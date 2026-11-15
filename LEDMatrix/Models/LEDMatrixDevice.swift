//
//  Models.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import Foundation

struct LEDMatrixDevice: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var ipAddress: String
    var port: Int = 80

    var url: URL? {
        URL(string: "http://\(ipAddress):\(port)")
    }

    init(id: String = UUID().uuidString, name: String, ipAddress: String, port: Int = 80) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.port = port
    }

    enum CodingKeys: String, CodingKey {
        case id, name, ipAddress = "ip", port
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
    var hoursColor1Hex: String = ""
    var hoursColor2Hex: String = ""
    var minutesColor1Hex: String = ""
    var minutesColor2Hex: String = ""
    var colonColorHex: String = ""
    var bgColorHex: String = ""
    var showColon: Bool = true
    var clockAnimationTypeInt: Int? = 0
    var clockAnimationMs: Int = 1000
    var clockRandomColor: Bool = false
    var clockDisplaySeconds: Int = 0
    var animationDisplaySeconds: Int = 0
    var animationTypeInt: Int? = 0
    var animationTypeId: Int? = 0
    var animationSortOrder: Int? = 0
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
        case hoursColor1Hex = "hours_color_1_hex"
        case hoursColor2Hex = "hours_color_2_hex"
        case minutesColor1Hex = "minutes_color_1_hex"
        case minutesColor2Hex = "minutes_color_2_hex"
        case colonColorHex = "colon_color_hex"
        case bgColorHex = "bg_color_hex"
        case showColon = "show_colon"
        case clockAnimationTypeInt = "clock_animation_type"
        case clockAnimationMs = "clock_animation_ms"
        case clockRandomColor = "clock_random_color"
        case clockDisplaySeconds = "clock_display_seconds"
        case animationDisplaySeconds = "animation_display_seconds"
        case animationTypeInt = "animation_type"
        case animationTypeId = "animation_id"
        case animationSortOrder = "animation_sort_order"
        case uptime
    }

    var animationType: AnimationType? {
        get {
            guard let type = animationTypeInt else { return nil }
            let id = animationTypeId ?? 0
            let sortOrder = animationSortOrder ?? 0
            switch type {
            case 0: return .standard(sortOrder: sortOrder)
            case 1: return .category(id: id, sortOrder: sortOrder)
            case 2: return .album(id: id, sortOrder: sortOrder)
            case 3: return .playlist(id: id, sortOrder: sortOrder)
            case 4: return .likes(sortOrder: sortOrder)
            default: return nil
            }
        }
        set {
            animationTypeInt = newValue?.typeKey
            animationTypeId = newValue?.id
        }
    }
    
    var clockAnimationType: ClockAnimationType? {
        get {
            guard let type = clockAnimationTypeInt else { return nil }
            
            switch type {
            case 0: return .fading
            case 1: return .slideUp
            case 2: return .flash
            case 3: return .tvStatic
            default: return nil
            }
        }
        set {
            clockAnimationTypeInt = newValue?.typeKey
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
            components.append("\(days) д.")
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
