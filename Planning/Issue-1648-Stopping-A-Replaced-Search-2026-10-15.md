# #1648's second step: stopping the SQL of a search a later one replaced (assessment, 2026-10-15)

**Status: decided.** The owner's word of 2026-10-15 (the plan of record's decision 43): filed as #1680, placed in Track A before A5 (A2b), and built by the session that wrote this memo, as its own pull request, to §4's recommendation. The assessment below is as it was written before the decision. Base `v2` @ `470f818c` (A2, #1679, merged). #1648's first step, A2's `SearchRunLedger`, keeps a replaced run's rows off the screen; this memo asks whether the kit should also stop that run's statements, so that the search that replaced it does not wait behind them.

## 0. In short

- **A newer search waits for all of the one it replaced**: the replaced search's ranking statement, its count and, on the Mac, its snippet pass. Measured on build 49's full index (553 volumes, 316,768 documents), a light search sent 50 ms into a heavy one came back **0.5 to 0.9 s late at iPhone and iPad's limit of 1,000 rows and 1.0 to 4.1 s late at the Mac's 7,500**, with the pages warm; **about 8 s late** (8.1 s and 10.1 s in all) behind a filtered common word whose pages were cold; and **134 s late** behind an exact-word search for a common word (`=government`).
- **The Mac already cancels a replaced run, and it changes nothing**: the window's `.task(id:)` cancels it, nothing under it checks, and 48 of 48 cancelled runs returned their rows.
- **The SQL runs on the pipeline's own connection** (`auxDb`), not FTS5Store's. No design here touches `FTS5Store/`.
- **Recommended: design (b)** (§3): a progress handler on that connection that stops a statement only while its task is cancelled and only where the two search methods have armed it, with a task-local value; plus (a)'s cancellation checks where the work is Swift, at the statement boundaries and in `SearchService`'s snippet loop; plus iPhone and iPad cancelling the run they replace. On the full index it stopped every statement shape tried within **0.3 to 1.5 ms** (2 to 13 ms for the exact-word one), its cost was below the runs' noise, and statements it does not arm ran to their end in a cancelled task and outside any task.
- **Its own pull request**: no index bump, no CloudKit change, no public signature change. For the web edition it compiles on Linux with no new import, and changes behaviour only inside a cancelled task (§5).
- **Three findings on the way**, for the plan's unfiled findings, now its §6g (§6): an exact-word search for a common word holds the pipeline for about two minutes (rows 59 s, then the count 58 s); on the Mac most of every search's time is the snippet pass, not SQL; and the default scope's user-content union costs a common word's count about 0.3 s where the corpus alone costs a few milliseconds.

## 1. What a replaced search does today

Read at `470f818c`.

- **iPhone and iPad.** `SearchViewModel.search()` (`FRUSExplorer/Search/SearchViewModel.swift:1003`) starts the rows and the count together (`async let`, line 1040) and asks the ledger once both are back. It is called from ten `Task { await runSearch() }` sites in `SearchView.swift`, and nothing holds or cancels those tasks.
- **Mac.** `MacSearchViewModel.performSearch(service:)` (`FRUSExplorer/App/MacSearchViewModel.swift:1365`) runs in `.task(id: searchVM.searchTrigger)` (`SearchSheet.swift:538`), which SwiftUI cancels when the trigger moves. The trigger carries `parametersVersion` (line 203), which every scope toggle and filter setter bumps, so **each click on a filter replaces the search under way**.
- **`SearchService`** (`FRUSCoreKit/Search/SearchService.swift`) is an actor. `search(parameters:limit:offset:)` awaits `pipeline.searchDocuments`, then maps every row to a snippet (`makeContextSnippet`, radius 1,000) on its own executor; `searchCount` awaits `pipeline.searchDocumentsCount`.
- **`IndexingPipeline`** is an actor. `searchDocuments` (`IndexingPipeline.swift:3481`) and `searchDocumentsCount` (`:3656`) are synchronous: prepare, step to the end, finalize, through `auxPrepare` and `auxStep` on `auxDb`, the pipeline's one connection (opened `SQLITE_OPEN_FULLMUTEX` at `:2160`). The pipeline's `nonisolated` reads (`isVolumeIndexed`, `allIndexedVolumeIds`, `volumesWithUnfinishedStore` and others) use the same connection from other threads, and so do indexing's writes, from the actor.
- **So a newer search queues at two actors**: on the pipeline behind the replaced search's ranking statement and its count, and on `SearchService` behind its snippet pass. The tree has no `sqlite3_progress_handler`, `sqlite3_interrupt` or busy handler anywhere (`git grep`).

## 2. Measured

**Set-up.** The pinned iPhone 17e simulator's library (`4E79C806`, built 2026-10-08 by build 49's code at index version 65; the code is at 69), 2.87 GB, cloned with `cp -c` into scratch and opened read-only and immutable through the kit's own `FTS5Store(readingDatabaseAt:)` and `IndexingPipeline(readingIndexAt:…)`, the web edition's open. A throwaway package test (`swift test -c release -Xswiftc -enable-testing`, not committed) drove `SearchService` the way the view models do: rows and count at once, then the expression. The M5 MacBook (10 cores, 32 GB), macOS 27.0, Swift 6.4, the system SQLite (3.54.0), load average 3 to 7. **"First"** is the first run in a process on a fresh clone, which no process had read; it ran 1.1 to 8 times the warm figure, as a read from disk would, though nothing here proves the page cache was empty. **"Warm"** is the median of the next three. Not measured on a phone (§7).

**Each search alone**, rows and total both back:

| Search | Matches | 1,000 rows: first / warm | 7,500 rows: first / warm |
|---|---|---|---|
| `government` | 195,588 | 1.00 / 0.64 s | 2.23 / 1.18 s |
| `government`, dates 1945–1963 | 58,472 | 7.27 / 0.97 s | 7.95 / 1.49 s |
| `government`, the 66 volumes of 1969–76 | 10,759 | 6.87 / 0.84 s | 8.67 / 2.34 s |
| `"united states"` | 145,996 | 0.97 / 0.53 s | 2.17 / 0.96 s |
| `gov*` | 207,740 | 1.32 / 0.97 s | 5.22 / 4.22 s |
| `=government` | 184,565 | 131 / 117 s | not run |
| `khrushchev` | 3,507 | 0.28 / 0.15 s | 1.63 / 1.21 s |
| `government berlin` | 10,771 | 0.38 / 0.15 s | 1.94 / 1.06 s |

**The wait.** A heavy search started, a light one sent 50 ms later, and the light one's time taken from its own start; three runs each, warm unless marked:

| Limit | Behind | Light alone | Light behind the heavy one | Wait |
|---|---|---|---|---|
| 1,000 | `government` | 0.15 s | 0.63–0.73 s | 0.54–0.56 s |
| 1,000 | dates 1945–1963 | 0.15 s | 0.98–1.12 s | 0.90–0.92 s |
| 1,000 | the 1969–76 volumes | 0.15 s | 0.90–1.11 s | 0.80–0.82 s |
| 1,000 | `gov*` | 0.15 s | 1.01–1.06 s | 0.87–0.89 s |
| 7,500 | `government` | 1.08–1.19 s | 2.10–2.30 s | 1.02–1.07 s |
| 7,500 | dates 1945–1963 | 1.10–1.21 s | 2.42–2.73 s | 1.32–1.40 s |
| 7,500 | the 1969–76 volumes | 1.06–1.19 s | 3.33–3.98 s | 2.34–2.45 s |
| 7,500 | `gov*` | 1.10–1.36 s | 5.10–5.73 s | 4.09–4.10 s |
| 1,000, first | dates 1945–1963 | 0.28 s (first) | 8.13 s | about 7.9 s |
| 7,500, first | the 1969–76 volumes | 1.63 s (first) | 10.10 s | about 8.5 s |
| 1,000 | `=government` | 0.15 s | 134.2 s | about 134 s |

The light searches were `khrushchev` and `government berlin`; the "Wait" column is the median behind the heavy one less the median alone, for each. **Every light search waited for the heavy one's whole remainder**, as the two actors predict. Run again with the heavy task cancelled 50 ms in, as the Mac's `.task(id:)` cancels it, the figures were the same within the spread, and 48 of 48 cancelled heavy runs returned their rows.

**Where a heavy search's time goes** (warm, medians of three):

| Search | Ranking step (`searchDocuments`, 1 row) | Rows, 1,000 / 7,500 | Count | Snippet pass, 1,000 / 7,500 rows |
|---|---|---|---|---|
| `government` | 0.33 s | 0.34 / 0.39 s | 0.30 s | 0.11 / 0.76 s |
| dates 1945–1963 | 0.48 s | 0.50 / 0.55 s | 0.49 s | 0.10 / 0.92 s |
| the 1969–76 volumes | 0.41 s | 0.44 / 0.51 s | 0.47 s | 0.17 / 1.89 s |
| `gov*` | 0.44 s | 0.41 / 0.47 s | 0.36 s | 0.53 / 3.72 s |
| `khrushchev` | 0.006 s | 0.011 / 0.043 s | 0.004 s | 0.16 / 1.20 s (3,507 rows) |

The snippet pass is `SearchService.search` less `searchDocuments` at the same limit. Three things follow. **The first `sqlite3_step` is most of the SQL**: the ranking pass scores and sorts every match before the first row comes back, so a check between steps cannot reach it. **The count is a second statement of the same size**, because the default scope adds the user-content match, and its `UNION ALL … GROUP BY` aggregates every match: on this library, where no summary or note matches, `government`'s count took 0.29–0.44 s that way and 0.003–0.022 s with the corpus match alone (the sqlite3 shell), which is the shape the "0.011 s" in `searchDocumentsCount`'s comment fits. **On the Mac the snippet pass is most of every search**: 60 to 90% of a common word's time at 7,500 rows, and 97% of `khrushchev`'s.

## 3. The three designs

**What each stopped**, on a connection of the test's own opened as the pipeline opens its read-only one, with the pipeline's statements copied from `searchDocuments` and `searchDocumentsCount`: the stop issued a quarter of the way in (during the ranking step, so no row had come back), three runs each. Every run ended `SQLITE_INTERRUPT` with no row returned.

| Statement | Time to run | Flag read by the handler | `sqlite3_interrupt` | The task's cancellation, read by the handler |
|---|---|---|---|---|
| `government`, rows 1,000 | 0.34 s | 0.5 ms | 0.5 ms | 0.5–0.6 ms |
| `government`, rows 7,500 | 0.41 s | 0.6 ms | 0.5–0.6 ms | 0.5–0.6 ms |
| dates 1945–1963, rows 1,000 | 0.53 s | 0.7–0.8 ms | 0.6–0.7 ms | 0.7 ms |
| dates 1945–1963, count | 0.50 s | 0.6 ms | 0.6 ms | 0.6 ms |
| `gov*`, rows and count (four shapes) | 0.39–0.69 s | 0.4–1.5 ms | 0.3–0.7 ms | 0.4–0.8 ms |
| `=government`, rows 1,000, stopped 2 s in | about 59 s | — | — | 2.8–13 ms (N = 1,000), 2.1–3.4 ms (N = 100) |

**The handler's cost.** Called every 1,000 virtual-machine instructions, it ran about 10,000 times in a 0.34 s statement (once every 33 µs); at every 100, ten times as often. Neither changed any statement's time beyond the run-to-run spread (−8% to +6% either way, with no larger cost at 100). The exact-word statement's stop is slower because each row's `frus_exact_word` call is one instruction that takes about 0.3 ms, and a long body longer: a handler waits for the call it is in.

### (a) Task cancellation checked between steps

`try Task.checkCancellation()` before each statement is prepared, between the row steps, and in `SearchService`'s snippet loop.

- **Stops**: a replaced run's count when it has not yet started (its call is queued behind the rows statement, so it usually has not), the hydration steps, and the snippet pass. **Does not stop**: the ranking step, nor a count already running: 0.3 to 0.5 s warm, most of the 7 to 9 s cold, and 59 s of an exact-word search.
- **Other statements on the connection**: none affected; it reads only the caller's own task.
- **The web edition**: Swift only, nothing to compile differently.
- **Alone** it recovers most of the Mac's wait (the snippet pass) and about half of iPhone and iPad's warm wait (the count), and little of the cold or exact-word cases.

### (b) `sqlite3_progress_handler` with a per-statement flag

One handler on `auxDb`, registered where the pipeline opens it: a C function that returns 1, stopping the statement with `SQLITE_INTERRUPT`, when a task-local value is set and the current task is cancelled. `searchDocuments` and `searchDocumentsCount` bind the value around their statement with the synchronous `withValue`, and map an interrupt in a cancelled task to `CancellationError`.

- **Stops**: the ranking step and the count mid-statement, within the figures above.
- **Other statements on the connection**: a handler is per connection, so the per-statement flag is what keeps it off the rest, and it has to be per task, not per connection, because the `nonisolated` reads step on this connection from other threads. Shown on the full index: an unarmed statement in a cancelled task ran to its end (1,000 rows); the same statement armed in that task stopped in 1.7 ms; a statement on a thread outside any task ran to its end. A flag set on the pipeline instead would stop whatever other thread stepped while it was set. Indexing's writes are never armed, and no transaction on `auxDb` spans an `await` (`replaceUserTagNames` at `:2752` and `inTransaction` at `:12186` are synchronous from `BEGIN` to `COMMIT`), so no armed search can land inside one.
- **The web edition**: `sqlite3_progress_handler` is the standard C API, in the SDK's SQLite on Apple platforms and in Ubuntu's libsqlite3, which the web edition's `CSQLite` module links (CPython's `sqlite3` module calls the same function there); `@TaskLocal` and `Task.isCancelled` are the standard library's. No new import, so `FRUSCoreKitBoundaryTests` has nothing new to read.
- **Cost**: below the noise (above). It replaces any handler registered on the connection later, and there is none.

### (c) `sqlite3_interrupt` on a dedicated read connection

A second connection that only the search statements use, interrupted from a cancellation handler (`withTaskCancellationHandler`).

- **Stops**: the same as (b), as fast.
- **Other statements**: `sqlite3_interrupt` stops whatever runs on the connection when it is called, and any statement started before the connection's running count returns to zero; an interrupted write inside an explicit transaction rolls the whole transaction back (SQLite's documentation for the call). On `auxDb` it could therefore stop an indexing write or a `nonisolated` read, which is why it needs the dedicated connection. On that connection a late cancellation can still land on the next search's statement, the one that replaced it, unless each statement records its owner under a lock and the handler interrupts only its own.
- **The web edition**: a second open in `init(readingIndexAt:…)` as well, with `frus_exact_word` registered on it; and on a server, where every user's search shares the pipeline, a misdirected interrupt stops another user's search.
- **Cost**: a second connection's page cache and schema, the owner bookkeeping, and the two search methods moved onto it.

**Not a design: "the latest search wins" inside the kit.** A generation counter in `SearchService` that stopped every older statement would stop the saved-search freshness counts, Browse's subject counts, Add Documents' search and, in the web edition, other users' searches. Only the caller knows that its search was replaced, so the stop has to follow the caller's own cancellation.

## 4. Recommendation and the cut

**Build (b) with (a)'s checks, as its own pull request.** (b) is the only design that reaches the ranking step without a second connection or a lock, and the arming is what keeps it off every statement it was not written for. What it changes:

- **Kit** (`FRUSCoreKit/Search/IndexingPipeline.swift`, `SearchService.swift`; not `FTS5Store/`): the handler, registered in the initialisers' shared body for both opens; the task-local and `Task.checkCancellation()` in `searchDocuments` and `searchDocumentsCount`; `SQLITE_INTERRUPT` in a cancelled task thrown as `CancellationError`; the snippet loop checking cancellation each row. About forty lines, and the two methods' doc comments say what a cancelled caller gets.
- **iPhone and iPad** (`SearchViewModel.search()`): the run that replaces another cancels the one it replaces, by holding the run's fetch as a task, and `replaceSearchesUnderWay()` cancels it too. **The Mac needs nothing**: `.task(id:)` cancels, and `performSearch`'s catch already returns `false` on `CancellationError`. A2's ledger stays: it is what keeps a run that finishes in the moment before its stop off the screen.
- **Callers that would now throw in a cancelled task**, each to re-read in the lane: the two view models; `SavedSearchFreshnessEvaluator` (`try?`, so a cancelled count is no stamp); `SubjectIndexView` (`try?` into its count); `CollectionAddDocumentsSheet` (`try?`, an empty list); and the web edition's routes (§5). None writes a cancelled task's answer anywhere a reader would see it.
- **Tests that fail before it**: in `FRUSExplorerTests/FRUSCoreKit/` (both compilers), a search whose task is cancelled before it reaches the pipeline throws `CancellationError` (on `v2` it returns rows); a statement stopped after it starts, through a test hook between prepare and the first step like the pipeline's existing `documentBatchStoredTestHook`, with a run that registers no handler as the A/B; an unarmed read in a cancelled task keeps its answer; and in the unit target, a second `search()` on iPhone and iPad cancels the first run's fetch. Then `swift build --target FRUSCoreKit`, `swift test` with its counts read back, the unit target, the Mac build, and the overlap measurement of §2 run again, to show the wait gone.
- **Not stopped by it**: the Meaning engine's query encode (the model), its `filterKeySet` and `semanticResultRows` reads, the facets' match materialisation and the Query Inspector's counts. Each could be armed the same way later; none is #1648's.

**Where it could go.** Before #1577's lanes 4 to 7 (A5), whose lanes 4 and 5 edit the same two view models, and after A3, whose files it does not share. Or after build 51, since nothing reported on a device asks for it: the cases a reader would notice are the Mac's filter clicks (a second or more each), searches after a cold launch, and any exact-word search for a common word.

## 5. For the web edition

FRUS Explorer Light serves every user's search through one `ServedIndex`, one `SearchService` and one pipeline actor, so the queueing of §1 is shared by its users, and its route says so ("both through the pipeline's one connection", `Sources/FRUSLightAPI/Search.swift`). Under (b) it compiles unchanged on Linux. Its route handlers' own `searchCount` and `search` calls would stop their SQL and throw `CancellationError` if the request's task were cancelled (whether its server cancels a request's task when the client goes away was not checked); its `RecentComputations` runs a shared result in an unstructured task, which no request's cancellation reaches, so a result other requests await is not lost. No golden file moves, since nothing in its parity runs is cancelled. The pull request's line would say so.

## 6. Three findings on the way (the plan's §6g)

- **An exact-word search for a common word holds the pipeline for about two minutes.** `=government` took 59 s for its rows and 58 s more for its count, warm (131 s from a cold start), and every search, facet and indexing write on the pipeline waited behind it. `frus_exact_word` runs on every match in both statements, and `ExactWordMatcher.contains(word:in:)` folds and splits each whole column it is given (`FTS5Store/ExactWordMatcher.swift:94`), about 0.3 ms a body. Not looked at further; (b) would let a replaced one stop, and would not make one that is wanted any faster.
- **On the Mac most of a search's time is the snippet pass.** At 7,500 rows: 0.76 s of `government`'s 1.15 s, 3.72 s of `gov*`'s 4.19 s, 1.20 s of `khrushchev`'s 1.24 s; about 0.1 s a thousand rows on iPhone and iPad, and longer bodies cost more (1.89 s for the 1969–76 volumes). It runs on `SearchService`'s executor, so it also holds up every other call into the service.
- **The default scope's union costs a common word's count about 0.3 s even where nothing in it matches** (§2): the count groups every corpus match by row id to merge a user-content match that, on a library with no summaries or notes, is empty, where the corpus match alone is counted without scoring. The ranking step costs the same either way (0.30–0.32 s for `government`, the sqlite3 shell), since it scores and sorts every match regardless. Not looked at further.

## 7. Not verified

- **No phone**: every figure is the M5's, reading the simulator's library from the Mac's disk. A phone's processor is close to it; its cold reads and its page cache under memory pressure were not measured.
- **The cold figures** are first runs on a fresh clone, read as cold, not proven cold (no `purge` here).
- **Build 49's index**: version 65, where the code is at 69. The statements ran against it unchanged; the row counts of a version-69 library would differ slightly.
- **The stop was measured on a connection of the test's own**, with the pipeline's statements copied by hand; the pipeline itself has no handler to measure until the lane builds one.
- **Not run on Linux**: the Linux claims are read from the C API and the web edition's `Package.swift` and module map.

## 8. The issue, filed as #1680 on the owner's word

**Title:** A search a later one replaced still runs its statements to the end, so the newer search waits behind them (#1648's second step)

**Body, in short:** §0's first two bullets and §2's wait table; the cause from §1; design (b) with (a)'s checks and iPhone and iPad's cancel (§4); not stopped (§4's last bullet); for the web edition (§5). Labels as the owner chooses. The three findings of §6 are separate issues if the owner wants them filed.
