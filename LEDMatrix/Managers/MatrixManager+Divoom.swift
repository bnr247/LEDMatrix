//
//  MatrixManager+Divoom.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 30.10.2026.
//

import Foundation
import SwiftUI

// MARK: - Гибкий тип для ID (поддерживает и Int, и String от сервера)
enum DivoomID: Codable, Equatable {
    case int(Int)
    case string(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(DivoomID.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String for ID"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let val): try container.encode(val)
        case .string(let val): try container.encode(val)
        }
    }
    
    var stringValue: String {
        switch self {
        case .int(let val): return String(val)
        case .string(let val): return val
        }
    }
}

// MARK: - Модели данных Divoom API

struct DivoomLoginResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let UserId: DivoomID?
    let Token: Int?
}

struct DivoomAlbumResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let AlbumList: [DivoomAlbum]?
}

struct DivoomAlbum: Identifiable, Codable {
    var id: String { AlbumId.stringValue }
    let AlbumId: DivoomID
    let AlbumName: String
    let AlbumImageId: String
    let AlbumBigImageId: String
}

struct DivoomAlbumImageListResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let FileListNum: Int?
    let CurListNum: Int?
    let FileList: [DivoomFileItem]?
}

struct DivoomFileItem: Identifiable, Codable {
    var id: String {
        if let galleryId = GalleryId { return galleryId.stringValue }
        return FileId ?? UUID().uuidString
    }
    
    let GalleryId: DivoomID?
    let FileId: String?
    let FileName: String?
    let FileSize: Int?
    let FileUrl: String?
    let Content: String?
}

// MARK: - Расширение MatrixManager

extension MatrixManager {
    
    private static var divoomUserId: String? = nil
    private static var divoomToken: Int? = nil
    
    /// Авторизация в сервисах Divoom
    func divoomLogin() async throws -> (userId: String, token: Int) {
        let url = URL(string: "https://app.divoom-gz.com/UserLogin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "Email": "Styroz@gmail.com",
            "Password": "a0193d91907579cc71cd101515474ded"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Лог для отладки, если сервер вернет ошибку формата
        if let rawString = String(data: data, encoding: .utf8) {
            print("🌐 Divoom Login Response: \(rawString)")
        }
        
        let response = try JSONDecoder().decode(DivoomLoginResponse.self, from: data)
        
        guard response.ReturnCode == 0,
              let userIdObj = response.UserId,
              let token = response.Token else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage.isEmpty ? "Ошибка авторизации" : response.ReturnMessage])
        }
        
        let userId = userIdObj.stringValue
        MatrixManager.divoomUserId = userId
        MatrixManager.divoomToken = token
        return (userId, token)
    }
    
    /// Получение активной сессии (с авто-логином при отсутствии)
    private func getValidDivoomSession() async throws -> (userId: String, token: Int) {
        if let userId = MatrixManager.divoomUserId, let token = MatrixManager.divoomToken {
            return (userId, token)
        }
        return try await divoomLogin()
    }
    
    /// Запрос списка альбомов Divoom
    func fetchDivoomAlbums() async throws -> [DivoomAlbum] {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://app.divoom-gz.com/Discover/GetAlbumList")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "UserId": session.userId,
            "Token": String(session.token)
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let response = try JSONDecoder().decode(DivoomAlbumResponse.self, from: data)
        
        // Код 11: Token is not match -> сбрасываем сессию и повторяем запрос с новым логином
        if response.ReturnCode == 11 {
            MatrixManager.divoomUserId = nil
            MatrixManager.divoomToken = nil
            return try await fetchDivoomAlbums()
        }
        
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
        
        return response.AlbumList ?? []
    }
    
    /// Запрос списка элементов конкретного альбома Divoom (фильтруем по FileSize == 1)
    func fetchDivoomAlbumImages(albumId: String) async throws -> [DivoomFileItem] {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://app.divoom-gz.com/Discover/GetAlbumImageList")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "UserId": session.userId,
            "Token": session.token,
            "AlbumId": albumId,
            "StartNum": 1,
            "EndNum": 2000,
            "FileSize": 1,
            "FileType": 1,
            "FileSort": 0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)
        
        // Код 11: Token is not match -> повторный логин
        if response.ReturnCode == 11 {
            MatrixManager.divoomUserId = nil
            MatrixManager.divoomToken = nil
            return try await fetchDivoomAlbumImages(albumId: albumId)
        }
        
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
        
        // Фильтруем объекты со Strict FileSize == 1
        let filteredItems = (response.FileList ?? []).filter { $0.FileSize == 1 }
        return filteredItems
    }
}
