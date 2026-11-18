//
//  ClockAnimationType.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 15.11.2026.
//

import Foundation

enum ClockAnimationType: Hashable {
    case fading
    case slideUp
    case flash
    case tvStatic
    
    var typeKey: Int {
        switch self {
        case .fading: return 0
        case .slideUp: return 1
        case .flash: return 2
        case .tvStatic: return 3
        }
    }
    
    var parameters: [String: Any] {
        var params: [String: Any] = ["clock_animation_type": typeKey]
        return params
    }
}
