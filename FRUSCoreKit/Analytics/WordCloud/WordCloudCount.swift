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

import Foundation

#if canImport(WordCloudKit)
import WordCloudKit
#endif

/// Progress callback for long-running word-cloud computation: `(documents
/// processed, total documents)`. Invoked from the service's actor; handlers that
/// touch UI state must hop to the main actor themselves.
public typealias WordCloudProgress = @Sendable (Int, Int) -> Void

// MARK: - WordCloudCount

/// The word cloud's count: a scope's documents' `body_text`, read from the index in chunks, each document
/// counted by a tokenizer over a tagger's walks, and the top terms kept, stamped with what they were
/// counted under; with the rules by which a result made earlier may stand in for a fresh count.
///
/// `WordFrequencyService`'s count, out of the app (FRUS Explorer Light, S29b), so that a host counts a
/// scope by the app's rules with a tagger of its own: the tokenizer it is given says the lens, the word
/// form and the lists, and the tagger, S29a's `WordCloudTagger`, gives the words, lemmas and classes it
/// walks. The service's caches, in memory and on disk, the scope's resolution and the readiness gate it
/// awaits before it counts stay the app's; the app's count passes NaturalLanguage's tagger, so it counts
/// as it did.
///
/// ## Isolation
/// The count runs where its caller runs (`isolation`), as it ran on the service's actor before it moved:
/// two counts the service asks for one after another still run one after another, and a tagger that is
/// not `Sendable` stays where it was made.
///
/// ## Memory (#1798)
/// Each document is tagged inside an autorelease pool of its own, as `CloudVectorsRunner` tags
/// the corpus. The tagger hands back autoreleased objects, and nothing drained them between
/// chunks, the `await` for each chunk's text included: measured in the test host on an iPhone 17
/// simulator (iOS 27.0) over a full index of 553 volumes, the count kept 70 to 100 KB a
/// document, in every lens, and released none of it when it ended. The default lens held 2.1 GB after
/// 20,000 documents and 4.5 GB after 60,000, so a corpus count would have needed about 25 GB, and
/// the corpus cloud crashed an M1 iPad Pro (#1798). With the pools a count of 5,000 documents
/// peaks 13 MB over its start in the default lens and at nothing in the others, in the same time,
/// and the whole corpus in the default lens peaked at 158 MB, 19 MB over its start, in 17 minutes.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29b): out of `WordFrequencyService` (its count, its
///          `finalize`, and the reuse and persistence rules of its results), public, over a host's tagger
public enum WordCloudCount {

    /// Documents fetched and tokenised per chunk when folding a large scope, kept
    /// modest so peak memory stays bounded even for the whole corpus.
    public static let chunkSize = 400

    /// Counts the documents `keys` name: their `body_text` read from `pipeline` in chunks of
    /// ``chunkSize``, each document counted by `tokenizer` over `tagger`'s walks, the terms that occur
    /// `minimumCount` times or more kept, the first `limit` of them returned, most frequent first, ties
    /// alphabetical, and the result stamped with the tokenizer's lens, the verdict and the index version.
    ///
    /// The tokenizer must count in the verdict's form (`NaturalLanguageHealth.wordForm`), since keyness
    /// ranks the result against the reference counted in its stamp's form (#1608): the app builds both
    /// from one verdict. A host's verdict is its tagger's health.
    ///
    /// - Parameters:
    ///   - keys: The documents whose text feeds the cloud.
    ///   - pipeline: The index the text is read from.
    ///   - tokenizer: The tokenizer the words are counted by, with the lens, the form and the lists.
    ///   - tagger: The tagger whose walks the tokenizer reads: NaturalLanguage's for the app, a host's own.
    ///   - languageAnalysis: The verdict the count is made under and stamped with.
    ///   - indexVersion: `IndexingPipeline.installedDateIndexVersion` as the count began (#1421 review).
    ///   - limit: Maximum number of terms to return.
    ///   - minimumCount: The fewest occurrences a term needs to be kept (`WordCloudTuning.minimumCount`).
    ///   - progress: Optional per-chunk progress callback `(processed, total)`.
    ///   - isolation: Where the count runs: its caller's actor, by default.
    /// - Returns: The counted result.
    /// - Throws: `CancellationError` when the task is cancelled between chunks, and what the index throws.
    public static func count<Tagger: WordCloudTagger>(
        keys: [WordCloudDocumentKey],
        pipeline: IndexingPipeline,
        tokenizer: WordCloudTokenizer,
        tagger: Tagger,
        countedUnder languageAnalysis: NaturalLanguageHealth,
        indexVersion: Int,
        limit: Int,
        minimumCount: Int,
        progress: WordCloudProgress? = nil,
        isolation: isolated (any Actor)? = #isolation
    ) async throws -> WordCloudResult {
        let total = keys.count
        var counts: [String: Int] = [:]
        var tokenTotal = 0
        var documentCount = 0
        var index = 0
        while index < keys.count {
            try Task.checkCancellation()
            let chunk = Array(keys[index..<min(index + chunkSize, keys.count)])
            index += chunkSize
            let texts = try await pipeline.documentBodyTexts(forKeys: chunk)
            documentCount += texts.count
            // A pool for each document (#1798): the tagger hands back autoreleased objects, and
            // nothing drains them between chunks, the `await` above included. Without one, the
            // count kept 70 to 100 KB a document until the process ended; see the type's doc.
            for text in texts {
                tokenTotal += autoreleasepool { tokenizer.accumulate(from: text, into: &counts, tagger: tagger) }
            }
            progress?(min(index, total), total)
        }

        var result = finalize(counts: counts, documentCount: documentCount,
                              totalTokens: tokenTotal, limit: limit,
                              minimumCount: minimumCount)
        // Stamp the lens before persisting: the disk cache names files by a digest of the key,
        // so this is the only way a later reader (the settings bench) can tell an entity cloud
        // from a word cloud. See `WordCloudResult.lens`.
        result.lens = tokenizer.lens
        result.languageAnalysis = languageAnalysis
        result.indexVersion = indexVersion
        return result
    }

    /// The tagger half of ``isReusable(_:for:indexVersion:)``: whether a stored result's own stamp
    /// says the tagger counted `lens` as designed (#1373).
    ///
    /// An entry written before #1373 carries no stamp, and one written since without a working
    /// tagger is never saved — but the stamp is checked on the way back in as well, because the
    /// file is outside this process's control.
    ///
    /// The settings bench asks this half alone, on purpose: it samples a stored cloud as the
    /// reader's vocabulary, to show what the length and occurrence thresholds would keep, and a
    /// count read before a re-index is still that vocabulary. It never stands in for a count.
    public static func isReusable(_ stored: WordCloudResult, for lens: WordCloudLens) -> Bool {
        stored.languageAnalysis?.countsAsDesigned(for: lens) == true
    }

    /// Whether a result read back from the disk cache may stand in for a fresh count under `lens`,
    /// over an index installed at `indexVersion`.
    ///
    /// Both of its stamps must say so: the tagger's (``isReusable(_:for:)``), and the index's
    /// (#1421 review). The disk key fingerprints the index by its document count, which a re-index
    /// that rewrites every body leaves as it was — v59 re-joined 313,949 of them — so only the
    /// stamp can tell a count read from the old text from one read from the new. An entry written
    /// before the stamp has none, and is counted again once.
    ///
    /// - Parameters:
    ///   - stored: The result read back from the disk cache.
    ///   - lens: The lens the caller is counting under.
    ///   - indexVersion: `IndexingPipeline.installedDateIndexVersion` as the count begins.
    public static func isReusable(_ stored: WordCloudResult, for lens: WordCloudLens,
                                  indexVersion: Int) -> Bool {
        isReusable(stored, for: lens) && stored.indexVersion == indexVersion
    }

    /// Whether a count this process made earlier, held in the in-memory cache, may answer a request
    /// counted under `current` — this process's verdict now (#1539).
    ///
    /// A count made as designed always may (``isReusable(_:for:)``): it is what any verdict that
    /// works would count. One that was not — printed forms, or a zero for a lens whose tagger
    /// failed — only while `current` is still the verdict it was counted under. Before #1539 the
    /// verdict could not change within a process and the memory cache needed no rule; now a return
    /// to the foreground can adopt a better one, and the same scope would then count differently.
    ///
    /// - Parameters:
    ///   - cached: The result the memory cache holds for the request's key.
    ///   - lens: The lens the caller is counting under.
    ///   - current: This process's verdict as the request begins.
    public static func isReusableInMemory(_ cached: WordCloudResult, for lens: WordCloudLens,
                                          countedUnder current: NaturalLanguageHealth) -> Bool {
        isReusable(cached, for: lens) || cached.languageAnalysis == current
    }

    /// Whether a result counted under `languageAnalysis` may be written to the disk cache.
    ///
    /// Only when every tagger `lens` reads worked. A later process may have a tagger that does, and
    /// the stored result would otherwise answer for it — a zero for Topics, or printed forms where
    /// that process would count dictionary forms.
    public static func isPersistable(countedUnder languageAnalysis: NaturalLanguageHealth,
                                     lens: WordCloudLens) -> Bool {
        languageAnalysis.countsAsDesigned(for: lens)
    }

    /// Builds the descending top-N term list from a raw tally, dropping terms below
    /// the minimum occurrence count.
    public static func finalize(
        counts: [String: Int],
        documentCount: Int,
        totalTokens: Int,
        limit: Int,
        minimumCount: Int = 1
    ) -> WordCloudResult {
        let top = counts
            .filter { $0.value >= minimumCount }
            .map { TermCount(term: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.term < $1.term }
            .prefix(limit)
        return WordCloudResult(terms: Array(top), documentCount: documentCount, totalTokenCount: totalTokens)
    }
}
