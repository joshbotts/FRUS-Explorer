# Window-fronting audit — re-run 2026-08-27 (W-2e / Mac W-12)

The standing per-release gate M-1 established (the 2026-08 navigation audit found **11 of 56**
open-window sites unpaired with fronting, including seven of the nine main-window toolbar
launchers). This is the first recorded re-run since that audit; W-12 says one belongs to every
release. Method: exhaustive call-site inventory (`fronting(id:)`, `fronting(id:value:)`,
`openWindow(value:)`, bare `openWindow(id:)`) paired both ways against the scene table, plus the
test suite that automates the invariants.

## Verdict: CLEAN, with two named blind spots

- **74 `fronting(id:)` sites** across 23 files, **27 `openWindow(value:)` sites** across 20
  files, **zero bare `openWindow(id:)`** in app code (every grep hit is doc-comment prose, which
  `MacWindowFrontingTests.codeLines` deliberately ignores).
- **Every id-based scene has at least one opener; every opener names a declared scene** — the
  set-difference is empty in both directions, including the two `fronting(id:value:)` sites
  (`about` + `frus.newProject`).
- The invariants are automated: `MacWindowFrontingTests` (bare-call build-failer, ≥50-site
  anti-vacuity floor, helper does open+raise with one id, ten toolbar launchers, graph and — since
  W-2b — Source Explorer open **by value** with their id-based hand-off doors pinned, both cold
  Window-menu doors pinned by `coldDoorsExist`) and `MacWindowRoutingTests` (every
  `openWindow(value:)` names a type with a `WindowGroup(for:)`).

## The two blind spots, one now guarded

1. **`ProjectHomeView` fronts a runtime id** — the one call the literal-matching tests cannot
   see: `openWindow.fronting(id: windowId)` where `windowId` is computed from a mapping. A future
   mapping entry naming an unregistered id would fail silently. **Now guarded**:
   `projectHomeMappedIdsAreDeclared` (in `MacWindowFrontingTests`) extracts every id the mapping
   can produce and asserts each is a declared scene id.
2. **`AppState.openAuxWindow` is generic** — `openWindow(value: value)` with a type parameter,
   invisible to `MacWindowRoutingTests`' `openWindow(value: SomeType(` regex, so its ~8 callers
   are unaudited by that test. Every current caller passes a type that has a scene; recorded here
   rather than guarded, because guarding it means resolving generics in a source scan — the next
   re-run should re-check the caller list instead.

## Corrections made alongside this run

- The scene-inventory tally had drifted (#1023 added `frus.subjects` without bumping the header);
  corrected in W-2b to the counted table — **16 `Window` + 11 `WindowGroup` + `Settings`** on
  macOS — with a note to trust the table over the headline.
- M-1's own numbers ("Twenty-three scenes… 17 singleton Windows, 4 value-based WindowGroups") are
  stale and should not be quoted; the table above is current as of W-2b.
- #920's promised cold Window-menu command for the graph **did not exist** — the door was silently
  missing from the menu since the graph went value-based. Restored in W-2b for both value-based
  conversions and pinned by `coldDoorsExist`.

## Re-run procedure (per release)

1. `swift test` equivalents: run `MacWindowFrontingTests` + `MacWindowRoutingTests` (they run in
   the iOS unit suite; both are source scans).
2. Re-grep the three call forms; pair against the scene table both ways; the expected result is
   empty set-difference.
3. Re-check `openAuxWindow`'s caller list (blind spot 2) — each passed type must still have a
   `WindowGroup(for:)` on the platform it runs on.
4. Append a dated verdict section to this file. A finding is a defect the moment a launcher can
   run with nothing surfacing — that is M-1's "worse than a dead button": a buried window that
   silently retargets.
