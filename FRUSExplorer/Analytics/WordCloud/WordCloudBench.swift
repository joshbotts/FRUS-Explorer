// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - WordCloudBench

/// What the Word Cloud settings would do to a sample of terms (S-5b).
///
/// ## Why a settings pane needs this
/// Every control on the Word Cloud pane is a threshold or a filter, and until now each one
/// stated only what it *is* — "Minimum occurrences: 3" — never what it *costs*. A researcher
/// tightening the criteria had to close Settings, open a cloud, and compare it against a memory
/// of the last one. The bench answers on the pane: here are the terms your settings keep, and
/// here is how many of the sample they dropped.
///
/// ## Where the sample comes from
/// Two sources, in order:
///
/// 1. The most recent `.allTerms` cloud on disk (``WordCloudDiskCache/mostRecent(lens:)``) —
///    real terms from the user's own corpus, so the preview is recognisably theirs.
/// 2. ``canonicalSample`` — a fixed, on-theme list, used when there is no suitable entry. Only
///    clouds over persistent scopes are written to disk at all, and entries cached before S-5b
///    carry no lens stamp and are skipped, so falling back is ordinary rather than exceptional.
///
/// Neither touches the search index. Opening Settings must never trigger indexing work, which
/// is the constraint that ruled out computing a live cloud here.
///
/// ## What the bench can and cannot measure
/// A cached cloud was itself produced under whatever criteria were in force at the time, and its
/// term list is capped at the request limit. So the bench measures the current criteria against
/// **that sample**, not against the raw corpus vocabulary, and the pane says "of this sample"
/// for exactly that reason. Two consequences worth stating plainly:
///
/// - **Minimum occurrences barely moves a cached sample.** It is a threshold on raw corpus
///   counts, applied *before* the top terms are chosen, so every term in a cached cloud has
///   already cleared it by a wide margin. The Thresholds footer says so rather than leaving the
///   user to conclude the control is broken.
/// - **`foldPlurals` is unmeasurable here.** Folding happens during tokenisation and cannot be
///   undone from a finished term.
///
/// Minimum length, the built-in stop lists, classification markings, the lens lexicons, and the
/// user's own hidden words all measure exactly.
///
/// Version history:
///   1.0 — S-5b: initial implementation
struct WordCloudBench: Equatable, Sendable {

    /// The terms the current criteria keep, in the sample's own order (descending count).
    let kept: [TermCount]
    /// How many terms the sample contained before filtering.
    let sampleSize: Int
    /// Whether the sample came from the user's own cached cloud rather than the canned list.
    let isFromUserCorpus: Bool

    /// The state before the first evaluation.
    static let empty = WordCloudBench(kept: [], sampleSize: 0, isFromUserCorpus: false)

    /// How many terms survived.
    var keptCount: Int { kept.count }

    /// How many the criteria removed.
    var droppedCount: Int { sampleSize - kept.count }

    // MARK: - Evaluation

    /// Applies a tuning and stop-list set to a term sample.
    ///
    /// The per-term criteria run through ``WordCloudTokenizer/accepts(_:)`` — the same predicate
    /// the tokenizer applies while counting — so the bench cannot claim a term survives when the
    /// cloud would drop it. The occurrence threshold is applied here, mirroring
    /// `WordFrequencyService.finalize`, which is `private static` and so unreachable.
    ///
    /// - Parameters:
    ///   - sample: Candidate terms with their counts.
    ///   - tuning: The user's tunable criteria.
    ///   - lens: The lens whose stop list and lexicon apply.
    ///   - includeDiplomatic: Whether the diplomatic-boilerplate layer is on.
    ///   - extraStopwords: The user's global + per-lens hidden words.
    ///   - isFromUserCorpus: Whether `sample` came from a cached cloud.
    static func evaluate(sample: [TermCount],
                         tuning: WordCloudTuning,
                         lens: WordCloudLens,
                         includeDiplomatic: Bool,
                         extraStopwords: Set<String>,
                         isFromUserCorpus: Bool) -> WordCloudBench {
        let tokenizer = WordCloudTokenizer.configured(
            tuning: tuning,
            lens: lens,
            includeDiplomatic: includeDiplomatic,
            extraStopwords: extraStopwords
        )
        let kept = sample.filter {
            $0.count >= tuning.minimumCount && tokenizer.accepts($0.term.lowercased())
        }
        return WordCloudBench(kept: kept,
                              sampleSize: sample.count,
                              isFromUserCorpus: isFromUserCorpus)
    }

    /// Reads the sample, preferring the user's most recent cached word-path cloud.
    ///
    /// The **whole** cached list, not its head. Taking the top N was the obvious first choice and
    /// it was wrong: a cached cloud is already sorted by descending count, so its first forty
    /// terms all have counts in the hundreds and no length or occurrence threshold the pane
    /// offers can touch them. The bench read as broken — turn a knob, watch nothing happen. The
    /// tail is where the thresholds bite, so the tail has to be in the sample.
    ///
    /// Only `.allTerms` entries qualify — see ``WordCloudDiskCache/mostRecent(lens:)`` for why an
    /// entity-lens cloud would make the numbers meaningless.
    ///
    /// Synchronous disk I/O — call from a `.task`, never a view body.
    ///
    /// - Returns: The terms and whether they are the user's own.
    static func loadSample() -> (terms: [TermCount], isFromUserCorpus: Bool) {
        if let cached = WordCloudDiskCache.mostRecent(lens: .allTerms), !cached.terms.isEmpty {
            return (cached.terms, true)
        }
        return (canonicalSample, false)
    }

    // MARK: - Canned sample

    /// The fallback sample: plausible FRUS vocabulary, chosen so every control visibly moves it.
    ///
    /// Deliberately seeded with one term that dies at each setting, so a user turning a knob
    /// sees the number change instead of wondering whether the control does anything:
    ///
    /// - `war`, `aid` fall out as soon as the minimum length passes 3.
    /// - `détente`, `rapprochement` fall out as the minimum occurrence count rises past 2.
    /// - `telegram`, `memorandum` are diplomatic boilerplate — they vanish with that filter on.
    /// - `confidential`, `priority` are classification markings.
    ///
    /// Single words throughout: a multi-word marking like "top secret" would be dead weight
    /// here, because the word path rejects anything containing a space before it ever consults
    /// the markings layer. Phrases only reach a cloud through the entity lenses.
    static let canonicalSample: [TermCount] = [
        TermCount(term: "negotiation", count: 84),
        TermCount(term: "telegram", count: 71),
        TermCount(term: "ambassador", count: 63),
        TermCount(term: "settlement", count: 55),
        TermCount(term: "negotiations", count: 48),
        TermCount(term: "memorandum", count: 44),
        TermCount(term: "sovereignty", count: 39),
        TermCount(term: "confidential", count: 37),
        TermCount(term: "withdrawal", count: 33),
        TermCount(term: "communiqué", count: 28),
        TermCount(term: "recognition", count: 24),
        TermCount(term: "armistice", count: 21),
        TermCount(term: "delegation", count: 19),
        TermCount(term: "priority", count: 17),
        TermCount(term: "sanctions", count: 15),
        TermCount(term: "ceasefire", count: 13),
        TermCount(term: "mediation", count: 11),
        TermCount(term: "war", count: 9),
        TermCount(term: "protocol", count: 8),
        TermCount(term: "blockade", count: 6),
        TermCount(term: "aid", count: 5),
        TermCount(term: "détente", count: 2),
        TermCount(term: "rapprochement", count: 1),
    ]
}

// MARK: - Row copy

extension WordCloudBench {

    /// "Keeps 18 of 24 terms in this sample" — the consequence line under Thresholds.
    ///
    /// Says "in this sample" rather than implying a corpus-wide count, because the sample is a
    /// bounded, already-filtered list. See the type's caveat.
    var summary: String {
        guard sampleSize > 0 else {
            return String(localized: "settings.wordcloud.bench.pending",
                          defaultValue: "Measuring…")
        }
        return String(format: String(localized: "settings.wordcloud.bench.keeps %lld %lld",
                                     defaultValue: "Keeps %lld of %lld terms in this sample"),
                      Int64(keptCount), Int64(sampleSize))
    }

    /// Where the sample came from, so the numbers above are not mistaken for a corpus statistic.
    var provenance: String {
        isFromUserCorpus
            ? String(localized: "settings.wordcloud.bench.source.cached",
                     defaultValue: "Sampled from your most recent word cloud.")
            : String(localized: "settings.wordcloud.bench.source.canned",
                     defaultValue: "A stand-in sample — open a corpus or subseries cloud and this becomes your own terms.")
    }
}
