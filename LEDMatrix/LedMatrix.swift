import SwiftUI
import UIKit

@main
struct LEDMatrixApp: App {
    @StateObject private var manager = MatrixManager()

    init() {
        let rawTheme = UserDefaults.standard.string(forKey: "selected_app_theme")
        Self.applyThemeAppearance(AppTheme(rawValue: rawTheme ?? "") ?? .system)
    }

    var body: some Scene {
        WindowGroup {
            MainScreenView(manager: manager)
                // Системная тема не переопределяет tint — берём дефольт iOS.
                // Декоративные темы задают свой акцент на уровне окна.
                .tint(manager.currentTheme.usesSystemAppearance ? Color.accentColor : manager.accentColor)
                // Глобально меняем схему приложения на уровне окна.
                // Если colorScheme возвращает nil (тема "Системная"), то система берет настройки iOS.
                .preferredColorScheme(manager.currentTheme.colorScheme)
                .onAppear {
                    Self.applyThemeAppearance(manager.currentTheme)
                    Self.refreshExistingControls(for: manager.currentTheme)
                }
                .onChange(of: manager.currentTheme) { _, newTheme in
                    Self.applyThemeAppearance(newTheme)
                    Self.refreshExistingControls(for: newTheme)
                }
        }
    }

    /// Единая точка настройки UIKit-аппеаранса. Заголовки окон и подвижные
    /// части контролов (thumb у слайдера и тоггла) красятся светлым акцентом.
    /// Системная тема сбрасывает все значения к дефолтам iOS.
    private static func applyThemeAppearance(_ theme: AppTheme) {
        let navigationBar = UINavigationBar.appearance()
        let attributes = titleAttributes(for: theme)
        let thumbColor = thumbTintColor(for: theme)

        navigationBar.titleTextAttributes = attributes
        navigationBar.largeTitleTextAttributes = attributes
        UISwitch.appearance().thumbTintColor = thumbColor
        UISlider.appearance().thumbTintColor = thumbColor

        UIDatePicker.appearance().tintColor = datePickerTintColor(for: theme)
        UIDatePicker.appearance().backgroundColor = datePickerBackgroundColor(for: theme)
        UILabel.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).textColor = datePickerTextColor(for: theme)
        UIPickerView.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).backgroundColor = datePickerBackgroundColor(for: theme)
    }

    /// Appearance proxy не перекрашивает уже созданные UISlider/UISwitch,
    /// поэтому при смене темы обновляем их напрямую — иначе, например,
    /// ползунок яркости остаётся янтарным.
    @MainActor
    private static func refreshExistingControls(for theme: AppTheme) {
        let attributes = titleAttributes(for: theme)
        let thumbColor = thumbTintColor(for: theme)
        let dateTextColor = datePickerTextColor(for: theme)
        let dateTintColor = datePickerTintColor(for: theme)
        let dateBackgroundColor = datePickerBackgroundColor(for: theme)

        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows {
            refresh(
                view: window,
                attributes: attributes,
                thumbColor: thumbColor,
                dateTextColor: dateTextColor,
                dateTintColor: dateTintColor,
                dateBackgroundColor: dateBackgroundColor,
                insideDatePicker: false
            )
        }
    }

    @MainActor
    private static func refresh(
        view: UIView,
        attributes: [NSAttributedString.Key: UIColor]?,
        thumbColor: UIColor?,
        dateTextColor: UIColor?,
        dateTintColor: UIColor?,
        dateBackgroundColor: UIColor?,
        insideDatePicker: Bool
    ) {
        if let navigationBar = view as? UINavigationBar {
            navigationBar.titleTextAttributes = attributes
            navigationBar.largeTitleTextAttributes = attributes
        }
        if let slider = view as? UISlider {
            slider.thumbTintColor = thumbColor
        }
        if let toggle = view as? UISwitch {
            toggle.thumbTintColor = thumbColor
        }

        let isDatePicker = view is UIDatePicker
        let isInsideDatePicker = insideDatePicker || isDatePicker

        if let datePicker = view as? UIDatePicker {
            datePicker.tintColor = dateTintColor
            datePicker.backgroundColor = dateBackgroundColor
        }
        if isInsideDatePicker {
            if let pickerView = view as? UIPickerView {
                pickerView.backgroundColor = dateBackgroundColor
            }
            if let label = view as? UILabel {
                label.textColor = dateTextColor
            }
        }

        for subview in view.subviews {
            refresh(
                view: subview,
                attributes: attributes,
                thumbColor: thumbColor,
                dateTextColor: dateTextColor,
                dateTintColor: dateTintColor,
                dateBackgroundColor: dateBackgroundColor,
                insideDatePicker: isInsideDatePicker
            )
        }
    }

    private static func titleAttributes(for theme: AppTheme) -> [NSAttributedString.Key: UIColor]? {
        guard !theme.usesSystemAppearance else { return nil }
        return [.foregroundColor: UIColor(MatrixManager.lightAccentColor(for: theme))]
    }

    private static func thumbTintColor(for theme: AppTheme) -> UIColor? {
        guard !theme.usesSystemAppearance else { return nil }
        return UIColor(MatrixManager.lightAccentColor(for: theme))
    }

    private static func datePickerTextColor(for theme: AppTheme) -> UIColor? {
        guard !theme.usesSystemAppearance else { return nil }
        return UIColor(MatrixManager.lightAccentColor(for: theme))
    }

    private static func datePickerTintColor(for theme: AppTheme) -> UIColor? {
        guard !theme.usesSystemAppearance else { return nil }
        return UIColor(MatrixManager.accentColor(for: theme))
    }

    private static func datePickerBackgroundColor(for theme: AppTheme) -> UIColor? {
        guard !theme.usesSystemAppearance else { return nil }
        return UIColor(MatrixManager.fieldBackgroundColor(for: theme))
    }
}
