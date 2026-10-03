//
//  AvatarCacheManager.swift
//  SpeakIT
//
//  Two-level avatar cache architecture (Memory NSCache + On-Disk File Cache)
//  designed for instantaneous 120Hz rendering and offline availability.
//

import UIKit
import CryptoKit

final class AvatarCacheManager {
    static let shared = AvatarCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskQueue = DispatchQueue(label: "com.speakit.avatarcache.disk", qos: .background)
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
    
    private init() {
        // 1. Configure memory cache limits (up to 50 avatars, ~25MB memory budget)
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 25 * 1024 * 1024
        
        // 2. Resolve disk cache directory: <Caches>/UserAvatars/
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskCacheDirectory = cachesURL.appendingPathComponent("UserAvatars", isDirectory: true)
        
        // 3. Ensure disk cache directory exists
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Synchronous In-Memory Read (0ms latency for list / header rendering)
    func memoryImage(for urlString: String) -> UIImage? {
        let key = cacheKey(for: urlString) as NSString
        return memoryCache.object(forKey: key)
    }
    
    // MARK: - Full 2-Tier Load (Memory -> Disk -> Network)
    func loadImage(from urlString: String) async -> UIImage? {
        guard let cleanURLString = resolveValidURLString(urlString) else { return nil }
        let key = cacheKey(for: cleanURLString)
        
        // Tier 1: Memory
        if let memImage = memoryCache.object(forKey: key as NSString) {
            return memImage
        }
        
        // Tier 2: Disk Cache
        let diskURL = diskCacheDirectory.appendingPathComponent(key)
        if let diskData = try? Data(contentsOf: diskURL),
           let diskImage = UIImage(data: diskData) {
            // Re-populate memory cache
            memoryCache.setObject(diskImage, forKey: key as NSString, cost: diskData.count)
            return diskImage
        }
        
        // Tier 3: Network Fetch
        guard let url = URL(string: cleanURLString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                  let downloadedImage = UIImage(data: data) else {
                return nil
            }
            
            // Store to Memory
            memoryCache.setObject(downloadedImage, forKey: key as NSString, cost: data.count)
            
            // Store to Disk asynchronously
            diskQueue.async {
                try? data.write(to: diskURL, options: .atomic)
            }
            
            return downloadedImage
        } catch {
            return nil
        }
    }
    
    // MARK: - Store Image
    func storeImage(_ image: UIImage, for urlString: String) {
        guard let cleanURLString = resolveValidURLString(urlString) else { return }
        let key = cacheKey(for: cleanURLString)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        
        // Memory
        memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
        
        // Disk
        let diskURL = diskCacheDirectory.appendingPathComponent(key)
        diskQueue.async {
            try? data.write(to: diskURL, options: .atomic)
        }
    }
    
    // MARK: - Cache Invalidation
    func clearCache(for urlString: String) {
        let key = cacheKey(for: urlString)
        memoryCache.removeObject(forKey: key as NSString)
        
        let diskURL = diskCacheDirectory.appendingPathComponent(key)
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: diskURL)
        }
    }
    
    func clearAll() {
        memoryCache.removeAllObjects()
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.diskCacheDirectory)
            try? self.fileManager.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Helper Methods
    private func cacheKey(for urlString: String) -> String {
        let input = Data(urlString.utf8)
        let hash = SHA256.hash(data: input)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Resolves relative URLs (e.g. /uploads/avatars/...) against the API baseURL.
    private func resolveValidURLString(_ urlString: String) -> String? {
        var trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.contains("cdn-speakit-avatars.mohitur.com") {
            trimmed = trimmed.replacingOccurrences(of: "cdn-speakit-avatars.mohitur.com", with: "cdn-speakit-avatar.mohitur.com")
        }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        if trimmed.hasPrefix("/") {
            return "\(APIEndpoint.baseURL)\(trimmed)"
        }
        return "\(APIEndpoint.baseURL)/\(trimmed)"
    }
}
