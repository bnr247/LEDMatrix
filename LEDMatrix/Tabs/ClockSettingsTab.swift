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
                ColorPicker("Цвет часов", selection: Binding(
                    get: { Color(hex: manager.settings.hoursColorHex) },
                    set: { newValue in Task { await manager.updateClockHoursColor(newValue) } }
                ), supportsOpacity: false)

                ColorPicker("Цвет минут", selection: Binding(
                    get: { Color(hex: manager.settings.minutesColorHex) },
                    set: { newValue in Task { await manager.updateClockMinutesColor(newValue) } }
                ), supportsOpacity: false)

                ColorPicker("Цвет разделителя", selection: Binding(
                    get: { Color(hex: manager.settings.colonColorHex) },
                    set: { newValue in Task { await manager.updateClockColonColor(newValue) } }
                ), supportsOpacity: false)

                ColorPicker("Цвет фона", selection: Binding(
                    get: { Color(hex: manager.settings.bgColorHex) },
                    set: { newValue in Task { await manager.updateClockBgColor(newValue) } }
                ), supportsOpacity: false)
            }
        }
        .task {
            clockFonts = await manager.fetchClockFonts()
        }
    }
}
