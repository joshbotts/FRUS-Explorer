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

    /// The lines to show, already built for the page on screen.
    let result: ConcordanceResult
    /// The active ordering.
    @Binding var sort: KWICSort
    /// Opens a document when a line is chosen.
    let onOpen: (KWICLine) -> Void

    /// Monospaced so the columns line up character-for-character; a proportional face would make
    /// the margins ragged and defeat the scan.
    private let lineFont = Font.system(.caption, design: .monospaced)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if result.lines.isEmpty {
                emptyState
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
            Text(String(localized: "search.kwic.count",
                        defaultValue: "\(result.lines.count) occurrences"))
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
    /// The page on screen — the concordance covers exactly it.
    let page: Int
    /// Bumped once per COMPLETED search, so a rebuild cannot fire against a half-replaced set.
    let version: Int
}
