// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ProfileAggregator

/// The pure (filesystem-free) core that turns the decoded `document_subjects.json`
/// into per-volume "top subjects" profiles. Keeping it pure makes the scoring and the
/// byte-stability guarantee unit-testable from in-memory fixtures.
///
/// ## Scoring
///
/// For a (volume, subject) pair the distinctiveness weight is TF-IDF-style:
///
///     score = (docsInVolumeWithSubject / distinctDocsInVolume)
///             × ln(corpusDistinctDocs / subjectCorpusDocFreq)
///
/// The term factor is the fraction of the volume's tagged documents that carry the
/// subject; the IDF factor down-weights subjects that are common across the whole
/// corpus. Document-frequency IDF (not volume-frequency) is used deliberately:
/// volume-frequency IDF over-boosts corpus-rare taxonomy artifacts (a subject with a
/// dozen scattered documents would float to the top of a volume).
///
/// ## Genericity floor
///
/// Subjects whose corpus document-frequency exceeds `genericityThreshold` (a fraction
/// of all tagged corpus documents) are dropped entirely — the handful of pure
/// meta-topics ("War", "Peace", "Treaties…", "Trade relations", …) that would
/// otherwise top every volume. The threshold is applied to the data as-loaded, so it
/// re-derives correctly if the source dataset changes.
///
/// A per-volume minimum instance count (`minDocCount`) additionally suppresses
/// single-document noise before ranking.
enum ProfileAggregator {

    /// Derivation parameters (defaults tuned on 19th-c / WWII / Vietnam sample volumes).
    struct Parameters: Sendable {
        /// Subjects appearing in more than this fraction of all tagged corpus documents
        /// are excluded as too generic. Default `0.10`.
        let genericityThreshold: Double
        /// Minimum documents a subject must tag in a volume to be eligible. Default `2`.
        let minDocCount: Int
        /// Maximum subjects kept per volume. Default `15`.
        let topN: Int

        /// Memberwise initializer.
        ///
        /// - Parameters mirror the stored properties.
        init(genericityThreshold: Double = 0.10, minDocCount: Int = 2, topN: Int = 15) {
            self.genericityThreshold = genericityThreshold
            self.minDocCount = minDocCount
            self.topN = topN
        }
    }

    /// Aggregation statistics, surfaced for logging / provenance (not serialized).
    struct Stats: Sendable {
        /// Distinct (volume, document) pairs carrying at least one subject.
        let corpusDistinctDocs: Int
        /// Subjects excluded by the genericity threshold.
        let genericSubjectCount: Int
        /// Distinct subjects that survived into at least one volume's top-N.
        let usedSubjectCount: Int
        /// Volumes that produced a non-empty profile.
        let volumeCount: Int
        /// (subject, volume) entries dropped by the #308 era-sanity pass (anachronistic tags).
        let eraSanityDropped: Int
        /// Era-sanity table subject names absent from this drop (rename/typo) — a warning signal.
        let eraSanityUnmatched: [String]
    }

    /// Builds the index plus its stats from the decoded input.
    ///
    /// - Parameters:
    ///   - input: The decoded `document_subjects.json`.
    ///   - parameters: The scoring/filter parameters.
    ///   - schemaVersion: The output schema version.
    ///   - generated: The `yyyy-MM-dd` generation stamp for the output.
    ///   - provenance: The human-readable provenance string for the output.
    /// - Returns: The built index and its aggregation stats.
    static func aggregate(
        input: DocumentSubjectsInput,
        parameters: Parameters,
        volumeCoverageEndYear: [String: Int],
        schemaVersion: Int,
        generated: String,
        provenance: String
    ) -> (index: VolumeSubjectProfilesIndex, stats: Stats) {

        // #308 era-sanity (review F2): resolve the name-keyed anachronism table to this drop's
        // refs, so the per-(subject, volume) filter below is an O(1) lookup.
        let (emergenceByRef, eraSanityUnmatched) = EraSanity.refYearMap(
            namesByRef: input.subjectsIndex.mapValues(\.name))
        // Always 0: the gate is retired (see the note at its former application site). The field
        // is KEPT rather than deleted so the runner can report "retired" explicitly — a stat that
        // silently vanished would read, to anyone diffing two runs, as a gate that found nothing.
        let eraSanityDropped = 0

        // Per-subject, per-volume distinct document ids.
        // subjectVolumeDocs[ref][volumeId] = Set<docId>
        var subjectVolumeDocs: [String: [String: Set<String>]] = [:]
        // Per-subject corpus document-frequency (distinct (volume,doc) pairs).
        var subjectCorpusDocFreq: [String: Int] = [:]
        // Per-volume distinct tagged (volume,doc) pairs (union across all subjects).
        var volumeDocSets: [String: Set<String>] = [:]

        for (ref, byVolume) in input.subjects {
            var volMap: [String: Set<String>] = [:]
            var corpusFreq = 0
            for (volumeId, joined) in byVolume {
                let docs = DocumentSubjectsInput.documentIds(from: joined)
                guard !docs.isEmpty else { continue }
                volMap[volumeId] = docs
                corpusFreq += docs.count
                volumeDocSets[volumeId, default: []].formUnion(docs)
            }
            subjectVolumeDocs[ref] = volMap
            subjectCorpusDocFreq[ref] = corpusFreq
        }

        let corpusDistinctDocs = volumeDocSets.values.reduce(0) { $0 + $1.count }
        let genericCutoff = Double(corpusDistinctDocs) * parameters.genericityThreshold

        // The generic subjects (corpus doc-frequency above the cutoff), excluded wholesale.
        let genericRefs = Set(subjectCorpusDocFreq
            .filter { Double($0.value) > genericCutoff }
            .map(\.key))

        let idfDenominator = Double(corpusDistinctDocs)

        // Score every eligible (volume, subject); keep the top-N per volume.
        // Accumulate the per-volume ranked refs first, then factor the vocabulary.
        var rankedByVolume: [String: [(ref: String, score: Double)]] = [:]

        for (volumeId, taggedDocs) in volumeDocSets {
            let distinctDocsInVolume = taggedDocs.count
            guard distinctDocsInVolume > 0 else { continue }
            var scored: [(ref: String, score: Double)] = []
            for (ref, volMap) in subjectVolumeDocs {
                if genericRefs.contains(ref) { continue }
                guard let docs = volMap[volumeId], docs.count >= parameters.minDocCount else { continue }
                // #308 era-sanity: RETIRED 2026-08-20, owner decision. The gate is not applied.
                //
                // It tested the SUBJECT HEADING's earliest-plausible year against the volume's
                // coverage end — but a tag is produced by the subject's match VARIANTS, and those
                // deliberately predate the heading. Measured over the whole corpus, that made
                // every one of its 92 drops wrong:
                //
                //   Refugees (1921)  74 drops — matches `Refugees` itself; frus1875v02 is a US
                //                              minister sheltering 80 political refugees in his
                //                              legation, frus1891 refugees taken off by boat in
                //                              the Chilean civil war. Also violates the table's
                //                              OWN rule: perennial concepts are excluded on
                //                              purpose (see EraSanity's note on Human rights).
                //   Cold War (1947)   9 drops — matches `Atomic weapons`, `Berlin issue`,
                //                              `Communist parties`, `Soviet bloc`.
                //   EEC (1957)        6 drops — matches `Conference on European Economic
                //                              Cooperation` (1947), `Schuman Plan` (1950),
                //                              `European Coal and Steel Community` (1951).
                //   NATO (1949)       3 drops — matches `North Atlantic Pact` and `North Atlantic
                //                              defense arrangements, proposed`.
                //
                // The dormant entries share the flaw and were only waiting for a volume to line
                // up: `United Nations` matches `Disputes, pacific settlement of`, `World War I`
                // matches 34 variants including `Baltic countries`.
                //
                // Its motivating case is also gone: the comment cites HIV/AIDS surfacing in a
                // 1964-68 volume, and in the corrected export AIDS drops ZERO — it appears in four
                // 1981-88 volumes and all 45 assignments were read and verified as genuine.
                //
                // NOT FIXABLE BY EDITING THE TABLE. The sound test needs the earliest plausible
                // year of the variant that ACTUALLY MATCHED, and `document_subjects.json` records
                // only subject -> volume -> documents; it never says which variant fired. That is
                // an upstream schema change. `EraSanity` is kept, unapplied, so the research and
                // the measurements survive for whoever gets that data.
                //
                // The risk it guarded is real — TF-IDF can amplify a rare anachronism into a
                // top-ranked volume subject, which is why volume grain differs from document
                // grain — but there is no instance of it in this data, and the gate cost 92
                // legitimate entries to guard against none.
                let corpusFreq = subjectCorpusDocFreq[ref] ?? docs.count
                guard corpusFreq > 0 else { continue }
                let tf = Double(docs.count) / Double(distinctDocsInVolume)
                let idf = log(idfDenominator / Double(corpusFreq))
                let score = round(tf * idf * 10000) / 10000
                guard score > 0 else { continue }
                scored.append((ref, score))
            }
            // Deterministic order: score desc, then ref asc for ties.
            scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.ref < $1.ref }
            if scored.count > parameters.topN { scored = Array(scored.prefix(parameters.topN)) }
            if !scored.isEmpty { rankedByVolume[volumeId] = scored }
        }

        // Build the vocabulary from the refs that survived into some top-N, sorted by
        // ref for stable indices.
        let usedRefs = Set(rankedByVolume.values.flatMap { $0.map(\.ref) }).sorted()
        var indexForRef: [String: Int] = [:]
        indexForRef.reserveCapacity(usedRefs.count)
        var vocab: [VocabSubject] = []
        vocab.reserveCapacity(usedRefs.count)
        for (i, ref) in usedRefs.enumerated() {
            indexForRef[ref] = i
            let meta = input.subjectsIndex[ref]
            vocab.append(VocabSubject(
                ref: ref,
                name: meta?.name ?? ref,
                category: meta?.category ?? "Uncategorized",
                subcategory: meta?.subcategory ?? ""
            ))
        }

        // Emit profiles sorted by volumeId; entries already ranked.
        let profiles = rankedByVolume.keys.sorted().map { volumeId -> VolumeProfile in
            let entries = rankedByVolume[volumeId]!.map { row in
                ScoredSubject(vocabIndex: indexForRef[row.ref]!, score: row.score)
            }
            return VolumeProfile(volumeId: volumeId, entries: entries)
        }

        let index = VolumeSubjectProfilesIndex(
            schemaVersion: schemaVersion,
            generated: generated,
            provenance: provenance,
            vocab: vocab,
            profiles: profiles
        )
        let stats = Stats(
            corpusDistinctDocs: corpusDistinctDocs,
            genericSubjectCount: genericRefs.count,
            usedSubjectCount: vocab.count,
            volumeCount: profiles.count,
            eraSanityDropped: eraSanityDropped,
            eraSanityUnmatched: eraSanityUnmatched
        )
        return (index, stats)
    }
}
