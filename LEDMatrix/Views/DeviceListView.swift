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
    
    // Отсортированный массив: доступные устройства первыми, недоступные — в конце
        private var sortedSavedDevices: [LEDMatrixDevice] {
            manager.savedDevices.sorted { device1, device2 in
                let is1Reachable = manager.deviceReachabilityStatus[device1.id] ?? true // по умолчанию до проверки считаем доступным
                let is2Reachable = manager.deviceReachabilityStatus[device2.id] ?? true
                
                if is1Reachable == is2Reachable {
                    return device1.name < device2.name
                }
                return is1Reachable && !is2Reachable // true (доступные) идут раньше false (недоступных)
            }
        }
    
    var body: some View {
        NavigationStack {
            List {
                // СЕКЦИЯ 1: Добавленные пользователем устройства
                if !manager.savedDevices.isEmpty {
                    Section(header: HStack {
                        Text("Мои устройства")
                        if manager.isCheckingReachability {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                        }
                    }) {
                        ForEach(sortedSavedDevices) { device in
                            let isReachable = manager.deviceReachabilityStatus[device.id] ?? true
                            
                            Group {
                                if isReachable {
                                    // Доступное устройство — полноценный кликабельный переход
                                    NavigationLink(destination: MatrixControlView(manager: manager, device: device)
                                        .onAppear {
                                            manager.selectedDevice = device
                                            manager.loadSettingsForCurrentDevice()
                                        }
                                    ) {
                                        deviceRowContent(device: device, isReachable: true)
                                    }
                                } else {
                                    // Недоступное устройство — серое и заблокированное для клика
                                    deviceRowContent(device: device, isReachable: false)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Опционально: можно показать подсказку, что устройство оффлайн
                                        }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            // Пересчитываем индексы с учетом сортировки
                            let devicesToDelete = indexSet.map { sortedSavedDevices[$0] }
                            let originalIndices = IndexSet(devicesToDelete.compactMap { dev in
                                manager.savedDevices.firstIndex(where: { $0.id == dev.id })
                            })
                            itemIndicesToDelete = originalIndices
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
                                Task {
                                    await manager.checkAllSavedDevicesReachability()
                                }
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
            .refreshable {
                await manager.checkAllSavedDevicesReachability()
                manager.startScanning()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        manager.startScanning()
                        Task {
                            await manager.checkAllSavedDevicesReachability()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                manager.startScanning()
                Task {
                    await manager.checkAllSavedDevicesReachability()
                }
            }
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
    
    @ViewBuilder
    private func deviceRowContent(device: LEDMatrixDevice, isReachable: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(isReachable ? .primary : .secondary)
                Text(isReachable ? device.ipAddress : "\(device.ipAddress) (недоступно)")
                    .font(.subheadline)
                    .foregroundColor(isReachable ? .secondary : .gray.opacity(0.8))
            }
            Spacer()
            if !isReachable {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.gray)
            }
        }
        .opacity(isReachable ? 1.0 : 0.5) // Визуально делаем полупрозрачным (серым)
    }
}
