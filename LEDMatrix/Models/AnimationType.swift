import Foundation

enum AnimationType: Hashable {
    case category(id: Int)
    case album(id: Int)
    case standard
    
    var typeKey: String {
        switch self {
        case .category: return "category"
        case .album: return "album"
        case .standard: return "standard"
        }
    }
    
    var id: Int? {
        switch self {
        case .category(let id), .album(let id): return id
        case .standard: return nil
        }
    }
    
    var parameters: [String: Any] {
        var params: [String: Any] = ["animation_type": typeKey]
        if let id = id {
            params["id"] = id
        }
        return params
    }
}
