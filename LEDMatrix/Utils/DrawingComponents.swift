//
//  DrawingComponents.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import SwiftUI

/// Вспомогательный компонент красивой кнопки инструмента с иконкой
struct ToolButton: View {
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
            .background(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct EraseButton: View {
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
            .background(Color(UIColor.secondarySystemBackground))
            .foregroundColor(.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
