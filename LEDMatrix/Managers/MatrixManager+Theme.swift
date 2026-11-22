import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "Системная"
    case dark = "Тёмная (OLED)"
    case neon = "Неоновая"
    case amber = "Янтарная"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil // Полностью следует системной схеме iOS
        case .dark: return .dark
        case .neon: return .dark // Неоновая также использует темную базу с яркими акцентами
        case .amber: return .dark // Янтарная — тёплая монохромная LED-палитра
        }
    }
    
    /// Системная тема не добавляет собственного декора: только нативные
    /// семантические цвета iOS, без обводок, свечений и теней.
    var usesSystemAppearance: Bool { self == .system }
    
    /// Толщина обводки карточки для «декоративных» тем.
    var cardBorderWidth: CGFloat {
        switch self {
        case .neon, .amber: return 1.2
        default: return 1
        }
    }
}

extension MatrixManager {
    // Цвет основного фона
    var backgroundColor: Color { Self.backgroundColor(for: currentTheme) }

    static func backgroundColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return Color(uiColor: .systemGroupedBackground)
        case .dark:
            return Color.black // Чистый OLED черный
        case .neon:
            return Color(hex: "080C14") // Глубокий киберпанк-оттенок (ночной сине-угольный)
        case .amber:
            return Color(hex: "140D05") // Тёплый чёрный монохромных LED-дисплеев
        }
    }

    // Цвет карточек / контейнеров
    var cardBackgroundColor: Color { Self.cardBackgroundColor(for: currentTheme) }

    static func cardBackgroundColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return Color(uiColor: .secondarySystemGroupedBackground)
        case .dark:
            return Color(hex: "1A1A1A") // Темный графит для OLED
        case .neon:
            return Color(hex: "111827") // Насыщенный темно-синий киберпанк-графит
        case .amber:
            return Color(hex: "241A0C") // Коричневатый корпус янтарного дисплея
        }
    }

    // Основной цвет текста интерфейса
    var appTextColor: Color {
        switch currentTheme {
        case .system:
            return .primary
        case .dark, .neon, .amber:
            return lightAccentColor
        }
    }

    /// Светлый оттенок акцента — заменяет чистый белый в декоративных темах.
    var lightAccentColor: Color { Self.lightAccentColor(for: currentTheme) }

    static func lightAccentColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return .primary
        case .dark:
            return Color(hex: "A6E6A6") // Насыщенный светло-зелёный OLED
        case .neon:
            return Color(hex: "A8E6F2") // Насыщенный светло-циановый неон
        case .amber:
            return Color(hex: "FFD9A0") // Разогретый янтарь
        }
    }

    /// Цвет значений — совпадает с цветом названия темы, то есть с акцентом.
    var valueTextColor: Color {
        switch currentTheme {
        case .system:
            return .secondary
        case .dark, .neon, .amber:
            return accentColor
        }
    }

    // Акцентный цвет
    var accentColor: Color { Self.accentColor(for: currentTheme) }

    static func accentColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return Color.accentColor // Реальный системный tint (без кастомного ассета)
        case .dark:
            return Color.green
        case .neon:
            return Color(hex: "00F0FF") // Яркий неоновый циан (электрик) для контраста
        case .amber:
            return Color(hex: "FFB000") // Классический янтарный светодиод
        }
    }

    // Цвет обводки (рамок) кнопок и карточек
    var borderColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.separator)
        case .dark:
            return Color.green.opacity(0.5)
        case .neon:
            return Color(hex: "00F0FF").opacity(0.8) // Циановая неоновая граница
        case .amber:
            return Color(hex: "FFB000").opacity(0.7)
        }
    }

    // MARK: - Расширенная палитра темы

    /// Второстепенный текст: подписи, значения, подсказки.
    var secondaryTextColor: Color { Self.secondaryTextColor(for: currentTheme) }

    static func secondaryTextColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return .secondary
        case .dark:
            return Color(hex: "5FBF5F")
        case .neon:
            return Color(hex: "61B9CC")
        case .amber:
            return Color(hex: "B07C36")
        }
    }

    /// Фон полей ввода и небольших вложенных контролов.
    var fieldBackgroundColor: Color { Self.fieldBackgroundColor(for: currentTheme) }

    static func fieldBackgroundColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return Color(uiColor: .systemFill)
        case .dark:
            return Color(hex: "242424")
        case .neon:
            return Color(hex: "0B1524")
        case .amber:
            return Color(hex: "1F160A")
        }
    }

    /// Линии-разделители внутри карточек и списков.
    var dividerColor: Color {
        switch currentTheme {
        case .system:
            return .clear // Нативные разделители списков рисует система
        case .dark:
            return Color(hex: "7EE37E").opacity(0.12)
        case .neon:
            return Color(hex: "00F0FF").opacity(0.16)
        case .amber:
            return Color(hex: "FFB000").opacity(0.18)
        }
    }

    /// Обводка карточек. В системной теме её нет
    var cardBorderColor: Color {
        switch currentTheme {
        case .system:
            return .clear
        case .dark:
            return Color.green.opacity(0.32)
        case .neon:
            return Color(hex: "00F0FF").opacity(0.45)
        case .amber:
            return Color(hex: "FFB000").opacity(0.5)
        }
    }

    /// Подложка вокруг LED-сетки 16×16. Всегда почти чёрная, чтобы
    /// светодиоды читались одинаково хорошо в любой теме.
    var matrixPanelColor: Color {
        switch currentTheme {
        case .system:
            return Color(hex: "171717")
        case .dark:
            return Color(hex: "0E0E0E")
        case .neon:
            return Color(hex: "05080F")
        case .amber:
            return Color(hex: "0D0904")
        }
    }

    /// Цвет тени карточек. В системной теме теней нет.
    var shadowColor: Color {
        switch currentTheme {
        case .system:
            return .clear
        case .dark:
            return Color.black.opacity(0.45)
        case .neon:
            return Color(hex: "00F0FF").opacity(0.16)
        case .amber:
            return Color(hex: "FFB000").opacity(0.12)
        }
    }

    /// Цвет текста/иконок поверх акцентной заливки.
    var accentContrastColor: Color {
        switch currentTheme {
        case .system:
            return .white
        case .dark:
            return .black
        case .neon:
            return Color(hex: "031018")
        case .amber:
            return Color(hex: "1A1206")
        }
    }

    var successColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.systemGreen)
        case .dark:
            return Color(hex: "4ADE80")
        case .neon:
            return Color(hex: "2DFFB2")
        case .amber:
            return Color(hex: "BCE86B")
        }
    }

    var warningColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.systemOrange)
        case .dark:
            return Color(hex: "FBBF24")
        case .neon:
            return Color(hex: "FFC857")
        case .amber:
            return Color(hex: "FFD166")
        }
    }

    var dangerColor: Color {
        switch currentTheme {
        case .system:
            return Color(UIColor.systemRed)
        case .dark:
            return Color(hex: "FF6B6B")
        case .neon:
            return Color(hex: "FF4D8D")
        case .amber:
            return Color(hex: "FF6B4A")
        }
    }

    /// Фон всплывающих подсказок (тостов).
    var toastBackgroundColor: Color {
        switch currentTheme {
        case .system:
            return Color.black.opacity(0.82)
        case .dark:
            return Color(hex: "242424").opacity(0.96)
        case .neon:
            return Color(hex: "0B1524").opacity(0.96)
        case .amber:
            return Color(hex: "241A0C").opacity(0.96)
        }
    }
}
