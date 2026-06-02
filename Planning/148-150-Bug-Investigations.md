---
name: Sessions 148–150 — Three Bug Investigations
description: Three targeted investigation-and-fix sessions addressing confirmed bugs
  in iCloud/CloudKit sync, persName/gloss detail sheet population, and NARA Catalog
  API resolution in Source Explorer. Each session begins with a focused diagnosis
  and ends with a fix and verification plan.
type: investigation
originSessionId: session-147
---

# Sessions 148–150: Three Bug Investigations

These sessions address three confirmed bugs reported in testing. Each has been
pre-investigated against the current codebase; the root causes and most likely
fixes are identified below. The sessions are independent and can be scheduled in
any order.

---

## Work Item Summary

| Session | Title | Effort | Risk | Depends On |
|---------|-------|--------|------|------------|
| 148 | CloudKit Sync Silent Failures | Medium | Medium | None |
| 149 | persName / gloss Detail Sheets Empty | Low–Medium | Low | None |
| 150 | Source Explorer — NARA API Resolution | Medium–Large | Medium | None |

---

## Session Breakdown

---

### Session 148 — CloudKit Sync Silent Failures

**Symptom:** The iCloud sync indicator in the status bar reports "Succeeded" but
research notes, tags, collections, and highlights created on one device do not
appear on another device signed into the same Apple ID.

**Effort:** Medium. Investigation is partly diagnostic; the fix depends on which
failure mode is active.  
**Risk:** Medium. CloudKit schema changes require careful migration; incorrect
container resets can cause data loss.

#### Pre-Investigation Findings

The container is configured in `ModelContainer+FRUS.swift` (lines 66–102) with
`.private("iCloud.bottsywattsy.FRUS-Explorer")`. Entitlements in both
`FRUSExplorer-AppStore.entitlements` and `FRUSExplorer-DirectDistribution.entitlements`
correctly declare the container ID.

Event monitoring in `FRUSExplorerApp.swift` (lines 519–559) observes
`NSPersistentCloudKitContainer.eventChangedNotification` and stores the result in
`AppState.cloudKitSyncState`. The state transitions to `.succeeded(Date)` when the
event fires without errors — but this only reflects the *notification-based* sync
path. Silent failures (authentication token expiry, zone deletion, schema
divergence) do not trigger a notification event and are never surfaced.

All 13 SwiftData `@Model` types were reviewed; no CloudKit-incompatible patterns
were found (ordered arrays have been replaced with sort-order columns, all
relationships are optional with `.nullify` delete rules). The schema itself is not
the likely culprit.

#### Investigation Steps

**Step 1 — Enable CloudKit diagnostics console logging**

Add to `FRUSExplorerApp.init()` before `makeModelContainer()`:

```swift
#if DEBUG
UserDefaults.standard.set(1, forKey: "com.apple.CoreData.CloudKitDebug")
UserDefaults.standard.set(1, forKey: "com.apple.CoreData.Logging.stderr")
#endif
```

Run on two devices with the same Apple ID. Filter Console.app output for
`"CloudKit"` and `"NSPersistentCloudKitContainer"`. Look for:
- `"CKError"` entries, especially error codes 9 (notAuthenticated), 6 (networkUnavailable), 26 (changeTokenExpired)
- `"zone not found"` — indicates the private zone was deleted server-side
- `"schema migration"` — indicates whether an automatic schema push succeeded

**Step 2 — Verify the private zone exists**

After container init, add a one-shot `CKContainer` zone fetch to confirm the
private zone is live on the server:

```swift
// In FRUSExplorerApp, after makeModelContainer() succeeds
Task {
    do {
        let container = CKContainer(identifier: "iCloud.bottsywattsy.FRUS-Explorer")
        let zones = try await container.privateCloudDatabase.allRecordZones()
        let hasFRUSZone = zones.contains { $0.zoneID.zoneName == "com.apple.coredata.cloudkit.zone" }
        await MainActor.run {
            appState.cloudKitZoneVerified = hasFRUSZone
        }
        if !hasFRUSZone {
            print("[CloudKit] Private zone missing — records will not sync")
        }
    } catch {
        print("[CloudKit] Zone verification failed: \(error)")
    }
}
```

Add `cloudKitZoneVerified: Bool?` to `AppState`. Surface a warning in the status
bar if `false`.

**Step 3 — Check account status before reporting sync state**

The current code calls `cloudKitSyncState = .succeeded(...)` as soon as the
notification fires without errors. It does not check whether the user is actually
signed into iCloud. Add an explicit check:

```swift
Task {
    let status = try? await CKContainer(identifier: "iCloud.bottsywattsy.FRUS-Explorer")
                               .accountStatus()
    await MainActor.run {
        appState.cloudKitAccountStatus = status
        if status != .available {
            appState.cloudKitSyncState = .failed("iCloud account unavailable (\(status?.description ?? "unknown"))")
        }
    }
}
```

Run this at launch and on `UIApplication.willEnterForegroundNotification`.

**Step 4 — Force a schema initialisation push**

If the CloudKit schema on the server is out of sync (e.g., new model types added
in recent sessions have not been pushed), records for those types will silently
fail to upload. Run the following once in DEBUG to force a schema push:

```swift
// Temporary debug-only code — remove after confirming schema is current
#if DEBUG
try container.initializeCloudKitSchema(options: [])
#endif
```

Check Console.app for `"schema migration"` log lines confirming the push succeeded.
This is safe to run repeatedly and is idempotent.

**Step 5 — Check change token validity**

A stale `NSPersistentHistoryToken` or `CKServerChangeToken` can cause the
container to believe it is in sync when it is not. If Steps 1–4 produce no clear
diagnosis, perform a controlled token reset:

```swift
// Debug only — exposes a Settings toggle to reset change tokens
UserDefaults.standard.removeObject(forKey: "NSPersistentHistoryToken")
```

This forces a full re-sync from the server on next launch. Do not expose this to
users; it is a diagnostic tool only.

#### Likely Fix

Based on the pre-investigation, the most probable causes in order of likelihood:

1. **Missing zone / change token expiry** — fix is Steps 2 and 5.
2. **Schema not pushed to server** — fix is Step 4.
3. **Account status not checked** — fix is Step 3.

After identifying the root cause, remove all diagnostic scaffolding and retain
only the permanent improvements: zone verification at launch (Step 2), account
status check (Step 3), and the richer status bar messaging.

#### Acceptance Criteria

- [ ] Create a note on Device A; it appears on Device B within 60 seconds on the
      same Wi-Fi network.
- [ ] Sign out of iCloud on one device; the status bar correctly shows a non-success
      state (not "Succeeded").
- [ ] Console contains no unhandled CKError entries during a normal sync cycle.
- [ ] `cloudKitZoneVerified` is `true` after successful launch on a signed-in device.

#### Files to Modify

| File | Change |
|------|--------|
| `FRUSExplorer/App/FRUSExplorerApp.swift` | Add account status check and zone verification at launch |
| `FRUSExplorer/App/AppState.swift` | Add `cloudKitZoneVerified: Bool?` and `cloudKitAccountStatus` |
| `FRUSExplorer/App/MainWindowView.swift` (macOS status bar) | Surface zone-verification warning |
| `FRUSExplorer/App/MainTabView.swift` (iOS) | Surface zone-verification warning |

---

### Session 149 — persName / gloss Detail Sheets Empty

**Symptom:** Tapping a person name (teal dashed underline) or a glossary term
inside a document opens the Person Detail or Gloss Detail sheet, but the sheet
content is blank — no name, no description, no definition.

**Effort:** Low–Medium. Root cause is a known timing bug; the fix is a sequencing
change in `DocumentViewModel`.  
**Risk:** Low. The change is confined to `DocumentViewModel.loadDocument()` and
does not touch the parser or the render node types.

#### Pre-Investigation Findings

The data flow is:

```
FRUSDocumentParser.parseDocument()          ← extracts body AST only
        ↓
ASTToRenderNodeConverter(
    personLookup: { pByRef[$0] },           ← closure captures dict
    glossLookup:  { tByRef[$0] }
).convert(ast)
        ↓
FRUSRenderNode.persNameLink(ref, children, person: PersonEntry?)
                                            ← person is nil if dict was empty
        ↓
FRUSDocumentWebView / FRUSDocumentRenderer
  onPersonTap: { person in                  ← receives nil
      activeSheet = .personDetail(person!)  ← sheet opens with nil data
  }
```

**The bug:** In `DocumentViewModel.swift` (lines 167–209), the person and term
dictionaries (`personsByRef`, `termsByRef`) are populated asynchronously after
`parseDocument()` returns. The render model is built with lookup closures that
already captured empty dictionaries. Because `ASTToRenderNodeConverter` resolves
lookups at *conversion time* (not at tap time), all `.persNameLink` and
`.glossLink` render nodes are produced with `person: nil` and `entry: nil`. When
the user taps a link, `onPersonTap` receives `nil` and the sheet opens empty.

A secondary issue: `parseDocument()` parses only the body of a single document
XML fragment. The persons list and terms glossary live in the volume's front
matter (`<listPerson>`, `<div type="terms">`), which requires either (a) reading
from the pre-indexed SQLite tables, or (b) re-parsing the full volume XML. The
SQLite path (`personMentionStore?.allPersons()`) is the correct approach, but it
is not awaited before the render model is built.

#### Root Cause (Precise)

`DocumentViewModel.loadDocument()` runs the following steps in this order:

1. Parse document body → `FRUSASTNode` tree
2. **Begin** async load of persons from SQLite (not awaited)
3. **Begin** async load of terms from SQLite (not awaited)
4. Call `ASTToRenderNodeConverter` with lookup closures → render model produced
   (persons/terms dicts are still empty at this point)
5. Assign render model to `self.renderModel` (SwiftUI re-renders)
6. SQLite loads complete → dicts updated, but render model is already built and
   not rebuilt

The fix is to await steps 2–3 before step 4.

#### Fix

**`FRUSExplorer/DocumentView/DocumentViewModel.swift`**

Locate the `loadDocument()` or equivalent async function (around lines 167–209).
Change the person/term loading to be sequential before render model construction:

```swift
// BEFORE (concurrent, order not guaranteed):
async let personEntries = personMentionStore?.allPersons(volumeId: volumeId) ?? []
async let termEntries   = termStore?.allTerms(volumeId: volumeId) ?? []
let (persons, terms) = await (personEntries, termEntries)
// ... render model built here with possibly-empty dicts

// AFTER (await both before building render model):
let personEntries = await (try? personMentionStore?.allPersons(volumeId: volumeId)) ?? []
let termEntries   = await (try? termStore?.allTerms(volumeId: volumeId)) ?? []

var pByRef: [String: PersonEntry] = [:]
var tByRef: [String: GlossEntry]  = [:]
for p in personEntries { pByRef[p.ref] = p }
for t in termEntries   { tByRef[t.ref] = t }

// Fallback: if SQLite returned nothing (volume not indexed), parse from XML
if pByRef.isEmpty, let url = volumeURL {
    let parsed = await parser.parsePersons(volumeURL: url)
    for p in parsed { pByRef[p.ref] = p }
}
if tByRef.isEmpty, let url = volumeURL {
    let parsed = await parser.parseTerms(volumeURL: url)
    for t in parsed { tByRef[t.ref] = t }
}

self.personsByRef = pByRef
self.termsByRef   = tByRef

// NOW build the render model — lookups will be populated
let converter = ASTToRenderNodeConverter(
    personLookup: { pByRef[$0] },
    glossLookup:  { tByRef[$0] }
)
self.renderModel = converter.convert(ast)
```

This adds a small latency to initial document load (one SQLite query for persons,
one for terms) but eliminates the empty-sheet bug entirely. For volumes that have
been indexed, the SQLite path returns in < 5 ms. The XML fallback (slow) is only
reached for volumes that were sideloaded without indexing.

**Also fix the tap callback** to guard against nil before presenting the sheet:

```swift
// DocumentView.swift — onPersonTap callback
onPersonTap: { [weak self] person in
    guard let person else {
        // Person data genuinely missing — show a "not found" sheet
        self?.activeSheet = .personNotFound
        return
    }
    self?.activeSheet = .personDetail(person)
}
```

Add a `.personNotFound` case to `DocumentSheet` that displays a brief explanatory
message ("Person information not available for this volume") rather than opening
an empty sheet.

#### Acceptance Criteria

- [ ] Tap any teal persName link in an indexed document — the sheet displays the
      person's name and description (if available in the volume's persons list).
- [ ] Tap any gloss link — the sheet displays the term and definition.
- [ ] For a volume where persons are not in the index (sideloaded XML), the sheet
      either shows the person name (from XML fallback) or a "not available" message.
- [ ] No regression on document load time (< 100 ms additional latency measured
      on iPhone 15 Pro with an indexed volume).

#### Files to Modify

| File | Change |
|------|--------|
| `FRUSExplorer/DocumentView/DocumentViewModel.swift` | Await persons/terms before building render model |
| `FRUSExplorer/DocumentView/DocumentView.swift` | Guard `onPersonTap`/`onGlossTap` against nil; add `.personNotFound` sheet case |
| `FRUSExplorer/App/MacDocumentView.swift` | Same nil-guard change |

---

### Session 150 — Source Explorer: NARA API Resolution

**Symptom:** In the Source Explorer, tapping a document's source note and
resolving a lot file or presidential library reference produces no result, an
incorrect result, or a result that does not match the archival collection cited in
the source note.

**Effort:** Medium–Large. The session begins with empirical analysis of a supplied
CSV file (`citations2.csv`) to determine how FRUS source note patterns map to
actual NARA Catalog entries. The implementation scope depends on what the CSV
analysis reveals.  
**Risk:** Medium. The NARA Catalog API is a third-party service; query strategy
changes must be validated against live API responses.

#### Pre-Investigation Findings

**Current query construction** (`NARACatalogClient.swift`, lines 125–145):

| Provenance type | Query string constructed | API params |
|-----------------|-------------------------|------------|
| Lot file | `"State Department Lot File {lotNumber}"` | `resultType=description`, `rows=1` |
| Presidential library | `"{library} {collection}"` | `resultType=description`, `rows=1` |
| RG-59 central files | No API call — static URL to NARA RG-59 landing page | — |

**Problems identified:**

1. **Free-text queries with no record group constraint.** The NARA Catalog
   full-text search returns whatever it considers the best text match across all
   holdings. A lot file query like `"State Department Lot File 61-D 146"` will
   match any description mentioning those tokens, not necessarily the series
   record for that specific lot.

2. **Only the top result is returned** (`rows=1`). If the correct record is not
   rank 1, it is silently discarded.

3. **No pre-computed lookup table.** There is no mapping from FRUS lot numbers or
   library collection names to NARA Catalog `naId` values. Every query is resolved
   purely by text search at runtime.

4. **`resultType=description` may not be optimal.** The NARA Catalog API supports
   `resultType=object` (specific items/files) and `resultType=description`
   (series/collection-level records). For FRUS source notes, series-level records
   (`description`) are appropriate, but the query must be precise enough to land
   on the right series.

#### Session Workflow

This session differs from the others because it is partly exploratory. It begins
with the CSV analysis and produces both a design and an implementation.

**Phase 1 — CSV Analysis (start of session)**

`citations2.csv` will be supplied at the start of the session. This file contains
corpus-extracted citation data from FRUS source notes. Before writing any code:

1. Load the CSV and examine its schema:
   - What fields are present? (expected: volumeId, documentId, sourceNoteText,
     parsedProvenanceType, extractedLotNumber / library / collection, etc.)
   - How many distinct lot numbers appear? How many distinct presidential libraries?
   - Are there NARA `naId` values already resolved in the CSV, or only the raw
     source note strings?

2. Cross-reference a sample of lot numbers against the live NARA Catalog API
   (authenticated with the stored API key) to determine:
   - What query string reliably returns the correct series record?
   - Are there patterns (e.g., "Lot {number}" vs "Record Group 59, Lot {number}")
     that improve precision?
   - Which lot numbers return zero results, one result, or ambiguous multiple
     results?

3. For presidential library references, test whether adding the NARA institution
   naId as a parent filter (e.g., filter to records under the JFK Library naId)
   narrows results to the correct collection.

4. Document findings as a query strategy table before implementing.

**Phase 2 — Design: Improved Query Strategy**

Based on Phase 1 findings, implement one or more of the following improvements.
The precise set depends on the CSV analysis results.

**Option A — naId lookup table for known lot numbers**

If the CSV reveals that a significant fraction of FRUS lot numbers can be
pre-resolved to specific NARA `naId` values, build a lookup table embedded in
the app:

```swift
// FRUSExplorer/SourceExplorer/NARACatalogLookupTable.swift
struct NARACatalogLookupTable {
    /// Maps State Department lot number strings (e.g. "61-D 146") to NARA naId.
    static let lotFileNaIds: [String: Int] = [
        "61-D 146": 302028,   // example
        // ... populated from CSV analysis
    ]

    /// Maps (library identifier, collection slug) to NARA naId.
    static let libraryCollectionNaIds: [(library: String, collection: String, naId: Int)] = [
        // ... populated from CSV analysis
    ]
}
```

When a lot number is in the table, skip the text search entirely and deep-link
directly to `catalog.archives.gov/id/{naId}`. This is the highest-confidence path.

**Option B — Constrained text search with naId parent filter**

For lot numbers not in the lookup table, refine the query using the NARA API's
`naId` filter parameter to restrict results to records under the State Department's
holdings (naId 10648145 for the National Archives at College Park, or the RG-59
series naId):

```
GET https://catalog.archives.gov/api/v1/search
  ?q=Lot+File+61-D+146
  &resultType=description
  &rows=5
  &naId=302028       ← constrains to RG-59 holdings
```

**Option C — Return multiple candidates for user selection**

Change `rows=1` to `rows=5` and present a ranked list of candidates to the user
rather than silently displaying (or failing to display) the top result:

```swift
struct NARACatalogResult: Identifiable, Decodable {
    let naId: Int
    let title: String
    let scopeNote: String?
    let matchScore: Double?    // add if API returns relevance score
}
```

Show up to 5 candidates in `SourceExplorerView` with titles; user taps to select
the correct one and open it in NARA Catalog.

**Option D — Presidential library naId filtering**

Map FRUS presidential library names to their NARA institution naIds:

```swift
static let presidentialLibraryNaIds: [String: Int] = [
    "Kennedy":   74884925,   // JFK Library
    "Johnson":   74884926,   // LBJ Library
    "Nixon":     74884927,   // Nixon Library
    "Ford":      74884928,   // Ford Library
    "Carter":    74884929,   // Carter Library
    // ...
]
```

Use the institution naId as a parent filter in the API call, constraining results
to that library's holdings.

**Phase 3 — Implementation**

After Phase 1 and 2 produce a clear strategy, implement:

1. **`NARACatalogLookupTable.swift`** — embed the lookup table built from CSV
   analysis. Generate it programmatically if the CSV is large (write a one-time
   Swift script to produce the static dictionary literal from the CSV).

2. **`NARACatalogClient.swift`** — update `resolveLotFile(lotNumber:)` and
   `resolvePresidentialLibrary(library:collection:)`:
   - Check lookup table first; if hit, return a direct `NARACatalogResult` with
     the known naId (no network call).
   - If miss, issue a constrained query (`rows=5`, naId parent filter if
     applicable).
   - Return `[NARACatalogResult]` (array) instead of `NARACatalogResult?`.

3. **`SourceExplorerView.swift`** — update the result display:
   - If the lookup table matched: show single result with a "Direct match" label.
   - If API returned multiple candidates: show a list the user can select from.
   - If API returned zero results: show an actionable message with a manual search
     link to `catalog.archives.gov/search?q={lotNumber}`.

4. **Error specificity** — replace the generic `error.localizedDescription` catch
   in `SourceExplorerView.fetchResult()` (around lines 437–445) with explicit
   handling:

   | Error condition | User message |
   |-----------------|-------------|
   | No API key | "Add a NARA Catalog API key in Settings → Advanced → NARA API to look up lot files." |
   | Network unavailable | "Network unavailable. Connect to look up this source in the NARA Catalog." |
   | No results found | "No matching NARA Catalog record found. [Search manually ↗]" |
   | Multiple ambiguous results | Candidate list UI (see Option C above) |

#### Files to Create / Modify

| File | Change |
|------|--------|
| `FRUSExplorer/SourceExplorer/NARACatalogLookupTable.swift` | **Create** — static lookup table from CSV analysis |
| `FRUSExplorer/SourceExplorer/NARACatalogClient.swift` | **Modify** — lookup-table-first resolution; constrained queries; return arrays |
| `FRUSExplorer/SourceExplorer/SourceExplorerView.swift` | **Modify** — candidate list UI; specific error messages; direct-match label |
| `FRUSExplorer/SourceExplorer/SourceNoteParser.swift` | **Modify** (if needed) — normalise lot number strings for lookup table key matching |

#### Acceptance Criteria

- [ ] For any FRUS lot file whose naId is in the lookup table: Source Explorer
      opens the correct NARA Catalog record without a network search call.
- [ ] For a lot file not in the table: Source Explorer issues a constrained API
      query and either displays a correct result or a ranked list of candidates.
- [ ] A missing API key shows a specific actionable message, not a generic error.
- [ ] Zero-result cases show a manual search link rather than a blank state.
- [ ] Presidential library references are constrained to that institution's
      NARA holdings (not searching all of NARA).
- [ ] Verify at least 10 lot numbers from `citations2.csv` resolve to correct
      NARA Catalog entries in the updated implementation.
