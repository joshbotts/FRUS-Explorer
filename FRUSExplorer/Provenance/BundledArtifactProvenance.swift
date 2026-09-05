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

/// Where each bundled artifact's data came from, computed from the inputs its generator declares.
///
/// **The tier is derived, not assigned, and that is the load-bearing property of the whole wave.**
/// Every generator states its inputs in an `Env:` line in `CLAUDE.md` and reads them from its
/// runner; ``BundledArtifactProvenanceTests`` walks the generator sources and fails when a
/// generator gains a data input this table does not account for. A design where a human assigned
/// tiers by judgement would rot within two waves — this one cannot drift silently.
///
/// ## The rule
///
/// A derivation is **Tier 1** iff its transitive input closure is a subset of
/// {FRUS TEI, `manifest.json`, `administrations.json`} **and** the fields it actually reads were
/// untouched by any other source.
///
/// `administrations.json` is in that set by owner decision: it is a calendar of who held office on
/// which date, a public-record constant rather than a dataset that could disagree with FRUS. The
/// document data behind the administration profiles is entirely FRUS's own editorial
/// `frus:doc-dateTime` bounds.
///
/// ## Why the closure is per FIELD, not per file
///
/// The first draft of this wave's plan tiered `collection-authority.json` as a file — its closure
/// includes NARA's catalogue — and so labelled the whole archival-analytics family Tier 2. That is
/// **wrong**, and the measurement is unambiguous: `naId` and `catalogURL` appear **nowhere** under
/// `FRUSExplorer/Analytics/`, the generator touches the NARA resolver on exactly one line filling
/// exactly one field, and `AuthorityLookup` keys on `id`, `name`, `aliases` and `bySegment` — all
/// FRUS-derived. A per-file rule would have told a reader their largest analytics surface was
/// NARA-dependent when it never reads a NARA value, understating what they may claim. That is the
/// opposite of this wave's purpose and worse than saying nothing.
///
/// So rows carry ``Entry/readsOnlyFRUSFields``: the artifact is Tier 2 as a file, and the values
/// the app reads out of it are Tier 1.
///
/// Version history:
///   1.0 — PV-0: initial implementation
enum BundledArtifactProvenance {

    /// One artifact's provenance, and the declaration the test checks it against.
    struct Entry: Sendable {
        /// The generator's directory prefix, e.g. `"ResolvedEdgeIndex"` for
        /// `ResolvedEdgeIndexGeneratorCore`. The test walks that directory's sources.
        let generator: String
        /// The data inputs the generator reads. Config, output paths and cache directories are
        /// not data and are excluded — see ``BundledArtifactProvenance/dataInputs``.
        let declaredInputs: Set<String>
        /// What a reader may claim from this artifact's values.
        let source: ProvenanceSource
        /// Set when the artifact's *file* has a non-FRUS input but the *fields the app reads* do
        /// not — the §1a case. `source` then describes what the app reads, not what the file is.
        let readsOnlyFRUSFields: String?

        init(generator: String, inputs: Set<String>, source: ProvenanceSource,
             readsOnlyFRUSFields: String? = nil) {
            self.generator = generator
            self.declaredInputs = inputs
            self.source = source
            self.readsOnlyFRUSFields = readsOnlyFRUSFields
        }
    }

    /// The environment variables that name a DATA input, as opposed to an output path, a cache
    /// directory, a mode flag or a reproducibility stamp.
    ///
    /// The test extracts these names from generator sources, so a generator that starts reading a
    /// new one fails until this table accounts for it. Adding a name here without adding it to the
    /// rows that read it is therefore also a failure — which is the point.
    static let dataInputs: Set<String> = [
        "VOLUMES_DIR", "MANIFEST", "ADMINISTRATIONS",
        "CENTRAL_FILES_INDEX", "COLLECTION_AUTHORITY", "VOLUME_SOURCES_INDEX",
        "HARVEST_DIR", "CATALOG_API_KEY", "CURATED_LOTS", "CITATIONS_CSV",
        "DECIMAL_LABELS", "SCHEDULE_DIR",
        "DOCUMENT_SUBJECTS",
        "PEOPLE_DATA_DIR", "PERSONS_COMPLETE", "MERGE_AUDIT_CSV", "POCOM_DIR", "AUTHORITY_INDEX",
        "LEXICONS", "STOPWORDS", "STORE", "LAYOUT_DIR",
    ]

    /// The inputs that keep a derivation in Tier 1.
    static let frusOnlyInputs: Set<String> = ["VOLUMES_DIR", "MANIFEST", "ADMINISTRATIONS"]

    /// Every bundled artifact the app reads, by filename.
    ///
    /// Config payloads that carry no corpus data — `tei-rendering-config.json`,
    /// `word-cloud-lexicons.json`, `word-cloud-stopwords.json` — are absent on purpose: they
    /// cannot carry a claim into a footnote, so they have no provenance to state. They appear as
    /// *inputs* to the rows that use them.
    static let table: [String: Entry] = [
        // ── Tier 1: the volumes and nothing else ────────────────────────────────────────────
        "manifest.json": .init(
            generator: "Manifest", inputs: [], source: .frusText),
        "broken-refs-index.json": .init(
            generator: "CrossRefValidation", inputs: ["VOLUMES_DIR", "MANIFEST"], source: .frusText),
        "resolved-edge-index.json": .init(
            generator: "ResolvedEdgeIndex", inputs: ["VOLUMES_DIR", "MANIFEST"], source: .frusText),
        "source-provenance-index.json": .init(
            generator: "SourceProvenanceIndex", inputs: ["VOLUMES_DIR", "MANIFEST"], source: .frusText),
        "administration-profiles-index.json": .init(
            generator: "AdministrationProfilesIndex", inputs: ["VOLUMES_DIR", "ADMINISTRATIONS"],
            source: .frusText),

        // ── Tier 1 by FIELD, Tier 2 as a file — the §1a case ────────────────────────────────
        "collection-usage-index.json": .init(
            generator: "CollectionUsageIndex",
            inputs: ["VOLUMES_DIR", "MANIFEST", "COLLECTION_AUTHORITY"], source: .frusText,
            readsOnlyFRUSFields: "Counts FRUS documents into authority clusters keyed on identity, aliases and volume lists — all read from FRUS front matter. The authority's NARA identifiers are not read here."),
        "provenance-flow-index.json": .init(
            generator: "ProvenanceFlowIndex",
            inputs: ["VOLUMES_DIR", "MANIFEST", "COLLECTION_AUTHORITY"], source: .frusText,
            readsOnlyFRUSFields: "Edges between archival units named in FRUS's own cross-references; the units are authority clusters read by identity, never by NARA identifier."),

        // ── Tier 2: NARA's catalogue ────────────────────────────────────────────────────────
        "central-files-index.json": .init(
            generator: "CentralFilesIndex",
            inputs: ["HARVEST_DIR", "CATALOG_API_KEY", "CURATED_LOTS", "CITATIONS_CSV",
                     "VOLUME_SOURCES_INDEX", "COLLECTION_AUTHORITY"],
            source: .naraCatalog),
        "collection-authority.json": .init(
            generator: "CollectionAuthority",
            inputs: ["VOLUMES_DIR", "CENTRAL_FILES_INDEX", "VOLUME_SOURCES_INDEX"],
            source: .naraCatalog),
        "volume-sources-index.json": .init(
            generator: "VolumeSourcesIndex",
            inputs: ["VOLUMES_DIR", "CENTRAL_FILES_INDEX", "CATALOG_API_KEY"], source: .naraCatalog),
        "lot-claimants-index.json": .init(
            generator: "LotClaimantsIndex", inputs: ["HARVEST_DIR", "CENTRAL_FILES_INDEX"],
            source: .naraCatalog),
        "series-facts-index.json": .init(
            generator: "SeriesFactsIndex",
            inputs: ["HARVEST_DIR", "CENTRAL_FILES_INDEX", "VOLUME_SOURCES_INDEX"],
            source: .naraCatalog),
        "digitized-ranges-index.json": .init(
            generator: "DigitizedRangeIndex", inputs: ["HARVEST_DIR"], source: .naraCatalog),
        "roll-scans-index.json": .init(
            generator: "DigitizedRangeIndex", inputs: ["HARVEST_DIR"], source: .naraCatalog),
        "presidential-library-catalog.json": .init(
            generator: "PresidentialLibraryCatalog", inputs: ["CATALOG_API_KEY"], source: .naraCatalog),

        // ── Tier 2: the State Department's classification schedule ──────────────────────────
        "decimal-class-labels.json": .init(
            generator: "DecimalClassLabel", inputs: ["SCHEDULE_DIR"], source: .stateDeptSchedule),
        "external-citation-index.json": .init(
            generator: "ExternalCitationIndex",
            inputs: ["VOLUMES_DIR", "MANIFEST", "COLLECTION_AUTHORITY", "DECIMAL_LABELS"],
            source: .stateDeptSchedule),

        // ── Tier 2: the Office of the Historian's own datasets ──────────────────────────────
        "person-authority-index.json": .init(
            generator: "PersonAuthorityIndex",
            inputs: ["PEOPLE_DATA_DIR", "PERSONS_COMPLETE", "MERGE_AUDIT_CSV"],
            source: .ohPeopleRegister),
        "pocom-index.json": .init(
            generator: "POCOMIndex", inputs: ["POCOM_DIR", "AUTHORITY_INDEX"],
            source: .ohPeopleRegister),
        "document-subject-index.json": .init(
            generator: "DocumentSubjectIndex", inputs: ["DOCUMENT_SUBJECTS"], source: .ohSubjects),
        "volume-subject-profiles-index.json": .init(
            generator: "VolumeSubjectProfiles", inputs: ["DOCUMENT_SUBJECTS", "MANIFEST"],
            source: .ohSubjects),
        "volume-tag-taxonomy.json": .init(
            generator: "Taxonomy", inputs: [], source: .ohSubjects),

        // ── Tier 3: made here ───────────────────────────────────────────────────────────────
        "cloud-vectors-core.json": .init(
            generator: "CloudVectors", inputs: ["VOLUMES_DIR", "MANIFEST", "LEXICONS", "STOPWORDS"],
            source: .appWordLists),
        "cloud-vectors-volumes.json": .init(
            generator: "CloudVectors", inputs: ["VOLUMES_DIR", "MANIFEST", "LEXICONS", "STOPWORDS"],
            source: .appWordLists),
        "keyness-baseline.json": .init(
            generator: "CloudVectors", inputs: ["VOLUMES_DIR", "MANIFEST", "LEXICONS", "STOPWORDS"],
            source: .appWordLists),
        "semantic-vectors-index.json": .init(
            generator: "SemanticVectors",
            inputs: ["STORE", "MANIFEST", "LEXICONS", "STOPWORDS", "LAYOUT_DIR"], source: .appModel),
        "semantic-map-index.json": .init(
            generator: "SemanticVectors",
            inputs: ["STORE", "MANIFEST", "LEXICONS", "STOPWORDS", "LAYOUT_DIR"], source: .appModel),
    ]

    /// The artifacts whose archival identifiers include rows matched by hand (Q-3).
    ///
    /// `curated-lot-resolutions.json` folds into `central-files-index.json` at generation time and
    /// leaves no marker — every shipped lot carries `matchType: "control"` — so membership is
    /// checked at runtime against `CuratedLotResolutions`, which the app already loads.
    static let carriesCuratedResolutions: Set<String> = [
        "central-files-index.json", "collection-authority.json", "series-facts-index.json",
        "lot-claimants-index.json",
    ]

    /// What a reader may claim from an artifact's values, or `nil` when it is not in the table.
    static func source(ofArtifact filename: String) -> ProvenanceSource? {
        table[filename]?.source
    }
}
