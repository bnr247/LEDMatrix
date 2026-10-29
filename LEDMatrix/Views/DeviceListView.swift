//
//  DeviceListView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import SwiftUI

struct DeviceListView: View {
    @StateObject private var manager = MatrixManager()
    
    // Состояния для подтверждения удаления
    @State private var itemIndicesToDelete: IndexSet? = nil
    @State private var isDeleteAlertPresented = false
    
    var body: some View {
        NavigationStack {
            List {
                // СЕКЦИЯ 1: Добавленные пользователем устройства
                if !manager.savedDevices.isEmpty {
                    Section(header: Text("Мои устройства")) {
                        ForEach(manager.savedDevices) { device in
                            NavigationLink(destination: MatrixControlView(manager: manager, device: device)) {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.headline)
                                    Text(device.ipAddress)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            itemIndicesToDelete = indexSet
                            isDeleteAlertPresented = true
                        }
                    }
                }
                
                // СЕКЦИЯ 2: Найденные новые устройства в сети
                Section(header: Text("Устройства в сети")) {
                    if manager.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Поиск устройств LedMatrix...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if manager.discoveredDevices.isEmpty && !manager.isScanning {
                        Text("Новые устройства не найдены")
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(manager.discoveredDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.headline)
                                Text(device.ipAddress)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Button("Добавить") {
                                manager.saveDevice(device)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                
                // СЕКЦИЯ 3: Ручное добавление
                Section {
                    NavigationLink(destination: ManualIPView(manager: manager)) {
                        Text("Добавить по IP вручную")
                    }
                }
            }
            .navigationTitle("Список устройств")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        manager.startScanning()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                manager.startScanning()
            }
            // Диалог подтверждения удаления устройства с динамическим именем
            .alert("Удаление устройства", isPresented: $isDeleteAlertPresented) {
                Button("Удалить", role: .destructive) {
                    if let indices = itemIndicesToDelete {
                        manager.removeDevice(at: indices)
                    }
                    itemIndicesToDelete = nil
                }
                Button("Отмена", role: .cancel) {
                    itemIndicesToDelete = nil
                }
            } message: {
                if let indices = itemIndicesToDelete,
                   let firstIndex = indices.first,
                   manager.savedDevices.indices.contains(firstIndex)
                {
                    let deviceName = manager.savedDevices[firstIndex].name
                    Text("Вы действительно хотите удалить устройство \"\(deviceName)\"?")
                } else {
                    Text("Вы действительно хотите удалить это устройство?")
                }
            }
        }
    }
}
