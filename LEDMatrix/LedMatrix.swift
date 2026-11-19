import SwiftUI

@main
struct LEDMatrixApp: App {
    @StateObject private var manager = MatrixManager()

    var body: some Scene {
        WindowGroup {
            MainScreenView(manager: manager)
                // Системная тема не переопределяет tint — берём дефольт iOS.
                // Декоративные темы задают свой акцент на уровне окна.
                .tint(manager.currentTheme.usesSystemAppearance ? Color.accentColor : manager.accentColor)
                // Глобально меняем схему приложения на уровне окна.
                // Если colorScheme возвращает nil (тема "Системная"), то система берет настройки iOS.
                .preferredColorScheme(manager.currentTheme.colorScheme)
        }
    }
}
