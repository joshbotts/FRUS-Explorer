// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation

/// The per-row provenance rules the two Source Explorer twins share (P-1).
///
/// ## Why a namespace, and not a property on either view
/// PV-3 badged the Source Explorer sections that are uniformly one tier. It deliberately left three
/// alone because their tier is decided **per row**, where a section chip would be wrong. This is
/// where those decisions live, so that the rule is written once and both twins call it.
///
/// The twins are hand-maintained copies that drift, and a rule written into each render block is
/// two rules. `SourceExplorerView.showsPartLabels` is the cautionary precedent: its own doc comment
/// claims to be "one property rather than the same condition written into each twin's render
/// block", and it is declared twice. The seams that actually hold across these twins are the
/// value-typed ones declared once.
///
/// ## Why these are free functions over values, not lookups
/// Both take what the caller already has in scope and return a `ProvenanceSource`. Neither reaches
/// for a store, so both are testable without a bundle and without a view host — the rules get real
/// runtime tests, and only the *mounting* needs a source scan.
///
/// Neither may route through `BundledArtifactProvenance.source(ofArtifact:)`. PV-3's rule is that a
/// mount **names its source**: the artifact a value happened to be read out of is not the same
/// question as where the claim came from, and `ProvenanceMountTests` pins the prohibition.
///
/// Version history:
///   1.0 — P-1: initial implementation
///   1.1 — Session 2026-10-09: #1589 — `lotCards(for:note:claimants:centralFiles:curated:)`, the
///          keyless lot cards a note shows, read once for both twins. The exception to "not
///          lookups" above: it is handed the three bundled indexes as values, and reads no store
enum SourceExplorerProvenance {

    /// Which producer answered for a lot file's **Record Group** row.
    ///
    /// Two producers reach this row and the view collapses them with `??`:
    ///
    /// - `SourceNoteParser.lotFileRecordGroup(_:)` is a pure rule over the printed lot string —
    ///   `RG-84` for an F-designator, `RG-59` otherwise. It reads the volumes and nothing else, so
    ///   its answer is `.frusText`.
    /// - `CuratedLotResolutionsStore.recordGroup(forRawLot:)` is the owner's archival judgement
    ///   against NARA's catalogue, so its answer is `.naraCatalog`.
    ///
    /// **The branch must key on which lookup answered, never on the value.** Measured over the
    /// shipped `curated-lot-resolutions.json`: all 20 curated lots resolve to a record group, and
    /// **19 of the 20 are byte-identical to the string the parser would have produced** — only
    /// `M88` differs (`RG-43` against the parser's `RG-59`). A value comparison would therefore
    /// call 19 of 20 curated rows uncurated, and the one row it got right would make it look
    /// correct.
    ///
    /// - Parameter curated: exactly what `CuratedLotResolutionsStore.shared?
    ///   .recordGroup(forRawLot:)` returned — **the curated answer under its own name, not the
    ///   value after `??`**. Passing the merged value makes every lot read `.naraCatalog`.
    /// - Returns: `.naraCatalog` when curation answered, `.frusText` otherwise.
    static func lotRecordGroupSource(curated: String?) -> ProvenanceSource {
        curated == nil ? .frusText : .naraCatalog
    }

    /// Where an unprinted pointer's archival unit came from.
    ///
    /// `ExternalCitation.anchor` is a `String`, not an enum: `"lotFile"` and `"presidentialLibrary"`
    /// are written from `FootnoteArchivalCitation.Anchor.rawValue`, while `"centralFileClass"` is a
    /// string literal typed at the two index-time sites that emit it — so a `switch` over the enum
    /// would compile, be exhaustive, and never see the class channel. The comparison is therefore
    /// on the string, and the default arm is `.frusText`.
    ///
    /// **Why a class pointer is `.stateDeptSchedule` and not `.frusText`.** The class *number* is
    /// read from FRUS's own footnote, so a first reading says `.frusText`. But whether the row
    /// exists at all was decided by composing that number against the State Department's published
    /// classification schedule: `IndexingPipeline` admits a class candidate only when
    /// `DecimalClassLabelStore` composes it, so a number the schedule could not match is absent
    /// rather than wrong. The reader is looking at a claim the schedule gated. That gate runs at
    /// **index** time, which is why the render site needs nothing from `decimal-class-labels.json`.
    ///
    /// A lot or library pointer is gated by nothing — the footnote named it and the app stored it —
    /// so those stay `.frusText`.
    ///
    /// - Parameter citation: the stored citation behind the row.
    /// - Returns: `.stateDeptSchedule` for a central-file-class pointer, `.frusText` otherwise.
    static func unprintedPointerSource(for citation: ExternalCitation) -> ProvenanceSource {
        citation.anchor == "centralFileClass" ? .stateDeptSchedule : .frusText
    }

    // MARK: - Lot cards (#1589)

    /// The keyless lot cards one source note shows: what the bundled indexes answer for the lot
    /// it cites, with no NARA Catalog API key.
    struct LotCards: Equatable {

        /// What the bundle holds for the lot.
        enum Bundled: Equatable {
            /// NARA divided the lot across several series: all of them, as the `.candidates`
            /// outcome the twins already draw. It takes the place of the one-series card, which
            /// would assert a choice the data does not support (#675).
            case divided(CuratedLotOutcome)
            /// The lot's one series, from `central-files-index.json`.
            case single(LotFileEntry)
        }

        /// The lot as the note prints it.
        let rawLot: String
        /// The bundle's answer, or `nil` when it holds none the note may show.
        let bundled: Bundled?
        /// The hand-curated outcome for a lot NARA's catalogue does not resolve by control number
        /// (#375), drawn after `bundled`.
        let curated: CuratedLotOutcome?
    }

    /// The lot cards `parsed` shows, or `nil` when it shows none.
    ///
    /// **A note's parse case records how it was worded, not what it cites.** `S/S Files: Lot 80 D
    /// 212` is `.lotFile`; `National Archives, RG 59, …, Lot 80D212` is `.naraCollection` with the
    /// lot attached. Until #1589 both twins drew these cards for `.lotFile` alone, so a reader with
    /// no API key was shown "NARA Catalog API Key Required" for a lot the bundle answers. Every
    /// other surface already read both cases as one citation (the keyed query, the
    /// related-documents line, the Unprinted Material marker, `CollectionKeying.identity`, the
    /// stored `lot_file`).
    ///
    /// **A lot cited through the National Archives is answered only under the record group the
    /// note names.** A lot-file citation names no record group of its own and is answered as it
    /// always was. A National Archives citation does, and some are notes led by another record
    /// group (RG 218, 273, 306, 330, 383, 84) whose State Department lot is named in a later
    /// remark or as another copy; a State Department lot card would be wrong there. So for
    /// `.naraCollection` the divided card needs a claimant series of the cited record group, the
    /// one-series card an entry of it, and a curated outcome a curated record group that is the
    /// cited one or none.
    ///
    /// Measured on 2026-10-09 by running this function over the stored note of every document in
    /// a full index: 807 notes are a National Archives collection carrying a lot. 719 get a card,
    /// in 67 volumes (621 the one-series card, 98 the divided one); 10 are refused by the record
    /// group; 78 cite a lot the bundle does not hold.
    ///
    /// **A Subject-Numeric citation shows none.** The iPhone and iPad twin gives such a note its
    /// own panel in place of this one (`provenanceSection(parsed:)`), and the Mac twin, which
    /// draws these cards beside its NARA box, is held to the same answer here.
    ///
    /// - Parameters:
    ///   - parsed: The document's parsed source note.
    ///   - note: Its text, for the Subject-Numeric reading.
    ///   - claimants: `LotClaimantsIndexStore.shared`.
    ///   - centralFiles: `CentralFilesIndexStore.shared`.
    ///   - curated: `CuratedLotResolutionsStore.shared`.
    static func lotCards(for parsed: ParsedSourceNote?, note: String,
                         claimants: LotClaimantsIndex?,
                         centralFiles: CentralFilesIndex?,
                         curated: CuratedLotResolutions?) -> LotCards? {
        let lot: String
        // The record group a National Archives citation names, as its number; `nil` for a
        // lot-file citation, which is answered whatever the lot's record group.
        let cited: String?
        switch parsed {
        case .lotFile(_, let number, _)?:
            lot = number
            cited = nil
        case .naraCollection(let recordGroup, _, let number?, _)?:
            guard let parsed,
                  CollectionKeying.centralFilesReading(parsed: parsed, note: note)?.form != .subjectNumeric
            else { return nil }
            lot = number
            cited = recordGroupNumber(recordGroup)
        default:
            return nil
        }
        func isCited(_ recordGroup: String?) -> Bool {
            guard let cited else { return true }
            return recordGroup.map(recordGroupNumber) == cited
        }

        let bundled: LotCards.Bundled?
        if let series = claimants?.claimants(forRawLot: lot),
           series.contains(where: { isCited($0.recordGroup) }),
           let divided = LotClaimantsIndex.candidatesOutcome(forRawLot: lot, in: claimants) {
            bundled = .divided(divided)
        } else if let entry = centralFiles?.lotFile(forRawLot: lot), isCited(entry.recordGroup) {
            bundled = .single(entry)
        } else {
            bundled = nil
        }
        // A curated lot with no record group of its own is answered under any.
        let curatedRecordGroup = curated?.recordGroup(forRawLot: lot)
        let outcome = (cited == nil || curatedRecordGroup == nil || isCited(curatedRecordGroup))
            ? curated?.outcome(forRawLot: lot) : nil
        guard bundled != nil || outcome != nil else { return nil }
        return LotCards(rawLot: lot, bundled: bundled, curated: outcome)
    }

    /// A record group as its number alone: `59` for `59`, `RG-59` and `RG 59`, the three forms the
    /// parser, the curated file and the bundled indexes write.
    static func recordGroupNumber(_ recordGroup: String) -> String {
        String(recordGroup.filter(\.isNumber).drop(while: { $0 == "0" }))
    }
}
