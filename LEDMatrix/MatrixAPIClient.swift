import Foundation
import Network
import Combine

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
    var dayBrightness: Int = 64
    var nightBrightness: Int = 16
    var brightnessControl: Int = 0
    var dayStartMinute: Int = 480
    var nightStartMinute: Int = 0
    var deviceMode: Int = 4
    var clockFont: Int = 0
    var scrollSpeed: Float = 25.0
    var scrollReps: Int = 3
    var digHex: String = "0064FF"
    var colHex: String = "FFFFFF"
    var bgHex: String = "000000"
    var showNameText: Bool = true

    enum CodingKeys: String, CodingKey {
        case dayBrightness = "bright_day"
        case nightBrightness = "bright_night"
        case brightnessControl = "bright_ctrl"
        case dayStartMinute = "day_start"
        case nightStartMinute = "night_start"
        case deviceMode = "device_mode"
        case clockFont = "clock_font"
        case scrollSpeed = "scroll_speed"
        case scrollReps = "scroll_reps"
        case digHex = "dig_hex"
        case colHex = "col_hex"
        case bgHex = "bg_hex"
        case showNameText = "show_name_text"
    }
}

@MainActor
class MatrixManager: ObservableObject {
    @Published var discoveredDevices: [LEDMatrixDevice] = []
    @Published var selectedDevice: LEDMatrixDevice?
    @Published var settings = MatrixSettings()
    @Published var isScanning = false
    @Published var connectionStatus = "Не подключено"

    private var browser: NWBrowser?

    func startScanning() {
        discoveredDevices.removeAll()
        isScanning = true
        connectionStatus = "Поиск устройств..."

        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let browser = NWBrowser(for: NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: "local."), using: parameters)
        
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            for result in results {
                if case let .service(name, _, _, _) = result.endpoint {
                    if name.hasPrefix("ledmatrix-") {
                        // Теперь метод можно вызывать из неизолированного замыкания сети
                        self.resolveEndpoint(endpoint: result.endpoint, name: name)
                    }
                }
            }
        }
        
        browser.start(queue: .main)
        self.browser = browser

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.stopScanning()
        }
    }

    func stopScanning() {
        browser?.cancel()
        browser = nil
        isScanning = false
        if discoveredDevices.isEmpty {
            connectionStatus = "Устройства не найдены. Введите IP вручную."
        } else {
            connectionStatus = "Найдено устройств: \(discoveredDevices.count)"
        }
    }

    // Пометка nonisolated разрешает вызывать метод из сетевых callback-ов вне MainActor
    nonisolated private func resolveEndpoint(endpoint: NWEndpoint, name: String) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            if case .ready = state {
                if case let .hostPort(host, _) = connection.endpoint {
                    let ipStr = "\(host)"
                    let device = LEDMatrixDevice(name: name, ipAddress: ipStr)
                    Task { @MainActor in
                        if !self.discoveredDevices.contains(where: { $0.ipAddress == ipStr }) {
                            self.discoveredDevices.append(device)
                        }
                    }
                }
                connection.cancel()
            }
        }
        connection.start(queue: .global())
    }

    func fetchSettings(for device: LEDMatrixDevice) async {
        guard let url = URL(string: "http://\(device.ipAddress)/settings") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(MatrixSettings.self, from: data)
            self.settings = decoded
            self.selectedDevice = device
            self.connectionStatus = "Подключено к \(device.name)"
        } catch {
            print("Ошибка загрузки настроек: \(error)")
            connectionStatus = "Ошибка соединения"
        }
    }

    func sendCommand(endpoint: String, params: [String: String]) async {
        guard let device = selectedDevice,
              var components = URLComponents(string: "http://\(device.ipAddress)/\(endpoint)") else { return }
        
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { return }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Команда успешно отправлена")
            }
        } catch {
            print("Ошибка отправки команды: \(error)")
        }
    }

    func updateBrightness(day: Int, night: Int, controlMode: Int) async {
        settings.dayBrightness = day
        settings.nightBrightness = night
        settings.brightnessControl = controlMode
        await sendCommand(endpoint: "cmd", params: [
            "bright_day": "\(day)",
            "bright_night": "\(night)",
            "bright_ctrl": "\(controlMode)"
        ])
    }

    func sendText(_ text: String, colorHex: String, speed: Float, reps: Int) async {
        await sendCommand(endpoint: "cmd", params: [
            "text": text,
            "color": colorHex,
            "speed": "\(speed)",
            "reps": "\(reps)"
        ])
    }

    func updateClockSettings(font: Int, digColor: String, colColor: String, bgColor: String) async {
        settings.clockFont = font
        settings.digHex = digColor
        settings.colHex = colColor
        settings.bgHex = bgColor
        await sendCommand(endpoint: "cmd", params: [
            "clock_font": "\(font)",
            "dig_hex": digColor,
            "col_hex": colColor,
            "bg_hex": bgColor
        ])
    }
}
