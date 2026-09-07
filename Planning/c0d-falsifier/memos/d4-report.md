# Scoping memo — US assertions of maritime neutrality in wartime

**Corpus:** the FRUS Explorer SQLite index at `/Users/jbotts/frus-analysis/frus-copy.db`, the TEI at
`/Users/jbotts/Development/frus/volumes/*.xml`, and the bundled JSON in
`/Applications/FRUS Explorer.app/Contents/Resources/`.
**Every count below is conditional on your library.** Coverage query, run first:

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

You have the whole published series — 552 volumes, 316,839 documents. So nothing below is thin
*because of the download*; where a result is thin it is thin in FRUS. Working scope throughout
(unless stated) excludes apparatus and the duplicate second editions:

```sql
is_front_matter=0 AND is_editorial_note=0
AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
-- 306,619 documents in 550 volumes
```
`frus1977-80v09Ed2` is kept: it has no first edition to duplicate.

**Controls, run in the same pass as the first scan** (SQL surface):

```sql
SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f
 JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
 WHERE frus_documents MATCH '"Department of State"' AND <scope>;   -- 93,418 docs / 549 volumes
SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ'; -- 0
```
Both controls were re-run independently on the TEI surface in `tei_split.py` (1,363 and 0
occurrences over six volumes). The scans work.

---

## 1. The headline

This corpus holds the subject in unusual density, and it holds it **as apparatus, not as
vocabulary**. FRUS's own editors carved five volumes into parts literally titled *Neutral Rights*
and *Neutral Duties* — and then, at the moment the United States entered the war, renamed the part
*Belligerent Rights and Practices*. That editorial hinge is the single most useful thing in the
corpus for your question, and no keyword search finds it.

| Editors' formula (matched against volume section trees) | Documents | Volumes |
|---|---|---|
| `Part II/III: Neutral Rights` \| `Neutral Duties` | **3,623** | 6 |
| `Part II: Belligerent Rights and Practices` | **1,267** | 2 |
| `Control of commerce by belligerent governments` | 167 | 1 (frus1939v01) |
| `Naval measures taken by China and Japan …` | 200 | 3 (1937v04, 1938v04, 1939v03) |
| `Neutrality policy of the United States` | 139 | 3 (1939v01, 1940v02, 1941v01) |
| `The Inter-American Neutrality Committee` | 128 | 3 |
| `… Security Zone established by the Declaration of Panama` | 108 | 2 |
| `maintenance of neutral rights` | 54 | 1 (frus1940v02) |
| `neutrality patrol` (territorial waters) | 8 | 1 (frus1939v05) |

Method: `parts.py` flattened all 552 volumes' `volume_structures.structure_json` into 15,808
(volume, heading-path, documentIds) rows → `all_sections.json`; `formulas.tsv` counts distinct
non-apparatus documents under each regex. These are section-title matches, not text matches, so
they are not subject to the stemmer at all.

For comparison, the whole *vocabulary* route — a 22-phrase OR over the rights-and-prize language
(`core_query.txt`) — returns **3,479 documents in 296 volumes**. The apparatus route returns more
documents from six volumes than the vocabulary route returns from the entire corpus. Documents
filed under *Neutral Rights* mostly do not contain the phrase "neutral rights."

---

## 2. Your own phrase is not the corpus's phrase — false-friend test

The question supplied "maritime neutrality." As a literal phrase it is **21 documents of 306,619**.
Do not search for it.

| term | on-topic (5 WWI Supplements, 6,065 docs) | control (5 Cold War vols, 2,029 docs) | corpus (306,619) |
|---|---|---|---|
| stem `neutral*` | 1,677 = 0.2765 | 159 = 0.0784 | 19,300 = 0.0629 |
| stem `maritim*` | 142 = 0.0234 | 10 = 0.0049 | 4,115 = 0.0134 |
| phrase `"maritime neutrality"` | 1 = 0.0002 | 0 | 21 = 0.0001 |
| phrase `"neutral rights"` | 61 = 0.0101 | 0 | 222 = 0.0007 |
| phrase `"contraband of war"` | 120 = 0.0198 | 0 | 527 = 0.0017 |
| CONTROL `"Department of State"` | 803 = 0.1324 | 1,263 = 0.6225 | 93,418 = 0.3047 |

Reading: `neutral*` is 4.4× enriched on-topic and is a usable ranking signal, but 19,300 corpus
documents carry it and most are Cold War non-alignment, neutralisation of Laos, and neutral-nation
mediation — it selects volumes, not documents. **`maritim*` is only 1.7× enriched and is close to
measuring the corpus rather than the question; I stopped using it.** Note the control phrase is
*lower* in the WWI Supplements (0.13) than corpus-wide (0.30), because those volumes are printed
telegrams whose headers name ambassadors, not the Department — a reminder that "Department of
State" is a liveness control here, not a baseline for topicality.

Written in `falsefriend.tsv`. Predicate for every row:
```sql
SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id
 AND d.document_id=f.document_id WHERE frus_documents MATCH ? AND <scope> [AND d.volume_id IN (…)]
```

---

## 3. Literal shares for every phrase family I argue from

The index stores porter stems, so a phrase MATCH also returns different words with the same stem.
Each family below was verified by regex over `header || dateline || source_note || body_text`,
whitespace-collapsed, **Python `re`, case-INSENSITIVE (`re.I`) for the whole family** — not SQL
LIKE. Census where the family is under 300 hits; otherwise an evenly spaced sample of 40 from the
`(volume_id, document_id)`-sorted hit list. STRICT = single spaces. TOLERANT = inflections allowed,
separators `[ \-,().]+`. Script `litshare.py`, output `litshare_core.json` / `litshare_corrected.tsv`.

| family (as I will publish it) | M hits | checked | TOLERANT | STRICT |
|---|---|---|---|---|
| `declaration of london` | 199 | census 199 | **199/199 = 1.000** | 199/199 = 1.000 |
| `contraband of war` | 527 | sample 40 | **40/40 = 1.000** | 40/40 = 1.000 |
| `freedom of the seas` | 241 | census 241 | **241/241 = 1.000** | 221/241 = 0.917 |
| `belligerent rights` | 489 | sample 40 | **40/40 = 1.000** | 34/40 = 0.850 |
| `prize court` | 714 | sample 40 | **40/40 = 1.000** | 38/40 = 0.950 |
| `neutral vessels` | 458 | sample 40 | **40/40 = 1.000** | 33/40 = 0.825 |
| `neutral flag` | 187 | census 187 | **187/187 = 1.000** | 145/187 = 0.775 |
| `right of search` | 147 | census 147 | **146/147 = 0.993** | 143/147 = 0.973 |
| `neutral rights` | 222 | census 222 | **218/222 = 0.982** | 210/222 = 0.946 |
| `rights of neutrals` | 216 | census 216 | **199/216 = 0.921** | 143/216 = 0.662 |
| `armed neutrality` | 46 | census 46 | **42/46 = 0.913** | 41/46 = 0.891 |
| `continuous voyage` | 53 | census 53 | **48/53 = 0.906** | 44/53 = 0.830 |

**Three families failed under their obvious name and pass under their true one.** I read the misses
before condemning them (`gloss`-style probe printed the actual matched word pairs):

| published as | first name tried | TOLERANT then | what the misses actually were | TOLERANT now |
|---|---|---|---|---|
| **duties of neutrals / duties of neutrality** | `duties of neutrals` | 98/178 = 0.551 | `duties of neutrality` ×7, `duty of neutrality` ×1 | **178/178 = 1.000** (STRICT 56/178 = 0.315) |
| **neutral ships / neutral shipping** | `neutral ships` | 32/40 = 0.800 | `neutral shipping` ×13, `neutral shipowners` ×2 | **40/40 = 1.000** (STRICT 26/40 = 0.650) |
| **visit(ation) and search** | `visit and search` | 142/166 = 0.855 | `visitation and search` ×6 | **166/166 = 1.000** (STRICT 140/166 = 0.843) |

None of these is a false friend; the stemmer was folding a synonym the editors actually use. But
the STRICT column is the point: publish `duties of neutrals` as a phrase and you are describing
31.5% of what you counted. Two of the three sit at or below the 0.80 tolerant floor under their
naive name, and would have been unusable as published.

A 1.000 share tests the stemmer, not the referent. `prize court` is 1.000 literal and still needs a
referent check — 714 documents is far more than the neutrality material, because British and German
prize courts appear throughout the claims correspondence of the 1920s. Treat it as a lead, not a count.

---

## 4. Where it sits in time

Periodised on `document_dates.date_iso` (= `frus:doc-dateTime-min`), **not** volume series year.
Rates are per 1,000 dated non-apparatus documents of that decade, since the 1940s holds 74,043 and
the 1870s 5,798.

| decade | core-family docs | dated docs | per 1,000 |
|---|---|---|---|
| 1860s | 627 | 11,250 | 55.7 |
| 1870s | 205 | 5,798 | 35.4 |
| 1880s | 85 | 6,472 | 13.1 |
| 1890s | 115 | 9,712 | 11.8 |
| 1900s | 180 | 9,924 | 18.1 |
| **1910s** | **1,379** | 30,359 | **45.4** |
| 1920s | 110 | 19,733 | 5.6 |
| 1930s | 251 | 39,196 | 6.4 |
| 1940s | 280 | 74,043 | 3.8 |
| 1950s | 122 | 42,296 | 2.9 |
| 1960s | 64 | 27,650 | 2.3 |
| 1970s | 40 | 22,259 | 1.8 |
| 1980s | 5 | 5,949 | 0.8 |

**Top-volume share of the numerator, as required:** the 1910s numerator is 1,379, of which
`frus1915Supp` alone supplies 336 (24.4%) and the four 1914–1918 Supplements together 968 (70.2%) —
this decade is *five books*, not a diffuse tendency. The 1860s numerator is 627, of which
`frus1863p1` supplies 99 (15.8%). The 1870s spike is narrower still: 1871–72 is the Geneva
Arbitration, and `frus1872p2v2` alone supplies 46 of the decade's 205 (22.4%).

By year (`wars_by_year.tsv`), the peaks are 1861 (175.7 per 1,000), 1862–65, 1871–72, 1898, 1904
(70.6), 1914 (84.9) / 1915 (102.6) / 1916 (81.0), and 1939 (22.7) / 1940 (14.2). That is: Civil War,
Alabama arbitration, Spanish-American War, Russo-Japanese War, First World War, Second World War.

---

## 5. The five episodes, and which one is not what it looks like

**(a) 1861–65 — the United States as *belligerent*.** 627 documents in the 1860s, top volumes
`frus1863p1` (99), `frus1862` (82), `frus1864p2` (77), `frus1861` (61), and
`frus1865p1/p2/p3` (35/42/36). This is the **inverse** of your question: the US is running the
blockade of the Confederacy and demanding that Britain and France *behave* as neutrals. If you want
American assertions of its own neutral rights, this decade is the counter-case, and it is essential
precisely for that — Seward's positions here are quoted back at the US in 1915.

**(b) 1871–72 — the Geneva Arbitration, and the corpus's most systematic doctrine.** The five
volumes `frus1872p2v1` (512 docs), `v2` (272), `v5` (164), `v4` (50), `v3` (40) — 1,038 non-apparatus
documents — are the printed *Case* and *Counter Case* of the Alabama claims. Four of those
"documents" are chapter-length treatises whose headers are the argument itself:

- `frus1872p2v1/d3` — "Part III. The duties which Great Britain, as a Neutral, should have observed toward the United States"
- `frus1872p2v1/d4` — "Part IV: Wherein Great Britain failed to perform its duties as a neutral."
- `frus1872p2v1/d5` — "Part V: Wherein Great Britain failed to perform its duties as a neutral. The Insurgent cruisers."
- `frus1872p2v2/d117` — "Part II. Argument of the United States on neutral duties." (`length(body_text)` = **103,210 characters**)

This is the fullest US statement of neutral duty in the corpus and it is **invisible to the section
route**: I searched the volume section trees for `duties as a neutral` and got **zero rows**. That
emptiness is real but not a finding about the corpus — the Geneva volumes *do* have section trees
(`frus1872p2v1`'s `structure_json` is 6,293 bytes); the doctrine simply lives in document headers,
not headings. The header route returns exactly the four above:
```sql
SELECT COUNT(*) FROM document_cache WHERE (header LIKE '%as a neutral%' OR header LIKE '%neutral duties%')
 AND is_front_matter=0 AND is_editorial_note=0;   -- 4
```
(SQL `LIKE`, case-insensitive for ASCII — stated because §3 used Python `re` instead.)

**(c) 1904 — Russo-Japanese War.** 70 core-family documents in a 991-document year (70.6 per 1,000),
all in `frus1904`; correspondence with St Petersburg (McCormick), Tokyo (Griscom) and London
(Choate) on contraband, coal, and the seizure of neutral merchantmen. The highest single-year rate
outside the Civil War and the World Wars, in one ordinary annual volume. Under-used, I suspect.

**(d) 1914–18 — the centre of gravity.** Five volumes, and the editors did the classification for
you. `frus1915Supp` 336 core hits / 1,154 documents under *Neutral rights* and *Neutral duties*;
`frus1914Supp` 257 / 790; `frus1916Supp` 212 / 844; `frus1917Supp01v01` 82 / 731. The sub-headings
under *Part II: Neutral rights* are a ready-made research vocabulary — I have 245 lines of them in
`neutral_rights_sections.txt`, e.g. *"The German declaration of a naval war zone (February 4, 1915):
Position taken by the United States"* (40 docs), *"Statements of July 14 and 15, 1915, to Great
Britain, denying the legality of actions taken under orders in council"* (13), *"Reservation of
American rights in connection with the abolition of the distinction between absolute and conditional
[contraband]"* (16), *"The seizure of the 'Kankakee' — The black list of neutral ships"* (7),
*"Departures by belligerent governments … from the established rules for exercise of the right [of
visit and search]"* (13). **And the hinge:** in `frus1917Supp02v02` and `frus1918Supp01v02` the same
structural slot is titled *Part II: Belligerent Rights and Practices* (1,267 documents), including
*"The development of an American policy of trade control — Authorization of an embargo in the
'Espionage Act', June [1917]"*. The corpus's own architecture records the United States changing sides
of the argument.

**(e) 1937–41 — the same question under different formulas.** Do not search `neutral rights` here;
the editors say *Neutrality policy of the United States* (139 docs, continued volume to volume with
explicit "Continued from Foreign Relations, 1940, vol. ii, pp. 1–67" cross-references), *Control of
commerce by belligerent governments* (167, incl. *"Representations to the German Government against
detention of neutral ships"*), *Violations by the belligerents of the Security Zone established by
the Declaration of Panama* (108 — the 300-mile neutrality zone, a distinctively American maritime
assertion with no earlier analogue), *The Inter-American Neutrality Committee* (128), and for the
undeclared Sino-Japanese war *Naval measures taken by China and Japan along the coasts and in the
rivers of China* (200). Full list in `wwii_sections.txt`.

**After 1945 the question essentially stops.** The core family falls from 45.4 per 1,000 (1910s) to
0.8 (1980s). I checked whether the 1957 and 1967 residue is on-topic: a narrowed query
(`"neutral rights" OR "rights of neutrals" OR "neutral vessels" OR "contraband of war" OR "freedom
of the seas"`) restricted to 1957 and 1967 **returned no rows** — the same query returns 26 rows for
1904–05, so it is not broken. The Cold War tail of the broad family is `prize court` and `neutral
port` in claims and Law-of-the-Sea contexts, not neutrality assertion.

---

## 6. Document text vs. editors' footnotes — measured, not disclaimed

`body_text` in this index blends document and editorial language and cannot be split by column. I
split it on the **TEI** instead. **Counting surface: tag-stripped and whitespace-collapsed, inside
`<div type="document">` only**; APPARATUS = text inside `<note>…</note>`, BODY = everything else.
Six volumes (`frus1915Supp`, `frus1914Supp`, `frus1916Supp`, `frus1872p2v2`, `frus1863p1`,
`frus1939v01`; 6,313 document divs). Script `tei_split.py`, Python `re`, case-insensitive.

| family | body occurrences | footnote occurrences | footnote share |
|---|---|---|---|
| declaration of london | 343 | 4 | 0.012 (of 347) |
| neutral ships/shipping | 248 | 0 | 0.000 (of 248) |
| contraband of war | 239 | 10 | 0.040 (of 249) |
| visit(ation) and search | 80 | 1 | 0.012 (of 81) |
| neutral rights | 75 | 7 | 0.085 (of 82) |
| rights of neutrals | 73 | 1 | 0.014 (of 74) |
| freedom of the seas | 36 | 0 | 0.000 (of 36) |
| CONTROL Department of State | 1,294 | 69 | 0.051 (of 1,363) |
| CONTROL ZZZ_IMPOSSIBLE_ZZZ | 0 | 0 | — |

Good news: apparatus contamination for this vocabulary is 0–8.5%, at or below the control's 5.1%.
Density claims on these families are safe. This measurement covers six volumes, not the corpus.

---

## 7. Archival scope — two channels, labelled, never summed

### Channel A — CAME-FROM (`document_sources`, one row per document)
Scope: the seven volumes carrying the neutrality apparatus (`frus1914Supp`, `frus1915Supp`,
`frus1916Supp`, `frus1917Supp01v01`, `frus1917Supp02v02`, `frus1918Supp01v02`, `frus1940v02`).

```sql
SELECT ds.citation_era, COUNT(*) FROM document_sources ds
 JOIN document_cache d ON d.volume_id=ds.volume_id AND d.document_id=ds.document_id
 WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND ds.volume_id IN (…7…)
 GROUP BY ds.citation_era;
```
**7,139 rows: decimal 7,077 (99.1%), named_series 31, unrecognized 19, published 11, structured 1.**
This material is almost purely the State Department Central Decimal File. Top classes:

| class | rows | what the *bundled* schedule can actually say |
|---|---|---|
| 763.72 | 1,230 | class 7 = Political Relations of States; country A `63` = Austria; country B `72` = **not named in the shipped table** |
| 763.72112 | 867 | same, plus subject suffix `.112` — **no class-7 subject schedule ships** |
| 763.72111 | 378 | same, suffix `.111` — no schedule |
| 300.115 | 258 | class 3 = Protection of Interests; country `00` = World — no class-3 subject schedule |
| 763.72119 | 258 | as above |
| 656.119 | 207 | class 6 = Commerce. Customs Administration; country `56` = Netherlands |
| 340.1115A | 171 | class 3, country `40` = Europe |
| 740.0011 | 144 | class 7, country A `40` = Europe, country B `00` = World |
| 841.731 | 107 | class 8 = Internal Affairs; country `41` = Great Britain; subject `.731` = **Laws and regulations** |
| 855.48 | 104 | class 8; country `55` = Belgium; subject `.48` = **Calamities. Disasters** |

**Honest limit, and I got this wrong on the first attempt.** My first accessor looped the subject
tables over every class and glossed `300.115` as "Sex relations" and `740.0011` as "Family" —
plausible, wrong readings of exactly the kind `decimal-class-labels.json` warns about. Corrected in
`gloss2.py`: the shipped 1910–1949 schedule has subject tables for **classes 6 and 8 only**, and
class 7 is parsed as `7 + ccA + '.' + ccB + suffix`. All these documents fall inside the schedule's
1910–1949 span so composing is permitted — but the file **cannot** tell you that 763.72112 is the
blockade-and-contraband file. It does not name country 72, and it ships no class-7 subject
schedule. You will need the printed NARA classification manual for the suffix.

Cross-check on an independent surface: `collection-usage-index.json` projected over the same seven
volumes gives **7,077 `centralDecimalFile`**, 31 `namedFileSeries` (War Trade Board File), 11
`previouslyPublished`, 1 `presidentialLibrary` (Roosevelt Library), 19 `unrecognized` — matching the
SQL exactly, and 763.72 / 763.72112 / 763.72111 rank identically. **I had this projection wrong
first too**: the rows are `{"k": key index, "n": [counts], "v": [volume indices]}` and I read `n` as
the volume index, which put the Johnson Library and Reagan Library inside 1915. Decisive check on
both sides, in `cui2.py` vs `cui3.py`:

| reading | row for classKey `763.72112` → volumes |
|---|---|
| `n` as volume index (wrong) | frus1894app1, frus1863p1, frus1931v01, frus1952-54v11p2, … |
| `v` as volume index (right) | frus1914-20v01, frus1914-20v02, **frus1914Supp, frus1915Supp** (n=322), frus1916Supp, … |

### Channel B — POINTED-AT (`external_citations`, many rows per document)
Same seven volumes: **131 citation rows across 120 documents** — against 7,139 came-from rows.
Repository is `Department of State` in 129 of 131; the other two are the Roosevelt Library. Top
classes cited-but-not-printed: 763.72112 (27), 763.72 (20), 340.1115A (9), 658.119 (8).
**Before ranking anything on this channel:** it has no row before 1910-12-06, it stores the citation
fragment rather than the sentence, and it holds only lot, library and decimal anchors. For the WWI
Supplements — compiled in the late 1920s with sparse annotation — it is close to empty. Do not read
131 as evidence the editors withheld little; read it as evidence they footnoted little.
**These two channels must never be summed.**

### The pre-1910 archival negative, and the series that answers it
For the Civil War and Geneva volumes (`frus1861`, `frus1862`, `frus1863p1`, `frus1864p2`,
`frus1865p2`, `frus1872p2v1–v5`) the came-from channel yields **229 rows, every one
`citation_era = 'unrecognized'`**, and `collection-usage-index.json` yields **0 attributions**. FRUS
printed these without archival citation. That is a property of nineteenth-century FRUS, not a gap in
your library, and it is not a research negative:

`central-files-index.json` → `countrySeries` names twelve pre-1910 chronological runs, offline,
with per-roll NARA NAIDs and catalog URLs — *Diplomatic Despatches* (2,160 rolls, to 1907),
*Diplomatic Instructions* (177, to 1906), *Notes from / to Foreign Missions* (522 / 104),
*Consular Despatches* (3,357), *Domestic Letters* (272), *Despatches from Special Agents* (22), and
five more. The Civil War neutrality correspondence with London sits in **"Despatches from U.S.
Ministers to Great Britain, 1791–1906"**; six roll rows in that series overlap 1861–65, e.g.
`catalog.archives.gov/id/188538150` (1861-11-01 → 1862-02-26) and
`catalog.archives.gov/id/188541557` (1864-11-25 → 1865-03-23). **Caveat:** these roll dates are OCR'd
and visibly unreliable — the first row in the series is dated `1790-04-07 → 1906-12-18` (a container
row) and another series' first roll reads `1318-11-01`. Use them to find the roll, not to date it.
`series-facts-index.json` carries no row for these (its `byNaId` is keyed on series NAIDs; the
`countrySeries` rolls carry only `naId`/`fileUnitNaId`, and no `legend` key exists in that file at
all). The offline stack barely reaches before 1940, so treat this as a pointer, not a finding list.

---

## 8. A third axis, with a warning

The bundled subject taxonomy has a `Neutrality` tag (`document_subject_refs.subject = 374`,
Warfare ▸ Neutrality). Corpus-wide it is **7,674 documents across 511 of 550 volumes** — far too
broad to select documents with, exactly as the string-matching caveat predicts. But its *volume
ranking* is excellent and independent of everything above: frus1914Supp 263, frus1939v01 160,
**frus1904 128**, frus1915Supp 124, frus1940v01 116, frus1940v05 111, **frus1872p2v1 110**,
frus1917Supp01v01 101, frus1898 93, frus1911 92. `Warship navigation rights` (subject 48,
International Law ▸ Law of the Sea, corpus df 1,631) is tighter: frus1915Supp 186, frus1914Supp 166,
frus1916Supp 94. Overlap between subject 374 and the core phrase family is only **403 documents** —
the two axes are nearly disjoint, so use the tag to rank volumes and the phrases to find documents,
never to cross-validate each other. (Subject names live in `document-subject-index.json` → `vocab`,
a 491-row list; the DB stores integers only.)

---

## 9. What I would actually search for

1. **Start with the section trees, not the text.** `Part II: Neutral Rights`, `Part III: Neutral
   Duties`, `Part II: Belligerent Rights and Practices`, then `Neutrality policy of the United
   States`, `Control of commerce by belligerent governments`, `Security Zone … Declaration of
   Panama`, `Inter-American Neutrality Committee`. Their **union is 5,640 distinct non-apparatus
   documents in 16 volumes** (the nine rows of the §1 table sum to 5,694; the sections nest, so the
   union is the number to quote) — editor-classified, and the single best starting set.
2. **Phrase families, in the corrected forms:** `contraband of war`; `declaration of london`;
   `freedom of the seas`; `neutral ships / neutral shipping`; `visit(ation) and search`;
   `duties of neutrals / duties of neutrality`; `neutral rights`; `rights of neutrals`;
   `continuous voyage`; `absolute contraband` / `conditional contraband` (107 / 150 documents, 15
   and 12 volumes — small and precise); `armed neutrality`.
3. **The corpus's own event vocabulary,** which the headings hand you and which no modern phrasing
   reaches: `order in council`, `war zone`, `armed merchant ships`, `black list`, `orders in council
   of October 20, 1915`, `Wilhelmina`, `Falaba`, `Gulflight`, `Arabic`, `Ancona`, `Sussex`,
   `Petrolite`, `Kankakee`, `Odenwald`.
4. **Read the Geneva Case as doctrine**, four headers, `frus1872p2v1/d3,d4,d5` and
   `frus1872p2v2/d117`.
5. **Do not** search `maritime neutrality`, `maritim*`, or `neutrality` as a bare subject tag.

## 10. Caveats

- All counts conditional on your library: 552 volumes / 316,839 documents (here, the full series).
- `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2` suppressed throughout; `frus1977-80v09Ed2` kept.
  I counted on **this index with apparatus excluded**, where the stated first/second-edition overlap
  is 701 documents — not the 718 of the vector artifacts.
- `citation_era` is a citation *form*, never a date; nothing above plots it.
- `cross_references.reference_type` defaults body references to `footnote`; I therefore made no
  body-vs-footnote claim from it — §6 uses the TEI instead.
- `person_rollup`/`person_mentions` unused; no surname was scanned.
- I never read `summary_text` or `note_text`.
- Thin results to treat with care: `armed neutrality` (46), `continuous voyage` (53), `paper
  blockade` (35), `carriage of contraband` (17), the 1810s/1850s decade rows (3 and 5 hits), and the
  entire pointed-at channel (131 rows).
- Two of my own passes were wrong and are corrected in place with both sides shown: the decimal
  gloss (§7) and the collection-usage array semantics (§7). Both produced *plausible* wrong answers.

## 11. Reading, and files on disk

**Retrieved whole: 6 documents** (`read.sql`; captured field length ≥ `length(body_text)` for each —
`frus1861/d255` 30,436 chars, `frus1872p2v2/d117` 103,210, `frus1915Supp/d132` 2,530,
`frus1915Supp/d140` 1,073, `frus1916Supp/d183` 4,088, `frus1939v01/d1089` 1,531; character counts,
not bytes). **Quoted from: 2** — the opening of `frus1915Supp/d132` (Page to the Secretary of State,
London, 8 February 1915, source note `File No. 811.0151/33`, on the neutral flag as a *ruse de
guerre*) and the header of `frus1916Supp/d183` (Gerard to the Secretary of State, Berlin, 30 December
1916, `File No. 763.72119/294`). Raw text in `read/`. Everything else quoted above is a section
heading or a document header returned in a result set in this session.

| file | holds |
|---|---|
| `phrase_counts.tsv` | the 40-phrase reconnaissance counts |
| `litshare_core.json`, `litshare_corrected.tsv` | §3 literal shares |
| `falsefriend.tsv` | §2 |
| `wars_by_year.tsv` | §4 by-year table |
| `all_sections.json`, `formulas.tsv`, `section_families.tsv` | §1 apparatus counts |
| `neutral_rights_sections.txt`, `wwii_sections.txt`, `headings_sample.txt` | the editors' vocabulary |
| `cui3.py` (and `cui2.py`, the wrong version) | §7 collection-usage projection |
| `gloss2.py` (and `gloss.py`, the wrong version) | §7 decimal gloss |
| `prewar_series.txt`, `prewar_rolls.txt` | §7 pre-1910 NARA series |
| `subjects.tsv` | §8 |
| `tei_split.py` | §6 TEI body/footnote split |
| `read/`, `read.sql` | §11 |
| `queries.log` | every command that touched a surface |
