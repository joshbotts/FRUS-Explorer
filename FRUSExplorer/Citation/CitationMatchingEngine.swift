// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitationMatchingEngine

/// Resolves a `CitationInput` to a ranked list of `CitationMatch` results.
///
/// ## Strategy priority order
///
/// | Priority | Strategy | Condition |
/// |---|---|---|
/// | 1 | `exactDocumentNumber` | Post-1955–57, vol resolved, doc number present |
/// | 2 | `pageRange` | Vol resolved, page number present, page data exists |
/// | 3 | `superimposedDocumentNumber` | Pre-1955–57, vol resolved, doc number present |
/// | 4 | `fuzzyDocumentNumber` | Doc number not found; nearest ±N surfaced |
/// | 5 | `titleFragmentMatch` | Vol number ambiguous; title text narrows candidates |
/// | 6 | `manifestOnly` | Vol identified but not in local corpus |
/// | 7 | `bestGuess` | Multiple corrections applied |
///
/// ## Era detection
/// Pre-1955–57 volumes are identified by subseries strings that start before `"1955"` or
/// contain single-year identifiers before that year (e.g. `"1861"`, `"1950"`). The
/// authoritative check uses the volume's `subseries` field from the manifest.
///
/// ## Two-stage undownloaded behavior
/// Stage 1: Volume resolved via manifest → `CitationMatch(requiresDownload: true)`.
/// Stage 2: After download completes, the caller re-invokes `match(input:)` and the
/// engine falls through to a full document-level match.
///
/// ## Log prefix
/// `[CitationMatcher]`
///
/// Version history:
///   1.0 — Session 30: initial implementation
///   1.1 — Authoring Phase 3 review: `noteVolumeDownloaded(_:)` — the downloaded-volume
///          set was a boot-time snapshot, so the advertised "download, then re-resolve"
///          loop could not succeed until the next app relaunch
public actor CitationMatchingEngine {

    // MARK: - Dependencies

    private let manifestStore: ManifestStore
    private let searchService: SearchService?
    private let pageRangeStore: PageRangeStore?

    /// Volume ids present in the local corpus. Seeded from disk at init and kept
    /// current via `noteVolumeDownloaded(_:)` as volumes finish downloading/indexing.
    private var downloadedVolumeIds: Set<String>

    // MARK: - Init

    public init(
        manifestStore: ManifestStore,
        searchService: SearchService?,
        pageRangeStore: PageRangeStore?,
        downloadedVolumeIds: Set<String>
    ) {
        self.manifestStore     = manifestStore
        self.searchService     = searchService
        self.pageRangeStore    = pageRangeStore
        self.downloadedVolumeIds = downloadedVolumeIds
    }

    // MARK: - Public API

    /// Marks a volume as locally available, enabling document-level match strategies
    /// for it without recreating the engine.
    ///
    /// Called from `AppState.connectIndexingProgress` when a volume finishes indexing
    /// (downloads auto-index), so the "download this volume, then resolve again" loop
    /// advertised by `CitationLookupView` and the Add Documents sheet works within a
    /// session — the init-time set is only a boot snapshot of the volumes directory.
    public func noteVolumeDownloaded(_ volumeId: String) {
        downloadedVolumeIds.insert(volumeId)
    }

    /// Resolves the input to a ranked list of matches.
    /// Returns an empty array when the input lacks sufficient information.
    public func match(input: CitationInput) async throws -> [CitationMatch] {
        guard input.isActionable else {
            #if DEBUG
            print("[CitationMatcher] input not actionable — returning empty")
            #endif
            return []
        }

        let candidates = await resolveVolume(
            subseries: input.subseries,
            volumeNumber: input.volumeNumber,
            titleFragment: input.titleFragment
        )

        guard !candidates.isEmpty else {
            // Can't resolve any volume — best guess
            if let sub = input.subseries {
                return [CitationMatch(
                    documentId: "",
                    volumeId: "",
                    rank: 1,
                    matchStrategy: .bestGuess(explanation: "No volumes found for subseries '\(sub)'"),
                    confidenceLabel: ConfidenceLabels.bestGuess("No FRUS volumes match the subseries '\(sub)' in the local manifest."),
                    correctionNote: nil
                )]
            }
            return []
        }

        var results: [CitationMatch] = []
        var rank = 1

        for volumeEntry in candidates.prefix(3) {
            let volumeId = volumeEntry.volumeId
            let downloaded = downloadedVolumeIds.contains(volumeId)

            if !downloaded {
                // Stage 1: manifest-only result
                results.append(CitationMatch(
                    documentId: "",
                    volumeId: volumeId,
                    rank: rank,
                    matchStrategy: .manifestOnly,
                    confidenceLabel: ConfidenceLabels.manifestOnly,
                    requiresDownload: true,
                    volumeManifestEntry: volumeEntry
                ))
                rank += 1
                continue
            }

            let preModern = isPreModernVolume(volumeEntry)
            let microfiche = isMicroficheSupplement(volumeEntry)

            // Strategy 1 / 3: Document number match
            if let docNum = input.documentNumber {
                if let match = try await matchByDocumentNumber(
                    volumeId: volumeId, volumeEntry: volumeEntry,
                    documentNumber: docNum,
                    rank: rank, preModern: preModern
                ) {
                    results.append(match)
                    rank += 1
                    if match.matchStrategy == .exactDocumentNumber { break }
                }
            }

            // Strategy 2: Page range match (skip for microfiche)
            if let pageNum = input.pageNumber, !microfiche {
                if let match = try await matchByPageRange(
                    volumeId: volumeId, volumeEntry: volumeEntry,
                    pageNumber: pageNum, rank: rank
                ) {
                    results.append(match)
                    rank += 1
                }
            }
        }

        // Strategy 4: Fuzzy doc number if no exact match found
        if results.isEmpty || results.allSatisfy({ $0.matchStrategy != .exactDocumentNumber }),
           let docNum = input.documentNumber,
           let volumeEntry = candidates.first,
           downloadedVolumeIds.contains(volumeEntry.volumeId) {
            if let fuzzy = try await matchByFuzzyDocumentNumber(
                volumeId: volumeEntry.volumeId,
                volumeEntry: volumeEntry,
                documentNumber: docNum,
                rank: rank
            ) {
                // Only append if not already a better match
                if !results.contains(where: { $0.volumeId == volumeEntry.volumeId }) {
                    results.append(fuzzy)
                }
            }
        }

        return results.sorted { $0.rank < $1.rank }
    }

    // MARK: - Volume Resolution

    /// Resolves subseries + volume number + title fragment to candidate manifest entries,
    /// best match first.
    ///
    /// A strong title-fragment match can **override** the subseries filter. This is essential for
    /// the round-trip of the app's own citations for pre-1906 "Papers Relating to Foreign Affairs"
    /// volumes (#216): their only year is the *print* year (e.g. 1864 for a `frus1863` volume) and
    /// carries no coverage year, so subseries resolution alone lands on the wrong volume group —
    /// only the title ("First Session … Part II") disambiguates. The comparison is a normalized
    /// token-subset test, so the manifest titles' embedded newlines/punctuation don't defeat it.
    func resolveVolume(
        subseries: String?,
        volumeNumber: String?,
        titleFragment: String?
    ) async -> [VolumeManifestEntry] {
        let allVolumes = await manifestStore.bundledEntries

        // Subseries-derived set (may be the WRONG group when the citation's only year is a print
        // year); falls back to the whole manifest when the subseries matches nothing.
        var subseriesCandidates = allVolumes
        if let sub = subseries {
            let normalized = normalizeSubseries(sub)
            let filtered = allVolumes.filter { normalizeSubseries($0.subseries) == normalized }
            if !filtered.isEmpty { subseriesCandidates = filtered }
        }

        // Narrows a set by the parsed volume number; a no-op when nothing matches so it never
        // empties an otherwise-good candidate list.
        func applyVolumeNumber(_ set: [VolumeManifestEntry]) -> [VolumeManifestEntry] {
            guard let vol = volumeNumber else { return set }
            let filtered = set.filter { volumeMatchesEntry(vol, entry: $0) }
            return filtered.isEmpty ? set : filtered
        }

        // Title-fragment resolution / subseries correction.
        if let fragment = titleFragment {
            let fragTokens = titleTokens(fragment)
            if !fragTokens.isEmpty {
                // A substantial fragment can OVERRIDE the subseries: find volumes whose title
                // contains ALL of its tokens — a full, unambiguous match (e.g. only frus1863p2
                // carries both "First Session" and "Part II"). Reserved for multi-token fragments
                // so a single generic word can't hijack resolution across the whole manifest.
                if fragTokens.count >= 4 {
                    let fullMatches = allVolumes.filter { fragTokens.isSubset(of: titleTokens($0.title)) }
                    if !fullMatches.isEmpty {
                        let inSubseries = fullMatches.filter { e in
                            subseriesCandidates.contains { $0.volumeId == e.volumeId }
                        }
                        // Prefer full matches that also satisfy the subseries; otherwise the title
                        // corrects a print-year subseries collision.
                        return applyVolumeNumber(inSubseries.isEmpty ? fullMatches : inSubseries)
                    }
                }
                // Otherwise (short fragment, or no full match) apply the explicit volume number
                // FIRST — it stays authoritative — then narrow that set by token overlap, keeping
                // only the best-scoring volumes. This preserves the historic "narrow by a
                // distinctive title word" behavior (e.g. "Vietnam") and ranks multi-token fragments
                // for `match()`'s prefix(3), without letting a title word override an explicit
                // volume number.
                let byVolume = applyVolumeNumber(subseriesCandidates)
                let scored = byVolume
                    .map { entry in (entry: entry, overlap: fragTokens.intersection(titleTokens(entry.title)).count) }
                    .filter { $0.overlap > 0 }
                    .sorted { $0.overlap > $1.overlap }
                if let maxOverlap = scored.first?.overlap {
                    return scored.filter { $0.overlap == maxOverlap }.map(\.entry)
                }
                return byVolume
            }
        }

        return applyVolumeNumber(subseriesCandidates)
    }

    /// Normalized token set of a title or citation fragment: lowercased, with every non-alphanumeric
    /// character (punctuation, and the embedded newlines the TEI manifest titles carry) reduced to a
    /// separator. Single-character tokens are kept so Roman-numeral part markers ("I" vs "II") stay
    /// distinguishable.
    private func titleTokens(_ s: String) -> Set<String> {
        let separated = s.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }
        return Set(String(separated).split(separator: " ").map(String.init))
    }

    // MARK: - Document Number Match

    private func matchByDocumentNumber(
        volumeId: String,
        volumeEntry: VolumeManifestEntry,
        documentNumber: Int,
        rank: Int,
        preModern: Bool
    ) async throws -> CitationMatch? {
        guard let service = searchService else { return nil }

        var params = SearchParameters()
        params.keywords = "\(documentNumber)"
        params.volumeIds = [volumeId]
        let results = try await service.search(parameters: params)

        if let hit = results.first(where: { $0.documentNumber == "\(documentNumber)" }) {
            let strategy: MatchStrategy = preModern ? .superimposedDocumentNumber : .exactDocumentNumber
            let label = preModern
                ? ConfidenceLabels.superimposedDocumentNumber
                : ConfidenceLabels.exactMatch
            return CitationMatch(
                documentId: hit.documentId,
                volumeId: volumeId,
                rank: rank,
                matchStrategy: strategy,
                confidenceLabel: label
            )
        }
        return nil
    }

    // MARK: - Page Range Match

    private func matchByPageRange(
        volumeId: String,
        volumeEntry: VolumeManifestEntry,
        pageNumber: Int,
        rank: Int
    ) async throws -> CitationMatch? {
        guard let store = pageRangeStore else { return nil }

        guard let documentId = try await store.document(forPage: pageNumber, inVolume: volumeId) else {
            return nil
        }

        // Fetch page range for display in the confidence label
        let range = try await store.pageRange(forDocument: documentId, inVolume: volumeId)
        let label: String
        if let range {
            label = ConfidenceLabels.pageRange(page: pageNumber, first: range.first, last: range.last)
        } else {
            label = ConfidenceLabels.pageRangeShort(page: pageNumber)
        }

        return CitationMatch(
            documentId: documentId,
            volumeId: volumeId,
            rank: rank,
            matchStrategy: .pageRange,
            confidenceLabel: label
        )
    }

    // MARK: - Fuzzy Document Number Match

    private func matchByFuzzyDocumentNumber(
        volumeId: String,
        volumeEntry: VolumeManifestEntry,
        documentNumber: Int,
        rank: Int
    ) async throws -> CitationMatch? {
        guard let service = searchService else { return nil }

        let maxDoc = volumeEntry.documentCount
        guard maxDoc > 0 else { return nil }

        // Find the nearest valid document number
        let nearest: Int
        if documentNumber > maxDoc {
            nearest = maxDoc
        } else if documentNumber < 1 {
            nearest = 1
        } else {
            return nil // should be found by exactDocumentNumber; something went wrong
        }

        var params = SearchParameters()
        params.keywords = "\(nearest)"
        params.volumeIds = [volumeId]
        let results = try await service.search(parameters: params)
        guard let hit = results.first(where: { $0.documentNumber == "\(nearest)" }) else {
            return nil
        }

        let note = ConfidenceLabels.fuzzyDocumentNote(requested: documentNumber, nearest: nearest, max: maxDoc)
        return CitationMatch(
            documentId: hit.documentId,
            volumeId: volumeId,
            rank: rank,
            matchStrategy: .fuzzyDocumentNumber(nearest: nearest),
            confidenceLabel: ConfidenceLabels.fuzzyDocument(requested: documentNumber, nearest: nearest),
            correctionNote: note
        )
    }

    // MARK: - Era Detection

    /// Returns `true` for volumes from subseries before the 1955–57 era.
    ///
    /// Pre-modern volumes use editorially superimposed document numbers, not native
    /// document numbers from the original publication.
    func isPreModernVolume(_ entry: VolumeManifestEntry) -> Bool {
        // Parse the start year from the subseries string
        let sub = entry.subseries
        guard let firstYear = sub.components(separatedBy: .init(charactersIn: "-–")).first,
              let year = Int(firstYear) else { return false }
        return year < 1955
    }

    /// Returns `true` for microfiche supplement volumes.
    ///
    /// Microfiche supplements are identified by `"micro"` or `"Microfiche"` in the volumeId
    /// or title. Page range lookup is skipped for these — `<pb>` elements are absent or
    /// not meaningful in supplement volumes.
    func isMicroficheSupplement(_ entry: VolumeManifestEntry) -> Bool {
        return entry.volumeId.lowercased().contains("micro")
            || entry.title.lowercased().contains("microfiche")
            || entry.title.lowercased().contains("supplement")
    }

    // MARK: - Private Helpers

    private func normalizeSubseries(_ s: String) -> String {
        // Unify en dashes and hyphens; collapse "1969-1976" → "1969-76"
        var normalized = s.replacingOccurrences(of: "–", with: "-")
        let parts = normalized.components(separatedBy: "-")
        if parts.count == 2, parts[0].count == 4, parts[1].count == 4 {
            normalized = "\(parts[0])-\(parts[1].suffix(2))"
        }
        return normalized
    }

    private func volumeMatchesEntry(_ volumeNumber: String, entry: VolumeManifestEntry) -> Bool {
        let volUpper = volumeNumber.uppercased()
        // Check volumeId suffix pattern: "v01", "v02", etc.
        if let roman = romanToArabic(volUpper) {
            let padded = String(format: "%02d", roman)
            if entry.volumeId.hasSuffix("v\(padded)") { return true }
        }
        // Check title contains "Volume I" or "Vol. I"
        let titleLower = entry.title.lowercased()
        let volPatterns = ["volume \(volUpper.lowercased())", "vol. \(volUpper.lowercased())", "vol \(volUpper.lowercased())"]
        return volPatterns.contains { titleLower.contains($0) }
    }

    private func romanToArabic(_ roman: String) -> Int? {
        let map: [Character: Int] = ["I":1,"V":5,"X":10,"L":50,"C":100,"D":500,"M":1000]
        var result = 0
        var prev = 0
        for ch in roman.reversed() {
            guard let val = map[ch] else { return nil }
            if val < prev { result -= val } else { result += val }
            prev = val
        }
        return result > 0 ? result : nil
    }
}

// MARK: - ConfidenceLabels

/// All confidence label and correction note strings for citation matches.
///
/// Centralizing these here ensures they can be tested in isolation and
/// that no inline literal strings escape to the view layer.
enum ConfidenceLabels {

    static let exactMatch = String(
        localized: "citation.match.exact",
        defaultValue: "Exact match"
    )

    static let superimposedDocumentNumber = String(
        localized: "citation.match.superimposed",
        defaultValue: "Match — document number assigned digitally"
    )

    static let manifestOnly = String(
        localized: "citation.match.manifestOnly",
        defaultValue: "Volume identified — download to find the specific document"
    )

    static func pageRange(page: Int, first: Int, last: Int) -> String {
        String(
            localized: "citation.match.pageRange",
            defaultValue: "Matched by page number — page \(page) falls within this document (pages \(first)–\(last))"
        )
    }

    static func pageRangeShort(page: Int) -> String {
        String(
            localized: "citation.match.pageRangeShort",
            defaultValue: "Matched by page number — page \(page)"
        )
    }

    static func fuzzyDocument(requested: Int, nearest: Int) -> String {
        String(
            localized: "citation.match.fuzzy",
            defaultValue: "Possible match — document \(requested) not found; nearest is document \(nearest)"
        )
    }

    static func fuzzyDocumentNote(requested: Int, nearest: Int, max: Int) -> String {
        String(
            localized: "citation.match.fuzzyNote",
            defaultValue: "Document \(requested) was not found in this volume (last document is \(max)); the nearest available document is \(nearest)."
        )
    }

    static func bestGuess(_ explanation: String) -> String {
        String(
            localized: "citation.match.bestGuess",
            defaultValue: "Best guess — \(explanation)"
        )
    }
}
