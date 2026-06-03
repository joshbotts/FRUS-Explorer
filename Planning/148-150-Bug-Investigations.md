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

### Session 150 — Source Explorer: NARA Resolution (Revised Strategy)

**Symptom:** In the Source Explorer, tapping a document's source note and
resolving a lot file or presidential library reference produces no result, an
incorrect result, or a result that does not match the archival collection cited in
the source note.

> **Revision note (2026-06-02):** The original Session 150 plan was drafted before
> empirical analysis of `citations2.csv` (322,060 source notes from published FRUS
> volumes) and before reviewing NARA's published finding-aid structure for RG 59.
> The revised plan below replaces the original Tier 1/2/3 strategy in its entirety.
> The core principle is: **prefer honest navigation links over speculative API queries.**
> Every citation type either resolves to a specific NARA Catalog record (lot files,
> some record groups) or is routed to the correct NARA finding-aid web page (decimal
> files, central files, foreign archives). Citing types that cannot be resolved via
> the API are never sent to the API; instead the UI shows a targeted search link
> with the correct scope already encoded.

**Effort:** Medium. The citation-type corpus analysis has already been done;
the revised strategy is based on empirical findings from 322,060 FRUS source
notes. Live API validation is still required for lot file queries but the scope
is narrower than the original plan.  
**Risk:** Low–Medium. The dominant citation types (decimal files, post-1963
central files) are handled by static URL construction with no API dependency.
The only API-dependent path (lot files, 8.0% of citations) uses a single
constrained field query with a well-defined normalization strategy.

#### Citation Corpus Summary (322,060 source notes analysed)

Analysis of `citations2.csv` reveals the following distribution, which drives
the resolution strategy below:

| Citation Type | Count | % | Resolution Method |
|---|---:|---:|---|
| State Dept Decimal File (RG 59, pre-1963) | 152,447 | 47.3% | Static URL — date-routed NARA finding aid |
| State Dept Lot File (RG 59) | 25,914 | 8.0% | NARA Catalog API — `variantControlNumber_is` |
| State Dept Central Files (RG 59, post-1963) | 16,232 | 5.0% | Static URL — date-routed NARA finding aid |
| Presidential Libraries (all) | 39,952 | 12.4% | NARA Catalog keyword search + library-specific fallback URL |
| Defense/JCS (RG 218) | 2,484 | 0.8% | NARA Catalog — `recordGroupNumber=218` |
| Defense/OSD (RG 330) | 795 | 0.2% | NARA Catalog — `recordGroupNumber=330` |
| USIA (RG 306) | 540 | 0.2% | NARA Catalog — `recordGroupNumber=306` |
| State Dept Post Records (RG 84) | 154 | 0.0% | NARA Catalog — `recordGroupNumber=84` |
| CIA Records | 1,968 | 0.6% | Static URL — CIA CREST / reading room link |
| Library of Congress | 1,048 | 0.3% | Static URL — LOC finding aid search |
| Published / Editorial / Cross-ref | 1,716 | 0.5% | No resolution attempted |
| Other / Unclassified | 73,627 | 22.9% | No resolution; show general NARA search link |

Lot numbers in FRUS citations are almost universally in compact form without
spaces: `63D135`, `67D131`, `72D316`. Spaced variants like `63 D 135` are
extremely rare in the corpus but must be handled in normalization.

#### Resolution Strategy by Citation Type

---

##### 1. State Dept Lot Files — RG 59 (25,914 citations, 8.0%)

**Approach: NARA Catalog API v2 — `variantControlNumber_is` field query**

NARA Catalog indexes lot file numbers as `variantControlNumber` on series
description records. This is a direct field match — far more precise than
free-text `q=` search — and does not require guessing the right rank-1 hit.

**Lot number normalization strategy:**

FRUS citations use compact form almost exclusively (`63D135`, `72D316`). NARA
may index them with spaces (`63 D 135`) or without. Generate three candidates
and try each until one returns a result:

```swift
func lotNumberVariants(_ raw: String) -> [String] {
    // raw input: "63D135" or "63 D 135" or "63-D-135" or "Lot 63D135"
    // 1. Strip "Lot" prefix, whitespace, dashes → compact canonical form
    let stripped = raw.replacingOccurrences(of: "Lot", with: "", options: .caseInsensitive)
                      .replacingOccurrences(of: "-", with: "")
                      .replacingOccurrences(of: " ", with: "")
                      .trimmingCharacters(in: .whitespaces)
    // 2. Insert spaces around the letter: "63D135" → "63 D 135"
    guard let m = stripped.range(of: #"^(\d{2,3})([A-Z])(\d+)$"#,
                                  options: .regularExpression) else {
        return [stripped]   // unusual format — try as-is
    }
    // Extract the three components
    let digits1 = String(stripped.prefix(while: \.isNumber))
    let letter  = String(stripped.dropFirst(digits1.count).prefix(1))
    let digits2 = String(stripped.dropFirst(digits1.count + 1))
    return [
        "\(digits1)\(letter)\(digits2)",        // compact: "63D135"
        "\(digits1) \(letter) \(digits2)",      // spaced:  "63 D 135"
        "\(digits1) \(letter)\(digits2)",       // mixed:   "63 D135"
    ]
}
```

**Query construction (v2 API):**

```
GET https://catalog.archives.gov/api/v2/records/search
  ?variantControlNumber_is={lotNumberVariant}
  &description.recordGroupNumber=59
  &resultTypes=description
  &rows=5
  x-api-key: {apiKey}
```

Try each variant in sequence; stop at the first non-empty result. If all three
variants return zero results, fall back to a free-text `q=` query with
`description.recordGroupNumber=59` as a constraint (keeps earlier `searchByLotFile`
logic as a safety net).

If all queries return zero results, do NOT show a generic error. Instead, show:
> "No NARA Catalog record found for this lot file. Search manually:"
> [Button → `https://catalog.archives.gov/search?q={lotNumber}&f.parentDescriptionNaId=302028`]

The fallback URL opens a pre-scoped search on the RG-59 parent record so the
user is already filtered to the right record group.

---

##### 2. State Dept Decimal Files — RG 59, 1910–1963 (152,447 citations, 47.3%)

**Approach: Static date-routed NARA finding aid URLs — NO API call**

Individual decimal file documents are not cataloged at the item level in the
NARA Catalog. The correct response is to navigate the user to the finding aid
for the relevant filing period and explain the filing system so they can
conduct their own search.

NARA has published seven period-specific research pages for the decimal files,
each with links to box lists, purport indexes, and the applicable filing manual:

| Period | NARA Research Page |
|--------|-------------------|
| 1910–1929 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1910-1963/1910-1929` |
| 1930–1939 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1910-1963/1930-1939` |
| 1940–1944 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1910-1963/1940-1944` |
| 1945–1949 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1910-1963/1945-1949` |
| 1950–1954 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1910-1963/1950-1954` |
| 1955–1959 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1910-1963/1955-1959` |
| 1960–Jan 1963 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1910-1963/1960-1963` |

**Date routing:** `SourceNoteParser` should extract the document date from the
FRUS document context (already available via `DocumentBrowserEntry.dateISO`).
Map the year to the filing period using a static lookup table:

```swift
static func decimalFilePeriodURL(year: Int) -> URL {
    let slug: String
    switch year {
    case ..<1910:    slug = "1910-1929"   // pre-decimal; use earliest period as fallback
    case 1910...1929: slug = "1910-1929"
    case 1930...1939: slug = "1930-1939"
    case 1940...1944: slug = "1940-1944"
    case 1945...1949: slug = "1945-1949"
    case 1950...1954: slug = "1950-1954"
    case 1955...1959: slug = "1955-1959"
    default:          slug = "1960-1963"  // 1960–Jan 1963
    }
    return URL(string: "https://www.archives.gov/research/foreign-policy/"
               + "state-dept/rg-59-central-files/1910-1963/\(slug)")!
}
```

**UI message:** Show the decimal file code prominently, explain what it means
(subject + country code), and link to the period-specific page:
> "This document cites decimal file **711.90G/7-2346** from the State
> Department central files. Use the filing manual for the 1945–1949 period
> to interpret the subject and country codes and locate the box."
> [Button → NARA 1945–1949 finding aid page]

No API key required. No API quota consumed.

---

##### 3. State Dept Central Files — RG 59, post-1963 (16,232 citations, 5.0%)

**Approach: Static date-routed NARA finding aid URLs — NO API call**

The post-1963 files use a subject-numeric code system (e.g. `POL 27 VIET S`,
`DEF 17 US`) organized into two further periods:

| Period | NARA Research Page |
|--------|-------------------|
| Feb 1963–1973 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1963-1973` |
| 1973–1979 | `https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1973-1979` |

Apply the same date-routing logic. For citations that already include the NARA
Catalog structure (e.g. `Source: National Archives, RG 59, Central Files
1967–69, POL 27 VIET S`), the existing `resolveRG59CentralFiles(fileIdentifier:)`
static URL method can be used directly with the subject code as the `q` parameter
(this already pre-scopes the NARA Catalog search to RG-59 children). Keep this
approach — it is correct.

---

##### 4. Presidential Libraries (39,952 citations, 12.4%)

**Approach: NARA Catalog keyword search + institution-specific fallback URL**

Presidential library records are indexed in the NARA Catalog as presidential
library staffs describe their holdings. A keyword search combining the collection
name and library name is the correct approach. The existing
`searchByPresidentialMaterials(library:collection:maxResults:)` method is
already implemented and correct.

**Nixon Presidential Materials** are a special case: these were held at NARA
College Park at the time the FRUS volumes were produced, but have since been
transferred to the Nixon Presidential Library in Yorba Linda, CA. They are
indexed in the NARA Catalog and the keyword search should work for them. No
institution-lookup phase is needed — include "Nixon" + collection keywords
directly in the `q` parameter.

**Failure handling by library:** If the API returns zero results, show a
targeted link to the institution's own online finding aids rather than a
generic NARA Catalog search link:

```swift
static func libraryFallbackURL(libraryName: String) -> URL {
    switch libraryName.lowercased() {
    case let n where n.contains("kennedy"):
        return URL(string: "https://www.jfklibrary.org/archives/finding-aids")!
    case let n where n.contains("johnson") || n.contains("lbj"):
        return URL(string: "https://www.lbjlibrary.org/research")!
    case let n where n.contains("nixon"):
        return URL(string: "https://www.nixonlibrary.gov/finding-aids")!
    case let n where n.contains("ford"):
        return URL(string: "https://www.fordlibrarymuseum.gov/library/finding-aids.asp")!
    case let n where n.contains("carter"):
        return URL(string: "https://www.jimmycarterlibrary.gov/research/finding-aids")!
    case let n where n.contains("reagan"):
        return URL(string: "https://www.reaganlibrary.gov/research")!
    case let n where n.contains("bush"):
        return URL(string: "https://www.bush41library.tamu.edu/research")!
    case let n where n.contains("eisenhower") || n.contains("ddel"):
        return URL(string: "https://www.eisenhowerlibrary.gov/research/finding-aids")!
    case let n where n.contains("truman") || n.contains("hstl"):
        return URL(string: "https://www.trumanlibrary.gov/research/finding-aids")!
    case let n where n.contains("roosevelt") || n.contains("fdrl"):
        return URL(string: "https://www.fdrlibrary.org/finding-aids")!
    default:
        return URL(string: "https://www.archives.gov/presidential-libraries")!
    }
}
```

**Return up to 3 results** for the user to choose from, not just 1.

---

##### 5. Defense/JCS Records — RG 218, RG 330 (3,279 citations, 1.0%)

**Approach: NARA Catalog API — `recordGroupNumber` constraint**

The existing `searchByRecordGroup(_:keywords:maxResults:)` method is correct.
Use the series keywords from the parsed citation alongside the record group
constraint:

```
GET /api/v2/records/search
  ?q={seriesKeywords}
  &description.recordGroupNumber=218   (or 330)
  &resultTypes=description
  &rows=5
```

Where `seriesKeywords` is the series title fragment extracted by `SourceNoteParser`
(e.g. "Geographic File" from "JCS Geographic File, 1942-1945"). No fallback
needed — if zero results, show a NARA Catalog search link scoped to the record
group: `catalog.archives.gov/search?q={keywords}&f.recordGroupNumber=218`.

---

##### 6. USIA Records — RG 306 (540 citations, 0.2%)

Same approach as Defense/JCS using `description.recordGroupNumber=306`.

---

##### 7. State Dept Post Records — RG 84 (154 citations, 0.0%)

Same approach using `description.recordGroupNumber=84`.

---

##### 8. CIA Records (1,968 citations, 0.6%)

**Approach: Static link to CIA CREST — NO API call**

CIA records are not in the NARA Catalog. CIA Historical Files (HS/HC-xxx series)
and CIA operational records (Job Numbers) are accessible via the CIA's CREST
database and reading room:

```swift
static func ciaResearchURL(jobNumber: String? = nil) -> URL {
    if let job = jobNumber, !job.isEmpty {
        // CREST allows job number search
        let encoded = job.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? job
        return URL(string: "https://www.cia.gov/readingroom/search/site/\(encoded)")!
    }
    return URL(string: "https://www.cia.gov/readingroom/")!
}
```

Display message: "CIA records are not in the NARA Catalog. Search the CIA CREST
database for this document:"
[Button → CREST search or reading room]

---

##### 9. Unresolvable Citation Types

The following types should display an explanation and a general NARA search
link, but no API call should be attempted:

| Type | Action |
|------|--------|
| Library of Congress (1,048) | Link to `https://lccn.loc.gov` or `https://catalog.loc.gov` |
| Published govt sources (587) | No link; note the document is publicly available online |
| Internal cross-references (668) | No link; explain it refers to another FRUS document |
| Other/unclassified (73,627) | Show `catalog.archives.gov/search?q={encodedText}` as a general search link |

#### Implementation Plan

**Phase 1 — `NARACatalogClient.swift` updates**

1. Add `resolveLotFileVariants(lotNumber:) async throws -> [NARACatalogResult]`
   implementing the three-variant `variantControlNumber_is` approach with
   `description.recordGroupNumber=59` constraint. Keep existing `resolveLotFile`
   as a deprecated wrapper calling this new method.

2. Add `decimalFilePeriodURL(year:) -> URL` static method (no API call).

3. Add `libraryFallbackURL(libraryName:) -> URL` static method (no API call).

4. Add `ciaResearchURL(jobNumber:) -> URL` static method (no API call).

5. Update `NARACatalogResult` to include `scopeContent: String?` and
   `seriesTitle: String?` if not already present.

**Phase 2 — `SourceNoteParser.swift` updates**

1. Ensure lot number extraction strips "Lot " prefix and normalises spaces/dashes.
   Current compact form (`63D135`) is already the dominant corpus format; add
   handling for the rare spaced form.

2. Expose the document date (year) to the resolution layer so period routing
   can be applied to decimal and central file citations.

**Phase 3 — `SourceExplorerView.swift` updates**

1. Implement the citation-type dispatch table: route each `ParsedSourceNote` case
   to the appropriate resolution method (API call, static URL, or no-op).

2. For API-returning paths (lot files, presidential libraries, record groups):
   - Show a loading indicator during the API call
   - Display up to 5 ranked results in a list; each row shows title + truncated
     scope note; tapping opens `catalog.archives.gov/id/{naId}` in the in-app
     browser
   - Zero results: show the fallback search URL with an explanatory message
   - Error states: specific messages per error type (see below)

3. For static-URL paths (decimal files, central files, CIA):
   - No loading indicator (no network call)
   - Show the formatted citation code prominently
   - Explain what the code means (filing system context)
   - Link button to the appropriate NARA or CIA page

4. Error messages:

| Error condition | Message |
|---|---|
| API key missing | "Add a NARA Catalog API key in Settings → NARA API to look up lot files." |
| Network unavailable | "Network unavailable. Connect to search the NARA Catalog." |
| HTTP 429 / rate limit | "NARA API rate limit reached. Try again later or search manually." |
| HTTP 403 | "NARA API key rejected. Check the key in Settings → NARA API." |
| Zero results (all variants tried) | "No NARA Catalog record found. [Search NARA ↗]" |

#### Files to Modify

| File | Change |
|------|--------|
| `FRUSExplorer/SourceExplorer/NARACatalogClient.swift` | `variantControlNumber_is` lot file resolution; `decimalFilePeriodURL`; `libraryFallbackURL`; `ciaResearchURL` |
| `FRUSExplorer/SourceExplorer/SourceNoteParser.swift` | Lot number normalisation; expose document year for period routing |
| `FRUSExplorer/SourceExplorer/SourceExplorerView.swift` | Citation-type dispatch; multi-result list UI; static-URL display; error specificity |

#### Acceptance Criteria

- [ ] Lot file: `variantControlNumber_is` query tried for compact, spaced, and mixed
      forms before free-text fallback; verify via DEBUG URL log.
- [ ] Lot file with no result across all variants: shows fallback search link scoped
      to RG-59 parent description; never shows a generic error or blank state.
- [ ] Decimal file (1910–1963): displays filing-period NARA page URL derived from
      document year; no API call made; no API key required.
- [ ] Post-1963 central file: routes to 1963–1973 or 1973–1979 period page using
      document year; existing `resolveRG59CentralFiles` used for subject-numeric code.
- [ ] Presidential library: keyword search returns up to 3 results; zero-result path
      shows institution-specific finding aid URL (e.g. `jfklibrary.org/archives`).
- [ ] CIA record: shows CREST link with job number or general reading room URL; no
      API call attempted.
- [ ] API key missing: shows specific Settings-navigation message, not a generic error.
- [ ] HTTP 429 and 403: show distinct user-facing messages.


| Provenance type | Query string constructed | API params |
|-----------------|-------------------------|------------|
| Lot file | `"State Department Lot File {lotNumber}"` | `resultType=description`, `rows=1` |
| Presidential library | `"{library} {collection}"` | `resultType=description`, `rows=1` |
| RG-59 central files | No API call — static URL to NARA RG-59 landing page | — |

**Problems identified:**

1. **Free-text queries with no record group constraint.** The NARA Catalog
   full-text search returns whatever it considers the best text match across all
   holdings. A lot file query like `"State Department Lot File 61-D 146"` may
   match any description mentioning those tokens — not necessarily the series
   record for that specific lot.

2. **Only the top result is returned** (`rows=1`). If the correct record is not
   rank 1, it is silently discarded.

3. **`resultType=description` may not be optimal.** The API supports
   `resultType=object` (item/file level) and `resultType=description`
   (series/collection level). For FRUS source notes, series-level records are
   appropriate, but this must be confirmed empirically.

4. **Known API constraint: no direct naId→naId mapping exists.** There is no
   way to derive a NARA Catalog record's `naId` from a FRUS lot number or
   collection name without issuing an API query. All resolution must go through
   the search endpoint.

#### API Query Capabilities

The following NARA Catalog API v1 parameters are confirmed available and should
be used to constrain queries beyond unstructured free text:

| Parameter | Description | Relevant use |
|-----------|-------------|--------------|
| `q` | Free-text query across all indexed fields | Lot number, collection name |
| `resultType` | `description` (series) or `object` (item) | Always `description` for FRUS source notes |
| `rows` | Number of results returned (default 1) | Increase to 5 for candidate display |
| `f.parentDescriptionNaId` | Restricts results to children of a known record | Filter lot files to RG-59 (naId 302028) |
| `recordGroupNumber` | Restricts to a specific NARA record group number | `recordGroupNumber=59` for lot files |

The `recordGroupNumber=59` and `f.parentDescriptionNaId=302028` filters are
complementary: `recordGroupNumber` restricts to the RG-59 *record group* broadly;
`f.parentDescriptionNaId=302028` restricts to children of the specific RG-59
top-level description record already hardcoded in `NARACatalogClient`. Use both
in tandem for lot file queries to maximise precision.

Presidential libraries are not record groups; they are NARA-operated institutions
with their own top-level description naIds. These naIds are not known in advance
and must be discovered through a one-time institution-lookup query at session start,
then cached for the session.

#### Session Workflow

**Phase 1 — Live API Testing with citations2.csv (start of session)**

`citations2.csv` will be supplied at the start of the session. Treat it as a
validation corpus, not a source of pre-computed mappings. Before writing any code:

1. Examine the CSV schema: confirm which fields are present (expected: volumeId,
   documentId, parsedProvenanceType, extractedLotNumber, library, collection,
   fileIdentifier). Note how many distinct lot numbers and library references appear.

2. Select a representative sample of 10–15 lot numbers and 5 presidential library
   references. Issue live API queries for each using the candidate strategies below,
   recording: query sent, top-5 results returned (naId + title), and whether the
   correct record appears in those 5.

3. For each provenance type, determine which query strategy produces the correct
   record in position 1–5 most reliably. Document findings as a strategy table
   before writing any implementation code.

4. Identify which citations return zero results from the API. These represent a
   "no match" state that the UI must handle gracefully — they are not errors.

**Phase 2 — Query Strategy Design**

The query strategy is built in tiers. Attempt the most-constrained query first;
fall back to progressively looser queries if the constrained form returns zero
results. All resolution goes through the API.

**Tier 1 — Lot files: constrained to RG-59**

State Department lot files live under Record Group 59. Use both available
constraints simultaneously:

```
GET https://catalog.archives.gov/api/v1/search
  ?q={lotNumber}
  &recordGroupNumber=59
  &f.parentDescriptionNaId=302028
  &resultType=description
  &rows=5
```

The `lotNumber` query term should be sent as extracted from the source note (e.g.
`61-D 146`), without decorative prefixes like "State Department Lot File". The
lot number string itself is the most distinctive token. If the Tier 1 query
returns zero results, retry without `f.parentDescriptionNaId` (keeping
`recordGroupNumber=59` only), then without both constraints if still empty.

**Tier 2 — Presidential libraries: two-phase institution lookup**

Presidential libraries are not record groups. Resolution requires two queries:

*Phase A — Discover the institution's naId (one query per library per session,
result cached in memory):*

```
GET https://catalog.archives.gov/api/v1/search
  ?q={libraryName}+Presidential+Library
  &resultType=description
  &rows=1
```

where `libraryName` is the surname extracted by `SourceNoteParser` (e.g.
`"Kennedy"`). Extract the `naId` of the top result; cache it in a
`[String: Int]` dictionary keyed on the surname for the session lifetime.

*Phase B — Search for the collection under the institution:*

```
GET https://catalog.archives.gov/api/v1/search
  ?q={collection}
  &f.parentDescriptionNaId={institutionNaId}
  &resultType=description
  &rows=5
```

If Phase A returns zero results (unknown library surname), fall back to a single
unconstrained query:

```
GET https://catalog.archives.gov/api/v1/search
  ?q={libraryName}+{collection}
  &resultType=description
  &rows=5
```

This two-phase approach uses at most two API calls per presidential library
reference, but the institution lookup is cached so repeated references to the
same library cost only one call total per session.

**Tier 3 — RG-59 central files**

The current implementation constructs a static URL to the RG-59 landing page
(`catalog.archives.gov/id/302028`) with no API call. This is correct and should
be retained. Central files do not need a search query because the citation
identifies them only as "RG-59, decimal file {identifier}" — the record group
record itself is the right destination.

**Phase 3 — Implementation**

1. **`NARACatalogClient.swift`** — replace `resolveLotFile(lotNumber:)` and
   `resolvePresidentialLibrary(library:collection:)`:

   ```swift
   // Lot file — tiered query with RG-59 constraints
   func resolveLotFile(lotNumber: String) async throws -> [NARACatalogResult] {
       // Tier 1: both constraints
       var results = try await search(
           query: lotNumber,
           extraParams: ["recordGroupNumber": "59",
                         "f.parentDescriptionNaId": "\(rg59NaId)",
                         "resultType": "description",
                         "rows": "5"]
       )
       // Tier 2: record group only
       if results.isEmpty {
           results = try await search(
               query: lotNumber,
               extraParams: ["recordGroupNumber": "59",
                             "resultType": "description",
                             "rows": "5"]
           )
       }
       // Tier 3: unconstrained
       if results.isEmpty {
           results = try await search(
               query: lotNumber,
               extraParams: ["resultType": "description", "rows": "5"]
           )
       }
       return results
   }

   // Presidential library — two-phase with institution naId cache
   private var institutionNaIdCache: [String: Int] = [:]

   func resolvePresidentialLibrary(
       library: String, collection: String
   ) async throws -> [NARACatalogResult] {
       let institutionNaId = try await resolveLibraryInstitution(library: library)
       if let naId = institutionNaId {
           return try await search(
               query: collection,
               extraParams: ["f.parentDescriptionNaId": "\(naId)",
                             "resultType": "description",
                             "rows": "5"]
           )
       } else {
           // Phase A failed — fall back to combined free-text query
           return try await search(
               query: "\(library) \(collection)",
               extraParams: ["resultType": "description", "rows": "5"]
           )
       }
   }

   private func resolveLibraryInstitution(library: String) async throws -> Int? {
       if let cached = institutionNaIdCache[library] { return cached }
       let results = try await search(
           query: "\(library) Presidential Library",
           extraParams: ["resultType": "description", "rows": "1"]
       )
       let naId = results.first?.naId
       if let naId { institutionNaIdCache[library] = naId }
       return naId
   }
   ```

   Change the return type of both resolution functions from `NARACatalogResult?`
   to `[NARACatalogResult]`. Extract the shared `search(query:extraParams:)` helper
   to avoid duplicating URL construction and response parsing.

2. **`NARACatalogClient.swift`** — update `NARACatalogResult`:

   ```swift
   struct NARACatalogResult: Identifiable, Sendable {
       let naId: Int
       let title: String
       let scopeContent: String?
       let seriesTitle: String?   // parent series title if available from API response
   }
   ```

3. **`SourceExplorerView.swift`** — update the result display:

   - If the API returned exactly one result: display it directly (existing layout).
   - If the API returned 2–5 results: replace the single-result view with a
     `List` of candidates. Each row shows title and (if present) a truncated scope
     note. Tapping a row opens `catalog.archives.gov/id/{naId}` in the in-app
     browser.
   - If the API returned zero results: show an actionable empty state with a
     "Search NARA Catalog" button that opens
     `catalog.archives.gov/search?q={urlEncodedQuery}` in the in-app browser.

4. **Error specificity** — replace the generic `error.localizedDescription` catch
   in `SourceExplorerView.fetchResult()` (around lines 437–445):

   | Error condition | User message |
   |-----------------|-------------|
   | No API key configured | "Add a NARA Catalog API key in Settings → Advanced → NARA API to look up lot files." |
   | Network unavailable | "Network unavailable. Connect to look up this source in the NARA Catalog." |
   | HTTP 403 / rate limit | "NARA Catalog API limit reached. Try again later or search manually." |
   | Zero results | "No matching NARA Catalog record found. [Search NARA ↗]" |

5. **`citations2.csv` as a test fixture** — at the end of the session, run a
   batch test function (DEBUG only) that iterates over a sample from the CSV,
   fires the new tiered queries, and logs which citations produced a result in
   position 1–5. This validates the strategy without any manual browsing.

#### Files to Modify

| File | Change |
|------|--------|
| `FRUSExplorer/SourceExplorer/NARACatalogClient.swift` | Tiered queries with RG-59 constraints; institution naId cache; return arrays; shared `search(query:extraParams:)` helper |
| `FRUSExplorer/SourceExplorer/SourceExplorerView.swift` | Candidate list UI; specific error messages; manual search fallback link |
| `FRUSExplorer/SourceExplorer/SourceNoteParser.swift` | Trim lot number strings if raw extraction includes surrounding whitespace or punctuation |

#### Acceptance Criteria

- [ ] Lot file query uses `recordGroupNumber=59` and `f.parentDescriptionNaId`
      constraints; verify via URL logged in DEBUG output.
- [ ] Lot file with no API results (all tiers exhausted) shows a manual search
      link rather than a blank state or generic error.
- [ ] Presidential library references issue a two-phase query; institution naId is
      cached across multiple references to the same library in one session.
- [ ] Source Explorer displays up to 5 ranked candidates when the API returns
      more than one result; user can tap any candidate to open it.
- [ ] A missing API key shows a specific actionable message, not a generic error.
- [ ] HTTP 403 and rate-limit errors show a distinct user-facing message.
- [ ] Batch test against a sample from `citations2.csv` confirms at least 70% of
      lot file citations return a non-empty candidate list from the constrained
      Tier 1 or Tier 2 query.
