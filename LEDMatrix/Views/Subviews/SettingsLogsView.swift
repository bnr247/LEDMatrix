//
//  SettingsLogView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ФОРМА: МОНИТОР ЛОГОВ (SERIAL MONITOR)

import SwiftUI

struct SettingsLogsView: View {
    @ObservedObject var manager: MatrixManager
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading) {
                if manager.isLogLoading && manager.deviceLogs.isEmpty {
                    HStack {
                        ProgressView()
                            .tint(.gray)
                            .padding(.trailing, 8)
                        Text("Загрузка вывода...")
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .rotationEffect(.radians(.pi)) // Переворачиваем индикатор загрузки
                    .scaleEffect(x: -1, y: 1, anchor: .center)
                } else {
                    Text(manager.deviceLogs)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(Color(red: 0.17, green: 1, blue: 0)) // Зеленый #b7f7b7
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        // ХИТРОСТЬ: Переворачиваем сам текст обратно, чтобы он читался нормально
                        .rotationEffect(.radians(.pi))
                        .scaleEffect(x: -1, y: 1, anchor: .center)
                }
            }
        }
        // Переворачиваем ScrollView вверх ногами.
        // Теперь низ стал верхом, новые строки липнут к низу экрана автоматически.
        .rotationEffect(.radians(.pi))
        .scaleEffect(x: -1, y: 1, anchor: .center)
        
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        
        .navigationTitle("Вывод устройства")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        
        .onAppear {
            manager.startLogStreaming()
        }
        .onDisappear {
            manager.stopLogStreaming()
        }
    }
}
