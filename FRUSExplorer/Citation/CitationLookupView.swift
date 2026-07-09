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
/// On iOS, presented as a sheet from `SearchView`'s "Find by Citation" button; result
/// taps push `DocumentView` onto the sheet's own `NavigationStack`. On macOS, hosted in
/// the `frus.citationLookup` Window scene (⌘⇧F) via `CitationLookupWindowView` — a window,
/// not a sheet, so parsed matches stay around while the researcher reads documents (UI
/// audit B4); result taps open the document in its **own** window (`DocumentWindowID`,
/// matching the Search window), so the lookup's matches stay visible and the document gets
/// working prev/next and cross-reference navigation.
///
/// Version history:
///   1.0 — Session 30: initial implementation
///   1.1 — Session 2026-07-04 (macOS UI audit B4): the Done toolbar button became
///          iOS-only sheet chrome — on macOS the view lives in a window whose own
///          close control is the exit (gap 11: no dead Done buttons in windows)
///   1.2 — Session 2 / #239 (macOS platform fit): `.formStyle(.grouped)` so the sections
///          render like every other Mac form; Return runs the lookup and the paste field
///          takes initial focus; result taps open a real document window (`DocumentWindowID`)
///          instead of pushing a `MacDocumentView(navigationPath: .constant([]))` whose
///          constant binding silently broke prev/next + cross-refs; result rows group for
///          VoiceOver and the lookup announces its result count; `.help` tooltips added
///   1.3 — Session 2 review pass: initial focus verified live and hardened (a settle-then-
///          focus task backs up `.defaultFocus`, which alone never landed; mode-switch
///          refocus deferred one tick); document windows are titled "volumeId — documentId"
///          (a bare TEI id left same-numbered documents indistinguishable); the no-engine
///          error announces to VoiceOver like every other outcome; badge caption text mixed
///          toward `.primary` for AA contrast (icon keeps the full hue); `.submitLabel(.search)`
///          on the iOS fields
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
    /// Parsed title fragment from the pasted citation. Not shown as an editable field — it's the
    /// disambiguator the matcher needs to resolve volumes whose only year is a print year (e.g.
    /// pre-1906 "Papers Relating to Foreign Affairs" parts), so it must be forwarded rather than
    /// dropped (#216).
    @State private var parsedTitleFragment: String? = nil

    // MARK: - Result State

    @State private var matches: [CitationMatch] = []
    @State private var isSearching: Bool = false
    @State private var error: String? = nil
    @State private var hasSearched: Bool = false

    // MARK: - Navigation

    @State private var navigationPath = NavigationPath()
    #if os(macOS)
    // On macOS a match opens a real document window (the Search-window convention) rather
    // than pushing onto this small lookup window's own stack, so parsed matches stay
    // visible and the document gets working prev/next + cross-reference navigation.
    @Environment(\.openWindow) private var openWindow
    #endif

    // MARK: - Focus

    /// The fields that can hold keyboard focus, so the sheet/window opens focused and
    /// Return runs the lookup from any field.
    private enum LookupField: Hashable { case paste, subseries, volume, document, page }
    @FocusState private var focusedField: LookupField?

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
            #if os(macOS)
            // The grouped Mac form style every other macOS form in the app uses (Settings,
            // Search filters, editors). The default columnar style rendered the sections as
            // cramped rows, which is the platform-fit defect this addresses (#239).
            .formStyle(.grouped)
            #endif
            // Return in any field runs the lookup (guarded), matching the Search window.
            .onSubmit(of: .text) { submitIfActionable() }
            .navigationTitle(String(localized: "citation.lookup.title",
                                    defaultValue: "Citation Lookup"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            // Done is sheet chrome — iOS only. On macOS the view lives in the
            // frus.citationLookup window, whose close control is the exit (B4).
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "citation.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            #endif
            // macOS opens matches as their own document windows (see `openMatch`), so the
            // stack destination is iOS-only. The previous macOS branch pushed a
            // `MacDocumentView(navigationPath: .constant([]))` whose constant binding
            // silently broke prev/next and cross-reference navigation (B4 follow-up).
            #if os(iOS)
            .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                DocumentView(entry: entry)
            }
            #endif
            .defaultFocus($focusedField, .paste)
            .task {
                // `.defaultFocus` alone does not land in a Form-hosted field when the
                // macOS window first opens (verified live in the simulator-free window
                // drive: typing after ⌘⇧F was dropped until a manual click). Nudge focus
                // once the window has settled — but only if the user hasn't already
                // focused something themselves.
                try? await Task.sleep(for: .milliseconds(350))
                if focusedField == nil {
                    focusedField = mode == .paste ? .paste : .subseries
                }
            }
            .onChange(of: mode) { _, newMode in
                // Keep focus on a field that exists in the new mode (paste field only
                // shows in .paste; the structured fields always show). Deferred one tick:
                // the paste field is being INSERTED by this same view update, and assigning
                // @FocusState to a not-yet-mounted field can be silently dropped.
                Task { @MainActor in
                    focusedField = newMode == .paste ? .paste : .subseries
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 440)
        #endif
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
                .focused($focusedField, equals: .paste)
                #if os(iOS)
                // With a submit label, Return submits instead of inserting a newline —
                // citations are pasted, not typed with line breaks.
                .submitLabel(.search)
                #endif
                .accessibilityLabel(String(localized: "citation.paste.a11y",
                                           defaultValue: "Citation text"))
                .onChange(of: pasteText) { _, new in
                    guard !new.isEmpty else { return }
                    let parsed = parser.parse(new)
                    subseriesField  = parsed.subseries     ?? subseriesField
                    volumeField     = parsed.volumeNumber  ?? volumeField
                    documentField   = parsed.documentNumber.map(String.init) ?? documentField
                    pageField       = parsed.pageNumber.map(String.init)     ?? pageField
                    parsedTitleFragment = parsed.titleFragment
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
                    .focused($focusedField, equals: .subseries)
                    #if os(iOS)
                    .submitLabel(.search)
                    #endif
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
                    .focused($focusedField, equals: .volume)
                    #if os(iOS)
                    .submitLabel(.search)
                    #endif
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
                    .focused($focusedField, equals: .document)
                    #if os(iOS)
                    .submitLabel(.search)
                    #endif
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
                    .focused($focusedField, equals: .page)
                    #if os(iOS)
                    .submitLabel(.search)
                    #endif
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
                submitIfActionable()
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
            #if os(macOS)
            // Return activates Look Up when focus is not in a text field (fields have their
            // own .onSubmit); macOS-only so it can't collide with the iOS Done confirmation.
            .keyboardShortcut(.defaultAction)
            #endif
            .help(String(localized: "citation.lookup.button.help",
                         defaultValue: "Resolve the citation to matching FRUS documents"))
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
                        openMatch(match)
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

    /// Runs the lookup if there is enough input and one isn't already in flight — the
    /// shared trigger for the Look Up button, Return-in-field, and the default-action key.
    private func submitIfActionable() {
        guard isInputActionable, !isSearching else { return }
        Task { await performLookup() }
    }

    /// Opens the match's document. On macOS this is a real document window (so parsed
    /// matches stay visible and the document gets working prev/next + cross-references);
    /// on iOS it pushes onto this sheet's navigation stack.
    private func openMatch(_ match: CitationMatch) {
        guard !match.documentId.isEmpty else { return }
        #if os(macOS)
        // The header doubles as the window/tab title (MacDocumentWindowView pins it), so a
        // bare TEI id would leave two "d15" windows indistinguishable — include the volume.
        // (CitationMatch carries no document heading; volumeManifestEntry is only populated
        // on manifest-only matches, which are never openable.)
        openWindow(value: DocumentWindowID(
            volumeId: match.volumeId,
            documentId: match.documentId,
            header: "\(match.volumeId) — \(match.documentId)"
        ))
        #else
        if let entry = makeEntry(for: match) {
            navigationPath.append(entry)
        }
        #endif
    }

    @MainActor
    private func performLookup() async {
        guard let engine = appState.citationMatchingEngine else {
            let message = String(localized: "citation.error.noEngine",
                                 defaultValue: "Citation lookup is not available until a volume is downloaded.")
            error = message
            hasSearched = true
            // This early-out is an outcome too — announce it like the shared block below,
            // so VoiceOver users get a cue on every path out of a lookup attempt.
            AccessibilityNotification.Announcement(message).post()
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
            // Forward the parsed title fragment (paste mode only) so the matcher can correct a
            // print-year subseries and disambiguate part volumes (#216).
            titleFragment: mode == .paste ? parsedTitleFragment : nil,
            parserConfidence: mode == .paste ? parser.parse(pasteText).parserConfidence : .structured
        )

        do {
            matches = try await engine.match(input: input)
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false

        // Announce the outcome for VoiceOver users, who otherwise get no cue that the
        // async lookup finished or how many results arrived.
        let announcement: String
        if let error {
            announcement = error
        } else if matches.isEmpty {
            announcement = String(localized: "citation.noMatch.title", defaultValue: "No Matches Found")
        } else {
            announcement = String(format: String(localized: "citation.results.count.a11y",
                                                  defaultValue: "%lld matches found"),
                                  Int64(matches.count))
        }
        AccessibilityNotification.Announcement(announcement).post()
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
        Task { await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: entry.downloadUrl) }
    }
}

#if os(macOS)

// MARK: - CitationLookupWindowView

/// Content for the macOS **Citation Lookup window** (`frus.citationLookup`, ⌘⇧F —
/// UI audit B4): `CitationLookupView` behind a boot-readiness guard.
///
/// A window, not a sheet, for the same reason full-text Search (⌘F) is one — both
/// are "find a document" flows whose results are worked through one by one, and the
/// modal died with its matches on every Done.
///
/// The guard copies the S6 Archival Neighbors rule: a window restored at relaunch
/// races app boot, and `appState.citationMatchingEngine` is assigned only when
/// `bootDownloadManager()` finishes (unconditionally — even with zero downloads), so
/// `nil` means exactly "still booting". Without the guard, a Look Up pressed in that
/// window would render the definitive "not available until a volume is downloaded"
/// error as a lie. Reading the `@Observable` property in `body` re-evaluates the view
/// and swaps the placeholder for the form the moment the engine exists.
///
/// Version history:
///   1.0 — Session 2026-07-04 (macOS UI audit B4): initial implementation
struct CitationLookupWindowView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.citationMatchingEngine == nil {
                // App still booting: never show the form whose lookup error would
                // falsely claim citation lookup is unavailable.
                ProgressView(String(localized: "archivalNeighbors.preparingIndex",
                                    defaultValue: "Preparing your index…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 560, minHeight: 440)
            } else {
                CitationLookupView()
            }
        }
    }
}

#endif // os(macOS)

// MARK: - CitationResultRow

private struct CitationResultRow: View {

    let match: CitationMatch
    let appState: AppState
    let onNavigate: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The confidence badge + identity + correction note read as one VoiceOver
            // element (they describe a single result); the action buttons below stay
            // separate so they remain individually activatable.
            VStack(alignment: .leading, spacing: 6) {
                // Confidence label badge — icon + text so confidence level is not
                // communicated by color alone (WCAG 1.4.1 / F-023). The caption TEXT is
                // mixed toward .primary so small type clears AA contrast on the tinted
                // background (raw system orange/green caption text sits well below 4.5:1);
                // the icon keeps the full hue as the color-language carrier.
                Label {
                    Text(match.confidenceLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(confidenceLabelColor.mix(with: .primary, by: 0.45))
                } icon: {
                    Image(systemName: confidenceLabelIcon)
                        .font(.caption2)
                        .foregroundStyle(confidenceLabelColor)
                }
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
            }
            .accessibilityElement(children: .combine)

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
                .help(String(localized: "citation.result.download.help",
                             defaultValue: "Download this volume so its documents can be opened"))
            } else if !match.documentId.isEmpty {
                Button {
                    onNavigate()
                } label: {
                    Text(String(localized: "citation.result.view",
                                defaultValue: "View Document"))
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
                .help(String(localized: "citation.result.view.help",
                             defaultValue: "Open this document"))
            }
        }
        .padding(.vertical, 4)
    }

    private var confidenceLabelColor: Color {
        switch match.matchStrategy {
        case .exactDocumentNumber:            return .green
        case .pageRange:                      return .blue
        case .superimposedDocumentNumber:     return .teal
        case .fuzzyDocumentNumber:            return .orange
        case .titleFragmentMatch:             return .purple
        case .manifestOnly:                   return .secondary
        case .bestGuess:                      return .orange
        }
    }

    /// SF Symbol name that reinforces confidence level independently of color (F-023).
    ///
    /// Each strategy has a distinct icon so color-blind users can still distinguish
    /// match quality at a glance.
    private var confidenceLabelIcon: String {
        switch match.matchStrategy {
        case .exactDocumentNumber:            return "checkmark.seal.fill"
        case .pageRange:                      return "number.circle"
        case .superimposedDocumentNumber:     return "number.square"
        case .fuzzyDocumentNumber:            return "questionmark.circle"
        case .titleFragmentMatch:             return "text.magnifyingglass"
        case .manifestOnly:                   return "doc.circle"
        case .bestGuess:                      return "lightbulb"
        }
    }
}
