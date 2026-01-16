// UnaMentis - Module Protocol Tests
// Tests for ModuleProtocol and SpecializedModule type-erased wrapper
//
// Part of Module System Testing

import XCTest
import SwiftUI
@testable import UnaMentis

final class ModuleProtocolTests: XCTestCase {

    // MARK: - Test Module Implementation

    /// A test module that implements ModuleProtocol for testing
    struct TestModule: ModuleProtocol {
        let id: String
        let name: String
        let shortDescription: String
        let longDescription: String
        let iconName: String
        let themeColor: Color

        init(
            id: String = "test-module",
            name: String = "Test Module",
            shortDescription: String = "Short description",
            longDescription: String = "Long description for testing",
            iconName: String = "star",
            themeColor: Color = .blue
        ) {
            self.id = id
            self.name = name
            self.shortDescription = shortDescription
            self.longDescription = longDescription
            self.iconName = iconName
            self.themeColor = themeColor
        }

        @MainActor
        func makeRootView() -> AnyView {
            AnyView(Text("Root View"))
        }

        @MainActor
        func makeDashboardView() -> AnyView {
            AnyView(Text("Dashboard View"))
        }
    }

    /// A test module with custom feature flags
    struct FullFeaturedModule: ModuleProtocol {
        let id = "full-featured"
        let name = "Full Featured"
        let shortDescription = "Has all features"
        let longDescription = "A module with all features enabled"
        let iconName = "star.fill"
        let themeColor = Color.orange
        let supportsTeamMode = true
        let supportsSpeedTraining = true
        let supportsCompetitionSim = true
        let version = "2.0.0"

        @MainActor
        func makeRootView() -> AnyView {
            AnyView(Text("Full Featured Root"))
        }

        @MainActor
        func makeDashboardView() -> AnyView {
            AnyView(Text("Full Featured Dashboard"))
        }
    }

    // MARK: - ModuleProtocol Default Implementation Tests

    func testDefaultSupportsTeamMode_isFalse() {
        let module = TestModule()
        XCTAssertFalse(module.supportsTeamMode)
    }

    func testDefaultSupportsSpeedTraining_isFalse() {
        let module = TestModule()
        XCTAssertFalse(module.supportsSpeedTraining)
    }

    func testDefaultSupportsCompetitionSim_isFalse() {
        let module = TestModule()
        XCTAssertFalse(module.supportsCompetitionSim)
    }

    func testDefaultVersion_is1_0_0() {
        let module = TestModule()
        XCTAssertEqual(module.version, "1.0.0")
    }

    func testCustomFeatureFlags_areRespected() {
        let module = FullFeaturedModule()
        XCTAssertTrue(module.supportsTeamMode)
        XCTAssertTrue(module.supportsSpeedTraining)
        XCTAssertTrue(module.supportsCompetitionSim)
        XCTAssertEqual(module.version, "2.0.0")
    }

    // MARK: - ModuleProtocol Hashable Tests

    func testHashable_sameIdProducesSameHash() {
        let module1 = TestModule(id: "same-id")
        let module2 = TestModule(id: "same-id", name: "Different Name")

        XCTAssertEqual(module1.hashValue, module2.hashValue)
    }

    func testHashable_differentIdProducesDifferentHash() {
        let module1 = TestModule(id: "id-1")
        let module2 = TestModule(id: "id-2")

        XCTAssertNotEqual(module1.hashValue, module2.hashValue)
    }

    // MARK: - ModuleProtocol Equatable Tests

    func testEquatable_sameIdAreEqual() {
        let module1 = TestModule(id: "same-id")
        let module2 = TestModule(id: "same-id", name: "Different Name")

        XCTAssertEqual(module1, module2)
    }

    func testEquatable_differentIdAreNotEqual() {
        let module1 = TestModule(id: "id-1")
        let module2 = TestModule(id: "id-2")

        XCTAssertNotEqual(module1, module2)
    }

    // MARK: - SpecializedModule Wrapper Tests

    func testSpecializedModule_preservesId() {
        let original = TestModule(id: "original-id")
        let wrapped = SpecializedModule(original)

        XCTAssertEqual(wrapped.id, "original-id")
    }

    func testSpecializedModule_preservesName() {
        let original = TestModule(name: "Original Name")
        let wrapped = SpecializedModule(original)

        XCTAssertEqual(wrapped.name, "Original Name")
    }

    func testSpecializedModule_preservesShortDescription() {
        let original = TestModule(shortDescription: "Short desc")
        let wrapped = SpecializedModule(original)

        XCTAssertEqual(wrapped.shortDescription, "Short desc")
    }

    func testSpecializedModule_preservesLongDescription() {
        let original = TestModule(longDescription: "Long description text")
        let wrapped = SpecializedModule(original)

        XCTAssertEqual(wrapped.longDescription, "Long description text")
    }

    func testSpecializedModule_preservesIconName() {
        let original = TestModule(iconName: "custom.icon")
        let wrapped = SpecializedModule(original)

        XCTAssertEqual(wrapped.iconName, "custom.icon")
    }

    func testSpecializedModule_preservesThemeColor() {
        let original = TestModule(themeColor: .red)
        let wrapped = SpecializedModule(original)

        XCTAssertEqual(wrapped.themeColor, .red)
    }

    func testSpecializedModule_preservesFeatureFlags() {
        let original = FullFeaturedModule()
        let wrapped = SpecializedModule(original)

        XCTAssertTrue(wrapped.supportsTeamMode)
        XCTAssertTrue(wrapped.supportsSpeedTraining)
        XCTAssertTrue(wrapped.supportsCompetitionSim)
    }

    func testSpecializedModule_preservesVersion() {
        let original = FullFeaturedModule()
        let wrapped = SpecializedModule(original)

        XCTAssertEqual(wrapped.version, "2.0.0")
    }

    @MainActor
    func testSpecializedModule_makeRootView_works() {
        let original = TestModule()
        let wrapped = SpecializedModule(original)

        let view = wrapped.makeRootView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testSpecializedModule_makeDashboardView_works() {
        let original = TestModule()
        let wrapped = SpecializedModule(original)

        let view = wrapped.makeDashboardView()
        XCTAssertNotNil(view)
    }

    // MARK: - SpecializedModule Hashable Tests

    func testSpecializedModule_hashable_sameIdSameHash() {
        let module1 = SpecializedModule(TestModule(id: "same-id"))
        let module2 = SpecializedModule(TestModule(id: "same-id"))

        XCTAssertEqual(module1.hashValue, module2.hashValue)
    }

    func testSpecializedModule_hashable_differentIdDifferentHash() {
        let module1 = SpecializedModule(TestModule(id: "id-1"))
        let module2 = SpecializedModule(TestModule(id: "id-2"))

        XCTAssertNotEqual(module1.hashValue, module2.hashValue)
    }

    // MARK: - SpecializedModule Equatable Tests

    func testSpecializedModule_equatable_sameIdEqual() {
        let module1 = SpecializedModule(TestModule(id: "same-id"))
        let module2 = SpecializedModule(TestModule(id: "same-id"))

        XCTAssertEqual(module1, module2)
    }

    func testSpecializedModule_equatable_differentIdNotEqual() {
        let module1 = SpecializedModule(TestModule(id: "id-1"))
        let module2 = SpecializedModule(TestModule(id: "id-2"))

        XCTAssertNotEqual(module1, module2)
    }

    // MARK: - SpecializedModule Identifiable Tests

    func testSpecializedModule_identifiable_idIsCorrect() {
        let wrapped = SpecializedModule(TestModule(id: "my-id"))

        XCTAssertEqual(wrapped.id, "my-id")
    }

    // MARK: - Collection Usage Tests

    func testSpecializedModule_canBeStoredInSet() {
        let module1 = SpecializedModule(TestModule(id: "id-1"))
        let module2 = SpecializedModule(TestModule(id: "id-2"))
        let module3 = SpecializedModule(TestModule(id: "id-1"))  // Duplicate

        var set: Set<SpecializedModule> = []
        set.insert(module1)
        set.insert(module2)
        set.insert(module3)

        XCTAssertEqual(set.count, 2)  // Duplicate should not be added
    }

    func testSpecializedModule_canBeStoredInArray() {
        let modules = [
            SpecializedModule(TestModule(id: "id-1")),
            SpecializedModule(TestModule(id: "id-2")),
            SpecializedModule(FullFeaturedModule())
        ]

        XCTAssertEqual(modules.count, 3)
    }

    func testSpecializedModule_canBeUsedAsDictionaryKey() {
        let module1 = SpecializedModule(TestModule(id: "id-1"))
        let module2 = SpecializedModule(TestModule(id: "id-2"))

        var dict: [SpecializedModule: String] = [:]
        dict[module1] = "First"
        dict[module2] = "Second"

        XCTAssertEqual(dict[module1], "First")
        XCTAssertEqual(dict[module2], "Second")
    }
}
