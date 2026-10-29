//
//  MatrixControlView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 23.10.2026.
//

import SwiftUI

/// Перечисление всех вкладок
enum MatrixTab: Int, CaseIterable, Identifiable {
    case text, clock, drawing, screen, camera, settings
    var id: Int {
        rawValue
    }
    
    var title: String {
        switch self {
        case .text: return "Текст"
        case .clock: return "Часы"
        case .drawing: return "Рисование"
        case .screen: return "Экран"
        case .camera: return "Камера"
        case .settings: return "Настройки"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .clock: return "clock"
        case .drawing: return "paintpalette"
        case .screen: return "tv"
        case .camera: return "camera.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MatrixControlView: View {
    @ObservedObject var manager: MatrixManager
    let device: LEDMatrixDevice
    
    /// Активная вкладка (по умолчанию — Текст)
    @State private var selectedTab: MatrixTab = .text
    
    // Состояния для переименования внутри экрана устройства
    @State private var isRenameAlertPresented = false
    @State private var newDeviceName = ""
    
    // ПРЕДОХРАНИТЕЛЬ: Гарантирует, что сеть дергается строго ОДИН раз при входе на экран
    @State private var hasLoadedData = false
    
    /// Отслеживание состояния жизненного цикла приложения (активно / свернуто / закрыто)
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 0) {
            // ВЕРХНЯЯ ПРОКРУЧИВАЕМАЯ ПАНЕЛЬ ВКЛАДОК (Scrollable Tab Bar)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MatrixTab.allCases) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                    Text(tab.title)
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedTab == tab ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                                .clipShape(Capsule())
                            }
                            .id(tab)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(UIColor.systemBackground))
                .onChange(of: selectedTab) { _, newTab in
                    withAnimation {
                        proxy.scrollTo(newTab, anchor: .center)
                    }
                }
            }
            
            Divider()
            
            // КОНТЕНТ АКТИВНОЙ ВКЛАДКИ
            Group {
                switch selectedTab {
                case .text:
                    TextControlTab(manager: manager)
                case .clock:
                    ClockSettingsTab(manager: manager)
                case .drawing:
                    DrawingTab(manager: manager)
                case .screen:
                    ScreenTab(manager: manager)
                case .camera:
                    CameraTab(manager: manager)
                case .settings:
                    SettingsTab(manager: manager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        newDeviceName = device.name
                        isRenameAlertPresented = true
                    }) {
                        Label("Переименовать", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.body)
                }
            }
        }
        // Диалоговое окно переименования устройства
        .alert("Переименовать устройство", isPresented: $isRenameAlertPresented) {
            TextField("Новое название", text: $newDeviceName)
            Button("Сохранить") {
                manager.renameDevice(ipAddress: device.ipAddress, newName: newDeviceName)
            }
            Button("Отмена", role: .cancel) {}
        }
        .onAppear {
            // 1. Сразу закрепляем устройство за менеджером, чтобы IP был доступен для UserDefaults
            manager.selectedDevice = device
            
            // 2. Загружаем локальные сохраненные настройки для этой конкретной матрицы
            manager.loadSettingsForCurrentDevice()
            
            // Если данные уже загружались — мгновенно выходим, не забивая сокеты ESP32
            guard !hasLoadedData else { return }
            hasLoadedData = true
            
            Task {
                await manager.fetchSettings(for: device)
            }
            Task {
                await manager.fetchWifiSettings(for: device)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Обычное сворачивание — отправляем стандартный метод
                Task {
                    manager.emergencyStopDrawing()
                }
            } else if newPhase == .inactive {
                // При закрытии приложения или уходе в неактивное состояние перед убийством
            }
        }
    }
}
