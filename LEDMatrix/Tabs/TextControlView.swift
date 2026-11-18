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
                TextField("Введите сообщение...", text: $manager.textToSend)
                    .foregroundColor(manager.appTextColor)
                
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
                Text("Бегущая строка")
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
            
            Section {
                Button(action: {
                    Task { await manager.sendCurrentText() }
                    hideKeyboard()
                }) {
                    Text("Отправить")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.accentColor)
                .listRowBackground(Color.clear)
            }
        }
        .themedForm(manager)
        .onTapGesture { hideKeyboard() }
        .onSubmit {
            Task { await manager.sendCurrentText() }
            hideKeyboard()
        }
        // Сам текст отправляется только кнопкой «Отправить» или Return.
        // На лету применяются лишь настройки уже показанной строки.
        .onChange(of: manager.textColor) { _, _ in scheduleLiveUpdate() }
        .onChange(of: manager.textBgColor) { _, _ in scheduleLiveUpdate() }
        .onChange(of: manager.scrollRepeatCount) { _, _ in scheduleLiveUpdate() }
        .onDisappear {
            liveUpdateTask?.cancel()
            liveUpdateTask = nil
        }
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
