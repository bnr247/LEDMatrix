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
    let firstByte: UInt8
}

private final class DivoomAnimationCacheEntry {
    let result: DivoomAnimationResult
    init(_ result: DivoomAnimationResult) { self.result = result }
}

enum DivoomAnimationLoader {
    // Сетка и фид часто показывают одни и те же анимации. Кэш с ограниченным
    // числом записей убирает повторную загрузку и дублирование кадров в памяти.
    private static let cache: NSCache<NSString, DivoomAnimationCacheEntry> = {
        let cache = NSCache<NSString, DivoomAnimationCacheEntry>()
        cache.countLimit = 200
        return cache
    }()

    static func loadAndCreateAnimation(from fileId: String) async -> DivoomAnimationResult? {
        let cleanId = fileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return nil }

        let key = cleanId as NSString
        if let cached = cache.object(forKey: key) {
            return cached.result
        }

        guard let url = URL(string: "https://fin.divoom-gz.com/" + cleanId) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, !data.isEmpty else {
                return nil
            }
            guard let result = parseAnimationData(data) else { return nil }
            cache.setObject(DivoomAnimationCacheEntry(result), forKey: key)
            return result
        } catch {
            return nil
        }
    }
    
    static func parseAnimationData(_ responseData: Data) -> DivoomAnimationResult? {
        guard responseData.count > 0 else { return nil }
        
        let firstByte = responseData[0]
        let fileType = firstByte
        let headerLength: Int
        let isEncrypted: Bool
        var rawSpeed: UInt16 = 100
        
        let speedFromByte4: UInt16? = responseData.count >= 4 ? UInt16(responseData[3]) : nil
        
        switch fileType {
        case 0x0c:
            headerLength = 4
            isEncrypted = true
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
            headerLength = 1 // 1 байт заголовка (только тип)
            isEncrypted = true
            rawSpeed = 10000 // 10 секунд (10000 мс) для статичной картинки
        case 3:
            headerLength = 1 // 1 байт заголовка (только тип)
            isEncrypted = false
            rawSpeed = 10000 // 10 секунд (10000 мс) для статичной картинки
        default:
            headerLength = 4
            isEncrypted = true
            if responseData.count >= 4 {
                rawSpeed = (UInt16(responseData[2]) << 8) | UInt16(responseData[3])
            }
        }
        
        let swappedSpeed = (rawSpeed >> 8) | (rawSpeed << 8)
        let speedMs = Int(rawSpeed)
        
        guard responseData.count > headerLength else { return nil }
        
        let payloadData = Data(responseData[headerLength...])
        guard !payloadData.isEmpty else { return nil }
        
        let processedPayload: Data
        if isEncrypted {
            let keyHex = "37386872657932337932386F67733839"
            let ivHex = "31323334353637383930313233343536"
            
            // Безопасное дешифрование с фоллбеком на raw payload, если файл не зашифрован
            if let keyData = hexToData(keyHex),
               let ivData = hexToData(ivHex),
               let decrypted = aes128Decrypt(data: payloadData, key: keyData, iv: ivData)
            {
                processedPayload = decrypted
            } else {
                processedPayload = payloadData
            }
        } else {
            processedPayload = payloadData
        }
        
        let framesData: [Data]
        if fileType == 0x0c {
            let direction = responseData.count > 1 ? responseData[1] : 0x02
            framesData = generateSeamlessScrollFrames(from: processedPayload, direction: direction)
        } else {
            let frameSize = 768
            var workingPayload = processedPayload
            if workingPayload.count < frameSize {
                workingPayload.append(Data(repeating: 0, count: frameSize - workingPayload.count))
            }
            
            let totalFrames = workingPayload.count / frameSize
            var extracted: [Data] = []
            for i in 0..<max(1, totalFrames) {
                let start = i * frameSize
                let end = start + frameSize
                if end <= workingPayload.count {
                    extracted.append(workingPayload.subdata(in: start..<end))
                } else if start < workingPayload.count {
                    var chunk = workingPayload.subdata(in: start..<workingPayload.count)
                    chunk.append(Data(repeating: 0, count: frameSize - chunk.count))
                    extracted.append(chunk)
                }
            }
            framesData = extracted
        }
        
        guard !framesData.isEmpty else { return nil }
        
        var images: [UIImage] = []
        // Анимация 16x16 — это пиксель-арт. Кадры хранятся в родном размере:
        // UIView увеличит их nearest-neighbor фильтрацией, а 256x256 рендер
        // на каждый кадр съедал десятки МБ и приводил к NSMallocException.
        images.reserveCapacity(min(framesData.count, 600))

        for frameBytes in framesData.prefix(600) {
            if let frameImage = createImage(from: frameBytes) {
                images.append(frameImage)
            }
        }
        
        guard !images.isEmpty else { return nil }
        
        let totalDuration: Double = (fileType == 8 || fileType == 3) ? 10.0 : (Double(speedMs) / 1000.0 * Double(images.count))
        
        if images.count == 1 {
            return DivoomAnimationResult(
                image: images.first!,
                rawSpeed: rawSpeed,
                swappedSpeed: swappedSpeed,
                speedMs: speedMs,
                firstByte: firstByte
            )
        }
        
        guard let finalImage = UIImage.animatedImage(with: images, duration: totalDuration) else {
            return DivoomAnimationResult(
                image: images.first!,
                rawSpeed: rawSpeed,
                swappedSpeed: swappedSpeed,
                speedMs: speedMs,
                firstByte: firstByte
            )
        }
        
        return DivoomAnimationResult(
            image: finalImage,
            rawSpeed: rawSpeed,
            swappedSpeed: swappedSpeed,
            speedMs: speedMs,
            firstByte: firstByte
        )
    }
    
    private static func generateSeamlessScrollFrames(from payload: Data, direction: UInt8) -> [Data] {
        let width = 16
        let height = 16
        let bytesPerPixel = 3
        let frameSize = width * height * bytesPerPixel
        let rowStride = width * bytesPerPixel
        
        var frames: [Data] = []
        guard payload.count >= rowStride * height else { return [] }
        
        if direction == 0x02 {
            let totalRows = payload.count / rowStride
            guard totalRows >= height else { return [] }
            
            for startRow in 0..<totalRows {
                var frameData = Data(count: frameSize)
                frameData.withUnsafeMutableBytes { destBytes in
                    guard let destBase = destBytes.baseAddress else { return }
                    payload.withUnsafeBytes { srcBytes in
                        guard let srcBase = srcBytes.baseAddress else { return }
                        for r in 0..<height {
                            let currentRow = (startRow + r) % totalRows
                            let srcOffset = currentRow * rowStride
                            let destOffset = r * rowStride
                            if srcOffset + rowStride <= payload.count, destOffset + rowStride <= frameSize {
                                memcpy(destBase.advanced(by: destOffset), srcBase.advanced(by: srcOffset), rowStride)
                            }
                        }
                    }
                }
                frames.append(frameData)
            }
        } else if direction == 0x01 {
            let numBlocks = payload.count / frameSize
            guard numBlocks > 0 else { return [] }
            let totalWidthInPixels = numBlocks * width
            
            for startCol in 0..<totalWidthInPixels {
                var frameData = Data(count: frameSize)
                frameData.withUnsafeMutableBytes { destBytes in
                    guard let destBase = destBytes.baseAddress else { return }
                    payload.withUnsafeBytes { srcBytes in
                        guard let srcBase = srcBytes.baseAddress else { return }
                        
                        for r in 0..<height {
                            let rowDestOffset = r * rowStride
                            for x in 0..<width {
                                let globalCol = (startCol + x) % totalWidthInPixels
                                let blockIndex = globalCol / width
                                let localX = globalCol % width
                                
                                let pixelSrcOffset = blockIndex * frameSize + r * rowStride + localX * bytesPerPixel
                                let pixelDestOffset = rowDestOffset + x * bytesPerPixel
                                
                                if pixelSrcOffset + 2 < payload.count, pixelDestOffset + 2 < frameSize {
                                    destBase.storeBytes(of: srcBase.load(fromByteOffset: pixelSrcOffset, as: UInt8.self), toByteOffset: pixelDestOffset, as: UInt8.self)
                                    destBase.storeBytes(of: srcBase.load(fromByteOffset: pixelSrcOffset + 1, as: UInt8.self), toByteOffset: pixelDestOffset + 1, as: UInt8.self)
                                    destBase.storeBytes(of: srcBase.load(fromByteOffset: pixelSrcOffset + 2, as: UInt8.self), toByteOffset: pixelDestOffset + 2, as: UInt8.self)
                                }
                            }
                        }
                    }
                }
                frames.append(frameData)
            }
        } else {
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
            // Жесткая защита: размер данных должен быть в разумных пределах
            guard count > 0, count < 10000000 else { return nil }
                
            // Безопасное вычисление размера буфера с защитой от переполнения (integer overflow)
            let (bufferSize, overflow) = count.addingReportingOverflow(kCCBlockSizeAES128)
            guard !overflow, bufferSize > 0 else { return nil }
                
            var decryptedData = Data(count: bufferSize)
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
            
            // Защита от некорректного размера расшифрованных данных
            guard numBytesDecrypted <= decryptedData.count else { return nil }
            
            decryptedData.removeSubrange(numBytesDecrypted..<decryptedData.count)
            return decryptedData
        }
    
    private static func createImage(from frameData: Data) -> UIImage? {
        let width = 16
        let height = 16
        
        guard frameData.count >= width * height * 3 else { return nil }
        
        var rgbBytes = [UInt8](repeating: 0, count: width * height * 4)
        
        frameData.withUnsafeBytes { srcPtr in
            guard let srcBase = srcPtr.baseAddress else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let srcX = x
                    // Раньше здесь был srcY = 15 - y: ручной флип компенсировал
                    // неявный переворот UIGraphicsImageRenderer. Теперь кадр
                    // создаётся напрямую через UIImage(cgImage:), поэтому флип
                    // убран — иначе анимация отображается вверх ногами.
                    let srcY = y
                    
                    let pixelIndex = srcY * width + srcX
                    let byteOffset = pixelIndex * 3
                    
                    guard byteOffset + 2 < frameData.count else { continue }
                    
                    let r = srcBase.load(fromByteOffset: byteOffset, as: UInt8.self)
                    let g = srcBase.load(fromByteOffset: byteOffset + 1, as: UInt8.self)
                    let b = srcBase.load(fromByteOffset: byteOffset + 2, as: UInt8.self)
                    
                    let destOffset = (y * width + x) * 4
                    rgbBytes[destOffset] = r
                    rgbBytes[destOffset + 1] = g
                    rgbBytes[destOffset + 2] = b
                    rgbBytes[destOffset + 3] = 255
                }
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

        // Родной размер 16x16 экономит память в 256 раз по сравнению с
        // рендером 256x256. AnimatedImageRepresentable масштабирует кадры
        // фильтром .nearest, поэтому картинка выглядит так же.
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
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
