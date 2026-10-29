//
//  SettingsWifiFormView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ФОРМА НАСТРОЙКИ WI-FI

import SwiftUI

struct SettingsWifiFormView: View {
    @ObservedObject var manager: MatrixManager
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        Form {
            Section(header: Text("Данные для подключения")) {
                HStack {
                    Text("SSID")
                    Spacer()
                    TextField("", text: $manager.localWifiSsid)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled(true)
                        // Поля заблокированы ТОЛЬКО непосредственно в момент самой отправки байт
                        .disabled(manager.isSavingSettings)
                }
                HStack {
                    Text("Пароль")
                    Spacer()
                    SecureField("", text: $manager.localWifiPassword)
                        .multilineTextAlignment(.trailing)
                        .focused($isPasswordFocused)
                        // Поля заблокированы ТОЛЬКО непосредственно в момент самой отправки байт
                        .disabled(manager.isSavingSettings)
                }
            }
            Section {
                Button(action: {
                    isPasswordFocused = false
                    Task { await manager.saveWifiSettings() }
                }) {
                    HStack {
                        if manager.isSavingSettings {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("Сохранить")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                // КНОПКА ЗАБЛОКИРОВАНА: если данные не менялись, если идет отправка, ЛИБО если сохранение уже прошло успешно
                .disabled(!manager.isWifiSsidChanged && !manager.isWifiPasswordChanged || manager.isSavingSettings || manager.isSaveSuccess)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Настройки WiFi")
        // Принудительно сбрасываем статус успеха при изменении текста в полях, чтобы кнопка снова ожила
        .onChange(of: manager.localWifiSsid) { _, _ in manager.isSaveSuccess = false }
        .onChange(of: manager.localWifiPassword) { _, _ in manager.isSaveSuccess = false }
        .alert("Ошибка сохранения", isPresented: Binding(
            get: { manager.saveErrorMessage != nil },
            set: {
                if !$0 {
                    manager.saveErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(manager.saveErrorMessage ?? "")
        }
        .onChange(of: isPasswordFocused) { _, focused in
            if focused {
                if manager.wifiSettings.passwordSet && manager.localWifiPassword == manager.passwordPlaceholder {
                    manager.localWifiPassword = ""
                }
            } else {
                if manager.wifiSettings.passwordSet && manager.localWifiPassword.isEmpty {
                    manager.localWifiPassword = manager.passwordPlaceholder
                }
            }
        }
    }
}
