# #335 — Source Explorer Corpus-Wide Audit

**Date:** 2026-07-17 · **Basis:** `SourceExplorerExportGenerator` run over the shippable corpus
(264,464 document source notes, 552 volumes; `Planning/source-explorer-export/`) · **Method:**
six analysis lenses over the full export, every candidate finding independently re-derived by an
adversarial verifier (34 raised → 34 verified, 7 with adjusted counts, 0 refuted). Counts below
are the *verified* numbers. One live NARA Catalog spot-check round (4 NAIDs) was the only
network access; everything else is the offline export.

---

## 1. Headline verdicts

**Accuracy (issue question 1 — do resolved records plausibly match the raw citations?):**
Series-level lot resolutions are **~93% plausible-or-better** (40-lot stratified sample: 29
plausible / 8 uncertain-generic / 3 implausible), and the 1906–1910 Numerical File path is
healthy (99.86% roll-hit rate, no year-gating hole). But the errors are **concentrated, not
diffuse**: the 16 fileUnit-level bundle entries are almost entirely wrong — headlined by lot
**60 D 627 (455 records, the corpus's 2nd-most-cited lot) resolving to an "Operation Mongoose /
Cuba – 1963" file unit**, confirmed wrong against the live catalog (the record carries zero
`variantControlNumbers`, so the bundle's `control` match claim is unsupported) — and 334
decimal-file citations are misrouted onto Numerical File rolls by a year-only gate. The two
concentrated defects account for ~789 records ≈ 6.5% of all strong (lot + numerical)
resolutions. The wrong 60D627 NAID has propagated into **all three** bundled indexes, which is
why intra-bundle agreement checks pass vacuously.

**Mitigation (issue question 2 — are the failures reasonable?):** Partially. ~47% of the
`unrecognized` residue is *correctly* unrecognized (editorial markers, bare despatch numbers,
prose). But the biggest unresolved buckets are not reasonable — they are head-heavy, tractable
gaps: the top-50 missed lots cover **78% of the lot gap** and every one already has an identity
cluster in the collection authority (only NAIDs are missing); **~20 curated NAIDs would flip
two-thirds of the 29k presidential-library bucket** to offline resolution; a **one-record**
RG-256 addition resolves all 1,547 Paris Peace citations; and the `namedFileSeries` strategy
dead-ends 4,986 records with *no route at all* despite 92% matching authority clusters by name.

**Documentation accuracy:** 71.6% of the whole corpus (189,345 records) "resolves" to one
constant record — the RG 59 record-group link (NAID 388). Honest, but record-group-grain: the
app must not claim it "found the citation in the catalog" for these. Two other claims need
correcting (§6).

---

## 2. The corpus at a glance

| Strategy | Records | Dominant outcome |
|---|---|---|
| centralDecimalFile | 193,675 (73.2%) | 189,345 → the constant RG-59 link; 2,783 numerical rolls; 1,547 RG-256 unresolved |
| presidentialLibrary | 29,093 (11.0%) | 29,092 live-route-only; **1** offline NAID (and it's wrong — §3.5) |
| lotFile | 14,487 (5.5%) | 8,710 lot-bundle; 5,776 missed (573 distinct lots) |
| naraCollection | 10,429 (3.9%) | 9,540 volume-sources; 719 lot-bundle |
| namedFileSeries | 4,986 (1.9%) | 100% noResolution, no route (by design — §5.1) |
| unrecognized | 4,231 (1.6%) | ~47% correctly terminal; ~44% recoverable (§4) |
| cfpfFile | 4,030 (1.5%) | 100% static guidance (D-reel deep links possible — §5.4) |
| intelligence / previouslyPublished / foreignArchive | 3,533 | noResolution (largely correct) |

---

## 3. Accuracy risks (ranked by affected records)

| # | Finding | Records | Fix |
|---|---|---|---|
| 3.1 | **fileUnit "control" matches are wrong-collection**: 60 D 627 → Operation Mongoose file unit (455); 4 more lots land on "DE 2 of 3"-style Disclosure-Act folders (23). All observed junk is in the 16 fileUnit-level entries; the 947 series-level entries look sane. | 488 | **App guards shipped #351** (§7a): central-files read guard + downstream render guards suppress the wrong NARA links across all three surfaces, offline & re-harvest-durable; `BundledLotResolver`/`PRUNE_FLAGGED_LOTS` reject fileUnit for future runs. **Remaining #352 (keyed):** post-validate that the hit's `variantControlNumbers` actually contain the queried lot (609235170's list is empty); re-resolve 60D627 to the real Conference Files family (cf. NAID 602875); regenerate volume-sources + collection-authority to purge the propagated NAID. |
| 3.2 | **Library-keyword-anywhere steals central-files notes**: `tryPresidentialLibrary` matches anywhere and runs before the central-files check, so a decimal-led note with a secondary "(Eisenhower Library…)" copy is classified presidentialLibrary; 379 records carry library="Department of State"; 230 lose decimalClass + the RG-59 resolution. | 456 | Parser: run `strippingParentheticals` before the library keyword scan (the FRC path's existing precedent), or check the decimal grammar first when the note leads with a central-files citation. |
| 3.3 | **Abstract prefixes absorbed into the library query**: mSupp abstract-style notes yield library fields like "…report. Top Secret. 5 pp. Eisenhower Library" → a 60–150-char junk q-string for the live query. | 367 | Parser: derive `library` from the keyword-bearing segment only (the 1961–63 `tryAbstractCitationTail` precedent doesn't cover the 1958–60 mSupp population). |
| 3.4 | **Decimal citations misrouted to Numerical rolls**: the (1906…1910) year-only gate lets 1910-dated decimal-class citations ("835.415A/97" → case 835) resolve to the wrong microfilm rolls. | 334 | A format check before the year gate (a `.` before the first `/` = decimal era, never Numerical); best placed in `CentralFilesIndex.caseNumber(fromFileNumber:)` so both platform call sites are covered. |
| 3.5 | **Secondary-citation lots override presidential-library sources**: notes leading "Source: <X> Library…" flip to lotFile via a lot in a secondary "A copy is also in…" clause; 163 present a State lot catalog record for a presidential-library document. | 229 | Parser: scope lot extraction to the primary source clause; a later lot is a copy location, never the strategy. |
| 3.6 | **One-series-per-lot flattening**: e.g. lot 84D241 → "Briefing Books of Cyrus R. Vance" for all 164 citing records, most of which cite non-briefing material accessioned into other series. | 164 | Bundle an array of series per lot; display the token-overlapping one, or "one of N series for Lot …". |
| 3.7 | **Repository-blind authority matching (canary)**: the corpus's *single* offline presidential-library NAID (frus1977-80v27/d137) is a false positive — the "Presidential Files" alias on lot:66D204 matched a Carter Library note. 27,632 library records alias-match clusters, so future NAID enrichment would mis-link at scale. | 1 (canary) | Domain-tag authority clusters (lot/rg vs presidential/manuscript) and refuse cross-domain matches — **before** any NAID seeding (§5.2). |
| 3.8 | **Non-NARA repositories routed to the NARA catalog**: LoC (1,060), NDU, CMH, NHC, universities — all get a catalog.archives.gov query that can only return wrong-repository noise. | ~1,502 | A manuscript-repository strategy with static finding-aid guidance (the `staticCFPFGuidance` pattern) instead of a NARA query. |
| 3.9 | **NARA-vs-FRUS attribution conflicts presented confidently** (2 sampled lots where NARA itself asserts the lot on a contradicting series) + generic unverifiable titles (20% of sample). | ~2 + tail | Render-time framing: when no content word of the resolved title appears in the citation, say "NARA lists Lot X as: …" instead of implying identity. |
| 3.10 | **Malformed Numerical roll titles** (reversed ranges, U+FFFD mojibake) surface in the UI. | 76 | Regenerate roll display titles from parsed caseStart/caseEnd. |

## 4. Parser improvements (from the `unrecognized` residue + strategy steals)

Actionable recovery ceiling ≈ **1,850 of 4,231** unrecognized records (44%); ~2,000 are
correctly terminal (editorial markers, bare despatch numbers, conference doc ids). The lot
ordering-bug probe was **clean** — zero unrecognized notes match the shared lot grammar.

| Fix | Records | Sketch |
|---|---|---|
| Decimal-family suffix gaps | 555 | en-dash/absent items, comma-name infixes, doubled "File No. No." (146 in frus1918Supp02), "F.W." prefixes, bracketed personnel names |
| NSC/agency repository leads | 578 | "Source: National Security Council, …" (Reagan/Nixon intelligence volumes) + NSA/DoD/Treasury leads → a repository-led strategy with a live route |
| Previously-published lead shapes | 339 | "Reprinted from…", "Executive Agreement Series No. N", etc. → `.previouslyPublished` (also fixes the SA-3a undercount: 527 → ~866) |
| Mid-note "obtained from the … Library" | 296 | the WWII-era idiom asserts actual provenance — safe exception to lead-gating |
| WNRC year-first FRC accessions | 111 | keep the parsed repository identity instead of the `guard let rg` drop |
| Old-style numeric lots ("Lot 122") | 45 | digits-only alternative, collision-guarded |
| Named-subfile decimal classes | **36,063** | not unrecognized but null `decimalClass` on "740.0011 European War 1939/…"-style notes — a leading-prefix match after the anchored one fails; recovers the class-leaf neighbor grain + per-class analytics |

## 5. Bundling & strategy opportunities (the mitigation gaps)

| # | Opportunity | Records | Cost |
|---|---|---|---|
| 5.1 | `namedFileSeries` live keyword route (the strategy currently dead-ends with **no route**; 92% of its records name authority-validated series) + personal-papers reroute (1,509) + a small seriesName→RG table (JCS→218, DoD→330, Army→319, SWNCC→353, embassy posts→84; ~939 records resolve through *already-bundled* RG NAIDs) + the txt-cluster→lot-cluster NAID bridge (946 candidates, 162 unambiguous) | 4,986 | small (route + tables) |
| 5.2 | **Presidential-library curated NAIDs**: 6 (library, collection) pairs cover ~19,300 records (Nixon/NSC 7,054; Johnson/NSF 3,874; Carter/NSA 3,553; Kennedy/NSF 1,977; Ford/NSA 1,452; Eisenhower/Whitman 1,372); ~20 entries ≈ 66% of the bucket. **Requires 3.7's domain-tagging first.** Also normalize neighbor-key variants ("NSF" vs "National Security Files"; "Dulles papers" vs "Dulles Papers"). | 29,092 | ~20 curated entries |
| 5.3 | **Top-50 missed lots** via the existing `CITATIONS_CSV` keyed pass (top-10 = 54% of the gap; 54D270 alone is 1,063 records, M-88 is 697). All 573 missed lots already have authority identity clusters — this is purely NAID resolution. Fold the volume-sources lot map into central-files at generation (the two layers are redundant: the fallback rescued exactly 2 records corpus-wide). | 4,498 of 5,776 | one keyed run (owner) |
| 5.4 | **CFPF D-reel deep links**: 1,361 D-reel ids dated ≤1979 are individually retrievable via AAD/catalog full text; tier the mitigation by reel shape + year instead of one static claim. | 1,361 | route logic |
| 5.5 | **RG-256** (Paris Peace): a single bundled record — the only non-RG-59 record group the decimal strategy emits. | 1,547 | one record |

## 6. Documentation-claim corrections

1. **The RG-59 constant** (189,345 records, 71.6% of corpus): offline "resolution" for decimal
   central files is a record-group-grain link. Manuals/UI must say so; a follow-up could bundle
   the ~23 series-level NAIDs under RG 59 keyed by era for series-grain links. *Framing note:*
   this `resolvedVolumeSources` outcome is the **export's diagnostic join** (the volume-sources
   RG map applied at document grain) — the app's decimal-note UI currently shows static
   finding-aid links and filing-manual PDFs (`centralFilesPeriodSection`), not NAID 388; so
   this row measures what the bundles *could* honestly claim, not what the app presently shows.
2. **"Central Decimal File" label vs subject-numeric contents**: 3,225 records in the bucket
   are 1963–73 POL/DEF/SOC subject-numeric citations; the SA-3 legend calls the category
   "pre-1963". Rename to "Central Files (decimal & subject-numeric)" or split the label.
3. **The pinned "prefixed central-files" quirk does not manifest in the corpus** (0 records;
   the 159 real prefixed shapes parse fine). The synthetic grammar edge remains pinned in the
   generator tests with a corrected note.
4. TEI errata worth reporting upstream (the #240 broken-refs precedent): doubled
   "File No. No." (146), "IO Flies:" (15), "Paris Peace Cont", slash-for-dot file numbers in
   frus1917Supp01v01, one empty "File No." (frus1912/d61).

## 7. Recommended sequence

1. **Bundle hygiene (do first — accuracy over coverage):** 3.1 fileUnit quarantine +
   post-validation; 3.7 domain tags; regenerate all three bundles (purges the poisoned NAID).
2. **Owner keyed run:** 5.3 top-50 lots (+ fold volume-sources lots in) — the largest
   real-resolution win per unit effort.
3. **Parser session:** 3.2/3.3/3.5 steals + §4 quick wins (decimal-family, File No. No.,
   previously-published, obtained-from) with the eval harness guarding regressions.
4. **Strategy/routing session:** 5.1 namedFileSeries routes + 5.4 CFPF tiers + 3.8
   manuscript-repository guidance + 3.4 numerical format gate.
5. **Curated NAIDs:** 5.2 presidential libraries (after 1's domain tags).
6. **Docs pass:** §6 corrections.

### 7a. #351 — bundle hygiene shipped (offline, no key)

Step 1's **app-side, re-harvest-durable half** landed in #351 (2026-07-17), fixing the
user-visible headline everywhere *without* regenerating the three bundles (that keyed
re-resolution is step 2 / #352):

- **central-files read guard** — `CentralFilesIndex.lotFile(forRawLot:)` now treats a
  `fileUnit`-level match as unresolved (joining the existing #321 `ancestryLacksRecordGroup`
  guard), so Source Explorer's own lot card routes 60 D 627 to live lookup instead of the
  "Operation Mongoose" file unit. `isFileUnitLevel` helper added.
- **downstream render guards (the propagated-NAID surfaces)** — the wrong 60 D 627 NAID
  (609235170) was baked into **14 `collection-authority` lot clusters** (incl. Conference
  Files, 39 volumes) and **18 `volume-sources` outline nodes**, which read their NAID directly
  rather than re-resolving. `CentralFilesIndex.untrustworthyNAIDs` / `isUntrustworthyNAID(_:)`
  exposes the fileUnit/flagged NAID set; `CollectionDetailView` (both platforms, via
  `CollectionDetailSheet`) withholds the NARA link when the record's NAID is in that set.
  `VolumeSourcesIndex.resolution(recordGroup:lotFile:)` withholds a `fileUnit`-level resolution
  **at the source** — the single choke point read by both the browser Sources row and the
  Collections "Sources & Archives" block, so no wrong NARA link reaches a durable PDF/DOCX/HTML
  export (adversarial-review Finding 1). Collection identity, citing-volume lists, and neighbors
  are unaffected — only the wrong NARA links are suppressed.
- **collection-authority domain guard** — `record(forParsed:)` (app + the `AuthorityLookup`
  export twin) now refuses a `.presidentialLibrary` note → `lot:` cluster cross-domain match
  (the 3.7 "Presidential Files" alias bridge onto `lot:66D204`).
- **generator hygiene for the future keyed run** — `BundledLotResolver.resolve` rejects
  `fileUnit` hits (so a re-harvest never re-propagates them to volume-sources /
  collection-authority); the central-files enrich pass now *reports* fileUnit resolutions; and
  the keyless `PRUNE_FLAGGED_LOTS` mode drops fileUnit alongside `ancestryLacksRecordGroup`.

**Still owed to step 2 (#352, keyed):** the *underlying* NAIDs in all three bundles are still
wrong in the data (only suppressed at render). The keyed top-50 re-resolution replaces them
with correct Conference-Files-family NAIDs and regenerates the bundles; once re-harvested, the
`untrustworthyNAIDs` set empties and the render guards become no-ops. Post-validation ("the
hit's `variantControlNumbers` actually contain the queried lot") remains a #352 generator task.

Two low-severity review findings are deferred to #352 (no live trigger measured, no headline
harm): (2) `record(forFrontMatterText:)` has no domain guard — a library-repository front-matter
row whose leading segment folds to "presidential file" *could* alias-bridge to `lot:66D204`, but
no such corpus row exists today and the bridged NAID is series-level, not the Mongoose link; add
a one-line repository-based guard during the #352 pass. (3) the offline export tool
(`SourceExplorerExportRunner`) mislabels a fileUnit lot miss as `notInBundle` and still embeds the
wrong NAIDs from `volume-sources.lots` — acceptable for a diagnostic that reflects raw bundle
state, but re-baseline it after the #352 regen so the accuracy table counts no wrong link as a
resolution.

## 8. Baseline recommendation

**Re-run the export after steps 1–3 and adopt it as the new citations baseline, replacing
`citations2.csv` for Source Explorer purposes.** The export strictly supersedes the CSV's
source-note rows (raw string + parse + strategy + resolution vs raw string alone), is
deterministic and regenerable in ~1 minute, and its summary gives the honest per-strategy
resolution-rate table the manuals should quote. Keep `citations2.csv` as the OH-side raw
extraction of record (it also carries footnote/front-matter rows the export deliberately
excludes); pin each export baseline by its `generated` stamp + summary in
`Planning/source-explorer-export/`. The `SourceNoteEvalGenerator` regression harness remains
the parser-grammar gate; this export adds the resolution-accuracy dimension it lacked.
