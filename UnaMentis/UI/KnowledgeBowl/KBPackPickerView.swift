//
//  KBPackPickerView.swift
//  UnaMentis
//
//  Pack picker view for selecting question packs.
//  Shows server packs, local packs, and option to create new packs.
//

import SwiftUI

/// View for selecting a question pack for practice.
struct KBPackPickerView: View {
    @Binding var selectedPackId: String?
    @State private var packService = KBPackService()
    @Bindable var localPackStore: KBLocalPackStore
    @State private var showingCreatePack = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // All Questions option
                allQuestionsSection

                // Server packs
                if !packService.packs.isEmpty {
                    serverPacksSection
                }

                // Local packs
                if !localPackStore.localPacks.isEmpty {
                    localPacksSection
                }

                // Loading state
                if packService.isLoading {
                    loadingSection
                }

                // Error state
                if let error = packService.error {
                    errorSection(error)
                }

                // Create pack button
                createPackSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Question Pack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await packService.fetchPacks()
                await localPackStore.load()
            }
            .sheet(isPresented: $showingCreatePack) {
                KBCreatePackView(localPackStore: localPackStore)
            }
        }
    }

    // MARK: - All Questions Section

    private var allQuestionsSection: some View {
        Section {
            Button {
                selectedPackId = nil
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("All Questions")
                            .font(.headline)
                            .foregroundColor(.kbTextPrimary)

                        Text("Use the full question bank")
                            .font(.caption)
                            .foregroundColor(.kbTextSecondary)
                    }

                    Spacer()

                    if selectedPackId == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.kbMastered)
                    }
                }
            }
        } header: {
            Text("Default")
        }
    }

    // MARK: - Server Packs Section

    private var serverPacksSection: some View {
        Section {
            ForEach(packService.packs) { pack in
                packRow(pack)
            }
        } header: {
            Text("Server Packs")
        }
    }

    // MARK: - Local Packs Section

    private var localPacksSection: some View {
        Section {
            ForEach(localPackStore.localPacks) { pack in
                packRow(pack)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let pack = localPackStore.localPacks[index]
                    localPackStore.deletePack(id: pack.id)
                }
            }
        } header: {
            Text("Your Packs")
        }
    }

    // MARK: - Pack Row

    private func packRow(_ pack: KBPack) -> some View {
        Button {
            selectedPackId = pack.id
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.kbTextPrimary)

                    HStack(spacing: 8) {
                        Text(pack.questionCountDisplay)
                            .font(.caption)
                            .foregroundColor(.kbTextSecondary)

                        // Domain badges
                        HStack(spacing: 4) {
                            ForEach(pack.topDomains.prefix(4)) { domain in
                                Image(systemName: domain.icon)
                                    .font(.system(size: 10))
                                    .foregroundColor(domain.color)
                            }
                        }
                    }
                }

                Spacer()

                if selectedPackId == pack.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.kbMastered)
                }
            }
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .padding(.trailing, 8)
                Text("Loading packs...")
                    .foregroundColor(.kbTextSecondary)
            }
        }
    }

    // MARK: - Error Section

    private func errorSection(_ error: Error) -> some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn't load server packs")
                        .font(.subheadline)
                        .foregroundColor(.kbTextPrimary)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.kbTextSecondary)
                }
            }

            Button("Retry") {
                Task {
                    await packService.fetchPacks()
                }
            }
        }
    }

    // MARK: - Create Pack Section

    private var createPackSection: some View {
        Section {
            Button {
                showingCreatePack = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.kbMastered)
                    Text("Create New Pack")
                        .foregroundColor(.kbMastered)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedPackId: String?
        @State private var store = KBLocalPackStore()

        var body: some View {
            KBPackPickerView(
                selectedPackId: $selectedPackId,
                localPackStore: store
            )
        }
    }

    return PreviewWrapper()
}
