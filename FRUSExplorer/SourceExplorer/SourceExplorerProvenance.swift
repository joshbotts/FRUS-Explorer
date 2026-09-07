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
}
