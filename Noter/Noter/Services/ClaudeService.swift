import Foundation
import SwiftData

/// Service for interacting with Claude AI for generating educational content
class ClaudeService {
    static let shared = ClaudeService()
    
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-5-sonnet-20241022"
    
    private init() {
        // Load API key from config or environment
        if let key = Self.loadAPIKey() {
            self.apiKey = key
        } else {
            fatalError("ANTHROPIC_API_KEY not found. Please set it in environment or config.")
        }
    }
    
    // MARK: - Configuration Loading
    
    private static func loadAPIKey() -> String? {
        // Try to load from config file
        let configPath = "/Users/haoming/Desktop/Noter/learning_page_logic/config/config.json"
        if let configData = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let json = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
           let claude = json["claude"] as? [String: Any],
           let apiKey = claude["apiKey"] as? String {
            return apiKey
        }
        
        // Try to load from environment
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return envKey
        }
        
        return nil
    }
    
    // MARK: - Flashcard Generation
    
    func generateFlashcards(from lecture: Lecture) async throws -> [Flashcard] {
        let notesText = extractNotesText(from: lecture)
        
        let prompt = """
        Based on these lecture notes titled "\(lecture.title)", generate 10 flashcards to help students study.

        NOTES:
        \(notesText.prefix(8000))

        You MUST respond with ONLY valid JSON in exactly this format, with no additional text before or after:
        {
          "flashcards": [
            {
              "question": "question here",
              "answer": "answer here"
            }
          ]
        }

        Make questions clear and answers concise but informative. Return ONLY the JSON, nothing else.
        """
        
        let response = try await callClaude(prompt: prompt)
        let flashcardsData = try parseFlashcardsResponse(response)
        
        return flashcardsData.map { data in
            Flashcard(
                question: data.question,
                answer: data.answer,
                lecture: lecture
            )
        }
    }
    
    // MARK: - Quiz Generation
    
    func generateQuiz(from lecture: Lecture) async throws -> [QuizQuestion] {
        let notesText = extractNotesText(from: lecture)
        
        let prompt = """
        Based on these lecture notes titled "\(lecture.title)", generate 5 quiz questions (mix of multiple choice and free response).

        NOTES:
        \(notesText.prefix(8000))

        You MUST respond with ONLY valid JSON in exactly this format, with no additional text before or after:
        {
          "questions": [
            {
              "type": "mcq",
              "question": "question text",
              "options": ["option1", "option2", "option3", "option4"],
              "correct_answer": 0,
              "explanation": "explanation"
            },
            {
              "type": "free_response",
              "question": "question text",
              "sample_answer": "sample answer"
            }
          ]
        }

        Make 3 multiple choice and 2 free response questions. Return ONLY the JSON, nothing else.
        """
        
        let response = try await callClaude(prompt: prompt)
        let questionsData = try parseQuizResponse(response)
        
        return questionsData.map { data in
            if data.type == "mcq" {
                return QuizQuestion(
                    question: data.question,
                    type: .multipleChoice,
                    options: data.options ?? [],
                    correctAnswer: data.correctAnswer,
                    explanation: data.explanation,
                    sampleAnswer: nil,
                    lecture: lecture
                )
            } else {
                return QuizQuestion(
                    question: data.question,
                    type: .freeResponse,
                    options: [],
                    correctAnswer: nil,
                    explanation: nil,
                    sampleAnswer: data.sampleAnswer,
                    lecture: lecture
                )
            }
        }
    }
    
    // MARK: - Question Answering
    
    func askQuestion(question: String, context: String) async throws -> String {
        let prompt = """
        You are a helpful study assistant. Answer the following question based on the provided context.
        If the question is general and not specific to the context, provide helpful academic guidance.
        
        CONTEXT:
        \(context)
        
        QUESTION:
        \(question)
        
        Provide a clear, concise, and helpful answer. Be conversational but informative.
        """
        
        return try await callClaude(prompt: prompt)
    }
    
    // MARK: - Answer Evaluation
    
    func evaluateAnswer(question: String, userAnswer: String, sampleAnswer: String) async throws -> AnswerEvaluation {
        let prompt = """
        Evaluate this student's answer to a question.

        QUESTION: \(question)

        SAMPLE ANSWER: \(sampleAnswer)

        STUDENT'S ANSWER: \(userAnswer)

        You MUST respond with ONLY valid JSON in exactly this format:
        {
          "score": 85,
          "feedback": "detailed feedback here"
        }

        Score should be 0-100. Provide constructive feedback. Return ONLY the JSON, nothing else.
        """
        
        let response = try await callClaude(prompt: prompt)
        let evaluationData = try parseEvaluationResponse(response)
        
        return AnswerEvaluation(score: evaluationData.score, feedback: evaluationData.feedback)
    }
    
    // MARK: - Animation Generation
    
    func generateAnimation(topic: String, quizQuestions: [QuizQuestion]) async throws -> String {
        let questionsText = quizQuestions.enumerated().map { index, q in
            "Question \(index + 1): \(q.question) (Type: \(q.type == .multipleChoice ? "Multiple Choice" : "Free Response"))"
        }.joined(separator: "\n")
        
        let prompt = """
        Generate a Manim (Mathematical Animation Engine) Python script to create an educational animation about: \(topic)

        Quiz questions to help guide the animation:
        \(questionsText)

        Generate a complete, runnable Manim script with a scene class that creates an engaging educational animation.
        The animation should:
        - Introduce the topic clearly
        - Use visual aids (text, shapes, diagrams)
        - Be approximately 30-60 seconds long
        - Include smooth transitions

        Return ONLY the Python code, nothing else. The class name should be "GenScene".
        """
        
        let response = try await callClaude(prompt: prompt)
        return extractCode(from: response)
    }
    
    // MARK: - Helper Methods
    
    private func extractNotesText(from lecture: Lecture) -> String {
        var text = ""
        
        if !lecture.summary.isEmpty {
            text += "Summary: \(lecture.summary)\n\n"
        }
        
        for note in lecture.notes {
            text += note.content + "\n\n"
        }
        
        return text
    }
    
    private func callClaude(prompt: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ClaudeError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeError.invalidResponseFormat
        }
        
        return text
    }
    
    private func parseFlashcardsResponse(_ response: String) throws -> [FlashcardData] {
        let jsonString = extractJSON(from: response)
        guard let data = jsonString.data(using: .utf8) else {
            throw ClaudeError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(FlashcardsResponse.self, from: data)
        return response.flashcards
    }
    
    private func parseQuizResponse(_ response: String) throws -> [QuizQuestionData] {
        let jsonString = extractJSON(from: response)
        guard let data = jsonString.data(using: .utf8) else {
            throw ClaudeError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(QuizResponse.self, from: data)
        return response.questions
    }
    
    private func parseEvaluationResponse(_ response: String) throws -> EvaluationData {
        let jsonString = extractJSON(from: response)
        guard let data = jsonString.data(using: .utf8) else {
            throw ClaudeError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(EvaluationData.self, from: data)
    }
    
    private func extractJSON(from response: String) -> String {
        // Handle code blocks
        if response.contains("```json") {
            let parts = response.components(separatedBy: "```json")
            if parts.count > 1 {
                let jsonPart = parts[1].components(separatedBy: "```")[0]
                return jsonPart.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if response.contains("```") {
            let parts = response.components(separatedBy: "```")
            if parts.count > 1 {
                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractCode(from response: String) -> String {
        // Extract Python code from response
        if response.contains("```python") {
            let parts = response.components(separatedBy: "```python")
            if parts.count > 1 {
                let codePart = parts[1].components(separatedBy: "```")[0]
                return codePart.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if response.contains("```") {
            let parts = response.components(separatedBy: "```")
            if parts.count > 1 {
                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If no code blocks, return as is (might be raw code)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Response Models

private struct FlashcardsResponse: Codable {
    let flashcards: [FlashcardData]
}

private struct FlashcardData: Codable {
    let question: String
    let answer: String
}

private struct QuizResponse: Codable {
    let questions: [QuizQuestionData]
}

private struct QuizQuestionData: Codable {
    let type: String
    let question: String
    let options: [String]?
    let correctAnswer: Int?
    let explanation: String?
    let sampleAnswer: String?
    
    enum CodingKeys: String, CodingKey {
        case type, question, options, explanation
        case correctAnswer = "correct_answer"
        case sampleAnswer = "sample_answer"
    }
}

private struct EvaluationData: Codable {
    let score: Int
    let feedback: String
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case invalidResponseFormat
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from Claude"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .invalidResponseFormat:
            return "Could not parse Claude response"
        case .invalidJSON:
            return "Invalid JSON in response"
        }
    }
}
