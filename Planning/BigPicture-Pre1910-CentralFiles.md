# Pre-1910 Central Files Resolution in Source Explorer — Feasibility & Plan

**Status:** Feasibility assessed 2026-06-11 — feasible with high confidence. Awaiting
reference data (see `Pre1910-CentralFiles-Reference-Data.md`) before implementation.

---

## Goal

NARA has digitized virtually the entire Department of State Central Files, 1789–1910
(see the [omnibus blog post](https://text-message.blogs.archives.gov/2023/07/11/department-of-state-central-files-1789-1910-available-online-an-omnibus/)).
Every document published in a pre-1910 FRUS volume should therefore have a digitized
archival copy reachable through the NARA Catalog. Finding it today is a manual
four-step inference:

1. From the document's operational context (diplomatic vs. consular; instruction from
   Washington vs. despatch from post; note to/from a foreign mission), infer **which
   component** of the Central Files holds it.
2. Within that component, find the **file series** from geographic + chronological
   parameters (country or consular post, plus date).
3. Locate the right **catalog link** (the roll-level record with images).
4. Conduct a **page-by-page review** of the roll's images/PDF to find the document.

The feature automates steps 1–3 and gives the user the best possible starting point
for step 4: the item-level (roll) catalog URL whose date range covers the document,
plus a verification hint (document number, date, estimated position within the roll).

---

## Why this is feasible — both sides already line up

### App side (verified against `frus1900.xml` and the FTS5 schema)

| Capability | Where it lives | Relevance |
|---|---|---|
| Sender/recipient direction | TEI `<persName type="from">` / `type="to"` in `<head>` | Explicitly tagged — instruction vs. despatch vs. note is *not* an inference |
| Originating office + place | `<dateline>` ("Legation of the United States, Buenos Ayres" / "Consulate-General…" / "Department of State, Washington") | Resolves diplomatic-vs-consular and Washington-vs-post deterministically in most cases |
| Exact document date | `document_dates.date_iso` (from `<date when=…>` / `frus:doc-dateTime-min`) | Drives roll selection within a series |
| Printed document number | `document_cache.document_number` ("No. 769.]") | Verification hint for the page-by-page review |
| Dateline text | `document_cache.dateline` | Classifier input, already indexed |
| Country chapter | `volume_structures` (sections list their `documentIds`; heads are "Argentine Republic.", "Austria-Hungary", …) | Document → country is a lookup, not an inference |
| Era classification | `SourceNoteParser` Era 1 (no source note, pre-1906) and Era 2 ("File No. 17529", 1906–1910) → `.centralFiles` | Entry point exists; currently dead-ends at a static research-page link in `SourceExplorerView.centralFilesPanel` |
| Keyed NARA API client | `NARACatalogClient` (v2, `x-api-key`) | Reused by the harvest tool; **runtime needs no API key** (see below) |

### NARA side (from the omnibus + per-series Text Message posts)

The digitized records follow a uniform three-level catalog hierarchy:

```
series (e.g. Despatches, NAID 603720)
  └─ file unit  = one microfilm publication per country / consular post
       └─ item  = one roll: per-frame JPEGs + a consolidated PDF   ← the target link
```

NARA's own [bulk-download scripts](https://github.com/usnationalarchives/Catalog-API)
confirm the v2 API enumerates everything under a series with
`GET /api/v2/records/search?ancestorNaId=<naid>&availableOnline=true&limit=25&searchAfter=<cursor>`.

### Series NAID table (collected 2026-06-11)

| Component | RG 59 entry | NAID | Arrangement |
|---|---|---|---|
| Despatches (diplomatic) | A1-13 | 603720 | by country, then chronological |
| Diplomatic Instructions (M61/M28/M77) | A1-5 | 593313 | by country from 1829; chronological 1785–1833 |
| Notes from Foreign Missions | A1-28 | 594363 | by country |
| Notes to Foreign Missions (M38/M99) | A1-23 | 597272 | by country 1834–1906; chronological 1810–1834; by country 1793–1810 |
| Miscellaneous Notes from Other States | A1-29 | 820133 | — |
| Despatches from Special Agents | A1-37 | 876974 | by mission, rough chronological |
| Instructions to Special Agents | — | 871874 | — |
| Consular Despatches | A1-85 | 302031 | by post city (hundreds of posts) |
| Consular Instructions (M78) | A1-59 | 604019 | **only 1801–1834 digitized** |
| Notes to Foreign Consuls | A1-96 | 1076611 | single chronological run |
| Notes from Foreign Consuls | A1-97 | 1076629 | single chronological run |
| Domestic Letters (Letters Sent) | A1-100 | 568025 | single chronological run |
| Miscellaneous Letters (Letters Received) | A1-113 | 583574 | single chronological run |
| Numerical File (M862) | — | 654171 | 1,241 rolls by case number; cases numbered sequentially, docs as `5275/1`, `5275/2`… |
| Minor File (M862) | — | 656890 | alphabetical subject file for routine matters |
| Card Index (M1889) | — | 656824 | 86 rolls, one alphabetical run |

Example file-unit NAIDs: France Despatches 177380727; Great Britain Notes from
Foreign Missions 183303919. Example item (roll) NAID: 188543169 (cited in the omnibus).

---

## Findings from reference data (2026-06-15)

User traced 9 documents (`Pre1910-CentralFiles-Reference-Data.md`). These confirm the
approach but **revise the architecture in several ways**. Each finding below carries
verified golden-target NAIDs for the harvest-tool parser.

### Finding 1 (architecture-changing): hierarchy depth varies by series

The plan assumed a uniform three-level `series → file-unit (country) → item (roll)`.
Reality is mixed: some series have **no file-unit level** and encode the country in the
roll (item) title instead. The index schema needs a per-component `geoGranularity`
flag and the roll-title parser needs per-series grammars.

| Component | Series NAID | Levels | Geo resolved at | Roll-title grammar | Verified example (roll NAID) |
|---|---|---|---|---|---|
| Diplomatic Instructions | 593313 | **2** | roll title | `Volume {n}: {country}: {date} - {date}` | "Volume 18: Great Britain: Aug. 17, 1861 - Sept. 2, 1863" (149311973) |
| Notes to Foreign Missions | 597272 | **2** | roll title (**may combine countries**) | `{country[ and country]}: {date} - {date}` | "Uruguay and Paraguay: July 7, 1834 - June 26, 1906" (216926854) |
| Notes from Foreign Missions | 594363 | 3 | file unit (country) | `{date} - {date}` | file-unit 183303942 → roll "Apr. 19, 1893-Mar. 28, 1896" (188287901) |
| Diplomatic Despatches | 603720 | 3 | file unit (country) | `{date} - {date}` | file-unit 5716479 (Japan) → roll "Mar. 4, 1905-Aug. 31, 1905" (188401761) |
| Consular Despatches | 302031 | 3 | file unit (post city) | `Despatches: {date} - {date}` | file-unit 196006797 (Havana) → roll "Despatches: April 1 - August 31, 1895" (211373468) |
| Numerical File | 654171 | **2** | n/a (case number) | `Numerical File: {caseStart}-{caseEnd}` | "Numerical File: 7179-7187" (19779414); "Numerical File: 682-699" (19174810) |

### Finding 2: roll-title formats are heterogeneous and dirty

- Per-series grammars (above) — no single regex. Some carry a `Volume {n}:` prefix.
- **NARA roll titles contain typos**, including in the date range: Switzerland roll
  189376306 reads "July 2, **1675**-Dec. 18, 1876" (1675 = 1875). Date parsing must
  clamp/flag years implausibly far from the series era and from adjacent rolls.
- Date forms vary ("Aug. 17, 1861", "April 1 - August 31, 1895", "Apr. 19, 1893-Mar.
  28, 1896" with and without spaces around the hyphen).

### Finding 3: multi-country and non-chronological rolls weaken date interpolation

Notes-to/from rolls can hold **several countries on one roll** ("Uruguay and Paraguay")
and the per-country section is **not internally chronological** (Doc 3). So the
"% into the roll" date-interpolation hint is unreliable for these. Revised UX: show it
only for single-country chronological rolls (Despatches, Consular, Instructions); for
combined/Notes rolls, show date range + correspondents + document number and a note to
scan the country's section.

### Finding 4 (architecture-changing): enclosures have *two* archival homes

Docs 8 & 9 trace the **same FRUS-printed text** (frus1895p2/d464, an enclosure):
- As an **enclosure**, the actual document physically lives in its **originating
  series** — Consular Despatches, Havana (roll 211373468), found exact at frame 290.
- The **covering instruction** that enclosed it lives in Diplomatic Instructions,
  Spain (roll 149334619) — but there the enclosure is only **referenced, not filmed**.

Implication: for an enclosure, the better page-by-page target is derived from the
**enclosure's own dateline** (→ its originating series), not the parent document's
series. The classifier should offer both, labelling which roll physically holds the
text vs. which only references it. TEI nests enclosures in the parent `<div>`, so both
the parent metadata and the enclosure's own `<dateline>` are available at index time.

### Finding 5: classifier cues, confirmed and expanded

Observed datelines/headings refine the rules:
- US post datelines appear in **two forms** — older "Legation of the United States,
  {city}" and newer "American Legation/Embassy, {city}". Both → Despatches.
- "{Foreign country} Legation, Washington" / "Legation of {country}, Washington" →
  Notes **from** Foreign Missions.
- "Department of State, Washington" + recipient is a US minister abroad → Instructions;
  + recipient is a foreign rep in Washington → Notes **to** Foreign Missions.
- Heading pattern "X to the Secretary of State" / "Secretary of State to X" is a strong
  direction signal alongside the dateline.
- **Country often must come from the FRUS chapter, not the document**: Doc 3 needed the
  *previous* document (d410) to identify the recipient's country. The volume chapter
  head is the reliable geo key; resolve country from chapter, not from parsing the name.

### Finding 6: FRUS annotations and the archival copy can disagree

- Doc 6: FRUS cites "File No. 7187"; the actual filing is 7187/19-76. The **integer
  case number still selects the right roll** ("7179-7187"), so Phase 1 keying on the
  leading integer (ignoring the `/NN` suffix) is robust even when FRUS is imprecise.
- Doc 7: case 697 → roll "682-699"; the `/43` is a within-case document number.
- Translations: Doc 2's FRUS text is an English translation; NARA holds the Spanish
  original. Text-matching to auto-verify a hit will fail for translated/extracted docs —
  rely on date + correspondents + position, never on body-text equality.

### Finding 7: microfilm prefixes vary (display only)

Observed: M77, M99, M133, M862, T20, T93, T98, FM77. The "T"/"FM"/"M" prefix is
citation metadata; NAID-based deep links don't depend on it. Capture it for display.

### Practical notes for the harvest tool

- Verified golden targets (series → file-unit → roll NAIDs above) become the parser's
  acceptance fixtures — the harvest output must reproduce each.
- Frames found were deep in rolls (294, 521, 860, …), confirming page-by-page is real
  and a good frame estimate is worth the effort where the roll is chronological.
- "NARA Catalog website delays and failures" (Doc 2) reinforce the **bundle-the-index,
  no-runtime-API** design — the live site is too flaky for an interactive lookup path.

### Non-blocking gaps in the fixture (harvest survey will resolve)

- No telegram trace (FRUS paraphrases them; they're filed within their parent series
  regardless, so no separate handling).
- No clean "not found" failure (Docs 3/6 friction partially cover the fallback UX).
- Only one consular post and one country per 2-level series sampled — the harvest's
  first survey run enumerates the full country/post vocabulary and validates that
  file-unit / roll titles parse across all of them.

---

## Proposed architecture

> **Revised by the 2026-06-15 findings above** — note especially the per-component
> `geoGranularity` flag (Finding 1), per-series roll-title grammars (Finding 2), and
> enclosure dual-homing (Finding 4).

Three components, each matching an existing pattern in the repo:

### 1. `CentralFilesIndexGenerator` (new SPM command-line tool)

Sibling of `ManifestGenerator` / `TaxonomyGenerator`. Offline, occasional harvest run
(requires a NARA API key via env var, like NARA's own scripts):

- For each series NAID above, page through `ancestorNaId` results.
- Parse **file-unit titles** → country / consular post / microfilm publication number.
- Parse **item titles** → roll number + date range (or case-number range for M862).
- Emit `Resources/central-files-index.json`.

Sketch of the bundled index (revised for variable hierarchy — Finding 1):

```json
{
  "generated": "2026-06-15",
  "components": [
    {
      "category": "diplomaticDespatches",
      "seriesNaId": "603720",
      "geoGranularity": "fileUnit",          // country resolved at file-unit level
      "rollTitleGrammar": "dateRange",
      "fileUnits": [
        {
          "geoKeys": ["japan"],
          "displayName": "Despatches from U.S. Ministers to Japan",
          "microfilm": "M133",
          "naId": "5716479",
          "rolls": [
            { "naId": "188401761", "title": "Mar. 4, 1905-Aug. 31, 1905",
              "start": "1905-03-04", "end": "1905-08-31", "frames": null }
          ]
        }
      ]
    },
    {
      "category": "diplomaticInstructions",
      "seriesNaId": "593313",
      "geoGranularity": "rollTitle",         // no file units; country in roll title
      "rollTitleGrammar": "volumeCountryDateRange",
      "rolls": [
        { "naId": "149311973", "title": "Volume 18: Great Britain: Aug. 17, 1861 - Sept. 2, 1863",
          "geoKeys": ["great britain"], "start": "1861-08-17", "end": "1863-09-02" }
      ]
    },
    {
      "category": "notesToForeignMissions",
      "seriesNaId": "597272",
      "geoGranularity": "rollTitle",
      "rollTitleGrammar": "countriesDateRange",  // may list >1 country
      "rolls": [
        { "naId": "216926854", "title": "Uruguay and Paraguay: July 7, 1834 - June 26, 1906",
          "geoKeys": ["uruguay", "paraguay"], "chronological": false,
          "start": "1834-07-07", "end": "1906-06-26" }
      ]
    }
  ],
  "numericalFileCases": [
    { "rollNaId": "19779414", "caseStart": 7179, "caseEnd": 7187 }
  ],
  "geoAliases": { "argentine republic": "argentina", "buenos ayres": "argentina" }
}
```

Per-component fields driven by the findings:
- `geoGranularity`: `fileUnit` | `rollTitle` | `none` (Numerical File).
- `rollTitleGrammar`: selects the per-series title parser (Finding 2).
- `geoKeys` is an **array** — a roll can serve multiple countries (Finding 3).
- `chronological: false` suppresses the date-interpolation hint (Finding 3).
- Date parser clamps implausible years against the series era (Finding 2 typo).

**Because the index ships in the bundle and resolved links are static
`catalog.archives.gov/id/<naid>` URLs, the runtime feature requires no API key.**
This is a major UX advantage over the existing lot-file lookups.

### 2. `CentralFilesClassifier` (pure Swift, app target)

Input: header, dateline, country chapter (from `volume_structures`), `date_iso`,
document number. Output: `(category, geoKey, confidence, rationale, alternates)`.

Decision rules (first match wins; all string checks on normalized text):

| Rule | Category |
|---|---|
| Era 2 source note "File No. N[/n]" (1906–1910) | Numerical File — case → roll lookup, near-deterministic |
| Dateline "Department of State" + recipient is a US minister abroad (chapter country) | Diplomatic Instructions to [country] |
| Dateline "Legation/Embassy of the United States, [city]" **or** "American Legation/Embassy, [city]" | Despatches from [chapter country] |
| Dateline "Consulate[-General], of the United States, [city]" | Consular Despatches from [post city] |
| Dateline = foreign legation in Washington (e.g. "Chinese Legation, Washington") or sender is the foreign minister resident in Washington | Notes **from** Foreign Missions, [country] |
| Dateline Washington + recipient is a foreign legation/minister in Washington | Notes **to** Foreign Missions, [country] |
| Sender is a special agent / commissioner on mission | Despatches from Special Agents |
| Fallback | Multi-option card: top 2–3 candidates with the date-matched roll for each |

Notes:
- Telegrams were filed with their parent series (instructions/despatches) — no
  separate handling needed beyond stripping "[Telegram]" markers.
- **Enclosures (dual-homed — Finding 4)**: a printed enclosure physically lives in its
  **own originating series** (derive from the *enclosure's* dateline), while the
  covering document's roll only *references* it. Offer both targets, labelled "holds the
  document" vs. "references it (filed with covering No. N)". TEI nests the enclosure in
  the parent `<div>`, so both the parent metadata and the enclosure's own `<dateline>`
  are available.
- **Country from chapter, not name parsing (Finding 5)**: resolve the geo key from the
  FRUS chapter head rather than parsing the correspondent's name — the recipient's
  country is sometimes only identifiable from an adjacent document.
- Geographic normalization needs an alias table (FRUS "Argentine Republic" vs. NARA
  "Argentina"; historical entities — Two Sicilies, Hawaii, German States, Texas; city
  spellings — "Buenos Ayres", "Canton", "Amoy"). Seed from harvest output + FRUS
  chapter heads; extend from reference-data findings.

### 3. Source Explorer integration

Upgrade `centralFilesPanel` (`SourceExplorerView` / `MacSourceExplorerView`) for
`.centralFiles` documents in the pre-1910 range:

- **"Inferred archival location" card**: component → country/post file unit → the
  roll whose date range covers `date_iso`, with the item-level catalog link (and
  consolidated-PDF link when the harvest captured it).
- **Adjacent rolls (±1)** as a hedge against filed-by-receipt-date drift.
- **Verification hint**: "Look for despatch No. 769, Feb 3, 1900. Chronological
  filing places it roughly 55% into this roll" (linear date interpolation across the
  roll's range — cheap and useful for the page-by-page step). **Only shown for
  single-country chronological rolls** (Finding 3); for combined / Notes rolls, show the
  date range + correspondents + document number and a "scan this country's section" note.
- **Confidence + rationale** displayed; alternates listed when the classifier is
  uncertain. Keep the existing period-page link as the fallback row.
- For Era 2: case-number lookup against `numericalFileCases` + a Card Index (M1889)
  link as the secondary path.

---

## Phasing

| Phase | Scope | Confidence | Effort |
|---|---|---|---|
| 1 | Numerical File 1906–1910: "File No." → case → M862 roll; Card Index link | Near-deterministic | Small — parser already extracts the file number; needs M862 harvest (1,241 roll titles) + UI card |
| 2 | Four country-arranged diplomatic series (Despatches, Diplomatic Instructions, Notes from/to Foreign Missions) | High for the three dateline-driven rules | Medium — classifier + geo aliases + harvest of 4 series |
| 3 | Consular Despatches (post-city matching, hundreds of posts), Consular Instructions, Notes to/from Consuls, Domestic/Miscellaneous Letters, Special Agents | Medium (consular post matching); chronological-run series are date-only and easy | Larger |

---

## Risks and open questions

1. **Item-title formats** are the main unknown: the harvest depends on parsing roll
   titles for date/case ranges. The blog posts confirm the structure; exact strings
   could not be verified without an API key (catalog pages are a JS shell; the
   unauthenticated v1 endpoint is gone). First harvest run is a survey; where titles
   don't parse, fall back to the file-unit-level link — still far better than today.
2. **Filing date vs. document date**: despatches were bound roughly by despatch date,
   but receipt-date filing can shift a document a roll over → show adjacent rolls.
3. **Coverage gaps**: Consular Instructions digitized only to 1834; occasional FRUS
   documents originate outside State (War/Navy/White House). Degrade to a
   lower-confidence multi-option card, never a hard failure.
4. **Index size**: est. 10–20k roll entries across all series. Fine as bundled JSON
   (compare manifest.json); load lazily in the Source Explorer path only.
5. **Harvest rate limits**: offline, one-time per refresh; respect the key's limits
   with paging delays.

---

## Extension: bundled index for the existing Source Explorer scope

Assessed 2026-06-11 (follow-up question). The harvest-tool → bundled JSON → key-less
runtime pattern generalizes to the **entire** Source Explorer scope, because the
citation key universe is small and closed. Measured on the user's fully-indexed corpus
(552 volumes, 191,922 document-source rows; note the index predates the Session 130/151
parser, so era labels are stale but raw text is complete):

| Key universe | Measured | Notes |
|---|---|---|
| Distinct lot numbers (doc + front-matter union) | 984 (~1,200–1,500 after current parser catches the 5,240 `unrecognized` rows containing "Lot") | The single biggest runtime API consumer today (`resolveLotFileVariants`, 2–4 calls each) |
| Distinct front-matter collections (repository, RG, series) | 965 | `volume_sources` — the natural normalized key set; the 87,923 noisy doc-level (RG, series) strings map onto these locally via string matching, zero API calls |
| Distinct record groups | 35 | |
| Distinct repositories | 32 | Presidential libraries mostly resolve to static finding-aid URLs anyway |
| Presidential library (library, collection) pairs | ~600–1,000 est. | Most return zero catalog hits; static fallbacks remain |

**Citations outside source notes** resolve through the same index because the index is
keyed by *normalized citation*, not citation location. Already extracted at index time:
editorial-note body citations (`document_sources.citation_era='footnote'`, currently
first-citation-only) and front-matter sources (`volume_sources`). Gaps requiring
indexer work before they can feed the index:
1. `extractCitations` runs only on editorial-note bodies — extend to footnote text of
   all documents.
2. `document_sources` PK is `(volume_id, document_id)` — one citation per document.
   Multiple embedded citations need a separate table (cf. the `external_citations`
   sketch in `130-ExternalRefs-GraphFeasibility.md`) or a relaxed key.

### API call budget (one-time initial harvest)

| Component | Keys | Calls/key | Subtotal |
|---|---|---|---|
| Pre-1910 series enumeration (~16 series, ~10–11k descriptions) | — | paged | 120–500 (page size 100 vs 25) |
| Lot files (`variantControlNumber_is` ladder) | ~1,200–1,500 | 2–4 | 3,000–6,000 |
| Front-matter collections (RG + series keywords) | ~1,000 | 1 | ~1,000 |
| Presidential library pairs | ~600–1,000 | 1 | ~1,000 |
| Decimal / subject-numeric / CFPF series-level descriptions | — | — | ~100 |
| **Subtotal** | | | **~5,200–8,600** |
| Development re-runs / retries (×1.5 with response caching) | | | **~8,000–13,000** |

NARA's default API limit is **10,000 queries per month per key**; exceeding it blocks
the key until the 1st of the next month ([API help](https://www.archives.gov/research/catalog/help/api)).
The initial harvest straddles that ceiling, so: (a) the harvest tool **must cache raw
JSON responses to disk** so parser iterations never re-query, and (b) a higher limit
should be requested from **Catalog_API@nara.gov** before the first full run (~50k/month
temporary, citing the one-time bulk-description harvest for an open-source research
app). Post-initial refreshes are incremental and fit comfortably in the default limit.

---

## Validation plan

User-provided reference data for 10 manually-traced documents — collection template
and field definitions in `Planning/Pre1910-CentralFiles-Reference-Data.md`. The set
doubles as the acceptance fixture: the classifier + index must reproduce the
user's roll-level link (or list it among alternates) for ≥8 of 10, and the failures
must be explainable by a documented risk above.

---

## Sources

- [Central Files 1789–1910 omnibus](https://text-message.blogs.archives.gov/2023/07/11/department-of-state-central-files-1789-1910-available-online-an-omnibus/)
- [Despatches, Notes from Foreign Missions, Domestic/Misc Letters](https://text-message.blogs.archives.gov/2021/02/02/now-available-online-department-of-state-records/)
- [Diplomatic & Consular Instructions](https://text-message.blogs.archives.gov/2021/11/18/now-available-online-diplomatic-instructions-consular-instructions/)
- [Consular Despatches 1783–1906](https://text-message.blogs.archives.gov/2021/08/05/now-available-online-consular-despatches-1783-1906/)
- [Numerical and Minor Files](https://text-message.blogs.archives.gov/2021/02/16/now-available-online-numerical-and-minor-files/)
- [Special Agents, Notes to Foreign Missions, Notes from Foreign Consuls](https://text-message.blogs.archives.gov/2021/10/14/department-of-state-online-despatches-from-special-agents-etc/)
- [NARA Catalog-API bulk scripts (`ancestorNaId` pattern)](https://github.com/usnationalarchives/Catalog-API)
- [NARA digitized microfilm master list (PDF)](https://www.archives.gov/files/nara-digitized-microfilm-updated-2.21.23.pdf)
