//
//  CameraTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ВКЛАДКА: КАМЕРА

import SwiftUI

struct CameraView: View {
    @ObservedObject var manager: MatrixManager
    @State private var cameraController = CameraStreamController()
    @State private var isStreaming = false
    @State private var toastMessage: String? = nil
    @State private var flashOpacity: Double = 0.0 // Состояние прозрачности для эффекта вспышки
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        let currentSpacing: CGFloat = manager.showCameraGrid ? 2 : 0
        let columns = Array(repeating: GridItem(.flexible(), spacing: currentSpacing), count: 16)
        
        VStack(spacing: 16) {
            // Квадрат по ширине: сетка не должна растягиваться на всю высоту,
            // иначе параметры и кнопки уезжают вниз с пустотой посередине.
            Color.clear
                .padding(.horizontal, 10)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { geometry in
                        let size = min(geometry.size.width, geometry.size.height)

                        VStack {
                            LazyVGrid(columns: columns, spacing: currentSpacing) {
                                ForEach(0 ..< 256, id: \.self) { index in
                                    Rectangle()
                                        .fill(manager.cameraPixels[index])
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                            .padding(16)
                            .background(manager.cardBackgroundColor)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(manager.cardBorderColor, lineWidth: 1)
                            )
                            .shadow(color: manager.shadowColor, radius: 5, x: 0, y: 2)
                        }
                        .frame(width: size, height: size)
                        .overlay(
                            Rectangle()
                                .fill(Color.white)
                                .cornerRadius(10)
                                .opacity(flashOpacity)
                        )
                    }
                }
                .padding(.top, 10)
            
            // Тумблеры управления
            VStack(spacing: 8) {
                Toggle("Сетка", isOn: $manager.showCameraGrid)
                    .tint(manager.accentColor)
            }
            .foregroundColor(manager.appTextColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .themedCard(manager, cornerRadius: 12)
            .padding(.horizontal, 20)
            
            // Панель кнопок управления трансляцией и снимками
            VStack(spacing: 12) {
                Button(action: {
                    isStreaming.toggle()
                    if isStreaming {
                        manager.isCameraActive = true
                        cameraController.onFrameCaptured = { image in
                            manager.processCameraImage(image)
                        }
                        cameraController.startSession()
                        Task {
                            try? await manager.sendCommand(endpoint: "draw", params: ["enabled": true])
                        }
                    } else {
                        manager.isCameraActive = false
                        cameraController.stopSession()
                        Task {
                            await manager.stopDrawing()
                        }
                    }
                }) {
                    Label(isStreaming ? "Остановить трансляцию" : "Начать трансляцию", systemImage: isStreaming ? "stop.fill" : "play.fill")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .themedActionButton(manager, buttonTint: isStreaming ? manager.dangerColor : manager.accentColor)
                
                HStack(spacing: 16) {
                    Button(action: {
                        cameraController.switchCamera()
                        manager.isUsingFrontCamera.toggle()
                    }) {
                        Label("Переключить", systemImage: "camera.rotate.fill")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(manager.accentColor)
                    .disabled(!isStreaming)
                    
                    Button(action: {
                        guard isStreaming else { return }
                        if let finalImage = manager.generateCapturedImage(withGrid: manager.showCameraGrid) {
                            UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
                            
                            // Запуск эффекта вспышки белого экрана с плавным затуханием на 500 мс
                            flashOpacity = 1.0
                            withAnimation(.easeOut(duration: 0.5)) {
                                flashOpacity = 0.0
                            }
                            
                            showToast(message: "Сохранено в галерею")
                        }
                    }) {
                        Label("Снимок", systemImage: "camera.circle.fill")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(manager.accentColor)
                    .disabled(!isStreaming)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background((manager.currentTheme.usesSystemAppearance ? manager.backgroundColor : manager.cardBackgroundColor).ignoresSafeArea())
        .tint(manager.accentColor)
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .themedLightText(manager)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(manager.toastBackgroundColor)
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: toastMessage)
            }
        }
        .onDisappear {
            if isStreaming {
                isStreaming = false
                manager.isCameraActive = false
                cameraController.stopSession()
                
                Task {
                    await manager.stopDrawing()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard isStreaming else { return }
            if newPhase == .background {
                cameraController.stopSession()
            } else if newPhase == .active {
                cameraController.onFrameCaptured = { image in
                    manager.processCameraImage(image)
                }
                cameraController.startSession()
                Task {
                    try? await manager.sendCommand(endpoint: "draw", params: ["enabled": true])
                }
            }
        }
    }
    
    private func showToast(message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}
