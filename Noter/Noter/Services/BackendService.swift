import Foundation
import SwiftData

/// Service for generating educational content - now using ClaudeService directly
class BackendService {
    static let shared = BackendService()

    private init() {}

    // MARK: - Flashcard Generation

    func generateFlashcards(from lecture: Lecture) async throws -> [Flashcard] {
        return try await ClaudeService.shared.generateFlashcards(from: lecture)
    }

    // MARK: - Quiz Generation

    func generateQuiz(from lecture: Lecture) async throws -> [QuizQuestion] {
        return try await ClaudeService.shared.generateQuiz(from: lecture)
    }

    // MARK: - Answer Evaluation

    func evaluateAnswer(question: String, userAnswer: String, sampleAnswer: String) async throws -> AnswerEvaluation {
        return try await ClaudeService.shared.evaluateAnswer(
            question: question,
            userAnswer: userAnswer,
            sampleAnswer: sampleAnswer
        )
    }

    // MARK: - Animation Generation

    func generateAnimation(topic: String, quizQuestions: [QuizQuestion]) async throws -> String {
        return try await ClaudeService.shared.generateAnimation(
            topic: topic,
            quizQuestions: quizQuestions
        )
    }
}

// MARK: - Error Types

enum BackendError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case evaluationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .invalidResponse:
            return "Invalid response from backend"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .evaluationFailed:
            return "Failed to evaluate answer"
        }
    }
}
