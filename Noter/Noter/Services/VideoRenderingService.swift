import Foundation
import AVFoundation

/// Service for rendering Manim videos from generated code
class VideoRenderingService {
    static let shared = VideoRenderingService()

    private let baseURL = "http://127.0.0.1:5001"

    private init() {}

    // MARK: - Code Generation

    func generateManimCode(
        prompt: String,
        model: String = "claude-3-haiku-20240307"
    ) async throws -> String {
        let endpoint = "\(baseURL)/v1/code/generation"

        let requestBody: [String: Any] = [
            "prompt": prompt,
            "model": model
        ]

        let data = try await post(endpoint: endpoint, body: requestBody)
        let response = try JSONDecoder().decode(CodeGenerationResponse.self, from: data)

        return extractCode(from: response.code)
    }

    // MARK: - Video Rendering

    func renderVideo(
        code: String,
        className: String = "GenScene",
        aspectRatio: VideoAspectRatio = .standard
    ) async throws -> URL {
        let endpoint = "\(baseURL)/v1/video/rendering"

        let requestBody: [String: Any] = [
            "code": code,
            "file_class": className,
            "aspect_ratio": aspectRatio.rawValue,
            "stream": false,
            "user_id": UUID().uuidString,
            "project_name": "noter_animation",
            "iteration": Int.random(in: 1000...9999)
        ]

        let data = try await post(endpoint: endpoint, body: requestBody)
        let response = try JSONDecoder().decode(VideoRenderingResponse.self, from: data)

        guard let videoURLString = response.video_url,
              let videoURL = URL(string: videoURLString) else {
            throw VideoRenderingError.invalidVideoURL
        }

        // Download video to local cache
        let localURL = try await downloadVideo(from: videoURL)
        return localURL
    }

    // MARK: - Streaming Render

    func streamRenderingProgress(
        code: String,
        className: String = "GenScene",
        aspectRatio: VideoAspectRatio = .standard
    ) -> AsyncThrowingStream<RenderProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let endpoint = "\(baseURL)/v1/video/rendering"

                    let requestBody: [String: Any] = [
                        "code": code,
                        "file_class": className,
                        "aspect_ratio": aspectRatio.rawValue,
                        "stream": true,
                        "user_id": UUID().uuidString,
                        "project_name": "noter_animation",
                        "iteration": Int.random(in: 1000...9999)
                    ]

                    guard let url = URL(string: endpoint) else {
                        throw VideoRenderingError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw VideoRenderingError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
                    }

                    var buffer = ""

                    for try await byte in bytes {
                        let char = Character(UnicodeScalar(byte))
                        buffer.append(char)

                        if char == "\n" {
                            let line = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                            buffer = ""

                            if line.isEmpty { continue }

                            // Parse JSON progress updates
                            if let data = line.data(using: .utf8) {
                                if let progressUpdate = try? JSONDecoder().decode(ProgressUpdate.self, from: data) {
                                    if let animationIndex = progressUpdate.animationIndex,
                                       let percentage = progressUpdate.percentage {
                                        continuation.yield(.progress(animation: animationIndex, percentage: percentage))
                                    } else if let videoURL = progressUpdate.video_url, let url = URL(string: videoURL) {
                                        let localURL = try await self.downloadVideo(from: url)
                                        continuation.yield(.completed(videoURL: localURL))
                                        continuation.finish()
                                        return
                                    } else if let error = progressUpdate.error {
                                        continuation.finish(throwing: VideoRenderingError.renderingFailed(error))
                                        return
                                    }
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func post(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw VideoRenderingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300 // 5 minutes for video rendering

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VideoRenderingError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw VideoRenderingError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    private func downloadVideo(from url: URL) async throws -> URL {
        let (localURL, _) = try await URLSession.shared.download(from: url)

        // Move to permanent location in cache
        let cacheURL = try VideoCacheService.shared.cacheVideo(from: localURL)

        return cacheURL
    }

    private func extractCode(from rawCode: String) -> String {
        // Remove markdown code fences if present
        var code = rawCode

        if code.contains("```python") {
            code = code.components(separatedBy: "```python").dropFirst().joined()
                .components(separatedBy: "```").first ?? code
        } else if code.contains("```") {
            code = code.components(separatedBy: "```").dropFirst().first?
                .components(separatedBy: "```").first ?? code
        }

        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Models

enum VideoAspectRatio: String, CaseIterable, Identifiable {
    case standard = "16:9"
    case portrait = "9:16"
    case square = "1:1"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Landscape (16:9)"
        case .portrait: return "Portrait (9:16)"
        case .square: return "Square (1:1)"
        }
    }
    
    var description: String {
        displayName
    }
}

enum RenderProgress {
    case progress(animation: Int, percentage: Int)
    case completed(videoURL: URL)
}

private struct CodeGenerationResponse: Codable {
    let code: String
}

private struct VideoRenderingResponse: Codable {
    let message: String?
    let video_url: String?
}

private struct ProgressUpdate: Codable {
    let animationIndex: Int?
    let percentage: Int?
    let video_url: String?
    let error: String?
}

// MARK: - Errors

enum VideoRenderingError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case invalidVideoURL
    case renderingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "Server error: \(statusCode)"
        case .invalidVideoURL:
            return "Invalid video URL received"
        case .renderingFailed(let message):
            return "Rendering failed: \(message)"
        }
    }
}
