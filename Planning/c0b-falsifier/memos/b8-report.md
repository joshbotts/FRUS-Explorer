# Scoping memo — US policy toward refugees and displaced persons in the FRUS corpus

**Run:** 2026-09-06 · scoping pass, not a finished study
**Surfaces used:** the SQLite index (`frus-copy.db`), the bundled JSON reference data
(`/Applications/FRUS Explorer.app/Contents/Resources/`), and the TEI XML corpus
(`/Users/jbotts/Development/frus/volumes/`) for the spelling-variant scan only.
**Every command I ran is in `queries.log`, in order.**

---

## 0. Coverage and controls

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library is **complete for this run**: all 552 volumes of the series are indexed. Nothing below
is thinned by a partial download. Non-apparatus denominator (front matter and editorial notes
excluded) = **307,359 documents**.

Controls, run in the same pass as the first census:

```sql
SELECT 'POSITIVE', COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f
 JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
 WHERE frus_documents MATCH '"Department of State"' AND d.is_front_matter=0 AND d.is_editorial_note=0
UNION ALL SELECT 'NEGATIVE', COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f
 WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ';
-- POSITIVE | 93643 | 551
-- NEGATIVE | 0 | 0
```

Second-edition suppression: `frus1951-54IranEd2` (3 hits) and `frus1969-76ve15p2Ed2` (10 hits) are
dropped wherever noted below; `frus1977-80v09Ed2` (35 hits) is **kept**, because it has no first
edition to duplicate. The suppression costs 13 documents — it does not move any figure here.

---

## 1. The short answer

The corpus holds a **large, continuous, and unusually well-signposted** body of material on this
question. Measured:

```sql
SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f
 JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
 WHERE frus_documents MATCH 'refugee OR "displaced persons"'
   AND d.is_front_matter=0 AND d.is_editorial_note=0
   AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
-- 7764 | 495
```

**7,764 of 307,359 non-apparatus documents**, spread across **495 of 552 volumes**, dated 1861 to
1981. It is not a thin or incidental presence. But the
material is *three different subjects wearing one word*, and they need to be searched differently:

| Era | What "refugee" means in the documents | Where it sits |
|---|---|---|
| 1861–1910 | **Asylum in a legation or consulate** during a Latin American or Caribbean revolution; a question of international law and of the minister's personal discretion | Country chapters (Haiti, Chile, Mexico, Nicaragua) |
| 1910–1939 | **Relief and resettlement abroad** — Greek/Armenian refugees after 1922, Russian émigrés, Spanish Civil War, then the Jewish refugee crisis from 1933 | Named editorial compilations |
| 1938–1952 | **An American programme**: Evian, the Intergovernmental Committee, the War Refugee Board, UNRRA, DPs, the IRO | The wartime and immediate-postwar *General* volumes |
| 1948–1981 | **A regional problem, chiefly Palestine** — then Hungary 1956, Cuba, Bengal 1971, Indochina 1975+ | Near East / Arab-Israeli volumes, then crisis volumes |

The single most important structural fact for your search design: **the editors stopped naming the
subject in their headings around 1955.** Before that, FRUS compilations carry titles like
"Organization of the Intergovernmental Committee on Political Refugees from Germany". After that,
the volumes are organised by country and crisis, and refugee policy is scattered inside them. A
heading-based search is excellent for 1873–1952 and nearly useless afterwards; a term-based search
is the reverse.

---

## 2. What to search for — and what not to

I ran a 23-term census (FTS `MATCH`, non-apparatus only), then a literal-share check on every term
I intend to report. This matters: the index is **porter-stemmed**, so a `MATCH` returns a different
word with the same stem. Sampled over `header + dateline + source_note + body_text`:

| Query | MATCH hits | literal share | verdict |
|---|---|---|---|
| `refugee` | 7,464 docs / 496 vols | 7,464 / 7,464 = **1.000** | **use** |
| `"displaced persons"` | 586 / 103 | tolerant 586/586 = 1.000; strict 583/586 = 0.995 | **use** |
| `asylum` | 1,619 / 315 | 1,619 / 1,619 = **1.000** | **use** |
| `stateless` | 142 / 44 | 142 / 142 = 1.000 | use |
| `"Intergovernmental Committee"` | 331 / 42 | 331/331 = 1.000 | use |
| `"War Refugee Board"` | 115 / 7 | 115/115 = 1.000 | use |
| `"International Refugee Organization"` | 69 / 33 | 69/69 = 1.000 | use |
| `"High Commissioner for Refugees"` | 118 / 48 | 117/118 = 0.992 | use |
| `"Palestine refugees"` | 327 / 45 | tolerant 320/327 = 0.979; **strict 226/327 = 0.691** | use tolerant form |
| `exiles` | 3,048 / 389 | 3,017/3,048 = 0.990 | use (catches exile/exiled) |
| `resettlement` | 1,235 / 228 | 1,047/1,235 = 0.848 | usable |
| `repatriation` | 3,562 / 352 | 2,889/3,562 = 0.811 | marginal — just above the floor |
| `"boat people"` | 33 / 13 | 29/33 = 0.879 | usable, tiny |
| **`emigration`** | 3,291 / 389 | **1,972/3,291 = 0.599** | **REFUTED — do not count** |
| **`sufferers`** | 13,363 corpus-wide | **520/13,363 = 0.039** | **REFUTED — the stem is `suffer`** |

The `sufferers` result is the cautionary one. I reached for it as a plausible 19th-century synonym
for refugees; the stem is `suffer`, so the query was silently measuring *suffering* across the whole
corpus. It would have produced a very confident and entirely false claim about Victorian
humanitarian vocabulary. `emigration` fails the same way (stem `emigr` = emigrant / emigrate /
émigré) at 0.599, below the 0.80 floor.

**A 1.000 literal share does not test the referent.** `refugee` matches the string perfectly, but
in 1868 that string means a Haitian insurrectionist sitting in the US consulate, and in 1979 it
means a Vietnamese family on a boat. The word is stable; the subject is not.

### False-friend test on the question's own term

Corpus-wide, `refugee` appears in 7,464 of 307,359 non-apparatus documents = **2.4%**. In the
volumes it concentrates in, it runs 7.6%–39%:

```sql
-- per-volume share of 'refugee' beside the share of the control phrase 'Department of State'
frus1949v06       339/1137 = 29.8%   control 14.6%
frus1943v01       304/967  = 31.4%   control 15.0%
frus1938v01       177/959  = 18.5%   control  6.3%
frus1977-80v22    130/335  = 38.8%   control 44.5%
frus1952-54v09p1  131/857  = 15.3%   control 60.8%
frus1923v02        79/1035 =  7.6%   control  7.7%
```

The term discriminates at **3×–16× baseline** and its ranking is uncorrelated with the control's
(`frus1952-54v09p1` is 61% "Department of State" and only 15% "refugee"). So `refugee` is measuring
the question, not the corpus. It passes.

### [TEI] Spelling-variant split

The index cannot answer this — porter stemming folds singular and plural into one row, which is why
`refugee` and `refugees` both returned exactly 7,464. Counted instead over the TEI, **tag-stripped
and whitespace-collapsed**, over the 552 manifest volumes with the two duplicate second editions
suppressed. **Apparatus is included in this surface** (front matter, abbreviation lists, footnotes
and the back-of-book index are all inside the file), so these occurrence counts run above what the
database's non-apparatus document counts would suggest.

Counting surface: **tag-stripped, whitespace-collapsed** — 1,432,167,737 characters over the
**550** files that remain after taking the 552 manifest volumes and suppressing the two duplicate
second editions. Controls in the same pass: `Department of State` = 177,177 occurrences in 549 of
550 volumes; `ZZZ_IMPOSSIBLE_ZZZ` = 0 in 0. These are **occurrence** counts, not document counts,
and they include the apparatus.

| variant | occurrences | volumes |
|---|---|---|
| `refugees` (plural, any case) | **19,955** | 483 |
| `refugee` (singular, any case) | **7,759** | 402 |
| — lower-case `refugee(s)` | 23,141 | 492 |
| — capitalised `Refugee(s)` | 4,541 | 298 |
| `displaced persons` | **1,464** | 111 |
| `displaced person` (singular) | 33 | 26 |
| `DP` / `DPs` / `DP's` (no periods) | 715 | 69 |
| — of those, in volumes overlapping 1943–1955 | **445** | 49 |
| `D.P.` / `D. P.` (with periods, loose form) | 947 | 146 |
| `stateless` | 273 | 43 |
| `expellee(s)` | 124 | 42 |
| `réfugié` (accented) | 17 | 3 |

Three things this shows that the index structurally cannot:

1. **Plural outnumbers singular 2.6 : 1** (19,955 to 7,759). Porter stemming folds them, which is
   why `refugee` and `refugees` both returned exactly 7,464 documents in §2. The corpus talks about
   refugees as a population, not as a person.
2. **The acronym is real and the index cannot reach it.** `DP`/`DPs` is a separate token from
   `displaced persons`; a phrase search for the spelled form misses every one of the 445 DP-era
   occurrences. But it is **also a false friend, and I checked**: of the 715 tight-regex hits,
   the two largest contributors are not refugees at all — `frus1958-60v18` (98) uses *DP* for the
   **Democratic Party (Republic of Korea)**, and `frus1969-76v34` (106) uses it for **David
   Packard's initials** in meeting transcripts. The loose `D.P.` form is worse: in the
   nineteenth-century volumes it is overwhelmingly personal initials (*D. P. Heap*, *D. P.
   Woodbury*) and Central American signature blocks. Only the era-restricted 445/49 is usable, and
   even that is a ceiling.
3. **The archival citation form surfaces in the raw text.** Reading DP contexts in `frus1946v05`
   turned up the literal citations `800.4016 DP/1–1046` and `840.48 Refugees/11–2245; 800.4016
   DP/12–2845` — independent confirmation of the two decimal subfiles identified in §5, from a
   different surface.

---

## 3. The editors' own vocabulary — the best scoping instrument here

I walked every volume's `volume_structures` tree and pulled headings matching refugee/displaced/
asylum/repatriation/migration vocabulary: **271 matching headings**, 113 of them from 1924 onward.
This is the single most useful artefact of the pass, because the editors' formula repeats and your
modern phrasing does not appear in the documents.

The recurring pre-1910 formula is **not** "refugees". It is:

- *"Asylum in legations"* (frus1898) · *"Shelter as distinguished from asylum"* (frus1895p1)
- *"Refusal of asylum to a Dominican"* (frus1899) · *"'Asylum' in legation at Port au Prince"* (frus1899)
- *"The rights of asylum and of temporary refuge"* (frus1912)
- *"Papers relating to expatriation, naturalization, and change of allegiance"* (frus1873p1v2, a whole compilation)
- *"Condition of Israelites in Russia, their emigration to the United States"* (frus1894)

From 1933 the formula changes and becomes explicit — these are the chapter titles to search on
directly:

- 1933–1936 · *"American participation in the establishment of the High Commission for Refugees (Jewish and other) coming from Germany"* — continued verbatim in frus1934v02, frus1935v02, frus1936v02
- 1935 · *"Inquiry by the Nansen International Office for Refugees concerning the possibility of settling refugees in the United States"* (frus1935v01)
- 1937–1938 · *"Anti-Semitism in Poland / in Rumania and consideration of Jewish emigration as a possible solution"*
- **1938 · *"Meeting at Evian, France, to form an intergovernmental committee for assistance of political refugees from Germany including Austria"*** (frus1938v01, 25 documents)
- **1938 · *"Organization of the Intergovernmental Committee on Political Refugees from Germany; efforts to aid resettlement…"*** (frus1938v01, **120 documents**)
- 1939–1941 · *"Cooperation with the Intergovernmental Committee on Refugees to assist persons forced to emigrate, primarily from Germany, for political or racial reasons"* (frus1939v02, 100 docs; frus1940v02, 41; frus1941v01, 10)
- **1943 · *"Bermuda Conference to consider the Refugee Problem, April 19–28, 1943"*** (frus1943v01, 115 documents)
- **1943 · *"Governmental assistance to persons forced to emigrate for political or racial reasons"*** (frus1943v01, **193 documents**; continued frus1944v01, **176**)
- 1943/1944 · *"Representations to neutral governments against the granting of asylum to persons guilty of war crimes"* (12 + 59 docs)
- 1945 · *"Concern of the United States over problems involving displaced and stateless persons and refugees"* (frus1945v02, 67 docs)
- **1946 · *"The United States and the question of international assistance to refugees and displaced persons; the genesis of the International Refugee Organization"*** (frus1946v01)
- 1946 · *"Concern of the United States over problems involving displaced persons and refugees; transfer of German minorities…"* (frus1946v05, 59 docs)
- 1947–1949 · *"…disposition of German refugees in Denmark and south Schleswig"* (frus1947v03, frus1948v03, frus1949v04)
- 1948 · *"Negotiations respecting evacuation of certain refugee groups from Shanghai through the International Refugee Organization"* (frus1948v08, 17 docs)
- 1950/1951 · *"Matters respecting refugees and stateless persons"* (frus1950v02 III; frus1951v02 IV)
- **1952–54 · *"United States Support of Refugees and Escapees from Eastern Europe; the President's Escapee Program; the Volunteer Freedom Corps; Other Exile Groups"*** (frus1952-54v08, 29 docs)
- 1952–54 · *"United States policy regarding immigration and migration programs"* (frus1952-54v01p2, 36 docs)
- **1961–63 · *"Refugees"*** (frus1961-63v25, 18 docs) — the last time the editors give the subject a chapter of its own
- 1969–76 · *"Economic Normalization and Soviet Jewish Emigration"* (frus1969-76v15) and *"Soviet Rejection of the Agreement on Jewish Emigration"* (frus1969-76v16)

**Search those exact strings.** They are the editors' own index to the subject and they will pull
compilations that a keyword search fragments.

---

## 4. Where it sits in time

Periodised on `document_dates.date_iso` (the editorial `frus:doc-dateTime-min`), **not** on the
volume's series year. Rates are per 1,000 dated non-apparatus documents *of that decade*, because
the 1940s holds 74,043 dated documents and the 1870s only 5,798.

| Decade | `refugee` docs | decade denominator | per 1,000 | largest single volume's share |
|---|---|---|---|---|
| 1860s | 101 | 11,250 | 8.98 | frus1868p2 — 27, **26.7%** |
| 1870s | 104 | 5,798 | **17.94** | frus1875v02 — 33, **31.7%** |
| 1880s | 41 | 6,472 | 6.33 | frus1885 — 8, 19.5% |
| 1890s | 141 | 9,712 | **14.52** | frus1891 — 49, **34.8%** |
| 1900s | 64 | 9,924 | 6.45 | frus1902 — 16, 25.0% |
| 1910s | 265 | 30,359 | 8.73 | frus1916 — 33, 12.5% |
| 1920s | 309 | 19,733 | 15.66 | frus1923v02 — 79, 25.6% |
| 1930s | 697 | 39,196 | 17.78 | frus1938v01 — 177, 25.4% |
| 1940s | 1,971 | 74,043 | 26.62 | frus1949v06 — 339, 17.2% |
| 1950s | 1,482 | 42,296 | 35.04 | frus1952-54v09p1 — 131, 8.8% |
| 1960s | 980 | 27,650 | 35.44 | frus1964-68v19 — 86, 8.8% |
| 1970s | 954 | 22,259 | 42.86 | frus1969-76v11 — 114, 11.9% |
| 1980s | 336 | 5,949 | **56.48** | frus1977-80v23 — 45, 13.4% |

**Read the last column before the middle one.** The 1870s rate of 17.9 per 1,000 — higher than the
1930s — is *one Haitian legation*: a third of that decade's hits are Bassett's despatches from Port
au Prince in `frus1875v02`. The 1890s spike is likewise one Chilean civil war (`frus1891`, 34.8%,
Egan to Blaine on the Balmacedist refugees in the US legation at Santiago). By contrast the postwar
decades are genuinely distributed — no volume holds more than 17% of its decade — so the 1940s–1980s
rise is a real broadening of the subject and not an artefact of one compilation.

The 1980s figure sits on a small and truncated denominator (5,949 dated documents, and the series
stops in 1981 in this snapshot). Treat it as directional.

`"displaced persons"` is by contrast a **term of art with a decade**: 447 of its 585 dated hits fall
in the 1940s, 73 in the 1950s, 14 in the 1960s. Top volumes: `frus1945v02` (89), `frus1945v03` (42),
`frus1946v05` (32), `frus1947v02` (28), `frus1944v01` (22), `frus1945Berlinv01` (21).

### The volumes to start in

33 volumes have ≥10% of their non-apparatus documents naming refugees, with ≥25 such documents:

```
frus1977-80v22  130/335 = 39%  Southeast Asia and the Pacific  [Indochinese refugees]
frus1969-76v11  116/305 = 38%  South Asia Crisis, 1971         [East Bengal]
frus1943v01     305/967 = 32%  1943 General I                  [Bermuda; IGCR]
frus1949v06     339/1137= 30%  1949 Near East, South Asia, Africa VI  [Palestine]
frus1977-80v08   69/281 = 25%  Arab-Israeli Dispute 1977–78
frus1961-63v17   61/293 = 21%  Near East 1961–62
frus1961-63v18   76/384 = 20%  Near East 1962–63
frus1958-60v13   76/390 = 19%  Arab-Israeli Dispute; UAR; North Africa
frus1938v01     177/959 = 18%  1938 General I                  [Evian]
frus1944v01     188/1030= 18%  1944 General I
frus1945v02     141/805 = 18%  1945 General: Political and Economic Matters II
… 22 more, full list in queries.log (core.py)
```

Note what this ranking says: **the densest refugee volumes in the whole series are the
Arab–Israeli/Near East run.** Counting the list above, **eleven of the top twenty** are Near East or
Arab-Israeli volumes (frus1949v06, frus1977-80v08, frus1961-63v17, frus1961-63v18, frus1958-60v13,
frus1955-57v14, frus1969-76v23, frus1964-68v19, frus1955-57v17, frus1952-54v09p1, frus1951v05). If you are
writing about American refugee policy as a general commitment, the corpus will keep pulling you
toward UNRWA.

---

## 5. Archival scope — where these documents came from, and where the footnotes point

**Two channels, never summed.** They answer different questions and have different date reach.

### Channel A — came-from (`document_sources`, one row per document)

Of 7,764 documents matching `refugee OR "displaced persons"` (Ed2 suppressed), **7,324 carry a
source row**. Citation form:

| form | n |
|---|---|
| decimal | 4,657 |
| structured | 1,715 |
| lot_file | 596 |
| cfpf (subject-numeric) | 177 |
| named_series | 111 |
| published | 43 |
| unrecognized | 36 |
| foreign | 2 |

Repository / record group:

| repository | RG | n |
|---|---|---|
| Department of State | RG-59 | 5,196 |
| National Archives | 59 | 398 |
| Carter Library | — | 343 |
| Nixon Presidential Materials | — | 280 |
| Johnson Library | — | 127 |
| Central Intelligence Agency | — | 117 |
| Kennedy Library | — | 114 |

**The finding that matters: there is a single named file.** Ranked by decimal class over the
refugee document set:

| class | n | date span | gloss (1910–1949 schedule only) |
|---|---|---|---|
| **840.48** | **770** | 1915-07-27 … 1949-08-23 | Internal Affairs of States / **Europe** / **Calamities. Disasters** |
| 501.BB | 302 | 1946–1949 | Congresses and Conferences (UN) |
| 740.00119 | 145 | 1943–1949 | Political Relations / Europe |
| 867N.01 | 123 | 1938–1949 | Internal Affairs / *(Palestine — 67N has no name in the shipped country table)* / Government |
| 852.48 | 77 | 1937–1943 | Internal Affairs / **Spain** / Calamities. Disasters |
| 868.48 | 63 | 1922–1943 | Internal Affairs / **Greece** / Calamities. Disasters |
| 868.51 | 95 | 1923–1947 | Internal Affairs / Greece / Financial conditions |

The `.48` suffix — "Calamities. Disasters", which in practice means charities, relief and refugee
work — **is the classificatory home of the subject**, and the State Department gave it a named
subfile. 757 documents in this corpus cite the literal string **`840.48 Refugees`**, dated
1938-03-23 to 1949-08-23. Others cite `811.111 Refugees` (7 docs, 1940–41 — the US visa file),
`868.51 Refugee Settlement Commission` and `868.51 Refugee Loan, 1924` (42 docs, 1923–1936).

Corpus-wide, `collection-usage-index.json` ranks **840.48 as the 22nd busiest of 10,446 decimal
class keys in the entire series — 894 documents across 28 volumes.** For a subject often described
as marginal to American diplomacy, its file is in the top quarter-percent of everything FRUS prints.

Glossing caveat, per the rules: the shipped `decimal-class-labels.json` carries **one schedule,
1910–1949** (`startYear` 1910, `endYear` 1949), and no `coverage.glossableYears` block at all in
this build. Every gloss above is on a class whose documents fall wholly inside 1910–1949; classes
whose documents fall outside it (`684A.86`, `751G.00`, `320.2-AA`, `357.AC`, `325.84`) are left
**unglossed**, because the classification was renumbered in 1950 and composing anyway returns a
plausible wrong reading. One correction to my own working: I initially glossed `740.0011` as
"…/Family" by falling back to the class-8 suffix table for a class-7 key. That is wrong and I have
removed it — class-7 subdivisions belong to their own whole numbers.

**The editors wrote you a finding aid, and it is in the corpus.** `frus1946v01/d752` — the single
document under the compilation *"The United States and the question of international assistance to
refugees and displaced persons; the genesis of the International Refugee Organization"* — is an
editorial note that names the archives directly. Retrieved whole (3,768 characters; see `captured.txt`), it states that unpublished US documentation on the IRO's creation "is found in
the Department of State's central indexed files under **File No. 501.BD Refugees**; and in the files
of the **Reference and Documents Section of the Bureau of International Organization Affairs**,"
which hold the delegation minutes for the **Special Committee on Refugees and Displaced Persons**
(London, April 8–June 1, 1946) and the **Committee on the Finances of the International Refugee
Organization** (London, July 6–20, 1946).

That class is real and I checked it: `501.BD` carries **34 documents in this corpus, 1946-02-17 to
1949-11-10, across 10 volumes** (37 raw-text mentions), sitting beside its much larger neighbours
`501.BB` (1,628 docs) and `501.BC` (1,282). So the IRO file exists, FRUS printed 34 documents out
of it, and the editors tell you where the rest is. Start there for 1946–1950.

**The 1963 break.** The refugee record changes filing system mid-corpus:
- to 1963: decimal — `324.8411` (UNHCR business; 14 documents, all in `frus1961-63v25`) and
  `320.2-AA` / `320.2-AC` (53 + 41 documents, 1950–1954, the IRO era)
- after 1963: subject-numeric `REF` — and here is the negative. **The entire corpus contains
  5 documents sourced from a `REF` file**: `REF 3 UNRWA` (4, 1963-09-26 … 1966-02-07) and
  `REF 3 UN` (1, 1963-12-11). The post-1963 refugee documents FRUS prints come out of `POL 27`
  (Arab-Israeli, Vietnam, Cyprus), `SOC 10/14`, and the presidential libraries instead.

Lot files. The top lots on the refugee set are **generic policy lots, not refugee lots** —
`63D351` (55 docs; RG 59, NAID 2839192, entry A1 1586E, *Records Relating to National Security
Council Policy Papers*), `59D518` (46; NAID 2212252, A1 1298, *Documents on Projects Alpha, Mask,
and Omega*), `62D430` (18; NAID 2839191, A1 1586C). Only three lots in the whole bundled
`central-files-index.json` have "refugee" in their NARA title, and all three are Near Eastern:

| lot | RG | NAID | entry | title |
|---|---|---|---|---|
| 70D229 / 70D66 | 59 | 631070 | A1 5270 | Records Relating to **Refugee Matters** and Jordan Waters |
| 70D44 | 59 | 28794083 | UD-WX 1498 | Records Relating to Aid to Israel, **Palestinian Refugees**, and the Jarring Mission |

`series-facts-index.json` on NAID 631070: **4 linear feet 5 linear inches, 1949–1968, access status
"Unrestricted"**, creator *Department of State. Bureau of Near Eastern and South Asian Affairs.
Office of the Country Director for Israel and Arab-Israel Affairs.* NAID 28794083: 1 linear foot,
1961–1969, creator *Bureau of Near Eastern and South Asian Affairs.* Those two lots supply only
**12 printed documents** between them in this corpus (70D229: 9, 1957–1963; 70D44: 1; 70D66: 0 by
that spelling) — i.e. FRUS printed a dozen pages out of five linear feet.

A fourth, from reading `frus1961-63v25/d323`: **RG 59, IO Files: Lot 67 D 378, "Refugees"** — 6
documents in this corpus, 1961-06-30 … 1963-02-27. Not in `central-files-index.json`.

**Digitisation:** `digitized-ranges-index.json` covers exactly three decimal classes — 131, 133 and
763.72 (with sub-classes). **840.48 is not digitised in this index.** Neither is 324.8411 or any
`REF` file. This is a reading-room subject; the roll-scan route will not save you a trip.

### Channel B — pointed-at (`external_citations`, many rows per document)

Before ranking anything on it: this table **has no row before 1910-12-06**, it stores the citation
fragment rather than the sentence, and it holds only lot, library and decimal anchors. It is a
post-1910 instrument and mostly a post-1945 one.

Of the 7,764-document refugee set, **1,149 documents carry at least one external citation, 1,911
rows total**:

| repository | collection | rows |
|---|---|---|
| Department of State | — | 1,385 |
| Nixon Presidential Materials | NSC Files | 151 |
| Carter Library | National Security Affairs | 113 |
| Johnson Library | National Security File | 66 |
| Carter Library | Presidential Materials | 42 |
| Kennedy Library | National Security Files | 31 |
| Ford Library | National Security Adviser | 20 |
| Eisenhower Library | Dulles Papers | 10 |

Channel A and Channel B **must not be added**. A is 7,324 documents' provenance; B is 1,911
footnote pointers from 1,149 documents. They overlap, they answer different questions, and the
second reaches nothing before 1910.

### A corpus-scoping negative, with the series that answers it

FRUS prints almost nothing from the State Department's own refugee-programme files after 1963 —
5 `REF`-sourced documents in 316,839. The office that generated that record (the Bureau for Refugee
Programs and its predecessors, and the `REF` category of the Central Foreign Policy File, RG 59) is
**not** reachable through the bundled indexes: `series-facts-index.json` holds 695 series and
**none** of them matches refugee/displaced/migration/escapee/repatriation/resettlement/immigration
on any field. The offline stack likewise barely reaches before 1940. So for 1963–1981 the printed
record is a White House and Near East record, and the departmental record has to be requested from
NARA directly — I can name where it is not, and I cannot name its NAID from what is on this machine.

---

## 6. Documents I actually read

Retrieved **whole** (captured length = `length(body_text)`), saved to `captured.txt` in this
directory: **7 documents**.

| id | length | note |
|---|---|---|
| frus1868p2/d233 | 1,522 | Seward to Hollister, Haiti |
| frus1875v02/d13 | 3,172 | Bassett to Fish, Port au Prince |
| frus1891/d194 | 435 | Wharton to Egan, Chile |
| frus1946v01/d1 | 599 | **my mis-guess** — a headerless editorial note on the UN Participation Act of 1945, not the IRO compilation. Recorded rather than deleted. |
| frus1946v01/d752 | 3,768 | the actual IRO-genesis note, found by walking the volume structure instead of guessing an id — see §5 |
| frus1961-63v25/d313 | 9,768 | UNHCR programme shift |
| frus1977-80v22/d115 | 16,263 | Interagency Task Force on Indochinese Refugees |

**Quoted: 3.**

`frus1868p2/d233`, Seward to Hollister, Department of State, July 18, 1868 — the clearest statement
of nineteenth-century doctrine I found, and worth having early because it frames the whole first
era: "The practice of opening asylum in consular offices to political refugees is exceptional. It is
adopted only in intercourse with States imperfectly constituted and established, and it rests for
its vindication not upon principles of international law, but only upon laudable sentiments of
humanity."

`frus1961-63v25/d313`, Instruction A-191 to the Mission in Geneva, April 24, 1961, subject
"Possible Shift in Emphasis in Program of the United Nations High Commissioner for Refugees" — the
Europe-to-global pivot stated in one paragraph, and the pivot document for anyone working on the
1960s: the Mission is told that US statements reflect "awareness of the existence of refugee
problems outside Europe" but "should discourage any interpretation of these statements as
indicating automatic increases in United States support for refugees outside of Europe."

One reading note that will bite you: `document_cache.body_text` **repeats the source note and the
header inside the body**, and it **includes the editors' footnotes**. Any term frequency computed
on it blends the document's language with the editor's. This index cannot separate them —
`cross_references.reference_type` defaults body references to 'footnote' and cannot support the
split either. If you need document-only density, that is a TEI job.

---

## 7. Subject tags — a warning, briefly

`document-subject-index.json` has a whole *Refugees* subcategory under *Human Rights*: `Refugees`
(df 5,885), `Asylum` (1,557), `Political refugees` (285), `Humanitarian assistance` (178),
`Refugee camps` (170), `Cuban refugees` (101), `Refugee resettlement` (95), `Indochinese refugees`
(40), plus `Immigration` (4,041) and `Emigration` (1,936) under *Global Issues*.

They are **string matches, not analysis**, and here is the measurement: subject 40 (`Refugees`) tags
5,756 non-apparatus documents, of which **5,638 also match the word `refugee`** — 97.9% containment.
The tag adds 118 documents you would not find by searching the word, and misses 2,139 that the word
finds. It is not an independent axis. Use it to *slice*, never to *count*.

---

## 8. What I would do next

1. **Search the editors' strings, not yours.** The eleven compilation titles bolded in §3 will pull
   the 1933–1963 policy record intact. "Governmental assistance to persons forced to emigrate for
   political or racial reasons" alone is 369 documents across `frus1943v01` and `frus1944v01`.
2. **Treat 1861–1910 as a different question** and search `asylum`, `right of asylum`, `temporary
   refuge`, `expatriation` — not `refugee`. The legation-asylum material is a coherent body of
   doctrine (Seward 1868, Bassett/Haiti 1875, Egan/Chile 1891) and it is what the term meant then.
3. **Search the acronym separately for 1945–1952.** `DP` / `DPs` is a distinct token from
   `displaced persons` and the phrase search cannot reach it — 445 occurrences across 49 volumes in
   the DP era. Verify every hit in context: two of the corpus's three biggest `DP` volumes mean the
   Korean Democratic Party and David Packard, not displaced persons (see §2).
4. **Decide early whether Palestine is in scope.** Eleven of the top twenty densest volumes are
   Near East or Arab-Israeli. If it is in scope, `"Palestine refugees"` (tolerant form, 320 of 327) and UNRWA are
   your handles; if it is not, you must exclude those volumes explicitly or they will dominate every
   count you produce.
5. **For the archives, start at 840.48.** It is the 22nd busiest class key in the series, it is
   named "Refugees" as a subfile, it runs 1938–1949, and it is not digitised. Then `320.2` (IRO,
   1950–54), `324.8411` (UNHCR, to 1963), and after 1963 give up on State's central file and go to
   the presidential libraries, which is where FRUS itself went.
6. **Do not run a density or apparatus-separated claim off this database.** It cannot separate a
   footnote from a body. Go to the TEI for that.

---

## 9. Caveats a reader should hold against me

- Every count above is from **this index**, which stores porter stems and a flattened text.
  Two of my own candidate terms (`emigration`, `sufferers`) failed their literal-share checks and
  are reported as refuted rather than dropped silently.
- I have **not** separated document text from editorial apparatus in any figure. The database drops
  front matter and editorial notes by column (and I did, everywhere), but `body_text` still contains
  footnotes.
- `citation_era` above is a citation **form**, not a date; I have not plotted it as a timeline.
- `person_rollup` / `person_mentions` were not used: name clustering under-merges and TEI person
  tagging is uneven, so any person count here would be a lower bound of unknown depth.
- The archival counts are **two channels reported separately and never summed**, per §5.
- The one class-8/class-7 gloss error I made is corrected in §5 rather than quietly removed.
- The TEI variant scan in §2 is an **occurrence** count over a surface that **includes the
  apparatus** — front matter, abbreviation lists, footnotes and the back-of-book index are all
  inside the file. It is therefore not comparable, line for line, with the document counts from the
  database, which exclude front matter and editorial notes. I have kept the two clearly separated
  and have not divided one by the other.
- `queries.log` is appended as I go and is faithful, but a few entries are multi-line: where I ran a
  small script through a heredoc, the script body occupies its own lines rather than being folded
  onto one. Nothing was reconstructed afterwards.
- One document in §6 (`frus1946v01/d1`) is a guess that turned out wrong; it is left in the table
  rather than removed, and the right document was found by walking `volume_structures` instead.
- Volume coverage is complete (552/552), so no figure here is thinned by a partial library — but the
  *series* ends in 1981 in this snapshot, which truncates the 1980s row of the decade table and puts
  the Refugee Act of 1980 and Mariel at the very edge of what exists to be found.
