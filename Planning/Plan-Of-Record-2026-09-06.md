# Plan of record — week of 2026-09-06

**Supersedes `Plan-Of-Record-2026-08-28.md`**, which is two days stale in five specific ways
recorded in §4. Written against the tree at `7b07147c` (build 45 shipped 2026-09-04, index format
version 49).

**What this document is for.** It separates the work that can start today from the work that
cannot, and states the blocker for every row in the second group by name. It was built by reading
all 26 live planning documents and then screening every "startable" claim against the tree and the
session log — 36 candidates, **16 of them cut** as already shipped or genuinely blocked. The cut
list is in §3, because a plan that only lists survivors invites the same re-derivation next week.

---

## §1 — The week's work

Ordered by what a reader of the tree would want fixed first, not by size.

### 1a. Shipped things that do not do what their own design says — DONE 2026-09-06

Seven defects, each landed as its own commit in the PR that carries this plan. Listed here because
the next plan should not re-derive them.

| | What was wrong | Fix |
|---|---|---|
| PV §5 / Q-1 | The export block claimed to carry a parse residual and never did; the session entry asserting otherwise was false the day it was written | `provenance.parseResidual.disclosure`, conditional on an archival-sources block |
| R-5 §8.2 Q-9 | A volume removed and re-downloaded across a parse change was stamped "changed by an update" for every document | `document_revisions.index_version`, bound in both upsert arms |
| V §7 item 1 | `46,234` travelled through two shipped doc comments without the predicate that produced it | Re-measured to **45,030 of 316,839**, predicate stated, plus the axis's **96.7%** reach over it |
| NARA §4 | Five documented `PROJECT_ONLY=1` promises were false — the raw store is gone, and Step 4a's "required" consolidation is now destructive | All five corrected; restoration cost stated |
| NARA 37 units | The "37 file unit gap" was explained as a filter under-returning | Resolved: a NAID-counting artifact over a series NARA re-describes; the two sets are not nested and their union **exceeds** NARA's own count |
| VM refusal 16 | `FrameTimeProbe`'s doc block argued it was *not* `#if DEBUG`-gated. It is | Block rewritten; gate untouched |
| W-19 C-table | The plan owning the C-rows had not recorded C-0b, and its two-by-two did not say which block length each cell measured | C-0b row added; lengths stated |

### 1b. Designed and unbuilt — the semantic cluster

The designs are written and every input is present (`~/frus-semantic-raw`, 2.2 GB). This is the
largest coherent body of work left that needs nobody's permission.

| Row | What | Size |
|---|---|---|
| **S-1** | **V-3 §6.1 item 2** — the semantic axis is generator-only; it never re-scores the other generators' candidates. `RelatedDocumentsEngine.swift:144` | M |
| **S-2** | **V-3 §6.2 / OS-27 §5.5** — Project Leads runs N per-seed engine ranks where one centroid retrieval would do. `ProjectLeadsService.swift:33-39` | M |
| **S-3** | **V-3 §6.2(a) / §7 item 2** — off-index volume-grain leads: *"N strong matches in a volume you don't have"*. A second Tier-1 Hamming scan in `SemanticSimilarityGenerator` | L |
| **S-4** | **Map §7.3** — two more bundled corpus lenses (`allTerms`, `descriptors`). **Read the screen's warning first**: `WordCloudKit/WordCloudLens.swift:84`'s `bundledCloudLenses` is the GENERATOR'S ARTIFACT CONTRACT with six consumers, not the backdrop's cycle | S |

**Reconnoitred 2026-09-06, and three of the four rows did not survive it.** The cluster was scoped
from the designs; reading the code changed the answer for all but one.

- **S-3 — SHIPPED** (PR below). The threshold the design leaves open turns out not to be a
  constant, and that is measured: over 60 anchors the Hamming distance of the axis's own 120th
  neighbour ranges **104–162**, while a random corpus pair sits at median 194 with a **minimum of
  105** — the bands overlap, so any fixed cutoff admits nothing for some anchors and a swathe for
  others. The rule shipped instead is the anchor's own band, taken from a scan that has already
  run. Yield at half a library: a median of **94 documents across 19 volumes**, 0 of 20 anchors
  empty. The scan cap is 4,096 rather than the rerank pool's 800 because at a **10% library** —
  the reader this exists for — the median rises to 732 and an 800-cap would bind on **43%** of
  anchors.
- **S-1 — RECOMMENDED AGAINST.** The axis is generator-only by construction, not by omission:
  making it a scorer needs a weight it does not have (it ships at 0, so the re-score would
  contribute nothing until a reader moves the slider) and a zero it does not have either — cosine
  has no natural zero, so every candidate any other axis produced would receive a non-zero
  semantic score, changing the default ranking of every existing user.
- **S-2 — BLOCKED ON A MEASUREMENT, not on effort.** A centroid over a project's seeds is only
  cheaper if the seeds are homogeneous; for a heterogeneous project the centroid retrieves the
  average of unlike things, which is nothing in particular. The `RecomputeCost` figure has to come
  first.
- **S-4 — PARKED, WIP on `claude/s4-two-more-corpus-lenses`.** The loader half builds; there is no
  consumer for it, and the artifact contract warning on `bundledCloudLenses` is the reason to stop
  rather than push through.

### 1c. Provenance and archival residue

| Row | What | Size |
|---|---|---|
| **P-1** | **PV-3's three MIXED sections** — per-row provenance chips for the Source Explorer sections that are mixed per row. Both twins (`SourceExplorerView` + `MacSourceExplorerView`) | M |
| **P-2** | **NARA streaming shard write** — 18.5 GB peak; `DEPTH=all` cannot finish. One change across three sites, starting at `RecordGroupCatalogWriter.swift:98-103` | M |

### 1d. Assessments and measurements owed

| Row | What | Size |
|---|---|---|
| **A-1** | **C-1 / Tier-E W-12** — the parallel-series concordance assessment (DBPO/DDF/AAPD/Dodis/Wilson Center). The 2026-08-28 plan calls it "the last startable Tier C row"; model it on the W-15 assessment | M |
| **A-2** | **B-4 measurement half** — the query encoder's in-app Metal footprint. The obvious route has two documented obstacles and one broken command; read the screen note before starting | S |
| **A-3** | **VM §3.2 M-6** — measure the in-app decade-accumulation cost, then scope or refuse it. Needs a small DEBUG driver first: there is no in-app decade-stepping affordance | M |

### 1e. Release readiness, startable before the volumes exist

Both de-risk R-1 without an Office of the Historian publication.

| Row | What | Size |
|---|---|---|
| **R-1a** | **NVR §13** — what a *corrected* volume does to the artifacts. Pure code reading today: the re-download → re-index chain from `VolumesStorageHubView.updateVolume` and its Mac twin | S–M |
| **R-1b** | **NVR §13's open code question** — whether any persisted user state names a semantic cluster id, which §4.5 flags as a relayout hazard. A grep over the SwiftData models and `SyncedPreferences` | S |

### 1f. One that reduces the owner's own queue

| Row | What | Size |
|---|---|---|
| **F-1** | **VM §7 step 11** — finish the film: crop the dead width, cut a subtitle track from `frames.csv`. **No re-render needed** — all 553 post-#1166 frames are already at `~/Desktop/frus-map-film/` | M |

---

## §2 — The owner lane, with the blocker named

Not a backlog. Each of these is blocked on something only the owner can supply, and the plan is
more useful for saying which.

| Row | Blocked by |
|---|---|
| M-1 — store listing GATE A | The four EULA placeholders (address, telephone, support email, governing law) and the App Store Connect privacy nutrition label. *Note: the old plan's "still no `.xcprivacy` in the repo" is false since PR #1191* |
| The capture programme (§7 steps 5, 10–16) | House rule: the owner captures all screenshots and recordings; the plates are a UI export the owner presses. `Planning/Capture-Runbook.md` is the afternoon written down |
| M-3 / M-4 residue, B-5 residue | A composition verdict on a live device and a Mac window. Not a test assertion |
| A-1 (Meaning-mode prompts) | An on-screen check the row itself assigns to the owner |
| B-2 — W-14 read-aloud | Owner deferral, 2026-09-01, with an explicit revisit point: "after the App Store push" |
| B-4 sitting half | Owner appetite plus the outstanding build-44/45 tester verdict |
| B-7 — Differentiate Without Color on the map | A design decision: which second channel carries the encoding |
| R-1 / NVR §10 | The Office of the Historian has not published. The volumes do not exist anywhere |
| N-0 → N-1 → N-2 → N-3 (#234) | The M2a annotation sitting: a human reading 72 documents. Everything downstream is gated on it, and **N-3 is refused by name until N-1 returns a verdict** |
| P10 — place_mentions | Owner curation of the top-300 toponym heads. *Note: the old plan defers it to "the next index bump"; two have shipped since (47→48, 48→49) and it did not ride either* |
| #1081 screenshots, VoiceOver pass, archive-and-upload, launch territories, Gemma check | Owner-only by house rule or by App Store Connect |
| C-3 — OS-27 adoption | An input that does not exist here: no Xcode 27 beta SDK on this machine |
| NARA catalog refresh | Diagnosed and terminated: the S3 listing shows the shipped artifacts derive from a snapshot a refresh would not reproduce |

---

## §3 — What the survey cut, and why

Recorded so next week's survey does not re-propose them. Sixteen of thirty-six candidates:

- **Already shipped**: the M2a 72-document staging (2026-08-25); wave PV in full (PRs #1210–#1219);
  the `.xcprivacy` half of M-1; R-4's badge residue.
- **Decided against, and reversing is the owner's call**: `V §6.3` (three unbuilt map colour
  lenses), `W-17`'s Similar Wording re-argument.
- **Blocked on an owner verdict the design doc does not mention**: `V §7 item 3` (cluster-share
  analytics), `V §7 item 5` (subject-tag denoising), `Map §7.4` (word-cloud animation).
- **Blocked on an owner decision the document itself flags**: the VM batch route and the figure
  filename stamp — §6's lead sentence is *"No draft answered where the output goes"*.
- **Blocked on a CloudKit Production deploy**: `R-5 §8.2 Q-6` (the absent
  `CD_AnnotationReview.CD_annotationId` writer).
- **Refused by the plan itself**: `W-7a` both halves, which row N-3 forbids building ahead of N-1.
- **Terminated by its own diagnostic**: the NARA catalog refresh.
- **Owner action, not owner review**: the repository link check's three owner-asserted URLs; the
  Archive Visit "Seeded from…" caption; M1b's identity reconciliation.

---

## §4 — How `Plan-Of-Record-2026-08-28.md` had gone stale

Five findings, each verified against the tree rather than the document:

1. **§3c's wave PV row shipped whole** and should have been struck — build 45 landed 2026-09-04 and
   PV-0…PV-5 landed 2026-09-05.
2. **§4c's reason for deferring P10 no longer holds.** It defers to "the next index bump"; two have
   shipped since (47→48 in #1223, 48→49 in #1225) and P10 rode neither.
3. **§2a's M-1 says "still no `.xcprivacy` in the repo".** False since PR #1191.
4. **§3b's R-4 residue is closed** (PR #1191).
5. **No rows for the 2026-09-05/06 issue wave** (#1201–#1208); all eight are closed. The tracker now
   holds exactly two open issues, **#234** and **#1081**, both owner-gated.

Also carried forward, since no row tracked it: `Agentic-Guide-Revisions-2026-09-04.md` **Part 2 —
the research skill — is deferred by owner decision** "until there is more usage to test a skill
against".

## §5 — Sources

Built from all 26 documents in `Planning/`, cross-checked against `Planning/DEVELOPMENT-PLAN.md`
and `git log`. The screening pass that cut 16 of 36 candidates is what makes §2 and §3 worth
trusting; its method — generate the candidate list, then verify each claim against the tree before
trusting it — is the discipline `Planning/Agentic-Harness-Runbook.md` §8 applies to workflow
scripts, used here on a survey instead.
