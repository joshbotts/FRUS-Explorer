# Wave R — the research trail, and build-35 tester feedback

**Status:** plan, not started. Runs **after S-6** (Settings docs closeout).
**Inputs:** `Planning/Settings-Parity-Audit-2026-07-25.md` (§B2, B3, and the deliberate-list
entry on search logging); build-35 tester feedback (not yet collected).

---

## The finding this wave exists for

**The app records what you read twice, through two independent systems, and the switch that
claims to control it governs only one of them.**

Open a document in `DocumentView` and two things happen about fifty lines apart:

| | `AppState.logEvent(.documentOpen)` | `DocumentViewModel.recordReadingHistory` |
|---|---|---|
| Fires at | `DocumentView.swift:397` | `DocumentView.swift:446` |
| Writes | `SessionEvent` → `ResearchSession` | `ReadingHistoryEntry` |
| Gated by `researchSessionLoggingEnabled`? | **Yes** (`AppState.swift:497`) | **No gate of any kind** |
| Read by | `SessionLogView` only | History window, Project Home, Project Leads' engaged-documents, the search checklist, the storage hub's last-opened dates |
| Carries | volume, document, title, timestamp | volume, document, title, project, timestamp |

So the switch labelled **"Log Research Sessions"** stops the recorder that nothing consumes and
leaves running the one that feeds five features. A user who turns it off to stop the app
remembering what they read has not stopped the app remembering what they read.

The same shape holds for searches, with the platforms swapped:

| | `.searchSubmit` event | `SearchHistoryEntry` |
|---|---|---|
| Producer | `SearchViewModel.swift:505` — **iOS only** | `MacSearchViewModel.swift:749` — **macOS only** |
| Gated? | Yes | No |
| Records the query text | Yes | Yes |

Net effect across two devices: an iPhone records your search text into a gated log nothing reads;
a Mac records your search text into an ungated store the History window reads. Neither device
shows you the other's searches. **Both** stores sync via CloudKit.

This is not a duplication to be tidied — it is a **privacy-honesty bug** plus a **feature gap**
wearing the same clothes, and that is why the two belong in one wave rather than being fixed
piecemeal.

---

## R-0 — Decide the model *before* writing any code

Three questions for the owner. Nothing else in the wave can be sequenced until they are answered,
and two of them are policy, not engineering.

**Q1. One trail or two?**
- **(a) Collapse.** `ReadingHistoryEntry`/`SearchHistoryEntry` become the trail; `ResearchSession`/
  `SessionEvent` are retired, with sessions derived by grouping entries on the 30-minute idle rule
  at read time. One store, one gate, one thing to explain. Cost: a migration, and the loss of the
  session grouping as stored data (it becomes a query).
- **(b) Keep both, gate both.** Sessions stay as the "what happened, in order" log; the history
  entries stay as the "what have I touched" index. Both honour the switch. Cost: two stores to
  keep honest, forever, and a switch whose scope needs explaining.
- Recommendation: **(a)**. Two records of the same event is how this drifted apart in the first
  place, and the derived-session query is a dozen lines.

**Q2. Does the trail record search *text*?**
Today it does, on both paths, and syncs it to iCloud. Options: keep it (it is the user's own data,
now visible and deletable since PR #503); keep it but exclude it from sync; or record only the
result count. This is the owner's call and should be written down wherever it lands.

**Q3. What should the switch actually promise?**
"Log Research Sessions" is engineering vocabulary. If the trail becomes one thing, the control is
better named for what it governs — **"Remember What I Read"** or similar — with the honest footer
that PR #503 already drafted. Renaming the *label* is free; the `UserDefaults` key
`researchSessionLoggingEnabled` must not change (user-data-bearing, and mirrored into a CloudKit
record via `SyncedPreferences.researchLoggingEnabled`).

---

## R-1 — Close the gate (do this regardless of Q1)

Make `recordReadingHistory` and `recordSearchHistory` honour the same preference `logEvent` does.

- Extract the gate to one place — `AppState.isResearchLoggingEnabled` — so there is a single
  reader of the key rather than three call sites doing `UserDefaults.standard.object(forKey:)`.
- Apply it at `DocumentViewModel.swift:529` and `MacSearchViewModel.swift:749`.
- **Test:** with the preference off, opening a document inserts neither a `SessionEvent` nor a
  `ReadingHistoryEntry`. That test does not exist today for any of the three writers.
- **Consequence to state in the PR:** turning the switch off will now visibly empty History and
  the Project Home recents over time. That is the honest behaviour, but it is a behaviour change
  and the copy must say so.

Independent of Q1, small, and it is the half of this wave that is a *correctness* fix rather than
a feature. Could ship before the rest.

## R-2 — One trail, one store

Executes Q1's answer. If (a): migrate `SessionEvent` payloads into `ReadingHistoryEntry`/
`SearchHistoryEntry`, derive sessions at read time, retire the two models from `frusModelTypes`,
and keep `SessionLogView` pointed at the derived grouping. Needs a migration story for records
already in users' iCloud private databases.

## R-3 — A History surface on iOS

`HistoryWindowView` is macOS-only (`#if os(macOS)`, reached by the `frus.history` scene and the
Research ▸ History menu). iOS has no view over the trail at all — the nearest thing is Project
Home's per-project recents, and only when a project is active.

- Shared view, per the S-programme pattern: a `HistoryView` both platforms render, macOS in its
  window, iOS pushed from the Research tab.
- Depends on R-2 if the model collapses; otherwise it must read both stores.
- This is the largest single "my Mac can do things my iPad cannot" left in the app.

## R-4 — Search history on iOS

`SearchHistoryEntry` has exactly one producer and it is macOS-only, so even after R-3 the iOS
History screen would show reading but no searches, and the Mac would show only searches made on
the Mac. Add the producer to the iOS search path. **Note the ordering trap:** doing this *before*
R-1 would start recording iOS search text into an ungated store — strictly more collection than
today. R-1 must land first.

## R-5 — Delete, export, and the copy

- `ResearchSessionAdmin.deleteAll` (PR #503) deletes sessions only. Whatever R-2 settles on, the
  delete must cover the whole trail, and Data & Recovery's **Contents** inventory should list it —
  it currently accounts for notes, tags, highlights, collections, prompts and projects, and is
  silent about the trail entirely.
- Research-data export (`ResearchDataExportView`) likewise omits the trail.
- Re-do the Research Sessions pane's copy against whatever the wave settles: the footers written
  in #502/#503 are honest about *today* and will be wrong the moment R-1 lands.

---

## Tester feedback — build 35

Not yet collected. Slot it here rather than in a separate wave: the settings programme touched
every pane in the app across S-0…S-6, and build 35 is the first build testers see all of it in.
Expect the feedback to cluster on surfaces this wave already opens.

**Intake checklist when the feedback arrives:**
1. Trailer through the existing triage shape (`Planning/Issues-207-219-Remediation-Plan.md` is the
   precedent for a tester-feedback wave: group by surface, not by reporter).
2. Cross-reference against `Planning/Settings-Parity-Audit-2026-07-25.md` — several audit entries
   are things a tester will independently report, and they should be merged rather than fixed
   twice. Likely candidates: the macOS hub's hover-only explanations (§D1), "Check Console.app"
   (§D2), the missing macOS settings search (§B4), and the inert precompute toggle (§B5).
3. Anything a tester reports about "the app remembers/doesn't remember what I read" belongs in
   R-1, not in a separate bug.

**Known-unverified items worth pointing testers at**, all from this session:
- The iOS Volume Scopes swipe-delete guard (shipped but not exercised on device — a scope would
  not persist in the simulator).
- The populated Notes list and All Notes screen on iOS.
- `ResearchSessionAdmin.deleteAll` end-to-end (unit-tested only; the log on the dev machine is
  real research history).

---

## Suggested order

**R-1 → (Q1 answer) → R-2 → R-3 → R-4 → R-5**, with tester feedback triaged into whichever step it
lands on. R-1 can go early and alone; R-3 is the item with the most user-visible value and should
not start before Q1 is settled, or it will be built against a model that then changes.

## Standing constraints

- Do not change the `researchSessionLoggingEnabled` key string. It is user-data-bearing, untested,
  and mirrored into CloudKit via `SyncedPreferences.researchLoggingEnabled`.
- `ResearchSession.events` is `.nullify`, so any deletion path must remove events explicitly or
  orphan them (`ResearchSessionAdmin` documents this; a test pins it).
- Both stores are in `frusModelTypes` and therefore CloudKit-mirrored — any schema change needs a
  migration story for records already in users' private databases.
- House rules as ever: implementer ≠ reviewer, PRs base `v2`, visual-review checklist in every UI
  PR body, `build-for-testing` before claiming green.
