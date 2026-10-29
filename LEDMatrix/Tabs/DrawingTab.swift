//
//  DrawingTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ВКЛАДКА: РИСОВАНИЕ

import SwiftUI


struct DrawingTab: View {
    @ObservedObject var manager: MatrixManager
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 16)
    
    enum DrawingTool {
        case brush, eraser, fill
    }
    
    @State private var selectedTool: DrawingTool = .brush
    // Состояние для хранения холста на момент начала текущего штриха/жеста
    @State private var canvasStateBeforeStroke: [Color]? = nil
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 16) {
            if !manager.isDrawingActive {
                Spacer()
                Button(action: {
                    Task {
                        await manager.startDrawing()
                        manager.resetUndoRedoHistory()
                    }
                }) {
                    HStack {
                        if manager.isDrawingLoading {
                            ProgressView().tint(.white).padding(.trailing, 8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Начать")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                
                if let errorMsg = manager.drawErrorMessage {
                    Text(errorMsg).font(.caption).foregroundColor(.red).padding(.top)
                }
                Spacer()
            } else {
                // ВЕРХНЯЯ ПАНЕЛЬ ИНСТРУМЕНТОВ
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ToolButton(icon: "paintbrush.fill", title: "Кисть", isSelected: selectedTool == .brush) {
                            selectedTool = .brush
                        }
                        
                        ToolButton(icon: "eraser.fill", title: "Ластик", isSelected: selectedTool == .eraser) {
                            selectedTool = .eraser
                        }
                        
                        ToolButton(icon: "paint.bucket.classic", title: "Заливка", isSelected: selectedTool == .fill) {
                            selectedTool = .fill
                        }
                        
                        Spacer()
                        
                        EraseButton {
                            // Очистка — это отдельное действие, сохраняем состояние для отмены
                            manager.saveStateForUndo()
                            manager.drawPixels = Array(repeating: .black, count: 256)
                            manager.sendDrawFrame()
                        }
                    }
                    
                    HStack {
                        if selectedTool == .brush || selectedTool == .fill {
                            HStack(spacing: 8) {
                                ColorPicker("", selection: $manager.drawBrushColor, supportsOpacity: false)
                                    .labelsHidden()
                                Text(selectedTool == .brush ? "Цвет кисти" : "Цвет заливки")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Стирает нарисованное")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                
                // СЕТКА 16x16
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                    
                    VStack {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(0..<256, id: \.self) { index in
                                Rectangle()
                                    .fill(manager.drawPixels[index])
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .padding(5)
                        .background(Color(hex: "202020"))
                        .cornerRadius(0)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Инструмент Заливка срабатывает мгновенно в момент тапа
                                    if selectedTool == .fill {
                                        if canvasStateBeforeStroke == nil {
                                            canvasStateBeforeStroke = manager.drawPixels
                                            let fillColor = manager.drawBrushColor
                                            if manager.drawPixels.contains(where: { $0 != fillColor }) {
                                                manager.drawPixels = Array(repeating: fillColor, count: 256)
                                                manager.sendDrawFrame()
                                            }
                                        }
                                    } else {
                                        // Обычный штрих (Кисть / Ластик): фиксируем состояние ДО начала линии
                                        if canvasStateBeforeStroke == nil {
                                            canvasStateBeforeStroke = manager.drawPixels
                                        }
                                        applyDrawingAt(location: value.location, in: size)
                                    }
                                }
                                .onEnded { _ in
                                    // Палец оторван: штрих завершен. Если были изменения, коммитим в историю Undo
                                    if let prevState = canvasStateBeforeStroke {
                                        // Проверяем, действительно ли что-то изменилось за время штриха
                                        if prevState != manager.drawPixels {
                                            manager.pushCustomStateToUndo(prevState)
                                        }
                                    }
                                    canvasStateBeforeStroke = nil
                                    manager.sendDrawFrame()
                                }
                        )
                    }
                    .frame(width: size, height: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 16)
                
                // КНОПКИ ОТМЕНИТЬ / ПОВТОРИТЬ НАД СЕТКОЙ
                HStack {
                    
                    // Кнопка Отменить
                    Button(action: {
                        manager.undoDrawing()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 36)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(!manager.canUndo)
                    
                    // Кнопка Повторить
                    Button(action: {
                        manager.redoDrawing()
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 36)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(!manager.canRedo)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // КНОПКА ВЫХОДА ВНИЗУ
                Button(action: {
                    Task {
                        await manager.stopDrawing()
                    }
                }) {
                    Text("Выйти")
                        .bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if manager.isDrawingActive {
                    Button("Назад") {
                        Task {
                            await manager.stopDrawing()
                        }
                    }
                }
            }
        }
        .onAppear {
            disableSwipeBack()
        }
        .onDisappear {
            enableSwipeBack()
            Task {
                await manager.stopDrawing()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard manager.isDrawingActive else { return }
            if newPhase == .background {
                // При сворачивании приложения экстренно гасим режим рисования на плате
                manager.emergencyStopDrawing()
            } else if newPhase == .active {
                // При возвращении в приложение снова активируем режим рисования и отправляем текущий холст
                Task {
                    await manager.startDrawing()
                    manager.sendDrawFrame()
                }
            }
        }
    }
    
    // Вспомогательный метод рисования пикселей штриха во время движения пальца
    private func applyDrawingAt(location: CGPoint, in size: CGFloat) {
        let adjustedX = location.x - 5
        let adjustedY = location.y - 5
        let effectiveSize = size - 10
        let cellWidth = effectiveSize / 16.0
        
        let col = Int(adjustedX / cellWidth)
        let row = Int(adjustedY / cellWidth)
        
        if col >= 0 && col < 16 && row >= 0 && row < 16 {
            let targetIndex = row * 16 + col
            let targetColor = (selectedTool == .eraser) ? Color.black : manager.drawBrushColor
            
            if manager.drawPixels[targetIndex] != targetColor {
                manager.drawPixels[targetIndex] = targetColor
                manager.sendDrawFrame()
            }
        }
    }
    
    private func disableSwipeBack() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let navController = windowScene.windows.first?.rootViewController?.findNavigationController() {
            navController.interactivePopGestureRecognizer?.isEnabled = false
            navController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
    
    private func enableSwipeBack() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let navController = windowScene.windows.first?.rootViewController?.findNavigationController() {
            navController.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
