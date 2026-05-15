# Session 30 — Citation Lookup

## Goal
Implement a dedicated Citation Lookup view that allows researchers to paste or manually enter a citation to a FRUS document and receive a ranked list of matches using the existing search result display. The tool handles diverse citation formats and styles, resolves page numbers to documents via `<pb>` element data, recovers gracefully from malformed citations, and applies a two-stage strategy for citations resolving to undownloaded volumes.

## Prerequisites
- Session 07 complete — `<pb>` elements surfaced in AST with `@n` attribute (see dependency note below)
- Session 09 complete — page range table populated during indexing (see dependency note below)
- Session 12 complete — Document view (for navigation from results)
- Session 16 complete — Search view (result display component reused here)

## Dependency Notes for Sessions 07 and 09

### Session 07 addition — `<pb>` in AST
Add to Session 07's element coverage:

```swift
case pageBreak(pageNumber: PageNumber)

enum PageNumber: Sendable {
    case arabic(Int)          // @n="47"
    case roman(Int)           // @n="iv" — front matter
    case prefixed(String)     // @n="A-12" or other non-standard forms
    case unparseable(String)  // preserve raw @n value if normalization fails
}
```

Normalization rules:
- Strip leading zeros
- Parse Roman numerals (i, ii, iii, iv ... up to standard front matter range)
- Preserve prefixed forms as `.prefixed` — do not attempt numeric comparison
- Log a `[TEIParser]` warning for unparseable values; never drop the element

### Session 09 addition — page range table
Add to the indexing pass alongside the cross-reference edge table:

```sql
-- Maps page numbers to the documents that contain them.
-- Built from <pb> elements encountered during TEI parsing.
-- sectionId groups pages within a compilation or chapter to handle
-- pagination restarts between volume sections.
CREATE TABLE page_ranges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    volume_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    section_id TEXT NOT NULL,     -- compilation or chapter div @xml:id
    page_number_type TEXT NOT NULL, -- 'arabic' | 'roman' | 'prefixed'
    page_number_int INTEGER,      -- NULL for non-arabic/roman types
    page_number_raw TEXT NOT NULL -- always stored for display
);
CREATE INDEX idx_page_ranges_volume ON page_ranges(volume_id, page_number_type, page_number_int);
CREATE INDEX idx_page_ranges_document ON page_ranges(volume_id, document_id);
```

Page range lookup: given a volume and an integer page number, find the document whose page_ranges span contains that page. "Span" is defined as the range from a document's first `<pb>` to the last `<pb>` before the next document's first `<pb>`. This is computed at query time from the ordered page_ranges rows, not precomputed.

Update `FRUS-API.openapi.yaml` with a `GET /volumes/{volumeId}/page-ranges` endpoint note.

---

## Specification References
- SPEC-UPDATE-Manifest-Tags.md (volume manifest structure)
- Section 12: Citation Formatter (source of truth for the history.state.gov citation style the tool must parse)
- Section 16: User Experience — Search View (result display component reused)
- Section 21: OpenAPI / Future FRUS API
- Section 22: Coding Standards

## Interface Location
Dedicated top-level view: **Citation Lookup**, accessible from the main navigation (tab bar on iPhone; sidebar on iPad and macOS). Linked from the Search view with a "Find by Citation" prompt. Also accessible from the Document view toolbar for resolving cited documents encountered while reading.

---

## Input Model

The tool provides two input modes, presented as a segmented control or tab within the view:

### Mode 1: Paste Citation (default)
A text field accepting a free-form citation string pasted from any source. The parser attempts to extract structured fields automatically. As fields are extracted, they populate the structured input fields below in real time, giving the user immediate feedback on what was parsed and allowing corrections.

### Mode 2: Structured Entry
Individual labeled fields for the components of a FRUS citation, pre-populated when parsing succeeds in Mode 1. Users can also fill these directly when they have partial information:
- Subseries / year range (e.g., "1969–76")
- Volume number (e.g., "I" or "1")
- Document number (optional)
- Page number (optional)
- Volume title fragment (optional, for disambiguation)

At least one of document number or page number must be provided to attempt a match. Subseries and volume number together without either will return volume-level metadata only.

---

## Key Types

### `CitationInput`
```swift
/// The structured representation of a parsed or manually entered FRUS citation.
/// All fields are optional — the matcher uses whatever is available.
/// Raw text is preserved alongside parsed fields for display and debugging.
///
/// Version history:
///   1.0 — Session 31: initial implementation
struct CitationInput: Sendable {
    let rawText: String?            // original pasted string; nil if structured entry
    let subseries: String?          // e.g. "1969-76"
    let volumeNumber: String?       // e.g. "I", "1", "01"
    let documentNumber: Int?        // e.g. 15
    let pageNumber: Int?            // e.g. 47
    let titleFragment: String?      // partial title text for disambiguation
    let parserConfidence: ParserConfidence   // how well the raw text parsed
}

enum ParserConfidence: Sendable {
    case high       // all key fields extracted unambiguously
    case medium     // some fields ambiguous or inferred
    case low        // minimal fields extracted; much uncertainty
    case structured // user entered fields directly; no parsing confidence issue
}
```

### `CitationMatch`
```swift
/// A single candidate match from the citation lookup engine.
/// Always displayed using the standard SearchResult view component.
/// The confidenceLabel provides an explicit human-readable explanation
/// of how the match was made and any corrections or assumptions applied.
///
/// Version history:
///   1.0 — Session 31: initial implementation
struct CitationMatch: Sendable {
    let documentId: String
    let volumeId: String
    let rank: Int                        // 1 = most likely
    let matchStrategy: MatchStrategy
    let confidenceLabel: String          // explicit, plain-language label shown in UI
    let correctionNote: String?          // explanation when best-guess recovery applied
    let requiresDownload: Bool           // true = volume not in local corpus
    let volumeManifestEntry: VolumeManifestEntry?  // for pre-download display
}

enum MatchStrategy: Sendable {
    case exactDocumentNumber            // subseries + volume + doc number → direct hit
    case pageRange                      // subseries + volume + page → document containing page
    case superimposedDocumentNumber     // pre-1955–57 volume; doc number editorially assigned
    case fuzzyDocumentNumber(nearest: Int)  // doc number not found; nearest existing doc
    case titleFragmentMatch             // volume resolved via title fragment; doc/page then matched
    case manifestOnly                   // volume not downloaded; match to volume metadata only
    case bestGuess(explanation: String) // multiple corrections applied
}
```

### `CitationParser`
```swift
/// CitationParser extracts structured CitationInput from free-form citation text.
/// Patterns are attempted from most-specific to most-general.
/// All recognized fields are extracted; unrecognized text is preserved as titleFragment
/// candidates and passed to the matcher for fuzzy resolution.
///
/// Citation format coverage:
///   - history.state.gov recommended style
///   - Chicago footnote (full and short)
///   - Informal/abbreviated (FRUS + year range + vol + doc/page)
///   - Page-only citations (common in pre-1955–57 volume references)
///   - Potentially malformed (OCR artifacts, missing punctuation, wrong numbering)
///
/// Version history:
///   1.0 — Session 31: initial implementation
struct CitationParser {
    func parse(_ rawText: String) -> CitationInput
    
    // Exposed for testing individual pattern stages
    func extractSubseries(from text: String) -> String?
    func extractVolumeNumber(from text: String) -> String?
    func extractDocumentNumber(from text: String) -> Int?
    func extractPageNumber(from text: String) -> Int?
    func extractTitleFragment(from text: String) -> String?
}
```

### `CitationMatchingEngine`
```swift
/// CitationMatchingEngine resolves a CitationInput to a ranked list of CitationMatches.
/// Matching proceeds through strategies in priority order, stopping when a
/// high-confidence match is found or exhausting all strategies.
///
/// Two-stage behavior for undownloaded volumes:
///   Stage 1: Resolve citation to a volume using manifest metadata.
///            Return a CitationMatch with requiresDownload = true and
///            volumeManifestEntry populated for user confirmation.
///   Stage 2: After user confirms download and indexing completes,
///            re-run the full match to resolve to a specific document.
///
/// Era handling:
///   Post-1955–57: document numbers are native; exact match is authoritative.
///   Pre-1955–57:  document numbers are superimposed editorially; page range
///                 lookup is the primary path; doc number match labeled accordingly.
///   Microfiche supplements: document number match only; page range not applicable.
///
/// Version history:
///   1.0 — Session 31: initial implementation
actor CitationMatchingEngine {
    func match(input: CitationInput) async throws -> [CitationMatch]
    
    private func resolveVolume(subseries: String?, volumeNumber: String?, titleFragment: String?) -> [VolumeManifestEntry]
    private func matchByDocumentNumber(volumeId: String, documentNumber: Int) async throws -> CitationMatch?
    private func matchByPageRange(volumeId: String, pageNumber: Int) async throws -> CitationMatch?
    private func matchByFuzzyDocumentNumber(volumeId: String, documentNumber: Int) async throws -> CitationMatch?
    private func isPreModernVolume(_ volumeId: String) -> Bool  // pre-1955–57 subseries
    private func isMicroficheSupplement(_ volumeId: String) -> Bool
}
```

### `PageRangeStore`
```swift
/// PageRangeStore queries the SQLite page_ranges table to resolve
/// page numbers to the documents that contain them.
///
/// Version history:
///   1.0 — Session 31: initial implementation (table built in Session 09)
actor PageRangeStore {
    /// Returns the documentId containing the given page number in the given volume.
    /// Uses section grouping to handle pagination restarts between volume sections.
    /// Returns nil if no page range data exists for this volume (e.g., microfiche supplement)
    /// or if the page number falls outside all known ranges.
    func document(forPage pageNumber: Int, inVolume volumeId: String) async throws -> String?
    
    /// Returns the page range (first page, last page) for a given document.
    /// Useful for displaying "pages X–Y" alongside a matched document.
    func pageRange(forDocument documentId: String, inVolume volumeId: String) async throws -> (first: Int, last: Int)?
}
```

---

## Matching Strategy — Priority Order

The engine works through strategies in this order, stopping at the first result with confidence ≥ `.high` or returning the full ranked list if multiple strategies contribute:

| Priority | Strategy | Condition | Confidence label |
|---|---|---|---|
| 1 | Exact document number (post-1955–57) | Vol resolved, doc number found, post-modern era | "Exact match" |
| 2 | Page range match | Vol resolved, page number provided, page data exists | "Matched by page number" |
| 3 | Superimposed document number (pre-1955–57) | Vol resolved, doc number found, pre-modern era | "Match — document number assigned digitally" |
| 4 | Fuzzy document number | Doc number not found; nearest ±N docs surfaced | "Possible match — document [N] not found; nearest is [M]" |
| 5 | Title fragment volume disambiguation | Vol number ambiguous; title text narrows candidates | "Matched via volume title; verify volume is correct" |
| 6 | Manifest only (volume not downloaded) | Vol identified but not in local corpus | "Volume identified — download to find specific document" |
| 7 | Best guess | Multiple corrections applied | "Best guess — [plain-language explanation]" |

---

## Confidence Labels — Examples

These are the explicit labels displayed alongside each result:

- **"Exact match"** — document number found directly in the resolved volume
- **"Matched by page number"** — page 47 falls within this document (pages 44–51)
- **"Match — document number assigned digitally"** — this pre-1955–57 volume uses document numbers assigned during digitization, not from the original print publication
- **"Possible match — document 150 not found in this volume (last document is 142); nearest is document 142"**
- **"Possible match — volume number 'II' is ambiguous for this subseries; two volumes match"**
- **"Volume identified — this volume is not downloaded. Download to locate the specific document."**
- **"Best guess — page number 847 exceeds this volume's range (pages 1–612); citation may refer to a different volume in this subseries"**

---

## Microfiche Supplement Handling

Microfiche supplements are identified by their volumeId patterns (to be confirmed against the actual corpus during development). For these volumes:
- Document number matching works normally
- Page range lookup is skipped (no continuous paginated text; `<pb>` elements absent or not meaningful)
- The confidence label notes the microfiche nature where relevant

---

## UI Layout

```
Citation Lookup
┌─────────────────────────────────────────┐
│  [Paste Citation] [Structured Entry]    │  ← segmented control
├─────────────────────────────────────────┤
│  Paste a FRUS citation:                 │
│  ┌───────────────────────────────────┐  │
│  │ Foreign Relations of the United   │  │
│  │ States, 1969–1976, Volume I...    │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Parsed fields (editable):             │
│  Subseries:  [1969–76          ]       │
│  Volume:     [I                ]       │
│  Document:   [15               ]       │
│  Page:       [                 ]       │
│                                         │
│  [Look Up]                              │
├─────────────────────────────────────────┤
│  Results (2 found)                      │
│                                         │
│  ① Exact match                          │
│  [standard SearchResult view]           │
│                                         │
│  ② Matched by page number               │
│  [standard SearchResult view]           │
└─────────────────────────────────────────┘
```

- Parsed fields update in real time as the user types or pastes
- Fields are individually editable so users can correct parser errors
- The "Look Up" button activates once at least one of (document number, page number, or volume + subseries) is populated
- Results use the identical `SearchResultView` component from Session 16
- Each result is preceded by its explicit confidence label in a distinct style (e.g., small label above the result card)
- Correction notes appear below the result card in a muted style
- "Download" button replaces the navigation action for `requiresDownload == true` results

---

## Tasks

1. **`<pb>` AST node** — confirm Session 07 has surfaced `pageBreak` with normalized `PageNumber`; add if missing (small addition, can be done at start of this session if needed)

2. **Page range table** — confirm Session 09 has built `page_ranges` table; add population logic if missing (indexing pass addition, same pattern as cross-reference table)

3. **`CitationParser`** — implement multi-pattern pipeline:
   - Pattern set covering all citation format variants listed above
   - Real-time field extraction as user types (debounced, async)
   - Preserve unmatched text as `titleFragment` candidate
   - Normalize volume numbers (Roman numeral ↔ integer; handle "vol.", "v.", bare numeral)
   - Normalize subseries year ranges (handle en dash, hyphen, space variants: "1969-76", "1969–76", "1969–1976")

4. **`PageRangeStore`** — implement document lookup by page number with section-aware span computation

5. **`CitationMatchingEngine`** — implement all seven matching strategies in priority order:
   - Volume resolution (subseries + volume number + optional title fragment → `[VolumeManifestEntry]`)
   - Pre/post-1955–57 era detection from volumeId/subseries
   - Microfiche supplement detection
   - Fuzzy document number (query FTS5 index for documents near the requested number)
   - Two-stage undownloaded volume behavior
   - Best-guess recovery with plain-language explanation generation

6. **`CitationLookupView`** — implement the full UI:
   - Segmented control for Paste / Structured Entry modes
   - Paste text field with real-time parser feedback populating structured fields
   - Editable structured fields
   - Results list using `SearchResultView` from Session 16
   - Explicit confidence label above each result
   - Correction note below result card where applicable
   - Download action for undownloaded volume results; re-run match on completion
   - Empty state (no match found, with explanation)
   - Error state (input too ambiguous to attempt match)

7. **Navigation integration**:
   - Add Citation Lookup to main navigation (tab bar / sidebar)
   - Add "Find by Citation" link in Search view
   - Add "Look Up Citation" option in Document view toolbar (pre-populates with a citation to the current document for researchers who want to verify how it would be cited)

8. **OpenAPI update** — add to `FRUS-API.openapi.yaml`:
   ```yaml
   /citation-lookup:
     get:
       summary: Resolve a FRUS citation to matching documents
       description: >
         Accepts citation fields and returns ranked CitationMatch results.
         In the current app, this is implemented entirely client-side using
         the local FTS5 index and page_ranges SQLite table. A future FRUS API
         could serve this endpoint to enable citation resolution without
         downloading volumes.
   /volumes/{volumeId}/page-ranges:
     get:
       summary: Page number to document mappings for a volume
   ```

## Tests

### `CitationParserTests`
- **FullCitationTest**: Parse the history.state.gov recommended style string; verify all fields extracted correctly
- **ChicagoShortTest**: Parse "FRUS, 1969–76, I, doc. 15"; verify subseries, volume, document number
- **ChicagoFullTest**: Parse Chicago full footnote with page number; verify page extracted alongside doc number
- **PageOnlyTest**: Parse citation with page but no document number; verify page extracted, doc number nil
- **InformalTest**: Parse "FRUS 1969-76, vol. 1, no. 15" (hyphen, Arabic numeral, "no." abbreviation); verify correct extraction
- **HyphenVariantTest**: "1969-76" (hyphen) and "1969–76" (en dash) and "1969–1976" (full year) all extract same subseries
- **VolumeNormalizationTest**: "vol. I", "v. I", "vol. 1", "Volume I" all extract same volume identifier
- **MalformedTest**: OCR-corrupted citation with missing comma and wrong spacing; verify graceful partial extraction
- **RealTimeTest**: Incrementally feed characters; verify parsed fields update correctly at each step

### `PageRangeStoreTests`
- **DocumentLookupTest**: Insert fixture page_ranges; query page in middle of a document's range; verify correct documentId
- **BoundaryTest**: Query first and last page of a document's range; verify correct result
- **GapTest**: Query a page number between two documents (should not occur in well-formed data); verify graceful nil
- **PaginationRestartTest**: Two sections with overlapping page numbers; verify section_id correctly disambiguates
- **MissingVolumeTest**: Query page range for volume with no page_ranges data; verify nil (not error)
- **PageRangeForDocumentTest**: Query page range for known document; verify correct (first, last) tuple

### `CitationMatchingEngineTests`
- **ExactMatchTest**: Post-1955–57 volume; correct subseries + volume + doc number → exact match, rank 1
- **PageRangeMatchTest**: Correct subseries + volume + page number → document containing that page
- **SuperimposedMatchTest**: Pre-1955–57 volume; doc number match → result labeled "assigned digitally"
- **FuzzyDocumentTest**: Doc number 150 in volume with max doc 142 → fuzzy match to 142 with correction note
- **TitleFragmentTest**: Ambiguous volume number disambiguated by title fragment → correct volume resolved
- **UndownloadedVolumeTest**: Citation resolves to volume not in corpus → `requiresDownload == true`, manifest entry populated
- **DownloadThenResolveTest**: Mock download completion; re-run match → full document-level result returned
- **MicroficheTest**: Citation to known microfiche supplement → doc number match works; page range skipped
- **NoMatchTest**: Completely unresolvable citation → empty results with explanation, no crash
- **PreModernPagePrimaryTest**: Pre-1955–57 volume citation with page number → page range is rank-1 result; doc number match (if also provided) is rank-2 or lower

### `CitationLookupViewTests`
- **ParseFeedbackTest**: Paste known citation string; verify structured fields populated correctly in UI
- **FieldEditTest**: Edit a parsed field; verify matching engine re-run with corrected input
- **ConfidenceLabelTest**: Exact match result displays "Exact match" label
- **CorrectionNoteTest**: Fuzzy match result displays correction note below card
- **DownloadActionTest**: Undownloaded volume result displays Download button; tapping initiates download
- **NavigationTest**: Tap a result → Document view for that document

## Development Plan Update
Session 30 precedes Final Integration Testing (Session 31). It depends on Sessions 07, 09, 12, and 16. The `<pb>` AST node (Session 07 addition) and `page_ranges` table (Session 09 addition) should be implemented in those sessions as flagged; if they were not, this session begins by adding them before proceeding.

## Coding Standards Checklist
- [ ] `CitationParser` documented: all format patterns listed with examples
- [ ] `CitationMatchingEngine` documented: strategy priority order and era detection logic explained
- [ ] `PageRangeStore` documented: section-aware span computation explained
- [ ] Confidence labels documented: full set of label strings defined as constants, not inline literals
- [ ] Microfiche detection logic documented with reference to volumeId patterns
- [ ] `[CitationParser]`, `[CitationMatcher]`, `[PageRangeStore]` log prefixes
- [ ] All strings (confidence labels, correction notes, UI text) localized
- [ ] `FRUS-API.openapi.yaml` updated with `/citation-lookup` and `/volumes/{volumeId}/page-ranges`
- [ ] Swift 6 strict concurrency: zero warnings
