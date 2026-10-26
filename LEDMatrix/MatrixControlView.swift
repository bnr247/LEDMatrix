//
//  MatrixControlView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 23.10.2026.
//

import SwiftUI
import CryptoKit

struct MatrixControlView: View {
    @ObservedObject var manager: MatrixManager
    let device: LEDMatrixDevice
    
    var body: some View {
        // TabView возвращается к чистому системному виду без нижних наложений
        TabView {
            TextControlTab(manager: manager)
                .tabItem { Label("Текст", systemImage: "text.bubble") }
            
            ClockSettingsTab(manager: manager)
                .tabItem { Label("Часы", systemImage: "clock") }
            
            SettingsTab(manager: manager)
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await manager.fetchSettings(for: device)
            }
            Task {
                await manager.fetchWifiSettings(for: device)
            }
        }
    }
}

// MARK: - ВКЛАДКА: ТЕКСТ
struct TextControlTab: View {
    @ObservedObject var manager: MatrixManager

    var body: some View {
        Form {
            // ИСПРАВЛЕНО: Секция общей яркости перенесена в самый верх первой вкладки
            Section(header: Text("Яркость устройства")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.secondary)
                        Text("Текущая яркость: \(manager.settings.brightnessPercent)%")
                            .font(.body)
                        Spacer()
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.brightnessPercent) },
                            set: { newValue in Task { await manager.updateSingleBrightness(Int(newValue)) } }
                        ),
                        in: 0...100, step: 5
                    )
                    .tint(.yellow)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Бегущая строка")) {
                TextField("Введите сообщение...", text: $manager.textToSend)
                ColorPicker("Цвет текста", selection: $manager.textColor)
                ColorPicker("Цвет фона", selection: $manager.textBgColor)
            }
            
            Section(header: Text("Параметры анимации")) {
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

// MARK: - ВКЛАДКА: ЧАСЫ
struct ClockSettingsTab: View {
    @ObservedObject var manager: MatrixManager

    var body: some View {
        Form {
            Section(header: Text("Внешний вид часов")) {
                Picker("Шрифт", selection: Binding(
                    get: { manager.settings.clockFont },
                    set: { newValue in Task { await manager.updateClockFont(newValue) } }
                )) {
                    Text("Default Horizontal (3x5)").tag(0)
                    Text("Simple Horizontal (3x7)").tag(1)
                    Text("Narrow Horizontal (3x11)").tag(2)
                    Text("Simple Vertical (5x7)").tag(3)
                    Text("OCR-A Vertical (5x7)").tag(4)
                    Text("Atari Vertical (5x7)").tag(5)
                }
            }
            Section(header: Text("Цветовая гамма часов")) {
                ColorPicker("Цвет цифр", selection: Binding(
                    get: { Color(hex: manager.settings.digitsColorHex) },
                    set: { newValue in Task { await manager.updateClockDigitsColor(newValue) } }
                ))
                ColorPicker("Цвет разделителя", selection: Binding(
                    get: { Color(hex: manager.settings.colonColorHex) },
                    set: { newValue in Task { await manager.updateClockColonColor(newValue) } }
                ))
                ColorPicker("Цвет фона", selection: Binding(
                    get: { Color(hex: manager.settings.bgColorHex) },
                    set: { newValue in Task { await manager.updateClockBgColor(newValue) } }
                ))
            }
        }
    }
}

// MARK: - ВКЛАДКА НАСТРОЕК
struct SettingsTab: View {
    @ObservedObject var manager: MatrixManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Панель управления")) {
                    NavigationLink(destination: SettingsGeneralFormView(manager: manager)) {
                        Label("Общие", systemImage: "sparkles.tv")
                    }
                    NavigationLink(destination: SettingsWifiFormView(manager: manager)) {
                        Label("Настройки Wifi", systemImage: "wifi")
                    }
                    NavigationLink(destination: SettingsDivoomFormView(manager: manager)) {
                        Label("Настройки Divoom", systemImage: "globe")
                    }
                    NavigationLink(destination: SettingsInfoFormView(manager: manager)) {
                        Label("Об устройстве", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Панель управления")
        }
    }
}

// MARK: - ФОРМА: ОБЩИЕ НАСТРОЙКИ
struct SettingsGeneralFormView: View {
    @ObservedObject var manager: MatrixManager
    
    var body: some View {
        Form {
            Section(header: Text("День")) {
                DatePicker(
                    "Начало дня",
                    selection: manager.dayStartTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                
                Picker("Режим экрана", selection: manager.dayDeviceModeBinding) {
                    Text("Смешанный").tag("mixed")
                    Text("Только часы").tag("clock_only")
                    Text("Только анимация").tag("animation_only")
                }
                
                // Перенесенный слайдер яркости для дневного режима
                VStack(alignment: .leading) {
                    Text("Яркость: \(manager.settings.dayBrightnessPercent)")
                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.dayBrightnessPercent) },
                            set: { newValue in Task { await manager.updateBrightnessDay(Int(newValue)) } }
                        ),
                        in: 0...100, step: 5
                    )
                }
                .padding(.top, 4)
            }
                
            Section(header: Text("Ночь")) {
                DatePicker(
                    "Начало ночи",
                    selection: manager.nightStartTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                
                Picker("Режим экрана", selection: manager.nightDeviceModeBinding) {
                    Text("Смешанный").tag("mixed")
                    Text("Только часы").tag("clock_only")
                    Text("Только анимация").tag("animation_only")
                }
                
                // Перенесенный слайдер яркости для ночного режима
                VStack(alignment: .leading) {
                    Text("Яркость: \(manager.settings.nightBrightnessPercent)")
                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.nightBrightnessPercent) },
                            set: { newValue in Task { await manager.updateBrightnessNight(Int(newValue)) } }
                        ),
                        in: 0...100, step: 5
                    )
                }
                .padding(.top, 4)
            }
            
            Section(header: Text("Бегущая строка")) {
                Toggle("Отображать имя из Telegram", isOn: Binding(
                    get: { manager.settings.showNameText },
                    set: { newValue in Task { await manager.toggleShowTextUsername(newValue) } }
                ))
            }
        }
        .navigationTitle("Общие настройки")
    }
}

// MARK: - ФОРМА: ОБ УСТРОЙСТВЕ
struct SettingsInfoFormView: View {
    @ObservedObject var manager: MatrixManager
    @State private var activeAction: DeviceAction?
    
    var body: some View {
        Form {
            Section {
                row(title: "Имя хоста", value: manager.settings.hostName)
                row(title: "IP адрес", value: manager.settings.ipAddress)
                row(title: "MAC адрес", value: manager.settings.macAddress)
                row(title: "Версия HW", value: manager.settings.hwVersion)
                row(title: "Версия FW", value: manager.settings.fwVersion)
                row(title: "Запусков", value: "\(manager.settings.bootCount)")
            }
            Section {
                VStack(spacing: 16) {
                    actionButton(title: "Перезагрузить", color: .blue) { activeAction = .restart }
                    actionButton(title: "Сброс WiFi", color: .orange) { activeAction = .resetWifi }
                    
                    actionButton(title: "Сброс настроек", color: .orange) { activeAction = .resetSettings }
                    actionButton(title: "Factory reset", color: .red) { activeAction = .factoryReset }
                }
                .listRowBackground(Color.clear)
            }
        }
        .alert(item: $activeAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .destructive(Text("Подтвердить")) {
                    Task {
                        switch action {
                        case .restart: await manager.deviceRestart()
                        case .resetWifi: await manager.deviceResetWifi()
                        case .resetSettings: await manager.deviceResetSettings()
                        case .factoryReset: await manager.deviceFactoryReset()
                        }
                    }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
        .navigationTitle("Информация об устройстве")
    }
    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}

// MARK: - ФОРМА НАСТРОЙКИ WI-FI
struct SettingsWifiFormView: View {
    @ObservedObject var manager: MatrixManager
    @FocusState private var isPasswordFocused: Bool
    var body: some View {
        Form {
            Section(header: Text("Данные для подключения")) {
                HStack {
                    Text("SSID")
                    Spacer()
                    TextField("", text: $manager.localWifiSsid)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled(true)
                }
                HStack {
                    Text("Пароль")
                    Spacer()
                    SecureField("", text: $manager.localWifiPassword)
                        .multilineTextAlignment(.trailing)
                        .focused($isPasswordFocused)
                }
            }
            Section {
                Button(action: {
                    isPasswordFocused = false
                    Task { await manager.saveWifiSettings() }
                }) {
                    Text("Сохранить")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!manager.isWifiSsidChanged && !manager.isWifiPasswordChanged)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Настройки WiFi")
        .onChange(of: isPasswordFocused) { _, focused in
            if focused {
                if manager.wifiSettings.passwordSet && manager.localWifiPassword == manager.passwordPlaceholder {
                    manager.localWifiPassword = ""
                }
            } else {
                if manager.wifiSettings.passwordSet && manager.localWifiPassword.isEmpty {
                    manager.localWifiPassword = manager.passwordPlaceholder
                }
            }
        }
    }
}

// MARK: - ФОРМА НАСТРОЙКИ DIVOOM
struct SettingsDivoomFormView: View {
    @ObservedObject var manager: MatrixManager
    @FocusState private var isPasswordFocused: Bool
    var body: some View {
        Form {
            Section(header: Text("Учетные данные Divoom")) {
                HStack {
                    Text("Email")
                    Spacer()
                    TextField("", text: $manager.localDivoomEmail)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled(true)
                }
                HStack {
                    Text("Пароль")
                    Spacer()
                    SecureField("", text: $manager.localDivoomPassword)
                        .multilineTextAlignment(.trailing)
                        .focused($isPasswordFocused)
                }
            }
            Section {
                Button(action: {
                    isPasswordFocused = false
                    Task { await manager.saveDivoomSettings() }
                }) {
                    Text("Сохранить")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!manager.isDivoomEmailChanged && !manager.isDivoomPasswordChanged)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Настройки Divoom")
        .onChange(of: isPasswordFocused) { _, focused in
            if focused {
                if manager.settings.divoomPasswordSet && manager.localDivoomPassword == manager.passwordPlaceholder {
                    manager.localDivoomPassword = ""
                }
            } else {
                if manager.settings.divoomPasswordSet && manager.localDivoomPassword.isEmpty {
                    manager.localDivoomPassword = manager.passwordPlaceholder
                }
            }
        }
    }
}

enum DeviceAction: Identifiable {
    case restart
    case resetWifi
    case resetSettings
    case factoryReset
    var id: Self { self }
    var title: String {
        switch self {
        case .restart: return "Перезагрузка"
        case .resetWifi: return "Сброс настроек WiFi"
        case .resetSettings: return "Сброс всех настроек"
        case .factoryReset: return "Factory reset"
        }
    }
    var message: String {
        switch self {
        case .restart: return "Вы уверены, что хотите перезагрузить устройство?"
        case .resetWifi: return "Вы уверены, что хотите сбросить настройки WiFi?"
        case .resetSettings: return "Это действие удалит настройки устройства без возможности восстановления. Настройки WiFi затронуты не будут"
        case .factoryReset: return "Это действие удалит все настройки и сбросит устройство до исходного состояния"
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Color {
    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch sanitizedHex.count {
        case 6: // Формат RGB (например, "540F28")
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
            self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        default:
            self.init(.black)
        }
    }
}

@ViewBuilder
func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
    .buttonStyle(.borderedProminent)
    .tint(color)
}
