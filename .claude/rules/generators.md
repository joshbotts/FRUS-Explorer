---
paths:
  - "*Generator*/**"
  - "GeneratorKit/**"
  - "GeneratorKitTests/**"
  - "EarlyEraNERControl*/**"
  - "tools/**"
  - "FRUSExplorer/Resources/*.json"
  - "Planning/Generators-Runbook.md"
---

# Command-line tools: the index, and the rules that span entries

Claude Code loads this file when a session reads or edits a file its `paths` name. A session that
only runs a tool, and a lane's agent, read it first (`CLAUDE.md`, *Command-line tools*). Everything
below this paragraph was moved here from `CLAUDE.md`'s *Build & Test Commands* word for word on 2026-11-26.

Add a new tool's row here and its entry to `Planning/Generators-Runbook.md`. Claude Code reads only
the first 40,000 characters of a file like this one.

**Command-line tools: what exists, and where the detail is.** Every generator is a package target
run from the repo root (`swift run -c release <Name>`); a few corpus tools are stdlib-only Python
under `tools/`. Each one's entry in `Planning/Generators-Runbook.md` gives its inputs and
environment variables, the figures it last measured, when it refuses to write, and what must be
regenerated after it. **Read a tool's entry before you run it, edit it or quote a figure from its
artifact** (`grep -n '<ToolName>'` finds it; the entries are long because each rule in them was a
measured failure).

| Tool | Writes | Reads, beyond the corpus at `VOLUMES_DIR` |
|---|---|---|
| `ManifestGenerator` | `manifest.json` | GitHub TEI headers, or `VOLUMES_DIR=` for the offline overlay |
| `TaxonomyGenerator` | `volume-tag-taxonomy.json` | the HistoryAtState/tags repository, then history.state.gov; then the committed overlay beside the tool |
| `CentralFilesIndexGenerator` (four keyed modes, four offline ones) | `central-files-index.json` | NARA Catalog (`CATALOG_API_KEY`) or the record-group harvest |
| `VolumeSourcesIndexGenerator` | `volume-sources-index.json` | `central-files-index.json`; optionally the Catalog |
| `CollectionAuthorityGenerator` | `collection-authority.json` and its report | the two indexes above |
| `CollectionUsageIndexGenerator` | `collection-usage-index.json` | the authority, the manifest |
| `ProvenanceFlowIndexGenerator` | `provenance-flow-index.json` | the authority, the manifest |
| `ResolvedEdgeIndexGenerator` | `resolved-edge-index.json`, `cited-page-map.json` (one run writes both, from a full index it builds of the corpus through the kit's pipeline) | the manifest |
| `VolumeAnnotationsIndexGenerator` | `volume-annotations-index.json` (what each volume's editors annotated; regenerated with every index bump) | the manifest, `CORPUS_COMMIT` (required); a full index it builds through the kit's pipeline, or `INDEX_DB` |
| `ExternalCitationIndexGenerator` | `external-citation-index.json` | the authority, `decimal-class-labels.json` |
| `SourceProvenanceIndexGenerator` | `source-provenance-index.json` | the manifest |
| `AdministrationProfilesIndexGenerator` | `administration-profiles-index.json` | `administrations.json` |
| `CrossRefValidationGenerator` | `Planning/cross-ref-validation/`; copy `broken-refs-index.json` into Resources | the manifest |
| `CorpusStructureSweepGenerator` | `Planning/corpus-structure-sweep/` | `CORPUS_COMMIT` (required) |
| `tools/oh-report/build_oh_report.py` | `Planning/OH-Report-<date>/` | `CORPUS_COMMIT` (required), the cross-ref CSV |
| `SourceExplorerExportGenerator` | `Planning/source-explorer-export/` | the bundled indexes |
| `LotClaimantsIndexGenerator` | `lot-claimants-index.json` | the record-group harvest |
| `AccessionSeriesIndexGenerator` | `accession-series-index.json` | the record-group harvest |
| `SeriesFactsIndexGenerator` | `series-facts-index.json` | the record-group harvest |
| `DigitizedRangeIndexGenerator` | `digitized-ranges-index.json`, `roll-scans-index.json` | the record-group harvest only |
| `PresidentialLibraryCatalogGenerator` | `presidential-library-catalog.json` | NARA Catalog (`CATALOG_API_KEY`), or its cache with `PROJECT_ONLY=1` |
| `RecordGroupCatalogGenerator` | `Planning/nara-record-group-catalog/` | NARA's public S3 export; start with `PROBE=1` |
| `DecimalClassLabelGenerator` | `decimal-class-labels.json` | the Department's manuals in `SCHEDULE_DIR` |
| `SubjectNumericLabelGenerator` | `subject-numeric-labels.json` | the handbooks in `SCHEDULE_DIR`, the usage index, `decimal-class-labels.json` |
| `PersonAuthorityIndexGenerator` | `person-authority-index.json` | the people registry, `persons-complete.xml`, the merge audit; then the committed corrections and Wikidata snapshot beside the tool (`tools/person-authority-facts/` refreshes the snapshot) |
| `POCOMIndexGenerator` | `pocom-index.json` | the POCOM register; run it after `PersonAuthorityIndexGenerator` |
| `DocumentSubjectIndexGenerator` | `document-subject-index.json` | the corrected subject export only, no TEI |
| `VolumeSubjectProfilesGenerator` | `volume-subject-profiles-index.json` | the same export, the manifest |
| `SemanticVectorsGenerator` | `semantic-vectors-*`, the shards and their manifest, `semantic-map*` | the chunk-vector store, `tools/semantic-map/build_layout.py`'s layout |
| `CloudVectorsGenerator` | `cloud-vectors-core.json`, `cloud-vectors-volumes.json`, `keyness-baseline.json`, `keyness-baseline-printed.json` | the lexicon and stopword payloads |
| `EarlyEraNERControl`, `tools/semantic-harvest/*.py` | the #234 detector stores and scores | the R-0 text layer |

Rules that span entries:

- **A refreshed JSON under `FRUSExplorer/Resources/` owes `swift test` and the unit target**, since
  package suites read it from the repository. A new or renamed bundled resource also needs
  `xcodegen generate` and the scheme restore; a same-name refresh does not. A new bundled JSON
  also needs a row in `BundledArtifactProvenance.table`:
  `BundledArtifactProvenanceTests.everyArtifactIsTiered` fails without one, and a scoped run of a
  lane's own suites does not include it (#1608's missing row was found by review, not by a run).
- **Rebuilding `collection-authority.json` changes record ids**, so regenerate usage, flow and
  external citations after it. The central-files chain is `SUPPLEMENT_FROM_HARVEST` →
  `PRUNE_FLAGGED_LOTS` → `CollectionAuthorityGenerator` → `CollectionUsageIndexGenerator` →
  `LotClaimantsIndexGenerator` → `SeriesFactsIndexGenerator`.
- **A change to the country or class keys of `decimal-class-labels.json`** moves
  `external-citation-index.json`'s vocabulary digest: regenerate it in the same commit.
- **Files that come out of one run are committed together**: `CloudVectorsGenerator`'s four, and
  `SemanticVectorsGenerator`'s index, binary and shard manifest. Run the second with `EXPECT_DIGEST`
  set to the shipped family's digest.
- **A keyed NARA harvest spends a metered quota**: confirm the invocation first. A
  `CloudVectorsGenerator` run takes about 21 minutes on the M5 MacBook, and about 52 of processor
  time with `VERIFY_PRINTED_WALK=1` (measured 2026-10-12; a run was 50 to 60 on the Mac it was
  first timed on).
- **A regenerated `subject-numeric-labels.json` ships only when every label that changed has been
  read against the handbook's scan** (the owner's decision of 2026-10-11). `REVIEW_OUTPUT` gives
  each label's page and row, and the pull request lists each change old to new. The generator
  reproduces its table since #1644: it reads the PDFs' content streams and asks PDFKit nothing
  (one SHA-256 under macOS 27.0.1 and inside the iOS 26.5 and 27.0 runtimes), and it throws while
  a label holds the capture's `~`. The table moves no index: the grammar's own lists
  (`ParsedSourceNote.subjectNumericAreaWords` and `subjectNumericCategories`) are pinned to
  themselves, and a change to either is an index version. A `collection-usage-index.json` that
  counts differently owes a regeneration: `ShippedLabelTableTests`, a package suite, recounts the
  table's `coverage` block over the usage index in the repository and fails when a figure differs.
