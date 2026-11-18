import SwiftUI

@main
struct LEDMatrixApp: App {
    @StateObject private var manager = MatrixManager()

    var body: some Scene {
        WindowGroup {
            MainScreenView(manager: manager)
                // Глобально меняем схему приложения на уровне окна.
                // Если colorScheme возвращает nil (тема "Системная"), то система берет настройки iOS.
                .preferredColorScheme(manager.currentTheme.colorScheme)
        }
    }
}
