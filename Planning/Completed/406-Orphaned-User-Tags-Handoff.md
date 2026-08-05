# Handoff — Issue #406: Orphaned User Tags (data loss + fix)

**For:** a fresh local Claude Code session on macOS with full Xcode tooling.
**Date:** 2026-07-19 · **Branch:** `claude/orphaned-user-tags-mka3qb` · **Head:** `974e15f`
**Status:** fix + tests committed & pushed. **NOT built/tested** (previous session ran in a
remote Linux container with no Xcode/Swift). **PR not opened** — owner wants tests green first.

---

## 0. Why this handoff exists / your critical path

The previous session investigated #406, wrote the fix + a test suite, committed and pushed to
this branch, but **could not compile or run anything** — it executed in a cloud Linux sandbox
(no `xcodebuild`/`swift`/`xcodegen`, and SwiftData/SwiftUI/CloudKit don't exist on Linux). You
are on macOS, so you can finish it.

**Do, in order:**

1. **Regenerate the project** (two new files must enter the `.xcodeproj`; XcodeGen also clobbers
   the schemes, so restore them):
   ```bash
   xcodegen generate --spec project.yml
   git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/
   ```
2. **Run the new suite, then the standards guard:**
   ```bash
   xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
     -destination "platform=iOS Simulator,name=iPhone 17" \
     -only-testing FRUSExplorerTests/OrphanedTagRepairTests

   xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
     -destination "platform=iOS Simulator,name=iPhone 17" \
     -only-testing FRUSExplorerTests/CodingStandardsAuditTests
   ```
   (Any installed iPhone simulator is fine; adjust the name via `xcrun simctl list devices available`.)
   Consider a full-suite run too — this change touches boot ordering and a CloudKit event observer.
3. **Fix anything the compiler/tests flag** (see §5 for the spots most likely to need a nudge),
   commit, push.
4. **Open the PR** only after green. Suggested body in §7. There is **no PR template** in the repo.
   After creating the PR, subscribe to its activity per repo convention.
5. **Confirm the trigger** with the owner using the diagnostics in §6 (optional but valuable). The
   dev→prod CloudKit lead is **already investigated (§8)** — real mechanism, poor fit for the
   *selective* loss, does not displace the fix; but it opens a possible **name-recovery path** (§4)
   and a **separate latent hazard** worth ruling out (§8).

Everything below is context so you can act without the prior conversation.

---

## 1. The bug (diagnosis)

**Symptom (ground truth — the owner's `frusresearchexport.json`, exported 2026-07-19):**
1 `UserTag` survived, but 94 `DocumentTagAssignment` records referenced **13 distinct tag ids** →
**12 tags gone, 92 of 94 assignments orphaned** (dangling `tagId` with no matching `UserTag`).
Notes (16), collections (7), projects (4), highlights (8) all survived — **loss is selective to
`UserTag`.** Assignment `createdAt` stamps show the lost tags were in active use through
**2026-07-17**, so the loss window is 07-17…19 ("after build 33 deployment"; "propagated through
iCloud — iPad has same issue").

**Confirmed defect (trigger-independent — this is what the fix targets):** tag→document and
tag→note links are **plain `UUID`s with no referential integrity and no orphan cleanup anywhere.**
- `DocumentTagAssignment.tagId: UUID` — no `@Relationship`, no cascade.
- `ResearchNote.userTagIds: [UUID]` — same.
- So *any* `UserTag` disappearance (by any path) silently, permanently orphans its associations.
  Only `mergeTag` ever repoints references; delete/dedupe never did.

**Root TRIGGER is under-determined** (an adversarial verification pass corrected an earlier
over-confident single-cause claim). The export fits two mechanisms equally and neither explains
the timing without an unobserved event:
- **(A)** A Settings tag-delete with no cascade (`SettingsView.swift` swipe `onDelete`, or the
  macOS delete dialog `FRUSSettingsView.swift`). UserTag-selective by construction. Weakness: 12
  deliberate deletes of active tags is implausible.
- **(B)** `DuplicateRecordCleanup` (runs every boot) colliding with the build-33 CloudKit
  re-import. Weakness: `dedupeSimple` always keeps one member per id-group, and the "a CloudKit
  tombstone also removes the keeper" escape hatch is **not demonstrable** (distinct rows get
  distinct `CKRecord.recordName`s); also non-selective (Project/Collection run the same path).
- **(C)** *(open — see §8)* dev-build (CloudKit **Development** env) tags encountered by
  App Store/TestFlight builds (CloudKit **Production** env). The owner's new lead.

**Ruled out:** the #390 flicker fix (verified read-only — sort tiebreaks + `reservesSpace` +
UUID-keyed chips, no `delete`/`insert`/`save`); both full-resets (they also delete
notes/collections/projects — those survived); `mergeTag` (its assignment-repoint fix `638a400`
shipped *in* build 33, so a merge can't orphan on the deployed build); the "id-default-collapse"
theory (the survivor keeps a **real distinct id**, and only 92/94 orphaned — a collapse survivor
would carry the default id and orphan all 94).

**Key point for the PR framing:** don't assert a single trigger. Assert the **harm mechanism**
(no referential integrity) and the **recovery**, both of which the code fully supports. The fix is
correct regardless of A/B/C.

---

## 2. What the fix does (already committed in `974e15f`)

| Change | File(s) | Effect |
|---|---|---|
| **`UserTagAdmin.deleteCascading`** (new) | `FRUSExplorer/Models/UserTagAdmin.swift` | Deleting a `UserTag` now strips its id from every `ResearchNote.userTagIds` and deletes its `DocumentTagAssignment` rows. Wired into the two raw Settings delete sites (iOS swipe `onDelete`; macOS delete dialog). In-memory filter, **not** a `#Predicate` on `userTagIds` (that traps SwiftData). FTS5 is intentionally not touched — it's rebuilt from assignments at every boot (same as the merge path). |
| **`OrphanedTagRepair`** (new) | `FRUSExplorer/Models/OrphanedTagRepair.swift` | Reconstructs a deterministic `"Recovered Tag <id-prefix>"` placeholder `UserTag` for every orphaned tag id (assignments ∪ note refs − existing tags). **Id-preserving**, so all 92 associations re-attach automatically (every consumer keys on `tagId == UserTag.id`). Purely additive + idempotent (existence-guarded). Placeholder `createdAt = min(referencing date)` and name are derived deterministically (never `Date.now`), so two devices emit identical placeholders. |
| **Boot wiring** | `FRUSExplorer/App/FRUSExplorerApp.swift` | Repair runs **after CloudKit imports settle** — an 8s debounce rescheduled off each successful `.import` event in the sync observer (`~line 1566-1579`), never against a partial mid-import store. For local-only stores (`!cloudKitSyncEnabled`) it runs once at boot right after `DuplicateRecordCleanup.run` (`~line 1220`). |
| **Debounce handle** | `FRUSExplorer/App/AppState.swift` | New `@ObservationIgnored var orphanedTagRepairDebounce: Task<Void, Never>?` (~line 270). |
| **`DuplicateRecordCleanup`** placeholder-aware keeper + always-on log | `FRUSExplorer/Models/DuplicateRecordCleanup.swift` | New `dedupeUserTags`/`userTagKeeper`: a real/renamed tag **always beats** a `"Recovered Tag …"` placeholder that shares its id (so a genuine tag re-syncing from CloudKit retention replaces the stand-in, id preserved). Removal-count log promoted from `#if DEBUG` to always-on. |
| **Full-reset parity** | `FRUSExplorer/Settings/SettingsView.swift` (`performReset`), `FRUSSettingsView.swift` (`deleteAllUserData`) | Both now also delete `DocumentTagAssignment` + `DocumentHighlight` — previously omitted, so "delete everything" left orphaned assignments and stranded highlights. |
| **Tests** | `FRUSExplorerTests/OrphanedTagRepairTests.swift` | Pure orphan computation (incl. earliest-date + note-only), reconstruction + idempotency, cascade delete (spares other tags), and the two dedupe-keeper cases (placeholder loses even when it's the earlier record). |
| **Dev log** | `Planning/DEVELOPMENT-PLAN.md` | Session entry. |

---

## 3. Design decisions the owner made (do not silently reverse)

- **Recovery = automatic** (not a manual Settings button) **and a permanent self-healing net**
  (not one-time). Safe *only because* deletes now cascade — a deliberate delete leaves no orphan,
  so the net can't resurrect it into an un-deletable "Recovered Tag" loop.
- **No pre-loss backup exists** → the 12 tag **names are unrecoverable**; recovery restores
  associations under placeholder names the owner will rename. (If an older export surfaces, the
  12 lost UUIDs can be mapped back to real names.)
- Owner confirmed the **CustomVolumeScope CloudKit schema was deployed** to Production — so the
  "undeployed-schema" theory is out.

---

## 4. Recovery expectations (tell the owner)

On the next launch after this ships and sync settles, the owner will see **12 `Recovered Tag …`
entries** with all their original document/note associations restored, ready to rename. This is
expected, not a second bug. Worth a **two-device sync sanity check** afterward, since the repair
writes to CloudKit.

**Possible NAME recovery (new — from the dev/prod investigation, §8):** the original tag names may
still exist in the **CloudKit *Development* environment** if those tags were created by Xcode debug
builds. Before the owner renames placeholders by hand, have them check **CloudKit Console →
Development → `CD_UserTag`** (Act As their iCloud Account) for the 12 lost ids and their `CD_name`
values. If present, export the id→name map and re-apply it to the Production placeholders (a small
one-off script or manual rename), turning `"Recovered Tag …"` back into the real names. Records do
**not** cross environments automatically, so nothing will do this on its own.

---

## 5. Compile/logic spots most worth double-checking (I couldn't build)

- **Strict concurrency on the observer** (`FRUSExplorerApp.swift`): the `NotificationCenter` block
  is `@Sendable`; it now also captures `modelContainer` (Sendable) alongside `appState`
  (`@MainActor final class` → Sendable). Both are used only inside `Task { @MainActor in … }`,
  matching the existing pattern — but confirm no Sendable warning under
  `SWIFT_STRICT_CONCURRENCY=complete`.
- **Two same-`id` records in the dedupe tests** rely on `UserTag.id` NOT being `@Attribute(.unique)`
  (it isn't). Confirm the in-memory test container accepts two rows sharing an `id`.
- **`Task.sleep(for: .seconds(8))`** in the debounce — fine on the iOS 26 target; just confirm.
- Already fixed pre-commit: a `String + Substring` in `OrphanedTagRepair.placeholders` → wrapped in
  `String(...)`.
- **Coding-standards audit**: new files carry the Apache header (required + mechanically enforced).
  `DuplicateRecordCleanup` got a `1.1` version-history entry. New files aren't on the version-history
  allowlist, so they don't need one, but they have `1.0` anyway.

---

## 6. Diagnostics to confirm the trigger (optional, high value)

Ask the owner to grab either:
1. **Console** on a build-33 launch, filter `[DuplicateRecordCleanup]` — a line like
   `Removed 11 duplicate record(s)` implicates hypothesis (B). (It's `#if DEBUG` — needs a debug
   build from Xcode. Note: the new always-on log means future prod builds will surface this too.)
2. **CloudKit Dashboard → Records → `CD_UserTag`**: are the 12 **deleted server-side** (→ a
   propagated delete, A or B) or **present-but-not-syncing** (→ an env/sync issue, points at C)?
   Check **both Development and Production** environments (see §8).

---

## 7. Suggested PR body (no template in repo)

> **Title:** `Fix #406: cascade tag deletes + reconstruct orphaned user-tag associations`
>
> ## Summary
> `#406` reported ~12 user tags and their associations vanishing after build 33, propagating via
> iCloud. The research-data export shows 12 of 13 referenced tags gone and 92 of 94
> `DocumentTagAssignment`s dangling. Root **trigger is under-determined** (a Settings delete with no
> cascade, or `DuplicateRecordCleanup` × a CloudKit re-import — see the issue), but the **harm
> mechanism is certain and fixed here**: tag→doc/note links are plain `UUID`s with no referential
> integrity or orphan cleanup, so any tag loss silently, permanently orphans its associations.
>
> ## Changes
> - **`UserTagAdmin.deleteCascading`** — tag deletion now strips note ids + deletes assignments;
>   wired into both raw Settings delete sites (they previously left orphans; the macOS dialog even
>   promised cleanup it never did).
> - **`OrphanedTagRepair`** — reconstructs an id-preserving `"Recovered Tag …"` placeholder per
>   orphaned tag id so associations re-attach (names are unrecoverable without a pre-loss backup).
>   Runs only after CloudKit imports settle (debounced) so it never duplicates a not-yet-synced
>   tag; runs at boot for local-only stores.
> - **`DuplicateRecordCleanup`** — placeholder-aware keeper (a real/renamed tag beats a placeholder
>   sharing its id); removal log promoted to always-on.
> - Both full-reset paths now also delete `DocumentTagAssignment` + `DocumentHighlight`.
> - `OrphanedTagRepairTests`.
>
> ## Recovery
> On next launch after sync settles, ~12 `Recovered Tag …` entries appear with all associations
> restored, ready to rename.
>
> ## Testing
> `xcodegen generate` (+ restore schemes); `OrphanedTagRepairTests` and full suite on iOS + macOS;
> recommend a two-device CloudKit sanity check.

---

## 8. Dev→prod CloudKit hypothesis — INVESTIGATED (owner's lead)

A research pass (web sources + code) resolved this. **Verdict: real mechanism, fits the build-33
timing, but a POOR explanation for the *selective* loss — it does not displace the
referential-integrity delete bug the fix targets.** Details:

**Mechanism (confirmed, cited):** CloudKit Development and Production are **separate server-side
stores; records never cross** — promotion copies *schema only*, not records. Xcode debug/run =
**Development**; TestFlight/App Store = **Production** (can't use Development). On a debug→TestFlight
install (same bundle id/account) the **local SQLite store persists**, but its cached CloudKit mirror
metadata is now stale for the new environment, and Apple provides **no** automatic handling — the
usual field practice is a manual local reset. Sources: Apple *Designing with CloudKit*
(https://developer.apple.com/icloud/cloudkit/designing/); Apple TN3164
(https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer);
fatbobman *Fixing CloudKit Sync in Production*
(https://fatbobman.com/en/snippet/why-core-data-or-swiftdata-cloud-sync-stops-working-after-app-store-login/);
Rambo *CloudKit 101* (https://www.rambo.codes/posts/2020-02-25-cloudkit-101).

**Why it does NOT explain #406's selectivity:** all user @Models live in the **same private DB and
zone** (`com.apple.coredata.cloudkit.zone`). An environment/zone event operates at store/zone level
and cannot single out `CD_UserTag` while preserving `CD_DocumentTagAssignment`/`CD_ResearchNote`/etc.
It also has no notion of the plain-UUID parent→child link, so it can't systematically delete the
*referenced* tags while keeping the *referencing* assignments. And on first Production launch the
local store still holds the Development-materialized records, so the expected NSPCKC action is to
*upload* them — net-zero local loss, not deletion. The parent-gone/children-kept asymmetry is the
fingerprint of the non-cascading `UserTag` delete, which is environment-agnostic. **Treat dev/prod
as at most a contributing disruption around build 33, not the root cause.**

**Interaction with the shipped fixes:**
- `OrphanedTagRepair` heals the associations **correctly under either explanation** (id-preserving,
  existence-guarded, additive) and cannot mint lasting duplicates (an install talks to exactly one
  environment; within it the pass is id-guarded and `DuplicateRecordCleanup` collapses any race).
- **Doc caveat to fix (minor, non-blocking):** the doc comments in `OrphanedTagRepair.swift`
  (`~:43-48`) and `DuplicateRecordCleanup.swift` claim a genuine tag may "re-sync from CloudKit
  retention" and reclaim the id from the placeholder. That's true for a *CloudKit deletion* (another
  device / retention) but **false for a tag stranded in the Development environment** — it will never
  cross to Production, so those placeholder names are permanent. Consider softening the doc to say
  "if a genuine record with the same id re-syncs (another device / retention) — note a tag stranded
  in a *different* CloudKit environment will not return."

**Separate latent hazard found (NOT the #406 cause, but rule it out / consider fixing):**
`ModelContainer+FRUS.swift:133-139` builds the CloudKit container on the **default (unnamed)** store,
while the fallback `makeLocalContainer()` (`:185-194`) uses a **named** store `"FRUSExplorerLocal"` —
a *different SQLite file*. If a Production build's CloudKit init **fails** (e.g. undeployed schema →
`serverRejectedRequest`), `makeFRUSContainer()` silently falls back to the **empty**
`"FRUSExplorerLocal"` store (`:160`), so the user would see **all** data gone (a broader symptom than
tag-only #406). Worth ruling out via the console signature `"CloudKit container FAILED — falling
back to local-only store"` (`:156`).

**Diagnostics for the owner (confirm/refute + possible name recovery):**
1. **CloudKit Console, both environments** (Act As their iCloud Account): compare `CD_UserTag` /
   `CD_DocumentTagAssignment` / `CD_ResearchNote` counts in **Development vs Production**. Hypothesis
   signature = many `CD_UserTag` in Development, few/none in Production, assignments present in
   Production. If instead *all* types are sparse in Production → a zone/reset/fallback problem, not
   tag-selective. **This is also the name-recovery path (see §4): the Development `CD_UserTag` rows
   carry the real `CD_name` values.**
2. **`SyncDiagnosticsLog`** / the `cloudKitDiagnostic` observer (`FRUSExplorerApp.swift:1556-1602`):
   look for `serverRejectedRequest (15)` / `incompatibleVersion (18)` / `invalidArguments (12)` around
   build 33 — signatures of an undeployed Production schema (would trigger the fallback-store swap).
3. Confirm build 33 (TestFlight) talks to **Production** and prior Xcode runs to **Development**.

**Optional mitigations (belt-and-braces, not required for the PR):** deploy the Development schema to
Production before every TestFlight/App Store build (already documented at
`ModelContainer+FRUS.swift:44-52`); detect a dev↔prod deployment-environment flip (persist last-seen
env in UserDefaults) and do a controlled local rebuild instead of letting NSPCKC reconcile a stale
mirror; unify the CloudKit and fallback store names (or make the fallback obvious in the UI) so a
CloudKit-init failure can't masquerade as total data loss.

**Nothing in the app is currently environment-aware** (confirmed: `ModelContainer+FRUS.swift:133-137`
uses a plain `.private(...)`; no `icloud-container-environment` / store-reset code anywhere).

---

## 9. Repo/process notes

- **XcodeGen is source of truth** (`project.yml`, directory-globbed). After adding files you MUST
  `xcodegen generate` then `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`
  (xcodegen regenerates schemes with wrong values).
- Do **not** run `xcodegen` just to bump build/version — see `CLAUDE.md`.
- Bundle id `bottsywattsy.FRUS-Explorer`; CloudKit `iCloud.bottsywattsy.FRUS-Explorer`; iOS scheme
  `FRUSExplorer`, macOS `FRUSExplorerMac`.
- Stay on branch `claude/orphaned-user-tags-mka3qb`. Commit trailer convention:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
