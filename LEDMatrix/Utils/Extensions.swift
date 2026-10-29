//
//  Extensions.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import CryptoKit
import SwiftUI

extension NetService: @retroactive @unchecked Sendable {}

extension View {
    func hideKeyboard() {
#if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

/// Вспомогательный поиск UINavigationController вьюхи
extension UIViewController {
    func findNavigationController() -> UINavigationController? {
        if let nav = self as? UINavigationController {
            return nav
        }
        for child in children {
            if let found = child.findNavigationController() {
                return found
            }
        }
        if let presented = presentedViewController {
            return presented.findNavigationController()
        }
        return nil
    }
}

/// Вспомогательное расширение для безопасного обновления внешнего вида навигации в iOS
extension UINavigationController {
    static func updateAppearance(_ appearance: UINavigationBarAppearance) {
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Быстро обновляем текущий стек навигации, чтобы изменения применились мгновенно
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController
        {
            rootVC.setNeedsStatusBarAppearanceUpdate()
        }
    }
}

extension Color {
    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch sanitizedHex.count {
        case 6: // Формат RGB (например, "540F28")
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
            self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        default:
            self.init(.black)
        }
    }
}

extension UIColor {
    func rgbComponents() -> (Int, Int, Int) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }

    func toHex() -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb = Int(r * 255)<<16 | Int(g * 255)<<8 | Int(b * 255)
        return String(format: "%06X", rgb)
    }
}

// MARK: - Расширение для шифрования строк в MD5

extension String {
    func md5Hex() -> String {
        let digest = Insecure.MD5.hash(data: Data(self.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension UIImage {
    /// Поворот на 90 градусов по часовой стрелке
    func rotated90Clockwise() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size.height, height: size.width))
        return renderer.image { context in
            context.cgContext.translateBy(x: size.height / 2, y: size.width / 2)
            context.cgContext.rotate(by: .pi / 2)
            context.cgContext.translateBy(x: -size.width / 2, y: -size.height / 2)
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Регулировка контраста и насыщенности через Core Image
    func adjusted(contrast: CGFloat, saturation: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey) // По умолчанию 1.0 (больше 1.0 — насыщеннее)
        filter.setValue(contrast, forKey: kCIInputContrastKey) // По умолчанию 1.0 (больше 1.0 — контрастнее)

        let context = CIContext()
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
    }
}
