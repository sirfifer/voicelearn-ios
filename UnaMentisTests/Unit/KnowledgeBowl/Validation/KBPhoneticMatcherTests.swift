//
//  KBPhoneticMatcherTests.swift
//  UnaMentisTests
//
//  Comprehensive unit tests for phonetic matching (Double Metaphone)
//  Target: 50+ test cases covering person names, places, scientific terms
//

import XCTest
@testable import UnaMentis

@available(iOS 18.0, *)
final class KBPhoneticMatcherTests: XCTestCase {
    var matcher: KBPhoneticMatcher!

    override func setUp() async throws {
        try await super.setUp()
        matcher = KBPhoneticMatcher()
    }

    override func tearDown() async throws {
        matcher = nil
        try await super.tearDown()
    }

    // MARK: - Person Names

    func testPersonName_StephenSteven() {
        // Common spelling variation
        XCTAssertTrue(matcher.arePhoneticMatch("Stephen", "Steven"))
    }

    func testPersonName_CatherineKathryn() {
        // K/C variation
        XCTAssertTrue(matcher.arePhoneticMatch("Catherine", "Kathryn"))
    }

    func testPersonName_JohnJon() {
        // Silent H
        XCTAssertTrue(matcher.arePhoneticMatch("John", "Jon"))
    }

    func testPersonName_PhilipPhillip() {
        // Double consonant
        XCTAssertTrue(matcher.arePhoneticMatch("Philip", "Phillip"))
    }

    func testPersonName_SaraS

arah() {
        // Silent H at end
        XCTAssertTrue(matcher.arePhoneticMatch("Sara", "Sarah"))
    }

    func testPersonName_JeffreyGeoffrey() {
        // J/G variation
        XCTAssertTrue(matcher.arePhoneticMatch("Jeffrey", "Geoffrey"))
    }

    func testPersonName_KristenKristen() {
        // Exact match (should always work)
        XCTAssertTrue(matcher.arePhoneticMatch("Kristen", "Kristen"))
    }

    func testPersonName_MichaelMichael() {
        // Exact match
        XCTAssertTrue(matcher.arePhoneticMatch("Michael", "Michael"))
    }

    func testPersonName_ChristopherKristopher() {
        // Ch/K variation
        XCTAssertTrue(matcher.arePhoneticMatch("Christopher", "Kristopher"))
    }

    func testPersonName_JenniferJennifer() {
        // Exact match
        XCTAssertTrue(matcher.arePhoneticMatch("Jennifer", "Jennifer"))
    }

    // MARK: - Place Names

    func testPlaceName_PhiladelphiaFiladelfia() {
        // Ph/F variation
        XCTAssertTrue(matcher.arePhoneticMatch("Philadelphia", "Filadelfia"))
    }

    func testPlaceName_CincinnatiCincinatti() {
        // Double consonant variation
        XCTAssertTrue(matcher.arePhoneticMatch("Cincinnati", "Cincinatti"))
    }

    func testPlaceName_PittsburghPittsburg() {
        // Silent H
        XCTAssertTrue(matcher.arePhoneticMatch("Pittsburgh", "Pittsburg"))
    }

    func testPlaceName_MississippiMissisipi() {
        // Missing double consonants (should still match phonetically)
        XCTAssertTrue(matcher.arePhoneticMatch("Mississippi", "Missisipi"))
    }

    func testPlaceName_ConnecticutConneticut() {
        // Missing consonant
        XCTAssertTrue(matcher.arePhoneticMatch("Connecticut", "Conneticut"))
    }

    func testPlaceName_AlbuquerqueAlbequerque() {
        // U/E variation
        XCTAssertTrue(matcher.arePhoneticMatch("Albuquerque", "Albequerque"))
    }

    func testPlaceName_SacramentoSacramento() {
        // Exact match
        XCTAssertTrue(matcher.arePhoneticMatch("Sacramento", "Sacramento"))
    }

    func testPlaceName_ChicagoChikago() {
        // Ch/K variation
        XCTAssertTrue(matcher.arePhoneticMatch("Chicago", "Chikago"))
    }

    func testPlaceName_TucsonTuson() {
        // Silent C
        XCTAssertTrue(matcher.arePhoneticMatch("Tucson", "Tuson"))
    }

    func testPlaceName_WorcesterWooster() {
        // Different pronunciation/spelling
        XCTAssertTrue(matcher.arePhoneticMatch("Worcester", "Wooster"))
    }

    // MARK: - Scientific Terms

    func testScientific_PhotosynthesisFotosynthesis() {
        // Ph/F variation
        XCTAssertTrue(matcher.arePhoneticMatch("Photosynthesis", "Fotosynthesis"))
    }

    func testScientific_ChlorophyllClorofill() {
        // Ph/F and Ch/C variations
        XCTAssertTrue(matcher.arePhoneticMatch("Chlorophyll", "Clorofill"))
    }

    func testScientific_PneumoniaNeumon() {
        // Silent P
        XCTAssertTrue(matcher.arePhoneticMatch("Pneumonia", "Neumonia"))
    }

    func testScientific_PsychologyPsikology() {
        // Silent P and Ch/K variation
        XCTAssertTrue(matcher.arePhoneticMatch("Psychology", "Psikology"))
    }

    func testScientific_ChemistryKemistry() {
        // Ch/K variation
        XCTAssertTrue(matcher.arePhoneticMatch("Chemistry", "Kemistry"))
    }

    func testScientific_GenealogyGenealogy() {
        // Exact match
        XCTAssertTrue(matcher.arePhoneticMatch("Genealogy", "Genealogy"))
    }

    func testScientific_BacteriaBacteria() {
        // Exact match
        XCTAssertTrue(matcher.arePhoneticMatch("Bacteria", "Bacteria"))
    }

    func testScientific_ChromosomeKromosome() {
        // Ch/K variation
        XCTAssertTrue(matcher.arePhoneticMatch("Chromosome", "Kromosome"))
    }

    func testScientific_PharmacyFarmacy() {
        // Ph/F variation
        XCTAssertTrue(matcher.arePhoneticMatch("Pharmacy", "Farmacy"))
    }

    func testScientific_MitochondriaMitochondria() {
        // Exact match
        XCTAssertTrue(matcher.arePhoneticMatch("Mitochondria", "Mitochondria"))
    }

    // MARK: - Metaphone Code Generation

    func testMetaphone_Smith() {
        let (primary, _) = matcher.metaphone("Smith")
        XCTAssertEqual(primary, "SM0")  // TH -> 0
    }

    func testMetaphone_Johnson() {
        let (primary, _) = matcher.metaphone("Johnson")
        XCTAssertEqual(primary, "JNSN")
    }

    func testMetaphone_Williams() {
        let (primary, _) = matcher.metaphone("Williams")
        XCTAssertEqual(primary, "WLMS")
    }

    func testMetaphone_Jones() {
        let (primary, _) = matcher.metaphone("Jones")
        XCTAssertEqual(primary, "JNS")
    }

    func testMetaphone_Brown() {
        let (primary, _) = matcher.metaphone("Brown")
        XCTAssertEqual(primary, "PRN")  // B -> P
    }

    // MARK: - Edge Cases

    func testEdgeCase_EmptyString() {
        let (primary, secondary) = matcher.metaphone("")
        XCTAssertEqual(primary, "")
        XCTAssertNil(secondary)
    }

    func testEdgeCase_SingleCharacter() {
        let (primary, _) = matcher.metaphone("A")
        XCTAssertEqual(primary, "A")
    }

    func testEdgeCase_TwoCharacters() {
        let (primary, _) = matcher.metaphone("AB")
        XCTAssertEqual(primary, "AP")  // B -> P
    }

    func testEdgeCase_AllVowels() {
        let (primary, _) = matcher.metaphone("AEIOU")
        XCTAssertEqual(primary, "A")  // Only initial vowel kept
    }

    func testEdgeCase_AllConsonants() {
        let (primary, _) = matcher.metaphone("BCDFG")
        XCTAssertEqual(primary, "PKTF")  // Consonants mapped
    }

    // MARK: - Non-Matches

    func testNonMatch_CompletelyDifferent() {
        XCTAssertFalse(matcher.arePhoneticMatch("Apple", "Zebra"))
    }

    func testNonMatch_DifferentLength() {
        XCTAssertFalse(matcher.arePhoneticMatch("Cat", "Cathedral"))
    }

    func testNonMatch_DifferentSound() {
        XCTAssertFalse(matcher.arePhoneticMatch("Bear", "Deer"))
    }

    func testNonMatch_Antonyms() {
        XCTAssertFalse(matcher.arePhoneticMatch("Hot", "Cold"))
    }

    func testNonMatch_Numbers() {
        // Numbers aren't phonetically comparable
        XCTAssertFalse(matcher.arePhoneticMatch("123", "456"))
    }

    // MARK: - Case Insensitivity

    func testCaseInsensitive_Uppercase() {
        XCTAssertTrue(matcher.arePhoneticMatch("STEPHEN", "STEVEN"))
    }

    func testCaseInsensitive_Lowercase() {
        XCTAssertTrue(matcher.arePhoneticMatch("stephen", "steven"))
    }

    func testCaseInsensitive_MixedCase() {
        XCTAssertTrue(matcher.arePhoneticMatch("StEpHeN", "sTeVeN"))
    }

    // MARK: - Performance Tests

    func testPerformance_SingleMatch() {
        measure {
            _ = matcher.arePhoneticMatch("Christopher", "Kristopher")
        }
    }

    func testPerformance_LongString() {
        let longString = String(repeating: "Christopher", count: 10)
        measure {
            _ = matcher.metaphone(longString)
        }
    }
}
