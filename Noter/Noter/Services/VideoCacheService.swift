import Foundation

/// Service for caching rendered videos locally
class VideoCacheService {
    static let shared = VideoCacheService()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        // Create cache directory in app's Documents folder
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("VideoCache", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Cache Management

    /// Cache a video file and return its new permanent location
    func cacheVideo(from temporaryURL: URL) throws -> URL {
        let fileName = "\(UUID().uuidString).mp4"
        let destinationURL = cacheDirectory.appendingPathComponent(fileName)

        // Copy from temporary location to cache
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: temporaryURL, to: destinationURL)

        return destinationURL
    }

    /// Get a cached video by its identifier
    func getCachedVideo(identifier: String) -> URL? {
        let videoURL = cacheDirectory.appendingPathComponent("\(identifier).mp4")

        guard fileManager.fileExists(atPath: videoURL.path) else {
            return nil
        }

        return videoURL
    }

    /// Check if a video is cached
    func isCached(identifier: String) -> Bool {
        let videoURL = cacheDirectory.appendingPathComponent("\(identifier).mp4")
        return fileManager.fileExists(atPath: videoURL.path)
    }

    /// Delete a specific cached video
    func deleteCachedVideo(identifier: String) throws {
        let videoURL = cacheDirectory.appendingPathComponent("\(identifier).mp4")

        guard fileManager.fileExists(atPath: videoURL.path) else {
            return
        }

        try fileManager.removeItem(at: videoURL)
    }

    /// Get list of all cached videos
    func getAllCachedVideos() -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { $0.pathExtension == "mp4" }
    }

    /// Get total size of video cache in bytes
    func getCacheSize() -> Int64 {
        let videos = getAllCachedVideos()
        var totalSize: Int64 = 0

        for videoURL in videos {
            if let attributes = try? fileManager.attributesOfItem(atPath: videoURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }

        return totalSize
    }

    /// Clear all cached videos
    func clearCache() throws {
        let videos = getAllCachedVideos()

        for videoURL in videos {
            try? fileManager.removeItem(at: videoURL)
        }
    }

    /// Clear old videos (older than specified days)
    func clearOldVideos(olderThanDays days: Int) throws {
        let videos = getAllCachedVideos()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        for videoURL in videos {
            if let attributes = try? fileManager.attributesOfItem(atPath: videoURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < cutoffDate {
                try? fileManager.removeItem(at: videoURL)
            }
        }
    }

    /// Format cache size for display
    func formattedCacheSize() -> String {
        let sizeInBytes = getCacheSize()
        return ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
}
