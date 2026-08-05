# Session 02 — Manifest Generator Tool
**Updated**: 2026-05-14 — Removed abstract/abstractSource; added volume-level tag extraction and taxonomy generator

## Goal
Build two tools:
1. `ManifestGenerator` — SPM executable that generates the bundled `manifest.json` by parsing `<teiHeader>` elements from FRUS volume XML files in the HistoryAtState GitHub repository
2. `TaxonomyGenerator` — a simpler tool that fetches and parses the volume tag taxonomy from history.state.gov/tags/all, producing `volume-tag-taxonomy.json`

`ManifestGenerator` is run before each app release. `TaxonomyGenerator` is run manually when the taxonomy changes. Both outputs are committed to the app repository.

## Prerequisites
- Session 01 complete
- Network access to the GitHub API, HistoryAtState raw content URLs, and history.state.gov

## Specification References
- Spec Update: SPEC-UPDATE-Manifest-Tags.md (supersedes original Section 6)
- Section 21: OpenAPI / Future FRUS API
- Section 22: Coding Standards

## Inputs
- GitHub API: volume directory listing (filenames, sizes, SHAs)
- GitHub raw content: `<teiHeader>` of each volume XML
- history.state.gov/tags/all: full tag taxonomy HTML

## Outputs
- `ManifestGenerator` SPM executable target
- `TaxonomyGenerator` SPM executable target
- `manifest.json` — generated, committed to `Sources/FRUSExplorer/Resources/`
- `volume-tag-taxonomy.json` — generated, committed to `Sources/FRUSExplorer/Resources/`
- Updated `FRUS-API.openapi.yaml`

## Key Types

### `VolumeManifestEntry`
```swift
/// Represents the rich metadata for a single FRUS volume in the bundled manifest.
/// Generated from the volume's TEI header at release time.
///
/// The `tags` field contains volume-level subject tag slugs extracted from:
///   /TEI/teiHeader/profileDesc/textClass/keywords[@scheme="https://history.state.gov/tags"]/term
/// These are authoritative OH-curated tags embedded in published TEI.
/// Slugs resolve against volume-tag-taxonomy.json for display names and hierarchy.
///
/// Note: this type carries no abstract or abstractSource field. Volumes are
/// presented to users as a browsable, sortable list filtered by tag or subseries.
///
/// Version history:
///   1.0 — Session 02: initial implementation
struct VolumeManifestEntry: Codable, Sendable {
    let volumeId: String
    let filename: String
    let subseries: String
    let title: String
    let dateRange: DateRange
    let publicationDate: String?    // ISO 8601; nil if absent from header
    let status: VolumeStatus        // .published | .partiallyPublished | .planned
    let editors: [String]
    let generalEditor: String?
    let documentCount: Int
    let sizeBytes: Int
    let tags: [String]              // volume-level tag slugs; [] if none (not an error)
}

enum VolumeStatus: String, Codable, Sendable {
    case published
    case partiallyPublished
    case planned
}

struct DateRange: Codable, Sendable {
    let earliest: String?   // ISO 8601
    let latest: String?     // ISO 8601
}
```

### `GitHubVolumeEntry`
```swift
/// File metadata returned by the GitHub API for a single volume file.
/// Entries with size < 20,000 bytes are excluded from all download functionality.
struct GitHubVolumeEntry: Codable, Sendable {
    let name: String
    let size: Int
    let sha: String
    let downloadUrl: String
}
```

### `VolumeLevelTag` (main app target)
```swift
/// A volume-level subject tag resolved from its slug against the bundled taxonomy.
/// Sourced from published TEI headers curated by OH staff — authoritative.
///
/// Distinct from SubjectTag (document-level, experimental pipeline):
///   - VolumeLevelTag: per-volume, authoritative, no confidence distinction
///   - SubjectTag: per-document, experimental, confidence .curated | .stringMatch
///
/// Version history:
///   1.0 — Session 02: initial implementation
struct VolumeLevelTag: Identifiable, Sendable {
    let slug: String
    let displayName: String    // e.g. "Kissinger, Henry A.", "Iran", "Arms Control and Disarmament"
    let category: TagCategory  // .people | .places | .topics
    let subcategory: String    // e.g. "secretaries-of-state", "near-east", "arms-control-and-disarmament"
    let parentSlug: String?
    let description: String?
    var id: String { slug }
}

enum TagCategory: String, Codable, Sendable {
    case people
    case places
    case topics
}
```

### `TagTaxonomyEntry` (decoded from `volume-tag-taxonomy.json`)
```swift
/// Single entry in the bundled volume-tag-taxonomy.json.
/// Decoded at app launch by VolumeLevelTagStore.
struct TagTaxonomyEntry: Codable, Sendable {
    let slug: String
    let displayName: String
    let category: String
    let subcategory: String
    let parentSlug: String?
    let description: String?
}
```

## ManifestGenerator Tasks

1. **GitHub API client** — async function fetching the volume directory listing from the GitHub API; filter entries where `size < 20_000`

2. **Volume ID and subseries parser** — `parseVolumeId(from filename: String) -> (volumeId: String, subseries: String)?`
   Document all observed filename patterns and their parsing rules clearly for contributors.

3. **TEI header fetcher** — async fetch of raw volume XML in streaming mode; stop parsing after `</teiHeader>` to avoid loading the full document into memory

4. **TEI header parser** — extract:
   - Title (`<titleStmt>/<title>`)
   - Editors (`<titleStmt>/<editor>` elements, excluding general editor)
   - General editor (`<titleStmt>/<editor role="general">`)
   - Publication date (`<publicationStmt>/<date>`)
   - Date range from `<profileDesc>`
   - Document count (from header metadata if available; note as approximation if heuristic)
   - Status indicators

5. **Volume-level tag extraction** — extract all `<term>` children from:
   ```xml
   <keywords scheme="https://history.state.gov/tags">
   ```
   Store as `[String]` slugs. Return `[]` if the element is absent — this is valid for volumes predating the tagging system, not an error.
   
   Do not extract terms from `keywords` elements with other scheme values (administration, priority, media type use different schemes).

6. **Concurrent fetching** — `TaskGroup` with concurrency limit of 8; `[ManifestGenerator]` prefix on all console output

7. **Output writer** — serialize `[VolumeManifestEntry]` to `Sources/FRUSExplorer/Resources/manifest.json`; pretty-printed for readability and diff-friendliness

8. **Summary report** — total volumes processed, count with tags, count without tags, count skipped (< 20kb), errors encountered

9. **OpenAPI update** — update `GET /volumes` in `FRUS-API.openapi.yaml`:
   - Remove `abstract` and `abstractSource` from response schema
   - Add `tags` field: `{ type: array, items: { type: string }, description: "Volume-level subject tag slugs from TEI teiHeader" }`

## TaxonomyGenerator Tasks

1. **Fetch** history.state.gov/tags/all HTML

2. **Parse taxonomy hierarchy** — three-level structure:
   - **Level 1** (category): People, Places, Topics
   - **Level 2** (subcategory): Presidents, Secretaries of State; regional groupings (Sub-Saharan Africa, East Asia and Pacific, Europe, Near East, South and Central Asia, Western Hemisphere, Dependencies, Other); topic categories (Arms Control, Dept of State, Foreign Economic Policy, Global Issues, Human Rights, Information Programs, International Law, International Organizations, Politico-Military, Science and Technology, Warfare)
   - **Level 3** (individual tag): slug from URL path, display name from link text, optional description from adjacent text

   Slug is the URL path segment: `/tags/kissinger-henry-a` → `kissinger-henry-a`

3. **Output writer** — serialize to `Sources/FRUSExplorer/Resources/volume-tag-taxonomy.json`

4. **README update** — document when and how to re-run `TaxonomyGenerator`; recommend reviewing the JSON diff before committing to catch unexpected taxonomy changes

## Tests

### `ManifestGeneratorTests`
- **FilenameParserTest**: Fixture filenames for all observed subseries patterns; verify volumeId and subseries extraction
- **SizeFilterTest**: Entries < 20,000 bytes excluded; entries ≥ 20,000 included
- **TEIHeaderParserTest**: Fixture XML headers — with full fields, with partial fields, with no publication date
- **TagExtractionTest**: Fixture header with known `<term>` elements under `scheme="https://history.state.gov/tags"`; verify correct slug array
- **EmptyTagsTest**: Header with no matching `keywords` element; verify `[]` returned, no error
- **WrongSchemeTest**: Header with `keywords` under a different scheme attribute; verify those terms excluded
- **MultipleKeywordsTest**: Header with multiple `keywords` elements (administration, priority, media type, tags); verify only the tags scheme extracted
- **OutputFormatTest**: Generated JSON decodes cleanly into `[VolumeManifestEntry]`

### `TaxonomyGeneratorTests`
- **HierarchyParseTest**: Fixture HTML; verify People/Places/Topics top-level extracted with correct subcategories
- **SlugExtractionTest**: Known tag links; verify slug correctly derived from URL path
- **DescriptionExtractionTest**: Tags with descriptions in fixture HTML; verify descriptions captured
- **OutputFormatTest**: Generated JSON decodes cleanly into `[TagTaxonomyEntry]`

### App-Side Tests (`FRUSExplorerTests`)
- **BundledManifestLoadTest**: App loads and decodes `manifest.json` from bundle at startup
- **BundledTaxonomyLoadTest**: App loads and decodes `volume-tag-taxonomy.json` from bundle at startup
- **LiveManifestDiffTest**: Fixture data covering all three diff cases (both manifests, live-only, bundled-only)
- **SlugResolutionTest**: Known slug from a manifest entry resolves to correct displayName, category, subcategory via taxonomy
- **UnknownSlugGraceTest**: Slug present in manifest but absent from taxonomy returns nil gracefully (tags may occasionally predate taxonomy additions)

## Coding Standards Checklist
- [ ] `VolumeManifestEntry` documented: tag XPath noted, empty array explained as valid
- [ ] `VolumeLevelTag` documented: distinction from `SubjectTag` explicitly called out
- [ ] `[ManifestGenerator]` and `[TaxonomyGenerator]` log prefixes
- [ ] README updated with taxonomy update procedure
- [ ] `FRUS-API.openapi.yaml` updated: abstract/abstractSource removed; tags field added
- [ ] Swift 6 strict concurrency: zero warnings
- [ ] No hardcoded UI strings (CLI tools; note localization not applicable)
