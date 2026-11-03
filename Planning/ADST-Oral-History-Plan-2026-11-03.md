# ADST oral histories: a passage database, and one semantic space with FRUS

> **A basis for discussion with ADST.** This plan is written to open a conversation with the
> Association for Diplomatic Studies and Training. It is **not under consideration for unilateral
> implementation**: nothing in it is to be harvested, built or shipped without ADST's agreement,
> and §2 lists what that agreement would need to cover.

**Date:** 2026-11-03 · **Status:** DISCUSSION DRAFT, for ADST. Nothing is built; §11 lists the
owner's decisions. ·
**Owner ask (2026-11-03):** an app that helps researchers use the Association for Diplomatic
Studies and Training's Foreign Affairs Oral History collection, which the Library of Congress also
publishes with catalogue enrichment. Two parts: a plan for analysing the interviews into a database
of smaller coherent chunks, searchable by country, role (domestic and overseas), date and other
scopes drawn from their content; and whether the same embedding model under the same configuration
lets a single query encoder find results in FRUS and in the interviews at once.

**What this rests on.** Every figure about FRUS Explorer's semantic stack is read from this
repository and cited. This session could not reach adst.org or www.loc.gov: the environment's
network policy refused both hosts. The list of interviews is ADST's own archive page, which the
owner saved as a PDF on 2026-11-02 (§1.3). Everything else §1 says about the two collections comes
from web-search results (§13) or is marked **[U]**, unverified; Phase 0 (§10) measures it. "OH" in this repository
means the Office of the Historian (`OH-Report-2026-10-01.md`), so this plan says *the interviews*
and names its artifacts `adst-…`.

**Related:** `Vector-Embeddings-Semantic-Design.md` (the tiers and the funnel);
`semantic-vectors/EmbeddingGemma-2-Stage-2-2026-10-15.md` and
`semantic-vectors/EmbeddingGemma-2-B4-Move-2026-10-15.md` (the shipped generation);
`tools/semantic-harvest/README.md` and `tools/semantic-harvest/corpus-gates/README.md` (the
harvest and the gates); `tools/semantic-harvest/NER-RUNBOOK.md` §0 (the detector rule);
`234-Early-Era-People-Reframe-Assessment-2026-09-13.md` (pricing a model pass, and what leaves the
machine).

---

## 0. In short

- **Yes, one query encoder can search both, and the app already enforces what makes it true.**
  Every semantic artifact carries a SHA-256 over nine fields: the model, its GGUF file's hash, the
  native and shipping widths, the window and its overlap, the document prompt, the pooling rule and
  the quantization rules (`SemanticVectorsArtifacts.Provenance.digest`). The on-device encoder
  accepts only the GGUF the bundled index names (`SemanticModelStore`). Embed the interviews under
  the same nine values and their artifacts carry the shipped digest, `89481b18…`. The one query
  vector, encoded under `task: search result | query: `, then scores FRUS documents and interview
  passages alike. FRUS's artifacts and the encoder do not change. A pilot confirmed it on 121
  passages from four interviews (§6.6).
- **One space is not one scale.** A query's cosine against a 1962 telegram and its cosine against
  a 1998 recollection of the same day are not comparable numbers. The display calibration (offsets
  0.47 and 0.40) and the funnel's recall@10 of 0.902 were measured on FRUS alone. Each corpus runs
  its own funnel with the same query vector. Results show in two lanes by default; a merged list
  waits for a per-corpus calibration that a judged query set has validated (§6.4). The pilot
  measured the gap: a passage's nearest FRUS document sits at a median cosine of 0.847, against
  0.920 between FRUS documents.
- **The database's spine is each interview's table of contents** [U for its format]. Its entries
  (post or office, role, years) become career segments aligned to the transcript, and every
  passage inherits its segment's place, role and dates. Passages are cut at the interviewer's
  questions, a few exchanges each, never across a segment, and kept to one embedding window
  (≤ 3,680 characters), so each is embedded whole (§3).
- **Scopes** (§4):
  - where the speaker served and what the passage discusses, as two place facets;
  - role as position × organisation × post type, with domestic, overseas and multilateral kept
    apart;
  - three times: when served, the period discussed, and when interviewed;
  - from the text: events, topics in FRUS's own vocabularies, people, and the kind of testimony.
- **The overlap with FRUS is large** (§1.3). Of the 2,488 people on ADST's list, 770 match by
  name a person that FRUS documents mention, 161 of them in at least 100 documents. The most
  documented are Henry A. Kissinger, Cyrus R. Vance, Zbigniew Brzezinski and U. Alexis Johnson.
- **A four-interview pilot** (§1.4). Where a recollection falls in FRUS's scope, FRUS documents
  it: none of 87 passages and claims went unfound. About one in five differs from the record,
  almost always on dates and sequence. Each interview touches only a small part of its speaker's
  FRUS record.
- **Rules first, a model second, gold always.** Parsing, gazetteers and the bundled authorities
  (HistoryAtState's places and topics, POCOM, the person authority) do what they can. A language
  model normalises irregular tables of contents and tags passages. Nothing a model or detector
  produced ships before a hand-keyed gold set has scored it (the NER runbook's rule). ADST's
  Country Readers, its excerpts arranged by country in chronological order, are a ready-made
  partial gold set (§8).
- **Permission is the first gate, and it decides the architecture** (§2). The Library of
  Congress's terms ask for the rights holder's permission for any use beyond fair use. Whether an
  app may show the text, store it, or send it to a model API is ADST's to grant.
- **It is affordable.** The interviews are perhaps 0.4–1.2 billion characters [U], against FRUS's
  ~1.33 billion. That is one night of embedding, ~10–31 MB of sign bits and ~83–248 MB of int8
  vectors. A model pass over every passage costs about $450–3,000 on the Opus tier, $225–1,500 on
  Sonnet and $11–75 on Haiku at batch prices (§7). The real cost is the gold sets: about 25–30
  hours of a researcher's reading.

## 1. The two collections

### 1.1 What the search found

- **ADST's archive page** (as saved on 2026-11-02) says the Foreign Affairs Oral History Program
  has recorded more than 2,600 interviews since 1986, spanning over 80 years, and adds about 60 a
  year. The series "also contains some significant oral histories dealing with American
  diplomacy, which were provided by universities and presidential libraries". ADST asks that the
  material be cited as "INTERVIEWEE FULL NAME Oral History, Interviewed by INTERVIEWER FULL NAME,
  Foreign Affairs Oral History Collection, Association for Diplomatic Studies and Training,
  Arlington, VA, adst.org." Charles Stuart Kennedy (1928–2022) conducted more than a thousand of
  the interviews.
- **The Library of Congress's collection** was donated by ADST. It was first published as
  *Frontline Diplomacy* in American Memory and is now the *Foreign Affairs Oral History Collection
  of the Association for Diplomatic Studies and Training*. It opened with 1,301 transcripts, held
  1,743 at one count, and its collection page listed 1,731 results when the search engine indexed
  it. Item ids look like `mfdipbib001043`.
- **Rights.** LoC's item pages give access for education and research, and ask for the rights
  holders' written permission for use beyond fair use. Some interviews are there by arrangement
  with other holders: one John S. Service interview by permission of the Bancroft Library's
  Regional Oral History Office.
- **Country and Subject Readers** are excerpts from the interviews, arranged in approximate
  chronological order. Each gives an overview of relations with a country, or of a subject, as
  seen by the people who dealt with it in Washington or in the field. They cover almost every
  country, the international organisations, and subjects such as Women in the Foreign Service.
- **A 2017 CLIR proposal** (Digitizing Hidden Collections) covered "over 2,000 unique full-length"
  interviews. Its aims were to make them full-text searchable and to index and catalogue them. The
  registry's records disagree on whether it was funded.
- **ADST's disclaimer**: the interviews are personal recollections and opinions, not official
  statements of the U.S. government or of ADST.

### 1.2 What this plan assumes, and Phase 0 measures

- **Files.** Each transcript is a PDF under `https://adst.org/OH%20TOCs/`, most named
  `<Surname>, <Given>.toc.pdf` (§1.3 counts them).
- **[U] Layout.** Each ADST transcript has three parts:
  - a header: interviewee, interviewer, initial interview date and a copyright line;
  - a TABLE OF CONTENTS whose entries name a post or office, a role and years, with the subjects
    discussed beneath;
  - the body, alternating the interviewer's questions (`Q:`) and answers labelled with the
    interviewee's surname.

  Older transcripts may lack the table or set it out differently.
- **[U] Text.** Most PDFs carry a text layer; some older ones are scans that need OCR.
- **[U] LoC metadata.** LoC adds catalogue fields per interview (subject headings, names, places)
  and serves them through its JSON API (`?fo=json`). Which fields exist, and how complete they
  are, is unmeasured.
- **[U] Overlap.** LoC's ~1,730 are a subset of ADST's ~2,600, some in an older version of the
  same interview.
- **[U] Country Readers.** Each excerpt names its speaker, the speaker's post and years.
- **[U] Size.** 0.4–1.2 billion characters, central 0.85 billion: 2,600 interviews averaging 60 to
  150 single-spaced pages. At FRUS's 4.16 characters a token that is about 100–290 M tokens,
  central ~200 M. Every size and cost below scales with this number.

### 1.3 The overlap with FRUS's people, measured

Measured on 2026-11-03 from two inputs:

- **ADST's list**: the archive page as the owner saved it (2026-11-02, 21:02). It holds 2,582
  links to transcripts in 2,562 distinct files: 2,488 distinct people once joint interviews are
  split and a person's repeat interviews are merged. The names were read from each link's
  position on the page.
- **FRUS's people**: the TEI at HistoryAtState/frus `216cdb76`, read with the app's mention rule.
  A mention is a `persName`'s `@corresp` or `@ref` inside a document, or a document's `@ana`
  pointer to a listed person, counted once per person per document. The documents are joined to
  people through `person-authority-index.json`'s crosswalk, as `person_rollup` joins them. The
  reconstruction found 314,616 documents, the semantic index's own count, and the crosswalk covers
  89.1% of the 62,896 persons-list entries.

| Interviewees who match a FRUS person by name, in … | Count |
|---|---|
| at least 1 document | 770 |
| at least 10 | 475 |
| at least 100 | 161 |
| at least 500 | 51 |
| at least 1,000 | 19 |

Another 140 match only a persons-list entry that the authority does not cover.

**The caveats.**
- These are name matches, not verified identities. Surnames must agree exactly and given names
  token by token, initials allowed, and generational suffixes are binding: Walter B. Smith II is
  not General Walter Bedell Smith. 30 of the 770 have more than one candidate. The people named
  below were checked by hand against the authority's roles. Their transcripts have not been
  opened (adst.org is unreachable from this session), so whether each file is the person's own
  interview is checked when it is read.
- Not every entry is an ADST interview. Some come from universities and presidential libraries
  (above). One, under Dwight D. Eisenhower's name, links to a symposium's transcript and is left
  out.
- The figures reconstruct the app's rollup from the TEI; they are not read from a device's
  index. A device holding another corpus or index version may differ by a few documents.

**The most-documented interviewees** are Henry A. Kissinger (13,091 documents in 99 volumes),
Cyrus R. Vance (4,190), Zbigniew Brzezinski (3,473), U. Alexis Johnson (about 3,370; below),
W. Averell Harriman (2,947), C. Douglas Dillon (2,774), Walt W. Rostow (2,697) and George W. Ball
(2,326).

**Johnson's count needs a correction.** His tags give 3,497, but some sit on President Johnson's
name. In the 1964–68 Korea volume (`frus1964-68v29p1`) his id marks 434 occurrences of "Johnson",
most of them after "President", and only 70 of the 157 documents it tags carry a tag that does not
follow "President". Across all 127
of his list entries, 3,367 documents carry at least one tag that does not follow "President". 813 of
his documents are in the 1955–57 China microfiche supplement (`frus1955-57v03mSupp`), the record of
the Geneva ambassadorial talks he conducted.

### 1.4 A pilot: four interviews read against FRUS

On 2026-11-03 the owner supplied four transcripts from ADST's archive: the three interviews at the
top of §1.3, and U. Alexis Johnson's. None is one of ADST's own interviews:

- three are Lyndon B. Johnson Library oral histories by Paige E. Mulhollan, which ADST hosts:
  Johnson (14 June 1969), Vance (3 November 1969) and Brzezinski (12 November 1971);
- the fourth is Henry Kissinger's interview with Susan Johnson for AFSA (25 July 2012), about China.

**The method.**
- Each transcript was cut into passages by §3.2's rules: 121 in all.
- 90 volumes were indexed for full-text search, 34,620 documents: all of 1958–60, 1961–63 and
  1964–68, and the China volumes of 1969–80.
- A reader judged every passage:
  - whether it falls in FRUS's scope;
  - if it does, whether FRUS documents it: DOCUMENTED, PARTLY or NOT FOUND;
  - where documented, whether the recollection agrees: CONSISTENT, DIFFERS or CAN'T TELL, with a
    quotation of at most 20 words from each side.
- The readers were language-model agents, one per interview. Twenty of their quotations and claims
  were checked against the sources by hand, and all held. The verdicts are candidates in §8's
  sense, not a historian's gold set.

| Interview | Passages | In FRUS's scope | Documented / partly / not found | Consistent / differs / can't tell | His FRUS record that the interview touches |
|---|---|---|---|---|---|
| Vance, 1969 | 54 | 31 (59% of the text) | 26 / 5 / 0 | 22 / 9 / 0 | 3 of the 30 volumes that tag him in 1961–68, 11–13% of his 685 documents; and the Korea volume, which names him in 33 documents and tags him in none |
| Johnson, 1969 | 37 | 25 (71%) | 21 / 4 / 0 | 18 / 6 / 1 | about 24% of his 1,064 documents in the interview's years (about 29% without the misattributed tags) |
| Brzezinski, 1971 | 22 | 16 (79%) | 7 / 9 / 0 | 14 / 1 / 1 | 1 of his 3 tagged 1964–68 documents |
| Kissinger, 2012 | 8 (27 claims) | 15 claims (about a quarter of his words) | 9 / 6 / 0 | 11 / 1 / 3 | 16% of his 649 documents in the China volumes directly, 33% indirectly |

**What it shows.**
- **Where a recollection falls in FRUS's scope, FRUS documents it.** None of the 87 in-scope
  passages and claims went unfound: 63 are fully documented and 24 partly.
- **About one in five differs from the record**, 17 of 87, almost always on dates, sequence or who
  was where. Memory compresses:
  - Vance has the emissary team chosen "the next morning" after the 28 April 1965 landing
    decision. FRUS has it meeting on 14 May (1964–68 v32 d69, d71).
  - Brzezinski places Humphrey's bombing statement "two and a half weeks before the election". It
    was made on 30 September 1968 (v07 d40).
  - One differs on a position. Johnson recalled "strong opposition" to the December 1965 bombing
    pause. FRUS's notes of the 18 December meeting have him telling the President "I'd take the
    pause" (v03 d235).
  - Kissinger's differs in degree. He says "a quasi-alliance posture. We couldn't go that far";
    his November 1973 memorandum speaks of "tacit alliance with Peking" (1969–76 v18 d62).
- **The overlap is narrow on the record's side.** Each interview touches only a small part of its
  speaker's FRUS record:
  - Vance's discusses 3 of the 30 volumes that tag him (Vietnam and the Paris talks were held over
    to a later session);
  - Johnson's touches about a quarter of his documents;
  - Kissinger's reflections on China never reach Taiwan (67 documents).

  The two are complements more than duplicates. An interview adds what FRUS leaves out: who
  telephoned whom, the internal argument, who drafted a speech. FRUS holds far more than any
  interview recalls.
- **Some of each interview is beyond FRUS altogether**: 21–41% of each LBJ Library interview. It
  covers Senate hearings, domestic crises such as Detroit in 1967, appointments, and the President's
  character.
- **FRUS's person tags are noisy.** The pilot found four defects in the TEI:
  - the Korea volume's misattributed tags (§1.3);
  - the same volume's missing tags for Vance;
  - Vietnam 1964 (`frus1964-68v01`), which tags Johnson in 7 documents while at least 41 name him
    (as Alexis, Alex or the Deputy Ambassador);
  - `frus1964-68v17 d116`, which tags an "Ambassador Zbigniew Bidzinski" as Brzezinski.

  A link through a person inherits such defects, so §9's "FRUS documents that name this
  interviewee" needs the same precision-first gate as every facet. The defects are worth reporting
  upstream, as `OH-Report-2026-10-01.md` reported others.

**What left the machine.** The four transcripts, and the FRUS documents the readers opened, were
read in a Claude Code session, which sends text to Anthropic. The owner asked for it. For the full
collection, §2's item 4 asks ADST.

## 2. Rights: the first gate

Ask ADST for five things separately, since each can be granted alone:

1. Show the transcripts in the app: in full, as passages, or as snippets that link to ADST's PDF.
2. Store and serve derived text (normalised transcripts, passages) from a host this project
   controls.
3. Ship derived data: offsets, facets, passage summaries and vectors.
4. Send the transcripts to a model API for tagging. Every word of every transcript leaves the
   machine, so it needs asking for in its own right; the #234 assessment's gate N1 is the precedent.
5. Fetch ADST's PDFs at runtime.

The answer decides the architecture:

| Granted | Shape |
|---|---|
| 1–3 | FRUS's volume pattern. The app downloads each interview's normalised text and its vector shard from a host the project owns, indexes the text in FTS5, and deletes both together. |
| 3 and 5 | The app ships identity, offsets, facets and vectors only. When a reader opens an interview, it fetches the PDF from ADST and extracts the text on the device with the same normaliser. A content hash per transcript version decides whether the stored offsets apply, just as FRUS takes identity from the bundled index and never from position in fetched text. A re-published PDF loses its passages until the next harvest. |
| 3 only | A search index that links out: snippets within fair use, no reader. |

Two more layers sit under ADST's answer: restrictions an interviewee set in a release form, and
the third-party holders LoC names. Living people named in candid passages are a privacy question
the terms should answer.

**Recommendation:** open the conversation before any harvest, and offer ADST the derived data
back: career segments, place and role facets, and the gold sets. That serves their 2017 proposal's
aim of indexing and cataloguing the collection.

## 3. Units

### 3.1 Interview, segment, passage, turn

| Level | What it is | Made from |
|---|---|---|
| Interview | one transcript, in one version | ADST's PDF, matched to LoC's record |
| Session | one sitting, with its date | "Q: Today is …" markers [U] |
| Career segment | one assignment or life stage: post or office, role, years | a table-of-contents entry, aligned to a range of turns |
| Passage | a few exchanges on one subject, ≤ 3,680 characters | §3.2 |
| Turn | one question or one answer | the speaker labels |

**The career segment scopes everything**: who was where, doing what, when. Each passage belongs
to exactly one segment. It inherits the segment's post, role and dates as *served* facets, and
adds its own *discussed* facets. Some entries are not assignments (background, education,
military service, retirement, reflections). They become segments of a life-stage type, so their
passages still have a home.

### 3.2 Cutting passages

- **Boundaries fall at the interviewer's questions.** A boundary is strong in three cases:
  - the question changes subject ("let's turn to …", "then you went to …", a new place or year);
  - the aligned table-of-contents subject changes;
  - the similarity between adjacent exchanges drops. A lexical TextTiling score measures this
    cheaply; the cosine between exchange vectors also would, if an extra embedding pass proves
    worth it.
- **Assembly is greedy.** Exchanges join until the next strong boundary or the cap. An answer
  longer than the cap splits at paragraph breaks, and each continuation links to the passage
  before it.
- **A passage keeps the question that opened it.** The question carries the place, year and
  subject the answer assumes.
- **Two hard limits.** A passage is at most 3,680 characters, the harvester's one-window limit
  (`CHUNK_CHARS` + `OVERLAP_CHARS` in `harvest_embeddings.py`), so it is embedded whole (§6.3). It
  never crosses a segment or a session. The target is 1,200–3,680 characters, about 200–600 words.
- **What is embedded is the text and nothing else.**
  - Speaker labels are kept for display but written `Q:` and `A:` in the embedded text. The
    interviewee's name, repeated at every answer, would otherwise draw an interview's passages
    together, and towards any query that names them.
  - Running headers, footers and page numbers are removed for the same reason.
- **Gold.** Country Reader excerpts are boundaries an editor chose. A blind panel (the V-0
  protocol) asks whether a historian would quote a passage as it stands.

## 4. Scopes

| Scope | Values | Grain | Made from |
|---|---|---|---|
| Place served | HistoryAtState place slugs (274 in `volume-tag-taxonomy.json`), with the post's city | segment | table of contents; a gazetteer of posts |
| Place discussed | the same slugs | passage | mentions, with a model's judgement of which are central |
| Role | position × organisation × post type (§4.1) | segment | table of contents, text, POCOM |
| Served during | year interval, months where stated | segment | table of contents |
| Period discussed | interval with a precision | passage | dates in the text, resolved within the segment's interval |
| Interviewed on | dates of the sessions | session | header, session markers |
| Recall gap | interview year minus period discussed | passage | derived |
| Administration | president; Secretary of State | passage | derived from the period: `administrations.json` for presidents, POCOM's principal officers for Secretaries [U] |
| Regional bureau | EUR, EAP, NEA, AF, ARA/WHA … | passage | derived from place *and* date, since bureau responsibilities moved |
| Event | the HistoryAtState topics that are events (wars, crises), and an event list [U: none is bundled; history.state.gov's Milestones is a candidate] | passage | a model, checked against the list |
| Topic | HistoryAtState topics (114); the Office of the Historian's 491 subjects (`document-subject-index.json`); an extension for what FRUS never covers | passage | a model |
| Person mentioned | a person-authority id, or an unlinked name | passage | span detection, then linking |
| Testimony | participant, witness, secondhand, assessment, anecdote, reflection | passage | a model |
| Interviewee, interviewer, series | person-authority ids; ADST's series [U] | interview | header, authorities |

### 4.1 Role

- **Position**, normalised. For example:
  - mission leadership: ambassador, chargé, DCM, consul general, consul;
  - embassy officers: section chief or counselor; political, economic, consular, management or
    public-affairs officer; attachés by kind; USAID mission director;
  - Washington: desk officer, office director, deputy assistant and assistant secretary, staff or
    special assistant, Policy Planning, INR analyst;
  - other: inspector, instructor, diplomat in residence, detailee, Peace Corps volunteer or
    director, spouse.
- **Organisation**: State and, where stated, its bureau and office; USIA and USIS; USAID and its
  predecessors; Peace Corps; Commerce, Agriculture, Treasury, Defense; the NSC and White House;
  Congress; the UN; private sector and academia.
- **Post type**:
  - overseas bilateral: embassy, consulate, legation, interests section, liaison office;
  - overseas multilateral: NATO, the European Communities, OECD, Geneva, UNESCO, IAEA;
  - Washington;
  - other domestic: USUN New York, diplomat in residence, passport agencies;
  - training: FSI, the war colleges, language schools.

  **Domestic or overseas is derived from post type.** Multilateral stays its own value rather
  than being forced into either.
- **Track and seniority** are derived where the title allows, and left unknown otherwise, never
  guessed. **Appointment** (career Foreign Service, Civil Service, political, military, other)
  comes from the text or the series.
- **A free check.** POCOM records appointment and end dates for chiefs of mission (HistoryAtState
  /pocom, CC0; the bundled `pocom-index.json` holds 1,243 careers). Every interviewee with POCOM
  entries checks the segment normalisation: role and dates must agree within the segment's
  precision.

### 4.2 Place and time

**Two place facets, because they answer different questions.** *Served in Iran* finds a tour in
Tehran. *Discusses Iran* also finds the Iran desk officer in Washington, and the officer in Baghdad
watching the revolution. FRUS volumes carry the same HistoryAtState slugs (`manifest.json`'s
`tags`). One place filter therefore means the same thing on both corpora, though at different
grains: a whole volume on FRUS's side, one passage on this side.

**Three times, for three questions.**
- *Served during* finds who was there.
- *Period discussed* finds what is told about a time, including a later desk officer looking back.
  It is also what pairs a passage with FRUS documents of the same months.
- *Interviewed on* and the recall gap are for judging the testimony: a recollection fifty years
  on is a different source from one five years on.

## 5. The pipeline

**The house split holds throughout.** Each step that cannot be reproduced cheaply is a harvest:
a fetch, OCR, a model call, an embedding. It is written once to a raw store with its provenance,
and not re-run casually. Everything after it is a deterministic Swift generator in the
`<Name>GeneratorCore`, `<Name>Generator` and `<Name>GeneratorTests` shape, reproducible from the
raw store byte for byte, as `SemanticVectorsGenerator` is from the embedding store
(`Vector-Embeddings-Semantic-Design.md` §3.1).

1. **Acquire** (harvest).
   - Enumerate ADST's listing and LoC's collection API.
   - Fetch each PDF and LoC record once, with its URL, date, HTTP validators and SHA-256, at a
     polite rate and under ADST's permission.
   - Later fetches look only for new and revised transcripts.
2. **Reconcile** (deterministic).
   - Match ADST to LoC by normalised name, interview date and interviewer.
   - Flag namesakes, and joint and multi-part interviews.
   - Take ADST's latest version as canonical [U].
   - Keep LoC's id and catalogue fields, as interview facets and as priors for step 6.
3. **Text layer** (OCR is a harvest; the rest is deterministic).
   - Take the PDF's text, or OCR where there is none, with its error rate measured on a sample.
   - Remove running headers, footers and page numbers, but keep a page map (character offset to
     printed page) so every passage cites its pages.
   - Repair hyphenation; normalise Unicode and whitespace.
4. **Structure** (deterministic, with a model fallback).
   - Read the header fields; turn the table of contents into segments, and the body into turns
     and sessions.
   - Align segments to turns with a monotonic dynamic-programming match: each entry's years,
     places and subject phrases, and the interviewer's transition questions, against the turn
     sequence, scored for confidence.
   - Low-confidence interviews go to the model pass and to review.
5. **Passages** (deterministic): §3.2.
6. **Facets.**
   - Rules first: gazetteers for places and posts, including historical names (Saigon,
     Léopoldville, Salisbury); dates resolved within the segment's interval; the derived facets of
     §4.
   - The model pass (§7) does what rules cannot: irregular tables of contents, which places are
     central, implicit periods, events, topics and testimony. It also writes a one-line summary
     for result lists, shown as machine-written, never embedded, and never cited as evidence.
   - People: span detection on the #234 harness's pattern. A name is linked to the person
     authority only where the match is unambiguous; otherwise it stays a string.
7. **Embed** (harvest): §6.
8. **Pack** (deterministic).
   - `adst-manifest.json`: interviews, versions, hashes, sizes.
   - The segment index, and the passage index: offsets, pages, and facets with their evidence and
     confidence.
   - The semantic tiers (§6.7) and the cross-corpus link index (§9).

   A bundled file follows the repository's bundled-artifact rules (CLAUDE.md, *Rules that span
   entries*).

## 6. One semantic space for FRUS and the interviews

### 6.1 The answer

Yes. Embed the interviews' passages with the same model file under the same configuration, and
the one on-device query encoder finds both. This is not a hope about embedding models in general:
the shipped pipeline already guarantees it within FRUS. The app accepts only the query encoder
file the corpus was embedded with, and every artifact names its space by a digest. A second corpus
embedded under the same digest is, by construction, in the same space.

### 6.2 The contract

The nine digested fields, as `semantic-vectors-index.json` ships them, and the query prompt, which
is published but not digested:

| Field | Shipped | For the interviews |
|---|---|---|
| `model` | `embeddinggemma-2-Q8_0` | the same |
| `modelFileSHA256` | `2188ac1d…` (309,855,456 bytes, release `encoder-2`) | the same file |
| `nativeDims` / `shippingDims` | 768 / 512 | the same |
| `chunkChars` / `overlapChars` | 3,200 / 480 | the same; a passage of ≤ 3,680 is one window |
| `prefix` | `title: none \| text: ` | the same; no per-passage title |
| `pooling` | char-length-weighted mean of unit-norm chunk vectors, L2-renormalized | the same; for one window, that window's own vector |
| `quantization` | Matryoshka cut then L2-renormalize; int8 per vector; sign bits, MSB first, zero packs as 1 | the same |
| `queryPrefix` (not digested) | `task: search result \| query: ` | the same: one encode serves both corpora |

With these values, the interviews' artifacts carry digest `89481b1869da1880…`. The app's family
rule, that every consumer refuses to mix pins (`Vector-Embeddings-Semantic-Design.md` §4.3), then
admits them unchanged. The query side does not change at all, so its parity gate stands as
measured: the device encoder against the harvest's vectors, at min cosine 0.999862 on the
simulator's CPU and 0.9999996 on the Mac's Metal (`EmbeddingGemma-2-B4-Runtime-2026-10-15.md`).

**Nothing in the quantization was fitted to FRUS**, so nothing needs refitting. The cut, the int8
scale and the sign threshold are arithmetic on each vector (`SemanticQuantization`). For the same
reason, nothing may be fitted to the interviews either: centring, whitening or a learned rotation
would move them out of FRUS's space.

### 6.3 What the digest does not see

- **The harvest's runtime.** The shipped store was embedded through `llama-server` at llama.cpp
  `a0e6dc73`, batch 64 (the stage-2 memo). The digest pins the weights and the parameters, but not
  the runtime build, the 2,048-token context or the batch, and a later runtime can move the floats.
  So before any interview vector is kept, the same session embeds a control sample of FRUS
  documents. They must reproduce the stored raw vectors within the agreement B4 measured between
  runtimes of one file (min cosine 0.999862 to 0.9999996), and their top-10 neighbours must agree
  with the shipped store's.
- **The text.** Headers, footers, page numbers and speaker names are text the model embeds. FRUS's
  text comes from TEI and carries none of it (§3.2, §5 step 3).
- **The unit.** FRUS documents average about 4,240 characters in 605,978 windows, 1.93 a document
  (about 1.33 billion characters over 314,616 documents: the stage-2 harvest's 29,312 characters a
  second over 45,503.7 s). A whole interview embedded as one item would be the mean of ~100
  windows, a centroid close to nothing in particular. One-window passages keep the vectors sharp.
  Interview and segment centroids (`SemanticQuantization.centroid`) are for "similar careers", not
  for search.
- **The title slot.** EmbeddingGemma's document prompt has a title. Writing the interviewee or the
  post there changes `prefix`, which is digested, so it would be a different contract. A header
  repeated across an interview's passages would also cluster them. Metadata belongs in filters.
- **Fine-tuning** on the interviews makes a new space, and would mean a new FRUS generation too.
  The plan does not need it.

### 6.4 Same space, different scales

- **Register.** FRUS is contemporaneous paperwork; the interviews are retrospective conversation.
  A typed question may sit closer to speech than to cable prose. A one-window passage (sharp) can
  also outscore a pooled two-window document (diluted) that is just as relevant. The calibration
  offsets were fitted on FRUS alone: `ScoreCalibration` records that EmbeddingGemma 2's on-topic
  question has a mean cosine of 0.62 over that corpus. The interviews' figure is unmeasured.
- **Recall is a property of the corpus it was measured on.** The 0.902 (Hamming-800 into an
  int8-512 rerank) was measured over 314,616 FRUS documents. One pool of 800 over the union would
  lower both corpora's recall. So each corpus runs its own funnel with the same query vector, and
  FRUS's stays exactly as measured. The corpus-gates scripts (`nn_ladder.py`,
  `rerank_pool_sweep.py`) measure the interviews' recall on their raw store, and the interviews get
  a `rerankPool` of their own if they need one. The pool is outside the digest.
- **Presentation.** Two lanes by default, *Documents* and *Recollections*, each ranked within
  itself.
  - A merged list ranks by per-corpus calibrated scores. The interviews' offsets are fitted so
    that judged-relevant hits in both corpora sit at the same calibrated median, the method B4
    used to put EmbeddingGemma 2 on the 300m's scale.
  - Reciprocal-rank fusion is the fallback only: it interleaves even when one corpus has nothing
    relevant.
  - `retrieval` is per artifact set, so the interviews' index carries its own `scoreCalibration`.
- **The query template.** The owner's 2026-08-27 sitting chose `task: search result` over two
  alternatives on FRUS (`SemanticQueryPrompt`). The judged query set checks it on the interviews.
  A second template (EmbeddingGemma's model card lists a question-answering task [U]) would cost a
  second encode per search, so it is taken only on a measured gain.
- **Related documents, across corpora.** Document-to-document cosines across the two registers run
  lower than within one. A link needs overlapping dates and places as well as a cosine, and its
  own fitted document offset.

### 6.5 Identity

The digest names the space, not the corpus. The interviews' artifacts carry a corpus id in their
headers and file names, and their own shard path beside FRUS's `generations/89481b18/`. Passage ids
`p1…pN` within an interview version run-length encode to one segment per interview
(`DocumentIDSegments`). A later model change re-embeds both corpora in one harvest under the new
pin, so they always move together. The semantic map is a later option: it needs a mode that places
new points into a fitted layout, which `tools/semantic-map/build_layout.py` does not have (it runs
`fit_transform` only).

### 6.6 Measured: the single-encoder test

On 2026-11-03, with the owner's go-ahead, llama.cpp `a0e6dc73` was built for CPU on Linux. It served
the pinned file, its SHA-256 verified against `2188ac1d…`, with the shipped harvest's settings. All
553 shards were fetched from `generations/89481b18/` and verified against their manifest.

- **The control passes (§6.3).** 24 FRUS documents were re-embedded through the harvester's own
  extraction, windows and pooling: 8 under 1,500 characters, 8 of one full window, and 8 of two to
  six windows.
  - Against their shipped int8 vectors: cosine 0.99975–0.99986 (median 0.99982); 80–94% of the
    int8 codes identical; 0–6 of the 512 sign bits different.
  - Each is its own nearest neighbour among the 314,616.
  - The gap is of the order B4 measured between the device's CPU encoder and the Metal reference
    (0.999862).
- **The interviews are in the space, at a distance.** 121 passages were embedded under the shipped
  contract. A passage's nearest FRUS document has a median cosine of 0.847. For FRUS documents, the
  nearest other document has 0.920 (121 drawn at random). This is §6.4's register gap, measured.
- **The funnel misses more on interviews.** Recall@10 of Hamming-800 into the int8 rerank, against
  an exact int8 scan, is 0.937 for the passages and 0.990 for the FRUS documents. By interview it
  runs 0.914–0.988, and one passage scored 0.4. The interviews need a wider pool, which the
  corpus-gates sweep should measure in Phase 3.
- **One question searches both corpora.** Eight typed questions were each encoded once under the
  query prompt. Each returned FRUS documents on the episode and the interview passages that recount
  it:
  - Cyprus in November 1967 found 1964–68 v16 d334 and d339, and Vance's passages on the mission;
  - Okinawa found the January 1965 Johnson–Sato memoranda, and Johnson's passages at the same score.

  In seven of the eight, the interview passages scored below the FRUS documents. That is the case
  for lanes and per-corpus calibration (§6.4).
- **Dates are weakly encoded.** The Cyprus question's best FRUS hit was a 1977–80 document, and a
  1905 document came third for the Dominican one. A period filter belongs with every semantic
  search, as §4.2 assumes.
- **A passage does not find its own documents.** Take the 77 passages the readers judged
  documented:
  - across all of FRUS, a document they cited was in the semantic top 10 for 12 of them, and the
    right episode (same volume, within a month) for 33;
  - within the cited document's own volume (a median of 375 documents), it was in the top 10 for
    29, at a median rank of 22.

  So §9's "documents from the same time and place that read close to this passage" are candidates,
  to be narrowed by the passage's period to the month, its people and its places. They are never to
  be shown as the documents the passage describes.

### 6.7 Sizes

| | FRUS, shipped | The interviews, central [U] (range) |
|---|---|---|
| Items | 314,616 documents | ~340,000 passages at ~2,500 characters (160,000–480,000) |
| Sign bits (Tier 1) | 20,476,048 bytes, bundled | ~22 MB (10–31 MB) |
| int8 (Tier 2) | 553 shards, 162,377,248 bytes | ~175 MB (83–248 MB), ~67 KB an interview |
| Embedding time | 12.64 h on the M5 Air | ~8 h at the same rate (4–11 h) |

## 7. The model pass

- **One request per career segment.** Its turns are numbered. The answer, as structured output,
  gives each passage's facets, and its boundaries as turn ranges if the model refines §3.2. Each
  value's evidence is a turn number and a short quotation. The packer must find that quotation
  verbatim, as `ExcerptVerifier` checks an excerpt, or the value is dropped. The instructions and
  schema are a cached prefix, and the requests go through the Batch API.
- **A small separate pass normalises the tables of contents**: ~2,600 of them, about 8 M input
  tokens [U]. It is the most consequential pass for its size, so it runs on the strongest tier, for
  about $55 at batch prices.
- **The output is a harvest**: model, prompt SHA-256, schema version, request ids and date, packed
  deterministically. A re-run is a new harvest, not an edit.

**The cost of the passage pass**, at batch prices (half of list, from the list prices the
claude-api skill cached on 2026-10-06):

| Tier | Batch $/MTok, in / out | Low: 100 M in, 25 M out | Central: 200 M in, 60 M out | High: 290 M in, 240 M out |
|---|---|---|---|---|
| Opus | 2 / 10 | ~$450 | ~$1,000 | ~$3,000 |
| Sonnet | 1 / 5 | ~$225 | ~$500 | ~$1,500 |
| Haiku | 0.05 / 0.25 | ~$11 | ~$25 | ~$75 |

*High* doubles the output for longer answers, and doubles it again for thinking. Haiku's price
holds for prompts up to 100 K tokens, so a longer segment is split. Each phase gets a spending cap
(the #234 assessment's N2).

- **The gold sets choose the tier.** A cheaper tier is used for a field only where it passes that
  field's gate, and that choice is the owner's.
- **If the text may not leave the machine** (§2, item 4), a local model runs through LM Studio on
  the Studio. It is slower, and is scored against the same gold sets.

## 8. Gold sets and gates

| Gold set | How it is made | What it scores |
|---|---|---|
| Country Readers | each excerpt matched to its interview's text | place served and discussed, period, the speaker's role at the time, passage boundaries |
| POCOM careers | interviewees with POCOM entries | segments' role and dates |
| Hand-keyed passages | ~300, stratified by interview decade, region and agency | topics, events, testimony, people, period |
| Hand-checked tables of contents | ~100 interviews | segment normalisation and alignment |
| Judged queries | ~50 of the owner's queries, top 10 in each lane | the funnel, the template, the merged list's calibration |
| Blind passage panel | ~100 passages | would a historian quote it as it stands? |

**Thresholds are set before scoring, precision first, per field.** A wrong *served in* costs more
than a missing one, and a field that fails its gate ships empty rather than wrong. People follow
the person authority's rules: no merge and no new identity without the gold set
(`NER-RUNBOOK.md` §0).

The hand-keyed sets are the real cost: about 25–30 hours of reading. That estimate is 300 passages
at 3 minutes, 100 tables at 5, 1,000 query judgements at 10 seconds and 100 panel rows at 1. The
Country Readers and POCOM carry most of the place, role and date checks.

## 9. The app

What the database makes possible:

- **One search box over both corpora**, by keyword (FTS5) and by meaning, in two lanes.
  - Filters shared by both: place slugs, dates, topics.
  - The interviews' own: role, testimony, interview date. FRUS's own: volume, document type.
- **Browse by post, role and period.** A post's timeline of who served there when ("Embassy
  Tehran, 1977–79: N interviewees") comes straight from the career segments.
- **An interview reader**: the table of contents as navigation, passages with their page numbers,
  a citation in the form an oral history takes, and a permalink to each passage.
- **Links between the corpora.**
  - *FRUS documents that name this interviewee*: precise, through the person authority's crosswalk
    to FRUS's persons lists.
  - *Documents from the same time and place that read close to this passage*: through §6.4's gate.
  - The FRUS reader gets the reverse: *recollections of this*.
  - Where FRUS has not yet published the years a passage discusses, the lane says so rather than
    showing nothing.
- **Recollection shown as recollection**: the interview date and the recall gap beside every
  passage, and ADST's disclaimer.

**Where it lives is the owner's decision** (§11). There are two shapes:
- **(a) A second corpus inside FRUS Explorer.** The 310 MB encoder download is paid once, and the
  reader, collections, notes, citations and sync already exist.
- **(b) A new app target in this repository**, sharing `FTS5Store` and `SemanticVectorsKit`
  (FRUSCoreKit is FRUS's own). For cross-search it still needs FRUS's 20 MB of sign bits, and
  FRUS's shards for the int8 rerank.

Either way, the pipeline and artifacts are package targets here, beside the harvester and the kit
they depend on. **Recommendation: decide after Phase 3**, once the cross-corpus lanes' value has
been measured. Shared kits keep the web edition's four rules (CLAUDE.md); generators are build
tools, outside them.

## 10. Phases

| Phase | Work | Exit gate |
|---|---|---|
| 0. Survey and permission | Enumerate both collections (ADST's list is done: §1.3). On ~60 interviews stratified by decade and source, measure size, text layer or scan, table-of-contents formats, speaker conventions, LoC field coverage, overlap and versions. A pilot, done on 2026-11-03: four interviews read against FRUS (§1.4) and embedded in its space (§6.6). Open the conversation with ADST. | A survey memo that replaces this plan's [U] marks; the pilot's findings; ADST's answer |
| 1. Acquisition and text | Harvest, reconcile, text layer, page map | Header and footer residue and OCR error, measured on a sample, under thresholds set beforehand |
| 2. Structure | Header, segments, turns, sessions, alignment | Segments checked against the hand-checked tables of contents and POCOM; alignment against the Country Readers |
| 3. Semantic spike | Passages for a ~5% stratified sample, embedded in one session with a FRUS control sample | The control reproduces FRUS's raw vectors; the interviews' recall measured; the judged queries scored; calibration fitted; the blind panel graded |
| 4. Facets | The model pass on the gold sample, scored; then the full run | Each field's threshold met, or the field ships empty |
| 5. Full harvest and pack | Every passage embedded; generators, tests, artifacts | A byte-identical repack; every artifact's digest equal to the FRUS index's |
| 6. The app | Shape (a) or (b) | The app's own tests and UI suites |
| 7. Upkeep | New and revised interviews (about 80 a year), harvested under the same pin | — |

## 11. Owner decisions

1. **Decided 2026-11-03: approach ADST, with this plan as the basis for the discussion.** Which of
   §2's five uses to ask for is still open.
2. Inside FRUS Explorer or a new app (§9), after Phase 3.
3. Whether the text may go to a model API (which depends on 1), and each field's tier once the
   gold sets have scored them.
4. Whether the interviews' sign bits (~22 MB [U]) are bundled or downloaded.
5. Two lanes or one merged list by default.

## 12. Risks

- **Permission refused or narrowed**: §2's link-out shape remains.
- **Revised transcripts**: passage ids are per version and content-hashed, and user notes and
  highlights re-anchor across versions (the reader's `HighlightReanchor` is the precedent).
- **Confidently wrong people, posts and roles**: precision-first gates; unknown is better than
  wrong.
- **Memory**: recollection is presented as recollection (§9).
- **Privacy**: living people in candid passages. ADST's terms and any interview's restrictions
  govern.
- **One corpus crowding out the other**: lanes by default, per-corpus calibration.
- **Tags drawn to famous events**: stratified gold sets.
- **FRUS's own person tags are noisy**: the pilot found one man's id on another's name across a
  whole volume (§1.4). Links through people pass the same gates as facets.
- **ADST's site changing under the harvester**: each file is fetched once into the raw store, and
  versions are found by hash.

## 13. Sources

ADST's archive page, *ADST Oral History Archive*
(https://adst.org/oral-history/oral-history-interviews/), saved as a PDF by the owner on
2026-11-02 at 21:02 and read for §1.1 and §1.3. The PDF is not committed.

The rest come from web search on 2026-11-03. The figures are as the search results reported them;
the pages themselves could not be read (see *What this rests on*).

- ADST, *Oral History*: https://adst.org/oral-history/
- ADST, *Country and Subject Reader Series*: https://adst.org/oral-history/country-reader-series/
- Library of Congress, the collection's search page: https://www.loc.gov/collections/foreign-affairs-oral-history/?q
- Library of Congress, an item page: https://www.loc.gov/item/mfdipbib001043
- *Frontline Diplomacy*, About (2008 web archive): https://webarchive.library.unt.edu/eot2008/20080916052930/http:/memory.loc.gov/ammem/collections/diplomacy/about.html
- CLIR Hidden Collections Registry, *Foreign Affairs Oral History Program: Digitization for Improved Access*: https://registry.clir.org/projects/2112/
- AFSA, *Telling Our Stories: The Foreign Affairs Oral History Collection*: https://afsa.org/telling-our-stories-foreign-affairs-oral-history-collection
- Wikipedia, *Charles Stuart Kennedy*: https://en.wikipedia.org/wiki/Charles_Stuart_Kennedy

The pilot's four transcripts (§1.4), downloaded by the owner from ADST's archive on 2026-11-03 and
not committed:
`https://adst.org/OH%20TOCs/Vance,%20Cyrus%20R.pdf`, `…/Johnson,%20U.%20Alexis.pdf`,
`…/Brzezinski,%20Dr.%20Zbigniew.toc.pdf` and `…/Kissinger-Henry.pdf`.
