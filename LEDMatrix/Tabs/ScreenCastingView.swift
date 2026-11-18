//
//  Untitled.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ВКЛАДКА: ЭКРАН (МОНИТОР МАТРИЦЫ 16x16)

import SwiftUI

struct ScreenCastingView: View {
    @ObservedObject var manager: MatrixManager
    
    var body: some View {
        let currentSpacing: CGFloat = manager.showGrid ? 2 : 0
        let columns = Array(repeating: GridItem(.flexible(), spacing: currentSpacing), count: 16)
        
        VStack(spacing: 12) {
            // Квадратная сетка 16x16 вверху экрана
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                
                VStack {
                    LazyVGrid(columns: columns, spacing: currentSpacing) {
                        ForEach(0 ..< 256, id: \.self) { index in
                            Rectangle()
                                .fill(manager.screenPixels[index])
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(16)
                    .background(manager.matrixPanelColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(manager.cardBorderColor, lineWidth: 1)
                    )
                    .shadow(color: manager.shadowColor, radius: 5, x: 0, y: 2)
                }
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            
            // Чекбоксы управления просмотром
            VStack(spacing: 8) {
                // Привязываем тумблер сетки к менеджеру (сохраняется в UserDefaults)
                Toggle("Сетка", isOn: $manager.showGrid)
                    .tint(manager.accentColor)
                
                // Тумблер Live-режима
                Toggle("Live-режим", isOn: Binding(
                    get: { manager.isScreenLiveActive },
                    set: { isActive in
                        if isActive {
                            manager.startScreenLiveStream()
                        } else {
                            manager.stopScreenLiveStream()
                        }
                    }
                ))
                .tint(manager.accentColor)
            }
            .foregroundColor(manager.appTextColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .themedCard(manager, cornerRadius: 12)
            .padding(.horizontal, 20)
            
            if let errorMsg = manager.screenErrorMessage {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(manager.dangerColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                Task {
                    await manager.fetchScreen()
                }
            }) {
                HStack {
                    if manager.isScreenLoading {
                        ProgressView()
                            .tint(manager.accentContrastColor)
                            .padding(.trailing, 8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Обновить кадр")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(manager.accentColor)
            .disabled(manager.isScreenLoading || manager.isScreenLiveActive)
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
        }
        .background(manager.backgroundColor.ignoresSafeArea())
        .tint(manager.accentColor)
        .onAppear {
            Task {
                await manager.fetchScreen()
            }
        }
        .onDisappear {
            // Безопасно выключаем лайв-режим при уходе с вкладки
            manager.stopScreenLiveStream()
        }
    }
}
