# Future (Unnumbered): Single SQLite Connection for Indexing Pipeline

**Status:** Planned — deferred from the Session 154 indexing optimization pass  
**Label:** future unnumbered  
**Priority:** Medium (eliminates cross-connection WAL write-lock contention during bulk indexing)

---

## Background

`IndexingPipeline` currently uses two SQLite connections to the same database file:

| Connection | Owner | Used for |
|---|---|---|
| `auxDb` (direct `OpaquePointer`) | `IndexingPipeline` | All auxiliary tables: `document_cache`, `cross_references`, `page_ranges`, `document_dates`, `person_mentions`, `persons`, `terms`, `document_sources`, `volume_sources` |
| `connection` (internal to `FTS5Store`) | `FTS5Store` actor | The `frus_documents` FTS5 virtual table |

Both connections point to the same `.sqlite` WAL-mode file (the same `databaseURL` is passed to both at init in `FRUSExplorerApp.bootApp()`). SQLite's WAL mode allows concurrent readers but only **one writer at a time**. During the co-batch loop in `storeIndexData`, these two connections alternate writes:

```
for each batch:
    fts5Store.insertBatch(fts5Chunk)     ← FTS5 connection acquires write lock, commits
    auxInsertDocumentCache(cacheChunk)  ← auxDb connection acquires write lock, commits
```

Even though both transactions are serialized by the Swift actor model, each `COMMIT` on one connection must release the WAL write lock before the other connection can acquire it. This inter-connection handoff adds overhead on every batch — most pronounced on iOS where `effectiveBatchSize = 50` produces 50 × 2 = 100 lock acquisitions per volume just for the co-batch loop.

After the Session 154 optimization (#1), the aux-table post-loop writes are now a single transaction on `auxDb`. The remaining cross-connection overhead is in the co-batch loop itself.

---

## Goal

Eliminate the two-connection pattern during bulk indexing so that `fts5Store.insertBatch` and `auxInsertDocumentCache` share one connection and can participate in the same transaction — or at minimum, avoid the inter-connection write-lock handoff on every batch.

---

## Why it was deferred

`FTS5Store` is a separate SPM package (`Packages/FTS5Store/`) designed for reuse. Its SQLite connection is private (`private let connection: FTS5Connection`). Exposing it requires a deliberate API design decision for the package.

Two viable approaches were considered:

**Option A: Foreign-connection INSERT method on FTS5Store** (preferred)

Add a method to `FTS5Store` that accepts an external `OpaquePointer` (raw SQLite handle) and performs FTS5 inserts using that handle instead of the internal connection:

```swift
// In FTS5Store (new method):
public nonisolated func insertBatch(
    _ documents: [FTS5Document],
    usingExternalDatabase db: OpaquePointer
) throws {
    // Same bind/step logic as insertBatch, but uses `db` instead of `connection.db`
    // Caller is responsible for the surrounding transaction.
}
```

`IndexingPipeline` would then call this variant during bulk indexing, passing `auxDb` as the handle. Both the FTS5 inserts and the `document_cache` inserts would use `auxDb`, sharing the same transaction.

**Option B: Single-connection IndexingPipeline (bypass FTS5Store for writes)**

`IndexingPipeline` opens its own connection and creates the `frus_documents` FTS5 virtual table directly (duplicating what `FTS5Store.setupSchema` does). It uses this single connection for ALL writes during indexing. `FTS5Store` is used only for queries.

This avoids any API change to `FTS5Store` but creates duplication of the table schema and INSERT logic. It also means `IndexingPipeline` must know the FTS5 column layout and apply Porter stemming — currently handled by `FTS5Store.stemForIndex(_:)` (already `nonisolated public`) and `FTS5Store.bind(document:to:)`.

---

## Implementation plan (Option A — preferred)

### 1. `FTS5Store.swift` changes

Add a new `nonisolated` method that accepts an external database handle:

```swift
/// Inserts a batch of documents using an external SQLite connection handle.
///
/// Used by `IndexingPipeline` during bulk indexing so that FTS5 inserts
/// can share the same connection (and transaction) as auxiliary-table writes,
/// eliminating cross-connection WAL write-lock contention.
///
/// The caller is responsible for the surrounding `BEGIN`/`COMMIT`. No
/// transaction is opened by this method.
///
/// - Parameters:
///   - documents: Documents to insert. Skipped silently if empty.
///   - db: Raw SQLite connection handle owned by the caller.
public nonisolated func insertBatch(
    _ documents: [FTS5Document],
    usingExternalDatabase db: OpaquePointer
) throws {
    guard !documents.isEmpty else { return }
    let sql = insertSQL()          // existing helper — returns the INSERT OR REPLACE SQL
    var stmt: OpaquePointer?
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    guard rc == SQLITE_OK, let s = stmt else {
        throw FTS5Error.prepareFailed(code: rc)
    }
    defer { sqlite3_finalize(s) }
    for doc in documents {
        bind(document: doc, to: s)   // existing helper — applies stemForIndex internally
        let stepRC = sqlite3_step(s)
        guard stepRC == SQLITE_DONE else { throw FTS5Error.stepFailed(code: stepRC) }
        sqlite3_reset(s)
    }
}
```

Similarly add:

```swift
public nonisolated func deleteVolume(
    volumeId: String,
    usingExternalDatabase db: OpaquePointer
) throws {
    let sql = "DELETE FROM \(schema.tableName) WHERE volume_id = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
        return
    }
    defer { sqlite3_finalize(s) }
    sqlite3_bind_text(s, 1, volumeId, -1, SQLITE_TRANSIENT)
    sqlite3_step(s)
}
```

### 2. `IndexingPipeline.swift` changes

Replace `await fts5Store.deleteVolume(volumeId:)` with the new non-actor variant in `storeIndexData`:

```swift
// Before FTS5 batch loop — use auxDb directly (no actor hop)
try fts5Store.deleteVolume(volumeId: data.volumeId, usingExternalDatabase: auxDb!)
```

In the co-batch loop, replace:

```swift
try await fts5Store.insertBatch(fts5Chunk)
try auxInsertDocumentCache(cacheChunk)
```

with a single `inTransaction` wrapping both:

```swift
try inTransaction {
    try fts5Store.insertBatch(fts5Chunk, usingExternalDatabase: auxDb!)
    try auxInsertDocumentCache(cacheChunk, inExternalTransaction: true)
}
```

This collapses the per-batch 2-transaction / 2-lock-acquisition pattern into 1. On iOS with `batchSize = 50` and a 300-doc volume: 100 lock acquisitions → 6.

### 3. Pre-prepare the FTS5 INSERT statement

Since the FTS5 INSERT statement is now used via `auxDb` (the same connection as the pre-prepared `document_cache` INSERT), the FTS5 INSERT can also be pre-prepared in `IndexingPipeline.init` alongside `preparedCacheInsert`.

Add `preparedFTS5Insert: OpaquePointer? = nil` with the same lifecycle as `preparedCacheInsert`.

---

## Testing checklist

- [ ] Full-corpus re-index completes without SQLite errors or data loss
- [ ] `frus_documents` FTS5 table contains the correct stemmed content after indexing
- [ ] Search results match pre-optimization baseline
- [ ] Per-document text is Porter-stemmed correctly (verify via existing FTS5Store tests)
- [ ] iOS indexing with `effectiveBatchSize = 50` completes correctly
- [ ] Verify that `fts5Store.insertBatch` (actor path) and the new external-db variant
  are kept in sync when FTS5 schema changes

---

## Files to modify

- `Packages/FTS5Store/Sources/FTS5Store/FTS5Store.swift` — add two `nonisolated` external-db methods
- `FRUSExplorer/Search/IndexingPipeline.swift` — replace actor-hop FTS5 calls with direct calls; merge co-batch loop into single transaction; pre-prepare FTS5 INSERT

---

## Related

- Session 154: implemented optimizations #1–#4, #6–#8; deferred this (#5)
- `IndexingPipeline.storeIndexData` — co-batch loop at approximately line 1138
- `FTS5Store.insertBatch` — existing actor method (keep for non-indexing callers)
- `FTS5Store.stemForIndex` — already `nonisolated public`; used by the new external-db variant
