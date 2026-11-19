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

// MARK: - Позиционирование поповера

private let dropdownRowHeight: CGFloat = 45
private let dropdownPanelPadding: CGFloat = 8

private final class DropdownAnchorStore {
    weak var view: UIView?

    var geometry: (frame: CGRect, bounds: CGRect)? {
        guard let view, let window = view.window else { return nil }
        return (view.convert(view.bounds, to: window), window.bounds)
    }
}

private struct DropdownAnchorReporter: UIViewRepresentable {
    let store: DropdownAnchorStore

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        store.view = uiView
    }
}

private struct DropdownMetrics {
    let attachmentAnchor: PopoverAttachmentAnchor
    let arrowEdge: Edge
    let viewportHeight: CGFloat
}

private func dropdownViewportHeight(itemCount: Int) -> CGFloat {
    dropdownRowHeight * CGFloat(itemCount)
}

private func dropdownMetrics(frame: CGRect, bounds: CGRect, itemCount: Int) -> DropdownMetrics {
    let naturalHeight = dropdownViewportHeight(itemCount: itemCount)
    let spaceBelow = max(0, bounds.height - frame.maxY - dropdownPanelPadding)
    let spaceAbove = max(0, frame.minY - dropdownPanelPadding)
    let placeAbove = naturalHeight + dropdownPanelPadding * 2 > spaceBelow && spaceAbove > spaceBelow
    let available = placeAbove ? spaceAbove : spaceBelow
    let viewportHeight = min(
        naturalHeight,
        max(88, available - dropdownPanelPadding * 2)
    )

    return DropdownMetrics(
        attachmentAnchor: placeAbove ? .point(.top) : .point(.bottom),
        arrowEdge: placeAbove ? .bottom : .top,
        viewportHeight: viewportHeight
    )
}

// MARK: - Тематическая панель списка

private struct ThemedDropdownPanel: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var manager: MatrixManager
    let items: [ThemedDropdownItem]
    let selectedIndex: Int?
    let viewportHeight: CGFloat
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
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
        .frame(width: 280, height: viewportHeight)
        .padding(dropdownPanelPadding)
        .presentationBackground(manager.cardBackgroundColor)
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
    @State private var anchorStore = DropdownAnchorStore()
    @State private var attachmentAnchor: PopoverAttachmentAnchor = .point(.bottom)
    @State private var arrowEdge: Edge = .top
    @State private var viewportHeight: CGFloat = 0

    private var selectedOption: ThemedDropdownOption<Value>? {
        options.first { $0.value == selection }
    }

    private func presentDropdown() {
        let metrics = anchorStore.geometry
            .map { dropdownMetrics(frame: $0.frame, bounds: $0.bounds, itemCount: options.count) }
            ?? DropdownMetrics(
                attachmentAnchor: .point(.bottom),
                arrowEdge: .top,
                viewportHeight: dropdownViewportHeight(itemCount: options.count)
            )
        attachmentAnchor = metrics.attachmentAnchor
        arrowEdge = metrics.arrowEdge
        viewportHeight = metrics.viewportHeight
        isPresented = true
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
            Button { presentDropdown() } label: {
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
            .background(DropdownAnchorReporter(store: anchorStore))
            .popover(isPresented: $isPresented, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) {
                ThemedDropdownPanel(
                    manager: manager,
                    items: options.map { ThemedDropdownItem(id: $0.id, title: $0.title) },
                    selectedIndex: selectedOption?.id,
                    viewportHeight: viewportHeight
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
    @State private var anchorStore = DropdownAnchorStore()
    @State private var attachmentAnchor: PopoverAttachmentAnchor = .point(.bottom)
    @State private var arrowEdge: Edge = .top
    @State private var viewportHeight: CGFloat = 0

    private func presentDropdown() {
        let metrics = anchorStore.geometry
            .map { dropdownMetrics(frame: $0.frame, bounds: $0.bounds, itemCount: items.count) }
            ?? DropdownMetrics(
                attachmentAnchor: .point(.bottom),
                arrowEdge: .top,
                viewportHeight: dropdownViewportHeight(itemCount: items.count)
            )
        attachmentAnchor = metrics.attachmentAnchor
        arrowEdge = metrics.arrowEdge
        viewportHeight = metrics.viewportHeight
        isPresented = true
    }

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
            Button { presentDropdown() } label: {
                label
            }
            .buttonStyle(.plain)
            .background(DropdownAnchorReporter(store: anchorStore))
            .popover(isPresented: $isPresented, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) {
                ThemedDropdownPanel(
                    manager: manager,
                    items: items,
                    selectedIndex: selectedIndex,
                    viewportHeight: viewportHeight
                ) { index in
                    onSelect(index)
                }
            }
        }
    }
}
