// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

// MARK: - SubjectIndexGrouping

/// The pure grouping and filtering behind ``SubjectIndexView``, split out so a test drives the
/// real rule rather than a copy of it — the #1027 lesson.
///
/// Version history:
///   1.0 — Session 2026-08-22: #1023
enum SubjectIndexGrouping {

    /// One initial-letter section of the index.
    struct Section: Identifiable, Equatable {
        /// The section's heading — an initial letter, or `#` for anything not starting with one.
        let letter: String
        /// The subjects filed under it, in catalogue (name) order.
        let subjects: [SubjectIndexRow]
        var id: String { letter }
    }

    /// One row: a subject, and the two reach figures that describe it.
    struct SubjectIndexRow: Identifiable, Equatable {
        /// The durable ref — exact half of the saved-search key.
        let ref: String
        /// Display name, and the fallback half of that key.
        let name: String
        /// Top-level taxonomy category.
        let category: String
        /// Second-level sub-category.
        let subcategory: String
        /// Documents carrying this subject **across the whole corpus**, from the bundled artifact.
        let documentCount: Int
        /// Volumes carrying it, corpus-wide.
        let volumeCount: Int
        var id: String { ref }
    }

    /// Filters by `query` and groups by initial letter.
    ///
    /// Matching is on the NAME and on the `category · subcategory` pair, because a reader who types
    /// "Vietnam" wants the Vietnam Conflict sub-category's subjects as readily as the subject
    /// literally called Vietnam — and because the sub-category is on screen in every row, so a row
    /// visibly containing the typed word must not be filtered out.
    ///
    /// Sections are ordered by letter with `#` last: a heading a reader cannot predict the position
    /// of belongs at the end, not sorted among the letters by its code point.
    static func sections(from rows: [SubjectIndexRow], query: String) -> [Section] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let matching = trimmed.isEmpty ? rows : rows.filter { row in
            row.name.localizedCaseInsensitiveContains(trimmed)
                || row.category.localizedCaseInsensitiveContains(trimmed)
                || row.subcategory.localizedCaseInsensitiveContains(trimmed)
        }
        var byLetter: [String: [SubjectIndexRow]] = [:]
        for row in matching {
            let first = row.name.first.map { String($0).uppercased() } ?? "#"
            byLetter[first.first?.isLetter == true ? first : "#", default: []].append(row)
        }
        return byLetter
            .map { Section(letter: $0.key, subjects: $0.value) }
            .sorted { lhs, rhs in
                if (lhs.letter == "#") != (rhs.letter == "#") { return rhs.letter == "#" }
                return lhs.letter < rhs.letter
            }
    }
}

// MARK: - SubjectIndexView

/// The Subject Explorer: a browsable index of the 491 detected subjects (#1023).
///
/// ## What this surface is for, and what D1 forbade
/// D1 dropped the document-view Subjects accordion and ruled that when the surface returned it
/// would be "a separate view, not an accordion, not the handoff's grid tile". This is that view.
///
/// ## The reach figures are CORPUS-WIDE, and the caption says so
/// The bundled subject index covers all 552 volumes; the SQL tables carry only volumes this reader
/// has indexed. So a row can truthfully read "4,000 documents" and a search for that subject
/// return sixty. Every surface in this app that faces the split discloses it, and a browse whose
/// whole content is counts would be the worst place to start hiding it.
///
/// ## Why the list needs no boot guard and the detail does
/// The vocabulary comes from `DocumentSubjectStore.shared`, a bundled artifact available on the
/// first frame — so the index renders immediately, with no "Preparing your index…" over content
/// that is genuinely ready. Reaching DOCUMENTS goes through `SearchService`, which does not exist
/// until boot completes, so that half guards on `appState.isBootComplete`. Guarding the whole
/// window on boot would spin over a list that could already be read.
///
/// Version history:
///   1.0 — Session 2026-08-22: #1023
struct SubjectIndexView: View {

    /// Where the reader arrived — the whole index, a bucket, or one subject.
    var request: SubjectExplorerRequest = .all

    @Environment(AppState.self) private var appState
    /// The scene this renders in, so a hand-off out of here addresses the presenting window (#338).
    @Environment(\.sceneID) private var sceneID

    /// The catalogue, resolved once. `subjectCatalogue` is cheap now that `subjectsByVolume` is
    /// stored, but it still allocates 491 rows and sorts them, which is not work for `body`.
    @State private var rows: [SubjectIndexGrouping.SubjectIndexRow] = []
    @State private var query = ""
    @State private var selected: SubjectIndexGrouping.SubjectIndexRow?

    var body: some View {
        List {
            if rows.isEmpty {
                unavailableSection
            } else {
                // The disclosure sits ABOVE the index, not in a footer: every row on this screen is
                // a pair of counts, and a caveat a reader reaches only by scrolling 491 rows has
                // been placed where it cannot do its job.
                Section {
                    Text(coverageCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(SubjectIndexGrouping.sections(from: rows, query: query)) { section in
                    Section(section.letter) {
                        ForEach(section.subjects) { row in
                            Button { selected = row } label: { rowLabel(row) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .searchable(text: $query,
                    prompt: Text(String(localized: "subjects.index.search.prompt",
                                        defaultValue: "Search topics")))
        .overlay { emptyResultsOverlay }
        .navigationTitle(String(localized: "subjects.index.title", defaultValue: "Topics"))
        .task { load() }
        .sheet(item: $selected) { row in
            SubjectDetailSheet(subject: row)
                .environment(appState)
                .environment(\.sceneID, sceneID)
        }
    }

    /// The caption that keeps every number on this screen honest.
    private var coverageCaption: String {
        String(format: String(
            localized: "subjects.index.coverage %lld",
            defaultValue: "%lld detected topics across the whole series. Counts describe all 552 volumes, not the volumes you have indexed — a search reaches only what is on this device. Topics are detected automatically from the text, not editorial subject headings, so some are wrong."),
            Int64(rows.count))
    }

    @ViewBuilder
    private func rowLabel(_ row: SubjectIndexGrouping.SubjectIndexRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.name).font(.callout)
            Text("\(row.category) · \(row.subcategory)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: String(
                localized: "subjects.index.row.reach %lld %lld",
                defaultValue: "%lld documents · %lld volumes"),
                Int64(row.documentCount), Int64(row.volumeCount)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The artifact is missing — the same degradation every subject surface takes, stated rather
    /// than shown as an empty index.
    @ViewBuilder
    private var unavailableSection: some View {
        ContentUnavailableView(
            String(localized: "subjects.index.unavailable.title", defaultValue: "Topics Unavailable"),
            systemImage: "tag.slash",
            description: Text(String(
                localized: "subjects.index.unavailable.message",
                defaultValue: "The detected-topic index did not load, so topics cannot be browsed. Everything else in the app is unaffected.")))
    }

    @ViewBuilder
    private var emptyResultsOverlay: some View {
        if !rows.isEmpty,
           SubjectIndexGrouping.sections(from: rows, query: query).isEmpty {
            ContentUnavailableView.search(text: query)
        }
    }

    private func load() {
        guard rows.isEmpty, let index = DocumentSubjectStore.shared else { return }
        rows = index.subjectCatalogue.map {
            SubjectIndexGrouping.SubjectIndexRow(
                ref: $0.ref, name: $0.name, category: $0.category, subcategory: $0.subcategory,
                documentCount: $0.documentCount, volumeCount: $0.volumeCount)
        }
        if case .subject(let ref, _) = request {
            selected = rows.first { $0.ref == ref }
        }
    }
}

// MARK: - SubjectDetailSheet

/// One subject: what it is, how far it reaches, and the two ways into the record (#1023).
///
/// ## Three numbers, three different questions
/// The corpus figures come from the bundled artifact and describe all 552 volumes. The device
/// figure comes from running the browse — `searchCount` over a filter-only `SearchParameters`,
/// which is the same correlated `EXISTS` the search itself runs and is served by the primary key.
/// It is deliberately NOT a new `COUNT(*) … WHERE subject = ?`: `document_subject_refs` has no
/// index on `subject`, so that scans all 877,817 rows, and adding the index costs half the table
/// again in disk plus nearly double the backfill (see the schema comment).
///
/// Version history:
///   1.0 — Session 2026-08-22: #1023
struct SubjectDetailSheet: View {

    /// The subject being shown.
    let subject: SubjectIndexGrouping.SubjectIndexRow

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// Documents this device can actually return — `nil` until counted, and `nil` forever if the
    /// count fails, which the caption renders as "not counted" rather than as zero.
    @State private var deviceCount: Int?
    @State private var counting = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(String(localized: "subjects.detail.category",
                                          defaultValue: "Category"),
                                   value: "\(subject.category) · \(subject.subcategory)")
                    LabeledContent(String(localized: "subjects.detail.corpusDocuments",
                                          defaultValue: "Documents in the series"),
                                   value: subject.documentCount.formatted())
                    LabeledContent(String(localized: "subjects.detail.corpusVolumes",
                                          defaultValue: "Volumes in the series"),
                                   value: subject.volumeCount.formatted())
                    LabeledContent(String(localized: "subjects.detail.onThisDevice",
                                          defaultValue: "Indexed on this device"),
                                   value: deviceCountText)
                } footer: {
                    Text(String(localized: "subjects.detail.footer",
                                defaultValue: "The first three figures describe the whole series, including volumes you have not downloaded. Only the last one is what a search here can return. Topics are detected automatically from the text, not editorial subject headings."))
                }

                Section {
                    Button {
                        findDocuments()
                    } label: {
                        Label(String(localized: "subjects.detail.findDocuments",
                                     defaultValue: "Find documents on this topic"),
                              systemImage: "magnifyingglass")
                    }
                    .disabled(!appState.isBootComplete)
                } footer: {
                    if !appState.isBootComplete {
                        Text(String(localized: "subjects.detail.preparing",
                                    defaultValue: "Available once the index has finished preparing."))
                    }
                }
            }
            .navigationTitle(subject.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
            .task { await countOnThisDevice() }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    /// Three states, not two — the third is the one people forget. A count that could not be taken
    /// is unknown, and reporting it as zero would tell the reader this device has nothing on a
    /// subject it may be full of.
    private var deviceCountText: String {
        if counting {
            return String(localized: "subjects.detail.counting", defaultValue: "Counting…")
        }
        guard let deviceCount else {
            return String(localized: "subjects.detail.countUnavailable", defaultValue: "Not counted")
        }
        return deviceCount.formatted()
    }

    private func countOnThisDevice() async {
        defer { counting = false }
        guard let service = appState.searchService else { return }
        var params = SearchParameters()
        params.subjectRef = subject.ref
        params.subjectName = subject.name
        deviceCount = try? await service.searchCount(parameters: params)
    }

    /// Hands the subject to Search as a filter-only query, carrying BOTH halves of the durable key.
    private func findDocuments() {
        var params = SearchParameters()
        params.subjectRef = subject.ref
        params.subjectName = subject.name
        #if os(macOS)
        appState.openSearch(params, from: sceneID)
        openWindow.fronting(id: "frus.search")
        dismiss()
        #else
        // iOS presents Search from the tab shell, and dismissing one sheet while presenting another
        // in the same state change drops the second — the #833 lesson. Dismiss, then hand off.
        dismiss()
        Task { @MainActor in
            appState.openSearch(params, from: sceneID)
        }
        #endif
    }
}
