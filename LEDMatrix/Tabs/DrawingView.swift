//
//  DrawingTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 29.10.2026.
//

// MARK: - ВКЛАДКА: РИСОВАНИЕ

import SwiftUI

struct DrawingView: View {
    @ObservedObject var manager: MatrixManager
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 16)
    
    enum DrawingTool {
        case brush, eraser, fill
    }
    
    @State private var selectedTool: DrawingTool = .brush
    /// Состояние для хранения холста на момент начала текущего штриха/жеста
    @State private var canvasStateBeforeStroke: [Color]? = nil
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 0) {
            if !manager.isDrawingActive {
                Spacer()
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            // Принудительно завершаем предыдущую сессию перед стартом новой
                            await manager.stopDrawing()
                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 сек паузы
                            
                            await manager.startDrawing()
                            manager.resetUndoRedoHistory()
                        }
                    }) {
                        HStack {
                            if manager.isDrawingLoading {
                                ProgressView().tint(manager.accentColor).padding(.trailing, 8)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text("Начать")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .themedActionButton(manager)
                    .padding(.horizontal, 40)
                    
                    if let errorMsg = manager.drawErrorMessage {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundColor(manager.dangerColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                Spacer()
            } else {
                // ВЕРХНЯЯ ПАНЕЛЬ ИНСТРУМЕНТОВ
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ToolButton(manager: manager, icon: "paintbrush.fill", title: "Кисть", isSelected: selectedTool == .brush) {
                            selectedTool = .brush
                        }
                        
                        ToolButton(manager: manager, icon: "eraser.fill", title: "Ластик", isSelected: selectedTool == .eraser) {
                            selectedTool = .eraser
                        }
                        
                        ToolButton(manager: manager, icon: "paint.bucket.classic", title: "Заливка", isSelected: selectedTool == .fill) {
                            selectedTool = .fill
                        }
                        
                        Spacer()
                        
                        EraseButton(manager: manager) {
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
                                    .foregroundColor(manager.secondaryTextColor)
                            }
                        } else {
                            Text("Стирает нарисованное")
                                .font(.subheadline)
                                .foregroundColor(manager.secondaryTextColor)
                        }
                        Spacer()
                    }
                    .frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // СЕТКА 16x16
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                    
                    VStack {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(0 ..< 256, id: \.self) { index in
                                Rectangle()
                                    .fill(manager.drawPixels[index])
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .padding(5)
                        .background(manager.matrixPanelColor)
                        .cornerRadius(0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(manager.cardBorderColor, lineWidth: 1)
                        )
                        .shadow(color: manager.shadowColor, radius: 5, x: 0, y: 2)
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
                                    if let prevState = canvasStateBeforeStroke,
                                       prevState != manager.drawPixels
                                    {
                                        manager.pushCustomStateToUndo(prevState)
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
                            .foregroundColor(manager.appTextColor)
                            .background(manager.fieldBackgroundColor)
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
                            .foregroundColor(manager.appTextColor)
                            .background(manager.fieldBackgroundColor)
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .themedActionButton(manager, buttonTint: manager.dangerColor)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(manager.backgroundColor.ignoresSafeArea())
        .tint(manager.accentColor)
        // Навигация системная: кнопка «Назад» и swipe-жест остаются стандартными.
        .onDisappear {
            Task {
                await manager.stopDrawing()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard manager.isDrawingActive else { return }
            if newPhase == .background {
                manager.emergencyStopDrawing()
            } else if newPhase == .active {
                Task {
                    await manager.startDrawing()
                    manager.sendDrawFrame()
                }
            }
        }
    }
    
    /// Вспомогательный метод рисования пикселей штриха во время движения пальца
    private func applyDrawingAt(location: CGPoint, in size: CGFloat) {
        let adjustedX = location.x - 5
        let adjustedY = location.y - 5
        let effectiveSize = size - 10
        let cellWidth = effectiveSize / 16.0
        
        let col = Int(adjustedX / cellWidth)
        let row = Int(adjustedY / cellWidth)
        
        if col >= 0, col < 16, row >= 0, row < 16 {
            let targetIndex = row * 16 + col
            let targetColor = (selectedTool == .eraser) ? Color.black : manager.drawBrushColor
            
            if manager.drawPixels[targetIndex] != targetColor {
                manager.drawPixels[targetIndex] = targetColor
                manager.sendDrawFrame()
            }
        }
    }
}
