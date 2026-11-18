//
//  ClockFont.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 03.11.2026.
//

import Foundation

/// Один растровый стиль цифр. В API /clockfonts у шрифта может быть несколько
/// стилей (например, у Huge Bold есть 6x10 и 6x5), а разметка циферблата
/// ссылается на конкретный `font_style`.
struct ClockFontStyle: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
    var width: Int
    var height: Int
    /// digits[digit][row] — байт колонок: бит (width - 1 - col) зажигает пиксель.
    var digits: [[Int]]

    enum CodingKeys: String, CodingKey {
        case id, name, width, height, digits
    }

    init(id: Int, name: String, width: Int, height: Int, digits: [[Int]]) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.digits = digits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
        digits = try container.decodeIfPresent([[Int]].self, forKey: .digits) ?? []
    }

    /// Возвращает true, если пиксель (col, row) знакоместа зажжён.
    func pixel(digit: Int, col: Int, row: Int) -> Bool {
        guard digit >= 0, digit < digits.count,
              row >= 0, row < digits[digit].count,
              col >= 0, col < width else { return false }
        let byte = digits[digit][row]
        return (byte & (1 << (width - 1 - col))) != 0
    }
}

struct ClockFont: Codable, Identifiable, Equatable {
    var fontName: String = ""
    var id: Int = 0
    var width: Int = 0
    var height: Int = 0
    var fontStyleId: Int = 0
    var fontStyleName: String = ""
    var digits: [[Int]] = []
    var styles: [ClockFontStyle] = []

    enum CodingKeys: String, CodingKey {
        case fontName = "font_name"
        case id
        case width, height
        case fontStyleId = "font_style_id"
        case fontStyleName = "font_style_name"
        case digits, styles
    }

    init(id: Int, fontName: String) {
        self.id = id
        self.fontName = fontName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? ""
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
        fontStyleId = try container.decodeIfPresent(Int.self, forKey: .fontStyleId) ?? 0
        fontStyleName = try container.decodeIfPresent(String.self, forKey: .fontStyleName) ?? ""
        digits = try container.decodeIfPresent([[Int]].self, forKey: .digits) ?? []
        styles = try container.decodeIfPresent([ClockFontStyle].self, forKey: .styles) ?? []
    }
}
