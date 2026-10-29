//
//  MatrixManager+Bojour.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

// MARK: - Сканирование Сети

import Foundation
import Network

extension MatrixManager: NetServiceBrowserDelegate, NetServiceDelegate {
    func startScanning() {
        print("🔍 Начать поиск устройств...")
        
        // 1. Обязательно останавливаем прошлый поиск и очищаем ТОЛЬКО системные службы,
        // чтобы избежать конфликта "handler to 0 from 0"
        netServiceBrowser.stop()
        for service in resolvingServices {
            service.stop()
        }
        resolvingServices.removeAll()
        
        // ВАЖНО: Массив discoveredDevices НЕ очищаем, чтобы уже найденные матрицы
        // оставались на экране, даже если сеть их временно потеряла.
        
        isScanning = true
        connectionStatus = "Поиск устройств..."
        
        netServiceBrowser.delegate = self
        netServiceBrowser.searchForServices(ofType: "_http._tcp.", inDomain: "local.")
        
        // Тайм-аут поиска через 10 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        netServiceBrowser.stop()
        for service in resolvingServices {
            service.stop()
        }
        // Очищаем службы, освобождая системные хендлеры iOS
        resolvingServices.removeAll()
        
        isScanning = false
        
        let totalCount = savedDevices.count + discoveredDevices.count
        print("🔍 Поиск завершен. Найдено новых: \(discoveredDevices.count)")
        if totalCount == 0 {
            connectionStatus = "Устройства не найдены"
        } else {
            connectionStatus = "Устройств доступно: \(totalCount)"
        }
    }
    
    // MARK: - NetServiceBrowserDelegate

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let name = service.name
        if name.lowercased().hasPrefix("ledmatrix-") {
            service.delegate = self
            service.resolve(withTimeout: 5.0)
            Task { @MainActor in
                if !self.resolvingServices.contains(service) {
                    self.resolvingServices.append(service)
                }
            }
        }
    }
    
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        // Чтобы устройства не исчезали во время сессии, если пропал Bonjour-сигнал,
        // мы больше не удаляем их из discoveredDevices принудительно внутри didRemove.
        Task { @MainActor in
            service.stop()
            self.resolvingServices.removeAll { $0 === service }
        }
    }
    
    // MARK: - NetServiceDelegate

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        let name = sender.name
        var addressStr = getIPAddress(from: sender.addresses) ?? ""
        if addressStr.isEmpty, let host = sender.hostName {
            addressStr = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        let cleanAddress = addressStr.components(separatedBy: "%").first ?? addressStr
        
        Task { @MainActor in
            if !cleanAddress.isEmpty {
                // 1. Проверяем, нет ли этого устройства уже в списке СОХРАНЕННЫХ
                if self.savedDevices.contains(where: { $0.ipAddress == cleanAddress }) {
                    return // Игнорируем появление в результатах поиска
                }
                
                // 2. Проверяем словарь кастомных имен на случай, если его переименовывали ранее
                let customNames = UserDefaults.standard.dictionary(forKey: self.customNamesKey) as? [String: String] ?? [:]
                let finalName = customNames[cleanAddress] ?? name
                let device = LEDMatrixDevice(name: finalName, ipAddress: cleanAddress)
                // 3. Добавляем в список найденных, если его там еще нет
                if !self.discoveredDevices.contains(where: { $0.ipAddress == cleanAddress }) {
                    self.discoveredDevices.append(device)
                    self.connectionStatus = "Найдено устройств: (self.savedDevices.count + self.discoveredDevices.count)"
                }
            }
        }
    }
    
    private nonisolated func getIPAddress(from addresses: [Data]?) -> String? {
        guard let addresses = addresses else { return nil }
        for address in addresses {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let success = address.withUnsafeBytes { ptr -> Bool in
                guard let addrBase = ptr.baseAddress else { return false }
                let sockAddrPtr = addrBase.assumingMemoryBound(to: sockaddr.self)
                return getnameinfo(sockAddrPtr, socklen_t(address.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0
            }
            
            if success {
                let ip = String(cString: hostname)
                if !ip.contains(":") {
                    return ip
                }
            }
        }
        return nil
    }
}
