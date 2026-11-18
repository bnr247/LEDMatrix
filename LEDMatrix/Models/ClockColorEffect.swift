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
}
