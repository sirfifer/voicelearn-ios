// UnaMentis - Voice Session Integration Tests
// Integration tests for the full voice conversation pipeline
//
// These tests verify end-to-end flows using mock services for
// external APIs but real internal components.

import XCTest
import AVFoundation
import CoreData
import Combine
@testable import UnaMentis

/// Integration tests for voice session functionality
///
/// Tests cover:
/// - Telemetry recording and metrics
/// - Curriculum context generation
/// - Progress tracking
/// - Core Data persistence
/// - Audio pipeline basics
final class VoiceSessionIntegrationTests: XCTestCase {

    // MARK: - Properties

    var telemetry: TelemetryEngine!
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var mockLLM: MockLLMService!
    var cancellables = Set<AnyCancellable>()

    // MARK: - Setup / Teardown

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        // Use in-memory Core Data store
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext

        // Real telemetry engine
        telemetry = TelemetryEngine()

        // Mock LLM for testing without API calls
        mockLLM = MockLLMService()
    }

    override func tearDown() async throws {
        cancellables.removeAll()
        telemetry = nil
        mockLLM = nil
        context = nil
        persistenceController = nil
        try await super.tearDown()
    }

    // MARK: - Telemetry Integration Tests

    @MainActor
    func testTelemetry_tracksLatencyMetrics() async throws {
        // Given - fresh telemetry
        await telemetry.startSession()

        // When - record various latencies
        await telemetry.recordLatency(.sttEmission, 0.250)
        await telemetry.recordLatency(.llmFirstToken, 0.180)
        await telemetry.recordLatency(.ttsTTFB, 0.150)
        await telemetry.recordLatency(.endToEndTurn, 0.450)

        // Then - metrics are tracked
        let metrics = await telemetry.currentMetrics
        XCTAssertFalse(metrics.sttLatencies.isEmpty)
        XCTAssertFalse(metrics.llmLatencies.isEmpty)
        XCTAssertFalse(metrics.ttsLatencies.isEmpty)
        XCTAssertFalse(metrics.e2eLatencies.isEmpty)
    }

    @MainActor
    func testTelemetry_tracksCosts() async throws {
        // Given - fresh telemetry
        await telemetry.startSession()

        // When - record costs
        await telemetry.recordCost(.stt, amount: 0.10, description: "STT usage")
        await telemetry.recordCost(.tts, amount: 0.15, description: "TTS usage")
        await telemetry.recordCost(.llmInput, amount: 0.05, description: "LLM input")
        await telemetry.recordCost(.llmOutput, amount: 0.20, description: "LLM output")

        // Then - total cost is correct
        let metrics = await telemetry.currentMetrics
        XCTAssertEqual(metrics.totalCost, 0.50)
    }

    @MainActor
    func testTelemetry_recordsEvents() async throws {
        // Given - fresh telemetry
        await telemetry.startSession()

        // When - record events
        await telemetry.recordEvent(.sessionStarted)
        await telemetry.recordEvent(.userStartedSpeaking)
        await telemetry.recordEvent(.vadSpeechDetected(confidence: 0.95))

        // Then - events are recorded
        let events = await telemetry.recentEvents
        XCTAssertGreaterThan(events.count, 0)
    }

    // MARK: - Mock LLM Integration Tests

    @MainActor
    func testMockLLM_streamsResponse() async throws {
        // Given - mock LLM with configured response
        await mockLLM.configure(summaryResponse: "Hello, how can I help you learn today?")

        // When - stream completion
        let messages = [LLMMessage(role: .user, content: "Hi there")]
        let config = LLMConfig(model: "claude-3-5-sonnet-20241022", maxTokens: 100)

        var tokens: [String] = []
        let stream = try await mockLLM.streamCompletion(messages: messages, config: config)
        for await token in stream {
            tokens.append(token.content)
        }

        // Then - full response was streamed
        let fullResponse = tokens.joined()
        XCTAssertTrue(fullResponse.contains("Hello"))
        XCTAssertTrue(fullResponse.contains("help"))
    }

    @MainActor
    func testMockLLM_validatesInput() async throws {
        // Given - empty messages
        let messages: [LLMMessage] = []
        let config = LLMConfig(model: "claude-3-5-sonnet-20241022", maxTokens: 100)

        // When/Then - should throw validation error
        do {
            _ = try await mockLLM.streamCompletion(messages: messages, config: config)
            XCTFail("Should have thrown validation error")
        } catch let error as LLMError {
            if case .invalidRequest = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    @MainActor
    func testMockLLM_simulatesErrors() async throws {
        // Given - mock configured to fail
        await mockLLM.configureToFail(with: .rateLimited(retryAfter: 30))

        let messages = [LLMMessage(role: .user, content: "Test")]
        let config = LLMConfig(model: "claude-3-5-sonnet-20241022", maxTokens: 100)

        // When/Then - should throw configured error
        do {
            _ = try await mockLLM.streamCompletion(messages: messages, config: config)
            XCTFail("Should have thrown rate limit error")
        } catch let error as LLMError {
            if case .rateLimited = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Curriculum Context Integration Tests

    @MainActor
    func testCurriculumContext_injectedIntoSession() async throws {
        // Given - curriculum with topic
        let curriculum = TestDataFactory.createCurriculum(in: context, name: "Swift Programming")
        let topic = TestDataFactory.createTopic(in: context, title: "Variables and Constants")
        topic.outline = "- let vs var\n- Type inference\n- Type annotation"
        topic.objectives = ["Understand immutability", "Use type inference"]
        topic.curriculum = curriculum
        try context.save()

        // Create curriculum engine
        let mockEmbedding = MockEmbeddingService()
        let curriculumEngine = CurriculumEngine(
            persistenceController: persistenceController,
            embeddingService: mockEmbedding
        )

        // When - load curriculum and generate context
        try await curriculumEngine.loadCurriculum(curriculum.id!)
        try await curriculumEngine.startTopic(topic)
        let contextString = await curriculumEngine.generateContext(for: topic)

        // Then - context includes topic information
        XCTAssertTrue(contextString.contains("Variables and Constants"))
        XCTAssertTrue(contextString.contains("let vs var"))
        XCTAssertTrue(contextString.contains("Understand immutability"))
    }

    @MainActor
    func testCurriculumNavigation_acrossTopics() async throws {
        // Given - curriculum with multiple topics
        let curriculum = TestDataFactory.createCurriculum(in: context)
        let topic1 = TestDataFactory.createTopic(in: context, title: "Topic 1")
        topic1.orderIndex = 0
        topic1.curriculum = curriculum

        let topic2 = TestDataFactory.createTopic(in: context, title: "Topic 2")
        topic2.orderIndex = 1
        topic2.curriculum = curriculum

        let topic3 = TestDataFactory.createTopic(in: context, title: "Topic 3")
        topic3.orderIndex = 2
        topic3.curriculum = curriculum

        try context.save()

        let mockEmbedding = MockEmbeddingService()
        let curriculumEngine = CurriculumEngine(
            persistenceController: persistenceController,
            embeddingService: mockEmbedding
        )

        // When - navigate through topics
        try await curriculumEngine.loadCurriculum(curriculum.id!)
        try await curriculumEngine.startTopic(topic1)

        // Then - can navigate forward
        let next = await curriculumEngine.getNextTopic()
        XCTAssertEqual(next?.id, topic2.id)

        // Move to topic2 and verify both directions
        try await curriculumEngine.startTopic(topic2)
        let prev = await curriculumEngine.getPreviousTopic()
        let nextFromT2 = await curriculumEngine.getNextTopic()
        XCTAssertEqual(prev?.id, topic1.id)
        XCTAssertEqual(nextFromT2?.id, topic3.id)
    }

    // MARK: - Progress Tracking Integration Tests

    @MainActor
    func testProgressTracking_updatesOnTopicCompletion() async throws {
        // Given - curriculum with topic
        let curriculum = TestDataFactory.createCurriculum(in: context)
        let topic = TestDataFactory.createTopic(in: context, title: "Test Topic")
        topic.curriculum = curriculum
        try context.save()

        let mockEmbedding = MockEmbeddingService()
        let curriculumEngine = CurriculumEngine(
            persistenceController: persistenceController,
            embeddingService: mockEmbedding
        )

        // When - start topic, spend time, and complete
        try await curriculumEngine.loadCurriculum(curriculum.id!)
        try await curriculumEngine.startTopic(topic)
        try await curriculumEngine.updateProgress(
            topic: topic,
            timeSpent: 300, // 5 minutes
            conceptsCovered: ["variables", "constants"]
        )
        try await curriculumEngine.completeTopic(topic, masteryLevel: 0.85)

        // Then - progress is recorded
        XCTAssertEqual(topic.progress?.timeSpent, 300)
        XCTAssertEqual(topic.mastery, 0.85)
        XCTAssertEqual(topic.status, .completed)
    }

    // MARK: - Core Data Integration Tests

    @MainActor
    func testCoreData_curriculumPersistence() async throws {
        // Given - a curriculum with topics
        let curriculum = TestDataFactory.createCurriculum(in: context, name: "Test Course", topicCount: 3)
        try context.save()

        // When - fetch curriculum
        let fetchRequest = Curriculum.fetchRequest()
        let curricula = try context.fetch(fetchRequest)

        // Then - curriculum was persisted with topics
        XCTAssertEqual(curricula.count, 1)
        XCTAssertEqual(curricula.first?.name, "Test Course")
        XCTAssertEqual(curricula.first?.topics?.count, 3)
    }

    @MainActor
    func testCoreData_topicProgressPersistence() async throws {
        // Given - a topic with progress
        let topic = TestDataFactory.createTopic(in: context, title: "Test Topic")
        let progress = TestDataFactory.createProgress(in: context, for: topic, timeSpent: 600)
        try context.save()

        // When - fetch topic with progress
        let fetchRequest = Topic.fetchRequest()
        let topics = try context.fetch(fetchRequest)

        // Then - progress was persisted
        XCTAssertEqual(topics.count, 1)
        XCTAssertEqual(topics.first?.progress?.timeSpent, 600)
    }

    @MainActor
    func testCoreData_documentAssociation() async throws {
        // Given - a topic with documents
        let topic = TestDataFactory.createTopic(in: context, title: "Swift Basics")
        let doc1 = TestDataFactory.createDocument(in: context, title: "Swift Guide", summary: "Intro to Swift")
        let doc2 = TestDataFactory.createDocument(in: context, title: "Advanced Swift", summary: "Deep dive")
        doc1.topic = topic
        doc2.topic = topic
        try context.save()

        // When - fetch topic documents
        let fetchRequest = Document.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "topic == %@", topic)
        let documents = try context.fetch(fetchRequest)

        // Then - documents are associated
        XCTAssertEqual(documents.count, 2)
    }
}

// MARK: - Audio Pipeline Integration Tests

/// Integration tests for audio capture and playback pipeline
final class AudioPipelineIntegrationTests: XCTestCase {

    var audioEngine: AudioEngine!
    var mockVAD: MockVADService!
    var telemetry: TelemetryEngine!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        mockVAD = MockVADService()
        telemetry = TelemetryEngine()
        audioEngine = AudioEngine(
            config: .default,
            vadService: mockVAD,
            telemetry: telemetry
        )
    }

    override func tearDown() async throws {
        await audioEngine.stop()
        audioEngine = nil
        mockVAD = nil
        telemetry = nil
        try await super.tearDown()
    }

    func testAudioEngine_configuresVAD() async throws {
        // Given - custom VAD config
        var config = AudioEngineConfig.default
        config.vadThreshold = 0.7
        config.vadContextWindow = 8

        // When - configure engine
        try await audioEngine.configure(config: config)

        // Then - VAD was configured
        let wasCalled = await mockVAD.configureWasCalled
        XCTAssertTrue(wasCalled)

        let vadConfig = await mockVAD.lastConfiguration
        XCTAssertEqual(vadConfig?.threshold, 0.7)
        XCTAssertEqual(vadConfig?.contextWindow, 8)
    }

    func testAudioEngine_processesBufferThroughVAD() async throws {
        // Given - configured and started engine
        try await audioEngine.configure(config: .default)
        try await audioEngine.start()

        // When - process test buffer
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            XCTFail("Failed to create test buffer")
            return
        }
        buffer.frameLength = 1024

        await audioEngine.processAudioBuffer(buffer)

        // Then - VAD processed the buffer
        let wasCalled = await mockVAD.processBufferWasCalled
        XCTAssertTrue(wasCalled)
    }

    func testAudioEngine_stopsPlaybackOnInterrupt() async throws {
        // Given - configured engine
        try await audioEngine.configure(config: .default)
        try await audioEngine.start()

        // When - stop playback (simulating barge-in)
        await audioEngine.stopPlayback()

        // Then - engine is not playing
        let isPlaying = await audioEngine.isPlaying
        XCTAssertFalse(isPlaying)
    }
}

// MARK: - Thermal Management Integration Tests

/// Integration tests for thermal state handling
final class ThermalManagementIntegrationTests: XCTestCase {

    var audioEngine: AudioEngine!
    var mockVAD: MockVADService!
    var telemetry: TelemetryEngine!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        mockVAD = MockVADService()
        telemetry = TelemetryEngine()
        audioEngine = AudioEngine(
            config: .default,
            vadService: mockVAD,
            telemetry: telemetry
        )
    }

    override func tearDown() async throws {
        await audioEngine.stop()
        audioEngine = nil
        mockVAD = nil
        telemetry = nil
        try await super.tearDown()
    }

    func testThermalStateChange_recordsTelemetry() async throws {
        // Given - engine with adaptive quality enabled
        var config = AudioEngineConfig.default
        config.enableAdaptiveQuality = true
        config.thermalThrottleThreshold = .fair

        try await audioEngine.configure(config: config)
        await telemetry.startSession()
        try await audioEngine.start()

        // When - simulate thermal state change
        await audioEngine.handleThermalStateChange(.serious)

        // Then - event was recorded
        let events = await telemetry.recentEvents
        XCTAssertTrue(events.contains {
            if case .thermalStateChanged = $0.event { return true }
            return false
        })
    }
}

// MARK: - Mock VAD Service (Test Spy)
// NOTE: MockVADService is defined in AudioEngineTests.swift and shared across tests
