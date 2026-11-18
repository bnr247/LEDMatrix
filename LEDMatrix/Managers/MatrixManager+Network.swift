//
//  MatrixManager+Network.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import Foundation
import SwiftUI

extension MatrixManager {
    // MARK: - Запросы и инициализация данных

    func fetchSettings(for device: LEDMatrixDevice) async {
        self.selectedDevice = device
        self.connectionStatus = "Подключение к \(device.name)..."
        guard let url = URL(string: "http://\(device.ipAddress)/settings") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 3.0
        addBasicAuthHeader(to: &request)
        
        do {
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                let decoded = try JSONDecoder().decode(MatrixSettings.self, from: data)
                self.settings = decoded
                // ИСПРАВЛЕНО: Полностью убран деструктивный код затирания локальных буферов Divoom
                self.connectionStatus = "Подключено к \(device.name)"

                // Циферблаты и шрифты загружаются вместе с настройками: без них
                // редактор часов не сможет построить превью.
                async let faces = fetchClockFaces()
                async let fonts = fetchClockFonts()
                let (loadedFaces, loadedFonts) = await (faces, fonts)
                self.clockFaces = loadedFaces
                self.clockFonts = loadedFonts
            }
        } catch {
            print("❌ Ошибка при запросе /settings: \(error)")
            connectionStatus = "Ошибка соединения"
        }
    }
    
    func fetchWifiSettings(for device: LEDMatrixDevice) async {
        self.selectedDevice = device
        guard let url = URL(string: "http://\(device.ipAddress)/wifi") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addBasicAuthHeader(to: &request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                let decoded = try JSONDecoder().decode(MatrixWifiSettings.self, from: data)
                self.wifiSettings = decoded
                self.localWifiSsid = decoded.ssid
                self.localWifiPassword = decoded.passwordSet ? passwordPlaceholder : ""
            }
        } catch {
            print("❌ Ошибка при запросе /wifi: (error)")
        }
    }
    
    func fetchClockFonts() async -> [ClockFont] {
        guard let device = selectedDevice,
              let url = URL(string: "http://\(device.ipAddress)/clockfonts") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 3.0
        addBasicAuthHeader(to: &request)
            
        do {
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                let decoded = try JSONDecoder().decode([ClockFont].self, from: data)
                self.clockFonts = decoded
                return decoded
            }
        } catch {
            print("❌ Ошибка при запросе /clockfonts: \(error)")
        }
        return []
    }

    func fetchClockFaces() async -> [ClockFace] {
        guard let device = selectedDevice,
              let url = URL(string: "http://\(device.ipAddress)/clockfaces") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 3.0
        addBasicAuthHeader(to: &request)

        do {
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                let decoded = try JSONDecoder().decode([ClockFace].self, from: data)
                self.clockFaces = decoded
                return decoded
            }
        } catch {
            print("❌ Ошибка при запросе /clockfaces: \(error)")
        }
        return []
    }
    
    /// Добавляем ключевое слово throws, чтобы метод умел пробрасывать ошибки наверх
    func sendCommand(endpoint: String, params: [String: Any]) async throws {
        guard let device = selectedDevice else { return }
        let urlString = "http://\(device.ipAddress)/\(endpoint)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Жестко требуем отсекать сессию, чтобы iOS не ждала keep-alive
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 2.0 // Быстрый таймаут, чтобы кнопка не висела
        
        addBasicAuthHeader(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
        
        // Создаем легковесную сессию без кэша и зависших сокетов
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResp = response as? HTTPURLResponse {
            print("📡 Ответ от \(endpoint): \(httpResp.statusCode)")
            if httpResp.statusCode != 200 {
                let serverMsg = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "LEDMatrix", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMsg])
            }
        }
    }
    
    // MARK: - API методы изменений

    func updateSingleBrightness(_ brightness: Int) async {
        // 1. Мгновенно обновляем локальный стейт для абсолютной плавности UI
        settings.brightnessPercent = brightness
        
        // 2. Если запрос уже летит по сети, просто запоминаем последнее желаемое значение
        guard !isBrightnessSending else {
            pendingBrightness = brightness
            return
        }
        
        isBrightnessSending = true
        
        do {
            // Отправляем текущее значение сразу
            try await self.sendCommand(endpoint: "cmd", params: ["brightness": brightness])
        } catch {
            print("❌ Ошибка отправки яркости: \(error)")
        }
        
        isBrightnessSending = false
        
        // 3. Если пока шел запрос, ползунок сдвинули дальше — отправляем финальное актуальное положение
        if let nextBrightness = pendingBrightness, nextBrightness != brightness {
            pendingBrightness = nil
            await self.updateSingleBrightness(nextBrightness)
        }
    }
    
    func updateBrightnessDay(_ brightDay: Int) async {
        settings.dayBrightnessPercent = brightDay
        try? await self.sendCommand(endpoint: "cmd", params: ["brightness_day": brightDay])
    }
    
    func updateBrightnessNight(_ brightNight: Int) async {
        settings.nightBrightnessPercent = brightNight
        try? await self.sendCommand(endpoint: "cmd", params: ["brightness_night": brightNight])
    }
    
    func sendCurrentText() async {
        guard !textToSend.isEmpty else { return }
        
        let bgComp = UIColor(textBgColor).rgbComponents()
        let textComp = UIColor(textColor).rgbComponents()
        
        // ИСПРАВЛЕНО: Строго проверяйте наличие всех \ перед скобками
        let formattedText = "[\(bgComp.0),\(bgComp.1),\(bgComp.2)][\(textComp.0),\(textComp.1),\(textComp.2)]\(textToSend)"
        
        try? await self.sendCommand(endpoint: "cmd", params: [
            "text": formattedText,
            "text_speed_fps": Int(scrollSpeedFps),
            "repeat_count": scrollRepeatCount,
            // true — непрозрачная полоса по центру, false — классический
            // полноэкранный текст. Тумблер «на весь экран» инвертирует флаг.
            "scroll_text_transparent": !textFullScreen
        ])
    }
    
    func updateClockFont(_ font: Int) async {
        settings.currentClockFontId = font
        try? await self.sendCommand(endpoint: "cmd", params: ["clock_font": font])
    }

    /// Выбирает циферблат и, если превью активно, просит устройство проиграть
    /// слайд в ту же сторону, что и свайп в приложении.
    func selectClockFace(_ faceId: Int, direction: Int) async {
        settings.currentClockFontId = faceId
        var params: [String: Any] = ["clock_font": faceId]
        if direction != 0 {
            params["clock_slide"] = direction
        }
        try? await self.sendCommand(endpoint: "cmd", params: params)
    }

    /// Включает или выключает живой предпросмотр на устройстве. При включении
    /// сразу отправляется текущий циферблат, чтобы на матрице было ровно то,
    /// что видно в приложении.
    func setClockPreview(_ active: Bool) async {
        settings.clockPreviewActive = active
        var params: [String: Any] = ["clock_preview": active]
        if active {
            params["clock_font"] = settings.currentClockFontId
        }
        try? await self.sendCommand(endpoint: "cmd", params: params)
    }
    
    func updateClockHoursColor1(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.hoursColor1Hex = hex
        try? await self.sendCommand(endpoint: "cmd", params: ["hours_color_1_hex": hex])
    }
    
    func updateClockHoursColor2(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.hoursColor2Hex = hex
        try? await self.sendCommand(endpoint: "cmd", params: ["hours_color_2_hex": hex])
    }
    
    func updateClockMinutesColor1(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.minutesColor1Hex = hex
        try? await self.sendCommand(endpoint: "cmd", params: ["minutes_color_1_hex": hex])
    }
    
    func updateClockMinutesColor2(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.minutesColor2Hex = hex
        try? await self.sendCommand(endpoint: "cmd", params: ["minutes_color_2_hex": hex])
    }
    
    func updateClockColonColor(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.colonColorHex = hex
        try? await self.sendCommand(endpoint: "cmd", params: ["colon_color_hex": hex])
    }
    
    func updateClockBgColor(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "000000"
        settings.bgColorHex = hex
        try? await self.sendCommand(endpoint: "cmd", params: ["bg_color_hex": hex])
    }

    /// Сохраняет цвет выбранного в превью элемента. Каждый слот циферблата
    /// отображается на свою глобальную настройку цвета устройства.
    func updateClockColor(for selection: ClockPreviewSelection, color: Color) async {
        switch selection {
        case .digit(let type):
            switch type {
            case "h1": await updateClockHoursColor1(color)
            case "h2": await updateClockHoursColor2(color)
            case "m1": await updateClockMinutesColor1(color)
            case "m2": await updateClockMinutesColor2(color)
            default: break
            }
        case .separator:
            await updateClockColonColor(color)
        case .background:
            await updateClockBgColor(color)
        }
    }
    
    func toggleClockShowColon(_ showColon: Bool) async {
        settings.showColon = showColon
        try? await self.sendCommand(endpoint: "cmd", params: ["show_colon": showColon])
    }
    
    func updateClockAnimationType(_ animType: ClockAnimationType) async {
        settings.clockAnimationType = animType
        try? await self.sendCommand(endpoint: "cmd", params: animType.parameters)
    }
    
    func updateClockColorEffect(_ colorEffect: ClockColorEffect) async {
        settings.clockColorEffect = colorEffect
        try? await self.sendCommand(endpoint: "cmd", params: colorEffect.parameters)
    }
    
    func updateClockEffectSpeed(_ speed: Int) async {
        settings.clockEffectSpeed = speed
        try? await self.sendCommand(endpoint: "cmd", params: ["clock_effect_speed": speed])
    }
    
    func updateClockAnimationMs(_ animMs: Int) async {
        settings.clockAnimationMs = animMs
        try? await self.sendCommand(endpoint: "cmd", params: ["clock_animation_ms": animMs])
    }
    
//    func toggleClockRandomColor(_ isRandomColor: Bool) async {
//        settings.clockRandomColor = isRandomColor
//        try? await self.sendCommand(endpoint: "cmd", params: ["clock_random_color": isRandomColor])
//    }
//    
//    func toggleClockSwapColors(_ swapColors: Bool) async {
//        settings.clockSwapColors = swapColors
//        try? await self.sendCommand(endpoint: "cmd", params: ["clock_swap_colors": swapColors])
//    }
    
    func toggleShowTextUsername(_ showUsername: Bool) async {
        settings.showNameText = showUsername
        try? await self.sendCommand(endpoint: "cmd", params: ["show_name_text": showUsername])
    }
    
    func updateClockDisplaySeconds(_ seconds: Int) async {
        settings.clockDisplaySeconds = seconds
        try? await self.sendCommand(endpoint: "cmd", params: ["clock_display_seconds": seconds])
    }

    func updateAnimationDisplaySeconds(_ seconds: Int) async {
        settings.animationDisplaySeconds = seconds
        try? await self.sendCommand(endpoint: "cmd", params: ["animation_display_seconds": seconds])
    }
    
    func updateAnimationType(_ animationType: AnimationType) async throws {
        settings.animationType = animationType
        try await self.sendCommand(endpoint: "cmd", params: animationType.parameters)
    }
    
    // MARK: - Пикеры Времени (Конвертация String <-> Date)

    var dayStartTimeBinding: Binding<Date> {
        Binding(
            get: { self.parseTime(self.settings.dayStart) },
            set: { newDate in
                let timeString = self.formatTime(newDate)
                self.settings.dayStart = timeString
                Task {
                    try? await self.sendCommand(endpoint: "cmd", params: ["day_start": timeString])
                }
            }
        )
    }
    
    var nightStartTimeBinding: Binding<Date> {
        Binding(
            get: { self.parseTime(self.settings.nightStart) },
            set: { newDate in
                let timeString = self.formatTime(newDate)
                self.settings.nightStart = timeString
                Task {
                    try? await self.sendCommand(endpoint: "cmd", params: ["night_start": timeString])
                }
            }
        )
    }
    
    var dayDeviceModeBinding: Binding<String> {
        Binding(
            get: { self.settings.dayDeviceMode },
            set: { newValue in
                self.settings.dayDeviceMode = newValue
                Task {
                    try? await self.sendCommand(endpoint: "cmd", params: ["day_device_mode": newValue])
                }
            }
        )
    }
    
    var nightDeviceModeBinding: Binding<String> {
        Binding(
            get: { self.settings.nightDeviceMode },
            set: { newValue in
                self.settings.nightDeviceMode = newValue
                Task {
                    try? await self.sendCommand(endpoint: "cmd", params: ["night_device_mode": newValue])
                }
            }
        )
    }
    
    var clockDisplaySecondsBinding: Binding<Int> {
        Binding(
            get: { self.settings.clockDisplaySeconds },
            set: { newValue in
                self.settings.clockDisplaySeconds = newValue
                Task {
                    try? await self.sendCommand(endpoint: "cmd", params: ["clock_display_seconds": newValue])
                }
            }
        )
    }

    var animationDisplaySecondsBinding: Binding<Int> {
        Binding(
            get: { self.settings.animationDisplaySeconds },
            set: { newValue in
                self.settings.animationDisplaySeconds = newValue
                Task {
                    try? await self.sendCommand(endpoint: "cmd", params: ["animation_display_seconds": newValue])
                }
            }
        )
    }
    
    var animationTypeBinding: Binding<AnimationType> {
        Binding(
            get: { self.settings.animationType ?? .standard(sortOrder: 0) },
            set: { newType in
                Task {
                    try? await self.updateAnimationType(newType)
                }
            }
        )
    }
    
    var clockAnimationTypeBinding: Binding<ClockAnimationType> {
        Binding(
            get: { self.settings.clockAnimationType ?? .fading },
            set: { newType in
                Task {
                    try? await self.updateClockAnimationType(newType)
                }
            }
        )
    }
    
    var clockColorEffectBinding: Binding<ClockColorEffect> {
        Binding(
            get: { self.settings.clockColorEffect ?? .off },
            set: { newType in
                Task {
                    try? await self.updateClockColorEffect(newType)
                }
            }
        )
    }
    
    /// Вспомогательные методы для работы с форматом ЧЧ:ММ
    private func parseTime(_ timeStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        // Если строка пустая или некорректная, отдаем дефолтное время
        return formatter.date(from: timeStr) ?? Date()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - Сохранение форм настроек (Вызывается по кнопке сохранить)

    func saveWifiSettings() async {
        self.isSavingSettings = true
        self.saveErrorMessage = nil
        self.isSaveSuccess = false
        
        do {
            if self.isWifiSsidChanged {
                try await self.sendCommand(endpoint: "wifi", params: ["ssid": localWifiSsid])
            }
            
            if self.isWifiPasswordChanged {
                try await self.sendCommand(endpoint: "wifi", params: ["password": localWifiPassword])
            }
            
            self.isSaveSuccess = true
            self.isSavingSettings = false
            
        } catch {
            print("❌ Ошибка сохранения WiFi: \(error)")
            self.isSaveSuccess = false
            self.saveErrorMessage = error.localizedDescription
            self.isSavingSettings = false
        }
    }
    
    func saveDivoomSettings() async {
        self.isSavingSettings = true
        self.saveErrorMessage = nil
        self.isSaveSuccess = false
        
        do {
            if self.isDivoomEmailChanged || self.isDivoomPasswordChanged {
                let md5Password = localDivoomPassword.md5Hex()
                try await self.sendCommand(endpoint: "cmd", params:
                                            ["divoom_email": localDivoomEmail,
                                             "divoom_password": md5Password
                                            ])
            }
            
            self.isSaveSuccess = true
            self.isSavingSettings = false
        } catch {
            print("❌ Ошибка сохранения Divoom: \(error)")
            self.isSaveSuccess = false
            self.saveErrorMessage = error.localizedDescription
            self.isSavingSettings = false
        }
    }
    
    // MARK: - Системные действия

    func deviceRestart() async {
        try? await self.sendCommand(endpoint: "cmd", params: ["action": "restart"])
    }

    func deviceResetWifi() async {
        try? await self.sendCommand(endpoint: "cmd", params: ["action": "reset_wifi"])
    }

    func deviceResetSettings() async {
        try? await self.sendCommand(endpoint: "cmd", params: ["action": "reset_settings"])
    }

    func deviceFactoryReset() async {
        try? await self.sendCommand(endpoint: "cmd", params: ["action": "factory_reset"])
    }
    
    // MARK: - Валидация изменений для кнопок сохранения

    var isWifiSsidChanged: Bool {
        localWifiSsid != wifiSettings.ssid && !localWifiSsid.isEmpty
    }

    var isWifiPasswordChanged: Bool {
        wifiSettings.passwordSet ? (localWifiPassword != passwordPlaceholder && !localWifiPassword.isEmpty) : !localWifiPassword.isEmpty
    }

    var isDivoomEmailChanged: Bool {
        localDivoomEmail != settings.divoomEmail && !localDivoomEmail.isEmpty
    }

    var isDivoomPasswordChanged: Bool {
        settings.divoomPasswordSet ? (localDivoomPassword != passwordPlaceholder && !localDivoomPassword.isEmpty) : !localDivoomPassword.isEmpty
    }
}
