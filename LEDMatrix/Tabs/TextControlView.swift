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
    
    var body: some View {
        Form {
            Section(header: Text("Бегущая строка")) {
                TextField("Введите сообщение...", text: $manager.textToSend)
                ColorPicker("Цвет текста", selection: $manager.textColor, supportsOpacity: false)
                ColorPicker("Цвет фона", selection: $manager.textBgColor, supportsOpacity: false)
                
                VStack(alignment: .leading) {
                    Text("Скорость: \(Int(manager.scrollSpeedFps))")
                    Slider(value: $manager.scrollSpeedFps, in: 10...100, step: 5)
                }
                Stepper("Повторов: \(manager.scrollRepeatCount)", value: $manager.scrollRepeatCount, in: 1...10)
            }
            
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
            .listRowBackground(Color.clear)
        }
        .onTapGesture { hideKeyboard() }
        .onSubmit {
            Task { await manager.sendCurrentText() }
            hideKeyboard()
        }
    }
}
