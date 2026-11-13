//
//  SettingsTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ВКЛАДКА НАСТРОЕК

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var manager: MatrixManager
    @State private var isFilePickerPresented = false
    @State private var isConfirmAlertPresented = false
    @State private var selectedFileName = ""
    
    // Состояния для диалога переименования устройства
    @State private var isRenameAlertPresented = false
    @State private var newDeviceName = ""
    @State private var showRenameToast = false
    
    var body: some View {
        Form {
            Section(header: Text("Устройство")) {
                HStack {
                    Text(manager.selectedDevice?.name ?? "Неизвестно")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Переименовать") {
                        if let currentDevice = manager.selectedDevice {
                            newDeviceName = currentDevice.name
                            isRenameAlertPresented = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Section(header: Text("Настройки устройства")) {
                NavigationLink(destination: SettingsGeneralFormView(manager: manager)) {
                    Label("Общие", systemImage: "sparkles.tv")
                }
                NavigationLink(destination: SettingsWifiFormView(manager: manager)) {
                    Label("Настройки Wifi", systemImage: "wifi")
                }
                NavigationLink(destination: SettingsDivoomFormView(manager: manager)) {
                    Label("Настройки Divoom", systemImage: "globe")
                }
                NavigationLink(destination: SettingsInfoFormView(manager: manager)) {
                    Label("Об устройстве", systemImage: "info.circle")
                }
                NavigationLink(destination: SettingsLogsView(manager: manager)) {
                    Label("Просмотр лога", systemImage: "terminal")
                }
            }
            
            Section(header: Text("Обновление ПО")) {
                if manager.isOtaUpdating {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(manager.otaStatusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: manager.otaProgress, total: 1.0)
                            .progressViewStyle(.linear)
                        
                        Text("\(Int(manager.otaProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    Button(action: {
                        isFilePickerPresented = true
                    }) {
                        Label("Установить прошивку (.bin)", systemImage: "arrow.clockwise.icloud")
                    }
                }
            }
        }
        // Диалоговое окно переименования устройства
        .alert("Переименовать устройство", isPresented: $isRenameAlertPresented) {
            TextField("Новое название", text: $newDeviceName)
            Button("Сохранить") {
                if let currentDevice = manager.selectedDevice, !newDeviceName.isEmpty {
                    manager.renameDevice(id: currentDevice.id, newName: newDeviceName)
                    showRenameToast = true
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        // Тост уведомления об успешном переименовании
        .overlay(alignment: .bottom) {
            if showRenameToast {
                Text("Устройство переименовано")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                    .padding(.bottom, 20)
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            await MainActor.run { showRenameToast = false }
                        }
                    }
            }
        }
        // 1. Окно выбора файла с жестким фильтром по расширению .bin
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [UTType(filenameExtension: "bin") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedFileURL = urls.first else { return }
                
                guard selectedFileURL.pathExtension.lowercased() == "bin" else {
                    manager.otaStatusMessage = "Ошибка: разрешены только файлы с расширением .bin"
                    return
                }
                
                self.selectedFileName = selectedFileURL.lastPathComponent
                manager.pendingOtaFileURL = selectedFileURL
                self.isConfirmAlertPresented = true
                
            case .failure(let error):
                manager.otaStatusMessage = "Файл не выбран: \(error.localizedDescription)"
            }
        }
        // 2. Диалог подтверждения перед прошивкой
        .alert("Обновление прошивки", isPresented: $isConfirmAlertPresented) {
            Button("Обновить", role: .none) {
                if let fileURL = manager.pendingOtaFileURL {
                    Task {
                        await manager.uploadFirmware(fileURL: fileURL)
                    }
                }
            }
            Button("Отмена", role: .cancel) {
                manager.pendingOtaFileURL = nil
            }
        } message: {
            Text("Вы действительно хотите установить выбранный файл прошивки?\n\nФайл: \(selectedFileName)")
        }
    }
}

func actionButton(title: LocalizedStringKey, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
    .buttonStyle(.borderedProminent)
    .tint(color)
}
