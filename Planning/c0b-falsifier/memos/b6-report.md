# Scoping memo: US policy toward refugees and displaced persons in the FRUS corpus

**Surfaces used:** the SQLite index (`/Users/jbotts/frus-analysis/frus-copy.db`, read-only), the TEI
XML at `/Users/jbotts/Development/frus/volumes/`, and the bundled JSON in
`/Applications/FRUS Explorer.app/Contents/Resources/`. No HARVEST path was given, so every archival
count below is a **bundled** count and none is summed with a harvest figure.

---

## 0. Coverage and controls

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library is **complete: 552 of 552 volumes**, 316,839 cached documents, of which 1,012 are front
matter and 8,468 editorial notes. Nothing in this memo is thinned by a partial download. (One
qualification survives anyway: FRUS itself is a selection, and declassification thins the 1980s —
see §3.)

Second-edition suppression, per your rule: I dropped `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2`
(740 non-apparatus documents between them) and kept `frus1977-80v09Ed2`. **Working denominator:
306,619 non-apparatus documents in 550 volumes.** Surface counted: this index (not the vector
artifacts).

Controls, run in the same pass:

```sql
SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents
WHERE frus_documents MATCH '"Department of State"';   -- 98499 | 551   (POSITIVE)
SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents
WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ';      -- 0 | 0        (NEGATIVE)
```

Positive fires in 551 of 552 volumes; negative returns nothing. Scans work.

---

## 1. The headline: this is a large, well-shaped body of material

The corpus holds **7,451 non-apparatus documents containing "refugee(s)" across 494 of 550
volumes** — 2.4% of the corpus. That is not a thin seam; it is one of the larger single-word
subjects you could pick.

```sql
SELECT COUNT(*), COUNT(DISTINCT f.volume_id)
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH 'refugee'
  AND d.is_front_matter=0 AND d.is_editorial_note=0
  AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
-- 7451 | 494
```

### 1.1 The stemming trap did *not* bite here, and I checked

`porter` folds most things together, but it happens to keep these two apart:

```sql
SELECT term,doc,cnt FROM frus_documents_vocab WHERE term IN ('refug','refuge','refugee');
-- refug   | 2093 | 2862     <- the word "refuge" ("took refuge in the legation")
-- refuge  | 7745 | 25899    <- the words "refugee" / "refugees"
-- refugee |    1 |     2
```

So `MATCH 'refugee'` does **not** drag in "took refuge". Literal share, over
`header+dateline+source_note+body_text`:

| family | matched | tolerant literal | strict word-bounded |
|---|---|---|---|
| `MATCH 'refugee'` | 7,451 | 7,451 (**1.000**) | 7,445 (**0.999**) |
| `MATCH '"displaced persons"'` | 585 | 585 (**1.000**) | 585 (**1.000**) |

Both are far above the 0.80 floor. A 1.000 share does not prove the *referent* is right, which is
what §3.1 and §5 are for.

### 1.2 The family, counted

All non-apparatus, Ed2 duplicates suppressed. Denominator 306,619 documents / 550 volumes.

| query | documents | volumes |
|---|---:|---:|
| `refugee` | 7,451 | 494 |
| `repatriation` | 3,561 | 351 |
| `emigration` | 3,291 | 389 |
| `asylum` | 1,616 | 313 |
| `resettlement` | 1,230 | 226 |
| `unrra` | 935 | 70 |
| `"displaced persons"` | 585 | 102 |
| `"intergovernmental committee"` | 331 | 42 |
| `unrwa` | 286 | 35 |
| `"refugee relief"` | 202 | 83 |
| `stateless` | 142 | 44 |
| `nansen` | 138 | 30 |
| `escapee` | 129 | 59 |
| `unhcr` | 124 | 32 |
| `"high commissioner for refugees"` | 118 | 48 |
| `"war refugee board"` | 115 | **7** |
| `iro` (token) | 85 | 32 |
| `evian` | 86 | 16 |
| `expellees` | 59 | 27 |
| `icem` | 32 | 12 |
| `"displaced persons act"` | 16 | 8 |

Literal (LIKE) counts *inside* the 7,451-document refugee set, one pass, so these are substrings and
not stems:

| literal | documents | volumes |
|---|---:|---:|
| `refugee problem` | 1,053 | 172 |
| `arab refugee` | 504 | 52 |
| `political refugee` | 326 | 140 |
| `palestine refugee` | 320 | 45 |
| `refugee camp` | 234 | 89 |
| `jewish refugee` | 187 | 52 |
| `cuban refugee` | 150 | 32 |
| `international refugee organization` | 69 | 33 |
| `indochinese refugee` | 59 | 10 |
| `hungarian refugee` | 55 | 28 |
| `refugee settlement commission` | 39 | – |
| `refugee relief act` | 20 | – |

And outside it: `exchange of population` 95 / 37 vols, `expellee` 59 / 27, `german minorities`
48 / 23, `escapee program` 31 / 12, `boat people` 29 / 10, `forced to emigrate` 10 / 10.

**One false friend to discard: `bermuda conference` returns 172 documents in 47 volumes**, but the
1943 Anglo-American refugee conference shares its name with the 1953 and 1957 Bermuda summits. Do
not use it as a proxy; use the volume-scoped chapter (frus1943v01) instead.

---

## 2. The false-friend test on the terms *your question* supplied

Your question supplied "refugees" and "displaced persons". Both had to be shown to discriminate
rather than to measure the corpus. Scope: the 20 volumes with the largest refugee counts (§3.2)
versus everything else, with `"Department of State"` as the control phrase.

| scope | documents | `refugee` | `"displaced persons"` | control `"Department of State"` |
|---|---:|---:|---:|---:|
| on-topic 20 volumes | 13,209 | 2,434 (**18.43%**) | 152 (**1.15%**) | 4,682 (35.45%) |
| rest of corpus | 293,410 | 5,017 (**1.71%**) | 433 (**0.15%**) | 88,736 (30.24%) |

Ratios on-topic : elsewhere — refugee **10.8×**, displaced persons **7.7×**, control **1.17×**. The
control sits at baseline, as it should; both question terms clear it by an order of magnitude.
**Neither term is a false friend.** Use them.

---

## 3. Shape over time — and a warning about the 19th century

Periodised on the document's own editorial date (`document_dates.date_iso`, which is
`frus:doc-dateTime-min`), **not** the volume's series year.

| decade | dated non-apparatus docs | `refugee` docs | per 1,000 | `"displaced persons"` | top volume's share of the numerator |
|---|---:|---:|---:|---:|---|
| 1860s | 11,250 | 101 | 8.98 | 0 | frus1868p2 — 27/101 = 26.7% |
| 1870s | 5,798 | 104 | 17.94 | 0 | frus1875v02 — 33/104 = 31.7% |
| 1880s | 6,472 | 41 | 6.33 | 0 | frus1885 — 8/41 = 19.5% |
| 1890s | 9,712 | 141 | 14.52 | 0 | frus1891 — 49/141 = **34.8%** |
| 1900s | 9,924 | 64 | 6.45 | 0 | frus1902 — 16/64 = 25.0% |
| 1910s | 30,359 | 265 | 8.73 | 0 | frus1916 — 33/265 = 12.5% |
| 1920s | 19,733 | 309 | 15.66 | 0 | frus1923v02 — 79/309 = 25.6% |
| 1930s | 39,196 | 697 | 17.78 | 0 | frus1938v01 — 177/697 = 25.4% |
| 1940s | 74,043 | 1,971 | 26.62 | **447** | frus1949v06 — 339/1,971 = 17.2% |
| 1950s | 42,296 | 1,482 | 35.04 | 72 | frus1952-54v09p1 — 131/1,482 = 8.8% |
| 1960s | 27,650 | 980 | 35.44 | 14 | frus1964-68v19 — 86/980 = 8.8% |
| 1970s | 22,259 | 954 | 42.86 | 47 | frus1969-76v11 — 114/954 = 11.9% |
| 1980s | 5,949 | 336 | 56.48 | 4 | frus1977-80v23 — 45/336 = 13.4% |

Read it as a **rising rate**, 9 per 1,000 in the 1860s to 56 per 1,000 in the 1980s. Two cautions:
the 1980s base is only 5,949 dated documents (declassification, not disinterest), and the pre-1910
rates rest on one volume apiece — a third of the 1890s numerator is a single volume.

### 3.1 The pre-1910 "refugees" are a different thing, and I read one to be sure

I retrieved **frus1891/d285** whole (`length(body_text)` = 11,272; file kept at
`reading/frus1891_d285.txt`). It is Egan to Blaine, Santiago, 19 January 1892, and its "refugees"
are the Chilean civil-war figures sheltering **inside the US legation**, escorted to the USS
*Yorktown* — diplomatic asylum, not migration. The 19th-century chapter headings agree: "Asylum to a
political refugee" (frus1896), "Asylum in legations" (frus1898), "Refusal of asylum to a Dominican"
(frus1899). **If you count pre-1910 "refugee" hits as migration policy you will be wrong most of the
time.** The migration story before 1910 is filed under other headings — "Treaty regulating
emigration" (frus1894), "Condition of Israelites in Russia, their emigration to the United States"
(frus1894), "Irade regarding Armenian emigration" (frus1896), "Jews in Roumania — … objection of
United States Government to immigration of such persons" (frus1902).

### 3.2 Where the material actually is

```sql
WITH base AS (SELECT d.rowid rid, d.volume_id FROM document_cache d
  WHERE d.is_front_matter=0 AND d.is_editorial_note=0
    AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')),
hit AS (SELECT rowid rid FROM frus_documents WHERE frus_documents MATCH 'refugee')
SELECT b.volume_id, COUNT(*) tot, SUM(b.rid IN (SELECT rid FROM hit)) ref,
       ROUND(100.0*SUM(b.rid IN (SELECT rid FROM hit))/COUNT(*),1) pct
FROM base b GROUP BY b.volume_id HAVING ref>=50 ORDER BY ref DESC LIMIT 25;
```

| volume | docs | refugee | % | what it is (manifest.json) |
|---|---:|---:|---:|---|
| frus1949v06 | 1,137 | 339 | 29.8 | 1949, Near East, South Asia, Africa VI |
| frus1943v01 | 967 | 304 | 31.4 | 1943, General I |
| frus1938v01 | 959 | 177 | 18.5 | 1938, General I |
| frus1944v01 | 1,030 | 177 | 17.2 | 1944, General I |
| frus1939v02 | 885 | 139 | 15.7 | 1939, General, British Commonwealth and Europe |
| frus1952-54v09p1 | 857 | 131 | 15.3 | 1952–54, Near and Middle East IX pt 1 |
| frus1977-80v22 | 335 | 130 | **38.8** | 1977–80, Southeast Asia and the Pacific |
| frus1950v05 | 917 | 128 | 14.0 | 1950, Near East, South Asia, Africa V |
| frus1969-76v11 | 305 | 114 | **37.4** | 1969–76, South Asia Crisis, 1971 |
| frus1951v05 | 749 | 112 | 15.0 | 1951, Near East and Africa V |
| frus1945v02 | 805 | 92 | 11.4 | 1945, General: Political and Economic II |
| frus1948v05p2 | 795 | 86 | 10.8 | 1948, Near East, South Asia, Africa V pt 2 |
| frus1964-68v19 | 524 | 86 | 16.4 | 1964–68, Arab-Israeli Crisis and War, 1967 |
| frus1923v02 | 1,035 | 79 | 7.6 | 1923 II (Greek/Near Eastern refugees) |
| frus1955-57v14 | 455 | 79 | 17.4 | 1955–57, Arab-Israeli Dispute, 1955 |

Four clusters, and they are the four literatures:

1. **Interwar and wartime "General" volumes, 1938–1945** — Evian, the Intergovernmental Committee,
   the Spanish republican refugees, the Bermuda conference, the War Refugee Board. Note that
   `"war refugee board"` returns 115 documents in **only 7 volumes** — it is a concentrated, readable
   seam, not a scatter.
2. **Displaced persons and the IRO, 1945–1951** — frus1945v02, frus1946v01, frus1946v05,
   frus1950v02, frus1951v02.
3. **Palestine/Arab refugees and UNRWA, 1948–1980** — the single biggest cluster by volume count;
   `arab refugee` 504 documents and `palestine refugee` 320 across ~50 volumes each.
4. **Cold War and post-colonial displacement** — the President's Escapee Program (frus1952-54v08),
   Hungary 1956, the 1971 South Asia crisis (frus1969-76v11, 37.4% of its documents), Soviet Jewish
   emigration (frus1969-76v15/v16), Indochinese refugees and boat people (frus1977-80v22, 38.8%),
   Cuban and Haitian arrivals (frus1977-80v23).

---

## 4. What to search for — the editors' vocabulary, not yours

I walked all 552 `volume_structures.structure_json` trees for chapter headings. 224 matched a
refugee/migration pattern. The editors use **repeating formulas**, and they are better queries than
anything I would have invented:

- "American interest in the work of the **High Commission for Refugees (Jewish and other) coming
  from Germany**" — frus1933v02, 1934v02, 1935v02, 1936v02 (four consecutive years, same wording)
- "Meeting at **Evian**, France, to form an intergovernmental committee for assistance of political
  refugees from Germany including Austria" — frus1938v01
- "Cooperation with the **Intergovernmental Committee on Refugees to assist persons forced to
  emigrate**, primarily from Germany, for political or racial reasons" — frus1939v02, 1940v02,
  1941v01
- "**Governmental assistance to persons forced to emigrate for political or racial reasons**" —
  frus1943v01, frus1944v01
- "**Bermuda Conference to consider the Refugee Problem, April 19–28, 1943**" — frus1943v01
- "Concern of the United States over problems involving **displaced and stateless persons and
  refugees**" — frus1945v02, frus1946v05
- "The United States and the question of international assistance to refugees and displaced persons;
  **the genesis of the International Refugee Organization**" — frus1946v01
- "**Matters respecting refugees and stateless persons**" — frus1950v02, frus1951v02
- "United States Support of **Refugees and Escapees from Eastern Europe; the President's Escapee
  Program**; the Volunteer Freedom Corps" — frus1952-54v08
- "**Economic Normalization and Soviet Jewish Emigration**, September–December 1972" — frus1969-76v15
- Earlier: "Withdrawal of American relief organizations … in behalf of **Greek refugees**, and
  formation of the **Refugee Settlement Commission**" (frus1923v02); "**Greek refugee loan of 1924**"
  (frus1924v01, frus1932v02); "Acceptance … of **certificates of identity issued by the League of
  Nations to Russian and Armenian refugees**" (frus1924v01); "Inquiry by the **Nansen International
  Office for Refugees**" (frus1935v01)

Note "persons forced to emigrate" is **heading language, not document language**: only 10 documents
contain the literal string. Search the chapter, not the phrase.

### 4.1 A trap in your own exclusion rule

Your standing rule drops `is_editorial_note = 1`. That is right for counting, but the single most
on-point chapter title in the corpus is defeated by it. In `frus1946v01.xml` the compilation
`comp21`, *"the genesis of the International Refugee Organization"*, opens with
`<div … subtype="editorial-note" type="document" xml:id="d752">` — an editorial note that narrates
the whole 1946 IRO negotiation, no-forced-repatriation principle included. That is why frus1946v01
shows only **4** refugee documents in the index while carrying that heading. Corpus-wide the
excluded layers hold, for `MATCH 'refugee'`, **155 editorial notes in 71 volumes and 126 front-matter
records in 108 volumes** on top of the 7,451. Small in aggregate; decisive in this one case. Run at
least one pass with the exclusions lifted.

---

## 5. [TEI] Spelling variants — the index cannot answer this and the acronyms matter

Counting surface: **tag-stripped + whitespace-collapsed** (stripping removes 53–61% of the raw bytes
in these files, so the surface choice is not cosmetic). Nine DP-era volumes: frus1945v02,
frus1946v01, frus1946v05, frus1947v03, frus1948v05p2, frus1949v06, frus1950v02, frus1951v02,
frus1952-54v08.

| variant | occurrences |
|---|---:|
| `Department of State` (POSITIVE control) | 3,660 |
| `\brefugees?\b` | 3,340 |
| `\bU\.?\s?N\.?\s?R\.?\s?R\.?\s?A\.?\b` | 1,565 |
| `\bdisplaced persons?\b` (spelled) | **484** |
| `\bD\.?\s?P\.?('s\|s)?\b` (acronym) | **246** |
| `\bescapees?\b` | 209 |
| `\bI\.?\s?R\.?\s?O\.?\b` (acronym) | **143** |
| `\bstateless\b` | 107 |
| `International Refugee Organi[sz]ation` (spelled) | **49** |
| `\bexpellees?\b` | 17 |
| `ZZZ_IMPOSSIBLE_ZZZ` (NEGATIVE control) | 0 |

Two things follow. **IRO's acronym outnumbers its spelled name 2.9 : 1** — a spelled-form search
finds a quarter of the organisation. And in frus1946v05 the DP acronym (106) *outnumbers* the spelled
form (89).

**But I checked the DP hits in context and must qualify my own number.** Sampling the 106 matches in
frus1946v05 (`DP` 90, `D.P` 14, `D. P` 2), most sit inside **archival citations**, not prose —
strings like `800.4016 DP/1–1046: Telegram` and `300.4016 D.P./2–2146`. So the acronym share of
*prose* usage is lower than 246/730. The finding survives in a better form: **"DP" in this corpus is
as often a file designator as a word**, which is itself the pointer in §6.2.

---

## 6. Archival scope — where these documents came from, and where the footnotes point

**Two channels, never summed.** Channel A is `document_sources` (where a printed document came from,
one row per document). Channel B is `external_citations` (what an editorial footnote mentions, many
rows per document). Volume set for both: the 7,451-document refugee set unless stated.

### 6.1 Channel A — came-from (7,013 of 7,451 refugee documents carry a source row)

`citation_era` is a citation **form**, not a date, and is not plotted as one:

| form | documents |
|---|---:|
| decimal | 4,409 |
| structured | 1,689 |
| lot_file | 576 |
| cfpf | 174 |
| named_series | 88 |
| published | 43 |
| unrecognized | 32 |
| foreign | 2 |

**Top central-file classes.** Glosses come from `decimal-class-labels.json`, which ships **one**
schedule (1910–1949) — so I glossed a class only where the citing documents' own dates fall inside
it, and refused otherwise.

| class | docs | vols | doc-date span | gloss (1910–49 schedule) |
|---|---:|---:|---|---|
| **840.48** | **767** | 22 | 1915–1949 | Internal Affairs of States · Europe · *Calamities. Disasters* |
| 501.BB | 294 | 8 | 1946–1949 | Congresses and Conferences (country code not in the table) |
| 867N.01 | 104 | 11 | 1938–1949 | Internal Affairs · Israel/Palestine · *Government* |
| 893.00 | 101 | 24 | 1913–1949 | Internal Affairs · China · *Political affairs* |
| 868.51 | 95 | 18 | 1923–1947 | Internal Affairs · Greece · *Financial conditions* (the refugee loan) |
| 793.94 | 82 | 9 | 1931–1939 | class 7 — **no gloss**: the file ships subject tables for classes 6 and 8 only |
| 852.48 | 77 | 6 | 1937–1943 | Internal Affairs · Spain · *Calamities. Disasters* |
| 740.00119 | 73 | 20 | 1943–1949 | class 7 — **no gloss** |
| 684A.86 | 69 | 9 | **1951–1962** | **outside 1910–49: refused, not glossed** |
| 868.48 | 63 | 5 | 1922–1943 | Internal Affairs · Greece · *Calamities. Disasters* |
| 751G.00 | 63 | 5 | **1950–1956** | **outside 1910–49: refused** |
| POL 27 ARAB-ISR | 52 | 3 | — | subject-numeric, post-1963; no decimal gloss applies |
| 861.48 | 35 | 5 | 1917–1929 | Internal Affairs · USSR · *Calamities. Disasters* |

**The single most useful archival string in this whole memo is a named subfile.** The 1945 document
I read (`frus1945v02/d511`, Warren, Adviser on Refugees and Displaced Persons, to Russell of the
British Embassy, 13 February 1945) carries the source note `840.48 Ref/1–3145`. Counting it:

```sql
SELECT SUM(raw_text LIKE '%840.48 Refugees%'), SUM(raw_text LIKE '%840.48%'), COUNT(*)
FROM document_sources;   -- 757 | 928 | 264487
```

**757 printed documents cite `840.48 Refugees`** — RG 59 Central Decimal File, Europe, Calamities,
*Refugees* subfile — concentrated in frus1943v01 (193), frus1944v01 (160), frus1938v01 (144),
frus1939v02 (92), frus1945v02 (46), spanning 1938–1948. If you order one thing, order this.

**A second, distinct family that a "refugee" search would never surface.** The persecution files are
not under `.48` *Calamities* but under `.4016` *Race problems*: corpus-wide 509 source rows carry a
`.4016`, including `840.4016` (Europe), `871.4016 Jews` (Romania), `867.4016`, `865.4016`,
`60f.4016`, and **`800.4016 DP`** (World · Race problems · *Displaced Persons*, 44 rows). Within the
refugee set: 1,057 documents cite a `.48` class and 58 a `.4016`. **Two central-file classes carry
what a modern historian would call one story.** Search both.

**Lot files.** The raw ranking is dominated by general policy lots (63D351 55 docs / 25 vols; 59D518
46/4; M88 33/11; 59D95 26/5; 84D241 21/9; 61D417 17/5), which appear because refugee policy passed
through the NSC. More useful is **concentration** — the refugee share of each lot's printed output,
lots with ≥25 printed documents:

| lot | printed docs | refugee | % | resolved (bundled JSON) |
|---|---:|---:|---:|---|
| **59D518** | 112 | 46 | **41.1** | RG 59, NAID 2212252, HMS/MLR **A1 1298**, *Documents on Projects Alpha, Mask, and Omega*; creator **DoS, Bureau of NEA, Office of Near Eastern Affairs**; 5 ft 3 in; 1949–1957; NARA College Park, Textual Reference |
| 71D440 | 57 | 12 | 21.1 | RG 59, NAID 2125425, **A1 3039E**, *Position Papers and Background Books*; Bureau of International Organization Affairs; 26 ft 3 in; 1945–1964 |
| 62D333 | 28 | 5 | 17.9 | RG 59, NAID 2124692, **A1 1462**, *Psychological Strategy Board Working Files* |
| 53D468 | 44 | 7 | 15.9 | RG 59, NAID 2194824, **A1 1422**, *Subject Files*; NEA Office of the Assistant Secretary; 8 ft 9 in; 1945–1953 |
| 82D298 | 60 | 9 | 15.0 | RG 59, NAID 1274403, **P 9**, *Records of Anthony Lake* |
| 61D385 | 80 | 12 | 15.0 | **not in central-files-index, not in curated-lot-resolutions, not in lot-claimants** |
| 84D241 | 160 | 21 | 13.1 | RG 59, NAID 26309216, **UD-14D 69**, *Briefing Books of Cyrus R. Vance* |
| 62D430 | 142 | 16 | 11.3 | RG 59, NAID 2839191, **A1 1586C**, *Subject and Special Files* |
| 59D95 | 283 | 26 | 9.2 | not in central-files-index; `curated-lot-resolutions.json` records it as kind **"possible"** → *Conference Files* |
| 63D351 | 624 | 55 | 8.8 | RG 59, NAID 2839192, **A1 1586E**, *Records Relating to National Security Council Policy Papers*; Executive Secretariat; 26 ft 3 in; 1947–1979 |
| 61D417 | 212 | 17 | 8.0 | RG 59, NAID 2103073, **A1 1261**, *Meeting Summaries and Project Files*; Executive Secretariat; 1951–1959 |

`M88` is not in `central-files-index.json`; `curated-lot-resolutions.json` records it as kind
**"referral"** to the **CFM Files / Council of Foreign Ministers Files, RG 43** — a different record
group, which is exactly the case where a same-group assumption would send you to the wrong building.

Also worth knowing even though it did not top the ranking: central-files-index resolves **Lot 428** →
RG 59, NAID 2124670, **A1 1457**, *Subject Files Relating to Palestine, Political, Security, and
Trusteeship Matters*, Bureau of United Nations Affairs, 2 ft 7 in, 1946–1951.

I did not verify these creator headings independently. NARA's creator attribution is a decoy surface;
treat "Bureau of Near Eastern Affairs" as NARA's claim, not as a finding.

**Volume-scope ranking** (`collection-usage-index.json`, the 20 on-topic volumes of §3.2, over
**13,152 source notes**) — this is a *volume* scope, not the refugee-document scope above, and the
two are different numbers:

| archival target | notes |
|---|---:|
| Department of State — central file | 1,033 |
| Department of State — central files 1967-69 | 449 |
| Johnson Library — National Security File | 351 |
| Carter Library — National Security Affairs | 335 |
| Nixon — NSC Files | 166 |
| IO Files | 141 |
| Kennedy Library — National Security File | 128 |
| Department of State — central files 1970-73 | 93 |
| lot M88 | 85 |
| Department of State atomic energy file | 82 |
| lot 60D224 | 77 |
| lot 59D95 | 58 |
| Roosevelt Library — Hyde Park | 40 |

### 6.2 Channel B — pointed-at (what the footnotes cite and FRUS did **not** print)

Caveats first, as required: `external_citations` holds **lot, library and decimal anchors only**, it
stores the citation fragment rather than the sentence, and it has no row before 1910-12-06. On the
refugee set the earliest citing document is dated **1917-12-15** and the latest 1988-09-23.

**1,862 references from 1,112 of the 7,451 refugee documents (14.9%).** So this channel sees about
one refugee document in seven, and essentially nothing before the First World War.

| repository | collection | refs | citing docs |
|---|---|---:|---:|
| Department of State | *(unspecified)* | 1,342 | 785 |
| Nixon Presidential Materials | NSC Files | 150 | 93 |
| Carter Library | National Security Affairs | 111 | 84 |
| Johnson Library | National Security File | 65 | 50 |
| Carter Library | Presidential Materials | 41 | 26 |
| Kennedy Library | National Security Files | 31 | 27 |
| Ford Library | National Security Adviser | 20 | 15 |
| Eisenhower Library | Dulles Papers | 10 | 8 |

Pointed-at lots: 66D95 (38 refs, 24 vols), 63D351 (38, 15), 59D518 (26, 3), 62D430 (16, 10).
Pointed-at classes: 751G.00 (63), 325.84 (52), 684A.86 (49), 867N.01 (43), 292.51G22 (30), 762.00 (23).

Note how little Channel B and Channel A overlap in emphasis: A is dominated by the 1938–49 decimal
file, B by post-1961 presidential libraries. That is a property of when FRUS editors started writing
this kind of footnote, not of where the records are.

### 6.3 What the offline stack cannot reach — and what to do instead

`series-facts-index.json` carries facts for **695 series**, of which exactly **1** has an end year
before 1940 and **3** before 1946. The series-level roadmap is a post-1945 instrument. For the
Greek/Armenian/Russian refugee material of the 1920s and the German-Jewish crisis of the 1930s the
bundled stack offers no series card — **but that is not an archival absence.** The roadmap for those
decades is the decimal file itself, and it is fully specified above: `868.48` and `868.51` (Greece,
1922–47), `861.48` (Russia, 1917–29), `852.48` (Spain, 1937–43), `840.48` and its `Refugees` subfile
(Europe, 1938–48), and the `.4016` *Race problems* family (`871.4016 Jews` for Romania). Those are
RG 59 Central Decimal File citations you can order directly.

**Digitisation: no.** `digitized-ranges-index.json` covers **18 decimal classes** — the 763.72
(First World War) family, plus visa classes 131, 131.1, 133, 133.1, and 763. **840.48 is not among
them.** Nothing in this refugee seam is available as a scan through that index; this is a
reading-room trip. (I did not test `roll-scans-index.json` against these classes.)

---

## 7. Subject tags: they add almost nothing here, and I measured it

`document-subject-index.json` has a `Human Rights › Refugees › Refugees` tag (id 40, corpus
df 5,885) plus Cuban refugees (124), Refugee resettlement (152), Indochinese refugees (238),
Political refugees (309), Refugee camps (370), Asylum (314), Emigration (463), Immigration (373).
Non-apparatus counts: tag 40 = 5,744 documents / 465 volumes; 373 = 4,012; 463 = 1,913; 314 = 1,534.

Cross-tabbed against the word search:

| | count |
|---|---:|
| tagged 40 **and** matches `refugee` | 5,625 |
| matches `refugee`, **not** tagged | 1,826 |
| tagged 40, **does not** match `refugee` | **119** |

The tag is 98% (5,625/5,744) a subset of the word match — it is string matching, as your rule warns,
and it costs you 1,826 documents while adding 119. **Use the FTS query, not the tag.** The 119
tag-only documents are worth a look precisely because they are the ones a literal search misses.

---

## 8. What I did *not* do

- No harvest surface (no path given), so no series-level completeness or extent beyond the 695
  bundled `series-facts` entries.
- I did not separate footnote text from document body anywhere. `body_text` contains both, so every
  frequency above blends editors' language with contemporaries'. I did drop front matter and
  editorial notes by column, and I reported what that removed (§4.1).
- I did not scan the full TEI corpus for variants — only the 9 DP-era volumes in §5. A corpus-wide
  variant scan of `refugee` vs `réfugié` vs `Flüchtling` in the French and German enclosures is
  unmeasured and would change the pre-1914 picture if anything does.
- I did not check `roll-scans-index.json`, `presidential-library-catalog.json`, or
  `accession-series-index.json` against these classes.
- `person_rollup` / `person_mentions` untouched: FRUS names its refugee officials in the *header*
  ("The Adviser on Refugees and Displaced Persons (Warren)", "the Coordinator on Palestine Refugee
  Matters (McGhee)"), which is a better handle than a name-clustered lower bound.

## 9. Reading log

Seven documents retrieved whole; raw text kept at `reading/` in this directory. Captured length =
`length(body_text)`:

| document | body_text chars |
|---|---:|
| frus1891/d285 | 11,272 |
| frus1938v01/d824 | 1,635 |
| frus1945v02/d511 | 2,543 |
| frus1946v01/d272 | 4,529 |
| frus1949v06/d608 | 21,053 |
| frus1952-54v08/d64 | 2,768 |
| frus1977-80v22/d111 | 6,758 |

Quoted above: two — frus1891/d285 (the Santiago legation refugees) and frus1945v02/d511 (its
`840.48 Ref/1–3145` source note and the UNRRA/Philippeville refusal). The remaining five were read
to confirm cluster identity and are not quoted. One further passage was read directly out of
`frus1946v01.xml` (the `comp21` / `d752` editorial note) to establish §4.1.

## 10. If you run one query tomorrow

```sql
-- the 1938-1948 core, with its archival key attached
SELECT d.volume_id||'/'||d.document_id AS ref, d.header, dd.date_iso, s.raw_text
FROM frus_documents f
JOIN document_cache d  ON d.rowid = f.rowid
JOIN document_sources s ON s.volume_id = d.volume_id AND s.document_id = d.document_id
LEFT JOIN document_dates dd ON dd.volume_id = d.volume_id AND dd.document_id = d.document_id
WHERE frus_documents MATCH 'refugee'
  AND d.is_front_matter = 0 AND d.is_editorial_note = 0
  AND s.raw_text LIKE '%840.48 Refugees%'
ORDER BY dd.date_iso;
```

757 rows, 15 volumes, 1938–1948, every one of them an orderable RG 59 citation.
