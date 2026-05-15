// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SourceExplorerView

/// Sheet that displays parsed provenance information for a FRUS source note.
///
/// ## Layout
/// Presented as a sheet from `DocumentView` when the user taps the Source Explorer
/// toolbar button. Parses the raw source note on appear and displays provenance-specific UI.
///
/// ## Provenance-specific panels
/// | Provenance | Panel |
/// |---|---|
/// | Central files (RG-59) | Static NARA URL link — no API key required |
/// | Lot file | NARA Catalog result (requires API key) |
/// | Presidential library | NARA Catalog result (requires API key) |
/// | Foreign archive | Formatted text display |
/// | Previously published | Formatted citation display |
/// | Unrecognized | Raw text with explanation |
///
/// ## No API Key State
/// Panels that require an API key show a prompt with a Settings navigation link
/// rather than a loading spinner.
///
/// ## Log prefix
/// `[SourceExplorer]`
///
/// Version history:
///   1.0 — Session 23: initial implementation
struct SourceExplorerView: View {

    // MARK: - Input

    /// Raw plain-text source note extracted from the TEI document.
    let rawSourceNote: String

    // MARK: - Dependencies

    private let parser = SourceNoteParser()
    private let client = NARACatalogClient()

    // MARK: - State

    @State private var parsed: ParsedSourceNote? = nil
    @State private var catalogResult: NARACatalogResult? = nil
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var hasAPIKey: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                rawNoteSection

                if let parsed {
                    provenanceSection(parsed: parsed)
                }
            }
            .navigationTitle(String(localized: "source.explorer.title",
                                    defaultValue: "Source Explorer"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "source.explorer.done",
                                  defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            .task {
                await load()
            }
        }
    }

    // MARK: - Raw Note Section

    private var rawNoteSection: some View {
        Section(String(localized: "source.explorer.rawNote.header",
                       defaultValue: "Source Note")) {
            Text(rawSourceNote)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Provenance Section

    @ViewBuilder
    private func provenanceSection(parsed: ParsedSourceNote) -> some View {
        switch parsed {

        case .centralFiles(let rg, let fileId):
            centralFilesPanel(recordGroup: rg, fileIdentifier: fileId)

        case .lotFile(let lotNumber, let fileId):
            lotFilePanel(lotNumber: lotNumber, fileIdentifier: fileId)

        case .presidentialLibrary(let library, let collection, let fileId):
            presidentialLibraryPanel(library: library, collection: collection, fileIdentifier: fileId)

        case .foreignGovernmentArchive(let desc):
            foreignArchivePanel(description: desc)

        case .previouslyPublished(let citation):
            previouslyPublishedPanel(citation: citation)

        case .unrecognized(let raw):
            unrecognizedPanel(rawText: raw)
        }
    }

    // MARK: - Central Files Panel

    @ViewBuilder
    private func centralFilesPanel(recordGroup: String, fileIdentifier: String?) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.centralFiles.type",
                       defaultValue: "Type"),
                value: String(localized: "source.explorer.centralFiles.typeValue",
                              defaultValue: "State Dept. Central Files (\(recordGroup))")
            )
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.centralFiles.identifier",
                           defaultValue: "File Identifier"),
                    value: fileIdentifier
                )
            }
        }

        Section(String(localized: "source.explorer.nara.header",
                       defaultValue: "NARA Catalog")) {
            Button {
                let url = client.resolveRG59CentralFiles(fileIdentifier: fileIdentifier ?? "")
                openURL(url)
            } label: {
                Label(
                    String(localized: "source.explorer.centralFiles.naraLink",
                           defaultValue: "Search NARA Catalog for This File"),
                    systemImage: "arrow.up.right.square"
                )
            }
            .accessibilityLabel(
                String(localized: "source.explorer.centralFiles.naraLink.accessibility",
                       defaultValue: "Open NARA Catalog search in browser")
            )

            Text(String(localized: "source.explorer.centralFiles.noKeyNote",
                        defaultValue: "Central file searches open directly in your browser — no API key required."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Lot File Panel

    @ViewBuilder
    private func lotFilePanel(lotNumber: String, fileIdentifier: String?) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.lotFile.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.lotFile.typeValue",
                              defaultValue: "State Dept. Lot File")
            )
            LabeledContent(
                String(localized: "source.explorer.lotFile.lot", defaultValue: "Lot Number"),
                value: lotNumber
            )
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.lotFile.fileId",
                           defaultValue: "File Identifier"),
                    value: fileIdentifier
                )
            }
        }

        naraResultSection(requiresKey: true)
    }

    // MARK: - Presidential Library Panel

    @ViewBuilder
    private func presidentialLibraryPanel(
        library: String,
        collection: String,
        fileIdentifier: String?
    ) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.presLib.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.presLib.typeValue",
                              defaultValue: "Presidential Library")
            )
            LabeledContent(
                String(localized: "source.explorer.presLib.library", defaultValue: "Library"),
                value: library
            )
            if !collection.isEmpty {
                LabeledContent(
                    String(localized: "source.explorer.presLib.collection",
                           defaultValue: "Collection"),
                    value: collection
                )
            }
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.presLib.fileId",
                           defaultValue: "File Identifier"),
                    value: fileIdentifier
                )
            }
        }

        naraResultSection(requiresKey: true)
    }

    // MARK: - Foreign Archive Panel

    @ViewBuilder
    private func foreignArchivePanel(description: String) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.foreignArchive.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.foreignArchive.typeValue",
                              defaultValue: "Foreign Government Archive")
            )
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }

        Section {
            Text(String(localized: "source.explorer.foreignArchive.note",
                        defaultValue: "Foreign government archives are not indexed in the NARA Catalog. Consult the archive directly for access."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Previously Published Panel

    @ViewBuilder
    private func previouslyPublishedPanel(citation: String) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.published.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.published.typeValue",
                              defaultValue: "Previously Published")
            )
            Text(citation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }

        Section {
            Text(String(localized: "source.explorer.published.note",
                        defaultValue: "This document was previously published. Consult the cited publication for the original source."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Unrecognized Panel

    @ViewBuilder
    private func unrecognizedPanel(rawText: String) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.unrecognized.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.unrecognized.typeValue",
                              defaultValue: "Unrecognized Format")
            )
        }

        Section {
            Text(String(localized: "source.explorer.unrecognized.explanation",
                        defaultValue: "The source note format was not recognized. The raw text is shown above. Automated NARA Catalog resolution is unavailable for this entry."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - NARA Result Section (API-dependent)

    @ViewBuilder
    private func naraResultSection(requiresKey: Bool) -> some View {
        Section(String(localized: "source.explorer.nara.header",
                       defaultValue: "NARA Catalog")) {
            if requiresKey && !hasAPIKey {
                noAPIKeyPrompt
            } else if isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text(String(localized: "source.explorer.nara.loading",
                                defaultValue: "Searching NARA Catalog…"))
                        .foregroundStyle(.secondary)
                }
            } else if let error = loadError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            } else if let result = catalogResult {
                catalogResultRow(result: result)
            } else {
                Text(String(localized: "source.explorer.nara.noResult",
                            defaultValue: "No matching record found in the NARA Catalog."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }

    private var noAPIKeyPrompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                String(localized: "source.explorer.noKey.label",
                       defaultValue: "NARA Catalog API Key Required"),
                systemImage: "key"
            )
            .font(.callout.weight(.medium))

            Text(String(localized: "source.explorer.noKey.explanation",
                        defaultValue: "A free NARA Catalog API key is needed to search for lot file and Presidential Library records. Add your key in Settings."))
                .font(.caption)
                .foregroundStyle(.secondary)

            NavigationLink(
                String(localized: "source.explorer.noKey.settingsLink",
                       defaultValue: "Open Settings")
            ) {
                // Settings navigation wired in Session 24
                EmptyView()
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func catalogResultRow(result: NARACatalogResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.callout.weight(.medium))

            if let scope = result.scopeNote {
                Text(scope)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            Button {
                openURL(result.catalogURL)
            } label: {
                Label(
                    String(localized: "source.explorer.nara.viewRecord",
                           defaultValue: "View in NARA Catalog"),
                    systemImage: "arrow.up.right.square"
                )
                .font(.callout)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Load

    private func load() async {
        let note = SourceNoteParser().parse(rawSourceNote)
        parsed = note

        hasAPIKey = await client.hasAPIKey()

        // Only hit the API for provenance types that need it
        switch note {
        case .lotFile(let lotNumber, _):
            guard hasAPIKey else { return }
            await fetchResult { try await client.resolveLotFile(lotNumber: lotNumber) }

        case .presidentialLibrary(let library, let collection, _):
            guard hasAPIKey else { return }
            await fetchResult {
                try await client.resolvePresidentialLibrary(library: library, collection: collection)
            }

        default:
            break
        }
    }

    private func fetchResult(_ operation: @Sendable () async throws -> NARACatalogResult?) async {
        isLoading = true
        loadError = nil
        do {
            catalogResult = try await operation()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}
