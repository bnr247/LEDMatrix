//
//  Models.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import Foundation

/// Для стабильной работы ForEach id должен быть привязан к уникальному IP,
/// так как UUID() генерировался бы заново при каждом создании объекта.
struct LEDMatrixDevice: Identifiable, Equatable {
    var id: String {
        ipAddress
    }

    var name: String
    var ipAddress: String
    var port: Int = 80

    var url: URL? {
        URL(string: "http://\(ipAddress):\(port)")
    }
}

struct MatrixSettings: Codable {
    var brightnessPercent: Int = 0
    var dayBrightnessPercent: Int = 0
    var nightBrightnessPercent: Int = 0
    var dayStart: String = ""
    var nightStart: String = ""
    var dayDeviceMode: String = ""
    var nightDeviceMode: String = ""
    var deviceMode: String = ""
    var showNameText: Bool = false
    var currentClockFontId: Int = 0
    var scrollSpeedFps: Int = 0
    var scrollRepeatCount: Int = 0
    var bootCount: Int = 0
    var divoomEmail: String = ""
    var divoomPassword: String = ""
    var divoomUserId: Int = 0
    var divoomToken: Int = 0
    var macAddress: String = ""
    var hostName: String = ""
    var ipAddress: String = ""
    var hwVersion: String = ""
    var fwVersion: String = ""
    var hoursColorHex: String = ""
    var minutesColorHex: String = ""
    var colonColorHex: String = ""
    var bgColorHex: String = ""
    var clockDisplaySeconds: Int = 0
    var animationDisplaySeconds: Int = 0
    var animationTypeString: String? = ""
    var animationTypeId: Int? = 0
    var uptime: Int = 0

    enum CodingKeys: String, CodingKey {
        case brightnessPercent = "brightness"
        case dayBrightnessPercent = "brightness_day"
        case nightBrightnessPercent = "brightness_night"
        case dayStart = "day_start"
        case nightStart = "night_start"
        case dayDeviceMode = "day_device_mode"
        case nightDeviceMode = "night_device_mode"
        case deviceMode = "device_mode"
        case showNameText = "show_name_text"
        case currentClockFontId = "current_clock_font_id"
        case scrollSpeedFps = "scroll_speed_fps"
        case scrollRepeatCount = "scroll_repeat_count"
        case bootCount = "boot_count"
        case divoomEmail = "divoom_email"
        case divoomPassword = "divoom_password"
        case divoomUserId = "divoom_user_id"
        case divoomToken = "divoom_token"
        case macAddress = "mac_address"
        case hostName = "hostname"
        case ipAddress = "ip_address"
        case hwVersion = "hw_version"
        case fwVersion = "fw_version"
        case hoursColorHex = "hours_color_hex"
        case minutesColorHex = "minutes_color_hex"
        case colonColorHex = "colon_color_hex"
        case bgColorHex = "bg_color_hex"
        case clockDisplaySeconds = "clock_display_seconds"
        case animationDisplaySeconds = "animation_display_seconds"
        case animationTypeString = "animation_type"
        case animationTypeId = "animation_id"
        case uptime
    }

    var animationType: AnimationType? {
        get {
            guard let type = animationTypeString else { return nil }
            let id = animationTypeId ?? 0
            switch type {
            case "category": return .category(id: id)
            case "album": return .album(id: id)
            case "standard": return .standard
            default: return nil
            }
        }
        set {
            animationTypeString = newValue?.typeKey
            animationTypeId = newValue?.id
        }
    }

    var divoomPasswordSet: Bool {
        !divoomPassword.isEmpty
    }

    var formattedUptime: String {
        let currentEpoch = Int(Date().timeIntervalSince1970)
        let totalSeconds = currentEpoch - uptime
        guard totalSeconds > 0 else { return "0 сек." }

        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        var components: [String] = []
        if days > 0 {
            components.append("\(days) дн.")
        }
        if days > 0 || hours > 0 {
            components.append("\(hours) ч")
        }
        if days > 0 || hours > 0 || minutes > 0 {
            components.append("\(minutes) мин.")
        }
        components.append("\(seconds) сек.")

        return components.joined(separator: " ")
    }
    
    var formattedBootTime: String {
            guard uptime > 0 else { return "—" }
            let date = Date(timeIntervalSince1970: TimeInterval(uptime))
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy HH:mm"
            return formatter.string(from: date)
        }
}

struct MatrixWifiSettings: Codable {
    var ssid: String = ""
    var passwordSet: Bool = false

    enum CodingKeys: String, CodingKey {
        case ssid
        case passwordSet = "password_set"
    }
}
