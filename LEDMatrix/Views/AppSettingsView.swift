//
//  AppSettingsView.swift
//  LEDMatrix
//
//  Настройки самого приложения: оформление, не зависящее от устройства.
//

import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var manager: MatrixManager

    var body: some View {
        Form {
            Section(header: Text("Внешний вид").themedSectionHeader(manager)) {
                ThemedMenuPicker(
                    manager: manager,
                    title: "Тема оформления",
                    options: AppTheme.allCases.enumerated().map { index, theme in
                        ThemedDropdownOption(id: index, title: theme.rawValue, value: theme)
                    },
                    selection: Binding(
                        get: { manager.currentTheme },
                        set: { manager.currentTheme = $0 }
                    )
                )
            }
            .listRowBackground(manager.cardBackgroundColor)
        }
        .themedForm(manager)
        .id(manager.currentTheme) // Мгновенное применение темы без пересоздания всего приложения
        .themedNavigationTitle("Настройки приложения", manager: manager)
        .navigationBarTitleDisplayMode(.inline)
    }
}
