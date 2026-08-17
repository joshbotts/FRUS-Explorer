# Completed plans

Plans, scopes, audits, and handoffs whose work is **shipped, closed, or superseded** — moved
here 2026-08-05 so `Planning/` holds only live documents. Nothing was edited in the move; some
files carry status lines that predate their own completion (e.g. `Collections-Authoring-Scope`
says "no implementation started" — the shipped code says otherwise). Where a completed document
left residual work, that work is tracked in GitHub issues or in
`../Plan-Of-Record-2026-08-17.md`, not here.

**What lives here, by cluster:**

- **The 2026-08-17 consolidation (16 files)** — every plan, review and assessment archived when
  `../Plan-Of-Record-2026-08-17.md` became the single live plan after the build-42 TestFlight
  release. Its §8 records where each document's live residue went. The set: the consolidated and
  resolve-open-issues plans, the eight-issue plan, the feature-priorities review, the three Q&CA
  documents, the restoration-depth design (#754; its deferred §B/§C are pointed at from the live
  plan), the lexical-similarity assessment (withdrawn-as-artifact), the #645 pool-depth
  measurement, the analytics big-picture blueprint, the 2026-05 pre-index feasibility, the
  cross-platform porting assessment, the Dynamic Type worklist, and the two Archival Analytics
  feature documents (feasibility + design handoff) — the feature shipped; its open remainders are
  tracked on `../Archival-Analytics-Adversarial-Review.md` and issues #825/#830–#838.

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

**Deliberately NOT here** (live at `Planning/` root): the plan of record
(`Consolidated-Development-Plan-2026-08`), the log (`DEVELOPMENT-PLAN`), the spec, the open
designs and assessments (vector embeddings, OS-27, lexical similarity, cross-platform,
PreIndex, `308-Subject-Integration-Design`, `BigPicture-Analytics-CorpusVsSeries`'s postponed
items, `BigPicture-Pre1910-CentralFiles` + its reference data), the live runbooks
(`nara-record-group-catalog-runbook`, `352-lot-resolution-runbook`), the QCA assessments that
still bind the Q tail, `Wave-R-Research-Trail-2026-08` (R-2b), `Eight-Issue-Plan-2026-08`
(documents the held owner decisions), `Dynamic-Type-Worklist` (open deferrals), the current
review and trip-packet scope, and the artifact directories
(`cross-ref-validation/`, `nara-record-group-catalog/`, `source-explorer-export/`,
`reference/`) that generator defaults point at.
