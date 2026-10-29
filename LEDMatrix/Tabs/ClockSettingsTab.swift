//
//  ClockSettingsTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ВКЛАДКА: ЧАСЫ

import SwiftUI

struct ClockSettingsTab: View {
    @ObservedObject var manager: MatrixManager

    var body: some View {
        Form {
            Section(header: Text("Внешний вид часов")) {
                Picker("Шрифт", selection: Binding(
                    get: { manager.settings.clockFont },
                    set: { newValue in Task { await manager.updateClockFont(newValue) } }
                )) {
                    Text("Default Horizontal (3x5)").tag(0)
                    Text("Simple Horizontal (3x7)").tag(1)
                    Text("Narrow Horizontal (3x11)").tag(2)
                    Text("Simple Vertical (5x7)").tag(3)
                    Text("OCR-A Vertical (5x7)").tag(4)
                    Text("Atari Vertical (5x7)").tag(5)
                    Text("Atari Vertical Small (3x6)").tag(6)
                    Text("Atari Vertical Bold (6x7)").tag(7)
                    Text("Atari Vertical Bold Small (5x5)").tag(8)
                    Text("Postal Horizontal (3x7)").tag(9)
                    Text("Postal Vertical (3x7)").tag(10)
                    Text("Huge Bold (6x9)").tag(11)
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
    }
}
