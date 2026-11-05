import Foundation
import SwiftUI

struct DivoomLoginResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let UserId: Int?
    let Token: Int?
    
    enum CodingKeys: String, CodingKey {
        case ReturnCode, ReturnMessage, UserId, Token
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ReturnCode = try container.decode(Int.self, forKey: .ReturnCode)
        ReturnMessage = try container.decode(String.self, forKey: .ReturnMessage)
        Token = try? container.decode(Int.self, forKey: .Token)
        
        if let str = try? container.decode(String.self, forKey: .UserId) {
            UserId = Int(str)
        } else if let intVal = try? container.decode(Int.self, forKey: .UserId) {
            UserId = intVal
        } else {
            UserId = nil
        }
    }
}

struct DivoomAlbumResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let AlbumList: [DivoomAlbum]?
}

struct DivoomAlbum: Identifiable, Codable {
    var id: String {
        AlbumId
    }

    let AlbumId: String
    let AlbumName: String
    let AlbumImageId: String
    let AlbumBigImageId: String
    
    enum CodingKeys: String, CodingKey {
        case AlbumId, AlbumName, AlbumImageId, AlbumBigImageId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        AlbumName = try container.decode(String.self, forKey: .AlbumName)
        AlbumImageId = try container.decode(String.self, forKey: .AlbumImageId)
        AlbumBigImageId = try container.decode(String.self, forKey: .AlbumBigImageId)
        
        if let str = try? container.decode(String.self, forKey: .AlbumId) {
            AlbumId = str
        } else if let intVal = try? container.decode(Int.self, forKey: .AlbumId) {
            AlbumId = String(intVal)
        } else {
            AlbumId = ""
        }
    }
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
        if let galleryId = GalleryId, !galleryId.isEmpty {
            return galleryId
        }
        return FileId ?? UUID().uuidString
    }
    
    let GalleryId: String?
    let FileId: String?
    let FileName: String?
    let FileSize: Int?
    let FileType: Int?
    let FileUrl: String?
    let Content: String?
    
    enum CodingKeys: String, CodingKey {
        case GalleryId, FileId, FileName, FileSize, FileType, FileUrl, Content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        FileId = try? container.decode(String.self, forKey: .FileId)
        FileName = try? container.decode(String.self, forKey: .FileName)
        FileSize = try? container.decode(Int.self, forKey: .FileSize)
        FileType = try? container.decode(Int.self, forKey: .FileType)
        FileUrl = try? container.decode(String.self, forKey: .FileUrl)
        Content = try? container.decode(String.self, forKey: .Content)
        
        if let str = try? container.decode(String.self, forKey: .GalleryId) {
            GalleryId = str
        } else if let intVal = try? container.decode(Int.self, forKey: .GalleryId) {
            GalleryId = String(intVal)
        } else {
            GalleryId = nil
        }
    }
}

extension MatrixManager {
    /// Выполняет логин в Divoom, сохраняет учетки и отправляет их на устройство
    func divoomLogin() async throws -> (userId: Int, token: Int) {
        let url = URL(string: "https://appin.divoom-gz.com/UserLogin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "Email": settings.divoomEmail,
            "Password": settings.divoomPassword
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomLoginResponse.self, from: data)
        
        guard response.ReturnCode == 0,
              let userId = response.UserId,
              let token = response.Token
        else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage.isEmpty ? "Ошибка авторизации" : response.ReturnMessage])
        }
        
        // Обновляем локальные настройки в памяти
        settings.divoomUserId = userId
        settings.divoomToken = token
        
        print("userId  \(userId) token  \(token)")
        
        // Отправляем полученные divoom_user_id и divoom_token на /cmd
        try? await sendCommand(endpoint: "cmd", params: [
            "divoom_user_id": userId,
            "divoom_token": token
        ])
        
        return (userId, token)
    }
    
    /// Получение валидной сессии: берем из settings, если пусто — логинимся
    private func getValidDivoomSession() async throws -> (userId: Int, token: Int) {
        if settings.divoomUserId != 0, settings.divoomToken != 0 {
            return (settings.divoomUserId, settings.divoomToken)
        }
        return try await divoomLogin()
    }
    
    /// Обработка ответов с проверкой ReturnCode == 11 ("Token is not match")
    private func handleTokenMismatchError<T>(responseCode: Int, responseMessage: String, retryBlock: () async throws -> T) async throws -> T? {
        if responseCode == 11 || responseMessage.contains("Token is not match") {
            // Сбрасываем локальные данные и пробуем перелогиниться
            settings.divoomUserId = 0
            settings.divoomToken = 0
            _ = try await divoomLogin()
            return try await retryBlock()
        }
        return nil
    }
    
    func fetchDivoomAlbums() async throws -> [DivoomAlbum] {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://app.divoom-gz.com/Discover/GetAlbumList")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Int] = [
            "UserId": session.userId,
            "Token": session.token
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumResponse.self, from: data)
        
        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomAlbums()
        }) {
            return retryResult
        }
        
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
        
        return response.AlbumList ?? []
    }
    
    func fetchDivoomAlbumImages(albumId: String, startNum: Int, endNum: Int, refreshIndex: Int) async throws -> DivoomAlbumImageListResponse {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Discover/GetAlbumImageListV3")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "UserId": session.userId,
            "Token": session.token,
            "Command": "Discover/GetAlbumImageListV3",
            "Version": 19,
            "AlbumId": albumId,
            "StartNum": startNum,
            "EndNum": endNum,
            "RefreshIndex": refreshIndex,
            "FileSize": 1,
            "FileType": 5,
            "FileSort": 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)
        
        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomAlbumImages(albumId: albumId, startNum: startNum, endNum: endNum, refreshIndex: refreshIndex)
        }) {
            return retryResult
        }
        
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
        
        return response
    }
    
    func fetchDivoomCategoryImages(categoryId: Int, startNum: Int, endNum: Int, refreshIndex: Int) async throws -> DivoomAlbumImageListResponse {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/GetCategoryFileListV2")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "EndNum": endNum,
            "Command": "GetCategoryFileListV2",
            "Version": 19,
            "FileSize": 1,
            "FileType": 5,
            "StartNum": startNum,
            "RefreshIndex": refreshIndex,
            "Classify": categoryId,
            "FileSort": 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)
        
        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomCategoryImages(categoryId: categoryId, startNum: startNum, endNum: endNum, refreshIndex: refreshIndex)
        }) {
            return retryResult
        }
        
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
        
        return response
    }
}
