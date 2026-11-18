//
//  ManualIPView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import SwiftUI

struct ManualIPView: View {
    @ObservedObject var manager: MatrixManager
    @State private var ipAddress: String = ""
    @State private var customName: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section(header: Text("Параметры матрицы").foregroundColor(manager.accentColor)) {
                TextField("Название матрицы (например, Гостиная)", text: $customName)
                    .foregroundColor(manager.appTextColor)
                TextField("192.168.1.50", text: $ipAddress)
                    .keyboardType(.numbersAndPunctuation)
                    .foregroundColor(manager.appTextColor)
            }
            .listRowBackground(manager.cardBackgroundColor)

            Button("Сохранить и подключиться") {
                let name = customName.isEmpty ? "LedMatrix-Manual" : customName
                let newDevice = LEDMatrixDevice(name: name, ipAddress: ipAddress)

                manager.saveDevice(newDevice)
                dismiss()
            }
            .disabled(ipAddress.isEmpty)
            .listRowBackground(manager.cardBackgroundColor)
        }
        .themedForm(manager)
        .navigationTitle("Ручное подключение")
    }
}
