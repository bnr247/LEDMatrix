// MARK: - ВКЛАДКА: ЧАСЫ

import SwiftUI

struct ClockSettingsTab: View {
    @ObservedObject var manager: MatrixManager
    @State private var clockFonts: [ClockFont] = []

    var body: some View {
        Form {
            Section(header: Text("Внешний вид часов")) {
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
                
                Toggle("Случайный цвет цифры", isOn: Binding(
                    get: { manager.settings.clockRandomColor },
                    set: { newValue in Task { await manager.toggleClockRandomColor(newValue) } }
                ))
            }
        }
        .task {
            clockFonts = await manager.fetchClockFonts()
        }
    }
}
