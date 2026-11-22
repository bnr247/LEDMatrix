import Foundation
import SwiftUI

extension MatrixManager {
    func fetchSomeoneInfo(someOneUserId: Int) async -> Int? {
        do {
            let session = try await getValidDivoomSession()
            let url = URL(string: "https://appin.divoom-gz.com/GetSomeoneInfoV2")!
                
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
            let body: [String: Any] = [
                "Token": session.token,
                "Command": "GetSomeoneInfoV2",
                "UserId": session.userId,
                "SomeOneUserId": someOneUserId,
                "Language": "en"
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
            let (data, _) = try await URLSession.shared.data(for: request)
                
            struct UserInfoResponse: Codable {
                let ReturnCode: Int
                let IsFollow: Int?
            }
                
            let infoResponse = try JSONDecoder().decode(UserInfoResponse.self, from: data)
            return infoResponse.IsFollow
        } catch {
            print("⚠️ Ошибка получения информации о пользователе: \(error.localizedDescription)")
            return nil
        }
    }

    func toggleDivoomLike(galleryId: String, isLike: Int) async throws {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/GalleryLikeV2")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "IsLike": isLike,
            "Command": "GalleryLikeV2",
            "GalleryId": galleryId,
            "Type": 5,
            "Classify": 0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct LikeResponse: Codable {
            let ReturnCode: Int
            let ReturnMessage: String
        }
        
        let response = try JSONDecoder().decode(LikeResponse.self, from: data)
        
        if let _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.toggleDivoomLike(galleryId: galleryId, isLike: isLike)
        }) {
            return
        }
        
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage.isEmpty ? "Ошибка изменения лайка" : response.ReturnMessage])
        }
    }

    private func syncSomeoneInfo(someOneUserId: Int) async {
        do {
            let session = try await getValidDivoomSession()
            let url = URL(string: "https://appin.divoom-gz.com/GetSomeoneInfoV2")!
                
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
            let body: [String: Any] = [
                "Token": session.token,
                "Command": "GetSomeoneInfoV2",
                "UserId": session.userId,
                "SomeOneUserId": someOneUserId,
                "Language": "en"
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("⚠️ syncSomeoneInfo error: \(error.localizedDescription)")
        }
    }

    func toggleDivoomFollow(someOneUserId: Int, isFollow: Int) async throws {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/FollowExpertV2")!
            
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        let body: [String: Any] = [
            "UserId": session.userId,
            "IsFollow": isFollow,
            "SomeOneUserId": someOneUserId,
            "Token": session.token,
            "Command": "FollowExpertV2"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
        let (data, _) = try await URLSession.shared.data(for: request)
            
        struct FollowResponse: Codable {
            let ReturnCode: Int
            let ReturnMessage: String
        }
            
        let response = try JSONDecoder().decode(FollowResponse.self, from: data)
            
        if let _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.toggleDivoomFollow(someOneUserId: someOneUserId, isFollow: isFollow)
        }) {
            return
        }
            
        // Отправляем запрос синхронизации на бэкенд, но результаты игнорируем
        await syncSomeoneInfo(someOneUserId: someOneUserId)
            
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage.isEmpty ? "Ошибка подписки" : response.ReturnMessage])
        }
    }

    func addDivoomWatch(galleryId: String, classify: Int?) async {
        do {
            let session = try await getValidDivoomSession()
            let url = URL(string: "https://appin.divoom-gz.com/AddWatch")!
                
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
            let effectiveClassify = classify ?? 0
            let type = effectiveClassify > 0 ? 1 : 5
                
            let body: [String: Any] = [
                "Token": session.token,
                "Command": "AddWatch",
                "UserId": session.userId,
                "Type": type,
                "Classify": effectiveClassify,
                "GalleryId": galleryId
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
            let (data, _) = try await URLSession.shared.data(for: request)
                
            struct WatchResponse: Codable {
                let ReturnCode: Int
                let ReturnMessage: String?
            }
                
            if let response = try? JSONDecoder().decode(WatchResponse.self, from: data), response.ReturnCode == 11 || (response.ReturnMessage?.contains("Token is not match") == true) {
                _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage ?? "", retryBlock: {
                    try await self.addDivoomWatch(galleryId: galleryId, classify: classify)
                })
            }
        } catch {
            print("⚠️ AddWatch error: \(error.localizedDescription)")
        }
    }

    func fetchDivoomLikedImages(startNum: Int, endNum: Int, fileSort: Int = 1) async throws -> DivoomAlbumImageListResponse {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/GetMyLikeListV3")!
            
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "EndNum": endNum,
            "Command": "GetMyLikeListV3",
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
            try await self.fetchDivoomLikedImages(startNum: startNum, endNum: endNum, fileSort: fileSort)
        }) {
            return retryResult
        }
            
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
            
        return response
    }

    // MARK: - Поиск по тэгам

    func fetchDivoomTags(tagKey: String, startNum: Int = 1, endNum: Int = 30) async throws -> [DivoomTag] {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Tag/SearchTagMoreV2")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "TagKeyEn": "",
            "Command": "Tag/SearchTagMoreV2",
            "EndNum": endNum,
            "FileSize": 1,
            "StartNum": startNum,
            "TagKey": tagKey
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomTagResponse.self, from: data)

        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomTags(tagKey: tagKey, startNum: startNum, endNum: endNum)
        }) {
            return retryResult
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }

        return response.TagList ?? []
    }

    func fetchDivoomTagImages(tagName: String, startNum: Int, endNum: Int, fileSort: Int = 1, refreshIndex: Int = 0) async throws -> DivoomAlbumImageListResponse {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Tag/GetTagGalleryListV3")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "EndNum": endNum,
            "Command": "Tag/GetTagGalleryListV3",
            "Version": 19,
            "FileSize": 1,
            "FileType": 5,
            "StartNum": startNum,
            "RefreshIndex": refreshIndex,
            "FileSort": fileSort,
            "TagName": tagName
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)

        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomTagImages(tagName: tagName, startNum: startNum, endNum: endNum, fileSort: fileSort, refreshIndex: refreshIndex)
        }) {
            return retryResult
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }

        return response
    }

    /// POST /Tag/Follow с теми же полями, что ждёт API: Token, Command,
    /// UserId, IsFollow (1 — подписаться, 0 — отписаться) и TagName —
    /// имя тэга (из поискового запроса).

    func toggleDivoomTagFollow(tagName: String, isFollow: Int) async throws {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/Tag/Follow")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "TagName": tagName,
            "IsFollow": isFollow,
            "Command": "Tag/Follow"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct FollowTagResponse: Codable {
            let ReturnCode: Int
            let ReturnMessage: String
        }

        let response = try JSONDecoder().decode(FollowTagResponse.self, from: data)

        if let _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.toggleDivoomTagFollow(tagName: tagName, isFollow: isFollow)
        }) {
            return
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage.isEmpty ? "Ошибка подписки на тэг" : response.ReturnMessage])
        }
    }

    // MARK: - Поиск анимаций
}
