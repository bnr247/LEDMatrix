import Foundation
import SwiftUI

extension MatrixManager {
    func fetchDivoomPlaylists(startNum: Int, endNum: Int) async throws -> [DivoomPlaylist] {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Playlist/GetMyList")!
            
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        let body: [String: Any] = [
            "Token": session.token,
            "Command": "Playlist/GetMyList",
            "UserId": session.userId,
            "StartNum": startNum,
            "EndNum": endNum
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomPlaylistResponse.self, from: data)
            
        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomPlaylists(startNum: startNum, endNum: endNum)
        }) {
            return retryResult
        }
        
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
        
        return response.PlayList ?? []
    }

    func fetchDivoomPlaylistImages(playId: Int, startNum: Int, endNum: Int, fileSort: Int = 1) async throws -> DivoomAlbumImageListResponse {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Playlist/GetMyImageList")!
                
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "PlayId": playId,
            "Command": "Playlist/GetMyImageList",
            "EndNum": endNum,
            "Version": 19,
            "FileSize": 1,
            "FileType": 5,
            "StartNum": startNum,
            "RefreshIndex": 0,
            "FileSort": fileSort
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)
                
        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomPlaylistImages(playId: playId, startNum: startNum, endNum: endNum, fileSort: fileSort)
        }) {
            return retryResult
        }
                
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
                
        return response
    }

    func createDivoomPlaylist(name: String) async throws {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Playlist/NewList")!
            
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        let body: [String: Any] = [
            "Token": session.token,
            "Command": "Playlist/NewList",
            "UserId": session.userId,
            "Name": name
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
        let (data, _) = try await URLSession.shared.data(for: request)
            
        struct NewListResponse: Codable {
            let ReturnCode: Int
            let ReturnMessage: String
        }
            
        let response = try JSONDecoder().decode(NewListResponse.self, from: data)
            
        if let _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.createDivoomPlaylist(name: name)
        }) {
            return
        }
            
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage.isEmpty ? "Ошибка создания плейлиста" : response.ReturnMessage])
        }
    }

    func deleteDivoomPlaylist(playId: Int) async throws {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Playlist/DeleteList")!
            
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        let body: [String: Any] = [
            "Token": session.token,
            "Command": "Playlist/DeleteList",
            "UserId": session.userId,
            "PlayId": playId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
        let (data, _) = try await URLSession.shared.data(for: request)
            
        struct DeleteListResponse: Codable {
            let ReturnCode: Int
            let ReturnMessage: String
        }
            
        let response = try JSONDecoder().decode(DeleteListResponse.self, from: data)
            
        if let _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.deleteDivoomPlaylist(playId: playId)
        }) {
            return
        }
            
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage.isEmpty ? "Ошибка удаления плейлиста" : response.ReturnMessage])
        }
    }
    
    /// Запрос актуальной информации о пользователе для получения реального статуса подписки

    func addDivoomImageToPlaylist(playId: Int, galleryId: String) async throws {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Playlist/AddImageToList")!
            
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        let body: [String: Any] = [
            "Token": session.token,
            "Command": "Playlist/AddImageToList",
            "UserId": session.userId,
            "PlayId": playId,
            "GalleryId": galleryId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
        let (data, _) = try await URLSession.shared.data(for: request)
            
        struct AddImageResponse: Codable {
            let ReturnCode: Int
            let ReturnMessage: String?
        }
            
        let response = try JSONDecoder().decode(AddImageResponse.self, from: data)
            
        if let _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage ?? "", retryBlock: {
            try await self.addDivoomImageToPlaylist(playId: playId, galleryId: galleryId)
        }) {
            return
        }
            
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage ?? "Ошибка добавления в плейлист"])
        }
    }
}
