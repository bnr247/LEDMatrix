//
//  MatrixManager+Camera.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import Foundation
import SwiftUI
import UIKit

extension MatrixManager {
    /// Метод обработки кадра с камеры: поворот, улучшение цвета и конвертация в сетку 16x16
    func processCameraImage(_ image: UIImage) {
        // 1. Поворачиваем на 90° по часовой и делаем контрастнее (например, 1.25) и насыщеннее (например, 1.3)
        guard let rotated = image.rotated90Clockwise(),
              let enhanced = rotated.adjusted(contrast: 1.2, saturation: 0.7)
        else {
            lastCapturedImage = image
            return
        }
        
        // Теперь в галерею пойдет уже повернутое и улучшенное фото
        lastCapturedImage = enhanced
        
        // 2. Сжимаем обработанное изображение до 16x16 для матрицы
        let targetSize = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        enhanced.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = resizedImage?.cgImage else { return }
        
        var newPixels: [Color] = Array(repeating: .black, count: 256)
        let width = 16
        let height = 16
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        for row in 0..<16 {
            for col in 0..<16 {
                let index = (row * 16 + col)
                let byteIndex = index * 4
                
                let r = Double(rawData[byteIndex]) / 255.0
                let g = Double(rawData[byteIndex + 1]) / 255.0
                let b = Double(rawData[byteIndex + 2]) / 255.0
                
                newPixels[index] = Color(red: r, green: g, blue: b)
            }
        }
        
        DispatchQueue.main.async {
            self.cameraPixels = newPixels
            if self.isCameraActive {
                self.drawPixels = newPixels
                self.sendCameraDrawFrame()
            }
        }
    }
    
    /// Отправка кадра камеры на матрицу (аналог sendDrawFrame)
    private func sendCameraDrawFrame() {
        guard selectedDevice != nil else { return }
        var frameData = Data()
        frameData.reserveCapacity(512)
        
        for row in 0..<16 {
            for col in 0..<16 {
                let targetIndex = row * 16 + col
                let color = cameraPixels[targetIndex]
                let uiColor = UIColor(color)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                let rgb565 = (UInt16(r * 255 / 8) << 11) | (UInt16(g * 255 / 4) << 5) | UInt16(b * 255 / 8)
                frameData.append(UInt8(rgb565 >> 8))
                frameData.append(UInt8(rgb565 & 0xFF))
            }
        }
        
        drawQueue.async { [weak self] in
            guard let self = self, let device = self.selectedDevice, let url = URL(string: "http://\(device.ipAddress)/draw/frame") else { return }
            let boundary = "Boundary-\(UUID().uuidString)"
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"frame\"; filename=\"frame.bin\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(frameData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            self.addBasicAuthHeader(to: &request)
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
            
            let task = URLSession(configuration: .ephemeral).uploadTask(with: request, from: body) { _, _, _ in }
            task.resume()
        }
    }
    
    /// Генерация UIImage из текущих пикселей камеры с учетом тумблера сетки
    func generateCapturedImage(withGrid: Bool) -> UIImage? {
        let scale: CGFloat = 40 // Размер одного пикселя на итоговом изображении (16 * 40 = 640x640 пикселей)
        let totalSize = CGSize(width: 16 * scale, height: 16 * scale)
        
        let renderer = UIGraphicsImageRenderer(size: totalSize)
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Заливаем фон черным
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(CGRect(origin: .zero, size: totalSize))
            
            let spacing: CGFloat = withGrid ? 1 * (scale / 10) : 0
            let cellSize = (totalSize.width - (spacing * 17)) / 16.0
            
            for row in 0..<16 {
                for col in 0..<16 {
                    let index = row * 16 + col
                    let color = cameraPixels[index]
                    
                    let x = spacing + CGFloat(col) * (cellSize + spacing)
                    let y = spacing + CGFloat(row) * (cellSize + spacing)
                    let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
                    
                    ctx.setFillColor(UIColor(color).cgColor)
                    ctx.fill(rect)
                }
            }
        }
    }
}
