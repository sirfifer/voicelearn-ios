//
//  KBCreatePackView.swift
//  UnaMentis
//
//  View for creating a new local question pack by selecting questions.
//

import SwiftUI

/// View for creating a custom question pack from local questions.
struct KBCreatePackView: View {
    @Bindable var localPackStore: KBLocalPackStore
    @Environment(\.dismiss) private var dismiss

    @State private var packName: String = ""
    @State private var packDescription: String = ""
    @State private var selectedQuestionIds: Set<UUID> = []
    @State private var availableQuestions: [KBQuestion] = []
    @State private var searchText: String = ""
    @State private var selectedDomain: KBDomain?
    @State private var engine = KBQuestionEngine()
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pack info section
                packInfoSection

                Divider()

                // Question selection
                questionSelectionSection
            }
            .navigationTitle("Create Pack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createPack()
                    }
                    .disabled(packName.isEmpty || selectedQuestionIds.isEmpty)
                }
            }
            .task {
                await loadQuestions()
            }
        }
    }

    // MARK: - Pack Info Section

    private var packInfoSection: some View {
        VStack(spacing: 12) {
            TextField("Pack Name", text: $packName)
                .textFieldStyle(.roundedBorder)

            TextField("Description (optional)", text: $packDescription)
                .textFieldStyle(.roundedBorder)

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.kbMastered)
                Text("\(selectedQuestionIds.count) questions selected")
                    .font(.subheadline)
                    .foregroundColor(.kbTextSecondary)
                Spacer()
            }
        }
        .padding()
        .background(Color.kbBgSecondary)
    }

    // MARK: - Question Selection Section

    private var questionSelectionSection: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            filterBar

            // Question list
            if isLoading {
                Spacer()
                ProgressView("Loading questions...")
                Spacer()
            } else if filteredQuestions.isEmpty {
                Spacer()
                Text("No questions match your filters")
                    .foregroundColor(.kbTextSecondary)
                Spacer()
            } else {
                questionList
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.kbTextSecondary)
                TextField("Search questions...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.kbTextSecondary)
                    }
                }
            }
            .padding(8)
            .background(Color.kbBgSecondary)
            .cornerRadius(8)

            // Domain filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    domainFilterButton(nil, label: "All")
                    ForEach(KBDomain.allCases) { domain in
                        domainFilterButton(domain, label: domain.displayName)
                    }
                }
            }
        }
        .padding()
    }

    private func domainFilterButton(_ domain: KBDomain?, label: String) -> some View {
        let isSelected = selectedDomain == domain

        return Button {
            withAnimation {
                selectedDomain = domain
            }
        } label: {
            HStack(spacing: 4) {
                if let domain = domain {
                    Image(systemName: domain.icon)
                        .font(.system(size: 12))
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? (domain?.color ?? Color.kbMastered) : Color.kbBgSecondary)
            .foregroundColor(isSelected ? .white : .kbTextPrimary)
            .cornerRadius(16)
        }
    }

    // MARK: - Question List

    private var questionList: some View {
        List {
            // Select all / Deselect all
            Section {
                HStack {
                    Button {
                        selectAllFiltered()
                    } label: {
                        Text("Select All (\(filteredQuestions.count))")
                            .font(.subheadline)
                    }

                    Spacer()

                    if !selectedQuestionIds.isEmpty {
                        Button {
                            selectedQuestionIds.removeAll()
                        } label: {
                            Text("Deselect All")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            // Questions
            ForEach(filteredQuestions) { question in
                questionRow(question)
            }
        }
        .listStyle(.plain)
    }

    private func questionRow(_ question: KBQuestion) -> some View {
        let isSelected = selectedQuestionIds.contains(question.id)

        return Button {
            toggleQuestion(question)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .kbMastered : .kbTextSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    // Question text (truncated)
                    Text(question.text)
                        .font(.subheadline)
                        .foregroundColor(.kbTextPrimary)
                        .lineLimit(2)

                    // Metadata
                    HStack(spacing: 8) {
                        // Domain badge
                        HStack(spacing: 4) {
                            Image(systemName: question.domain.icon)
                                .font(.system(size: 10))
                            Text(question.domain.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(question.domain.color)

                        // Difficulty
                        Text(question.difficulty.displayName)
                            .font(.caption2)
                            .foregroundColor(.kbTextSecondary)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var filteredQuestions: [KBQuestion] {
        var questions = availableQuestions

        // Filter by domain
        if let domain = selectedDomain {
            questions = questions.filter { $0.domain == domain }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            questions = questions.filter {
                $0.text.lowercased().contains(lowercasedSearch) ||
                $0.answer.primary.lowercased().contains(lowercasedSearch)
            }
        }

        return questions
    }

    // MARK: - Actions

    private func loadQuestions() async {
        isLoading = true
        do {
            try await engine.loadBundledQuestions()
            // Get all questions from the engine
            availableQuestions = engine.questions
        } catch {
            // Handle error
        }
        isLoading = false
    }

    private func toggleQuestion(_ question: KBQuestion) {
        if selectedQuestionIds.contains(question.id) {
            selectedQuestionIds.remove(question.id)
        } else {
            selectedQuestionIds.insert(question.id)
        }
    }

    private func selectAllFiltered() {
        for question in filteredQuestions {
            selectedQuestionIds.insert(question.id)
        }
    }

    private func createPack() {
        let selectedQuestions = availableQuestions.filter { selectedQuestionIds.contains($0.id) }

        localPackStore.createPack(
            name: packName,
            description: packDescription.isEmpty ? nil : packDescription,
            questions: selectedQuestions
        )

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    KBCreatePackView(localPackStore: KBLocalPackStore())
}
