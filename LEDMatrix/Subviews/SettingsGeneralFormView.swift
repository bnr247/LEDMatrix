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
            Section(header: Text("Время на экране").foregroundColor(manager.accentColor)) {
                Stepper(value: manager.clockDisplaySecondsBinding, in: 1...86400, step: 10) {
                    HStack {
                        Text("Часы (сек.)")
                        Spacer()
                        Text("\(manager.settings.clockDisplaySeconds)")
                            .foregroundColor(manager.secondaryTextColor)
                    }
                }
                
                Stepper(value: manager.animationDisplaySecondsBinding, in: 1...86400, step: 10) {
                    HStack {
                        Text("Анимации (сек.)")
                        Spacer()
                        Text("\(manager.settings.animationDisplaySeconds)")
                            .foregroundColor(manager.secondaryTextColor)
                    }
                }
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section(header: Text("Тип анимации").foregroundColor(manager.accentColor)) {
                Picker("Режим", selection: manager.animationTypeBinding) {
                    Text("Стандартный").tag(AnimationType.standard(sortOrder: manager.settings.animationType?.sortOrder ?? 0))
                    Text("Категории").tag(AnimationType.category(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0))
                    Text("Альбом").tag(AnimationType.album(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0))
                    Text("Избранное").tag(AnimationType.likes(sortOrder: manager.settings.animationType?.sortOrder ?? 0))
                    Text("Плейлист").tag(AnimationType.playlist(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0))
                }
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section(header: Text("День").foregroundColor(manager.accentColor)) {
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
                
            Section(header: Text("Ночь").foregroundColor(manager.accentColor)) {
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
            
            Section(header: Text("Бегущая строка").foregroundColor(manager.accentColor)) {
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
