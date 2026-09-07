# Scoping memo — "How did the United States negotiate and administer international postal conventions?"

**Run date** 2026-09-06. **Surfaces used:** the SQLite index (all document counts) and the bundled
JSON in `/Applications/FRUS Explorer.app/Contents/Resources/` (all archival resolution).
**I did not open the TEI XML.** Nothing below is a spelling-variant census, an apparatus/document
split, or a counting-surface measurement; where the question wanted one, I say so and stop.

## 0. Coverage, and the caveat that qualifies every number here

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
--> 552 | 316839 | 1012 | 8468
```

Your library holds **552 volumes** — the full published series — so for once the partial-library
caveat is not binding. Every count below excludes `is_front_matter = 1` and `is_editorial_note = 1`
(**307,359 documents remain**) unless stated. Decade tables additionally suppress
`frus1951-54IranEd2` and `frus1969-76ve15p2Ed2`. I never read `summary_text` or `note_text`.

**Controls, run in the same pass as the first census** (predicate identical, only the MATCH string
changes):

```sql
SELECT COUNT(*) FROM frus_documents f
  JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
 WHERE frus_documents MATCH '"Department of State"'   -- 93,643   positive
   AND d.is_front_matter=0 AND d.is_editorial_note=0;
--   MATCH '"ZZZ_IMPOSSIBLE_ZZZ"'                     --      0   negative
```

The scan works. Absences below are findings, not failures.

---

## 1. The headline: the corpus splits into four unequal bodies, and only one is your question

I built a **CORE** family of eleven convention-machinery phrases and it returns **232 documents in
111 of 552 volumes**:

```
CORE = '"postal convention" OR "postal conventions" OR "Universal Postal Union"
     OR "General Postal Union" OR "postal union" OR "postal congress"
     OR "Universal Postal Congress" OR "postal treaty" OR "postal arrangement"
     OR "postal agreement" OR "international postal"'
SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f
  JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
 WHERE frus_documents MATCH '<CORE>' AND d.is_front_matter=0 AND d.is_editorial_note=0;
--> 232 | 111
```

Split on `document_dates.date_iso` (the editorial document date, **not** the volume's series year):

| era | CORE documents |
|---|---|
| pre-1900 | 81 |
| 1900–1945 | 95 |
| 1946+ | 51 |
| undated | 5 |

Those three eras are **three different research questions**, and I would not run one search across
them:

1. **1861–1899 — bilateral postal conventions, negotiated by the Post Office Department through
   State.** This is your question in its pure form. 81 documents.
2. **1910–1945 — belligerent interference with the mails.** Wartime censorship, not convention
   machinery. This is where the *bulk* of the corpus's postal material sits and it will contaminate
   any naive search.
3. **1932–34 and 1951 — Universal Postal Union membership as a recognition contest** (Manchukuo,
   then the People's Republic of China). Postal administration used as a proxy for statehood.
4. **After 1960 — near-silence.** 3 documents in the 1960s, 14 in the 1970s.

### Decade shape, with rates (raw counts alone would mislead badly here)

Numerator is a slightly wider union (CORE plus `postal administration`, `postal relations`,
`parcel post`, `postal money order`) = **425 documents in 172 volumes**. Denominator is that
decade's dated non-apparatus documents.

| decade | hits | dated non-apparatus docs | per 1,000 | top-volume share of the numerator |
|---|---|---|---|---|
| 1850s | 1 | 150 | 6.67 | 1 of 1 in frus1879 |
| 1860s | 27 | 11,250 | 2.40 | 7 of 27 in frus1863p2 |
| **1870s** | **32** | **5,798** | **5.52** | 5 of 32 in each of frus1871 / frus1875v01 / frus1878 / frus1879 |
| 1880s | 19 | 6,472 | 2.94 | 4 of 19 in frus1887 |
| 1890s | 10 | 9,712 | 1.03 | 3 of 10 in each of frus1893 / frus1898 |
| 1900s | 31 | 9,924 | 3.12 | 6 of 31 in frus1906p2 |
| 1910s | 93 | 30,359 | 3.06 | 17 of 93 in frus1915Supp |
| 1920s | 37 | 19,733 | 1.88 | 7 of 37 in frus1929v01 |
| 1930s | 60 | 39,196 | 1.53 | 14 of 60 in frus1934v03 |
| 1940s | 52 | 74,043 | 0.70 | 5 of 52 in frus1940v03 |
| 1950s | 41 | 42,296 | 0.97 | 8 of 41 in each of frus1951v02 / frus1951v03p2 |
| 1960s | 3 | 27,650 | 0.11 | 1 of 3 |
| 1970s | 14 | 22,259 | 0.63 | 3 of 14 |

The **1870s is the density peak**, at 5.5 per 1,000 against a corpus that is thin in that decade —
and it is *not* one negotiation: the top volume holds only 5 of 32. That is the Universal Postal
Union's founding decade (Bern 1874, Paris 1878) and it is genuinely well spread.
The 1910s raw peak of 93 is the **lowest-quality** cell in the table: it is mail censorship.

---

## 2. Read the editors' headings before you write a query — they reframe the question

I walked all 552 `volume_structures` records and kept every section title matching
`post(al|age|s?[- ]office)|mail|parcel` (script `/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer/02d9a891-c562-471b-845c-53aa054cd34e/scratchpad/c0d/runs/d1/headings2.py`; the SQL is
`SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id`). **37 headings
matched.** The distribution is the finding:

- **Exactly two** name the multilateral machinery, both in **frus1898**, both carrying **one
  document each**: *"Postal Union, adhesion of Great Britain to"* and *"Circulars to the United
  States legations—International Postal Congress"*.
- **One** names a bilateral treaty: frus1906p1, *"Parcel-post arrangement between Bolivia and the
  United States; transit through Peru"* (2 documents).
- **Fifteen** are wartime mail interference or censorship — the largest single compilation being
  frus1918Supp01v02, *"The Control of Spanish Ships in Latin American Trade—Censorship of Mails and
  Bunkering Regulations in Cuba"* (41 documents), and frus1916Supp, *"Interference with the mails by
  belligerent governments"* (37).
- **Four** are air-mail contract diplomacy, 1928–1945 (Chile, Mexico, Iceland, and *"Diplomatic
  support for American companies awarded mail contracts by the Post Office Department"*).
- **Three** are the 1943–45 Soviet relief-and-mail shipments (37 + 50 + 25 documents).

**The editors never compiled "postal conventions" as a subject.** The one place they did is
frus1898, and it is a single circular. Everything else you will find is scattered through
country-by-country compilations under headings about something else.

---

## 3. What the 19th-century material actually is (I read four documents whole)

| document | db chars | captured chars | whole? |
|---|---|---|---|
| frus1871/d4 | 74,640 | 74,640 | yes |
| frus1898/d1190b | 11,995 | 11,995 | yes |
| frus1952-54v03/d61 | 1,679 | 1,679 | yes |
| frus1863p2/d454 | 735 | 735 | yes |
| frus1951v02/d139 | 2,340 | 2,340 | yes |

Five retrieved whole, five quoted from. Reading SELECT and raw text are on disk at `/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer/02d9a891-c562-471b-845c-53aa054cd34e/scratchpad/c0d/runs/d1/reads/`.

**frus1871/d4 is the single most valuable document in the corpus for you.** Its header is
`[Report of the Postmaster General.]` and it is the Postmaster General's annual report printed in
full inside FRUS. Retrieved in this session, it says of 1870–71 that *"Postal conventions have been
negotiated with the republic of Ecuador and with the Argentine Republic"*, that
*"Negotiations are in progress with the governments of Denmark, Sweden, and Norway"*, that
propositions were submitted to Russia *"through its minister at Washington"*, and that
*"Negotiations have been renewed for a postal convention with France, but I regret to state that
there is little prospect of a favorable result."* One document gives you the whole negotiating
programme, the counterparties, and the transmission mechanism.

**frus1863p2/d454 shows the mechanism in miniature.** Seward to Morris at Constantinople,
26 January 1863: *"I have communicated to the Postmaster General the favorable reply of the Turkish
government to his proposition concerning reforms in international postal regulations."* State is the
transmission belt; the Post Office Department is the principal.

**frus1898/d1190b is the administration channel.** A Department circular to all legations notifying
them that the Orange Free State has adhered to *"the Universal Postal Convention signed at
Washington on June 15, 1897"*, reciting the franc/penny equivalents and the sixth-class quota of
International Bureau expenses. That is State acting as notifier for a multilateral instrument.

**frus1951v02/d139 shows the twentieth-century transformation.** A January 1951 circular telegram
on the Cairo UPU conference: the US Representative is named in the editors' own bracketed note as
**John M. Redding, Assistant Postmaster General**, and his instruction is to move that the UPU
*"postpone consideration Chi representation question until GA has taken action."* By 1951 the
postal union is an instrument of the China-recognition fight, and the Post Office Department
supplies the delegate.

---

## 4. Three false friends that will cost you a day each

**(a) The Postmaster General is a false friend for postal business.** 45 documents name him in the
header. Sixteen of them are in **frus1941v04**, and:

```sql
SELECT COUNT(*) FROM document_cache WHERE volume_id='frus1941v04'
  AND header LIKE '%Postmaster General%'
  AND (body_text LIKE '%postal%' OR body_text LIKE '%postage%' OR body_text LIKE '%parcel%');
--> 0        (of 16)
```

Zero of 16. Postmaster General Frank Walker was the Walsh–Drought back channel to Japan; the
documents are filed at decimal class 711.94 and concern Prince Konoye, not the mails.

**(b) Two of the terms your own question supplies are measuring the corpus, not the question.**
SQL `LIKE`, case-insensitive, non-apparatus documents; the "on-topic" set is the eight top CORE
volumes (frus1871, frus1878, frus1879, frus1875v01, frus1863p2, frus1906p2, frus1934v03, frus1898):

| term | on-topic | corpus | ratio |
|---|---|---|---|
| `postal` | 104 of 5,030 = 0.0207 | 1,244 of 307,359 = 0.0040 | **5.11** |
| `convention` | 381 of 5,030 = 0.0757 | 17,664 of 307,359 = 0.0575 | 1.32 |
| `negotiat` | 450 of 5,030 = 0.0895 | 64,378 of 307,359 = 0.2095 | **0.43** |
| `Department of State` (control) | 1,452 of 5,030 = 0.2887 | 92,870 of 307,359 = 0.3022 | 0.96 |

The control lands at 0.96, so the test works. `postal` is a real discriminator at 5.1×.
**`convention` at 1.32 and `negotiat` at 0.43 are useless** — every treaty is a convention, and
`negotiat` is actually *anti*-correlated with the 19th-century despatch volumes. Do not build a
query on either.

**(c) "Post" in a NARA series title means a diplomatic post.** The only four bundled lot files whose
titles match `post` are *Top Secret Foreign Service Post Files*, *Subject Files of Foreign Service
Posts* (×2) and *Central Subject and Officially Decentralized Files of Foreign Service Posts*.
None is postal.

---

## 5. Literal shares for every phrase count in this memo

House rule (a)/(b). Regex over `header + dateline + source_note + body_text`, whitespace-collapsed.
**Python `re` with `re.I`** throughout (not SQL `LIKE`) — one method for the whole family. Every
family had M ≤ 300, so these are **censuses of the whole hit list, not samples**. STRICT = single
spaces between the literal words; TOLERANT = each word allowed its inflections with
`[\s\-,\(\)\.]+` between them. Script `/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer/02d9a891-c562-471b-845c-53aa054cd34e/scratchpad/c0d/runs/d1/share.py`, output `/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer/02d9a891-c562-471b-845c-53aa054cd34e/scratchpad/c0d/runs/d1/shares.txt`.

| phrase | hits M | TOLERANT | STRICT |
|---|---|---|---|
| postal convention | 95 | **95 of 95 = 1.000** | 95 of 95 = 1.000 |
| Universal Postal Union | 67 | **67 of 67 = 1.000** | 67 of 67 = 1.000 |
| postal union | 105 | **105 of 105 = 1.000** | 105 of 105 = 1.000 |
| parcel post | 125 | **125 of 125 = 1.000** | 99 of 125 = 0.792 |
| Postmaster General | 273 | **273 of 273 = 1.000** | 209 of 273 = 0.766 |
| postal administration | 80 | **80 of 80 = 1.000** | 80 of 80 = 1.000 |
| international postal | 37 | **37 of 37 = 1.000** | 37 of 37 = 1.000 |
| postal treaty | 21 | **21 of 21 = 1.000** | 16 of 21 = 0.762 |
| postal congress | 5 | **5 of 5 = 1.000** | 5 of 5 = 1.000 |
| Post Office Department | 186 | **185 of 186 = 0.995** | 142 of 186 = 0.763 |

Every family is usable (all ≥ 0.995 tolerant). The strict/tolerant gaps are pure orthography:
`parcel-post` hyphenated, `Postmasters General`, `postal treaties`. The one tolerant miss is
frus1958-60v16/d56.

**A 1.000 share tests the stemmer, not the referent**, which is why §3 exists: I read documents to
establish that these phrases mean international postal conventions and not something else.

**A stemming artefact you must know about:** `"postal convention"` and `"postal conventions"`
return *byte-identical* results — 95 documents, 51 volumes, span 1862-11-21 to 1952-08-14 — because
porter folds them to one stem. Do not report them as two families. Likewise `"Berne"` and `"Bern"`
each return 3,158, and that number is a false friend of a different kind: Bern is the UPU's seat but
also the seat of a hundred arbitrations.

### Family reference table (docs / volumes / date span)

| phrase | docs | volumes | span |
|---|---|---|---|
| postal service | 201 | 112 | 1862-01-23 .. 1982-03-04 |
| Post Office Department | 186 | 87 | 1849-08-31 .. 1976-08-17 |
| Postmaster General | 273 | 128 | 1862-09-23 .. 1980-02-29 |
| parcel post | 125 | 65 | 1881-12-01 .. 1979-05-07 |
| postal union | 105 | 62 | 1875-02-04 .. 1979-10-23 |
| postal convention(s) | 95 | 51 | 1862-11-21 .. 1952-08-14 |
| money order | 91 | 60 | 1864-01-15 .. 1951-03-16 |
| postal administration | 80 | 47 | 1871-11-18 .. 1963-11-22 |
| Universal Postal Union | 67 | 40 | 1879-12-09 .. 1979-10-23 |
| international postal | 37 | 30 | 1861-10-22 .. 1950-04-03 |
| postal money order | 26 | 21 | 1870-01-18 .. 1951-03-16 |
| postal treaty | 21 | 16 | 1861-10-22 .. 1947-03-05 |
| postal arrangement | 18 | 14 | 1851-07-10 .. 1943-10-05 |
| postal agreement | 10 | 10 | 1919-07-29 .. 1977-05-16 |
| General Postal Union | 5 | 4 | 1875-02-04 .. 1947-03-05 |
| postal congress | 5 | 5 | 1878-03-08 .. 1908-04-25 |

Period vocabulary I also tested, so you know what is *not* there: `mail convention` **0**,
`ocean postage` **0**, `postal separation` **0**, `postal card convention` **0**, `letter postage`
**1**, `packet service` **1**, `postal bureau` **1**, `international postage` **2**,
`closed mail(s)` **10**, `franking privilege` **9**, `mail packet` **40**, `mail steamers` **278**.
`mail steamers` is a large adjacent literature about ocean-mail *carriage and subsidy* — a
different question from convention-making, and I have not counted it as yours.

---

## 6. Archival scope — two channels, never summed

### Channel: **came-from** (`document_sources`, one row per document)

**129 rows** for the 232 CORE documents. By citation form (a *form*, not a date): decimal 102,
structured 10, unrecognized 7, published 3, cfpf 3, named_series 2, lot_file 2.

The decimal classes are the real find. Glossed **only** through the bundled 1910–1949 schedule
(`decimal-class-labels.json`, the sole schedule it ships), and only for documents dated inside it:
the schedule composes as *class digit + country number + subject suffix*, class **8** is
"Internal Affairs of States", and its subject block **`.71` = Post**, with children
`.711` Laws and regulations, `.713` Rates. Postage, `.715` Parcel post, `.716` Money orders,
`.71086` Tampering with mail, `.71A` Postal adviser. So:

- **893.71 / 893.711** = China — Post (8 + 19 documents)
- **841.711** = Great Britain — Post: laws and regulations (6 in the CORE set; 107 corpus-wide)
- **891.711** = Iran — Post (6)
- **811.711** = United States — Post (24 corpus-wide)
- **399.10-UPU** — a dedicated decimal file for the Universal Postal Union (2 in CORE)

**This gives you a second, independent route into the corpus.** Searching the archival
classification rather than the text:

```sql
SELECT COUNT(*), COUNT(DISTINCT s.volume_id) FROM document_sources s
  JOIN document_cache d ON d.volume_id=s.volume_id AND d.document_id=s.document_id
 WHERE d.is_front_matter=0 AND d.is_editorial_note=0
   AND s.decimal_class GLOB '8[0-9][0-9].71*';
--> 325 | 46
```

**325 documents in 46 volumes — and the two routes barely intersect:**

| | documents |
|---|---|
| CORE text search | 232 |
| class-8 `.71x` archival | 325 |
| **in both** | **24** |

24 of 232, and 24 of 325. If you run only one of these you will miss most of the material. (The
archival route skews to censorship — its top volumes are frus1916Supp 33, frus1918Supp01v02 26,
frus1914Supp 20 — but it also recovers the 1930s Iran and China postal files the text search misses.)

**The `399.10-UPU` file is a continuous run in one volume.** `SELECT ... WHERE s.decimal_class LIKE
'%UPU%'` returns 20 rows, all in **frus1951v02**, documents d138–d181, January–April 1951, mostly
circular telegrams — the Cairo UPU congress and Chinese representation.

**The severe limitation, and it falls exactly where your question is densest:**

```sql
-- CORE documents having any document_sources row, by era
pre-1900   :  1 of 81
1900-1945  : 77 of 95
1946+      : 51 of 51
(undated)  :  0 of 5
```

**One of 81.** The nineteenth-century volumes carry essentially no archival apparatus —
`collection-usage-index.json` records frus1871 as having **4 source notes in the whole volume**.
For 1861–1899 FRUS will tell you what was printed and nothing about where it came from.

### Channel: **pointed-at** (`external_citations`, many rows per document)

**18 rows** for the 232 CORE documents, and **not one of them is postal** — the top classes are
835.452, 684.85, 611.95A241, 611.85. The editors' footnotes on postal documents point at unrelated
files. For the 325-document archival set the pointed-at channel has ~16 rows and they stay inside
the `.71x` block (893.711 ×4, 811.711 ×2, …).

**Rank nothing on this channel here.** Note also its structural limits: it holds no row before
1910-12-06, it stores the citation fragment rather than the sentence, and it carries only lot,
library and decimal anchors.

### Series resolution, and what the offline stack cannot reach

The 1951 UPU material sits in IO Bureau lot files, which resolve cleanly (creator headings from
`series-facts-index.json`, verified rather than assumed):

| lot | NAID | RG | NARA title | creator heading | entry | extent | span | access |
|---|---|---|---|---|---|---|---|---|
| 59D237 | 2103077 | 59 | Subject Files | Bureau of International Organization Affairs, Office of UN Political and Security Affairs | A1 1265 | 5 ft 8 in | 1945–1957 | Unrestricted |
| 60D512 | 16905055 | 59 | Country and Subject Files | Bureau of International Organization Affairs, Office of Dependent Area Affairs | P 469 | 5 ft 8 in | 1946–1958 | Restricted – Partly |
| 53D26 | 2108774 | 59 | Subject Files | Bureau of Inter-American Affairs, Office of the Assistant Secretary | A1 1130 | 6 ft 2 in | 1949–1953 | Unrestricted |
| 60D224 | 592873 | 59 | Records Relating to the US Delegation to the UN Conference on International Organization | Bureau of UN Affairs, Office of the Assistant Secretary | A1 503 | 11 ft 10 in | 1949–1950 | Unrestricted |

`M88` and `53D250`, both cited in frus1951v02, are **not in `central-files-index.json`** and I could
not resolve them offline.

**Three offline negatives, each checked rather than assumed:**

1. **RG 28 (Records of the Post Office Department) is entirely absent.** The 1,065 lot files in
   `central-files-index.json` reach exactly five record groups: **59 (985), 84 (57), 306 (17),
   353 (3), 43 (3)**. The one federal archive that would hold the Post Office Department's own
   negotiating files is outside everything this stack can see.
2. **No series creator in the bundle is a postal body.** I regexed all 397 creator headings in
   `series-facts-index.json` for `post(al|master|[ -]office)` — **zero matches**.
3. **Nothing postal is digitised.** `digitized-ranges-index.json` holds 624 ranges spanning
   **18 distinct decimal classes**: 131 and 131.1 (Visa Division reports of births), 133 and 133.1,
   and the 763.72x block (WWI). No `.71` class appears. *(My first containment test here was
   wrong — I compared full class numbers against within-class sub-number ranges and got 13 spurious
   hits. `/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer/02d9a891-c562-471b-845c-53aa054cd34e/scratchpad/c0d/runs/d1/digi.py` holds that bad output; it is not used above.)*

### A corpus-scoping negative is not a research negative — here is where to go instead

FRUS does not compile postal-convention negotiation, and its archival apparatus vanishes before
1900. But `central-files-index.json`'s `countrySeries` names the pre-1910 State Department series
that **do** hold it, all resolved at roll level:

- **Domestic Letters, NAID 568025, 272 rolls** — State's outgoing correspondence to domestic
  addressees, which is where every Seward-to-the-Postmaster-General letter of the kind quoted in
  §3 physically is. Fully digitized as microfilm.
- **Diplomatic Instructions, NAID 593313, 177 rolls** — the outgoing half of the negotiations
  frus1871/d4 lists (Ecuador, Argentina, Denmark, Sweden, Norway, Russia, France).
- **Notes to Foreign Missions, NAID 597272, 104 rolls** — the exchanges with ministers at
  Washington, the channel Russia's was conducted through.

Beyond that: **RG 28**, unreachable here, and the UPU's own International Bureau records at Bern,
which the 1898 circular shows the United States corresponding with directly.

---

## 7. Two more structural facts worth knowing before you search

**The editors never linked these documents to each other.**

```sql
-- cross-references whose source AND target are both in the CORE set, is_broken = 0
--> 0        (against 345 outbound references from CORE documents to anywhere)
```

Zero internal edges. The citation graph will not help you assemble this topic; there is no editorial
thread connecting a postal document in one volume to one in another.

**The subject taxonomy cannot reach the question at all.** `document-subject-index.json` ships
**491 subjects in 13 categories**. Regexing every subject name for `post|mail|telegraph|communicat`
returns exactly one: **"Military communication"**. There is no postal, mail, or communications
subject. Ignore `subject_tag_ids` (always NULL) and do not expect the Subjects axis to do any work
here. (The taxonomy's own provenance string calls its tags *"recall-oriented candidates rather than
ground truth"* from string matching, so this is not a close call.)

---

## 8. What I would actually search for

**For the negotiation question (1861–1899), where the corpus is richest and the apparatus poorest:**

1. Start at **frus1871/d4** and read it whole. It is 74,640 characters and it names the entire
   negotiating programme. Then work outward to the country volumes for each counterparty it lists.
2. Query `"postal convention"` (95 docs / 51 vols) and `"postal treaty"` (21 / 16) — both tolerant
   share 1.000 — and restrict to `volume_id < 'frus1900'`. Add `"postal arrangement"` (18 / 14),
   which reaches back to 1851.
3. Use **`Postmaster General` AND a postal term**, never `Postmaster General` alone (§4a).
4. Do **not** use `convention` or `negotiat` unqualified (§4b).

**For the multilateral machinery:** `"Universal Postal Union"` (67 / 40), `"General Postal Union"`
(5 / 4, and note it is the pre-1878 name — worth searching separately for exactly that reason),
`"postal congress"` (5 / 5, span 1878–1908). The 1898 Washington congress circulars in frus1898
are the densest single point.

**For administration as distinct from negotiation:** `"parcel post"` (125 / 65),
`"postal money order"` (26 / 21), `"postal administration"` (80 / 47), `"franking privilege"` (9).
The last of these gives you frus1952-54v03/d61, a clean small case of the Postal Convention of the
Americas and Spain being administered — whether UN delegates from signatory states inherit the
diplomatic franking privilege. (They do not; L/UNA, L/A and the Post Office Department concurred.)

**For the recognition strand, which I would treat as its own project:** the Manchukuo episode is
**29 documents** (`body_text LIKE '%Manchukuo%' AND body_text LIKE '%postal%'`), concentrated in
frus1932v04, frus1933v03 and frus1934v03, and conducted largely through the **US Minister in
Switzerland at Bern** — Wilson's despatches are the UPU channel. The 1951 China episode is the
`399.10-UPU` run in frus1951v02, d138–d181.

**What I would not do:** search `mail` or `mails` unqualified. That returns the censorship corpus,
which is large (the mail-interference family is 77 documents in 37 volumes, overlapping the CORE
set by only **3**), well-compiled, and about a different subject.

---

## 9. Things I did not do, so you can weigh what I did

- **No TEI work.** I have not counted spelling or hyphenation variants on any counting surface, have
  not separated footnote text from document text, and have published no density. `body_text`
  contains editorial footnotes, so all term frequencies above blend document and editor language and
  I have not attempted to unmix them. If you want a variant census — `parcel post` / `parcels post` /
  `parcel-post`, or `Postal Union` acronyms — that is a TEI job and this index cannot do it.
- **No person analysis.** `person_rollup` under-merges and `person_mentions` covers TEI-tagged
  mentions only; I did not scan any surname.
- **`digitized-ranges-index.json` cost me one wrong test**, recorded in §6 and in `queries.log`.
- **Thin cells to distrust:** the 1850s row (1 document), the 1960s row (3), `"postal congress"`
  (5), `"General Postal Union"` (5). None of these is thin because your library is partial — you
  have all 552 volumes — but each is thin enough that a single volume moves it.
- Two commands failed and are recorded rather than removed: a `document_subjects.name` query (no
  such column) and the first `collection-usage-index.json` accessor (its `k` field is a scalar key
  index, not a list).

Files on disk in this run directory: `report.md`, `queries.log`, `shares.txt`, `fams.json`,
`headings.py`, `headings2.py`, `share.py`, `jsonprobe.py`, `digi.py`, `usage.py`, `usage2.py`,
`lots.py`, and `reads/` (nine files: four documents captured with header/dateline/source and five
body-only captures used for the whole-capture check).
