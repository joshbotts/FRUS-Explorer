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
/// | 2 | `pageRange` | Vol resolved, page number present, one document begins on the page (or, none beginning there, is printed on it) |
/// | 2 | `sharedPage` | The same, but the page names several documents: listed, none vouched for (#1503) |
/// | 3 | `superimposedDocumentNumber` | Pre-1955–57, vol resolved, doc number present |
/// | 4 | `fuzzyDocumentNumber` | Doc number not found; nearest ±N surfaced |
/// | 5 | `titleFragmentMatch` | Vol number ambiguous; title text narrows candidates |
/// | 6 | `manifestOnly` | Vol identified but not in local corpus; or a link's downloaded volume, holding no document the citation names |
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
/// meets it, so a lookup still returns something for a citation with a typo in it; and a long
/// title fragment can move the lookup to a volume the title names outright (#216). Every result
/// is then checked against the fields the citation names, and one from a volume that does not
/// carry them is labelled **Best guess**, naming the field, rather than "Exact match": before
/// #1474 a document found by number in a volume the citation did not name was reported as exact.
/// A cited year is carried by the volume's subseries, by a year or range its title prints, or by
/// the year it was printed (`subseriesMatches`), so a fallback can keep a volume that carries it
/// and whose results keep their plain label. The text beside a history.state.gov link, whose
/// volume the link has chosen, is checked against that volume for its volume number and part,
/// and for its year only when it names the series with the year after it (`FRUS, 1961–1963`,
/// `CitationVolumeFields.subseriesReading`). A document found by number is also checked against a
/// cited page: when the pages it may be printed on do not include it, it is a best guess too.
/// That check reads the page a document begins on (`PageRangeStore.printedPages`, #1503), so it
/// places a document with no page break of its own exactly. It stays silent in the five
/// microfiche supplements (`isMicroficheSupplement`), whose page breaks are not printed pages.
/// Outside them, over the 311,245 document divs of the other 548 volumes at corpus `550a8c5c5`,
/// it is silent for 527 documents nothing places — 1,495 before #1503, when a document with no
/// break of its own was bounded by the breaks on either side of it:
/// - 100 in `frus1977-80v27` with no page break before them at all;
/// - 78 that begin on a page whose number is not arabic, 62 of them on `frus1863p1`'s
///   roman-numbered pages;
/// - 349 in the volumes that number their pages per document, with no page break of their own
///   and a start that is the page the document before them ended on, in its numbering (#1503
///   review round 1: #1503 as first written placed them on that page, `frus1969-76ve05p1`'s d239
///   on d238's page 2).
///
/// ## Page-only citations (#1503)
/// A citation by volume and page alone finds the document that BEGINS on the page — the page a
/// citation names — or, when none does, the document printed on it. When several begin on it
/// (short documents), or several are printed on it (breaks out of order), it lists them all, up to
/// `sharedPageListLimit`, as `sharedPage` results that nothing treats as confident. In a volume
/// that numbers its pages per document (`PageSpanResolver.numbersPagesPerDocument`) a page number
/// names no document, so it lists every document printed on a page of that number as `sharedPage`
/// results, even when only one is (#1503 review round 1). Over the 533 printed volumes at
/// `550a8c5c5`, measured over the rows the index holds, of the 306,463 documents whose recorded
/// start places them a citation of that page now finds the document alone for 185,470 and among
/// others that begin there for 120,993; before #1503 it found the document before it for 156,625,
/// an earlier document or a promoted prose section for 32,293, nothing for 117,503, one of several,
/// whichever a Swift Dictionary reached first, for 40, and the document itself for 2.
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
///   1.3 — #1474 review round 1: a link that names no document the index holds — the volume, a
///          section, an id the volume lacks — looks up the document or page printed beside it in
///          the linked volume, and otherwise answers with the volume, where it answered nothing;
///          a link's document id is looked up as written, then ignoring case; a document found by
///          number whose pages do not include the cited page is a best guess; and a best guess
///          keeps the note or label of the strategy that found it
///   1.4 — #1474 review round 2: the page check reaches a document with no page break of its own
///          (a third of the corpus's documents, which 1.3 never checked), and its label shows the
///          pages the check accepts; and a document a link's fallback finds through the prose
///          beside it is a best guess when that prose names a volume the link's does not match
///   1.5 — #1474 review round 3: the page strategy and the page check skip the five microfiche
///          supplements and nothing else — the nine printed 1914–1918 World War supplements are
///          looked up and checked by page, and `frus1961-63v07-09mSupp`, whose title does not say
///          "microfiche", no longer is
///   1.6 — #1474 review rounds 4 and 5: the text beside a link is checked against the linked
///          volume for its year only when the year follows the series' name
///          (`CitationVolumeFields.subseriesReading`), so a note that opens with its document's
///          date and names the series only in its link is an exact match, and `FRUS, 1961–1963,
///          vol. XXIII` beside a link to Volume XXIII of 1964–68 is still a best guess. (Round 4
///          met any year inside the years the linked volume covers instead, which made that
///          second citation an exact match; round 5 replaced it before it landed.)
///   1.7 — #1503: a page-only citation finds the document that begins on the page, and every
///          document when several do (`sharedPage`, never vouched for); the page check reads the
///          page a document begins on (`PageRangeStore.printedPages`)
///   1.8 — #1503 review round 1: in a volume numbering its pages per document every page-only
///          answer is `sharedPage`, one document or many; a document already listed by its number
///          is not listed again by the page; a best guess keeps the count of a page's documents
///          (`CitationMatch.sharedPageTotal`)
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

        // A history.state.gov link names its volume, and often its document, exactly (#1474).
        if let reference = input.exactReference {
            return try await match(reference: reference, input: input)
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
            // The cited fields this volume does not carry (#1474) — which a candidate can fail when
            // a narrowing step found no volume that carried the field and fell back, or when a long
            // title fragment moved the lookup out of the cited subseries (`resolveVolume`).
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
                    // A page the citation also names must be one the document is printed on.
                    let miss = try await pageMiss(page: input.pageNumber, documentId: found.documentId,
                                                  in: volumeEntry)
                    let match = qualified(found, unmet: unmet, pageMiss: miss)
                    results.append(match)
                    rank += 1
                    // Stop only at a hit that meets every cited field: a best guess must not hide
                    // the cited volume's own answer, or the document on the cited page, behind it.
                    if match.matchStrategy == .exactDocumentNumber { break }
                }
            }

            // Strategy 2: Page range match (skip for microfiche) — every document the page names
            // (#1503), one of them unless several begin on it or the volume numbers its pages per
            // document, less any the document number already listed (review round 1).
            if let pageNum = input.pageNumber, !microfiche {
                let listed = Set(results.filter { $0.volumeId == volumeId }.map(\.documentId))
                for match in try await matchByPageRange(
                    volumeId: volumeId, volumeEntry: volumeEntry,
                    pageNumber: pageNum, rank: rank, listed: listed
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
    /// on Volume I.
    ///
    /// In a downloaded volume the link's segment is looked up as a document id first, as written
    /// and then ignoring case (`SearchService.document(withId:inVolume:)`). When the index holds no
    /// such document — the link names the volume itself, a section (`ch3`), or an id the volume
    /// lacks — the citation's document number and page decide instead, in the linked volume
    /// alone: `FRUS, 1961–1963, vol. V, doc. 84, https://…/frus1961-63v05` is document 84. When
    /// those find nothing either, the answer is the volume, labelled as such, rather than nothing:
    /// the link does name it.
    ///
    /// Two limits on that fallback (#1474 review round 2). A document it finds is the prose's
    /// choice, so it is checked against the subseries, volume and part the prose names
    /// (`reference.prose`) and is a best guess when the linked volume does not carry one:
    /// `vol. XIV, doc. 84, …/frus1961-63v05` is Volume V's document 84, not an exact match. The
    /// prose's year is checked only when the parser read it after the series' name
    /// (`CitationVolumeFields.subseriesReading`, #1474 review round 5), and then strictly, by
    /// `subseriesMatches`: `FRUS, 1961–1963, vol. XXIII, doc. 5, …/frus1964-68v23` names Volume
    /// XXIII of 1961–63, Southeast Asia, and the link's Congo volume of 1964–68 is a best guess
    /// even though its title prints 1960–1968. A year the parser read as the text's first — the
    /// text names no series, the link being its only "frus", or names it with no year after it —
    /// is not checked at all. It is the date the note opens with, which names no volume:
    /// `National Intelligence Estimate, December 1, 1960, vol. V, doc. 1, …/frus1961-63v05` is
    /// Volume V's document 1, dated 1960, and an exact match. Round 3 checked that date and
    /// reported a best guess whose text "names a different one"; round 4 met a year inside the
    /// years the volume covers, which took the Southeast Asia citation to an exact match on the
    /// Congo volume. And for a numbered `d` id the volume lacks (`d999`), the document number is
    /// the id's own and is looked up as a PRINTED number — which could reach a different document
    /// only in a volume where some document prints a number whose `d` id is another's. Over the
    /// corpus at `550a8c5c5` no document does (0 of 314,571; every numbered `d` id's `@n` is its
    /// own number): that is a property of the corpus, not a guard here.
    private func match(reference: CitationExactReference, input: CitationInput) async throws -> [CitationMatch] {
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
            if let hit = try await searchService?.document(withId: documentId, inVolume: entry.volumeId) {
                return [CitationMatch(
                    documentId: hit.documentId,
                    volumeId: entry.volumeId,
                    rank: 1,
                    matchStrategy: .exactDocumentNumber,
                    confidenceLabel: ConfidenceLabels.exactMatch
                )]
            }
            #if DEBUG
            print("[CitationMatcher] link names \(entry.volumeId)/\(documentId), which the index does not hold — trying the cited document and page")
            #endif
        }

        // No document the index holds: the document number, then the page, in this volume alone —
        // each the prose's choice, so each is checked against the volume fields the prose names:
        // its volume and part, and its year only when that year followed the series' name — a
        // year read as the text's first is the document's date (#1474 review round 5).
        let proseUnmet: [CitedField] = reference.prose.map { prose in
            let seriesYear = prose.subseriesReading == .afterSeriesName ? prose.subseries : nil
            return unmetFields(of: CitationInput(subseries: seriesYear, volumeNumber: prose.volumeNumber,
                                                 partNumber: prose.partNumber), in: entry)
        } ?? []
        var results: [CitationMatch] = []
        if let number = input.documentNumber,
           let found = try await matchByDocumentNumber(volumeId: entry.volumeId, volumeEntry: entry,
                                                       documentNumber: number, rank: 1,
                                                       preModern: isPreModernVolume(entry)) {
            let miss = try await pageMiss(page: input.pageNumber, documentId: found.documentId, in: entry)
            results.append(qualified(found, unmet: proseUnmet, pageMiss: miss,
                                     unmetNote: ConfidenceLabels.linkProseNote))
            if miss == nil { return results }
        }
        if let page = input.pageNumber, !isMicroficheSupplement(entry) {
            for hit in try await matchByPageRange(volumeId: entry.volumeId, volumeEntry: entry,
                                                  pageNumber: page, rank: results.count + 1,
                                                  listed: Set(results.map(\.documentId))) {
                results.append(qualified(hit, unmet: proseUnmet, unmetNote: ConfidenceLabels.linkProseNote))
            }
        }
        if !results.isEmpty { return results }

        return [CitationMatch(
            documentId: "",
            volumeId: entry.volumeId,
            rank: 1,
            matchStrategy: .manifestOnly,
            confidenceLabel: ConfidenceLabels.linkVolumeOnly,
            volumeManifestEntry: entry
        )]
    }

    // MARK: - Cited Page (#1474 review round 1)

    /// A cited page that the document found for a citation is not printed on.
    struct PageMiss: Equatable, Sendable {
        /// The page the citation names.
        let page: Int
        /// The first page the document may be printed on (`PageRangeStore.printedPages`).
        let first: Int
        /// The last page the document may be printed on.
        let last: Int
    }

    /// The cited `page`, when the document `documentId` of `entry` is known not to be printed on it;
    /// `nil` when no page is cited, the volume is one of the five microfiche supplements
    /// (`isMicroficheSupplement` — whose page breaks are not printed pages; the 1914–1918 World
    /// War supplements are printed volumes and are checked), or the index cannot tell which pages
    /// the document is on.
    ///
    /// The pages are `PageRangeStore.printedPages(forDocument:inVolume:)`: from the page the
    /// document begins on — the commonest page to cite, which must not demote it — through its last
    /// page break, so one with no break of its own, a third of the corpus's documents, is printed
    /// on the one page it begins on (#1503). Until #1503 the index held no record of that page, and
    /// the check used the page before a document's first break, or for one with no break the pages
    /// between the breaks recorded on either side of it (#1474 review round 2); without a recorded
    /// start that places the document it still does the first.
    private func pageMiss(page: Int?, documentId: String,
                          in entry: VolumeManifestEntry) async throws -> PageMiss? {
        guard let page, !isMicroficheSupplement(entry), let store = pageRangeStore,
              let pages = try await store.printedPages(forDocument: documentId, inVolume: entry.volumeId)
        else { return nil }
        guard !pages.contains(page) else { return nil }
        #if DEBUG
        print("[CitationMatcher] \(entry.volumeId)/\(documentId) may be printed on pp. \(pages.lowerBound)–\(pages.upperBound), not the cited p. \(page) — best guess")
        #endif
        return PageMiss(page: page, first: pages.lowerBound, last: pages.upperBound)
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

    /// `match` as it may be reported for a volume that does not carry `unmet`, or for a document
    /// whose pages do not include the cited one (`pageMiss`).
    ///
    /// A document found that way becomes a best guess naming what it fails; a volume-only row
    /// keeps `.manifestOnly`, since it names no document to guess at, and takes the same warning
    /// as its label. The note keeps what the match itself said when it was more than a hit on the
    /// cited number — its own note (the nearest-document substitution), or its label (a match by
    /// page, a digitally assigned number), or both (a page several documents share, #1503, whose
    /// label counts them and whose note says a page cannot choose) — so the best guess does not
    /// hide how it was found. It keeps `sharedPageTotal`, the one thing its strategy no longer
    /// says (#1503 review round 1: Batch counted only the listed documents of a best guess's page).
    /// Unchanged when there is nothing to report.
    ///
    /// `unmetNote` is the note an unmet field adds: `unmetFieldsNote` by default, and
    /// `linkProseNote` for a document a link's fallback found through the prose beside it, whose
    /// volume the citation does name — in its link (#1474 review round 2).
    private func qualified(_ match: CitationMatch, unmet: [CitedField],
                           pageMiss: PageMiss? = nil,
                           unmetNote: String = ConfidenceLabels.unmetFieldsNote) -> CitationMatch {
        guard !unmet.isEmpty || pageMiss != nil else { return match }
        var reasons: [String] = []
        var notes: [String] = []
        if !unmet.isEmpty {
            reasons.append(ConfidenceLabels.unmetFields(unmet.map(ConfidenceLabels.cited)))
            notes.append(unmetNote)
        }
        if let pageMiss {
            reasons.append(ConfidenceLabels.pageOutside(page: pageMiss.page, first: pageMiss.first,
                                                        last: pageMiss.last))
            notes.append(ConfidenceLabels.pageOutsideNote)
        }
        if case .sharedPage = match.matchStrategy {
            // Both: the label says how many documents the page names, the note what to do (#1503).
            notes.append(match.confidenceLabel)
            if let own = match.correctionNote { notes.append(own) }
        } else if let own = match.correctionNote {
            notes.append(own)
        } else if match.matchStrategy == .pageRange || match.matchStrategy == .superimposedDocumentNumber {
            notes.append(match.confidenceLabel)
        }
        let explanation = reasons.formatted(.list(type: .and))
        #if DEBUG
        print("[CitationMatcher] \(match.volumeId)/\(match.documentId) does not meet the cited \(unmet), page miss \(pageMiss.map { "\($0.page)" } ?? "-") — best guess")
        #endif
        return CitationMatch(
            documentId: match.documentId,
            volumeId: match.volumeId,
            rank: match.rank,
            matchStrategy: match.requiresDownload ? match.matchStrategy : .bestGuess(explanation: explanation),
            confidenceLabel: ConfidenceLabels.bestGuess(explanation),
            correctionNote: notes.joined(separator: "\n"),
            requiresDownload: match.requiresDownload,
            volumeManifestEntry: match.volumeManifestEntry,
            sharedPageTotal: match.sharedPageTotal
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
        // that fallback fails the field, and `unmetFields` reports it as a best guess (#1474). The
        // subseries fallback above is looser: it keeps every volume, and `unmetFields` excuses one
        // whose title prints the cited year, or which was printed in it (`subseriesMatches`).
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

    /// How many of the documents a shared page names a page-only lookup lists (#1503), in source
    /// order; the label and the strategy carry how many there are.
    ///
    /// Ten covers every page of the 533 printed volumes at corpus `550a8c5c5`, where no page names
    /// more than ten documents (one names ten; three name nine); a volume that numbers its pages
    /// per document names more — up to 665 on `frus1969-76ve10`'s page 1 — and listing hundreds of
    /// rows for a citation that cannot choose between them helps no one.
    static let sharedPageListLimit = 10

    /// The documents page `pageNumber` of `volumeId` names (`PageRangeStore.documents(forPage:)`,
    /// #1503): one `.pageRange` match for the one document that begins on the page — or, when none
    /// does, the one printed on it — and otherwise the first `sharedPageListLimit` of them as
    /// `.sharedPage` matches, which nothing downstream treats as a confident answer. In a volume
    /// that numbers its pages per document every answer is `.sharedPage`, with a label and note of
    /// its own, even for the one document that carries the page number (#1503 review round 1).
    /// Ranked from `rank` in source order. Empty when the page names no document.
    ///
    /// `listed` holds the documents of this volume the lookup has already listed — by the cited
    /// document number — which are not listed again (#1503 review round 1: a pre-1955 citation of
    /// a document and the page it begins on listed it twice, and Batch counted three documents
    /// where there were two). The count every `.sharedPage` match carries still counts them.
    ///
    /// Before #1503 this was one document: the one owning the last page break at or before the
    /// page, which was the document before the one that begins there, or none, and in a volume
    /// numbering its pages per document whichever a Swift Dictionary reached first.
    private func matchByPageRange(
        volumeId: String,
        volumeEntry: VolumeManifestEntry,
        pageNumber: Int,
        rank: Int,
        listed: Set<String> = []
    ) async throws -> [CitationMatch] {
        guard let store = pageRangeStore,
              let claimants = try await store.documents(forPage: pageNumber, inVolume: volumeId)
        else { return [] }

        let begins = claimants.claim == .begins
        let unlisted = claimants.documents.filter { !listed.contains($0.documentId) }
        guard claimants.isAmbiguous else {
            guard let document = unlisted.first else { return [] }
            let pages = document.pages
            return [CitationMatch(
                documentId: document.documentId,
                volumeId: volumeId,
                rank: rank,
                matchStrategy: .pageRange,
                confidenceLabel: begins
                    ? ConfidenceLabels.pageBegins(page: pageNumber, first: pages.lowerBound, last: pages.upperBound)
                    : ConfidenceLabels.pageRange(page: pageNumber, first: pages.lowerBound, last: pages.upperBound)
            )]
        }

        let total = claimants.documents.count
        let label: String
        let note: String
        switch claimants.claim {
        case .numberedPerDocument:
            label = ConfidenceLabels.perDocumentPage(page: pageNumber, documents: total)
            note = ConfidenceLabels.perDocumentPageNote
        case .begins, .printed:
            label = ConfidenceLabels.sharedPage(page: pageNumber, documents: total, begin: begins)
            note = ConfidenceLabels.sharedPageNote
        }
        #if DEBUG
        print("[CitationMatcher] \(volumeId) p. \(pageNumber) names \(total) documents (\(claimants.claim)) — ambiguous")
        #endif
        return unlisted.prefix(Self.sharedPageListLimit).enumerated().map { offset, document in
            CitationMatch(
                documentId: document.documentId,
                volumeId: volumeId,
                rank: rank + offset,
                matchStrategy: .sharedPage(documents: total),
                confidenceLabel: label,
                correctionNote: note,
                sharedPageTotal: total
            )
        }
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

    /// Returns `true` for microfiche supplement volumes: an id carrying `mSupp`, in any case, or a
    /// title naming the microfiche.
    ///
    /// Neither the page strategy nor the page check runs in one. Their page breaks are not a
    /// printed volume's pages: the facsimile breaks restart with every document, the typeset
    /// breaks between them run on through the volume, and the index records both as arabic pages.
    /// In `frus1961-63v07-09mSupp`, until #1474 review round 3, several documents spanned 1,893 of
    /// the 1,897 page numbers a page-only citation could name.
    ///
    /// The bundled manifest has five such volumes, and the id and the title find all five:
    /// `frus1961-63v07-09mSupp`'s title does not name the microfiche, and its id is the only sign.
    /// Before round 3 the test was "supplement" anywhere in the title, or "micro" in the id. That
    /// skipped the nine printed 1914–1918 "Supplement, The World War" volumes, 9,118 documents on
    /// ordinary arabic pages, and missed `frus1961-63v07-09mSupp`. Measured over the local corpus
    /// at `550a8c5c5` (`measure_supplement_scope.py`, `measure_page_strategy.py`), the nine
    /// volumes behave like the rest of the corpus under both page rules:
    /// - The page check bounds 9,093 of their documents, and every one of them begins on a page
    ///   the check accepts.
    /// - A page-only citation finds a document printed on that page for 77.4% of their page
    ///   numbers and none for the rest, against 80.8% in the other volumes. None finds a
    ///   document that is not on the page, and no page is claimed by two documents. (Both were
    ///   measured under the page rule #1503 replaced, which answered a page with the document
    ///   running when it began and found none for a break between documents; under the rule that
    ///   replaced it every page a break carries names a document.)
    ///
    /// Fifteen other volumes number their pages per document too — fourteen of the 22 E-volumes
    /// and `frus1981-88v16` — but are not microfiche supplements, so both page rules run there,
    /// reading the volume as numbering its pages per document (`PageSpanResolver
    /// .numbersPagesPerDocument`, which finds exactly those fifteen). There a page-only citation
    /// names every document printed on that page number, and it is answered as such
    /// (`sharedPage`), never as one document — even the only one with a page of that number
    /// (#1503 review round 1; #1503 as first written answered with one document when one alone
    /// began on the page or was printed on it, 85 of their 520 page numbers). Before #1503 it was
    /// whichever document a Swift Dictionary reached first, labelled a match by page. A document
    /// number with the page names one document, and the page is checked against it — a document
    /// with no page break of its own only when its start is its own page 1.
    func isMicroficheSupplement(_ entry: VolumeManifestEntry) -> Bool {
        return entry.volumeId.lowercased().contains("msupp")
            || entry.title.lowercased().contains("microfiche")
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
    /// break lines anywhere, so "Volume\n    E-5" counts as "Volume E-5" — and names it WHOLE: a
    /// cited "E-1" is a prefix of "E-10" through "E-16", and without the closing lookahead it
    /// admitted eleven of those volumes beside E-1's own.
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

    /// The label on the one document printed on a cited page that no document begins on, having
    /// begun on an earlier one, e.g. "page 53 falls within this document (pages 51–54)" (#1503:
    /// the range is the pages it is printed on from the page it begins on, not its own page
    /// breaks). A document printed on the one page takes the one-page form — which only a document
    /// placed by its own single break can be, the index recording no page it begins on.
    static func pageRange(page: Int, first: Int, last: Int) -> String {
        guard first < last else {
            return String(localized: "citation.match.pageRangeOnePage",
                          defaultValue: "Matched by page number — this document is printed on page \(page)")
        }
        return String(
            localized: "citation.match.pageRange",
            defaultValue: "Matched by page number — page \(page) falls within this document (pages \(first)–\(last))"
        )
    }

    /// The label on the one document that begins on a cited page (#1503), e.g. "this document
    /// begins on page 49 (pages 49–50)", or, printed on that page alone, "begins on page 47 and
    /// ends on it".
    static func pageBegins(page: Int, first: Int, last: Int) -> String {
        guard first < last else {
            return String(localized: "citation.match.pageBeginsOnePage",
                          defaultValue: "Matched by page number — this document begins on page \(page) and ends on it")
        }
        return String(localized: "citation.match.pageBegins",
                      defaultValue: "Matched by page number — this document begins on page \(page) (pages \(first)–\(last))")
    }

    /// The label on each of the documents a cited page names when it names several (#1503):
    /// several `begin` on it, or — none beginning there — several are printed on it, as in a
    /// volume numbering its pages per document. `documents` is how many, counting any the lookup
    /// does not list (`CitationMatchingEngine.sharedPageListLimit`).
    static func sharedPage(page: Int, documents: Int, begin: Bool) -> String {
        // "N documents", grouped (#1374): a volume numbering its pages per document can print one
        // page number in hundreds.
        let counted = CountCopy.documents(documents)
        return begin
            ? String(localized: "citation.match.sharedPageBegins",
                     defaultValue: "Possible match — one of \(counted) that begin on page \(page)")
            : String(localized: "citation.match.sharedPagePrinted",
                     defaultValue: "Possible match — one of \(counted) printed on page \(page)")
    }

    /// The note under each of those documents (#1503).
    static let sharedPageNote = String(
        localized: "citation.match.sharedPageNote",
        defaultValue: "A page alone cannot say which of the documents printed on it the citation means. Add the document number to the citation, or compare these documents with the citation."
    )

    /// The label on each document a cited page names in a volume that numbers its pages afresh in
    /// every document (#1503 review round 1), where every answer is a possible match: "one of 12
    /// documents printed on page 2", as for any page several documents are printed on, or — when
    /// one document alone has a page of that number — "page 57 is printed only in this document".
    static func perDocumentPage(page: Int, documents: Int) -> String {
        guard documents == 1 else { return sharedPage(page: page, documents: documents, begin: false) }
        return String(localized: "citation.match.perDocumentPageOne",
                      defaultValue: "Possible match — page \(page) is printed only in this document")
    }

    /// The note under each of those documents (#1503 review round 1).
    static let perDocumentPageNote = String(
        localized: "citation.match.perDocumentPageNote",
        defaultValue: "This volume numbers its pages afresh in every document, so a page number alone does not say which document the citation means. Add the document number to the citation."
    )

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

    /// The explanation a best guess carries when its volume does not carry a cited field (#1474),
    /// e.g. "this volume does not match the cited volume XX and part 2".
    ///
    /// It states what is true of the result rather than why the lookup reached it: usually no
    /// volume carried the field and the lookup looked beyond it, but a long title fragment can
    /// also move it out of a cited subseries that other volumes do carry.
    static func unmetFields(_ cited: [String]) -> String {
        let fields = cited.formatted(.list(type: .and))
        return String(localized: "citation.match.unmetFields",
                      defaultValue: "this volume does not match the cited \(fields)")
    }

    /// The note under such a best guess (#1474).
    static let unmetFieldsNote = String(
        localized: "citation.match.unmetFieldsNote",
        defaultValue: "This result comes from a volume the citation does not name, so it may not be the document cited. Check the citation before relying on it."
    )

    /// The note under such a best guess when a history.state.gov link chose the volume and the
    /// text beside it chose the document, naming a volume the link's does not match (#1474 review
    /// round 2) — `FRUS, 1961–1963, vol. XIV, doc. 84, https://…/frus1961-63v05`. The volume is
    /// the one the link names, so `unmetFieldsNote`'s "a volume the citation does not name" would
    /// be untrue. The text names a different volume by its volume number or part, or by the years
    /// it gives after the series' name (`FRUS, 1964–1968`); a year it gives otherwise is the date
    /// a note opens with, is not checked, and never draws this note (#1474 review round 5).
    static let linkProseNote = String(
        localized: "citation.match.linkProseNote",
        defaultValue: "The link names this volume, but the citation’s text names a different one, and this document was found by the text’s document number or page — so it may not be the document cited. Check the citation before relying on it."
    )

    /// The explanation a best guess carries when the document found by number is not printed on
    /// the cited page (#1474 review round 1), e.g. "page 50 is outside the pages this document may
    /// be printed on (199–203)".
    ///
    /// `first`–`last` is exactly what the check accepts (`PageRangeStore.printedPages`), so no page
    /// inside the range shown is ever reported outside it (#1474 review round 2: the label first
    /// showed the document's page breaks, 200–203, while the check also accepted 199, and a
    /// document with one break read "pages 200–200"). When the range is one page, the label names
    /// it: a document with no page break of its own, between two breaks one page apart, or — since
    /// round 3's page-1 floor — a document whose only arabic page break of its own is page 1, whose
    /// range is `1...1` and whose label reads "(1)".
    static func pageOutside(page: Int, first: Int, last: Int) -> String {
        guard first < last else {
            return String(localized: "citation.match.pageOutsideOnePage",
                          defaultValue: "page \(page) is not the page this document is printed on (\(first))")
        }
        return String(localized: "citation.match.pageOutside",
                      defaultValue: "page \(page) is outside the pages this document may be printed on (\(first)–\(last))")
    }

    /// The note under such a best guess (#1474 review round 1).
    static let pageOutsideNote = String(
        localized: "citation.match.pageOutsideNote",
        defaultValue: "The citation’s page is not one this document is printed on, so its document number or its page may be wrong. Check the citation before relying on it."
    )

    /// The label on the one row a history.state.gov link yields when its volume is downloaded
    /// but no document it names — by id, number or page — is found in it (#1474 review round 1):
    /// a link to the volume itself, to a chapter, or to an id the index does not hold.
    static let linkVolumeOnly = String(
        localized: "citation.match.linkVolumeOnly",
        defaultValue: "Volume identified — no document the citation names was found in it"
    )
}
