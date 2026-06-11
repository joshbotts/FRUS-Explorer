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

## Proposed architecture

Three components, each matching an existing pattern in the repo:

### 1. `CentralFilesIndexGenerator` (new SPM command-line tool)

Sibling of `ManifestGenerator` / `TaxonomyGenerator`. Offline, occasional harvest run
(requires a NARA API key via env var, like NARA's own scripts):

- For each series NAID above, page through `ancestorNaId` results.
- Parse **file-unit titles** → country / consular post / microfilm publication number.
- Parse **item titles** → roll number + date range (or case-number range for M862).
- Emit `Resources/central-files-index.json`.

Sketch of the bundled index:

```json
{
  "generated": "2026-06-11",
  "components": [
    {
      "category": "diplomaticDespatches",
      "seriesNaId": "603720",
      "fileUnits": [
        {
          "geoKey": "argentina",
          "displayName": "Despatches from U.S. Ministers to Argentina",
          "microfilm": "M69",
          "naId": "…",
          "rolls": [
            { "naId": "…", "title": "Roll 30", "start": "1899-01-01",
              "end": "1900-12-31", "frames": 980 }
          ]
        }
      ]
    }
  ],
  "numericalFileCases": [
    { "rollNaId": "…", "caseStart": 5727, "caseEnd": 5740 }
  ],
  "geoAliases": { "argentine republic": "argentina", "buenos ayres": "argentina" }
}
```

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
| Dateline "Department of State" + recipient at a foreign post (chapter country) | Diplomatic Instructions to [country] |
| Dateline "Legation/Embassy of the United States, [city]" | Despatches from [chapter country] |
| Dateline "Consulate[-General] of the United States, [city]" | Consular Despatches from [post city] |
| Dateline = foreign legation in Washington (e.g. "Chinese Legation, Washington") or sender is the foreign minister resident in Washington | Notes **from** Foreign Missions, [country] |
| Dateline Washington + recipient is a foreign legation/minister in Washington | Notes **to** Foreign Missions, [country] |
| Sender is a special agent / commissioner on mission | Despatches from Special Agents |
| Fallback | Multi-option card: top 2–3 candidates with the date-matched roll for each |

Notes:
- Telegrams were filed with their parent series (instructions/despatches) — no
  separate handling needed beyond stripping "[Telegram]" markers.
- **Enclosures**: FRUS frequently prints enclosures; TEI nests them inside the parent
  document `<div>`, so the parent's metadata drives the lookup — handled naturally.
  The archival location shown should mention "filed with covering despatch No. N".
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
  roll's range — cheap and genuinely useful for the page-by-page step).
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
