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

// MARK: - CollocationView

/// What the query's matches keep company with, across the whole result set.
///
/// ## Shared, like the concordance
/// `SearchView` (iOS) and `SearchSheet` (macOS) are parallel implementations that share no results
/// list. The panel is shared anyway, for the reason the concordance is: a measure whose presentation
/// differs between platforms is a measure that cannot be compared across them.
///
/// ## Two numbers, because one of them is misleading alone
/// The list is ranked on log-likelihood, which measures **evidence** and therefore grows with how
/// much text a scope contains. Window corpora are small, so a merely-common neighbour with a modest
/// lift can outrank the word a researcher would call the collocate — measured in
/// `CollocationAnalysisTests`, `government` at 15× scores 10,277 while `ratify` at 22× scores 371.
/// The effect size sits beside the score for exactly that reason, and the ordering control lets a
/// reader rank on either.
///
/// Version history:
///   1.0 — S-2: initial implementation
struct CollocationView: View {

    /// Which set the search is showing, so the panel can say what it measured over.
    let scope: ResultSetScope

    /// The outcome to present.
    let outcome: CollocationAnalysis.Outcome
    /// Words either side of a match, adjustable here.
    @Binding var windowSize: Int
    /// Which number the list is ordered on.
    @Binding var order: CollocationOrder
    /// Whether a scan is in flight.
    let isLoading: Bool

    /// The window sizes offered. A short list rather than a free stepper: these are the spans that
    /// mean something — a clause, a sentence, a paragraph — and an arbitrary 13 is not a better
    /// question than 10.
    static let windowSizes = [5, 10, 20, 50]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch outcome {
            case .ranked(let result):
                if isLoading { loading } else { list(result) }
            case .unavailable(let reason):
                if isLoading { loading } else { unavailable(reason) }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Picker(selection: $windowSize) {
                    ForEach(Self.windowSizes, id: \.self) {
                        Text(String(format: String(localized: "search.collocation.window %lld",
                                                   defaultValue: "±%lld words"), Int64($0))).tag($0)
                    }
                } label: {
                    Text(String(localized: "search.collocation.window.label", defaultValue: "Within"))
                }
                #if os(macOS)
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                #endif
                Spacer(minLength: 8)
            }
            Picker(selection: $order) {
                ForEach(CollocationOrder.allCases, id: \.self) { Text($0.pickerLabel).tag($0) }
            } label: {
                Text(String(localized: "search.collocation.order.label", defaultValue: "Rank by"))
            }
            .pickerStyle(.segmented)
            #if os(macOS)
            .frame(maxWidth: 300)
            #endif
            if case .ranked(let result) = outcome { caveat(result) }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// What the scan could and could not see. Stated, never implied by a short list.
    private func caveat(_ result: CollocationResult) -> some View {
        var parts: [String] = [
            // WHICH set was measured, before how much of it was seen. Carries no numbers: macOS's
            // over-cap advisory sits above every panel with the same two figures.
            scope.collocationScopeDescription,
            String(format: String(localized: "search.collocation.caveat.scope.v2 %lld %lld",
                                  defaultValue: "%lld matches, in %lld documents that had indexed text."),
                   Int64(result.anchorCount), Int64(result.documentsScanned))
        ]
        if result.wasBounded {
            // Names BOTH numbers. The first version printed the scanned count twice and never the
            // total, so "the first N of them" read as though N were the whole set.
            parts.append(String(format: String(
                localized: "search.collocation.caveat.bounded.v2 %lld %lld",
                defaultValue: "The scan stopped at %lld of your %lld results, so this ranking covers part of them, not all."),
                Int64(result.documentsOffered), Int64(result.documentsInScope)))
        }
        if result.omittedAnchorCount > 0 {
            parts.append(String(format: String(
                localized: "search.collocation.caveat.perDocument %lld",
                defaultValue: "%lld further matches were skipped so no single document can dominate."),
                Int64(result.omittedAnchorCount)))
        }
        if result.referenceCutoffCount > 1 {
            parts.insert(String(format: String(
                localized: "search.collocation.caveat.unpriced %lld",
                defaultValue: "Words occurring fewer than %lld times corpus-wide are unpriced and score as if new."),
                Int64(result.referenceCutoffCount)), at: 0)
        }
        let text = parts.joined(separator: " ")
        return Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .help(text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func list(_ result: CollocationResult) -> some View {
        List(Array(order.apply(to: result.scores, cutoffCount: result.referenceCutoffCount)
                        .enumerated()), id: \.element.id) { index, score in
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 28, alignment: .trailing)
                VStack(alignment: .leading, spacing: 1) {
                    Text(score.term).font(.body)
                    Text(counts(score, result))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                Spacer()
                // The number the list is SORTED on. Always showing G² while ranking on effect made
                // the list look unsorted — the trailing column descended, then did not.
                Text(rankedValue(score))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 56, alignment: .trailing)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: score.term))
            .accessibilityValue(Text(counts(score, result)))
            .contextMenu {
                Button {
                    #if os(iOS)
                    UIPasteboard.general.string = score.term
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(score.term, forType: .string)
                    #endif
                } label: {
                    Label(String(localized: "common.copy", defaultValue: "Copy"),
                          systemImage: "doc.on.doc")
                }
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }

    /// The trailing number, which is always whatever the list is ordered by.
    private func rankedValue(_ score: KeynessScore) -> String {
        switch order {
        case .evidence:
            return Self.scoreFormatter.string(from: NSNumber(value: score.logLikelihood)) ?? ""
        case .effect:
            let fold = score.foldOverRepresentation
            return (fold >= 10 ? fold.formatted(.number.precision(.fractionLength(0)))
                               : fold.formatted(.number.precision(.fractionLength(1)))) + "×"
        }
    }

    /// The row's numbers: the effect size, then both raw counts — with *unpriced* said plainly.
    private func counts(_ score: KeynessScore, _ result: CollocationResult) -> String {
        let fold = score.foldOverRepresentation
        let formatted = fold >= 10
            ? fold.formatted(.number.precision(.fractionLength(0)))
            : fold.formatted(.number.precision(.fractionLength(1)))
        if score.referenceCount == 0, result.referenceCutoffCount > 1 {
            return String(format: String(
                localized: "search.collocation.row.unpriced %@ %lld %lld",
                defaultValue: "%@× more often here · %lld nearby · fewer than %lld corpus-wide (unpriced)"),
                formatted, Int64(score.scopeCount), Int64(result.referenceCutoffCount))
        }
        return String(format: String(
            localized: "search.collocation.row.counts %@ %lld %lld",
            defaultValue: "%@× more often here · %lld nearby · %lld corpus-wide"),
            formatted, Int64(score.scopeCount), Int64(score.referenceCount))
    }

    private var loading: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(String(localized: "search.collocation.loading",
                        defaultValue: "Reading the words around your matches…"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unavailable(_ reason: CollocationAnalysis.Unavailable) -> some View {
        let detail: String
        switch reason {
        case .pending:
            detail = String(localized: "search.collocation.unavailable.pending",
                            defaultValue: "Loading the bundled corpus reference…")
        case .scanFailed:
            detail = String(localized: "search.collocation.unavailable.scanFailed",
                            defaultValue: "The scan couldn’t finish. Try opening this panel again.")
        case .noArtifact:
            detail = String(localized: "search.collocation.unavailable.noArtifact",
                            defaultValue: "The bundled corpus reference could not be loaded, so there is nothing to measure these neighborhoods against.")
        case .configurationMismatch(let mismatches):
            detail = String(format: String(
                localized: "search.collocation.unavailable.mismatch %@",
                defaultValue: "Your Word Cloud settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to rank these neighbors."),
                Self.describe(mismatches))
        case .noMatches:
            detail = String(localized: "search.collocation.unavailable.noMatches",
                            defaultValue: "None of these results contains a whole word this measure can center on. Phrase, wildcard and proximity searches match in ways a word window cannot anchor to.")
        case .noNeighboursAboveFloor(let minimum):
            detail = String(format: String(
                localized: "search.collocation.unavailable.floor %lld",
                defaultValue: "No word appears at least %lld times near your matches. A word used once or twice can top a ranking while telling you nothing about the documents, so nothing is ranked. Widen the window or run a broader search to give this more text to read."),
                Int64(minimum))
        case .nothingDistinctive:
            detail = String(localized: "search.collocation.unavailable.nothingDistinctive",
                            defaultValue: "Nothing near your matches is used more here than across the corpus. That is a real result, not an error: this query sits in ordinary FRUS prose.")
        }
        return ContentUnavailableView(
            String(localized: "search.collocation.unavailable.title", defaultValue: "No Collocates"),
            systemImage: "circle.grid.cross",
            description: Text(detail)
        )
    }

    /// Names the mismatched settings the way the user's own controls do.
    private static func describe(
        _ mismatches: [KeynessBaselineFile.Configuration.Mismatch]
    ) -> String {
        mismatches.map { mismatch in
            switch mismatch {
            case .diplomaticLayer:
                String(localized: "wordcloud.keyness.mismatch.boilerplate",
                       defaultValue: "“Hide common diplomatic words” is off")
            case .foldPlurals:
                String(localized: "wordcloud.keyness.mismatch.plurals",
                       defaultValue: "plural folding differs")
            case .filterMarkings:
                String(localized: "wordcloud.keyness.mismatch.markings",
                       defaultValue: "classification-marking filtering differs")
            case .minimumLength:
                String(localized: "wordcloud.keyness.mismatch.length",
                       defaultValue: "your minimum word length is shorter")
            case .lexicons, .stopwords:
                String(localized: "wordcloud.keyness.mismatch.payload",
                       defaultValue: "the bundled word lists have changed since the reference was built")
            }
        }
        .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        .joined(separator: "; ")
    }

    private static let scoreFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()
}

// MARK: - CollocationOrder

/// Which number the collocate list is ranked on.
///
/// Two orderings rather than one because the two numbers genuinely disagree, and which one a
/// researcher wants depends on the question. Evidence answers "how sure are we"; effect answers
/// "how concentrated is it". Neither is the right default for every query, so the control is
/// visible rather than buried.
enum CollocationOrder: String, CaseIterable, Sendable {
    /// Log-likelihood — the corpus-linguistics standard, and comparable with published figures.
    case evidence
    /// The fold difference — how much more often the word appears here than corpus-wide.
    case effect

    /// The control's label.
    var pickerLabel: String {
        switch self {
        case .evidence: String(localized: "search.collocation.order.evidence", defaultValue: "Evidence")
        case .effect: String(localized: "search.collocation.order.effect", defaultValue: "Concentration")
        }
    }

    /// Applies the ordering. Both are **total** — the term breaks ties — so the list cannot
    /// reshuffle under the reader between renders.
    ///
    /// Concentration sorts **priced terms first**. A term absent from the reference gets the +0.5
    /// continuity correction, which by construction hands it the largest ratio in the list — so a
    /// naive sort by effect returns the unpriced tail and nothing else, each row advertising a
    /// multiple that the same row's "(unpriced)" label says is an upper bound. Ranking a
    /// measurement above an upper bound is the only defensible order.
    func apply(to scores: [KeynessScore], cutoffCount: Int = 1) -> [KeynessScore] {
        switch self {
        case .evidence:
            return scores.sorted { $0.logLikelihood == $1.logLikelihood
                ? $0.term < $1.term : $0.logLikelihood > $1.logLikelihood }
        case .effect:
            func unpriced(_ s: KeynessScore) -> Bool { s.referenceCount == 0 && cutoffCount > 1 }
            return scores.sorted {
                if unpriced($0) != unpriced($1) { return !unpriced($0) }
                return $0.logRatio == $1.logRatio ? $0.term < $1.term : $0.logRatio > $1.logRatio
            }
        }
    }
}

// MARK: - CollocationRebuildKey

/// The inputs that change what a collocation should contain.
///
/// **`page` is deliberately NOT a member**, unlike ``ConcordanceRebuildKey``. The concordance shows
/// the rows on screen, so it must follow the page; a collocation reads the whole retained result set,
/// so turning a page changes nothing about the answer — and rebuilding would rescan thousands of
/// documents to produce the identical ranking.
///
/// `window` **is** a member, because it changes the answer.
struct CollocationRebuildKey: Equatable {
    /// Whether the collocates panel is open at all.
    let mode: Bool
    /// Words either side of a match.
    let window: Int
    /// Bumped once per COMPLETED search, so a rebuild cannot fire against a half-replaced set.
    let version: Int
}

// MARK: - SearchCollocationDefaults

/// Storage keys for the collocation controls.
///
/// Persisted rather than held as view state so the two search surfaces agree, and so the macOS
/// window — which rebuilds its view on retarget — does not silently reset the reader's window size.
enum SearchCollocationDefaults {
    /// Words either side of a match.
    static let windowKey = "frus.search.collocation.window"
    /// Which number the list is ranked on (`CollocationOrder`).
    static let orderKey = "frus.search.collocation.order"
}
