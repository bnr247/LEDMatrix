//
//  DeviceListView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 29.10.2026.
//

import SwiftUI

/// Перечисление доступных функций устройства для сетки
enum AppFeature: Identifiable, CaseIterable, Hashable {
    case divoom, clock, text, drawing, screen, camera
    
    var id: Self {
        self
    }
    
    var title: String {
        switch self {
        case .divoom: return "Divoom"
        case .clock: return "Часы"
        case .text: return "Текст"
        case .drawing: return "Рисование"
        case .screen: return "Экран"
        case .camera: return "Камера"
        }
    }
    
    var icon: String {
        switch self {
        case .divoom: return "square.grid.2x2.fill"
        case .clock: return "clock.fill"
        case .text: return "text.bubble.fill"
        case .drawing: return "paintpalette.fill"
        case .screen: return "tv.fill"
        case .camera: return "camera.fill"
        }
    }
}

struct MainScreenView: View {
    @ObservedObject var manager: MatrixManager
    
    @State private var isShowingAddDevice = false
    @State private var isShowingSettings = false
    @State private var selectedFeature: AppFeature? = nil
    
    private var isDeviceAvailable: Bool {
        guard let device = manager.selectedDevice else { return false }
        return manager.deviceReachabilityStatus[device.id] ?? true
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Динамический фон в зависимости от темы
                manager.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // СЕКЦИЯ ВЫБОРА УСТРОЙСТВА И НАСТРОЕК
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Устройство")
                            .foregroundColor(manager.secondaryTextColor)
                        
                        HStack(spacing: 12) {
                            ThemedActionMenu(
                                manager: manager,
                                title: "Устройства",
                                items: manager.savedDevices.enumerated().map { index, device in
                                    ThemedDropdownItem(id: index, title: device.name)
                                },
                                selectedIndex: manager.savedDevices.firstIndex { $0.id == manager.selectedDevice?.id },
                                onSelect: { index in
                                    manager.selectDevice(manager.savedDevices[index])
                                }
                            ) {
                                HStack {
                                    Text(manager.savedDevices.isEmpty ? "Нет устройств" : (manager.selectedDevice?.name ?? "Выберите устройство"))
                                        .fontWeight(.medium)
                                        .foregroundColor(manager.selectedDevice != nil ? manager.accentColor : manager.secondaryTextColor)
                                    Spacer()
                                    if !manager.savedDevices.isEmpty {
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.subheadline)
                                            .foregroundColor(manager.secondaryTextColor)
                                    }
                                }
                                .if(!manager.currentTheme.usesSystemAppearance) { content in
                                    content
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(manager.cardBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(manager.accentColor.opacity(0.5), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                            .if(manager.currentTheme.usesSystemAppearance) { content in
                                content.buttonStyle(.borderless)
                            }
                            .disabled(manager.savedDevices.isEmpty)
                            
                            Button(action: {
                                isShowingSettings = true
                            }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title2)
                                    .if(!manager.currentTheme.usesSystemAppearance) { content in
                                        content
                                            .foregroundColor(isDeviceAvailable ? manager.accentColor : manager.secondaryTextColor)
                                            .padding(12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(manager.cardBackgroundColor)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(isDeviceAvailable ? manager.accentColor.opacity(0.5) : manager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                    }
                            }
                            .if(manager.currentTheme.usesSystemAppearance) { content in
                                content.buttonStyle(.borderless)
                            }
                            .disabled(!isDeviceAvailable)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // СЕКЦИЯ УПРАВЛЕНИЯ ЯРКОСТЬЮ
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(isDeviceAvailable ? manager.accentColor : manager.secondaryTextColor)
                            Text("Яркость: ")
                                .foregroundColor(manager.appTextColor)
                            + Text(Double(manager.settings.brightnessPercent) / 100.0, format: .percent)
                                .foregroundColor(manager.valueTextColor)
                            Spacer()
                        }
                                            
                        Slider(
                            value: Binding(
                                get: { Double(manager.settings.brightnessPercent) },
                                set: { newValue in
                                    Task { await manager.updateSingleBrightness(Int(newValue)) }
                                }
                            ),
                            in: 0 ... 100,
                            step: 5
                        )
                        .tint(manager.accentColor)
                        .disabled(!isDeviceAvailable)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .if(manager.currentTheme.usesSystemAppearance) { content in
                        content.background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(manager.cardBackgroundColor)
                        )
                    }
                    .if(!manager.currentTheme.usesSystemAppearance) { content in
                        content.background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(manager.cardBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(manager.accentColor.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    .opacity(isDeviceAvailable ? 1.0 : 0.6)
                                        
                    // СЕТКА КНОПОК ФУНКЦИЙ (2x3)
                    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AppFeature.allCases) { feature in
                            Button(action: {
                                if isDeviceAvailable {
                                    selectedFeature = feature
                                }
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: feature.icon)
                                        .font(.system(size: 28))
                                        .if(manager.currentTheme.usesSystemAppearance) { content in
                                            content.foregroundColor(isDeviceAvailable ? manager.accentColor : manager.secondaryTextColor)
                                        }
                                    Text(feature.title)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .if(manager.currentTheme.usesSystemAppearance) { content in
                                            content.foregroundColor(isDeviceAvailable ? manager.appTextColor : manager.secondaryTextColor)
                                        }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 110)
                                .if(manager.currentTheme.usesSystemAppearance) { content in
                                    content
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(manager.cardBackgroundColor)
                                        )
                                        .opacity(isDeviceAvailable ? 1 : 0.5)
                                }
                                .if(!manager.currentTheme.usesSystemAppearance) { content in
                                    content
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(manager.cardBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(isDeviceAvailable ? manager.accentColor : manager.secondaryTextColor.opacity(0.35), lineWidth: manager.currentTheme == .neon ? 1.5 : 1)
                                                )
                                        )
                                        .foregroundColor(isDeviceAvailable ? manager.appTextColor : manager.secondaryTextColor)
                                        .shadow(color: manager.shadowColor, radius: 5, x: 0, y: 3)
                                }
                            }
                            .themedButtonStyle(manager, .plain)
                            .disabled(!isDeviceAvailable)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .themedNavigationTitle("LED Matrix", manager: manager)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddDevice = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(manager.accentColor)
                    }
                }
            }
            // Идентификатор id(manager.currentTheme) заставляет SwiftUI полностью пересоздать стэк при смене темы
            .id(manager.currentTheme)
            .navigationDestination(item: $selectedFeature) { feature in
                Group {
                    switch feature {
                    case .divoom:
                        DivoomMainView(manager: manager)
                    case .clock:
                        ClockSettingsView(manager: manager)
                    case .text:
                        TextControlView(manager: manager)
                    case .drawing:
                        DrawingView(manager: manager)
                    case .screen:
                        ScreenCastingView(manager: manager)
                    case .camera:
                        CameraView(manager: manager)
                    }
                }
                .themedNavigationTitle(feature.title, manager: manager)
                .navigationBarTitleDisplayMode(.inline)
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationStack {
                    SettingsView(manager: manager)
                        .themedNavigationTitle("Настройки", manager: manager)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Готово") {
                                    isShowingSettings = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingAddDevice) {
                DeviceManagementSheet(manager: manager)
            }
            .onAppear {
                manager.startScanning()
                Task {
                    await manager.checkAllSavedDevicesReachability()
                    if manager.selectedDevice == nil, let firstDevice = manager.savedDevices.first {
                        manager.selectDevice(firstDevice)
                    }
                }
            }
        }
    }
}

/// Отдельное представление для модального окна добавления/управления устройствами (+)
struct DeviceManagementSheet: View {
    @ObservedObject var manager: MatrixManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemIndicesToDelete: IndexSet? = nil
    @State private var isDeleteAlertPresented = false
    
    var body: some View {
        NavigationStack {
            List {
                // Секция сохраненных устройств
                if !manager.savedDevices.isEmpty {
                    Section(header: HStack {
                        Text("Мои устройства").themedSectionHeader(manager)
                        if manager.isCheckingReachability {
                            Spacer()
                            ProgressView().controlSize(.small)
                        }
                    }) {
                        ForEach(manager.savedDevices) { device in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name).font(.headline)
                                    Text(device.ipAddress)
                                        .font(.subheadline)
                                        .foregroundColor(manager.secondaryTextColor)
                                }
                                Spacer()
                                if manager.selectedDevice?.id == device.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(manager.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                manager.selectDevice(device)
                                dismiss()
                            }
                        }
                        .onDelete { indexSet in
                            itemIndicesToDelete = indexSet
                            isDeleteAlertPresented = true
                        }
                    }
                    .listRowBackground(manager.cardBackgroundColor)
                }
                
                // Секция найденных устройств в сети
                Section(header: Text("Устройства в сети").themedSectionHeader(manager)) {
                    if manager.isScanning {
                        HStack {
                            ProgressView().padding(.trailing, 8)
                            Text("Поиск устройств...").foregroundColor(manager.secondaryTextColor)
                        }
                    }
                    
                    if manager.discoveredDevices.isEmpty && !manager.isScanning {
                        Text("Новые устройства не найдены").foregroundColor(manager.secondaryTextColor)
                    }
                    
                    ForEach(manager.discoveredDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name).font(.headline)
                                Text(device.ipAddress).font(.subheadline).themedValueText(manager)
                            }
                            Spacer()
                            Button("Добавить") {
                                manager.saveDevice(device)
                                manager.selectedDevice = device
                                Task {
                                    await manager.checkAllSavedDevicesReachability()
                                }
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(manager.accentColor)
                            .controlSize(.small)
                        }
                    }
                }
                .listRowBackground(manager.cardBackgroundColor)
                
                // Ручное добавление по IP
                Section {
                    NavigationLink(destination: ManualIPView(manager: manager)) {
                        Text("Добавить по IP вручную")
                            .foregroundColor(manager.appTextColor)
                    }
                }
                .listRowBackground(manager.cardBackgroundColor)
            }
            .themedForm(manager)
            .themedNavigationTitle("Устройства", manager: manager)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        manager.startScanning()
                        Task { await manager.checkAllSavedDevicesReachability() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
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
                Text("Вы действительно хотите удалить это устройство?")
            }
            .onAppear {
                manager.startScanning()
                Task {
                    await manager.checkAllSavedDevicesReachability()
                }
            }
        }
    }
}
