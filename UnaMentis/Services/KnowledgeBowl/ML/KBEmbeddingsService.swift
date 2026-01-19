//
//  KBEmbeddingsService.swift
//  UnaMentis
//
//  Semantic embeddings service for Knowledge Bowl answer validation (Tier 2)
//  Uses CoreML sentence transformer for 384-dimensional embeddings
//

import Foundation
@preconcurrency import CoreML
import OSLog

// MARK: - Embeddings Service

/// Service for managing and using sentence embeddings model
actor KBEmbeddingsService {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBEmbeddingsService")

    // MARK: - Model State

    /// Current state of the embeddings model
    enum ModelState: Sendable, Equatable {
        case notDownloaded
        case downloading(Float)  // Progress 0.0-1.0
        case available           // Downloaded but not loaded
        case loaded              // Ready for inference
        case error(String)       // Error occurred

        static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.notDownloaded, .notDownloaded),
                 (.available, .available),
                 (.loaded, .loaded):
                return true
            case let (.downloading(p1), .downloading(p2)):
                return abs(p1 - p2) < 0.01
            case let (.error(e1), .error(e2)):
                return e1 == e2
            default:
                return false
            }
        }
    }

    private var state: ModelState = .notDownloaded
    private nonisolated(unsafe) var model: MLModel?

    // MARK: - Configuration

    private let modelName = "sentence_embeddings_v1"
    private let modelURL: URL
    private let downloadURL = "https://models.unamentis.com/kb/sentence_embeddings_v1.mlpackage.zip"
    private let expectedDimension = 384

    // MARK: - Initialization

    init() {
        // Model storage location
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.modelURL = documentsURL.appendingPathComponent("\(modelName).mlpackage")

        // Check if model already exists
        Task {
            await checkModelAvailability()
        }
    }

    // MARK: - Public API

    /// Get current model state
    nonisolated func currentState() async -> ModelState {
        await state
    }

    /// Download the embeddings model
    /// - Parameter progressHandler: Called with download progress (0.0-1.0)
    func downloadModel(progressHandler: @Sendable @escaping (Float) -> Void) async throws {
        logger.info("Starting model download")
        state = .downloading(0.0)

        guard let url = URL(string: downloadURL) else {
            let error = "Invalid download URL"
            logger.error("\(error)")
            state = .error(error)
            throw EmbeddingsError.invalidURL
        }

        // Download with progress tracking
        let (localURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let error = "Download failed with status \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            logger.error("\(error)")
            state = .error(error)
            throw EmbeddingsError.downloadFailed
        }

        // Unzip to final location
        try await unzipModel(from: localURL)

        state = .available
        logger.info("Model downloaded successfully")
    }

    /// Load the model into memory
    func loadModel() async throws {
        logger.info("Loading embeddings model")

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            let error = "Model not found at \(modelURL.path)"
            logger.error("\(error)")
            state = .error(error)
            throw EmbeddingsError.modelNotFound
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use Neural Engine if available

            self.model = try await MLModel.load(contentsOf: modelURL, configuration: config)
            state = .loaded
            logger.info("Model loaded successfully")
        } catch {
            let errorMsg = "Failed to load model: \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            state = .error(errorMsg)
            throw EmbeddingsError.loadFailed(error)
        }
    }

    /// Unload the model from memory
    func unloadModel() {
        logger.info("Unloading embeddings model")
        model = nil
        state = .available
    }

    /// Generate embedding for text
    /// - Parameter text: Input text
    /// - Returns: 384-dimensional embedding vector
    func embed(_ text: String) async throws -> [Float] {
        guard state == .loaded, let model = model else {
            logger.error("Model not loaded")
            throw EmbeddingsError.modelNotLoaded
        }

        // Prepare input (this is a placeholder - actual implementation depends on model input format)
        guard let inputFeatures = try? prepareInput(text: text) else {
            logger.error("Failed to prepare input")
            throw EmbeddingsError.invalidInput
        }

        // Run inference (synchronous prediction within actor context)
        let prediction = try await model.prediction(from: inputFeatures)

        // Extract embedding (placeholder - actual implementation depends on model output format)
        guard let embedding = extractEmbedding(from: prediction) else {
            logger.error("Failed to extract embedding")
            throw EmbeddingsError.invalidOutput
        }

        guard embedding.count == expectedDimension else {
            logger.error("Unexpected embedding dimension: \(embedding.count)")
            throw EmbeddingsError.dimensionMismatch
        }

        return embedding
    }

    /// Compute cosine similarity between two texts
    /// - Parameters:
    ///   - text1: First text
    ///   - text2: Second text
    /// - Returns: Similarity score (0.0-1.0)
    func similarity(_ text1: String, _ text2: String) async throws -> Float {
        let embedding1 = try await embed(text1)
        let embedding2 = try await embed(text2)

        return cosineSimilarity(embedding1, embedding2)
    }

    // MARK: - Private Helpers

    private func checkModelAvailability() {
        if FileManager.default.fileExists(atPath: modelURL.path) {
            state = .available
            logger.info("Model found at \(self.modelURL.path)")
        } else {
            state = .notDownloaded
            logger.info("Model not downloaded")
        }
    }

    private func unzipModel(from sourceURL: URL) async throws {
        // Create destination directory if needed
        let destDir = modelURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Unzip the model package
        // This is a placeholder - actual implementation would use ZipFoundation or similar
        logger.info("Unzipping model to \(self.modelURL.path)")

        // For now, just move the file (assumes it's already a .mlpackage)
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
        try FileManager.default.moveItem(at: sourceURL, to: modelURL)
    }

    private func prepareInput(text: String) throws -> MLFeatureProvider {
        // Placeholder: Actual implementation depends on model's expected input format
        // Typical CoreML sentence transformer expects a string or token IDs
        fatalError("Model-specific input preparation not implemented")
    }

    private func extractEmbedding(from prediction: MLFeatureProvider) -> [Float]? {
        // Placeholder: Actual implementation depends on model's output format
        // Typical output is a MultiArray of shape [1, 384]
        fatalError("Model-specific output extraction not implemented")
    }

    private func cosineSimilarity(_ vec1: [Float], _ vec2: [Float]) -> Float {
        guard vec1.count == vec2.count else { return 0.0 }

        var dotProduct: Float = 0.0
        var mag1: Float = 0.0
        var mag2: Float = 0.0

        for i in 0..<vec1.count {
            dotProduct += vec1[i] * vec2[i]
            mag1 += vec1[i] * vec1[i]
            mag2 += vec2[i] * vec2[i]
        }

        let magnitude = sqrt(mag1) * sqrt(mag2)
        guard magnitude > 0 else { return 0.0 }

        // Normalize to 0-1 range (cosine returns -1 to 1)
        let cosine = dotProduct / magnitude
        return (cosine + 1.0) / 2.0
    }
}

// MARK: - Embeddings Error

enum EmbeddingsError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case modelNotFound
    case loadFailed(Error)
    case modelNotLoaded
    case invalidInput
    case invalidOutput
    case dimensionMismatch

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid model download URL"
        case .downloadFailed:
            return "Failed to download model"
        case .modelNotFound:
            return "Model file not found"
        case .loadFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .modelNotLoaded:
            return "Model not loaded into memory"
        case .invalidInput:
            return "Failed to prepare model input"
        case .invalidOutput:
            return "Failed to extract model output"
        case .dimensionMismatch:
            return "Embedding dimension mismatch"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBEmbeddingsService {
    static func preview() -> KBEmbeddingsService {
        KBEmbeddingsService()
    }
}
#endif
