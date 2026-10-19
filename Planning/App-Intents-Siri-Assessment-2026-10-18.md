# App Intents and Siri, stage 1: an assessment on the shipped SDK, 2026-10-18

**What this is.** Plan-of-record item A6 (`Planning/Plan-Of-Record-2026-10-14.md` §1, decision 23, §5), based on `v2` at `d28093f9`. It settles the question `Planning/OS27-Semantic-Retrieval-Design.md` §3.3 left open: whether `IndexedEntity` adds to the app's Spotlight donation or replaces it. It also re-checks the declaration facts that design read on 2026-10-01, sizes A7's sketch, and says where A7 goes under decision 23.

**How.**
- **The SDK.** Read on Xcode 27.1 (27A9275): the iOS 27.1 and macOS 27.0 SDKs' `AppIntents` and `CoreSpotlight` interfaces, their headers, the documentation compiled into `AppIntents.swiftdoc`, and the toolchain's App Schema database (`AppIntentSchemas.sqlite`).
- **A throwaway spike, run on an iPhone 17 simulator under iOS 27.0 (24A434).** An app of its own, "Spike Reader" (`bottsywattsy.A6Spike`), donated fictional FRUS-shaped documents five ways and offered four intents. It was driven by launch arguments and by a UI-test target through Spotlight, Shortcuts and Siri. Its code is not committed; §2 records what it measured.
- **The owner's iPhone is not yet tried** (§4).

## 1. In brief

- **`IndexedEntity` is additive.** An app keeps donating its own `CSSearchableItem`s and attaches an entity to each with `associateAppEntity(_:priority:)` (iOS 18, macOS 15). The SDK's own documentation for `IndexedEntityQuery` names an entity associated with a `CSSearchableItem` as one of the two ways to donate one. Nothing in the old path is deprecated.
  - On the simulator, an associated item kept its identifier, its domain, its title and its text, and gained six attributes naming the entity.
  - Removing a volume by its domain still removed it.
  - An item donated plain gained the same six attributes from a later `isUpdate` item that carried the association and nothing else, and kept its text.
- **The replacing path exists, and A7 has no reason to take it.** `indexAppEntities(_:priority:)` builds its own items. They are keyed `<EntityType>/<id>` with the type name as their domain, so a volume's removal does not reach them, and the landing's `volumeId/documentId` split would misread them (§2.3).
- **The declaration facts hold.** `IndexedEntity` is `@available(macOS 15.0, iOS 18.0, visionOS 2.0, *)`, under the 26.0 target. `IndexedEntityQuery` is 27.0, and in the spike its conformance was gated with `@available(iOS 27.0, *)` while the target stayed 26.0, with no warning.
- **What the simulator showed of the intents.** Shortcuts and Spotlight ran them; Siri did not.
  - In the Shortcuts app, the four App Shortcuts were listed, and Summarize ran in the background through the on-device model in about 3 seconds.
  - In home-screen Spotlight, a document the entity query suggests appeared as a runnable Open or Summarize action, and a tap ran that intent.
  - Siri, driven through `XCUISiriService`, answered "Search Spike Reader" with a web search and never reached the app. So whether Siri surfaces an associated document is still open, and it is the owner's iPhone that settles it (§4).
- **Found on the way: the simulator's Spotlight never listed a donated item as such.** None of the five donation shapes appeared in home-screen Spotlight, today's shape included, even searched by full title. Every app result it showed was an App Shortcut. The privacy policy says the donation is "so that system search can find them"; that is to be seen on a device (§4, §6).
- **Found on the way: the donated items expire.** A new `CSSearchableItem` expires 31 days after it is made unless `expirationDate` is set, and the app sets none. Whether and when Spotlight purges an expired item is not measured: one given a 60-second expiry was still there 3 minutes later (§2.6, §6).
- **A7 needs no CloudKit change and no index version.** It adds no `@Model` and no stored property, and changes nothing indexing stores. Only the association would move the Spotlight shape stamp (`currentSpotlightSchemaVersion`, a defaults key, not an index version); the entity and the intents do not.
- **Where A7 goes: decision 23 put it in build 51**, because `IndexedEntity` is additive. One part of A7 would re-donate every library on upgrade: associating the entity with the items a library already holds. That part is separable, and its place would turn on the device check (§5).
- **The owner's decision, 2026-10-18 (decision 57): A7 is deferred past build 51.** Build 51 is cut without App Intents, and this memo stands as A7's plan (§5).

## 2. What the spike measured

The spike's five groups, two documents each, every one a fictional telegram or memorandum with a marker word of its own:

| Group | Marker | How it reached Spotlight |
|---|---|---|
| plain | Quillmere | Exactly as `IndexingPipeline.makeSearchableItem` donates today: `contentType: .text`, title, a 300-character description, keywords `[volumeId, documentId]`, a 3,200-character `textContent`, identifier `"\(volumeId)/\(documentId)"`, domain `volumeId` |
| associated | Varrowind | The same item, with `associateAppEntity(_:priority:)` called before donation |
| update later | Tessaloon | Donated plain; in a later launch, an `isUpdate` item carrying only the association |
| related identifier | Ombrevale | The same item, with 27.0's `relatedAppEntityIdentifier` set |
| indexed entity | Corvantis | No item of the app's own: `CSSearchableIndex.indexAppEntities(_:priority:)` |

The entity, `SpikeDocumentEntity`, was `FRUSDocumentEntity` as A7 would sketch it: `AppEntity, IndexedEntity`, keyed by `"\(volumeId)/\(documentId)"`, with a title property indexed under `\.title`, the volume as its subtitle, and an `attributeSet` carrying the app's own fields. Its query was an `EntityStringQuery`, with `IndexedEntityQuery` added in an `@available(iOS 27.0, *)` extension. The four intents were a classic `OpenIntent`, a `ShowInAppSearchResultsIntent`, a background summarize intent calling `FoundationModels`, and a background write standing in for Add to Collection. With them went the 27.0 schema intent `@AppIntent(schema: .system.searchInApp)` and an `AppShortcutsProvider`.

### 2.1 What builds

- **The 26.0 target, Swift 6 and strict concurrency built clean**, with no warning.
  - Needed no `#available`: `IndexedEntity`, `associateAppEntity`, `CSSearchableItem(appEntity:)` and `indexAppEntities`.
  - Needed 27.0 gating: the `IndexedEntityQuery` conformance and `relatedAppEntityIdentifier`.
  - The `.system.searchInApp` schema intent built beside the classic search intent, and the metadata records it as iOS 27.0 only.
- **`.system.open` cannot sit beside a classic `OpenIntent` on the same entity.** The App Intents metadata processor halted the build: "OpenIntent targets should be unique". A 26.0 app keeps the classic `OpenIntent`, which runs on 26 and 27; the schema form would leave 26 with none.
- **`indexAppEntities` is `@concurrent`, on a non-Sendable `CSSearchableIndex`.** Strict concurrency refused a call on an index the main actor held; it takes an index of its own (`CSSearchableIndex.default()` inline).
- **The exported metadata marks the entity `com.apple.appintents.entity.Indexed`.** `linkd` indexed it and wrote the seven App Shortcut phrases out with the display name. It donated them to Siri about 6 seconds after the app was installed.

### 2.2 What each path writes on the item

Measured on the attribute set before donation, as keyed-archive bytes, for one document of 767 characters:

| Path | Archived | What it adds |
|---|---|---|
| plain | 3,145 bytes | — |
| `associateAppEntity` | 3,717 (+572) | `_kMDItemAppEntityInstanceIdentifier`, `_kMDItemAppEntityTypeIdentifier`, `_kMDItemAppEntityPriority`, `_kMDItemAppEntityTypeDisplayRepresentationName`, `kMDItemAppEntityTitle`, `kMDItemAppEntitySubtitle` |
| `relatedAppEntityIdentifier` (27.0) | 3,275 (+130) | `kMDItemRelatedUniqueIdentifier` alone |
| `CSSearchableItem(appEntity:)` | 3,932 | the same six, with `kMDItemSubtitle` and `MDItemCachedViewData` |

- **The association copies the entity's title and subtitle onto the item**, so they go stale as the item's own title does, until the next donation.
- **27.0's related identifier does not make the item an entity.** It only links the item to one indexed elsewhere, and the item answered no query on the entity attributes (§2.4).

### 2.3 Identity and domain

Read back from the index with `CSSearchQuery`.

- **Every item of the app's own kept `spike-associated/d1`-style identifiers and its volume as its domain**, whether associated, related or updated.
- **The `indexAppEntities` items were keyed `SpikeDocumentEntity/spike-indexedEntity/d1`**, the entity's type name and then its identifier.
  - Their domain was `SpikeDocumentEntity`.
  - Their keywords came from the entity's attribute set.
- **So the replacing path would touch all three donation paths and the landing.**
  - Today's items would have to be deleted, since none would be replaced in place.
  - `rebuildSpotlightIndex()` would donate entities.
  - A volume's removal would delete by entity identifier, document by document.
  - `continueSpotlightActivity` would have to strip the type name, since it splits `CSSearchableItemActivityIdentifier` at its first `/`.

### 2.4 What the index holds, and what each delete removes

A query on each attribute the association writes (`kMDItemAppEntityTitle == "*"` and the rest) matched the same six items:
- the two associated at donation;
- the two associated afterwards by an `isUpdate` item;
- the two `indexAppEntities` items.

The two related-identifier items matched `kMDItemRelatedUniqueIdentifier` alone, and the plain items matched none.

**The update kept the earlier item.** After it, the item still matched a word that appears only in its body (`textContent == "*authorize*"cd`, 5 of 5 groups), and it kept its title, description and keywords. So a library could gain the association from a pass that sends each item's identifier, domain and association, without its 3,200 characters of text.

**The deletes.**
- **A volume's removal** deletes by domain (`deleteSearchableItems(withDomainIdentifiers:)`). Given the associated group's domain and the entity group's, it removed the associated items and left the `indexAppEntities` items.
- **`deleteAppEntities(ofType:)`** removed the `indexAppEntities` items and nothing else.

An associated item is the app's item, removed by the app's own deletes.

### 2.5 Shortcuts, Spotlight and Siri on the simulator

- **Shortcuts.** The Spike Reader page listed Search, Read Later, Open Document and Summarize.
  - A phrase with a document parameter ("Open `${target}` in Spike Reader") expanded into one tile for each document `suggestedEntities()` returned.
  - Run from its tile, Summarize did not open the app. The query resolved its document through `entities(for:)`, the on-device model returned a two-sentence summary 3 seconds later, and Shortcuts showed it in a sheet.
- **Spotlight, searched by a document's full title.**
  - **With those phrases**, each document appeared as a Top Hit and again in a "Spike Reader" section, as an App Shortcut: Open Document's or Summarize's glyph, with the app's badge. A tap ran that intent: the query resolved the identifier and the intent performed, Open bringing the app forward on the document. No tap arrived as `CSSearchableItemActionType`.
  - **Without the parameterised phrases** (a second build), the same searches showed no app content at all, for any of the five groups.
  - **A one-word search** (the marker alone) showed web results; the app's section, as App Shortcut rows, appeared in 1 of 10 such searches.
- **Siri, through `XCUISiriService`** (the simulator's Siri is the server-backed `assistantd` pipeline).
  - "Search Spike Reader" returned web results for the words.
  - "Open Telegram From the Embassy in Varrowind to the Department of State in Spike Reader" sat in Siri's listening state for 10 seconds and never called the app.
  - The two activations after it never got through: the screen still showed that request, and the last timed out.
  - The phrases had been donated to Siri (§2.1), so the simulator's Siri does not settle §4's question in either direction.

### 2.6 Expiry

`CSSearchableItem.expirationDate` defaults to 31 days ahead; the header gives the default as one month. An item made at 00:18 UTC read 2026-11-19 00:00 UTC, 30.99 days on, and so did an item built from an entity. `makeSearchableItem` does not set it.

An item donated with a 60-second expiry was still returned by a query 3 minutes 18 seconds after it expired. So the purge, if Spotlight makes one, is not immediate on the simulator. Whether a library's items leave Spotlight a month after each donation is not measured here.

### 2.7 A full library's re-donation, timed

This is what A7b's bump would cost a library at its first launch.

**The setup.**
- A clone of A4's simulator: iPhone 17e, iOS 27.0, index v69, 553 volumes.
- FRUS Explorer at A4's AppStore build, installed on the clone first, so the clone had a container of its own.
- Its Spotlight shape stamp set back from 4 to 3, so the launch ran the existing gated path, `rebuildSpotlightIndexIfNeeded()`, as a bump would.

**What it measured.**
- The pipeline started 4 seconds after the launch.
- `rebuildSpotlightIndex: resubmitted 318104 items` was logged 1 minute 54 seconds after that. That covers the post-index passes (current, so near no-ops), the delete-all, and 637 batches of 500 items, each awaited until Spotlight had journaled it.
- Meanwhile the app ran at 25 to 50% of a core, and the simulator's Spotlight indexer, `searchd`, at 230 to 320%.
- `searchd` was idle 3 seconds after the last batch. Sampled every 30 seconds for the next five minutes, it read 0% nine times and 27% once, at the last sample. On the simulator Spotlight's processing kept pace with the submission rather than trailing it.

That is the M5's simulator, and a phone is slower. Nothing of it reaches the reader: there is no progress, and it runs at launch after the post-index passes, as at the last three bumps.

## 3. The declaration facts, re-checked

| Declaration | Availability | Note |
|---|---|---|
| `IndexedEntity: AppEntity` | iOS 18.0, macOS 15.0 | `attributeSet` (default `defaultAttributeSet`: title, subtitle, image); `hideInSpotlight` from 18.4 |
| `IndexedEntityQuery: EntityQuery` | iOS 27.0, macOS 27.0 | `reindexEntities(for:indexDescription:)`, `reindexAllEntities(indexDescription:)`; for entities donated with `indexAppEntities` |
| `CSSearchableItem.associateAppEntity(_:priority:)`, and on `CSSearchableItemAttributeSet` | iOS 18.0, macOS 15.0 | an `async` form from 27.0 that resolves deferred properties first |
| `CSSearchableIndex.indexAppEntities`, `deleteAppEntities(identifiedBy:ofType:)`, `deleteAppEntities(ofType:)` | iOS 18.0, macOS 15.0 | the replacing path |
| `CSSearchableItem(appEntity:)` | iOS 18.0, macOS 15.0 | `async` form from 27.0 |
| `relatedAppEntityIdentifier` (item and attribute set) | iOS 27.0, macOS 27.0 | writes `kMDItemRelatedUniqueIdentifier` |
| `NSUserActivity.appEntityIdentifier` | iOS 18.2, macOS 15.2 | the reader's Handoff activity can name the entity on screen |
| `URLRepresentableEntity` | iOS 18.0, macOS 15.0 | lets an open land through a URL |
| `CSSearchableIndexDelegate.searchableItems(forIdentifiers:)` | iOS 18.4, macOS 15.4 | protection-class form from 27.0 |

- **The two platforms match.** The macOS 27.0 SDK declares the same availability for each, macOS 15 where iOS says 18 and macOS 27 where it says 27.
- **The App Schema domains** (`AppIntentSchemas.sqlite`):
  - **`.reader` does not fit FRUS documents.** Its open intent takes files, its search intent searches inside given documents, and its document entity carries a kind and a pixel width and height.
  - **What fits is 27.0's `.system` pair:** `.system.searchInApp`, which deprecates `.system.search` in 27.0, and `.system.open`. The latter is unusable beside a classic `OpenIntent` (§2.1).

## 4. The device check, the owner's step

No declaration settles whether Siri surfaces an associated document, and the simulator's Siri did not reach the app. The check needs the owner's go-ahead, an iPhone and about fifteen minutes.

**Install.**
- **Install the spike, not FRUS Explorer.** Spike Reader has its own bundle identifier, so it cannot touch FRUS Explorer's container. Open `A6Spike/A6Spike.xcodeproj` from this worktree in Xcode, choose the iPhone, and Run.
- **Signing registers a new App ID**, `bottsywattsy.A6Spike`, on team 828S8SXVLC.
- **`devicectl device install app` serves as well, but never with `--remove-existing-content`**: that flag emptied FRUS Explorer's container on this phone on 2026-10-15.

**Record.** Settings ▸ General ▸ About (the model and the iOS version), and whether Apple Intelligence is on.

**In the spike.** Tap donate, then associate-existing, then assoc-query; its log should read 6, 6, 6 and 2 items. Then tap expiry-donate.

**Spotlight.** Search each full title: "Telegram From the Embassy in Quillmere" (plain), "…Varrowind" (associated), "…Tessaloon" (associated by update) and "…Corvantis" (indexed entity). Note what each shows, tap it, and read the spike's Landing line. Tell the two kinds of row apart:
- **An App Shortcut**, as on the simulator: Open Document's or Summarize's glyph, with the app's badge. Its Landing line reads `OpenIntent`.
- **The donated item itself:** the app's icon and the document's opening lines. Its Landing line reads `CSSearchableItemActionType`.

**FRUS Explorer's own donation, as a control.** In Spotlight, search the title of a document from the phone's library: build 50, donated since 2026-10-15. Does a FRUS Explorer result appear, and does a tap open it?

**Siri, by voice or typed.**
- "Open Telegram From the Embassy in Varrowind to the Department of State in Spike Reader"
- "Summarize Telegram From the Embassy in Varrowind in Spike Reader"
- "Search Spike Reader"
- With no app named: "Find the document about emergency grain shipments for famine relief" (the associated group's topic), and "Find the document about a harbor dispute over fishing rights" (the plain group's)
- With a document open in the spike: "Summarize this"

**A day later.** Tap expiry-query: is the item with the 60-second expiry gone? Then remove Spike Reader from the phone, which takes its Spotlight items and its shortcuts with it.

**What the outcomes mean.**
- **Siri reaches documents but surfaces only associated ones.** Then the association (A7b, §5) is what makes Siri find documents without being told the app's name.
- **Siri surfaces neither.** Then A7b buys nothing on this OS, and A7 is the intents alone.
- **The control shows no FRUS Explorer result.** Then the existing donation is not reaching system search on iOS 27, and that is a finding of its own (§6).

## 5. The sketch, sized, and where A7 goes

**The entity.**
- **`FRUSDocumentEntity: AppEntity, IndexedEntity, URLRepresentableEntity`**, keyed by `"\(volumeId)/\(documentId)"`, the identifier the donation and the landing already use.
- **Its display title is `DocumentDisplayTitle`'s**, the Spotlight item's and every list's, with the volume's title as its subtitle.
- **Its URL is `frusexplorer://document/<volumeId>/<documentId>`**, so an open lands through `DeepLinkRoute.document` and `handleDeepLink`, which check the volume against the manifest, as a typed link does.
- **Its query is an `EntityStringQuery`.**
  - `entities(for:)` reads `document_cache` through the pipeline (`documentHeader(volumeId:documentId:)`).
  - `entities(matching:)` is a ranked keyword search through `SearchService`, a dozen rows.
  - `suggestedEntities()` is the most recent `ReadingHistoryEntry` rows. Keep it short: each suggestion becomes a tile in Shortcuts and a runnable action in Spotlight (§2.5).
- **It needs no `IndexedEntityQuery`.** That serves only entities donated with `indexAppEntities`.
- **It lives in the app (`FRUSExplorer/`), never in `FRUSCoreKit/`**, which stays Foundation-only, so nothing is owed to the web edition.

**The four intents, each weighed for what a Siri or Shortcuts caller gets that the app's own screens do not.**
1. **Open a document** (a classic `OpenIntent`). It reaches a named document from Siri, Spotlight, Shortcuts or the Action button without Browse or Search, and recent documents appear in Spotlight as one-tap actions (§2.5). Small. It is also the entity's anchor, which the other three need.
2. **Search the corpus.** A `ShowInAppSearchResultsIntent`, which runs on 26 and 27, and the 27.0 `.system.searchInApp` schema intent beside it (§2.1). The words come from outside and Search opens on them; the screen itself is the app's. Small. A variant for Shortcuts that returns documents, without opening the app, would let a shortcut hand the matches to Summarize or Add to Collection. It is optional, and nothing in the app chains a search into an action today.
3. **Summarize a document** (in the background, through `SummarizationService` and the `SummarizationProvider` it uses). A summary arrives without opening the app, from Siri or as a value a shortcut passes on, which no screen does. The spike's ran in 3 seconds (§2.5). Medium:
   - it should store the `GeneratedSummary` the reader stores, through the same service, with the standard prompt;
   - it needs a clear error where Apple Intelligence is unavailable;
   - a long document's chunked summary must finish within the time the system gives an intent, which is not measured.
4. **Add to a collection.** Adding the document on screen, or a named one, to a named collection by voice, and batch adds from a shortcut, beside the reader's own Add to Collection. Medium:
   - it needs a second entity, `FRUSCollectionEntity`, over the SwiftData `Collection`, whose query leaves smart collections out (`SmartCollectionRule`);
   - it writes through `CollectionDocumentAppend.appendDocuments(_:to:modelContext:)`, which refuses a smart collection, drops duplicates and saves once;
   - the intent needs the app's `ModelContainer`, and must wait for the boot when the system launches the app in the background.

**With them.**
- **"This document."** The reader's Handoff activity sets `appEntityIdentifier`, so "summarize this" can name the document on screen (iOS 18.2, macOS 15.2).
- **The phrases** come in an `AppShortcutsProvider`.
- **The Mac compiles the same sources.** `navigateToDocument`'s `.global` landing serves an open that arrives with no window (#338). The Mac was not tried here.
- **The intents reach the pipeline, the search service and the model container** through `AppDependencyManager`. `AppState.indexingPipeline` and `searchService` are optional until the boot sets them, so each intent waits for them.

**What A7 owes besides code.**
- Every intent title, parameter, dialog and phrase is user-facing copy, with an EditableContent block.
- Both manuals gain a section (Siri, Shortcuts and Spotlight), with a capture slot for §6a.
- The privacy policy's list of what Apple provides under its own policy names Spotlight and Apple Intelligence, but not Siri or Shortcuts. The website copy follows, through `build_website_pages.py`.
- `CLAUDE.md`'s line on the two known build residues loses `appintentsmetadataprocessor`'s note, which disappears once the app depends on App Intents.
- Tests:
  - the query's three methods over a test pipeline;
  - each intent's `perform` against a test `AppState`;
  - the build itself, which the metadata processor halts on a schema error (§2.1).
  - Siri cannot be tested in CI; Shortcuts can be driven as the spike drove it.

**No CloudKit change and no index version.** No `@Model` or stored property is added, and nothing indexing stores changes. A7 is not kit code.

**A7's lanes, as this memo cuts them.**
- **A7a: the entities, the four intents, the phrases, "this document", the Mac, the copy and the manuals.** It changes nothing in the donation, so a library is not re-donated. It is the part a Siri or Shortcuts caller uses whether or not Spotlight's items carry the entity.
- **A7b: the association.** Three parts:
  - `makeSearchableItem` associates the entity and sets `expirationDate`;
  - the libraries already on devices gain both;
  - a `CSSearchableIndexDelegate` answers Spotlight's requests to reindex. The SDK routes those to the delegate for associated items, and the app has none today (§6).

  For the libraries on devices there are two ways:
  - the existing gated path, `currentSpotlightSchemaVersion` 4 → 5, which re-donates every document at the next launch, silently, as at each of the last three bumps;
  - a new pass of `isUpdate` items that carry the association and the expiry without the text (§2.4).

  Either is a pass over every document of every library, and it is exactly what decision 23 kept out of build 51 had the answer been "replacing".

**Where A7 goes (decision 23).** `IndexedEntity` is additive, so by decision 23 A7 would be in build 51, with the build cut after it.
- **The recommendation:** A7a in build 51, since it re-donates nothing, and A7b's place to be the owner's after the device check.
- **If the phone shows that Siri surfaces associated documents and plain ones not,** A7b is what gives Siri the corpus. Its pass is then the decision 23 trade in small: build 51 with a once-per-library pass at launch, timed in §2.7, or build 52.
- **If the phone shows Siri surfaces neither,** A7b waits. Only its expiry fix and its delegate are left, and those turn on §6's first finding, not on App Intents.

**The owner's decision, 2026-10-18** (decision 57), on reading this memo: "I would like to defer A7."
- **A7 is deferred past build 51**, A7a and A7b alike. Build 51 is cut without App Intents, and A8 follows A6.
- **This section stands as A7's plan.** The plan of record keeps it in §6h.
- **The device check no longer gates the build.** It still answers §6's questions about the donation that ships.
- **The issue (§8) is filed on the owner's word.**
- **When A7 is taken up,** the SDK's facts are worth reading again on whatever Xcode is current then.

## 6. Found on the way

- **The donated items expire, and nothing renews them.**
  - `makeSearchableItem` sets no `expirationDate`, so each item expires 31 days after it is donated (§2.6).
  - The app donates when a volume is indexed and at a shape bump.
  - If Spotlight purges at expiry, a library's Spotlight content empties a month after each donation, and the privacy policy's "so that system search can find them" holds only for that month.
  - Not measured: the simulator kept a 60-second item for at least 3 minutes. The spike's `expiry-query` on the phone, a day after `expiry-donate`, would answer it (§4).
- **Spotlight's requests to reindex go unanswered.** The app has no `CSSearchableIndexDelegate`. When Spotlight loses its index or asks for items again, nothing re-donates them until the next shape bump or the volume's next indexing. A7b's delegate would answer.
- **The simulator's Spotlight showed none of the donated items** (§2.5), today's shape included. Nothing in the repository records the donation seen in system search on any device. W-9's measurements read the index from inside the app with `CSUserQuery`. The device check's control (§4) says whether an iPhone under iOS 27 shows them.

## 7. Not done

- **The device check** (§4) is the owner's step.
- **The Mac was not tried.** It would need the spike built for macOS and run on the owner's Mac, which donates into the Mac's Spotlight and registers its phrases with Siri there.
- **Not exercised:** the time the system gives a background intent, a long document's chunked summary inside it, and Add to Collection's SwiftData write.
- **Not studied:** the onscreen awareness for the iPad's and the Mac's several windows.

## 8. The issue, drafted

**Title:** App Intents and Siri: FRUS documents as entities, four intents, and the Spotlight association (A7)

**Body, in short:**
- §1's first three bullets;
- §5's entity, the four intents and what each gives a caller;
- the two lanes, with A7b's two ways for existing libraries;
- what A7 owes besides code;
- no CloudKit change and no index version;
- the device check (§4);
- §6's three findings, as the questions the device check and A7b answer.

The full text is in this session group's notes folder (`a6-issue-draft.md`), to be filed on the owner's word.

## 9. Redoing it

- **The spike** stays in this worktree's `A6Spike/`, untracked:
  - the app, the UI-test target and `project.yml` (generated with XcodeGen);
  - the logs;
  - every screenshot and element tree under `out*/`;
  - the re-donation timing's script (`redonation-timing2.sh`) and its logs under `redonation/`.
- **The simulator** is "A6 Spike iPhone 17" (`21484F90-A531-4A30-9786-A58DC8C47F6D`), iOS 27.0.
- **The re-donation timing's clone was deleted afterwards.** To redo it:
  - clone A4's simulator (`8BE32D39`);
  - install the app on the clone before launching anything, since straight after a clone the app's container still resolves to the source device;
  - shut the clone down and set `spotlightSchemaVersionApplied` to 3 in the new container's preferences;
  - boot it and launch with `-hasCompletedOnboarding YES`, streaming the `IndexingPipeline` category.
- **The launch arguments:**
  - `--spike=inspect,donate,query`, then `associate-existing`, `assoc-query`, `delete-domains`, `delete-entities`, `expiry-donate` and `expiry-query`;
  - `q:<query string>` for any query.
- **A second build** with `SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SPIKE_NO_PARAM_SHORTCUTS'` drops the parameterised phrases (§2.5).
- **The SDK readings** are in the interface files named in §3.
- **The schema domains** come from `AppIntentSchemas.sqlite`, opened read-only with `?immutable=1`.
