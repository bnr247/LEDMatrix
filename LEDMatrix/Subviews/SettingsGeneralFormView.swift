//
//  SettingsGeneralFormView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ФОРМА: ОБЩИЕ НАСТРОЙКИ

import SwiftUI
import UIKit

struct SettingsGeneralFormView: View {
    @ObservedObject var manager: MatrixManager
    
    var body: some View {
        Form {
            Section(header: Text("Время на экране").themedSectionHeader(manager)) {
                Stepper(value: manager.clockDisplaySecondsBinding, in: 1...86400, step: 10) {
                    HStack {
                        Text("Часы (сек.)")
                            .foregroundColor(manager.appTextColor)
                        Spacer()
                        Text("\(manager.settings.clockDisplaySeconds)")
                            .foregroundColor(manager.valueTextColor)
                    }
                }
                
                Stepper(value: manager.animationDisplaySecondsBinding, in: 1...86400, step: 10) {
                    HStack {
                        Text("Анимации (сек.)")
                            .foregroundColor(manager.appTextColor)
                        Spacer()
                        Text("\(manager.settings.animationDisplaySeconds)")
                            .foregroundColor(manager.valueTextColor)
                    }
                }
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section(header: Text("Тип анимации").themedSectionHeader(manager)) {
                ThemedMenuPicker(
                    manager: manager,
                    title: "Режим",
                    options: [
                        ThemedDropdownOption(id: 0, title: "Стандартный", value: AnimationType.standard(sortOrder: manager.settings.animationType?.sortOrder ?? 0)),
                        ThemedDropdownOption(id: 1, title: "Категории", value: AnimationType.category(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0)),
                        ThemedDropdownOption(id: 2, title: "Альбом", value: AnimationType.album(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0)),
                        ThemedDropdownOption(id: 3, title: "Избранное", value: AnimationType.likes(sortOrder: manager.settings.animationType?.sortOrder ?? 0)),
                        ThemedDropdownOption(id: 4, title: "Плейлист", value: AnimationType.playlist(id: manager.settings.animationType?.id ?? 0, sortOrder: manager.settings.animationType?.sortOrder ?? 0))
                    ],
                    selection: manager.animationTypeBinding
                )
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section(header: Text("День").themedSectionHeader(manager)) {
                if manager.currentTheme.usesSystemAppearance {
                    DatePicker(
                        "Начало",
                        selection: manager.dayStartTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                } else {
                    HStack {
                        Text("Начало")
                            .themedParameterText(manager)
                        Spacer()
                        ThemedTimePicker(manager: manager, selection: manager.dayStartTimeBinding)
                    }
                }
                
                ThemedMenuPicker(
                    manager: manager,
                    title: "Режим экрана",
                    options: [
                        ThemedDropdownOption(id: 0, title: "Смешанный", value: "mixed"),
                        ThemedDropdownOption(id: 1, title: "Только часы", value: "clock_only"),
                        ThemedDropdownOption(id: 2, title: "Только анимация", value: "animation_only")
                    ],
                    selection: manager.dayDeviceModeBinding
                )
                
                VStack(alignment: .leading) {
                    Text("Яркость: ")
                        .foregroundColor(manager.appTextColor)
                    + Text("\(manager.settings.dayBrightnessPercent)")
                        .foregroundColor(manager.valueTextColor)
                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.dayBrightnessPercent) },
                            set: { newValue in Task { await manager.updateBrightnessDay(Int(newValue)) } }
                        ),
                        in: 0...100, step: 5
                    )
                }
                .tint(manager.accentColor)
                .padding(.top, 4)
            }
            .listRowBackground(manager.cardBackgroundColor)
                
            Section(header: Text("Ночь").themedSectionHeader(manager)) {
                if manager.currentTheme.usesSystemAppearance {
                    DatePicker(
                        "Начало",
                        selection: manager.nightStartTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                } else {
                    HStack {
                        Text("Начало")
                            .themedParameterText(manager)
                        Spacer()
                        ThemedTimePicker(manager: manager, selection: manager.nightStartTimeBinding)
                    }
                }
                
                ThemedMenuPicker(
                    manager: manager,
                    title: "Режим экрана",
                    options: [
                        ThemedDropdownOption(id: 0, title: "Смешанный", value: "mixed"),
                        ThemedDropdownOption(id: 1, title: "Только часы", value: "clock_only"),
                        ThemedDropdownOption(id: 2, title: "Только анимация", value: "animation_only")
                    ],
                    selection: manager.nightDeviceModeBinding
                )
                
                VStack(alignment: .leading) {
                    Text("Яркость: ")
                        .foregroundColor(manager.appTextColor)
                    + Text("\(manager.settings.nightBrightnessPercent)")
                        .foregroundColor(manager.valueTextColor)
                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.nightBrightnessPercent) },
                            set: { newValue in Task { await manager.updateBrightnessNight(Int(newValue)) } }
                        ),
                        in: 0...100, step: 5
                    )
                }
                .tint(manager.accentColor)
                .padding(.top, 4)
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section(header: Text("Бегущая строка").themedSectionHeader(manager)) {
                Toggle("Отображать имя из Telegram", isOn: Binding(
                    get: { manager.settings.showNameText },
                    set: { newValue in Task { await manager.toggleShowTextUsername(newValue) } }
                ))
                .tint(manager.accentColor)
            }
            .listRowBackground(manager.cardBackgroundColor)
        }
        .themedForm(manager)
        .id(manager.currentTheme)
        .navigationTitle("Общие настройки")
    }
}

/// Компактный пикер времени для декоративных тем.
/// SwiftUI `DatePicker` не открывает свои внутренние UILabel/UITextField,
/// поэтому красим UIDatePicker и всё его дерево напрямую.
struct ThemedTimePicker: UIViewRepresentable {
    @ObservedObject var manager: MatrixManager
    @Binding var selection: Date

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.date = selection
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)

        applyTheme(to: picker)
        DispatchQueue.main.async { [weak picker] in
            guard let picker else { return }
            self.applyTheme(to: picker)
        }

        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        if !Calendar.current.isDate(uiView.date, equalTo: selection, toGranularity: .minute) {
            uiView.date = selection
        }

        applyTheme(to: uiView)
        DispatchQueue.main.async { [weak uiView] in
            guard let uiView else { return }
            self.applyTheme(to: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator {
        var parent: ThemedTimePicker

        init(parent: ThemedTimePicker) {
            self.parent = parent
        }

        @objc func dateChanged(_ picker: UIDatePicker) {
            parent.selection = picker.date
        }
    }

    private func applyTheme(to picker: UIDatePicker) {
        guard !manager.currentTheme.usesSystemAppearance else { return }

        let accent = UIColor(manager.accentColor)
        let text = UIColor(manager.lightAccentColor)
        let background = UIColor(manager.fieldBackgroundColor)

        picker.overrideUserInterfaceStyle = .dark
        picker.tintColor = accent
        picker.backgroundColor = background
        picker.layer.cornerRadius = 8
        picker.clipsToBounds = true

        colorSubviews(of: picker, accent: accent, text: text, background: background)
    }

    private func colorSubviews(of view: UIView, accent: UIColor, text: UIColor, background: UIColor) {
        view.tintColor = accent

        if let pickerView = view as? UIPickerView {
            pickerView.backgroundColor = background
            pickerView.tintColor = accent
        }
        if let button = view as? UIButton {
            button.tintColor = accent
        }
        if let label = view as? UILabel {
            if let attributed = label.attributedText, attributed.length > 0 {
                let colored = NSMutableAttributedString(attributedString: attributed)
                colored.addAttributes(
                    [.foregroundColor: text],
                    range: NSRange(location: 0, length: colored.length)
                )
                label.attributedText = colored
            } else {
                label.textColor = text
            }
        }
        if let textField = view as? UITextField {
            textField.textColor = text
            textField.tintColor = accent
            if let attributed = textField.attributedText, attributed.length > 0 {
                let colored = NSMutableAttributedString(attributedString: attributed)
                colored.addAttributes(
                    [.foregroundColor: text],
                    range: NSRange(location: 0, length: colored.length)
                )
                textField.attributedText = colored
            }
        }

        for subview in view.subviews {
            colorSubviews(of: subview, accent: accent, text: text, background: background)
        }
    }
}
