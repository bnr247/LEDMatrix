//
//  MatrixManager+OTA.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import Foundation
import SwiftUI

extension MatrixManager {
    func uploadFirmware(fileURL: URL) async {
        guard let device = selectedDevice else {
            self.otaStatusMessage = "Устройство не выбрано"
            return
        }
        
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        self.isOtaUpdating = true
        self.otaProgress = 0.0
        self.otaStatusMessage = "Подготовка прошивки..."
        
        // 1. Проверяем чтение файла
        guard let firmwareData = try? Data(contentsOf: fileURL) else {
            self.otaStatusMessage = "Не удалось прочитать файл"
            self.isOtaUpdating = false
            return
        }
        
        // 2. Защитная проверка: первый байт бинарника ESP32 обязан быть 0xE9
        guard let firstByte = firmwareData.first, firstByte == 0xE9 else {
            self.otaStatusMessage = "Ошибка: файл не является валидной прошивкой ESP32"
            self.isOtaUpdating = false
            return
        }
        
        let urlString = "http://\(device.ipAddress)/update"
        guard let url = URL(string: urlString) else {
            self.otaStatusMessage = "Неверный URL обновления"
            self.isOtaUpdating = false
            return
        }
        
        // Дальше идет формирование multipart-запроса и отправка...
        let boundary = "Boundary-\(UUID().uuidString)"
        var bodyHeader = Data()
        bodyHeader.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyHeader.append("Content-Disposition: form-data; name=\"update\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        bodyHeader.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        var bodyFooter = Data()
        bodyFooter.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        var fullBodyData = Data()
        fullBodyData.append(bodyHeader)
        fullBodyData.append(firmwareData)
        fullBodyData.append(bodyFooter)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addBasicAuthHeader(to: &request)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(fullBodyData.count)", forHTTPHeaderField: "Content-Length")
        
        let uploadDelegate = OTAUploadDelegate { [weak self] progress in
            Task { @MainActor in
                if progress >= 0.98 {
                    self?.otaProgress = 0.98
                    self?.otaStatusMessage = "Запись во флэш-память устройства..."
                } else {
                    self?.otaProgress = progress
                    self?.otaStatusMessage = "Отправка пакетов данных..."
                }
            }
        }
        
        do {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.urlCache = nil
            
            let session = URLSession(configuration: config, delegate: uploadDelegate, delegateQueue: nil)
            let (data, response) = try await session.upload(for: request, from: fullBodyData)
            
            if let httpResp = response as? HTTPURLResponse {
                if httpResp.statusCode == 200 {
                    self.otaProgress = 1.0
                    self.otaStatusMessage = "Обновление завершено! Устройство перезагружается..."
                } else {
                    let serverResponse = String(data: data, encoding: .utf8) ?? ""
                    self.otaStatusMessage = "Ошибка (\(httpResp.statusCode)): \(serverResponse)"
                }
            }
        } catch {
            print("❌ Ошибка OTA обновления: \(error)")
            self.otaStatusMessage = "Ошибка сети: \(error.localizedDescription)"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.isOtaUpdating = false
            self?.otaProgress = 0.0
        }
    }
}
