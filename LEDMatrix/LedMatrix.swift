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
        navigationBar.tintColor = theme.usesSystemAppearance ? nil : UIColor(MatrixManager.accentColor(for: theme))
        UISwitch.appearance().thumbTintColor = thumbColor
        UISlider.appearance().thumbTintColor = thumbColor

        UIDatePicker.appearance().tintColor = datePickerTintColor(for: theme)
        UIDatePicker.appearance().backgroundColor = datePickerBackgroundColor(for: theme)
        UILabel.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).textColor = datePickerTextColor(for: theme)
        UITextField.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).textColor = datePickerTextColor(for: theme)
        UIButton.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).tintColor = datePickerTintColor(for: theme)
        UIPickerView.appearance().backgroundColor = datePickerBackgroundColor(for: theme)
        UIPickerView.appearance().tintColor = datePickerTintColor(for: theme)
        UILabel.appearance(whenContainedInInstancesOf: [UIPickerView.self]).textColor = datePickerTextColor(for: theme)

        let usesSystem = theme.usesSystemAppearance
        let accent = UIColor(MatrixManager.accentColor(for: theme))
        let text = UIColor(MatrixManager.lightAccentColor(for: theme))
        let secondary = UIColor(MatrixManager.secondaryTextColor(for: theme))
        let card = UIColor(MatrixManager.cardBackgroundColor(for: theme))

        let tabBar = UITabBar.appearance()
        tabBar.tintColor = usesSystem ? nil : accent
        tabBar.unselectedItemTintColor = usesSystem ? nil : secondary
        tabBar.barTintColor = usesSystem ? nil : card
        tabBar.backgroundColor = usesSystem ? nil : card
        tabBar.isTranslucent = usesSystem
        UITabBarItem.appearance().setTitleTextAttributes(usesSystem ? nil : [.foregroundColor: secondary], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(usesSystem ? nil : [.foregroundColor: accent], for: .selected)

        let alertView = UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        alertView.tintColor = usesSystem ? nil : accent
        alertView.backgroundColor = usesSystem ? nil : card
        UILabel.appearance(whenContainedInInstancesOf: [UIAlertController.self]).textColor = usesSystem ? nil : text
        let alertField = UITextField.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        alertField.textColor = usesSystem ? nil : accent
        alertField.tintColor = usesSystem ? nil : accent
        alertField.backgroundColor = usesSystem ? nil : UIColor(MatrixManager.fieldBackgroundColor(for: theme))
        UIButton.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = usesSystem ? nil : accent
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
        let usesSystem = theme.usesSystemAppearance
        let tabAccentColor = UIColor(MatrixManager.accentColor(for: theme))
        let tabSecondaryColor = UIColor(MatrixManager.secondaryTextColor(for: theme))
        let tabBackgroundColor = UIColor(MatrixManager.cardBackgroundColor(for: theme))

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
                tabAccentColor: usesSystem ? nil : tabAccentColor,
                tabSecondaryColor: usesSystem ? nil : tabSecondaryColor,
                tabBackgroundColor: usesSystem ? nil : tabBackgroundColor,
                usesSystemAppearance: usesSystem,
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
        tabAccentColor: UIColor?,
        tabSecondaryColor: UIColor?,
        tabBackgroundColor: UIColor?,
        usesSystemAppearance: Bool,
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
        if let tabBar = view as? UITabBar {
            tabBar.tintColor = tabAccentColor
            tabBar.unselectedItemTintColor = tabSecondaryColor
            tabBar.barTintColor = tabBackgroundColor
            tabBar.backgroundColor = tabBackgroundColor
            tabBar.isTranslucent = usesSystemAppearance
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
                tabAccentColor: tabAccentColor,
                tabSecondaryColor: tabSecondaryColor,
                tabBackgroundColor: tabBackgroundColor,
                usesSystemAppearance: usesSystemAppearance,
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
