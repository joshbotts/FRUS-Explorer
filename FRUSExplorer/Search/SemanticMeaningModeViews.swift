// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SemanticModeStrip

/// The Meaning mode's replacement for the MATCH inspector strip (V-5 hybrid page): where the
/// keyword route shows the FTS5 expression it executed, this route shows what a meaning search
/// IS and every count it owes — the assessment's breakage budget, answered as one honest bar.
/// Shared by both platforms, the strip's copy in one place.
///
/// Since #1577 lane 1 the strip says where the ranking ran. A search inside a document set (an
/// applied working corpus, a project's History scope) ranks that set's members and no others, so
/// "across the whole series" would be untrue there; the strip names the set's size instead, and
/// counts the members that could not be ranked.
struct SemanticModeStrip: View {
    /// The last run's disclosure, or `nil` before the first Meaning run.
    let disclosure: SemanticSearchBackend.Disclosure?
    /// Beyond-library hits shown under the list.
    let beyondCount: Int
    /// The size of the document set the NEXT Meaning search would rank inside, or `nil` when no
    /// set is applied: the host's live `documentIds` count. Read only while there is no
    /// disclosure. Once a run has one, the strip describes that run by its own record
    /// (`Disclosure.rankedWithin`), so a set applied or cleared since does not relabel the rows.
    var pendingSetSize: Int? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: SemanticGlyph.feature)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text(Self.caption(disclosure: disclosure, beyondCount: beyondCount,
                              pendingSetSize: pendingSetSize))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.25))
    }

    /// The strip's sentences — a pure function so a test can pin every disclosure.
    ///
    /// - Parameters:
    ///   - disclosure: The last run's disclosure, or `nil` before the first Meaning run.
    ///   - beyondCount: Beyond-library hits shown under the list.
    ///   - pendingSetSize: The live document set's size, read only when `disclosure` is `nil`.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The sentences, joined by a space.
    static func caption(disclosure: SemanticSearchBackend.Disclosure?, beyondCount: Int,
                        pendingSetSize: Int? = nil,
                        locale: Locale = .autoupdatingCurrent) -> String {
        // The run's own record where there is one, a corpus-wide run's `nil` included; the next
        // run's set otherwise.
        let setSize = disclosure.map(\.rankedWithin) ?? pendingSetSize
        var parts: [String] = [opening(setSize: setSize, locale: locale)]
        guard let disclosure else { return parts.joined(separator: " ") }
        if disclosure.filtersApplied, disclosure.filteredOut > 0 {
            parts.append(String(format: String(
                localized: "search.meaning.strip.filtered %lld",
                defaultValue: "Your filters removed %lld matches."),
                Int64(disclosure.filteredOut)))
        }
        if disclosure.beyondUncheckedByFilters, beyondCount > 0 {
            parts.append(String(
                localized: "search.meaning.strip.beyondUnchecked",
                defaultValue: "Matches in volumes you have not downloaded are checked against your volume scope only, not your other filters."))
        }
        if disclosure.notIndexedHere > 0 {
            parts.append(SemanticUnscoredCopy.notIndexedHere(disclosure.notIndexedHere, locale: locale))
        }
        if disclosure.withoutVector > 0 {
            parts.append(SemanticUnscoredCopy.withoutVector(disclosure.withoutVector, locale: locale))
        }
        if disclosure.unscoredCandidates > 0 {
            // Inside a set the unscored are the reader's own documents, not candidates, and the
            // control that fetches their files is a different one.
            parts.append(disclosure.rankedWithin == nil
                ? SemanticUnscoredCopy.unscored(
                    candidates: disclosure.unscoredCandidates, volumes: disclosure.unscoredVolumes,
                    downloading: disclosure.downloadingVolumes, locale: locale)
                : SemanticUnscoredCopy.unranked(
                    members: disclosure.unscoredCandidates, volumes: disclosure.unscoredVolumes,
                    downloading: disclosure.downloadingVolumes, locale: locale))
        }
        return parts.joined(separator: " ")
    }

    /// The strip's first sentences: what a meaning search is, and where this one ranks.
    ///
    /// - Parameters:
    ///   - setSize: The size of the document set ranked inside, or `nil` for the whole series.
    ///   - locale: The locale that groups the count.
    /// - Returns: The sentences.
    static func opening(setSize: Int?, locale: Locale = .autoupdatingCurrent) -> String {
        guard let setSize else {
            return String(
                localized: "search.meaning.strip.base",
                defaultValue: "Meaning search (experimental): ranked by what your question means, across the whole series — your exact words may not appear. Front matter and chapter headings are not reachable this way.")
        }
        guard setSize > 0 else {
            return String(
                localized: "search.meaning.strip.base.emptySet",
                defaultValue: "Meaning search (experimental): the set you are searching within holds no documents on this device, so there is nothing to rank.")
        }
        return String(format: String(
            localized: "search.meaning.strip.base.within %@",
            defaultValue: "Meaning search (experimental): ranked by what your question means, inside the %@ you are searching within — your exact words may not appear. Front matter and chapter headings are not reachable this way."),
            CountCopy.documents(setSize, locale: locale))
    }
}

// MARK: - SemanticUnscoredCopy

/// What a meaning search says about the candidates it could not score, in the variant the match
/// files' state makes true (#1527). Both search surfaces — the Meaning mode and the keyword
/// fallback — read it, so the two cannot disagree about whether anything is downloading.
///
/// "Downloading" is claimed only when every unscored volume has a download under way: the searcher
/// asked for each volume's file (it asks only for its top candidates' volumes) and
/// `AppState.requestSemanticShardForSearch` answered that a fetch started or is running. Otherwise
/// the sentence points to **Download Vectors for Every Volume** in Settings: a meaning search ranks
/// the whole series, so the volumes it could not score are usually ones the reader has not
/// downloaded, and that is the one control that fetches their files. **Download Missing Vectors**
/// fetches files only for downloaded volumes, and is not on screen when every downloaded volume has
/// its file, which with Download With Volumes on is the ordinary state (review round 1).
///
/// ## Inside a document set the pair is a different one (#1577 lane 1)
///
/// A search inside a working corpus or a History scope ranks the reader's own documents, so what
/// went unscored there is so many *documents*, not possible matches, and the files wanted are for
/// volumes the reader has: **Download Missing Vectors** is the control, where the corpus-wide
/// sentences rightly name Download Vectors for Every Volume.
/// ``unranked(members:volumes:downloading:locale:)`` and
/// ``emptyInsideSet(setSize:ranked:filteredOut:volumes:downloading:locale:)`` word that case,
/// and the pair above stays as it is for the corpus-wide search and the keyword fallback.
/// ``withoutVector(_:locale:)`` is the third thing a set can hold: a member no search can rank.
/// ``notIndexedHere(_:locale:)`` is for either kind of search: a close match that was ranked and
/// that this device's index has no row to list.
///
/// Version history:
///   1.0 — Session 2026-09-30: #1527, the owner's two variants
///   1.1 — Session 2026-09-30, review round 1: the not-downloading pair names Download Vectors for
///         Every Volume, and the downloading pair counts through `CountCopy` (`.v2` keys)
///   1.2 — #1577 lane 1: the sentences for a search inside a document set
enum SemanticUnscoredCopy {

    /// Whether the "downloading" variant is true: something is unscored and every unscored volume
    /// has a download under way.
    ///
    /// - Parameters:
    ///   - volumes: Distinct volumes whose candidates went unscored.
    ///   - downloading: Of those, the ones with a download under way.
    /// - Returns: `true` for the downloading variant.
    static func isDownloading(volumes: Int, downloading: Int) -> Bool {
        volumes > 0 && downloading >= volumes
    }

    /// The results caption's unscored sentence.
    ///
    /// - Parameters:
    ///   - candidates: Candidate documents dropped for want of a match file.
    ///   - volumes: Distinct volumes those came from.
    ///   - downloading: Of those volumes, the ones with a download under way.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The sentence.
    static func unscored(candidates: Int, volumes: Int, downloading: Int,
                         locale: Locale = .autoupdatingCurrent) -> String {
        if isDownloading(volumes: volumes, downloading: downloading) {
            return String(format: String(
                localized: "search.semantic.results.unscored.v2 %@ %@",
                defaultValue: "%1$@ in %2$@ could not be scored yet; their match files are downloading."),
                possibleMatches(candidates, locale: locale), CountCopy.volumes(volumes, locale: locale))
        }
        return String(format: String(
            localized: "search.semantic.results.unscored.notFetching %@ %@",
            defaultValue: "%1$@ in %2$@ could not be scored. Try Download Vectors for Every Volume in Settings to enable scoring."),
            possibleMatches(candidates, locale: locale), CountCopy.volumes(volumes, locale: locale))
    }

    /// The empty state's sentence when nothing could be scored.
    ///
    /// - Parameters:
    ///   - volumes: Distinct volumes whose candidates went unscored.
    ///   - downloading: Of those volumes, the ones with a download under way.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    /// - Returns: The sentence.
    static func warming(volumes: Int, downloading: Int,
                        locale: Locale = .autoupdatingCurrent) -> String {
        if isDownloading(volumes: volumes, downloading: downloading) {
            return String(format: String(
                localized: "search.semantic.empty.warming.v2 %@",
                defaultValue: "Match files for %@ are still downloading in the background. Searching again in a moment may find more."),
                CountCopy.volumes(volumes, locale: locale))
        }
        return String(format: String(
            localized: "search.semantic.empty.notFetching %@",
            defaultValue: "Match files for %@ are required. Use Download Vectors for Every Volume in Settings to get the data needed to run this search."),
            CountCopy.volumes(volumes, locale: locale))
    }

    /// The strip's sentence for members of a document set whose match files are not on the device.
    ///
    /// - Parameters:
    ///   - members: Members of the set not ranked for want of a match file.
    ///   - volumes: Distinct volumes those are in.
    ///   - downloading: Of those volumes, the ones with a download under way.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The sentence.
    static func unranked(members: Int, volumes: Int, downloading: Int,
                         locale: Locale = .autoupdatingCurrent) -> String {
        if isDownloading(volumes: volumes, downloading: downloading) {
            return String(format: String(
                localized: "search.meaning.strip.unranked.downloading %@ %@",
                defaultValue: "%1$@ in %2$@ could not be ranked yet; their match files are downloading."),
                CountCopy.documents(members, locale: locale), CountCopy.volumes(volumes, locale: locale))
        }
        return String(format: String(
            localized: "search.meaning.strip.unranked.notFetching %@ %@",
            defaultValue: "%1$@ in %2$@ could not be ranked: their match files are not on this device. Download Missing Vectors in Settings fetches the files for volumes you have downloaded."),
            CountCopy.documents(members, locale: locale), CountCopy.volumes(volumes, locale: locale))
    }

    /// The strip's sentence for close matches this device's index holds no row for, in a search
    /// of the series and inside a set alike.
    ///
    /// It names no cause, because the app cannot tell which applies: the volume here is older
    /// than the build's match data, or newer, or its indexing was cut short.
    ///
    /// - Parameters:
    ///   - count: Ranked hits in indexed volumes with no row in the index.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    /// - Returns: The sentence.
    static func notIndexedHere(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(
            count,
            one: String(localized: "search.meaning.strip.notIndexed.one",
                        defaultValue: "%@ close match is not listed: this device's index does not hold that document."),
            many: String(localized: "search.meaning.strip.notIndexed.many",
                         defaultValue: "%@ close matches are not listed: this device's index does not hold those documents."),
            locale: locale)
    }

    /// The strip's sentence for members of a document set that have no vector at all.
    ///
    /// Short on purpose. It follows the opening, which has just said that front matter and
    /// chapter headings are not reachable this way, and the strip sits in the top inset of an
    /// iPhone, above the results it describes.
    ///
    /// - Parameters:
    ///   - count: Members the bundled vectors hold no row for.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    /// - Returns: The sentence.
    static func withoutVector(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(
            count,
            one: String(localized: "search.meaning.strip.withoutVector.one",
                        defaultValue: "%@ document in the set has no match data and cannot be ranked."),
            many: String(localized: "search.meaning.strip.withoutVector.many",
                         defaultValue: "%@ documents in the set have no match data and cannot be ranked."),
            locale: locale)
    }

    /// The empty state's sentence when a search inside a document set has no row to show.
    ///
    /// A set is ranked whole and with no threshold, so an empty list never means that nothing
    /// was close. It has one of five causes, and the sentence names the one that applies: the set
    /// is empty on this device; none of its members was ranked because match files are missing;
    /// none was ranked because none has a vector; members were ranked and the other filters then
    /// removed the closest of them; or members were ranked, no filter removed any, and none of
    /// the closest is in this device's index. The app never blames a filter that removed nothing.
    ///
    /// - Parameters:
    ///   - setSize: The size of the set the search ran inside.
    ///   - ranked: Members scored, before the list was cut to its length and filtered.
    ///   - filteredOut: Ranked hits the other filters removed (`Disclosure.filteredOut`).
    ///   - volumes: Distinct volumes whose members went unranked for want of a match file.
    ///   - downloading: Of those volumes, the ones with a download under way.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The sentence.
    static func emptyInsideSet(setSize: Int, ranked: Int, filteredOut: Int,
                               volumes: Int, downloading: Int,
                               locale: Locale = .autoupdatingCurrent) -> String {
        guard setSize > 0 else {
            return String(localized: "search.semantic.empty.set.none",
                          defaultValue: "The set you are searching within holds no documents on this device, so there is nothing to rank.")
        }
        guard ranked == 0 else {
            return filteredOut > 0
                ? String(localized: "search.semantic.empty.set.filtered",
                         defaultValue: "None of the closest matches inside the documents you are searching within passes your other filters.")
                : String(localized: "search.semantic.empty.set.notIndexed",
                         defaultValue: "None of the closest matches inside the documents you are searching within is indexed on this device.")
        }
        guard volumes > 0 else {
            return String(localized: "search.semantic.empty.set.noVectors",
                          defaultValue: "None of the documents you are searching within can be ranked by meaning: the app has no match data for them. Front matter and chapter headings never have any.")
        }
        if isDownloading(volumes: volumes, downloading: downloading) {
            return String(format: String(
                localized: "search.semantic.empty.set.warming %@",
                defaultValue: "Match files for %@ are still downloading in the background. Searching again in a moment may rank the documents you are searching within."),
                CountCopy.volumes(volumes, locale: locale))
        }
        return String(format: String(
            localized: "search.semantic.empty.set.notFetching %@",
            defaultValue: "The documents you are searching within could not be ranked: match files for %@ are not on this device. Download Missing Vectors in Settings fetches the files for volumes you have downloaded."),
            CountCopy.volumes(volumes, locale: locale))
    }

    /// "1 possible match", "1,204 possible matches" — the count both caption variants lead with.
    private static func possibleMatches(_ count: Int, locale: Locale) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "search.semantic.possibleMatches.one",
                                     defaultValue: "%@ possible match"),
                         many: String(localized: "search.semantic.possibleMatches.many",
                                      defaultValue: "%@ possible matches"),
                         locale: locale)
    }
}

// MARK: - SemanticBeyondLibrarySection

/// The beyond-library stratum of a Meaning result list — hits the reader cannot open here,
/// shown by the #262 rule beneath the openable rows, never mixed into them (they have no
/// metadata to sort or filter by). `Section` content, mounted inside each platform's `List`.
struct SemanticBeyondLibrarySection: View {
    let hits: [SemanticSearchBackend.BeyondLibraryHit]

    var body: some View {
        if !hits.isEmpty {
            Section {
                ForEach(hits) { hit in
                    SemanticUndownloadedRow(
                        volumeID: hit.volumeID,
                        documentID: hit.documentID,
                        score: hit.score,
                        volumeTitle: hit.volumeTitle,
                        isDownloadable: hit.isDownloadable)
                }
            } header: {
                Text(String(format: String(
                    localized: "search.meaning.beyond.header %lld",
                    defaultValue: "In volumes you have not downloaded (%lld)"),
                    Int64(hits.count)))
            }
        }
    }
}

// MARK: - SemanticMeaningEmptyState

/// The Meaning mode's results-empty surface: the model offer when that is what is missing,
/// otherwise the honest empty statement plus whatever beyond-library hits exist — a meaning
/// search whose only matches are beyond the library is NOT a zero, and rendering the keyword
/// zero-state's "term is absent" diagnosis for it would be the wrong claim twice over.
struct SemanticMeaningEmptyState: View {
    let needsModel: Bool
    let disclosure: SemanticSearchBackend.Disclosure?
    let beyondHits: [SemanticSearchBackend.BeyondLibraryHit]
    /// Re-runs the search once the model lands.
    let onModelReady: () -> Void

    /// The sentence under "No semantic matches yet" — a pure function so a test can pin each case.
    ///
    /// A run inside a document set (#1577 lane 1) is worded by what became of the set. "Nothing in
    /// the scorable corpus reads close" would be untrue there: the set is ranked whole, with no
    /// threshold, so an empty list never means nothing was close.
    ///
    /// - Parameters:
    ///   - disclosure: The run's disclosure, or `nil` when it has none.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The sentence.
    static func emptyStatement(disclosure: SemanticSearchBackend.Disclosure?,
                               locale: Locale = .autoupdatingCurrent) -> String {
        if let disclosure, let setSize = disclosure.rankedWithin {
            return SemanticUnscoredCopy.emptyInsideSet(
                setSize: setSize, ranked: disclosure.rankedCount ?? 0,
                filteredOut: disclosure.filteredOut,
                volumes: disclosure.unscoredVolumes, downloading: disclosure.downloadingVolumes,
                locale: locale)
        }
        return (disclosure?.unscoredVolumes ?? 0) > 0
            ? SemanticUnscoredCopy.warming(
                volumes: disclosure?.unscoredVolumes ?? 0,
                downloading: disclosure?.downloadingVolumes ?? 0, locale: locale)
            : String(localized: "search.semantic.empty.none",
                     defaultValue: "Nothing in the scorable corpus reads close to this search.")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if needsModel {
                    SemanticModelOfferCard(followsKeywordSearch: false, onModelReady: onModelReady)
                } else {
                    // No strip here: both hosts keep `SemanticModeStrip` mounted persistently
                    // (iOS in the top inset, macOS in the body chain), and a second copy in the
                    // empty state rendered the same disclosures twice — measured on the sim.
                    if beyondHits.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(String(localized: "search.semantic.empty.title",
                                         defaultValue: "No semantic matches yet"),
                                  systemImage: SemanticGlyph.feature)
                                .font(.headline)
                            Text(Self.emptyStatement(disclosure: disclosure))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: String(
                                localized: "search.meaning.beyond.header %lld",
                                defaultValue: "In volumes you have not downloaded (%lld)"),
                                Int64(beyondHits.count)))
                                .font(.headline)
                            ForEach(beyondHits) { hit in
                                SemanticUndownloadedRow(
                                    volumeID: hit.volumeID,
                                    documentID: hit.documentID,
                                    score: hit.score,
                                    volumeTitle: hit.volumeTitle,
                                    isDownloadable: hit.isDownloadable)
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}
