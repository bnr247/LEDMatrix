//
//  MatrixManager+Logs.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import Foundation

extension MatrixManager {
    /// Запуск циклического опроса логов (раз в секунду)
    func startLogStreaming() {
        guard let device = selectedDevice else { return }
        print("📋 Запущен монитор логов для \(device.name)")
        
        // Сбрасываем старый лог и запускаем загрузку
        self.deviceLogs = "Подключение к монитору логов...\n"
        self.isLogLoading = true
        
        // Сразу делаем первый запрос
        Task { await self.fetchDeviceLogsData(for: device) }
        
        // Создаем таймер на каждую секунду
        logTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let activeDevice = self.selectedDevice else { return }
            Task {
                await self.fetchDeviceLogsData(for: activeDevice)
            }
        }
    }
    
    /// Остановка опроса логов (вызывается при закрытии экрана логов)
    func stopLogStreaming() {
        print("📋 Монитор логов остановлен")
        logTimer?.invalidate()
        logTimer = nil
        isLogLoading = false
    }
    
    /// Один HTTP-запрос к эндпоинту /logs/data
    private func fetchDeviceLogsData(for device: LEDMatrixDevice) async {
        guard let url = URL(string: "http://\(device.ipAddress)/logs/data") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Отключаем кэш, как в JS {cache:'no-store'}
        addBasicAuthHeader(to: &request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse {
                if httpResp.statusCode == 200 {
                    if let rawText = String(data: data, encoding: .utf8) {
                        self.deviceLogs = rawText.isEmpty ? "Вывод устройства пуст" : rawText
                    }
                } else if httpResp.statusCode == 401 {
                    self.deviceLogs = "Ошибка: Ошибка авторизации (401)"
                    self.stopLogStreaming()
                } else {
                    self.deviceLogs = "Ошибка сервера (\(httpResp.statusCode))"
                }
            }
            self.isLogLoading = false
        } catch {
            self.deviceLogs = "Не удалось получить вывод устройства: \(error.localizedDescription)"
            self.isLogLoading = false
        }
    }
}
