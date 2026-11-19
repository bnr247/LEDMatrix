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
    private let internalUUID = UUID().uuidString
    
    var id: String {
        if let galleryId = GalleryId, !galleryId.isEmpty {
            return galleryId
        }
        if let fileId = FileId, !fileId.isEmpty {
            return fileId
        }
        return internalUUID
    }
    
    let GalleryId: String?
    let FileId: String?
    let FileName: String?
    let FileSize: Int?
    let FileType: Int?
    let FileUrl: String?
    let Content: String?
    let LikeCnt: Int?
    let CommentCnt: Int?
    let IsLike: Int?
    let UserHeaderId: String?
    let UserName: String?
    let UserId: Int?
    let IsFollow: Int?
    let Classify: Int?
    
    enum CodingKeys: String, CodingKey {
        case GalleryId, FileId, FileName, FileSize, FileType, FileUrl, Content, LikeCnt, CommentCnt, IsLike, UserName, UserHeaderId, UserId, IsFollow, Classify
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        FileId = try? container.decode(String.self, forKey: .FileId)
        FileName = try? container.decode(String.self, forKey: .FileName)
        FileSize = try? container.decode(Int.self, forKey: .FileSize)
        FileType = try? container.decode(Int.self, forKey: .FileType)
        FileUrl = try? container.decode(String.self, forKey: .FileUrl)
        Content = try? container.decode(String.self, forKey: .Content)
        LikeCnt = try? container.decode(Int.self, forKey: .LikeCnt)
        CommentCnt = try? container.decode(Int.self, forKey: .CommentCnt)
        IsLike = try? container.decode(Int.self, forKey: .IsLike)
        UserName = try? container.decode(String.self, forKey: .UserName)
        UserHeaderId = try? container.decode(String.self, forKey: .UserHeaderId)
        UserId = try? container.decode(Int.self, forKey: .UserId)
        Classify = try? container.decode(Int.self, forKey: .Classify)
        
        // Всеядный парсинг IsFollow (поддерживает Int, String и Bool)
        if let intVal = try? container.decode(Int.self, forKey: .IsFollow) {
            IsFollow = intVal
        } else if let str = try? container.decode(String.self, forKey: .IsFollow) {
            IsFollow = Int(str)
        } else if let b = try? container.decode(Bool.self, forKey: .IsFollow) {
            IsFollow = b ? 1 : 0
        } else {
            IsFollow = nil
        }
        
        if let str = try? container.decode(String.self, forKey: .GalleryId) {
            GalleryId = str
        } else if let intVal = try? container.decode(Int.self, forKey: .GalleryId) {
            GalleryId = String(intVal)
        } else {
            GalleryId = nil
        }
    }
}

struct DivoomUserAllInfoResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let GalleryMatchName: String?
}

/// Один тэг в результатах поиска. `GalleryList` содержит несколько превью
/// анимаций, которые Divoom отдаёт вместе с тэгом.
struct DivoomTag: Identifiable, Codable {
    var id: String { TagName }

    let TagName: String
    let FollowCnt: Int?
    let GalleryCnt: Int?
    let IsFollow: Int?
    let GalleryList: [DivoomFileItem]?
}

struct DivoomTagResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let TagList: [DivoomTag]?
}

/// Автор (эксперт) из GetExpertListV4.
struct DivoomExpert: Identifiable, Codable {
    let UserId: Int
    let NickName: String
    let HeadId: String?
    let FansCnt: Int?
    let Score: Int?
    let Level: Int?
    let IsFollow: Int?
    let FileList: [DivoomFileItem]?

    var id: Int { UserId }

    enum CodingKeys: String, CodingKey {
        case UserId, NickName, HeadId, FansCnt, Score, Level, IsFollow, FileList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        NickName = try container.decode(String.self, forKey: .NickName)
        HeadId = try? container.decode(String.self, forKey: .HeadId)
        FansCnt = try? container.decode(Int.self, forKey: .FansCnt)
        Score = try? container.decode(Int.self, forKey: .Score)
        Level = try? container.decode(Int.self, forKey: .Level)
        FileList = try? container.decode([DivoomFileItem].self, forKey: .FileList)

        if let intVal = try? container.decode(Int.self, forKey: .UserId) {
            UserId = intVal
        } else if let str = try? container.decode(String.self, forKey: .UserId) {
            UserId = Int(str) ?? 0
        } else {
            UserId = 0
        }

        if let intVal = try? container.decode(Int.self, forKey: .IsFollow) {
            IsFollow = intVal
        } else if let str = try? container.decode(String.self, forKey: .IsFollow) {
            IsFollow = Int(str)
        } else {
            IsFollow = nil
        }
    }
}

struct DivoomExpertListResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let ExpertList: [DivoomExpert]?
    let CurListNum: Int?
}

/// Информация о пользователе из GetSomeoneInfoV2.
struct DivoomSomeoneInfo: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let NickName: String?
    let HeadId: String?
    let Score: Int?
    let LikeCnt: Int?
    let FansCnt: Int?
    let Level: Int?
    let IsFollow: Int?
}

struct DivoomPlaylistResponse: Codable {
    let ReturnCode: Int
    let ReturnMessage: String
    let PlayList: [DivoomPlaylist]?
}

struct DivoomPlaylist: Identifiable, Codable {
    var id: Int {
        PlayId
    }

    let PlayId: Int
    let Name: String
    let Describe: String?
    let CoverFileId: String?
    let Count: Int?
    let HideFlag: Int?
    let AddFlag: Int?
    
    enum CodingKeys: String, CodingKey {
        case PlayId, Name, Describe, CoverFileId, Count, HideFlag, AddFlag
    }
}

extension MatrixManager {
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
        
        settings.divoomUserId = userId
        settings.divoomToken = token
        
        try? await sendCommand(endpoint: "cmd", params: [
            "divoom_user_id": userId,
            "divoom_token": token
        ])
        
        return (userId, token)
    }
    
    private func getValidDivoomSession() async throws -> (userId: Int, token: Int) {
        if settings.divoomUserId != 0, settings.divoomToken != 0 {
            return (settings.divoomUserId, settings.divoomToken)
        }
        return try await divoomLogin()
    }
    
    private func handleTokenMismatchError<T>(responseCode: Int, responseMessage: String, retryBlock: () async throws -> T) async throws -> T? {
        if responseCode == 11 || responseMessage.contains("Token is not match") {
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
