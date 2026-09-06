# Provenance tiers — telling the reader what they may claim

**Status:** proposed, 2026-09-04. Written against the tree at `0d88e7e5` (**build 45**, index format
version 47). This is **wave PV**; its Plan-of-Record placement is a new row in
`Plan-Of-Record-2026-08-28.md`. **It ships in the release AFTER build 45** — build 45 is at the
store gate and nothing here may delay it. Every code claim below was verified against the tree at
the stated anchors, not taken from a doc comment.

**The owner's framing, verbatim, because the whole design turns on it:**

> *"Data derived directly from FRUS publications without dependencies on other bundled data sources
> belong in the first category. The idea would be to give users a clear sense of provenance so they
> can make clear judgments about how to characterize insights that they want to report from the app."*

So this is a **citation feature wearing a visual-design costume**. The question a reader is asking
is not *what colour is this* but *may I write "FRUS shows X", or must I write something weaker*.
Everything below is ordered by how close a surface sits to a footnote.

---

## 1. The rule, and why it makes the wave shippable

**A bundled artifact does not make a derivation Tier 2. The artifact's own input closure decides —
and the closure is per FIELD, not per file.**

Stated mechanically: a derivation is **Tier 1** iff its transitive input closure is a subset of
{FRUS TEI, `manifest.json`} **and** the fields it actually reads were untouched by any other
source.

Two files on the same shelf, different tiers, and nobody has to argue:

| Artifact | Declared inputs | Tier |
|---|---|---|
| `broken-refs-index.json` | `VOLUMES_DIR`, `MANIFEST` | **1** |
| `collection-usage-index.json` | `VOLUMES_DIR`, `MANIFEST`, `COLLECTION_AUTHORITY` → which takes `CENTRAL_FILES_INDEX` → NARA | **2** |

This is the load-bearing property of the whole wave: **the tier is computed from the `Env:` lines
the generators already declare**, not assigned by taste. It is therefore testable, and PV-0 makes
it so. A design where a human assigns tiers by judgement would rot within two waves.

**Measured over the 34 bundled artifacts** (each verified against its generator's runner source,
not only against CLAUDE.md):

- **Tier 1 — 8 artifacts.** `manifest`, `source-provenance-index`, `resolved-edge-index`,
  `broken-refs-index`, `administration-profiles-index`, `administrations`, `tei-rendering-config`,
  `word-cloud-stopwords`.
- **Tier 2 — 21 artifacts.** Everything with NARA's catalogue, the OH people register, POCOM, the
  subject taxonomy, the State Department decimal schedule, or the owner's curated resolutions in
  its closure. Four of them — `presidential-library-catalog`, `digitized-ranges-index`, `roll-scans-index`
  and `document-subject-index` — contain **no FRUS data at all**.
- **Tier 3 — 5 artifacts.** `semantic-vectors-index`, `semantic-map-index`, `cloud-vectors-core`,
  `cloud-vectors-volumes`, `keyness-baseline`.

### 1a. Why per-file tiering is not enough — the error this plan already made once

The first draft of this plan tiered `collection-authority.json` as a file (its closure includes
NARA) and therefore labelled the whole archival-analytics family **Tier 2**. That is wrong, and the
measurement is unambiguous:

- `grep -rn "naId\|catalogURL" FRUSExplorer/Analytics/` returns **zero hits**. Every NARA-identifier
  consumer in the app lives in `SourceExplorer/`, `Browser/ArchivesBrowseView.swift` or `TripPacket/`.
- In the generator, `CollectionAuthorityGeneratorCore/AuthorityBuilder.swift:176` is the **only**
  line that touches the NARA resolver, and it fills exactly one field.
- `AuthorityLookup` keys on `record.id`, `record.name`, `record.aliases`, `bySegment` — all
  FRUS-derived.

**So Collections, Flows and Network are Tier 1**, and a per-file rule would have told the reader
their largest analytics surface was NARA-dependent when it never reads a NARA value. That
understates what they may claim, which is the opposite of this wave's purpose and worse than saying
nothing. PV-0's table is therefore keyed on *(artifact, field-set)*, and its test must assert the
field set, not just the file.

### 1b. The crux: a parse of printed prose is Tier 1

A source note reads `Department of State, Central Files, 611.41/5-1054`; the app parses it into a
repository and a decimal class. **That parse is Tier 1**, on two grounds:

1. **The closure is empty.** `Package.swift` declares `SourceNoteKit` with no `dependencies:` array
   at all, and no file in the target reads `Bundle`, a `.json`, or the network.
2. **The alternative is incoherent.** If a hand-written grammar's fallibility demoted its output,
   then `extractHeader`, `extractBodyText` and the FTS5 index itself would demote too — every read
   of XML is a program that can be wrong. **The tier is about provenance, not confidence.**

**But the label licenses less than it looks like, and PV-1's strings must say so.** Tier 1 licenses
*"this came from FRUS and nowhere else."* It never licenses *"this is what FRUS says"* — a machine
did the reading. Every Tier-1 sentence about a parse names the app as the reader.

### 1c. The finding that decides the shape: the boundary runs inside a row

Measured on the shipped `collection-authority.json`: of **4,429 collections, 3,411 (77%) are
clustered from FRUS front matter alone and 1,018 (23%) carry a NARA identifier.** The identity is
Tier 1; the catalogue link is Tier 2; they are the same card. `CollectionGeneratedBlocks.swift`
builds each Archival Sources row with a Tier-1 `text` and a Tier-2 `secondaryText` on one line.

**Consequence, and it is the design:** the badge attaches to **a claim**, never to a card, a screen
or a document. A per-screen chip cannot describe this data and must not be built.

---

## 2. What the reader sees — name the source, not the tier

Three hues carry the tier. **The text names the partner**, because that is the first half of the
sentence the reader is writing: "Tier 2" forces a lookup; "FRUS + NARA catalog" *is* the answer.

| Chip | Tier | Covers |
|---|---|---|
| **FRUS text** | 1 | Search, cross-references, TEI dates, editor-tagged persons, page ranges, the source-note parse, provenance categories, decimal class *numbers*, update tracking |
| **FRUS + NARA catalog** | 2 | Central files, series facts, divided lots, digitised ranges, presidential libraries, the NAIDs on 23% of collections. **Not** the archival analytics built on the authority — those read no NARA field (§1a) |
| **FRUS + OH people register** | 2 | Person rollups, the persons index, POCOM careers |
| **FRUS + OH subjects** | 2 | The subjects facet, document subject chips, volume subject profiles |
| **FRUS + State Dept. schedule** | 2 | Decimal-class *glosses* only — `812.6363` reading as *Mexico — Petroleum* |
| **FRUS + this app's word lists** | 3 | Word clouds, keyness, collocation |
| **This app's model** | 3 | Summaries, semantic search, the map, cluster labels |
| **Your reading** | — | Notes, tags, highlights, coverage |

**Three collapses, deliberate.** Curated resolutions fold into *NARA catalog* and surface in the
disclosure rather than taking a ninth label; POCOM folds into *OH people register*;
`volume-tag-taxonomy` folds into *OH subjects*. An eight-label vocabulary a reader learns beats a
twelve-label one they don't.

**"Your reading" is outside the visual family on purpose.** Nobody mis-cites their own highlight as
FRUS, and the codebase already enforces this boundary architecturally — `FTS5Store/FTS5Types.swift`
splits `frus_documents` from `user_content` so the corpus index stays immutable outside volume
indexing. The label exists only where the reader's own act becomes a denominator (coverage over a
working corpus), and it must not look like a provenance chip.

### 2a. The colours, measured

| Tier | Light | on `#F2F2F7` | Dark | on `#1C1C1E` |
|---|---|---|---|---|
| 1 | `#A61C2A` | **6.67:1** | `#E8798A` | **6.10:1** |
| 2 | `#3B4E8C` | **7.09:1** | `#8FA5DE` | **6.97:1** |
| 3 | `#4A5568` | **6.74:1** | `#A0AEC0` | **7.54:1** |

`#A61C2A` is **the app icon's own dominant field** (sampled from `AppIcon-256.png`, which runs
`#A61C2A`–`#AE1E2D` over paper `#F7F7F5`). This wave does not introduce a brand colour; it extends
inward the one the icon already asserts.

**The ruby cannot cross into dark mode**: `#A61C2A` on `#1C1C1E` is **2.29:1**, below even the 3:1
minimum for a UI component. The dark twin is a rose. `FRUSTheme.adaptiveColor(lightHex:darkHex:)`
already exists for exactly this and `headnotePurple` already ships as two different purples.

**The capsule around the text carries almost nothing, and PV-2 measured how little.** The 12% wash
is **1.19–1.25:1** against the page across all six pairs, and the 32% hairline **1.63–1.94:1** —
deliberately short of WCAG 1.4.11's 3:1, which governs visuals *required to identify a component*
and does not bind here, since the label identifies the chip at 6.1:1 or better and the glyph beside
it does too. Reaching 3:1 would take roughly 0.70 alpha, a heavy ring at `.caption2`. What a reader
perceives is the chip's **text**.

---

## 3. The rows

| # | Session | Scope | Size | Gate |
|---|---|---|---|---|
| ~~PV-0~~ | **SHIPPED 2026-09-05 (PR #1210).** THREE undocumented artifacts, not two — `document-subject-index.json` was the third and the one the classification most needed, since it reads `DOCUMENT_SUBJECTS` alone and has no FRUS TEI in its closure at all. `ProvenanceSource` (the eight labels, each with a chip label, a method sentence and a partner name), `ProvenanceTier`, and `BundledArtifactProvenance.table` — 27 rows covering every bundled data artifact, with the seven config payloads exempt by name. The derivation guard works: `declaredInputsMatchTheSources` walks each generator's `*GeneratorCore` sources for the data-input env names and fails when they disagree with the table, so a generator that gains an input fails the build until someone decides what it means for the tier. Three mutations killed — a generator gaining an input, a NARA artifact claiming Tier 1, and an artifact dropped from the table. | S | none |
| ~~PV-1~~ | **SHIPPED 2026-09-05 (PR #1211).** `ProvenanceStatement` + a `sources` set on each export surface. THREE seams, each already the single source for its renderers, which is why this stayed an S: `AnalyticsProvenance.allCaveats` (CSV + plate), `QueryMethodAppendix.preambleLines` (CSV + Markdown), and `CollectionColophon` (PDF + HTML + DOCX — the type exists precisely "so HTML, PDF, and DOCX cannot drift", which is the W-13 failure this row was warned about). **The set is DERIVED from the exported items, never declared**, so an export cannot claim a source it did not use: a `.summaryOnly` body adds the model, an archival-sources block adds NARA and the curated disclosure, a persons index adds the people register, the researcher's own prose is their own. **One decision beyond the plan**: the sources block survives a plate's caveat designation, as `corpusCaveat` does — a designation trims qualifications, where sources are attribution, and a trimmed plate is the artifact most likely to be shared detached from its CSV. Three mutations killed. | S | PV-0 |
| ~~PV-2~~ | **SHIPPED 2026-09-05 (PR #1212).** `ProvenanceChip` — glyph + label + VoiceOver sentence, three tier colours on `FRUSTheme`, **deliberately unmounted**: PV-3 is the row that decides where a badge falls, and mounting one here to prove the type compiles would pre-empt it. Every rule is a `static func`, so the whole chip is testable without a view host. **Four sentences, not the plan's three** — `yourReading` shares the computed tier while sitting outside the provenance family, and "computed by this app" over a reader's own highlight attributes their work to the software. Twelve mutations killed. Four findings changed the code after review: the neutral wash and hairline route through `provenanceFill`/`provenanceBorder` rather than restating the alphas; the stroke is **0.5**, the chip idiom, where 1.0 is the headnote *card*; the glyphs joined `SymbolNameAuditTests`' runtime check, since the literal audit cannot see a name returned from a function and `square.fill`/`triangle.fill` appear nowhere else in the tree (proved: mutating a glyph *and* its expectation together passes `ProvenanceChipTests` and fails the audit); and `.accessibilityElement(children: .ignore)` is pinned **with its position**, because `Image(systemName:)` speaks its own symbol name and a label applied above the modifier is discarded. | M | PV-1 |
| ~~PV-3~~ | **SHIPPED 2026-09-05 (PR #1216).** Five mounts across four files, and the split renders where §1c said it falls. **The two halves are cleanly separated by SECTION, which the plan did not know**: `CollectionDetailView.overviewSection` (name, repository, record group, lot key, aliases) is uniformly Tier 1 — `recordGroup` is a vote over references parsed from FRUS front matter, not a catalogue lookup — while `catalogSection` (NAID, catalogue link) and `dividedAtNARASection` (claimant series, entry numbers) are uniformly Tier 2. So a per-section badge is exact rather than approximate, and no claim needed splitting. **That view is SHARED between platforms**, so three of the five mounts cover both; only the Source Explorer card is twinned, and a test pins both twins. **The mount names the source and never asks `source(ofArtifact:)`** — a test proves that prohibition non-vacuous by adding a real call. Five mutations killed. **It also corrected a Q-3 error PV-0 and PV-1 shipped — see §8.** | M | PV-2 |
| ~~PV-4~~ | **SHIPPED 2026-09-05 (PR #1217).** Two mounts, and mostly measured refusals. An enumeration of **71 capture moments** sorted them four ways: durable files and CSVs are already PV-1's (the colophon, the analytics block, the query appendix — the only form that travels); citations pasted into a footnote are **refused, with a test pinning it**, on the app's own #680 reasoning that a chip does not travel but a payload does; diagnostics dumps are out of scope by kind; and only two are UI moments before a save. Those two are `CollectionPickerSheet` (both platform bodies, persistent chrome, invariant `.frusText` **by construction** — an excerpt is a frozen span of the document's own text) and **the semantic map's lasso**, the row's headline and the one genuinely mixed capture in the app: the documents are FRUS's, but the fact that these particular ones are together is the model's. Four mutations killed. | S | PV-2 |
| ~~PV-5~~ | **SHIPPED 2026-09-05 (PR #1219).** Three mounts, and **the row where the per-claim rule was actually needed**: the identity block puts the volumes' own description directly above the register's role, both secondary-styled prose about one person, previously indistinguishable — §1c's boundary-inside-a-row, found at last. The career footer takes the second grain, where the chip adds what the POCOM sentence leaves out: that *attaching* this career to this person is the app's join, which is what a reader needs before reading an empty Career section as "held no post". The People LIST stays unbadged on three measured legs — and one of PV-2's own premises was **wrong**: the row subtitle does not splice two tiers, `roleEraSubtitle` is `role ?? description` plus era, all TEI, so the row is uniformly Tier 1. Five mutations killed. **Wave PV complete.** | S | PV-2 |

**Suggested order is the table order, and PV-1 before PV-2 is the argument of the wave**: the
export sentence is the only part that reaches a footnote, and it is nearly free (see PV-1). If the
wave stalls after one session, that session should be the one that changed what a reader can
honestly claim.

---

### PV-0 — Make the tier computable, and fix what it reads

**Two artifacts are undocumented and therefore cannot be tiered.** `digitized-ranges-index.json`
and `roll-scans-index.json` appear **nowhere** in CLAUDE.md (verified: 0 occurrences each). Both
are pure NARA — `DigitizedRangeIndexGenerator` reads only `HARVEST_DIR/series/rg_59.json` and takes
no FRUS input at all. Since the tier is computed from declared inputs, an undeclared artifact is
untierable. **Document them first.**

Then the mechanism: a `ProvenanceTier` enum and a table mapping each bundled artifact and each
runtime derivation to its tier and its partner label, **plus a test that fails when a generator
gains an input its tier does not account for**. The test is the point — without it the table is a
snapshot that silently goes stale the next time a generator takes a new `Env:` var.

**Refused here:** deriving the tier at runtime by inspecting artifacts. The inputs are a build-time
property; reading them on device would be machinery serving nothing.

---

### PV-1 — The export sentences

**This is the cheapest row and the most valuable, and it is nearly free because the machinery
exists.** `FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift` already emits
`csvPreambleLines` and `plateLines`, already forces its corpus caveat through every trim
(`plateCaveatLines`), and already credits the Office of the Historian rather than the app
(`plateAttribution`). The source sentence is **a field on that struct, not a new subsystem** — and
`Export/QueryMethodAppendix.swift` already consumes it.

The strings, to be keyed and mirrored in `Docs/EditableContent.md`:

- **Tier 1** — *"Read from the text and editorial apparatus of the FRUS volumes, and from no other
  source. Where a value was parsed out of printed prose, this app did the reading."*
- **Tier 2** — *"Produced by joining the FRUS volumes to %@. The join is this app's; a record it
  could not match is absent rather than wrong."*
- **Tier 3** — *"Computed by this app rather than read from a source — a model or a scoring rule
  stands between the volumes and this figure. Cite it as the app's output, not the record's."*

**Reaches:** the three collection renderers, the method appendix, the analytics plates and CSVs,
the visit packet. **Note the W-13 finding that applies here**: `preambleLines` is *not* shared —
it is private and CSV-only, and Markdown and plain text hand-build their own headers. A sentence
added in one place ships in one format and vanishes from the collection PDF. Check all three.

---

### PV-2 — The chip type and its non-colour channel

One `ProvenanceChip`, declared once, mounted by both platforms. **The twins are hand-maintained and
this repo's record is that they drift on exactly this kind of edit** — a chip written twice is two
places for the vocabulary to diverge.

**The non-colour channel is mandatory, and it is new machinery.** No chip in this app encodes
meaning by colour alone today (`ConfidenceChip` carries its label as text), and that line must
hold. `accessibilityDifferentiateWithoutColor` is read in exactly **one** file in the whole tree
(`WordCloudView`, which swaps colour dots for `plus.circle.fill`/`minus.circle.fill`). So the chip
carries a glyph (■ ▲ ●) *and* the label *and* a VoiceOver string, and honours the environment key.

**VoiceOver strings:** *"Source: the FRUS volumes only."* / *"Source: FRUS joined to %@."* /
*"Source: computed by this app."*

**SHIPPED.** A fourth sentence was needed: `yourReading` sits in the computed tier while being
deliberately outside the provenance family, so a per-*tier* string reads "computed by this app"
over somebody's own highlight.

**No variant was added, and that was the question the row was surveyed to answer.** A per-mount
survey of all three remaining rows proposed a glyph-only form for dense person rows, a
`Set<ProvenanceSource>` parameter for the capture moments, and a plain-`String` accessor for
pasteboard payloads. All three were refused on verification: the words are already `String`s on
`ProvenanceSource`, several sources on one surface is several chips (ordered by tier then label,
as the export block orders its sentences), and a glyph-only chip would encode meaning by shape
alone for a sighted reader who has not learned the vocabulary — the same failure as colour alone,
one channel over. **The chip takes one `source` and nothing else.**

**One shape collision is recorded rather than designed around.** `ArchivalNetworkView`'s legend
already reads `circle.fill` as *Collection* and `square.fill` as *Central-file class* at the same
`.caption2`/`.secondary` weight. §6 already refuses graph surfaces because hue is the data there;
it now refuses them for a second reason, and the chip's own doc comment says so.

---

### PV-3 — Source Explorer, per claim

Render the 77/23 split where it falls. The collection's identity, aliases and volume list are Tier
1; the NARA identifier, the catalogue link, the series facts and the sharing counts are Tier 2. One
card, two badges, attached to the rows rather than the header.

This is the row that justifies the wave — and the row most at risk of becoming decoration if it is
built before PV-1 and PV-2 settle the vocabulary.

**SHIPPED.** What the row actually found, beyond the survey:

- **The boundary falls between SECTIONS, not inside a row.** §1c inferred from
  `CollectionGeneratedBlocks` (a Collections *export*, whose rows do mix a Tier-1 `text` with a
  Tier-2 `secondaryText`) that the badge must attach below row level. On the Source Explorer
  surfaces it does not: `overviewSection` is uniformly Tier 1 and `catalogSection` uniformly Tier 2.
  The per-claim rule still holds — it is *satisfied* per section here, rather than weakened.
- **`CollectionDetailView` is shared between platforms**, which is why this row cost less than
  feared: three of five mounts are written once. Only the Source Explorer card is twinned.
- **What is deliberately NOT badged, and the measurement behind it.** A claim inventory over both
  twins, the shared detail view and the authority types found **279 distinct claims, of which
  roughly 150 are Tier 2** — the lot-file panel, series facts, curated cards, live catalogue
  results, digitised rolls, filing periods, Paris Peace, pre-1906 predictions, presidential
  libraries, non-NARA repositories. Badging each would put fifteen identical chips down one screen,
  which is the "chip per atom" §6 refuses.
  **It would also add nothing, and that is the real argument**: those sections say *NARA* in their
  own labels — "NARA Creator", "Open Series in NARA Catalog", "Resolved from the bundled index",
  "View in National Archives Catalog". A reader cannot mistake them for FRUS. The chip earns its
  place on the **collection identity**, which is the one claim on these screens a reader would
  naturally assume came from the catalogue and did not; and on the two sections adjacent to it that
  are the catalogue's, so the boundary is visible where it actually falls.
  Also unbadged, for the same reason in the other direction: the sections counting over the
  reader's own library (local citing counts, related collections, cited-over-time, citing volumes,
  sub-series) are FRUS-derived and sit under a headline already badged Tier 1.
- **Three sections are unbadged because they are MIXED per row, and a section chip there would be
  wrong** — the inventory's adversarial pass caught all three, and each is a real finding for a
  later row rather than an omission from this one:
  the **pre-1906 country series** is Tier 2 throughout (the row exists only because a NARA artifact
  said so), not the Tier 1 a first reading suggests;
  a **lot file's record group** is `.frusText` when it falls out of `SourceNoteParser`'s pure
  `lotFileRecordGroup` rule and `.naraCatalog` (with the curated disclosure) when
  `CuratedLotResolutionsStore` supplied it — the same row, two answers, decided at render time;
  and **Pointed At, Not Printed** must branch on `citation.anchor`, `.frusText` for lot and library
  pointers against `.stateDeptSchedule` for central-file-class pointers, which are gated by
  `decimal-class-labels.json`.
  These are the §1c shape — the boundary inside a row — and they are where PV-3's per-claim rule
  would actually have had to split a row. Badging them needs a per-row branch, not a section chip.

**Surveyed at PV-2, two constraints verified:**

- **The twins do not share a container.** `SourceExplorerView` is a `Form` of nine `Section`s;
  `MacSourceExplorerView` has no `Form`, `List` or `Section` at all — it is `ScrollView` + `VStack`
  + `GroupBox`, and its own header comment states the substitution. So the chip may not depend on
  `Section` or `LabeledContent` semantics. `ConfidenceChip` and `ClassificationChip` are already
  mounted at parallel sites in both, which is the shape to copy.
- **A container accessibility label swallows the chip silently.** `SearchView`'s result rows set
  `.accessibilityLabel(result.header)` on the `Button` wrapping `SearchResultRow`, and every chip
  inside goes unannounced. Source Explorer's `NavigationLink`s set no container label *today*, so
  this is a hazard to check rather than a present failure — and `ProvenanceChip.accessibilityLabel(for:)`
  is callable on its own precisely so such a row can fold the sentence in.
- **Do not route the source through `BundledArtifactProvenance.source(ofArtifact:)`.** The table
  holds one `Entry` per file, and `collection-authority.json` is precisely the artifact whose two
  halves this row must separate: `name`/`aliases`/`volumeIds` against `naId`/`catalogURL`. Nor can
  the table be corrected to cover it — flipping that row to `.frusText` under the §1a field
  exemption passes the PV-0 guard and would then claim Tier 1 for the NARA identifier and
  catalogue link the collection detail screen renders. **The mount names the source per claim.**
- **The card's two halves are not on one screen.** Both Source Explorers render only the Tier-1
  rows; the NAID and the catalogue link are one navigation away. "One card, two badges" is
  therefore two *screens*, one badge each — which is a stronger argument for the chip than the
  plan's original framing, since neither screen is self-evidently the other's tier.
- **The chip is a fixed-intrinsic leaf, and the mounts are why.** All twelve `ConfidenceChip`
  sites across the twins are leading-packed `HStack(spacing: 6)`s — title first, chip last, no
  `Spacer()` anywhere. A greedy chip stretches its capsule across the row and truncates the claim
  beside it.

---

### PV-4 — The capture moments

Add to Collection, freezing a quotation, Copy Citation. **The moment a screen becomes a claim** — a
chip here is read once, deliberately, by someone about to write something down. Highest
attention-per-pixel in the wave.

**SHIPPED.** Two mounts, and the row turned out to be mostly a set of measured refusals.

**An enumeration of 71 capture moments across the app** — every copy, share, export, freeze and
save a reader can invoke — sorted them into four kinds, and only one wanted a chip it did not
already have:

- **A durable file or CSV.** Already PV-1's, and already done: `CollectionColophon`,
  `AnalyticsProvenance` and `QueryMethodAppendix` put the sources block into the artifact, which is
  the only form that travels. Adding a chip beside the export button would duplicate it.
- **A citation pasted into a footnote** — Copy Citation, Share Citation, BibTeX, RIS, Copy URL.
  **Refused, and the refusal is now pinned by a test.** A sentence appended here is pasted into
  somebody's document. The app already draws this line: `naraExportText` embeds a caveat in a
  durable NARA record copy *because* "the chip in the UI does not travel into a research note"
  (#680) — the distinction is what the payload becomes, not whether it leaves the app.
- **A UI moment before a save**, where a chip is read once and deliberately. Two of these:
  `CollectionPickerSheet` (both platform bodies, in the persistent chrome) and the semantic map's
  lasso.
- **Diagnostics dumps.** Out of scope by kind — a research-state record is not a research claim.

**The lasso is the row's headline and the one genuinely mixed capture in the app.** The documents
in a lassoed set are FRUS's; what is *not* FRUS's is that these particular ones are together — the
model placed them near each other. The saved corpus records only
`sourceDescription: "Semantic map selection"`, naming the mechanism without saying it is a model,
and a reader who later writes "these documents cluster" is reporting the app's reading of the
language. The chip sits above **Save as Working Corpus** on the panel's own stated reasoning: *say
it before the corpus is made, not only in its provenance afterwards*.

**The picker's chip is invariant, and that is by construction rather than by omission.** Nothing
else can be captured there: the entry is a FRUS document and an excerpt is a frozen span of that
document's own text. §6 refuses an invariant chip on *search results*, a browsing surface seen
constantly; this is a capture moment seen once, deliberately, by someone about to write something
down — and it is the surface whose exports PV-1 gives a colophon, so the two now agree.

**Surveyed at PV-2, and no constraint on the chip's API survived verification.** The survey
proposed three additions for these moments — a `Set<ProvenanceSource>` parameter, a plain-`String`
accessor for pasteboard payloads, and a dark-chrome palette for the Excerpt trigger — and each was
refused: the words are already `String`s on `ProvenanceSource`, and several sources at one moment
is several chips. What it did *not* refute is a set of mount obligations, and they stand as
the row's own work. None of the three moments is full-screen. `CollectionPickerSheet`'s shared
seams are `String`s rather than views, so a chip must be mounted in **both** platform bodies or it
travels to neither — and it belongs in the sheet's persistent chrome, visible from presentation
until dismissal, never keyed to a post-tap confirmation state, since the point is to be read
*before* the capture. And the sources must be derived from the payload that particular button
captures rather than from the hosting screen: the mixed case already exists **within** a single
surface, not merely across two, in the document share popover and menu.

---

### PV-5 — Person rollups

Editor-tagged `persName` mentions (Tier 1) beside the authority join and POCOM careers (Tier 2),
currently indistinguishable on one screen.

**SHIPPED.** Three mounts, and this is the row where the per-claim rule was actually needed.

**PV-3 found each Source Explorer section uniformly one source; here they are not.** The identity
block holds `indexEntry.entry.description` — the volumes' own words — directly above
`authorityEntry?.r`, the Office of the Historian's register, both secondary-styled prose about the
same person. Nothing distinguished them, so a reader quoting "FRUS describes him as…" could not
tell which line they had. Each now carries its own chip. **This is §1c's boundary-inside-a-row,
found at last.**

**The career footer is the second grain**, and the chip adds the half the sentence leaves out. The
footer already said "From the Department's Principal Officers and Chiefs of Mission register" —
whose records these are. It did not say that *attaching this career to this person* is a join the
app made, which is what a reader needs before concluding from an empty Career section that somebody
held no post. The chip supplements the sentence; a test pins that it does not replace it.

**The People LIST is deliberately unbadged, for three measured reasons, and one of the survey's own
premises was wrong.** PV-2's survey said "the row's subtitle string itself splices two tiers" — it
does not: `FRUSASTNode.roleEraSubtitle` is `role ?? description` plus the era, read from the TEI, so
the row is **uniformly Tier 1** and a chip there would never vary, which is §6's refusal of search
results. Beyond that the row already carries a name, a subtitle, a duplicate hint, a count capsule
and a chevron; and it is a `Button` with `.accessibilityElement(children: .combine)` *and its own*
`.accessibilityLabel`, the exact container that swallows a chip's announcement — so a chip there
would be silent to VoiceOver unless `accessibilityLabelText` folded the sentence in, which is why
`ProvenanceChip.accessibilityLabel(for:)` is callable alone. A test pins all three legs, so whoever
changes one is told the exclusion rested on it.

**Person Analytics stays unbadged** on the survey's verified constraint: `PersonMentionRanking`
carries no authority field, chart rows are `BarMark`s, and `rankingChartBody` is reused verbatim by
`exportRankingFigure` — a per-bar chip would be baked into the exported figure of record.

**Surveyed at PV-2, three constraints verified:**

- **Per row, from `PersonIndexEntry.authorityId` — never a per-screen constant.** The People list
  is not uniformly joined: a row with a nil `authorityId` took its canonical name and its
  birth/death years from the FRUS front-matter aggregate alone. And the chip must claim less than
  it looks like even on a matched row — role and description *always* come from the FRUS aggregate,
  and years fall back to it when the authority record carries none, so a chip keyed on
  `authorityId != nil` asserts that the **identity** was matched, not that the fields beside it
  came from the register.
- **Two grains in `PersonIndexView`, not one.** The career section already carries a footer
  sentence naming POCOM — that is the idiom to extend — while the identity section has no header
  and no footer and holds the Tier-1 front-matter description and the Tier-2 authority role as
  sibling `Text`s in one `VStack`. A chip must compose in both.
- **Person Analytics takes a section-level mount, not a per-row one.** `PersonMentionRanking`
  carries no authority field and the query selects no such column, so a per-row chip needs a new
  store column first; in chart mode the rows are `BarMark`s, and `rankingChartBody` is reused
  verbatim by `exportRankingFigure`, so a per-bar chip would be baked into the exported figure of
  record. All fifteen rows derive from one query and would carry an identical tier anyway.

---

## 4. What this wave deliberately is not

- **No CloudKit schema change.** Nothing here adds or alters a `@Model` or a stored property. The
  #488 gate is untouched, and `CD_AnnotationReview.CD_annotationId` still awaits its first writer
  independently of this wave.
- **No index bump.** Tiers are a build-time property of artifacts and a display property of views.
  Nothing here changes parse output, so `currentDateIndexVersion` stays at 47.
- **No new bundled resource.** The tier table is Swift, not JSON — it is code that must compile
  against the artifact names, and a JSON copy would be a second place for it to be wrong.
- **Not a confidence display.** See §5.
- **Not on every value.** The refusals in §6 are as much the design as the rows are.

---

## 5. The honest caution, which the owner should read before approving

**A tier badge makes a claim about provenance that a reader will reasonably extend to reliability,
and those are not the same thing.** Measured on `SourceNoteKit`'s own eval over 267,663 real notes:
the parser returns `unrecognized` for **7.4%** of 1952–54 notes, **1.1%** of 1906–39 — and
**essentially 100%** of pre-1906 notes (2,033 of 2,034).

All of those are Tier 1. A pre-1906 provenance chart is Tier-1 sourced and almost entirely
unparsed. **If the badge travels into footnotes, every surface reporting an aggregate owes a
residual beside it**, or the feature will make some numbers look better sourced than they are.
That obligation belongs to whichever row first puts a badge on an aggregate — PV-1, in practice.

**Owner decision required:** is a residual acceptable as a sentence in the export block only, or
must it appear on screen beside the chip? The second is more honest and more cluttered.

---

## 6. Refused surfaces, and why

| Surface | Why not |
|---|---|
| **The reading view** | The despatch is the point, all of it is Tier 1, and purple already marks editorial notes in the prose. A second hue competes with the document. |
| **Search results** | Every row is Tier 1. A colour that never varies teaches nothing and spends a hue. |
| **The semantic map** | Hue *is* the data — an even cluster sweep and a ten-hue provenance legend — and it does not honour Differentiate Without Color yet (plan row B-7). |
| **Word clouds** | Four lens colours are assigned, and red is negative sentiment. |
| **Administration profiles** | **Red means Republican here**, in a `Capsule()` at `opacity(0.18)` — the same shape and alpha this wave proposes. Nothing else may be red on that screen. |
| **Per-value chips generally** | ~60–70 kinds of datum across several hundred render sites. A chip per atom is unreadable; a chip per claim is the design. |

---

## 7. The traps, each measured

1. **The ruby fails dark mode.** `#A61C2A` on `#1C1C1E` is 2.29:1. Use `adaptiveColor`; the dark
   twin is a rose and will not look like the binding.
2. **Red is not free.** 53 call sites, four meanings — destructive/gone, Republican, negative
   sentiment, and slot 8 of the twelve-colour chart palette.
3. **A red capsule at 0.18 already ships** and means Republican
   (`AdministrationProfilesDashboard.swift`). The "red is only ever warning *text*" defence is false.
4. **macOS has no `AccentColor` asset**, so user tags and override chips take the reader's own
   system accent — **which can itself be red**. The glyph, not the hue, is what keeps Tier 1
   distinguishable there. `CrossReferenceAnalyticsView` already records this hazard.
5. **A 12% wash is a whisper** — 1.23:1 against the page. What a reader perceives is the chip's
   *text* colour, not its fill. Do not expect the tint alone to carry the tier.
6. **`preambleLines` is not shared** (W-13's finding): a sentence added there ships in CSV and
   vanishes from the collection PDF.
7. **Twin drift.** Every chip has an iOS and a macOS home.

---

## 8. Owner decisions — ANSWERED 2026-09-05

All four were answered the day build 45 shipped, which is what unblocked the wave.

| # | Question | Decision | What it settled |
|---|---|---|---|
| **Q-1** | Residual on screen, or only in the export block? | **Export block only.** | PV-1 is a string change, not a layout change. The residual is a property of the method, and the methods block is where a method belongs. |
| **Q-2** | Is `administrations.json` Tier 1? | **Yes.** | A calendar of who held office on which date is a public-record constant rather than a dataset that could disagree with FRUS. `administrations.json` joins {FRUS TEI, `manifest.json`} in `frusOnlyInputs`, and the administration profiles carry a Tier-1 chip. |
| **Q-3** | Disclose the curated resolutions by name? | **Yes — and PV-3 found they were ALREADY disclosed, in the only place they occur.** | ~~Twenty lot files and 185 finding-aid entries rest on the owner's archival judgement. Implementable without a generator re-run: the shipped index cannot distinguish them (every lot carries `matchType: "control"`), but `CuratedLotResolutions.shared` already loads at runtime, so membership is a lookup. `carriesCuratedResolutions` names the four artifacts it applies to.~~ **The premise was false and the app already enforced the opposite.** `curated-lot-resolutions.json` says of itself that its rows are "deliberately NOT written into central-files-index.json, volume-sources-index.json, or collection-authority.json — those bundles feed surfaces that cannot express doubt", and two non-vacuous assertions in `CuratedLotResolutionsTests` hold that line. PV-0's four-artifact set was therefore wrong, and PV-1 used it to make **every collection export containing an archival-sources block claim a hand-matched identifier it cannot contain** — manufacturing doubt the app had guaranteed away, which fails the wave's purpose in the same way overstating certainty would. Fixed in PV-3: the set is deleted (an empty one invites the claim back), the export passes nothing, and a test pins the absence. `ProvenanceSource.curatedDisclosure` is retained for a future surface that renders curated outcomes. **Where the doubt actually is, it was already said better than a chip could**: `SourceExplorerView.curatedLotSection` and its Mac twin carry a `ConfidenceChip` and the sentence "This match was made by collection name, not by a catalog control number." |
| **Q-4** | Eight labels, or three? | **Eight.** | The label is the first half of the footnote — "FRUS + NARA catalog" *is* the answer where "Tier 2" forces a lookup. `everySourceSpeaks` pins the count at eight so a ninth cannot arrive unnoticed. |

---

## 9. Version history

- **1.5 — 2026-09-05:** PV-5 shipped and **wave PV is complete**. §PV-5 records the identity block
  as the row where per-claim badging was genuinely required, the three measured legs behind leaving
  the People list unbadged, and a PV-2 survey premise that did not survive checking (the row
  subtitle is uniformly Tier 1, not mixed).
- **1.4 — 2026-09-05:** PV-4 shipped. §PV-4 records the 71-moment enumeration and the four kinds it
  sorted into, the citation refusal and why the app already drew that line at #680, and why the
  picker's chip is invariant by construction rather than by omission.
- **1.3 — 2026-09-05:** PV-3 shipped. §PV-3 records that the tier boundary falls between *sections*
  rather than inside a row on these surfaces, and that `CollectionDetailView` is shared between
  platforms. **§8's Q-3 is rewritten**: its premise — that curated resolutions fold invisibly into
  the bundled artifacts — was false, the app already enforced the opposite in two tests, and PV-0
  and PV-1 shipped a sentence claiming hand-matched identifiers in exports that cannot contain one.
- **1.2 — 2026-09-05:** PV-2 shipped. §2a gains the measured worth of the wash and the hairline;
  PV-2's own section records the fourth VoiceOver sentence and the glyph collision with
  `ArchivalNetworkView`'s legend; PV-3, PV-4 and PV-5 gain the constraints a per-mount survey
  verified — and, as usefully, the four proposed API additions that did **not** survive it, so a
  later row does not re-propose them.
- **1.1 — 2026-09-05:** PV-0 and PV-1 shipped (PRs #1210, #1211); §8's four decisions answered.
- **1.0 — 2026-09-04:** proposed, against build 45. Supersedes the first assessment of this idea,
  which read the first category as *what is printed on the page* and concluded the layers did not
  partition. Under the owner's dependency-closure definition they do, and the boundary is
  mechanical — which is what makes the wave shippable rather than a matter of taste.
