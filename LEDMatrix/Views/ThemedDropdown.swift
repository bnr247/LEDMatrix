//
//  ThemedDropdown.swift
//  LEDMatrix
//
//  Выпадающие списки: нативные в системной теме и полностью тематические
//  (фон + строки) в декоративных темах.
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

// MARK: - Тематическая панель списка

private struct ThemedDropdownPanel: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var manager: MatrixManager
    let title: String
    let items: [ThemedDropdownItem]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(manager.lightAccentColor)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(manager.secondaryTextColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(manager.dividerColor)
                .padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(item.title)
                                    .foregroundColor(
                                        item.id == selectedIndex
                                            ? manager.accentColor
                                            : manager.lightAccentColor
                                    )
                                Spacer()
                                if item.id == selectedIndex {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(manager.accentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if item.id != items.last?.id {
                            Divider()
                                .background(manager.dividerColor)
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(manager.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(manager.accentColor.opacity(0.7), lineWidth: 1)
                )
        )
        // Отступ от границ поповера: иначе его собственный радиус срезает
        // скругление и обводку панели.
        .padding(8)
        .presentationBackground(.clear)
        .presentationCompactAdaptation(.popover)
    }
}

// MARK: - Выпадающий Picker

struct ThemedMenuPicker<Value: Hashable>: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let options: [ThemedDropdownOption<Value>]
    @Binding var selection: Value

    @State private var isPresented = false

    private var selectedOption: ThemedDropdownOption<Value>? {
        options.first { $0.value == selection }
    }

    var body: some View {
        if manager.currentTheme.usesSystemAppearance {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.menu)
        } else {
            Button { isPresented = true } label: {
                HStack {
                    Text(title)
                        .foregroundColor(manager.appTextColor)
                    Spacer()
                    Text(selectedOption?.title ?? "")
                        .foregroundColor(manager.valueTextColor)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(manager.accentColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                ThemedDropdownPanel(
                    manager: manager,
                    title: title,
                    items: options.map { ThemedDropdownItem(id: $0.id, title: $0.title) },
                    selectedIndex: selectedOption?.id
                ) { index in
                    selection = options[index].value
                }
            }
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

    @State private var isPresented = false

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
            Button { isPresented = true } label: {
                label
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                ThemedDropdownPanel(
                    manager: manager,
                    title: title,
                    items: items,
                    selectedIndex: selectedIndex
                ) { index in
                    onSelect(index)
                }
            }
        }
    }
}
