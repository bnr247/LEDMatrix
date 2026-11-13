import Foundation

enum AnimationType: Hashable {
    case standard (sortOrder: Int)
    case category(id: Int, sortOrder: Int)
    case album(id: Int, sortOrder: Int)
    case playlist(id: Int, sortOrder: Int)
    case likes (sortOrder: Int)
    
    var typeKey: Int {
        switch self {
        case .standard: return 0
        case .category: return 1
        case .album: return 2
        case .playlist: return 3
        case .likes: return 4
        }
    }
    
    var id: Int? {
        switch self {
        case .category(let id, _), .album(let id, _), .playlist(let id, _): return id
        case .standard, .likes: return nil
        }
    }
    
    var sortOrder: Int? {
        switch self {
        case .category(_, let sortOrder), .album(_, let sortOrder), .playlist(_, let sortOrder): return sortOrder
        case .standard(let sortOrder), .likes(let sortOrder): return sortOrder
        }
    }
    
    var parameters: [String: Any] {
        var params: [String: Any] = ["animation_type": typeKey]
        if let id = id {
            params["id"] = id
        }
        if let sortOrder = sortOrder {
            params["animation_sort_order"] = sortOrder
        }
        return params
    }
}
