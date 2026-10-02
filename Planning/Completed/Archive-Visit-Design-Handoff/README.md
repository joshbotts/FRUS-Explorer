# Design brief: Archive Visits — the archival research plan (#830 successor)

Implements `Planning/Archive-Visit-Plan-Design.md` (v3, **fully decided** — every §7 decision is
answered), on branch `v2` of `joshbotts/FRUS-Explorer`. This is the **outgoing** brief: it asks
for a design, it does not describe one that exists.

## Overview

FRUS Explorer already turns a set of documents into a research-trip packet, but the packet is
**ephemeral** — built at presentation time from `[(volumeId, documentId)]` and persisting nothing —
and it is reachable only from collection-shaped surfaces. An **Archive Visit** makes it a
persistent, CloudKit-synced object that can be seeded from anywhere a researcher meets archival
provenance, prioritized, filtered, and turned into three narrow deliverables.

**The working grain is the research target, not the document.** A target is an archival unit under
one claim: *drawn from* (the document's own source note) or *pointed at* (its footnote citations
to material FRUS did not print). One document seeding three targets gives three independently
prioritizable rows. Targets are a **state overlay** — a row exists only once the researcher gives
it a tier, a note, or an exclusion; everything else derives at render time.

**The app's job is FRUS, not NARA.** It presents FRUS-derived data in the form most useful for
planning and for consulting an archivist, and points at repository guidance rather than
reproducing it. Four of the packet's seven chapters are gone; three deliverables remain:

- **(a)** repository visit-planning links (already built — 11 facilities in `RepositoryFactTable`)
- **(b)** a repository-filtered, tier-grouped **target list** carrying consultation metadata, where
  each row itemizes its seeding documents with a link and the **verbatim reference context**
- **(c)** a per-repository **inquiry email draft** the researcher edits and sends

## What we need from this design

Artboards for the surfaces in **Screens** below, at the fidelity of the Archival Analytics handoff
(`Planning/Completed/Archival-Analytics-Revision-Design-Handoff/`): one consolidated final state
per surface, badges top-left, amber dashed annotations for implementation notes. Both platforms
where they differ — noted per screen.

## Fidelity

**High-fidelity in structure and copy; native in implementation.** Mirror stock
iOS/iPadOS/macOS SwiftUI chrome — inset-grouped `List` sections, `.bordered`/`.controlSize(.small)`
menu chips, `ContentUnavailableView`, alerts with `TextField` — not hand-tuned pixels. The task on
the far side is to recreate these in SwiftUI using the components named per screen; do not port
markup.

**Number convention.** **●** = measured, reuse as stated. **○** = illustrative; the real value is
computed at render time. **Never hard-code an ○ number.**

**The plain-language rule.** On-screen labels use researcher words; precise definitions,
populations and caveats live in the surface's ⓘ popover (`FeatureInfoButton`). Accessibility
labels may keep precise terminology.

**The honesty rule, which this feature inherits and must not weaken.** Where a figure is partial,
say both numbers. The house grammar is `WorkingCorpusResolver`'s, and its doc comment states why:
*"Always states both numbers, even when complete: '267 of 267' tells a reader the corpus is whole,
where a bare '267 documents' leaves them to wonder whether it was clipped."* An incomplete
coverage line renders **orange**; a complete one secondary.

## Vocabulary

| Concept | On-screen |
|---|---|
| `ArchiveVisitPlan` | **Archive Visit** (list: *Archive Visits*) |
| the verb | **Plan a Visit** / **Add to Archive Visit…** |
| `PlanTarget` | **research target**, or just the unit's own name on screen |
| drawnFrom claim | **drawn from** — "the document was published from this file" |
| pointedAt claim | **pointed at** — "the document's footnotes cite this, unprinted" |
| `PlanTier` | **priority tier** (user-named; unlabeled tiers read "Priority 1") |
| no tier | **Unprioritized** (implicit, always last) |

⚠️ **"Collection" is already overloaded** — a *user's* collection vs an *archival* collection. Never
use it for an Archive Visit or a target. The app already ships an info popover whose whole job is
disambiguating those two senses.

## Screens

### 1a — Archive Visits list (iOS: Research tab · macOS: `frus.archiveVisits` window)

Mirror **`WorkingCorporaView`**, not `CollectionListView` — the plan's model is the WorkingCorpus
shape, and that view already solves rename and coverage. `WorkingCorporaView`'s own doc comment
states the family rule: *"a `@Query`-driven list, rename in place, swipe or menu to delete… a
researcher who has learned one should not have to learn the other."*

- **Row**: name (`.body`; ● "Untitled Archive Visit" when empty) · caption line `N targets · M
  repositories · lastModified` (all ○) · an optional `.caption2`/`.tertiary` provenance line
  ("Seeded from “%@”" ●).
- **Context menu**, two items, no divider: **Rename** (`pencil`) → **Delete** (`trash`,
  `role: .destructive`) — the `WorkingCorporaView` order.
- **Rename** is an `.alert` with a `TextField`, Cancel/Save — and commits through the model's
  `rename(to:)`, never by assigning `name`, so `lastModified` moves (it is what CloudKit's
  last-writer-wins resolves on).
- **Duplicate** in the context menu, above a `Divider()`: names the copy ● `"%@ copy"` — the exact
  shipped grammar of `Collection.duplicate(in:)` — under a **new** localization key.
- **Create**: an end-of-list **New Archive Visit** row, *not* a nav-bar `+`. S-3b retired that
  pattern with a recorded reason: *"the old '+' lived in the navigation bar, where a reader who had
  never gone looking for it never found it."*
- **Delete**: swipe + the menu item, with a confirmation naming what goes. Cascade is explicit —
  `.nullify` inverses do not cascade under CloudKit.

**States**: empty (`ContentUnavailableView` explaining what a visit is and how to seed one — and
the New row must remain reachable); a plan whose documents are partly unindexed on this device
(orange coverage caption).

### 1b — Plan editor: Targets (the core screen). Both platforms.

Sections **by repository**, each header carrying the **(a) links** for that facility ("Plan a
research visit" / "Finding aids — what is held" ●, from `RepositoryFactTable`). Within a section,
group by **priority tier**, Unprioritized last.

- **Filter row** (chips, `ViewThatFits` one-row/stacked, the Wave-B grammar from
  `ArchivalAnalyticsView`): **Repository** · **Tier** · **Claim** (drawn from / pointed at / both) ·
  **Included only**.
- **Collapsed target row**: the unit's name (a decimal class shows #828's `code — gloss`; a lot its
  number; a library collection its name) · the **records line** (RG · Entry · series · NAID · years
  — `TripPacketModel.recordsLine`) · claim counts, **never summed** ("drawn from 3 · pointed at by
  2" ○, never "5") · tier control · include toggle · a **restriction** line where flagged · a
  **substitute** marker where the seeding has one.
- **Expanded row**: each seeding document — a link (in-app it navigates; in export, the short
  citation + its history.state.gov URL) and the **verbatim reference context**: the source note as
  printed for a drawn-from seeding; the footnote citation with its anchor for a pointed-at one,
  with `Ibid.` rows disclosing inheritance. **Claim groups stay visibly distinct.** Long lists
  elide with exact counts (the shipped 12/8/20 truncation grammar).

**Restriction rendering is not a badge.** A lot can be claimed by several series with different
access statuses (● 123 divided lots in the shipped artifact, one claimed by up to 13 series), so
the line states the **worst covered status**, the series it belongs to, and how many claimants are
**unmeasured** — then routes the divided lot into (c) as a question for the archivist.

**States**: no seeds; seeds but no derived targets; a stored target whose key no longer derives
(shown, labeled, never deleted); fewer indexed volumes on this device.

### 1c — Tier management

Create, rename, reorder, delete, any number. Deleting a tier drops its members to **Unprioritized**
and says so. A new plan starts with **no tiers** and one visible "Add a priority tier" control — so
a researcher who never prioritizes pays nothing.

### 1d — Plan editor: Documents (secondary tab)

The seed list, each row with the **two contribution controls** — *Archival source* and *Unprinted
references* — in `CollectionEntryInspector`'s shipped Default/On/Off `overridePicker` grammar.

**Sparsity is a design constraint**: external references exist on **≲6% of documents ●**. The
references control shows its count where present ("3 references" ○) and, where absent, is
**replaced by a caption, never rendered as a dead toggle**: ● "No unprinted references in this
document's footnotes"; ● "This document carries no source note" (true of pre-1906 by design). A
row with both halves off gets a **"contributes nothing"** warning chip.

### 1e — Add to Archive Visit (the picker) + the three-way choice at add time

`PlanPickerSheet`, cloning `CollectionPickerSheet`: searchable list, a New row, dedupe, checkmark,
auto-dismiss. It carries a **preset scope** and a **basis string** recording how the seed was made.

The add control appears on: **Source Explorer** (section-local, with the three choices — *source* /
*references (N)* / *both*), **Archival Neighbors** (in the shared content core — it has three
hosts, and a control in the sheet alone would be missing from the macOS and Stage-Manager
windows), **Archival Analytics** (beside "Show Archival Neighbors", routed *through* neighbors so
the count is disclosed before anything is added), **Project Home** ("Plan a Visit" → create-or-open,
seeded from the leads union, plus an explicit "Re-seed from project" — never a live mirror), and
**Collections**.

**Before adding a large cohort, disclose the count and let the researcher choose** the visible set
or the full cohort.

### 1f — Deliverables panel

Per-plan toggles: **(a)** links · **(b)** target list · **(c)** inquiry drafts — all on by default —
plus the **citation crib** appendix, **off** by default. Per-plan, not a global preference.

### 1g — The artifact: preview and share

Successor to `TripPacketSheet`. Adds what the packet never had: an **editable inquiry topic
sentence**. `TripPacketTopicSentence` was designed for this and its writer was never built; its
doc comment states the hazard — the research question is *"an internal note written for the
researcher's own use"* while the draft is *"an email to NARA reference staff"*, so **the exporter
must read the edited value, never the stored one.** Draw the editor.

### 1h — The coverage report

Always present, in `WorkingCorpusResolver`'s grammar (both numbers, always): targets derived vs.
stored rows that no longer derive · documents indexed on this device vs. seeded · substitutes
tested vs. found, with the partial-digitization count · restriction claimants measured vs.
unmeasured. **An empty substitutes result must never read as absence** — the shipped type warns
that an empty chapter with no caveat *"would read as a clearance to pull everything."*

### 1i — Settings ▸ Data & Recovery

An Archive Visits row in the research-data item counts and in the erase ladder.

## Numbers for the mocks

● 11 facilities in `RepositoryFactTable` · ● 123 divided lots (up to 13 claimant series) · ● ≲6% of
documents carry external references · ● ~21 source-note groups per 30 documents corpus-wide (25
pre-1950, 14 post-1950). Everything else in a mock — target counts, repository counts, per-plan
figures — is ○.

## Files

`README.md` (this brief). The design returns as `Archive-Visits.dc.html` + `screenshots/`, with a
`PROVENANCE.md` recording what was delivered.
