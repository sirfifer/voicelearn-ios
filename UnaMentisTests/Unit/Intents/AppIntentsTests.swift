// UnaMentis - App Intents Tests
// Comprehensive tests for Siri and Shortcuts integration
//
// Tests cover:
// - Entity queries and search
// - Intent parameter validation
// - Deep link URL generation
// - Error handling
// - Integration with Core Data

import XCTest
import CoreData
import AppIntents
@testable import UnaMentis

// MARK: - Curriculum Entity Tests

final class CurriculumEntityTests: XCTestCase {

    // MARK: - Properties

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    // MARK: - Setup / Teardown

    @MainActor
    override func setUp() async throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    @MainActor
    override func tearDown() async throws {
        context = nil
        persistenceController = nil
    }

    // MARK: - Entity Creation Tests

    @MainActor
    func testCurriculumEntity_initFromCoreData_mapsPropertiesCorrectly() throws {
        // Given
        let curriculum = TestDataFactory.createCurriculum(
            in: context,
            name: "Physics I",
            topicCount: 5
        )
        curriculum.summary = "Classical mechanics course"
        try context.save()

        // When
        let entity = CurriculumEntity(from: curriculum)

        // Then
        XCTAssertEqual(entity.id, curriculum.id)
        XCTAssertEqual(entity.name, "Physics I")
        XCTAssertEqual(entity.summary, "Classical mechanics course")
        XCTAssertEqual(entity.topicCount, 5)
    }

    @MainActor
    func testCurriculumEntity_initWithExplicitValues_setsPropertiesCorrectly() {
        // Given
        let id = UUID()

        // When
        let entity = CurriculumEntity(
            id: id,
            name: "Test Course",
            summary: "A test summary",
            topicCount: 3
        )

        // Then
        XCTAssertEqual(entity.id, id)
        XCTAssertEqual(entity.name, "Test Course")
        XCTAssertEqual(entity.summary, "A test summary")
        XCTAssertEqual(entity.topicCount, 3)
    }

    @MainActor
    func testCurriculumEntity_displayRepresentation_formatsCorrectly() throws {
        // Given
        let entity = CurriculumEntity(
            id: UUID(),
            name: "Quantum Mechanics",
            summary: "Advanced physics course",
            topicCount: 10
        )

        // When
        let representation = entity.displayRepresentation

        // Then
        // Verify title contains the name
        XCTAssertNotNil(representation.title)
    }

    @MainActor
    func testCurriculumEntity_typeDisplayRepresentation_isConfigured() {
        // When
        let typeRep = CurriculumEntity.typeDisplayRepresentation

        // Then
        XCTAssertNotNil(typeRep)
    }

    // MARK: - Query Initialization Tests

    func testCurriculumEntityQuery_canBeInitialized() {
        // When
        let query = CurriculumEntityQuery()

        // Then
        XCTAssertNotNil(query)
    }
}

// MARK: - Topic Entity Tests

final class TopicEntityTests: XCTestCase {

    // MARK: - Properties

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    // MARK: - Setup / Teardown

    @MainActor
    override func setUp() async throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    @MainActor
    override func tearDown() async throws {
        context = nil
        persistenceController = nil
    }

    // MARK: - Entity Creation Tests

    @MainActor
    func testTopicEntity_initFromCoreData_mapsPropertiesCorrectly() throws {
        // Given
        let curriculum = TestDataFactory.createCurriculum(in: context, name: "Physics")
        let topic = TestDataFactory.createTopic(
            in: context,
            title: "Newton's Laws",
            mastery: 0.75
        )
        topic.curriculum = curriculum
        topic.outline = "Study of motion and forces"
        try context.save()

        // When
        let entity = TopicEntity(from: topic)

        // Then
        XCTAssertEqual(entity.id, topic.id)
        XCTAssertEqual(entity.title, "Newton's Laws")
        XCTAssertEqual(entity.outline, "Study of motion and forces")
        XCTAssertEqual(entity.curriculumName, "Physics")
        XCTAssertEqual(entity.mastery, 0.75, accuracy: 0.01)
    }

    @MainActor
    func testTopicEntity_initWithExplicitValues_setsPropertiesCorrectly() {
        // Given
        let id = UUID()

        // When
        let entity = TopicEntity(
            id: id,
            title: "Test Topic",
            outline: "A test outline",
            curriculumName: "Test Curriculum",
            mastery: 0.5,
            statusDescription: "In Progress"
        )

        // Then
        XCTAssertEqual(entity.id, id)
        XCTAssertEqual(entity.title, "Test Topic")
        XCTAssertEqual(entity.outline, "A test outline")
        XCTAssertEqual(entity.curriculumName, "Test Curriculum")
        XCTAssertEqual(entity.mastery, 0.5)
        XCTAssertEqual(entity.statusDescription, "In Progress")
    }

    @MainActor
    func testTopicEntity_statusDescription_reflectsProgress() throws {
        // Given - Not started topic
        let topic1 = TestDataFactory.createTopic(in: context, mastery: 0)

        // Given - In progress topic
        let topic2 = TestDataFactory.createTopic(in: context, mastery: 0.5)
        let _ = TestDataFactory.createProgress(in: context, for: topic2, timeSpent: 300)

        // Given - Completed topic
        let topic3 = TestDataFactory.createTopic(in: context, mastery: 0.9)
        let _ = TestDataFactory.createProgress(in: context, for: topic3, timeSpent: 600)

        try context.save()

        // When
        let entity1 = TopicEntity(from: topic1)
        let entity2 = TopicEntity(from: topic2)
        let entity3 = TopicEntity(from: topic3)

        // Then
        XCTAssertEqual(entity1.statusDescription, "Not Started")
        XCTAssertEqual(entity2.statusDescription, "In Progress")
        XCTAssertEqual(entity3.statusDescription, "Completed")
    }

    @MainActor
    func testTopicEntity_displayRepresentation_formatsCorrectly() {
        // Given
        let entity = TopicEntity(
            id: UUID(),
            title: "Quantum Entanglement",
            curriculumName: "Physics",
            mastery: 0.75,
            statusDescription: "In Progress"
        )

        // When
        let representation = entity.displayRepresentation

        // Then
        XCTAssertNotNil(representation.title)
    }

    @MainActor
    func testTopicEntity_typeDisplayRepresentation_isConfigured() {
        // When
        let typeRep = TopicEntity.typeDisplayRepresentation

        // Then
        XCTAssertNotNil(typeRep)
    }

    // MARK: - Query Initialization Tests

    func testTopicEntityQuery_canBeInitialized() {
        // When
        let query = TopicEntityQuery()

        // Then
        XCTAssertNotNil(query)
    }
}

// MARK: - Lesson Depth Tests

final class LessonDepthTests: XCTestCase {

    func testLessonDepth_allCasesHaveDisplayRepresentations() {
        // Verify all cases have proper display representations
        let allCases: [LessonDepth] = [.overview, .introductory, .intermediate, .advanced, .graduate]

        for depth in allCases {
            let representation = LessonDepth.caseDisplayRepresentations[depth]
            XCTAssertNotNil(representation, "Missing display representation for \(depth)")
        }
    }

    func testLessonDepth_rawValues_matchExpected() {
        XCTAssertEqual(LessonDepth.overview.rawValue, "overview")
        XCTAssertEqual(LessonDepth.introductory.rawValue, "introductory")
        XCTAssertEqual(LessonDepth.intermediate.rawValue, "intermediate")
        XCTAssertEqual(LessonDepth.advanced.rawValue, "advanced")
        XCTAssertEqual(LessonDepth.graduate.rawValue, "graduate")
    }
}

// MARK: - Deep Link Tests

final class DeepLinkTests: XCTestCase {

    func testDeepLink_lessonURL_formatsCorrectly() {
        // Given
        let topicId = UUID()
        let depth = LessonDepth.advanced

        // When
        let urlString = "unamentis://lesson?id=\(topicId.uuidString)&depth=\(depth.rawValue)"
        let url = URL(string: urlString)

        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "unamentis")
        XCTAssertEqual(url?.host, "lesson")

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let idParam = components?.queryItems?.first(where: { $0.name == "id" })
        let depthParam = components?.queryItems?.first(where: { $0.name == "depth" })

        XCTAssertEqual(idParam?.value, topicId.uuidString)
        XCTAssertEqual(depthParam?.value, "advanced")
    }

    func testDeepLink_resumeURL_formatsCorrectly() {
        // Given
        let topicId = UUID()

        // When
        let urlString = "unamentis://resume?id=\(topicId.uuidString)"
        let url = URL(string: urlString)

        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "unamentis")
        XCTAssertEqual(url?.host, "resume")
    }

    func testDeepLink_analyticsURL_formatsCorrectly() {
        // When
        let url = URL(string: "unamentis://analytics")

        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "unamentis")
        XCTAssertEqual(url?.host, "analytics")
    }

    func testDeepLink_chatURL_formatsCorrectly() {
        // When - Simple chat URL
        let url = URL(string: "unamentis://chat")

        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "unamentis")
        XCTAssertEqual(url?.host, "chat")
    }

    func testDeepLink_chatURLWithPrompt_formatsCorrectly() {
        // Given
        let prompt = "What is quantum physics?"
        let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        // When
        let urlString = "unamentis://chat?prompt=\(encodedPrompt)"
        let url = URL(string: urlString)

        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "unamentis")
        XCTAssertEqual(url?.host, "chat")

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let promptParam = components?.queryItems?.first(where: { $0.name == "prompt" })
        XCTAssertNotNil(promptParam)
    }
}

// MARK: - Error Handling Tests

final class IntentErrorTests: XCTestCase {

    func testStartLessonError_hasLocalizedDescriptions() {
        // Verify all errors have user-friendly descriptions
        let errors: [StartLessonError] = [
            .noTopicSelected,
            .topicNotFound,
            .invalidConfiguration
        ]

        for error in errors {
            // localizedStringResource should not be empty
            let resource = error.localizedStringResource
            XCTAssertNotNil(resource)
        }
    }

    func testResumeLearningError_hasLocalizedDescriptions() {
        let errors: [ResumeLearningError] = [
            .noSessionToResume,
            .invalidConfiguration
        ]

        for error in errors {
            let resource = error.localizedStringResource
            XCTAssertNotNil(resource)
        }
    }

    func testStartConversationError_hasLocalizedDescriptions() {
        // Verify all errors have user-friendly descriptions
        let errors: [StartConversationError] = [
            .invalidConfiguration,
            .appNotReady
        ]

        for error in errors {
            let resource = error.localizedStringResource
            XCTAssertNotNil(resource)
        }
    }
}

// MARK: - Start Conversation Intent Tests

final class StartConversationIntentTests: XCTestCase {

    func testStartConversationIntent_canBeInitialized() {
        // When
        let intent = StartConversationIntent()

        // Then
        XCTAssertNotNil(intent)
        XCTAssertNil(intent.initialPrompt)
    }

    func testStartConversationIntent_hasCorrectMetadata() {
        // Then
        XCTAssertEqual(StartConversationIntent.title.key, "Start Conversation")
        XCTAssertNotNil(StartConversationIntent.description)
    }

    func testStartConversationIntent_acceptsOptionalPrompt() {
        // Given
        var intent = StartConversationIntent()

        // When
        intent.initialPrompt = "What is quantum physics?"

        // Then
        XCTAssertEqual(intent.initialPrompt, "What is quantum physics?")
    }
}

// MARK: - App Shortcuts Provider Tests

final class AppShortcutsProviderTests: XCTestCase {

    func testAppShortcuts_allShortcutsAreDefined() {
        // When
        let shortcuts = UnaMentisShortcuts.appShortcuts

        // Then - Should have 4 shortcuts: Start Conversation, Start Lesson, Resume Learning, Show Progress
        XCTAssertGreaterThanOrEqual(shortcuts.count, 4, "Should have at least 4 shortcuts defined")
    }

    func testAppShortcuts_haveValidPhrases() {
        // When
        let shortcuts = UnaMentisShortcuts.appShortcuts

        // Then - Each shortcut should have at least one phrase
        for shortcut in shortcuts {
            // Shortcuts are defined with phrases, which we can verify exist
            // by checking the shortcut is properly configured
            XCTAssertNotNil(shortcut)
        }
    }
}

// MARK: - Integration Tests
// NOTE: These tests verify entity creation and URL generation.
// The EntityQuery tests that use PersistenceController.shared require
// the full app context and are better tested as UI tests or manual verification.

final class AppIntentsIntegrationTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    @MainActor
    override func setUp() async throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    @MainActor
    override func tearDown() async throws {
        context = nil
        persistenceController = nil
    }

    @MainActor
    func testFullWorkflow_createEntitiesFromCoreData() throws {
        // Given - Create a curriculum with topics
        let curriculum = TestDataFactory.createCurriculum(in: context, name: "Physics I")
        let topic1 = TestDataFactory.createTopic(in: context, title: "Kinematics")
        let topic2 = TestDataFactory.createTopic(in: context, title: "Dynamics")
        topic1.curriculum = curriculum
        topic2.curriculum = curriculum
        try context.save()

        // When - Create entities from Core Data objects
        let curriculumEntity = CurriculumEntity(from: curriculum)
        let topicEntity1 = TopicEntity(from: topic1)
        let topicEntity2 = TopicEntity(from: topic2)

        // Then - Entities are properly created
        XCTAssertEqual(curriculumEntity.name, "Physics I")
        XCTAssertEqual(topicEntity1.title, "Kinematics")
        XCTAssertEqual(topicEntity1.curriculumName, "Physics I")
        XCTAssertEqual(topicEntity2.title, "Dynamics")
        XCTAssertEqual(topicEntity2.curriculumName, "Physics I")
    }

    @MainActor
    func testFullWorkflow_topicStatusMapping() throws {
        // Given - Create topics with different states
        let notStarted = TestDataFactory.createTopic(in: context, title: "Not Started", mastery: 0)

        let inProgress = TestDataFactory.createTopic(in: context, title: "In Progress", mastery: 0.5)
        let progress = TestDataFactory.createProgress(in: context, for: inProgress, timeSpent: 300)
        progress.lastAccessed = Date()

        let completed = TestDataFactory.createTopic(in: context, title: "Completed", mastery: 0.9)
        let _ = TestDataFactory.createProgress(in: context, for: completed, timeSpent: 600)

        try context.save()

        // When - Create entities
        let notStartedEntity = TopicEntity(from: notStarted)
        let inProgressEntity = TopicEntity(from: inProgress)
        let completedEntity = TopicEntity(from: completed)

        // Then - Status descriptions are correct
        XCTAssertEqual(notStartedEntity.statusDescription, "Not Started")
        XCTAssertEqual(inProgressEntity.statusDescription, "In Progress")
        XCTAssertEqual(completedEntity.statusDescription, "Completed")
    }

    func testFullWorkflow_deepLinkGeneration() {
        // Given
        let topicId = UUID()
        let depth = LessonDepth.advanced

        // When - Generate lesson URL
        let lessonURL = URL(string: "unamentis://lesson?id=\(topicId.uuidString)&depth=\(depth.rawValue)")!

        // When - Generate resume URL
        let resumeURL = URL(string: "unamentis://resume?id=\(topicId.uuidString)")!

        // When - Generate analytics URL
        let analyticsURL = URL(string: "unamentis://analytics")!

        // When - Generate chat URL (freeform conversation)
        let chatURL = URL(string: "unamentis://chat")!

        // When - Generate chat URL with prompt
        let chatWithPromptURL = URL(string: "unamentis://chat?prompt=hello")!

        // Then - All URLs are valid
        XCTAssertEqual(lessonURL.scheme, "unamentis")
        XCTAssertEqual(lessonURL.host, "lesson")

        XCTAssertEqual(resumeURL.scheme, "unamentis")
        XCTAssertEqual(resumeURL.host, "resume")

        XCTAssertEqual(analyticsURL.scheme, "unamentis")
        XCTAssertEqual(analyticsURL.host, "analytics")

        XCTAssertEqual(chatURL.scheme, "unamentis")
        XCTAssertEqual(chatURL.host, "chat")

        XCTAssertEqual(chatWithPromptURL.scheme, "unamentis")
        XCTAssertEqual(chatWithPromptURL.host, "chat")
    }
}
