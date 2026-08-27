# Completed plans

Plans, scopes, audits, and handoffs whose work is **shipped, closed, or superseded** — moved
here 2026-08-05 so `Planning/` holds only live documents. Nothing was edited in the move; some
files carry status lines that predate their own completion (e.g. `Collections-Authoring-Scope`
says "no implementation started" — the shipped code says otherwise). Where a completed document
left residual work, that work is tracked in GitHub issues or in
the live plan of record (currently `../Plan-Of-Record-2026-08-23.md`), not here.

**What lives here, by cluster:**

- **The 2026-08-17 consolidation (16 files)** — every plan, review and assessment archived when
  `Plan-Of-Record-2026-08-17.md` (now archived here too) became the single live plan after the build-42 TestFlight
  release. Its §8 records where each document's live residue went. The set: the consolidated and
  resolve-open-issues plans, the eight-issue plan, the feature-priorities review, the three Q&CA
  documents, the restoration-depth design (#754; its deferred §B/§C are pointed at from the live
  plan), the lexical-similarity assessment (withdrawn-as-artifact), the #645 pool-depth
  measurement, the analytics big-picture blueprint, the 2026-05 pre-index feasibility, the
  cross-platform porting assessment, the Dynamic Type worklist, and the two Archival Analytics
  feature documents (feasibility + design handoff) — the feature shipped; its open remainders are
  tracked on `../Archival-Analytics-Adversarial-Review.md` and issues #825/#830–#838.

- **`Plan-Of-Record-2026-08-17.md` (moved 2026-08-23)** — the discharged plan itself: every
  session row S-1…S-8 shipped (its struck tables carry the per-row PR evidence), superseded by
  `../Plan-Of-Record-2026-08-23.md`, written from the owner's next-wave decision.

- **The 2026-08-23 post-wave retirement (16 artifacts)** — moved when the issue-and-planning
  audit found every Plan-of-Record session row discharged. The archival-analytics wave closed
  (`Archival-Analytics-Adversarial-Review.md` — every tracked issue #825–#838 closed —
  and its `Archival-Analytics-Revision-Design-Handoff/` artboards); the research trip packet
  shipped and #830 closed (`Research-Trip-Packet-Scope.md` v1.4 + `Research-Trip-Packet-
  T0-Prereqs.md` with the D1–D21 decisions ledger — chapter 6's transcription deposits stay
  live in `../reference/`); Wave R finished (`Wave-R-Research-Trail-2026-08.md` — R-2b shipped
  in PR #981 with NO Production deploy, since a removal is not a deploy); the subjects program
  completed (`308-Subject-Integration-Design.md` — #308/#261 closed — and
  `Subjects-Followup-Plan-2026-08.md` — #1019–#1030 all closed); #751's evidence and design
  records closed with it (`Navigation-State-Audit-2026-08.md`, `iOS-Reading-Journey-Design.md`
  — O-3's settlement stays recorded in the latter's §3b); the executed-in-June pre-1910 plan
  (`BigPicture-Pre1910-CentralFiles.md` + `Pre1910-CentralFiles-Reference-Data.md` — the
  harvest ran, schema-3 index committed, classifier live; the un-harvested Phase-3 tail series
  remain registered as `SURVEY_SERIES` targets in CLAUDE.md); the discharged lot runbook
  (`352-lot-resolution-runbook.md` — its recurring operations live in CLAUDE.md's generator
  entries); and #834's frozen measurement record (`Decimal-Channel-Measurement-2026-08-20.md`
  + its two JSONs — #1014's live instrument is the in-code `MEASURE_DECIMAL=1` harness, which
  mints fresh copies at the Planning root) plus the superseded `external-citations/` sample
  (the current baseline is `../external-citation-sample.json`).

- **The browse-axes program (#1051, 3 files — moved 2026-08-23)** — the program completed
  B-1…B-7 (PRs #1060, #1064–#1069) plus the #1070 regression fix (#1071):
  `Browse-Axes-Development-Plan.md` (the executed plan; its §2 decision register and B-5's
  deferred-with-obligations list remain the record), `Browse-Axes-Design-Requirements.md` (the
  feasibility study, R-1…R-4/A-1…A-9), and `browse-axes-design/` (the Claude Design handoff
  mirror). The B-7 clusters gate was resolved by owner direction — the axis shipped as the
  instrument for the build-42 leads-or-noise verdict; see the live plan's §1 addendum.

- **The W-4/W-5 design records (2 files — written 2026-08-26, shipped the same day)** —
  `W4-Classification-Override-Design.md` (#279: the reversible classification override; the
  owner's restyle-the-body decision; the replay-not-clobber architecture) and
  `W5-Saved-Search-Freshness-Design.md` (#266: the synced count-watermark definition of "new";
  capsule + exact count; `SavedSearch.lastModified`). Written directly here rather than living
  at the Planning root first: each is the O-4/O-5 one-pager the plan of record owed, recorded
  as shipped. The batched CloudKit promotion they board (41 identifiers, with Archive Visits
  Phase 2) remains owed on the live plan's owner ledger.

- **Numbered session plans (01…406)** — the session-by-session build of the app, all delivered.
  Includes the architecture/design records for shipped subsystems
  (`102-DocumentHighlight-Architecture`, `140-147-WebKit-Rendering-Migration`,
  `258-Custom-Volume-Scopes-Design`), completed audits/handoffs (`335`, `369`, `406`), and the
  superseded early backlog (`75-Development-Backlog` — surviving items became issues).
- **Completed workstream plans** — `Onboarding-Glass-Flow-Plan` (O, PRs #525–#540),
  `Analytics-Session-Plan` (Waves A–D), `Research-Rail-Implementation-Plan`,
  `Projects-Enhancement` (#377, Phases 1–5; Phase 6 dropped),
  `Docs-Pass-Plan` (#646), the Collections trilogy
  (`Collections-Rework-Scope` → `Collections-Authoring-Scope` → `Collections-Manager-UX-Scope`),
  `Corpus-Browser-Rework-Plan`, `Source-Explorer-Provenance-Scope` (all five phases),
  `Window-Routing-Provenance` (implemented; still cited by `AppState.swift` as the design
  record), and `Design-Requirements-Query-Analysis-UI` (the design brief — its hand-back's
  binding is the still-live `../QCA-Design-Handoff-Assessment.md`).
- **Closed issue-wave plans** — `Issues-207-219-Remediation-Plan`, `Issues-233-243-Plan`
  (⚠️ `Issues-233-243-Plan` is archived but still holds the **live, unstarted** #234 M1/M2/M3
  early-era people program's reference rules. The program itself moved to
  `Planning/People-Early-Era-Program.md` on 2026-08-07 — being filed here had made it
  invisible for two months.)
  (spawned issues #259–#270), `188-189-Tester-Feedback-Build28-Plan`.
- **Point-in-time audits/evals** — `UI-Audit-2026-07-03`, `People-Browser-Eval-2026-07-03`
  (successor: issue #234), `Source-Explorer-Audit-2026-07-03` (§2.1 still defines the
  `SourceNoteEval` era buckets — the code doc comment points here),
  `Settings-Parity-Audit-2026-07-25` (superseded by Workstream S).
- **Delivered BigPicture programs** — `BigPicture-WordCloud`, `BigPicture-VolumeFrontMatter`,
  `BigPicture-iPadMacParity` (#238 correction tracked via #312), `BigPicture-ZoteroExport`
  (remaining iOS fallback = issue #358).
- **Shipped one-offs** — `future-unnumbered-PDF-DOCX-highlight-annotation` (its unticked manual
  verification checklist is recorded as P5.4 verification debt in the priorities review).

**Deliberately NOT here** (live at `Planning/` root — verified 2026-08-25): the plan of record
(`Plan-Of-Record-2026-08-23`), the log (`DEVELOPMENT-PLAN`), the spec, the open designs and
programs (`Vector-Embeddings-Semantic-Design` — V-0…V-4 shipped, V-5 open;
`OS27-Semantic-Retrieval-Design` (W-10); `Map-Figure-Export-And-Visual-Outputs` (W-3);
`People-Early-Era-Program` + `M2-Semantic-Pipeline-Ride-Along` (#234, W-7)), the live runbook
(`nara-record-group-catalog-runbook`), the cross-platform review package
(`Cross-Platform-UI-Adversarial-Review/`, whose `STATUS.md` is W-2's only tracker), and the
artifact directories that generator defaults and live plans point at (`cross-ref-validation/`,
`nara-record-group-catalog/`, `source-explorer-export/`, `semantic-vectors/`, `semantic-map/`,
`semantic-spike/`, `early-era-people/`, `reference/`, `external-citation-sample.json`).

Everything else this paragraph used to name is now **in this directory**:
`Consolidated-Development-Plan-2026-08`, the lexical-similarity, cross-platform-porting and
PreIndex assessments, `308-Subject-Integration-Design`, `BigPicture-Analytics-CorpusVsSeries`,
`BigPicture-Pre1910-CentralFiles` + its reference data, `352-lot-resolution-runbook`, both QCA
assessments, `Wave-R-Research-Trail-2026-08`, `Eight-Issue-Plan-2026-08`, `Dynamic-Type-Worklist`,
`Archival-Analytics-Adversarial-Review` and the trip-packet scope.
