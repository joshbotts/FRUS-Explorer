// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - CitationLookupView

/// Resolves pasted or manually entered FRUS citations to specific documents.
///
/// ## Input modes
/// - **Paste Citation** (default): A text field accepting any free-form citation string.
///   Parsed fields populate the structured inputs in real time.
/// - **Structured Entry**: Individual labeled fields for subseries, volume, document number,
///   and page number. Pre-populated from the paste parser; also editable directly.
///
/// ## Results
/// Ranked results are displayed using `CitationResultRow`, which wraps the standard
/// document header / dateline / volume display. Each result is preceded by an explicit
/// confidence label. Correction notes appear below the result when a recovery was applied.
/// For undownloaded volumes, a Download button replaces the navigation action.
///
/// ## Navigation integration
/// Accessible via the toolbar "Find by Citation" button in `BrowserView`.
/// Pre-populates with the current document's citation when launched from `DocumentView`.
///
/// Version history:
///   1.0 — Session 30: initial implementation
struct CitationLookupView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // MARK: - Input State

    @State private var mode: CitationLookupMode = .paste
    @State private var pasteText: String = ""
    @State private var subseriesField: String = ""
    @State private var volumeField: String = ""
    @State private var documentField: String = ""
    @State private var pageField: String = ""

    // MARK: - Result State

    @State private var matches: [CitationMatch] = []
    @State private var isSearching: Bool = false
    @State private var error: String? = nil
    @State private var hasSearched: Bool = false

    // MARK: - Navigation

    @State private var navigationPath = NavigationPath()

    // MARK: - Parser

    private let parser = CitationParser()

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                modeSection
                inputSection
                lookUpSection
                if hasSearched { resultsSection }
            }
            .navigationTitle(String(localized: "citation.lookup.title",
                                    defaultValue: "Citation Lookup"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "citation.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                DocumentView(entry: entry)
            }
        }
    }

    // MARK: - Sections

    private var modeSection: some View {
        Section {
            Picker(String(localized: "citation.mode.label", defaultValue: "Input mode"),
                   selection: $mode) {
                ForEach(CitationLookupMode.allCases, id: \.self) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    @ViewBuilder
    private var inputSection: some View {
        if mode == .paste {
            Section {
                TextField(
                    String(localized: "citation.paste.placeholder",
                           defaultValue: "Paste a FRUS citation…"),
                    text: $pasteText,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .onChange(of: pasteText) { _, new in
                    guard !new.isEmpty else { return }
                    let parsed = parser.parse(new)
                    subseriesField  = parsed.subseries     ?? subseriesField
                    volumeField     = parsed.volumeNumber  ?? volumeField
                    documentField   = parsed.documentNumber.map(String.init) ?? documentField
                    pageField       = parsed.pageNumber.map(String.init)     ?? pageField
                }
            } header: {
                Text(String(localized: "citation.paste.header", defaultValue: "Citation Text"))
            }
        }

        Section {
            LabeledContent {
                TextField(String(localized: "citation.field.subseries.placeholder",
                                 defaultValue: "e.g. 1969-76"),
                          text: $subseriesField)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .disableAutocorrection(true)
            } label: {
                Text(String(localized: "citation.field.subseries", defaultValue: "Subseries"))
            }

            LabeledContent {
                TextField(String(localized: "citation.field.volume.placeholder",
                                 defaultValue: "e.g. I or 1"),
                          text: $volumeField)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .disableAutocorrection(true)
            } label: {
                Text(String(localized: "citation.field.volume", defaultValue: "Volume"))
            }

            LabeledContent {
                TextField(String(localized: "citation.field.document.placeholder",
                                 defaultValue: "e.g. 15"),
                          text: $documentField)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            } label: {
                Text(String(localized: "citation.field.document", defaultValue: "Document no."))
            }

            LabeledContent {
                TextField(String(localized: "citation.field.page.placeholder",
                                 defaultValue: "e.g. 47"),
                          text: $pageField)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            } label: {
                Text(String(localized: "citation.field.page", defaultValue: "Page"))
            }
        } header: {
            Text(String(localized: "citation.fields.header", defaultValue: "Parsed Fields"))
        } footer: {
            Text(String(localized: "citation.fields.footer",
                        defaultValue: "Provide at least a document number, page number, or volume to search."))
                .font(.caption)
        }
    }

    private var lookUpSection: some View {
        Section {
            Button {
                Task { await performLookup() }
            } label: {
                if isSearching {
                    HStack {
                        ProgressView()
                        Text(String(localized: "citation.lookup.searching",
                                    defaultValue: "Looking up…"))
                    }
                } else {
                    Text(String(localized: "citation.lookup.button", defaultValue: "Look Up"))
                        .bold()
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(!isInputActionable || isSearching)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if isSearching {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        } else if let err = error {
            Section {
                ContentUnavailableView(
                    String(localized: "citation.error.title", defaultValue: "Lookup Error"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(err)
                )
            }
        } else if matches.isEmpty {
            Section {
                ContentUnavailableView(
                    String(localized: "citation.noMatch.title", defaultValue: "No Matches Found"),
                    systemImage: "doc.questionmark",
                    description: Text(String(localized: "citation.noMatch.detail",
                        defaultValue: "No FRUS documents matched the provided citation. Check the subseries and volume, then try again."))
                )
            }
        } else {
            Section {
                ForEach(matches) { match in
                    CitationResultRow(match: match, appState: appState) {
                        if let entry = makeEntry(for: match) {
                            navigationPath.append(entry)
                        }
                    } onDownload: {
                        initiateDownload(for: match)
                    }
                }
            } header: {
                Text(String(localized: "citation.results.header",
                            defaultValue: "Results (\(matches.count) found)"))
            }
        }
    }

    // MARK: - Actions

    private var isInputActionable: Bool {
        !documentField.isEmpty || !pageField.isEmpty || !volumeField.isEmpty
    }

    @MainActor
    private func performLookup() async {
        guard let engine = appState.citationMatchingEngine else {
            error = String(localized: "citation.error.noEngine",
                           defaultValue: "Citation lookup is not available until a volume is downloaded.")
            hasSearched = true
            return
        }

        isSearching = true
        error = nil
        hasSearched = true

        let input = CitationInput(
            rawText: mode == .paste ? pasteText : nil,
            subseries: subseriesField.isEmpty ? nil : subseriesField,
            volumeNumber: volumeField.isEmpty ? nil : volumeField,
            documentNumber: Int(documentField),
            pageNumber: Int(pageField),
            parserConfidence: mode == .paste ? parser.parse(pasteText).parserConfidence : .structured
        )

        do {
            matches = try await engine.match(input: input)
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }

    private func makeEntry(for match: CitationMatch) -> DocumentBrowserEntry? {
        guard !match.documentId.isEmpty else { return nil }
        return DocumentBrowserEntry(
            documentId: match.documentId,
            volumeId: match.volumeId,
            documentNumber: nil,
            header: match.confidenceLabel,
            dateline: nil,
            sourceNote: nil
        )
    }

    private func initiateDownload(for match: CitationMatch) {
        guard let entry = match.volumeManifestEntry,
              let dm = appState.downloadManager else { return }
        let downloadUrl = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(entry.filename)"
        Task { await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: downloadUrl) }
    }
}

// MARK: - CitationResultRow

private struct CitationResultRow: View {

    let match: CitationMatch
    let appState: AppState
    let onNavigate: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Confidence label badge
            Text(match.confidenceLabel)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(confidenceLabelColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(confidenceLabelColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            if let entry = match.volumeManifestEntry {
                // Manifest-only result
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(entry.volumeId)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(match.documentId)
                    .font(.headline)
                Text(match.volumeId)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Correction note
            if let note = match.correctionNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            // Action button
            if match.requiresDownload {
                Button {
                    onDownload()
                } label: {
                    Label(
                        String(localized: "citation.result.download",
                               defaultValue: "Download Volume"),
                        systemImage: "arrow.down.circle"
                    )
                }
                .buttonStyle(.bordered)
                .font(.caption)
            } else if !match.documentId.isEmpty {
                Button {
                    onNavigate()
                } label: {
                    Text(String(localized: "citation.result.view",
                                defaultValue: "View Document"))
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private var confidenceLabelColor: Color {
        switch match.matchStrategy {
        case .exactDocumentNumber:    return .green
        case .pageRange:              return .blue
        case .superimposedDocumentNumber: return .teal
        case .fuzzyDocumentNumber:    return .orange
        case .titleFragmentMatch:     return .purple
        case .manifestOnly:           return .secondary
        case .bestGuess:              return .orange
        }
    }
}
