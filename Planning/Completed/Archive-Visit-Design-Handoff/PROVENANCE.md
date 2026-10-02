# Provenance — Archive Visits design (#830 successor)

## Delivered
- `Archive-Visits.dc.html` — nine consolidated artboards (1a–1i), badges top-left, amber dashed
  annotations behind the `showAnnotations` tweak, at the fidelity of
  `Planning/Completed/Archival-Analytics-Revision-Design-Handoff/`.
- `screenshots/` — one capture per artboard.

## Spec
`Planning/Archive-Visit-Design-Handoff/README.md` on `joshbotts/FRUS-Explorer@v2`
(implements Archive-Visit-Plan-Design.md v3, fully decided). Every screen, state, copy rule,
and ●/○ number convention follows that brief.

## Grounding (files read at v2, 2026-08-26)
- `FRUSExplorer/Settings/WorkingCorporaView.swift` — 1a row anatomy, rename alert,
  context-menu order, `rename(to:)` rule, provenance line grammar.
- `FRUSExplorer/Models/WorkingCorpusResolver.swift` — both-numbers coverage grammar (1a, 1b, 1h).
- `FRUSExplorer/TripPacket/RepositoryFactTable.swift` — the ● link labels per facility
  (College Park's three; the D16 pair per library), 11 facilities, VerifiedFact rules.
- `FRUSExplorer/TripPacket/TripPacketModel.swift` — `recordsLine` field order,
  `TripPacketTopicSentence` placeholder + forExport rule (1g).
- `FRUSExplorer/TripPacket/TripPacketSheet.swift` — 1g chrome: plain text first, PDF same string.
- `FRUSExplorer/Collections/CollectionPickerSheet.swift` — 1e picker anatomy.
- `FRUSExplorer/Collections/CollectionEntryInspector.swift` (overridePicker call sites) —
  1d Default/On/Off grammar.
- `Planning/Completed/Archival-Analytics-Revision-Design-Handoff/Archival-Analytics-Revision.dc.html`
  — the artboard visual system, copied into this project as the fidelity reference.

## Numbers
● measured, reused as stated: 11 facilities · 123 divided lots (up to 13 claimant series) ·
≲6% of documents carry external references · ~21 source-note groups per 30 documents
(25 pre-1950, 14 post-1950) · "Untitled Archive Visit" · "%@ copy" · the topic-sentence
placeholder. Everything else is ○ — illustrative, computed at render time, never hard-coded.

---

## Repo-side record (appended on check-in)

**Added to the repo:** 2026-08-26, supplied by the owner as `Archive Visits Design Handoff.zip`.
Contents are **byte-identical to the handoff as delivered** — `Archive-Visits.dc.html`,
`support.js`, the nine artboards under `screenshots/`, and this file's section above. `README.md`
in this directory is the **outgoing brief** the design was produced against, committed before
delivery.

## What governs

`../Archive-Visit-Plan-Design.md` (v3, fully decided) is the plan of record; this folder is the
design record. The check-in assessment lives in that document's **§7b** — verdict: **conforms**,
with three annotation-level flags (a mock-state filter chip, the undrawn plan-delete dialog, an
email-case nit). Where the two ever disagree, the plan governs.

## The `.dc.html` is the copy authority, not the PNGs

Artboard 1b is captured with its info popover open, which occludes part of the summary line and
two filter chips; every occluded string is present in the design file.
