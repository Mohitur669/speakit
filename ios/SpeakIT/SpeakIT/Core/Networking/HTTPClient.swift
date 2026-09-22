//
//  HTTPClient.swift
//  SpeakIT
//
//  Typed network client with automatic Bearer token injection and 401 eviction interception.
//

import Foundation

extension Notification.Name {
    static let speakitSessionInvalidated = Notification.Name("speakitSessionInvalidated")
}

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case unauthorized
    case forbidden
    case decodingError(Error)
    case missingData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server endpoint URL."
        case .networkError(let error):
            return "Network connection error: \(error.localizedDescription)"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You do not have permission to access this feature. Please upgrade your plan."
        case .decodingError:
            return "Failed to parse data received from the server."
        case .missingData:
            return "No data received from the server."
        }
    }
}

final class HTTPClient {
    static let shared = HTTPClient()
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Standard JSON Request
    func request<T: Decodable>(_ endpoint: APIEndpoint, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = endpoint.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = KeychainHelper.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.missingData
        }
        
        if httpResponse.statusCode == 401 {
            NotificationCenter.default.post(name: .speakitSessionInvalidated, object: nil)
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 403 {
            throw APIError.forbidden
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Binary Audio Stream Request (for TTS)
    func downloadBinary(_ endpoint: APIEndpoint, body: Data) async throws -> Data {
        guard let url = endpoint.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        
        if let token = KeychainHelper.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.missingData
        }
        
        if httpResponse.statusCode == 401 {
            NotificationCenter.default.post(name: .speakitSessionInvalidated, object: nil)
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 403 {
            throw APIError.forbidden
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Synthesis failed"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        return data
    }
    
    // MARK: - Multipart Form Data Upload (for STT)
    func uploadMultipart<T: Decodable>(_ endpoint: APIEndpoint, fileData: Data, fileName: String, mimeType: String, fieldName: String) async throws -> T {
        guard let url = endpoint.url else { throw APIError.invalidURL }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = KeychainHelper.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.missingData
        }
        
        if httpResponse.statusCode == 401 {
            NotificationCenter.default.post(name: .speakitSessionInvalidated, object: nil)
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 403 {
            throw APIError.forbidden
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Upload failed"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
