# The Privacy Policy and Support pages

App Store Connect requires a Privacy Policy URL and a Support URL. Plan of record decision 36
(2026-10-15) keeps each page in two copies, in step, with the store's fields naming the domain's:

| Page | GitHub copy (edited) | Domain copy (written from it) | Address App Store Connect names |
|---|---|---|---|
| Privacy Policy | `Docs/Privacy-Policy.md` | `Docs/Website/privacy.html` | `https://frusexplorer.app/privacy` |
| Support | `Docs/Support.md` | `Docs/Website/support.html` | `https://frusexplorer.app/support` |

The GitHub copies are read at `https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/…`, the
form `AboutLinks` uses for the manuals, so they are live once merged to `v2`, the default branch.

## Keeping the two in step

Edit the Markdown, never the HTML, then run

```bash
python3 Scripts/build_website_pages.py
```

and commit the Markdown and the HTML together. `--check` writes nothing and exits 1 when either
HTML file is not what its Markdown makes. The script reads only the Markdown these two pages use;
a construct it does not know passes through as text, so it shows in the HTML diff.

A published page is a third copy the repository cannot see: after a change lands, the owner
pastes the new HTML into the site, and the two copies are in step again only then.

## Publishing on frusexplorer.app

The domain is a Squarespace site (it answered `server: Squarespace` on 2026-10-15, as a private
site behind a password). The pages' addresses are in place, named by the owner on 2026-10-18
(decision 26): **help@frusexplorer.app** on the Support page and for the policy's questions, and
**feedback@frusexplorer.app** for Semantic Match Feedback's file, which the app's own mail draft
addresses (`SemanticFeedbackMail.address`). A change to either is made in the Markdown, in the
script's `ADDRESSES` and, for feedback@, in that constant. For each page:

1. Make a page whose URL slug is `privacy` (or `support`), add a Code Block, and paste everything
   between `<main>` and `</main>` of the HTML file. The site's own type and colours apply; the
   file's `<style>` is only for viewing it on its own.
2. Make the site public before the submission. App Review opens both URLs, and on 2026-10-15
   both answered 401. `https://frusexplorer.app/privacy` redirects to `www.`, keeping the path.

## What each factual sentence rests on

Read at `v2` @ `470f818c` on 2026-10-15. A change to anything in the right-hand column owes the
policy an edit. In particular: **the mail draft for Semantic Match Feedback** (decision 26,
built on 2026-10-18 for build 51) needed no edit beyond its address, since the policy already named
email as one way to share the file; **a new network request, a new `@Model`, or a new kind of
record** does.

### The policy

| Claim | Where it is true |
|---|---|
| No data collected, no tracking; the label reads Data Not Collected | `FRUSExplorer/Resources/PrivacyInfo.xcprivacy` (`NSPrivacyTracking` false, `NSPrivacyCollectedDataTypes` empty); plan of record decision 35. No analytics, telemetry or crash-reporting import in the app, the widgets, `FRUSCoreKit` or the kits the app compiles in (every `import` read 2026-10-15), and no MetricKit |
| No account; the developer runs no server the app reports to | Every network call site in the app: `ManifestStore.fetchGitHubListing`, `BackgroundDownloadEngine` and `DownloadManager.performTestDownload` (volumes), `FigureImageLibrary.session`, `SemanticShardFetcher`, `SemanticModelFetcher`, `NARACatalogClient.executeSearch`, `ZoteroAPIClient`. Found by searching for `URLSession`, `.data(for:`, `.download(from:`, `Data(contentsOf:` of a remote URL and every `https://` literal |
| The listing's privacy sentence | Decision 28, verbatim |
| What stays on the device: library, research, trail | Volumes are files under the app's container; research is `ModelContainer.frusModelTypes` (`Models/ModelContainer+FRUS.swift`), every type listed in the policy's second bullet; the trail is `ReadingHistoryEntry`, `SearchHistoryEntry`, `ExportHistoryEntry` |
| Log Research Sessions governs the trail, is on by default, and Delete Recorded Sessions… removes it | `AppState.isResearchLoggingEnabled(in:)` (default `true`); `Settings/ResearchSessionsView.swift` (`settings.notes.logging`, `settings.sessions.logging.footer.trail.v3` / `…mac.v2`, `settings.sessions.deleteAll`, whose action deletes the whole trail) |
| A question typed into a search by meaning does not leave the device | The encoder runs in `Vendor/llama.xcframework` on the device; `settings.model.download.detail`: "Runs on this device only; nothing you search leaves it." |
| Summaries come from Apple Intelligence's on-device model | `Summarization/AppleIntelligenceProvider.swift` (`FoundationModels`, `SystemLanguageModel.default`); both manuals §13 ("no document text leaves your device") |
| Diagnostic records stay unless copied or exported | `Settings/SyncDiagnosticsView.swift` (`settings.syncDiag.footer`: event types, timing and error codes; Copy and Export…); `DataRecoveryView` (`Copy Report`, `Copy Language Analysis Record`); `IndexHealthView` (`Copy Research-State Record`). None is sent by the app |
| Semantic Match Feedback is on the device, not synced, sent only by the reader, and what each verdict holds | `Semantic/SemanticFeedbackLog.swift` (`SemanticFeedbackEntry`); `Settings/SemanticFeedbackView.swift` (`settings.semanticFeedback.privacy.v2`) |
| The file goes by email to feedback@frusexplorer.app only when the reader sends it | `Settings/SemanticFeedbackView.swift` (`SemanticFeedbackMail.address`; **Email Feedback File** writes a draft the reader sends from their own mail app: `MFMailComposeViewController` on iPhone and iPad, `NSSharingService(named: .composeEmail)` on the Mac), beside **Share Feedback File** |
| Spotlight index on the device | `Search/IndexingPipeline+App.swift` (`CSSearchableIndex.default().indexSearchableItems`) |
| Files the reader exports go only where they are saved or sent | Every export leaves through a share sheet or a save panel, and none is among the network call sites above: `DataExportSections` (`Export/ResearchDataExportView.swift`: `ShareLink` for the JSON export, the notes and the method appendix; `NSSavePanel` for **Export Research Database…**, under `#if os(macOS)`); `Collections/CollectionExportSheet.swift`; `Analytics/Export/AnalyticsExportDelivery.swift` |
| Handoff names the document, or the map's volumes and scope | `DocumentView.swift` and `MacDocumentView.swift` (`userInfo` = volume and document ids); `Semantic/Map/SemanticMapSpikeView.swift` (`SemanticMapRequest`: volume ids, scope label, lens, axis poles) |
| iCloud: the private database; local-only without iCloud | `ModelContainer+FRUS.swift` (`cloudKitDatabase: .private("iCloud.bottsywattsy.FRUS-Explorer")`, and `makeLocalContainer()` when CloudKit cannot start) |
| Volumes and the index are not synced | They are files on disk, outside SwiftData; `Reset This Device` in both manuals' recovery ladder: "iCloud data survives" |
| Sync Settings Across Devices: off by default, and what it shares | `SettingsSyncCoordinator` (`enabledKey`, every path gated on `isEnabled`); `SyncSettingsSection` (`settings.sync.toggle.detail`) |
| API keys in the keychain, carried by iCloud Keychain | `KeychainStore`, `NARAAPIKeyStore`, `ZoteroAccountStore` (`kSecAttrSynchronizable` true); `ConnectionsView` (`Held in your keychain and synced via iCloud Keychain…`) |
| Requests carry no identifier of the reader or device | The only headers set are `User-Agent: FRUSExplorer/2.0`, GitHub's `Accept` and API version, NARA's `x-api-key` and Zotero's key and write token; no `identifierForVendor`, advertising identifier, DeviceCheck or App Attest anywhere |
| The volume list: `api.github.com`, at launch and on opening Volumes & Storage or refreshing | `ManifestStore.fetchGitHubListing`; `FRUSExplorerApp` (`fetchLiveManifest()` at launch when online); `VolumesStorageHubView` and `MacVolumesStorageHub` (`refresh()` in `.task` and `refreshCatalog()`) |
| Volumes: `raw.githubusercontent.com/HistoryAtState/frus`, on download or update, and at launch or reconnect to finish | `VolumeManifestEntry.downloadUrl` (`FRUSCoreKit/Models/Manifest/ManifestModels.swift`); `DownloadManager.resumeQueuedDownloads()` at launch and in `onChange(of: appState.isOnline)` |
| Figure images: `static.history.state.gov`, after a download, at launch and reconnect, and one at a time when needed | `FigureImageLibrary.remoteBase`, its ephemeral `session`; `FRUSExplorerApp.fetchMissingFigureImages(with:appState:)`; `PrivacyInfo.xcprivacy`'s comment; `CLAUDE.md` § Figure images |
| Match files: the developer's `frus-semantic-vectors` repository, with each volume and when a semantic feature needs one, unless Download With Volumes is off; or by the two buttons | `SemanticShardFetcher.defaultBaseURL`; `AppState.fetchSemanticShardIfNeeded(for:reason:)` (gated on `isOnline` and the switch); `SemanticStorageSection` (`Download With Volumes`, `Download Missing Vectors`, `Download Vectors for Every Volume`) |
| Which match files a semantic feature fetches shows GitHub the volumes it found, never the question | `SemanticQuerySearcher` asks `AppState.requestSemanticShardForSearch` for the volumes of its top unscored candidates; `SemanticSimilarityGenerator` asks for the anchor's volume and its candidates' (`reason: .readerAskedForSemantics`). The question is encoded on the device and sent nowhere |
| The search model: EmbeddingGemma 2, 310 MB, a release of the same repository, only on Download Search Model | `SemanticModelFetcher` (`releases/download/encoder-2/embeddinggemma-2-Q8_0.gguf`); `AppState.downloadSemanticModel()`, called only from `SemanticModelSection` and `SemanticSearchSharedViews` buttons |
| Neither service is used without the reader's key; Remove Key and Disconnect | `NARACatalogClient.fetchAPIKey()` throws `missingAPIKey`; `SourceExplorerView.load()` returns before any query when `hasAPIKey()` is false; `ConnectionsView` (`Remove Key`, `Disconnect`) |
| NARA: on opening Source Explorer or running a lookup, the note's terms and the key | `SourceExplorerView.load()` (run by `.task(id: loadIdentity)`), `MacSourceExplorerView`, `NARACatalogLookupView`; `NARACatalogClient.executeSearch` (`x-api-key`) |
| Zotero: citation details with tags and notes, never the text; account lookup on connect and on a device the key reached through iCloud Keychain | `ZoteroAPIClient.send(items:…)`, `resolveAccount(key:)`; `ZoteroAccountStore.resolveAccountIfNeeded()` (at launch and on foreground, only with a key and no user ID); `CollectionExportSheet` (`Over the Zotero web API — carries your tags & research notes.`, and "The Zotero formats render citations and notes — never body content") |
| About and the Research Guide open a built-in browser; other links the default browser; the built-in one keeps cookies | `Theme/InAppBrowserView.swift` (`WKWebView()` with the default, persistent website data store); iOS manual §2.4 |
| Erase Everything… and what it removes; settings kept | `settings.erase.warning.inventory.corrections` (`SettingsView.swift`); `DataRecoveryView` (`.eraseEverything`) |
| Keys stay in the keychain after the app is deleted | Keychain items outlive the app on Apple platforms; the app removes them only through `Remove Key` and `Disconnect` |
| Apple's crash reports reach the developer only with the reader's analytics consent, with nothing added by the app | Apple's *Share With App Developers* setting; the app has no crash reporter or MetricKit subscriber |

**Owner commitments, not code facts**: the developer's name (it should match the App Store
seller); how the developer handles an email (used only to answer and improve the app, not sold or
shared, deleted on request); and that the page changes when the app's handling of data does.

### The support page

| Claim | Where it is true |
|---|---|
| The disclaimer | `Planning/Store-Listing-Draft.md` §2, the listing's wording, word for word; the app's own is `about.dos.disclaimer` |
| Manual titles and links; About links to both | `Docs/iOS-User-Manual.md` and `Docs/macOS-User-Manual.md` line 1; `AboutLinks.iosManual`, `AboutLinks.macManual` (`Settings/AboutView.swift`, the Resources section) |
| Where the Research Guide is | iOS manual §16 (Research tab row; Settings → System → About → FRUS Research Guide); macOS manual's menu table (Help → FRUS Research Guide) |
| Version and build in About, as *Version 1.0 (1861)* | `AboutView.appVersion` (`"\(v) (\(b))"`) and `about.version`; decision 25 |
| The Sync Log path, Export…, and what it holds | `SettingsPaneModel` (System group: Connections, Data & Recovery, About); `DataRecoveryView` (`settings.dataRecovery.syncLog`); `SyncDiagnosticsView` |
| Requirements | `project.yml` (`deploymentTarget: "26.0"` for every target); both manuals §2.1 |
| Where the documents come from; offline after download | `VolumeManifestEntry.downloadUrl`; `Store-Listing-Draft.md` §2 |
| Free keys, where they are entered, the NARA card's link | `ConnectionsView` (`A free key from the National Archives Catalog…`, `Get a free key from NARA`); iOS manual (Create a Zotero API key) |
| Natural-language search: experimental, 310 MB, on the device, where to download | `SemanticModelSection` (`settings.model.footer`, `settings.model.download.detail`, `Download Search Model`), mounted by both Volumes & Storage hubs |
| The research database export: Mac only, its path, a checked copy, the reader's writing left out unless switched on; the guide | `DataExportSections` (`Export/ResearchDataExportView.swift`: the section under `#if os(macOS)`, `Export Research Database…`, `Include My Notes, Summaries, and Tags`, a `@State` that is `false` on every entry, an `NSSavePanel` named `frus-index.sqlite`), hosted by `DataRecoveryView` in Settings' System group (`SettingsPaneModel.group`); `ResearchDataExporter` (`PRAGMA quick_check` and each FTS table's `integrity-check` after the copy; a copy that fails is named on screen, `settings.export.database.integrity`, never reported as a plain success); `Docs/Agentic-Analysis-Guide.md` |
| Where the iCloud status is, and the recovery ladder | iOS manual §17 (Settings opens with the status); macOS manual §4.4 (the status bar's iCloud chip); both manuals' Data & Recovery ladder |
| Source code public under Apache 2.0 | `LICENSE`; `AboutLinks.frusExplorerRepo` |
