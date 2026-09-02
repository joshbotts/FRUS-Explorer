# New Volume Release — the ingestion plan

**Status:** live plan, written 2026-09-01 against the tree at `6d6aeb5` (after build 44).
Written in advance of the Office of the Historian's next release, which they intend before the
end of 2026. Every claim below about the current tree was verified by reading the code named
beside it; every number carried over from a shipped artifact is cited to `CLAUDE.md` or to the
artifact's own provenance block and is marked where it is an estimate rather than a measurement.

**What this document is for.** When OH publishes a volume, the work is not "add a row to the
manifest". It is a **release**: 36 bundled data resources, 47 MB of them, of which 18 are
derived from the corpus and rebuilt every release; one owner-run neural harvest on a second machine;
one Python layout stage; a shard published to a *different repository*; a set of artifact-pinned
tests that will fail by design; and ten strings of user-visible copy that hard-code `552`, nine of
which become false the day the 553rd volume ships. This plan enumerates all of it, in the order it has to happen, with the
traps found by reading the code rather than by assuming.

---

## 1. The fact that shapes everything: this needs an app release

**A newly published volume is invisible in the app until a new build ships.** Not degraded —
invisible.

`ManifestStore.fetchLiveManifest()` does fetch the live GitHub listing at launch and does diff it
against the bundled manifest, producing three buckets: `known`, `newlyAvailable`,
`noLongerPublished` (`FRUSExplorer/Models/Manifest/ManifestStore.swift:377`). The doc comment on
`newlyAvailable` says it is "Displayed with a 'newly available' badge in the Browser and download
views" (`ManifestStore.swift:24`) and the store's own header repeats it (`:79`).

**That claim is false in this tree.** `newlyAvailable` has exactly one consumer outside the file
that defines it — `ManifestStoreTests.swift:131`, which checks that its `id` equals its filename.
No view reads it. Every screen that lists volumes reads `diffResult?.known ?? bundledEntries`,
which is *bundled ∩ live* — the Browser (`BrowserViewModel`), both storage hubs
(`VolumesStorageHubView`, `MacVolumesStorageHub`), onboarding, custom scopes, background
summarisation, `DocumentView`. A volume that is live but not bundled is in none of those sets.

So on release day, before we ship anything:

| Route | Works? | Notes |
|---|---|---|
| In-app download of the new volume | **No** | Not in `known`; no surface reads `newlyAvailable`. |
| Side-load the XML by hand | **Yes** | `.fileImporter` in both hubs (`VolumesStorageHubView.swift:175`, `MacVolumesStorageHub.swift:184`); `LocalVolumeCatalog.entry(volumeId:url:sizeBytes:)` mints a full `.sideloaded` manifest entry from the volume's own `<teiHeader>` — title, dates, editors, tags, document count — and files it in the right subseries. It indexes, renders and searches. |
| Everything derived | **No** | Semantic vectors, word clouds, subject profiles, archival analytics, cross-reference edges: all keyed to bundled artifacts that do not know the volume exists. |

**Decision D-1 (owner, cheap, ~S):** whether to make `newlyAvailable` visible — a row in the
storage hubs that says "published since this app version; use Add Volumes to side-load, or update
the app" — so that the gap between OH's publication and our release is *explained* rather than
silently empty. This is one small view change and it is the only thing in this plan that helps a
reader on the day of publication rather than the day of our release. It is not free of risk: a
"newly available" row that offers no button is a support question, and one that offers a download
button would hand the reader a volume with no derived data at all, which is precisely the
degradation the rest of this plan exists to avoid.

---

## 2. The trigger, and the four upstream clocks

The corpus itself is one input. Three others move on their own schedules, and two of them
**routinely lag OH's volume publication**. Nothing in this plan can pull them forward.

| Input | Source | Consumed by | Lag risk |
|---|---|---|---|
| Volume TEI XML | `HistoryAtState/frus`, `volumes/` | everything | none — it *is* the trigger |
| Tag taxonomy | `https://history.state.gov/tags/all` (HTML, scraped by `TaxonomyFetcher`) | `volume-tag-taxonomy.json` | low; new tags usually land with the volume |
| Subject mappings | `frus-subject-taxonomy/exports/document_subjects.json` (OH public-domain hand-off; shipped drop is dated **2026-08-20**, md5 `7f2e7b1b…`) | `document-subject-index.json`, `volume-subject-profiles-index.json` | **high** — a separate export cycle |
| Person registry | `HistoryAtState/people` + `frus-name-authority` (`persons-complete.xml`, `merge_audit_report.csv`) | `person-authority-index.json` → `pocom-index.json` | **high** — separate repos, separately re-minted |

The NARA record-group harvest (4.5 GB at `HARVEST_DIR`, gitignored, one machine) is **not** on this
list: it describes the archives, not the corpus. It matters only in the narrow case in §6.

**Consequence.** The release can ship with a new volume that has full text, full search, full
semantic coverage and full archival analytics but **no subject tags and no person-authority
crosswalk**, because those two depend on drops we do not control. That is an acceptable, honest
partial state — both features degrade per-volume rather than globally — but it must be a decision,
not a discovery. See D-4.

---

## 3. The artifact inventory

36 bundled data resources. Classified by what a new volume does to them.

### Tier 1 — corpus-derived, must be regenerated (18 artifacts, 12 generator runs)

| Artifact | Generator | Notes / cost |
|---|---|---|
| `manifest.json` | `ManifestGenerator` (needs `GITHUB_TOKEN`) | The gate. Defines the shippable set for every generator below. Sorted by `volumeId` — see §5. |
| `volume-sources-index.json` | `VolumeSourcesIndexGenerator` | Corpus front-matter Sources + offline lot resolution against `central-files-index.json`. Needs `CATALOG_API_KEY` only if the new volume names lots the bundle cannot answer. |
| `collection-authority.json` (+ report) | `CollectionAuthorityGenerator -c release` | Re-clusters the whole cross-volume authority. **Ids can move** — #696's `president's `→`presidential ` fold once killed 28 collection ids covering 2,040 documents. Everything downstream must be rebuilt from the *new* authority, never from a stale export. |
| `collection-usage-index.json` | `CollectionUsageIndexGenerator -c release` | Reads the authority. 629 KB today. |
| `external-citation-index.json` | `ExternalCitationIndexGenerator -c release` | Reads the authority **and** `decimal-class-labels.json`. |
| `provenance-flow-index.json` | `ProvenanceFlowIndexGenerator -c release` | Reads the authority. |
| `resolved-edge-index.json` | `ResolvedEdgeIndexGenerator -c release` | **Changes for existing volumes too**: cross-volume citations *into* the new volume become resolvable, and the new volume's own outbound citations add inbound edges to documents in volumes already shipped. |
| `broken-refs-index.json` | `CrossRefValidationGenerator -c release`, then `cp Planning/cross-ref-validation/broken-refs-index.json FRUSExplorer/Resources/` | Same two-way effect: refs that were `unknownVolume` may now resolve. Do **not** point `OUTPUT_DIR` at `Resources` — that dumps the CSV and report into the bundle. |
| `source-provenance-index.json` | `SourceProvenanceIndexGenerator -c release` | Schema 2; per-volume table must gain a row or `supportsVolumeScope` degrades. |
| `administration-profiles-index.json` | `AdministrationProfilesIndexGenerator -c release` | `administrations.json` already runs through Trump-2, so no table edit is needed for any volume OH could plausibly publish. |
| `cloud-vectors-core.json`, `cloud-vectors-volumes.json`, `keyness-baseline.json` | `CloudVectorsGenerator -c release` | **One run, three files — regenerating one alone is a mistake the artifact tests catch.** ~50–60 min measured. |
| `semantic-vectors-index.json`, `semantic-vectors-binary.bin`, `semantic-shards-manifest.json`, `semantic-map.bin`, `semantic-map-index.json` | `SemanticVectorsGenerator -c release` | §4 and §5. The long pole. |

### Tier 2 — gated on an upstream drop we do not control (5)

`document-subject-index.json`, `volume-subject-profiles-index.json` (both from the OH subjects
export); `person-authority-index.json`, `pocom-index.json` (both from the people registry, and in
that order — `POCOMIndexGenerator` reads the authority index to decide what is worth bundling);
`volume-tag-taxonomy.json` (`TaxonomyGenerator`, scraping `history.state.gov/tags/all`).

The taxonomy is the mild case: it is cheap, it usually lands with the volume, and a missing tag
degrades to a tag the Browser cannot name rather than to a broken surface. The other four are the
ones that can hold up a feature for the new volume alone.

Regenerating the person authority **changes rollup outcomes for ~90 of 62,818 records**, so
`IndexingPipeline.currentPersonRollupVersion` (currently 9, `IndexingPipeline.swift:832`) must be
bumped in the same commit. That forces a one-time re-consolidation on every device.

### Tier 3 — NARA-derived; touch only if the new volume cites something new (9)

`central-files-index.json`, `lot-claimants-index.json`, `series-facts-index.json`,
`presidential-library-catalog.json`, `digitized-ranges-index.json`, `roll-scans-index.json`,
`curated-lot-resolutions.json`, `curated-library-resolutions.json`, `decimal-class-labels.json`.
See §6.

### Tier 4 — static; never (4 data files, plus the JS/CSS/text payloads)

`administrations.json`, `tei-rendering-config.json`, `word-cloud-lexicons.json`,
`word-cloud-stopwords.json` — plus `frus-highlights.js`, `frus-offset-engine.js`,
`frus-selection.js`, `frus-print.css` and `gemma-terms-of-use.txt`, which are not data at all. **Do not edit
`word-cloud-stopwords.json` or `word-cloud-lexicons.json` during a volume release**: their
SHA-256s are pinned by `BundledKeynessBaseline`, and an edit makes every keyness read report
`.configurationMismatch` until `CloudVectorsGenerator` runs again.

---

## 4. The semantic pipeline — the long pole, and the one step that can go quietly wrong

### 4.1 It is incremental, and that is the good news

`harvest_embeddings.py` skips every volume whose `head.json` exists. Harvesting one new volume is
therefore **on the order of a minute**, not the measured 6.1 h a full corpus run took (derived:
366 min ÷ 552 volumes ≈ 40 s for an average volume; a large modern volume is above average).

The packer refuses to paper over a gap: `SemanticVectorsRunner` throws
`RunError.volumeMissingFromStore` for any manifest volume with no store entry
(`SemanticVectorsRunner.swift:166`). So the manifest and the store must move together — you cannot
ship a 553-volume manifest against a 552-volume store.

### 4.2 THE HAZARD: an incremental harvest silently rewrites the store's contract

`harvest_embeddings.py:317–333` assembles `run-manifest.json` from **this invocation's
environment** and writes it unconditionally at the end of the run. There is no comparison against
the manifest already in the store.

The packer builds the family provenance digest from that file — model, GGUF SHA-256, dims,
`chunk_chars`, `overlap_chars`, `prefix`, pooling, quantization
(`SemanticVectorsRunner.swift:129–144`). Per volume it validates **only `model` and `dim`**
against each `head.json` (`SemanticRawStore.swift:230`). `prefix`, `chunk_chars` and
`overlap_chars` are never cross-checked per volume.

So a resumed harvest that forgets `PREFIX="title: none | text: "` (trailing space included):

1. embeds the new volume under a different contract — no error, no warning;
2. rewrites `run-manifest.json` with `prefix: ""`;
3. packs cleanly, with a **different provenance digest for the entire corpus**;
4. and every installed device hits `.provenanceMismatch` on its downloaded shards and re-fetches
   **all of them** — 162.3 MB — to get vectors that are now a mixture of two prompts.

Mitigation, and it is not optional:

- **Before the run:** `cp ~/frus-semantic-raw/run-manifest.json /tmp/run-manifest.before.json`
- **Run the exact Phase-3 command line** from `tools/semantic-harvest/README.md`, unchanged, with
  `MODEL`, `MODEL_FILE` and `PREFIX` all set. The GGUF file must still be on disk at the same path
  with the same SHA — the packer refuses a `model_file_sha256` that is not 64 hex, but it cannot
  tell you that you hashed a *different* file.
- **After the run:** diff the two. Only `generated`, `machine`, `models_listing`,
  `volumes_requested` and `totals_this_run` may differ. Anything else — **stop, do not pack.**
- **Then:** confirm the packed `semantic-vectors-index.json` carries `provenanceDigest`
  `a726ca606bdf4d1984ba7cfda4d5605c2e9dc1a8320654a1b5742e06aa6e3a64`, unchanged from the shipped
  artifact. A changed digest means a changed family and a 162 MB re-download for every user.

**Work item W-1 (S, high value):** teach the harvester to refuse a resume whose contract fields
differ from the store's existing `run-manifest.json`, or teach the packer to compare the digest
against a `--expect-digest` argument. Either turns a silent corpus-wide fault into an exit code.
Doing this *before* the release is cheaper than doing it after.

### 4.3 `DIMS=512` is not the default

The generator's own `DIMS` default is still **256**; the shipped artifacts are packed at **512**
since #933 / build 42. Pass `DIMS=512` or the bundle silently repacks at half its shipping width
and takes every consumer to `.provenanceMismatch`. (This is stated in `CLAUDE.md`; it is repeated
here because it is the same failure class as §4.2 and will be reached in the same sitting.)

### 4.4 The shards live in another repository

`SemanticShardFetcher.defaultBaseURL` is
`https://raw.githubusercontent.com/joshbotts/frus-semantic-vectors/main/shards`
(`SemanticShardFetcher.swift:52`). The new volume's `.vec` must be **pushed to that repo before
the app build reaches users**, or every device that downloads the volume gets an HTTP 404 on its
shard fetch. That repository is outside this one and outside this session's scope; it is an owner
step.

The 552 existing shards are unaffected: a repack is byte-identical (verified 2026-08-12 across all
three artifact kinds and all 552 shards), so their SHA-256s in `semantic-shards-manifest.json` do
not move and no device re-downloads anything.

### 4.5 The map: relayout, or the map goes dark

There is **no third option**, and this is the finding most likely to be assumed away.

`BundledSemanticMap.prepare()` passes `expectedDocumentCount: vectorIndex.documentCount` into the
map reader (`BundledSemanticMap.swift:94`), and `SemanticMapReader.init` throws
`malformedArtifact("map places N documents, the vectors have M")` on a mismatch
(`SemanticMapReader.swift:72`). Adding a volume changes the vector artifact's document count.
Therefore a stale `semantic-map.bin` is **refused cleanly** — no misplaced documents, no wrong
coordinates, but the whole Clusters/Map feature disables itself for everyone.

So the map must be rebuilt:

```
.cache/semantic-map-venv/bin/python tools/semantic-harvest/corpus-gates/pool_docs.py
.cache/semantic-map-venv/bin/python tools/semantic-map/build_layout.py
DIMS=512 LAYOUT_DIR=Planning/semantic-map swift run -c release SemanticVectorsGenerator
```

What that costs, from the measured 2026-08-12 run: PCA + UMAP 6.6 min + HDBSCAN 8.2 min ≈ **15 min
of compute**, and then the part that is not compute — **179 clusters get re-derived and re-labelled**.
`random_state` is pinned, so a rebuild over *identical* input reproduces itself; a rebuild over
input with one more volume does not. Cluster count, cluster membership, cluster ids and the c-TF-IDF
labels can all move. Every document on the map moves.

Three consequences worth deciding in advance:

- The label pass has a **known failure mode that passed review by eye**: the first artifact's
  labels were pronounced historically coherent and 168 of 179 were wrong, caught by a unit fixture
  rather than by reading them. Budget a real check of the new labels, not a glance.
- Anything a user has saved that names a cluster id is invalidated. (Verify before release
  whether any persisted state does — `ClustersBrowseView` and the map sheet are the surfaces to
  check.)
- **Ordering trap:** `pool_docs.py` orders volumes by `sorted(os.listdir(store/vectors))`
  (`pool_docs.py:58`) while the packer orders by manifest order (`ManifestWriter` sorts by
  `volumeId`). They agree only while the store and the manifest hold the same set. Harvest the new
  volume *and* refresh the manifest **before** pooling. If they disagree the packer catches it —
  `SemanticMapPacker` checks both the byte length and the document count
  (`SemanticMapPacker.swift:95,137`) — but it catches it at the end of a 15-minute Python stage.

---

## 5. The row-order hazard

`manifest.json` is sorted by `volumeId` (`ManifestWriter.swift:37`, "sorted for deterministic diffs
between releases"). A new volume therefore inserts **in the middle**, not at the end — `frus1977-80v28`
lands between `v27` and `frus1981-88v01`.

`SemanticVectorsRunner` accumulates `rowOffset` in manifest order (`:162`, `:197`), so every volume
after the insertion point gets a new corpus row index. Nothing is silently wrong — the bundled index
stores each volume's `rowOffset` and its run-length-encoded document ids, and identity is read from
those segments rather than derived from position (that design exists because the implicit
`d{ordinal+1}` keying mis-keys 15,097 documents) — but it does mean:

- `semantic-vectors-binary.bin` is rewritten end to end (19.52 MB in the bundle);
- `semantic-map.bin` must be rebuilt in the same order (§4.5);
- the per-volume `.vec` shards are **not** affected — they carry no row rows and no ids.

---

## 6. When the NARA chain has to move

Only if the new volume's source notes name archival units the bundle cannot resolve. Check first,
run second: after `VolumeSourcesIndexGenerator`, read its log for lots it could not answer, and
check the Source Explorer export summary for a rise in `notInBundle`.

If it does, the run order is non-negotiable and is documented at length in `CLAUDE.md`:

```
CATALOG_API_KEY=… swift run VolumeSourcesIndexGenerator        # resolve the new lots live
FOLD_VOLUME_SOURCES=1 swift run CentralFilesIndexGenerator     # absorb them into central-files
PRUNE_FLAGGED_LOTS=1 swift run CentralFilesIndexGenerator      # re-apply the #321 refusal
swift run -c release VolumeSourcesIndexGenerator               # re-derive; lotsToWrite should empty
swift run -c release CollectionAuthorityGenerator
swift run -c release CollectionUsageIndexGenerator
swift run -c release LotClaimantsIndexGenerator
swift run -c release SeriesFactsIndexGenerator
```

Two traps carried over from the last time this chain ran: `ArchivalResolverTests.lotMapsAreDisjoint`
fails while the two artifacts duplicate each other, which is why the re-derive step is in the list;
and a supplement that resolves a **divided lot** (five are known — 57D284, 61D233, 71D483, 76F44,
77F53) requires `LotClaimantsIndexGenerator` to run afterwards or Source Explorer renders a
confident single card where NARA names several series.

The 4.5 GB harvest at `HARVEST_DIR` is on one machine and gitignored. If the release is prepared
anywhere else, this whole tier is unavailable and the honest move is to ship the new volume with
its unresolved lots showing as unresolved, rather than to fabricate a resolution.

---

## 7. Code that becomes wrong, independent of any artifact

### 7.1 Ten strings of user-visible copy hard-code "552"

Nine of them become false. Each is a `String(localized:)` default value:

| File | Line | What it says |
|---|---|---|
| `Onboarding/OnboardingView.swift` | 509 | "552+ volumes · ≈ 3.3 GB" — **the only one that stays true**, and the model for fixing the rest |
| `Onboarding/IndexingEducationView.swift` | 734 | "All 552 volumes are now available as structured digital texts" |
| `Browser/SubjectIndexView.swift` | 262 | "Counts describe all 552 volumes" |
| `Theme/FRUSTheme.swift` | 279 | "Only 254 of the 552 volumes carry any of these references" |
| `SeriesAnalytics/AdministrationProfilesDashboard.swift` | 562 | "more than the series' 552 volumes" |
| `SeriesAnalytics/SeriesProductionDashboard.swift` | 316, 386 | "the 552 volumes this app catalogs"; "These charts cover the 552 volumes…" |
| `SeriesAnalytics/SourceProvenanceDashboard.swift` | 621 | "Coverage spans 522 of the 552 cataloged volumes" |
| `SeriesAnalytics/SeriesGeographyDashboard.swift` | 355 | "551 of the 552 cataloged volumes carry at least one place tag" |
| `SeriesAnalytics/TopCollectionsCard.swift` | 305 | "an index covering all 552 cataloged volumes… reaches 356 of them" |

Note the shape of the last four: they are not one number but a *ratio* measured against the corpus
(254/552, 522/552, 551/552, 356). Each has to be **re-measured from the regenerated artifact**, not
arithmetically bumped.

**Work item W-2 (M):** replace the literals with a value read from `ManifestStore.bundledEntries.count`
and from each artifact's own coverage block, so the next release does not repeat this. Several of
these strings already sit next to a `%lld` interpolation, so the pattern exists. Where a figure
genuinely cannot be derived at runtime, the "552+" idiom is the fallback.

### 7.2 The coverage-era table stops at 1992

`CollectionRelations.coverageEras` is a hardcoded 19-bucket table whose last span is
**(1989, 1992)** (`CollectionRelations.swift:196–200`). `eraIndex(forMidpointYear:)` **clamps** to
the last bucket rather than returning `nil` (`:223`), and `ArchivalEraBand.band(forMidpointYear:)`
inherits that clamp (`ArchivalAnalyticsAxes.swift:385`).

The clamp is deliberate and correct at the *low* end — eight volumes print retrospective annexes
reaching back to 1620 and dropping them would silently shrink counts a reader takes as complete.
At the high end it has never been exercised, because no volume covers past 1992.

**A first 1993+ volume would be silently filed under "1989–1992"** — in the collection timeline,
in the archival era bands, in every band-scoped ranking. No crash, no warning, a wrong label.

**Work item W-3 (S, conditional):** if and only if the release includes a volume whose coverage
midpoint exceeds 1992, extend `coverageEras` and the five `ArchivalEraBand.all` ranges together —
`ArchivalEraBandTests` pins that the bands tile the era axis exactly, which is the guard that makes
this safe to change. `administrations.json` needs nothing; it already runs through Trump-2.

### 7.3 New subseries

Subseries are derived from the volume id (`^\d{4}(-\d{2,4})?`) everywhere — `VolumeIDParser`,
`LocalVolumeCatalog.subseries(for:)`, `ManifestStore.frusSubseries(from:)`, which handles century
rollover (`1899-01` → 1901). A new subseries needs **no table edit**: the Browser groups
dynamically, `CloudVectorsGenerator` rolls up whatever subseries it finds (107 today), and the
semantic packer accumulates subseries centroids the same way (659 centroids = 552 volumes + 107
subseries; both counts move).

The only thing to verify by eye is the subseries **label and sort position** in the Browser for an
id shape the corpus has not carried before.

---

## 8. Tests: what will fail, and the rule

Regenerating the artifacts will fail a family of tests that pin corpus-scale numbers. This is the
suite working as designed — those assertions exist so that an artifact cannot change without a
human looking. Known examples:

| Test | Assertion |
|---|---|
| `VolumeCatalogueGroupingTests.swift:241` | `index.volumeTotals.count == 552` |
| `AdministrationProfilesDataTests.swift:417` | `index.volumesCovered == 552` |
| `AdministrationProfilesDataTests.swift:426–427` | Nixon `pointDocCount == 13611`, Ford `== 4333` |
| `ArchivalAnalyticsTests.swift:528` | `coverage.count == 552` — "every catalogued volume must carry a parseable span" |
| `ArchivalFlowsTests.swift:209–210` | `volumesWithEdges == 254`, `volumesScanned == 552` |
| `BundledKeynessBaselineTests.swift:46` | `volumeCount: 552, documentCount: 314_479` |
| `BrokenRefsIndexTests.swift:24` | `"seriesVolumeCount": 552` |
| `SubjectFacetScopeTests`, `SemanticMapSurfaceTests`, `VolumeSubjectProfilesTests`, `CollectionUsageIndexTests`, `SourceProvenanceDataTests`, … | narrative counts in doc comments and fixtures |

Find the rest mechanically, after regeneration, by running both suites:

```
swift test                                        # 33 generator/kit test targets
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17"
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -only-testing FRUSExplorerUITests/UIObstructionTests
```

The `FRUSExplorer` scheme builds **both** app modules, so a `#if os(macOS)` file's warnings and
failures surface in the "iOS" run. Strict-concurrency warnings need a **clean** build to appear at
all — an incremental one does not recompile the files that would warn.

**The rule, and it is the important part of this section: re-measure, never relax.** Replace
`== 552` with `== 553`, not with `>= 552`. Replace `13611` with the number the new artifact
actually states. A weakened assertion is a test that will not catch the next regeneration mistake,
and this codebase has already been bitten twice by artifacts that looked right — the c-TF-IDF
labels that were 168-of-179 wrong and read as coherent, and the `LotClaimantsIndexGenerator` run
that produced an empty artifact because `recordGroupNumber` decodes as `Int` in shards and `String`
in API responses.

There is **no CI in this repository** (no `.github/workflows`), so nothing runs these for us.

---

## 9. What it costs the user's device on first launch after the update

Several backfills are keyed to an artifact's `generated` stamp, so a regenerated artifact means a
one-time rebuild on every device, not just for the new volume:

| Trigger | Effect |
|---|---|
| `document-subject-index.json` `generated` or vocabulary digest changes | `applyDocumentSubjectsIfNeeded` wipes and repopulates `document_subjects` + `document_subject_refs` for every indexed volume (`IndexingPipeline.swift:6796`). Measured ~0.8 s for the bucket table alone; no reindex. |
| `broken-refs-index.json` `generated` changes | `applyBrokenRefsIndexIfNeeded` resets every `is_broken` flag and re-marks in one transaction (`:6944`). |
| `currentPersonRollupVersion` bumped | Full person-rollup re-consolidation; any surface holding a rollup id must re-resolve (`AppState.swift:913`). |
| Semantic provenance digest **unchanged** | Downloaded shards survive. **This is the outcome to protect** — see §4.2. |
| CloudKit | **Nothing.** No `@Model` and no stored property changes, so the #488 Production-deploy gate is not engaged. Confirm by running `CloudKitSchemaInventoryTests` — it fails the moment the mirrored set changes. |

Users who already have volumes downloaded get the new volume offered as a normal download; the
eager shard fetch rides along with it (`AppState.fetchSemanticShardIfNeeded`), ~294 KB against
~6 MB of XML.

---

## 10. The release runbook, in order

Steps marked **[owner]** cannot be done from this repository.

**Phase A — corpus and manifest**
1. `git pull` the corpus clone (`~/Development/frus`). Note both **new** volumes and **changed**
   ones (OH corrects published volumes; `VolumeUpdateChecker` exists for exactly that, and a
   corrected volume changes every artifact a new one does).
2. `GITHUB_TOKEN=… swift run ManifestGenerator`. Review the diff: entry count, and that no existing
   entry changed unexpectedly.
3. `swift run TaxonomyGenerator` — cheap; run it unless the new volume's tags are all already in
   `volume-tag-taxonomy.json`.

**Phase B — archival chain** (§6; skip past step 4 if the volume introduces no new lots)
4. `swift run VolumeSourcesIndexGenerator`, read the log for unresolved lots.
5. If needed, the eight-step chain in §6, in that exact order.
6. Otherwise: `CollectionAuthorityGenerator` → `CollectionUsageIndexGenerator`.

**Phase C — corpus analytics** (independent of each other; any order)
7. `ExternalCitationIndexGenerator`, `ProvenanceFlowIndexGenerator`, `ResolvedEdgeIndexGenerator`,
   `SourceProvenanceIndexGenerator`, `AdministrationProfilesIndexGenerator`.
8. `CrossRefValidationGenerator`, then copy **only** `broken-refs-index.json` into `Resources/`.
9. `CloudVectorsGenerator` (~50–60 min, writes three files).

**Phase D — semantic** (§4; the long pole)
10. **[owner]** Studio: LM Studio + the pinned gemma GGUF; snapshot `run-manifest.json`; run the
    exact Phase-3 command; diff the manifest; transfer and `shasum -c SHA256SUMS`.
11. `pool_docs.py` → `build_layout.py` → `DIMS=512 … SemanticVectorsGenerator`.
12. Verify the provenance digest is unchanged. Review the new cluster labels properly.
13. **[owner]** Push the new `.vec` shard(s) to `joshbotts/frus-semantic-vectors`, `main`,
    `shards/`. **Before** the app build ships.

**Phase E — gated extras** (ship without them if the drops have not landed; see D-4)
14. `DocumentSubjectIndexGenerator` + `VolumeSubjectProfilesGenerator`, if the OH export includes
    the new volume.
15. `PersonAuthorityIndexGenerator` → `POCOMIndexGenerator`, if the registry does; bump
    `currentPersonRollupVersion` in the same commit.

**Phase F — code, tests, release**
16. §7's copy fixes; §7.2 only if a 1993+ volume is in the release.
17. `swift test` and the `xcodebuild test` runs in §8; re-measure every failing pin.
18. Bump `CURRENT_PROJECT_VERSION` (44 → 45) **by editing `project.yml` and `project.pbxproj`
    directly — do not run `xcodegen generate`**. No new bundled resource names, so no enrollment is
    needed; if that ever changes, `xcodegen generate` must be followed by
    `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.
19. Update `Planning/Store-Listing-Draft.md` — it states 552 volumes in five places and 316,839
    documents as its Gate-B evidence (lines 44, 51, 88, 118–120, 149, 172–174, 198).
20. **[owner]** TestFlight, then `TEAM_ID=… ./Scripts/notarize.sh` for the Mac build.
21. Update `Planning/DEVELOPMENT-PLAN.md` with what actually happened, including anything this
    plan got wrong.

---

## 11. Decisions the owner has to make

| # | Decision | Why it matters |
|---|---|---|
| **D-1** | Surface `newlyAvailable`, or leave the publication-to-release gap silent? | §1. The only change that helps a reader before our build ships. |
| **D-2** | Rebuild the map, or accept the map going dark for a release? | §4.5. There is no third option; "leave the map alone" is not one of them. |
| **D-3** | Do W-1 (harvest-contract guard) before or after this release? | §4.2. Before is cheap; after is cheap only if the release went well. |
| **D-4** | Ship without subject tags / person crosswalk for the new volume if the upstream drops lag? | §2. Both degrade per-volume; the alternative is holding the release for repos we do not control. |
| **D-5** | Batch several volumes into one release, or ship each as it appears? | Every fixed cost in this plan — 50–60 min of cloud vectors, 15 min of layout, the label review, the test re-measurement, a TestFlight cycle — is **per release, not per volume**. Batching is strictly cheaper; the cost is that readers wait. |

---

## 12. Effort

Rough, and honest about which parts are guesses. Compute times are measured where `CLAUDE.md`
measured them; the human times are estimates.

| Phase | Compute | Human |
|---|---|---|
| A — manifest, taxonomy | minutes | ~30 min (diff review) |
| B — archival chain | minutes; hours if §6's full chain runs | 1–3 h |
| C — corpus analytics | ~1.5 h, mostly `CloudVectorsGenerator` | ~1 h (artifact diff review) |
| D — semantic | ~1 min harvest + ~15 min layout + ~14 s pack | 2–3 h **[owner-gated]** — machine setup, transfer, digest verification, cluster-label review |
| E — gated extras | minutes | ~1 h |
| F — code, tests, release | ~1 h of test runs | 3–5 h (test re-measurement is the bulk) |

**Call it a full working day of attention for a single-volume release, most of it review rather
than compute, plus an owner session on a second machine.** D-5 is where the leverage is.

### Minimum viable release, if the calendar collapses

Ship the manifest + the Tier-1 artifacts that are cheap and mechanical (Phases A, C, D) and
explicitly defer Phase B's NARA chain and Phase E. The new volume then reads, searches, appears in
every browse surface, has semantic vectors and a map placement, and shows **unresolved** for any
archival unit the bundle cannot answer — which is the app's existing, honest degradation, not a new
one. What must **not** be deferred: the semantic pack (or the volume is absent from search by
meaning and the map), the shard push (or its fetch 404s), and the map relayout (or the map goes
dark for everyone).

---

## 13. What this plan does not cover

- **Corrected volumes.** OH revises published volumes, and a correction changes every corpus-derived
  artifact exactly as a new volume does — but it also invalidates already-downloaded copies on
  device. `VolumeUpdateChecker` compares the live git blob SHA against the local file and surfaces
  updatable volumes in both storage hubs; whether a re-download should force a re-index, and what
  happens to a reader's notes and highlights anchored into a document whose text moved, is a real
  question this document does not answer. It deserves its own plan before the first correction
  lands in a release.
- **A volume that will not parse.** `LocalVolumeCatalog.entry` returns `nil` rather than inventing
  a title, and the volume goes unlisted. Fine for side-load; unexamined for the catalogue path.
- **The `newlyAvailable` doc-comment defect** is recorded here (§1) but not filed. It should be an
  issue whichever way D-1 goes: either the code grows a consumer or the comment stops claiming one.
- **Whether any persisted user state names a semantic cluster id.** §4.5 flags it; verifying it is
  a code read this document did not do.

---

*Document history*
*1.0 — 2026-09-01: written against `6d6aeb5`, ahead of OH's end-of-year release.*
