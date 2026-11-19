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
    case amber = "Янтарная"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil // Полностью следует системной схеме iOS
        case .dark: return .dark
        case .neon: return .dark // Неоновая также использует темную базу с яркими акцентами
        case .amber: return .dark // Янтарная — тёплая монохромная LED-палитра
        }
    }
    
    /// Системная тема не добавляет собственного декора: только нативные
    /// семантические цвета iOS, без обводок, свечений и теней.
    var usesSystemAppearance: Bool { self == .system }
    
    /// Толщина обводки карточки для «декоративных» тем.
    var cardBorderWidth: CGFloat {
        switch self {
        case .neon, .amber: return 1.2
        default: return 1
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
    
    /// Тумблер «Отображать на весь экран» на вкладке Текст.
    /// По умолчанию выключен: прошивка рисует текст на непрозрачной полосе
    /// в центре матрицы. Включённый тумблер возвращает классический
    /// полноэкранный текст (scroll_text_transparent = false).
    @Published var textFullScreen: Bool = false {
        didSet {
            guard !isRestoringSettings else { return }
            if selectedDevice != nil {
                UserDefaults.standard.set(textFullScreen, forKey: deviceKeyPrefix + "saved_text_fullscreen")
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

    /// Пароль basic auth — MAC-адрес устройства в обратном порядке байт.
    /// Например, MAC `28:84:85:89:6E:4C` даёт пароль `4C6E89858428`.
    /// MAC приходит в /settings, который не требует авторизации.
    var authPassword: String {
        let hex = settings.macAddress.filter(\.isHexDigit).uppercased()
        guard hex.count == 12 else { return "" }

        let bytes = stride(from: 0, to: 12, by: 2).map { offset in
            String(hex.dropFirst(offset).prefix(2))
        }
        return bytes.reversed().joined()
    }
    
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
        let password = authPassword
        // Пока MAC ещё не получен из /settings, защищённый запрос всё равно
        // не пройдёт; не отправляем заведомо неверные учётные данные.
        guard !password.isEmpty else { return }

        let loginString = "\(authUsername):\(password)"
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
        
        // Загружаем режим отображения текста (полоса / весь экран)
        if UserDefaults.standard.object(forKey: deviceKeyPrefix + "saved_text_fullscreen") != nil {
            textFullScreen = UserDefaults.standard.bool(forKey: deviceKeyPrefix + "saved_text_fullscreen")
        } else {
            textFullScreen = false
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
            return Color(uiColor: .systemGroupedBackground)
        case .dark:
            return Color.black // Чистый OLED черный
        case .neon:
            return Color(hex: "080C14") // Глубокий киберпанк-оттенок (ночной сине-угольный)
        case .amber:
            return Color(hex: "140D05") // Тёплый чёрный монохромных LED-дисплеев
        }
    }

    // Цвет карточек / контейнеров
    var cardBackgroundColor: Color {
        switch currentTheme {
        case .system:
            return Color(uiColor: .secondarySystemGroupedBackground)
        case .dark:
            return Color(hex: "1A1A1A") // Темный графит для OLED
        case .neon:
            return Color(hex: "111827") // Насыщенный темно-синий киберпанк-графит
        case .amber:
            return Color(hex: "241A0C") // Коричневатый корпус янтарного дисплея
        }
    }

    // Основной цвет текста интерфейса
    var appTextColor: Color {
        switch currentTheme {
        case .system:
            return .primary
        case .dark, .neon, .amber:
            return lightAccentColor
        }
    }

    /// Светлый оттенок акцента — заменяет чистый белый в декоративных темах.
    var lightAccentColor: Color { Self.lightAccentColor(for: currentTheme) }

    static func lightAccentColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return .primary
        case .dark:
            return Color(hex: "A6E6A6") // Насыщенный светло-зелёный OLED
        case .neon:
            return Color(hex: "A8E6F2") // Насыщенный светло-циановый неон
        case .amber:
            return Color(hex: "FFD9A0") // Разогретый янтарь
        }
    }

    /// Цвет значений — совпадает с цветом названия темы, то есть с акцентом.
    var valueTextColor: Color {
        switch currentTheme {
        case .system:
            return .secondary
        case .dark, .neon, .amber:
            return accentColor
        }
    }

    // Акцентный цвет
    var accentColor: Color {
        switch currentTheme {
        case .system:
            return Color.accentColor // Реальный системный tint (без кастомного ассета)
        case .dark:
            return Color.green
        case .neon:
            return Color(hex: "00F0FF") // Яркий неоновый циан (электрик) для контраста
        case .amber:
            return Color(hex: "FFB000") // Классический янтарный светодиод
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
        case .amber:
            return Color(hex: "FFB000").opacity(0.7)
        }
    }

    // MARK: - Расширенная палитра темы

    /// Второстепенный текст: подписи, значения, подсказки.
    var secondaryTextColor: Color {
        switch currentTheme {
        case .system:
            return .secondary
        case .dark:
            return Color(hex: "9BD49B")
        case .neon:
            return Color(hex: "8FD8E6")
        case .amber:
            return Color(hex: "C99A55")
        }
    }

    /// Фон полей ввода и небольших вложенных контролов.
    var fieldBackgroundColor: Color {
        switch currentTheme {
        case .system:
            return Color(uiColor: .systemFill)
        case .dark:
            return Color(hex: "242424")
        case .neon:
            return Color(hex: "0B1524")
        case .amber:
            return Color(hex: "1F160A")
        }
    }

    /// Линии-разделители внутри карточек и списков.
    var dividerColor: Color {
        switch currentTheme {
        case .system:
            return .clear // Нативные разделители списков рисует система
        case .dark:
            return Color(hex: "7EE37E").opacity(0.12)
        case .neon:
            return Color(hex: "00F0FF").opacity(0.16)
        case .amber:
            return Color(hex: "FFB000").opacity(0.18)
        }
    }

    /// Обводка карточек. В системной теме её нет вовсе.
    var cardBorderColor: Color {
        switch currentTheme {
        case .system:
            return .clear
        case .dark:
            return Color.green.opacity(0.32)
        case .neon:
            return Color(hex: "00F0FF").opacity(0.45)
        case .amber:
            return Color(hex: "FFB000").opacity(0.5)
        }
    }

    /// Подложка вокруг LED-сетки 16×16. Всегда почти чёрная, чтобы
    /// светодиоды читались одинаково хорошо в любой теме.
    var matrixPanelColor: Color {
        switch currentTheme {
        case .system:
            return Color(hex: "171717")
        case .dark:
            return Color(hex: "0E0E0E")
        case .neon:
            return Color(hex: "05080F")
        case .amber:
            return Color(hex: "0D0904")
        }
    }

    /// Цвет тени карточек. В системной теме теней нет.
    var shadowColor: Color {
        switch currentTheme {
        case .system:
            return .clear
        case .dark:
            return Color.black.opacity(0.45)
        case .neon:
            return Color(hex: "00F0FF").opacity(0.16)
        case .amber:
            return Color(hex: "FFB000").opacity(0.12)
        }
    }

    /// Цвет текста/иконок поверх акцентной заливки.
    var accentContrastColor: Color {
        switch currentTheme {
        case .system:
            return .white
        case .dark:
            return .black
        case .neon:
            return Color(hex: "031018")
        case .amber:
            return Color(hex: "1A1206")
        }
    }

    var successColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.systemGreen)
        case .dark:
            return Color(hex: "4ADE80")
        case .neon:
            return Color(hex: "2DFFB2")
        case .amber:
            return Color(hex: "BCE86B")
        }
    }

    var warningColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.systemOrange)
        case .dark:
            return Color(hex: "FBBF24")
        case .neon:
            return Color(hex: "FFC857")
        case .amber:
            return Color(hex: "FFD166")
        }
    }

    var dangerColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.systemRed)
        case .dark:
            return Color(hex: "FF6B6B")
        case .neon:
            return Color(hex: "FF4D8D")
        case .amber:
            return Color(hex: "FF6B4A")
        }
    }

    /// Фон всплывающих подсказок (тостов).
    var toastBackgroundColor: Color {
        switch currentTheme {
        case .system:
            return Color.black.opacity(0.82)
        case .dark:
            return Color(hex: "242424").opacity(0.96)
        case .neon:
            return Color(hex: "0B1524").opacity(0.96)
        case .amber:
            return Color(hex: "241A0C").opacity(0.96)
        }
    }
}

// MARK: - Общие тематические модификаторы

/// Нативные стили кнопок, которые применяются только в системной теме.
enum ThemedButtonStyle {
    case plain
    case borderless
    case bordered
    case borderedProminent
}

extension View {
    /// Условный модификатор: позволяет выключать декоративные слои
    /// только для нативной темы, не раздувая body.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// В системной теме кнопка получает нативный стиль iOS.
    /// В остальных темах сохраняется `.plain`, чтобы работала кастомная обводка.
    @ViewBuilder
    func themedButtonStyle(_ manager: MatrixManager, _ style: ThemedButtonStyle) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            switch style {
            case .plain:
                self.buttonStyle(.plain)
            case .borderless:
                self.buttonStyle(.borderless)
            case .bordered:
                self.buttonStyle(.bordered)
            case .borderedProminent:
                self.buttonStyle(.borderedProminent)
            }
        } else {
            self.buttonStyle(.plain)
        }
    }

    /// Большая кнопка действия: в декоративных темах повторяет плитку функции
    /// на главном экране — карточка, обводка акцентом и светлый акцентный текст.
    /// В системной теме остаётся нативной prominent-кнопкой с заданным tint.
    @ViewBuilder
    func themedActionButton(_ manager: MatrixManager, buttonTint: Color? = nil, isEnabled: Bool = true) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            if let buttonTint {
                self.buttonStyle(.borderedProminent).tint(buttonTint)
            } else {
                self.buttonStyle(.borderedProminent)
            }
        } else {
            self
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(manager.cardBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(buttonTint ?? manager.accentColor, lineWidth: manager.currentTheme == .neon ? 1.5 : 1)
                        )
                )
                .foregroundColor(isEnabled ? manager.appTextColor : manager.secondaryTextColor)
                .shadow(color: manager.shadowColor, radius: 5, x: 0, y: 3)
                .buttonStyle(.plain)
                .opacity(isEnabled ? 1 : 0.5)
        }
    }

    /// Белый текст на тёмных плашках: в декоративных темах — светлый акцент,
    /// в системной остаётся нативным белым.
    @ViewBuilder
    func themedLightText(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self.foregroundColor(.white)
        } else {
            self.foregroundColor(manager.lightAccentColor)
        }
    }

    /// Системная тема вообще не вмешивается в оформление Form/List:
    /// ни фон, ни tint — всё берётся из дефолтов iOS.
    @MainActor
    @ViewBuilder
    func themedForm(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self
                .scrollContentBackground(.hidden)
                .background(manager.backgroundColor.ignoresSafeArea())
                .foregroundColor(manager.appTextColor)
                .tint(manager.accentColor)
        }
    }

    /// Системная тема не рисует декоративную карточку: только нативная
    /// семантическая заливка строки, без скругления, обводки и тени.
    @MainActor
    @ViewBuilder
    func themedCard(_ manager: MatrixManager, cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        if manager.currentTheme.usesSystemAppearance {
            self.background(manager.cardBackgroundColor)
        } else {
            self
                .background(shape.fill(manager.cardBackgroundColor))
                .overlay(shape.stroke(manager.cardBorderColor, lineWidth: manager.currentTheme.cardBorderWidth))
                .shadow(color: manager.shadowColor, radius: 6, x: 0, y: 3)
        }
    }

    /// Заголовки секций в системной теме остаются нативными (secondary).
    @ViewBuilder
    func themedSectionHeader(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self.foregroundColor(manager.accentColor)
        }
    }

    /// Оставляет нативный полупрозрачный navbar в системной теме.
    @MainActor
    @ViewBuilder
    func themedToolbarBackground(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self
                .toolbarBackground(manager.cardBackgroundColor, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    /// Тёмный «терминальный» navbar нужен только декоративным темам.
    @MainActor
    @ViewBuilder
    func themedDarkToolbar(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbarBackground(manager.matrixPanelColor, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
