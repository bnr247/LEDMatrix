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
            "repeat_count": scrollRepeatCount
        ])
    }
    
    func updateClockFont(_ font: Int) async {
        settings.clockFont = font
        try? await self.sendCommand(endpoint: "cmd", params: ["clock_font": font])
    }
    
    func updateClockHoursColor(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.hoursColorHex = hex
        try? await self.sendCommand(endpoint: "cmd", params: ["hours_color_hex": hex])
    }
    
    func updateClockMinutesColor(_ color: Color) async {
        let hex = UIColor(color).toHex() ?? "0064FF"
        settings.minutesColorHex = hex
        try? await self.sendCommand(endpoint: "cmd", params: ["minutes_color_hex": hex])
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
    
    func toggleShowTextUsername(_ showUsername: Bool) async {
        settings.showNameText = showUsername
        try? await self.sendCommand(endpoint: "cmd", params: ["show_name_text": showUsername])
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
            
            // Как только ESP32 ответила 200 — МГНОВЕННО фиксируем успех и тушим загрузку
            self.isSaveSuccess = true
            self.isSavingSettings = false
            
            // ВАЖНО: Больше никаких скрытых фоновых fetch-запросов, которые вешают UI!
            // Плата сама применит настройки, а интерфейс уже разблокирован.
            
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
            if self.isDivoomEmailChanged {
                try await self.sendCommand(endpoint: "cmd", params: ["divoom_email": localDivoomEmail])
            }
            
            if self.isDivoomPasswordChanged {
                let md5Password = localDivoomPassword.md5Hex()
                try await self.sendCommand(endpoint: "cmd", params: ["divoom_password": md5Password])
            }
            
            // Как только Divoom-настройки улетели — МГНОВЕННО освобождаем интерфейс
            self.isSaveSuccess = true
            self.isSavingSettings = false
            
            // Никаких фоновых fetchSettings. Кнопка отвиснет моментально.
            
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
