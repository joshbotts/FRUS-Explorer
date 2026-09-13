# Changelog: reframe-delta.md → reframe-delta-v2.md

Date: 2026-09-13.

**Inputs.**
- The draft: `reframe/synthesis/reframe-delta.md` (left untouched).
- The critique: `reframe/critique/critique.json` — 32 corrections, 12 gaps and 14 contradictions — and its one new measurement, `era_reach.py` → `era_reach.json`.
- The five verification objects in `reframe/journal-results.json`.
- The evidence folders.

**How to read the "how" column.** Section numbers refer to v2. "Applied" means the critic's replacement text was used, adapted only to v2's key and population names. Where the evidence showed a replacement was itself wrong, the entry says so.

No LLM or token-count API was called. Figures were re-checked with the system `python3`, standard library only, against these files:
- `measure-se-pocom/out/merged-rule.json` and `hunter-labels.json`;
- `measure-claude-jobs/pools.json` and `summary-costs.md`;
- `verify-measure-claude-jobs/vcost.json`;
- `read-claude/pricing/pricing.json` and `disagreement/disagreement.json`;
- `measure-offsets/fts-timing.json` and `verify-measure-offsets/v3-checks.json` / `v4-fts.json`;
- `measure-silver/sample-design.json`;
- `measure-agreement/summary.json`;
- `read-app/manifest_people_tags.json`;
- `llm-pass/program-fit/pilot_cost.json`;
- FA lines 30–40, 188–195, 455–462, 625–645, 775–840 and 898–930.

## Corrections (32)

| # | item | applied | how |
|---|---|---|---|
| C1 | "The commonest label, the U.S. mission" misquoted (N12; §3.5 reach and verdict) | yes | N12 and §3.5 Reach now give rows by own role from MSE `label_signatures` (Department 26,254 of 52,616; single U.S. mission 13,796; two-way 8,551; foreign legation 3,404; U.S. consulate 542; the signatures sum to 52,616, re-checked). The §3.5 verdict names the Department as the majority label, with proxy evidence missing for 42.5% of labelled rows (22,347 of 52,616, INFERRED). The critic wrote "about 42%"; the exact share is used. §1 and §3.0 follow. VSE's own summary also calls the U.S. mission "the commonest own role", which is where the draft's wording came from; v2 follows MSE's counts. |
| C2 | Filing-role label called identity-free, against §1's post-claim rule | yes | §3.5 "Identity asserted" now reads "No identity, but a post claim about the named side", with the `frus1861/d21` example. N12 is keyed blind as a post claim. Gate 10 names the label as such a claim. Gate 17 and §3.5 Gates require document-attached wording ("filed as a despatch from the U.S. legation in Belgium"). §3.0 rank 8 and §1 follow. |
| C3 | FTS timings mislabelled "volume-scoped" (§3.8) | yes, with one figure corrected | §3.8 Cost gives the 267-volume join counts: Seward 4.4–4.9, Hull 10.5–12.1, Wells 73–474 ms. These were re-checked (MOF 4.4–4.6 / 11.5–12.1 / 84–474; VOF `v3-checks.json` 4.8–4.9 / 10.5–10.7 / 73–76). **The critic's "one volume through a join: 3–72 ms" repeats MOF's prose, but MOF's own `fts-timing.json` records 0.24–0.39 ms for Bliss and 0.25–0.27 ms for Blaine,** so v2 gives 0.24–72 ms and names the discrepancy (also §4.4 erratum 9). `rowid BETWEEN` 0.01–0.03 ms is marked not reproduced by VOF (VOF's own note). |
| C4 | N1's 21–33% text share came from RC's design, not the priced jobs | yes | N1 now gives MCJ's merged ±300 windows: 310,674,650 (45.7%) and 346,287,109 (51.0%), plus 30.8M / 41.9M of listings (re-checked in `pools.json`). RC's 144.4M (21.3%) / 226.8M (33.4%) are given beside them. The 2× cost gap is reconciled in the new §3.9.1. |
| C5 | [V] overclaimed on pilot costs, the 9,954 sections and per-chapter guide costs | yes, extended | [V] removed in §3.9 Cost (screen costs), §4.2 pilot row, §5 step 7 and §3.10 (9,954 sections; per-chapter costs). Also removed from §3.13's "with document text" adjudication costs, because `vcost.json` holds no C+doc row either (re-checked: jobs A, B, C:armB and D only). [V] kept on A / B / C rows-only / D per volume and the headline totals. |
| C6 | "W. H. assigned to 113 of 113" tagged [V] though VSE did not re-derive it | yes | [V-part] in gate 5(a), §3.11 F. W. Seward bullet and §4.3 facts row. Each names what VSE reproduced (117 rows; shown 68 → 113; sender pattern 106; rule decides 0) and what is MSE only (113 of 113 shown; 117 under T_after). |
| C7 | Key and population mixing (758,194 vs 768,928; three sets called "queue"; the 119,094 placement) | yes | §0 gains a "Pair keys" table (census K2 / grains key / RC surface key / k2_surface) and three names: three-way union (1,841,697), census net pool (1,072,769), priced adjudication queue (1,051,899; 929,012 new). Applied in gates 20 and 21, §3.2, §3.7, §3.9 (table and Quality, where the 11.1% share is stated to apply to the census pool, with VCJ's 122,887 for the priced queue), §3.9.1, §4.1 sweep row, N20 and §7.2 item 11. |
| C8 | 82.4% vs 90.4% compared a roll-tested arm with an untested one | yes | §4.3 facts row and the P3 "9 in 10" row now read: T_after corroborates 41,020 of 45,258 (90.6%), matching the approximation's 40,907 (90.4%); shown rose 36,269 (80.1%) → 37,301 (82.4%). The gap is the roll test. |
| C9 | "157 known documents" mixed 1900–1905 into an 1861–1899 SE-DOC-AY share | yes | §4.3 P3 "23%" row: 14.1% (SE-DOC-AY), plus a known residual of 148 documents in 1861–1899 scope volumes (SE-DOC-VY; a subset) and 9 in 1900–1905. N13 is worded the same way. |
| C10 | Pilot and local controls scored on the only fresh confirmation sample; central-only spend; mislabelled confirmation cost; unpriced whole-document arm | yes, with one addition | §5 split into a step 7 screen on the 64 gold documents only, a step 8 freeze by hash, and a step 9 confirmation on 6(c). Step 7 gives Opus 5 standard high effort as $1.6 central / $10.2 high (queue) and $1.4 / $10.1 (arm filter), plus other treatments, and P2's up-to-about-$150 thinking allowance. The confirmation cost is labelled RC R6's whole-document, detection-shaped estimate. The critic said the whole-document arm is unpriced; v2 agrees no such price exists, and adds the nearest priced shape, LP `pilot_cost.json` S1-c (Sonnet $10.21–10.83, Opus $25.54–27.08, 3 replicates, standard), labelled as a nearest shape. §4.2 pilot row and §3.9 Cost follow. |
| C11 | Step 12 shipped an identity tier on a POCOM-agrees-with-POCOM stratum that cannot meet FA §6.4 | yes, one claim not carried | §5 step 14 uses the replacement text: two-signal-agreement stratum only; convention-narrowed, location-narrowed, F. W.-initial and all 1861–69 Seward rows excluded until tier B passes; FA §6.4 per band; a measured Seward-type rate. §3.11 Gates says tier A licenses 37,301 shown rows, not 45,258 / 8,642 / 2,081. **Not carried: the critique's problem statement says "a single error fails" at n = 25.** `sample-design.json` gives a one-error Wilson lower bound of 0.8046 at n = 25, which is ≥ 0.80. FA §6.4 also reads as a threshold on the estimate with stated half-widths (±11.3 per 75-row band). v2 therefore states only that FA §6.4 is set on 75-row bands: tier A's 100 rows fill one band for 1861–1899 as a whole, and a per-decade claim would need about 75 rows per decade (INFERRED). |
| C12 | Step 11 corpus pass bypassed pre-1910-first, quoted only the low-effort high scenario, and had no post-run check | yes | §5 step 12 runs the frozen verifier over PRE1910 first, then a blind-keyed audit (N21). Step 13 extends to the corpus in stages, each audited, with caps by treatment including standard high effort: arm filter $4,395 / $11,250, queue $4,310 / $11,045 (re-checked in `vcost.json`). N10 recording is required. |
| C13 | §1 "Cost therefore stops binding" | yes | §1 now uses the replacement: small beside the gates at central batch estimates; high scenarios about 5× central ($444 → $2,265; up to $22,548), so every phase needs a cap. |
| C14 | §3.6 per-volume nodes said to assert no identity | yes | §3.6 Identity asserted and Quality now say per-volume nodes fold the concurrent Sewards (1861–69 W. H. + F. W.; 1876–80 G. F. + F. W.; FA line 460). Verdict is conditional on N17's labelling rule. N17, §2.2 decision 1, §3.0 rank 9 and §6 decision 2 follow. |
| C15 | "The one untagged-people surface that already ships"; filtered-store counts used for an unfiltered lens | yes | §3.4 Reach lists the other shipped surfaces. §3.4 Quality says the lens is unfiltered and the filtered-store figures are a lower bound on its noise. New §3.19 covers OH tags and FTS; §3.15 covers the summary templates; §1 follows. |
| C16 | "computed live in the Research rail with no reindex" | yes | §3.5 Cost: a document-level role can be computed live; attaching it to editor-marked sides needs the markup data layer. |
| C17 | Census-format sizes presented as the feature's artifact | yes | §3.2 Cost, §3.7 Cost, gate 18 and §5 step 4 call them a census-format proxy, with no app-shaped size measured (VAG). |
| C18 | Correspondents engineering omitted the data layer | yes | §3.2 Cost and §5 step 4: 2–3 sessions for the two surfaces plus an unsized isolated data layer. RA's 2–3 (parse-time) and 3–4 (artifact) are given as the closest figures. Gate 11 also names the generator or index table and the removal hook. |
| C19 | Erratum 2 overstated; FA already named the seeds | yes | §4.4 erratum 2 reworded as replaced. §1, §3.2 Quality and §4.1 row follow the narrower reading (FA line 664 names the seeds; the defect is presenting P 1.000 as measured quality). |
| C20 | §0 "no corpus text left the machine" | yes | The preamble's "What left the machine" uses the replacement, with the three examples (MSE/VSE headers, VAG `samples.json`, LP `cases.txt` 141,512 bytes, re-checked). Gate 2 no longer treats in-session reads as an exception. N1 requires the authorization to state whether in-session reads are covered, and records that they occurred. §4.2 subagents row and §6 decision 5 follow. |
| C21 | §4.1 "Dollar lines superseded by the MCJ job prices" | yes | §4.1 row: superseded for editor-marked correspondents only. Identity adjudication over detected surfaces remains priced only by FA §4.c's rescale and RC's 301,979-row shape (Sonnet $137 / Opus $325 central, INFERRED, LP `costs.json` via RC [R]). |
| C22 | Queue yield on the gold presented without being called a ceiling | yes | §3.9 Quality uses the replacement (at most 58 of 330, 17.6%; 241 overlap no gold mention; lenient any-overlap credit; no scorer-matched count). |
| C23 | Recall-job ceiling omitted its per-band limit | yes | §3.9 jobs table recall row gives per-band P 0.985 / 0.977 / 0.772 / 0.884 (re-checked in `disagreement.json`), and the precision row per band 1.000 / 0.973 / 1.000 / 1.000. §4.2 row, §2.2 decision 5 and §5 step 9 order the arm filter before or with any recall job. |
| C24 | 0.7575 read as the bound for all 100 pre-1910 rows | yes | §4.2 row uses the replacement: 0.963 overall; 0.7575 for the 12 several-candidate rows. |
| C25 | "Falls into no proposed stratum" labelled MEASURED; N15 banded by document year without saying so | yes | Gate 10 labels it INFERRED. N15 gives both keys: by TEI document year 12,405 heads / 20 volumes; by volume-id year 15 volumes / 9,912 documents (9 / 6,193 in 1900–1905; 6 / 3,719 in 1906–1909; `era_reach.json`). |
| C26 | 14,495 mislabelled as "after #1292" | yes | §3.13 Reach lists B0 13,907, B_after 14,495, S_after 13,252 and T_after 14,485 (2,536 + 2,167 + 9,263 + 509 + 10, re-added). |
| C27 | Hunter "193 of 197 right" / "the role still holds" | yes | §3.5 paragraph retitled "the label still appears" and reworded: labelled Department for 193 of 197, consistent with 194 datelines; correctness unkeyed. The §4.3 P3 "contradictions" row is reworded the same way. |
| C28 | 46 of 288 gold keys used for a markup-only list | yes | §3.2 Quality: duplication inside a markup-only list not measured; 46 of 288 applies to all gold keys; 8.9% (19.5% in 1861–1899) of added pairs share a last token with an editor key (census K2; re-checked in MAG `summary.json`). |
| C29 | Offset claim generalised beyond the sample; decoder caveat omitted | yes | §3.3 Quality: "every sampled detected span (two independent 400-document samples)", with the second sample's 6,447 / 3,249 and VOF's XML-decoder caveat. |
| C30 | Gate 20 "unchanged" but "Met" | yes | Gate 20 effect: discharged for reach and census-format size, precision still unmeasured. Status names census K2. |
| C31 | §5 dependency rule contradicted step 6 and §3.11 | yes | §5 has a "needs" column. 6(a) needs step 5; 6(b), 6(c) and 6(d) are independent and can start at once. |
| C32 | Combined silver figure readable as a precision | yes | §3.11 silver bullet adds: agreement over registry-covered heads, not a precision; three namesake pairs (649 / 619 / 88); TEI-document-year bands (volume-id key: 1930–1945 0.930). §7.2 item 15 follows. |

## Gaps (12)

| # | item | applied | how |
|---|---|---|---|
| G1 | No disposition for #234's named surfaces or the surfaces that inherit person rows | yes | New §3.16 table covers the People browser list and detail sheet, person search (autocomplete, filter, saved searches), Person Analytics, the co-mention graph, Related documents' shared-people axis (weight 0.7), the Collections Persons Index and exports, the results People facet, the custom-scope person facet, and the front-matter list / inline links / affinity. For each it gives what isolated carriers deliver (none), the nearest separate view, and what folding in re-imports. Also §1, §2.2 decision 2 and §6 decision 9. |
| G2 | Shipped, ungated on-device summary templates that name participants from memory | yes | New §3.15 card (templates, `GeneratedSummary` synced `@Model`, `summary_text` FTS indexing; DOCUMENTED, RA). Gate 5(d), N23, §3.0 rank 5, §6 decision 14, §7.1 row and §7.2 item 16. |
| G3 | Identity-free carriers RA mapped; OH volume tags and FTS as shipped surfaces | yes | New §3.17 (citation note, Chronology rows, trip-packet pull list), §3.18 (Posts axis, pre-1906 archival analytics, series dashboard card, semantic-map post lens) and §3.19 (OH tags: 647 assignments on all 267 untagged volumes; FTS; plus pointers to 3.4 and 3.15). §3.0 ranks 6, 7 and 12. |
| G4 | Source Explorer / POCOM-chapter era ceiling never stated | yes | §0 ERA-REACH population; §1; §3.5, §3.11 and §3.13 Reach; §3.17–3.18; N13; N15; §4.3 P3 "after 1900" row; §7.1. 38,953 of 197,534 (19.7%, MEASURED) and 158,581 (80.3%, INFERRED). |
| G5 | Owner keying time unsized | yes | New §2.5 table: the one documented estimate (FA §5: ~2–3 h for 300 rows, with FA's "halves it" note for 100 pre-1910 rows), FA's INFERRED 2–4 h R-3 sitting, and every other instrument marked not priced. N20 asks that sitting durations be recorded. §6 decision 8 and §7.1 follow. |
| G6 | `frus1941-43` missing from the exclusion list; `frus1873p1v2` not stated as outside TEI-267 | yes | §3.1 Gates and new N24: `frus1941-43` (81 `persons` rows, 0 `person_mentions` at v50; VSI [V]) added; `frus1873p1v2` stated as outside TEI-267 (FA §4.0). |
| G7 | No seeding decision for the fresh detection sample | yes | N3, N4, §2.3 detected-layer trigger, §2.5 and §5 step 6(c): keyed unseeded, or seeded with planted wrong spans and disclosed, before any markup-precision claim is scored on it. |
| G8 | Detected tier and Claude path not ordered pre-1910 first | yes | Gate 3, §3.7 Gates, §3.9 Gates, §5 step 12 (pre-1910 pass for the detected tier and any frozen verifier before step 13's corpus stages). |
| G9 | No post-run audit | yes | New N21; §5 steps 12 and 13; §3.7 and §3.9 Gates. |
| G10 | Two cost bases never reconciled | yes | New §3.9.1 table (window, populations, characters sent, Sonnet and Opus central for each design). It explains what drives the gap and why high scenarios differ in treatment, and that caps use MCJ. §0 dollar-figure note, §6 decision 15 and §7.1 follow. |
| G11 | Reusing the Likely/Possible chip implies calibration | yes | New N22; §3.5 Gates; §2.2 decision 6; §5 step 10; §6 decision 3; §7.1; §7.2 item 18. |
| G12 | Recall job's band limit omitted | yes | As C23: §3.9 table, §2.2 decision 5, §4.2 row, §5 step 9 ordering, §7.2 item 17. |

## Contradictions (14)

| # | contradiction | resolved | how |
|---|---|---|---|
| K1 | §1 post-claim rule vs §3.5 "Identity asserted: No" | yes | Via C2: §3.5 now names a post claim and requires N12. |
| K2 | §1 "Cost stops binding" vs N2 and §7.2 item 12 | yes | Via C13. |
| K3 | §3.6 "None while nodes stay per volume" vs concurrent Sewards | yes | Via C14. |
| K4 | §2.3 identity "tightens" vs a tier on 100 agreement-stratum rows at 25 per decade | yes | Via C11. §2.3 adds that a single-stratum tier licenses only that stratum; §3.11 and §5 step 14 apply FA §6.4. |
| K5 | "64 documents are a screen; confirmation needs a fresh sample" vs pilot and controls scored on 6(c) | yes | Via C10: the gold is the screen (step 7), 6(c) is used once for confirmation (step 9) after the freeze (step 8). N3 and §2.3 say it is used once. |
| K6 | Gate 3 "pre-1910 first tightens" vs whole-corpus step 11 | yes | Via C12 and G8: §5 steps 12–13. |
| K7 | Gate 20 "unchanged" vs "Met" | yes | Via C30. |
| K8 | §3.4 "the one untagged-people surface" vs RA | yes | Via C15 and §3.19. |
| K9 | §3.5 "live, no reindex" vs RA's data-layer requirement | yes | Via C16. |
| K10 | "commonest label, the U.S. mission" vs label_signatures | yes | Via C1. |
| K11 | §4.1 "superseded" vs MCJ notMeasured | yes | Via C21. |
| K12 | §0 "no corpus text left the machine" vs in-session reads | yes | Via C20. |
| K13 | §5 "each step needs the one before" vs step 6 parallelism and §3.11 | yes | Via C31: explicit "needs" column. |
| K14 | Agreement arm 758,194 vs 768,928 unkeyed; "queue" naming three sets | yes | Via C7. |

## Verifier issues (method and label problems in the five verifications)

| verification | issue | reflected in v2 | how |
|---|---|---|---|
| VOF | Footnote share undercounted (5.6% / 4.9% → 6.8% / 6.8%) | yes | Carried from the draft in §3.12 and N16. |
| VOF | End-to-end "unverified" tranche verifies at 100% | yes | §3.12 figures (88.3% / 88.8% correct, 0 wrong). |
| VOF | Wrong metric for the converter route (uniqueness) | yes | §3.12: 11.9–16.7% newly wrapped occurrences, neither precision nor recall. |
| VOF | 358/400 raw equality is sample-specific | yes | §3.3 relies only on post-decode identity (800/800). |
| VOF | FTS phrase confirmation is tautological | yes | §3.3 says FTS confirms known names only and cannot discover names. |
| VOF | Entity decoder should follow XML rules | yes | Added to §3.3 (C29). |
| VOF | FTS population is app-view documents in the TEI-rule volumes | yes | §3.8 label. |
| VOF | 1,000-name-list and `rowid BETWEEN` timings not reproduced | yes | §3.8 marks `rowid BETWEEN` as not reproduced (the 1,000-name figure is not used). |
| VCJ | Gold yield ceiling arithmetic mixed populations | yes | C22. |
| VCJ | 122,887 queue pairs repeat an arm key (929,012 new) | yes | §0 keys, §3.9 table and Quality, N20. |
| VCJ | Job B is a filter, not a precision audit | yes | §3.9 verdict, N21. |
| VCJ | Local-hours range mixed two time models | yes | §4.2 local-option row (367.7 or 369.4 h). |
| VCJ | Job D key is `k2_surface`, not census K2 | yes | §0 keys; §3.10 Cost. |
| VCJ | Identity pilot sample is unkeyed | yes | §3.11, §3.13, §4.2 rows; N4. |
| VCJ | Arm B post-#1292 is not "Source Explorer as merged" | yes | C26 in §3.13. |
| VSI | `silver.py` double count (Page 1,678 heads) | yes | §4.4 erratum 8. |
| VSI | "1900–1929" silver band is 1910–1919 only | yes | §0 SILVER, §3.11, N15. |
| VSI | Band key differs from the assessment (0.939 → 0.930) | yes | C32 in §3.11. |
| VSI | Combined figure excludes unscoreable picks | yes | §3.11 silver bullet. |
| VSI | Negative-silver errors concentrated in namesake pairs | yes | C32 in §3.11; §7.2 item 15. |
| VSI | Circularity is a hypothesis for 1946– | yes | §7.1 row. |
| VSI | 286 list volumes, not 285 | yes | §0 SILVER row. |
| VSI | 79% of 1930–1945 both-same rows rest on POCOM-derived gold | yes | §4.3 P3 post-1905 proxy row and §4.4 erratum 7. |
| VSI | Planted-error bounds are Wilson bounds | yes | N4 names Wilson and exact bounds. |
| VSI | Stratum sizes predate #1292 | yes | Added to §3.11 Gates. |
| VAG | Gold P depends on the tie-break (0.898 / 0.882) | yes | Gate 16, N5, §3.7, §4.1, §4.4 erratum 3. |
| VAG | Three-way pool is not purely disagreements (119,094) | yes | C7 in §3.9. |
| VAG | Last-token duplication understated (19.2%) | yes | Gate 21, §3.7. |
| VAG | "Body prose" includes lists and tables (66.8%) | yes | §3.7 Reach. |
| VAG | ~78,000 illustration biased low (~95,000) | yes | §3.7 Quality. |
| VAG | POCOM parser minor difference | yes | §4.1 POCOM ceilings row (VSE's Monroe block, 5 rows). |
| VSE | Monroe attribute-bearing POCOM block skipped (5 rows) | yes | §4.1 POCOM ceilings row. |
| VSE | Corroboration compares POCOM with POCOM; chief-of-mission part not reproduced | yes | §1, §3.11, §4.3, §7.1. |
| VSE | Label categories from candidates, not shown resolutions (604 documents) | yes | §3.5 known failure classes. |
| VSE | U.S.-mission label supported only by 1873 | yes | N12, §3.5 (with C1's corrected ranking). |
| VSE | 1873 proxy validates role kind only | yes | §3.5 proxies table. |
| VSE | 91.8% header proxy is Department-dominated | yes | §3.5 proxies table. |
| VSE | "1900–1905" is this program's own cut | yes | §0 SE-ROWS row. |
| VSE | 85.9% coincidence between two populations | yes | §7.2 item 14. |
| VSE | Hunter's last pre-gap POCOM post ends 1855-10-31, not 1855-05-07 | not applicable | v2 quotes no pre-gap date; the window and counts are unaffected. |
| VSE | Department-only 1873 evidence rests on 3 distinct entries, not 6 | not applicable | v2 quotes no Department-only entry count; the rate is unaffected. |

## Task requirements beyond the critique

| requirement | how |
|---|---|
| §0 claim about corpus text; N1 covers in-session reads | "What left the machine" paragraph before §0; gate 2; N1 unblock column (C20). |
| §1 verdict consistent with every change | §1 rewritten: filing-role label as a post claim needing a keyed sample; cost binds at high scenarios; Source Explorer era ceiling; isolated carriers deliver none of #234's named surfaces; four shipped surfaces including the ungated summary templates. |
| §5 respects every standing rule | §5 rebuilt: screen on the gold (step 7) → freeze by hash (step 8) → one confirmation on 6(c) (step 9); pre-1910 before corpus with a keyed audit (steps 12–13); tier A licenses only its stratum and must meet FA §6.4 (step 14); caps by treatment with high scenarios; 6(a) needs step 5, 6(b)–6(d) independent. |
| Structure kept, sub-sections added, "Changes from the draft" note | Sections 0–7 kept. Added §2.5, §3.9.1 and §3.15–3.19; the note sits at the end of §0. |

## Not applied, or applied with a change

- **C3, per-volume join latency.** The critic's "3–72 ms" repeats MOF's prose. MOF's own JSON shows 0.24–72 ms across its ten surnames, so v2 uses the JSON range and records the discrepancy.
- **C11, "a single error fails" at n = 25.** Not carried. The one-error Wilson lower bound at n = 25 is 0.8046 (`sample-design.json`), which meets ≥ 0.80. The replacement text's substance, 75-row bands per FA §6.4, is applied.
- **VSE's Hunter date and 1873 Department-only entry count.** Not applicable: v2 quotes neither figure.


## Residual fixes after the independent check (applied by hand)

The check agent rated v2 ready with fixes: 4 unresolved items and 10 new errors. All 14 are applied.

- Step 9 spend: the windowed verifier is unpriced and must be priced with both treatments before the run. RC R6 is described as the S1-c whole-document shape, a characters-per-token range with a thinking allowance included.
- Step 12 and §3.7: produce, audit (N21), then ship.
- N12 and §2.5: 75 rows per shipping cell; the per-row rate from FA's 300-row estimate is INFERRED and does not transfer.
- Key table: persons-row key (30,327) and RC per-volume from/to key (28,280) added; §7.2 item 14 now names six keys.
- Filing-role proxies: every major label kind has out-of-population proxies, and the U.S.-mission label's conflict (192 of 193 in 1873, 0 of 33 in 1900–1905) is stated. Checked against proxy-1873.json and proxy-headers.json (Department 1,002 of 1,047; two-way 100 of 116; U.S. mission 0 of 33).
- "detection-shaped" replaced with the S1-c shape in §3.9.
- [V] removed from 0.9513 at n = 75, the 588,607-byte census proxy, and the 95.7% / 1.3% head format ([V-part]).
- 'johnson' and 'wilson' are mention counts (census.py: K2 -> mention count).
- Step 2 now fixes N4 and the 6(c) seeding choice; 6(a) and 6(b) need 2 and 5; 6(c) and 6(d) need 2.
- Trip packet: conditional on a keyed archival-suggestion sample or a disclosure; N22's unblock names the claim the chip is attached to.
- Chronology rows: heading as printed, dateline attached to the document, no parsed direction.
- Band key named (TEI document year) on the 68.0%, 76.0% and 95.7% figures.
- Cost labels: the 22,688-row prices carry batch+cache, low effort; the costs.json lines read INFERRED, DOCUMENTED in costs.json.
- §3.3 cost: included in 3.2's sessions.
