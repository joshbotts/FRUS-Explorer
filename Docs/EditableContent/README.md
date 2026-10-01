# FRUS Explorer — Editable Static Content (`Docs/EditableContent/`)

These files contain the user-facing editorial prose across FRUS Explorer: the About screen, the
onboarding welcome, the in-app FRUS Research Guide, the Series and Archival analytics dashboards,
the analytics info popovers and captions, the Source Explorer panels, the methods statements
stamped on every export, the Archives Visit planner and its trip packet, the Browse-axis coverage
captions, and the explanatory footers in Settings. Edit the text directly. When you
are done, hand the files back and the changes will be written to the source code.

**What the app shows.** Every block’s text below is what the app ships once lane WB (2026-09-30, the build-49
wave) has written your review back. Eight of your edits were held — a test pins the wording they replace, the
text describes the screen the other way round, it lost words mid-sentence, or it read as a note rather than app copy — and three more ship with a name or phrase changed so they describe the screen as it is; each of the eleven sits under its block in a ✎ box that says why. Your close-out pass, [below](#close-out-pass-2026-09-30), settles them one at a time; the table counts what is still open. The
amendment history that used to fill this paragraph is now the last section, [Amendment-Log.md](Amendment-Log.md).

## The files

The single `Docs/EditableContent.md` was split by app area on 2026-09-28 so each file opens quickly and you can work area by area. Write-back is by key, so a block can be edited in whichever file holds it. Sections keep their old numbers; §6, §14 and §18 were spread across the files by the area each part describes. The owner’s earlier reviewed snapshots are in [History/](History/). The amendment history is [Amendment-Log.md](Amendment-Log.md).

| File | Area | Size | Blocks | ✎ held or changed | ⚑ issues still open |
|---|---|---|---|---|---|
| [01-About-and-Onboarding.md](01-About-and-Onboarding.md) | About & Onboarding | 14 KB | 12 | 0 | — |
| [02-Research-Guide.md](02-Research-Guide.md) | FRUS Research Guide | 42 KB | 11 | 0 | — |
| [03-Repository-README.md](03-Repository-README.md) | Repository README | 12 KB | 1 | 0 | — |
| [04-Series-Analytics.md](04-Series-Analytics.md) | Series Analytics (About the Series dashboards) | 22 KB | 33 | 0 | — |
| [05-Analytics.md](05-Analytics.md) | Analytics — Corpus, Person, Cross-Reference, Chronology, Word Cloud, semantic map | 117 KB | 219 | 0 | — |
| [06-Archives.md](06-Archives.md) | Archives — Archival Analytics, Source Explorer, Archives Visits | 125 KB | 264 | 0 | #1483 |
| [07-Search-and-Browse.md](07-Search-and-Browse.md) | Search & Browse | 103 KB | 216 | 0 | — |
| [08-Reading-Research-Collections.md](08-Reading-Research-Collections.md) | Reading, Research & Collections (and export method statements) | 142 KB | 281 | 0 | #1422 |
| [09-Settings-and-App.md](09-Settings-and-App.md) | Settings & app-wide messages | 83 KB | 183 | 0 | #1483, #1531 (#1476 decided, awaiting lane STOR) |

## How to read this file

- **Block text = what the app shows now.** A block is the text between a `SOURCE` comment and its `END SOURCE`
  comment. Edit it in place; only text inside blocks is written back, by key. (The two blocks under a
  RETIRED banner are the exception: their strings are gone from the app.)
- **✎ = your edit that is not in the app as you wrote it.** It sits directly under its block. Since lane WB
  (2026-09-30) the only ✎ boxes are the eight edits it held and the three it shipped with a name or phrase
  changed, each saying why and quoting your text. To ship one as written, say so and the test that holds it (if
  any) changes with it; to drop it, leave the block alone. The ✎ box itself is never written back.
- **⚑ = an open issue you can close by writing its wording.** Each says what is wrong, gives the options, and
  says how your wording will be applied. A **✎ New string needed** box beside it is for a string that does not
  exist yet (a per-platform or one/many form); it starts as the current text — write your version there.
- **Editor’s notes are not app text.** Lines in *italics*, a trailing *(Interpolated with …)* after a block’s
  text, `>` quotations and `<!-- … -->` comments are notes to you; they are not written back. Keep every `\(…)`
  interpolation and every `%lld` / `%@` / `%1$@` token exactly as written.
- **Quotation marks.** A few blocks keep curly quotes where the source still has straight ones (the 2026-09-20
  amendment below names them); that is the only way a block may differ from the app.
- **What is here.** Every shipped string of prose length — 90 characters or more as the source writes it, the
  rule §18’s header states — plus the shorter strings a surface needs to be read whole (titles, labels,
  one/many forms). The sections: §1 About; §2 Onboarding; §3 the FRUS Research Guide; §4 the Series Analytics
  dashboards; §5 Analytics captions and info popovers; §6 Settings, Tips & Collections; §7 Search and
  result-set copy; §8 the repository README; §9 Archival Analytics; §10 Export method statements; §11 Source
  Explorer; §12 Word Cloud keyness; §13 Semantic Analytics; §14 Short strings bumped since build 42; §15
  Archives Visits; §16 Browse axis captions; §17 Browse load failures; §18 Prose this file had never carried.

## Written back 2026-09-30 (lane WB)

*Your review of these files, handed back 2026-09-30, was written into the app by lane WB of the 2026-09-28 plan of
record. Block by block: a block you changed is your text in the app; a block you left alone kept the app’s text.*

- **111 blocks changed: 103 ship exactly as you wrote them, pages 5 and 6 of the Research Guide ship all but
  one section each, and 6 are held whole — eight held edits in all.** Six were held when your review was
  written back, and two more by the review round below. They are the ✎ boxes: §3.5 *Narrow Without
  Losing Count* (`CorrectedClaimsTests`, `ResearchGuideCoverageTests`), §5 *How dates are determined*
  (`analytics.info.dating.body.v3`) and the export’s dating caveat (`analytics.export.caveat.dating.v2`), which
  `SearchTipsTests` and `AnalyticsExportTests` hold to one wording, and §13’s Semantic Match Feedback privacy
  footer (`settings.semanticFeedback.privacy`), whose added sentence reads as a request for a feature, and §5’s
  *What the graph shows* (`graph.info.what.body`), which gives the graph’s blue and orange nodes each other’s
  meaning; its box carries your text with the two directions swapped and the archival nodes teal, ready to
  adopt; §13’s slice refusal *the two volumes are too alike* (`semanticMap.axis.tooAlike`), whose word “alike”
  `SemanticSliceGuidanceTests` requires; §3.6 *The Language Itself*; and §13.7’s frame-sequence sentence
  (`semanticMap.frames.grain`).
- **Lane WB’s review, round 1 (2026-09-30) held two more and changed three.** Held: §3.6 *The Language Itself*,
  where a clause was lost mid-sentence (“you can see the words most what other terms occur…”; its box offers the
  likeliest repair), and the semantic map’s frame-sequence sentence (`semanticMap.frames.grain`), whose rewording
  drops the refusal the map’s design requires and calls a frame “the selected scope” where a frame is the
  volumes published so far. Changed: the two #1527 not-downloading sentences
  (`search.semantic.results.unscored.notFetching %@ %@`, `search.semantic.empty.notFetching %@`) name
  **Download Vectors for Every Volume**, because **Download Missing Vectors** fetches only for downloaded volumes
  and is usually not on screen; and #1481’s touch text (`graph.info.interact.body.ios`) says “Tap a node” and
  “or open it”, because a touch screen does not click and its long-press menu does not open the main window.
  `graph.info.what.body`’s box now offers the archival nodes as teal, the colour the app draws. Two new ⚑ below
  go back to you with no issue number.
- **Your 2026-09-21 ✎ boxes are gone: 32 boxes, 50 edits.** 22 you adopted as written, 26 you rewrote further when
  you edited the block, and 2 you dropped by leaving the block alone (`series.geography.intro`, and the README’s
  internet-access line under *Requirements*).
- **Corrected in your text, spelling and spacing only:** “refenced” → “referenced” (in the held
  `graph.info.what.body` box), “futher” → “further” (`source.explorer.dividedLot.rationale %lld`), three spaces lost where README lines were
  joined (“the`CLAUDE.md`”, “and`Planning/…`”, “Update`FRUS-API.openapi.yaml`”), the README’s new semantic-map
  image pointed at `Docs/screenshots/ipad/semantic-map.png` (the file the column names), and straight quotation
  marks you typed curled to the app’s style (“long tail”, “leans”, and the apostrophes in *you’ve*, *can’t*,
  *Kennedy’s* and nine more).
- **About’s attribution suffix** now begins with a space in code, because the sentence runs straight on from
  “Claude”; the note under that block says so.

## Close-out pass (2026-09-30)

*You went through the held edits, the changed answers and the open ⚑ one at a time. Each line is what you decided and what shipped.*

- **A1, §3.5 *Narrow Without Losing Count* — shipped, re-revised.** Your text with provenance named as the one facet that is descriptive only; the subjects-facet sentence is gone, so `CorrectedClaimsTests` and `ResearchGuideCoverageTests` pin the facet list (“archival provenance and subjects. Most of those become a filter”) instead.
- **A2, §3.6 *The Language Itself* — shipped with the repair.** Your text with the stray “the words most” deleted.
- **A3, §5 *What the graph shows* (`graph.info.what.body`) — shipped with the repair.** Your text with the two directions swapped (blue incoming, orange outgoing), the archival nodes teal, and “with a document icon” dropped, since a blue node whose volume is not downloaded shows a cloud icon instead. *Reopened the same day:* “Teal nodes with the building icon” was untrue for central-file nodes (cited by decimal number), which were teal but drew the document icon; you chose to fix the graph, so every teal node now draws the building icon.
- **§5 *Undownloaded volumes* (`graph.info.undownloaded.body`), its second paragraph — your wording, new.** It said references from un-indexed volumes “are not shown at all”, out of date since #262: the graph fills in every document that cites this one from bundled data and the orange banner counts them. Your paragraph says so, and that the 2nd- and 3rd-degree neighbors still come only from indexed volumes.
- **A8, §13.8 the Semantic Match Feedback footer (`settings.semanticFeedback.privacy`) — shipped, reworded.** “Stored on-device and not synced to iCloud.” (the file does go into device backups, so “only on this device” was loose), “and when you gave it” added to what a verdict records, and the voluntary route that already exists named: “choose Prepare Feedback File, then Share Feedback File”. Where to send the file is [#1545](https://github.com/joshbotts/FRUS-Explorer/issues/1545).
- **B1, §5 the graph’s touch help (`graph.info.interact.body.ios`) — confirmed as shipped.** “Tap a node” and “or open it”, as lane WB changed them. With it every step of #1481 is done on this branch; relabelling the iOS **Open in Main Window** menu item stays lane GRAPH’s (D9).
- **B2 + B3, §7 Meaning search’s not-downloading sentences (#1527) — confirmed, with “in Settings” added to the empty state.** Both name **Download Vectors for Every Volume**, the one button that fetches files for volumes you have not downloaded, and both now say where it is.
- **C1, §2.1 onboarding Step 2’s captions — closed.** Entire Corpus: “≈ 3.5 GB — the entire series, fully offline. Recommended for full functionality.” Subseries: “A coherent editorial era — recommended if you want to start smaller.” The size counts the 553 match files a whole-series download fetches with Download With Volumes on: 3,338,778,538 bytes of volumes and 162,354,028 of match files, 3.50 GB.
- **C2, §8 the repository README’s semantic-features sentence — closed.** “Semantic features rely on vector embeddings generated ahead of time with Google’s EmbeddingGemma model; searching by meaning runs the same model on your device.” It no longer calls the model open source, which the README’s License section and `NOTICE` contradict (the weights are under the Gemma Terms of Use); the License section keeps the terms.
- **A4 + A5, the dating rule — shipped.** *How dates are determined* (`analytics.info.dating.body.v3`) is your two sentences with “they” made “the editors”, plus “Volume content with no stored date, chiefly front matter, sits at the start year of its volume on By Year and By Decade and is left out of By Month and By Day.” The export caveat (`analytics.export.caveat.dating.v2`) is your text as written. The tests read “editor-annotated date” as the rule’s marker now, and “denominator” is checked on the export only.
- **A6, §13 *the two volumes are too alike* (`semanticMap.axis.tooAlike`) — shipped as you wrote it.** “were measured as so similar”. `SemanticSliceGuidanceTests` now accepts “similar” for this message and refuses both “alike” and “similar” in the no-summary one, which is the build-42 guard.
- **A7, §13.7 the frame-sequence sentence (`semanticMap.frames.grain`) — shipped, re-revised.** “Each frame lights every mapped document in the volumes published so far — whole volumes, whatever each document is about.” Your rewording keeps both facts the map design requires (a frame is the volumes published so far, lit whole) without claiming the lit documents are never about one subject, since some volumes are. `SemanticMapFrameSequenceTests` pins “whatever each document is about” in place of “never the documents about”.
- **#1478’s last three count sentences — closed.** §5, the Word Cloud CSV’s stop lists: only the lists that removed something are named — “1 word from your global hidden-word list was removed before counting”, “3 words from your list for the ‘Concepts’ lens were removed”, or both joined with “were” — each count grouped, with no “word(s)” and no “0 words”. §10.1, the Archival ranking CSV: “Scope: 120 volumes in this era, and 3,665 collections ranked in all under the current weight.”, in the unit lens’s own noun (collections or classes), without “carry at least one document”, which was false for named collections under Volumes and for both lenses under Unprinted pointers. §10.1, the Cited Over Time CSV: no era count, and the buckets as the chart draws them — by decade before 1941, then 1941–1947, 1948–1950 and 1951–1954, FRUS’s own subseries from 1955. With these every item of #1478 is done on this branch.
- **#1476, Volumes & Storage’s hero — decided; lane STOR writes it in.** While measuring: “—” and “Measuring…”. After a failed measurement, on both platforms: “—” and “Could not measure storage”. While volumes are removed: their own clause, “1 being removed” / “%lld being removed”, counted in neither “downloaded” nor “not yet indexed”. The three answers sit in a ✓ note in `09-Settings-and-App.md` until STOR’s fix lands, because the hero is built from them in code this lane does not change.

## Wording issues you can close here (⚑)

*Each ⚑ box states the problem, gives the options and says how your wording will be applied. Where the fix needs a string that does not exist yet, a “✎ New string needed” box beside it holds the current text as a starting point.*

**Still open** — you left each of these untouched on 2026-09-30:

- **#1422** — Chronology’s spanning chip calls every wide-span row an editorial note: §18.10 `chronology.spanning.chip.*`
- **#1483** — keys declared with two texts: §11.1 `source.explorer.unrecognized.explanation`; §18.15’s nine keys
- **#1531** — the red sync banner’s detail line: §18.14 `sync.banner.failed.title`

**Answered and written back on 2026-09-30:** #1481 (the graph’s touch text is `graph.info.interact.body.ios`,
beside the Mac’s `.v2`, with “Tap” and “open it” — its ✎ box says why); #1527 (the two empty-state and two
caption variants, naming Download Vectors for Every Volume — their ✎ boxes say why — and the footer as `.v4`); #1478’s
network dock (`archival.network.dock.summary.v3`); #1483’s `source.explorer.noKey.explanation` (the Mac text is
`.mac`); #1464 (“Untitled Collection” on both Project Home rows); #1531’s Fix iCloud Sync message.

## Changes since your 2026-09-21 review

*What changed in this file between your review (commit 3249b1ea, 2026-09-21) and build 48 (07b9b65c), other than your own edits: blocks whose text was edited by later work, re-keyed or re-pointed, added, or removed. Not listed: the ~519 blocks whose only change is their `lines:` field. Then, separately, the blocks added on 2026-09-27 to prepare this review.*

- **§3.5** — edited page `finding-documents` (§3.5’s *Narrow Without Losing Count*: #1418 restored a clause into your rewrite)
- **§5** — gone `crossRefAnalytics.export.caveat.excluded %lld` (split into one/many forms or re-keyed; see the new blocks beside it); gone `wordcloud.export.caveat.hidden %lld` (split into one/many forms or re-keyed; see the new blocks beside it)
- **§5 (Analytics Export — Word Cloud caveats)** — re-keyed `wordcloud.export.caveat.population %lld %lld %@` → `wordcloud.export.caveat.population %@ %@ %@`; re-keyed `wordcloud.export.caveat.tuning %lld %lld %@` → `wordcloud.export.caveat.tuning %@ %@ %@`; new `wordcloud.export.caveat.hidden.one`; new `wordcloud.export.caveat.hidden.many`; new `wordcloud.export.caveat.countedAsPrinted`; new `wordcloud.export.caption.countedAsPrinted`; new `wordcloud.export.collection.countedAsPrinted`
- **§5 (Analytics Export)** — re-keyed `analytics.export.caveat.corpus %lld` → `analytics.export.caveat.corpus %@`; new `crossRefAnalytics.export.caveat.excluded.one`; new `crossRefAnalytics.export.caveat.excluded.many`
- **§5 (Corpus Analytics)** — new `analytics.prompt.detail`; new `analytics.prompt.detail.mac`
- **§5 (Cross-Reference Analytics — Captions)** — edited `crossRefAnalytics.landmarks.subtitle`; edited `crossRefAnalytics.matrix.subtitle`
- **§5 (Person Analytics)** — edited `personAnalytics.info.compare.detail`
- **§6 (Discovery Tips (TipKit))** — edited `tip.facetNarrow.message`
- **§6 (Research rail)** — new `researchRail.tools.info.heading`; new `researchRail.tile.cite`; new `researchRail.tile.cite.help`; new `researchRail.tile.wordCloud`; new `researchRail.tile.wordCloud.help`; new `researchRail.tile.sources`; new `researchRail.tile.sources.help`; new `researchRail.tile.graph`; new `researchRail.tile.graph.help`; new `researchRail.tile.related`; new `researchRail.tile.related.help`; new `researchRail.tile.share`; new `researchRail.tile.share.help`; new `document.toolbar.share`; new `document.toolbar.share.help`
- **§7.5** — new `search.collocation.unavailable.languageAnalysis`
- **§7.14** — new `savedSearches.empty.detail`; new `savedSearches.empty.detail.mac`
- **§8** — edited `repo.readme`
- **§9** — gone `archival.network.card.detail %lld %lld %@` (split into one/many forms or re-keyed; see the new blocks beside it)
- **§9.2** — re-keyed `archival.ranking.caption %@ %lld %@ %lld` → `archival.ranking.caption %@ %@ %@`; re-keyed `archival.caveats.umbrella %lld %@ %@` → `archival.caveats.umbrella %@ %@`
- **§9.3** — edited `archival.network.node.hint`; new `archival.network.card.detail.counted %@ %@ %@`; new `archival.network.card.detail.partnerUncounted %@ %@`; new `archival.network.card.detail.focusUncounted %@ %@`; new `archival.network.card.detail.noIndex %@ %@`
- **§10.1** — edited `archival.export.caveat.network.grain`; re-keyed `archival.export.caveat.umbrella %lld %@` → `archival.export.caveat.umbrella %@`
- **§11.1** — edited `source.explorer.window.empty.detail`
- **§12.2** — new `wordcloud.keyness.unavailable.languageAnalysis`
- **§12.4** — new `wordcloud.lens.unavailable.names %@ %@`; new `wordcloud.lens.unavailable.classes %@ %@`; new `wordcloud.lens.noTerms.allTerms`; new `wordcloud.lens.noTerms.people`; new `wordcloud.lens.noTerms.places`; new `wordcloud.lens.noTerms.organizations`; new `wordcloud.lens.noTerms.topics`; new `wordcloud.lens.noTerms.actions`; new `wordcloud.lens.noTerms.descriptors`; new `wordcloud.lens.noTerms.concepts`; new `wordcloud.lens.noTerms.sentiment`; new `wordcloud.countedAsPrinted`
- **§13.1** — edited `semanticAnalytics.about.body.v2`
- **§13.3** — edited `semanticMap.axis.needsSecondPole.v2`
- **§13.6** — re-keyed `settings.vectors.auto.a11y.v2` → `settings.vectors.auto.a11y.v3`
- **§15.1** — re-keyed `archiveVisit.coverage.v2` → `archiveVisit.coverage.v3`
- **§15.2** — re-keyed `archiveVisit.editor.summary.v2` → `archiveVisit.editor.summary.v3`; re-keyed `archiveVisit.editor.coverage.v2` → `archiveVisit.editor.coverage.v3`; new `archiveVisit.filter.menu.help`; new `archiveVisit.editor.export.help`; new `archiveVisit.editor.about.help`; new `archiveVisit.editor.more.help`
- **§15.6** — new `archiveVisit.reseed.topic.message`; new `archiveVisit.reseed.topic.keep`; new `archiveVisit.reseed.topic.filled`
- **§16.4** — new `subjects.index.groupFilter.all.one %@`; new `subjects.index.groupFilter.all.many %@ %@`; new `subjects.index.groupFilter.some.one %@ %@`; new `subjects.index.groupFilter.some.many %@ %@ %@`
- **§18.2** — edited `personCoMention.node.hint`; re-pointed `personAnalytics.ranking.subtitle` (the string moved to `PersonAnalyticsCopy.rankingSubtitle`; wording unchanged or as shown); re-pointed `personCoMention.cap.disclosed` (the string moved to `PersonCoMentionGraphViewModel.capDisclosure`; wording unchanged or as shown)
- **§18.3** — re-keyed `archival.ranking.caption.pointers %@ %lld %lld %@` → `archival.ranking.caption.pointers %@ %@ %@`
- **§18.5** — re-keyed `archival.export.caveat.denominator %lld %lld` → `archival.export.caveat.denominator %@ %@`; re-keyed `archival.export.caveat.denominator.uncapped %lld %lld` → `archival.export.caveat.denominator.uncapped %@ %@`; re-keyed `semanticMap.export.caveat.corpus.reach %lld` → `semanticMap.export.caveat.corpus.reach %@`
- **§18.8** — re-keyed `browser.editors.drill.caption` → `browser.editors.drill.caption.v2`; new `people.detail.lifespan`; new `people.detail.lifespan.born`; new `people.detail.lifespan.died`; new `people.era.until`
- **§18.9** — re-keyed `source.explorer.unprinted.footer` → `source.explorer.unprinted.footer.v2`; new `source.explorer.unprinted.row.title %@ %@`; new `source.explorer.unprinted.row.spokenTitle %@ %@`; new `source.explorer.unprinted.row.sameLot`; new `source.explorer.unprinted.row.repeat %lld %lld`; new `nara.lookup.detected.hint.v2`
- **§18.10** — re-pointed `chronology.prompt.detail` (the string moved to `ChronologyView.promptDetail`; wording unchanged or as shown); new `chronology.prompt.detail.mac`; new `chronology.overflow.chip.a11y.one`; new `chronology.overflow.chip.a11y.many`; new `citation.match.unmetFieldsNote`; new `citation.match.linkProseNote`; new `citation.match.unmetFields`; new `citation.match.pageOutside`; new `citation.match.pageOutsideOnePage`; new `citation.match.pageOutsideNote`; new `citation.match.sharedPageNote`; new `citation.match.perDocumentPageNote`; new `citation.match.linkVolumeOnly`; new `citation.match.notYetIndexed`
- **§18.12** — edited `archiveVisit.seeding.footnote.unrecorded %@`; edited `archiveVisit.seeding.footnote.printed %@ %@`

**Added on 2026-09-27 for this review** (all unranged, each read out of the source):

- **§5 (About the Graph popover)** — `graph.info.what.title`, `graph.info.edges.title`, `graph.info.timeline.title`, `graph.info.degree.title`, `graph.info.interact.title`, `graph.info.undownloaded.title`
- **§5 (Chronology)** — `chronology.info.shows.title`, `chronology.info.dates.title`, `chronology.info.chart.title`, `chronology.info.cap.title`
- **§5 (Corpus Analytics)** — `analytics.info.metric.title`, `analytics.info.multiword.title`, `analytics.info.phrase.title`, `analytics.info.stemming.title`, `analytics.info.dating.title`
- **§5 (Cross-Reference Analytics)** — `crossRefAnalytics.info.shows.title`, `crossRefAnalytics.info.matrix.title`, `crossRefAnalytics.info.influence.title`
- **§5 (Person Analytics)** — `personAnalytics.info.shows.title`, `personAnalytics.info.counting.title`, `personAnalytics.info.compare.title`
- **§5 (Source Explorer)** — `source.explorer.info.shows.title`, `source.explorer.info.why.title`, `source.explorer.info.catalog.title`
- **§5 (Word Cloud)** — `wordcloud.info.shows.title`, `wordcloud.info.lenses.title`, `wordcloud.info.filters.title`, `wordcloud.info.tap.title`
- **§6 (Volumes & Storage (Library))** — `settings.hub.summary.downloaded %lld %lld`, `settings.hub.summary.nothingYet`, `settings.hub.summary.someIndexed %lld`, `settings.hub.loading`
- **§9.2** — `archival.info.method.title`
- **§9.4** — `archival.info.flows.scope.title`, `archival.info.flows.browse.title`
- **§11.1** — `source.explorer.noKey.explanation` (iOS text), `source.explorer.unrecognized.explanation` (iOS text)
- **§11.4** — `source.explorer.nara.outsideCustody` (iOS text)
- **§12.1** — `wordcloud.info.measure.title`, `wordcloud.info.keyness.numbers.title`
- **§12.4** — `wordcloud.lens.unavailable.title`, `wordcloud.lens.noTerms.title`
- **§14 (Archival Flows)** — `archival.info.flows.ibid.title`, `archival.info.flows.mixed.title`
- **§18.3** — `archival.measure.detail.documents.uncounted`
- **§18.4** — `series.chart.lag.a11y.v2`
- **§18.10** — `chronology.spanning.chip.one`, `chronology.spanning.chip.many`, `chronology.spanning.chip.a11y.one`, `chronology.spanning.chip.a11y.many`
- **§18.11** — `project.home.collections.untitled`, `project.collections.manage.untitled`, `research.empty.noSelection.detail.v2`
- **§18.14** — `sync.banner.failed.title`, `sync.banner.zoneMissing.detail`
- **§18.15** — `analytics.export.column.occurrences` (two blocks), `archiveVisit.picker.new` (two blocks), `browser.volume.partial` (two blocks), `graph.panel.close.a11y` (two blocks), `series.geography.totals.title` (two blocks), `series.geography.trend.y` (two blocks), `series.provenance.trend.y` (two blocks), `wordcloud.scope.corpus` (two blocks), `graph.resetView.a11y` (two blocks)

---


**The 2026-09-20 amendment (build 48)** re-ran the mechanical sweep over every block — the first
full pass since build 44 — and, for the first time, also ran it in reverse, over every string the app
ships, to find the ones with no block at all. The comparison decodes each Swift literal the way the
compiler does (multi-line indentation, `\` line continuations, interpolations), so a block is checked
against the text a reader sees rather than against a pattern's guess at it.

 - **The forward half found seven defects, and four were in this file's own mechanics rather than
   in the source.** The §5 *How dates are determined* block (`analytics.info.dating.body.v3`) had
   been the two characters `%s` since #1306 wrote it — a substitution that never ran, so the row had
   no text to edit; it now carries the shipped sentence. The two §14 Chronology blocks
   (`chronology.agg.editorial.v2`, `chronology.agg.volumes.v2`) had been cut off at their first
   quotation mark since #976 generated them. The §6 Rebuild From Scratch message
   (`settings.hub.rebuild.message.v2`) had shown its placeholder as a bare `(volumes)` and its
   paragraph break as a literal `\n\n` since #947. The other three had drifted from source: the §13
   Semantic Match Feedback intro (`settings.semanticFeedback.what`) still said the semantic axis "is
   off by default", which stopped being true in build 47, when D-D put semantic matching on by
   default — the source was corrected at #1265 and this block was not;
   the provenance lens caption (`semanticMap.lens.provenance.caption.v2`, §14) said 498 volumes where
   the source has said 499 since #1268; and **the §8 README mirror** still said build 37 and 552
   volumes, and lacked four things the real README had gained (the Agentic Analysis guide, the Gemma
   license paragraph, the facet sort/page/filter line, and the institutions that hold non-NARA
   records). §8 has been replaced wholesale with `README.md` as it stands at build 48.
 - **Eight of the ten RETIRED blocks were not retired.** Their strings still ship, word for word,
   under keys that had gained their format placeholders — `search.collocation.unavailable.floor` is
   now `search.collocation.unavailable.floor %lld` — which is the case the 2026-08-19 sweep
   repointed nineteen times. These eight it marked RETIRED instead, giving reasons ("consolidated
   into …scope.v2", "replaced by the specific reasons") that the source does not bear out: all four
   collocation strings are still assembled into the Collocations caption and refusals (§7.5), and
   the four working-corpus strings still warn in the Save Working Corpus sheet and the search filters
   (§7.7). They are repointed at their live keys with their banners removed, so an edit to them now
   reaches the app. A fifth caveat from the same caption, `search.collocation.caveat.perDocument
   %lld`, had no block and now has one beside them. Two blocks stay RETIRED, correctly:
   `settings.erase.warning.trail` (removed with R-2b) and `search.kwic.show.help.v2` (no such
   control remains).
 - **Everything else verifies.** Of the 755 blocks that were here before this sweep, 699 now match
   the source exactly once whitespace and the italic editor's notes some blocks carry are set aside
   (fourteen of them only after the repairs above), and 31 more once a `%lld` or `%@` is read as the
   interpolation it stands for. The rest are the two RETIRED blocks, the README, the seven
   quote-only blocks below, and fifteen page, multi-key and property blocks checked by hand: all 50
   keys named on the four dashboard pages (§3.8–§3.11) are live; the guide pages, onboarding,
   attribution and word-cloud blocks match their source apart from the three guide headings below;
   and §2.2's undisplayed intro text differs only in its quotation marks.
 - **Ten differ from the source only in straight versus curly quotation marks, and in every case this
   file has the curly form**: seven blocks (`about.frus.description`,
   `analytics.exactUnsupported.detail`, `source.explorer.presLib.offline.provenance`,
   `source.explorer.parisPeace.provenance`, `semanticAnalytics.about.body.v2`,
   `semanticAnalytics.about.experimental`, `browser.clusters.caption`) and three Research Guide
   headings (*…Department of State’s Office of the Historian*, *Understanding What You’re Reading*,
   *Don’t Forget What You’re Not Reading*). The #1195 pass curled this file but missed the source's
   multi-line (`"""`) literals and the guide's raw strings. They are left curly here, because that is
   the wording the owner asked for; **the port of the next editorial pass owes the source the curl**,
   whether or not these blocks are edited. Four §18 strings have the same gap, and two carry British
   spellings the en-US sweep missed; §18's header names them.
 - **The reverse half added §18: 296 keys in 298 blocks this file had never carried.** 257 of them
   already shipped at build 44, in surfaces the opening paragraph claims — Settings footers,
   analytics captions, Source Explorer panels, export method statements — so this is mostly a
   standing gap closed rather than new material. §18's header gives the rule that selected them and
   how to read a block.
 - **The `lines:` fields were recomputed** against the build-48 source in a separate commit: of the
   635 keyed blocks that carried one before this sweep, 421 had drifted by more than two lines and
   180 by more than fifty. They remain advisory, and they will rot again; `key:` is still the
   address. *(Superseded 2026-09-26: since #1424 a test keeps every ranged block on its key — see
   the note on the `lines:` field below.)*
 - Not changed: the two blocks still RETIRED, the dated snapshots beside this file, and anything
   the verification did not flag.

**The 2026-08-29 amendment** re-ran the mechanical sweep over all 466 blocks after build 44 was
tagged. The verification half came back clean: every block's key is live, and the only source
strings whose wording moved since the last amendment are one interpolation-variable rename with
identical visible text (`appendix.caveat.zero.many`) and one capitalization fix on a window title
this file does not carry (`packet.title`). The build-43/44 feature PRs that added long strings
mostly added their blocks as they went (§1.4a–d, §7.12, §13.5's lexical twin), which is why the
sweep found no rot — the additions below are the surfaces that DIDN'T bring their blocks:

 - **§15 Archives Visits** — the build-44 flagship (#1086–#1097) shipped ~120 new strings and none
   had a block: the plan list and Mac manager, the editor's coverage/derivation states, the
   research-targets info popover (the two-claims definition and both sparsity disclosures), the
   tier/orphan/substitution prose, and the rescoped packet sheet's empty states and topic captions.
 - **§16 Browse — the axis captions** — a standing gap, not a new one: the coverage statements on
   the Clusters, Archives, Administrations and Subjects browse axes were never carried. Each is a
   numbers-bearing method sentence, exactly this file's material.
 - New blocks inside existing sections: the Meaning-search caveats the method appendix gained at
   #1127 (§7.8), the Meaning strip's filters caveat (§7.12), the archival export's grain and
   pointed-at method sentences (§10.1 — pre-baseline gaps), the map's figure-export caveats from
   W-3/W-2a (§13.7), the Semantic Match Feedback screen (§13.8 — shipped earlier, never carried),
   the Flows ⓘ's `Ibid.` disclosure beside its mixed-systems sibling (§14), the classification
   override's rail warning and Settings corrections list from W-4/#1097 (§14), the exact-word
   charting refusal (§5), and the storage hubs' remove-volume confirmations with their side-loaded
   variants (§6).

**The 2026-08-23 amendment** verified every block's prose against the source string it names —
mechanically, block by block — and repaired the twenty that had drifted since build 42. Most of the
drift came from four passes that edited strings without touching this mirror: the #838 archival
copy pass (footers shortened, prose moved into ⓘ items), the #834 central-file channel (the Flows
scope ⓘ and the graph's help now describe three citation kinds, not two), the #1052 subject-facet
rewrite (categories are headings, not scopes), and the American-spelling copy guard
(coloured/centre/recognise → colored/center/recognize). It also **filled three §13 blocks that had
been empty since they were written** (the map's About body, the experimental-standing line, and the
layout caveat), repointed a §13 block that carried the slice's *horizontal* caption under the
*vertical* caption's key, replaced the retired graph help block with the live
`graph.info.interact.body.v2`, and added the blocks the post-42 features grew:
`archival.info.library.*` (#838's moved Your-Library rule) and `graph.context.centralFile` (#834's
class nodes).

The build-42 amendment adds **§13**, which covers the semantic map and the Settings section that
governs its files — a surface this file had never carried, and which grew a great deal in this
release. It also refreshes four blocks in §6 and §7 whose text *and* localization key changed in the
build-42 plain-language pass, so the prose here matches what ships. Every string in §13 was read
out of the source rather than transcribed.

Those short strings now have blocks: **§14** carries the storage hubs' reindex controls, the
document reader's person and term popovers, the Collections search-unavailable notice, the Zotero
rate-limit error, and every other key the build-42 and build-43 sessions bumped without a block —
31 in all, each read out of the source.

**The plain-language pass (2026-08-09).** 126 of the app's longest strings were rewritten to read
more plainly, and 122 of them changed. The rule was that plainer must not mean vaguer: every
number, every stated limitation, and every refusal to claim more than the data supports survives,
usually promoted out of a trailing clause into a sentence of its own. If a revision below reads as
having *lost* a caveat rather than unpacked one, that is a defect — say so and it goes back.

Five rewrites were rejected during review because the plainer wording claimed more than the
original: "most heavily used" for a ranking that measures how many volumes cite a collection;
"covers the whole series" for what was only an independence claim; "exact phrase" for an index
that is stemmed and has a separate exact-word mode; "the collections cited alongside it" for a
graph that also draws class nodes; and "arrangement" for the app's own named Composition setting.
They are recorded here because they are the failure mode to watch for in your own edits.

**What is new in this regeneration**
 - **§9 Archival Analytics** — the four modes (Collections, Network, Flows, Your Library), their
   captions, caveat blocks, empty states and info popover. None of it was in this file before.
 - **§10 Export method statements** — the prose stamped above the numbers in an exported CSV or
   figure, for the archival surfaces and for the four About-the-Series dashboards. This is what a
   reader sees when the file has traveled without the app, so it has to stand alone. (§5 already
   carried the corpus, Person, Cross-Reference and Word Cloud statements.)
 - **§11 Source Explorer** — the panel prose: what a citation resolved to, what it did not, and
   what to do about it. Note that nearly every key here exists twice, once per platform.
 - **§12 Word Cloud keyness** — the two measures, and every state in which the app refuses to
   score rather than show a number it cannot stand behind.
 - Smaller additions inside existing sections: a **Display & Reading** subsection in §6, the
   heat-matrix subtitle in §5, the detected-topic facet footers in §7, and the Data & Recovery
   strings for schema-pending and store-mismatch.
 - **§7.11 has been moved** back inside §7, where it belongs; it had been sitting after the README.

**Earlier amendments**, kept for the record: 2026-08-01 (#597 PR 2) added seven Research Guide
sections for the Query & Corpus Analysis wave to §3; 2026-08-02 (build 37) added §7 and §8,
rewrote §6's Discovery Tips block, and corrected three stale Research Guide blocks.

**A note on the `lines:` field.** Since #1424 (2026-09-26) a ranged block's range is kept on its
key: `EditableContentKeyTests` fails when a block's key is not inside its `lines:` range, so every
range in this file names lines that hold its key, and you can navigate by it. (Before that nothing
checked, and the ranges rotted — a third had drifted within five weeks of one regeneration.) A block
with no `lines:` field is not checked, and a RETIRED block carries none. **`key:` is still the
address**: revisions are written back by key, never by line number.

**Blocks whose key the code no longer has are now marked in place.** A sweep on 2026-08-19 checked
every one of the 443 blocks against the source and found **31** naming a key that is absent from the
file they point at — the three this note used to list, plus 28 nobody had noticed. Editing such a
block has no effect: the revision is mapped back by `key:`, and there is nothing to map it to.

Nineteen were repointed mechanically, because the key had only gained its format placeholders
(`related.why.cohort` → `related.why.cohort %@ %lld`) or a version suffix (`archival.info.weights.*`
→ `.v2`). Three more were repointed after reading the source and confirming the string had simply
been renamed with its wording intact — including the two `tip.examineResults.*` keys this note used
to defer as an editorial call; they are `tip.examine.*` now, and the prose matches.

The remaining **eleven** carry a ⚠️ RETIRED banner naming what happened to the string. Their text is
left in place rather than deleted, because deciding whether copy went away with its feature or is
worth re-attaching somewhere is an editorial call, not a mechanical one.

`FRUSExplorerTests/EditableContentKeyTests` now fails the suite when a block names a key the source
does not have, so this cannot silently accumulate again.

**How annotations work:** Each editable block is preceded by an HTML comment that
identifies the exact source location. Do not remove or alter the annotation comments —
they are how your revisions get mapped back to code. You can edit anything between
the comments freely, including adding or removing paragraphs, restructuring bullet
lists, and changing headings.

---

## About §14 and §18

## 14. Short strings bumped since the build-42 pass

*The strings the §13 header promised blocks for — the storage hubs' reindex controls, the
reader's person and term popovers, the Collections search-unavailable notice, the Zotero
rate-limit error — plus every other short string whose localization key was bumped by the
build-42 and build-43 sessions without gaining a block here. Grouped by surface rather than
by section, because each is one or two sentences and an editor working on one is working on
its screen, not on a theme. Every string below was read out of the source, key and line
included, like everything else in this file. A few strings carry Swift interpolations —
`\(HubCopy.volumes(failures))` and the like; keep them intact exactly as written, as the
placeholder notes elsewhere in this file already require. The §13 standing rule applies
unchanged: plainer must not become more confident.*


## 18. Prose this file had never carried (build-48 sweep)

*Every shipped string of prose length — 90 characters or more as the source writes it — that had no
block anywhere in this file when the build-48 sweep ran on 2026-09-20, plus eleven shorter strings
new since build 44 that state a method, a limit or a count's meaning (the Meaning-mode
search prompts, the My Tags count caption from #1310, the trip packet's footnote citation from #1322,
the class-axis caption, and the like). **296 keys in 298 blocks**: three keys carry different wording
in their iOS and macOS files, and each wording has its own block. Those counts are the sweep's; §18
now holds **349 blocks**, because later changes added blocks after it, most of them short
templates shorter than the sweep's rule. #1370 (2026-09-23) added four to §18.8 — the person sheet's three lifespan lines,
and the active-years form for a list entry that names only the year its holder left — carried
because they replaced a footer line or a year the row used to show, and sit under a person's name.
#1387 (2026-09-24) added two to §18.10 — the Chronology overflow chip's VoiceOver label, one form
for one document and one for several — carried because it is the only place VoiceOver hears the
chip's breakdown. #1390 (2026-09-24) replaced §18.9's Unprinted Material footer with a re-keyed
one and added four short templates after it — a row's footnote-first title, its VoiceOver form,
the same-lot marker and the number for rows worded alike — carried because they replaced the
unit-only row the old footer sat under. #1380 (2026-09-25) added two: to §18.9 the NARA Lookup's
Detected in This Passage hint, which its “tap one” → “select one” took from 89 characters to 92,
past the sweep's rule; and to §18.10 the Mac's own Chronology empty state beside the iOS one,
because the Mac's names the Show button with “click” under a key of its own. #1474 (2026-09-26) added seven Citation Lookup notes to §18.10 — `citation.match.unmetFields`,
`citation.match.unmetFieldsNote`, `citation.match.linkProseNote`, `citation.match.linkVolumeOnly`,
`citation.match.pageOutside`, `citation.match.pageOutsideOnePage` and `citation.match.pageOutsideNote`;
#1503 (2026-09-26) added `citation.match.sharedPageNote` and `citation.match.perDocumentPageNote`; and #1522
(2026-09-27) added `citation.match.notYetIndexed`. The 2026-09-27 review preparation added the rest: blocks for
the strings of open wording issues, the six prose strings new since 2026-09-21 that had none, and §18.15.*

*Most of this is a standing gap, not new work. **257 of the 296 keys already shipped at build 44**,
in surfaces this file's opening paragraph says it covers — the Settings footers, the analytics
captions, the Source Explorer panels, the export method statements — and no earlier sweep went looking
for them; the 2026-08-29 amendment found one such gap (§16) by chance. 35 are new between builds 44
and 47, and 4 since build 47. The census that found them is the same one that verified every other
block in this file: each string was decoded from its Swift literal — multi-line indentation,
continuations and interpolations included — so the text below is what ships, character for character.*

*How to read a block. The heading is the string's opening words, prefixed with its role wherever the
code makes the role unambiguous: a **Tooltip** (hover text), a **Footer** under a settings or list
section, an **Empty state**, an **Alert message**, an **Error message**, a **VoiceOver** label, value
or hint, or a **Field prompt**. `shared:` appears only where an `#if os(…)` in the source proves the
string is compiled for one platform; many strings live in views that only one platform presents, and
this section does not guess which. `same text also in:` names every other file declaring the key with
the same wording — an edit is applied to all of them.*

*The standing rules apply unchanged. Keep every `\(…)` interpolation and every `%lld` / `%@` / `%1$@`
token intact, including the positional numbers. Plainer must not become more confident. Shorter
strings — button labels, bare VoiceOver labels, row templates such as `\(count) volumes · edited
\(date)` — stay out of scope, as they always have; sixteen strings that clear 90 characters only
because of their interpolation code were left out for that reason.*

*These blocks show the source exactly, including what the two copy passes missed: four carry straight
apostrophes the #1195 pass did not curl (`browser.volume.subjects.none`, `project.reach.caption`, and
both `settings.projects.list.footer.order` keys), `project.reach.caption` spells “neighbours” and
`semanticMap.lasso.emptyInScope.detail` spells “coloured”. Correct them here like any other edit.*
