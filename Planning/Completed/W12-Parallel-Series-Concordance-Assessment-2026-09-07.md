# W-12: parallel-series concordance — SCORING REPORT

**Status: SCORED 2026-09-07. THE FEATURE IS DEFERRED INDEFINITELY — owner decision, same date.**

**This document is a record of research, not a plan of work.** It exists so that a future revisit
starts from measured ground instead of re-deriving it, and so the backlog text that prompted it is not
re-proposed on premises this session refuted. Nothing here is scheduled, and the costings in §4 and
the sequence in §6 are **recorded pricing, not a commitment** — read them as *what it would take*,
never as *what is planned*.

Row A-1 / Tier-E **W-12** of `Tier-E-Assessment-2026-08-27.md`. Five researchers swept the five
candidate series against their official sites; every join figure below was re-run in this session
against the shipped `FRUSExplorer/Resources/manifest.json`, not inherited.

## The scores

Tractability per target, on the evidence in §2. **No row is a recommendation to build.**

| target | score | what the score rests on |
|---|---|---|
| **AAPD** (Germany) | **Tractable — 40 rows, derivable** | Strictly annual; the coverage year is a machine-readable *field*, not a title to be read; 35 of 40 volumes free. The only target where a table could be generated rather than curated. |
| **Dodis** (Switzerland) | **Tractable — 34 rows, with a caveat** | Open API + downloadable SQL dump + CC BY 4.0; reaches 540 of 552 FRUS volumes. **The official dump carries two verified date errors**, so it would have to be curated rather than imported. |
| **DDF** (France) | **Partly tractable — 113 of 185** | Tiers 1–2 (1914–1974) are day-precise and cheap. Tier 3 (1863–1914, 72 rows) has **no per-volume date source** at all. |
| **DBPO** (UK) | **Barely tractable — 1 row, series grain** | Thematic rather than chronological; 27 of 29 volumes paywalled, so real coverage cannot be checked; the one volume where it *could* be checked proved its own title range wrong by 206 FRUS matches. |
| **Wilson Center Digital Archive** | **Not tractable — refused twice over** | Its collections carry no date metadata at any grain, **and the host has not resolved since ~April 2026**. |
| **The join as briefed** — date overlap on `dateRange` | **Refuted** | Returns a *median of 6 counterpart volumes per FRUS volume from two series alone* (max 18). A list, not an answer. The corrected key is in §1.1 and costs nothing. |

### Why it is deferred — the owner's reason, stated 2026-09-07

**Expanded maintenance obligations for only a partial internationalisation of perspective: every
series that survived the research is European.**

The research did not fail. It produced a workable reduced design (§1.1's key, §1.2's collapsed rows,
~187 rows). What it also produced, without anyone setting out to, was a **skewed** feature. The four
tractable targets are **Germany, Switzerland, France and the United Kingdom** — four Western European
foreign ministries. A panel captioned *"parallel editions"* on a corpus documenting US relations with
the whole world would, in practice, mean *"what Western Europe published about the same months."*

**And the refusal is what caused the skew.** The Wilson Center Digital Archive was the only candidate
carrying non-Western material — translated Soviet, Chinese, East European and Korean documents. Losing
it (§1.3: no date metadata at any grain, *and* the host offline since ~April 2026) did not cost one
source in five. It removed the **only** non-European perspective and left a set that is uniformly
European by accident rather than by design.

Against that partial gain sits a **permanent** cost, and it is not the build: it is the **re-stamp
cadence**. Every target is a foreign ministry's website; two have already changed publisher
mid-series, one sits behind a proof-of-work wall, and **one vanished during the week this report was
written**. A curated link table is a standing promise to keep checking, indefinitely — a promise
renewed forever in exchange for a perspective that only widens in one direction.

**What would reopen it:** a keyable non-European source. A Soviet/Russian, Chinese, Japanese, Indian,
Latin American, African or Middle Eastern series with per-volume date coverage would change the
feature's *meaning*, not merely its row count — at which point the maintenance obligation buys
something the corpus does not already lean toward. A machine-readable concordance published upstream
would lower the cost, but **cost was not the deciding factor and lowering it does not by itself
reopen this.**

---

## 1. The premises, corrected

The brief already corrected two (no era tags; region cannot discriminate — a volume touches a mean of
4.66 of 7 regions). Both re-affirmed. **Three more did not survive.**

### 1.1 `dateRange` alone is *not* the clean join key

The brief calls it "the clean join key. Median 3 years, mean 5, max 252." All three numbers are right
and the conclusion is wrong. Measured over all 552 volumes:

| | value |
|---|---|
| `dateRange` populated, both ends, ISO | **552 / 552** |
| span (end year − start year): median / mean / max | **3 / 5 / 252** |
| volumes with a span ≥ 10 years | **30** |
| ≥ 20 years | **12** |
| ≥ 50 years | **8** |

Those long spans are **editorial tails, not coverage**. Four real rows:

| volume | `dateRange` | `subseries` | what it is |
|---|---|---|---|
| `frus1872p2v5` | 1620-11-03 → 1872-12-02 | `1872` | the 252-year volume; a 1620 document in an 1872 annual |
| `frus1952-54Guat` | 1952-01-11 → **1975**-05-12 | `1952-54` | a 1975 document in the Guatemala retrospective |
| `frus1945Berlinv02` | 1945-02-11 → **1960**-03-28 | `1945` | Potsdam, with a 1960 tail |
| `frus1981-88v01` | **1975**-11-20 → 1989-01-11 | `1981-88` | Foundations of Foreign Policy |

**The fix is already in the bundle and costs nothing.** `manifest.json` carries a `subseries` string on
every volume, and **all 107 distinct values parse as a year or a year range** (`1861`, `1952-54`,
`1969-76`, `1917-72`) — checked, 107 of 107, no exceptions. Intersecting the two:

| key | span median | span max | empty results |
|---|---|---|---|
| `dateRange` | 3 y | **252 y** | — |
| `subseries` | 0 y | 55 y | — |
| **`dateRange` ∩ `subseries`** | **0 y** | **10 y** | **0 of 552** |

Zero empty intersections across the whole corpus. `frus1872p2v5` collapses from 253 years to 1872;
`frus1952-54Guat` to 1952–1954. **This is the join key, and it is a display-time computation over two
fields already in the manifest** — no parse change, no `currentDateIndexVersion` bump, no re-index.

### 1.2 The overlap join floods, and the flood is the design problem

Joining **only** AAPD (41 intervals) and DBPO (31 intervals) against the corpus:

| key | FRUS volumes with ≥1 match | pairs | median | mean | max |
|---|---|---|---|---|---|
| `dateRange` | 320 | 2,305 | 7 | 7.2 | **26** |
| `dateRange` ∩ `subseries` | 304 | 1,771 | **6** | 5.8 | **18** |

79 volumes draw ≥10 matches from those two series alone. Adding DDF (185 volumes, semi-annual through
the modern era — roughly 1.7 volumes per covered year) and Dodis (34, measured mean 1.95) puts a
typical mid-century FRUS volume at **a dozen or more counterpart rows**. A panel that lists them is
worse than no panel.

**Consequence for the design, and it is the main one:** the surface must render **one collapsed row per
series** — *"AAPD — 8 volumes, 1969–1976"* — expandable to the individual volumes, never a flat list.
This also happens to be what makes the cheap DBPO treatment (§2.4) coherent with the rest.

### 1.3 There are four candidate series, not five

The Wilson Center Digital Archive is gone. `digitalarchive.wilsoncenter.org` is a CNAME to a Cloudflare
target that returns **NOERROR with zero answers** — no A record; `curl` cannot resolve it; two WebFetch
attempts failed `ENOTFOUND`. Control: `www.wilsoncenter.org` returns HTTP 200, so this is not a network
artefact. Wayback: every capture from 2026-01-16 to 2026-04-20 is **403**, and there is **no capture at
all after 2026-04-20**; the last status-200 snapshot is 2025-09-25. Its JSON API was switched off
around 2022 (the unofficial client's repo states it verbatim and was archived 2022-12-06).

**And it would have been refused even if it were up.** Its unit is a thematic *Collection*, and the
archived API records — list (`/srv/collection.json`) and detail (`/srv/collection/9.json`) — were
scanned field by field for any date/year/start/end/period key. The only hits are ingest timestamps
(`source_updated_at = 2013-02-11 12:01:17`). **Collections carry no coverage dates at either grain.**
Only individual documents do. There is nothing to key a volume-to-volume table against.

---

## 2. The four series, priced

Every URL below was fetched by a researcher in this session. Row counts are *counted*, never estimated;
where a count could not be established, it says so.

### 2.1 AAPD — Germany — **derivable, 40 rows, the cheapest target**

*Akten zur Auswärtigen Politik der Bundesrepublik Deutschland*, ed. Institut für Zeitgeschichte
München–Berlin for the Auswärtiges Amt.

- **Structure: strictly annual.** IfZ's own abstract: 40 *Jahresbände* in 92 *Teilbände*, 16,299
  documents, through 1995. One irregularity — a double first volume, 1949/1950.
- **Coverage: 1949/50–1954 and 1961–1995, with a real, open gap at 1955–1960** (pre-1963 years are
  filled "ohne vertragliche Verpflichtung"; no schedule found).
- **The date is a field, not a title.** `publicationvolume.volumeNumber` carries the *coverage* year on
  35 of 35 repository records, distinct from `dc.date.issued` (the print year). Use it; the titles are
  inconsistent (one Crossref title is bare `"1986"`).
- **Access: 35 of 40 free**, verified by download, not by claim — AAPD 1963's PDF fetched
  unauthenticated at 56,033,239 bytes. Paywalled: 1954, 1992–1995. A four-year moving wall advances one
  volume per year.
- **Two traps, both measured.** The DSpace *search* endpoint returns 34 of 35 — **AAPD 1976 is missing
  from the index** though the item is live and downloadable; use the relationships endpoint or the
  sitemap. And **De Gruyter's own access flags are wrong** (1963 and 1978 marked "Requires
  Authentication" while both download free from IfZ), so the free/paywalled column must come from IfZ.
- **Licence:** not CC. 32 of 35 carry *"…erlaubt zu privaten, wissenschaftlichen und
  nicht-kommerziellen Zwecken"*; three (1989–1991) carry no statement. Immaterial for links; binding on
  any mirroring.
- **Join, recomputed here:** 40 rows → **246 of 552 FRUS volumes (44.6%)**, **964 pairs** modelling
  1949/50 as one interval (980 if modelled as two — the researcher's figure; the difference *is* the
  double volume, and one interval is the honest model). Mean 3.9, max 18.
- **Curation cost: effectively zero.** The researcher built the complete 40-row table programmatically
  in a handful of API calls. Only the 5 paywalled DOIs are hand-copied.

### 2.2 Dodis — Switzerland — **34 rows, an open dump, and two errors in it**

- **Structure: mixed.** DDS 1–27 (vol. 7 split 7-I/7-II) are irregular editor-chosen period volumes —
  vol. 1 spans 17 years, vol. 22 spans 2.5 — with boundaries pinned to events (vol. 6 opens 1914-06-28;
  vol. 16 opens 1945-05-09). DDS 1990–1995 are annual, on a different slug scheme.
- **A structural gap: nothing published covers 1979–1989.** DDS-28 (1979–82) exists as a page labelled
  *"Funding not yet secured."*
- **Three independent machine-readable date sources**: typed `date_lower`/`date_upper` columns in the
  downloadable SQL dump (23 MB, 2024-11-15, 31 tables); the span in each volume page's title, to the
  day for vols 16–26; and `doc_dateRange` on every document, from which volume bounds can be
  re-derived. A live facet call answers the whole concordance question in one GET, with a passing
  negative control (a 2200–2300 window returns zero).
- **DO NOT IMPORT THE DUMP UNCHECKED.** Cross-checking dump bounds against live per-volume document
  min/max found **two real errors**: `dds-3` declares `date_upper` 1879-12-31 against a true 1889
  (wrong by ten years — a naive join silently loses the 1880s), and `dds-1991` declares 1991-01-31
  against 1991-12-29. 32 of 37 agree exactly; three more differ only by documents falling outside a
  declared span, which is normal editorial practice.
- **Licence: CC BY 4.0**, stated on the site's own Open Science page and Impressum, and the entire
  printed edition is free to download (verified by HEAD: DDS-1.PDF 57.9 MB, DDS-1991.pdf 8.80 MB).
  **The only unambiguously reusable dataset of the four.**
- **URLs are stable but NOT synthesisable**, verified rather than assumed: vol. 25 is not at `/en/DDS-25`
  but at `/en/dds-vol-25-111970-31121972`; the split volume is `/en/DDS-7-1`; forthcoming volumes are
  linked under `/de/`; and download hrefs come in three shapes with inconsistent extension case
  (`DDS-1.PDF` vs `DDS-27.pdf` vs `/sites/default/files/doc/DDS-1991.pdf`). **Take the href off the
  page; never construct it.**
- **One operational note for the link checker:** the apex `dodis.ch` — where document permalinks point —
  is behind Anubis proof-of-work and refuses automated fetches; `www.dodis.ch` and the API host are not.
  Store `www.` links, or `Scripts/check_repository_links.py` needs a vocabulary entry beside its D19
  403 rule.
- **Join:** the researcher measured 34 published volumes → **540 of 552 (97.8%)**, 1,078 pairs, median 2,
  max 9. **Independently reproduced here**: exactly **12** FRUS volumes fall outside the published
  Swiss union (1848–1978 ∪ 1990–1995), and they are precisely `frus1977-80v11p1` plus eleven
  `frus1981-88` volumes — the 1979–89 funding gap, not a defect.
- **Caveat that must reach the screen:** reach is not relevance. DDS is Swiss-focused; a two-year
  overlap with a FRUS volume on Vietnam says only that both editions print documents from those years.

### 2.3 DDF — France — **113 of 185 rows; day-precision dates and five real gaps**

*Documents diplomatiques français*, Commission de publication at the MEAE, La Courneuve. Nine sub-series
under nine named academic directors, not one continuous run.

- **185 volumes are digitised and free** on the ministry's own digital library, each with a BnF **ARK**
  that resolves on two independent hosts (`bibliotheque-numerique.diplomatie.gouv.fr` *and*
  `gallica.bnf.fr`) — the strongest persistent identity of the four. 76 ARK record pages were resolved
  in this session; no 404s.
- **Dates are explicit and day-precise, and mostly parse.** 77 of 81 modern-series link labels converted
  straight to ISO day ranges by first-pass script; the 4 failures are trivial. Nine official per-series
  PDFs (all HTTP 200, all `Last-Modified: 21 Oct 2025`) carry the authoritative lists.
- **THE GAPS ARE THE HEADLINE.** The series is *not* continuous. Unpublished periods:
  **1917-01 → 1918-09-26**, **1924-07 → 1931-12** (seven and a half interwar years), **1942 → 1944-09**,
  **1953 → 1954-07**, and post-1974-06. Measured against the corpus: **4 FRUS volumes fall wholly inside
  the 1925–31 gap, 2 inside 1942–43, and 40 begin after the 1974 frontier.** *"No French volume covers
  this period"* must be a first-class outcome of the feature, not an empty state.
- **Two traps for a date join.** *Annexes* volumes repeat their parent tome's span (Vol. 3 and Vol. 4
  are both 1 Jan–30 Jun 1955). And **parallel governments overlap deliberately**: Vichy (1 Jan–31 Dec
  1941) and France Libre–Londres (18 Jun 1940–31 Dec 1941) are the same dates from two competing
  authorities and **must not be de-duplicated**.
- **Licence:** the BDN's own terms state non-commercial reuse is *"libre et gratuite"* with a source
  credit and **commercial reuse is chargeable**. Every sampled record carries `DC.rights = "domaine
  public"`. Links plus bibliographic facts are unproblematic; bundling page images would not be.
- **Tiering, which is where the subset comes from:**
  - **Tier 1 — 81 rows, ~30 min.** Volume number, date range and ARK all in one anchor on one page.
    Covers every DDF volume that meets a 20th-century FRUS volume.
  - **Tier 2 — 32 rows (1932–1939), ~30 min.** ARKs from the site, day ranges from the ministry PDFs,
    joined by ordinal. One documented trap: the 1932–35 list prints 14 tome lines for 13 distinct
    volumes (a re-edition footnoted as an error), which is why the PDF's 33 and the site's 32 disagree.
  - **Tier 3 — 72 rows (1863–1914), 2–4 h, DEFERRED.** `ddf-avant-1914.pdf` is **prose, not a list** —
    it gives only aggregate counts. Roughly half the catalogue titles carry a range; the whole 2e série
    (1901–1911) carries none. These would have to come from a reference work or the volumes themselves.
- **Join:** at year granularity over the published union, **504 of 552 (91.3%)**. Deferring tier 3
  costs the 1861–1914 FRUS volumes their French row — and those volumes are already served by Dodis,
  which covers 1848 onward.

### 2.4 DBPO — UK — **one row, and that is the honest maximum**

*Documents on British Policy Overseas*, FCDO Historians. 29 volumes across three series, 1944–1990.

**This is the series the brief's premise fits worst, and the evidence is unusually sharp.**

- **It is thematic, not chronological**, and increasingly so. ProQuest's editorial guide states it
  plainly: after Potsdam, *"volumes are organised around specific themes rather than proceeding in a
  strict chronological series."* Series III is organised by episode or bilateral relationship —
  *The Invasion of Afghanistan and UK-Soviet Relations, 1979-82*; *The Challenge of Apartheid,
  1985-1986* — and two volumes cover the same years from different angles.
- **All 29 titles carry a year or range, and the range can be a lie.** *Berlin in the Cold War,
  1948-1990* actually prints three discrete windows — 1948-49, 1959-61, 1988-90 — a fact recoverable
  only because Routledge's marketing blurb happened to say so. **Recomputed here: the title span matches
  305 FRUS volumes; the three real windows match 99. One volume produces 206 false matches** — 13% of
  every pair a naive 29-row join emits. And splitting it correctly drops the series' total FRUS reach
  from 342 to 303, meaning **39 FRUS volumes were being matched *only* by an interval that is wrong.**
- **The other 28 cannot be checked. 27 of 29 volumes are paywalled or out of print**; there is no free
  source stating any volume's real coverage. Shipping their title ranges is shipping 28 unverified
  intervals, at least one of which is known by construction to be the Berlin case's sibling.
- **No machine-readable list exists, and four things that look like one were each checked and failed**:
  gov.uk has no DBPO page at all (`api/search.json` for the series title returns `total: 1`, unrelated;
  four plausible paths 404; `history.fcdo.gov.uk` does not resolve); the ICEDD WordPress REST API
  exposes 4 of 29 volumes as announcements; Routledge's sitemap holds exactly 13 of 29 (verified by
  grepping 217,533 product URLs for six other title fragments — 0 hits each, so 13 is real, not a slug
  artefact); Crossref matches a *different, overlapping* 13, addressable only by fuzzy title search
  because all 15 print ISBNs return zero. **Union: 14 of 29 have any publisher web identity; 15 have
  none.** No FCDO or National Archives URL exists for any volume.
- **The only complete list is a hand-typed third-party page** (ICEDD `?pdb=36`) **with a verified typo**
  — it prints Series III IX as "UK-**Soviet** Relations" where the publisher says "UK-**South African**"
  — and a one-year date disagreement with Routledge on Series I X. The National Archives' own research
  guide says "18 Volumes", wrong by eleven.
- **No licence or reuse terms for the metadata were found anywhere.**

**Verdict:** curating 29 intervals costs a couple of hours and produces a table whose errors are
invisible to the reader — the exact failure mode this assessment exists to prevent. Ship **one row**:
the series, its 1944–1990 span, the volume count, a link to the list, and the sentence *"organised by
theme, not by period."*

**One extension worth naming.** DBPO's chronological predecessor, **Documents on British Foreign
Policy 1919–1939 (64 volumes, month-precise titles, listed free on the same ICEDD page)**, date-joins
far more cleanly than DBPO ever will. If a British row is wanted at volume grain, that is the
better-behaved dataset — and its 64-row count is itself unreconciled (TNA says 68), so it needs its own
pass, not an assumption.

---

## 3. The artifact a build would need — designed, not created

*No file was added. `curated-parallel-editions.json` does not exist and is not scheduled; this section
records the shape it would take, so a revisit inherits the design decisions rather than re-making them.*

### 3.1 Name and posture

**`FRUSExplorer/Resources/curated-parallel-editions.json`** — the `curated-lot-resolutions.json` /
`curated-library-resolutions.json` family, and their rule verbatim in the `note` field: **no generator
writes this file.** Every row is a human reading of a publisher's page; a re-harvest must never
overwrite it. There is no generator to write it *with*: two of the three buildable series have no
enumerable index at all, and the two that do (IfZ DSpace, Dodis dump) are exactly the two whose
automated routes were measured wrong — AAPD 1976 missing from the search index, `dds-3` wrong by a
decade.

**The outbound links are the exception, and they must be Swift, not JSON.** `Scripts/check_repository_links.py`
parses `RepositoryLink(url:...)` out of *Swift source* tables by design (`RepositoryFactTable`,
`PublishedSourceLinkTable`), and D12's discipline is that **a link with no `verifiedDate` does not
print**. Either the link column lives in a Swift `ParallelEditionLinkTable` beside the JSON intervals,
or the checker gains a second reader. **The Wilson Center is the argument for this**: a link table
built on that host in 2024 would today ship 126 dead links and say nothing.

### 3.2 Row shape

Half-open `[start, end)` intervals, the `administrations.json` convention (`end` mirrors the next
volume's `start`; ISO dates; day precision where the source has it, 1 January / 1 January where it does
not).

```jsonc
{
  "schemaVersion": 1,
  "generated": "2026-09-07",
  "note": "Hand-curated. No generator writes this file … intervals are half-open [start, end).",
  "series": {
    "aapd": {
      "name": "Akten zur Auswärtigen Politik der Bundesrepublik Deutschland",
      "short": "AAPD", "country": "DE", "language": "de",
      "editor": "Institut für Zeitgeschichte München–Berlin, for the Auswärtiges Amt",
      "grain": "volume",
      "coverage": [ {"start":"1949-01-01","end":"1955-01-01"},
                    {"start":"1961-01-01","end":"1996-01-01"} ],
      "gaps": [ {"start":"1955-01-01","end":"1961-01-01",
                 "note":"Worked on without contractual obligation; no announced schedule."} ],
      "access": "35 of 40 volumes free; four-year moving wall",
      "rights": "Non-commercial scholarly use (German copyright statement); not CC."
    }
  },
  "volumes": [
    { "series": "aapd", "id": "aapd-1978", "label": "AAPD 1978",
      "start": "1978-01-01", "end": "1979-01-01",
      "intervalSource": "publisherMetadata",
      "rationale": "Coverage year from DSpace publicationvolume.volumeNumber (distinct from dc.date.issued 2009). Annual volume; the two Teilbände split at 30 June but no metadata records it.",
      "access": "free" }
  ]
}
```

`intervalSource` is load-bearing and has exactly four values, because the four series were established
four different ways: **`publisherMetadata`** (AAPD's DSpace field, DDF's ARK catalogue title),
**`officialList`** (the MEAE per-series PDFs), **`curatorRead`** (a human opened the volume or its
contents page), **`titleRange`** (parsed from a title and *not* otherwise confirmed). A `titleRange` row
is the Berlin case, and the surface should say so rather than pretend a title is a finding aid. The
recommended build ships **zero** `titleRange` rows.

### 3.3 The matching rule

```
frusCoverage(v) = [ max(v.dateRange.earliest, startOfYear(v.subseriesStart)),
                    min(v.dateRange.latest,   endOfYear(v.subseriesEnd))     )      // §1.1
match(v, p)     ⟺  frusCoverage(v).start < p.end  ∧  p.start < frusCoverage(v).end   // half-open
```

Both operands are already in `manifest.json`; the rule runs at display time. **No `currentDateIndexVersion`
bump, no re-index, no `@Model`, no CloudKit deploy** — this feature touches none of the three gates.

**The 252-year volume, specifically.** `frus1872p2v5` carries `dateRange` 1620-11-03 → 1872-12-02 and
`subseries` `1872`. Under `dateRange` alone it would match every DDF *Recueil* volume (all 29 lie inside
1863–1870, inside the span) plus the earliest Swiss volumes, on the strength of one 1620 document.
Under the intersection it matches **1872 only**, which is what the volume is. Measured across the whole
corpus, the intersection produces **0 empty results in 552** and caps the maximum span at 10 years.
A second guard is still warranted — *if the intersected span exceeds 12 years, render series-grain rows
only* — which today fires on zero volumes and exists against a future manifest, not against this one.

---

## 4. What a build would cost — recorded, not scheduled

*Priced so a revisit need not re-derive it. The feature is deferred; nothing below is planned work.*

| | rows | curation | source quality |
|---|---|---|---|
| AAPD | 40 | **~0** (built programmatically in-session; 5 DOIs hand-copied) | field-level |
| Dodis | 34 | **~1 h** (parse the dump, then a mandatory 20-min cross-check against page titles — it is what caught the ten-year error) | field-level, two known errors |
| DDF tiers 1–2 | 113 | **~1 h** | official PDFs + ARK titles |
| DBPO | 1 | ~10 min | series index only |
| Wilson | 0 | — | refused |
| **total** | **188** | **~2–3 h** plus a careful re-read | |

Plus DDF tier 3 (72 rows, 2–4 h) if the pre-1914 corpus is ever to have a French row.

**Engineering:** one bundled JSON + one loader (the `VolumeSubjectProfiles` shape — lazily loaded,
not at app init) + one shared row view + **two hosts**: `Browser/VolumeView.swift`'s `List` (iOS/iPadOS)
and `CorpusVolumeDetailView` in `App/MacCorpusBrowserWindow.swift` (macOS). "Top subjects" is the exact
precedent — one shared `VolumeSubjectsChips` hosted twice with two localized keys
(`browser.volume.subjects.header` / `corpus.volume.subjects.header`) — and it is also the warning: these
are hand-maintained twins, so the collapsed/expanded decision belongs in the shared view, not in each
host (the Source Explorer twin-drift rule). Plus the link table + checker extension + tests.
**~1 session.**

**Maintenance:** AAPD gains one row per year and flips one row from paywalled to free per year; DDF
gains one row every year or two (and has already changed publisher mid-series, Peter Lang →
Hémisphères, so the table needs a publisher column); Dodis gains one row per year with two forthcoming
volumes already dated. Plus a `--stamp` pass at each release.

---

## 5. What it would be called, and where it would live

*Naming was resolved because the collisions are the durable part — they will still be true whenever
this is reopened. No surface was added.*

**"Concordance" is taken** — it is the shipped KWIC mode in `SearchSheet` / `SearchViewModel`
(`showConcordance`, `ConcordanceResult`, `ResultReading.concordance`), with its own denominator
caption. **"Related" is taken** by the Related list (shared persons 0.7 / shared subjects 0.5).

**The name that survives the collisions: `Parallel editions`.** Checked against the source tree — no user-facing string begins
with "Parallel" and there is no localized `Elsewhere` default, so both are free. Subtitle line:
*"Other governments' document series printing documents from these years."* That sentence is the honest
claim: **shared years, not equivalent volumes.**

Rejected: *Counterpart volumes* (asserts equivalence the date join cannot support), *Companion editions*
(reads as a publisher's boxed set), *Sister series* (same problem plus a gendered idiom to localize).

**Where it lives: a Section on the volume page, below "Top subjects"** — not a seventh Browse tile. The
data is per-volume and answers a question a reader has while looking at one volume; a browse axis would
imply you can navigate *into* the other series, which the app cannot do. Rendered as **one row per
series**, collapsed:

```
Parallel editions
  AAPD (Germany)        1969–1976 · 8 volumes            ›
  DDF (France)          1969–1974 · 11 volumes           ›
  Dodis (Switzerland)   1967–1978 · 2 volumes            ›
  DBPO (United Kingdom) organised by theme — browse ↗
  France: no volume covers 1975–1976
```

The last two lines are the feature's real content: an honest *"no volume covers this"* (DDF's five gaps,
AAPD's 1955–60, Dodis's 1979–89) and an honest *"this series is not organised by period."* Expanding a
row lists its volumes with stamped links. A volume older than 1848 shows the section empty or absent —
2 FRUS volumes end before 1863, and 210 end before 1944.

---

## 6. The order it would have to be done in, if it is ever revived

*Recorded for the same reason as §4. This is not a schedule, and no part of it is queued.*

1. **Owner curates AAPD (40) and Dodis (34)** into `curated-parallel-editions.json` — the two
   field-level sources — running the Dodis dump/page-title cross-check as a *required* step. Nothing is
   blocked on code.
2. **Loader + the shared collapsed-row view + both hosts**, plus the honest empty states (gap, thematic,
   pre-coverage). Ship with two series; the third is data, not code.
3. **DDF tiers 1–2 (113 rows)** curated and added, with the Vichy / France Libre overlap preserved and
   the annexes flagged so they are not read as duplicates.
4. **DBPO's single series row**, and the Wilson Center's refusal recorded in the artifact's `note` so
   the row is not re-proposed from the backlog text.
5. **Link table in Swift + `check_repository_links.py` extension** (`TABLES` entry, anti-vacuity floor,
   and a host-vocabulary note for `dodis.ch`'s Anubis wall), then an owner `--stamp`.

**Deferred, priced, not refused:** DDF tier 3 (72 rows, 2–4 h) and DBFP 1919–1939 (64 rows, count
unreconciled) — the two additions that would extend the feature into the pre-1914 corpus.

---

## 7. Standing decision — DEFERRED INDEFINITELY

**The feature is not being built.** What follows is the finding the deferral rests on, kept because a
future reader deserves the reasoning and not just the outcome.

The feature as briefed does not survive its own research. One of the five candidates is off the
internet and had no keyable unit anyway; a second is thematic, unverifiable and demonstrably wrong in
the one case that could be checked; and the join the brief specifies — date overlap on `dateRange` —
floods to a median of six counterpart volumes from two series alone.

A reduced version *would have been* defensible — three series at volume grain (~187 hand-checked
rows), one at series grain, one refused, keyed on `dateRange ∩ subseries` and rendered as collapsed
per-series rows whose most valuable output is often *"no volume covers this period."* One tooling
session, two to three owner hours of curation, no index bump, no schema deploy. **That option is
recorded, not taken.**

A cheaper fallback also exists and is **likewise not taken**: five stamped links in the Research Guide
naming the four live series and their editorial bodies, ~1 hour, delivering the part of the value that
is just *"these editions exist."* It does not deliver the gaps, which is the half only a table can
state — and it carries the same maintenance promise at a smaller size, which is the thing being
declined.

**The consideration that decided the deferral (owner, 2026-09-07):** expanded maintenance obligations
for only a partial internationalisation of perspective — **all four surviving series are European**.
See the head section. The maintenance half is real on its own terms (a stamped table that hedges when
stale is a feature; an unstamped one is a promise the app cannot keep), but it is the *pairing* that
decided it: a permanent obligation bought with a one-directional widening of view.

---

## 8. Shelf life — read this before trusting any figure above

**These findings decay, and one decayed while the research was running.** Every target is somebody
else's website, and this report is a snapshot of 2026-09-07:

- The **Wilson Center** archive host stopped resolving at some point around April 2026 — between the
  backlog text that named it as a candidate and the session that checked it.
- **DBPO** and **DDF** have each changed publisher mid-series.
- **Dodis** sits behind a proof-of-work wall that a future client may not pass.
- **AAPD**'s access flags on the publisher's own site are already wrong for at least two volumes.

So the per-series counts, the free/paywalled splits and every URL in §2 should be treated as
**expired by default** on any revisit. What does *not* expire is the part measured against this
repository: §1.1's join key, §1.2's flood, and §1.3's reason the Wilson Center was unkeyable even when
it was up. A revisit can trust §1 and must re-run §2.

---

## 9. Verification of this document

Every join figure above was re-run against the shipped `FRUSExplorer/Resources/manifest.json` in the
session that wrote it, rather than inherited from the researchers. Re-confirmed exactly:

- `dateRange` populated with both ends on **552 / 552** volumes; span median **3**, max **252**;
  **30** volumes at ≥ 10 years, **8** at ≥ 50.
- **107** distinct `subseries` values, **0** unparseable as a year or year range.
- `subseries` span median **0**, max **55**.
- The intersection: span median **0**, max **10**, and **0** empty intersections across all 552.
- The four quoted long-span volumes, field for field.
- `digitalarchive.wilsoncenter.org` CNAMEs to a Cloudflare target that returns **no address**, while
  the control `www.wilsoncenter.org` resolves — so the archive host is down, not the network.

**One figure was wrong and is corrected here: volumes with a span ≥ 20 years is 12, not 14.** Checked
both by year subtraction and by exact days ÷ 365.2425; both give 12, and the twelve are listed in the
session entry. Nothing else moved, and the correction does not touch any conclusion — the argument
rests on the *shape* of the long tail, not its exact size.

**What is NOT independently verified**, and should be read as the researchers' measurement rather than
this document's: the per-series volume counts and coverage tables in §2, and the flood figures in §1.2,
which are computed against interval tables the researchers built from the series' own sites. Their
inputs are the URLs cited beside them. The flood conclusion is robust to a wrong count in a way the
counts themselves are not: it needs only that AAPD is annual and DDF roughly semi-annual, both of
which are stated by the publishers.
