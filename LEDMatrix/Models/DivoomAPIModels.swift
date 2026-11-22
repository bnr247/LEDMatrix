// Модели ответов Divoom API, используемые сетевым слоем приложения.
import Foundation

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
