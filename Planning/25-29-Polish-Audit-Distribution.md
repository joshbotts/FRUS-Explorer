# Session 25 — Global Context View

## Goal
Implement the global context view providing aggregated, explorable information about the user's activity across all projects.

## Prerequisites
- Sessions 15, 14, 22 complete

## Specification References
- Section 16: User Experience — Global Context View

## Tasks
1. Implement `GlobalContextViewModel` — aggregates reading history, research notes, and collections across all projects
2. Implement volumes and documents accessed/read summary: total counts, per-project breakdown, per-volume breakdown
3. Implement research notes browser: filterable by project tag, user tag, or both; list view with note preview and document link
4. Implement collections browser: filterable by project tag; list with collection details
5. Implement tapping any item → appropriate detail view (Document view, Research Note editor, Collection editor)
6. Implement "untagged" category for activity with no project tag

## Tests
- **AggregationTest**: Create activity across two projects and untagged; verify global view shows all
- **NotesBrowserFilterTest**: Notes with different project tags; filter by project A; verify only project A notes shown
- **CollectionsBrowserTest**: Collections with different project tags; verify all visible in global context

## Coding Standards Checklist
- [ ] All strings localized
- [ ] `[GlobalContext]` log prefix
- [ ] Accessibility: list items fully labeled
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 26 — About Screen & App Polish

## Goal
Implement the About screen and conduct a UI polish pass across all views.

## Prerequisites
- All prior sessions complete

## Specification References
- Section 16: User Experience — About Screen
- Section 17: App Identity & Distribution

## ⚠️ Placeholder (resolve before this session)
Attribution text for the About screen must be provided. See Specification Section 23, Placeholder #4.

## Tasks

### About Screen
1. Implement About screen with:
   - Attribution text (provided before session)
   - FRUS series description — bundled as a localized string (text below); displayed as readable prose above the links
   - Link to history.state.gov
   - Link to github.com/HistoryAtState
   - TEI Publisher Lib acknowledgement with Apache 2.0 license statement
   - NARA Catalog API required disclaimers
2. Implement all links opening in the default browser

#### Bundled FRUS Series Description (About Screen)

The following text is the content of the `AboutFRUSDescription` localized string key. It is original prose derived from history.state.gov/historicaldocuments/about-frus and does not need to be fetched at runtime.

> *Foreign Relations of the United States* (FRUS) is the official documentary record of U.S. foreign policy, published by the Department of State continuously since 1861. Prepared by the Office of the Historian under a federal statute, the series is required to be a thorough, accurate, and reliable record of major U.S. foreign policy decisions. Historians draw on records from the White House, National Security Council, Departments of State and Defense, the CIA, and other agencies, as well as the private papers of individual policymakers, to document how decisions were made and what they aimed to achieve.
>
> The statute requires that editing be guided by historical objectivity: records may not be altered without acknowledgment, no fact of major importance in reaching a decision may be omitted, and nothing may be omitted to conceal a defect in policy. Volumes must be published within 30 years of the events they document.
>
> FRUS covers U.S. bilateral and regional relations across the globe, as well as global issues — terrorism, narcotics, health, the environment — and topics including national security policy, foreign economic policy, and foreign policy organization. It is an essential resource for scholars, policymakers, and citizens seeking to understand the origins of contemporary challenges and the United States' role in the world.

This text should be reviewed and approved by OH staff before the session begins if any adjustments to phrasing are desired.

### UI Polish Pass
3. Review all views for consistent typography, spacing, and color usage
4. Review all empty states (no volumes, no results, no notes, no collections)
5. Review all loading states (indexing in progress, download in progress, summarization in progress)
6. Review all error states (network error, API error, schema validation error)
7. Verify platform-adaptive layouts on all three platforms (macOS, iPadOS, iPhone)
8. Verify Dynamic Type scaling on all text throughout the app

## Tests
- **AboutScreenLinksTest**: Verify all About screen URLs are well-formed
- **EmptyStateTest**: Verify each major view has an appropriate empty state (no crash, meaningful message)
- **DynamicTypeTest**: Verify key views render without clipping at largest Dynamic Type sizes

## Coding Standards Checklist
- [ ] All strings localized
- [ ] Attribution placeholder confirmed resolved
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 27 — Accessibility Audit & Fixes

## Goal
Conduct a comprehensive accessibility audit across the entire application and implement any required fixes.

## Prerequisites
- All prior sessions complete

## Specification References
- Section 18: Accessibility

## ⚠️ Open Questions (must be resolved before this session)
All six accessibility open questions from Specification Section 18 must be answered:
1. VoiceOver label pattern for tag chips and graph nodes
2. Document view VoiceOver reading order preference
3. Cross-reference graph VoiceOver alternative representation
4. Additional Reduce Motion animation surfaces
5. Non-color indicator for curated vs. string-match tags
6. macOS tap target policy for mouse-driven surfaces

## Audit Areas

### VoiceOver
- All interactive elements have meaningful labels, hints, and traits
- Reading order is logical throughout all views
- Custom Canvas views (cross-reference graph) have accessibility element overlays
- Tag chips labeled per resolved open question #1
- Document view reading order per resolved open question #2
- Cross-reference graph alternative representation per resolved open question #3

### Dynamic Type
- All text scales correctly at all Dynamic Type sizes including accessibility sizes
- No text clipping, truncation, or overlap at large sizes
- All touch targets remain usable at large sizes

### Reduce Motion
- Cross-reference graph settling animation disabled when Reduce Motion is on
- All other animations identified in resolved open question #4 reviewed and handled

### Color Independence
- Curated vs. string-match subject tags distinguished by non-color indicator per resolved open question #5
- No other information conveyed by color alone

### Tap Targets
- All iPadOS/iOS interactive elements meet 44×44pt minimum
- macOS targets reviewed per resolved open question #6

### Contrast
- All text meets WCAG AA contrast ratio requirements (4.5:1 for normal text, 3:1 for large text)

## Tests
- **VoiceOverLabelTest**: Automated check that all interactive elements have non-empty accessibility labels
- **TapTargetTest**: Automated check that all interactive elements on iOS/iPadOS are ≥44×44pt
- **ColorIndependenceTest**: Verify curated and string-match tags differ by more than color (label or icon present)
- **ReduceMotionTest**: Mock Reduce Motion enabled; verify no animations fire in graph view or any other identified surface

## Coding Standards Checklist
- [ ] All accessibility fixes documented in code with rationale
- [ ] Open questions confirmed resolved
- [ ] Swift 6 strict concurrency: zero warnings

---

# Session 28 — OpenAPI Document Review & Finalization

## Goal
Review and finalize `FRUS-API.openapi.yaml` as a complete, well-documented draft specification for the future FRUS API.

## Prerequisites
- All prior sessions complete (all GitHub API calls and local volume data access points have been identified)

## Specification References
- Section 21: OpenAPI / Future FRUS API

## Tasks
1. Review all endpoints added across sessions 02–24; verify completeness and consistency
2. Add missing endpoints identified during review
3. Write complete request/response schemas for all endpoints using the `components/schemas` section
4. Add authentication documentation (how a future FRUS API might handle auth)
5. Add rate limiting documentation
6. Add pagination documentation for list endpoints
7. Add error response schemas (400, 404, 500)
8. Write an introduction section explaining the document's purpose and relationship to the current app implementation
9. Validate the OpenAPI document using an OpenAPI validator tool

### Endpoints Expected at This Point
- `GET /volumes` — full manifest
- `GET /volumes/{volumeId}` — single volume metadata
- `GET /volumes/{volumeId}/download` — volume XML download
- `GET /volumes/{volumeId}/documents` — document list
- `GET /volumes/{volumeId}/documents/{documentId}` — single document
- `GET /subjects` — full subject taxonomy
- `GET /subjects/appearances/{volumeId}` — document-subject mappings
- `GET /search` — full-text search
- Any additional endpoints identified during development

## Tests
- **OpenAPIValidationTest**: Run the OpenAPI document through a validator; verify zero errors

## Coding Standards Checklist
- [ ] All endpoints documented with descriptions explaining current app implementation vs. future API intent
- [ ] All schemas complete (no `{}` placeholder schemas)
- [ ] OpenAPI 3.1 compliant

---

# Session 29 — Direct Distribution Build & Notarization

## Goal
Configure and validate the direct distribution (Developer ID) macOS build, including Sparkle update framework integration, notarization workflow, and distribution packaging.

## Prerequisites
- All prior sessions complete

## Specification References
- Section 17: App Identity & Distribution

## Tasks
1. Verify DirectDistribution build configuration produces a valid signed binary using Developer ID Application certificate
2. Configure Sparkle:
   - Add Sparkle SPM dependency (already in Package.swift from Session 01; confirm linked only to DirectDistribution target)
   - Generate Sparkle EdDSA signing keys
   - Configure `SUFeedURL` in DirectDistribution Info.plist pointing to an update appcast URL (document the required appcast format)
   - Implement minimal Sparkle update check in the DirectDistribution build (standard Sparkle integration)
3. Create a notarization shell script that:
   - Archives the DirectDistribution build
   - Submits to Apple notarization via `notarytool`
   - Staples the notarization ticket
   - Produces a distributable `.dmg`
4. Document the complete release workflow for both App Store and direct distribution builds
5. Verify both macOS builds maintain identical sandbox posture (entitlements diff check)

## Tests
- **SandboxParityTest**: Compare entitlements of AppStore and DirectDistribution builds; verify sandbox settings are identical; verify only expected differences exist (App Store vs. Developer ID specific keys)
- **SparkleIntegrationTest**: Verify Sparkle is only linked in DirectDistribution build; verify update check compiles without error
- **NotarizationWorkflowTest**: Dry-run the notarization script in a CI-like environment; verify all steps execute without error (actual notarization requires Apple credentials; document this requirement)

## Coding Standards Checklist
- [ ] Release workflow documented in README
- [ ] Sparkle configuration documented
- [ ] Notarization script documented with required credentials and environment variables
- [ ] AppStore build verified unaffected by Sparkle changes

---
