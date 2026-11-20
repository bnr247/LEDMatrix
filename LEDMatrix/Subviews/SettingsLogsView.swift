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
                            .tint(manager.accentColor)
                            .padding(.trailing, 8)
                        Text("Загрузка вывода...")
                            .foregroundColor(manager.secondaryTextColor)
                    }
                    .padding(16)
                    .rotationEffect(.radians(.pi)) // Переворачиваем индикатор загрузки
                    .scaleEffect(x: -1, y: 1, anchor: .center)
                } else {
                    Text(manager.deviceLogs)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(manager.successColor) // Терминальный зелёный из палитры темы
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        // Переворачиваем сам текст обратно, чтобы он читался нормально
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
        .background(
            (manager.currentTheme.usesSystemAppearance
                ? manager.backgroundColor
                : manager.matrixPanelColor)
            .ignoresSafeArea()
        )
        .themedNavigationTitle("Вывод устройства", manager: manager)
        .navigationBarTitleDisplayMode(.inline)
        .themedDarkToolbar(manager)
        .tint(manager.accentColor)
        .onAppear {
            manager.startLogStreaming()
        }
        .onDisappear {
            manager.stopLogStreaming()
        }
    }
}
