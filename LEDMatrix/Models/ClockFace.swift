//
//  ClockFace.swift
//  LEDMatrix
//
//  Разметка циферблата, которую отдаёт GET /clockfaces. Она полностью описывает
//  положение цифр, точки разделителя и цвета, поэтому превью в приложении можно
//  построить без дублирования логики прошивки.
//

import Foundation

struct ClockFaceSeparatorPart: Codable, Identifiable, Equatable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var id: String { "\(x)-\(y)-\(width)-\(height)" }

    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }

    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decodeIfPresent(Int.self, forKey: .x) ?? 0
        y = try container.decodeIfPresent(Int.self, forKey: .y) ?? 0
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
    }

    func contains(x px: Int, y py: Int) -> Bool {
        px >= x && px < x + width && py >= y && py < y + height
    }
}

struct ClockFaceDigit: Codable, Identifiable, Equatable {
    /// "h1", "h2", "m1", "m2"
    var type: String
    var x: Int
    var y: Int
    var font: Int
    var fontStyle: Int
    var fontStyleName: String
    var width: Int
    var height: Int
    var colorHex: String
    var colorSlot: String

    var id: String { type }

    enum CodingKeys: String, CodingKey {
        case type, x, y, font
        case fontStyle = "font_style"
        case fontStyleName = "font_style_name"
        case width, height
        case colorHex = "color_hex"
        case colorSlot = "color_slot"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        x = try container.decodeIfPresent(Int.self, forKey: .x) ?? 0
        y = try container.decodeIfPresent(Int.self, forKey: .y) ?? 0
        font = try container.decodeIfPresent(Int.self, forKey: .font) ?? 0
        fontStyle = try container.decodeIfPresent(Int.self, forKey: .fontStyle) ?? 0
        fontStyleName = try container.decodeIfPresent(String.self, forKey: .fontStyleName) ?? ""
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#FFFFFF"
        colorSlot = try container.decodeIfPresent(String.self, forKey: .colorSlot) ?? "fixed"
    }

    init(type: String, x: Int, y: Int, font: Int, fontStyle: Int,
         fontStyleName: String, width: Int, height: Int,
         colorHex: String, colorSlot: String) {
        self.type = type
        self.x = x
        self.y = y
        self.font = font
        self.fontStyle = fontStyle
        self.fontStyleName = fontStyleName
        self.width = width
        self.height = height
        self.colorHex = colorHex
        self.colorSlot = colorSlot
    }

    func contains(x px: Int, y py: Int) -> Bool {
        px >= x && px < x + width && py >= y && py < y + height
    }

    var displayName: String {
        switch type {
        case "h1": return "Час 1"
        case "h2": return "Час 2"
        case "m1": return "Минута 1"
        case "m2": return "Минута 2"
        default: return type
        }
    }
}

struct ClockFace: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
    var bgColorHex: String
    var bgColorSlot: String
    var digits: [ClockFaceDigit]
    var separatorParts: [ClockFaceSeparatorPart]
    var separatorColorHex: String
    var separatorUseUnderlying: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case bgColorHex = "bg_color_hex"
        case bgColorSlot = "bg_color_slot"
        case digits
        case separatorParts = "separator_parts"
        case separatorColorHex = "separator_color_hex"
        case separatorUseUnderlying = "separator_use_underlying"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        bgColorHex = try container.decodeIfPresent(String.self, forKey: .bgColorHex) ?? "#000000"
        bgColorSlot = try container.decodeIfPresent(String.self, forKey: .bgColorSlot) ?? "background"
        digits = try container.decodeIfPresent([ClockFaceDigit].self, forKey: .digits) ?? []
        separatorParts = try container.decodeIfPresent([ClockFaceSeparatorPart].self, forKey: .separatorParts) ?? []
        separatorColorHex = try container.decodeIfPresent(String.self, forKey: .separatorColorHex) ?? "#FFFFFF"
        separatorUseUnderlying = try container.decodeIfPresent(Bool.self, forKey: .separatorUseUnderlying) ?? false
    }

    init(id: Int, name: String, bgColorHex: String, bgColorSlot: String = "background",
         digits: [ClockFaceDigit], separatorParts: [ClockFaceSeparatorPart],
         separatorColorHex: String, separatorUseUnderlying: Bool) {
        self.id = id
        self.name = name
        self.bgColorHex = bgColorHex
        self.bgColorSlot = bgColorSlot
        self.digits = digits
        self.separatorParts = separatorParts
        self.separatorColorHex = separatorColorHex
        self.separatorUseUnderlying = separatorUseUnderlying
    }

    /// Элемент, который находится под пальцем. Разделитель проверяется раньше
    /// цифр: в Super Bold его точки лежат внутри знакоместа, и выбрать их иначе
    /// было бы невозможно. Цифра выбирается только по реально зажжённому
    /// пикселю, а не по всему прямоугольнику знакоместа: иначе на плотных
    /// циферблатах нельзя было бы добраться до фона.
    func hitTest(x: Int, y: Int, styles: [Int: ClockFontStyle],
                 hour: Int, minute: Int) -> ClockPreviewSelection {
        for (index, part) in separatorParts.enumerated() where part.contains(x: x, y: y) {
            return .separator(index)
        }

        let digitValues: [String: Int] = [
            "h1": hour / 10,
            "h2": hour % 10,
            "m1": minute / 10,
            "m2": minute % 10
        ]

        // Последняя цифра рисуется поверх предыдущих — её и проверяем первой.
        for digit in digits.reversed() where digit.contains(x: x, y: y) {
            guard let value = digitValues[digit.type],
                  let style = styles[digit.fontStyle] else { continue }

            let col = x - digit.x
            let row = y - digit.y
            let width = min(style.width, digit.width)
            let height = min(style.height, digit.height)
            guard col >= 0, row >= 0, col < width, row < height else { continue }

            if style.pixel(digit: value, col: col, row: row) {
                return .digit(digit.type)
            }
        }

        return .background
    }

    func digit(type: String) -> ClockFaceDigit? {
        digits.first { $0.type == type }
    }
}

enum ClockPreviewSelection: Equatable {
    case digit(String)
    case separator(Int)
    case background

    var title: String {
        switch self {
        case .digit(let type):
            switch type {
            case "h1": return "Час 1"
            case "h2": return "Час 2"
            case "m1": return "Минута 1"
            case "m2": return "Минута 2"
            default: return type
            }
        case .separator(let index):
            return "Разделитель \(index + 1)"
        case .background:
            return "Фон"
        }
    }
}
