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
item in it is a real property of this schema, not a hypothetical.

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

- 1.1 — 2026-08-29: Appendix A, the semantic vector artifacts. Binary layouts, id decoding,
  and every worked example verified against the shipped files (552/552 id round-trip, digest
  match across index/binary/map, executed neighbor/centroid/map examples).
- 1.0 — 2026-08-24: initial guide. Schema documented against `IndexingPipeline` index format
  version 46 and `FTS5Types.frusDocuments`; all example queries executed against a fixture built
  from that schema; the `integrity-check` `rank` semantics and the `VACUUM` rowid risk verified
  empirically.
