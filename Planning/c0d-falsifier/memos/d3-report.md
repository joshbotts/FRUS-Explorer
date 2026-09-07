# Scoping memo — United States assertions of maritime neutrality in wartime

**Run directory (everything cited below is on disk here):**
`/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer/02d9a891-c562-471b-845c-53aa054cd34e/scratchpad/c0d/runs/d3`
Full command list in `queries.log` (with its `ELIDED:` declarations).

---

## 0. Coverage, and the standing caveat

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library holds **all 552 volumes**, 316,839 documents, of which 1,012 are front matter and
8,468 editorial notes. Everything below excludes those two classes and suppresses the two
second editions whose first editions are also present (`frus1951-54IranEd2`,
`frus1969-76ve15p2Ed2`; `frus1977-80v09Ed2` is kept — it has no first edition). That leaves
**306,619 non-apparatus documents**, of which **305,280 carry a `frus:doc-dateTime-min` date**
and 1,339 do not. All periodisation below is on that date, never on the volume's series year.

Because the library is complete at the volume level, none of the counts here are thin *because of
your download set*. Where a count is thin it is thin in FRUS.

**Controls, run in the same pass (index surface):**

```sql
SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"Department of State"';        -- 98499
SELECT COUNT(DISTINCT volume_id) FROM frus_documents WHERE frus_documents MATCH '"Department of State"';  -- 551
SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ';           -- 0
```

Positive control fires in 551 of 552 volumes; negative control returns 0. The single volume
without it is `frus1919Parisv05` (a Paris Peace Conference minutes volume), identified by an
`EXCEPT` against the volume list. Controls were re-run independently on the TEI surface in §5:
3,916 occurrences positive, 0 negative.

---

## 1. The headline

The corpus is **very strong** on this question, and its strength is **twin-peaked and
asymmetrical**. Two peaks:

* **1861–1872** — the United States arguing the question *as a belligerent*: enforcing a blockade,
  defending it against neutral protest, and simultaneously (Seward, April 1861) offering to accede
  to the Declaration of Paris. The Alabama Claims arbitration volumes of 1872 are the densest
  doctrinal deposit in the whole series.
* **1914–1920** — the United States arguing it *as the principal neutral*, against both
  belligerents at once. This is by a wide margin the largest body of material.

A third, much smaller and legally different peak sits in **1939–1941** (Declaration of Panama
security zone, the Neutrality Acts, the Havana maritime-neutrality convention of 1928 being
invoked). It is a *hemispheric-zone* argument rather than a *neutral-rights-at-sea* argument, and
it should not be pooled with the first two.

The corpus **does not contain** the founding American assertions — 1793, the Jay Treaty, 1812,
Marcy's 1854 propositions — as documents. FRUS begins in 1861. Only **2** documents in the whole
union family predate 1861, and both are retrospective exhibits inside the 1872 arbitration volume
(`frus1872p2v1/d147`, 1855-08-09; `frus1872p2v1/d176`, 1856-04-20). The relevant founding text is
nonetheless *printed under another name*: **`frus1861/d4`** (Seward's circular of 24 April 1861 to
the ministers at London, Paris, St Petersburg, etc.) recites Marcy's 1854 propositions verbatim,
including "free ships make free goods." I read this document whole (§6).

---

## 2. What I would search for — and what I would not

### 2.1 The question's own phrase fails the false-friend test. Do not use it.

`"maritime neutrality"` is a real term of art in this corpus, but a useless search key.

| term | hits in the 18 on-topic volumes | corpus hits | concentration |
|---|---|---|---|
| `"maritime neutrality"` | 2 of 13,578 = 0.0001 | 21 of 306,619 = 0.0001 | **2.15×** |
| control `"Department of State"` | 3,151 of 13,578 = 0.2321 | 93,418 of 306,619 = 0.3047 | 0.76× |
| control `"international law"` | 766 of 13,578 = 0.0564 | 6,021 of 306,619 = 0.0196 | 2.87× |
| the 19-phrase union family (§2.2) | 1,716 of 13,578 = 0.1264 | 3,072 of 306,619 = 0.0100 | **12.61×** |

The question's phrase concentrates on-topic **less than the generic phrase "international law"
does**. It is measuring the corpus, not the question. I stopped using it as a search key.

It is not worthless, though — it is *precise*. I censused all 21 documents and read the
surrounding 180 characters of each (`maritime_neutrality_referent.txt`): **21 of 21 are genuinely
about maritime neutrality as a legal doctrine.** A 1.000 literal share tests the stemmer, so I
tested the referent separately, and it holds. What the phrase finds is the *codification* thread —
Hague Convention XIII (1907), the Alabama arbitration's "revision of the rules of maritime
neutrality," and above all **`frus1928v01/d367`, the text of the Convention Regarding Maritime
Neutrality, Habana, 20 February 1928** (Treaty Series No. 845), which is then cited back at the
United States by Germany in 1940 and 1941 (`frus1940v05/d383`, `frus1941v01/d456`) and by the
United States to Uruguay in 1939 (`frus1939v05/d122`). Use the phrase to find that spine of six or
seven texts; do not use it to find the correspondence.

### 2.2 Use the editors' formulas, not modern phrasing

I read the chapter headings first (`headings.py` → `headings.txt`, a walk over
`volume_structures.structure_json` for all 552 volumes; 684 headings matched a maritime/neutrality
regex). The editors use repeating formulas, and they are the search keys:

* "**Establishment of control measures by the belligerents interfering with neutral commerce;
  reservations by the United States of American rights**" (frus1939v01, 88 documents)
* "**Proclamations, orders, and decrees of belligerent governments on contraband of war and trade
  with enemy countries**" (frus1914Supp, 63 documents)
* "**Departures by belligerent governments and naval authorities from the established rules for
  exercise of the right to visit and search at sea**" (frus1916Supp)
* "**Treatment of armed merchant ships**" (frus1914Supp/1915Supp/1916Supp — three consecutive years)
* "**The German declaration of a naval war zone (February 4, 1915): Position taken by the United
  States**" (frus1915Supp, 40 documents)
* "**Efforts toward recognition of the Declaration of London**" (frus1914Supp, 63 documents)
* "**Projects of cooperation among the neutral states in defense of neutral rights**" (frus1916Supp)
* "**Violations by the belligerents of the Security Zone established by the Declaration of Panama**"
  (frus1939v05, frus1940v01)
* "**Entrance of neutral men-of-war into blockaded ports**" (frus1898)
* "**Neutral commerce in articles conditionally contraband of war**" (frus1904 — Russo-Japanese War)
* "**The revision of the rules of maritime neutrality**" (frus1873p2v3 — the Alabama aftermath)

The nineteen-phrase **union family** I settled on is:
`"neutral rights"`, `"rights of neutrals"`, `"neutral commerce"`, `"neutral trade"`,
`"freedom of the seas"`, `"maritime neutrality"`, `"contraband of war"`, `"conditional contraband"`,
`"visit and search"`, `"right of search"`, `"declaration of london"`, `"declaration of paris"`,
`"armed merchant"`, `"neutral vessels"`, `"neutral ships"`, `"neutral flag"`, `"neutral ports"`,
`"prize court"`, `"free ships"` — OR'd in one FTS5 MATCH.

```sql
SELECT f.volume_id, COUNT(*) n
FROM frus_documents f
JOIN document_cache dc ON dc.volume_id=f.volume_id AND dc.document_id=f.document_id
WHERE f.frus_documents MATCH ? AND dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
GROUP BY f.volume_id ORDER BY n DESC;
-- 3,072 documents across 273 volumes
```

---

## 3. What I measured

### 3.1 Every phrase count below carries its literal share

The FTS tokenizer is porter-stemmed, so a phrase MATCH also returns different words with the same
stem. I therefore re-tested every family against the index's own stored flattened text
(`header || dateline || source_note || body_text`, whitespace-collapsed), twice: **STRICT** =
single spaces between the literal words; **TOLERANT** = each word allowed its inflections with any
run of space/hyphen/comma/parenthesis/full stop between them. Both regexes were **Python `re` with
`re.IGNORECASE`** — one implementation for the whole family, not a mix of SQL `LIKE` and Python.
Families of 300 or fewer were **censused**; larger families took an evenly spaced 40 from the
`(volume_id, document_id)`-sorted hit list. Script `shares.py`, output `shares.txt`.

| family | FTS docs | mode | tested | STRICT share | **TOLERANT share** |
|---|---|---|---|---|---|
| maritime neutrality | 21 | census | 21 | 21 of 21 = 1.000 | 21 of 21 = 1.000 |
| neutral rights | 222 | census | 222 | 210 of 222 = 0.946 | **221 of 222 = 0.995** |
| rights of neutrals | 216 | census | 216 | 143 of 216 = 0.662 | **216 of 216 = 1.000** |
| neutral commerce | 135 | census | 135 | 134 of 135 = 0.993 | **135 of 135 = 1.000** |
| neutral trade | 106 | census | 106 | 103 of 106 = 0.972 | **105 of 106 = 0.991** |
| freedom of the seas | 241 | census | 241 | 221 of 241 = 0.917 | **241 of 241 = 1.000** |
| visit and search | 166 | census | 166 | 140 of 166 = 0.843 | **164 of 166 = 0.988** |
| right of search | 147 | census | 147 | 143 of 147 = 0.973 | **147 of 147 = 1.000** |
| declaration of london | 199 | census | 199 | 199 of 199 = 1.000 | **199 of 199 = 1.000** |
| declaration of paris | 90 | census | 90 | 89 of 90 = 0.989 | **90 of 90 = 1.000** |
| armed merchant | 107 | census | 107 | 91 of 107 = 0.850 | **107 of 107 = 1.000** |
| conditional contraband | 150 | census | 150 | 150 of 150 = 1.000 | **150 of 150 = 1.000** |
| contraband of war | 527 | sample 40 | 40 | 40 of 40 = 1.000 | **40 of 40 = 1.000** |
| prize court | 714 | sample 40 | 40 | 38 of 40 = 0.950 | **40 of 40 = 1.000** |
| neutral vessels | 458 | sample 40 | 40 | 33 of 40 = 0.825 | **40 of 40 = 1.000** |
| neutral ports | 493 | sample 40 | 40 | 24 of 40 = 0.600 | **40 of 40 = 1.000** |
| neutral flag | 187 | census | 187 | 145 of 187 = 0.775 | **187 of 187 = 1.000** |
| blockade | 4,864 | sample 40 | 40 | 33 of 40 = 0.825 | **40 of 40 = 1.000** |

Every family is at or above 0.988 tolerant. **Nothing here is unusable.** Note how far apart the
two columns are for `neutral ports` (0.600 strict) and `rights of neutrals` (0.662) — that gap is
entirely inflection ("neutral port," "rights of a neutral," "neutrality's rights"), which is
precisely why an unlabelled share is worse than none.

I read the only four tolerant misses rather than condemning the families:

| miss | what is actually in the text |
|---|---|
| `frus1915Supp/d831` | "the **neutrals' right** to indemnity for goods not liable to seizure" |
| `frus1939v01/d824` | "the increase of the **neutrals' trade** with Great Britain" |
| `frus1886/d173` | "four several **visitations and searches** of the vessel" |
| `frus1887/d332` | "the seizure was preceded by **visitations and searches**" |

All four are the referent under a curly-apostrophe possessive or an unmodelled nominalisation my
TOLERANT pattern did not cover. The honest tolerant shares are therefore 222 of 222, 106 of 106
and 166 of 166 — i.e. 1.000 across the board. (Context strings retrieved in this session; the
diagnostic is command [17] in `queries.log`.)

### 3.2 Decade shape, with rates

Never raw counts alone: the 1940s holds 74,043 dated non-apparatus documents and the 1870s 5,798.
`decades.py` → `decades.txt`. Rates are per 1,000 of that decade's dated non-apparatus documents.

**Core neutral-rights family** (`neutral rights` OR `rights of neutrals` OR `neutral commerce` OR
`neutral trade` OR `freedom of the seas` OR `maritime neutrality`), 799 dated hits:

| decade | hits | decade denominator | per 1,000 |
|---|---|---|---|
| 1860s | 117 | 11,250 | **10.40** |
| 1870s | 53 | 5,798 | **9.14** |
| 1880s | 16 | 6,472 | 2.47 |
| 1890s | 9 | 9,712 | 0.93 |
| 1900s | 20 | 9,924 | 2.02 |
| **1910s** | **328** | **30,359** | **10.80** |
| 1920s | 24 | 19,733 | 1.22 |
| 1930s | 63 | 39,196 | 1.61 |
| 1940s | 61 | 74,043 | 0.82 |
| 1950s | 47 | 42,296 | 1.11 |
| 1960s | 22 | 27,650 | 0.80 |
| 1970s | 34 | 22,259 | 1.53 |

**Contraband family** (`contraband of war` OR `conditional contraband` OR `absolute contraband`),
668 dated hits: 1860s 150/11,250 = 13.33; 1870s 77/5,798 = 13.28; 1900s 66/9,924 = 6.65; 1910s
270/30,359 = 8.89; and then it **stops** — 1920s 5, 1930s 19, 1940s 10, 1960s 1. Contraband law is
a nineteenth-century-to-1918 vocabulary in this corpus.

**Visit and search**, 333 dated hits: 1860s 4.09, 1870s 4.14, 1910s 3.56 per 1,000, decaying to
0.09 by the 1970s.

**Blockade**, 4,860 dated hits, is the one family with a *third* life: 1860s 65.16 per 1,000 (the
Union blockade), 1910s 25.36, then 1940s 12.99, 1950s 18.04, **1960s 19.39** — but by then it means
Cuba and Vietnam, not neutral rights. Blockade is the family most likely to mislead you; do not
run it alone.

**Top-volume share of the numerator, for the small decades.** The house rule matters here — a small
decade's rate can be one negotiation. For the core family the 1870s' 53 hits are concentrated in
the Alabama-arbitration volumes: `frus1872p2v3` alone contributes 20 of its volume's 40
non-apparatus documents (a 0.500 within-volume share for the full union family — the highest in the
corpus), and `frus1872p2v2` 19. The 1870s rate is substantially *one arbitration*.

### 3.3 Where the material is — the 18-volume scope

I defined an on-topic scope mechanically: a volume qualifies if the union family hits **≥ 15
documents** *and* covers **≥ 5% of that volume's non-apparatus documents**. Eighteen volumes
qualify, holding 13,578 non-apparatus documents (`scope_volumes.txt`):

```
frus1861 frus1862 frus1863p1 frus1864p1 frus1864p2 frus1865p1
frus1872p2v2 frus1872p2v3 frus1904
frus1914-20v01 frus1914Supp frus1915Supp frus1916Supp
frus1917Supp01v01 frus1917Supp02v02 frus1918Supp01v02 frus1920v02 frus1939v01
```

Ranked by hits, with the within-volume share (from `topvols.txt`):

| volume | hits | volume non-apparatus docs | share |
|---|---|---|---|
| frus1915Supp | 351 | 1,527 | 0.230 |
| frus1914Supp | 261 | 1,346 | 0.194 |
| frus1916Supp | 224 | 1,316 | 0.170 |
| frus1914-20v01 | 130 | 706 | 0.184 |
| frus1918Supp01v02 | 87 | 912 | 0.095 |
| frus1917Supp01v01 | 87 | 964 | 0.090 |
| frus1863p1 | 85 | 695 | 0.122 |
| frus1939v01 | 79 | 1,160 | 0.068 |
| frus1864p2 | 67 | 594 | 0.113 |
| frus1904 | 63 | 953 | 0.066 |
| frus1861 | 61 | 312 | **0.196** |
| frus1862 | 54 | 720 | 0.075 |
| frus1920v02 | 42 | 812 | 0.052 |
| frus1872p2v3 | 20 | 40 | **0.500** |

Just outside the cut but worth your time: `frus1898` (36 hits — Spanish-American War proclamations
of neutrality), `frus1900`, `frus1910` (International Prize Court), `frus1940v01` / `frus1940v05` /
`frus1939v05` (Declaration of Panama), `frus1919Parisv02` (whose compilation heading is *The
Blockade and Regulation of Trade*), `frus1917Supp02v01`, `frus1865p1–p3`, `frus1866p2`,
`frus1871`, `frus1879`, `frus1923v01`.

### 3.4 The subject-tag axis is unsafe here — one tag measurably so

Subject tags are string-matched candidates, not semantic analysis (the artifact's own provenance
string says: *"Detected topics from case-insensitive string matching of subject names and
variants, NOT semantic analysis — treat as recall-oriented candidates rather than ground truth."*).
Four tags look relevant; I tested each against a literal regex over the stored text
(`tag_precision.txt`):

| tag | tagged docs in scope | tested | literal hits | share |
|---|---|---|---|---|
| Antisubmarine warfare (id 348) | 222 | 222 (census) | 1 | **1 of 222 = 0.005** |
| Neutrality (id 374) | 1,380 | 40 | 38 | 38 of 40 = 0.950 |
| Contraband of war (id 358) | 336 | 40 | 37 | 37 of 40 = 0.925 |
| Blockade (id 132) | 940 | 40 | 36 | 36 of 40 = 0.900 |

**Do not use the "Antisubmarine warfare" tag.** It puts 222 documents in an eighteen-volume scope
in which every volume is dated 1939 or earlier, and exactly **1 of 222** contains the string
`anti-?submarine`. Corpus-wide it claims 510 documents in 123 volumes. The other three are usable
as recall aids at 0.90–0.95, but "Neutrality" is a bare single word claiming 7,674 documents in
**511 of 552 volumes** — that is a corpus-wide word, not a topic.

---

## 4. Archival scope — where these documents came from, and where the footnotes point

**These are two channels. They are never summed.** Both are reported for the same 18-volume scope.

### 4.1 Came-from channel (`document_sources`, one row per document)

```sql
SELECT citation_era, COUNT(*) FROM document_sources WHERE volume_id IN (<18 scope volumes>) GROUP BY 1;
-- decimal 8729 | unrecognized 187 | named_series 31 | published 13   (8,960 rows total)
SELECT COALESCE(repository,'(null)'), COUNT(*) FROM document_sources WHERE volume_id IN (<18>) GROUP BY 1;
-- Department of State 8729 | (null) 231
```

8,960 of the scope's 13,578 documents carry a source note, and **8,729 of 8,960 are State
Department decimal-file citations**. The bundled `collection-usage-index.json`, read independently
over the same volume set, reproduces those four numbers exactly (8,729 / 187 / 31 / 13) and the
same class ranking — two surfaces agreeing, which is the only cross-check I have for either.

**A hole you must know about.** The came-from channel barely reaches the Civil War peak:

| volume | source-note rows | volume non-apparatus docs |
|---|---|---|
| frus1861 | 126 | 312 |
| frus1862 | 18 | 720 |
| frus1863p1 | 8 | 695 |
| frus1864p1 | 11 | 399 |
| frus1864p2 | 3 | 594 |
| frus1865p1 | 0 | 391 |
| frus1872p2v2 | 1 | 272 |
| frus1872p2v3 | 0 | 40 |

The nineteenth-century volumes print no source notes. **167 rows for eight volumes holding 3,423
documents.** Any archival ranking you build for the 1861–1872 peak from this channel is an
artifact of FRUS's editorial practice, not of the archive.

**Top decimal classes in scope** (`document_sources`, decimal_class not null):

| class | docs | volumes | date span of the citing documents |
|---|---|---|---|
| 763.72 | 1,524 | 7 | 1911-11-27 → 1918-10-05 |
| 763.72112 | 928 | 8 | 1914-07-31 → 1919-02-20 |
| 763.72111 | 480 | 7 | 1911-09-26 → 1918-08-22 |
| 763.72119 | 303 | 7 | 1914-07-28 → 1920-10-01 |
| 300.115 | 289 | 7 | 1914-08-12 → 1939-10-23 |
| 656.119 | 207 | 2 | 1917-08-08 → 1918-12-18 |
| 740.00 | 138 | 1 | 1939-01-24 → 1939-09-19 |
| 600.119 | 138 | 2 | 1917-04-09 → 1918-11-30 |
| 652.119 | 116 | 2 | 1917-05-05 → 1918-11-22 |
| 658.119 | 108 | 2 | 1917-05-19 → 1918-12-17 |
| 657.119 | 75 | 2 | 1917-09-21 → 1918-11-01 |

**Glossing, and its limit.** `decimal-class-labels.json` on this build ships **one** schedule,
`1910-1949`; there is no top-level `coverage` key on this file (I read the file's own keys), so the
gate is `schedules[0].startYear`/`endYear`. Every class above sits inside it. The class digit and
country number gloss cleanly — class 7 = *Political Relations of States. Bi-lateral Treaties*,
class 6 = *Commerce. Customs Administration*, class 3 = *Protection of Interests*; country 63 =
Austria, 56 = Netherlands, 52 = Spain, 58 = Sweden, 57 = Norway, 41 = Great Britain. **The subject
suffixes do not gloss**: the shipped `subjects` table is nested under classes `6` and `8` only
(sizes 1 and 692), and **0 of the top 20 scope classes** got a suffix gloss. I am therefore
*not* telling you that `.72111` means anything. What the evidence does support, from the pattern
of use, is: 763.72 is the general European War file, 763.72111 / .72112 / .72119 its neutrality,
trade-interference and detention subdivisions, and the `6NN.119` run is the Commerce class keyed to
each *neutral* country (Netherlands, Spain, Sweden, Norway) in 1917–18. Verify against the
published schedule before citing.

A first pass at this gloss composed the suffix against a flat `subjects` table and printed
plausible-looking readings for `.72112` and `.119`; that pass is `decimal_gloss.txt` and it is
**wrong**. The corrected pass, using `relationsClasses`/`countryArrangedClasses`, is
`decimal_gloss2.txt`. I have kept both.

### 4.2 Pointed-at channel (`external_citations`, many rows per document)

This channel has **no row before 1910-12-06**, stores the citation fragment rather than the
sentence, and holds lot, library and decimal anchors only. Say that before ranking anything on it —
so, first, the ranking:

```sql
SELECT COUNT(*), COUNT(DISTINCT volume_id||'/'||document_id) FROM external_citations WHERE volume_id IN (<18>);
-- 168 rows | 156 documents
SELECT anchor, COUNT(*) FROM external_citations WHERE volume_id IN (<18>) GROUP BY 1;
-- centralFileClass 167 | presidentialLibrary 1
```

**168 rows over 156 of 13,578 scope documents (1.1%).** All eight contributing volumes are
1914–1939; the ten pre-1910 scope volumes contribute zero, by construction. The one non-decimal
anchor is a single Franklin D. Roosevelt Library citation. Top classes pointed at: 763.72112 (30),
763.72 (28), 760d.61 (9), 658.119 (8), 763.72111 (6), 656.119 (6), 300.115 (6).

The pointed-at channel is **too thin to rank** for this question. It is the same decimal file the
documents came out of. That is itself the finding: for 1914–1918, FRUS's editors were not sending
the reader anywhere else.

### 4.3 Only one authority collection is reached, and no series facts are

Over the 18-volume scope, `collection-usage-index.json` reaches exactly **one** authority
collection — *War Trade Board Files*, 31 documents. Everything else is central decimal file, which
the authority does not model as a collection.

`series-facts-index.json` on this build is `schemaVersion 2` with **695 rows and no `legend` key**.
I probed the five NAIDs my scope actually needs — 654171 (1906–1910 Numerical File), 177380725 and
177380755 (pre-1906 despatch series), 2555709 and 302021 (the decimal-file series) — and **all five
return null.** So there is no creator, extent, facility or access status available offline for a
single archival unit behind this question. That is consistent with the known limit that the offline
stack barely reaches before 1940. Do not read the empty result as an archival absence; it is an
index-coverage absence.

### 4.4 "FRUS does not print this" — and here is the series that does

FRUS prints a selection. For each half of the scope I resolved the parent series as far as the
bundled indexes reach:

**Pre-1906 (the Civil War and Alabama peaks).** `central-files-index.json`'s `countrySeries`
holds twelve pre-decimal RG 59 runs at file-unit grain: *Diplomatic Despatches* (2,160 rolls),
*Diplomatic Instructions* (177), *Notes from / to Foreign Missions* (522 / 104), *Consular
Despatches* (3,357), *Domestic Letters* (272), *Despatches from Special Agents* (22), and others.
The Civil War correspondence FRUS excerpted sits in, e.g., **"Despatches from U.S. Ministers to
Great Britain, 1791–1906," fileUnit NAID 177380725** — which is where the unprinted three-quarters
of Adams's London despatches are. This is the answer to the 167-source-note hole in §4.1.

**1914–1920 (the main peak) — and it is digitised.** This is the most useful thing I found.
`digitized-ranges-index.json` (generated 2026-08-07, series NAIDs 2555709 and 302021) covers only
**18 decimal classes in total** — and four of them are exactly this question's classes:

| class | digitised ranges | serial span | digitised objects |
|---|---|---|---|
| 763.72 | 110 | 72–13616 | 94,813 |
| 763.72111 | 31 | 301–7321 | 23,546 |
| 763.72112 | 51 | 393–12946 | 49,963 |
| 763.72119 | 137 | 151–12420 | 107,654 |

That is **276,000-plus digitised images across the four core WWI neutrality classes**, in NARA
microfilm publication **M367**. I resolved a real citation end-to-end as a test: `frus1915Supp/d837`
carries the source note `File No. 763.72112/1861a`; serial 1861 falls inside the digitised range
`763.72112/1704-2074` (naId 27207956, 1,893 objects,
`catalog.archives.gov/medialive/56/2079/27207956/content/dc-metro/rg-059/M367/M367_Box_5`) and also
inside `763.72112/1107-11245` (naId 27243983). **You can read the unprinted file for this question
without travelling.** By contrast, classes 300.115, 656.119 and 740.00 have **0** digitised ranges
— the neutral-country commerce files and the 1939 material are a reading-room trip.

---

## 5. The TEI pass — counting surface, apparatus split, spelling variants

The index cannot answer a variant question (porter stemming folds the variants together) and cannot
separate a footnote from a body (`body_text` contains both). So I ran a second pass over the raw
TEI for the 18 scope volumes: `tei_variants.py` → `tei_variants_0_9.tsv`, `tei_variants_9_18.tsv`,
merged into `tei_variants_merged.txt`.

**Counting surface: tag-stripped (`<[^>]+>` → space) and whitespace-collapsed. These are
OCCURRENCE counts, not document counts, and they are not comparable to §3's document counts.**
The footnote channel is the concatenation of every `<note>…</note>`, tag-stripped identically.
Controls ran in the same pass: `department of state` = 3,916 occurrences, `ZZZ_IMPOSSIBLE_ZZZ` = 0.

| variant | occurrences | inside footnotes | outside | footnote share |
|---|---|---|---|---|
| contraband of war | 678 | 13 | 665 | 13 of 678 = 0.019 |
| Declaration of London | 580 | 9 | 571 | 9 of 580 = 0.016 |
| man/men-of-war | 357 | 5 | 352 | 5 of 357 = 0.014 |
| conditional contraband | 325 | 0 | 325 | 0 of 325 = 0.000 |
| neutral rights | 242 | 16 | 226 | 16 of 242 = 0.066 |
| visit and search | 178 | 7 | 171 | 7 of 178 = 0.039 |
| absolute contraband | 173 | 1 | 172 | 1 of 173 = 0.006 |
| rights of neutrals | 155 | 0 | 155 | 0 of 155 = 0.000 |
| Declaration of Paris | 124 | 0 | 124 | 0 of 124 = 0.000 |
| freedom of the seas | 81 | 1 | 80 | 1 of 81 = 0.012 |
| right of search | 69 | 1 | 68 | 1 of 69 = 0.014 |
| right of visit and search | 48 | 4 | 44 | 4 of 48 = 0.083 |
| freedom of the sea (singular) | 7 | 0 | 7 | 0 of 7 = 0.000 |
| visitation(s) and search(es) | 7 | 0 | 7 | 0 of 7 = 0.000 |
| free ships (make) free goods | 5 | 0 | 5 | 0 of 5 = 0.000 |
| maritime neutrality | 3 | 0 | 3 | 0 of 3 = 0.000 |
| neutrals' rights (possessive) | 1 | 0 | 1 | — |
| search and visit | **0** | 0 | 0 | — |
| neutrality of the seas | **0** | 0 | 0 | — |

Three things follow.

1. **The apparatus warning is real but small for this family in this scope.** Footnote share runs
   0.000–0.083, mostly under 0.02, against 0.022 for the positive control. Term frequencies here
   are not being driven by editorial language. (Caveat: the six Civil War volumes in the scope,
   `frus1861`–`frus1865p1`, carry almost no `<note>` markup at all — 908 to 4,507 characters of
   note text each — so this footnote share is effectively a measurement of the 1872, 1904, 1914–20
   and 1939 volumes. The two 1872 arbitration volumes are the opposite extreme, at 96,045 and
   160,917 characters of note text.)
2. **The variant split matters.** `visit and search` (178) is only two-thirds of the visit/search
   family once you add `right of visit and search` (48), `right of search` (69) and
   `visitation(s) and search(es)` (7). `contraband of war` (678) is barely more than half the
   contraband family once `conditional contraband` (325) and `absolute contraband` (173) are added
   — and the conditional/absolute distinction is itself a live 1916 issue ("*The abolition of the
   distinction between absolute and conditional contraband*", frus1916Supp).
3. **Two plausible variants return zero**, and I verified the scan works via the controls in the
   same pass: nobody in this corpus writes "search and visit" or "neutrality of the seas".

**What I did NOT do on the TEI surface**, and you should know it: I ran no corpus-wide TEI pass
(only these 18 volumes), no case-variant or acronym split (this vocabulary has no meaningful
acronyms), and no document-vs-editorial-note split beyond `<note>`. Every §3 count is
index-side and therefore stemmed, footnote-inclusive, and document-grain.

---

## 6. Documents I read

Five retrieved whole; for each, captured length equals `length(body_text)` exactly. Raw text is on
disk in `read/`; the SELECT is command [41] in `queries.log`.

| id | header | source note | chars | captured |
|---|---|---|---|---|
| `frus1915Supp/d837` | The Secretary of State to the Ambassador in Great Britain (Page), Washington, 21 Oct 1915 | File No. 763.72112/1861a | 77,790 | 77,790 ✓ |
| `frus1928v01/d367` | Convention Regarding Maritime Neutrality, Habana, 20 Feb 1928 | Treaty Series No. 845 | 16,526 | 16,526 ✓ |
| `frus1861/d4` | Mr. Seward to ministers in Great Britain, France, Russia, Prussia…, 24 Apr 1861 | (none) | 10,725 | 10,725 ✓ |
| `frus1872p2v3/d40` | No. 1. Earl Granville to Her Majesty's High Commissioners | (none) | 10,722 | 10,722 ✓ |
| `frus1939v01/d737` | The Secretary of State to the Ambassador in France (Bullitt), 27 Sep 1939 | 740.00111A Armed Merchantmen/1: Telegram | 1,121 | 1,121 ✓ |

I quoted from three of them, all retrieved in this session:

* `frus1861/d4` — Seward reciting the 1854 Marcy propositions: the powers have been "engaged with
  much assiduity in endeavoring to effect some modifications of the law of nations in regard to the
  rights of neutrals in maritime war"; proposition 1, "that free ships make free goods; that is to
  say, that the effects or goods belonging to subjects or citizens of a power or State at war are
  free from capture or confiscation when found on board of neutral vessels, with the exception of
  articles contraband of war."
* `frus1928v01/d367` — the Havana convention's own preamble: "Desiring that, in case war breaks out
  between two or more sta…"; the record notes ratification advised by the Senate 28 Jan 1932 with
  the exception of section 3 of article 12.
* `frus1939v01/d737` — the source note itself is the finding: **`740.00111A Armed Merchantmen/1`**.
  That is a *named* decimal subdivision, and it is the file to ask for on the 1939 armed-merchantman
  question.

`frus1915Supp/d837` — the 21 October 1915 note to Grey, the central American statement of the
neutral-rights case against the British blockade — I retrieved whole but quote from only in
aggregate: it runs 77,790 characters and contains `neutral` 49 times, `blockad` 41, `contraband`
27, and `Declaration of London` 3 (counts by Python `re.findall`, `re.IGNORECASE`, over the
whitespace-collapsed retrieved text). It opens by answering seven prior British notes at once.

A correction against myself: I put `frus1872p2v3/d40` on the reading list intending the
"revision of the rules of maritime neutrality" document, which is `frus1873p2v3/d40` — a different
volume. I read the wrong one and it contains no occurrence of the phrase. I make no claim from it.

---

## 7. What I would do next, in order

1. **Read `frus1915Supp` chapter by chapter, not by search.** Its headings are already an argument:
   the British note of 7 Jan 1915, the German war-zone declaration of 4 Feb, the American
   *modus vivendi* proposal of 20 Feb, the Anglo-French trade prohibition of 1 Mar, the *Wilhelmina*
   and *Dacia*, the *Frye*, the *Arabic*, and the note of 21 Oct. 351 of its 1,527 non-apparatus
   documents are in the union family.
2. **Then `frus1914Supp` and `frus1916Supp`** for the same run of headings a year either side —
   *Treatment of armed merchant ships* appears in all three consecutive volumes, which is the single
   clearest sign that the editors themselves treated this as one continuing controversy.
3. **Pair the 1861–1865 volumes with `frus1872p2v1–v4`.** The Civil War volumes show the United
   States asserting belligerent rights; the arbitration volumes show the same government, seven
   years later, having the neutral-duty doctrine argued back at it by Britain. `frus1872p2v3` is
   the densest single volume in the corpus on this question (0.500 of its documents).
4. **Treat 1939–1941 as a separate question.** The Declaration of Panama security zone, the
   Neutrality Acts, and the Havana 1928 convention are a hemispheric-zone doctrine. `frus1939v01`
   chapter I ("*reservations by the United States of American rights*"), `frus1939v05` and
   `frus1940v01` ("*Violations by the belligerents of the Security Zone*"), `frus1940v05`
   (Inter-American Neutrality Committee).
5. **Order M367 rather than travelling**, for the 763.72 / .72111 / .72112 / .72119 files. Then
   plan a reading-room visit only for the `6NN.119` neutral-country commerce files and the 1939
   `740.00111A` material, neither of which is digitised in the bundled index.
6. **If you want the pre-1906 unprinted record**, the target is RG 59 Diplomatic Despatches /
   Instructions / Notes from & to Foreign Missions at file-unit grain — e.g. NAID 177380725 for
   Great Britain, 1791–1906. The bundled indexes give you the file unit and no more; creator,
   extent and facility are not available offline for any of it.

---

## 8. Things that could be wrong

* **Everything in §3 is stemmed and footnote-inclusive.** The literal shares in §3.1 constrain the
  stemming problem; the §5 footnote shares constrain the apparatus problem; neither eliminates it.
* **The 18-volume scope is a rule, not a judgement.** ≥15 hits and ≥5% is arbitrary at the margin,
  and it excludes `frus1898`, `frus1940v01` and `frus1919Parisv02`, all of which a historian would
  probably include. Every archival number in §4 is conditional on that particular list.
* **The 1860s–1870s archival picture is not measurable from this database.** 167 source-note rows
  for eight volumes and 3,423 documents.
* **I misread `collection-usage-index.json` on the first attempt** (treating `n` as volume indices
  rather than counts) and reported Nixon tapes and CIA files as top collections for a scope ending
  in 1939. The wrong output is `collection_usage_ranked.txt`; the corrected one is
  `collection_usage_ranked2.txt`, and it now agrees with the SQL in §4.1 to the document. The
  decisive query, run on both sides, is the aggregation
  `sum(c for vi,c in zip(row["v"],row["n"]) if vi in scope_indices)` versus the earlier
  `zip(row["n"],row["v"])`: 8,960 documents in four provenance categories (correct) against 214,000
  in ten (wrong). I also mis-composed the decimal glosses on the first attempt (§4.1).
* **I ran no HARVEST surface.** No offline NARA record-group harvest path was given in this brief,
  so every archival claim above is from the bundled JSON and the database, and none of it is
  labelled `[HARVEST]`.
* **Person and citation-graph axes are untouched.** `person_rollup` is name-clustered and
  under-merged, `person_mentions` is unevenly tagged, and I did not use either; nor did I use
  `cross_references`. If you want the Lansing/Page/Spring Rice correspondence network, that is a
  separate pass and its counts would be lower bounds.
