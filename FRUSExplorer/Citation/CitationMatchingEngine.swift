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
/// | 6 | `manifestOnly` | Vol identified but not in local corpus; or a link's downloaded volume, holding no document the citation names; or a downloaded volume the index cannot yet answer for, where nothing was found (#1522) |
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
/// engine falls through to a full document-level match. The app's engine reads the volumes
/// directory at each lookup (`init(manifestStore:searchService:pageRangeStore:volumesDirectory:)`,
/// #1522), so the second lookup sees the file with nothing to notify.
///
/// ## Downloaded, not yet indexed (#1522)
/// A downloaded volume is searched through the index, and the index cannot always say what the
/// volume holds: a volume waiting to be indexed after its download holds no rows, nor does any
/// volume after Settings' Rebuild Index empties the index until its pass reaches it, and a volume
/// whose indexing is running or was cut short may hold some of its documents and not others
/// (`SearchService.hasFinishedIndexing(_:)`). Such a volume is looked up all the same — a volume
/// re-indexed keeps its earlier rows while its pass runs — and whatever is found is returned; but
/// when the citation names something an index could find there — a document (a link's segment, or
/// a document number) or a page the volume's pages are searched for (`asksTheIndex(_:segment:in:)`)
/// — and none of it is found, the answer is the volume, labelled as not yet indexed
/// (`CitationMatch.awaitingIndex`, `ConfidenceLabels.notYetIndexed`), never absent. Before #1522 a
/// link to such a volume read "no document the citation names was found in it", and a citation of
/// it found nothing at all ("No Matches Found", and "No match" in Batch). A citation that names
/// nothing an index could find — the volume alone, or only a page of a microfiche supplement — is
/// answered as an indexed volume answers it, since no pass can change that answer; and the
/// nearest-document row (Strategy 4) takes the not-yet-indexed row's place when it finds one, since
/// no pass adds a document numbered past the manifest's count (both #1522 review round 1). Both
/// questions — is the file on disk, can the index say what it holds — are put at each lookup, so
/// the answers change the moment a download lands, a pass finishes or a volume is removed, with
/// nothing to notify and nothing to fall stale.
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
/// and for its years when it names the series with the year after it and no other number between
/// (`FRUS, 1961–1963`, `CitationVolumeFields.subseriesReading`) or gives a range the parser reads
/// by its fallback (`1964–68`, #1507). A document found by number is also checked against a
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
///   1.9 — #1505: the app's own citations reach their own volumes — a title the citation prints
///          whole comes first (`wholeTitlesFirst`), and a full title match need only carry the
///          cited year by subseries or, when the citation prints its title whole, by title, as
///          the Iran retrospective's title does; 548, 545 and 532 of the 553 round-tripped in
///          history.state.gov, Chicago and Turabian form, marked or plain, and 551 do in each, all
///          but two volumes whose titles in the Office of the Historian's data cannot be told from
///          a sibling's. The series' full name, which the fragment now keeps, counts only toward a
///          title printed whole, never toward a full title match or the shared-words ranking
///          (review round 1: `FRUS, 1961–1963, Volume VI` came back as Public Diplomacy's Volume
///          VI, and `FRUS, 1862` as an 1870s volume). #1507: beside a link, a range the parser
///          reads by its fallback is checked too (`namesSubseries`)
///   2.0 — #1522: a downloaded volume the index cannot yet answer for — never indexed, or its
///          indexing running or cut short (`indexAnswers(for:)`) — is never reported as holding
///          nothing the citation names: where nothing is found, its row says it is not yet indexed
///          (`CitationMatch.awaitingIndex`). The app's engine reads the volumes directory at each
///          lookup (`init(manifestStore:searchService:pageRangeStore:volumesDirectory:)`), and
///          `noteVolumeDownloaded(_:)`, which grew a set read once, is gone. Review round 1: that
///          row is given only for a citation naming something an index could find there
///          (`asksTheIndex(_:segment:in:)`) — a citation of the volume alone, or of a microfiche
///          supplement's page alone, is answered as an indexed volume answers it — and Strategy 4's
///          nearest document replaces it rather than being withheld by it
public actor CitationMatchingEngine {

    // MARK: - Dependencies

    private let manifestStore: ManifestStore
    private let searchService: SearchService?
    private let pageRangeStore: PageRangeStore?

    /// Where a lookup learns which volumes are downloaded.
    private let downloadedVolumes: DownloadedVolumes

    /// Which volumes a lookup treats as downloaded: searched through the index rather than offered
    /// for download (#1522).
    ///
    /// Downloaded means the volume's file is on disk, and nothing more. Whether the index can say
    /// what a downloaded volume holds is asked of the index at each lookup (`indexAnswers(for:)`),
    /// because a downloaded volume can hold no rows yet, or only some.
    private enum DownloadedVolumes: Sendable {
        /// A fixed set of volume ids — an engine a test builds over a fixture.
        case fixed(Set<String>)
        /// The volumes directory, asked at each lookup whether `<volumeId>.xml` is in it — the file
        /// `DownloadManager.isVolumeDownloaded(_:)` checks. The app's engine.
        case directory(URL)
    }

    // MARK: - Init

    /// An engine that treats exactly `downloadedVolumeIds` as downloaded — what the tests build.
    public init(
        manifestStore: ManifestStore,
        searchService: SearchService?,
        pageRangeStore: PageRangeStore?,
        downloadedVolumeIds: Set<String>
    ) {
        self.manifestStore     = manifestStore
        self.searchService     = searchService
        self.pageRangeStore    = pageRangeStore
        self.downloadedVolumes = .fixed(downloadedVolumeIds)
    }

    /// The app's engine: a volume is downloaded when its file is in `volumesDirectory` at the
    /// moment of the lookup (#1522).
    ///
    /// Until #1522 the app built its engine over a set of ids read from the directory when the
    /// engine was made, and grew it when a volume finished indexing (`noteVolumeDownloaded(_:)`,
    /// now gone). Every change to the directory that sent no notice left that set wrong: a
    /// download that had landed and was waiting for its pass was offered for download, and after
    /// Erase Local Data every volume that had been on disk still counted as downloaded. Read at
    /// each lookup, the directory is right by construction, as the index is.
    public init(
        manifestStore: ManifestStore,
        searchService: SearchService?,
        pageRangeStore: PageRangeStore?,
        volumesDirectory: URL
    ) {
        self.manifestStore     = manifestStore
        self.searchService     = searchService
        self.pageRangeStore    = pageRangeStore
        self.downloadedVolumes = .directory(volumesDirectory)
    }

    // MARK: - Public API

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
            let downloaded = isDownloaded(volumeId)
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
            // Whether a lookup that finds nothing here may leave the volume out (#1522): not while
            // its index cannot yet say what it holds, when the citation names something an index
            // could find here (review round 1). The strategies still run — a re-index keeps the rows
            // it replaces — and the volume's row after them speaks for the rest.
            var answers = true
            if asksTheIndex(input, segment: nil, in: volumeEntry) {
                answers = try await indexAnswers(for: volumeId)
            }
            let listedBefore = results.count

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

            // Nothing found in a volume the index cannot yet answer for, of something it could find
            // there: the volume, not yet indexed — where before #1522 it was left out, and a
            // citation of it alone found nothing at all.
            if !answers, results.count == listedBefore {
                results.append(qualified(notYetIndexedRow(volumeEntry, rank: rank), unmet: unmet))
                rank += 1
            }
        }

        // Strategy 4: Fuzzy doc number if no exact match found
        if results.isEmpty || results.allSatisfy({ $0.matchStrategy != .exactDocumentNumber }),
           let docNum = input.documentNumber,
           let volumeEntry = candidates.first,
           isDownloaded(volumeEntry.volumeId) {
            // The row saying the volume is not yet indexed (#1522) gives way to the nearest
            // document, in its place: that row promises an answer from the pass, and no pass adds
            // a document numbered past the manifest's count, which is when this strategy answers
            // (#1522 review round 1 — the row had withheld v2's "nearest is document M" from a
            // volume whose re-index was running or cut short, its rows intact).
            let waiting = results.firstIndex { $0.volumeId == volumeEntry.volumeId && $0.awaitingIndex }
            if let fuzzy = try await matchByFuzzyDocumentNumber(
                volumeId: volumeEntry.volumeId,
                volumeEntry: volumeEntry,
                documentNumber: docNum,
                rank: waiting.map { results[$0].rank } ?? rank
            ) {
                if let waiting { results.remove(at: waiting) }
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
    /// the link does name it. The label says nothing it names was found only when the index can
    /// say what the volume holds (`indexAnswers(for:)`); when it cannot — the volume is downloaded
    /// and not yet indexed, or its indexing is running or was cut short — it says so instead
    /// (#1522), since the document may be there all the same. A link to the whole volume with no
    /// document number or page beside it names nothing an index could find, and reads as it reads
    /// in an indexed volume (`asksTheIndex(_:segment:in:)`, #1522 review round 1).
    ///
    /// Two limits on that fallback (#1474 review round 2). A document it finds is the prose's
    /// choice, so it is checked against the subseries, volume and part the prose names
    /// (`reference.prose`) and is a best guess when the linked volume does not carry one:
    /// `vol. XIV, doc. 84, …/frus1961-63v05` is Volume V's document 84, not an exact match. The
    /// prose's year is checked when the parser read it after the series' name
    /// (`CitationVolumeFields.subseriesReading`, #1474 review round 5) or it is a range
    /// (`namesSubseries`, #1507), and then strictly, by `subseriesMatches`: `FRUS, 1961–1963, vol.
    /// XXIII, doc. 5, …/frus1964-68v23` names Volume XXIII of 1961–63, Southeast Asia, and the
    /// link's Congo volume of 1964–68 is a best guess even though its title prints 1960–1968; so
    /// is `1964–68, vol. V, doc. 84, …/frus1961-63v05`. A single year the parser read as the text's
    /// first — the text names no series, the link being its only "frus", or names it with no year
    /// following it — is not checked at all. It is the date the note opens with, which names no
    /// volume: `National Intelligence Estimate, December 1, 1960, vol. V, doc. 1,
    /// …/frus1961-63v05` is Volume V's document 1, dated 1960, and an exact match. Round 3 checked
    /// that date and reported a best guess whose text "names a different one"; round 4 met a year
    /// inside the years the volume covers, which took the Southeast Asia citation to an exact match
    /// on the Congo volume. And for a numbered `d` id the volume lacks (`d999`), the document number is
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

        guard isDownloaded(entry.volumeId) else {
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
        // Asked before any lookup, so a pass that finishes mid-lookup cannot leave a document
        // looked for in an unfinished index reported absent (#1522); and only of a link naming
        // something an index could find there (review round 1).
        var answers = true
        if asksTheIndex(input, segment: reference.documentId, in: entry) {
            answers = try await indexAnswers(for: entry.volumeId)
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
        // its volume and part, and its year when that year followed the series' name or is a
        // range — a single year read as the text's first is the document's date (#1474 review
        // round 5, #1507).
        let proseUnmet: [CitedField] = reference.prose.map { prose in
            let seriesYear = Self.namesSubseries(prose) ? prose.subseries : nil
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

        // Nothing it names was found. That says the volume lacks it only when the index can say
        // what the volume holds; otherwise the volume is not yet indexed (#1522), and Add
        // Documents adds a numbered document the link names by its id
        // (`CollectionCitationLineResolver.unsearchableLinkDocument`).
        guard answers else { return [notYetIndexedRow(entry, rank: 1)] }
        return [CitationMatch(
            documentId: "",
            volumeId: entry.volumeId,
            rank: 1,
            matchStrategy: .manifestOnly,
            confidenceLabel: ConfidenceLabels.linkVolumeOnly,
            volumeManifestEntry: entry
        )]
    }

    // MARK: - Local state (#1522)

    /// Whether `volumeId`'s file is on disk: in the fixed set, or in the volumes directory now.
    private func isDownloaded(_ volumeId: String) -> Bool {
        switch downloadedVolumes {
        case .fixed(let ids):
            return ids.contains(volumeId)
        case .directory(let directory):
            return FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(volumeId + ".xml").path)
        }
    }

    /// Whether the index can say what the downloaded volume `volumeId` holds, so that a lookup
    /// finding nothing there may report it absent: the volume has rows, and its indexing is not
    /// running or cut short (`SearchService.hasFinishedIndexing(_:)`). Asked at every lookup, never
    /// remembered, so it changes the moment a pass stores the volume's last row.
    ///
    /// `true` for an engine built without a search service, which has no index to ask and whose
    /// lookups found nothing before #1522 as they do now — only the tests build one.
    private func indexAnswers(for volumeId: String) async throws -> Bool {
        guard let searchService else { return true }
        return try await searchService.hasFinishedIndexing(volumeId)
    }

    /// Whether the citation names something an index could find in `entry` — so that, when
    /// nothing is found while the index cannot yet say what the volume holds, "look it up again
    /// once it is" promises an answer a pass can give (#1522 review round 1): a link's `segment`,
    /// a document number, or a page, in a volume whose pages are searched (not a microfiche
    /// supplement's, `isMicroficheSupplement(_:)`, which Strategy 2 skips). A citation of the
    /// volume alone (`FRUS, 1961–1963, vol. V`, or a link to the whole volume) names none of these,
    /// and finds nothing in the volume whether it is indexed or not, so it is answered as an
    /// indexed volume answers it — with no row, or a link's `linkVolumeOnly`.
    private func asksTheIndex(_ input: CitationInput, segment: String?, in entry: VolumeManifestEntry) -> Bool {
        segment != nil || input.documentNumber != nil
            || (input.pageNumber != nil && !isMicroficheSupplement(entry))
    }

    /// The one row a downloaded volume gives when its index cannot yet say what it holds and
    /// nothing the citation names was found in it, the citation naming something the index could
    /// find (`asksTheIndex(_:segment:in:)`) (#1522): the volume, with no document and no download
    /// to offer, labelled `ConfidenceLabels.notYetIndexed`.
    private func notYetIndexedRow(_ entry: VolumeManifestEntry, rank: Int) -> CitationMatch {
        #if DEBUG
        print("[CitationMatcher] \(entry.volumeId) is downloaded, but its index cannot say yet what it holds — not yet indexed")
        #endif
        return CitationMatch(
            documentId: "",
            volumeId: entry.volumeId,
            rank: rank,
            matchStrategy: .manifestOnly,
            confidenceLabel: ConfidenceLabels.notYetIndexed,
            awaitingIndex: true,
            volumeManifestEntry: entry
        )
    }

    /// Whether the year the text beside a link gives names a subseries, and so is checked against
    /// the link's volume: a year the parser read after the series' name, or a range it read by its
    /// fallback (`.firstYear`, #1507) — whether the text names no series or names it with another
    /// number before the year (`FRUS, vol. V, doc. 84, 1964–68`).
    ///
    /// A bare year read by the fallback is the date a note opens with (`National Intelligence
    /// Estimate, December 1, 1960`), and names no volume. A range read that way does: `1964–68,
    /// vol. V, doc. 84, …/frus1961-63v05` cites Volume V of 1964–68, and before #1507 it was an
    /// exact match on the linked Volume V of 1961–63, because a year read without the series' name
    /// was never checked.
    static func namesSubseries(_ prose: CitationVolumeFields) -> Bool {
        guard let subseries = prose.subseries else { return false }
        return prose.subseriesReading == .afterSeriesName || subseries.contains("-")
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
        } else if match.awaitingIndex {
            // The best guess takes the label, so the note says the volume is not yet indexed: no
            // button says it, as Download says a volume is not downloaded (#1522).
            notes.append(match.confidenceLabel)
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
            // A volume row keeps its strategy: it names no document for a best guess to be.
            matchStrategy: match.requiresDownload || match.awaitingIndex
                ? match.matchStrategy : .bestGuess(explanation: explanation),
            confidenceLabel: ConfidenceLabels.bestGuess(explanation),
            correctionNote: notes.joined(separator: "\n"),
            requiresDownload: match.requiresDownload,
            awaitingIndex: match.awaitingIndex,
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
    /// The series' full name takes no part in that test, nor in counting whether a fragment is
    /// long enough for it (`withoutSeriesName`, #1505 review round 1). Of the titles it keeps, only
    /// those that carry the cited year are offered when any does: those whose subseries it is, and
    /// — since #1505, where it was the subseries alone — those whose title prints it
    /// (`subseriesMatches` without the print year) and which the citation prints whole. A title the
    /// citation prints whole comes before the rest (`wholeTitlesFirst`).
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
            // The words the citation prints (#1505): its fragment, and the years of its subseries
            // and its volume's word and numeral, which the parser takes out of the fragment. A
            // citation that names the series — `Foreign Relations`, or `FRUS`, which the parser
            // spells out — names the whole of it, old or new. So `Foreign Relations, 1919, vol. i`
            // prints every word of `Papers Relating to the Foreign Relations of the United States,
            // 1919, Volume I`, and not "The Paris Peace Conference", which the Paris Volume I adds.
            let printed = fragTokens
                .union(subseries.map { yearTokens($0) } ?? [])
                .union(volumeNumber.map { titleTokens($0).union(["volume"]) } ?? [])
                .union(fragTokens.isSuperset(of: ["foreign", "relations"]) ? Self.seriesNameTokens : [])
            // The words that can choose a volume by its title: the fragment's, less the series'
            // full name, which the parser leaves in for `printed` (#1505 review round 1).
            let titleWords = titleTokens(Self.withoutSeriesName(fragment))
            if !fragTokens.isEmpty {
                // A substantial fragment can OVERRIDE the subseries: find volumes whose title
                // contains ALL of its tokens — a full, unambiguous match (e.g. only frus1863p2
                // carries both "First Session" and "Part II"). Reserved for multi-token fragments
                // so a single generic word can't hijack resolution across the whole manifest.
                if titleWords.count >= 4 {
                    let fullMatches = allVolumes.filter { titleWords.isSubset(of: titleTokens($0.title)) }
                    if !fullMatches.isEmpty {
                        // Prefer full matches that also carry the cited year: those whose subseries
                        // it is, and those whose title prints it and which the citation prints
                        // whole (#1505: the Iran retrospective's subseries is 1951–54, and its
                        // title prints the 1952–1954 it is cited by). Only a title printed whole
                        // (review round 1): every word of `Foreign Relations, 1964–1968, volume
                        // VII` is in Public Diplomacy's "…, 1917–1972, Volume VII, Public
                        // Diplomacy, 1964–1968", which sorts before 1964–68's own Volume VII.
                        // Otherwise the title corrects a print-year subseries collision. Either way
                        // a title the citation prints whole comes first.
                        let inSubseries = subseries.map { cited in
                            let wanted = normalizeSubseries(cited)
                            return fullMatches.filter { entry in
                                normalizeSubseries(entry.subseries) == wanted
                                    || (subseriesMatches(cited, entry: entry, printYear: false)
                                        && isPrintedWhole(entry, printed: printed))
                            }
                        } ?? fullMatches
                        return applyVolumeAndPart(wholeTitlesFirst(inSubseries.isEmpty ? fullMatches : inSubseries,
                                                                   printed: printed))
                    }
                }
                // Otherwise (short fragment, or no full match) apply the explicit volume number
                // FIRST — it stays authoritative — then narrow that set by token overlap, keeping
                // only the best-scoring volumes. This preserves the historic "narrow by a
                // distinctive title word" behavior (e.g. "Vietnam") and ranks multi-token fragments
                // for `match()`'s prefix(3), without letting a title word override an explicit
                // volume number. The series' full name is not counted (`withoutSeriesName`).
                let byVolume = applyVolumeAndPart(subseriesCandidates)
                let scored = byVolume
                    .map { entry in (entry: entry, overlap: titleWords.intersection(titleTokens(entry.title)).count) }
                    .filter { $0.overlap > 0 }
                if let maxOverlap = scored.map(\.overlap).max() {
                    return wholeTitlesFirst(scored.filter { $0.overlap == maxOverlap }.map(\.entry),
                                            printed: printed)
                }
                return wholeTitlesFirst(byVolume, printed: printed)
            }
        }

        return applyVolumeAndPart(subseriesCandidates)
    }

    /// `entries` with every title the citation prints whole — each of its words among `printed` —
    /// moved to the front, the longest first, and the rest after them in the order given (#1505).
    ///
    /// Several titles can hold every word a citation gives, and the manifest order used to pick
    /// among them: `frus1919v01`'s own citation, `Papers Relating to the Foreign Relations of the
    /// United States, 1919, Volume I`, came back as the Paris Peace Conference's Volume I, whose
    /// title holds every one of those words and "The Paris Peace Conference" besides, because
    /// the Paris volumes come first. The title a citation prints whole is the one it names; one
    /// that adds words it does not print is a different volume that shares them. Of two printed
    /// whole, the longer is the more specific: the citation prints the words it adds too. That
    /// order decides nothing measured today — putting the shorter first changes none of the app's
    /// own citations of the 553 volumes and none of the 30,204 footnote clauses — because a
    /// fragment holding the longer title's extra words ("Second Edition", say) is no full match for
    /// the shorter one; a fixture pins it (`longerWholeTitleFirst`).
    ///
    /// Only a title printed whole moves. Ranking every title by how few words it adds, as this
    /// was first written, put the shortest title first wherever a citation printed none of them
    /// whole: `Foreign Relations, 1915, p. 146` came back as the 1915 World War supplement ahead
    /// of the 1915 volume, whose title adds the President's annual message. Over the 30,204
    /// clauses of the corpus's own footnotes that name the series and a year (corpus
    /// `550a8c5c5`), that ranking gave 1,268 of them a different first volume while reading the
    /// same subseries as before. This one gives 244: 230 citing 1919's `vol. i` or `vol. ii` move
    /// off a Paris Peace Conference volume, 6 citing 1919's Russia volume likewise, 2 citing
    /// `volume E–13` off E–2 and 1 citing 1945's `vol. i` off the Berlin volume. In the other 5
    /// the first answer was wrong before and after: one cites `1918, supp. 2`, which neither
    /// reached, and four name no published volume (a Senate committee, the Council on Foreign
    /// Relations, a volume still to be published).
    ///
    /// A title that is nothing but the series' name and a year never moves: every citation of that
    /// year prints it. Two of the 553 bundled titles are. `frus1918`'s is the 1918 volume's own,
    /// which the manifest orders first among that year's. `frus1894app2`'s is cut short upstream —
    /// its TEI's complete title stops at "Foreign Relations of the United States, 1894", and
    /// "Appendix II, Affairs in Hawaii" stands only in its volume-number and volume titles — and
    /// moving it would send every `Foreign Relations, 1894` citation to the Hawaii appendix rather
    /// than to the 1894 volume.
    private func wholeTitlesFirst(_ entries: [VolumeManifestEntry],
                                  printed: Set<String>) -> [VolumeManifestEntry] {
        let whole = entries.enumerated()
            .filter { isPrintedWhole($0.element, printed: printed) }
            .map { (offset: $0.offset, entry: $0.element, words: titleTokens($0.element.title).count) }
            .sorted { ($0.words, $1.offset) > ($1.words, $0.offset) }
            .map(\.entry)
        let moved = Set(whole.map(\.volumeId))
        return whole + entries.filter { !moved.contains($0.volumeId) }
    }

    /// Whether a citation printing the words `printed` prints `entry`'s title whole: every word of
    /// the title among them, and at least one besides the series' name and its years
    /// (`wholeTitlesFirst`, #1505).
    private func isPrintedWhole(_ entry: VolumeManifestEntry, printed: Set<String>) -> Bool {
        let words = titleTokens(entry.title)
        return words.isSubset(of: printed)
            && words.subtracting(Self.seriesNameTokens).contains { !Self.isYear($0) }
    }

    /// The series' name as title tokens, in its old form and its new: "Papers Relating to the
    /// Foreign Relations of the United States" holds "Foreign Relations of the United States".
    static let seriesNameTokens: Set<String> = ["papers", "relating", "to", "the", "foreign",
                                                "relations", "of", "united", "states"]

    /// `fragment` with the series' full name taken out wherever it stands — "Papers Relating to
    /// the Foreign Relations of the United States", "Foreign Relations of the United States", or
    /// "FRUS" (#1505 review round 1).
    ///
    /// `resolveVolume` counts what is left when it decides whether a fragment is long enough to
    /// search every title, matches only that against a title, and ranks titles by it. The parser
    /// took a leading full name out of the fragment until #1505, which keeps it so that a title
    /// can be printed whole (`wholeTitlesFirst`); counted, the name made every citation long.
    /// `FRUS, 1961–1963, Volume VI, Document 5` then searched the whole manifest, and of the
    /// titles holding its words the first was Public Diplomacy's Volume VI, "…, 1917–1972, Volume
    /// VI, Public Diplomacy, 1961–1963". `FRUS, 1862, p. 100`, matched against the name, found
    /// only titles that print it — none of the 19 volumes of 1861–1868 does — and came back as a
    /// best guess on `frus1870`. And ranked by shared words, `FRUS, 1865, p. 100` kept only the
    /// one 1865 part whose title also says "of the United States".
    ///
    /// The bare "Foreign Relations" stays, as it stayed in the fragment before #1505: the
    /// corpus's footnotes cite that way — `Foreign Relations, Japan, 1931—1941, vol. i` reaches
    /// the Japan volumes only by a full title match, which its other two words could not make.
    /// Only a name standing as words is taken.
    static func withoutSeriesName(_ fragment: String) -> String {
        fragment.replacingOccurrences(
            of: #"(?<![A-Za-z])(?:FRUS|(?:Papers\s+Relating\s+to\s+the\s+)?Foreign\s+Relations\s+of\s+the\s+United\s+States)(?![A-Za-z])"#,
            with: " ", options: [.regularExpression, .caseInsensitive])
    }

    /// Whether a title token is a year.
    private static func isYear(_ token: String) -> Bool {
        token.count == 4 && token.allSatisfy(\.isNumber)
    }

    /// The years a subseries spans at its ends, as title tokens: `"1952-54"` → 1952 and 1954,
    /// `"1883"` → 1883.
    private func yearTokens(_ subseries: String) -> Set<String> {
        let ends = normalizeSubseries(subseries).split(separator: "-").map(String.init)
        guard let start = ends.first, let first = Int(start) else { return [] }
        guard ends.count == 2, let tail = Int(ends[1]) else { return [start] }
        // A two-digit end takes the start's century, or the next one when it would fall before it.
        let century = first / 100 * 100
        let last = ends[1].count == 2 ? (century + tail < first ? century + 100 + tail : century + tail) : tail
        return [start, String(last)]
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
    ///
    /// `printYear: false` leaves the print year out (#1505), for choosing among the volumes whose
    /// titles hold every word of a citation's title fragment: there the print year admits every
    /// volume printed in the cited year, whatever years it covers, and the manifest orders such a
    /// volume first — `frus1893` was printed in 1894, `frus1911` in 1918 and `frus1918Russiav01`
    /// in 1931. With it in, as #1505 first measured it, the app's own citations of `frus1883`,
    /// `frus1889`, `frus1918` and `frus1931v01` went to `frus1882`, `frus1888p1`, `frus1911` and
    /// `frus1918Russiav01`. Since review round 1 a volume that match keeps by a year its title
    /// prints must also be one the citation prints whole; measured then, leaving the print year
    /// out decides none of the 553 volumes' own citations, in any of their six forms, and none of
    /// 2,492 citations naming the series, a subseries and a volume, document, page or part. It
    /// stays out because that match is by what the title prints.
    private func subseriesMatches(_ cited: String, entry: VolumeManifestEntry,
                                  printYear: Bool = true) -> Bool {
        let wanted = normalizeSubseries(cited)
        if normalizeSubseries(entry.subseries) == wanted { return true }
        if printYear, let printed = FRUSVolumeMetadata.firstYear(in: entry.publicationDate),
           String(printed) == wanted {
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
    /// be untrue. The text names a different volume by its volume number or part, by the years
    /// it gives after the series' name with no other number between (`FRUS, 1964–1968`), or by a
    /// range the parser reads otherwise (`1964–68`, #1507); a single year it gives otherwise is the
    /// date a note opens with, is not checked, and never draws this note (#1474 review round 5).
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

    /// The label on the one row a downloaded volume gives when nothing the citation names was found
    /// in it while its index cannot yet say what it holds (#1522): the volume was never indexed —
    /// it waits in the queue after its download, or Settings' Rebuild Index has not reached it — or
    /// its indexing is running or was cut short. It replaces `linkVolumeOnly` for a link, and the
    /// empty answer a citation of such a volume got before — for a citation naming something the
    /// index could find there (a document or a searched page); one naming the volume alone keeps
    /// the indexed volume's answer, and a document past the volume's count gets its nearest
    /// document once the index holds it (#1522 review round 1). It says "not yet indexed", not
    /// "being indexed": a volume whose pass was cut short waits for the reader to index it again.
    static let notYetIndexed = String(
        localized: "citation.match.notYetIndexed",
        defaultValue: "Volume identified — downloaded but not yet indexed; look it up again once it is"
    )
}
