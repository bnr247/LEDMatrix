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
                .tint(manager.currentTheme.usesSystemAppearance ? Color.accentColor : manager.accentColor)
                // `nil` для системной темы означает следовать настройкам iOS.
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

    /// Единая точка настройки UIKit-аппеаранса. В декоративных темах
    /// заголовки и контролы красятся акцентом — без белого.
    /// Системная тема сбрасывает все значения к дефолтам iOS.
    private static func applyThemeAppearance(_ theme: AppTheme) {
        let navigationBar = UINavigationBar.appearance()
        let attributes = titleAttributes(for: theme)

        navigationBar.titleTextAttributes = attributes
        navigationBar.largeTitleTextAttributes = attributes
        navigationBar.tintColor = theme.usesSystemAppearance ? nil : UIColor(MatrixManager.accentColor(for: theme))
        UISwitch.appearance().thumbTintColor = thumbTintColor(for: theme)
        UISlider.appearance().thumbTintColor = thumbTintColor(for: theme)

        let usesSystem = theme.usesSystemAppearance
        let accent = UIColor(MatrixManager.accentColor(for: theme))
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
        UILabel.appearance(whenContainedInInstancesOf: [UIAlertController.self]).textColor = usesSystem ? nil : accent
        let alertField = UITextField.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        alertField.textColor = usesSystem ? nil : accent
        alertField.tintColor = usesSystem ? nil : accent
        alertField.backgroundColor = usesSystem ? nil : UIColor(MatrixManager.fieldBackgroundColor(for: theme))
        UIButton.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = usesSystem ? nil : accent
    }

    /// Appearance proxy не перекрашивает уже созданные UINavigationBar,
    /// UISlider, UISwitch и UITabBar — обновляем их напрямую при смене темы.
    @MainActor
    private static func refreshExistingControls(for theme: AppTheme) {
        let attributes = titleAttributes(for: theme)
        let thumbColor = thumbTintColor(for: theme)
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
                tabAccentColor: usesSystem ? nil : tabAccentColor,
                tabSecondaryColor: usesSystem ? nil : tabSecondaryColor,
                tabBackgroundColor: usesSystem ? nil : tabBackgroundColor,
                usesSystemAppearance: usesSystem
            )
        }
    }

    @MainActor
    private static func refresh(
        view: UIView,
        attributes: [NSAttributedString.Key: UIColor]?,
        thumbColor: UIColor?,
        tabAccentColor: UIColor?,
        tabSecondaryColor: UIColor?,
        tabBackgroundColor: UIColor?,
        usesSystemAppearance: Bool
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

        for subview in view.subviews {
            refresh(
                view: subview,
                attributes: attributes,
                thumbColor: thumbColor,
                tabAccentColor: tabAccentColor,
                tabSecondaryColor: tabSecondaryColor,
                tabBackgroundColor: tabBackgroundColor,
                usesSystemAppearance: usesSystemAppearance
            )
        }
    }

    private static func titleAttributes(for theme: AppTheme) -> [NSAttributedString.Key: UIColor]? {
        guard !theme.usesSystemAppearance else { return nil }
        return [.foregroundColor: UIColor(MatrixManager.accentColor(for: theme))]
    }

    private static func thumbTintColor(for theme: AppTheme) -> UIColor? {
        guard !theme.usesSystemAppearance else { return nil }
        return UIColor(MatrixManager.accentColor(for: theme))
    }
}
