# EditableContent — Search & Browse

Part of the owner’s editing surface, `Docs/EditableContent/` (read `README.md` there first). Covers §7, §16, §17, §18.1, §18.7, §18.8. Every block’s text is what the app ships after lane WB wrote your 2026-09-30 review back (the build-49 wave); the ✎ boxes that listed your unlanded 2026-09-21 edits are gone, each adopted where you changed its block and dropped where you left it alone. Section numbers are the ones the single file used, so references like “§18’s rule” still point somewhere.

**In this file:** 216 blocks · no ✎ edits held or changed · no ⚑ wording issues

---

## 7. Search & Result-Set Copy
*The Query & Corpus Analysis wave (#602–#623) and the eight-issue wave (#629–#641). This material
is neither an analytics caption nor a settings footer — it is the prose that tells a researcher
what a number covers — so it has its own section. Almost all of it exists because a count that does
not say what it counted is worse than no count.*

---

### 7.1 The Query Inspector

*Source: `FRUSExplorer/Search/QueryInspectorView.swift`*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.expressionsDiffer -->

Documents and your own summaries/notes are searched with different expressions, because only some of them are in scope.

<!-- END SOURCE: search.inspector.expressionsDiffer -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.stemWarning -->

*Interpolated: `\(term) is searched as \(stem) — other words with that root match too`. Keep both placeholders.*

%@ is searched as %@ — other words with that root match too

<!-- END SOURCE: search.inspector.stemWarning -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.denominator -->

*Interpolated with the indexed-volume count.*

Counts are over the %lld volumes indexed on this device — not the whole published series.

<!-- END SOURCE: search.inspector.denominator -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.excludedDetail.v2 -->

excluded — documents containing this are removed wherever the expression above applies it

<!-- END SOURCE: search.inspector.excludedDetail.v2 -->

Note: the detail line under a term tagged EXCLUDED. Replaces `search.inspector.excludedDetail` (“excluded — documents containing this are removed”), which never had a block here; re-keyed for #1297, because an exclusion is not a removal from the whole result set: it applies where the MATCH expression above applies it. A `-` or NOT on a word never reaches across OR, but excluding a group that holds a word to search for reverses the marks inside it, and that can join the alternatives of an OR typed inside the group — `NOT (cold OR -korea)` removes cold from korea’s matches — so the line points at the expression rather than at the words typed beside the term. (A group made only of exclusions still just excludes them: `cold -(-korea)` is `cold -korea`.)

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.notAppliedTag -->

NOT APPLIED

<!-- END SOURCE: search.inspector.notAppliedTag -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.notAppliedDetail -->

not searched — this part of the query only excludes, and a search needs something to find, so it was left out

<!-- END SOURCE: search.inspector.notAppliedDetail -->

Note: the tag and detail line on a term the query typed but its expression leaves out — the `-korea` in `cold OR -korea`, or the `war` in `-(war -korea)`, which excluding the group turns into a part of its own that only excludes (#1297). Such a term is never counted or blamed. Reworded in place before shipping for #1297 round 1: it said “an OR alternative made only of exclusions has nothing to search for”, which blamed an OR on `-(war -korea)`, a query that types none.

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.structuredTag -->

ADVANCED

<!-- END SOURCE: search.inspector.structuredTag -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.approximateCaption -->

Narrower than typed: part of this query only excludes terms, and a search needs something to find, so that part was left out.

<!-- END SOURCE: search.inspector.approximateCaption -->

Note: the tag marks a term that came from a structured field — the phrase, prefix or excluded terms a restored saved search carries beside the typed text — rather than from the search box; such a term is counted like any other. The caption sits under the MATCH line whenever the expression matches less than the query means (#1297). It is the only report when what was left out is a demoted operator word, which has no term row: `-( -korea NOT )` searches `korea` alone.

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.refused -->

*Interpolated with the nesting limit, `FTS5InlineQueryParser.maximumGroupDepth` (32). Keep the placeholder.*

No expression — this query cannot run: nothing is left to search for once its exclusions apply, or its parentheses nest more than %lld deep.

<!-- END SOURCE: search.inspector.refused -->

Note: shown in place of the MATCH line when the query holds something to search for and the parser refuses it — only exclusions (`-korea`), an approximation that could match nothing (`-(war -korea) -korea`), or groups nested past the limit — and the search throws (#1297 round 1). Before it, such a query showed no strip at all, and beside a person or subject filter the strip said “this query is filters only”, which was false. Not shown for text with nothing searchable in it, such as a lone `"`, `(` or `=` typed on the way to a query (#1297 round 2): the parser refuses that too and the search throws, but neither reason in the line is true of it, and the strip shows while the researcher pauses mid-typing, so it shows nothing. An operator word the parser searches as a word counts as something searchable (#1297 round 3): `-(or)` and `NOT (AND)` exclude the words or and and, have nothing left to search for, and show the line.

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.empty.combination -->

Each of your terms matches something on its own — it is the combination that appears in no single document.

<!-- END SOURCE: search.empty.combination -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.empty.oneEmpty -->

*Interpolated with the term that matched nothing.*

%@ matches no document in your current scope. The rest of your query is not the problem.

<!-- END SOURCE: search.empty.oneEmpty -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.empty.denominator -->

*Interpolated with the indexed-volume count.*

0 here means 0 in what you have indexed — %lld volumes on this device.

<!-- END SOURCE: search.empty.denominator -->

---

### 7.2 Reading a Result Set — the four modes

*Source: `FRUSExplorer/Search/SearchView.swift, SearchSheet.swift`*

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | lines: 1086–1087 | key: search.mode.help.v2 -->

Read the results you have as a timeline, as your search term in context, or as the words that occur near it — or break the whole match down by year, volume, person, document type, archival provenance and subject.

<!-- END SOURCE: search.mode.help.v2 -->

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1145–1146 | key: search.facets.on.help.v3 -->

Break the whole match down by year, volume, person, document type, archival provenance and subject — before any narrowing you apply

<!-- END SOURCE: search.facets.on.help.v3 -->

> ⚠️ **RETIRED — editing this block has no effect.** No line holds it: #923 replaced the Search window's reading
> toggles with one Reading picker, whose tooltip, `search.reading.help %@` (§18.1), now states this page
> denominator. Kept so the wording is not lost; delete it when you next revise this section.

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | key: search.kwic.show.help.v2 -->

Show every occurrence of your term on its own line, aligned — for the documents on this page

<!-- END SOURCE: search.kwic.show.help.v2 -->

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1772–1774 | key: search.cap.tooltip -->

*Interpolated with the loaded and total counts.*

Showing %lld of %lld matches. Narrow your search with a date range, volume filter, or more specific terms to see every result.

<!-- END SOURCE: search.cap.tooltip -->

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1777–1779 | key: search.cap.tooltip.unknownTotal -->

*Interpolated with the loaded count.*

Showing the first %lld matches. The total could not be counted, so there may be many more — narrow your search with a date range, volume filter, or more specific terms.

<!-- END SOURCE: search.cap.tooltip.unknownTotal -->

---

### 7.3 Facets

*Source: `FRUSExplorer/Search/FacetPanelView.swift`*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.preamble.detail -->

Facets read the whole match, before any narrowing you apply below.

<!-- END SOURCE: facets.preamble.detail -->

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.preamble.meaning %@ -->

*Interpolated with the result count. The header of the facet panel for a MEANING search — where the counts describe the results themselves rather than a wider match the list only samples.*

Describing the %@ closest matches

<!-- END SOURCE: facets.preamble.meaning %@ -->

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.preamble.detail.meaning -->

*The meaning-mode counterpart to the line above. It is the opposite claim, and both are true of their own route: a keyword search's facets read past the capped list into the whole match, while a meaning search's describe exactly the ranked results — which is why narrowing to a row returns precisely its documents (#1193).*

Counted over the results themselves, not the whole corpus. Narrowing to a row returns exactly its documents.

<!-- END SOURCE: facets.preamble.detail.meaning -->




<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.closest %@ -->

*The results header for a meaning search, on both platforms. It replaces the keyword grammar's "N loaded · total unavailable", which asserts a total exists and could not be counted — a similarity ranking has no total, because every document is a match at some distance.*

%@ closest matches

<!-- END SOURCE: search.count.closest %@ -->

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.checklistNote -->

*Interpolated with the shown count.*

Checklist mode is hiding reviewed results. These facets still describe the whole match, not the %lld shown.

<!-- END SOURCE: facets.checklistNote -->

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.undated -->

*Interpolated with the undated count.*

%lld matched documents carry no date and appear in no year above.

<!-- END SOURCE: facets.undated -->

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.provenance.coverage -->

*Interpolated with three counts. This is the two-denominator caveat — parsed at all vs. named a record group — and both numbers matter.*

Source notes parsed for %lld of %lld matches; %lld name a record group.

<!-- END SOURCE: facets.provenance.coverage -->

---

#### Detected-topic facet — footer

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 958–959 | key: search.subject.facet.footer -->

Experimental. These topics are experimental enrichment data, not editorial subject headings reviewed as part of the FRUS publication process, so some are wrong. Choose a sub-category: categories themselves are headings, because each one reaches most of the series. The volume count beside each row says how many it selects, and the volume picker then fills with the matches you have indexed.

<!-- END SOURCE: search.subject.facet.footer -->

---

#### Detected-topic facet — picker footer

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 1486–1487 | key: search.subject.facet.picker.footer -->

Detected topics (experimental). These are inferred from the text, not editorial subject headings, so some are wrong. A volume appears when any document in it carries the topic — mentioned is enough. Categories are headings, not filters — every one of them reaches most of the series — so open a category and choose a sub-category, and check the volume count beside each. For finer topics, browse the Topic index.

<!-- END SOURCE: search.subject.facet.picker.footer -->

---

### 7.4 Concordance (keyword in context)

*Source: `FRUSExplorer/Search/ConcordanceView.swift`*

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.empty.detail -->

These results matched, but none of their text could be aligned on your search term. Phrase, wildcard and proximity searches match in ways a concordance cannot center on a single word.

<!-- END SOURCE: search.kwic.empty.detail -->

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.omitted -->

*Interpolated with the omitted count and the per-document line cap.*

%lld further occurrences aren’t shown — each document contributes at most %lld lines.

<!-- END SOURCE: search.kwic.omitted -->

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.unaligned -->

*Interpolated with a document count.*

%lld matching documents contributed no line — their match isn’t a whole word this view can center on.

<!-- END SOURCE: search.kwic.unaligned -->

---

### 7.5 Collocation — the words near your term

*Source: `FRUSExplorer/Search/CollocationView.swift`*

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.noArtifact -->

The bundled corpus reference could not be loaded, so there is nothing to measure these neighborhoods against.

<!-- END SOURCE: search.collocation.unavailable.noArtifact -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.mismatch %@ -->

*Interpolated with the setting that differs.*

Your Word Cloud settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to rank these neighbors.

<!-- END SOURCE: search.collocation.unavailable.mismatch %@ -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.languageAnalysis -->

*Added by #1373. Shown when this device's lemmatiser failed its check. Reworded by #1539: the app now checks again each time it becomes active, and the panel rebuilds when a check finds the lemmatiser working.*

This device’s language analysis isn’t reducing words to their dictionary forms right now, so the words near your matches can’t be compared with the corpus reference, which was counted that way. FRUS Explorer checks again each time you come back to it, and this panel updates if it recovers; if it doesn’t, quitting and reopening FRUS Explorer may restore it.

<!-- END SOURCE: search.collocation.unavailable.languageAnalysis -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.noMatches -->

None of these results contains a whole word this measure can center on. Phrase, wildcard and proximity searches match in ways a word window cannot anchor to.

<!-- END SOURCE: search.collocation.unavailable.noMatches -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.floor %lld -->

*Interpolated with the minimum-count floor.*

No word appears at least %lld times near your matches. A word used once or twice can top a ranking while telling you nothing about the documents, so nothing is ranked. Widen the window or run a broader search to give this more text to read.

<!-- END SOURCE: search.collocation.unavailable.floor %lld -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.nothingDistinctive -->

Nothing near your matches is used more here than across the corpus. That is a real result, not an error: this query sits in ordinary FRUS prose.

<!-- END SOURCE: search.collocation.unavailable.nothingDistinctive -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.caveat.bounded.v2 %lld %lld -->

*Interpolated with the scanned and total counts.*

The scan stopped at %lld of your %lld results, so this ranking covers part of them, not all.

<!-- END SOURCE: search.collocation.caveat.bounded.v2 %lld %lld -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.caveat.perDocument %lld -->

*Interpolated with the number of matches skipped. Shown only when the per-document cap dropped some.*

%lld further matches were skipped so no single document can dominate.

<!-- END SOURCE: search.collocation.caveat.perDocument %lld -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.caveat.unpriced %lld -->

*Interpolated with the reference cutoff.*

Words occurring fewer than %lld times corpus-wide are unpriced and score as if new.

<!-- END SOURCE: search.collocation.caveat.unpriced %lld -->

---

### 7.6 What a reading actually covers

*Source: `FRUSExplorer/Search/ResultSetScope.swift`*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.collocation.caveat.scope.loaded.capped -->

Measured over every result this search loaded, not the page on screen — those are the highest-scoring matches, not a sample of all of them.

<!-- END SOURCE: search.collocation.caveat.scope.loaded.capped -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.collocation.caveat.scope.loaded.complete -->

Measured over every result this search loaded, which is every matching document.

<!-- END SOURCE: search.collocation.caveat.scope.loaded.complete -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.timeline.bias -->

These are the highest-scoring matches, not a sample across time — this shape is theirs, not the whole match’s.

<!-- END SOURCE: search.timeline.bias -->

---

### 7.7 Working corpora

*Source: `FRUSExplorer/Settings/WorkingCorporaView.swift, SaveWorkingCorpusSheet.swift, SearchFilterView.swift`*

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpora.footer -->

A working corpus is a fixed set of documents, captured once. The whole set syncs to your other devices. A count taken inside it therefore means the same thing on every device, even where fewer of its volumes are indexed.

<!-- END SOURCE: corpora.footer -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpora.empty.detail -->

Run a search, then choose “Save as Working Corpus” to fix those results as a named set you can search inside later.

<!-- END SOURCE: corpora.empty.detail -->

<!-- SOURCE: FRUSExplorer/Search/SaveWorkingCorpusSheet.swift | lines: 131–132 | key: corpus.save.footer -->

The set is fixed at capture. Re-running the query later may find different documents; this corpus will not change, which is what makes counts taken inside it reproducible.

<!-- END SOURCE: corpus.save.footer -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 299–300 | key: corpus.save.truncated.total %@ %@ -->

*Interpolated with the captured and total counts.*

These %1$@ documents are the highest-scoring of %2$@ matching documents. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.truncated.total %@ %@ -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 304–305 | key: corpus.save.truncated.unknown %@ -->

*Interpolated with the captured count.*

These %@ documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.truncated.unknown %@ -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 317–318 | key: corpus.save.checklistHiding %@ -->

*Interpolated with the hidden count.*

Checklist mode is hiding %@ reviewed documents. They will not be in this corpus.

<!-- END SOURCE: corpus.save.checklistHiding %@ -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 293–294 | key: corpus.save.meaning -->

*The Save Working Corpus sheet's warning for a list saved from a Meaning search (#1598).*

These documents are the closest matches a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.

<!-- END SOURCE: corpus.save.meaning -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 337–338 | key: corpus.save.source.meaning %@ -->

*Stored on a working corpus saved from a Meaning search, and shown wherever the corpus is listed. Interpolated with the number of rows the search returned.*

Meaning search — the %@ closest matches

<!-- END SOURCE: corpus.save.source.meaning %@ -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 335–336 | key: corpus.save.source.meaning.one -->

*The same, when the search returned one row.*

Meaning search — the closest match

<!-- END SOURCE: corpus.save.source.meaning.one -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | lines: 64–65 | key: search.checklist.loggingOff -->

*Shown under the results count on iPhone, iPad and Mac while Checklist Mode is on and Settings ▸ Research ▸ Research Sessions ▸ Log Research Sessions is off (#1592).*

Opening a result does not hide it while Log Research Sessions is off in Settings. Mark Reviewed still hides a result.

<!-- END SOURCE: search.checklist.loggingOff -->

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 798–799 | key: search.corpus.footer -->

A working corpus is a fixed set of documents. Applying one searches only inside it. Manage them in Settings.

<!-- END SOURCE: search.corpus.footer -->

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 868–869 | key: search.corpus.noneIndexed %@ -->

*Interpolated with the corpus name.*

None of “%@” is indexed on this device yet — download and index its volumes first.

<!-- END SOURCE: search.corpus.noneIndexed %@ -->

---

### 7.8 The method appendix

*Source: `FRUSExplorer/Export/QueryMethodAppendix.swift, ResearchDataExportView.swift`*

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.snapshot -->

Each count is what the search returned when it ran, over the volumes downloaded to that device at that moment. It is not re-run, and it will not match a search run today against a larger index.

<!-- END SOURCE: appendix.caveat.snapshot -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.zero.one -->

One of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.

<!-- END SOURCE: appendix.caveat.zero.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.zero.many %lld -->

*Interpolated with a count. Kept separate from the singular above because there is no String Catalog to inflect it.*

%lld of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.

<!-- END SOURCE: appendix.caveat.zero.many %lld -->

<!-- The Meaning route's own caveat (#1127): its counts are a ranked top-K, not a match total, and
     its zeros are not term absence — different claims than the keyword rows make. Both sentences
     are the caveat; neither may be dropped for brevity. -->
<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | lines: 515–516 | key: appendix.caveat.semantic.one -->

One search ran by meaning (on-device model) rather than by keywords. Its count is the size of a ranked list, not a match total, and a zero there does not mean any term is absent.

<!-- END SOURCE: appendix.caveat.semantic.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | lines: 517–518 | key: appendix.caveat.semantic.many %lld -->

*Interpolated with a count — keep `\(semanticRowCount)` intact.*

\(semanticRowCount) searches ran by meaning (on-device model) rather than by keywords. Their counts are sizes of ranked lists, not match totals, and zeros there do not mean any term is absent.

<!-- END SOURCE: appendix.caveat.semantic.many %lld -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.floor.one -->

One search hit the app’s row ceiling. Its count is shown as “at least N” and is a floor, not a total — do not sum it with the others.

<!-- END SOURCE: appendix.caveat.floor.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.floor.many %lld -->

*Interpolated with a count.*

%lld searches hit the app’s row ceiling. Those counts are shown as “at least N” and are floors, not totals — do not sum them.

<!-- END SOURCE: appendix.caveat.floor.many %lld -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.unrecorded.one -->

One search predates this app version. It saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. It is marked “as reported” and cannot be checked against the others.

<!-- END SOURCE: appendix.caveat.unrecorded.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.unrecorded.many %lld -->

*Interpolated with a count.*

%lld searches predate this app version. They saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. They are marked “as reported” and cannot be checked against the others.

<!-- END SOURCE: appendix.caveat.unrecorded.many %lld -->

<!-- The coverage block (W-13 session 2): how much of each searched corpus was actually examined.
     The corpora are the ones this project's own searches ran inside — a WorkingCorpus carries no
     project of its own, so SearchHistoryEntry.appliedCorpusId is the only honest way to name them.
     Two preambles, not one: the block must say whose engagement it counted, because a
     project-scoped count attributes annotations through the project that owns them and a reader
     recomputing by hand needs to know which population the numbers describe. -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.coverage.heading -->

How much of each searched corpus was examined

<!-- END SOURCE: appendix.coverage.heading -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.coverage.preamble.project -->

Coverage counts what this project has done with the documents each corpus holds — opened, annotated, or placed in a collection. It is not what the searches returned.

<!-- END SOURCE: appendix.coverage.preamble.project -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.coverage.preamble.device -->

*The same sentence when no project heads the export.*

Coverage counts what has been done on this device with the documents each corpus holds — opened, annotated, or placed in a collection. It is not what the searches returned.

<!-- END SOURCE: appendix.coverage.preamble.device -->

<!-- The three sentences the coverage lines are built from live in DocumentEngagementService, since
     the in-app corpus list states them too and the two must not drift. -->

<!-- SOURCE: FRUSExplorer/ProjectContext/DocumentEngagementService.swift | key: engagement.coverage %@ %@ -->

*Interpolated with the engaged count and the corpus total, both grouped.*

%@ of %@ documents worked on

<!-- END SOURCE: engagement.coverage %@ %@ -->

<!-- SOURCE: FRUSExplorer/ProjectContext/DocumentEngagementService.swift | key: engagement.breakdown %@ %@ %@ -->

*Interpolated with the opened, annotated and collected counts. All three are named even when zero: in a review a zero is a finding.*

%@ opened · %@ annotated · %@ collected

<!-- END SOURCE: engagement.breakdown %@ %@ %@ -->

<!-- SOURCE: FRUSExplorer/ProjectContext/DocumentEngagementService.swift | key: engagement.untouched %@ -->

%@ untouched

<!-- END SOURCE: engagement.untouched %@ -->

<!-- SOURCE: FRUSExplorer/ProjectContext/DocumentEngagementService.swift | key: engagement.caveat.loggingOff -->

*Shown whenever “Log Research Sessions” is off. The opened count is not zeroed — entries written before the switch was flipped are still there — so the sentence says what the number is rather than hiding it.*

Opened is a floor, not a total — research logging is off.

<!-- END SOURCE: engagement.caveat.loggingOff -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.attribution -->

Text from Foreign Relations of the United States, Office of the Historian, U.S. Department of State (public domain).

<!-- END SOURCE: appendix.attribution -->

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | lines: 161–162 | key: settings.export.appendix.footer -->

Every search you ran, in a Markdown table and a CSV. Each row gives the scope the search ran under and how many volumes were indexed at the time. Counts that hit the app’s row ceiling appear as “at least N”, so a partial result is never printed as a total.

<!-- END SOURCE: settings.export.appendix.footer -->

---

### 7.9 Occurrence counts — when they are refused, and why

*Source: `FRUSExplorer/Analytics/OccurrenceAvailability.swift, AnalyticsView.swift`*

<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | lines: 3023–3024 | key: analytics.measure.help -->

Count matching documents, or every occurrence of the word. A term mentioned fifty times in one document is one document and fifty occurrences — the two can move in opposite directions.

<!-- END SOURCE: analytics.measure.help -->

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.occurrences.unavailable.exact -->

Occurrence counts aren’t available for exact-word searches: the index stores word stems, so it cannot tell one exact spelling’s occurrences from another’s.

<!-- END SOURCE: analytics.occurrences.unavailable.exact -->

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.occurrences.unavailable.multiTerm -->

Occurrence counts aren’t available for phrases, wildcards or proximity searches — those match several index terms, which have no single occurrence count.

<!-- END SOURCE: analytics.occurrences.unavailable.multiTerm -->

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.occurrences.unavailable.composite -->

Occurrence counts aren’t available for queries with more than one term: adding up occurrences of each would count two different things as one.

<!-- END SOURCE: analytics.occurrences.unavailable.composite -->

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.occurrences.unavailable.notSingleToken -->

This term indexes as several separate words, so it has no single occurrence count.

<!-- END SOURCE: analytics.occurrences.unavailable.notSingleToken -->

---

### 7.10 Bulk summarization

*Source: `FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift, BackgroundSummarizationService.swift`*

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.concurrency.hint.v2 -->

Apple Intelligence generates one summary at a time, so a higher number does not make the model faster. It helps when your Mac is busy with other work. It also makes the first summary take longer to appear.

<!-- END SOURCE: bg.summarizer.concurrency.hint.v2 -->

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.concurrency.hint.background -->

*iOS only.*

Once a run continues in the background, iOS processes documents one at a time regardless of this setting.

<!-- END SOURCE: bg.summarizer.concurrency.hint.background -->

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.start.duration -->

Summarizing a large scope can take several hours. You can keep working while it runs.

<!-- END SOURCE: bg.summarizer.start.duration -->

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.start.quitting -->

*macOS only.*

Quitting FRUS Explorer stops the run. Summaries already written are kept.

<!-- END SOURCE: bg.summarizer.start.quitting -->

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationService.swift | lines: 612–613 | key: bg.summarizer.failed.unavailable -->

*Interpolated with the succeeded and attemptable counts.*

Apple Intelligence became unavailable. Stopped after %lld of %lld documents.

<!-- END SOURCE: bg.summarizer.failed.unavailable -->


### 7.11 Compacting the search index

*Source: `FRUSExplorer/Settings/SettingsComponents.swift` (the shared `IndexCompaction` rule),
rendered identically by both storage hubs.*

*SQLite never returns deleted pages to the filesystem — they go on a freelist and wait to be reused —
so the index file can be much larger than the data in it. Reindexing is the main producer. Measured
on the author's 552-volume store: 6.29 GiB on disk, 2.75 GiB live, 3.53 GiB reclaimable.*

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.storage.compact.available %@ %lld -->

*Interpolated with the reclaimable size and its percentage of the file.*

%@ of this is free space left by reindexing — %lld%% of the file.

<!-- END SOURCE: settings.storage.compact.available %@ %lld -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.storage.compact.blocked %@ %@ -->

*Shown when there is something worth reclaiming but not enough free disk to do it safely. Stated
rather than hidden: this is the case where the number explains the most.*

%@ could be reclaimed, but compacting needs about %@ of free space first.

<!-- END SOURCE: settings.storage.compact.blocked %@ %@ -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 907–908 | key: settings.storage.compact.action | shared: iOS+macOS (single edit point) -->

Compact Database

<!-- END SOURCE: settings.storage.compact.action -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 917–918 | key: settings.storage.compact.caveat | shared: iOS+macOS (single edit point) -->

Rewrites the index to give the free space back. Searching is unavailable while it runs — usually a few seconds, longer on a large library. Nothing you have written is affected.

<!-- END SOURCE: settings.storage.compact.caveat -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 926–927 | key: settings.storage.compact.done %@ -->

*Interpolated with the reclaimed size.*

Reclaimed %@.

<!-- END SOURCE: settings.storage.compact.done %@ -->

<!-- SOURCE: FRUSExplorer/RelatedDocuments/SimilarityModel.swift | RelatedDocumentsCounts.cohort | lines: 385–386 | key: related.why.cohort %@ %@ -->

*The archival “why related” chip (#644). Interpolated with the container name and its size, which is
grouped since #1586 (“1 of 1,063”).
Replaces a bare “same provenance”, which read identically for a lot file holding two documents and
for Nixon’s NSC Files holding 7,056 — and that difference is what tells a researcher whether sharing
the container is a finding or a filing-cabinet coincidence.*

%1$@ · 1 of %2$@

<!-- END SOURCE: related.why.cohort %@ %@ -->

---

### 7.12 Semantic search fallback (V-5 s3)

> **Compliance note:** the offer card leads to the consent sheet (§1.4c), whose sentence is the
> Gemma flow-down. The offer copy itself is editable; the consent sheet's is not a copy edit.

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchSharedViews.swift | property: SemanticModelOfferCard | lines: 116–117 | key: search.semantic.offer.body -->

Keyword search found nothing, but the app can also search by what an AI model detects your question to mean — including questions whose words never appear in the documents. This needs a one-time 229 MB model download that runs entirely on this device.

<!-- END SOURCE: search.semantic.offer.body -->

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchSharedViews.swift | property: SemanticModelOfferCard | lines: 119–120 | key: search.semantic.offer.body.meaning -->

*The same card in Meaning mode, where no keyword search ran: shown when a Meaning search is submitted and the model is not on the device.*

A Meaning search ranks documents by what an AI model detects your question to mean, including questions whose words never appear in the documents. This needs a one-time 229 MB model download that runs entirely on this device.

<!-- END SOURCE: search.semantic.offer.body.meaning -->

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchFallbackView.swift | property: disclosureCaption | lines: 257–258 | key: search.semantic.results.caption -->

Ranked by meaning, not keywords, across the whole series — your exact words may not appear.

<!-- END SOURCE: search.semantic.results.caption -->

<!-- #1527 (2026-09-30): two texts, your option (a). The first is shown only while every unscored
     volume's match file is really downloading — the search asked for each volume's file and the app
     started the fetch, which it does not while Download With Volumes is off, offline, or after that
     volume's fetch failed; the second otherwise. Both search surfaces read them from
     SemanticUnscoredCopy. %@ in each is the volume count with its noun ("1 volume", "12 volumes");
     the first was "%lld volumes" until review round 1 (2026-09-30), which read "1 volumes". -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.warming | lines: 200–201 | key: search.semantic.empty.warming.v2 %@ -->

Match files for %@ are still downloading in the background. Searching again in a moment may find more.

<!-- END SOURCE: search.semantic.empty.warming.v2 %@ -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.warming | lines: 205–206 | key: search.semantic.empty.notFetching %@ -->

Match files for %@ are required. Use Download Vectors for Every Volume in Settings to get the data needed to run this search.

<!-- END SOURCE: search.semantic.empty.notFetching %@ -->

<!-- #1577 lane 1 (2026-10-10): the sentence under "No semantic matches yet" when the search ran
     inside a document set. A set is ranked whole, with no threshold, so an empty list there never
     means that nothing was close, and each of the six says what did happen: the set is empty on
     this device; the closest matches were ranked and the other filters removed them; they were
     ranked, no filter removed any, and none is indexed here (a set made only of documents this
     device's copy of a volume does not hold); no document in the set has match data; the match
     files are downloading; or they are not on the device. The first is also the pre-search prompt for an
     empty set. In the last two %@ is the volume count with its noun. -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 293–294 | key: search.semantic.empty.set.none -->

The set you are searching within holds no documents on this device, so there is nothing to rank.

<!-- END SOURCE: search.semantic.empty.set.none -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 298–299 | key: search.semantic.empty.set.filtered -->

None of the closest matches inside the documents you are searching within passes your other filters.

<!-- END SOURCE: search.semantic.empty.set.filtered -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 300–301 | key: search.semantic.empty.set.notIndexed -->

None of the closest matches inside the documents you are searching within is indexed on this device.

<!-- END SOURCE: search.semantic.empty.set.notIndexed -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 304–305 | key: search.semantic.empty.set.noVectors -->

None of the documents you are searching within can be ranked by meaning: the app has no match data for them. Front matter and chapter headings never have any.

<!-- END SOURCE: search.semantic.empty.set.noVectors -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 309–310 | key: search.semantic.empty.set.warming %@ -->

Match files for %@ are still downloading in the background. Searching again in a moment may rank the documents you are searching within.

<!-- END SOURCE: search.semantic.empty.set.warming %@ -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 314–315 | key: search.semantic.empty.set.notFetching %@ -->

The documents you are searching within could not be ranked: match files for %@ are not on this device. Download Missing Vectors in Settings fetches the files for volumes you have downloaded.

<!-- END SOURCE: search.semantic.empty.set.notFetching %@ -->

---

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | property: SemanticModeStrip.caption | lines: 106–107 | key: search.meaning.strip.base -->

Meaning search (experimental): ranked by what your question means, across the whole series — your exact words may not appear. Front matter and chapter headings are not reachable this way.

<!-- END SOURCE: search.meaning.strip.base -->

<!-- #1577 lane 1 (2026-10-10): a Meaning search inside a document set (an applied working corpus,
     a project's History scope) ranks that set's members and no others, so the strip's opening
     names the set where it said "across the whole series". The block above is still what a search
     of the whole series shows. -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticModeStrip.opening | lines: 115–116 | key: search.meaning.strip.base.within %@ -->

Meaning search (experimental): ranked by what your question means, inside the %@ you are searching within — your exact words may not appear. Front matter and chapter headings are not reachable this way. *(%@ is the set's size with its noun, “1 document” or “212 documents”.)*

<!-- END SOURCE: search.meaning.strip.base.within %@ -->

<!-- The same opening when the set is empty here: a History scope with nothing in it yet, or a
     corpus and a History scope with no document in common. -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticModeStrip.opening | lines: 111–112 | key: search.meaning.strip.base.emptySet -->

Meaning search (experimental): the set you are searching within holds no documents on this device, so there is nothing to rank.

<!-- END SOURCE: search.meaning.strip.base.emptySet -->

<!-- #1577 lane 1 (2026-10-10): appended to the strip, in a search of the whole series and inside a set
     alike, when some of the closest matches are in a volume this device has indexed and its index
     holds no row for them. The match data is the build's and the volume is whatever the device
     downloaded, so the two can disagree: a document added to a volume since it was downloaded, or
     removed since the build's match data was made. Such a match was dropped without a word, or
     counted under "Your filters removed" when any filter was set. One and many forms; %@ is the
     count. It names no cause, because the app cannot tell which applies. -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.notIndexedHere | lines: 245–246 | key: search.meaning.strip.notIndexed.one -->

%@ close match is not listed: this device's index does not hold that document.

<!-- END SOURCE: search.meaning.strip.notIndexed.one -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.notIndexedHere | lines: 247–248 | key: search.meaning.strip.notIndexed.many -->

%@ close matches are not listed: this device's index does not hold those documents.

<!-- END SOURCE: search.meaning.strip.notIndexed.many -->

<!-- Appended inside a set when some of its documents have no match data at all. One and many
     forms; %@ is the count. Kept short: it follows the opening, which has just said that front
     matter and chapter headings are not reachable, and on an iPhone the strip sits above the
     results. -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.withoutVector | lines: 265–266 | key: search.meaning.strip.withoutVector.one -->

%@ document in the set has no match data and cannot be ranked.

<!-- END SOURCE: search.meaning.strip.withoutVector.one -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.withoutVector | lines: 267–268 | key: search.meaning.strip.withoutVector.many -->

%@ documents in the set have no match data and cannot be ranked.

<!-- END SOURCE: search.meaning.strip.withoutVector.many -->

<!-- Appended inside a set when some of its documents are in volumes whose match files are not
     on the device. Two texts, by #1527's rule: the first only while every such volume's file is
     really downloading, the second otherwise. They differ from the corpus-wide pair below in two
     ways: the count is of the reader's own documents ("12 documents", not "12 possible matches"),
     and the control named is Download Missing Vectors, which fetches files for downloaded volumes.
     %1$@ is the documents with their noun and %2$@ the volumes with theirs. -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.unranked | lines: 222–223 | key: search.meaning.strip.unranked.downloading %@ %@ -->

%1$@ in %2$@ could not be ranked yet; their match files are downloading.

<!-- END SOURCE: search.meaning.strip.unranked.downloading %@ %@ -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.unranked | lines: 227–228 | key: search.meaning.strip.unranked.notFetching %@ %@ -->

%1$@ in %2$@ could not be ranked: their match files are not on this device. Download Missing Vectors in Settings fetches the files for volumes you have downloaded.

<!-- END SOURCE: search.meaning.strip.unranked.notFetching %@ %@ -->

<!-- Appended to the strip when matches land in undownloaded volumes while non-volume filters are
     active (#1127). The claim is precise: the volume scope IS checked for those matches, the other
     filters are NOT — a rewrite that says "filters are ignored" would claim too much, one that
     stays silent would claim too little. -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | property: SemanticModeStrip.caption | lines: 74–75 | key: search.meaning.strip.beyondUnchecked -->

Matches in volumes you have not downloaded are checked against your volume scope only, not your other filters.

<!-- END SOURCE: search.meaning.strip.beyondUnchecked -->

---

### 7.13 Search Tips

*Source: `FRUSExplorer/Search/SearchModels.swift` — `SearchTip` (thirteen rows), `SearchTipNote` and `SearchQueryRefusal` (#1299).*

*One model feeds both platforms: the Search Tips sheet on iOS and iPadOS and the Tips panel in the macOS Search window render the same rows, so each block below is a single edit point. Each row has two editable strings — the **detail** a reader sees, and the **spoken** form VoiceOver reads in place of the example. The **example chip is not editable here**: it is search syntax, typed exactly as shown, and `SearchTipsTests` parses it and checks every row's claims against the parser and SQLite. When you revise a detail, keep the parts that test reads: the distances in the NEAR row (5 and 10, and no other number), the two prefixes in the prefix row (negoti\* and negotiat\*) and the form it names (negotiations), `NOT NEAR(` in the NEAR row, the word forms named in the stemming row (negotiated, negotiations), and in the exact-word row the forms (contain, containing), the word stemming, the three things the mark still ignores (capitalization, accent, punctuation) and `NEAR(`; in the last row, NOT APPLIED and "beside a word". The test also refuses a prefix row that says a prefix finds "nothing", and an exact-word row that says "as you typed" — both were false (below). Each spoken form must say every word and number of its example.*

*Owner decisions behind the wording (2026-09-17): the prefix row warns that a long prefix misses forms, because it is matched against word stems (Q6); the NEAR row says OR, NOT and parentheses cannot go inside and that only NOT NEAR(…) excludes, and describes no fallback (Q7); there is no person note (Q1); and in Meaning mode the Meaning-mode note replaces the rows (Q3).*

#### 1. All the words — `berlin crisis`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .allWords | lines: 367–368 | key: search.tips.allWords.detail | shared: iOS+macOS (single edit point) -->

Finds documents containing every word, in any order.

<!-- END SOURCE: search.tips.allWords.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .allWords | lines: 366–366 | key: search.tips.allWords.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `berlin crisis`, before the detail. Name every symbol in words.*

berlin crisis

<!-- END SOURCE: search.tips.allWords.spoken -->

#### 2. Other forms of a word — `negotiate`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .stemming | lines: 372–373 | key: search.tips.stemming.detail | shared: iOS+macOS (single edit point) -->

Each word also matches its other forms, so negotiate finds negotiated and negotiations.

<!-- END SOURCE: search.tips.stemming.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .stemming | lines: 371–371 | key: search.tips.stemming.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `negotiate`, before the detail. Name every symbol in words.*

negotiate

<!-- END SOURCE: search.tips.stemming.spoken -->

#### 3. A phrase — `"cold war"`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .phrase | lines: 377–378 | key: search.tips.phrase.detail | shared: iOS+macOS (single edit point) -->

Words in double quotation marks, straight or curly, must appear together and in that order. A phrase cannot contain quotation marks of its own.

<!-- END SOURCE: search.tips.phrase.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .phrase | lines: 376–376 | key: search.tips.phrase.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `"cold war"`, before the detail. Name every symbol in words.*

quote, cold war, quote

<!-- END SOURCE: search.tips.phrase.spoken -->

#### 4. Either word — `rusk OR bundy`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .either | lines: 382–383 | key: search.tips.either.detail | shared: iOS+macOS (single edit point) -->

Finds documents with either word. OR divides everything before it from everything after it, so use parentheses to limit it.

<!-- END SOURCE: search.tips.either.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .either | lines: 381–381 | key: search.tips.either.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `rusk OR bundy`, before the detail. Name every symbol in words.*

rusk OR bundy

<!-- END SOURCE: search.tips.either.spoken -->

#### 5. Searching for and, or, not — `"will not intervene"`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .operatorWords | lines: 388–389 | key: search.tips.operatorWords.detail | shared: iOS+macOS (single edit point) -->

AND, OR and NOT work in any case, so put a phrase that contains and, or or not in quotation marks.

<!-- END SOURCE: search.tips.operatorWords.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .operatorWords | lines: 386–387 | key: search.tips.operatorWords.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `"will not intervene"`, before the detail. Name every symbol in words.*

quote, will not intervene, quote

<!-- END SOURCE: search.tips.operatorWords.spoken -->

#### 6. Leaving a word out — `vietnam -laos`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .exclude | lines: 393–394 | key: search.tips.exclude.detail | shared: iOS+macOS (single edit point) -->

A minus sign touching a word, or NOT before it, leaves out documents containing that word, wherever it sits among the words typed with it.

<!-- END SOURCE: search.tips.exclude.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .exclude | lines: 392–392 | key: search.tips.exclude.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `vietnam -laos`, before the detail. Name every symbol in words.*

vietnam, minus sign, laos

<!-- END SOURCE: search.tips.exclude.spoken -->

#### 7. Exclusions and OR — `(cold OR war) -korea`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .excludeAcrossOr | lines: 399–400 | key: search.tips.excludeAcrossOr.detail | shared: iOS+macOS (single edit point) -->

An exclusion does not reach across OR. To exclude a word from every alternative, put the alternatives in parentheses.

<!-- END SOURCE: search.tips.excludeAcrossOr.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .excludeAcrossOr | lines: 397–398 | key: search.tips.excludeAcrossOr.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `(cold OR war) -korea`, before the detail. Name every symbol in words.*

open parenthesis, cold OR war, close parenthesis, minus sign, korea

<!-- END SOURCE: search.tips.excludeAcrossOr.spoken -->

#### 8. Groups — `(aqaba OR tiran) navig*`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .group | lines: 405–406 | key: search.tips.group.detail | shared: iOS+macOS (single edit point) -->

Parentheses group alternatives, and the group must match along with the words beside it.

<!-- END SOURCE: search.tips.group.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .group | lines: 403–404 | key: search.tips.group.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `(aqaba OR tiran) navig*`, before the detail. Name every symbol in words.*

open parenthesis, aqaba OR tiran, close parenthesis, navig, star

<!-- END SOURCE: search.tips.group.spoken -->

#### 9. Leaving a group out — `vietnam -(laos OR cambodia)`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .excludeGroup | lines: 411–412 | key: search.tips.excludeGroup.detail | shared: iOS+macOS (single edit point) -->

NOT, or a minus sign touching the parenthesis, leaves out everything the group matches. A minus sign followed by a space is ignored.

<!-- END SOURCE: search.tips.excludeGroup.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .excludeGroup | lines: 409–410 | key: search.tips.excludeGroup.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `vietnam -(laos OR cambodia)`, before the detail. Name every symbol in words.*

vietnam, minus sign, open parenthesis, laos OR cambodia, close parenthesis

<!-- END SOURCE: search.tips.excludeGroup.spoken -->

#### 10. Prefixes — `negoti*`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .prefix | lines: 416–417 | key: search.tips.prefix.detail | shared: iOS+macOS (single edit point) -->

Finds words beginning with these letters. Keep the prefix short, because it is matched against word stems: negotiat* misses negotiations, which negoti* finds.

<!-- END SOURCE: search.tips.prefix.detail -->

Note: reworded in place before shipping (#1299 follow-up). It said "negoti* finds negotiations, but negotiat* finds nothing", which a reader who tried it would find false: `negotiat*` still matches a word whose own stem keeps those letters — *negotiatory*, printed 21 times in the shipped corpus, and a run of misspellings such as *negotiatons*. What it misses is every form whose stem is *negoti*: negotiate, negotiated, negotiating, negotiations, negotiator.

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .prefix | lines: 415–415 | key: search.tips.prefix.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `negoti*`, before the detail. Name every symbol in words.*

negoti, star

<!-- END SOURCE: search.tips.prefix.spoken -->

#### 11. Words near each other — `NEAR(military europe, 5)`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .near | lines: 422–423 | key: search.tips.near.detail | shared: iOS+macOS (single edit point) -->

Finds the words within 5 words of each other, in either order, or within 10 when you leave out the number. The words may be phrases or prefixes. OR, NOT, AND, a minus sign and parentheses cannot go inside one, and a search that puts them there is refused rather than run as something else. Only NOT NEAR(…) excludes a NEAR; a minus sign before it does not.

<!-- END SOURCE: search.tips.near.detail -->

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .near | lines: 420–421 | key: search.tips.near.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `NEAR(military europe, 5)`, before the detail. Name every symbol in words.*

NEAR, open parenthesis, military europe, comma, 5, close parenthesis

<!-- END SOURCE: search.tips.near.spoken -->

#### 12. A word without stemming — `=containment`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .exactWord | lines: 427–428 | key: search.tips.exactWord.detail | shared: iOS+macOS (single edit point) -->

Turns off stemming for this word, so containment no longer matches contain or containing. Capitalization, a single accent, and/or punctuation at either end still do not matter. The = is ignored where a match need not contain the word, such as one side of an OR, and always on a prefix, inside NEAR(…), or on a word the index splits into several terms, such as anti-Communist or U.S.S.R.

<!-- END SOURCE: search.tips.exactWord.detail -->

Note: reworded in place before shipping (#1299 follow-up). It said the mark "matches the word only as you typed it", but the exact-word filter folds capitalization, a single accent and punctuation at either end — `=Hull`, typed for Cordell Hull, still counts every ship's hull — so a reader could have cited a count as capitalized-only when it was not. It also left out NEAR(…): inside one the mark is dropped, and `NEAR(=containment policy, 5)` still finds *containers policy*. Round 2 added the last case, which both user manuals and the Corpus Analytics Multiple words row already named: a word the index splits into several terms has no single word to filter on, so `=anti-Communist` still counts *anti-Communists* (the corpus prints 4,578 of the one and 185 of the other). `SearchTipsTests` requires the row to name it.

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .exactWord | lines: 426–426 | key: search.tips.exactWord.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `=containment`, before the detail. Name every symbol in words.*

equals sign, containment

<!-- END SOURCE: search.tips.exactWord.spoken -->

#### 13. A search needs a word — `-korea`
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) detail .needsAWord | lines: 432–433 | key: search.tips.needsAWord.detail | shared: iOS+macOS (single edit point) -->

A search needs a word to find. A query made only of exclusions does not run, and an OR alternative made only of exclusions is left out and marked NOT APPLIED in the Query Inspector, unless its parentheses sit beside a word to search for.

<!-- END SOURCE: search.tips.needsAWord.detail -->

Note: reworded in place before shipping (#1299 follow-up). Without the last clause it said every such alternative is left out, which steered a reader away from a query that works: `war (cold OR -korea)` is searched exactly — the *war* documents that mention *cold* or do not mention *korea* — and nothing is marked. `cold OR -korea`, `(cold OR -korea)` on its own, and `war OR (cold OR -korea)` still leave `-korea` out. The user manuals' §7.2 explain the whole rule.

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTip.init(id:) spokenExample .needsAWord | lines: 431–431 | key: search.tips.needsAWord.spoken | shared: iOS+macOS (single edit point) -->

*Spoken by VoiceOver in place of the example chip `-korea`, before the detail. Name every symbol in words.*

minus sign, korea

<!-- END SOURCE: search.tips.needsAWord.spoken -->

#### Notes shown with the rows

*iOS and iPadOS show the dates note and the iOS scope note under the rows; the macOS panel shows the dates note and the macOS scope note. In Meaning mode both show the Meaning-mode note instead of the rows.*

##### Dates (both platforms)
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTipNote.text | lines: 493–494 | key: search.tips.note.dates | shared: iOS+macOS (single edit point) -->

A date filter keeps documents whose dates overlap the range you set, and leaves out documents with no date.

<!-- END SOURCE: search.tips.note.dates -->

##### Search scope (iOS and iPadOS)
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTipNote.text | lines: 496–497 | key: search.tips.note.scope.ios | shared: iOS+macOS (single edit point) -->

Filters ▸ Search Scope sets what a search reads. Its defaults live in Settings ▸ Reading & Search ▸ Search, and a change made in Filters is not saved as a default.

<!-- END SOURCE: search.tips.note.scope.ios -->

##### Search scope (macOS)
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTipNote.text | lines: 499–500 | key: search.tips.note.scope.mac | shared: iOS+macOS (single edit point) -->

The Search in chips set what this window searches. Their defaults live in Settings ▸ Reading & Search ▸ Search, and a change made with the chips is not saved as a default.

<!-- END SOURCE: search.tips.note.scope.mac -->

##### Meaning mode (both platforms)
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchTipNote.text | lines: 502–503 | key: search.tips.note.meaningMode | shared: iOS+macOS (single edit point) -->

These tips are for Keywords search. A Meaning search reads your words as a whole, so quotation marks, AND, OR, NOT, a minus sign, parentheses, *, NEAR and = have no special effect.

<!-- END SOURCE: search.tips.note.meaningMode -->

Note: this departs from the design brief's draft (§2.3: "These tips are for keyword search. A meaning search reads your question as a whole, so quotation marks, OR, NOT, *, NEAR and = have no special effect.") in three ways, each to match what the reader sees. The mode names are capitalized, as the Keywords and Meaning picker labels are. It says "your words" rather than "your question", beside a field that asks for "a question in your own words" and for the reader most likely to open it, who typed operators rather than a question. And it names AND, a minus sign and parentheses too, since the rows above teach all of them.

Why it is true: a meaning search hands your words to the model as typed, and only the filters you set narrow its results. Until #1299 round 2 that was not so for `=`. The Meaning results are intersected with the filters, and that intersection also built the keyword search's exact-word filter from the typed text, so `=containment policy` dropped every match without the literal word and the strip said "Your filters removed N matches" to a reader who had set none. Keep the `=` in the list only while the intersection reads filters alone. The guard is narrower than the intersection: `HybridSearchModeTests.filterKeySetIgnoresTypedText` fails if `SearchService.filterKeySet(parameters:)`, the one method the intersection builds its key set from, reads typed text, but no test drives `SemanticSearchBackend.run` itself, so a backend that built its key set some other way would not be caught.

#### A search that cannot run

*Shown when a submitted keyword search holds nothing it can search for — for example `-korea`, or groups nested more than 32 deep. It replaced "The operation couldn’t be completed. (FRUSExplorer.FTS5Error error 5.)" on iOS, where the same code also answered a search with document text, summaries and research notes all turned off; that case now has its own message, below. Keep the pointer to Search Tips: `SearchRefusalMessageTests` requires it. The "for example" is deliberate, because the same message also answers a query with nothing searchable in it at all, such as a lone quotation mark, for which neither reason is true. Both platforms show it under the title Search Error: on the Mac the Search window rendered no search error at all until #1299, so this message, the empty-scope message and the Meaning-mode errors had all been an empty result list there.*

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchQueryRefusal.errorDescription | lines: 588–589 | key: search.error.refusedQuery | shared: iOS+macOS (single edit point) -->

This query has nothing it can search for: for example, it only excludes words, or its groups are nested too deeply. See Search Tips for what a search needs.

<!-- END SOURCE: search.error.refusedQuery -->

#### The Sort control's Large Content Viewer detail

*The line shown when a reader touches and holds the Search actions bar's Sort control at an accessibility text size (#1307). Sort was the one control in that bar with no Large Content Viewer entry, which matters more now that the bar's glyphs stop growing: the magnified NAME is what replaces the magnified glyph.*

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | sortMenu's controlHelp | key: search.sort.help | shared: iOS only -->

Order results by relevance or by document date

<!-- END SOURCE: search.sort.help -->

#### A NEAR that cannot be searched as written

*Shown when a submitted keyword search puts a boolean, a minus sign, a nested group or an unparseable distance inside a `NEAR(…)` — `NEAR(military OR europe, 5)`, `NEAR(military -europe, 5)`, `NEAR(military europe, 3.5)`. Until #1304 the app DEGRADED these: it dropped the NEAR keyword and searched the parentheses as an ordinary boolean group, so the distance was looked for as a word and a minus sign became a corpus-wide exclusion — a plausible count for a search nobody typed. The `%@` is the NEAR as the reader typed it, quoted back so they can see which one. Keep the sentence saying nothing was searched: the reader's next question is whether a partial search ran, and it did not.*

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchQueryRefusal.errorDescription | lines: 595–596 | key: search.error.malformedNear %@ | shared: iOS+macOS (single edit point) -->

%@ cannot be searched as written: a NEAR(…) holds only words, phrases and prefixes, with an optional distance. OR, NOT, AND, a minus sign and parentheses cannot go inside one. Nothing was searched, because dropping the NEAR would run a different search.

<!-- END SOURCE: search.error.malformedNear %@ -->

#### The Query Inspector's line for a refused NEAR

*The Query Inspector strip's "no expression" line, when the reason is a malformed `NEAR(…)` (#1304). The generic refused line — nothing left after the exclusions, or groups nested too deep — is true of this query and useless to the reader, who cannot tell from it which part to change. The `%@` is the NEAR as typed.*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | the refused branch | key: search.inspector.refused.near %@ | shared: iOS+macOS (single edit point) -->

No expression — %@ holds something a NEAR cannot: a boolean, a minus sign, a nested group, or a distance that is not a whole number. The query was refused rather than run as an ordinary boolean search.

<!-- END SOURCE: search.inspector.refused.near %@ -->

#### A search with nowhere to search (iOS)

*Shown on iPhone and iPad when a keyword search could run but Include document text, Include summaries and Include research notes under Filters ▸ Search Scope are all off, so there is nowhere to search. A query that cannot run gets the message above instead, whatever the scope. The same section's Include front matter toggle does not count and is usually still on, so the message names the three it means rather than saying every scope is off. Until #1299's follow-up it read "The operation couldn’t be completed. (FRUSExplorer.FTS5Error error 5.)". Keep "Filters ▸ Search Scope" and the names of the three toggles, and do not say "every": `SearchRefusalMessageTests` requires all three. The Mac never shows it — its Search window stops a search with all three Search in chips off before it runs, with the macOS message below.*

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchQueryRefusal.errorDescription | lines: 591–592 | key: search.error.emptyScope.ios | shared: iOS only -->

Document text, summaries and research notes are all turned off, so there is nothing to search. Turn one on in Filters ▸ Search Scope.

<!-- END SOURCE: search.error.emptyScope.ios -->

#### A search with every Search in chip turned off (macOS)

<!-- SOURCE: FRUSExplorer/App/MacSearchViewModel.swift | MacSearchError.errorDescription | lines: 1345–1346 | key: search.error.emptyScope | shared: macOS only -->

*Shown in the Search window, under the title Search Error, when Documents, Notes and Summaries are all turned off.*

Enable at least one of Documents, Notes, or Summaries to search.

<!-- END SOURCE: search.error.emptyScope -->

#### An empty search (iOS)

<!-- SOURCE: FRUSExplorer/Search/SearchViewModel.swift | SearchViewModel.search() | lines: 675–676 | key: search.error.empty | shared: iOS only -->

*Shown under the title Search Error when a search runs with nothing typed and no filter that searches on its own.*

Enter a keyword, phrase, or prefix to search.

<!-- END SOURCE: search.error.empty -->

#### The title above every search error

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | SearchView.resultsSection | lines: 1597–1597 | key: search.error.title | shared: iOS+macOS (declared in BOTH — edit both call sites) -->

*The heading over each message above, on both platforms. The key is declared twice with the same text — in `SearchView.swift` on iOS and in `SearchSheet.swift`'s `searchErrorView` on the Mac, which adopted it in #1299 — so keep the two the same.*

Search Error

<!-- END SOURCE: search.error.title -->

#### Where the tips open

*The chrome around the rows above. On iOS and iPadOS the rows open in a sheet, from four places the owner chose (2026-09-17): the More menu, a link on the Search screen before a search in Keywords mode, a link under the Query Inspector when a query cannot run or runs narrower than typed, and the Find menu. On the Mac they open in a panel under the results, from the Tips button and the Find menu. No keyboard shortcut and no new actions-bar icon (Q2).*

##### Sheet title (iOS)
<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | SearchTipsSheet.body | lines: 2523–2523 | key: search.tips.title -->

Search Tips

<!-- END SOURCE: search.tips.title -->

##### Sheet section: the syntax rows (iOS)
<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | SearchTipsSheet.body | lines: 2512–2512 | key: search.tips.section.syntax -->

Typing a search

<!-- END SOURCE: search.tips.section.syntax -->

##### Sheet section: the notes (iOS)
<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | SearchTipsSheet.body | lines: 2519–2519 | key: search.tips.section.filters -->

Filters and scope

<!-- END SOURCE: search.tips.section.filters -->

##### More menu item (iOS)
<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | SearchView.moreMenu | lines: 1187–1187 | key: search.tips.open -->

*After Look up an abbreviation, and never between the two save items. The menu is labelled More search actions.*

Search Tips

<!-- END SOURCE: search.tips.open -->

##### More menu hint (iOS)
<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | SearchView.moreMenu .controlHelp detail | lines: 1212–1213 | key: search.moreActions.help.v2 -->

*The VoiceOver hint and Large Content Viewer detail for the More menu. Replaces `search.moreActions.help`, which named neither the abbreviation lookup nor the tips.*

Save this search or its results, revisit saved searches, find a document by citation, look up an abbreviation, or read the search tips

<!-- END SOURCE: search.moreActions.help.v2 -->

##### Link to the sheet (iOS)
<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | SearchTipsSheet.linkTitle | lines: 2496–2496 | key: search.tips.link -->

*One string for both links: under the prompt on the Search screen before a search (Keywords mode only), and under the Query Inspector when a query cannot run or runs narrower than typed.*

Search tips

<!-- END SOURCE: search.tips.link -->

##### Find menu item (iPadOS and macOS)
<!-- SOURCE: FRUSExplorer/App/FRUSExplorerApp.swift | IOSFindMenuContent / FindMenuContent | lines: 3813–3813, 4305–4305 | key: menu.find.searchTips | shared: iOS+macOS (declared in BOTH — edit both call sites) -->

*On iPad it switches to the Search tab and opens the sheet; on the Mac it brings the Search window forward with the Tips panel open. The key appears twice in the file with the same text — keep them the same.*

Search Tips…

<!-- END SOURCE: menu.find.searchTips -->

##### Tips button (macOS)
<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | MacSearchWindowView.searchInputRow | lines: 739–739 | key: search.tips.button -->

Tips

<!-- END SOURCE: search.tips.button -->

##### Tips button help (macOS)
<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | MacSearchWindowView.searchInputRow .help | lines: 746–747 | key: search.tips.help.v2 -->

*The tooltip. Replaces `search.tips.help`, which promised a stemming tip the panel never had and named neither groups, NEAR nor exact words.*

Show or hide the search tips: phrases, OR and NOT, exclusions, groups, prefixes, NEAR, exact words, and what the date filter and the Search in chips do

<!-- END SOURCE: search.tips.help.v2 -->

##### Panel heading (macOS)
<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | MacSearchWindowView.tipsPanel | lines: 2230–2230 | key: search.tips.header -->

*Shown in capitals above the rows.*

Search tips

<!-- END SOURCE: search.tips.header -->

### 7.14 Saved Searches — the empty list (#1380)

*The two bodies of the Saved Searches sheet each say where the bookmark button is. The iOS body's
sentence says “tap” and the Mac's says “click”, each under its own key: until #1380 the Mac body
shared the iOS key and its wording. Both are shorter than §18's prose rule, and are carried because
the Mac's is new and an editor should see the pair.*

#### Empty state (iPhone and iPad)
<!-- SOURCE: FRUSExplorer/Search/SavedSearchesView.swift | SavedSearchesView.iOSBody | lines: 166–167 | key: savedSearches.empty.detail | shared: iOS only (the macOS wording is the next block) -->

Tap the bookmark button in Search to save a search for quick access later.

<!-- END SOURCE: savedSearches.empty.detail -->

#### Empty state (macOS)
<!-- SOURCE: FRUSExplorer/Search/SavedSearchesView.swift | SavedSearchesView.macBody | lines: 129–130 | key: savedSearches.empty.detail.mac | shared: macOS only -->

Click the bookmark button in Search to save a search for quick access later.

<!-- END SOURCE: savedSearches.empty.detail.mac -->

---

## 16. Browse — the axis captions

*The coverage statements on the Browse axes: what each axis was computed from, what its counts
denominate, and what cannot be reached through it. These predate build 44 and were a standing gap
in this file. Each is a method sentence with numbers or a refusal in it — the same material as
§10's export statements — so the same editing rule applies: plainer must not mean vaguer, and
every denominator and every "cannot appear here" must survive.*

### 16.1 Clusters

#### The index caption
<!-- Placeholder note: keep `\(clusterCount)`, `\(unclusteredCount)` and `\(percentText)` intact.
     The unclustered disclosure is the load-bearing clause — those documents cannot be reached
     from this list at all, and hiding that would present the axis as exhaustive. -->
<!-- SOURCE: FRUSExplorer/Browser/ClustersBrowseView.swift | lines: 137–143 | key: browser.clusters.caption -->

\(clusterCount) clusters computed from document text. Labels are the most distinctive sampled terms, not subject headings. \(unclusteredCount) documents (\(percentText)%) belong to no cluster and cannot be reached from this list. Era bars reflect each volume’s coverage era, not document dates.

<!-- END SOURCE: browser.clusters.caption -->

#### The drill-in footer
<!-- SOURCE: FRUSExplorer/Browser/ClustersBrowseView.swift | lines: 766–767 | key: browser.clusters.drill.footer -->

A cluster is a grouping detected by an AI model that the corpus fell into on its own. It is comprised of documents whose language reads alike to an AI model. It is detected mathematically by turning its text into numeric vectors and clustering documents measured as similar rather than chosen by an editor. Its label is automatically assigned from the most distinctive words in a sample of the cluster’s documents. It is not a subject heading. Era counts reflect each volume’s coverage era, not each document’s own date.

<!-- END SOURCE: browser.clusters.drill.footer -->

### 16.2 Archives

#### The coverage statement
<!-- Placeholder note: keep `\(coverage.noteCount)`, `\(coverage.volumesWithNotes)`,
     `\(coverage.volumesScanned)`, `\(percent)` and `\(noteless)` intact. The last sentence is the
     refusal — the noteless volumes, mostly the pre-1906 annuals, cannot appear on this axis. -->
<!-- SOURCE: FRUSExplorer/Browser/ArchivesBrowseView.swift | lines: 86–87 | key: browser.archives.coverage -->

FRUS’s editors printed a source note under \(coverage.noteCount) documents across \(coverage.volumesWithNotes) of \(coverage.volumesScanned) volumes — the archival record this axis browses. About \(percent)% of those notes name an archival collection; most of the rest cite a State Department central-file number. \(noteless) volumes, mostly the pre-1906 annuals, print no notes and cannot appear here.

<!-- END SOURCE: browser.archives.coverage -->

### 16.3 Administrations

#### The index caption
<!-- Placeholder note: keep `\(membershipSum)` and `\(index.volumeTotals.count)` intact. "Dated to
     each term, never by where a volume was published" is the coverage-not-production rule the
     administration profiles are built on; the double-counting disclosure explains why memberships
     sum past the volume count. -->
<!-- SOURCE: FRUSExplorer/Browser/AdministrationIndexView.swift | lines: 182–183 | key: browser.administrations.coverage -->

Volumes filed by the administration their documents cover — dated to each term, never by where a volume was published. A volume spanning two administrations appears under both: memberships sum to \(membershipSum) across \(index.volumeTotals.count) volumes.

<!-- END SOURCE: browser.administrations.coverage -->

#### The drill-in caption
<!-- Placeholder note: keep `\(profile.volumes.count)`, `\(profile.president)` and
     `\(termText(start: profile.start, end: profile.end))` intact. -->
<!-- SOURCE: FRUSExplorer/Browser/AdministrationIndexView.swift | lines: 108–109 | key: browser.administrations.drill.caption -->

\(profile.volumes.count) volumes with documents covering the \(profile.president) administration (\(termText(start: profile.start, end: profile.end))), largest share first. Membership: any dated document. A volume spanning two administrations appears under both.

<!-- END SOURCE: browser.administrations.drill.caption -->

### 16.4 Subjects

#### The coverage statement
<!-- The two disclosures are the caption: counts describe all 553 volumes while search reaches
     only this device's index, and topics are DETECTED, not editorial — "so some are wrong" is a
     sentence the feature owes the reader and must survive editing. -->
<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | lines: 485–486 | key: subjects.index.coverage.v2 %lld %lld -->

%1$lld assigned topics across the whole series. Counts describe all %2$lld cataloged volumes, not the volumes you have indexed — a search reaches only what is on this device. Topics are drawn from experimental enrichment data, not editorial subject headings, so some are wrong.

<!-- END SOURCE: subjects.index.coverage.v2 %lld %lld -->

#### The topic-area chip (#1365)
<!-- Shown above the index when it is narrowed to one topic area ("All Cold War topics" on a
     topic's sheet). Four forms, chosen in code: the first two when every topic in the area is
     listed, the last two when the reader's search hides some of them — before #1365 the chip
     counted the area alone and read "6 topics" over a list of one. Placeholders: `%1$@` (or the
     bare `%@`) is the area's name, `%2$@` the number listed or the area's size, `%3$@` the area's
     size; the numbers arrive already grouped. The "one" forms are for an area of ONE topic, so
     they must keep "1 topic" singular — "0 of 1 topic" is what the third form prints. -->
<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexGrouping.groupFilterCaption | lines: 317–318 | key: subjects.index.groupFilter.all.one %@ -->

Topic area: %@ — 1 topic

<!-- END SOURCE: subjects.index.groupFilter.all.one %@ -->

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexGrouping.groupFilterCaption | lines: 320–321 | key: subjects.index.groupFilter.all.many %@ %@ -->

Topic area: %1$@ — %2$@ topics

<!-- END SOURCE: subjects.index.groupFilter.all.many %@ %@ -->

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexGrouping.groupFilterCaption | lines: 325–326 | key: subjects.index.groupFilter.some.one %@ %@ -->

Topic area: %1$@ — %2$@ of 1 topic

<!-- END SOURCE: subjects.index.groupFilter.some.one %@ %@ -->

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexGrouping.groupFilterCaption | lines: 328–329 | key: subjects.index.groupFilter.some.many %@ %@ %@ -->

Topic area: %1$@ — %2$@ of %3$@ topics

<!-- END SOURCE: subjects.index.groupFilter.some.many %@ %@ %@ -->


---

## 17. Browse — when a section's documents cannot be loaded (#1301)

*The three strings of one row on the Browse compilation/chapter screen. Before #1301 a document load
that failed, or that was never started, drew the same spinner as one in flight — for ever, with no
error row and no way to ask again; this row is the terminal state that replaced it. The heading is
worded after `VolumeView`'s structure-error row, which shows no error text at all; the sentence under
it is new in round 2 and replaced the system's own "The operation couldn’t be completed.
(FRUSExplorer.IndexingError error 2.)", which is what a reader saw while the row printed the raw
error. The standing rule for the three: the reader cannot tell a damaged index from a missing table
and does not need to — what they can act on is the button. Do not promise that retrying will work,
and do not name a cause the app has not established.*

### Could not load this section's documents.
<!-- SOURCE: FRUSExplorer/Browser/CompilationView.swift | lines: 498–499 | key: browser.compilation.loadFailed -->

Could not load this section’s documents.

<!-- END SOURCE: browser.compilation.loadFailed -->

### The sentence under it
<!-- This is shown for every failure the row can reach, including ones carrying no message of their
     own. An error that HAS a reader-facing sentence (the unavailable-index one in §14) keeps its
     own wording instead, so edits here must stand alone rather than continue that one. -->
<!-- SOURCE: FRUSExplorer/Browser/CompilationDocumentsPresentation.swift | lines: 117–118 | key: browser.compilation.loadFailed.detail -->

FRUS Explorer could not read this section from its search index. Retry below; if it keeps failing, index this volume again.

<!-- END SOURCE: browser.compilation.loadFailed.detail -->

### Retry
<!-- A button label on the row above, beside a circular-arrow icon. Keep it a verb the reader can
     act on — it asks for the same section's documents again, and it is the only way out of the
     error row: this screen has no pull-to-refresh. -->
<!-- SOURCE: FRUSExplorer/Browser/CompilationView.swift | lines: 510–511 | key: browser.compilation.loadFailed.retry -->

Retry

<!-- END SOURCE: browser.compilation.loadFailed.retry -->

---

## 18. Prose this file had never carried (build-48 sweep) — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### 18.1 Search — scope footers, prompts, Meaning mode, facets and collocations

*The Search screen's explanatory text outside the Search Tips (§7.13) and the result-set copy §7 already carries: the filter and project-scope footers, the Meaning-mode prompts and notices, the facet panel's coverage lines, the collocation refusals, and the notice when a saved corpus had to be truncated.*

#### The person filter was cleared — \(…) is no longer in the…
<!-- SOURCE: FRUSExplorer/App/MacSearchViewModel.swift | MacSearchViewModel.refreshPersonRollupBinding | lines: 673–674 | key: search.person.filterDropped | same text also in: FRUSExplorer/Search/SearchViewModel.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

The person filter was cleared — \(before.label ?? "that person") is no longer in the indexed corpus.

<!-- END SOURCE: search.person.filterDropped -->

#### Tooltip — How to read these results. The concordance covers %@; the…
<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | MacSearchWindowView.searchToolbar | lines: 1090–1091 | key: search.reading.help %@ | shared: macOS only -->

How to read these results. The concordance covers %@; the others cover the whole retained set.

<!-- END SOURCE: search.reading.help %@ -->

#### Tooltip — Open advanced filters — date range, volume scope, document…
<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | MacSearchWindowView.advancedFiltersButton | lines: 1521–1522 | key: search.filter.advanced.help | shared: macOS only -->

Open advanced filters — date range, volume scope, document type, person, search scope. Changes apply immediately.

<!-- END SOURCE: search.filter.advanced.help -->

#### This breakdown stopped at \(…) of \(…) values.
<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.sectionBody | lines: 840–841 | key: facets.bound -->

This breakdown stopped at \(bound.shown.formatted()) of \(bound.total.formatted()) values.

<!-- END SOURCE: facets.bound -->

#### Subjects detected for \(…) of \(…) matches.
<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.subjectsCaveat | lines: 1097–1098 | key: facets.subjects.coverage -->

Subjects detected for \(facets.subjectCoverage.formatted()) of \(facets.matchCount.formatted()) matches.

<!-- END SOURCE: facets.subjects.coverage -->

#### Detected topics from the Office of the Historian, matched…
<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.subjectsCaveat | lines: 1105–1106 | key: facets.subjects.provenance -->

Detected topics from the Office of the Historian, matched by name — not the volumes’ own markup.

<!-- END SOURCE: facets.subjects.provenance -->

#### Ranks the collections behind all %lld volumes these matches…
<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.archivalProfileButton | lines: 1195–1196 | key: facets.provenance.openProfile.detail %lld -->

Ranks the collections behind all %lld volumes these matches sit in — whole volumes, not the matches themselves.

<!-- END SOURCE: facets.provenance.openProfile.detail %lld -->

#### \(…) match no document in your current scope.
<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | QueryZeroResultView.body | lines: 411–412 | key: search.empty.severalEmpty -->

\(emptyConjuncts.map(\.text).joined(separator: ", ")) match no document in your current scope.

<!-- END SOURCE: search.empty.severalEmpty -->

#### History limits results to the 1 document you’ve collected…
<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | SearchFilterView.projectScopeFooter | lines: 368–369 | key: search.projectscope.footer.history.one -->

History limits results to the 1 document you’ve collected, annotated, or opened in this project.

<!-- END SOURCE: search.projectscope.footer.history.one -->

#### History limits results to the \(…) documents you’ve…
<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | SearchFilterView.projectScopeFooter | lines: 370–371 | key: search.projectscope.footer.history.other -->

History limits results to the \(n) documents you’ve collected, annotated, or opened in this project.

<!-- END SOURCE: search.projectscope.footer.history.other -->

#### Choose History to search only what you’ve engaged, or Focus…
<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | SearchFilterView.projectScopeFooter | lines: 394–395 | key: search.projectscope.footer.off -->

Choose History to search only what you’ve engaged, or Focus to discover across the volumes your project’s subjects define.

<!-- END SOURCE: search.projectscope.footer.off -->

#### Documents without a parseable date are excluded. Documents…
<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | SearchFilterView.dateRangeSection | lines: 421–422 | key: search.daterange.help -->

Documents without a parseable date are excluded. Documents with only a year or month in their dateline are treated as January 1 of that period and may appear as false positives near range boundaries.

<!-- END SOURCE: search.daterange.help -->

#### Counts are how many of your closest matches carry that tag.
<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | SearchFilterView.countFooterText | lines: 628–629 | key: search.usertags.countFooter.meaning -->

Counts are how many of your closest matches carry that tag.

<!-- END SOURCE: search.usertags.countFooter.meaning -->

#### Footer — Applying a scope fills the volume picker with its indexed…
<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | SearchFilterView.customScopeSection | lines: 768–769 | key: search.scope.custom.footer -->

Applying a scope fills the volume picker with its indexed members. Manage scopes in Settings.

<!-- END SOURCE: search.scope.custom.footer -->

#### Subseries and volumes combine: results include every…
<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | SearchFilterView.volumeScopeFooter | lines: 1093–1094 | key: search.scope.volume.footer -->

Subseries and volumes combine: results include every document in the chosen subseries plus any individually chosen volumes. Only indexed volumes are listed.

<!-- END SOURCE: search.scope.volume.footer -->

#### Ask a question to search the FRUS corpus by meaning.
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchMode.initialPrompt | lines: 147–148 | key: search.prompt.meaning -->

Ask a question to search the FRUS corpus by meaning.

<!-- END SOURCE: search.prompt.meaning -->

#### Ask a question to search within the selected volumes.
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchMode.initialPrompt | lines: 150–151 | key: search.prompt.meaning.scoped -->

Ask a question to search within the selected volumes.

<!-- END SOURCE: search.prompt.meaning.scoped -->

#### Ask a question to rank the %@ you are searching within by meaning.
<!-- #1577 lane 1 (2026-10-10): the pre-search prompt in Meaning mode while a working corpus or a
     project's History scope is applied, in place of the two prompts above. iPhone and iPad only;
     the Mac window has no pre-search prompt. The Keywords prompts are unchanged. -->
<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchMode.documentSetPrompt | lines: 176–177 | key: search.prompt.meaning.withinSet %@ -->

Ask a question to rank the %@ you are searching within by meaning. *(%@ is the set's size with its noun, “1 document” or “212 documents”.)*

<!-- END SOURCE: search.prompt.meaning.withinSet %@ -->

#### %1$@ in %2$@ could not be scored…
<!-- #1527 (2026-09-30): two texts, your option (a), by the same rule as the empty state's pair
     above. In each, %1$@ is the count of possible matches with its noun and %2$@ the volumes'
     ("1 possible match", "1 volume"), from the forms below; the first was "%lld … %lld" until review
     round 1 (2026-09-30), which read "1 possible matches in 1 volumes". -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.unscored | lines: 179–180 | key: search.semantic.results.unscored.v2 %@ %@ -->

%1$@ in %2$@ could not be scored yet; their match files are downloading.

<!-- END SOURCE: search.semantic.results.unscored.v2 %@ %@ -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.unscored | lines: 184–185 | key: search.semantic.results.unscored.notFetching %@ %@ -->

%1$@ in %2$@ could not be scored. Try Download Vectors for Every Volume in Settings to enable scoring.

<!-- END SOURCE: search.semantic.results.unscored.notFetching %@ %@ -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.unscored | key: search.semantic.possibleMatches.one -->

%@ possible match

<!-- END SOURCE: search.semantic.possibleMatches.one -->

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.unscored | key: search.semantic.possibleMatches.many -->

%@ possible matches

<!-- END SOURCE: search.semantic.possibleMatches.many -->

#### The model could not be downloaded. You can try again from…
<!-- SOURCE: FRUSExplorer/Search/SemanticSearchSharedViews.swift | SemanticModelOfferCard.downloadModel | lines: 190–191 | key: search.semantic.downloadFailed -->

The model could not be downloaded. You can try again from the button above, or from Settings.

<!-- END SOURCE: search.semantic.downloadFailed -->

### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects

*Coverage captions and empty states on the Browse axes that §16 does not carry, and the Browse root's tile tooltips.*

#### You can browse this volume’s contents now. Re-index it to…
<!-- SOURCE: FRUSExplorer/App/MacCorpusBrowserWindow.swift | CorpusVolumeDetailView.indexStatusBanner | lines: 1196–1197 | key: corpus.volume.indexInterrupted.detail | shared: macOS only -->

You can browse this volume’s contents now. Re-index it to restore full search coverage and document text.

<!-- END SOURCE: corpus.volume.indexInterrupted.detail -->

#### You can browse this volume’s contents now. Index it to…
<!-- SOURCE: FRUSExplorer/App/MacCorpusBrowserWindow.swift | CorpusVolumeDetailView.indexStatusBanner | lines: 1198–1199 | key: corpus.volume.indexRequired.detail | shared: macOS only -->

You can browse this volume’s contents now. Index it to search inside it and open its documents.

<!-- END SOURCE: corpus.volume.indexRequired.detail -->

#### Counts are documents whose printed source note names the…
<!-- SOURCE: FRUSExplorer/Browser/ArchivesArrangement.swift | ArchivesArrangement.collectionCaption | lines: 478–479 | key: browser.archives.collections.counts -->

Counts are documents whose printed source note names the collection; one cited only in a volume’s front matter shows its volumes alone.

<!-- END SOURCE: browser.archives.collections.counts -->

#### Record groups are the National Archives’ own divisions.…
<!-- SOURCE: FRUSExplorer/Browser/ArchivesArrangement.swift | ArchivesArrangement.collectionCaption | lines: 481–482 | key: browser.archives.collections.noRecordGroup -->

Record groups are the National Archives’ own divisions. Collections whose citations name none — nearly every presidential-library collection among them — are listed together last.

<!-- END SOURCE: browser.archives.collections.noRecordGroup -->

#### \(…) volumes with documents drawn from \(…), largest count…
<!-- SOURCE: FRUSExplorer/Browser/ArchivesBrowseView.swift | ArchivesAxis.spec | lines: 134–135 | key: browser.archives.drill.caption -->

\(byVolume.count) volumes with documents drawn from \(name), largest count first. Percentages are each volume’s share of its own sourced documents — the notes printed under documents, not every document in the volume.

<!-- END SOURCE: browser.archives.drill.caption -->

#### Central-file classes, grouped by the filing schedule in…
<!-- SOURCE: FRUSExplorer/Browser/ArchivesBrowseView.swift | ArchivesIndexView.classesLens | lines: 387–397 | key: browser.archives.classes.caption -->

Central-file classes, grouped by the filing schedule in force. A volume is counted in the era its coverage falls inside; one spanning two schedules is counted in neither, because the same number means different things on either side. Readings come from the Department’s own filing manuals. Each era lists every class its volumes’ source notes cite; by class number, it follows its own file — decimal numbers digit by digit, so 711.11 comes before 711.2, and subject-numeric designators by their numbers.

<!-- END SOURCE: browser.archives.classes.caption -->

#### About \(…)% of sourced documents name an archival…
<!-- SOURCE: FRUSExplorer/Browser/ArchivesBrowseView.swift | ArchivesIndexView.collectionsLens | lines: 539–540 | key: browser.archives.collections.ceiling -->

About \(ArchivesAxis.collectionSharePercent(coverage: usage.coverage))% of sourced documents name an archival collection; the rest — mostly central-file citations — are under Provenance Types.

<!-- END SOURCE: browser.archives.collections.ceiling -->

#### Volumes citing %1$@ whose coverage falls inside %2$@.…
<!-- SOURCE: FRUSExplorer/Browser/ArchivesClassAxis.swift | ArchivesClassAxis.spec | lines: 276–280 | key: browser.archives.class.caption %@ %@ -->

Volumes citing %1$@ whose coverage falls inside %2$@. Counted from document source notes.

<!-- END SOURCE: browser.archives.class.caption %@ %@ -->

#### The cluster data and the semantic vectors come from…
<!-- SOURCE: FRUSExplorer/Browser/ClustersBrowseView.swift | ClustersIndexView.unavailableText | lines: 292–293 | key: browser.clusters.mismatch -->

The cluster data and the semantic vectors come from different releases, so the list is not shown.

<!-- END SOURCE: browser.clusters.mismatch -->

#### Footer — Saved “\(…)” with the first \(…) of \(…) documents.
<!-- SOURCE: FRUSExplorer/Browser/ClustersBrowseView.swift | ClusterDocumentsView.actionsSection | lines: 804–805 | key: browser.clusters.saved.truncated -->

Saved “\(savedCorpusName)” with the first \(savedCapture.documentKeys.count) of \(savedCapture.total) documents.

<!-- END SOURCE: browser.clusters.saved.truncated -->

#### Empty state — A working corpus is a fixed set of documents captured from…
<!-- SOURCE: FRUSExplorer/Browser/CorpusBrowseView.swift | CorporaIndexView.body | lines: 199–200 | key: browser.corpora.empty.detail -->

A working corpus is a fixed set of documents captured from a result set — use “Save as Working Corpus” on Search results or the semantic map’s lasso.

<!-- END SOURCE: browser.corpora.empty.detail -->

#### Footer — A corpus is captured from a result set — in Search results…
<!-- SOURCE: FRUSExplorer/Browser/CorpusBrowseView.swift | CorporaIndexView.body | lines: 209–210 | key: browser.corpora.footer -->

A corpus is captured from a result set — in Search results or with the semantic map’s lasso — and syncs via iCloud. There is nothing to create here.

<!-- END SOURCE: browser.corpora.footer -->

#### Tooltip — Browse an alphabetical index of all people mentioned across…
<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | CorpusView.crossVolumeIndicesSection | lines: 319–320 | key: browser.corpus.people.help -->

Browse an alphabetical index of all people mentioned across your indexed volumes — tap a name to search for every document where they appear

<!-- END SOURCE: browser.corpus.people.help -->

#### Tooltip — Browse an index of the topics detected across the whole…
<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | CorpusView.crossVolumeIndicesSection | lines: 350–351 | key: browser.corpus.subjects.help -->

Browse an index of the topics detected across the whole series — including volumes you have not downloaded. Tap one to see its reach and find documents on it

<!-- END SOURCE: browser.corpus.subjects.help -->

#### Tooltip — One catalogue of every volume — search it, or arrange it by…
<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | CorpusView.browseBySection | lines: 404–405 | key: browser.corpus.tile.catalogue.help -->

One catalogue of every volume — search it, or arrange it by title, publication year, era, or length

<!-- END SOURCE: browser.corpus.tile.catalogue.help -->

#### Tooltip — Volumes filed by the kind of file their documents came…
<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | CorpusView.browseBySection | lines: 461–462 | key: browser.corpus.tile.archives.help -->

Volumes filed by the kind of file their documents came from, and the archival collections FRUS drew on

<!-- END SOURCE: browser.corpus.tile.archives.help -->

#### Tooltip — Documents grouped by the language they share, computed from…
<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | CorpusView.browseBySection | lines: 480–481 | key: browser.corpus.tile.clusters.help -->

Documents grouped by the language they share, computed from the text — labels are sampled terms, not subject headings

<!-- END SOURCE: browser.corpus.tile.clusters.help -->

#### Tooltip — Fixed document sets captured from Search results or the…
<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | CorpusView.yourSetsSection | lines: 559–560 | key: browser.corpus.corpora.help -->

Fixed document sets captured from Search results or the semantic map — browse each one’s documents, grouped by volume

<!-- END SOURCE: browser.corpus.corpora.help -->

#### Empty state — A scope is a set of volumes you assemble yourself. Create…
<!-- SOURCE: FRUSExplorer/Browser/ScopeBrowseView.swift | ScopeIndexView.body | lines: 325–326 | key: browser.scopes.empty.detail -->

A scope is a set of volumes you assemble yourself. Create one here, or use “Save as Scope” on any axis’s volume list.

<!-- END SOURCE: browser.scopes.empty.detail -->

#### Volume sets you assemble yourself, most recently edited…
<!-- SOURCE: FRUSExplorer/Browser/ScopeBrowseView.swift | ScopeIndexView.body | lines: 331–332 | key: browser.scopes.coverage -->

Volume sets you assemble yourself, most recently edited first. Scopes also narrow Search, analytics, and word clouds — and sync via iCloud.

<!-- END SOURCE: browser.scopes.coverage -->

#### Empty state — The detected-topic index did not load, so topics cannot be…
<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexView.unavailableSection | lines: 519–520 | key: subjects.index.unavailable.message -->

The detected-topic index did not load, so topics cannot be browsed. Everything else in the app is unaffected.

<!-- END SOURCE: subjects.index.unavailable.message -->

#### Footer — The first three figures describe the whole series…
<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectDetailSheet.body | lines: 617–618 | key: subjects.detail.footer -->

The first three figures describe the whole series, including volumes you have not downloaded. Only the last one is what a search here can return. Topics are detected automatically from the text, not editorial subject headings.

<!-- END SOURCE: subjects.detail.footer -->

#### Tooltip — Filter volumes by research topic — select one or more tags…
<!-- SOURCE: FRUSExplorer/Browser/SubseriesView.swift | SubseriesTagFilterBar.body | lines: 272–273 | key: browser.filter.addTag.help -->

Filter volumes by research topic — select one or more tags to narrow the list to volumes covering those themes

<!-- END SOURCE: browser.filter.addTag.help -->

#### \(…) volumes. Publication year is the print year. Document…
<!-- SOURCE: FRUSExplorer/Browser/VolumeCatalogueView.swift | VolumeCatalogueView.controlSection | lines: 403–404 | key: browser.catalogue.coverage -->

\(entries.count) volumes. Publication year is the print year. Document counts are FRUS document divs from the bundled index; Search over the same volume can return more rows.

<!-- END SOURCE: browser.catalogue.coverage -->

#### Tooltip — No documents in your indexed volumes cite this collection…
<!-- SOURCE: FRUSExplorer/Browser/VolumeSourcesView.swift | VolumeSourcesView.sourceNodeRow | lines: 440–441 | key: browser.sources.archivalNeighbors.zero.help -->

No documents in your indexed volumes cite this collection — indexing more volumes may surface some

<!-- END SOURCE: browser.sources.archivalNeighbors.zero.help -->

#### Archival Neighbors — no documents in your indexed volumes…
<!-- SOURCE: FRUSExplorer/Browser/VolumeSourcesView.swift | VolumeSourcesView.neighborsAccessibilityLabel | lines: 534–535 | key: browser.sources.archivalNeighbors.zero.accessibility -->

Archival Neighbors — no documents in your indexed volumes cite this collection; indexing more volumes may surface some

<!-- END SOURCE: browser.sources.archivalNeighbors.zero.accessibility -->

#### No subjects detected for this volume yet. The topic data is…
<!-- SOURCE: FRUSExplorer/Browser/VolumeSubjectsView.swift | VolumeSubjectsChips.body | lines: 75–76 | key: browser.volume.subjects.none -->

No subjects detected for this volume yet. The topic data is the Office of the Historian's own subject export, and it does not cover this volume.

<!-- END SOURCE: browser.volume.subjects.none -->

#### Ranks the collections and file series the %lld volumes…
<!-- SOURCE: FRUSExplorer/Browser/VolumeSubjectsView.swift | VolumeSubjectVolumesSheet.archivalProfileSection | lines: 339–340 | key: browser.volume.subjectVolumes.archival.footer %lld -->

Ranks the collections and file series the %lld volumes covering this subject draw on. The scope is whole volumes, not the documents about this subject inside them — and the subjects themselves are detected automatically, not editorial headings.

<!-- END SOURCE: browser.volume.subjectVolumes.archival.footer %lld -->

#### Footer — Shows this topic’s reach across the whole series, and finds…
<!-- SOURCE: FRUSExplorer/Browser/VolumeSubjectsView.swift | VolumeSubjectVolumesSheet.subjectExplorerSection | lines: 363–364 | key: browser.volume.subjectVolumes.explore.footer -->

Shows this topic’s reach across the whole series, and finds the documents on it that you have indexed.

<!-- END SOURCE: browser.volume.subjectVolumes.explore.footer -->

### 18.8 Browse — people and editors

*The Editors axis, the person index and a person's detail page (merge, mentions, subjects), the corrections list, and a volume's front-matter persons list.*

#### \(…) naming \(…) as a volume editor, in publication order…
<!-- SOURCE: FRUSExplorer/Browser/EditorIndexView.swift | EditorIndexGrouping.spec | lines: 326–327 | key: browser.editors.drill.caption.v2 -->

\(CountCopy.volumes(row.volumeIds.count)) naming \(row.name) as a volume editor, in publication order. Editor credits are shown as printed on each title page.

*The first interpolation is the count and its noun — “1 volume”, “12 volumes” (#1374).*

<!-- END SOURCE: browser.editors.drill.caption.v2 -->

#### Volume editors as named on each title page. \(…) of \(…)…
<!-- SOURCE: FRUSExplorer/Browser/EditorIndexView.swift | EditorIndexView.coverageCaption | lines: 419–420 | key: browser.editors.coverage -->

Volume editors as named on each title page. \(named) of \(entries.count) volumes name editors — \(none) early volumes carry none, so this index cannot reach them. General editors are credited on the volume page, not indexed here.

<!-- END SOURCE: browser.editors.coverage -->

#### This volume’s editors did not publish a list of persons.…
<!-- SOURCE: FRUSExplorer/Browser/FrontMatterPersonsView.swift | FrontMatterPersonsView.body | lines: 99–100 | key: browser.persons.empty.noEditorList -->

This volume’s editors did not publish a list of persons. Roughly half the corpus has none — they are most common from 1940 onward.

<!-- END SOURCE: browser.persons.empty.noEditorList -->

#### Empty state — Merges and separations you make in the People browser…
<!-- SOURCE: FRUSExplorer/Browser/PersonCorrectionsView.swift | PersonCorrectionsSheet.content | lines: 281–282 | key: people.corrections.empty.detail -->

Merges and separations you make in the People browser appear here, where you can undo them.

<!-- END SOURCE: people.corrections.empty.detail -->

#### \(…)–\(…)
<!-- SOURCE: FRUSExplorer/Browser/PersonIndexView.swift | PersonLifespan.text | lines: 472–473 | key: people.detail.lifespan -->

\(born, format: plain)–\(died, format: plain)

<!-- END SOURCE: people.detail.lifespan -->

#### Born \(…)
<!-- SOURCE: FRUSExplorer/Browser/PersonIndexView.swift | PersonLifespan.text | lines: 475–476 | key: people.detail.lifespan.born -->

Born \(born, format: plain)

<!-- END SOURCE: people.detail.lifespan.born -->

#### Died \(…)
<!-- SOURCE: FRUSExplorer/Browser/PersonIndexView.swift | PersonLifespan.text | lines: 478–479 | key: people.detail.lifespan.died -->

Died \(died, format: plain)

<!-- END SOURCE: people.detail.lifespan.died -->

#### until \(…)
<!-- A person's active years when the volume's list names only the year they LEFT a post ("until
     June 5, 1953"). It follows the role after a middle dot in a list row ("Counselor of the Legation
     in Saudi Arabia until June 5, 1953; … · until 1953") and stands alone as the person sheet's
     Active value, so it starts in lower case. A range prints as "1949–1953" and a year the list
     gives as a start as "1953", neither of them a string. -->
<!-- SOURCE: FRUSCoreKit/TEI/FRUSASTNode.swift | PersonEntry.eraText | lines: 707–708 | key: people.era.until -->

until \(end, format: plain)

<!-- END SOURCE: people.era.until -->

#### Volume-level: subjects characteristic of the volumes where…
<!-- SOURCE: FRUSExplorer/Browser/PersonIndexView.swift | PersonIndexDetailSheet.detailList | lines: 809–810 | key: people.detail.subjects.note -->

Volume-level: subjects characteristic of the volumes where this person is mentioned — not per-document tags.

<!-- END SOURCE: people.detail.subjects.note -->

#### This person has no indexed document mentions to open — they…
<!-- SOURCE: FRUSExplorer/Browser/PersonIndexView.swift | PersonIndexDetailSheet.detailList | lines: 845–846 | key: people.detail.findMentions.noMentions -->

This person has no indexed document mentions to open — they appear only in a volume’s front-matter person list.

<!-- END SOURCE: people.detail.findMentions.noMentions -->

#### Footer — Use this when one person appears under different names and…
<!-- SOURCE: FRUSExplorer/Browser/PersonIndexView.swift | PersonIndexDetailSheet.detailList | lines: 893–894 | key: people.detail.mergeManual.footer -->

Use this when one person appears under different names and the app kept them apart. The change syncs across your devices and can be undone from Corrections.

<!-- END SOURCE: people.detail.mergeManual.footer -->

#### “%1$@” and “%2$@” will become a single identity. Merging is…
<!-- SOURCE: FRUSExplorer/Browser/PersonIndexView.swift | PersonIndexDetailSheet.mergeConfirmMessage | lines: 1127–1128 | key: people.detail.mergeConfirm.message %1$@ %2$@ -->

“%1$@” and “%2$@” will become a single identity. Merging is transitive — if you later merge a third record with either one, all three become one identity. You can undo this from Corrections.

<!-- END SOURCE: people.detail.mergeConfirm.message %1$@ %2$@ -->

#### These records match different entries in the bundled…
<!-- SOURCE: FRUSExplorer/Browser/PersonIndexView.swift | PersonIndexDetailSheet.mergeConfirmMessage | lines: 1131–1132 | key: people.detail.mergeConfirm.authorityWarning -->

These records match different entries in the bundled name-authority data, so they may be distinct. Merge only if you’re sure.

<!-- END SOURCE: people.detail.mergeConfirm.authorityWarning -->
