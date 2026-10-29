//
//  CameraTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ВКЛАДКА: КАМЕРА

import SwiftUI

struct CameraTab: View {
    @ObservedObject var manager: MatrixManager
    @State private var cameraController = CameraStreamController(); @State private var showAlert = false
    @State private var alertMessage = ""
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        let currentSpacing: CGFloat = manager.showCameraGrid ? 2 : 0
        let columns = Array(repeating: GridItem(.flexible(), spacing: currentSpacing), count: 16)
        
        VStack(spacing: 16) {
            // Сетка 16x16, повторяющая изображение с камеры
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
                    .background(Color(hex: "202020"))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            
            // Тумблеры управления
            VStack(spacing: 8) {
                Toggle("Сетка", isOn: $manager.showCameraGrid)
            }
            .padding(.horizontal, 20)
            
            // Панель кнопок: Сменить камеру / Сделать снимок
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
                
                Button(action: {
                    // Генерируем картинку с учетом текущего состояния тумблера сетки
                    if let finalImage = manager.generateCapturedImage(withGrid: manager.showCameraGrid) {
                        UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
                        alertMessage = manager.showCameraGrid ? "Снимок с сеткой сохранен в галерею!" : "Снимок без сетки сохранен в галерею!"
                        // showAlert = true
                    }
                }) {
                    Label("Снимок", systemImage: "camera.circle.fill")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .alert("Галерея", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            manager.isCameraActive = true
            cameraController.onFrameCaptured = { image in
                manager.processCameraImage(image)
            }
            cameraController.startSession()
            Task {
                try? await manager.sendCommand(endpoint: "draw", params: ["enabled": true])
            }
        }
        .onDisappear {
            manager.isCameraActive = false
            cameraController.stopSession()
            
            Task {
                await manager.stopDrawing()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard manager.isCameraActive else { return }
            if newPhase == .background {
                cameraController.stopSession()
            } else if newPhase == .active {
                // Возвращаемся из фонового режима: перезапускаем камеру и снова включаем режим рисования на плате
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
}
