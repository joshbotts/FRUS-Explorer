# Planning review, for the next plan of record — 2026-10-21

**Status: DECIDED 2026-10-21, and carried into `Plan-Of-Record-2026-10-21.md`.** The owner answered §4's fifteen questions the same day (§5), and the new plan is built from those answers, its decisions 84 to 98, and from this review's findings. Written against `v2` at `f962077e` (S5 merged, no pull request open), the review proposed and decided nothing. Its §1 table is as proposed but for one row, corrected when the change was made (`external-citation-sample.json`), and the plan it names as superseded is now `Completed/Plan-Of-Record-2026-10-14.md`.

---

## 0. Where things stand

- **Build 51 (version 1.0, build 1861) is code-complete.** Every lane of the live plan merged: A1 to A19 with A10b, A11b and A18b (#1678 to #1748), and the screenshot sweep S0 to S5 (#1749 to #1755). The build has not been uploaded or tagged: decision 83 holds both until the app is ready for App Store submission.
- **The capture sittings' findings are filed** as #1756 to #1765 on the owner's word of 2026-10-21. Eight carry the new label *before App Store submission* (#1756 to #1763) and two do not (#1764, #1765). A comment on #1620 records that Stage Manager is the crash's trigger.
- **The live plan is spent.** Its Track A queue, Track B, §6a (the captures), §6d (the index bump) and §6e (the issues filed on 2026-10-15) are done. What remains open:
  - §4, the owner's steps;
  - §5, OS 27's leftovers;
  - §6b, C-3, the agentic analysis measurements;
  - §6c, the store set;
  - §6f, carried from the build-49 wave;
  - §6g, unfiled findings;
  - §6h, A7 (App Intents and Siri).
- **Open issues: 16.** #1756 to #1765, #1723 (A7), #1696, #1691, #1690, #1620 and #234. No proposal is open.

---

## 1. Document dispositions

The rule in `CLAUDE.md` is that `Planning/` holds live plans, runbooks and open designs, and finished work goes to `Completed/`.

Many finished documents are cited by code comments, tests, tools or the Agentic Analysis Guide. For example, `CodingStandardsAuditTests` reads `c0-falsifier/` and `c2-long-session/`, and `FRUSCoreKit` comments cite four memos. Moving those means editing the citing files, some of them shared kit code.

So each document gets one of these dispositions:
- **COMPLETE IN PLACE:** mark its header complete and leave it where it is. This follows `Index-Bump-Brief-2026-10-11.md`'s precedent, which stays at the root because kit code cites it.
- **MOVE:** move it to `Completed/` and add it to `Completed/README.md`. Only for uncited documents.
- **KEEP:** it stays live.
- **KEEP until X:** it stays live until X happens.
- **SUPERSEDE:** the plan of record, which moves to `Completed/` marked SUPERSEDED.
- **OWNER:** it needs the owner's decision first.

| Document | Disposition | Why / note |
|---|---|---|
| `Plan-Of-Record-2026-10-14.md` | **SUPERSEDE** | The new plan replaces it. `planOfRecordMatchesTheVisualMarketingPlan` needs exactly one plan not marked SUPERSEDED, with a matching `§7 struck:` line. |
| `DEVELOPMENT-PLAN.md` (4.1 MB) | **KEEP**; **OWNER**: rotate? | The session log. At 4.1 MB, every session that greps it pays for it. Option: move entries before 2026-10-01 to `Completed/DEVELOPMENT-PLAN-to-2026-09.md` (D14). |
| `FRUS-Explorer-Specification.md` | KEEP | The original spec. Decisions §18 and §22 are still cited. |
| `Generators-Runbook.md`, `UI-Test-Destinations-Runbook.md`, `Capture-Runbook.md`, `Agentic-Harness-Runbook.md`, `nara-record-group-catalog-runbook.md` | KEEP | Runbooks in use. |
| `New-Volume-Release-Plan.md` | KEEP | The live procedure for when the Office publishes new volumes. |
| `Visual-Marketing-Plan.md` | KEEP, and **update §7** | The audit test reads its §7. Steps 10 (capture sessions) and 15 (composed frames) were done by S0 to S5. GATE A, the EULA placeholders, is moot since decision 17. Steps 5, 12, 13 and 16 stay open. |
| `Launch-Marketing-Kit-2026-10-13.md`, `Store-Listing-Draft.md`, `marketing-drafts/` | KEEP until submission | The listing's source. #1763 edits the kit. |
| `Manual-Revisions-Pending.md`, `Manual-Update-Build-49-Owner-Review.md` | KEEP until the owner's manual review | The ledger and the Amendment Log cite them. Rule P2, "no lane edits a manual", was superseded by the 2026-10-14 plan's "lanes edit the manuals". Close both at the review (D11). |
| `App-Intents-Siri-Assessment-2026-10-18.md` | KEEP until A7 | A7's plan (#1723). |
| `C-3-Reader-Test-Design.md`, `Agentic-Loop-Development-Plan.md`, `Agentic-Guide-Accessibility-Review-2026-10-14.md` | KEEP until C-3 runs | C-3 is frozen and deferred to after the tag. C-1 stays gated. The guide cites the accessibility review. |
| `Person-Authority-Identifier-Assessment-2026-10-17.md`, `Person-Authority-Overlay-Review-2026-10-17.md` | KEEP until the deferred person-authority work runs | The design for decision 55's later fix. File it as one issue (D13). |
| `Keyword-Snippet-Assessment-2026-10-20.md` | KEEP until #1760 lands, then COMPLETE IN PLACE | Cited by `ProseSnippet.swift`, `SearchService.swift` and `KeywordSnippetTests`. |
| `Cross-Volume-Page-Citations-Assessment-2026-10-20.md` | COMPLETE IN PLACE | A18b is done. Cited by `PageSpanResolver.swift` and `IndexingPipeline.swift`. Its §10 side findings move to the new plan's backlog (§2). |
| `Index-Bump-Brief-2026-10-11.md` | COMPLETE IN PLACE (already) | Cited by kit code. |
| `Issue-1648-Stopping-A-Replaced-Search-2026-10-15.md` | COMPLETE IN PLACE | Decided and built. Cited by `IndexingPipeline.swift`. Its §6 search-cost measurements move to the backlog. |
| `Vector-Embeddings-Semantic-Design.md` | COMPLETE IN PLACE | Executed, V-0 to V-5. Cited by two app files. |
| `Lexical-Axis-Addressable-Market-2026-08-27.md` | COMPLETE IN PLACE | Done. Cited by `SimilarityModel.swift`. |
| `Agentic-Guide-Revisions-2026-09-04.md`, `C0b/C0c/C0d-Falsifier-2026-09-06.md` | COMPLETE IN PLACE | Done. The Agentic Analysis Guide cites them. |
| `C0-Falsifier-2026-08-31.md`, `C2-Long-Session-2026-08-31.md` | **MOVE** the memos; **KEEP** `c0-falsifier/` and `c2-long-session/` | The memos are uncited. The folders stay, since `CodingStandardsAuditTests` reads them. |
| `c0b-falsifier/`, `c0c-falsifier/`, `c0d-falsifier/` | COMPLETE IN PLACE | Experiment data beside cited memos. |
| `OH-Report-2026-10-01.md`, `OH-Report-2026-10-01/` | COMPLETE IN PLACE | Filed as HistoryAtState/frus#469. `tools/oh-report/` reads them. |
| `Issue-1577-Search-Within-Results-Assessment.md` | **MOVE** | A5 is done. Uncited. |
| `Map-Figure-Export-And-Visual-Outputs.md` | **MOVE** | Phases 1 to 3 shipped 2026-08-27. Uncited. |
| `OS27-Semantic-Retrieval-Design.md` | **MOVE** | Uncited. Its workstreams have all landed somewhere: A (A0 is A6; A1 is A7, #1723), B0 shipped in build 44, B1 (`CSUserQuery`) was declined, and C shipped through the vectors program (C3, project-lead centroids, is one backlog line). |
| `W15-Geographic-Analytics-Assessment-2026-09-01.md` | **MOVE** | Assessed. Dateline places stay parked, blocked on the owner's toponym curation. Uncited. |
| `external-citation-sample.json` | KEEP *(proposed as MOVE; corrected 2026-10-21)* | `Completed/README.md` names it the current baseline of the external-citation sample, whose superseded predecessor is archived there. |
| `semantic-spike/` | COMPLETE IN PLACE | The 300m-era spike, superseded by EmbeddingGemma 2. `tools/semantic-harvest/` cites it. |
| `semantic-vectors/` | KEEP | The shard output location and the memos `CLAUDE.md` cites, such as `Dimension-Ladder-Spike.md`. Track B is complete, so its memos are history, but they are cited. |
| `234-Early-Era-People-*.md` (2), `People-Early-Era-Program.md`, `M2-Semantic-Pipeline-Ride-Along.md`, `early-era-people/` | KEEP as deferred | #234 is deferred indefinitely. `CLAUDE.md`, kit code and `tools/semantic-harvest/` cite them, and the People program says it is live, not archived. |
| `Cross-Platform-UI-Adversarial-Review/` | **OWNER**, then COMPLETE IN PLACE | The program is done. Its `STATUS.md` §0 lists residue that needs a yes or no on each item (D10). Two app files cite it. |
| `corpus-structure-sweep/`, `cross-ref-validation/`, `source-explorer-export/`, `nara-record-group-catalog/`, `semantic-map/`, `reference/` | KEEP | Generator outputs and reference copies named by the runbooks. |

---

## 2. The backlog, prioritized

Every open issue, every open item of the live plan (§4 to §6h), and every parked or deferred item, in five tiers. **P0** gates App Store submission. **P1** is the first update after it (build 52). **P2** comes later. **Parked** waits for the owner to pick it up. **Close** needs nothing more.

### P0 — before App Store submission

**Code and text.** The eight labelled issues, in a suggested lane order:
- **L1, cheap and screen-visible, first:**
  - #1761, small copy and drawing fixes;
  - #1762, text that drifted from the data;
  - plus §6g's three places that put a phrase's quotation marks inside their own (#1726's siblings: Working Corpora's provenance line, the corpora list's caption, Corpus Analytics' chart headings);
  - plus the two rows that cut their own words at the largest accessibility size (the smart collection row; a document title held to two lines). D3.
- **L2, Search:** #1758 (stale state; the saved corpus records only its query) and #1760 (a question typed in Keywords mode).
- **L3, Analytics:** #1756 (the link's count, the Administrations order, Chart Colors).
- **L4, the indexing banner:** #1757 (it undercounts large downloads; the Research Guide's first-queue sheet didn't open). New readers hit it first.
- **L5, first launch:** #1759 (the dock before the splash, the empty backdrop, the overlapping words).
- **L6, the launch kit:** #1763. Tools and copy, not app code.
- **Proposed addition (D2): a page link into a volume not on the device does nothing**, on iOS and the Mac (`resolvePageReference`). This is a §6g finding from the page-citation assessment. A18b made many more page references into documents, and most readers hold only some of the volumes, so a reader taps a link that does nothing.

**Release mechanics, after the P0 lanes merge:**
- The release checklist again, as A19 ran it.
- **Screenshot retakes** for the screens the fixes change (D5): the onboarding frames (#1759), the analytics captures (#1756), the search captures (#1758, #1760), `research-rail` (#1761's tint), and the coverage line.
- Both TestFlight notes.
- Then the archive, the upload and the `build-51` tag, with D4 (a TestFlight device pass before submitting) decided first.

**Owner steps.** The repository holds drafts for all of them:
- Make frusexplorer.app public and paste the Privacy Policy and Support pages (decisions 36 and 58). App Store Connect requires both URLs, and every path answered 401 on 2026-10-19.
- App Store Connect:
  - the privacy label, Data Not Collected (decision 35);
  - the listing, from `Store-Listing-Draft.md` (decisions 28 to 31);
  - the screenshots, from `marketing-drafts/` once composed without the DRAFT stamp;
  - the check that the 13-inch iPad slot takes 2752 × 2064 (decision 33);
  - the App Review notes, age rating and export compliance;
  - a Mac build signed for the App Store.
- **App Previews**: whether the listing launches with them (D6, Visual Marketing Plan step 12).

### P1 — build 52, the first update after submission

1. **#1723, A7: App Intents and Siri.** Its plan is `App-Intents-Siri-Assessment-2026-10-18.md` §5:
   - A7a: the entities, the four intents and the copy.
   - A7b: the Spotlight association, with `expirationDate` and a `CSSearchableIndexDelegate`. This closes §6g's two Spotlight findings: donated items expire after 31 days, and nothing answers Spotlight's requests to reindex.
   - The owner's device check (Spike Reader) decides A7b's place.
2. **Cross-references:**
   - #1764, the network at three hops;
   - §6g's untitled outbound page node in the graph;
   - the six cross-volume references by id to a section's row, missing from the bundled edge index.
3. **#1765, summaries:** the Long Telegram refused by the model, and the Mac's stale collection preview.
4. **Numbers and states that read wrong**, from §6g:
   - after A18's respelling, the two Archival Neighbors readers disagree on a class key no note carries any more (A19's census);
   - a volume whose indexing is cut short is marked nowhere until the next launch (A14);
   - the Archives Visit labels lot targets by their first document (A15).
5. **Search's cost**, measured on 2026-10-15:
   - an exact-word search for a common word holds the pipeline for about two minutes;
   - on the Mac, most of a search's time is the snippet pass;
   - the default scope's user-content union costs a common word's count about 0.3 s.
6. **An owner device sitting** for the device checks no simulator can do:
   - the Topics lens on an iOS 27 device;
   - one Audio Graph heard aloud;
   - the Mac's Sync Log after a sync;
   - the Mac Search window with a selection under VoiceOver, in dark appearance, with Full Keyboard Access;
   - Text Color's picker on an iPad under iOS 27;
   - the by-eye checks carried from builds 48 and 49.
7. **C-3**, the agentic analysis measurements (decision 13): after the tag, on the owner's Mac, under its budget rule.
8. **The owner's review of both manuals** (decision 27). Then the *AI Generated* notice comes off, and `Manual-Revisions-Pending.md` and `Manual-Update-Build-49-Owner-Review.md` close (D11).

### P2 — later

- **The person authority's deferred work** (decision 55; the two 2026-10-17 memos), to file as one issue (D13):
  - the identifier rule (b4), which restores the VIAF and Wikidata ids that hold (it needs a rollup bump);
  - the role text of an overlay entry that carries several people;
  - the nine members held apart who rejoin by name;
  - #1658's tie, fixed but not decided.
- **Generators:** provenance flows count no page reference (`RefDestination.citedDocument` is nil for a page).
- **Section vectors**, at the next vectors generation (decision 61). This is #1690's one unbuilt line.
- **Smaller app items**, from §6g:
  - `ProjectLeadsService` ranks with no year;
  - `datesByDocumentKey(_:)` scans every row (17 ms against 0.03 ms by the key);
  - the archival chip is cut on the iPhone 17;
  - Sync Diagnostics' Clear Log draws its trash icon in the accent colour.
- **The 2026-09-27 audit**, unfiled:
  - Facets is disabled in Meaning mode on iPhone and iPad, where the Mac offers it;
  - the reach scan and the leads count second-edition reprints;
  - Archives Visit derivations go stale when a volume updates.
- **Test infrastructure:**
  - #1620's re-test on iOS 27.1 (decision 72), now pointed at Stage Manager;
  - `RichTextRestingCapTests` on an iPad host;
  - two UI suites need the Research rail open (A12);
  - the iOS 26.5 runtime's missing English lemmatiser, a note for the runbook.
- **#1608:** how often iOS 27 devices launch without the lemmatiser.
- **Hygiene, from §6f:**
  - two views nothing constructs;
  - 14 Swift files outside every target with no license header;
  - nine Swift files citing the wrong issue numbers;
  - the HYG and READ leftovers;
  - the lanes' own leftovers.
- **Marketing**, from the Visual Marketing Plan: step 5 (the publication-lag plate), step 13 (Plate B) and step 16 (after launch).
- **Accessibility, parked in §6f** and worth a sweep of its own:
  - `AXChartDescriptor` for four chart families;
  - Differentiate Without Color on the map;
  - about 37 text sites with a fixed size;
  - a reader that follows the system text size.

### Parked — designed or proposed, not scheduled

From §6f:
- dateline places (blocked on toponym curation);
- links from the map to Search and Related;
- a heat-matrix cell drill-down;
- a Search command menu and shortcuts;
- standalone token editors;
- a subseries pole picker;
- a region-share chart;
- an iPhone rail peek strip;
- an immersive Read mode.

Also C-1 of the agentic loop (gated), and the OS 27 design's C3 (project-lead centroids).

### Deferred, or waiting on someone else

- **#234**, early-era people: deferred indefinitely.
- **#1696**: waits for the Office's subject export to reach Document 946. Decision 71 says nothing is posted.
- **For the corpus to fix:** `frus1945Malta/d273`'s year.
- **For HistoryAtState/people to fix:** the registry's own merges (Stevenson, Wilson, Fish).
- **New volumes**, whenever the Office publishes, by `New-Volume-Release-Plan.md`.

### Close

- **#1690:** lines 1, 3 and 4 were built in A14, A9 and A18. Line 2, section vectors, was deliberately left out (decision 61) and is tracked in P2.
- **#1691:** lines 1 to 3 were built in A16 and A15.
- **Settled in §4 and §6g:** A10b's two residuals, answered "keep as decided".
- **Declined in §6f, closed as declined:** W12's parallel editions, W14, the MCP server and `CSUserQuery`.

---

## 3. Notes for writing the new plan

- **It must keep the audit's shape**: exactly one plan not marked SUPERSEDED, and a first-lines `§7 struck:` list that matches `Visual-Marketing-Plan.md` §7. If S0 to S5 strike steps 10 and 15 there, the list becomes `0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 14, 15`.
- **The rules that still bind carry over unchanged:**
  - a serial queue, one fresh session per pull request, no auto-merge;
  - `Scripts/heavy.sh`;
  - lanes edit the manuals and leave the *AI Generated* notice;
  - a test that pins language is an advisory;
  - the web edition's four rules;
  - a finding is filed on the owner's word.
- **Decisions 1 to 83 stay in the superseded plan.** The new plan cites the ones it relies on (17, 25, 27, 28 to 36, 55, 57, 58, 61, 72, 82, 83) and numbers its own from 84.

---

## 4. Decisions for the owner

Each has a recommendation. The answers, with §1 to §3, become the new plan.

- **D1.** Do all eight issues labelled *before App Store submission* (#1756 to #1763) gate submission? *Recommended: yes.*
- **D2.** Should the dead page-link tap (a link into a volume not on the device does nothing) be filed as a ninth P0 issue? *Recommended: yes.*
- **D3.** Should #1726's three quote-doubling siblings and the two rows cut at the largest accessibility size join #1761? *Recommended: yes, since all are small.*
- **D4.** How does the release go?
  - (a) Upload 1861 to TestFlight, do a device pass, then submit the same build; a problem found costs a bump to 1862.
  - (b) Submit straight after the checklist.

  *Recommended: (a).*
- **D5.** Should a retake sitting follow the P0 fixes, for the screens they change, before submission? *Recommended: yes.*
- **D6.** Does the listing launch with App Previews (Visual Marketing Plan step 12; recordings A, R and T exist outside the repository)? *The owner's call.*
- **D7.** What does build 52 take? *Recommended: A7 (#1723, with A7b's Spotlight fixes) first, then the cross-reference lane, #1765 and §2's P1 items 4 and 5.*
- **D8.** C-3 after submission, and before or beside build 52? *Recommended: after submission, when the Mac is free.*
- **D9.** Where should #234's documents go? *Recommended: keep them in place as deferred, since they are cited.*
- **D10.** The cross-platform review's residue: a yes or no on each line of `Cross-Platform-UI-Adversarial-Review/STATUS.md` §0, after which the folder is marked complete. *Recommended: decline everything not already filed, unless a line is still wanted.*
- **D11.** When does the manual review happen, and does the *AI Generated* notice come off in the first update after it? *Recommended: the review in P1, and the notice off in build 52.*
- **D12.** Close #1690 and #1691? *Recommended: yes.*
- **D13.** File the person authority's deferred work as one P2 issue? *Recommended: yes.*
- **D14.** Rotate `DEVELOPMENT-PLAN.md`, moving entries before 2026-10-01 into `Completed/`? *Recommended: yes. A 4.1 MB log is read in part by every session.*
- **D15.** Approve §1's MOVE and COMPLETE IN PLACE list as one docs change with the new plan? *Recommended: yes.*

---

## 5. The owner's answers, 2026-10-21

Given in four rounds in one sitting. Each answer becomes a numbered decision of the new plan of record.

- **D1. All eight issues labelled *before App Store submission* (#1756 to #1763) gate submission.**
- **D2. The dead page-link tap is filed as a ninth P0 issue**, labelled *before App Store submission*: **#1766**, a page link into a volume not on the device does nothing. The tap resolves through the device's own `PageRangeStore`, not A18b's bundled page map.
- **D3. #1761 takes the three quote-doubling siblings and the two rows cut at the largest accessibility size** (its body was extended on 2026-10-21, items 7 and 8). The siblings are Working Corpora's provenance line, the corpora list's caption, and Corpus Analytics' chart headings with its no-match line. The method appendix's plain-text line stays the owner's call: it is the record of what was typed.
- **D4. A TestFlight pass first, numbered 1.0 (1776). The App Store submission is 1.0 (1861).** The owner's words: "because 1.0/1861 hasn't been submitted to test flight yet, we can still change build number for a test flight release. bump build number down to 1776 for a test flight pass. we will restore build number to 1861 for the app store submission."
  - So decision 83 is refined. Once the P0 fixes and the retakes are in, the build number goes to 1776 for the TestFlight upload; after the device pass it is restored to 1861 for submission.
  - Each bump follows `CLAUDE.md`'s procedure, the README line and its mirror included.
  - App Store Connect accepts the order: within version 1.0 each upload must be numbered higher than the last, and on the Mac higher than every earlier upload. Build 50 went up as 50, so 50, 1776, 1861 all rise. The reverse order would be refused.
- **D5. A retake sitting follows the P0 fixes, before submission**, for every screen the fixes change, in the manuals and the store frames.
- **D6. The listing launches without App Previews.** They are added in a later update (Visual Marketing Plan step 12).
- **D7. Build 52's order is decided after submission**, by the next plan.
- **D8. C-3 runs after submission and before build 52 starts.**
- **D9. #234's documents stay in place as deferred.**
- **D10. The cross-platform review's leftovers that are not already filed are declined**, and the folder is marked complete in place.
- **D11. The manual review, and taking the *AI Generated* notice off, wait past build 52.** Decision 27 stands for 1.0.
- **D12. #1690 and #1691 are closed** (2026-10-21), each with a comment naming the lanes that built its lines, and for #1690 decision 61.
- **D13. The person authority's deferred work is filed as one P2 issue: #1767**, pointing at the two 2026-10-17 memos, which stay until it runs.
- **D14. `DEVELOPMENT-PLAN.md`'s entries before 2026-10-01 move to `Completed/DEVELOPMENT-PLAN-to-2026-09.md`**, after checking that no test or tool reads them from the live file.
- **D15. §1's dispositions land as one docs change with the new plan of record**: the new plan, the old one marked SUPERSEDED, the moves, the in-place marks, the Visual Marketing Plan's §7, and D14's split, with the audit tests run.
