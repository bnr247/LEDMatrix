//
//  DrawingComponents.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import SwiftUI

/// Вспомогательный компонент красивой кнопки инструмента с иконкой
struct ToolButton: View {
    @ObservedObject var manager: MatrixManager
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 70, height: 42)
            .background(isSelected ? manager.accentColor : manager.fieldBackgroundColor)
            .foregroundColor(isSelected ? manager.accentContrastColor : manager.appTextColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? manager.accentColor : manager.cardBorderColor, lineWidth: 1)
            )
        }
    }
}

struct EraseButton: View {
    @ObservedObject var manager: MatrixManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Очистить")
                    .font(.caption2)
            }
            .frame(width: 70, height: 42)
            .background(manager.fieldBackgroundColor)
            .foregroundColor(manager.dangerColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(manager.dangerColor.opacity(0.35), lineWidth: 1)
            )
        }
    }
}
