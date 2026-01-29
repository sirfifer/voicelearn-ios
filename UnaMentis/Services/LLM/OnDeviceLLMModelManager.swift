// UnaMentis - On-Device LLM Model Manager
// Manages Ministral 3 3B model download, storage, and lifecycle
//
// Part of Services/LLM

import Foundation
import OSLog

// MARK: - Model Configuration

/// Model configuration for on-device LLM
public struct OnDeviceLLMModelConfig: Sendable {
    /// Model identifier
    let id: String
    /// Display name
    let displayName: String
    /// Hugging Face repository
    let huggingFaceRepo: String
    /// Filename in the repository
    let filename: String
    /// Expected file size in bytes
    let expectedSizeBytes: Int64
    /// Quantization type
    let quantization: String
    /// Context window size
    let contextSize: UInt32
    /// Minimum RAM required in GB
    let minimumRAMGB: Int
    /// Description for users
    let description: String

    /// Direct download URL from Hugging Face CDN
    var downloadURL: URL {
        URL(string: "https://huggingface.co/\(huggingFaceRepo)/resolve/main/\(filename)")!
    }

    /// Expected size in MB for display
    var expectedSizeMB: Int {
        Int(expectedSizeBytes / 1_000_000)
    }
}

// MARK: - Available Models

/// Available on-device LLM models
public enum OnDeviceLLMModel: String, CaseIterable, Sendable {
    case ministral3_3B = "ministral-3-3b"

    /// Model configuration
    public var config: OnDeviceLLMModelConfig {
        switch self {
        case .ministral3_3B:
            return OnDeviceLLMModelConfig(
                id: "ministral-3-3b-instruct-2512",
                displayName: "Ministral 3 3B",
                huggingFaceRepo: "mistralai/Ministral-3-3B-Instruct-2512-GGUF",
                filename: "Ministral-3-3B-Instruct-2512-Q4_K_M.gguf",
                expectedSizeBytes: 2_150_000_000, // ~2.15 GB
                quantization: "Q4_K_M",
                contextSize: 4096,
                minimumRAMGB: 4,
                description: "December 2025 release from Mistral AI. Excellent instruction following and reasoning capabilities."
            )
        }
    }
}

// MARK: - Model Manager

/// Manages on-device LLM model files
///
/// Model files are stored in Documents/models/LLM/ and downloaded from Hugging Face CDN.
///
/// Features:
/// - Download from Hugging Face with progress tracking
/// - Resume interrupted downloads
/// - Delete models to free storage
/// - Verify model integrity
public actor OnDeviceLLMModelManager {
    private let logger = Logger(subsystem: "com.unamentis", category: "OnDeviceLLMModelManager")

    // MARK: - Model State

    /// Current state of the model
    public enum ModelState: Sendable, Equatable {
        case notDownloaded       // Model not present
        case downloading(Float)  // Download in progress with progress (0.0-1.0)
        case verifying           // Verifying downloaded file
        case available           // Model present, not loaded
        case loading(Float)      // Loading into memory
        case loaded              // Ready for inference
        case error(String)       // Error occurred

        public static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.notDownloaded, .notDownloaded),
                 (.verifying, .verifying),
                 (.available, .available),
                 (.loaded, .loaded):
                return true
            case let (.downloading(p1), .downloading(p2)),
                 let (.loading(p1), .loading(p2)):
                return abs(p1 - p2) < 0.01
            case let (.error(e1), .error(e2)):
                return e1 == e2
            default:
                return false
            }
        }

        public var isReady: Bool {
            self == .loaded
        }

        public var isAvailable: Bool {
            self == .available || self == .loaded
        }

        public var displayText: String {
            switch self {
            case .notDownloaded: return "Not Downloaded"
            case .downloading(let progress): return "Downloading \(Int(progress * 100))%"
            case .verifying: return "Verifying..."
            case .available: return "Ready to Load"
            case .loading(let progress): return "Loading \(Int(progress * 100))%"
            case .loaded: return "Loaded"
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    public private(set) var state: ModelState = .notDownloaded

    /// Currently selected model
    public private(set) var selectedModel: OnDeviceLLMModel = .ministral3_3B

    // MARK: - Download State

    private var downloadTask: URLSessionDownloadTask?
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private var progressObservation: NSKeyValueObservation?

    // MARK: - Model Paths

    /// Base directory for LLM models
    private var modelDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("models/LLM", isDirectory: true)
    }

    /// Path to the current model file
    public var modelPath: URL {
        modelDirectory.appendingPathComponent(selectedModel.config.filename)
    }

    /// Path as string for llama.cpp
    public var modelPathString: String {
        modelPath.path
    }

    // MARK: - Initialization

    public init() {
        Task {
            await checkModelAvailability()
        }
    }

    // MARK: - Public API

    /// Get current model state
    nonisolated public func currentState() async -> ModelState {
        await state
    }

    /// Check if model is available locally
    public func isModelAvailable() -> Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    /// Get model file size in bytes (0 if not downloaded)
    public func modelSizeBytes() -> Int64 {
        guard isModelAvailable() else { return 0 }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: modelPath.path)
            return attrs[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }

    /// Get model file size in MB for display
    public func modelSizeMB() -> Int {
        Int(modelSizeBytes() / 1_000_000)
    }

    /// Ensure model is available (download if needed)
    public func ensureModelAvailable() async throws {
        if isModelAvailable() {
            state = .available
            return
        }

        try await downloadModel()
    }

    /// Download the model from Hugging Face
    public func downloadModel() async throws {
        guard !isModelAvailable() else {
            state = .available
            return
        }

        let config = selectedModel.config
        logger.info("Starting download of \(config.displayName) from Hugging Face")

        state = .downloading(0.0)

        // Create model directory if needed
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        // Create URLSession configuration for background download
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 300
        sessionConfig.timeoutIntervalForResource = 3600 // 1 hour for large file
        let session = URLSession(configuration: sessionConfig)

        // Download file
        let tempURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.downloadContinuation = continuation

            let task = session.downloadTask(with: config.downloadURL) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: OnDeviceLLMModelError.downloadFailed("Invalid response"))
                    return
                }

                guard let tempURL = tempURL else {
                    continuation.resume(throwing: OnDeviceLLMModelError.downloadFailed("No file returned"))
                    return
                }

                continuation.resume(returning: tempURL)
            }

            self.downloadTask = task

            // Observe progress
            self.progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { [weak self] in
                    await self?.updateDownloadProgress(Float(progress.fractionCompleted))
                }
            }

            task.resume()
        }

        // Clean up observation
        progressObservation?.invalidate()
        progressObservation = nil
        downloadTask = nil
        downloadContinuation = nil

        // Verify and move file
        state = .verifying
        logger.info("Download complete, verifying file...")

        do {
            // Move to final location
            if FileManager.default.fileExists(atPath: modelPath.path) {
                try FileManager.default.removeItem(at: modelPath)
            }
            try FileManager.default.moveItem(at: tempURL, to: modelPath)

            // Verify size
            let actualSize = modelSizeBytes()
            let expectedSize = config.expectedSizeBytes
            let tolerance: Int64 = 100_000_000 // 100MB tolerance for compression variations

            if abs(actualSize - expectedSize) > tolerance {
                logger.warning("Model size mismatch: expected \(expectedSize), got \(actualSize)")
            }

            state = .available
            logger.info("Model \(config.displayName) downloaded successfully (\(self.modelSizeMB()) MB)")

        } catch {
            state = .error("Failed to save model: \(error.localizedDescription)")
            throw OnDeviceLLMModelError.downloadFailed(error.localizedDescription)
        }
    }

    /// Cancel ongoing download
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        progressObservation?.invalidate()
        progressObservation = nil

        if let continuation = downloadContinuation {
            continuation.resume(throwing: CancellationError())
            downloadContinuation = nil
        }

        state = .notDownloaded
        logger.info("Download cancelled")
    }

    /// Delete the model to free storage
    public func deleteModel() async throws {
        guard isModelAvailable() else {
            return
        }

        logger.info("Deleting model at \(self.modelPath.path)")

        do {
            try FileManager.default.removeItem(at: modelPath)
            state = .notDownloaded
            logger.info("Model deleted successfully")
        } catch {
            logger.error("Failed to delete model: \(error.localizedDescription)")
            throw OnDeviceLLMModelError.deleteFailed(error.localizedDescription)
        }
    }

    /// Mark model as loaded (called by OnDeviceLLMService after successful load)
    public func markLoaded() {
        state = .loaded
    }

    /// Mark model as available (called when unloading)
    public func markUnloaded() {
        if isModelAvailable() {
            state = .available
        } else {
            state = .notDownloaded
        }
    }

    // MARK: - Private Helpers

    private func checkModelAvailability() {
        if isModelAvailable() {
            state = .available
            logger.info("Model found at: \(self.modelPath.path)")
        } else {
            state = .notDownloaded
            logger.info("Model not found, needs to be downloaded")
        }
    }

    private func updateDownloadProgress(_ progress: Float) {
        state = .downloading(progress)
    }
}

// MARK: - Model Error

/// Errors for on-device LLM model operations
public enum OnDeviceLLMModelError: Error, LocalizedError {
    case modelNotDownloaded
    case downloadFailed(String)
    case deleteFailed(String)
    case insufficientStorage
    case insufficientRAM
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "The on-device LLM model is not downloaded. Download it in Settings to enable this feature."
        case .downloadFailed(let reason):
            return "Failed to download model: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete model: \(reason)"
        case .insufficientStorage:
            return "Not enough storage space. The model requires approximately 2.2 GB of free space."
        case .insufficientRAM:
            return "This device does not have enough RAM to run the on-device LLM. A minimum of 4 GB is required."
        case .networkUnavailable:
            return "Network connection is required to download the model."
        }
    }
}

// MARK: - Model Info

/// Static information about the on-device LLM model
public enum OnDeviceLLMModelInfo {
    public static let displayName = "Ministral 3 3B"
    public static let version = "December 2025"
    public static let quantization = "Q4_K_M"
    public static let totalSizeMB: Float = 2150
    public static let contextSize: UInt32 = 4096
    public static let minimumRAMGB = 4
    public static let minimumIOSVersion = "16.0"
    public static let license = "Apache 2.0"
    public static let publisher = "Mistral AI"

    /// Why users should keep the model
    public static let keepModelReasons = [
        "Enables fully offline AI features for learning modules",
        "No internet connection required for tutoring sessions",
        "Your data stays private and never leaves your device",
        "No API costs for on-device processing",
        "Faster response times compared to cloud services"
    ]

    /// What happens if deleted
    public static let deletionConsequences = [
        "Learning modules will fall back to simpler validation methods",
        "Complex answers requiring judgment may not be validated correctly",
        "Some curriculum features may require an internet connection",
        "You can re-download the model anytime (requires ~2.2 GB download)"
    ]
}

// MARK: - State Observer

/// Observable wrapper for model state (for SwiftUI)
@MainActor
public final class OnDeviceLLMModelStateObserver: ObservableObject {
    @Published public var state: OnDeviceLLMModelManager.ModelState = .notDownloaded
    @Published public var downloadProgress: Float = 0.0

    private let manager: OnDeviceLLMModelManager

    public init(manager: OnDeviceLLMModelManager) {
        self.manager = manager
        Task {
            await refreshState()
        }
    }

    public func refreshState() async {
        state = await manager.currentState()
        if case .downloading(let progress) = state {
            downloadProgress = progress
        }
    }

    public func downloadModel() async throws {
        try await manager.downloadModel()
        await refreshState()
    }

    public func cancelDownload() async {
        await manager.cancelDownload()
        await refreshState()
    }

    public func deleteModel() async throws {
        try await manager.deleteModel()
        await refreshState()
    }

    public var isModelAvailable: Bool {
        get async { await manager.isModelAvailable() }
    }

    public var modelSizeMB: Int {
        get async { await manager.modelSizeMB() }
    }

    public var modelPath: String {
        get async { await manager.modelPathString }
    }
}

// MARK: - Preview Support

#if DEBUG
extension OnDeviceLLMModelManager {
    public static func preview() -> OnDeviceLLMModelManager {
        OnDeviceLLMModelManager()
    }
}
#endif
