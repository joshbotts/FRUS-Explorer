# Scoping memo: US participation in international sanitary conventions and quarantine practice in FRUS

**To:** the historian
**From:** corpus scoping pass over the local FRUS Explorer installation
**Date:** 2026-09-06
**Scope of effort:** ~55 queries against the SQLite search index, the TEI corpus, and the app's bundled JSON reference data. This is a scoping pass, not a finished study — everything below is checkable from `queries.log`.

---

## 1. Headline

The corpus holds a **real, continuous, and well-shaped record of this topic from 1861 to about 1948**, and then it stops. The record is unusual in one respect that will matter to you: FRUS prints not only the diplomatic correspondence but the **full texts of the conventions themselves**, as presidential proclamations. Five multilateral sanitary instruments are printed in full in these volumes.

After roughly 1951 the topic effectively vanishes. The World Health Organization is well represented in the post-war volumes but almost entirely as an *institution* — budget, assessments, specialised-agency politics, the Israel question — not as a quarantine regime. **The 1951 International Sanitary Regulations, the WHO instrument that superseded the whole convention system this corpus documents, do not appear in FRUS at all.** That absence is itself a finding: the sanitary-convention thread in FRUS is a story with a beginning and a middle but, in this source, no end.

The single largest trap is a homonym. **The Cuban naval "quarantine" of October 1962 accounts for roughly 28–31% of every `quarantine` hit in the corpus.** Any unfiltered search on the word will be dominated by it.

---

## 2. What I measured

Corpus baseline: **316,839 documents across 552 indexed volumes.**

### 2.1 Raw vocabulary counts (documents containing the term; FTS5, porter-stemmed)

| term | docs | | term | docs |
|---|---|---|---|---|
| sanitary | 1,331 | | public health | 977 |
| quarantine(s/d) | 863 | | plague | 816 |
| epidemic | 498 | | cholera | 250 |
| yellow fever | 169 | | public health service | 162 |
| world health organization | 156 | | bill(s) of health | 139 |
| sanitary regulations | 131 | | surgeon general | 111 |
| disinfect | 103 | | quarantine regulations | 99 |
| typhus | 99 | | pestilence | 95 |
| **sanitary convention** | **84** | | smallpox | 73 |
| marine hospital | 69 | | **international sanitary** | **65** |
| quarantine station | 38 | | fumigation | 36 |
| lazaretto | 30 | | sanitary bureau | 23 |
| sanitary conference | 23 | | quarantine laws | 23 |
| pan american sanitary | 17 | | sanitary code | 10 |
| national board of health | 8 | | hygiene publique | 3 |

A note on method that cost me a query: `fumigat` and `pestilen` both returned **zero**, because the porter stemmer maps *fumigation* → `fumig` and the query token `fumigat` → `fumigat`. Search whole words, not truncations, against this index.

### 2.2 The combined net

A union query over `quarantine(s) OR "sanitary convention" OR "sanitary conference" OR "sanitary code" OR "sanitary bureau" OR "sanitary council" OR "sanitary regulations" OR "bill(s) of health" OR lazaretto(s) OR cholera OR "yellow fever" OR "bubonic plague"` returns:

- **1,430 documents in 288 of 552 volumes** (1,414 after dropping 16 front-matter rows).

By volume decade (post-front-matter):

```
1860s 151   1870s  96   1880s 135   1890s 101   1900s 130
1910s  99   1920s 110   1930s 139   1940s  82   1950s  36
1960s 308   1970s  18   1980s   9
```

The 1960s spike is not the topic. Of 279 `quarantine` hits in 1961–63 volumes, **265 also mention Cuba, Soviet, or missile**; only 23 co-occur with any health or agricultural word. Corpus-wide, 243 of the 863 `quarantine` hits co-occur with *missile*, *blockade*, or *Khrushchev*. Filter `volume_id NOT LIKE 'frus1961-63%'` for any quantitative work.

### 2.3 Precision, honestly

I drew a **random sample of 20** hits from the broad net (`random.seed(7)`) and read the matched context of each. My classification:

- **~8–10 genuinely about sanitary or quarantine policy** (Spain's quarantine of US vessels 1867; the Alexandria quarantine board 1932; cholera precautions in Chile 1887; Fish's 1874 reply to Austria; the 1926 convention and Soviet recognition; Haitian bills of health 1902; British animal quarantine at Glasgow 1896).
- **~5 disease as background** — yellow-fever relief subscriptions, typhus reporting from Constantinople, a servant's cholera in a Paraguay deposition. Real epidemics, no policy content.
- **~4–5 homonyms or boilerplate** — three Cuban-missile documents, one "quarantine Peron" used as political metaphor (frus1961-63v12 d193), John Surratt held at the Alexandria "quarantine grounds" as a *place*, and quarantine dues in the standard tonnage-and-harbour-charges clause of a 1937 commercial treaty with Siam.

**Call it roughly 45–50% precision on the broad net.** That is workable but you should not report counts from it without saying so.

---

## 3. The best finding aid in this corpus is not full-text search

FRUS volumes of the 1860–1940 era are organised into named topical compartments under each country heading. Those headings are stored in the index (`volume_structures`), and walking them yields **45 compartments** whose titles name this subject directly. This is the closest thing to an editorial index of the topic, and it is far higher precision than any keyword query. The full list, chronologically:

**Multilateral conventions and organisations**
- 1904 · *International sanitary convention* (frus1907p1)
- 1905 · *International sanitary convention between the Argentine Republic, Brazil, Paraguay, and Uruguay*
- 1906 · *Sanitary convention of 1905*
- 1907 · *Third International Sanitary Convention, Mexico City, December 2–7, 1907*
- 1908 · *Arrangement … for the establishment of the International Office of Public Health*
- 1909 · *Fourth Pan-American Sanitary Conference*; *Fourth International Sanitary Convention*; *Sanitary convention between the United States and other powers*
- 1912 · *Ninth International Congress of Hygiene and Demography*
- 1913 · *Fourth International Congress on School Hygiene*
- 1923 · *Approval by the United States of a project for cooperation between the International Office of Public Health and the Health Commission of the League of Nations*
- 1924 · *Sanitary convention between the United States and other American Republics, signed November 14, 1924*
- 1926 · *Convention … revising the international sanitary convention of January 17, 1912*
- 1927 · *Additional protocol … amending the Pan American sanitary convention*
- 1938 · *Participation of the United States in the International Sanitary Conference, Paris, October 28–31, 1938*

**Quarantine administration abroad**
- 1924 · *Sanitary Commission for Turkey* (American representative, consultative capacity)
- 1928 and 1932 · *Appointment of an American representative on the International Quarantine Board at Alexandria*
- 1929 · *Arrangement … concerning quarantine inspection of vessels entering Puget Sound … or the Great Lakes* (Canada)
- 1930 · *Jurisdiction for quarantine purposes over American merchant vessels in Chinese ports*
- 1933 · *Reservation of American rights with respect to certain measures in the French Zone of Morocco*

**Sanitation as an instrument of intervention/administration**
- 1904 · *Sanitary conditions in Cuba*; *Sanitary conditions on the Isthmus of Panama*
- 1905 · *Sanitary conditions of the Isthmus of Panama*
- 1907 · *Improvement of Sanitary Conditions*
- 1911 · *The plague in Manchuria*
- 1918 · *Proposed repatriation of sanitary personnel*
- 1920 · *Assistance to Poland in combating typhus*
- 1929 · *Appointment of Dr. Howard F. Smith of the United States Public Health Service as Chief Medical Adviser to the Republic of Liberia*
- 1930 · *Interest of the Department of State in sanitary reforms for Liberia*

**Quarantine as a grievance — in both directions**
- 1895 · Germany, *Protest against immigration and quarantine laws* (against the US)
- 1900 · Argentine Republic, *Interference with official duties of foreign representatives in matters of quarantine and bills of health*
- 1900 and 1901 · Japan, *Alleged discrimination in the United States against Japanese in the matter of quarantine against bubonic plague*

**Animal and plant sanitary regimes**
- 1913 · *Plant quarantine act*
- 1928 · *Convention … safeguarding livestock interests through the prevention of infectious and contagious diseases* (Mexico)
- 1933 · *Representations by Argentina against sanitary restrictions on importation into the United States of Argentine meats*
- 1935 · *Unperfected sanitary convention between the United States and Argentina, signed May 24, 1935*
- 1940 · *Interest of the Argentine Government in obtaining the ratification by the United States of the Sanitary Convention of 1935*
- 1946, 1947, 1948 · *Joint United States–Mexican campaign against foot-and-mouth disease*

That last cluster is the second trap. **"Sanitary convention" in FRUS after about 1928 usually means animal health, not human quarantine.** Of the 84 documents containing the phrase, a large block (frus1933v04, 1935v03/v04, 1936v05, 1937v05, 1938v05, 1939v05, 1940v05, 1941v06) is the Argentine beef and foot-and-mouth dispute. Related counts: `foot-and-mouth OR hoof and mouth OR aftosa` = 80 documents; `trichina/trichinosis/trichinae` = 117, concentrated in frus1883 (38) and frus1881 (33) — the European prohibitions on American pork, where "regard to the public health" was the stated ground for what Washington read as protectionism. `sanitary AND (cattle OR meat OR livestock OR animals)` = 397 documents.

---

## 4. The narrative the documents actually support

I read enough full text to sketch the arc. These are the documents I would start from.

**a. FRUS begins after the sanitary conferences do.** The series starts in 1861; the first two International Sanitary Conferences (Paris 1851, 1859) predate it. Your record begins mid-stream.

**b. A homonym at the very start.** `frus1864p4 d434` (Fogg to Seward, Berne, 6 August 1864) reports his instruction to attend "in an unofficial manner" the "International Sanitary Congress" at Geneva. That is the **Geneva Convention conference on the wounded in war** — the Red Cross, not epidemics — and Fogg's letter turns on the US Sanitary Commission. Do not count it as a sanitary-convention document.

**c. Constantinople 1866.** `frus1866p2 d205` (Morris to Seward, 23 December 1865) transmits Aali Pasha's note: the Porte has adhered to the French proposal for "an international sanitary conference for the purpose of ascertaining and pointing out the precautionary measures to be taken against the cholera," and invites the United States to send delegates. The note is careful that the conference "is not at all of a diplomatic character, and is composed of competent men."

**d. Vienna 1874 — the US accepts and then fails to appear.** This is the sharpest short episode in the corpus and it sits in four documents in one volume:
- `frus1874 d25` (Fish to Baron Lederer, 30 April 1874): the US "will be disposed to take part … and will in that event probably be represented by a representative from the office of the Surgeon-General of the Army."
- `frus1874 d26` (Lederer to Fish, 16 June 1874): the formal Austrian invitation, arguing for "obligatory arrangements" and "perfect conformity" in measures, explicitly to reduce the "disturbances in commercial transactions" that inconsistent quarantines produce.
- `frus1874 d20` (Delaplaine to Fish, Vienna, 17 July 1874): the conference has opened without an American; the presiding officers have asked him why.
- `frus1874 d21` (Fish to Delaplaine, 21 August 1874): the explanation — the Austrian note arrived at the Department on 24 June for a conference that opened 1 July.

**e. Washington 1881 — the US convenes one of its own.** `frus1880 d4` (circular to the diplomatic officers, 30 July 1880) is the instrument: "in pursuance of a joint resolution of Congress which was approved on the 14th of May last, the President has determined to call an international sanitary conference to meet at Washington," inviting "the several powers having jurisdiction of ports likely to be infected with yellow fever or cholera," with the object of "an international system of notification." The outcome is reported in Arthur's annual message, `frus1881 message-of-the-president`: the conference sat from early January to March 1881; "Although it reached no specific conclusions affecting the future action of the participant powers, the interchange of views proved to be most valuable"; it did adopt a standard **bill of health**, which the National Board of Health then prescribed. **Note carefully:** the message says "The full protocols of the sessions have been already presented to the Senate" — i.e. the proceedings are *not* in FRUS. FRUS 1881 contains no compartment on the conference. What is filed under "sanitary" in that volume is the European pork prohibitions.

**f. The convention texts the corpus does print.** These are the payload:

| document | what it is | body chars |
|---|---|---|
| `frus1926v01 d116` | Convention revising the International Sanitary Convention of 17 Jan 1912, Paris, 21 June 1926 | 122,539 |
| `frus1907p1 d338` | Proclamation of the **International Sanitary Convention, Paris, 3 December 1903** (20 signatories, French text with translation) | 121,888 |
| `frus1909 d611` | Proclamation of the **Washington Convention of 14 October 1905** (US + 10 American republics) "providing measures to guard the public health against the invasion and propagation of yellow fever, plague and cholera" | 36,391 |
| `frus1924v01 d219` | **Pan American Sanitary Code**, Habana, 14 November 1924, Treaty Series No. 714 (18 republics) | 34,268 |
| `frus1908 d468` | Proclamation of the **Rome Arrangement of 9 December 1907** establishing the *international office of public health* under Article 181 of the 1903 convention | 11,040 |
| `frus1935v04 d318` | Sanitary Convention with Argentina, 24 May 1935 (unperfected) | 6,187 |
| `frus1927v01 d238` | Additional Protocol, 19 October 1927, amending the Pan American Sanitary Convention | 3,892 |

Also present: `frus1926v01 d117–d119`, three separate *procès-verbaux* of the deposit of ratifications.

**Not printed:** the Paris convention of 17 January 1912 itself. Both `frus1926v01` and `frus1928v02 d756` cite it out to *Malloy, Treaties 1910–1923, vol. iii, p. 2972*. If the 1912 instrument is central to your argument, this corpus will point at it rather than give it to you.

**g. The last multilateral episode: Paris, October 1938.** `frus1938v01 d927` is the Egyptian aide-mémoire: the object of the congress is "the abolition of the Maritime Sanitary and Quarantine Council," which after the end of the capitulations "is in flagrant conflict with the sovereignty of Egypt and constitutes a blow to her dignity." `frus1938v01 d930` (Wilson from Paris, 3 November 1938) reports that **Surgeon General Hugh S. Cumming (ret.), US Public Health Service** represented the United States among 57 delegates, 24 of them plenipotentiaries. The Alexandria board thread runs back through `frus1932v02 d469` and `frus1928v02 d756` (which shows the US pressing since 1925 to be seated on it).

**h. Quarantine as a sovereignty question — the richest analytic seam.** Three episodes, all of the same shape and none of them about disease:
- **Japan 1879.** `frus1879 d328` (Bingham, 18 August 1879): British and German ministers "deny the power of His Imperial Japanese Majesty's Government to declare and enforce a quarantine in Japanese waters over the vessels of their respective countries" — extraterritoriality against public health. Bingham transmits the whole correspondence. `frus1879 d323` gives the cholera mortality tables (31,759 cases, 18,017 deaths to 11 July).
- **Argentina 1900.** `frus1900 d1–d2`: the Argentine sanitary decree of 24 January 1900 would constrain what US consuls may certify; Hay's reply is flat — "The consul's duty under the law where an epidemic prevails is to notify his Government and the vessel … no matter what conditions a foreign government may impose," on pain of a $5,000 penalty for sailing without a bill of health.
- **China 1930.** A 15-document compartment, `frus1930v02 d397, d588–d601`, on "Jurisdiction for quarantine purposes over American merchant vessels in Chinese ports" (Cunningham at Shanghai, Johnson at Peiping).

And the mirror image, where the United States is the respondent: Germany's 1895 protest against US immigration and quarantine laws (frus1895p1), and Japan's 1900–01 protest against "discrimination … in the matter of quarantine against bubonic plague" — the San Francisco plague measures.

**i. Manchurian plague, 1911.** An 11-document compartment (`frus1911 d40–d57`) of US–Russia–China exchanges. `frus1911 d41` (State to the Russian Ambassador, 20 January 1911) reports southbound rail travel prohibited below the Great Wall and "a quarantine station in charge of foreign physicians … established at Shan-hai Kuan."

---

## 5. Archival routes (for follow-on work at NARA)

For the 1910–49 decimal era the corpus's own source notes give you the file numbers, decoded against the app's bundled classification schedule:

- **Class 5 = Congresses and Conferences.** The multilateral health files appear as `512.4-A` (frus1923v01, 6 documents — League/OIHP cooperation), `512.4-B` (frus1926v01, 3 — the 1926 Paris revision), `512.4B3` (frus1938v01, 4 — the 1938 Paris conference), `512.4A1A1` (frus1944v02, 3 — UNRRA). **`512.4` is the file series to request.**
- **Class 8 = Internal Affairs of States**, suffix `12` = *Public health*, `124` = *Hygiene and sanitation*, `1246` = *Hygiene of vessels and aircraft*, `124A` = *Sanitary engineer*. Across all 190,419 classed source rows in the corpus, only **163 documents** carry an `8xx.12*` file number, and they are concentrated exactly where the compartments said: Liberia `882.124a`/`882.124A` (39 + 22), Ecuador `822.124` (37), Peru `823.124` (15), China `893.12` (15), Egypt `883.12` (14), Colombia `821.12` (5), Turkey `867.12` (4).
- A bilateral oddity worth knowing: the US–Argentina sanitary convention correspondence is filed in the *political relations* class as **`711.359 Sanitary/…`** — the suffix is literally the word.
- Repository distribution across the topical hit set: Department of State 480, Kennedy Library 85 (that is the Cuban quarantine again), National Archives 25, Nixon Presidential Materials 25.

---

## 6. Where the app's own browse axes will *not* help you

Two negative results worth having before you spend time in the interface:

1. **The bundled subject taxonomy has no health category.** `document-subject-index.json` carries 491 subjects in 13 categories (Foreign Economic Policy 122, Global Issues 52, Arms Control 49, Warfare 49, Bilateral Relations 47, …). Not one subject name matches *health*, *sanitary*, *disease*, *epidemic*, *quarantine*, *medical*, *plague*, or *cholera*. The nearest neighbours are "Humanitarian relief" (119 docs), "Narcotics" (631) and "Refugees" (5,885). Browsing by subject cannot reach this topic.
2. **The semantic map nearly agrees with the compartments.** Of 179 clusters in `semantic-map-index.json`, exactly one — cluster 140, 510 documents, distinctive terms `picul, paladini, gendrot, cholera` — is health-adjacent, and its era histogram is **302 / 206 / 2**: the third era is essentially empty. An unsupervised clustering of the corpus independently confirms that this vocabulary is a pre-1945 phenomenon.

---

## 7. Corpus-integrity notes you should have

- The TEI directory holds **694 `.xml` files but only 552 are indexed**. I checked the 142 extras: every one is a metadata stub of 2.3–12 KB with no body text (median 2,483 bytes), and **none contains any sanitary/quarantine string**. They are not hidden content. Among them, unfortunately, are `frus1861-99Index.xml` and `frus1900-18Index.xml` — the consolidated FRUS general indexes, which reduce to 540 and 401 characters of text respectively. **There is no usable consolidated index in this installation**; do not go looking for one.
- I spot-checked the index against the source: `frus1907p2.xml` contains 69 case-insensitive "sanitary" matches, `frus1926v01.xml` 221, `frus1938v01.xml` 26, and the chapter heading "Third International Sanitary Convention" is present verbatim in the TEI. The index is faithful for this topic.
- Front matter and abbreviation lists inflate keyword counts, especially for `world health organization`, where a large share of volume-level hits are "List of Abbreviations" pages. `document_cache.is_front_matter` lets you drop them.

---

## 8. What I would search, in order

1. **Start with the 45 compartment headings in §3, not with keywords.** They are the editors' own index of the topic and they are ~100% precise. Pull the compartments whole.
2. Then the seven printed convention texts in §4(f), plus `frus1926v01 d117–d119` for the ratifications.
3. Then the four-document Vienna 1874 episode and the two-document Washington 1881 episode. Those are the participation story in miniature.
4. For the sovereignty argument: `frus1879 d323–d332` (Japan), `frus1900 d1–d2` (Argentina), `frus1930v02 d588–d601` (China), plus the two compartments where the US is the accused (Germany 1895, Japan 1900/1901).
5. Only then run keywords, and run them **excluding `frus1961-63*`**. The single most useful reading list is the per-volume ranking of the combined net with that exclusion:
   `frus1879` 28 · `frus1900` 26 · `frus1867p1` 25 · `frus1883` 23 · `frus1867p2` 23 · `frus1896` 22 · `frus1881` 22 · `frus1865p3` 22 · `frus1895p1` 21 · `frus1888p1` 21 · `frus1904` 20 · `frus1888p2` 19 · `frus1866p2` 19 · `frus1887` 18 · `frus1878` 18 · `frus1929v03` 17 · `frus1930v02` 15 · `frus1928v02` 15 · `frus1868p2` 15 · `frus1930v03` 14
6. Search `512.4` in source notes to find conference correspondence that the keyword net misses.

---

## 9. Caveats on what I did not do

- I did not read whole documents beyond the first 1,000–1,800 characters, except where quoted. Every quotation above is from text I read directly.
- I did not verify that the compartment list is *complete* — it is the set of structural headings matching a keyword pattern, so a compartment titled, say, "Health conditions in ___" without any of my keywords would be missed. `epidemic`, `hygien`, `public health`, `plague`, `cholera`, `yellow fever` were all in the pattern, so I think the gap is small, but I did not measure it.
- The precision estimate in §2.3 rests on one 20-document sample. It is indicative, not a measurement.
- I did not attempt to distinguish "US ratified" from "US signed" from "US attended" systematically. The corpus supports that distinction — the 1935 Argentine convention is explicitly labelled *unperfected*, and the 1926 ratification procès-verbaux are printed — but tracing adherence for every instrument would be a second pass.
- **The one thing I would most want checked by someone who knows the period:** whether the absence of the 1892 Venice, 1893 Dresden, 1894 Paris and 1897 Venice conventions from this corpus reflects genuine US non-participation (which is my reading, since the US did not accede to them) or an editorial gap in FRUS for those years. I found no FRUS compartment for any of the four, and the 1890s volumes' "sanitary" content is almost entirely the pork and cattle disputes.
