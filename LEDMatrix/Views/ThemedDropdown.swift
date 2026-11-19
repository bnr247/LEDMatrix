//
//  ThemedDropdown.swift
//  LEDMatrix
//
//  Выпадающие списки: нативные в системной теме и полностью тематические
//  (фон + строки) в декоративных темах.
//

import SwiftUI
import UIKit

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

// MARK: - Показ панели прямо в окне приложения

@MainActor
private enum DropdownOverlay {
    static var host: UIHostingController<AnyView>?

    static func present<Content: View>(@ViewBuilder content: () -> Content) {
        guard host == nil,
              let scene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }

        let controller = UIHostingController(rootView: AnyView(content()))
        controller.view.frame = window.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.backgroundColor = .clear
        window.addSubview(controller.view)
        host = controller
    }

    static func dismiss() {
        host?.view.removeFromSuperview()
        host = nil
    }
}

// MARK: - Тематическая панель списка

private struct ThemedDropdownPanel: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let items: [ThemedDropdownItem]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(manager.lightAccentColor)
                Spacer()
                Button(action: onDismiss) {
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
                        Button { onSelect(item.id) } label: {
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
        .padding(8)
    }
}

// MARK: - Оверлей с привязкой к месту нажатия

private struct ThemedDropdownOverlay: View {
    @ObservedObject var manager: MatrixManager
    let anchor: CGRect
    let title: String
    let items: [ThemedDropdownItem]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { DropdownOverlay.dismiss() }

                let panelWidth: CGFloat = 296
                let panelHeight = CGFloat(45 * items.count + 62)
                let centerX = min(max(anchor.midX, panelWidth / 2 + 8), geo.size.width - panelWidth / 2 - 8)
                let belowCenter = anchor.maxY + 8 + panelHeight / 2
                let aboveCenter = anchor.minY - 8 - panelHeight / 2
                let preferredY = belowCenter + panelHeight / 2 <= geo.size.height - 8
                    ? belowCenter
                    : aboveCenter
                let centerY = min(max(preferredY, panelHeight / 2 + 8), geo.size.height - panelHeight / 2 - 8)

                ThemedDropdownPanel(
                    manager: manager,
                    title: title,
                    items: items,
                    selectedIndex: selectedIndex,
                    onSelect: { index in
                        onSelect(index)
                        DropdownOverlay.dismiss()
                    },
                    onDismiss: { DropdownOverlay.dismiss() }
                )
                .frame(width: panelWidth, height: panelHeight)
                .position(x: centerX, y: centerY)
            }
        }
    }
}

// MARK: - Выпадающий Picker

struct ThemedMenuPicker<Value: Hashable>: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let options: [ThemedDropdownOption<Value>]
    @Binding var selection: Value

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
            Button {
                DropdownOverlay.present {
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
            } label: {
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
            Button {
                DropdownOverlay.present {
                    ThemedDropdownOverlay(
                        manager: manager,
                        anchor: anchor,
                        title: title,
                        items: items,
                        selectedIndex: selectedIndex,
                        onSelect: onSelect
                    )
                }
            } label: {
                label
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: DropdownAnchorKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(DropdownAnchorKey.self) { anchor = $0 }
        }
    }
}
