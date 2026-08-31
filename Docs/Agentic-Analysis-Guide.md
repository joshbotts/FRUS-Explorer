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

---

## 3. Connecting an agent to it

The mechanics differ by tool, but the shape is the same everywhere and only three decisions matter.

**Give it SQL, not the file.** Do not upload a multi-gigabyte database to a chat interface, and do
not ask a model to "read" it. The productive pattern is an agent that can *execute queries* and see
result sets — a coding agent with shell access (`sqlite3`/Python in a terminal), or a SQLite MCP
server wired into a desktop client. The model's job is to write SQL and interpret rows; the
database's job is to do the counting. A model that is guessing at contents rather than querying
them will produce fluent fabrications.

**Make the connection read-only.** Use a read-only URI (`?mode=ro`) or a client configured without
write tools. This is not only about safety — it removes any possibility that a number changed
between the run that produced it and the run that checks it.

**Put the schema in context up front.** Paste [§4](#4-schema-reference) and
[§7](#7-eight-ways-this-database-will-quietly-mislead-you) into the session, or point the agent at
this file. Agents infer table semantics from column names, and several columns here mean something
other than what they appear to (`citation_era` is not a date; `reference_type` does not reliably
distinguish body from footnote; `subject_tag_ids` is always empty). The gotcha list is worth more
context budget than the schema is.

A note on scale: a full 552-volume index runs to several gigabytes, with `document_cache` alone at
roughly 1.8 GB of text. Aggregate in SQL and return summaries. An agent that pulls `body_text` for
20,000 rows into its context will exhaust the window before it reaches an answer.

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
everything.

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
| `user_tag_ids` | Your tags, mirrored from SwiftData. |
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
| `repository` | `Department of State`, `National Archives`, a presidential library, `Central Intelligence Agency`, … |
| `record_group` | NARA record group number, where asserted. |
| `lot_file`, `lot_file_norm` | Lot file as cited, and its canonical compact key (`64D199`) for joining. |
| `series_name` | Series or file designation as parsed. |
| `decimal_class` | Central-file class key (`751.00`, `POL 27 ARAB-ISR`), canonicalized. |
| `job_number_norm` | Normalized CIA Job number. |
| `classification` | Classification/handling markings (`Secret; Nodis`). |
| `citation_era` | **The citation *form*, not a date.** See below. |
| `raw_text` | The source note as printed — your fallback when the parse is thin. |

`citation_era` takes one of: `decimal`, `cfpf`, `lot_file`, `structured`, `foreign`, `published`,
`named_series`, `unrecognized`. These describe *how the citation is shaped*, which correlates with
period but does not encode it. `structured` in particular covers NARA collections, presidential
libraries, and CIA Job citations alike. Never group by it and label the axis "era."

**`external_citations`** — **many rows per document**, keyed
`(volume_id, document_id, note_ordinal, citation_index)`: archival material the editors *cited in a
footnote*, largely things FRUS did not print.

**These two tables must never be blended into one provenance count.** A `document_sources` row says
a document *came from* an archive. An `external_citations` row says an editor *mentioned* one. The
app keeps them in separate tables precisely so the blend is structurally impossible rather than
merely discouraged, and rows that once conflated them were deleted from `document_sources`. If your
agent produces "documents from the Kennedy Library" by unioning them, the number is wrong.

**`volume_sources`** — the volume's own front-matter Sources section, as an ordered outline
(`kind`, `depth`, `is_heading`, `sort_order`). This is a *finding aid* — what the editors say they
consulted — not a per-document assertion. Volume-grain, never document-grain.

### 4.5 Subjects

**`document_subject_refs`** — `(volume_id, document_id, subject)`, where `subject` is an **integer
position** in a vocabulary that lives outside the database. **`document_subjects`** is the same idea
folded to 106 coarser `(category, subcategory)` buckets — and **the two integers index different
vocabularies and are not interchangeable**: `subject` is a position in the subject vocabulary,
`bucket` a position in the sorted list of distinct `(category, subcategory)` pairs, resolved
through `DocumentSubjectStore`'s separate `bucketVocabulary`. Neither is interpretable in SQL alone;
[§5](#5-resolving-the-coded-columns) shows how to resolve them, and
[§7.7](#77-subject-tags-are-recall-oriented-candidates) explains what they are worth.

---

## 5. Resolving the coded columns

Two things an agent cannot get from the database alone, because they are keyed to bundled JSON
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

FTS5 query syntax is available in full: `"phrase match"`, `NEAR(containment allies, 10)`,
`header : telegram` for column-scoped matching, `AND`/`OR`/`NOT`, and `term*` prefixes.

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
  the index; if the distinction matters, filter the retrieved `body_text` afterwards.
- Frequency counts from `frus_documents_vocab` are stem frequencies. Do not present them as word
  counts.

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
documents" is a statement about string matching.

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

**Quotations come from a retrieved row, never from the model.** If a quotation appears in the
agent's prose, it must have appeared in a result set first. A useful discipline: require the agent
to output the `SELECT` that returned any quoted text alongside the quotation.

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

1. **Make the agent show the SQL for every number.** No exceptions, including numbers in prose.
   Read the `WHERE` clause. Most errors are visible there in five seconds.
2. **Check the joins for the pair.** Any join between two corpus tables must constrain both
   `volume_id` and `document_id`. This one check catches more bad results than everything else here
   combined.
3. **Ask for the denominator with every proportion.** "12% of documents" is unverifiable; "1,447 of
   12,060 documents in 43 indexed volumes" is checkable, and the act of writing it out surfaces
   coverage problems on its own.
4. **Spot-check five rows in the app.** Take the extremes and three at random, open them in FRUS
   Explorer, and confirm the document is what the query claimed. This catches join-level errors that
   no amount of SQL reading will.
5. **Re-derive one number a different way.** If a count came through a join, get it again with an
   `EXISTS` subquery. Agreement is weak evidence; disagreement is a finding.
6. **Distinguish "zero rows" from "wrong query".** When an agent reports no results, ask it to prove
   the query is capable of returning rows — run it with the filter relaxed. Models are prone to
   accepting an empty result as a substantive finding, and "FRUS contains no discussion of X" is a
   dramatic claim to reach through a typo.
7. **Ask what would falsify it.** Before accepting a pattern, have the agent name the query that
   would disconfirm it and run that one too.

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
INSERT INTO user_content(user_content) VALUES('rebuild');
```

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
- The FTS tokenizer is porter stemming. Index terms are stems ('containment' -> 'contain'). A
  vocab lookup for a full word returning nothing means you used the wrong form, not that the
  corpus lacks the word.
- body_text INCLUDES editorial footnotes. Term frequencies blend document and editor language.
- citation_era is a citation FORM (decimal, lot_file, structured, cfpf, foreign, published,
  named_series, unrecognized), NOT a date. Never plot it as a timeline.
- cross_references.reference_type defaults body references to 'footnote'. It cannot support a
  body-vs-footnote split.
- document_sources (where a document CAME FROM, one row per document) and external_citations
  (what a footnote MENTIONS, many rows per document) must never be combined into one count.
- person_rollup is name-based clustering biased to under-merge; person counts are lower bounds.
- person_mentions covers TEI-tagged mentions only; tagging is uneven across volumes.
- Subject tags come from string matching, not semantic analysis. Treat as candidates.
- subject_tag_ids is always NULL. Ignore it.
- bm25() is negative; better matches are more negative. ORDER BY score ASC.

REPORTING
- Show the exact SQL for every number you report.
- Give proportions as "N of M" with the denominator, never as a bare percentage.
- If a query returns no rows, say so explicitly and verify the query can return rows at all
  before drawing any conclusion from the emptiness.
- Do not quote text you have not retrieved in a result set in this session.
- Flag when a result is thin enough that it may reflect my partial library rather than the corpus.

SCOPING — applies whenever you are scanning the corpus to decide what to search for
- Run a POSITIVE control ("Department of State", expect nonzero in every volume) and a NEGATIVE
  control ("ZZZ_IMPOSSIBLE_ZZZ", expect 0) in the SAME pass. Report both. An absence is not a
  finding until the controls prove the scan works.
- State your COUNTING SURFACE with every number: raw TEI, tag-stripped, or word-bounded. They
  disagree by up to 14% on this corpus. Prefer tag-stripped + whitespace-collapsed.
- Never query a single literal. Count every spelling, hyphenation, plural and acronym variant
  and report the split. Acronyms often outnumber spelled forms.
- FALSE-FRIEND TEST: for any term the question itself supplied, compute its share in the
  on-topic volumes and compare that to a control phrase's share. A term matching the baseline
  is measuring the corpus, not the question — say so and stop using it.
- Never scan a bare surname. Full-name and inverted-index forms only; <persName> markup covers
  only 4-10% of mentions and cannot disambiguate.
- Periodise on frus:doc-dateTime-min, NOT on the volume's series year. Say which you used.
- Separate document text from apparatus (front matter, abbreviation lists, footnotes, index)
  before publishing any density, or say explicitly that you have not.
- Read the editors' chapter headings before writing queries. My modern phrasing for a subject
  is usually absent from the corpus; theirs is a repeating formula.
- A negative built from vocabulary postdating the period is circular. Before claiming the
  corpus lacks pre-YEAR coverage, scan terms contemporaries would have used.
- Suppress Ed2 twins where a first edition is also present (frus1951-54Iran,
  frus1969-76ve15p2) — 718 documents are otherwise double-counted.

ARCHIVAL SCOPE — do not stop at what FRUS printed
- FRUS is a SELECTION. Scoping is not finished when you know which volumes hold the question.
  Also establish which archival units those documents came out of, and which units their
  footnotes point at. Report both, always labelled by channel, and NEVER summed.
- Resolve as far as the bundled indexes reach, and report what you got:
    collection-usage-index.json  -> ranked archival targets for any volume scope
    external-citation-index.json -> what the editors cited and did NOT print
    central-files-index.json     -> lot number -> record group + series NAID + entry number
    collection-authority.json    -> collection identity across spellings
    series-facts-index.json      -> creator, extent, date span, access status, facility
    lot-claimants-index.json     -> lots NARA divides across several series
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
```

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
| The queries themselves | Verbatim, in a file, with their result counts. |

Two of these change under your feet in normal use. Downloading more volumes changes every count.
An app update can raise the index format version and trigger a background re-index, which changes
extraction output for rows you already had. If a number matters, re-derive it after any update
rather than assuming it held.

---

## 14. Scoping a question before you answer it

Everything above assumes you already know what to search for. That assumption is where
machine-assisted work here actually fails. This section is the record of three scoping runs — on
U.S.–Cuba contacts after 1961, on the State Department and wartime critical-materials supply, and on
Foreign Service reform — each measured over the local TEI corpus with controls, and each
adversarially re-measured afterwards. In all three the errors clustered *before* the first
substantive query. Every figure below was measured; none is illustrative.

Note the scope shift: §§1–13 are about the SQLite index. This section is mostly about scanning the
TEI corpus directly, which is what scoping requires — you are deciding which volumes to index-search
at all, and the manifest plus the raw XML answer that faster than SQL does.

**Scoping has two halves, and §§14.1–14.9 are only the first.** Establishing which volumes hold your
question is necessary and not sufficient: FRUS is a published selection, so the second half is
establishing which archival units those documents came out of and which units their footnotes point
at. [§14.11](#1411-the-second-half-of-scoping-where-the-documents-came-from-and-point-at) is that
half. All three runs recorded here skipped it, which is why it is stated as a rule rather than an
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
`python3` heredoc with absolute paths over shell globbing.

### 14.3 Say which text surface you counted

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

### 14.6 A negative built from anachronistic vocabulary is circular

This is the subtlest error the three runs produced, and it nearly shipped.

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

### 14.7 Two things that quietly turn a claim into a claim about something else

**Volume year is not document date.** Every periodisation in the first pass of two runs bucketed by
the *volume's* series year. Each `<div type="document">` carries `frus:doc-dateTime-min`/`-max` — the
same editorial dates [§4.3](#43-derived-structure) exposes as `document_dates` — and reading them
costs nothing extra in the same pass. Until you do, a claim like "the Board of Economic Warfare
appears in 1942–43" is a claim about how FRUS was assembled as much as about the agency. State which
you measured.

**Apparatus is not document text.** Front matter, abbreviation lists, editorial footnotes and the
back-of-book index are all inside the file, and no keyword scan separates them by default.
`type="index"` divs are present in 98 of 99 volumes in one run's scope. Measured effects: index and
front matter hold 5.9% of the corpus's text but carry **18.6%** of `Foreign Service`, 20.0% of bare
capital `Service`, 16.0% of `FSO` — and *the enrichment worsens inside the on-topic volumes*, because
those carry the longest persons lists. In the anchor volume of one question, **335 of 984 marker hits
were bare grade acronyms**, and an agent discovered three of those acronyms by reading that volume's
abbreviation list. All four `Rogers Act` hits in the entire corpus are footnote glosses or index
entries.

Until you scope hits to their enclosing `<div type="document">`, *"this volume is about X"* and
*"this volume indexes X"* are indistinguishable in every number you publish. This project has already
measured the analogous ratio for cross-references at **95.3% editorial footnote** — see
[§7.3](#73-reference_type-defaults-body-references-to-footnote) — so the skew is the expectation, not
the exception.

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
`frus1969-76ve15p2Ed2`, `frus1977-80v09Ed2` — and for two of them the first edition ships as well
(`frus1951-54Iran`, 375 documents, beside its Ed2 at 375; `frus1969-76ve15p2`, 343, beside its Ed2 at
382). So a naive corpus-wide scan double-counts **718 documents**. Both editions appear in
`manifest.json` and in `semantic-vectors-index.json`; this is deliberate publishing, not a defect —
but suppress the Ed2 twin where a first edition is present before computing any share.

Related, and worth stating once: the semantic artifacts count **314,483** documents, while this
project's own settled corpus figure from its query work is **316,839**. The two count different
surfaces. Whichever you use, name it — a run that publishes densities to two decimals owes the reader
its denominator.

### 14.10 Two bundled artifacts that scope the corpus

The app ships 34 bundled JSON resources. Two of them scope a question against the *corpus*, and
neither is obvious from the schema; the fifteen that scope it against the *archives* are
[§14.11](#1411-the-second-half-of-scoping-where-the-documents-came-from-and-point-at).

**`volume-subject-profiles-index.json`** carries the Office of the Historian's own subject
vocabulary — 380 subjects in 13 categories, with a per-volume weighted profile. It includes a
`Department of State` category with a `Personnel: Foreign Service` subcategory, and ranking all 552
volumes by that subject's weight recovered the entire relevant volume family unprompted, in agreement
with an independent title scan and an independent density scan. Three routes agreeing is worth more
than any one of them.

**`semantic-map-index.json`** carries 179 unsupervised cluster labels. It is a fast test of whether
your subject forms a region of the corpus at all — and the answer differs sharply by question shape:

| Question | Clusters found | Reading |
|---|---|---|
| Wartime critical materials | **4** clusters, 2,405 documents — `jordana, wolfram, hayes, wendelin`; `chrome, turkish, numan, turk`; `salazar, lagen, portuguese, azore`; `rubber, tin, vile, gwatkin` | Sustained named negotiations cluster hard. The vector layer is the right instrument. |
| Foreign Service reform | **0** of 179 (controls pass: 15 match `soviet`, 5 match `nuclear`) | An institution is not a region of the semantic space. Vectors will not rescue the question. |

The map's twenty largest clusters are, without exception, places and crises. That is what it is
organised around, and it constrains what it can find for you. Note also the asymmetry *within* a
question: the wartime *denial* operations clustered; the hemispheric *acquisition* program did not,
because it is distributed across many country files rather than concentrated in a few negotiations.

### 14.11 The second half of scoping: where the documents came from, and point at

**This section exists because all three runs failed it.** Each treated the printed document as the
only target. Between them they resolved zero record groups, zero NAIDs, zero series titles, zero
entry numbers — and of the fifteen bundled archival-resolution artifacts (11.83 MB of the 24.79 MB
the app ships), exactly one was ever opened, as a dictionary for glossing a filing code. The
omission was invisible from inside the work; it took someone asking whether the runs had used the
archival layer at all.

The stack, and the question each artifact answers:

| Artifact | Answers | Scale |
|---|---|---|
| `collection-usage-index.json` | how many documents in volume X came from archival unit Y — **the join that turns any volume scope into a ranked archival target list** | 264,464 notes; 1,839 collections reached; 10,446 class keys |
| `external-citation-index.json` | what the editors cited and did **not** print | 19,800 lot/library refs + 29,890 class refs, 440 volumes |
| `central-files-index.json` | cited lot number → record group, series NAID, HMS/MLR entry number | 1,065 lot files, all carrying a NAID |
| `collection-authority.json` | which collection is this note naming, under every spelling | 4,429 collections, 1,018 with a NAID |
| `series-facts-index.json` | the pre-travel facts: creator, extent, date span, access status, facility | 695 series, 397 creator headings |
| `lot-claimants-index.json` | when a lot has several correct NARA answers, which | 123 divided lots, up to 13 claimants |
| `presidential-library-catalog.json` | the collections that sit outside every record group | 11 libraries, 3,837 collections, 14,656 series |
| `volume-sources-index.json` | what the editors say they consulted, per volume | 3,412 rows, 251 volumes |
| `decimal-class-labels.json` | what `812.6363` means, compositionally | 1910–49 schedule; 9 classes, 198 countries, 693 suffixes |
| `curated-lot-resolutions.json` / `-library-` | the targets NARA's catalogue cannot resolve | 20 lots, 185 library finding aids |
| `digitized-ranges-index.json`, `roll-scans-index.json` | is it already digitised — do I need to travel | 624 ranges, 1,238 roll scans |

Two rules govern using them, and the second is easy to get backwards.

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
  agencies are separate record groups, and the project's own harvest already covers RG 169 and
  RG 182.
- **Foreign Service reform.** The corpus prints almost nothing citeable — `Wriston` appears in 0
  source notes against 38 full-text occurrences. But the office that produced the record resolves to
  nine RG 59 series, **104.1 linear feet, 1955–1980**, all created by the (Deputy) Under Secretary
  for Management, each with a NAID and an entry number, three of them Restricted-Fully. A verdict of
  "the corpus does not hold this" was one lookup away from a bounded research plan.

That last case is the general lesson: **a corpus-scoping negative is not a research negative.** The
answer to "FRUS does not print this" is frequently "and here is the shelf that does" — but only if
the second half of scoping ran.

Two cautions, both measured. NARA's creator attribution is itself a decoy surface in the sense of
[§14.5](#145-the-false-friend-test-compare-a-terms-concentration-to-the-corpus-baseline) — it ran at
56% precision on one route here, and the adversarial pass that caught this whole omission
nevertheless mis-filed NAID 27022913 (Bureau of International Organization Affairs) as a Foreign
Service management series. And the offline stack has a hard reach: 11 of 695 bundled series begin
before 1940, so a pre-war archival roadmap is largely unavailable regardless of how well the corpus
covers the period.

### 14.12 Contest your own agent

In all three runs an adversarial pass — a second agent given the first's results and told to find the
wrong number — earned its place. It caught the `ball bearing` hyphen fold; it found one probe had
counted decoded characters and labelled them bytes; it found a term where the *larger* context window
produced the *smaller* count, proving two passes had used different and undisclosed marker sets; and
on one question it corrected the headline figure by **47%**, having noticed that half the "reform
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

None of this makes an agent trustworthy. It makes an agent *checkable*, which is the property this
whole guide is about.

---

## Appendix A: The semantic vector artifacts

The database is not the only structured layer FRUS Explorer ships. The app also carries a set of
**semantic vector artifacts** — a neural embedding of every document in the corpus, quantized and
packed for on-device retrieval — and they are just as usable by an outside agent as the SQLite
index is. Everything in this appendix was verified against the shipped files: the binary headers
parse as documented, the id encoding round-trips for all 552 volumes, and every worked example
below was executed as shown.

One structural fact frames all of it: **the app itself never embeds free text.** Every semantic
surface it ships (Related documents, the map) is anchored on an existing document. So the shipped
artifacts are *complete* for document-to-document work with no embedding model at all
([§A.5](#a5-what-an-agent-can-do-with-no-model)), while free-text semantic queries require
reproducing the harvest embedder ([§A.7](#a7-free-text-queries-require-the-embedder)).

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

— all Civil War-era diplomacy, which is what a working index looks like. The core loop, given the
`row_of`/`doc_of` maps built from §A.3's decode:

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
on clusters owes the reader the number.

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

Two caveats an agent must carry. The artifact records only the *document*-side prompt; the app
never embeds queries, so there is no in-repo reference for the query-side prompt — EmbeddingGemma's
own prompt conventions apply, and the choice is yours to make and to state. And the 0.851 recall
was measured document-to-document; nothing here has measured text-query retrieval, so validate it
on queries you can check by hand before trusting it in bulk.

### A.8 What the vectors cannot tell you

The database caveats in §7 all still apply — and the semantic layer adds its own:

- **Similarity is a lead, not evidence.** A neighbor is a reading suggestion. Nothing about
  embedding distance supports "these documents are related" as a historical claim; the claim comes
  from reading them, with the vector as the finding aid that got you there.
- **Vectors pool whole documents, footnotes included.** Each document is one vector — a weighted
  mean over its chunks, editors' annotation and all. Long documents blur; the chunk vectors that
  could localize a match are not shipped.
- **The neural layer is not reproducible.** The embedding was produced by an owner-run harvest;
  you cannot regenerate it, only cite it. Record the provenance digest and the index's `generated`
  and `harvestGenerated` stamps the way you would cite an edition, and re-record them after any
  app update — a regeneration changes every neighbor list.
- **The map is a projection.** Clustering ran on the 2-D embedding, not the 512-dim space; 28% of
  documents are unclustered; labels are c-TF-IDF over a *sample* of each cluster's members. Use
  clusters to explore and to sample, not to measure.
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
  relationship. Similarity claims require reading the documents.
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
