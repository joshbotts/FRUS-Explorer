#677 added an acceptance test to the **lot-file** route. Measured against the corpus, that route is **14,487 of 54,009 live-catalog source notes — 26.8%.** The other 73.2% render catalog rows through queries with no acceptance test at all, in the same row view, behind the same "View in NARA Catalog" button.

| strategy | notes | live query | guarded? |
|---|---|---|---|
| `lotFile` | 14,487 | `variantControlNumber_is` + RG filter | ✅ #677 |
| `presidentialLibrary` | **29,093** | `searchByPresidentialMaterials` — free-text `q` only | ❌ |
| `naraCollection` | **10,429** | `searchByRecordGroup` | ❌ |

`searchByPresidentialMaterials` (`NARACatalogClient.swift:585-600`) sends **only** a free-text `q`, without even `description.recordGroupNumber` — strictly weaker than the query #674's own doc comment calls uncontrolled, and it is rendered as up to three confident results.

## Why the exposure is real, not theoretical

**1,947 of those notes name institutions that are not in the NARA catalog at all** — Library of Congress (1,060), Minnesota Historical Society, Princeton, Yale, Hoover Institution, Stanford, plus mis-parses like `"NSC 5906"`. Every catalog row shown for those is wrong by construction: there is no right answer to return, so whatever the free-text query surfaces is noise presented as a finding.

A further **853 `naraCollection` notes ship a lot number as free text**, so they take the unguarded path for a citation the guarded path was built for.

## Why this is not simply "apply the same test"

The lot test's third conjunct is *carries this control number*. Presidential-library collections have no equivalent identifier — that is why #355 needs hand-curated NAIDs in the first place. So the fix is not one rule reused; it needs its own answer, probably some mix of:

- refuse outright for repositories known to be outside NARA (the 1,947), and say so — the honest "this is held at the Library of Congress, not NARA" is more useful than three wrong catalog rows;
- route the 853 lot-carrying `naraCollection` notes through the lot path, which *does* have a test;
- for the genuine presidential-library remainder, treat live results as candidates rather than resolutions (#669's `.candidates` grammar), pending #355's curation.

Sized here rather than scoped: this is larger than #674 and should not ride N-8b. Filed so the 26.8% figure is on the record — #677's fix is real but narrower than its framing suggested.

Related: #674, #677, #355.
