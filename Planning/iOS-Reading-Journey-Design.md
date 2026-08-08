# iOS document-to-document navigation: keeping the reading journey (#751)

**Status:** owner decision required. Nothing is implemented.
**Source:** 2026-08 navigation & state audit (`Navigation-State-Audit-2026-08.md`), findings
**H-3, M-16, M-17, M-28**. Filed as the audit's one genuine *design* question.
**Written:** Session 2026-08-08, against `v2` @ `e470d517` (post-#750).

---

## 1. The single decision

Today, on iOS, **every document-to-document jump goes to the Browse tab**, no matter where the
reader started. That is deliberate and documented (`DocumentView.swift`, the comment at
`navigateToAdjacentDocument`): one universal reader, so behaviour is predictable.

The cost is the reading journey. Open a document from search results, tap a cross-reference, and the
app leaves the Search tab. **Back** then unwinds the *Browse* hierarchy — an unrelated volume from
earlier, or the corpus root where the Back button disappears. The document you were reading is still
alive on the Search tab, but nothing on screen says so.

macOS does not have this problem: a cross-ref pushes onto the same window's stack, so Back returns
to the source.

**The question:** should an iOS reading journey stay in the tab it started in?

---

## 2. What changed underneath this issue

**#750 already built the mechanism.** `DocumentView` now takes an optional
`onNavigateToDocument: ((DocumentBrowserEntry) -> Void)?`; when supplied, cross-references and
edge-tap page-turns go to the *host's* stack instead of the Browse tab. Three sheets already use it
(Chronology, Citation Lookup, the cross-reference graph).

So the implementation cost of the main change is now **one line per host**, not a refactor.

**But #750 also encoded the status quo as a test.** `HandoffVisibilityTests.browseHostsAreUnchanged`
asserts that `BrowserView` and `SearchView` must *not* pass a host router. That was the right call
for a bug-fix PR — it kept the change opt-in and prevented a double navigation — but it means
**changing this decision requires deliberately editing that guard**, which is exactly the friction a
design decision should have. It is not an obstacle; it is the record of the current choice.

---

## 3. What is actually broken vs. what is a design preference

Separating these matters, because two of the four findings do not need an owner decision.

| Finding | Character | Needs a decision? |
|---|---|---|
| **H-3 / M-28** — cross-ref from a Search-opened document exits to Browse; Back lands in stale Browse history | Design | **Yes** — this is the decision |
| **M-16** — five other origins (Research, History, Project leads, Related Documents, Archival Neighbors) behave the same way | Design, same root | **Yes** — same decision, wider blast radius |
| **M-17a** — each edge-tap page-turn *appends* a Browse level, so 20 pages = 20 Back taps | **Bug-ish** | No. Even under today's design, a page-turn should *replace* the top entry, not stack one |
| **M-17b** — the 56 pt leading edge-tap zone overlaps the system back-swipe start region | **Unverified** | No — see below |

**On M-17b, the issue overstates the evidence.** The zones use `.onTapGesture`, so a recognised pan
should not fire them; whether an imprecise short back-swipe registers as a tap is a *runtime*
question nobody has measured. The audit's own verifier flagged this. It should be settled with a
device check, not designed around. The existing 56 pt width already carries a documented rationale
(sit outside the reading column so WKWebView still receives in-column link taps), so narrowing it has
a real cost.

**M-17a is worth doing regardless of the decision below**, and is cheap: the consumer
(`BrowserView.consumePendingBrowseDocument`) unconditionally appends. A page-turn is a *replacement*
of the current reading position, not a descent into it.

---

## 4. Options

### Option A — Keep the current design (do nothing but M-17a)

Every jump goes to Browse. Predictable, one code path, no new state.

- **For:** zero risk; the origin tab genuinely retains its stack (`BrowserTabView`-style identity
  wrappers keep `@State` stable across tab switches), so the reading position is recoverable by a
  tab tap.
- **Against:** recoverable is not discoverable. Nothing on screen tells the user their document is
  one tab away, and **Back's destination is arbitrary** relative to where they came from — the part
  that reads as broken rather than merely different.

### Option B — Reading journeys stay in their origin tab (recommended)

Pass `onNavigateToDocument` from every surface that hosts a reader on its own stack: the Search tab,
and the five M-16 origins. A cross-ref or page-turn then pushes onto the stack the user is already
looking at, and **Back returns to the document they were reading** — matching macOS.

- **For:** fixes H-3, M-16 and M-28 together; mechanism already exists and is already exercised by
  three sheets; makes iOS consistent with macOS; Back becomes meaningful everywhere.
- **Against:** the Browse tab is no longer "where documents are". A user who reads a long chain
  inside the Search tab has a deep Search stack and an empty Browse tab, which may surprise anyone
  who has learned today's behaviour. Five origins are *lists* (History, leads, Related Documents,
  Archival Neighbors) where pushing a reader onto the list's own stack is natural — but two of those
  are **sheets**, which raises the question of how deep a reader should be allowed to go inside a
  sheet before it should hand off properly.
- **Cost:** small per site; the real work is deciding sheet depth policy and updating the #750 guard.

### Option C — Hybrid: origin-stack for tabs, Browse for sheets

Search / Research / History keep their journeys; the three sheet origins (Project leads, Related
Documents, Archival Neighbors) continue to dismiss and hand off to Browse as they do now.

- **For:** avoids unbounded reading stacks inside modal sheets; keeps the biggest wins (H-3, M-28,
  and the two highest-traffic M-16 origins).
- **Against:** two rules instead of one; a user cannot predict which origins keep their place.

---

## 5. Recommendation

**Option B**, with one qualification: adopt it for the **tab-hosted** origins first (Search,
Research, History) and treat the three sheet origins as a follow-up once the sheet-depth policy is
decided. That is Option C as a *staging order* rather than a permanent split — it delivers the
finding the audit rated highest (H-3/M-28, the Search case) with the least ambiguity, and defers only
the part that has a genuine open sub-question.

Do **M-17a** (replace-don't-append on page-turns) in the same pass regardless — it is a defect under
either design.

Settle **M-17b** with a device check before touching the zone width.

---

## 6. If Option B is chosen — the implementation shape

1. `SearchView`: pass `onNavigateToDocument: { vm.navigationPath.append($0) }` to its `DocumentView`.
2. Same for `ResearchView` and `HistoryView` (each already owns a stack for its pushed reader).
3. `BrowserView` keeps the default routing — it *is* the Browse stack; a router there would double up.
4. Update `HandoffVisibilityTests.browseHostsAreUnchanged` to name only `BrowserView`, and add a test
   asserting the newly-adopting hosts DO pass a router (so the reverse regression is caught too).
5. M-17a: make the page-turn path replace rather than append.
6. Docs: both manuals describe where documents open; this changes that sentence on iOS.

**Not in scope:** macOS is unaffected — it already keeps journeys in-window, which is the behaviour
this proposes to match.
