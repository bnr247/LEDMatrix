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

private final class DivoomFirstFrameCacheEntry {
    let image: UIImage
    init(_ image: UIImage) { self.image = image }
}

private struct ParsedAnimationData {
    let frames: [Data]
    let rawSpeed: UInt16
    let swappedSpeed: UInt16
    let speedMs: Int
    let firstByte: UInt8
    let fileType: UInt8
}

enum DivoomAnimationLoader {
    // Сетка и фид часто показывают одни и те же анимации. Кэш с ограниченным
    // числом записей убирает повторную загрузку и дублирование кадров в памяти.
    private static let cache: NSCache<NSString, DivoomAnimationCacheEntry> = {
        let cache = NSCache<NSString, DivoomAnimationCacheEntry>()
        cache.countLimit = 200
        return cache
    }()

    // Быстрый первый кадр для сетки: один 16x16 CGImage вместо всей анимации.
    private static let firstFrameCache: NSCache<NSString, DivoomFirstFrameCacheEntry> = {
        let cache = NSCache<NSString, DivoomFirstFrameCacheEntry>()
        cache.countLimit = 400
        return cache
    }()

    // MARK: - Публичные методы

    /// Быстрый статичный первый кадр — для мгновенного отображения сетки.
    static func loadFirstFrame(from fileId: String) async -> UIImage? {
        let cleanId = fileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return nil }

        let key = cleanId as NSString
        if let cached = firstFrameCache.object(forKey: key) {
            return cached.image
        }

        guard let data = await fetchData(cleanId, key: key),
              let image = parseFirstFrameData(data) else { return nil }

        firstFrameCache.setObject(DivoomFirstFrameCacheEntry(image), forKey: key)
        return image
    }

    /// Полная анимация. Догружается в фоне после того, как первый кадр уже виден.
    static func loadAndCreateAnimation(from fileId: String) async -> DivoomAnimationResult? {
        let cleanId = fileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return nil }

        let key = cleanId as NSString
        if let cached = cache.object(forKey: key) {
            return cached.result
        }

        guard let data = await fetchData(cleanId, key: key),
              let result = parseAnimationData(data) else { return nil }

        cache.setObject(DivoomAnimationCacheEntry(result), forKey: key)
        return result
    }

    // MARK: - Загрузка и разбор

    /// Сетка, фид и видимые ячейки часто просят один и тот же fileId
    /// одновременно. Без координатора каждый из них качал бы файл заново.
    private actor DivoomDataFetchCoordinator {
        // Сырые файлы кэшируются, чтобы первый кадр и полная анимация не качали
        // один и тот же URL дважды.
        private let rawDataCache: NSCache<NSString, NSData> = {
            let cache = NSCache<NSString, NSData>()
            cache.countLimit = 300
            return cache
        }()
        private var inFlight: [String: Task<Data?, Never>] = [:]

        func data(for fileId: String, key: NSString) async -> Data? {
            if let cached = rawDataCache.object(forKey: key) {
                return cached as Data
            }

            if let existing = inFlight[fileId] {
                return await existing.value
            }

            let task = Task<Data?, Never> {
                guard let url = URL(string: "https://fin.divoom-gz.com/" + fileId) else { return nil }

                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard let httpResp = response as? HTTPURLResponse,
                          httpResp.statusCode == 200,
                          !data.isEmpty else { return nil }

                    rawDataCache.setObject(data as NSData, forKey: key)
                    return data
                } catch {
                    return nil
                }
            }

            inFlight[fileId] = task
            let data = await task.value
            inFlight[fileId] = nil
            return data
        }
    }

    private static let dataCoordinator = DivoomDataFetchCoordinator()

    private static func fetchData(_ fileId: String, key: NSString) async -> Data? {
        await dataCoordinator.data(for: fileId, key: key)
    }

    static func parseAnimationData(_ responseData: Data) -> DivoomAnimationResult? {
        guard let parsed = parseFrames(from: responseData) else { return nil }

        var images: [UIImage] = []
        // Анимация 16x16 — это пиксель-арт. Кадры хранятся в родном размере:
        // UIView увеличит их nearest-neighbor фильтрацией, а 256x256 рендер
        // на каждый кадр съедал десятки МБ и приводил к NSMallocException.
        images.reserveCapacity(min(parsed.frames.count, 600))

        for frameBytes in parsed.frames.prefix(600) {
            if let frameImage = createImage(from: frameBytes) {
                images.append(frameImage)
            }
        }

        guard !images.isEmpty else { return nil }

        let totalDuration: Double = (parsed.fileType == 8 || parsed.fileType == 3)
            ? 10.0
            : (Double(parsed.speedMs) / 1000.0 * Double(images.count))

        if images.count == 1 {
            return DivoomAnimationResult(
                image: images[0],
                rawSpeed: parsed.rawSpeed,
                swappedSpeed: parsed.swappedSpeed,
                speedMs: parsed.speedMs,
                firstByte: parsed.firstByte
            )
        }

        guard let finalImage = UIImage.animatedImage(with: images, duration: totalDuration) else {
            return DivoomAnimationResult(
                image: images[0],
                rawSpeed: parsed.rawSpeed,
                swappedSpeed: parsed.swappedSpeed,
                speedMs: parsed.speedMs,
                firstByte: parsed.firstByte
            )
        }

        return DivoomAnimationResult(
            image: finalImage,
            rawSpeed: parsed.rawSpeed,
            swappedSpeed: parsed.swappedSpeed,
            speedMs: parsed.speedMs,
            firstByte: parsed.firstByte
        )
    }

    /// Разбирает только первый кадр — без создания UIImage.animatedImage.
    static func parseFirstFrameData(_ responseData: Data) -> UIImage? {
        guard let parsed = parseFrames(from: responseData),
              let firstFrame = parsed.frames.first else { return nil }
        return createImage(from: firstFrame)
    }

    private static func parseFrames(from responseData: Data) -> ParsedAnimationData? {
        guard !responseData.isEmpty else { return nil }

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
            headerLength = 1
            isEncrypted = true
            rawSpeed = 10000
        case 3:
            headerLength = 1
            isEncrypted = false
            rawSpeed = 10000
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

        return ParsedAnimationData(
            frames: framesData,
            rawSpeed: rawSpeed,
            swappedSpeed: swappedSpeed,
            speedMs: speedMs,
            firstByte: firstByte,
            fileType: fileType
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
        guard count > 0, count < 10000000 else { return nil }

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
