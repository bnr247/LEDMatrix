//
//  SettingsDivoomFormView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ФОРМА НАСТРОЙКИ DIVOOM

import SwiftUI

struct SettingsDivoomFormView: View {
    @ObservedObject var manager: MatrixManager
    @FocusState private var isPasswordFocused: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Учетные данные Divoom")) {
                HStack {
                    Text("Email")
                    Spacer()
                    TextField("", text: $manager.localDivoomEmail)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled(true)
                        .disabled(manager.isSavingSettings)
                }
                HStack {
                    Text("Пароль")
                    Spacer()
                    SecureField("", text: $manager.localDivoomPassword)
                        .multilineTextAlignment(.trailing)
                        .focused($isPasswordFocused)
                        .disabled(manager.isSavingSettings)
                }
            }
            Section {
                Button(action: {
                    isPasswordFocused = false
                    Task { await manager.saveDivoomSettings() }
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
                .disabled(!manager.isDivoomEmailChanged && !manager.isDivoomPasswordChanged || manager.isSavingSettings || manager.isSaveSuccess)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Настройки Divoom")
        .onChange(of: manager.localDivoomEmail) { _, _ in manager.isSaveSuccess = false }
        .onChange(of: manager.localDivoomPassword) { _, _ in manager.isSaveSuccess = false }
        // Переносим инициализацию полей Divoom строго на момент открытия этой формы
        .onAppear {
            manager.localDivoomEmail = manager.settings.divoomEmail
            manager.localDivoomPassword = manager.settings.divoomPasswordSet ? manager.passwordPlaceholder : ""
            manager.isSaveSuccess = false
        }
        .alert("Ошибка сохранения", isPresented: Binding(
            get: { manager.saveErrorMessage != nil },
            set: { if !$0 { manager.saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(manager.saveErrorMessage ?? "")
        }
        .onChange(of: isPasswordFocused) { _, focused in
            if focused {
                if manager.settings.divoomPasswordSet && manager.localDivoomPassword == manager.passwordPlaceholder {
                    manager.localDivoomPassword = ""
                }
            } else {
                if manager.settings.divoomPasswordSet && manager.localDivoomPassword.isEmpty {
                    manager.localDivoomPassword = manager.passwordPlaceholder
                }
            }
        }
    }
}
