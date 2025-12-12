// VoiceLearn - LLM Task Type Tests
// Tests for task type enumeration and capability requirements
//
// Part of Patch Panel routing system

import XCTest
@testable import VoiceLearn

/// Tests for LLMTaskType enumeration
final class LLMTaskTypeTests: XCTestCase {

    // MARK: - Task Type Existence Tests

    func testAllCoreTutoringTaskTypesExist() {
        // Core tutoring tasks
        XCTAssertNotNil(LLMTaskType.tutoringResponse)
        XCTAssertNotNil(LLMTaskType.understandingCheck)
        XCTAssertNotNil(LLMTaskType.socraticQuestion)
        XCTAssertNotNil(LLMTaskType.misconceptionCorrection)
    }

    func testAllContentTaskTypesExist() {
        // Content generation tasks
        XCTAssertNotNil(LLMTaskType.explanationGeneration)
        XCTAssertNotNil(LLMTaskType.exampleGeneration)
        XCTAssertNotNil(LLMTaskType.analogyGeneration)
        XCTAssertNotNil(LLMTaskType.rephrasing)
        XCTAssertNotNil(LLMTaskType.simplification)
    }

    func testAllNavigationTaskTypesExist() {
        // Navigation tasks
        XCTAssertNotNil(LLMTaskType.tangentExploration)
        XCTAssertNotNil(LLMTaskType.topicTransition)
        XCTAssertNotNil(LLMTaskType.sessionSummary)
    }

    func testAllProcessingTaskTypesExist() {
        // Content processing tasks
        XCTAssertNotNil(LLMTaskType.documentSummarization)
        XCTAssertNotNil(LLMTaskType.transcriptGeneration)
        XCTAssertNotNil(LLMTaskType.glossaryExtraction)
    }

    func testAllClassificationTaskTypesExist() {
        // Classification tasks
        XCTAssertNotNil(LLMTaskType.intentClassification)
        XCTAssertNotNil(LLMTaskType.sentimentAnalysis)
        XCTAssertNotNil(LLMTaskType.topicClassification)
    }

    func testAllSimpleResponseTaskTypesExist() {
        // Simple response tasks
        XCTAssertNotNil(LLMTaskType.acknowledgment)
        XCTAssertNotNil(LLMTaskType.fillerResponse)
        XCTAssertNotNil(LLMTaskType.navigationConfirmation)
    }

    func testAllSystemTaskTypesExist() {
        // System tasks
        XCTAssertNotNil(LLMTaskType.healthCheck)
        XCTAssertNotNil(LLMTaskType.embeddingGeneration)
    }

    // MARK: - Capability Tier Tests

    func testFrontierTierTasks() {
        // These tasks require frontier models (GPT-4o, Claude 3.5)
        let frontierTasks: [LLMTaskType] = [
            .tutoringResponse,
            .understandingCheck,
            .socraticQuestion,
            .misconceptionCorrection,
            .tangentExploration
        ]

        for task in frontierTasks {
            XCTAssertEqual(
                task.minimumCapabilityTier,
                .frontier,
                "\(task) should require frontier tier"
            )
        }
    }

    func testMediumTierTasks() {
        // These tasks can use medium models (7-70B)
        let mediumTasks: [LLMTaskType] = [
            .explanationGeneration,
            .exampleGeneration,
            .analogyGeneration,
            .rephrasing,
            .simplification,
            .documentSummarization,
            .transcriptGeneration,
            .sessionSummary
        ]

        for task in mediumTasks {
            XCTAssertEqual(
                task.minimumCapabilityTier,
                .medium,
                "\(task) should require medium tier"
            )
        }
    }

    func testSmallTierTasks() {
        // These tasks can use small models (1-3B)
        let smallTasks: [LLMTaskType] = [
            .intentClassification,
            .sentimentAnalysis,
            .topicClassification,
            .glossaryExtraction,
            .topicTransition
        ]

        for task in smallTasks {
            XCTAssertEqual(
                task.minimumCapabilityTier,
                .small,
                "\(task) should require small tier"
            )
        }
    }

    func testTinyTierTasks() {
        // These tasks can use tiny models or templates
        let tinyTasks: [LLMTaskType] = [
            .acknowledgment,
            .fillerResponse,
            .navigationConfirmation
        ]

        for task in tinyTasks {
            XCTAssertEqual(
                task.minimumCapabilityTier,
                .tiny,
                "\(task) should require tiny tier"
            )
        }
    }

    func testSpecialTierTasks() {
        XCTAssertEqual(LLMTaskType.healthCheck.minimumCapabilityTier, .any)
        XCTAssertEqual(LLMTaskType.embeddingGeneration.minimumCapabilityTier, .embedding)
    }

    // MARK: - Transcript Answerable Tests

    func testTranscriptAnswerableTasks() {
        // Tasks that can potentially be answered from transcript
        let transcriptTasks: [LLMTaskType] = [
            .exampleGeneration,
            .rephrasing,
            .simplification,
            .glossaryExtraction,
            .topicTransition
        ]

        for task in transcriptTasks {
            XCTAssertTrue(
                task.acceptsTranscriptAnswer,
                "\(task) should accept transcript answers"
            )
        }
    }

    func testNonTranscriptAnswerableTasks() {
        // Tasks that need fresh generation
        let nonTranscriptTasks: [LLMTaskType] = [
            .tutoringResponse,
            .understandingCheck,
            .socraticQuestion,
            .tangentExploration,
            .intentClassification
        ]

        for task in nonTranscriptTasks {
            XCTAssertFalse(
                task.acceptsTranscriptAnswer,
                "\(task) should not accept transcript answers"
            )
        }
    }

    // MARK: - CaseIterable Tests

    func testAllTaskTypesInCaseIterable() {
        let allCases = LLMTaskType.allCases

        // Should have all the tasks we've defined
        XCTAssertGreaterThanOrEqual(allCases.count, 18)

        // Verify key tasks are included
        XCTAssertTrue(allCases.contains(.tutoringResponse))
        XCTAssertTrue(allCases.contains(.intentClassification))
        XCTAssertTrue(allCases.contains(.acknowledgment))
        XCTAssertTrue(allCases.contains(.healthCheck))
    }

    // MARK: - Raw Value Tests

    func testTaskTypeRawValues() {
        XCTAssertEqual(LLMTaskType.tutoringResponse.rawValue, "tutoringResponse")
        XCTAssertEqual(LLMTaskType.intentClassification.rawValue, "intentClassification")
        XCTAssertEqual(LLMTaskType.acknowledgment.rawValue, "acknowledgment")
    }

    // MARK: - Codable Tests

    func testTaskTypeCodable() throws {
        let task = LLMTaskType.tutoringResponse

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LLMTaskType.self, from: data)

        XCTAssertEqual(decoded, task)
    }

    func testTaskTypeArrayCodable() throws {
        let tasks: [LLMTaskType] = [
            .tutoringResponse,
            .intentClassification,
            .acknowledgment
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(tasks)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([LLMTaskType].self, from: data)

        XCTAssertEqual(decoded, tasks)
    }
}

/// Tests for CapabilityTier enumeration
final class CapabilityTierTests: XCTestCase {

    func testCapabilityTierOrdering() {
        // Verify tiers are properly ordered
        XCTAssertLessThan(CapabilityTier.any, CapabilityTier.tiny)
        XCTAssertLessThan(CapabilityTier.tiny, CapabilityTier.small)
        XCTAssertLessThan(CapabilityTier.small, CapabilityTier.medium)
        XCTAssertLessThan(CapabilityTier.medium, CapabilityTier.frontier)
    }

    func testCapabilityTierRawValues() {
        XCTAssertEqual(CapabilityTier.any.rawValue, 0)
        XCTAssertEqual(CapabilityTier.tiny.rawValue, 1)
        XCTAssertEqual(CapabilityTier.small.rawValue, 2)
        XCTAssertEqual(CapabilityTier.medium.rawValue, 3)
        XCTAssertEqual(CapabilityTier.frontier.rawValue, 4)
        XCTAssertEqual(CapabilityTier.embedding.rawValue, 5)
    }

    func testCapabilityTierDescriptions() {
        XCTAssertFalse(CapabilityTier.tiny.description.isEmpty)
        XCTAssertFalse(CapabilityTier.small.description.isEmpty)
        XCTAssertFalse(CapabilityTier.medium.description.isEmpty)
        XCTAssertFalse(CapabilityTier.frontier.description.isEmpty)
    }

    func testCapabilityTierMeetsRequirement() {
        // Frontier can meet any requirement
        XCTAssertTrue(CapabilityTier.frontier.meets(.tiny))
        XCTAssertTrue(CapabilityTier.frontier.meets(.small))
        XCTAssertTrue(CapabilityTier.frontier.meets(.medium))
        XCTAssertTrue(CapabilityTier.frontier.meets(.frontier))

        // Tiny can only meet tiny and any
        XCTAssertTrue(CapabilityTier.tiny.meets(.tiny))
        XCTAssertTrue(CapabilityTier.tiny.meets(.any))
        XCTAssertFalse(CapabilityTier.tiny.meets(.small))
        XCTAssertFalse(CapabilityTier.tiny.meets(.medium))
        XCTAssertFalse(CapabilityTier.tiny.meets(.frontier))
    }
}
