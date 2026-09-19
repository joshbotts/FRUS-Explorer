# Open-issues resolution plan — 2026-09-19

Base: `v2` @ `9078fe61` · index v51 (`IndexingPipeline.swift:824`) · rollup v9 · build 47 · **no open PRs**.
Corpus pinned at `/Users/jbotts/Development/frus` `550a8c5c5`.

Every open issue was re-verified against this tree by one analyst and then attacked by an independent
skeptic; a cross-issue pass and a completeness critic followed. Nothing below is taken from an issue
body without a re-check. **This is a proposal, not a plan of record** — `Plan-Of-Record-2026-09-06.md`
remains the single live plan of record (the audit test allows only one).

---

## 1. Where the twelve issues stand

| # | Title (short) | Verdict | Size | Index bump | Gate |
|---|---|---|---|---|---|
| 1311 | Toolbar overflow suite fails on iPad mini | **Already fixed** by #1316 (`402932d4`) — **closed 2026-09-19** | XS | no | — |
| 1321 | Letter-grouped persons lists parse to zero | Still valid; **live regression on build 47** | S | **v52** | — |
| 1322 | Trip packet cites `ordinal+1`, not the printed `@n` | Still valid | M | **v53** | nil-label wording |
| 1323 | `rend="strong"` never renders bold | Still valid | S | no | bold signatures? |
| 1304 | Booleans/`-`/groups inside `NEAR(…)` silently degrade | Still valid | M | no | **option 1/2/3** |
| 1310 | My Tags counts are keyword counts in Meaning mode | Still valid | S/M | no | **count or hide** |
| 1307 | Search actions bar overflows at AX sizes | Still valid | S/M | no | **cap or fold** |
| 1305 | "counted once" is false under Occurrences | Still valid (+ a bar defect) | S→M | no | **bar in scope?** |
| 1306 | Two unmeasured claims in the dating help | Still valid (+ 2 new defects) | M/L | no (one spin-off does) | **chart rule** |
| 1309 | Yalta TEI short a `</div>` | Still valid; resolution is a **sweep + OH report** | XL | no | OH channel |
| 1081 | Screenshot checklist | Owner lane; gated on 1321/1322/1323 + analytics | L | no | scheme, device |
| 234 | Extend the people browser | A decision set (R1–R18), not a code task | L | no | **R1–R18** |

Plus one **unfiled** defect found yesterday and characterised here: the SwiftData **test-host crash**.

---

## 2. What the review found that the issues do not say

1. **#1321 is shipped, not latent.** The `build-47` tag is `d736cbed`, which already contains v51
   (#1291), the R-1a persons scrub and #741's rule. Testers have already re-indexed and already lost
   the 37 volumes' persons lists (9,127 entries → 78). v52/v53 is therefore a **new** full re-index
   for everyone, not a free ride — so both parser PRs must ship in one build, and the TestFlight note
   must own the cost.
2. **The test-host crash gates every "green" claim in this wave.** 9 of 39 `ModelConfiguration(`
   sites in `FRUSExplorerTests` omit `cloudKitDatabase: .none`; 8 of 9 measured full-target runs
   crashed the host mid-run. Narrow `-only-testing` scopes that dodge those seven files are safe; a
   full unit run is not.
3. **Three of the plans' own `-only-testing` arguments name files, not types** — they would run zero
   tests and report success. Fixed in the per-issue notes.
4. **#1323's blast radius is far larger than its issue.** 34,298 of 41,951 in-document `strong`
   occurrences are signatures, in 33,477 documents. history.state.gov renders them bold, so accepting
   is defensible — but it is the dominant visible change and the issue never mentions it.
5. **#1322 should store the note's `xml:id` beside the label** while the table is being re-derived:
   the printed label is not unique (6,912 documents repeat one). Skipping it costs another re-index.
6. **No CloudKit gate anywhere in this wave.** Nothing adds or removes a `@Model` or a stored
   property. If `CloudKitSchemaInventoryTests` goes red, something unplanned changed.
7. **The 89.3% person-coverage figure should NOT be swept.** Measured: 92.16% today, 88.96% after
   #1321 — but the denominator is the live device index (population 2) and four of the five sites are
   dated records (population 3). Leave them; put the measurement in the PR body instead.
8. **`552 → 553` and "268 of 552" are claimed by three issues** (#1321, #234, #1081). Assign one
   owner: the #1321 PR.
9. **CLAUDE.md's build-bump procedure is incomplete** — `README.md` carries the build number and is
   pinned by `CodingStandardsAuditTests.readmeStatesCurrentBuild`.

### New defects worth filing (none of them has an issue)

All were filed on 2026-09-19 after a second pass re-measured each one; the figures below are the
filed ones, which differ from the review's first numbers where the re-measurement moved them.

| Filed | Defect | Cost |
|---|---|---|
| **#1325** | Nine bare `ModelConfiguration` sites keep SwiftData's CloudKit default: the unit target ends `TEST EXECUTE FAILED` with five host crashes per run | S — **fixed in PR #1330** |
| **#1326** | 11,888 documents indexed one day off: `frus:doc-dateTime-min` is an instant re-expressed at −05:00 and `normalizeToFullDate` reads its first ten characters as the day | M + **index bump** |
| **#1327** | By Day mixes UTC and local time: 793 Jan-1 documents file under the previous year, 1,226 Dec-31 documents fall outside the plot, every exported row is a day early | S |
| **#1328** | Under Occurrences the bars still count documents while the axis, fit line, footnote and CSV count occurrences | M |
| **#1329** | Summary templates ask the model for participants and their offices in the 266 volumes with no persons list — and name-keyed seeding means editing the literal reaches no existing install | needs a refresh pass, not a copy edit |
| *(comment on #1306)* | "the counts here match what Search returns" is false — Analytics reads `frus_documents` alone, Search unions `user_content`, and the hand-off drops undated documents | copy |

A correcting comment also went on **#1305**: its body assumes the bars already show occurrences,
which #1328 refutes, so #1305 cannot be closed on a reworded string alone.

---

## 3. Sequence

```
PR-A test-host crash ─┬─ PR-B close #1311
                      │
   TEI lane:  PR-C #1323 → PR-D #1321 (v52) → PR-E #1322 (v53) → cut build 48
                      │
   search lane (parallel):  PR-F #1304 → PR-G #1310 → PR-H #1307
                      │
   analytics lane:  behaviour (#1305 service, #1305 bars, #1306 charts) → ONE copy PR
                      │
   long-running (parallel, no app files):  #1309 validator ;  #1081 Phase 0 docs
```

**Wave 1 — unblock verification. DONE.** PR #1330 (#1325): nine `cloudKitDatabase: .none`, the app-side
in-memory fallback, and a tree-wide gate. A/B on one device and flags: before, `TEST EXECUTE FAILED`,
4,948 passed / 5 crashes; after, five consecutive `TEST EXECUTE SUCCEEDED` runs, 4,954 passed / 0
failed, zero `Restarting after unexpected exit` and zero `NSCloudKitMirroringDelegate`. PR-B: close #1311; the optional
hardening is aimed at the wrong leak — three UI tests still persist a real project UUID through
`ProjectEditorView.swift:298`, so a `defaults delete` does not leave a simulator clean. Either gate
persistence on `FRUS_UI_TEST_MODE` (covers every writer) or record the residual as accepted; do not
ship the proposed CLAUDE.md edit, which is false either way.

**Wave 2 — TEI/parse lane, ordered (shares two files and the bump).** #1323 first (no bump, verifies
immediately). Then #1321: the rule is "an `<item>` that reaches a nested `<list>` without saying
anything is a group, not a person" — measured over all 553 volumes it restores 9,049 entries in 37
volumes, reproduces the pre-#741 parse exactly, and leaves the other 516 volumes byte-identical.
Drop the plan's "loss-free by construction" claim (text after a nested list *is* captured — the
skeptic built the counterexample), add the section-end reset and that fixture. Then #1322. Cut build
48 after the pair: one re-index for v52+v53, and the bump edits `README.md` too.

**Wave 3 — search lane**, independent of wave 2, internally sequential on shared files: #1304 first
(largest change), then #1310, then #1307 (the only issue here needing `xcodegen` + scheme restore,
for a new AX suite that must set `FRUS_UI_TEST_DISABLE_ANIMATIONS=1`).

**Wave 4 — analytics: behaviour first, one copy PR last.** Writing the help before the chart rule is
chosen would ship a third unmeasured claim into the row that exists to remove unmeasured claims. One
exception: the **phrase row**'s "counts match what Search returns" is false for reasons no pending
decision touches — it can be corrected immediately.

**Wave 5 — parallel and long-running.** #1309 is SPM-only and touches no app file: build the
structure validator, adjudicate against OH's own page images, then one report. Its 131-finding review
queue must not go to OH unadjudicated — a false positive costs credibility. #1081 Phase 0 is docs-only
and can land any time, but its `552→553` edits belong to the #1321 PR.

**#234** opens no PR until R1–R18 are answered. Two items should leave the program now: R1 retargets
to v52 (not v51, which build 47 already did), and R14 (the summary-template participant fields) is a
live defect that needs no research decision.

---

## 4. Owner decisions

**Blocking a PR that is otherwise ready**

1. Ship #1321 + #1322 together in build 48, accepting a new full re-index for every tester.
2. Two sequential PRs (52 then 53) or one PR taking a single 52.
3. **#1304**: refuse (option 3, recommended), degrade-and-disclose (2), or drop the distance (1) —
   and whether `AND` inside `NEAR` is refused or a no-op. Note option 3 also refuses
   `NEAR(a OR b)`, which runs a sensible search today.
4. **#1310**: count over the result keys in Meaning mode (recommended), or hide the counts there.
5. **#1307**: cap the glyphs (Apple's own bar pattern) or `ViewThatFits` (this repo's documented
   idiom for that geometry) — and resolve the 320 pt Display-Zoom floor, where 1.55× still fails.
6. **#1306**: chart rule R1 (whole interval inside the bucket; −3.01%/−3.56% of documents), R2
   (padding-shaped only; −521/−919), or text-only.
7. **#1305**: is the bar defect in scope? It decides that PR's size and the copy's wording.
8. **#1323**: accept bold signatures corpus-wide (34,298 occurrences).
9. Assign the `552 → 553` / "268 of 552" sweep to the #1321 PR.
10. Close #1311 (fixed by #1316, which never linked it).

**Not blocking, but needed before the copy PR and the sittings**

11. Final copy for all three analytics rows + the export caveat, in one review, after the behaviour
    lands — and whether it names the 1,000/7,500 result caps.
12. #1309: channel and granularity for HistoryAtState (one consolidated issue, per their #252
    precedent, or per volume); patches attached or report only; fold in the refreshed
    broken-cross-reference CSV; make the validator a standing release step.
13. #1081: filename scheme, iPad class and pinned runtime, whether §5's 16 optional slots are part of
    the close criteria — and a fifth capture gate behind the analytics work.
14. Whether to file the six new defects above, and whether the test-host crash gets an issue or goes
    straight into PR-A.
15. #234 R1–R18, plus the question the program does not ask: is *correspondents from editor markup* —
    which uses neither POCOM nor NER — an acceptable first answer to #234 at all?

---

## 5. Device verification matrix

| Work | Destinations | Why |
|---|---|---|
| PR-A | one pinned iOS 27 UDID + a full unit-target run | only a full run exercises all nine sites |
| TEI lane units | iPhone 17 + `TEST_RUNNER_FRUS_TEI_MIRROR` | confirm the real-TEI suites *ran*, not skipped |
| TEI lane visual | iPhone + iPad two-pane + Mac | owner-captured; #1323 needs a device holding corrected v16 |
| #1304 / #1310 | iPhone 17 + Mac | both platforms route through the filter popover |
| #1307 | iPhone 17 + a 375 pt SE on iOS 27 + 320 pt Display Zoom + iPad | the cap binds at widths no default simulator has |
| #1306 | iPhone + iPad + Mac, including iOS table mode | the not-placed footnote is missing in compare and table modes |
| #1311 guard | iPad mini (A17 Pro), **pinned UDID and runtime**, `-test-timeouts-enabled YES` | a `name=` destination picks one of four runtimes |
