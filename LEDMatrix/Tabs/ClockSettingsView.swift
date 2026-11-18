// MARK: - ВКЛАДКА: ЧАСЫ

import SwiftUI

struct ClockSettingsView: View {
    @ObservedObject var manager: MatrixManager
    @State private var clockFonts: [ClockFont] = []

    var body: some View {
        Form {
            Section(header: Text("Внешний вид")) {
                Picker("Шрифт", selection: Binding(
                    get: { manager.settings.currentClockFontId },
                    set: { newValue in Task { await manager.updateClockFont(newValue) } }
                )) {
                    if clockFonts.isEmpty {
                        Text("Загрузка шрифтов...").tag(manager.settings.currentClockFontId)
                    } else {
                        ForEach(clockFonts, id: \.id) { font in
                            Text(font.fontName).tag(font.id)
                        }
                    }
                }
                
                Picker("Анимация", selection: manager.clockAnimationTypeBinding) {
                    Text("Стандартный").tag(ClockAnimationType.fading)
                    Text("Слайд").tag(ClockAnimationType.slideUp)
                    Text("Вспышка").tag(ClockAnimationType.flash)
                    Text("Помехи").tag(ClockAnimationType.tvStatic)
                }
                
                Picker("Эффект", selection: manager.clockColorEffectBinding) {
                    Text("Нет").tag(ClockColorEffect.off)
                    Text("Обмен цветом").tag(ClockColorEffect.swap)
                    Text("Спектр").tag(ClockColorEffect.spectrum)
                    Text("Радуга").tag(ClockColorEffect.rainbow)
                    Text("Случайный цвет").tag(ClockColorEffect.randomColor)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(manager.settings.clockEffectSpeed) },
                        set: { newValue in
                            Task { await manager.updateClockEffectSpeed(Int(newValue)) }
                        }
                    ),
                    in: 0 ... 100,
                    step: 5
                )
                .tint(manager.accentColor)
                //.disabled(!Pic)
            }

            Section(header: Text("Цветовая гамма часов")) {
                HStack(spacing: 32) {
                    ColorPicker("Час 1", selection: Binding(
                        get: { Color(hex: manager.settings.hoursColor1Hex) },
                        set: { newValue in Task { await manager.updateClockHoursColor1(newValue) } }
                    ), supportsOpacity: false)
                    
                    ColorPicker("Час 2", selection: Binding(
                        get: { Color(hex: manager.settings.hoursColor2Hex) },
                        set: { newValue in Task { await manager.updateClockHoursColor2(newValue) } }
                    ), supportsOpacity: false)
                }
                HStack(spacing: 32) {
                    ColorPicker("Минута 1", selection: Binding(
                        get: { Color(hex: manager.settings.minutesColor1Hex) },
                        set: { newValue in Task { await manager.updateClockMinutesColor1(newValue) } }
                    ), supportsOpacity: false)
                    
                    ColorPicker("Минута 2", selection: Binding(
                        get: { Color(hex: manager.settings.minutesColor2Hex) },
                        set: { newValue in Task { await manager.updateClockMinutesColor2(newValue) } }
                    ), supportsOpacity: false)
                }
                ColorPicker("Цвет разделителя", selection: Binding(
                    get: { Color(hex: manager.settings.colonColorHex) },
                    set: { newValue in Task { await manager.updateClockColonColor(newValue) } }
                ), supportsOpacity: false)

                ColorPicker("Цвет фона", selection: Binding(
                    get: { Color(hex: manager.settings.bgColorHex) },
                    set: { newValue in Task { await manager.updateClockBgColor(newValue) } }
                ), supportsOpacity: false)
                
//                Toggle("Обмен цветом цифр", isOn: Binding(
//                    get: { manager.settings.clockSwapColors },
//                    set: { newValue in Task { await manager.toggleClockSwapColors(newValue) } }
//                ))
//                
//                Toggle("Случайный цвет цифры", isOn: Binding(
//                    get: { manager.settings.clockRandomColor },
//                    set: { newValue in Task { await manager.toggleClockRandomColor(newValue) } }
//                ))
                
                Toggle("Показывать разделитель", isOn: Binding(
                    get: { manager.settings.showColon },
                    set: { newValue in Task { await manager.toggleClockShowColon(newValue) } }
                ))
                
            }
        }
        .task {
            clockFonts = await manager.fetchClockFonts()
        }
    }
}
