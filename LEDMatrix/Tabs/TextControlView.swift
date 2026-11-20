//
//  TextControlTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - ВКЛАДКА ТЕКСТ

import SwiftUI

struct TextControlView: View {
    @ObservedObject var manager: MatrixManager

    /// Отложенная отправка текущего текста: изменения цветов и ползунков
    /// применяются на устройстве почти сразу, но без запроса на каждое
    /// движение пальца.
    @State private var liveUpdateTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 8) {
                    TextField("Введите сообщение...", text: $manager.textToSend, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                        .if(!manager.currentTheme.usesSystemAppearance) { content in
                            content
                                .foregroundColor(manager.appTextColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(manager.fieldBackgroundColor)
                                )
                        }

                    Button(action: sendText) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .if(!manager.currentTheme.usesSystemAppearance) { content in
                                content
                                    .foregroundColor(manager.accentColor)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        Circle()
                                            .fill(manager.accentColor.opacity(0.16))
                                    )
                            }
                    }
                    .themedButtonStyle(manager, .borderless)
                    .disabled(isTextEmpty)
                    .opacity(isTextEmpty ? 0.45 : 1)
                    .accessibilityLabel("Отправить текст")
                }
                .padding(.vertical, 2)
            } header: {
                Text("Сообщение")
                    .if(!manager.currentTheme.usesSystemAppearance) { content in
                        content.foregroundColor(manager.accentColor)
                    }
            } footer: {
                Text("Текст появится на матрице после нажатия кнопки отправки.")
                    .if(!manager.currentTheme.usesSystemAppearance) { content in
                        content.foregroundColor(manager.secondaryTextColor)
                    }
            }
            // Обводим только содержимое секции: заголовок «Сообщение» и
            // описание под полем остаются снаружи, как у карточки «Яркость».
            .listRowBackground(
                Group {
                    if manager.currentTheme.usesSystemAppearance {
                        manager.cardBackgroundColor
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(manager.cardBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(manager.accentColor.opacity(0.5), lineWidth: manager.currentTheme == .neon ? 1.5 : 1)
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                }
            )

            Section {
                ColorPicker("Цвет текста", selection: $manager.textColor, supportsOpacity: false)
                ColorPicker("Цвет фона", selection: $manager.textBgColor, supportsOpacity: false)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Скорость")
                        Spacer()
                        Text("\(Int(manager.scrollSpeedFps))")
                            .foregroundColor(manager.accentColor)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $manager.scrollSpeedFps,
                        in: 10...100,
                        step: 5,
                        onEditingChanged: { editing in
                            // Пока палец на ползунке, меняем только локальное
                            // значение. На устройство отправляем после отпускания.
                            if !editing {
                                scheduleLiveUpdate()
                            }
                        }
                    )
                    .tint(manager.accentColor)
                }

                Stepper("Повторов: \(manager.scrollRepeatCount)", value: $manager.scrollRepeatCount, in: 1...10)
                    .tint(manager.accentColor)
            } header: {
                Text("Параметры")
                    .foregroundColor(manager.accentColor)
            }
            .listRowBackground(manager.cardBackgroundColor)
            
            Section {
                Toggle("Отображать на весь экран", isOn: $manager.textFullScreen)
                    .tint(manager.accentColor)
                    .foregroundColor(manager.appTextColor)
            } header: {
                Text("Отображение")
                    .foregroundColor(manager.accentColor)
            } footer: {
                Text(manager.textFullScreen
                     ? "Классическая бегущая строка на всю матрицу."
                     : "Текст идёт по непрозрачной полосе в центре матрицы, а вокруг виден фон часов или анимации.")
                    .foregroundColor(manager.secondaryTextColor)
            }
            .listRowBackground(manager.cardBackgroundColor)
        }
        .themedForm(manager)
        .onTapGesture { hideKeyboard() }
        .onSubmit { sendText() }
        // Сам текст отправляется только кнопкой отправки или Return.
        // На лету применяются лишь настройки уже показанной строки.
        .onChange(of: manager.textColor) { _, _ in scheduleLiveUpdate() }
        .onChange(of: manager.textBgColor) { _, _ in scheduleLiveUpdate() }
        .onChange(of: manager.scrollRepeatCount) { _, _ in scheduleLiveUpdate() }
        .onDisappear {
            liveUpdateTask?.cancel()
            liveUpdateTask = nil
        }
    }

    private var isTextEmpty: Bool {
        manager.textToSend.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendText() {
        guard !isTextEmpty else { return }
        Task { await manager.sendCurrentText() }
        hideKeyboard()
    }

    private func scheduleLiveUpdate() {
        liveUpdateTask?.cancel()

        liveUpdateTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await manager.updateTextSettings()
        }
    }
}
