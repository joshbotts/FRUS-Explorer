# Session 03 — SQLite FTS5 Swift Wrapper (`FTS5Store`)

## Goal
Build `FTS5Store`, a well-documented, reusable Swift wrapper around SQLite FTS5. This is a first-class project component designed for use both within FRUS Explorer and potentially by other projects. It provides the full query surface needed for FRUS Explorer's search functionality, with an async/await interface compatible with Swift 6 strict concurrency.

## Prerequisites
- Session 01 complete

## Specification References
- Section 9: Search & Indexing
- Section 22: Coding Standards

## Inputs
None beyond the Session 01 project structure.

## Outputs
- `FTS5Store.swift` — the wrapper
- `FTS5Tokenizer.swift` — the English stemming tokenizer
- `FTS5Query.swift` — the query builder
- `FTS5StoreTests` — comprehensive test suite

## Architecture

`FTS5Store` is a Swift actor wrapping a SQLite database connection. All SQLite calls are made from within the actor's executor, ensuring thread safety without additional synchronization.

```
FTS5Store (actor)
├── FTS5Connection       — manages the SQLite connection lifecycle
├── FTS5Schema           — defines the virtual table and auxiliary tables
├── FTS5Tokenizer        — custom English stemming tokenizer (registered with SQLite)
├── FTS5Query            — builds FTS5 query strings from structured search parameters
└── FTS5Result           — typed search result with snippet and ranking
```

## Key Types

### `FTS5Store`
```swift
/// FTS5Store is the primary interface for full-text search in FRUS Explorer.
/// It wraps a SQLite database containing an FTS5 virtual table of FRUS document
/// content, with a custom English stemming tokenizer and support for phrase,
/// boolean, and prefix wildcard queries.
///
/// Design: FTS5Store is an actor to ensure all SQLite operations execute
/// serially on a single thread, satisfying SQLite's threading requirements
/// without locks. The async interface is compatible with Swift 6 concurrency.
///
/// Reuse: FTS5Store is designed to be reusable outside FRUS Explorer.
/// The schema is configurable at initialization; the tokenizer is pluggable.
///
/// Version history:
///   1.0 — Session 03: initial implementation
actor FTS5Store {
    init(databaseURL: URL, schema: FTS5Schema) async throws
    
    // Index management
    func insert(document: FTS5Document) async throws
    func update(document: FTS5Document) async throws
    func delete(documentId: String) async throws
    func insertBatch(_ documents: [FTS5Document]) async throws
    
    // Search
    func search(query: FTS5Query, limit: Int, offset: Int) async throws -> [FTS5Result]
    func searchCount(query: FTS5Query) async throws -> Int
    
    // Maintenance
    func optimize() async throws     // FTS5 'optimize' command — run after bulk inserts
    func rebuild() async throws      // Full reindex from content table
    func storageSize() async throws -> Int  // bytes used by the database file
}
```

### `FTS5Document`
```swift
/// A document to be indexed in the FTS5 store.
/// The `id` field is the unique identifier used for update and delete operations.
/// Fields correspond to the FTS5 virtual table columns.
struct FTS5Document: Sendable {
    let id: String              // documentId (e.g. "d1" within volumeId)
    let volumeId: String
    let documentNumber: String?
    let header: String
    let dateline: String?
    let sourceNote: String?
    let bodyText: String        // full plain-text content of the FRUS document
    let subjectTagIds: String?  // space-separated subject tag IDs for tag filtering
    let userTagIds: String?     // space-separated user tag IDs for tag filtering
    let summaryText: String?    // latest generated summary text, if available
    let noteText: String?       // research note text, if available
}
```

### `FTS5Query`
```swift
/// FTS5Query builds a valid SQLite FTS5 query string from structured parameters.
/// Handles escaping and operator composition to prevent injection and invalid syntax.
///
/// Supports:
///   - Keyword search (stemmed, across all columns or specific columns)
///   - Phrase search ("cold war" → exact phrase match)
///   - Boolean operators (AND, OR, NOT)
///   - Prefix wildcard (negoti* → prefix match)
///
/// Does NOT support suffix wildcard (*gotiate) — document this clearly.
struct FTS5Query: Sendable {
    var keywords: [String]          // stemmed keyword terms (AND by default)
    var phrase: String?             // exact phrase
    var booleanMode: BooleanMode    // .and | .or
    var excludedTerms: [String]     // NOT these terms
    var prefixWildcard: String?     // term prefix (e.g. "negoti")
    var subjectTagId: String?       // filter to documents with this subject tag
    var userTagId: String?          // filter to documents with this user tag
    var columns: [FTS5Column]?      // nil = search all columns
    
    /// Renders the structured query into an FTS5 MATCH expression string.
    func toFTS5MatchExpression() -> String
}
```

### `FTS5Result`
```swift
/// A single search result from FTS5Store.
/// Contains the document identifier fields and a relevance-ranked snippet
/// for display in the search results list.
struct FTS5Result: Sendable {
    let documentId: String
    let volumeId: String
    let header: String
    let dateline: String?
    let sourceNote: String?
    let snippet: String        // FTS5 snippet() function output, HTML-safe
    let bm25Score: Double      // lower is more relevant in SQLite BM25
    let subjectTagIds: [String]
    let userTagIds: [String]
}
```

### `FTS5Schema`
```swift
/// Defines the FTS5 virtual table structure.
/// Configurable to allow FTS5Store to be reused in other projects
/// with different document schemas.
struct FTS5Schema: Sendable {
    let tableName: String
    let columns: [FTS5Column]
    let tokenizerName: String    // registered tokenizer name; default "frus_english"
    let contentTable: String?    // for content= option (external content FTS5)
}
```

## Stemming Tokenizer

Implement a custom FTS5 tokenizer (`frus_english`) that applies Porter stemming to English text. The tokenizer is registered with SQLite at connection open time using the `fts5_tokenizer` API.

Implementation approach:
- Implement the Porter stemming algorithm in Swift (well-documented algorithm, ~150 lines)
- Register as a custom SQLite tokenizer via the C API
- Apply after Unicode tokenization (handle punctuation, hyphens in diplomatic terms)
- Document the tokenizer clearly for contributors unfamiliar with FTS5 tokenizer registration

## Database Schema

```sql
-- FTS5 virtual table for FRUS document full-text search
CREATE VIRTUAL TABLE frus_documents USING fts5(
    document_id UNINDEXED,
    volume_id UNINDEXED,
    document_number UNINDEXED,
    header,
    dateline,
    source_note,
    body_text,
    subject_tag_ids UNINDEXED,
    user_tag_ids UNINDEXED,
    summary_text,
    note_text,
    tokenize = 'frus_english'
);

-- Cross-reference edge table (populated in Session 09 alongside FTS5)
CREATE TABLE cross_references (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_document_id TEXT NOT NULL,
    source_volume_id TEXT NOT NULL,
    target_document_id TEXT NOT NULL,
    target_volume_id TEXT NOT NULL,
    context TEXT,
    reference_type TEXT CHECK(reference_type IN ('footnote', 'editorialNote'))
);
CREATE INDEX idx_xref_source ON cross_references(source_document_id, source_volume_id);
CREATE INDEX idx_xref_target ON cross_references(target_document_id, target_volume_id);
```

## Storage & Backup Exclusion

```swift
// Applied to the database file URL immediately after creation:
try (databaseURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
```

## Tasks

1. Implement `FTS5Connection` — manages SQLite connection open/close, WAL mode, and tokenizer registration
2. Implement `FTS5Tokenizer` — Porter stemming tokenizer registered via SQLite C API
3. Implement `FTS5Schema` and database schema creation
4. Implement `FTS5Document` and `FTS5Result` value types
5. Implement `FTS5Query` with `toFTS5MatchExpression()` — include thorough documentation of the FTS5 query syntax supported
6. Implement `FTS5Store` actor — all CRUD and search operations
7. Implement `insertBatch` with `optimize()` call after bulk insert completion
8. Implement `storageSize()` for the Settings storage reporting requirement
9. Apply `isExcludedFromBackupKey` at database creation
10. Document every public type and function with contributor-oriented comments

## Tests

### `FTS5StoreTests`
- **InsertAndSearchTest**: Insert a fixture document; search for a term in its body; verify result contains the document
- **StemmingTest**: Insert document containing "negotiations"; search for "negotiate"; verify match. Test multiple stemming variations.
- **PhraseSearchTest**: Insert documents; search `"cold war"` as phrase; verify only documents with exact phrase are returned
- **BooleanORTest**: Search `cold OR korea`; verify documents containing either term are returned
- **BooleanNOTTest**: Search `cold NOT korea`; verify documents with "cold" but not "korea" are returned
- **PrefixWildcardTest**: Search `negoti*`; verify all prefix matches returned
- **SubjectTagFilterTest**: Insert documents with different subject tag IDs; search with `subjectTagId` filter; verify only matching documents returned
- **IncrementalUpdateTest**: Insert documents; add new documents; verify new documents are searchable without full reindex
- **DeleteTest**: Insert then delete a document; verify it no longer appears in search results
- **BatchInsertPerformanceTest**: Insert 1,000 fixture documents; verify completion within acceptable time; verify `optimize()` runs after batch
- **StorageSizeTest**: Verify `storageSize()` returns a non-zero value after insertion
- **BackupExclusionTest**: Verify `isExcludedFromBackupKey` is set on the database file

## Coding Standards Checklist
- [ ] `FTS5Store` is an actor; all operations async
- [ ] All public types and functions fully documented
- [ ] `[FTS5Store]` prefix on all `#if DEBUG` log statements
- [ ] Porter stemmer implementation documented with algorithm reference
- [ ] Tokenizer registration documented with FTS5 C API reference
- [ ] Swift 6 strict concurrency: zero warnings
- [ ] No hardcoded UI strings
- [ ] `FRUS-API.openapi.yaml` — no update needed this session (no GitHub API calls)
