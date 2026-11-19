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
            Section(header: Text("Время на экране").themedSectionHeader(manager)) {
                Stepper(value: manager.clockDisplaySecondsBinding, in: 1...86400, step: 10) {
                    HStack {
                        Text("Часы (сек.)")
                        Spacer()
                        Text("\(manager.settings.clockDisplaySeconds)")
                            .foregroundColor(manager.valueTextColor)
                    }
                }
                
                Stepper(value: manager.animationDisplaySecondsBinding, in: 1...86400, step: 10) {
                    HStack {
                        Text("Анимации (сек.)")
                        Spacer()
                        Text("\(manager.settings.animationDisplaySeconds)")
                            .foregroundColor(manager.valueTextColor)
                    }
                }
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section(header: Text("Тип анимации").themedSectionHeader(manager)) {
                ThemedMenuPicker(
                    manager: manager,
                    title: "Режим",
                    options: [
                        ThemedDropdownOption(id: 0, title: "Стандартный", value: AnimationType.standard(sortOrder: manager.settings.animationType?.sortOrder ?? 0)),
                        ThemedDropdownOption(id: 1, title: "Категории", value: AnimationType.category(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0)),
                        ThemedDropdownOption(id: 2, title: "Альбом", value: AnimationType.album(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0)),
                        ThemedDropdownOption(id: 3, title: "Избранное", value: AnimationType.likes(sortOrder: manager.settings.animationType?.sortOrder ?? 0)),
                        ThemedDropdownOption(id: 4, title: "Плейлист", value: AnimationType.playlist(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0))
                    ],
                    selection: manager.animationTypeBinding
                )
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section(header: Text("День").themedSectionHeader(manager)) {
                DatePicker(
                    "Начало",
                    selection: manager.dayStartTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                
                ThemedMenuPicker(
                    manager: manager,
                    title: "Режим экрана",
                    options: [
                        ThemedDropdownOption(id: 0, title: "Смешанный", value: "mixed"),
                        ThemedDropdownOption(id: 1, title: "Только часы", value: "clock_only"),
                        ThemedDropdownOption(id: 2, title: "Только анимация", value: "animation_only")
                    ],
                    selection: manager.dayDeviceModeBinding
                )
                
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
                .tint(manager.accentColor)
                .padding(.top, 4)
            }
            .listRowBackground(manager.cardBackgroundColor)
                
            Section(header: Text("Ночь").themedSectionHeader(manager)) {
                DatePicker(
                    "Начало",
                    selection: manager.nightStartTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                
                ThemedMenuPicker(
                    manager: manager,
                    title: "Режим экрана",
                    options: [
                        ThemedDropdownOption(id: 0, title: "Смешанный", value: "mixed"),
                        ThemedDropdownOption(id: 1, title: "Только часы", value: "clock_only"),
                        ThemedDropdownOption(id: 2, title: "Только анимация", value: "animation_only")
                    ],
                    selection: manager.nightDeviceModeBinding
                )
                
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
                .tint(manager.accentColor)
                .padding(.top, 4)
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section(header: Text("Бегущая строка").themedSectionHeader(manager)) {
                Toggle("Отображать имя из Telegram", isOn: Binding(
                    get: { manager.settings.showNameText },
                    set: { newValue in Task { await manager.toggleShowTextUsername(newValue) } }
                ))
                .tint(manager.accentColor)
            }
            .listRowBackground(manager.cardBackgroundColor)
        }
        .themedForm(manager)
        .navigationTitle("Общие настройки")
    }
}
