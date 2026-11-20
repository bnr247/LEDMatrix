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
                // Системная тема не переопределяет tint — берём дефолт iOS.
                .tint(manager.currentTheme.usesSystemAppearance ? Color.accentColor : manager.lightAccentColor)
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

    /// Единая точка настройки UIKit-аппеаранса.
    /// Декоративные темы красят навигацию, таббар и кнопки светлым акцентом,
    /// системная тема возвращает стандартные appearance-объекты iOS.
    private static func applyThemeAppearance(_ theme: AppTheme) {
        let usesSystem = theme.usesSystemAppearance
        let light = UIColor(MatrixManager.lightAccentColor(for: theme))
        let accent = UIColor(MatrixManager.accentColor(for: theme))
        let card = UIColor(MatrixManager.cardBackgroundColor(for: theme))

        let navigationBar = UINavigationBar.appearance()
        let navigationAppearance = navigationBarAppearance(for: theme)
        navigationBar.standardAppearance = navigationAppearance
        navigationBar.compactAppearance = navigationAppearance
        navigationBar.scrollEdgeAppearance = navigationAppearance
        navigationBar.titleTextAttributes = titleAttributes(for: theme)
        navigationBar.largeTitleTextAttributes = titleAttributes(for: theme)
        navigationBar.tintColor = usesSystem ? nil : light

        let barButton = UIBarButtonItem.appearance()
        barButton.tintColor = usesSystem ? nil : light
        let buttonTitleAttributes: [NSAttributedString.Key: Any]? = usesSystem ? nil : [.foregroundColor: light]
        barButton.setTitleTextAttributes(buttonTitleAttributes, for: .normal)
        barButton.setTitleTextAttributes(buttonTitleAttributes, for: .highlighted)
        barButton.setTitleTextAttributes(buttonTitleAttributes, for: .disabled)

        UISwitch.appearance().thumbTintColor = thumbTintColor(for: theme)
        UISlider.appearance().thumbTintColor = thumbTintColor(for: theme)

        let tabBar = UITabBar.appearance()
        let tabAppearance = tabBarAppearance(for: theme)
        tabBar.standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = tabAppearance
        }
        tabBar.tintColor = usesSystem ? nil : accent
        tabBar.unselectedItemTintColor = usesSystem ? nil : light
        tabBar.barTintColor = usesSystem ? nil : card
        tabBar.backgroundColor = usesSystem ? nil : card
        tabBar.isTranslucent = usesSystem
        UITabBarItem.appearance().setTitleTextAttributes(usesSystem ? nil : [.foregroundColor: light], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(usesSystem ? nil : [.foregroundColor: accent], for: .selected)

        let alertView = UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        alertView.tintColor = usesSystem ? nil : accent
        alertView.backgroundColor = usesSystem ? nil : card
        UILabel.appearance(whenContainedInInstancesOf: [UIAlertController.self]).textColor = usesSystem ? nil : light
        let alertField = UITextField.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        alertField.textColor = usesSystem ? nil : light
        alertField.tintColor = usesSystem ? nil : accent
        alertField.backgroundColor = usesSystem ? nil : UIColor(MatrixManager.fieldBackgroundColor(for: theme))
        UIButton.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = usesSystem ? nil : accent
    }

    /// Appearance proxy не перекрашивает уже созданные UINavigationBar,
    /// UITabBar, UISlider и UISwitch — обновляем их напрямую при смене темы.
    @MainActor
    private static func refreshExistingControls(for theme: AppTheme) {
        let usesSystem = theme.usesSystemAppearance
        let navigationAppearance = navigationBarAppearance(for: theme)
        let tabAppearance = tabBarAppearance(for: theme)
        let light = UIColor(MatrixManager.lightAccentColor(for: theme))
        let accent = UIColor(MatrixManager.accentColor(for: theme))
        let card = UIColor(MatrixManager.cardBackgroundColor(for: theme))

        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows {
            refresh(
                view: window,
                navigationAppearance: navigationAppearance,
                navigationTintColor: usesSystem ? nil : light,
                titleAttributes: titleAttributes(for: theme),
                thumbColor: thumbTintColor(for: theme),
                tabAppearance: tabAppearance,
                tabSelectedColor: usesSystem ? nil : accent,
                tabUnselectedColor: usesSystem ? nil : light,
                tabBackgroundColor: usesSystem ? nil : card,
                usesSystemAppearance: usesSystem
            )
        }
    }

    @MainActor
    private static func refresh(
        view: UIView,
        navigationAppearance: UINavigationBarAppearance,
        navigationTintColor: UIColor?,
        titleAttributes: [NSAttributedString.Key: UIColor]?,
        thumbColor: UIColor?,
        tabAppearance: UITabBarAppearance,
        tabSelectedColor: UIColor?,
        tabUnselectedColor: UIColor?,
        tabBackgroundColor: UIColor?,
        usesSystemAppearance: Bool
    ) {
        if let navigationBar = view as? UINavigationBar {
            navigationBar.standardAppearance = navigationAppearance
            navigationBar.compactAppearance = navigationAppearance
            navigationBar.scrollEdgeAppearance = navigationAppearance
            navigationBar.titleTextAttributes = titleAttributes
            navigationBar.largeTitleTextAttributes = titleAttributes
            navigationBar.tintColor = navigationTintColor
        }
        if let slider = view as? UISlider {
            slider.thumbTintColor = thumbColor
        }
        if let toggle = view as? UISwitch {
            toggle.thumbTintColor = thumbColor
        }
        if let tabBar = view as? UITabBar {
            tabBar.standardAppearance = tabAppearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = tabAppearance
            }
            tabBar.tintColor = tabSelectedColor
            tabBar.unselectedItemTintColor = tabUnselectedColor
            tabBar.barTintColor = tabBackgroundColor
            tabBar.backgroundColor = tabBackgroundColor
            tabBar.isTranslucent = usesSystemAppearance
        }

        for subview in view.subviews {
            refresh(
                view: subview,
                navigationAppearance: navigationAppearance,
                navigationTintColor: navigationTintColor,
                titleAttributes: titleAttributes,
                thumbColor: thumbColor,
                tabAppearance: tabAppearance,
                tabSelectedColor: tabSelectedColor,
                tabUnselectedColor: tabUnselectedColor,
                tabBackgroundColor: tabBackgroundColor,
                usesSystemAppearance: usesSystemAppearance
            )
        }
    }

    private static func navigationBarAppearance(for theme: AppTheme) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        guard !theme.usesSystemAppearance else { return appearance }

        let titleColor = UIColor(MatrixManager.lightAccentColor(for: theme))
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        let buttonColor = UIColor(MatrixManager.lightAccentColor(for: theme))
        let buttons = UIBarButtonItemAppearance()
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: buttonColor]
        buttons.normal.titleTextAttributes = attributes
        buttons.highlighted.titleTextAttributes = attributes
        buttons.disabled.titleTextAttributes = [.foregroundColor: buttonColor.withAlphaComponent(0.5)]
        appearance.buttonAppearance = buttons
        appearance.backButtonAppearance = buttons
        appearance.doneButtonAppearance = buttons

        return appearance
    }

    private static func tabBarAppearance(for theme: AppTheme) -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        guard !theme.usesSystemAppearance else { return appearance }

        appearance.backgroundColor = UIColor(MatrixManager.cardBackgroundColor(for: theme))

        let item = UITabBarItemAppearance()
        let selected = UIColor(MatrixManager.accentColor(for: theme))
        let normal = UIColor(MatrixManager.lightAccentColor(for: theme))
        item.normal.titleTextAttributes = [.foregroundColor: normal]
        item.selected.titleTextAttributes = [.foregroundColor: selected]
        item.normal.iconColor = normal
        item.selected.iconColor = selected
        item.focused.titleTextAttributes = [.foregroundColor: selected]
        item.focused.iconColor = selected

        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item

        return appearance
    }

    private static func titleAttributes(for theme: AppTheme) -> [NSAttributedString.Key: UIColor]? {
        guard !theme.usesSystemAppearance else { return nil }
        return [.foregroundColor: UIColor(MatrixManager.lightAccentColor(for: theme))]
    }

    private static func thumbTintColor(for theme: AppTheme) -> UIColor? {
        guard !theme.usesSystemAppearance else { return nil }
        return UIColor(MatrixManager.accentColor(for: theme))
    }
}
