//
//  KBPhoneticMatcher.swift
//  UnaMentis
//
//  Phonetic matching using Double Metaphone algorithm for Knowledge Bowl
//  Catches pronunciation-based errors from STT transcription
//

import Foundation
import OSLog

// MARK: - Phonetic Matcher

/// Phonetic matching using Double Metaphone algorithm
actor KBPhoneticMatcher {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBPhoneticMatcher")

    // MARK: - Public API

    /// Generate Double Metaphone codes for a text string
    /// - Parameter text: Input text to encode
    /// - Returns: Tuple of (primary code, optional secondary code)
    nonisolated func metaphone(_ text: String) -> (primary: String, secondary: String?) {
        let cleaned = text.uppercased().filter { $0.isLetter }
        guard !cleaned.isEmpty else {
            return ("", nil)
        }

        var context = MetaphoneContext(text: cleaned)
        processInitialExceptions(&context)
        processMainLoop(&context)

        return context.result()
    }

    // MARK: - Processing Helpers

    private nonisolated func processInitialExceptions(_ context: inout MetaphoneContext) {
        // Skip initial letters that are not pronounced
        if context.stringAt(0, 2, "GN", "KN", "PN", "WR", "PS") {
            context.advanceIndex()
        }

        // Initial X is pronounced Z
        if context.charAt(0) == "X" {
            context.appendBoth("S")
            context.advanceIndex()
        }
    }

    private nonisolated func processMainLoop(_ context: inout MetaphoneContext) {
        while context.hasMore() {
            let ch = context.currentChar()
            let pos = context.currentPosition()

            processCharacter(ch, at: pos, context: &context)
            context.advanceIndex()
        }
    }

    private nonisolated func processCharacter(_ ch: Character, at pos: Int, context: inout MetaphoneContext) {
        switch ch {
        case "A", "E", "I", "O", "U", "Y":
            processVowel(at: pos, context: &context)
        case "B": processB(context: &context)
        case "C": processC(at: pos, context: &context)
        case "D": processD(at: pos, context: &context)
        case "F": processF(context: &context)
        case "G": processG(at: pos, context: &context)
        case "H": processH(at: pos, context: &context)
        case "J": processJ(at: pos, context: &context)
        case "K", "L", "M", "N": processSimple(ch, context: &context)
        case "P": processP(context: &context)
        case "Q": processQ(context: &context)
        case "R": processR(context: &context)
        case "S": processS(at: pos, context: &context)
        case "T": processT(at: pos, context: &context)
        case "V": processV(context: &context)
        case "W": processW(at: pos, context: &context)
        case "X": processX(at: pos, context: &context)
        case "Z": processZ(context: &context)
        default: break
        }
    }

    // MARK: - Character Processing

    private nonisolated func processVowel(at pos: Int, context: inout MetaphoneContext) {
        if pos == 0 {
            context.appendBoth("A")
        }
    }

    private nonisolated func processB(context: inout MetaphoneContext) {
        context.appendBoth("P")
        if context.charAt(1) == "B" {
            context.advanceIndex()
        }
    }

    private nonisolated func processC(at pos: Int, context: inout MetaphoneContext) {
        // Handle CH combinations
        if context.stringAt(pos, 2, "CH") {
            // CHR at start (Christopher, Chromosome, etc.) -> K sound
            if pos == 0 && context.stringAt(pos, 3, "CHR") {
                context.appendBoth("K")
                context.advanceIndex()
            // CHL, CHM (Chlorine, etc.) -> K sound
            } else if context.stringAt(pos, 3, "CHL", "CHM", "CHN") {
                context.appendBoth("K")
                context.advanceIndex()
            // CH followed by vowel at start -> K (Chemistry, etc.) - give both options
            } else if pos == 0 {
                context.appendPrimary("K")
                context.appendSecondary("X")
                context.advanceIndex()
            // Other CH -> X (church sound) with K as secondary
            } else {
                context.appendPrimary("X")
                context.appendSecondary("K")
                context.advanceIndex()
            }
        } else if pos == 0 && context.stringAt(pos, 2, "CE", "CI") {
            context.appendBoth("S")
        } else if context.stringAt(pos, 2, "CE", "CI", "CY") {
            context.appendBoth("S")
        } else {
            context.appendBoth("K")
        }
        if context.charAt(1) == "C" && !context.stringAt(pos, 2, "CH") {
            context.advanceIndex()
        }
    }

    private nonisolated func processD(at pos: Int, context: inout MetaphoneContext) {
        if context.stringAt(pos, 2, "DG") && (context.charAt(2) == "E" || context.charAt(2) == "I" || context.charAt(2) == "Y") {
            context.appendBoth("J")
            context.advanceIndex(by: 2)
        } else {
            context.appendBoth("T")
        }
        if context.charAt(1) == "D" {
            context.advanceIndex()
        }
    }

    private nonisolated func processF(context: inout MetaphoneContext) {
        context.appendBoth("F")
        if context.charAt(1) == "F" {
            context.advanceIndex()
        }
    }

    private nonisolated func processG(at pos: Int, context: inout MetaphoneContext) {
        if context.charAt(1) == "H" {
            if pos > 0 && !context.isVowel(context.charAt(-1)) {
                context.appendBoth("K")
            } else if pos == 0 {
                if context.charAt(2) == "I" {
                    context.appendBoth("J")
                } else {
                    context.appendBoth("K")
                }
            }
        } else if context.stringAt(pos, 2, "GN", "GNED") {
            context.advanceIndex()
        } else if context.charAt(1) == "E" || context.charAt(1) == "I" || context.charAt(1) == "Y" {
            context.appendPrimary("J")
            context.appendSecondary("K")
        } else {
            context.appendBoth("K")
        }
        if context.charAt(1) == "G" {
            context.advanceIndex()
        }
    }

    private nonisolated func processH(at pos: Int, context: inout MetaphoneContext) {
        if (context.charAt(1) != nil && context.isVowel(context.charAt(1))) && (pos == 0 || !context.isVowel(context.charAt(-1))) {
            context.appendBoth("H")
        }
    }

    private nonisolated func processJ(at pos: Int, context: inout MetaphoneContext) {
        context.appendPrimary("J")
        if pos == 0 || (context.charAt(-1) != nil && context.isVowel(context.charAt(-1))) {
            context.appendSecondary("J")
        } else {
            context.appendSecondary("A")
        }
        if context.charAt(1) == "J" {
            context.advanceIndex()
        }
    }

    private nonisolated func processSimple(_ ch: Character, context: inout MetaphoneContext) {
        context.appendBoth(String(ch))
        if context.charAt(1) == ch {
            context.advanceIndex()
        }
    }

    private nonisolated func processP(context: inout MetaphoneContext) {
        if context.charAt(1) == "H" {
            context.appendBoth("F")
            context.advanceIndex()
        } else {
            context.appendBoth("P")
        }
        if context.charAt(1) == "P" {
            context.advanceIndex()
        }
    }

    private nonisolated func processQ(context: inout MetaphoneContext) {
        context.appendBoth("K")
        if context.charAt(1) == "Q" {
            context.advanceIndex()
        }
    }

    private nonisolated func processR(context: inout MetaphoneContext) {
        context.appendBoth("R")
        if context.charAt(1) == "R" {
            context.advanceIndex()
        }
    }

    private nonisolated func processS(at pos: Int, context: inout MetaphoneContext) {
        if context.stringAt(pos, 2, "SH") {
            context.appendBoth("X")
            context.advanceIndex()
        } else if context.stringAt(pos, 3, "SIO", "SIA") {
            context.appendPrimary("S")
            context.appendSecondary("X")
        } else {
            context.appendBoth("S")
        }
        if context.charAt(1) == "S" {
            context.advanceIndex()
        }
    }

    private nonisolated func processT(at pos: Int, context: inout MetaphoneContext) {
        if context.stringAt(pos, 3, "TIA", "TIO") {
            context.appendBoth("X")
        } else if context.stringAt(pos, 2, "TH") {
            context.appendPrimary("0")
            context.appendSecondary("T")
            context.advanceIndex()
        } else if context.stringAt(pos, 2, "TCH") {
            context.appendBoth("X")
        } else {
            context.appendBoth("T")
        }
        if context.charAt(1) == "T" {
            context.advanceIndex()
        }
    }

    private nonisolated func processV(context: inout MetaphoneContext) {
        context.appendBoth("F")
        if context.charAt(1) == "V" {
            context.advanceIndex()
        }
    }

    private nonisolated func processW(at pos: Int, context: inout MetaphoneContext) {
        if pos == 0 && (context.charAt(1) != nil && context.isVowel(context.charAt(1))) {
            context.appendPrimary("A")
            context.appendSecondary("F")
        } else if context.stringAt(pos, 2, "WR") {
            context.appendBoth("R")
            context.advanceIndex()
        }
    }

    private nonisolated func processX(at pos: Int, context: inout MetaphoneContext) {
        if pos == 0 {
            context.appendBoth("S")
        } else {
            context.appendBoth("KS")
        }
    }

    private nonisolated func processZ(context: inout MetaphoneContext) {
        context.appendBoth("S")
        if context.charAt(1) == "Z" {
            context.advanceIndex()
        }
    }

    /// Check if two strings are phonetically equivalent
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: True if strings match phonetically
    nonisolated func arePhoneticMatch(_ str1: String, _ str2: String) -> Bool {
        let codes1 = metaphone(str1)
        let codes2 = metaphone(str2)

        // Empty codes (e.g., numbers only) should not match
        guard !codes1.primary.isEmpty && !codes2.primary.isEmpty else {
            return false
        }

        // Match if primary codes match, or if either secondary matches the other's primary
        if codes1.primary == codes2.primary {
            return true
        }

        if let sec1 = codes1.secondary, sec1 == codes2.primary {
            return true
        }

        if let sec2 = codes2.secondary, codes1.primary == sec2 {
            return true
        }

        if let sec1 = codes1.secondary, let sec2 = codes2.secondary, sec1 == sec2 {
            return true
        }

        return false
    }

}

// MARK: - Metaphone Context

/// Context for Double Metaphone encoding
private struct MetaphoneContext {
    let text: String
    var index: String.Index
    var primary: String = ""
    var secondary: String = ""

    init(text: String) {
        self.text = text
        self.index = text.startIndex
    }

    // MARK: - Navigation

    mutating func advanceIndex(by offset: Int = 1) {
        index = text.index(index, offsetBy: offset, limitedBy: text.endIndex) ?? text.endIndex
    }

    func hasMore() -> Bool {
        index < text.endIndex
    }

    func currentChar() -> Character {
        text[index]
    }

    func currentPosition() -> Int {
        text.distance(from: text.startIndex, to: index)
    }

    // MARK: - Character Access

    func charAt(_ offset: Int) -> Character? {
        let targetIndex = text.index(index, offsetBy: offset, limitedBy: offset < 0 ? text.startIndex : text.endIndex)
        guard let targetIndex = targetIndex, text.indices.contains(targetIndex) else {
            return nil
        }
        return text[targetIndex]
    }

    func stringAt(_ start: Int, _ length: Int, _ matches: String...) -> Bool {
        guard start >= 0 else { return false }
        let startIdx = text.index(text.startIndex, offsetBy: start, limitedBy: text.endIndex)
        guard let startIdx = startIdx else { return false }
        guard text.distance(from: startIdx, to: text.endIndex) >= length else { return false }
        let endIdx = text.index(startIdx, offsetBy: length)
        let substr = String(text[startIdx..<endIdx])
        return matches.contains(substr)
    }

    func isVowel(_ ch: Character?) -> Bool {
        guard let ch = ch else { return false }
        return "AEIOUY".contains(ch)
    }

    // MARK: - Code Building

    mutating func appendPrimary(_ code: String) {
        primary.append(code)
    }

    mutating func appendSecondary(_ code: String) {
        secondary.append(code)
    }

    mutating func appendBoth(_ code: String) {
        primary.append(code)
        secondary.append(code)
    }

    // MARK: - Result

    func result() -> (primary: String, secondary: String?) {
        let primaryCode = String(primary.prefix(4))
        let secondaryCode = secondary.isEmpty || secondary == primary ? nil : String(secondary.prefix(4))
        return (primaryCode, secondaryCode)
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBPhoneticMatcher {
    static func preview() -> KBPhoneticMatcher {
        KBPhoneticMatcher()
    }
}
#endif
