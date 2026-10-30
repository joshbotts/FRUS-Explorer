# The person authority's deferred work (#1767): what a cloud session could settle, and the lane the Mac runs, 2026-10-28

**What this is.** The planning for #1767 that a cloud session can do, worked on the owner's word of 2026-10-28, based on `v2` at `32e295e`. The issue gathers the person authority's deferred work from the 2026-10-14 plan's §6g (plan of record decision 96, P2): the identifier rule, the role text of overlay entries that carry several people, nine held-apart members who rejoin by name, #1658's undecided tie, and one check. Its designs are `Planning/Person-Authority-Identifier-Assessment-2026-10-17.md` and `Planning/Person-Authority-Overlay-Review-2026-10-17.md`; this memo adds what could be read from the data reachable here, settles the two items those memos left open, and gives the Mac its runbook. Nothing in it changed the generator, the kit, the bundle or any version.

**Lane A built, 2026-10-29** (items 3 and 4 with §4.6, on the owner's word "start the person authority lane"; branch `claude/person-authority-lane-c64504`). Four things the build found correct this memo; the session entry in `DEVELOPMENT-PLAN.md` has every figure.
- **`"joins": null` did not mean "no record"** (§4.2, §4.3). Before the apart list was written, every apart anchor's printed name was looked up in the whole registry. Eleven of the 80 left after the Hughes join had a record of their own. The memo's apart list would have split nine entries from the records v12 had placed them with by name, seven of them Jeane Kirkpatrick's (#1657's correction predates `joins`), and kept two more from records they could now join (Richard T. McCormack and William G. Miller, known to the registry from POCOM alone). Four corrections gained a `joins` beside the Hughes join the memo proposed, one held-apart anchor an assignment, and three records with no FRUS anchor are kept. 69 anchors stand apart.
- **The tie rule is neither T1 nor T2** (§4.4). The owner chose a third, `exactFirst`, from the census: a member that fits two reconciled people joins the one its exact name fits, when only one does. T1 moved three entries away from that person, Peter G. Peterson's among them; T2 moved seven of Jimmy Carter's own entries.
- **Only vol. XLIV Part 1's Wright entry went to Jerauld Wright** (§4.6). Vol. I's "Wright, John Oliver" already reached Sir Oliver by name and role; its assignment makes that the bundle's answer. Sir Oliver's rollup also held four of House Speaker Jim Wright's entries, joined by name ("James" fits "J.", and the role check counts "from"). On the owner's word, four more assignments give them to the Speaker's own record, 114818.
- **The census ran over S1's v71 library** (§7), since A4's clone `8BE32D39` no longer exists. And `pocom-index.json` was owed: the three kept records each carry a POCOM slug.

**Lane B built, 2026-10-29** (items 1 and 2, on the parent session's brief; branch `claude/strange-cohen-3a0b0b`). The rule is the assessment's (b4) and its §7.2 rule, as §5 says. It moves the person rollup to v14 rather than riding on lane A's unshipped v13 (decision 106). What the build found that corrects this memo or the assessment:
- **The 2026-10-17 notes folder is gone from the Mac**: the facts, the scripts and `identifier-assessment-reads.tsv` with it (§5's second point). The scripts were recovered from that session's transcript, every write and patch replayed, and run unchanged over a new snapshot they give the assessment's own figures, 1,857 Wikidata and 1,609 VIAF ids. The verdicts are recorded in the same transcript, and on the owner's word (plan of record decision 105) the reads are rebuilt from it and committed beside the snapshot; the rule's tests re-score the shipped file against them (95.9% of the links it keeps are right).
- **The port departs from the scripts on three records, each where the scripts were wrong**: they tested an item against a VIAF id a correction withholds (President Taft lost his own item to Taft IV's VIAF id, and Brigadier General James D. Hughes his to a physicist's), and compared a redirected id without following it (Ephraim Evron's VIAF id). The port gives 1,859 and 1,610.
- **Luigi R. Einaudi does not keep his own item** under (b4), as the assessment's §7.2 says he does: his entry carries his grandfather's VIAF id, so the soft test withholds it. Only rule (b1) keeps it.
- **The snapshot holds 4,331 items** (the assessment counted 4,306) and is 1,321,834 bytes (1.24 MB estimated), fetched 2026-10-30 UTC in about ten minutes: three SPARQL queries, 109 `wbgetentities` calls for the items and 127 for their labels.

## 1. In brief

- **Item 5 is done.** A4c's corrections already hold 1981-1988 vol. V's Taft anchor apart from President Taft and join it to Taft IV, and the shipped bundle sends it there (§3). Strike it from the issue.
- **Items 3 and 4 are one mechanism.** A member the bundle marks *apart* never joins a reconciled person's component, and #1658's tie rule marks a member apart when it would join two. One kit change, one generator change, one rollup bump (§4).
- **#1658's named tie is data, not a tie.** Sir Oliver Wright's two uncovered 1981-1988 entries sit beside Jerauld Wright's eleven in one name block, and the registry already has his record, 114825, with his vol. XIII entry. An anchor assignment in the corrections file fixes both entries with no clusterer change; the tie rule is for the cases no one has read (§4.6).
- **Items 1 and 2 stand as designed.** Two facts help the lane: the registry has not moved since the memos (`HistoryAtState/people` master is still `63b537ad`), and the registry's remarks are tied to the anchor each came from, so item 2's rule is exact (§5).
- **This runs on the Mac.** The cloud container has no Swift toolchain and may not reach download.swift.org, wikidata.org, query.wikidata.org, viaf.org or static.history.state.gov; the overlay is a private repository the session was not given; and the package does not build on Linux in any case. What the owner can change about that, and what it would buy, is §6.

## 2. What was read here, and how

- **The repository**: the shipped `person-authority-index.json` (version 2, generated 2026-10-17: 56,029 crosswalk pairs over 285 volumes, 12,836 records, no Wikidata id, 142 VIAF ids, 12,787 role texts) and `PersonAuthorityIndexGenerator/persons-complete-corrections.json` (82 corrections), read with stdlib Python in the scratchpad.
- **The registry**: `HistoryAtState/people`, cloned shallow at `63b537ad`, the memos' own commit and still master on 2026-10-28: 80 MB, 16,312 records, of which 12,836 carry a FRUS source-url and 3,476 none.
- **The corpus**: the 52 files of `HistoryAtState/frus`'s 1981-1988 volumes, a sparse clone at `6170e4b` (A4c's commit), for the Wright entries.
- **The generator and the kit**, read: `PersonAuthorityIndexBuilder.applyOverlay`, `PersonsCompleteCorrections`, `PersonClusterer.cluster`, `IndexingPipeline.loadPersonClusterInputs` and `currentPersonRollupVersion`'s note.
- **Not read**: the overlay (`vak2ve/frus-name-authority`, private; the owner has push access, so a session can be given it), Wikidata and VIAF (denied), and the 2026-10-17 assessment's fetched facts and 300 read verdicts, which are in the Mac's notes folder and not committed.

## 3. Item 5: the Taft IV check is done

The corrections file holds, for 113302 *Taft, William Howard*, the anchor `frus1981-88v05/persons#p_TWHIV_1` with `joins` 113304 *Taft, William Howard, IV*, VIAF 67636647 and the role text *Non-career appointee. Legal Adviser* withheld. The shipped bundle sends that anchor to 113304, with seven more of Taft IV's (1981-1988 vols. IV, XI, XIII, XXIV, XLI and XLIV Part 1, and 1989-1992 vol. XXXI), and the President keeps 1916 Supplement's `p_TWH1` alone. Vol. I's Richard V. Allen, the other case A4 printed, goes to 100308, his own record; 100307 keeps its three 1951-1954 anchors. The issue's item 5 can be struck.

## 4. Items 3 and 4: an *apart* mark, set by the bundle and by the tie rule

### 4.1 What the clusterer does today

Read in `PersonClusterer.cluster` and `normalize`:
- A block is surname plus the first given initial, after titles are dropped (*sir*, *general*, *dr* among them), so *Wright, Sir J. Oliver*, *Wright, John Oliver* and *Wright, Jerauld* share the block `wright|j`.
- Members sharing an authority id are united first. Inside a block, pairs go in input order, which `IndexingPipeline` fixes as `volume_id` then `ref` (#1658). A `.merge` that would unite two components carrying different ids is refused and recorded as a candidate; a `.merge` between an uncovered member and a covered component unites them, and the component keeps its id.
- So an uncovered member compatible with two reconciled people joins whichever pair the order reaches first, and the second is refused. Jerauld Wright's rows are 1951-1968 volumes and sort first.

### 4.2 The members in question

82 corrections: 16 name a record their anchors join, 66 do not. The 66 list 84 anchors; 3 are answered by the registry anyway (Jeane Kirkpatrick's vols. I, III and XIII, to 107237), and **81 are left to the clusterer**. A4c's census over a full library counted what became of them: 60 members a person of their own, 9 rejoined by name the person they were held apart from (Adlai E. Stevenson III, Hamilton Fish III and IV, Frank Murphy, Richard J. Davis, Charlie Wilson, John Hughes of 1982-1985, William G. Miller, the hostage James Hughes), and Myles Greene joined a third person. The registry was checked here for the four the issue names: Fish, Stevenson and Wilson have the merged records only, so no `joins` can reach them.

### 4.3 The mechanism

**One flag, three places.**
- **The bundle** gains an optional key, say `apart`: `volumeId → [ref]`, the anchors that belong to no reconciled person. The generator writes every held-apart anchor whose correction names no `joins` and that no source answered (81 today, counted after `keepVolume`), and prints the count. `PersonAuthorityIndex` decodes it with `decodeIfPresent`, empty by default, so a file without it reads as before; a lookup mirrors `canonicalId(volumeId:ref:)`.
- **The pipeline** sets a new `PersonClusterInput.standsApart: Bool`, default `false`, from the index, through `listSources` as `authorityId` is, so no other caller changes.
- **The clusterer** keeps an `apartRoots` set beside `authorityOfRoot`, carried through every union. A `.merge` whose union would put an apart root with a covered root is refused and recorded as a candidate (*held apart from reconciled identities; possibly the same person*), like the cannot-link. An apart member may still unite with other uncovered members, so two volumes' entries of one unrecorded person roll up together. A user must-link keeps the final say, since `applyConstraints` runs after.

The nine and Greene are then their own people by construction, as the 60 already are. What the sheet shows for them is the volume's own name and description, as for any uncovered person.

### 4.4 The tie rule, on the same flag (item 4)

Before a block's pair loop, for each uncovered member `u` in it, compute `reach(u)`: the authority ids of the covered members `c` in the block with `decide(u, c) == .merge`. Only members of one block are ever compared, so this is exactly the set of reconciled people `u` would join directly. When it holds two or more ids, `u` stands apart for this run, and each refused pair is a candidate naming both ids. The outcome for such a member no longer depends on order.

What stays order-dependent is a chain: `u1` compatible with A alone, `u2` with B alone, and `u1` with `u2`. The key order fixes which of the two the chain's bridge refuses (#1658's first fix), as today. A second variant, **T2**, propagates ids along `.merge` edges until they settle and marks apart every uncovered member that sees two; it is order-independent throughout and more conservative. The census (§7) can run both over the same inputs in one throwaway test and count the members that differ; the owner then picks. **Recommended: T1**, the direct rule, unless T2 moves few members and all for the better.

### 4.5 What it does not fix

- The registry's own merges (the review's §6.3): 113000 holds ten of Adlai Stevenson III's anchors, 114659 Charles Edward Wilson's and Charlie Wilson's, 104298 Hamilton Fish IV's. Those are covered anchors, and the flag never touches a covered member. Upstream's.
- An unrecorded person's entry in a volume no correction names still joins by name, as today.
- A held-apart member who was in fact the keyed person. None is known: every listed anchor was read against its volume (A4c).

### 4.6 Anchor assignments: the Wright case, and a record the builder drops

The registry's 114825 *Wright, Oliver* holds `frus1969-76v36/persons#p_WSO1` and `frus1981-88v13/persons#p_WSJO_1` (*British Ambassador to the United States from September 1982*). Two more entries are his and uncovered: 1981-1988 vol. XLIV Part 1's `p_WSJO_1`, *Wright, Sir J. Oliver, U.K. Ambassador to the United States until 1986*, and vol. I's `p_WJO_1`, *Wright, John Oliver, British Ambassador to the United States from 1982 until 1986*. Both sit in Jerauld Wright's block; the rows of his eleven 1951-1968 anchors sort first; so the order gives them to him.

A new list in the corrections file, say `assigned` (`anchor`, `peopleId`, `registryName`, `reason`), fixes this by data: the builder writes the pair into the crosswalk where no source answers, and refuses to write when the registry names the anchor otherwise, or names `peopleId` otherwise than `registryName`, as it refuses for a `joins`. One rule more: a registry record an assignment or a `joins` names is kept even when it has no FRUS anchor of its own. The builder drops 3,476 such records today, and one is 106238, the *(Robert) John Hughes* the 106247 correction could not join for that reason. Both Wright entries then leave Jerauld Wright for 114825, and the tie rule has one case fewer to decide. The two anchors are also worth sending upstream to `HistoryAtState/people`.

### 4.7 The alternative for item 3, deferred: a synthetic record

A correction could instead give an unrecorded person a record of the bundle's own, with a name, years and role, under a reserved id. The cannot-link then keeps them apart with no clusterer change, every listed anchor rolls up under one name, and the sheet names them. It costs an id convention across the `Int` crosswalk, `AuthorityEntry`, the rollup's majority pick, the sheet's lifespan and role lines, and POCOM, and a rule for what the id means when upstream later mints a real one. The apart flag does what the issue asks with none of that; the synthetic record is the owner's to want.

## 5. Items 1 and 2: what the memos settled, and what this adds

**Item 1, the identifier rule (b4).** The assessment's §7.4 and §9 stand: a committed Wikidata snapshot beside the tool (1.24 MB compact with (b4)'s labels), a stdlib Python refresh tool under `tools/` that refuses to write when an overlay id it would stamp has no facts, the per-id tests in `applyOverlay`, and the VIAF ids' return, which moves the rollup version because the rollup stores `viaf_id`. Three facts for the lane:
- The registry has not moved, so the control (`GENERATED_DATE=2026-10-17` at the base) should still reproduce the shipped file byte for byte, as A4d measured.
- The rule's precision figures (about 96% of 1,857 Wikidata links, about 97% of 1,467 VIAF links) rest on 300 read verdicts in `identifier-assessment-reads.tsv`, uncommitted. The facts can be fetched again in about 110 `wbgetentities` calls and three SPARQL queries; the verdicts cannot. **The lane should commit the reads file** beside the snapshot, so the rule's tests can cite them and a later refresh can re-score.
- The overlay's 824 VIAF ids no Wikidata item holds stay dropped under (b4); reading them costs a day of viaf.org's quota, and is a separate, optional day.

**Item 2, the role text of a multi-id entry.** The registry writes each remark with the source-url it came from:

```xml
<remark source-urls="1">
  <p>British Ambassador to the United States from September 1982</p>
  <source-url>https://history.state.gov/historicaldocuments/frus1981-88v13/persons#p_WSJO_1</source-url>
</remark>
```

So the assessment's rule, *the role text goes only to the ids whose own registry remarks hold it*, is exact per record. `parseRecord` keeps no remarks today; it must keep each record's as `[String]`, and `applyOverlay` compares the entry's role text, as `roleText(from:)` takes it, against each id's remarks with case, dashes and spaces folded. The measured effect stands: 18 records lose another person's role text, 5 that could not be told lose theirs, and 10 duplicates of one person lose their copy while the other record keeps it (102950, 103955, 104525, 109533, 111818, 115687, 115858, 115861, 116018, 116022). No network, no index version, no rollup version.

## 6. Where it runs

| Need | This container, 2026-10-28 |
|---|---|
| Swift toolchain | none installed; download.swift.org denied by the environment's network policy |
| Wikidata and VIAF | www.wikidata.org, query.wikidata.org and viaf.org denied |
| The corpus host | static.history.state.gov denied; `HistoryAtState/frus` clones by git |
| The registry | `HistoryAtState/people` clones by git |
| The overlay | `vak2ve/frus-name-authority` is private; the session was not given it |
| The assessment's facts and verdicts | on the Mac, uncommitted |

Even with a toolchain, this repository's package does not build on Linux: FRUSCoreKit there needs the web edition's `CSQLite` and swift-crypto, which `Package.swift` here does not declare, and `PersonAuthorityIndexGeneratorCore` uses `XMLDocument` with `import Foundation` alone, so it needs `FoundationXML` behind `canImport` before it compiles there. The three runs a shared-code change owes (`swift build --target FRUSCoreKit`, `swift test`, the unit target) and the Mac build are Mac runs, and so is the full-library census, which needs an index of 553 volumes (654 s and 2.9 GB through the kit, or A4's clone of the pinned iPhone 17e).

**What the owner can change, and what it buys.** Adding download.swift.org, www.wikidata.org, query.wikidata.org and viaf.org under the environment's Allowed domains, and a Swift install to its setup script, lets a cloud session fetch and commit the Wikidata snapshot, write and run the refresh tool, and compile and test the generator target alone once it imports `FoundationXML`. Giving the session `vak2ve/frus-name-authority` lets it run the generator with the overlay and measure items 1 and 2 record for record. None of it buys the kit's runs, the unit target, the Mac build or the census.

## 7. The lane, for the Mac

Two pull requests, one build, so one rollup bump carries both; in the serial queue after submission, as decision 96 places it.

**Lane A, items 3 and 4 with §4.6** (kit and generator; `currentPersonRollupVersion` 12 → 13):
1. The control: the generator at the base with `GENERATED_DATE=2026-10-17`, byte for byte against the shipped file (A4d's inputs: people `63b537ad`, name-authority `cb8b0a5`).
2. The generator: the `apart` section, the `assigned` list with its refusals, and a kept record for a named id; the two Wright assignments; tests for each refusal and for the Hughes record.
3. The kit: `PersonAuthorityIndex.apart`, `PersonClusterInput.standsApart`, `loadPersonClusterInputs`, the clusterer's `apartRoots` with the tie pre-pass, and the version note. Tests over synthetic inputs: an apart member beside one covered namesake, beside two, the chain, a must-link over an apart member, and the order test of #1658 extended to the tie.
4. The census on A4's clone (`8BE32D39`: 553 volumes, index v69, 63,667 members; 13.6 s a rebuild in debug through a throwaway package test): the base's rollup member for member, then this branch's, with T1 and T2 both, each member that moves listed by name and the nine confirmed apart.
5. `swift build --target FRUSCoreKit`, `swift test`, the unit target, the Mac build; POCOM not owed unless a slug moves (none should).
6. Docs: the runbook's `PersonAuthorityIndexGenerator` entry, `DEVELOPMENT-PLAN.md`, the plan of record's P2 line, a line for the web edition (the kit model and the bundle change), and the version note.

**Lane B, items 1 and 2** (generator, snapshot and tool; the bundle):
1. The control again at its own base.
2. The snapshot and its refresh tool, with the reads file committed; the rule with corpus fixtures (the Kennedys, McKee and Denton, Brezhnev and the carrier, the Castros, the Einaudis, Truman's nephew); `Overlay.takesIdentifiers` turned on by the runner through the rule.
3. The remarks kept by `parseRecord` and §7.2's rule, with the ten duplicates as fixtures.
4. The regenerated file and its diff against the control, record for record; `swift test`; the unit target, whose bundled-file tests read the new file; the Mac build.
5. Docs: the runbook, both manuals' People sentence (iOS 6.5, macOS 6.3: *a VIAF link for about one person in ninety, no Wikidata link* becomes about one in seven and one in eight), the assessment's §8 pointed here, `DEVELOPMENT-PLAN.md`, the plan of record.

If B lands in the same build as A, v13 carries its VIAF ids; if later, it moves the version again.

## 8. Decisions for the owner

1. **Item 3**: the apart flag (§4.3, recommended) or a synthetic record (§4.7).
2. **Item 4**: T1, the direct rule (recommended), or T2, the propagated one, after the census counts the difference.
3. **Anchor assignments** (§4.6): add the list, and send the two Wright anchors upstream.
4. **Commit the 2026-10-17 reads** with the snapshot.
5. **The cloud environment**: the four hosts and the toolchain, and the overlay repository, if cloud sessions are to run the generator at all.
6. **One build for both lanes**, so one rollup bump carries both.

## 9. Redoing it

Every figure above came from stdlib Python over the files named in §2, run in the session's scratchpad and not committed: the bundle's crosswalk and counts, the corrections' `joins`, the registry's records by `<id>` and by preferred name, and the 1981-1988 persons lists by `xml:id`. Nothing was fetched from Wikidata or VIAF.
