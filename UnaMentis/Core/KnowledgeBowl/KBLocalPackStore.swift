//
//  KBLocalPackStore.swift
//  UnaMentis
//
//  Manages locally created Knowledge Bowl question packs.
//  Packs are persisted to the Documents directory as JSON.
//

import Foundation
import Logging
import SwiftUI

/// Manages creation, storage, and retrieval of local question packs.
@MainActor
@Observable
final class KBLocalPackStore {
    private(set) var localPacks: [KBPack] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    private let fileURL: URL
    private static let logger = Logger(label: "com.unamentis.kb.localpackstore")

    init() {
        // Store in Documents/kb_local_packs.json
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = documentsURL.appendingPathComponent("kb_local_packs.json")
    }

    // MARK: - Public Methods

    /// Load local packs from disk
    func load() async {
        isLoading = true
        error = nil

        do {
            localPacks = try await loadFromDisk()
            Self.logger.info("Loaded \(self.localPacks.count) local packs")
        } catch {
            // File doesn't exist yet is fine
            if (error as NSError).code != NSFileReadNoSuchFileError {
                self.error = error
                Self.logger.error("Failed to load local packs: \(error.localizedDescription)")
            }
            localPacks = []
        }

        isLoading = false
    }

    /// Create a new local pack from selected questions
    @discardableResult
    func createPack(
        name: String,
        description: String? = nil,
        questions: [KBQuestion]
    ) -> KBPack {
        // Calculate domain distribution
        var domainDistribution: [String: Int] = [:]
        var difficultyDistribution: [Int: Int] = [:]

        for question in questions {
            let domainKey = question.domain.rawValue
            domainDistribution[domainKey, default: 0] += 1

            let difficultyKey = question.difficulty.level
            difficultyDistribution[difficultyKey, default: 0] += 1
        }

        let pack = KBPack(
            id: "local-\(UUID().uuidString.prefix(8))",
            name: name,
            description: description ?? "Custom pack created on device",
            questionCount: questions.count,
            domainDistribution: domainDistribution,
            difficultyDistribution: difficultyDistribution,
            packType: .custom,
            isLocal: true,
            questionIds: questions.map { $0.id.uuidString },
            createdAt: Date(),
            updatedAt: nil
        )

        localPacks.append(pack)
        save()

        Self.logger.info("Created local pack '\(name)' with \(questions.count) questions")
        return pack
    }

    /// Update an existing local pack
    func updatePack(
        id: String,
        name: String? = nil,
        description: String? = nil,
        questions: [KBQuestion]? = nil
    ) {
        guard let index = localPacks.firstIndex(where: { $0.id == id }) else {
            Self.logger.warning("Pack not found for update: \(id)")
            return
        }

        let existing = localPacks[index]

        // Recalculate distributions if questions changed
        var domainDistribution = existing.domainDistribution
        var difficultyDistribution = existing.difficultyDistribution
        var questionIds = existing.questionIds
        var questionCount = existing.questionCount

        if let questions = questions {
            domainDistribution = [:]
            difficultyDistribution = [:]

            for question in questions {
                let domainKey = question.domain.rawValue
                domainDistribution[domainKey, default: 0] += 1

                let difficultyKey = question.difficulty.level
                difficultyDistribution[difficultyKey, default: 0] += 1
            }

            questionIds = questions.map { $0.id.uuidString }
            questionCount = questions.count
        }

        let updated = KBPack(
            id: existing.id,
            name: name ?? existing.name,
            description: description ?? existing.description,
            questionCount: questionCount,
            domainDistribution: domainDistribution,
            difficultyDistribution: difficultyDistribution,
            packType: existing.packType,
            isLocal: true,
            questionIds: questionIds,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )

        localPacks[index] = updated
        save()

        Self.logger.info("Updated local pack '\(updated.name)'")
    }

    /// Delete a local pack
    func deletePack(id: String) {
        guard let index = localPacks.firstIndex(where: { $0.id == id }) else {
            Self.logger.warning("Pack not found for deletion: \(id)")
            return
        }

        let pack = localPacks[index]
        localPacks.remove(at: index)
        save()

        Self.logger.info("Deleted local pack '\(pack.name)'")
    }

    /// Get a pack by ID
    func pack(withId id: String) -> KBPack? {
        localPacks.first { $0.id == id }
    }

    // MARK: - Private Methods

    private func loadFromDisk() async throws -> [KBPack] {
        let data = try Data(contentsOf: fileURL)
        let container = try JSONDecoder().decode(LocalPacksContainer.self, from: data)
        return container.packs
    }

    private func save() {
        Task {
            do {
                let container = LocalPacksContainer(
                    version: "1.0.0",
                    packs: localPacks
                )
                let data = try JSONEncoder().encode(container)
                try data.write(to: fileURL, options: .atomic)
                Self.logger.debug("Saved \(self.localPacks.count) local packs to disk")
            } catch {
                Self.logger.error("Failed to save local packs: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Container Type

private struct LocalPacksContainer: Codable {
    let version: String
    let packs: [KBPack]
}
