//
//  KBLinguisticMatcher.swift
//  UnaMentis
//
//  Linguistic matching using Apple's Natural Language framework
//  Provides lemmatization and key term extraction for iOS
//

import Foundation
import NaturalLanguage
import OSLog

// MARK: - Linguistic Matcher

/// Linguistic matching using Apple Natural Language framework
actor KBLinguisticMatcher {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBLinguisticMatcher")

    // MARK: - Public API

    /// Lemmatize text (reduce words to base forms)
    /// - Parameter text: Input text
    /// - Returns: Lemmatized text
    nonisolated func lemmatize(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text

        var lemmatized: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma) { tag, tokenRange in
            // Use the lemma if available, otherwise use the original word
            let word = tag?.rawValue ?? String(text[tokenRange])
            lemmatized.append(word)
            return true
        }

        return lemmatized.joined(separator: " ")
    }

    /// Extract key nouns and verbs for semantic core matching
    /// - Parameter text: Input text
    /// - Returns: Array of key terms
    nonisolated func extractKeyTerms(_ text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var keyTerms: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            guard let tag = tag else { return true }

            // Extract nouns and verbs as key terms
            if tag == .noun || tag == .verb {
                let term = String(text[tokenRange])
                keyTerms.append(term.lowercased())
            }

            return true
        }

        return keyTerms
    }

    /// Check if two texts share key semantic terms
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: True if they share significant key terms
    nonisolated func shareKeyTerms(_ str1: String, _ str2: String) -> Bool {
        let terms1 = Set(extractKeyTerms(str1))
        let terms2 = Set(extractKeyTerms(str2))

        guard !terms1.isEmpty && !terms2.isEmpty else {
            return false
        }

        let intersection = terms1.intersection(terms2)
        let union = terms1.union(terms2)

        // Require at least 50% overlap
        let overlap = Float(intersection.count) / Float(union.count)
        return overlap >= 0.5
    }

    /// Check if two strings are equivalent after lemmatization
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: True if lemmatized forms match
    nonisolated func areLemmasEquivalent(_ str1: String, _ str2: String) -> Bool {
        let lemma1 = lemmatize(str1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        let lemma2 = lemmatize(str2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))

        return lemma1 == lemma2
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBLinguisticMatcher {
    static func preview() -> KBLinguisticMatcher {
        KBLinguisticMatcher()
    }
}
#endif
