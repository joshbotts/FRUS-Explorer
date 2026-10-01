# EditableContent — Reading, Research & Collections (and export method statements)

Part of the owner’s editing surface, `Docs/EditableContent/` (read `README.md` there first). Covers parts of §6, §10, §18.5, §18.10–§18.12, parts of §14. Every block’s text is what the app ships after lane WB wrote your 2026-09-30 review back (the build-49 wave); the ✎ boxes that listed your unlanded 2026-09-21 edits are gone, each adopted where you changed its block and dropped where you left it alone. Section numbers are the ones the single file used, so references like “§18’s rule” still point somewhere.

**In this file:** 283 blocks · no ⚑ wording issues

---

## 6. Settings, Tips & Collections (continued)

*The rest of §6 is in `09-Settings-and-App.md`.*

### Research Sessions

<!-- Settings ▸ Research ▸ Research Sessions. One view on both platforms. The recording footer still has TWO keys, but no longer for the original reason: the platforms once recorded into DIFFERENT stores (iOS wrote `.searchSubmit` session events, macOS wrote `SearchHistoryEntry`), and since Wave R-2a there is exactly one writer of each kind on both. What still differs is only what the surfaces are CALLED — macOS has the History window and Recents, iOS has the History screen plus Project Home's cards and tiles — so the two texts differ in their nouns and not in their substance.

This whole block was refreshed in Wave R-5. Every key below changed in R-2a, and this file had been left describing the R-1 wording, some of which had become false — see the per-entry notes. -->

#### Research-session recording footer (iOS)

<!-- Rewritten TWICE, each time under a NEW key, because no String Catalog ships and reusing a key with different text is a silent collision. R-1 replaced `settings.sessions.logging.footer` (which described a switch that governed the session log alone) with `…footer.trail`; R-4 replaced that with `…trail.v2` when iOS gained a `SearchHistoryEntry` writer; R-2a replaced THAT with `…trail.v3`, because sessions became derived rather than stored and exports joined the trail. The label stays "Log Research Sessions" (owner decision, R-0 Q3), so this footer carries the whole explanatory burden, including the behaviour change: History and Recents drain when the switch is off. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordingSection footer | lines: 189–190 | key: settings.sessions.logging.footer.trail.v3 | shared: iOS only (see the note above) -->

Despite the name, this switch covers everything the app can track about your work. That means the documents you open, the text of the searches you run, and the collections you export. The app keeps one record of each. The History screen, a project’s Recently Read and Recent Searches cards, its Documents Visited and Searches Run counts, and the Session Log all read those same records. The Session Log groups them into sessions, and a session ends after 30 minutes of inactivity. The records stay on this device, and in your private iCloud database if iCloud sync is on. Turn the switch off and all of that recording stops. Those surfaces will thin out and eventually empty. That is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it.

<!-- END SOURCE: settings.sessions.logging.footer.trail.v3 -->

#### Research-session recording footer (macOS)

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordingSection footer | lines: 186–187 | key: settings.sessions.logging.footer.trail.mac.v2 | shared: macOS only (see the note above) -->

Despite the name, this switch covers everything the app can track about your work. That means the documents you open, the text of the searches you run, and the collections you export. The app keeps one record of each. The History window, a project’s Recents, and the Session Log all read those same records. The Session Log groups them into sessions, and a session ends after 30 minutes of inactivity. The records stay on this device, and in your private iCloud database if iCloud sync is on. Turn the switch off and all of that recording stops. History and Recents will thin out and eventually empty. That is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it.

<!-- END SOURCE: settings.sessions.logging.footer.trail.mac.v2 -->

#### Recorded-activity footer (empty)

<!-- One key on both platforms since Wave R-2a. A macOS variant used to exist because the session log read `SessionEvent`, which macOS never wrote for a search — so "run a search" would have been a promise the Mac did not keep. The log is derived from `SearchHistoryEntry` now, of which macOS has always been a producer, so the fence is gone. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordedActivitySection footer | lines: 228–229 | key: settings.sessions.activity.footer.empty | shared: iOS+macOS (single edit point) -->

Nothing has been recorded yet. Open a document or run a search and it will appear here.

<!-- END SOURCE: settings.sessions.activity.footer.empty -->

#### Recorded-activity footer (non-empty)

<!-- Wave R-2a, NEW key. The R-1 text under `settings.sessions.activity.footer` said "No other part of the app reads this log — it is groundwork for a research-trail view." That was true of the `SessionEvent` store and became false the moment the log was derived from the same reading, search and export history the History surface and Project Home are built from. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordedActivitySection footer | lines: 235–236 | key: settings.sessions.activity.footer.derived | shared: iOS+macOS (single edit point) -->

The app infers sessions from the times you opened documents, ran searches, and exported collections. A gap of 30 minutes starts a new session. The same records fill the History screen and a project’s Recents.

<!-- END SOURCE: settings.sessions.activity.footer.derived -->

#### Delete-sessions footer

<!-- Wave R-2a, NEW key. The R-1 text under `settings.sessions.manage.footer.trail` ended "…and so does the reading and search history the switch above also governs — this button does not reach that." That gap is closed: sessions are derived from that history, so deleting sessions IS deleting it, and the button now calls `HistoryTrailAdmin.deleteAll`. Leaving the old sentence in place would have under-warned about an irreversible, CloudKit-propagating delete. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.manageSection footer | lines: 263–264 | key: settings.sessions.manage.footer.whole | shared: iOS+macOS (single edit point) -->

This deletes the whole record of your work: every document you opened, every search you ran, and every collection you exported. It goes from this device, and from your iCloud database if iCloud sync is on. Your notes, highlights, tags, and collections are not touched. To delete single entries instead, use the History screen.

<!-- END SOURCE: settings.sessions.manage.footer.whole -->

#### iCloud unavailable (Local Only) detail
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 239–240 | key: settings.icloud.localOnly.detail | shared: iOS only (the macOS status lives in the main window's status bar) -->

iCloud sync is unavailable. Notes, tags, and collections won’t sync across devices. Check that you are signed in to iCloud in Settings and that FRUS Explorer has iCloud access.

<!-- END SOURCE: settings.icloud.localOnly.detail -->

#### iCloud zone-missing detail
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 275–276 | key: settings.icloud.zoneMissing.detail | shared: iOS only (the macOS status lives in the main window's status bar) -->

The iCloud sync zone is missing. Data cannot upload or download until it is recreated. Force-quit and relaunch the app, or use Settings → Data & Recovery → Fix iCloud Sync.

<!-- END SOURCE: settings.icloud.zoneMissing.detail -->

---

#### Deleting one session — confirmation

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | lines: 150–151 | key: settings.sessions.delete.message.trail.v2 %@ -->

%@ will be permanently deleted from this device. If iCloud sync is on, the same records go from iCloud too. A session is made of every document you opened, every search you ran, and every collection you exported. Your notes, highlights, tags, and collections are not affected.

<!-- END SOURCE: settings.sessions.delete.message.trail.v2 %@ -->

---

### Document Change Banner (R-5 P2)

One shared banner above a document in both document views. Which sentence shows depends on the
recorded change (text, apparatus, gone) and on whether any stored highlight was made against an
earlier rendering. The first key is the pre-existing highlight hedge, now declared here only.

#### No recorded change, stale highlights
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeBanner.swift | lines: 104–105 | key: highlight.stale.warning | shared: iOS+macOS (single edit point) -->

Some highlights may be misaligned — the document has been updated since they were created.

<!-- END SOURCE: highlight.stale.warning -->

#### Text changed
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeBanner.swift | lines: 107–108 | key: document.changed.body | shared: iOS+macOS (single edit point) -->

The text of this document changed in a volume update. Highlight positions may have moved.

<!-- END SOURCE: document.changed.body -->

#### Text changed, stale highlights
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeBanner.swift | lines: 110–111 | key: document.changed.body.stale | shared: iOS+macOS (single edit point) -->

The text of this document changed in a volume update. Some highlights may be misaligned.

<!-- END SOURCE: document.changed.body.stale -->

#### Apparatus changed
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeBanner.swift | lines: 113–114 | key: document.changed.apparatus | shared: iOS+macOS (single edit point) -->

Footnotes, the source note, or the heading changed in a volume update. The text did not.

<!-- END SOURCE: document.changed.apparatus -->

#### Apparatus changed, stale highlights
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeBanner.swift | lines: 116–117 | key: document.changed.apparatus.stale | shared: iOS+macOS (single edit point) -->

Footnotes, the source note, or the heading changed in a volume update, and some highlights may be misaligned.

<!-- END SOURCE: document.changed.apparatus.stale -->

#### No longer in the volume
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeBanner.swift | lines: 119–120 | key: document.changed.vanished | shared: iOS+macOS (single edit point) -->

This document is no longer in the volume.

<!-- END SOURCE: document.changed.vanished -->

### Research — Changed by an update (R-5 P2)

#### Sidebar row
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | lines: 749–750 | key: research.sidebar.updated -->

Changed by an update

<!-- END SOURCE: research.sidebar.updated -->

#### Row line — text changed
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | lines: 1675–1676 | key: research.row.changed.body -->

Text changed in an update — highlight positions may have moved

<!-- END SOURCE: research.row.changed.body -->

#### Row line — apparatus changed
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | lines: 1678–1679 | key: research.row.changed.apparatus -->

Footnotes, source note, or heading changed in an update — the text did not

<!-- END SOURCE: research.row.changed.apparatus -->

#### Row line — gone
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | lines: 1665–1665 | key: research.row.changed.vanished -->

No longer in the volume

<!-- END SOURCE: research.row.changed.vanished -->

### Review Changes sheet (R-5 P3)

One shared sheet, opened from the change banner's *Review…* control in both document views and
from *Review Changes…* on a Research row. Lists what changed, every highlight with its standing
and its Confirm / Remove actions, and the other annotations the app cannot judge.

#### Banner control
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeBanner.swift | lines: 66–66 | key: document.changed.review | shared: iOS+macOS (single edit point) -->

Review…

<!-- END SOURCE: document.changed.review -->

#### Research row action
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | lines: 1157–1157 | key: research.action.reviewChanges -->

Review Changes…

<!-- END SOURCE: research.action.reviewChanges -->

#### Done
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 186–186 | key: document.review.done | shared: iOS+macOS (single edit point) -->

Done

<!-- END SOURCE: document.review.done -->

#### Loading
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 282–282 | key: document.review.loading | shared: iOS+macOS (single edit point) -->

Reading the change record…

<!-- END SOURCE: document.review.loading -->

#### What Changed — header
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 309–309 | key: document.review.change.header | shared: iOS+macOS (single edit point) -->

What Changed

<!-- END SOURCE: document.review.change.header -->

#### What Changed — vanished
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 285–286 | key: document.review.vanished | shared: iOS+macOS (single edit point) -->

This document is no longer in the volume — either a volume update removed it, or a change to how the app reads the volume no longer finds it. Everything you attached to it is kept until you remove it.

<!-- END SOURCE: document.review.vanished -->

#### What Changed — nothing recorded
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 293–294 | key: document.review.noChange | shared: iOS+macOS (single edit point) -->

No change to this document is recorded on this device.

<!-- END SOURCE: document.review.noChange -->

#### Mark Reviewed button
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 302–302 | key: document.review.markReviewed | shared: iOS+macOS (single edit point) -->

Mark Reviewed

<!-- END SOURCE: document.review.markReviewed -->

#### What Changed — footer
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 312–313 | key: document.review.change.footer.v2 | shared: iOS+macOS (single edit point) -->

Marking the document reviewed clears it from “Changed by an update”. With iCloud sync it reaches your other devices too, a few seconds after they next sync or when they next open. Highlights stay flagged until you confirm each one, and the next update re-opens the document if it changes again.

<!-- END SOURCE: document.review.change.footer.v2 -->

#### Highlights — header
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 325–325 | key: document.review.highlights.header | shared: iOS+macOS (single edit point) -->

Highlights

<!-- END SOURCE: document.review.highlights.header -->

#### Highlights — footer
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 327–328 | key: document.review.highlights.footer.v2 | shared: iOS+macOS (single edit point) -->

Confirm keeps a highlight exactly where it is and clears its warning everywhere you are signed in. Where the app can find the passage again it offers to move the highlight, showing you the words and what surrounds them — it never moves one on its own, and it never guesses when the words appear more than once.

<!-- END SOURCE: document.review.highlights.footer.v2 -->

#### Highlight with no stored passage
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 341–341 | key: document.review.highlight.noPassage | shared: iOS+macOS (single edit point) -->

Highlighted passage

<!-- END SOURCE: document.review.highlight.noPassage -->

#### Highlight — Confirm
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 368–368 | key: document.review.highlight.confirm | shared: iOS+macOS (single edit point) -->

Confirm

<!-- END SOURCE: document.review.highlight.confirm -->

#### Highlight — Remove
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 379–379 | key: document.review.highlight.remove | shared: iOS+macOS (single edit point) -->

Remove…

<!-- END SOURCE: document.review.highlight.remove -->

#### Highlight standing — orphaned
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1042–1043 | key: document.review.highlight.orphaned | shared: iOS+macOS (single edit point) -->

The document it was made on is no longer in the volume.

<!-- END SOURCE: document.review.highlight.orphaned -->

#### Highlight standing — aligned
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1047–1048 | key: document.review.highlight.aligned | shared: iOS+macOS (single edit point) -->

Matches the current text.

<!-- END SOURCE: document.review.highlight.aligned -->

#### Highlight standing — stale
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1050–1051 | key: document.review.highlight.stale | shared: iOS+macOS (single edit point) -->

Made against an earlier version of the text — its position may have moved.

<!-- END SOURCE: document.review.highlight.stale -->

#### Highlight standing — stale, no passage
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1053–1054 | key: document.review.highlight.stale.noPassage | shared: iOS+macOS (single edit point) -->

Made against an earlier version of the text, and the words it covered were not stored — it can only be checked by eye.

<!-- END SOURCE: document.review.highlight.stale.noPassage -->

#### Highlight standing — unverifiable
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1056–1057 | key: document.review.highlight.unverifiable | shared: iOS+macOS (single edit point) -->

This device has no record to compare it against.

<!-- END SOURCE: document.review.highlight.unverifiable -->

#### Other Annotations — header
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 581–581 | key: document.review.other.header | shared: iOS+macOS (single edit point) -->

Other Annotations

<!-- END SOURCE: document.review.other.header -->

#### Other Annotations — none
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 525–525 | key: document.review.other.none | shared: iOS+macOS (single edit point) -->

No other annotations on this document.

<!-- END SOURCE: document.review.other.none -->

#### Other Annotations — notes
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 512–513 | key: document.review.other.notes %lld | shared: iOS+macOS (single edit point) -->

%lld notes

<!-- END SOURCE: document.review.other.notes %lld -->

#### Other Annotations — tags
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 514–515 | key: document.review.other.tags %lld | shared: iOS+macOS (single edit point) -->

%lld tags

<!-- END SOURCE: document.review.other.tags %lld -->

#### Other Annotations — collections
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 516–517 | key: document.review.other.collections %lld | shared: iOS+macOS (single edit point) -->

in %lld collections

<!-- END SOURCE: document.review.other.collections %lld -->

#### Other Annotations — summaries
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 518–519 | key: document.review.other.summaries %lld | shared: iOS+macOS (single edit point) -->

%lld summaries

<!-- END SOURCE: document.review.other.summaries %lld -->

#### Other Annotations — visit plan
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 520–521 | key: document.review.other.visit | shared: iOS+macOS (single edit point) -->

in an archive-visit plan

<!-- END SOURCE: document.review.other.visit -->

#### Other Annotations — footer
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 589–590 | key: document.review.other.footer.v3 | shared: iOS+macOS (single edit point) -->

These carry no position in the text, so the app cannot judge them against the change — it can take you to them, and it can summarize the document again. Review them by eye; a summary describes the text as it was when it was written, and the app cannot tell you which of these predate the correction.

<!-- END SOURCE: document.review.other.footer.v3 -->

#### Other Annotations — footer when no summary can be made
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 592–593 | key: document.review.other.footer.noSummarizer.v3 | shared: iOS+macOS (single edit point) -->

These carry no position in the text, so the app cannot judge them against the change — it can only take you to them. Review them by eye; a summary describes the text as it was when it was written, and the app cannot tell you which of these predate the correction.

<!-- END SOURCE: document.review.other.footer.noSummarizer.v3 -->

#### Other Annotations — make another summary
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 664–665 | key: document.review.other.summarizeAgain | shared: iOS+macOS (single edit point) -->

Summarize Again

<!-- END SOURCE: document.review.other.summarizeAgain -->

#### Other Annotations — Summarize Again will substitute a prompt
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 653–654 | key: document.review.summarizeAgain.fallback %@ | shared: iOS+macOS (single edit point) -->

Summarize Again will use “%@” — the prompt that made the newest summary is no longer on this device.

<!-- END SOURCE: document.review.summarizeAgain.fallback %@ -->

#### Other Annotations — a new summary was added
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 749–750 | key: document.review.other.summarizeAgain.done | shared: iOS+macOS (single edit point) -->

A new summary was added. The earlier ones are kept — step through them in the document’s Summary panel.

<!-- END SOURCE: document.review.other.summarizeAgain.done -->

#### Other Annotations — Edit Tags
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 555–556 | key: document.review.other.editTags | shared: iOS+macOS (single edit point) -->

Edit Tags…

<!-- END SOURCE: document.review.other.editTags -->

#### Other Annotations — a note with nothing written in it yet
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 872–872 | key: document.review.other.note.untitled | shared: iOS+macOS (single edit point) -->

Open note

<!-- END SOURCE: document.review.other.note.untitled -->

#### Other Annotations — open an archive-visit plan
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 570–571 | key: document.review.other.openPlan %@ | shared: iOS+macOS (single edit point) -->

Open the plan “%@”

<!-- END SOURCE: document.review.other.openPlan %@ -->

#### Other Annotations — closing the plan editor
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 245–246 | key: document.review.other.plan.done | shared: iOS only — #1462: the Mac opens the plan in the Archives Visits window, not this sheet -->

Done

<!-- END SOURCE: document.review.other.plan.done -->

### Research rail — the Document tools popover (#1351)

The rail header's ⓘ button opens a **Document tools** popover: a heading, then one row per tile in
the order the tiles appear, then the classification section below. Each tile's two strings are
written once, in `RailTileCopy`, and each is shown in more than one place: the caption is the tile's
label, its VoiceOver name, its iOS Large Content Viewer title and the bold title of its row in this
popover; the sentence is the tile's macOS tooltip, its iOS VoiceOver hint and the text of that row.
An edit here changes every one of those — except the **Share** tile on iOS, which is a menu with its
own VoiceOver name and hint (`document.toolbar.share` and `document.toolbar.share.help`). There the
Share caption below is only the visible label and the popover row's title, and the Share sentence
only the popover row, so renaming it without editing those two — the last two blocks in this section
— leaves VoiceOver saying something else.
The heading is also the ⓘ button's VoiceOver name and its macOS tooltip. The **On the Map** tile's caption and sentence are in §13.4 ("Research-rail tile" and
"Research-rail tile help"); this section does not repeat them, because two blocks for one key would
be two places to edit one string.

#### The popover's heading
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | ResearchRailView.toolsInfoHeading | lines: 343–343 | key: researchRail.tools.info.heading | shared: iOS+macOS (single edit point) -->

Document tools

<!-- END SOURCE: researchRail.tools.info.heading -->

#### Cite — the tile's caption
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.cite | lines: 1070–1070 | key: researchRail.tile.cite | shared: iOS+macOS (single edit point) -->

Cite

<!-- END SOURCE: researchRail.tile.cite -->

#### Cite — what the tile does
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.cite | lines: 1071–1072 | key: researchRail.tile.cite.help | shared: iOS+macOS (single edit point) -->

Cite this document — copy a formatted citation or export BibTeX/RIS

<!-- END SOURCE: researchRail.tile.cite.help -->

#### Word Cloud — the tile's caption
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.wordCloud | lines: 1077–1077 | key: researchRail.tile.wordCloud | shared: iOS+macOS (single edit point) -->

Word Cloud

<!-- END SOURCE: researchRail.tile.wordCloud -->

#### Word Cloud — what the tile does
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.wordCloud | lines: 1078–1079 | key: researchRail.tile.wordCloud.help | shared: iOS+macOS (single edit point) -->

Show a word cloud of this document’s most frequent terms

<!-- END SOURCE: researchRail.tile.wordCloud.help -->

#### Sources — the tile's caption
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.sources | lines: 1084–1084 | key: researchRail.tile.sources | shared: iOS+macOS (single edit point) -->

Sources

<!-- END SOURCE: researchRail.tile.sources -->

#### Sources — what the tile does
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.sources | lines: 1085–1086 | key: researchRail.tile.sources.help | shared: iOS+macOS (single edit point) -->

Resolve this document’s source note in the NARA Catalog or RG-59 records

<!-- END SOURCE: researchRail.tile.sources.help -->

#### Graph — the tile's caption
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.graph | lines: 1091–1091 | key: researchRail.tile.graph | shared: iOS+macOS (single edit point) -->

Graph

<!-- END SOURCE: researchRail.tile.graph -->

#### Graph — what the tile does
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.graph | lines: 1092–1093 | key: researchRail.tile.graph.help | shared: iOS+macOS (single edit point) -->

Show this document’s cross-reference graph

<!-- END SOURCE: researchRail.tile.graph.help -->

#### Related — the tile's caption
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.related | lines: 1098–1098 | key: researchRail.tile.related | shared: iOS+macOS (single edit point) -->

Related

<!-- END SOURCE: researchRail.tile.related -->

#### Related — what the tile does
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.related | lines: 1099–1100 | key: researchRail.tile.related.help | shared: iOS+macOS (single edit point) -->

Find related documents by archival provenance, cross-references, date, and shared people

<!-- END SOURCE: researchRail.tile.related.help -->

#### Share — the tile's caption
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.share | lines: 1105–1105 | key: researchRail.tile.share | shared: iOS+macOS (single edit point) -->

Share

<!-- END SOURCE: researchRail.tile.share -->

#### Share — what the tile does
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | RailTileCopy.share | lines: 1106–1107 | key: researchRail.tile.share.help | shared: iOS+macOS (single edit point) -->

Share or export this document

<!-- END SOURCE: researchRail.tile.share.help -->

#### Share (iOS) — the menu's VoiceOver name
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentView.swift | DocumentShareMenu | lines: 2247–2247 | key: document.toolbar.share | shared: iOS only -->

Share

<!-- END SOURCE: document.toolbar.share -->

#### Share (iOS) — the menu's VoiceOver hint
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentView.swift | DocumentShareMenu | lines: 2248–2249 | key: document.toolbar.share.help | shared: iOS only -->

Send this document to your Zotero library, export a Zotero file, or share its citation

<!-- END SOURCE: document.toolbar.share.help -->

### Research rail — the classification disagreement (R-5 P3b-5)

The one sentence the rail prints when a reader has reclassified a document. It was never mirrored
here, and R-5 P3b-5 is the phase that made it truthful: the value it names used to come from a
snapshot frozen on the day of the correction, so once the Office of the Historian fixed the same
mistag the app went on quoting the old reading — and the Undo beside it put that old reading back
into the index. Both now read FRUS's parse as it stands.

#### When FRUS adopts the reader's correction
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 1188–1189 | key: panel.classification.overrideNowRedundant | shared: iOS+macOS (single edit point) -->

FRUS now tags this the same way, so your correction no longer changes anything. You can restore FRUS’s classification.

<!-- END SOURCE: panel.classification.overrideNowRedundant -->

#### FRUS's own tagging, beside the reader's correction
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 1191–1192 | key: panel.classification.overridden %@ | shared: iOS+macOS (single edit point) -->

FRUS tags this as %@ — reclassified by you.

<!-- END SOURCE: panel.classification.overridden %@ -->

#### The inline noun for an editorial note
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 1194–1195 | key: panel.classification.note.inline | shared: iOS+macOS (single edit point) -->

an editorial note

<!-- END SOURCE: panel.classification.note.inline -->

#### The inline noun for a document
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 1196–1197 | key: panel.classification.document.inline | shared: iOS+macOS (single edit point) -->

a document

<!-- END SOURCE: panel.classification.document.inline -->

### Review Changes sheet — finding a moved passage (R-5 P3b-3)

When a correction moves the text under a highlight, the sheet looks for the exact words the
reader stored and, if it finds them in one place, offers to move the highlight there. These
are the sentences it uses. None of them may claim the passage was deleted: about half of what
a real correction changes is renumbering, where the document id now names a different
document and the passage is elsewhere rather than gone.

#### Move button
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 358–358 | key: document.review.highlight.move | shared: iOS+macOS (single edit point) -->

Move Here

<!-- END SOURCE: document.review.highlight.move -->

#### Found, unmoved
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1016–1017 | key: document.review.search.here | shared: iOS+macOS (single edit point) -->

Found once, still in this position.

<!-- END SOURCE: document.review.search.here -->

#### Found at a new position
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1019–1020 | key: document.review.search.moved | shared: iOS+macOS (single edit point) -->

Found once, at a new position in the corrected text.

<!-- END SOURCE: document.review.search.moved -->

#### Found far away
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1022–1023 | key: document.review.search.far | shared: iOS+macOS (single edit point) -->

Found once, but far from where it was. This can mean the document was renumbered and this one is not the same document — check it before moving anything by hand.

<!-- END SOURCE: document.review.search.far -->

#### Not found
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1025–1026 | key: document.review.search.notFound | shared: iOS+macOS (single edit point) -->

Not found in the current text. The passage may have been edited, or this document may have been renumbered.

<!-- END SOURCE: document.review.search.notFound -->

#### Found more than once
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1028–1029 | key: document.review.search.ambiguous %lld | shared: iOS+macOS (single edit point) -->

Found %lld times, so the app cannot tell which one is yours.

<!-- END SOURCE: document.review.search.ambiguous %lld -->

#### Too short to search
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 1032–1033 | key: document.review.search.tooShort.v2 | shared: iOS+macOS (single edit point) -->

Too short to look for: a passage this brief can repeat, so finding it once would not prove anything.

<!-- END SOURCE: document.review.search.tooShort.v2 -->

### AI summaries — the prompt a regeneration runs (R-5 P3b-6)

A summary is made with a PROMPT, and until now neither surface said which. macOS printed
“· custom prompt” beside every summary, including the standard-prompt ones, and its Regenerate ran
whichever prompt happened to be oldest — so regenerating a summary made with a prompt of your own
quietly produced one in a different voice. iOS had no regenerate control at all.

Both now name the prompt that MADE the summary, and regenerate with it. A substitute is never
printed as provenance: if the prompt has been deleted, both surfaces say which one Regenerate will
use instead, before it is pressed.

**Read the `shared:` line on each block below.** Most of these strings live in a `#if os(macOS)`
file and exist on that platform alone; three are declared on BOTH surfaces, at two call sites, and
editing one of those without the other makes the twins describe one summary two different ways.

#### The AI-summary badge
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 163–163 | key: summary.block.label | shared: macOS only -->

AI summary

<!-- END SOURCE: summary.block.label -->

#### The prompt that made this summary
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 177–178 | key: summary.block.prompt %@ | shared: iOS+macOS (declared in BOTH — edit both call sites) -->

· %@

<!-- END SOURCE: summary.block.prompt %@ -->

#### Change prompt
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 195–196 | key: summary.block.changePrompt | shared: macOS only -->

Change prompt

<!-- END SOURCE: summary.block.changePrompt -->

#### Regenerate
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 208–209 | key: summary.block.regenerate | shared: iOS+macOS (declared in BOTH — edit both call sites) -->

Regenerate

<!-- END SOURCE: summary.block.regenerate -->

#### No prompt to summarize with
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 227–228 | key: summary.block.noPrompt | shared: macOS only -->

No summarization prompt is available. Add one in Settings ▸ Research ▸ Summarization.

<!-- END SOURCE: summary.block.noPrompt -->

#### Regenerate will substitute a prompt
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 234–235 | key: summary.block.regenerate.fallback %@ | shared: iOS+macOS (declared in BOTH — edit both call sites) -->

Regenerate will use “%@” — the prompt that made this summary is no longer on this device.

<!-- END SOURCE: summary.block.regenerate.fallback %@ -->

#### Where you are in the summary history
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 125–126 | key: summary.history.position %lld %lld | shared: macOS only -->

%lld/%lld

<!-- END SOURCE: summary.history.position %lld %lld -->

#### Where you are in the summary history — spoken
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 131–132 | key: summary.history.position.a11y %lld %lld | shared: macOS only -->

Summary %lld of %lld

<!-- END SOURCE: summary.history.position.a11y %lld %lld -->

#### Regenerate — spoken
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentView.swift | lines: 2553–2554 | key: summary.block.regenerate.a11y | shared: iOS only -->

Regenerate this summary

<!-- END SOURCE: summary.block.regenerate.a11y -->

### Review Changes sheet — quotations (R-5 P3b-4)

An excerpt is a copy, not a pointer: the passage was frozen into its collection when it was
captured and renders from that copy, so a correction cannot change what it prints. What a
correction can change is whether those words are still in the record the quotation cites. Each
row therefore says up to two independent things — always what an exact search of the current
text found, and, when there is something to report, which version of the text the quotation was
taken from. The version line is deliberately SILENT when the quotation was taken from the text as
it now reads, and when the sheet has no current version to compare against: a row that speaks is
a row saying something real. The two sentences must never read as though the app were
contradicting itself, and neither mentions the other's subject.

Absence of a version is NOT staleness. A quotation taken from a footnote carries no version at
all, because a footnote selection reports text without offsets, and it is perfectly checkable;
its sentence has to say how it was taken, never that something moved.

#### Quotations — header
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 427–427 | key: document.review.excerpts.header | shared: iOS+macOS (single edit point) -->

Quotations

<!-- END SOURCE: document.review.excerpts.header -->

#### Quotations — footer
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 429–430 | key: document.review.excerpts.footer | shared: iOS+macOS (single edit point) -->

A quotation is a copy, so a correction cannot change what it prints — what it can change is whether those words are still in the record it cites. This is the same check that runs when a collection is exported, and it reads the whole document, footnotes included. So a quotation can be affected by a correction described above as touching only the notes, and a quotation can fail this check for reasons older than any correction. Nothing here edits or removes a quotation: it belongs to its collection, and the collection editor is where you change it.

<!-- END SOURCE: document.review.excerpts.footer -->

#### Quotation — checking
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift | lines: 461–462 | key: document.review.excerpt.checking | shared: iOS+macOS (single edit point) -->

Checking this quotation against the current text…

<!-- END SOURCE: document.review.excerpt.checking -->

#### Quotation — found
<!-- SOURCE: FRUSExplorer/DocumentView/ExcerptReview.swift | lines: 155–156 | key: document.review.excerpt.verified | shared: iOS+macOS (single edit point) -->

These words are still in the document as it reads now.

<!-- END SOURCE: document.review.excerpt.verified -->

#### Quotation — not found
<!-- SOURCE: FRUSExplorer/DocumentView/ExcerptReview.swift | lines: 158–159 | key: document.review.excerpt.notFound | shared: iOS+macOS (single edit point) -->

These words are not in the document as it reads now. The passage may have been corrected, or this document may have been renumbered and this one may not be the same document.

<!-- END SOURCE: document.review.excerpt.notFound -->

#### Quotation — the document is gone
<!-- SOURCE: FRUSExplorer/DocumentView/ExcerptReview.swift | lines: 161–162 | key: document.review.excerpt.vanished | shared: iOS+macOS (single edit point) -->

The document is no longer in the volume, so there is nothing to check the quotation against.

<!-- END SOURCE: document.review.excerpt.vanished -->

#### Quotation — no indexed text to check against
<!-- SOURCE: FRUSExplorer/DocumentView/ExcerptReview.swift | lines: 167–168 | key: document.review.excerpt.notIndexed.v2 | shared: iOS+macOS (single edit point) -->

There is no indexed text for this document on this device, so the quotation could not be checked.

<!-- END SOURCE: document.review.excerpt.notIndexed.v2 -->

#### Quotation — too short to check
<!-- SOURCE: FRUSExplorer/DocumentView/ExcerptReview.swift | lines: 170–171 | key: document.review.excerpt.inconclusive | shared: iOS+macOS (single edit point) -->

Too short, or too heavily elided, to check: a fragment this brief appears in too many documents to prove anything.

<!-- END SOURCE: document.review.excerpt.inconclusive -->

#### Quotation — captured from an earlier version
<!-- SOURCE: FRUSExplorer/DocumentView/ExcerptReview.swift | lines: 186–187 | key: document.review.excerpt.capturedEarlier | shared: iOS+macOS (single edit point) -->

Captured from an earlier version of the text.

<!-- END SOURCE: document.review.excerpt.capturedEarlier -->

#### Quotation — captured with no version recorded
<!-- SOURCE: FRUSExplorer/DocumentView/ExcerptReview.swift | lines: 189–190 | key: document.review.excerpt.capturedUnversioned | shared: iOS+macOS (single edit point) -->

Captured without a record of which version of the text it came from.

<!-- END SOURCE: document.review.excerpt.capturedUnversioned -->

### The excerpt check on export (M-3, unmirrored until R-5 P3b-4)

The same verifier, reporting on a whole collection in the export sheet. These six sentences
shipped with M-3 and P3b-1 and had never been mirrored here, so their wording could not be
edited from this file. The order they appear in is deliberate: failures lead, because they are
the only category saying something is wrong with the work; the rest are stated as limits on the
check rather than as problems with the quotations.

#### Export check — one quotation not found
<!-- SOURCE: FRUSExplorer/Export/ExcerptVerifier.swift | lines: 297–298 | key: excerpt.verify.failures.one | shared: iOS+macOS (single edit point) -->

One quotation was not found in the document it cites.

<!-- END SOURCE: excerpt.verify.failures.one -->

#### Export check — several not found
<!-- SOURCE: FRUSExplorer/Export/ExcerptVerifier.swift | lines: 299–300 | key: excerpt.verify.failures.many %lld | shared: iOS+macOS (single edit point) -->

%lld quotations were not found in the documents they cite.

<!-- END SOURCE: excerpt.verify.failures.many %lld -->

#### Export check — one document removed by an update
<!-- SOURCE: FRUSExplorer/Export/ExcerptVerifier.swift | lines: 304–305 | key: excerpt.verify.vanished.one | shared: iOS+macOS (single edit point) -->

One quotation cites a document that is no longer in its volume.

<!-- END SOURCE: excerpt.verify.vanished.one -->

#### Export check — several documents removed by an update
<!-- SOURCE: FRUSExplorer/Export/ExcerptVerifier.swift | lines: 306–307 | key: excerpt.verify.vanished.many %lld | shared: iOS+macOS (single edit point) -->

%lld quotations cite documents that are no longer in their volumes.

<!-- END SOURCE: excerpt.verify.vanished.many %lld -->

#### Export check — volumes not downloaded
<!-- SOURCE: FRUSExplorer/Export/ExcerptVerifier.swift | lines: 310–311 | key: excerpt.verify.unindexed %lld | shared: iOS+macOS (single edit point) -->

%lld could not be checked — their volumes are not downloaded.

<!-- END SOURCE: excerpt.verify.unindexed %lld -->

#### Export check — too short to check
<!-- SOURCE: FRUSExplorer/Export/ExcerptVerifier.swift | lines: 314–315 | key: excerpt.verify.inconclusive %lld | shared: iOS+macOS (single edit point) -->

%lld were too short to check.

<!-- END SOURCE: excerpt.verify.inconclusive %lld -->

### Collections Export

#### Native-format export explanation
<!-- SOURCE: FRUSExplorer/Collections/CollectionExportSheet.swift | CollectionExportSheet.nativeShareOptions | lines: 604–605 | key: export.native.hint | shared: iOS+macOS (single edit point) -->

Shares an editable copy of this collection: its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don’t have. Your research notes stay private unless you include them above.

<!-- END SOURCE: export.native.hint -->

Note: the apostrophe in "don’t" is a curly quote (U+2019), copied verbatim from source.

---

*End of editable content. Source locations span the About screen (§1), Onboarding (§2),
the 11-page Research Guide (§3), the four Series-analytics dashboards (§4), the analytics
captions & info popovers (§5), and the Settings / tips / Collections prose (§6). Annotations
were re-pinned to current source lines in the 2026-07 source→doc refresh; §1 gained the
FRUS Explorer license notice (§1.3) and §6 the word-cloud precompute footer — strings added
to the app after the previous revision. Blocks marked `shared: iOS+macOS` are a single edit
point (one localization key, or the shared FRUSTheme static) — there is no separate platform
duplicate to hunt for.*

*Reconciliation to do during revision: the Corpus Analytics popover's Multiple words and Phrases
rows (§5) overlap the Search Tips rows (§7.13), which both Search surfaces render from one model
— when either is revised, align the other (#1299 aligned them). The Research Guide's search page
no longer carries syntax wording to align with. Still open: add the Guide's "finding aid, not
evidence" caveat to the Word Cloud popover (§5) so the two surfaces don't drift.*

---

## 10. Export Method Statements

*Every analytics figure and table that leaves the app carries a methods statement above its numbers — a `#`-commented preamble on a CSV, a printed block on a figure plate. This is the prose a reader sees when the file has traveled without the app, so it has to stand alone. §5 already carries the corpus, Person, Cross-Reference and Word Cloud statements; the Archival and About-the-Series ones are new here.*

---

### 10.1 Archival Analytics

#### The sentence every archival export carries

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 62–63 | key: archival.export.caveat.base -->

Method: these figures come from the source note on each published FRUS document. That note is the citation naming where the editors found the archival original. They record where the editors drew documents from, not what the archives themselves hold. Collections are grouped across volumes by name. When two spellings of one name fail to merge, a single body of records appears twice under nearby names.

<!-- END SOURCE: archival.export.caveat.base -->

---

#### The pointers exports' own base sentence

*A separate base, not an appended correction: `archival.export.caveat.base` above describes work a
pointers (unprinted-references) export did not do — those figures are parsed from editorial
footnotes, not source notes. Two contradictory methods statements in one file would leave the
reader trusting the first, so the pointers exports swap the base out entirely.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | pointerBaseCaveat | lines: 365–366 | key: archival.export.caveat.base.pointers -->

These figures are parsed from the editorial footnotes of published FRUS documents, not from the source notes that record where those documents came from, and not from an archive’s catalog. They count references pointing at material the editors did not print. A reference is an annotation practice, so the figures describe how FRUS annotated its volumes rather than a relation between archives.

<!-- END SOURCE: archival.export.caveat.base.pointers -->

---

#### The class lens's grain sentence

*Stamped when the export ranks central-file classes (#826, owner decision D-3): decimal rows stand
for themselves, subject-numeric rows are folded to category+number. The sentence exists because the
fold hides the designator a reader writes on a pull slip — it says the fold happened and points at
the app's leaf listing. The POL 27 example is the explanation; keep a concrete pair.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | grainCaveat | lines: 74–75 | key: archival.export.caveat.grain -->

Grain: central-file rows are one unit deep. A decimal file number (763.72) stands for itself; subject-numeric designators are grouped to their category and number (POL 27 VIET S and POL 27 ARAB-ISR both count under POL 27), because at full length half of them carry a single document. A grouped row’s own leaves, with their counts, are listed under the chart in the app. A volume citing two designators in one group counts once for the group.

<!-- END SOURCE: archival.export.caveat.grain -->

---

#### Why the three weights disagree

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 353–354 | key: archival.export.caveat.weight.v2 -->

The three weights count different things. A document counts only when its own source note names the collection. A volume counts when either its front matter or any document source note names the collection. So a collection named only in front matter has volumes but no documents. Unprinted pointers counts neither: it counts footnotes naming material FRUS did not print, and is never added to the other two. Switching the weight changes which collections appear in the ranking, not just their order.

<!-- END SOURCE: archival.export.caveat.weight.v2 -->

> Same string also in §14 (Archival analytics — the three weights) — edit one copy only.

---

#### Why an era can look empty

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 371–372 | key: archival.export.caveat.coverage -->

Coverage is uneven by era. Named collections are scarce before 1948, where central-file classes carry almost the whole record. Classes all but disappear after 1976, where the presidential libraries carry it. A thin ranking usually means you have the wrong unit selected, not a thin era.

<!-- END SOURCE: archival.export.caveat.coverage -->

---

#### Collections ranking — what the era covers

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 113–114 | key: archival.export.caveat.scope.v2 %@ %@ -->

Scope: %1$@ in this era, and %2$@ ranked in all under the current weight. *(Interpolated with each count and its noun, grouped and singular at one (#1478, your close-out answer): %1$@ is the era’s volumes — “1 volume”, “120 volumes”; %2$@ is the units the ranking ranks, in the unit lens’s own noun, the forms the on-screen ranking caption uses — “1 collection”, “3,665 collections”, “1 class”, “5,893 classes”. “In all” because the count is not this table’s rows: the ranking card’s CSV lists at most 12, and the count leaves out a withheld Central Files umbrella, which the Withheld sentence states.)*

<!-- END SOURCE: archival.export.caveat.scope.v2 %@ %@ -->

---

#### Collections ranking — what the umbrella filter withheld

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 103–104 | key: archival.export.caveat.umbrella %@ -->

Withheld: this ranking leaves out the Central Files umbrella record. On its own it accounts for %@ in this era, and its bar would flatten the scale. The era-specific Central Files records are still included. *(Interpolated with the umbrella's count in the Count-by weight's own words — “12,067 documents”, “1 volume” — grouped and singular at one (#1374).)*

<!-- END SOURCE: archival.export.caveat.umbrella %@ -->

---

#### Cited Over Time export — what the bars count

*#1478, your close-out answer: the sentence no longer counts the eras (the table beside it has a row for each, and a chart needs two or more), and its last sentences give the buckets as the chart draws them — decades through 1940, three groupings to 1954, FRUS’s own subseries from 1955.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 217–218 | key: archival.export.caveat.timeline.v2 -->

Scope: the whole published series, not this device’s library. Each bar counts the volumes in one coverage era whose front matter or document source notes name this collection — volumes, not documents, so a volume citing it once counts the same as a volume built on it. The eras run contiguously from the first era that cites it to the last, so an interior gap is a real gap. From 1955 on, the buckets are FRUS’s own subseries rather than decades, because a decade axis splits a published subseries across two bars. Earlier years are grouped: by decade before 1941, then 1941–1947, 1948–1950 and 1951–1954.

<!-- END SOURCE: archival.export.caveat.timeline.v2 -->

---

#### Network — what a link means

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 272–273 | key: archival.export.caveat.network.grain -->

What a link means: two collections are linked because the same volumes drew on both. Each document carries exactly one source note, so no document can cite two collections. The shared-documents measure takes, for each volume the two share, the smaller of their two document counts, and sums them. It does not count documents citing both. A blank Jointly supplied documents cell means the count is unknown, not zero: no document source note resolves to one of the two collections, or the document-usage index could not be loaded.

<!-- END SOURCE: archival.export.caveat.network.grain -->

---

#### Network — what the table lists

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 275–276 | key: archival.export.caveat.network.scope %lld %lld %lld -->

Scope: this table lists %1$lld of the %2$lld units above the current threshold. In all, %3$lld collections share two or more volumes with the focus. The graph draws at most six per custodian so each quadrant stays readable. This table lists exactly what the graph drew.

<!-- END SOURCE: archival.export.caveat.network.scope %lld %lld %lld -->

---

#### Flows — the footnote share, stated first

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 313–314 | key: archival.export.caveat.flows.footnotes %@ -->

Read this first: %@ of these references are footnotes. A row describes how the editors annotated. While annotating material from one collection, they pointed the reader to material from another. It is not a relationship between the archives themselves.

<!-- END SOURCE: archival.export.caveat.flows.footnotes %@ -->

---

#### Flows — coverage and the absence of dates

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 317–318 | key: archival.export.caveat.flows.coverage %lld %lld -->

Coverage: only %1$lld of the %2$lld volumes in the series contribute any of these references. The cross-reference style they come from postdates 1945. The figures carry no dates: the stored data is a pair of archival units and a count. You cannot narrow this view to a period.

<!-- END SOURCE: archival.export.caveat.flows.coverage %lld %lld -->

---

#### Flows — why the class axis is excluded

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 321–322 | key: archival.export.caveat.flows.classes %lld %lld -->

Excluded: central-file classes. Between them the whole series carries %1$lld references over %2$lld pairs — under two per pair — which is too thin to rank, and there are no labels to rank it with.

<!-- END SOURCE: archival.export.caveat.flows.classes %lld %lld -->

---

#### Flows — same-unit references

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 328–329 | key: archival.export.caveat.flows.sameUnit %lld -->

Excluded: %lld references from this collection to itself. A hand-off to yourself is not a hand-off, but the figure is stated so the exclusion is visible.

<!-- END SOURCE: archival.export.caveat.flows.sameUnit %lld -->

---

#### Flows, unprinted material — what a row claims

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 292–293 | key: archival.export.caveat.flows.unprinted.claim %lld %lld -->

Read this first: every row is an editorial footnote naming archival material FRUS did not print. A row says the editors, working on material from one collection, told the reader that something unprinted is in another. It is not a relationship between the archives and not a count of documents held anywhere. %1$lld citations were found; %2$lld matched a known collection.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.claim %lld %lld -->

---

#### Flows, unprinted material — scope

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 296–297 | key: archival.export.caveat.flows.unprinted.scope %lld %lld -->

Scope: State Department lot files, presidential-library collections, and central-file numbers. The first two are post-1945 ways of filing; the third is how the earlier volumes cite, which is why they were nearly absent from this measure until it was added. Most central-file citations name the citing document’s own file rather than another — about three in five — so they are counted but are not movement between archives. %1$lld of the %2$lld volumes in the series contribute a row.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.scope %lld %lld -->

---

#### Flows, unprinted material — method

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 300–301 | key: archival.export.caveat.flows.unprinted.ibid %@ -->

Method: %@ of these citations come from an “Ibid.” — the archive is named once and referred back to. The app follows that back the way a reader would; it is a reading, not a quotation.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.ibid %@ -->

---

#### Flows, unprinted material — coverage span

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 306–307 | key: archival.export.caveat.flows.unprinted.era %lld %lld -->

Coverage span: the contributing volumes cover %1$lld to %2$lld.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.era %lld %lld -->

---

---

#### Your Library — what these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 246–247 | key: archival.export.caveat.library %lld %lld %lld -->

Scope: counted from what you have indexed on this device. That is %1$lld source notes across the %2$lld indexed volumes that carry them, out of %3$lld volumes in the series. These figures change as you index more volumes. Do not compare them with the figures for the whole series.

<!-- END SOURCE: archival.export.caveat.library %lld %lld %lld -->

---

#### Your Library — what a source note is

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 250–251 | key: archival.export.caveat.notes -->

Unit: a source note is not a document. Only documents whose editors recorded where the original was found are counted, so this total is smaller than the indexed document count.

<!-- END SOURCE: archival.export.caveat.notes -->

---

### 10.2 The four About-the-Series dashboards

*One builder per dashboard in `SeriesAnalyticsExport.swift`. Three of the four never read a document's date, so each states its own dating rule rather than inheriting the corpus one — that is what these `dating` blocks are.*

#### What corpus these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 42–43 | key: series.export.caveat.corpus %lld -->

Corpus: these figures come from a data file that ships with the app and covers all %lld cataloged volumes of the series. They do not depend on which volumes you have indexed on this device. Every device shows the same numbers, and they are available before you download anything.

<!-- END SOURCE: series.export.caveat.corpus %lld -->

---

#### When a subseries scope is active

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 52–53 | key: series.export.caveat.scope %@ -->

Scoped to %@ — every figure below is recomputed from that subset’s volumes alone and is not comparable with a whole-series export.

<!-- END SOURCE: series.export.caveat.scope %@ -->

---

#### Production & timeliness — dating rule

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 75–76 | key: series.export.dating.production -->

Dating: no document date is read. A volume sits at its print year, taken from the publication-date in its TEI header. Its publication lag is that print year minus the last year of the coverage range in the same header. Neither figure is derived from the dates of the volume’s own documents.

<!-- END SOURCE: series.export.dating.production -->

---

#### Geographic emphasis — dating rule

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 96–97 | key: series.export.dating.geography -->

Dating: no document date is read. A volume is placed by the coverage range declared in its TEI header. Its regions come from the volume’s own subject tags. So these figures count volumes concerned with a region, not documents about it.

<!-- END SOURCE: series.export.dating.geography -->

---

#### Archival sourcing — dating rule

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 146–147 | key: series.export.dating.provenance -->

Dating: no document date is read. Each source note sits in the coverage decade of the volume that printed it, taken from that volume’s declared date range. The trend starts around 1900. Earlier volumes are published correspondence and carry no archival source notes.

<!-- END SOURCE: series.export.dating.provenance -->

---

#### Archival sourcing — what a source note is

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 133–134 | key: series.export.caveat.provenanceNotes %lld -->

Unit: %lld parsed source notes. A source note is the citation naming where a document’s archival original was found. “Other / Unclassified” means a citation the parser could not classify, not a missing note.

<!-- END SOURCE: series.export.caveat.provenanceNotes %lld -->

---

#### Archival sourcing — when categories are hidden

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 128–129 | key: series.export.caveat.hiddenCategories %@ -->

Re-based: %@ are hidden, and every share in this table is a share of the categories shown rather than of all source notes. A decade with nothing in any shown category is zero here, not absent.

<!-- END SOURCE: series.export.caveat.hiddenCategories %@ -->

---

#### Administration profiles — dating rule

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 205–206 | key: series.export.dating.administration.v2 -->

Dating: each document is placed by its own editorial date bounds, the frus:doc-dateTime-min and -max attributes on the document element. Those attributes are instants normalised to −05:00, so where the document’s own dateline names the same instant its day is taken from the dateline instead — otherwise the day at −05:00 stands. There is no fallback to the volume’s start year. An undated document is attributed to no administration and drops out.

<!-- END SOURCE: series.export.dating.administration.v2 -->

---

#### Administration profiles — what the year range does

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 161–162 | key: series.export.caveat.adminYears -->

Year range: this selects which administrations appear, by whether the president’s term overlaps the range. It does not re-count documents. An administration shown here carries its full count even when only part of its term falls inside the range.

<!-- END SOURCE: series.export.caveat.adminYears -->

---

#### Administration profiles — why the counts overlap

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 168–169 | key: series.export.caveat.adminOverlap -->

Attribution: a document counts toward every administration its date range overlaps. The counts therefore overlap each other and add up to more than the whole series. A term ends on the day the next president takes office. A document dated on a succession day therefore belongs to the incoming president. These counts measure whose foreign policy the documents cover, not when the volumes were published.

<!-- END SOURCE: series.export.caveat.adminOverlap -->

---

#### Administration profiles — the editorial-notes toggle

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 188–189 | key: series.export.caveat.adminNotes.v2 %@ -->

Editorial notes: %@. Editorial-note documents carry a span of dates rather than a single date; excluding them also withholds a volume whose only tie to an administration is such a note.

<!-- END SOURCE: series.export.caveat.adminNotes.v2 %@ -->

---

---

## 14. Short strings bumped since the build-42 pass — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### The document reader's person and term popovers

#### This volume was indexed before the app recorded definitio…
<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | lines: 336–337 | key: glossNotFound.detail.v2 -->

This volume was indexed before the app recorded definitions. To add them, re-index the volume in Settings → Volumes & Storage.

<!-- END SOURCE: glossNotFound.detail.v2 -->

#### This volume was indexed before the app recorded details a…
<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | lines: 326–327 | key: personNotFound.detail.v2 -->

This volume was indexed before the app recorded details about people. To add them, re-index the volume in Settings → Volumes & Storage.

<!-- END SOURCE: personNotFound.detail.v2 -->

### Collections and Zotero

#### Search is not ready yet. Try again in a moment.
<!-- SOURCE: FRUSExplorer/Collections/CollectionContentResolver.swift | lines: 34–35 | key: export.smart.noSearchService.v2 -->

Search is not ready yet. Try again in a moment.

<!-- END SOURCE: export.smart.noSearchService.v2 -->

#### Zotero is receiving too many requests right now. Try agai…
<!-- SOURCE: FRUSExplorer/Zotero/ZoteroAPIModels.swift | lines: 206–207 | key: zotero.error.rateLimited.v2 -->

Zotero is receiving too many requests right now. Try again in a moment.

<!-- END SOURCE: zotero.error.rateLimited.v2 -->

### A document with no printed title

Most FRUS documents carry a printed head, and that is what the app shows in every list. A few do
not — almost all of them editorial notes, which are the editors' own connective prose rather than a
document reproduced from the archives. These two strings are what such a row says instead. Before
they existed the row showed the raw record id, and before that it showed nothing at all.

#### An editorial note, with its document number
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentDisplayTitle.swift | lines: 72–73 | key: document.title.editorialNote %@ | shared: iOS+macOS (single edit point) -->

Editorial Note %@

<!-- END SOURCE: document.title.editorialNote %@ -->

#### An editorial note carrying no number
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentDisplayTitle.swift | lines: 75–76 | key: document.title.editorialNote.unnumbered | shared: iOS+macOS (single edit point) -->

Editorial Note

<!-- END SOURCE: document.title.editorialNote.unnumbered -->

### Where an export says what it drew on

These are wave PV's export sentences — the part a reader can actually cite, because a chip cannot
travel into a PDF somebody else opens. Each names a source the exported material used; an export
prints only the ones that apply to its own contents.

#### provenance.source.frusText
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 108–108 | key: provenance.source.frusText | shared: iOS+macOS (single edit point) -->

FRUS text

<!-- END SOURCE: provenance.source.frusText -->

#### provenance.source.nara
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 110–110 | key: provenance.source.nara | shared: iOS+macOS (single edit point) -->

FRUS + NARA catalog

<!-- END SOURCE: provenance.source.nara -->

#### provenance.source.ohPeople
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 112–113 | key: provenance.source.ohPeople | shared: iOS+macOS (single edit point) -->

FRUS + OH people register

<!-- END SOURCE: provenance.source.ohPeople -->

#### provenance.source.ohSubjects
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 115–116 | key: provenance.source.ohSubjects | shared: iOS+macOS (single edit point) -->

FRUS + OH subjects

<!-- END SOURCE: provenance.source.ohSubjects -->

#### provenance.source.stateSchedule
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 118–119 | key: provenance.source.stateSchedule | shared: iOS+macOS (single edit point) -->

FRUS + State Dept. schedule

<!-- END SOURCE: provenance.source.stateSchedule -->

#### provenance.source.wordLists
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 121–122 | key: provenance.source.wordLists | shared: iOS+macOS (single edit point) -->

FRUS + this app's word lists

<!-- END SOURCE: provenance.source.wordLists -->

#### provenance.source.model
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 124–124 | key: provenance.source.model | shared: iOS+macOS (single edit point) -->

This app's model

<!-- END SOURCE: provenance.source.model -->

#### provenance.source.yourReading
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 126–126 | key: provenance.source.yourReading | shared: iOS+macOS (single edit point) -->

Your reading

<!-- END SOURCE: provenance.source.yourReading -->

#### provenance.method.frusText
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 138–139 | key: provenance.method.frusText | shared: iOS+macOS (single edit point) -->

Read from the text and editorial apparatus of the FRUS volumes, and from no other source. Where a value was parsed out of printed prose, this app did the reading.

<!-- END SOURCE: provenance.method.frusText -->

#### provenance.method.joined %@
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 141–142 | key: provenance.method.joined %@ | shared: iOS+macOS (single edit point) -->

Produced by joining the FRUS volumes to %@. The join is this app's; a record it could not match is absent rather than wrong.

<!-- END SOURCE: provenance.method.joined %@ -->

#### provenance.method.computed
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 145–146 | key: provenance.method.computed | shared: iOS+macOS (single edit point) -->

Computed by this app rather than read from a source — a model or a scoring rule stands between the volumes and this figure. Cite it as the app's output, not the record's.

<!-- END SOURCE: provenance.method.computed -->

#### provenance.method.yourReading
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 148–149 | key: provenance.method.yourReading | shared: iOS+macOS (single edit point) -->

Your own notes, tags and highlights. The app never mixes them into the published text.

<!-- END SOURCE: provenance.method.yourReading -->

#### provenance.partner.nara
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 157–158 | key: provenance.partner.nara | shared: iOS+macOS (single edit point) -->

the National Archives catalog

<!-- END SOURCE: provenance.partner.nara -->

#### provenance.partner.ohPeople
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 160–161 | key: provenance.partner.ohPeople | shared: iOS+macOS (single edit point) -->

the Office of the Historian's people register

<!-- END SOURCE: provenance.partner.ohPeople -->

#### provenance.partner.ohSubjects
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 163–164 | key: provenance.partner.ohSubjects | shared: iOS+macOS (single edit point) -->

the Office of the Historian's subject taxonomy

<!-- END SOURCE: provenance.partner.ohSubjects -->

#### provenance.partner.stateSchedule
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 166–167 | key: provenance.partner.stateSchedule | shared: iOS+macOS (single edit point) -->

the State Department's decimal classification schedule

<!-- END SOURCE: provenance.partner.stateSchedule -->

#### provenance.curated.disclosure
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 181–182 | key: provenance.curated.disclosure | shared: iOS+macOS (single edit point) -->

Some archival identifiers in this material were matched by hand rather than found in the catalog, because NARA publishes no control number for them.

<!-- END SOURCE: provenance.curated.disclosure -->

#### provenance.parseResidual.disclosure
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceSource.swift | lines: 206–207 | key: provenance.parseResidual.disclosure | shared: iOS+macOS (single edit point) -->

Archival units are read from the volumes' own source notes by a parser, which leaves 2.0% of notes unrecognized across the series — but the rate is very uneven: about 7% for 1952–1954, and effectively every note before 1906. A unit missing from this list may be one the parser could not read rather than one the editors did not cite.

<!-- END SOURCE: provenance.parseResidual.disclosure -->

Printed only in an export that actually contains an archival-sources block, since that block is the parse. The figures come from `SourceNoteKit/eval-baseline.txt`, the maintained generator output (5,465 of 267,663 notes since #1514, 5,469 after #1489; 7.2% for 1952–1954, the worst post-1906 band; 2,033 of 2,034 before 1906) — not from the older `eval-report.txt` beside it.

#### provenance.block.heading
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceStatement.swift | lines: 35–35 | key: provenance.block.heading | shared: iOS+macOS (single edit point) -->

Where this came from

<!-- END SOURCE: provenance.block.heading -->

### What VoiceOver reads from a provenance chip

The chip beside a value carries three channels — a shape, the short label above, and this spoken
sentence. VoiceOver reads **only this sentence**, in place of the glyph and the label, so it is
what a reader using the screen reader learns about the value's provenance. Keep each one a
complete sentence.

#### provenance.chip.a11y.frusOnly
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceChip.swift | lines: 203–204 | key: provenance.chip.a11y.frusOnly | shared: iOS+macOS (single edit point) -->

Source: the FRUS volumes only.

<!-- END SOURCE: provenance.chip.a11y.frusOnly -->

#### provenance.chip.a11y.joined %@
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceChip.swift | lines: 206–207 | key: provenance.chip.a11y.joined %@ | shared: iOS+macOS (single edit point) -->

Source: FRUS joined to %@.

<!-- END SOURCE: provenance.chip.a11y.joined %@ -->

#### provenance.chip.a11y.computed
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceChip.swift | lines: 210–211 | key: provenance.chip.a11y.computed | shared: iOS+macOS (single edit point) -->

Source: computed by this app.

<!-- END SOURCE: provenance.chip.a11y.computed -->

#### provenance.chip.a11y.yourReading
<!-- SOURCE: FRUSExplorer/Provenance/ProvenanceChip.swift | lines: 213–214 | key: provenance.chip.a11y.yourReading | shared: iOS+macOS (single edit point) -->

Source: your own reading.

<!-- END SOURCE: provenance.chip.a11y.yourReading -->


#### \(volumes) volume\(volumes == 1 ? "" : "s")
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | lines: 1354–1355 | key: chronology.agg.volumes.v2 -->

\(volumes) volume\(volumes == 1 ? "" : "s")

<!-- END SOURCE: chronology.agg.volumes.v2 -->

### The classification override — the rail warning and the Settings corrections list (W-4, #1097)

*W-4 let a reader reclassify a document the corpus filed oddly; #1097 moved the control into the
Research rail's classification ⓘ popover by owner decision. The warning is the anomaly disclosure
#279 requires — what follows the override (body styling, badges, filters, counts, exports, across
devices) and what cannot (the bundled series-analytics dashboards, computed from the published
corpus). Softening the "cannot see this change" sentence would turn a disclosed limit into a
silent inconsistency.*

#### The override confirmation warning
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | reclassify confirmation | lines: 1226–1227 | key: classification.override.warning.v2 -->

The document’s body styling, badges, search filters, counts, and exports will follow the new classification on all your devices. Bundled series-analytics dashboards are computed from the published corpus and cannot see this change, and other open windows reflect it when reopened. You can restore FRUS’s own classification at any time from here or from Settings ▸ Search.

<!-- END SOURCE: classification.override.warning.v2 -->

#### The corrections list — empty state
<!-- SOURCE: FRUSExplorer/Settings/ClassificationCorrectionsView.swift | lines: 106–107 | key: classification.corrections.empty.detail -->

Documents you reclassify from the Research panel appear here, where you can restore FRUS’s own classification.

<!-- END SOURCE: classification.corrections.empty.detail -->

#### The corrections list — footer
<!-- SOURCE: FRUSExplorer/Settings/ClassificationCorrectionsView.swift | lines: 136–137 | key: classification.corrections.footer -->

Undoing a correction restores FRUS’s own classification and syncs across your devices. A correction for a volume not indexed on this device takes effect when the volume is indexed.

<!-- END SOURCE: classification.corrections.footer -->

---

## 18. Prose this file had never carried (build-48 sweep) — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### 18.5 Export method statements

*Prose stamped into an exported file, where it has to stand alone because the app is not there to explain it. §10 carries the archival and series statements already mirrored; these are the rest — above all the semantic map's regions table and figure plate, whose caveats had never been here except the slice line in §13.*

#### Scope: only the volumes in “%@” are counted. The derivation…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | ArchivalAnalyticsExport.ranking | lines: 121–122 | key: archival.export.caveat.scope.volumes %@ -->

Scope: only the volumes in “%@” are counted. The derivation behind this table is corpus-wide and is not narrowed to what this device has downloaded, so the same scope gives the same figures on any device.

<!-- END SOURCE: archival.export.caveat.scope.volumes %@ -->

#### Denominator: the era’s volumes carry %1$@ in all, and the…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | ArchivalAnalyticsExport.ranking | lines: 134–135 | key: archival.export.caveat.denominator %@ %@ -->

Denominator: the era’s volumes carry %1$@ in all, and the rows in this table account for %2$@ of them. The rest name a unit of the other kind, a unit below the row cap, or nothing this app resolves. *(Interpolated with the era's source notes as a phrase — “59,973 source notes” — and the rows' grouped total (#1374).)*

<!-- END SOURCE: archival.export.caveat.denominator %@ %@ -->

#### Denominator: the era’s volumes carry %1$@ in all, and this…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | ArchivalAnalyticsExport.ranking | lines: 138–139 | key: archival.export.caveat.denominator.uncapped %@ %@ -->

Denominator: the era’s volumes carry %1$@ in all, and this table — every unit the era reaches, uncapped — accounts for %2$@ of them. The rest name a unit of the other kind, or nothing this app resolves. *(Interpolated as the capped sentence above is.)*

<!-- END SOURCE: archival.export.caveat.denominator.uncapped %@ %@ -->

#### ranked by meaning (on-device model), not by keywords — the…
<!-- SOURCE: FRUSExplorer/Search/SearchScopeSignature.swift | SearchScopeSignature.describe | lines: 165–166 | key: appendix.scope.semantic -->

ranked by meaning (on-device model), not by keywords — the query’s words were not required to appear

<!-- END SOURCE: appendix.scope.semantic -->

#### Corpus: the map is a bundled artifact covering all %1$lld…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.corpusStatement | lines: 152–153 | key: semanticMap.export.caveat.corpus.whole %lld -->

Corpus: the map is a bundled artifact covering all %1$lld documents in the published series, and draws them whether or not a volume has been downloaded.

<!-- END SOURCE: semanticMap.export.caveat.corpus.whole %lld -->

#### Only the %@ indexed on this device can be opened from it.
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.corpusStatement | lines: 159–160 | key: semanticMap.export.caveat.corpus.reach %@ -->

Only the %@ indexed on this device can be opened from it. *(Interpolated with the indexed volumes as a count and its noun — “1 volume”, “12 volumes” (#1374 review, round 1, where it read “1 volume(s)”).)*

<!-- END SOURCE: semanticMap.export.caveat.corpus.reach %@ -->

#### The current scope covers %1$lld of those documents; every…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.corpusStatement | lines: 165–166 | key: semanticMap.export.caveat.scoped %lld -->

The current scope covers %1$lld of those documents; every count in this export is taken inside that scope.

<!-- END SOURCE: semanticMap.export.caveat.scoped %lld -->

#### How to read position: the projection preserves local…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.caveats | lines: 177–178 | key: semanticMap.export.caveat.layout -->

How to read position: the projection preserves local similarity, so documents near each other are alike. Distances between far-apart regions are not meaningful, and neither is direction — there is no axis, no scale and no origin.

<!-- END SOURCE: semanticMap.export.caveat.layout -->

#### This surface is experimental. The regions are found by a…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.caveats | lines: 179–180 | key: semanticMap.export.caveat.experimental -->

This surface is experimental. The regions are detected by an AI model and a clustering algorithm, not by an editor, and their names are the most distinctive words in a sample of each region’s documents — not subject headings.

<!-- END SOURCE: semanticMap.export.caveat.experimental -->

#### Coverage: %1$lld regions cover %2$lld documents. The other…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.caveats | lines: 182–183 | key: semanticMap.export.caveat.unclustered %lld %lld %lld -->

Coverage: %1$lld regions cover %2$lld documents. The other %3$lld sit between regions and belong to none: a regions table cannot list them, and on the map they are drawn with no region name.

<!-- END SOURCE: semanticMap.export.caveat.unclustered %lld %lld %lld -->

#### Method: %1$@ from %2$lld dimensions (neighbors %3$lld)…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.caveats | lines: 188–189 | key: semanticMap.export.caveat.method %@ %lld %lld %@ %@ -->

Method: %1$@ from %2$lld dimensions (neighbors %3$lld), clustered with %4$@. Labels: %5$@.

<!-- END SOURCE: semanticMap.export.caveat.method %@ %lld %lld %@ %@ -->

#### Artifact: generated %1$@, provenance %2$@. The layout is…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.caveats | lines: 193–194 | key: semanticMap.export.caveat.artifact %@ %@ -->

Artifact: generated %1$@, provenance %2$@. The layout is pinned to a fixed seed, so the same artifact always draws the same map.

<!-- END SOURCE: semanticMap.export.caveat.artifact %@ %@ -->

#### Color lens in effect when this export was taken: %1$@. The…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.caveats | lines: 197–198 | key: semanticMap.export.caveat.lens %@ -->

Color lens in effect when this export was taken: %1$@. The lens changes only what the points are colored by, never where they sit.

<!-- END SOURCE: semanticMap.export.caveat.lens %@ -->

#### The map artifact stores positions and region membership…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.caveats | lines: 200–201 | key: semanticMap.export.caveat.identity -->

The map artifact stores positions and region membership only — no document titles and no dates — so an export from it can name regions and counts, and cannot name a document.

<!-- END SOURCE: semanticMap.export.caveat.identity -->

#### Frame: rendered at %1$lld × %2$lld points, centered on grid…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.frameCaveats | lines: 236–237 | key: semanticMap.export.caveat.frame %lld %lld %lld %lld %@ -->

Frame: rendered at %1$lld × %2$lld points, centered on grid (%3$lld, %4$lld) — %5$@. Those coordinates are the artifact’s own grid, recorded so this exact view can be restored; they are not a measurement, and the projection has no axis, no scale and no origin.

<!-- END SOURCE: semanticMap.export.caveat.frame %lld %lld %lld %lld %@ -->

#### Region names shown: %1$lld of %2$lld, chosen to fit this…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapExport.swift | SemanticMapExport.frameCaveats | lines: 244–245 | key: semanticMap.export.caveat.frame.labels %lld %lld -->

Region names shown: %1$lld of %2$lld, chosen to fit this plate. The app’s window is a different shape and re-runs the same rule against it, so a reader at the screen sees a different set of names — a region named here can be unnamed there, and the reverse.

<!-- END SOURCE: semanticMap.export.caveat.frame.labels %lld %lld -->

#### Artifact: drawn from the bundled source-provenance…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | SeriesAnalyticsExport.provenance | lines: 122–123 | key: series.export.caveat.artifact %@ -->

Artifact: drawn from the bundled source-provenance aggregate generated %@. Every figure on this surface reads that one file; a plate from a different generation is a different figure.

<!-- END SOURCE: series.export.caveat.artifact %@ -->

### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations

*Text a reader meets while reading: the missing-volume state, the rail's subject and summary notes, the Related list's pool and off-device captions, the Chronology's footers and its overflow chip's VoiceOver label, the cross-reference graph's banners and help, citation lookup, and the notice for a link that only works inside a document.*

#### This is a “%@” link from inside a FRUS document. It works…
<!-- SOURCE: FRUSExplorer/App/FRUSExplorerApp.swift | FRUSExplorerApp.handleDeepLink | lines: 3048–3049 | key: deepLink.inAppOnly %@ -->

This is a “%@” link from inside a FRUS document. It works while reading that document in the app, not on its own.

<!-- END SOURCE: deepLink.inAppOnly %@ -->

#### Alert message — The linked document is in “%@”, which isn’t downloaded yet.… (macOS)
<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | MacDocumentView.body | lines: 362–363 | key: document.crossref.download.message.mac %@ | shared: macOS (a key of its own since #1483; the iPhone and iPad text is document.crossref.download.message %@, later in §18.10) -->

The linked document is in “%@”, which isn’t downloaded yet. Download it to open the document.

<!-- END SOURCE: document.crossref.download.message.mac %@ -->

*The Mac’s alert offers Download Volume and Cancel only, so its message does not mention the connections view the iPhone and iPad alert offers.*

#### Apple Intelligence is not available on this device, so new…
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | SummaryBlockView.body | lines: 283–284 | key: summary.unavailable.explanation | shared: macOS only -->

Apple Intelligence is not available on this device, so new summaries cannot be generated. Summaries created on your other devices still appear here via iCloud.

<!-- END SOURCE: summary.unavailable.explanation -->

#### Tooltip — Choose citation style (history.state.gov, Chicago…
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | CitationPopoverView.body | lines: 1270–1271 | key: citation.popover.stylePicker.help | shared: macOS only -->

Choose citation style (history.state.gov, Chicago, Turabian) for this view — change the default in Settings → Display

<!-- END SOURCE: citation.popover.stylePicker.help -->

#### Tooltip — Copy this citation as BibTeX or RIS, or save a .bib file.…
<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | CitationPopoverView.body | lines: 1386–1387 | key: citation.popover.copyAs.help | shared: macOS only -->

Copy this citation as BibTeX or RIS, or save a .bib file. Sharing and Zotero are on the document’s Share button.

<!-- END SOURCE: citation.popover.copyAs.help -->

#### (chart shows all; list shows the first \(…) — narrow the…
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView.summaryLine | lines: 317–318 | key: chronology.summary.chartFull -->

(chart shows all; list shows the first \(ChronologyViewModel.loadLimit) — narrow the range to browse them)

<!-- END SOURCE: chronology.summary.chartFull -->

#### Empty state — Pick a start and end date, then tap Show to browse every…
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView.promptDetail | lines: 336–337 | key: chronology.prompt.detail | shared: iOS only (the macOS wording is the next block) -->

Pick a start and end date, then tap Show to browse every corpus document from that period.

<!-- END SOURCE: chronology.prompt.detail -->

#### Empty state (macOS) — Pick a start and end date, then click Show to browse every…
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView.promptDetail | lines: 333–334 | key: chronology.prompt.detail.mac | shared: macOS only -->

*#1380: the Mac's own key, because the sentence names the Show button and the Mac reader clicks it. Two keys, because one key with two default values collides.*

Pick a start and end date, then click Show to browse every corpus document from that period.

<!-- END SOURCE: chronology.prompt.detail.mac -->

#### Empty state — No indexed documents fall within this date range. Try…
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView.contentArea | lines: 362–363 | key: chronology.empty.detail -->

No indexed documents fall within this date range. Try widening it or indexing more volumes.

<!-- END SOURCE: chronology.empty.detail -->

#### VoiceOver label — Document distribution over the selected dates, stacked by…
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView.distributionChart | lines: 705–706 | key: chronology.chart.a11y -->

Document distribution over the selected dates, stacked by volume. Counts are listed in the legend and in each date section below.

<!-- END SOURCE: chronology.chart.a11y -->

#### Header — Spans more than a year

*#1422: the header of the section the chip below opens. It read “Spans this period”, but a row is listed because its dates overlap your range, so it can begin or end inside it; what every row here does is span more than a year, which is the rule that sorts it here. It now lives beside the chip’s sentences in `ChronologyViewModel.swift`, so the two are worded together.*

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyViewModel.swift | ChronologyViewModel.spanningSectionHeader | lines: 613–613 | key: chronology.spanning.header -->

Spans more than a year

<!-- END SOURCE: chronology.spanning.header -->

#### Footer — These documents (mostly editorial notes) cover a span of…
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView.spanningSection | lines: 912–913 | key: chronology.spanning.footer -->

These documents (mostly editorial notes) cover a span of dates rather than a single day, so they’re listed here instead of on the timeline.

<!-- END SOURCE: chronology.spanning.footer -->

#### Chip — one document spans more than a year

*#1422: the chip counts documents, not editorial notes — 36 of the 7,137 rows wider than a year in a 553-volume index, in 8 volumes, are not editorial notes — and the footer above keeps “(mostly editorial notes)”.*

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyViewModel.swift | key: chronology.spanning.chip.one -->

1 document spans more than a year

<!-- END SOURCE: chronology.spanning.chip.one -->

#### Chip — several documents span more than a year

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyViewModel.swift | key: chronology.spanning.chip.many -->

\(count.formatted(.number.locale(locale))) documents span more than a year

<!-- END SOURCE: chronology.spanning.chip.many -->

#### VoiceOver label — the chip, one document

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyViewModel.swift | key: chronology.spanning.chip.a11y.one -->

1 document spans more than a year. Toggle to show it.

<!-- END SOURCE: chronology.spanning.chip.a11y.one -->

#### VoiceOver label — the chip, several documents

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyViewModel.swift | key: chronology.spanning.chip.a11y.many -->

\(count.formatted(.number.locale(locale))) documents span more than a year. Toggle to show them.

<!-- END SOURCE: chronology.spanning.chip.a11y.many -->

#### Footer — These documents overlap your range but their dates are…
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView.overflowSection | lines: 982–983 | key: chronology.overflow.footer -->

These documents overlap your range but their dates are imprecise enough to reach before or after it, so they’re listed here rather than placed on the chart.

<!-- END SOURCE: chronology.overflow.footer -->

#### VoiceOver label — 1 document has an uncertain date that extends beyond…
<!-- The Chronology's "extend beyond this range" chip, read aloud (#1387). The label replaces both
     of the chip's lines, so it carries the breakdown the screen prints in parentheses:
     `\(breakdown)` is the chip's non-zero parts joined by commas, each already singular or plural
     — "1 reaches past both ends", or "2 begin before, 24 reach past both ends" — the same words the
     screen shows between middle dots. This form is for ONE document, so keep it singular. -->
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyViewModel.swift | ChronologyOverflowCounts.chipAccessibilityLabel | lines: 159–160 | key: chronology.overflow.chip.a11y.one -->

1 document has an uncertain date that extends beyond this range: \(breakdown). Toggle to show it.

<!-- END SOURCE: chronology.overflow.chip.a11y.one -->

#### VoiceOver label — \(…) documents have uncertain dates that extend beyond…
<!-- The same label for two or more documents. `\(grouped(total))` is their number, grouped for the
     reader's region ("12,072"); `\(breakdown)` is as above. -->
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyViewModel.swift | ChronologyOverflowCounts.chipAccessibilityLabel | lines: 161–162 | key: chronology.overflow.chip.a11y.many -->

\(grouped(total)) documents have uncertain dates that extend beyond this range: \(breakdown). Toggle to show them.

<!-- END SOURCE: chronology.overflow.chip.a11y.many -->

#### Footer — Paste a chapter’s footnotes. Numbered notes are split on…
<!-- SOURCE: FRUSExplorer/Citation/CitationLookupView.swift | CitationLookupView.inputSection | lines: 220–221 | key: citation.batch.footer -->

Paste a chapter’s footnotes. Numbered notes are split on their numbers, and a note wrapped across lines is rejoined; an unnumbered list is one citation per line.

<!-- END SOURCE: citation.batch.footer -->

#### Empty state — No FRUS documents matched the provided citation. Check the…
<!-- SOURCE: FRUSExplorer/Citation/CitationLookupView.swift | CitationLookupView.resultsSection | lines: 391–392 | key: citation.noMatch.detail -->

No FRUS documents matched the provided citation. Check the subseries and volume, then try again.

<!-- END SOURCE: citation.noMatch.detail -->

#### Document \(…) was not found in this volume (last document…
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.fuzzyDocumentNote | lines: 1361–1362 | key: citation.match.fuzzyNote -->

Document \(requested) was not found in this volume (last document is \(max)); the nearest available document is \(nearest).

<!-- END SOURCE: citation.match.fuzzyNote -->

#### This result comes from a volume the citation does not…
<!-- The note under a Citation Lookup result whose volume does not carry a field the citation
     names (#1474) — usually because no volume had the cited subseries, volume or part and the lookup
     looked past it. The result's label reads "Best guess — this volume does not match the cited
     volume XX" (or subseries, or part). It appears under a document found that way and under a
     volume offered for download. Other lines may follow it, one to a line (corrected in review
     round 2, which found this note naming only two): the note about a cited page the document is
     not on, when that is wrong too (the "The citation’s page is not one…" block below); and how the
     result was found, when it was more than a hit on the cited number — the page-match label
     ("Matched by page number — …"), the nearest-document note ("Document 500 was not found…"), or
     the label "Match — document number assigned digitally". Since #1503, one of several documents
     a page-only citation names carries two lines after it: its label ("Possible match — one of 2
     documents that begin on page 48") and the "A page alone cannot say…" note (the block after
     "The citation’s page is not one…"). A document found through the text
     beside a history.state.gov link carries the next block's note instead of this one. Until #1507
     a footnote that opens with its date and gives its volume's years without naming the series —
     "Memorandum, May 5, 1962, 1961–1963, vol. V, doc. 84" — was read as the subseries 1962 and drew
     this note under Volume V, though the citation names Volume V; it now reads 1961–1963. -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.unmetFieldsNote | lines: 1402–1403 | key: citation.match.unmetFieldsNote -->

This result comes from a volume the citation does not name, so it may not be the document cited. Check the citation before relying on it.

<!-- END SOURCE: citation.match.unmetFieldsNote -->

#### The link names this volume, but the citation’s text names a…
<!-- The note under a Citation Lookup best guess found through the text beside a history.state.gov
     link (#1474 review round 2): the link names a volume, or a chapter of it, the text beside it
     gives the document number or page, and that text also names a different volume, subseries or
     part — "FRUS, 1961–1963, vol. XIV, doc. 84, https://history.state.gov/historicaldocuments/
     frus1961-63v05". The result is Volume V's document 84, labelled "Best guess — this volume does
     not match the cited volume XIV". It replaces the previous block's note, whose "a volume the
     citation does not name" is untrue here: the link names it. The text's subseries is the year
     that follows "FRUS" or "Foreign Relations" — until review round 3 it was the first year in the
     text, so a footnote opening with the document's date ("Memorandum of Conversation, Moscow, May
     5, 1962, FRUS, 1961–1963, vol. V, doc. 84, https://…/frus1961-63v05") drew this note, and "the
     cited subseries 1962", when its text named Volume V's own subseries. A text that names the
     series nowhere — the link is its only "frus" — or names it with no year after it still reads
     its first year, the date the note opens with; since review round 5 that year is not checked
     and never draws this note, so "National Intelligence Estimate, December 1, 1960, vol. V, doc.
     1, https://…/frus1961-63v05" is an exact match. A year after the series' name is checked, and
     draws it when the linked volume does not carry it: "FRUS, 1961–1963, vol. XXIII, doc. 5,
     https://…/frus1964-68v23" does, though that Congo volume's title prints 1960–1968, and so does
     "FRUS, 1964–1968, vol. V, doc. 84" beside a link to Volume V. Since #1507, when no year follows
     the series' name with no other number between — the text names no series, or names it before
     another number — the first range it gives is checked too: "1964–68, vol. V, doc. 84,
     https://…/frus1961-63v05" draws this note. A single year read that way is a date and is not:
     "FRUS, vol. V, doc. 84, Memorandum, May 5, 1962" and "Senate Committee on Foreign Relations,
     May 5, 1962, vol. V, doc. 84" beside the Volume V link drew it until then, and no longer do. -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.linkProseNote | lines: 1415–1416 | key: citation.match.linkProseNote -->

The link names this volume, but the citation’s text names a different one, and this document was found by the text’s document number or page — so it may not be the document cited. Check the citation before relying on it.

<!-- END SOURCE: citation.match.linkProseNote -->

#### Best guess — this volume does not match the cited \(…)
<!-- The explanation after "Best guess — " on a Citation Lookup result whose volume does not carry
     a field the citation names (#1474; reworded in review round 1 from "no volume matches the cited
     …", which is untrue when a long title fragment moves the lookup out of a subseries other volumes
     carry). `\(fields)` is the fields it misses, each as "subseries 1999-00", "volume XX" or
     "part 2", joined as a list: "volume XX and part 2". It may be followed by "and page 50 is
     outside the pages this document may be printed on …" (the next two blocks). Keep it
     lower-case: it continues the label. -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.unmetFields | lines: 1396–1397 | key: citation.match.unmetFields -->

this volume does not match the cited \(fields)

<!-- END SOURCE: citation.match.unmetFields -->

#### Best guess — page \(…) is outside the pages this document may be printed on (\(…)–\(…))
<!-- The explanation after "Best guess — " on a Citation Lookup document found by its number when
     the page the citation also names is not one it may be printed on (#1474 review round 1;
     reworded in review round 2 from "page 50 is outside this document (pages 200–203)", whose
     numbers were the document's page breaks and so left out the page before the first, which the
     check accepts — and read "pages 200–200" for a document with one break). `\(page)` is the
     cited page; `\(first)`–`\(last)` are exactly the pages the check accepts: since #1503, from
     the page the document begins on to its last page break, which for a short document with no
     break of its own is the one page it begins on. Until #1503 the index kept no record of that
     page, and the range ran from the page before the document's first break — as it still does
     for the few documents the index records no start for, but never from page 0: a document whose
     first page break is page 1 shows "(1–2)", where it showed "(0–2)" until review round 3 — and
     for a short document with none, over the pages between the breaks on either side of it. When
     the range is one page, the next block is shown instead. Keep it lower-case: it continues the
     label, and may follow the previous block after "and". -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.pageOutside | lines: 1435–1436 | key: citation.match.pageOutside -->

page \(page) is outside the pages this document may be printed on (\(first)–\(last))

<!-- END SOURCE: citation.match.pageOutside -->

#### Best guess — page \(…) is not the page this document is printed on (\(…))
<!-- The previous block's one-page form (#1474 review round 2): a short document with no page break
     of its own is printed on one page, `\(first)` — since #1503 always the page it begins on, until
     then only when the breaks on either side of it were one page apart — so "vol. V, doc. 17, p.
     500" reads "page 500 is not the page this document is printed on (40)". Since review round 3's
     page-1 floor it is also the form for a document the index records no start for whose only
     arabic page break of its own is page 1, which reads "(1)" (corrected in review round 4, which
     found this note naming only the first case). Keep it lower-case: it continues the label. -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.pageOutside | lines: 1432–1433 | key: citation.match.pageOutsideOnePage -->

page \(page) is not the page this document is printed on (\(first))

<!-- END SOURCE: citation.match.pageOutsideOnePage -->

#### The citation’s page is not one this document is printed on…
<!-- The note under that best guess (#1474 review round 1). The document on the cited page, when
     there is one, is listed after it as a second result — since #1503 the document that begins on
     that page, or every one of them when several do, each carrying the next block's note. -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.pageOutsideNote | lines: 1441–1442 | key: citation.match.pageOutsideNote -->

The citation’s page is not one this document is printed on, so its document number or its page may be wrong. Check the citation before relying on it.

<!-- END SOURCE: citation.match.pageOutsideNote -->

#### A page alone cannot say which of the documents printed on it…
<!-- The note under each result of a citation that names a page but no document when that page
     names several documents (#1503): several begin on it — short documents often share a page — or,
     none beginning there, several are printed on it (a page whose breaks run out of order). Each
     result's label reads "Possible match — one of 2 documents that begin on page 48" (or "… printed
     on page 269"); up to ten are listed, and the count is every one. None is treated as a match:
     Batch counts the note as ambiguous, and a collection's Add Documents never adds it as
     resolved. In the E-volumes that number their pages afresh in every document the next block is
     shown instead (#1503 review round 1). -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.sharedPageNote | lines: 1332–1333 | key: citation.match.sharedPageNote -->

A page alone cannot say which of the documents printed on it the citation means. Add the document number to the citation, or compare these documents with the citation.

<!-- END SOURCE: citation.match.sharedPageNote -->

#### This volume numbers its pages afresh in every document…
<!-- The note under each result of a citation that names a page but no document in a volume that
     numbers its pages afresh in every document — fourteen of the E-volumes and 1981–1988 Volume
     XVI — where a page number alone names no document (#1503 review round 1). Every document with
     a page of that number is listed, up to ten, each labelled "Possible match — one of 12
     documents printed on page 2", or, when one document alone has such a page, "Possible match —
     page 57 is printed only in this document"; even that one is not treated as a match. -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.perDocumentPageNote | lines: 1348–1349 | key: citation.match.perDocumentPageNote -->

This volume numbers its pages afresh in every document, so a page number alone does not say which document the citation means. Add the document number to the citation.

<!-- END SOURCE: citation.match.perDocumentPageNote -->

#### Volume identified — no document the citation names was found in it
<!-- The label on the one result a history.state.gov link gives when its volume is downloaded but
     nothing it names is found in it (#1474 review round 1): a link to the whole volume or to a
     chapter, with no document number or page beside it that the volume holds, or a link to a
     document id the volume's index lacks. The result shows the volume's title and has no button.
     Since #1522 it is shown only when the volume's index can say what the volume holds; a volume
     downloaded and not yet indexed, or whose indexing is running or was cut short, shows the next
     block's label instead — except for a link to the whole volume with no document or page beside
     it, which names nothing an index could find and shows this label either way (#1522 review
     round 1). -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.linkVolumeOnly | lines: 1449–1450 | key: citation.match.linkVolumeOnly -->

Volume identified — no document the citation names was found in it

<!-- END SOURCE: citation.match.linkVolumeOnly -->

#### Volume identified — downloaded but not yet indexed; look it up again once it is
<!-- The label on the one result a volume gives when it is downloaded, the citation names a
     document or a page in it, nothing it names was found there, and its index cannot yet say what
     it holds (#1522): the volume is waiting to be indexed after its download, Settings' Rebuild
     Index has not reached it yet, or its indexing is running or was cut short. Until #1522 a
     history.state.gov link to such a volume read "Volume identified — no document the citation
     names was found in it" (the block above), and a citation of it found nothing at all — "No
     Matches Found", and "No match" in Batch — though the document may well be in it. It is not
     shown where indexing could not change the answer (#1522 review round 1): a citation naming
     only the volume, a link to the whole volume with no document or page beside it, and a citation
     naming only a page of one of the microfiche supplements, whose pages are never looked up, read
     as they would in an indexed volume; and a document numbered past the volume's last shows the
     nearest document ("Possible match — document … not found; nearest is document …") when the
     volume already holds it. It is shown in Citation Lookup (in Batch it is the row's caption),
     and in a collection's Add Documents as the reason a line stays unresolved; a link to a numbered
     document in such a volume is added instead, by the id the link names, and resolves once the
     volume is indexed. On a best guess the label reads "Best guess — …" and this line follows the
     best guess's note in Citation Lookup; Add Documents gives only the best guess's label as the
     reason (review round 1 corrected this note, which said it gave this line). The result shows the
     volume's title and has no button. It says "not yet indexed" rather than "being indexed"
     because a volume whose indexing was cut short is not being indexed until it is indexed again. -->
<!-- SOURCE: FRUSExplorer/Citation/CitationMatchingEngine.swift | ConfidenceLabels.notYetIndexed | lines: 1463–1464 | key: citation.match.notYetIndexed -->

Volume identified — downloaded but not yet indexed; look it up again once it is

<!-- END SOURCE: citation.match.notYetIndexed -->

#### Tooltip — Find other FRUS documents drawn from the same archival…
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.nodeContextMenuItems | lines: 949–950 | key: graph.contextMenu.archivalNeighbors.help -->

Find other FRUS documents drawn from the same archival source — lot file, central file, collection, or library

<!-- END SOURCE: graph.contextMenu.archivalNeighbors.help -->

#### Tooltip — Timeline arranges documents chronologically along a date…
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.filterToolbar | lines: 1394–1395 | key: graph.layout.help -->

Timeline arranges documents chronologically along a date axis; Network uses the spring layout. Timeline is unavailable when too few documents have dates.

<!-- END SOURCE: graph.layout.help -->

#### %1$lld documents in %2$lld volumes you have not downloaded…
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.undownloadedBanner | lines: 1589–1590 | key: graph.banner.undownloaded.v2 %lld %lld -->

%1$lld documents in %2$lld volumes you have not downloaded also cite this one. They are shown without titles until you download them.

<!-- END SOURCE: graph.banner.undownloaded.v2 %lld %lld -->

#### Footer — Corpus-wide connections for this volume — every other…
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphWindowView.swift | CrossReferenceGraphWindowView.modeChoiceView | lines: 342–343 | key: xref.picker.volumeGraph.footer | shared: macOS only -->

Corpus-wide connections for this volume — every other volume it cross-references or is referenced by.

<!-- END SOURCE: xref.picker.volumeGraph.footer -->

#### Tooltip — View cross-volume reference counts for this volume — click…
<!-- SOURCE: FRUSExplorer/CrossReference/VolumeConnectionGraphView.swift | VolumeConnectionGraphView.nodeHitAreas | lines: 760–761 | key: volumeGraph.node.help -->

View cross-volume reference counts for this volume — click for details and to explore its connections

<!-- END SOURCE: volumeGraph.node.help -->

#### Empty state — This document is in \(…), which is not on this device.…
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentView.swift | DocumentView.loadedView | lines: 770–771 | key: document.volumeMissing.detail | shared: iOS only -->

This document is in \(entry.volumeId), which is not on this device. Download the volume from the Browse tab to read it.

<!-- END SOURCE: document.volumeMissing.detail -->

#### Alert message — The linked document is in “%@”, which isn’t downloaded yet.… (iOS)
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentView.swift | DocumentView.documentContent | lines: 833–834 | key: document.crossref.download.message %@ | shared: iOS (the Mac’s text is document.crossref.download.message.mac %@, a key of its own since #1483, earlier in §18.10) -->

The linked document is in “%@”, which isn’t downloaded yet. Download it to open the document, or view how it connects to this one.

<!-- END SOURCE: document.crossref.download.message %@ -->

*The iPhone and iPad alert has a View Connections button beside Download Volume, which the last clause names.*

#### VoiceOver hint — Read mode also enables edge-tap navigation to the previous…
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentView.swift | DocumentView.documentToolbar | lines: 1441–1442 | key: document.toolbar.panelMode.hint | shared: iOS only -->

Read mode also enables edge-tap navigation to the previous and next document in this volume

<!-- END SOURCE: document.toolbar.panelMode.hint -->

#### This volume was side-loaded, not downloaded from the…
<!-- SOURCE: FRUSExplorer/DocumentView/DocumentViewModel.swift | DocumentViewModel.citationProvenanceNote | lines: 249–250 | key: citation.sideloaded.note -->

This volume was side-loaded, not downloaded from the published catalogue. The app cannot confirm it is published, so no history.state.gov link is included — check the citation before using it.

<!-- END SOURCE: citation.sideloaded.note -->

#### Detected automatically from the text, not editorial subject…
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | ResearchRailView.subjectsAccordion | lines: 419–420 | key: panel.subjects.caveat -->

Detected automatically from the text, not editorial subject headings — so some are wrong. Most distinctive first.

<!-- END SOURCE: panel.subjects.caveat -->

#### Apple Intelligence is not available on this device, so new…
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | ResearchRailView.summaryAccordion | lines: 558–559 | key: panel.summary.unavailable | shared: iOS only -->

Apple Intelligence is not available on this device, so new summaries cannot be generated. Summaries from your other devices still appear here via iCloud.

<!-- END SOURCE: panel.summary.unavailable -->

#### Ranked from the first %1$lld of %2$lld documents that share…
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | RelatedDocumentsContent.body | lines: 264–265 | key: related.poolCut %lld %lld -->

Ranked from the first %1$lld of %2$lld documents that share this anchor’s archival container. The rest were not scored. Narrow the scope to reach them.

<!-- END SOURCE: related.poolCut %lld %lld -->

#### No indexed documents share this document’s archival…
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | RelatedDocumentsContent.emptyDetail | lines: 440–441 | key: related.empty.detail -->

No indexed documents share this document’s archival provenance or cross-references — indexing more volumes may surface some.

<!-- END SOURCE: related.empty.detail -->

#### At least %1$lld documents in %2$lld volumes you have not…
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | RelatedDocumentsContent.offIndexCaption | lines: 655–656 | key: related.offIndex.caption.capped %lld %lld -->

At least %1$lld documents in %2$lld volumes you have not downloaded read as close to this one as the matches ranked above.

<!-- END SOURCE: related.offIndex.caption.capped %lld %lld -->

#### %1$lld documents in %2$lld volumes you have not downloaded…
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | RelatedDocumentsContent.offIndexCaption | lines: 657–658 | key: related.offIndex.caption %lld %lld -->

%1$lld documents in %2$lld volumes you have not downloaded read as close to this one as the matches ranked above.

<!-- END SOURCE: related.offIndex.caption %lld %lld -->

### 18.11 Research, projects and history

*The Research tab's empty states, Project Home's captions and footers, the project editor, and the history and session-log states.*

#### Research logging is off, so new activity is not being…
<!-- SOURCE: FRUSExplorer/History/HistoryView.swift | HistoryView.loggingFooter | lines: 309–310 | key: history.logging.off -->

Research logging is off, so new activity is not being recorded. Turn it back on in Settings under Research Sessions.

<!-- END SOURCE: history.logging.off -->

#### All notes, collections, summaries, and reading history…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectContextView.swift | MergeProjectSheet.macBody | lines: 66–67 | key: project.merge.explanation -->

All notes, collections, summaries, and reading history assigned to “\(sourceProject.name)” will be re-assigned to the selected project. “\(sourceProject.name)” will be deleted.

<!-- END SOURCE: project.merge.explanation -->

#### Footer — Merging needs a second project to merge into. Deleting…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectEditorView.swift | ProjectEditorView.manageSection | lines: 271–272 | key: project.editor.manage.footer.only -->

Merging needs a second project to merge into. Deleting keeps your notes, collections, and history — it only unlinks them from this project.

<!-- END SOURCE: project.editor.manage.footer.only -->

#### Footer — Merging moves everything filed here into the project you…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectEditorView.swift | ProjectEditorView.manageSection | lines: 273–274 | key: project.editor.manage.footer -->

Merging moves everything filed here into the project you choose. Deleting keeps your notes, collections, and history — it only unlinks them from this project.

<!-- END SOURCE: project.editor.manage.footer -->

#### Footer — Subjects that recur across the volumes you’ve already…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectFocusSubjectsEditor.swift | ProjectFocusSubjectsEditor.content | lines: 110–111 | key: project.focus.suggested.detail -->

Subjects that recur across the volumes you’ve already collected, annotated, or opened in this project.

<!-- END SOURCE: project.focus.suggested.detail -->

#### %lld documents in volumes you have not downloaded read as…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectHomeView.swift | ProjectHomeView.reachCaption | lines: 786–790 | key: project.reach.caption %lld %lld -->

%lld documents in volumes you have not downloaded read as close to one of this project's %lld documents as that document's nearest neighbours already on this device.

<!-- END SOURCE: project.reach.caption %lld %lld -->

#### As you add documents to this project’s collections, related…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectHomeView.swift | ProjectHomeView.leadsSection | lines: 825–826 | key: project.home.leads.placeholder -->

As you add documents to this project’s collections, related documents you haven’t gathered yet will surface here.

<!-- END SOURCE: project.home.leads.placeholder -->

#### No activity in this project yet. Read documents, take…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectHomeView.swift | ProjectHomeView.recentSection | lines: 1105–1106 | key: project.home.recent.empty -->

No activity in this project yet. Read documents, take notes, or build a collection while this project is active and it will appear here.

<!-- END SOURCE: project.home.recent.empty -->

#### Footer — A collection can belong to more than one project. Attaching…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectHomeView.swift | ProjectCollectionsEditor.body | lines: 1355–1356 | key: project.collections.manage.footer -->

A collection can belong to more than one project. Attaching it here doesn’t remove it from any others.

<!-- END SOURCE: project.collections.manage.footer -->

#### A collection with no name — Project Home, its Manage sheet, and every other list row

<!-- #1464 (2026-09-30): your option (a). You capitalized the Manage row; option (a) covers both rows.
     Since lane EXPORT (2026-10-01) both Project Home rows — and the Collections list, the Mac window's
     picker, the Research sidebar, its rows and its list title, and the document change review — print
     this one key through `CollectionEditorNaming.listName`, trimmed. The two Project Home keys
     (`project.home.collections.untitled`, `project.collections.manage.untitled`) are gone, so their
     two blocks are this one, the one place the wording lives. -->
<!-- SOURCE: FRUSExplorer/Models/Collection.swift | CollectionEditorNaming.navigationTitle | lines: 967–967 | key: collection.untitled.name | same text also in: FRUSExplorer/Collections/MacCollectionManagerView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Untitled Collection

<!-- END SOURCE: collection.untitled.name -->

#### Empty state — Tag documents while you research, then choose which tags…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectHomeView.swift | ProjectFocusTagsEditor.body | lines: 1504–1505 | key: project.focusTags.empty.detail -->

Tag documents while you research, then choose which tags focus this project’s suggestions here.

<!-- END SOURCE: project.focusTags.empty.detail -->

#### %lld documents · reached from %lld of yours
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectHomeView.swift | ProjectReachVolumeRow.body | lines: 1610–1611 | key: project.reach.volumeDetail %lld %lld -->

%lld documents · reached from %lld of yours

<!-- END SOURCE: project.reach.volumeDetail %lld %lld -->

#### Alert message — Projects keep separate research threads — each with its own…
<!-- SOURCE: FRUSExplorer/ProjectContext/ProjectPickerMenu.swift | SecondProjectNudgeModifier.body | lines: 399–400 | key: project.nudge.secondProject.message -->

Projects keep separate research threads — each with its own collections, notes, and suggestions. Project Home is where you steer one; switch between them from the project menu.

<!-- END SOURCE: project.nudge.secondProject.message -->

#### Empty state — Your research activity will appear here as you open…
<!-- SOURCE: FRUSExplorer/ProjectContext/SessionLogView.swift | SessionLogView.body | lines: 77–78 | key: sessionLog.empty.detail.trail -->

Your research activity will appear here as you open documents, run searches, and export collections.

<!-- END SOURCE: sessionLog.empty.detail.trail -->

#### Research notes, tags, highlights, and collections you add…
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | ResearchView.documentList | lines: 873–874 | key: research.empty.noDocs.allNotes -->

Research notes, tags, highlights, and collections you add from the document view will appear here.

<!-- END SOURCE: research.empty.noDocs.allNotes -->

#### Notes you write on a document will appear here. A document…
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | ResearchView.documentList | lines: 876–877 | key: research.empty.noDocs.hasNotes -->

Notes you write on a document will appear here. A document you have only tagged, highlighted, or collected appears under All Research Documents instead.

<!-- END SOURCE: research.empty.noDocs.hasNotes -->

#### No document you have annotated has changed since it was…
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | ResearchView.documentList | lines: 888–889 | key: research.empty.noDocs.updated -->

No document you have annotated has changed since it was indexed on this device.

<!-- END SOURCE: research.empty.noDocs.updated -->


#### Empty state — Choose a tag or All Research Documents…

<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | key: research.empty.noSelection.detail.v2 -->

Choose a tag or All Research Documents from the sidebar.

<!-- END SOURCE: research.empty.noSelection.detail.v2 -->

### 18.12 Collections, Zotero and the trip packet

*The collection editor and inspector captions, the add-documents sheet, the export sheet's Zotero captions, the headnote and colophon printed in exports, and the trip packet's topic placeholder and footnote citation.*

#### This volume is downloaded but not yet indexed. Indexing…
<!-- SOURCE: FRUSExplorer/Collections/CollectionAddDocumentsSheet.swift | CollectionAddDocumentsSheet.browseDocumentLevel | lines: 1047–1048 | key: collection.addDocs.browse.notIndexed -->

This volume is downloaded but not yet indexed. Indexing normally starts right after download — give it a moment, or check Settings if it doesn’t.

<!-- END SOURCE: collection.addDocs.browse.notIndexed -->

#### Each line is resolved against the FRUS manifest and your…
<!-- SOURCE: FRUSExplorer/Collections/CollectionAddDocumentsSheet.swift | CollectionAddDocumentsSheet.citationsTab | lines: 1195–1196 | key: collection.addDocs.citations.hint -->

Each line is resolved against the FRUS manifest and your local index — footnotes, bibliography entries, and document links all work.

<!-- END SOURCE: collection.addDocs.citations.hint -->

#### Summaries are generated on demand for documents that don’t…
<!-- SOURCE: FRUSExplorer/Collections/CollectionCompositionRows.swift | CollectionCompositionRows.body | lines: 134–135 | key: composition.summaryPrompt.hint -->

Summaries are generated on demand for documents that don’t already have one for this prompt. Requires Apple Intelligence.

<!-- END SOURCE: composition.summaryPrompt.hint -->

#### Choose a summarization prompt in the collection’s…
<!-- SOURCE: FRUSExplorer/Collections/CollectionContentResolver.swift | CollectionResolveError.errorDescription | lines: 40–41 | key: export.summaryNoPrompt -->

Choose a summarization prompt in the collection’s Composition section to export summaries.

<!-- END SOURCE: export.summaryNoPrompt -->

#### Footer — Rendered on the exported title page; the introduction opens…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | CollectionEditorView.frontMatterSection | lines: 1170–1171 | key: collection.frontmatter.footer -->

Rendered on the exported title page; the introduction opens the body, after the table of contents and before the first document. Leave blank to keep the plain document layout.

<!-- END SOURCE: collection.frontmatter.footer -->

#### This is a smart collection. Its documents are resolved from…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | CollectionEditorView.documentsSection | lines: 1210–1211 | key: collection.editor.docs.smartEmpty -->

This is a smart collection. Its documents are resolved from the linked saved search when you export — use Export in Actions below.

<!-- END SOURCE: collection.editor.docs.smartEmpty -->

#### VoiceOver label — Add documents, a section heading, a note block, highlighted…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | CollectionEditorView.iPhoneAddMenu | lines: 1416–1417 | key: collection.add.menu | shared: iOS only -->

Add documents, a section heading, a note block, highlighted passages, or an apparatus block

<!-- END SOURCE: collection.add.menu -->

#### Footer — Search the index, browse volumes, paste citations or…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | CollectionEditorView.addDocumentsSection | lines: 1773–1774 | key: collection.editor.addDocuments.footer -->

Search the index, browse volumes, paste citations or history.state.gov links, or gather a tag. New documents are added to the end of the list.

<!-- END SOURCE: collection.editor.addDocuments.footer -->

#### Field prompt — Overrides the document title in the table of contents and…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryInspector.swift | CollectionEntryInspector.identitySection | lines: 374–375 | key: collection.inspector.titleOverride.caption -->

Overrides the document title in the table of contents and the export heading. Leave blank to use the derived title.

<!-- END SOURCE: collection.inspector.titleOverride.caption -->

#### Checked notes are included when research notes apply to…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryInspector.swift | CollectionEntryInspector.annotationsSection | lines: 445–446 | key: collection.inspector.note.selectionCaption -->

Checked notes are included when research notes apply to this document. Unselecting every note turns notes off for it.

<!-- END SOURCE: collection.inspector.note.selectionCaption -->

#### Checked passages are included when highlights apply to this…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryInspector.swift | CollectionEntryInspector.annotationsSection | lines: 530–531 | key: collection.inspector.highlight.selectionCaption -->

Checked passages are included when highlights apply to this document. Unselecting every passage turns highlights off for it.

<!-- END SOURCE: collection.inspector.highlight.selectionCaption -->

#### Adds a “See also” line listing cross-referenced documents…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryInspector.swift | CollectionEntryInspector.overrideControls | lines: 714–715 | key: collection.inspector.override.related.caption -->

Adds a “See also” line listing cross-referenced documents that are also in this collection. Off unless turned on here or on the section.

<!-- END SOURCE: collection.inspector.override.related.caption -->

#### Default follows the section’s setting when its heading sets…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryInspector.swift | CollectionEntryInspector.overridesSection | lines: 766–767 | key: collection.inspector.overrides.caption -->

Default follows the section’s setting when its heading sets one, else the collection’s composition.

<!-- END SOURCE: collection.inspector.overrides.caption -->

#### Documents in this section use these settings unless they…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryInspector.swift | CollectionEntryInspector.sectionDefaultsSection | lines: 779–780 | key: collection.inspector.sectionDefaults.caption -->

Documents in this section use these settings unless they set their own. Default falls through to the collection’s composition.

<!-- END SOURCE: collection.inspector.sectionDefaults.caption -->

#### Reorder or delete excerpts in the collection list. Insert…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryInspector.swift | CollectionEntryInspector.excerptsSection | lines: 895–896 | key: collection.inspector.excerpts.caption -->

Reorder or delete excerpts in the collection list. Insert new ones from the highlight rows above.

<!-- END SOURCE: collection.inspector.excerpts.caption -->

#### No headnote yet. Edit to write a key takeaway, or generate…
<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryInspector.swift | CollectionEntryInspector.headnoteCard | lines: 992–993 | key: collection.inspector.headnote.empty -->

No headnote yet. Edit to write a key takeaway, or generate a document summary to seed one.

<!-- END SOURCE: collection.inspector.headnote.empty -->

#### Connect a Zotero account to send with your tags & research…
<!-- SOURCE: FRUSExplorer/Collections/CollectionExportSheet.swift | ExportSheetView.zoteroCaption | lines: 676–677 | key: export.zotero.send.caption.iosNoAccount | shared: iOS only -->

Connect a Zotero account to send with your tags & research notes. Without one this saves an RIS file, which Zotero can import on a Mac — not on iPhone or iPad.

<!-- END SOURCE: export.zotero.send.caption.iosNoAccount -->

#### Connect a Zotero account to send with your tags & research…
<!-- SOURCE: FRUSExplorer/Collections/CollectionExportSheet.swift | ExportSheetView.zoteroCaption | lines: 679–680 | key: export.zotero.send.caption.macNoAccount | shared: macOS only -->

Connect a Zotero account to send with your tags & research notes. Without one this saves an RIS file for Zotero’s File → Import.

<!-- END SOURCE: export.zotero.send.caption.macNoAccount -->

#### Send to Zotero Library — the Zotero collection made for a collection with no name
<!-- #1497, your decision D16 (2026-09-28): new in lane EXPORT. Only the Zotero send uses it; a file
     export of the same collection keeps "Untitled Collection". -->
<!-- SOURCE: FRUSExplorer/Collections/CollectionExporter.swift | CollectionExportNaming.zoteroCollectionName | lines: 1548–1549 | key: export.zotero.collection.untitled %@ -->

FRUS Explorer Collection - %@

*(Interpolated with the day of the send, written yyyy-mm-dd in the reader's own time zone.)*

<!-- END SOURCE: export.zotero.collection.untitled %@ -->

#### Collection preview and entry inspector — a Section heading with no text
<!-- #1465, your decision D4 (2026-09-28): the live preview now shows an untitled heading under this
     name, in its body and its Contents, set apart in grey italics; every export leaves the heading
     out, and the editor's own row keeps its "Section heading" prompt. The inspector's identity row
     has always used it. -->
<!-- SOURCE: FRUSExplorer/Models/Collection.swift | CollectionEditorNaming.untitledSection | lines: 1014–1014 | key: collection.inspector.section.untitled -->

Untitled section

<!-- END SOURCE: collection.inspector.section.untitled -->

#### Compiled with FRUS Explorer · \(…) document\(…) from \(…)…
<!-- SOURCE: FRUSExplorer/Collections/CollectionExporter.swift | CollectionColophon.text | lines: 955–956 | key: export.colophon.line -->

Compiled with FRUS Explorer · \(docCount) document\(docCount == 1 ? "" : "s") from \(volCount) volume\(volCount == 1 ? "" : "s") · \(df.string(from: date))

<!-- END SOURCE: export.colophon.line -->

#### No stored summary for this document — generate one in the…
<!-- SOURCE: FRUSExplorer/Collections/CollectionItemHTMLRenderer.swift | CollectionItemHTMLRenderer.headnoteHTML | lines: 442–443 | key: collection.headnote.missing | same text also in: FRUSExplorer/Collections/DocxCollectionExporter.swift, FRUSExplorer/Collections/PDFCollectionExporter.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

No stored summary for this document — generate one in the document view to fill this headnote.

<!-- END SOURCE: collection.headnote.missing -->

#### Showing collections from every project, including ones…
<!-- SOURCE: FRUSExplorer/Collections/CollectionListView.swift | CollectionListView.projectFilterBanner | lines: 386–387 | key: collections.filterBanner.showingAll | same text also in: FRUSExplorer/Collections/MacCollectionManagerView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Showing collections from every project, including ones outside “\(activeProjectDisplayName)”.

<!-- END SOURCE: collections.filterBanner.showingAll -->

#### Showing collections for “\(…)” — \(…) other collection\(…)…
<!-- SOURCE: FRUSExplorer/Collections/CollectionListView.swift | CollectionListView.projectFilterBanner | lines: 399–400 | key: collections.filterBanner.filtered.withHidden | same text also in: FRUSExplorer/Collections/MacCollectionManagerView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Showing collections for “\(activeProjectDisplayName)” — \(hidden) other collection\(hidden == 1 ? "" : "s") hidden.

<!-- END SOURCE: collections.filterBanner.filtered.withHidden -->

#### No content yet. Use the Add menu in the toolbar to add…
<!-- SOURCE: FRUSExplorer/Collections/MacCollectionManagerView.swift | CollectionDetailPane.documentsSection | lines: 1033–1034 | key: collection.documents.empty | shared: macOS only -->

No content yet. Use the Add menu in the toolbar to add documents, headings, notes, and apparatus.

<!-- END SOURCE: collection.documents.empty -->

#### Tooltip — Export this collection as a PDF, HTML page, or Word…
<!-- SOURCE: FRUSExplorer/Collections/MacCollectionManagerView.swift | CollectionDetailPane.toolbarContent | lines: 1421–1422 | key: collection.toolbar.export.help | shared: macOS only -->

Export this collection as a PDF, HTML page, or Word document — includes document text and any attached research notes

<!-- END SOURCE: collection.toolbar.export.help -->

#### Tooltip — Show this document’s notes, highlights, tags, and…
<!-- SOURCE: FRUSExplorer/Collections/MacCollectionManagerView.swift | MacEntryRow.body | lines: 1692–1693 | key: collection.entry.inspect.help | shared: macOS only -->

Show this document’s notes, highlights, tags, and provenance in the inspector panel — click again to close it

<!-- END SOURCE: collection.entry.inspect.help -->

#### Error message — This collection was made with a newer version of FRUS…
<!-- SOURCE: FRUSExplorer/Collections/NativeCollectionFormat.swift | NativeCollectionError.errorDescription | lines: 269–270 | key: collection.import.error.version -->

This collection was made with a newer version of FRUS Explorer (format \(version)). Update the app to open it.

<!-- END SOURCE: collection.import.error.version -->

#### %@, footnote (no printed number recorded).
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketExporter.swift | TripPacketExporter.footnoteLine | lines: 1013–1014 | key: archiveVisit.seeding.footnote.unrecorded %@ -->

%@, footnote (no printed number recorded).

*Interpolated with the document's citation, less its own closing period (#1392) — so the period after the parenthesis is the line's only closing period (the citation keeps any periods inside it, such as “Washington, D.C.”). Keep the placeholder.*

<!-- END SOURCE: archiveVisit.seeding.footnote.unrecorded %@ -->

#### %@, footnote %@.
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketExporter.swift | TripPacketExporter.footnoteLine | lines: 1017–1018 | key: archiveVisit.seeding.footnote.printed %@ %@ -->

%@, footnote %@.

*Interpolated with the document's citation, less its own closing period (#1392), and then the footnote number the volume printed — so the final period is the line's only closing period (the citation keeps any periods inside it, such as “Washington, D.C.”). Keep both placeholders.*

<!-- END SOURCE: archiveVisit.seeding.footnote.printed %@ %@ -->

#### [Describe your research topic in one or two sentences…
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketModel.swift | TripPacketTopicSentence | lines: 50–51 | key: packet.topic.placeholder -->

[Describe your research topic in one or two sentences — narrow and specific. NARA asks for a succinct description, never “everything you have”.]

<!-- END SOURCE: packet.topic.placeholder -->

#### This Zotero key lacks write access to your library. Create…
<!-- SOURCE: FRUSExplorer/Zotero/ZoteroAPIModels.swift | ZoteroAPIError.errorDescription | lines: 193–194 | key: zotero.error.permissions -->

This Zotero key lacks write access to your library. Create a key with write and notes permission.

<!-- END SOURCE: zotero.error.permissions -->
