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
    var clockFont: Int = 0
    var scrollSpeedFps: Int = 0
    var scrollRepeatCount: Int = 0
    var bootCount: Int = 0
    var divoomEmail: String = ""
    var divoomPasswordSet: Bool = false
    var macAddress: String = ""
    var hostName: String = ""
    var ipAddress: String = ""
    var hwVersion: String = ""
    var fwVersion: String = ""
    var hoursColorHex: String = ""
    var minutesColorHex: String = ""
    var colonColorHex: String = ""
    var bgColorHex: String = ""

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
        case clockFont = "clock_font"
        case scrollSpeedFps = "scroll_speed_fps"
        case scrollRepeatCount = "scroll_repeat_count"
        case bootCount = "boot_count"
        case divoomEmail = "divoom_email"
        case divoomPasswordSet = "divoom_password_set"
        case macAddress = "mac_address"
        case hostName = "hostname"
        case ipAddress = "ip_address"
        case hwVersion = "hw_version"
        case fwVersion = "fw_version"
        case hoursColorHex = "hours_color_hex"
        case minutesColorHex = "minutes_color_hex"
        case colonColorHex = "colon_color_hex"
        case bgColorHex = "bg_color_hex"
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
