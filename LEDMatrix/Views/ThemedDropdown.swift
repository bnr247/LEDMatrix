//
//  ThemedDropdown.swift
//  LEDMatrix
//
//  Системная тема использует нативные Picker/Menu без вмешательства в оформление.
//  В декоративных темах список показывается системным поповером с цветами темы.
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

// MARK: - Системный поповер с цветами темы

private final class DropdownAnchorStore {
    weak var view: UIView?
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

private final class DropdownPopoverDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    static let shared = DropdownPopoverDelegate()

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }

    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        .none
    }
}

@MainActor
private enum DropdownPresenter {
    static func present<Content: View>(
        from sourceView: UIView,
        manager: MatrixManager,
        itemCount: Int,
        @ViewBuilder content: () -> Content
    ) {
        guard let window = sourceView.window else { return }

        var presenter = window.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        guard let presenter else { return }

        let hosting = UIHostingController(rootView: AnyView(content()))
        let padding: CGFloat = 8
        let naturalHeight = 44 * CGFloat(itemCount) + padding * 2
        let maxHeight = max(120, window.bounds.height - 32)

        hosting.view.backgroundColor = UIColor(manager.cardBackgroundColor)
        hosting.preferredContentSize = CGSize(
            width: 280 + padding * 2,
            height: min(naturalHeight, maxHeight)
        )
        hosting.modalPresentationStyle = .popover

        let popover = hosting.popoverPresentationController
        popover?.sourceView = sourceView
        popover?.sourceRect = sourceView.bounds
        popover?.permittedArrowDirections = [.up, .down]
        popover?.popoverLayoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        popover?.backgroundColor = UIColor(manager.cardBackgroundColor)
        popover?.delegate = DropdownPopoverDelegate.shared

        presenter.present(hosting, animated: true)
    }
}

private struct ThemedDropdownPanel: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var manager: MatrixManager
    let items: [ThemedDropdownItem]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    var body: some View {
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
        .frame(width: 280)
        .background(manager.cardBackgroundColor)
        .padding(8)
    }
}

// MARK: - Выпадающий Picker

struct ThemedMenuPicker<Value: Hashable>: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let options: [ThemedDropdownOption<Value>]
    @Binding var selection: Value

    @State private var anchorStore = DropdownAnchorStore()

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
                guard let sourceView = anchorStore.view else { return }
                DropdownPresenter.present(
                    from: sourceView,
                    manager: manager,
                    itemCount: options.count
                ) {
                    ThemedDropdownPanel(
                        manager: manager,
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
            .background(DropdownAnchorReporter(store: anchorStore))
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

    @State private var anchorStore = DropdownAnchorStore()

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
                guard let sourceView = anchorStore.view else { return }
                DropdownPresenter.present(
                    from: sourceView,
                    manager: manager,
                    itemCount: items.count
                ) {
                    ThemedDropdownPanel(
                        manager: manager,
                        items: items,
                        selectedIndex: selectedIndex,
                        onSelect: onSelect
                    )
                }
            } label: {
                label
            }
            .buttonStyle(.plain)
            .background(DropdownAnchorReporter(store: anchorStore))
        }
    }
}
