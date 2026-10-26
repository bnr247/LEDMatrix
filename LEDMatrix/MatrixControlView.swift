import SwiftUI
import CryptoKit

struct MatrixControlView: View {
    @ObservedObject var manager: MatrixManager
    let device: LEDMatrixDevice
    
    @State private var dayBrightnessPercent: Double = 0
    @State private var nightBrightnessPercent: Double = 0
    @State private var brightnessPercent: Double = 0

    @State private var textToSend = ""
    @State private var textColor = Color.purple
    @State private var textBgColor = Color.black
    @State private var scrollSpeedFps: Float = 25.0
    @State private var scrollRepeatCount = 3
    
    @State private var clockFont: Int = 0
    @State private var digitsColor = Color.blue
    @State private var colonColor = Color.white
    @State private var bgColor = Color.black
    
    @State private var macAddress = ""
    @State private var hostName = ""
    @State private var ipAddress = ""
    @State private var hwVersion = ""
    @State private var fwVersion = ""
    
    @State private var wifiSsid = ""
    @State private var wifiPasswordSet = false
    @State private var wifiPassword = ""
    
    @State private var divoomUsername = ""
    @State private var divoomPasswordSet = false
    @State private var divoomPassword = ""
    
    @State private var showTextUsername = false
    
    @State private var bootCount = 0
    

    var body: some View {
        TabView {
            TextControlTab(
                textToSend: $textToSend,
                textColor: $textColor,
                textBgColor: $textBgColor,
                scrollSpeed: $scrollSpeedFps,
                scrollReps: $scrollRepeatCount,
                onSend: {
                    if (textToSend != "") {
                        Task {
                            await manager.sendText(
                                textToSend,
                                textColor: textColor,
                                bgColor: textBgColor,
                                speed: Int(scrollSpeedFps),
                                reps: scrollRepeatCount
                            )
                        }
                    }
                }
            )
            .tabItem {
                Label("Текст", systemImage: "text.bubble")
            }

            BrightnessControlTab(
                brightnessPercent: $brightnessPercent,
                dayBrightnessPercent: $dayBrightnessPercent,
                nightBrightnessPercent: $nightBrightnessPercent,
                
                onBrightnessChange: {
                    Task {
                        await manager.updateSingleBrightness(
                            brightness: Int(brightnessPercent)
                        )
                    }
                },
                onDayBrightnessChange: {
                    Task {
                        await manager.updateBrightnessDay(
                            brightDay: Int(dayBrightnessPercent)
                        )
                    }
                },
                onNightBrightnessChange: {
                    Task {
                        await manager.updateBrightnessNight(
                            brightNight: Int(nightBrightnessPercent)
                        )
                    }
                }
            )
            .tabItem {
                Label("Яркость", systemImage: "sun.max")
            }

            ClockSettingsTab(
                clockFont: $clockFont,
                digitsColorHex: $digitsColor,
                colonColorHex: $colonColor,
                bgColorHex: $bgColor,
                
                onFontChange: {
                    Task {
                        await manager.updateClockFont(
                            font: clockFont
                        )
                    }
                },
                onDigitsColorChange: {
                    Task {
                        await manager.updateClockDigitsColor(
                            digColor: UIColor(digitsColor).toHex() ?? "0064FF"
                        )
                    }
                },
                onColonColorChange: {
                    Task {
                        await manager.updateClockColonColor(
                            colColor: UIColor(colonColor).toHex() ?? "0064FF"
                        )
                    }
                },
                onBgColorChange: {
                    Task {
                        await manager.updateClockBgColor(
                            bgColor: UIColor(bgColor).toHex() ?? "0064FF"
                        )
                    }
                }
            )
            .tabItem {
                Label("Часы", systemImage: "clock")
            }
            
            SettingsTab(
                hostName: $hostName,
                ipAddress: $ipAddress,
                macAddress: $macAddress,
                hwVersion: $hwVersion,
                fwVersion: $fwVersion,
                bootCount: $bootCount,
                showTextUsername: $showTextUsername,
                wifiSsid: $wifiSsid,
                wifiPasswordSet: $wifiPasswordSet,
                wifiPassword: $wifiPassword,
                divoomUsername: $divoomUsername,
                divoomPasswordSet: $divoomPasswordSet,
                divoomPassword: $divoomPassword,
                
                onDeviceRestart: {
                    Task {
                        await manager.deviceRestart()
                    }
                },
                onDeviceResetWifi: {
                    Task {
                        await manager.deviceResetWifi()
                    }
                },
                onDeviceResetSettings: {
                    Task {
                        await manager.deviceResetSettings()
                    }
                },
                onDeviceFactoryReset: {
                    Task {
                        await manager.deviceFactoryReset()
                    }
                },
                onSaveWifiSsid: {
                    Task {
                        await manager.updateWifiSsid(
                            ssid: wifiSsid
                        )
                    }
                },
                onSaveWifiPassword: {
                    Task {
                        await manager.updateWifiPassword(
                            password: wifiPassword
                        )
                    }
                },
                onSaveDivoomUsername: {
                    Task {
                        await manager.updateDivoomEmail(
                            email: divoomUsername
                        )
                    }
                },
                onSaveDivoomPassword: {
                    Task {
                        await manager.updateDivoomPassword(
                            password: divoomPassword
                        )
                    }
                },
                onSaveShowTextUsername: {
                    Task {
                        await manager.updateShowTextUsername(
                            showUsername: showTextUsername
                        )
                    }
                }
            )
            .tabItem {
                Label("Настройки", systemImage: "gearshape.2.fill")
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            Task {
                await manager.fetchSettings(for: device)
                brightnessPercent = Double(manager.settings.brightnessPercent)
                dayBrightnessPercent = Double(manager.settings.dayBrightnessPercent)
                nightBrightnessPercent = Double(manager.settings.nightBrightnessPercent)
                clockFont = manager.settings.clockFont
                scrollSpeedFps = Float(manager.settings.scrollSpeedFps)
                scrollRepeatCount = manager.settings.scrollRepeatCount
                
                macAddress = manager.settings.macAddress
                hostName = manager.settings.hostName
                ipAddress = manager.settings.ipAddress
                hwVersion = manager.settings.hwVersion
                fwVersion = manager.settings.fwVersion
                
                bootCount = manager.settings.bootCount
                showTextUsername = manager.settings.showNameText
                
                divoomUsername = manager.settings.divoomEmail
                divoomPasswordSet = manager.settings.divoomPasswordSet
                
                // Конвертируем полученные строки с HEX-цветами в SwiftUI Color для интерфейса
                digitsColor = Color(hex: manager.settings.digitsColorHex)
                colonColor = Color(hex: manager.settings.colonColorHex)
                bgColor = Color(hex: manager.settings.bgColorHex)
            }
            Task {
                await manager.fetchWifiSettings(for: device)
                wifiSsid = manager.wifiSettings.ssid
                wifiPasswordSet = manager.wifiSettings.passwordSet
            }
        }
    }
}

struct TextControlTab: View {
    @Binding var textToSend: String
    @Binding var textColor: Color
    @Binding var textBgColor: Color
    @Binding var scrollSpeed: Float
    @Binding var scrollReps: Int
    var onSend: () -> Void

    var body: some View {
        Form {
            Section(header: Text("Бегущая строка")) {
                TextField("Введите сообщение...", text: $textToSend)
                ColorPicker("Цвет текста", selection: $textColor)
                ColorPicker("Цвет фона", selection: $textBgColor)
            }
            Section(header: Text("Параметры анимации")) {
                VStack(alignment: .leading) {
                    Text("Скорость: \(Int(scrollSpeed))")
                    Slider(value: $scrollSpeed, in: 10...100, step: 5)
                }
                Stepper("Повторов: \(scrollReps)", value: $scrollReps, in: 1...10)
            }
            Button(action: {
                onSend()
                hideKeyboard()
            }) {Text("Отправить")
                    .bold()
                    // Растягиваем текст на всю доступную ширину внутри кнопки
                    .frame(maxWidth: .infinity)
                    // Настраиваем внутренние отступы для высоты (размера) кнопки
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
        }
        .onTapGesture {
            hideKeyboard()
        }
        .onSubmit {
            onSend()
            hideKeyboard()
        }
    }
}

struct BrightnessControlTab: View {
    @Binding var brightnessPercent: Double
    @Binding var dayBrightnessPercent: Double
    @Binding var nightBrightnessPercent: Double
    var onBrightnessChange: () -> Void
    var onDayBrightnessChange: () -> Void
    var onNightBrightnessChange: () -> Void
    
    var body: some View {
        Form {
            Section(header: Text("Уровень яркости")) {
                VStack(alignment: .leading) {
                    Text("Текущая яркость: \(Int(brightnessPercent))")
                    Slider(value: $brightnessPercent, in: 0...100, step: 5)
                        .onChange(of: brightnessPercent) { _, _ in
                            onBrightnessChange()
                        }
                }
                VStack(alignment: .leading) {
                    Text("Дневная яркость: \(Int(dayBrightnessPercent))")
                    Slider(value: $dayBrightnessPercent, in: 0...100, step: 5)
                        .onChange(of: dayBrightnessPercent) { _, _ in
                            onDayBrightnessChange()
                        }
                }
                VStack(alignment: .leading) {
                    Text("Ночная яркость: \(Int(nightBrightnessPercent))")
                    Slider(value: $nightBrightnessPercent, in: 0...100, step: 5)
                        .onChange(of: nightBrightnessPercent) { _, _ in
                            onNightBrightnessChange()
                        }
                }
            }
        }
    }
}

struct ClockSettingsTab: View {
    @Binding var clockFont: Int
    @Binding var digitsColorHex: Color
    @Binding var colonColorHex: Color
    @Binding var bgColorHex: Color
    var onFontChange: () -> Void
    var onDigitsColorChange: () -> Void
    var onColonColorChange: () -> Void
    var onBgColorChange: () -> Void

    var body: some View {
        Form {
            Section(header: Text("Внешний вид часов")) {
                Picker("Шрифт", selection: $clockFont) {
                    Text("Default Horizontal (3x5)").tag(0)
                    Text("Simple Horizontal (3x7)").tag(1)
                    Text("Narrow Horizontal (3x11)").tag(2)
                    Text("Simple Vertical (5x7)").tag(3)
                    Text("OCR-A Vertical (5x7)").tag(4)
                    Text("Atari Vertical (5x7)").tag(5)
                }
                .onChange(of: clockFont) { oldValue, newValue in
                    onFontChange()
                }
            }
            Section(header: Text("Цветовая гамма часов")) {
                ColorPicker("Цвет цифр", selection: $digitsColorHex)
                    .onChange(of: digitsColorHex) { _, _ in
                        onDigitsColorChange()
                    }
                ColorPicker("Цвет разделителя", selection: $colonColorHex)
                    .onChange(of: colonColorHex) { _, _ in
                        onColonColorChange()
                    }
                ColorPicker("Цвет фона", selection: $bgColorHex)
                    .onChange(of: bgColorHex) { _, _ in
                        onBgColorChange()
                    }
            }
        }
    }
}

struct SettingsTab: View {
    @Binding var hostName: String
    @Binding var ipAddress: String
    @Binding var macAddress: String
    @Binding var hwVersion: String
    @Binding var fwVersion: String
    @Binding var bootCount: Int
    @Binding var showTextUsername: Bool
    
    @Binding var wifiSsid: String
    @Binding var wifiPasswordSet: Bool
    @Binding var wifiPassword: String
    
    @Binding var divoomUsername: String
    @Binding var divoomPasswordSet: Bool
    @Binding var divoomPassword: String
    
    var onDeviceRestart: () -> Void
    var onDeviceResetWifi: () -> Void
    var onDeviceResetSettings: () -> Void
    var onDeviceFactoryReset: () -> Void
    
    var onSaveWifiSsid: () -> Void
    var onSaveWifiPassword: () -> Void
    
    var onSaveDivoomUsername: () -> Void
    var onSaveDivoomPassword: () -> Void
    
    var onSaveShowTextUsername: ()-> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Панель управления")) {
                    NavigationLink(destination: SettingsGeneralFormView(showTextUsername: $showTextUsername, onSaveShowTextUsername: onSaveShowTextUsername)) {
                        Label("Обшие", systemImage: "sparkles.tv")
                    }
                    
                    NavigationLink(destination: SettingsWifiFormView(wifiSsid: $wifiSsid, wifiPasswordSet: $wifiPasswordSet, wifiPassword: $wifiPassword, onSaveWifiSsid: onSaveWifiSsid, onSaveWifiPassword: onSaveWifiPassword)) {
                        Label("Настройки Wifi", systemImage: "wifi")
                    }
            
                    NavigationLink(destination: SettingsDivoomFormView(divoomUsername: $divoomUsername, divoomPasswordSet: $divoomPasswordSet, divoomPassword: $divoomPassword, onSaveDivoomUsername: onSaveDivoomUsername, onSaveDivoomPassword: onSaveDivoomPassword)) {
                        Label("Настройки Divoom", systemImage: "globe")
                    }

                    
                    
                    
//                    NavigationLink(destination: SettingsDivoomFormView()) {
//                        Label("Настройки Divoom", systemImage: "globe")
//                    }
                    
                    NavigationLink(destination: SettingsInfoFormView(
                        hostName: $hostName,
                        ipAddress: $ipAddress,
                        macAddress: $macAddress,
                        hwVersion: $hwVersion,
                        fwVersion: $fwVersion,
                        bootCount: $bootCount,
                        onDeviceRestart: onDeviceRestart,
                        onDeviceResetWifi: onDeviceResetWifi,
                        onDeviceResetSettings: onDeviceResetSettings,
                        onDeviceFactoryReset: onDeviceFactoryReset
                    )) {
                        Label("Об устройстве", systemImage: "info.circle")
                    }
                    
//                    NavigationLink(destination: SettingsDivoomFormView()) {
//                        Label("Логи", systemImage: "text.document")
//                    }
                }
            }
            .navigationTitle("Панель управления")
        }
    }
}

struct SettingsGeneralFormView: View {
    @Binding var showTextUsername: Bool
    
    var onSaveShowTextUsername: () -> Void
    
    var body: some View {
            Form {
                Section(header: Text("Данные для подключения")) {
                    // Передаем текст прямо в Toggle, SwiftUI сам выровняет его по левому краю, а тумблер — по правому
                    Toggle("Отображать имя из Telegram", isOn: $showTextUsername)
                        // Отслеживаем изменение состояния
                        .onChange(of: showTextUsername) { _, newValue in
                            // Вызываем метод сохранения при каждом переключении
                            onSaveShowTextUsername()
                        }
                }
            }
        }
}


struct SettingsInfoFormView: View {
    @Binding var hostName: String
    @Binding var ipAddress: String
    @Binding var macAddress: String
    @Binding var hwVersion: String
    @Binding var fwVersion: String
    @Binding var bootCount: Int
    
    var onDeviceRestart: () -> Void
    var onDeviceResetWifi: () -> Void
    var onDeviceResetSettings: () -> Void
    var onDeviceFactoryReset: () -> Void
    
    @State private var activeAction: DeviceAction?
    
    var body: some View {
        Form {
            Section {
                row(title: "Имя хоста", value: hostName)
                row(title: "IP адрес", value: ipAddress)
                row(title: "MAC адрес", value: macAddress)
                row(title: "Версия HW", value: hwVersion)
                row(title: "Версия FW", value: fwVersion)
                row(title: "Запусков", value: "\(bootCount)")
            }
            Section {
                VStack(spacing: 16) {
                    
                    // Кнопка 1: Перезагрузка
                    actionButton(title: "Перезагрузить", color: .blue) {
                        activeAction = .restart
                    }
                    
                    // Кнопка 2: Сброс WiFi
                    actionButton(title: "Сброс WiFi", color: .orange) {
                        activeAction = .resetWifi
                    }
                    
                    // Кнопка 3: Сброс настроек
                    actionButton(title: "Сброс настроек", color: .orange) {
                        activeAction = .resetSettings
                    }
                    
                    // Кнопка 4: Factory reset
                    actionButton(title: "Factory reset", color: .red) {
                        activeAction = .factoryReset
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .alert(item: $activeAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .destructive(Text("Подтвердить")) {
                    // 5. Выполняем нужное замыкание в зависимости от контекста
                    switch action {
                    case .restart: onDeviceRestart()
                    case .resetWifi: onDeviceResetWifi()
                    case .resetSettings: onDeviceResetSettings()
                    case .factoryReset: onDeviceFactoryReset()
                    }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
        .navigationTitle("Информация об устройстве")
    }
    
    private func row(title: String, value: String) -> some View {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
}

struct SettingsWifiFormView: View {
    @Binding var wifiSsid: String
    @Binding var wifiPasswordSet: Bool
    @Binding var wifiPassword: String
    
    var onSaveWifiSsid: () -> Void
    var onSaveWifiPassword: () -> Void
    
    // Локальное состояние для ввода данных в поля
    @State private var localSsid: String = ""
    @State private var localPassword: String = ""
    
    // Отслеживание фокуса на поле пароля
    @FocusState private var isPasswordFocused: Bool
    
    // Заглушка, имитирующая сохраненный пароль
    private let passwordPlaceholder = "••••••••••••••••"
    
    var body: some View {
        Form {
            Section(header: Text("Данные для подключения")) {
                HStack {
                    Text("SSID")
                    Spacer()
                    TextField("", text: $localSsid)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled(true)
                }
                
                HStack {
                    Text("Пароль")
                    Spacer()
                    SecureField("", text: $localPassword)
                        .multilineTextAlignment(.trailing)
                        .focused($isPasswordFocused)
                }
            }
            
            Section {
                Button(action: {
                    isPasswordFocused = false
                    
                    // Создаем флаг, чтобы понять, изменилось ли что-то вообще
                    let ssidChanged = isSsidChanged
                    let passwordChanged = isPasswordChanged
                    
                    // 1. Если изменился SSID — обновляем биндинг и вызываем первый метод
                    if ssidChanged {
                        wifiSsid = localSsid
                        onSaveWifiSsid()
                    }
                    
                    // 2. Если изменился пароль — обновляем биндинг и вызываем второй метод
                    if passwordChanged {
                        wifiPassword = localPassword
                        onSaveWifiPassword()
                    }
                }) {
                    Text("Сохранить")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isSsidChanged && !isPasswordChanged)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Настройки WiFi")
        .onAppear {
            // Инициализируем локальные переменные при появлении экрана
            localSsid = wifiSsid
            setupInitialPassword()
        }
        .onChange(of: isPasswordFocused) { _, focused in
            if focused {
                if wifiPasswordSet && localPassword == passwordPlaceholder {
                    localPassword = ""
                }
            } else {
                if wifiPasswordSet && localPassword.isEmpty {
                    localPassword = passwordPlaceholder
                }
            }
        }
    }
    
    // Проверка: изменился ли SSID относительно исходного
    private var isSsidChanged: Bool {
        localSsid != wifiSsid && !localSsid.isEmpty
    }
    
    // Проверка: изменился ли пароль относительно заглушки или пустоты
    private var isPasswordChanged: Bool {
        if wifiPasswordSet {
            return localPassword != passwordPlaceholder && !localPassword.isEmpty
        } else {
            return !localPassword.isEmpty
        }
    }
    
    private func setupInitialPassword() {
        if wifiPasswordSet {
            localPassword = passwordPlaceholder
        } else {
            localPassword = ""
        }
    }
}

struct SettingsDivoomFormView: View {
    @Binding var divoomUsername: String
    @Binding var divoomPasswordSet: Bool
    @Binding var divoomPassword: String
    
    var onSaveDivoomUsername: () -> Void
    var onSaveDivoomPassword: () -> Void
    
    // Локальное состояние для ввода данных в поля
    @State private var localUsername: String = ""
    @State private var localPassword: String = ""
    
    // Отслеживание фокуса на поле пароля
    @FocusState private var isPasswordFocused: Bool
    
    // Заглушка, имитирующая сохраненный пароль
    private let passwordPlaceholder = "••••••••••••••••"
    
    var body: some View {
        Form {
            Section(header: Text("Учетные данные Divoom")) {
                HStack {
                    Text("Email")
                    Spacer()
                    TextField("", text: $localUsername)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled(true)
                }
                
                HStack {
                    Text("Пароль")
                    Spacer()
                    SecureField("", text: $localPassword)
                        .multilineTextAlignment(.trailing)
                        .focused($isPasswordFocused)
                }
            }
            
            Section {
                Button(action: {
                    isPasswordFocused = false
                    
                    // Создаем флаг, чтобы понять, изменилось ли что-то вообще
                    let ssidChanged = isUsernameChanged
                    let passwordChanged = isPasswordChanged
                    
                    // 1. Если изменился SSID — обновляем биндинг и вызываем первый метод
                    if ssidChanged {
                        divoomUsername = localUsername
                        onSaveDivoomUsername()
                    }
                    
                    // 2. Если изменился пароль — обновляем биндинг и вызываем второй метод
                    if passwordChanged {
                        divoomPassword = localPassword
                        onSaveDivoomPassword()
                    }
                }) {
                    Text("Сохранить")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isUsernameChanged && !isPasswordChanged)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Настройки Divoom")
        .onAppear {
            // Инициализируем локальные переменные при появлении экрана
            localUsername = divoomUsername
            setupInitialPassword()
        }
        .onChange(of: isPasswordFocused) { _, focused in
            if focused {
                if divoomPasswordSet && localPassword == passwordPlaceholder {
                    localPassword = ""
                }
            } else {
                if divoomPasswordSet && localPassword.isEmpty {
                    localPassword = passwordPlaceholder
                }
            }
        }
    }
    
    // Проверка: изменился ли SSID относительно исходного
    private var isUsernameChanged: Bool {
        localUsername != divoomUsername && !localUsername.isEmpty
    }
    
    // Проверка: изменился ли пароль относительно заглушки или пустоты
    private var isPasswordChanged: Bool {
        if divoomPasswordSet {
            return localPassword != passwordPlaceholder && !localPassword.isEmpty
        } else {
            return !localPassword.isEmpty
        }
    }
    
    private func setupInitialPassword() {
        if divoomPasswordSet {
            localPassword = passwordPlaceholder
        } else {
            localPassword = ""
        }
    }
}

enum DeviceAction: Identifiable {
    case restart
    case resetWifi
    case resetSettings
    case factoryReset
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .restart: return "Перезагрузка"
        case .resetWifi: return "Сброс настроек WiFi"
        case .resetSettings: return "Сброс всех настроек"
        case .factoryReset: return "Factory reset"
        }
    }
    
    var message: String {
        switch self {
        case .restart: return "Вы уверены, что хотите перезагрузить устройство?"
        case .resetWifi: return "Вы уверены, что хотите сбросить настройки WiFi?"
        case .resetSettings: return "Это действие удалит все настройки без возможности восстановления"
        case .factoryReset: return "Это действие удалит все настройки и сбросит устройство до исходного состояния"
        }
    }
}

@ViewBuilder
private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
    .buttonStyle(.borderedProminent)
    .tint(color)
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension String {
    func toMD5() -> String {
        // 1. Переводим строку в Data (набор байт)
        guard let data = self.data(using: .utf8) else { return "" }
        
        // 2. Хэшируем с помощью CryptoKit
        let digest = Insecure.MD5.hash(data: data)
        
        // 3. Преобразуем результат в шестнадцатеричную строку (hex)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

