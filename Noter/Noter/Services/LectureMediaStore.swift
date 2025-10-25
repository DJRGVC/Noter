import Foundation
import UniformTypeIdentifiers

enum LectureMediaStoreError: LocalizedError {
    case microphoneAccessDenied
    case invalidSource
    case storageFailure

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access is required to record lectures."
        case .invalidSource:
            return "The selected file could not be read."
        case .storageFailure:
            return "We couldn't save the media file. Try again."
        }
    }
}

struct LectureMediaMetadata {
    let storedFileName: String
    let destinationURL: URL
    let fileSize: Int64
    let displayName: String
    let contentTypeIdentifier: String?
    let type: LectureAttachment.AttachmentType
}

final class LectureMediaStore {
    static let shared = LectureMediaStore()

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let queue = DispatchQueue(label: "com.noter.media.store")

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        rootDirectory = documentsDirectory.appendingPathComponent("LectureMedia", isDirectory: true)
        createRootDirectoryIfNeeded()
    }

    func url(forStoredFileName name: String) -> URL {
        rootDirectory.appendingPathComponent(name, isDirectory: false)
    }

    func removeStoredFile(named name: String) {
        let fileURL = url(forStoredFileName: name)
        queue.async { [fileManager] in
            guard fileManager.fileExists(atPath: fileURL.path) else { return }
            try? fileManager.removeItem(at: fileURL)
        }
    }

    @discardableResult
    func persistImportedFile(at url: URL) throws -> LectureAttachment {
        try storeFile(at: url, move: false)
    }

    @discardableResult
    func persistRecording(from url: URL, suggestedName: String? = nil) throws -> LectureAttachment {
        try storeFile(at: url, move: true, preferredName: suggestedName)
    }

    private func storeFile(at url: URL, move: Bool, preferredName: String? = nil) throws -> LectureAttachment {
        let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey, .nameKey])
        let utType = resourceValues?.contentType ?? UTType(filenameExtension: url.pathExtension)
        let originalName = preferredName ?? resourceValues?.name ?? url.lastPathComponent
        let sanitizedBaseName = sanitize((originalName as NSString).deletingPathExtension)
        let targetBaseName = sanitizedBaseName.isEmpty ? "Lecture" : sanitizedBaseName
        let fileExtension = url.pathExtension.isEmpty ? (utType?.preferredFilenameExtension ?? "dat") : url.pathExtension
        let uniqueFileURL = uniqueDestinationURL(for: targetBaseName, fileExtension: fileExtension)

        do {
            if move {
                try fileManager.moveItem(at: url, to: uniqueFileURL)
            } else {
                try fileManager.copyItem(at: url, to: uniqueFileURL)
            }
        } catch {
            throw LectureMediaStoreError.storageFailure
        }

        let fileSize = (try? fileManager.attributesOfItem(atPath: uniqueFileURL.path)[.size] as? NSNumber)?.int64Value
        let metadata = LectureMediaMetadata(
            storedFileName: uniqueFileURL.lastPathComponent,
            destinationURL: uniqueFileURL,
            fileSize: fileSize ?? 0,
            displayName: originalName,
            contentTypeIdentifier: utType?.identifier,
            type: determineAttachmentType(for: utType)
        )

        return LectureAttachment(
            name: metadata.displayName,
            type: metadata.type,
            url: metadata.destinationURL,
            storedFileName: metadata.storedFileName,
            originalFileName: metadata.displayName,
            fileSize: metadata.fileSize,
            contentType: metadata.contentTypeIdentifier
        )
    }

    private func determineAttachmentType(for utType: UTType?) -> LectureAttachment.AttachmentType {
        guard let utType else { return .other }
        if utType.conforms(to: .audio) { return .audio }
        if utType.conforms(to: .pdf) || utType.conforms(to: .text) || utType.conforms(to: .content) {
            return .document
        }
        if utType.conforms(to: .data) { return .other }
        return .other
    }

    private func sanitize(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "-")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func uniqueDestinationURL(for baseName: String, fileExtension: String) -> URL {
        var candidate = rootDirectory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let newBase = "\(baseName)-\(index)"
            candidate = rootDirectory.appendingPathComponent(newBase).appendingPathExtension(fileExtension)
            index += 1
        }
        return candidate
    }

    private func createRootDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: rootDirectory.path) else { return }
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Failed to create LectureMedia directory: \(error)")
        }
    }
}

extension LectureAttachment {
    var resolvedURL: URL? {
        if let storedFileName {
            return LectureMediaStore.shared.url(forStoredFileName: storedFileName)
        }
        return url
    }

    var displayName: String {
        originalFileName ?? name
    }

    var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
