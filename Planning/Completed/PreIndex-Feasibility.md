# Pre-Index Feasibility Assessment

**Version**: 1.0  
**Date**: 2026-05-17  
**Session**: 53  
**Status**: Approved — Hosted Quick-Start Index recommended

---

## 1. Problem Statement

The current user flow requires downloading the corpus XML before any search is possible:

```
Download XML (3.3 GB total) → IndexingPipeline → frus.db → Search
```

A user who downloads a single volume can search that volume immediately. A user who wants
to search the full series must either download all 552 volumes (3.3 GB) or search only
whatever subset they have downloaded.

A pre-built index breaks the dependency: the user downloads a ready-made `frus.db` once
and can search the full corpus immediately, downloading individual volume XML files only
when they want to read documents.

---

## 2. Database Schema (as of Session 53)

All data lives in a single SQLite file (`{Application Support}/FRUSExplorer/frus.db`),
opened in WAL mode. The schema consists of one FTS5 virtual table and seven auxiliary
regular tables:

### 2.1 FTS5 Virtual Table — `frus_documents`

Created by `FTS5Connection.createSchema`. Schema version tracked via `PRAGMA user_version`
(currently **3**, set by Session 48 migration).

| Column | FTS5 role | Contents |
|---|---|---|
| `document_id` | UNINDEXED | Stable XML `xml:id` (e.g. `"d1"`) |
| `volume_id` | UNINDEXED | FRUS volume identifier (e.g. `"frus1969-76v01"`) |
| `document_number` | UNINDEXED | Printed document number, if present |
| `header` | Indexed | Document title/header line |
| `dateline` | Indexed | Place and date of authorship |
| `source_note` | Indexed | Archival provenance note |
| `body_text` | Indexed | Full plain-text body (XML markup stripped) |
| `subject_tag_ids` | UNINDEXED | Space-separated subject tag IDs |
| `user_tag_ids` | UNINDEXED | Space-separated user tag IDs (user-generated) |
| `summary_text` | Indexed | AI-generated summary (user-generated) |
| `note_text` | Indexed | Research note body text (user-generated) |
| `is_editorial_note` | UNINDEXED | 1 if FRUS editorial note, 0 for primary source |

Tokenizer: `frus_english` (Porter-stemming over `unicode61`).  
Storage: standard (not external-content); FTS5 internally manages `_content`, `_data`,
`_docsize`, `_idx`, and `_config` shadow tables.

**Critical distinction for pre-built index**: `summary_text`, `note_text`, and
`user_tag_ids` are user-generated and cannot be included in a hosted pre-built index.
They remain NULL in the distributed artifact; the app populates them per-user via
the existing `updateDocumentWithSummary` / `updateDocumentWithNote` merge paths.

### 2.2 Auxiliary Tables

| Table | Purpose | Dominant columns |
|---|---|---|
| `document_cache` | Un-stemmed field text for incremental FTS5 merges | `body_text TEXT NOT NULL`, all metadata fields |
| `cross_references` | Directed `<ref>` edges between documents | `source_*`, `target_*`, `context TEXT` |
| `page_ranges` | One row per `<pb>` element (citation lookup) | `volume_id`, `page_number_int`, `page_number_raw` |
| `document_dates` | ISO 8601 dates for date-range filtering | `date_iso TEXT` (primary key on `volume_id, document_id`) |
| `person_mentions` | One row per unique person ref per document | `person_ref TEXT` |
| `persons` | Glossary: named persons with descriptions | `name`, `description TEXT` |
| `terms` | Glossary: defined terms with definitions | `term`, `definition TEXT` |

---

## 3. Size Estimates

### 3.1 Corpus Input

From `manifest.json` (552 volumes, generated 2026-05-17):

| Metric | Value |
|---|---|
| Volume count | 552 |
| Subseries count | 170 |
| Total XML size | **3.34 GB** |
| Mean volume size | 6.0 MB |
| Median volume size | 5.8 MB |
| Largest volume | 13.1 MB |

### 3.2 Plain-Text Estimate

TEI XML markup (tags, attributes, namespace declarations) constitutes approximately
40–50% of raw file bytes in the FRUS corpus. Stripping markup yields roughly:

> **1.7 – 2.0 GB of plain text** across 552 volumes.

### 3.3 Per-Table Size Projections

These are engineering estimates; exact figures require running the full indexer.

#### `frus_documents` FTS5 virtual table

FTS5 stores content in two parts:

- **`_content` shadow table**: all column values for every row. Dominated by
  `body_text`. Estimated: **1.7 – 2.0 GB** (effectively a full copy of all
  plain-text content).
- **`_data` shadow table**: compressed inverted index segments for the tokenized
  columns (`header`, `dateline`, `source_note`, `body_text`). English prose with
  Porter stemming typically indexes at 30–50% of plain-text input size. Estimated:
  **500 MB – 1.0 GB**.
- **`_docsize`, `_idx`, `_config` shadow tables**: negligible.

**FTS5 subtotal: ~2.2 – 3.0 GB uncompressed.**

#### `document_cache`

Stores the same `body_text` as FTS5 `_content`, plus all metadata fields, for the
purpose of reconstructing FTS5 rows when user summaries or notes are merged in.
Estimated: **1.7 – 2.0 GB**.

This is unavoidable duplication given the current architecture (standard FTS5 table,
not external-content). See §6.3 for a potential future optimization.

#### Auxiliary tables

| Table | Estimated size |
|---|---|
| `cross_references` (directed `<ref>` edges + context) | 50 – 150 MB |
| `page_ranges` (one row per `<pb>` element) | 30 – 80 MB |
| `document_dates` | < 10 MB |
| `person_mentions` | 20 – 60 MB |
| `persons` + `terms` | 20 – 60 MB |
| **Auxiliary subtotal** | **~120 – 360 MB** |

### 3.4 Total Database Size

| Component | Uncompressed |
|---|---|
| `frus_documents` FTS5 | 2.2 – 3.0 GB |
| `document_cache` | 1.7 – 2.0 GB |
| Auxiliary tables | 0.12 – 0.36 GB |
| SQLite overhead (WAL, page alignment) | ~200 MB |
| **Total uncompressed** | **~4.2 – 5.6 GB** |

SQLite databases with English prose content compress well. gzip typically achieves
55–65% reduction on this content type:

> **Estimated compressed artifact size: 1.5 – 2.5 GB (.db.gz)**

This estimate is deliberately wide because it depends heavily on how many editorial
notes (shorter, denser prose) appear relative to primary-source documents (longer,
more repetitive prose) and on the exact FTS5 segment merge state at index-build time.
The only reliable number is the one produced by an actual full-corpus indexer run.

---

## 4. Distribution Option Comparison

| Option | Artifact Size | App Store Compliant | User Friction | Implementation Effort |
|---|---|---|---|---|
| **A. Bundled in app binary** | ~1.5–2.5 GB inside .ipa | ❌ Exceeds practical limit (4 GB hard cap; 200 MB OTA prompt) | None after install | None — not feasible |
| **B. Bundled as App Store On-Demand Resource** | ~2 GB ODR tag | ⚠️ Technically allowed; tags up to 4 GB | App must request asset; fails without network | Medium — requires ODR API |
| **C. Hosted direct download (this assessment's recommendation)** | ~1.5–2.5 GB .db.gz | ✅ Post-install download of data is permitted | One opt-in download during onboarding | Medium — requires CI pipeline and hosting |
| **D. Partial shards by subseries** | ~5–30 MB per shard | ✅ | Multiple downloads; complex stitching | High — rejected |
| **E. No pre-built index (status quo)** | 0 extra | ✅ | Must download and index XML first | None |

### 4.1 Why App Store On-Demand Resources (Option B) is Not Recommended

ODR is designed for game assets (levels, textures) that map to discrete app features.
A single monolithic 2 GB SQLite database cannot be split into meaningful ODR tags.
Apple recommends ODR tags under 512 MB; a 2 GB single-tag ODR asset will likely be
rejected in review. Additionally, ODR assets are cached by the OS on a best-effort
basis and can be purged without warning, requiring the app to handle re-download
gracefully — adding complexity equivalent to Option C with fewer controls.

### 4.2 Why Bundling is Not Feasible (Option A)

A 2 GB SQLite file inside the `.ipa` would make the initial App Store download
approximately 2.5 GB after Bitcode compilation overhead. iOS imposes a 200 MB OTA
download prompt and cellular carriers often throttle or fail downloads over 1 GB.
The macOS DMG would ship at ~2.5 GB compressed, making the initial install
prohibitively large and the direct-distribution auto-update payload huge.

---

## 5. Recommended Architecture: Hosted Quick-Start Index

### 5.1 Overview

A server-hosted, gzip-compressed SQLite artifact (`frus-index-vN.db.gz`) is
generated by a CI pipeline using `IndexingPipeline` compiled as a macOS CLI tool.
The app downloads and decompresses it during onboarding as an optional "Quick Start"
path. The artifact is read-only from the app's perspective; all user data
(`summary_text`, `note_text`, user tags) continues to live in SwiftData / CloudKit.

### 5.2 Onboarding Integration

`DownloadScopePickerView` (Session 49) gains a fourth option, shown first as the
recommended choice:

```
● Quick Start  (Recommended)
  Download the search index (≈ 600 MB–1.5 GB compressed). Search the full
  corpus immediately. Download individual volumes to read documents.

○ Entire Corpus
  Download all 552 volumes (3.3 GB XML). Full offline reading and search.

○ A Subseries
  Choose a decade or era to download.

○ A Single Volume
  Find and download one volume to explore.
```

> The displayed size ("≈ 600 MB–1.5 GB") should be fetched from a companion
> `frus-index-manifest.json` served alongside the artifact, so it updates without
> an app release.

### 5.3 Download and Installation Flow

```
Onboarding selects "Quick Start"
  → DownloadManager enqueues IndexArtifactDownloadTask
  → URLSession downloads frus-index-vN.db.gz to a temp file
  → App verifies SHA-256 checksum (from frus-index-manifest.json)
  → App checks PRAGMA user_version == IndexingPipeline.currentFTSSchemaVersion
      If mismatch: show error "Index incompatible with this app version"
  → App decompresses .db.gz → frus.db at the standard database URL
  → AppState boots FTS5Store + IndexingPipeline against the new database
  → Search is immediately available for all 552 volumes
```

If the index download fails at any point, the app falls back to the status quo:
the user can download XML volumes and index them locally. No data is lost.

### 5.4 Conflict Resolution with Local XML Indexing

When a user who has downloaded the Quick-Start index later downloads a volume XML,
`IndexingPipeline.indexVolume(_:)` runs and overwrites that volume's rows in
`frus_documents` and `document_cache` with freshly parsed content. This is safe
because:

- The pre-built artifact already has the correct `body_text` for all volumes.
  Re-indexing a downloaded volume produces identical content (deterministic parse).
- `summary_text` and `note_text` are preserved by the `updateDocumentWithSummary` /
  `updateDocumentWithNote` merge paths, which run after initial insertion and are
  driven by SwiftData (CloudKit), not the XML.
- `user_tag_ids` are stored in SwiftData and merged back into FTS5 rows on demand.

There is **no user-visible conflict** between the pre-built index and local indexing.

### 5.5 Schema Compatibility

The artifact is versioned with the FTS5 schema version embedded in its filename:

```
frus-index-v3.db.gz       ← schema version 3 (current as of Session 48)
frus-index-manifest.json  ← {version: 3, sizeBytes: ..., sha256: "...", builtAt: "..."}
```

The app always verifies `PRAGMA user_version` immediately after decompressing:

```swift
// In FTS5Connection or a new IndexArtifactValidator:
guard schemaVersion == IndexingPipeline.currentFTSSchemaVersion else {
    throw IndexArtifactError.incompatibleSchemaVersion(
        found: schemaVersion,
        required: IndexingPipeline.currentFTSSchemaVersion
    )
}
```

When `IndexingPipeline.currentFTSSchemaVersion` is incremented (triggering a local
re-index via the existing migration path), the CI pipeline must also generate a new
artifact at the new version. The manifest URL always points to the latest compatible
version for the current app release.

A URL pattern that supports multiple concurrent app versions in the wild:

```
https://frus-explorer.bottsywattsy.com/index/v{schema}/frus-index.db.gz
https://frus-explorer.bottsywattsy.com/index/v{schema}/manifest.json
```

The app hardcodes the URL template and substitutes `currentFTSSchemaVersion` at
runtime. Old app versions continue to download from their schema-version path.

---

## 6. Build Pipeline: `IndexingPipelineCLI`

### 6.1 New Target

Add a macOS command-line tool target to the Xcode project:

```
Target name:  IndexingPipelineCLI
Product type: Command Line Tool
Platforms:    macOS only
Dependencies: FTS5Store framework (already in the project)
              FRUSExplorer module (for IndexingPipeline, FRUSDocumentParser)
```

### 6.2 Invocation

```bash
# Run from a GitHub Actions macOS runner or locally:
swift run IndexingPipelineCLI \
  --volumes-dir ./volumes \       # pre-downloaded XML files
  --output ./frus-index.db \
  --compress                      # gzip output → frus-index.db.gz
```

The tool:
1. Opens `frus-index.db` (WAL mode, in-memory is not suitable — output is ~5 GB)
2. Calls `IndexingPipeline.indexAllVolumes()` (uses the same actor code as the app)
3. Calls `fts5Store.optimize()` to merge all FTS5 segments into one (reduces query
   time and makes the file more compressible)
4. Closes the database cleanly (WAL checkpoint to main file)
5. Compresses with gzip and writes the `.db.gz` artifact

### 6.3 Potential Future Optimization: External-Content FTS5

In the current schema, `body_text` is stored twice: once in `frus_documents._content`
and once in `document_cache`. Converting `frus_documents` to an external-content FTS5
table backed by `document_cache` would halve this duplication:

```sql
-- External-content FTS5 (document_cache is the content table):
CREATE VIRTUAL TABLE frus_documents USING fts5(
  header, dateline, source_note, body_text, ...,
  content='document_cache',
  content_rowid='rowid',
  tokenize='frus_english'
);
```

Benefit: FTS5 `_content` shadow table is eliminated; `document_cache` serves as the
single source of truth. Estimated savings: **1.7 – 2.0 GB** of duplicate storage.

Drawback: FTS5 `DELETE` and `UPDATE` operations on external-content tables require
explicit triggers or manual maintenance (`INSERT INTO frus_documents(frus_documents,
rowid, ...) VALUES('delete', ...)`). The current `IndexingPipeline.deleteVolume`
method would need rewriting. This is a non-trivial refactor.

**Recommendation**: defer external-content FTS5 until after the first Quick-Start
index ships. Run the full indexer once to get a real size measurement; only proceed
with the refactor if the artifact exceeds 2 GB compressed in practice.

### 6.4 CI/CD Pipeline Sketch

```yaml
# .github/workflows/build-index.yml (runs on demand or on manifest change)
jobs:
  build-index:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Download corpus XML
        run: |
          python scripts/download_corpus.py --output volumes/
          # Uses manifest.json to fetch all 552 files from HistoryAtState/frus
      - name: Build index
        run: |
          swift run -c release IndexingPipelineCLI \
            --volumes-dir volumes/ \
            --output frus-index.db \
            --compress
      - name: Update manifest
        run: |
          python scripts/make_index_manifest.py \
            --db frus-index.db.gz \
            --schema-version 3 \
            --output frus-index-manifest.json
      - name: Upload to hosting
        run: |
          # Upload to GitHub Releases or an S3-compatible CDN
          gh release upload v3 frus-index.db.gz frus-index-manifest.json
```

**Estimated build time** on a GitHub Actions macOS-15 runner (8 vCPU, 14 GB RAM):
indexing 552 volumes × 6 MB mean = 3.3 GB XML. IndexingPipeline at 4 concurrent
parsers processes roughly 10–20 MB/s on macOS (observed from local testing).
Estimated wall time: **3–6 hours** for a full-corpus index build.

Build runs are triggered manually (on schema version increment or corpus update),
not on every commit.

---

## 7. Hosting Considerations

### 7.1 File Size and CDN

A 1.5–2.5 GB single-file download is well within what commercial CDNs handle
routinely. GitHub Releases supports assets up to 2 GB per file. For larger artifacts,
an S3-compatible bucket (Cloudflare R2, AWS S3) is preferable.

Download performance at typical broadband speeds:
- 100 Mbps: ~2–3 minutes
- 50 Mbps: ~4–6 minutes
- 10 Mbps: ~20–33 minutes

The app should show a progress indicator during the download (using `URLSession`
`URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)` with Content-Length from
the server response).

### 7.2 Resumable Downloads

Standard `URLSession` does not resume partial downloads of raw files on connection
loss without a server that supports `Range` requests. GitHub Releases supports `Range`.
An S3 bucket with CloudFront also supports `Range`.

For the initial implementation, a non-resumable download is acceptable given that
most users will be on Wi-Fi. A future enhancement could persist the partial download
and resume using `URLRequest` `setValue("bytes=X-", forHTTPHeaderField: "Range")`.

---

## 8. App Store Review Considerations

### 8.1 Post-Install Large Downloads

Apple's App Review guidelines (§2.4.2) permit apps to download additional content
after install, provided:
- The download is initiated by explicit user action (not silently on first launch).
- The app remains functional if the download is skipped or fails.
- The downloaded content is not executable code (a SQLite file is data, not code).

The Quick-Start onboarding path satisfies all three conditions. The user explicitly
selects "Quick Start"; declining leaves the app functional (no volumes downloaded);
a SQLite database is data.

### 8.2 Cellular Download Warning

iOS presents a system alert for downloads over 200 MB on cellular. The app should
additionally show its own pre-flight warning:

```
"The search index is approximately 1.5 GB. Download over Wi-Fi recommended."
```

Present this before initiating the `URLSession` download task.

### 8.3 Disclosure

The app should clearly state in the App Store description and onboarding text that
search index data is downloaded separately and is not included in the app download.
This is consistent with how streaming services, mapping apps, and other data-heavy
apps describe their content.

---

## 9. Limitations and Open Questions

| Item | Status |
|---|---|
| Exact artifact size | Unknown until full indexer run; estimate is 1.5–2.5 GB compressed |
| External-content FTS5 optimization | Deferred; evaluate after first artifact measurement |
| Resumable downloads | Deferred; initial implementation non-resumable |
| Artifact hosting location | TBD: GitHub Releases (free, 2 GB limit) vs. CDN |
| Index build frequency | On demand (schema version increment or major corpus update) |
| Incremental / delta updates | Not planned; full re-download on schema version change |
| iOS background download (`URLSessionConfiguration.background`) | Recommended but deferred; initial build uses foreground session |
| User-tag and summary merging after index download | Handled by existing merge paths; no new work required |

---

## 10. Decision Record

**Chosen approach**: Option C — Hosted Quick-Start Index.

**Rationale**:
1. The estimated artifact size (1.5–2.5 GB) is too large for App Store bundling and
   too large for a practical ODR asset.
2. A direct hosted download is a well-established pattern for data-heavy apps and is
   explicitly permitted by App Store guidelines when user-initiated.
3. The `IndexingPipeline` actor is already a self-contained, testable unit that can be
   compiled into a CLI tool with minimal additional code.
4. The existing `DownloadManager` infrastructure handles large file downloads with
   progress reporting; plugging in an IndexArtifactDownloadTask is incremental work.
5. Failure modes are safe: if the index download fails or is incompatible, the user
   falls back to per-volume XML download and local indexing with no data loss.

**Next implementation steps** (future sessions, not Session 53):
1. Add `IndexingPipelineCLI` target and run a full-corpus index build to get the real
   artifact size before committing to hosting infrastructure.
2. Add `IndexArtifactDownloadTask` to `DownloadManager`.
3. Add `IndexArtifactValidator` (schema version check, SHA-256 verification).
4. Add "Quick Start" option to `DownloadScopePickerView`.
5. Set up hosting and CI pipeline.
