# Plan of record — from 2026-11-25

**Base:** `v2` @ `9325f79d` (2026-11-25, #2009's merge). The tree reads version 1.0, build 1861: the build archived from `08e8bac8`, tagged `1.0-release`, submitted on 2026-11-20, released on 2026-11-21 and in every storefront since 2026-11-22. Nineteen pull requests have merged since that tag, #1961 to #2009:
- six of records and the website (#1961 to #1966);
- eleven for FRUS Explorer Light, which move app code into `FRUSCoreKit` or add kit API and tests (#1967 to #1969, #1979 to #1983, #1985, #1987, #1988): 98 files and about 8,500 added lines under the app's and the kits' folders, each meant to change nothing the app does, and none yet in a build a reader has;
- two of planning, the Collections design (#2008, #2009).

No bundled data file has changed since the tag. Index **v75**, person rollup **v15**, EmbeddingGemma 2 vectors under digest `89481b18`, 553 volumes, 41 bundled data files. Forty-two issues are open: 33 filed since the 2026-11-15 plan was written, and nine that plan had placed. §1a places all 42. A forty-third and a forty-fourth, #2012 and #2013, were filed the same day from this plan's own reading, on the owner's word (decisions 186 and 187), and §1a places them too.

**Status: LIVE — the plan of record from 2026-11-25.** The owner answered its questions the same day, one at a time, and the answers are decisions 147 to 183 (§0). Later that day the owner asked for one more row, which is L56 (decision 184), took its four proposals (185), and had two findings of its reading filed, as #2012 (186) and #2013 (187). #2013 has a row of its own, L57. On 2026-11-26 CR's review asked four things more of index version 76, which the owner added to it (188 to 191), and C2's answers followed (192 to 202), then L31's four (203 to 206). That evening L28's rehearsal found two generators' defects, which the owner had filed as #2022 and #2023, to be fixed before R10 in a row of their own, L61, and had the root checkout's stale map layout replaced (207 to 209). On 2026-11-27 L57's finding about days whose midnight a change of clocks skips was filed, as #2033 (210). §4 lists what is still the owner's. It supersedes `Completed/Plan-Of-Record-2026-11-15.md`, whose Track A ran from L15 to R3: 1.0 (1823) on TestFlight, the device pass, and 1.0 (1861) submitted and released. Its §3 left the order of the release after 1.0 to "the next plan". This is that plan.

It is written from six sources:
- the owner's instruction of 2026-11-25 (decision 145), the owner's word on the draft (146), the answers (147 to 183), and the row the owner asked for afterwards, with what the owner then said of it (184 to 187), and the owner's answers to CR's four questions on index version 76 (188 to 191), with the owner's two answers to L26's questions on the last;
- the 42 open issues (§1a says how each was read), with the code checked at `9325f79d` for fourteen of them (#2010, #2005, #1999, #1990, #1989, #1986, #1978, #1977, #1976, #1975, #1974, #1973, #1971 and #1970);
- `Planning/Collections-Customization-Design-2026-11-25.md` and its two reviews, whose §9 lanes this plan takes as rows and whose §10 questions the owner answered (decisions 153 to 174);
- `Planning/New-Volume-Release-Plan.md`, the runbook the Office's release sets off;
- the 2026-11-15 plan's §3 and §5: the findings the owner sent to the first update (F1, F2, F7, F11 and D1), its other candidates, and its backlog;
- the code at `9325f79d`, read again for the rows the answers added: the collection's model, the index's tables, the three Zotero sends, the entitlements, the stores a Debug build opens, and the archive's CloudKit gate; and, for L56, Chronology's screen and its rules, the index's reads of a range of dates, and the working corpus's record; and, for L57, Search's two view models and its filter's pickers.

**No app was built or run.** The session's container has no Xcode and no Swift toolchain. Every statement about behaviour is read from the code, from an issue, or from an earlier session's record, and says which. The Collections rows, which are Waves 4 to 6, are read from a design that has not been reviewed, and are provisional until its review (CR) and the checkpoint after it (C2).

§7 struck: 0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 14, 15. (These are the Visual Marketing Plan's §7 steps that are done, unchanged since 2026-10-21; `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan` checks the list. The line names that plan's §7; this file has no §7 of its own.)

**In brief:**
- **One update, version 1.1, when both are done** (decisions 148 and 150): the Office's next volume taken in, and the whole Collections overhaul built. *E* is the day the Office of the Historian publishes. A new volume is invisible in the app until a build ships (`New-Volume-Release-Plan.md` §1), so from E until 1.1 is released a reader of 1.0 does not have it.
- **Thirty-six rows in six waves, L26 to L61, and a review.** A wave's rows are developed side by side where their files do not meet, and landed one at a time. Fixes in the same code share a row: the 42 issues, five findings, the owner's picks from the design, the row the owner added (decision 184) and a row for an issue filed since (decision 187) come to thirty-two pull requests, C2's three splits (decision 199) to thirty-five, and the two defects L28's rehearsal found (decisions 207 and 208) to thirty-six. A row keeps the number it was first given, so the waves give the order and the numbers do not: L56 lands in Wave 3, L57 and L61 in Wave 2, L58 and L59 in Wave 5, and L60 last of all the Collections rows.
- **Wave 1 is what every build of 1.1 must carry:** index version 76, the re-index it sets off, and a rehearsal of the runbook on this tree. Version 76 now also stores each document's linked terms, for a block that Wave 6 adds (decision 172).
- **Wave 2 is wrong facts,** most of them found by the web edition's full-corpus checks; research notes that four exports send where the author switched them off; the days of Search's date filter on iPhone and iPad (L57); and two generators' guards that R10 needs (L61).
- **An early build goes to TestFlight after Waves 1 and 2** (decision 151). It takes the one re-index and the long device pass.
- **Wave 3 is what the owner sent to the first update,** with the Zotero row and two rows of saves: #1990, the cross-reference graph saved as a working corpus or an Archives Visit, and L56, a range of Chronology saved as a working corpus (decision 184).
- **Collections is reviewed first** (CR; decision 149), **then built in three waves.** Wave 4 stores nothing: one plan for three formats, export from the lists, the preview's repairs. Wave 5 adds the stored facts and trims the three surfaces. Wave 6 is the owner's picks from the design's two lists of candidates, nine from one and eight from the other. The design's lane 5 is not built (decision 156).
- **1.1 changes the CloudKit schema:** seven stored fields or eight, and one record type. The owner promotes them to Production once, before the release candidate is archived.
- **When the Office publishes, the volume is taken in at once, with the queue paused** (decision 152). It ships with 1.1.
- **39 of the 42 issues are in a row, each of them whole** but #1923's resume, which waits for its design. Three are not in this update: #1723 is a feature that waits on a device check, #1696 waits on the Office's subject export, and #234 is deferred (decision 92). #2012 and #2013, filed since (decisions 186 and 187), are in L56 and L57.
- **The calendar is arithmetic and not a promise.** At two rows merged a day with no day lost, the submission falls about 2026-12-20. If the Office publishes in the first week of December, the new volume is out of the app for about three weeks, or more.

---

## 0. Decisions, and the rules that still bind

**Decisions carried.** Their full text stays in `Completed/Plan-Of-Record-2026-11-15.md` (126 to 144), `Completed/Plan-Of-Record-2026-10-21.md` (84 to 125) and `Completed/Plan-Of-Record-2026-10-14.md` (1 to 83). This plan relies on these:
- 17 and 18: EmbeddingGemma 2 under Apache 2.0. The release's harvest (R10) runs it as B2 did.
- 28 to 36 and 58: the listing, free in every storefront, English only, the privacy label (Data Not Collected), and the Privacy Policy and Support pages. The update changes none of them.
- 71 and 92: #1696 waits for the Office's subject export; #234 is deferred indefinitely.
- 88: a retake sitting follows the fixes, before submission, for every screen they change. It is T3 here (R11).
- 94: the manuals carry their *AI Generated* notice until the manual review, which is still owed (§4).
- 113: `1.0-release` tags the submitted commit. The update's submitted commit is tagged the same way, and a TestFlight build's tag is the owner's call.
- 134: the release checklist runs the full unit target on iOS 27.0 and iOS 27.2.
- 135 and 136: *Subjects* with its one caption, and the in-app browser kept to its opening page's host, as shipped.
- 138: #1923 to #1926 are one Zotero row. It is L41.
- 139: the six Collections templates. L44 divides each into two steps, and decision 167 renames three of them.
- The runbook's own, of 2026-09-02 (`New-Volume-Release-Plan.md` §11): the gap between the Office's publication and this app's release stays silent, and is kept short (D-1), of which decision 148 sets the second half aside for this release; the map is rebuilt every release (D-2); a release ships without subject tags or the person crosswalk for a new volume when those drops lag (D-4); and each release ships as it comes, not batched (D-5). D-3, the harvest guard, is done (#1177).

**The owner's instruction of 2026-11-25**, which this plan is written from:

145. **An updated plan of record: the open issues assessed and triaged into fix waves, fixes that touch the same code consolidated, the Collections overhaul included, the app made ready for a new FRUS release in early December, and an update shipped to the App Store after that release.** The owner's words: "Let's develop an updated plan of record. Assess open issues and triage them into fix waves. Try to consolidate fixes that touch the same code. Include the collections overhaul in the plan. The goal should be preparing the app to accommodate a new FRUS release in early December and then shipping an update to the App Store after that release."
    - *Open issues* is read as the 42 open on GitHub on 2026-11-25. The five findings the owner sent to the first update have no issue, and are placed with them (§1b).
    - *Fix waves* is read as `.claude/workflows/README.md` uses the word: rows developed side by side with `lane-dev.js`, then landed one at a time through the serial queue. So a wave's rows must not share a file.
    - *Consolidate fixes that touch the same code* is read as one row for each family of files. §1's table of what each row touches is the working of it, and names the files two rows still meet in, with the order that settles each.
    - *Include the collections overhaul* is read as the design's lanes taken as rows of this plan (§1c). The draft put the lanes that store something after the update, and asked. Decision 147 put all of them in it.
    - *A new FRUS release in early December* is read as E, no earlier than Monday 2026-11-30. Its date is the Office's. The draft's calendar ran to E. Since decision 148 the update waits for the overhaul as well.
    - *An update after that release* is read as one release that carries the new volume, not a fix release now and a volume release later. Its version is 1.1 (decision 150).

**The owner's word of 2026-11-25, on the draft.** The draft had put #1990 after the update. Asked how it handled #1990 and #1723, the session said so, and gave as one reason that the cross-reference graph draws documents and not archival collections or classes.

146. **#1990 is in this plan, as a row of the update.** The owner's words: "Include 1990 in the plan. Double check your claim that cross reference graph only draws documents."
    - It is L42, now in Wave 3. Decisions 180 and 181 say what its two saves take.
    - **The claim was wrong.** The graph has drawn both since #837 and #834: an archival unit for each footnote citation that joins the collection authority, and a central-file class for each decimal number (`DisplayNode.Kind`, `FRUSCoreKit/CrossReference/CrossReferenceGraphDisplay.swift:36-64`). The view model's own notes count them: at three hops `frus1952-54v02p1` d16 has 247 nodes, 72 of them archival units and 9 central-file classes. The session had not read the graph's code when it answered. L42's brief is written from that code.
    - The draft's other two reasons shrink with it. A working corpus's bound of 7,500 keys is far off: the largest graph the records name has 1,259 nodes. What *displayed* means was still a question, and decision 180 answers it.
    - #1723 stays after the update (§3), as the draft had it.

**The owner's answers of 2026-11-25**, given one at a time in the session that wrote this plan. The draft had put ten questions, each with a recommendation. The first answer brought the Collections design's own twelve in with them. Each answer below is the option's label as the owner chose it, or the owner's words. Numbered on:

147. **All eight Collections lanes are in this update.** The owner's choice: "All eight lanes", over the draft's recommendation, which was the lanes that store nothing new.
    - The update carries the design's stored facts, and so a CloudKit promotion.
    - The design's twelve questions were answered the same day (153 to 174). Its lane 5 then went by the owner's own answer (156), so seven of the eight are built.
148. **One update, when both are done: the new volume waits for the overhaul.** The owner's choice: "One update, both done", over the recommendation, the volume first.
    - From E until 1.1 ships, the new volume is not in the app. A reader of 1.0 can side-load its file, and nothing derived comes with it (`New-Volume-Release-Plan.md` §1).
    - D-1's first half stands: the gap stays silent. Its second half, that the gap is kept short, gives way to this decision for this release.
149. **An adversarial review of the design's third form comes before its lanes are built.** The owner's choice: "Review, then build (Recommended)".
    - It is row CR. It runs alongside Waves 1 and 2, on the design as decisions 153 to 174 leave it.
    - Wave 4 starts when its findings are answered. L29 and L26's table of term mentions do not wait: neither is a lane of the design.
150. **The update is version 1.1.** The owner's choice: "1.1 (Recommended)". The build numbers are the owner's.
151. **Two TestFlight builds: one after Waves 1 and 2, and the release candidate.** The owner's choice: "Early build + final (Recommended)".
152. **When the Office publishes, the volume is taken in at once, with the queue paused.** The owner's choice: "At once, queue paused (Recommended)".
    - The row in flight finishes, R10 runs and merges, and the rows resume.
    - A corrected volume's re-packed shard is still pushed close to the release candidate, since 1.0 (1861) refuses a fresh download of it from the push on.

*The Collections design's questions* (`Collections-Customization-Design-2026-11-25.md` §10):

153. **Q1, the interface: 1.0's three surfaces, trimmed.** The owner's choice: "Three surfaces, trimmed (Recommended)".
154. **Q2, the mark: the words *As published:*, fixed.** The owner chose "Other words, still fixed", and then gave the words: “As published:”.
    - It takes the place of the design's *In the volume:* wherever the design has it: before the volume's heading where a title of the author's stands above a document, and in a contents row's second line.
    - An author cannot change it or empty it.
155. **Q2, a document without its volume's heading or dateline: not offered.** The owner's choice: "Not offered (Recommended)".
156. **Q3, the export sheet: format and destination only.** The owner's choice: "Format and destination only", over the recommendation, both steps in the sheet.
    - The design's lane 5 is not built, and its §4.4 and the two rows of its §5.1 go with it.
    - A template is chosen in the collection's settings, and the collection is then exported. *Export…* from the lists (L35) is the quick export.
157. **Q3, the apparatus when a document template is chosen: it stays, with the suggested set one tap away.** The owner's choice: "Stays; suggestion one tap away (Recommended)".
158. **Q4, what leads a document: the volume's heading in four templates, and the citation in two.** The owner asked for more ("Tell me more"), was given the design's table and a third reading of it, and chose that one: "Third."
    - The volume's heading leads in *Full text as printed*, *Full text with your annotations*, *Summaries* and *Full text with everything*.
    - The citation leads in *Citations with your notes* and *Citations with source notes*.
    - The design's table had the citation leading in *Everything included*. So in four of the six, the template now opens a document differently from 1.0's, and a collection that equals one of the four today reads *1 differs* until its Opening is changed (the design's §4.3).
159. **Q4, a new collection: 1.0's settings, with the volume's heading leading and no apparatus.** The owner's choice: "1.0's settings, heading leads (Recommended)".
160. **Q5, a new collection's citation style: the one chosen in Settings ▸ Display.** The owner's choice: "The Settings ▸ Display style (Recommended)".
161. **Q5, Chicago and Turabian: checked against the manuals before per-collection styles ship.** The owner's choice: "Check against the manuals first (Recommended)".
    - The check takes a note, a list's row and a bibliography's entry in each style, and, since decision 171 took A10, a volume's entry.
    - L43 does not start before it.
162. **Q6, storage: four optional properties on the record types 1.0 has.** The owner's choice: "Four optional properties (Recommended)".
163. **Q7, the author's date line: kept, for a document that has a title.** The owner's choice: "Kept, under a title (Recommended)".
164. **Q8, lane 7: nine of the design's thirteen candidates.** The owner's choice: "Let me pick from the 13", then the ticks; for candidates 5 and 6 "Tell me more", and then "6".
    - **Taken:** selected passages as a document's text (1); Save as Template (2); a section's headnote default and See also for the collection (6); the page (7); Same settings as… (9); See also, by page (10); a short citation form (11); a tagged PDF (12); and both halves of 13, the opening drawn in a document's settings and a settings column on the iPad.
    - **Not taken:** the collection's own numbers (3); where notes go (4); a date alone in contents rows (5); several formats in one export (8).
    - Save as Template is a record type of its own, and See also for the collection is a stored field. Both join the promotion (the rules, below). A section's headnote default is a field too, by the design, or rides one that 1.0 already stores (§1c).
165. **Q9: a citation record's title takes the new reading of a heading.** The owner's choice: "Yes, clean titles (Recommended)".
166. **Q10: a headnote travels in the collection file always, as its text, with who wrote it.** The owner's choice: "Always, with its author (Recommended)".
167. **Q11, step 1's names: three are renamed.** The owner's choice: "Rename the three (Recommended)": *Summaries*, *Citations with source notes* and *Full text with everything*. Decision 139's other three keep their names.
168. **Q11, step 2's shortcuts: *Suggested for…*, *All* and *None*.** The owner's choice: "Suggested, All, None (Recommended)".
169. **Q11: the contents-list style is step 2's.** The owner's choice: "Step 2, Apparatus (Recommended)".
170. **Q11: the colophon, the project stamp and the query log sit under step 2, and no shortcut sets them.** The owner's choice: "Under step 2, untouched by shortcuts (Recommended)".
171. **Q12, lane 8: eight of the design's thirteen candidates.** The owner's choice: "Let me pick from the 13", then the ticks; for A5 and A6 "Tell me more", and then "Neither"; for A9 and A10 "Tell me more", and then "A10".
    - **Taken:** a line of coverage (A1); Abbreviations & Terms (A2); Unprinted material cited (A3); Documents cited, not included (A4); Sources & Archives by file class (A8); Bibliography by volume (A10); Chronology by administration (A11); the word cloud's terms as a table (A12).
    - **Not taken:** the Subject Index (A5), which settles Q12's third part too; Marked passages (A6); Abstracts (A7); the Persons Index with life dates and posts (A9); the files read, in the Note on the Text (A13).
    - A8, A10, A11 and A12 have no switch. Each changes what a block of 1.0's prints, for every collection.
172. **Q12, how Abbreviations & Terms is filled: a table of term mentions, in index version 76.** The owner's choice: "Table in index version 76 (Recommended)". It joins L26.
173. **Q12: no suggested set gains a block.** The owner's choice: "None does (Recommended)".
174. **A term in the web page links to its row in Abbreviations & Terms where the collection has the block, and is plain text where it has not.** The owner's choice: "Link to its row if the block is there (Recommended)". The session put this one, from the design's note under A2.

*The issues' own questions, and the plan's:*

175. **#1976: the views fall back to the index's date.** The owner's choice: "A: views fall back to the index's date (Recommended)".
176. **#1974: one rule, in SourceNoteKit, that the kit and the generator's core both forward to.** The owner's choice: "One rule both forward to (Recommended)".
177. **#1972: its narrow form, in L33.** The owner's choice: "Narrow form, in L33 (Recommended)".
178. **F7: L26 measures first.** The owner's choice: "Measure first, in L26 (Recommended)".
179. **D1: sheets on a phone idiom, and a check of the iPad.** The owner asked for more, and chose "A with iPad check".
    - One helper, read at the gates, answers as a phone on a phone idiom.
    - The row also checks, on the iPad simulator, whether a window closed with Done comes back at the next launch. If it does, Done ending its own window's session is that defect's fix, on the iPad.
180. **#1990, the working corpus: every document the graph holds as drawn.** The owner's choice: "Everything the graph holds (Recommended)".
181. **#1990, the Archives Visit: both halves.** The owner's choice: "Both halves", over the recommendation, the references half alone.
    - Its seeds are read as the corpus's documents (decision 180), each with its own source note and its footnotes' references contributing, as Project Home's *Plan a Visit* seeds.
182. **L28, the rehearsal, is run.** The owner's choice: "Run it (Recommended)".
183. **Two working rules are adopted.** The owner's choice: "Both rules (Recommended)": a row shows its defect first, and a candidate is offered, not taken (the rules, below).

*A row the owner asked for the same day, after the answers:*

184. **A session that lets Chronology save a range of dates as a working corpus.** The owner's words: "Can we include a session in the plan that adds an option in chronology to save a chronological scope as a working corpus?"
    - It is row L56, in Wave 3. It lands after L42, the graph's saves, since both make the same record.
    - *A chronological scope* is read as the range of dates the screen has loaded. No route leads from a range to a working corpus today: Search does not run on a range of dates alone (L56's brief).
    - It stores nothing new, so it brings no CloudKit change and no index version.
    - Four things about the save were the owner's: what a saved range holds, what the save does over 7,500 documents, how the corpus is named, and whether the legend's filter narrows it. Decision 185 answers them.
185. **L56's four choices, each as the row proposed.** The owner's words: "I accept your recommendations."
    - **A saved range holds every document whose dates overlap it:** those dated inside it, those whose dates extend beyond it, and those that span more than a year. It is the set Search's date filter means by a range. The save says how many of each kind it holds.
    - **Over 7,500 documents, the save offers the range cut at the last whole day that fits,** and names the corpus for the shorter range. Nothing is recorded as cut short.
    - **The corpus is named by rule:** the range's two days and the capture's stamp, as L42's, the Clusters index's and the map's lasso's are.
    - **The legend's filter does not narrow the save.**
186. **The day-early finding is filed, as #2012, and L56 takes it.** The owner's words: "File the issue".
    - *Search in this range* writes its two days through a UTC formatter over a local midnight. East of UTC it hands Search the range a day early, at both ends.
    - It was read from the code and from an emulation of the two expressions, and was not seen in the app. The issue says so, and L56 shows it first (decision 183).
    - It is in L56 because L56 edits those lines, and it was that row's candidate. The fix the issue proposes is to hand Search the days the screen loaded, which also has both hand-offs name the range the screen shows.
    - One more finding was made while the issue was written: on iPhone and iPad, Search's own date pickers and the days it keeps are in two zones. Decision 187 files it. The other findings of the same reading stay unfiled (§5).
187. **That finding is filed too, as #2013, and has a row of its own, L57.** The owner's word: "Yes", to the session's question whether to file it.
    - On iPhone and iPad, Search turns its date filter's day strings into dates, and back, in GMT, while its two pickers are in the device's zone. After a hand-off or a saved search the pickers show the day before, west of UTC; a picked day can be written as another; and *Visualize in Corpus Analytics* reads the filter's years in the device's zone.
    - Like #2012 it was read from the code and from an emulation, and was not seen in the app. Its first and third symptoms would show in New York with no zone changed, so its row can show it on the owner's Mac.
    - **The row and its wave are the plan's reading, and the owner's to change.** No other row edits Search's view model, so it is a row of its own. It is in Wave 2, with the other wrong facts, so that the early build carries it and its device pass reads it.
188. **CR's reading of A2: index version 76 records where in each document a term is linked.** The owner's choice: "Add it to v76", to CR's question whether L26 should add the column before it lands or the index version after 1.1 should.
    - `term_mentions` held that a document links a term, not where. By CR's reading of the TEI at corpus `216cdb764`, 124,491 of 497,026 document–term pairs (25.0%; 28.6% from 1955) are linked only in notes, so a block that lists every row lists terms the page does not print where a template leaves out the footnotes or the text.
    - **The column:** `parts`, flags OR'd over the document: text 1, heading 2, footnote 4, source note 8, named on `@ana` 16; one row a document and term, as before. It joins L26. L52's block keeps a term where a part that links it prints, which CR's pull request writes into the design's A2 and L52's brief.
189. **CR's DATA-2: a term-list item that lists two spellings gives each its own `terms` row, in index version 76.** The owner's choice: "Add it to v76 (Recommended)", to CR's question whether L26 should take it before it lands.
    - The parser's term-list delegate gave an item one row, under its last `<term xml:id>` with its first word, and took the other spellings into the definition: `frus1917-72PubDipv08`'s `HAD or HD, Henry A. Dunlap` was `t_HD_1`, "HAD", "or HD, Henry A. Dunlap". By CR's reading at corpus `216cdb764`: 200 such items; 809 document–term pairs in 27 volumes link a spelling no row answers (in 1.0's reader the tap says to re-index the volume, which would not help), and 335 more link the last and show the first word; 30 volumes in all.
    - **The rule, L26's to choose:** each spelling its own row under its own id, its word as printed, with the definition printed after the last spelling. An item with one spelling reads as before. It joins L26, and `volume-annotations-index.json`, which counts each volume's terms, is regenerated with it.
190. **CR's EDI-2: an edge a page pass resolved keeps the page it cited and how it was resolved, in index version 76.** The owner's choice: "Add it to v76 (Recommended)", to CR's question whether L26 should also store, on each such edge, the page and how it was resolved.
    - The same-volume pass (#1503, #1509) and, since 71, the other-volume pass (A18b, rule C) rewrite a page reference's `target_document_id` to one document, the one the note names by number or day, else the first on the page, and kept neither the page nor the choice. So the Collections design's A4 (*Documents cited, not included*, L51) would print the index's picks as the editors' citations, unmarked: by the index's own records, the note names none of the documents in 8,422 of 12,749 same-volume references to a page several begin on (corpus `550a8c5c5`), and 4,216 other-volume edges take the first.
    - **The columns, L26's to name:** `cited_page_id`, the `pg_N` cited (in `target_volume_id` where that is set, else the source volume), and `page_resolution`, how the document was chosen: `one`, `range`, `number`, `day` or `first`. Both are empty on every other row, a page the passes leave among them. Nothing that reads the table today selects them; L51 is the first reader.
191. **CR's C2-5: the footnote grammar reads the post-1963 central files, in index version 76.** CR's question, for A3 (L53's *Archival files cited*, decision 196), was what to do about a grammar that reads only lots, presidential libraries and decimal central files. The owner's answer: "Can the post-1963 central files be added to the grammar, so they can be listed as well?", and then "In 1.1, joining v76 now". To L26's two questions the owner answered "Every reader now" and "Yes, both (Recommended)".
    - The class channel refused every Subject-Numeric designator (7,849 on the shipped artifact), and the Central Foreign Policy File, the Department's file from 1973, had no anchor. So A3 could list neither, and no reader showed them. Measured over the catalogue's body footnotes before the rule: 4,409 clauses name the Central Files and a handbook category (40 of 40 read real), and 155 another lead, most of them an organization's (`UN 6 CHICOM`); 7,887 name the Central Foreign Policy File (20 of 20 real). An `Ibid.` that names a designator of its own follows a Central Files citation within three notes 605 times, and is the first citation after the document's own Central Files source note 1,174 times; one that names a film number follows the file 142 times and the file's source note 150.
    - **The rule, L26's to choose:** a Subject-Numeric file is a class row where its clause names the Central Files (not the White House's, nor the Central Foreign Policy File alone) under a lead the source notes read. The Central Foreign Policy File is an anchor of its own, its film number the file, joined to no collection. An `Ibid.` that names a file or a film number of its own takes its referent's repository within three notes, or, first in the document, the source note's (the owner's "Yes, both"); after a lot or a library it takes nothing.
    - **Every reader now,** the owner's choice: the graph draws a Subject-Numeric file as a central-file node; Archival Analytics ranks it on the class lens's pointer weight, folded as its other weights fold it; Source Explorer's Unprinted Material lists both kinds; `external-citation-index.json` is regenerated in this row. The Archives Visit packet still leaves the central files out, and Source Explorer's Add to Archives Visit counts the rows it takes.

*CR's eight questions, answered at C2 on 2026-11-26,* one at a time, in the CR session (the third review's §8). Decision 191, above, is C2-5's first half. The owner asked "Can the post-1963 central files be added to the grammar, so they can be listed as well?" and, told what it reaches, chose "In 1.1, joining v76 now" over CR's recommendation of a row after 1.1. The other seven follow:

192. **C2-1: L35 says, at export, what the export will print.** The owner's choice: "L35, the sheet's sentence (Recommended)". The sheet's sentence is written from what the export prints: the headnote count, and what this device lacks for the template. It holds at the largest text sizes. L44's cards may also say a template's needs.
193. **C2-2: a headnote switched off stays off in the collection file.** The owner's choice: "No: Off stays Off (Recommended)". Off travels as Off, and an Off entry's draft does not travel.
194. **C2-3: an export names a headnote's writer by the compiler's name.** The owner's choice: "The compiler's name", over the recommendation, which was the compiler or Apple Intelligence in fixed words.
    - The collection's settings take the compiler's name once, and exports print it ("Headnote by Jane Doe"), with Apple Intelligence named where it drafted.
    - So each headnote carries its writer's name. Otherwise a recipient's own new headnotes would print under the sender's name.
    - L43 settles whether the title page's author line serves as the compiler's name. The promotion is then seven fields, or eight.
195. **C2-4: a saved template holds step 1's seven settings.** The owner's choice: "Step 1's seven settings (Recommended)". Decision 157 holds for it.
196. **C2-5, second half: A3 is titled *Archival files cited*.** The owner's choice: "Archival files cited (Recommended)". A line on the page says which kinds of file are listed for which years.
197. **C2-6: a citation names history.state.gov's number.** The owner's choice: "history.state.gov's (Recommended)". The *As published:* line keeps the volume's own, such as `frus1874` d100's "No. 98.".
198. **C2-7 and C2-8: the records' date line takes the new reading, and the *Summaries* export's defect is filed.** The owner's choices: "Yes, the new reading (Recommended)" and "File it; L35 takes it (Recommended)".
    - A Zotero, BibTeX or RIS record's "Document date:" line reads the dateline as the one reading does.
    - The defect is #2018. L35's files widen to `CollectionContentResolver.swift`.

*C2's rest, answered the same day* (the C2 bullet of §1c): the re-cut, the pace, the design's status, and one choice the review left open.

199. **C2-9: three Collections rows are split.** The owner's choice: "Split L43 (Recommended)", "Split L45 (Recommended)" and "Split L48 (Recommended)". Rows keep their numbers, so the second halves take the next free ones.
    - **L58:** L43's second half, the Note on the Text, the statement of sources and the collection file's new keys.
    - **L59:** L45's, the iPad's settings column and the opening drawn in a document's settings.
    - **L60:** L48's, the tagged PDF, which lands last of the Collections rows.
200. **C2-10: decisions 147 and 148 stand.** The owner's choice: "Both stand (Recommended)", told the submission falls about 2026-12-22 by the plan's arithmetic, inside the week App Review ran slowly in 2024. The owner's word on E: "Early December, no day". The Office has said early December and given no day.
201. **C2-11: the Collections design is accepted as reviewed.** The owner's choice: "Accepted as reviewed (Recommended)". Its head reads ACCEPTED, and the plan of record's rows are what is built. Wave 4 starts once its own runs are made (§2).
202. **C2-12: a person's name in an exported web page links like a term.** The owner's choice: "Like terms (Recommended)". Where the collection has a Persons Index, a name links to its row there; elsewhere it is plain text, as decision 174 has a term. It is L52's.
203. **L31 (#1975): a dateline's strict date is held to 1600–2029.** The owner's choice: "1600–2029 (Recommended)", over "1800–2029, as written", told that an 1800 floor drops nine correct pre-1800 dates (the Massachusetts Bay charter of March 4, 1628; a treaty article of November 30, 1782; letters of 1793) along with the three misprints it targets (1054, 1291, 7928).
204. **L31 (#1975): a dateline's year ends before an ASCII letter, not at a word boundary.** The owner's choice: "Not followed by a letter (Recommended)", over "A word boundary, as written", told that a word boundary also refuses `November 30, 18811.` (frus1881 d107, a footnote digit glued to the year) and `September 4, 1963è8 p.m.` (frus1961-63v04 d58), which the rule read right.
205. **L31 (#1975): the editors' bracketed year is the year in all 32 datelines that print one.** The owner's choice: "Editors' year in all 32 (Recommended)", over "Leave the bracket rule out", told that in 11 more than the issue's 21 the TEI's own date follows the original's slip (frus1925v02 d17, `Habana, October 22, 1924 [1925]`, is indexed 1924-10-22).
206. **L31 (#1976): where a pre-1906 dateline prints no date, the country series looks the rolls up by the index's date.** The owner's choice: "Look rolls up by the index date", over the recommendation, "Keep "no year" for them". The owner was told the index-date fallback reaches 462 pre-1906 documents whose datelines print no year, which the section had left unchecked. The rolls are those covering the index's days unless a printed year contradicts them (`CountrySeriesRollDates`), and both views say so above them (`centralFiles.rolls.indexedNote`).

*From L28's rehearsal, the evening of 2026-11-26, asked in its session:*

207. **The manifest generator's silent drop is filed and fixed before R10.** The owner's choice: "File it; fix before R10 (Recommended)", told that a run whose header fetch fails writes `manifest.json` without that volume, says it was written and exits 0 (six HTTP 503s left 547 of 553 volumes), and that a second run reproduced the bundled file byte for byte.
    - Filed as #2022. Its fix is row L61's, in a short row of its own before R10.
208. **The map packer's missing check is filed and fixed before R10.** The owner's choice: "File it; fix before R10", over the recommendation, to file it alone. The two layout scripts default to the 300m's store and pool, and the packer's preflight takes a layout made from either.
    - Filed as #2023, and also row L61's. The runbook's §4.5 names every path meanwhile.
209. **The root checkout's stale `layout.bin` is replaced with the shipped one.** The owner's choice: "Replace it with the shipped one (Recommended)". L28 copied the layout it reproduced (`46799d5a…`) over the 300m's (`80a9af07…`) the same evening; the file is gitignored, so no commit carries it.

#2022 and #2023 are row L61's to fix, not L28's, which commits documents alone. The orchestrator starts L61's session, one row for both, landing before R10.

*From L57, 2026-11-27, asked in its session:*

210. **L57's finding is filed: on the Mac's Search and in the word cloud, a day whose midnight a change of clocks skips is read as no date.** The owner's choice: "File it (Recommended)", over leaving it in §5, told that the Mac's filter then keeps its previous date and the word cloud's picker falls back to year 1, on 27 such days from 1861 to 2000 in São Paulo, 42 in Havana, 4 in Tokyo and none in New York.
    - Filed as #2033. No row takes it yet; §5 lists it under *Found by L57*.

**Rules carried from the earlier plans and `CLAUDE.md`, and the two of decision 183.** Each is the owner's.
- **The queue is serial.** The next pull request is pushed when the owner has merged the one before. Auto-merge is never enabled.
- **One fresh session per pull request**, started from this plan and the row's issue numbers, and ended at the merge.
- **Small defects are fixed inline**, several related issues to one pull request, a commit for each, with one review pass on the diff.
- **A row shows its defect first** (decision 183). It is `open-issue-review.js`'s rule for an issue filed from code that was read, taken to the row. Most of the 33 newer issues were filed from code that was read, or from the web edition's checks, and were not seen in the app. Each row begins with a failing test, or with the defect seen in 1.0 (1861), before it changes anything; a claim that does not hold is reported to the owner, and the row goes on without it.
- **A candidate is offered, not taken** (decision 183). Where a row's brief names an unfiled finding in the row's own files, the session takes it only if it is a few lines in code the row already changes, and says so in its pull request. The rest stay in §5.
- **Tests are scoped with `-only-testing` while developing.** Landing owes one full unit run, `swift test` where the diff names package input, and the Mac build. Build output goes to a file, and the session reads the summary.
- **A row with code needs a Mac with Xcode.** A cloud session such as this plan's cannot make the runs landing owes. It can take what is documents only: this plan, CR, and the half of L28 that edits the runbook.
- **Every heavy job goes through `Scripts/heavy.sh`**, one at a time on the Mac. No more than three builds at once across every workflow.
- **One index bump a build.** 1.1 carries version 76 and no other, and L26 is the only row that changes what indexing stores: a document's place in its volume (#1978), the editorial notes (#1854), the table of term mentions (decision 172) and, if its measurement says so, the front- and back-matter pages (decision 178). Every library re-indexes once, at its first launch of 1.1; a TestFlight device does so at the early build. Anything else that would change what indexing stores joins L26 before it lands, or waits for the build after 1.1.
- **One CloudKit promotion, before the release candidate.** 1.1 adds stored fields and a record type (decisions 162 and 164): a collection's citation style, opening and words; a document's date line; See also for the collection; a saved template, which is the record type; and a section's headnote default, which CR settled as a field of its own (§1c); and the name each headnote carries, with the compiler's name if the title page's author line does not serve (decision 194). So seven fields, or eight. More, if L46 gives an imported passage a field, or L48 or L49 keeps a choice on the collection.
  - Each lands with its control in the same row, since CloudKit makes a field only from the first record that carries a value.
  - The R-7 gate (`CloudKitSchemaInventoryTests`) catches each as it lands, and its checklist is followed.
  - The owner exercises each on a Development build and then deploys the schema to Production, once, before the release candidate is archived (R11). `check_cloudkit_schema.py` gates every archive (#1531).
  - The two-device run of the design's §12 comes before L43.
- **The freeze** (decision 129's shape): from R11's start until the submission (R13), `v2` takes only what the checklist and the device pass send back. The queue also pauses for R10 (decision 152). A web-authored pull request waits likewise.
- **Lanes edit the manuals** where they change what a manual describes, and leave the *AI Generated* notice (decision 94).
- **A test that pins specific language is an advisory reminder** (decision 9): the edit goes ahead, the test is brought to the new text in the same change, and the reason is written where the test is.
- **The web edition.** Sessions follow `CLAUDE.md`'s four rules. A row that changes shared code says so, runs `swift build --target FRUSCoreKit` and `swift test`, and, where its issue carries a hand-over note for FRUS Explorer Light, fills it in after the merge. Twelve of this plan's issues carry one: #1970 to #1978, #1986, #1989 and #2010. Index version 76 is the pin move that matters most to it: its server refuses a version-76 export until that move ships (its COORDINATION §4).
- **The EditableContent range gate stays exact** (`EditableContentKeyTests.everyRangedBlockHoldsItsKey`).
- **A finding is filed as an issue on the owner's word.** The findings no row takes stay in §5 until then.

---

## 1. Track B — to version 1.1

A row keeps the number it was first given. So the waves give the order and the numbers do not: L37 to L42 land before L34, and L56, which the owner added after the answers (decision 184), lands with them. L57, the row of an issue filed after that (decision 187), lands in Wave 2.

| | Pull request | Issues and findings |
|---|---|---|
| | **Wave 1: what every build of 1.1 must carry. Before any other wave lands** | |
| L26 | Index version 76: a library upgraded in place lists each volume's documents in its file's order; the 138 editorial-note documents store their source note, dateline and provenance; each document's linked terms are stored, with the parts of the document that link each, for *Abbreviations & Terms* (decisions 172 and 188), and each spelling of a term-list item has its own row (189); an edge resolved from a page keeps the page and how (190); the footnote grammar reads the post-1963 central files (191); with Browse's subseries in one order from launch to launch | #1978, #1854; T1's finding; F7's measurement (decision 178) |
| L27 | The tab shell's banner and the room it sets aside, through a re-index that a new index version starts, and with the keyboard up | F1, #1835 |
| L28 | The rehearsal: the runbook's corpus phases run on this tree before the Office publishes, and `New-Volume-Release-Plan.md` brought to what they find (decision 182) | — |
| | **Wave 2: wrong facts, and notes sent where the author switched them off. Seven rows whose files do not meet** | |
| L29 | What leaves a collection, and what a copy of one keeps: a document's research-notes setting holds in BibTeX, RIS, the Zotero send and a shared file; a file opened on its author's account makes its own headnote drafts; Duplicate copies every setting; an added entry lands before the back matter | #2000, #1999 (the import's half), #1996, #1995 |
| L30 | Citation Lookup reads a printed number as Cite writes it: *Document 1190b*, *Document C*, *Document GT–6* | #1977; W2's finding |
| L31 | Source Explorer reads a document's year by one rule, kept in one place; the export's Numerical File case follows the kit; a live lookup shows NARA's scope note | #1975, #1976, #1974, #1970 |
| L32 | The semantic map's slice: a revealed document ringed where the slice draws it, and a slice with no dated volume laid out, not trapped | #2010, #1986 |
| L33 | Four small kit fixes FRUS Explorer Light found: a duplicated Archives Visit shows the row its original shows; the Mac's Chronology magnifier names its months; two strings take their host's locale and words | #1989, #1971, #1973, #1972 |
| L57 | On iPhone and iPad, Search's date filter reads and writes its days in the zone its pickers are in (decision 187) | #2013 |
| L61 | Two generators' guards before R10: a manifest run whose header fetch fails writes nothing and says so; the map's pack refuses a layout made from another store's vectors (decisions 207 and 208) | #2022, #2023 |
| | **The early build** (decision 151) | |
| R8 | The release checklist's first run, the bump to 1.1, and the early build to TestFlight | — |
| R9 | The device pass of the early build: the one re-index to version 76, what moved into the kit since 1.0, and each row's own check | — |
| | **Wave 3: what the owner sent to the first update, Zotero, and three saves: the graph's two and Chronology's** | |
| L37 | A reader rebuilt by a window's resize keeps its rail as it was | F11 |
| L38 | The Mac's windows: the Research window's rows read their heads from the start, a subject's sheet has its door to the subject area, and the title bar says something whole | #1946, #1931, F2 |
| L39 | Links that open nothing: a volume's Contents links to its front matter and Index, and a page link whose page names no document | F7; the 608 page links (§5) |
| L40 | The iPhone Duo's windows, and a check of the iPad's (decision 179) | D1 |
| L41 | The Zotero client: a stopped send says how far it got, `Backoff` is waited before the next request, the waits are reported, and a date `Retry-After` is read (decision 138) | #1923 to #1926 |
| L42 | The cross-reference graph saved: its documents as a working corpus, and as the seeds of an Archives Visit (decisions 146, 180 and 181) | #1990 |
| L56 | A range of Chronology saved as a working corpus (decisions 184 and 185); and *Search in this range* handing Search the days the screen shows | #2012 |
| | **The Collections overhaul, reviewed first** (decisions 147 and 149) | |
| CR | The adversarial review of the Collections design's third form, as decisions 153 to 174 leave it. Planning only, alongside Waves 1 and 2 | — |
| C2 | The checkpoint: CR's findings answered, the Collections rows re-cut where the findings say so, and the pace read | — |
| | **Wave 4: Collections, with nothing new stored. The design's lanes 1 and 2 and its preview repairs** | |
| L34 | One plan for three formats (lane 2): the web page, the PDF and Word draw the same lines in the same order | #1984, #1991, #1992, #1993, #1994, #1998, #2001, #2002, #2003, #2007; #2005 (the sentence's half) |
| L35 | *Export…* from the Collections list and Manage Collections, the format remembered, the sheet's fit at the largest text sizes (lane 1); with the list's row actions for VoiceOver | #2006 (the list's part); R4's finding |
| L36 | The preview's four repairs (lane 6, first half): it keeps its place, follows the row chosen, names a document entered twice as two places, and refreshes on every setting its page draws | #1997, #2004 |
| | **Wave 5: Collections, the stored facts and the three surfaces. Lanes 3 and 4 and the rest of lane 6; each row is built on the one before** | |
| L43 | The new facts, each with its control (lane 3, and lane 7's candidate 6): a collection's citation style, opening and words; a document's date line under a title; See also for the collection and a section's headnote default; the compiler's name, and each headnote's writer (decision 194); the research export's version 8 | — |
| L58 | The Note on the Text, as a rule over the resolved entries; the statement of sources; the collection file's new keys, with a headnote as its text, Off kept as Off and its writer's name (decisions 193 and 194). L43's second half (decision 199) | #2005 (the statement), #1999 (the file) |
| L44 | The three surfaces, trimmed (lane 4): the collection's settings as two steps, *Documents* and *Apparatus*, with the recipe divided in the kit and three templates renamed; a section's sheet with the section's six; a *Default* that says what it follows; *n set their own*; the snapshot from a smart collection's editor; the Mac's New Collection form | #2006 (the other three) |
| L45 | Pointing on the Mac: *Show Parts* (lane 6, second half) | — |
| L59 | The iPad's settings column, with pointing there, and the opening drawn in a document's settings (lane 7's candidate 13). L45's second half (decision 199) | — |
| | **Wave 6: Collections, the owner's picks from lanes 7 and 8** (decisions 164 and 171) | |
| L46 | Selected passages as a document's text (candidate 1) | — |
| L47 | *Save as Template*, and *Same settings as…* (candidates 2 and 9) | — |
| L48 | The page: Letter or A4, each document on a new page or run on, page numbers in Word (candidate 7) | — |
| L49 | A short citation form (candidate 11) | — |
| L50 | A line of coverage: what a block can fill from the collection's volumes (A1) | — |
| L51 | *Documents cited, not included* (A4), and *See also* by page (candidate 10) | — |
| L52 | *Abbreviations & Terms* (A2), with a term's link in the web page (decision 174) | — |
| L53 | *Archival files cited*, the design's *Unprinted material cited* (A3; decision 196) | — |
| L54 | Three of 1.0's blocks changed: Sources & Archives by file class (A8), Bibliography by volume (A10), Chronology by administration (A11) | — |
| L55 | The word cloud's terms as a table (A12) | — |
| L60 | A tagged PDF (candidate 12), the last of the Collections rows. L48's second half (decision 199) | — |
| | **The release** | |
| R10 | The Office's release taken in, at E, with the queue paused (decision 152): `New-Volume-Release-Plan.md` §10, Phases A to F | — |
| R11 | The freeze, the CloudKit promotion, the release checklist, the release candidate to TestFlight, and sitting T3 | — |
| R12 | The device pass of the release candidate: two devices on one account, the new volume on each, and each Collections row's own check | — |
| R13 | The submission, and the tag | — |

**What each row touches.** Kit paths are under `FRUSCoreKit/`, app paths under `FRUSExplorer/`. Each was checked to exist at `9325f79d`. For L43 to L55 the lists are this plan's reading of the design and of the code it cites, and each row's session confirms its own.

| Row | Kit | App | Index, CloudKit, exports |
|---|---|---|---|
| L26 | `Search/IndexingPipeline.swift`; `TEI/FRUSDocumentParser.swift` if the wrapper's read needs it; `Models/PersonMentionStore.swift` for the terms' read | `Browser/BrowserViewModel.swift` | **Index version 76.** The two bundled files that record an index version, `volume-annotations-index.json` and `cited-page-map.json` |
| L27 | — | `App/MainTabView.swift`, `Models/SupportingTypes.swift` | None |
| L28 | — | — | Nothing committed but the runbook |
| L29 | `Collections/BibTeXCollectionExporter.swift`, `ZoteroCollectionExporter.swift`, `NativeCollectionFormat.swift` | `Models/Collection.swift`, `Collections/CollectionExportSheet.swift`, `Collections/NativeCollectionFormat+App.swift` | The BibTeX and RIS pins, where a fixture turns a document's notes off |
| L30 | `Citation/CitationParser.swift`, `CitationModels.swift`, `CitationMatchingEngine.swift`, with the block splitter and the lookup form's fields | `Citation/CitationLookupView.swift` | A public type (`ParsedCitation`), so a symbol diff; `FRUS-API.openapi.yaml` if `CitationMatch`'s number changes its type |
| L31 | `SourceExplorer/CentralFilesClassifier.swift`, `SourceExplorerLoadIdentity.swift`, `CentralFilesIndex.swift`, `NARACatalogClient.swift`; `SourceExplorerExportGeneratorCore/`, `CentralFilesIndexGeneratorCore/`; SourceNoteKit, for the one rule (decision 176). As built, for the owner's choices of 2026-11-26: `SourceExplorerResolution.swift`, and `Search/IndexingPipeline.swift`'s `sourceExplorerFacts(volumeId:documentId:)` alone; `Package.swift`, the export core's dependency on the kit | `DocumentView/DocumentView.swift`, `App/MacDocumentView.swift`, `DocumentView/ResearchRailView.swift`: the three copies of the rule. As built: one line above the pre-1906 rolls in `SourceExplorer/SourceExplorerView.swift` and `MacSourceExplorerView.swift`; a sentence in each manual's Pre-1910 Central Files passage | `Planning/source-explorer-export/` regenerated |
| L32 | `Semantic/SemanticMapReveal.swift`, `SemanticMapSlice.swift` | `Semantic/Map/SemanticMapSpikeView.swift` | None |
| L33 | `TripPacket/ArchiveVisitPlanWrites.swift`, `Chronology/ChronologyGrouping.swift`, `Analytics/Export/SeriesAnalyticsExport.swift`, `WordCloudKit/` | `Models/ArchiveVisitPlan.swift` | None |
| L57 | — , unless the session writes one function for a day's two conversions that both view models share | `Search/SearchViewModel.swift`, `SearchView.swift`, `SearchFilterView.swift`; `App/MacSearchViewModel.swift` only if the two come to share a function | None. A saved search converts its own two dates, and stores what it stored |
| L61 | `ManifestGeneratorCore/ManifestGeneratorRunner.swift`, `TEIHeaderFetcher.swift`; `SemanticVectorsGeneratorCore/SemanticMapPacker.swift`; `tools/semantic-map/build_layout.py` for the store's identity in the layout's metadata | — | None: no bundled file, no index version, no CloudKit change. `ManifestGeneratorCore` is shared code |
| L37 | — | `DocumentView/DocumentView.swift`, `Browser/BrowserView.swift` | None |
| L38 | — | `Research/ResearchView.swift`, `Browser/SubjectIndexView.swift`, `App/MainWindowView.swift`, `App/MacDocumentView.swift` | None |
| L39 | `TEI/FRUSURLScheme.swift`, `Citation/PageSpanResolver.swift` | `TEI/FRUSURLSchemeHandler.swift`, `DocumentView/DocumentView.swift`, `App/MacDocumentView.swift` | None in this row. Its page rows, if L26's measurement finds none, are stored in L26 |
| L40 | — | The gates on `supportsMultipleWindows`: 25 in 10 files, by the assessment's count | None |
| L41 | `Zotero/ZoteroAPIClient.swift` | The app's three sends: `DocumentView/DocumentView.swift`, `App/SupportingViews.swift`, `Collections/CollectionExportSheet.swift`; both manuals' strings | None |
| L42 | `CrossReference/CrossReferenceGraphDisplay.swift`, for the rule that says what is saved | `CrossReference/CrossReferenceGraphView.swift`, `CrossReferenceGraphViewModel.swift`, `ReferenceListPanel.swift`. It presents `TripPacket/PlanPickerSheet.swift` and makes a `Models/WorkingCorpus.swift` record, and changes neither | None. No stored property is added, so no CloudKit change |
| L56 | The rule that says what a range's save holds, beside `Chronology/ChronologyGrouping.swift`; `Search/IndexingPipeline.swift`, for a read of a range's keys and dates that the list's limit does not cut | `Chronology/ChronologyView.swift`, `ChronologyViewModel.swift`. It makes a `Models/WorkingCorpus.swift` record, and changes nothing there | None. No stored property is added, so no CloudKit change. A read is added and nothing stored, so no index version |
| CR | — | — | `Planning/` only |
| L34 | `Collections/CollectionContentAssembly.swift`, `CollectionExporter.swift`, `CollectionItemHTMLRenderer.swift`, `DocxCollectionExporter.swift`; `TEI/FRUSRenderNodeHTMLSerializer.swift`; `Citation/ZoteroJSONExporter.swift` (decision 165) | `Collections/PDFCollectionExporter.swift` | **Changes what every export prints.** The web page's and Word's pins, and BibTeX's and RIS's |
| L35 | — | `Collections/CollectionListView.swift`, `MacCollectionManagerView.swift`, `CollectionExportSheet.swift`; `CollectionContentResolver.swift` for #2018 (decision 198) | None |
| L36 | `Collections/CollectionItemHTMLRenderer.swift` (the ids) | `Collections/CollectionPreviewView.swift` | The web page's ids, for a document entered twice |
| L43 | `Collections/CollectionContentAssembly.swift`, `CollectionExporter.swift`; `Citation/CitationFormatter.swift`; `Export/ResearchDataEnvelope.swift`, `ResearchImportPlan.swift` | `Models/Collection.swift`, `GeneratedSummary.swift` (a headnote's writer), `CloudKitSchemaInventory.swift`; `Collections/CollectionCompositionRows.swift`, `CollectionEntryInspector.swift`, `CollectionEditorView.swift`, `MacCollectionManagerView.swift`, `CollectionContentResolver.swift`, `CollectionPreviewView.swift` (the refresh list) | **CloudKit: seven new fields, or eight** (decision 194). The research export's version 8 |
| L58 | `Collections/CollectionContentAssembly.swift`, `CollectionGeneratedBlocks.swift`, `CollectionGeneratedBlockType.swift`, `NativeCollectionFormat.swift`; `Provenance/ProvenanceStatement.swift` | `Collections/NativeCollectionFormat+App.swift`, `CollectionEditorView.swift` (the Note's line in the settings) | The collection file's new keys. A new block type. The Guide's §15 |
| L44 | `Collections/CollectionExporter.swift` (`CollectionPreset.Recipe`, divided) | `Collections/CollectionEditorView.swift`, `CollectionCompositionRows.swift`, `CollectionEntryRows.swift`, `CollectionEntryInspector.swift`, `MacCollectionManagerView.swift`, `CollectionExporter+App.swift`, `CollectionOutline+App.swift` | None |
| L45 | `Collections/CollectionItemHTMLRenderer.swift`, if a part needs a mark on the page | `Collections/CollectionPreviewView.swift`, `MacCollectionManagerView.swift`, `CollectionEntryInspector.swift` | None |
| L59 | — | `Collections/CollectionEditorView.swift`, `CollectionEntryInspector.swift`, `CollectionPreviewView.swift` | None |
| L46 | `Collections/CollectionExporter.swift` (`CollectionBodyDepth`), `CollectionContentAssembly.swift`, `NativeCollectionFormat.swift`, and the exporters through the plan | `Collections/CollectionEntryRows.swift`, `CollectionCompositionRows.swift`, `CollectionEntryInspector.swift` | A new value of a stored string, so no CloudKit change. The collection file carries the passages as text |
| L47 | `Export/ResearchDataEnvelope.swift` | A new model's file under `Models/`; `Models/ModelContainer+FRUS.swift`, `CloudKitSchemaInventory.swift`; `Collections/CollectionEditorView.swift`, `MacCollectionManagerView.swift` | **CloudKit: one new record type.** The research export's version 8 |
| L48 | `Collections/DocxCollectionExporter.swift`, `CollectionExporter.swift` | `Collections/PDFCollectionExporter.swift` | The PDF's page size and breaks, and Word's page numbers where asked for. CloudKit only if a choice is kept on the collection |
| L49 | `Citation/CitationFormatter.swift` | Where the form is offered | CloudKit only if the choice is kept on the collection |
| L50 | `Collections/CollectionGeneratedBlocks.swift`, `CollectionContentAssembly.swift` (the blocks' data source), `Browser/VolumeAnnotations.swift` | `Collections/CollectionContentResolver.swift`; step 2's ticks and the outline's rows | `CollectionResolutionTests`' pin, where a fixture's block is empty |
| L51 | `Collections/CollectionGeneratedBlocks.swift`, `CollectionGeneratedBlockType.swift`, `CollectionContentAssembly.swift`; `CrossReference/CrossReferenceStore.swift`, `Citation/CitedPageMap.swift` | `Collections/CollectionContentResolver.swift`; the four menus that add a block | A new block type. The *See also* line prints more where a volume refers by page |
| L52 | The three blocks' files that L51 names; `Models/PersonMentionStore.swift`; `TEI/FRUSRenderNodeHTMLSerializer.swift` or `Collections/CollectionItemHTMLRenderer.swift`, for a term's link | `Collections/CollectionContentResolver.swift` | A new block type, which reads version 76's table. The web page's pin |
| L53 | The three blocks' files that L51 names | `Collections/CollectionContentResolver.swift` | A new block type. It reads the index by a read 1.0 has |
| L54 | `Collections/CollectionGeneratedBlocks.swift`; `Citation/CitationFormatter.swift`, `PageRangeStore.swift`; `Analytics/DecimalClassLabelTable.swift`, `SubjectNumericLabelTable.swift`, `Analytics/Series/AdministrationProfilesData.swift`; one read in `Search/IndexingPipeline.swift` | `Collections/CollectionContentResolver.swift` | **Changes what three of 1.0's blocks print, with no switch.** `CollectionResolutionTests`' pin. No index version: a read changes, and nothing stored |
| L55 | `Collections/CollectionExporter.swift` (`CollectionWordCloud`), `CollectionItemHTMLRenderer.swift`, `DocxCollectionExporter.swift`; `Analytics/WordCloud/KeynessCloud.swift` | `Analytics/WordCloud/WordCloudExport.swift`, `Collections/PDFCollectionExporter.swift` | **Changes what every collection with a word cloud prints.** The web page's and Word's pins. A public type changes, so a symbol diff |
| L60 | — | `Collections/PDFCollectionExporter.swift` | The PDF's structure: tags, a title and links. No CloudKit change |

**Where two rows meet in one file, and the order that settles it:**
- **`IndexingPipeline.swift`: what indexing stores is L26's alone.** #1978, #1854 and the terms share its row because they share its file, its version and its re-index. If its measurement finds no front- or back-matter page rows, they join it too. L56 adds one read there, and L54, far later, changes one. Neither stores anything.
- **`CollectionExportSheet.swift`:** L29 (the Zotero send reads no option, `:734-735`; the shared file's notes follow the sheet's one switch, `:621-644`), then L41 (the collection's send, `:741`), then L35 (the sheet opened from the lists).
- **`DocumentView.swift` and `MacDocumentView.swift`:** L31 (the year's three copies become calls to the kit), then L37 (the per-open task), L38 (the title), L39 (a link's tap) and L41 (the reader's send, `DocumentView.swift:2387`). Each is a different function. Wave 3's four land in that order, each on the one before.
- **The Zotero send is three files in three rows:** L29 gives the send its options, L41 changes the client and its three callers, and L34 gives a record its title (decision 165). L29 and L41 both edit the collection's send, `CollectionExportSheet.sendToZoteroLibrary()`: L29 what it resolves, and L41 how it calls the client. L41 is developed after L29 has merged.
- **`ChronologyGrouping.swift`:** L33 (the month label's locale, #1971), then L56, if its rule goes in that file and not in one of its own.
- **A day between Chronology and Search is a string, and two rows are at its two ends.** L57, in Wave 2, has Search on iPhone and iPad read and write a day in the device's zone (#2013). L56, in Wave 3, has Chronology hand over the days its screen loaded (#2012). They share no file, and neither waits for the other.
- **A working corpus is captured in five places once Wave 3 has landed:** Search's sheet, the map's lasso, the Clusters index, the graph (L42) and Chronology (L56). L56 is developed after L42 has merged and makes its record as L42 left the graph's: through L42's helper, if L42 wrote one, and without writing a second.
- **One TEI wrapper is read in two places.** #1854 is the index's extractors never looking inside the editorial-note wrapper, and #2003 is the collection's heading read stopping at the same wrapper. L26 lands first; L34 reads the wrapper the way L26 leaves it read, and does not write a second rule.
- **From L34 on, the Collections rows are a sequence and not a set.** Nearly every one changes `CollectionContentAssembly.swift` or `CollectionExporter.swift`. Each is developed on the one before, and two are developed side by side only where a session shows that their files are their own; L35 is the one such row in sight.
- **`CollectionItemHTMLRenderer.swift`:** L34 rewrites how a document is drawn, then L36 changes its ids, then L52 a term's link and L55 the table.
- **`CollectionGeneratedBlocks.swift`:** L58 adds the Note on the Text (L43's second half since decision 199), then L50 to L54 in their order.
- **C2's three splits** (decision 199): L58 is developed on L43's merge, L59 on L45's, and L60 last of the Collections rows, after L55. Since the split, the Note on the Text is L58's, so it is L58 that first adds a block type to `CollectionGeneratedBlocks.swift`.
- **`CitationFormatter.swift`:** L43 gives a collection its style, L49 adds the short form, and L54 a volume's form in each style.
- **`Collection.swift` and `CloudKitSchemaInventory.swift`:** L29 (Duplicate, in the first), then L43 (both), then L47 (the inventory), then L48 and L49 if either keeps a choice on the collection. Each follows the gate's checklist, and R11 deploys once for all of them.
- **The research export has one new version in 1.1, which is 8.** L43 raises it. A later row that stores something adds its fields to version 8 and re-takes the fixture, since no build has shipped a version-8 file. This is the plan's reading of `CLAUDE.md`'s rule, and a session that would rather take a version 9 says so.

**The calendar.** The dates are targets, and after Wave 3 they are arithmetic.

| When | Rows | Who |
|---|---|---|
| Wed 2026-11-25 | This plan, with the owner's answers | The owner merges it |
| Thu 2026-11-26 to Sun 2026-11-29 | Wave 1: L26; L27, which needs L26's bump; L28 once L26 has merged. Wave 2: L29 to L33, L57 and L61. CR alongside | Sessions on the Mac, and a cloud session for CR; the owner merges each, and runs L28's heavy jobs |
| Mon 2026-11-30 to Tue 2026-12-01 | R8, the early build; R9, its device pass | A session; the owner archives, uploads and makes the pass |
| Tue 2026-12-01 to Fri 2026-12-04 | Wave 3: L37, L38, L39, L42, L56, L41, L40. C2, once CR's findings are answered. The runs L34 and L43 wait for (§2) | Sessions; the owner |
| From C2 | Wave 4: L34, L35, L36. Wave 5: L43, L58, L44, L45, L59. Wave 6: L46 to L55, then L60 | Sessions; the owner merges each |
| E, whenever it comes | R10, with the queue paused | The owner, with a session for the runbook's generator runs |
| When L55 and R10 have merged | R11, then R12, then R13 | A session; the owner promotes the schema, archives, uploads, passes and submits |

- **The arithmetic.** Thirty-five rows, a review, two builds and two device passes. Waves 1 and 2 are nine rows in their four days, one more than two a day covers, so the early build may come half a day later. Wave 3 is seven rows in its four days, which two a day covers. Nineteen rows are left when Wave 3 ends, with C2's three splits (decision 199). At two merged a day they take nine and a half days; with a day more for each of the three largest, about twelve and a half, which ends about 2026-12-17. With a day or two for R10 and three for R11 to R13, the submission falls about 2026-12-22, if no day is lost between now and then. That is inside the week App Review ran slowly in 2024, and the owner kept decisions 147 and 148 with it in view (decision 200).
- **The week after it ran slowly at App Review in 2024,** by Apple's notice of that year: reviews could take longer from December 20 to 26 (MacRumors, 2024-12-02). This session did not find this year's notice.
- **What it means for the volume.** If the Office publishes in the first week of December, the volume is out of the app for about three weeks, or more. That is decision 148's cost, and C2 is where the owner reads it against the pace.
- **No estimate is made of a row's own size** beyond what its brief says it touches. L34, L43 and L44 are the largest of the thirty-five, L43 since its split among them.

**When the Office publishes.** The Office's date is not this plan's, and 1.1 no longer waits on it alone (decision 148).
- **R10 runs at once** (decision 152). The row in flight finishes and merges, the queue pauses, R10 runs the runbook and merges, and the rows resume.
- **If L26 has not merged, it lands first.** The generators stamp an index version into two bundled files, and that version is 76.
- **The volume is then in `v2`, and in no build a reader has.** It reaches TestFlight with the next build that is cut: the early build if E comes before R8, and the release candidate otherwise.
- **The app says nothing of the gap** (D-1's first half). With a gap of weeks and not days, whether the website says anything of the new volume is the owner's.
- **A corrected volume's re-packed shard is not pushed until R11.** From the push on, 1.0 (1861) refuses a fresh download of that volume's shard. A new volume's shard is pushed as the runbook says, before the build ships.
- **A second publication, or a correction, before R11** is taken in the same way (D-5: each as it comes). R11 reads the corpus's head against R10's before it freezes.
- **The freeze starts when L55 and R10 have merged, or sooner on the owner's word.** A row not merged when it starts waits for the update after 1.1.
- **A defect a device pass finds goes to a row on the owner's word.** One that is not a crash, a loss of work or a store check may go to the update after 1.1.

### 1a. Where each of the 42 open issues goes

**How each was read.**
- **Whole, on GitHub, with its comments** (none has any): #2010, #1990, #1989, #1986, #1984, #1978, #1977, #1976, #1975, #1974, #1972, #1971 and #1970.
- **From the repository's own record of it:** #1991 to #2007 from the Collections design's §2.8 and the two reviews' §6, which give each its file and line; #1923 to #1926, #1854, #1835, #1723, #1696 and #234 from the 2026-11-15 plan; #1946 and #1931 from the sessions that filed them.
- **By title, by FRUS Explorer Light's COORDINATION §5 and by the code:** #1973 alone. GitHub's pages stopped answering this session before it could be read whole. Each row's session reads its issues whole first.

**The ratings** are `open-issue-review.js`'s: *incorrect-data* (the app shows, exports or cites something false), *feature-broken* (a reader cannot finish something the app offers), *degraded-ui*, *dev-or-docs-only*, *enhancement*. None of the 42 is fixed at `9325f79d`. Only L26's two need a re-index.

**A forty-third and a forty-fourth, #2012 and #2013,** were filed on 2026-11-25 from this plan's own reading of Chronology and of Search, on the owner's word (decisions 186 and 187). They are the table's first two rows. Like most of the rest they were read from the code, and each one's row shows it first.

| Issue | What a reader meets | Rating, size | Goes |
|---|---|---|---|
| #2013 | On iPhone and iPad, Search converts its date filter's days in GMT under pickers in the device's zone: after a hand-off or a saved search the pickers show the day before, west of UTC; a picked day can be written as another; a chart's years come back a year wider. Read from the code and an emulation, not yet seen in the app | incorrect-data, a filter under another day than the one shown; S to M; needs local testing | **L57** (decision 187) |
| #2012 | Chronology's *Search in this range* hands Search its range a day early, at both ends, wherever the device's zone is east of UTC; read from the code and an emulation, not yet seen in the app | incorrect-data, a search under the wrong days; S; needs local testing | **L56** (decision 186) |
| #2018 | A *Summaries* export fails with "The export could not be rendered." on a device without Apple Intelligence, even when every summary is stored, since the export checks for Apple Intelligence before it reads them. Filed at C2 from CR's INT-2; read from the code, not yet seen in the app | feature-broken, an export that cannot be made; S; needs local testing | **L35** (decision 198) |
| #2022 | A manifest run whose header fetch fails writes `manifest.json` without that volume, says it was written and exits 0: six HTTP 503s left 547 of 553 volumes in L28's first run. Filed from L28's rehearsal; seen in a run, and met by no reader unless a release commits such a file | incorrect-data if a release commits it, a catalogue short of volumes; S | **L61** (decision 207) |
| #2023 | The map's two layout scripts default to the 300m's store and pool, and the packer's preflight takes a layout made from either, so a release could ship a map laid out over another model's vectors. Filed from L28's rehearsal; read from the code and the scripts, the wrong pack not run | incorrect-data if a release packs it, a map of other vectors; S | **L61** (decision 208) |
| #2033 | On the Mac's Search and in the word cloud, a day whose midnight a change of clocks skips is read as no date: the Mac's filter keeps its previous date, and the word cloud's pickers fall back to year 1. Filed from L57's measurement of Foundation (27 such days from 1861 to 2000 in São Paulo, 4 in Tokyo); read from the code, not seen in the app | incorrect-data on those days, a filter under another day; S; needs local testing | No row yet (decision 210) |
| #2010 | On a map slice, a revealed document is ringed at its place on the map's plane, where another document sits, and the camera moves off the slice | feature-broken on a slice; S | **L32** |
| #2007 | With footnotes left out of a web page, each call is still a button with nothing behind it | degraded-ui; S | **L34** |
| #2006 | Four accessibility defects: the list's row actions, the per-note switches' names, the section pill's height, the template cards' fixed type | degraded-ui; S each | **L35** for the list's; **L44** for the other three |
| #2005 | The export's statement of sources says "from no other source" over an Apple Intelligence headnote | incorrect-data, an attribution; S | **L34** for the sentence; **L43** for the statement as the design's §3.7 redesigns it |
| #2004 | A document entered twice has duplicate ids in the web page | degraded-ui; S | **L36** |
| #2003 | An editorial note has no heading in a contents row, and its citation record is titled with its id | incorrect-data; S | **L34** |
| #2002 | From 1952 a contents row reads "4.  1. Letter From…" and a citation record "Document 1: 1. Letter From…" | incorrect-data; S | **L34** |
| #2001 | Word numbers the volume's footnotes by its own count | incorrect-data; M; needs local testing | **L34** |
| #2000 | Notes switched off for a section or a document still go out in BibTeX, RIS, the Zotero send and a shared file | incorrect-data, and the author's own text sent where they said not to; S | **L29** |
| #1999 | A collection file opened on its author's account shares the original's headnote drafts: edit or delete one and the other's is gone | feature-broken, a loss of work; S for the import's half | **L29** for the import; **L43** for the file carrying a headnote as its text (decision 166) |
| #1998 | A title override prints with nothing of the volume's beside it | enhancement | **L34**, under the words *As published:* (decision 154) |
| #1997 | The preview does not refresh on a title override or the Headnotes default | degraded-ui; S; needs local testing | **L36** |
| #1996 | Duplicate drops *Stamp active project* and *Append the query log* | degraded-ui; S | **L29** |
| #1995 | An entry added later lands after the back-matter blocks | degraded-ui; S | **L29** |
| #1994 | A *Header & Dateline* contents list prints no dateline for most documents | feature-broken; M | **L34** |
| #1993 | The three exports number contents rows differently | degraded-ui; S; needs local testing | **L34** |
| #1992 | A footnote call stays as "[n]" in a heading and a citation record's title | incorrect-data; S | **L34** |
| #1991 | With Footnotes and Source note both on, the source note prints twice | degraded-ui; S | **L34** |
| #1990 | The cross-reference graph's documents saved as a working corpus, and its archival collections and classes as an Archives Visit (the owner's request) | enhancement; M | **L42** (decisions 146, 180 and 181) |
| #1989 | A duplicated Archives Visit can show another stored row on a target than its original | incorrect-data, in plans from before v59, index version 69 or A15; S | **L33** |
| #1986 | A slice whose volumes have no year traps. The app cannot reach it while the manifest dates all 553 volumes; a server can | dev-or-docs-only for the app, a crash for a host; S | **L32** |
| #1984 | The PDF's contents list stops at the end of its first page (the owner's, a 52-document collection on the iPad) | feature-broken; M | **L34** |
| #1978 | A library upgraded in place lists a volume's newer documents last: 361 of 553 volumes in the owner's | incorrect-data, an order; M; **re-index** | **L26** |
| #1977 | Citation Lookup misses or misreads the app's own citation for 722 documents, and answers 83 of them with another document | incorrect-data; M | **L30** |
| #1976 | The export and the views read a document's year by two rules: 8,175 documents differ, 23 in what they resolve | enhancement, a proposal; the owner chose A (decision 175); M | **L31** |
| #1975 | The dateline rule reads a Zulu time, a received date or an original's slip as the year: 27 documents, none of which resolves wrongly today | degraded-ui, latent; S | **L31** |
| #1974 | The export generator gives a 1906–1910 citation in the Decimal File's form another case's Numerical File rolls: about 335 records of the export, and none of the app's screens, which have refused the case since #722 | dev-or-docs-only; M, as one rule (decision 176) | **L31** |
| #1973 | `SeriesAnalyticsExport.provenance` joins its hidden categories in the process's locale | enhancement, for a host; S | **L33** |
| #1972 | A host with no language analysis has no reason of the kit's to give, so the web edition words its own refusals. No Apple screen changes | enhancement, a proposal; S in its narrow form, which the owner took (decision 177) | **L33** |
| #1971 | The Mac's Chronology magnifier labels a year's months M01 to M12; read from the code and a probe, not yet seen in the app | degraded-ui; S | **L33** |
| #1970 | A live NARA lookup never shows a series' scope note, on any platform | feature-broken, for a reader with a NARA key; S | **L31** |
| #1946 | The Mac's Research window shows ids for heads until the sidebar's selection changes; seen three times, not every time | degraded-ui; S; needs local testing | **L38** |
| #1931 | On the Mac a subject's sheet draws no *All «area» subjects* door | degraded-ui; S; needs local testing | **L38** |
| #1926 | The Zotero client reads a date `Retry-After` as absent | enhancement; S | **L41** |
| #1925 | A Zotero send says nothing while it waits | enhancement; S | **L41** |
| #1924 | A finished send can wait up to a minute on `Backoff` | enhancement; S | **L41** |
| #1923 | A send that stops partway duplicates on resend | enhancement, a proposal whose design is the owner's; M | **L41**, if the design is given by then |
| #1854 | 138 editorial-note documents store no source note, dateline or provenance | incorrect-data; M; **re-index** | **L26** |
| #1835 | On an iPad mini simulator under iOS 27.0 the tab shell's banner stays up with the keyboard | dev-or-docs-only until seen on a device; S | **L27** |
| #1723 | App Intents and Siri (A7) | enhancement; L | **After the update** (§3): the device check with Spike Reader comes first |
| #1696 | The 47 documents restored to 1952–1954 vol. IX, Part 1 have no subject tags | upstream-only | **Deferred** (decision 71). R10's Phase E reads whether the Office's export now reaches Document 946 |
| #234 | Extend the people browser | enhancement | **Deferred** (decision 92) |

### 1b. Where each finding sent to the first update goes

The 2026-11-15 plan's §3 named these as the release after 1.0's candidates and left their order here.

| Finding | Goes | Why |
|---|---|---|
| **F1**, a blank band under the tab shell's banner on the iPad, during the re-index at 1823's first launch (PD3); not reproduced by R6a | **L27, and R9 watches for it** | The owner's check of 1842 saw none during Rebuild From Scratch, but PD3's start was an index-version change, and "the next index version brings that start back". L26 is that version. So L27 is in Wave 1, and the early build's first launch on the iPad is the one chance to see F1 before every reader's iPad makes the same start |
| **F2**, the Mac main window's title cut short (MC6) | **L38** | A design question, the last of its row: at 1,200 pt AppKit gives the title about 140 pt. The row proposes what the title bar says when its room is short, with a capture, and the owner chooses |
| **F7**, a volume's Contents links to its front matter and Index doing nothing (PH17, PD13, MC15) | **L39**; its page rows in **L26** if L26's measurement finds none stored (decision 178) | The design question was the cost of an index version. This build pays for one already |
| **F11**, a resize across Browse's one-pane and two-pane widths closes the rail | **L37** | The likely fix is one rule: apply *Open Documents In* only when a different document opens. First the confirmation the plan named: set it to Remember Last and repeat the resize |
| **D1**, the iPhone Duo's windows (`iPhone-Duo-Assessment-2026-11-19.md`) | **L40** | Sheets on a phone idiom by one helper, and a check of the iPad (decision 179) |
| **The web edition's kit rows**, #1907, #1911 to #1913, #1927, #1928 | Done | Merged on 2026-11-22 as #1967 to #1969 |
| **Carried from the 2026-10-21 plan:** A18b, A19, A14, A15, and Search's cost | §5 | None shares a file with a row here but A14, which is in `IndexingPipeline.swift`: a candidate for L26 only if its session finds it a few lines |
| **The review's 35 findings no 1.0 row took** | §5 | Each is filed on the owner's word. Where one sits in a row's files the row's brief names it as a candidate |
| **An owner device sitting** | R9 | Its checks join the pass (R9's brief) |
| **Accessibility Nutrition Labels** | §3 | Voluntary still |

### 1c. The Collections overhaul, as rows

The design (`Collections-Customization-Design-2026-11-25.md`, its third form as twice amended) is PROPOSED, and nothing in its §3 to §9 has been reviewed. Its §9 has eight lanes and three issues outside them. Its §10 asks twelve questions, which the owner answered on 2026-11-25 (decisions 153 to 174). Its §12 lists runs that need a device. All of it is in this update (decision 147), after a review (decision 149):

| The design's | Here | Stored data | Before it starts |
|---|---|---|---|
| The three issues outside the lanes, #1995, #1996, #2000 | **L29**, Wave 2 | None | Nothing. It is no lane of the design, so it does not wait for CR |
| A table of term mentions, for A2 (decision 172) | **L26**, Wave 1 | **Index version 76** | Nothing. CR read A2 first, and what it asked of the index, the parts of each document that link each term, joined L26 (decision 188), as did a row for each spelling of a term-list item (189) |
| The review of the third form | **CR** | — | The design's text brought to decisions 153 to 174 |
| Lane 2, one plan for three formats | **L34**, Wave 4 | None | C2; the Word and Pages run; the three runs in 1.0 for #1991, #1993 and #2001 |
| Lane 1, export from the lists | **L35**, Wave 4 | None | C2 |
| Lane 6, first half: the preview's four repairs | **L36**, Wave 4 | None | L34; the run in 1.0 for #1997 |
| Lane 3, the four new facts, with lane 7's candidate 6 | **L43** and **L58**, Wave 5 (decision 199) | Seven properties, or eight (below) | L34; the two-device run and the file run; the desk check of Chicago and Turabian (decision 161) |
| Lane 4, the three surfaces trimmed, with the two steps | **L44**, Wave 5 | None | L43 |
| Lane 5, the two steps for one export | **Not built** (decision 156) | — | — |
| Lane 6, second half: *Show Parts* on the Mac, with lane 7's candidate 13 | **L45** (the Mac) and **L59** (the iPad), Wave 5 (decision 199) | None | L44 |
| Lane 7, nine of §8.1's thirteen (decision 164) | **L43** (6), **L59** (13), **L46** (1), **L47** (2 and 9), **L48** (7), **L60** (12), **L49** (11), **L51** (10) | A record type for a saved template; the page's options and the short form, if either is kept on the collection | L43 and L44; for each, what its brief names |
| Lane 8, eight of §8.2's thirteen (decision 171) | **L50** (A1), **L51** (A4), **L52** (A2), **L53** (A3), **L54** (A8, A10 and A11), **L55** (A12) | None | L34 for what prints; L44 for A1's line at a tick; the three runs in 1.0 |

**All eighteen Collections issues close in this update.** L29, L34, L35 and L36 end fifteen of them and part of the other three; L58 ends the rest of #1999 and #2005 (decision 199), and L44 the rest of #2006.

**What decision 156 takes out, and what must find another place.** The export sheet stays format and destination, so the design's lane 5, its §4.4 and the two rows of its §5.1 are not built. Three things the design said in that sheet are wanted still, and CR is asked where each goes:
- **A template says what it needs** (the second review's H11, answered in §4.4): the summaries need Apple Intelligence and a prompt, and two templates print a headnote only where one is stored. With no step in the export sheet, this plan reads it as step 1's to say, on its cards, in L44.
- **How many headnotes will print:** *Headnotes for 4 of 6 documents*. The sheet 1.0 has already opens with a sentence of what will print, and that sentence can say it.
- **What a block cannot fill** (A1). L50 says it at the tick, on the outline's row and on the page. Whether the sheet's sentence says it too is L50's to propose.
- **CR's answer** (the third review, `Collections-Design-Third-Review-2026-11-26.md`, J9 to J11). None of the three has a home yet. This section gives the headnote count to the sheet's sentence and L44's brief gives it to L44. 1.0's sentence reads the collection's defaults, and at AX5 on an iPhone SE it does not leave Export in view. A *Summaries* export already fails on a device without Apple Intelligence, even with every summary stored. CR recommends that L35 take the sheet's sentence, written from what the export prints, with L44's cards free to say a template's needs, and puts it to the owner (C2-1).

**The promotion.** Lane 3's four properties are a collection's citation style, opening and words, and a document's date line. Decision 164 adds See also for the collection, which is a property `Collection` has not got, and a saved template, which is a record type. A section's headnote default is the sixth property, or none:
- The design said it was "a field and a deploy of its own" (its §4.1, before CR brought it to the answers). It is promoted with the rest, once, at R11.
- This plan's reading of the model: a section is a `CollectionEntry`, and every entry already stores `includeHeadnote` (`Collection.swift:577`). The cascade ignores it on a heading today ("Headings do not carry a headnote section default", `CollectionContentAssembly.swift:1085`), as a rule and not for want of a field.
- **But a heading made before the Composer redesign holds an explicit `false` there,** by that property's own comment: it was a `Bool` that defaulted to off, and "Existing entries migrate to their stored value". Read as a section's default, that `false` would switch headnotes off under a collection that has them on.
- **CR settled it: a new optional property, read on headings only** (the third review's J24). The explicit `false` is on headings made under the builds of 2026-07-01 to 07-11, and on their copies (Duplicate, Import from JSON). No screen ever showed it, and no pass can tell it from a value set on purpose. The field lands with its control, in L43, and the promotion is six fields.

**What a reader still on 1.0 (1861) sees of a collection made in 1.1,** as the design's §7.2 and the code read:
- It reads none of the new properties. It prints 1.0's layout: the citation leading, History at State, the app's words and no date line. Nothing the volume prints is left out by a new setting, so nothing 1.0 prints is false.
- A block type it does not know stays in its place and is skipped (`CollectionContentAssembly.swift:964-965`). That is the Note on the Text and the three new blocks.
- A text depth it does not know is read as the full text (`CollectionExporter.swift:310`). That is L46's selected passages: 1.0 prints more than the author chose.
- **What is not established** is what 1.0 does to the new properties on a record it then changes, and what a device updated later holds for a record it imported before. That is the two-device run, before L43 (§2).

**Six departures from the design's §9,** each because two changes meet in one file or one release step. The first three were in the draft; all six are the owner's to refuse:
- **#2005's sentence goes with lane 2.** The sentence is at `CollectionExporter.swift:1317-1319`, in the file lane 2 rewrites, and it is false today. The statement of sources as §3.7 redesigns it stays lane 3's.
- **#1999's import half goes with L29.** Duplicate copies each headnote's draft (`Collection.swift:866`) and the import does not. Making the import copy it, where the id resolves, stops the loss of the original's headnote and changes no file. The file carrying a headnote as its text is L58's (decision 166; L43's until decision 199).
- **Lane 6's four repairs come before lane 4.** The design puts lane 6 after lane 4. The repairs touch `CollectionPreviewView.swift` and the web page's ids, which lane 4 does not. L43, whose new settings they are, adds each to the refresh list L36 completes, and L36 adds a test that walks the two models' stored properties against it. (CR's J20: this said lane 4, which stores nothing.)
- **Lane 7's candidate 6 goes with lane 3.** Its fields are the same cascade's two empty cells. In one row they take one version of the research export, one set of `Fields` cases and one pass through the CloudKit checklist.
- **A1 is a row of its own, after lane 4.** The design builds its line with lane 4's ticks. L50 adds it to ticks that L44 has made, so that L44 is not larger still.
- **Lane 7's candidate 13 goes with lane 6's second half.** *Show Parts* on the Mac, a settings column on the iPad and the opening drawn in a document's settings are three changes to where a document's settings sit beside its page.

**The rows,** in the order they land.

- **L26, index version 76** (#1978, #1854; decision 172). One fresh session, one pull request: a commit for each issue and one for the terms, the version raised once, then a docs commit. Kit code, so `swift build --target FRUSCoreKit` and `swift test` are owed; no CloudKit change.
  - **#1978.** `IndexingPipeline.documents(forVolume:)` reads `document_cache` by rowid (`IndexingPipeline.swift:3519-3523`), and the upsert keeps an existing row's rowid, since the FTS tables are keyed on it. So a document a later version began to hold, or a corrected file added, lists last.
    - The fix is the issue's: a column for a document's place in its volume, written by each pass and set by the upsert; the read orders by it, then by rowid; the rowid stays the FTS key.
    - The other reads of rowid order for a volume's documents are checked (`:3564` is one).
    - Its test indexes a volume, then a file with a section put before its last, and holds the file's order, the old rowids and search.
    - **This is a release's own defect.** The Office also corrects volumes it has published (the runbook's step 1), and a correction that adds a document is exactly this case.
  - **#1854.** 138 documents tagged `subtype="editorial-note"` carry a source note of their own, 119 of them with an opener and a dateline, and the index stores none, because its extractors never look inside the wrapper.
    - The session measures what the fix does to the bundled indexes that count source notes (`collection-usage-index.json`, `source-provenance-index.json`, `external-citation-index.json`). They are regenerated at R10, not here.
  - **The table of term mentions** (decision 172). The index holds each volume's list of terms (`terms`, `IndexingPipeline.swift:8876-8885`) and not which document uses which: people have a table of mentions (`person_mentions`, `:8734-8742`) and terms have none.
    - This version adds one, written as the people's is, from the linked terms in each document's parse. It also takes the terms `frus1981-88v16` names on each document's `@ana`, as #1599 did for that volume's people (the design's §8.2, A2).
    - Nothing prints from it in this row. Its test indexes a volume and reads the rows back, by a read beside `allTerms(forVolumeId:)` (`PersonMentionStore.swift:1081`). L52's block is its first reader.
    - **CR reads A2 before this row lands** (§1c). Anything more the block needs from the index joins this version, or waits for the build after 1.1. CR read it on 2026-11-26 and asked for three things more, which join this version: the parts of each document that link each term (decision 188); from its DATA reviewer, a `terms` row for each spelling of an item that lists two (decision 189); and from its EDI reviewer, for A4, the page and the resolution on each edge a page pass resolves (decision 190).
  - **T1's finding, in the same pull request** as an app commit: two subseries that begin in the same year sort differently from launch to launch (`BrowserViewModel.allSubseriesGroups`, `BrowserViewModel.swift:579`, sorts by start year alone over a `Dictionary`'s order). A release can add a subseries, and R12 looks at where it lands.
  - **F7's measurement** (decision 178): whether `page_ranges` holds a row for a front-matter page (`#pg_III`) and a back-matter page (`#pg_315` of `frus1961-63v06`). If it holds none, the rows are stored in this version. If it holds them, L39 resolves at the tap and this row stores nothing for it.
  - **Owed with the bump:** the two bundled files that record `indexVersion` brought to 76 as L22 brought them to 75; a census of the 75 → 76 re-index on a simulator holding a full library (R5's measured 727 s for 71 → 75); the hand-over note for FRUS Explorer Light, `upstream-volume-document-order.md`, which says its server refuses a version-76 export until its pin moves.
  - **By hand, on the Mac:** in a library upgraded from version 75, Browse `frus1969-76ve09p1`: the *notes* section lists third.
  - **Built on 2026-11-26** from `v2` at `b3acd7ad` (#2016 merged; #2017, the CI checks, open at the head of the queue, merged as `d8b70f5f` while the row was built and taken in as `5d82a7b6`), on `claude/plan-of-record-pr2011-2cc493`, by the session the owner started with "start the plan of record from PR2011", which took the plan's first row as L15's session took the last plan's. A commit for each issue and one for the two new tables: `c8b0a971` (#1978, the version raised to 76), `480c1ac1` (#1854), `71cc5749` (the term mentions and the division start pages), `1e60d3ed` (the bundled files), `28db14d0` (T1), then the docs, a commit each for decisions 188, 189 and 190, which CR's review asked for the same day, one that gives the Volumes & Storage hubs T1's order, and one for decision 191 (`6dc07fd9`), from CR's C2 questions; then `v2` at `d8b70f5f`, once #2017 merged (`5d82a7b6`).
    - **Each defect shown first** (decision 183). #1978 in a copy of the owner's Mac library at 75, upgraded in place: 361 of the 553 volumes list in another order than a fresh index of the same files (L22's, at 75), the issue's figure, and `frus1969-76ve09p1`'s `notes` lists last. #1854 in L22's full v75 index: `frus1941-43` d291, d293 and d423 hold no note, dateline or source row. F7's measurement in the same index: no `page_ranges` row for `#pg_III` or `#pg_315`, since each break falls between two divisions, and none of `frus1961-63v06`'s seven front- and back-matter Contents targets names a page any table holds; so the rows are stored in this version, in a table of their own. T1 in a two-line program run twice, whose `Dictionary` gave the same keys in two orders, which the start year alone carried into Browse.
    - **#1978:** `document_cache.document_order`, a document's place in its volume from 0, written by every store pass and set by the upsert; `documents(forVolume:)`, `document(forDocumentNumber:inVolume:)` and `documentRevisions(forVolumeId:)` order by it, then rowid. An index from before 76 opened read-only, which runs no migration, lists by rowid as before (`volumeOrder`, read once). **The probe of the owner's library** (a throwaway package test on a clone of it, not committed): `frus1969-76ve09p1` listed `… d128, notes` before and `preface, terms, notes, d1 …` after the volume's re-index under 76.
    - **#1854:** `IndexingPipeline.ownFieldNodes(of:)`, through which the source note, the dateline and the opener's marking are read under an `.editorialNote` wrapper that holds a source note of its own, and only there; the public `extractSourceNote(from:)` and `extractDateline(from:)` read through it. `DocumentNoteExtractor` yields the same notes, and its test that held it to none (`editorialWrappedDocumentsYieldNoNotes`) now holds it to them, its reason written where it is. `RealTEINoteParityTests` passed over `frus1961-63v06` and `frus1952-54v01p1`, whose d108 is such a document.
    - **The term mentions** (decisions 172 and 188): `term_mentions (volume_id, document_id, term_ref, parts)`, from each `<gloss>` link and `frus1981-88v16`'s `@ana`; read by `PersonMentionStore.termsLinked(inDocument:volumeId:)`, which returns each term's `LinkedTerm` with its `TermMentionParts`. **F7's rows** (decision 178): `division_start_pages`, the start page the parse already settles for every division with an `xml:id` (`VolumeFullParseResult.divisionStartPages`), read by `IndexingPipeline.divisions(startingOn:inVolume:)`, which L39's tap will use.
    - **Two full indexes of the 553 catalogue volumes at corpus `6170e4b32`**, L22's at 75 and this row's at 76 (`ResolvedEdgeIndexGenerator`'s `INDEX_DIR`), read table by table with the id columns set aside: `document_cache` moves in 138 rows (`source_note` on 138, in 47 volumes; `dateline` on 131) and gains `document_order` (0 to n−1 in every volume, in the fresh index's rowid order); `document_revisions` in the same 138 hashes, which the bump rebaselines; `document_sources` gains 138 rows (52 by lot, 48 decimal, 29 a named series, 6 structured, 2 published, 1 unrecognized), 114 with a marking; `term_mentions` holds 498,757 rows for 113,714 documents in 312 volumes (809 naming a term the list lacks, none after decision 189; `frus1981-88v16` 419 for its 88 documents); `division_start_pages` 24,009 rows in 552 volumes, each of the seven Contents targets naming its division; every other table the same.
    - **The regenerations,** at corpus `6170e4b32`'s volumes with the shipped stamps, in one lock: `resolved-edge-index.json` byte for byte (not committed); `cited-page-map.json` differs in `indexVersion` alone (75 → 76); `volume-annotations-index.json` in `indexVersion` and, as it should, in the 47 volumes of the 138: source notes by file number +131 documents and by "Source:" +7, classification +114, no volume crossing a layer's threshold.
    - **What #1854 does to the bundled files that count source notes,** regenerated at R10 and not here: five generators read notes through `DocumentNoteExtractor`, and each control with `v2`'s extractor reproduced its shipped file byte for byte. With L26's, `collection-authority.json` gains one record (`lot:56D676`, from `frus1951v07p2`) and one volume on `lot:63D351`; `collection-usage-index.json` 138 notes (83 in a collection, 47 with a class key, two class keys new); `provenance-flow-index.json` 19 joined references for collections and 12 for classes; `external-citation-index.json` 16 references with both ends, and decision 191 regenerated it in this row, so the shipped file carries them (R10 regenerates it again after the authority); `source-provenance-index.json`, which reads every `type="source"` element itself, nothing. The Source Explorer export reads them too, which L31's brief now says. Each runbook entry has its figures.
    - **The census** (R5's form): the branch's `AppStore` simulator build installed over S1's iPad Pro 13-inch (M5) library under iOS 27.0, at 75: the re-index started 72 s after launch and indexed 553 volumes, 321,749 documents, in **867 s** (concurrency 1), none failed; the rollup consolidated 9.2 s later. Its index, upgraded in place by the app with its bundled resources, equals this row's fresh v76 index in all twelve tables the parse fills; `cross_references` and `external_citations` differ as they did at 75, by the page map and the class labels the generator's index is built without. S1's library was put back at 75 afterwards, for L27 (a clone is at `~/Library/Caches/FRUS-Explorer/l26/pre-census/`).
    - **Checked:** the fail-first control on the committed tree, each kit fix taken out and the mirror put back to `v2`'s: the five new kit tests and the mirror's failed at their guards, and with the read-only guard alone taken out, its test failed. (The first mutation of the term mentions left the insert running, since in Swift a `return` before an expression on the next line returns it; a second, `guard !rows.isEmpty, rows.isEmpty`, failed the test.) T1's test hands the tie over in both orders, which the old rule answers differently. `swift build --target FRUSCoreKit`: no warning in the kit. `swift test`: 5,186 tests in 601 suites over 39 runs, none failed. `build-for-testing`: the two known residues and no other warning. The unit target on the iPhone 17 under iOS 27.0, with `TEST_RUNNER_FRUS_TEI_MIRROR`: 8,278 tests in 1,001 suites passed, 17 skipped as on R5, the six known issues. The Mac build: succeeded, the residues only.
    - **What T1 changes in a capture,** read by Vision OCR over the 131 captures and tour crops for the eight tied pairs: `ipad/browse-root` shows the Subseries list with `1950` above `1950-55`, the order of the launch it was taken in, where this build draws `1950-55` first, so it joins T3's list. The iOS Quick Start, the iOS manual and the website's iOS quick start show it; no store frame does (`tools/marketing/shots.json`). The Mac's sidebar (`macos/browse-all-volumes`, `browse-annotations`, `browser`) shows T1's order already, since it sorts the manifest's own order (`MacCorpusBrowserWindow.subseries`), not `allSubseriesGroups`. No other capture or crop shows a tied pair. **The same tie outside Browse,** in a list no row touches: the Volumes & Storage hubs' download browsers (`DownloadVolumesBrowseView`, `MacDownloadVolumesSheet`) sorted a `Set` of subseries by start year alone, so a tied pair could swap there from launch to launch. Fixed in this row, on the owner's word ("Fix it in L26"): the rule is now the kit's, `SubseriesGroup.listsBefore(_:_:)` and `newestFirst(_:)`, which Browse and both hubs sort by (`SubseriesOrderTests`), and seven EditableContent blocks follow their keys. Onboarding breaks the tie by identifier, ascending (`OnboardingScopeResolver.subseries`), and the Mac's corpus sidebar keeps the manifest's order: each has one order, as before. `SubseriesOrderTests` passed as written and failed under the start-year-only rule; `build-for-testing` showed the residues alone; `BrowserViewTests`, `SubseriesOrderTests`, `EditableContentKeyTests` and `FRUSCoreKitBoundaryTests`, 61 tests in 4 suites, passed on the iPhone 17 under iOS 27.0; the Mac build succeeded.
    - **Decision 188, where each term is linked** (CR's reading of A2, the owner's "Add it to v76"). The walk carries the part down (`collectDocumentRefs(…, part:)`): a heading in the text is the heading's; a source note, and everything inside it, the source note's; any other note a footnote's; an editorial note's own text the document's. `parts` ORs them over the document, with `@ana` as 16. **Measured on a full index at 76 with the column** (corpus `6170e4b32`'s volumes, which `216cdb764`'s equal): the 498,757 rows are the ones the table held without it; 124,616 (25.0%) are linked only in notes, 72,777 in the source note alone, 41,698 in footnotes alone, and 326,903 in the text alone. Read pair by pair against CR's own walk of the TEI (`cr-a2-where_terms.py`, kept as it was and made to emit each pair's flags), all 497,026 pairs it finds carry the same flags; the 1,731 rows it does not find are in the 669 divisions the index stores as documents and it does not (181 prefaces, 152 term lists, prose sections, volume summaries, notes on covert actions). `cited-page-map.json`, `volume-annotations-index.json` and `resolved-edge-index.json` came out byte for byte, as no bundled file reads the table. **Fail-first:** four mutations, one at a time (a link that records the text whatever its part, every note a footnote, a heading that sets no part, `@ana` recorded as text), each failed the new test at its own expectation, and the last decision 172's too. `swift test` after it: 5,187 tests in 601 suites over 39 runs, none failed.
    - **Decision 189, each spelling its own `terms` row** (CR's DATA-2, the owner's "Add it to v76 (Recommended)"). `TermsParserDelegate` keeps each `<term xml:id>` of an item with its own text; an item with two or more gives each a row under its own id, its word as printed less a comma the list put inside the term (`G–1,`) and parentheses around the whole (`(Masjumi)`), with the definition printed after the last spelling, less the joining punctuation at its start, a closing parenthesis among it (`BMM (or BMMG,) British Military Mission`). An item with one spelling takes the path it took. **Measured on a full index at 76** against decision 188's: `terms` 66,203 rows → 66,426, 223 added, none removed, and 200 changed, each an item's last spelling given its own word and the bare definition (`t_HD_1` "HAD", "or HD, Henry A. Dunlap" → "HD", "Henry A. Dunlap"), in 31 volumes; no added or changed row has an empty word or definition or punctuation left at an edge. The 809 `term_mentions` rows that named no `terms` row, in 27 volumes, all name one, and `term_mentions` is the same table. **`volume-annotations-index.json` regenerated** from that index (it counts each volume's terms): `termsListed` rises in the 31 volumes, and `abbreviations` by 14 documents in 6 (`frus1917-72PubDipv08`, `frus1946v11`, `frus1947v03`, `frus1948v04`, `frus1949v03`, `frus1949v05`); the layer still holds 310 volumes from 1951–54, and the file is 71,939 bytes, as before. The page map and the edge index came out byte for byte. **Fail-first:** the suite's 6 tests passed as written; three mutations, one at a time (one row per item, as before; the words left as printed inside the term; the closing parenthesis left on the definition), each failed the new test. `swift test` after it: 5,188 tests in 601 suites over 39 runs, none failed.
    - **Decision 190, how a page reference was resolved** (CR's EDI-2, the owner's "Add it to v76 (Recommended)"). `PageSpanResolver.PageResolution` (`one`, `range`, `number`, `day`, `first`) and the `…Resolution` functions that return it with the document: the rule itself, which each `citedDocument` now forwards to, so the reader's tap, `ResolvedEdgeIndexGenerator` and every caller keep their documents. Both page passes write the page cited and the resolution beside the document, in two columns added as the table's earlier ones were (`cited_page_id`, `page_resolution`); a row left on its page has neither. No reader selects `cross_references` by `*`, and no insert omits its columns. **Measured** on a full index of the 553 volumes built as the app builds it (the kit's pipeline with the five bundled files, through a throwaway release target, removed): no row's values disagree with it; of the same volume's page references, 57,531 resolve (43,947 one, 11 number, 5,262 day, 8,311 first) and 170 stay; of another volume's, 29,391 resolve (21,076 one, 1,954 range ends, 3 number, 2,177 day, 4,181 first) and 19,213 stay. Against the v71 note, the one, range, number and total counts are equal, and 35 references it counted as the first are settled by the day; the census index of this morning, the app's own and built without the columns, holds the same rows as this index in every column they share, so the app already resolved those 35 that way, and decision 190 moves no document. On the generator's index too (built without the map) every shared column is unchanged, and the page map, the edge index and the annotations index came out byte for byte. **Fail-first:** the A18b fixture, read with the two columns, and a same-volume page two documents begin on (first, one, day, number, and a page naming nothing): 12 tests in the two suites passed as written; five mutations one at a time (a page with no note called `one`, a number called `day`, a range called `one`, the same-volume pass dropping its page, the other-volume pass dropping its resolution) each failed the test it meant to. `swift test` after it: 5,190 tests in 601 suites over 39 runs, none failed.
    - **Decision 191, the post-1963 central files** (CR's C2-5; the owner's "Can the post-1963 central files be added to the grammar, so they can be listed as well?", and to this row "Every reader now" and "Yes, both"). `FootnoteIbidGapWalker.subjectNumericVerdict` is the shipped chain's subject-numeric half, which the walker, the app's harvest and the generator read: the clause names the Central Files (`centralFilesAnchorSegment`), not the White House Central Files (whose `PR` and `TR` are handbook categories too) nor the Central Foreign Policy File alone, under a lead the source notes read a designation by (`CollectionKeying.subjectNumericLead`, so `UN 6 CHICOM` reads as it does in a source note). An `Ibid.` naming a file of its own takes its referent's Central Files within three notes, or, first in the document, the document's own source note's (`Outcome.inheritsRepository`). The scanner's third anchor is the Central Foreign Policy File, its film number the file (`SourceNoteParser.cfpfFilmNumber`); an `Ibid.` naming a film number inherits it within reach or, first in the document, from the file's source note, and a bare `Ibid.` after it is the same telegram. Its row joins no collection, since lot 12D215's aliases name the file. The table seeds every document from its parsed source note, as the generator does, rather than behind a word test. **Every reader:** the graph's class nodes and Source Explorer's rows take the subject-numeric files with no change; a subject-numeric row's chip is the volumes' (`unprintedPointerSource`), since no bundled schedule composed it; the class lens's pointer weight folds a key to category and number, as its other weights do (`ArchivalCollectionsData` 1.8), where it had ranked the raw key; the packet's channel is one list (`ExternalCitation.anchorsOutsideThePacket`), which the builder, the plan editor's counts and the sparsity query read; Source Explorer's Add to Archives Visit counts the rows the packet takes (`packetPointers`), where it had counted every row; and three texts name the Subject-Numeric file (the graph's *Navigating*, Flows' scope row and its export caveat). **Measured on a full index built as the app builds it**, against decision 190's: `external_citations` 50,173 rows → 65,549 (7,075 subject-numeric, 3,052 inherited, 1,631 keys in 93 volumes; 8,313 of the file, 426 inherited, 7,569 with a film number, in 62 volumes); every other row the same but 12 bare `Ibid.`s whose last citation is now the file, which had taken a library or a lot cited before it (`frus1969-76v26` d267's notes 3 to 5, the Ford Library). Source Explorer shows Unprinted Material on 38,991 documents (32,419); the graph gains 5,383 class nodes on 4,384 documents; the packet's sparsity stays 13,781, where the old query would read 17,033; Add to Archives Visit offered references that add nothing on 18,638 documents and offers them on none. **`external-citation-index.json` regenerated** (the runbook's entry has every figure): 37,602 class references (30,527), 7,075 of them subject-numeric, which equal the table's; 8,313 of the file, which equal the table's; the 4,460 decimal target keys unchanged beside 1,631 subject-numeric ones. The generator's fifteen samples of subject-numeric rows an `Ibid.` gave, and eight each of the two kinds the source note seeds, read as real citations.
    - **Still owed:** after the merge, #1978's hand-over note for FRUS Explorer Light, as a comment on the issue, which says its server refuses a version-76 export until its pin moves.

- **L27, the tab shell's banner** (F1, #1835). One session on L26's branch or after its merge, since it needs a launch that an index version starts.
  - **First, reproduce.** On the iPad Pro 13-inch simulator, a library at version 75 launched under version 76, with Browse two-pane and the reader open. R6a's probe held through a 74 → 75 re-index there, so also what R6a left untried: the menu bar shown, and Browse's pushes during the re-index.
  - **The reading R6a left unproven:** `TabShellBannerReserve.reserve()` takes the first view controller up the responder chain, and a reserve written to a controller above the tab's host would add its inset to every tab. The owner's frame showed a 188-pt banner over about 322 pt of room.
  - **If it reproduces,** fix it. **If it does not,** the build keeps a log line of the banner's height against the reserve, so that R9's pass on the owner's iPad records what a simulator did not show.
  - **#1835** is the same reserve with the keyboard up, on the iPad mini simulator under iOS 27.0. Its suite's row stays on 26.5 until this row moves it.
  - **Record (2026-11-26, `claude/l27-tab-shell-banner-42ab07`).**
    - **F1 was not reproduced** (decision 183). The device was S1, the iPad Pro 13-inch (M5) under iOS 27.0, in Windowed Apps (the owner's frame shows the corner grip too) and in landscape. A temporary probe, never committed, logged every banner height and every reserve with its host's controller chain. It also logged every controller holding a bottom inset, the keyboard's notices and the reader's frame. There were two runs:
      - `v2` at `bbe6686c`, through its whole 75 → 76 re-index: 553 volumes and 321,749 documents in 992 s.
      - 1823 itself (`build-54`), through PD3's own 74 → 75 start. 1823 still drew the reader's rail as the `.inspector` that R6a's F8 later replaced, and the owner's reader band went when that rail opened.
    - **What both runs tried:**
      - The menu bar shown. A tap on the app's name in the status bar draws the owner's *File Edit View Document Find Window Help*.
      - Browse's pushes toward the owner's own screen, with documents opened and Back. `v2`'s run reached that screen exactly: 1977–80, volume XXIV, Argentina's 66 documents.
      - The reader. `v2`'s run had its rail column open; 1823's had its `.inspector` rail open, then closed, the Read state of the owner's synced setting.
    - **What one run added:**
      - `v2`'s: the software keyboard, the sidebar, a rotation, the Guide sheet and the re-index's end.
      - 1823's: the Dock raised over the window.
    - **What both runs measured:**
      - Every reserve went to the tab's `TabHostingController` under `UIKitTabBarController`.
      - No other controller held a bottom inset.
      - The reserve followed each height change within 6–10 ms.
      - Every settled frame's banner rested on the window's floor, at 1,011.5 pt, and the reader ended at the banner's top.
      - The one band photographed was 40 pt for a single frame, inside the 17-ms flip a volume's start gives the banner.
    - **So the build keeps a log line** (`c7f7d4cb`):
      - A second after a change settles, the reserving view measures the room from the tab content's bottom edge to the window's safe-area floor. It measures the geometry because room set aside by a controller above the host never shows in the host's own inset.
      - `TabShellBannerRoom` judges the room against the banner. It is not judged where a tab bar sits at the bottom or with no banner up.
      - Category `TabShellBanner`: a notice for each tab's first measurement, and an error with every value when the room stops matching. R9's brief says how to read it.
    - **#1835:** on the iPad mini (A17 Pro) under iOS 27.0, the keyboard row's three suites gave 9 tests, 8 passed. #1835's own Browse-root test passed, as in the issue's sixteen runs of 2026-11-01. The one failure is the year-range popover's test: its own keyboard goes down late after its Done, which is not the tab shell's banner. With the same branch it passed under 26.5, so it follows the 27.0 runtime. Through the run's keyboard cycles the new line logged no mismatch. #1835 was closed as not reproduced on the owner's word ("Close as not reproduced").
    - **The row moved** to `OS=27.0` (`.claude/rules/ui-tests.md` and the runbook's entry), with the year-range test read on 26.5 as well until #2024 is placed. #2024 is that test's late keyboard, filed on the owner's word ("File it"); no row holds it yet.

- **L28, the rehearsal** (decision 182). On the owner's Mac, at `v2` once L26 has merged. Nothing is committed but the runbook.
  - **What runs:** `New-Volume-Release-Plan.md` §10's Phase A and Phase C against the corpus as it is, through `Scripts/heavy.sh`; and, if the raw store is at hand, step 11's pack from the last harvest, with no new harvest.
  - **The corpus is the shipped one.** The bundled indexes were built at the corpus's `6170e4b32` (2026-10-14, by `volume-annotations-index.json`). Its `master` is at `216cdb76` (2026-11-02) and has changed no file under `volumes/` since. So no volume waits to be corrected, and every regenerated file should equal the bundled one but for its stamp and for what L26 changes.
  - **What that shows:** no file under `FRUSExplorer/Resources/` has been written since L22, on 2026-11-17. Since then the generators' cores, the word cloud's tokenizers and the semantic rules have been moved into the kits or re-housed (#1979, #1983 and #1987 are three of the eleven pull requests since 1.0). This is the run that shows the moves changed nothing a generator writes, on a day when nothing is waiting on it. A difference found here is found before E, and not the day after.
  - **The runbook's refresh:** its inventory counts 38 bundled data files and the tree has 41; it does not name `cited-page-map.json`, which `ResolvedEdgeIndexGenerator` writes with the edge index; its Phase F ends at TestFlight, where an update also owes the App Store's version page, *What's New*, and the website's figures (§2); and its D-1 gains a line that decision 148 sets its second half aside for this release.
  - **The cost** is about an hour and a half of the Mac by the runbook's §12, and less on the M5. Without the run, R10 would be the first time these generators ran on this tree.
  - **What L26 changes, measured by L26's session on 2026-11-26** (`Planning/Generators-Runbook.md`, each generator's entry). Five generators read a document's source note through `DocumentNoteExtractor`, which since L26 yields the own note of the 138 documents the TEI tags as editorial notes (#1854): the collection authority, the usage index, the provenance-flow index, the external citations and the Source Explorer export. Each control with `v2`'s extractor at `b3acd7ad` reproduced its shipped file byte for byte (the authority, usage, provenance, flow and external citations), and the run with L26's adds one authority record (`lot:56D676`, from `frus1951v07p2`) and moves the usage index by 138 notes (83 in a collection, 47 with a class key), the flow index by 19 joined references and the external citations by 16 references with both ends. `source-provenance-index.json` reads its notes its own way and does not move. So the rehearsal's files differ from the bundled ones by these as well as by the stamp: a control at L26's merge separates the two.
  - **Run on 2026-11-26** by the session the orchestrator started for this row, on the owner's word that L28 "runs its phases pinned to L26's merge (bbe6686c) when the lock is quiet, e.g. overnight, and lands whenever it is done". The fourteen generators built in a detached checkout of `bbe6686c` outside the row's worktree, in 135 s. Each phase was one `Scripts/heavy.sh` job, with L27's and L31's jobs between them, and each run took its bundled file's own stamp, so that a byte-for-byte comparison read content alone. Outputs went to scratch, and nothing regenerated was committed. The checkout and its outputs were removed afterwards.
    - **Every file accounted for** (`New-Volume-Release-Plan.md` §10a, one row each).
      - Byte for byte the bundled file: the manifest (at its second run), the taxonomy, the volume sources, the external citations on the shipped authority, the edge index and the page map, the annotations index, the source provenance, the administrations, the broken references and the validation's two report files, the four word-cloud files under `VERIFY_PRINTED_WALK=1`, the five semantic files, and all 553 shards.
      - Moved by L26 alone, to its figures: the authority (`lot:56D676` added; `frus1951v03p1` on `lot:63D351`), the usage index and the flow index. The usage index has 138 notes more, 83 of them in a collection in 29 records and 47 with a class in 32, two keys new; on the regenerated authority it has one note more, in `lot:56D676`. The flow index joins 19 more collection references and 12 class ones.
      - The external citations on the regenerated authority differ by its record count alone. So the moves since 1.0 changed nothing a generator writes.
    - **Phase B's keyless path ran too**, though the brief named Phases A and C. Phase C's readers take the authority that step 6 writes, and the brief's last bullet counts its moves. Each reader ran on both authorities: the shipped one, to tie its figures to L26's, and the regenerated one, as R10 runs it.
    - **Step 11 from the last harvest:** the store's 2,212 checksums and its contract held. The pool came out B2's, the layout the shipped `46799d5a…`, and the pack all five files and 553 shards.
    - **Found** (decisions 207 to 209):
      - the manifest generator's silent drop, seen in the first run (#2022);
      - the map scripts' defaults and the packer's missing check, read in the code (#2023);
      - the root checkout's stale `layout.bin`, replaced.
      - For the runbook: no `GITHUB_TOKEN` is needed; the authority reads `.cache/volume-sources`, which no commit records; R10's files move the website's 264,598 notes and the manuals' and the guide's 3,977 collections; and no Subject-Numeric key moves, so the label table owes R10 nothing.
    - **The brief's claims, checked** (decision 183): each held but one. The bundled external citations already carry #1854's 16 references, which L26 regenerated for decision 191, so they are no difference here. And since L22, three bundled files have been written, by L26 itself.
    - **The runbook refreshed** (its head and §10a):
      - the inventory: 41 files, 51.7 MB, 21 in Tier 1, `cited-page-map.json` named;
      - §4.5's commands, with every path named;
      - steps 1 to 4, 6, 7, 9 and 11, as run;
      - Phase F's steps 18 to 20c: an update's version page and *What's New*, the website's figures, and the documents' literals;
      - §8's CI;
      - D-1's line for decision 148, and its doc-comment defect struck, since #1191 fixed it on 2026-09-04;
      - §12's costs, measured: one pass of Phases A to D is about 75 minutes of the M5, 60 without the walk, and the rehearsal held the lock for 93 minutes with its controls.

- **L29, what leaves a collection, and what a copy keeps** (#2000, #1999, #1996, #1995). One session, one pull request, a commit for each issue. Kit and app code; no stored data, no CloudKit change, no change to the collection file's format.
  - **#2000.** The rendered formats read a document's research-notes value (`CollectionItemHTMLRenderer.swift:397`, `DocxCollectionExporter.swift:781`, `PDFCollectionExporter.swift:854`). BibTeX and RIS read the collection's alone (`BibTeXCollectionExporter.swift:63`, `ZoteroCollectionExporter.swift:65-69`), the Zotero send reads no option (`CollectionExportSheet.swift:734-735`), and a shared file's notes follow the sheet's one switch (`:621-644`). The fix puts the four under the values the rendered formats resolve, as the second review's H8 directs. **It is first in its wave:** it sends a researcher's own notes where they said not to.
  - **#1999, the import's half.** An import whose headnote id resolves on this account copies the draft under a new id, as Duplicate does. **First, the run in 1.0** the design's §12 names: export a collection with a written headnote, import the file on the same device, edit the copy's headnote and read the original's.
  - **#1996.** Duplicate copies *Stamp active project* and *Append the query log* (`Collection.swift:794-814`), and the snapshot copies what its comment says it copies.
  - **#1995.** An entry added to a collection lands before its back-matter blocks.
  - **From the third review** (J39). The snapshot carries the smart collection's own blocks in their places, as the design's §4.5 says. The code copies none today (`SmartCollectionSnapshot.swift:92-120`), so "copies what its comment says it copies" asks for nothing.

- **L30, Citation Lookup** (#1977). One session, one pull request. Kit code and the app's lookup form.
  - Cite writes the printed number as printed; the parser captures digits alone (`CitationParser.swift:458-470`) into `ParsedCitation.documentNumber: Int?` (`CitationModels.swift:44`). Of 314,646 numbered documents, 722 have a number that is not whole: 83 with a letter, which are answered with the document of the same digits; 628 with a prefix, all in `frus1958-60v05mSupp`; 11 single letters.
  - **The fix is the issue's:** the parser reads the three forms; the engine asks `document(byNumber:)` for the whole token and falls back to the digits only when it finds nothing, so that *Document 1190* still reaches 1190b; the Parsed Fields form, Structured Entry and the Batch splitter keep the printed number.
  - **A public type changes:** a text field beside `documentNumber`, or the type itself. A symbol diff either way, and `FRUS-API.openapi.yaml` if `CitationMatch` follows.
  - **W2's finding, a candidate:** a pasted citation's result names its document by id alone (*d23* over *frus1955-57v14*, `CitationLookupView.swift:772`), though the index holds its head.
  - **By hand, on the Mac:** Copy Citation for `frus1898` d1190b, paste it into Citation Lookup, and it finds d1190b.

- **L31, Source Explorer's year, and NARA's scope note** (#1975, #1976, #1974, #1970). One session, one pull request, a commit for each issue in this order.
  - **#1975 first, since it makes one copy of the rule.** `CentralFilesClassifier.documentYear(fromDateline:)` (`CentralFilesClassifier.swift:690-701`) has three copies in the app: `DocumentView.extractYear(from:)`, `MacDocumentView.extractYear(from:)` and an inline scan in `ResearchRailView.swift`. Each reads a Zulu time as a year (*1515Z*, three documents), a received date for a day-first sent date (three), and an original's slip where the editors correct it in brackets (21).
    - The fix: a word boundary after the year, a day-first date read as sent, the editors' bracketed year taken, the strict parse held to 1800–2029, and the three copies made calls to the kit's.
    - `datelineDateISO` also feeds the chiefs-of-mission tenure match, so the session measures the classification before and after and says what moved.
  - **#1976, by decision 175.** The kit's hydration falls back to the index's own date where a dateline gives no year, and the export reads the dateline first. 8,019 documents gain a year in Source Explorer, eleven of them Numerical File rolls and twelve a coverage gap.
  - **#1974.** The export's runner (`SourceExplorerExportRunner.swift:199-210`) reads a case number with the generator core's own `caseNumber(fromFileNumber:)` (`CentralFilesIndexGeneratorCore/CentralFilesIndexModels.swift`), which lacks the guard #722 gave the kit's (`CentralFilesIndex.swift`, `isDecimalFileForm`). So "File No. 723.2515/110." in a 1908 document is read as case 723, and the export lists that case's rolls: about 335 records, and no screen of the app. **By decision 176** the rule moves to SourceNoteKit, and the kit and the generator's core both forward to it. Two copies is how #722 fixed one and missed the other.
  - **#1970.** `NARACatalogClient.buildResult(from:)` reads `scopeContent` or `description.scopeAndContentNote` (`NARACatalogClient.swift:979-980`); a v2 record carries `scopeAndContentNote` on the record. The fix reads that first and keeps the two older readings. The live answer recorded for #1908 (`NARAAndZoteroClientHostTests.swift`, series 2839192) is its test, so it needs no key.
  - **`Planning/source-explorer-export/`** is regenerated, with the count of records that changed.
    - **Since L26 its generator reads 138 more source notes** (#1854: the documents the TEI tags as editorial notes that print one of their own, which `DocumentNoteExtractor` now yields). Run a control at L26's merge, before this row's three changes, so the count of records each issue moves is its own and not #1854's.
  - **By hand, on the Mac:** `frus1969-76v09` d46's Source Explorer no longer reads 1515; `frus1909` d429 reads 1909 and lists the Numerical File's rolls; with a key, Lot 63 D 351 in RG 59 shows its scope note.
  - **Built on 2026-11-26** from `v2` at `bbe6686c` (L26's merge), on `claude/l31-source-explorer-year-7a9f4b`, by a session the orchestrator started on the owner's word. A commit for each issue in the brief's order: `00bb6465` (#1975), `164245a2` (#1976), `bea93498` (#1974), `f45cb40e` (#1970), then the docs (`69105ead`); then, at the head of the queue, `v2` at `a17023f9` (CR's #2020 and L27's #2021) taken in as `4186ed4e`, with no conflict, and the landing's records.
    - **The owner's four answers of 2026-11-26** (asked in the row's session; decisions 203 to 206):
      - the strict parse is held to **1600–2029**, not the brief's 1800–2029: an 1800 floor took nine correct pre-1800 dates away (the Massachusetts Bay charter of March 4, 1628, a treaty article of 1782, letters of 1793), and with them their dated roll lookups;
      - the year ends **before an ASCII letter**, not at a word boundary, which also refused `November 30, 18811.` (frus1881 d107) and `September 4, 1963è8 p.m.` (frus1961-63v04 d58);
      - the editors' bracketed year is the year **in all 32** datelines that print one, not the issue's 21: in 11 the TEI's own date follows the original's slip, so the rule and the attribute agreed and check 8 never saw them (frus1925v02 d17, `Habana, October 22, 1924 [1925]`, is dated 1924-10-22);
      - where a pre-1906 dateline prints no date, the country series looks the rolls up **by the index's date**, over the recommendation to keep "no year": the fallback reached 462 pre-1906 documents whose datelines print no year (`undated`, `Vienna, November 14.`), which the section left unchecked, and 266 that print a year alone, which it matched against every roll of the country's series.
    - **Each defect shown first** (decision 183): the row's new tests, run on the unchanged code at `bbe6686c`, fail, eleven of them, each on its defect (four of the rule's, the two scope notes', the two of `evaluate`, the export's dateline-first and decimal-citation tests, and the generator core's case number); the two guards of what the rule read right pass there as here; and the measurement harness over a full v76 index read the same code's answers: frus1969-76v09 d46 1515, frus1919Parisv01 d398 1919 (its received date), frus1941v01 d121 1940, frus1921v02 d749 1291; frus1909 d429 no year; frus1864p4 d120 "Not checked — no year"; frus1873p1v2 d63 (`Madrid, 24 December, 1872.`) 134 rolls by an undated lookup.
    - **#1975:** `CentralFilesClassifier.datelineDateISO(from:)` reads a day-first date, the earlier of the two forms being the sent date; ends the year before an ASCII letter; takes the editors' bracketed year; and holds the year to 1600–2029. `documentYear(fromDateline:)` is the one copy: the app's two `extractYear(from:)` forward to it and the Research rail calls it, where the rail's copy read the loose scan alone. Over the 301,070 datelines the v76 index stores: **41 change year** (the issue's 27; 11 more brackets; the 3 misprints, which read none), **4,058 gain a day** (2 before 1906), 5 keep their year and change day, 6 lose their date (3 Zulu, 3 misprints). **The tenure match moves for no document**: the harness's run of `evaluate` over 46,326 pre-1906 candidates at the control and at the branch names the same chief of mission for every document.
    - **#1976** (decision 175): the facts read takes `document_dates`' first and last day (`IndexingPipeline.SourceExplorerFacts.dateISO`, `dateISOMax`); the hydration's year is the route's, else the dateline's, else the index's (`SourceExplorerDocumentContext.year(dateline:indexDateISO:)`); the gate calls a hydrated year of 1906 or later not applicable before it asks for a dateline. The export parses each volume with the kit and reads `SourceExplorerDocumentContext.year(of:)`, the same rule over the dateline and the day the index stores them by (the export core now depends on FRUSCoreKit; only its `DocumentYearExtractor.swift` imports it). **Measured:** 22,394 documents of the index gain a year in Source Explorer, **8,033** of them documents with a source note (the issue's 8,019, at v75): 10 gain Numerical File rolls and 11 the coverage gap (the issue's 23 with frus1910 d91 and frus1914 d602, which move on the export's side). **At the branch every one of the export's 264,736 records has the year Source Explorer hydrates for its document, where 157 differed and 8,033 had none at the control.** And the owner's fourth answer: `CountrySeriesRollDates`, the dateline's day, else the index's days (a span), unless a printed year contradicts them; both views say so above such rolls (`centralFiles.rolls.indexedNote`, a new EditableContent block). Of the 46,326 candidates, 678 outcomes move: the 462 leave "no year" (230 resolve, with a median of 6 rolls; 212 find no match; 20 are sections outside the structure), 8 more of 1906 and 62 with no dateline read "not applicable", 141 print a year alone or a day-first date and list fewer rolls (10,689 in all to 1,218), resolve (2) or find none (1), and the 5 misread years read "not applicable".
    - **#1974** (decision 176): SourceNoteKit's `NumericalFileCitation`, the kit's rule moved unchanged; `CentralFilesIndex` and `CentralFilesIndexGeneratorCore`'s `NumericalFileIndex` forward to it.
    - **#1970:** the client reads a v2 record's own `scopeAndContentNote` first; an empty note is none.
    - **`Planning/source-explorer-export/` regenerated**, with a control at `bbe6686c` first (unchanged code, the corpus at `216cdb764`, the bundled indexes of L26's merge, `GENERATED_DATE=2026-11-26`): 264,736 records, 272 more than the July snapshot's 264,464. Against the control: #1975 alone moves none (the export read no dateline before #1976); **#1976 moves 141** (23 of them decade: 127 to the year the dateline prints, 11 to the editors' bracket, 3 to the index's own day where the attribute's first four digits were the year before, #1326's instant), two of them across the 1906–1910 window (`frus1910` d91 out, for its dateline's 1914, and `frus1914` d602 in, at 1907); **#1974 moves 335**, from a wrong case's rolls to the coverage gap: the 334 decimal-form citations in the window at the control's years and d602; #1970 none.
    - **By hand, on the Mac**, in the check copy built from the branch at `f45cb40e` (the docs commit changes no code), its 298 volumes re-indexed from 75 to 76:
      - `frus1909` d429 lists the Numerical File's three rolls for case 924 (M862 rolls 128 to 130) under the filing period 1906–1910. The control read it no year.
      - `frus1864p4` d120 (`Vienna, November 14.`) lists the Austrian despatch rolls under the new line. d119, which its own dateline dates, lists the same rolls without the line.
      - **`frus1969-76v09` d46's Source Explorer draws no year, at the control or now**, so the plan's first check cannot be seen on d46. The view shows a year only through the Numerical File's box, a decimal citation's filing period, or a note-less document's series. d46's note is the Library of Congress's, which resolves as before. Its 1515, now 1972, is the harness's reading.
      - The misread year shows on `frus1921v02` d749 (`Washington, April 5, 1291—5 p.m.`, `361.11/3696`). Its filing period now reads 1910–1929. The control's year for it, 1291, gets the label 1789–1906 and no filing manual; that is the label rule's answer for 1291, and the control was not run in the app.
      - The scope note was not checked: the check copy has no NARA key, and the owner chose to skip it.
    - **Checked:** on the branch, the package suites the row touches and `swift build --target FRUSCoreKit`; `build-for-testing`, with the two residues alone; 18 scoped app suites on the iPhone 17 under iOS 27.0, 250 tests passed; the Mac build. At the head of the queue, on `b7a75db2` (tree `f6ec50f0`, with `v2` at `a17023f9` taken in as `4186ed4e`): `build-for-testing`, with the two residues alone (`v2`'s merge brought no shared code, and L27's three app files compiled clean); the unit target on the iPhone 17 under iOS 27.0 with the TEI mirror, 8,309 tests in 1,003 suites passed, 17 skipped as at L26, the six known issues; `swift build --target FRUSCoreKit`; `swift test`, 5,234 tests in 606 suites over 39 runs, none failed; the Mac build, with the residues alone; `Scripts/check_repo_hygiene.py`, its six checks passed.
    - **Found, not taken:** of a country series' 51 Austrian despatch rolls, two carry inverted title dates, and of Mexico's, 44 of the 50 a summer's lookup lists: the index's guard matches such a roll on any date, so a dated lookup there lists them all. Pre-existing; it is in §5.
    - **Still owed:** after the merge, the four hand-over notes for FRUS Explorer Light (#1975, #1976, #1974, #1970).

- **L32, the semantic map's slice** (#2010, #1986). One session, one pull request.
  - **#2010.** `SemanticMapReveal.reveal` takes a row's place from `map.placement(at:)`, the plane (`SemanticMapReveal.swift:93-98`), and the model applies it whatever is drawn (`SemanticMapSpikeView.swift:407-427`). The fix proposed here is the issue's first option: the kit's reveal takes the displayed positions, so the web edition's server can reveal on a slice too and drop its own `placed()`. The regions list on a slice selects the region, without the hit test.
  - **#1986.** The slice's year span subtracts `Int.max` from `Int.min` when no volume is dated (`SemanticMapSlice.swift:110`, `:117`); the scale beside it already guards the case (`:164-165`). The fix is the guard, and no tick drawn without a dated volume.
  - **By hand:** *Axis: from here* on one document, *…to here* on another in a different volume; then *Nearest in language* on the selection card. The ring is on the slice.

- **L33, four small kit fixes** (#1989, #1971, #1973, #1972). One session, one pull request, a commit for each. They share no file; they share a landing run, and each is a few lines with its test written in its issue.
  - **#1989.** `ArchiveVisitPlanWrites.duplicate(of:id:now:)` dates every copied target `now` (`ArchiveVisitPlanWrites.swift:175-201`), so the copy can show another stored row than its original where several answer for one target. Each copy keeps its source's `createdAt`; `lastModified` stays `now`.
  - **#1971.** `ChronologyGrouping.monthLabel(fromMonthKey:)` asks a calendar that has no locale for its month names (`ChronologyGrouping.swift:412-415`), so the Mac's magnifier would label a year's months M01 to M12. The issue's author saw that in a probe and not in the app, so the row hovers a year section in 1.0 first. The label and its two callers take a locale, as `group` and `makeChart` did in #1968; public signatures change, so a symbol diff.
  - **#1973.** `SeriesAnalyticsExport.provenance` joins its hidden categories with `.formatted(.list(type: .and))` and no locale (`SeriesAnalyticsExport.swift:116-131`), so the list is written in the process's. It takes the locale its host passes, defaulting to the reader's as #1968's did. Nothing changes on an Apple screen.
  - **#1972, in its narrow form** (decision 177): one public type in WordCloudKit beside `NaturalLanguageHealth`, with a sentence each for *Distinctive*, a live scope's cloud and Collocates, written for a host and not a device. Nothing changes on an Apple screen. Its broad form, which moves the app's own refusals and their EditableContent blocks into the kit, is not this update's.

- **L57, the days of Search's date filter on iPhone and iPad** (#2013; decision 187). One session, one pull request, app code and its tests. No stored property and nothing the index stores, so no CloudKit change and no index version. Its files meet no other row's.
  - **What is wrong, as read.** On iPhone and iPad, Search turns a filter's day strings into dates, and back, in GMT (`SearchViewModel.swift:2784-2789`, `:2864-2868`, `:2585-2591`). Its two pickers are in the device's zone (`SearchFilterView.swift:413-426`). The Mac converts in the device's zone both ways (`MacSearchViewModel.swift:1514-1527`, `:1560-1569`).
    - After a hand-off or a saved search, the pickers show the day before, west of UTC, over an active-filter line and a query that have the right days.
    - A picked day can be written as the day before or the day after, by the zone and the time of day the date carries.
    - *Visualize in Corpus Analytics* reads the filter's years in the device's zone (`SearchView.swift:2473-2476`). A chart of 1961 to 1963, followed to Search and back, would return as 1960 to 1963 west of UTC.
  - **It shows its defect first** (decision 183), and on a Mac in New York's zone it can. The first and the third would show there with no zone changed, on a simulator; the issue gives the two runs. The session also settles what the issue could not: the time of day a date carries after a pick.
  - **The fix the issue proposes:** convert in the device's zone at the three sites, as the Mac's view model and the app's other pickers do, and as the comment on `WordCloudScope.isoFormatter()` says a day's conversion must. One function for both view models, if the session can write one without moving what the Mac does.
    - The other way is to set the two pickers, and the year read, to GMT on iPhone and iPad. It is the smaller change, and it leaves the app with two conventions.
  - **Nothing stored moves.** A saved search converts its own two dates in GMT both ways (`SavedSearch.swift:147-151`, `:252-256`), so its strings come back the same in any zone.
  - **Tests.** `SearchViewTests.dateRangeFilterIncludedInParameters` sets local midnights and expects their days (`SearchViewTests.swift:186-215`). By the issue's reading it passes at or west of UTC only, so a run in New York's zone passes it with the defect in place. The row's own test is a pure function over a date and a zone, or runs with its zone pinned. Two other suites set their dates in GMT; those move to local components with the fix, and the issue lists them.
  - **#2012 is its neighbour, in L56.** Chronology's hand-off writes a day string in the wrong zone, and this is what Search does with a right one. Neither waits for the other.
  - **Owed:** a UI test of the pickers after a hand-off, on an iPhone and an iPad; the manuals, if either says what the pickers show, which the session reads first; an EditableContent block only if a string changes.
  - **By hand,** in the early build, on an iPhone in New York. After Chronology's *Search in this range* for 1 to 31 October 1962, the filter's pickers read 1 and 31 October. A chart of 1961 to 1963, followed to Search and back, reads 1961 to 1963. A day picked in the evening is the day the active-filter line then names.
  - **Record (2026-11-27, `claude/l57-search-date-filter-zone-d90596`).**
    - **Shown first** (decision 183), at `a7d8e017`, whose Search files are 1.0's (none has changed since `1.0-release`), on the iPhone 17 simulator under iOS 27.0, in New York's zone with no zone changed:
      - **The first symptom, in the app.** After a hand-off of 1 to 31 October 1962, Filters' pickers read *Sep 30, 1962* and *Oct 30, 1962*, over the chip *1962-10-01 to 1962-10-31*. The filter held 30 September at 20:00 EDT and 30 October at 19:00 EST: midnight GMT on each day.
      - **The third, in a hosted test.** Corpus Analytics' own hand-off of 1961 to 1963 (`AnalyticsSearchHandoff.parameters`), read back as Visualize read it, gave 1960 to 1963.
      - **What the issue could not settle: a pick keeps the time of day of the date the picker held.** A temporary log line, never committed, recorded From at `1962-09-30T20:00-04:00` before the 5th was tapped and `1962-09-05T20:00-04:00` after, and in Tokyo's zone 09:00 stayed 09:00. So the issue's first branch held: west of UTC, after a hand-off or a saved search, a pick was written as the day after the one the picker showed.
      - The same build in Tokyo's zone showed 1 and 31 October: on this path the defect is west of UTC's, and the UI test's `TZ` reaches the app.
    - **The fix the issue proposed:** the device's zone at every site, not GMT pickers. Filters' pickers are `SearchFilterView`'s, which the Mac's Search window draws too, over a `SearchViewModel` of its own, so GMT pickers would have moved the Mac's; the app's other pickers and `WordCloudScope.isoFormatter()`'s rule are the device's zone; and a project's range and the filter's first dates are made in it.
      - `SearchViewModel.filterDay(of:in:)` and `filterDate(ofDay:in:)` at the five sites: a hand-off's and a saved search's read, the facet's year, the search's two days, the chip, and the chip's record. The zone is `dateRangeTimeZone`, the device's, which the tests pin; Visualize reads `dateRangeYears`.
      - **No one function for both view models.** The Mac reads a day with a strict `DateFormatter` in the device's zone, which reads no date for a day whose midnight a change of clocks skips, and keeps the filter's previous date. `filterDate(ofDay:in:)` takes the day's noon back to its start, the day's first hour on such a day, so a shared function would have moved what the Mac does on those days. Measured on iOS 27.0's Foundation from 1861 to 2000: 27 such days in São Paulo, 42 in Havana, 33 in Beirut, 43 in Santiago, 14 each in Tehran and Cairo, 4 in Tokyo and none in New York. The Mac is unchanged, and its edge is filed as #2033 (decision 210, §5).
    - **Nothing stored moves:** `SavedSearch` and `Project` are untouched; no CloudKit field and no index version.
    - **The candidate, `applyProjectDefaults(_:)`:** onboarding makes a project's range in the device's zone (`ManifestStore.corpusYearStart(_:)`), so east of UTC its first day was written a day early. The fix writes it as made, a test holds it in nine zones, and it needed no line of its own.
    - **Tests.** `SearchDateFilterZoneTests`, 10 tests: the two conversions over nine zones from UTC−11 to UTC+14 (the issue's two tables, a skipped midnight, strings that name no day), and the view model with its zone pinned (a hand-off, a saved search, a chart's years, a pick at four times of day, a facet's year, a project's range). `SearchWithinResultsModelTests`' three tests and `IOSFacetNarrowingTests`' one set their dates on days in the device's zone, where they set GMT midnights; `dateRangeFilterIncludedInParameters` is unchanged, since it holds anywhere now and the new suite is the guard. The seam's two days have a test and a wiring check (`BrowseSeamSignalTests`).
      - **The control:** each site put back in GMT alone, each built and run against the suite: the hand-off's read failed 4 tests, the search's two days 6, the facet's year 1, the chip 3, and the years 2.
    - **UI:** `FilterDateRangeHandOffTests` (in `MeaningResultsSeamTests.swift`), two tests after a hand-off by the search seam's signal, which now carries two days, in New York's zone: the pickers show the handed days, and a day picked in From is the day the chip names. Under iOS 27.0: iPhone 17, 2 passed; iPad Pro 13-inch (M5), each test alone on a fresh boot, 2 passed. **The control** (the conversions put back in GMT, iPhone 17): 2 failed, at From's *Sep 30, 1962*, and at From's *Sep 5, 1962* under the chip *1962-09-06 to 1962-10-31*. On the iPad, `backboardd` aborted in #1620's frames at a second launch on one boot, so each test runs alone; its row in `.claude/rules/ui-tests.md` and its runbook entry say so.
    - **The manuals:** neither says what the pickers show (the iOS manual's *Limit by date*, the Mac's *Date Range*), only that a hand-off carries its range, which the fix makes true, so neither changes. No string changed, so no EditableContent block; nine ranges moved and are re-pointed.

- **L61, two generators' guards before R10** (#2022, #2023; decisions 207 and 208). One session, one pull request, a commit for each issue. Generator code and its tests: no app code, no bundled file, no index version, no CloudKit change. `ManifestGeneratorCore` is shared code that FRUS Explorer Light compiles, so `swift build --target ManifestGeneratorCore` and `swift test` are owed. Both were found by L28's rehearsal on 2026-11-26 (`New-Volume-Release-Plan.md` §10a), and each issue has its lines.
  - **#2022.** A manifest run whose header fetch fails writes the file without that volume, prints that it was written and exits 0 (`ManifestGeneratorRunner.swift:190`, `:207-215`, at `bbe6686c`). L28's first run lost six of 553 volumes to HTTP 503; its second reproduced the bundled file byte for byte. The fix: write nothing and exit 1 when any fetch failed, naming each; retry a 429 or a 5xx a few times, with a pause, before counting it.
  - **#2023.** The two layout scripts default to the 300m's store and pool (`pool_docs.py:22-24`, `build_layout.py:51`), and `SemanticMapPacker.preflight` checks a layout's count, length and clustered rows, never which vectors it was laid out over (`SemanticMapPacker.swift:179`; `LayoutMeta` does not decode `sourceMatrixSHA256`). The fix: the layout's metadata carries the identity of its pool's store, from that store's `run-manifest.json`, and the preflight refuses one that is not the `STORE` it packs, before anything is written (#1439's rule). The session settles what a layout written before the fix, with no identity, gets.
  - **Each shows its defect first** (decision 183): a test over a fetcher that fails, since a live 503 cannot be called up; a test that hands the preflight a layout made from another store's pool, over the suite's small stores.
  - **After it lands,** the runbook's step 2 and §4.5 keep their checks, and their notes name the fix as landed.

- **R8, the early build** (decision 151). One fresh session from `v2` when Waves 1 and 2 have merged. There is no freeze: Wave 3 goes on behind it.
  - **The checklist's first run for 1.1,** as R5 ran it: a clean `build-for-testing` with no source warning; the full unit target on iOS 27.0 and iOS 27.2 (decision 134); `swift test`; the Mac build; the UI suites. R11 runs it again on the frozen tree.
  - **The bump** by `CLAUDE.md`'s procedure, never `xcodegen generate`: version 1.1 (decision 150) and the build number the owner names, the README line and its mirror, both TestFlight notes within 4,000 characters, `fetch-llama-dsyms.sh` and `check_cloudkit_schema.py`, which should read no change, since no row before it adds a stored property.
  - **Both notes say** that a library re-indexes once at the first launch, and about how long, by L26's census; and that the Collections overhaul comes in a later build.
  - **No sitting.** T3 is R11's, when every screen that will change has changed.

- **R9, the device pass of the early build,** on an iPhone, an iPad and the Mac. The owner's.
  - **The one re-index, 75 → 76,** at each device's first launch. On the iPad, Browse two-pane and the reader open while it runs: F1's band, or L27's log line.
    - **L27's log line** is the app's category `TabShellBanner`. Each tab writes *Tab shell room, first measured* once. If a band stays for a second, the iPad writes *Tab shell room does not match the banner*, with every value it measured: the banner, the reserve, the room below the content, the band, the controller written to and its parent, and every controller holding a bottom inset.
    - **If the band shows:** take a screenshot, then pull the iPad's log off the Mac within the hour. The app's own lines last about nine hours on a device. Either collect it: `sudo /usr/bin/log collect --device-name "<the iPad's name>" --last 1h`, which takes the whole device's log, so use the shortest window that covers the sighting. Or start Console with the iPad selected and `TabShellBanner` in its search before the first launch.
  - **What moved into the kit since 1.0,** each opened once and read against 1.0 (1861) on another device: Related Documents' semantic axis and *Beyond your library*; Project Home's reach; search by meaning and a held list; the semantic map, its lenses and a slice; the Word Cloud's count, *Distinctive*, Collocates and the shared-word chips; an Archives Visit's derivation, its writes, Duplicate and its packet.
  - **Each row's own check,** as its brief says *by hand*.
  - **The owner device sitting the 2026-11-15 plan carried,** where the device is in hand: the Topics lens on an iOS 27 device; one Audio Graph heard aloud; the Mac's Sync Log after a sync; the Mac Search window with a selection under VoiceOver, in dark appearance and with Full Keyboard Access; Text Color's picker on an iPad under iOS 27; and the by-eye checks carried from builds 48 and 49 (`Completed/Plan-Of-Record-2026-10-14.md` §4).

- **L37, the rail through a rebuild** (F11). One session, app code.
  - Browse draws one pane or two by width (`BrowserView.swift`, `BrowseTwoPaneMetrics.showsDetailPane`), so a resize across that width builds the reader anew, and `DocumentView`'s per-open task applies *Open Documents In* again: Read closes the rail, Research opens one the reader closed.
  - **First, confirm it:** with Remember Last, the rail stays through the resize.
  - **The fix:** the setting is applied when a different document opens, never when the same document's reader is rebuilt. `RailAtCompactWidthTests` opens its document under Remember Last, so it gains a case under Read.

- **L38, the Mac's windows** (#1946, #1931, F2). One session with Computer Use on the Mac check copy: #1946 and #1931 are labelled *needs local testing*, and F2 shows only in a running Mac app.
  - **#1946.** `ResearchView.loadHeaders()` (`ResearchView.swift:1263`) keeps nothing while the cross-reference store is nil or its query throws, and has no retry. It was seen three times and did not show in R6's pass, so the fix is a retry when the store arrives, with a test that starts with the store nil.
  - **#1931.** A subject's sheet in the Subjects window draws no *All «area» subjects* door, though the data holds its pair. The issue names what was ruled out and a first step.
  - **F2, last.** The row proposes what the title bar holds when its room is short, with captures at 1,200 pt and at the window's least width, and the owner chooses. If the choice is not made when the two issues are ready, they land and F2 follows in a pull request of its own.

- **L39, links that open nothing** (F7). One session.
  - The kit's grammar reads a roman-numeral page anchor as `.unresolved` by design (`FRUSURLScheme.resolveCrossRefTarget`), and an arabic back-matter page names no document, so `PageLink` opens nothing.
  - **By decision 178,** the tap reads the page's row: one the page index already held, or one version 76 stores. Either way a Contents line for the Preface opens the Preface.
  - **A candidate:** the 608 of 48,577 page links into a volume on the device whose page names no document (§5).

- **L40, the iPhone Duo's windows** (D1; decision 179). One session; the simulator alone can show it.
  - The Duo is the one iPhone that supports multiple windows, so the gates on `supportsMultipleWindows` open Analytics and the other aux surfaces as windows there, and a window closed with Done leaves its scene session behind: the next launch reads *2 Views Open*.
  - **The fix:** one helper, read at the gates, that answers as a phone on a phone idiom. The Duo then opens those surfaces as sheets, as every other iPhone does.
  - **And the iPad check:** on the iPad simulator, close an aux window with Done, quit, and launch again. If the window comes back, Done ending its own window's session is that defect's fix, on the iPad, in this row.

- **L41, the Zotero client** (#1923 to #1926; decision 138). One session, kit code and new strings in both manuals.
  - `Backoff` waited before the next request, with a deadline every client sees, since the app makes a new client for each of its three sends (#1924); the waits reported through the send's `status` (#1925); a date `Retry-After` read (#1926).
  - **#1923's resume** is a proposal whose design is the owner's. Without it the row lands the other three.

- **L42, the cross-reference graph saved** (#1990; decisions 146, 180 and 181). One session, one pull request: a commit for each save, then a docs commit. A kit rule and app code, so `swift build --target FRUSCoreKit` and `swift test` are owed. No stored property, so no CloudKit change; no index version.
  - **What the graph draws** (`DisplayNode.Kind`, `CrossReferenceGraphDisplay.swift:36-64`): documents, as the central node, its inbound and outbound neighbours and those two or three hops out; page nodes, which open nothing (`isPageNode`, `:163`); volume clusters and date clusters, each standing for documents; and the archival units and central-file classes that its documents' footnotes point at, a node for each citing document (`unitNodes(rowsByDocument:authority:)`, `:451`).
  - **What both saves take** (decision 180): every document the graph holds as drawn. That is at the chosen depth, within the brushed dates where a range is brushed, with the documents a volume cluster or a date cluster stands for and those in volumes not downloaded, and without page nodes.
  - **Save as Working Corpus.** As the Clusters index and the map's lasso capture one (`ClustersBrowseView.swift:836`, `SemanticMapCapture`): the documents' keys written out, a name by rule with the capture's stamp, no `sourceQuery`, a `sourceDescription` that names the graph's document and its depth, the count of volumes indexed at capture, and the 7,500-key bound with its truncation said before the save.
    - The graph draws documents in volumes that are not downloaded, so the save states its coverage first, as the lasso does.
    - `sourceDescription` is a property 1.0 already stores (`CloudKitSchemaInventory.swift:411`), so nothing is promoted.
  - **Add to Archives Visit.** The picker that Source Explorer, Collections, a collection's record and Archival Neighbors present (`PlanPickerRequest`, `PlanPickerSheet.swift:22-29`): those documents as its seeds, both halves on (decision 181), a basis line and a suggested name. The write is `ArchiveVisitPlanWrites.addingSeeds`, the one path every add flow shares, so the row writes no new rule for a plan.
  - **The visit lists more than the graph draws,** and the picker's line says how much before the write. The graph draws a class for a footnote's decimal number, a unit where a citation joins the collection authority, and nothing otherwise (`CrossReferenceGraphDisplay.swift:452-492`). A visit keys every footnote citation, joined or not (`TripPacketBuilder.referenceKey(for:)`, `TripPacketBuilder.swift:521`). With both halves it also takes the file each seed's own source note names, as Project Home's *Plan a Visit* does.
  - **At the size a graph can reach.** The largest graph the records name has 1,259 nodes. The session reads what `addingSeeds` does with seeds in the hundreds before it offers the action at that size, and says what it found.
  - **The rule that says what is saved is the kit's,** beside the display's own rules and over values: the keys, their count, the truncation, and which documents have an archival node. Its tests run in the package, and FRUS Explorer Light can offer the same two saves from it.
  - **Where the two actions are:** a *Save As* menu in the graph's toolbar on each platform, and on the reference list, which is the graph an iPhone opens on. Each says what it did, as L19 made Add to Collection do.
  - **Owed:** both manuals' sections on the graph, on working corpora and on Archives Visits; the EditableContent blocks for the new strings; two captures in T3.
  - **A candidate in its files:** #1764's unfiled finding, the reference-list toggle that opened nothing on two taps on the iPad (§5).
  - **By hand:** `frus1952-54v02p1` d16 at three hops, saved both ways. The corpus holds its documents and none of its pages. The visit's targets include every unit and class the graph drew, and the files its documents' own source notes name.

- **L56, a range of Chronology saved as a working corpus** (decisions 184 to 186; #2012). One session, one pull request: a commit for #2012, first; one for the kit's rule and the index's read; one for the screen; then a docs commit. A kit rule and app code, so `swift build --target FRUSCoreKit` and `swift test` are owed. No stored property, so no CloudKit change; a read is added and nothing stored, so no index version. After L42 has merged.
  - **Why it needs a row.** Chronology hands a range to two places, a word cloud (`ChronologyView.swift:208`) and Search (`:1206`), and neither leads to a working corpus of the range.
    - Search does not run on a range of dates alone. A search with no words runs only on a person or a subject (`SearchParameters.supportsFilterOnlySearch`, `SearchParameters.swift:426-432`), so *Search in this range* sets the filter and waits for words.
    - With words, the list a corpus is captured from holds at most 1,000 documents on an iPhone or an iPad and 7,500 on the Mac (`SearchViewModel.swift:915`, `MacSearchViewModel.swift:503`).
    - The owner asked for the save in Chronology, so the row does not widen what Search runs on.
  - **#2012, first** (decision 186). *Search in this range* writes its two days through a formatter set to UTC, over a local midnight (`ChronologyView.swift:1206-1215`). East of UTC that is the day before, at both ends: 1 to 31 October 1962 reaches Search as 30 September to 30 October. The kit's own `isoDay` records the same defect as fixed there (`ChronologyGrouping.swift:632-644`).
    - It is read from the code and from an emulation of the two expressions, and was not seen in the app. So the row shows it first (decision 183): the app run in a zone east of UTC, or a test of the expression with its zone pinned. A UI run on a Mac west of UTC passes with the defect in place.
    - **The fix the issue proposes:** hand Search the days the screen loaded, which the view model holds as strings (`loadedStartISO` and `loadedEndISO`, `ChronologyViewModel.swift:92-93`). No formatter is left to be in the wrong zone.
    - **The same change has both hand-offs name the range the screen shows.** Today they read the pickers (`ChronologyView.swift:209-212`, `:1212-1215`), which a reader can move without pressing Show.
  - **What a chronological scope is:** the range of dates the screen last loaded, in whole days, both ends included (`ChronologyViewModel.swift:92-93`). It is not the pickers' values.
  - **What a range holds, by the screen's own rules.** Its query takes every document whose dates overlap the range (`documentsInDateRange`, `IndexingPipeline.swift:6155`). The screen then divides them in three (`ChronologyGrouping.partition` and `splitOverflow`, `ChronologyGrouping.swift:260` and `:280`):
    - those dated inside the range, which the date sections list;
    - those whose dates extend beyond it, a year-only document in a range of one month for one, under a chip;
    - those that span more than a year, which the screen's own footer calls mostly editorial notes, under another chip. Both chips' sections are closed until tapped (`ChronologyView.swift:68` and `:70`).
  - **The save takes all three** (decision 185). That is the set Search's date filter means by a range (`IndexingPipeline.swift:5950-5963`), and the one the word cloud for the range reads, up to its own limit of 5,000. So a count taken inside the corpus agrees, at capture, with a search under the same dates. The save says how many of each kind it holds. Not taken: only the documents dated inside the range.
  - **The legend's filter does not narrow it** (decision 185). A tap on the chart's legend narrows the list to one volume, or to the volumes the chart folds into *Other* (`rowMatchesFilter`, `ChronologyView.swift:383`). It narrows neither hand-off, and every load clears it (`:201-204`). This session found no route to a corpus of one volume's documents in a range without words, and this row adds none.
  - **The save reads the range itself, and not the list.** The list is cut at 5,000 rows (`ChronologyGrouping.loadLimit`, `ChronologyGrouping.swift:197`), and a working corpus holds 7,500 keys, which is the record's size budget (`SemanticMapPicking.corpusCaptureLimit`, `SemanticMapPicking.swift:141`; `WorkingCorpus.swift:48`). So the row adds a read: a range's keys with their dates, in date order, with none of the list's display fields.
    - The index has a keys-only read of a range already (`documentKeysInDateRange`, `IndexingPipeline.swift:6085`). Nothing in the app calls it; its callers are tests, though its comment says Search calls it. It is unordered, and it does not join `document_cache` as the list's query does.
    - The session measures on a full index whether the two reads can differ, and makes the save's count the list's.
  - **The count is the rule's, and not the screen's headline.** Under the list's cap the headline counts the documents dated inside the range (`ChronologyViewModel.swift:200`). Over it, the aggregate that replaces it counts every placed document that overlaps the range, those extending beyond it among them (`:221`; `dateBucketVolumeCounts`, `IndexingPipeline.swift:6336`). The row prints its own three counts, and leaves the headline as a candidate (below).
  - **Over 7,500 documents.** A single year can pass the bound on a device with the whole series. The twelve volumes of the 1945 subseries hold 11,567 documents, and those of 1944, 1946, 1949 and 1943 more than 7,500 each (the bundled `manifest.json` and `semantic-vectors-index.json`). A volume's documents are not all dated in its year, so the session counts the fullest year on a full index.
    - **The save then offers the range cut at the last whole day that fits** (decision 185), and names the corpus for the shorter range. The read is in date order, so that corpus is every document of the range it names, and nothing is recorded as cut short. A second save from the next day on takes the rest.
    - Not taken: a refusal that says how many the range holds; and the first 7,500 with the truncation recorded, as the map's lasso does.
  - **The record,** as the Clusters index and the map make one (`ClustersBrowseView.swift:836`, `SemanticMapSpikeView.swift:2488`): the keys written out; no `sourceQuery`, since no words produced the set; a `sourceDescription` that names Chronology and the range's two days; the count of volumes indexed at capture; and the two truncation fields. The description is enough to make the set again by hand, which is what the model records a query for (`WorkingCorpus.swift:94-100`).
  - **The name is by rule** (decision 185), as L42's, the Clusters index's and the lasso's: the range's two days and the capture's stamp, since the app looks a corpus up by its name and two saves of one range must not share one (`SemanticMapCapture.corpusName`, `SemanticMapCapture.swift:129`). What the save holds is said before it, and what it did after it, as L19 made Add to Collection do. Not taken: Search's sheet, which asks for the name (`SaveWorkingCorpusSheet`).
  - **Where the action is:** with the screen's other two actions on a range, on each platform.
    - An iPhone's bar already holds five items and Done (`ChronologyView.swift:1053`). The session reads the bar's fit at the largest text sizes before it adds a sixth, and may gather the range's three actions into one menu.
    - It is offered whenever the loaded range holds a document of any of the three kinds. The two hand-offs are offered only where it holds one dated inside it (`:286`, `:1114`).
  - **The rule is the kit's,** beside Chronology's own and over values: from a range's rows in date order, the keys, the three counts, and over the bound the last whole day that fits. Its tests run in the package beside `ChronologyQueryTests`, and FRUS Explorer Light can offer the same save from it.
  - **Owed:** both manuals' sections on Chronology and on working corpora; the EditableContent blocks for the new strings, and the ranges of the blocks that cite `ChronologyView.swift`, re-pointed; a UI test of the save on an iPhone, where the screen is a sheet, and on an iPad, where it is a window; a capture in T3.
  - **A candidate in its files** (§5), read from the code and not seen in the app: the headline's two counts, above.
  - **By hand:** October 1962 on a device that holds `frus1961-63v11`. The save's three counts add up to what the corpus holds. A word searched inside the corpus is found in as many documents as the same word under Search's date filter for that month. And with the device's zone set east of UTC, *Search in this range* hands Search the two days Chronology shows.

- **CR, the review of the Collections design** (decision 149). Planning only, so a cloud session can run it. It merges through the same queue, alongside Waves 1 and 2.
  - **First, the design's own text is brought to the owner's answers,** in a commit of its own, so that the review reads what will be built. What moves:
    - the mark is *As published:* wherever the design has *In the volume:* (decision 154): its §3.3, §3.4, §3.6, §4.6, §5.2 and the check in its §9. The words are true of the 22 electronic-only volumes too, which was the design's own test of them;
    - lane 5, §4.4 and the two rows of §5.1 go (decision 156);
    - §4.3's table takes decision 158's openings and decision 167's names;
    - §8.1 and §8.2 are marked with what was taken (decisions 164 and 171), and A5 is not offered;
    - §10's questions are marked answered, each with its decision's number.
  - **Then the review,** as the second was run: six reviewers by discipline, then three skeptics who try to refute each finding against the code, the record and the public TEI. Their reports go under `Planning/collections-design-review-3/`, and the review beside the two before it.
  - **Where it starts.** The design's own two lists (its §11, *Where a reviewer would start*), and what the answers opened:
    - A2, first, for what it asks of index version 76 (L26);
    - where the three things §4.4 said now go (§1c);
    - a section's headnote default: a new field, or the one every entry has (§1c);
    - the nine candidates of §8.1 that were taken, which the design gives a line or two each and nowhere designs: what each stores, what 1.0 does with it, and whether it travels in the collection file;
    - A8, A10, A11 and A12, which change what collections already print, with no switch (decision 171);
    - step 2 with three more ticks, 17 controls where the design counted 14.
  - **What it leaves:** each finding answered in the design's text, sent to a row's brief here, or put to the owner. C2 follows.
  - **Done on 2026-11-26** (the third review, `Collections-Design-Third-Review-2026-11-26.md`; its reports in `collections-design-review-3/`). Nine agents, as the owner chose. 58 findings and the session's own A2, merged to 48: 1 at S1, 22 at S2 and 25 at S3. None was refuted.
    - **Three changed index version 76,** and the owner took each into L26 the same day: decisions 188 to 190.
    - **The design** is corrected in place where it was wrong, each correction marked.
    - **The rows' briefs** below carry the rest, each as a bullet *From the third review*.
    - **Eight questions were C2's** (the review's §8). The owner answered them the same day: decisions 191 to 198, and #2018 filed.

- **C2, the checkpoint.** The owner's, when CR's findings are in. Wave 3 goes on meanwhile.
  - Each finding is answered, and the design's status changes from PROPOSED on the owner's word.
  - **CR's eight questions** (the third review's §8, each with a recommendation):
    - who says, at export, what the export will print (C2-1; recommended: L35, in the sheet's sentence);
    - whether decision 166's "always" covers a headnote switched off (C2-2; recommended: no);
    - the words that say who wrote a headnote (C2-3);
    - what a saved template holds (C2-4; recommended: step 1's seven settings);
    - A3's title (C2-5);
    - which number a citation names where the volume's own differs (C2-6; recommended: history.state.gov's, with the volume's after *As published:*);
    - whether Q9's yes takes the records' date line to the new reading (C2-7; recommended: yes);
    - and the filing of one 1.0 defect (C2-8: a *Summaries* export fails without Apple Intelligence even with every summary stored).
  - **Answered on 2026-11-26** (decisions 191 to 198). The owner took the recommendation on six. On the other two:
    - for C2-3 the owner chose the compiler's name;
    - for C2-5 the owner asked that the grammar read the post-1963 central files, in version 76.
    - C2's rest was answered the same day (decisions 199 to 202): three rows split, decisions 147 and 148 standing, the design accepted, and a person's name in the web page linking like a term. **C2 is done.**
  - The Collections rows, L34 to L36 and L43 to L55, are re-cut where a finding says so. L43 to L55 are this plan's reading of an unreviewed design, and their briefs say what each must settle first.
  - The pace is read against the calendar: the rows merged, E's date if the Office has given one, and where the submission then falls. Decisions 147 and 148 stand unless the owner changes them here.

- **L34, one plan for three formats** (the design's lane 2 and §3.8). One session, one pull request, the largest of Wave 4. After C2.
  - **What it is.** `FRUSCoreKit` resolves each document into a plan, the lines that will print, in order, each with its text, role, heading level and label, where the assembly already resolves the cascade (`resolveEntry`, `CollectionContentAssembly.swift:944-1165`). The web page, the PDF and Word draw the plan. None decides a part's presence, place or wording.
  - **What ends:** the PDF's contents list runs past its first page (#1984); the source note prints once (#1991); a heading is read without its footnote call or the volume's own number (#1992, #2002); the rows are numbered alike, documents only (#1993); a contents row has its dateline (#1994); a title stands above the words *As published:* and never alone (#1998; decision 154); Word prints the volume's footnote numbers (#2001); an editorial note has its heading (#2003, read as L26 leaves the wrapper read); a footnote call with no note behind it is not a button (#2007).
  - **With it, #2005's sentence** (§1c).
  - **A citation record's title takes the new reading of a heading** (decision 165): a Zotero item is titled "Document 1: Letter From President Carter…", without the doubled number or "[1]". It changes what a send or a file carries.
  - **It adds no setting.** A document opens as 1.0 opens it, the citation leading, or under a title where the author gave one. *The volume's heading leads* is built into the plan here, and is chosen from L43 on.
  - **Before it starts:** C2; the Word and Pages run for the contents list (the design's §12: plain linked rows with a page-number field each, against a field over marked entries, each file opened in both); and the three runs in 1.0 that show #1991, #1993 and #2001.
  - **What it owes** is the design's §9: `CollectionRenderingPinTests`' pins for the web page and Word re-taken with their reason, and BibTeX's and RIS's, by decision 165; `CollectionResolutionTests`' two pins; `CollectionExportParityTests` taken to the blocks' order, a source note longer than a line, a research note longer than a page, a contents list longer than a page and a row's number; `CollectionExportContrastTests`' list; the 26 ranged blocks of `Docs/EditableContent/08-Reading-Research-Collections.md` that cite `CollectionExporter.swift`; both manuals' chapter 12; and a kit test that says, for each of the three openings, which line is the document's heading, and that *As published:* is inside the volume's heading.
  - **A candidate in its files:** R2b's unfiled finding, an entry's AI summary row showing the first summary the store returns where the rail shows the newest (the content resolver's fallback).
  - **By hand:** the owner's 52-document collection, as a PDF, a Word file and a web page.
  - **From the third review:**
    - **No placeholder in an exported file** (J10). Where a requested headnote has nothing stored, all three formats print nothing. Today each prints "No stored summary for this document — generate one in the document view to fill this headnote." (`CollectionItemHTMLRenderer.swift:463-466`; `DocxCollectionExporter.swift:2068-2073`; `PDFCollectionExporter.swift:923-929`).
    - **Headings that tell documents apart** (J16). Where the volume's heading leads, the heading or its region carries the citation's number, in the web page and in Word, and Word keeps the citation line with its heading. The kit test reads the Word package as well as the HTML. 56.4% of documents share their heading with another of their volume, and 77.1% before 1952. Where the text does not print, the dateline prints under the heading's words.
    - **One heading rule for every level** (J32): a document under a section, a titled document's volume heading, an attachment's heading (23,768 documents have one), and what happens past six levels. The rule is checked in order in HTML and in Word.
    - **The volume's own number, read by its form in every volume** (J23). Before 1952, 13,669 headings in 39 volumes carry one, 6,091 of them not history.state.gov's. In 1952–1954, 16 of the 28 volumes print none. Which number a citation names is C2-6.
    - **A titled row in *Citation* style** has *As published:* and the volume's heading as its second line, with the citation after it (J46).
    - **The outline's line is this row's** (J38): the title, with the volume's heading under it (the design's §3.4), in `CollectionEntryRows.swift` and `MacCollectionManagerView.swift`. So L35 is developed after L34, or leaves the Mac's file alone.
    - **The records' "Document date:" line** (J44) reads the top level alone, which finds no dateline for 291,438 of 314,616 documents. Whether it takes the new reading is C2-7. Whichever it is, it is said among what a send or a file carries.
    - **Each plan line drawn as its own run, carrying its role** (J19), so that L48 can tag what the PDF draws.
  - **From C2:** a citation names history.state.gov's number, and the *As published:* line keeps the volume's own (decision 197). The records' "Document date:" line takes the one reading's dateline, and is listed among what a send or a file carries (decision 198).

- **L35, export from the lists** (lane 1). One session, one pull request, app code only. After C2; it can be developed beside L34.
  - *Export…* in the Collections list and in Manage Collections; the format remembered on the device; the sheet at the default size, AX3 and AX5, with its sentence, its format and *Export* in view when it opens.
  - **The sheet is otherwise 1.0's** (decision 156): format and destination. This row is the owner's quick export.
  - **With it, in the same file:** the list's Rename, Duplicate and the rest as VoiceOver actions (#2006's first), and a row that opens anywhere along its width on the iPad (R4's finding, `CollectionRow`).
  - **Held by** a fit suite on the iPhone 17 and the iPhone SE, and a suite that reads the action's name.
  - **From the third review:**
    - **The sheet's sentence** (J9; C2-1). If C2 gives it to this row, it is written from what the export will print: the headnote count, and what this device lacks for the template. It holds at AX3 and AX5 with the format and Export in view. 1.0's does not: at AX5 on an iPhone SE its sentence and the grid's first row overflow, and its Export sits inside the form (`CollectionExportSheet.swift:345`, `:353`, `:373-394`).
    - **What this device lacks** (J11). Before Export, the sheet says what the export needs that this device lacks. A *Summaries* export today fails with "The export could not be rendered." on a device without Apple Intelligence, even with every summary stored, since the guard runs first (`CollectionContentResolver.swift:776-778`). That file is outside this row's, and where the fix goes is C2-8.
    - **The remembered format** cannot be the Zotero send, which runs from its row (`CollectionExportSheet.swift:133-138`).
  - **From C2:** the sheet's sentence is this row's (decision 192). So is #2018, with `CollectionContentResolver.swift` among its files: an export reads each document's stored summary before it asks Apple Intelligence, and the row shows the defect first (decision 198).

- **L36, the preview's four repairs** (lane 6, first half; #1997, #2004). One session, one pull request, after L34.
  - It keeps the author's place when the page reloads; choosing a row brings its document into view, and renders it if it is past the first 20; each document on the page is named by its entry, so that one entered twice is two places (#2004, `CollectionItemHTMLRenderer.swift:784-787`); it refreshes on the title override and the Headnotes default (#1997, `CollectionPreviewView.swift:211-266`).
  - **First, the run in 1.0:** with the preview on, switch Headnotes alone and wait five seconds.
  - **From the third review** (J20). A test walks `Collection`'s and `CollectionEntry`'s stored properties against the preview's list, so that the settings L43 to L49 add cannot be left out of it.

- **L43, the new facts** (the design's lane 3 and §7, with lane 7's candidate 6). One session, one pull request, the largest of Wave 5: a commit for each fact with its control, then the research export. After L34. C2 split it (decision 199): the Note on the Text, the statement of sources and the collection file's keys are L58's.
  - **Each fact lands with a plain control in the surfaces 1.0 has,** which L44 then trims. CloudKit makes a field only from the first record that carries a value (`CloudKitSchemaInventory.swift:514-516`), so no property lands without its control.
  - **A collection's citation style** (the design's §6): History at State, Chicago or Turabian, for every place a citation prints. Absent reads as History at State. A new collection takes the style chosen in Settings ▸ Display (decision 160). The batch's formatter becomes `any CitationFormatter`. The *See also* line's join, which runs Turabian's three sentences together today (`CollectionItemHTMLRenderer.swift:390-392`), is settled here.
  - **A collection's opening:** which line leads a document. Absent reads as *the citation leads*, so a collection that exists prints as it does. A new collection starts with the volume's heading leading, 1.0's other settings and no apparatus (decision 159).
  - **A collection's words:** the ten labels of the design's §5.2, each a field that cannot be emptied. They are one text property holding a plain map from a label's name to its text, so that a build which does not know a name carries it through. A test holds that (its §7.3).
  - **A document's date line,** given only under a title (decision 163).
  - **See also for the collection, and a section's headnote default** (decision 164). The first is a new property. The second is a new property too, as CR settled it (§1c).
  - **The research export's version 8,** with a `Fields` case for each new property and a fixture. Duplicate and Create Static Snapshot copy every stored property, held by a test that walks the schema.
  - **The CloudKit gate.** `CloudKitSchemaInventoryTests` goes red as each property lands. Its checklist's first two steps are this row's: the printed list pasted over `installedIdentifiers`, and the new identifiers added to `identifiersAwaitingDeploy`. The deploy is R11's.
  - **Before it starts:** L34; the two-device run and the file run (§2); the desk check of Chicago and Turabian (decision 161).
  - **What it owes** is the design's §9 and §7.4: the Guide's §15, both manuals' chapter 12, the sheet's hint, the ranged blocks of `Docs/EditableContent/08-Reading-Research-Collections.md` that cite `Collection.swift`, the format's own tests, `CollectionExportContrastTests`' list, and a VoiceOver suite on the iPhone 17 and the iPad Pro 13-inch in which each new control speaks its name and value.
  - **By hand:** `frus1946v06` d475 under each opening and each style, and as *The Long Telegram* with a date line.
  - **From the third review:**
    - **A section's headnote default is a new optional property** of `CollectionEntry`, read on headings only (J24). So the promotion is six fields.
    - **The research export's version 8 carries a collection's headnote drafts with its entries,** whatever the AI-summaries switch (J45).
    - **A date line prints only under a title that prints** (J41): what clearing a title does to it, and where a stored date line with no title is shown.
    - **The preview's list** (J20). Each new setting joins `CollectionPreviewView.swift`'s refresh list, or #1997 recurs for each.
    - **The schema walk for Duplicate and the snapshot** names what a snapshot must not copy, `savedSearchId` first (J39).
    - **Before it starts:** the two-device run also drags a document and sorts by date on the 1.0 device, then reads every date line (J25).
  - **From C2:**
    - **A headnote's writer by name** (decision 194). The collection's settings take the compiler's name, unless the title page's author line serves, and each headnote stores its writer's name when it is written. Those are this row's fields, with their controls, and so the promotion is seven fields or eight, with their `Fields` cases at version 8. What an export prints from them, and what the file carries, are L58's.

- **L58, the Note on the Text, the statement of sources, and the collection file's new keys** (the design's §3.6, §3.7 and §7.4; the second half of L43, split at C2, decision 199). One session, one pull request. After L43, on whose fields it builds.
  - **The Note on the Text,** a block (its §3.6): a new value of a field every block's row has. Its sentences are written from the volumes in the collection, and their wording is the owner's.
  - **The statement of sources** (its §3.7): a sentence of the collection's own for the author's lines, and the app's model named as a source where a headnote was generated. That is the rest of #2005.
  - **The collection file** (its §7.4): new optional keys, each written only where it is set, and no change of version. A headnote travels as its text, always, with who wrote it (decision 166), and every import makes a draft of its own. That is the rest of #1999.
  - **What it owes** for the file (the design's §7.4): the Guide's §15 (its two examples, its checker, its account of versions), both manuals' sentence on the file, the sheet's hint, the two ranged blocks of `Docs/EditableContent/08-Reading-Research-Collections.md` the design names, and the format's own tests.
  - **From the third review:**
    - **The Note on the Text is a rule over the resolved entries** (J18), run outside the block seam. The seam gives a block the membership alone, and prints *Nothing to list* for an empty one (`CollectionGeneratedBlocks.swift:155-160`, `:184`). The same rule answers the design's §3.6 line in the collection's settings.
    - **The headnote in the file** (J6 to J8):
      - Off travels as Off, for documents and sections. Today the writer omits Off and the reader takes absent as Default (`NativeCollectionFormat.swift:517-520`, `:757-760`).
      - The keys are the headnote's text, its format (a structured draft is a JSON object) and its authorship, and the brief says what an import makes of a sender's authorship.
      - What 1.0 prints for the new file is stated as it is: an AI summary or the placeholder under *Headnote*. Or the headnote's state travels under a key 1.0 does not read.
      - Whether "always" covers an entry switched off, and the words for who wrote it, are C2-2 and C2-3.
      - The Guide's §15.1a limit, "Headnotes cannot be supplied", is brought to the rule.
    - **`everyApparatusBlockInTwoTemplates` turns red with the Note** (J36), since it runs over `allCases`. It is rewritten over decision 139's five blocks, with the vocabulary pin, and the reason is written where each test is.
  - **From C2:**
    - **Off stays Off** (decision 193): an Off entry's draft does not travel.
    - **A headnote's writer by name** (decision 194). An export prints "Headnote by …", with Apple Intelligence named where it drafted. The file carries each headnote's writer's name, which L43 stores, so an import keeps a sender's name on a sender's headnotes.

- **L44, the three surfaces, trimmed** (the design's lane 4, §4.2, §4.3 and §5.2; decision 153). One session, one pull request. After L43.
  - **The collection's settings open on ten controls:** a row for each step, the title page's five fields, *Citation style*, *Wording* and the linked saved search.
  - **Step 1, Documents:** the six templates and, under them, the seven settings a template sets and the summary prompt. Three are renamed (decision 167): *Summaries*, *Citations with source notes* and *Full text with everything*. The volume's heading leads in four, and the citation in the two *Citations* templates (decision 158). Choosing one changes the seven in view, with a line that says what changed and *Undo*.
  - **Step 2, Apparatus:** *Suggested for…*, *All* and *None* (decision 168); the contents list's style (decision 169) and the word cloud; a tick for each block. Under them are the colophon, the project stamp and the query log, which no shortcut sets (decision 170).
  - **Choosing in step 1 does not change step 2.** Step 2's row then offers the suggested set in one tap (decision 157). No suggested set gains a block (decision 173).
  - **In the kit,** `CollectionPreset.Recipe` is divided in two. Decision 139's table stays as data, each case a document recipe with its suggested apparatus.
  - **A section's sheet** holds the section's six pickers and nothing of the collection's. **A picker's first choice says what it follows:** *Follow the section: On*. **At the collection, a row says how many set their own,** and the count opens the list of them, with *Clear*.
  - **Also:** *Create Static Snapshot* in a smart collection's editor; the Mac's New Collection form as a name and the two steps; and one name for each setting wherever it shows.
  - **#2006's other three:** the per-note switches' names, the section pill's height, and the template cards' fixed type.
  - **What the export sheet will not say** (§1c): a template's needs, and how many headnotes will print, are said here if C2 so decides (C2-1). CR recommends the sheet's sentence, in L35, for the count.
  - **1.0 marks its own card.** It compares its own eight fields, two of which are now step 2's, so a collection set here can show another card *Active* there. Nothing prints by that mark (the design's §4.3).
  - **What it owes** is the design's §9: `CollectionTests.swift:3450-3565` goes on holding decision 139's table, and its tests of what a template writes move to the two steps; the six UI suites of `CollectionEditorTitleTests.swift` are brought to their surfaces; a fit suite and a hit-area suite for the cards and the pill at AX3 and AX5; the VoiceOver suite; a walk of the Mac's gear popover with a step opened in place; both manuals' chapter 12, the captures that show the editor, and the tour's step 16.
  - **Candidates in its files:** IPA-3's whole-collection Sort and MAC-11's Done (§5).
  - **From the third review:**
    - **The one tap on step 2's row** (J14): whether it adds or replaces. It is labelled by what it does, every change it makes is listed, and its Undo is where the change shows on each platform.
    - **What is in view after a choice** (J17). Each step's line of change and its Undo sit where the choice was made, for step 2's shortcuts as for step 1's cards. The fit suite checks what is in view at AX3 and AX5 after a card and after *None*.
    - **A collection that equals no template** (J26). A new collection ties at two differences between *Full text as printed* and *Summaries*. The brief says what step 1's row and the Mac's New Collection menu show for it, and which settings differ.
    - **Step 2's row is two controls** (J30). The brief gives its anatomy for touch, VoiceOver and the keyboard.
    - **What it owes besides** (J37):
      - the 24 template blocks of `08-Reading-Research-Collections.md`, renamed and reworded in the owner's words, and its 28 ranged blocks;
      - the three `CollectionEditorTitleTests` tests that reach the collection's fields through a section's sheet, moved to step 2's switches, with the suite's row in the rules file.
    - **A section's sheet holds seven pickers**, with its headnote default.
    - **The prompt's error** names the screen that holds the prompt, not a "Composition section" (J11).
  - **From C2:** the headnote count is L35's, in the sheet's sentence (decision 192). This row's cards may say a template's needs.

- **L45, pointing on the Mac** (the design's lane 6, second half). One session. After L44. C2 split it (decision 199): the iPad's settings column and the opening drawn in a document's settings are L59's.
  - ***Show Parts* on the Mac** (its §5.3): a switch on the preview and in the View menu. On, each part of a document is outlined and named. A click on a part selects its document's row and brings that part's control into view in the column. Keyboard focus stays where the click was, VoiceOver is told what is selected, and every part is reachable from the column by keyboard alone.
  - **The iPhone is unchanged:** its outline and its preview are never on screen together.
  - **The parts are the plan's** (L34). The row reads a line's role from the plan and writes no second list.
  - **Held by** a walk on the Mac, since nothing automated holds the Mac.
  - **From the third review:**
    - **A part on the page is marked, never made a control** (J33): its name is in text, and its click is caught by the page. So its links and footnote calls stay reachable.
    - **A click that lands on a link inside a part** (J34). The preview allows in-page jumps, so a term's link (decision 174) would move the page. Say which wins.

- **L59, the iPad's settings column, with pointing there, and the opening drawn in a document's settings** (lane 7's candidate 13; the second half of L45, split at C2, decision 199). One session. After L45, whose pointing it shares.
  - **A settings column on the iPad,** with pointing there. Today a document's settings are a sheet over both columns (`CollectionEditorView.swift:863-873`), so a tap on the page cannot be answered beside it.
  - **The opening drawn in a document's settings.** The second form had it, and the third withdrew it because it could not share the screen with the field at the largest text sizes (its §5.6). So this row shows it at AX3 and AX5 before it builds it.
  - **Held by** a suite on the iPad, with its devices and its assertions named, at the default size, AX3 and AX5.
  - **From the third review:**
    - **The iPad's column** (J13). Composer v2 removed this column on 2026-07-12 "so the reading surface stays clear" (`CollectionEditorView.swift:832-836`). The brief says:
      - the widths at which the column shows and gives way, after Browse's rule (`BrowseTwoPaneMetrics.swift:27-35`), and what the outline and the preview keep;
      - whether it is an `.inspector` or a column the editor draws;
      - what it does at AX3 and AX5, where a 280-pt column takes about three landscape screens for the eight pickers;
      - the iPad suite's devices.
    - **A part is marked, never made a control, and a click on a link inside a part,** as in L45 (J33, J34).

- **L46, selected passages as a document's text** (candidate 1). One session. After L44.
  - **A fourth choice of text depth:** the passages the author highlighted, in the document's order, under the volume's heading, which prints at every depth.
  - **Nothing new is stored in CloudKit.** Text depth is a stored string at each scope, and this is a new value of it. 1.0 (1861) reads a value it does not know as the full text (`CollectionExporter.swift:310`).
  - **The passages travel in the collection file as text,** as a quoted passage does, since highlights do not travel (`NativeCollectionFormat.swift:55-58`).
  - **The sign for an omission is the owner's.** Brackets are the editors' additions (the design's §3.1). By this repository's own record, a row of asterisks is the editors' mark of an omission before 1925, and an ellipsis theirs from 1925 to 1991 (`FRUS-History-Feature-Assessment-2026-11-09.md`). The design's reason for the mark applies here: words are read aloud, and collide with nothing the volumes print.
  - **Four more that the design does not say,** which the row proposes and the owner chooses: whether the volume's dateline prints where the author highlighted none of it; what a document with no highlight prints at this depth; whether a highlight the reader marks as stale is printed; and whether the depth is offered for a section and a collection, or for a document alone.
  - **The Note on the Text names** the documents that print as selected passages.
  - **From the third review:**
    - **Where an imported passage is kept** (J12). A document entry's `text` is nil by rule, and an import gives the recipient's own highlights. A stored home joins the promotion and version 8. Say which prints when an entry has both, and run the excerpt check over passages that came from a file.
    - **Which highlights make the passages** (J29): all, or the document's selection. Say what *Highlights in body* and the per-highlight switch mean at this depth.
    - **One cut, in the kit** (J29): a render model of the passages and the notes they call, which the three exporters draw. Which footnotes print is a fifth question.
    - **The omission sign's word** is checked against the volumes' own. They print "[omission]" 309 times with variants, in brackets, which the design rules out, and an ellipsis in 2,223 documents from 1969 on (EDI's count, not recounted).

- **L47, *Save as Template*, and *Same settings as…*** (candidates 2 and 9). One session, a commit for each. After L44.
  - ***Save as Template*:** an edited set of settings kept under a name, for other collections. It is authored content, so it is a record type of its own (the design's §8.1): a new model in `frusModelTypes`, which the CloudKit gate catches and R11 deploys.
    - It joins the research export's version 8, with its own records.
    - A collection file carries the settings and not the template.
    - **What a saved template holds is the owner's:** step 1's seven settings, as each of the six holds; or both steps.
    - A record type that syncs can be made twice, on two devices. The design's §7.6 says what the cleanup must not do to authored content, as #1791 ruled for notes.
  - ***Same settings as…*:** one document's settings copied to others. It writes the fields 1.0 has, and stores nothing new.
  - **Held by** the VoiceOver suite, for both actions' names.
  - **From the third review:**
    - ***Same settings as…* copies the cascade's pickers alone** (J1, the review's one S1): text depth, the summary prompt, the six switches and the headnote switch.
      - It never copies the title, the date line, the note and highlight selections, or the headnote's draft, which name the source's own records.
      - The kit takes chosen notes and a headnote by id with no check of their document (`CollectionContentAssembly.swift:1004-1011`, `:1364-1366`). So a target would print the source's, and an edit or a delete through a target would delete the source's headnote (`CollectionEntryInspector.swift:1158-1173`; `GeneratedSummary.swift:238-243`).
      - The brief says the direction, what a following value does to a target's own, and where the action is. It is tested on a source with chosen notes and an edited headnote.
    - **Where saved templates live** (J15): where they are listed, applied, renamed and deleted on each platform, and how step 1's comparison and *Suggested for…* treat one. What a saved template holds is C2-4, told first that "both steps" changes step 2 from step 1.
  - **From C2:** a saved template holds step 1's seven settings (decision 195).

- **L48, the page** (candidate 7). One session. After L44. C2 split it (decision 199): the tagged PDF is L60's.
  - **The page:** Letter or A4; each document on a new page, or run on; page numbers in Word. The PDF's page is fixed at 612 by 792 points today (`PDFCollectionExporter.swift:177-178`).
  - **Where the choices are kept is the owner's.** On the collection they are stored properties, and join the promotion, the collection file's keys and version 8. On the device they are kept as the remembered format is, and nothing is promoted. A paper size follows the person who prints; a page break before each document follows the work.
  - **What 1.0 prints stays the default,** so no pin moves until a choice is made.
  - **Held by** the PDF's page size and breaks read back, and Word's package read for its page size and its footer.
  - **From the third review:**
    - **The defaults by format** (J28). Before a choice is set, each one reads what each format prints today: a page per document in the PDF, a break after each document's text in the printed web page, none in Word. One control shows that.

- **L49, a short citation form** (candidate 11). One session. After L43.
  - *FRUS*, 1946, vol. VI, doc. 475. Year, volume and document name more than one volume for 133 of the manifest's 553 (the design's §6).
  - **So the rule comes first, and is the owner's to accept:** a form that names one volume for each of the 553, held by a test that walks the manifest.
  - **Where it prints is the owner's too.** The design names the form and no place for it. The places a full citation repeats are the *See also* line, a contents row in *Citation* style, and the rows of the two new lists (L51, L53).
  - If the choice is kept on the collection it is a stored property, and joins the promotion and version 8.
  - **From the third review.** The manifest holds two first editions beside their second editions (`frus1951-54Iran`, `frus1969-76ve15p2`), so a unique short form names the edition.

- **L50, a line of coverage** (A1). One session. After L44.
  - **What it says:** what the collection's volumes give a block. The blocks fill from what a volume's editors marked, and that differs by era. 265 of the 553 volumes tag no person, so a Persons Index over them is the one row *Nothing to list* (the design's §8.2).
  - **Where:** under a block's tick in step 2, on its row in the outline, and on the page under the block's title where the block is empty or partly filled.
  - **What it reads:** `VolumeAnnotationsIndex` (`Browser/VolumeAnnotations.swift`), passed to the blocks' data source as the archival indexes are.
  - **What it must not say.** The file counts by volume, at one index version and one commit of the corpus. It does not say which documents, or what a corrected volume now carries. R10 regenerates it.
  - **The wording is the owner's.** The People browser's caption is the precedent (`AnnotationsAxisViews.swift:472-482`).
  - **First, the run in 1.0:** the eight telegrams of `frus1946v06` with a Persons Index and a Sources & Archives block, read in the preview (§2).
  - **What it owes:** a new requirement of the blocks' data source, which both fixture sources answer; `CollectionResolutionTests`' pin where a fixture's block is empty; and the line spoken with its tick's name and value.
  - **From the third review:**
    - **What A2 and A4 fill from** (J40). A2's count takes terms linked in any part or on `@ana`, where the block lists only what prints, so the block says where it left terms out. A4's line reads `xrefDocuments`, where the block also fills from page references (`xrefPages`, `xrefVolumes`).
    - **The read's protocol** (J35). A new read on the blocks' data source has eight conformers, the Archives Visit packet's source and four of its test stubs among them. Say which protocol it joins.

- **L51, *Documents cited, not included*, and *See also* by page** (A4 and candidate 10). One session, a commit for each. After L50.
  - **The join both need.** A reference to a printed page is stored under its page (`CrossReferenceStore.swift:757-759`), so it matches no document of the collection. The app already maps a cited page to the documents on it (`Citation/CitedPageMap.swift`, and the device's page index).
  - ***See also* by page:** the line then matches a page's documents against the collection's. The volumes through the 1950s refer by page, so for a collection of them the line prints more than it did.
  - **The block:** the documents the collection's documents cite and the collection does not hold, most cited first, each with the documents that cite it. A list, and not a picture.
  - **A page that holds several documents** is the row's to settle and to say on the page: every document on it, or none.
  - **A new block type owes** (the design's §9): a case in every `switch` over the types, with its title, its symbol, its usual place and its resolver; a line in what an export drew on; a tick in step 2; its title among the collection's words; and both manuals' list of the blocks.
  - **From the third review** (J4). The join is the index's already.
    - A page reference is stored as the document on the page (`IndexingPipeline.swift:10631-10697`), so 1.0's See also line already matches same-volume page references.
    - "The line prints more than it did" holds only for the other volumes' rows left on their page: "ff.", ranges across documents, and pages naming nothing (19,186 at version 71).
    - Since decision 190 each resolved edge keeps `cited_page_id` and `page_resolution`, so the block marks a `first` pick, or lists every document on its page.
    - "The join both need" above is to be read with this.

- **L52, *Abbreviations & Terms*** (A2; decisions 172 and 174). One session. After L51.
  - **What it prints:** each abbreviation the collection's documents use, with the volume's own definition and the documents that use it. It reads version 76's table, as the Persons Index reads the people's.
  - **A term in the web page** links to its row where the collection has the block, and is plain text where it has not (decision 174). Today it is a `frusexplorer://gloss/…` link that a browser cannot follow (`FRUSRenderNodeHTMLSerializer.swift:899-902`). Word and the PDF already write the term as plain text.
  - **First, the run in 1.0:** one of the telegrams exported in full as a web page, opened in a browser on a Mac that has the app and on one that does not, and *Dept* clicked (§2).
  - **Reach:** 312 volumes link a term in at least one document. L50's line says so for the rest.
  - **What it owes:** what a new block type owes (L51), and the web page's pin, re-taken with its reason.
  - **From the third review:**
    - **Rows and links keyed by volume and the editors' id** (J5), with the block's instance in an anchor, since a block can be placed twice. The volume is named beside a definition where the collection spans volumes. One abbreviation means two things in one volume (`frus1946v11`'s *BA*) and across volumes (1,063 abbreviations). A row has no id today (`CollectionExporter.swift:1196-1218`).
    - **What prints, not what is linked** (decision 188). The blocks' data source passes, for each document, the parts its resolved settings print, and a term is listed where a part that links it prints (`collections-design-review-3/a2-what-the-index-owes.md`).
    - **An `@ana`-only term** (J40): what it counts as is said. No export prints `@ana`, so under the rule `frus1981-88v16`'s block is empty.
    - **One row per spelling** (decision 189).
    - **The other links beside a term's** (J34): what the web page writes for a person's name and a cross-reference where a term's link now works, and what the preview does with an in-page jump.
  - **From C2:** a person's name in the web page links to its row in the Persons Index where the collection has that block, and is plain text elsewhere, beside the term links (decision 202).

- **L53, *Unprinted material cited*** (A3), titled *Archival files cited* (decision 196). One session. After L52.
  - **What it prints:** the archival files that the documents' footnotes point to and the volumes do not print, grouped by file, each with the document, the note's printed number and the editors' words. The index stores each pointer (`external_citations`), and one read answers for a list of documents.
  - **Three rules it keeps** (the design's §8.2): it is a block of its own, and never a part of Sources & Archives; it lists what the footnote grammar reads, and says so on the page; and a row prints a note's number only where the volume printed one.
  - **Central files are in,** though the Archives Visit packet leaves them out. Before 1955 they are the only pointers there are. (The third review's J21: not so. Before 1955, 2,556 footnotes name a lot or a library.)
  - **Since index version 76 the grammar reads the post-1963 central files** (decision 191, built in L26): a Subject-Numeric file is a `centralFileClass` row whose `decimal_class` is its designator (`CollectionKeying.isSubjectNumericClass` tells it from a decimal number), and the Central Foreign Policy File a `centralForeignPolicyFile` row with no collection, its film number in `file_id`, labelled by `ExternalCitation.displayLabel`. Grouped by file, the Foreign Policy File's rows are one group (8,313 rows in 62 volumes on a full index), each row a telegram's film number, which the block's session may want to divide. A designation with no number (`Central Files, POL US–USSR`) is still not read in a footnote, and the page says what the grammar reads.
  - **First, the run in 1.0:** Source Explorer's *Unprinted Material* rows for `frus1946v06` d474 and d475, against their notes 39 and 44 (§2).
  - **What it owes:** what a new block type owes (L51).
  - **From the third review:**
    - **What it lists, by years** (J21). At the review, the grammar read lots, libraries and decimal files, which end in 1963. From 1964, 11,659 of the 21,020 footnotes that name a file named only kinds it did not read. Decision 191 has since had it read the subject-numeric files and the Central Foreign Policy File. The page says which kinds are listed for which years, and what the grammar still does not read: a designation with no number, about 500 clauses.
    - **Its read** (J35) is the very query that the Archives Visit packet's refinement keeps out of the blocks' protocol (`TripPacketBuilder.swift:712-716`). The collections' source conforms to that refinement rather than lift the query.
  - **From C2:** the block is titled *Archival files cited* (decision 196). From index version 76 the grammar also reads the subject-numeric files of 1963–73 and the Central Foreign Policy File (decision 191). So the block lists them as the grammar reads them, and the page's line says which kinds for which years.

- **L54, three of 1.0's blocks changed** (A8, A10 and A11). One session, a commit for each. After L53 and L49.
  - **Sources & Archives, by file class** (A8). Today a central file is a group of one: eight telegrams make eight groups. The block groups by class, with the class in words for the files of 1910 to 1973 (`DecimalClassLabelTable.swift`, `SubjectNumericLabelTable.swift`). The index stores each note's class, and the block's read does not select it (`IndexingPipeline.swift:6490-6492`). A scan's link, where there is one, says that it is a file's and not a document's.
  - **Bibliography, by volume** (A10): a volume cited once, with its documents and the pages each is printed on. The formatters have a form for a document and none for a volume, so each of the three styles gains one, and the desk check covers it (decision 161).
  - **Chronology, by administration** (A11): a heading where the presidency changes, from the dates the app holds.
  - **None has a switch** (decision 171). Every collection that has one of these blocks prints differently from this row on. `CollectionResolutionTests`' pin (`:157-160`) moves once, for all three.
  - **Both manuals** say what each block prints, and are brought to it.
  - **From the third review:**
    - **A8 groups by class and by schedule** (J47). The Department renumbered its classes on 1 January 1950, and 127 keys are cited on both sides of that day. A scan's link carries the caveat Source Explorer gives its route, a roll's or a range's, on the document's row.
    - **A11's rule at a change** (J48). The app gives each day of change to both presidents: 26 documents are dated 12 April 1945, 17 are dated 9 August 1974, and 3,229 ranges straddle a change. Say where each goes, and say on the page that the heading falls by date. Its heading needs an exporter, which this row's files do not name.
    - **The reads' protocol** (J35), as in L50.

- **L55, the word cloud's terms as a table** (A12). One session. After L54.
  - **What it adds:** under the image, a table of the terms and their counts, with a header for each column, in the web page and in Word. Today the image's alternative text is one sentence, the same for every collection.
  - **The terms are counted and then dropped** (`WordCloudExport.swift:171-190`), and an exporter is handed a picture and its size. The handoff, `CollectionWordCloud`, carries the terms too. It is a public type that a host fills, so a symbol diff, and the web edition is told.
  - **A second list, the distinctive terms,** by the measure the Word Cloud calls *Distinctive*, with the caveats that measure carries on screen.
  - **No switch** (decision 171): every collection whose word cloud is on prints the table.
  - **Held by** a kit test over the HTML and the Word package, and the two pins re-taken with their reason.
  - **From the third review** (J22):
    - **Which terms.** The table lists the terms the image places, at most 140, which are the cloud's own accessible list (`KeynessCloud.swift:40-41`). Every term counted once or more would be about 2,300 rows for the eight telegrams.
    - **What was counted.** The count covers every document's whole text with its notes, whatever the export prints, under the device's word forms and hidden words (`WordCloudExport.swift:158-172`). The table says so, or counts what the export prints.
    - **The PDF.** Whether it prints the table, and how, since its cloud comes from another path (`PDFCollectionExporter.swift:208-212`) and its tables are lines. The parity suite holds the three formats to that.

- **L60, a tagged PDF** (candidate 12; split from L48 at C2, decision 199). One session. After L55, the last of the Collections rows, so that it tags what every other row draws.
  - **A tagged PDF:** a title, links, and tags from the roles the plan gives each line (L34). Today the PDF has no tags, title or links (the design's §3.8).
  - **First, a small proof,** since no one has made a tagged PDF in this app: two pages with a heading, a paragraph and a link, tagged, and read with VoiceOver on a Mac and an iPad. The row goes on if a heading is announced as one.
  - **Held by** a test over the PDF's structure where one can be written, and by that walk.
  - **From the third review:**
    - **The API's floor** (J19). The structure-tree API and `CGPDFTagTypeArtifact` are `API_AVAILABLE(macos(27.0), ios(27.0))` (`CGPDFContext.h:397`, `:480`), and the app targets 26.0 (`project.yml:78`). So the row builds on `CGPDFContextBeginTag` (`:461`), or gates by OS.
    - **The drawing** (J19). The PDF draws a document's body as one string in frames, with one `CTFrameDraw` each (`PDFCollectionExporter.swift:796-847`, `:1494`). Tagging a heading inside means drawing it as its own run, which L34 is asked to do. The proof is the exporter's own document crossing a page break, with a link from a contents row.
    - **What it marks beyond the plan's lines** (J19): tables as tables (8,820 documents hold one, drawn as cells joined by " | "), figures with text, page numbers as artifacts, and the document's language.

- **R10, the Office's release taken in** (decision 152). At E. `New-Volume-Release-Plan.md` §10 is the runbook, and L28 has run most of it once.
  - **The queue pauses.** The row in flight finishes and merges, R10 runs and merges, and the rows resume. If L26 has not merged, it lands first.
  - **Phases A to D** as written: the manifest; the archival chain if the volume names a new lot; the corpus analytics, with `CloudVectorsGenerator`'s four files in one run; the owner's harvest on the Air and the pack at `DIMS=512`, the provenance digest unchanged (§4.2 is the hazard); the map relaid and its new cluster labels read; the shard pushed to `joshbotts/frus-semantic-vectors` before the build ships, with that repository's own record (step 13a).
  - **A corrected volume** takes D-c0 to D-c4. Its re-packed shard is not pushed until R11: from the push on, 1.0 (1861) refuses a fresh download of that volume's shard.
  - **Phase E only if the drops have landed** (D-4): the Office's subject export, which is where #1696 is read again, and the person registry, whose regeneration raises `currentPersonRollupVersion` in the same commit.
  - **By the volume:** §7.2's coverage eras only if its midpoint is past 1992; §7.3's subseries label and place, by eye, which L26's sort now holds steady.
  - **Phase F:** the pins re-measured, never bumped by arithmetic; the listing draft's figures; `swift test` and the unit runs.
  - **A candidate the audit of 2026-09-27 left:** Archives Visit derivations going stale when a volume updates. R10 is when a volume updates; the session says what it sees.

- **R11, the freeze and the release candidate.** One fresh session from `v2` when L55 and R10 have merged. The freeze starts when it does.
  - **The corpus is read again.** If a file under the corpus's `volumes/` has changed since R10, the runbook runs for it before anything else. A corrected volume's re-packed shard is pushed now.
  - **The CloudKit promotion, the owner's.** By `CLAUDE.md`'s checklist: each new field, and a saved template, exercised once on a Development build with iCloud signed in; then *Deploy Schema Changes to Production* in the CloudKit console. The session then clears `identifiersAwaitingDeploy`, re-runs the suite, pastes the count and digest it prints, and brings `deployedThroughBuild` and `deployedOn` to the release candidate's. `check_cloudkit_schema.py` reads Production itself, and no archive is made until it passes.
  - **The checklist,** as R8 ran it, on the frozen tree.
  - **The bump:** the build number the owner names, the README line and its mirror, both TestFlight notes, and `fetch-llama-dsyms.sh`.
  - **Both notes say** what the new volume is; what changed in Collections, and that an export prints differently from 1.0's; and that a library which skipped the early build re-indexes once.
  - **The release candidate** is archived and uploaded to TestFlight.
  - **Sitting T3** (decision 88): every screen the rows changed, on the iPad simulator with the full library and in the Mac check copy. The collection's settings and both steps, a section's sheet, a document's inspector, the lists and the export sheet, a collection's three exports with each new block, Citation Lookup's result, Source Explorer's year, the graph's two saves, and Chronology's. Browse's Subseries list on the iPad (`ipad/browse-root`), where L26's T1 puts `1950-55` above `1950`. And any store frame that shows one of them.

- **R12, the device pass of the release candidate,** on an iPhone, an iPad and the Mac. The owner's.
  - **Two devices on one iCloud account, one still on 1.0 (1861).** It is the design's first run (its §12), made again on Production with the two builds readers will have. On the release candidate, set each new fact on a collection the other device holds. Rename that collection on 1.0, then drag a document and sort by date there, and read every fact on the release candidate, each entry's date line among them (CR's J25: 1.0 re-sends every entry record on a reorder). Update the second device, and read the facts there before the first touches the collection again.
  - **A collection file both ways:** one the release candidate writes, opened in 1.0 (1861); and one that 1.0 wrote, with a headnote, opened in the release candidate.
  - **The new volume on each device:** in Browse under its subseries; its download and its index, with no re-index of the library; a document read; a keyword search and a search by meaning that reach it; its place on the map; its Sources and an Archival Neighbors row; a corrected volume's shard fetched again (D-c4) and its documents in file order.
  - **Each Collections row's own check,** as its brief says *by hand*, and the owner's 52-document collection in the three formats.
  - **A saved template** made on one device and read on another.

- **R13, the submission.** The owner submits with §2's entry, and tags the commit as decision 113 tagged 1.0's: `1.1-release`. On approval: the release, the website's figures and the launch kit's note (§2), and the web edition's line about the pin.

---

## 2. The update — what only the owner does

- **The merges,** each row's in turn, and **the answers to CR's findings** (C2).
- **The runs in 1.0 (1861)** that rows wait for, each a few minutes in the released app. A session with Computer Use on the Mac can make them, if the owner would rather.
  - For L29: a collection file with a written headnote, imported on its own device; edit the copy's headnote and read the original's (#1999).
  - For L34: `frus1961-63v11` d1 exported under *Full text as printed*, and the source notes counted (#1991); a collection with one section heading exported as a web page, and its contents rows' numbers read (#1993); `frus1946v06` d475 exported to Word, and the number after "[13]" read (#2001).
  - For L36: Headnotes switched alone, with the preview on (#1997).
  - For L50 and L54: a collection of documents 470, 473 to 477, 480 and 486 of `frus1946v06`, with a Persons Index and a Sources & Archives block, both read in the preview.
  - For L43, from CR: the two-device run with a drag and Sort by Date on the 1.0 device, every date line read after (J25); and a hand-made collection file with `"includeHeadnote": true` and no id, imported into 1861 and exported as a PDF (J7).
  - For L35, from CR: on a Mac with Apple Intelligence off, a PDF of a collection at *Summary only* whose summaries are all stored (J11).
  - For L53: Source Explorer's *Unprinted Material* rows for d474 and d475 of that volume, against their notes 39 and 44.
  - For L52: one of those documents exported in full as a web page, opened in a browser on a Mac that has the app and on one that does not, and *Dept* clicked.
- **The Word and Pages run** for L34: two `.docx` files a session makes, opened in each.
- **Before L43, three things.**
  - **The two-device run** (the design's §12): two devices on one iCloud account, B kept on 1.0. On A, a build with one of the new properties sets it on a collection B already holds. Let B import; rename the collection on B and read the property on A. Update B; read the property on B before A touches the collection again; then rename on B and read on A.
    - It can be made in CloudKit's Development environment, so that nothing reaches Production before the answer is known. A Debug build is signed for Development and keeps stores of its own (`FRUSStoreConfiguration`, #1531). So A runs a branch with one property, and B runs the commit tagged `1.0-release`, both in the Debug configuration from Xcode.
    - Neither is an AppStore-configuration build run from Xcode. That one talks to Development while it uses the shipped app's own store files, by the same type's note, and the owner's library is in them.
  - **The file run:** a hand-made collection file carrying the new keys, opened in 1.0 (1861) from *Import Collection…*, from Finder and from Files.
  - **The desk check** (decision 161): the app's Chicago and Turabian against the two manuals, for a note, a list's row, a bibliography's entry and a volume's entry.
- **Words that are the owner's,** each proposed by its row: the Note on the Text's sentences (L58), the sign for an omission (L46), the line of coverage (L50), and the three new blocks' titles (L51 to L53).
- **R10's heavy jobs:** the Mac, the corpus clone, and the Air for the harvest. L28's ran on 2026-11-26 and needed no `GITHUB_TOKEN`: the manifest's run makes one GitHub API call, the listing, which needs none (`New-Volume-Release-Plan.md` step 2).
- **The shard push,** before the release candidate ships; a corrected volume's at R11.
- **The CloudKit promotion** (R11): each new field and a saved template exercised on a Development build, then the deploy to Production. `check_cloudkit_schema.py` needs a CloudKit management token saved on the Mac.
- **The archives, the uploads and the tags:** the early build and the release candidate, numbered by the owner above 1861 and each above the last.
- **The device passes,** R9 and R12.
- **App Store Connect, the version's page.** An update's page asks for *What's New in This Version*, which 1.0 did not have; the draft goes in `app-store-connect/paste/` with R11. The description's volume count, if it states one. A screenshot only where T3 retook its screen. The privacy label and the age rating stand, and the review notes are read against what 1.1 adds. A manual release, as for 1.0.
- **The website, after approval:** `build_site.py`'s ten figures recounted from the release's bundle, and Home and the tour pasted again, as on release day.

---

## 3. After the update

- **What the owner did not take from the Collections design** on 2026-11-25. Each stays in the design as a candidate, and none is planned:
  - from its §8.1: the collection's own numbers (3), where notes go (4), a date alone in contents rows (5), and several formats in one export (8);
  - from its §8.2: the Subject Index (A5), Marked passages (A6), Abstracts (A7), the Persons Index with life dates and posts (A9), and the files read, in the Note on the Text (A13);
  - its lane 5, the two steps for one export (decision 156).
- **#1723, A7: App Intents and Siri,** with A7b's Spotlight association; the owner's device check with Spike Reader decides A7b's place (`App-Intents-Siri-Assessment-2026-10-18.md` §4 and §5).
- **Whatever the freeze left** (§1, *When the Office publishes*).
- **Carried from the 2026-10-21 plan's §3:** six cross-volume references by id to a section's row, missing from the bundled edge index (A18b); the two Archival Neighbors readers disagreeing on a class key no note carries (A19); a volume whose indexing is cut short marked nowhere until the next launch (A14); the Archives Visit labelling lot targets by their first document (A15); Search's cost (`Issue-1648-Stopping-A-Replaced-Search-2026-10-15.md` §6).
- **The review's findings no row takes** (§5, *Found by the review*), each filed on the owner's word.
- **Accessibility Nutrition Labels.** Voluntary still, and to be required for new submissions later (`App-Store-Connect-Entry.md`, *Not required now*). Answering one means walking every common task with that feature on.

---

## 4. Waiting on the owner

**The plan's questions are answered** (decisions 147 to 183), and nothing blocks Waves 1 to 3. What is still the owner's, in the order it is wanted:

- **Before Wave 4:** CR's findings, answered at C2; the Word and Pages run; and the three runs in 1.0 for L34 (§2).
- **Before L43:** the two-device run, the file run and the desk check (§2).
- **With its row,** where the row proposes and the owner chooses:
  - L38: what the Mac's title bar holds when its room is short (F2).
  - L41: the design of #1923's resume.
  - L43: the Note on the Text's sentences.
  - L46: the sign for an omission, and the four things its brief says the design leaves open.
  - L47: what a saved template holds.
  - L48: where the page's choices are kept, on the collection or on the device.
  - L49: the short form's rule, and where it prints.
  - L50: the line of coverage's wording.
  - L51 to L53: each new block's title.
- **For the release:** the build numbers (decision 150); E's date, as soon as the Office has one; the CloudKit promotion (R11); and *What's New in This Version*.
- **At C2, if the owner wants it:** the pace against decisions 147 and 148 (§1's calendar).

**Carried:**
- **For #1767**, closed: whether to file the three reports drafted in `Person-Authority-Upstream-Reports-2026-11-01.md` with `HistoryAtState/people`.
- **The asterisk rows** (`Editors-Annotations-Followups-2026-11-08.md`, Lane 0b): whether a row of asterisks counts as a third form of marked omission. `FRUS-History-Feature-Assessment-2026-11-09.md` §2.4 proposes a census. L46's sign for an omission is read against the same record.
- **For A7** (#1723): the device check with Spike Reader.
- **App Previews** for a later update (decision 89). Two beats show templates that are gone since L25, and L34 and L44 change what an export prints and how a template is chosen, so a preview cut from recordings A and T needs both recorded again.
- **The manual review**, after 1.0 (decision 94): `Manual-Revisions-Pending.md` and `Manual-Update-Build-49-Owner-Review.md` are its inputs.
- **Whether Home and the tour become copies of record** on the website. Both have held their launch versions since 2026-11-21.

---

## 5. Backlog, parked, deferred and closed

The 2026-11-15 plan's §5, with what this plan's rows take left out: the subseries' order (T1, in L26); #1835 (L27); a Collections row's hit shape (R4, in L35); the Research window's ids, filed as #1946 (L38); and the Contents links, F7 (L39). Where a line below names a row, the item is a candidate of that row's and nothing more.

### Found by the third review of the Collections design, 2026-11-26, unfiled

None was seen in a running app. The review's §6 lists seven. These two are outside every row's brief, and each needs the owner's word to file:
- **A *Summaries* export fails on a device without Apple Intelligence, even with every summary stored.** The guard runs before the stored summaries are read (`CollectionContentResolver.swift:776-778`). Filed since, as #2018, and L35 takes it (decision 198).
- **In an exported web page, every person's name is a link no browser can follow,** and an untagged name is a link to `#` (`FRUSRenderNodeHTMLSerializer.swift:894-897`). L52 takes it, by decision 202: a name links like a term.

### Found by the review of 2026-11-15, unfiled

The 35 of the review's S3 findings that no 1.0 row took. Each has its evidence and size in `UI-UX-Adversarial-Review-2026-11-15.md` §4, and the 7 that need a running app to settle have their checks in its §6. Each is filed as an issue on the owner's word, or declined. Two sit in the Collections editor that L44 trims, and are candidates there: IPA-3's whole-collection Sort and MAC-11's Done. In brief:
- **iPhone:**
  - IPH-6, the sync banner at accessibility sizes on a small iPhone;
  - IPH-7, the Lock Screen Live Activity's count;
  - IPH-8, the end-of-queue card;
  - IPH-9, onboarding's dock at accessibility sizes;
  - IPH-10, the banner's word cloud under Increase Contrast.
- **Search and analysis:**
  - IPS-2, captions in tertiary grey and orange (with IPA-8);
  - IPS-4, the match percentages, unexplained in the app;
  - IPS-5, Clusters' and the map's three names for one group;
  - IPS-6, Corpus Analytics' explanations in `.help` only;
  - IPS-7, Archival Analytics' "list below".
- **Reading and organising:**
  - IPA-1, the downloaded-only filter's glyph (its empty state goes with L18);
  - IPA-3's whole-collection Sort;
  - IPA-5, next and previous with the rail open;
  - IPA-7, the rail header's and tag chips' small targets;
  - IPA-9, two empty states;
  - IPA-10, ⌥⌘F on iPad;
  - IPA-11, three stacked sheets;
  - IPA-12, the sidebar's project rows;
  - IPA-13, "Adds all 0 generated summaries".
- **Mac:**
  - MAC-4, the reader's 136% ceiling and no ⌘+/⌘− (with the accessibility sweep's reader item);
  - MAC-7, the reader's verbs, Back and Forward, and Help ▸ User Manual in the menu bar, and ⇧⌘P and ⇧⌘A;
  - MAC-8, Escape on the person and gloss sheets;
  - MAC-9, the toggles' state for VoiceOver;
  - MAC-10, Settings' last pane;
  - MAC-11, the inspector's Done;
  - MAC-13, the main window over Search;
  - MAC-14, two alerts on one error.
- **Cross-platform:**
  - ASR-5, `drawsBackground`;
  - A11Y-4's silent highlight;
  - A11Y-6, the rail's accordion state;
  - A11Y-7, the Research tab's rows by keyboard;
  - A11Y-8, removing a highlight without pointing;
  - HCD-7, the iCloud wording;
  - HCD-9, the Research Guide at every launch during a queue (#757's choice);
  - HCD-10, a long summary's spinner.

### Found by L31, unfiled

- **A country-series roll with one date, or two inverted, matches far more of a lookup than its span.** Of the bundled index's 6,654 country-series rolls, 295 carry a plausible end date alone and 111 a start alone, and `CountryRoll.matches` filters them by that one bound, so each matches every day before its end or after its start; 155 carry two inverted dates, which its guard matches on every day rather than hide (`FRUSCoreKit/SourceExplorer/CentralFilesIndex.swift`). So a dated lookup lists them wherever their place matches: a lookup of July 1865 among Mexico's diplomatic despatches lists 50 rolls, 44 of them end-only, and every lookup of Austria's lists the two inverted ones. Measured by L31's harness over a full v76 index; nothing changed, since it is the index's reading of NARA's titles and the guard is deliberate. A fix would be the generator's (`CountrySeriesIndexBuilder` reads the bounds from NARA's titles) and a regenerated `central-files-index.json`. Filed on the owner's word.
- **A dateline's misprinted year now reaches the export, as it always reached Source Explorer.** Decision 175 has the export read the dateline first, as the views do. Of the 141 records whose export year moved at L31, 32 now carry a year outside their volume's where the TEI's date was inside it: mostly the dateline's own misprints (`frus1949v09` d28, *Lisbon, May 19, 1919*; `frus1944v07` d503, *October 18, 1964*; `frus1952-54v07p2` d845, *February 5, 1976*), with a few documents FRUS prints out of their year (`frus1914` d602, of 1907). One crosses the Numerical File's window: `frus1910` d91 cites case 21614 and its dateline prints 1914, so neither the views nor now the export list its roll. The views read each of these years before L31. A rule that preferred the TEI's own date where the dateline's year falls outside its volume's would be a new decision, for both. Filed on the owner's word.

### Found by L57, unfiled

- **On the Mac's Search and in the word cloud, a day whose midnight a change of clocks skips is read as no date.** Each reads a `yyyy-MM-dd` day with a strict `DateFormatter` in the device's zone, which returns `nil` for such a day: the Mac's Search window then keeps its filter's previous date (`MacSearchViewModel.mirrorParameters(into:)`, `MacSearchViewModel.swift:1521`, `:1524`), and the word cloud's date-range pickers fall back to `.distantPast` and now (`WordCloudScope.day(fromISO:)`, `WordCloudView.swift:2561-2571`). Measured on iOS 27.0's Foundation by L57, from 1861 to 2000: 27 such days in São Paulo, 42 in Havana, 33 in Beirut, 43 in Santiago, 14 each in Tehran and Cairo, 4 in Tokyo (1948 to 1951) and none in New York. iPhone and iPad Search read them since L57 (`SearchViewModel.filterDate(ofDay:in:)`, a day's noon taken back to its start). Read from the code and Foundation, not seen in the app; L57 left the Mac's file unchanged, as its brief asked. Filed since, as #2033, on the owner's word (decision 210); no row takes it yet.

### P2 — later

- **Generators:** provenance flows count no page reference (`RefDestination.citedDocument` is nil for a page).
- **Section vectors**, at the next vectors generation (decision 61).
- **A second question for the Agentic Analysis Guide's model table** (§3a; decision 115), under a budget line the owner sets and decision 115's guard.
- **Found by #1764's session, unfiled:** a graph of 1,259 nodes cannot be read on an iPad canvas under any layout tried, so clustering or a cap on what three hops draws is a design question; what a label carries is the owner's call; the reference-list toggle opened nothing on two taps on the iPad (L42's candidate).
- **Found by the summarization sessions, unfiled:** a chunked summary's synthesis keeps too little of the document (#1820); a model that declines may write its refusal as the answer (#1820); no device and no iOS 26 system measured for the 4,096-token window (#1825, #1827); the app not run with #1827's retry.
- **Found in R2b's walk, unfiled:** where a collection names no summary prompt, an entry's AI summary row in the inspector, and the headnote it would draft, show the first summary the store returns, while the reader's rail shows the newest (`CollectionEntryInspector` and the content resolver's fallback; L34's candidate).
- **Found in T2, unfiled:** under iOS 27.0 the simulator's render server (`backboardd`) aborts as the Related Documents window opens from the reader, #1620's Metal stack, twice in a row, and its accessibility stays down until a reboot (27.2 and 26.5 opened it cleanly; not tried on a device); and after a search in Archives' Collections lens on the iPad the tab sidebar's toggle drew no icon until a relaunch (seen once). Its other two are rows now: #1946 (L38) and F7 (L39).
- **Found in W2, unfiled (2026-11-21):** a pasted citation's result names its document by id alone (*d23* over *frus1955-57v14*, `CitationLookupView.swift:772`), though the index holds its head (L30's candidate); and the method appendix's CSV opens untidily in a spreadsheet, since its `#` lines hold unquoted commas, which Quick Look splits across columns, with the header at row 18 (`QueryMethodAppendix.preambleLines`). Both are in 1.0 (1861); neither misstates a result.
- **Found while L56 was read (2026-11-25),** each read from the code and not seen in the app. Two are filed: *Search in this range* hands Search its range a day early east of UTC (#2012, decision 186; in L56), and on iPhone and iPad Search converts its date filter's days in GMT under pickers in the device's zone (#2013, decision 187; in L57). #2012's fix also has both of Chronology's hand-offs name the range the screen loaded, where they read the pickers (`ChronologyView.swift:209-212`, `:1212-1215`). Unfiled:
  - Chronology's headline counts the documents dated inside the range while the list is under its cap, and every placed document that overlaps the range once it is over (`ChronologyViewModel.swift:200` and `:221`; L56's candidate);
  - a word cloud for a range of dates reads at most the first 5,000 documents in date order, and its resolver has no field that says a range was cut (`WordCloudScopeResolver.swift:36-45` and `:172-187`);
  - `applyProjectDefaults(_:)` sets Search's two filter dates from a project's, which onboarding fills from the manifest's range (`SearchViewModel.swift:1007-1014`, `OnboardingViewModel.swift:98-100`). Which zone those are built in was not followed (L57's candidate).
- **Smaller app items:** `ProjectLeadsService` ranks with no year; `datesByDocumentKey(_:)` scans every `document_dates` row; the archival chip is cut on the iPhone 17; Sync Diagnostics' Clear Log draws its trash icon in the accent colour; a phrase can match across a document's heading and its form marker; a question's keyword snippets cost more since #1760 (the UTF-8 scan unbuilt); a number typed with a mark (`1945.`) searches nothing and nothing says so; a hyphenated word or an `=` word never anchors a snippet; a page link into a volume on the device whose page names no document does nothing (608 of 48,577; L39's candidate); under iOS 26.5 in Stage Manager a popped-out document's rail draws black until the window moves.
- **The 2026-09-27 audit, unfiled:** Facets is disabled in Meaning mode on iPhone and iPad, where the Mac offers it; the reach scan and the leads count second-edition reprints; Archives Visit derivations go stale when a volume updates (R10 says what it sees).
- **Test infrastructure:** `RichTextRestingCapTests` on an iPad host; two UI suites need the Research rail open, which a simulator can hold closed (A12); the iOS 26.5 runtime has no English lemmatiser.
- **#1608:** how often an iOS 27 device launches without the lemmatiser.
- **Hygiene:** `FilterChip` and `CrossProjectNoteIndicator`, the two views nothing constructs; 14 Swift files outside every target with no license header; nine Swift files citing #1210, #1211 or #1257 where the work merged as #1250, #1251 and #1256; the HYG and READ leftovers (`Completed/Plan-Of-Record-2026-10-14.md` §6f).
- **Marketing**, from the Visual Marketing Plan: step 5 (the publication-lag plate), step 13 (Plate B) and step 16 (after launch).
- **Accessibility, a sweep of its own:** `AXChartDescriptor` for four chart families; Differentiate Without Color on the map; about 37 text sites with a fixed size; a reader that follows the system text size; the iPad rail toggle's `.isSelected` trait; at the largest text size on an iPhone, Collection settings' row and the Local Only banner's button. The review's accessibility findings (above) join it.

### Parked — designed or proposed, not scheduled

- Dateline places, blocked on the owner's toponym curation.
- Links from the map to Search and Related.
- A heat-matrix cell drill-down.
- A Search command menu and shortcuts.
- Standalone token editors.
- A subseries pole picker.
- A region-share chart.
- An iPhone rail peek strip.
- An immersive Read mode.
- C-1 of the agentic loop, gated on C-2's measurement.
- The OS 27 design's C3, project-lead centroid retrieval.

### Deferred, or waiting on someone else

- **#234**, early-era people: deferred indefinitely (decision 92).
- **#1696**: waits for the Office's subject export to reach Document 946 (decision 71). R10's Phase E reads the export it takes, if it takes one.
- **For the corpus to fix:** `frus1945Malta/d273`'s year, 1945 by `@when` where its dateline says 1944.
- **For HistoryAtState/people to fix:** the registry's own merges (Stevenson, Wilson, Fish), its duplicate records (Rowan, Regan, Tran Buu Kiem) and Sir Oliver Wright's two missing anchors; the three reports are drafted and not filed (§4).
- **New volumes after this one**, whenever the Office publishes, by `New-Volume-Release-Plan.md` as L28 and R10 leave it (D-5: each release as it comes).

### Closed or declined

- **Closed under the 2026-11-15 plan:** #1892, #1893, #1905, #1907 to #1915, #1917 to #1921 and #1927 to #1929, by its rows L15 to L24 and N1, and by #1967 to #1969 after the upload. R6a fixed findings that were not filed (F3 to F6 and F8 to F10, #1956).
- **Closed under the 2026-10-21 plan:** #1690, #1691, #1620, #1767, and every issue its rows fixed (#1756 to #1766, #1796 to #1799, #1823 and #1856). L10 to L14 fixed findings that were not filed (#1873 and #1879 to #1883 are their pull requests).
- **Left as it is:** the method appendix's plain-text line, the record of what was typed (decision 86).
- **Declined:** W12's parallel editions, W14, the MCP server and `CSUserQuery`; the cross-platform review's unfiled leftovers (decision 93), which the 2026-11-15 review did not re-raise.

---

## 6. The documents, as this change leaves them

- **New:** this plan.
- **Moved to `Completed/`:** `Plan-Of-Record-2026-11-15.md`, marked SUPERSEDED in its head: the record of decisions 126 to 144; of L15 to L25, N1 and C1; of R5, R6, R6a, R6b, R7 and R3; of sittings T2, W1 and W2; and of index version 75.
  - The live documents that pointed at it now point there, or at this plan where they meant the live one: `Completed/README.md`, `Visual-Marketing-Plan.md`, `website-drafts/README.md`, `Cross-Platform-UI-Adversarial-Review/STATUS.md`, `UI-UX-Adversarial-Review-2026-11-15.md`, `R6-Device-Pass-2026-11-18.md`, `iPhone-Duo-Assessment-2026-11-19.md` and `Collections-Design-Adversarial-Review-2026-11-25.md`.
  - Its head is one paragraph, where the two plans archived before it have two. No line below it moved, so the lines that the Collections design's first review and its reviewers' reports cite by number are where they were.
  - In `Completed/`, the 2026-10-21 plan's status line and its review's dated note named it at `../`, and now name it in their own folder. `Completed/README.md` has the move's entry.
  - Dated records are left as written: `DEVELOPMENT-PLAN.md`'s entries, the archived plans' bodies, and the reviewers' and skeptics' reports under `collections-design-review/` and `collections-design-review-2/`.
- **Kept live:**
  - `Collections-Customization-Design-2026-11-25.md` and its three reviews, the third being CR's (`Collections-Design-Third-Review-2026-11-26.md`, with `collections-design-review-3/`), until its lanes are built. The owner's answers to its twelve questions are decisions 153 to 174 of this plan. CR's first step brings the design's own text to them, and it stays PROPOSED until C2.
  - `UI-UX-Adversarial-Review-2026-11-15.md`, until its backlog is filed or declined.
  - `R6-Device-Pass-2026-11-18.md` and `iPhone-Duo-Assessment-2026-11-19.md`, until F1, F2, F7, F11 and D1 have landed.
  - `New-Volume-Release-Plan.md`, which L28 refreshes and R10 runs.
  - As the 2026-11-15 plan's §6 left them: the runbooks; the original specification; the session log; the Visual Marketing Plan, the launch kit, the listing draft, `marketing-drafts/`, `app-store-connect/` and `website-drafts/`, which the update's entry and the website's figures still use; the two manual-review documents, until the review; the A7 design, until its work runs; the person-authority identifier assessment and the upstream-report drafts; #234's documents (decision 92); `Editors-Annotations-Followups-2026-11-08.md`; the generator output folders.
