//
//  DivoomAnimationParser.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 31.10.2026.
//

import CommonCrypto
import Foundation
import UIKit

struct DivoomAnimationResult {
    let image: UIImage
    let rawSpeed: UInt16
    let swappedSpeed: UInt16
    let speedMs: Int
    let firstByte: UInt8 // Первый байт самого файла (тип из бинарника)
}

enum DivoomAnimationLoader {
    static func loadAndCreateAnimation(from fileId: String) async -> DivoomAnimationResult? {
        let cleanId = fileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty, let url = URL(string: "https://fin.divoom-gz.com/" + cleanId) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, !data.isEmpty else {
                return nil
            }
            return parseAnimationData(data)
        } catch {
            return nil
        }
    }
    
    static func parseAnimationData(_ responseData: Data) -> DivoomAnimationResult? {
        guard responseData.count > 0 else { return nil }
        
        let firstByte = responseData[0] // Запоминаем первый байт файла
        let fileType = firstByte
        let headerLength: Int
        let isEncrypted: Bool
        var rawSpeed: UInt16 = 100
        
        // Читаем скорость из 4-го байта заголовка (индекс 3), если в файле достаточно данных
        let speedFromByte4: UInt16? = responseData.count >= 4 ? UInt16(responseData[3]) : nil
        
        switch fileType {
        case 0x0c:
            headerLength = 4
            isEncrypted = true
            // Скорость берем из 4-го байта (индекс 3), если он есть и не равен 0
            if let s4 = speedFromByte4, s4 > 0 {
                rawSpeed = s4
            } else if responseData.count >= 4 {
                rawSpeed = (UInt16(responseData[2]) << 8) | UInt16(responseData[3])
            }
        case 9:
            headerLength = 4
            isEncrypted = true
            if responseData.count >= 4 {
                rawSpeed = (UInt16(responseData[2]) << 8) | UInt16(responseData[3])
            }
        case 4:
            headerLength = 4
            isEncrypted = false
            if responseData.count >= 4 {
                rawSpeed = (UInt16(responseData[2]) << 8) | UInt16(responseData[3])
            }
        case 7:
            headerLength = 3
            isEncrypted = true
            if responseData.count >= 3 {
                rawSpeed = (UInt16(responseData[1]) << 8) | UInt16(responseData[2])
            } else if responseData.count >= 2 {
                rawSpeed = UInt16(responseData[1])
            }
        case 8:
            headerLength = 1
            isEncrypted = true
            rawSpeed = 100
        case 3:
            headerLength = 1
            isEncrypted = false
            rawSpeed = 100
        default:
            headerLength = 4
            isEncrypted = true
            if responseData.count >= 4 {
                rawSpeed = (UInt16(responseData[2]) << 8) | UInt16(responseData[3])
            }
        }
        
        let swappedSpeed = (rawSpeed >> 8) | (rawSpeed << 8)
        let speedMs = Int(rawSpeed)
        
        guard responseData.count >= headerLength else { return nil }
        
        let payloadData = responseData.advanced(by: headerLength)
        
        let processedPayload: Data
        if isEncrypted {
            let keyHex = "37386872657932337932386F67733839"
            let ivHex = "31323334353637383930313233343536"
            
            guard let keyData = hexToData(keyHex),
                  let ivData = hexToData(ivHex),
                  let decrypted = aes128Decrypt(data: payloadData, key: keyData, iv: ivData)
            else {
                return nil
            }
            processedPayload = decrypted
        } else {
            processedPayload = payloadData
        }
        
        // Получаем кадры в зависимости от типа анимации
        let framesData: [Data]
        if fileType == 0x0c {
            let direction = responseData.count > 1 ? responseData[1] : 0x02
            framesData = generateSeamlessScrollFrames(from: processedPayload, direction: direction)
        } else {
            let frameSize = 768
            let totalFrames = processedPayload.count / frameSize
            var extracted: [Data] = []
            for i in 0..<totalFrames {
                let start = i * frameSize
                let end = start + frameSize
                if end <= processedPayload.count {
                    extracted.append(processedPayload.subdata(in: start..<end))
                }
            }
            framesData = extracted
        }
        
        guard !framesData.isEmpty else { return nil }
        
        var images: [UIImage] = []
        images.reserveCapacity(framesData.count)
        
        let targetSize = CGSize(width: 256, height: 256)
        
        for frameBytes in framesData {
            if let frameImage = createImage(from: frameBytes, targetSize: targetSize) {
                images.append(frameImage)
            }
        }
        
        guard !images.isEmpty else { return nil }
        
        let frameDuration = Double(speedMs) / 1000.0
        let totalDuration = frameDuration * Double(images.count)
        
        guard let finalImage = UIImage.animatedImage(with: images, duration: totalDuration) else { return nil }
        
        return DivoomAnimationResult(
            image: finalImage,
            rawSpeed: rawSpeed,
            swappedSpeed: swappedSpeed,
            speedMs: speedMs,
            firstByte: firstByte
        )
    }
    
    /// Алгоритм генерации кадров с зацикливанием для прокрутки (тип 0C)
    private static func generateSeamlessScrollFrames(from payload: Data, direction: UInt8) -> [Data] {
        let width = 16
        let height = 16
        let bytesPerPixel = 3
        let frameSize = width * height * bytesPerPixel // 768 байт на кадр
        let rowStride = width * bytesPerPixel // 48 байт на строку
        
        var frames: [Data] = []
        
        if direction == 0x02 {
            // Снизу вверх: построчный сдвиг полотна
            let totalRows = payload.count / rowStride
            guard totalRows >= height else { return [] }
            
            for startRow in 0..<totalRows {
                var frameData = Data(count: frameSize)
                frameData.withUnsafeMutableBytes { destBytes in
                    let destBase = destBytes.baseAddress!
                    payload.withUnsafeBytes { srcBytes in
                        let srcBase = srcBytes.baseAddress!
                        for r in 0..<height {
                            let currentRow = (startRow + r) % totalRows
                            let srcOffset = currentRow * rowStride
                            let destOffset = r * rowStride
                            memcpy(destBase.advanced(by: destOffset), srcBase.advanced(by: srcOffset), rowStride)
                        }
                    }
                }
                frames.append(frameData)
            }
        } else if direction == 0x01 {
            // Справа налево / Слева направо: плавный попиксельный сдвиг по соединенным блокам (768 байт)
            let numBlocks = payload.count / frameSize
            guard numBlocks > 0 else { return [] }
            let totalWidthInPixels = numBlocks * width // Общая ширина всех блоков в пикселях
            
            for startCol in 0..<totalWidthInPixels {
                var frameData = Data(count: frameSize)
                frameData.withUnsafeMutableBytes { destBytes in
                    let destBase = destBytes.baseAddress!
                    payload.withUnsafeBytes { srcBytes in
                        let srcBase = srcBytes.baseAddress!
                        
                        for r in 0..<height {
                            let rowDestOffset = r * rowStride
                            for x in 0..<width {
                                // Вычисляем глобальную колонку с учетом зацикливания
                                let globalCol = (startCol + x) % totalWidthInPixels
                                let blockIndex = globalCol / width
                                let localX = globalCol % width
                                
                                // Смещение нужного пикселя в расшифрованном payload
                                let pixelSrcOffset = blockIndex * frameSize + r * rowStride + localX * bytesPerPixel
                                let pixelDestOffset = rowDestOffset + x * bytesPerPixel
                                
                                // Копируем 3 байта RGB
                                destBase.storeBytes(of: srcBase.load(fromByteOffset: pixelSrcOffset, as: UInt8.self), toByteOffset: pixelDestOffset, as: UInt8.self)
                                destBase.storeBytes(of: srcBase.load(fromByteOffset: pixelSrcOffset + 1, as: UInt8.self), toByteOffset: pixelDestOffset + 1, as: UInt8.self)
                                destBase.storeBytes(of: srcBase.load(fromByteOffset: pixelSrcOffset + 2, as: UInt8.self), toByteOffset: pixelDestOffset + 2, as: UInt8.self)
                            }
                        }
                    }
                }
                frames.append(frameData)
            }
        } else {
            // Дефолтная нарезка по 768 байт
            let totalFrames = payload.count / frameSize
            for i in 0..<totalFrames {
                let start = i * frameSize
                let end = start + frameSize
                if end <= payload.count {
                    frames.append(payload.subdata(in: start..<end))
                }
            }
        }
        
        return frames
    }
    
    private static func aes128Decrypt(data: Data, key: Data, iv: Data) -> Data? {
        let count = data.count
        var decryptedData = Data(count: count + kCCBlockSizeAES128)
        let bufferSize = decryptedData.count
        var numBytesDecrypted: size_t = 0
        
        let status = data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    decryptedData.withUnsafeMutableBytes { decryptedBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress,
                            count,
                            decryptedBytes.baseAddress,
                            bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else { return nil }
        decryptedData.removeSubrange(numBytesDecrypted..<decryptedData.count)
        return decryptedData
    }
    
    private static func createImage(from frameData: Data, targetSize: CGSize) -> UIImage? {
        let width = 16
        let height = 16
        
        var rgbBytes = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            for x in 0..<width {
                let srcX = x
                let srcY = 15 - y
                
                let pixelIndex = srcY * width + srcX
                let byteOffset = pixelIndex * 3
                
                guard byteOffset + 2 < frameData.count else { continue }
                
                let r = frameData[byteOffset]
                let g = frameData[byteOffset + 1]
                let b = frameData[byteOffset + 2]
                
                let destOffset = (y * width + x) * 4
                rgbBytes[destOffset] = r
                rgbBytes[destOffset + 1] = g
                rgbBytes[destOffset + 2] = b
                rgbBytes[destOffset + 3] = 255
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: &rgbBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let cgImage = context.makeImage() else { return nil }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .none
            ctx.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private static func hexToData(_ hex: String) -> Data? {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            let byteString = hex[index..<nextIndex]
            guard let num = UInt8(byteString, radix: 16) else { return nil }
            data.append(num)
            index = nextIndex
        }
        return data
    }
}
