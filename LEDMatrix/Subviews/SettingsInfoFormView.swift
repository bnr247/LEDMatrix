//
//  SettingsInfoFormView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ФОРМА: ОБ УСТРОЙСТВЕ

import SwiftUI

struct SettingsInfoFormView: View {
    @ObservedObject var manager: MatrixManager
    @State private var activeAction: DeviceAction?

    var body: some View {
        Form {
            Section {
                row(title: "Имя хоста", value: manager.settings.hostName)
                row(title: "IP адрес", value: manager.settings.ipAddress)
                row(title: "MAC адрес", value: manager.settings.macAddress)
                row(title: "Версия HW", value: manager.settings.hwVersion)
                row(title: "Версия FW", value: manager.settings.fwVersion)
                row(title: "Запусков", value: "\(manager.settings.bootCount)")
            }
            Section {
                VStack(spacing: 16) {
                    actionButton(title: "Перезагрузить", color: .blue) { activeAction = .restart }
                    actionButton(title: "Сброс настроек", color: .orange) { activeAction = .resetSettings }
                    actionButton(title: "Сброс WiFi", color: .orange) { activeAction = .resetWifi }
                    actionButton(title: "Factory reset", color: .red) { activeAction = .factoryReset }
                }
                .listRowBackground(Color.clear)
            }
        }
        .alert(item: $activeAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .destructive(Text("Подтвердить")) {
                    Task {
                        switch action {
                        case .restart: await manager.deviceRestart()
                        case .resetWifi: await manager.deviceResetWifi()
                        case .resetSettings: await manager.deviceResetSettings()
                        case .factoryReset: await manager.deviceFactoryReset()
                        }
                    }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
        .navigationTitle("Информация об устройстве")
    }

    private func row(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title) // Теперь Text сразу понимает, что это ключ локализации
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}

enum DeviceAction: Identifiable {
    case restart
    case resetWifi
    case resetSettings
    case factoryReset
    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .restart: return "Перезагрузка"
        case .resetWifi: return "Сброс настроек WiFi"
        case .resetSettings: return "Сброс всех настроек"
        case .factoryReset: return "Factory reset"
        }
    }

    var message: String {
        switch self {
        case .restart: return "Вы уверены, что хотите перезагрузить устройство?"
        case .resetWifi: return "Вы уверены, что хотите сбросить настройки WiFi?"
        case .resetSettings: return "Это действие удалит настройки устройства без возможности восстановления. Настройки WiFi затронуты не будут"
        case .factoryReset: return "Это действие удалит все настройки и сбросит устройство до исходного состояния"
        }
    }
}
