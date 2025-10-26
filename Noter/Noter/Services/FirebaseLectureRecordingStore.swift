import Foundation
import FirebaseFirestore
import FirebaseStorage

enum FirebaseLectureRecordingStoreError: LocalizedError {
    case missingLocalFile
    case downloadURLUnavailable

    var errorDescription: String? {
        switch self {
        case .missingLocalFile:
            return "The local recording file could not be found."
        case .downloadURLUnavailable:
            return "Could not retrieve a download URL for the uploaded recording."
        }
    }
}

actor FirebaseLectureRecordingStore {
    static let shared = FirebaseLectureRecordingStore()

    private let firestore: Firestore
    private let storage: Storage

    init(firestore: Firestore = Firestore.firestore(), storage: Storage = Storage.storage()) {
        self.firestore = firestore
        self.storage = storage
    }

    func sync(recording: LectureRecording, lectureID: UUID, classID: UUID) async throws -> LectureRecording {
        guard recording.remoteURL != nil else {
            var updatedRecording = recording
            guard let storedFileName = recording.storedFileName else {
                throw FirebaseLectureRecordingStoreError.missingLocalFile
            }

            let localURL = LectureMediaStore.shared.url(forStoredFileName: storedFileName)
            guard FileManager.default.fileExists(atPath: localURL.path) else {
                throw FirebaseLectureRecordingStoreError.missingLocalFile
            }

            let fileExtension = (storedFileName as NSString).pathExtension
            let resolvedExtension = fileExtension.isEmpty ? "m4a" : fileExtension
            let objectName = "\(recording.id.uuidString).\(resolvedExtension)"
            let reference = storage.reference()
                .child("classes/\(classID.uuidString)/lectures/\(lectureID.uuidString)/recordings/\(objectName)")

            let metadata = StorageMetadata()
            metadata.contentType = recording.contentType ?? "audio/m4a"
            metadata.customMetadata = [
                "lectureId": lectureID.uuidString,
                "classId": classID.uuidString,
                "originalFileName": recording.originalFileName
            ]

            _ = try await upload(fileURL: localURL, to: reference, metadata: metadata)
            let downloadURL = try await downloadURL(for: reference)

            let documentData: [String: Any] = [
                "id": recording.id.uuidString,
                "lectureId": lectureID.uuidString,
                "classId": classID.uuidString,
                "storagePath": reference.fullPath,
                "downloadURL": downloadURL.absoluteString,
                "createdAt": Timestamp(date: recording.createdAt),
                "fileSize": recording.fileSize ?? 0,
                "contentType": recording.contentType ?? "audio/m4a",
                "duration": recording.duration ?? 0
            ]

            try await setData(documentData, documentID: recording.id.uuidString)

            updatedRecording.remoteURLString = downloadURL.absoluteString
            updatedRecording.storagePath = reference.fullPath
            return updatedRecording
        }

        return recording
    }

    func deleteRemoteArtifacts(for recording: LectureRecording) async throws {
        if let storagePath = recording.storagePath {
            let reference = storage.reference(withPath: storagePath)
            try await delete(reference: reference)
        }

        try await deleteDocument(withID: recording.id.uuidString)
    }

    private func upload(fileURL: URL, to reference: StorageReference, metadata: StorageMetadata) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            reference.putFile(from: fileURL, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: metadata ?? StorageMetadata())
                }
            }
        }
    }

    private func downloadURL(for reference: StorageReference) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            reference.downloadURL { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: FirebaseLectureRecordingStoreError.downloadURLUnavailable)
                }
            }
        }
    }

    private func setData(_ data: [String: Any], documentID: String) async throws {
        let collection = firestore.collection("lectureRecordings")
        try await withCheckedThrowingContinuation { continuation in
            collection.document(documentID).setData(data, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func delete(reference: StorageReference) async throws {
        try await withCheckedThrowingContinuation { continuation in
            reference.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func deleteDocument(withID id: String) async throws {
        let document = firestore.collection("lectureRecordings").document(id)
        try await withCheckedThrowingContinuation { continuation in
            document.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
