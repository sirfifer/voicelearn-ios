//
//  OnDeviceLLMModelManagerTests.swift
//  UnaMentisTests
//
//  Unit tests for OnDeviceLLMModelManager
//

import XCTest
@testable import UnaMentis

/// Unit tests for OnDeviceLLMModelManager
///
/// Tests model configuration, state management, and file operations.
/// Note: Network download tests are skipped in CI to avoid hitting Hugging Face CDN.
final class OnDeviceLLMModelManagerTests: XCTestCase {

    // MARK: - Model Configuration Tests

    func testModelConfigHasCorrectValues() {
        let config = OnDeviceLLMModel.ministral3_3B.config

        XCTAssertEqual(config.id, "ministral-3-3b-instruct-2512")
        XCTAssertEqual(config.displayName, "Ministral 3 3B")
        XCTAssertEqual(config.huggingFaceRepo, "mistralai/Ministral-3-3B-Instruct-2512-GGUF")
        XCTAssertEqual(config.filename, "Ministral-3-3B-Instruct-2512-Q4_K_M.gguf")
        XCTAssertEqual(config.quantization, "Q4_K_M")
        XCTAssertEqual(config.contextSize, 4096)
        XCTAssertEqual(config.minimumRAMGB, 4)
        XCTAssertGreaterThan(config.expectedSizeBytes, 2_000_000_000) // > 2GB
    }

    func testModelConfigDownloadURL() {
        let config = OnDeviceLLMModel.ministral3_3B.config
        let expectedURL = "https://huggingface.co/mistralai/Ministral-3-3B-Instruct-2512-GGUF/resolve/main/Ministral-3-3B-Instruct-2512-Q4_K_M.gguf"

        XCTAssertEqual(config.downloadURL.absoluteString, expectedURL)
    }

    func testModelConfigExpectedSizeMB() {
        let config = OnDeviceLLMModel.ministral3_3B.config

        // ~2.15 GB = ~2150 MB
        XCTAssertEqual(config.expectedSizeMB, 2150)
    }

    // MARK: - Model State Tests

    func testModelStateEquality() {
        // Same states should be equal
        XCTAssertEqual(OnDeviceLLMModelManager.ModelState.notDownloaded, .notDownloaded)
        XCTAssertEqual(OnDeviceLLMModelManager.ModelState.available, .available)
        XCTAssertEqual(OnDeviceLLMModelManager.ModelState.loaded, .loaded)
        XCTAssertEqual(OnDeviceLLMModelManager.ModelState.verifying, .verifying)

        // Progress states with same progress
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.downloading(0.5),
            .downloading(0.5)
        )
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.loading(0.75),
            .loading(0.75)
        )

        // Progress states with similar progress (within tolerance)
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.downloading(0.501),
            .downloading(0.505)
        )

        // Error states with same message
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.error("test error"),
            .error("test error")
        )
    }

    func testModelStateInequality() {
        // Different states should not be equal
        XCTAssertNotEqual(
            OnDeviceLLMModelManager.ModelState.notDownloaded,
            .available
        )
        XCTAssertNotEqual(
            OnDeviceLLMModelManager.ModelState.downloading(0.5),
            .downloading(0.8)
        )
        XCTAssertNotEqual(
            OnDeviceLLMModelManager.ModelState.error("error1"),
            .error("error2")
        )
    }

    func testModelStateIsReady() {
        XCTAssertTrue(OnDeviceLLMModelManager.ModelState.loaded.isReady)
        XCTAssertFalse(OnDeviceLLMModelManager.ModelState.available.isReady)
        XCTAssertFalse(OnDeviceLLMModelManager.ModelState.notDownloaded.isReady)
        XCTAssertFalse(OnDeviceLLMModelManager.ModelState.downloading(0.5).isReady)
    }

    func testModelStateIsAvailable() {
        XCTAssertTrue(OnDeviceLLMModelManager.ModelState.available.isAvailable)
        XCTAssertTrue(OnDeviceLLMModelManager.ModelState.loaded.isAvailable)
        XCTAssertFalse(OnDeviceLLMModelManager.ModelState.notDownloaded.isAvailable)
        XCTAssertFalse(OnDeviceLLMModelManager.ModelState.downloading(0.5).isAvailable)
    }

    func testModelStateDisplayText() {
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.notDownloaded.displayText,
            "Not Downloaded"
        )
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.downloading(0.5).displayText,
            "Downloading 50%"
        )
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.verifying.displayText,
            "Verifying..."
        )
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.available.displayText,
            "Ready to Load"
        )
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.loading(0.25).displayText,
            "Loading 25%"
        )
        XCTAssertEqual(
            OnDeviceLLMModelManager.ModelState.loaded.displayText,
            "Loaded"
        )
        XCTAssertTrue(
            OnDeviceLLMModelManager.ModelState.error("Network error").displayText.contains("Network error")
        )
    }

    // MARK: - Model Info Tests

    func testModelInfoStaticValues() {
        XCTAssertEqual(OnDeviceLLMModelInfo.displayName, "Ministral 3 3B")
        XCTAssertEqual(OnDeviceLLMModelInfo.version, "December 2025")
        XCTAssertEqual(OnDeviceLLMModelInfo.quantization, "Q4_K_M")
        XCTAssertEqual(OnDeviceLLMModelInfo.totalSizeMB, 2150)
        XCTAssertEqual(OnDeviceLLMModelInfo.contextSize, 4096)
        XCTAssertEqual(OnDeviceLLMModelInfo.minimumRAMGB, 4)
        XCTAssertEqual(OnDeviceLLMModelInfo.license, "Apache 2.0")
        XCTAssertEqual(OnDeviceLLMModelInfo.publisher, "Mistral AI")
    }

    func testModelInfoKeepReasons() {
        XCTAssertFalse(OnDeviceLLMModelInfo.keepModelReasons.isEmpty)
        XCTAssertGreaterThanOrEqual(OnDeviceLLMModelInfo.keepModelReasons.count, 3)

        // Should mention offline capability
        let hasOfflineReason = OnDeviceLLMModelInfo.keepModelReasons.contains {
            $0.lowercased().contains("offline")
        }
        XCTAssertTrue(hasOfflineReason, "Should mention offline capability")

        // Should mention privacy
        let hasPrivacyReason = OnDeviceLLMModelInfo.keepModelReasons.contains {
            $0.lowercased().contains("private") || $0.lowercased().contains("privacy")
        }
        XCTAssertTrue(hasPrivacyReason, "Should mention privacy")
    }

    func testModelInfoDeletionConsequences() {
        XCTAssertFalse(OnDeviceLLMModelInfo.deletionConsequences.isEmpty)
        XCTAssertGreaterThanOrEqual(OnDeviceLLMModelInfo.deletionConsequences.count, 3)

        // Should mention re-download option
        let hasRedownloadInfo = OnDeviceLLMModelInfo.deletionConsequences.contains {
            $0.lowercased().contains("re-download") || $0.lowercased().contains("download")
        }
        XCTAssertTrue(hasRedownloadInfo, "Should mention re-download option")
    }

    // MARK: - Model Error Tests

    func testModelErrorDescriptions() {
        XCTAssertNotNil(OnDeviceLLMModelError.modelNotDownloaded.errorDescription)
        XCTAssertTrue(
            OnDeviceLLMModelError.modelNotDownloaded.errorDescription!.contains("not downloaded")
        )

        XCTAssertNotNil(OnDeviceLLMModelError.downloadFailed("test").errorDescription)
        XCTAssertTrue(
            OnDeviceLLMModelError.downloadFailed("network").errorDescription!.contains("network")
        )

        XCTAssertNotNil(OnDeviceLLMModelError.deleteFailed("permission").errorDescription)
        XCTAssertTrue(
            OnDeviceLLMModelError.deleteFailed("permission").errorDescription!.contains("permission")
        )

        XCTAssertNotNil(OnDeviceLLMModelError.insufficientStorage.errorDescription)
        XCTAssertTrue(
            OnDeviceLLMModelError.insufficientStorage.errorDescription!.contains("storage")
        )

        XCTAssertNotNil(OnDeviceLLMModelError.insufficientRAM.errorDescription)
        XCTAssertTrue(
            OnDeviceLLMModelError.insufficientRAM.errorDescription!.contains("RAM")
        )

        XCTAssertNotNil(OnDeviceLLMModelError.networkUnavailable.errorDescription)
        XCTAssertTrue(
            OnDeviceLLMModelError.networkUnavailable.errorDescription!.contains("Network")
        )
    }

    // MARK: - Manager Tests

    func testManagerInitialState() async {
        let manager = OnDeviceLLMModelManager()

        // Give it time to check model availability
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let state = await manager.currentState()

        // Should be notDownloaded since model isn't bundled in tests
        // or available if model was previously downloaded
        XCTAssertTrue(
            state == .notDownloaded || state == .available,
            "Initial state should be notDownloaded or available"
        )
    }

    func testManagerModelPath() async {
        let manager = OnDeviceLLMModelManager()
        let path = await manager.modelPath

        XCTAssertTrue(path.path.contains("models/LLM"))
        XCTAssertTrue(path.path.contains("Ministral-3-3B-Instruct-2512-Q4_K_M.gguf"))
    }

    func testManagerModelPathString() async {
        let manager = OnDeviceLLMModelManager()
        let pathString = await manager.modelPathString

        XCTAssertTrue(pathString.contains("models/LLM"))
        XCTAssertTrue(pathString.contains("Ministral-3-3B-Instruct-2512-Q4_K_M.gguf"))
    }

    func testManagerSelectedModel() async {
        let manager = OnDeviceLLMModelManager()
        let selectedModel = await manager.selectedModel

        XCTAssertEqual(selectedModel, .ministral3_3B)
    }

    func testManagerMarkLoadedAndUnloaded() async {
        let manager = OnDeviceLLMModelManager()

        // Mark as loaded
        await manager.markLoaded()
        var state = await manager.currentState()
        XCTAssertEqual(state, .loaded)

        // Mark as unloaded
        await manager.markUnloaded()
        state = await manager.currentState()
        // Should be available or notDownloaded depending on file existence
        XCTAssertTrue(
            state == .available || state == .notDownloaded,
            "After unload, state should be available or notDownloaded"
        )
    }

    func testManagerCancelDownload() async {
        let manager = OnDeviceLLMModelManager()

        // Cancel when not downloading should be safe
        await manager.cancelDownload()

        let state = await manager.currentState()
        XCTAssertEqual(state, .notDownloaded)
    }

    // MARK: - State Observer Tests

    @MainActor
    func testStateObserverInitialization() async {
        let manager = OnDeviceLLMModelManager()
        let observer = OnDeviceLLMModelStateObserver(manager: manager)

        // Give it time to refresh
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // State should be synced with manager
        let managerState = await manager.currentState()

        // Compare states
        XCTAssertEqual(observer.state, managerState)
    }

    @MainActor
    func testStateObserverRefresh() async {
        let manager = OnDeviceLLMModelManager()
        let observer = OnDeviceLLMModelStateObserver(manager: manager)

        await observer.refreshState()

        let managerState = await manager.currentState()
        XCTAssertEqual(observer.state, managerState)
    }

    // MARK: - All Models Enumeration

    func testAllModelsAvailable() {
        let allModels = OnDeviceLLMModel.allCases

        XCTAssertEqual(allModels.count, 1, "Currently only Ministral 3 3B is supported")
        XCTAssertTrue(allModels.contains(.ministral3_3B))
    }

    func testModelRawValues() {
        XCTAssertEqual(OnDeviceLLMModel.ministral3_3B.rawValue, "ministral-3-3b")
    }
}
