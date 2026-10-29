//
//  SettingsGeneralFormView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ФОРМА: ОБЩИЕ НАСТРОЙКИ

import SwiftUI

struct SettingsGeneralFormView: View {
    @ObservedObject var manager: MatrixManager
    
    var body: some View {
        Form {
            Section(header: Text("День")) {
                DatePicker(
                    "Начало",
                    selection: manager.dayStartTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                
                Picker("Режим экрана", selection: manager.dayDeviceModeBinding) {
                    Text("Смешанный").tag("mixed")
                    Text("Только часы").tag("clock_only")
                    Text("Только анимация").tag("animation_only")
                }
                
                // Перенесенный слайдер яркости для дневного режима
                VStack(alignment: .leading) {
                    Text("Яркость: \(manager.settings.dayBrightnessPercent)")
                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.dayBrightnessPercent) },
                            set: { newValue in Task { await manager.updateBrightnessDay(Int(newValue)) } }
                        ),
                        in: 0...100, step: 5
                    )
                }
                .padding(.top, 4)
            }
                
            Section(header: Text("Ночь")) {
                DatePicker(
                    "Начало",
                    selection: manager.nightStartTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                
                Picker("Режим экрана", selection: manager.nightDeviceModeBinding) {
                    Text("Смешанный").tag("mixed")
                    Text("Только часы").tag("clock_only")
                    Text("Только анимация").tag("animation_only")
                }
                
                // Перенесенный слайдер яркости для ночного режима
                VStack(alignment: .leading) {
                    Text("Яркость: \(manager.settings.nightBrightnessPercent)")
                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.nightBrightnessPercent) },
                            set: { newValue in Task { await manager.updateBrightnessNight(Int(newValue)) } }
                        ),
                        in: 0...100, step: 5
                    )
                }
                .padding(.top, 4)
            }
            
            Section(header: Text("Бегущая строка")) {
                Toggle("Отображать имя из Telegram", isOn: Binding(
                    get: { manager.settings.showNameText },
                    set: { newValue in Task { await manager.toggleShowTextUsername(newValue) } }
                ))
            }
        }
        .navigationTitle("Общие настройки")
    }
}
