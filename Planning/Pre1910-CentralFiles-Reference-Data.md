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

- [ ] Diplomatic despatch, high-volume country (e.g. Great Britain, Mexico, China)
- [ ] Diplomatic despatch, low-volume country
- [ ] Diplomatic instruction (Washington → post)
- [ ] Note **from** a foreign mission in Washington
- [ ] Note **to** a foreign mission in Washington
- [ ] Consular despatch (post city)
- [ ] A telegram (any series)
- [ ] An enclosure printed in FRUS (located via its covering despatch)
- [ ] Numerical File document, 1906–1910 ("File No." citation) — ideally two,
      one with a sub-document number like `5275/2`
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
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 2

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 3

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 4

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 5

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 6

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 7

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 8

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 9

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |

## Document 10

| Field | Value |
|---|---|
| FRUS volume | |
| Document | |
| Permalink | |
| Heading | |
| Dateline | |
| Date | |
| Component | |
| Classification cue | |
| Country / post | |
| Microfilm pub. | |
| Series URL | |
| File-unit URL | |
| Roll (item) URL | |
| Roll title | |
| Found at | |
| Match quality | |
| Friction notes | |
| Time spent | |
