//
//  ClockFont.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 03.11.2026.
//

import Foundation

struct ClockFont: Codable {
    var fontName: String = ""
    var id: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case fontName = "font_name"
        case id = "id"
    }
}
