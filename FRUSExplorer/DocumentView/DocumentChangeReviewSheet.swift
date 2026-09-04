// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - DocumentChangeReviewSheet

/// The per-document review surface for a volume update (design §5.4–§5.6, R-5 P3): what the
/// re-index recorded, every highlight on the document with its standing and the two actions the
/// reader can take on it, every quotation frozen from it with the export check's verdict, the
/// other annotations the app cannot judge, and the document-level disposition that stamps
/// `reviewed_at`.
///
/// One shared view, reached three ways: the change banner's *Review…* control in both document
/// twins (which pass the open document's `renderingVersion`), and the Research list's *Review
/// Changes…* row action (which passes none, so the sheet judges against the revision row's
/// `body_hash` — P1 pinned the two equal). A vanished document never reaches a document view at
/// all, so the Research route is the only one an orphan has, and the sheet works with no render
/// model: nothing here needs one.
///
/// What it refuses, per §7: it never re-anchors ON ITS OWN — since R-5 P3b-3 it may OFFER to move
/// a highlight whose stored passage it found again, showing the words and their surroundings, and
/// it moves nothing until the reader taps; it never deletes on its own; and it never says an
/// annotation is wrong — only what the hashes and an exact search can prove. Since R-5 P3b-5 it
/// also OPENS what it names: a note row presents the note editor and a tag row the tag picker,
/// because telling a reader their annotation may be affected and giving them no way to reach it
/// left the only route out of the sheet and back through the document.
///
/// Version history:
///   1.0 — R-5 P3: initial implementation
///   1.1 — R-5 P3b-3: the re-anchor search, the found passage in context, and the Move Here offer
///   1.2 — R-5 P3b-4: the Quotations section — the export check, per excerpt, with its capture version
///   1.3 — R-5 P3b-5: notes and tags open from the sheet (design Q-11 b)
struct DocumentChangeReviewSheet: View {

    let volumeId: String
    let documentId: String
    /// The document's header, for the title.
    let title: String
    /// The open document's `renderingVersion`, when the caller has one; nil falls back to the
    /// revision row's `bodyHash`.
    let currentVersion: String?

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    /// macOS opens a note in the `frus.noteComposer` WINDOW rather than a nested sheet, because
    /// `NoteComposerRequest`'s stored properties are all identity fields: opening the same request
    /// focuses the composer already on screen instead of stacking a second editor over one
    /// SwiftData row. A sheet here would be the only macOS route that could do that.
    @Environment(\.openWindow) private var openWindow
    #endif

    @Query private var highlights: [DocumentHighlight]
    @Query private var notes: [ResearchNote]
    @Query private var tagAssignments: [DocumentTagAssignment]
    @Query private var entries: [CollectionEntry]
    @Query private var summaries: [GeneratedSummary]
    @Query private var visitDocuments: [ArchiveVisitDocument]

    @State private var revision: IndexingPipeline.DocumentRevision?
    @State private var loaded = false
    @State private var highlightToDelete: DocumentHighlight?
    @State private var stamping = false
    /// The document's block partition as it reads NOW, built once per sheet — the haystack the
    /// re-anchor search runs against (R-5 P3b-3). Nil when the volume is not on this device.
    @State private var blocks: [String]?
    /// The `renderingVersion` of the model those blocks came from. A Move must write THIS, not
    /// `effectiveVersion`, which on the Research route falls back to the index-time `bodyHash` and
    /// can disagree with a model parsed from disk now.
    @State private var searchedVersion: String?
    /// One search per highlight, computed once off the row builder — `highlightRow` runs per
    /// `ForEach` element and the search is not free.
    @State private var searches: [UUID: HighlightReview.Search] = [:]
    /// The display order frozen for the life of the sheet: the `@Query` sorts on `startOffset`, so
    /// a Move would otherwise make the row jump under the reader's finger as they tap it.
    @State private var rowOrder: [UUID] = []
    /// One verifier outcome per excerpt entry, by entry id (R-5 P3b-4). Empty until the check has
    /// run, which is why the row says "checking" rather than defaulting to an answer.
    @State private var excerptOutcomes: [UUID: ExcerptVerifier.Outcome] = [:]
    /// The note the reader asked to open (R-5 P3b-5, design Q-11 b). Carries the note ITSELF, not
    /// its id: a `.sheet(item:)` closure that re-derived the note from a sibling `@State` would
    /// read a value captured before the presentation (#862).
    @State private var noteToOpen: NoteEditorRequest?
    /// Whether the tag picker is up — the same sheet the Research rail presents.
    @State private var editingTags = false
    /// The archive-visit plan the reader asked to open, resolved from a seed's `planId`.
    @State private var planToOpen: ArchiveVisitPlan?
    /// The note row order frozen for the life of the sheet — see `orderedNotes`.
    @State private var noteOrder: [UUID] = []

    init(volumeId: String, documentId: String, title: String, currentVersion: String? = nil) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.title = title
        self.currentVersion = currentVersion
        let key = "\(volumeId)/\(documentId)"
        _highlights = Query(filter: #Predicate<DocumentHighlight> {
            $0.volumeId == volumeId && $0.documentId == documentId
        }, sort: [SortDescriptor(\DocumentHighlight.startOffset)])
        _notes = Query(filter: #Predicate<ResearchNote> {
            $0.volumeId == volumeId && $0.documentId == documentId
        })
        _tagAssignments = Query(filter: #Predicate<DocumentTagAssignment> {
            $0.volumeId == volumeId && $0.documentId == documentId
        })
        _entries = Query(filter: #Predicate<CollectionEntry> {
            $0.volumeId == volumeId && $0.documentId == documentId
        })
        _summaries = Query(filter: #Predicate<GeneratedSummary> {
            $0.volumeId == volumeId && $0.documentId == documentId
        })
        _visitDocuments = Query(filter: #Predicate<ArchiveVisitDocument> { $0.documentKey == key })
    }

    // MARK: - Derived

    /// The version highlights are judged against.
    private var effectiveVersion: String? {
        // Once the sheet has parsed the document itself, THAT is the authority: it came from the
        // bytes on disk, while `currentVersion` can predate a background re-index and the revision
        // row's `bodyHash` is the index's copy. Without this, Confirm and Move could write two
        // different hashes from the same row (R-5 P3b-3 review).
        if let searchedVersion, !searchedVersion.isEmpty { return searchedVersion }
        if let currentVersion, !currentVersion.isEmpty { return currentVersion }
        if let bodyHash = revision?.bodyHash, !bodyHash.isEmpty { return bodyHash }
        return nil
    }

    /// A vanished document: no text to judge against, every annotation an orphan.
    private var isVanished: Bool { revision?.changeKind == "vanished" }

    /// Whether the row can still be stamped.
    private var canMarkReviewed: Bool {
        guard let revision else { return false }
        return revision.changedAt != nil && revision.reviewedAt == nil
    }

    private var highlightsStale: Bool {
        highlights.contains { HighlightReview.status(of: $0, currentVersion: effectiveVersion) != .aligned
            && HighlightReview.status(of: $0, currentVersion: effectiveVersion) != .unverifiable }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                changeSection
                if !highlights.isEmpty { highlightsSection }
                if !excerpts.isEmpty { excerptsSection }
                othersSection
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "document.review.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 440)
        #endif
        .task {
            await loadRevision()
            await runSearches()
        }
        // A SECOND task, keyed on the quotations and on whether the revision has loaded (R-5
        // P3b-4). Keyed rather than chained for two reasons: the check must not run before
        // `loadRevision`, since `upgradingVanished` needs the change kind; and an excerpt syncing
        // in from another device while the sheet is open would otherwise keep "Checking…" on its
        // row for the life of the sheet. Re-running is cheap — one indexed read for one document.
        .task(id: excerptCheckKey) {
            guard loaded else { return }
            await verifyExcerpts()
        }
        // Declared HERE, on the sheet's own content, never on any of its three mounts: SwiftUI
        // will not present an ancestor's sheet over a descendant's, so a `.sheet` attached where
        // this sheet is presented would be a no-op that ghost-presents when this one closes
        // (DocumentView's own note on the rail records that failure). Sheet-over-sheet from inside
        // a sheet is what CollectionPickerSheet and NotesSettingsView already ship.
        .sheet(item: $noteToOpen) { request in
            ResearchNoteEditorView(
                documentId: documentId,
                volumeId: volumeId,
                activeProjectId: appState.activeProjectId,
                noteToEdit: request.note,
                indexingPipeline: appState.indexingPipeline)
        }
        .sheet(isPresented: $editingTags) {
            UserTagPickerSheet(
                entry: browserEntry,
                indexingPipeline: appState.indexingPipeline,
                initialTagIds: Set(tagAssignments.map(\.tagId)))
        }
        // The plan editor, in the shape Project Home already presents it: a NavigationStack with an
        // explicit Done, and `appState` re-injected exactly as that mount does. The injection is
        // belt-and-braces rather than load-bearing — the note sheet fifteen lines above reads
        // `AppState` from the inherited environment and works — but matching the shipped mount
        // costs nothing and keeps the two presentations of this editor identical.
        //
        // Deliberately NOT the macOS archive-visits WINDOW, which is a singleton whose selection is
        // local state with no hand-off: fronting it would show whichever plan it was last on.
        .sheet(item: $planToOpen) { plan in
            NavigationStack {
                ArchiveVisitEditorView(plan: plan)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "document.review.other.plan.done",
                                          defaultValue: "Done")) { planToOpen = nil }
                        }
                    }
            }
            .environment(appState)
        }
        .confirmationDialog(
            String(localized: "highlight.delete.title", defaultValue: "Remove Highlight"),
            isPresented: Binding(get: { highlightToDelete != nil },
                                 set: { if !$0 { highlightToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "highlight.delete.confirm", defaultValue: "Remove"), role: .destructive) {
                if let highlight = highlightToDelete {
                    searches[highlight.id] = nil
                    HighlightReview.delete(highlight, in: modelContext)
                    appState.revisionReviewToken += 1
                }
                highlightToDelete = nil
            }
            Button(String(localized: "highlight.delete.cancel", defaultValue: "Cancel"), role: .cancel) {
                highlightToDelete = nil
            }
        } message: {
            Text(String(localized: "highlight.delete.message",
                        defaultValue: "This highlight will be permanently removed."))
        }
    }

    // MARK: - Sections

    /// What the re-index recorded, in the banner's own words, and the document-level disposition.
    private var changeSection: some View {
        Section {
            if !loaded {
                Text(String(localized: "document.review.loading", defaultValue: "Reading the change record…"))
                    .foregroundStyle(.secondary)
            } else if isVanished {
                Label(String(localized: "document.review.vanished",
                             defaultValue: "This document is no longer in the volume after an update. Everything you attached to it is kept until you remove it."),
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if let line = DocumentChangeBanner.line(revision: revision, highlightsStale: highlightsStale) {
                Label(line, systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
            } else {
                Label(String(localized: "document.review.noChange",
                             defaultValue: "No change to this document is recorded on this device."),
                      systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            if canMarkReviewed {
                Button {
                    Task { await markReviewed() }
                } label: {
                    Label(String(localized: "document.review.markReviewed", defaultValue: "Mark Reviewed"),
                          systemImage: "checkmark.circle")
                }
                .disabled(stamping)
                .accessibilityIdentifier("document.review.markReviewed")
            }
        } header: {
            Text(String(localized: "document.review.change.header", defaultValue: "What Changed"))
        } footer: {
            if canMarkReviewed {
                Text(String(localized: "document.review.change.footer.v2",
                            defaultValue: "Marking the document reviewed clears it from “Changed by an update”. With iCloud sync it reaches your other devices too, a few seconds after they next sync or when they next open. Highlights stay flagged until you confirm each one, and the next update re-opens the document if it changes again."))
            }
        }
    }

    /// Every highlight on the document, with its standing and its two actions.
    private var highlightsSection: some View {
        Section {
            ForEach(orderedHighlights) { highlight in
                highlightRow(highlight)
            }
        } header: {
            Text(String(localized: "document.review.highlights.header", defaultValue: "Highlights"))
        } footer: {
            Text(String(localized: "document.review.highlights.footer.v2",
                        defaultValue: "Confirm keeps a highlight exactly where it is and clears its warning everywhere you are signed in. Where the app can find the passage again it offers to move the highlight, showing you the words and what surrounds them — it never moves one on its own, and it never guesses when the words appear more than once."))
        }
    }

    private func highlightRow(_ highlight: DocumentHighlight) -> some View {
        let status = HighlightReview.status(of: highlight, currentVersion: effectiveVersion)
        return VStack(alignment: .leading, spacing: 6) {
            if let context = matchContext(for: highlight) {
                // The found words IN their surroundings, replacing the bare passage above rather
                // than printing it twice: under an exact match the found words ARE the stored
                // passage, so the surroundings are the whole information gain.
                context.lineLimit(6)
            } else if highlight.selectedText.isEmpty {
                Text(String(localized: "document.review.highlight.noPassage", defaultValue: "Highlighted passage"))
                    .italic()
                    .foregroundStyle(.secondary)
            } else {
                Text(highlight.selectedText)
                    .lineLimit(4)
            }
            Text(Self.statusLine(status, vanished: isVanished))
                .font(.caption)
                .foregroundStyle(isVanished ? Color.red : (status == .aligned ? Color.secondary : Color.orange))
            if let search = searches[highlight.id], let line = Self.searchLine(search) {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 12) {
                if !isVanished, let match = movableMatch(for: highlight), let version = searchedVersion {
                    Button(String(localized: "document.review.highlight.move", defaultValue: "Move Here")) {
                        HighlightReview.move(highlight, to: match, currentVersion: version)
                        searches[highlight.id] = nil
                        appState.revisionReviewToken += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("document.review.highlight.move")
                }
                if !isVanished, case .stale = status, let version = effectiveVersion {
                    Button(String(localized: "document.review.highlight.confirm", defaultValue: "Confirm")) {
                        HighlightReview.confirm(highlight, currentVersion: version)
                        // A confirmation settles the question the search was asking. Leaving the
                        // result would have the row say "Matches the current text" and "Found once,
                        // at a new position" together, with Move still offered.
                        searches[highlight.id] = nil
                        appState.revisionReviewToken += 1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button(String(localized: "document.review.highlight.remove", defaultValue: "Remove…"), role: .destructive) {
                    highlightToDelete = highlight
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Quotations (R-5 P3b-4)

    /// What re-runs the quotation check: the revision's arrival, then any change to the set of
    /// quotations on this document.
    private var excerptCheckKey: String {
        (loaded ? "1|" : "0|") + excerpts.map(\.id.uuidString).joined(separator: ",")
    }

    /// Every stored quotation taken from this document, in a stable order.
    ///
    /// An entry with no text is skipped rather than shown as uncheckable: it renders as nothing in
    /// its own collection too, and a row saying "nothing to check" about an invisible entry would
    /// be the sheet's only mention of it.
    private var excerpts: [CollectionEntry] {
        entries
            .filter { $0.entryKind == .excerpt && !($0.text ?? "").isEmpty }
            .sorted {
                // Branch on the COMPARISON, not on string inequality: two collections named
                // "Notes" and "notes" are unequal strings that compare `.orderedSame`, so the
                // obvious form returns false for both orderings and leaves them unordered against
                // each other — and `sorted` is not stable, so the rows could swap between renders.
                let order = ($0.collection?.name ?? "")
                    .localizedCaseInsensitiveCompare($1.collection?.name ?? "")
                if order != .orderedSame { return order == .orderedAscending }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    /// The quotations frozen from this document, each with what an exact search of the current
    /// text found and which version it was taken from.
    private var excerptsSection: some View {
        Section {
            ForEach(excerpts) { entry in
                excerptRow(entry)
            }
        } header: {
            Text(String(localized: "document.review.excerpts.header", defaultValue: "Quotations"))
        } footer: {
            Text(String(localized: "document.review.excerpts.footer",
                        defaultValue: "A quotation is a copy, so a correction cannot change what it prints — what it can change is whether those words are still in the record it cites. This is the same check that runs when a collection is exported, and it reads the whole document, footnotes included. So a quotation can be affected by a correction described above as touching only the notes, and a quotation can fail this check for reasons older than any correction. Nothing here edits or removes a quotation: it belongs to its collection, and the collection editor is where you change it."))
        }
    }

    private func excerptRow(_ entry: CollectionEntry) -> some View {
        let outcome = excerptOutcomes[entry.id]
        // One call, so the two sentences cannot contradict each other — see `ExcerptReview.lines`,
        // which exists because composing them in the view produced exactly that twice.
        let lines = outcome.map {
            ExcerptReview.lines(outcome: $0,
                                storedVersion: entry.excerptRenderingVersion,
                                currentVersion: effectiveVersion)
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text(entry.text ?? "")
                .lineLimit(4)
            Text(entry.collection?.name.isEmpty == false
                 ? entry.collection?.name ?? ""
                 : String(localized: "research.list.untitledCollection", defaultValue: "Untitled Collection"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let outcome, let lines {
                Text(lines.finding)
                    .font(.caption)
                    .foregroundStyle(ExcerptReview.isWarning(outcome) ? Color.orange : Color.secondary)
                if let capture = lines.capture {
                    Text(capture)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(String(localized: "document.review.excerpt.checking",
                            defaultValue: "Checking this quotation against the current text…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    /// Runs the export sheet's own check over every quotation taken from this document.
    ///
    /// Deliberately the SHIPPED rules and not a second copy of them: `ExcerptVerifier.verify`
    /// decides found/not-found, and `upgradingVanished` re-labels the miss on a document an update
    /// removed. Without that second call every quotation on a vanished document would read "this
    /// volume is not on this device" — the exact misreport P3b-1 fixed on the export path, and
    /// this sheet is the ONLY route a vanished document has.
    private func verifyExcerpts() async {
        let items = excerpts
        guard !items.isEmpty else { return }
        let pairs = items.compactMap { entry -> (UUID, ExcerptVerifier.Request)? in
            guard let text = entry.text, !text.isEmpty else { return nil }
            return (entry.id, ExcerptVerifier.Request(volumeId: volumeId, documentId: documentId, text: text))
        }
        // A read failure is not a verdict, so no pipeline degrades every quotation to "could not be
        // checked" rather than to "not found" — the same asymmetry the export sheet applies.
        var bodies: [String: String] = [:]
        if let pipeline = appState.indexingPipeline {
            let key = WordCloudDocumentKey(volumeId: volumeId, documentId: documentId)
            bodies = (try? await pipeline.documentBodyTextsByKey(forKeys: [key])) ?? [:]
        }
        let outcomes = ExcerptVerifier.verify(pairs.map(\.1), bodyTexts: bodies)
        let upgraded = ExcerptVerifier.upgradingVanished(
            outcomes, changeKinds: ["\(volumeId)/\(documentId)": revision?.changeKind ?? ""])
        // A cancelled run must not overwrite the one that replaced it. `.task(id:)` cancels this
        // when a quotation syncs in, but the only suspension point above — a `try?` await — does
        // not throw on cancellation, so without this the older snapshot resumes and writes a
        // dictionary missing the new entry's id, leaving its row on "Checking…" for good: the
        // exact symptom the keyed task exists to remove.
        guard !Task.isCancelled else { return }
        // `uniquingKeysWith`, not `uniqueKeysWithValues`: `CollectionEntry.id` carries no unique
        // constraint (CloudKit forbids one), so a sync can materialise two rows sharing an id and
        // the trapping initialiser would crash the sheet.
        excerptOutcomes = Dictionary(pairs.compactMap { id, request in upgraded[request].map { (id, $0) } },
                                     uniquingKeysWith: { first, _ in first })
    }

    /// The other annotations on the document: counted, never judged.
    private var othersSection: some View {
        let documentEntries = entries.filter { $0.kind == CollectionEntryKind.document.rawValue }.count
        let liveSummaries = summaries.filter { !$0.isHeadnoteDraft }.count
        let parts: [String] = [
            notes.isEmpty ? nil : String(localized: "document.review.other.notes %lld",
                                         defaultValue: "\(notes.count) notes"),
            tagAssignments.isEmpty ? nil : String(localized: "document.review.other.tags %lld",
                                                  defaultValue: "\(tagAssignments.count) tags"),
            documentEntries == 0 ? nil : String(localized: "document.review.other.collections %lld",
                                                defaultValue: "in \(documentEntries) collections"),
            liveSummaries == 0 ? nil : String(localized: "document.review.other.summaries %lld",
                                              defaultValue: "\(liveSummaries) summaries"),
            visitDocuments.isEmpty ? nil : String(localized: "document.review.other.visit",
                                                  defaultValue: "in an archive-visit plan"),
        ].compactMap { $0 }
        return Section {
            if parts.isEmpty {
                Text(String(localized: "document.review.other.none", defaultValue: "No other annotations on this document."))
                    .foregroundStyle(.secondary)
            } else {
                Text(parts.joined(separator: " · "))
            }
            // R-5 P3b-5 (design Q-11 b): the count stays — it is the honest overview — and the
            // annotations the app can OPEN get a row each. Until now the sheet told a reader that
            // a document they had written on had changed and gave them no way to reach what they
            // wrote; the only route was to leave, find the document, and open the rail.
            ForEach(orderedNotes) { note in
                Button {
                    openNote(note)
                } label: {
                    Label {
                        Text(Self.noteRowTitle(note))
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: "note.text")
                    }
                }
                .accessibilityIdentifier("document.review.other.openNote")
            }
            // NOT gated on the document already having tags: the picker's Done replaces the whole
            // assignment set, so clearing the last tag through a gated control would delete the
            // control that opened it and leave no way back. It is also the surface where a reader
            // re-files a document after a correction, which is a reason to add a tag, not only to
            // edit one.
            Button {
                editingTags = true
            } label: {
                Label(String(localized: "document.review.other.editTags",
                             defaultValue: "Edit Tags…"),
                      systemImage: "tag")
            }
            .accessibilityIdentifier("document.review.other.editTags")
            // One row per PLAN, not one control: the seed query is keyed on the document alone, so
            // a document can be seeded into several plans and a single button would open whichever
            // one sorted first. The label promises only to open the plan — the editor takes a whole
            // plan, opens on its Targets tab, and offers no way to focus a seed, so a label saying
            // it would show this document there would be a promise the app cannot keep.
            ForEach(planRows, id: \.id) { row in
                Button {
                    planToOpen = row.plan
                } label: {
                    Label {
                        Text(String(format: String(localized: "document.review.other.openPlan %@",
                                                   defaultValue: "Open the plan “%@”"), row.name))
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: "suitcase")
                    }
                }
                .accessibilityIdentifier("document.review.other.openPlan")
            }
        } header: {
            Text(String(localized: "document.review.other.header", defaultValue: "Other Annotations"))
        } footer: {
            Text(String(localized: "document.review.other.footer.v2",
                        defaultValue: "These carry no position in the text, so the app cannot judge them against the change — it can only take you to them. Review them by eye; a summary describes the text as it was when it was written."))
        }
    }

    /// Opens one note, by the route that platform already uses for every other note.
    ///
    /// macOS has a non-modal composer window whose request type is pure identity, so opening the
    /// same note twice focuses the open window. Routing a second macOS entry point through a sheet
    /// would break that: a reader could edit one note in a window and in a sheet at once, over one
    /// SwiftData row. iOS has no such window and presents the editor as a sheet everywhere.
    private func openNote(_ note: ResearchNote) {
        #if os(macOS)
        // The sheet's own anchor, not the note's: the `@Query` filters on exactly these two, so
        // they are equal by construction, and using the sheet's keeps the request identical to the
        // one every other macOS route builds for this document.
        openWindow(value: NoteComposerRequest(
            documentId: documentId,
            volumeId: volumeId,
            noteId: note.id,
            linkedHighlightId: nil))
        #else
        noteToOpen = NoteEditorRequest(note: note)
        #endif
    }

    /// The archive-visit plans this document is seeded into, in a stable order.
    ///
    /// Resolved through `planId` rather than the seed's `plan` back-reference: the model's own note
    /// on that property says it is managed by the parent's `documents` array, and `planId` is
    /// documented as the field carried "for fast lookups that don't need the full graph". A seed
    /// whose plan cannot be resolved — a CloudKit orphan — contributes no row rather than a row
    /// that opens nothing.
    private var planRows: [(id: UUID, name: String, plan: ArchiveVisitPlan)] {
        var seen = Set<UUID>()
        var rows: [(id: UUID, name: String, plan: ArchiveVisitPlan)] = []
        for seed in visitDocuments {
            guard !seen.contains(seed.planId) else { continue }
            let id = seed.planId
            guard let plan = (try? modelContext.fetch(
                FetchDescriptor<ArchiveVisitPlan>(predicate: #Predicate { $0.id == id })))?.first
            else { continue }
            seen.insert(id)
            // `displayName`, never a local placeholder: `ArchiveVisitPlan` already owns the name a
            // nameless plan is called by, and minting a second one here would have this sheet say
            // "Untitled plan" about the same plan every other surface calls "Untitled Archive Visit".
            rows.append((id: id, name: plan.displayName, plan: plan))
        }
        return rows.sorted {
            let c = $0.name.localizedCaseInsensitiveCompare($1.name)
            return c != .orderedSame ? c == .orderedAscending : $0.id.uuidString < $1.id.uuidString
        }
    }

    /// The notes on this document, in the order the reader first saw them.
    ///
    /// Newest first, and then FROZEN for the life of the sheet — the same treatment
    /// `orderedHighlights` gives its rows, and for a sharper reason here. Opening a note from this
    /// sheet and saving it writes `bodyText`, whose `didSet` stamps `lastModified`, so a live sort
    /// on that field would send the row the reader just tapped to the top the instant they came
    /// back. Working down a list of four notes, they would meet the same one twice and never reach
    /// the last. New arrivals — another device's note syncing in — go to the end rather than
    /// reshuffling what is on screen.
    private var orderedNotes: [ResearchNote] {
        let byRecency = notes.sorted {
            let l = $0.lastModified ?? .distantPast, r = $1.lastModified ?? .distantPast
            return l != r ? l > r : $0.id.uuidString < $1.id.uuidString
        }
        guard !noteOrder.isEmpty else { return byRecency }
        // `uniquingKeysWith`, not `uniqueKeysWithValues`: `ResearchNote.id` carries no unique
        // constraint (CloudKit forbids one), so a sync can materialise two rows sharing an id.
        let rank = Dictionary(noteOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return byRecency.sorted { rank[$0.id] ?? Int.max < rank[$1.id] ?? Int.max }
    }

    /// A note's first line, or a placeholder when it has no text yet.
    ///
    /// Lifted out of the view so it can be tested, and deliberately NOT the note's full body: the
    /// row is a way in, not a reading surface.
    ///
    /// `nonisolated` so the rule is not MainActor-bound merely by living on a `View`: a test, and
    /// any future caller off the main actor, reaches it without an annotation.
    nonisolated static func noteRowTitle(_ note: ResearchNote) -> String {
        // Two CRLF traps, and the obvious code walks into both. `"\r\n"` is ONE Swift `Character`,
        // so `split(separator: "\n")` does not split CRLF text at all and the whole note comes back
        // as its own "first line"; splitting on `isNewline` handles LF, CR and CRLF alike. And
        // `CharacterSet.whitespaces` is space and tab only, so trimming with it would leave a
        // carriage return and print an invisible control character as the title.
        let firstLine = note.bodyText
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        return firstLine.isEmpty
            ? String(localized: "document.review.other.note.untitled", defaultValue: "Open note")
            : firstLine
    }

    /// The document, in the shape the shared tag picker takes — the same three-field synthesis the
    /// Research list already makes when it hands a document to the cross-reference graph.
    ///
    /// The picker reads only `volumeId`, `documentId` and `documentNumber`. It never reads
    /// `isEditorialNote`, which is why letting that field default here does not assert a
    /// classification the sheet has no way to know — but a future entry-consuming editor presented
    /// from this sheet WOULD need the real value, and this is the line to revisit.
    ///
    /// One disclosed cost: the sheet has no document NUMBER, so the picker's title falls back from
    /// "Tags — Doc 12" to "Tags — d12". Resolving the number would cost an indexed lookup for a
    /// sheet title, and the fallback names the document truthfully.
    private var browserEntry: DocumentBrowserEntry {
        DocumentBrowserEntry(documentId: documentId, volumeId: volumeId, header: title)
    }

    // MARK: - The re-anchor search (R-5 P3b-3)

    /// The highlights in the order the reader first saw them.
    ///
    /// The `@Query` sorts on `startOffset`, which a Move rewrites — so without this the row would
    /// jump to a new place in the list at the instant it is tapped. New arrivals (another device's
    /// highlight syncing in) go to the end rather than reshuffling what is on screen.
    private var orderedHighlights: [DocumentHighlight] {
        guard !rowOrder.isEmpty else { return highlights }
        // `uniquingKeysWith`, not `uniqueKeysWithValues`: `DocumentHighlight.id` carries no unique
        // constraint (CloudKit forbids one), so a sync can materialise two rows sharing an id and
        // the trapping initialiser would crash the sheet.
        let rank = Dictionary(rowOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return highlights.sorted { rank[$0.id] ?? Int.max < rank[$1.id] ?? Int.max }
    }

    /// The match a Move would apply, or nil when there is nothing to offer.
    ///
    /// `foundFar` is deliberately excluded: a unique match hundreds of characters away is the
    /// signature of a renumbered document, where this id now names a different document and the
    /// passage belongs to someone else's text. The sheet says what it found; it does not offer the
    /// one-tap repair.
    private func movableMatch(for highlight: DocumentHighlight) -> HighlightReview.Match? {
        guard HighlightReview.status(of: highlight, currentVersion: effectiveVersion) != .aligned else { return nil }
        return Self.offeredMove(searches[highlight.id])
    }

    /// Which search results earn a one-tap Move — lifted out of the view so it can be tested.
    ///
    /// `.foundFar` deliberately does NOT: a unique match hundreds of characters away is the
    /// signature of a renumbered document, where this id names a different document and the words
    /// found are someone else's. The sheet says what it found and offers no repair.
    static func offeredMove(_ search: HighlightReview.Search?) -> HighlightReview.Match? {
        guard case .moved(let match)? = search else { return nil }
        return match
    }

    /// The found passage set in its surroundings, the passage itself emphasised.
    ///
    /// Built from three `Text` runs rather than one formatted string: the emphasis has to survive
    /// into VoiceOver and into every text size, and bracket characters around the passage would be
    /// read aloud as their names and fall back unpredictably outside the system font's coverage.
    /// Nothing here is localizable — every character is the document's own text.
    private func matchContext(for highlight: DocumentHighlight) -> Text? {
        guard let blocks else { return nil }
        let match: HighlightReview.Match
        switch searches[highlight.id] {
        case .moved(let m), .foundFar(let m): match = m
        default: return nil
        }
        let radius = 100
        let before = flatTextExcerpt(blocks: blocks, start: max(0, match.start - radius), end: match.start) ?? ""
        let found = flatTextExcerpt(blocks: blocks, start: match.start, end: match.end) ?? highlight.selectedText
        let after = flatTextExcerpt(blocks: blocks, start: match.end, end: match.end + radius) ?? ""
        var lead = AttributedString("…" + before)
        lead.foregroundColor = .secondary
        var middle = AttributedString(found)
        middle.inlinePresentationIntent = .stronglyEmphasized
        var tail = AttributedString(after + "…")
        tail.foregroundColor = .secondary
        return Text(lead + middle + tail)
    }

    /// Builds the haystack once and searches every stale highlight against it.
    ///
    /// Excerpts are never searched here. They are checked by `verifyExcerpts()` against the
    /// index's body text, which is a different string from this partition — it includes footnote
    /// prose, which the flat text excludes — and the two answer different questions: this one asks
    /// WHERE a passage is, and that one asks WHETHER the words are still in the record.
    ///
    /// **Aligned highlights are not searched.** `renderingVersion` IS a hash of the flat text, so
    /// aligned means the text is byte-identical and the offsets are provably exact; a search could
    /// only agree, or — for a short passage — report several occurrences, which would read as doubt
    /// about an anchor that is certain.
    private func runSearches() async {
        if rowOrder.isEmpty { rowOrder = highlights.map(\.id) }
        if noteOrder.isEmpty { noteOrder = orderedNotes.map(\.id) }
        // Excerpts join the gate (R-5 P3b-4) even though they never search here: the parse is what
        // produces `searchedVersion`, and that is the version a capture must be judged against for
        // the same reason a highlight is — it came from the bytes on disk, while the revision row's
        // `bodyHash` is the INDEX's copy and can predate a re-download that has not been re-indexed
        // yet. Without this, a document carrying only quotations would fall back to that older copy
        // on the Research route, where `currentVersion` is nil, and could report a quotation as
        // captured from an earlier version of a text the reader is no longer looking at.
        guard !isVanished, !highlights.isEmpty || !excerpts.isEmpty else { return }
        guard let dm = appState.downloadManager else { return }
        let url = dm.volumeURL(for: volumeId)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var ast = await appState.documentASTCache.ast(volumeId: volumeId, documentId: documentId)
        if ast == nil,
           let parsed = try? await FRUSDocumentParser().parseDocument(documentId: documentId, volumeURL: url) {
            await appState.documentASTCache.store([parsed], volumeId: volumeId)
            ast = parsed
        }
        guard let ast else { return }
        // A BARE converter: the lookup closures resolve links and change no character of the flat
        // text, and the index's own `bodyHash` is computed the same way.
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(ast)
        let partition = buildFlatTextBlocks(from: model)
        let version = ASTToRenderNodeConverter.renderingVersion(for: model)
        var found: [UUID: HighlightReview.Search] = [:]
        for highlight in highlights {
            guard HighlightReview.status(of: highlight, currentVersion: effectiveVersion) != .aligned else { continue }
            found[highlight.id] = HighlightReview.locate(passage: highlight.selectedText,
                                                         storedStart: highlight.startOffset,
                                                         storedEnd: highlight.endOffset,
                                                         in: partition)
        }
        blocks = partition
        searchedVersion = version
        searches = found
    }

    // MARK: - Sentences

    /// What the search found, or nil where there is nothing to add to the standing line.
    ///
    /// Every sentence says only what an exact search can support. "Not found" never says the
    /// editors deleted the passage: about half of the documents a real correction changes are
    /// RENUMBERED rather than edited, and in those this document id names a different document
    /// altogether, so the passage is elsewhere rather than gone.
    static func searchLine(_ search: HighlightReview.Search) -> String? {
        switch search {
        case .here:
            return String(localized: "document.review.search.here",
                          defaultValue: "Found once, still in this position.")
        case .moved:
            return String(localized: "document.review.search.moved",
                          defaultValue: "Found once, at a new position in the corrected text.")
        case .foundFar:
            return String(localized: "document.review.search.far",
                          defaultValue: "Found once, but far from where it was. This can mean the document was renumbered and this one is not the same document — check it before moving anything by hand.")
        case .notFound:
            return String(localized: "document.review.search.notFound",
                          defaultValue: "Not found in the current text. The passage may have been edited, or this document may have been renumbered.")
        case .ambiguous(let count):
            return String(format: String(localized: "document.review.search.ambiguous %lld",
                                         defaultValue: "Found %lld times, so the app cannot tell which one is yours."),
                          Int64(count))
        case .refused(.tooShort):
            return String(localized: "document.review.search.tooShort.v2",
                          defaultValue: "Too short to look for: a passage this brief can repeat, so finding it once would not prove anything.")
        case .noPassage, .refused:
            return nil
        }
    }

    /// One line per standing. Says what two hashes prove and nothing more.
    static func statusLine(_ status: HighlightReview.Status, vanished: Bool) -> String {
        if vanished {
            return String(localized: "document.review.highlight.orphaned",
                          defaultValue: "The document it was made on is no longer in the volume.")
        }
        switch status {
        case .aligned:
            return String(localized: "document.review.highlight.aligned",
                          defaultValue: "Matches the current text.")
        case .stale(hasPassage: true):
            return String(localized: "document.review.highlight.stale",
                          defaultValue: "Made against an earlier version of the text — its position may have moved.")
        case .stale(hasPassage: false):
            return String(localized: "document.review.highlight.stale.noPassage",
                          defaultValue: "Made against an earlier version of the text, and the words it covered were not stored — it can only be checked by eye.")
        case .unverifiable:
            return String(localized: "document.review.highlight.unverifiable",
                          defaultValue: "This device has no record to compare it against.")
        }
    }

    // MARK: - Actions

    private func loadRevision() async {
        revision = await DocumentChangeBanner.revision(volumeId: volumeId, documentId: documentId,
                                                       pipeline: appState.indexingPipeline)
        loaded = true
    }

    private func markReviewed() async {
        guard let pipeline = appState.indexingPipeline else { return }
        stamping = true
        defer { stamping = false }
        // R-5 P3b-2: the ledger row FIRST, from the hash the reader is dispositioning — it is what
        // carries this review to the reader's other devices. The local stamp follows.
        if let hash = revision?.contentHash, !hash.isEmpty {
            AnnotationReviewStore.record(kind: .document, volumeId: volumeId, documentId: documentId,
                                         contentHash: hash, changeKind: revision?.changeKind,
                                         context: modelContext)
            try? modelContext.save()
        }
        _ = try? await pipeline.markDocumentRevisionReviewed(volumeId: volumeId, documentId: documentId)
        await loadRevision()
        appState.revisionReviewToken += 1
    }
}

// MARK: - NoteEditorRequest

/// One note the reader asked to open from the review sheet (R-5 P3b-5, design Q-11 b).
///
/// Carries the note ITSELF rather than its id, so the presented editor cannot be handed a value
/// that has moved on since the tap — the `.sheet(item:)` failure #862 recorded, where a draft was
/// saved into no context because the closure read a sibling `@State` captured before presentation.
struct NoteEditorRequest: Identifiable {
    let note: ResearchNote
    var id: UUID { note.id }
}
