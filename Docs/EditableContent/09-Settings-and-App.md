# EditableContent — Settings & app-wide messages

Part of the owner’s editing surface, `Docs/EditableContent/` (read `README.md` there first). Covers parts of §6, §18.13–§18.15, parts of §14. Every block’s text is what the app ships after lane WB wrote your 2026-09-30 review back (the build-49 wave) and your 2026-11-20 review was written back for 1.0 (1861); the ✎ boxes that listed your unlanded 2026-09-21 edits are gone, each adopted where you changed its block and dropped where you left it alone. Section numbers are the ones the single file used, so references like “§18’s rule” still point somewhere.

**In this file:** 225 blocks · no ⚑ wording issues

✓ #1476 written in by lane STOR at Volumes & Storage (Library) · ✓ the five two-text keys settled 2026-10-01 (18.15 One key, one text (#1483), its last part)

---

## 6. Settings, Tips & Collections

*Explanatory footers in Settings — the ones that tell a reader what a control costs or protects, across the four groups (Library · Research · Reading & Search · System). Functional and error strings are intentionally excluded. Also the discovery tips and the Collections native-export explanation. Strings shared across platforms via one localization key are marked; where the two platforms genuinely say different things (the Volumes & Storage hub is still two views, and search logging differs by platform) each is a separate edit point and says so.*

---

### iCloud Sync, Settings Sync & Privacy

#### Settings-sync toggle detail
<!-- S-5b made the "single edit point" claim on the three keys below actually true: the macOS Sync pane used to hardcode its own near-identical copy (and had drifted — "shares those settings" vs "shares the settings above"). Both platforms now render `SyncSettingsSection`. -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.rows | lines: 1548–1549 | key: settings.sync.toggle.detail | shared: iOS+macOS (single edit point) -->

Word-cloud filters & stop lists, citation style, default document mode, and research logging.

<!-- END SOURCE: settings.sync.toggle.detail -->

#### Settings-sync unavailable notice
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.rows | lines: 1560–1561 | key: settings.sync.unavailable | shared: iOS+macOS (single edit point) -->

Settings sync needs iCloud. Sign in to iCloud and enable it for FRUS Explorer to turn this on.

<!-- END SOURCE: settings.sync.unavailable -->

#### iCloud Sync section footer
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.footerText | lines: 1570–1571 | key: settings.sync.footer | shared: iOS+macOS (single edit point) -->

When this is on, the device shares the settings above with your other devices that also have it on. Turning it on adopts the settings already in iCloud. Leave it off to keep this device’s settings separate.

<!-- END SOURCE: settings.sync.footer -->

### After an Update — the storage hubs' post-update summary (R-5 P2)

One shared section mounted by both storage hubs. It says, per updated volume, how many changed
documents carry the reader's research and splits them by what moved. Numbers are interpolated
where `%lld` appears.

#### Section header
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 111–111 | key: settings.updateReview.header | shared: iOS+macOS (single edit point) -->

After an Update

<!-- END SOURCE: settings.updateReview.header -->

#### Section footer
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 127–128 | key: settings.updateReview.footer.v2 | shared: iOS only (the macOS wording is the next block) -->

When a volume is updated, the app compares every document with the copy it indexed before and records which ones changed. A document counts as yours if it carries a note, tag, highlight, quotation, collection entry, summary, or archive-visit plan. The Research tab lists the changed ones under “Changed by an update”. Opening one shows a banner saying whether its text moved or only its notes and heading changed — unless the update removed the document altogether, in which case it opens the review sheet, the only surface that can still reach it.

<!-- END SOURCE: settings.updateReview.footer.v2 -->

#### After an Update — footer (macOS)
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 124–125 | key: settings.updateReview.footer.mac.v2 | shared: macOS only (Research is a window here, not a tab) -->

When a volume is updated, the app compares every document with the copy it indexed before and records which ones changed. A document counts as yours if it carries a note, tag, highlight, quotation, collection entry, summary, or archive-visit plan. The Research window lists the changed ones under “Changed by an update”. Opening one shows a banner saying whether its text moved or only its notes and heading changed — unless the update removed the document altogether, in which case it opens the review sheet, the only surface that can still reach it.

<!-- END SOURCE: settings.updateReview.footer.mac.v2 -->

#### Nothing waiting — label
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 80–81 | key: settings.updateReview.none.label | shared: iOS+macOS (single edit point) -->

No changes waiting

<!-- END SOURCE: settings.updateReview.none.label -->

#### Nothing waiting — detail
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 82–83 | key: settings.updateReview.none.detail | shared: iOS+macOS (single edit point) -->

No volume update on this device has changed a document since it was last indexed.

<!-- END SOURCE: settings.updateReview.none.detail -->

#### Summary row — label
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 87–88 | key: settings.updateReview.summary.label | shared: iOS+macOS (single edit point) -->

Updates changed documents

<!-- END SOURCE: settings.updateReview.summary.label -->

#### Summary row — detail
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 217–218 | key: settings.updateReview.summary.detail %lld %lld %lld | shared: iOS+macOS (single edit point) -->

%1$lld documents changed in %2$lld updated volumes. %3$lld of them carry your research. *(Interpolated with the changed-document, volume, and annotated-document totals.)*

<!-- END SOURCE: settings.updateReview.summary.detail %lld %lld %lld -->

#### Volume row — lead
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 240–241 | key: settings.updateReview.volume.lead %lld %lld | shared: iOS+macOS (single edit point) -->

%1$lld of %2$lld changed documents carry your research *(followed by a colon and the non-zero parts below, or a full stop when none apply)*

<!-- END SOURCE: settings.updateReview.volume.lead %lld %lld -->

#### Volume row — part: text
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 229–230 | key: settings.updateReview.part.body %lld | shared: iOS+macOS (single edit point) -->

%lld with changed text

<!-- END SOURCE: settings.updateReview.part.body %lld -->

#### Volume row — part: apparatus
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 233–234 | key: settings.updateReview.part.apparatus %lld | shared: iOS+macOS (single edit point) -->

%lld with changed footnotes, source note, or heading

<!-- END SOURCE: settings.updateReview.part.apparatus %lld -->

#### Volume row — part: gone
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 237–238 | key: settings.updateReview.part.vanished %lld | shared: iOS+macOS (single edit point) -->

%lld no longer in the volume

<!-- END SOURCE: settings.updateReview.part.vanished %lld -->

#### More volumes
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 99–100 | key: settings.updateReview.more %lld | shared: iOS+macOS (single edit point) -->

And %lld more volumes with changed annotated documents.

<!-- END SOURCE: settings.updateReview.more %lld -->

#### Loading
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 106–106 | key: settings.updateReview.loading | shared: iOS+macOS (single edit point) -->

Checking for changed documents…

<!-- END SOURCE: settings.updateReview.loading -->

#### Open Research button
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 201–201 | key: settings.updateReview.openResearch | shared: iOS+macOS (single edit point) -->

Open Research

<!-- END SOURCE: settings.updateReview.openResearch -->

### After an Update — per-volume Mark Reviewed (R-5 P3)

#### Row button
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 148–148 | key: settings.updateReview.markVolumeReviewed | shared: iOS+macOS (single edit point) -->

Mark Reviewed

<!-- END SOURCE: settings.updateReview.markVolumeReviewed -->

#### Dialog title
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 157–158 | key: settings.updateReview.markVolume.title %lld | shared: iOS+macOS (single edit point) -->

Mark %lld changed documents as reviewed?

<!-- END SOURCE: settings.updateReview.markVolume.title %lld -->

#### Dialog confirm
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 163–163 | key: settings.updateReview.markVolume.confirm | shared: iOS+macOS (single edit point) -->

Mark Reviewed

<!-- END SOURCE: settings.updateReview.markVolume.confirm -->

#### Dialog cancel
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 168–168 | key: settings.updateReview.markVolume.cancel | shared: iOS+macOS (single edit point) -->

Cancel

<!-- END SOURCE: settings.updateReview.markVolume.cancel -->

#### Dialog message
<!-- SOURCE: FRUSExplorer/Settings/VolumeUpdateReviewSection.swift | lines: 172–173 | key: settings.updateReview.markVolume.message.v2 | shared: iOS+macOS (single edit point) -->

This marks every changed document in the volume as reviewed. With iCloud sync it reaches your other devices too, a few seconds after they next sync or when they next open. Highlights stay flagged until you confirm each one, and the next update re-opens anything that changes again.

<!-- END SOURCE: settings.updateReview.markVolume.message.v2 -->

### Volumes & Storage (Library)

<!-- The merged Library destination. Replaces the retired Volume Updates and Storage & Backup subsections, whose keys (`settings.volumes.updates.footer`, `settings.storage.aggregate.footer`, `settings.storage.backup.note`) went with the panes S-2b/S-2c deleted. The hub is still TWO views — VolumesStorageHubView.swift for iOS, MacVolumesStorageHub.swift for macOS — so each footer below is a separate edit point unless noted. -->

#### Keeping Current footer

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentSection.swift | KeepingCurrentSection footer | lines: 79–80 | key: settings.hub.keepingCurrent.footer | shared: iOS+macOS (single edit point since #1660, when the two hubs' sections became one shared view) -->

Updating re-downloads and re-indexes a volume. Your notes, highlights, tags, and summaries are preserved.

<!-- END SOURCE: settings.hub.keepingCurrent.footer -->

#### Keeping Current — an update's progress, and why a check could not run (#1660)

*Since build 51 (#1660, the owner's answers of 2026-10-16) a listed volume's row stays after Update or Update All and shows where its update stands; a failed update offers Retry with its reason; a side-loaded copy's row says Update replaces it; and when the published list cannot be read, a row under the two buttons says why. One shared view on every platform, so each block below is a single edit point.*

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentModel.swift | KeepingCurrentCopy | lines: 359–375 | keys: settings.hub.corrections.status.queued, settings.hub.corrections.status.downloading, settings.hub.corrections.status.alreadyDownloading, settings.hub.corrections.status.indexing, settings.hub.corrections.status.updated, settings.hub.corrections.retry | shared: iOS+macOS (single edit point) -->

**Waiting in the queue:** Queued

**Downloading:** Downloading…

**A download of the volume was already under way:** Already downloading…

**Re-indexing:** Indexing…

**Done:** Updated

**A failed row's button:** Retry

<!-- END SOURCE: settings.hub.corrections.status -->

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentModel.swift | KeepingCurrentCopy.sideloaded | lines: 378–379 | key: settings.hub.corrections.sideloaded | shared: iOS+macOS (single edit point) -->

Your side-loaded copy. Update replaces it with the published volume.

<!-- END SOURCE: settings.hub.corrections.sideloaded -->

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentModel.swift | KeepingCurrentCopy.failure(_:) | lines: 387–404 | keys: settings.hub.corrections.failed.offline, settings.hub.corrections.failed.timedOut, settings.hub.corrections.failed.server, settings.hub.corrections.failed.other, settings.hub.corrections.failed.indexing, settings.hub.corrections.failed.noURL | shared: iOS+macOS (single edit point) -->

**No connection:** The download failed: no connection.

**Timed out:** The download failed: it timed out.

**GitHub sent no volume:** The download failed: GitHub did not send the volume.

**Any other cause:** The download failed: \(download.description)

**The re-index failed:** The volume downloaded, and indexing it failed: \(description)

**No catalogue address (not expected, since every listed volume has one):** This volume has no published copy to download.

*(Interpolated with the system's description of the error.)*

<!-- END SOURCE: settings.hub.corrections.failed -->

*L20 (#1920, HCD-3): a volume's own page shows the download lines above, with **Retry** (`settings.hub.corrections.retry`) in Download Volume's place, when its download fails with its retries spent, on iPhone and iPad and in the Mac's Corpus Browser, and VoiceOver hears the line as it arrives. Until L20 such a download vanished, and the Mac's page stayed on Downloading….*

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentModel.swift | KeepingCurrentCopy.listProblem(_:) | lines: 409–435 | keys: settings.hub.corrections.listProblem, settings.hub.corrections.listProblem.offline, settings.hub.corrections.listProblem.rateLimited, settings.hub.corrections.listProblem.rateLimited.noTime, settings.hub.corrections.listProblem.server, settings.hub.corrections.listProblem.unreadable | shared: iOS+macOS (single edit point) -->

**The row's label:** Couldn’t read the published list

**Offline:** This device is offline. Checking compares your volumes with the list on GitHub.

**GitHub's request limit, when it says when it lifts:** GitHub limits how often it answers one network, and this network has reached the limit. Try again after \(time).

**GitHub's request limit, when it does not:** GitHub limits how often it answers one network, and this network has reached the limit. Try again later.

**GitHub answered with an error:** GitHub answered with error \(status). Try again later.

**No reason was recorded:** The list on GitHub could not be read.

*(Any other failure shows the system's own description of it.)*

<!-- END SOURCE: settings.hub.corrections.listProblem -->

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentSection.swift | KeepingCurrentRow.control | lines: 266–271 | keys: settings.hub.corrections.update.a11y, settings.hub.corrections.retry.a11y | shared: iOS+macOS (single edit point) -->

**VoiceOver, a row's Update:** Update \(volumeId)

**VoiceOver, a row's Retry:** Retry the update of \(volumeId)

<!-- END SOURCE: settings.hub.corrections.rowButtons -->

#### Storage & Index footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | storageAndIndexSection footer | lines: 584–585 | key: settings.hub.storageIndex.footer | shared: iOS (macOS carries the same text separately) -->

Notes, highlights, and tags are never affected. For reference: the full FRUS corpus is roughly 3.3 GB of XML plus 3 to 3.5 GB of search index.

<!-- END SOURCE: settings.hub.storageIndex.footer -->

*Measured on two full libraries at index version 74 (L20, #1920): 3.34 GB of XML and an index of 2.88 GB as first built, 3.57 GB after a re-index, whose free pages Compact Database returns. The 9–10 GB this said until then was measured on 2026-05-31, and the index has shrunk since.*

#### Cancel All — the button, the question it asks first, and the Mac's queue line

<!-- SOURCE: FRUSExplorer/Settings/StorageHubModel.swift | HubCopy (Cancel All) | lines: 49–73 | keys: settings.hub.active.cancelAll, settings.hub.active.queueLine, settings.hub.active.cancelAll.title, settings.hub.active.cancelAll.message, settings.hub.active.cancelAll.confirm, settings.hub.active.cancelAll.keep | shared: iOS+macOS (single edit point) -->

**The button:** Cancel All

**The Mac hub's queue line, while anything is queued:** \(volumes(count)) in the download queue

**The question it asks first:** Stop downloading \(volumes(count))?

**Its message:** Volumes already on this device stay. To download the others later, use “Download from GitHub…”.

**Its buttons:** Cancel All Downloads · Keep Downloading

<!-- END SOURCE: settings.hub.active.cancelAll -->

*L20 (#1920): on iPhone and iPad the button sits above Active Downloads' rows when more than one volume is queued, each row keeping its own Cancel; on the Mac, which lists no queue, it sits on the queue line under Download from GitHub… and Sideload XML File…. \(volumes(count)) reads "1 volume" or "553 volumes". Reset This Device and Erase Everything stop every download too, with no question of their own, since each already asks; so does Back from onboarding's Ready step.*

#### Rebuild From Scratch — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | rebuild confirmation | lines: 247–248 | key: settings.hub.rebuild.message.v2 | shared: iOS (macOS carries the same text separately) -->

This deletes everything the app has built for searching — document text, cross-references, page numbers, dates and the people named in each document — and builds it again by re-reading all \(volumes) you have downloaded.

Your research notes, highlights, summaries, collections, and tags are stored separately. They are not affected.

<!-- END SOURCE: settings.hub.rebuild.message.v2 -->

#### Free Up Space — removal confirmation

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | MacManageStorageSheet / FreeUpSpaceSheet confirmation | lines: 1775–1776 | key: settings.hub.freeUp.confirm.message | shared: iOS+macOS (single edit point — the Mac adopted these keys when its missing confirmation was added) -->

The XML files and their search-index rows are deleted from this device. Every one of these volumes can be downloaded again.

<!-- END SOURCE: settings.hub.freeUp.confirm.message -->

#### Free Up Space — size-estimate note

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | FreeUpSpaceSheet | lines: 1735–1736 | key: settings.hub.freeUp.estimateNote | shared: iOS (macOS carries the same text separately) -->

Each size is the XML file plus an estimate of its share of the search index, 0.86 times the XML. That ratio comes from the full corpus: about 2.9 GB of index for about 3.3 GB of XML. Per volume it runs from roughly 0.7 to 1 times, so treat these sizes as approximate.

<!-- END SOURCE: settings.hub.freeUp.estimateNote -->

#### Needs Attention footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | needsAttentionSection footer | lines: 513–514 | key: settings.hub.interrupted.footer.v2 | shared: iOS (macOS carries the same text separately) -->

These volumes were still being indexed when the app last closed. This section appears only when something needs your attention.

<!-- END SOURCE: settings.hub.interrupted.footer.v2 -->


#### Hero summary line, and the Measuring… placeholder (#1476)

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.hub.summary.downloaded %lld %lld | LibraryStatusSummary.text | shared: iOS+macOS (single edit point) -->

%lld of %lld downloaded

<!-- END SOURCE: settings.hub.summary.downloaded %lld %lld -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.hub.summary.nothingYet | LibraryStatusSummary.text | shared: iOS+macOS (single edit point) -->

nothing indexed yet

<!-- END SOURCE: settings.hub.summary.nothingYet -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.hub.summary.someIndexed %lld | LibraryStatusSummary.text | shared: iOS+macOS (single edit point) -->

%lld not yet indexed

<!-- END SOURCE: settings.hub.summary.someIndexed %lld -->

*The hero states no measurement it has not taken (#1476, your 2026-09-30 wording). Until the first
measurement lands its size reads the dash below and its sentence “Measuring…”, and VoiceOver reads the
dash as that sentence. After a measurement fails with no earlier one to show, the dash and “Could not
measure storage”, the words of the failure row beneath it, which the Mac now shows too. A re-measure
that fails keeps the last figures beside that row. A measured library that really is empty keeps
“0 of 553 downloaded · nothing indexed yet”. While volumes are removed they are counted in neither
“downloaded” nor “not yet indexed” but in their own clause, after the index clause and before the
attention clause: “29 of 553 downloaded · all indexed · 1 being removed · nothing needs attention”.*

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | LibraryStatusSummary.text | lines: 143–144 | key: settings.hub.summary.removing.one | shared: iOS+macOS (single edit point) -->

1 being removed

<!-- END SOURCE: settings.hub.summary.removing.one -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | LibraryStatusSummary.text | lines: 146–147 | key: settings.hub.summary.removing %lld | shared: iOS+macOS (single edit point) -->

%lld being removed

<!-- END SOURCE: settings.hub.summary.removing %lld -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | key: settings.hub.loading | the Downloaded section while measuring; also the hero's sentence while measuring, which VoiceOver reads for its dash too (`DownloadedVolumesListModel.heroContent`) | same text also in: FRUSExplorer/Settings/VolumesStorageHubView.swift, FRUSExplorer/Settings/StorageHubModel.swift -->

Measuring…

<!-- END SOURCE: settings.hub.loading -->

<!-- SOURCE: FRUSExplorer/Settings/StorageHubModel.swift | StorageHeroContent.unmeasuredValue | lines: 273–273 | key: settings.hub.hero.unmeasured | shared: iOS+macOS (single edit point) — the hero's size before a measurement, or after one fails with no earlier one -->

—

<!-- END SOURCE: settings.hub.hero.unmeasured -->

<!-- SOURCE: FRUSExplorer/Settings/StorageHubModel.swift | DownloadedVolumesListModel.heroContent | lines: 478–479 | key: settings.hub.measureFailed | the hero's sentence after a measurement fails with no earlier one, and what VoiceOver reads for its dash then | same text also in: FRUSExplorer/Settings/VolumesStorageHubView.swift, FRUSExplorer/Settings/MacVolumesStorageHub.swift (the failure row's label) -->

Could not measure storage

<!-- END SOURCE: settings.hub.measureFailed -->

#### Download options footer (iOS only)

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | optionsSection footer | lines: 699–700 | key: settings.hub.options.footer | shared: iOS only — absorbed the retired iCloud-Backup exclusion note -->

Volume files are large; Wi-Fi is recommended. Downloaded XML is excluded from iCloud Backup — it can be re-downloaded at any time.

<!-- END SOURCE: settings.hub.options.footer -->

#### Remove-volume confirmation

*Four variants of one message: each platform names itself ("this device" / "this Mac"), and each
has a side-loaded form whose bold warning is the load-bearing sentence — a side-loaded volume has
no download to fall back on, so removal can be final. Keep the `**…**` emphasis intact.*

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | remove confirmation | lines: 1342–1343 | key: settings.hub.remove.message.iOS -->

The XML file and its search-index rows are deleted from this device. Your notes, highlights, tags, and summaries for it are kept, and the volume can be downloaded again.

<!-- END SOURCE: settings.hub.remove.message.iOS -->

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | remove confirmation, side-loaded | lines: 1339–1340 | key: settings.hub.remove.message.iOS.sideloaded -->

The XML file and its search-index rows are deleted from this device. Your notes, highlights, tags, and summaries for it are kept. **This volume was side-loaded, so the app cannot download it again** — if you no longer have the file, this cannot be undone.

<!-- END SOURCE: settings.hub.remove.message.iOS.sideloaded -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | remove confirmation | lines: 1287–1288 | key: settings.hub.remove.message -->

The XML file and its search-index rows are deleted from this Mac. Your notes, highlights, tags, and summaries for it are kept, and the volume can be downloaded again.

<!-- END SOURCE: settings.hub.remove.message -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | remove confirmation, side-loaded | lines: 1284–1285 | key: settings.hub.remove.message.sideloaded -->

The XML file and its search-index rows are deleted from this Mac. Your notes, highlights, tags, and summaries for it are kept. **This volume was side-loaded, so the app cannot download it again** — if you no longer have the file, this cannot be undone.

<!-- END SOURCE: settings.hub.remove.message.sideloaded -->

#### Side-loaded — Not in the bundled catalogue

<!-- New with #1523 (owner decision D7). Shown in Volumes & Storage, on iPhone, iPad and Mac, under
     the import's own result ("Imported 1 volume") when a file the reader side-loads is a volume the
     app's bundled catalogue does not list. A file named after a catalogue volume is that volume and
     draws no notice. The row's title is "Not in the bundled catalogue"
     (`settings.hub.sideload.notCatalogued`, the `label` declared in the same file just above this
     block's `detail`); this is its detail line.
     Both storage hubs show the one shared row, so this is a single edit point. Citation Lookup and
     Add Documents' Citations tab resolve citations and links against the bundled catalogue only, so
     they refuse such a volume however it is cited; Browse and Search reach it. -->
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SideloadCatalogueNotice.detail | lines: 401–402 | key: settings.hub.sideload.notCatalogued.detail | shared: iOS+macOS (single edit point) -->

Volumes added from your own files cannot be used with some features that rely on the app’s bundled publication data. Citation Lookup and Add Documents do not resolve a citation or history.state.gov link to them; open them from Browse or find them with Search.

<!-- END SOURCE: settings.hub.sideload.notCatalogued.detail -->

### Connections (System)

<!-- The merged outside-services destination (S-4a). One shared view, so these are single edit points. -->

#### Connections footer

<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | ConnectionsView services section footer | lines: 51–52 | key: settings.connections.footer | shared: iOS+macOS (single edit point) -->

Both keys are held in your keychain and travel with iCloud Keychain to your other devices. Neither service is required — the app works without them.

<!-- END SOURCE: settings.connections.footer -->

#### NARA Catalog — about

<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | NARACatalogConnectionView About section | lines: 252–253 | key: settings.connections.nara.about | shared: iOS+macOS (single edit point) -->

A free key from the National Archives Catalog. Source Explorer needs it to search lot files and Presidential Library records; everything else in the app works without it.

<!-- END SOURCE: settings.connections.nara.about -->

#### Zotero — about

<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | ZoteroConnectionView About section | lines: 488–489 | key: settings.zotero.about.body | shared: iOS+macOS (single edit point) -->

Send FRUS documents to your Zotero library with your tags and research notes attached. Zotero syncs them to all your devices, including the Zotero iOS app. This is the only way to get FRUS annotations into Zotero on iPhone and iPad.

<!-- END SOURCE: settings.zotero.about.body -->

### Data & Recovery (System)

<!-- The merged export/diagnostics/recovery destination (S-4b). Replaces the retired Reset & Data Safety subsection: the recovery ladder renamed its rungs, so all seven `settings.reset.*` keys are gone. -->

#### Recovery ladder footer

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | recoverySection footer | lines: 336–337 | key: settings.dataRecovery.recovery.footer | shared: iOS+macOS (single edit point) -->

In order of how much they take away. Try the first one first — it is the one that deletes nothing.

<!-- END SOURCE: settings.dataRecovery.recovery.footer -->

#### Recovery ladder footer — while an upload is unrecovered (#1531)

*Added by lane SYNC (#1531). Shown in place of the footer above while an upload from this device has failed and none has succeeded since: then Fix iCloud Sync, the first rung, would discard the changes that never reached iCloud, so “the one that deletes nothing” would be untrue. Reset This Device does not touch them.*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | DataRecoveryView.recoveryFooter | lines: 339–340 | key: settings.dataRecovery.recovery.footer.unrecovered | shared: iOS+macOS (single edit point) -->

In order of how much they take away. While this device holds changes that have not reached iCloud, Fix iCloud Sync would discard them too.

<!-- END SOURCE: settings.dataRecovery.recovery.footer.unrecovered -->

#### Fix iCloud Sync — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | fixSync confirmation | lines: 311–312 | key: settings.dataRecovery.fixSync.message | shared: iOS+macOS (single edit point) -->

This clears the local copy of your synced data and downloads it again. Nothing in iCloud is deleted, but unsynced local data could be lost. The app returns to onboarding while it restores. The clearing happens the next time the app starts, so quit and reopen it.

<!-- END SOURCE: settings.dataRecovery.fixSync.message -->

#### Fix iCloud Sync — the warning while an upload is unrecovered (#1531)

*Added by lane SYNC (#1531). While an upload from this device has failed and none has succeeded since, the confirmation opens with this paragraph and then shows the message above, unchanged. %@ is the date and time of the first failed upload, as the device writes dates. It shows whether the failure began in this session or an earlier one.*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | DataRecoveryView.fixSyncMessage | lines: 315–316 | key: settings.dataRecovery.fixSync.warning %@ | shared: iOS+macOS (single edit point) -->

Warning: no upload from this device has succeeded since %@, so it holds changes that are not in iCloud yet. Fix iCloud Sync would discard them.

<!-- END SOURCE: settings.dataRecovery.fixSync.warning %@ -->

#### Fix iCloud Sync — the row’s line while an upload is unrecovered (#1531)

*Added by lane SYNC (#1531). Replaces “Re-download from iCloud at next launch” under the Fix iCloud Sync row in the same state, so the cost shows before the row is tapped.*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | DataRecoveryView.fixSyncRowDetail | lines: 328–329 | key: settings.dataRecovery.fixSync.detail.unrecovered | shared: iOS+macOS (single edit point) -->

Would discard changes not yet in iCloud

<!-- END SOURCE: settings.dataRecovery.fixSync.detail.unrecovered -->

#### Reset This Device — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | resetDevice confirmation | lines: 197–198 | key: settings.dataRecovery.resetDevice.message | shared: iOS+macOS (single edit point) -->

Downloaded volumes and the search index go; your notes, highlights, tags, collections and projects stay in iCloud and come back on the next launch. You will need to download volumes again.

<!-- END SOURCE: settings.dataRecovery.resetDevice.message -->

#### Broken Cross-References report footer

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | reports section footer | lines: 641–642 | key: settings.export.brokenRefs.footer | shared: iOS+macOS (single edit point) -->

Every cross-reference in the printed FRUS volumes that points to a document, page, or volume the corpus does not contain. The list covers the whole corpus. The CSV names each broken target once, not once for every occurrence. A fuller spreadsheet, with one row per occurrence and its source line number, is produced by a separate tool rather than in the app.

<!-- END SOURCE: settings.export.brokenRefs.footer -->

#### Research-data export — JSON footer

<!-- Wave R-5, NEW key (`settings.export.json.footer` listed six things; the file now carries seven). The research trail is named explicitly rather than folded into "your research data" because it is the part a reader would not assume was in there — and the part they may want to check before sharing the file, since it includes the text of every search they ran. -->

<!-- Archives Visits Phase 2, NEW key (`…json.footer.trail` listed seven things; the file now also carries archive visit plans). -->

<!-- FRUS Explorer Light's S16a, format version 7, NEW key (`…json.footer.visits` listed seven kinds of record; the file now also carries saved searches, working corpora, volume scopes, the two kinds of correction, reviewed changes, Suggested Next leads and synced settings). -->

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections JSON section footer | key: settings.export.json.footer.searches | shared: iOS+macOS (single edit point — hosted by Data & Recovery on both) -->

One JSON file with your notes, tags, highlights, collections, custom prompts, projects, archive visit plans, saved searches, working corpora, volume scopes, corrections, reviewed changes, Suggested Next leads, and synced settings. It also holds your research trail: every document you opened, every search you ran and how many results it returned, and every collection you exported.

<!-- END SOURCE: settings.export.json.footer.searches -->

<!-- #1915 (L24), NEW keys: Import from JSON… in Data & Recovery, the report it shows before anything is written, its progress and its done line. One declaration on both platforms (`ResearchImportCopy`), so each block is a single edit point. -->

#### Import from JSON — Import from JSON…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.rowAction | lines: 417–417 | key: settings.import.json.action | shared: iOS+macOS (single edit point) -->

Import from JSON…

<!-- END SOURCE: settings.import.json.action -->

#### Import from JSON — Brings back a file from Export as JSON, written by this app…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.rowFooter | lines: 422–423 | key: settings.import.json.footer | shared: iOS+macOS (single edit point) -->

Brings back a file from Export as JSON, written by this app on any device or by FRUS Explorer Light. Before anything is written, you see what importing it will add and replace.

<!-- END SOURCE: settings.import.json.footer -->

#### Import from JSON — Import from JSON
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.title | lines: 430–430 | key: settings.import.title | shared: iOS+macOS (single edit point) -->

Import from JSON

<!-- END SOURCE: settings.import.title -->

#### Import from JSON — Reading the file…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.reading | lines: 435–435 | key: settings.import.reading | shared: iOS+macOS (single edit point) -->

Reading the file…

<!-- END SOURCE: settings.import.reading -->

#### Import from JSON — Import
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.importAction | lines: 439–439 | key: settings.import.action.import | shared: iOS+macOS (single edit point) -->

Import

<!-- END SOURCE: settings.import.action.import -->

#### Import from JSON — Cancel
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.cancel | lines: 443–443 | key: settings.import.action.cancel | shared: iOS+macOS (single edit point) -->

Cancel

<!-- END SOURCE: settings.import.action.cancel -->

#### Import from JSON — Done
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.done | lines: 447–447 | key: settings.import.action.done | shared: iOS+macOS (single edit point) -->

Done

<!-- END SOURCE: settings.import.action.done -->

#### Import from JSON — File
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fileHeader | lines: 453–453 | key: settings.import.file.header | shared: iOS+macOS (single edit point) -->

File

<!-- END SOURCE: settings.import.file.header -->

#### Import from JSON — Name
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fileNameLabel | lines: 457–457 | key: settings.import.file.name | shared: iOS+macOS (single edit point) -->

Name

<!-- END SOURCE: settings.import.file.name -->

#### Import from JSON — Exported
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.exportedLabel | lines: 461–461 | key: settings.import.file.exported | shared: iOS+macOS (single edit point) -->

Exported

<!-- END SOURCE: settings.import.file.exported -->

#### Import from JSON — Format version
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.versionLabel | lines: 465–465 | key: settings.import.file.version | shared: iOS+macOS (single edit point) -->

Format version

<!-- END SOURCE: settings.import.file.version -->

#### Import from JSON — Exported under the project
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.projectLabel | lines: 469–469 | key: settings.import.file.project | shared: iOS+macOS (single edit point) -->

Exported under the project

<!-- END SOURCE: settings.import.file.project -->

#### Import from JSON — This file is from an earlier version of the export, which…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.olderFileFooter | lines: 479–480 | key: settings.import.fieldsNotCarried | shared: iOS+macOS (single edit point) -->

This file is from an earlier version of the export, which cannot carry \(list). A record the import replaces keeps them as they are here, and a new record takes the app’s defaults.

<!-- END SOURCE: settings.import.fieldsNotCarried -->

#### Import from JSON — An export of this version cannot hold \(…), so the file…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.olderFileFooter | lines: 485–486 | key: settings.import.typesNotCarried | shared: iOS+macOS (single edit point) -->

An export of this version cannot hold \(list), so the file brings none.

<!-- END SOURCE: settings.import.typesNotCarried -->

#### Import from JSON — a note’s formatting
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 495–496 | key: settings.import.field.noteFormatting | shared: iOS+macOS (single edit point) -->

a note’s formatting

<!-- END SOURCE: settings.import.field.noteFormatting -->

#### Import from JSON — a collection’s front matter and export settings
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 498–499 | key: settings.import.field.collectionSettings | shared: iOS+macOS (single edit point) -->

a collection’s front matter and export settings

<!-- END SOURCE: settings.import.field.collectionSettings -->

#### Import from JSON — a collection entry’s kind, text and own settings
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 501–502 | key: settings.import.field.collectionEntryContent | shared: iOS+macOS (single edit point) -->

a collection entry’s kind, text and own settings

<!-- END SOURCE: settings.import.field.collectionEntryContent -->

#### Import from JSON — a project’s focus tags and Suggested Next weights
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 504–505 | key: settings.import.field.projectFocus | shared: iOS+macOS (single edit point) -->

a project’s focus tags and Suggested Next weights

<!-- END SOURCE: settings.import.field.projectFocus -->

#### Import from JSON — a recorded search’s scope and counts
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 507–508 | key: settings.import.field.searchCaptureProvenance | shared: iOS+macOS (single edit point) -->

a recorded search’s scope and counts

<!-- END SOURCE: settings.import.field.searchCaptureProvenance -->

#### Import from JSON — who wrote a summary
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 510–511 | key: settings.import.field.summaryAuthorship | shared: iOS+macOS (single edit point) -->

who wrote a summary

<!-- END SOURCE: settings.import.field.summaryAuthorship -->

#### Import from JSON — Made by FRUS Explorer Light
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webHeader | lines: 518–518 | key: settings.import.web.header | shared: iOS+macOS (single edit point) -->

Made by FRUS Explorer Light

<!-- END SOURCE: settings.import.web.header -->

#### Import from JSON — Summaries
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webSummariesLabel | lines: 522–522 | key: settings.import.web.summaries | shared: iOS+macOS (single edit point) -->

Summaries

<!-- END SOURCE: settings.import.web.summaries -->

#### Import from JSON — Corrections
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webCorrectionsLabel | lines: 526–526 | key: settings.import.web.corrections | shared: iOS+macOS (single edit point) -->

Corrections

<!-- END SOURCE: settings.import.web.corrections -->

#### Import from JSON — Included
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webValue | lines: 533–533 | key: settings.import.web.included | shared: iOS+macOS (single edit point) -->

Included

<!-- END SOURCE: settings.import.web.included -->

#### Import from JSON — Left out
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webValue | lines: 535–535 | key: settings.import.web.leftOut | shared: iOS+macOS (single edit point) -->

Left out

<!-- END SOURCE: settings.import.web.leftOut -->

#### Import from JSON — Not said
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webValue | lines: 537–537 | key: settings.import.web.unsaid | shared: iOS+macOS (single edit point) -->

Not said

<!-- END SOURCE: settings.import.web.unsaid -->

#### Import from JSON — FRUS Explorer Light says what its export leaves out by…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webFooter | lines: 542–543 | key: settings.import.web.footer | shared: iOS+macOS (single edit point) -->

FRUS Explorer Light says what its export leaves out by choice. Its corrections come only in a curator’s export.

<!-- END SOURCE: settings.import.web.footer -->

#### Import from JSON — What the Import Does
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.recordsHeader | lines: 549–549 | key: settings.import.records.header | shared: iOS+macOS (single edit point) -->

What the Import Does

<!-- END SOURCE: settings.import.records.header -->

#### Import from JSON — In all
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.totalLabel | lines: 553–553 | key: settings.import.total | shared: iOS+macOS (single edit point) -->

In all

<!-- END SOURCE: settings.import.total -->

#### Import from JSON — This library already holds every record in the file, as new…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.nothingToDo | lines: 557–558 | key: settings.import.nothingToDo | shared: iOS+macOS (single edit point) -->

This library already holds every record in the file, as new or newer, so importing it would change nothing.

<!-- END SOURCE: settings.import.nothingToDo -->

#### Import from JSON — A record already here is replaced only by a newer copy, and…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.recordsFooter | lines: 564–565 | key: settings.import.records.footer | shared: iOS+macOS (single edit point) -->

A record already here is replaced only by a newer copy, and only in what this file’s version can carry. Nothing here is deleted, so a record you have deleted since this file was made comes back.

<!-- END SOURCE: settings.import.records.footer -->

#### Import from JSON — This device takes the file’s synced settings as they are…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.settingsApplied | lines: 572–573 | key: settings.import.settings.applied | shared: iOS+macOS (single edit point) -->

This device takes the file’s synced settings as they are imported, since Sync Settings Across Devices is on.

<!-- END SOURCE: settings.import.settings.applied -->

#### Import from JSON — The file’s synced settings are kept with your library. This…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.settingsKept | lines: 578–579 | key: settings.import.settings.kept | shared: iOS+macOS (single edit point) -->

The file’s synced settings are kept with your library. This device takes them when Sync Settings Across Devices is turned on.

<!-- END SOURCE: settings.import.settings.kept -->

#### Import from JSON — \(…) set aside
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.counts | lines: 589–590 | key: settings.import.count.setAside | shared: iOS+macOS (single edit point) -->

\(count.setAside) set aside

<!-- END SOURCE: settings.import.count.setAside -->

#### Import from JSON — \(…) repeated
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.counts | lines: 593–594 | key: settings.import.count.repeated | shared: iOS+macOS (single edit point) -->

\(count.repeated) repeated

<!-- END SOURCE: settings.import.count.repeated -->

#### Import from JSON — \(…) to add
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.added | lines: 605–605 | key: settings.import.count.add | shared: iOS+macOS (single edit point) -->

\(count) to add

<!-- END SOURCE: settings.import.count.add -->

#### Import from JSON — \(…) to replace
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.replaced | lines: 609–609 | key: settings.import.count.replace | shared: iOS+macOS (single edit point) -->

\(count) to replace

<!-- END SOURCE: settings.import.count.replace -->

#### Import from JSON — \(…) already here
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.kept | lines: 613–613 | key: settings.import.count.keep | shared: iOS+macOS (single edit point) -->

\(count) already here

<!-- END SOURCE: settings.import.count.keep -->

#### Import from JSON — Research Notes
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 621–621 | key: settings.import.type.researchNote | shared: iOS+macOS (single edit point) -->

Research Notes

<!-- END SOURCE: settings.import.type.researchNote -->

#### Import from JSON — Tags
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 623–623 | key: settings.import.type.userTag | shared: iOS+macOS (single edit point) -->

Tags

<!-- END SOURCE: settings.import.type.userTag -->

#### Import from JSON — Tag Assignments
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 625–625 | key: settings.import.type.documentTagAssignment | shared: iOS+macOS (single edit point) -->

Tag Assignments

<!-- END SOURCE: settings.import.type.documentTagAssignment -->

#### Import from JSON — Highlights
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 627–627 | key: settings.import.type.documentHighlight | shared: iOS+macOS (single edit point) -->

Highlights

<!-- END SOURCE: settings.import.type.documentHighlight -->

#### Import from JSON — Collections
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 629–629 | key: settings.import.type.collection | shared: iOS+macOS (single edit point) -->

Collections

<!-- END SOURCE: settings.import.type.collection -->

#### Import from JSON — Collection Entries
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 631–631 | key: settings.import.type.collectionEntry | shared: iOS+macOS (single edit point) -->

Collection Entries

<!-- END SOURCE: settings.import.type.collectionEntry -->

#### Import from JSON — Custom Prompts
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 633–633 | key: settings.import.type.summarizationPrompt | shared: iOS+macOS (single edit point) -->

Custom Prompts

<!-- END SOURCE: settings.import.type.summarizationPrompt -->

#### Import from JSON — Projects
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 635–635 | key: settings.import.type.project | shared: iOS+macOS (single edit point) -->

Projects

<!-- END SOURCE: settings.import.type.project -->

#### Import from JSON — Summaries
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 637–637 | key: settings.import.type.generatedSummary | shared: iOS+macOS (single edit point) -->

Summaries

<!-- END SOURCE: settings.import.type.generatedSummary -->

#### Import from JSON — Documents Visited
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 639–639 | key: settings.import.type.readingHistoryEntry | shared: iOS+macOS (single edit point) -->

Documents Visited

<!-- END SOURCE: settings.import.type.readingHistoryEntry -->

#### Import from JSON — Searches Executed
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 641–641 | key: settings.import.type.searchHistoryEntry | shared: iOS+macOS (single edit point) -->

Searches Executed

<!-- END SOURCE: settings.import.type.searchHistoryEntry -->

#### Import from JSON — Collections Exported
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 643–643 | key: settings.import.type.exportHistoryEntry | shared: iOS+macOS (single edit point) -->

Collections Exported

<!-- END SOURCE: settings.import.type.exportHistoryEntry -->

#### Import from JSON — Archives Visits
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 645–645 | key: settings.import.type.archiveVisitPlan | shared: iOS+macOS (single edit point) -->

Archives Visits

<!-- END SOURCE: settings.import.type.archiveVisitPlan -->

#### Import from JSON — Archives Visit Documents
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 647–647 | key: settings.import.type.archiveVisitDocument | shared: iOS+macOS (single edit point) -->

Archives Visit Documents

<!-- END SOURCE: settings.import.type.archiveVisitDocument -->

#### Import from JSON — Archives Visit Targets
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 649–649 | key: settings.import.type.archiveVisitTarget | shared: iOS+macOS (single edit point) -->

Archives Visit Targets

<!-- END SOURCE: settings.import.type.archiveVisitTarget -->

#### Import from JSON — Saved Searches
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 651–651 | key: settings.import.type.savedSearch | shared: iOS+macOS (single edit point) -->

Saved Searches

<!-- END SOURCE: settings.import.type.savedSearch -->

#### Import from JSON — Working Corpora
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 653–653 | key: settings.import.type.workingCorpus | shared: iOS+macOS (single edit point) -->

Working Corpora

<!-- END SOURCE: settings.import.type.workingCorpus -->

#### Import from JSON — Volume Scopes
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 655–655 | key: settings.import.type.customVolumeScope | shared: iOS+macOS (single edit point) -->

Volume Scopes

<!-- END SOURCE: settings.import.type.customVolumeScope -->

#### Import from JSON — Classification Corrections
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 657–657 | key: settings.import.type.documentClassificationOverride | shared: iOS+macOS (single edit point) -->

Classification Corrections

<!-- END SOURCE: settings.import.type.documentClassificationOverride -->

#### Import from JSON — Person Corrections
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 659–659 | key: settings.import.type.personClusterOverride | shared: iOS+macOS (single edit point) -->

Person Corrections

<!-- END SOURCE: settings.import.type.personClusterOverride -->

#### Import from JSON — Reviewed Changes
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 661–661 | key: settings.import.type.annotationReview | shared: iOS+macOS (single edit point) -->

Reviewed Changes

<!-- END SOURCE: settings.import.type.annotationReview -->

#### Import from JSON — Suggested Next Leads
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 663–663 | key: settings.import.type.projectLeadEntry | shared: iOS+macOS (single edit point) -->

Suggested Next Leads

<!-- END SOURCE: settings.import.type.projectLeadEntry -->

#### Import from JSON — Synced Settings
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 665–665 | key: settings.import.type.syncedPreferences | shared: iOS+macOS (single edit point) -->

Synced Settings

<!-- END SOURCE: settings.import.type.syncedPreferences -->

#### Import from JSON — From an Earlier Export
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsHeader | lines: 672–672 | key: settings.import.readings.header | shared: iOS+macOS (single edit point) -->

From an Earlier Export

<!-- END SOURCE: settings.import.readings.header -->

#### Import from JSON — Collection entries with no document
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.inertLabel | lines: 676–676 | key: settings.import.inert | shared: iOS+macOS (single edit point) -->

Collection entries with no document

<!-- END SOURCE: settings.import.inert -->

#### Import from JSON — Summaries that name no author
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.noAuthorshipLabel | lines: 680–680 | key: settings.import.noAuthorship | shared: iOS+macOS (single edit point) -->

Summaries that name no author

<!-- END SOURCE: settings.import.noAuthorship -->

#### Import from JSON — Headnote drafts
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.headnotesLabel | lines: 684–684 | key: settings.import.headnotes | shared: iOS+macOS (single edit point) -->

Headnote drafts

<!-- END SOURCE: settings.import.headnotes -->

#### Import from JSON — Collections whose saved search is not here
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.unlinkedLabel | lines: 688–688 | key: settings.import.unlinked | shared: iOS+macOS (single edit point) -->

Collections whose saved search is not here

<!-- END SOURCE: settings.import.unlinked -->

#### Import from JSON — An earlier export wrote a heading, a prose block and a…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsFooter | lines: 695–696 | key: settings.import.inert.detail | shared: iOS+macOS (single edit point) -->

An earlier export wrote a heading, a prose block and a section block alike, without saying which, so these come in as entries the collection editor leaves untouched and no export prints.

<!-- END SOURCE: settings.import.inert.detail -->

#### Import from JSON — A summary that names no author comes in as AI-generated, as…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsFooter | lines: 699–700 | key: settings.import.noAuthorship.detail | shared: iOS+macOS (single edit point) -->

A summary that names no author comes in as AI-generated, as the app reads any such summary.

<!-- END SOURCE: settings.import.noAuthorship.detail -->

#### Import from JSON — A headnote draft is a summary a collection keeps for a…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsFooter | lines: 703–704 | key: settings.import.headnotes.detail | shared: iOS+macOS (single edit point) -->

A headnote draft is a summary a collection keeps for a headnote, which no list or search shows; an earlier export marks it by its prompt.

<!-- END SOURCE: settings.import.headnotes.detail -->

#### Import from JSON — A collection keeps its link to a saved search this library…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsFooter | lines: 707–708 | key: settings.import.unlinked.detail | shared: iOS+macOS (single edit point) -->

A collection keeps its link to a saved search this library does not hold, and shows it as it shows a link to a deleted search.

<!-- END SOURCE: settings.import.unlinked.detail -->

#### Import from JSON — Importing %2$@ of %1$@ record…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.progress | lines: 719–720 | key: settings.import.progress.one %@ %@ | shared: iOS+macOS (single edit point) -->

Importing %2$@ of %1$@ record…

<!-- END SOURCE: settings.import.progress.one %@ %@ -->

#### Import from JSON — Importing %2$@ of %1$@ records…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.progress | lines: 721–722 | key: settings.import.progress.many %@ %@ | shared: iOS+macOS (single edit point) -->

Importing %2$@ of %1$@ records…

<!-- END SOURCE: settings.import.progress.many %@ %@ -->

#### Import from JSON — Imported
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.doneHeader | lines: 727–727 | key: settings.import.done.header | shared: iOS+macOS (single edit point) -->

Imported

<!-- END SOURCE: settings.import.done.header -->

#### Import from JSON — Added
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.addedLabel | lines: 731–731 | key: settings.import.done.added | shared: iOS+macOS (single edit point) -->

Added

<!-- END SOURCE: settings.import.done.added -->

#### Import from JSON — Replaced
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.replacedLabel | lines: 735–735 | key: settings.import.done.replaced | shared: iOS+macOS (single edit point) -->

Replaced

<!-- END SOURCE: settings.import.done.replaced -->

#### Import from JSON — Already here
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.keptLabel | lines: 739–739 | key: settings.import.done.kept | shared: iOS+macOS (single edit point) -->

Already here

<!-- END SOURCE: settings.import.done.kept -->

#### Import from JSON — Notes now in plain text
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.plainNotesLabel | lines: 743–743 | key: settings.import.done.plainNotes | shared: iOS+macOS (single edit point) -->

Notes now in plain text

<!-- END SOURCE: settings.import.done.plainNotes -->

#### Import from JSON — Summaries now AI-generated
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.aiSummariesLabel | lines: 747–747 | key: settings.import.done.aiSummaries | shared: iOS+macOS (single edit point) -->

Summaries now AI-generated

<!-- END SOURCE: settings.import.done.aiSummaries -->

#### Import from JSON — An earlier export cannot carry a note’s formatting or say…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.doneFooter | lines: 754–755 | key: settings.import.done.textChanged | shared: iOS+macOS (single edit point) -->

An earlier export cannot carry a note’s formatting or say who wrote a summary, so a note or summary whose text it replaced reads as plain text or as AI-generated.

<!-- END SOURCE: settings.import.done.textChanged -->

#### Import from JSON — The imported records reach your other devices through…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.doneFooter | lines: 758–759 | key: settings.import.done.sync | shared: iOS+macOS (single edit point) -->

The imported records reach your other devices through iCloud, as your own changes do.

<!-- END SOURCE: settings.import.done.sync -->

#### Import from JSON — Can’t Import This File
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.failedHeader | lines: 767–767 | key: settings.import.failed.header | shared: iOS+macOS (single edit point) -->

Can’t Import This File

<!-- END SOURCE: settings.import.failed.header -->

#### Import from JSON — Import Stopped
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.stoppedHeader | lines: 771–771 | key: settings.import.stopped.header | shared: iOS+macOS (single edit point) -->

Import Stopped

<!-- END SOURCE: settings.import.stopped.header -->

#### Import from JSON — This file was exported by a newer version of FRUS Explorer,…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.problem | lines: 778–779 | key: settings.import.error.newer | shared: iOS+macOS (single edit point) -->

This file was exported by a newer version of FRUS Explorer, at format version \(version). Update the app to import it.

<!-- END SOURCE: settings.import.error.newer -->

#### Import from JSON — This file names format version \(…), which no version…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.problem | lines: 781–782 | key: settings.import.error.unknownVersion | shared: iOS+macOS (single edit point) -->

This file names format version \(version), which no version of FRUS Explorer has written.

<!-- END SOURCE: settings.import.error.unknownVersion -->

#### Import from JSON — This file is not a research export from Export as JSON, or…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.problem | lines: 786–787 | key: settings.import.error.notAnExport | shared: iOS+macOS (single edit point) -->

This file is not a research export from Export as JSON, or it is damaged.

<!-- END SOURCE: settings.import.error.notAnExport -->

#### Import from JSON — The file could not be read: \(…)
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.unreadable | lines: 795–795 | key: settings.import.error.unreadable | shared: iOS+macOS (single edit point) -->

The file could not be read: \(detail)

<!-- END SOURCE: settings.import.error.unreadable -->

#### Import from JSON — The import stopped: \(…) What it saved before it…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.stopped | lines: 800–801 | key: settings.import.error.stopped | shared: iOS+macOS (single edit point) -->

The import stopped: \(detail) What it saved before it stopped is kept, and importing the file again adds the rest.

<!-- END SOURCE: settings.import.error.stopped -->

#### Erase Everything — warning

<!-- Wave R-5, NEW key. Wave R-2a extended `EraseEverythingView.performReset` to delete the whole research trail but left this list — the screen's entire account of what is about to go — unchanged, so the warning under-stated its own reach. -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: the Research Trail erase warning; the trail schema was retired (R-2b). Kept so the
> wording is not lost; delete it, or point it at a live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | key: settings.erase.warning.trail | shared: iOS+macOS (single edit point — reached from the macOS Data & Recovery sheet) -->

This deletes every downloaded volume, the search index, and all of your research notes, projects, tags, collections, highlights, and AI-generated summaries — along with your whole research trail: every document you opened, every search you ran, and every collection you exported. Because your research data syncs, it goes from your other devices too. This cannot be undone.

<!-- END SOURCE: settings.erase.warning.trail -->

#### Erase Everything — first confirmation

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | lines: 1432–1433 | key: settings.erase.confirm1.message | shared: iOS+macOS (single edit point) -->

Everything listed above will be deleted from this device and from iCloud.

<!-- END SOURCE: settings.erase.confirm1.message -->

#### Erase Everything — final confirmation

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | lines: 1448–1449 | key: settings.erase.confirm2.message | shared: iOS+macOS (single edit point) -->

Export your research data first if you might want it back.

<!-- END SOURCE: settings.erase.confirm2.message -->

#### Erase All Data — what exactly goes

<!-- W-4 (#279), NEW key (`…inventory.visits` under-stated the reach once the reset began deleting document-classification corrections — the same fault each predecessor key was minted to fix). -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | key: settings.erase.warning.inventory.corrections -->

This deletes every downloaded volume and the search index. It deletes all of your research notes, projects, tags, collections, highlights, and AI-generated summaries. It also deletes your saved searches, working corpora, custom volume scopes, archive visit plans, project leads, and any person-identity or document-classification corrections you have made. It deletes your whole research trail as well: every document you opened, every search you ran, and every collection you exported. Because your research data syncs, it goes from your other devices too. Your app preferences are kept. This cannot be undone.

<!-- END SOURCE: settings.erase.warning.inventory.corrections -->

---

#### When iCloud has not been told about a record type yet

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | lines: 577–578 | key: settings.dataRecovery.schema.about.pending -->

iCloud has to be told about each kind of record the app saves before it will accept one. Some additions in this version have not been published yet. Records that use them will not upload until they are. Everything else keeps syncing. This is a problem with the app, not with your account. There is nothing you can do here except report it.

<!-- END SOURCE: settings.dataRecovery.schema.about.pending -->

---

#### When the stored data does not match the running build

<!-- SOURCE: FRUSExplorer/Models/StoreSchemaDiagnostic.swift | lines: 118–119 | key: storeSchema.summary.consequence -->

This usually happens when your stored data does not match the build you are running. The data is safe, and iCloud still has its copy. This build cannot open it, so it is using a separate local store. Nothing you do here will sync.

<!-- END SOURCE: storeSchema.summary.consequence -->

---

#### Language Analysis — the Diagnostics row (#1539)

*Added by #1539. A read-only row in Data & Recovery's Diagnostics section, on iPhone, iPad and Mac (one shared view), saying what this device's language analysis can do in this session. The row's title, then its trailing value and detail line for each state: while the app is still checking, when all three parts work, and when one or more does not.*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisRow.body | lines: 745–746 | key: settings.dataRecovery.languageAnalysis | shared: iOS+macOS (single edit point) -->

Language Analysis

<!-- END SOURCE: settings.dataRecovery.languageAnalysis -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 902–903 | key: settings.dataRecovery.languageAnalysis.value.checking | shared: iOS+macOS (single edit point) -->

Checking

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.value.checking -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 904–905 | key: settings.dataRecovery.languageAnalysis.detail.checking | shared: iOS+macOS (single edit point) -->

Finding out what this device’s language analysis can do.

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.detail.checking -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 909–910 | key: settings.dataRecovery.languageAnalysis.value.working | shared: iOS+macOS (single edit point) -->

Working

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.value.working -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 911–912 | key: settings.dataRecovery.languageAnalysis.detail.working | shared: iOS+macOS (single edit point) -->

Dictionary forms, parts of speech and names all work on this device.

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.detail.working -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 914–915 | key: settings.dataRecovery.languageAnalysis.value.limited | shared: iOS+macOS (single edit point) -->

Limited

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.value.limited -->

*Interpolated with the parts that are not working, joined as a list from the three names below — for example “dictionary forms” or “dictionary forms and names”.*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 917–918 | key: settings.dataRecovery.languageAnalysis.detail.limited %@ | shared: iOS+macOS (single edit point) -->

Not working right now: %@. FRUS Explorer checks again each time you come back to it.

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.detail.limited %@ -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.missingCapabilities | lines: 930–931 | key: settings.dataRecovery.languageAnalysis.capability.lemmas | shared: iOS+macOS (single edit point) -->

dictionary forms

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.capability.lemmas -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.missingCapabilities | lines: 934–935 | key: settings.dataRecovery.languageAnalysis.capability.classes | shared: iOS+macOS (single edit point) -->

parts of speech

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.capability.classes -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.missingCapabilities | lines: 938–939 | key: settings.dataRecovery.languageAnalysis.capability.names | shared: iOS+macOS (single edit point) -->

names

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.capability.names -->

#### Language Analysis — Copy Language Analysis Record (#1608)

*Added by #1608. The row under Language Analysis, on iPhone, iPad and Mac (one shared view). It copies what the language check has logged since the app opened, so a tester can paste it into a report: an iPhone’s own log held those lines for about nine hours when it was read on 2026-10-11, and reading that log takes a Mac. Three strings: the button’s title; its title for two seconds after it is pressed, which is also what VoiceOver is told; and its explanation, which is the pointer’s tooltip on the Mac and VoiceOver’s hint on iPhone and iPad. The copied text is not in these files. It is the log’s own lines, each with its time, under the app’s version and build, the system’s version and the device’s model, and it is not translated.*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisRow.copyLabel | lines: 764–765 | key: settings.dataRecovery.languageAnalysis.copy | shared: iOS+macOS (single edit point) -->

Copy Language Analysis Record

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.copy -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisRow.copiedLabel | lines: 770–770 | key: settings.dataRecovery.languageAnalysis.copied | shared: iOS+macOS (single edit point) -->

Copied

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.copied -->

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisRow.body | lines: 757–758 | key: settings.dataRecovery.languageAnalysis.copy.help | shared: iOS+macOS (single edit point) -->

Copies what the language check has found since the app opened, with the app’s and the system’s versions. Paste it into a bug report.

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.copy.help -->

---

### Background Summarization

#### Continue-in-background footer
<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | BackgroundSummarizationSettingsView.backgroundContinuationSection footer | lines: 103–104 | key: bg.summarizer.continue.hint.v2 | shared: iOS+macOS (single edit point) -->

When on, the app keeps summarizing a few documents at a time while you are not using the device, even after you close the app. Uses the on-device model and some battery.

<!-- END SOURCE: bg.summarizer.continue.hint.v2 -->

---

### Display & Reading

*The reading-mode footers in Settings ▸ Display, and the Browse error a broken index produces. New in this regeneration.*

---

#### Reading Width (#1665)

*Settings ▸ Display's Reading Width, beside Document Text Size (#1665, the owner's decisions 20 and 50 of 2026-10-15 and 2026-10-16). Three steps on two ladders: on iPhone 60, 70 and 87ch, on iPad and the Mac 70, 87 and 120ch, so each footer below states its device's figures — the mean characters a line at Medium text, measured on the Long Telegram (`ReadingWidth`). A footer's figures change only with a rung, and `ReadingWidthTests` measures them again.*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | lines: 1686–1696 | keys: settings.display.readingWidth.label, settings.display.readingWidth.a11y | shared: iOS+macOS (single edit point) -->

**The control's name:** Reading Width

**VoiceOver:** Document reading width

<!-- END SOURCE: settings.display.readingWidth.control -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | lines: 1700–1701 | key: settings.display.readingWidth.header | shared: iOS+macOS (single edit point) -->

Reading Width

<!-- END SOURCE: settings.display.readingWidth.header -->

<!-- SOURCE: FRUSExplorer/TEI/ReadingWidth.swift | ReadingWidth.label | lines: 52–55 | keys: settings.display.readingWidth.narrow, settings.display.readingWidth.standard, settings.display.readingWidth.wide | shared: iOS+macOS (single edit point) -->

**The three steps:** Narrow · Standard · Wide

<!-- END SOURCE: settings.display.readingWidth.steps -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView.readingWidthFooter | lines: 1655–1656 | key: settings.display.readingWidth.footer.phone | shared: iPhone only -->

How long a document’s lines may grow: about 63 characters at Narrow, 77 at Standard and 100 at Wide, at Medium text. In portrait the screen is narrower than all three.

<!-- END SOURCE: settings.display.readingWidth.footer.phone -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView.readingWidthFooter | lines: 1658–1659 | key: settings.display.readingWidth.footer.wide | shared: iPad and macOS -->

How long a document’s lines may grow: about 77 characters at Narrow, 100 at Standard and 145 at Wide, at Medium text. A narrower window, or the Research panel beside the document, makes them shorter.

<!-- END SOURCE: settings.display.readingWidth.footer.wide -->

---

#### Reading mode — footer (iPad and Mac)

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | lines: 1792–1793 | key: settings.display.reading.footer -->

“Remember Last” reopens documents in the mode you used last, Read or Research. Research mode shows the Research rail in a side panel beside the document. Read mode hides the rail so you can just read. The rail toggle inside a document always wins for that document.

<!-- END SOURCE: settings.display.reading.footer -->

---

#### Reading mode — footer (iPhone)

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | lines: 1789–1790 | key: settings.display.reading.footer.iphone -->

The Research rail opens as a bottom sheet from the toolbar’s Research button. It never opens on its own, so it cannot cover a document you only meant to read. Edge-Tap Page Turn moves you between documents while the rail is closed.

<!-- END SOURCE: settings.display.reading.footer.iphone -->

---

#### Custom volume scopes — the coverage-years facet

<!-- SOURCE: FRUSExplorer/Settings/CustomScopesView.swift | lines: 966–967 | key: settings.scopes.facet.coverage.footer -->

Adds volumes whose coverage overlaps the years you set. You can also narrow by editor. Leave both years blank to add by editor name alone. Volumes with no coverage dates in the manifest never match a year range.

<!-- END SOURCE: settings.scopes.facet.coverage.footer -->

---

#### Browse — the search index could not be opened

<!-- SOURCE: FRUSExplorer/Browser/BrowserViewModel.swift | lines: 1002–1003 | key: browser.indexing.pipelineUnavailable -->

FRUS Explorer could not open its search index. This volume cannot be indexed or checked until you restart. Relaunch the app. If the message comes back, the index database is damaged and only reinstalling will rebuild it.

<!-- END SOURCE: browser.indexing.pipelineUnavailable -->

---

### Discovery Tips (TipKit)

*Small popovers that appear beside easy-to-miss controls the first few times you reach them. Each
retires once the control is used. Every tip has a **title** and a **message**; both are editable.
The set is re-armable from Settings ▸ Display ▸ **Show Tips Again**.*

#### Tip — Your Research Tools Live Here
*iPhone / iPad only. Appears on the Research-rail toggle in the document toolbar.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ResearchRailTip.title | key: tip.researchRail.title | shared: iOS only -->

Your Research Tools Live Here

<!-- END SOURCE: tip.researchRail.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ResearchRailTip.message | key: tip.researchRail.message | shared: iOS only -->

Citations, the word cloud, archival sources, the cross-reference graph, related documents, and your notes, tags and collections for this document.

<!-- END SOURCE: tip.researchRail.message -->

#### Tip — Tap the Edges to Turn the Page
*iOS only. Appears over the document reading area.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | EdgeTapNavigationTip.title | key: tip.edgeTap.title | shared: iOS only -->

Tap the Edges to Turn the Page

<!-- END SOURCE: tip.edgeTap.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | EdgeTapNavigationTip.message | key: tip.edgeTap.message | shared: iOS only -->

In Read mode, tapping the left or right edge moves to the previous or next document in this volume — the order the editors arranged them in.

<!-- END SOURCE: tip.edgeTap.message -->

#### Tip — Four Ways to Read These Results
*iOS only. Appears on the binoculars menu above search results.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ExamineResultsTip.title | key: tip.examine.title | shared: iOS only -->

Four Ways to Read These Results

<!-- END SOURCE: tip.examine.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | lines: 137–138 | key: tip.examine.message.v2 | shared: iOS only -->

Place them on a timeline, line every occurrence up on your search term, rank the words that keep company with it, or break the whole match down six ways — by year, volume, person, document type, archival provenance and subject.

<!-- END SOURCE: tip.examine.message.v2 -->

#### Tip — Facet Rows Are Filters
*iPhone, iPad and macOS — the one tip with a shared anchor. Appears on the facet panel.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | FacetNarrowTip.title | key: tip.facetNarrow.title | shared: iOS+macOS (single edit point) -->

Facet Rows Are Filters

<!-- END SOURCE: tip.facetNarrow.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | FacetNarrowTip.message | key: tip.facetNarrow.message | shared: iOS+macOS (single edit point) -->

Select a person, a document type or a subject to narrow your search to it. In Years and Volumes, select rows and then Apply. Each narrowing becomes a chip you can clear; the counts always describe the whole match, before any narrowing.

<!-- END SOURCE: tip.facetNarrow.message -->

#### Tip — Browse References as a List
*iOS and macOS. Appears on the reference-list toggle in the cross-reference graph.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | GraphReferenceListTip.title | key: tip.graphList.title | shared: iOS+macOS (single edit point) -->

Browse References as a List

<!-- END SOURCE: tip.graphList.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | GraphReferenceListTip.message | key: tip.graphList.message | shared: iOS+macOS (single edit point) -->

Open a side panel listing every reference with its date, volume, and the footnote that linked it.

<!-- END SOURCE: tip.graphList.message -->

#### Tip — Timeline or Network
*iOS and macOS. Appears on the layout picker in the cross-reference graph.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | TimelineLayoutTip.title | key: tip.timeline.title | shared: iOS+macOS (single edit point) -->

Timeline or Network

<!-- END SOURCE: tip.timeline.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | TimelineLayoutTip.message | key: tip.timeline.message | shared: iOS+macOS (single edit point) -->

Timeline places each document at its date — earlier sources left, later responses right. Network shows the citation web instead.

<!-- END SOURCE: tip.timeline.message -->

#### The tip-recall control (Settings ▸ Display)

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | key: settings.display.tips.header | shared: iOS+macOS (single edit point) -->

Discovery Tips

<!-- END SOURCE: settings.display.tips.header -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | key: settings.display.tips.reset | shared: iOS+macOS (single edit point) -->

Show Tips Again

<!-- END SOURCE: settings.display.tips.reset -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | key: settings.display.tips.reset.done | shared: iOS+macOS (single edit point) -->

Tips will appear again as you reach the controls they point at.

<!-- END SOURCE: settings.display.tips.reset.done -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | key: settings.display.tips.footer | shared: iOS+macOS (single edit point) -->

Tips point out controls that are easy to miss — the Research button, the page-turn edges, the ways to read a result set. Each retires once you use the control it describes. This brings them all back.

<!-- END SOURCE: settings.display.tips.footer -->

---

## 14. Short strings bumped since the build-42 pass — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### Storage hub — the reindex and maintenance controls

#### No volumes on this device yet. Download them from GitHub,…
<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | lines: 427–428 | key: settings.hub.downloaded.empty.iOS.v2 -->

No volumes on this device yet. Download them from GitHub, or add an XML file you already have.

<!-- END SOURCE: settings.hub.downloaded.empty.iOS.v2 -->

#### No volumes on this Mac yet. Download them from GitHub, or…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 414–415 | key: settings.hub.downloaded.empty.v2 -->

No volumes on this Mac yet. Download them from GitHub, or add an XML file you already have.

<!-- END SOURCE: settings.hub.downloaded.empty.v2 -->

#### \(HubCopy.volumes(failures)) could not be indexed
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 571–572 | key: settings.hub.indexFailures.v2 -->

\(HubCopy.volumes(failures)) could not be indexed

<!-- END SOURCE: settings.hub.indexFailures.v2 -->

#### Only volumes not yet fully indexed.
<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | lines: 549–550 | key: settings.hub.indexRemaining.detail.v2 -->

*The line under **Index Remaining** in Volumes & Storage ▸ Storage & Index on iPhone and iPad. The button indexes each downloaded volume the index holds no document of, and since #1689 each one whose indexing stopped before the app finished writing it to the index, which can hold some of its documents and not the rest. Until then it passed the second kind over, and the line read "Only volumes not yet indexed." (`settings.hub.indexRemaining.detail`).*

Only volumes not yet fully indexed.

<!-- END SOURCE: settings.hub.indexRemaining.detail.v2 -->

#### Index volumes not yet fully indexed
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 544–545 | key: settings.hub.indexRemaining.a11y.v2 -->

*What VoiceOver calls the Mac's **Index Remaining** button; its tooltip is the next block. Since #1689 the button also takes a volume whose indexing stopped before the app finished writing it to the index, so its name no longer reads "Index volumes that have not been indexed yet" (`settings.hub.indexRemaining.a11y`).*

Index volumes not yet fully indexed

<!-- END SOURCE: settings.hub.indexRemaining.a11y.v2 -->

#### Indexes only the volumes that still need it, and leaves t…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 546–547 | key: settings.hub.indexRemaining.help.v2 -->

Indexes only the volumes that still need it, and leaves the rest untouched

<!-- END SOURCE: settings.hub.indexRemaining.help.v2 -->

#### Deletes what the app has built for searching and builds i…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 563–564 | key: settings.hub.rebuild.help.v2 -->

Deletes what the app has built for searching and builds it again from every downloaded volume. Use this if search results look wrong, or if leftovers remain from volumes you deleted.

<!-- END SOURCE: settings.hub.rebuild.help.v2 -->

#### Rebuilds what Spotlight knows about your documents. Quick…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 619–620 | key: settings.hub.spotlight.help.v2 -->

Rebuilds what Spotlight knows about your documents. Quicker than a full reindex, because it reuses text the app has already read.

<!-- END SOURCE: settings.hub.spotlight.help.v2 -->

### Storage hub — index health

#### The app updates the index by itself when a new version im…
<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | lines: 611–612 | key: settings.storage.indexHealth.footer.v2 -->

The app updates the index by itself when a new version improves how indexing works. Check Integrity runs a full check whenever you ask for one.

<!-- END SOURCE: settings.storage.indexHealth.footer.v2 -->

### Semantic vectors — fetch failures and refusals

#### There is no file available for this volume.
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 143–144 | key: settings.vectors.error.notPublished.v2 -->

There is no file available for this volume.

<!-- END SOURCE: settings.vectors.error.notPublished.v2 -->

#### The file downloaded correctly, but it was made for a diff…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 156–157 | key: settings.vectors.error.rejected.v2 -->

The file downloaded correctly, but it was made for a different version of the app, so it was not kept. A future update will publish a matching one.

<!-- END SOURCE: settings.vectors.error.rejected.v2 -->

#### The download did not finish. The app tries again when you…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 153–154 | key: settings.vectors.error.transport.v2 -->

The download did not finish. The app tries again when your connection changes.

<!-- END SOURCE: settings.vectors.error.transport.v2 -->

#### The file is no longer on this device.
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 179–180 | key: settings.vectors.refused.missing.v2 -->

The file is no longer on this device.

<!-- END SOURCE: settings.vectors.refused.missing.v2 -->

#### This file was made for a different version of the app, so…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 176–177 | key: settings.vectors.refused.provenance.v2 -->

This file was made for a different version of the app, so it cannot be used with this one. Remove it and download again.

<!-- END SOURCE: settings.vectors.refused.provenance.v2 -->

### Menus, tooltips, and short labels

#### Chronology, Corpus Analytics, Person Analytics, Cross-Ref…
<!-- SOURCE: FRUSExplorer/Browser/BrowserView.swift | lines: 507–508 | key: browse.analysisTools.help.v3 -->

Chronology, Corpus Analytics, Person Analytics, Cross-Reference Analytics, Archival Analytics, Semantic Analytics, and the corpus Word Cloud

<!-- END SOURCE: browse.analysisTools.help.v3 -->

#### Corpus, Person, Cross-Reference, Archival, and Semantic a…
<!-- SOURCE: FRUSExplorer/App/MainWindowView.swift | lines: 423–424 | key: mainwindow.tools.analytics.menu.help.v3 -->

Corpus, Person, Cross-Reference, Archival, and Semantic analytics, Chronology, and Word Cloud

<!-- END SOURCE: mainwindow.tools.analytics.menu.help.v3 -->

#### Research window (⌘⌥R), Collections (⇧⌘K), Archives Visits…
<!-- Archives Visits Phase 3, NEW key (`…help.v2` named three windows; the menu carries four now — the same re-mint `.v2` itself was). -->

<!-- SOURCE: FRUSExplorer/App/MainWindowView.swift | key: mainwindow.tools.myResearch.help.v3 -->

Research window (⌘⌥R), Collections (⇧⌘K), Archives Visits, and Complete History

<!-- END SOURCE: mainwindow.tools.myResearch.help.v3 -->

#### Open Document
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | lines: 1199–1200 | key: research.action.openDocument.v2 -->

Open Document

<!-- END SOURCE: research.action.openDocument.v2 -->

#### Colors group collections by who holds the records — four…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | lines: 307–308 | key: series.provenance.topCollections.method.v4 %lld %lld -->

Colors group collections by who holds the records — four custodians, not the eleven categories above, which classify the citation rather than its holder. Eras here are coarser than the decades above, so a year range ending mid-era still covers the whole era. Document counts come from an index covering all %1$lld cataloged volumes with no 1900 floor, so a row here can rest on volumes the charts above leave out; the collection names come from a cross-volume authority that reaches %2$lld of them. The Categories filter above does not apply to this ranking.

<!-- END SOURCE: series.provenance.topCollections.method.v4 %lld %lld -->

#### Digitized Scans
<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2296–2297 | key: source.explorer.scans.header.v2 -->

Digitized Scans

<!-- END SOURCE: source.explorer.scans.header.v2 -->


## 18. Prose this file had never carried (build-48 sweep) — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### 18.13 Settings

*Footers, empty states and confirmations across Settings that §6 does not carry — Tags, Projects, Volume Scopes, Search, Display, Summarization, Connections (NARA and Zotero), Data & Recovery, the storage hubs, vector and model storage, index health and the research data export. Settings is assembled from more than one view file, so several strings are declared twice; the SOURCE line names every file that carries one.*

#### Footer — Adds all \(…) generated summaries to the JSON export. Off…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.body | lines: 174–175 | key: settings.export.includeSummaries.footer -->

Adds all \(summaries.count) generated summaries to the JSON export. Off by default since AI output can be large.

<!-- END SOURCE: settings.export.includeSummaries.footer -->

#### Footer — One Markdown file per research note, with a citation and…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.body | lines: 220–221 | key: settings.export.markdown.footer -->

One Markdown file per research note, with a citation and link back to the source document. Compatible with Obsidian and similar note-taking tools.

<!-- END SOURCE: settings.export.markdown.footer -->

#### Footer — A complete copy of the search index, for analysis with your…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.databaseExportSection | lines: 304–305 | key: settings.export.database.footer | shared: macOS only -->

A complete copy of the search index, for analysis with your own tools. With the switch off, your notes, summaries and tag names are removed from the copy and the freed space reclaimed, so the words are gone rather than merely unlinked. The copy is verified before it is handed over. It is roughly the size of the index on disk.

<!-- END SOURCE: settings.export.database.footer -->

#### Exported \(…), but the copy did not verify: \(…)
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.exportIndexDatabase | lines: 344–345 | key: settings.export.database.integrity | shared: macOS only -->

Exported \(size), but the copy did not verify: \(report.integrityProblems.joined(separator: "; "))

<!-- END SOURCE: settings.export.database.integrity -->

*The line under Export Research Database… on the Mac (#1910): the index version the copy will carry, which a tool that reads the copy may require, or why the button waits. The Mac shows one of the five at a time, and the done line after a copy that verified.*

#### The copy will carry index version \(…).
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 678–679 | key: settings.export.database.indexVersion | shared: macOS only -->

The copy will carry index version \(installed).

<!-- END SOURCE: settings.export.database.indexVersion -->

#### The copy will carry index version \(…), not this build’s \(…).
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 675–676 | key: settings.export.database.indexVersion.older | shared: macOS only -->

The copy will carry index version \(installed), not this build’s \(current).

<!-- END SOURCE: settings.export.database.indexVersion.older -->

#### The index is being updated to version \(…). You can export it…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 664–665 | key: settings.export.database.indexVersion.updatingTo | shared: macOS only -->

The index is being updated to version \(current). You can export it when the update is done.

<!-- END SOURCE: settings.export.database.indexVersion.updatingTo -->

#### The index is being updated. You can export it when the update is done.
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 667–668 | key: settings.export.database.indexVersion.updating | shared: macOS only -->

The index is being updated. You can export it when the update is done.

<!-- END SOURCE: settings.export.database.indexVersion.updating -->

#### The index has no version recorded yet.
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 671–672 | key: settings.export.database.indexVersion.none | shared: macOS only -->

The index has no version recorded yet.

<!-- END SOURCE: settings.export.database.indexVersion.none -->

#### Exported \(…), index version \(…).
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.doneLine | lines: 688–689 | key: settings.export.database.done.withVersion | shared: macOS only -->

Exported \(size), index version \(version).

<!-- END SOURCE: settings.export.database.done.withVersion -->

*On the Mac each of the three file exports is also saved where the reader chooses (R6a, F3): the JSON in a save panel, and the notes and the query log in a new folder inside the folder an open panel chooses, numbered when one of the name is there. The share menu stays beside each, and a line under the row says where the files went. iOS keeps its share sheet.*

#### Export as JSON…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.jsonExportRow | lines: 427–427 | key: settings.export.json.action.mac | shared: macOS only -->

Export as JSON…

<!-- END SOURCE: settings.export.json.action.mac -->

#### Share…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.shareTitle | lines: 413–413 | key: settings.export.share | shared: macOS only -->

Share…

<!-- END SOURCE: settings.export.share -->

#### Export Notes as Markdown (\(…))…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.markdownExportRow | lines: 479–480 | key: settings.export.markdown.action.mac | shared: macOS only -->

Export Notes as Markdown (\(markdownExportURLs.count))…

<!-- END SOURCE: settings.export.markdown.action.mac -->

#### FRUS Research Notes
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.markdownExportRow | lines: 472–473 | key: settings.export.markdown.folderName | shared: macOS only -->

FRUS Research Notes

<!-- END SOURCE: settings.export.markdown.folderName -->

#### Choose a folder. Your notes are saved in a new folder inside…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.markdownExportRow | lines: 474–475 | key: settings.export.markdown.panelMessage | shared: macOS only -->

Choose a folder. Your notes are saved in a new folder inside it, “FRUS Research Notes”, one Markdown file per note.

<!-- END SOURCE: settings.export.markdown.panelMessage -->

#### Export Query Log as a Method Appendix…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.appendixExportRow | lines: 525–526 | key: settings.export.appendix.action.mac | shared: macOS only -->

Export Query Log as a Method Appendix…

<!-- END SOURCE: settings.export.appendix.action.mac -->

#### FRUS Query Log
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.appendixExportRow | lines: 518–519 | key: settings.export.appendix.folderName | shared: macOS only -->

FRUS Query Log

<!-- END SOURCE: settings.export.appendix.folderName -->

#### Choose a folder. The query log is saved in a new folder inside…
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.appendixExportRow | lines: 520–521 | key: settings.export.appendix.panelMessage | shared: macOS only -->

Choose a folder. The query log is saved in a new folder inside it, “FRUS Query Log”, as a Markdown table and a CSV.

<!-- END SOURCE: settings.export.appendix.panelMessage -->

#### Export Here
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.saveFolderExport | lines: 389–389 | key: settings.export.folder.prompt | shared: macOS only -->

Export Here

<!-- END SOURCE: settings.export.folder.prompt -->

#### Saved “\(…)” in \(…).
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | ExportDestinationWriter.savedFileLine | lines: 778–779 | key: settings.export.saved.file | shared: macOS only -->

Saved “\(name)” in \(folder).

<!-- END SOURCE: settings.export.saved.file -->

#### Saved %1$@ file in a new folder, “%2$@”, in %3$@.
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | ExportDestinationWriter.savedFolderLine | lines: 789–790 | key: settings.export.saved.folder.one %@ | shared: macOS only -->

Saved %1$@ file in a new folder, “%2$@”, in %3$@.

<!-- END SOURCE: settings.export.saved.folder.one %@ -->

#### Saved %1$@ files in a new folder, “%2$@”, in %3$@.
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | ExportDestinationWriter.savedFolderLine | lines: 791–792 | key: settings.export.saved.folder.many %@ | shared: macOS only -->

Saved %1$@ files in a new folder, “%2$@”, in %3$@.

<!-- END SOURCE: settings.export.saved.folder.many %@ -->

#### Couldn’t save the export: \(…)
<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | ExportDestinationWriter.failedLine | lines: 798–799 | key: settings.export.saveFailed | shared: macOS only -->

Couldn’t save the export: \(error.localizedDescription)

<!-- END SOURCE: settings.export.saveFailed -->

#### The included copy of the terms could not be loaded. The…

> ⚠️ **RETIRED — editing this block has no effect.** The bundled Gemma Terms screen went with
> EmbeddingGemma 300m (B4, 2026-10-15). Kept so the wording is not lost; delete it when you
> next revise this section.

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | GemmaTermsView.body | key: about.gemmaTerms.missing -->

The included copy of the terms could not be loaded. The authoritative text is at the link below.

<!-- END SOURCE: about.gemmaTerms.missing -->

#### No key yet. Source Explorer needs one to search lot files…
<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | ConnectionsView.statusDetail | lines: 137–138 | key: settings.connections.nara.off -->

No key yet. Source Explorer needs one to search lot files and Presidential Library records.

<!-- END SOURCE: settings.connections.nara.off -->

#### Alert message — Source Explorer’s archival search stops working on this…
<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | NARACatalogConnectionView.body | lines: 294–295 | key: settings.connections.nara.remove.message -->

Source Explorer’s archival search stops working on this device and every device sharing your iCloud Keychain. Nothing you’ve already saved is affected.

<!-- END SOURCE: settings.connections.nara.remove.message -->

#### Requests this app has made with your key in the last 30…
<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | NARACatalogConnectionView.usageFooter | lines: 378–379 | key: settings.connections.nara.usage.footer -->

Requests this app has made with your key in the last 30 days. NARA sets the actual rate limit and this app can’t see it, so treat this as your own record rather than a quota.

<!-- END SOURCE: settings.connections.nara.usage.footer -->

#### Alert message — “Send to Zotero Library…” disappears from collections and…
<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | ZoteroConnectionView.body | lines: 532–533 | key: settings.connections.zotero.disconnect.message -->

“Send to Zotero Library…” disappears from collections and documents. Anything already sent stays in your Zotero library.

<!-- END SOURCE: settings.connections.zotero.disconnect.message -->

#### Footer — The key is checked with Zotero before it’s stored, so a bad…
<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | ZoteroConnectionView.accountSection | lines: 588–589 | key: settings.connections.zotero.account.footer.off -->

The key is checked with Zotero before it’s stored, so a bad paste is caught here rather than the first time you try to send something.

<!-- END SOURCE: settings.connections.zotero.account.footer.off -->

#### Create a named set of volumes to use as a search scope…
<!-- SOURCE: FRUSExplorer/Settings/CustomScopesView.swift | CustomScopesView.body | lines: 80–81 | key: settings.scopes.empty.detail | same text also in: FRUSExplorer/Settings/FRUSSettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Create a named set of volumes to use as a search scope — for example, every volume covering a crisis, a region, or an administration.

<!-- END SOURCE: settings.scopes.empty.detail -->

#### Footer — Scopes sync to your other devices via iCloud. Deleting a…
<!-- SOURCE: FRUSExplorer/Settings/CustomScopesView.swift | CustomScopesView.body | lines: 119–120 | key: settings.scopes.footer -->

Scopes sync to your other devices via iCloud. Deleting a scope does not affect searches already run with it.

<!-- END SOURCE: settings.scopes.footer -->

#### %lld volumes selected · %lld indexed. Volumes you haven’t…
<!-- SOURCE: FRUSExplorer/Settings/CustomScopesView.swift | CustomScopeEditorView.footerText | lines: 317–318 | key: settings.scopes.editor.footer %lld %lld -->

%lld volumes selected · %lld indexed. Volumes you haven’t downloaded stay in the scope and take effect once indexed.

<!-- END SOURCE: settings.scopes.editor.footer %lld %lld -->

#### Alert message — Your local copy will be cleared and re-downloaded from…
<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | DataRecoveryView.body | lines: 181–182 | key: settings.dataRecovery.fixSync.relaunch.message -->

Your local copy will be cleared and re-downloaded from iCloud the next time FRUS Explorer starts. Nothing has been deleted yet, and nothing in iCloud is affected.

<!-- END SOURCE: settings.dataRecovery.fixSync.relaunch.message -->

#### Footer — Records that use these will fail to upload until the…
<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | SchemaDeployStatusView.body | lines: 519–520 | key: settings.dataRecovery.schema.awaiting.footer -->

Records that use these will fail to upload until the developer publishes the schema update in the CloudKit Dashboard. Everything else syncs normally.

<!-- END SOURCE: settings.dataRecovery.schema.awaiting.footer -->

#### Footer — Fields the app declares but nothing writes yet. They cannot…
<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | SchemaDeployStatusView.body | lines: 539–540 | key: settings.dataRecovery.schema.reserved.footer -->

Fields the app declares but nothing writes yet. They cannot be published until a future version records one, and nothing syncs differently because of them.

<!-- END SOURCE: settings.dataRecovery.schema.reserved.footer -->

#### iCloud has to be told about each kind of record the app…
<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | SchemaDeployStatusView.explanation | lines: 574–575 | key: settings.dataRecovery.schema.about.current -->

iCloud has to be told about each kind of record the app saves before it will accept one. Everything this version saves has been published, so nothing is being held back for this reason.

<!-- END SOURCE: settings.dataRecovery.schema.about.current -->

#### Footer — The active project scopes the notes, collections, history…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsProjectsPane.body | lines: 254–255 | key: settings.projects.active.footer | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

The active project scopes the notes, collections, history, and searches you see. Global Context shows everything.

<!-- END SOURCE: settings.projects.active.footer -->

#### No projects yet. A project keeps one line of research — its…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsProjectsPane.body | lines: 262–263 | key: settings.projects.empty.where | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

No projects yet. A project keeps one line of research — its notes, collections, history and searches — separate from the rest.

<!-- END SOURCE: settings.projects.empty.where -->

#### Footer — This order is also the order of the Active Project picker…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsProjectsPane.body | lines: 324–325 | key: settings.projects.list.footer.order.mac | shared: macOS only -->

This order is also the order of the Active Project picker, the Switch Project menu and the note editor's project list. Right-click a project to move it.

<!-- END SOURCE: settings.projects.list.footer.order.mac -->

#### Footer — Open Tags to rename, merge or delete a tag. Open Volume…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsProjectsPane.body | lines: 349–350 | key: settings.projects.related.footer | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Open Tags to rename, merge or delete a tag. Open Volume Scopes to edit or delete a scope — scopes cannot be merged.

<!-- END SOURCE: settings.projects.related.footer -->

#### Footer — Named sets of volumes usable as search scopes. Scopes sync…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsScopesPane.body | lines: 490–491 | key: settings.scopes.pane.subtitle | shared: macOS only -->

Named sets of volumes usable as search scopes. Scopes sync to your other devices via iCloud; volumes you haven’t downloaded stay in a scope and take effect once indexed.

<!-- END SOURCE: settings.scopes.pane.subtitle -->

#### No tags yet. Tags are the labels you apply to research…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsTagsPane.body | lines: 636–637 | key: settings.tags.empty.where | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

No tags yet. Tags are the labels you apply to research notes and documents as you read — create one here, or from any note.

<!-- END SOURCE: settings.tags.empty.where -->

#### Footer — Tags are global labels you apply to research notes and…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsTagsPane.body | lines: 700–701 | key: settings.tags.pane.subtitle | shared: macOS only -->

Tags are global labels you apply to research notes and documents. They are not scoped to a project.

<!-- END SOURCE: settings.tags.pane.subtitle -->

#### Footer — This order is also the order of your tags in the note…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsTagsPane.body | lines: 702–703 | key: settings.tags.list.footer.order.mac | shared: macOS only -->

This order is also the order of your tags in the note editor, the document tag picker and Search. Right-click a tag to move it.

<!-- END SOURCE: settings.tags.list.footer.order.mac -->

#### Not available on this device. Prompts still edit and sync…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsSummarizationPane.body | lines: 780–781 | key: settings.summarization.availability.unavailable | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Not available on this device. Prompts still edit and sync to your other devices, where they are used for generation.

<!-- END SOURCE: settings.summarization.availability.unavailable -->

*L20 (#1920, HCD-5): said only where the device cannot run Apple Intelligence. Turned off, or with its model not ready yet, the row says why (`ai.availability.*`, in 08), then the block below.*

#### Prompts still edit and sync to your other devices…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsSummarizationPane.body | lines: 782–783 | key: settings.summarization.availability.unavailable.prompts | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Prompts still edit and sync to your other devices, where they are used for generation.

<!-- END SOURCE: settings.summarization.availability.unavailable.prompts -->

#### Footer — The prompts the app ships with. They can’t be edited…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsSummarizationPane.body | lines: 810–811 | key: settings.summarization.standard.footer | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

The prompts the app ships with. They can’t be edited — start from one with Use as Template.

<!-- END SOURCE: settings.summarization.standard.footer -->

#### No prompts of your own yet. Prompts you create appear here…
<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsSummarizationPane.body | lines: 819–820 | key: settings.summarization.user.empty.where | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

No prompts of your own yet. Prompts you create appear here and sync to your other devices via iCloud.

<!-- END SOURCE: settings.summarization.user.empty.where -->

#### Tooltip (macOS) / VoiceOver hint (iOS) — Copies app build, index versions, the indexed volume list…
<!-- SOURCE: FRUSExplorer/Settings/IndexHealthView.swift | IndexHealthView.researchStateButton | lines: 198–199 | key: indexHealth.researchState.help -->

Copies app build, index versions, the indexed volume list and the vector provenance as JSON — what a reproducible research claim needs to cite

<!-- END SOURCE: indexHealth.researchState.help -->

#### Tooltip (macOS) / VoiceOver hint (iOS) — Run the full SQLite and FTS5 corruption diagnostic on the…
<!-- SOURCE: FRUSExplorer/Settings/IndexHealthView.swift | IndexHealthView.integrityButton | lines: 250–251 | key: indexHealth.integrity.help -->

Run the full SQLite and FTS5 corruption diagnostic on the search index — may take a moment on a large index

<!-- END SOURCE: indexHealth.integrity.help -->

#### Tooltip — Compares each downloaded volume against the FRUS repository…
<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentSection.swift | KeepingCurrentSection.listButtons | lines: 124–125 | key: settings.hub.corrections.help | shared: macOS only -->

Compares each downloaded volume against the FRUS repository and lists any that changed since you downloaded them

<!-- END SOURCE: settings.hub.corrections.help -->

#### Tooltip — Re-reads the FRUS repository’s volume list, refreshing each…
<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentSection.swift | KeepingCurrentSection.listButtons | lines: 149–150 | key: settings.hub.catalog.help.v2 | shared: macOS only -->

Re-reads the FRUS repository’s volume list, refreshing each volume’s download link and size and dropping any the Office of the Historian has withdrawn

<!-- END SOURCE: settings.hub.catalog.help.v2 -->

#### Tooltip — Lists downloaded volumes with no attached notes…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | MacVolumesStorageHub.storageAndIndexSection | lines: 529–530 | key: settings.hub.freeUp.help | shared: macOS only -->

Lists downloaded volumes with no attached notes, collections, or summaries so you can remove them

<!-- END SOURCE: settings.hub.freeUp.help -->

#### Tooltip — This volume carries notes, collections, or summaries and is…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | MacAllVolumesSheet.row | lines: 1309–1310 | key: settings.hub.protected.help | shared: macOS only -->

This volume carries notes, collections, or summaries and is never suggested for automatic removal

<!-- END SOURCE: settings.hub.protected.help -->

#### Empty state — Every published volume will be queued. Downloads run in the…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | MacDownloadVolumesSheet.body | lines: 1442–1443 | key: settings.hub.browse.corpus.body | shared: macOS only -->

Every published volume will be queued. Downloads run in the background and resume across launches; you can start reading as soon as the first volume lands.

<!-- END SOURCE: settings.hub.browse.corpus.body -->

#### \(…) · \(…) of XML, plus about as much again in search index.…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | MacDownloadVolumesSheet.corpusDetail | lines: 1623–1624 | key: settings.hub.browse.corpus.detail | shared: iOS+macOS (one text on both hubs since #1483; VolumesStorageHubView.swift declares it too, in DownloadVolumesBrowseView.scopeFooter) | same text also in: FRUSExplorer/Settings/VolumesStorageHubView.swift -->

\(HubCopy.volumes(allVolumes.count)) · \(xml) of XML, plus about as much again in search index. Downloads run in the background and resume across launches.

<!-- END SOURCE: settings.hub.browse.corpus.detail -->

*The Entire Corpus card’s detail in the Mac’s download sheet, and the footer under the iPhone and iPad picker. The Mac took the second sentence on 2026-10-01: its downloads use the same background transfer and keep the volumes still waiting in their queue. That was checked in the code, not yet tried on a Mac, and a volume that is mid-download when the app quits comes back only if macOS kept that transfer going. On the Mac the panel below the card, the block above this one, says it too.*

#### Select volumes to remove. Only volumes with no attached…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | MacManageStorageSheet.body | lines: 1755–1756 | key: settings.hub.freeUp.subtitle | shared: macOS only -->

Select volumes to remove. Only volumes with no attached notes, collections, or summaries are shown.

<!-- END SOURCE: settings.hub.freeUp.subtitle -->

#### Empty state — Every downloaded volume has attached notes, collections, or…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | MacManageStorageSheet.body | lines: 1774–1775 | key: settings.hub.freeUp.none.detail | shared: macOS only -->

Every downloaded volume has attached notes, collections, or summaries. Remove those individually from “Show all” in Volumes & Storage.

<!-- END SOURCE: settings.hub.freeUp.none.detail -->

#### Frees %@. Everything else — volumes, notes, keyword search…
<!-- SOURCE: FRUSExplorer/Settings/SemanticModelSection.swift | SemanticModelSection.removeButton | lines: 211–212 | key: settings.model.remove.detail %@ -->

Frees %@. Everything else — volumes, notes, keyword search — stays exactly as it is. You can download it again any time.

<!-- END SOURCE: settings.model.remove.detail %@ -->

#### Download With Volumes is off, so these will not arrive on…
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | SemanticStorageSection.downloadDetail | lines: 210–211 | key: settings.vectors.download.detail.switchOff -->

Download With Volumes is off, so these will not arrive on their own.

<!-- END SOURCE: settings.vectors.download.detail.switchOff -->

#### %lld volumes, about %@. Includes volumes you have not…
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | SemanticStorageSection.corpusWideDownloadButton | lines: 240–241 | key: settings.vectors.downloadAll.detail %lld %@ -->

%lld volumes, about %@. Includes volumes you have not downloaded, so the whole series can be searched by meaning at full precision.

<!-- END SOURCE: settings.vectors.downloadAll.detail %lld %@ -->

#### Footer — This order is also the order of your tags in the note…
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | UserTagsView.body | lines: 544–545 | key: settings.tags.list.footer.order -->

This order is also the order of your tags in the note editor, the document tag picker and Search.

<!-- END SOURCE: settings.tags.list.footer.order -->

#### Footer — This order is also the order of the Active Project picker…
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | ProjectsSettingsView.body | lines: 781–782 | key: settings.projects.list.footer.order -->

This order is also the order of the Active Project picker, the project switcher and the note editor's project list.

<!-- END SOURCE: settings.projects.list.footer.order -->

#### All notes tagged ‘\(…)’ will be re-tagged with the selected…
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | MergeTagSheet.macBody | lines: 991–992 | key: settings.tags.merge.explanation -->

All notes tagged ‘\(sourceTag.name)’ will be re-tagged with the selected tag. ‘\(sourceTag.name)’ will be deleted.

<!-- END SOURCE: settings.tags.merge.explanation -->

#### Footer — How many colors the Chronology and Corpus Analytics charts…
<!-- #1756: re-keyed from settings.display.chartColors.footer. The count is of colors, the gray
     "Other volumes" among them, so the default of 8 names seven volumes; the row above it reads
     "Colors per chart: %lld" (settings.display.chartColors.value.v2), where it said volumes. -->
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView.body | lines: 1719–1720 | key: settings.display.chartColors.footer.v2 -->

How many colors the Chronology and Corpus Analytics charts use for their volumes. When more volumes contribute than there are colors, the last color is a gray “Other volumes” holding the rest, so a chart names one volume fewer than its colors. Each chart can override this per view.

<!-- END SOURCE: settings.display.chartColors.footer.v2 -->

#### Footer — Used for Copy Citation, Share Citation, and the citation…
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView.body | lines: 1745–1746 | key: settings.display.citationStyle.footer.mac | shared: macOS only -->

Used for Copy Citation, Share Citation, and the citation popover’s default. The popover can still switch styles per-presentation for comparison.

<!-- END SOURCE: settings.display.citationStyle.footer.mac -->

#### VoiceOver hint — When on, tapping near the left or right edge of a document…
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView.body | lines: 1780–1781 | key: settings.display.edgeTapNavigation.a11y | shared: iOS only -->

When on, tapping near the left or right edge of a document opens the previous or next one — available whenever the Research rail is closed

<!-- END SOURCE: settings.display.edgeTapNavigation.a11y -->

#### Footer — These defaults can be overridden per-session in the Search…
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SearchDefaultsView.body | lines: 1873–1874 | key: settings.search.scope.footer -->

These defaults can be overridden per-session in the Search filter panel. At least one scope stays on — searching nothing has no result to show.

<!-- END SOURCE: settings.search.scope.footer -->

#### Footer — Documents you have reclassified between “document” and…
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SearchDefaultsView.body | lines: 1941–1942 | key: settings.search.classificationCorrections.footer -->

Documents you have reclassified between “document” and “editorial note”. This filter, badges, counts, and exports follow your corrections.

<!-- END SOURCE: settings.search.classificationCorrections.footer -->

#### Footer — How many lines of matched context each search result shows.…
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SearchDefaultsView.body | lines: 1956–1957 | key: settings.search.snippet.footer -->

How many lines of matched context each search result shows. Individual search screens can override this default.

<!-- END SOURCE: settings.search.snippet.footer -->

#### A local, on-device record of iCloud sync events. It…
<!-- SOURCE: FRUSExplorer/Settings/SyncDiagnosticsView.swift | SyncDiagnosticsView.body | lines: 31–32 | key: settings.syncDiag.about -->

A local, on-device record of iCloud sync events. It contains no personal information and nothing about your documents — only event types, timing, and error codes. Export it to help diagnose sync problems.

<!-- END SOURCE: settings.syncDiag.about -->

#### Footer — Merging needs a second tag to merge into. Deleting removes…
<!-- SOURCE: FRUSExplorer/Settings/TagEditorView.swift | TagEditorView.editorForm | lines: 190–191 | key: tag.editor.manage.footer.only -->

Merging needs a second tag to merge into. Deleting removes this tag from every note and document that carries it; nothing else is deleted.

<!-- END SOURCE: tag.editor.manage.footer.only -->

#### Footer — Merging re-tags everything here with the tag you choose…
<!-- SOURCE: FRUSExplorer/Settings/TagEditorView.swift | TagEditorView.editorForm | lines: 192–193 | key: tag.editor.manage.footer -->

Merging re-tags everything here with the tag you choose, then removes this one. Deleting removes this tag from every note and document that carries it; nothing else is deleted.

<!-- END SOURCE: tag.editor.manage.footer -->

#### Re-read the published list to refresh sizes and download…
<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentSection.swift | KeepingCurrentSection.listButtons | lines: 194–195 | key: settings.hub.catalog.detail.v2 | shared: iOS only -->

Re-read the published list to refresh sizes and download links.

<!-- END SOURCE: settings.hub.catalog.detail.v2 -->

#### \(…) · \(…) of XML, plus about as much again in search index.… (iOS)

*One text on both hubs since #1483 (2026-10-01): its one block, `settings.hub.browse.corpus.detail`, is with the Mac hub’s earlier in §18.13, and an edit there is applied to this footer too.*

#### Empty state — Every downloaded volume has attached notes, collections, or…
<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | FreeUpSpaceSheet.body | lines: 1722–1723 | key: settings.hub.freeUp.none.detail.iOS | shared: iOS only -->

Every downloaded volume has attached notes, collections, or summaries. Remove those individually from the full volume list.

<!-- END SOURCE: settings.hub.freeUp.none.detail.iOS -->

#### No volumes are downloaded yet. Summarization reads the…
<!-- SOURCE: FRUSExplorer/Summarization/BatchRunReadiness.swift | BatchRunBlocker.reason | lines: 91–92 | key: bg.summarizer.blocked.nothingDownloaded -->

No volumes are downloaded yet. Summarization reads the volume text, so there is nothing to run against.

<!-- END SOURCE: bg.summarizer.blocked.nothingDownloaded -->

#### None of this scope’s volumes are downloaded. Summarization…
<!-- SOURCE: FRUSExplorer/Summarization/BatchRunReadiness.swift | BatchRunBlocker.reason | lines: 115–116 | key: bg.summarizer.blocked.customScopeNotDownloaded -->

None of this scope’s volumes are downloaded. Summarization reads the volume text, so download at least one first.

<!-- END SOURCE: bg.summarizer.blocked.customScopeNotDownloaded -->

#### Footer — Closing this doesn’t stop a run. Progress and the result…
<!-- SOURCE: FRUSExplorer/Summarization/BatchRunSheet.swift | BatchRunSheet.footer | lines: 43–44 | key: settings.summarization.runSheet.footer -->

Closing this doesn’t stop a run. Progress and the result appear on the Summarization screen.

<!-- END SOURCE: settings.summarization.runSheet.footer -->

### 18.14 App-wide status, sync and schema messages

*The iCloud and sync notices in the status bar, the store-schema diagnostic and its recovery alert, and the macOS indexing queue's finalizing line.*

#### Not signed in to iCloud — notes, highlights, and…
<!-- SOURCE: FRUSExplorer/App/AppState.swift | AppState.accountStatusDescription | lines: 669–670 | key: cloudkit.account.noAccount -->

Not signed in to iCloud — notes, highlights, and collections won’t sync. Sign in via Settings → Apple ID.

<!-- END SOURCE: cloudkit.account.noAccount -->

#### Alert message — To rebuild this device’s copy from iCloud, use Settings ▸…
<!-- SOURCE: FRUSExplorer/App/StoreSchemaMismatchAlert.swift | StoreSchemaMismatchAlert.message | lines: 89–90 | key: storeSchema.alert.recovery -->

To rebuild this device’s copy from iCloud, use Settings ▸ Data & Recovery ▸ Fix iCloud Sync, then quit and reopen the app.

<!-- END SOURCE: storeSchema.alert.recovery -->

#### iCloud sync is unavailable — notes, collections, and tags…
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | StatusBarView.cloudKitStatusChip | lines: 619–622 | key: statusBar.sync.disabled.help | shared: macOS only -->

iCloud sync is unavailable — notes, collections, and tags won’t sync across devices. Check that you are signed in to iCloud and that the app has iCloud permissions in System Settings.

<!-- END SOURCE: statusBar.sync.disabled.help -->

#### Tooltip — The iCloud sync zone is missing — data cannot upload or…
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | StatusBarView.cloudKitStatusChip | lines: 662–663 | key: statusBar.sync.zoneMissing.help | shared: macOS only -->

The iCloud sync zone is missing — data cannot upload or download. Force-quit the app and relaunch to trigger zone recreation, or use Settings → Data & Recovery → Fix iCloud Sync.

<!-- END SOURCE: statusBar.sync.zoneMissing.help -->

#### Merging FTS5 segments for \(…) indexed documents. This may…
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | MacIndexingQueuePanel.body | lines: 920–921 | key: indexing.queue.mac.finalizing.detail | shared: macOS only -->

Merging FTS5 segments for \(update.totalDocuments.formatted()) indexed documents. This may take 30–60 seconds.

<!-- END SOURCE: indexing.queue.mac.finalizing.detail -->

#### \(…) holds the same \(…) record types this build declares…
<!-- SOURCE: FRUSExplorer/Models/StoreSchemaDiagnostic.swift | StoreSchemaDiagnostic.summary | lines: 95–96 | key: storeSchema.summary.match -->

\(storeName) holds the same \(storeEntityNames.count) record types this build declares, so a stale store is not the cause of this failure.

<!-- END SOURCE: storeSchema.summary.match -->

#### \(…) was created with \(…) record types; this build…
<!-- SOURCE: FRUSExplorer/Models/StoreSchemaDiagnostic.swift | StoreSchemaDiagnostic.summary | lines: 101–102 | key: storeSchema.summary.counts -->

\(storeName) was created with \(storeEntityNames.count) record types; this build declares \(modelEntityNames.count).

<!-- END SOURCE: storeSchema.summary.counts -->

#### In the store but not in this build: \(…). This store was…
<!-- SOURCE: FRUSExplorer/Models/StoreSchemaDiagnostic.swift | StoreSchemaDiagnostic.summary | lines: 113–114 | key: storeSchema.summary.extra -->

In the store but not in this build: \(absentFromModel.joined(separator: ", ")). This store was written by a newer build.

<!-- END SOURCE: storeSchema.summary.extra -->


#### Sync banner — the red failed banner’s title (#1531)

<!-- SOURCE: FRUSExplorer/App/SyncStatusBanner.swift | key: sync.banner.failed.title | SyncStatusBanner.content -->

iCloud Sync Failed

<!-- END SOURCE: sync.banner.failed.title -->

#### Sync banner — the red failed banner’s detail line (#1531)

*#1531: the line under the title. It used to be the redacted error itself, such as “CKErrorDomain partialFailure (2)”; that error is still on the Settings iCloud Sync row, which the banner’s **Details** button opens, and the error’s code is in Sync Diagnostics. VoiceOver reads the title and this line. It is the wording for one failed sync; a failure the app remembers across launches has its own wording, **iCloud Sync Stopped**, below (lane SYNC). Since lane SYNC an upload that failed keeps this banner up, in that session, until an upload succeeds: a later successful download no longer hides it.*

<!-- SOURCE: FRUSExplorer/App/SyncStatusBanner.swift | key: sync.banner.failed.detail | SyncStatusBanner.content -->

Your changes are kept on this device. Relaunch the app to try again.

<!-- END SOURCE: sync.banner.failed.detail -->

#### Sync banner — the sync zone is missing (#1376)

<!-- SOURCE: FRUSExplorer/App/SyncStatusBanner.swift | key: sync.banner.zoneMissing.detail | SyncStatusBanner.content -->

Nothing syncs until it’s recreated. Relaunch, or use Fix iCloud Sync.

<!-- END SOURCE: sync.banner.zoneMissing.detail -->

#### Sync banner — a stopped sync, remembered across launches (#1531)

*Added by lane SYNC (#1531): the wording for a failure the app remembers across launches. It shows when an upload from this device failed in an EARLIER session and none has succeeded since — so the reader has already relaunched, and the banner neither tells them to relaunch nor promises a retry. A successful download does not hide it; only a successful upload ends it. The one-session failure keeps its own line above. VoiceOver reads the title and the line. Details opens the Settings iCloud Sync row, which says since when (next blocks).*

<!-- SOURCE: FRUSExplorer/App/SyncStatusBanner.swift | key: sync.banner.stopped.title | SyncStatusBanner.content -->

iCloud Sync Stopped

<!-- END SOURCE: sync.banner.stopped.title -->

<!-- SOURCE: FRUSExplorer/App/SyncStatusBanner.swift | key: sync.banner.stopped.detail | SyncStatusBanner.content -->

Sync stopped on this device; your changes are kept here.

<!-- END SOURCE: sync.banner.stopped.detail -->

#### A stopped sync — the Settings row and the Mac status bar (#1531)

*Added by lane SYNC (#1531). The iPhone and iPad Settings iCloud Sync row reads **Sync Stopped**, and the Mac status bar's chip reads **Sync Stopped** and opens a popover titled **iCloud Sync Stopped**. Both show the explanation below, with %@ the date and time of the first failed upload, then “Diagnostic:” and the redacted error and any record-type and field names it carried, for a bug report. The Mac chip's tooltip is the explanation alone.*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 286–286 | key: settings.icloud.stopped -->

Sync Stopped

<!-- END SOURCE: settings.icloud.stopped -->

<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | StatusBarView.cloudKitStatusChip | lines: 705–705 | key: statusBar.sync.stopped | shared: macOS only -->

Sync Stopped

<!-- END SOURCE: statusBar.sync.stopped -->

<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | StatusBarView.cloudKitStatusChip | lines: 715–716 | key: statusBar.sync.stopped.title | shared: macOS only -->

iCloud Sync Stopped

<!-- END SOURCE: statusBar.sync.stopped.title -->

<!-- SOURCE: FRUSExplorer/App/ICloudStatusSummary.swift | SyncStoppedCopy.detail | lines: 195–196 | key: sync.stopped.detail %@ | shared: iOS+macOS (single edit point) -->

No upload from this device has succeeded since %@. Your changes are kept here, and Fix iCloud Sync would discard them.

<!-- END SOURCE: sync.stopped.detail %@ -->

<!-- SOURCE: FRUSExplorer/App/ICloudStatusSummary.swift | SyncStoppedCopy.diagnostic | lines: 206–207 | key: sync.stopped.diagnostic %@ | shared: iOS+macOS (single edit point) -->

Diagnostic: %@

<!-- END SOURCE: sync.stopped.diagnostic %@ -->

#### Mac status bar — a volume's indexing counts (#1478)

*Added 2026-09-30 (lane WB). The Mac status bar's line after a volume indexes, "Indexed <title> · 12,067 docs · 1 person · 78 links", and its detail while indexing, "56 persons · 78 links · 1,200/1,234 dated". They were plain strings that printed "1 persons" and ungrouped numbers; the docs count uses the shared `count.docs.one`/`.many` forms.*

<!-- SOURCE: FRUSCoreKit/Models/CountCopy.swift | StatusBarCopy.indexedSummary | key: statusBar.indexed %@ -->

Indexed %@

<!-- END SOURCE: statusBar.indexed %@ -->

<!-- SOURCE: FRUSCoreKit/Models/CountCopy.swift | StatusBarCopy.counts | key: statusBar.persons.one -->

%@ person

<!-- END SOURCE: statusBar.persons.one -->

<!-- SOURCE: FRUSCoreKit/Models/CountCopy.swift | StatusBarCopy.counts | key: statusBar.persons.many -->

%@ persons

<!-- END SOURCE: statusBar.persons.many -->

<!-- SOURCE: FRUSCoreKit/Models/CountCopy.swift | StatusBarCopy.counts | key: statusBar.links.one -->

%@ link

<!-- END SOURCE: statusBar.links.one -->

<!-- SOURCE: FRUSCoreKit/Models/CountCopy.swift | StatusBarCopy.counts | key: statusBar.links.many -->

%@ links

<!-- END SOURCE: statusBar.links.many -->

<!-- SOURCE: FRUSCoreKit/Models/CountCopy.swift | StatusBarCopy.metaSummary | key: statusBar.dated %@ %@ -->

%1$@/%2$@ dated

<!-- END SOURCE: statusBar.dated %@ %@ -->

#### The Live Activity, once the app has stopped updating it (#1642)

*Added 2026-10-12 (#1642). What the Lock Screen and the Dynamic Island say under the activity’s title when the app has stopped updating it: iOS suspended the app after you left it, or the app was closed. The system marks the activity two minutes after the app’s last update, and until then it shows the progress as it stood. One sentence for an index run and two for a summarization run. The widget cannot tell a suspended app from a closed one, so each sentence has to be true of both: opening the app carries a suspended run on, and after the app was closed the launch removes the activity. A summarization run started with Continue in the background switched on, which the app will take up again by itself between your visits, reads the third sentence (#1695, plan of record decision 64, 2026-10-19); with it off, or switched on only after the run began, the second. Since #1695 the three are in `FRUSExplorer/Models/IndexingActivityAttributes.swift`, the file the app and the widget both compile, where they were in the widget’s own file, so a test reads what the widget prints. The indexing sentence fits one line on an iPhone 17’s Lock Screen and the summarization sentence wraps to two; the second was seen only on a build that labelled an index run as a summarization run, since no summarization runs on a simulator.*

<!-- SOURCE: FRUSExplorer/Models/IndexingActivityAttributes.swift | ContentState.stoppedLabel | lines: 128–129 | key: liveactivity.stopped.indexing -->

Indexing has stopped. Open FRUS Explorer to continue.

<!-- END SOURCE: liveactivity.stopped.indexing -->

<!-- SOURCE: FRUSExplorer/Models/IndexingActivityAttributes.swift | ContentState.stoppedLabel | lines: 135–136 | key: liveactivity.stopped.summarizing -->

Summarizing has stopped. Open FRUS Explorer to continue.

<!-- END SOURCE: liveactivity.stopped.summarizing -->

<!-- SOURCE: FRUSExplorer/Models/IndexingActivityAttributes.swift | ContentState.stoppedLabel | lines: 132–133 | key: liveactivity.stopped.summarizing.background -->

Summarizing will continue in the background. Open FRUS Explorer to continue now.

<!-- END SOURCE: liveactivity.stopped.summarizing.background -->

#### The Live Activity while the app is updating it (#1695)

*Added 2026-10-20 (#1695). The activity’s other words, which had no block: what it says under the title before a volume’s documents are counted, and before a summarization run knows how many documents it has; the title of the merge that ends a whole-library index pass, which had been empty; and the title of a summarization run. Since #1695 one activity follows a whole indexing queue, titled by each volume in turn (plan of record decision 63), and the finishing merge’s words are its title, where they had been a line under an empty one. The count under the bar (“312/740 docs”) and the seconds left (“~12s”, none under five since #1695) are not keyed strings, and have no block.*

<!-- SOURCE: FRUSExplorerWidgets/IndexingLiveActivity.swift | ContentState.indeterminateLabel | lines: 48–48 | key: liveactivity.parsing -->

Parsing…

<!-- END SOURCE: liveactivity.parsing -->

<!-- SOURCE: FRUSExplorerWidgets/IndexingLiveActivity.swift | ContentState.indeterminateLabel | lines: 52–53 | key: liveactivity.summarizing.preparing -->

Preparing to summarize…

<!-- END SOURCE: liveactivity.summarizing.preparing -->

<!-- SOURCE: FRUSExplorer/App/AppState.swift | LiveActivityLifecycle.indexingState | lines: 4669–4669 | key: liveactivity.optimizing -->

Finalizing index…

<!-- END SOURCE: liveactivity.optimizing -->

<!-- SOURCE: FRUSExplorer/App/AppState.swift | LiveActivityLifecycle.summarizationState | lines: 4711–4712 | key: liveactivity.summarizing.title -->

Summarizing FRUS documents

<!-- END SOURCE: liveactivity.summarizing.title -->

### 18.15 One key, one text (#1483)

*Added 2026-09-27 for this review and closed on 2026-09-30 with your choice, “all A”. Each key below was declared with two different texts. Each now carries one text, or its second text has a key of its own. Each block shows the text with every place it ships, by file and line after the close-out. The Source Explorer key of the same kind, `source.explorer.unrecognized.explanation`, is in §11.1. A test now fails when any key in the app is declared with two texts. It found five more, each an iPhone/iPad text beside a Mac one, and you settled those on 2026-10-01 with “all recommended” (the last part of this section). The test now lets no key through.*

#### `analytics.export.column.occurrences`

<!-- SOURCE: FRUSCoreKit/Analytics/AnalyticsValueUnit.swift | key: analytics.export.column.occurrences | ships at: AnalyticsValueUnit.swift:91 -->

Occurrences (index stems)

<!-- END SOURCE: analytics.export.column.occurrences -->

*Corpus Analytics’ CSV column. The Word Cloud CSV’s count column now has a key of its own, because it counts something else: NLTagger lemmas in document text, not index stems.*

<!-- SOURCE: FRUSCoreKit/Analytics/Export/AnalyticsChartTables.swift | key: analytics.export.column.wordcloud.occurrences | ships at: AnalyticsChartTables.swift:442 -->

Occurrences

<!-- END SOURCE: analytics.export.column.wordcloud.occurrences -->

#### `archiveVisit.picker.new`

<!-- SOURCE: FRUSExplorer/TripPacket/PlanPickerSheet.swift | key: archiveVisit.picker.new | ships at: PlanPickerSheet.swift:179, MacArchiveVisitManagerView.swift:235 | same text also in: FRUSExplorer/TripPacket/MacArchiveVisitManagerView.swift -->

New Archives Visit

<!-- END SOURCE: archiveVisit.picker.new -->

*The Mac plan menu’s item has no ellipsis now. Like the iOS row, it creates the visit at once and opens no dialog.*

#### `browser.volume.partial`

<!-- SOURCE: FRUSExplorer/Browser/SubseriesView.swift | key: browser.volume.partial | ships at: SubseriesView.swift:429 -->

Partial

<!-- END SOURCE: browser.volume.partial -->

*The badge on a volume’s row. The volume page’s header label now has a key of its own, as Planned’s does:*

<!-- SOURCE: FRUSExplorer/Browser/VolumeView.swift | key: browser.volume.partial.label | ships at: VolumeView.swift:459 -->

Partially Published

<!-- END SOURCE: browser.volume.partial.label -->

#### `graph.panel.close.a11y`

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.panel.close.a11y | ships at: CrossReferenceGraphView.swift:1241, ReferenceListPanel.swift:367, ReferenceListPanel.swift:559 | same text also in: FRUSExplorer/CrossReference/ReferenceListPanel.swift -->

Close details

<!-- END SOURCE: graph.panel.close.a11y -->

*The close button on the graph’s node panel had a second VoiceOver name stacked on it, “Close details panel”. It now has one name, like the reference list’s two close buttons.*

#### `series.geography.totals.title`

<!-- SOURCE: FRUSCoreKit/Analytics/Export/ChartInspectorAdapters.swift | key: series.geography.totals.title | ships at: ChartInspectorAdapters.swift:243, SeriesGeographyDashboard.swift:258, SeriesGeographyDashboard.swift:264 | same text also in: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift -->

Overall regional emphasis

<!-- END SOURCE: series.geography.totals.title -->

*The exported figure uses this title too: on the image, in the CSV’s “Figure:” line and in the file name. All three said “Volumes by region” before.*

#### `series.geography.trend.y`

<!-- SOURCE: FRUSCoreKit/Analytics/Export/ChartInspectorAdapters.swift | key: series.geography.trend.y | ships at: ChartInspectorAdapters.swift:221, SeriesGeographyDashboard.swift:218, SeriesGeographyDashboard.swift:247 | same text also in: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift -->

Share of volumes

<!-- END SOURCE: series.geography.trend.y -->

*Used for the chart’s axis title, the name of the value the chart plots, and the table and CSV column.*

#### `series.provenance.trend.y`

<!-- SOURCE: FRUSCoreKit/Analytics/Export/ChartInspectorAdapters.swift | key: series.provenance.trend.y | ships at: ChartInspectorAdapters.swift:410, ChartInspectorAdapters.swift:438, SourceProvenanceDashboard.swift:438, SourceProvenanceDashboard.swift:468 | same text also in: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift -->

Share of source notes

<!-- END SOURCE: series.provenance.trend.y -->

*Used for the chart’s axis title, the name of the value the chart plots, and the share column in the tables and CSVs of both the trend and the overall composition.*

#### `wordcloud.scope.corpus`

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.scope.corpus | ships at: WordCloudView.swift:2483, WordCloudView.swift:2623, WordCloudScopeResolver.swift:87 | same text also in: FRUSExplorer/Analytics/WordCloud/WordCloudScopeResolver.swift -->

Entire Corpus

<!-- END SOURCE: wordcloud.scope.corpus -->

*Used for the scope menu, the scope bar, the cloud’s header, a comparison column, and the export’s title and file name.*

#### `graph.resetView.a11y`

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.resetView.a11y | ships at: CrossReferenceGraphView.swift:1519 -->

Reset view

<!-- END SOURCE: graph.resetView.a11y -->

*“Reset View” never shipped under this key (three other graphs ship it under keys of their own). It was the example in a code comment in `ControlHelp.swift`, which now says “Reset view” too.*

#### The five keys found after the ten

*The new test found these five on 2026-09-30, after the ten above were settled. In each, iPhone and iPad showed one text and the Mac another. You settled them on 2026-10-01 with “all recommended”: one now has one text on both platforms, and in the other four the Mac’s text has a key of its own, ending `.mac`, beside the iPhone and iPad key.*

#### `document.crossref.download.message %@` and `document.crossref.download.message.mac %@`

*Two keys, each keeping its text. The alert for a link into a volume that is not downloaded offers View Connections on iPhone and iPad, and its message says so. The Mac’s alert offers Download Volume and Cancel only, so its message, “… Download it to open the document.”, now has the `.mac` key. Both blocks are in §18.10 of `08-Reading-Research-Collections.md`.*

#### `settings.hub.browse.corpus.detail`

*One text on both hubs, the iPhone and iPad one: the Mac’s size line for the entire corpus gained “Downloads run in the background and resume across launches.” The code bears that out on the Mac, which downloads through the same background transfer and keeps the volumes still waiting in its queue; it was not tried on a Mac, and a volume that is mid-download when the app quits comes back only if macOS kept that transfer going. Its one block is in §18.13 of this file.*

#### `personNotFound.dismiss` and `personNotFound.dismiss.mac`

<!-- SOURCE: FRUSExplorer/DocumentView/DocumentView.swift | DocumentView.personNotFoundSheet | lines: 1790–1791 | key: personNotFound.dismiss | shared: iOS (the Mac’s is personNotFound.dismiss.mac, the next block) | ships at: DocumentView.swift:1652 -->

Done

<!-- END SOURCE: personNotFound.dismiss -->

<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | MacDocumentView.body | lines: 337–337 | key: personNotFound.dismiss.mac | shared: macOS (a key of its own since #1483) | ships at: MacDocumentView.swift:331 -->

OK

<!-- END SOURCE: personNotFound.dismiss.mac -->

*What closes the notice that a person’s details are unavailable: the iPhone and iPad sheet’s Done, the Mac alert’s OK.*

#### `glossNotFound.dismiss` and `glossNotFound.dismiss.mac`

<!-- SOURCE: FRUSExplorer/DocumentView/DocumentView.swift | DocumentView.glossNotFoundSheet | lines: 1823–1824 | key: glossNotFound.dismiss | shared: iOS (the Mac’s is glossNotFound.dismiss.mac, the next block) | ships at: DocumentView.swift:1685 -->

Done

<!-- END SOURCE: glossNotFound.dismiss -->

<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | MacDocumentView.body | lines: 347–347 | key: glossNotFound.dismiss.mac | shared: macOS (a key of its own since #1483) | ships at: MacDocumentView.swift:341 -->

OK

<!-- END SOURCE: glossNotFound.dismiss.mac -->

*What closes the notice that a glossary term’s definition is unavailable: the iPhone and iPad sheet’s Done, the Mac alert’s OK.*

#### `menu.find.search` and `menu.find.search.mac`

<!-- SOURCE: FRUSExplorer/App/FRUSExplorerApp.swift | IOSFindMenuContent.body | lines: 4912–4912 | key: menu.find.search | shared: iOS (the Mac’s is menu.find.search.mac, the next block) | ships at: FRUSExplorerApp.swift:4393 -->

Search

<!-- END SOURCE: menu.find.search -->

<!-- SOURCE: FRUSExplorer/App/FRUSExplorerApp.swift | FindMenuContent.body | lines: 4384–4384 | key: menu.find.search.mac | shared: macOS (a key of its own since #1483) | ships at: FRUSExplorerApp.swift:3895 -->

Search…

<!-- END SOURCE: menu.find.search.mac -->

*The Find menu item that opens Search. In the keyboard menu on iPhone and iPad it switches to the Search tab and reads “Search”; on the Mac it opens the Search window, so it ends in an ellipsis.*

---
