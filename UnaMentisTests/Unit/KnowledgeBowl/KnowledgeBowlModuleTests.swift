// UnaMentis - Knowledge Bowl Module Tests
// Tests for KnowledgeBowlModule and KBDomain
//
// Part of Knowledge Bowl Module Testing

import XCTest
import SwiftUI
@testable import UnaMentis

final class KnowledgeBowlModuleTests: XCTestCase {

    // MARK: - KnowledgeBowlModule Tests

    func testModule_hasCorrectId() {
        let module = KnowledgeBowlModule()
        XCTAssertEqual(module.id, "knowledge-bowl")
    }

    func testModule_hasCorrectName() {
        let module = KnowledgeBowlModule()
        XCTAssertEqual(module.name, "Knowledge Bowl")
    }

    func testModule_hasShortDescription() {
        let module = KnowledgeBowlModule()
        XCTAssertFalse(module.shortDescription.isEmpty)
    }

    func testModule_hasLongDescription() {
        let module = KnowledgeBowlModule()
        XCTAssertFalse(module.longDescription.isEmpty)
        XCTAssertGreaterThan(module.longDescription.count, module.shortDescription.count)
    }

    func testModule_hasIconName() {
        let module = KnowledgeBowlModule()
        XCTAssertEqual(module.iconName, "brain.head.profile")
    }

    func testModule_hasThemeColor() {
        let module = KnowledgeBowlModule()
        XCTAssertEqual(module.themeColor, Color.purple)
    }

    func testModule_supportsTeamMode() {
        let module = KnowledgeBowlModule()
        XCTAssertTrue(module.supportsTeamMode)
    }

    func testModule_supportsSpeedTraining() {
        let module = KnowledgeBowlModule()
        XCTAssertTrue(module.supportsSpeedTraining)
    }

    func testModule_supportsCompetitionSim() {
        let module = KnowledgeBowlModule()
        XCTAssertTrue(module.supportsCompetitionSim)
    }

    func testModule_hasVersion() {
        let module = KnowledgeBowlModule()
        XCTAssertEqual(module.version, "1.0.0")
    }

    @MainActor
    func testModule_makeRootView_returnsAnyView() {
        let module = KnowledgeBowlModule()
        let view = module.makeRootView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testModule_makeDashboardView_returnsAnyView() {
        let module = KnowledgeBowlModule()
        let view = module.makeDashboardView()
        XCTAssertNotNil(view)
    }

    func testModule_hashable_sameIdProducesSameHash() {
        let module1 = KnowledgeBowlModule()
        let module2 = KnowledgeBowlModule()

        XCTAssertEqual(module1.hashValue, module2.hashValue)
    }

    func testModule_equatable_sameIdIsEqual() {
        let module1 = KnowledgeBowlModule()
        let module2 = KnowledgeBowlModule()

        XCTAssertEqual(module1, module2)
    }

    // MARK: - KBDomain Tests

    func testDomain_allCases_has12Domains() {
        XCTAssertEqual(KBDomain.allCases.count, 12)
    }

    func testDomain_allCases_containsExpectedDomains() {
        let domains = Set(KBDomain.allCases.map { $0.rawValue })

        XCTAssertTrue(domains.contains("Science"))
        XCTAssertTrue(domains.contains("Mathematics"))
        XCTAssertTrue(domains.contains("Literature"))
        XCTAssertTrue(domains.contains("History"))
        XCTAssertTrue(domains.contains("Social Studies"))
        XCTAssertTrue(domains.contains("Arts"))
        XCTAssertTrue(domains.contains("Current Events"))
        XCTAssertTrue(domains.contains("Language"))
        XCTAssertTrue(domains.contains("Technology"))
        XCTAssertTrue(domains.contains("Pop Culture"))
        XCTAssertTrue(domains.contains("Religion & Philosophy"))
        XCTAssertTrue(domains.contains("Miscellaneous"))
    }

    func testDomain_id_equalsRawValue() {
        for domain in KBDomain.allCases {
            XCTAssertEqual(domain.id, domain.rawValue)
        }
    }

    func testDomain_weights_sumToOne() {
        let totalWeight = KBDomain.allCases.reduce(0) { $0 + $1.weight }
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.001)
    }

    func testDomain_weights_arePositive() {
        for domain in KBDomain.allCases {
            XCTAssertGreaterThan(domain.weight, 0)
        }
    }

    func testDomain_science_hasHighestWeight() {
        let maxWeight = KBDomain.allCases.map { $0.weight }.max()!
        XCTAssertEqual(KBDomain.science.weight, maxWeight)
    }

    func testDomain_iconName_isNotEmpty() {
        for domain in KBDomain.allCases {
            XCTAssertFalse(domain.iconName.isEmpty, "Domain \(domain.rawValue) should have an icon")
        }
    }

    func testDomain_iconName_areValidSFSymbols() {
        // These are the expected SF Symbol names
        let expectedIcons: [KBDomain: String] = [
            .science: "atom",
            .mathematics: "function",
            .literature: "book.closed",
            .history: "clock.arrow.circlepath",
            .socialStudies: "globe.americas",
            .arts: "paintpalette",
            .currentEvents: "newspaper",
            .language: "character.book.closed",
            .technology: "cpu",
            .popCulture: "star",
            .religionPhilosophy: "sparkles",
            .miscellaneous: "puzzlepiece"
        ]

        for domain in KBDomain.allCases {
            XCTAssertEqual(
                domain.iconName,
                expectedIcons[domain],
                "Domain \(domain.rawValue) has unexpected icon"
            )
        }
    }

    func testDomain_color_isNotNil() {
        for domain in KBDomain.allCases {
            // Just verify that accessing the color doesn't crash
            _ = domain.color
        }
    }

    func testDomain_subcategories_areNotEmpty() {
        for domain in KBDomain.allCases {
            XCTAssertFalse(
                domain.subcategories.isEmpty,
                "Domain \(domain.rawValue) should have subcategories"
            )
        }
    }

    func testDomain_subcategories_haveValidContent() {
        for domain in KBDomain.allCases {
            for subcategory in domain.subcategories {
                XCTAssertFalse(
                    subcategory.isEmpty,
                    "Subcategory in \(domain.rawValue) should not be empty"
                )
            }
        }
    }

    func testDomain_science_hasExpectedSubcategories() {
        let expected = ["Biology", "Chemistry", "Physics", "Earth Science", "Astronomy"]
        XCTAssertEqual(KBDomain.science.subcategories, expected)
    }

    func testDomain_mathematics_hasExpectedSubcategories() {
        let expected = ["Arithmetic", "Algebra", "Geometry", "Calculus", "Statistics"]
        XCTAssertEqual(KBDomain.mathematics.subcategories, expected)
    }

    func testDomain_literature_hasExpectedSubcategories() {
        let expected = ["American", "British", "World", "Poetry", "Drama"]
        XCTAssertEqual(KBDomain.literature.subcategories, expected)
    }

    func testDomain_history_hasExpectedSubcategories() {
        let expected = ["US", "World", "Ancient", "Modern", "Military"]
        XCTAssertEqual(KBDomain.history.subcategories, expected)
    }
}
