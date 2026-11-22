import Foundation
import SwiftUI

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

    func getValidDivoomSession() async throws -> (userId: Int, token: Int) {
        if settings.divoomUserId != 0, settings.divoomToken != 0 {
            return (settings.divoomUserId, settings.divoomToken)
        }
        return try await divoomLogin()
    }

    func handleTokenMismatchError<T>(responseCode: Int, responseMessage: String, retryBlock: () async throws -> T) async throws -> T? {
        if responseCode == 11 || responseMessage.contains("Token is not match") {
            settings.divoomUserId = 0
            settings.divoomToken = 0
            _ = try await divoomLogin()
            return try await retryBlock()
        }
        return nil
    }
}
