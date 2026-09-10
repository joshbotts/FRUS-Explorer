# Release: FRUS 1981–1988, Volume XVI, South America

**Live record of the ingestion run.** Executes `New-Volume-Release-Plan.md` against OH's PR #460,
merged into the corpus clone as `13a56f8e5`. Started 2026-09-09. Every number below was read off a
regenerated artifact or a generator's own log, not carried over from the plan.

## What OH shipped

| Volume | Change | Lines |
|---|---|---|
| `frus1981-88v16` | **NEW** — 88 documents, 4 chapters, 491 source notes, 264 `<pb>`, 1.2 MB | +15,280 |
| `frus1914Supp` | correction — two `<ref target>` URLs in front-matter prose | 4 |
| `frus1981-88v05` | correction — three `<pb n>` bracketed, one `<pb>` moved within `d154` | 8 |

The volume is **partial by design**: OH's own commit says "release frus1981-88v16 with 4 chapters",
its `<date type="publication-date"/>` is **empty**, and so are both ISBN elements. It will grow.

---

## Part 1 — the two corrections: assessment

**They change no bundled artifact's content.** The only field either moves is `manifest.json`'s
`sizeBytes` (8157489 → 8157496 and 8158079 → 8158085), which matches the files on disk exactly.
Verified structurally rather than assumed, and the reason is the same twice:

- **A `<ref target>` is an attribute.** `FRUSASTNode.plainText`'s `.crossReference` arm returns only
  its children, every text extractor replaces a whole tag with a space, and `CrossRefKit`'s
  `RefClassification` returns `.external` for any `http(s)://` target without existence-checking it.
  Both spellings classified `.external` before and after, so `broken-refs-index.json` never saw them.
- **A `<pb>` contributes zero characters.** `plainText` returns `""` for it, `flatText` skips it with
  no separator, and `extractBodyText` ends in `.normalizedWhitespace`, which absorbs the joining
  space at both the old and the new position. Measured: the tag-stripped, whitespace-collapsed
  character stream is **identical on both sides of the merge** for the press-release div and for the
  `d154` window, and `d154`'s `<pb n>` multiset is unchanged at 679–688.

**No index-version bump.** `currentDateIndexVersion` stays **50**. No *parse output* changed; the
*input* did. `VolumeUpdateChecker` compares the git blob SHA, both volumes' SHAs moved, so both
surface under Keeping Current and taking one re-indexes that volume alone. A bump would re-index
every downloaded volume to rewrite two inert rows.

**What a reader sees: nothing, and that is correct.** `DocumentChangeBanner.line()` returns nil
unless `changed_at` is set, and `changed_at` is stamped only on a `content_hash` change —
`contentHash` covers header ⟂ dateline ⟂ sourceNote ⟂ bodyText, none of which moved. No highlight,
quotation, note, tag, collection entry or summary is disturbed. Page data is unmoved too:
`PageNumber.parse` strips enclosing brackets (its comment names this exact FRUS front-matter
convention) and the roman arm stores the integer, so the row is `("roman", 1, "1")` before and after;
the moved `pg_682` stays inside `d154`, so `page_ranges` and the citation page match are unchanged.

**Two consequences worth naming.**

1. **Do not use these two volumes to smoke-test build 46's correction banner.** The R-5 machinery is
   structurally blind to exactly the two shapes #460 corrects. A tester who sees no banner has not
   found a bug.
2. **A re-exported DOCX of `frus1981-88v05/d154` paginates about 27 lines later.**
   `DocxCollectionExporter` turns a block-level `.pageBreak` into a real `<w:br w:type="page"/>`;
   PDF and the reading view drop it. This is the one place the moved `<pb>` is visible.

**One stale doc comment — found by the assessment, and fixed in this branch.**
`ASTToRenderNodeConverter.swift` justified `isSpuriousAutolink`'s first clause by naming
`http://uwdc.library.wisc.edu/` as one of "thirty genuine bare-host links". Verified: that target now
occurs **zero** times across the 553 volumes — the string survives only as the ref's link *text* —
and the new target has a path, so clause 1 saves it outright and it is no longer one of the thirty.
The comment now says so. **Its counts (619 refs, 22 de-linked, 597 kept, thirty bare-host) are NOT
re-measured** — they are attributed to build 45's 552 volumes and flagged as stale, because
re-deriving them means replicating the shipped predicate's scope, and a Python proxy that tokenises
differently from the shipped code is how three earlier analyses in this repo went wrong.

---

## Part 2 — THE FINDING THAT CHANGES HOW THIS DIFF MUST BE READ

**The archival artifacts in this branch carry two changes, not one, and only one of them is v16.**

`collection-authority.json` and everything downstream were last stamped **2026-08-19**. `#1206`
(`e309cbde`, 2026-09-05, "Stop storing a secondary citation as the document's own lot file") and
`#1225` (`f0874a25`, "a fourth unguarded lot site") changed `SourceNoteParser` **after** that stamp
and were never followed by a regeneration. This release is the first run of those generators since,
so the diff contains the belated effect of #1206 alongside v16's addition.

The evidence is unambiguous. Eighteen collection ids disappear, and seventeen are lot files whose
authority record carries a bare `Lot 78 D 155`-shaped name with no descriptive title and no
repository — exactly the secondary-citation shape #1206 exists to stop storing, and nothing like the
fully-described records that survive (compare `lot:95D407`, which arrives with a name, three aliases,
a record group and a repository). Between them the eighteen carried **25 documents**, 1–3 apiece.

| Measure | Before | After | Attribution |
|---|---|---|---|
| notes scanned | 264,464 | 264,552 | **+88 = v16's 88 documents** |
| notes in a collection | 74,914 | 74,910 | v16 **+50**, #1206 **−54** |
| collections reached | 1,839 | 1,833 | 18 lost to #1206, 12 gained (v16 + re-clustering) |
| authority collections | 4,429 | 4,432 | +8 v16, −5 #1206 (all five had 0 volumes) |
| class keys | 10,446 | 10,446 | v16 cites **no** central-file class |

**Nothing was orphaned:** every id that vanished from the authority also vanished from the usage
index, because both were rebuilt in the required order. One gain is a real improvement rather than a
loss — `txt:|robert h. lilac file` (4 documents, no repository) is replaced by
`txt:reagan library|robert h. lilac file`, because v16's front matter supplied the attribution.

**Review these artifacts as a #1206 change.** Reading them as v16's doing would credit a new volume
with removing seventeen lot files.

---

## Part 3 — runbook status

### Phase A — corpus and manifest ✅
1. ✅ Corpus pulled by the owner (`13a56f8e5`).
2. ✅ `ManifestGenerator` — **552 → 553**. Reviewed: one entry added, and the only change to an
   existing entry is `sizeBytes` on the two corrected volumes. Nothing else moved.
3. ✅ `TaxonomyGenerator` — **byte-identical**. v16 carries no tags, so there is nothing to add.

**Two properties of the new entry, both precedented but worth knowing:**
- **No `publicationDate`** — v16 is the only volume of 553 without one. `TEIHeaderParser` maps an
  empty element to nil and has a test for it. Downstream, `SupportingViews` renders **"n.d."**, which
  is honest. But `CitationFormatter` falls to `firstYear(...) ?? 0` and `publisher(forYear: 0)`
  resolves to **"Government Printing Office"** — the pre-2014 name, wrong for a 2026 volume. There is
  a designed escape (`overridingPublicationYear(_:)`, taking the year live from the TEI `@when`) but
  v16's publication-date element carries no `@when` either. **Owner decision needed** — see below.
- **No tags** — v16 joins `frus1981-88v04`, which has shipped tagless. No new behaviour.

### Phase B — archival chain ✅ (with one unresolved lot)
4. ✅ `VolumeSourcesIndexGenerator` — 259/694 volumes with front-matter sources (was 258);
   majorCollections 3,412 → 3,418; `lots: {}` as expected; record groups preserved at 31 (keyless run
   cannot re-derive them, and the generator refuses to write an empty map rather than silently
   dropping them — it did refuse once, correctly, before the existing artifact was seeded).
5. ✅ **§6's NARA chain RAN, with the owner's `CATALOG_API_KEY` — and `95D407` did not resolve.**
   NARA answered five *other* lots and all 36 record groups, but not the one v16 introduced. That is
   a property of the catalogue rather than of the key: the keyed route asks for the CITED spelling,
   and NARA indexes many State lots only expanded (`80D135` is held solely as `1980D0135`). v16
   therefore ships with one archival unit unresolved, which is §6's own stated default — `lot:95D407`
   still gets a collection record, so it browses and groups; it simply has no NARA series behind it.

   **What the keyed run did buy**, none of it related to v16 and all of it carried in this PR at the
   owner's direction:
   - **5 lot files resolved**: `53D211`, `53D403`, `57D618`, `58D78`, `64D148` — all RG 59, all with
     catalog URLs. `central-files-index.json` 1,065 → **1,070**.
   - **Record groups 31 → 36.** Every offline run could only carry forward the 31 already resolved;
     the keyed pass re-derived all 36, newly answering RG **51** (OMB), **80** (Navy), **107**
     (Secretary of War), **353** (Interdepartmental Committees) and **457** (NSA/CSS).
   - `series-facts-index.json` **695 → 698** creators / 397 → 398 headings, because those five lots
     reach three more series NAIDs.

   The eight-step chain ran in its documented order and the re-derive emptied `lots` back to `{}`,
   so `ArchivalResolverTests.lotMapsAreDisjoint` holds. `lot-claimants-index.json` is unchanged at
   123 divided lots — none of the five is divided.

   **`collection-authority.json`, `collection-usage-index.json` and `lot-claimants-index.json` came
   back identical apart from their `generated` stamp**, so they were reverted rather than committed:
   an artifact diff is this project's review surface and a date-only entry in it carries nothing.
   That also settles the downstream question — with the authority unmoved, `external-citation-index`
   and `provenance-flow-index` cannot move either, and were not re-run.

*(Superseded — kept for the record: §6's chain was originally deferred because no key was available
here, and the offline route was exhausted.)*
   ⚠️ **The offline route remains exhausted for `95D407`.** v16 introduces six archival units the
   bundle has not seen: four CIA job numbers, the George H.W. Bush Library as a repository, and one
   **lot file, `95D407`** (Bureau of Inter-American Affairs, Assistant Secretary…), which
   `central-files-index.json` cannot answer.
   - The keyed route needs `CATALOG_API_KEY` — **owner-held**.
   - The offline route was tried and is exhausted: `SUPPLEMENT_FROM_HARVEST=1` scanned **751,880
     records** of the 4.5 GB harvest and admitted **nothing** — all 678 wanted lots, `95D407` among
     them, have no candidate. That is a property of NARA's catalogue, not of the rule.
   - **Shipping it unresolved is the plan's own answer** (§6: "the honest move is to ship the new
     volume with its unresolved lots showing as unresolved"). `lot:95D407` still gets a collection
     record, so it browses and groups; it simply has no NARA series behind it.
6. ✅ `CollectionAuthorityGenerator` → `CollectionUsageIndexGenerator`, in that order. Figures in
   Part 2.

### Phase C — corpus analytics 🟡
7. ✅ `ExternalCitationIndexGenerator` — 553 scanned, 441 with references (was 440); pairs 3,054 →
   3,076; targets 1,000 → 1,006. Decimal class references stay **31,259**, matching #1256 — v16 is a
   subject-numeric-era volume and cites no decimal class.
   ✅ `SourceProvenanceIndexGenerator` — volumesCovered 522 → 523; notes 268,757 → **269,248**
   (+491, exactly v16's source-note count).
   ✅ `AdministrationProfilesIndexGenerator` — 552 → 553 volumes; point-dated +83, range-dated +5
   (= v16's 88 documents); reconciles.
   ✅ `ProvenanceFlowIndexGenerator` — 553 volumes; document-to-document edges unchanged at 77,792
   from 254 volumes, because **v16 uses no `dN` cross-reference idiom**. Its collection figures fall
   (48,829 → 48,622 joined) for the #1206 reason, not for a v16 reason.
   ✅ `ResolvedEdgeIndexGenerator` — **payload byte-identical**; only `coverage.referencesScanned`
   (+411) and `volumesScanned` (552 → 553) move. A newly published volume is not yet cited by others.
8. ✅ `CrossRefValidationGenerator` — **v16 introduces zero broken cross-references**. The bundled
   index's `records` are unchanged (213 keys / 652 occurrences); only `generated` and
   `seriesVolumeCount` (552 → 553) move.
   **A real gain, easy to miss:** `frus1981-88v16` has left the non-shippable list. Cross-references
   from other volumes into v16 previously resolved in-corpus but pointed outside the app's manifest;
   they now reach a volume the reader can open.
   *Cost to weigh:* `applyBrokenRefsIndexIfNeeded` gates on the `generated` stamp alone, with no
   digest, so shipping this re-runs the whole `is_broken` backfill on every device to rewrite
   identical flags. Installed on the grounds that the coverage count should be truthful; trivially
   revertible if you would rather not pay it.
9. ✅ `CloudVectorsGenerator` — all three files from one `pack()` call, ~35 min. volumeCount
   552 → 553, documentCount 314,479 → **314,567** (+88), volume scopes +1, vocabulary +8 terms. The
   lexicon and stopword SHA pins are unchanged, so `BundledKeynessBaseline` will not report
   `.configurationMismatch`.

### Tests after Phases A–C
- **iOS suite: 4,623 tests / 601 suites PASS.** Four artifact-pinned figures had to be re-measured
  first, which is Phase F step 17 arriving early — `AdministrationProfilesDataTests` (volumesCovered
  552 → 553), `ArchivalAnalyticsTests` (band distribution `[261,120,64,66,41]` → `[…,42]`, coverage
  552 → 553), `SourceProvenanceDataTests` (268,757 → 269,248 notes; 522 → 523 volumes), and
  `VolumeCatalogueGroupingTests` (314,483 → 314,571; 552 → 553). Each moved by exactly v16's own
  contribution; the band that gained is band 4, whose span contains v16's 1985 midpoint. The
  ArchivalAnalytics message asks for a look before the number is updated — the look was taken: the
  manifest changed, the coverage builder did not.
- **`FRUSExplorerMac` BUILD SUCCEEDED**, 26 warnings, all of them the two known non-source residues.
- **`swift test`: 1,353 of 1,354 — one failure, and it is Phase D's gate.**
  `SemanticVectorsArtifactTests` "Volumes are in manifest order and cover the manifest exactly"
  fails because the semantic index covers 552 volumes and the manifest now names 553. **This branch
  must not merge until Phase D closes it.**

### Phase D — semantic ✅ **run on the Air, not the Studio**
Runbook and the environment check: `Phase-D-on-the-Air.md`. The Studio was unavailable, so the store
was copied to the MacBook Air (Mac17,4, M5) and the whole phase ran there.

**The precondition that decided it:** the GGUF on the Air hashes to `5a9e0645…de09020`, identical to
what the Studio harvest recorded. That is the input the corpus-wide provenance digest is built from.

- **Harvest** — 88 documents, 257 chunks, **9.4 seconds**. The contract diff came back clean: only
  `generated`, `machine`, `models_listing`, `volumes_requested`, `totals_this_run` and
  `script_sha256` moved. That last one is PR #1177's contract guard changing the harvester itself;
  it is **not** an input to the digest and reaches the index as a separate field. §4.2's allowed
  list predates it. None of the six that must not move — `model`, `model_file_sha256`, `dim`,
  `chunk_chars`, `overlap_chars`, `prefix` — appear in the diff at all.
- v16's `head.json` is the **first in the store to record the full contract** (`prefix`,
  `chunk_chars`, `overlap_chars` beside `model` and `dim`); the 552 Studio-era heads carry only the
  latter two, which is exactly what #1177 added and why the packer can now check per volume.
- **Relayout** — PCA 58.36% explained variance, **identical to the Studio's run to two decimals**
  over a different matrix; UMAP 1.8 min, HDBSCAN 1.7 min. Clusters **179 → 171**, unclustered 28.0%
  → 28.4%. Every parameter that should be identical is, including the venv resolving to the
  Studio's exact pins. See the runbook for the spurious numpy/Accelerate PCA warnings and the
  evidence they are harmless.
- **Pack** — `DIMS=512`, `EXPECT_DIGEST` pinned. **Digest unchanged at `a726ca60…`.** 553 volumes,
  **314,571 documents** (+88), 660 centroids (553 + 107 subseries), 1,607 id segments.
- **Shards** — 553 files. **All 552 pre-existing rows are byte-identical**: zero moved in
  `semantic-shards-manifest.json`, so no installed device re-downloads anything. The new
  `frus1981-88v16.vec` is 45,472 bytes, sha `ca8219e8…97a7aa3`.
- **Published and verified on the remote.** Fetched from the URL the app itself builds
  (`SemanticShardFetcher.defaultBaseURL` + `/frus1981-88v16.vec`): HTTP 200, byte-exact against the
  manifest. Five pre-existing shards spot-checked — the largest, the smallest and three at random —
  6 of 6 match, so the push disturbed nothing.

**The labels were read, not glanced at.** Zero of the 171 carry a label of three or more generic
corpus-wide words, which is the `british, united, war, american` failure mode that once put 168 of
179 wrong. What ships is properly distinctive — `falkland, galtieri, argentine, thatcher`;
`tshombe, adoula, katanga, congo`; `overlord, husky, brooke, burma`; `behring, bering, pauncefote,
fur`; `arica, plebiscitary, tacna, chile`. Only 12 tuples survive verbatim, but most changes are the
same cluster reordered or one term swapped (`ababa, ethiopia, addis, engert` →
`ababa, addis, ethiopia, engert`): the structure held, the weights moved under one more volume.

**And v16 landed where a South America volume should.** Its 88 documents went to four clusters —
52 `venezuela, perez, venezuelan, febre`, 20 `somoza, guatemala, nicaragua, guatemalan`, 2
`latin, venezuelan, venezuela, nsc`, 1 `allende, frei, chile, chilean` — with 13 unclustered
(14.8%, well under the corpus's 28.4%). Its row segments are `d368`–`d413` and `d444`–`d485`, two
runs with a gap: four published chapters out of eleven, visible in the artifact.

Two more artifact-pinned figures had to be re-measured, both 552/314,483 →
553/314,571: `SemanticVectorsArtifactTests.corpusFactsAreThePinnedOnes` and
`SemanticSubstrateTests`' bundled-tier check.

### Phase E — gated extras ⏸️ **DEFERRED by the owner**
Per D-4. The subject tags and the person crosswalk degrade per volume: v16 simply carries none until
the upstream drops include it. Nothing else waits on this.

### Phase F — code, tests, release ✅ 2026-09-10
- §7.1 (the "552" strings) was **already handled**: W-2 / PR #1178 made all nine derive their numbers
  live. The remaining `552`s in the tree are doc comments.
- §7.2 does not apply — v16 covers 1981–1988, not 1993+.
- Build number: **47**, edited directly in `project.yml` (3) and `project.pbxproj` (9), no `xcodegen`.
  README's "Current build:" line and its "manifest covers 552 volumes" both moved with it.
- **D-B's condition was verified in both directions before the bump**, which matters more than the
  listing being live. `history.state.gov/historicaldocuments/frus1981-88v16` is published — and its
  own `/d1` still returns *"This document will be published once its chapter has been cleared"*, so
  the local corpus copy is CURRENT rather than stale: the app's 88 documents are exactly OH's four
  cleared chapters of eleven, and the `partiallyPublished` badge is right. Had the site been ahead of
  our copy, the bump would have shipped a volume more incomplete than the one a reader could see.
- TestFlight notes rewritten for both platforms (iOS 3,855 / Mac 3,983 characters, `wc -m`, cap
  4,000). **Their headline is D-D, not the volume**: the semantic default going 0 → 0.5 is what a
  tester will actually notice, and the volume is partial.
- **Build 47 costs no re-index** — `currentDateIndexVersion` is unmoved since build 46 — and no mass
  shard re-fetch, since the provenance digest is unchanged and only v16's shard is new.

---

## OH pushed again mid-run: PR #461

The corpus moved from `13a56f8e5` (PR #460) to **`e744e71db`** (PR #461, *"add static files and
keywords"*) while Phases A–C were running. Everything above was generated at #460, so the question
is what has to be redone.

**Only `manifest.json`.** The body after `</teiHeader>` is **byte-identical** across the two commits
— same length, same SHA-1 (`73e8668b…`) — and #461 touches no other volume. The header grew from
4,111 to 6,387 bytes and nothing else moved, so every corpus-derived artifact reads exactly the same
bytes it read before. (`CrossRefValidationGenerator` does scan the whole file and will now see three
more `<ref target>`s in the header, but they are `https://static.history.state.gov/…`, classified
external and informational; the bundled index holds only broken refs.)

**What #461 actually added, and it matters more than its size suggests:**

- Three `<relatedItem>` blocks — the cover JPG, the EPUB and the MOBI are now published — each with
  a `<date type="publication-date" when="2026-09-10T…"/>` **build stamp**, which is exactly the
  timestamp `TEIHeaderParser` documents it must never take for `publicationDate`. It is right not to.
- `<revisionDesc status="partially-published">` carrying
  **`<change corresp="#frus1981-88v16" status="published" when="2026-09-18"/>`** plus per-chapter
  entries (`#ch1` is `being-cleared`). **The corpus does state the publication date after all** — 18
  September 2026 — just not in the element the parser reads.
- A `<profileDesc>` whose `https://history.state.gov/tags` keywords block is **commented out**, which
  is why v16 still has no tags. That is OH's deliberate choice, not a parse failure.

### Recording it, and why not by curation

Measured over all 694 corpus files, `revisionDesc/@status` is published 532 / being-cleared 51 /
planned 42 / being-researched 37 / being-digitized 10 / **partially-published 2** / absent 20, and
**534 files carry a `<change … status="published" … when="…">` for their own id**. Over the shipped
553, where both a `publicationStmt` print year and a revisionDesc `@when` exist, the years **agree in
510 and differ in 22** (`frus1950v01` is 1977 against 1998) — so the two are not interchangeable and
the revisionDesc value can only ever be a **fallback**, never an override.

As a fallback it fills **exactly one volume: `frus1981-88v16`, with `2026-09-18`.** That is better
evidence than a curated table, because it comes from the document and retires itself when OH fills
the primary element in.

**Also surfaced, and deliberately not acted on:** `frus1977-80v27` is `partially-published` in its
TEI and recorded `.published` in the manifest, because `ManifestGeneratorRunner` hardcodes
`status: .published` behind a comment claiming "The TEI header carries no publication status". That
comment is now false, `VolumeStatus.partiallyPublished` already exists and `SubseriesView` already
renders a badge for it — but honouring it would change a volume this release was not asked to touch.
See the decisions below.

## Owner decisions

1. **`CATALOG_API_KEY` for `95D407`?** Provide it and §6's eight-step chain resolves one lot file;
   withhold it and v16 ships with one archival unit showing unresolved, which is the plan's stated
   default. Everything else in Phase B is already done either way.
2. **The citation publisher for a volume with no publication date.** v16 will cite as *n.d.* — right
   — but names **Government Printing Office**, because `publisher(forYear:)` sees year 0 and 0 < 2014.
   The options are to treat a missing year as post-2014 (USGPO), to suppress the publisher entirely
   when the year is unknown, or to accept it. This is the first volume in 553 to reach that branch.
3. **`broken-refs-index.json`'s date stamp** — keep the truthful 553 count and pay one device-side
   backfill of identical flags, or revert that one file.
4. **§8 of the release plan is wrong in two directions and is the checklist this release runs from.**
   Three of its rows point at fixture literals no regeneration can reach
   (`BrokenRefsIndexTests.swift:24` is inside `fixtureJSON`; `ArchivalFlowsTests.swift:209-210`
   asserts numbers hard-coded at `:39`; `BundledKeynessBaselineTests.swift:46` is in `makeFile`),
   while the strongest real row — `.generatedOverTheWholeCorpus` — is omitted. Worth fixing in the
   plan before the next release.
