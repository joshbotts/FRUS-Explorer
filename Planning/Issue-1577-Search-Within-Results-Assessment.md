# Issue #1577, "Combined FTS/semantic search": assessment

Assessed 2026-10-07 at v2 f384d2d5 (build 49, index version 65). Read from the code; nothing was built or run.

**Decided 2026-10-08.** The owner took every recommended default in section 8. So Meaning mode ranks inside an applied working corpus, a layered search is not saved, the set-ranking step stays in the app's searcher, and lanes 4 and 5 land after #1576's selection lanes. The implementation plan to work from is on the issue: https://github.com/joshbotts/FRUS-Explorer/issues/1577#issuecomment-6058254302. Two things this document says in the future tense have since happened: the manual update has merged (#1580), and lanes edit the manuals themselves, leaving the AI Generated notice in place (owner, 2026-10-07; `Planning/Manual-Revisions-Pending.md` says so).

**In short**

- Build it as **Search Within These Results**: the reader holds the list on screen as a base, a row names it, and the search field then runs the other engine inside it.
- The one missing engine piece is a Meaning search that ranks a given set of documents. Today a Meaning search takes the corpus-wide top 100 and then throws away what is outside the set (`FRUSExplorer/Search/SemanticSearchBackend.swift:106-127`). The kit already has what the fix needs.
- Five pull requests close the issue. A sixth widens a keyword base from the rows loaded to the whole match and, on the recommended defaults, is the only one that edits shared kit code. A seventh is optional polish.
- No CloudKit deploy, no index-version bump, no export change and no re-index, on the recommended path.
- The web edition: no lane gains from breaking a coordination rule. Five choices the rules leave open cost the web side something, and section 5 shows each both ways.
- Seven decisions are yours (section 8). The first is whether Meaning mode should rank inside a working corpus from now on.

Every statement about behaviour comes from reading source at the line cited, so it is "the code says", not "the app was seen to". Paths are relative to the repository root. The timings quoted are the repository's own records, except those marked synthetic, which a script took on a synthetic SQLite index of the same shape on a Mac. Nothing is measured on an iPhone.

Terms used below:

- **Base:** the first search's result list.
- **Layer:** the second search, run inside the base with the other engine.
- **Pin:** a copy of the base, held in memory for the session.
- **Gate:** `SearchParameters.documentIds`, the document-set restriction a working corpus and a project's History scope already use.

## 1. The request, restated, and what it leaves open

The issue asks for two things, each a second search layered on a first:

1. **Words in matches.** Start with a Meaning search, then run a keyword search inside those results.
2. **Rank by meaning.** Start with a keyword search, then run a Meaning search over its results.

Neither exists as one action. The first can be done today by hand through Save as Working Corpus. The second runs today but does not do what is asked: with a corpus applied, Meaning mode takes the corpus-wide top 100 and keeps those that fall inside the corpus, which may be few or none.

| Left open | Recommended reading | Why |
| --- | --- | --- |
| What "the pinned set" is | The list as shown: the loaded rows less any that checklist mode hides. Session only | It is what Save as Working Corpus already captures (`displayedResults`), and the code has no other notion of a held set. Rows picked by hand can feed the same pin once #1576's selection exists |
| "Its results" for a keyword search: the rows loaded, or every match. The loaded rows are 1,000 for a keyword search on iPhone and iPad, and 7,500 on the Mac and for a filter-only browse on every platform. A code comment records 35,275 matches for `negotiations` over a date range (`FRUSExplorer/Search/SearchViewModel.swift:350-355`) | The loaded rows first, with the cut stated in the base row. The whole match as lane 6 | The loaded rows need no kit work and are the whole match for most searches. For a large match they are the BM25 top slice, and a different slice on each platform, so lane 6 is worth building. Decision 2 |
| Whether a filter-only browse can be a base | Yes, for a Meaning layer | It is the same code path, and a subject or person browse is a natural thing to rank by a question. It is also the largest set a phone holds, so the timing must cover it. Decision 6 |
| What a layer does | A keyword layer filters the base. A Meaning layer reorders it | Typed Meaning search has no score threshold anywhere, and none is calibrated, so it cannot filter |
| How many rows a Meaning layer returns | The whole pinned set, closest first. Rows that cannot be ranked go last under a count | The reader found those documents; a cut to 100 would lose some without saying which. Decision 3 |
| Order of a keyword layer's rows | The base's Meaning order, with the base's score on each row | The layer is "atop" the Meaning result. BM25 order inside 100 documents says little |
| Lifetime | The session. Save as Working Corpus is the durable form | A saved layered search needs a stored route, which nothing has today. Decision 4 |
| Depth and pairs | One base, one layer, the other engine | It is what the issue asks. Decision 5 |
| Same text or a second query | A second query | The engines want different input: terms, and a question |
| "Combined" as one fused ranking | Not designed | The body asks for layers |
| Other filters in Meaning mode (volumes, dates, people) | Unchanged: applied after ranking | The facet panel promises "Narrowing to a row returns exactly its documents" (`FRUSExplorer/Search/FacetPanelView.swift:588-596`), which holds only if they are |
| Meaning hits in volumes not downloaded | Left out of a pin, with the count stated | They have no index rows to search |

One consequence the screen must state: the same two queries give different lists in the two orders. Words in matches can return at most 100 documents, because a Meaning base is the top 100. Rank by meaning returns every loaded document that has the words.

Rank by meaning is likely the more useful of the two. That is an inference, not a finding: the repository's evaluation compared the two engines corpus-wide and tested neither layered order. It scored keywords 0.07 against 0.65 for meaning on nine research questions, a tie at 0.79 and 0.77 on search-box keywords, and 1.00 against 0.10 on two terms of art (`Planning/semantic-vectors/eval-2026-08-27/VERDICT.md:25-26`, `:39-40`).

## 2. What exists today that it builds on

### Both platforms

| Need | What exists | Where |
| --- | --- | --- |
| Keyword search inside a document set | The gate, rendered as chunked `IN` lists in the one search statement | `FRUSCoreKit/Search/SearchParameters.swift:174`; `FRUSCoreKit/Search/IndexingPipeline.swift:4294-4314` (kit) |
| Combining document gates | `DocumentScopeGate.combine`, an intersection that keeps an empty result as "match nothing" | `FRUSExplorer/Models/WorkingCorpusResolver.swift:104-120` |
| Exact scoring of any list of rows | `SemanticRetrievalKernel.rerank(candidates:limit:score:)`, `SemanticVectorIndex.row(documentID:volumeID:)`, `SemanticShard.cosine(row:query:queryScale:)`. `rerank` drops a row it cannot score (`:250`), so its caller counts the unranked | `SemanticVectorsKit/SemanticRetrievalKernel.swift:242-255`, `SemanticVectorIndex.swift:90-104`, `SemanticVectorReaders.swift:248` (kit, public) |
| A candidate scan restricted to some rows | `hammingCandidates(queryBits:in:limit:isEligible:)` | `SemanticVectorsKit/SemanticRetrievalKernel.swift:124-137`. The typed-query searcher passes no `isEligible` (`FRUSExplorer/Semantic/SemanticQuerySearcher.swift:160-162`) |
| A precedent for scoring a key list, with a per-volume shard cache | `SemanticSimilarityGenerator.reScore` | `FRUSExplorer/RelatedDocuments/SemanticSimilarityGenerator.swift:321-367` |
| The Meaning backend | `SemanticSearchBackend.run`: top 100 corpus-wide, then the filter intersection, an applied corpus included | `FRUSExplorer/Search/SemanticSearchBackend.swift:55`, `:105-127` |
| Rows that carry both a snippet and a Meaning score | `SearchResult`'s public initialiser takes `semanticScore`. Relevance order is the array's order | `FRUSCoreKit/Search/SearchParameters.swift:545-575`; `FRUSExplorer/Search/SearchViewModel.swift:403-409` |
| Count and capture sentences | `ResultSetScope`, with `isMeaningSearch` | `FRUSExplorer/Search/ResultSetScope.swift:66`, `:114`, `:297-319` |
| A description of the list frozen when a search completes | `UserTagCountScope`, set beside every `executedSearchVersion` bump in both view models | `FRUSExplorer/Search/SearchModels.swift:477`; `SearchViewModel.swift:706`, `:786`; `FRUSExplorer/App/MacSearchViewModel.swift:1067`, `:1151` |
| Recording a search's route with no new field | `SearchHistoryWriter.Reading.signatureOverride` and `renderedExpression`; `SearchScopeSignature` | `FRUSExplorer/Search/SearchHistoryWriter.swift:97-123`; `SearchScopeSignature.swift:60`, `:161-175` |
| The durable form of a held set | `WorkingCorpus`, `SaveWorkingCorpusSheet`, Filters ▸ My Working Corpora | `FRUSExplorer/Search/SearchFilterView.swift:795-836` |
| Meaning views | `SemanticModeStrip`, `SemanticMeaningEmptyState`, `SemanticScoreChip`, `SemanticModelOfferCard` | `FRUSExplorer/Search/SemanticMeaningModeViews.swift:17`, `:186`; `SemanticSearchSharedViews.swift` |
| Tests without the 229 MB model | `embedOverride` on the searcher; the kit's own writers for a corpus binary and a shard | `FRUSExplorer/Semantic/SemanticQuerySearcher.swift:111`, `:134-141`; `SemanticVectorsKit/SemanticVectorsArtifacts.swift:283`, `:337` |

### iPhone and iPad

One view, `SearchView`, with `SearchViewModel`, on both idioms.

- The Keywords | Meaning picker sits in the top inset above the actions bar (`FRUSExplorer/Search/SearchView.swift:542-556`, `:1336-1367`). A flip re-runs the standing query through the other engine and replaces the results.
- The actions bar is five controls in a row that "cannot wrap, scroll or fold" (`:1369-1393`). The More menu holds Save this search and Save as Working Corpus… (`:1134-1215`); the sort menu is at `:1397-1424`.
- `workingCorpusBanner` is the idiom for "you are inside a set": one line and a close button (`:1439-1468`).
- The loaded list is at most 1,000 rows for a keyword search, 7,500 for a filter-only browse and 100 for Meaning, 25 to a page (`SearchViewModel.swift:517`, `:533`, `:545`). A browse row carries no body snippet (`:519-533`).
- The gate is composed in `searchParameters` on every read (`SearchViewModel.swift:1074-1075`).
- Emptying the field clears the results (`SearchView.swift:502-512`).
- `applyParameters`, which every hand-off and saved-search recall uses, resets the project scope but not an applied corpus (`SearchViewModel.swift:1485-1540`). Clear Filters does clear it (`:894-925`).
- While checklist mode is on, its marks reset on every completed search (`:712-716`, `:790-794`).

### Mac

A separate implementation: `MacSearchWindowView` in `FRUSExplorer/App/SearchSheet.swift` with `MacSearchViewModel`.

- The picker sits beside the query field (`SearchSheet.swift:655-681`). The engine is part of the search trigger (`MacSearchViewModel.swift:187`), so a flip re-runs the submitted query at once.
- The toolbar holds the Reading picker, Save as Working Corpus…, Checklist and Facets (`SearchSheet.swift:1062-1139`). It has no shortcuts, by a recorded decision that they wait for a Search command channel (`:1053-1061`).
- The sort bar is at `:1626-1684`, the corpus banner at `:1825-1859`.
- The loaded list is at most 7,500 rows (`MacSearchViewModel.swift:325`).
- An applied corpus lives only on `filterVM`, which does not exist until Advanced… has been opened once (`MacSearchViewModel.swift:236`; `SearchSheet.swift:1469-1470`). Without it `scopeDerivedParams()` returns no gate (`MacSearchViewModel.swift:914`).
- An empty submitted query clears the results (`:990-997`, `:1108-1117`), and the count label hides while the field is empty (`SearchSheet.swift:1631`).
- Checklist marks reset when the submitted query's text changes, not on each run (`MacSearchViewModel.swift:1034`, `:1131`).
- No Mac test target exists. Mac logic is tested only where it lives in types the iOS unit target compiles.

### Facts settled by reading

- **How to score a set.** Exact scoring of every member, at every size this design reaches, lane 6's whole match included.
  - Both kit entry points exist and are public, but the restricted candidate scan has no use here. It would have to return at least as many candidates as rows shown (1,000 or 7,500), which is above the 800-row pool the recall figure was measured at.
  - The recorded cost of exact scoring is 0.113 ms for 800 rows on an M1 Max (`Planning/semantic-vectors/Dimension-Ladder-Spike.md:44`). That covers rows already located, with their shards in hand. It leaves out key-to-row resolution and shard mapping.
  - Scaled by row count, the arithmetic for 35,275 rows is about 5 ms on that Mac. That is an extrapolation, not a measurement.
- **How an older build reads a new trail signature.** `describe` returns nothing only when a part has no `=` or `mode` is missing; an unknown extra key on a keyword signature is ignored (`SearchScopeSignature.swift:161-175`). The method appendix treats a row as a Meaning search by the prefix `route=semantic` (`FRUSExplorer/Export/QueryMethodAppendix.swift:228-229`). So a Meaning layer's signature must start with `route=semantic`. A `route=hybrid` prefix would let an older build count its zero as a term's absence.
- **Where the trail's fields are printed.** `renderedExpression` reaches the appendix's CSV only (`QueryMethodAppendix.swift:79-81`, `:437`). The scope prose in the Markdown, the plain text and a collection export's appendix comes from `scopeProse`, which reads the signature and the applied corpus's name (`:592-602`).
- **How the trail decides a re-run, and prints a count.** The writer refreshes the anchored row whenever the query text is the same, whatever the scope (`SearchHistoryWriter.swift:172`). The appendix prints a count through `recordedCount`: with no match count, loaded rows at or above the recorded limit read "at least N" (`FRUSExplorer/Models/SearchHistoryEntry.swift:204-213`; `QueryMethodAppendix.swift:611-617`).
- **How many places read the live mode.** Twenty comparisons in the two view files: 17 `== .meaning` (9 in `SearchView.swift`, 8 in `SearchSheet.swift`) and 3 `== .keywords`.
  - Two more, in the view models, choose the engine (`SearchViewModel.swift:646`; `MacSearchViewModel.swift:981`).
  - Several of the twenty concern the input, not the results (`SearchView.swift:1546`, `:1741`, `:2496`; `SearchSheet.swift:314`, `:2208`). Only those that describe results need to move.
  - Neither view model freezes the route with the results. `lastRunWasSemantic` is documented as frozen (`SearchViewModel.swift:637`) but is written before the await on both (`:650`, `:771`; `MacSearchViewModel.swift:985`, `:1127`), the trap `SearchModels.swift:474-476` warns of. Only the trail reads it (`SearchViewModel.swift:880`; `MacSearchViewModel.swift:1219`). The precedent for a frozen description is `userTagCountScope`.
- **Where the Mac can hold a pin.** Not where it holds a corpus, for the `filterVM` reason above, and not in the stored `parameters` either: the filter summary and the token caption read that value and would misname a pin (rule 3). It goes on `MacSearchViewModel` itself.
- **Whether the whole-match method can live outside the kit.** No. `matchCTE` and `filterConditions` are private to the kit file (`IndexingPipeline.swift:3455`, `:4280`), and so is `SearchService.makeFilters` (`FRUSCoreKit/Search/SearchService.swift:477`).
- **Whether the searcher's tests run in a lane worktree.** No. `SemanticQuerySearcherTests` is enabled only when two gitignored shard files exist (`FRUSExplorerTests/SemanticQuerySearcherTests.swift:24-27`, `:63`; `.gitignore:59`). A fresh worktree has none, and the suite reports green either way.

### Existing defects this work runs into

All read from code, none seen running.

| Defect | Where | Handled by |
| --- | --- | --- |
| Mac: a full 100-row Meaning list shows the over-cap advisory, "Narrow your search…" | `MacSearchViewModel.swift:305-309`, `:1137`; `SearchSheet.swift:1878-1879` | Lane 2 |
| Mac: "Visualize in Corpus Analytics" is offered on a Meaning list and hands the question over as a term | `SearchSheet.swift:1776-1787` | Lane 2 |
| iPhone and iPad: flipping to Meaning over a filter-only browse leaves keyword rows under a "closest matches" header | `SearchView.swift:996`, `:1353-1356` | Lane 2 |
| A Meaning list saved as a working corpus is stored as complete "Search results". Both hosts pass `ResultSetScope` a constant ceiling, so 100 rows never read as cut, and the typed flag is false too | `ResultSetScope.swift:134-138`, `:297-319`; `SearchView.swift:991`; `SearchSheet.swift:1864`; `FRUSExplorer/Search/SaveWorkingCorpusSheet.swift:181` | Lane 2 |
| iPhone and iPad: a complete filter-only browse of 1,000 to 7,499 rows is described as cut, with the "Add more keywords or filters" line, and a corpus saved from it is stored as cut. The host passes 1,000, not the 7,500 the browse was fetched at | `SearchView.swift:991`, `:1799`, `:2065-2068`; `ResultSetScope.swift:134-138`; `SearchViewModel.swift:679` | Lane 2 |
| Mac: after a hand-off the banner still reads "Inside …" over a search that is no longer gated | `MacSearchViewModel.swift:874`; `SearchSheet.swift:1827` | Its own issue; lane 5 must not copy it |
| iPhone and iPad: a hand-off runs inside whatever corpus was applied | `SearchViewModel.swift:1532-1539` | Its own issue |
| A search saved in Meaning mode comes back as a keyword search of the same text | `SearchView.swift:658-663`; `SearchSheet.swift:634-638` | Its own issue |

## 3. Recommended design

The spine is to fix the engine first and then add the control. Two things are added to it: one frozen description of the list, with the rule that every hand-off leaves the base; and a single list shape, with a base row in place of the picker and whole-set reordering.

### Rules the code must hold

1. **Words and filters decide which documents are in the list. Meaning decides their order.** Both layers produce the same kind of list: documents from the base that contain the words, closest to the question first, each row with its keyword snippet and its Semantic match chip.
2. **The base is frozen.** Filters edited during a layer can only narrow it.
3. **Every hand-off leaves the base, and only the base row names it.**
   - `applyParameters` on both platforms and a saved-search run leave it. `clearAll` is given the same clear, though only a test calls it (`FRUSExplorerTests/SearchViewTests.swift:93`).
   - Clear Filters does not, so the reader can drop a date range without losing a Meaning list that a re-run might not reproduce.
   - The pin is a scope, not a filter. It does not light the filter glyph. On the Mac it must not reach the two readers of the gate that would misname it: the filter summary, which would call it "project" when Advanced… has never been opened (`MacSearchViewModel.swift:526-533`), and the token caption, which would read "also narrowed by a document scope — see Advanced" (`FRUSExplorer/App/SearchFilterTokens.swift:314-328`, `:345-358`).
   - The Query Inspector does read the gate (`FRUSExplorer/Search/QueryInspection.swift:579`), and should. Its counts "in your current scope" are then counts inside the base, which is what ran.
4. **A document that cannot be ranked is shown last under a count.** It is never dropped silently and never scored as zero.
5. **A layer never overwrites the base's trail row.** The pin sets the trail anchor aside to make that so, because the writer refreshes by query text alone.
6. **Keys only.** Nothing caches rowids across calls: a re-indexed volume gets new ones.
7. **The corpus-wide semantic fallback is not shown while a base is held.** It ignores every filter and would answer a different question.
8. **No gate sent through SQL exceeds 32,766 keys**, the bind limit the kit's own comment gives (`FRUSCoreKit/Search/SearchParameters.swift:182-183`). The recommended path never exceeds 7,500.

### What the reader sees

**Words in matches.**

1. Ask a question in Meaning mode. The header reads "100 closest matches".
2. Choose **Find Words in These Matches**. A base row replaces the Keywords | Meaning control: *Within 100 closest matches to "how did the embassy…"*, with a close button. The field empties and takes focus, its prompt reads "Words to find in these matches…", and the 100 rows stay on screen.
3. Type `SAVAK OR "secret police"`. The header reads "7 of your 100 closest matches contain these words". Rows stay closest first, with the words bold in the snippet and the base's score on the chip. The Query Inspector, the readings and Facets work, because a real keyword match ran.
4. With no hits: "None of your 100 closest matches contains these words", with **Search the Whole Library for These Words** and **Back to the 100 Matches**.

**Rank by meaning.**

1. Search `"offset agreement"`: 212 results.
2. Choose **Rank These Results by a Question**. The base row reads *Within 212 results for "offset agreement"*, and the prompt "A question to rank these results by…".
3. Type the question. The same 212 rows reorder, closest first, each keeping its keyword snippet and gaining a chip. The header reads "212 results, closest first", or "212 results · 203 ranked · 9 not ranked".
4. The strip says why rows went unranked: front matter and headings have no vectors, or a volume's match file is not on this device. For the second it names **Download Missing Vectors**, in a new sentence. Today's copy names Download Vectors for Every Volume (`SemanticMeaningModeViews.swift:115`, `:136`), the right control for a corpus-wide search and the wrong one for the reader's own downloaded volumes (`:66-78`).
5. Where the base was cut at the load ceiling, the base row says so: *Within the first 1,000 of 35,275 results for "negotiations"*.
6. On a filter-only browse the base row names the filter, since there is no query, and rows keep the header line they have.
7. With no search model on the device, the existing download offer appears in the results area and the base row stays.

Closing the base row restores the base list and its figures from memory, with no search, refills the field and brings the mode control back.

| | iPhone | iPad | Mac |
| --- | --- | --- | --- |
| Way in | An item in the ••• More menu after Save as Working Corpus…, titled by what it will do. On a keyword list the Sort menu also offers **Closest to a Question…**. No sixth control in the actions bar | The same | A titled toolbar button, **Search Within Results**, after Save as Working Corpus…, with `.labelStyle(.titleAndIcon)`. No shortcut |
| Base row | Takes the mode picker's place in the top inset, so the inset does not grow | The same, with pointer help | A row where the corpus banner sits. The segmented picker gives way to a plain label naming the engine the field now uses, since a disabled picker explains nothing |
| Filters while a base is held | The filter glyph does not light for the base | The same | The filter summary and the token caption do not mention the base |
| Readings and Facets | Off for a rank-by-meaning list, as in Meaning mode today; on for words in matches | The same | Readings the same. Facets open either way, counted over the list |
| Windows | One | Each Stage Manager scene holds its own base | One Search window |

Accessibility, on all three:

- The base row is one element, "Searching within 100 closest matches to …", with a child button "Stop searching within these results".
- Starting a layer, leaving it and finishing a ranking are announced to VoiceOver.
- A row with a score gains an accessibility value such as "Semantic match 71 percent". Today the row's label is the header alone (`SearchView.swift:2111`), so the chip is silent.
- At accessibility text sizes the base row wraps to three lines and the close button keeps a 44 pt target.
- A Meaning base uses the `SemanticGlyph` family, as the Meaning strip and the model offer already do.

### Model and service changes

Nothing is persisted. No `@Model` gains a field.

1. **`SemanticQuerySearcher.search(_:within:limit:)`**, new, in `FRUSExplorer/Semantic/SemanticQuerySearcher.swift`.
   - Embed and quantise as today, then resolve each key to a corpus row. A key with no row is counted as having no vector.
   - Map each volume's shard once and call the kernel's `rerank` over the rows. There is no candidate stage, so every member with a shard is scored exactly, with the kernel's own tie-break. `rerank` drops what it cannot score, so the searcher counts those members before the call.
   - Members whose shard is absent are counted, and fetches are requested for a bounded number of volumes, those with most members first. The bound is a new named constant. `fetchQueueDepth` is a depth of 100 in candidate order (`SemanticQuerySearcher.swift:123-126`, `:182`), not a count of volumes.
   - Edition twins are not folded: the set is the reader's.
   - An empty set returns nothing without loading the encoder.
2. **`SemanticSearchBackend`**.
   - `run` sends a non-nil gate to the new method and takes the gate out of the parameters before `filterKeySet`, so the set is not scanned a second time. Other filters still apply after ranking.
   - `rerank(query:base:parameters:)` is the same path with the limit set to the base's size. It composes rows from the base's own rows, which keeps their keyword snippets.
   - `Disclosure` gains `rankedWithin` and `withoutVector`, with defaults so existing callers compile.
   - `SemanticUnscoredCopy` gains a third sentence, for members unranked for want of a match file, naming Download Missing Vectors. The existing pair is shared with the keyword fallback (`FRUSExplorer/Search/SemanticSearchFallbackView.swift:210`, `:264`) and stays as it is.
   - The file keeps the spellings `bm25Score: -hit.score` and `semanticScore: hit.score`, which a source scan requires (`FRUSExplorerTests/HybridSearchModeTests.swift:287-289`).
3. **`ExecutedSearchRoute`**, an enum on `ResultSetScope` in place of the `isMeaningSearch` flag: keywords, meaning, words in matches, ranked by meaning.
   - Both view models set it where they set `userTagCountScope`, when a run completes, not where `lastRunWasSemantic` is written.
   - It answers the questions the result-describing comparisons ask today: is there a keyword match, is the order by meaning, where do facets count, what does the header say.
   - Both hosts pass `ResultSetScope` the ceiling the run was fetched at (`lastFetchLimit`), where they pass a constant today. The base row's "first 1,000 of 35,275" wording depends on that value.
4. **`FRUSExplorer/Search/SearchLayering.swift`**, new, shared by both view models so the twins cannot drift.
   - `PinnedResultBase`, a value type. It holds the route; the query or, for a browse, the filter's name; the shown rows in order; the score by key for a Meaning base; and the counts left out (checklist-hidden, not downloaded).
   - It also holds everything a restore must put back: the executed parameters, `totalMatchCount`, `lastFetchLimit`, `lastRenderedExpression`, `semanticDisclosure`, `beyondLibraryHits`, `userTagCountScope` and the trail anchor.
   - It is built from an array of rows, so #1576's selection can feed it later.
   - `LayeredResultComposer`, pure functions: put keyword rows in base order with base scores; merge ranked rows with an unranked tail in base order; compose a pin into a parameter value's gate.
5. **`DocumentScopeGate.combine`** takes the pin as a third set, with the same empty-set contract. On lanes 1 to 5 only words in matches sends a pin through SQL, so that gate never exceeds 100 keys, one `IN` group. Its total is the row count, so no second count statement runs.
6. **View models.**
   - iPhone and iPad: the field-clearing handler (`SearchView.swift:502-512`) must restore the base's rows, not empty the list, while a base is held.
   - Mac: pinning must clear `submittedQuery` as well as the field, or the engine change will run the base's text through the other engine at once (`MacSearchViewModel.swift:187`).
   - Mac: the pin joins the gate where the value a search runs with is built (`MacSearchViewModel.swift:216`, `:225`, `:999`, `:1139`), through the one composer function. It never enters the stored `parameters`. So it needs no `filterVM`, and the filter summary and token caption, which read `parameters` (`SearchSheet.swift:1156`, `:1161`), stay true with no edit.
   - Both: leaving the base puts back the state in item 4 and bumps `executedSearchVersion`. Facets, the concordance and the tag counts are keyed on that version (`SearchView.swift:613-644`), so rows restored without it would sit under the layer's figures.
   - Both: layer runs inside a held base do not re-anchor the checklist, so marks made on the base survive adding and removing a layer. The guard differs by platform. iPhone and iPad re-anchor on every completed search; the Mac re-anchors when the query text changes, so a layer's second query would clear the marks there by default.
7. **The record**, in fields that already exist.
   - A Meaning search inside a set signs as `route=semantic;engine=on-device;docs=<count>/<digest>`; with no set it stays byte-identical to today's constant.
   - A keyword layer signs with the existing keyword grammar, whose `docs=` part already describes the gate.
   - Both add a `base=` key holding the base's route and its query, percent-encoded, and `describe` turns it into a phrase. So the Markdown, the plain text and a collection export's appendix name the base. This is chosen over naming it in `renderedExpression` alone, which would record the base in the CSV and nowhere a reader of an exported collection looks. `renderedExpression` repeats it for the CSV.
   - The pin sets the trail anchor aside and leaving restores it. Without that, a layer typed with the base's own text, or lane 7's Swap, would overwrite the base's row.
   - A layer's row records the listed set's size as its match count. Left empty, with the limit set to the set's size, a complete 212-row ranking would print as "at least 212".
   - `Reading.appliedCorpusId` has no slot for a pin (`SearchHistoryWriter.swift:113`), so the appendix's "inside …" phrase and its coverage block, both joined on a corpus id, say nothing about a base. The `base=` phrase is what names it. A browse writes no trail row of its own (`:163`), so for a browse base that phrase is the only record.
   - A working corpus captured inside a base names both layers in `sourceDescription`.
   - Save this search is disabled while a base is held, with help text pointing to Save as Working Corpus. Today a saved search stores the gate, recall drops it, and a smart collection honours it (`FRUSExplorer/Collections/CollectionContentResolver.swift:543-546`), so one saved layered search would give two result sets.

### Left out

- Same-engine layers and deeper stacks (decision 5).
- Saved layered searches (decision 4), and replaying a layered row from History: a re-run hands over the layer's text alone.
- A keyboard shortcut and Find-menu commands, which wait for the Search command channel that #1576 also wants.
- Ranking inside a volume scope. The scoped prompt says "search within the selected volumes" (`FRUSExplorer/Search/SearchModels.swift:96-98`) while the code filters afterwards; changing it would break the facet promise, so it deserves its own issue.
- A faster SQL shape for a small gate, unless a phone timing of a gated keyword search shows a need. Lane 1's Meaning timing cannot show it: the keyword layer's cost is the joined ranking statement, which the Meaning path never runs. Lane 1 therefore logs both.

## 4. Lanes

Each is one pull request based on `v2`, landed through the serial merge queue in this order, none stacked on another. Sizes: small is about a day of agent work with review, medium two to three days, large about a week. A lane that adds a source file runs `xcodegen generate` and restores the schemes.

| # | Lane | Size | Needs | Shared kit code |
| --- | --- | --- | --- | --- |
| 1 | A Meaning search ranks inside a document set | Medium | Decisions 1 and 7 | None, unless decision 7 puts the scoring step in `SemanticVectorsKit` |
| 2 | One frozen description of the list on screen | Medium | — | None |
| 3 | A UI-test seam for Meaning results | Small to medium | 1 | None |
| 4 | Search within results on iPhone and iPad | Large | 1, 2, 3, decision 6 | None |
| 5 | Search within results on the Mac | Medium | 4 | None |
| 6 | The whole keyword match as the base | Medium | 5, decision 2 | `FRUSCoreKit/Search/` |
| 7 | Swap search order, and polish | Small | 5 | None |

Lanes 1 to 5 close #1577. Lanes 1 and 2 can be developed side by side.

**Lane 1. A Meaning search ranks inside a document set.**

- *Scope.* Items 1 and 2 of the model changes, less `rerank`; the gated signature and its `describe` phrase; the strip, empty-state and scoped-prompt sentences ("inside the N documents you are searching within" in place of "across the whole series"); the Download Missing Vectors sentence.
- *Logging.* A `Logger` line timing encode, key resolution, shard mapping and scoring, and a second timing the statement of a gated keyword search.
- *What it ships.* Both directions of the issue work at once through the existing route, on both platforms, with no new control: save a result list as a working corpus, apply it, search with the other engine.
- *Acceptance.* A new suite on a synthetic index, corpus and shards written with the kit's own writers, so it cannot skip. Choose a set the corpus-wide search does not return. The in-set search returns only members, in the order of a brute-force cosine computed in the test, and the no-vector and no-shard counts equal the planted ones. The control is run once on the pre-change code and quoted: the same gate through the backend yields no rows and `filteredOut == 100`. The pull request quotes the executed test count.

**Lane 2. One frozen description of the list on screen.**

- *Scope.* `ExecutedSearchRoute`, set on completion; the comparisons that describe results move off the live mode on both hosts, and those that concern the input stay; both hosts pass the run's own ceiling; the Mac's truncation rule moves into `ResultSetScope`, false for a Meaning run; the five defects marked "Lane 2" in section 2. No new feature.
- *Scans it must move.* `FacetMeaningModeTests.swift:77-96` requires `.meaning` inside each host's `facetController.load(` call, so it is rewritten in this lane to require the frozen route. Three exact `if … searchMode == …` headers matched by `SearchTipsWiringTests.swift:215`, `:326` and `:393` concern the input and are left alone.
- *Acceptance.* `ResultSetScopeTests`, one test per route for each header and capture sentence, and one for a complete browse above 1,000 rows. A view-model test for the mode-flip edge that fails on the pre-change code. Source scans, each matched on the call: both hosts pass the frozen route and the run's ceiling, and neither tests the live mode to describe results.

**Lane 3. A UI-test seam for Meaning results.**

- *Scope.* A DEBUG launch flag that builds the searcher with `embedOverride` and adopts a synthetic shard for the seeded fixture volume. It drives the real searcher and backend. No UI test reaches a Meaning result today, since no simulator has the model.
- *What the bundled artifacts require.* The app's searcher is built on the bundled index and sign bits (`FRUSExplorer/App/FRUSExplorerApp.swift:1768-1780`), and a plain Meaning search picks its candidates from those bits.
  - The stand-in embedding is therefore built from the bundled sign bits of a fixture document. One taken from the synthetic shard would almost never land in the fixture volume.
  - The synthetic shard carries the bundled provenance digest and the fixture volume's bundled row count, both of which `adoptShard` checks (`FRUSExplorer/Semantic/SemanticShardStore.swift:325-330`).
  - A plain Meaning search then lists the fixture documents that fall in the 800-candidate pool. The lane states how many; lane 4's tests need at least three, some with a chosen word and some without.
- *Acceptance.* A UI test in which a Meaning search inside a working corpus, saved and applied through the screen, lists every member that has a vector, each with a chip. Run once against the tree before lane 1, the same test lists fewer or none. The lane quotes both counts.

**Lane 4. Search within results on iPhone and iPad.**

- *Scope.* `SearchLayering.swift`; `rerank`; the three-way gate; the view-model and view changes; the record (item 7); the `Docs/EditableContent` re-points.
- *The More menu's help string.* It lists that menu's contents, so it is re-keyed to `search.moreActions.help.v3`. `.v2` is the key in use (`SearchView.swift:1211`). The test that pins it (`FRUSExplorerTests/SearchTipsWiringTests.swift:375-376`) and the block that cites it (`Docs/EditableContent/07-Search-and-Browse.md:1120`) move in the same lane.
- *Acceptance.* The unit and UI tests in section 7. `SearchActionsBarFitTests` passes unchanged.

**Lane 5. Search within results on the Mac.**

- *Scope.* The pin on `MacSearchViewModel`; the composer called at the four sites that build the value a search runs with; the trigger and empty-query changes; the checklist guard for a layer's second query; the toolbar button, base row and engine label.
- *Acceptance.* Source scans matched on the call: the host builds the pin from `displayedResults`; the four sites call the composer and nothing writes a pin into `parameters`; `applyParameters` clears the pin; the filter summary and the token caption are still given `parameters`.
- *Check by eye, listed in the pull request.* The toolbar at the window's 640 pt minimum width. Each direction end to end. The base row beside a corpus banner. A hand-off from History while a base is held. A filter edit during a layer. The filter summary and token caption while a base is held and Advanced… has never been opened. Checklist marks across a layer. VoiceOver on the base row.

**Lane 6. The whole keyword match as the base.**

- *Scope, kit.* `SearchService.matchKeys(parameters:)`, every key the query and filters match, as a plain `SELECT` over the existing match and filter builders, with no temp table and no schema change. It goes in the kit file because those builders are private to it.
- *Scope, app.* Where the base was cut at the load ceiling, the Meaning layer scores every key of the whole match exactly and shows the closest rows up to the ceiling, under "Closest 1,000 of 35,275 results". There is one scoring path and no threshold.
  - The rows to show are fetched by running the existing keyword search again with the chosen keys as its gate, which returns them with their keyword snippets (`FRUSCoreKit/Search/SearchService.swift:152-200`). `semanticResultRows` would return them with none.
  - That gate is the ceiling's size at most: 3 `IN` groups on a phone, 16 on the Mac. On the synthetic index the statement took about 0.4 s at 1,000 keys and 0.9 s at 7,500 for a common word.
  - Offered for a Meaning layer only. A keyword layer inside tens of thousands of keys would take seconds (6.9 s at 100,000 keys, synthetic) and above 32,766 would break rule 8.
  - Whether a very large match (195,519 rows for `government`) needs an upper bound is decided from a timing on the real index, which the lane takes.
- *Acceptance.* Kit tests in `FRUSExplorerTests/FRUSCoreKit/`, on a synthetic index with no enabling condition: the key set's size equals `searchCount` across the three match shapes, the filters and `=exact`; it equals `search`'s keys below the cap; it answers the same through the read-only open. `swift build --target FRUSCoreKit` and `swift test` pass, with counts quoted. An app test on a synthetic index and shards: for a match larger than the load ceiling, the rows shown are the closest by a brute-force cosine computed in the test, in that order, each with its keyword snippet, and a document outside the match never appears.

**Lane 7. Swap search order, and polish.**

- *Scope.* A **Swap** control on the base row that turns "7 of 100" into "all 212 with the words, closest first" without retyping, and any second way in that lane 4 left out. A Swap sets the trail anchor aside as a pin does.
- *Acceptance.* A view-model test: after Swap the two queries have changed places, the list equals the one built by hand in the other order, and the trail rows written before the Swap are unchanged.

**Docs.** Lanes 1, 4, 5 and 6 each end with a docs pass.

- Both user manuals. They are being brought up to date in a separate pull request and will carry an "AI Generated" notice directly under each title until you have reviewed them, which will be at least two weeks. A lane that changes behaviour the manuals describe edits them and leaves the notice in place.
- Search Tips on both hosts; the Research Guide where it states what a working corpus does in Meaning mode; `Planning/DEVELOPMENT-PLAN.md`; TestFlight notes at the next build bump.

**Order against #1576.** Lanes 4 and 5 edit the More menu, the toolbar and the same help string as #1576's selection lanes. Land one issue's interface lanes before the other's; whichever lands second takes the next key suffix for the help string. Lanes 1 to 3 here can go at any time.

## 5. The web edition

**Shared code touched.**

- Lanes 1 to 5 and 7 edit no shared file on the recommended defaults. They call kit declarations as they stand: the kernel's `rerank`, `SemanticVectorIndex.row(documentID:volumeID:)`, `SemanticShard.cosine`, `SearchResult`'s initialiser and `SearchService.search` with a gate. Lane 1's tests also call the kit's two artifact writers.
- Lane 6 edits `FRUSCoreKit/Search/SearchService.swift` and `FRUSCoreKit/Search/IndexingPipeline.swift`, and adds a suite under `FRUSExplorerTests/FRUSCoreKit/`.

**What the four coordination rules require.**

- Lanes 1 to 5 and 7: nothing beyond the normal unit run. `FRUSCoreKitBoundaryTests` runs there regardless.
- Lane 6: the method takes and returns Foundation values and names no app type (rules 1 and 2); it changes kit behaviour in the kit (rule 3); its tests sit outside any `#if !SWIFT_PACKAGE` branch and use no app type; `swift test` is run as well as the unit target (rule 4). It need not be `public` for the app's sake.

**Where the app's goal and the web edition pull apart.** No lane gains anything from breaking one of the four rules. The choices below are of another kind: things the arrangement leaves to the app ("App work goes ahead; the web side follows") that still cost the web side something. Each is shown within the arrangement and with it set aside.

| Choice | Within the arrangement | With it set aside |
| --- | --- | --- |
| **Where the set-ranking step lives** (lane 1; decision 7) | In the app's `SemanticQuerySearcher`, which is not shared code. *App:* no kit edit; lanes 1 to 5 need only the unit run. *Web:* its Meaning search is planned on the kit's funnel (the web repository's `docs/SPEC.md:405`), so it cannot rank inside a set until a web-authored pull request moves the step into the kit or repeats it. Until then its results inside a working corpus differ from the app's | Shape the code for the web edition, which the arrangement says is not asked: put the pure step (keys to rows to exact scores, with the not-ranked counts) in `SemanticVectorsKit` now, the shards passed in. *App:* a kit edit in lane 1, a kit test with no skip, `swift test`, and a signature free of app types (the shard store is the app's). *Web:* it gets the step, its tie-break and its accounting by construction. No rule is broken either way |
| **What Meaning mode does with a document set** (lane 1; decision 1) | Change it: rank inside the set. *App:* the corpus footer becomes true in Meaning mode. *Web:* its specification's sentence, Meaning mode "intersects and discloses filters" (`docs/SPEC.md:349`), goes out of date for document sets, and its phase 4 needs the step above to match. Nothing is compiled against the sentence | Hold the app back to match that sentence (decision 1, "No"), which the arrangement does not ask. *App:* the footer stays untrue in Meaning mode and lane 1 serves the pin alone. *Web:* nothing to follow |
| **How lane 6's kit suite is written, and run** | On a synthetic index with no enabling condition, and `swift test` is run. *App:* about two minutes. *Web:* the suite runs on Linux at its next pin move and passes | The rules do not forbid a suite that skips when a real index is absent, and rule 4 could be skipped. *App:* a little less fixture code; two minutes saved. *Web:* its CI fails on any skip outside its allow-list (the pin-move checklist in its `docs/COORDINATION.md`), and a package-only failure surfaces at that pin move, for a web session to repair |
| **How large a gate may go through SQL** (rule 8; lane 6; decision 5's alternative) | Never above 32,766 keys; the recommended path stays at 7,500 or fewer. *App:* lane 6 ranks in memory and fetches only the rows it shows. *Web:* nothing | Send a larger gate. No rule forbids it, and the system SQLite on the Mac this was written on is compiled for 500,000 bound values. *App:* simpler fetching of a very large set. *Web:* the same kit call may fail on its Linux image, whose SQLite is the distribution's package and whose limit was not read. iOS's was not read either |
| **Saving a layered search** (decision 4) | Not saved, the default: no shared code, no export change. *Web:* nothing | Not a rule set aside but a kit edit: an optional field in `SearchParameters` (`FRUSCoreKit/Search/SearchParameters.swift:86`). *App:* `swift test`, and the two field-pin tests move. *Web:* the type its search takes, and the blob its planned importer decodes, gain a field it ignores until it follows, so a saved layered search runs there as plain keywords. The `SavedSearch` column instead costs the app a CloudKit deploy and changes the shape `formatVersion` 7 is reserved for |

Where there is no choice:

- Lane 6's method could not live outside the kit in any case, since the builders it needs are private to the kit file.
- Lanes 2, 3, 4, 5 and 7 are the app's own files and touch nothing the web edition compiles.
- Nothing moves the index version, the FTS generation or the export the web server checks.

Two things the web side will follow in its own time, neither asked of app sessions:

- None of its 482 parity queries sets a gate, so its check 3 protects none of this. Only this repository's tests do.
- Its plan has reserved JSON `formatVersion` 7 for saved searches and working corpora. This design leaves the export alone.

## 6. Release constraints

| Constraint | Needed? | Why |
| --- | --- | --- |
| CloudKit schema deploy | No | No `@Model` and no stored property is added. The pin is view-model memory. The trail and the corpus capture write to `scopeSignature`, `renderedExpression` and `sourceDescription`, which exist. Only decision 4's `SavedSearch` column would need one |
| Index version | No, stays 65 | Nothing changes parse output or what indexing stores. Lane 6 adds a query, not a table |
| FTS schema generation | No, stays 4 | No FTS table changes |
| JSON export `formatVersion` | No, stays 6 | No model is added. Trail rows already export the two string fields, so the new signatures travel in the old shape |
| Export Research Database… | No | No index table or column is added, so the strip list and the web's schema mirror stand |
| Re-index | No | Follows from the index version |
| `FRUS-API.openapi.yaml` | No | Its `/search` describes no document gate today and this adds none |

## 7. Tests

Every run quotes a test count. A skipped suite is not a pass, and `-only-testing` names the type.

**Unit, in `FRUSExplorerTests` on an iOS simulator.**

| Suite | What it pins |
| --- | --- |
| New in-set ranking suite (lane 1) | Section 4's acceptance, on synthetic artifacts. Also: a member ranked beyond 800 corpus-wide still appears; twins are not folded; no-vector and no-shard are counted apart; an empty set never loads the encoder |
| `SemanticQuerySearcherTests`, additions | The same against real shards. It runs only where the shard files exist, so the pull request says where it ran and the count |
| `HybridSearchModeTests`, additions | The backend: a gated run returns members only; other filters still apply after ranking; `bm25Score` is the negated score; keyword snippets survive `rerank`. Its existing scan of the two score spellings still passes |
| `ResultSetScopeTests` | One test per route for each header, base-row and capture sentence. A complete browse above 1,000 rows reads as complete |
| Signature and appendix tests | Round trips; `describe` for both forms, each naming the base from `base=`; the gated Meaning signature starts with `route=semantic`; a Meaning layer's zero is not counted as a term's absence; a complete ranking prints an exact count, not a floor |
| `DocumentScopeGate` tests | The three-way combine, one fixture per `nil` and per empty conjunct |
| `LayeredResultComposer` tests | Base order kept, nothing dropped or duplicated, the tail in base order. Tie fixtures are named so that id order alone does not pass. The gate composer leaves a value with no pin unchanged |
| View-model tests (iPhone and iPad model) | Pin and leave restore the rows and every figure in item 4 with no search call, and bump the version. Emptying the field while a base is held keeps the base rows. One test for each thing that leaves the base, and one that Clear Filters does not. Save is disabled. Marks survive pin, layer and leave. A layer typed with the base's own text does not overwrite the base's trail row |
| Source scans for the Mac | Listed under lanes 2 and 5, each matched on the call, not a window of text |
| Kit suite (lane 6) | Compiled twice, by Xcode and by `swift test`, with no enabling condition |

`EditableContentKeyTests`, `UnconstructedViewAuditTests`, `ToolbarAccessibilityAuditTests` and the license-header audit all bear on the new files and moved lines.

**UI, in `FRUSExplorerUITests`.** Controls are found by identifier. Each suite sets `FRUS_UI_TEST_DISABLE_ANIMATIONS=1`, closes what it opens in `tearDown`, and on iOS 27 runs with `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 300`.

| Suite | Devices | Why those |
| --- | --- | --- |
| `SearchWithinResultsTests`: each direction end to end through lane 3's seam; the base row replaces the picker; closing restores rows and picker; the no-hits state; a hand-off leaves the base | iPhone 17 **and** iPad Pro 13-inch (M5). It skips on neither | The view is shared, but the iPad adds the facet inspector and the regular-width layout. Run against the tree before lane 4 first, to show each test can fail |
| Base-row fit: frames of the base row and actions bar at five text sizes, with each accessibility size proving it took effect | iPhone 17 (402 pt) **and** iPhone SE 3rd generation (375 pt, iOS 27). It skips on iPad | The row replaces the picker in an inset that already ran off both edges once (#1307). At iPad width it fits either way |
| `SearchActionsBarFitTests`, unchanged | The same two iPhones | It must still measure five controls |

**Mac.** No machine test. Lanes 1, 2, 5 and 6 each carry a check by eye in the pull request.

## 8. Decisions for the owner

| # | Decision | Recommended default | The alternative, and its cost |
| --- | --- | --- | --- |
| 1 | In Meaning mode, should an applied working corpus or project History scope be ranked inside, where today it filters the corpus-wide top 100? | Yes. Other filters stay as they are | No: the new ranking is used by the pin alone and lane 1 shrinks. A corpus's own footer, "Applying one searches only inside it", stays untrue in Meaning mode, where a small corpus can return few rows or none |
| 2 | What a keyword base holds | The loaded rows now, with the cut stated; then lane 6 for the whole match | Hold the feature until lane 6: no interim release where iPhone and Mac rank different slices of a large match. Or never build lane 6: no kit work, and large matches stay cut by BM25 |
| 3 | What a Meaning layer returns | The whole pinned set, closest first | The 100 closest only: a shorter list, and documents the keyword search found disappear |
| 4 | Whether a layered search can be saved | No. The session only, with Save this search disabled while a base is held | An optional field inside `SearchParameters`: no deploy, but that type is shared kit code, so `swift test` applies; three smart-collection resolvers and older builds would run it as plain keywords; and the two tests that pin the type's fields move (`FRUSExplorerTests/QueryInspectionTests.swift:1282-1284`, the 26-field count, and `:1330`, the unread set). Or a `SavedSearch` column: the deploy gate, and no archive until Production is read |
| 5 | Which pairs | The other engine only, with the base row in place of the picker | Keep the picker so either engine runs inside any base: four kinds of list to word, one more row on iPhone, and keyword gates of up to 7,500 keys (about 0.9 s a statement on a common word, synthetic) |
| 6 | Whether a filter-only browse can be a base | Yes, for a Meaning layer. Its rows keep the header line they have, and the phone timing below covers a 7,500-row browse before lane 4 starts | Keyword-search bases only: one condition and a disabled item with help text. A subject or person browse cannot then be ranked by a question, and the timing need not cover 7,500 rows |
| 7 | Where the set-ranking step lives | In the app's searcher, as the coordination arrangement leaves it | In `SemanticVectorsKit` now (section 5): a kit edit and `swift test` in lane 1, and the web edition's Meaning search can rank inside a set without a move of its own |

Two checks are also yours, neither a decision:

- **Timings on an iPhone with the search model downloaded**, after lane 1, read from its two log lines. Lane 4 should not start until they are in hand.
  - A Meaning search inside a working corpus of about 1,000 documents.
  - The same inside a 7,500-row browse saved as a corpus, if decision 6 is yes.
  - A common word in Keywords mode inside a 100-document corpus. This is the keyword layer's statement.
- **The Mac checks by eye** for lanes 1, 2, 5 and 6.

## 9. Risks

- **Phone latency is unmeasured.** The recorded figures are from an M1 Max and a command-line encoder, and the rerank figure covers rows already located with their shards mapped. Scoring is likely to be the small part. Encoding the question, resolving keys to rows and first-touch mapping of many shards are the unknowns, and a 7,500-row browse base is the largest case.
- **Missing match files make a ranking partial.** Libraries downloaded before the vectors shipped are the likely case. The count is disclosed, fetches honour Download With Volumes, and a new sentence names Download Missing Vectors. The shared copy that names Download Vectors for Every Volume is left alone.
- **The chip implies precision.** With no score floor, the last rows of a 1,000-row ranking still carry a percentage. Quality inside a set is unmeasured (the 0.851 recall figure describes the corpus-wide search only), and pre-1900 quality is unmeasured anywhere. The copy keeps "experimental".
- **The two orders give different lists.** Weak header copy will make that look like a fault. Lane 7's Swap is the remedy.
- **A held base is state the reader can forget.** The base row and the header count are the only guard. That is why every hand-off leaves it, and why no other surface may name it as something else.
- **Two rules sit side by side in Meaning mode**: a document set is ranked inside, other filters narrow afterwards. The strip must say which applied.
- **The Mac has no executed tests.** Shared rules live in `PinnedResultBase`, `LayeredResultComposer`, `DocumentScopeGate` and `ResultSetScope`; the Mac's wiring has source scans and a list checked by eye. Its checklist anchor and its readers of the gate are where it differs from the phone's model.
- **Four state traps.** Two will empty the list at the moment a layer starts unless gated: the iOS field-clearing handler, and the Mac's engine-in-the-trigger with its empty-query clear. A restore that puts back the rows without their figures and the version leaves the layer's numbers over the base's rows. And the trail anchor, left in place, lets a layer overwrite the base's row.
- **A keyword layer on a cold cache.** Any gate turns on the joined form of the ranking statement, one row lookup for each row the words match. The file's own figure for a common word's first page is 10.74 s with the joins against 0.376 s without (`FRUSCoreKit/Search/IndexingPipeline.swift:3321-3322`), and it warns that such figures depend on the page cache. Every filtered search pays this today; a common word inside 100 documents will too.
- **Mixed builds share one trail.** An older build prints a Meaning layer as a plain Meaning search, and a keyword layer as a keyword search in "100 documents". It ignores the `base=` key. Both lines are true and neither names the base.
- **Scanned files and ranged blocks move.**
  - Twenty unit-test files name `SearchView.swift` and twenty-one name `SearchSheet.swift`, so the Mac file is under machine scans though the Mac has no executed tests. Those that read a file as text can fail on an edit that changes no behaviour.
  - `Docs/EditableContent` cites `SearchView.swift` in 8 ranged blocks, `SearchSheet.swift` in 8, `ResultSetScope.swift` in 3, and `SearchModels.swift` with `SemanticMeaningModeViews.swift` in 41.
  - Both search view bodies are near the type-checker's budget, so new rows go in extracted builders.
- **The seam is new DEBUG surface.** It must drive the real searcher, not stand in for it, and its synthetic shard must never reach a release build. It also leans on the bundled artifacts: if the stand-in vector or the shard disagrees with the bundled bits, digest or row count, the test lists nothing for a reason that has nothing to do with the feature.
- **Lane 6's enumeration runs on the index actor.** A long one queues facets, tag writes and indexing behind it, and nothing cancels it. The scoring arithmetic is small by the spike's figure. The enumeration, 195,000 key lookups and the shard mapping are not timed on the real 6.3 GB index.
- **The bind limit belongs to the host's SQLite.** Rule 8 uses the 32,766 the kit's comment gives. Only the Mac's system library was read (500,000), which is why a 100,000-key synthetic run worked there.
- **Not traced:** the Mac facet panel's cost when it counts over 7,500 result keys where it counts over 100 today.
