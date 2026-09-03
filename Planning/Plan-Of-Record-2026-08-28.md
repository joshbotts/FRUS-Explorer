# Plan of Record — 2026-08-28, after build 44

**Status:** the single live plan — **reviewed and revised 2026-08-29 (§7), re-prioritised
2026-08-31 (§8), external animation handoff assessed 2026-08-31 (§9)** — superseding
`Completed/Plan-Of-Record-2026-08-23.md`
(discharged in bulk: tiers A and B shipped whole, Tier C's harvest lane closed except the
#234 scoring path, Tier D's W-9 completed FAR past its written scope — the encoder, the
licence surfaces, the zero-result fallback, and the full hybrid page all shipped — and
Tier E shipped W-11/W-16/W-17 leaving its four assessments/features). Written the day
**build 44 was tagged** (`build-44` at `c47a9d48`: search by meaning, archive visit plans,
Similar wording, overrides, freshness, Spotlight text, the quit fix) and the day the owner's
**Mac Studio began the Qwen3-14B NER harvest** — which is why Tier A *was* #234. It no longer
is: the harvest did not finish in the week, and §8 records the re-prioritisation. Read §2 for the
current tier, not this paragraph, which stands as the document's origin note.

**How to keep this current:** when a session ships, strike its row. When this document's
sequencing is overtaken, replace it the way it replaced its predecessor.

---

## 1. The standing gates

1. **Build-44 tester feedback outranks the order below when it lands.** Two verdicts are
   outstanding — but *(corrected 2026-08-29, §7)* they are solicited by **different
   builds' notes**, not both by build 44's. Build 44's What-to-Test asks only **do Meaning
   search's top matches deserve opening** ("this is the verdict we most need", following
   the owner's own 25-query sitting). The **clusters/semantic-map leads-or-noise**
   question was build 43's ask ("coherent research leads, or arbitrary piles?") and the
   build-44 rewrite dropped it, so that verdict rides the 43 cohort; if it stays silent,
   restore the ask in the next build's notes rather than assuming it is still being put.
   Consequences remain pre-decided for the map (one clean removal commit, recorded in
   `Completed/Browse-Axes-Development-Plan.md`); a poor Meaning verdict demotes Tier B's
   V-5 residues, not the shipped surfaces.
2. **The Studio harvest is the owner's machine and stays untouched from here.** Nothing in
   this plan may assume its completion date; scoring rows activate when the owner says the
   stores exist. *(Updated 2026-08-31: the owner reports the harvest **will not finish this
   week**, so #234's scoring lane is DEFERRED — §4b — and Tier A is now the two programs in
   §2. The one #234 item that stays live is the owner-gated seeding annotation, N-0, because
   it is owner work that does not wait on the machine and because every scoring row is
   refused without it.)*

## 2. Tier A — the two programs *(re-prioritised 2026-08-31)*

#234 held this tier because the Studio was mid-harvest. It is not finishing this week, so the
tier goes to the two programs that were already written, already verified against the tree, and
gated on nothing: **the visual and marketing plan** and **the agentic-loop wave**. Both have
their own plan documents; the tables below stay pointers, not copies.

### 2a. The visual and marketing plan — `Visual-Marketing-Plan.md`

Proposed 2026-08-30 against the tree at `30b105e`; eight verified probes, three independent
drafts scored adversarially, and a completeness critic that **overturned the winning draft's
flagship claim and corrected six motion items**. It reconciles against
`Map-Figure-Export-And-Visual-Outputs.md` §7–§9 rather than sitting beside it — which is why
Tier B's old B-3 row is struck below and folded here.

Its own §7 sequences the work. The two things a reader of *this* document needs:

| # | Lane | Scope | Gate |
|---|---|---|---|
| M-1 | **The store listing — the critical path** | Plan §4.1. This is the row that gates an App Store submission, and it is separated from research figures on purpose: `AnalyticsFigureCanvas` paints white, pins `.colorScheme(.light)` and prints a mandatory methods band with no width parameter reaching any caller — right for a figure, wrong for a screenshot. The two asset families obey different rules and §3/§4 keep them apart. | none |
| M-2 | **The five residual gaps in the shipped map export** | *(2026-08-31, §9: Gap 4 and plan §3.2's M-3 lens dip are the same shape — one shared pipeline, two consumers, one of which is a published figure. Plan §7 schedules Gap 4 at step 2 and M-3 at step 8; either pull the shared assertion forward or accept the gap deliberately.)* Plan §1. Three block publication — the caption band carries no caveats and credits "FRUS Explorer 0.2" rather than the Office of the Historian; the plate unconditionally prints a sentence a standalone PNG makes false; the map's mandatory lens caveat reaches neither export half. Plus one print defect (`sourceAlphaBlendFactor = .sourceAlpha` washes the plate and clamps bright dots) and one methods gap (the plate cannot state what was in frame). **Gap 4 is a plan-author error the critic caught**, and fixing it touches the single shared pipeline — verify on screen as well as in the plate. | none |
| M-3 | **In-app motion** | Plan §3, corrected: §3.1 is *film what already ships*, §3.2 is the new motion the critic re-scoped. Note plan §2(a): the splash and a corpus-bearing device are mutually exclusive by construction, so a capture plan that assumes both is wrong. **Re-reviewed 2026-08-31 (§9)** against the shipped animation code: read plan §3.1's new **Renderer column** before scoping anything that mentions "the splash's drift" — the splash has never run the particle canvas, and plan §3.2's M-4 therefore *enables a renderer* rather than tuning a constant (re-priced **S in code, M in risk**). Plan §3.2's M-1/M-2, M-3 and M-5 moved **ahead of the capture sessions**; M-4 deliberately stays after them. A new plan §7 **step 0** fixes a real double-cloud defect — a search cloud already up when indexing begins is never withdrawn. **Beware the M-number collision: this table's M-numbers are not plan §3.2's.** | none |

Plan §6 names its own largest structural gap (operations) and §8 records what it refuses.
Read those two before scoping a session out of it.

**PROGRESS THROUGH 2026-09-01. Every engineering row in this plan is now closed; what remains is
capture, assembly and one deferred motion item.** The lane table above describes the state at
proposal and is left as written — read this block for what is true.

| Lane | State |
|---|---|
| **M-2** — the five residual gaps | **ALL FIVE CLOSED.** Gaps 1–2 by GATE C (#1154), 3–4 by steps 1–2 (#1155), 5 by its methods half (#1157). The three that *blocked publication* were the first three, so **the map figure and the analytics plates are publishable**. |
| **M-3** — in-app motion | **§3.2's M-1, M-2, M-3 and M-5 shipped** as one change (#1158), plus §7 step 0's double-cloud fix (#1156). **M-4 SHIPPED 2026-09-01 (PR #1174)**, pulled ahead of capture per §4c. The `M in risk` pricing was right: enabling drift on the splash made it the app's first `showsChip` + `drift` surface and surfaced **two defects the review did not predict** — the chip named a lens the canvas was not drawing on 75% of launches (silently undoing M-5 in the words while the label went on claiming otherwise), and the exclusion zone was computed in the overlay's safe-area box and consumed in the backdrop's full-bleed one, 62 pt out on an iPhone 17. Both fixed. 17 mutations killed. **Owner step outstanding: the on-device composition review at phone and Mac widths**, and it has three named things to look for — see the PR. |
| **M-1** — the store listing | **Copy drafted** (#1160, `Store-Listing-Draft.md`): every field counted, every number measured from a shipped artifact, disclaimer in the same field as the "official documentary record" line. **GATE B was already satisfied** — 552 volumes, 316,839 documents — so the capture program is unblocked. **GATE A stays owner-only** (EULA placeholders, privacy nutrition label; still no `.xcprivacy` in the repo). |

**§7 struck: 0, 1, 2, 3, 4, 6, 7, 8, 9.** That line is machine-checked against the plan itself by
`CodingStandardsAuditTests` — strike a row there without updating it here and the suite fails, which
is the drift this document has already suffered once. Step 5 is deliberately NOT struck: its four
conditions are closed but the plates themselves are an export the owner presses. **Steps 10–16 are
the owner's**: run the capture sessions, finish the film, record the App Preview, Plate B, then M-4
and the outside-the-repo composition.
`Planning/Capture-Runbook.md` is the afternoon written down — every command self-contained and
executed verbatim, the simulator wedge and its only measured cure, and the device classes the store
actually requires (6.9″/13″), which are **not** the two this plan names.

**Five plan premises did not survive contact, each recorded at its row**: M-1's constraint 3 (a
reveal-versus-`applyScope` race that does not exist — `setScope` never touches the camera); GATE C's
"five builders" (there are 14 construction sites across 7 files); the claim that the caption band
would eat the chart (the plate grows instead — measured +76 pt at any chart height); §4.2 condition
3's "CSV-only today" (GATE C had already carried it to the plate); and the frame sequence's coverage
ordering, which opened the film in **1620** and is now publication-ordered, opening on `frus1861`.

### 2b. The agentic-loop wave, W-19 — `Agentic-Loop-Development-Plan.md`

*(Was Tier D, added 2026-08-30; promoted 2026-08-31.)* One wave, one plan document: the app-side
work that turns the loop `Docs/Agentic-Analysis-Guide.md` documents — curate in the app, compute
over the curation, adjudicate in the app — from folklore into affordances. Nine rows, each
anchored to the code it extends. **No CloudKit schema change anywhere in the wave** (every row
checked against the #488 gate; L-3 writes a plain SQLite table on the indexing side). The plan
argues its own sequencing.

| # | Session | Hand-off | Size | Gate |
|---|---|---|---|---|
| L-0 | Guide correction — Appendix A.7 stale since build 44 (the app now embeds queries) | — | XS | none |
| L-1 | `.fruscollection` write-minimum: spec + conformance fixture (the inbound keystone) | inbound | S | none |
| L-2 | Export Research Database… (backup + integrity + default-off include-my-notes) | outbound | S | none |
| L-3 | Mirror tag names into `user_tags` beside the existing id sync | outbound | S | none |
| L-4 | Surface the shipped embedder (reveal model path; publish `queryPrefix`, undigested) | both | S | none |
| L-5 | `frusexplorer://` document deep links (touches `project.yml` — xcodegen ritual) | inbound | M | none |
| L-6 | Corpus-wide shard fetch as an explicit named-cost button (#926's refusal upheld) | both | S | none |
| L-7 | Copy research-state record (build, index versions, volume list, digests) | outbound | XS | none |
| L-8 | Local read-only MCP server — ASSESSMENT, build/no-build | both | M | L-1..L-4 |

**THE WAVE IS COMPLETE AS OF 2026-08-31 — every row struck.** L-0..L-7 shipped as PRs #1142–#1149,
and **L-8 was assessed and refused**: `MCP-Server-Assessment-2026-08-31.md` records a NO-BUILD on the
MCP server, superseded by a read-only CLI (C-1) that is itself gated on running a falsifier first
(C-0). The gate in L-8's own text did its work — measured against the baseline the other seven rows
built, an MCP server would have been the first artifact in the wave that works only for users of
MCP-capable clients, narrowing the audience for no guarantee a fixed-subcommand binary does not
already give. Two of the row's premises did not survive; the assessment names both.

**THE RESIDUE SHIPPED THE SAME DAY (PR #1151)** — all five items: §14.11's artifact paths, §12's
surface-routing table (plus a SURFACES preamble and per-rule `[TEI]`/`[JSON]` tags inside the
pasted block), three `research_*` views on the L-2 export, a `research_provenance` stamp inside the
copy, and `README.md` 37 → 44 with a test pinning it to `project.yml`. Building it exposed three
more defects, all fixed: §12's Ed2 rule read as an instruction to delete the *first* editions;
§14.9's 718-document overlap is the semantic artifacts' figure while the index's is **701**, so the
section about double-counting was violating the guide's own counting-surface rule; and §14.11's
table listed thirteen of the fifteen artifacts it counted.

**AND C-0 RAN THE SAME DAY (PR #1152) — the falsifier substantially FIRES.**
`C0-Falsifier-2026-08-31.md` records it: eight scoping passes, two fresh questions × (§12 block
pasted | no rules) × 2, blind-scored against a rubric frozen before launch. **BLOCK 96/97 = 99%,
CONTROL 81/96 = 84%.** The block works — on L-8's own terms, *the rules that do not survive a paste
are the subcommand specification*, and that specification is nearly empty. §14.11's archival zero
turns out to be **part discovery failure** (4/4 no-rules runs opened a bundled artifact once the
files were merely listed by name, which is what PR #1151 shipped) and **part rules failure** (those
same four runs resolved **zero NAIDs**, against 4/4 in the block arm). Of the four rules the block
earns, two are already structural in #1151's views. **C-1 was therefore downgraded to a row gated on C-2**, a
long-session re-run — the only setting where the delivery-channel argument can be true.

**C-2 RAN THE SAME DAY (PR #1153) AND CLOSES THE WAVE.** `C2-Long-Session-2026-08-31.md`: eight
sessions of 123 tool calls each (2.1× C-0's, ranges non-overlapping, verified before any verdict was
read), three non-archival tasks in front of C-0's byte-identical terminal task, withheld in a file so
it entered context far from the rules. **LONG+block 99/100 — not one item decayed**, against
SHORT+block 96/97. The no-rules arm *did* decay, 84% → 75%, which is what makes that a finding rather
than a null. Catalogue identifiers resolved, all sixteen runs across both experiments: **BLOCK 8 of 8,
CONTROL 0 of 8.** **C-1 is CLOSED as NOT NEEDED** on C-2's pre-registered reading, and W-19 ends with
a build refused twice on measurement — once for MCP at L-8, once for the CLI here. Recorded limit: no
session compacted, so the *truncated* half of the mechanism is untested; it does not reopen C-1,
because that branch's fix is re-pasting the block rather than shipping a binary.

**L-0 was larger than its row implied.** `Docs/Agentic-Analysis-Guide.md` is now
at **v1.2** (PR #1137): §14 added the scoping method from three measured runs, and §14.11 added
the archival half after an audit found all three runs had resolved zero record groups and zero
NAIDs. Two consequences for this wave. First, A.7's staleness is unchanged and still owed.
Second, **§14.11 was read at the time as the strongest argument yet for L-8** — the rules a local
MCP server would enforce, written down and measured. C-0 has since narrowed that: pasted as prose,
those same rules are obeyed 96 times in 97, so what §14.11 established was a *specification*, not a
case for a binary to carry it. The guide is now at **v1.10**.

### 2c. One small UI item

| # | Session | Scope | Gate |
|---|---|---|---|
| ~~A-1~~ | ~~**Meaning-mode search placeholder**~~ | **SHIPPED 2026-08-31** — PR #1140 (the field) and #1141 (the pre-search prompt beneath it). `SearchMode` gained `fieldPrompt(keywordPrompt:)` and `initialPrompt(scoped:)`; the macOS raw literal is gone. The two members differ deliberately: the field prompt takes the surface's keyword wording as a parameter because the two fields differ on purpose (the Mac window's names the three scopes it searches, whose chips sit ~200 lines below it), while the pre-search prompt owns all four strings because that surface is iOS-only. Both mutation-tested — reverting either wiring turns its test red. 4,196 unit tests in 559 suites; Mac build clean. **Owner check outstanding**, uncovered by any test: that the prompts visibly change on a mode switch. | — |

## 3. Tier B — carried engineering (unblocked today)

| # | Session | Scope | Gate |
|---|---|---|---|
| ~~B-1~~ | **COMPLETE 2026-09-01.** W-13 coverage map / systematic-review mode | **Both sources this row originally named are refuted**, as the Tier-E assessment predicted: `ExportHistoryEntry` records a `documentCount` and no identities, and `ProjectEngagedDocuments.keys` unions visits, notes and collection entries into one flat set. **Session 1** (PR #1172) built `DocumentEngagementService` over the three real numerators, gathered apart and intersected with the corpus, plus row badges and the coverage line in `CorpusDocumentsView`. **Session 2** (PR #1173) added the exportable statement to **all three renderers** and a Project Home tile per searched corpus. **The denominator was the session's real problem and its answer is the row's lasting finding:** a `WorkingCorpus` carries no project identifier and `Project` carries no corpus reference, so "this project's corpora" does not exist in this schema — but `SearchHistoryEntry.appliedCorpusId` is the one record holding a corpus id and a project id together, so the universe is *the corpora this project searched inside*, read out of the log the appendix already is. That is also exactly the searched→examined bridge the row asked for. Three further findings: `preambleLines` is **not** shared (private, CSV-only — Markdown and plain text hand-build their own headers, so a fact added there ships in one format and vanishes from the collection PDF); the **denominator can itself be a floor**, so a truncated capture discloses it; and the block names the population it counted. 23 mutations killed across the two sessions. No schema change, as forecast. | — |
| B-2 | **DEFERRED 2026-09-01 (owner).** Purely additive and nothing depends on it; the only row here with no research argument behind it. Not removed — revisit after the App Store push. W-14 read-aloud | Unchanged: `AVSpeechSynthesizer` over the render tree — skip footnotes, track position, honor the read-vs-research split. Purely additive. | none |
| ~~B-3~~ | ~~**W-3 §7 remainders**~~ | **Struck 2026-08-31 — folded into Tier A §2a.** `Visual-Marketing-Plan.md` reconciles against `Map-Figure-Export-And-Visual-Outputs.md` §7–§9 and supersedes this row's scope. The four items it named (word-cloud drift harness, splash lens, marketing plates, extra lenses) are governed there now; scope sessions out of that plan's §7, not out of this row. | — |
| B-4 | **SPLIT 2026-09-01 (owner): the measurement is KEPT, the sitting is DEFERRED.** The encoder's in-app Metal footprint is an unmeasured number that needs no owner time — take it. The second sitting over the shipped Meaning pipeline waits for build-44 tester feedback, which is what would sharpen its rubric. V-5 residue: the supplementary sitting | The shipped Meaning surfaces have never been judged the way the first 25 queries were: a second owner sitting over the SHIPPED pipeline (hybrid page + fallback), reusing the standing harness and rubric — sharpened by whatever build-44 testers report. Also the small unmeasured number: the encoder's Metal in-app footprint on a device/attended Mac run (the CPU shape measured 141→349→393→140 MB; the CLI ceiling 639–861 MB bounds Metal). | owner appetite; tester feedback helps |
| B-5 | **HALF SHIPPED 2026-09-01 (PR #1176); the walkthrough is the owner's.** W-8 residue: the two June leftovers | **Enclosure dual-home rendering is built.** Finding 4's claim measured first, because the row said "small" and nothing about whether it mattered: at the classifier's own gate — **which is `year < 1906`, not the pre-1910 this row and the research both say** — 12,293 documents carry an enclosure and 19,243 enclosures print a dateline differing from their parent's. Shipped **without an index bump**: the enclosure's dateline is nowhere in `document_cache`, but the app-wide `DocumentASTCache` already holds the open document's AST, so the Source Explorer reads it there (cache-hit-else-parse). **Narrowed on measurement**: only 5,876 of 23,296 dateline-bearing enclosures name their own institution, so the rest would have placed by borrowing the parent's chapter country and then been labelled "Enclosure" — a parent-derived guess wearing an enclosure's name. `chapterCountry: nil` is the refusal lever. Ten mutations killed. **The live UI walkthrough of the pre-1910 classifier surfaces on both platforms remains, and is the owner's** — it is what would confirm the composition of a two-home document on screen, which no test here does. | none |

## 3a. Newly filed — 2026-09-01

Two defects found during the visual-marketing wave, recorded in code comments and in the plan's
§10 but never given a row. Both are **owner decisions before any code**, which is why they sat
unfiled; filing them is what stops "recorded somewhere" from meaning "lost".

| # | Session | Scope | Gate |
|---|---|---|---|
| B-6 | **The blank relaunch window** | `.indexingBackdrop` is a suppression verdict **nothing renders**. With a download QUEUED but no batch started, `ContentView` withholds the splash and `MainTabView` never mounts the strip, so a relaunch mid-download shows nothing at all. `CloudSurfaceArbiterTests.relaunchMidDownloadPrefersIndexing` passes while the screen is blank, and now says so in its doc comment. **Not a drive-by**: the fix needs a product decision (a queued-download banner, or let the splash through?) *and* a banner state that does not exist — `IndexingQueueBannerView` needs a `batch.latest`, and in that window there is no batch. | **owner decision** |
| B-7 | **Differentiate Without Color on the map** | `accessibilityDifferentiateWithoutColor` appears nowhere under `Semantic/`, while `WordCloudView` honours it with a documented rationale on a surface far *less* colour-dependent. The map's cluster lens is an even hue sweep and its provenance lens a ten-hue legend, so colour is load-bearing. Closing it needs a **second channel** — shape, or a labelled sub-selection — which is a design question, not a contract to state. M-2 stated the Reduce Motion and Reduce Transparency positions and deliberately left this one open rather than half-answering it. | **owner design decision** |

## 3b. Standing readiness — the next OH release *(filed 2026-09-01)*

The Office of the Historian intends to publish before the end of the year, and a new volume is a
**release**, not a manifest row: 18 corpus-derived bundled artifacts, an owner-run harvest on a
second machine, a shard pushed to a different repository, and ten strings of user-visible copy that
hard-code `552`. Scoped in full — inventory, run order, traps, decisions, effort — in
`New-Volume-Release-Plan.md`.

| # | Session | Scope | Gate |
|---|---|---|---|
| R-1 | **The volume-release runbook** | The plan's §10, executed when the volumes land. Shaped by the 2026-09-02 decisions: map rebuilt every release (D-2), enrichment deferrable (D-4), **one release per volume** (D-5) — so §12's minimum-viable path is the expected shape. | **OH publication** |
| ~~R-2~~ | **SHIPPED 2026-09-02 (PR #1177).** The harvest-contract guard (plan §4.2, W-1) | Three guards, not the one-or-the-other the plan offered. **Harvester:** a resume under a changed `model` / GGUF SHA / `prefix` / `chunk_chars` / `overlap_chars` exits non-zero naming the field (`ALLOW_CONTRACT_CHANGE=1` overrides). **Packer:** `EXPECT_DIGEST` refuses to write under any other provenance digest, before a directory is created. **Store:** every new `head.json` records the contract so `pooledDocuments` checks it per volume — impossible before, since a head carried only `model` and `dim`; the 552 shipped heads predate it and are trusted. The GGUF is hashed at startup, the one check that can tell an operator they loaded a different file at the same path. 20 selftest checks through the real `main()`, 62 Swift tests with the digest test driving the real `run()`, eleven mutations killed — two of which first survived because the selftest was testing its own mock. | — |
| ~~R-3~~ | **SHIPPED 2026-09-02 (PR #1178).** The `552` literals (plan §7.1, W-2) | All nine derive: the catalog count from the manifest, the four ratios from the artifacts' own coverage fields. **One was already stale**: the collections card's "reaches 356" had been 365 since the authority's 2026-08-19 re-clustering, and a source-scan test pinned the stale value as measured. Seven mutations killed; the one it cannot catch — a literal passed as an *argument* in an undriven SwiftUI body — is recorded, not hidden. | — |
| ~~R-4~~ | **DECIDED 2026-09-02 (D-1): leave the gap silent.** `newlyAvailable` stays unconsumed; the owner will prioritise the release runbook so the gap is minimal. The only residue is the doc comment that claims a badge renders it — it should stop claiming one (release plan §13). | — |
| R-5 | **P1 SHIPPED 2026-09-03 (PR #1179); P2 SHIPPED 2026-09-03 (PR #1180 — say it: hub section, Research filter over six sources, one shared banner); P3 remains.** Annotation integrity across an OH correction — `Volume-Update-Annotation-Integrity-Design.md` | **Q-1 measured first, and it settled the design**: over the largest post-1960 volume, render-converting every document costs 0.05 s against a 0.50 s parse, so `body_hash` is eager. P1 writes both hashes at index time — `content_hash` over the stored columns, `body_hash` the exact `renderingVersion` highlights carry, pinned against an independent computation — stamps `'body'` / `'apparatus'` / `'vanished'` via one SQL `CASE` upsert, and leaves an identical re-index without a trace. Nine tests through the real `indexVolume`; seven mutations killed, one equivalent (the source note is also in `body_text`). No UI, no `@Model`, no index bump — the table now accumulates truth ahead of the first OH correction, which is the property §6 wanted. **P2 shipped**: `VolumeUpdateReviewSection` in both hubs, a *Changed by an update* row in `ResearchView` over an aggregation widened to `GeneratedSummary` + `ArchiveVisitDocument`, and `DocumentChangeBanner` replacing the twins' two identical banners with one seven-cell truth table; plus the `onVolumeDownloaded` AST-cache fix. **P3** (fix it: confirm / unique-match re-anchor / delete; `reviewed_at` stamping) is next. | none for P3 beyond Q-5's note in the design |

## 4. Tier C — assessments (each ends with a build/no-build recommendation)

| # | Session | Scope | Gate |
|---|---|---|---|
| C-1 | **KEEP.** The last startable Tier C row. C-2 is the argument for doing it: an assessment that refused P8 outright and corrected a design premise before anyone built on it. W-12 parallel-series concordance — ASSESSMENT | Unchanged from the old plan: DBPO/DDF/AAPD/Dodis/Wilson Center volume-level concordance scoping; document-level alignment stays out. | none |
| ~~C-2~~ | ~~**W-15 geographic analytics — ASSESSMENT**~~ **ASSESSED 2026-09-01**, PR #1170 — `W15-Geographic-Analytics-Assessment-2026-09-01.md`. **P10 BUILD but renamed** (a *document-origin* table, not "country attention"); **P8 DO NOT BUILD from place mentions** — Washington is 46.9% of all dateline geography; **P11 and P12 CLOSE as already delivered**, which the plan describes as postponed. The recon's "few hundred rows" premise survives only with a normalisation step it did not identify: keyed on raw surface a 300-row table reaches 90.0%, keyed on the normalised head 96.4%. | — |
| C-3 | **DEFERRED by its own gate**, not by choice — it cannot start until the SDK is available. W-10 OS-27 adoption — assessment against the actual SDK | Unchanged; first session is assessment-against-the-beta, not a build. | SDK availability |

## 4a. Tier D — vacated *(2026-08-31)*

The agentic-loop wave W-19 that sat here was **promoted to Tier A, §2b**. Nothing else was ever
filed under Tier D, so the tier is vacated rather than emptied. `Agentic-Loop-Development-Plan.md`'s
own status line said "Tier D" and was repointed to Tier A §2b in the same commit as this revision.

## 4b. Deferred — #234, the NER scoring lane *(deferred 2026-08-31)*

Deferred because the harvest will not finish this week, **not** because the question changed. The
framing survives intact: the sweep was never the scoring gate's input, so the verdict decides
whether its output is used, not whether to spend the compute. Reactivate the whole block when the
owner says the stores exist — the rows below are unedited apart from this note, so reactivation is
a move, not a rewrite.

**N-0 does not sit here.** The M2a span sitting is owner work that does not wait on the machine,
it is the gate every row below is refused without, and it stays live in the owner lane (§5).

| # | Session | Scope | Gate |
|---|---|---|---|
| N-1 | **Score the harvest** | When the stores exist: run `score_detections.py` over the Qwen3-14B store, the `EarlyEraNERControl` (NLTagger) store, and the editors'-markup baseline, against the keyed gold — same scorer, same documents, maximum-cardinality matching. Deliverable: the three-way table and the verdict on the question the scorer was designed for (`NER-RUNBOOK.md` §6–7) — *does the model beat the free option by enough to justify its cost?* — under `People-Early-Era-Program.md` §5's own binding constraint, which is prior: eval set first, nothing ships until M2a is keyed *(citation repointed 2026-08-29, §7 — §5 states the keying gate, not the comparison question)*. Record whatever the answer is; a control win is a finding, not a failure. Guard rails already in the tools: a store that sampled without `sampled_doc_ids` is refused; gold re-verified against the text layer before any detector is read. | N-0 + the stores |
| N-2 | **The verdict's consequences** | Branches on N-1, both pre-scoped: **detector wins** → design the ingestion (how detected early-era mentions reach the people browser #234 asks to extend — index shape, confidence display, the "detected, not editorial" disclosure the program mandates); **control/baseline wins** → the same browser extension built on the editors' markup + NLTagger at zero model cost, and the sweep output archived as a measured negative. Either branch ends with a build plan for the browser extension itself. | N-1 |
| N-3 | **W-7a, if a re-run is ever wanted** | The harness additions (`ONLY_DOCUMENTS` + `WORKERS`, both shapes settled by the Swift control and the #1083 probe). Needed only if N-1's verdict demands scoped re-runs of other models. Do not build ahead of that need. | an N-1 outcome that wants more models |

## 4c. Disposition sweep — 2026-09-01

Every remaining session was put to the owner for keep / defer / remove. The results are written
into the rows above; this is the summary and the resulting order.

| Decision | Rows |
|---|---|
| **KEEP** | B-1 (W-13 coverage map), B-5 (W-8 residue), C-1 (W-12 assessment), B-4's *measurement* half, and **M-4 pulled forward** |
| **DEFERRED** | B-2 (W-14 read-aloud), B-4's *sitting* half, **P10**, C-3 (by its own SDK gate) |
| **REMOVED** | none |
| **NEWLY FILED** | B-6, B-7 (§3a) |

**M-4 was built BEFORE capture, reversing the plan's own schedule** — an owner decision made with the trade stated, and it paid. The plan put it at step 14 because it changes the App Preview's opening frame; building first meant one capture pass. It also found two defects that would have been shot into the store assets: on the frame the App Preview opens on, the lens chip named the wrong lens three launches in four, and the identity block's protected rect sat 62 pt from the block. The `push` re-clamp bug the row required did ship with it — and turned out to be the least consequential of the three, because the field's own expansion opens a void around a centred zone before drift's 14 pt excursion applies.

**P10 is deferred to the next index bump rather than scheduled.** `currentDateIndexVersion` is 47
and P10 needs 48, which is a full re-index for every user; the plan already treats bumps as batched
events with a passenger list. Its step 1 is owner curation of the top 300 normalised toponym heads
and is unblocked by code whenever the owner wants it — the measurement in
`W15-Geographic-Analytics-Assessment-2026-09-01.md` §2 is the input.

**Suggested order for the engineering rows**: M-4 first (it gates a capture pass the owner is
mid-way through), then B-1, then B-5, then C-1. B-4's measurement folds into any of them.

## 5. The owner lane

| Item | Feeds |
|---|---|
| **Build 44**: the VoiceOver pass and the App Store Connect archive-and-upload (tag `build-44` is set; What-to-Test texts are paste-ready and under the 4,000-character limit) | release |
| **The M2a span sitting** (N-0) — the one thing on #234's critical path, and *(2026-08-31)* **the only #234 item still live** now that the scoring lane is deferred to §4b. Key the 72 staged gold documents (`~/frus-m2a` on the Studio; `stage_m2a.py` is SEED-pinned at 234, so a local re-stage is deterministic). The scorer refuses every detector without it, so doing it now is what makes reactivation cheap rather than blocking. The M1a identity CSV (0/300) rides the same sitting if convenient but does not gate scoring. | unblocks §4b |
| **The custom EULA paste** before any App Store (not TestFlight) submission of build 44+: fill four placeholders in `semantic-vectors/App-Store-Custom-EULA.md`, paste into App Information ▸ License Agreement | App Store review |
| Screenshot captures — #1081's 13 live placeholders, via the staged four-sitting shot list (`Docs/screenshots/SHOT-LIST-2026-08.md`, W-2e). *Refined 2026-08-29, §7:* the list already covers the visit-plan packet (shot A10, the two claim lists); what build 44 staled is **Meaning search, which has no shot at all** — add its shots to the sweep (the mode strip, the beyond-library row, the model offer) or log the gap on #1081 before capturing | #1081 |
| Release habits: `check_repository_links.py --stamp` each release; eyeball the 3 owner-asserted URLs (JFK ×2, LBJ) | each release |
| Gemma recurring check (runbook §6): at each release carrying the encoder, re-read the PUP's last-modified date and re-run the Apache-relicensing escape-hatch check | compliance |
| **Optional CSUserQuery re-run with Apple Intelligence verified ON** *(recovered 2026-08-29, §7)* — the caveat the W-9 step-1 verdict itself records: the eval machine's setting was unconfirmed, and one re-run with it ON would harden the eight-zero-queries finding. Only if the owner wants the record hardened; the verdict stands either way | closes the step-1 record |

## 6. Standing records

Open issues: **#234** (deferred, §4b — its owner gate N-0 stays live in §5), **#1081** (owner
screenshots) — verified 2026-08-29 as the only two open. Everything else the 2026-08-23 plan scheduled is shipped and struck in that
document, which carries the per-row evidence — except two residues its struck rows still
name, now carried here rather than lost (B-5; the owner-lane CSUserQuery re-run).
The Gemma compliance state lives in `semantic-vectors/Gemma-Compliance-Runbook.md` (all
in-app/in-repo conditions DONE; §5 ASC EULA owner-only). The V-5 program's measurement
record lives in `semantic-vectors/` (the judged sitting, the four-route comparison, the
encoder acceptance fixture) and is the baseline any future retrieval work argues against.

## 7. Review — 2026-08-29, the day after

A claim-by-claim verification of this document against the tree, the tags, the tester
notes, and the issue tracker, run one day after it was written. The method was the one
this repo's measurement records use: no claim taken from memory or from a neighboring
document when a primary source could answer — the string in the source file, the tag on
the remote, the character count of the file itself. **The plan held up: of some twenty
distinct checks, two claims needed correction, two residues had leaked, and one row needed
sharpening; everything else verified true.** The corrections, the recoveries, and the
sharpening are all edited in place above, each marked *(…2026-08-29, §7)*.

### What was verified and held

- **The supersession accounting.** `Completed/Plan-Of-Record-2026-08-23.md` exists; its
  Tier A and Tier B rows are all struck (W-1, W-1b, W-18, W-2, W-3, W-6; W-4+W-5 one PR);
  Tier C is closed except W-7/W-7a, which are this plan's N-0…N-3; W-8 is struck with the
  residue B-5 now carries; Tier D's W-9 row records steps 1–4 all decided/shipped plus the
  hybrid page — "FAR past its written scope" is fair; Tier E shipped W-11 (struck, one
  session), W-16 (delete arm), W-17 (three sessions + the judged sitting), leaving exactly
  the four this plan carries: W-13→B-1, W-14→B-2, W-12→C-1, W-15→C-2. W-18 is rightly
  absent here — delivered 2026-08-26 as the Archive Visits Phase 1 pointed-at channel, per
  the old plan's own struck row.
- **The tag.** `build-44` exists on the remote at `c47a9d48` (the #1130 merge), annotated.
- **The Meaning verdict ask.** Verbatim in both build-44 notes: "Do the top matches
  deserve opening? **This is the verdict we most need.**"
- **The map's pre-decided consequence.** `Completed/Browse-Axes-Development-Plan.md` line
  167: "If the eventual verdict demotes the map, removing the tile remains one clean
  commit."
- **Tier A's tooling facts.** `harvest_ner.py` contains neither `ONLY_DOCUMENTS` nor
  `WORKERS` (the W-7a additions remain unbuilt); its `FULL_SWEEP=1` route writes
  `"sampled": false` with `sampled_doc_ids: null` — "for a full volume the answer is 'all
  of them'" — so the weekend store is indeed scoreable over any gold documents inside the
  volumes it covers. `stage_m2a.py` is SEED-pinned (default 234) with DOCS default 72.
  The M1a identity CSV is 300 rows, 0 keyed (`early-era-people/m1a-eval-candidates.csv`).
- **Tier B's premises.** `ExportHistoryEntry` is in the CloudKit inventory and
  `ProjectEngagedDocuments` exists (B-1's "no schema change" is plausible on those two);
  B-3's four items are exactly `Map-Figure-Export-And-Visual-Outputs.md` §7.1–7.4 (the
  "drift harness" is §7.4's `WordCloudDriftField`/`WordCloudDriftCanvas` animation);
  B-4's memory figures are verbatim from the record — 141→349→393→140 MB is the s2
  CPU-shape acceptance, 639–861 MB is the step-4 spike's Metal CLI run, and the 25-query
  file has exactly 25 queries.
- **Tier C's rows** match the old plan's W-12/W-15/W-10 scope statements word for word
  where they claim to be unchanged.
- **The owner lane.** #1131's own record: "the owner's VoiceOver pass and the App Store
  Connect archive-and-upload remain owner-only." The What-to-Test files measure 3,940
  (iOS) and 3,986 (Mac) characters — both under 4,000, the Mac one by fourteen.
  `App-Store-Custom-EULA.md` carries exactly four bracketed placeholders (mailing
  address, telephone, support email, state/country). The shot list's own §"After the
  sweep" names the 13 `[SCREENSHOT: …]` placeholders. `Scripts/check_repository_links.py`
  supports `--stamp`, and the three owner-asserted URLs are `jfklibrary.org` ×2 +
  `discoverlbj.org` — JFK ×2, LBJ, as written. Gemma runbook §6 is the recurring
  obligation exactly as the row states (PUP last-modified re-read, §0 escape hatch folded
  into the same ritual).
- **Standing records.** The tracker holds exactly two open issues, #234 and #1081.

### What was corrected (edited in place above)

1. **Gate 1 misattributed the second verdict.** It said the What-to-Test notes put both
   verdicts to testers; build 44's notes ask only the Meaning question. The
   clusters/leads-or-noise ask ("Coherent research leads, or arbitrary piles? This is the
   leads-or-noise verdict we most need") was build **43**'s notes — the build-44 rewrite,
   which baselines against 43, dropped it. The verdict is still outstanding but nobody is
   currently being asked; the gate now says so and names the follow-up (restore the ask in
   the next build's notes if the 43 cohort stays silent).
2. **N-1 cited the wrong document for the comparison question.**
   `People-Early-Era-Program.md` §5 is "Constraints carried forward" — its binding gate is
   *eval set first / nothing ships until M2a is keyed*. The "does the model beat the free
   option" question is the scorer's design brief (`NER-RUNBOOK.md` §6–7, and the
   `stage_m2a.py` header). The row now cites both, each for what it actually says.

### What had leaked (recovered above)

3. **The two June W-8 leftovers** — enclosure dual-home rendering and the live UI
   walkthrough of the pre-1910 classifier surfaces — were recorded inside the old plan's
   *struck* W-8 row ("Left of this row: only…") and appeared nowhere in this plan. No open
   issue tracks them. Now Tier B row B-5.
4. **The optional CSUserQuery re-run** with Apple Intelligence verified ON — a caveat the
   W-9 step-1 verdict itself records as the one thing that would harden it — was in the
   old plan's "what remains is owner-lane" clause and was not carried. Now an owner-lane
   row, marked optional.

One row was sharpened rather than corrected: the screenshots line said build 44's
"Meaning/visit-plan surfaces" further staled #1081, but the staged shot list already
covers the visit-plan packet (shot A10, the two claim lists); the genuinely uncovered
surface is Meaning search — zero mentions in the shot list. The row now says which.

### What the review deliberately did not change

The tier order and every gate. In particular it did not second-guess the two standing
gates: the Studio harvest stays untouched and undated (nothing here assumes its
completion), and no row was promoted on the strength of this review — a verification is
not a verdict. The Tier C assessments stay assessments. The owner-lane items stay
owner-only. And the review adds no new work beyond the two recovered residues, which were
already commitments — recorded once, in rows that were struck around them.

## 8. Re-prioritisation — 2026-08-31

**Cause:** the owner reports the Qwen3-14B NER harvest will not finish this week. Tier A was
#234 solely because the Studio was mid-sweep, so the tier had to move.

**What changed, and nothing more:**

1. **#234's scoring lane deferred** to §4b — N-1, N-2, N-3 moved *unedited*, so reactivation is
   a move rather than a rewrite. The framing was re-checked and survives: the sweep was never
   the gate's input.
2. **N-0 stays live** in the owner lane, per the owner's instruction to defer everything except
   the seeding annotation. It is owner work that does not wait on the machine, and it is the
   gate every deferred row is refused without — so doing it now is what makes §4b cheap to
   restart.
3. **Tier A is now two programs**, both already written and verified, both gated on nothing:
   `Visual-Marketing-Plan.md` (§2a) and the agentic-loop wave W-19 (§2b, promoted from Tier D).
4. **B-3 struck**, folded into §2a — `Visual-Marketing-Plan.md` reconciles against
   `Map-Figure-Export-And-Visual-Outputs.md` §7–§9 and supersedes that row's scope. Two plan
   documents pointing at the same four items is how a backlog gets done twice or not at all.
5. **Tier D vacated** (§4a), and the stale "Tier D" placement line in
   `Agentic-Loop-Development-Plan.md` repointed in the same commit.
6. **One new row, A-1** (§2c): the Meaning-mode search placeholder.

**Verified against the tree while writing this, not taken from the plans:**

- `SearchMode` is `FRUSExplorer/Search/SearchModels.swift:45`, cases `.keywords` / `.meaning`,
  already carrying a localized `label`. Per-session and deliberately not persisted.
- The iOS prompt is `SearchView.swift:404` — `String(localized: "search.keywords.placeholder",
  defaultValue: "Keywords…")`, static, the file's only use of that key.
- The macOS prompt is `SearchSheet.swift:629` — `TextField("Search documents, notes,
  summaries…", …)`, a **raw string literal**. A-1 therefore also closes a localization-convention
  violation, which is worth knowing before someone scopes it as a one-line change.
- Both plans promoted into Tier A exist and are current: `Visual-Marketing-Plan.md` (452 lines,
  §§1–9) and `Agentic-Loop-Development-Plan.md` (195 lines, rows L-0..L-8).

**What this revision deliberately did not change:** every gate, the Tier B and Tier C rows, the
owner lane apart from N-0's note, and §7 — left untouched so its inline *(…2026-08-29, §7)*
markers stay valid. Deferring #234 is a scheduling decision and not a verdict on it; no row was
promoted on the strength of the deferral beyond the two programs the owner named.

## 9. External design handoff assessed — 2026-08-31

An outside handoff (`Animation-Surfaces-Review`, findings A-1..A-8, six proposed revisions R-1..R-6)
reviewed Tier A §2a's motion items against the shipped animation code and proposed edits to both
Tier A planning documents. **Every claim was verified against the tree before anything was applied.**

**Verdict: partially applied, with amendments.** The handoff's reading of the *code* is good — the
`drift` default and its two call sites, the whole constant table, the house rule, both cloud
predicates, `sourceAlphaBlendFactor`, `Uniforms.alpha` at both sites, and every §7 step number it
cites all check out, and several `Visual-Marketing-Plan.md` §3.2 rows were genuinely wrong. Its
reading of the *plan documents* is where it drifts, which is the reverse of the usual failure.

**Its only claimed defect is REFUTED and no document should acquire its sentence.** "Two drifting
Canvases run at once in the download-queued window" is not reachable: the drifting strip is raised by
its host, `MainTabView.swift:452`'s `} else if let batch = appState.indexingBatch {`, not by
`CloudSurfaceArbiter`, which only decides whether an already-mounted strip draws. In that window the
host is absent and exactly one canvas is on screen. The supporting quotation elides *"During an
indexing run"*, the clause that makes code and comment agree. The proposed fix would instead suppress
the search backdrop for the whole pre-indexing download phase and breaks five test call sites. Full
record in `Visual-Marketing-Plan.md` §10.

**Two real defects it missed, both now recorded.** A genuine double-cloud by *staleness* —
`PendingCloudBackdrop.canShow` is sampled once inside `.task(id: isPending)` and never re-tested, so a
search cloud already up when a batch begins keeps drifting above the strip — is now plan §7 **step 0**.
And its inverse, unclaimed and unrowed: in the queue-only window `.indexingBackdrop` is a suppression
verdict that *nothing renders*, so a relaunch mid-download-before-first-index shows **no cloud at
all** — with a test (`CloudSurfaceArbiterTests.relaunchMidDownloadPrefersIndexing`) that passes while
the screen is blank, because it asserts the arbiter's value rather than what renders.

**What was applied to this document.** The §2a M-3 row's Scope cell **appended to, not replaced** —
the handoff supplied replacement text that would have deleted the cell's §2(a) mutual-exclusion
warning, its one operational fact. A note added to §2a's M-2 row about the Gap 4 / lens-dip
scheduling collision, which the handoff's own scope boundary excluded. Both standing gates, the tier
order, §7 and §8 untouched.

**One hazard for anyone editing either document.** `Visual-Marketing-Plan.md` §3.2 and this
document's §2a **both use M-numbers, for different rows** — §2a's M-1/M-2/M-3 are the store listing /
the export gaps / in-app motion; §3.2's M-1..M-6 are camera transit / reduce-motion / lens dip /
splash drift / seeded lens / decade accumulation. Always qualify as "plan §3.2's M-*n*". The handoff
did not notice and wrote one vocabulary into the other's table.

**The review document is not committed.** The precedent for committing it exists
(`Planning/Cross-Platform-UI-Adversarial-Review/`), but its citation-grade claim does not survive
verification — a refuted headline, an elided quotation, a wrong line cite — and its one piece of
content reaching neither plan was itself wrong. Everything worth keeping now lives in the two plans.
