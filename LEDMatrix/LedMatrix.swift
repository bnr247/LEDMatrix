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
                .onAppear { Self.applyThemeAppearance(manager.currentTheme) }
                .onChange(of: manager.currentTheme) { _, newTheme in
                    Self.applyThemeAppearance(newTheme)
                }
        }
    }

    /// Единая точка настройки UIKit-аппеаранса. Заголовки окон и подвижные
    /// части контролов (thumb у слайдера и тоггла) красятся светлым акцентом.
    /// Системная тема сбрасывает все значения к дефолтам iOS.
    private static func applyThemeAppearance(_ theme: AppTheme) {
        let navigationBar = UINavigationBar.appearance()

        if theme.usesSystemAppearance {
            navigationBar.titleTextAttributes = nil
            navigationBar.largeTitleTextAttributes = nil
            UISwitch.appearance().thumbTintColor = nil
            UISlider.appearance().thumbTintColor = nil
            return
        }

        let color = UIColor(MatrixManager.lightAccentColor(for: theme))
        navigationBar.titleTextAttributes = [.foregroundColor: color]
        navigationBar.largeTitleTextAttributes = [.foregroundColor: color]
        UISwitch.appearance().thumbTintColor = color
        UISlider.appearance().thumbTintColor = color
    }
}
