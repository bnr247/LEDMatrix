//
//  MatrixControlView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 23.10.2026.
//

import SwiftUI

/// Перечисление вкладок управления устройством (без вкладки настроек в горизонтальном баре)
enum MatrixTab: Int, CaseIterable, Identifiable {
    case text, clock, drawing, screen, camera
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
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .clock: return "clock"
        case .drawing: return "paintpalette"
        case .screen: return "tv"
        case .camera: return "camera.fill"
        }
    }
}

/// Главные разделы экрана устройства
enum MainRootTab: String, CaseIterable, Identifiable {
    case device = "Устройство"
    case divoom = "Divoom"
    
    var id: String { rawValue }
}

struct MatrixControlView: View {
    @ObservedObject var manager: MatrixManager
    let device: LEDMatrixDevice
    
    /// Корневая вкладка (Устройство / Divoom)
    @State private var selectedRootTab: MainRootTab = .device
    
    /// Активная вкладка устройства (по умолчанию — Текст)
    @State private var selectedTab: MatrixTab = .text
    
    /// Флаг отображения вкладки настроек (открывается по кнопке-шестеренке)
    @State private var isShowingSettingsTab = false
    
    // ПРЕДОХРАНИТЕЛЬ: Гарантирует, что сеть дергается строго ОДИН раз при входе на экран
    @State private var hasLoadedData = false
    
    /// Отслеживание состояния жизненного цикла приложения (активно / свернуто / закрыто)
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 0) {
            // Переключаем контент в зависимости от выбранного главного раздела в NavigationBar
            Group {
                if selectedRootTab == .device {
                    // Контент управления устройством
                    VStack(spacing: 0) {
                        // Если открыта вкладка настроек, показываем её, иначе горизонтальный бар вкладок и контент
                        if isShowingSettingsTab {
                            SettingsView(manager: manager)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
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
                            
                            // КОНТЕНТ АКТИВНОЙ ВКЛАДКИ УСТРОЙСТВА
                            Group {
                                switch selectedTab {
                                case .text:
                                    TextControlView(manager: manager)
                                case .clock:
                                    ClockSettingsView(manager: manager)
                                case .drawing:
                                    DrawingView(manager: manager)
                                case .screen:
                                    ScreenCastingView(manager: manager)
                                case .camera:
                                    CameraView(manager: manager)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    // Вкладка Divoom (DivoomMainView)
                    DivoomMainView(manager: manager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Размещаем переключатель «Устройство / Divoom» по центру
            ToolbarItem(placement: .principal) {
                Picker("Раздел", selection: $selectedRootTab) {
                    ForEach(MainRootTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: selectedRootTab) { _, newTab in
                    // Скрываем вкладку настроек устройства при переключении на Divoom
                    if newTab == .divoom {
                        isShowingSettingsTab = false
                    }
                }
            }
            
            // Кнопка настроек отображается только во вкладке «Устройство»
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedRootTab == .device {
                    Button(action: {
                        withAnimation {
                            isShowingSettingsTab.toggle()
                        }
                    }) {
                        Image(systemName: isShowingSettingsTab ? "xmark.circle.fill" : "gearshape.fill")
                            .font(.body)
                            .foregroundColor(isShowingSettingsTab ? .accentColor : .primary)
                    }
                }
            }
        }
        .onAppear {
            manager.selectedDevice = device
            manager.loadSettingsForCurrentDevice()
            
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
                Task {
                    manager.emergencyStopDrawing()
                }
            }
        }
    }
}
