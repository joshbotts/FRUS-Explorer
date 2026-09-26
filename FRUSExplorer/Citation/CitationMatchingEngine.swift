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
/// ## Every cited field, or a best guess (#1474)
/// Each narrowing step (subseries, volume, part) falls back to the unnarrowed set when no volume
/// meets it, so a lookup still returns something for a citation with a typo in it. A result from
/// such a volume is labelled **Best guess**, naming the field it does not meet, rather than
/// "Exact match": before #1474 a document found by number in a volume the citation did not name
/// was reported as exact.
///
/// ## Log prefix
/// `[CitationMatcher]`
///
/// Version history:
///   1.0 — Session 30: initial implementation
///   1.1 — Authoring Phase 3 review: `noteVolumeDownloaded(_:)` — the downloaded-volume
///          set was a boot-time snapshot, so the advertised "download, then re-resolve"
///          loop could not succeed until the next app relaunch
///   1.2 — #1474: a cited part narrows the volume; a volume numeral matches as a whole word and
///          in Arabic (`II` no longer admits Volume III, `V` no longer admits VI–VIII); a
///          history.state.gov link resolves to exactly the volume and document it names; and a
///          result from a volume that fails a cited field is a best guess, never an exact match
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

        // A history.state.gov link names its volume and document exactly (#1474).
        if let reference = input.exactReference {
            return try await match(reference: reference, pageNumber: input.pageNumber)
        }

        let candidates = await resolveVolume(
            subseries: input.subseries,
            volumeNumber: input.volumeNumber,
            partNumber: input.partNumber,
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
            // The cited fields this volume does not meet — non-empty only when a narrowing step
            // found no volume that met them and fell back (#1474).
            let unmet = unmetFields(of: input, in: volumeEntry)

            if !downloaded {
                // Stage 1: manifest-only result
                results.append(qualified(CitationMatch(
                    documentId: "",
                    volumeId: volumeId,
                    rank: rank,
                    matchStrategy: .manifestOnly,
                    confidenceLabel: ConfidenceLabels.manifestOnly,
                    requiresDownload: true,
                    volumeManifestEntry: volumeEntry
                ), unmet: unmet))
                rank += 1
                continue
            }

            let preModern = isPreModernVolume(volumeEntry)
            let microfiche = isMicroficheSupplement(volumeEntry)

            // Strategy 1 / 3: Document number match
            if let docNum = input.documentNumber {
                if let found = try await matchByDocumentNumber(
                    volumeId: volumeId, volumeEntry: volumeEntry,
                    documentNumber: docNum,
                    rank: rank, preModern: preModern
                ) {
                    let match = qualified(found, unmet: unmet)
                    results.append(match)
                    rank += 1
                    // Stop only at a hit in a volume that meets every cited field: a best guess
                    // must not hide the cited volume's own answer behind it.
                    if match.matchStrategy == .exactDocumentNumber { break }
                }
            }

            // Strategy 2: Page range match (skip for microfiche)
            if let pageNum = input.pageNumber, !microfiche {
                if let match = try await matchByPageRange(
                    volumeId: volumeId, volumeEntry: volumeEntry,
                    pageNumber: pageNum, rank: rank
                ) {
                    results.append(qualified(match, unmet: unmet))
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
                    results.append(qualified(fuzzy, unmet: unmetFields(of: input, in: volumeEntry)))
                }
            }
        }

        return results.sorted { $0.rank < $1.rank }
    }

    // MARK: - Exact Reference (#1474)

    /// Resolves a history.state.gov link: the volume it names, and the document or page in it.
    ///
    /// No volume is searched for. The link's volume id is looked up in the manifest as written,
    /// then case-insensitively (a retyped link may lower-case `frus1919Parisv01`), and an id the
    /// manifest does not have yields nothing — never a sibling volume that fits the other fields,
    /// which is how a prose citation of the E-volume `frus1969-76ve05p1` would otherwise land
    /// on Volume I. A link to a document the index does not hold yields nothing either.
    private func match(reference: CitationExactReference, pageNumber: Int?) async throws -> [CitationMatch] {
        let volumes = await manifestStore.bundledEntries
        guard let entry = volumes.first(where: { $0.volumeId == reference.volumeId })
                ?? volumes.first(where: {
                    $0.volumeId.caseInsensitiveCompare(reference.volumeId) == .orderedSame
                })
        else {
            #if DEBUG
            print("[CitationMatcher] link names \(reference.volumeId), which the manifest does not have")
            #endif
            return []
        }

        guard downloadedVolumeIds.contains(entry.volumeId) else {
            return [CitationMatch(
                documentId: "",
                volumeId: entry.volumeId,
                rank: 1,
                matchStrategy: .manifestOnly,
                confidenceLabel: ConfidenceLabels.manifestOnly,
                requiresDownload: true,
                volumeManifestEntry: entry
            )]
        }

        if let documentId = reference.documentId {
            guard let hit = try await searchService?.document(withId: documentId, inVolume: entry.volumeId) else {
                #if DEBUG
                print("[CitationMatcher] link names \(entry.volumeId)/\(documentId), which the index does not hold")
                #endif
                return []
            }
            return [CitationMatch(
                documentId: hit.documentId,
                volumeId: entry.volumeId,
                rank: 1,
                matchStrategy: .exactDocumentNumber,
                confidenceLabel: ConfidenceLabels.exactMatch
            )]
        }

        // A page link; a link to the volume or one of its sections names no document.
        if let page = pageNumber,
           let hit = try await matchByPageRange(volumeId: entry.volumeId, volumeEntry: entry,
                                                pageNumber: page, rank: 1) {
            return [hit]
        }
        return []
    }

    // MARK: - Cited Fields (#1474)

    /// A field a citation names, carried with the value it names so a label can quote it.
    enum CitedField: Equatable, Sendable {
        /// The chronological subseries, e.g. `"1961-63"`.
        case subseries(String)
        /// The volume numeral as cited, e.g. `"XIV"`.
        case volume(String)
        /// The part of a multi-part volume.
        case part(Int)
    }

    /// The fields `input` names that `entry` does not meet. A cited year range is met by any year
    /// the volume carries — its subseries, a range its title prints, or its print year — because a
    /// citation may name any of them (`subseriesMatches`).
    private func unmetFields(of input: CitationInput, in entry: VolumeManifestEntry) -> [CitedField] {
        var unmet: [CitedField] = []
        if let subseries = input.subseries, !subseriesMatches(subseries, entry: entry) {
            unmet.append(.subseries(subseries))
        }
        if let volume = input.volumeNumber, !volumeMatchesEntry(volume, entry: entry) {
            unmet.append(.volume(volume))
        }
        if let part = input.partNumber, !partMatchesEntry(part, entry: entry) {
            unmet.append(.part(part))
        }
        return unmet
    }

    /// `match` as it may be reported for a volume that does not meet `unmet`.
    ///
    /// A document found in such a volume becomes a best guess naming what it fails; a volume-only
    /// row keeps `.manifestOnly`, since it names no document to guess at, and takes the same
    /// warning as its label. Unchanged when `unmet` is empty.
    private func qualified(_ match: CitationMatch, unmet: [CitedField]) -> CitationMatch {
        guard !unmet.isEmpty else { return match }
        let explanation = ConfidenceLabels.unmetFields(unmet.map(ConfidenceLabels.cited))
        #if DEBUG
        print("[CitationMatcher] \(match.volumeId) does not meet the cited \(unmet) — best guess")
        #endif
        return CitationMatch(
            documentId: match.documentId,
            volumeId: match.volumeId,
            rank: match.rank,
            matchStrategy: match.requiresDownload ? match.matchStrategy : .bestGuess(explanation: explanation),
            confidenceLabel: ConfidenceLabels.bestGuess(explanation),
            correctionNote: ConfidenceLabels.unmetFieldsNote,
            requiresDownload: match.requiresDownload,
            volumeManifestEntry: match.volumeManifestEntry
        )
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
    ///
    /// A cited part (#1474) narrows after the volume number, by the part the volume id carries.
    func resolveVolume(
        subseries: String?,
        volumeNumber: String?,
        partNumber: Int? = nil,
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

        // Narrows a set by the parsed volume number, then by the part; each step is a no-op when
        // nothing matches, so it never empties an otherwise-good candidate list. A volume kept by
        // that fallback fails the field, and `unmetFields` reports it as a best guess (#1474).
        func applyVolumeAndPart(_ set: [VolumeManifestEntry]) -> [VolumeManifestEntry] {
            var narrowed = set
            if let vol = volumeNumber {
                let filtered = narrowed.filter { volumeMatchesEntry(vol, entry: $0) }
                if !filtered.isEmpty { narrowed = filtered }
            }
            if let part = partNumber {
                let filtered = narrowed.filter { partMatchesEntry(part, entry: $0) }
                if !filtered.isEmpty { narrowed = filtered }
            }
            return narrowed
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
                        return applyVolumeAndPart(inSubseries.isEmpty ? fullMatches : inSubseries)
                    }
                }
                // Otherwise (short fragment, or no full match) apply the explicit volume number
                // FIRST — it stays authoritative — then narrow that set by token overlap, keeping
                // only the best-scoring volumes. This preserves the historic "narrow by a
                // distinctive title word" behavior (e.g. "Vietnam") and ranks multi-token fragments
                // for `match()`'s prefix(3), without letting a title word override an explicit
                // volume number.
                let byVolume = applyVolumeAndPart(subseriesCandidates)
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

        return applyVolumeAndPart(subseriesCandidates)
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

        // Deterministic document_cache lookup by canonical printed number. The previous
        // implementation ran a full-text search for the bare number and filtered the
        // hits — but a number like "15" matches every document mentioning it (dates,
        // telegram numbers, page references), and with results BM25-ranked and capped
        // at a page, the actual Document 15 row was starved out of the result set in
        // any realistically-sized volume, so valid citations resolved to nothing.
        if let hit = try await service.document(byNumber: "\(documentNumber)",
                                                inVolume: volumeId) {
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

        // Same deterministic lookup as the exact strategy (see matchByDocumentNumber) —
        // the nearest number is a specific document, not a keyword.
        guard let hit = try await service.document(byNumber: "\(nearest)",
                                                   inVolume: volumeId) else {
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

    /// Whether `entry` is the cited volume. A numeral, Roman or Arabic, is the volume number the id
    /// carries (`v02`, `v02p1`); anything else — an E-volume typed as "E-5" — must be named whole
    /// after "Volume" in the title.
    ///
    /// Before #1474 the title test was a substring test, so "volume ii" also matched "Volume III"
    /// and "volume v" matched VI–VIII; only an id ENDING in `vNN` counted, which missed every part
    /// volume; and an Arabic numeral typed in Structured Entry matched nothing. The id is enough for
    /// a numeral: of the 553 bundled volumes, all 432 whose title prints "Volume <numeral>" carry the
    /// same number in their id. Over those 432 the old test admitted a different-numeral volume of
    /// the same subseries for 171 and failed to match 12 to their own numeral; this one does neither.
    private func volumeMatchesEntry(_ volumeNumber: String, entry: VolumeManifestEntry) -> Bool {
        if let value = CitationNumerals.value(of: volumeNumber) {
            return CitationNumerals.volumeNumber(inVolumeId: entry.volumeId) == value
        }
        let dashFolded = volumeNumber.replacingOccurrences(of: "–", with: "-")
            .trimmingCharacters(in: .whitespaces)
        return titleNames(volume: dashFolded, in: entry.title.replacingOccurrences(of: "–", with: "-"))
    }

    /// Whether `entry` is the cited part: the part its id carries (`v02p1`, `frus1863p2`).
    ///
    /// The id alone decides, and does not need the title: every one of the 98 part volumes in the
    /// bundled manifest carries its part in the id, and its title's "Part N" agrees with it.
    private func partMatchesEntry(_ part: Int, entry: VolumeManifestEntry) -> Bool {
        CitationNumerals.partNumber(inVolumeId: entry.volumeId) == part
    }

    /// Whether `title` names `volume` whole right after "Volume" or "Vol." — the manifest titles
    /// break lines anywhere, so "Volume\n    E-5" counts as "Volume E-5", and "E-15" does not.
    private func titleNames(volume: String, in title: String) -> Bool {
        let pattern = #"\bvol(?:ume)?\.?\s+"# + NSRegularExpression.escapedPattern(for: volume)
            + #"(?![A-Za-z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        return regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) != nil
    }

    /// Whether the cited year range is one this volume carries: its subseries, a year or range its
    /// title prints, or the year it was printed (#1474).
    ///
    /// All three are what a citation of the volume may name. A pre-1906 volume's citation carries
    /// only its PRINT year (`frus1863p2` is cited as 1864, #216), and a volume whose title prints
    /// narrower dates than its subseries is cited by them (`frus1941-43` as "1941–1942"). The app's
    /// own citations of every bundled volume, in all three formats, are pinned by
    /// `ownCitationsAreNeverBestGuesses`.
    private func subseriesMatches(_ cited: String, entry: VolumeManifestEntry) -> Bool {
        let wanted = normalizeSubseries(cited)
        if normalizeSubseries(entry.subseries) == wanted { return true }
        if let printed = FRUSVolumeMetadata.firstYear(in: entry.publicationDate), String(printed) == wanted {
            return true
        }
        let pattern = #"(1[789]\d{2})(?:\s*[–\-]\s*(\d{4}|\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let title = entry.title
        return regex.matches(in: title, range: NSRange(title.startIndex..., in: title)).contains { match in
            guard let start = Range(match.range(at: 1), in: title) else { return false }
            let end = Range(match.range(at: 2), in: title).map { "-" + title[$0] } ?? ""
            return normalizeSubseries(String(title[start]) + end) == wanted
        }
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

    /// One cited field as a best-guess label quotes it: "volume XX", "part 2", "subseries 1999-00".
    static func cited(_ field: CitationMatchingEngine.CitedField) -> String {
        switch field {
        case .subseries(let subseries):
            return String(localized: "citation.match.cited.subseries",
                          defaultValue: "subseries \(subseries)")
        case .volume(let volume):
            return String(localized: "citation.match.cited.volume",
                          defaultValue: "volume \(volume)")
        case .part(let part):
            return String(localized: "citation.match.cited.part",
                          defaultValue: "part \(part)")
        }
    }

    /// The explanation a best guess carries when its volume does not meet a cited field (#1474),
    /// e.g. "no volume matches the cited volume XX and part 2".
    static func unmetFields(_ cited: [String]) -> String {
        let fields = cited.formatted(.list(type: .and))
        return String(localized: "citation.match.unmetFields",
                      defaultValue: "no volume matches the cited \(fields)")
    }

    /// The note under such a best guess (#1474).
    static let unmetFieldsNote = String(
        localized: "citation.match.unmetFieldsNote",
        defaultValue: "This result comes from a volume the citation does not name, so it may not be the document cited. Check the citation before relying on it."
    )
}
