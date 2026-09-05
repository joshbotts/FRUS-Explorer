# Agentic Analysis with the FRUS Explorer Database

> **A guide for researchers who want to point Claude, ChatGPT, Gemini, or a comparable
> agentic tool at FRUS Explorer's local SQLite index and ask it questions.**

FRUS Explorer builds a full-text index of the *Foreign Relations of the United States* series on
your own machine. That index is an ordinary SQLite database. Nothing stops you from opening it with
an AI coding agent, handing the agent SQL access, and asking it to find patterns across the
more than 300,000 documents a full index holds.

This is a genuinely powerful way to work, and it is also a very efficient way to produce confident,
well-formatted, wrong history. This guide covers both halves: the **technical** matters (where the
database is, what its tables mean, which queries work) and the **methodological** ones (how to keep
provenance intact, how to verify what the agent tells you, and which questions this data cannot
answer no matter how the query is phrased).

**Read [§7](#7-eight-ways-this-database-will-quietly-mislead-you) before you trust a number.** Every
item in it is a real property of this schema, not a hypothetical. And read
[§14](#14-scoping-a-question-before-you-answer-it) before you write your first query: most of the
errors in machine-assisted work here happen while deciding *what to search for*, not while searching.

---

## Contents

1. [What you are working with](#1-what-you-are-working-with)
2. [Getting a copy of the database](#2-getting-a-copy-of-the-database)
3. [Connecting an agent to it](#3-connecting-an-agent-to-it)
4. [Schema reference](#4-schema-reference)
5. [Resolving the coded columns](#5-resolving-the-coded-columns)
6. [Query patterns that work](#6-query-patterns-that-work)
7. [Eight ways this database will quietly mislead you](#7-eight-ways-this-database-will-quietly-mislead-you)
8. [Provenance: the citation chain](#8-provenance-the-citation-chain)
9. [Verification: how to check the agent](#9-verification-how-to-check-the-agent)
10. [What FRUS is, as evidence](#10-what-frus-is-as-evidence)
11. [Safety, privacy, and what leaves your machine](#11-safety-privacy-and-what-leaves-your-machine)
12. [A house-rules block to paste into your agent](#12-a-house-rules-block-to-paste-into-your-agent)
13. [Recording a run so it can be reproduced](#13-recording-a-run-so-it-can-be-reproduced)
14. [Scoping a question before you answer it](#14-scoping-a-question-before-you-answer-it)
15. [Writing a collection the app can open](#15-writing-a-collection-the-app-can-open)

[Appendix A: The semantic vector artifacts](#appendix-a-the-semantic-vector-artifacts)

---

## 1. What you are working with

Three things are true of this database at once, and confusing any of them for another is the
source of most bad results.

**It is a search index, not the edition.** The app renders documents from the original TEI XML.
The database holds a flattened text extraction of each document plus derived tables (dates,
cross-references, persons, source notes). Formatting, the footnote/body distinction, marginal
apparatus, and the editorial structure that makes TEI worth having are *not* in the database. If a
finding depends on how something was encoded, go back to the XML in
`~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/Volumes/`
or to [history.state.gov](https://history.state.gov/historicaldocuments).

**It contains only what you downloaded.** The bundled manifest covers 552 volumes; the database
covers however many you have indexed. There is no row anywhere that says "and 410 volumes are
missing." Every count you compute is conditional on your library, and it is your job — not the
agent's — to say so. Start every session with the coverage query in [§6.1](#61-establish-coverage-first).

**It contains your own writing.** `document_cache.summary_text` and `document_cache.note_text` hold
your AI-generated summaries and your research notes, mirrored out of SwiftData so search can reach
them. An agent doing `SELECT * FROM document_cache` will read them, and — unless told otherwise —
will happily quote a machine-generated summary back to you as though it were a 1958 telegram. See
[§7.6](#76-summaries-are-not-sources) and [§11](#11-safety-privacy-and-what-leaves-your-machine).

---

## 2. Getting a copy of the database

### Where it lives

On macOS the app is sandboxed, so the index sits inside its container:

```
~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db
```

Alongside it you will find `frus.db-wal` and `frus.db-shm`. The database runs in WAL mode; recent
writes may live entirely in the `-wal` file. **Copying `frus.db` alone can give you a stale or
inconsistent database.**

On iOS and iPadOS there is no supported route to the file. The app does not enable iTunes/Finder
file sharing, so the index is not reachable without a full device backup extraction. Do this work
on a Mac.

### Or let the app do it

On macOS, **Settings ▸ Data & Recovery ▸ Export Research Database…** runs everything this section
and [§11](#11-safety-privacy-and-what-leaves-your-machine) describe, in the right order: the backup
API rather than a file copy, the optional strip of your own writing (with the `VACUUM` that makes it
an erase rather than an unlinking), and the `rank`-1 integrity check afterwards — reporting any
problem instead of handing you a file that looks fine. The switch is **off** by default, so the
export excludes your notes, summaries and tag names unless you say otherwise.

The exported copy also carries two things the live index does not: a `research_provenance` table
saying what the copy *is*, and three `research_*` views that pre-apply the exclusion rules
[§12](#12-a-house-rules-block-to-paste-into-your-agent) otherwise asks an agent to remember. Both are
documented in [§4.7](#47-what-the-apps-export-adds).

It is disabled while indexing is running, for the reason the next paragraph gives. The rest of this
section is what to do by hand — on iOS, where there is no route to the file, or when you want the
copy somewhere the panel cannot reach. A hand-made copy is the same database **without** the stamp
and the views: `.backup` copies what is in the file, and neither exists in the live index.

### Copy it properly

Quit FRUS Explorer first. Then use SQLite's backup API, which produces a byte-faithful copy with
the WAL applied and the row identifiers preserved:

```bash
DB=~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application\ Support/FRUSExplorer/frus.db
sqlite3 "$DB" ".backup '$HOME/frus-analysis/frus-copy.db'"
```

Or in Python:

```python
import sqlite3
src = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
dst = sqlite3.connect("frus-copy.db")
src.backup(dst)
dst.close()
```

**Prefer `.backup` over `VACUUM INTO`.** Two of this schema's tables — `frus_documents` and
`user_content` — are FTS5 *external-content* tables: they store only the inverted index and read
column values live from `document_cache` by `rowid`. `document_cache` declares
`PRIMARY KEY (volume_id, document_id)`, so its `rowid` is not an `INTEGER PRIMARY KEY` alias, and
SQLite documents that `VACUUM` **may** renumber such rowids. If it does, every full-text match in
the copy silently points at the wrong document, at entirely plausible-looking scores. `.backup`
copies pages and cannot renumber anything.

### Verify the copy before you use it

```sql
PRAGMA quick_check;
INSERT INTO frus_documents(frus_documents, rank) VALUES('integrity-check', 1);
INSERT INTO user_content(user_content, rank)     VALUES('integrity-check', 1);
```

The `rank` argument matters and is counter-intuitive. Verified empirically against SQLite 3.45:
with the default (`rank` 0) the check tests only the FTS index's *internal* consistency and passes
happily on an index that has drifted from its content table. **`rank` 1 is the one that cross-checks
the index against `document_cache`** — it is the form the app's own Settings ▸ Storage ▸ *Check
Integrity* button uses. A malformed-image error from the `rank` 1 form means your copy's search
index and its text no longer agree; recopy.

Work on the copy, and open it read-only (`file:frus-copy.db?mode=ro`). An agent with write access
to your live index can corrupt the app's state; an agent with write access to a copy can silently
"fix" data to match its hypothesis.

From the shell, either form opens the copy read-only (verified on Apple's sqlite3 3.51.0):

```bash
sqlite3 -readonly "$HOME/frus-analysis/frus-copy.db" "SELECT COUNT(*) FROM document_cache;"
sqlite3 "file:$HOME/frus-analysis/frus-copy.db?mode=ro" "SELECT COUNT(*) FROM document_cache;"
```

The shell accepts a `file:` URI as the database name with no flag; there is no `-uri` option
(`sqlite3: Error: unknown option: -uri`), and an agent told only "use a read-only URI" will invent
one. Prove the connection is read-only once, in a form that changes nothing if you are wrong:
`sqlite3 -readonly frus-copy.db "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` must fail with "attempt to
write a readonly database". (`BEGIN IMMEDIATE` alone does not fail on a read-only connection and
proves nothing.) And whatever invocation you print into an agent's prompt, run it yourself first on
the machine the agents will use, and make the first agent's first call that exact command against
a known answer — a wrong flag shipped to 141 agents in one run would have been caught by one
ten-second canary.

---

## 3. Connecting an agent to it

The mechanics differ by tool, but the shape is the same everywhere and only three decisions matter,
plus one discipline about the calls themselves.

**Give it SQL, not the file.** Do not upload a multi-gigabyte database to a chat interface, and do
not ask a model to "read" it. The productive pattern is an agent that can *execute queries* and see
result sets — a coding agent with shell access (`sqlite3`/Python in a terminal), or a SQLite MCP
server wired into a desktop client. The model's job is to write SQL and interpret rows; the
database's job is to do the counting. A model that is guessing at contents rather than querying
them will produce fluent fabrications.

**Make the connection read-only.** Use a read-only URI (`?mode=ro`) or a client configured without
write tools. This is not only about safety — it removes any possibility that a number changed
between the run that produced it and the run that checks it. From a shell that means
`sqlite3 -readonly` or a `file:…?mode=ro` name with no flag
([§2](#verify-the-copy-before-you-use-it)); the URI form with `uri=True` is for a library
connection.

**Put the schema in context up front.** Paste [§4](#4-schema-reference) and
[§7](#7-eight-ways-this-database-will-quietly-mislead-you) into the session, or point the agent at
this file. Agents infer table semantics from column names, and several columns here mean something
other than what they appear to (`citation_era` is not a date; `reference_type` does not reliably
distinguish body from footnote; `subject_tag_ids` is always empty). The gotcha list is worth more
context budget than the schema is.

A note on scale: a full 552-volume index runs to several gigabytes, with `document_cache` alone at
roughly 1.8 GB of text. Aggregate in SQL and return summaries. An agent that pulls `body_text` for
20,000 rows into its context will exhaust the window before it reaches an answer.

**Keep every tool call short, and keep the big files out of context.** Agent harnesses kill a
call that produces no output for longer than their per-call timeout (three minutes, in the runs
this guide draws on), and a killed call loses everything not yet on disk — one thread lost an hour
and three-quarters of scans that way, and one 300-second query loop lost its results to Python's
stdout buffer after it had computed them. So: never scan all 552 volumes or all of `body_text` in
one call; slice by volume (ten to twenty per call), write each slice's result to a file in the
agent's scratch directory as it completes (`print(…, flush=True)` or `python3 -u`), and merge.
Never `SELECT body_text` without a `(volume_id, document_id)` pair or a tight filter and a `LIMIT`.
And never `cat` a memo, a thread report or a large JSON artifact into context: one round's memo ran
to 279 KB; read it with `grep -n` and `sed -n`. Prefer the index to a corpus scan wherever the
scoping pass has already settled the scan.

When reading is the task the pattern inverts: select `body_text` for named pairs only, a handful
per call — `SELECT volume_id, document_id, length(body_text), header, source_note, body_text FROM
document_cache WHERE (volume_id, document_id) IN (VALUES (…),(…))` — and write each batch to disk
with notes before the next. Select `length(body_text)` beside the text so the result set carries
its own check. Never `substr()` a document you intend to call read: "read in full" means the
captured length equals `length(body_text)`, and the whole/partial split is published. One pass
truncated at 2,200–3,200 characters and reported 77 documents "read in full" where 32 were whole; a
156,074-character document was captured at 1.5%, and one inference in its chronology sat past the
window. Whole-corpus scans in one call are the ones a session limit kills — chunk and checkpoint.

---

## 4. Schema reference

Everything below lives in one SQLite file. Tables fall into four groups: **corpus text**,
**derived structure**, **archival provenance**, and **your own data**.

### 4.1 Identifiers

| Value | Shape | Notes |
|---|---|---|
| `volume_id` | `frus1958-60v07p1`, `frus1861` | The TEI filename without `.xml`. Stable; use it as the join key everywhere. |
| `document_id` | `d12`, `d373a` | The TEI `xml:id`. **Unique only within a volume** — always join on the pair. Letter suffixes exist and are not anomalies. |
| `document_number` | `"12"`, sometimes `NULL` | The printed document number as displayed. Not an identifier; not always present. |
| Canonical URL | `https://history.state.gov/historicaldocuments/{volume_id}/{document_id}` | The citation target for any claim. |

`document_cache.rowid` is used internally to join the FTS tables. **Never persist a rowid, export
one, or use one as an identifier across two copies of the database** — it is not stable across a
`VACUUM`, which the app itself runs after bulk volume removal.

### 4.2 Corpus text

**`document_cache`** — one row per document, keyed `(volume_id, document_id)`. The spine of
everything. About 1,350 rows carry container ids rather than `dN` (`ch1`, `ch10subch1` — chapter
and subchapter divs, 155 volumes), and a `<back>` appendix div is stored as a document with
`is_editorial_note = 0` (`frus1944v01/appendix`). Reconcile any TEI document count against this
table with those two classes named.

| Column | Meaning |
|---|---|
| `header` | The document's title line as printed. |
| `dateline` | The place-and-date line, as printed prose (`"Paris, May 3, 1958"`). Not parsed — use `document_dates`. |
| `source_note` | The editors' source note, verbatim: where the printed document came from. |
| `body_text` | Flattened document text. **Footnotes are included** — see [§7.2](#72-footnotes-are-inside-body_text). |
| `is_editorial_note` | 1 for editorial notes — the editors' own connective prose, not a historical document. |
| `is_front_matter` | 1 for front matter (preface, sources section, abbreviations, persons list). |
| `despatch_serial` | The pre-1906 despatch/instruction serial number, where one exists. |
| `summary_text`, `note_text` | **Yours**, not the corpus. See [§7.6](#76-summaries-are-not-sources). |
| `user_tag_ids` | Your tags, as space-joined opaque UUIDs. Resolve them to names through `user_tags` — see [§4.6](#46-your-own-data). |
| `subject_tag_ids` | **Always `NULL`.** Retired feature; the column survives for schema compatibility. |

**`frus_documents`** — the FTS5 index over `document_cache`, tokenizer `porter unicode61`.
Indexed columns: `header`, `dateline`, `source_note`, `body_text`. Identifier and flag columns are
`UNINDEXED` and cannot be matched against. Join it to `document_cache` on `rowid`.

**`frus_documents_vocab`** — an `fts5vocab('frus_documents', 'row')` view giving `(term, doc, cnt)`:
document frequency and total occurrences for every term in the index. Free to query, and the fastest
route to corpus-wide frequency work. Its terms are **stems**, not words — see
[§7.1](#71-the-index-stores-stems-not-words).

**`user_content`** — a second FTS5 index over the same rows, covering `summary_text` and
`note_text` only. Kept separate so your edits never re-tokenize corpus text. Exclude it from corpus
analysis.

### 4.3 Derived structure

**`document_dates`** — keyed `(volume_id, document_id)`.

| Column | Meaning |
|---|---|
| `date_iso` | Start of the document's date range, ISO-8601. `NULL` for undated documents. |
| `date_iso_max` | End of the range. Equal to `date_iso` for single-day documents. |
| `date_precision`, `date_certainty` | Qualifiers where the editors' encoding supplies them; frequently `NULL`. |

Dates come from the editorial `frus:doc-dateTime-min`/`-max` attributes — the *editors'* judgment
about when a document was created, which for undated memoranda is an inference. A meaningful share
of the corpus is undated; measure it rather than assuming (see [§6.4](#64-time-series-with-an-honest-denominator)).

An editorial-note div (`is_editorial_note = 1`) is dated to the **opening of the span it narrates**:
a 1951 note on the Torquay Round carries `date_iso` 1948-07-02. Exclude editorial notes from any
first-appearance table, or read `date_iso_max` beside `date_iso`.

**`cross_references`** — one row per `<ref>` from one document to another.

| Column | Meaning |
|---|---|
| `source_volume_id`, `source_document_id` | The citing document. |
| `target_volume_id`, `target_document_id` | The cited document. `target_volume_id` is `NULL` for same-volume references in some encodings — handle it. |
| `is_broken` | 1 when corpus-wide validation found the target unresolvable. **Filter these out of every count.** |
| `reference_type` | `footnote` or `editorialNote`. **Do not trust this to separate body text from footnotes** — see [§7.3](#73-reference_type-defaults-body-references-to-footnote). |
| `context` | Truncated surrounding text, useful for reading an edge rather than counting it. |

**`page_ranges`** — one row per page break inside a document. `page_number_type` is one of
`arabic`, `roman`, `prefixed`, `unparseable`; `page_number_int` is populated only for the first two.
`MIN`/`MAX` over `arabic` gives a document's printed page span for citation.

**`persons`** — the per-volume persons list: `(volume_id, ref)` → `name`, `description`, `role`,
`start_year`, `end_year`. The `ref` is a TEI `xml:id` and is meaningful **only inside its volume**.

**`person_mentions`** — `(volume_id, document_id, person_ref)`, one row per tagged mention.

**`person_rollup`, `person_rollup_member`** — the cross-volume identity layer. `person_rollup_member`
maps a volume-local `(volume_id, ref)` to a `rollup_id`; `person_rollup` carries the canonical name,
role, era, volume count, and — where the bundled Office of the Historian authority crosswalk reaches
the cluster — `authority_id` and `viaf_id`. This is **clustering, not ground truth**; see
[§7.5](#75-person-identity-is-clustered-with-a-deliberate-under-merge-bias).

**`person_cluster_candidate`** — pairs the clusterer declined to merge. Never applied automatically.
A useful sanity check when a person's counts look low.

**`terms`** — per-volume glossary entries (abbreviations and their definitions).

**`volume_structures`** — one JSON blob per volume describing its section tree. Parse it in the
client; don't try to query into it with SQL string functions.

### 4.4 Archival provenance

This is the part of the schema most worth understanding, and the part where a careless join produces
the most confident nonsense.

**`document_sources`** — **one row per document**, keyed `(volume_id, document_id)`: the parsed form
of the editors' source note. This answers *where the printed document came from*.

| Column | Meaning |
|---|---|
| `repository` | `Department of State`, `National Archives`, a presidential library, `Central Intelligence Agency`, … The vocabulary is closed (Department of State 212,858 · National Archives 10,514 · Nixon 8,014 · Johnson 4,693 · …); it has **no Commerce value**, so a repository the parser does not recognise falls to `raw_text`/`series_name`, not to a new label. |
| `record_group` | NARA record group number, where asserted. |
| `lot_file`, `lot_file_norm` | Lot file as cited, and its canonical compact key (`64D199`) for joining. |
| `series_name` | Series or file designation as parsed. |
| `decimal_class` | Central-file class key (`751.00`, `POL 27 ARAB-ISR`), canonicalized. The schedule was **renumbered in 1950** (the artifact's own `provenance` string says so): class 4 is *Claims* before and *U.S. trade* after; class 6 is *Commerce* before and bilateral *political relations* after (`611.41: U.S.-U.K. relations` in the editors' own gloss; `611.31` is U.S.–Venezuela commerce after 1950); country numbers move too. A prefix is a false friend across 1950-01-01 — bound every `decimal_class` family by `document_dates.date_iso` at that date, publish the two halves as two sets, and print the predicate beside the count. Measured on the working scope: `411.*` = 327 documents in 46 volumes after, 259 in 29 before (44% of the undated union are claims cases). Country numbers carry a **letter** for dependencies and derived states (`41D` Ireland, `11B` Philippines) and the corpus writes punctuation variants (`611.37.31`, `611.60c.31`): never let the schedule's shape decide the predicate — `GLOB '611.[0-9][0-9]31'` looks like the careful choice and silently drops Ireland (20 documents) and the Philippines (12), while `LIKE '611.%31'` admits the renumbered post-1950 class. Use the date. And `document_sources` stores the letter in upper case (`60F`) where `decimal-class-labels.json` keys it lower (`60f`); one thread's "all bare" claim was a case-sensitive lookup. |
| `job_number_norm` | Normalized CIA Job number. |
| `classification` | Classification/handling markings (`Secret; Nodis`). |
| `citation_era` | **The citation *form*, not a date.** See below. |
| `raw_text` | The source note as printed — your fallback when the parse is thin. It is also where the printed source note's misprints live: a singleton class key beside a large neighbour (`611.8331/139` beside `611.3331`, `611.2031`/`611.2631` beside `611.2531`) is a suspect, and the document header decides. |

`citation_era` takes one of: `decimal`, `cfpf`, `lot_file`, `structured`, `foreign`, `published`,
`named_series`, `unrecognized`. These describe *how the citation is shaped*, which correlates with
period but does not encode it. `structured` in particular covers NARA collections, presidential
libraries, and CIA Job citations alike. Never group by it and label the axis "era."

**`external_citations`** — **many rows per document**, keyed
`(volume_id, document_id, note_ordinal, citation_index)`: archival material the editors *cited in a
footnote*, largely things FRUS did not print.
Three structural facts, measured on the 2026-08-31 build. **The table begins at 1910-12-06**: it has
no row on any document dated earlier, so for the 43,156 non-apparatus documents dated 1860–1909
(13.7% of the 315,827 documents outside front matter) the pointed-at channel is empty by
construction, not by finding — a nineteenth-century question has one channel, and any ranking
built on this table has no nineteenth-century volume in it. **`raw_text` is the parsed anchor
fragment** (mean 50.8 characters — `822.154/375`, `Lot 57D284, Box 111`), not the footnote sentence:
`LIKE '%Department of Commerce%'` over it measures the parser's fragment and returns 0 where the TEI
footnotes carry the name 254 times; for an institution named in footnotes, parse `<note>` in the
TEI. And **the table is a grammar, not a transcript**: it captures lot, presidential-library and
decimal-class anchors only. A Federal Records Center accession, a bare `RG 40`, or a subject-numeric
key (`FT 7 GATT`, `STR 13-1`, `ORG 1 COM–STATE` — 6,753 refused corpus-wide, so every post-1963
pointer of that form is invisible here) is not a row: `SUM(raw_text LIKE '%RG 59%')` = 781 while
`'%RG 40%'` = 0 against 13 `RG 40` footnote occurrences in the TEI. A zero in this channel for a
record group, an accession or a subject-numeric file is a grammar limit, not an absence.

**These two tables must never be blended into one provenance count.** A `document_sources` row says
a document *came from* an archive. An `external_citations` row says an editor *mentioned* one. The
app keeps them in separate tables precisely so the blend is structurally impossible rather than
merely discouraged, and rows that once conflated them were deleted from `document_sources`. If your
agent produces "documents from the Kennedy Library" by unioning them, the number is wrong.

**`volume_sources`** — the volume's own front-matter Sources section, as an ordered outline
(`entry_text`, `kind`, `depth`, `is_heading`, `sort_order`, `note`, keyed
`(volume_id, sort_order)`), each entry carrying a source note's parsed keys, plus the raw
`job_number` (`repository`, `record_group`, `lot_file`, `lot_file_norm`, `series_name`,
`decimal_class`, `job_number`, `job_number_norm`). This is a *finding aid* — what the editors say
they consulted — not a per-document assertion. Volume-grain, never document-grain. It is also the
editors' own gloss table for filing keys — 4,242 of 33,764 rows carry a `decimal_class`; 804
distinct class glosses in 50 volumes (`411.: U.S. trade`, `411.4141: U.S. trade relations with the
United Kingdom`,
`frus1958-60v04`) — and for 1950–63 keys it is the **only** gloss in the stack. Do not confuse it
with the bundled `volume-sources-index.json` (§14.11), which holds the *resolved collections* (3,412
rows, 251 volumes) and none of these glosses; an agent given only the JSON will report the glosses
absent.

### 4.5 Subjects

**`document_subject_refs`** — `(volume_id, document_id, subject)`, where `subject` is an **integer
position** in a vocabulary that lives outside the database. **`document_subjects`** is the same idea
folded to 106 coarser `(category, subcategory)` buckets — and **the two integers index different
vocabularies and are not interchangeable**: `subject` is a position in the subject vocabulary,
`bucket` a position in the sorted list of distinct `(category, subcategory)` pairs, resolved
through `DocumentSubjectStore`'s separate `bucketVocabulary`. Neither is interpretable in SQL alone;
[§5](#5-resolving-the-coded-columns) shows how to resolve them, and
[§7.7](#77-subject-tags-are-recall-oriented-candidates) explains what they are worth.

### 4.6 Your own data

§4's opening names four groups and this is the fourth. Two columns on `document_cache` hold your
writing — `summary_text` and `note_text`, both covered by [§7.6](#76-summaries-are-not-sources) —
and one small table resolves your tags.

**`user_tags`** — `(tag_id TEXT PRIMARY KEY, name TEXT NOT NULL)`. `document_cache.user_tag_ids`
holds space-joined SwiftData UUIDs; this table gives them the names you chose. Ids are written as
uppercase `UUID` strings by both producers, so they join without normalization. The app itself never
queries this table — it exists so that something reading the index directly can.

The join is space-delimited containment, not equality, because the ids share one column. This is the
app's own form:

```sql
SELECT ut.name,
       COUNT(DISTINCT dc.volume_id || '/' || dc.document_id) AS docs
FROM user_tags ut
JOIN document_cache dc
  ON (' ' || dc.user_tag_ids || ' ') LIKE ('% ' || ut.tag_id || ' %')
WHERE dc.user_tag_ids IS NOT NULL AND dc.user_tag_ids <> ''
GROUP BY ut.tag_id
ORDER BY docs DESC;
```

`COUNT(DISTINCT …)` rather than `COUNT(*)` is load-bearing: a document's tag string can repeat an id,
and on the author's own store 14 of 67 tagged rows do.

Three properties worth knowing before you build on it:

- **It is a mirror, refreshed at app launch.** The authority is the app's synced tag model. A tag you
  rename during a session reads under its old name until the app restarts, so a name from this table
  is as fresh as your last launch, not as fresh as your last edit.
- **It carries every tag, including ones assigned to no document.** That is deliberate — "what
  vocabulary does this researcher use" is a question unused tags answer — so a row here is not
  evidence that anything is tagged with it.
- **It is your writing, not the corpus.** Everything [§7.6](#76-summaries-are-not-sources) says about
  summaries applies: exclude it from anything whose output becomes evidence, and see
  [§11](#11-safety-privacy-and-what-leaves-your-machine) for stripping it from a copy.

### 4.7 What the app's export adds

Four objects exist only in a copy made by **Settings ▸ Data & Recovery ▸ Export Research Database…**
([§2](#or-let-the-app-do-it)). They are not in the live index and not in a copy you made with
`.backup`, so a query written against them is a query that will not run on a hand-made file.

**`research_provenance`** — `(key TEXT PRIMARY KEY, value TEXT)`. What this copy is:

| Key | |
|---|---|
| `exported_at` | When the copy was taken. |
| `my_writing_included` | `1` or `0`. **The row the table exists for**: nothing else distinguishes a stripped copy from an unstripped one, because a stripped column reads NULL and so does a document you never annotated. |
| `app_version`, `app_build` | |
| `installed_index_version`, `current_index_version` | [§13](#13-recording-a-run-so-it-can-be-reproduced)'s pair. Unequal means a re-index was pending, so extraction may differ between rows. |
| `installed_fts_schema_version`, `current_fts_schema_version` | The second stamp, which independently triggers a rebuild. |
| `semantic_provenance_digest` | The vectors' pin, or SQL `NULL` if they were not loaded. The key is always present, so NULL means *unloaded* rather than *older export*. |
| `documentation` | A URL to this guide. |

It deliberately does **not** carry §13's two lists — the indexed volumes and the subject-vocabulary
digests. Both are answerable from the rows beside them (`SELECT DISTINCT volume_id FROM
document_cache`; `SELECT DISTINCT digest FROM document_subject_volumes`), and a stored second copy is
a second place for them to disagree. The clipboard record carries them because a clipboard has no
rows to ask.

**Three views** turn four house rules from things to remember into things that are true:

| View | What it is |
|---|---|
| `research_documents` | `document_cache` minus front matter, editorial notes and suppressed volumes — and **without** `summary_text`, `note_text` or `subject_tag_ids`. A view has no `rowid`, so `SELECT rowid FROM research_documents` is an error rather than a plausible identifier. |
| `research_cross_references` | `cross_references` minus `is_broken = 1`. Only that: it does not apply the edition fold, because no rule asks it to. |
| `research_suppressed_volumes` | The second editions this copy is folding, and nothing else. |

The fold is **computed against this copy**, not hard-coded: a second edition is suppressed only where
its first edition is also present here. `frus1977-80v09Ed2` ships with no first edition and survives;
so does an `Ed2` you downloaded on its own. Read `research_suppressed_volumes` and report it —
[§14.9](#149-where-the-corpus-double-counts-itself) explains why the choice is not neutral.

Nothing here is hidden. `SELECT sql FROM sqlite_master WHERE type='view'` prints the exact exclusion
clause you are working under, which is the only reason it is safe to work under one.

---

## 5. Resolving the coded columns

Three things an agent cannot get from the database alone, because they are keyed to bundled JSON
resources inside the app.

**Subjects.** `document_subject_refs.subject` is an index into the `vocab` array of
`document-subject-index.json`, shipped in the app bundle at
`/Applications/FRUS Explorer.app/Contents/Resources/document-subject-index.json`. Each entry carries
`c` (category), `s` (subcategory), `n` (name), `r` (ref slug), `df` (corpus document frequency). The
simplest reliable approach is a SQLite user-defined function:

```python
import json, sqlite3
vocab = json.load(open("document-subject-index.json"))["vocab"]
db = sqlite3.connect("file:frus-copy.db?mode=ro", uri=True)
db.create_function("subject_name",     1, lambda i: vocab[i]["n"] if 0 <= i < len(vocab) else None)
db.create_function("subject_category", 1, lambda i: vocab[i]["c"] if 0 <= i < len(vocab) else None)

db.execute("""
  SELECT subject_category(subject) AS category,
         subject_name(subject)     AS subject,
         COUNT(*)                  AS docs
  FROM document_subject_refs
  GROUP BY subject
  ORDER BY docs DESC
  LIMIT 25
""").fetchall()
```

The vocabulary is versioned: `document_subject_volumes.digest` records the fingerprint the stored
integers were written against. If you resolve against a differently-versioned JSON, every label is
subtly wrong. Copy the JSON out of the same app build that wrote the index.

**Volume metadata.** Coverage dates, titles, subseries, and editors are not in the database at all;
they live in `manifest.json` in the same Resources directory. Any analysis that groups by decade,
era, or subseries needs it. Load it as a table:

```python
import json
man = json.load(open("manifest.json"))
db.execute("CREATE TEMP TABLE volumes(volume_id TEXT PRIMARY KEY, title TEXT, subseries TEXT, "
           "coverage_start TEXT, coverage_end TEXT, published TEXT)")
db.executemany("INSERT INTO volumes VALUES (?,?,?,?,?,?)", [
    (v["filename"].removesuffix(".xml"), v["title"], v.get("subseries"),
     v["dateRange"]["earliest"][:10], v["dateRange"]["latest"][:10], v.get("publicationDate"))
    for v in man])
```

Note the distinction the manifest makes and your prose must keep: **coverage** dates (what the
volume documents) and **publication** date (when it was printed) are different axes, and they are
far apart. Measured over the 552 bundled volumes that state both, the median gap between a volume's
last covered year and its publication year is **27 years**, and the largest is 95. Group by the
wrong one and a chart of "FRUS documents per decade" becomes a chart of publishing schedules.

**Office-holders.** A header names the office, not the person (*The Secretary of State to the Chargé
in Salvador (Engert)*, 1925-08-06 — Kellogg, not Hughes, who left office 4 March 1925); the bundle's
`pocom-index.json` (Principal Officers and Chiefs of Mission) and `person-authority-index.json`
carry the tenures to resolve it by date.

---

## 6. Query patterns that work

Every query below was executed against a database built from this schema. Adapt freely; the point
is the shape.

### 6.1 Establish coverage first

Run this before anything else, every session, and put its output in your notes.

```sql
SELECT COUNT(DISTINCT volume_id) AS volumes,
       COUNT(*)                  AS rows_total,
       SUM(is_front_matter)      AS front_matter,
       SUM(is_editorial_note)    AS editorial_notes
FROM document_cache;
```

`volumes` against the manifest's 552 is the denominator for every claim that follows. The two flag
sums tell you how much of `rows_total` is not a historical document.

Per volume, with its indexed date span:

```sql
SELECT dc.volume_id,
       COUNT(*)             AS docs,
       MIN(dd.date_iso)     AS first_date,
       MAX(dd.date_iso_max) AS last_date
FROM document_cache dc
LEFT JOIN document_dates dd USING (volume_id, document_id)
GROUP BY dc.volume_id
ORDER BY dc.volume_id;
```

### 6.2 Full-text search, ranked and dated

```sql
SELECT dc.volume_id, dc.document_id, dc.document_number, dc.header,
       dd.date_iso,
       bm25(frus_documents) AS score,
       snippet(frus_documents, 6, '[', ']', ' … ', 12) AS hit
FROM frus_documents
JOIN document_cache dc ON dc.rowid = frus_documents.rowid
LEFT JOIN document_dates dd
       ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
WHERE frus_documents MATCH 'containment'
  AND dc.is_front_matter = 0
  AND dc.is_editorial_note = 0
ORDER BY score
LIMIT 50;
```

`bm25()` returns **negative** values where more negative is a better match, so `ORDER BY score`
ascending is correct and `DESC` silently gives you the worst hits. The `6` in `snippet()` is the
zero-based index of `body_text` in the FTS column list.

**For counts, filter with `rowid IN (…)`, not with the join.** Every scoping figure is "how many
documents, in how many volumes, match this phrase". The ranked shape above plans FTS-first and is
fast even for a common phrase. Turned into a count — `COUNT(*)`, `COUNT(DISTINCT volume_id)`,
grouped by year, with the apparatus filter — the planner (the copy carries no `sqlite_stat1`)
drives the join from `document_cache`'s `(is_front_matter, is_editorial_note)` index instead and
runs the MATCH once per row: on the full copy a single phrase costs 5.3 s that way against 0.3 s
in this form:
```sql
SELECT COUNT(*) AS docs, COUNT(DISTINCT volume_id) AS vols
FROM document_cache
WHERE rowid IN (SELECT rowid FROM frus_documents WHERE frus_documents MATCH '"department of state"')
  AND is_front_matter = 0 AND is_editorial_note = 0
  AND volume_id NOT IN ('frus1951-54IranEd2', 'frus1969-76ve15p2Ed2');
```
The tell in `EXPLAIN QUERY PLAN` is `SEARCH dc USING COVERING INDEX idx_document_cache_facet`
appearing *above* `SCAN frus_documents VIRTUAL TABLE`. Where you need the join's columns, `CROSS
JOIN` forces FTS first. In a loop over phrase families with a further join to `document_dates`, five
agents in one investigation recorded the join form timing out at 120, 300 and 600 seconds on the
positive control, and each round re-learned it.

A second cost is in the phrase itself. A phrase MATCH whose tokens include `of` or `the` walks
doclists that span nearly the whole corpus: `"office of international trade policy"` and its like ran
past fifteen minutes on one machine and were abandoned, and seven families lost their literal share
to it. Budget for it, run such phrases one at a time in a process that prints progress, and never
let a no-output watchdog decide the phrase is absent. (`"department of state"` itself, the §14.2
control, is one of these on the join form — 5 minutes; use the count form above, 0.3 s.)

FTS5 query syntax is available in full: `"phrase match"`, `NEAR(containment allies, 10)`,
`header : telegram` for column-scoped matching, `AND`/`OR`/`NOT`, and `term*` prefixes
(matched against stems — see [§7.1](#71-the-index-stores-stems-not-words)).

### 6.3 Corpus frequency without scanning the corpus

```sql
SELECT term, doc, cnt
FROM frus_documents_vocab
WHERE term IN ('contain', 'deterr', 'alli')
ORDER BY doc DESC;
```

`doc` is document frequency, `cnt` total occurrences, and the gap between them is often the finding:
200 occurrences across 150 documents is a pattern; 200 across three is one memo with a tic. Remember
these are stems ([§7.1](#71-the-index-stores-stems-not-words)).

### 6.4 Time series with an honest denominator

```sql
SELECT substr(dd.date_iso, 1, 4) AS year, COUNT(*) AS docs
FROM document_dates dd
JOIN document_cache dc USING (volume_id, document_id)
WHERE dd.date_iso IS NOT NULL
  AND dc.is_front_matter = 0
  AND dc.is_editorial_note = 0
GROUP BY year
ORDER BY year;
```

Always pair it with what the series drops:

```sql
SELECT SUM(dd.date_iso IS NULL) AS undated, COUNT(*) AS total
FROM document_cache dc
LEFT JOIN document_dates dd USING (volume_id, document_id)
WHERE dc.is_front_matter = 0;
```

**The decades are not the same size, so a term's raw decade counts are a chart of this table before
they are a chart of the term.** Dated, non-apparatus documents per decade, second editions folded,
measured 2026-09-02 over 552 volumes: **1860s 11,250 · 1870s 5,798 · 1880s 6,472 · 1890s 9,712 ·
1900s 9,924 · 1910s 30,359 · 1920s 19,733 · 1930s 39,196 · 1940s 74,043 · 1950s 42,296 · 1960s
27,650 · 1970s 22,259 · 1980s 5,949** — a 12.8× spread. Measured: `"commercial policy"` runs 1930s
355 / 1940s 582 raw and one investigation published the 1940s as its peak; per 1,000 dated documents
of each decade it is 9.06 / 7.86 and the 1930s is the peak. `"chamber of commerce"` has its largest
raw count in the 1930s and is, per 10,000, densest in the 1900s and only fourth in the 1930s.

Publish the rate beside the raw count, never instead of it, with the decade's denominator and the
numerator's top-volume share. A small decade's rate can be one negotiation: 76 of the 1900s' 116
chamber-of-commerce documents sit in three volumes, and the rate without the two densest is 64.4
per 10,000 against the published 116.9. And the last bucket is cut by the publication frontier:
1980 alone supplies 1,799 of the 1980s' 5,949 (30%), from the `frus1977-80` volumes, and the 1980s
in this build is 41 volumes' worth of a partially-published subseries — bound the final decade at
the last fully-published year, or drop it, and say which.

```sql
-- denominator: dated, non-apparatus documents per decade, Ed2 folded (§14.9)
SELECT substr(dd.date_iso, 1, 3) || '0s' AS decade,
       COUNT(*) AS docs, COUNT(DISTINCT dc.volume_id) AS vols
FROM document_dates dd
JOIN document_cache dc USING (volume_id, document_id)
WHERE dd.date_iso IS NOT NULL
  AND dc.is_front_matter = 0 AND dc.is_editorial_note = 0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2', 'frus1969-76ve15p2Ed2')
GROUP BY decade ORDER BY decade;

-- numerator for one phrase: same scope, same grouping (the count form is §6.2's IN-subquery)
SELECT substr(dd.date_iso, 1, 3) || '0s' AS decade, COUNT(*) AS hits,
       COUNT(DISTINCT dc.volume_id) AS vols
FROM document_cache dc
JOIN document_dates dd USING (volume_id, document_id)
WHERE dc.rowid IN (SELECT rowid FROM frus_documents WHERE frus_documents MATCH '"commercial policy"')
  AND dd.date_iso IS NOT NULL
  AND dc.is_front_matter = 0 AND dc.is_editorial_note = 0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2', 'frus1969-76ve15p2Ed2')
GROUP BY decade ORDER BY decade;
```

Four traps the time series will not announce:
- **Range-dated documents.** A printed "July —, 1877" is encoded as an interval; `date_iso` is its
  *start* (here 1877-06-30, the month before). A chronology that prints `date_iso` alone gives day
  precision the editors did not; print `date_iso_max` beside it, or say "min" — `SELECT
  SUM(date_iso <> date_iso_max)` tells you how many of your rows are intervals.
- **A decade bucket is not a year range.** "1960s: 24" does not say 1961–63; nine of those 24 were
  1964–67. Re-run at year grain before writing a year span.
- **"Earliest" needs `ORDER BY date_iso`.** A hit list sorted by `volume_id` puts frus1950v01
  before frus1950v06 regardless of date; two "earliest in window" cells were wrong for that reason.
- **`BETWEEN '1934' AND '1945'` drops all of 1945** — it is a string comparison and `'1945-01-01' >
  '1945'`. Write `>= '1934' AND < '1946'`.

### 6.5 Provenance mix

```sql
SELECT ds.citation_era, COUNT(*) AS docs
FROM document_sources ds
JOIN document_cache dc USING (volume_id, document_id)
WHERE dc.is_front_matter = 0
GROUP BY ds.citation_era
ORDER BY docs DESC;
```

Label the output "citation form", not "era". For a repository breakdown use `repository` and
`record_group`; for lot-file work join on `lot_file_norm`, never on the raw `lot_file` spelling,
which varies (`64 D 199`, `64D199`, `64 D199`).
`lot_file_norm` is a parse, not an assertion: it is populated on some rows whose
note names no lot at all (two of the five `75 D 229` rows are Nixon Presidential Materials notes), so
read `raw_text` for any lot you publish a shelf for.

### 6.6 Citation graph

```sql
SELECT target_volume_id, target_document_id, COUNT(*) AS inbound
FROM cross_references
WHERE is_broken = 0
  AND target_volume_id IS NOT NULL
GROUP BY target_volume_id, target_document_id
ORDER BY inbound DESC
LIMIT 25;
```

This counts only edges whose citing volume you have indexed. A document can look uncited simply
because the volumes that cite it are not in your library — which is why the app ships a bundled
resolved-edge index for the inbound half. Inside SQL, treat every degree as a **lower bound**.

### 6.7 A person's footprint

```sql
SELECT pr.canonical_name, pr.role, pr.volume_count, pr.authority_id,
       COUNT(DISTINCT pm.volume_id || '/' || pm.document_id) AS docs
FROM person_rollup pr
JOIN person_rollup_member prm ON prm.rollup_id = pr.rollup_id
JOIN person_mentions pm
     ON pm.volume_id = prm.volume_id AND pm.person_ref = prm.ref
GROUP BY pr.rollup_id
ORDER BY docs DESC
LIMIT 25;
```

A `NULL` `authority_id` means the cluster was never keyed to the Office of the Historian authority
file — treat that row's identity as provisional.

### 6.8 Pages for a citation

```sql
SELECT volume_id, document_id,
       MIN(page_number_int) AS first_page,
       MAX(page_number_int) AS last_page
FROM page_ranges
WHERE page_number_type = 'arabic'
  AND volume_id = 'frus1958-60v07p1'
  AND document_id = 'd12'
GROUP BY volume_id, document_id;
```

---

## 7. Eight ways this database will quietly mislead you

None of these throw an error. All of them produce plausible numbers.

### 7.1 The index stores stems, not words

The tokenizer is `porter unicode61`. `containment`, `contains`, and `containing` are all stored as
`contain`; `allies` is `alli`. Consequences, in order of how often they bite:

- `SELECT * FROM frus_documents_vocab WHERE term = 'containment'` returns **nothing**. The term is
  `contain`. An agent that concludes "the corpus never uses this word" has misread the tokenizer.
- A `MATCH` for `containment` also matches `contained` and `container`. You cannot separate them at
  the index; if the distinction matters, filter the retrieved rows afterwards — over all four
  indexed columns, not `body_text` alone (the protocol below).
- Frequency counts from `frus_documents_vocab` are stem frequencies. Do not present them as word
  counts.
- **Collisions are not exotic.** Measured on this corpus: `office`/`officer`/`offices` → `offic`
  (`"consular officer"` = `"consular office"` = 3,615 documents; `"commercial officer"` was half
  *commercial office*); `act`/`acting` → `act` (`"rogers act"` 8 documents, 7 of them "Rogers,
  Acting …", 1 the statute); `consul`/`consulate(s)` → `consul` (36,226); `work`/`working`;
  `attach*` → *attached*. Any phrase whose last word is a noun with a verb or plural homograph
  needs a literal check.
- **A `term*` prefix is matched against stems.** A prefix longer than the stem reaches only the
  unstemmed residue: `reorganiz*` returned 9 documents, `reorgan*` 5,184; `amalgamat*` 0,
  `amalgam*` 420. Check the stem in `frus_documents_vocab` before writing any `…iz*`, `…ation*` or
  `…ment*` prefix.
- **Phrase matching is subsequence matching** (in any engine, not FTS5 alone). `"division of
  commercial policy"` matches every occurrence of *Division of Commercial Policy and Agreements*; a
  successor unit's count contains its predecessor's. Subtract the longer phrase, or say you have not.

That "filter afterwards" is a rule, not an option, and it has a measured shape. Over 44 phrase
families audited in one investigation, three failed the share and two more that had shipped with no
share failed when first measured: `"national treatment"` is literal in **9 of 40** (34 of the 40
contain *most-favored-nation treatment*, at least three of them beside a literal use —
`national → nation`, and unicode61 drops the hyphens);
`"commercial officer"` **22 of 40** (*commercial office*); `"clearing agreement"` **157 of 229**
(*clear agreement*); `"export administration"` **55 of 86** (29 of the misses are the 1917 *Exports
Administrative Board*: `exports → export`, `administrative → administr`); `"american exporters"` **453
of 907** (*export trade*). `"generalization of"` returned 10,717 documents because the stem is `gener`.

**Rule: no phrase count containing a word with a colliding stem is published without its literal
share, and a family you argue from carries one — a false-friend screen is not a substitute.** The
working threshold that investigation used was 0.80 (a project convention, not a measured constant):
below it a family is unusable in its published form. The protocol:

1. An evenly-spaced sample of 40 from the `(volume_id, document_id)`-sorted hit list (≥30; the whole
   set under 300; a census for a load-bearing family).
2. Regex over the concatenation of **all four indexed columns** — `header`, `dateline`,
   `source_note`, `body_text` — NFKD-stripped and whitespace-collapsed. Sampling `body_text` alone
   manufactures misses.
3. Run it **strict** (single spaces) and **tolerant** (each word allowed its inflections; any run of
   space, hyphen, comma, parenthesis, full stop between words) and print both. **Publish tolerant,
   strict beside it.** Low strict with tolerant 1.000 is inflection and harmless (`"consular
   invoice"` 0.372 / 1.000; `"bilateral balancing"` 62 of 89 strict, 87 of 89 once *bilaterally
   balanced* is allowed); a low **tolerant** share means the stemmer folded two words together
   (`"national treatment"` 0.175 on a later 280-document sample, against 9 of 40 above: the misses
   are *most-favored-nation treatment*). The band also holds the corpus's hyphenation (*East–West
   trade*: strict 6 of 809, tolerant 809 of 809) and the tokenizer's list-crossing false positives
   (*"economic, foreign policy, and ideological"* matched
   as *economic foreign policy*). Read the misses before condemning.
4. Print the share in the family's row beside the count. Budget for the phrase MATCH itself: a
   phrase whose tokens include `of` or `the` can run for minutes on this index (§6.2); do not
   publish a family unmeasured because its MATCH was slow.

A literal share tests the stemmer, not the referent: a homograph passes at 1.000 (`ito` is one
quarter the Japanese surname Itō, 89 of 355, every one before 1946), which is §14.5's question,
asked separately — an acronym or short family needs a date or context screen reported beside it.

Cross-lemma folds to expect: `officer/office → offic`; `national/nation → nation`; `clearing/clear →
clear`; `balancing/balance → balanc`; `exports/export → export`; `administrative/administration →
administr`; `reciprocity/reciprocal → reciproc`; `attaché/attached → attach`; `promotion/promote →
promot`; `generalization → gener`. Inflectional folds (`policy/policies`) are benign. Two near
misses: `commissioner → commission` but `commission → commiss`; `commercial → commerci` but
`commerce → commerc`.

### 7.2 Footnotes are inside `body_text`

`body_text` is all character data inside the document `<div>`, footnotes included. So a term count
over `body_text` blends the historical document's language with the *editors'* twentieth- and
twenty-first-century annotation. For a claim about how diplomats wrote, this is a real contaminant
— editorial footnotes are dense, numerous, and written in a modern register. The database offers no
column that separates them. If the distinction is load-bearing, parse the TEI.

### 7.3 `reference_type` defaults body references to `footnote`

The column takes `footnote` or `editorialNote`, and a reference in a document's *body text* falls
through to `footnote`. It therefore cannot support "N% of citations occur in footnotes" — a claim
this column looks purpose-built to answer and cannot. Use it to identify editorial-note references;
do not use it as a body/footnote split.

For the corpus as a whole, roughly 95% of document-to-document references genuinely are footnote
references, measured elsewhere in this project. That figure matters for interpretation: a citation
graph over FRUS is largely a map of **the editors' annotation practice**, not of contact between
the historical documents. Any surface built on `cross_references` owes the reader that sentence.

### 7.4 `citation_era` is a form, not a period

Covered in [§4.4](#44-archival-provenance) and repeated here because it is the single most common
misreading: grouping by `citation_era` and plotting it as a timeline produces a chart that looks
like archival history and is not.

### 7.5 Person identity is clustered, with a deliberate under-merge bias

`person_rollup` is built by name-key clustering over per-volume persons lists, tuned to **under-merge**:
when in doubt it leaves two clusters apart and records the pair in `person_cluster_candidate` for a
human to confirm. So:

- A person's document count is a **floor**. Check `person_cluster_candidate` before calling one low.
- Two rollups may be the same person. Same name, different rollups is common across long runs of
  volumes.
- Coverage of the authority crosswalk is partial (about 89% of the app's person rows). Rows without
  `authority_id` are the ones most likely to be split or conflated.

Also: `person_mentions` records *tagged* mentions from the TEI `<persName>` markup. Editors did not
tag exhaustively, and tagging practice varies enormously across a century and a half of volumes. An
untagged mention is invisible here. Never write "X is mentioned in N documents"; write "X is tagged
in N documents in my indexed volumes."

### 7.6 Summaries are not sources

`summary_text` holds on-device Apple Intelligence summaries; `note_text` holds your own notes. Both
are indexed in `user_content`. An agent that does `SELECT header, body_text, summary_text` and
writes a paragraph from what it saw can produce a quotation that exists nowhere in the historical
record. **Exclude both columns from any query whose output will become evidence**, and state that
exclusion in your prompt. If you want to search your own notes, do it deliberately and separately.

### 7.7 Subject tags are recall-oriented candidates

The bundled subject index is derived from the Office of the Historian's public-domain frus-subjects
data by **case-insensitive string matching of subject names and variants — not semantic analysis**.
Its own provenance string says to treat the tags as recall-oriented candidates rather than ground
truth, and no breadth filter or era-sanity gate is applied. They are excellent for *finding*
documents and unsuitable as a measurement of what documents are *about*. "Blockade appears in N
documents" is a statement about string matching
— and the matched string may be one common word. Measured on the working scope (apparatus excluded,
Ed2 folded): *Trade relations* tags 28,815 documents, of which 28,144 contain the stem `trade` and
only 1,509 the phrase "trade relations" — in the 1860s it fires on the slave trade; *Customs
regulation* tags 9,633, of which 9,627 contain `customs` and 278 "customs regulation", and 2,763
(28.7%) carry no fiscal cue at all ("customs and habits"). One agent's reading of 20 documents per
tag found 10 and 4–5 on topic. Before using any tag as a count, run the literal-phrase and the
bare-stem FTS queries and publish tag ∩ phrase / tag; the shortfall runs both ways — 63 of 937
*Consular offices* documents contain no `consul*` token in the index, the tagger having matched text
the index does not hold. And check the tag's date distribution against the term's own first
appearance: the *Multilateral Trade Negotiations* tag fires on 136 documents dated before the phrase
exists (1972-08-15). A subject absent from the 491-name vocabulary is not a corpus absence either —
the vocabulary has no subject for the Department of Commerce, its Bureau of Foreign and Domestic
Commerce, or commercial attachés.

### 7.8 Absent rows are not zeros

Several tables are sparse by construction: a document with an unparseable source note has no useful
`document_sources` values; an undated document has `NULL` dates; a volume with no front-matter
Sources section has no `volume_sources` rows. A `LEFT JOIN` that turns these into `0` and an
`INNER JOIN` that drops them are two different biases, and neither announces itself. Decide which
you want, say which you chose, and report the size of the excluded set.

---

## 8. Provenance: the citation chain

The value of working this way is that every aggregate can be walked back to a document. Protect
that property; it is the whole argument for using a structured corpus rather than asking a model
what it remembers about FRUS.

**Every claim carries `(volume_id, document_id)`.** Not a title, not a summary, not a page number
alone. The pair is the only durable identity in this system, and it resolves to a URL:
`https://history.state.gov/historicaldocuments/{volume_id}/{document_id}`.

The same pair also opens the reader's own copy. `frusexplorer://document/{volume_id}/{document_id}`
is registered by the app on both platforms, so a line in your output can be one click from the
rendered document — footnotes, apparatus and all. That is what makes an agent's claim cheap to
check rather than expensive, so prefer emitting both: the canonical URL for anyone, the scheme link
for the person who has the app. A volume the reader has not downloaded still opens, landing on a
state that names the volume; a volume that is not in the series is refused by name.

**Quotations come from a retrieved row, never from the model — and are checked by machine.** Require
the `SELECT` beside every quotation. Then verify each: lower-case both sides and drop everything but
`[a-z0-9]` (this absorbs smart quotes, dash forms, line-break hyphens and the space the flattened TEI
puts before punctuation — a checker's own accent handling is the commonest false alarm); split the
quotation at its ellipsis marks; require every segment as a substring of `header || dateline ||
source_note || body_text` for the *exact* `(volume_id, document_id)` cited, at increasing offsets.
Segment-strict, not chunk-tolerant: a matcher that accepts 90% of chunks in any order passed a
compressed list set inside quotation marks, an unmarked 232-character elision that changed a
pronoun's referent, and two passages joined in reverse order — all three of which the strict test
refuses. A corpus-wide search finds the right words in the wrong document; test the pair. Three
rules for the residue: `body_text` splices the editors' footnotes into the printed sentence
(`frus1937v02/d101` reads "…to Squire E. C. Squire, American Trade Commissioner at Sydney. who
concurs"), so a quotation crossing a footnote anchor marks the elision and says the TEI settles the
printed form; an elision is always marked, never removes the words that fix a referent, never
reverses source order; and nothing goes inside quotation marks that is not in the row — no
compression, no bracket-free substitution, no silent initial capital. The third round of the
2026-09 run (§14.12) checked 220 quotations this way and found 0 fabrications; a review by eye had
not. Reading has a count of its own — §9 item 8.

**Cite the printed edition, not the database.** Chicago style for FRUS is the printed volume,
document number, and page — which is why `page_ranges` is in the schema. The database is your
finding aid; the citation is to the edition. The Office of the Historian's own
[citation guidance](https://history.state.gov/historicaldocuments/citing-frus) is authoritative, and
the app's export formats (BibTeX, RIS, Zotero) already implement it if you would rather not
hand-roll.

**Keep the source note.** For any document you build an argument on, carry `document_sources.raw_text`
into your notes. It is the editors' statement of where the document came from, and it is the bridge
from FRUS to the archives — the thing that lets a reader, or a later you, check the printed text
against the file.

**Distinguish the three archival relations.** They are three different tables for a reason, and
collapsing them is the most common analytical error available here:

| Question | Table |
|---|---|
| Where did this printed document come from? | `document_sources` |
| What did the editors cite in a footnote (usually unprinted)? | `external_citations` |
| What did the editors say they consulted for this volume? | `volume_sources` |

---

## 9. Verification: how to check the agent

Agentic SQL fails in a characteristic way: the query runs, returns rows, and answers a subtly
different question than the one you asked. A `JOIN` on `document_id` alone (without `volume_id`)
returns a large, plausible, meaningless result set. So does a filter that forgot
`is_front_matter = 0`. Neither errors.

A protocol that catches most of it:

1. **Make the agent show the SQL for every number.** No exceptions, including numbers in prose. Read
   the `WHERE` clause. Most errors are visible there in five seconds. Then resolve five report
   labels at random against the log. A label that resolves to nothing, a regex elided with "…", or a
   printed query returning a different number from the one beside it leaves the number unverified
   whatever its value.
2. **Check the joins for the pair.** Any join between two corpus tables must constrain both
   `volume_id` and `document_id`. This one check catches more bad results than everything else here
   combined.
3. **Ask for the denominator with every proportion — and for its grain and its members.** "1,447 of
   12,060 documents in 43 indexed volumes" is checkable only if the 43 are listed somewhere and
   "documents" means distinct `(volume_id, document_id)` pairs. State the grain (occurrences /
   notes / distinct documents / volumes — one run printed 23 "hits" that were 16 documents and "116
   footnotes" that were 144 occurrences in 140 notes), enumerate the set behind any denominator used
   more than once (one eight-volume set carried twenty-four proportions and was never listed; one
   "18 volumes" listed 16), and for any statistic that varies by era — unclustered share, footnote
   density, headings per volume — compare against an **era-matched** baseline, not the corpus (the
   map's unclustered share is 47% before 1900 and 22% in 1945–64; FRUS's sectioning granularity
   quadruples in 1894, so a raw 0 → 18 commercial headings overstates the editorial turn 3.4×). A
   table headed "ranked" or "top N" that omits rows is a selection; say so.
4. **Spot-check five rows in the app.** Take the extremes and three at random, open them in FRUS
   Explorer, and confirm the document is what the query claimed. This catches join-level errors that
   no amount of SQL reading will.
5. **Re-derive one number a different way.** If a count came through a join, get it again with an
   `EXISTS` subquery. Agreement is weak evidence; disagreement is a finding. The commonest case:
   `COUNT(*)` over a `LEFT JOIN` to a many-rows-per-document table (`document_subject_refs`,
   `external_citations`, `person_mentions`) counts rows — 410 for a 46-document volume in one run,
   762 for a 31-document one. Count `DISTINCT (volume_id, document_id)` or filter with `EXISTS`.
6. **A zero is a claim about a query *and* a surface. Ask for both.** "Run it with the filter
   relaxed" catches a wrong query; it does not catch a surface that was narrowed before the query
   ran, which is how most of one investigation's first-round false zeros were made. Ask what set
   the zero was measured over and how that set was built. If it is a regex-filtered heading file, a
   hand-picked volume list, a `<text><body>` pass that never read `<back>`, a lookup of the named
   leads, or a list of
   `header LIKE` prefixes copied from documents already in hand, the zero is a zero over that
   artefact. An absence claim must be re-run over the unfiltered surface — with the apparatus
   exclusion lifted, since `is_front_matter = 0 AND is_editorial_note = 0` is right for a count and
   wrong for an absence — and a zero that has no logged query behind it is an assertion, not a
   measurement.
7. **Ask what would falsify it.** Before accepting a pattern, have the agent name the query that
   would disconfirm it and run that one too. Treat every *only / first / earliest / last / none* in
   the agent's prose as a pattern in this sense — see
   [§14.13](#1413-superlatives-are-claims-over-a-scope).
8. **When the task is reading, measure the reading.** Define the counts before anything is read:
   *documents read* = distinct `(volume_id, document_id)` pairs whose whole `body_text` was
   retrieved (captured length equals `length(body_text)`, §3); *documents quoted* = distinct pairs a
   quotation is drawn from; *quotation passages* = the passages. Publish all three with the
   whole/partial split, and pre-register a floor for the first two. The evidence is on disk, not in
   the prose — the reading `SELECT` in the query log, the raw retrieved text, and running notes
   written batch by batch — and the claimed count is checked against the distinct pairs in the raw
   text. A count a pass did not do is worse than a small count. In one round the three counts were
   published three ways (178/183, 175/178, 165/178) because no construction had been fixed; a
   thread's 66 was 61 distinct pairs in its own raw text. A cheap test that the output changed
   genre: table lines against blockquote lines and distinct documents cited (97 → 24, 15 → 103,
   76 → 156 in that round).

Do not ask the model to double-check its own arithmetic in prose. Ask it to re-run the query.

Two additions from [§14](#14-scoping-a-question-before-you-answer-it), which are cheap and caught
real errors: require the agent to state its **counting surface** with every corpus-scan number
(raw XML, tag-stripped text, or word-bounded tokens differ by up to 14% here), and where a result
matters, run a second agent adversarially over the first's output with the instruction to find the
wrong number. In three scoping runs that pass found a hyphen fold that had two agents publishing
214 and 142 for the same string, and on one question corrected the headline figure by 47%.

---

## 10. What FRUS is, as evidence

The technical caveats above are about the database. These are about the corpus, and they constrain
what any query over it can mean.

**FRUS is a selection.** Historians at the Office of the Historian choose which documents to print
from vastly larger archival files. The series is deliberately compiled to be a "thorough, accurate,
and reliable" record of major foreign policy decisions — which is a selection principle, not an
absence of one. Frequency in FRUS measures **editorial attention**, and only through it the
underlying activity. "The word X appears more often after 1961" may be a fact about diplomats, about
the editors who compiled those volumes, or about which files were available to them.

**Coverage is uneven by construction.** Volumes are compiled decades after the events, by different
teams, under changing editorial standards, and at different levels of density. Nineteenth-century
volumes are thinner and encoded differently from Cold War volumes. Comparisons across eras are
comparisons across editorial regimes as much as across periods.

**Declassification shapes the record.** Documents are withheld or redacted; some volumes carry
formal statements about material that could not be printed. Silence in FRUS is not silence in the
archives, and the intelligence-related material in particular is systematically under-represented in
ways that vary by period.

**The editors' voice is in the corpus.** Editorial notes, footnotes, headnotes, and source notes are
all present, and (per [§7.2](#72-footnotes-are-inside-body_text)) partly inseparable from document
text. A distant-reading result over FRUS is a reading of a compiled and annotated edition.

None of this makes quantitative work over FRUS invalid. It makes the *framing* of a finding part of
the finding. The defensible form is nearly always comparative and hedged: "Among the 43 volumes I
have indexed, documents the editors sourced to lot files rise from X to Y across the 1950s" — a
claim about the printed record, scoped to what you actually looked at, that a reader can check.

An agent will not supply these caveats. It will produce clean declaratives about "U.S. foreign
policy" from a query over your partial library. Supplying the framing is the part of this work that
remains yours.

---

## 11. Safety, privacy, and what leaves your machine

**The FRUS corpus is public domain.** It is a U.S. Government work published by the Department of
State. There is no copyright obstacle to sending document text to a commercial model, and no
licensing reason to keep it local.

**Your own writing is a different matter.** FRUS Explorer is built so that nothing you write leaves
your devices for a server the project runs; notes, tags, and collections sync through your own
iCloud, and summarization is on-device. **Copying the database to a cloud AI tool overrides that
choice** — `summary_text`, `note_text`, and `user_tag_ids` travel with it. That may be perfectly
fine; it should be a decision rather than a side effect. If you would rather not, strip them from
the working copy before you connect anything:

```sql
-- on the COPY, never the live index
UPDATE document_cache SET summary_text = NULL, note_text = NULL, user_tag_ids = NULL;
DELETE FROM user_tags;
INSERT INTO user_content(user_content) VALUES('rebuild');
```

`DELETE FROM user_tags` is not optional if you are stripping. That table holds the *names* you gave
your tags — `escalation-rhetoric`, not a UUID — which is the most legible piece of your own writing
in the file, and nulling `user_tag_ids` alone leaves it intact.

One caveat about what this recipe does and does not do. It removes the text from the live rows and
from the search index, but the words remain in pages SQLite has freed and not yet reused, and a
page-level copy carries those pages along. If the export must be free of your writing rather than
merely tidy, `VACUUM` the copy afterwards — and then re-run the `'rebuild'` above, because
`document_cache` declares `PRIMARY KEY (volume_id, document_id)` so its rowid is not an
`INTEGER PRIMARY KEY` alias, and `VACUUM` may renumber it out from under both external-content FTS
tables ([§2](#2-getting-a-copy-of-the-database)).

Also worth thinking about before you send: unpublished research in progress, an unpublished argument
visible in the shape of your queries, and any confidential material in your notes about living
people. Check your tool's data-retention and training settings.

**Keep the agent read-only.** Every reason from [§2](#2-getting-a-copy-of-the-database) applies, plus
one: an agent with write access can resolve an inconvenient result by changing the data, and will
sometimes describe that as cleaning.

**Do not point an agent at the live index while the app is running.** Concurrent access to a WAL
database from an uncooperative writer is a good way to lose an index you spent hours building. Work
on the copy.

---

## 12. A house-rules block to paste into your agent

Adapt and paste at the start of a session. It encodes the constraints most likely to be violated.

```text
You have read-only SQL access to a SQLite copy of the FRUS Explorer index — a full-text index of
the Foreign Relations of the United States series. Follow these rules.

SURFACES — there are three, and most rules below belong to exactly one
- THIS DATABASE answers coverage, identity, exclusions, the citation graph, and every count of
  documents.
- THE TEI XML is the only surface that can answer a counting-surface question, a spelling-variant
  scan, or an apparatus/document split. This index stores porter STEMS and a flattened text, so a
  variant count run here silently answers a different question. Marked [TEI] below.
- THE BUNDLED JSON resolves subjects, volume metadata, and EVERY archival question. Nothing in this
  database turns a lot number or a collection name into a shelf. Marked [JSON] below.
If a rule is marked [TEI] or [JSON] and you have not been given that surface, say so and stop —
do not answer it in SQL. An approximation here is indistinguishable from an answer.
- If your brief gives you a [HARVEST] path (the offline NARA record-group harvest the bundled
  archival JSON is projected from — one machine, gitignored): label every count from it [HARVEST],
  state its snapshot date, never sum it with a bundled count, and stream its shards in chunks
  (rg_59.json is 3.56 GB). If you are not given the path, say the surface is unavailable.

COVERAGE
- Before anything else, run the coverage query and report it:
  SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
  FROM document_cache;
- The full series is 552 volumes. This database has only what I downloaded. Every count is
  conditional on that; say so in every summary, with the volume count.

IDENTITY
- Documents are keyed (volume_id, document_id). ALWAYS join on both. Never on document_id alone.
- Cite every claim as volume_id/document_id. Never cite by title alone.
- Never use or report document_cache.rowid as an identifier.

EXCLUSIONS
- Exclude is_front_matter = 1 and is_editorial_note = 1 unless I ask for them.
- NEVER read or quote summary_text or note_text. They are my own AI summaries and notes, not
  historical sources.
- Exclude cross_references where is_broken = 1.

KNOWN TRAPS — do not fall into these:
- The FTS tokenizer is porter stemming and unicode61 drops punctuation. Index terms are stems
  ('containment' -> 'contain'); a vocab lookup for a full word returning nothing means you used the
  wrong form. The converse bites harder: a phrase MATCH also returns a DIFFERENT word with the same
  stem ("commercial officer" returns "commercial office"; "national treatment" returns
  "most-favored-nation treatment"). Publish no phrase count without its literal share, sampled over
  header+dateline+source_note+body_text, tolerant with strict beside it; below 0.80 tolerant is
  unusable; read the misses before calling a family unusable; a 1.000 share does not test the referent.
- body_text INCLUDES editorial footnotes. Term frequencies blend document and editor language.
- citation_era is a citation FORM (decimal, lot_file, structured, cfpf, foreign, published,
  named_series, unrecognized), NOT a date. Never plot it as a timeline.
- cross_references.reference_type defaults body references to 'footnote'. It cannot support a
  body-vs-footnote split.
- document_sources (where a document CAME FROM, one row per document) and external_citations
  (what a footnote MENTIONS, many rows per document) must never be combined into one count.
- person_rollup is name-based clustering biased to under-merge; person counts are lower bounds.
- person_mentions covers TEI-tagged mentions only; tagging is uneven across volumes.
- Subject tags come from string matching, not semantic analysis. Treat as candidates. A tag may be
  a single bare word; verify with the literal-phrase query before counting.
- subject_tag_ids is always NULL. Ignore it.
- bm25() is negative; better matches are more negative. ORDER BY score ASC.

REPORTING
- Show the exact SQL for every number you report.
- Give proportions as "N of M" with the denominator, never as a bare percentage.
- If a query returns no rows, say so explicitly and verify the query can return rows at all
  before drawing any conclusion from the emptiness.
- Do not quote text you have not retrieved in a result set in this session.
- Flag when a result is thin enough that it may reflect my partial library rather than the corpus.
- If you say an earlier pass was wrong, silent, or never read something: grep its FINAL files
  (after its fix pass), show the command, and put the change in a table with the decisive query
  run on BOTH sides.
- If you read documents, report how many you retrieved whole (captured length = length(body_text))
  and how many you quoted; keep the reading SELECT and the raw text on disk.

SCOPING — applies whenever you are scanning the corpus to decide what to search for
- Run a POSITIVE control ("Department of State", expect nonzero in every volume) and a NEGATIVE
  control ("ZZZ_IMPOSSIBLE_ZZZ", expect 0) in the SAME pass. Report both. An absence is not a
  finding until the controls prove the scan works.
- [TEI] State your COUNTING SURFACE with every number: raw TEI, tag-stripped, or word-bounded.
  They disagree by up to 14% on this corpus. Prefer tag-stripped + whitespace-collapsed.
- [TEI] Never query a single literal. Count every spelling, hyphenation, plural, acronym and case
  variant and report the split. Acronyms often outnumber spelled forms. The index CANNOT do this:
  porter stemming folds `chiefs of mission` and `chiefs of missions` to one stem.
- FALSE-FRIEND TEST: for any term the question itself supplied, compute its share in the
  on-topic volumes and compare that to a control phrase's share. A term matching the baseline
  is measuring the corpus, not the question — say so and stop using it.
- Never scan a bare surname. Full-name and inverted-index forms only; <persName> markup covers
  only 4-10% of mentions and cannot disambiguate.
- Periodise on frus:doc-dateTime-min, NOT on the volume's series year. Say which you used.
- Never publish a term's decade shape as raw counts alone: the 1940s holds 74,043 dated documents
  and the 1870s 5,798. Give per-1,000 of that decade's dated non-apparatus documents beside every
  raw count, with the numerator's top-volume share — a small decade's rate can be one negotiation.
- [TEI] Separate document text from apparatus (front matter, abbreviation lists, footnotes,
  index) before publishing any density, or say explicitly that you have not. This database can
  drop front matter and editorial notes by column; it cannot separate a footnote from a body,
  because body_text contains both.
- Read the editors' chapter headings before writing queries. My modern phrasing for a subject
  is usually absent from the corpus; theirs is a repeating formula.
- A negative built from vocabulary postdating the period is circular. Before claiming the corpus
  lacks pre-YEAR coverage, scan terms contemporaries would have used — including the COUNTERPART's
  vocabulary (merchants, chambers, the foreign ministry), not only earlier names for the office.
  Head an absence by the name you tested, and put the founding document beside it if the thing is
  printed under another name.
- Suppress the SECOND edition where its first edition is also present: drop
  frus1951-54IranEd2 and frus1969-76ve15p2Ed2, never the first editions their ids are built from,
  and never frus1977-80v09Ed2, which has no first edition to duplicate. Say which surface you
  counted: the overlap is 718 documents in the vector artifacts and 701 in this index with
  apparatus excluded.

ARCHIVAL SCOPE — do not stop at what FRUS printed
- FRUS is a SELECTION. Scoping is not finished when you know which volumes hold the question.
  Also establish which archival units those documents came out of, and which units their
  footnotes point at. Report both, always labelled by channel, and NEVER summed.
- [JSON] Resolve as far as the bundled indexes reach, and report what you got. They are in the
  app bundle at /Applications/FRUS Explorer.app/Contents/Resources/ and in the public repository
  at FRUSExplorer/Resources/:
    collection-usage-index.json  -> ranked archival targets for any volume scope
    external-citation-index.json -> what the editors cited and did NOT print
    central-files-index.json     -> lot number -> record group + series NAID + entry number
    collection-authority.json    -> collection identity across spellings
    series-facts-index.json      -> creator, extent, inclusive date span, access status, facility
    lot-claimants-index.json     -> lots NARA divides across several series and the NAIDs several
                                    lots converge on
    presidential-library-catalog.json, volume-sources-index.json, decimal-class-labels.json,
    curated-lot-resolutions.json, digitized-ranges-index.json
- A CORPUS-SCOPING NEGATIVE IS NOT A RESEARCH NEGATIVE. "FRUS does not print this" is an
  invitation to answer "and here is the series that does". Never publish the first without
  having attempted the second.
- Label every archival count with its CHANNEL (came-from / pointed-at / union) and its volume
  set. Two channels over one scope are two different numbers.
- NARA's creator attribution is a decoy surface like any other — measured at 56% precision on
  one route. Verify a series' creator heading before calling it on-topic.
- The offline stack barely reaches before 1940 (11 of 695 bundled series). Say so rather than
  reporting an empty pre-war roadmap as an archival absence.
- The pointed-at channel (external_citations) has no row before 1910-12-06, stores the citation
  fragment, not the sentence, and holds lot, library and decimal anchors only. Say so before
  ranking anything on it.
```

### Which surface answers which block

The block as it stood in v1.10 was measured to hold across a doubled session (C-2); the lines v1.11
added to it have not been re-measured (see the version history), and its blocks are not equally
reachable in any case. This is what an agent handed only the database can and cannot do:

| Block | Surface | If the surface is missing |
|---|---|---|
| COVERAGE, IDENTITY, REPORTING | This database | — |
| EXCLUSIONS | This database — and **already applied** in the app's export, see [§4.7](#47-what-the-apps-export-adds) | — |
| KNOWN TRAPS | This database, except the stemming trap, which is a *warning about* the database | — |
| SCOPING: controls, false-friend test, surnames, periodisation, editors' headings, Ed2 fold | This database | — |
| SCOPING: counting surface, variant expansion, apparatus split | **The TEI XML** | Say the number is unavailable. A stem count is not a variant count. |
| ARCHIVAL SCOPE, and §5's subject and volume-metadata joins | **The bundled JSON** | Say the archival half did not run. Do not report it as an archival absence — see [§14.11](#1411-the-second-half-of-scoping-where-the-documents-came-from-and-point-at). |
| ARCHIVAL SCOPE: a `[HARVEST]` count | **The offline record-group harvest**, only when the brief names its path | Say the surface is unavailable. A bundled count is a projection of it, not a substitute — see [§14.11](#1411-the-second-half-of-scoping-where-the-documents-came-from-and-point-at). |

Four of these stop depending on the agent's memory when the copy comes from the app's own export,
because a view enforces them. The rest do not, and no wording of the block changes that.

---

## 13. Recording a run so it can be reproduced

A finding you cannot reproduce is a finding you cannot publish. The database does not fully
self-describe, so capture these alongside your results:

| Record | Where to get it |
|---|---|
| Date of the copy | When you ran `.backup`. |
| App build and version | FRUS Explorer ▸ About. |
| Index format version | Settings ▸ Storage ▸ Index Health — this is the parser generation that built your rows, and it changes what is extracted. |
| Indexed volume list | `SELECT DISTINCT volume_id FROM document_cache ORDER BY 1;` — save the full list, not the count. |
| Subject vocabulary digest | `SELECT DISTINCT digest FROM document_subject_volumes;` if you used subjects. |
| The queries themselves | Verbatim, in a file, with their result counts — **the pattern actually executed**, every disjunct included; a TEI, heading or JSON regex is a query for this purpose. Keep the log per agent session; a reading claim with no retrieval line in it is unverified. |
| Whether the copy contains your own writing, and how many rows | On an app export, `SELECT value FROM research_provenance WHERE key='my_writing_included'`. On a hand-made `.backup` nothing records it: if you did not strip them ([§11](#11-safety-privacy-and-what-leaves-your-machine)), count them — `SELECT COUNT(summary_text), COUNT(note_text), COUNT(user_tag_ids) FROM document_cache` — and state that no agent read those columns. |
| The agent model(s), the number of sessions including the ones that died, the run identifier your harness assigns, and what it cost | Your harness's log and usage accounting. If the model changed mid-run, say which agents ran on which. |
| The exact text each agent was given | The house-rules block *as pasted*, with everything you appended to it (resources, tooling notes), saved as a file. Two agents given different texts are two different instruments. |
| Tool versions | `sqlite3 --version`; `python3 -c 'import sqlite3, sys; print(sqlite3.sqlite_version, sys.version)'`; the harness version. |

**The app can now hand you the index-side rows.** Settings ▸ Storage ▸ Index Health ▸ **Copy
Research-State Record** puts a small JSON on the clipboard carrying the date, the app build and
version, *both* index-version pairs (installed and current, for the date index and the FTS schema),
the sorted indexed-volume list, the subject-vocabulary digests, and the semantic provenance digest.
Paste it beside your results.

Two of those rows it deliberately does not carry, and the four rows after the queries it cannot:
the model and sessions, the prompt text, the tool versions and the writing count live in your
harness and your copy, not in the app. **The queries** stay yours — the app already exports them
with their hit counts, including the recorded zeros a claim of absence rests on, through the method
appendix on a collection export; a thinner second copy here would be worse. And the **date of the
copy** in the table above means when *you* ran `.backup`, which the app cannot know; the record
stamps when the record was taken, which is the honest thing it can say.

It also carries one row this table does not ask for, because the table predates it: the **FTS schema
version**, a second stamp that independently triggers a rebuild. A record showing a matched date-index
pair while that one disagrees is an index mid-migration.

Two of these change under your feet in normal use. Downloading more volumes changes every count.
An app update can raise the index format version and trigger a background re-index, which changes
extraction output for rows you already had. If a number matters, re-derive it after any update
rather than assuming it held.

---

## 14. Scoping a question before you answer it

Everything above assumes you already know what to search for. That assumption is where
machine-assisted work here actually fails. This section is the record of three scoping runs in
2026-08 — on U.S.–Cuba contacts after 1961, on the State Department and wartime critical-materials
supply, and on Foreign Service reform — each measured over the local TEI corpus with controls, and
each adversarially re-measured afterwards, and of a fourth investigation in 2026-09, on commercial
diplomacy, run in three rounds with the §12 block pasted into every agent (§§14.12–14.15 are largely
its record). In the three 2026-08 runs the errors clustered *before* the first substantive query.
Every figure below was measured; none is illustrative.

Note the scope shift: §§1–13 are about the SQLite index. This section is mostly about scanning the
TEI corpus directly, which is what scoping requires — you are deciding which volumes to index-search
at all, and the manifest plus the raw XML answer that faster than SQL does.

**Scoping has two halves, and §§14.1–14.9 are only the first.** Establishing which volumes hold your
question is necessary and not sufficient: FRUS is a published selection, so the second half is
establishing which archival units those documents came out of and which units their footnotes point
at. [§14.11](#1411-the-second-half-of-scoping-where-the-documents-came-from-and-point-at) is that
half. All three 2026-08 runs skipped it, which is why it is stated as a rule rather than an
option — the omission was invisible from inside the work and had to be found by someone asking.

### 14.1 The scoping pass is most of the work

A research question rarely maps onto the corpus the way its prose suggests. Measured:

- A question about U.S.–Cuba contacts "after 1961" has a hard ceiling at **January 1981** — the
  1981–1988 subseries has twelve volumes and none on Cuba, the Caribbean, or the American Republics.
- A question about wartime supply chains touches **99 volumes and 84,664 documents**.
- A question about Foreign Service reform is served by roughly **five volumes and 1,850 documents**,
  0.59% of the corpus.

Two orders of magnitude separate those three, and nothing in the questions themselves predicts it.
Budget the scoping pass accordingly, and finish it before curating anything.

### 14.2 Run a positive and a negative control in the same pass

An absence is not a finding until a control proves the scan could have found something. Use a term
you are confident appears (`Department of State` returns **178,311** occurrences in 552 of 552
volumes) and a string you are confident does not (`ZZZ_IMPOSSIBLE_ZZZ`, 0). Both in the same read,
over the same files, reported with the result.

This is not ceremony. A first probe in one of these runs returned zero for all fifteen terms because
the shell's working directory reset between commands and the glob matched nothing; the scan was
silently searching an empty file list. A control would have caught it in one line. Related: an
unquoted shell variable holding many space-containing paths fails as `File name too long` — prefer a
`python3` heredoc with absolute paths over shell globbing — and GNU `timeout` does not exist on macOS
(`command not found: timeout`; neither does `gtimeout`); guard a long scan with
`perl -e 'alarm 600; exec @ARGV' python3 scan.py …` or a Python-side alarm instead.

**Compare the control, do not just observe it.** "Nonzero in every volume" proves the scan runs; it
does not prove the surface is whole. One heading census reported its control as 201 and never
compared it — the true figure on that surface was 450, and the census had silently dropped every
heading over 200 characters. One TEI table's control was 16% low and passed; every phrase row in it
was 13–61% low, the line-wrap signature. Record the reference for your surface and treat a control
materially below it (the two failures were 16% and 55% low) as a surface defect — a line-wrap, a
length cap, a filtered file. References measured on the 2026-08-31 `.backup` of a full 552-volume
index and the manifest's 552 TEI files, `Department of State`:

| surface | reference |
|---|---|
| FTS `"department of state"`, apparatus excluded, Ed2 dropped | 93,418 documents / 549 volumes |
| raw XML, 550 manifest files (the two folded Ed2 volumes excluded; the 178,311 above is over all 552) | ~177,900 occurrences (177,893 / 177,091 on two agents' folds) |
| inside `<div type="document">`, tag-stripped and collapsed | 152,197 hits / 548 volumes |
| titled `volume_structures` nodes (all levels, front and index included) | 450 of 25,103 |
| body chapter / subchapter / compilation / section `<head>`s | 260 in 107 volumes |
| `external_citations.raw_text LIKE '%RG 59%'` | 781 rows |

A scan of a bundled artifact needs its own positive control (consular roll titles: `despatch` 3,355
of 3,357). A random control is reported with its seed and as a mean over several draws — one
headline random unclustered share was the lowest of thirty seeds (25.6 against a mean of 27.9,
sd 0.98).

**Nor does a control see what was excluded before the scan began.** Four surface-narrowing
shapes produced false absences in one run, each caught by a verifier in one query: a heading file
pre-filtered by a topic regex (a head reading "Reorganization Plan No. II" could never enter it); a
`<body>`-only heading pass (FRUS puts administrative statements in `<back>` appendices —
frus1944v01's "Reorganization of the Department of State" is one, stored `is_editorial_note = 0`);
a census built from `header LIKE` prefixes copied from the documents already found ("a pattern list
built from its own answers"); and the apparatus exclusion itself — `is_front_matter = 0 AND
is_editorial_note = 0` is right for a count and wrong for an absence claim, and one run's "barely
exists" institution was in a 1900 presidential message stored as front matter. Build a census from
a superset scan with a stated inclusion rule, never by enumeration, and re-run every zero with the
exclusion lifted.

### 14.3 Say which text surface you counted

**The shape of the file, since three scans in one run got it wrong.** A document is `<div …
type="document" xml:id="dN">` whose start tag spans several lines with one attribute per line —
measured over the first 150 manifest volumes, 150 of 150 have this shape and a single-line regex
`<div[^>\n]*type="document"[^>\n]*>` finds 0 of 97,483 documents; §14.2's controls do not catch
it, because they count a phrase, not documents, and a scan that found zero documents and 178,311
control hits passes both. Parse, or scan across newlines. The same div carries
`subtype="historical-document"` or `subtype="editorial-note"`, and a regex for `type=` that is not
anchored (`(?<![-\w])type=`) matches `subtype=` first and recognises no document at all (one
thread's whole first TEI table was built that way). Each document div carries
`frus:doc-dateTime-min`/`-max`. Headings are the `<head>` of *non*-document divs, and they live in
`<front>`, `<body>` **and `<back>`** — FRUS puts administrative statements in `<back>` appendices,
so a `<body>`-only heading pass is a narrowed surface in §14.2's sense. Prefer a parser
(`lxml`/`ElementTree`) with the manifest as the file list, never a shell glob over the 694 files on
disk (the manifest names 552).

Raw TEI, tag-stripped text, and word-bounded tokens are three different measurements of the same
corpus, and on FRUS they disagree materially, because the XML hard-wraps prose and inline markup
interrupts phrases. Measured on one control phrase across 99 volumes:

| Surface | Count | Relative |
|---|---|---|
| Tag-stripped + whitespace-collapsed | 16,696 | baseline |
| Raw TEI with whitespace collapsed | 16,670 | −0.2% |
| Raw TEI, uncollapsed | 14,362 | **−14.0%** |

In the densest single volume the naive surface was 19% low. Prefer tag-stripped and
whitespace-collapsed, and state it. The inverse case exists too: a term appearing inside markup
reads *high* on raw TEI — `Safehaven` returns 266 raw against 251 in text, because 15 occurrences
live in attribute values.

### 14.4 One literal is never enough

Every scoping run found the same class of defect, and in one case two agents published **214** and
**142** for the same string without either noticing — a hyphen fold (`ball bearing` 142 +
`ball-bearing` 72). Query every form and report the split.

| Split | Counts | Why it matters |
|---|---|---|
| `wolfram` / `tungsten` | 1,083 / 475 | Same ore, **different top volumes** — 81% Europe vs 45% Far East. Either alone loses a whole theatre. |
| `Proclaimed List` / blacklist family | 2,327 / 354 | The official name outnumbers all four colloquial spellings 6.6 : 1. |
| `chief of mission` / `chiefs of mission` / `chiefs of missions` | 1,687 / 1,651 / 170 | The obvious plural is the *wrong* one; a singular-only query loses half. |
| `Lend-Lease` / `Lend Lease` | 7,509 / 585 | |
| `chrome` / `chromium` / `chromite` | 850 / 51 / 26 | The diplomatic files say *chrome*. |
| `\bFSS\b` vs `FSSO`, `\bFSR\b` vs `FSRU` | — | Word boundaries dropped **441 occurrences** of the purest vocabulary in that question, 88.7% of it in the target volumes. |
| `Reorganization Plan No. II` / `No. 2` | 0 / 20 documents in 6 volumes | The corpus writes Arabic numerals. |

**Case is a variant too.** Telegrams write 'Commercial attaché reports…' and prose 'the foreign trade
advisers of the Department'; one family that scanned only the capitalised form was 47% low, another
40%. Run each family once case-insensitively as a control and reconcile the difference.

Two corollaries. **Acronyms frequently outnumber spelled forms** — `FEA` 1,048 > *Foreign Economic
Administration* 841; `MEW` 451 > *Ministry of Economic Warfare* 322; `UKCC` is **4.6×** its spelled
form; `EEO` 198 > *equal employment* 140. A term list built from spelled forms alone can be 40–460%
low. And **not every suspected split is real**: `aluminium` returns 3 against `aluminum` 207. Measure
rather than assume in both directions.

### 14.5 The false-friend test: compare a term's concentration to the corpus baseline

The most dangerous terms are the ones the research question supplies. A cheap, decisive test: compute
what share of a term's occurrences fall in the volumes you believe are on-topic, and compare that
share to the same figure for an ordinary control phrase. **A term whose concentration matches the
baseline is measuring the corpus, not your question.**

Worked: for the Foreign Service question the control's target-volume share was 2.8%. `reform` —
20,519 occurrences in 514 of 552 volumes — came in at **2.96%**. A uniform random sample of 40
occurrences contained **zero** about the U.S. Foreign Service; 38 were about foreign countries' land,
currency and constitutional reforms.

Others found the same way, each stated as *raw count → share actually on topic*:

- `Herter` 8,655 → **0.13%** the Herter Committee; the rest is Christian Herter as Secretary of State.
- `Director General` 3,442 in 440 volumes → **3.3%** the Foreign Service office; the rest are
  Directors General of the Imperial Railway, of Telegraphs, of Military Education.
- `examination` 16,868 → target share **1.9%, below the 2.8% baseline** — actively anti-correlated.
- `equal opportunity` 628 → essentially none; it is the **Open Door** formula.
- `minority` 8,977 → peaks in the 1910s; the Paris Peace Conference minorities treaties.
- `Inspector General` 1,243 → peaks in 1930s China volumes: the Chinese Maritime Customs.
- `cone` 440 → 157 the career track, 176 the *Southern* Cone, ~108 volcanic and pine.
- `Macomber` 689 → ~14% the management reformer; the rest a serving ambassador.

Substring matching adds its own: a scan for `Herter Report` returned 21 where the truth is 3, because
it was matching **"Herter reported"**.

Personal names are the worst case and cannot be repaired by first name or by markup. `Davies` 2,807
→ at most 27 John Paton (**0.96%**). `Vincent` 2,101 → 164 John Carter, against 421 *President
Vincent* of Haiti. And `<persName>` does not rescue you: only 4–10% of these mentions sit inside one,
so filtering on entity tags discards 90–96% of the real mentions rather than disambiguating them
(compare [§7.5](#75-person-identity-is-clustered-with-a-deliberate-under-merge-bias)).

**The concentration test has a blind spot: a term can be dense in the right volumes and still name
the wrong actor.** Institutional titles are shared across governments and across decades — every
embassy has a commercial attaché, every trade ministry a department of commerce. So run a second
test on any office, title or institution the question supplies: **the actor test** — draw a seeded
sample of at least 100 (or the whole set under ~1,500; a 30-document read gave 10% foreign where
the full pass gave 17%), read the qualifying adjective or possessor before the term, and report the
split *U.S. / named foreign / unmarked*. Report it even when it does not overturn the count. Three
shapes, each measured on this corpus: (1) titles every government uses — attaché, counselor,
commissioner, commercial section (`commercial counselor` cleared the concentration test and was 72%
other governments' officers; `trade mission` 73% foreign delegations, and one Tibetan mission put a
volume at rank 16 of 550); (2) institutions that exist in several countries and predate the U.S.
one — `Department of Commerce` before 1903 and `Tariff Commission` before 1916 are foreign ministries
and commissions; (3) one name, two men or two offices — `Julius Klein` ("Dr." of Commerce and
"General" of the Jewish War Veterans), `Governor Herter` 42% before the office the row was labelled
with. Put the question's own list in the house-rules block you paste: the one such line one run
carried ("'commercial agent' was a consular rank in the 19th century … titles are false friends until
tested") was handled correctly by every one of eight reports that met the term.

**A decoy the concentration test passes: the subject's own letterhead.** When a phrase is also the
name of an office, a committee or a division, its hits include every document that office signed —
on-topic by concentration, and not a use of the phrase. Measured: `"commercial policy"` lifts 3.17×
over its on-topic volumes against a control's 0.75× and passes this test outright; read, **246 of
its 1,265 documents carry the phrase only as the *Division of Commercial Policy*'s letterhead**, and
because that Division existed in the 1940s, the unsplit count put the family's peak in the wrong
decade. `"economic foreign policy"` is a proper noun in **64 of 112** (the Executive Committee on
Economic Foreign Policy); `"trade policy"` attaches an office name in 242 of 1,422, and 194 have no
other use. The 47% headline correction in §14.12 was the same defect, found once before.
**Rule: before publishing a count for any phrase that is also an institution's name, split it into
analytic use and proper-noun use, and publish both.** The split is a regex for the office forms
(*Division of …*, *Office of …*, *Committee on …*) over the sample §7.1's literal-share protocol
already draws, with a third bucket for documents carrying only the office form — and the office
forms are themselves a succession with date spans (*Division of Commercial Policy and Agreements*
1941–45, 83 documents; *Division of Commercial Policy* 1944–50, 130; *… and Trade Agreements* 1), so
enumerate the successors. A decade rate computed on the unsplit family is not comparable with one
computed on the split.

### 14.6 A negative built from anachronistic vocabulary is circular

This is the subtlest error the three 2026-08 runs produced, and it nearly shipped.

A scoping pass reported a clean **12× density step at 1960** for Foreign Service reform vocabulary
and offered it as evidence about FRUS's coverage. The adversarial pass found that **at least eleven
of its twenty markers name institutions, statutes or people that did not exist before 1946** — the
Foreign Service Institute (1947), the Director General (1946), AFSA, the Herter Committee, Macomber.
The step partly measured *when those institutions were founded*, not what FRUS printed.

The correction was immediate: the one era-appropriate term anyone scanned, `civil service reform`,
turned up a real **1871–1897 cluster** the scoping pass had reduced to "1 hit each".

**Rule: a negative measured with the target period's own vocabulary is evidence; a negative measured
with a later period's vocabulary is a tautology.** Before asserting the corpus lacks coverage of
something before year Y, scan terms contemporaries would have used. This generalises well past that
question — it applies to any long-run corpus and to every "the record is silent on X" claim.

The commonest instance is a statute. Eponyms are retrospective: on document text the *Rogers Act* is
named in one historical document in 552 volumes (frus1977-80v28/d166, 1979), while its own decade
wrote "the Rogers bill" (1923, ×3) and "the Act of May 24, 1924" (1927, ×2). The Foreign Service Act
of 1946 enters document text in 1946 as "Public Law 724" and "60 Stat. 999", not under its title;
the 1914 attaché appropriation is "(38 Stat. L. 500)" — and the *Stat.* form has its own variants
(`"38 stat 500"` matches 0, `"38 stat l 500"` matches 1); the tariff of 1930 is "the tariff act of
1930" 218 times and "Hawley-Smoot" 38. Before publishing "the statute is not named", scan the
act-of-date form, the public-law number, the *Stat.* citation and the bill name.

Two forms of the same error bit a run that had the sentence above pasted into every agent. **The
contemporaries' vocabulary for a relation is the counterpart's, not an older name for the office.**
Over 39,800 documents dated before 1906 the Commerce field service's own nouns return almost nothing
(`"commercial attache"` 1, `"trade commissioner"` 0) and the run published the era as institutionally
silent; the same window returns `"commercial interests"` 338 documents, `"american merchants"` 321,
`"chamber of commerce"` 227, `"board of trade"` 132 — consuls and ministers dealing with named
merchants and chambers. Scan for the counterpart, the object and the transaction, not only for
earlier names of the institution. And **head an absence by what was tested**: "FRUS does not print
the United States and Foreign Commercial Service" was a true count of a post-1980 statutory name (0
in 552 volumes) over a founding that is printed, as a description under the earlier name, in two
1979 documents the same memo had read and quoted — and the next pass re-discovered, then
over-claimed, what the first had already found. "FRUS never uses the name X; the founding is printed
at Y under name Z" is the finding. (Spelling of numbered instruments is §14.4: `No. II` is 0, `No. 2`
is 20.)

### 14.7 Two things that quietly turn a claim into a claim about something else

**Volume year is not document date.** Every periodisation in the first pass of two runs bucketed by
the *volume's* series year. Each `<div type="document">` carries `frus:doc-dateTime-min`/`-max` — the
same editorial dates [§4.3](#43-derived-structure) exposes as `document_dates` — and reading them
costs nothing extra in the same pass. Until you do, a claim like "the Board of Economic Warfare
appears in 1942–43" is a claim about how FRUS was assembled as much as about the agency. State which
you measured. Document date is a range: see §6.4's four traps before publishing a chronology.

**Apparatus is not document text.** Front matter, abbreviation lists, editorial footnotes and the
back-of-book index are all inside the file, and no keyword scan separates them by default.
`type="index"` divs are present in 98 of 99 volumes in one run's scope. Measured effects: index and
front matter hold 5.9% of the corpus's text but carry **18.6%** of `Foreign Service`, 20.0% of bare
capital `Service`, 16.0% of `FSO` — and *the enrichment worsens inside the on-topic volumes*, because
those carry the longest persons lists. In the anchor volume of one question, **335 of 984 marker hits
were bare grade acronyms**, and an agent discovered three of those acronyms by reading that volume's
abbreviation list. Three of the four literal `Rogers Act` occurrences in the TEI are footnote
glosses or index entries; the fourth is a 1979 memorandum's own prose (frus1977-80v28/d166 — the
one document that survives §7.1's eight-document FTS count once its seven *Rogers, Acting*
collisions are removed).

**Two consequences for dates.** An *earliest occurrence* or *first appearance* claim is a
body-surface claim: editors gloss institutions by their later names, so on `body_text` a term
routinely appears before its referent exists — "Foreign Service officer" in a 1922 document (a
footnote, two years before the Rogers Act); "Uruguay Round" in 1985 (a footnote, a year before the
round opened, whose own text says "began in September 1986"); "Bureau of Foreign and Domestic
Commerce" in a 1910 document (an editors' parenthetical; the bureau dates from 1912). Verify every
*earliest* on the TEI with `<note>` stripped, or label it "earliest on `body_text`, footnotes
included". Measured footnote-only shares for institutional families on this corpus run 10–46% of the
FTS document count (`office of international trade` 45.8%; `Foreign Agricultural Service` 34.4%;
`commercial attaché` 11.9%). And an editorial note's `date_iso` is the opening of the span it
narrates (§4.3).

Until you scope hits to their enclosing `<div type="document">`, *"this volume is about X"* and
*"this volume indexes X"* are indistinguishable in every number you publish. This project has already
measured the analogous ratio for cross-references at **95.3% editorial footnote** — see
[§7.3](#73-reference_type-defaults-body-references-to-footnote) — so the skew is the expectation, not
the exception.

**A title is not an office.** When a post moves between departments by statute, the same words name
two employers either side of the date — *commercial attaché* is the Department of Commerce's officer
before 1 July 1939 (Reorganization Plan No. II) and the Foreign Service's after. Split the family at
the date and publish both halves; the undivided decade table read "its peak is after 1939" where
the single peak year, 1936, sits inside the earlier employer's life (632 / 417 across the date, 89
volumes each side). And when two censuses of one institution run opposite ways — 21 documents as
*author*, 123 as *subject* — publish the base beside each direction: a direction on 21 documents
describes 21 documents, not a curve.

### 14.8 The editors' own headings are the highest-precision handle

FRUS volumes carry chapter and section headings — `<head>` inside non-`type="document"` divs — and
the editors reused boilerplate. Where a formula exists it beats term retrieval outright.

For wartime materials, `procure for the United States strategic materials from <country>` returns
**16 headings at ~100% precision**, enumerating the country chapters; three parent headings
(`frus1939v01` "Measures to secure adequate supplies of raw materials:", and its 1940 and 1941
siblings) organise the whole 1939–41 material into subchapter trees. For the Department itself,
`Managing the Department of State` is a verbatim repeated chapter title in exactly two volumes —
corpus-wide only three headings begin `Managing`.

The corollary is a warning about your own vocabulary. **`supply chain` occurs once in all 552
volumes.** The editors' umbrella term is `strategic materials` (24 headings, and only 1937–1945).
Likewise `reform of the Foreign Service`, `reform the Foreign Service` and `modernization of the
Foreign Service` are all **zero**; what FRUS writes is `Foreign Service reform` (8 occurrences, 2
volumes). And the editors head institutions but not abstractions: `economic warfare` returns **0
headings against 1,358 body occurrences**, while `Rubber Reserve Company` gets 12. Read the headings
before writing queries; they are cheap (24,996 non-document headings corpus-wide) and they tell you
the corpus's own words for your subject.

### 14.9 Where the corpus double-counts itself

The 552 bundled volumes include **three second editions** — `frus1951-54IranEd2`,
`frus1969-76ve15p2Ed2`, `frus1977-80v09Ed2` — and for two of them the first edition ships as well.
Both editions appear in `manifest.json` and in `semantic-vectors-index.json`; this is deliberate
publishing, not a defect — but suppress the second edition where a first edition is present before
computing any share.

**And name your surface when you state the size of the overlap**, because §14.3 applies to this
number too and the two available surfaces disagree:

| Surface | Iran pair | ve15p2 pair | Overlap |
|---|---|---|---|
| `semantic-vectors-index.json` | 375 / 375 | 343 / 382 | **718** |
| `document_cache`, apparatus excluded | 358 / 358 | 343 / 382 | **701** |

**The two editions are not interchangeable, which is why the choice of which to drop is not
neutral.** Measured over a full 552-volume index: the Iran pair shares **377 document ids** but only
**277** of them carry identical text, and the `ve15p2` pair shares 345 ids with 335 identical. In
both pairs the `Ed2` is the *later* publication (2018 over 2017; 2021 over 2014). So the conventional
fold — suppress the `Ed2` — keeps the earlier text, which is right for a count and wrong for a quote.
If a claim turns on the wording of a document in either pair, read the volume.

Related, and worth stating once: the semantic artifacts count **314,483** documents, while this
project's own settled corpus figure from its query work is **316,839**. The two count different
surfaces. Whichever you use, name it — a run that publishes densities to two decimals owes the reader
its denominator.

### 14.10 Two bundled artifacts that scope the corpus

The app ships 34 bundled JSON resources. Two of them scope a question against the *corpus*, and
neither is obvious from the schema; the fifteen that scope it against the *archives* (and one
citation-graph index, `resolved-edge-index.json`, tabled beside them) are
[§14.11](#1411-the-second-half-of-scoping-where-the-documents-came-from-and-point-at).

**`volume-subject-profiles-index.json`** carries the Office of the Historian's own subject
vocabulary — 380 subjects in 13 categories, with a per-volume weighted profile. It includes a
`Department of State` category with a `Personnel: Foreign Service` subcategory, and ranking all 552
volumes by that subject's weight recovered the entire relevant volume family unprompted, in agreement
with an independent title scan and an independent density scan. Three routes agreeing is worth more
than any one of them.

The profiles vocabulary is 380 of the 491 document-level tags, and it is floored at both ends by the
generator's own parameters (`GENERICITY_THRESHOLD` 0.10, `MIN_DOC_COUNT` 2, `TOP_N` 15): a subject
tagging more than 10% of tagged documents is dropped as generic (*Trade relations*, df 29,433 of
238,302 = 12.35%), and a subject that never places two documents in one volume's top 15 never
appears (*Consular service*, df 237; *Joint Commercial Commission*, df 28). A subject's absence from
the profiles is by construction; rank it from `document_subject_refs` instead. Sum named subjects,
never a subcategory — *Trade and Commercial Policy/Agreements* has 17 members, eight of them prices,
wages and credit.

**`semantic-map-index.json`** carries 179 unsupervised cluster labels. It is a fast test of whether
your subject forms a region of the corpus at all — and the answer differs sharply by question shape:

| Question | Clusters found | Reading |
|---|---|---|
| Wartime critical materials | **4** clusters, 2,405 documents — `jordana, wolfram, hayes, wendelin`; `chrome, turkish, numan, turk`; `salazar, lagen, portuguese, azore`; `rubber, tin, vile, gwatkin` | Sustained named negotiations cluster hard. The vector layer is the right instrument. |
| Foreign Service reform | **0** of 179 (controls pass: 15 match `soviet`, 5 match `nuclear`) | An institution is not a region of the semantic space. Vectors will not rescue the question. |
| Commercial diplomacy, 1930s | label test: **1** of 179 (controls pass). Cluster-purity harvest: 4 clusters at 25–59% RTAA-stratum share held 1,030 non-stratum documents, 776 of 1,030 (75.3%) commercial by the editors' own headings after a refuter fixed an unanchored `tin` (it matched *PanamaContinued*), 284 of 849 unreachable by all twenty of the project's phrase families; corpus-wide they sized a third editorial stratum of 1,228 documents, 878 outside every prior stratum | A label test is a test of labelling. When a subject is filed by counterpart, the map labels by counterpart (cluster 92 is 59% reciprocal-trade documents and its label is `chalkley · australian · australia · sydney`). |

The map's twenty largest clusters are, without exception, places and crises. That is what it is
organised around, and it constrains what it can find for you. Note also the asymmetry *within* a
question: the wartime *denial* operations clustered; the hemispheric *acquisition* program did not,
because it is distributed across many country files rather than concentrated in a few negotiations.

A 0-of-179 label test rules out a *labelled* region, not the map. Before closing the route, harvest
the clusters where a heading-defined stratum concentrates (≥25% purity) and triage the non-stratum
members by the editors' headings — and budget one in four for geographic contamination. Read the
corpus's own partition before choosing a memo's organising axis: one memo had no geography while the
corpus's own instruments (`611.xx31` came-from keys, the map's neighbourhoods) are organised by
counterpart.

### 14.11 The second half of scoping: where the documents came from, and point at

**This section exists because all three 2026-08 runs failed it.** Each treated the printed document
as the only target. Between them they resolved zero record groups, zero NAIDs, zero series titles,
zero entry numbers — and of the fifteen bundled archival-resolution artifacts (11.83 MB of the 24.79 MB
the app ships), exactly one was ever opened, as a dictionary for glossing a filing code. The
omission was invisible from inside the work; it took someone asking whether the runs had used the
archival layer at all.

**Where they are, since the runs that skipped them were never told.** Every one is in the app
bundle at `/Applications/FRUS Explorer.app/Contents/Resources/` — the directory
[§5](#5-resolving-the-coded-columns) already takes `document-subject-index.json` and `manifest.json`
from — and every one is also committed to the public repository under `FRUSExplorer/Resources/`, so
an agent on a machine with no app installed can still read them. Take them from the build that wrote
your index, for §5's versioning reason.

Every artifact in this table is a projection of NARA's catalogue, and a negative in the bundle is a
negative in the projection. In one run a record group returned 0 hits in eight bundled artifacts
and resolved to 232 series, all Unrestricted, from the record-group harvest the artifacts are built
from — and two fields the projection drops, `recordsCenterTransferNumbers` (the FRC accession a
series was retired under; 240,929 occurrences in the RG 59 shard) and NARA's wider
`coverageStartDate/EndDate` (`series-facts-index.json` carries only the inclusive pair as `y0`/`y1`),
decided four of that run's five archival corrections. When a record group is in the harvest's
coverage list and the bundle has nothing, that is a projection gap, not a structural limit: say
which, check NARA's catalogue for the field, and read a series' own entry number rather than
assuming a record group sits under one finding aid (197 of those 232 carried PI-100; 35 carried
another). The harvest is an owner-local store described in
`Planning/nara-record-group-catalog-runbook.md`; its depth is uneven (RG 256 has a 178 MB shard, RG 429
none; RG 182 has no file units described); counts from it are labelled [HARVEST], carry the snapshot
date (2026-04-09 against bundle stamps 2026-08-09 to 2026-08-28), and are never summed with bundled
counts.

The stack, and the question each artifact answers:

| Artifact | Answers | Scale |
|---|---|---|
| `collection-usage-index.json` | how many documents in volume X came from archival unit Y — **the join that turns any volume scope into a ranked archival target list** | 264,464 notes; 1,839 collections reached; 10,446 class keys |
| `external-citation-index.json` | what the editors cited and did **not** print | 19,800 lot/library refs + 29,890 class refs, 440 volumes |
| `central-files-index.json` | cited lot number → record group, series NAID, HMS/MLR entry number — as a **candidate**. The key is a folded control number, and a match is an identity claim only when both sides mean a lot by it: a Federal Records Center accession (`65 A 987`) and a file label fold the same way and are not lots. Two cheap screens before the date-span rule: does the series' extent hold the box FRUS cites (five inches cannot hold a Box 104), and does its title fit the document type (an undivided lot has one answer, which is unchallenged, not confirmed — `72 D 192` resolves to a series titled *Speeches and Statements*). | 1,065 lot files, all carrying a NAID |
| `collection-authority.json` | which collection is this note naming, under every spelling | 4,429 collections, 1,018 with a NAID |
| `series-facts-index.json` | the pre-travel facts: creator, extent, **inclusive** date span (NARA's wider *coverage* span is not projected — rule 3 below), access status, facility. Its `byNaId` entries use one-letter wire keys with no legend — `as` and `us` (access and use status) → `statuses`, `ar` → `restrictions`, `ur` → `useRestrictions`, `ru` → `referenceUnits`, `c` and `p` (creator and predecessors) → `headings`, `fa` → `findingAidTypes`, `x` extent, `y0`/`y1` the inclusive span — over six separate vocabularies (`statuses`, `restrictions`, `useRestrictions`, `referenceUnits`, `findingAidTypes`, `headings`). Reading `as` through `restrictions` reproduces a plausible wrong value on every row. | 695 series, 397 creator headings |
| `lot-claimants-index.json` | when a lot has several correct NARA answers, which — and, run the other way over your resolved set, which NAIDs several lots converge on | 123 divided lots, up to 13 claimants |
| `presidential-library-catalog.json` | the collections that sit outside every record group | 11 libraries, 3,837 collections, 14,656 series |
| `volume-sources-index.json` | what the editors say they consulted, per volume | 3,412 rows, 251 volumes |
| `decimal-class-labels.json` | what `812.6363` means, compositionally. **ONE schedule, 1910–49**, and the artifact's provenance says a key resolves only against its own era: run a post-1950 key through it and you get a plausible WRONG gloss (`411` = *Claims*; `48` = *British Africa* where the editors gloss `411.48` as Poland), not a miss — gloss 1950–63 keys from `volume_sources` (§4.4). And its 1910–49 country table is wrong or empty on codes FRUS files commerce under (build of 2026-08-11): `60f` = *Ruthenia* (FRUS: Czechoslovakia, 82 documents on `611.60F31`), `47h` = *Cook Islands* (New Zealand, 27); `42` Canada, `43` Newfoundland, `54` Switzerland, `74` Bulgaria, `11b` Philippines absent — 233 documents unnameable, 109 named wrong. Keys are lowercase (`60f`; `document_sources` carries `60F`). A gloss table that answers wrongly is worse than one that fails: before publishing a country name from any bundled table, read one document header filed under the key. [Repo issue: the country table.] | 1910–49 schedule; 9 classes, 198 countries, 693 suffixes |
| `curated-lot-resolutions.json` / `-library-` | the targets NARA's catalogue cannot resolve | 20 lots, 185 library finding aids |
| `digitized-ranges-index.json`, `roll-scans-index.json` | is it already digitised — do I need to travel | 624 ranges, 1,238 roll scans |
| `provenance-flow-index.json` | where the editors sent the reader when they cross-referenced one document from another, as (unit → unit) pairs | 77,792 edges, 4,907 collection pairs; **95.3% are footnotes**, so it describes annotation practice |
| `resolved-edge-index.json` | the inbound half of the citation graph for volumes you have not downloaded (§6.6) | 8,628 cross-volume edges into 5,740 documents from 184 volumes — its `volumes` array (235) is a shared vocabulary of target *and* citing volumes, not a target list (distinct targets: 206), and its own footnote share is 7,622 of 8,628 = 88.3%, not the corpus-wide 95.3% |
| `source-provenance-index.json` | the provenance *mix* — how many documents came from a decimal file, a lot file, a library — per decade and per volume | 268,757 notes, 522 volumes, 16 decades |

Three rules govern using them, and the second is easy to get backwards.

**Report the two archival relations separately, each resolved as far as the indexes reach, and never
sum them.** [§8](#8-provenance-the-citation-chain) already forbids combining `document_sources` with
`external_citations`; the productive form of that rule is that both are worth resolving, because they
answer different questions. Where a document *came from* is a claim about the printed record. What a
footnote *points at* is a lead into what was withheld — and for a question about why something did
**not** happen, that is usually the more valuable channel. Measured on the Cuba scope: 2,823
source-note attributions across 188 units, plus 676 footnote pointers that reach **15 units the
source notes never name**.

**Label the channel and the volume set on every archival count.** This is §14.3's counting-surface
rule on the archival axis, and skipping it produced four unreconciled numbers in this very audit —
the same scope reported as 188 units and 203 units (source-note channel versus the union of both),
and one run's scope appearing as 5, 7 and 8 volumes in three passes. All were correct; none was
labelled.

**A resolution is a candidate until it survives the date-span screen.** Join the citing documents'
`document_dates.date_iso` to the series' span and test overlap — corpus-wide, never on your own
volume subset (a lot's shelf is a property of the lot: `72 D 318` failed on one document and passed
on seven, and one round's "7 of 93" against its critic's "6 of 93" was an undeclared denominator);
against the wider of NARA's two spans (`series-facts` carries only the inclusive pair; of 75 RG 59
series checked, 19 publish both fields, 17 differ, and coverage starts earlier in all 17; the
inclusive field alone produced three false failures over 44 documents — the corpus-wide result is 3
of 93, not 7 and not 6); reading the citing source note before accepting one of several claimants
(`73 D 153`: nine of ten notes say *Morning Summaries*; the index had picked *Special Summaries*);
and diagnosing a survivor rather than deleting it — ask whether the FRUS string is a lot number at
all (the candidate rule in the table above). A one-year overhang at an accession boundary is the
shape of a correct resolution; a twelve-year gap into another subject is not; report the gap in
years. Screen any replacement you offer by the same test — a substitute that fails the screen that
condemned the original is the case the rule exists for. Run the resolved set the other way too:
NARA consolidates as readily as it divides (11 of 81 resolved NAIDs on one scope were claimed by two
or more lots — 23 lots, 294 documents), one series answering two lot citations is one order and not
two (`63 D 351` and `66 D 95`, 112 documents, are one series, RG 59 entry A1 1586E), and a
convergence whose lots all fail the screen is the same wrong answer returned twice — the second
claimant corroborates the error, not the shelf. Write the reference query against the NAID, not the
lot list.

A published resolution carries every claimant the `lot-claimants` index lists for the lot and the
series' access and FOIA status — seven lot rows in one run suppressed a FOIA restriction the
artifact carries, the field a researcher acts on.

Three measured illustrations of what the second half yields, each from a run that published without
it:

- **Cuba.** 203 archival units, 86 with a NAID. The heaviest single target is not in FRUS at all: 272
  footnote pointers into the Carter Library's National Security Affairs (Brzezinski and Staff
  Material). The Nixon NSC Files, 370 documents, carry a sub-series literally titled *Backchannel
  Messages* — that run's question by name.
- **Wartime materials.** 76,764 documents resolve to one target, RG 59 Central Decimal Files
  1910–1963 (NAID 302021), pullable by 89 measured commodity class keys. The run's published
  disclosure — that the BEW, FEA and RFC "contribute zero source notes", so the question is put to a
  corpus where they are structurally invisible — is true of FRUS and **false of the archives**: those
  agencies are separate record groups, and RG 169 and RG 182 are both in the coverage list of the
  record-group harvest the paragraph before the table describes — a projection gap, not a
  structural limit.
- **Foreign Service reform.** The corpus prints almost nothing citeable — `Wriston` appears in 0
  source notes against 38 full-text occurrences. But the office that produced the record resolves to
  nine RG 59 series, **104.1 linear feet, 1955–1980**, all created by the (Deputy) Under Secretary
  for Management, each with a NAID and an entry number, three of them Restricted-Fully. A verdict of
  "the corpus does not hold this" was one lookup away from a bounded research plan.

That last case is the general lesson: **a corpus-scoping negative is not a research negative.** The
answer to "FRUS does not print this" is frequently "and here is the shelf that does" — but only if
the second half of scoping ran.

The answer takes the form of a reference query a researcher can send unchanged: what is known (the
citation as FRUS prints it, box and folder), what is inferred (the nearest resolved neighbours and
where they stop), what is asked (entry number, whether the folders survive, access status). Two
levers reach past the bundled indexes. The editors' front matter often names the Federal Records
Center accession a lot was retired under (`volume_sources`: "…now part of Washington National
Records Center Accession No. 71 A 6682 (15 ft.)"), and NARA records the same accession, with item
numbers, on the series it became — an accession is a join key the lot number is not, so cite
NARA's own item numbers where its catalogue has them (`059-71A6682-9`, `-29`, `-31`, `-33`). And a lot
NARA does not index at all is asked for by the editors' description — office, function, span,
feet — which are handles NARA does hold. Say which units the lever does not reach: a lot named
only inside a document's text has no accession statement to send.

Two cautions, both measured. NARA's creator attribution is itself a decoy surface in the sense of
[§14.5](#145-the-false-friend-test-compare-a-terms-concentration-to-the-corpus-baseline) — it ran at
56% precision on one route here, and the adversarial pass that caught this whole omission
nevertheless mis-filed NAID 27022913 (Bureau of International Organization Affairs) as a Foreign
Service management series. And the offline stack has a hard reach: 11 of 695 bundled series begin
before 1940, so a pre-war archival roadmap is largely unavailable regardless of how well the corpus
covers the period.

### 14.12 Contest your own agent

In all four investigations an adversarial pass earned its place — a second agent given the first's
results and told to find the wrong number, or, when the pass under review reads rather than counts,
the misquotation and the inflated reading count (§8; §9 item 8): re-retrieve every quotation for its
pair, check the claimed count against the raw text, confirm every NAID against the artifact under
the title given. It caught the `ball bearing` hyphen fold; it found one probe had counted decoded
characters and labelled them bytes; it found a term where the *larger* context window produced the
*smaller* count, proving two passes had used different and undisclosed marker sets; and on one
question it corrected the headline figure by **47%**, having noticed that half the "reform
vocabulary" was a job title the pass had itself elsewhere called "the phrase, not the subject".

Cheap practices that make contesting possible:

1. **Every number carries its counting surface** (§14.3) and its denominator.
2. **Every pass reports its controls** (§14.2), so a disagreement can be localised.
3. **Watch for circular context markers.** One probe measured whether `Office of Personnel` occurred
   near personnel vocabulary using a marker set that contained the word *personnel* — scoring a
   circular 100%. Re-run with a non-circular set, the true value was 7.8%. It caught this itself and
   said so; require that.
4. **Give each parallel agent its own scratch directory.** In one run a concurrent session overwrote
   another agent's scan script on disk mid-run.
5. **Expect agents to die, and make the loss cheap.** In a ~200-session run a third of the first
   round's sessions returned nothing (quota, rate limits, a per-call watchdog). Retry an empty
   result once; have every agent write its log and partial results to disk as it goes, so a killed
   session leaves a draft.
6. **A dead agent's draft is a claim, not a result.** Hand it to the successor with the instruction
   to re-run the decisive queries, correct what is wrong, and say which numbers it re-derived. Keep
   the dead attempt's query labels separate from the delivered ones.
7. **Prove the environment with one cheap agent before launching a fleet**, on the exact invocation
   the prompts print, against a known answer. In one round a hung model setting cost four hours of
   a fleet that produced nothing before a transcript read found it, and a wrong shell flag cost the
   first call of every agent that used it; one agent run on the exact command against a known
   answer would have caught either in ten seconds, before the fleet launched. If your harness
   resumes a run from cache, a finished agent's prompt is frozen: append a correction only to the
   agents still to run, or every finished one runs again.
8. **Reconcile the report against its own tables before anyone else does.** Diff every figure that
   appears twice, and every prose sentence against the table beneath it. In one round ten of
   twenty-eight verdicts found a contradiction inside the report they were checking — a uniqueness
   claim against a count printed three sections earlier, "18 volumes" over a list of 16, "none
   between 1952 and 1958" over a table that listed four. It costs no query.
9. **Report the window beside any proximity-derived claim, and show the count at a second width.**
   "1,037 never attach the phrase to the United States" rested on a 60 + 45-character window; at ±250
   characters the set is 811 and "four fifths" is 64%. A window test supports "not attached within
   ~105 characters"; it cannot support *never*.
10. **A republished number is re-derived or labelled "inherited, not re-derived"**, and a
   correction re-derives the other figures in the same sentence (one fix pass "audited what the
   reviewers pointed at and nothing adjacent to it"; §14.14 rule 3 carries the measured case).

Budget the adversarial layer as a peer of the threads, not an add-on. In the 2026-09 three-round
run — about 200 agent sessions over roughly a day — 60 sessions were refuters and, by the harness's
own accounting, they wrote about half of all output tokens; the item they caught most often was the
wrong number. The same accounting put the whole loop near $2,800 at first-party API rates with 96%
of input served from cache, which is why byte-stable prompts (item 7) are what make a repeated or
resumed run affordable. Record your own figures under §13. Hand the refuter the query log, not only
the report: 43 of 60 verdicts in that run cite `queries.log`, and the failures it found — a label
that resolves to nothing, a disjunct the report omits — are visible only there.

None of this makes an agent trustworthy. It makes an agent *checkable*, which is the property this
whole guide is about.

### 14.13 Superlatives are claims over a scope

*Only*, *first*, *earliest*, *last*, *none*, *never*, *anywhere in FRUS*, *no X other than Y* are the
sentences round-1 verifiers of the 2026-09 run refuted most often — sixteen of twenty-eight
verdicts, and in every case the counter-example was one query away. Three rules:

1. **Name the scope the word is true over.** "The only such heading in the 244 volumes scanned" is a
   finding; "the only such heading in the series" written from the same scan is not.
2. **Run the falsifier over the unrestricted surface, not the working set.** A superlative
   established from a filtered heading file, a hand-picked volume list, a lookup of named leads or a
   `volume_id`-sorted hit list has not been tested. `ORDER BY date_iso` before any *earliest*;
   `GROUP BY` before any *only*.
3. **Print the falsifying query beside the sentence**, with its result — including the zero.

Measured: "all 24 dated 1961–63" (nine were 1964–67); "the earliest-dated document on this thread
anywhere in FRUS", 1851 (an 1826 commercial treaty sat in the same appendix); "not described
contemporaneously anywhere in the 550 volumes" (one telegram, frus1939v02/d617, described it); "no
record group other than RG 59 on any document in the window" — 1,547 RG-256 documents.

### 14.14 Revising a prior round

When a second pass claims to correct a first — "round 1 never read X", "round 1's figure was Y",
"this family was counted nowhere" — the claim about the prior round is itself a measurement, and in
one three-round investigation it failed more often than the arithmetic did: the refuters found every
thread's numbers reproducing exactly and its change-claims failing in five of nine, and the memo's
own §4 opened with "round 1 mentions this institution zero times" when the prior memo mentioned it
five times and published the same counts.

1. **A claim about what a prior round said is a grep over its final files, and the command is
   shown.** "Round N never names X" is `grep -c` over round N's memo, scope and thread reports with
   the count; "round N never read X" is a search of round N's quotation-verification log. Grep the
   files as they stand *after* round N's fix pass: the false "zero times" above was copied from
   round 1's own critic, which had been right before the fix pass added the row. A reviewer's
   description of a round is a claim to verify, not a source. The true claim is usually narrower
   ("the memo did not; the thread report did") — publish that one.
2. **Every changed finding goes in a four-column table** — *claim as published · corrected value ·
   decisive query · which side the re-run supported* — including rows where the re-run supported the
   original and rows where it supported neither. The scorer that caught the round-2 failures found
   that all three were claims that had escaped the table.
3. **A fix pass re-derives what is adjacent to the correction, not only what the reviewer pointed
   at.** Measured: one section's re-derived number was exact and its three inherited neighbours were
   all wrong, and the one fix-pass figure that failed was "a figure added quickly to answer a
   reviewer, not re-derived".
4. **Every open thread the prior round listed is answered, carried, or dropped with a reason.** Two
   of twenty-five were dropped silently in one round, both bodies the investigation had already
   sized.

The rubric item that enforces 1 and 2: *every claim that round N+1 changed a round-N finding is
backed by the decisive query on both sides.* Round 2 of that investigation failed it; round 3, with
48 table rows, did not.

### 14.15 Ask a critic when to stop, and make it show its work

The adversarial pass in §14.12 finds the wrong number. It does not find the missing modality, the
key document named and never read, the era's own vocabulary nobody scanned, or the point at which
another round would confirm arithmetic rather than learn anything. One agent per round can, if its
brief asks for a verdict: a critic asked only for "open threads" returned fifteen every time and no
verdict; the same role, asked for CONTINUE or STOP with evidence, returned CONTINUE with a condition
in one round and, in the next, an argued STOP — "my strongest case for CONTINUE fails on inspection,
and I want to be explicit about that because it is the honest test."

Ask for, in this order: N headline numbers re-derived (eleven of twelve reproducing is a reason to
stop counting); the artifacts not yet opened, by name (the corpus's own unsupervised partition,
`semantic-map-index.json`, went unopened for two rounds and, opened, showed the subject had no cluster
of its own); five era-appropriate terms run with controls (two of fifteen were bodies of 250–430
documents with no row anywhere; the ninth, tenth and eleventh institutional terms returned single
digits, "which is what a saturated vocabulary looks like"); three archival resolutions attempted and
every published resolution screened by date span; the documents every prior pass named and none read,
with one of them read; a ranked list of at most 15 threads, each *what · which surface · why*, sized
in documents and sorted into reading, corrections and residue; and **an explicit CONTINUE or STOP** —
the case for stopping as numbered evidence, the strongest case for the other verdict stated and
tested, and if CONTINUE a success criterion that does not renew itself ("documents read and quoted,
from a fixed list"), if STOP what a further round would and would not add and the residue that
belongs in an archive. A sized list becomes a reading list; an unsized one becomes another scoping
round. The critic is one agent against a round's refuters (eighteen in that run's second round,
fourteen in its third; §14.12 counts 60 over the run), and its own claims about what the run
contains are subject to §14.14 rule 1 — one critic's "zero mentions in round 1", true when
written and false after the fix pass, became the next memo's false sentence.

---

## 15. Writing a collection the app can open

Everything above is read-only. This section is the one place the traffic runs the other way: an
agent's candidate list can be written as a `.fruscollection` file, which the researcher opens and
edits in the app like any other collection. That closes the loop — the shortlist stops being text
in a chat window and becomes an object with documents in it.

The format is a plain JSON file with a versioned, **tolerant reader**: unknown keys are ignored,
unknown entry kinds are skipped rather than misdecoded, and the compatibility gate is explicit. You
do not need the app's source to write one.

### 15.1 The write-minimum

Every key below is required. There are no others you must supply.

```json
{
  "format": "fruscollection",
  "formatVersion": 1,
  "name": "Escalation rhetoric — round 1",
  "composition": {
    "defaultBodyDepth": "full",
    "footnoteStyle": "all",
    "tocStyle": "citation",
    "applyHighlights": false,
    "includeNotes": true,
    "includeWordCloud": false
  },
  "entries": [
    { "kind": "heading", "text": "Strong candidates" },
    { "kind": "document", "volumeId": "frus1961-63v11", "documentId": "d1" },
    { "kind": "document", "volumeId": "frus1964-68v32", "documentId": "d17" }
  ]
}
```

Those bytes are a test fixture in this repo, not an illustration. If they stop opening, the suite
fails.

| Key | Notes |
|---|---|
| `format` | Must be exactly `"fruscollection"`. Anything else is rejected outright rather than imported as empty. |
| `formatVersion` | `1` is right for a hand-written file. See §15.3 before raising it. |
| `name` | The collection title. |
| `composition` | All six keys above are required; the values shown are the app's own defaults for a new collection. |
| `entries` | Array order **is** collection order. May be `[]`. |

Each entry needs only `kind`. The kinds are `document`, `heading`, `prose`, `excerpt` and
`generated`; for writing a candidate list you want the first two. A `heading` carries its title in
`text`; a `document` carries `volumeId` and `documentId` — the same pair everything else in this
guide is keyed by.

Save with a `.fruscollection` extension. The file pickers match on the extension, so a `.json` file
with perfect contents will not be offered.

### 15.2 One constraint the app does not enforce

**A `document` entry MUST carry both `volumeId` and `documentId`.** Omit either and the file still
opens, the collection still lists the entry, and every export of it is silently empty — the ids are
coerced to empty strings on import and filtered out by every downstream resolver, with no error at
any point.

This is the worst failure shape available to an agent-written file, so treat it as a hard rule on
your side. Nothing will tell you.

The checks, against the copy of the index the list was written from — every rule in this section
and [§14.9](#149-where-the-corpus-double-counts-itself)'s edition fold:

```python
import json, sqlite3, sys
path, db = sys.argv[1], sys.argv[2]        # the .fruscollection, and the index it was written from
c, problems = json.load(open(path)), []
if not path.endswith(".fruscollection"): problems.append("extension is not .fruscollection")
if (c.get("format"), c.get("formatVersion")) != ("fruscollection", 1): problems.append("format gate")
missing = {"defaultBodyDepth", "footnoteStyle", "tocStyle", "applyHighlights", "includeNotes",
           "includeWordCloud"} - set(c.get("composition", {}))
if missing: problems.append(f"composition keys missing: {sorted(missing)}")
docs = [e for e in c.get("entries", []) if e.get("kind") == "document"]
pairs = [(e.get("volumeId") or "", e.get("documentId") or "") for e in docs]
if any(not v or not d for v, d in pairs): problems.append("an entry lacks volumeId or documentId")
if len(pairs) != len(set(pairs)): problems.append(f"{len(pairs) - len(set(pairs))} duplicate pairs")
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
known = set(con.execute("SELECT volume_id, document_id FROM document_cache"))
absent = [p for p in pairs if p not in known]
if absent: problems.append(f"{len(absent)} pairs not in document_cache, e.g. {absent[:3]}")
vols = {v for v, _ in known}
twins = sorted({v for v, _ in pairs if v.endswith("Ed2") and v[:-3] in vols})
if twins: problems.append(f"Ed2 beside its first edition (§14.9): {twins}")
print(len(docs), "documents;", "; ".join(problems) or "all checks pass")
sys.exit(1 if problems else 0)
```

A pass prints the document count and `all checks pass`; anything else names the rule broken and
exits 1.

### 15.3 Versions, and stamping your own provenance

The reader's gate is `minimumReaderVersion` when present, and **`formatVersion` when it is absent** —
not 1, which is a distinction worth knowing if you are tempted to write a higher `formatVersion`. A
file declaring `formatVersion: 3` with no floor is *rejected* by a version-2 reader; the same file
declaring `"minimumReaderVersion": 1` is accepted and its unknown features ignored. Write
`formatVersion: 1` and no floor unless you have a reason.

**Unknown top-level keys are free.** You may stamp provenance without any format change:

```json
"generator": "my-agent/1.0, 2026-08-31, query: escalation rhetoric"
```

The app ignores it. It also does not preserve it: a collection re-exported from the app drops the
key, deliberately — that file was written by the app, not by you, and carrying your stamp forward
would be a claim the file cannot support.

### 15.4 What this is good for, and what it is not

Good for: handing back a ranked candidate list as something the researcher adjudicates by reading;
grouping it with headings so your reasoning survives the hand-off; round-tripping, since a
collection exported *out* of the app is the same format and you can read the researcher's curation
back.

Not good for: asserting anything. A collection is a reading list. It carries no claim that the
documents are related, and the researcher's judgement is applied after they open it — which is the
division of labour [§10](#10-what-frus-is-as-evidence) argues for throughout.

---

## Appendix A: The semantic vector artifacts

The database is not the only structured layer FRUS Explorer ships. The app also carries a set of
**semantic vector artifacts** — a neural embedding of every document in the corpus, quantized and
packed for on-device retrieval — and they are just as usable by an outside agent as the SQLite
index is. Everything in this appendix was verified against the shipped files: the binary headers
parse as documented, the id encoding round-trips for all 552 volumes, and every worked example
below was executed as shown.

One structural fact frames all of it: **the shipped artifacts are complete for document-to-document
work with no embedding model at all** ([§A.5](#a5-what-an-agent-can-do-with-no-model)). Related
documents and the map are anchored on an existing document, so an outside agent can reproduce every
one of them from the bundled files alone.

Free-text queries are the exception, and they need the embedder
([§A.7](#a7-free-text-queries-require-the-embedder)). *(Corrected 2026-08-31: this paragraph used to
say "the app itself never embeds free text." Build 44's Search by Meaning falsified that — the app
now embeds queries on-device — and the query-side prompt it uses is named in §A.7 rather than left
to you.)*

### A.1 What ships, and where

| Artifact | Contents | Where |
|---|---|---|
| `semantic-vectors-index.json` (~73 KB) | Identity and provenance: per-volume row offsets, run-length-encoded document ids, the provenance pin, measured retrieval parameters | App bundle `Resources/` |
| `semantic-vectors-binary.bin` (~19.5 MB) | Tier 1: one 512-bit **sign vector** per document (314,483 of them), then 659 int8 **centroids** (552 volumes + 107 subseries) | App bundle `Resources/` |
| `<volume>.vec` shards (~150 KB each) | Tier 2: full **int8 512-dim vectors** with a per-document scale, one file per volume | `…/Application Support/FRUSExplorer/SemanticVectors/` |
| `semantic-map.bin` (~1.9 MB) | One `(int16 x, int16 y, uint16 cluster)` placement per document — a 2-D UMAP layout with HDBSCAN clusters | App bundle `Resources/` |
| `semantic-map-index.json` (~25 KB) | Per-cluster labels (c-TF-IDF terms), centres, document counts, era histograms | App bundle `Resources/` |

The bundle path on macOS is `/Applications/FRUS Explorer.app/Contents/Resources/`. The Tier-2
shards live beside the database in Application Support and exist **only for volumes whose vectors
have been fetched** (by default that tracks volume downloads; Settings ▸ Storage controls it) —
whereas Tier 1 and the map cover the **entire 552-volume corpus regardless of your library**. That
asymmetry cuts both ways: semantic neighbors can point at documents you cannot open locally
(resolve them via the canonical URL), and the semantic tier is the one place in the app's data
where a claim about the *whole* corpus is actually possible.

### A.2 The provenance pin, and the one family rule

Every artifact carries the same 32-byte SHA-256 **provenance digest**, computed over everything
that changes the numbers: model id, GGUF weight hash, native and shipping dims, chunking, the
document prompt (trailing space included), the pooling rule, and the quantization rules. The
index carries it as `provenanceDigest` (hex); each binary carries it in its header at offset 20.

The family rule is: **no consumer may mix two generations.** A shard from one generation must
never rescore candidates from another — refuse, re-fetch, or degrade, never blend. For an outside
agent that means one check before any scoring: read the digest from each file you touch and
compare. Verified on the shipped set: index, corpus binary, and map all carry the same digest.

### A.3 Document identity: stored, never derived

Rows in the binary tier are keyed by the index's `volumes` table: each volume states its
`rowOffset` (`r`), its document count (`n`), and its ids as run-length-encoded segments (`seg`).
**Do not guess ids from ordinals.** The obvious rule — document at ordinal *i* is `d{i+1}` — was
measured against this corpus and mis-keys 15,097 documents (4.8%), because a single letter-suffixed
id (`frus1865p1`'s `d373a`) shifts every document behind it. A wrong key here never fails: every
vector still resolves and every score is plausible; the neighbors shown just belong to different
documents than the ones named.

The faithful decode (mirroring `SemanticVectorsKit/DocumentIDSegments.swift`): a run only ever
forms over ids that are exactly `d` + digits with no redundant leading zero; anything else
(`d373a`, `appA`) is a literal single-document segment.

```python
def numeric_part(doc_id):
    if not doc_id.startswith("d"): return None
    digits = doc_id[1:]
    if not digits or not digits.isdigit(): return None
    if len(digits) > 1 and digits[0] == "0": return None
    return int(digits)

def decode_segments(segments):          # one volume's "seg" array
    ids = []
    for seg in segments:
        assert seg["s"] == len(ids)     # segments are in row order
        ids.append(seg["i"])
        if seg["n"] > 1:
            base = numeric_part(seg["i"])
            ids.extend(f"d{base + k}" for k in range(1, seg["n"]))
    return ids
```

Run the round trip before trusting anything built on it — decoded length must equal `n` for every
volume (verified: 552 of 552 on the shipped index).

### A.4 Binary layouts

All three binaries share the shape: a 64-byte little-endian header, then flat arrays. Read `dims`
from the header rather than hard-coding 512 — the shipping width is a regeneration lever.

```
semantic-vectors-binary.bin                      <volume>.vec (Tier-2 shard)
0   magic "FRSV"              4 B                0   magic "FRSS"              4 B
4   version                   4 B  UInt32        4   version                   4 B  UInt32
8   shipping dims             4 B  UInt32        8   shipping dims             4 B  UInt32
12  document count            4 B  UInt32        12  document count            4 B  UInt32
16  centroid count            4 B  UInt32        16  provenance digest        32 B
20  provenance digest        32 B                48  zero padding             16 B
52  zero padding             12 B                64  int8 codes      docs × dims B
64  sign bits      docs × dims/8 B               ..  scales          docs × 4    B  Float32
..  centroids  centroids × (dims+4) B
    (int8 codes, then Float32 scale)

semantic-map.bin
0   magic "FRSM"              4 B
4   version                   4 B  UInt32
8   document count            4 B  UInt32
12  cluster count             4 B  UInt32
16  grid extent               4 B  UInt32
20  provenance digest        32 B
52  zero padding             12 B
64  placements       docs × 6 B  (int16 x, int16 y, uint16 cluster; 0xFFFF = unclustered)
```

Sign bits are packed **MSB-first, and a zero component packs as a set bit** (the rule is `>= 0`).
Centroids follow the sign-bit block in a fixed order: the 552 volumes in index order, then the 107
subseries in the index's `subseries` order. Dequantize any int8 vector as `code × scale`.

### A.5 What an agent can do with no model

**Nearest neighbors of a document, corpus-wide.** XOR-and-popcount over the sign bits. Executed
against the shipped binary, the ten nearest neighbors of `frus1861/d111` are:

```
hamming  87  frus1862/d130        hamming  91  frus1861/d163
hamming  87  frus1862/d455        hamming  91  frus1861/d212
hamming  89  frus1861/d39         hamming  91  frus1862/d462
hamming  90  frus1862/d457        hamming  96  frus1863p2/d165
hamming  90  frus1865p3/d5        hamming  97  frus1864p4/d212
```

— all Civil War-era diplomacy, which is what a working index looks like.

Calibrate before reading any distance, against **two** baselines. Random pairs at this digest
(20,000, `default_rng(1877)`): mean 193, sd 17, 1st percentile 152, minimum ~100 of 512 — the list
above at 87–97 is far outside chance. But every nearest-neighbour list is a tail of that
distribution by construction, so a neighbour at 126 is not "top 0.1%" evidence of a link: the
corpus's median document has its 25th-nearest neighbour at 124, and one document whose nearest
neighbour in the whole corpus sits at 126 is a semantic isolate. Judge a neighbour against the
k-th-neighbour distribution and a set's cohesion against random pairs; a random 512-bit pattern has
minimum 215 to the corpus. Recompute both after any regeneration.

The core loop, given the `row_of`/`doc_of` maps built from §A.3's decode:

```python
import struct, heapq
blob = open("semantic-vectors-binary.bin", "rb").read()
ver, dims, docs, cents = struct.unpack("<IIII", blob[4:20])
bpr = dims // 8

def sign_row(row):
    o = 64 + row * bpr
    return int.from_bytes(blob[o:o+bpr], "big")

anchor = row_of[("frus1861", "d111")]
q, best = sign_row(anchor), []
for row in range(docs):
    if row == anchor: continue
    d = (q ^ sign_row(row)).bit_count()
    if len(best) < 10: heapq.heappush(best, (-d, row))
    elif -best[0][0] > d: heapq.heapreplace(best, (-d, row))
```

A full scan is milliseconds in a compiled language and a few seconds even in pure Python; no ANN
index is needed at this scale (the app measured its own full scan at 1.43 ms and decided the same).

**Semantic joins into the database.** This is where an agent goes past the app's own UI: take a
neighbor set or a cluster's members, then join `(volume_id, document_id)` into `document_dates`,
`document_sources`, or `person_mentions`. "Documents semantically near this memo but from a
different decade / a different archive / never citing this person" are one query each — questions
neither the vectors nor the database can answer alone. Vectors also recover what FTS structurally
misses: vocabulary drift across 165 years, and the French and Spanish enclosures that porter
stemming mangles.

**Volume and subseries similarity, and outliers.** The centroid block gives every volume a vector.
Executed against the shipped file, the volumes nearest `frus1861` by centroid cosine are
`frus1862` (0.976), `frus1863p2` (0.967), `frus1866p1` (0.957) — the adjacent Civil War annuals,
as they should be. A document's distance from its own volume's centroid is an off-the-shelf
outlier detector: "the least typical document in this volume."

**The map.** Six bytes per document give a 2-D position and a cluster; the map index names each
cluster with sampled c-TF-IDF terms and an era histogram. Verified example: `frus1881/d625` sits
in cluster 0, whose terms are `shah, iran, iranian, mosadeq` — a nineteenth-century Persia
despatch landing in the same region as the 1950s Iran crisis, which is exactly the kind of
long-arc continuity the layout exists to show. 88,207 of 314,483 placements (28.0%) are
unclustered (`0xFFFF`); that share is a property of the corpus, not an error, and any figure built
on clusters owes the reader the number. The 28.0% is corpus-wide and strongly era-dependent — 46.7%
of 1861–1899 documents are unclustered against 22.3% of 1945–1964 (working scope: apparatus
excluded, Ed2 folded). Compare any set's unclustered share to an era-matched baseline, never to 28%.

**Near-duplicate detection.** FRUS reprints some documents across volumes. Very small Hamming
distances flag reprints — worth running over any sample before counting anything, so a document
printed twice is not counted twice.

### A.6 Reranking with Tier-2 shards

The bundled sign bits are the recall stage; the shards are precision. The app's measured funnel —
take the ~800 best Hamming candidates, rerank by int8 cosine — reaches **recall@10 of 0.851**
against exact float-768 neighbors (the figure is stated in the index's `retrieval` block, with the
measurement's citation). Scoring against a shard: for documents *a* and *b* with codes and scales,

```
cosine(a, b) ≈ scale_a · scale_b · dot(codes_a, codes_b)
```

(vectors are L2-normalized before quantization, so the dot product *is* the cosine up to
quantization error). Shard rows are in the volume's row order — identity again comes from the
index's segments, never from the shard, which deliberately carries no ids. Remember shards exist
only for fetched volumes; a missing shard is *typed-unavailable*, not zero similarity.

### A.7 Free-text queries require the embedder

To ask the corpus a question in words ("naval blockade diplomacy") rather than by anchor document,
you must produce a query vector in the same space, and the provenance pins exactly what that
means: model `text-embedding-embeddinggemma-300m-qat` (Google's EmbeddingGemma-300m, publicly
distributed), the GGUF's SHA-256 (in the index — verify your download against it), document
prompt `"title: none | text: "` with its trailing space, 3,200-character chunks with 480 overlap,
char-length-weighted pooling of unit-norm chunk vectors, Matryoshka truncation to the shipping
width, L2 renormalization — then int8- or sign-quantize by the rules in §A.4 to score.

**The query-side prompt is now in the repo, and public** *(corrected 2026-08-31; this appendix
previously said the app never embeds queries, which was true when it was written and stopped being
true at build 44)*. The app ships on-device query embedding: it fetches the pinned EmbeddingGemma
GGUF and encodes through `SemanticQueryEncoder.encodeQuery`
(`FRUSExplorer/Semantic/SemanticQueryEncoder.swift:225`) under

```
SemanticQueryPrompt.queryPrefix = "task: search result | query: "
```

(`SemanticVectorsKit/SemanticQueryPrompt.swift:30`). Use it verbatim, trailing space included. It is
asymmetric with the document prompt on purpose — that is EmbeddingGemma's convention, not an
oversight — and a query embedded under a different prefix lands in a different region of the space,
which does not fail so much as quietly return worse neighbours.

**You probably already have the weights.** If you have used Search by Meaning, the app fetched the
pinned GGUF and checked it against the published length and SHA-256 before keeping it. Rather than
downloading 229 MB again and trusting a URL, reuse the copy the app validated:
**Settings ▸ Volumes & Storage ▸ Natural-Language Search** shows the file's location, with *Show in
Finder* and *Copy Path* on macOS. The path appears only while a verified copy is present, so a path
you can see is a file that passed its check.

The prompt itself is in the artifact too: `semantic-vectors-index.json`'s `provenance.queryPrefix`,
so the index is self-describing on both sides. It is published but deliberately **not** part of the
provenance digest — adding it changed no artifact's identity, and every previously downloaded shard
stayed valid. An artifact generated before this field existed simply omits the key.

**The caveat that stands:** the 0.851 recall was measured **document-to-document**. Nothing has
measured text-query retrieval, so validate on queries you can check by hand before trusting it in
bulk. The prompt being pinned removes a source of variance; it does not supply the missing
measurement.

### A.8 What the vectors cannot tell you

The database caveats in §7 all still apply — and the semantic layer adds its own:

- **Similarity is a lead, not evidence.** A neighbor is a reading suggestion. Nothing about
  embedding distance supports "these documents are related" as a historical claim; the claim comes
  from reading them, with the vector as the finding aid that got you there. Compare like statistics.
  A minimum-to-a-set is not comparable to a mean over pairs; the matched control for 'candidates are
  closer to the stratum than members are to each other' is min-to-nearest-member on both sides, and
  it inverted the published sentence when run (88.3 for members, 123.5 for candidates).
- **Vectors pool whole documents, footnotes included.** Each document is one vector — a weighted
  mean over its chunks, editors' annotation and all. Long documents blur; the chunk vectors that
  could localize a match are not shipped.
- **The neural layer is not reproducible.** The embedding was produced by an owner-run harvest;
  you cannot regenerate it, only cite it. Record the provenance digest and the index's `generated`
  and `harvestGenerated` stamps the way you would cite an edition, and re-record them after any
  app update — a regeneration changes every neighbor list.
- **The map is a projection.** Clustering ran on the 2-D embedding, not the 512-dim space — the
  layout's input was the 256-dim cut (`layout.sourceDims`), not the shipped 512-bit sign block; map
  neighbours and Hamming neighbours are two measurements. 28% of documents are unclustered; the
  28.0% is corpus-wide and strongly era-dependent — 46.7% of 1861–1899 documents are unclustered
  against 22.3% of 1945–1964 (working scope: apparatus excluded, Ed2 folded). Compare any set's
  unclustered share to an era-matched baseline, never to 28%. Labels are c-TF-IDF over a *sample* of
  each cluster's members. Use clusters to explore and to sample, not to measure.
- **Recall 0.851 means misses.** Roughly one to two of any document's ten true nearest neighbors
  are absent from the shipped funnel's answer. Fine for discovery; fatal for any claim of the form
  "no similar document exists."

A short addendum for the §12 house-rules block, when a session touches the vectors:

```text
SEMANTIC VECTORS
- Identity comes ONLY from semantic-vectors-index.json's id segments. Never derive an id from
  an ordinal or a rowid.
- Before scoring, compare the 32-byte provenance digest across every artifact you touch; on any
  mismatch, stop and say so. Never mix generations.
- Report semantic neighbors as suggestions with their distances, never as evidence of a
  relationship. Similarity claims require reading the documents — and say which baseline each
  distance is measured against (random-pair mean 193 / sd 17, or the k-th-neighbour distribution)
  at the digest in use.
- Tier-1 covers all 552 volumes even when the SQLite index does not: flag any neighbor whose
  volume is absent from document_cache, and cite it by its canonical URL.
- Absence of a neighbor is not evidence of absence: the funnel's measured recall@10 is 0.851.
```


## See also

- [macOS User Manual](macOS-User-Manual.md) — the app's own analytics, search, and Source Explorer
  cover many of these questions with the caveats already built in. Try the built-in surface before
  writing SQL; it is often both faster and safer.
- [iOS / iPadOS User Manual](iOS-User-Manual.md)
- [`CLAUDE.md`](../CLAUDE.md) — the maintainer's reference, including every bundled index and the
  generator that produces it. The measured caveats recorded there are the source of several
  statements in this guide.
- [Citing FRUS](https://history.state.gov/historicaldocuments/citing-frus) — Office of the Historian.

---

*Version history*

- 1.11 — 2026-09-04: the docs pass from the 2026-09-01/02 commercial-diplomacy run — three rounds
  over the full 552-volume index with this guide's §12 block pasted into every agent, about 200
  agent sessions, scored **22 of 23 → 23 of 26 → 29 of 29** rules obeyed as the round scripts added
  rules the guide lacked, and an argued STOP from the round-3 critic. Every revision was checked
  against the guide's own text by an adversarial pass (six miners, six checkers: 0 dropped whole,
  10 kept as written, 46 amended) and is listed with its evidence, run file by run file, in
  `Planning/Agentic-Guide-Revisions-2026-09-04.md`. **§2 and §3** gain the shell read-only form
  (`sqlite3 -readonly`, or a `file:…?mode=ro` name with no flag — there is no `-uri`), a proof that
  changes nothing if it is wrong, and the ten-second canary before a fleet; **§3** the tool-call
  discipline (slice, checkpoint, flush; never `cat` a memo into context; "read in full" means the
  captured length equals `length(body_text)`). **§4.4**: the 1950 decimal renumbering with the
  lettered country keys, `external_citations`' 1910 floor and grammar, and `volume_sources` as the
  editors' own gloss table for post-1950 keys. **§6.2** the count form (`rowid IN (…)`, 0.3 s where
  the join form ran five minutes) and the phrase that walks the corpus; **§6.4** the decade table
  with the rate rule and four date traps; **§7.1** the three stem mechanisms and the literal-share
  rule; **§8** quotations checked by machine and the elision rules `body_text` forces; **§9** six
  edits, including item 8, *measure the reading* (documents read whole, documents quoted, passages);
  **§13** four rows the record lacked (your own writing and how many rows; model, sessions and cost;
  the exact text each agent was given; tool versions) and a queries row that demands the pattern
  actually executed. **§14.11** gains the date-span screen as a third rule and the offline NARA
  harvest as a fourth surface, labelled `[HARVEST]` and never summed with a bundled count; **§14.12**
  grows from four practices to ten; and three subsections are new — **§14.13** superlatives are
  claims over a scope, **§14.14** revising a prior round, **§14.15** ask a critic when to stop.
  **§14.7's** sentence on the `Rogers Act` contradicted the guide's own record and is corrected:
  three of the four corpus hits are footnote glosses or index entries, the fourth is a 1979
  memorandum's own prose. Further additions to §4.2, §4.3, §5, §6.5, §7.7, §14.2–§14.6, §14.10, §15
  and Appendix A are itemised in the plan. **One caveat.** §12's block gained twenty-four lines
  on 110 (134 now), and none of them has been re-measured: v1.10's block is the instrument that C-0
  and C-2 scored at 99%, and the C-0 harness is owed a re-run on the revised block before v1.11's
  block is declared the instrument. *(Commercial-diplomacy run, plan Part 1; Part 2, the skill, is
  deferred.)*

- 1.10 — 2026-08-31: the four documentation defects the L-8 assessment named or its implementation
  exposed. **§4.7** documents the two things the app's export now adds and a hand-made copy does not
  — a `research_provenance` stamp (with `my_writing_included`, the one fact that told a stripped copy
  from an unstripped one, and nothing did before) and three `research_*` views that make four of §12's
  rules structural. **§12 gains a SURFACES preamble, per-rule `[TEI]`/`[JSON]` tags and a
  surface-routing table**: three of its scoping rules cannot be executed against the database at all,
  and an agent handed only the index was previously left to discover that or, worse, not to.
  **§12's Ed2 rule is rewritten** — its parenthetical named the first editions while the sentence
  said to suppress the twins, which reads as an instruction to delete the wrong volumes. **§14.9
  names its surface**: the 718-document overlap is the vector artifacts' figure and the index's is
  701, and the two editions turn out not to be interchangeable (377 shared ids in the Iran pair, 277
  with identical text; the `Ed2` is the later publication in both pairs). **§14.11 states where the
  artifacts are** — the same bundle directory §5 already names, and the public repository — and gains
  the two rows that were counted in its own "fifteen" but missing from its table. *(Wave W-19, row
  L-8 residue.)*

- 1.9 — 2026-08-31: §8 gains the `frusexplorer://document/{volume_id}/{document_id}` deep link, so a
  citation in an agent's output is one click from the rendered document. *(Wave W-19, row L-5.)*

- 1.8 — 2026-08-31: §13 gains **Copy Research-State Record** — the reproducibility record this
  section asks for, as one paste from Settings ▸ Storage ▸ Index Health. Notes the two rows it
  deliberately does not carry (the queries, already exported better by the method appendix; and the
  date of *your* `.backup`, which the app cannot know) and the one it adds that the table predates
  (the FTS schema version, a second stamp that independently triggers a rebuild). *(Wave W-19,
  row L-7.)*

- 1.7 — 2026-08-31: §A.7 gains the two things that stop an agent re-fetching and guessing: the app's
  validated GGUF is reachable from Settings (Volumes & Storage ▸ Natural-Language Search), and the
  query-side prompt is now IN the artifact as `provenance.queryPrefix`. Published but not digested,
  so adding it changed no artifact's identity and every downloaded shard stayed valid — verified by
  regenerating: the digest and the 19.5 MB binary are byte-identical, and all 552 shard hashes are
  unchanged. *(Wave W-19, row L-4.)*

- 1.6 — 2026-08-31: §2 gains **"Or let the app do it"** — macOS Settings ▸ Data & Recovery now runs
  this section's recipe and §11's strip as one action, with the integrity check reported rather than
  assumed. The by-hand instructions stay, because iOS has no route to the file. *(Wave W-19, row
  L-2.)*
- 1.5 — 2026-08-31: **§15, writing a collection the app can open** — the first section in this guide
  where the traffic runs toward the app rather than away from it. Publishes the `.fruscollection`
  write-minimum (five top-level keys, six composition keys, one required key per entry), the
  version gate's actual rule (absent `minimumReaderVersion` falls back to `formatVersion`, **not**
  to 1), and the free `generator` stamp with the reason the app drops it on re-export. §15.2 states
  the one constraint the app does not enforce: a `document` entry missing either id imports, looks
  populated, and exports nothing, silently. The published example is a test fixture — if it stops
  opening, the suite fails. *(Wave W-19, row L-1.)*
- 1.4 — 2026-08-31: **§4.6, "Your own data"** — §4's opening had promised four groups and delivered
  three. Documents the new `user_tags(tag_id, name)` mirror, which resolves the opaque UUIDs in
  `document_cache.user_tag_ids` into the names the researcher chose, with the app's own
  space-delimited join and its three caveats (launch-refreshed, carries unassigned tags, is your
  writing rather than the corpus). §11's strip gains `DELETE FROM user_tags` — nulling
  `user_tag_ids` alone left the most legible piece of the researcher's own writing in the file — and
  a note that the strip removes text from rows and the index but not from freed pages, with the
  `VACUUM`-then-`rebuild` sequence for when that matters. *(Wave W-19, row L-3.)*
- 1.3 — 2026-08-31: **§A.7 corrected, and Appendix A's opening frame with it.** §A.7 said the app
  "never embeds queries, so there is no in-repo reference for the query-side prompt", and the
  appendix opened on the same claim in stronger form ("the app itself never embeds free text").
  True when written; falsified by build 44's Search by Meaning, which embeds on-device under a
  pinned prefix now named in the text. **Two sites, not one** — the wave row that scheduled this
  correction named only §A.7, and an agent reading the appendix top-down would have hit the stale
  framing first. The document-to-document recall caveat is unchanged and restated so it is not read
  as also repaired.
  Note for readers of §13: this guide was documented against index format version **46** and the
  tree is now at **47** (`IndexingPipeline.currentDateIndexVersion`) — record the version your own
  copy reports rather than either number here. *(Wave W-19, row L-0.)*
- 1.2 — 2026-08-31: §14, scoping a question before you answer it — the measured record of three
  scoping runs (U.S.–Cuba contacts after 1961; State and wartime critical materials; Foreign
  Service reform), each run with positive and negative controls and each adversarially
  re-measured. Adds the counting-surface spread (14%), the variant rule, the false-friend
  concentration test, the anachronistic-vocabulary circularity, the apparatus/document split, the
  editors'-headings handle, the 718-document Ed2 double-count, and which bundled artifact suits
  which shape of question. §9 and §12's house-rules block extended to match.
  **Revised the same day after a second adversarial pass**, which found that all three runs had
  treated the printed document as the only target: between them zero record groups, zero NAIDs and
  zero series titles, and one of fifteen bundled archival-resolution artifacts ever opened. Adds
  §14.11, the second half of scoping — the archival stack, the two-channel rule, and the measured
  demonstration that a corpus-scoping negative is not a research negative (the Foreign Service
  question resolves to nine RG 59 series, 104.1 linear feet). Retitles §14.10, which had promised
  coverage it did not have. §§14.2–14.9 are unchanged: the method transferred to the archival axis
  intact, and §14.5's decoy warning proved out there too — the audit itself mis-filed a Bureau of
  International Organization Affairs series as a management record.
- 1.1 — 2026-08-29: Appendix A, the semantic vector artifacts. Binary layouts, id decoding,
  and every worked example verified against the shipped files (552/552 id round-trip, digest
  match across index/binary/map, executed neighbor/centroid/map examples).
- 1.0 — 2026-08-24: initial guide. Schema documented against `IndexingPipeline` index format
  version 46 and `FTS5Types.frusDocuments`; all example queries executed against a fixture built
  from that schema; the `integrity-check` `rank` semantics and the `VACUUM` rowid risk verified
  empirically.
