# Scoping memo: US participation in international sanitary conventions and quarantine practice

**Surfaces used:** the SQLite index (coverage, identity, counts), the TEI corpus (one variant scan),
and the bundled JSON (all archival resolution). No NARA harvest path was given, so that surface was
unavailable and nothing here is labelled [HARVEST].

---

## 0. Coverage, controls, and the one thing that is *not* a caveat

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

**Your library is complete**: 552 volumes, which is the whole series. So for once the usual sentence
does not apply — nothing below is thin *because* of a partial download. Every count is still
conditional on these 552 volumes and I say so where it matters, but the conditionality is about what
FRUS printed, not about what you have.

Working denominator throughout: **306,619** non-apparatus documents (front matter and editorial notes
excluded, `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2` suppressed; `frus1977-80v09Ed2` kept, it has
no first edition).

Controls, run in the same passes as the scans:

| surface | positive `Department of State` | negative `ZZZ_IMPOSSIBLE_ZZZ` |
|---|---|---|
| index (FTS5) | 98,499 documents in 551 of 552 volumes | 0 documents, 0 volumes |
| TEI (tag-stripped) | 177,891 occurrences in 550 of 550 files | 0 occurrences, 0 files |

---

## 1. The short answer

The corpus holds a **real, continuous, and unusually well-shaped record** of this question, and it is
larger than a keyword search suggests because the editors filed it under headings you would not guess.

Three things you should know before searching:

1. **The spine is the editors' own compilation headings, not any search term.** I pulled every
   section title in `volume_structures` and found **76** that name sanitation, quarantine, health or
   an epidemic disease. Those headings are the finding aid. They give **129 documents in 21 volumes**
   of human sanitary/quarantine business — and they name the episodes for you: the Third
   International Sanitary Convention (Mexico City 1907), the Fourth (San José 1909), the 1926 Paris
   revision, the 1924 Havana Sanitary Code, the International Quarantine Board at Alexandria, the
   1938 Paris conference.
2. **"Sanitary" in FRUS is three different subjects**, and they must be separated or every count is
   junk. I separated them by the editors' own chapter assignment, not by guessing.
3. **The two words the question gave you — "quarantine" and "cholera" — both fail the false-friend
   test.** Details in §3. Use the convention/conference phrases instead.

---

## 2. The three senses of "sanitary", separated by the editors' own headings

Built from `volume_structures` section titles (script `headings.py` → `headings-out.txt`; scope
extracted by `scope.py` → `scope-ids.tsv`). None of the documents in any bucket is apparatus —
verified per document against `is_front_matter` / `is_editorial_note`, 0 of 129, 0 of 58, 0 of 5.

| sense | chapters | documents | volumes | what it actually is |
|---|---|---|---|---|
| **HUMAN** — sanitary conventions, maritime quarantine, public health | 32 | **129** | **21** | the question |
| **ANIMAL/PLANT** — veterinary and phytosanitary trade restriction | 9 | **58** | 8 | a *trade* dispute wearing the same word |
| **PROGRAM** — bilateral "health and sanitation" aid agreements, 1942–48 | 17 | **5** | 1 | technical assistance, not quarantine |

The animal sense is not a nuisance to be filtered — it is a substantial body (58 documents) about
Argentine and Mexican livestock, German barley, and foot-and-mouth disease, and the **US–Argentina
"Sanitary Convention" of 24 May 1935** (`frus1935v04/d318`) is an animal-health instrument that the
phrase `"sanitary convention"` returns alongside the Paris and Havana conventions. Nine of the 84
`"sanitary convention"` hits sit in ANIMAL-headed chapters:
`frus1935v04/d318`, `frus1940v05/d591`, `/d592`, `/d593`, `/d594`, `/d595`, `/d597`,
`frus1947v08/d695`, `/d696`.

**The PROGRAM row is itself a finding.** Sixteen of those seventeen 1942–48 chapters print **zero
documents** — the editors head a chapter for an agreement (Bolivia, Brazil, Ecuador, El Salvador,
Haiti, Nicaragua, Paraguay, Peru, Dominican Republic, Panama, Venezuela, Honduras…) and then print
nothing under it. Only `frus1942v06` ch13 (Colombia) prints anything: 5 documents. If you want the
wartime health-and-sanitation programs, FRUS will tell you they existed and send you elsewhere.

---

## 3. False-friend test — both question-supplied terms fail at volume grain

House rule: compare the term's share in the on-topic volumes with a control phrase's share.
Denominators: **18,318** non-apparatus documents in the 22 volumes carrying a HUMAN chapter;
**306,619** corpus-wide. Script `falsefriend.py`.

| term | on-topic share | corpus share | ratio |
|---|---|---|---|
| `"international sanitary"` | 35 of 18,318 = 0.0019 | 64 of 306,619 = 0.0002 | **9.2×** |
| `"sanitary convention"` | 35 of 18,318 = 0.0019 | 84 of 306,619 = 0.0003 | **7.0×** |
| `"bill of health"` | 21 of 18,318 = 0.0011 | 136 of 306,619 = 0.0004 | 2.6× |
| `quarantin` (stem) | 126 of 18,318 = 0.0069 | 847 of 306,619 = 0.0028 | 2.5× |
| `cholera` | 15 of 18,318 = 0.0008 | 248 of 306,619 = 0.0008 | **1.0×** |
| — control `"consular officer"` | 513 of 18,318 = 0.0280 | 3,615 of 306,619 = 0.0118 | 2.4× |
| — control `railway` | 920 of 18,318 = 0.0502 | 7,943 of 306,619 = 0.0259 | 1.9× |
| — control `"good offices"` | 574 of 18,318 = 0.0313 | 5,080 of 306,619 = 0.0166 | 1.9× |
| — control `"most favored nation"` | 281 of 18,318 = 0.0153 | 2,803 of 306,619 = 0.0091 | 1.7× |

**The control band is 1.7×–2.4×.** So:

- `quarantin` at 2.5× and `"bill of health"` at 2.6× are **at baseline**. They are measuring the
  fact that these are big pre-1940 annual volumes, not that the volume is about quarantine.
- `cholera` at **1.0×** is *exactly* baseline. Do not scope on it.
- Only `"sanitary convention"` and `"international sanitary"` clear the band by a real margin.

**Why the enrichment fails is structural, and it changes the method.** The FRUS annual volumes of
1895–1938 are omnibus country-by-country compilations of 800–2,000 documents, in which a sanitary
chapter is 1–20 documents. **Volume-grain enrichment cannot see this topic at all.** The unit of
analysis has to be the editors' chapter (or the individual document), never the volume.

### The other false friend: the Cuban quarantine

`quarantin` matches **847** non-apparatus documents. Its top two volumes are `frus1961-63v11` (98)
and `frus1961-63v10-12mSupp` (93) — the 1962 naval quarantine of Cuba. I classified every literal
`quarantin*` occurrence by a ±200-character window (health vocabulary vs. missile/blockade/Cuba
vocabulary; script `referent.py`):

| decade | health | both | strategic-only | neither | total |
|---|---|---|---|---|---|
| 1860s | 57 | 8 | 0 | 9 | 74 |
| 1870s | 35 | 1 | 0 | 4 | 40 |
| 1880s | 53 | 4 | 0 | 3 | 60 |
| 1890s | 59 | 2 | 0 | 3 | 64 |
| 1900s | 36 | 8 | 1 | 12 | 57 |
| 1910s | 39 | 2 | 1 | 12 | 54 |
| 1920s | 53 | 5 | 0 | 15 | 73 |
| 1930s | 60 | 1 | 1 | 9 | 71 |
| 1940s | 20 | 5 | 2 | 12 | 39 |
| 1950s | 8 | 0 | 1 | 2 | 11 |
| **1960s** | 17 | **133** | **95** | 16 | **261** |
| 1970s | 5 | 12 | 3 | 5 | 25 |
| 1980s | 5 | 6 | 0 | 2 | 13 |

The strategic sense is **decade-localised**: 6 strategic-only documents across the whole 1840s–1950s,
then 95 in the 1960s alone. **Before 1960, `quarantine` in this corpus means public-health
quarantine and you can use it freely. From 1960 you cannot.**

---

## 4. Literal-share obligation — every phrase family I publish

Every family below was **censused** (all M ≤ 300), not sampled. Regex over
`header + dateline + source_note + body_text`, whitespace-collapsed, **case-INSENSITIVE Python `re`**
(one convention for the whole family). STRICT = single spaces; TOLERANT = each word allowed its
inflections with any run of space, hyphen, comma, parenthesis or full stop between them.
Script `litshare.py` → `litshare-out.json`.

| phrase | M | TOLERANT | STRICT |
|---|---|---|---|
| `sanitary convention` | 84 | **84 of 84 = 1.000** | 77 of 84 = 0.917 |
| `international sanitary` | 64 | **64 of 64 = 1.000** | 64 of 64 = 1.000 |
| `pan american sanitary` | 15 | **15 of 15 = 1.000** | 13 of 15 = 0.867 |
| `quarantine regulations` | 98 | **98 of 98 = 1.000** | 93 of 98 = 0.949 |
| `bill of health` | 136 | **136 of 136 = 1.000** | 96 of 136 = 0.706 |
| `sanitary conference` | 21 | **21 of 21 = 1.000** | 17 of 21 = 0.810 |
| `quarantine station` | 38 | **38 of 38 = 1.000** | 31 of 38 = 0.816 |
| `sanitary bureau` | 22 | **22 of 22 = 1.000** | 22 of 22 = 1.000 |

Every tolerant share is 1.000, which — as the house rules say — **tests the stemmer, not the
referent**. The strict/tolerant gap is pure inflection: `bill of health`'s 40 strict misses are all
`bills of health` (the index folds the two to identical hit sets, 136 documents each). So I tested the
referent separately, in §2 (chapter assignment) and §3 (window classification). **The referent test is
where `sanitary convention` actually loses 9 of 84 documents to the animal sense — the literal share
would never have told you.**

---

## 5. Decade shape, with rates and top-volume shares

Per 1,000 dated non-apparatus documents of that decade, with the numerator's top-volume share.
Script `rates.py`. Periodised on the **document's own date** (`document_dates.date_iso`), not the
volume's series year.

**The sanitary-convention phrase family** (`"sanitary convention" OR "sanitary conference" OR "international sanitary" OR "sanitary bureau"`):

| decade | raw | per 1,000 | top volume share |
|---|---|---|---|
| 1860s | 3 | 0.27 (3 of 11,250) | frus1864p4 1 of 3 |
| 1870s | 7 | 1.21 (7 of 5,798) | frus1879 4 of 7 |
| 1880s | 5 | 0.77 (5 of 6,472) | frus1888p1 3 of 5 |
| 1890s | 3 | 0.31 (3 of 9,712) | frus1896 3 of 3 |
| **1900s** | **28** | **2.82 (28 of 9,924)** | frus1909 6 of 28 |
| 1910s | 12 | 0.40 (12 of 30,359) | frus1919Parisv06 4 of 12 |
| 1920s | 15 | 0.76 (15 of 19,733) | frus1926v01 7 of 15 |
| 1930s | 19 | 0.48 (19 of 39,196) | frus1937v05 4 of 19 |
| 1940s | 17 | 0.23 (17 of 74,043) | frus1940v05 6 of 17 |
| 1950s | 3 | 0.07 (3 of 42,296) | frus1951v06p1 1 of 3 |

**Quarantine co-occurring with health vocabulary** (the sense-filtered series):

| decade | raw | per 1,000 | top volume share |
|---|---|---|---|
| 1860s | 57 | 5.07 (57 of 11,250) | frus1867p1 15 of 57 |
| 1870s | 31 | 5.35 (31 of 5,798) | frus1879 14 of 31 |
| 1880s | 37 | 5.72 (37 of 6,472) | frus1888p1 10 of 37 |
| 1890s | 44 | 4.53 (44 of 9,712) | frus1895p1 13 of 44 |
| 1900s | 41 | 4.13 (41 of 9,924) | frus1900 15 of 41 |
| 1910s | 23 | 0.76 (23 of 30,359) | frus1912 4 of 23 |
| 1920s | 43 | 2.18 (43 of 19,733) | frus1928v02 9 of 43 |
| 1930s | 37 | 0.94 (37 of 39,196) | frus1930v02 13 of 37 |
| 1940s | 11 | 0.15 (11 of 74,043) | frus1944v02 2 of 11 |
| 1950s | 2 | 0.05 (2 of 42,296) | frus1951v02 1 of 2 |
| 1960s | 3 | 0.11 (3 of 27,650) | — |
| 1980s | 5 | 0.84 (5 of 5,949) | frus1977-80v26 2 of 5 |

**Read the rate column, not the raw column.** The 1900s peak (2.82/1,000) is genuine and is the
Pan-American convention cycle. The **1860s–1890s rate for health quarantine is 4.5–5.7 per 1,000 and
is the highest sustained level in the corpus** — a fact the raw counts hide, because those decades
are small. Then it collapses: after 1940 the topic effectively leaves FRUS (0.15, then 0.05 per
1,000). Every decade's top-volume share is below 0.60 except the tiny 1890s cell, so none of these
is one negotiation being counted many times.

---

## 6. What to search for — a concrete list

**Use these (they clear the false-friend band or are unambiguous):**

- `"international sanitary"` · `"sanitary convention"` · `"sanitary conference"` · `"sanitary bureau"` ·
  `"pan american sanitary"` · `"sanitary code"`
- `pratiqu` (184 occurrences, 61 documents) and `"libre pratique"` / `"free pratique"` — the technical
  vocabulary of admission, and an excellent precision term
- `lazaret*` (73 TEI occurrences, 19 volumes)
- `"bill of health"` — high recall, but at baseline enrichment; use for retrieval, not for scoping
- disease anchors: `cholera` (928 occ / 250 docs), `plagu` (1,270 / 816), `yellow fever`, `typhu`,
  `smallpox`, `bacteriolog`, `derat` (deratisation, 20 docs — a 1926-convention term)
- institutional: `"marine hospital service"` (51 docs / 23 vols), `"public health service"` (162 / 77),
  `"international office of public health"`, `"sanitary cordon"` / `cordon sanitaire`

**Do not scope on:** `quarantine` alone after 1960, `cholera` at volume grain, `sanitary` alone
(it returns the animal and the aid senses), or `WHO` (see §7).

**Read the chapter headings first.** `headings-out.txt` in this directory is the list; it is worth
more than any query I wrote.

---

## 7. [TEI] Variant scan — spelling, hyphenation, acronym

**Counting surface: raw TEI byte stream with all tags stripped to a space and whitespace collapsed.
Case-insensitive Python `re`. 550 of the 552 volume files (the two suppressed Ed2 excluded).
Apparatus is NOT separated — front matter, footnotes and the back-of-book index are inside these
counts.** Scripts `teiscan.py` (5 chunks) + `teiagg.py` → `tei-agg.json`.

| variant | occurrences | volumes |
|---|---|---|
| POSITIVE CONTROL `Department of State` | 177,891 | 550 |
| NEGATIVE CONTROL | 0 | 0 |
| `quarantine` (any inflection) | 2,691 | 236 |
| `quarantaine` (French) | **0** | 0 |
| `maritime quarantine` | 10 | 7 |
| `bill/bills of health` | 299 | 76 |
| `clean bill of health` | 68 | 31 |
| `sanitary convention` | 274 | 39 |
| `international sanitary convention` | 149 | 26 |
| `sanitary conference` | 73 | 18 |
| `international sanitary conference` | 34 | 9 |
| `pan american sanitary` (space) | **68** | 12 |
| `pan-american sanitary` (hyphen) | **12** | 6 |
| `PASB` acronym | **1** | 1 |
| `sanitary bureau` | 63 | 15 |
| `Havana / Pan-American Sanitary Code` | 9 | 3 |
| `International Sanitary Regulations` | 2 | 2 |
| `Office International d'Hygiène Publique` (French) | **2** | 1 |
| `International Office of Public Health` (English) | **34** | 5 |
| `OIHP` acronym | **0** | 0 |
| `World Health Organization/-isation` | 239 | 85 |
| `lazaretto/lazaret` | 73 | 19 |
| `pratique` | 167 | 34 |
| `libre/free pratique` | 52 | 15 |
| `sanitary cordon` / `cordon sanitaire` | 98 | 49 |

Four things follow that a single-literal query would have got wrong:

- **Hyphenation costs 15%.** `pan american sanitary` 68 vs `pan-american sanitary` 12 — search both.
- **The acronyms do *not* outnumber the spelled forms here**, contrary to the usual pattern: `PASB` = 1
  against 80 spelled; `OIHP` = **0**.
- **The English name of the Paris office beats the French 17:1** — `International Office of Public
  Health` 34 in 5 volumes against `Office International d'Hygiène Publique` 2 in 1. Search the
  English form; it is also the form the editors used in the `frus1908` and `frus1923v01` chapter titles.
- **`WHO` as an acronym is unmeasurable on this surface and I am reporting the failure rather than the
  number.** My pattern (a negative lookahead for common auxiliaries) returned **86,117 hits in 550 of
  550 volumes** — it is overwhelmingly the relative pronoun. Use `"world health organization"`
  (239 occurrences, 85 volumes) and nothing else.

---

## 8. Apparatus caveat, stated rather than fixed

`body_text` in the index **includes editorial footnotes**, and my TEI scan did not separate document
text from footnotes, front matter or the back-of-book index. So every frequency above blends the
diplomats' language with the editors'. The index *can* and did drop front matter (1,012) and editorial
notes (8,468) by column; it cannot split a footnote from a body. Where that matters most is the raw
TEI occurrence counts in §7 — the back-of-book index alone repeats "quarantine" once per entry.

---

## 9. Archival scope — both channels, never summed

### Channel A: came-from (`document_sources`, one row per document)

Over the 129 HUMAN documents: **73 of 129 carry a source row.** All 67 with a record group are
**RG 59**; the other 6 are `published`. Script `archival.py`.

Glossed against `decimal-class-labels.json`, **applying the schedule's own year gate** (the shipped
copy is `schemaVersion 1`, one schedule, `startYear 1910 / endYear 1949`; note it carries **no
`coverage` block at all**, so `glossableYears` / `notShipped` were unavailable and I gated on
`startYear`/`endYear` directly). Script `gloss.py` → `class-keys.json`.

| class key | docs | years | gloss |
|---|---|---|---|
| **883.12** | 14 | 1927–1933 | class 8 *Internal Affairs of States* · country 83 **Egypt** · `.12` **Public health** |
| **893.12** | 14 | 1930 | class 8 · country 93 **China** · `.12` **Public health** |
| 158.931 | 9 | 1911 | class 1 *Administrations, US Government* — **no class-1 subject table is shipped** |
| 512.4-A | 6 | 1921–1923 | class 5 *Congresses and Conferences* — **no class-5 subject table is shipped** |
| **867.12** | 4 | 1924 | class 8 · country 67 **Turkey** · `.12` **Public health** |
| 512.4B3 | 4 | 1938 | class 5 *Congresses and Conferences* — no subject table |
| 150.655 | 3 | 1911 | class 1 — no subject table |
| 512.4-B | 3 | 1925–1926 | class 5 — no subject table |
| 711.429 | 1 | 1929 | class 7 *Political Relations · Bi-lateral Treaties* — no subject table |

Plus, for the other two senses: `821.12` **Colombia · Public health** (5, PROGRAM), `811.612`
**United States · Pests affecting plant life** (1), and the ANIMAL classes `662.11173` (19, Germany,
the barley file), `611.125` (14), `611.3556` (5, the Argentine meat file), `611.1256` (6), `612.325` (2).

**Two honest limits on that table.** (a) For classes 6 and 7 the country code is a *pair* and my
parser glosses only the first two digits — which is why `611.3556` reads "United States" when it is
really US–Argentina. Treat the class-6/7 rows as raw keys, not as resolved answers. (b) The subject
vocabulary the file ships covers **only classes 6 and 8** (`subjects` has exactly two keys), so
`512.4` — the *International Congresses and Conferences* file, which is precisely where the sanitary
conferences live — **has no gloss in the bundle at all**. That is a gap in the shipped schedule, not
in the archive.

**So the roadmap, stated plainly:** for 1910–1949 this topic is **RG 59 Central Decimal File**, in
two places — `5 1 2 . 4 *` (the conference series) and `8 <country> . 1 2` (each state's public-health
file: Egypt 883.12, China 893.12, Turkey 867.12).

### Channel B: pointed-at (`external_citations`, many rows per document)

**2 rows over 2 of the 129 HUMAN documents.** That is not a measurement failure — it is the channel's
shape. `external_citations` holds 49,687 rows over 31,740 documents corpus-wide, has **no row before
1910-12-06**, stores the citation fragment rather than the sentence, and carries only lot, library and
decimal anchors. This topic is overwhelmingly pre-1940 and its footnotes cite printed treaty series
rather than archives. Corpus-wide, the health classes barely appear in it at all: `411.12` 5,
`723.12` 3, `893.12` 3, `883.12` 1.

**Do not add the two channels.** 73 came-from and 2 pointed-at are answers to different questions.

### The volumes that cite nothing

From `collection-usage-index.json` (`volumeNoteCounts`, script `usage.py`): of the 22 on-topic
volumes, **six print zero source notes** — `frus1895p1`, `frus1900`, `frus1901`, `frus1904`,
`frus1905`, `frus1906p2`. Confirmed at document grain by reading: `frus1880/d4`, `frus1866p2/d205`
and `frus1874/d26` all have `source_note = None`. **The whole 19th-century and early-1900s half of
this topic reaches you with no archival pointer whatsoever.** That is why the chapter headings, not
the citations, are the finding aid for it.

Across those 22 volumes the provenance mix is **12,592 centralDecimalFile / 109 previouslyPublished /
18 unrecognized / 11 namedFileSeries** of 12,730 notes, and **0 of 1,839 authority collections are
reached** — no lot file, no presidential library, nothing named. Consistent with the offline stack
barely reaching before 1940. (This is a *volume*-scope number, i.e. everything those volumes cite, not
just the sanitary chapters — a coarser grain than the per-document table above, and I am labelling it
as such rather than letting the two be confused.)

### What you can see before travelling

- **`digitized-ranges-index.json`: nothing.** The whole artifact (624 ranges) covers only classes
  **131, 131.1, 133, 133.1** (visa/passport reports) and **763, 763.72\*** (the WWI Europe file).
  **No sanitary or quarantine class is digitised.** *I got this wrong on the first pass* — my initial
  containment test compared `883.12` against a range's numeric `low`/`high` while ignoring that
  range's own `decimalClass` field, and reported all eleven classes as covered. Both scripts are on
  disk: `jsonarch.py` (wrong) and `jsonarch2.py` (corrected). The decisive difference is one
  predicate — `str(r["decimalClass"]) == c` — and the answer flips from 11 of 11 covered to 0 of 11.
- **The pre-1910 material, by contrast, is on microfilm and scanned.** Nine `File No. NNNN` citations
  in the HUMAN scope resolve against `central-files-index.json`'s `numericalFile` block (microfilm
  **M862**, series naId 654171, 1,261 rolls) to **two rolls, both carrying a scan row in
  `roll-scans-index.json`**:

  | roll | naId | catalogue | documents |
  |---|---|---|---|
  | Numerical File 7662–7680 (case 7666) | **19839584** | catalog.archives.gov/id/19839584 | `frus1907p2/d231`, `/d232`, `/d233`, `/d234` — the Mexico City 1907 convention file |
  | Numerical File 20233–20272 (case 20272) | **20614612** | catalog.archives.gov/id/20614612 | `frus1909/d4`, `/d612`, `/d613`, `/d614`, `/d615` — the San José 1909 convention file |

  *This too took a correction.* My first pass matched `File No. (\d+)` and resolved the **1911**
  citation `File No. 158.931/64` to "case 158", inventing a roll. The final pass gates on both form
  (`(?!\.\d)` — a decimal class always has an internal dot) and date (`< 1910-08-01`), and rejects 13
  of 22 candidates on those grounds. Scripts `numfile.py` (wrong) and `numfile2.py` (corrected).

- **For 1945 onward** the record moves into lot files and subject-numeric. Resolving the lots that
  carry WHO/public-health documents against `central-files-index.json` + `series-facts-index.json`
  (`schemaVersion 2` — this shipped copy has **no top-level `legend`** and no `cy0`/`cy1` coverage
  pair, so only the inclusive span is available):

  | lot | RG | naId | series | creator | span | access |
  |---|---|---|---|---|---|---|
  | 63D351 | 59 | 2839192 | Records Relating to National Security Council Policy | Office of the Secretary, Executive Secretariat | 1947–1979 | Restricted – Partly |
  | 62D430 | 59 | 2839191 | Subject and Special Files | Executive Secretariat | 1953–1961 | Restricted – Partly (**divided** — see `lot-claimants-index.json`) |
  | 60D513 | 59 | 2108782 | Office Files | ARA, Office of the Special Assistant | 1956–1958 | Unrestricted |
  | 60D665 | 59 | 2660902 | Records Relating to the Inter-American Cultural Council | ARA, Inter-American Regional Political Affairs | 1951–1960 | Unrestricted (**divided**) |
  | 82D298 | 59 | 1274403 | Records of Anthony Lake | Policy Planning Staff, Office of the Director | 1977–1981 | Restricted – Partly |

  `89D137` and `55D36` are **not in** `central-files-index.json` (1,065 lots). Three of these lots are
  in `lot-claimants-index.json` (123 divided lots), i.e. NARA splits them across several series and
  the single naId above is one correct answer, not the only one. And per the house rule on creator
  attribution: I have **not** verified any of these creator headings against the series itself — they
  are NARA's own attribution and should be checked before being called on-topic.

---

## 10. A negative, and where the record actually is

**The 1951 International Sanitary Regulations are not in this corpus under that name.** The phrase
`"international sanitary regulations"` returns exactly two documents — `frus1880/d4` and
`frus1888p1/d6` — and I verified both are **literal** uses (tolerant regex, case-insensitive) of the
words in their 19th-century generic sense, quoted from text I retrieved this session: `frus1880/d4`
speaks of "proper subjects for international sanitary regulations"; `frus1888p1/d6` of the incubation
period reckoned "in accordance with the international sanitary regulations". Neither is the WHO
instrument.

That is a corpus-scoping negative, so here is the second half of it. The successor record is not
missing, it is filed elsewhere: `"world health organization"` appears in **156 documents across 81
volumes** (8 in the 1940s, 23 in the 1950s, 8 in the 1960s, 35 in the 1970s, 15 in the 1980s), and the
documents that carry it sit in the international-organisation and subject-numeric files —
`501.BB` (3), `341.9` (2), `320` (2), `310` (2), and subject-numeric designators `SOC 11-15 UN`,
`UN 3-1`, `UN 6 CHICOM` — plus the Executive Secretariat lots in the table above. For the ISR
themselves you want the WHO's own archive in Geneva and RG 59's international-organisation files, not
FRUS.

Similarly, before claiming the corpus lacks early coverage I searched the counterparties' vocabulary
rather than only later American names for the office, and found the founding documents. **They are
printed, under other names**, and I retrieved all three whole:

- `frus1866p2/d205` — Morris to Seward, Constantinople, 23 Dec 1865, enclosing the Sublime Porte's
  invitation to the **1866 Constantinople International Sanitary Conference**, described in the
  enclosure as convened on the French proposal against "the cholera and its propagation".
- `frus1874/d26` — Baron Lederer to Fish, 16 June 1874, the Austro-Hungarian invitation to the
  **1874 Vienna conference**.
- `frus1880/d4` — the Department's circular of 30 July 1880 to all diplomatic officers announcing
  that, "in pursuance of a joint resolution of Congress" approved 14 May 1880, the President had
  determined **to call an international sanitary conference to meet at Washington** — the United
  States as convening power. This is the founding document for American participation and it carries
  **no source note**.

---

## 11. Subject tags — usable for retrieval, not for scoping

`document-subject-index.json` ships a 491-term vocabulary. It contains **no** tag for quarantine,
sanitation, epidemic, cholera or infectious disease. The nearest is **`Public Health`** (subject id
102, category *Global Issues*), which tags **914 documents in 300 volumes**.

- **Literal precision (census of all 914, tolerant regex, case-insensitive Python `re`): 914 of 914 =
  1.000** contain the literal phrase.
- **Recall against the editors' own scope: 47 of 129** HUMAN documents are tagged.

So the tag is honest about what it matches and misses roughly two-thirds of the topic. The artifact's
own provenance string is a caveat you should carry: the tags are "**Detected topics from
case-insensitive string matching of subject names and variants, NOT semantic analysis — treat as
recall-oriented candidates rather than ground truth**".

---

## 12. Reading accounting

I retrieved **10 documents whole** — captured length equals `length(body_text)` for all ten, verified
per document (script `read.py`, raw text kept in `reads/`):

`frus1880/d4` (8,607 chars) · `frus1866p2/d205` (2,711) · `frus1874/d26` (13,434) ·
`frus1879/d322` (28,541) · `frus1908/d468` (11,040) · `frus1926v01/d116` (**122,539** — the printed
text of the 21 June 1926 Paris convention) · `frus1930v02/d595` (1,232) · `frus1938v01/d930` (6,110) ·
`frus1900/d1030` (453) · `frus1928v02/d756` (3,250).

Character counts, not bytes. I **quoted from 3** of them (`frus1880/d4`, `frus1866p2/d205`,
`frus1874/d26`, in §10), plus the two literal windows verified in §10 from `frus1880/d4` and
`frus1888p1/d6`. I read no `summary_text` and no `note_text`.

---

## 13. Corrections I made to my own work

| what I first reported | decisive test, both sides | corrected |
|---|---|---|
| All 11 topic decimal classes are covered by a digitised range | `jsonarch.py`: `float(r["low"]) <= 883.12 <= float(r["high"])` → 11 of 11 covered. `jsonarch2.py`: `str(r["decimalClass"]) == "883"` → 0 ranges, and the artifact's whole class vocabulary is `{131, 131.1, 133, 133.1, 763, 763.72*}` | **0 of 11 covered** |
| 21 of 21 Numerical-File citations resolve to a roll | `numfile.py`: `File\s*No\.?\s*(\d+)` matched `File No. 158.931/64` (dated 1911) as case 158. `numfile2.py`: `(?!\.\d)` + `date_iso < '1910-08-01'` rejects it and 12 others | **9 of 22 resolve**, to 2 rolls |
| (interim) form gate `(?![\d]*\.)` | it also rejected `File No. 20272.` — a trailing full stop is sentence punctuation, not a decimal point; `frus1909/d4` was lost | regex changed to `(?!\.\d)`; 8 → 9 resolved |
| 0 of 491 subject terms match health vocabulary | I read the vocabulary rows with `.get('name')`; the field is `n` | **11 of 491** match; `Public Health` = id 102 |

Two shell commands also failed outright and were re-run: an unqualified `COUNT(DISTINCT volume_id)`
(ambiguous column) and two quoted-phrase terms in the false-friend shell loop (shell quoting); both
re-run in `falsefriend.py`. `SELECT ... FROM document_subjects WHERE name LIKE ...` failed — that
table has no `name` column, the vocabulary is in the JSON. All four are in `queries.log` in place.

---

## 14. Files on disk

| file | what it holds |
|---|---|
| `queries.log` | every command that touched a surface, in order, nothing elided |
| `headings-out.txt` | the 76 topical section titles — **start here** |
| `scope-ids.tsv` | the 192 (label, volume_id, document_id, sectionId, title) rows behind §2 |
| `litshare-out.json` | §4, per family: M, mode, strict/tolerant counts, the miss list |
| `referent-quarantine.json`, `referent-sanconv.json` | §3 classifications, every id listed |
| `class-keys.json` | §9 — every document id behind each decimal class key |
| `tei-agg.json`, `tei-0-80.json` … `tei-420-552.json` | §7 per-volume variant counts, all 550 volumes |
| `reads/*.txt` | the 10 documents retrieved whole |
| `headings.py` `scope.py` `litshare.py` `referent.py` `crosstab.py` `falsefriend.py` `archival.py` `gloss.py` `jsonarch.py` `jsonarch2.py` `numfile.py` `numfile2.py` `usage.py` `teiscan.py` `teiagg.py` `read.py` `rates.py` `lots.py` | the scripts, including the two superseded ones |
