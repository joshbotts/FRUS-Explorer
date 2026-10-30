# The person authority's Wikidata and VIAF ids, and the overlay entries that carry several people: an assessment, 2026-10-17

**What this is.** The assessment of the two findings A4c sized and left (plan of record §6g; `Planning/Person-Authority-Overlay-Review-2026-10-17.md` §6.1 and §6.2), worked on the owner's word of 2026-10-17 after #1709 merged, based on `v2` at `b3272d86`. It measures how many of `person-authority-index.json`'s Wikidata and VIAF ids name someone else, what the overlay's multi-id entries stamp on each of their ids, and what each way of fixing them would do to the bundle. Nothing in this memo's measurements changed the generator, the corrections, the bundled file or any version. **Decided on 2026-10-17** (plan of record decision 55): option (c) for build 51, built as A4d, and the fix deferred to a later release (§8).

## 1. In brief

- **About 1,600 of the bundle's 3,769 Wikidata links name someone else (42%)**, not the 450 A4c estimated. A4c counted only the records failing its rough test (540, of which 34 in 40 were wrong). Two groups it did not size hold most of the rest: links that fail a finer test, such as a given name that differs or a VIAF id that belongs to another item (about 85% wrong), and links that fail nothing, because a name-only match with no life years on Wikidata cannot be contradicted (about 18% wrong, some 440 links). Senator Paul M. Simon wears the singer-songwriter's item, Herbert Hoover Jr. his father's, Helmut Kohl his wife's, and Leonid Brezhnev the aircraft carrier *Admiral Kuznetsov*.
- **About a quarter of the overlay's 3,010 VIAF ids name someone else**: about 580 of the 2,186 that could be sized. 824 could not be sized today, because no Wikidata item holds them and viaf.org allows this address 1,003 requests a day.
- **15 of the 31 entries carrying several people-ids are different people** (A4c named 12; also Luigi Einaudi, Harry Truman and David LeBreton). 18 records wear another person's role text: the President of Italy wears his grandson's post at the Organization of American States, and Truman's nephew wears *President of the United States, 1945-53*. The identifiers on these entries are mostly name-only matches to a third person, so they are item 1's problem as much as item 2's: all four Donald MacDonalds wear a silent-film actor.
- **Recommended** (§8): a rule in the generator, reading a committed snapshot of Wikidata (CC0). An overlay id is kept only when its item is a person whose names and years fit the record, and something independent agrees: the overlay's VIAF id, the registry's life years, or the record's own registry remarks. A multi-id entry's role text goes only to the ids whose registry remarks hold it. Measured: 1,857 Wikidata links at about 96% right (from 3,769 at 57%), 1,609 VIAF links (1,467 of them the overlay's) at about 97%, and no wrong role on a multi-id entry. The bundle shrinks by 59,645 bytes, with no index version and no rollup membership change.

## 2. How it was measured

- **Inputs** as A4c had them: `HistoryAtState/people` at `63b537ad`, `frus-name-authority` at `cb8b0a5`, and the shipped bundle at `b3272d86` (2,532,807 bytes, SHA-256 `a53e0c9a…`, generated 2026-10-16).
- **The control**: the generator at `b3272d86` with `GENERATED_DATE=2026-10-16` reproduced the shipped file byte for byte.
- **Item facts, fetched 2026-10-17** and kept outside the repository (§10). From Wikidata (`wbgetentities`, 40 ids a call), every one of the 6,809 Wikidata ids in `persons-complete.xml` (the bundle's 3,498 distinct ids among them) and the 1,725 more items that hold those VIAF ids. That is 8,534 items with labels, aliases, life years, instance of, occupations, positions and VIAF ids: 5 were redirects and 1 was deleted. Also the labels of the 13,659 items those claims name. From query.wikidata.org, which still answers this client once a minute, the holder of each of the 5,992 VIAF ids, in four queries: 3,961 are held. From viaf.org, 967 clusters (961 records and 6 abandoned ones), before `x-ratelimit-limit-day: 1003` stopped it. The limit resets at 00:00 UTC.
- **A Python mirror of `applyOverlay`** records which overlay entry gave each record its Wikidata id, VIAF id and role text. It reproduces the shipped values for all 12,836 records, and the bundle it writes is the shipped file byte for byte. Every option in §7 is a stamping rule over the mirror, so each option's numbers are counts in a real file, not estimates. Option (a) was also run through the generator itself (§7.3).
- **Reading.** 190 Wikidata links drawn at random from three strata (40 failing a hard test, 50 failing only a soft one, 100 failing nothing). Then 60 more to check the rules: 30 that (b3) keeps, and 30 that (b3) drops and (b2) keeps. Then 50 VIAF ids: 30 held by another Wikidata item and 20 read on viaf.org. Then 20 the VIAF-holder step keeps, and all 31 multi-id entries, id by id. Each was read from the fetched facts (the item's label, description, life years, occupations and positions, or VIAF's headings and dates) against the record (its registry name and years, its volumes, its role, and its registry remarks). Estimates for the whole bundle weight each stratum by its size. Every verdict is in `identifier-assessment-reads.tsv` (§10).

## 3. The Wikidata ids

A4c's rough test, reproduced: **544 records fail** (A4c had 540). The finer tests add the registry's own life years (1,257 records have a birth year, 874 a death year), the record's first FRUS volume taken from its registry anchors, transliteration (ö and oe, ß and ss), common nicknames, and the instance-of statement.

| Test | Records failing |
|---|---:|
| **Hard**: the item is not a person | 176 |
| **Hard**: born after, or less than 15 years before, the record's first volume | 245 |
| **Hard**: died more than 40 years before it | 200 |
| **Hard**: no word of the record's surname in any of the item's names | 112 |
| **Hard**: a birth or death year more than a year from the registry's | 181 / 77 |
| **Any hard test** | **801** |
| **Soft only**: a given name or middle initial that differs (*John F.* against *John N.*) | 273 |
| **Soft only**: the record's VIAF id is held by another Wikidata item | 306 |
| **Any soft test, no hard one** | **536** |
| **Fails nothing** | **2,432** |

The sample was drawn from the first pass of these tests, before the transliteration fold, when the strata were 806, 502 and 2,461. The estimates weight by those figures.

| Stratum (records) | Read | Someone else | Right | Could not tell | Estimated wrong |
|---|---:|---:|---:|---:|---:|
| Hard (806) | 40 | 37 | 2 | 1 | ~750 |
| Soft only (502) | 50 | 40 | 7 | 3 | ~400-430 |
| Fails nothing (2,461) | 100 | 18 | 82 | 0 | ~440 |
| **All 3,769** | 190 | | | | **~1,600** (about 1,400-1,850 at 95%) |

What the wrong ones are:
- **Not a person (176)**: 64 NARA holdings (*Anne L. Armstrong's Files (NAID 6117716)*; *Martin Hillenbrand, Ambassador to Germany (NAID 122292709)*), 26 newspaper obituaries, 16 disambiguation pages, 11 articles, 8 name items, and 51 other things. Brezhnev wears the aircraft carrier *Admiral Kuznetsov*, Yuri Andropov the cruiser *Pyotr Velikiy*, Eduardo Mondlane the university named after him, and Rowland Evans, Jr. a merchant ship.
- **Namesakes**, the most common case. Senator Paul M. Simon wears the singer-songwriter (Q4028), Major General Carl R. Smith a country singer, Robert W. Fri of the EPA the guitarist Robert Fripp, and Governor Abdul Monem Khan of East Pakistan a Singaporean badminton player born in 1999. Thomas Wilson of the State Department wears a New Zealand geologist, and Jordan's Foreign Minister Hassan al-Ibrahim a Saudi cyclist born in 2000.
- **Family members**, whose names and eras fit. Herbert Hoover Jr. wears his father (Q35236), Hodding Carter III his father, Helmut Kohl Hannelore Kohl, Gustav Dahrendorf his son Ralf, "Ramfis" Trujillo his father, Bruce C. Clarke, Jr. his father, and Jon M. Huntsman, Sr. his son.
- **The two the hard tests got wrong** were spellings: Manfred Woerner against *Manfred Wörner* (since folded), and Mamdouh Salim against *Mamdouh Salem*.
- **John F. Kennedy's record** (107025) wears John N. Kennedy (Q6250211), as A4c found; every rule in §7 removes it. Kinnaird R. McKee's (108893) wears Jeremiah Denton, and its VIAF id is McKee's own (held by Q6414023).

## 4. The VIAF ids

3,152 records carry a VIAF id. 142 come from the registry, which wins by design and is left alone; 3,010 come from the overlay. The overlay's VIAF ids were not simply copied from its Wikidata items. Of the 4,451 overlay entries carrying both, the item holds the entry's VIAF id in 2,319, holds another in 706, and holds none in 1,426.

| Route (overlay VIAF ids) | Ids | Read | Someone else | Estimated wrong |
|---|---:|---:|---:|---:|
| Held by the record's own Wikidata item: right exactly when that item is | 1,283 | through the Wikidata sample | | ~170 |
| Held by another Wikidata item, whose facts were tested against the record | 763 | 30 | 14 (1 could not tell) | ~370 |
| Held by no item, read on viaf.org | 140 | 20 | 5 (3 could not tell) | ~40 |
| Held by no item, not read | 824 | | | not sized |

The Wikidata route and viaf.org agree on 362 of the 375 records both could test (96.5%). Admiral Thomas B. Hayward, Chief of Naval Operations, wears an operatic tenor. General Douglas MacArthur (108250) wears his nephew Douglas MacArthur II's VIAF id, and the nephew (108251) the General's Wikidata id. A Japanese Foreign Ministry director-general, Toshio Yamazaki, wears a waka poet, and Thomas M. T. Niles (born 1939) a Thomas Niles of 1825-1894. **Not sized**: the 824 no Wikidata item holds. Reading them on viaf.org takes one day's quota.

## 5. The entries carrying several people-ids

64 entries carry two or more people-ids; 31 carry two or more the bundle knows. None is skipped by the audit guard. Read id by id against each id's own registry remarks:

| Kind | Entries |
|---|---|
| **Different people (15)** | Bernadotte (Prince Carl junior, 115190, and senior, 115191); Castro (Raúl Castro, 102311, and Raul H. Castro, U.S. ambassador, 102312); Donovan, James (a USAF colonel, 115397, and James B. Donovan, the New York lawyer, 103588); Donovan, John (INR, 103589, and the Children's Book Council, 115398); Einaudi (the President of Italy, 103878, and Luigi R. Einaudi, 103879); Graham (Sir John Graham at NATO, 115548, and John S. Graham of the AEC, 105093; the entry's role is the acting Secretary of State of 1817's); Hughes (106247 and 106248; A4c's correction already withholds all three of the entry's values); LeBreton (the Consul General at Tunis, 107761, and the admiral, 115749); MacDonald (four men, 108262 to 108265); Mueller (109500 and 109501); Peterson (the Consul General in Greece, 110612, and Peter G. Peterson, 110613); Sanders (AIPAC, 111889, and OMB, 111890); Simmons (Atlantic Richfield, 112498, and John Farr Simmons, 112499); Truman (the President's nephew, 116214, and the President, 113770); Walsh (Defense, 114233, and John P. Walsh, 116252 and 114234) |
| **One person the registry holds twice (13)** | Craig, Ely, Fraser, Ibn Saud, Kane, Kelley, Meyner, Mikołajczyk, Muñiz, Redecker, Regan, Sakellariou, Szanton |
| **Could not tell (3)** | Bowman, Galloway, Quinn |

What they stamp today:
- **Role text on 63 ids**: 18 wear another person's, 40 their own, and 5 could not be told.
- **Wikidata ids on 39 ids**: 7 right and 32 wrong. Most of the wrong ones are another person altogether: both Muñiz records wear a Spanish playwright, the three Walsh records a Montana senator born in 1960, and the MacDonalds a silent-film actor.
- **VIAF ids on 36 ids**: 8 right, 14 wrong and 14 not sized. Einaudi's entry carries the grandson's Wikidata id and the grandfather's VIAF id.

## 6. Where these reach the reader

- **The Wikidata link** (`PersonIndexView`, "View on Wikidata") and **the role line** (`registerRole`) are read from the bundled index when the sheet opens (`authorityEntry`). A changed bundle shows at once.
- **The VIAF link** reads the rollup row's `viaf_id`, which `consolidatePersonRollup` writes from the bundle when the rollup is rebuilt. A changed VIAF id reaches a library at its next rebuild. If it ships in build 51, v12's rebuild carries it, and every build-50 library makes that rebuild once. After build 51 it needs v13, or rides on the next bump.
- **Neither affects who is who.** The clusterer reads no VIAF or Wikidata id, and the crosswalk does not change, so rollup membership and the People counts stay as they are. No index version is owed. `pocom-index.json` is not owed, since no slug moves.
- **The manuals** (iOS 6.5, macOS 6.3) tell the reader these links exist for "roughly a quarter to a third of the authority entries". Today that is 29% and 25%. Under the recommended rule it would be about 14% and 13%, and the sentence would change with the build.
- **For the web edition**: no kit code changes in any option; the bundled authority file does.

## 7. The options, measured

### 7.1 The identifiers

Counts are the bundle each option writes, through the mirror. "Right" is the share of kept links the sample reads as the record's person, and "Right lost" is the estimated right Wikidata links each option removes. VIAF shares are of the overlay's ids that could be sized, with the 824 not sized shown apart.

| Option | Wikidata kept | Right | Right lost | Overlay VIAF kept | Right (sized) | Bundle |
|---|---:|---:|---:|---:|---:|---:|
| Today | 3,769 | ~57% (~1,600 wrong) | — | 3,010 | ~73% (~580 wrong), 824 not sized | 2,532,807 |
| (a) Identifier-only corrections, every hard failure read first | 2,966 | ~71% | ~20 + the multi-id losses (§7.3) | 2,795 | ~80%, 824 not sized | — |
| (b1) Rule: withhold a hard failure | 2,968 | ~71% (~850 wrong) | ~20 | 2,798 | ~80% (~400 wrong), 824 not sized | 2,516,955 |
| (b2) Rule: withhold any failure | 2,430 | ~82% (~440 wrong) | ~115 | 2,611 | ~89% (~190 wrong), 824 not sized | 2,505,553 |
| (b3) Rule: keep only what is corroborated (the overlay's VIAF id agrees, or the registry's years) | 1,355 | ~98% (~28 wrong) | ~970 | 1,148 | ~98% | 2,463,185 |
| **(b4) As (b3), or a word of the record's registry remarks in the item's description, positions or occupations; and a VIAF id whose own holder passes the same way** | **1,857** | **~96% (~75 wrong)** | **~380** | **1,467** | **~97% (~40 wrong)** | **2,473,162** (with §7.2's rule) |
| (c) Withhold every overlay id | 0 | — | ~2,130 | 0 | — | 2,425,394 |

- **(b3) and (b4) were checked on fresh samples.** 29 of 30 kept by (b3) are right. The one miss is Sir William Luce, Political Resident in the Gulf, who wears the American librettist William Luce, whose VIAF id the overlay took too, so the two ids agree. Of 30 that (b3) drops and (b2) keeps, 19 are right (Golda Meir, Chiang Ching-kuo, Nguyen Cao Ky, Médici) and 10 wrong. (b4)'s role words keep 9 of the 19 right ones and none of the 10 wrong.
- **(b4)'s VIAF step** keeps a VIAF id when no accepted Wikidata item holds it, but the item that does hold it passes the tests and is corroborated by the registry's years or a role word. Holding the VIAF id itself counts for nothing there. 319 VIAF ids come back this way. 28 of the 29 read are right (Theodore H. White, Leon Jaworski, Daniel arap Moi, Christian Herter, Nikolai Podgorny). The miss is General MacArthur's record, which takes his nephew's VIAF id on the shared word *Japan*.
- **What none of the rules can see**: two relatives of one name and era (Truman's nephew keeps the President's item under (b3) and (b4), through the word *President* in his own remark), and an overlay that took both ids from one wrong item. The Muñiz pair keeps the playwright's two ids, which agree with each other.
- **What (b3) and (b4) cost in VIAF**: the 824 ids no Wikidata item holds are all dropped, since nothing can corroborate them. If they are like the 140 read on viaf.org, about 600 of them are right.

### 7.2 A multi-id entry's role text

Measured on the 63 ids that take a role from the 31 entries:

| Rule | Another's role kept (of 18) | Own role lost (of 40) | Could not tell, removed (of 5) |
|---|---:|---:|---:|
| Today | 18 | 0 | 0 |
| The first known id only (as the crosswalk already does for anchors) | 5 | 17 | 3 |
| None of the entry's ids | 0 | 40 | 5 |
| **The ids whose own registry remarks hold the role text** (case, dashes and spaces aside) | **0** | **10** | 5 |

The 10 lost under the remarks rule are all duplicates of one person, and each one's other record keeps the role: 102950 Craig, 103955 Ely, 104525 Fraser, 109533 Muñiz, 111818 Sakellariou, 115687 Kelley, 115858 Meyner, 115861 Mikołajczyk, 116018 Redecker and 116022 Regan. A record's own sheet still shows the volume's description. The identifiers of these entries need no rule of their own under (b1) to (b4), which test each id against each record. Raúl Castro keeps Q46809 and Raul H. Castro loses it, and the President of Italy keeps his VIAF id while his grandson keeps his Wikidata id.

### 7.3 Option (a) through the generator itself, and why it cannot divide an entry

Written as identifier-only corrections in `persons-complete-corrections.json`, the hard failures alone take **896 new corrections, plus 2 merged into A4c's**. The file grows from 1,193 lines to 9,257 before any reasons are written, and every id is first read on wikidata.org. Run through the generator in a scratch worktree, the result matches the mirror's per-record rule (b1) on every record but four, and those four are §6.2's limitation in the generator's own output. A correction for Raul H. Castro withholds Q46809 and 97724278 from every id of the entry, so Raúl Castro loses both. Corrections for the two Einaudis take the President's VIAF id and his grandson's Wikidata id from both. Covering the hard failures, option (a) reaches (b1)'s 71%. Covering the soft ones too takes 536 more reads, for about (b2)'s 82%. The wrong links that pass every test (about 440) can be found only by reading all 2,432 passing links.

### 7.4 What a rule needs

- **A snapshot of the item facts committed beside the tool** (`PersonAuthorityIndexGenerator/`, read by path from the project root as the corrections are). It holds the 3,540 overlay Wikidata ids that can reach a bundled record and the 766 more items that hold the overlay's VIAF ids: 4,306 items and 2,073 VIAF-holder rows. That is **0.62 MB compact** (0.94 MB indented) for (b1) to (b3), or **1.24 MB** (1.70 MB indented) with (b4)'s description, position and occupation labels. Wikidata is CC0. (b3) and (b4) need no VIAF data, which is ODC-By; (b1) and (b2) can test the 964 ids no Wikidata item holds only by committing VIAF's headings and dates.
- **A tool to refresh it**, stdlib Python under `tools/` like the corpus tools: about 110 `wbgetentities` calls and their labels, and three SPARQL queries a minute apart. The run itself stays offline and reproducible. It should **refuse to write** when an overlay id it would stamp has no facts, as the corrections refuse when they no longer fit, so a new overlay drop forces a refresh rather than passing unread.
- **The rule**, in `PersonAuthorityIndexGeneratorCore`, which is not shared code. It needs the snapshot's loader and checks, and the tests of §3, applied per entry and id in `applyOverlay`. For (b4), the registry's remarks, which the builder reads today and does not keep, and a stopword and nationality list. For §7.2, the same remarks. The run should print every withheld id with its reason, as it prints the registry's disagreements. Its word lists and thresholds are part of the rule: a change to one changes the bundle, and each change is measured against the control.

## 8. Recommendation, and the owner's choice

**Recommended: (b4) with §7.2's remarks rule, before build 51.** Build 51 is the first public release, and today it would show about 1,600 wrong Wikidata links and some 700 wrong VIAF links from the person sheet (about 580 among those sized, and perhaps 200 among the 824 not). (b4) keeps about five in six of the right Wikidata links (about 1,780 of 2,130) and leaves about 75 wrong. Its VIAF change rides on v12's rebuild if it lands before build 51. It moves no index version and changes no person's membership. The work fits one lane: a snapshot, a tool, the rule with corpus fixtures (John F. Kennedy and John N. Kennedy, McKee and Denton, Brezhnev and the carrier, the Castros, the Einaudis, Truman's nephew), a control at the base, the regenerated file, and the manuals' sentence.

**The alternatives, in order of preference:**
- **(b3)** if the owner wants no word lists: about 98% right, at about 600 more right links lost (Golda Meir among them).
- **(c) for build 51 alone** if a lane cannot be fitted before it: a change of a few lines that removes every wrong link and every right one, with (b4) to follow. The VIAF half would then need a v13 bump after build 51.
- **(b2)** if coverage matters more than precision: 82%, about 440 wrong.
- **(a)** only for exceptions. It does not scale (§7.3), and it cannot divide a multi-id entry.

**The owner's choice, 2026-10-17** (decision 55): "Option c - withhold VIAF from build 51. Defer fix to later release." Build 51 takes none of the overlay's Wikidata and VIAF ids (A4d): the regenerated file has no Wikidata id and 142 VIAF ids, the registry's own, and matches §7.1's option (c) record for record. (b4) and §7.2's rule are deferred; restoring VIAF ids will need a rollup bump, since build 51's rebuild is v12's. **Not proposed**, but measured and open: deriving a record's Wikidata id from the item that holds its VIAF id, which would give 319 records a link (199 whose overlay id (b4) withholds, 120 that had none), 28 of 29 read right; reading the 824 unheld VIAF ids on viaf.org (a day's quota); and telling `frus-name-authority` upstream which of its ids fail, which is the owner's to send.

**Built on 2026-10-29** as #1767's lane B (`Planning/Person-Authority-Lane-Design-2026-10-28.md` §7, whose header says what the build found): (b4) and §7.2's rule, over a Wikidata snapshot committed beside the generator. 1,859 Wikidata ids and 1,610 VIAF ids, and no wrong role on a multi-id entry. One sentence of §7.2 does not hold for (b4): Luigi R. Einaudi loses his own Wikidata id, since his entry carries his grandfather's VIAF id. And the VIAF figure of §7.1, about 97% (about 40 wrong), is not what §10's reads give: with them alone the estimator gives 95.8% (about 62 wrong), as it printed on 2026-10-17. The 97% also counts 20 reads of the VIAF-holder step ("28 of the 29") that were judged after `identifier-assessment-reads.tsv` was written and never recorded in it; the file, rebuilt and committed beside the generator in lane B, says so in its header.

## 9. What a build would owe

The control at its base; the snapshot and its tool; the rule and its tests, with a fixture for each test from the corpus; the regenerated `person-authority-index.json` and its diff against the control, record by record; `swift test` (the generator's suites are package suites) and the unit target, whose bundled-file tests read the new file; and the Mac build. No index version. No rollup version if it ships in build 51 (v12's rebuild carries the VIAF ids), and v13 if after. POCOM checked (no slug moves). The runbook's `PersonAuthorityIndexGenerator` entry; the manuals' People sections (iOS 6.5, macOS 6.3: "roughly a quarter to a third"); the A4c review's §6.1 and §6.2 pointed here; the plan of record; and `DEVELOPMENT-PLAN.md`. For the web edition, the bundled file changes and the kits do not.

## 10. Redoing it

The facts are in this session group's notes folder (`authority-item-facts/`, 8.5 MB, with a README). The scripts and the verdicts are in `identifier-assessment-scripts/`, and every read record is in `identifier-assessment-reads.tsv`: `collect_ids.py`, `fetch_wikidata.py`, `fetch_viaf.py` (resumable, against the daily limit) and `sparql_viaf_holders.py`, then `authority_mirror.py` (the mirror, with `verify()` holding it to the shipped file), `classify.py`, `overlap.py`, `simulate.py` (every option's bundle) and `final_scores.py`. None of this is committed. A build lane would commit only the snapshot and its tool.
