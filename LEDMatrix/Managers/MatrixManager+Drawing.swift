//
//  MatrixManager+Drawing.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import Foundation
import SwiftUI

extension MatrixManager {
    /// Включение режима рисования (POST /draw)
    func startDrawing() async {
        isDrawingLoading = true
        drawErrorMessage = nil
        do {
            try await sendCommand(endpoint: "draw", params: ["enabled": true])
            isDrawingActive = true
            // Сбрасываем холст в черный цвет при старте
            drawPixels = Array(repeating: .black, count: 256)
        } catch {
            print("❌ Ошибка включения рисования: \(error)")
            drawErrorMessage = "Не удалось войти в режим рисования"
        }
        isDrawingLoading = false
    }
    
    /// Безусловный выход из режима рисования (отправка DELETE /draw)
    func stopDrawing() async {
        isDrawingActive = false // Сбрасываем флаг на всякий случай
        
        guard let device = selectedDevice else { return }
        let urlString = "http://\(device.ipAddress)/draw"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 3.0
        addBasicAuthHeader(to: &request)
        
        do {
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config)
            _ = try await session.data(for: request)
            print("🛑 Режим рисования принудительно выключен")
        } catch {
            print("❌ Ошибка при выходе из рисования: \(error)")
        }
    }
    
    /// Безопасная отправка кадра через последовательную очередь
    func sendDrawFrame() {
        guard selectedDevice != nil, isDrawingActive else { return }
        
        // Формируем 512 байт буфера
        var frameData = Data()
        frameData.reserveCapacity(512)
        
        for row in 0..<16 {
            for col in 0..<16 {
                let targetIndex = row * 16 + col
                let color = drawPixels[targetIndex]
                
                let uiColor = UIColor(color)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                let r8 = UInt8(r * 255)
                let g8 = UInt8(g * 255)
                let b8 = UInt8(b * 255)
                
                let rgb565 = (UInt16(r8 >> 3) << 11) | (UInt16(g8 >> 2) << 5) | UInt16(b8 >> 3)
                
                frameData.append(UInt8(rgb565 >> 8))
                frameData.append(UInt8(rgb565 & 0xFF))
            }
        }
        
        // Ставим отправку в последовательную очередь, чтобы пакеты не терялись и шли по порядку
        drawQueue.async { [weak self] in
            guard let self = self, let device = self.selectedDevice else { return }
            let urlString = "http://\(device.ipAddress)/draw/frame"
            guard let url = URL(string: urlString) else { return }
            
            let boundary = "Boundary-\(UUID().uuidString)"
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"frame\"; filename=\"frame.bin\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(frameData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 2.0
            self.addBasicAuthHeader(to: &request)
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
            
            let config = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: config)
            
            // Используем uploadTask с замыканием (completion handler) вместо async/await
            let task = session.uploadTask(with: request, from: body) { _, _, _ in
                // Запрос выполнен
            }
            task.resume()
        }
    }
    
    /// Сохраняет текущее состояние в историю перед изменением
    func saveStateForUndo() {
        undoStack.append(drawPixels)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        // Новое действие сбрасывает стек повтора
        redoStack.removeAll()
        updateUndoRedoStates()
    }
    
    func undoDrawing() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(drawPixels)
        drawPixels = previousState
        updateUndoRedoStates()
        sendDrawFrame()
    }
    
    func redoDrawing() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(drawPixels)
        drawPixels = nextState
        updateUndoRedoStates()
        sendDrawFrame()
    }
    
    private func updateUndoRedoStates() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    /// Сброс истории при старте рисования или полной очистке
    func resetUndoRedoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoStates()
    }
    
    /// Сохранение готового штриха в историю отмены
    func pushCustomStateToUndo(_ prevState: [Color]) {
        undoStack.append(prevState)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        updateUndoRedoStates()
    }
    
    /// Экстренный метод для завершения рисования при закрытии приложения
    func emergencyStopDrawing() {
        guard let device = selectedDevice else { return }
        let urlString = "http://\(device.ipAddress)/draw"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 2.0
        addBasicAuthHeader(to: &request)
        
        // Запрашиваем у системы фоновое время (до ~3 секунд), чтобы запрос успел уйти до убийства процесса
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        // Делаем синхронный семафорный запрос, так как асинхронный Task при гибели приложения отменяется мгновенно
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in
            semaphore.signal()
        }
        task.resume()
        
        // Ждем ответа максимум 1.5 секунды, чтобы не морозить систему
        _ = semaphore.wait(timeout: .now() + 1.5)
        
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        print("🛑 Экстренный DELETE /draw отправлен при закрытии приложения")
    }
}
