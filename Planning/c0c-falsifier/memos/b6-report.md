# Scoping memo — US participation in international sanitary conventions and quarantine practice

**Surfaces used:** the SQLite index (`/Users/jbotts/frus-analysis/frus-copy.db`, read-only), the TEI
corpus (`/Users/jbotts/Development/frus/volumes/*.xml`), and the bundled JSON in
`/Applications/FRUS Explorer.app/Contents/Resources/`. No HARVEST path was given, so no
`[HARVEST]` number appears below.
**Every command is in `queries.log`, in order.** Working files named in the text are in this directory.

---

## 0. Coverage

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 | 316839 | 1012 | 8468
```

Your library is **complete**: 552 of 552 volumes, 316,839 documents, 1,012 front-matter and 8,468
editorial-note rows. No result below is thin because of a partial download. With apparatus excluded
and the two second editions suppressed (`frus1951-54IranEd2`, `frus1969-76ve15p2Ed2`), the working
denominator is **306,619 documents**.

**Controls, run in the same pass.** DB: `"Department of State"` → 98,499 documents in 551 of 552
volumes; `ZZZ_IMPOSSIBLE_ZZZ` → 0. TEI: `department of state` → 6,532 occurrences over the 19
pre-1910 volumes I parsed and 2,980 over the 20 modern ones; `ZZZ_IMPOSSIBLE_ZZZ` → 0 in both. The
scans work.

---

## 1. The headline

**FRUS carries this subject continuously from 1866 to 1940, and then essentially drops it.** It is
not a compiled subject: apart from one 1938 chapter, it is scattered through country chapters of the
annual volumes. The corpus documents the United States as a *participant* — invited, sometimes
absent, eventually signatory — rather than as an architect, and the largest single body of material
is not conference diplomacy at all but **complaints about quarantine practice at foreign and
American ports**.

Three things will waste your time if you don't know them first, and all three are measured below:

1. **`quarantine` is the corpus's worst false friend for this question.** 261 of the 847
   non-apparatus `quarantine` documents are 1960s, and they are the Cuban naval quarantine.
2. **`sanitary` in the 1880s–90s is mostly pork.** 57 of 107 (1880s) and 61 of 95 (1890s) `sanitary`
   documents co-occur with pork/swine/trichina/cattle vocabulary — the American meat-export
   controversy, filed under "sanitary" restrictions and "sanitary police".
3. **The editors' chapter titles are the reliable index; the document headers are not.** Only 10
   documents in 316,839 have a header naming the subject.

---

## 2. What the corpus holds — the editors' own chapters

I walked `volume_structures` for chapter titles (script `headings.py` → `headings_all.txt`, 66
headings; `chapters.py` → `chapters.tsv`, 60 chapters carrying 435 documentIds). Curated to the
subject (`build_core_docs.py`; inclusion and exclusion regexes are in `queries.log` §8), that gives
**24 chapters, 100 documents, 21 volumes** — the files are `core_chapters_final.tsv` and
`core_docs.tsv` (100 lines, no elision).

The spine, in date order:

| Volume | Chapter (editors' wording, trimmed) | Docs |
|---|---|---|
| frus1895p1 | Germany — Protest against immigration and quarantine laws | 2 |
| frus1900 | Argentine Republic — Interference with official duties of foreign representatives in matters of quarantine and bills of health | 2 |
| frus1900 | Japan — Alleged discrimination in United States against Japanese, in the matter of quarantine against bubonic plague | 19 |
| frus1901 | Japan — same subject, continued | 2 |
| frus1905 | Argentine Republic — International sanitary convention between the Argentine Republic, Brazil, Paraguay, and Uruguay | 1 |
| frus1906p2 | Mexico — Sanitary convention of 1905 | 2 |
| frus1907p1 | France — International sanitary convention | 1 |
| frus1907p2 | Mexico — Third International Sanitary Convention, Mexico City, December 2–7, 1907 | 4 |
| frus1908 | Italy — Arrangement … for the establishment of the International Office of Public Health | 1 |
| frus1909 | Circulars — Fourth Pan-American Sanitary Conference | 1 |
| frus1909 | International conferences — Sanitary convention between the United States and other powers | 1 |
| frus1909 | International conferences — Fourth International Sanitary Convention | 4 |
| frus1923v01 | Cooperation between the International Office of Public Health and the Health Commission of the League of Nations | 6 |
| frus1924v01 | Sanitary convention between the United States and other American Republics, signed November 14, 1924 | 1 |
| frus1924v02 | Turkey — American representative … Sanitary Commission for Turkey | 4 |
| frus1926v01 | Convention … revising the international sanitary convention of January 17, 1912 | 7 |
| frus1927v01 | Additional protocol … amending the Pan American sanitary convention of November 14, 1924 | 1 |
| frus1928v02 | Egypt — American representative on the International Quarantine Board at Alexandria | 11 |
| frus1929v02 | Canada — quarantine inspection of vessels entering Puget Sound … or the Great Lakes via the St. Lawrence | 1 |
| frus1930v02 | China — Jurisdiction for quarantine purposes over American merchant vessels in Chinese ports | 14 |
| frus1932v02 | Egypt — International Quarantine Board at Alexandria, continued | 3 |
| frus1935v04 | Argentina — Unperfected sanitary convention … signed May 24, 1935 | 1 |
| **frus1938v01** | **Participation of the United States in the International Sanitary Conference, Paris, October 28–31, 1938** | **4** |
| frus1940v05 | Argentina — ratification by the United States of the Sanitary Convention of 1935 | 7 |

Two structural facts about this table. First, **`frus1938v01` is the only chapter in the whole series
whose title is the question** — `divType: "compilation"`, `sectionId: comp17`, `documentIds:
["d927","d928","d929","d930"]`. Second, **the pre-1910 material is under-represented here**, because
in the annual volumes the sanitary correspondence is filed by *post*, inside chapters titled
"Austria-Hungary", "Turkey", "Great Britain" — not by subject. §5 shows what that hides.

### What I read

I retrieved **23 documents whole** and verified capture on all of them: `read2_raw.txt` (14 docs,
captured chars == `length(body_text)` for 14 of 14), `read3_raw.txt` (6), `read4_raw.txt` (3). The
SELECTs are `read1.sql`–`read4.sql`. I quote from **7** of them below (`frus1938v01/d927`, `/d929`, `/d930`; `frus1866p2/d205`; `frus1880/d4`; `frus1881/d358`, `/d362`).

The 1938 chapter is worth describing precisely, because it is the clearest single statement in the
corpus of what "US participation" meant. `frus1938v01/d927` (source note `512.4B3/5`) is an Egyptian
aide-mémoire asking Washington to support abolishing the Alexandria board, describing the object of
the congress as "the modification of the above-mentioned Treaty by the abolition of the Maritime
Sanitary and Quarantine Council". `frus1938v01/d929` records acceptance: Hull informs the Egyptian
Minister "that the invitation has been accepted and that Surgeon General Hugh S. Cumming, Retired,
United States Public Health Service … has been appointed delegate", adding that "Dr. Cumming is the
American representative at the International Office of Public Health." `frus1938v01/d930` is the
Paris chargé's report — 57 delegates, 24 of them plenipotentiaries, three commissions, Cumming on
two of them.

---

## 3. Term families, with their literal shares

All counts below: apparatus excluded (`is_front_matter=0 AND is_editorial_note=0`), Ed2 volumes
suppressed. The predicate shape is in `queries.log` §3.

| Phrase (FTS5 `MATCH '"…"'`) | Docs | Volumes |
|---|---|---|
| `"bill of health"` (= `"bills of health"`, same stem) | 136 | 76 |
| `"sanitary regulations"` | 131 | 76 |
| `"quarantine regulations"` | 98 | 49 |
| `"world health organization"` | 89 | 39 |
| `"sanitary convention"` | 84 | 38 |
| `"international sanitary"` | 64 | 35 |
| `"quarantine station"` | 38 | 27 |
| `"sanitary bureau"` | 22 | 14 |
| `"sanitary conference"` | 21 | 17 |
| `"pan american sanitary"` | 15 | 10 |
| `"sanitary code"` | 10 | 9 |
| `"international office of public health"` | 8 | 5 |
| single terms (same exclusions): `quarantine` 847 / 213 · `sanitary` 1,308 / 256 · `epidemic` 484 / 204 · `plague` 775 / 338 | | |

**`"bill of health"` and `"bills of health"` return the identical 136 documents.** That is the porter
fold, visible: do not read a difference between them into anything.

### Literal shares (census, not sample)

Rule (a) obligation, discharged for every family I argue from. Script `share.py` → `share_out.txt`.
Surface: `header || dateline || source_note || body_text`, whitespace-collapsed. Matching:
**Python `re`, `IGNORECASE`**, applied uniformly to the whole family set (I did not mix in SQL `LIKE`
anywhere). **The census is the whole hit list, not a sample** — every family is under 300.
STRICT = single spaces between the words. TOLERANT = each word allowed its inflections, separated by
any run of space, hyphen, comma, parenthesis or full stop.

| Family | STRICT | TOLERANT |
|---|---|---|
| `international sanitary convention` | 43 of 45 (0.956) | **45 of 45 (1.000)** |
| `sanitary convention` | 77 of 84 (0.917) | **84 of 84 (1.000)** |
| `sanitary conference` | 17 of 21 (0.810) | **21 of 21 (1.000)** |
| `bill of health` | 96 of 136 (0.706) | **136 of 136 (1.000)** |
| `quarantine regulations` | 93 of 98 (0.949) | **98 of 98 (1.000)** |
| `pan american sanitary` | 13 of 15 (0.867) | **15 of 15 (1.000)** |
| `quarantine station` | 31 of 38 (0.816) | **38 of 38 (1.000)** |
| `sanitary bureau` | 22 of 22 (1.000) | **22 of 22 (1.000)** |

Every family is fully literal at tolerant. Note `bill of health` at 0.706 strict: the 40 strict misses
are plurals and hyphen/line-break separations, not different words — which is exactly the case the
rule warns against condemning. **But a 1.000 share tests the stemmer, not the referent**, so §4 tests
the referents separately, and two of them fail.

---

## 4. Two referent failures you must design around

### 4.1 `quarantine` — the Cuban missile crisis owns the word

Document-level co-occurrence test, re-derivable in SQL (`queries.log` §12b):

```sql
WITH q   AS (… MATCH 'quarantine' …),
     dis AS (… MATCH 'cholera OR "yellow fever" OR smallpox OR typhus OR epidemic OR sanitary
                       OR pratique OR lazaretto OR "bill of health" OR disinfection OR fumigation
                       OR pestilence OR bubonic' …)
SELECT substr(dt.date_iso,1,3)||'0s',
       SUM(CASE WHEN EXISTS(SELECT 1 FROM dis WHERE dis.v=q.v AND dis.id=q.id) THEN 1 ELSE 0 END),
       COUNT(*) FROM q JOIN document_dates dt … GROUP BY 1;
```

**283 of 847** `quarantine` documents carry any disease or sanitation vocabulary at all. By decade
(with-disease / all): 1860s 54/74 · 1870s 29/40 · 1880s 37/60 · 1890s 36/64 · 1900s 36/57 ·
1910s 18/54 · 1920s 35/73 · 1930s 26/71 · 1940s 6/39 · 1950s 1/11 · **1960s 1/261** · 1970s 0/25 ·
1980s 3/13. **226 of the 847 sit in `frus1961-63*` volumes alone.** A proximity classifier
(`referent.py` → `referent_out.txt`, `quarantine_classified.tsv`) agrees in direction — 110
naval/Cuba, 275 health/maritime, 38 plant/animal, 57 both-signal, 367 unclassified — but its
unclassified bucket is a third of the set, so **the SQL co-occurrence number above is the one I
publish**; treat the proximity split as corroboration only.

Periodisation throughout this memo is on `document_dates.date_iso`, i.e. `frus:doc-dateTime-min`,
never the volume's series year.

### 4.2 `sanitary` in the Gilded Age — the pork controversy

```sql
WITH san AS (… MATCH 'sanitary' …),
     ani AS (… MATCH 'pork OR swine OR trichina OR trichinosis OR "hog cholera" OR cattle
                      OR "foot and mouth" OR "salted meats" OR bacon OR hogs OR livestock
                      OR "live stock"' …),
     hum AS (… MATCH 'cholera OR "yellow fever" OR smallpox OR typhus OR quarantine
                      OR "bill of health" OR pratique OR lazaretto OR "public health"
                      OR "board of health" OR plague' …) …
```

| Decade | `sanitary` docs | with animal/meat vocab | with human-disease vocab |
|---|---|---|---|
| 1860s | 81 | 14 | 54 |
| 1870s | 59 | 13 | 26 |
| **1880s** | **107** | **57** | 52 |
| **1890s** | **95** | **61** | 34 |
| 1900s | 154 | 32 | 59 |
| 1910s | 162 | 19 | 41 |
| 1920s | 200 | 8 | 57 |
| 1930s | 195 | 14 | 56 |
| 1940s | 172 | 11 | 16 |

I found this by reading, not by suspecting it. `frus1881/d358` (Thornton to Evarts, 7 March 1881) is
about "the immense mortality among swine by a disease known as 'hog cholera'"; `frus1881/d362`
(Blaine to Thornton, 22 April 1881) answers a British request for "strict measures of sanitary
police" against foot-and-mouth in exported animals. Both are `sanitary` hits and neither is about
human quarantine. If you scope on `sanitary` alone for the 1880s you will build a memo about meat.

### 4.3 The false-friend test the house rules require

Share of each question-supplied term in a 12-volume on-topic set (`frus1905, frus1906p2, frus1907p1,
frus1907p2, frus1908, frus1909, frus1924v01, frus1926v01, frus1927v01, frus1935v04, frus1938v01,
frus1940v05`; 9,293 non-apparatus documents) against the corpus baseline (306,619):

| Term | on-topic | corpus | enrichment |
|---|---|---|---|
| `sanitary` | 122 of 9,293 | 1,308 of 306,619 | **3.08×** |
| `bill of health` | 8 of 9,293 | 136 of 306,619 | 1.94× |
| `cholera` | 8 of 9,293 | 248 of 306,619 | **1.06× — at baseline** |
| `quarantine` | 21 of 9,293 | 847 of 306,619 | **0.82× — below baseline** |
| control: `extradition` | 168 of 9,293 | 1,600 of 306,619 | 3.47× |
| control: `good offices` | 322 of 9,293 | 5,080 of 306,619 | 2.09× |
| control: `commerce` | 638 of 9,293 | 14,740 of 306,619 | 1.43× |
| control: `treaty` | 1,672 of 9,293 | 45,907 of 306,619 | 1.20× |

Read this honestly. `quarantine` and `cholera` **fail**: they do not discriminate the volumes that
actually carry the conventions, so stop using them as scoping terms. And `sanitary`, though enriched
3.08×, is beaten by the control `extradition` at 3.47× — which does not mean `sanitary` is useless,
it means **my volume set is the wrong grain**. These are big general annual volumes that are dense in
every treaty-diplomacy word; the sanitary material inside them is one chapter of several hundred
documents. Scope at chapter grain (`core_docs.tsv`), not volume grain.

---

## 5. Where the material sits in time

13-term family (`"sanitary convention" OR "sanitary conference" OR "international sanitary" OR
"sanitary code" OR "sanitary bureau" OR "sanitary regulations" OR "quarantine regulations" OR
"quarantine station" OR "quarantine board" OR lazaretto OR pratique OR "bill of health" OR
"international office of public health"`), apparatus excluded, Ed2 suppressed: **538 documents in 166
volumes**. Rate per 1,000 dated non-apparatus documents of that decade, with the numerator's top
volume, exactly as the house rule requires:

| Decade | hits | decade denominator | per 1,000 | top volume in numerator |
|---|---|---|---|---|
| 1850s | 1 | 150 | 6.667 | frus1872p2v2:1 |
| 1860s | 58 | 11,250 | 5.156 | frus1867p1:13 |
| 1870s | 53 | 5,798 | **9.141** | frus1879:15 |
| 1880s | 52 | 6,472 | 8.035 | frus1888p1:12 |
| 1890s | 47 | 9,712 | 4.839 | frus1896:9 |
| 1900s | 76 | 9,924 | 7.658 | frus1900:11 |
| 1910s | 31 | 30,359 | 1.021 | frus1919Parisv06:5 |
| 1920s | 60 | 19,733 | 3.041 | frus1928v02:12 |
| 1930s | 83 | 39,196 | 2.118 | frus1930v02:11 |
| 1940s | 41 | 74,043 | 0.554 | frus1944v02:8 |
| 1950s | 13 | 42,296 | 0.307 | frus1955-57v11:1 |
| 1960s | 4 | 27,650 | 0.145 | frus1969-76ve02:1 |
| 1970s | 12 | 22,259 | 0.539 | frus1969-76ve10:3 |
| 1980s | 1 | 5,949 | 0.168 | frus1981-88v13:1 |

The 1850s row is one document; ignore it. The real shape is a **19th-century plateau around 5–9 per
1,000, a 1910s collapse to 1.0, a partial 1920s–30s recovery, and effective disappearance after
1945**. The top-volume shares are low enough (13 of 58 in the 1860s, 15 of 53 in the 1870s) that no
decade rests on a single negotiation.

**The collapse is real but it is partly a change of venue, not of interest.** After 1948 the subject
migrates to the World Health Organization, which the index reaches under a different vocabulary:
`"world health organization"` = 89 documents in 39 volumes, top volumes `frus1981-88v41` (14),
`frus1977-80v02` (9), `frus1969-76ve14p1` (6). There is a chapter for it — `frus1977-80v02`,
"International Health, Population Growth, and Women's Issues", 72 documentIds. `"smallpox
eradication"` returns only 2 documents (`frus1964-68v24`, `frus1977-80v02`).

---

## 6. Absences, tested by name

The house rule against circular negatives applies hard here, so each of these was tested with the
contemporaries' own words, and where the thing is printed under another name I give the document.

- **The 1851–1874 European sanitary conferences.** Present, but as reportage from posts, not as US
  participation. `frus1866p2/d205` (Morris to Seward, Constantinople, 23 Dec 1865) transmits the
  Porte's invitation to "an international sanitary conference for the purpose of ascertaining and
  pointing out the precautionary measures to be taken against the cholera and its propagation",
  noting it "is not at all of a diplomatic character, and is composed of competent men".
  `frus1874/d20`, `/d21`, `/d26` are the Vienna 1874 sequence — and `frus1874/d21` (Fish to
  Delaplaine, 21 Aug 1874) is an explanation of **why no American delegate attended**, the Austrian
  invitation having gone astray. That is a finding, not a gap.
- **The 1881 Washington International Sanitary Conference — the one the US itself convened.** No
  chapter names it. It is printed under another name: **`frus1880/d4`**, "No. 4. To the diplomatic
  officers of the United States", 30 July 1880, instructing them that "in pursuance of a joint
  resolution of Congress which was approved on the 14th of May last, the President has determined to
  call an international sanitary conference to meet at Washington". The replies are filed by country
  in `frus1881` (`d16`, `d27`, `d31`, `d35`, `d39`, `d45` from Vienna and Brussels, `d270` Paris,
  `d298` Berlin, `d419` Rome, `d358`/`d360`/`d361`/`d362` Thornton). **Beware: several of those
  `frus1881` hits are the pork dispute, not the conference** (§4.2) — you must read them, not count
  them.
- **"International Sanitary Regulations" (the WHO instrument of 1951).** `MATCH '"international
  sanitary regulations"'` returns **2 documents, in `frus1880` and `frus1888p1`** — the 19th-century
  sense of the phrase. The WHO instrument is **not** in this corpus under that name. `"world health
  assembly"` returns 14 documents, none before 1951.
- **The Office International d'Hygiène Publique.** Present, and reachable only through the *English*
  name: `"international office of public health"` = 8 documents (`frus1908`, `frus1923v01`,
  `frus1938v01`, `frus1939v02`, `frus1944v02`); `"hygiene publique"` = 3; `"office international
  dhygiene publique"` (unicode61 drops the apostrophe) = **0**. The founding document is
  `frus1908/d468`, a presidential proclamation of the Rome arrangement.
- **`"constantinople board of health"` and `"board of health at constantinople"` both return 0 rows.**
  I verified the query shape can return rows — `"superior board of health"` returns 15
  (`frus1881`, `frus1903`, `frus1905`, `frus1906p1`, `frus1906p2`, `frus1907p1`, `frus1907p2`,
  `frus1908`, `frus1909`, `frus1912`) and `"conseil sanitaire"` returns 1 (`frus1878`) on the same
  predicate. The Ottoman body is in the corpus under **"Sanitary Commission for Turkey"**
  (`frus1924v02`, 4 documents) and, in `frus1938v01/d930`, as "the International Sanitary Control
  formerly functioning in Turkey under the capitulatory regime".
- **`"cordon sanitaire"` returns 67 documents** — and it is a false friend: the hits are
  `frus1919Parisv03/v07`, `frus1919Russia`, `frus1943v01`, `frus1945Berlinv01` and so on, i.e. the
  political cordon against Bolshevism. Do not fold it into the epidemiological family.

**Two FTS5 queries errored and returned nothing** — `sanitary NEAR/6 conference` and
`quarantine NEAR/4 cholera`, both `fts5: syntax error near "/"`. No number in this memo comes from
them; I am recording them because the log must be complete.

---

## 7. Apparatus: how much of this is the editors talking? [TEI]

The database cannot separate a footnote from a body (`body_text` holds both), so I did it on the TEI.
**Counting surface: tag-stripped and whitespace-collapsed, inside `<div type="document">` only**
(which excludes front matter and editorial-note divs by TEI type). Script `tei_split.py`; outputs
`tei_split_pre1910.txt` (19 volumes, 15,189 document divs) and `tei_split_modern.txt` (20 volumes,
15,981 document divs). Case-insensitive except the WHO acronym, which is case-sensitive — matched
case-insensitively it returns 16,365 hits in the 19th-century volumes, all of them the English word
"who", which is a false friend I built into my own instrument on the first pass and then fixed.

| Variant | pre-1910 set: body / notes | modern set: body / notes (notes share) |
|---|---|---|
| quarantin(e/es/ed/ing) | 567 / 2 | 279 / 1 (0.004) |
| sanitary | 936 / 7 | 523 / 22 (0.040) |
| international sanitary convention | 46 / 1 | 34 / 3 (0.081) |
| bill(s) of health | 84 / 0 | 36 / 0 (0.000) |
| pratique | 31 / 3 | 21 / 0 |
| lazaretto/lazaret | 24 / 1 | 0 / 0 |
| cholera | 352 / 0 | 92 / 0 |
| yellow fever | 171 / 1 | 40 / 2 |
| Pan American Sanitary (any hyphen) | 0 / 0 | 46 / 2 |
| World Health Organization | 0 / 0 | 21 / 5 (0.192) |
| **control: department of state** | **6,518 / 14** | **2,093 / 887 (0.298)** |
| control: ZZZ_IMPOSSIBLE_ZZZ | 0 / 0 | 0 / 0 |

**Read the control row first.** In the modern volumes 29.8% of "Department of State" occurrences are
in editorial notes — the apparatus is heavy there. Against that baseline, the sanitary vocabulary's
notes share is 0.4%–8%. **So this vocabulary is the historical actors' language, not the editors'**,
and the `body_text` blending trap, though real in principle, does not distort this particular family.
Also worth noting: "Pan American Sanitary" is **0 / 0** in the pre-1910 set even though `frus1909`
has a chapter titled "Fourth Pan-American Sanitary Conference" — because chapter `<head>`s sit
*outside* `<div type="document">`. Chapter titles and document text are two different surfaces.

I did not attempt a full-corpus TEI variant census; these 39 volumes are the ones carrying the
material, and that is a stated limit of the scan, not a claim about 552 volumes.

---

## 8. Archival scope — where these documents came from, and where the footnotes point

**Two channels, never summed.**

### Channel A — came-from (`document_sources`, one row per document)

Over the **100 core-chapter documents** (`channels.sql`, whose `VALUES` list is `core_docs.tsv`,
100 lines):

- **69 of 100** carry a source row. By `citation_era`: decimal **62**, published 6, unrecognized 1.
- Record group: **RG-59, Department of State, for 62 of 69**; the remaining 7 rows carry neither.
- Decimal classes, all of them: `893.12` (14) · `883.12` (14) · `711.359` (7) · `512.4-A` (6) ·
  `867.12` (4) · `512.4B3` (4) · `512.4-B` (3) · `711.429` (1).

Over the **538-document 13-term family**: 259 source rows — decimal 213, published 20, structured 15,
unrecognized 5, lot_file 4, named_series 1, cfpf 1. Split by era:

| | documents | with a source row |
|---|---|---|
| pre-1910 | 287 | **19** |
| 1910+ | 245 | **240** |
| undated | 6 | 0 |

That 19-of-287 is the whole pre-1910 archival story: **the 19th-century volumes print no source note**,
so this channel cannot tell you where a pre-1910 sanitary despatch came from. For that period the
route is not a subject file at all but the country series — `central-files-index.json` lists them:
Diplomatic Despatches (series NAID 603720, 2,160 rolls), Consular Despatches (302031, 3,357),
Notes from Foreign Missions (594363, 522), Notes to Foreign Missions (597272, 104), Diplomatic
Instructions (593313, 177), plus the 1906–1910 Numerical File (microfilm M862, series NAID 654171).
You go in by post and date, from the dateline of the printed document.

### Channel B — pointed-at (`external_citations`, many rows per document)

**This channel is effectively empty for this question, and structurally so.** Over the 100 core
documents: **2 rows in 2 documents**. Over the 538-document family: **15 rows in 11 documents** —
3 class `715.00`, 2 Reagan Library / Executive Secretariat, 1 Ford Library / National Security
Adviser, 1 lot `64 D 199`, 1 lot `54 D 423`, and single rows for classes 893.12, 883.12, 861.24591,
800.796, 611.82, 367.116, 180.0501. The cause is not a gap in your library: this channel has no row
before 1910-12-06, it stores the citation fragment rather than the sentence, and it holds only lot,
library and decimal anchors — and 287 of 538 of these documents are pre-1910. **Do not rank anything
on it.**

The two lots resolve (`lot_lookup.py` → `lot_lookup_out.txt`): `64D199` → NAID 602231, RG 59, *The
Secretary's and the Under Secretary's Memorandums of Conversation*, HMS/MLR entry A1 1566; `54D423`
→ NAID 2127217, RG 59, *Japanese Petitions*, A1 1255. `54D423` is a **divided lot** — it appears in
`lot-claimants-index.json` (123 divided lots) with several claimant series (*Subject Files* NAID
2127213 / A1 1252, *Cable Files* NAID 2127215 / A1 1253, …), so one NAID is not the answer for it.

### Glossing the decimal classes [JSON]

The bundled `decimal-class-labels.json` is `schemaVersion 1`, generated 2026-08-11, and ships
**exactly one schedule, 1910–1949** (9 classes, 198 countries), with subject tables for **classes 6
and 8 only**. There is no `coverage` block in this copy, so the schedule's own `startYear`/`endYear`
is the gate. Every document above is dated 1910–1949, so glossing is permitted; I have glossed
nothing outside it.

| Class | Gloss | Volumes |
|---|---|---|
| `512.4-A`, `512.4-B`, `512.4B3` | class 5 = **Congresses and Conferences**. The digits after the class are **not glossable** — this schedule ships no class-5 subject table. | frus1923v01, frus1926v01, frus1938v01 |
| `893.12` | 8 *Internal Affairs of States* + 93 **China** + `.12` **Public health** | frus1930v02 |
| `883.12` | 8 + 83 **Egypt** + `.12` **Public health** | frus1928v02, frus1932v02 |
| `867.12` | 8 + 67 **Turkey** + `.12` **Public health** | frus1924v02 |
| `711.359` | 7 *Political Relations of States. Bi-lateral Treaties* + 11 **United States** + 35 **Argentine Republic/Argentina** | frus1940v05 |
| `711.429` | 7 + 11 **United States** + 42 — **the shipped 198-country table has no name for 42**, so I am not naming it | frus1929v02 |

Note `.124` in the same schedule is *Hygiene and sanitation* and `.1246` is *Hygiene of vessels and
aircraft* — worth trying in the catalogue even though FRUS never cites them here.

### Ranked archival targets [JSON]

`collection-usage-index.json` (schemaVersion 1, generated 2026-08-19; coverage: 552 volumes scanned,
264,464 notes, 74,914 in a collection, 190,407 with a class key). Script `archival2.py` →
`archival2_out.txt`.

- **Every `512.4*` class key in the whole corpus is 16 documents**: `512.4-A` 6 (frus1923v01),
  `512.4B3` 4 (frus1938v01), `512.4-B` 3 (frus1926v01), `512.4A1A1` 3 (frus1944v02). That is the
  entire footprint of "International Congresses and Conferences — sanitary" as FRUS cites it.
- Public-health classes: `893.12` 15 docs (frus1930v02:14, frus1941v05:1) · `883.12` 14
  (frus1928v02:11, frus1932v02:3) · `867.12` 4 (frus1924v02) · `711.429` 10 (frus1930v01:8,
  frus1925v01:1, frus1929v02:1) · `711.359` 7 (frus1940v05) · `893.1281` 3.
- **Collection axis: 0 document-notes** for the 12 core post-1910 volumes. Not a bug — these
  documents are cited by decimal class, not by named collection or lot file, which is what pre-1950
  FRUS does.

### What you cannot see before travelling

- `digitized-ranges-index.json` (generated 2026-08-07, 624 ranges): **0 ranges** for classes 512,
  893, 883, 867 or 711. The digitised decimal file covers only `131`, `131.1`, `133`, `133.1` and the
  `763.72*` WWI family. **No scan substitutes for a visit here.**
- `series-facts-index.json` (bundled copy is `schemaVersion 2`, no `legend` key, 695 series): of 397
  creator headings, **exactly one** names health — *Department of State. Bureau of International
  Organization Affairs. Office of the Deputy Assistant Secretary for Human Rights and Social Affairs.
  Health and Narcotics Directorate.* The three series NAIDs the decimal and numerical-file routes use
  (2555709, 302021, 654171) are **not** in `byNaId`. The bundled series layer barely reaches this
  subject, and it reaches almost nothing before 1940 — say that rather than reading it as an archival
  absence.

**The corpus-scoping negative, answered.** FRUS does not print the 1851–1897 conference proceedings,
the 1903 and 1912 convention negotiations, the WHO's founding, or the 1951 International Sanitary
Regulations. The series that do: the 1881 Washington conference proceedings were published by
Congress (`frus1880/d4` names the joint resolution of 14 May 1880 as its authority); the Fourth
Pan-American conference's transactions are noted in the `frus1909` chapter title as separately
published; the treaty texts themselves are printed as Treaty Series (`frus1926v01/d116` carries
`Treaty Series No. 762`) and are in Malloy, which the `frus1926v01` chapter title cites for the 1912
convention. For the archival originals, the routes are RG 59 class `512.4` (1910–1949), the pre-1910
country series named above, and — outside RG 59 entirely, and outside every index you have here —
the records of the Marine Hospital Service / Public Health Service in RG 90.

---

## 9. People

`"Hugh S. Cumming"` returns 85 documents — **and 23 of them are dated 1946 or later**, which is a
different man (the Foreign Service officer, Jr.). Only **9 of 85** co-occur with `sanitary OR
quarantine OR "public health"`. Others: `"Walter Wyman"` 4 (frus1900, frus1909), `"Rupert Blue"` 4
(frus1923v01, frus1924v01), `"Thomas Parran"` 2 (frus1943v01, frus1944v02), `"John M. Woodworth"` 1
(frus1871), `"John B. Hamilton"` 1 (and that one is `frus1952-54v04`, so probably a different
Hamilton). I did not scan a bare surname. `person_rollup` is name-clustered and under-merges, so
treat all of these as lower bounds; I did not use it for any count here.

---

## 10. What I would actually search for

1. **Start from `core_docs.tsv`** — the 100 chapter-scoped documents — not from a term. Read
   `frus1938v01/d927–d930`, `frus1926v01/d113–d119`, `frus1924v01/d219`, `frus1927v01/d238`,
   `frus1908/d468`, `frus1909/d611–d615` first. That is the convention spine, about 40 documents.
2. **Then the 19th century by post, not by subject.** `frus1866p2/d205`, `frus1874/d20/d21/d26`,
   `frus1880/d4`, then the `frus1881` replies — reading each, because half are pork.
3. **Search terms that survive the referent test**: `"sanitary convention"`, `"international
   sanitary"`, `"sanitary conference"`, `"quarantine regulations"`, `"bill of health"`, `pratique`,
   `lazaretto`, `"superior board of health"`, `"quarantine board"`, `"international office of public
   health"`. **Do not scope on bare `quarantine`, bare `sanitary`, bare `cholera`, `plague`, or
   `cordon sanitaire`.**
4. **The quarantine-practice thread is the bigger and less-worked body.** Pre-1910 documents matching
   `quarantine` *and* disease vocabulary rank: `frus1867p1` 15 · `frus1879` 14 · `frus1900` 12 ·
   `frus1896` 10 · `frus1895p1` 10 · `frus1888p1` 9 · `frus1865p3` 9 · `frus1904` 7 · `frus1888p2` 7.
   None of these is in a chapter titled for the subject.
5. **Archives**: RG 59 class **512.4** for the conferences 1910–1949 (16 documents' worth in FRUS,
   but the class itself is the target); classes **883.12 / 893.12 / 867.12** for the Alexandria board,
   Chinese port jurisdiction and the Turkish commission; **711.359** for the US–Argentina convention;
   the pre-1910 country series by post and date. Nothing here is digitised.

## 11. Caveats a reader should hold

- Every count is over the **complete 552-volume series** with apparatus excluded and the two second
  editions suppressed; no result is limited by your library.
- Shares in §3 are Python `re` `IGNORECASE`; the co-occurrence and count queries in §4–§5 are SQLite
  `MATCH`/`LIKE`, which is case-insensitive for ASCII. I did not mix the two within one family.
- `citation_era` in §8 is a citation **form**, not a date; it is never plotted here as a timeline.
- The 23 documents I read whole and the SELECTs that fetched them are on disk (`read1.sql`–
  `read4.sql`, `read2_raw.txt`, `read3_raw.txt`, `read4_raw.txt`). I quoted from 7 of them; every
  quotation above comes from a result set retrieved in this session.
- I did not read or quote `summary_text` or `note_text`.
- Subject tags were not used: `document_subject_refs` tags come from string matching, and for a
  subject this vulnerable to false friends they would have added candidates I would then have had to
  discard by the same tests I ran anyway.
