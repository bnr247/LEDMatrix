import SwiftUI

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
//                onSave: {
//                    Task {
//                        await manager.updateClockSettings(
//                            font: clockFont,
//                            digColor: UIColor(digitsColor).toHex() ?? "0064FF",
//                            colColor: UIColor(colonColor).toHex() ?? "FFFFFF",
//                            bgColor: UIColor(bgColor).toHex() ?? "000000"
//                        )
//                    }
//                }
            )
            .tabItem {
                Label("Настройки", systemImage: "gearshape.2.fill")
            }
            InfoTab(
                hostName: $hostName,
                ipAddress: $ipAddress,
                macAddress: $macAddress,
                hwVersion: $hwVersion,
                fwVersion: $fwVersion,
                bootCount: $bootCount,
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
                }
            )
            .tabItem {
                Label("Инфо", systemImage: "info.circle")
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
                
                // Конвертируем полученные строки с HEX-цветами в SwiftUI Color для интерфейса
                digitsColor = Color(hex: manager.settings.digitsColorHex)
                colonColor = Color(hex: manager.settings.colonColorHex)
                bgColor = Color(hex: manager.settings.bgColorHex)
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
    var body: some View {
        Form {
        }
    }
}

struct InfoTab: View {
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
    
    
    @State private var showRestartConfirmation = false
    @State private var activeAction: DeviceAction?
    
    var body: some View {
        Form {
            Section(header: Text("Об устройстве")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Имя хоста: \(hostName)")
                    Text("IP адрес: \(ipAddress)")
                    Text("MAC адрес: \(macAddress)")
                    Text("Версия HW: \(hwVersion)")
                    Text("Версия FW: \(fwVersion)")
                    Text("Запусков: \(bootCount)")
                }
               // .listRowBackground(Color.clear)
            }
            
            Section {
                VStack(spacing: 12) { // Задаем отступ между кнопками
                    
                    // Кнопка 1: Перезагрузка
                    actionButton(title: "Перезагрузить", color: .blue) {
                        activeAction = .restart
                    }
                    
                    // Кнопка 2: Выключение
                    actionButton(title: "Сброс WiFi", color: .yellow) {
                        activeAction = .resetWifi
                    }
                    
                    // Кнопка 3: Обновить прошивку
                    actionButton(title: "Сброс настроек", color: .orange) {
                        activeAction = .resetSettings
                    }
                    
                    // Кнопка 4: Сброс
                    actionButton(title: "Factory reset", color: .red) {
                        activeAction = .factoryReset
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        // 4. ОДИН алерт, который реагирует на появление выбранного действия (item)
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
        case .factoryReset: return "Сброс до заводских настроек"
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

