//
//  MatrixManager.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 23.10.2026.
//

import Combine
import CryptoKit
import Foundation
import Network
import SwiftUI
import UIKit

@MainActor
class MatrixManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [LEDMatrixDevice] = []
    @Published var savedDevices: [LEDMatrixDevice] = []
    
    @Published var selectedDevice: LEDMatrixDevice?
    @Published var settings = MatrixSettings()
    @Published var wifiSettings = MatrixWifiSettings()
    @Published var isScanning = false
    @Published var connectionStatus = "Не подключено"
    
    @Published var isSavingSettings = false
    @Published var isSaveSuccess = false
    @Published var saveErrorMessage: String? = nil
    
    // MARK: - Состояния Вкладок Управления (с привязкой к выбранному устройству)
    
    /// Флаг, чтобы UserDefaults не перезаписывали значения во время программной загрузки
    private var isRestoringSettings = false
    
    private var deviceKeyPrefix: String {
        guard let ip = selectedDevice?.ipAddress else { return "matrix_default_" }
        return "matrix_\(ip)_"
    }
    
    @Published var textToSend: String = ""
    @Published var textColor: Color = .init(hex: "800080") {
        didSet {
            guard !isRestoringSettings else { return }
            if selectedDevice != nil {
                let hexStr = UIColor(textColor).toHex() ?? "800080"
                UserDefaults.standard.set(hexStr, forKey: deviceKeyPrefix + "saved_text_color")
            }
        }
    }
    
    @Published var textBgColor: Color = .init(hex: "000000") {
        didSet {
            guard !isRestoringSettings else { return }
            if selectedDevice != nil {
                let hexStr = UIColor(textBgColor).toHex() ?? "000000"
                UserDefaults.standard.set(hexStr, forKey: deviceKeyPrefix + "saved_text_bgcolor")
            }
        }
    }
    
    @Published var scrollSpeedFps: Float = 40.0 {
        didSet {
            guard !isRestoringSettings else { return }
            if selectedDevice != nil {
                UserDefaults.standard.set(scrollSpeedFps, forKey: deviceKeyPrefix + "saved_scroll_speed")
            }
        }
    }
    
    @Published var scrollRepeatCount: Int = 3 {
        didSet {
            guard !isRestoringSettings else { return }
            if selectedDevice != nil {
                UserDefaults.standard.set(scrollRepeatCount, forKey: deviceKeyPrefix + "saved_scroll_repeat")
            }
        }
    }
    
    /// Состояние тумблера «Сетка» на вкладке Экран
    @Published var showGrid: Bool = true {
        didSet {
            guard !isRestoringSettings else { return }
            if selectedDevice != nil {
                UserDefaults.standard.set(showGrid, forKey: deviceKeyPrefix + "saved_show_grid")
            }
        }
    }
    
    // MARK: - Локальные буферы для форм настроек

    @Published var localWifiSsid = ""
    @Published var localWifiPassword = ""
    @Published var localDivoomEmail = ""
    @Published var localDivoomPassword = ""
    
    @Published var screenPixels: [Color] = Array(repeating: .black, count: 256)
    @Published var isScreenLoading = false
    @Published var screenErrorMessage: String? = nil
    
    var authUsername = "admin"
    var authPassword = "s120Px17"
    
    var netServiceBrowser = NetServiceBrowser()
    var resolvingServices: [NetService] = []
    let passwordPlaceholder = "••••••••••••••••"
    
    // Ключи UserDefaults
    let savedDevicesKey = "led_matrix_saved_devices_list"
    let customNamesKey = "led_matrix_custom_names_dict"
    
    var isBrightnessSending = false
    var pendingBrightness: Int?
    
    // Очередь для последовательной отправки кадров рисования без гонки потоков
    let drawQueue = DispatchQueue(label: "com.matrix.drawQueue", qos: .userInitiated)
    var isDrawingFrameInFlight = false
    var pendingDrawFrameData: Data?
    
    override init() {
        super.init()
        loadSavedDevices()
    }
    
    func addBasicAuthHeader(to request: inout URLRequest) {
        let loginString = "\(authUsername):\(authPassword)"
        guard let loginData = loginString.data(using: .utf8) else { return }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    }
    
    /// Метод для загрузки настроек конкретного устройства из UserDefaults
    func loadSettingsForCurrentDevice() {
        guard selectedDevice != nil else { return }
        
        // Включаем флаг блокировки didSet, чтобы при присвоении значений
        // они случайно не затерли память пустыми дефолтами
        isRestoringSettings = true
        
        // Загружаем цвет текста
        if let hexColor = UserDefaults.standard.string(forKey: deviceKeyPrefix + "saved_text_color") {
            textColor = Color(hex: hexColor)
        } else {
            textColor = Color(hex: "800080")
        }
        
        // Загружаем цвет фона
        if let hexBg = UserDefaults.standard.string(forKey: deviceKeyPrefix + "saved_text_bgcolor") {
            textBgColor = Color(hex: hexBg)
        } else {
            textBgColor = Color(hex: "000000")
        }
        
        // Загружаем скорость
        if UserDefaults.standard.object(forKey: deviceKeyPrefix + "saved_scroll_speed") != nil {
            scrollSpeedFps = UserDefaults.standard.float(forKey: deviceKeyPrefix + "saved_scroll_speed")
        } else {
            scrollSpeedFps = 40.0
        }
        
        // Загружаем повторы
        if UserDefaults.standard.object(forKey: deviceKeyPrefix + "saved_scroll_repeat") != nil {
            scrollRepeatCount = UserDefaults.standard.integer(forKey: deviceKeyPrefix + "saved_scroll_repeat")
        } else {
            scrollRepeatCount = 3
        }
        
        // Загружаем видимость сетки
        if UserDefaults.standard.object(forKey: deviceKeyPrefix + "saved_show_grid") != nil {
            showGrid = UserDefaults.standard.bool(forKey: deviceKeyPrefix + "saved_show_grid")
        } else {
            showGrid = true
        }
        
        // Снимаем блокировку
        isRestoringSettings = false
    }
    
    // MARK: - Управление Сохранением и Переименованием

    func saveDevice(_ device: LEDMatrixDevice) {
        // Проверяем, нет ли уже такого устройства в сохраненных
        if !savedDevices.contains(where: { $0.ipAddress == device.ipAddress }) {
            savedDevices.append(device)
            persistSavedDevices()
        }
        // Удаляем из списка найденных, так как оно теперь перешло в категорию сохраненных
        discoveredDevices.removeAll { $0.ipAddress == device.ipAddress }
    }
    
    func renameDevice(ipAddress: String, newName: String) {
        // 1. Обновляем имя в списке сохраненных
        if let index = savedDevices.firstIndex(where: { $0.ipAddress == ipAddress }) {
            savedDevices[index].name = newName
            persistSavedDevices()
        }
        
        // 2. Сохраняем маппинг "IP -> Кастомное имя", чтобы при повторном поиске имя подтягивалось
        var customNames = UserDefaults.standard.dictionary(forKey: customNamesKey) as? [String: String] ?? [:]
        customNames[ipAddress] = newName
        UserDefaults.standard.set(customNames, forKey: customNamesKey)
        
        // 3. Если устройство сейчас выбрано — обновляем его состояние
        if selectedDevice?.ipAddress == ipAddress {
            selectedDevice?.name = newName
        }
    }
    
    func removeDevice(at offsets: IndexSet) {
        for index in offsets {
            guard savedDevices.indices.contains(index) else { continue }
            let deviceToRemove = savedDevices[index]
            
            // 1. Очищаем кастомное имя из UserDefaults по IP-адресу
            var customNames = UserDefaults.standard.dictionary(forKey: customNamesKey) as? [String: String] ?? [:]
            customNames.removeValue(forKey: deviceToRemove.ipAddress)
            UserDefaults.standard.set(customNames, forKey: customNamesKey)
            
            // 2. НОВОЕ: Полностью удаляем все сохраненные настройки этой матрицы из UserDefaults
            let prefix = "matrix_\(deviceToRemove.ipAddress)_"
            UserDefaults.standard.removeObject(forKey: prefix + "saved_text_to_send")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_text_color")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_text_bgcolor")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_scroll_speed")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_scroll_repeat")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_show_grid")
        }
        
        // 3. Удаляем из списка и сохраняем актуальный массив
        savedDevices.remove(atOffsets: offsets)
        persistSavedDevices()
    }
    
    private func persistSavedDevices() {
        // Для сохранения структуры в UserDefaults превращаем ее в компактный массив словарей
        let representation = savedDevices.map { ["name": $0.name, "ip": $0.ipAddress, "port": String($0.port)] }
        UserDefaults.standard.set(representation, forKey: savedDevicesKey)
    }
    
    private func loadSavedDevices() {
        guard let rawList = UserDefaults.standard.array(forKey: savedDevicesKey) as? [[String: String]] else { return }
        savedDevices = rawList.compactMap { dict in
            guard let name = dict["name"], let ip = dict["ip"], let portStr = dict["port"], let port = Int(portStr) else { return nil }
            return LEDMatrixDevice(name: name, ipAddress: ip, port: port)
        }
    }
    
    // MARK: - OTA-Обновление

    @Published var otaProgress: Double = 0.0
    @Published var isOtaUpdating = false
    @Published var otaStatusMessage: LocalizedStringKey = ""
    var pendingOtaFileURL: URL?
    
    // MARK: - Состояния Монитора Логов

    @Published var deviceLogs = ""
    @Published var isLogLoading = false
    var logTimer: Timer?
    
    // MARK: - Состояния Вкладки «Рисование»

    @Published var drawBrushColor: Color = .red
    @Published var isDrawingActive = false
    @Published var drawPixels: [Color] = Array(repeating: .black, count: 256)
    @Published var isDrawingLoading = false
    @Published var drawErrorMessage: String? = nil
    
    // MARK: - Undo / Redo для Рисования

    var undoStack: [[Color]] = []
    var redoStack: [[Color]] = []
    let maxUndoSteps = 10
    @Published var canUndo = false
    @Published var canRedo = false
    
    // MARK: - Состояния Лайв-режима Экран (WebSocket)

    @Published var isScreenLiveActive = false
    var webSocketTask: URLSessionWebSocketTask?
    
    // MARK: - Состояния и методы вкладки «Камера»

    @Published var isCameraActive = false
    @Published var cameraPixels: [Color] = Array(repeating: .black, count: 256)
    @Published var isUsingFrontCamera = false
    @Published var showCameraGrid = true
    @Published var lastCapturedImage: UIImage? = nil
}
