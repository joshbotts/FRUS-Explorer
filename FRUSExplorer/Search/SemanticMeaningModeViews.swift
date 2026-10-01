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
struct SemanticModeStrip: View {
    /// The last run's disclosure, or `nil` before the first Meaning run.
    let disclosure: SemanticSearchBackend.Disclosure?
    /// Beyond-library hits shown under the list.
    let beyondCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: SemanticGlyph.feature)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text(Self.caption(disclosure: disclosure, beyondCount: beyondCount))
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
    static func caption(disclosure: SemanticSearchBackend.Disclosure?, beyondCount: Int) -> String {
        var parts: [String] = [String(
            localized: "search.meaning.strip.base",
            defaultValue: "Meaning search (experimental): ranked by what your question means, across the whole series — your exact words may not appear. Front matter and chapter headings are not reachable this way.")]
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
        if disclosure.unscoredCandidates > 0 {
            parts.append(SemanticUnscoredCopy.unscored(
                candidates: disclosure.unscoredCandidates, volumes: disclosure.unscoredVolumes,
                downloading: disclosure.downloadingVolumes))
        }
        return parts.joined(separator: " ")
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
/// Version history:
///   1.0 — Session 2026-09-30: #1527, the owner's two variants
///   1.1 — Session 2026-09-30, review round 1: the not-downloading pair names Download Vectors for
///         Every Volume, and the downloading pair counts through `CountCopy` (`.v2` keys)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if needsModel {
                    SemanticModelOfferCard(onModelReady: onModelReady)
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
                            Text((disclosure?.unscoredVolumes ?? 0) > 0
                                ? SemanticUnscoredCopy.warming(
                                    volumes: disclosure?.unscoredVolumes ?? 0,
                                    downloading: disclosure?.downloadingVolumes ?? 0)
                                : String(localized: "search.semantic.empty.none",
                                         defaultValue: "Nothing in the scorable corpus reads close to this search."))
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
