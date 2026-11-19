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

private struct DropdownAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
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
        // Отступ от границ: скругление и обводка панели не обрезаются.
        .padding(8)
        .presentationBackground(.clear)
        .presentationCompactAdaptation(.popover)
    }
}

// MARK: - Оверлей без системного баббла со стрелкой

private struct ThemedDropdownOverlay: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var manager: MatrixManager
    let anchor: CGRect
    let title: String
    let items: [ThemedDropdownItem]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }

                let panelWidth: CGFloat = 296
                let estimatedHeight = CGFloat(48 * items.count + 76)
                let below = anchor.maxY + 8
                let y = below + estimatedHeight > geo.size.height
                    ? max(8, anchor.minY - 8 - estimatedHeight)
                    : max(8, below)
                let x = min(max(anchor.minX, 8), max(8, geo.size.width - panelWidth - 8))

                ThemedDropdownPanel(
                    manager: manager,
                    title: title,
                    items: items,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect
                )
                .offset(x: x, y: y)
            }
        }
        .presentationBackground(.clear)
    }
}

// MARK: - Выпадающий Picker

struct ThemedMenuPicker<Value: Hashable>: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let options: [ThemedDropdownOption<Value>]
    @Binding var selection: Value

    @State private var isPresented = false
    @State private var anchor: CGRect = .zero

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
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: DropdownAnchorKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(DropdownAnchorKey.self) { anchor = $0 }
            .fullScreenCover(isPresented: $isPresented) {
                ThemedDropdownOverlay(
                    manager: manager,
                    anchor: anchor,
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
    @State private var anchor: CGRect = .zero

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
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: DropdownAnchorKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(DropdownAnchorKey.self) { anchor = $0 }
            .fullScreenCover(isPresented: $isPresented) {
                ThemedDropdownOverlay(
                    manager: manager,
                    anchor: anchor,
                    title: title,
                    items: items,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect
                )
            }
        }
    }
}
