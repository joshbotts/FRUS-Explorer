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

---

## 3. The rows

| # | Session | Scope | Size | Gate |
|---|---|---|---|---|
| ~~PV-0~~ | **SHIPPED 2026-09-05 (PR #1210).** THREE undocumented artifacts, not two — `document-subject-index.json` was the third and the one the classification most needed, since it reads `DOCUMENT_SUBJECTS` alone and has no FRUS TEI in its closure at all. `ProvenanceSource` (the eight labels, each with a chip label, a method sentence and a partner name), `ProvenanceTier`, and `BundledArtifactProvenance.table` — 27 rows covering every bundled data artifact, with the seven config payloads exempt by name. The derivation guard works: `declaredInputsMatchTheSources` walks each generator's `*GeneratorCore` sources for the data-input env names and fails when they disagree with the table, so a generator that gains an input fails the build until someone decides what it means for the tier. Three mutations killed — a generator gaining an input, a NARA artifact claiming Tier 1, and an artifact dropped from the table. | S | none |
| ~~PV-1~~ | **SHIPPED 2026-09-05 (PR #1211).** `ProvenanceStatement` + a `sources` set on each export surface. THREE seams, each already the single source for its renderers, which is why this stayed an S: `AnalyticsProvenance.allCaveats` (CSV + plate), `QueryMethodAppendix.preambleLines` (CSV + Markdown), and `CollectionColophon` (PDF + HTML + DOCX — the type exists precisely "so HTML, PDF, and DOCX cannot drift", which is the W-13 failure this row was warned about). **The set is DERIVED from the exported items, never declared**, so an export cannot claim a source it did not use: a `.summaryOnly` body adds the model, an archival-sources block adds NARA and the curated disclosure, a persons index adds the people register, the researcher's own prose is their own. **One decision beyond the plan**: the sources block survives a plate's caveat designation, as `corpusCaveat` does — a designation trims qualifications, where sources are attribution, and a trimmed plate is the artifact most likely to be shared detached from its CSV. Three mutations killed. | S | PV-0 |
| PV-2 | **The chip type and its non-colour channel** | One shared `ProvenanceChip`, both platforms, glyph + label + VoiceOver | M | PV-1 |
| PV-3 | **Source Explorer, per claim** | The 77/23 split rendered where it actually falls | M | PV-2 |
| PV-4 | **The capture moments** | Add to Collection, freeze a quotation, Copy Citation | S | PV-2 |
| PV-5 | **Person rollups** | Editor-tagged mentions beside the authority join and POCOM | S | PV-2 |

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

---

### PV-3 — Source Explorer, per claim

Render the 77/23 split where it falls. The collection's identity, aliases and volume list are Tier
1; the NARA identifier, the catalogue link, the series facts and the sharing counts are Tier 2. One
card, two badges, attached to the rows rather than the header.

This is the row that justifies the wave — and the row most at risk of becoming decoration if it is
built before PV-1 and PV-2 settle the vocabulary.

---

### PV-4 — The capture moments

Add to Collection, freezing a quotation, Copy Citation. **The moment a screen becomes a claim** — a
chip here is read once, deliberately, by someone about to write something down. Highest
attention-per-pixel in the wave.

---

### PV-5 — Person rollups

Editor-tagged `persName` mentions (Tier 1) beside the authority join and POCOM careers (Tier 2),
currently indistinguishable on one screen.

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
| **Q-3** | Disclose the curated resolutions by name? | **Yes, as a disclosure line rather than a ninth label.** | Twenty lot files and 185 finding-aid entries rest on the owner's archival judgement. **Implementable without a generator re-run**: the shipped index cannot distinguish them (every lot carries `matchType: "control"`), but `CuratedLotResolutions.shared` already loads at runtime, so membership is a lookup. `ProvenanceSource.curatedDisclosure` carries the sentence; `carriesCuratedResolutions` names the four artifacts it applies to. |
| **Q-4** | Eight labels, or three? | **Eight.** | The label is the first half of the footnote — "FRUS + NARA catalog" *is* the answer where "Tier 2" forces a lookup. `everySourceSpeaks` pins the count at eight so a ninth cannot arrive unnoticed. |

---

## 9. Version history

- **1.0 — 2026-09-04:** proposed, against build 45. Supersedes the first assessment of this idea,
  which read the first category as *what is printed on the page* and concluded the layers did not
  partition. Under the owner's dependency-closure definition they do, and the boundary is
  mechanical — which is what makes the wave shippable rather than a matter of taste.
