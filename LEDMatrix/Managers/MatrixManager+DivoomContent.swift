import Foundation
import SwiftUI

extension MatrixManager {
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

    func fetchDivoomAlbumImages(albumId: String, startNum: Int, endNum: Int, fileSort: Int = 1, refreshIndex: Int = 0) async throws -> DivoomAlbumImageListResponse {
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
            "FileSort": fileSort
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)
            
        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomAlbumImages(albumId: albumId, startNum: startNum, endNum: endNum, fileSort: fileSort, refreshIndex: refreshIndex)
        }) {
            return retryResult
        }
            
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
            
        return response
    }

    func fetchDivoomCategoryImages(categoryId: Int, startNum: Int, endNum: Int, fileSort: Int = 1, refreshIndex: Int = 0) async throws -> DivoomAlbumImageListResponse {
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
            "FileSort": fileSort
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)
            
        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomCategoryImages(categoryId: categoryId, startNum: startNum, endNum: endNum, fileSort: fileSort, refreshIndex: refreshIndex)
        }) {
            return retryResult
        }
            
        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }
            
        return response
    }
    
    /// Имя праздничной/конкурсной категории Divoom. Приложение показывает его
    /// на третьей вкладке в категориях; при ошибке экран подставляет Contest.

    func fetchDivoomGalleryMatchName() async throws -> String? {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/GetUserAllInfo")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "Language": "en",
            "Command": "GetUserAllInfo",
            "NotUseIpFlag": 1,
            "CountryISOCode": "RU",
            "TimeZone": "+3"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomUserAllInfoResponse.self, from: data)

        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomGalleryMatchName()
        }) {
            return retryResult
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }

        return response.GalleryMatchName
    }

    func searchDivoomAnimations(keywords: String, startNum: Int, endNum: Int, fileSort: Int = 1) async throws -> DivoomAlbumImageListResponse {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/SearchGalleryV3")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Version": 19,
            "UserId": session.userId,
            "EndNum": endNum,
            "Keywords": keywords,
            "FileType": 5,
            "FileSort": fileSort,
            "StartNum": startNum,
            "Command": "SearchGalleryV3",
            "Token": session.token,
            "FileSize": 1,
            "RefreshIndex": 1,
            "KeywordsEn": ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)

        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.searchDivoomAnimations(keywords: keywords, startNum: startNum, endNum: endNum, fileSort: fileSort)
        }) {
            return retryResult
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }

        return response
    }

    // MARK: - Авторы

    func fetchDivoomExperts(startNum: Int, endNum: Int) async throws -> DivoomExpertListResponse {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/GetExpertListV4")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "EndNum": endNum,
            "Command": "GetExpertListV4",
            "Language": "en",
            "Version": 19,
            "FileSize": 1,
            "FileType": 5,
            "StartNum": startNum,
            "RefreshIndex": 0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomExpertListResponse.self, from: data)

        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomExperts(startNum: startNum, endNum: endNum)
        }) {
            return retryResult
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }

        return response
    }

    func fetchDivoomSomeoneInfo(userId: Int) async throws -> DivoomSomeoneInfo {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/GetSomeoneInfoV2")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Token": session.token,
            "Command": "GetSomeoneInfoV2",
            "UserId": session.userId,
            "SomeOneUserId": userId,
            "Language": "en"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomSomeoneInfo.self, from: data)

        if let _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomSomeoneInfo(userId: userId)
        }) {
            return response
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }

        return response
    }

    func fetchDivoomSomeoneImages(userId: Int, startNum: Int, endNum: Int, fileSort: Int = 1) async throws -> DivoomAlbumImageListResponse {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/GetSomeoneListV3")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Token": session.token,
            "UserId": session.userId,
            "EndNum": endNum,
            "Command": "GetSomeoneListV3",
            "Version": 19,
            "SomeOneUserId": userId,
            "FileType": 5,
            "FileSize": 1,
            "StartNum": startNum,
            "RefreshIndex": 0,
            "FileSort": fileSort
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DivoomAlbumImageListResponse.self, from: data)

        if let retryResult = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.fetchDivoomSomeoneImages(userId: userId, startNum: startNum, endNum: endNum, fileSort: fileSort)
        }) {
            return retryResult
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage])
        }

        return response
    }

    /// POST /FollowExpertV2: IsFollow 1 — подписаться, 0 — отписаться.

    func toggleDivoomExpertFollow(userId: Int, isFollow: Int) async throws {
        let session = try await getValidDivoomSession()
        let url = URL(string: "https://appin.divoom-gz.com/FollowExpertV2")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Token": session.token,
            "Command": "FollowExpertV2",
            "UserId": session.userId,
            "SomeOneUserId": userId,
            "IsFollow": isFollow
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct FollowExpertResponse: Codable {
            let ReturnCode: Int
            let ReturnMessage: String
        }

        let response = try JSONDecoder().decode(FollowExpertResponse.self, from: data)

        if let _ = try await handleTokenMismatchError(responseCode: response.ReturnCode, responseMessage: response.ReturnMessage, retryBlock: {
            try await self.toggleDivoomExpertFollow(userId: userId, isFollow: isFollow)
        }) {
            return
        }

        guard response.ReturnCode == 0 else {
            throw NSError(domain: "DivoomAPI", code: response.ReturnCode, userInfo: [NSLocalizedDescriptionKey: response.ReturnMessage.isEmpty ? "Ошибка подписки на автора" : response.ReturnMessage])
        }
    }
}
