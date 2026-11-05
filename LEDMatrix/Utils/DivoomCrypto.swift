//
//  DivoomCrypto.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 31.10.2026.
//

import CommonCrypto
import Foundation

/// Обрабатывает ответ сервера (application/octet-stream), расшифровывает полезную нагрузку
/// и возвращает объединенный результат (заголовок + данные) в виде HEX-строки.
func processDivoomServerResponse(_ responseData: Data) -> String? {
    guard !responseData.isEmpty else { return nil }
    
    // Первый байт — всегда тип файла
    let fileType = responseData[0]
    
    // Определяем длину заголовка и необходимость дешифровки по типу файла
    let headerLength: Int
    let isEncrypted: Bool
    
    switch fileType {
    case 9:
        headerLength = 4
        isEncrypted = true
    case 8:
        headerLength = 1
        isEncrypted = true
    case 7:
        headerLength = 2
        isEncrypted = true
    case 4:
        headerLength = 4
        isEncrypted = false
    case 3:
        headerLength = 1
        isEncrypted = false
    default:
        headerLength = 4
        isEncrypted = true
    }
    
    guard responseData.count >= headerLength else { return nil }
    
    // Выделяем заголовок и полезную нагрузку (данные кадров)
    let headerData = responseData.prefix(headerLength)
    let payloadData = responseData.advanced(by: headerLength)
    
    let processedPayload: Data
    
    if isEncrypted {
        // Ключ и IV формате hex
        let keyHex = "37386872657932337932386F67733839"
        let ivHex = "31323334353637383930313233343536"
        
        guard let keyData = hexStringToData(keyHex),
              let ivData = hexStringToData(ivHex),
              let decryptedData = aes128Decrypt(data: payloadData, key: keyData, iv: ivData)
        else {
            print("❌ Ошибка дешифрования AES-128-CBC")
            return nil
        }
        processedPayload = decryptedData
    } else {
        processedPayload = payloadData
    }
    
    // Собираем заголовок + обработанные данные вместе
    var finalData = Data()
    finalData.append(headerData)
    finalData.append(processedPayload)
    
    // Конвертируем итоговый результат в HEX-строку
    return finalData.map { String(format: "%02hhx", $0) }.joined()
}

// MARK: - Вспомогательные функции криптографии и конвертации

private func aes128Decrypt(data: Data, key: Data, iv: Data) -> Data? {
    let keyLength = kCCKeySizeAES128
    let operation = CCOperation(kCCDecrypt)
    let algOptions = CCOptions(kCCOptionPKCS7Padding)
    
    var decryptedData = Data(count: data.count + kCCBlockSizeAES128)
    let bufferSize = decryptedData.count // Кэшируем размер в локальную константу
    var numBytesDecrypted: size_t = 0
    
    let status = data.withUnsafeBytes { dataBytes in
        key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                decryptedData.withUnsafeMutableBytes { decryptedBytes in
                    CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES),
                        algOptions,
                        keyBytes.baseAddress, keyLength,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, data.count,
                        decryptedBytes.baseAddress,
                        bufferSize,
                        &numBytesDecrypted
                    )
                }
            }
        }
    }
    
    guard status == kCCSuccess else {
        return nil
    }
    
    decryptedData.removeSubrange(numBytesDecrypted..<decryptedData.count)
    return decryptedData
}

private func hexStringToData(_ hex: String) -> Data? {
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
