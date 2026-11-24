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
///
/// ## At the accessibility text sizes, on iPhone and iPad
///
/// The strip is one row there: "Meaning search (experimental)", drawn at XXXL at most, and an ⓘ that
/// opens the whole caption in a sheet at the reader's own size (``SemanticModeStripCaptionSheet``).
/// VoiceOver reads the whole caption from the row, as it does from the strip at every other size. The
/// strip sits in Search's top inset, and grown with the reader's text the caption made the inset taller
/// than the screen: after the UI fixture's near question it was 1,530 points tall at AX5 on an iPhone 17
/// and 1,785 on an iPhone SE, SwiftUI centred the inset, and the Keywords | Meaning control, the actions
/// bar and the results went off the screen, from AX3 on the iPhone 17 and from AX1 on the iPhone SE
/// (`MeaningStripFitTests`, 2026-10-18). Two other ways were measured and not taken. Capped in two lines
/// with the whole caption in the Large Content Viewer, as `SearchLayerBaseRow` is, the caption ran off
/// the top and the bottom of the viewer at AX5, which does not scroll, and the two lines were always the
/// opening, never what this search could not do. Among the rows that scroll above the results, it was read
/// through a window under one line tall on the iPhone SE at AX5. The Mac's strip is unchanged.
///
/// Version history:
///   1.0 — V-5 hybrid page: initial implementation
///   1.1 — #1577 lane 1: where the ranking ran, and the members of a set it could not rank
///   1.2 — 2026-10-18: one row at the accessibility sizes, the whole caption a tap away
///   1.3 — 2026-11-24: FRUS Explorer Light's S27a — the caption's sentences are FRUSCoreKit's
///         (``SemanticModeStripCopy``), which ``caption(disclosure:beyondCount:pendingSetSize:locale:)``,
///         ``parts(disclosure:beyondCount:pendingSetSize:locale:)`` and ``opening(setSize:locale:)`` forward to
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

    #if os(iOS)
    /// The reader's text size, before the row's own cap: whether the strip is drawn as one row.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Whether the sheet that holds the whole caption is up.
    @State private var showsWholeCaption = false
    #endif

    var body: some View {
        let parts = Self.parts(disclosure: disclosure, beyondCount: beyondCount, pendingSetSize: pendingSetSize)
        #if os(iOS)
        if dynamicTypeSize.isAccessibilitySize {
            row(parts: parts)
        } else {
            strip(caption: parts.joined(separator: " "))
        }
        #else
        strip(caption: parts.joined(separator: " "))
        #endif
    }

    /// The strip at the standard text sizes, and on the Mac: the whole caption, wrapped.
    ///
    /// - Parameter caption: The caption.
    /// - Returns: The strip.
    private func strip(caption: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: SemanticGlyph.feature)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.25))
    }

    #if os(iOS)
    /// The strip at the accessibility text sizes: one row, the whole caption a tap away.
    ///
    /// Its words are drawn at XXXL at most, the base row's cap. The sheet draws at the reader's own size, wherever
    /// it hangs: a presentation does not take the cap (hung inside it, the sheet measured the same). A touch and
    /// hold shows the row's own words enlarged, which the Large Content Viewer can hold where it could not hold
    /// the caption.
    ///
    /// - Parameter parts: The caption's parts, each a paragraph of the sheet.
    /// - Returns: The row.
    private func row(parts: [String]) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: SemanticGlyph.feature)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(Self.rowTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(parts.joined(separator: " "))
                .accessibilityShowsLargeContentViewer {
                    Label(Self.rowTitle, systemImage: SemanticGlyph.feature)
                }
                .accessibilityIdentifier("search.meaning.strip.text")
            Button {
                showsWholeCaption = true
            } label: {
                Image(systemName: "info.circle")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .controlHelp(Self.wholeCaptionLabel, detail: Self.wholeCaptionHelp, systemImage: "info.circle")
            .accessibilityIdentifier("search.meaning.strip.more")
        }
        .padding(.leading)
        .padding(.trailing, 6)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(.quaternary.opacity(0.25))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.meaning.strip")
        .sheet(isPresented: $showsWholeCaption) {
            SemanticModeStripCaptionSheet(parts: parts)
        }
    }

    /// The row's words at the accessibility sizes, where the rest of the caption is a tap away.
    static var rowTitle: String {
        String(localized: "search.meaning.strip.row", defaultValue: "Meaning search (experimental)")
    }

    /// The ⓘ's name, for VoiceOver and the Large Content Viewer.
    static var wholeCaptionLabel: String {
        String(localized: "search.meaning.strip.more.a11y", defaultValue: "About Meaning search")
    }

    /// What the ⓘ does, for VoiceOver's hint.
    static var wholeCaptionHelp: String {
        String(localized: "search.meaning.strip.more.help",
               defaultValue: "Shows the strip's whole text at your text size")
    }

    /// The title of the sheet the ⓘ opens.
    static var sheetTitle: String {
        String(localized: "search.meaning.strip.sheet.title", defaultValue: "Meaning Search")
    }
    #endif

    /// The strip's sentences (``SemanticModeStripCopy/caption(disclosure:beyondCount:pendingSetSize:locale:)``).
    static func caption(disclosure: SemanticSearchBackend.Disclosure?, beyondCount: Int,
                        pendingSetSize: Int? = nil,
                        locale: Locale = .autoupdatingCurrent) -> String {
        SemanticModeStripCopy.caption(disclosure: disclosure, beyondCount: beyondCount,
                                      pendingSetSize: pendingSetSize, locale: locale)
    }

    /// The caption's parts (``SemanticModeStripCopy/parts(disclosure:beyondCount:pendingSetSize:locale:)``).
    static func parts(disclosure: SemanticSearchBackend.Disclosure?, beyondCount: Int,
                      pendingSetSize: Int? = nil,
                      locale: Locale = .autoupdatingCurrent) -> [String] {
        SemanticModeStripCopy.parts(disclosure: disclosure, beyondCount: beyondCount,
                                    pendingSetSize: pendingSetSize, locale: locale)
    }

    /// The strip's first sentences (``SemanticModeStripCopy/opening(setSize:locale:)``).
    static func opening(setSize: Int?, locale: Locale = .autoupdatingCurrent) -> String {
        SemanticModeStripCopy.opening(setSize: setSize, locale: locale)
    }
}

#if os(iOS)
// MARK: - SemanticModeStripCaptionSheet

/// The Meaning strip's whole caption at the reader's own text size: what the strip's ⓘ opens at the
/// accessibility sizes, where the strip is one row (``SemanticModeStrip``). Each part of the caption is a
/// paragraph, what a meaning search is first and then each thing the run could not do, and the text
/// scrolls where it is taller than the sheet.
///
/// Version history:
///   1.0 — 2026-10-18: initial implementation
struct SemanticModeStripCaptionSheet: View {

    /// The caption's parts, in order (`SemanticModeStrip.parts(disclosure:beyondCount:pendingSetSize:locale:)`).
    let parts: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(parts.indices, id: \.self) { index in
                        Text(parts[index])
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("search.meaning.strip.sheet.part")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(SemanticModeStrip.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "search.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
    }
}
#endif

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

    /// The heading over a Meaning search's matches in volumes not on this device
    /// (``SemanticModeStripCopy/beyondHeader(count:)``). `nonisolated`, as a view's statics are main-actor otherwise.
    ///
    /// - Parameter count: How many such matches.
    /// - Returns: The heading.
    nonisolated static func beyondHeader(count: Int) -> String {
        SemanticModeStripCopy.beyondHeader(count: count)
    }

    /// The sentence under "No semantic matches yet" (``SemanticModeStripCopy/emptyStatement(disclosure:locale:)``).
    static func emptyStatement(disclosure: SemanticSearchBackend.Disclosure?,
                               locale: Locale = .autoupdatingCurrent) -> String {
        SemanticModeStripCopy.emptyStatement(disclosure: disclosure, locale: locale)
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
                            Text(Self.beyondHeader(count: beyondHits.count))
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
