//
//  ClockColorEffect.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 18.11.2026.
//

import Foundation

enum ClockColorEffect: Hashable {
    case off
    case swap
    case spectrum
    case rainbow
    case randomColor
    
    var typeKey: Int {
        switch self {
        case .off: return 0
        case .swap: return 1
        case .spectrum: return 2
        case .rainbow: return 3
        case .randomColor: return 4
        }
    }
    
    var parameters: [String: Any] {
        var params: [String: Any] = ["clock_color_effect": typeKey]
        return params
    }

    /// Скорость управляет только непрерывными эффектами: спектром и радугой.
    /// Обмен цветом и случайный цвет срабатывают при смене цифры, а «Нет»
    /// вообще не анимирует цвет — для них слайдер не нужен.
    var usesSpeed: Bool {
        switch self {
        case .spectrum, .rainbow: return true
        case .off, .swap, .randomColor: return false
        }
    }
}
