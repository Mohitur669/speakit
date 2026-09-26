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
        case .serverError(_, let msg):
            return msg.isEmpty ? "An unexpected server error occurred." : msg
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

struct EmptyResponse: Codable {
    public init() {}
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
            let cleanMsg = HTTPClient.extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: cleanMsg)
        }
        
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            if let empty = EmptyResponse() as? T {
                return empty
            }
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
            let cleanMsg = HTTPClient.extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: cleanMsg)
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
        
        // Sanitize fileName to prevent backend double-extension security rejections
        let safeFileName: String
        let ns = fileName as NSString
        let ext = ns.pathExtension
        if !ext.isEmpty {
            let base = ns.deletingPathExtension.replacingOccurrences(of: ".", with: "_")
            safeFileName = "\(base).\(ext)"
        } else {
            safeFileName = fileName
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(safeFileName)\"\r\n".data(using: .utf8)!)
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
            let cleanMsg = HTTPClient.extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: cleanMsg)
        }
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - JSON Error Extraction
    static func extractErrorMessage(from data: Data, statusCode: Int) -> String {
        struct ErrorEnvelope: Decodable {
            let message: String?
            let error: String?
            let detail: String?
        }
        
        if let decoded = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            if let msg = decoded.message, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return msg.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let err = decoded.error, !err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return err.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let det = decoded.detail, !det.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return det.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            if !raw.hasPrefix("<") && !raw.hasPrefix("{") && raw.count < 200 {
                return raw
            }
        }
        
        switch statusCode {
        case 400: return "Invalid request. Please check your details and try again."
        case 401: return "Authentication required. Please sign in again."
        case 403: return "Access denied. You do not have permission for this action."
        case 404: return "Requested resource was not found."
        case 429: return "Rate limit exceeded. Please wait a moment and try again."
        case 500...599: return "Server error. Please try again shortly."
        default: return "An unexpected error occurred."
        }
    }
}
