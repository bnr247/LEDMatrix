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

    var body: some View {
        TabView {
            TextControlTab(
                textToSend: $textToSend,
                textColor: $textColor,
                textBgColor: $textBgColor,
                scrollSpeed: $scrollSpeedFps,
                scrollReps: $scrollRepeatCount,
                onSend: {
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
            )
            .tabItem {
                Label("Текст", systemImage: "text.bubble")
            }

            BrightnessControlTab(
                brightnessPercent: $brightnessPercent,
                dayBrightnessPercent: $dayBrightnessPercent,
                nightBrightnessPercent: $nightBrightnessPercent,
                onSave: {
                    Task {
                        await manager.updateBrightness(
                            brightDay: Int(dayBrightnessPercent),
                            brightNight: Int(nightBrightnessPercent)
                        )
                    }
                },
                onBrightnessChange: {
                    Task {
                        await manager.updateSingleBrightness(
                            brightness: Int(brightnessPercent)
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
                onSave: {
                    Task {
                        await manager.updateClockSettings(
                            font: clockFont,
                            digColor: UIColor(digitsColor).toHex() ?? "0064FF",
                            colColor: UIColor(colonColor).toHex() ?? "FFFFFF",
                            bgColor: UIColor(bgColor).toHex() ?? "000000"
                        )
                    }
                },
                
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
                Label("Инфо", systemImage: "info.circle")
            }
        }
        .navigationTitle(device.name)
        .onAppear() {
            Task {
                await manager.fetchSettings(for: device)
                brightnessPercent = Double(manager.settings.brightnessPercent)
                dayBrightnessPercent = Double(manager.settings.dayBrightnessPercent)
                nightBrightnessPercent = Double(manager.settings.nightBrightnessPercent)
                clockFont = manager.settings.clockFont
                scrollSpeedFps = Float(manager.settings.scrollSpeedFps)
                scrollRepeatCount = manager.settings.scrollRepeatCount
                
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
            Button("Отправить") {
                onSend()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct BrightnessControlTab: View {
    @Binding var brightnessPercent: Double
    @Binding var dayBrightnessPercent: Double
    @Binding var nightBrightnessPercent: Double
    var onSave: () -> Void
    var onBrightnessChange: () -> Void
    
    var body: some View {
        Form {
            Section(header: Text("Уровень яркости")) {
                VStack(alignment: .leading) {
                    Text("Текущая яркость: \(Int(brightnessPercent))")
                    Slider(value: $brightnessPercent, in: 0...100, step: 5)
                        .onChange(of: brightnessPercent) { oldValue, newValue in
                                            // Срабатывает непрерывно при перетаскивании
                            onBrightnessChange()
                                        }
                    //, onEditingChanged: { isEditing in
//                        if isEditing {
//                            
//                        } else {
//                            onBrightnessChange()
//                        }
//                    }
//                    )
                }
                
                VStack(alignment: .leading) {
                    Text("Дневная яркость: \(Int(dayBrightnessPercent))")
                    Slider(value: $dayBrightnessPercent, in: 0...100, step: 5)
                }
                VStack(alignment: .leading) {
                    Text("Ночная яркость: \(Int(nightBrightnessPercent))")
                    Slider(value: $nightBrightnessPercent, in: 0...100, step: 5)
                }
            }
            Button("Применить настройки") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ClockSettingsTab: View {
    @Binding var clockFont: Int
    @Binding var digitsColorHex: Color
    @Binding var colonColorHex: Color
    @Binding var bgColorHex: Color
    var onSave: () -> Void
    var onFontChange: () -> Void
    var onDigitsColorChange: () -> Void
    var onColonColorChange: () -> Void
    var onBgColorChange: () -> Void

    var body: some View {
        Form {
            Section(header: Text("Шрифт часов")) {
                Picker("Шрифт", selection: $clockFont) {
                    Text("Default Horizontal (3x5)").tag(0)
                    Text("Simple Horizontal (3x7)").tag(1)
                    Text("Narrow Horizontal (3x11)").tag(2)
                    Text("Simple Vertical (5x7)").tag(3)
                    Text("OCR-A Vertical (5x7)").tag(4)
                    Text("Atari Vertical (5x7)").tag(5)
                }
            }
            Section(header: Text("Цветовая гамма часов")) {
                ColorPicker("Цвет цифр", selection: $digitsColorHex)
                    .onChange(of: digitsColorHex) { oldValue, newValue in
                        onDigitsColorChange()
                    }
                ColorPicker("Цвет разделителя", selection: $colonColorHex)
                    .onChange(of: colonColorHex) { oldValue, newValue in
                        onColonColorChange()
                    }
                ColorPicker("Цвет фона", selection: $bgColorHex)
                    .onChange(of: bgColorHex) { oldValue, newValue in
                        onBgColorChange()
                    }
            }
            Button("Обновить настройки часов") {
                onSave()
            }
            .buttonStyle(.glassProminent)
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
    var body: some View {
        Form {
        }
    }
}
