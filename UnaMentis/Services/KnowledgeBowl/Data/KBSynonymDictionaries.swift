//
//  KBSynonymDictionaries.swift
//  UnaMentis
//
//  Domain-specific synonym dictionaries for Knowledge Bowl answer validation
//  Handles common abbreviations and alternative names
//

import Foundation

// MARK: - Synonym Dictionaries

/// Domain-specific synonym dictionaries
enum KBSynonymDictionaries {
    // MARK: - Places

    static let places: [String: Set<String>] = [
        "usa": ["united states", "united states of america", "us", "america"],
        "uk": ["united kingdom", "great britain", "britain", "england"],
        "uae": ["united arab emirates"],
        "nyc": ["new york city", "new york"],
        "la": ["los angeles"],
        "sf": ["san francisco"],
        "dc": ["washington dc", "washington d.c.", "district of columbia"],
        "nz": ["new zealand"],
        "ussr": ["soviet union", "union of soviet socialist republics"],
        "prc": ["peoples republic of china", "china"],
        "drc": ["democratic republic of congo", "congo"],
        "mount": ["mt"],
        "saint": ["st"],
        "fort": ["ft"],
        "lake": ["lk"],
        "river": ["riv"],
        "mountain": ["mt", "mtn"]
    ]

    // MARK: - Scientific

    static let scientific: [String: Set<String>] = [
        "h2o": ["water", "dihydrogen monoxide"],
        "co2": ["carbon dioxide"],
        "o2": ["oxygen", "dioxygen"],
        "h2": ["hydrogen", "dihydrogen"],
        "n2": ["nitrogen", "dinitrogen"],
        "nacl": ["sodium chloride", "table salt", "salt"],
        "h2so4": ["sulfuric acid"],
        "hcl": ["hydrochloric acid"],
        "nh3": ["ammonia"],
        "ch4": ["methane"],
        "c6h12o6": ["glucose"],
        "dna": ["deoxyribonucleic acid"],
        "rna": ["ribonucleic acid"],
        "atp": ["adenosine triphosphate"],
        "co": ["carbon monoxide"],
        "no2": ["nitrogen dioxide"],
        "so2": ["sulfur dioxide"],
        "caco3": ["calcium carbonate"],
        "fe2o3": ["iron oxide", "rust"],
        "au": ["gold"],
        "ag": ["silver"],
        "fe": ["iron"],
        "cu": ["copper"],
        "pb": ["lead"],
        "hg": ["mercury"],
        "k": ["potassium"],
        "na": ["sodium"],
        "ca": ["calcium"],
        "mg": ["magnesium"]
    ]

    // MARK: - Historical

    static let historical: [String: Set<String>] = [
        "wwi": ["world war i", "world war one", "first world war", "great war", "world war 1"],
        "wwii": ["world war ii", "world war two", "second world war", "world war 2"],
        "usa": ["united states", "united states of america", "us", "america"],
        "ussr": ["soviet union", "union of soviet socialist republics"],
        "bc": ["bce", "before common era", "before christ"],
        "ad": ["ce", "common era", "anno domini"],
        "fdr": ["franklin delano roosevelt", "franklin roosevelt", "franklin d roosevelt"],
        "jfk": ["john f kennedy", "john fitzgerald kennedy"],
        "mlk": ["martin luther king", "martin luther king jr"],
        "abe": ["abraham lincoln", "lincoln"],
        "gw": ["george washington", "washington"],
        "potus": ["president of the united states", "president"],
        "scotus": ["supreme court of the united states", "supreme court"],
        "nato": ["north atlantic treaty organization"],
        "un": ["united nations"],
        "eu": ["european union"]
    ]

    // MARK: - Mathematics

    static let mathematics: [String: Set<String>] = [
        "pi": ["π", "3.14159", "3.14"],
        "e": ["eulers number", "2.71828", "2.718"],
        "phi": ["golden ratio", "φ", "1.618"],
        "sqrt": ["square root"],
        "cbrt": ["cube root"],
        "log": ["logarithm"],
        "ln": ["natural logarithm", "natural log"],
        "sin": ["sine"],
        "cos": ["cosine"],
        "tan": ["tangent"],
        "arcsin": ["inverse sine", "asin"],
        "arccos": ["inverse cosine", "acos"],
        "arctan": ["inverse tangent", "atan"]
    ]
}

// MARK: - Synonym Matcher

/// Matcher for domain-specific synonyms
actor KBSynonymMatcher {
    // MARK: - Public API

    /// Find all synonyms for a given text in a specific domain
    /// - Parameters:
    ///   - text: Input text
    ///   - type: Answer type to determine which dictionary to use
    /// - Returns: Set of synonyms (including original text)
    nonisolated func findSynonyms(_ text: String, for type: KBAnswerType) -> Set<String> {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let dictionary: [String: Set<String>]
        switch type {
        case .place:
            dictionary = KBSynonymDictionaries.places
        case .scientific:
            dictionary = KBSynonymDictionaries.scientific
        case .person, .title:
            dictionary = KBSynonymDictionaries.historical
        case .number, .date:
            dictionary = KBSynonymDictionaries.mathematics
        case .text, .multipleChoice:
            // Generic text doesn't use synonyms
            return [normalized]
        }

        // Check if text is in dictionary
        if let synonyms = dictionary[normalized] {
            var result = synonyms
            result.insert(normalized)
            return result
        }

        // Check if text is a synonym of any key
        for (key, synonyms) in dictionary where synonyms.contains(normalized) {
            var result = synonyms
            result.insert(key)
            result.insert(normalized)
            return result
        }

        // No synonyms found
        return [normalized]
    }

    /// Check if two strings are synonyms for a given answer type
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    ///   - type: Answer type to determine which dictionary to use
    /// - Returns: True if strings are synonyms
    nonisolated func areSynonyms(_ str1: String, _ str2: String, for type: KBAnswerType) -> Bool {
        let normalized1 = str1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = str2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match
        if normalized1 == normalized2 {
            return true
        }

        // Get synonyms for both
        let synonyms1 = findSynonyms(normalized1, for: type)
        let synonyms2 = findSynonyms(normalized2, for: type)

        // Check if they overlap
        return !synonyms1.isDisjoint(with: synonyms2)
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBSynonymMatcher {
    static func preview() -> KBSynonymMatcher {
        KBSynonymMatcher()
    }
}
#endif
