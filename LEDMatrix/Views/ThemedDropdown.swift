//
//  ThemedDropdown.swift
//  LEDMatrix
//
//  Нативные Picker/Menu: в системной теме без вмешательства в оформление,
//  в декоративных — только цвета темы.
//

import SwiftUI

struct ThemedDropdownItem: Identifiable {
    let id: Int
    let title: String
}

struct ThemedDropdownOption<Value: Hashable>: Identifiable {
    let id: Int
    let title: String
    let value: Value
}

@ViewBuilder
private func themedMenuOption(_ title: String, manager: MatrixManager) -> some View {
    if manager.currentTheme.usesSystemAppearance {
        Text(title)
    } else {
        Text(title)
            .foregroundColor(manager.lightAccentColor)
    }
}

// MARK: - Выпадающий Picker

struct ThemedMenuPicker<Value: Hashable>: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let options: [ThemedDropdownOption<Value>]
    @Binding var selection: Value

    var body: some View {
        if manager.currentTheme.usesSystemAppearance {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    themedMenuOption(option.title, manager: manager)
                        .tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .foregroundColor(manager.appTextColor)
            .tint(manager.valueTextColor)
        }
    }
}

// MARK: - Выпадающее меню действий

struct ThemedActionMenu<Label: View>: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let items: [ThemedDropdownItem]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void
    @ViewBuilder let label: Label

    var body: some View {
        if manager.currentTheme.usesSystemAppearance {
            Menu {
                ForEach(items) { item in
                    Button(action: { onSelect(item.id) }) {
                        Text(item.title)
                    }
                }
            } label: {
                label
            }
        } else {
            Menu {
                ForEach(items) { item in
                    Button(action: { onSelect(item.id) }) {
                        themedMenuOption(item.title, manager: manager)
                    }
                }
            } label: {
                label
            }
            .foregroundColor(manager.appTextColor)
            .tint(manager.valueTextColor)
        }
    }
}
