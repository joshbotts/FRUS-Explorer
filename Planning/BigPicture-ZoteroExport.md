// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

# Zotero Export

**Status:** Planning  
**Priority:** Medium (near-term backlog)  
**Estimated effort:** 1–3 sessions (depends on scope chosen)

---

## Problem Statement

Researchers who use FRUS Explorer alongside Zotero (the dominant reference manager in academic history) have no direct path from FRUS Explorer → Zotero. They must manually re-enter citations or copy-paste from "Copy BibTeX" into Zotero's BibTeX importer — a friction-filled multi-step process that defeats the app's core value proposition of making FRUS research faster.

---

## Three Implementation Options (in ascending complexity)

### Option A — BibTeX Share Sheet (0.5 sessions) ← Recommended first step

**What it does:** Adds a "Send to Zotero…" share-sheet item to the citation popover (and collection export) that produces a `.bib` file and opens the iOS/macOS share sheet. The user drags it into Zotero or uses AirDrop to a Mac running Zotero.

**Why:** `.bib` import is already implemented. Adding a `ShareLink(item: bibtexString, subject: "FRUS Citation")` with a `transferRepresentation(contentType: .bib)` wrapper is 20–30 lines.

**Limitation:** Requires manual drag into Zotero. One extra step for the user.

**Tasks:**
- Define `UTType.bibtex` (if not already in `UTType+FRUS.swift`)
- In `CitationPopoverView`, add "Send to Zotero (BibTeX)…" to the Export menu as a `ShareLink` with `contentType: .bibtex`
- On macOS, present an NSSavePanel with `.bib` default extension and a "Open in Zotero" button that calls `NSWorkspace.open(_:withApplicationAt:)` pointing at the Zotero app bundle if installed
- On iOS, the system share sheet handles Zotero if it's installed (Zotero for iOS accepts `.bib` via the Files app provider)

---

### Option B — Zotero Connector-Compatible JSON (1 session)

**What it does:** Exports a Zotero-format JSON file (Zotero's `.json` exchange format, used by the Connector browser extension) that Zotero can import directly via File → Import.

**Why Zotero JSON over BibTeX:** Zotero's internal JSON format carries richer metadata (item type, tags, related items, notes) that maps naturally to FRUS Explorer's data model (user tags, research notes, collection membership). A BibTeX export loses this metadata.

**Zotero item format for a FRUS document:**
```json
{
  "itemType": "bookSection",
  "title": "Document 217: Memorandum From Secretary of State Rusk to President Kennedy",
  "bookTitle": "Foreign Relations of the United States, 1961–1963, Volume XIII, West Europe and Canada",
  "date": "1961-04-03",
  "publisher": "Government Printing Office",
  "place": "Washington, D.C.",
  "volume": "XIII",
  "pages": "",
  "url": "https://history.state.gov/historicaldocuments/frus1961-63v13/d217",
  "accessDate": "2026-06-08",
  "tags": [{ "tag": "NATO" }, { "tag": "my-user-tag" }],
  "notes": [{ "note": "My research note content here" }]
}
```

**Tasks:**
- Implement `ZoteroJSONExporter` conforming to `CollectionExporter`
- Map `CollectionEntry` → Zotero JSON item type:
  - Regular FRUS document → `"bookSection"`
  - Editorial note → `"bookSection"` with `"extra": "Editorial note"`
- Include `userTagIds` resolved to tag names as Zotero tags
- Include `ResearchNote` content as Zotero notes (HTML body)
- Export a `.json` array; wrap in the Zotero exchange envelope:
  ```json
  { "version": 5, "items": [ ... ] }
  ```
- Add "Export to Zotero (JSON)…" to Collection editor's share menu
- Add "Send to Zotero…" to `CitationPopoverView` Export menu for single-document export

---

### Option C — Zotero Web API Direct Import (2–3 sessions)

**What it does:** Authenticates with the Zotero Web API (OAuth 1.0a) and POSTs items directly to the user's Zotero library, eliminating any manual import step.

**Why:** The "save to Zotero" one-tap flow that researchers expect (equivalent to the Zotero browser connector's "Save to Zotero" button).

**Zotero API endpoints used:**
- `GET /users/{userId}/collections` — list user's Zotero collections
- `POST /users/{userId}/items` — create items (batch, max 50 per request)
- `POST /users/{userId}/collections/{collectionKey}/items` — add items to a collection

**Tasks:**
- OAuth 1.0a: implement token request / authorization / access-token exchange (Zotero uses a custom OAuth 1.0a flow, not OAuth 2.0)
  - Authorization URL: `https://www.zotero.org/oauth/authorize`
  - Request token: `https://www.zotero.org/oauth/request`
  - Access token: `https://www.zotero.org/oauth/access`
  - Use `ASWebAuthenticationSession` for the in-app web auth flow
- Keychain storage for access token and userId
- `ZoteroAPIClient` actor wrapping `URLSession`:
  - `createItems([ZoteroItem]) async throws -> ZoteroWriteResponse`
  - `fetchCollections() async throws -> [ZoteroCollection]`
- Add "Save to Zotero Library…" to Collection editor and CitationPopoverView
  - Let user pick destination Zotero collection (or "My Library")
  - Show progress indicator for large collection exports (rate-limited to 6 req/s)
- SwiftData model for Zotero account settings (`ZoteroAccount`: userId, username, accessToken)

**API key:** Requires a Zotero API key registered at zotero.org. The app should link users to the key creation page on first use (`https://www.zotero.org/settings/keys/new`).

---

## Recommended Implementation Order

1. **Option A first** — ship `.bib` share quickly (already 90% built); satisfies most power users
2. **Option B second** — adds richer Zotero JSON with notes and tags; significant quality improvement
3. **Option C later** — post-1.0; high complexity (OAuth), high reward (one-tap save)

---

## Citation Mapping Reference

| FRUS Explorer field | Zotero field |
|---|---|
| `entry.header` | `title` (document title) |
| `vol.title` | `bookTitle` (volume title) |
| `vol.editors` | `editor` array |
| `vol.publicationDate` | `date` (publication year) |
| `entry.documentNumber` | included in `title` as "Document N" |
| `canonicalURL` | `url` |
| `UserTag.name` | `tags[].tag` |
| `ResearchNote.body` | `notes[].note` (HTML) |
| Dateline date | `extra: "Document date: YYYY-MM-DD"` |

**Item type mapping:**
- FRUS document → `bookSection`  
- FRUS volume (whole-volume citation) → `book`  
- Editorial note → `bookSection` + `extra: "Editorial note"`

---

## Testing Criteria

### Option A
- [ ] "Send to Zotero (BibTeX)…" appears in Citation popover Export menu
- [ ] Sharing the item produces a valid `.bib` file
- [ ] Importing the `.bib` file into Zotero Desktop creates a correctly populated item

### Option B (in addition to A)
- [ ] Collection export to Zotero JSON produces valid Zotero exchange format
- [ ] User tags appear as Zotero tags
- [ ] Research notes appear as Zotero notes
- [ ] Zotero Desktop File → Import correctly ingests the JSON

### Option C (in addition to A + B)
- [ ] OAuth flow opens `ASWebAuthenticationSession` and completes without error
- [ ] Access token is stored in Keychain, persists across app restarts
- [ ] "Save to Zotero Library" creates items in the user's Zotero library
- [ ] Large collections (>50 items) are split into batches respecting Zotero's rate limit
- [ ] Disconnect/re-authenticate flow in Settings → Integrations

---

## Open Questions

1. Should Zotero export live in Settings → Integrations (next to potential future Obsidian/Notion integrations) or in the Collections editor only?
2. For Option C: should single-document "Save to Zotero" be available from the document toolbar (not just the citation popover)?
3. Does the Zotero API need a registered OAuth application, or can users supply their own API keys? (Zotero's API supports both; a registered app gives a better UX.)
