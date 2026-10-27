//
//  MatrixManager.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 23.10.2026.
//

import Foundation
import Network
import Combine
import SwiftUI
import UIKit

extension NetService: @retroactive @unchecked Sendable {}

struct LEDMatrixDevice: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var ipAddress: String
    var port: Int = 80
    
    var url: URL? {
        URL(string: "http://\(ipAddress):\(port)")
    }
}

struct MatrixSettings: Codable {
    var brightnessPercent: Int = 0
    var dayBrightnessPercent: Int = 0
    var nightBrightnessPercent: Int = 0
    var dayStart: String = ""
    var nightStart: String = ""
    var dayDeviceMode: String = ""
    var nightDeviceMode: String = ""
    var deviceMode: String = ""
    var showNameText: Bool = false
    var clockFont: Int = 0
    var scrollSpeedFps: Int = 0
    var scrollRepeatCount: Int = 0
    var bootCount: Int = 0
    var divoomEmail: String = ""
    var divoomPasswordSet: Bool = false
    var macAddress: String = ""
    var hostName: String = ""
    var ipAddress: String = ""
    var hwVersion: String = ""
    var fwVersion: String = ""
    var hoursColorHex: String = ""
    var minutesColorHex: String = ""
    var colonColorHex: String = ""
    var bgColorHex: String = ""
    
    enum CodingKeys: String, CodingKey {
        case brightnessPercent = "brightness"
        case dayBrightnessPercent = "brightness_day"
        case nightBrightnessPercent = "brightness_night"
        case dayStart = "day_start"
        case nightStart = "night_start"
        case dayDeviceMode = "day_device_mode"
        case nightDeviceMode = "night_device_mode"
        case deviceMode = "device_mode"
        case showNameText = "show_name_text"
        case clockFont = "clock_font"
        case scrollSpeedFps = "scroll_speed_fps"
        case scrollRepeatCount = "scroll_repeat_count"
        case bootCount = "boot_count"
        case divoomEmail = "divoom_email"
        case divoomPasswordSet = "divoom_password_set"
        case macAddress = "mac_address"
        case hostName = "hostname"
        case ipAddress = "ip_address"
        case hwVersion = "hw_version"
        case fwVersion = "fw_version"
        case hoursColorHex = "hours_color_hex"
        case minutesColorHex = "minutes_color_hex"
        case colonColorHex = "colon_color_hex"
        case bgColorHex = "bg_color_hex"
    }
}

struct MatrixWifiSettings: Codable {
    var ssid: String = ""
    var passwordSet: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case ssid = "ssid"
        case passwordSet = "password_set"
    }
}

@MainActor
class MatrixManager: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var discoveredDevices: [LEDMatrixDevice] = []
    @Published var selectedDevice: LEDMatrixDevice?
    @Published var settings = MatrixSettings()
    @Published var wifiSettings = MatrixWifiSettings()
    @Published var isScanning = false
    @Published var connectionStatus = "Не подключено"
    
    // MARK: - Состояния Вкладок Управления
    @Published var textToSend = ""
    @Published var textColor = Color.purple
    @Published var textBgColor = Color.black
    @Published var scrollSpeedFps: Float = 25.0
    @Published var scrollRepeatCount = 3
    
    // MARK: - Локальные буферы для форм настроек
    @Published var localWifiSsid = ""
    @Published var localWifiPassword = ""
    @Published var localDivoomEmail = ""
    @Published var localDivoomPassword = ""
    
    var authUsername = "admin"
    var authPassword = "s120Px17"
    
    private var netServiceBrowser = NetServiceBrowser()
    private var resolvingServices: [NetService] = []
    let passwordPlaceholder = "••••••••••••••••"
    
    private func addBasicAuthHeader(to request: inout URLRequest) {
        let loginString = "\(authUsername):\(authPassword)"
        guard let loginData = loginString.data(using: .utf8) else { return }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
    }
    
    func startScanning() {
        print("🔍 Начать поиск устройств...")
        discoveredDevices.removeAll()
        resolvingServices.removeAll()
        isScanning = true
        connectionStatus = "Поиск устройств..."
        
        netServiceBrowser.delegate = self
        netServiceBrowser.searchForServices(ofType: "_http._tcp.", inDomain: "local.")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        netServiceBrowser.stop()
        for service in resolvingServices {
            service.stop()
        }
        isScanning = false
        print("🔍 Поиск завершен. Найдено устройств: \(discoveredDevices.count)")
        if discoveredDevices.isEmpty {
            connectionStatus = "Устройства не найдены"
        } else {
            connectionStatus = "Найдено устройств: \(discoveredDevices.count)"
        }
    }
    
    // MARK: - NetServiceBrowserDelegate
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let name = service.name
        if name.lowercased().hasPrefix("ledmatrix-") {
            service.delegate = self
            service.resolve(withTimeout: 5.0)
            Task { @MainActor in
                if !self.resolvingServices.contains(service) {
                    self.resolvingServices.append(service)
                }
            }
        }
    }
    
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let name = service.name
        Task { @MainActor in
            service.stop()
            self.resolvingServices.removeAll { $0 === service }
            self.discoveredDevices.removeAll { $0.name == name }
        }
    }
    
    // MARK: - NetServiceDelegate
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        let name = sender.name
        var addressStr = getIPAddress(from: sender.addresses) ?? ""
        if addressStr.isEmpty, let host = sender.hostName {
            addressStr = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        let cleanAddress = addressStr.components(separatedBy: "%").first ?? addressStr
        
        Task { @MainActor in
            if !cleanAddress.isEmpty {
                let device = LEDMatrixDevice(name: name, ipAddress: cleanAddress)
                if !self.discoveredDevices.contains(where: { $0.name == name || $0.ipAddress == cleanAddress }) {
                    self.discoveredDevices.append(device)
                    self.connectionStatus = "Найдено устройств: \(self.discoveredDevices.count)"
                }
            }
        }
    }
    
    nonisolated private func getIPAddress(from addresses: [Data]?) -> String? {
        guard let addresses = addresses else { return nil }
        for address in addresses {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let success = address.withUnsafeBytes { ptr -> Bool in
                guard let addrBase = ptr.baseAddress else { return false }
                let sockAddrPtr = addrBase.assumingMemoryBound(to: sockaddr.self)
                return getnameinfo(sockAddrPtr, socklen_t(address.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0
            }
            if success {
                let ip = String(cString: hostname)
                if !ip.contains(":") { return ip }
            }
        }
        return nil
    }
    
    // MARK: - Запросы и инициализация данных
    func fetchSettings(for device: LEDMatrixDevice) async {
        self.selectedDevice = device
        self.connectionStatus = "Подключение к \(device.name)..."
        
        guard let url = URL(string: "http://\(device.ipAddress)/settings") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addBasicAuthHeader(to: &request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                let decoded = try JSONDecoder().decode(MatrixSettings.self, from: data)
                self.settings = decoded
                self.localDivoomEmail = decoded.divoomEmail
                self.localDivoomPassword = decoded.divoomPasswordSet ? passwordPlaceholder : ""
                self.connectionStatus = "Подключено к \(device.name)"
            }
        } catch {
            print("❌ Ошибка при запросе /settings: \(error)")
            connectionStatus = "Ошибка соединения"
        }
    }
    
    func fetchWifiSettings(for device: LEDMatrixDevice) async {
        self.selectedDevice = device
        guard let url = URL(string: "http://\(device.ipAddress)/wifi") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addBasicAuthHeader(to: &request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                let decoded = try JSONDecoder().decode(MatrixWifiSettings.self, from: data)
                self.wifiSettings = decoded
                self.localWifiSsid = decoded.ssid
                self.localWifiPassword = decoded.passwordSet ? passwordPlaceholder : ""
            }
        } catch {
            print("❌ Ошибка при запросе /wifi: \(error)")
        }
    }
    
    func sendCommand(endpoint: String, params: [String: Any]) async {
        guard let device = selectedDevice else { return }
        let urlString = "http://\(device.ipAddress)/\(endpoint)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addBasicAuthHeader(to: &request)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Ошибка отправки команды: (error)")
        }
    }
    
    // MARK: - API методы изменений
    func updateSingleBrightness(_ brightness: Int) async {
        settings.brightnessPercent = brightness
        await sendCommand(endpoint: "cmd", params: ["brightness": brightness])
    }
    
    func updateBrightnessDay(_ brightDay: Int) async {
        settings.dayBrightnessPercent = brightDay
        await sendCommand(endpoint: "cmd", params: ["brightness_day": brightDay])
    }
    
    func updateBrightnessNight(_ brightNight: Int) async {
        settings.nightBrightnessPercent = brightNight
        await sendCommand(endpoint: "cmd", params: ["brightness_night": brightNight])
    }
    
    func sendCurrentText() async {
        guard !textToSend.isEmpty else { return }
        
        let bgComp = UIColor(textBgColor).rgbComponents()
        let textComp = UIColor(textColor).rgbComponents()
        
        // ИСПРАВЛЕНО: Добавлены обратные слэши для корректной интерполяции данных
        let formattedText = "[\(bgComp.0),\(bgComp.1),\(bgComp.2)][\(textComp.0),\(textComp.1),\(textComp.2)]\(textToSend)"
        
        await sendCommand(endpoint: "cmd", params: [
            "text": formattedText,
            "text_speed_fps": Int(scrollSpeedFps),
            "repeat_count": scrollRepeatCount
        ])
    }

    func updateClockFont(_ font: Int) async {
        settings.clockFont = font
        await sendCommand(endpoint: "cmd", params: ["clock_font": font])
    }
    
    func updateClockHoursColor(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.hoursColorHex = hex
        await sendCommand(endpoint: "cmd", params: ["hours_color_hex": hex])
    }
    
    func updateClockMinutesColor(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.minutesColorHex = hex
        await sendCommand(endpoint: "cmd", params: ["minutes_color_hex": hex])
    }
    
    func updateClockColonColor(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.colonColorHex = hex
        await sendCommand(endpoint: "cmd", params: ["colon_color_hex": hex])
    }
    
    func updateClockBgColor(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "000000"
        settings.bgColorHex = hex
        await sendCommand(endpoint: "cmd", params: ["bg_color_hex": hex])
    }
    
    func toggleShowTextUsername(_ showUsername: Bool) async {
        settings.showNameText = showUsername
        await sendCommand(endpoint: "cmd", params: ["show_name_text": showUsername])
    }
    
    // MARK: - Пикеры Времени (Конвертация String <-> Date)
    var dayStartTimeBinding: Binding<Date> {
        Binding(
            get: { self.parseTime(self.settings.dayStart) },
            set: { newDate in
                let timeString = self.formatTime(newDate)
                self.settings.dayStart = timeString
                Task {
                    await self.sendCommand(endpoint: "cmd", params: ["day_start": timeString])
                }
            }
        )
    }
    
    var nightStartTimeBinding: Binding<Date> {
        Binding(
            get: { self.parseTime(self.settings.nightStart) },
            set: { newDate in
                let timeString = self.formatTime(newDate)
                self.settings.nightStart = timeString
                Task {
                    await self.sendCommand(endpoint: "cmd", params: ["night_start": timeString])
                }
            }
        )
    }
    
    var dayDeviceModeBinding: Binding<String> {
        Binding(
            get: { self.settings.dayDeviceMode },
            set: { newValue in
                self.settings.dayDeviceMode = newValue
                Task {
                    await self.sendCommand(endpoint: "cmd", params: ["day_device_mode": newValue])
                }
            }
        )
    }
        
    var nightDeviceModeBinding: Binding<String> {
        Binding(
            get: { self.settings.nightDeviceMode },
            set: { newValue in
                self.settings.nightDeviceMode = newValue
                Task {
                    await self.sendCommand(endpoint: "cmd", params: ["night_device_mode": newValue])
                }
            }
        )
    }
    
    // Вспомогательные методы для работы с форматом ЧЧ:ММ
    private func parseTime(_ timeStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        // Если строка пустая или некорректная, отдаем дефолтное время
        return formatter.date(from: timeStr) ?? Date()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    
    // MARK: - Сохранение форм настроек (Вызывается по кнопке сохранить)
    func saveWifiSettings() async {
        if isWifiSsidChanged {
            await sendCommand(endpoint: "wifi", params: ["ssid": localWifiSsid])
        }
        if isWifiPasswordChanged {
            await sendCommand(endpoint: "wifi", params: ["password": localWifiPassword])
        }
        if let device = selectedDevice { await fetchWifiSettings(for: device) }
    }
    
    func saveDivoomSettings() async {
        if isDivoomEmailChanged {
            await sendCommand(endpoint: "cmd", params: ["divoom_email": localDivoomEmail])
        }
        if isDivoomPasswordChanged {
            await sendCommand(endpoint: "cmd", params: ["divoom_password": localDivoomPassword])
        }
        if let device = selectedDevice { await fetchSettings(for: device) }
    }
    
    // MARK: - Системные действия
    func deviceRestart() async { await sendCommand(endpoint: "cmd", params: ["action": "restart"]) }
    func deviceResetWifi() async { await sendCommand(endpoint: "cmd", params: ["action": "reset_wifi"]) }
    func deviceResetSettings() async { await sendCommand(endpoint: "cmd", params: ["action": "reset_settings"]) }
    func deviceFactoryReset() async { await sendCommand(endpoint: "cmd", params: ["action": "factory_reset"]) }
    
    // MARK: - Валидация изменений для кнопок сохранения
    var isWifiSsidChanged: Bool { localWifiSsid != wifiSettings.ssid && !localWifiSsid.isEmpty }
    var isWifiPasswordChanged: Bool { wifiSettings.passwordSet ? (localWifiPassword != passwordPlaceholder && !localWifiPassword.isEmpty) : !localWifiPassword.isEmpty }
    var isDivoomEmailChanged: Bool { localDivoomEmail != settings.divoomEmail && !localDivoomEmail.isEmpty }
    var isDivoomPasswordChanged: Bool { settings.divoomPasswordSet ? (localDivoomPassword != passwordPlaceholder && !localDivoomPassword.isEmpty) : !localDivoomPassword.isEmpty }
}

extension UIColor {
    func rgbComponents() -> (Int, Int, Int) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }
    
    func toHex() -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)
        return String(format: "%06X", rgb)
    }
}
