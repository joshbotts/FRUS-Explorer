# Agentic Analysis Guide — revisions from the commercial-diplomacy run, and a skill feasibility assessment

**Status:** WRITTEN 2026-09-04 from a six-miner / six-checker review of the 2026-09-01/02
commercial-diplomacy run. Nothing in `Docs/Agentic-Analysis-Guide.md` has been changed yet; this
document is the change list, with every proposed line pasteable and every claim carrying the run
file it rests on. Guide line numbers are `grep -n` over v1.10 (1,869 lines) on 2026-09-04; apply
insertions bottom-up or renumber as you go.

**What the run was.** Three rounds over the full 552-volume index, following the guide at v1.10
with its §12 house-rules block pasted into every agent: a scoping round (eight modalities, two
refuters each, six threads, two refuters each, memo, critic, scorer), a deepening round (an audit
of round 1, nine threads, eighteen refuters), and a reading round (six reading threads on fixed
lists, two correction threads, fourteen refuters, an argued STOP). By the orchestrator's accounting
— figures that appear in no file under the run and are labelled orchestrator-reported wherever they
recur below — 207 agent sessions over roughly 19 hours, 2.94 B tokens, $2,810.88 at first-party API
rates, 95.9% of input served from cache, half of all output tokens written by the refuters, and 45 of
round 1's 141 sessions dead without output ($257). The files corroborate the shape: 108 agent
scratch directories, 53 `queries.log` files, 60 refuter verdicts (28 + 18 + 14 `refute-*/verdict.md`; an earlier draft of this line said 46), mtimes 2026-09-01 23:31 →
2026-09-02 22:57. Measured outcomes, read back from the score files: round 1 **22 obeyed of 23
applicable** (`rounds/round1/score.md:9`); round 2 **23 of 26**, violated R1, P1, P2
(`rounds/round2/score.md:10`); round 3 **29 of 29** (`rounds/round3/score.md:13`). Round 3 retrieved
**361** documents, **316** of them whole, quoted **171** documents in **183** passages
(`rounds/round3/memo.md:2819`); the critic's independent extractor matched **182 of 220** quotations
verbatim on an alphanumeric fold and found **zero fabrications and zero mis-citations**
(`rounds/round3/critic.md:68,92`); it returned **STOP** (`critic.md:278`). The three
`.fruscollection` files carry 148 → 300 → 400 documents with nothing dropped at either handover
(`commercial-diplomacy-round2.collection-manifest.md:372`, `…round3.collection-manifest.md:81`).

**Method.** Six miners each read one slice of the run — operations (M1), the 28 round-1 verdicts
(M2), the 18 round-2 verdicts and critic (M3), round 3's reading and archival threads (M4), the
bundled artifact surfaces (M5), and the skill question (M6) — and wrote recommendations that quote
the guide at the line they would change and cite a run file for the failure. Six adversarial
checkers then opened every cited line, grepped the guide for each "the guide does not say this"
claim, re-ran the database figures on the copy, and returned keep / amend / drop with the reason.
Headline across the six: **0 dropped whole, 10 kept as written, 46 amended**; every miner's "the
guide already says it" section was found accurate. Where two checkers disagree with each other, or
where I disagree with one, the deciding quote is given in place. Everything cut or reworded is
listed in the Dropped section at the end, with the checker's reason, because a reader auditing this
will want to know what was considered. Miner reports and checker verdicts are at
`/Users/jbotts/frus-analysis/commercial-diplomacy/agents-review/{M1-operations,…,check-M6-skill-feasibility}/`.

Abbreviations: `RUN` = `/Users/jbotts/frus-analysis/commercial-diplomacy`; `GUIDE` =
`Docs/Agentic-Analysis-Guide.md`; `S1`/`S2`/`S3` = the round-1/2/3 workflow scripts named in the
task (`S1` has `.pre-opus` and `.stalled` predecessors); `M1`…`M6` and `check-M1`…`check-M6` = the
reports under `RUN/agents-review/`.

**One correction to the brief this document was commissioned under.** The task attributes the failing
read-only invocation to "the guide's own §2/§3 invocation `sqlite3 "file:...?mode=ro" -uri`". The
guide prints no `-uri` anywhere (`grep -c -- '-uri' GUIDE` → 0); §2:152 says only "open it read-only
(`file:frus-copy.db?mode=ro`)", and typed into the shell as written that form **works** on this
Mac's sqlite3 3.51.0 — re-run 2026-09-04: `sqlite3 "file:$DB?mode=ro" "… BEGIN; CREATE TABLE
zz_probe(x); ROLLBACK;"` returns the count and refuses the write with `attempt to write a readonly
database (8)`. The flag was added by the round-1 script (`S1:138` `Open it READ-ONLY: sqlite3
"file:${DB}?mode=ro" -uri`) and, independently, eight times each by the C-0 and C-2 harnesses
(check-M6 §0). All four checkers that looked (check-M1 §0, check-M2 preamble, check-M4 tail,
check-M6 §0) found the same. The guide's real gap is that it prints no shell form at all, which is
what invited the invention. The memory note `env_workflow_agent_failure_modes.md` repeats the
brief's wrong attribution ("the read-only invocation printed in … §2 fails as written") and should be
corrected — see the repo-issue stubs at the end of Part 1.

---

## Part 1 — Revisions to `Docs/Agentic-Analysis-Guide.md`

Grouped by guide section in the guide's order. Each entry gives the section and lines, what the
guide says now, the change as pasteable text (the checker-amended form wherever the checker amended
it), the evidence, and what it would have prevented. Priority is **must** / **should** / **could**.
Where a change belongs in the §12 house-rules block as well as the body, the block line is given
under the entry and collected again in the §12 entry, because the block is a measured instrument
(C-2: 99% obedience with no decay over 2× session length) and every line added to it is untested —
check-M4's standing caution, "Add one line each, or none", governs.

### §2 and §3 — the shell read-only form (must; M1-R1, M2-R14, M6-G1, folded on the checkers' instruction)

**Lines.** §2:152; §3:169–170.

**Guide now.** §2:152 "Work on the copy, and open it read-only (`file:frus-copy.db?mode=ro`)." §3:169–170
"**Make the connection read-only.** Use a read-only URI (`?mode=ro`) or a client configured without
write tools." The only executable forms are Python `uri=True` (lines 123, 428).

**Change.** After §2:154 (the last line of the paragraph that begins at 152):

> From the shell, either form opens the copy read-only (verified on Apple's sqlite3 3.51.0):
> ```bash
> sqlite3 -readonly "$HOME/frus-analysis/frus-copy.db" "SELECT COUNT(*) FROM document_cache;"
> sqlite3 "file:$HOME/frus-analysis/frus-copy.db?mode=ro" "SELECT COUNT(*) FROM document_cache;"
> ```
> The shell accepts a `file:` URI as the database name with no flag; there is no `-uri` option
> (`sqlite3: Error: unknown option: -uri`), and an agent told only "use a read-only URI" will invent
> one. Prove the connection is read-only once, in a form that changes nothing if you are wrong:
> `sqlite3 -readonly frus-copy.db "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` must fail with "attempt to
> write a readonly database". (`BEGIN IMMEDIATE` alone does not fail on a read-only connection and
> proves nothing.) And whatever invocation you print into an agent's prompt, run it yourself first on
> the machine the agents will use, and make the first agent's first call that exact command against
> a known answer — a wrong flag shipped to 141 agents in one run would have been caught by one
> ten-second canary.

At §3:171 (the last line of the paragraph that begins at 169) append: "From a shell that means `sqlite3 -readonly` or a `file:…?mode=ro` name with no
flag ([§2](#copy-it-properly)); the URI form with `uri=True` is for a library connection."

**Evidence.** `S1:138`; `S1:606–610` ("The read-only sqlite3 invocation printed above is WRONG for
this system's sqlite3 (3.51): it does NOT accept `-uri`"); `agents/A4-sql/queries.log:2` "`sqlite3
"file:…/frus-copy.db?mode=ro" -uri "..." -> sqlite3 3.51.0: unknown option: -uri`";
`agents/refute-A6-semantic-history/queries.log:100`; `agents/refute-T1-method/queries.log:2` "the
-uri form in the brief fails on sqlite3 3.51"; `agents/thread-T6/queries.log:6198`;
`agents3/read-D4-ecefp/queries.log:2` "(sqlite3 3.51, no -uri)". Census (check-M1 §0): 10 logs
carry `-uri`, 21 `-readonly`, 21 `uri=True`. The non-destructive proof and the canary are
check-M1's amendments: `BEGIN IMMEDIATE` "prints no error on a `mode=ro` or `-readonly` connection —
it is NOT a read-only proof", and the memory note records the canary finding the flag "in ten seconds
after two long runs had silently worked around it".

**Would have prevented.** The first call of at least ten round-1 agents, the TOOLING correction all
three scripts had to carry, and the mid-session switch of T3 and T6 to the Python route. Not any
finding — check-M6 C14(c): "the cost was one failed command, not hours".

### §3 — tool-call discipline beside the scale note (must; M1-R2 with M4-R3 and M6-G2 folded)

**Lines.** §3:179–182.

**Guide now.** "A note on scale: a full 552-volume index runs to several gigabytes, with
`document_cache` alone at roughly 1.8 GB of text. Aggregate in SQL and return summaries. An agent
that pulls `body_text` for 20,000 rows into its context will exhaust the window before it reaches an
answer." — the context window only; nothing on the wall-clock of a single call.

**Change.** After line 182, two paragraphs, kept **beside** the §12 block and not inside it (both
S2 and S3 appended their TOOLING notes after the block, which check-M1 confirms is the right shape:
"the block is the C-2 instrument").

> **Keep every tool call short, and keep the big files out of context.** Agent harnesses kill a
> call that produces no output for longer than their per-call timeout (three minutes, in the runs
> this guide draws on), and a killed call loses everything not yet on disk — one thread lost an hour
> and three-quarters of scans that way, and one 300-second query loop lost its results to Python's
> stdout buffer after it had computed them. So: never scan all 552 volumes or all of `body_text` in
> one call; slice by volume (ten to twenty per call), write each slice's result to a file in the
> agent's scratch directory as it completes (`print(…, flush=True)` or `python3 -u`), and merge.
> Never `SELECT body_text` without a `(volume_id, document_id)` pair or a tight filter and a `LIMIT`.
> And never `cat` a memo, a thread report or a large JSON artifact into context: one round's memo ran
> to 279 KB; read it with `grep -n` and `sed -n`. Prefer the index to a corpus scan wherever the
> scoping pass has already settled the scan.
>
> When reading is the task the pattern inverts: select `body_text` for named pairs only, a handful
> per call — `SELECT volume_id, document_id, length(body_text), header, source_note, body_text FROM
> document_cache WHERE (volume_id, document_id) IN (VALUES (…),(…))` — and write each batch to disk
> with notes before the next. Select `length(body_text)` beside the text so the result set carries
> its own check. Never `substr()` a document you intend to call read: "read in full" means the
> captured length equals `length(body_text)`, and the whole/partial split is published. One pass
> truncated at 2,200–3,200 characters and reported 77 documents "read in full" where 32 were whole; a
> 156,074-character document was captured at 1.5%, and one inference in its chronology sat past the
> window. Whole-corpus scans in one call are the ones a session limit kills — chunk and checkpoint.

**Evidence.** `S1:612–620` ("KEEP EVERY SINGLE TOOL CALL SHORT. A previous run of this task was killed
by a watchdog after three minutes without output"); `S2:136–142`; `S3:81–87`;
`agents/thread-T3/queries.log:1–9` ("the scratch artifacts stamped 06:40-08:27 … come from an EARLIER
attempt at this task that was killed by the watchdog" — 1 h 47 min discarded);
`agents/refute-A3-tei-policy-numbers/queries.log:44` ("not finished after ~40 min; killed");
`agents/A8-pointed-at/queries.log:45` ("TIMED OUT at 600 s"); `agents/thread-T6/queries.log:6230`
("4 chunks of 16 volumes"); `agents/refute-A1-headings-numbers/queries.log:349` ("output lost to
buffering" — check-M1's fold; 75 agent files converged on `flush=True` / `python3 -u`);
`agents3/read-D5-geography/queries.log:129–133` ("substr(d.body_text,1,N) … N = 2200..3200 per
batch"); `agents3/refute-D5-geography-quotes/verdict.md:112–146` ("≥ 99% (genuinely whole) 32 of 77 |
< 90% 41 | < 50% 26"; "'Estrada Palma' first occurs at offset 2,442, past the 2,300-character
window"); `agents3/read-D2-trade-fairs/reading-notes.md:595` ("PARTIALLY READ … body NOT retrieved
whole, 12"). `run_in_background` appears in 0 of 53 logs (check-M1 §0), which is why chunking leads.

**Would have prevented.** The killed T3 first attempt, the 40-minute rawprobe and the 600 s
`tei_rg_recount`; the need for a TOOLING appendix in every script (rounds 2 and 3 carried it and
their 60 logs record no kill); D5's 45 partial reads. The "three minutes" is one harness's watchdog
and is stated as the example, per check-M1.

### §4.2 — `document_cache` is not exactly one row per document (could; checker-surfaced, check-M2 missed 6)

**Lines.** §4.2:206.

**Guide now.** "**`document_cache`** — one row per document, keyed `(volume_id, document_id)`."

**Change.** Append a note: "About 1,350 rows carry container ids rather than `dN` (`ch1`,
`ch10subch1` — chapter and subchapter divs, 155 volumes), and a `<back>` appendix div is stored as a
document with `is_editorial_note = 0` (`frus1944v01/appendix`). Reconcile any TEI document count
against this table with those two classes named."

**Evidence.** `agents/refute-A2-tei-institutions-numbers/verdict.md:25,66` "the 1,348 extra ids are ALL
chapter/subchapter ids (`ch1`, `ch10subch1` …, 155 volumes)"; `agents/refute-T2-method/verdict.md:65`
the appendix row "stored this row with `is_editorial_note=0`"; `rounds/round1/score.md` M9 confirms.

**Would have prevented.** T2's "first time the series prints" (the 1944 appendix was inside the
index under a non-apparatus flag and outside the `<body>`-only heading pass).

### §4.3 — how an editorial-note div is dated (must; M2-R5's second half, placed here on check-M2's instruction)

**Lines.** §4.3:241–246, under the `document_dates` table.

**Guide now.** "`date_iso` | Start of the document's date range" / "`date_iso_max` | End of the
range" / "Dates come from the editorial `frus:doc-dateTime-min`/`-max` attributes". Nothing on how a
narrative note is dated.

**Change.** Add under the table: "An editorial-note div (`is_editorial_note = 1`) is dated to the
**opening of the span it narrates**: a 1951 note on the Torquay Round carries `date_iso` 1948-07-02.
Exclude editorial notes from any first-appearance table, or read `date_iso_max` beside `date_iso`."

**Evidence.** `agents/refute-A3-tei-policy-numbers/verdict.md:11` "**11 hits are the Torquay Round** in
editorial notes whose `doc-dateTime-min` is the opening of their span: frus1951v01/d461 (×8,
1948-07-02 → 1952-03-20 …)" — labelled "the Devon town" by the report it refuted. check-M2: "a
*schema* fact a SQL user hits in `document_dates` and should sit in §4.3's table … or nobody querying
dates will see it."

**Would have prevented.** A3's "15 pre-1949 hits are the Devon town" (28 of 35 were the GATT rounds).

### §4.4 — `decimal_class`: the 1950 renumbering, lettered country keys, and the predicate shape (must; M4-R10 and M5-R2 folded, check-M5 missed 3 added)

**Lines.** §4.4:296.

**Guide now.** "| `decimal_class` | Central-file class key (`751.00`, `POL 27 ARAB-ISR`),
canonicalized. |" — `grep 1950` finds no renumbering.

**Change.** Append to the row:

> The schedule was **renumbered in 1950** (the artifact's own `provenance` string says so): class 4
> is *Claims* before and *U.S. trade* after; class 6 is *Commerce* before and bilateral *political
> relations* after (`611.41: U.S.-U.K. relations` in the editors' own gloss; `611.31` is U.S.–Venezuela
> commerce after 1950); country numbers move too. A prefix is a false friend across 1950-01-01 —
> bound every `decimal_class` family by `document_dates.date_iso` at that date, publish the two halves
> as two sets, and print the predicate beside the count. Measured on the working scope: `411.*` = 327
> documents in 46 volumes after, 259 in 29 before (44% of the undated union are claims cases).
> Country numbers carry a **letter** for dependencies and derived states (`41D` Ireland, `11B`
> Philippines) and the corpus writes punctuation variants (`611.37.31`, `611.60c.31`): never let the
> schedule's shape decide the predicate — `GLOB '611.[0-9][0-9]31'` looks like the careful choice and
> silently drops Ireland (20 documents) and the Philippines (12), while `LIKE '611.%31'` admits the
> renumbered post-1950 class. Use the date. And `document_sources` stores the letter in upper case
> (`60F`) where `decimal-class-labels.json` keys it lower (`60f`); one thread's "all bare" claim was a
> case-sensitive lookup.

**Evidence.** `rounds/round2/threads/R8-archival-deepening.md:27–45` ("the prefix is a **false friend
across the 1950 renumbering**: before 1950, class 4 is *Claims* … `411.*` returns **259 documents in 29
volumes**"); `rounds/round3/threads/C2-number-corrections.md:78–127` ("`611.41D31` is IRELAND … twenty
documents … `611.11B31` is the PHILIPPINES … twelve … Class 6 was renumbered in 1950 … `611.31` (10
documents, 1950-06-30 → 1962-09-21 … every one of them Venezuela)"; :124–128 "**Never let a schedule's
shape decide a predicate** … Use the **date** for a decimal-class family");
`agents3/refute-C2-number-corrections/verdict.md:69–93` (B1: 63 bare / 135 lettered; only `11b`
absent); `rounds/round3/memo.md:2070` (GLOB 3,209 / 103 vs LIKE 3,552 / 117); the phrase "a *different and worse* set" is `C2-number-corrections.md:122–123`, not the memo's,
`:2071–2073`; check-M5 re-ran every figure: "411.* post-1950 327/46, pre-1950 259/29 … All exact";
check-M4 re-ran `611.31` = 10, `611.41D31` = 20, `611.11B31` = 12. The provenance-string fact is
check-M5's: the artifact "says it itself … so the fact was one header read away".

**Would have prevented.** Round 1's `411.00*` = 120/14 (a "substring accident" at 37% of the true
327/46, `R8:67`); memo v2's central key published without its predicate (3,552) and the lossy 3,209
that dropped two countries.

### §4.4 — `external_citations`: the 1910 floor, what `raw_text` is, and the grammar (must; M2-R11 kept, with check-M4 missed 1 and check-M5 missed 1 added)

**Lines.** §4.4:307–311.

**Guide now.** "**`external_citations`** — **many rows per document** … archival material the editors
*cited in a footnote*, largely things FRUS did not print." No column table, no floor, no note on what
`raw_text` holds, no grammar limit.

**Change.** Append to the paragraph:

> Three structural facts, measured on the 2026-08-31 build. **The table begins at 1910-12-06**: it has
> no row on any document dated earlier, so for the 43,156 non-apparatus documents dated 1860–1909
> (13.7% of the corpus) the pointed-at channel is empty by construction, not by finding — a
> nineteenth-century question has one channel, and any ranking built on this table has no
> nineteenth-century volume in it. **`raw_text` is the parsed anchor fragment** (mean 50.8
> characters — `822.154/375`, `Lot 57D284, Box 111`), not the footnote sentence: `LIKE '%Department
> of Commerce%'` over it measures the parser's fragment and returns 0 where the TEI footnotes carry
> the name 254 times; for an institution named in footnotes, parse `<note>` in the TEI. And **the
> table is a grammar, not a transcript**: it captures lot, presidential-library and decimal-class
> anchors only. A Federal Records Center accession, a bare `RG 40`, or a subject-numeric key (`FT 7
> GATT`, `STR 13-1`, `ORG 1 COM–STATE` — 6,753 refused corpus-wide, so every post-1963 pointer of that
> form is invisible here) is not a row: `SUM(raw_text LIKE '%RG 59%')` = 781 while `'%RG 40%'` = 0
> against 13 `RG 40` footnote occurrences in the TEI. A zero in this channel for a record group, an
> accession or a subject-numeric file is a grammar limit, not an absence.

**Block.** §12, ARCHIVAL SCOPE, one line after 992: "- The pointed-at channel (external_citations)
has no row before 1910-12-06, stores the citation fragment, not the sentence, and holds lot, library
and decimal anchors only. Say so before ranking anything on it."

**Evidence.** `agents/refute-A8-pointed-at-history/verdict.md:81` ("**The pointed-at channel is
structurally blind before 1910.** … V019: 43,156 non-apparatus documents are dated 1860s–1900s = 13.7%
of 315,827"), `:31–32` ("raw_text averages **50.8 characters** … `822.154/375`");
`agents/refute-T1-method/verdict.md:202–203` ("`MIN(date_iso)` … is **1910-12-06**; 0 rows on any
document dated before 1910. Independently confirmed"); `rounds/round2/audit-round1.md` row 25;
`agents/refute-A8-pointed-at-numbers/verdict.md:62` (254 footnote hits); `rounds/round3/memo.md:2017–2027`
("`external_citations` captures **lot, presidential-library and decimal-class anchors only** … The same
grammar refuses **subject-numeric keys** (6,753 corpus-wide)"); check-M4 re-ran `%RG 59%` = 781,
`%RG 40%` = 0; check-M5 verified `external-citation-index.json` `coverage.decimalSubjectNumericRefused
= 6753`.

**Would have prevented.** A8's on-topic ranking with no nineteenth-century volume and its Surface-A
zeros table; three passes (T1, T6, the memo) each re-measuring the floor.

### §4.4 — `volume_sources`: its real columns, and that it is the editors' gloss table (must; M5-R2(b), with check-M5 missed 5)

**Lines.** §4.4:317–320.

**Guide now.** "**`volume_sources`** — the volume's own front-matter Sources section, as an ordered
outline (`kind`, `depth`, `is_heading`, `sort_order`). This is a *finding aid* … Volume-grain, never
document-grain." Schema check (check-M5): the table also carries `decimal_class`, `lot_file_norm`,
`entry_text`, `note`, none listed.

**Change.** List the real columns and add: "It is also the editors' own gloss table for filing keys —
4,242 of 33,764 rows carry a `decimal_class`; 804 distinct class glosses in 50 volumes (`411.: U.S.
trade`, `411.4141: U.S. trade relations with the United Kingdom`, `frus1958-60v04`) — and for
1950–63 keys it is the **only** gloss in the stack. Do not confuse it with the bundled
`volume-sources-index.json` (§14.11), which holds the *resolved collections* (3,412 rows, 251 volumes)
and none of these glosses; an agent given only the JSON will report the glosses absent."

**Evidence.** `rounds/round2/threads/R8-archival-deepening.md:27–32` ("sort_order 15 reads verbatim: >
**`411.: U.S. trade`**"; "Thirty distinct `411.` glosses appear across **38 rows in 17 volumes**");
check-M5 re-ran `.schema volume_sources` and the counts (33,764 / 258 / 4,242; 804 glosses in 50
volumes; rows 15–21 of `frus1958-60v04`); `S1:204–205` names the JSON's 3,412-row shape.

**Would have prevented.** Round 1 quoted three sub-key glosses and never ran the table over the whole
`411.` range (`agents2/refute-R8-archival-deepening-method/verdict.md:23–45`); the round-3 brief had to
carry the gloss as a standing fact (`S3:159–161`).

### §4.4 — two smaller column notes (could; checker-surfaced, check-M2 missed 10 and check-M4 missed 7)

**Lines.** §4.4:292 (`repository`), :300 (`raw_text`).

**Change.** (a) After the `repository` row: "The vocabulary is closed (Department of State 212,858 ·
National Archives 10,514 · Nixon 8,014 · Johnson 4,693 · …); it has **no Commerce value**, so a
repository the parser does not recognise falls to `raw_text`/`series_name`, not to a new label." (b)
After the `raw_text` row: "It is also where the printed source note's misprints live: a singleton
class key beside a large neighbour (`611.8331/139` beside `611.3331`, `611.2031`/`611.2631` beside
`611.2531`) is a suspect, and the document header decides."

**Evidence.** `rounds/round2/audit-round1.md` N3 ("`document_sources.repository` has **no Commerce
value at all**"); `agents/refute-T3-citations/verdict.md:374–375`; `agents3/read-D5-geography/queries.log:125–127`
("almost certainly a misprint for 611.3331/139. Found by reading the document, not by any query");
`agents3/read-D5-geography/reading-notes.md:22–23`.

### §5 — the office is named, the holder is resolved by date, and the bundle carries the tenures (could; checker-surfaced, check-M4 missed 4)

**Lines.** §5:414–432 (or §14.10).

**Change.** One sentence: "A header names the office, not the person (*The Secretary of State to the
Chargé in Salvador (Engert)*, 1925-08-06 — Kellogg, not Hughes, who left office 4 March 1925); the
bundle's `pocom-index.json` (Principal Officers and Chiefs of Mission) and `person-authority-index.json`
carry the tenures to resolve it by date."

**Evidence.** `rounds/round3/memo.md` §7.3 item 3 (`frus1926v02/d610`); `grep -i 'pocom\|person-authority'`
over the guide → nothing (check-M4).

### §6.2 — the count form, and the phrase that walks the corpus (should, upgraded by check-M3; M1-R3, M3-7 and M6-G2 folded)

**Lines.** §6.2:503–526.

**Guide now.** The ranked `JOIN document_cache dc ON dc.rowid = frus_documents.rowid … LIMIT 50` recipe,
then "FTS5 query syntax is available in full: … and `term*` prefixes." Nothing on counting. §6.3's
vocab counts are stem frequencies, not document counts under the apparatus filter.

**Change.** After line 524 (the end of the `bm25()` paragraph, before the syntax sentence at 526), two paragraphs. **On the mechanism I side with
check-M1 over check-M3**: check-M3's amended text keeps the agents' phrase "makes SQLite abandon the
FTS index and scan", but check-M1 ran `EXPLAIN QUERY PLAN` on the copy — "`SEARCH dc USING COVERING
INDEX idx_document_cache_facet` … then `SCAN frus_documents VIRTUAL TABLE INDEX 0:=M10` — the planner
drives the join from `document_cache`'s facet index (the copy has no `sqlite_stat1`) and runs the MATCH
restricted to one rowid ~307,000 times. It does not 'abandon' the FTS index; it probes it per row" —
and the tell is what lets an agent diagnose a variant.

> **For counts, filter with `rowid IN (…)`, not with the join.** Every scoping figure is "how many
> documents, in how many volumes, match this phrase". The ranked shape above plans FTS-first and is
> fast even for a common phrase. Turned into a count — `COUNT(*)`, `COUNT(DISTINCT volume_id)`,
> grouped by year, with the apparatus filter — the planner (the copy carries no `sqlite_stat1`)
> drives the join from `document_cache`'s `(is_front_matter, is_editorial_note)` index instead and
> runs the MATCH once per row: on the full copy a single phrase costs 5.3 s that way against 0.3 s as
> ```sql
> SELECT COUNT(*) AS docs, COUNT(DISTINCT volume_id) AS vols
> FROM document_cache
> WHERE rowid IN (SELECT rowid FROM frus_documents WHERE frus_documents MATCH '"department of state"')
>   AND is_front_matter = 0 AND is_editorial_note = 0
>   AND volume_id NOT IN ('frus1951-54IranEd2', 'frus1969-76ve15p2Ed2');
> ```
> The tell in `EXPLAIN QUERY PLAN` is `SEARCH dc USING COVERING INDEX idx_document_cache_facet`
> appearing *above* `SCAN frus_documents VIRTUAL TABLE`. Where you need the join's columns, `CROSS
> JOIN` forces FTS first. In a loop over phrase families with a further join to `document_dates`, five
> agents in one investigation recorded the join form timing out at 120, 300 and 600 seconds on the
> positive control, and each round re-learned it.
>
> A second cost is in the phrase itself. A phrase MATCH whose tokens include `of` or `the` walks
> doclists that span nearly the whole corpus: `"office of international trade policy"` and its like ran
> past fifteen minutes on one machine and were abandoned, and seven families lost their literal share
> to it. Budget for it, run such phrases one at a time in a process that prints progress, and never
> let a no-output watchdog decide the phrase is absent. (`"department of state"` itself, the §14.2
> control, is one of these on the join form — 5 minutes; use the count form above, 0.3 s.)

At line 526, after "`term*` prefixes", add "(matched against stems — see §7.1)".

**Evidence.** `agents/A4-sql/queries.log:6` ("the first family.py (join form …) TIMED OUT at 120 s on the
positive control"); `agents/A5-subjects/queries.log:551` ("timed out at 600 s. The Python-side
hit-list version … completed in 3 s"); `agents/refute-A1-headings-numbers/queries.log:349` ("timed out
at 300 s inside the FTS JOIN loop"); `agents2/thread-R1-instruction-genre/queries.log:13–19` ("The
IN-subquery form above is the one used for every count"); 92 files across the run carry `rowid IN
(SELECT rowid FROM frus_documents` (check-M3); check-M1's timings (0.29 s vs 5.3 s; `CROSS JOIN` 3.3 s
wall) and plan; `rounds/round2/critic.md:135` ("a six-word phrase MATCH over this index runs to many
minutes"); `rounds/round3/memo.md:575–579` ("each phrase MATCH ran past fifteen minutes on this
machine and was abandoned"); `rounds/round3/critic.md:322` (seven families' shares lost);
`agents/refute-A1-headings-numbers/verdict.md:112` ("Phrases containing 'of'/'and' are impractically
slow on this FTS5 index — an attempt with 'department of state' ran past 5 minutes").

**Would have prevented.** Four abandoned first attempts in round 1 (120–600 s each), R1's repeated
timeouts, and the seven unmeasured literal shares in round 3.

### §6.4 — the decade table and the rate rule (must; M3-2, appended not replaced per check-M3)

**Lines.** §6.4:541–561.

**Guide now.** The per-year total, then "Always pair it with what the series drops:" and the undated
count. Never says to divide a term's counts by the totals, never states the spread; `per 1,000`,
`normalis`, `largest decade` → 0 hits.

**Change.** Append after the undated-count query (keep everything that is there):

> **The decades are not the same size, so a term's raw decade counts are a chart of this table before
> they are a chart of the term.** Dated, non-apparatus documents per decade, second editions folded,
> measured 2026-09-02 over 552 volumes: **1860s 11,250 · 1870s 5,798 · 1880s 6,472 · 1890s 9,712 ·
> 1900s 9,924 · 1910s 30,359 · 1920s 19,733 · 1930s 39,196 · 1940s 74,043 · 1950s 42,296 · 1960s
> 27,650 · 1970s 22,259 · 1980s 5,949** — a 12.8× spread. Measured: `"commercial policy"` runs 1930s
> 355 / 1940s 582 raw and one investigation published the 1940s as its peak; per 1,000 dated documents
> of each decade it is 9.06 / 7.86 and the 1930s is the peak. `"chamber of commerce"` has its largest
> raw count in the 1930s and is, per 10,000, densest in the 1900s and only fourth in the 1930s.
>
> Publish the rate beside the raw count, never instead of it, with the decade's denominator and the
> numerator's top-volume share. A small decade's rate can be one negotiation: 76 of the 1900s' 116
> chamber-of-commerce documents sit in three volumes, and the rate without the two densest is 64.4
> per 10,000 against the published 116.9. And the last bucket is cut by the publication frontier:
> 1980 alone supplies 1,799 of the 1980s' 5,949 (30%), from the `frus1977-80` volumes, and the 1980s
> in this build is 41 volumes' worth of a partially-published subseries — bound the final decade at
> the last fully-published year, or drop it, and say which.
>
> ```sql
> -- denominator: dated, non-apparatus documents per decade, Ed2 folded (§14.9)
> SELECT substr(dd.date_iso, 1, 3) || '0s' AS decade,
>        COUNT(*) AS docs, COUNT(DISTINCT dc.volume_id) AS vols
> FROM document_dates dd
> JOIN document_cache dc USING (volume_id, document_id)
> WHERE dd.date_iso IS NOT NULL
>   AND dc.is_front_matter = 0 AND dc.is_editorial_note = 0
>   AND dc.volume_id NOT IN ('frus1951-54IranEd2', 'frus1969-76ve15p2Ed2')
> GROUP BY decade ORDER BY decade;
>
> -- numerator for one phrase: same scope, same grouping (the count form is §6.2's IN-subquery)
> SELECT substr(dd.date_iso, 1, 3) || '0s' AS decade, COUNT(*) AS hits,
>        COUNT(DISTINCT dc.volume_id) AS vols
> FROM document_cache dc
> JOIN document_dates dd USING (volume_id, document_id)
> WHERE dc.rowid IN (SELECT rowid FROM frus_documents WHERE frus_documents MATCH '"commercial policy"')
>   AND dd.date_iso IS NOT NULL
>   AND dc.is_front_matter = 0 AND dc.is_editorial_note = 0
>   AND dc.volume_id NOT IN ('frus1951-54IranEd2', 'frus1969-76ve15p2Ed2')
> GROUP BY decade ORDER BY decade;
> ```

**Block.** §12, SCOPING, one line after 955: "- Never publish a term's decade shape as raw counts alone:
the 1940s holds 74,043 dated documents and the 1870s 5,798. Give per-1,000 of that decade's dated
non-apparatus documents beside every raw count, with the numerator's top-volume share — a small
decade's rate can be one negotiation."

**Evidence.** `rounds/round2/threads/R2-commercial-policy.md:45–51` ("the 1940s is the largest decade in
the corpus (74,043 dated documents against the 1930s' 39,196), so the raw count flatters it"),
`:72–77` (9.06 vs 7.86), `:113–115` (the denominator row, which begins with the 1860s cell of 11,250
the miner had dropped — check-M3's restoration); `rounds/round2/threads/R9-private-counterpart.md:22–27`
("peaks in the 1900s at 116.9 documents per 10,000 … The decade with the largest raw count (the 1930s,
241 documents) is only the fourth densest"); `agents2/refute-R2-commercial-policy-method/verdict.md:78–82,181–182`
(blind re-implementation: "8.50 and 5.07 per 1,000. The rate conclusion is unchanged");
`agents2/refute-R9-private-counterpart-method/verdict.md:89–110` ("frus1907p1 37 · frus1908 23 ·
frus1906p1 16 (= 76 of 116, 66%)"; :114,289 "publish the ex-`frus1907p1`/`frus1908` rate of 64.4 per
10,000 beside it"); `rounds/round1/critic.md:228` (item 2 propagated "1940s 582");
`agents3/refute-C2-number-corrections/verdict.md:95–118` (B2: "1980 supplies 1,799 of the 5,949
denominator documents (30%) … the 1980s in this build is 41 volumes' worth of a partially-published
subseries" — check-M4's addition). The miner's "fell to fourth" for the 1900s was its own gloss and is
not in the text (check-M3).

**Would have prevented.** The round-1 memo's "1940s peak … do not share a decade" and the round-1
critic's item 2, which sent a whole round-2 thread and two refuters to reverse it; R9's "peaks in the
1900s" superlative.

### §6.4 — four date traps the time series will not announce (should; M2-R6 kept)

**Lines.** §6.4, after the paragraph above; one cross-reference sentence in §14.7.

**Guide now.** §4.3:241–242 defines the range; §6.4 buckets with `substr(dd.date_iso, 1, 4)`;
`BETWEEN` occurs nine times in the guide, none in SQL; `ORDER BY` twelve times, none about earliest-ness.

**Change.**

> Four traps the time series will not announce:
> - **Range-dated documents.** A printed "July —, 1877" is encoded as an interval; `date_iso` is its
>   *start* (here 1877-06-30, the month before). A chronology that prints `date_iso` alone gives day
>   precision the editors did not; print `date_iso_max` beside it, or say "min" — `SELECT
>   SUM(date_iso <> date_iso_max)` tells you how many of your rows are intervals.
> - **A decade bucket is not a year range.** "1960s: 24" does not say 1961–63; nine of those 24 were
>   1964–67. Re-run at year grain before writing a year span.
> - **"Earliest" needs `ORDER BY date_iso`.** A hit list sorted by `volume_id` puts frus1950v01
>   before frus1950v06 regardless of date; two "earliest in window" cells were wrong for that reason.
> - **`BETWEEN '1934' AND '1945'` drops all of 1945** — it is a string comparison and `'1945-01-01' >
>   '1945'`. Write `>= '1934' AND < '1946'`.

§14.7, one sentence after the volume-year paragraph: "Document date is a range: see §6.4's four traps
before publishing a chronology."

**Evidence.** `agents/refute-T1-citations/verdict.md:129–135` ("The report takes `date_iso` alone and dates
d1 **1877-06-30**"), `:354` ("`date_iso_max` was never consulted");
`agents/refute-T4-citations/verdict.md:39,109,262` ("a decade histogram read as a year range"; "sorted by
volume id"; "**Every "earliest" in §1.4 is unordered.** Two of the two are wrong");
`agents/refute-A6-semantic-numbers/verdict.md:31` ("`'1945-01-01' > '1945'` … **497**, not 472");
`agents/refute-T3-citations/verdict.md:377–380`; `agents/refute-A1-headings-numbers/verdict.md:96` (heading
periodisation differs "by **decade for 13**").

**Would have prevented.** T1's two month-wrong dates; T4's Dillon Round claim and both "earliest"
cells; A6's 472 → 497.

### §6.5 — `lot_file_norm` is a parse, not an assertion (should; M4-R5(b))

**Lines.** §6.5:574–576.

**Guide now.** "for lot-file work join on `lot_file_norm`, never on the raw `lot_file` spelling, which
varies (`64 D 199`, `64D199`, `64 D199`)."

**Change.** Append: "`lot_file_norm` is a parse, not an assertion: it is populated on some rows whose
note names no lot at all (two of the five `75 D 229` rows are Nixon Presidential Materials notes), so
read `raw_text` for any lot you publish a shelf for."

**Evidence.** `agents3/corr-C1-archival-corrections/queries.log` Q9; check-M4 re-ran `SELECT … FROM
document_sources WHERE lot_file_norm='75D229'` → five rows, `frus1969-76v02/d1` and `/d11` carry
`lot_file = '75 D 229'` while their `raw_text` reads "Nixon Presidential Materials, White House Central
Files …" with no lot — "it is `lot_file` itself, not only the norm, that is populated: a parser
defect". Repo-issue stub below.

**Would have prevented.** A five-document count for `75 D 229` that is three, and the date-span
failure the two phantom rows manufactured.

### §7.1 — the three stem mechanisms, and the literal-share rule (must; M2-R4, M3-3 and M4-R9 folded — the four checkers agree on the substance and on two corrections)

**Lines.** §7.1:630–641; §6.2:526 (the prefix clause, above); §12:917–919 (block).

**Guide now.** "`containment`, `contains`, and `containing` are all stored as `contain`; `allies` is
`alli` … A `MATCH` for `containment` also matches `contained` and `container`. You cannot separate
them at the index; if the distinction matters, filter the retrieved `body_text` afterwards." One
collision, "filter afterwards" as an option, no rule, no threshold, no sample protocol; `collision`,
`subsequence`, `literal share` → 0 hits. Round 2 was failed on P1 for exactly this
(`rounds/round2/score.md:44`); round 3, with the rule in its script, passed 29 of 29.

**Change.** (a) Three bullets after the existing three:

> - **Collisions are not exotic.** Measured on this corpus: `office`/`officer`/`offices` → `offic`
>   (`"consular officer"` = `"consular office"` = 3,615 documents; `"commercial officer"` was half
>   *commercial office*); `act`/`acting` → `act` (`"rogers act"` 8 documents, 7 of them "Rogers,
>   Acting …", 1 the statute); `consul`/`consulate(s)` → `consul` (36,226); `work`/`working`;
>   `attach*` → *attached*. Any phrase whose last word is a noun with a verb or plural homograph
>   needs a literal check.
> - **A `term*` prefix is matched against stems.** A prefix longer than the stem reaches only the
>   unstemmed residue: `reorganiz*` returned 9 documents, `reorgan*` 5,184; `amalgamat*` 0,
>   `amalgam*` 420. Check the stem in `frus_documents_vocab` before writing any `…iz*`, `…ation*` or
>   `…ment*` prefix.
> - **Phrase matching is subsequence matching** (in any engine, not FTS5 alone). `"division of
>   commercial policy"` matches every occurrence of *Division of Commercial Policy and Agreements*; a
>   successor unit's count contains its predecessor's. Subtract the longer phrase, or say you have not.

(b) A paragraph after the bullets — the two round-2/round-3 formulations merged, in the form check-M3
and check-M4 both arrived at:

> That "filter afterwards" is a rule, not an option, and it has a measured shape. Over 44 phrase
> families audited in one investigation, three failed the share and two more that had shipped with no
> share failed when first measured: `"national treatment"` is literal in **9 of 40** (34 are
> *most-favored-nation treatment* — `national → nation`, and unicode61 drops the hyphens);
> `"commercial officer"` **22 of 40** (*commercial office*); `"clearing agreement"` **157 of 229**
> (*clear agreement*); `"export administration"` **55 of 86** (29 of the misses are the 1917 *Exports
> Administrative Board*: `exports → export`, `administrative → administr`); `"american exporters"` **453
> of 907** (*export trade*). `"generalization of"` returned 10,717 documents because the stem is `gener`.
>
> **Rule: no phrase count containing a word with a colliding stem is published without its literal
> share, and a family you argue from carries one — a false-friend screen is not a substitute.** The
> working threshold that investigation used was 0.80 (a project convention, not a measured constant):
> below it a family is unusable in its published form. The protocol:
>
> 1. An evenly-spaced sample of 40 from the `(volume_id, document_id)`-sorted hit list (≥30; the whole
>    set under 300; a census for a load-bearing family).
> 2. Regex over the concatenation of **all four indexed columns** — `header`, `dateline`,
>    `source_note`, `body_text` — NFKD-stripped and whitespace-collapsed. Sampling `body_text` alone
>    manufactures misses.
> 3. Run it **strict** (single spaces) and **tolerant** (each word allowed its inflections; any run of
>    space, hyphen, comma, parenthesis, full stop between words) and print both. **Publish tolerant,
>    strict beside it.** Low strict with tolerant 1.000 is inflection and harmless (`"consular
>    invoice"` 0.372 / 1.000; `"bilateral balancing"` 62 of 89 strict, 87 of 89 once *bilaterally
>    balanced* is allowed); a low **tolerant** share means the stemmer folded two words together
>    (`"national treatment"` 0.175: the misses are *most-favored-nation treatment*). The band also
>    holds the corpus's hyphenation (*East–West trade*: strict 6 of 809, tolerant 809 of 809) and the
>    tokenizer's list-crossing false positives (*"economic, foreign policy, and ideological"* matched
>    as *economic foreign policy*). Read the misses before condemning.
> 4. Print the share in the family's row beside the count. Budget for the phrase MATCH itself: a
>    phrase whose tokens include `of` or `the` can run for minutes on this index (§6.2); do not
>    publish a family unmeasured because its MATCH was slow.
>
> A literal share tests the stemmer, not the referent: a homograph passes at 1.000 (`ito` is one
> quarter the Japanese surname Itō, 89 of 355, every one before 1946), which is §14.5's question,
> asked separately — an acronym or short family needs a date or context screen reported beside it.
>
> Cross-lemma folds to expect: `officer/office → offic`; `national/nation → nation`; `clearing/clear →
> clear`; `balancing/balance → balanc`; `exports/export → export`; `administrative/administration →
> administr`; `reciprocity/reciprocal → reciproc`; `attaché/attached → attach`; `promotion/promote →
> promot`; `generalization → gener`. Inflectional folds (`policy/policies`) are benign. Two near
> misses: `commissioner → commission` but `commission → commiss`; `commercial → commerci` but
> `commerce → commerc`.

**Block.** §12, KNOWN TRAPS, replace lines 917–919 with:

```text
- The FTS tokenizer is porter stemming and unicode61 drops punctuation. Index terms are stems
  ('containment' -> 'contain'); a vocab lookup for a full word returning nothing means you used the
  wrong form. The converse bites harder: a phrase MATCH also returns a DIFFERENT word with the same
  stem ("commercial officer" returns "commercial office"; "national treatment" returns
  "most-favored-nation treatment"). Publish no phrase count without its literal share, sampled over
  header+dateline+source_note+body_text, tolerant with strict beside it; below 0.80 tolerant is
  unusable; read the misses before calling a family unusable; a 1.000 share does not test the referent.
```

**Evidence.** `agents/refute-A4-sql-history/verdict.md:30` ("7 of 8 hits are 'Rogers, acting …'"),
`:63–66` ("`"consular officer"` (3,615 / 352): a stem collision AND a false friend … identical sets of
3,615"); `agents/refute-T4-citations/verdict.md:96–97,250–253` ("the true literal count is 5, not 10";
"One literal-match control column would have caught six bad rows");
`agents/refute-A4-sql-numbers/verdict.md:170–177,214` ("`reorganiz*` **9 / 9**; `reorgan*` 5,184 / 519";
36,226); `agents/refute-T3-method/verdict.md:272–274` ("`amalgamat*` returns **0** … `amalgam*` returns
**420**"); `agents/refute-T2-method/verdict.md:132–141` (214 contains 83; "**131 of 306,619**");
`rounds/round2/threads/R2-commercial-policy.md:165–176,204–214,246–252,254–270` (fold classes; 44
families; the audit's own instrument caught by the strict column; the three refinements);
`rounds/round2/threads/R6-1930s-instruments.md:126–136` (`gener`, 10,717 / 547);
`rounds/round2/threads/R9-private-counterpart.md:56–60` and
`agents2/refute-R9-private-counterpart-citations/verdict.md:67` (453 of 907 "exact");
`rounds/round2/score.md:44` (P1 violated; 0.686 and 0.628 — the memo's fix pass re-measured the second
at `rounds/round2/memo.md:372` "55 literal of 86 (0.640)", the settled figure, per check-M3);
`rounds/round2/memo.md:365–381` (Exports Administrative Board; East–West trade; `"bilateral
balancing"` 62/89 → 87/89); `R2-commercial-policy.md:206` ("Verdict rule as the task specifies: literal
share below 0.80 ⇒ unusable" — the threshold is the task's, which is why it is stated as a convention;
check-M6 C18 calls it "measured", check-M3 and check-M4 do not, and the record supports the latter);
`rounds/round3/threads/C2-number-corrections.md:350–352,363,375,420–425` (strict vs tolerant; 0.175;
0.372/1.000; `ito` 1.000 and 89/355 Itō); `rounds/round3/memo.md:533,569` ("The tolerant share is the
published measure"; `"trade center"` 0.774 argued from with `—` in the column);
`agents3/corr-C2-number-corrections/queries.log:190–194` (the `of`/`the` timeouts).

**Would have prevented.** Round 2's P1 failure; `"clearing agreement"` and `"export administration"`
shipping in the memo's first draft with `—` in the literal column; round 1's "American exporters 520";
A4's `"rogers act"` 8 → 1; T4's 23 → 17 (and its "none between 1952 and 1958", which becomes true once
the artefacts are removed); T2's DCP 214 → 131; `ITO 169` published where the family is 355 with 89
Itō; the three discarded R6 numbers.

### §7.7 — a subject tag can be a bare-word count (should; M5-R7 amended)

**Lines.** §7.7:693–700; §12:929 (block).

**Guide now.** "'Blockade appears in N documents' is a statement about string matching." Right, and
under-specified: nothing says the matched "variant" can be one common word, nor how to test a tag.

**Change.** After "a statement about string matching":

> — and the matched string may be one common word. Measured on the working scope (apparatus excluded,
> Ed2 folded): *Trade relations* tags 28,815 documents, of which 28,144 contain the stem `trade` and
> only 1,509 the phrase "trade relations" — in the 1860s it fires on the slave trade; *Customs
> regulation* tags 9,633, of which 9,627 contain `customs` and 278 "customs regulation", and 2,763
> (28.7%) carry no fiscal cue at all ("customs and habits"). One agent's reading of 20 documents per
> tag found 10 and 4–5 on topic. Before using any tag as a count, run the literal-phrase and the
> bare-stem FTS queries and publish tag ∩ phrase / tag; the shortfall runs both ways — 63 of 937
> *Consular offices* documents contain no `consul*` token in the index, the tagger having matched text
> the index does not hold. And check the tag's date distribution against the term's own first
> appearance: the *Multilateral Trade Negotiations* tag fires on 136 documents dated before the phrase
> exists (1972-08-15). A subject absent from the 491-name vocabulary is not a corpus absence either —
> the vocabulary has no subject for the Department of Commerce, its Bureau of Foreign and Domestic
> Commerce, or commercial attachés.

**Block.** §12:929, append to the subject-tags bullet: "A tag may be a single bare word; verify with
the literal-phrase query before counting."

**Evidence.** `agents/refute-A5-subjects-history/verdict.md:26–33` ("**27,344 of the 28,815 tagged docs do
not contain the phrase** … **28,144 of the 28,815 tagged docs contain it** … 100 contain 'slave trade'";
"9,627 of the 9,633 tagged docs contain the word 'customs' … **2,763 of 9,633 (28.7%) contain no fiscal
cue at all**"), `:92` ("one literal-phrase FTS query each would have shown it"), `:5–6` ("REFUTED,
severity MATERIAL"); `agents/A5-subjects/report.md:7` (10 of 20; 4–5 of 20 — labelled as one agent's
era-blind reading, per check-M5); `agents/refute-A5-subjects-numbers/verdict.md:48` (63 of 937);
`agents/A5-subjects/report.md:44` (the vocabulary's holes — check-M5 missed 8);
`rounds/round1/threads/T6.md` §9 #9 (the *Tariffs* tag 334 = 888 documents = the FTS word `tariff`).

**Would have prevented.** A5's Tier-1 intersection (572 BOTH documents, 64% resting on the two
bare-word tags), which fed round 1's scope and admitted a speech volume and a public-diplomacy volume
to Tier 1.

### §8 — quotations are checked by machine; the elision rules `body_text` forces (must; M4-R2 amended, with check-M2 missed 9)

**Lines.** §8:729–731.

**Guide now.** "**Quotations come from a retrieved row, never from the model.** If a quotation appears
in the agent's prose, it must have appeared in a result set first. A useful discipline: require the
agent to output the `SELECT` that returned any quoted text alongside the quotation." No fold, no
machine test, no elision rule; §7.2 says footnotes are inside `body_text` but not that they land
mid-sentence.

**Change.** Replace 729–731 with the check-M4 form. The miner's form said "require the quoted string as
a substring", which fails every legitimately elided quotation; the critic's own `verify6.py` is a
*chunked, order-tolerant* matcher (`chunked_match(frag, b, size=36)`, ≥90% of chunks) and check-M4
showed it would pass all three of D2's defects. The rule that catches D2 without manufacturing false
failures is segment-strict:

> **Quotations come from a retrieved row, never from the model — and are checked by machine.** Require
> the `SELECT` beside every quotation. Then verify each: lower-case both sides and drop everything but
> `[a-z0-9]` (this absorbs smart quotes, dash forms, line-break hyphens and the space the flattened TEI
> puts before punctuation — a checker's own accent handling is the commonest false alarm); split the
> quotation at its ellipsis marks; require every segment as a substring of `header || dateline ||
> source_note || body_text` for the *exact* `(volume_id, document_id)` cited, at increasing offsets.
> Segment-strict, not chunk-tolerant: a matcher that accepts 90% of chunks in any order passed a
> compressed list set inside quotation marks, an unmarked 232-character elision that changed a
> pronoun's referent, and two passages joined in reverse order — all three of which the strict test
> refuses. A corpus-wide search finds the right words in the wrong document; test the pair. Three
> rules for the residue: `body_text` splices the editors' footnotes into the printed sentence
> (`frus1937v02/d101` reads "…to Squire E. C. Squire, American Trade Commissioner at Sydney. who
> concurs"), so a quotation crossing a footnote anchor marks the elision and says the TEI settles the
> printed form; an elision is always marked, never removes the words that fix a referent, never
> reverses source order; and nothing goes inside quotation marks that is not in the row — no
> compression, no bracket-free substitution, no silent initial capital. Round 3 checked 220 quotations
> this way and found 0 fabrications; a review by eye had not. Reading has a count of its own — §9
> item 8.

**Evidence.** `rounds/round3/critic.md` §1.2 ("matched each against `header || dateline || source_note ||
body_text` for that exact `(volume_id, document_id)` pair, on an alphanumeric fold … **182 of 220
extracted quotations matched verbatim**"; the three false failures all the footnote splice);
`agents3/critic3/verify6.py:3–6,10,14` (the fold; the exact-pair SELECT; `chunked_match … size=36` —
read 2026-09-04); `agents3/refute-D2-trade-fairs-quotes/verdict.md:46–53,64–83,92–94` ("a quoted string
that does not exist … The compressed list is the report's own prose set inside the quotation"; "232
characters and three sentences are removed without an ellipsis, and the removed text is what fixes the
referent"; "the ellipsis silently reverses them"); `rounds/round3/memo.md` §2.4:372–375 ("**Any
quotation drawn from `body_text` across a footnote anchor must mark the elision**"); `S3:507`
("allowing only whitespace normalisation" — the refuters needed NFKC/NFC plus quote/dash folds,
`refute-D4-ecefp-quotes/verdict.md:29`, `refute-D6-conventions-unions-quotes/verdict.md:28–33`); `rounds/round2/audit-round1.md` §4 ("My first pass
reported five failures; all five were my own accent handling — `attaché`").

**Would have prevented.** D2's non-existent "Frankfurt, Beirut, Lagos and Nairobi" string and its
referent-changing elision, caught by a refuter rather than by the thread; the P3 rubric item gains a
guide rule to score against.

### §9 — six edits to the verification protocol

**Lines.** §9:763–785.

**§9 item 1, append (should; M2-R8 amended).** After "Read the `WHERE` clause.": "Then resolve five
report labels at random against the log. A label that resolves to nothing, a regex elided with "…",
or a printed query returning a different number from the one beside it leaves the number unverified
whatever its value." *Evidence:* `agents/refute-T2-citations/verdict.md:163–166` ("`queries.log` is 9
lines and holds **three** entries … resolves, for ~35 of ~38 figures, to a log entry that does not
exist"); `agents/refute-T6-citations/verdict.md:59–61` ("a **fourth disjunct the report omits**: `OR
"october 1 1890"` … differ by 92%"); `agents/refute-T4-method/verdict.md:27,170,180` ("V95 … no regex");
`agents/refute-A5-subjects-numbers/verdict.md:24` ("elided with '…'"); `rounds/round1/score.md` R1
(the round-1 memo's only violation: M47/M48 "`header LIKE` census …, with no patterns"). *Would have
prevented:* T6's 13-vs-25; T2's phantom labels; memo R1. The rule itself already exists twice (§9
item 1, §13's row) and the round-1 failures are disobedience of it; what is new is the spot check and
that a regex is a query (§13 below).

**§9 item 3, extend (should; M2-R7 amended).** Replace with: "**Ask for the denominator with every
proportion — and for its grain and its members.** '1,447 of 12,060 documents in 43 indexed volumes' is
checkable only if the 43 are listed somewhere and 'documents' means distinct `(volume_id,
document_id)` pairs. State the grain (occurrences / notes / distinct documents / volumes — one run
printed 23 'hits' that were 16 documents and '116 footnotes' that were 144 occurrences in 140 notes),
enumerate the set behind any denominator used more than once (one eight-volume set carried
twenty-four proportions and was never listed; one '18 volumes' listed 16), and for any statistic that
varies by era — unclustered share, footnote density, headings per volume — compare against an
**era-matched** baseline, not the corpus (the map's unclustered share is 47% before 1900 and 22% in
1945–64; FRUS's sectioning granularity quadruples in 1894, so a raw 0 → 18 commercial headings
overstates the editorial turn 3.4×). A table headed 'ranked' or 'top N' that omits rows is a
selection; say so." *Evidence:* `agents/refute-T4-citations/verdict.md:259–260`;
`agents/refute-A8-pointed-at-numbers/verdict.md:91`; `agents/refute-T5-method/verdict.md:284–287`
("A denominator used in twenty-four proportions should be printed with its members"); `rounds/round1/score.md`
defects 1 and 3; `agents/refute-A6-semantic-numbers/verdict.md:16–22` ("**1861–1899: 15,500 of 33,217 =
46.7%**"); `agents/refute-T6-method/verdict.md:132–139` ("`frus1893` has 35 named sections; `frus1894` has
**203**"); `agents/refute-T5-method/verdict.md:169,203` (curated selections printed as rankings).

**§9 item 5, append (should; M2-R7 amended — check-M2's placement, because item 5 already prescribes
the EXISTS re-derivation that caught the case).** After "disagreement is a finding.": "The commonest
case: `COUNT(*)` over a `LEFT JOIN` to a many-rows-per-document table (`document_subject_refs`,
`external_citations`, `person_mentions`) counts rows — 410 for a 46-document volume in one run, 762
for a 31-document one. Count `DISTINCT (volume_id, document_id)` or filter with `EXISTS`." *Evidence:*
`agents/refute-A5-subjects-numbers/verdict.md:6,10–13` ("**410 eligible documents** … WRONG. Actual: 46
… The same flawed shape produced `762` … and `439`" — re-derived "with EXISTS instead of JOIN").

**§9 item 6, replace (must; M2-R2 amended).** "**A zero is a claim about a query *and* a surface. Ask
for both.** 'Run it with the filter relaxed' catches a wrong query; it does not catch a surface that
was narrowed before the query ran, which is how most of round one's false zeros were made. Ask what
set the zero was measured over and how that set was built. If it is a regex-filtered heading file, a
hand-picked volume list, a `<text><body>` pass that never read `<back>`, a lookup of the named leads,
or a list of `header LIKE` prefixes copied from documents already in hand, the zero is a zero over
that artefact. An absence claim must be re-run over the unfiltered surface — with the apparatus
exclusion lifted, since `is_front_matter = 0 AND is_editorial_note = 0` is right for a count and wrong
for an absence — and a zero that has no logged query behind it is an assertion, not a measurement."
*Evidence:* `agents/refute-A2-tei-institutions-numbers/verdict.md:52` ("**A negative reported from a
set that could not contain it.**"); `agents/refute-T2-method/verdict.md:65,67` ("**Both of the report's
surfaces structurally exclude it, and neither exclusion is declared.**"); `agents/refute-T3-method/verdict.md:72`
("a hand-built list of the documents it already knew"); `agents/refute-T4-method/verdict.md:92–93`
("**11 of the 48 are absent** … 3,029 − 374 = 2,655, exactly"); `agents/refute-T1-method/verdict.md:135,156`
("None of these three zeros … appears anywhere in queries.log"; "The zero measures an editorial
convention"); `agents/refute-T1-citations/verdict.md:349–352` (the apparatus-exclusion case check-M2
added: `"bureau of foreign commerce"` corpus-wide returns `frus1900/message-of-the-president`,
`is_front_matter=1`, so "barely exists in the text" was "an artefact of the apparatus exclusion and
never says so"); `rounds/round2/audit-round1.md` N6 ("the pattern list was built from its own answers").
*Would have prevented:* T4's stratum (2,655 → 3,029, three empty years restored); T3's "6 of 21,602"
(→ 8 of 25,103); T2's 1944 appendix; T6's 1897 Canadian negotiation; T1's three false zeros; the
memo's M47/M48 census.

**§9 item 7, append (must; M2-R1 kept).** "Treat every *only / first / earliest / last / none* in the
agent's prose as a pattern in this sense — see §14.13."

**§9 new item 8 (must; M4-R1 amended).** "**When the task is reading, measure the reading.** Define the
counts before anything is read: *documents read* = distinct `(volume_id, document_id)` pairs whose
whole `body_text` was retrieved (captured length equals `length(body_text)`, §3); *documents quoted*
= distinct pairs a quotation is drawn from; *quotation passages* = the passages. Publish all three
with the whole/partial split, and pre-register a floor for the first two. The evidence is on disk,
not in the prose — the reading `SELECT` in the query log, the raw retrieved text, and running notes
written batch by batch — and the claimed count is checked against the distinct pairs in the raw text.
A count a pass did not do is worse than a small count. In one round the three counts were published
three ways (178/183, 175/178, 165/178) because no construction had been fixed; a thread's 66 was 61
distinct pairs in its own raw text. A cheap test that the output changed genre: table lines against
blockquote lines and distinct documents cited (97 → 24, 15 → 103, 76 → 156 in that round)." *Block:*
§12, REPORTING, one line after 939: "- If you read documents, report how many you retrieved whole
(captured length = length(body_text)) and how many you quoted; keep the reading SELECT and the raw
text on disk." — the counts are produced by the agent, which sees the block and not §9, and rounds
1–2 recorded nothing because no prompt asked (check-M4). *Evidence:* `S3:469–472` ("THE SUCCESS
CRITERION IS DOCUMENTS READ AND QUOTED, and it is a floor, not a target … a thread that reports a
number it did not do is worse than one that reports a small number"), `:495–496`;
`rounds/round3/critic.md` §1.1 ("Sum = **361**"), §1.3 ("Table lines fell by 75%, blockquote lines rose
nearly sevenfold, cited documents doubled"), §1.4 ("stated three different ways");
`rounds/round3/score.md` P4 ("three mutually inconsistent forms"); `rounds/round3/memo.md` §2.6:395–396
(rounds 1 and 2 "not recorded"), :447 ("361 documents retrieved, of which **316 were read whole**");
`agents3/refute-D1-fccr-treaties-quotes/verdict.md:242–243` ("distinct (volume_id, document_id) in
raw-reading.txt -> 61"); `rounds/round2/critic.md:363–364`. *Would have prevented:* rounds 1–2's "not
recorded"; the three inconsistent figures and D4's 22-vs-26; D1's 66 and D5's 77 published as 61 and
32-whole.

### §12 — the house-rules block: every change in one place

The block (§12:884–993, byte-identical to `Planning/c2-long-session/house-rules-block-v1.10.txt`) is
the instrument C-0 and C-2 measured at 99% obedience. The run's own scripts show what happens to a
copy: round 1's `HOUSE_RULES` was byte-identical, round 2's one sentence behind (the Ed2 "718/701"
surface sentence absent), round 3's a 50-line paraphrase of 110 — so the 29/29 memo obeyed a block
that was not the guide's (check-M6 §0, C7). The additions below total about **twenty-two lines on
110**. None is measured. Two consequences follow, both stated in Part 2: the C-0 harness should be
re-run with the revised block before v1.11 declares it the instrument, and any skill evaluation must
give its BLOCK arm the *same* revised block or a SKILL-arm win is attributed to the loader for what a
docs pass delivered (check-M6 C14(d)).

| line | section | change | from |
|---|---|---|---|
| after 895 | SURFACES | `- If your brief gives you a [HARVEST] path (the offline NARA record-group harvest the bundled archival JSON is projected from — one machine, gitignored): label every count from it [HARVEST], state its snapshot date, never sum it with a bundled count, and stream its shards in chunks (rg_59.json is 3.56 GB). If you are not given the path, say the surface is unavailable.` | M4-R7 / M5-R1 — my resolution, see §14.11 |
| 917–919 | KNOWN TRAPS | replace the stemming bullet with the seven-line form under §7.1 above | M3-3, M4-R9 |
| 929 | KNOWN TRAPS | append `A tag may be a single bare word; verify with the literal-phrase query before counting.` | M5-R7 |
| after 939 | REPORTING | `- If you say an earlier pass was wrong, silent, or never read something: grep its FINAL files (after its fix pass), show the command, and put the change in a table with the decisive query run on BOTH sides.` | M3-1 |
| after 939 | REPORTING | `- If you read documents, report how many you retrieved whole (captured length = length(body_text)) and how many you quoted; keep the reading SELECT and the raw text on disk.` | M4-R1 |
| 947 | SCOPING | `Count every spelling, hyphenation, plural, acronym and case variant` | M2-R13 |
| after 955 | SCOPING | the decade-rate line under §6.4 above | M3-2 |
| 962–963 | SCOPING | replace with: `- A negative built from vocabulary postdating the period is circular. Before claiming the corpus lacks pre-YEAR coverage, scan terms contemporaries would have used — including the COUNTERPART's vocabulary (merchants, chambers, the foreign ministry), not only earlier names for the office. Head an absence by the name you tested, and put the founding document beside it if the thing is printed under another name.` | M3-5 |
| 981 | ARCHIVAL | insert the one word `inclusive` before `date span` | M4-R4 / M5-R4 |
| 982 | ARCHIVAL | append `and the NAIDs several lots converge on` | M4-R6 |
| after 992 | ARCHIVAL | the pointed-at-channel line under §4.4 above | M2-R11 |
| 998 (prose, outside the block) | routing table | "The block above is longer than any agent reliably holds" is contradicted by the record: C-2 measured 99% at 123 tool calls with "not one item decayed" (`Planning/C2-Long-Session-2026-08-31.md:39–46`). Reword to "The block above was measured to hold across a doubled session (C-2), but its blocks are not equally reachable" | check-M1 missed 8 (both checkers flag it) |

Not added to the block, on the checkers' instruction: the owner-local harvest path (M4-R7/M5-R1 —
the path goes in the per-run RESOURCES text the orchestrator appends, as all three scripts did with
the record-group list); the candidate rule for `central-files-index.json` (M4-R5(c) — "leave the block
alone; the candidate rule lives in §14.11"); the critic's seven-item brief (M3-6 — a pasteable block
beside §12 or the workflow runbook, not §14).

### §13 — the reproducibility record (must; M1-R4 amended to four rows, and M2-R8's row edit)

**Lines.** §13:1020–1027.

**Guide now.** Six rows: date of the copy, app build and version, index format version, indexed volume
list, subject vocabulary digest, "The queries themselves | Verbatim, in a file, with their result
counts." §4.7:383 calls `my_writing_included` "the row the table exists for" — on an app export only;
§11:848 gives the strip for a hand copy but §13 never asks whether you ran it. No row for model,
sessions, prompt text or tool versions. Appendix A:1531 insists on "model id, GGUF weight hash" for the
embedder, which is the argument for recording the analysis model too.

**Change.** Replace the queries row and append four:

| Record | Where to get it |
|---|---|
| The queries themselves | Verbatim, in a file, with their result counts — **the pattern actually executed**, every disjunct included; a TEI, heading or JSON regex is a query for this purpose. Keep the log per agent session; a reading claim with no retrieval line in it is unverified. |
| Whether the copy contains your own writing, and how many rows | On an app export, `SELECT value FROM research_provenance WHERE key='my_writing_included'`. On a hand-made `.backup` nothing records it: if you did not strip them ([§11](#11-safety-privacy-and-what-leaves-your-machine)), count them — `SELECT COUNT(summary_text), COUNT(note_text), COUNT(user_tag_ids) FROM document_cache` — and state that no agent read those columns. |
| The agent model(s), the number of sessions including the ones that died, the run identifier your harness assigns, and what it cost | Your harness's log and usage accounting. If the model changed mid-run, say which agents ran on which. |
| The exact text each agent was given | The house-rules block *as pasted*, with everything you appended to it (resources, tooling notes), saved as a file. Two agents given different texts are two different instruments. |
| Tool versions | `sqlite3 --version`; `python3 -c 'import sqlite3, sys; print(sqlite3.sqlite_version, sys.version)'`; the harness version. |

**Evidence.** `rounds/round1/research-state.json` — `databaseCopy.madeWith = ".backup (hand-made; no
research_* views, no research_provenance)"`, `databaseCopy.myWritingIncluded = true`,
`databaseCopy.myWritingRowsNeverRead = {6556, 12, 85}`, `workflowRunId = "wf_4fc9078c-b84"`, and no
model, session, cost or prompt field (read 2026-09-04; 18 top-level keys); `rounds/round3/memo.md:3076–3118`
(§9: sqlite3 3.51 and the run id, no model); `FRUSExplorer/Export/ResearchDataExporter.swift:1369–1425`
(`ResearchStateRecord`'s ten fields — no writing flag, no model); `S1:140–142` (the counts had to be
handed to every agent for E2 to be scorable); the count SQL returns `6556|12|85` on the copy in 4.5 s
(check-M1). The prompt-text row is the measured drift fact above (three scripts, three block texts).
The queries-row edit: `agents/refute-A4-sql-numbers/verdict.md:28` ("the pattern actually run differed
from the printed one"); `S2:559–560` and 43 of 60 verdicts citing `queries.log` (check-M1 missed 6 —
refuters were handed the log, which §9 and §14.12 never name as the thing to hand over); `S3:507`.

**Would have prevented.** Not an error; a record gap. A reader of `rounds/round3/memo.md` §9 today cannot
learn which model wrote it, that a third of round 1's sessions never returned, or what it cost — which
is also why the cost paragraph proposed for §14.12 (below) can only be number-light: the run's own
files carry no figure to cite.

### §14.2 — compare the control; the surface must be whole; two shell notes (should; M2-R9 amended, M2-R2's shapes placed here by check-M2, M1-R7 kept, check-M2 missed 7)

**Lines.** §14.2:1085–1097.

**Guide now.** "Use a term you are confident appears (`Department of State` returns **178,311**
occurrences in 552 of 552 volumes) … Both in the same read, over the same files, reported with the
result." Then the working-directory and `File name too long` notes. One reference value, one surface;
the block asks only for "nonzero". `reference value` → 0 hits.

**Change.** Append three paragraphs.

> **Compare the control, do not just observe it.** "Nonzero in every volume" proves the scan runs; it
> does not prove the surface is whole. One heading census reported its control as 201 and never
> compared it — the true figure on that surface was 450, and the census had silently dropped every
> heading over 200 characters. One TEI table's control was 16% low and passed; every phrase row in it
> was 13–61% low, the line-wrap signature. Record the reference for your surface and treat a control
> materially below it (the two failures were 16% and 55% low) as a surface defect — a line-wrap, a
> length cap, a filtered file. References measured on the 2026-08-31 `.backup` of a full 552-volume
> index and the manifest's 552 TEI files, `Department of State`:
>
> | surface | reference |
> |---|---|
> | FTS `"department of state"`, apparatus excluded, Ed2 dropped | 93,418 documents / 549 volumes |
> | raw XML, 550 manifest files | ~177,900 occurrences (177,893 / 177,091 on two agents' folds) |
> | inside `<div type="document">`, tag-stripped and collapsed | 152,197 hits / 548 volumes |
> | titled `volume_structures` nodes (all levels, front and index included) | 450 of 25,103 |
> | body chapter / subchapter / compilation / section `<head>`s | 260 in 107 volumes |
> | `external_citations.raw_text LIKE '%RG 59%'` | 781 rows |
>
> A scan of a bundled artifact needs its own positive control (consular roll titles: `despatch` 3,355
> of 3,357). A random control is reported with its seed and as a mean over several draws — one
> headline random unclustered share was the lowest of thirty seeds (25.6 against a mean of 27.9,
> sd 0.98).
>
> **A control proves the scan ran; it does not prove the surface is whole.** Four surface-narrowing
> shapes produced false absences in one run, each caught by a verifier in one query: a heading file
> pre-filtered by a topic regex (a head reading "Reorganization Plan No. II" could never enter it); a
> `<body>`-only heading pass (FRUS puts administrative statements in `<back>` appendices —
> frus1944v01's "Reorganization of the Department of State" is one, stored `is_editorial_note = 0`);
> a census built from `header LIKE` prefixes copied from the documents already found ("a pattern list
> built from its own answers"); and the apparatus exclusion itself — `is_front_matter = 0 AND
> is_editorial_note = 0` is right for a count and wrong for an absence claim, and one run's "barely
> exists" institution was in a 1900 presidential message stored as front matter. Build a census from
> a superset scan with a stated inclusion rule, never by enumeration, and re-run every zero with the
> exclusion lifted.

And at line 1096 (the last line of that sentence; 1097 is blank), append to the shell-tooling sentence: "— and GNU `timeout` does not exist on macOS
(`command not found: timeout`; neither does `gtimeout`); guard a long scan with `perl -e 'alarm 600;
exec @ARGV' python3 scan.py …` or a Python-side alarm instead."

**Evidence.** `agents/refute-T3-method/verdict.md:156–164` ("report's regex … **21,602** | **6** |
**201**" vs "JSON parse … **25,103** | **8** | **450**"; "A control with no ground truth proves only
that the query executes"); `agents/refute-A8-pointed-at-numbers/verdict.md:76,96` ("a control that is
itself 16% low validates the mechanism, not the number"); `agents/refute-A8-pointed-at-history/verdict.md:42,51`;
`agents/refute-A7-came-from-numbers/verdict.md:31,120` (`despatch` 3,355 / 3,357); the references —
93,418 in 17 of the 28 round-1 verdict files (35 of 60 across the run), `agents/refute-A3-tei-policy-numbers/verdict.md` (177,893),
`agents/refute-A2-tei-institutions-numbers/verdict.md:26` (177,091 = 152,197 in + 24,894 out),
`agents/refute-T3-method/verdict.md:157` (450 of 25,103), `agents/refute-A1-headings-numbers/verdict.md:30`
(260 / 107), `rounds/round1/score.md:15` (781); the two heading rows are different surfaces and are
labelled distinctly on check-M2's instruction; "2%" was the refuters' brief tolerance, not a corpus
property, and is replaced by "materially below"; `agents/refute-A6-semantic-numbers/verdict.md:64`
("2,000-row random unclustered share over 30 seeds: min 25.6 (the report's seed 3), max 29.9, mean
27.9, sd 0.98"); the shapes — as under §9 item 6 above; `agents/refute-A3-tei-policy-history/queries.log:441`
("`(eval):1: command not found: timeout`", directly under the D1 FTS cross-check header, which has no
result after it); `which timeout gtimeout` → neither (re-run 2026-09-04); `perl -e 'alarm 2; exec
@ARGV' sleep 5` exits 142 (check-M1).

**Would have prevented.** T3's "6 of 21,602" (→ 8 of 25,103) and A8's whole §6 table including the
false "0 footnotes" for the Foreign Commercial Service; the four false-absence cases under §9 item 6;
one unguarded corpus scan in one refuter.

### §14.3 — the shape of the file (should; M2-R12 kept; check-M1's largest "missed")

**Lines.** §14.3:1098–1113, before the surface table.

**Guide now.** Counting surfaces only. `start tag`, `multi-line`, `<back>`, `subtype`, `694` → 0 hits.
Every round's script carried the warning instead (`S1:158–162`, `S2:164`, `S3:107`).

**Change.**

> **The shape of the file, since three scans in one run got it wrong.** A document is `<div …
> type="document" xml:id="dN">` whose start tag spans several lines with one attribute per line —
> measured over the first 150 manifest volumes, 150 of 150 have this shape and a single-line regex
> `<div[^>\n]*type="document"[^>\n]*>` finds 0 of 97,483 documents; §14.2's controls do not catch
> it, because they count a phrase, not documents, and a scan that found zero documents and 178,311
> control hits passes both. Parse, or scan across newlines. The same div carries
> `subtype="historical-document"` or `subtype="editorial-note"`, and a regex for `type=` that is not
> anchored (`(?<![-\w])type=`) matches `subtype=` first and recognises no document at all (one
> thread's whole first TEI table was built that way). Each document div carries
> `frus:doc-dateTime-min`/`-max`. Headings are the `<head>` of *non*-document divs, and they live in
> `<front>`, `<body>` **and `<back>`** — FRUS puts administrative statements in `<back>` appendices,
> so a `<body>`-only heading pass is a narrowed surface in §14.2's sense. Prefer a parser
> (`lxml`/`ElementTree`) with the manifest as the file list, never a shell glob over the 694 files on
> disk (the manifest names 552).

**Evidence.** `S1:158–162` ("a document is `<div ... type="document" xml:id="dN">` whose START TAG SPANS
SEVERAL LINES … do not match it with a single-line regex over one line"); check-M1 measured 150/150 and
0/97,483 (`frus1923v01.xml:16413–16415` the type case); `rounds/round1/threads/T6.md:576` ("**The
draft's whole §2.2 TEI table was produced by a broken scan and is replaced.** Its own regex for the
`type` attribute matched `subtype="historical-document"` first … Re-running with `(?<![-\w])type=`
yields 34,468 document divs"); `agents/refute-T6-citations/verdict.md:142`;
`agents/refute-T2-method/verdict.md:67,75` ("The heading pass reads only `<text><body>`; this div sits in
`<back>` … 264 non-document heads live in back matter across the same 244 volumes; exactly one matches
this thread's institutional pattern, and it is the one that refutes the claim"); multi-line handling
confirmed in A1-n, A2-h, A7-n, T3-m, A8-n; `agents2/thread-R6-1930s-instruments/queries.log:223`
("located with a multi-line regex").

**Would have prevented.** T6's broken first table (self-caught, at the cost of a thread's time); T2's
"first time the series prints" (the 1944 appendix).

### §14.4 — case is a variant; numbered instruments (could; M2-R13 kept; check-M3 on M3-5)

**Lines.** §14.4:1119 and the table; §12:947 (block, above).

**Guide now.** "Query every form and report the split." The table lists spelling, hyphen, plural,
acronym, word boundary; case is absent; so is numeral form.

**Change.** After the table: "**Case is a variant too.** Telegrams write 'Commercial attaché reports…'
and prose 'the foreign trade advisers of the Department'; one family that scanned only the
capitalised form was 47% low, another 40%. Run each family once case-insensitively as a control and
reconcile the difference." And one table row: `Reorganization Plan No. II` / `No. 2` — 0 / 20 documents
in 6 volumes — "the corpus writes Arabic numerals".

**Evidence.** `agents/refute-A2-tei-institutions-numbers/verdict.md:47,50,51,61` (mixed-case "Commercial
attaché" 22 + 4; lowercase "foreign trade adviser(s)" — 112, not 76; "Consular reports" 108 total; "A
per-family case-insensitive control"); `rounds/round2/threads/R5-1970s-institutions.md:64`
("`"reorganization plan no ii"` matches **0 documents** … `"reorganization plan no 2"` **20 documents in
6 volumes**"); the Roman-numeral zero at `rounds/round1/memo.md:155,547,686` (check-M3's corrected
citation; the miner's `:24` says only that a numbered plan is absent from headings).

### §14.5 — the actor test, and the letterhead decoy the concentration test passes (must; M2-R3 amended, M3-4 kept with amendments)

**Lines.** §14.5:1136–1167.

**Guide now.** The concentration test and a worked list of names and abstractions (`Herter`, `Director
General`, `examination`, `cone`, `Davies`, `Vincent`). `actor`, `nationality`, `letterhead`, `proper
noun`, `office name` → 0 hits. The only trace of the letterhead defect is §14.12:1373–1376's anecdote
about a 47% correction.

**Change.** Two appended passages.

> **The concentration test has a blind spot: a term can be dense in the right volumes and still name
> the wrong actor.** Institutional titles are shared across governments and across decades — every
> embassy has a commercial attaché, every trade ministry a department of commerce. So run a second
> test on any office, title or institution the question supplies: **the actor test** — draw a seeded
> sample of at least 100 (or the whole set under ~1,500; a 30-document read gave 10% foreign where
> the full pass gave 17%), read the qualifying adjective or possessor before the term, and report the
> split *U.S. / named foreign / unmarked*. Report it even when it does not overturn the count. Three
> shapes, each measured on this corpus: (1) titles every government uses — attaché, counselor,
> commissioner, commercial section (`commercial counselor` cleared the concentration test and was 72%
> other governments' officers; `trade mission` 73% foreign delegations, and one Tibetan mission put a
> volume at rank 16 of 550); (2) institutions that exist in several countries and predate the U.S.
> one — `Department of Commerce` before 1903 and `Tariff Commission` before 1916 are foreign ministries
> and commissions; (3) one name, two men or two offices — `Julius Klein` ("Dr." of Commerce and
> "General" of the Jewish War Veterans), `Governor Herter` 42% before the office the row was labelled
> with. Put the question's own list in the house-rules block you paste: the one such line one run
> carried ("'commercial agent' was a consular rank in the 19th century … titles are false friends until
> tested") was handled correctly by every one of eight reports that met the term.
>
> **A decoy the concentration test passes: the subject's own letterhead.** When a phrase is also the
> name of an office, a committee or a division, its hits include every document that office signed —
> on-topic by concentration, and not a use of the phrase. Measured: `"commercial policy"` lifts 3.17×
> over its on-topic volumes against a control's 0.75× and passes this test outright; read, **246 of
> its 1,265 documents carry the phrase only as the *Division of Commercial Policy*'s letterhead**, and
> because that Division existed in the 1940s, the unsplit count put the family's peak in the wrong
> decade. `"economic foreign policy"` is a proper noun in **64 of 112** (the Executive Committee on
> Economic Foreign Policy); `"trade policy"` attaches an office name in 242 of 1,422, and 194 have no
> other use. The 47% headline correction in §14.12 was the same defect, found once before.
> **Rule: before publishing a count for any phrase that is also an institution's name, split it into
> analytic use and proper-noun use, and publish both.** The split is a regex for the office forms
> (*Division of …*, *Office of …*, *Committee on …*) over the sample §7.1's literal-share protocol
> already draws, with a third bucket for documents carrying only the office form — and the office
> forms are themselves a succession with date spans (*Division of Commercial Policy and Agreements*
> 1941–45, 83 documents; *Division of Commercial Policy* 1944–50, 130; *… and Trade Agreements* 1), so
> enumerate the successors. A decade rate computed on the unsplit family is not comparable with one
> computed on the split.

**Evidence.** Actor test: `agents/refute-A4-sql-history/verdict.md:43–46,54,94,157–158` ("**foreign 205
(72%)**"; "roughly half foreign, plus the Federal Trade Commission"; "before 1903 is foreign ministries";
"**foreign 176 (17%)** … the 30-document random read gave 27 American");
`agents/refute-A2-tei-institutions-history/verdict.md:55–66,69,95` (ratio 7.89, the Tibetan Trade
Mission, "rank 16 of 550"; "`commercial section` is ~80% foreign ministries"; the Treasury's Bureau of
Statistics); `agents/refute-A5-subjects-history/verdict.md:42–46` (Prussian, Venezuelan, Swiss pre-1903;
the Dominican comptroller "styled 'commercial attaché'"); `agents/refute-T3-citations/verdict.md:29`
("three are a different Julius Klein"); `agents/refute-T5-method/verdict.md:148` ("**70 of 165 (42%)
predate the office**"); `agents/refute-T1-method/verdict.md:283–287` ("**133 are unmarked** … tested two
documents, declared them exceptions"); `S1:238` (the pre-warning) and `grep -l 'consular rank'
refute-*/verdict.md` = 8 files (check-M2). Letterhead: `rounds/round2/threads/R2-commercial-policy.md:47–51,72–77,130–140,264–270`
("246 of the 1,265 documents (19.4%) contain no analytic use of the phrase at all"; "**57% of it is a
proper noun**"; "Tier-1 **533 of 40,793** … vs corpus **1,265 of 306,619** … **lift 3.17×**"; "the largest
single correction in this thread"), `:73` ("*Division of Commercial Policy* 214 is three successive
offices, not one … 83 + 130 + 1" — check-M3's addition); `rounds/round2/critic.md:172–177` (`"trade
policy"` 242 / 194 / "not comparable"); `agents2/refute-R2-commercial-policy-method/verdict.md:79–80`
(blind re-implementation: "office-name **311**, analytic **998**, office-name-only **263**"). The
nine-term list the miner proposed is cut to the three shapes on check-M2's reasoning — "A guide cannot
enumerate every question's false friends; it can state the shapes", and the measured lesson of the
`commercial agent` line is that a per-run prompt line works.

**Would have prevented.** A2's whole institutional-score ranking; A4's "corpus's own words" list; T3's
declared-clean `julius klein`; T5's `governor herter` row; the round-1 "1940s peak" inference (jointly
with §6.4); the memo's non-comparable `"trade policy"` rates.

### §14.6 — statutes cite by date, public-law number or *Stat.* page; the counterpart's vocabulary; head an absence by what was tested (should; M2-R10 amended, M3-5 amended and shrunk)

**Lines.** §14.6:1169–1185; §12:962–963 (block, above).

**Guide now.** "**Rule: a negative measured with the target period's own vocabulary is evidence; a
negative measured with a later period's vocabulary is a tautology.** Before asserting the corpus lacks
coverage of something before year Y, scan terms contemporaries would have used." General; `statute`
appears once in a list; no citation forms; the rule reads as "earlier names for the same thing" (its
only worked case is `civil service reform`), and a run that had it pasted into every agent still
shipped two institution-shaped negatives.

**Change.** Append two paragraphs.

> The commonest instance is a statute. Eponyms are retrospective: on document text the *Rogers Act* is
> named in one historical document in 552 volumes (frus1977-80v28/d166, 1979), while its own decade
> wrote "the Rogers bill" (1923, ×3) and "the Act of May 24, 1924" (1927, ×2). The Foreign Service Act
> of 1946 enters document text in 1946 as "Public Law 724" and "60 Stat. 999", not under its title;
> the 1914 attaché appropriation is "(38 Stat. L. 500)" — and the *Stat.* form has its own variants
> (`"38 stat 500"` matches 0, `"38 stat l 500"` matches 1); the tariff of 1930 is "the tariff act of
> 1930" 218 times and "Hawley-Smoot" 38. Before publishing "the statute is not named", scan the
> act-of-date form, the public-law number, the *Stat.* citation and the bill name.
>
> Two forms of the same error bit a run that had the sentence above pasted into every agent. **The
> contemporaries' vocabulary for a relation is the counterpart's, not an older name for the office.**
> Over 39,800 documents dated before 1906 the Commerce field service's own nouns return almost nothing
> (`"commercial attache"` 1, `"trade commissioner"` 0) and the run published the era as institutionally
> silent; the same window returns `"commercial interests"` 338 documents, `"american merchants"` 321,
> `"chamber of commerce"` 227, `"board of trade"` 132 — consuls and ministers dealing with named
> merchants and chambers. Scan for the counterpart, the object and the transaction, not only for
> earlier names of the institution. And **head an absence by what was tested**: "FRUS does not print
> the United States and Foreign Commercial Service" was a true count of a post-1980 statutory name (0
> in 552 volumes) over a founding that is printed, as a description under the earlier name, in two
> 1979 documents the same memo had read and quoted — and the next pass re-discovered, then
> over-claimed, what the first had already found. "FRUS never uses the name X; the founding is printed
> at Y under name Z" is the finding. (Spelling of numbered instruments is §14.4: `No. II` is 0, `No. 2`
> is 20.)

**Evidence.** Statutes: `agents/refute-A3-tei-policy-numbers/verdict.md:18–21` ("**'Rogers Bill' ×3 in
frus1924v01/d560 (1923-10-16)** … **'the Act of May 24, 1924' ×2 in frus1927v02/d651**");
`agents/refute-A3-tei-policy-history/verdict.md:37–38,53` ("the anachronistic negative the guide §14.6
warns about"; "1930: 218" and Hawley-Smoot 38); `agents/refute-A2-tei-institutions-numbers/verdict.md:48`
("The house rule the report itself pastes in … was not applied to statutes");
`agents/refute-T2-method/verdict.md:93–103,219` (`"public law 724"` 3, `"60 stat 999"` 4,
frus1945-50Intel/d201 dated 1946-12-02, so "enters document text in 1948–49" is two years wrong);
`agents/refute-T3-citations/verdict.md:279` and `rounds/round2/audit-round1.md` N11 ("`"38 stat 500"`
matches 0 documents; `"38 stat l 500"` matches exactly one"); the Rogers Act count is check-M2's
corrected form — the miner's "twice, both after 1970" was unevidenced (`agents/refute-A7-came-from-history/verdict.md:175`
gives "**1 document** (frus1977-80v28/d166, 1979)"). Counterpart: `rounds/round2/threads/R9-private-counterpart.md:37–45`
("**A negative built from post-1906 institutional nouns is circular over a pre-1906 corpus.**");
`agents2/refute-R9-private-counterpart-method/verdict.md:280` ("obeyed, and strengthened");
`rounds/round1/memo.md:177` ("Both archival channels are structurally empty before 1906"). Head an
absence: `rounds/round1/memo.md:555,557,370` (A9's name test; A10's "Attached but not printed"; d119 read
and quoted as M62); `rounds/round2/threads/R5-1970s-institutions.md:41–49,63–64,732–736`;
`agents2/refute-R5-1970s-institutions-method/verdict.md:29–31,57–79` ("R1 (FATAL to the headline)
… false"; "R2 (FATAL to the headline) … `Attached but not printed.` [three times]");
`rounds/round2/memo.md:127–132` (the memo adopts the refuters). The 649-position quotation and the
two-paragraph institutional form the miner proposed are cut on check-M3's reasoning ("the guide's
register is one measured case per rule").

**Would have prevented.** A3's "named once … recorded only when a reorganization reaches the
Secretary"; T2's "enters document text in 1948–49"; round 1's "institutionally silent before 1906"
(the R9 thread and two refuters); the A9 heading R5 misread, and with it R5's refuted headline (two
refuters, one memo correction).

### §14.7 — "earliest" is a body-surface claim; a title is not an office; a direction is not a curve; and one existing sentence is wrong (must; M2-R5 amended, M4-R11 amended, check-M2 missed 3)

**Lines.** §14.7:1187–1210; the sentence at 1203.

**Guide now.** Two things: "**Volume year is not document date.**" (1189) and "**Apparatus is not
document text.**" (1196). At 1203: "All four `Rogers Act` hits in the entire corpus are footnote glosses
or index entries." Nothing ties apparatus to *earliest* claims; nothing on a title that changes
employer.

**Change.** (a) **Fix line 1203.** `frus1977-80v28/d166` is `is_front_matter = 0, is_editorial_note = 0`
and its `body_text` reads "this return to a post-Rogers Act" in Springsteen's own 1979 prose, followed
by the editors' gloss "The Foreign Service Act of 1924 (Ch. 182, 43 Stat. 140 …" — re-run 2026-09-04,
confirming check-M2's query. One of the four is document text. Reword to: "Three of the four `Rogers
Act` hits in the corpus are footnote glosses or index entries; the fourth is a 1979 memorandum's own
prose." (The FTS `"rogers act"` MATCH returns 8 on the working scope; 7 of those are `Rogers, Acting` —
§7.1.)

(b) After the apparatus paragraph, before "Until you scope hits…":

> **Two consequences for dates.** An *earliest occurrence* or *first appearance* claim is a
> body-surface claim: editors gloss institutions by their later names, so on `body_text` a term
> routinely appears before its referent exists — "Foreign Service officer" in a 1922 document (a
> footnote, two years before the Rogers Act); "Uruguay Round" in 1985 (a footnote, a year before the
> round opened, whose own text says "began in September 1986"); "Bureau of Foreign and Domestic
> Commerce" in a 1910 document (an editors' parenthetical; the bureau dates from 1912). Verify every
> *earliest* on the TEI with `<note>` stripped, or label it "earliest on `body_text`, footnotes
> included". Measured footnote-only shares for institutional families on this corpus run 10–46% of the
> FTS document count (`office of international trade` 45.8%; `Foreign Agricultural Service` 34.4%;
> `commercial attaché` 11.9%). And an editorial note's `date_iso` is the opening of the span it
> narrates (§4.3).

(c) After line 1210:

> **A title is not an office.** When a post moves between departments by statute, the same words name
> two employers either side of the date — *commercial attaché* is the Department of Commerce's officer
> before 1 July 1939 (Reorganization Plan No. II) and the Foreign Service's after. Split the family at
> the date and publish both halves; the undivided decade table read "its peak is after 1939" where
> the single peak year, 1936, sits inside the earlier employer's life (632 / 417 across the date, 89
> volumes each side). And when two censuses of one institution run opposite ways — 21 documents as
> *author*, 123 as *subject* — publish the base beside each direction: a direction on 21 documents
> describes 21 documents, not a curve.

Plus the one-sentence cross-reference to §6.4's four traps (above).

**Evidence.** (a) as stated; `agents/refute-A2-tei-institutions-numbers/verdict.md:32` ("Rogers Act 2 in +
2 out"); `agents/refute-A3-tei-policy-history/verdict.md:23` ("Rogers Act body + footnote at d166").
(b) `agents/refute-T5-citations/verdict.md:69–71` ("Four 'earliest' entries in the dated chronology are
editorial footnotes, not documents … d248's own footnote says in words '**The Uruguay Round … began in
September 1986**'"); `agents/refute-A5-subjects-history/verdict.md:38–39,52` ("A 'first appearance' cited
as document evidence is an editorial interpolation"; FAS 11 of 32); `agents/refute-A2-tei-institutions-history/verdict.md:133–141`
("the earliest 'Foreign Service officer' (1922-03-25, frus1926v02/d454) is an editors' footnote");
`agents/refute-A4-sql-history/verdict.md:101–107` (10–46%; 45.8%); `agents/refute-A6-semantic-history/verdict.md:139`
("**122 of 1,024 documents (11.9%)** carry the term only in a footnote"). (c) `rounds/round3/threads/C2-number-corrections.md:289–316`
("**A. before 1939-07-01** — Commerce's officer | **632** | 89 … **B. on/after** … **417** | 89"; "the
single peak year is **1936**"; "**Any statement about 'the commercial attaché' that spans 1939 without
saying which employer it means is ambiguous by construction**"), `:213,270–272` ("the authorship
census's **base is 21 documents** … it is not a curve"); `rounds/round2/critic.md:143–160`;
`rounds/round3/memo.md` §3.2:561 (republished split), §7.2 items 10–11; `rounds/round3/score.md` #23–24
(both splits re-derived "identical, including both spans").

**Would have prevented.** T5's four "earliest" chronology rows; A5's BFDC "first in 1910"; A2's 1910s
cells; memo v2's "its peak is after 1939" (false on its own decade row) and "more visible as an author
after abolition than during its life" (a 21-document base); and the guide contradicting its own record
at 1203.

### §14.10 — the map: a label test tests labelling; the profiles artifact is floored at both ends (should / could; M5-R5 amended, M5-R8 kept)

**Lines.** §14.10:1268–1283.

**Guide now.** The profiles paragraph ("380 subjects in 13 categories … ranking all 552 volumes by that
subject's weight recovered the entire relevant volume family unprompted") implies any subject is
rankable. The map table's second row: "Foreign Service reform | **0** of 179 (controls pass …) | An
institution is not a region of the semantic space. Vectors will not rescue the question." Then "The
map's twenty largest clusters are, without exception, places and crises."

**Change.** (a) After the profiles paragraph: "The profiles vocabulary is 380 of the 491 document-level
tags, and it is floored at both ends by the generator's own parameters (`GENERICITY_THRESHOLD` 0.10,
`MIN_DOC_COUNT` 2, `TOP_N` 15): a subject tagging more than 10% of tagged documents is dropped as
generic (*Trade relations*, df 29,433 of 238,302 = 12.35%), and a subject that never places two
documents in one volume's top 15 never appears (*Consular service*, df 237; *Joint Commercial
Commission*, df 28). A subject's absence from the profiles is by construction; rank it from
`document_subject_refs` instead. Sum named subjects, never a subcategory — *Trade and Commercial
Policy/Agreements* has 17 members, eight of them prices, wages and credit."

(b) A third table row, leaving the Foreign Service row's measured verdict as it is: "Commercial
diplomacy, 1930s | label test: **1** of 179 (controls pass). Cluster-purity harvest: 4 clusters at
25–59% RTAA-stratum share held 1,030 non-stratum documents, 776 of 1,030 (75.3%) commercial by the
editors' own headings after a refuter fixed an unanchored `tin` (it matched *PanamaContinued*), 284 of
849 unreachable by all twenty of the project's phrase families; corpus-wide they sized a third
editorial stratum of 1,228 documents, 878 outside every prior stratum | A label test is a test of
labelling. When a subject is filed by counterpart, the map labels by counterpart (cluster 92 is 59%
reciprocal-trade documents and its label is `chalkley · australian · australia · sydney`)."

(c) After the table's paragraph: "A 0-of-179 label test rules out a *labelled* region, not the map.
Before closing the route, harvest the clusters where a heading-defined stratum concentrates (≥25%
purity) and triage the non-stratum members by the editors' headings — and budget one in four for
geographic contamination. Read the corpus's own partition before choosing a memo's organising axis:
one memo had no geography while the corpus's own instruments (`611.xx31` came-from keys, the map's
neighbourhoods) are organised by counterpart."

**Evidence.** Profiles: `agents/A5-subjects/report.md:8,81` ("**Three of the sixteen subjects … cannot be
ranked from the profiles artifact at all**, by construction"; the 17-member subcategory);
`agents/refute-A5-subjects-numbers/verdict.md:40` and its `commands.log:681–687` (the per-volume floor
test, `check12_floor.py`); the generator parameters from `CLAUDE.md`
(VolumeSubjectProfilesGenerator). Map: `agents/A6-semantic/report.md:45` ("matched **4 of 179
clusters**"); `rounds/round2/critic.md:73` ("**exactly one**"); `rounds/round3/threads/D3-map-harvest.md:375–381`
("**The map is not empty of commerce documents; it is empty of a commerce *label*.** … *guaranteed* to
be labelled by counterpart"), `:66` (cluster 92, 214/363 = 59.0%), `:93–94,113–114`;
`agents3/refute-D3-map-harvest-method/verdict.md:47,118,133` ("`tin` matches 'PanamaContinued'. 90 of
the 685"; "The defensible figure is **284 of 849**, not 526"); `rounds/round3/memo.md:2753` ("Corrected:
776 of 1,030 (75.3%) commercial"), `:178–190` (1,228 / 878); `rounds/round2/critic.md:320–335` (the
missing geography axis — check-M3 missed 8). The brief this document was commissioned under said the
map found "685 documents unreachable"; the files say 685 was a heading count before refutation and 284
of 849 the defensible figure (M5 §1, verified by check-M5).

**Would have prevented.** Under §14.10 as written the round-2 critic's "no commerce cluster" closes the
route; the round-3 brief opened it on the orchestrator's initiative ("A MODALITY NEITHER ROUND HAS
OPENED", `S3:296`) and it produced the memo's largest new body. A5 spent part of its errand
rediscovering the floors from the generator's provenance.

### §14.11 — the archival stack: eight changes

**Lines.** §14.11:1287–1367; the table rows at 1308–1315; the rules at 1321–1341; 1349; 1355–1358.

**(a) Every artifact is a projection; a bundled negative is a projection negative (should; M4-R7 and
M5-R1, amended — and the one place two checkers disagree).** check-M4: "Putting a `~/Development/…`
path into the §12 block — a pasted instrument measured at 110 lines — is out of place twice over … No
change to §12." check-M5: "The path and the 22-RG list belong in the §12 house-rules block as an
optional stanza — the block is what every agent actually receives, and all three scripts already
pasted the RG list there." My resolution: check-M5 is right that the block is what the agent sees and
that a rule which never reaches it is not a rule (the C1 agent found the harvest *unprompted* after
three briefs named it only as a coverage list — `S1:222`, `S2:185–190`, `S3:125–127`); check-M4 is right
that an owner's home directory has no place in a public guide (the guide names no developer-tree
path anywhere — `grep '/Users/jbotts' GUIDE` → 0). So the block gains **one conditional line** (§12
table above) and no path; the path and record-group list stay in the per-run RESOURCES text the
orchestrator appends, which is where all three scripts put the list; and the guide body carries the
portable fact. Body text, after 1301 (prose, not the block):

> Every artifact in this table is a projection of NARA's catalogue, and a negative in the bundle is a
> negative in the projection. In one run a record group returned 0 hits in eight bundled artifacts
> and resolved to 232 series, all Unrestricted, from the record-group harvest the artifacts are built
> from — and two fields the projection drops, `recordsCenterTransferNumbers` (the FRC accession a
> series was retired under; 240,929 occurrences in the RG 59 shard) and NARA's wider
> `coverageStartDate/EndDate` (`series-facts-index.json` carries only the inclusive pair as `y0`/`y1`),
> decided four of that run's five archival corrections. When a record group is in the harvest's
> coverage list and the bundle has nothing, that is a projection gap, not a structural limit: say
> which, check NARA's catalogue for the field, and read a series' own entry number rather than
> assuming a record group sits under one finding aid (197 of those 232 carried PI-100; 35 carried
> another). The harvest is an owner-local store described in
> `Planning/nara-record-group-catalog-runbook.md`; its depth is uneven (RG 256 has a 178 MB shard, RG 429
> none; RG 182 has no file units described); counts from it are labelled [HARVEST], carry the snapshot
> date (2026-04-09 against bundle stamps 2026-08-09 to 2026-08-28), and are never summed with bundled
> counts.

Rewrite 1349 ("the project's own harvest already covers RG 169 and RG 182") to point at that paragraph.
*Evidence:* `rounds/round3/threads/C1-archival-corrections.md:19–30` ("There is a fourth on this machine,
and every one of the five errands turned on it … the projection drops fields"; the two-field table),
errand 4:282–290 ("**0 NAID hits in every one** … The gap is **in the projection, not in the archive**
… 232 series, every one at series level, every one `Unrestricted`"); `agents3/corr-C1-archival-corrections/queries.log:9–15,65`
("[HARVEST] … A FOURTH surface, not named in the brief"; "Scanned rg_59.json (3.56 GB)");
`agents3/refute-C1-archival-corrections/verdict.md:24–26` ("**28 of 31 independently re-derived figures
matched to the digit**"); `rounds/round3/critic.md` §5.1 ("197 of 232 carry PI-100 and 35 carry another");
`:246–248` (240,929); `rounds/round3/memo.md:75–77,3109`; repo: `LotClaimantsIndexGeneratorCore/HarvestShardReader.swift:129`
(CodingKeys `variantControlNumbers, inclusiveStartDate, inclusiveEndDate, ancestors` — no coverage,
no transfer numbers), `RecordGroupCatalogGeneratorCore/RecordProjector.swift:152,160` (both fields
projected into the shards) — paths corrected by check-M4 (the miners' `Sources/` prefix is spurious).
*Would have prevented:* RG 182 published as a structural limit in memo v2 and the round-3 brief; the
1917 export-control errand carrying its five series a round earlier.

**(b) The date-span screen as rule 3 (must; M4-R4 and M5-R4 — check-M6 C19: "one wording, owned
there").** Cell 1311: "the pre-travel facts: creator, extent, **inclusive** date span (NARA's wider
*coverage* span is not projected — rule 3 below), access status, facility". After 1335:

> **A resolution is a candidate until it survives the date-span screen.** Join the citing documents'
> `document_dates.date_iso` to the series' span and test overlap — corpus-wide, never on your own
> volume subset (a lot's shelf is a property of the lot: `72 D 318` failed on one document and passed
> on seven, and one round's "7 of 93" against its critic's "6 of 93" was an undeclared denominator);
> against the wider of NARA's two spans (`series-facts` carries only the inclusive pair; of 75 RG 59
> series checked, 19 publish both fields, 17 differ, and coverage starts earlier in all 17; the
> inclusive field alone produced three false failures over 44 documents — the corpus-wide result is 3
> of 93, not 7 and not 6); reading the citing source note before accepting one of several claimants
> (`73 D 153`: nine of ten notes say *Morning Summaries*; the index had picked *Special Summaries*);
> and diagnosing a survivor rather than deleting it — ask whether the FRUS string is a lot number at
> all (the candidate rule below). A one-year overhang at an accession boundary is the shape of a
> correct resolution; a twelve-year gap into another subject is not; report the gap in years. Screen
> any replacement you offer by the same test — a substitute that fails the screen that condemned the
> original is the case the rule exists for. Run the resolved set the other way too: NARA consolidates
> as readily as it divides (11 of 81 resolved NAIDs on one scope were claimed by two or more lots — 23
> lots, 294 documents), one series answering two lot citations is one order and not two (`63 D 351`
> and `66 D 95`, 112 documents, are one series, RG 59 entry A1 1586E), and a convergence whose lots
> all fail the screen is the same wrong answer returned twice — the second claimant corroborates the
> error, not the shelf. Write the reference query against the NAID, not the lot list.

Cell 1312: "when a lot has several correct NARA answers, which — and, run the other way over your
resolved set, which NAIDs several lots converge on". *Evidence:* `rounds/round3/threads/C1-archival-corrections.md:47–73`
("(a) The 7-versus-6 discrepancy is a denominator, and neither document says so … (b) The screen was
reading the narrower of two NARA date fields … The screen was manufacturing failures");
`agents3/corr-C1-archival-corrections/queries.log:31–60` (Q2 "7 FAIL"; Q3 "6 FAIL, not 7. 72D318 CLEARS";
Q5 "3 of 93 fail, not 7 and not 6 … CLEARED by the wider field: 68D349 (28 docs), 68D358 (11), 75D229
(5)"), Q8 (`73 D 153`), Q19 ("81 distinct NAIDs among the 93 resolved lots; 11 claimed by 2+ lots; 23
lots; 294 documents. Re-screened: 10 of the 11 pass … The one failure is 619592, and it fails for both
its lots"); `agents3/refute-C1-archival-corrections/verdict.md:101–116` (P2, replacements fail the same
screen), row 9 ("19 publish both, 17 differ, coverage starts earlier in 17/17" — the refuter's count,
which check-M5 prefers to the miner's "17 of 75 publish both"); `rounds/round2/critic.md:388,253`
("6 of 93"; "Defect C — many-lots-to-one-series is undisclosed"); `rounds/round2/memo.md:2957` ("7 of
93"); `rounds/round3/memo.md:2118–2146`. *Would have prevented:* three "DO NOT ORDER ON THIS ROW" flags
on 44 documents; the 7-vs-6 dispute; two reference letters for one series; C1's own replacements
offered unscreened.

**(c) A folded control-number match is a candidate (must; M4-R5 amended).** Cell 1309, append: "— as a
**candidate**. The key is a folded control number, and a match is an identity claim only when both
sides mean a lot by it: a Federal Records Center accession (`65 A 987`) and a file label fold the same
way and are not lots. Two cheap screens before the date-span rule: does the series' extent hold the
box FRUS cites (five inches cannot hold a Box 104), and does its title fit the document type (an
undivided lot has one answer, which is unchallenged, not confirmed — `72 D 192` resolves to a series
titled *Speeches and Statements*)." *Evidence:* C1 errand 1(c) ("NAID **2945755 carries `65A987` as a
`variantControlNumber` and has NO records-center transfer number at all** … the string is a *file
label*, not an accession … A control-number match is an identity claim only when both sides mean the
same kind of object by it"); `rounds/round2/memo.md:1661,1703–1711` ("**DO NOT ORDER ON THIS ROW**"; "A
folded-control-number collision resolved an accession string onto a five-inch aviation series");
`rounds/round3/threads/D4-ecefp.md:778–782` ("5 linear inches spanning 1938–1944 … physically incapable
of containing a Box 104. The control number matched; the series is wrong"); `rounds/round3/critic.md`
§0a item 10 / §4 (`72 D 192`) — the extent and title screens are check-M4's fold ("the cheapest
screen in the whole episode and the miner left it out"). *Would have prevented:* a shelf published in
memo v2 for 21 documents; a wrong entry number for `73 D 153` (A1 5185 for A1 5184).

**(d) The reference query is the deliverable, and the FRC accession is its lever (should; M4-R8, half
length).** After 1359 (the last line of that paragraph):

> The answer takes the form of a reference query a researcher can send unchanged: what is known (the
> citation as FRUS prints it, box and folder), what is inferred (the nearest resolved neighbours and
> where they stop), what is asked (entry number, whether the folders survive, access status). Two
> levers reach past the bundled indexes. The editors' front matter often names the Federal Records
> Center accession a lot was retired under (`volume_sources`: "…now part of Washington National
> Records Center Accession No. 71 A 6682 (15 ft.)"), and NARA records the same accession, with item
> numbers, on the series it became — an accession is a join key the lot number is not, so cite
> NARA's own item numbers where its catalogue has them (`059-71A6682-9`, `-29`, `-31`, `-33`). And a lot
> NARA does not index at all is asked for by the editors' description — office, function, span,
> feet — which are handles NARA does hold. Say which units the lever does not reach: a lot named
> only inside a document's text has no accession statement to send.

*Evidence:* C1 errand 5:367–387 ("`71A6682` **42 times, all in `recordsCenterTransferNumbers`, across 39
RG 59 series** … the editors call the sugar files **item 79** … NARA records `059-71A6682` on **NAID
27022874**"), errand 2:219–221 ("four independent handles and the lot number is the one NARA does not
hold"); `agents3/corr-C1-archival-corrections/queries.log` Q12–Q15 (incl. "POSITIVE CONTROL: same
query shape for '60 D 137' -> 20 rows. The zero is real"); `agents3/refute-C1-archival-corrections/verdict.md:221–225,279`
(NARA's item numbers); `rounds/round3/score.md` A5 row; `rounds/round3/memo.md` §8.1 errand 1. *Would
have prevented:* `60 D 137` — 131 documents in 25 volumes — carried "pending a better index pass"
through two rounds ("Stop treating 60 D 137 as pending a better index pass; it is not there. Write
the letter" — `C1-archival-corrections.md:218`).

**(e) `decimal-class-labels.json` — a caveat that retires when the artifact is fixed (must until then;
M4-R10 and M5-R2(c)/R3, amended).** Cell 1315, append: "**ONE schedule, 1910–49**, and the artifact's
provenance says a key resolves only against its own era: run a post-1950 key through it and you get a
plausible WRONG gloss (`411` = *Claims*; `48` = *British Africa* where the editors gloss `411.48` as
Poland), not a miss — gloss 1950–63 keys from `volume_sources` (§4.4). And its 1910–49 country table is
wrong or empty on codes FRUS files commerce under (build of 2026-08-11): `60f` = *Ruthenia* (FRUS:
Czechoslovakia, 82 documents on `611.60F31`), `47h` = *Cook Islands* (New Zealand, 27); `42` Canada,
`43` Newfoundland, `54` Switzerland, `74` Bulgaria, `11b` Philippines absent — 233 documents
unnameable, 109 named wrong. Keys are lowercase (`60f`; `document_sources` carries `60F`). A gloss table
that answers wrongly is worse than one that fails: before publishing a country name from any bundled
table, read one document header filed under the key. [Repo issue: the country table.]" *Evidence:*
`rounds/round3/threads/D5-geography.md:175–193` ("**The bundled country table is wrong, and it is wrong
the expensive way** … a reader who trusted it would report an 82-document Ruthenian trade file that
does not exist"); `rounds/round3/memo.md:3307–3314` (W16), `:2764` (§7.3 item 20: "**233 documents
unnameable, 109 named wrong**"), `:2028–2050`; `rounds/round3/score.md:96` ("**identical**, every
lookup"); `agents3/refute-D3-map-harvest-method/verdict.md:240` (a gloss "attributed to an artifact
that does not carry it"); `rounds/round2/threads/R8-archival-deepening.md:71–81`; check-M5 read the
shipped file: 198 countries, `60f` Ruthenia, `47h` Cook Islands, `42/43/54/74/11b` → None; the
provenance string ("The classification was RENUMBERED in 1950 … a key resolves only against the
schedule governing its own era"). The miner's §5 placement is dropped (the guide never introduces the
artifact in §5).

**(f) `series-facts-index.json`'s unlabelled wire keys (should; checker-surfaced, check-M5 missed 2).**
Same cell 1311, append: "Its `byNaId` entries use one-letter wire keys with no legend — `as` →
`statuses`, `ar` → `restrictions`, `us` → `statuses`, `ru` → `useRestrictions`, `c` → `headings`, `x`
extent, `fa` finding-aid type, `y0`/`y1` the inclusive span — over five separate vocabularies
(`statuses`, `restrictions`, `useRestrictions`, `findingAidTypes`, `headings`). Reading `as` through
`restrictions` reproduces a plausible wrong value on every row." *Evidence:* `rounds/round3/memo.md:3110`;
check-M5 verified the keys and the five vocabularies in the shipped file.

**(g) `resolved-edge-index.json` has no row and two measured reading traps (could; checker-surfaced,
check-M5 missed 4).** Add a table row: "`resolved-edge-index.json` | the inbound half of the citation
graph for volumes you have not downloaded (§6.6) | 8,628 cross-volume edges into 5,740 documents from
184 volumes — its `volumes` array (235) is a shared vocabulary of target *and* citing volumes, not a
target list (distinct targets: 206), and its own footnote share is 7,622 of 8,628 = 88.3%, not the
corpus-wide 95.3%." *Evidence:* `rounds/round3/memo.md:2380–2386`; `rounds/round3/score.md:62` ("opened
for the first time in the project"); `S1:219` had named it; §6.6:592 mentions it without its filename.

**(h) A published NAID carries every claimant and its access status (could; checker-surfaced, check-M2
missed 5).** One sentence after rule 3: "A published resolution carries every claimant the
`lot-claimants` index lists for the lot and the series' access and FOIA status — seven lot rows in one
run suppressed a FOIA restriction the artifact carries, the field a researcher acts on." *Evidence:*
`agents/refute-A8-pointed-at-history/verdict.md:10,90` ("57 D 284 → NAID 1422076 RG 43 **with a second
claimant**"); `rounds/round2/audit-round1.md` N10 ("Seven lot rows suppress a FOIA restriction the
artifact carries"), N9; `agents/refute-T2-citations/verdict.md` MISSED 4 (lot 57F103 "never a record group
… It is **RG 84**").

### §14.12 — contesting many agents: dying agents, the canary, the budget, the second lens, three cheap checks

**Lines.** §14.12:1369–1392.

**Guide now.** Four "cheap practices": counting surface and denominator; controls; circular markers;
"**Give each parallel agent its own scratch directory.**" — the only multi-agent item. Retry, resume,
model, dead drafts, cost, the reading lens: nothing. `grep -i 'budget\|cost\|tokens'` → 178 and 1083 (`budget`: the context budget, and budgeting the scoping pass), 789 and 1100
(`tokens`, a counting surface), 1192 ("costs nothing extra") — none about money, sessions or an
agent budget [audited 2026-09-02; the earlier draft read "178, 182, 1083 only"].

**Change.** (a) Items 5–7 after item 4 (should; M1-R5 amended):

> 5. **Expect agents to die, and make the loss cheap.** In a ~200-session run a third of the first
>    round's sessions returned nothing (quota, rate limits, a per-call watchdog). Retry an empty
>    result once; have every agent write its log and partial results to disk as it goes, so a killed
>    session leaves a draft.
> 6. **A dead agent's draft is a claim, not a result.** Hand it to the successor with the instruction
>    to re-run the decisive queries, correct what is wrong, and say which numbers it re-derived. Keep
>    the dead attempt's query labels separate from the delivered ones.
> 7. **Prove the environment with one cheap agent before launching a fleet**, on the exact invocation
>    the prompts print, against a known answer. In one run a wrong shell flag and a hung model setting
>    each cost hours across a hundred agents and each was found by a ten-second canary. If your
>    harness resumes a run from cache, a finished agent's prompt is frozen: append a correction only
>    to the agents still to run, or every finished one runs again.

(b) After the list (should; M1-R6 amended to number-light — the load-bearing figures are in no file
under the run, so the guide carries what the run's files can corroborate and the §13 row makes the
next run's figures citable):

> Budget the adversarial layer as a peer of the threads, not an add-on. In the 2026-09 three-round
> run — about 200 agent sessions over roughly a day — 60 sessions were refuters and, by the harness's
> own accounting, they wrote about half of all output tokens; the item they caught most often was the
> wrong number. The same accounting put the whole loop near $2,800 at first-party API rates with 96%
> of input served from cache, which is why byte-stable prompts (item 7) are what make a repeated or
> resumed run affordable. Record your own figures under §13. Hand the refuter the query log, not only
> the report: 43 of 60 verdicts in that run cite `queries.log`, and the failures it found — a label
> that resolves to nothing, a disjunct the report omits — are visible only there.

(c) At 1372, after "told to find the wrong number" (could; M4-R12 cut to one sentence): "— or, when the
pass under review reads rather than counts, the misquotation and the inflated reading count (§8; §9
item 8): re-retrieve every quotation for its pair, check the claimed count against the raw text,
confirm every NAID against the artifact under the title given."

(d) Three cheap checks as items 8–10 (should; checker-surfaced — check-M2 missed 1, check-M3 missed 3,
and M3-1's rule 3 restated for a single run):

> 8. **Reconcile the report against its own tables before anyone else does.** Diff every figure that
>    appears twice, and every prose sentence against the table beneath it. In one round ten of
>    twenty-eight verdicts found a contradiction inside the report they were checking — a uniqueness
>    claim against a count printed three sections earlier, "18 volumes" over a list of 16, "none
>    between 1952 and 1958" over a table that listed four. It costs no query.
> 9. **Report the window beside any proximity-derived claim, and show the count at a second width.**
>    "1,037 never attach the phrase to the United States" rested on a 60 + 45-character window; at ±250
>    characters the set is 811 and "four fifths" is 64%. A window test supports "not attached within
>    ~105 characters"; it cannot support *never*.
> 10. **A republished number is re-derived or labelled "inherited, not re-derived"**, and a
>    correction re-derives the other figures in the same sentence: one fix pass "audited what the
>    reviewers pointed at and nothing adjacent to it", and the one fix-pass figure that failed was "a
>    figure added quickly to answer a reviewer, not re-derived".

**Evidence.** (a) `S1 .stalled:656/670/722/788–790/808` carry `model: 'opus'`, the final script none;
`attempts || 3` → `|| 2` at `S1:518`; `S1:670` `${['T1','T2'].includes(t.key) ? '' : TOOLING}` (the
per-key conditional that kept finished prompts byte-identical); `draftNote` `S1:622–632` ("A PARTIAL
DRAFT OF YOUR REPORT ALREADY EXISTS … It is unverified: treat every number in it as a claim to check,
not a result to copy"); `.stalled:641–642` ("interrupted by a quota limit"); `agents/thread-T3/queries.log:1–9`
(the agent applying the same discipline to its own killed attempt); the pin hang and the canary are
memory-note only (`env_workflow_agent_failure_modes.md`: "six attempts each, four hours, zero
output"; "found this in ten seconds after two long runs had silently worked around it") — which is why
the harness specifics go to a Planning runbook (stub below) and the guide keeps the portable rule.
(b) 60 verdict files — 28 + 18 + 14 `refute-*/verdict.md` under `agents`, `agents2`, `agents3`, counted 2026-09-02 (memo v3 §9 says "sixteen" for round 3 and "eighteen" for round 2 and gives no round-1 count; its sixteen is a miscount of the fourteen round-3 files); mtimes 2026-09-01
23:31 → 2026-09-02 22:57; `S2:130` ("corrections that cost an earlier run hours"); the dollar and
token figures are orchestrator-reported and appear in no file (`grep -rl '2,810\|2\.94 B\|2811'
rounds/ *.md` → nothing — check-M6 C12, check-M1 §3); `S2:559–560` and 43 of 60 verdicts citing the log
(check-M1 missed 6). (c) `S3:507`; the D1/D2/D5 verdicts under §8 and §9 item 8. (d)
`agents/refute-T6-citations/verdict.md:99` ("contradicts a count printed three sections earlier in the same
report"); `agents/refute-T5-method/verdict.md:236` ("a flat internal contradiction");
`agents/refute-T4-citations/verdict.md:62,262–264` ("'None between 1952 and 1958' is four. The report's
own §1.4 table lists them"; "both the right method and the wrong one, in the same document");
`rounds/round1/score.md` defect 3; `agents2/refute-R2-commercial-policy-method/verdict.md:187–210` (P4:
"The window test can support *'not attached within ~105 characters'*. It cannot support *never*");
`rounds/round2/audit-round1.md:387–391`.

**Would have prevented.** The stalled second launch (every agent hung) and the choice, made under time
pressure, of which prompts could be edited on the third; nothing in the run for (b) — but a reader of
§14.12 today is told to run a second agent adversarially with no idea it doubles the writing; T4's
1952–58, T6's Pan-American, T5's Plan No. 3 and score defect 3 for item 8; R2's "never attach" for
item 9; W3's three inherited framing figures and N4 for item 10.

### §15 — point at a validator, or carry the checks (could; M6-G6 kept)

**Lines.** §15.2:1451–1457.

**Guide now.** "**A `document` entry MUST carry both `volumeId` and `documentId`.** Omit either and the
file still opens … with no error at any point … treat it as a hard rule on your side. Nothing will
tell you." §15 carries no Python.

**Change.** After 1457, a 20-line Python block that checks: `format` / `formatVersion` / the six
composition keys; every `document` entry carries both ids; every pair exists in `document_cache`; no
Ed2 twin where its first edition is present; no duplicate pair; the `.fruscollection` extension. (If
a skill ships, the block becomes one line naming `validate_fruscollection.py`; the 20-line block is
the cheaper branch and loses nothing — check-M6 C21.)

**Evidence.** The run re-specified the same five checks in every collection prompt (`S1:758–767`;
`S3:626–633`: "Verify every pair exists in document_cache before writing and list any drops.
De-duplicate … Apply the Ed2 fold … Validate with python3 json.load"); the round-3 file passes all of
them today — 411 entries, 400 documents, 11 headings, 0 missing-id, 0 duplicate pairs, 0 Ed2, **400 of
400 pairs present in `document_cache`** (check-M6 §0, re-verified by query).

### Appendix A — calibrate distances against two baselines; era-dependent unclustering; the map's input width (should; M5-R6 amended materially, M5-R5(c)(d))

**Lines.** A.5:1613–1622; A.5:1665; A.8:1735,1745; the addendum:1760.

**Guide now.** A.5 prints the neighbour list ("hamming 87 frus1862/d130 …") and reads it as "what a
working index looks like"; nothing says what 87, or 130, means against chance. A.5:1665 and A.8:1745
give 28.0% unclustered as "a property of the corpus". A.8: "Clustering ran on the 2-D embedding, not
the 512-dim space" — true, and it invites the reading a refuter caught.

**Change.** (a) A.5, after the neighbour list — **not** the miner's "top 0.1–1% of random pairs"
framing, which is the sentence the run's own refuter called "wrong in kind and wrong in magnitude":

> Calibrate before reading any distance, against **two** baselines. Random pairs at this digest
> (20,000, `default_rng(1877)`): mean 193, sd 17, 1st percentile 152, minimum ~100 of 512 — the list
> above at 87–97 is far outside chance. But every nearest-neighbour list is a tail of that
> distribution by construction, so a neighbour at 126 is not "top 0.1%" evidence of a link: the
> corpus's median document has its 25th-nearest neighbour at 124, and one document whose nearest
> neighbour in the whole corpus sits at 126 is a semantic isolate. Judge a neighbour against the
> k-th-neighbour distribution and a set's cohesion against random pairs; a random 512-bit pattern has
> minimum 215 to the corpus. Recompute both after any regeneration.

(b) A.8, after "Similarity is a lead, not evidence": "Compare like statistics. A minimum-to-a-set is not
comparable to a mean over pairs; the matched control for 'candidates are closer to the stratum than
members are to each other' is min-to-nearest-member on both sides, and it inverted the published
sentence when run (88.3 for members, 123.5 for candidates)."

(c) A.5:1665 and A.8:1745: "The 28.0% is corpus-wide and strongly era-dependent — 46.7% of 1861–1899
documents are unclustered against 22.3% of 1945–1964 (working scope: apparatus excluded, Ed2 folded).
Compare any set's unclustered share to an era-matched baseline, never to 28%."

(d) A.8 map bullet: "the layout's input was the 256-dim cut (`layout.sourceDims`), not the shipped
512-bit sign block; map neighbours and Hamming neighbours are two measurements."

(e) Addendum line 1760, append: "— and say which baseline each distance is measured against
(random-pair mean 193 / sd 17, or the k-th-neighbour distribution) at the digest in use."

**Evidence.** `rounds/round2/threads/R1-instruction-genre.md:34–45` (the random-pair baseline);
`agents2/thread-R1-instruction-genre/queries.log:34–35` (Q4); `agents2/refute-R1-instruction-genre-method/verdict.md`
row 54 ("exact (p0.1 133 vs their 132 — percentile interpolation)") **and `:155–160`**, the paragraph
the miner did not carry: "**`frus1940v02/d424`'s nearest neighbour in the whole corpus (126) is farther
away than the median document's 25th-nearest neighbour (124).** It is a semantic isolate … rests on a
percentile framing that is both wrong in kind and wrong in magnitude: against 200,000 fresh random
pairs … a distance ≤126 occurs in **0.046%** of pairs"; `agents/A6-semantic/report.md:185–186` (random
pattern minimum 215, mean 259.9); `rounds/round1/critic.md:104–106` ("as one neighbourhood");
`rounds/round3/threads/D3-map-harvest.md:82–83` and `agents3/refute-D3-map-harvest-method/verdict.md:209–226`
("**the distance comparison is a minimum against a mean** … Under the matched statistic the claim
**inverts**: stratum members sit at 88.3 … candidates at 123.5"), `:271` (`sourceDims` 256 — check-M5
read the file: `layout.sourceDims` = 256, `unclusteredCount` = 88,207);
`agents/refute-A6-semantic-numbers/verdict.md:11–22` ("**1861–1899: 15,500 of 33,217 = 46.7%** …
1945–1964 | 21,812 of 98,028 = 22.3%").

**Would have prevented.** The round-1 critic's "one neighbourhood" reading, which set R1's errand;
D3's inverted sentence, carried as a memo correction; A6's wrong comparative sentence on four
19th-century sets.

### NEW §14.13 — Superlatives are claims over a scope (must; M2-R1 kept)

**Lines.** After §14.12 (1392). The miner numbered this §14.13 and M3-1 also claimed §14.13; the
single-run rule goes first.

**Guide now.** §9 item 7 is generic ("Ask what would falsify it"); `superlativ` → 0 hits; `earliest`
once, in a Python snippet.

**Change.**

> ### 14.13 Superlatives are claims over a scope
>
> *Only*, *first*, *earliest*, *last*, *none*, *never*, *anywhere in FRUS*, *no X other than Y* are the
> sentences round-1 verifiers of the 2026-09 run refuted most often — sixteen of twenty-eight
> verdicts, and in every case the counter-example was one query away. Three rules:
>
> 1. **Name the scope the word is true over.** "The only such heading in the 244 volumes scanned" is a
>    finding; "the only such heading in the series" written from the same scan is not.
> 2. **Run the falsifier over the unrestricted surface, not the working set.** A superlative
>    established from a filtered heading file, a hand-picked volume list, a lookup of named leads or a
>    `volume_id`-sorted hit list has not been tested. `ORDER BY date_iso` before any *earliest*;
>    `GROUP BY` before any *only*.
> 3. **Print the falsifying query beside the sentence**, with its result — including the zero.
>
> Measured: "all 24 dated 1961–63" (nine were 1964–67); "the earliest-dated document on this thread
> anywhere in FRUS", 1851 (an 1826 commercial treaty sat in the same appendix); "not described
> contemporaneously anywhere in the 550 volumes" (one telegram, frus1939v02/d617, described it); "no
> record group other than RG 59 on any document in the window" — 1,547 RG-256 documents.

**Evidence.** `agents/refute-T1-citations/verdict.md:29,47` ("**S13 is a 23-document lead lookup**";
"**1,547 documents dated in the window carry record group RG-256**"); `agents/refute-T4-citations/verdict.md:27,62`;
`agents/refute-T6-method/verdict.md:51,62,64` ("**`frus1894app2/d3` 1826-12-23** … a commercial treaty, in
the *same* Hawaii appendix"); `agents/refute-T2-citations/verdict.md:126,149` ("the scan covered **244 of
552 volumes**"); `agents/refute-T3-method/verdict.md:140`; `agents/refute-A2-tei-institutions-numbers/verdict.md:49`;
`agents/refute-A8-pointed-at-numbers/verdict.md:84–85` (RG 364 has a NAID in `volume-sources-index.json`);
`agents/refute-T3-citations/verdict.md:371` ("**A test of its own superlatives.**"); `rounds/round1/score.md`
defect 2 ("**exactly one** series begins before 1928"); `rounds/round2/audit-round1.md` W1 ("The
**superlative** was never tested"), N8.

**Would have prevented.** T4's Dillon Round date claim; T6's "earliest anywhere in FRUS" and "longest";
T2's "first time the series prints"; T3's "last operational appearance"; A2/A5's "not described
anywhere"; A8's "no footnote"; memo defect 2; audit N8 — none altered a thesis, each is the kind of
sentence a reader quotes.

### NEW §14.14 — Revising a prior round (must; M3-1 amended)

**Lines.** After §14.13.

**Guide now.** Nothing multi-round. `prior round`, `earlier pass`, `decisive`, `both sides` (in this
sense), `correction table`, `adjacent` → nothing in this sense (`decisive` and `adjacent` each occur once in another: §14.5:1138 "a cheap, decisive test", A.5:1657 "the adjacent Civil War" volumes); §9 item 5 and §14.12 are single-run; §13 records one
run.

**Change.**

> ### 14.14 Revising a prior round
>
> When a second pass claims to correct a first — "round 1 never read X", "round 1's figure was Y",
> "this family was counted nowhere" — the claim about the prior round is itself a measurement, and in
> one three-round investigation it failed more often than the arithmetic did: the refuters found every
> thread's numbers reproducing exactly and its change-claims failing in five of nine, and the memo's
> own §4 opened with "round 1 mentions this institution zero times" when the prior memo mentioned it
> five times and published the same counts.
>
> 1. **A claim about what a prior round said is a grep over its final files, and the command is
>    shown.** "Round N never names X" is `grep -c` over round N's memo, scope and thread reports with
>    the count; "round N never read X" is a search of round N's quotation-verification log. Grep the
>    files as they stand *after* round N's fix pass: the false "zero times" above was copied from
>    round 1's own critic, which had been right before the fix pass added the row. A reviewer's
>    description of a round is a claim to verify, not a source. The true claim is usually narrower
>    ("the memo did not; the thread report did") — publish that one.
> 2. **Every changed finding goes in a four-column table** — *claim as published · corrected value ·
>    decisive query · which side the re-run supported* — including rows where the re-run supported the
>    original and rows where it supported neither. The scorer that caught the round-2 failures found
>    that all three were claims that had escaped the table.
> 3. **A fix pass re-derives what is adjacent to the correction, not only what the reviewer pointed
>    at.** Measured: one section's re-derived number was exact and its three inherited neighbours were
>    all wrong, and the one fix-pass figure that failed was "a figure added quickly to answer a
>    reviewer, not re-derived".
> 4. **Every open thread the prior round listed is answered, carried, or dropped with a reason.** Two
>    of twenty-five were dropped silently in one round, both bodies the investigation had already
>    sized.
>
> The rubric item that enforces 1 and 2: *every claim that round N+1 changed a round-N finding is
> backed by the decisive query on both sides.* Round 2 of that investigation failed it; round 3, with
> 48 table rows, did not.

**Block.** §12, REPORTING, after 939 (in the table above).

**Evidence.** `agents2/refute-R5-1970s-institutions-citations/verdict.md:24–42` ("'two documents round 1
lists by date and never reads' is false … Round 1 read d119, quoted **the same sentence** R5 presents as
its discovery, logged the read as M62"); `agents2/refute-R5-1970s-institutions-method/verdict.md:29–31,76–79`;
`agents2/refute-R6-1930s-instruments-method/verdict.md:209–212,221–223` ("**Six of the eleven family sizes R6
presents as its change are verbatim re-derivations of round-1 figures**"; "rebuts a claim that was not
made"); `agents2/refute-R2-commercial-policy-method/verdict.md:6–10` ("the ECEFP 'discovery' is a round-1
number republished"); `agents2/refute-R9-private-counterpart-method/verdict.md:282` ("mixed");
`rounds/round2/score.md:45,150,170–171` (P2 violated; "the three violations above are all cases of a
claim escaping that table"); `rounds/round2/memo.md:2115–2116,2158,1428–1434` (the table; "including the
four where it supported this memo and the two where it supported neither side"; V38);
`rounds/round1/critic.md:238` (item 12, "zero mentions in round 1", written before the fix pass added
M81 at `rounds/round1/memo.md:710` — check-M3's mechanism); `rounds/round2/critic.md:182–196` ("Two were
dropped silently"); `rounds/round2/audit-round1.md:387–391`; `S2:554,683–684` (the refuter lens and P2);
`rounds/round3/score.md:31` (P2 obeyed: "§7.2 (25 rows) and §7.3 (23 rows) each carry a *decided by*
column").

**Would have prevented.** P2 (one of three round-2 rubric failures) and the false §4.7 sentence; three
of nine R5 change rows, three of eight R6 rows, the R2 ECEFP "discovery", the R9 "21 documents" — every
one a refuter's finding that consumed adversarial output to correct a claim a grep would have
prevented; two silently dropped threads.

### NEW §14.15 — Ask a critic when to stop, and make it show its work (should; M3-6 amended and cut)

**Lines.** After §14.14. The seven-item brief goes beside §12 as a pasteable block (or in the workflow
runbook), not in §14 — the guide's convention for prompts.

**Guide now.** §14.12 is the refuter only ("a second agent given the first's results and told to find
the wrong number"); `critic` (this sense), `diminishing`, `when to stop`, `CONTINUE`/`STOP` → nothing as a verdict (`stop` occurs eleven times as a verb, `continue` once in a Python loop).

**Change.**

> ### 14.15 Ask a critic when to stop, and make it show its work
>
> The adversarial pass in §14.12 finds the wrong number. It does not find the missing modality, the
> key document named and never read, the era's own vocabulary nobody scanned, or the point at which
> another round would confirm arithmetic rather than learn anything. One agent per round can, if its
> brief asks for a verdict: a critic asked only for "open threads" returned fifteen every time and no
> verdict; the same role, asked for CONTINUE or STOP with evidence, returned CONTINUE with a condition
> in one round and, in the next, an argued STOP — "my strongest case for CONTINUE fails on inspection,
> and I want to be explicit about that because it is the honest test."
>
> Ask for, in this order: N headline numbers re-derived (eleven of twelve reproducing is a reason to
> stop counting); the artifacts not yet opened, by name (the corpus's own unsupervised partition,
> `semantic-map-index.json`, went unopened for two rounds and, opened, showed the subject had no cluster
> of its own); five era-appropriate terms run with controls (two of fifteen were bodies of 250–430
> documents with no row anywhere; the ninth, tenth and eleventh institutional terms returned single
> digits, "which is what a saturated vocabulary looks like"); three archival resolutions attempted and
> every published resolution screened by date span; the documents every prior pass named and none read,
> with one of them read; a ranked list of at most 15 threads, each *what · which surface · why*, sized
> in documents and sorted into reading, corrections and residue; and **an explicit CONTINUE or STOP** —
> the case for stopping as numbered evidence, the strongest case for the other verdict stated and
> tested, and if CONTINUE a success criterion that does not renew itself ("documents read and quoted,
> from a fixed list"), if STOP what a further round would and would not add and the residue that
> belongs in an archive. A sized list becomes a reading list; an unsized one becomes another scoping
> round. The critic is one agent against eighteen refuters in that run, and its own claims about what
> the run contains are subject to §14.14 rule 1 — one critic's "zero mentions in round 1", true when
> written and false after the fix pass, became the next memo's false sentence.

**Evidence.** `S1:771–784` (`CRITIC_TASK` asks for "a ranked list of at most 15 OPEN THREADS", no verdict);
`rounds/round1/critic.md` §9 (fifteen threads, no CONTINUE/STOP — one incidental "recommend" at :189);
`S2:661–666` ("Say plainly whether the investigation is reaching diminishing returns … followed by an
explicit CONTINUE or STOP recommendation with its reason"); `rounds/round2/critic.md:337–364,438–446`
("**Round 3 should be a reading round with a fixed document list and no new scoping** … **CONTINUE — one
further round, constrained to reading**"), `:59–68` (the map "never opened"), `:112–138` (fifteen terms),
`:210–240` (the lot census and the date screen), `:284–302` (d18 read), `:366–370` (the list's form);
`S3:641–656` ("A well-argued STOP is the most useful thing you can write here");
`rounds/round3/critic.md:276–330` ("# **STOP.** … **The instrument is now measuring itself.** … **My
strongest case for CONTINUE fails on inspection**"); `rounds/round2/memo.md:2192–2219` (§8.0 adopts the
condition). The "fraction of the refuters' cost" the miner claimed has no per-agent figure in the files
and is replaced by "one agent against eighteen" (check-M3); "would have fixed the critic's item 2" is
dropped — that is §6.4's rule, not this one.

**Would have prevented.** The round-1 critic's silence on stopping (the orchestrator decided round 2
without evidence); the round-2 and round-3 critic prompts, written ad hoc between rounds, become the
guide's own text.

### What the run confirmed the guide already gets right

A revision list that omitted this would misrepresent the guide. Each rule below was pasted into every
agent and held; the verdicts say so in the same sentence that refutes something else.

- **The numeric discipline held across all 28 round-1 verdicts** — coverage query first, the pair join
  ("every join in queries.log is `ON volume_id=… AND document_id=…`" — T3-m; "`grep -n 'JOIN document_'
  queries.log | grep -v volume_id` returns nothing" — A7-n), apparatus excluded, `summary_text` /
  `note_text` never read, the Ed2 fold, the 552-manifest file set, periodisation on
  `frus:doc-dateTime-min` ("No entry is dated by volume year" — T1-m, T3-m, T4-m, T5-m, T6-m). The
  refuters' own summary: "The report's denominators, its heading counts, its zero-count claims and its
  1930s story all reproduce exactly. What does not survive is the *meaning*" (`agents/refute-A1-headings-history/verdict.md`);
  "every one of the 160 cells I re-derived … reproduced **exactly**" (`refute-T2-citations`). M2 §Notes.
- **Controls in the same pass (§14.2, §12)** — obeyed in every round; `score.md` R3/C1 in all three;
  every round-2 verdict, the critic, the scorer and the audit (M3 §8). What was missing was the
  *comparison*, not the control.
- **N of M with the denominator (§9 item 3, §12)** — obeyed; what was missing was grain, members and
  era-matching.
- **The two archival channels, labelled, never summed (§8, §14.11)** — obeyed everywhere; "Channels —
  came-from and pointed-at are labelled, given separately … Clean" (`agents2/refute-R6-1930s-instruments-method/verdict.md:195–197`);
  scorer A3 "obeyed" in rounds 2 and 3; C1 extended the same discipline to a fourth surface with the
  [HARVEST] label (`rounds/round3/score.md:61`).
- **Zero rows proved capable of returning rows (§9 item 6)** — applied where it was the right test: C1's
  Q15 positive control ("same query shape for '60 D 137' -> 20 rows. The zero is real").
- **Keep the source note (§8:740)** — the rule that exposed `65 A 987` as an accession and chose among
  `73 D 153`'s claimants.
- **The creator-heading caution (§14.11:1361–1364, §12)** — C1's Q7 "verified against the documents' own
  signature blocks, per the 56%-precision rule".
- **The editors' headings as the highest-precision handle (§14.8)** — every round-3 heading census
  (W4, W4a, W5, W13, W15) is that rule, and the critic's independent walk reproduced all of them.
- **The `.fruscollection` write-minimum (§15)** — three files in exactly §15.1's shape (keys `format,
  formatVersion, name, generator, composition, entries`; generator `"commercial-diplomacy-round3,
  2026-09-02"`), 148 → 300 → 400 documents with **nothing dropped at either handover**
  (`…round2.collection-manifest.md:372` "**No round-1 entry was dropped.** All 148 documents …";
  `…round3.collection-manifest.md:81` "**Dropped from round 2: nothing.** Every one of the 300 round-2
  entries survives … tested rather than assumed … **0 hits**"), 400 of 400 pairs present in
  `document_cache`, 0 missing ids, 0 Ed2 twins (check-M6 §0).
- **The §12 block as pasted** — byte-identical to `Planning/c2-long-session/house-rules-block-v1.10.txt`
  (diff exit 0, 110 lines; check-M2, check-M4, check-M6 all ran it), and the run's compliance under it
  went 22/23 → 23/26 → 29/29 as the round scripts added rules the guide lacked (P1, P2, P3, P4) — the
  measured case that these rules work when written down, which is stronger evidence for Part 1 than the
  round-1 failures alone (check-M2 Notes).
- **Own scratch directory per agent (§14.12 item 4)** — every agent in the run had one (`agents*/<label>/`).
- **The diacritic fold** — tested and found folded on every surface (`"commercial attache"`,
  `"commercial attaché"`, `"commercial attaches"` all 1,049 — `refute-A5-subjects-numbers`); the one
  diacritic problem in the round was the auditor's own.
- **The offline stack barely reaches before 1940 (§12:992, §14.11:1365)** — restated by memo v3 §5.0
  ("none before 1901") and the round-3 brief.
- **id decode and the Hamming loop (A.3, A.5)** — verified against the shipped files and used by R1,
  A6 and D3 unchanged; and **the semantic-map header layout** (memo v3 §9) is already in the guide.

### Repo-issue stubs (defects in artifacts, code or planning documents — not guide text)

Each is one line; the guide carries a dated caveat until the issue closes.

1. **`decimal-class-labels.json` country table** — `60f` = Ruthenia (FRUS: Czechoslovakia, 82 docs),
   `47h` = Cook Islands (New Zealand, 27); `42`, `43`, `54`, `74`, `11b` absent; 233 documents
   unnameable, 109 named wrong. Re-read the 1910–63 country table for the parent-state rows the parser
   dropped; add a test that every code on `611.xx31` with ≥4 documents resolves. (M5 A1; no issue exists —
   `gh issue list --search Ruthenia` → none.)
2. **`series-facts-index.json` schema 3** — project `coverageStartDate/EndDate` beside `y0`/`y1`
   (`LotClaimantsIndexGeneratorCore/HarvestShardReader.swift:129` is the CodingKeys line to extend), and
   ship a legend for the one-letter wire keys. (M5 A2; check-M5 missed 2.)
3. **An accession → series map** from `recordsCenterTransferNumbers` — with the claimant count disclosed,
   and citing **#679**, which recorded a deliberate decision *not* to use the field for lot acceptance
   ("Those keys average 1.5 claimants and reach 57 … Widening there would manufacture ambiguity"). C1's
   use is a different join — the editors name the accession themselves — so the issue is "project the
   map", not "reopen #679". (M5 A3, corrected by check-M5.)
4. **`decimal-class-labels.json` era gate for outside consumers** — the app gates by era
   (`governs(_:floor:)`, PR #858); the artifact's provenance says so in words; a naive consumer gets a
   plausible wrong gloss. Either ship the 1951–59 / 1960–63 schedules (the later two schedules #828 — closed — measured and skipped, per `CLAUDE.md`) or add an
   explicit `eraGate` per schedule. (M5 A4.)
5. **`central-files-index.json` picks the wrong claimant for `73 D 153`** (NAID 621628 *Special
   Summaries* where nine of ten source notes say *Morning Summaries*; 620873 is absent from
   central-files entirely). Re-run `LotClaimantsIndexGenerator` (already required after the 1b
   supplement per `CLAUDE.md`) and prefer the claimant whose title matches the editors' wording. (M5 A5.)
6. **`SourceNoteParser` populates `document_sources.lot_file` on notes that name no lot** —
   `frus1969-76v02/d1` and `/d11` (`75 D 229`) are Nixon Presidential Materials notes. (check-M4 R5, re-run
   on the copy.)
7. **A harness runbook under `Planning/`** — the 180 s watchdog, the resume cache keyed on (prompt,
   opts), the model-pin hang and its diagnosis from `agent-*.jsonl`, the canary, the `-uri` history.
   Today these live only in `~/.claude/projects/…/memory/env_workflow_agent_failure_modes.md`;
   `Planning/Agentic-Loop-Development-Plan.md` has none of them (check-M1 missed 4).
8. **Correct the memory note** `env_workflow_agent_failure_modes.md` item 2: the guide's §2 form does
   not "fail as written"; the `-uri` flag was the round-1 script's (`S1:138`). (check-M1 missed 9.)
9. **Re-measure the revised §12 block** with the C-0 harness before v1.11 declares it the instrument
   (Part 2 §5).

---

## Part 2 — Feasibility of a FRUS Explorer research skill

### The verdict

> **Feasible, as a packaging-and-cost artifact — a docs pass in loadable form plus helper scripts —
> and not as an enforcement mechanism.** Build the scripts first, as `tools/`, because the run
> warrants them whatever any evaluation says; build the `SKILL.md` wrapper only if a third arm of the
> C-0 design beats a BLOCK arm that carries the *same* revised §12; and claim for the scripts only what
> they do when invoked.

This is M6's "feasible with conditions" after check-M6's amendments, and the amendments change what
the conditions are. M6's three — the house-rules block generated from §12 by a script with a
byte-compare test, every path a parameter, no attempt to package the orchestration — are right and
are kept. But two mechanism claims under M6's verdict point the wrong way, and the evaluation as M6
drew it could not attribute a win to the skill. Each is set out below with the deciding quote.

### The reasoning, with the corrections

**1. Pasted prose is measured sufficient and non-decaying.** C-0: "**BLOCK 96 of 97 = 99%. CONTROL 81
of 96 = 84%.**" (`Planning/C0-Falsifier-2026-08-31.md:41`). C-2: long session **99/100** against the
control's 75/100, "**Not one item decayed in the block arm**", and NAIDs resolved "8 of 8 versus 0 of
8" (`Planning/C2-Long-Session-2026-08-31.md:39–46,67`). The commercial-diplomacy run then applied the
same block to ~200 agents over three rounds and the final memo scored 29 of 29. A skill's `SKILL.md`
body is that block plus routing; the evidence that the block works is evidence that the skill's prose
half works.

*The correction.* M6 argued that C-2's one recorded limit — "**No session compacted. Zero of eight**"
(`C2:106`) — "is the one a skill addresses structurally … a skill is the mechanism that re-pastes." It
is not. The skill-creator's own loading rule, read on this machine 2026-09-04: "1. **Metadata** (name +
description) - Always in context (~100 words) 2. **SKILL.md body** - In context whenever skill triggers
(<500 lines ideal) 3. **Bundled resources** - As needed". The body enters on trigger and is then
ordinary context, compacted like a paste; per-turn re-presentation is the property the MCP assessment
assigns to the *tool catalogue*, not to a file. What a skill adds over a paste is a one-line re-trigger
after compaction — an unmeasured convenience, not a structural fix. C-2's own answer to the untested
branch stands: "If a block is lost to compaction, the fix is to paste it again — or to let the artifact
carry it, which the export already does: the views enforce four rules structurally regardless of what
the model remembers" (`C2:116–118`).

**2. The run's agents rewrote the same helpers repeatedly.** `find agents agents2 agents3 -name '*.py'
-o -name '*.sh' | wc -l` → **870**; 867 distinct by md5 (check-M6 counted 853); the six basenames M6 named total **55**
(`q.py` 21, `fts.py` 14, `tei_scan.py` 7, `lots.py` 5, `lit.py` 5, `naid.py` 3) — and `walk.py` ×8
and `tei.py` ×6 outrank three of them. **55** files of every kind under `agents*/` carry `sqlite3 -readonly` (13 of the 870 scripts), **525**
carry `uri=True` (484 scripts), and **710** of the 870 scripts hard-code `/Users/jbotts` (re-counted
2026-09-02; check-M6 gave 55 / 525 / 710 without saying the first two are over all files). That is the skill-creator's signal for a
`scripts/` directory, at its honest size: "55 files under six recurring basenames, out of 870 ad-hoc
scripts", not "870 rewrites of six helpers" (check-M6 C3, C8).

**3. The operational facts had no durable home — and after Part 1 the guide is it.** The `-uri`
history, the watchdog, the query shapes that time out and the resume-cache rule lived in three
throw-away workflow scripts (one under `/private/tmp/…/scratchpad/workflows/`, two under a
session-specific `~/.claude/projects/…/workflows/scripts/`) and a TOOLING note those scripts carried.
M6 called the skill "the first durable home for them". check-M6: M6's own G-1/G-2 (and Part 1's §2/§3
entries) put the facts in the guide, "which is then the durable home, and the skill's tooling section
is a second copy — to be generated from it exactly as §12 is, or it drifts like round 3's block did."
The drift is measured: one author, three scripts, 24 hours — byte-identical, one sentence behind, a
50-line paraphrase of 110 (check-M6 §0).

**4. The two refusals were about audience, dependency and over-claimed enforcement.** MCP: "An MCP
server would be the first artifact in the wave that works only for users of MCP-capable clients"
(`Planning/MCP-Server-Assessment-2026-08-31.md:69–70`); "adding this package's first external
dependency across 94 targets" (`:72–73`); "**A tool description is prose with exactly the authority of
§12's prose.** Only implementations bind" (`:131–132`); "'House rules built into the tool
descriptions' overstates what descriptions do" (`:154`); and the flip clause — "If the block alone
fixes the failure it was written to fix, the honest answer is a docs pass plus SQL views, not a
binary" (`:174–176`). C-1 closed on C-0's pre-registration: "If archival compliance holds where it held
here, the block is sufficient and C-1 should be closed as NOT NEEDED" (`C0:166–167`; `C2:113`). A skill
has no protocol and adds no `Package.swift` target; its content is Markdown and Python any agent can
be pointed at (§3:174–175 already says "point the agent at this file"), so the audience narrowing is
bounded to the trigger (check-M6 C9 keep).

*The correction.* M6 wrote that the scripts are "the implementations — a validator that refuses an
id-less entry, a resolver that will not report a span without the harvest, a counter that runs the
controls whether or not the agent remembered." The last clause repeats the over-claim Q4 refused. MCP
Q4 names three mechanisms that "do real work": the response envelope, absent capability, required
parameters (`:133–141`). A script supplies the first and third *for its own output* and cannot supply
the second while the agent holds a shell — a counter runs the controls only if the agent remembered
to run the counter. So every operational item in the evaluation measures whether the agent chose to
run the script, which is prose compliance again. The honest claim is that scripts lower the *cost* of
compliance; they do not bind. The only artifact in this program that carries a rule regardless of
memory is the export view, and even that is opt-in against `document_cache` (check-M6 C5, missed 2).

### What it would contain, and what of it is already built

Layout per the skill-creator: `SKILL.md` (frontmatter + body under ~500 lines), `scripts/`
(executable, deterministic, Python 3 stdlib + `sqlite3` — the contract `tools/semantic-harvest/`
already imposes: "macOS's bundled `python3`, no pip, no venv"), `references/`, `assets/`. The repo has
**no skills of its own** (`find . -name SKILL.md` under the repo and `~/.claude` → nothing; `.claude/`
holds `settings.json`, `settings.local.json`, `worktrees/`; check-M6 verified).

| Component | Already built? | Where | Gap |
|---|---|---|---|
| The house-rules block (SURFACES, COVERAGE, IDENTITY, EXCLUSIONS, TRAPS, REPORTING, SCOPING, ARCHIVAL) | Yes, prose | `GUIDE:879–1013` (fenced block `:883–994`); frozen copy `Planning/c2-long-session/house-rules-block-v1.10.txt` (110 lines, byte-identical) | Must be **generated** from §12's fenced block by `scripts/sync_from_guide.py` with a byte-compare test — never hand-copied. After Part 1 the block is ~132 lines and has not been re-measured. |
| Surface routing (which block answers on DB / TEI / JSON) | Yes, prose | `GUIDE:996–1013` and the `[TEI]`/`[JSON]` tags | Same generation rule. |
| Tooling notes (read-only form; chunking; count form; `body_text` batching; `of`/`the` phrases) | In three throw-away scripts today; in the guide after Part 1 (§2/§3, §6.2) | `S1:605–618`; `S2:130–136`; `S3:76–87` | Generated from the guide's new paragraphs, not hand-written a third time. |
| Round shapes (scope → contest → threads → contest → issue; audit; read; correct; STOP) | Yes, as script phase lists and prompts | the three `meta.phases` blocks; `MEMO_TASK` / `CRITIC_TASK` / `SCORER_TASK` (`S1:704–800`) | `references/rounds.md` as a description, not a runner. |
| Reading discipline (per-agent `queries.log`; quote only from retrieved rows; 5–15 `body_text` per call; notes to scratch; honest read counts) | Yes, as prompts; in the guide after Part 1 (§8, §9 item 8, §13 row) | `S3:462–470,479–483,507` | The verification rule was the only delta (check-M6 C20). |
| The rubric | Yes | `Planning/c2-long-session/RUBRIC.md` — **26** items (C-0's 25 plus A6); round 2 added P1/P2 (`S2:682–684`), round 3 P3/P4 (`rounds/round3/score.md:4`: "30 items, 29 applicable") | `references/rubric.md` verbatim, at the right count — M6's "25 items … P1/P2/P3" would ship the wrong list (check-M6 C6, C14). |
| The STOP protocol | Yes, as one prompt and two worked verdicts | `S3:649–654`; `rounds/round3/critic.md:276–330`; `rounds/round2/critic.md:438` | `references/stop-protocol.md`; Part 1's §14.15 is the guide text. |
| `.fruscollection` writer + validator | Writer spec yes (§15, fixture at `FRUSExplorerTests/CollectionTests.swift:2856–2876`); validator **no** | the run re-specified the five checks in every collection prompt (`S1:758–767`; `S3:626–633`) | `scripts/validate_fruscollection.py` — the single most valuable script; the round-3 file passes all checks today (411 entries, 400 documents, 400/400 pairs in `document_cache`). |
| id-decode + Hamming helper | As verified prose code; not as a file | `GUIDE` A.3 `:1550–1574` ("verified: 552 of 552" is line 1574), A.5 `:1619–1637`; `SemanticVectorsKit/DocumentIDSegments.swift:50`; `RetrievalEvalHarness` (`Package.swift:785–806`, needs `swift run`) | No Python in `tools/` reads the shipped binary (`grep -rl semantic-vectors-binary tools/` → nothing). `scripts/semantic_neighbors.py` with A.5's two numbers as its self-test — and both baselines from Part 1's Appendix A entry. |
| Literal-share auditor | ×5 as ad-hoc `lit.py`; in the guide after Part 1 (§7.1) | e.g. `agents2/refute-R9-private-counterpart-citations/lit.py`; the refined rule at `rounds/round3/memo.md:462–475` | `scripts/literal_share.py` in the **refined** form — tolerant with strict beside it, four indexed columns, the homograph caveat — not the round-3 prompt's superseded strict-only form M6 specified (check-M6 C18). |
| Date-span screen | As a standing rule in memo v3; in the guide after Part 1 (§14.11 rule 3) | `rounds/round3/memo.md:2123–2135`; `C1-archival-corrections.md:144` | Test 2 needs `coverageStart/EndDate`, which only the one-machine harvest carries until repo stub 2 ships. The script must **refuse** a span verdict without it and say so. |
| Two archival-channel resolvers | Artifacts yes; joins ad hoc ×N | `FRUSExplorer/Resources/` (34 JSON: `central-files-index.json` 3.6 MB, `series-facts-index.json` 116 KB, `lot-claimants-index.json` 132 KB, `collection-authority.json` 1.9 MB, `external-citation-index.json` 584 KB, `collection-usage-index.json` 644 KB); `agents2/thread-R7-people/lots.py`, `agents/refute-T1-citations/naid.py` | `scripts/resolve_lot.py` and `scripts/pointed_at.py`, each printing the channel label and volume set on every count. **Join on `lot_file_norm` and refuse raw input**: the keys are already folded on both sides (`document_sources.lot_file_norm` = `53D223`; `central-files-index.json` `lotNumber` = `53D223`; `lot-claimants-index.json` `lotNumber` = `53D223`), so the Python-proxy risk `CLAUDE.md` records ("three analysis errors … from measuring with a Python proxy that tokenised differently") is avoidable rather than incurred (check-M6 C15). Print **every claimant** for the 123 divided lots — M5's A5 (`73 D 153`) is a successful join naming the wrong series, which a confident single card gets wrong. |
| FTS phrase-family counter | ad hoc ×14+ (`fts.py`, `fam.py`, `q.py`) | `agents2/critic2/fts.py`; the timeouts under Part 1 §6.2 | `scripts/fts_family.py` with the rowid-`IN` form and the controls built in — the self-test's expected value carries its surface (93,418 / 549 is FTS *documents* on the working scope, `rounds/round3/memo.md:356`; the guide's 178,311 / 552 is TEI *occurrences*, `GUIDE:1088`), or the self-test fails on a surface, not a defect (check-M6 C17). |
| Research-state record | Yes, in-app and in the run | `GUIDE` §13; `rounds/round1/research-state.json` (18 keys, richer than the app's — it names the harvest record groups and the Ed2 fold) | `scripts/research_state.py` emits the run's shape plus Part 1's four new rows. |
| Export views | Yes, in-app | `GUIDE` §4.7 (`research_documents`, `research_cross_references`, `research_suppressed_volumes`, `research_provenance`) | Nothing to build; detect (`SELECT name FROM sqlite_master WHERE type='view'`) — the run's copy had none (`S1:152`). |

### The gaps

No validator; no Python reads the vector binary; §15 carries no Python; no `queries.log` verification
rule in the guide until Part 1's §13 row lands; no skills directory anywhere on this machine; and the
harness runbook (repo stub 7) that would hold the model-pin and resume specifics does not exist.

### The risks

- **R-1, drift (the highest).** A hand-copied `SKILL.md` is a second copy of §12 that falls behind
  the first; the guide moved 1.0 → 1.10 in one week and §12 was rewritten twice in it. Mitigation:
  `scripts/sync_from_guide.py` plus a byte-compare test — the repo's own rule for mirrors (memory:
  *port mirror→source by generating*). One condition M6 omitted: **the test can only pin a skill that
  lives in the repo**; a copy installed under `~/.claude/skills` (which does not exist today) is
  outside every test (check-M6 C7).
- **R-2, paths.** 710 of 870 ad-hoc scripts and the round-1 constants (`S1:17–19`) hard-code
  `/Users/jbotts/…`; the guide itself prints `/Applications/…` (`:1297`) and `~/frus-analysis`
  (`:116`) as examples. Scripts take `FRUS_DB`, `FRUS_VOLUMES`, `FRUS_RESOURCES`, `FRUS_HARVEST` from the
  environment or a `frus-research.json` beside the copy; the resources path must resolve to the
  installed app, not only the repo (`GUIDE:1300–1301` "Take them from the build that wrote your index").
- **R-3, audience.** `SKILL.md` frontmatter is a Claude convention; the guide's audience is "Claude,
  ChatGPT, Gemini, or a comparable agentic tool" (`:3–4`). Bounded: the content is Markdown and Python;
  what a non-Claude agent loses is auto-triggering, not the method. Say so in the skill's README.
- **R-4, artifact defects the resolvers inherit.** M5's five (repo stubs 1–5 above) — A5 in particular
  is a case a resolver gets wrong *after* a successful join. Every one becomes a self-test case.
- **R-5, the harvest dependency.** The date-span screen's decisive test needs `rg_59.json`
  (3,559,252,571 bytes, gitignored, one machine). Without it the screen silently reverts to the narrower
  field, which is *precisely* memo v2's defect. Refuse, and say so.
- **R-6, cost.** No cost figure from the run survived into any file; the evaluation is on the order of
  C-0 + C-2 (16 runs + 16 scorers) plus one arm — record the figure this time, in the evaluation file.
- **R-7, scope creep toward a runner.** `tryAgent`, the blind scorer, `draftNote`, the per-key resume
  conditional are the workflow runner's business (`S1:517,621–632,670`). `references/rounds.md` stays
  descriptive.

### The evaluation plan — the C-0 design, one arm wider, with the confound removed

C-0's harness (`Planning/c0-falsifier/workflow.mjs`, 65 lines) and C-2's long-session variant are
re-runnable as-is; the change is a third arm. Two corrections to M6's plan decide whether the result
means anything:

| Arm | What it gets |
|---|---|
| SKILL | the skill directory, loaded — no pasted block |
| BLOCK | **the revised §12 block from Part 1**, pasted (not v1.10's) |
| CONTROL | no rules |

*Why the BLOCK arm must carry the revised block:* if Part 1's §2/§3 and §7.1 land in the guide, a BLOCK
arm on v1.10's §12 loses the operational items to prose the guide would carry anyway, and a SKILL-arm
win is attributed to the loader for what a docs pass delivered (check-M6 C14(d), missed 3). Freeze both
arms to the same text, or add a BLOCK+v1.10 arm and read the difference.

*What is scored:* the 26-item rubric (`RUBRIC.md` with A6) plus P1–P4, plus five operational items the
skill specifically claims — O1 no failed read-only invocation; O2 no call exceeded the watchdog and
corpus scans were chunked; O3 every phrase family carries a literal share and sample size; O4 the
collection file passes the validator; O5 lot resolutions carry the date-span verdict or an explicit
"harvest absent". *Two facts about O1 and O2:* they are **transcript** items and C-0 saved memos only
(`scratchpad/c0/runs/aN/report.md`; no transcript or query log exists for any of the sixteen C-0/C-2
runs), so the SKILL run must require a per-agent `queries.log` — the run's convention — or capture the
transcript; and O1 barely discriminates, because block-arm agents hit `-uri` and self-corrected in one
call (C-0 a3 `:443`, a7 `:341`; C-2 b4 `:284–285`; the run's A4 and A6) — the hours were watchdog kills
and quota deaths, which O2 partly and no skill fully addresses (check-M6 C14(b)(c), missed 4, 13).

*Runs:* fresh questions (C-0's two are now printed in the planning documents); 2 per cell → 12 runs,
12 blind scorers; the C-2 long-session variant optional — and **not** "for the SKILL arm alone", since
the compaction advantage it was to test does not exist as described.

*Pre-registered reading, in C-0's form:* **build** the wrapper if SKILL ≥ BLOCK on the 26 items with A6
at 8/8 *and* SKILL beats BLOCK on O1–O5 by a margin outside C-0's n=2 noise; **docs-pass only** if
SKILL ≈ BLOCK on everything including O1–O5; **investigate** if SKILL < BLOCK on the 26 (the loader is
costing something the paste is not). **Scripts in `tools/` are the outcome of every branch**, since the
55/870 count warrants them independently of the loader (check-M6 C14(f)). Adjudicate scorer verdicts as
C-0 did (`C0:58–77`) and give the mechanical grep its own positive and negative control (`C2:63–77`).

Use the skill-creator's eval harness for the *scripts* only (`evals/evals.json`: "552 of 552 volumes
round-trip"; "frus1861/d111 → frus1862/d130 at Hamming 87"; "the round-3 `.fruscollection` validates;
a copy with one `documentId` removed is refused"; "`"department of state"` = 93,418 / 549 on the FTS
surface"). Its with-skill / without-skill benchmark is the wrong instrument for the method — the rubric
is.

### How it squares with L-8 and C-1

**L-8 (MCP, NO-BUILD).** Audience: a skill narrows less — content is files any agent can be pointed at;
only the trigger is Claude-specific. Dependency: none — Python stdlib, no `Package.swift` change, no
bundled resource, no CloudKit gate. Enforcement: the assessment's strongest point ("Only
implementations bind") decides the skill's shape — the prose half binds nothing the paste did not, and
the scripts bind only their own output when invoked. The flip clause ("a docs pass plus SQL views, not
a binary") is satisfied by Part 1; the skill is that docs pass in loadable form plus the scripts a docs
pass cannot carry. It is inside the clause, not outside it — provided it makes no enforcement claim
for prose.

**C-1 (CLI, CLOSED NOT NEEDED).** The rules that survive a paste need no tool. A skill does not reopen
C-1 because it is not a tool that *replaces* the rules; it is the rules, delivered, with helpers for
the parts that were never rules — the invocation, the chunking, the joins, the file format. C-0's
residue sentence describes it: "**a tool would make the archival resolution the default for a reader
who does not paste 110 lines of prose.** That is worth something. It is not worth four …" (`C0:153–154`).
A skill makes the paste the default without a binary.

**What the assessments would refuse.** Two versions of it: a hand-maintained `SKILL.md` that is a
second, drifting copy of §12 (Q4's objection with the roles reversed), and a skill that claims
enforcement for prose or "whether or not the agent remembered". The recommended build avoids both.

### Recommended first step, sized honestly

**Step 0 — the Part 1 docs pass, then re-measure the block.** Land Part 1 as guide v1.11. The guide is
the durable home and every skill component generates from it; nothing else is sized until it exists.
The revised §12 block is ~22 lines longer than the instrument C-0 and C-2 measured, and none of the
new lines has been tested: re-run C-0's eight-run design (block vs control, two questions, two runs
per cell, blind scorers) on the revised block before v1.11 declares it the instrument. Size: a day of
editing; the re-run is C-0's scale (8 runs + 8 scorers) and its cost must be recorded this time,
since the 2026-09 run's figures survive only in the orchestrator's memory.

**Step 1 — `tools/frus-research/`, five scripts and a generator, no wrapper.** `validate_fruscollection.py`
(§15's checks; the round-3 file as the positive fixture, an id-stripped copy as the negative);
`fts_family.py` (rowid-`IN`, controls with their surfaces, the Ed2 fold, the decade denominator from
§6.4); `literal_share.py` (tolerant with strict beside it over the four indexed columns; the 0.80
convention as a flag, not a verdict; the homograph caveat printed); `resolve_lot.py` (join on
`lot_file_norm`, refuse raw input, print every claimant, the date-span screen with a hard refusal when
`FRUS_HARVEST` is unset); `research_state.py` (the 18-key shape plus §13's four new rows); and
`sync_from_guide.py` with the byte-compare test that pins the block and the tooling paragraphs to the
guide. Stdlib only; every path from the environment. Self-tests as listed above. Size: one to two days
for someone who has read Part 1; warranted by the 55/870 count and the four timeouts regardless of
what any arm later says.

**Step 2 — only then, the three-arm evaluation, with the `SKILL.md` wrapper built as its input and
kept only on a "build" reading.** Size: C-0 + C-2's scale plus four runs (12 runs, 12 scorers), plus
the `queries.log` capture O1/O2 need. The honest expectation, stated before the run: the scripts'
value is established by step 1; the wrapper's marginal value over guide-plus-tools is unmeasured, and
the one structural advantage M6 reserved for it does not exist as described. A "docs-pass only"
reading is the likely outcome and is not a failure — it is the outcome the MCP assessment's flip
clause already named.

---

## Dropped recommendations (with the checker's reason)

No recommendation was dropped whole: across the six checkers the headline is 0 drop / 10 keep / 46
amend. What follows is every part of a recommendation that was cut, moved or reworded against the
miner's text, so a reader can see what was considered. The brief's own premise is listed first.

| What was proposed | By | Cut / changed to | Checker's reason (deciding quote) |
|---|---|---|---|
| The premise that "the guide's own §2/§3 invocation `sqlite3 "file:...?mode=ro" -uri` fails" | the task brief; memory note | Dropped as a premise; the guide's gap is the absence of any shell form | check-M1 §0: "**The guide never prints `-uri`.** … typed into the shell as written, `sqlite3 "file:scratch.db?mode=ro" "CREATE TABLE zz(x);"` fails with `attempt to write a readonly database (8)` … The flag came from the round-1 script (S1:138)". Re-run here 2026-09-04, same result. |
| "Apple's build rejects `-uri`" and a bare `CREATE TABLE zz(x);` as the read-only proof | M1-R1 | "the sqlite3 shell has no `-uri` option"; `BEGIN; CREATE TABLE zz(x); ROLLBACK;` | check-M1: "The miner's bare `CREATE TABLE zz(x);` proof writes a table into the copy if the connection is not actually read-only"; "`BEGIN IMMEDIATE` … is NOT a read-only proof". |
| "verified on macOS sqlite3 3.51 to return `552|316839|1012|8468`"; "That binary does **not** accept `-uri`" | M2-R14 | Reworded so it does not read as a 3.51 quirk; the row count dropped as the verification | check-M2: "invites the reading that another sqlite3 would; the shell has no `-uri` option to accept … 'verified … to return `552|316839|1012|8468`' is this copy's coverage, not a property of the command." |
| "16 volumes per call was comfortable"; "three minutes" as the rule | M1-R2 | "ten to twenty per call"; "your harness's per-call timeout (three minutes, in the runs this guide draws on)" | check-M1: "'16 volumes per call' is one data point (T6's 4×16 over a 64-volume era)"; "'three minutes' is one harness's watchdog". |
| "the join makes the planner abandon the FTS index" | M1-R3, M3-7 (and check-M3's amended text) | "the planner … drives the join from `document_cache`'s facet index and runs the MATCH once per row" | check-M1 ran `EXPLAIN QUERY PLAN`: "It does not 'abandon' the FTS index; it probes it per row … **The guide's own §6.2 ranked recipe is fine**". I side with check-M1 over check-M3 on this sentence. |
| "One log records the timeout, so this is a could" | M3-7 | Upgraded to **should** | check-M3: "Four more do, in round 1 … **92 files** … carry `rowid IN (SELECT rowid FROM frus_documents`. The JOIN-with-aggregate timeout is the loop's most-repeated tooling defect". |
| A fifth §13 row for the run identifier; the resume-cache clause in the prompt-text row | M1-R4 | Folded into the model/session row; clause trimmed | check-M1: "harness-specific on its own"; "the general point is two texts = two instruments". |
| §14.12 item 7's model-pin specifics ("do not pin agents to a model the session is not already using") | M1-R5 | Replaced by the canary rule; specifics to a Planning runbook | check-M1: "properties of one harness (the Workflow tool) on one day … 7's pin hang would not have been prevented by a sentence in a method guide — by a canary." |
| A measured cost paragraph with $2,800 / 2.9 B tokens / 19 h as guide text | M1-R6 | Number-light, in §14.12, with the §13 row making the next figure citable | check-M1: "Evidence real: **no** for the load-bearing figures … in no file under RUN or the scripts … every other number in the guide is measured with a source." |
| Placing the three surface-narrowing shapes in §7.8 | M2-R2 | Moved to §14.2; a fourth shape (the apparatus exclusion) added | check-M2: "§7.8 … is about sparse SQL tables; the shapes … are TEI/heading-scan shapes and belong beside the control rule in §14.2". |
| A nine-term FRUS false-friend list in §14.5 | M2-R3 | Cut to three shapes with one example each; "put the question's own list in the block you paste" | check-M2: "A guide cannot enumerate every question's false friends; it can state the shapes … the one FRUS-specific pre-warning that worked (8 of 8) was a line in the run's prompt". |
| "filter … afterwards" as a looser rule without the 0.80 threshold | M2-R4 | The threshold carried, as the project's convention | check-M2: "The guide should carry the operational form that was actually tested". check-M6 C18 calls 0.80 "measured (3 of 43 families fail tolerantly)"; check-M3 and check-M4 call it the task's threshold, and `R2-commercial-policy.md:206` ("Verdict rule as the task specifies") settles it — a measurement of the families, not of the threshold. |
| "two more failed when a 40-document sample was replaced by a census"; "54 of 86" | M3-3 | "two more that had shipped with no share failed when first measured"; "55 of 86 (0.640)" | check-M3: "They were never sampled; they shipped unmeasured"; "the memo's fix pass re-measured the second at `memo.md:372`: '55 literal of 86 (0.640)'". |
| Editorial-note span-dating inside the §14.7 paragraph | M2-R5 | Moved to §4.3's table | check-M2: "a *schema* fact a SQL user hits in `document_dates` … or nobody querying dates will see it." |
| A new §7.8 bullet for `COUNT(*)` over `LEFT JOIN` | M2-R7 | Appended to §9 item 5 | check-M2: "§9 item 5 ALREADY prescribes the EXISTS re-derivation that caught the 410 … The miner does not acknowledge this." |
| The 13-vs-25 clause in the §13 queries row | M2-R8 | Kept once, in §9 item 1 | check-M2: "it is T6's case and belongs in the §9 sentence, once." |
| "treat a control more than 2% below it as a surface defect"; one undifferentiated list of heading references | M2-R9 | "materially below it (the two failures were 16% and 55% low)"; two labelled heading rows, dated | check-M2: "the '2%' is the refuters' brief tolerance … not a measured property of the corpus"; "they are different surfaces and the miner's list runs them together". |
| "FRUS names the *Rogers Act* twice in 552 volumes, both after 1970" | M2-R10 | "named in one historical document in 552 volumes (frus1977-80v28/d166, 1979)"; and §14.7:1203 corrected | check-M2: "would sit in the same guide as §14.7's 'All four `Rogers Act` hits … are footnote glosses or index entries' … one of the four is document text"; "'both after 1970' is not evidenced in the cited files". Verified here. |
| Replacing §6.4's body; omitting the 1860s cell; "a rate over a 6,000-document decade … fell to fourth" | M3-2 | Append, not replace; 1860s 11,250 restored; the measured 76-of-116 / 64.4-vs-116.9 sentence | check-M3: "**It does not say the 1900s 'fell to fourth'** — that is the miner's gloss … And the 1900s denominator is **9,924**, not 'a 6,000-document decade'." |
| Two-paragraph institutional form of §14.6 with the 649-position quotation; the Roman-numeral paragraph | M3-5 | Shrunk ~60%; numerals to §14.4's table | check-M3: "the guide's register is one measured case per rule"; "The Roman-numeral sub-case … is a spelling variant — §14.4's table, not §14.6". |
| The seven-item critic brief inside §14; "a fraction of the refuters' cost"; "would have fixed the critic's item 2" | M3-6 | Brief to a pasteable block; "one agent against eighteen"; the item-2 claim dropped | check-M3: "the seven-item brief is a prompt, and the guide's convention for prompts is §12's pasteable block"; "no per-agent figure exists in the files"; "nothing in the seven items asks for a denominator; M3-2 does." |
| "require the quoted string as a substring" (whole-quotation strict) | M4-R2 | Split at ellipses; segment-strict at increasing offsets | check-M4: "a strict test on a whole quotation fails every legitimately elided quotation ('…'), which is what produced the critic's three false failures"; and `verify6.py`'s chunk-tolerant matcher "passes all three" of D2's defects. |
| The watchdog sentence and "five to fifteen" as §3 method text | M4-R3 | Chunk-and-checkpoint clause; the definition of "read in full" carries the rule | check-M4: "the round-3 script already said 'Select it for specific pairs, a handful at a time' and D5 truncated anyway — so the definition, not the batch advice, is the part that bites." |
| The genre test as part of the numbered §9 item | M4-R1 | One clause | check-M4: "a heuristic for one deliverable shape and does not belong in a numbered protocol item". |
| "let the editors' wording choose" stated in §6.5 as well as §14.11; the §12:979 candidate clause | M4-R5 | Stated once (rule 3); block left alone | check-M4: "duplicates R4's rule 3 — state it once"; "leave the block alone; the candidate rule lives in §14.11". |
| A paragraph-length cell for `lot-claimants-index.json` | M4-R6 | Short cell; the diagnostic moved beside rule 3 | check-M4: "a paragraph in a table cell, and the diagnostic … belongs beside the date-span rule, not in the artifact table." |
| The owner's harvest path in the §12 block; "SURFACES — there are three on every machine and a fourth on the owner's" | M4-R7; M5-R1(a) | One conditional line, no path; the path in per-run RESOURCES text; the portable fact in §14.11 | check-M4: "out of place twice over"; check-M5: "the block is what every agent actually receives, and all three scripts already pasted the RG list there". My resolution is in §14.11(a); it takes check-M5's shape and check-M4's placement, and departs from check-M4's "No change to §12" by one line. |
| A full paragraph on the quotation-fidelity lens in §14.12 | M4-R12 | One sentence | check-M4: "R1 item 8 … and R2 … carry the substance; the miner's own 'would have changed: nothing in the run'." |
| The miner's `Sources/…` repo paths | M4, M5 | Corrected to `LotClaimantsIndexGeneratorCore/HarvestShardReader.swift` and `RecordGroupCatalogGeneratorCore/RecordProjector.swift` | check-M4: "The claims hold; the paths do not." |
| A sentence in §5 introducing `decimal-class-labels.json` | M5-R3 | Dropped; §14.11 row only | check-M5: "the guide never introduces `decimal-class-labels.json` in §5 (its only mentions are lines 980 and 1315 [`grep -n` 2026-09-02: 983 and 1315])". |
| Rewriting the Foreign Service row's verdict in §14.10 | M5-R5(b) | A qualifier below the table; the measured row untouched | check-M5: "it was a measured finding for that question". |
| "A link at 126–137 is the top 0.1–1% of random pairs: unusual, not decisive" in A.5 | M5-R6(a) | Two baselines; the k-th-neighbour distribution for a neighbour | check-M5: "the framing the miner would write into A.5 is the framing the run's own refuter called 'wrong in kind and wrong in magnitude'" (`refute-R1:155–160`). |
| "Precision by reading, 20 documents each: 10 of 20 and 4–5 of 20" | M5-R7 | "One agent's reading of 20 documents per tag" with the working-scope denominators | check-M5: "A5's own era-blind stride reading (refuter P1), so label it 'one agent's reading of 20', not 'precision'"; three different totals for the same tag. |
| M5 A3's "no issue exists" for `recordsCenterTransferNumbers` | M5 | Cites #679 | check-M5: "#679 (closed) … '**Deliberately not extended to `recordsCenterTransferNumbers`.**' … A3 survives as a different join but must cite it." |
| "a skill addresses [compaction] structurally … a skill is the mechanism that re-pastes"; the long-session variant "for the SKILL arm alone" | M6 | Dropped; a one-line re-trigger, unmeasured | check-M6 C2, and the skill-creator's `SKILL.md` read here: the body is "In context whenever skill triggers", only the description "Always in context". |
| "870 rewrites of six helpers" | M6 | "55 files under six recurring basenames, out of 870 ad-hoc scripts" | check-M6 C3: "the six named basenames total **55** … the number is inflated ~16×". |
| "a counter that runs the controls whether or not the agent remembered" | M6 | "when invoked" | check-M6 C5: "repeats the over-claim Q4 refused (`:154`)". |
| "every ad-hoc script and every prompt hard-codes `/Users/jbotts`" | M6 | 710 of 870 | check-M6 C8. |
| "the skill is the first durable home" for the operational facts | M6 C4 | The guide is the durable home; the skill carries a generated copy | check-M6 C4: "(a) the premise that the guide's invocation fails is false … (b) the report's own G-1/G-2 … put the facts in the guide". |
| A 25-item rubric with "round 2's P1/P2/P3" | M6 | 26 items (A6) + P1/P2 (round 2) + P3/P4 (round 3) | check-M6 C6/C14: "`references/rubric.md` as specified would ship the wrong list". |
| `literal_share.py` in the round-3 prompt's strict form | M6 | The memo-v3 refined form | check-M6 C18: "`literal_share.py` as specified would implement the superseded form." |
| `resolve_lot.py` re-implementing `foldControlNumber` in Python | M6 | Join on `lot_file_norm`; refuse raw input | check-M6 C15: "The came-from route needs no fold … removes the one place the report's design needed a Swift rule in Python." |
| Fourteen line-number citations into the C-0 / C-2 / MCP documents | M6 | Corrected (`MCP :73`→`:69–70`, `:75`→`:73`, `:120–121`→`:131–132`, `:126`→`:154`, `:150–153`→`:174–176`; `C0 :44`→`:41`, `:118–119`→`:153–154`, `:127–128`→`:166–167`; `C2 :97`→`:106`, `:105`→`:117`, `:53–58`→`:67`) | check-M6 §3; every substance holds. Re-read here at the corrected lines. |
| M3's house-rules line numbers (955 / 925–927 / 956–957) | M3 | 939 / 917–919 / 955 | check-M3: "a Write phase that trusts them inserts text mid-bullet". Verified by `grep -n` here. |

---

## Sources

Every run file this document cites, by location. Paths under `RUN` =
`/Users/jbotts/frus-analysis/commercial-diplomacy/`.

**Workflow scripts.**
`/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-pensive-goldberg-236407/144987ac-9dae-4a56-bae0-48cecd302617/scratchpad/workflows/commercial-diplomacy-round1.js`
(and `.stalled`, `.pre-opus`);
`/Users/jbotts/.claude/projects/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-pensive-goldberg-236407/144987ac-9dae-4a56-bae0-48cecd302617/workflows/scripts/commercial-diplomacy-round2-wf_1310b062-c82.js`;
`…/commercial-diplomacy-round3-wf_9fd13f08-036.js`.

**Round deliverables (`RUN/rounds/`).** `round1/score.md`, `round1/critic.md`, `round1/memo.md`,
`round1/research-state.json`, `round1/threads/T6.md`; `round2/score.md`, `round2/critic.md`,
`round2/memo.md`, `round2/audit-round1.md`, `round2/threads/R1-instruction-genre.md`,
`R2-commercial-policy.md`, `R5-1970s-institutions.md`, `R6-1930s-instruments.md`,
`R8-archival-deepening.md`, `R9-private-counterpart.md`; `round3/score.md`, `round3/critic.md`,
`round3/memo.md`, `round3/threads/C1-archival-corrections.md`, `C2-number-corrections.md`,
`D3-map-harvest.md`, `D4-ecefp.md`, `D5-geography.md`.

**Collections (`RUN/`).** `commercial-diplomacy-round{1,2,3}.fruscollection` and
`.collection-manifest.md`.

**Round-1 agents (`RUN/agents/`).** `A4-sql/queries.log`; `A5-subjects/queries.log`,
`A5-subjects/report.md`; `A6-semantic/report.md`; `A8-pointed-at/queries.log`;
`A3-tei-policy/queries.log`; `A2-tei-institutions/queries.log`; `thread-T3/queries.log`;
`thread-T6/queries.log`; verdicts: `refute-A1-headings-history`, `refute-A1-headings-numbers` (and its
`queries.log`, `verdict.md:112`), `refute-A2-tei-institutions-history`, `refute-A2-tei-institutions-numbers`,
`refute-A3-tei-policy-history` (and `queries.log:441`), `refute-A3-tei-policy-numbers` (and
`queries.log:44`), `refute-A4-sql-history`, `refute-A4-sql-numbers`, `refute-A5-subjects-history`,
`refute-A5-subjects-numbers` (and `commands.log`), `refute-A6-semantic-history` (and `queries.log:100`),
`refute-A6-semantic-numbers`, `refute-A7-came-from-history`, `refute-A7-came-from-numbers`,
`refute-A8-pointed-at-history`, `refute-A8-pointed-at-numbers`, `refute-T1-citations`,
`refute-T1-method` (and `queries.log:2`), `refute-T2-citations`, `refute-T2-method`,
`refute-T3-citations`, `refute-T3-method`, `refute-T4-citations`, `refute-T4-method`,
`refute-T5-citations`, `refute-T5-method`, `refute-T6-citations`, `refute-T6-method` — all
`verdict.md`.

**Round-2 agents (`RUN/agents2/`).** `thread-R1-instruction-genre/queries.log`;
`thread-R6-1930s-instruments/queries.log`; `thread-R7-people/lots.py`; `critic2/fts.py`;
`refute-R1-instruction-genre-method/verdict.md`; `refute-R2-commercial-policy-citations/verdict.md`;
`refute-R2-commercial-policy-method/verdict.md`; `refute-R5-1970s-institutions-citations/verdict.md`;
`refute-R5-1970s-institutions-method/verdict.md`; `refute-R6-1930s-instruments-method/verdict.md`;
`refute-R8-archival-deepening-method/verdict.md`; `refute-R9-private-counterpart-citations/verdict.md`
(and `lit.py`); `refute-R9-private-counterpart-method/verdict.md`.

**Round-3 agents (`RUN/agents3/`).** `corr-C1-archival-corrections/queries.log`;
`corr-C2-number-corrections/queries.log`; `read-D2-trade-fairs/queries.log`,
`read-D2-trade-fairs/reading-notes.md`; `read-D3-map-harvest/queries.log`; `read-D4-ecefp/queries.log`;
`read-D5-geography/queries.log`, `read-D5-geography/reading-notes.md`; `critic3/verify6.py`;
`refute-C1-archival-corrections/verdict.md`; `refute-C2-number-corrections/verdict.md`;
`refute-D1-fccr-treaties-quotes/verdict.md`; `refute-D2-trade-fairs-quotes/verdict.md`;
`refute-D2-trade-fairs-method/verdict.md`; `refute-D3-map-harvest-method/verdict.md`;
`refute-D4-ecefp-quotes/verdict.md`; `refute-D5-geography-quotes/verdict.md`;
`refute-D5-geography-method/verdict.md`; `refute-D6-conventions-unions-quotes/verdict.md`.

**Review reports (`RUN/agents-review/`).** `M1-operations/report.md`; `M2-round1-verdicts/report.md`;
`M3-round2-verdicts/report.md`; `M4-round3-reading-archival/report.md`; `M5-artifact-surfaces/report.md`;
`M6-skill-feasibility/report.md`; `check-M1-operations/verdict.md`; `check-M2-round1-verdicts/verdict.md`
(and `rogers_d166.py`); `check-M3-round2-verdicts/verdict.md`; `check-M4-round3-reading-archival/verdict.md`;
`check-M5-artifact-surfaces/verdict.md`; `check-M6-skill-feasibility/verdict.md`.

**Repository files.** `Docs/Agentic-Analysis-Guide.md` (v1.10, 1,869 lines); `CLAUDE.md`;
`Planning/Agentic-Loop-Development-Plan.md`; `Planning/MCP-Server-Assessment-2026-08-31.md`;
`Planning/C0-Falsifier-2026-08-31.md`; `Planning/C2-Long-Session-2026-08-31.md`;
`Planning/c2-long-session/house-rules-block-v1.10.txt`; `Planning/c2-long-session/RUBRIC.md`;
`Planning/c0-falsifier/workflow.mjs`; `Planning/nara-record-group-catalog-runbook.md`;
`FRUSExplorer/Export/ResearchDataExporter.swift:1369–1425`;
`LotClaimantsIndexGeneratorCore/HarvestShardReader.swift:129,222–223`;
`RecordGroupCatalogGeneratorCore/RecordProjector.swift:152,160`;
`SourceNoteKit/LotResolutionAcceptance.swift:84`; `FRUSExplorerTests/CollectionTests.swift:2856–2876`;
`Package.swift:785–806`; `FRUSExplorer/Resources/decimal-class-labels.json`, `series-facts-index.json`,
`semantic-map-index.json`, `external-citation-index.json`, `volume-sources-index.json`; GitHub issues
#679, #828, PR #858.

**Outside the repository.** `/Users/jbotts/frus-analysis/frus-copy.db` (opened `-readonly` for every
figure re-run here); `/Users/jbotts/Development/nara-record-group-catalog/series/rg_59.json`
(3,559,252,571 bytes; existence and size only);
`~/.claude/projects/-Users-jbotts-Development-FRUS-Explorer/memory/env_workflow_agent_failure_modes.md`;
the skill-creator's `SKILL.md` (Progressive Disclosure, lines 86–91, under
`~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/…/skills/skill-creator/`).

**Re-run on this machine, 2026-09-04, for this document.** `sqlite3 --version` → 3.51.0; `sqlite3 -uri`
→ `unknown option: -uri`; `sqlite3 -readonly frus-copy.db` → `552|316839`; `sqlite3
"file:…?mode=ro" "… BEGIN; CREATE TABLE zz_probe(x); ROLLBACK;"` → count returned, write refused;
`which timeout gtimeout` → neither; `frus1977-80v28/d166` → `is_front_matter=0, is_editorial_note=0`,
`body_text` "…this return to a post-Rogers Act The Foreign Service Act of 1924…"; FTS `"rogers act"`
on the working scope → 8; the three collections → 148 / 300 / 400 documents; `research-state.json` →
`databaseCopy.myWritingIncluded = true`, `myWritingRowsNeverRead = {6556, 12, 85}`, `workflowRunId =
wf_4fc9078c-b84`, 18 top-level keys; the guide's §12 block line numbers by `grep -n`.

Audited 2026-09-04: 627 claims checked, 29 corrected (432 citations, 98 guide greps, 56 path and census checks, 41 database and shell re-runs; the audit is at `RUN/agents-review/audit/audit.md`).
