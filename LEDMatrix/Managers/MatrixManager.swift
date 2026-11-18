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


enum AppTheme: String, CaseIterable, Identifiable {
    case system = "Системная"
    case dark = "Тёмная (OLED)"
    case neon = "Неоновая"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .neon: return .dark // Неоновая также использует темную базу с яркими акцентами
        }
    }
}

@MainActor
class MatrixManager: NSObject, ObservableObject {
    @Published var currentTheme: AppTheme = MatrixManager.loadInitialTheme() {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selected_app_theme")
        }
    }
    
    private static func loadInitialTheme() -> AppTheme {
        if let raw = UserDefaults.standard.string(forKey: "selected_app_theme"),
           let theme = AppTheme(rawValue: raw) {
            return theme
        }
        return .dark // По умолчанию темная тема
    }
    
    @Published var discoveredDevices: [LEDMatrixDevice] = []
    @Published var savedDevices: [LEDMatrixDevice] = []
        
    @Published var selectedDevice: LEDMatrixDevice? {
        didSet {
            if let device = selectedDevice {
                UserDefaults.standard.set(device.id, forKey: "led_matrix_last_selected_device_id")
            } else {
                UserDefaults.standard.removeObject(forKey: "led_matrix_last_selected_device_id")
            }
        }
    }

    @Published var settings = MatrixSettings()
    @Published var wifiSettings = MatrixWifiSettings()
    @Published var clockFaces: [ClockFace] = []
    @Published var clockFonts: [ClockFont] = []
    @Published var isScanning = false
    @Published var connectionStatus = "Не подключено"
        
    @Published var isSavingSettings = false
    @Published var isSaveSuccess = false
    @Published var saveErrorMessage: String? = nil
    
    let lastSelectedDeviceIdKey = "led_matrix_last_selected_device_id"

    /// В init() добавьте автоматический выбор последнего устройства:
    override init() {
        super.init()
        loadSavedDevices()
        restoreLastSelectedDevice()
    }
    
    /// Единый метод для смены устройства: загружает локальный кэш и подтягивает сеть
    func selectDevice(_ device: LEDMatrixDevice) {
        guard selectedDevice?.id != device.id else { return }
        selectedDevice = device
        loadSettingsForCurrentDevice()
            
        Task {
            await fetchSettings(for: device)
            await fetchWifiSettings(for: device)
        }
    }

    func restoreLastSelectedDevice() {
        let lastId = UserDefaults.standard.string(forKey: lastSelectedDeviceIdKey)
        if let found = savedDevices.first(where: { $0.id == lastId }) {
            selectedDevice = found
            loadSettingsForCurrentDevice()
            Task {
                await fetchSettings(for: found)
                await fetchWifiSettings(for: found)
            }
        } else if let first = savedDevices.first {
            selectedDevice = first
            loadSettingsForCurrentDevice()
            Task {
                await fetchSettings(for: first)
                await fetchWifiSettings(for: first)
            }
        }
    }
        
    // Новые состояния для проверки доступности перед входом
    @Published var isConnectingToDevice = false
    @Published var connectionErrorAlert: String? = nil
        
    /// Ассоциируем настройки исключительно с уникальным ID устройства
    private var deviceKeyPrefix: String {
        guard let deviceId = selectedDevice?.id else { return "matrix_default_" }
        return "matrix_\(deviceId)_"
    }
    
    // Словарь статусов доступности устройств [ID устройства: доступно ли в сети]
    @Published var deviceReachabilityStatus: [String: Bool] = [:]
    @Published var isCheckingReachability = false

    /// Проверка доступности всех сохраненных устройств
    func checkAllSavedDevicesReachability() async {
        isCheckingReachability = true
            
        // Параллельно проверяем каждое сохраненное устройство
        let statuses: [(String, Bool)] = await withTaskGroup(of: (String, Bool).self) { group in
            for device in savedDevices {
                group.addTask {
                    let isReachable = await self.isDeviceReachable(device)
                    return (device.id, isReachable)
                }
            }
                
            var results: [(String, Bool)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
            
        await MainActor.run {
            for (id, status) in statuses {
                self.deviceReachabilityStatus[id] = status
            }
            self.isCheckingReachability = false
        }
    }

    /// Единичная проверка доступности устройства
    private func isDeviceReachable(_ device: LEDMatrixDevice) async -> Bool {
        guard let url = URL(string: "http://\(device.ipAddress):\(device.port)/settings") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        addBasicAuthHeader(to: &request)
            
        do {
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config)
            let (_, response) = try await session.data(for: request)
            if let httpResp = response as? HTTPURLResponse {
                return (200 ... 299).contains(httpResp.statusCode) || httpResp.statusCode == 401
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Состояния Вкладок Управления (с привязкой к выбранному устройству)
    
    /// Флаг, чтобы UserDefaults не перезаписывали значения во время программной загрузки
    private var isRestoringSettings = false

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
        // Проверяем уникальность по id, а не по IP-адресу
        if let index = savedDevices.firstIndex(where: { $0.id == device.id }) {
            savedDevices[index].ipAddress = device.ipAddress // обновляем IP, если он изменился
        } else if !savedDevices.contains(where: { $0.id == device.id }) {
            savedDevices.append(device)
        }
        persistSavedDevices()
        discoveredDevices.removeAll { $0.id == device.id }
    }
        
    func renameDevice(id: String, newName: String) {
        if let index = savedDevices.firstIndex(where: { $0.id == id }) {
            savedDevices[index].name = newName
            persistSavedDevices()
        }
            
        var customNames = UserDefaults.standard.dictionary(forKey: customNamesKey) as? [String: String] ?? [:]
        customNames[id] = newName
        UserDefaults.standard.set(customNames, forKey: customNamesKey)
            
        if selectedDevice?.id == id {
            selectedDevice?.name = newName
        }
    }
        
    func removeDevice(at offsets: IndexSet) {
        for index in offsets {
            guard savedDevices.indices.contains(index) else { continue }
            let deviceToRemove = savedDevices[index]
                
            var customNames = UserDefaults.standard.dictionary(forKey: customNamesKey) as? [String: String] ?? [:]
            customNames.removeValue(forKey: deviceToRemove.id)
            UserDefaults.standard.set(customNames, forKey: customNamesKey)
                
            // Удаляем настройки, привязанные к уникальному ID устройства
            let prefix = "matrix_\(deviceToRemove.id)_"
            UserDefaults.standard.removeObject(forKey: prefix + "saved_text_to_send")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_text_color")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_text_bgcolor")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_scroll_speed")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_scroll_repeat")
            UserDefaults.standard.removeObject(forKey: prefix + "saved_show_grid")
        }
            
        savedDevices.remove(atOffsets: offsets)
        persistSavedDevices()
    }
        
    func persistSavedDevices() {
        let representation = savedDevices.map { ["id": $0.id, "name": $0.name, "ip": $0.ipAddress, "port": String($0.port)] }
        UserDefaults.standard.set(representation, forKey: savedDevicesKey)
    }
        
    private func loadSavedDevices() {
        guard let rawList = UserDefaults.standard.array(forKey: savedDevicesKey) as? [[String: String]] else { return }
        savedDevices = rawList.compactMap { dict in
            guard let id = dict["id"] ?? dict["ip"], // поддержка обратной совместимости со старыми записями
                  let name = dict["name"], let ip = dict["ip"], let portStr = dict["port"], let port = Int(portStr) else { return nil }
            return LEDMatrixDevice(id: id, name: name, ipAddress: ip, port: port)
        }
    }
        
    /// Проверка доступности устройства в сети перед входом
    func selectAndVerifyDevice(_ device: LEDMatrixDevice) async -> Bool {
        isConnectingToDevice = true
        connectionErrorAlert = nil
            
        guard let url = URL(string: "http://\(device.ipAddress):\(device.port)/settings") else {
            isConnectingToDevice = false
            connectionErrorAlert = "Некорректный адрес устройства."
            return false
        }
            
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        addBasicAuthHeader(to: &request)
            
        do {
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config)
            let (_, response) = try await session.data(for: request)
                
            if let httpResp = response as? HTTPURLResponse, (200 ... 299).contains(httpResp.statusCode) || httpResp.statusCode == 401 {
                await MainActor.run {
                    self.selectedDevice = device
                    self.loadSettingsForCurrentDevice()
                    self.isConnectingToDevice = false
                }
                return true
            }
        } catch {
            print("❌ Устройство недоступно: \(error)")
        }
            
        isConnectingToDevice = false
        connectionErrorAlert = "Устройство «\(device.name)» добавлено, но недоступно в сети."
        return false
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

extension MatrixManager {
    // Цвет основного фона
    var backgroundColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.systemBackground)
        case .dark:
            return Color.black // Чистый OLED черный
        case .neon:
            return Color(hex: "080C14") // Глубокий киберпанк-оттенок (ночной сине-угольный)
        }
    }

    // Цвет карточек / контейнеров
    var cardBackgroundColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.secondarySystemBackground)
        case .dark:
            return Color(hex: "1A1A1A") // Темный графит для OLED
        case .neon:
            return Color(hex: "111827") // Насыщенный темно-синий киберпанк-графит
        }
    }

    // Основной цвет текста интерфейса
    var appTextColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.label)
        case .dark:
            return Color.white
        case .neon:
            return Color(hex: "E2E8F0") // Светлый технологичный оттенок
        }
    }

    // Акцентный цвет
    var accentColor: Color {
        switch currentTheme {
        case .system:
            return Color.accentColor
        case .dark:
            return Color.green
        case .neon:
            return Color(hex: "00F0FF") // Яркий неоновый циан (электрик) для контраста
        }
    }

    // Цвет обводки (рамок) кнопок и карточек
    var borderColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.separator)
        case .dark:
            return Color.green.opacity(0.5)
        case .neon:
            return Color(hex: "00F0FF").opacity(0.8) // Циановая неоновая граница
        }
    }
}
