// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

# Zotero Integration

**Status:** Strategy decided 2026-06-26 after on-device testing + reading `zotero/zotero-ios`.
RIS-to-iOS does **not** work (see Finding); RIS desktop path fixed and rescoped. Web API
integration specced below (not yet built).
**Priority:** Medium (near-term backlog)
**Estimated effort:** Web API ~2–3 sessions; iOS web fallback ~0.5 session.

---

## Decided strategy — three tiers, both platforms

| Tier | Mechanism | Platforms | Annotations? | Status |
|---|---|---|---|---|
| **Primary** | **Zotero Web API v3** — POST items/notes/tags/collection directly to the user's library | iOS + macOS | **Yes** (notes + tags + collection) | Specced (this doc) |
| **Fallback A** | **RIS file → File → Import** | macOS desktop only | Yes (notes→`N1`, tags→`KW`, doc#→`M2`); collection flattens | **Done** (fixes below) |
| **Fallback B** | **Share `history.state.gov` URL → Zotero iOS share extension** (web translator) | iOS | **No** (annotations lost; one item) | Specced (this doc) |

The Web API is the only path that carries FRUS **annotations** into Zotero on **iOS**, so it is the
headline integration. The two fallbacks are for users who won't set up an API key.

---

## Finding: why RIS can't reach Zotero on iOS (verified)

From [zotero/zotero-ios](https://github.com/zotero/zotero-ios):
1. **`Zotero/Info.plist` declares no `CFBundleDocumentTypes`/UTI imports** → no "Open in Zotero"
   for `.ris`/`.bib`, and there is no File → Import on iOS (desktop-only).
2. The only ingestion path is the **ZShare share extension**, whose `NSExtensionActivationRule`
   accepts `com.adobe.pdf` / `public.url` / `public.file-url` / `public.text` and runs Zotero's
   **web-translator** pipeline (`ZShare/Assets/translation/*`) — there is **no RIS/citation-file
   parser**. A shared `.ris` makes Zotero appear in the sheet (it conforms to `public.text`/
   `public.file-url`) but produces nothing useful, which is exactly the "doesn't open in Zotero"
   symptom.

RIS desktop import **is** solid (verified against [zotero/translators `RIS.js`](https://github.com/zotero/translators/blob/master/RIS.js)):
`TY CHAP`→bookSection, `KW`→tags, `N1`→child notes, `M2`→Extra. So RIS stays as the macOS fallback.

### RIS fixes already applied (2026-06-26)
- **Doc number moved `N1` → `M2`** (`RISExporter`): for `bookSection`, `M1` maps to
  `numberOfVolumes` but `M2` maps unconditionally to **Extra**. Prevents a spurious note next to
  the researcher's own notes. `extra` is emitted as one `M2` per line (Zotero accumulates them).
- **User-facing copy corrected**: collection format relabelled "Zotero RIS (desktop)"; the
  document-citation share items relabelled "Share BibTeX/RIS file…" (were "Send to Zotero …" on
  iOS, which over-promised); onboarding copy now says RIS imports into Zotero *on the desktop via
  File → Import*; misleading "works on iOS / every platform" comments removed.

---

## Web API integration (primary)

### Authentication — API key (recommended) over OAuth

Use a **user-supplied API key**, not OAuth 1.0a. It's far simpler (no registered app, no
`ASWebAuthenticationSession`), works identically on iOS/macOS, and is the standard Zotero pattern.

- The user creates a key at `https://www.zotero.org/settings/keys/new` (deep-link prefilled:
  `?name=FRUS%20Explorer&library_access=1&notes_access=1&write_access=1`) and pastes **only the key**.
- We resolve the numeric **userID + username + permissions** automatically:
  `GET https://api.zotero.org/keys/<key>` → `{ "userID": 123, "username": "...", "access": { "user": { "library": true, "write": true, "notes": true } } }`.
  Validates write+notes access and removes the need to paste the userID.
- **Storage:** API key in the **Keychain** (not UserDefaults/SwiftData — it's a credential);
  userID/username in `AppStorage`. A `ZoteroAccount` is *not* a SwiftData/CloudKit model (don't
  sync a secret).

### Request shapes (Zotero Web API v3)

Common headers: `Zotero-API-Version: 3`, `Authorization: Bearer <key>`, `Content-Type: application/json`.
Base: `https://api.zotero.org/users/<userID>`.

**1. Create the destination collection** (mirror the FRUS collection name):
```
POST /collections
[ { "name": "FRUS — <collection name>", "parentCollection": false } ]
→ 200 { "successful": { "0": { "key": "ABCD1234", "version": 42, ... } }, "failed": {} }
```
(Or let the user pick an existing collection / "My Library" — then skip this.)

**2. Create the document items** (batch ≤ 50 per request):
```
POST /items
[ {
    "itemType": "bookSection",
    "title": "<header>",
    "bookTitle": "<volume title>",
    "creators": [ { "creatorType": "editor", "firstName": "Louis J.", "lastName": "Smith" } ],
    "publisher": "Government Printing Office",
    "place": "Washington, D.C.",
    "date": "1972",
    "url": "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
    "extra": "FRUS Document 1\nDocument date: 1972-02-15",
    "tags": [ { "tag": "NATO" }, { "tag": "my-user-tag" } ],
    "collections": [ "ABCD1234" ]
  }, … ]
→ 200 { "successful": { "0": { "key": "ITEMKEY1", ... }, … }, "failed": {} }
```

**3. Create research notes as child items** (after parents exist — `parentItem` must reference an
already-created key, so this is a second pass keyed by the success map):
```
POST /items
[ { "itemType": "note", "parentItem": "ITEMKEY1", "note": "<p>My research note…</p>" }, … ]
```

### Mapping (reuse the existing `ZoteroJSONExporter.Item` model)

| FRUS | Zotero API |
|---|---|
| `header` | `title` |
| volume `title` | `bookTitle` |
| volume `editors` | `creators[]` (`creatorType: "editor"`, split into first/last on last space; institutional → single `name`) |
| year | `date` |
| document number | appended to `extra` ("FRUS Document N") |
| canonical URL | `url` |
| `UserTag.name` | `tags[].tag` |
| `ResearchNote.body` (HTML) | child `note` item with `parentItem` |
| dateline / editorial flag | `extra` lines |
| FRUS collection | a Zotero collection (created or chosen); items carry its key in `collections[]` |

`ZoteroJSONExporter.Item` already produces almost all of this; the API client serialises it plus
the `collections` key, and splits notes into the child-item pass.

### Reliability

- **Idempotency:** send a unique `Zotero-Write-Token` (32-char hex) header per POST so a retried
  request doesn't double-create (server dedupes for ~12h). Essential because mobile networks drop.
- **Rate limits / backoff:** honor `Retry-After` on **429** and the advisory **`Backoff`** header —
  sleep the indicated seconds before the next request. Batches of 50 + a small inter-request delay.
- **Partial failure:** the response `failed` map names per-item errors; surface "N of M added,
  K failed" and offer retry of just the failures (re-using the same write token set).
- **Versioning:** capture `Last-Modified-Version`; not required for pure creation, but pass
  `If-Unmodified-Since-Version` if we later add update/sync.

### Components to build

- `ZoteroAPIClient` (actor over `URLSession`): `resolveAccount(key:)`, `createCollection(name:)`,
  `createItems([Item], collectionKey:)` (chunked ≤50, write-token, backoff), `createNotes([(parentKey, html)])`,
  returning a structured `ZoteroWriteResult { added, failed, collectionURL }`.
- `ZoteroAccountStore`: Keychain read/write for the key; `AppStorage` userID/username; `signOut()`.
- **Settings → Integrations → Zotero:** paste-key field, "Get an API key" deep link, Verify button
  (calls `resolveAccount`), connected-state row (username + "Disconnect").
- **Entry points:** Collection editor "Send to Zotero Library…" (destination picker: My Library /
  existing collection / new collection mirroring the FRUS name) and the document citation menu
  "Send to Zotero Library…". Progress UI for large collections; deep-link to the created collection
  in the Zotero app/web on success (`zotero://` or the web library URL).

---

## iOS lossy fallback — share `history.state.gov` URL to the share extension

For users without an API key, expose **"Send to Zotero (web)"** on iOS: a `ShareLink` of the
document's `history.state.gov` URL (`public.url`), which the Zotero share extension's web
translators ingest natively. Caveats to state in the UI: **one document at a time, no FRUS notes
or tags** (metadata is whatever Zotero extracts from the page; there may be no FRUS-specific
translator, so the record can be thin). This is a convenience affordance, not the annotation path.

*(Optional later: contribute a `history.state.gov` translator to `zotero/translators` so the
extracted record is rich. Out of scope here.)*

---

## Phasing

- **Phase 1 — RIS desktop hygiene. ✅ Done.** `M2` doc-number fix; honest copy; format rescoped to
  desktop.
- **Phase 2 — Web API (primary). 🟢 Built (2026-06-26), pending live verification.** Shipped:
  `ZoteroAccountStore` (Keychain key + UserDefaults userID/username), `ZoteroAPIModels` (encodable
  items/creators/notes with last-space name split; decodable write/key responses), `ZoteroAPIClient`
  actor (`resolveAccount`, `createCollection`, chunked `createItems` with write-token + 429/`Backoff`
  retry, child-note pass, `send()` orchestration), **Settings → Integrations → Zotero** (paste key →
  verify → connected/disconnect), **"Send to Zotero Library…" in the collection export sheet** (both
  platforms), and **document-level "Send to Zotero Library…"** in the iOS citation sheet (lands a
  single doc + its notes/tags in My Library). Unit-tested: creator split, item mapping/encoding, note
  htmlify, response decoding. **Remaining:** live end-to-end verification against a real API key (the
  network round-trip is untested — only request construction + response decoding are unit-covered);
  optional macOS document-level entry (macOS already has RIS→desktop). Personal library only.
- **Phase 3 — iOS web fallback.** "Send to Zotero (web)" URL share on iOS.
- **Phase 4 (optional).** Group libraries (`/groups/<id>`); pick-existing-collection browser;
  highlights → notes; a contributed history.state.gov translator.

---

## Testing criteria (Web API)

- [ ] Pasting a valid key resolves userID/username and shows "connected"; invalid key → clear error.
- [ ] Key is in Keychain, survives relaunch and is **not** synced to CloudKit.
- [ ] Collection export creates a Zotero collection + bookSection items with correct fields.
- [ ] User tags → Zotero tags; research notes → child notes under the right parent.
- [ ] >50 items split into batches; 429/`Backoff` respected (no request storm).
- [ ] Retried/duplicated request (same write token) does not double-create.
- [ ] Partial failure reports "N added / K failed" and retries only the failures.
- [ ] Items appear in the user's **iOS** Zotero app after sync (the whole point).

---

## Open decisions

1. **Creator name splitting** — FRUS editors are single strings ("Louis J. Smith"). Split on last
   space into first/last (recommended) vs. single-field `name`. Affects how Zotero alphabetises.
2. **Destination default** — always create a new collection mirroring the FRUS collection name
   (recommended) vs. default to "My Library" with optional collection pick.
3. **Document-level entry** — offer "Send to Zotero Library…" from the document toolbar too, or
   only from the citation menu / collection editor.
4. **Group libraries** — personal-only for v1 (recommended) or include group library selection.
5. **Highlights** — include user highlights as notes in v1, or notes+tags only (recommended v1).
