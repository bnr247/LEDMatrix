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
    var digitsColorHex: String = ""
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
        case digitsColorHex = "digits_color_hex"
        case colonColorHex = "colon_color_hex"
        case bgColorHex = "bg_color_hex"
    }
}

@MainActor
class MatrixManager: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var discoveredDevices: [LEDMatrixDevice] = []
    @Published var selectedDevice: LEDMatrixDevice?
    @Published var settings = MatrixSettings()
    @Published var isScanning = false
    @Published var connectionStatus = "Не подключено"

    private var netServiceBrowser = NetServiceBrowser()
    private var resolvingServices: [NetService] = []

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
        print("🔍 Обнаружен сервис Bonjour: \(name)")
        if name.lowercased().hasPrefix("ledmatrix-") {
            print("🔍 Сервис подходит под фильтр: \(name), начинаем резолв...")
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
        print("🔍 Сервис удален: \(name)")
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
        
        print("🔍 Успешный резолв для \(name) -> Адрес: \(cleanAddress)")

        Task { @MainActor in
            if !cleanAddress.isEmpty {
                let device = LEDMatrixDevice(name: name, ipAddress: cleanAddress)
                if !self.discoveredDevices.contains(where: { $0.name == name || $0.ipAddress == cleanAddress }) {
                    self.discoveredDevices.append(device)
                    print("✅ Устройство добавлено в список: \(name) (\(cleanAddress))")
                    self.connectionStatus = "Найдено устройств: \(self.discoveredDevices.count)"
                }
            } else {
                print("❌ Не удалось получить IP-адрес для резолвнутого сервиса \(name)")
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

    func fetchSettings(for device: LEDMatrixDevice) async {
        print("🔍 fetchSettings вызван для: \(device.name) (\(device.ipAddress))")
        self.selectedDevice = device
        self.connectionStatus = "Подключение к \(device.name)..."

        // Исправлено: добавление пути /settings
        guard let url = URL(string: "http://\(device.ipAddress)/settings") else {
            print("❌ Ошибка: не удалось сформировать URL для /settings")
            return
        }
        print("🔍 Отправка GET-запроса на: \(url)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResp = response as? HTTPURLResponse {
                print("📥 Ответ от /settings получен. Код ответа: \(httpResp.statusCode)")
            }
            let decoded = try JSONDecoder().decode(MatrixSettings.self, from: data)
            self.settings = decoded
            print("✅ Настройки успешно декодированы")
            self.connectionStatus = "Подключено к \(device.name)"
        } catch {
            print("❌ Ошибка при запросе /settings: \(error)")
            connectionStatus = "Ошибка соединения"
        }
    }

    func sendCommand(endpoint: String, params: [String: Any]) async {
        print("🔍 sendCommand вызван (POST JSON). Endpoint: \(endpoint), параметры: \(params)")
        
        guard let device = selectedDevice else {
            print("❌ Ошибка: selectedDevice == nil! Команда не может быть отправлена.")
            return
        }
        print("🔍 Текущее выбранное устройство: \(device.name) (\(device.ipAddress))")

        let urlString = "http://\(device.ipAddress)/\(endpoint)"
        guard let url = URL(string: urlString) else {
            print("❌ Ошибка: не удалось создать URL из строки: '\(urlString)'")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            print("❌ Ошибка сериализации в JSON: \(error)")
            return
        }
        
        print("🔍 Отправка POST JSON запроса на URL: \(url)")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Команда успешно отправлена. Код ответа: \(httpResponse.statusCode)")
            } else {
                print("📥 Команда отправлена, но ответ не HTTPURLResponse")
            }
        } catch {
            print("❌ Ошибка отправки команды в блоке catch: \(error)")
        }
    }
    
    func updateBrightnessDay(brightDay: Int) async {
        settings.dayBrightnessPercent = brightDay
        
        await sendCommand(endpoint: "cmd", params: [
            "brightness_day": brightDay
        ])
    }
    
    func updateBrightnessNight(brightNight: Int) async {
        settings.nightBrightnessPercent = brightNight
        
        await sendCommand(endpoint: "cmd", params: [
            "brightness_night": brightNight
        ])
    }
    
    func updateSingleBrightness(brightness: Int) async {
        settings.brightnessPercent = brightness
        
        await sendCommand(endpoint: "cmd", params: [
            "brightness": brightness,
        ])
    }

    func sendText(_ text: String, textColor: Color, bgColor: Color, speed: Int, reps: Int) async {
        let bgComp = UIColor(bgColor).rgbComponents()
        let textComp = UIColor(textColor).rgbComponents()
        
        let formattedText = "[\(bgComp.0),\(bgComp.1),\(bgComp.2)][\(textComp.0),\(textComp.1),\(textComp.2)]\(text)"
        
        await sendCommand(endpoint: "cmd", params: [
            "text": formattedText,
            "text_speed_fps": speed,
            "repeat_count": reps
        ])
    }

//    func updateClockSettings(font: Int, digColor: String, colColor: String, bgColor: String) async {
//        settings.clockFont = font
//        settings.digitsColorHex = digColor
//        settings.colonColorHex = colColor
//        settings.bgColorHex = bgColor
//        await sendCommand(endpoint: "cmd", params: [
//            "clock_font": font,
//            "digits_color_hex": digColor,
//            "colon_color_hex": colColor,
//            "bg_color_hex": bgColor
//        ])
//    }
    
    func updateClockFont(font: Int) async {
        settings.clockFont = font
        await sendCommand(endpoint: "cmd", params: [
            "clock_font": font
        ])
    }
    
    func updateClockDigitsColor(digColor: String) async {
        settings.digitsColorHex = digColor
        await sendCommand(endpoint: "cmd", params: [
            "digits_color_hex": digColor
        ])
    }
    
    func updateClockColonColor(colColor: String) async {
        settings.colonColorHex = colColor
        await sendCommand(endpoint: "cmd", params: [
            "colon_color_hex": colColor
        ])
    }
    
    func updateClockBgColor(bgColor: String) async {
        settings.bgColorHex = bgColor
        await sendCommand(endpoint: "cmd", params: [
            "bg_color_hex": bgColor
        ])
    }
    
    func deviceRestart() async {
        await sendCommand(endpoint: "cmd", params: [
            "action": "restart"
        ])
    }
    
    func deviceResetWifi() async {
        await sendCommand(endpoint: "cmd", params: [
            "action": "reset_wifi"
        ])
    }
    
    func deviceResetSettings() async {
        await sendCommand(endpoint: "cmd", params: [
            "action": "reset_settings"
        ])
    }
    
    func deviceFactoryReset() async {
        await sendCommand(endpoint: "cmd", params: [
            "action": "factory_reset"
        ])
    }
}

extension UIColor {
    func toHex() -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)
        return String(format: "%06X", rgb)
    }
    
    func rgbComponents() -> (Int, Int, Int) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension Color {
    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch sanitizedHex.count {
        case 6: // Формат RGB (например, "540F28" или "#540F28")
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
            self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        default:
            self.init(.black)
        }
    }
}
