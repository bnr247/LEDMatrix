import SwiftUI

struct MatrixControlView: View {
    @ObservedObject var manager: MatrixManager // Исправлено: добавлен символ @
    let device: LEDMatrixDevice

    @State private var textToSend = ""
    @State private var textColor = Color.blue
    @State private var scrollSpeed: Float = 25.0
    @State private var scrollReps: Int = 3
    
    @State private var dayBrightness: Double = 64
    @State private var nightBrightness: Double = 16
    @State private var brightnessControlMode: Int = 0
    
    @State private var selectedFont: Int = 0
    @State private var digitsColor = Color.cyan
    @State private var colonColor = Color.white
    @State private var bgColor = Color.black

    var body: some View {
        TabView {
            TextControlTab(
                textToSend: $textToSend,
                textColor: $textColor,
                scrollSpeed: $scrollSpeed,
                scrollReps: $scrollReps,
                onSend: {
                    let hex = UIColor(textColor).toHex() ?? "0064FF"
                    Task {
                        await manager.sendText(textToSend, colorHex: hex, speed: scrollSpeed, reps: scrollReps)
                    }
                }
            )
            .tabItem {
                Label("Текст", systemImage: "text.bubble")
            }

            BrightnessControlTab(
                dayBrightness: $dayBrightness,
                nightBrightness: $nightBrightness,
                brightnessControlMode: $brightnessControlMode,
                onSave: {
                    Task {
                        await manager.updateBrightness(
                            day: Int(dayBrightness),
                            night: Int(nightBrightness),
                            controlMode: brightnessControlMode
                        )
                    }
                }
            )
            .tabItem {
                Label("Яркость", systemImage: "sun.max")
            }

            ClockSettingsTab(
                selectedFont: $selectedFont,
                digitsColor: $digitsColor,
                colonColor: $colonColor,
                bgColor: $bgColor,
                onSave: {
                    Task {
                        await manager.updateClockSettings(
                            font: selectedFont,
                            digColor: UIColor(digitsColor).toHex() ?? "0064FF",
                            colColor: UIColor(colonColor).toHex() ?? "FFFFFF",
                            bgColor: UIColor(bgColor).toHex() ?? "000000"
                        )
                    }
                }
            )
            .tabItem {
                Label("Часы", systemImage: "clock")
            }
        }
        .navigationTitle(device.name)
        .onAppear {
            dayBrightness = Double(manager.settings.dayBrightness)
            nightBrightness = Double(manager.settings.nightBrightness)
            brightnessControlMode = manager.settings.brightnessControl
            selectedFont = manager.settings.clockFont
            scrollSpeed = manager.settings.scrollSpeed
            scrollReps = manager.settings.scrollReps
        }
    }
}

struct TextControlTab: View {
    @Binding var textToSend: String
    @Binding var textColor: Color
    @Binding var scrollSpeed: Float
    @Binding var scrollReps: Int
    var onSend: () -> Void

    var body: some View {
        Form {
            Section(header: Text("Текст для прокрутки")) {
                TextField("Введите сообщение...", text: $textToSend)
                ColorPicker("Цвет текста", selection: $textColor)
            }
            Section(header: Text("Параметры анимации")) {
                VStack(alignment: .leading) {
                    Text("Скорость (мс/кадр): \(Int(scrollSpeed))")
                    Slider(value: $scrollSpeed, in: 10...100, step: 5)
                }
                Stepper("Повторов: \(scrollReps)", value: $scrollReps, in: 1...10)
            }
            Button("Отправить на матрицу") {
                onSend()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct BrightnessControlTab: View {
    @Binding var dayBrightness: Double
    @Binding var nightBrightness: Double
    @Binding var brightnessControlMode: Int
    var onSave: () -> Void

    var body: some View {
        Form {
            Section(header: Text("Режим управления яркостью")) {
                Picker("Режим", selection: $brightnessControlMode) {
                    Text("Авто (по времени)").tag(0)
                    Text("Принудительно День").tag(1)
                    Text("Принудительно Ночь").tag(2)
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text("Уровни яркости (8 - 192)")) {
                VStack(alignment: .leading) {
                    Text("Дневная яркость: \(Int(dayBrightness))")
                    Slider(value: $dayBrightness, in: 8...192, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("Ночная яркость: \(Int(nightBrightness))")
                    Slider(value: $nightBrightness, in: 8...192, step: 1)
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
    @Binding var selectedFont: Int
    @Binding var digitsColor: Color
    @Binding var colonColor: Color
    @Binding var bgColor: Color
    var onSave: () -> Void

    var body: some View {
        Form {
            Section(header: Text("Шрифт часов")) {
                Picker("Шрифт", selection: $selectedFont) {
                    Text("Default Hor (3x5)").tag(0)
                    Text("Simple Hor (3x7)").tag(1)
                    Text("Narrow Hor (3x11)").tag(2)
                    Text("Simple Vert (5x7)").tag(3)
                    Text("OCR Vert (5x7)").tag(4)
                    Text("Atari Vert (5x7)").tag(5)
                }
            }
            Section(header: Text("Цветовая гамма часов")) {
                ColorPicker("Цвет цифр", selection: $digitsColor)
                ColorPicker("Цвет разделителя (:)", selection: $colonColor)
                ColorPicker("Цвет фона", selection: $bgColor)
            }
            Button("Сохранить настройки часов") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
        }
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
}
