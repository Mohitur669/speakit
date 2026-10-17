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
    case emailNotVerified(email: String)
    case decodingError(Error)
    case missingData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to connect to service. Please check your internet connection."
        case .networkError(let error):
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    return "No internet connection. Please check your network settings."
                case NSURLErrorTimedOut:
                    return "Request timed out. Please check your connection and try again."
                case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                    return "Cannot reach the server. Please try again in a few moments."
                default:
                    return "Network connection issue. Please check your internet connection."
                }
            }
            return HTTPClient.sanitizeUserFacingMessage(error.localizedDescription)
        case .serverError(let statusCode, let msg):
            let clean = HTTPClient.sanitizeUserFacingMessage(msg)
            return clean.isEmpty ? HTTPClient.defaultMessage(for: statusCode) : clean
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You do not have permission to access this feature. Please upgrade your plan."
        case .emailNotVerified(let email):
            return email.isEmpty
                ? "Your email address is not verified. Please verify your account."
                : "Please verify your email address (\(email)) to sign in."
        case .decodingError:
            return "Received an unexpected response from the server. Please try again."
        case .missingData:
            return "No data received from the server. Please try again."
        }
    }
}

struct EmptyResponse: Codable {
    public init() {}
}

final class HTTPClient {
    static let shared = HTTPClient()
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        // Enforce HTTP Keep-Alive header and persistent connection reuse
        configuration.httpAdditionalHeaders = [
            "Connection": "keep-alive"
        ]
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Standard JSON Request
    func request<T: Decodable>(_ endpoint: APIEndpoint, method: String = "GET", body: Data? = nil, headers: [String: String]? = nil) async throws -> T {
        guard let url = endpoint.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let headers = headers {
            for (headerField, value) in headers {
                request.setValue(value, forHTTPHeaderField: headerField)
            }
        }
        
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
            if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                let errCode = (dict["error"] as? String) ?? ""
                if errCode == "EMAIL_NOT_VERIFIED" {
                    let email = (dict["message"] as? String) ?? ""
                    throw APIError.emailNotVerified(email: email)
                }
            }
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
    
    // MARK: - Plain Text Response Request
    func requestString(_ endpoint: APIEndpoint, method: String = "GET", body: Data? = nil) async throws -> String {
        guard let url = endpoint.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        return String(data: data, encoding: .utf8) ?? "Success"
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
    
    // MARK: - Binary Audio Stream Request via GET (for History Audio Playback & Cloudflare R2 CDN)
    func downloadBinaryGet(_ endpoint: APIEndpoint) async throws -> Data {
        guard let url = endpoint.url else { throw APIError.invalidURL }
        return try await downloadBinaryFromURL(url)
    }
    
    func downloadBinaryFromURL(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("SpeakIT-iOS/1.0 (Apple; iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("audio/mpeg, audio/*;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        
        // Only attach Authorization Bearer token if querying our own backend API
        if let token = KeychainHelper.shared.getToken(), url.absoluteString.contains("/api/") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        
        return data
    }
    
    // MARK: - Multipart Form Data Upload (for STT and Avatars)
    func uploadMultipart<T: Decodable>(
        _ endpoint: APIEndpoint,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file",
        additionalFields: [String: String]? = nil
    ) async throws -> T {
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
        if let fields = additionalFields {
            for (key, val) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(val)\r\n".data(using: .utf8)!)
            }
        }
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
    
    // MARK: - JSON Error Extraction & Human-Friendly Message Sanitization
    static func extractErrorMessage(from data: Data, statusCode: Int) -> String {
        // 1. Try decoding structured Spring / SaaS error response
        struct SpringValidationError: Decodable {
            let field: String?
            let defaultMessage: String?
        }
        
        struct DetailedErrorEnvelope: Decodable {
            let message: String?
            let error: String?
            let detail: String?
            let error_description: String?
            let validationErrors: [String: String]?
            let errors: [SpringValidationError]?
        }
        
        if let decoded = try? JSONDecoder().decode(DetailedErrorEnvelope.self, from: data) {
            // Check for explicit field validation error map (e.g. ApiErrorResponse)
            if let validationErrors = decoded.validationErrors, !validationErrors.isEmpty {
                let messages = validationErrors.values.filter { !$0.isEmpty }
                if !messages.isEmpty {
                    return sanitizeUserFacingMessage(messages.joined(separator: ". "))
                }
            }
            
            // Check for Spring default errors array
            if let errorsList = decoded.errors, !errorsList.isEmpty {
                let messages = errorsList.compactMap { $0.defaultMessage }.filter { !$0.isEmpty }
                if !messages.isEmpty {
                    return sanitizeUserFacingMessage(messages.joined(separator: ". "))
                }
            }
            
            // Check message field
            if let msg = decoded.message, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = sanitizeUserFacingMessage(msg)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
            
            // Check error_description field (OAuth / Auth standards)
            if let errDesc = decoded.error_description, !errDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = sanitizeUserFacingMessage(errDesc)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
            
            // Check detail field
            if let det = decoded.detail, !det.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = sanitizeUserFacingMessage(det)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
            
            // Check error field if meaningful (and not generic "Bad Request")
            if let err = decoded.error, !err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = err.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased() != "bad request" && trimmed.lowercased() != "internal server error" {
                    let cleaned = sanitizeUserFacingMessage(trimmed)
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }
            }
        }
        
        // 2. Try parsing as generic JSON dictionary if structured decoding didn't catch it
        if let jsonDict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let msg = jsonDict["message"] as? String, !msg.isEmpty {
                let cleaned = sanitizeUserFacingMessage(msg)
                if !cleaned.isEmpty { return cleaned }
            }
            if let err = jsonDict["error"] as? String, !err.isEmpty && err.lowercased() != "bad request" {
                let cleaned = sanitizeUserFacingMessage(err)
                if !cleaned.isEmpty { return cleaned }
            }
            if let errs = jsonDict["errors"] as? [String: String], !errs.isEmpty {
                let joined = errs.values.joined(separator: ". ")
                let cleaned = sanitizeUserFacingMessage(joined)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        
        // 3. Check for plain text response (if not JSON or HTML)
        if let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            if !raw.hasPrefix("<") && !raw.hasPrefix("{") && !raw.hasPrefix("[") && !raw.contains("\"timestamp\":") && raw.count < 180 {
                return sanitizeUserFacingMessage(raw)
            }
        }
        
        // 4. Clean status code defaults
        return defaultMessage(for: statusCode)
    }
    
    // MARK: - Sanitize Any Error Text to Prevent Raw JSON or Exception Stacks
    static func sanitizeUserFacingMessage(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If message is or contains JSON, try extracting inner message
        if text.contains("{") && text.contains("}") {
            if let startIdx = text.firstIndex(of: "{"),
               let endIdx = text.lastIndex(of: "}") {
                let jsonSubstring = String(text[startIdx...endIdx])
                if let jsonData = jsonSubstring.data(using: .utf8),
                   let dict = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any] {
                    if let innerMsg = dict["message"] as? String, !innerMsg.isEmpty {
                        return sanitizeUserFacingMessage(innerMsg)
                    }
                    if let innerErr = dict["error"] as? String, !innerErr.isEmpty {
                        return sanitizeUserFacingMessage(innerErr)
                    }
                }
            }
            // If it could not be cleanly extracted, strip JSON braces or return clean message
            text = text.replacingOccurrences(of: "\\{[^}]*\\}", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Handle Spring Validation failed message wrapper
        if text.contains("default message [") {
            let components = text.components(separatedBy: "default message [")
            if components.count > 1, let lastPart = components.last?.components(separatedBy: "]").first, !lastPart.isEmpty {
                return lastPart.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove technical Java exception prefixes
        let techPrefixes = [
            "org.springframework.",
            "jakarta.validation.",
            "java.lang.",
            "com.speakit.",
            "ResponseStatusException:",
            "BadCredentialsException:",
            "IllegalArgumentException:",
            "IllegalStateException:"
        ]
        for prefix in techPrefixes {
            if let range = text.range(of: prefix) {
                text = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If remaining string starts with colon or dash, trim it
        while text.hasPrefix(":") || text.hasPrefix("-") || text.hasPrefix(" ") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // If empty or still has JSON fragments, provide polite fallback
        if text.isEmpty || text.hasPrefix("{") || text.hasPrefix("[") || text.contains("\"timestamp\"") {
            return "Unable to complete request. Please verify your details and try again."
        }
        
        // Clean up common technical phrasing
        if text.lowercased().contains("bad credentials") {
            return "Incorrect password or username. Please check your credentials and try again."
        }
        if text.lowercased().contains("jwt expired") || text.lowercased().contains("token expired") {
            return "Your session has expired. Please sign in again."
        }
        if text.lowercased().contains("connection refused") || text.lowercased().contains("timed out") {
            return "Unable to connect to the server. Please check your connection."
        }
        
        return text
    }
    
    static func defaultMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 400: return "Invalid request details. Please check your information and try again."
        case 401: return "Authentication required. Please sign in again."
        case 403: return "Access restricted. You do not have permission for this action."
        case 404: return "Requested resource was not found."
        case 409: return "This item or information already exists."
        case 422: return "Unable to process the submitted data. Please review and try again."
        case 429: return "Rate limit exceeded. Please wait a moment and try again."
        case 500...599: return "Our servers are temporarily experiencing issues. Please try again shortly."
        default: return "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Safe Human-Facing Error Extension
extension Error {
    var userFriendlyMessage: String {
        if let apiError = self as? APIError {
            return apiError.errorDescription ?? "An unexpected error occurred."
        }
        return HTTPClient.sanitizeUserFacingMessage(self.localizedDescription)
    }
}
