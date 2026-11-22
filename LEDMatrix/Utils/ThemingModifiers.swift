import Foundation
import SwiftUI
import UIKit

// MARK: - Общие тематические модификаторы

/// Нативные стили кнопок, которые применяются только в системной теме.
enum ThemedButtonStyle {
    case plain
    case borderless
    case bordered
    case borderedProminent
}

extension View {
    /// Условный модификатор: позволяет выключать декоративные слои
    /// только для нативной темы, не раздувая body.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// В системной теме кнопка получает нативный стиль iOS.
    /// В остальных темах сохраняется `.plain`, чтобы работала кастомная обводка.
    @ViewBuilder
    func themedButtonStyle(_ manager: MatrixManager, _ style: ThemedButtonStyle) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            switch style {
            case .plain:
                self.buttonStyle(.plain)
            case .borderless:
                self.buttonStyle(.borderless)
            case .bordered:
                self.buttonStyle(.bordered)
            case .borderedProminent:
                self.buttonStyle(.borderedProminent)
            }
        } else {
            self.buttonStyle(.plain)
        }
    }

    /// Большая кнопка действия: в декоративных темах повторяет плитку функции
    /// на главном экране — карточка, обводка акцентом и светлый акцентный текст.
    /// В системной теме остаётся нативной prominent-кнопкой с заданным tint.
    @ViewBuilder
    func themedActionButton(_ manager: MatrixManager, buttonTint: Color? = nil, isEnabled: Bool = true) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            if let buttonTint {
                self.buttonStyle(.borderedProminent).tint(buttonTint)
            } else {
                self.buttonStyle(.borderedProminent)
            }
        } else {
            self
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(manager.cardBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(buttonTint ?? manager.accentColor, lineWidth: manager.currentTheme == .neon ? 1.5 : 1)
                        )
                )
                .foregroundColor(isEnabled ? manager.appTextColor : manager.secondaryTextColor)
                .shadow(color: manager.shadowColor, radius: 5, x: 0, y: 3)
                .buttonStyle(.plain)
                .opacity(isEnabled ? 1 : 0.5)
        }
    }

    /// Белый текст на тёмных плашках: в декоративных темах — светлый акцент,
    /// в системной остаётся нативным белым.
    @ViewBuilder
    func themedLightText(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self.foregroundColor(.white)
        } else {
            self.foregroundColor(manager.lightAccentColor)
        }
    }

    /// Системная тема вообще не вмешивается в оформление Form/List:
    /// ни фон, ни tint — всё берётся из дефолтов iOS.
    @MainActor
    @ViewBuilder
    func themedForm(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self
                .scrollContentBackground(.hidden)
                .background(manager.backgroundColor.ignoresSafeArea())
                .foregroundColor(manager.appTextColor)
                .tint(manager.accentColor)
        }
    }

    /// Системная тема не рисует декоративную карточку: только нативная
    /// семантическая заливка строки, без скругления, обводки и тени.
    @MainActor
    @ViewBuilder
    func themedCard(_ manager: MatrixManager, cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        if manager.currentTheme.usesSystemAppearance {
            self.background(manager.cardBackgroundColor)
        } else {
            self
                .background(shape.fill(manager.cardBackgroundColor))
                .overlay(shape.stroke(manager.cardBorderColor, lineWidth: manager.currentTheme.cardBorderWidth))
                .shadow(color: manager.shadowColor, radius: 6, x: 0, y: 3)
        }
    }

    /// Название параметра: в декоративных темах светлый акцент,
    /// в системной — нативный primary.
    @ViewBuilder
    func themedParameterText(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self.foregroundColor(manager.appTextColor)
        }
    }

    /// Значение параметра: в декоративных темах акцент,
    /// в системной — нативный текст без переопределения.
    @ViewBuilder
    func themedValueText(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self
                .foregroundColor(manager.valueTextColor)
                .tint(manager.accentColor)
        }
    }

    /// Небольшая кнопка в стиле карточек главного экрана: фон темы,
    /// обводка акцентом и светлый акцентный текст. Системная — нативная.
    @ViewBuilder
    func themedInlineButton(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self.buttonStyle(.bordered).controlSize(.small)
        } else {
            self
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(manager.cardBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(manager.accentColor.opacity(0.7), lineWidth: 1)
                        )
                )
                .foregroundColor(manager.lightAccentColor)
                .buttonStyle(.plain)
        }
    }

    /// Заголовок экрана: системная тема остаётся нативной, декоративные
    /// красят заголовок светлым акцентом.
    @ViewBuilder
    func themedNavigationTitle(_ title: LocalizedStringKey, manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self.navigationTitle(title)
        } else {
            self.modifier(ThemedNavigationBarModifier(manager: manager, title: Text(title)))
        }
    }

    @ViewBuilder
    func themedNavigationTitle(_ title: String, manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self.navigationTitle(title)
        } else {
            self.modifier(ThemedNavigationBarModifier(manager: manager, title: Text(verbatim: title)))
        }
    }

    /// Заголовки секций в системной теме остаются нативными (secondary).
    @ViewBuilder
    func themedSectionHeader(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self.foregroundColor(manager.accentColor)
        }
    }

    /// Оставляет нативный полупрозрачный navbar в системной теме.
    @MainActor
    @ViewBuilder
    func themedToolbarBackground(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self
                .toolbarBackground(manager.cardBackgroundColor, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    /// Тёмный «терминальный» navbar нужен только декоративным темам.
    @MainActor
    @ViewBuilder
    func themedDarkToolbar(_ manager: MatrixManager) -> some View {
        if manager.currentTheme.usesSystemAppearance {
            self
        } else {
            self
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbarBackground(manager.matrixPanelColor, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

/// Системный `.navigationTitle` перекрашивается iOS в белый, поэтому заголовок
/// рисуется отдельным `.principal`-элементом. Кнопка «Назад» и swipe-жест
/// остаются системными — кастомная кнопка ломала навигацию.
struct ThemedNavigationBarModifier: ViewModifier {
    @ObservedObject var manager: MatrixManager
    let title: Text

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .tint(manager.lightAccentColor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    title
                        .foregroundColor(manager.lightAccentColor)
                        .fixedSize()
                }
            }
            .background(UIKitThemeConfigurator(manager: manager))
    }
}

/// Принудительно применяет UIKit-аппеаранс после того, как SwiftUI создал
/// UINavigationBar/UITabBar. Appearance-прокси и `themedForm` не перекрашивают
/// уже созданные бары, поэтому configurator вызывается на появлении экрана.
struct UIKitThemeConfigurator: UIViewControllerRepresentable {
    @ObservedObject var manager: MatrixManager

    func makeUIViewController(context: Context) -> ThemeConfiguratorViewController {
        ThemeConfiguratorViewController(manager: manager)
    }

    func updateUIViewController(_ uiViewController: ThemeConfiguratorViewController, context: Context) {
        uiViewController.manager = manager
        uiViewController.applyTheme()
    }

    final class ThemeConfiguratorViewController: UIViewController {
        var manager: MatrixManager
        private var didApplyAfterLayout = false

        init(manager: MatrixManager) {
            self.manager = manager
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            didApplyAfterLayout = false
            applyTheme()
            DispatchQueue.main.async { self.applyTheme() }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            guard !didApplyAfterLayout else { return }
            didApplyAfterLayout = true
            DispatchQueue.main.async { self.applyTheme() }
        }

        func applyTheme() {
            let theme = manager.currentTheme
            LEDMatrixApp.applyThemeAppearance(theme)

            // Прямо красим навбар, который содержит текущий экран: SwiftUI
            // пересоздаёт его после appearance-прокси и сбрасывает tint.
            if let bar = navigationController?.navigationBar {
                let light = UIColor(MatrixManager.lightAccentColor(for: theme))
                bar.tintColor = theme.usesSystemAppearance ? nil : light
                var chevron: UIImage?
                if !theme.usesSystemAppearance {
                    chevron = UIImage(systemName: "chevron.left")?
                        .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
                        .withTintColor(light, renderingMode: .alwaysOriginal)
                }
                bar.backIndicatorImage = chevron
                bar.backIndicatorTransitionMaskImage = chevron
            }

            Task { @MainActor in
                LEDMatrixApp.refreshExistingControls(for: theme)
            }
        }
    }
}
