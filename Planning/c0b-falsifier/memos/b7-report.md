# Scoping memo: refugees and displaced persons in the FRUS corpus

**To:** the historian
**Re:** what *Foreign Relations of the United States* (552 volumes, 316,839 documents in this index) will and will not give you on US refugee policy
**Date:** 2026-09-06

---

## 1. The short answer

The corpus holds a large, continuous, and unusually well-signposted record — **7,745 documents (2.4% of the corpus) use the word "refugee"**, spread across 497 of 552 volumes — but it is not one record. It is at least three, and they do not share a vocabulary, a decade, or a filing cabinet:

1. **Before roughly 1920, "refugee" in FRUS means *diplomatic asylum*** — people sheltering inside American legations during Latin American and Ottoman upheavals. This is consular and international-law material, not migration policy, and a keyword search will hand it to you mixed in with everything else.
2. **From 1922 to 1952 the corpus documents the invention of international refugee machinery**, and does so from inside — Greek resettlement finance, the Nansen certificates, the 1933 High Commission, Evian, Bermuda, UNRRA, the IRO. This is the densest and most self-aware stretch.
3. **After 1952 refugees become an instrument and a by-product of Cold War and regional crisis** — escapees from Eastern Europe, Palestine, Hungary, Cuba, Bangladesh, Indochina, Afghanistan. Density keeps climbing to the corpus's endpoint.

The most useful single thing I found is an archival fact, in §5 below: the State Department filed refugees under **"Calamities. Disasters."**

---

## 2. What I measured, and the curve

Refugee-word share of **dated** documents, five-year bins (per-document dates from `document_dates`, not volume midpoints):

| bin | dated docs | refugee docs | share | "displaced persons" |
|---|---|---|---|---|
| 1860–64 | 4,747 | 34 | 0.72% | 0 |
| 1875–79 | 2,520 | 68 | **2.70%** | 0 |
| 1890–94 | 4,686 | 98 | **2.09%** | 0 |
| 1910–14 | 8,834 | 67 | 0.76% | 0 |
| 1920–24 | 9,339 | 227 | **2.43%** | 0 |
| 1930–34 | 16,977 | 117 | 0.69% | 0 |
| 1935–39 | 22,225 | 580 | 2.61% | 0 |
| 1940–44 | 34,154 | 874 | 2.56% | 57 |
| 1945–49 | 41,526 | 1,153 | 2.78% | **396** |
| 1950–54 | 28,379 | 888 | 3.13% | 65 |
| 1955–59 | 18,142 | 645 | 3.56% | 8 |
| 1960–64 | 16,835 | 565 | 3.36% | 8 |
| 1965–69 | 13,024 | 442 | 3.39% | 6 |
| 1970–74 | 12,891 | 444 | 3.44% | 13 |
| 1975–79 | 10,384 | 543 | **5.23%** | 34 |
| 1980–84 | 4,152 | 278 | **6.70%** | 3 |
| 1985–89 | 1,971 | 61 | 3.09% | 1 |

Two things to notice. The **secular rise is real** — refugees go from under 1% of American diplomatic business to over 6% — and it is not an artifact of volume selection, because the denominator is the corpus's own dated output. But the **three 19th-century spikes are not what they look like**, and the 1985–89 fall is a publication artifact (see §8).

Concentration: the top 10 volumes hold 23.3% of all refugee documents, the top 50 hold 50.9%. Median non-zero volume has 7. Seventy-one volumes have 25 or more.

---

## 3. The pre-1920 trap: "refugee" means asylum in a legation

I chased the 1875–79 and 1890–94 spikes to their volumes and read the documents.

- **1875–79** is Haiti. `frus1875v02` supplies 31 of the 68. The top-ranked documents are Ebenezer Bassett's despatches from Port-au-Prince to Hamilton Fish about persons sheltered in the American legation.
- **1890–94** is Chile. `frus1891` supplies 49 of the 98 — Patrick Egan in Santiago after the civil war, including Wharton's instruction that Egan "furnish to the Department full details as to the number of refugees in other legations."

The editors' own section titles for this era confirm the sense, and they are worth reading as a list: *"Asylum to a political refugee"* (1896), *"Refusal of asylum to a Dominican"* (1899), *"Asylum in legations"* (1898), *"The rights of asylum and of temporary refuge"* (1912), *"Policy of the United States regarding asylum"* (1940), *"Project by Argentina for a multilateral convention on the right of asylum"* (1937).

**Consequence for your search design:** an undifferentiated `refugee` query over the 19th century returns Latin American revolutionary politics. If diplomatic asylum is your subject, this is a rich seam — 1,646 documents match `asylum`, and there is a distinct Inter-American treaty literature. If it is not, you need to exclude it explicitly rather than assume the word is stable.

---

## 4. The hinge: 1922–1924, Greece, and refugees as a credit problem

The first mass-displacement record in the modern sense is the Asia Minor catastrophe. `frus1923v02` holds 79 refugee documents; `frus1922v02` holds 61. The editors' section titles:

- *"Withdrawal of American relief organizations from operations in behalf of Greek refugees, and formation of the Refugee Settlement Commission"* (1923)
- *"Consent by the United States to the pledge of further securities by Greece for the Greek refugee loan of 1924"* (1924)
- *"Protests of the United States against Greek default in payment on the Refugee Loan of 1924"* (1932)
- *"Acceptance by the United States of certificates of identity issued by the League of Nations to Russian and Armenian refugees in lieu of passports"* (1924)

The archival citations are `868.48` and `868.51 Refugee Settlement Commission`. What the corpus shows here is the United States engaging displacement primarily as a **financial and documentary** question — loan security, default, identity papers — rather than as an admissions question. That framing is visible in the file numbers themselves and is, I think, the most under-argued thing in this part of the corpus.

The `Armenian/Russian (Nansen)` query peaks at 147 documents in volumes covering the 1910s; `Greek/Turkish exchange` at 86 in the 1920s.

---

## 5. The archival finding: refugees were filed under "Calamities. Disasters"

This is the result I would most want checked, because it is a claim about how the Department *thought*, evidenced by how it *filed*.

Of the 7,745 refugee documents, 7,027 carry a parsed source note. Grouping their decimal file numbers by **subject suffix** and comparing against the whole corpus:

| suffix | refugee docs | corpus-wide docs | meaning (1910–49 schedule) |
|---|---|---|---|
| **.48** | **1,047** | 2,265 | **Calamities. Disasters** |
| .00 | 699 | 30,656 | Political affairs |
| .BB | 294 | — | (UN conference series) |
| .01 | 159 | 5,640 | Government |
| .51 | 118 | 7,511 | Financial conditions |

`.48` is only the **12th** commonest suffix in the corpus at large, and the **1st** among refugee documents. Put the other way: **46% of every `.48` document in the entire corpus is a refugee document.**

And the file has a name. The Department created a titled subdivision, **`840.48 Refugees`** — class 8 (Internal Affairs of States) / country 40 (Europe) / subject .48 (Calamities. Disasters). It is cited by **757 documents in this corpus**, running from `frus1938v01` to `frus1949v09`, concentrated in:

```
frus1943v01  193      frus1945v02   46      frus1946v05  14
frus1944v01  160      frus1940v02   33      frus1941v01   9
frus1938v01  144      frus1942v01   32      frus1948v08   9
frus1939v02   92
```

Siblings exist: `861.48 Refugees` (USSR), `811.111 Refugees` (7 documents, the US visa-control class), `868.48` (Greece), `852.48` (Spain, 77 docs — Spanish Civil War), `800.48 FRP`.

**Why this matters practically:** if you are going to NARA, `840.48 Refugees` for 1938–49 is a single defined pull that reaches the heart of the Evian–Bermuda–War Refugee Board record. **Why it matters interpretively:** the Department's own classification put displaced people in the same drawer as earthquakes and hurricanes (`817.48 Earthquake of 1931`, `836.48 1930 Hurricane` sit adjacent). Refugee movement was administratively a *natural disaster*, not a *political status*. That is an argument you can make from the file numbers alone.

Repositories for refugee documents: Department of State 5,161; National Archives 458; then the presidential libraries — Carter 340, Nixon 278, Johnson 127, Kennedy 113, Ford 84, Eisenhower 74, Reagan 42; CIA 117.

---

## 6. The population-by-era map

Document counts by named population against volume coverage decade. **Read this as a locator, not a measure** — these are boolean co-occurrence queries (`refugee AND Cyprus` counts co-mention anywhere in a document, not aboutness).

```
population                        00s   10s   20s   30s   40s   50s   60s   70s   80s  TOTAL
Armenian/Russian (Nansen)         147    58    16    17     7     1     1     2          267
Greek/Turkish exchange             12    27    11    86     7     3    10               156
Spanish Civil War                   3          33    13     2                            51
Jewish (pre-1945)                   3     1    35   111    22     7    13               192
German expellees/Volksdeutsche      4     1    35    84    32     8     7     3         174
Displaced Persons (Europe)                          456   110    10    50     2         628
Palestine/Arab refugees                       3     214   525   209   103     2        1056
Korea                                             1  48   267    67   131    33         555
Hungary 1956                        1                3    42     5     4     1           60
China/Hong Kong                     3     5    49    44    28    23    51     2          214
Cuba                                7     2    25    25    34   208   166    26          529
Vietnam/Indochina                            1     5    29     5    92     5             142
East Pakistan/Bangladesh                          11     7   208     3                   229
Soviet Jewish emigration                       2              48    24                    74
Cyprus                              3          2    15    40    25    98     7           191
Africa (Horn/Southern)              2         27    22    85    59   174    51           421
Afghanistan                                    1    11    55     6   168    62           303
```

**Palestine is the largest single sustained thread** (1,056), and it never stops: it is the only population with substantial counts in every decade from the 1940s to the 1980s. The single densest volume in the corpus on this subject is `frus1949v06` (*The Near East, South Asia, and Africa*): **365 refugee documents out of 1,244, 29.3%**. The corpus names a *"Coordinator on Palestine Refugee Matters (McGhee)"* in 1949 and lists 24 UNRWA officials in its biographical apparatus.

**"Displaced persons" is a period term with a short half-life** — 628 documents total, 456 in 1940s volumes, then 110, then 10. If you search on it you are searching one decade.

---

## 7. The institutional spine, readable as an org chart

FRUS's biographical lists are an underused instrument. **76 distinct people across 43 volumes** have a role line naming refugees, displaced persons, migration, or asylum. Taking the earliest volume in which each office title appears gives a datable sequence:

| office | first appears in |
|---|---|
| War Refugee Board (Executive Director) | `frus1945Malta` |
| Refugees and Displaced Persons Staff, Bureau of UN Affairs | `frus1951v04p1` |
| Deputy Administrator for Refugee Relief | `frus1955-57v17` |
| Officer in Charge of Hungarian Refugee Operations | `frus1955-57v17` |
| Office of Refugee and Migration Affairs | `frus1961-63v25` |
| Ambassador at Large and Coordinator for Refugee Affairs | `frus1977-80v01` |
| Bureau of Refugee Programs | `frus1977-80v02` |
| Asst. Secretary for Population, Refugee and Migration Affairs | `frus1977-80v22` |

Alongside: *"Adviser on Refugees and Displaced Persons, Office of the Assistant Secretary for Economic Affairs"*, *"Assistant Legal Adviser for Human Rights and Refugees"*, 15 UNHCR officials, a *"Refugee Minister, Republic of Vietnam"*, and a West German *"Minister of Displaced Persons, Refugees and War Wounded."*

That table is the bureaucratic history of the Refugee Act of 1980 arriving in the record as a sequence of job titles.

The Cold War instrumentalization is stated outright in a chapter title — `frus1952-54v08`: *"United States Support of Refugees and Escapees from Eastern Europe; the President's Escapee Program; the Volunteer Freedom Corps; Other Exile Groups."* (`Escapee Program` = 40 documents; `escapee` = 143.)

And the 1970s turn is visible as density: the two highest-density volumes in the entire corpus are `frus1977-80v22` *Southeast Asia and the Pacific* (**132/339 = 38.9%**) and `frus1969-76v11` *South Asia Crisis, 1971* (**122/337 = 36.2%**).

---

## 8. What this corpus does **not** hold

This is the part I would want you to read before committing.

- **Refugee law is nearly absent.** The 1951 Convention / 1967 Protocol: **16 documents**. *Non-refoulement*: **2**. "Refugee Act": **4**. "Displaced Persons Act": 17. "Refugee Relief Act": 20. FRUS documents refugee *diplomacy and operations*, not refugee *law*. If your question is about legal status, admissions ceilings, or asylum adjudication, this corpus is a supplement, not a base.
- **Domestic implementation is out of frame by design.** FRUS is the Department of State's foreign-relations record. INS, Congress, and the courts appear only as they surface in diplomatic correspondence.
- **The 1980s are thin and the decline after 1984 is a publication artifact.** The `frus1981-88` volumes contribute 4,273 documents total (128 refugee) and `frus1989-92` barely begins; the latest coverage year anywhere in the manifest is 1991. Mariel appears in 55 documents, Haitian boat arrivals in 22 — real, but on a denominator too small to compare with the 1940s.
- **There is no "refugees" cluster in the corpus's own semantic map.** Of 179 unsupervised clusters over 314,483 documents, exactly one touches this vocabulary, and it is about *naturalize / naturalization / citizenship / emigrate* (877 documents). Refugee documents disperse into regional clusters (`vietnam, viet, kissinger, saigon`; `israel, israeli, arab, baath`). I read this as a finding rather than a tooling failure: **in FRUS, refugees are not a topic — they are an aspect of every regional crisis.** That is precisely why the subject is hard to see and worth writing about.

---

## 9. What I would actually search for

In rough order of yield:

1. `840.48 Refugees` as a **source-note** string, not a text search — it isolates 757 documents that the Department itself classified as refugee business, with no false positives. Then `868.48`, `852.48`, `861.48 Refugees`, `811.111 Refugees`.
2. The **editors' section titles** (`volume_structures`), not document headers. 206 section titles across 118 volumes match refugee vocabulary. This is the single best aboutness signal in FRUS and it costs one scan.
3. Period-specific institution names rather than the generic word: `Intergovernmental Committee on Refugees` (85), `UNRRA` (995), `International Refugee Organization` (104), `UNRWA` (329), `UNHCR` (157), `High Commissioner for Refugees` (159), `War Refugee Board` (116), `Evian` (87), `ICEM` (47), `Nansen`.
4. The **persons apparatus** for office titles — it dates the bureaucracy independently of the documents.
5. `refugee problem` (1,087) — a phrase with its own history; the shift in who is said to *have* the problem is trackable.
6. Only then the bare word, scoped to a decade.

---

## 10. How to check me

Every command is in `queries.log` in this directory, in order. The three heredoc scripts are preserved beside it: `agg.py` (per-volume/decade rollup), `struct.py` (section-title scan), `pops.py` (population matrix). The three `.tsv` files are the raw per-volume counts. Re-running `python3 agg.py .` and `python3 pops.py` reproduces §2, §6 and the density rankings exactly.

**Traps I hit, which you will hit too:**

- **The index is Porter-stemmed.** This is mostly lucky here: `refugee`/`refugees` stem to `refuge`, while the noun `refuge` stems to `refug` — so they *separate*. My 7,745 is checkable against a literal `LIKE '%refugee%'` over header+body, which returns **7,746**. The counts agree to one document.
- **But `internment` is poison.** It stems to `intern` and collides with *international* and *internal*: the query returns **70,585 documents**, 22% of the corpus. I nearly reported that as a finding. Any stemmed count you cannot reproduce with a literal `LIKE` should be treated as suspect.
- **FRUS headers are not titles.** Only 68 documents have "refugee" anywhere in the header field, because FRUS headers name sender and recipient (*"The Minister in the Netherlands (Gordon) to the Secretary of State"*). Header search will tell you this corpus has almost nothing on refugees. It has 7,745 documents.
- **The bundled subject index adds almost nothing.** Subject 40 ("Refugees", Human Rights) tags 5,885 documents, of which **5,762 (98%) already contain the word**; it contributes 123 new ones. Its own provenance string describes it as *"case-insensitive string matching of subject names and variants, NOT semantic analysis."* Treat it as a synonym list, not an independent judgment.
- **Two different time axes.** §2 uses real per-document dates; §6 uses volume coverage midpoints, because the population queries are cheaper per volume. They disagree at the margins. Where they disagree, trust §2.
- **§6 measures co-mention, not aboutness.** Do not quote those cells as counts of documents *about* a population.

---

## 11. One suggested framing

If you want a thesis to test, here is the one the evidence pushed me toward:

> The United States acquired a refugee policy twice — once in 1938–1952, when displacement was classified as a **disaster** (`.48`) and answered with relief, finance, and international organization; and again in 1975–1980, when it was reclassified as a **security and human-rights** problem and answered with an office, an Ambassador at Large, and a statute. The corpus lets you see the reclassification happening in the file numbers and the job titles before it appears in the prose.

The instruments for testing it are all in this index: `840.48 Refugees` for the first, the `frus1977-80v02` *Human Rights and Humanitarian Affairs* volume and the 1977–80 role lines for the second.
