// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalResolver

/// The one place that decides which bundled index answers "what NARA record is this archival
/// citation?" for the two surfaces that ask — the corpus browser's volume Sources outline and
/// the Collections "Sources & Archives" export block (#372 / N-5).
///
/// ## Why this type exists
/// Two shipped artifacts both map a State Department lot number to a NARA record, and until
/// this type they were consulted by different surfaces with no stated precedence:
///
/// | | lot keys resolved | how it is built |
/// |---|---|---|
/// | `central-files-index.json` | **1,065** | keyed harvest + the #372 1b offline supplement |
/// | `volume-sources-index.json` `lots` | 0 | front-matter Sources pass, resolved offline |
/// | `lot-claimants-index.json` | **123 refused** | offline record-group harvest (#675) |
///
/// Source Explorer already read central-files; these two surfaces read volume-sources, so the
/// same lot could carry a catalogue link in one place and none in another. Measured over the
/// owner's 501-volume index: **220 lot keys resolve only in central-files** and **7 only in
/// volume-sources**, worth **733 documents** and **98 front-matter nodes** gained.
///
/// Both figures are now historical. #372 item 1 folded the 7 into central-files and item 1b
/// supplemented **87 more** from the offline record-group harvest, so central-files answers
/// every lot either bundle can — 1,065 keys against the volume-sources map's zero.
///
/// ## Precedence, and why it is not a replacement
/// Central-files first, volume-sources second. It is a *fallback*, not a swap, for two
/// measured reasons:
///
/// 1. **Seven lots existed only in volume-sources** — `64D171`, `67D317`, `67D333`, `68D393`,
///    `70D449` (RG 306, USIA), `74D267`, `78D26` (RG 59). Replacing rather than layering
///    would have lost 2 documents and 7 front-matter nodes to gain 733 and 98. #372 item 1
///    then folded all seven into central-files with `FOLD_VOLUME_SOURCES`, so today the
///    fallback answers **nothing in the shipped bundle** and the `lots` map is `{}`. It stays
///    because it is one line and a re-harvest can mint new orphans — `lotsToWrite`'s
///    carry-forward exists for exactly that — but nothing on screen depends on it now.
/// 2. **Central-files has no record-group map at all.** `VolumeSourcesIndex.resolution`'s
///    second branch answers every *lot-less* node from volume-sources' 31 record-group
///    headers, and that branch carries **14,187 document rows and 6,373 front-matter nodes**
///    — twenty times the lot path's gain. This type never touches it.
///
/// ## A third bundle sits in front of both (#1205)
/// `lot-claimants-index.json` records the lots NARA divided across several series. It is
/// consulted **before** either map above and its answer is a refusal, never a resolution: where
/// it names more than one claimant there is no single record to return. See `lotResolution`.
///
/// ## What is deliberately preserved
/// A citation that names a lot resolves **only** through that lot. An unresolved lot returns
/// `nil` rather than falling back to the citation's record group, which would stamp a generic
/// "General Records of the Department of State" link on every lot the bundles cannot place.
/// That rule predates this type (`VolumeSourcesIndex.resolution`) and survives it — which is
/// why the lot branch below passes `recordGroup: nil` when it consults volume-sources.
///
/// That `nil` is belt-and-braces: `VolumeSourcesIndex.resolution` enforces the same rule on
/// its own, so passing the record group through would change nothing today. Mutation testing
/// showed the flip side — with the resolver withholding the record group, a regression *inside*
/// `VolumeSourcesIndex` is invisible from here, because there is nothing to fall through to.
/// The rule is therefore pinned at both layers
/// (`ArchivalResolverTests.volumeSourcesEnforcesTheLotOnlyRule`), not just this one.
///
/// The `#321` (`ancestryLacksRecordGroup`) and `#351` (`fileUnit`-level) refusals ride along
/// unchanged: they live inside `CentralFilesIndex.lotFile(forRawLot:)` and
/// `VolumeSourcesIndex.resolution`, and this type calls both rather than reimplementing
/// either. Measured on the shipped bundles both guards currently refuse **nothing** (1,058 of
/// 1,070 central-files entries are `series`-level and none is flagged — the 12 with no level at
/// all are the item-1 fold's seven plus the five the 2026-09-10 keyed run added (53D211, 53D403,
/// 57D618, 58D78, 64D148), which the #321/#351 guards pass and `evidence` would not; the
/// volume-sources lot map is empty) — they are dormant, not dead, and a re-harvest can
/// re-arm them. The fold itself applies the same two refusals before admitting a row, so a
/// flagged orphan stays in volume-sources rather than crossing over.
///
/// Version history:
///   1.0 — Session 2026-08-05: #372 / N-5 PR 1 (the repoint)
///   1.1 — Session 2026-08-19: #372 item 1 — the seven orphans folded into central-files
///   1.2 — Session 2026-08-19: #372 item 1b — +87 lots from the offline harvest supplement
///   1.3 — Session 2026-09-05: #1205 — a divided lot resolves to nothing rather than to one
///         of its claimants
///   1.4 — 2026-10-27 (FRUS Explorer Light, S18b): moved into FRUSCoreKit with the three indexes it reads
///         (`ArchivalIndexes`), for the Sources & Archives block a host outside the app resolves; the
///         front-matter resolution, which also reads the presidential-library catalogue, the divided-lot
///         claimants and the overloads over the app's bundled indexes stay in the app
///         (`ArchivalResolver+App.swift`), and `lotResolution` is internal so they can call it
enum ArchivalResolver {

    /// The resolution for a **document's own source citation**: its lot, and nothing else.
    ///
    /// There is deliberately no `recordGroup` parameter (#372/N-5 follow-up). A document
    /// citation names something far more specific than a record group — a decimal file number,
    /// a lot, a named series — and answering it with "General Records of the Department of
    /// State" is not a resolution, it is a category. The app already refuses that move for an
    /// unresolved *lot*; it had been making it for lot-less citations only because they happen
    /// to arrive through a different branch.
    ///
    /// ## Why the parameter is absent rather than ignored
    /// `document_sources.record_group` carries two forms — a bare `"59"` where the citation
    /// named its record group, the literal `"RG-59"` where the parser *inferred* one — and the
    /// header map is keyed bare. So 192,130 lot-less rows missed the branch while 11,495
    /// otherwise-identical ones hit it, purely on whether a FRUS editor spelled out "RG 59".
    /// Normalizing the form would have made that generic link apply to all 206,317; removing
    /// the branch makes it apply to none. Either is coherent; the arbitrary middle was the
    /// defect. Taking the parameter away means no call site can reintroduce it by passing one.
    ///
    /// The record group is still *shown* — `CollectionGeneratedBlocks.label(for:)` prints
    /// "RG 59" in the row label. It is the hyperlink that is withheld, not the fact.
    static func documentResolution(lotFile: String?,
                                   centralFiles: CentralFilesIndex?,
                                   volumeSources: VolumeSourcesIndex?,
                                   claimants: LotClaimantsIndex? = nil) -> ArchivalResolution? {
        lotResolution(lotFile, centralFiles, volumeSources, claimants)
    }

    /// Central-files first, volume-sources second — the shared lot half of both entry points,
    /// with the divided-lot refusal in front of both (#1205).
    ///
    /// ## Why a divided lot resolves to nothing
    /// NARA divides a lot file across several series as readily as it consolidates, and a
    /// `variantControlNumber` on a series **is** that series' assertion that it holds the lot.
    /// So a divided lot has several correct answers, and `ArchivalResolution` can hold exactly
    /// one: `title` and `catalogURL` are single non-optional values. There is no honest value to
    /// return, which is why this declines rather than choosing — the refusal is forced by the
    /// type, not preferred over an alternative rendering.
    ///
    /// Measured on the shipped bundles: **all 123 divided lots also carry a single `naId` in
    /// `central-files-index.json`**, so before this guard every one of them resolved to a
    /// confident single series. The picked naId was always *among* the claimants (0 of 123 were
    /// outside the list), which is the shape #675 named: the defect is an **undisclosed pick**,
    /// not a wrong record.
    ///
    /// Source Explorer has applied this rule since #675 — `SourceExplorerView` and
    /// `MacSourceExplorerView` both try `LotClaimantsIndex.candidatesOutcome` before the single
    /// bundled card — and `TripPacketModel.restriction` applies it on the access-status axis,
    /// where its doc comment records *single-pick … printed one claimant's status as if it were
    /// the lot's* as a rejected rendering. This resolver was the one lot surface still making
    /// that move, on the **identity** axis, which is why a trip packet could print "NARA divides
    /// this lot across 3 series" and a four-field pull-slip line naming one of them on the same
    /// page.
    ///
    /// `claimants(forRawLot:)` folds the citation itself and already returns `nil` for a lot with
    /// a single claimant, so this is exactly the divided case and never a lot NARA kept whole.
    static func lotResolution(_ lotFile: String?,
                              _ centralFiles: CentralFilesIndex?,
                              _ volumeSources: VolumeSourcesIndex?,
                              _ claimants: LotClaimantsIndex?) -> ArchivalResolution? {
        let lot = lotFile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !lot.isEmpty else { return nil }
        // Ahead of BOTH bundles: volume-sources stores one naId per lot for the same reason
        // central-files does, so answering from the fallback would reintroduce the same pick.
        if claimants?.claimants(forRawLot: lot) != nil { return nil }
        if let entry = centralFiles?.lotFile(forRawLot: lot) {
            return ArchivalResolution(lotFileEntry: entry)
        }
        // `recordGroup: nil` on purpose — see the note on the lot-only rule above.
        return volumeSources?.resolution(recordGroup: nil, lotFile: lot)
    }
}

// MARK: - ArchivalIndexes

/// The three bundled indexes ``ArchivalResolver`` answers a document's lot from, as a host loaded them:
/// `central-files-index.json`, `volume-sources-index.json` and `lot-claimants-index.json`, each `nil` when
/// it could not be read, which resolves nothing through it.
///
/// The app passes its bundle's (`ArchivalIndexes.bundled`, which reads the three stores); a host outside
/// the app decodes the same files and passes them in, so the Sources & Archives block links the same lots.
///
/// Version history:
///   1.0 — 2026-10-27 (FRUS Explorer Light, S18b): initial implementation
public struct ArchivalIndexes: Sendable {
    /// The central-files index: lot files first, as `ArchivalResolver` reads them.
    public var centralFiles: CentralFilesIndex?
    /// The volume-sources index: the lots central-files cannot answer.
    public var volumeSources: VolumeSourcesIndex?
    /// The lots NARA divided across several series, which resolve to nothing.
    public var claimants: LotClaimantsIndex?

    /// Creates the set; every index defaults to none.
    public init(centralFiles: CentralFilesIndex? = nil, volumeSources: VolumeSourcesIndex? = nil,
                claimants: LotClaimantsIndex? = nil) {
        self.centralFiles = centralFiles
        self.volumeSources = volumeSources
        self.claimants = claimants
    }
}

extension ArchivalResolver {

    /// ``documentResolution(lotFile:centralFiles:volumeSources:claimants:)`` against `indexes`.
    static func documentResolution(lotFile: String?, indexes: ArchivalIndexes) -> ArchivalResolution? {
        documentResolution(lotFile: lotFile, centralFiles: indexes.centralFiles,
                           volumeSources: indexes.volumeSources, claimants: indexes.claimants)
    }
}

// MARK: - ArchivalResolution bridge

extension ArchivalResolution {

    /// The central-files view of a lot, in the shape the two archival surfaces render.
    ///
    /// Every field `ArchivalResolution` declares has a counterpart on `LotFileEntry`, so this
    /// is a rename rather than a lossy projection. Two notes:
    ///
    /// - `matchType` becomes central-files' `"control"` where volume-sources said `"lot"`.
    ///   Nothing renders `matchType` — it is read only by `CentralFilesIndexTests` against
    ///   central-files' own value — so the change is invisible.
    /// - `recordGroup` is non-optional on `LotFileEntry` and optional here; it widens.
    init(lotFileEntry entry: LotFileEntry) {
        self.init(naId: entry.naId,
                  catalogURL: entry.catalogURL,
                  title: entry.title,
                  recordGroup: entry.recordGroup,
                  matchType: entry.matchType,
                  hmsMlrEntryNumbers: entry.hmsMlrEntryNumbers,
                  levelOfDescription: entry.levelOfDescription,
                  seriesNaId: entry.seriesNaId,
                  seriesTitle: entry.seriesTitle,
                  seriesHmsMlrEntryNumbers: entry.seriesHmsMlrEntryNumbers)
    }
}
