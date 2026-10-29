//
//  MatrixManager+ScreenLive.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import Foundation
import SwiftUI

extension MatrixManager {
    func fetchScreen() async {
        guard let device = selectedDevice, let url = URL(string: "http://\(device.ipAddress)/screen") else { return }
        
        self.isScreenLoading = true
        self.screenErrorMessage = nil
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        request.setValue("close", forHTTPHeaderField: "Connection")
        addBasicAuthHeader(to: &request)
        
        do {
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                self.screenErrorMessage = "Ошибка сервера: \(code)"
                self.isScreenLoading = false
                return
            }
            
            guard data.count >= 520 else {
                self.screenErrorMessage = "Неверный размер данных: \(data.count) байт"
                self.isScreenLoading = false
                return
            }
            
            // 1. Проверка заголовка (8 байт)
            guard data[0] == Character("D").asciiValue, data[1] == Character("V").asciiValue else {
                self.screenErrorMessage = "Неверный заголовок данных (Magic)"
                self.isScreenLoading = false
                return
            }
            
            let version = data[2]
            let width = data[3]
            let height = data[4]
            let format = data[5]
            
            guard version == 1, width == 16, height == 16, format == 1 else {
                self.screenErrorMessage = "Неподдерживаемый формат кадра: \(width)x\(height), fmt \(format)"
                self.isScreenLoading = false
                return
            }
            
            // 2. Декодирование с использованием точного зеркала функции XY(x, y) из прошивки ESP32
            var newPixels: [Color] = Array(repeating: .black, count: 256)
            let pixelData = data.subdata(in: 8..<520)
            
            for row in 0..<16 {
                for col in 0..<16 {
                    let targetIndex = row * 16 + col
                    
                    // Логические координаты экрана: x = col (колонка), y = row (строка)
                    let x = col
                    let y = row
                    
                    // Точное зеркало функции XY(x, y) из main.cpp для матрицы 16x16
                    let sourceIndex: Int
                    if x % 2 != 0 {
                        sourceIndex = x * 16 + (15 - y)
                    } else {
                        sourceIndex = x * 16 + y
                    }
                    
                    let byteOffset = sourceIndex * 2
                    guard byteOffset + 1 < pixelData.count else { continue }
                    
                    // Чтение Big-Endian (MSB первым)
                    let highByte = UInt16(pixelData[byteOffset])
                    let lowByte = UInt16(pixelData[byteOffset + 1])
                    
                    let rgb565 = (highByte << 8) | lowByte
                    
                    let r5 = (rgb565 >> 11) & 0x1F
                    let g6 = (rgb565 >> 5) & 0x3F
                    let b5 = rgb565 & 0x1F
                    
                    let r8 = Double((r5 * 527 + 23) >> 6) / 255.0
                    let g8 = Double((g6 * 259 + 33) >> 6) / 255.0
                    let b8 = Double((b5 * 527 + 23) >> 6) / 255.0
                    
                    newPixels[targetIndex] = Color(red: r8, green: g8, blue: b8)
                }
            }
            
            self.screenPixels = newPixels
            self.isScreenLoading = false
        } catch {
            print("❌ Ошибка при получении /screen: \(error)")
            self.screenErrorMessage = "Ошибка сети: \(error.localizedDescription)"
            self.isScreenLoading = false
        }
    }
    
    func startScreenLiveStream() {
        guard let device = selectedDevice,
              let url = URL(string: "ws://\(device.ipAddress):81/")
        else {
            self.isScreenLiveActive = false
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Сначала гасим старый сокет без изменения Published-флага
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
            
            self.isScreenLiveActive = true
            self.screenErrorMessage = nil
            
            let session = URLSession(configuration: .default)
            let task = session.webSocketTask(with: url)
            self.webSocketTask = task
            task.resume()
            
            // Запускаем непрерывное чтение потока
            self.listenWebSocket()
        }
    }
    
    func stopScreenLiveStream() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Меняем флаг строго один раз
            if self.isScreenLiveActive {
                self.isScreenLiveActive = false
            }
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
        }
    }
    
    private func listenWebSocket() {
        guard let task = webSocketTask else { return }
        
        task.receive { [weak self] result in
            guard let self = self, self.isScreenLiveActive else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.parseAndApplyScreenData(data)
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.parseAndApplyScreenData(data)
                    }
                @unknown default:
                    break
                }
                // Рекурсивно слушаем следующий пакет, пока активен флаг
                if self.isScreenLiveActive {
                    self.listenWebSocket()
                }
                
            case .failure(let error):
                print("❌ WebSocket error: \(error)")
                Task { @MainActor in
                    // Аккуратно выключаем лайв только при реальном разрыве сети
                    if self.isScreenLiveActive {
                        self.isScreenLiveActive = false
                        self.webSocketTask?.cancel(with: .goingAway, reason: nil)
                        self.webSocketTask = nil
                        self.screenErrorMessage = "Соединение разорвано"
                    }
                }
            }
        }
    }
    
    /// Вынесенный парсер 520 байт бинарного кадра (идентичен тому, что был в fetchScreen)
    private func parseAndApplyScreenData(_ data: Data) {
        guard data.count >= 520,
              data[0] == Character("D").asciiValue, data[1] == Character("V").asciiValue,
              data[2] == 1, data[3] == 16, data[4] == 16, data[5] == 1
        else {
            return
        }
        
        var newPixels: [Color] = Array(repeating: .black, count: 256)
        let pixelData = data.subdata(in: 8..<520)
        
        for row in 0..<16 {
            for col in 0..<16 {
                let targetIndex = row * 16 + col
                let x = col
                let y = row
                
                let sourceIndex: Int
                if x % 2 != 0 {
                    sourceIndex = x * 16 + (15 - y)
                } else {
                    sourceIndex = x * 16 + y
                }
                
                let byteOffset = sourceIndex * 2
                guard byteOffset + 1 < pixelData.count else { continue }
                
                let highByte = UInt16(pixelData[byteOffset])
                let lowByte = UInt16(pixelData[byteOffset + 1])
                let rgb565 = (highByte << 8) | lowByte
                
                let r5 = (rgb565 >> 11) & 0x1F
                let g6 = (rgb565 >> 5) & 0x3F
                let b5 = rgb565 & 0x1F
                
                let r8 = Double((r5 * 527 + 23) >> 6) / 255.0
                let g8 = Double((g6 * 259 + 33) >> 6) / 255.0
                let b8 = Double((b5 * 527 + 23) >> 6) / 255.0
                
                newPixels[targetIndex] = Color(red: r8, green: g8, blue: b8)
            }
        }
        
        Task { @MainActor in
            self.screenPixels = newPixels
        }
    }
}
