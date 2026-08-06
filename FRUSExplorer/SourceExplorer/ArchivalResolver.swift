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
/// | `central-files-index.json` | **971** | keyed NARA Catalog harvest, `variantControlNumber` |
/// | `volume-sources-index.json` `lots` | 758 | front-matter Sources pass, resolved offline |
///
/// Source Explorer already read central-files; these two surfaces read volume-sources, so the
/// same lot could carry a catalogue link in one place and none in another. Measured over the
/// owner's 501-volume index: **220 lot keys resolve only in central-files** and **7 only in
/// volume-sources**, worth **733 documents** and **98 front-matter nodes** gained.
///
/// ## Precedence, and why it is not a replacement
/// Central-files first, volume-sources second. It is a *fallback*, not a swap, for two
/// measured reasons:
///
/// 1. **Seven lots exist only in volume-sources** — `64D171`, `67D317`, `67D333`, `68D393`,
///    `70D449` (RG 306, USIA), `74D267`, `78D26` (RG 59). Replacing rather than layering
///    would lose 2 documents and 7 front-matter nodes to gain 733 and 98.
/// 2. **Central-files has no record-group map at all.** `VolumeSourcesIndex.resolution`'s
///    second branch answers every *lot-less* node from volume-sources' 31 record-group
///    headers, and that branch carries **14,187 document rows and 6,373 front-matter nodes**
///    — twenty times the lot path's gain. This type never touches it.
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
/// either. Measured on the shipped bundles both guards currently refuse **nothing** (all 971
/// central-files entries are `series`-level and unflagged; all 758 volume-sources lots are
/// `series` or unlevelled) — they are dormant, not dead, and a re-harvest can re-arm them.
///
/// Version history:
///   1.0 — Session 2026-08-05: #372 / N-5 PR 1 (the repoint)
enum ArchivalResolver {

    /// The resolution for a **volume front-matter Sources node**: its lot, else its
    /// record-group header.
    ///
    /// The record-group branch belongs here and only here. A front-matter node *is* a
    /// collection — "General Records of the Department of State" is a fair answer to a row
    /// that names nothing more specific — and this is the surface volume-sources' 31 headers
    /// were harvested from in the first place.
    ///
    /// - Parameters:
    ///   - recordGroup: The node's record group. `volume_sources` stores these bare (measured:
    ///     0 of 7,374 rows carry the parser's `"RG-"` prefix), which is the form the map is
    ///     keyed by; `bareRG` normalizes anyway so the entry point cannot be form-sensitive.
    ///   - lotFile: The raw lot citation (`"63 D 135"`, `"Lot 61–D 146"`); normalized by the
    ///     indexes themselves.
    ///   - centralFiles: The central-files index. Injected so tests drive the real precedence.
    ///   - volumeSources: The volume-sources index, supplying both the lot fallback and the
    ///     record-group branch.
    static func frontMatterResolution(recordGroup: String?,
                                      lotFile: String?,
                                      entryText: String,
                                      centralFiles: CentralFilesIndex?,
                                      volumeSources: VolumeSourcesIndex?) -> ArchivalResolution? {
        if let lotHit = lotResolution(lotFile, centralFiles, volumeSources) { return lotHit }
        guard (lotFile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty else {
            return nil   // the lot-only rule
        }
        // The row must NAME the record group, not merely sit under one. `volume_sources`
        // stores the inherited value on every descendant, so without this a descriptive line
        // like "Reference works, visual materials, transcripts of oral histories…" borrows its
        // ancestor's link — and where the ancestor is the wrong record group, so is the link.
        guard let named = CollectionKeying.recordGroupNamedIn(entryText),
              let stored = CollectionKeying.bareRG(recordGroup),
              CollectionKeying.bareRG(named) == stored
        else { return nil }
        return volumeSources?.resolution(recordGroup: stored, lotFile: nil)
    }

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
                                   volumeSources: VolumeSourcesIndex?) -> ArchivalResolution? {
        lotResolution(lotFile, centralFiles, volumeSources)
    }

    /// Central-files first, volume-sources second — the shared lot half of both entry points.
    private static func lotResolution(_ lotFile: String?,
                                      _ centralFiles: CentralFilesIndex?,
                                      _ volumeSources: VolumeSourcesIndex?) -> ArchivalResolution? {
        let lot = lotFile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !lot.isEmpty else { return nil }
        if let entry = centralFiles?.lotFile(forRawLot: lot) {
            return ArchivalResolution(lotFileEntry: entry)
        }
        // `recordGroup: nil` on purpose — see the note on the lot-only rule above.
        return volumeSources?.resolution(recordGroup: nil, lotFile: lot)
    }

    /// ``frontMatterResolution(recordGroup:lotFile:centralFiles:volumeSources:)`` against the
    /// app's bundled indexes.
    static func frontMatterResolution(recordGroup: String?, lotFile: String?,
                                      entryText: String) -> ArchivalResolution? {
        frontMatterResolution(recordGroup: recordGroup, lotFile: lotFile, entryText: entryText,
                              centralFiles: CentralFilesIndexStore.shared,
                              volumeSources: VolumeSourcesIndexStore.shared)
    }

    /// ``documentResolution(lotFile:centralFiles:volumeSources:)`` against the app's bundled
    /// indexes.
    static func documentResolution(lotFile: String?) -> ArchivalResolution? {
        documentResolution(lotFile: lotFile,
                           centralFiles: CentralFilesIndexStore.shared,
                           volumeSources: VolumeSourcesIndexStore.shared)
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
