import sys, io
src = open(sys.argv[1], encoding='utf-8').read()
addendum = open(sys.argv[2], encoding='utf-8').read().rstrip('\n')
out_path = sys.argv[3]

pairs = []
def rep(old, new): pairs.append((old, new))

# P1 status + provenance + reviewed line
rep(r'''**Status: ASSESSMENT, 2026-09-12. Not a plan of record, not a schedule, and nothing in it is queued.**''',
r'''**Status: ASSESSMENT, 2026-09-12. Not a plan of record, not a schedule, and nothing in it is queued. Owner decision: PENDING — the decisions this asks for are listed in §6.3.**

Answers the `N-0 → N-1 → N-2 → N-3 (#234)` row of `Planning/Plan-Of-Record-2026-09-06.md` §2 (the owner
lane) — the N-2 reading `Planning/People-Early-Era-Program.md` §4 says is owed once M2a is scored.
**Reviewed against the evidence pack:** a completeness pass listed 10 gaps, 17 attribution or reference
corrections and 10 internal contradictions; all 37 were applied by hand on 2026-09-12, and §9 records
what was re-run, what was reproduced only approximately, and what is not independently verified.''')

# P2 verdict precision phrasing
rep(r'''64-document gold (0 false name keys of 79 predicted; relaxed precision 1.000 on 406 mentions), it''',
r'''64-document gold (0 false name keys of 79 predicted; 88 of 88 predicted spans overlap a gold mention;
gold n = 406), it''')

# P3 verdict clusterer claim + 83.1% grain
rep(r'''index** (97.8% of the documents it reaches carry only the from/to header names), and **under the
shipped `PersonClusterer` it manufactures confidently-wrong persons by default**: 83.1% of its rows
are single-token surnames, the clusterer auto-merges same-surname records of overlapping era, and
"Seward" resolves to two concurrent officeholders in every year of 1861–69 and 1876–80. That is the''',
r'''index** (97.8% of the documents it reaches carry only the from/to header names), and **read from the
shipped `PersonClusterer`'s code, it would merge confidently-wrong persons by default** (inferred from
`decide()`, §3.4 — the merge frequency over a real derived table is unmeasured, §7): 83.1% of its
mention rows are single-token surnames (the share of its ~30,327 entries is unmeasured), the
clusterer's rule merges same-surname records of overlapping era, and "Seward" resolves to two
concurrent officeholders in every year of 1861–69 and 1876–80. That is the''')

# P0 app view today (before "The two differ")
rep(r'''The two differ by the 1873 `correspondents` pair (#740, closed) and `frus1941-43` (#741, closed).''',
r'''Measured on the live index on 2026-09-12 the app view is **267 volumes / 198,936 documents** (§4.0):
`frus1873p1v1` gained its list under #740, nothing else moved, and the Program doc's 268 / 199,246 is
the 2026-08-07 figure the issue's framing quotes. The two populations differ by the 1873
`correspondents` pair (#740, closed — but only `frus1873p1v1` is actually read, §4.0) and `frus1941-43`
(#741, closed).''')

# P4 three keys paragraph
rep(r'''**Labels.** MEASURED = computed''',
r'''**Three normalised-surface keys, all called "K2" or "normalised surface" below, and they are not one
key.** The census (§2.1) folds casefold + whitespace + trailing possessive and strips ONE leading
honorific from a 29-token list, over ALL marked rows — its marked vocabulary is **11,377**. The gold
re-score (§2.2) strips honorifics repeatedly from a 74-token list — its 288 gold keys. The POCOM pass
(§2.5) strips from a 62-entry list over the from/to rows only — its marked vocabulary is **9,969**.
The three agree on every headline ordering and differ in the hundreds on vocabularies; no figure is
carried from one key's population into another's.

**Labels.** MEASURED = computed''')

# P5 raw-control union bullet
rep(r'''- **The frozen stopping rule (raw arms only: strict gap ≥ 10 AND same winner every band) is not''',
r'''- **Editor ∪ RAW NLTagger already reads 0.773 relaxed (P 0.767, R 0.778)** (`[SCORE-V]`
  `union_check.json`, post-hoc): the free-layer union beats every sweep arm before the frozen filter
  runs, so (b1) below depends on promoting `filter_detections.py` to a product rule for about two
  points, not for its standing.
- **The frozen stopping rule (raw arms only: strict gap ≥ 10 AND same winner every band) is not''')

# P27b strip-title source path (must precede the §8 m2a_analysis64 edit)
rep(r'''pre-registered metric (`m2a_analysis64.py`; reproduced `strip_titles.py`).''',
r'''pre-registered metric (`audit-2026-09-12-second-sitting/m2a_analysis64.py`; re-implemented in
  `strip_titles.py` at 0.661 against 0.653).''')

# P6 census header
rep(r'''(doc, K2) pairs = `person_mentions` rows''',
r'''(doc, K2) pairs — `person_mentions` rows under §4.a's one-ref-per-surface design''')

# P7 six/five
rep(r'''Six of the control's place surfaces are single tokens that are also personal names
(Bull, Haro, Arro, Rosario, Seville).''',
r'''Five of the control's place surfaces (9 mentions: Haro ×4, Rosario ×2, Bull, Arro, Seville) are
single tokens that are also personal names.''')

# P8 13.6× key note
rep(r'''(13.6× the marked layer's 9,969), of which 3.4% are uniquely anchored.''',
r'''(13.6× the marked layer's 9,969 distinct from/to surfaces under this section's key — §2.1's 11,377 is
every marked row under the census key, see §0), of which 3.4% are uniquely anchored.''')

# P9 12-volume un-anchorable share
rep(r'''and the M2a gold has no
identity column.''',
r'''and the M2a gold has no
identity column. On the 12-volume population the set is drawn from, **2,499 of 13,037** from/to names
(19.2%) are surname-known yet resolve to nobody or to several officeholders in the year
(`repro_pc2.out`), so roughly a fifth of the keyable rows are un-anchorable by the surname × year rule
by construction.''')

# P10 §3.4 file refs + bump wording
rep(r'''- `purgeNonPersonRows` (`:1080-1105` → `PersonListHeuristics.isLikelyPersonName :1391`) deletes any''',
r'''- `purgeNonPersonRows` (`IndexingPipeline.swift:1080-1105` → `FRUSDocumentParser.swift:1391`,
  `isLikelyPersonName`) deletes any''')
rep(r'''- `auxDeletePersonMentions(forVolumeId:)` (`:4573`, `:7375`) wipes''',
r'''- `auxDeletePersonMentions(forVolumeId:)` (`IndexingPipeline.swift:4573`, `:7375`) wipes''')
rep(r'''pattern (`:4630`, `:7682`).''', r'''pattern (`IndexingPipeline.swift:4630`, `:7682`).''')
rep(r'''override fingerprint changed` (`:913-917`)''', r'''override fingerprint changed` (`IndexingPipeline.swift:913-917`)''')
rep(r'''  is nevertheless mandatory in every shape because every shape changes the clustering rule**
  (CLAUDE.md rule; `currentPersonRollupVersion = 9`, `:863`).''',
r'''  is nevertheless required in every shape by the CLAUDE.md rule, because every shape changes the
  clustering rule** — a policy, not a mechanism: the drift check would rebuild without it
  (`currentPersonRollupVersion = 9`, `IndexingPipeline.swift:863`).''')

# P11 §4.0 rewrite
rep(r'''`frus1932v04`, `frus1918Supp01v02` and `frus1917Supp02v02` are in the 267 and carry **9,215** body
`<persName corresp="frus1932v03#p_JNT1">`-style marks into the sibling part's persons list (MEASURED,
`count_stores.json`, `linked_check.json`). The parser already reads `corresp` as the ref
(`FRUSDocumentParser.swift:1174-1176`); `normalizePersonRef` strips the `volumeId#` prefix
(`IndexingPipeline.swift:5287-5291`, doc comment at `:5299`) on the v13 premise that "each part carries its own copy of the
set's persons list" (`:456-463`) — false for these three (0 `persName xml:id` in each; `frus1932v03`
has 597). INFERRED from code, **not verified against a live index**: those 9,215 mentions land in
`person_mentions` for a volume with no `persons` rows and are invisible to every count — the v13
class the note says was closed — and the inline link resolves nothing. This is an editor-asserted
identity signal at zero model cost; a cross-part join, if it holds at runtime, changes both volume
censuses (app view and TEI rule) for three volumes before any of #234 is scoped, and any synthetic namespace must not collide
with those already-stored fragments.''',
r'''`frus1932v04` (794 documents), `frus1918Supp01v02` (912) and `frus1917Supp02v02` (459) are in the 267
and carry **9,215** body `<persName corresp="frus1932v03#p_JNT1">`-style marks — 5,028 / 2,890 / 1,297
of their 5,225 / 3,310 / 1,498 located marks — into the sibling part's persons list, which holds 597 /
267 / 212 `persName xml:id`s (MEASURED, `count_stores.json`, `linked_check.json`; the three TEI files
carry 10,616 such `corresp` attributes — 5,743 / 3,395 / 1,478 — of which 9,215 sit inside body
document divs). The parser already reads `corresp` as the ref (`FRUSDocumentParser.swift:1174-1176`);
`normalizePersonRef` strips the `volumeId#` prefix (`IndexingPipeline.swift:5287-5291`, doc comment at
`:5299`) on the v13 premise that "each part carries its own copy of the set's persons list"
(`:456-463`) — false for these three (0 `persName xml:id` in each).

''' + addendum + r'''

This is an editor-asserted identity signal at zero model cost. A cross-part join changes both volume
censuses (app view and TEI rule) for three volumes before any of #234 is scoped, and any synthetic
namespace must not collide with these already-stored fragments.''')

# P12 §4.a 83.1%
rep(r'''names per volume (max 696) `[CEN]`, **83.1% single-token surnames** `[APP]`, top entries seward / johnson / hay /''',
r'''names per volume (max 696) `[CEN]`, **83.1% of its mention rows single-token surnames** `[APP]` (the
entry-grain share is unmeasured), top entries seward / johnson / hay /''')

# P13 §4.a exactly + 0.89%
rep(r'''where this correspondent is named" exactly. Analytics trajectories over-count documents by **0.89%**
under COUNT(\*) (`[APP]`).''',
r'''where this correspondent is named" — 0 false keys on the 64-document sample, not a corpus-scale
guarantee. Analytics trajectories would over-count under COUNT(\*) by at most the last-token collision
proxy, **0.89%** (1,988 of 223,600 presence rows, `[APP]`) — a bound, not a measured over-count.''')

# P14 §4.a defect verdict
rep(r'''them**: the shipped clusterer would fold every same-surname derived entry of overlapping era across
the 61 volumes of the 1861–1899 band alone, and could bridge one into a sealed rollup. Its user-''',
r'''them**: read from its code, the shipped clusterer's `decide()` would merge same-surname derived
entries of overlapping era (within `eraGapYears = 30`) — across the 61 volumes of the 1861–1899 band
that is most of them, at a frequency not measured over a real derived table (§7) — and could bridge
one into a sealed rollup. Its user-''')

# P15 §4.b b1 per-document rates
rep(r'''**46 false keys / 64 documents ≈ 1 per 1.4**; per band P 0.845 / 0.949 / **0.745** / 0.783. Under
string equality F1 **0.697**.''',
r'''**46 false keys / 64 documents ≈ 1 per 1.4**; per band P 0.845 / 0.949 / **0.745** / 0.783. Under
string equality F1 **0.697**. Per document, the filtered control alone places at least one non-person
in **19 of 64** gold documents (false-positive-free in 45), the raw control in 30 (34 clean), the
filtered sweep in 53 (11 clean) (`reproduce_analysis.json` doc_level).''')

# P16 §4.b b2 misses + reach
rep(r'''surnames (Harding, Wolf, Rudolf, Seville) — placeName markup removes about 2 of them. Its misses are
the heading line, which the editor layer covers. The precision gain over (b1) excludes zero (+0.071
[+0.028, +0.128]); the F1 gain does not. Reach: 57 of 62 gold documents naming anyone for the
control side. **ACCEPTABLE as the only detected layer**, subject to an owner precision floor per''',
r'''surnames (Harding, Wolf, Rudolf, Seville) — placeName markup removes about 2 of them. Its misses are
dominated by the heading line, which the editor layer covers only in part (59 of the control's 61
heading-line misses, none of its other 89): after the union the arm still misses 67 of 288 keys
(R 0.767). The precision gain over (b1) excludes zero (+0.071 [+0.028, +0.128]); the F1 gain does
not. Reach: the filtered control alone reaches 57 of the 62 gold documents naming anyone; the
intersection's reach was not measured separately and, as a subset of the control's spans, is at most
57. **ACCEPTABLE as the only detected layer**, subject to an owner precision floor per''')

# P17 §4.c R-2 basis
rep(r'''for ~750k, so its candidate basis is stale ×1.7 (control) to ×3.5 (filtered sweep) / ×4.9 (raw);''',
r'''for ~750k (~250k marked + ~500k unmarked), so the like-for-like comparison is against the NOVEL
counts — control 1,273,179 (×2.5), sweep 3,406,323 (×6.8) — and the 3.9 h figure embeds 80,567
control rows that overlap an editor mark and need no re-embedding;''')
rep(r'''over 553 `~/frus-semantic-raw/vectors/*.head.json`, re-summed): R-2''',
r'''over 553 `~/frus-semantic-raw/vectors/*.head.json`, re-summed over heads written on two machines,
552 on the Studio and 1 on the Air): R-2''')

# P18 §4.d
rep(r'''mentions at P 0.44, and its 16 prose misses are bare surnames and all-caps signatures; (4) **the''',
r'''mentions at P 0.44 (relaxed, mention grain) and misses 7 presence keys (archibald campbell, aspíroz,
campbell, chou, george washington, king, william h. seward); the filtered sweep's own 28 misses are 16
unmarked prose names plus signatures and headings (§2.4); (4) **the''')

# P19 §5 gate (3) pre-1910 scores
rep(r'''by volume-id year** `[COST]` |''',
r'''by volume-id year** `[COST]`. The pre-1910 gold already exists — 27 documents / 229 spans from 9 volumes: filtered sweep strict 0.702 / relaxed 0.760, raw sweep 0.616 / 0.667, filtered control 0.379 / 0.708, editor baseline relaxed R 0.258 (`pre1910_check.json`) |''')

# P20 §5 M2a row
rep(r'''| M2a keyed | **done, 64 of 72**; the 8 unkeyed cannot move the stopping rule | owner (optional) |''',
r'''| M2a keyed | **done, 64 of 72**; simulation puts keying the 8 at 0–1 of 10,000 draws meeting the stopping rule (§1.2) | owner (optional) |''')

# P21 §5 R-2 row
rep(r'''cost basis stale ×1.7–4.9''', r'''cost basis stale ×2.5 (control novel) to ×6.8 (sweep novel)''')

# P22 §5 §4.0 row
rep(r'''| §4.0 cross-part corresp | measured in the store; **runtime effect unverified** | engineer | a live-index check; then a cross-part join or a decision to drop |''',
r'''| §4.0 cross-part corresp | **MEASURED in the live index**: 5,530 orphan `person_mentions` rows across the three volumes against 0 `persons` rows, 6,288 orphans corpus-wide, plus `frus1873p1v2`'s unread list (454 rows) | engineer | a cross-part join (or a decision to drop the rows) and the `correspondence` spelling in `personsSectionIds` — both #740 / v13-class defects, filed separately from #234 |''')

# P23 §5 floor row
rep(r'''| precision floor for any detected layer | **unset** | **owner** | a per-band floor against: agreement ≈ 1 wrong name per 2.6 docs (P 0.745 in 1930–45); NLTagger ≈ 1 per 1.4 (P 0.698 in 1930–45); n = 64 |''',
r'''| precision floor for any detected layer | **unset** | **owner** | a per-band floor against (post-hoc, n = 64; the 1930–45 band is 15 documents / 44 gold keys): editor ∪ agreement arm ≈ 1 wrong name per 2.6 docs (25 / 64), 1930–45 P 0.745 [0.633, 0.897]; editor ∪ filtered NLTagger ≈ 1 per 1.4 (46 / 64), 1930–45 P 0.745 [0.629, 0.898]; filtered NLTagger alone 1930–45 P 0.698 [0.567, 0.875] |''')

# P24 §6.2 step 0
rep(r'''1. **Step 0 first** — a runtime verification of what §4.0 found by reading code, in the three split-set
   volumes, and a re-run of the app-view "contributes zero people" census for them. It is a shipped
   defect of the v13 class, not a #234 feature, and it is the cheapest early-era gain in the whole
   program.''',
r'''1. **Step 0 first** — the §4.0 cross-part join, now verified in the live index (5,530 orphan mention
   rows over 2,165 documents in the three split-set parts), and the `correspondence` spelling that
   leaves `frus1873p1v2`'s 57-entry list unread. Both are shipped defects of the #740 / v13 class, not
   #234 features, and together they are the cheapest early-era gain in the whole program.''')

# P25 §6.3 83.1%
rep(r'''asserted neither same nor different, and 83.1% of them bare surnames. Refusing it refuses (a) and''',
r'''asserted neither same nor different, and 83.1% of the mention rows behind them bare surnames.
   Refusing it refuses (a) and''')

# P26 §7
rep(r'''- **Whether the §4.0 orphan rows exist at runtime** — inferred from code only.''',
r'''- ~~Whether the §4.0 orphan rows exist at runtime~~ — **settled**, measured in the live index (§4.0);
  what remains open is the cross-part join's design.''')

# P27 §8 fixes
rep(r'''`sim8.py`, `filter_in_sample.py`, `sum_heads.py`''', r'''`sim8.py`, `filter_in_sample.out` (its script was not kept), `sum_heads.py`''')
rep(r'''`m2a_analysis64.py`, the typed annotation files.''', r'''`audit-2026-09-12-second-sitting/m2a_analysis64.py`, the typed annotation files.''')
rep(r'''`FRUSExplorer/Search/IndexingPipeline.swift`, `PersonClusterer.swift`, `SearchFilterView.swift`; `FRUSExplorer/Models/PersonMentionStore.swift`, `SavedSearch.swift`, `PersonClusterOverride.swift`, `CloudKitSchemaInventory.swift`, `PersonRollupRefresh.swift`, `SearchModels.swift`;''',
r'''`FRUSExplorer/Search/IndexingPipeline.swift`, `PersonClusterer.swift`, `SearchFilterView.swift`, `SearchModels.swift`; `FRUSExplorer/Models/PersonMentionStore.swift`, `SavedSearch.swift`, `PersonClusterOverride.swift`, `CloudKitSchemaInventory.swift`, `PersonRollupRefresh.swift`;''')
rep(r'''- Stores: `~/frus-ner-raw/{scope.json,marked/}`;''',
r'''- Stores: the live index `~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db` (read-only, `mode=ro`, index version 50, 552 volumes / 316,839 documents); `~/frus-ner-raw/{scope.json,marked/}`;''')

# P28 §9
rep(r'''Nothing under the repository, `~/frus-*`, or the Mac Studio folder was modified by this assessment;
no git state changed.''',
r'''Nothing under the repository, `~/frus-*`, or the Mac Studio folder was modified by this assessment;
no git state changed.

---

## 9. Verification of this document

**Re-run or reproduced independently before being quoted** (by two verifier passes per report; † =
also by hand in the writing session):
- the six published strict / relaxed rows — the official scorer re-run plus two independent scorers,
  dict-equal to `score-detections.json`;
- both runbook unions (0.794 / 0.646), which reproduce only under exact-duplicate dedup;
- the census — twice, with an independent key implementation; artifacts byte-identical;
- M1a Measurement 3 — reproduced exactly from its verbatim code against today's POCOM checkout;
- every FP and miss count — the scorer's own residues, recounted by a second script;
- the harvest totals — re-summed from all 267 heads of each store;
- the 9,215 cross-part `corresp` rows — recounted from the marked layer, and the TEI's 10,616
  `corresp="<sibling>#…"` attributes (5,743 / 3,395 / 1,478) re-grepped †;
- the live-index rows in §4.0 — queried read-only on 2026-09-12 †;
- the `PersonClusterer` and `IndexingPipeline` lines cited in §3.4 and §4.0 — re-read at HEAD
  `bd394443` †.

**Reproduced only approximately, and quoted with that caveat:**
- the "0 of 10,000 draws" simulation for the 8 unkeyed documents — 0–1 of 10,000 under a different
  seed;
- the stripped-title check (0.653 vs 0.563) — 0.661 on re-implementation;
- the band-stratified bootstrap intervals — within 0.3 points across two implementations and seeds.

**Not independently verified:**
- the "+57 mentions" non-determinism figure (§1.4 item 7), which conflates decoding non-determinism
  with an OS / LM Studio build change between the two pilot arms;
- every FP and miss CATEGORY in §2.4 — one reader's judgement, corroborated only by the second
  audit's zero missed mentions;
- the session budgets, the R-2 hours, the dollar lines and every threshold in §6.4 — INFERRED;
- the frequency of the clusterer's default merge over real derived rows — the mechanism is read from
  code; the count was never run;
- corpus-scale precision of any arm — unbounded by any measurement here.

**How this document was produced.** Eight evidence agents (four readers, four measurers), two
verifiers per report (one re-deriving the numbers, one auditing the method), four assessors under
distinct lenses, two scoring judges, one synthesis writer and one completeness critic — 32 model
instances in one orchestrated run on 2026-09-12; the critic's 37 items and the live-index measurement
were applied by hand afterwards, with every replacement checked to match the draft exactly once. The
M2a audits it cites were model adjudicators too (§1.4 item 5). Every number here traces to a script
and output path under §8; none was carried from a model's memory.''')

failed = []
for old, new in pairs:
    n = src.count(old)
    if n != 1:
        failed.append((n, old[:90].replace('\n', '⏎')))
        continue
    src = src.replace(old, new)
open(out_path, 'w', encoding='utf-8').write(src)
print(f'{len(pairs)-len(failed)} of {len(pairs)} replacements applied')
for n, o in failed: print(f'  FAILED (matched {n}x): {o}')
