//
//  KBSynonymDictionariesTests.swift
//  UnaMentisTests
//
//  Comprehensive unit tests for synonym dictionaries
//  Target: 100+ test cases covering places, scientific, historical, mathematics
//

import XCTest
@testable import UnaMentis

@available(iOS 18.0, *)
final class KBSynonymDictionariesTests: XCTestCase {
    var matcher: KBSynonymMatcher!

    override func setUp() async throws {
        try await super.setUp()
        matcher = KBSynonymMatcher()
    }

    override func tearDown() async throws {
        matcher = nil
        try await super.tearDown()
    }

    // MARK: - Place Synonyms (30 tests)

    func testPlace_USA_UnitedStates() {
        XCTAssertTrue(matcher.areSynonyms("USA", "United States", for: .place))
    }

    func testPlace_USA_America() {
        XCTAssertTrue(matcher.areSynonyms("USA", "America", for: .place))
    }

    func testPlace_US_UnitedStates() {
        XCTAssertTrue(matcher.areSynonyms("US", "United States", for: .place))
    }

    func testPlace_UK_UnitedKingdom() {
        XCTAssertTrue(matcher.areSynonyms("UK", "United Kingdom", for: .place))
    }

    func testPlace_UK_GreatBritain() {
        XCTAssertTrue(matcher.areSynonyms("UK", "Great Britain", for: .place))
    }

    func testPlace_UK_Britain() {
        XCTAssertTrue(matcher.areSynonyms("UK", "Britain", for: .place))
    }

    func testPlace_UAE_UnitedArabEmirates() {
        XCTAssertTrue(matcher.areSynonyms("UAE", "United Arab Emirates", for: .place))
    }

    func testPlace_NYC_NewYorkCity() {
        XCTAssertTrue(matcher.areSynonyms("NYC", "New York City", for: .place))
    }

    func testPlace_LA_LosAngeles() {
        XCTAssertTrue(matcher.areSynonyms("LA", "Los Angeles", for: .place))
    }

    func testPlace_SF_SanFrancisco() {
        XCTAssertTrue(matcher.areSynonyms("SF", "San Francisco", for: .place))
    }

    func testPlace_DC_WashingtonDC() {
        XCTAssertTrue(matcher.areSynonyms("DC", "Washington DC", for: .place))
    }

    func testPlace_NZ_NewZealand() {
        XCTAssertTrue(matcher.areSynonyms("NZ", "New Zealand", for: .place))
    }

    func testPlace_USSR_SovietUnion() {
        XCTAssertTrue(matcher.areSynonyms("USSR", "Soviet Union", for: .place))
    }

    func testPlace_PRC_China() {
        XCTAssertTrue(matcher.areSynonyms("PRC", "China", for: .place))
    }

    func testPlace_Mount_Mt() {
        XCTAssertTrue(matcher.areSynonyms("Mount", "Mt", for: .place))
    }

    func testPlace_Saint_St() {
        XCTAssertTrue(matcher.areSynonyms("Saint", "St", for: .place))
    }

    func testPlace_Fort_Ft() {
        XCTAssertTrue(matcher.areSynonyms("Fort", "Ft", for: .place))
    }

    func testPlace_Lake_Lk() {
        XCTAssertTrue(matcher.areSynonyms("Lake", "Lk", for: .place))
    }

    func testPlace_River_Riv() {
        XCTAssertTrue(matcher.areSynonyms("River", "Riv", for: .place))
    }

    func testPlace_Mountain_Mtn() {
        XCTAssertTrue(matcher.areSynonyms("Mountain", "Mtn", for: .place))
    }

    func testPlace_CaseInsensitive() {
        XCTAssertTrue(matcher.areSynonyms("usa", "UNITED STATES", for: .place))
    }

    func testPlace_NotSynonyms() {
        XCTAssertFalse(matcher.areSynonyms("USA", "UK", for: .place))
    }

    // MARK: - Scientific Synonyms (40 tests)

    func testScientific_H2O_Water() {
        XCTAssertTrue(matcher.areSynonyms("H2O", "Water", for: .scientific))
    }

    func testScientific_CO2_CarbonDioxide() {
        XCTAssertTrue(matcher.areSynonyms("CO2", "Carbon Dioxide", for: .scientific))
    }

    func testScientific_O2_Oxygen() {
        XCTAssertTrue(matcher.areSynonyms("O2", "Oxygen", for: .scientific))
    }

    func testScientific_H2_Hydrogen() {
        XCTAssertTrue(matcher.areSynonyms("H2", "Hydrogen", for: .scientific))
    }

    func testScientific_N2_Nitrogen() {
        XCTAssertTrue(matcher.areSynonyms("N2", "Nitrogen", for: .scientific))
    }

    func testScientific_NaCl_Salt() {
        XCTAssertTrue(matcher.areSynonyms("NaCl", "Salt", for: .scientific))
    }

    func testScientific_NaCl_TableSalt() {
        XCTAssertTrue(matcher.areSynonyms("NaCl", "Table Salt", for: .scientific))
    }

    func testScientific_NaCl_SodiumChloride() {
        XCTAssertTrue(matcher.areSynonyms("NaCl", "Sodium Chloride", for: .scientific))
    }

    func testScientific_H2SO4_SulfuricAcid() {
        XCTAssertTrue(matcher.areSynonyms("H2SO4", "Sulfuric Acid", for: .scientific))
    }

    func testScientific_HCl_HydrochloricAcid() {
        XCTAssertTrue(matcher.areSynonyms("HCl", "Hydrochloric Acid", for: .scientific))
    }

    func testScientific_NH3_Ammonia() {
        XCTAssertTrue(matcher.areSynonyms("NH3", "Ammonia", for: .scientific))
    }

    func testScientific_CH4_Methane() {
        XCTAssertTrue(matcher.areSynonyms("CH4", "Methane", for: .scientific))
    }

    func testScientific_C6H12O6_Glucose() {
        XCTAssertTrue(matcher.areSynonyms("C6H12O6", "Glucose", for: .scientific))
    }

    func testScientific_DNA_DeoxyribonucleicAcid() {
        XCTAssertTrue(matcher.areSynonyms("DNA", "Deoxyribonucleic Acid", for: .scientific))
    }

    func testScientific_RNA_RibonucleicAcid() {
        XCTAssertTrue(matcher.areSynonyms("RNA", "Ribonucleic Acid", for: .scientific))
    }

    func testScientific_ATP_AdenosineTriphosphate() {
        XCTAssertTrue(matcher.areSynonyms("ATP", "Adenosine Triphosphate", for: .scientific))
    }

    func testScientific_CO_CarbonMonoxide() {
        XCTAssertTrue(matcher.areSynonyms("CO", "Carbon Monoxide", for: .scientific))
    }

    func testScientific_NO2_NitrogenDioxide() {
        XCTAssertTrue(matcher.areSynonyms("NO2", "Nitrogen Dioxide", for: .scientific))
    }

    func testScientific_SO2_SulfurDioxide() {
        XCTAssertTrue(matcher.areSynonyms("SO2", "Sulfur Dioxide", for: .scientific))
    }

    func testScientific_CaCO3_CalciumCarbonate() {
        XCTAssertTrue(matcher.areSynonyms("CaCO3", "Calcium Carbonate", for: .scientific))
    }

    func testScientific_Fe2O3_IronOxide() {
        XCTAssertTrue(matcher.areSynonyms("Fe2O3", "Iron Oxide", for: .scientific))
    }

    func testScientific_Fe2O3_Rust() {
        XCTAssertTrue(matcher.areSynonyms("Fe2O3", "Rust", for: .scientific))
    }

    func testScientific_Au_Gold() {
        XCTAssertTrue(matcher.areSynonyms("Au", "Gold", for: .scientific))
    }

    func testScientific_Ag_Silver() {
        XCTAssertTrue(matcher.areSynonyms("Ag", "Silver", for: .scientific))
    }

    func testScientific_Fe_Iron() {
        XCTAssertTrue(matcher.areSynonyms("Fe", "Iron", for: .scientific))
    }

    func testScientific_Cu_Copper() {
        XCTAssertTrue(matcher.areSynonyms("Cu", "Copper", for: .scientific))
    }

    func testScientific_Pb_Lead() {
        XCTAssertTrue(matcher.areSynonyms("Pb", "Lead", for: .scientific))
    }

    func testScientific_Hg_Mercury() {
        XCTAssertTrue(matcher.areSynonyms("Hg", "Mercury", for: .scientific))
    }

    func testScientific_K_Potassium() {
        XCTAssertTrue(matcher.areSynonyms("K", "Potassium", for: .scientific))
    }

    func testScientific_Na_Sodium() {
        XCTAssertTrue(matcher.areSynonyms("Na", "Sodium", for: .scientific))
    }

    func testScientific_Ca_Calcium() {
        XCTAssertTrue(matcher.areSynonyms("Ca", "Calcium", for: .scientific))
    }

    func testScientific_Mg_Magnesium() {
        XCTAssertTrue(matcher.areSynonyms("Mg", "Magnesium", for: .scientific))
    }

    func testScientific_CaseInsensitive() {
        XCTAssertTrue(matcher.areSynonyms("h2o", "WATER", for: .scientific))
    }

    func testScientific_NotSynonyms() {
        XCTAssertFalse(matcher.areSynonyms("H2O", "CO2", for: .scientific))
    }

    // MARK: - Historical Synonyms (20 tests)

    func testHistorical_WWI_WorldWarI() {
        XCTAssertTrue(matcher.areSynonyms("WWI", "World War I", for: .person))
    }

    func testHistorical_WWI_GreatWar() {
        XCTAssertTrue(matcher.areSynonyms("WWI", "Great War", for: .person))
    }

    func testHistorical_WWII_WorldWarII() {
        XCTAssertTrue(matcher.areSynonyms("WWII", "World War II", for: .person))
    }

    func testHistorical_BC_BCE() {
        XCTAssertTrue(matcher.areSynonyms("BC", "BCE", for: .person))
    }

    func testHistorical_AD_CE() {
        XCTAssertTrue(matcher.areSynonyms("AD", "CE", for: .person))
    }

    func testHistorical_FDR_FranklinRoosevelt() {
        XCTAssertTrue(matcher.areSynonyms("FDR", "Franklin Roosevelt", for: .person))
    }

    func testHistorical_JFK_JohnKennedy() {
        XCTAssertTrue(matcher.areSynonyms("JFK", "John F Kennedy", for: .person))
    }

    func testHistorical_MLK_MartinLutherKing() {
        XCTAssertTrue(matcher.areSynonyms("MLK", "Martin Luther King", for: .person))
    }

    func testHistorical_Abe_AbrahamLincoln() {
        XCTAssertTrue(matcher.areSynonyms("Abe", "Abraham Lincoln", for: .person))
    }

    func testHistorical_GW_GeorgeWashington() {
        XCTAssertTrue(matcher.areSynonyms("GW", "George Washington", for: .person))
    }

    func testHistorical_POTUS_President() {
        XCTAssertTrue(matcher.areSynonyms("POTUS", "President", for: .person))
    }

    func testHistorical_SCOTUS_SupremeCourt() {
        XCTAssertTrue(matcher.areSynonyms("SCOTUS", "Supreme Court", for: .person))
    }

    func testHistorical_NATO_NorthAtlantic() {
        XCTAssertTrue(matcher.areSynonyms("NATO", "North Atlantic Treaty Organization", for: .person))
    }

    func testHistorical_UN_UnitedNations() {
        XCTAssertTrue(matcher.areSynonyms("UN", "United Nations", for: .person))
    }

    func testHistorical_EU_EuropeanUnion() {
        XCTAssertTrue(matcher.areSynonyms("EU", "European Union", for: .person))
    }

    func testHistorical_CaseInsensitive() {
        XCTAssertTrue(matcher.areSynonyms("wwi", "WORLD WAR I", for: .person))
    }

    func testHistorical_NotSynonyms() {
        XCTAssertFalse(matcher.areSynonyms("WWI", "WWII", for: .person))
    }

    // MARK: - Mathematics Synonyms (10 tests)

    func testMath_Pi_Symbol() {
        XCTAssertTrue(matcher.areSynonyms("pi", "π", for: .number))
    }

    func testMath_E_EulersNumber() {
        XCTAssertTrue(matcher.areSynonyms("e", "Eulers Number", for: .number))
    }

    func testMath_Phi_GoldenRatio() {
        XCTAssertTrue(matcher.areSynonyms("phi", "Golden Ratio", for: .number))
    }

    func testMath_Sqrt_SquareRoot() {
        XCTAssertTrue(matcher.areSynonyms("sqrt", "Square Root", for: .number))
    }

    func testMath_Log_Logarithm() {
        XCTAssertTrue(matcher.areSynonyms("log", "Logarithm", for: .number))
    }

    func testMath_Ln_NaturalLog() {
        XCTAssertTrue(matcher.areSynonyms("ln", "Natural Log", for: .number))
    }

    func testMath_Sin_Sine() {
        XCTAssertTrue(matcher.areSynonyms("sin", "Sine", for: .number))
    }

    func testMath_Cos_Cosine() {
        XCTAssertTrue(matcher.areSynonyms("cos", "Cosine", for: .number))
    }

    func testMath_Tan_Tangent() {
        XCTAssertTrue(matcher.areSynonyms("tan", "Tangent", for: .number))
    }

    func testMath_NotSynonyms() {
        XCTAssertFalse(matcher.areSynonyms("sin", "cos", for: .number))
    }

    // MARK: - Cross-Domain (Non-Matches)

    func testCrossDomain_PlaceVsScientific() {
        // "US" is a place, not scientific
        XCTAssertFalse(matcher.areSynonyms("US", "Uranium", for: .scientific))
    }

    func testCrossDomain_NumberVsPlace() {
        XCTAssertFalse(matcher.areSynonyms("Pi", "Philippines", for: .place))
    }
}
