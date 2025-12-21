// UnaMentis - OpenAI Embedding Service
// Service for generating vector embeddings using OpenAI API
//
// Part of Curriculum Layer (Phase 4 Integration)

import Foundation
import Logging

/// OpenAI Embedding model options
public enum OpenAIEmbeddingModel: String, Sendable {
    case small = "text-embedding-3-small"
    case large = "text-embedding-3-large"
    case ada002 = "text-embedding-ada-002" // Legacy
    
    var dimension: Int {
        switch self {
        case .small: return 1536
        case .large: return 3072
        case .ada002: return 1536
        }
    }
}

/// Service for generating embeddings via OpenAI
public actor OpenAIEmbeddingService: EmbeddingService {
    
    // MARK: - Properties
    
    private let logger = Logger(label: "com.unamentis.embeddings.openai")
    private let apiKey: String
    private let model: OpenAIEmbeddingModel
    private let baseURL = URL(string: "https://api.openai.com/v1/embeddings")!
    
    public let embeddingDimension: Int
    
    // MARK: - Initialization
    
    public init(apiKey: String, model: OpenAIEmbeddingModel = .small) {
        self.apiKey = apiKey
        self.model = model
        self.embeddingDimension = model.dimension
        logger.info("OpenAIEmbeddingService initialized with model: \(model.rawValue)")
    }
    
    // MARK: - EmbeddingService Protocol
    
    public func embed(text: String) async -> [Float] {
        do {
            // Clean text (replace newlines with spaces as per OpenAI recommendation)
            let cleanedText = text.replacingOccurrences(of: "\n", with: " ")
            
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "input": cleanedText,
                "model": model.rawValue
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Embedding request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return []
            }
            
            let result = try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: data)
            
            guard let embedding = result.data.first?.embedding else {
                logger.error("No embedding returned in response")
                return []
            }
            
            return embedding
        } catch {
            logger.error("Failed to generate embedding: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Models

private struct OpenAIEmbeddingResponse: Codable {
    let data: [EmbeddingData]
    
    struct EmbeddingData: Codable {
        let embedding: [Float]
        let index: Int
    }
}
