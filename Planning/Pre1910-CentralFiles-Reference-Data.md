# Pre-1910 Central Files — Reference Data Collection

Companion to `BigPicture-Pre1910-CentralFiles.md`. Ten manually-traced documents:
each entry records how a FRUS document was located in the digitized Central Files in
the NARA Catalog. This set drives the classifier design, seeds the geographic alias
table, and becomes the acceptance test fixture (target: the app reproduces your
roll-level link, or lists it among alternates, for ≥8 of 10).

## How to fill this in

- Copy values exactly as they appear (catalog titles, FRUS headings, dateline text) —
  the string formats are themselves the data being collected.
- A full `catalog.archives.gov/id/...` URL is enough anywhere a NAID is asked for.
- Leave a field blank if unknown; write `n/a` if it doesn't apply.
- **Failed or painful lookups are at least as valuable as clean ones** — if a trace
  dead-ended or needed several wrong-roll attempts, include it and say why.

## Coverage checklist (ideal mix — adjust to what you have)

- [ document 4 ] Diplomatic despatch, high-volume country (e.g. Great Britain, Mexico, China)
- [ document 5 ] Diplomatic despatch, low-volume country
- [ document 1 ] Diplomatic instruction (Washington → post)
- [ document 2 ] Note **from** a foreign mission in Washington
- [ document 3 ] Note **to** a foreign mission in Washington
- [ document 8 ] Consular despatch (post city)
- [ these are paraphrased in FRUS, so difficult to look up ] A telegram (any series)
- [ document 9 ] An enclosure printed in FRUS (located via its covering despatch)
- [ document 6 and document 7 ] Numerical File document, 1906–1910 ("File No." citation) — ideally two, one with a sub-document number like `5275/2`
- [ ] One hard/failed lookup, if available

## Field definitions

| Field | What to record |
|---|---|
| FRUS volume | Volume ID as in the app/manifest, e.g. `frus1895p1` |
| Document | Printed number ("No. 769") and/or TEI `xml:id` (e.g. `d1`) if you have it |
| Permalink | history.state.gov URL for the document |
| Heading | As printed, e.g. "Mr. Jones to Mr. Hay" |
| Dateline | As printed, e.g. "Legation of the United States, Buenos Ayres, February 3, 1900" |
| Date | ISO if possible, e.g. `1900-02-03` |
| Component | Which Central Files component you concluded it's in (Despatches / Diplomatic Instructions / Notes from Foreign Missions / Notes to Foreign Missions / Consular Despatches / Numerical File / …) |
| Classification cue | What told you — dateline? salutation? chapter? prior knowledge of the correspondents? |
| Country / post | The geographic key you searched under (e.g. "Argentina" or post city "Amoy") |
| Microfilm pub. | e.g. `M69`; roll number if known |
| Series URL | Catalog URL/NAID of the parent series you started from |
| File-unit URL | Catalog URL/NAID of the country/post-level record |
| Roll (item) URL | **The final catalog link you used for page-by-page review** |
| Roll title | The item title exactly as shown in the catalog (date/case range format matters) |
| Found at | Frame/JPEG number or consolidated-PDF page where the document appears |
| Match quality | exact / enclosure of a covering despatch / extract / variant text / not found |
| Friction notes | Wrong-roll first guesses, filed-by-receipt-date drift, name variants, docket annotations that confirmed the match, anything confusing |
| Time spent | Rough minutes for the whole trace (optional — baseline for measuring the feature's value) |

---

## Worked example (illustrative)

Real FRUS metadata; **NARA values below are placeholders — replace with a real trace.**

| Field | Value |
|---|---|
| FRUS volume | `frus1900` |
| Document | No. 769 (`d1`) |
| Permalink | https://history.state.gov/historicaldocuments/frus1900/d1 |
| Heading | Mr. Jones to Mr. Hay |
| Dateline | Legation of the United States, Buenos Ayres, February 3, 1900 |
| Date | 1900-02-03 |
| Component | Despatches (diplomatic) |
| Classification cue | Dateline names the U.S. legation at a foreign capital; addressee is the Secretary of State |
| Country / post | Argentina |
| Microfilm pub. | M69, roll 30 *(placeholder)* |
| Series URL | https://catalog.archives.gov/id/603720 |
| File-unit URL | *(placeholder — Argentina despatches file unit)* |
| Roll (item) URL | *(placeholder — roll covering 1899–1900)* |
| Roll title | *(placeholder — copy exactly, e.g. "Roll 30, Jan. 2, 1899–Dec. 31, 1900")* |
| Found at | *(placeholder, e.g. frame 412 / PDF p. 410)* |
| Match quality | exact |
| Friction notes | *(placeholder)* |
| Time spent | *(placeholder)* |

---

## Document 1

| Field | Value |
|---|---|
| FRUS volume | `frus1863p1` |
| Document | No. 644. (`d229`) |
| Permalink | https://history.state.gov/historicaldocuments/frus1863p1/d229 |
| Heading | Mr. Seward to Mr. Adams. |
| Dateline | Department of State, Washington, July 6, 1863. |
| Date | 1863-07-06 |
| Component | Diplomatic Instructions |
| Classification cue | Dateline names the Department of State; addressee (Adams) is U.S. minister in London |
| Country / post | Great Britain |
| Microfilm pub. | M77, Roll 77 |
| Series URL | https://catalog.archives.gov/id/593313 |
| File-unit URL | n/a |
| Roll (item) URL | https://catalog.archives.gov/id/149311973 |
| Roll title | Volume 18: Great Britain: Aug. 17, 1861 - Sept. 2, 1863 |
| Found at | frame 294 |
| Match quality | exact |
| Friction notes | no separate per-country file units in the Diplomatic Instructions series. instead, recipients are segmented at the level of rolls in the series. |
| Time spent | 25 minutes |

## Document 2

| Field | Value |
|---|---|
| FRUS volume | `frus1894` |
| Document | (`d815`) |
| Permalink | https://history.state.gov/historicaldocuments/frus1894/d815 |
| Heading | Dr. Lobo to Mr. Gresham. |
| Dateline | Legation of Venezuela, Washington, October 26, 1893. |
| Date | 1893-10-26 |
| Component | Notes from Foreign Missions |
| Classification cue | Dateline names the Venezuelan legation in Washington |
| Country / post | Venezuela |
| Microfilm pub. | T93, Roll 7 |
| Series URL | https://catalog.archives.gov/id/594363 |
| File-unit URL | https://catalog.archives.gov/id/183303942 |
| Roll (item) URL | https://catalog.archives.gov/id/188287901 |
| Roll title | Apr. 19, 1893-Mar. 28, 1896 |
| Found at | frame 69 |
| Match quality | exact, but in spanish |
| Friction notes | NARA Catalog website delays and failures. also document printed in FRUS was an english translation of the original document in spanish that is preserved at NARA |
| Time spent | 25 minutes |

## Document 3

| Field | Value |
|---|---|
| FRUS volume | `frus1878` |
| Document | (`d412`) |
| Permalink | https://history.state.gov/historicaldocuments/frus1878/d412 |
| Heading | No. 407. Mr. Evarts to Dr. Aceval. |
| Dateline | Department of State, Washington, November 13, 1878. |
| Date | 1878-11-13 |
| Component | Notes to Foreign Missions |
| Classification cue | Dateline names the Department of State and previous document (frus1878/d410) identifies recipient as Paraguayan representative at legation in Washington |
| Country / post | Paraguay |
| Microfilm pub. |  M99, Roll 98 |
| Series URL | https://catalog.archives.gov/id/597272 |
| File-unit URL | n/a |
| Roll (item) URL | https://catalog.archives.gov/id/216926854 |
| Roll title | Uruguay and Paraguay: July 7, 1834 - June 26, 1906 |
| Found at | frame 76 |
| Match quality | exact |
| Friction notes | Paraguay combined with Uruguay on roll and documents in Paraguay section of roll are not in chronological order |
| Time spent | 25 minutes |

## Document 4

| Field | Value |
|---|---|
| FRUS volume | `frus1905` |
| Document | No. 210 (`d544`) |
| Permalink | https://history.state.gov/historicaldocuments/frus1905/d544 |
| Heading | Minister Griscom to the Secretary of State. |
| Dateline | American Legation, Tokyo, March 14, 1905.|
| Date | 1905-03-014 |
| Component | Diplomatic Despatches |
| Classification cue | To the Secretary of State from an American Legation |
| Country / post | Japan/Tokyo |
| Microfilm pub. | M133, Roll 80 |
| Series URL | https://catalog.archives.gov/id/603720 |
| File-unit URL | https://catalog.archives.gov/id/5716479 |
| Roll (item) URL | https://catalog.archives.gov/id/188401761 |
| Roll title | Mar. 4, 1905-Aug. 31, 1905 |
| Found at | frame 101 |
| Match quality | near exact |
| Friction notes | minor editorial changes in document printed in FRUS |
| Time spent | 15 minutes |

## Document 5

| Field | Value |
|---|---|
| FRUS volume | `frus1876` |
| Document | (`d311`) |
| Permalink | https://history.state.gov/historicaldocuments/frus1876/d311 |
| Heading | No. 302. Mr. Rublee to Mr. Fish.|
| Dateline | Legation of the United States, Berne, September 28, 1875. (Received October 14.) |
| Date | 1875-09-28 |
| Component | Diplomatic Despatches |
| Classification cue | To the Secretary of State from an American Legation |
| Country / post | Switzerland/Berne |
| Microfilm pub. | T98, Roll 11 |
| Series URL | https://catalog.archives.gov/id/603720 |
| File-unit URL | https://catalog.archives.gov/id/177380756 |
| Roll (item) URL | https://catalog.archives.gov/id/189376306 |
| Roll title | July 2, 1675-Dec. 18, 1876 |
| Found at | frame 93 |
| Match quality | exact |
| Friction notes | some roll titles in file unit have date types (1875 mistakenly identified as 1675 in roll title) |
| Time spent | 15 minutes |

## Document 6

| Field | Value |
|---|---|
| FRUS volume | `frus1907p2` |
| Document | (`d246`) |
| Permalink | https://history.state.gov/historicaldocuments/frus1907p2/d246 |
| Heading | Ambassador Thompson to the Secretary of State. |
| Dateline | American Embassy, Mexico, October 22, 1907. |
| Date | 1907-10-22 |
| Component | Numerical File |
| Classification cue | File No. 7187. |
| Country / post | n/a |
| Microfilm pub. | M862, Roll 550 |
| Series URL | https://catalog.archives.gov/id/654171 |
| File-unit URL | n/a |
| Roll (item) URL | https://catalog.archives.gov/id/19779414 |
| Roll title | Numerical File: 7179-7187 |
| Found at | frame 521 |
| Match quality | FRUS annotation incorrect |
| Friction notes | wrong file number - actually 7187/19-76 on roll microfilm |
| Time spent | 20 minutes |

## Document 7

| Field | Value |
|---|---|
| FRUS volume | `frus1909` |
| Document | (`d299`) |
| Permalink | https://history.state.gov/historicaldocuments/frus1909/d299 |
| Heading | The Acting Secretary of State to Minister Moses. |
| Dateline | Department of State, Washington, June 18, 1909. |
| Date | 1909-06-18 |
| Component | Numerical File |
| Classification cue | File No. 697/43. |
| Country / post | n/a |
| Microfilm pub. | M862, Roll 99 |
| Series URL | https://catalog.archives.gov/id/654171 |
| File-unit URL | n/a |
| Roll (item) URL | https://catalog.archives.gov/id/19174810 |
| Roll title | Numerical File: 682-699 |
| Found at | frame 860 |
| Match quality | exact |
| Friction notes | the document printed in FRUS is not only record filed at 697/43 |
| Time spent | 10 minutes |

## Document 8

| Field | Value |
|---|---|
| FRUS volume | `frus1895p2` |
| Document | (`d463`) (enclosure 1) |
| Permalink | https://history.state.gov/historicaldocuments/frus1895p2/d464 |
| Heading | [Inclosure 1 in No. 363.] Mr. Springer to Mr. Uhl. |
| Dateline | Consulate-General, of the United States, Havana, June 19, 1895. |
| Date | 1895-06-19 |
| Component | Consular Despatches |
| Classification cue | Dateline identifies Consulate-General as sender of message to Secretary of State |
| Country / post | Havana |
| Microfilm pub. | T20, Roll 121 |
| Series URL | https://catalog.archives.gov/id/302031 |
| File-unit URL | https://catalog.archives.gov/id/196006797 |
| Roll (item) URL | https://catalog.archives.gov/id/211373468 |
| Roll title | Despatches: April 1 - August 31, 1895 |
| Found at | frame 290 |
| Match quality | exact |
| Friction notes | |
| Time spent | 10 minutes |

## Document 9

| Field | Value |
|---|---|
| FRUS volume | `frus1895p2` |
| Document | (`d463`) (enclosure 1) |
| Permalink | https://history.state.gov/historicaldocuments/frus1895p2/d464 |
| Heading | [Inclosure 1 in No. 363.] Mr. Springer to Mr. Uhl. |
| Dateline | Consulate-General, of the United States, Havana, June 19, 1895. |
| Date | 1895-06-19 |
| Component | Diplomatic Instructions |
| Classification cue | The enclosing message was sent by the Department to the Legation in Madrid |
| Country / post | Spain /Madrid |
| Microfilm pub. | FM77, Roll 150 |
| Series URL | https://catalog.archives.gov/id/593313 |
| File-unit URL | n/a |
| Roll (item) URL | https://catalog.archives.gov/id/149334619 |
| Roll title | Volume 22: Spain: June 17, 1895 - Mar. 9, 1900 |
| Found at | frame 11 |
| Match quality | exact for enclosing message, enclosure is referenced but not present on roll |
| Friction notes | |
| Time spent | 15 minutes |
