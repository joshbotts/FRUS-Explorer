# Cross-reference integration — the feature the window did not become

Logged 2026-08-15, after assessing whether Cross-Reference **Analytics** should integrate with the
cross-reference **graph** before giving Analytics its iPad window. The answer was no — the window
shipped as an empty marker (#917) — but the assessment found a real, unbuilt feature and three
specific defects. This is that record.

Two independent readers, the second tasked with breaking the first. Every claim is cited.

---

## 1. The surfaces, and the third one the framing forgets

| surface | grain | data |
|---|---|---|
| **Cross-Reference Analytics** | corpus-wide statistical object — top-15 in-degree, degree histogram, 15×15 volume heat matrix, top-15 PageRank | the **local** SQLite index only |
| **Cross-Reference Graph** | one document's ego network, 1–3 hops, with the footnote passage that carried each edge | local, **plus** the bundled corpus-wide index for inbound edges |
| **`VolumeConnectionGraphView`** | one volume's ego graph, from `VolumeView`'s toolbar | local |

**The third is the one that matters and neither the review nor the original question names it.**
It sits at *exactly* the grain the heat matrix aggregates — and the two reach volume-to-volume
counts by **two different queries** (`volumeLevelConnections` for the matrix, `volumeEgoGraph` for
the graph), so the same adjacency is computed twice by two routes that could disagree.

## 2. Why this was not a window key

Every focus an integration would introduce fails for its own reason:

- **A document focus** is already owned by `GraphWindowRequest`.
- **A matrix cell** has no tap target at all — only row and column labels are buttons, and they
  teleport to Browse. So "volume A cites volume B 47 times" is a dead end, though A's ego graph is
  one sheet away.
- **A volume scope** has no producer: both call sites construct the view with no arguments, so a
  scope-carrying request would ship with exactly **one reachable value** — an empty marker with
  extra fields.

Widening later is non-breaking (optional fields decode cleanly from pre-widening restoration
payloads, the `GraphWindowRequest` pattern), which is what makes shipping the marker first safe.

## 3. The feature, smallest first

**3a. Make a heat-matrix cell go somewhere.** The obvious gesture on "A cites B 47 times" is to ask
*which 47*. Today nothing happens.

**Blocked on a query, not on UI.** The readers disagreed here and the disagreement is the finding:
one said no store query returns the references behind a cell; the second found the edge list *is*
already loaded — what is missing is **agreement between the two queries above**. Settle that before
designing the interaction, because it decides whether this is a UI change or a data change.

**3b. Let the two families reach each other.** Neither links to the other in either direction.
An analytics document row's only action is opening the document in Browse; the graph offers no
route back to the aggregate.

**3c. Reconcile the two volume-adjacency queries**, or document why they differ.

## 4. The honesty problem, which is the most interesting finding

**The two families do not see the same corpus.**

The graph completes its inbound half from the bundled corpus-wide index. Every analytics figure
reads the local table only. So:

> "Most-referenced documents" is a function of **what the reader has downloaded**. The graph's
> inbound list is not.

Put those side by side — which is exactly what integration means — and the app would be showing two
numbers about the same citation that disagree, with nothing on screen explaining why. Any
integration owes that sentence before it owes a picture.

The bundled index cannot close the gap either: it deliberately carries no titles, dates or document
numbers, so it can support *"how many cite this, and from which volumes"* but never a ranking.

## 5. Defects found in passing

1. **A stale doc comment that would mislead this work.** `CrossReferenceStore`'s
   `volumeLevelConnections` says it is *"Used by `VolumeConnectionGraphView` in the Corpus
   Browser"*. That view was redesigned to the ego-graph query and no longer calls it; the query's
   only app-side caller is the analytics heat matrix. Anyone scoping integration from that comment
   starts from a false map.
2. **P-8's stale evidence is still in the source.** `STATUS.md` records the finding as falsified by
   #209, but the code comment it quoted was never edited — so the file still asserts the thing the
   status file says is untrue.
3. **The `dismiss()` gate**, fixed in #917: the row hand-offs called `dismiss()` unconditionally,
   which closes a `WindowGroup` scene. Any future window on these surfaces inherits the same trap.

## 6. If this is picked up

Order: **§3c** (settle the queries) → **§3a** (the cell goes somewhere) → **§4** (say the corpora
differ) → **§3b** (mutual links). §4 is not optional decoration; it is the difference between an
integration that informs and one that quietly misleads.
