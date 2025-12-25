//
//  CampaignAPI.swift
//  PaylisherExample
//
//  Created by Paylisher SDK on 24.12.2025.
//

import Foundation

/// Backend campaign API ile iletişim için servis
enum CampaignAPI {

    /// Campaign keyName'e göre deeplink bilgilerini backend'den çeker
    /// - Parameter keyName: Campaign key (örn: "X7kdi5Yq9lTVOv46uHYtV")
    /// - Returns: Resolve edilmiş deeplink payload
    /// - Throws: Network veya decode hataları
    static func resolve(keyName: String) async throws -> ResolvedDeepLinkPayload {
        // Backend endpoint
        let urlString = "https://api.usepublisher.com/campaign/\(keyName)"

        guard let url = URL(string: urlString) else {
            throw CampaignAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        // Network isteği
        let (data, response) = try await URLSession.shared.data(for: request)

        // HTTP status kontrolü
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw CampaignAPIError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        // JSON decode
        let decoder = JSONDecoder()
        do {
            let payload = try decoder.decode(ResolvedDeepLinkPayload.self, from: data)
            return payload
        } catch {
            throw CampaignAPIError.decodingError(underlying: error)
        }
    }
}

// MARK: - Errors
enum CampaignAPIError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case decodingError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid campaign URL"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
