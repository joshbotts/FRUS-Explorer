// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ConcordanceView

/// The keyword-in-context reading of a result page: every occurrence on its own line, the search
/// term in a fixed centre column, context running out to either side.
///
/// ## Shared deliberately
/// `SearchView` (iOS) and `SearchSheet` (macOS) are parallel implementations that do not share a
/// results list — a documented property of this codebase. The *rows* need not be duplicated, so this
/// view is the whole concordance and each host contributes only a mode toggle and the data. Two
/// copies of an alignment layout would drift, and a concordance whose columns differ between
/// platforms is a concordance that cannot be compared across them.
///
/// ## Alignment is the feature
/// The three columns are fixed-width so the eye can run down the margins. That is what makes a
/// repeated formula visible: twenty lines whose left column ends the same way are a house style, and
/// nothing about a list of snippets would show it. The left column is **trailing**-aligned for the
/// same reason — the words nearest the match line up against the centre.
///
/// Version history:
///   1.0 — R-3b: initial implementation
struct ConcordanceView: View {

    /// Which set the search is showing, so the occurrence count can name its own denominator.
    let scope: ResultSetScope

    /// The lines to show, already built for the page on screen.
    let result: ConcordanceResult
    /// The active ordering.
    @Binding var sort: KWICSort
    /// Opens a document when a line is chosen.
    let onOpen: (KWICLine) -> Void

    /// The context radius the lines were built with, so the table can be sized to show it
    /// (UI review P-3). Defaults to `SearchService.concordance`'s own default.
    var contextRadius: Int = 60

    /// Width this view was given, measured rather than assumed — the two-pane and inspector
    /// layouts mean the tab's width is not the container's.
    @State private var availableWidth: CGFloat = 0

    /// Monospaced so the columns line up character-for-character; a proportional face would make
    /// the margins ragged and defeat the scan.
    private let lineFont = Font.system(.caption, design: .monospaced)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if result.lines.isEmpty {
                emptyState
            } else if ConcordanceMetrics.needsHorizontalScroll(radius: contextRadius,
                                                              available: availableWidth) {
                // **P-3: the columns keep their geometry and the viewport scrolls.** The lines
                // already carry a 60-character radius; a phone was showing about a quarter of it
                // and calling the result a concordance. A phone-specific arrangement would break
                // this view's own stated contract — that columns must not differ between
                // platforms, or two concordances cannot be compared — so the table is laid out at
                // its natural width everywhere and only the narrow screen scrolls to it.
                //
                // ONE scroll view over the whole table, both axes. Per-row horizontal scrolling
                // would let rows drift out of step, which destroys the alignment that is the
                // entire feature.
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sort.apply(to: result.lines)) { line in
                            Button { onOpen(line) } label: { row(line) }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            Divider()
                        }
                    }
                    .frame(width: ConcordanceMetrics.tableWidth(radius: contextRadius,
                                                                available: availableWidth),
                           alignment: .leading)
                    .padding(.horizontal)
                }
            } else {
                List(sort.apply(to: result.lines)) { line in
                    Button { onOpen(line) } label: { row(line) }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                }
                #if os(iOS)
                .listStyle(.plain)
                #else
                .listStyle(.inset)
                #endif
            }
            if result.omittedCount > 0 || result.documentsWithoutLines > 0 { caveats }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.width, initial: true) { _, width in
                        availableWidth = width
                    }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Picker(selection: $sort) {
                ForEach(KWICSort.allCases, id: \.self) { Text($0.pickerLabel).tag($0) }
            } label: {
                Text(String(localized: "search.kwic.sort", defaultValue: "Align by"))
            }
            #if os(macOS)
            .pickerStyle(.segmented)
            .frame(maxWidth: 380)
            #endif
            Spacer(minLength: 8)
            // Qualified by the set it came from: a bare "214 occurrences" travels out of context
            // in a screenshot with nothing to say it came from 25 documents rather than a thousand.
            Text(scope.concordanceCountDescription(occurrences: result.lines.count))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func row(_ line: KWICLine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(line.left)
                    .lineLimit(1)
                    .truncationMode(.head)          // keep the words NEAREST the match
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(line.match)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .layoutPriority(1)               // the term never truncates; it is the anchor
                Text(line.right)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(lineFont)
            Text(sourceLabel(line))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        // VoiceOver reads the line as a sentence; the visual alignment carries no meaning aloud.
        .accessibilityLabel(Text("\(line.left) \(line.match) \(line.right). \(sourceLabel(line))"))
        .accessibilityHint(Text(String(localized: "search.kwic.open.hint",
                                       defaultValue: "Opens this document")))
    }

    private func sourceLabel(_ line: KWICLine) -> String {
        let date = line.dateISO.map { String($0.prefix(10)) }
        return [line.header, date].compactMap { $0 }.joined(separator: " · ")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "search.kwic.empty.title", defaultValue: "No Aligned Occurrences"),
            systemImage: "text.alignleft",
            description: Text(String(
                localized: "search.kwic.empty.detail",
                defaultValue: "These results matched, but none of their text could be aligned on your search term. Phrase, wildcard and proximity searches match in ways a concordance cannot centre on a single word."
            ))
        )
    }

    /// What the concordance could not show. Stated rather than left to be inferred from a short list.
    private var caveats: some View {
        VStack(alignment: .leading, spacing: 2) {
            if result.omittedCount > 0 {
                Text(String(localized: "search.kwic.omitted",
                            defaultValue: "\(result.omittedCount) further occurrences aren’t shown — each document contributes at most \(KWICBuilder.maxLinesPerDocument) lines."))
            }
            if result.documentsWithoutLines > 0 {
                Text(String(localized: "search.kwic.unaligned",
                            defaultValue: "\(result.documentsWithoutLines) matching documents contributed no line — their match isn’t a whole word this view can centre on."))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

// MARK: - ConcordanceRebuildKey

/// The inputs that change what a concordance page should contain.
///
/// A `.task(id:)` key rather than three `onChange` handlers: the rebuild is one async unit of work,
/// and three handlers racing to start it is how the occurrence measure acquired a second producer
/// against a shared token.
///
/// **`sort` is deliberately NOT a member.** Sorting is applied at render time, over lines already in
/// memory; including it here would make every change of ordering a database fetch and a scan — a
/// visible stall for a control that should feel instantaneous. The key names only what changes which
/// lines EXIST, not how they are arranged.
struct ConcordanceRebuildKey: Equatable {
    /// Whether concordance mode is open at all.
    let mode: Bool
    /// The documents on screen — the concordance covers exactly them.
    ///
    /// This was the page *index*, which is not the same thing. Two things change which documents
    /// a page holds without re-running a search or moving the page: **changing the sort order**
    /// (`sortedResults` re-orders `results` in place) and **marking a document reviewed** in
    /// checklist mode (`displayedResults` drops it and everything after shifts up). Neither moved
    /// `page` or `version`, so neither rebuilt, and the concordance went on showing lines from
    /// documents that were no longer on screen.
    ///
    /// That is precisely the failure the page bound exists to prevent:
    /// `SearchService.concordance(for:parameters:radius:)` takes the caller's displayed rows rather
    /// than re-running the query specifically so "the concordance and the list [cannot] disagree
    /// about what they are showing". Keying on the identity of those rows is what actually
    /// enforces it; keying on the page index only enforced it against paging.
    ///
    /// Empty while `mode` is false, so the composite keys are not built on every body pass of a
    /// screen that is not showing a concordance.
    let documentKeys: [String]
    /// Bumped once per COMPLETED search, so a rebuild cannot fire against a half-replaced set.
    ///
    /// Still needed alongside ``documentKeys``: a new query can match the same documents while
    /// centring on a different term, and the lines would differ though the keys did not.
    let version: Int

    /// Builds the key for a host, taking the rows only when a concordance is actually open.
    ///
    /// - Parameters:
    ///   - mode: whether concordance mode is on.
    ///   - rows: the displayed page. Not read at all when `mode` is false.
    ///   - version: the host's completed-search counter.
    init(mode: Bool, rows: @autoclosure () -> [SearchResult], version: Int) {
        self.mode = mode
        self.documentKeys = mode ? rows().map { "\($0.volumeId)/\($0.documentId)" } : []
        self.version = version
    }
}
