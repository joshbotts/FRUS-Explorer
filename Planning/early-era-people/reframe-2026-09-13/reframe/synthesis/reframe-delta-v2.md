# #234 reframed: assessment delta (v2)

Date: 2026-09-13. This revises `reframe/synthesis/reframe-delta.md` after an independent critique (`reframe/critique/critique.json`). The change log is `reframe/synthesis/reframe-delta-v2-changelog.md`.

**The reframe.** #234 was "extend the People browser, person search, person analytics and the co-mention graph to the FRUS volumes whose editors published no persons list". The proposed reframe is "make maximum possible use of the Qwen harvest, NLTagger, POCOM, Source Explorer, and Claude verification/synthesis to develop features for untagged people".

**What this file does.** It states how the reframe changes three assessments:
1. the feasibility assessment merged in PR #1290;
2. the in-session answer on a Sonnet or Opus pass;
3. the in-session answer on Source Explorer chapter context.

**What left the machine.** No scripted LLM or token-count API call was made to produce this file. Corpus snippets were read inside Claude Code sessions, which send them to Anthropic. Examples: document headers such as "Earl Russell to Lord Lyons" in the Source Explorer measurement and its verification; the verification samples in `verify-measure-agreement/samples.json`; and the 80 identity cases in `llm-pass/identity/cases.txt` (141,512 bytes). Gate N1 records this.

## 0. Reading rules

**Labels.**
- MEASURED: computed by the script named beside it.
- DOCUMENTED: read in the file named beside it.
- INFERRED: arithmetic or judgement on other figures.

A ceiling is never a precision.

**Verification tags**, appended in square brackets:
- **[V]** An independent verification script reproduced the figure, exactly or within a difference the verifier explained (such differences are named where they matter).
- **[V-corr]** The verification disagreed. The corrected figure is used, and the original is named where it matters.
- **[V-part]** Only part was reproduced. The unreproduced part is named.
- **[R]** Reported by one of the three reader agents. The evidence contains no verification block for the readers, so the figure carries only its own label. Where the output file was opened directly, the tag reads [R, file read].

A figure a verifier did not reproduce carries no [V], even when neighbouring figures from the same run do.

**Populations.** Figures from different rows of this table are never combined into one figure.

| tag | population |
|---|---|
| TEI-267 | TEI-rule store scope: 267 volumes / 197,534 documents (`~/frus-ner-raw/scope.json`) |
| ERA-REACH | TEI-267 documents by volume-id year: up to 1899, 61 volumes / 32,760; 1900–1905, 9 / 6,193; 1906–1909, 6 / 3,719; 1910–1929, 51 / 38,940; 1930–1945, 87 / 77,899; 1946–, 53 / 38,023 (MEASURED, CR `era_reach.py` → `era_reach.json`; the total reproduces TEI-267) |
| PRE1910 | The pre-1910 population, still unpinned: 85 volumes / 53,894 documents by manifest earliest year, or 76 / 42,672 by volume-id year (DOCUMENTED, FA §5) |
| APP-v50 | App view in the live index at version 50: 267 volumes with no `persons` rows / 198,936 documents |
| APP-v51 | App view after the owner's v51 reindex: 263 volumes / 196,447 documents (INFERRED, RF `post1291_population.json` [R, file read]) |
| GOLD | M2a gold: 64 keyed documents / 406 mentions / 288 presence keys. The arms scored on it were chosen after the scores existed. |
| SE-ROWS | Editor-marked from/to rows in no-list volumes, banded by volume-id year. 1861–1899: 61 volumes, 84,234 rows, 30,864 documents holding rows. 1900–1905: 9 volumes, 13,160 rows, 5,314 documents; this band is this program's own cut, not one of the assessment's bands. |
| SE-DOC-VY | Live-index export documents in those 70 volumes, banded by volume-id year: 32,809 (1861–1899) / 6,222 (1900–1905) |
| SE-DOC-AY | The live-index export of 46,837 pre-1906 documents, 1861–1899 by app year: 32,478 documents |
| SILVER | From/to document heads carrying an editor link that reaches a POCOM slug through the person-authority crosswalk. Drawn from the 286 persName-list volumes plus the 3 split-set second parts, banded by TEI document year. Under that key the "1900–1929" silver band holds only documents dated 1910–1919 (MEASURED, VSI). |
| SAMPLE-400 | 400 documents, 100 per band, drawn from TEI-267. Equal allocation, not population-weighted. |

Bands are 1861–1899 / 1900–1929 / 1930–1945 / 1946–. They follow the volume-id year unless a row says otherwise.

**Pair keys.** A (document, name) pair count depends on how the name is keyed. Every pair count below names its key, and no figure combines two keys.

| key | definition | figures that use it |
|---|---|---|
| census K2 | `census.py`: lower-cased, one of 29 honorifics stripped once | editor layer 223,505; agreement arm 768,928; census net pool 1,072,769; three-way union 1,841,697 (MAG) |
| grains key | `grains.py` `surface_key`: 74 honorifics, stripped repeatedly | agreement arm 758,194; priced adjudication queue 1,051,899, of which 929,012 are new at presence grain (MCJ, VCJ) |
| RC surface key | `read-claude/disagreement/disagreement.py` (document, surface) key over spans the editors did not mark | unmarked agreement arm 570,129; disagreement set 1,053,359 (RC) |
| k2_surface | `measure_pocom.k2_surface`, per-volume distinct keys | sum 30,011 (MCJ job D); census K2 gives 30,107 (VCJ) |
| persons-row key | lower-cased surface, distinct per volume, all marked rows | marked layer: about 30,327 per-volume entries (FA §2.1; VAG) |
| RC per-volume from/to key | RC `synthesis-size.json`: distinct from/to keys summed per volume, from/to rows only | 28,280 (RC) |

Three different sets have been called "the queue". This file names them: the **three-way union** (census K2, 1,841,697 pairs), the **census net pool** (census K2, 1,072,769 pairs: the union minus the agreement arm), and the **priced adjudication queue** (grains key, 1,051,899 pairs: the union minus the agreement arm, minus every span overlapping an agreement span).

**Evidence keys.** The prefix for scratchpad paths is `/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/`.

| key | source |
|---|---|
| FA | `Planning/234-Early-Era-People-Feasibility-Assessment-2026-09-12.md` (repository) |
| P2 / P3 | The first and second ASSISTANT FINAL blocks in `reframe/prior-assessments.md` (the Claude-pass answer and the Source Explorer answer) |
| LP / CC | `llm-pass/` and `chapter-context/` (evidence behind P2 and P3) |
| RF / RA / RC | The reader agents: `reframe/read-feasibility/`, `reframe/read-app/`, `reframe/read-claude/` |
| MSE / VSE | `reframe/measure-se-pocom/` and `reframe/verify-measure-se-pocom/` |
| MAG / VAG | `reframe/measure-agreement/` and `reframe/verify-measure-agreement/` |
| MCJ / VCJ | `reframe/measure-claude-jobs/` and `reframe/verify-measure-claude-jobs/` |
| MOF / VOF | `reframe/measure-offsets/` and `reframe/verify-measure-offsets/` |
| MSI / VSI | `reframe/measure-silver/` and `reframe/verify-measure-silver/` |
| CR | `reframe/critique/` (`critique.json`; `era_reach.py` → `era_reach.json`) |

**Dollar figures.**
- **All are INFERRED.** They are estimated from character counts, so token counts can be off by up to about ±40% (MCJ caveat).
- **Unit prices** come from `llm-pass/cost-scale/cost_model.py`, in $/MTok input/output: Haiku 4.5 1/5, Sonnet 5 2/10, Opus 5 5/25. Batch pricing is ×0.5 and a cache read is ×0.1.
- **Price provenance.** `cost_model.py` records no pricing date and no source. Its prices match the claude-api skill model table cached 2026-06-24 (DOCUMENTED, VCJ).
- **Triples** read low / central / high scenario.
- **Treatments.** "Batch+cache, low effort" and "standard, high effort" are `cost_model.py`'s two treatments. Its thinking tokens and cache hit rates are assumptions, not measurements. Wherever a cap is proposed, both treatments are given, high scenarios included.
- **Two cost bases.** MCJ and RC price the same two verifier roles about 2× apart, because they assume different windows. §3.9.1 sets them side by side. Caps in this file use MCJ, the higher base.

**Code citations** are at the worktree HEAD. Its content is identical to `origin/v2` 6aad5a9f (the reader recorded f63e253e), and it includes #1291 and #1292.

**Changes from the draft.**
- **Corrected figures.**
  - The commonest filing-role label is the Department of State (26,254 of 52,616 rows), not the U.S. mission.
  - Pair counts name their key.
  - The share of corpus text sent is MCJ's 45.7% / 51.0%, not RC's 21–33%.
  - The 82.4% versus 90.4% comparison now holds the roll test fixed.
  - FTS timings are scoped to 267 volumes, not one.
  - Artifact sizes are a census-format proxy.
- **Tags.** [V] is removed from pilot costs, the 9,954-section count and the per-chapter guide costs; the W. H. Seward assignment is now [V-part].
- **Reframed claims.**
  - The filing-role label is a post claim that needs a keyed sample.
  - Per-volume network nodes still fold the concurrent Sewards.
  - Cost does not stop binding at high scenarios.
  - Erratum 2 is narrowed.
  - In-session corpus reads are disclosed and fall under N1.
- **Added.**
  - Dispositions for the surfaces #234 named and for the surfaces that inherit person rows (§3.16).
  - The shipped, ungated summary-template path (§3.15).
  - Identity-free and classifier-aggregate carriers (§3.17–3.18).
  - Already-shipped surfaces (§3.19).
  - The Source Explorer era ceiling.
  - Exclusions for `frus1941-43` and `frus1873p1v2`.
  - Owner keying time (§2.5).
  - Gates N21–N24.
  - A reconciliation of the two cost bases (§3.9.1).
- **§5 rebuilt.** Screen on the gold, freeze by hash, then one confirmation. Pre-1910 before corpus, with a keyed audit after every pass. Tier A licenses only its stratum. Caps are given by treatment. Dependencies are corrected.

---

## 1. The verdict

**What decides feasibility changes; the evidence does not.** In the assessment every shape wrote rows into `persons` / `person_mentions`. The shipped `PersonClusterer`, whose only row source is `SELECT … FROM persons` (`IndexingPipeline.swift:1175`; DOCUMENTED, RF [R]), therefore decided feasibility. Features kept outside those tables never reach it: a per-document list, a Source Explorer line, a correspondence view, a verification queue. For them the clusterer gate becomes an isolation invariant, and three other things decide:
- a precision floor for each feature at the grain it displays;
- a blind-keyed sample for any claim about who a correspondent was or what post they held;
- any verifier, measured on documents it has not seen.

**Isolation costs reach.** Isolated carriers deliver none of the surfaces #234 named — the People browser, person search, Person Analytics and the co-mention graph. Nor do they deliver the surfaces that inherit person rows: Related documents' shared-people axis, the Collections Persons Index and its exports, and the person facets. Each of these is delivered only as a new, separate view, or by folding entries into the person tables, which brings back FA §4.a's clusterer gate and the rollup bump (§3.16).

**The assessment's two narrow findings stand.**
- **Editor markup yields a correspondent index, not a people index.** 97.8% of the 159,182 documents it reaches carry only from/to header names (MEASURED, FA §2.1, TEI-267).
- **Identity is not shippable.** 0 of 300 evaluation rows are keyed (MEASURED, VCJ). Post-1910 silver cannot stand in for pre-1900, where the silver set is one person on 459 heads (MEASURED, MSI [V]).

One assessment figure changes status. FA knew the 88 marked spans were the gold's seeds, but presented presence P 1.000 / 0 false keys as measured quality. The annotator, shown those spans, removed none (MEASURED, VSI), so relaxed precision 1.000 follows from that outcome. The figure cannot detect a wrong editor mark.

**Untagged people already reach readers through four shipped surfaces:**
- Office of the Historian volume people tags on all 267 untagged volumes: 647 assignments, presidents and secretaries of state only (MEASURED, RA [R, file read]);
- full-text search;
- the word cloud's NLTagger People lens;
- the on-device summary templates.

The summary templates can name participants from model memory. The output is stored in a CloudKit-synced `@Model` and indexed for full-text search, with no gate (DOCUMENTED, RA [R]). That defect class is live today and needs an owner decision (§3.15).

**The Claude-pass answer changes most.** Claude's defensible roles shrink from re-reading or judging the corpus to checking candidates the free layers already produced. On Sonnet 5 batch+cache, low effort (INFERRED, MCJ [V]):
- filtering the agreement arm costs $129 / $209 / $1,113;
- verifying the priced adjudication queue costs $146 / $223 / $1,130.

At central batch estimates, cost is small beside the gates. High scenarios run about 5× central: $444 → $2,265 for the headline job set on Sonnet 5 batch+cache, and up to $22,548 on Opus 5 standard high effort. Every phase therefore still needs a cap (N2). RC's narrower windows price the same two roles at about half, with verifier quality unmeasured under either design (§3.9.1). Four other things bind:
- authorization to send text off the machine, including whether in-session reads are covered (N1);
- a held-out instrument, because 63 of the 64 gold documents are named in committed evidence (MEASURED, RF [R, file read]);
- blind keying;
- a local-model control arm.

**The Source Explorer answer changes in reach and in its best use.**
- **Suggestion share.** After #1292 the share of 1861–1899 documents with an archival suggestion rose from 76.9% to 85.9% (MEASURED, RF [R, file read], SE-DOC-AY).
- **Era ceiling.** Its classifier covers only volumes dated up to 1905: 70 of the 267 TEI-267 volumes, and 38,953 of 197,534 documents (19.7%; MEASURED, CR `era_reach.json`). The other 158,581 documents (80.3%, INFERRED) get markup and detectors only.
- **Best product: a filing-role label.** It reaches 52,616 of 84,234 correspondent rows in 1861–1899 (62.5%; MEASURED, MSE [V], SE-ROWS).
  - It asserts no identity, but it is shown at the side of a named correspondent, so it is a post claim and needs a blind-keyed sample before it ships.
  - No precision exists on its target population.
  - No label kind has a keyed sample on the target rows. Out-of-population proxies exist for every major kind, and they conflict for the U.S.-mission label: right in 192 of 193 rows in 1873, but in 0 of 33 printed-office sides in 1900–1905 (MEASURED, MSE).
- **Identity contribution: unchanged.**
  - The new sender rule decides 0 of the 117 head rows first-signed by F. W. Seward.
  - "Corroboration" compares POCOM with POCOM.
  - A pre-1900 identity precision still needs a blind-keyed, stratified sample.

---

## 2. Gates and decisions under the reframe

### 2.1 The assessment's §5 gates

| # | gate (FA §5) | status in FA | effect | why | status 2026-09-13 |
|---|---|---|---|---|---|
| 1 | (1) Evaluation set first | Met for detection; not met for identity | **tightens** | "Met for detection" covers only the existing detectors. 63 of 64 gold documents are named in 15 committed files, and the four error listings hold 1,480 bracketed context snippets (MEASURED, RF `gold_leakage.json` [R, file read]). The M2a audits used LLM adjudicators (DOCUMENTED, FA §1.4). The marked layer equals the seeded spans in 64 of 64 documents, with 0 removed (MEASURED, VSI `v-m2a-seeds.json`). A Claude arm needs a fresh set. | Detection: a screen only. Identity: not met. |
| 2 | (2) Out of interactive scope | Binding | **tightens** | Claude fits only as a scripted batch job. A Claude Code subagent carries a fixed seat of 44,661–70,602 tokens (INFERRED, LP `cost-scale/side.json`). Design-time reading of corpus text inside Claude Code has already happened during this assessment, and those reads send the text to Anthropic (DOCUMENTED, RC R9). That practice is not an exception to assume: whether it is allowed is part of N1. | Binding; in-session reads need owner authorization (N1) |
| 3 | (3) Pilot before corpus, pre-1910 first | Binding; bypassed once by the sweep | **tightens** | The markup exemption rests on "editor markup asserts no identity", which holds only for carriers that show markup and nothing else. Filing-role labels, POCOM candidates and Claude verdicts each need a held-out pilot of their own. The pre-1910-first rule now also binds the detected-names tier and every Claude path: a corpus-scale pass before a pre-1910 pass and its keyed audit would repeat the sweep's bypass, this time with money. The pre-1910 population is still unpinned (PRE1910). | Pin still owed |
| 4 | (4) Synthetic-ref namespace / force-merge-only / index-bump batching | Undefined anywhere | **relaxes** | A namespace collision exists only when derived rows share `persons`' key (volume_id, ref); a separate table removes it. Two things remain: stable deterministic ids, if saved searches or user verdicts anchor to entries, and bump batching for any parse-time change. | Returns in full if any entry is proposed for the People browser |
| 5 | (5) A confidently wrong person is the worst defect | Violated by default under the shipped clusterer | **tightens** | The constraint binds every person claim; only its named mechanism was the clusterer. The reframe adds mechanisms the clusterer gate does not close. **(a) POCOM plus filing context.** POCOM's chapter rule still assigns W. H. Seward to all 113 of the 113 rows first-signed by F. W. Seward that Source Explorer now shows (MEASURED, MSE [V-part]: VSE reproduced the 117 rows, shown 68 → 113 and the sender rule deciding 0, but not the W. H. assignment). **(b) Facets and networks keyed by name string**, including per-volume network nodes, which fold concurrent namesakes. **(c) Model memory.** 18.6% of marked correspondent mentions have no candidate in any local source (DOCUMENTED, P2). **(d) A shipped instance of (c).** The on-device summary templates can already name participants from model memory, and the result is synced and full-text indexed (DOCUMENTED, RA [R]; §3.15). Each carrier needs its own refusal rule. | Binding; (d) is live |
| 6 | M2a keyed | 64 of 72 keyed; keying the other 8 optional, as a held-out set | **tightens** | The 8 unkeyed documents (3 / 3 / 2 in the three later bands; MEASURED, FA §0) are the only staged documents with no committed residues. They are too few to score a verifier, so they should be spent only as a held-out check. | Protect them from prompt design and pre-fill |
| 7 | N-1 scored | Done | **unchanged** | A record of the detector comparison; it does not depend on the carrier. | Done |
| 8 | N-2 detector choice and build plan | Decision owed | **relaxes** | "Presence, not offsets" was read from the People surfaces' code. It reopens per carrier: presence for lists and facets, offsets for inline highlighting and for context windows sent to a verifier. | Owed, per carrier |
| 9 | N-3 / W-7a more models | Dormant | **tightens** | A Claude judge is a third model, so the gate is active again. It brings authorization, a spend cap, a held-out score, output pinning and a terms review. A local 27–31B arm should run on identical inputs first. That such models are loaded on the Studio is DOCUMENTED in P2 and was not checked from this machine. | Active |
| 10 | 300-row identity evaluation | 0 of 300 keyed | **tightens** | Any claim about who someone was, what post they held, or a career link needs it. The filing-role label is such a claim (§3.5). It must be keyed blind, because pre-filled rows measure agreement with whatever filled them. It holds only 16 several-candidate rows, 12 of them pre-1910 (DOCUMENTED, LP `identity/gate.json`); with zero errors at n = 12 the lower bound is 0.7575 (MEASURED arithmetic, MSI [V]). Source Explorer and POCOM claims need a sample stratified by rule outcome (§3.11), and a tier drawn from one stratum licenses only that stratum. FA §6.4's thresholds apply to each: ≥ 0.90 pooled and ≥ 0.80 in every 75-row band. 1900–1909 falls into no proposed stratum (INFERRED, from VSI's reading of the sample design). | 0 of 300 keyed (MEASURED, VCJ) |
| 11 | M1b / R-4 derived rows reach the app | Not started | **relaxes** | Its dependence on gates (4) and (5) existed only because derived rows meant `persons` rows. A separate table or bundled artifact still needs a generator or index table, `xcodegen` for a new resource, and its own re-apply and removal hook. "No CloudKit deploy" becomes conditional: synced user accept/reject verdicts trigger the R-7 schema-deploy gate (DOCUMENTED, CLAUDE.md). | Not started |
| 12 | M3 provenance | Not started | **tightens** | `ProvenanceSource` is pinned at 8 labels (`ProvenanceChipTests.swift:51`; DOCUMENTED, RF and RA [R]). None fits a hosted-model verdict or an offline Qwen or NLTagger harvest, and `.appModel` reads "This app's model". None fits a rule-derived identity guess or a filing-role post claim either: `.ohPeopleRegister`'s method sentence describes a join (DOCUMENTED, RA [R]). | Owner wording owed |
| 13 | R-2 mention-context vectors | Not started | **unchanged** | Needed only for identity clustering. A Claude identity judge could substitute, but neither is scored. | Not started |
| 14 | R-3 identity clustering plus adversarial tier | Not started; gated on owner | **tightens** | The adversarial tier is now a concrete hosted model, so it adds authorization, a spend cap, blind keying and a held-out score. "Rules written" becomes a refusal rule for each carrier. | Not started |
| 15 | §4.0 cross-part `corresp` defect | Measured in the live index | **dissolves** | Fixed in code by #1291 (index v51; DOCUMENTED, RF [R]). The live index is still at v50 on all 316,839 revision rows, with 0 `persons` rows in the four affected volumes (MEASURED, RF [R]; VSI). | Owner reindex owed |
| 16 | Precision floor for any detected layer | Unset | **tightens** | One floor becomes one per feature, per band and per verifier output. The gold precision also depends on the matcher: the agreement arm reads 0.898 (25 false keys) under the scorer's tie-break and 0.882 (29 false keys) under an equally valid maximum matching (MEASURED, VAG). The 1930–1945 cell is 15 documents. | Unset |
| 17 | On-screen wording | Unset | **tightens** | New claim types need owner wording: a filing role, a possible officeholder from filing context, a name checked by a model, a model-written guide. The filing role should attach to the document, not to the name ("filed as a despatch from the U.S. legation in Belgium"). The "Reconciled identity" seal stays gated on an authority id (`PersonIndexView.swift:654–664`; DOCUMENTED, RA [R]). | Unset |
| 18 | Bundle-size decision for (b) | Open | **unchanged** | The agreement arm measures 9,346,130 bytes, 2,926,099 with gzip -9, in the census format (MEASURED, MAG [V]). That format carries no display strings, direction or stable ids; no app-shaped size was measured (VAG). A sweep that only feeds a queue never ships, which removes the ~7.2 MB option. Claude-derived artifacts would add sizes nobody has measured. | Open |
| 19 | OS-build pin and filter promotion | Not started | **unchanged** | Any shipped NLTagger derivative is a property of OS 26.6.2 (25G83) (DOCUMENTED, FA §1.1). A verifier adds its own pin: model id, prompt hash and parameters. | Not started |
| 20 | Corpus-scale census of the agreement arm | Not measured | **discharged for reach and census-format size; precision still unmeasured** | Any carrier that uses the arm needs it. The census measures reach and size, not precision. | **Met for reach and census-format size:** 768,928 (document, census K2) pairs, 190,658 documents (96.5%), 157,028 keys, TEI-267 (MEASURED, MAG [V]). Corpus precision: unmeasured. |
| 21 | Identity-grain / string-equality re-score | String equality done; last-token proxy grain not scored | **tightens** | In a per-document list the last-token collapse is what the reader actually sees. At corpus scale a within-document last-token collapse removes 19.2% of the arm's added pairs (census K2), 32.3% in 1861–1899 (MEASURED, VAG). That collapse is a proxy in both directions: it also merges namesakes. | The gold's last-token P/R is still unscored |
| 22 | On-device rollup consolidation time | Recorded nowhere | **dissolves** | It exists only if derived rows multiply `persons`. Isolated carriers leave the rollup at its editor population: 62,931 `persons` rows at v50 (MEASURED, RF [R]). | Returns if entries are folded into the People browser |
| 23 | Errata in the record | Open | **unchanged** | The record's accuracy does not depend on the carrier. §4.4 adds new errata. | Open |

### 2.2 The assessment's §6.3 owner decisions

| # | decision (FA §6.3) | effect | why |
|---|---|---|---|
| 1 | "Offsets vs presence is settled: presence." The real decision is the name-string grain. | **relaxes, and is re-posed per carrier** | A per-document list asserts nothing beyond its document, so it avoids the "two seward entries" question. A facet or network node that spans documents folds people by string: 'johnson' (10,761 filtered-sweep mentions, census K2) and 'wilson' (10,010) each fold several people (MEASURED, FA §2.1). A per-volume node folds concurrent namesakes too (§3.6). Offsets are no longer settled: inline highlighting needs them, and a mapping has now been measured (§3.12). |
| 2 | Whether "correspondents from FRUS markup" counts as extending the People browser | **dissolves** | The reframe does not need it to count. The part that survives, that it must be labelled a correspondent index, moves into decision 6. Whether entries may ever enter the People browser moves to §6 decision 9 (§3.16). |
| 3 | Ratify the derived-entry rollup rule as a code change, plus the synthetic-ref namespace | **relaxes** | For carriers outside `persons`, `person_mentions`, `person_rollup_member`, the authority crosswalk and `PersonClusterOverride`, it becomes an isolation invariant test. It returns in full if any entry is proposed for the People browser. |
| 4 | Grant or refuse the §5(3) exemption for editor markup | **tightens in scope** | The exemption's argument covers carriers that show markup only. Every other feature needs a pinned pre-1910 population and a held-out pilot. |
| 5 | Set the per-band precision floor | **tightens** | It becomes per feature × band × verifier. On the gold's three-way candidate pool, a verifier must reject at least 89.0% of false keys to reach presence P 0.898, or at least 92.7% for at most one false name per 3 documents (INFERRED, RF from FA §2.2). A recall verifier cannot move the band the floor argument turns on: even perfect verification of the disagreement set leaves 1930–1945 at P 0.772 (MEASURED post hoc, RC `disagreement.json`). |
| 6 | Approve the wording | **tightens** | It gains new claim types, and needs either a ninth provenance source or a disclosure sentence per claim type. The seal stays tied to an authority id. Reusing Source Explorer's Likely/Possible chip needs a measured meaning or a disclosure (N22). |
| 7 | The bundle question for (b) | **unchanged** | It still applies to whatever ships. |
| 8 | Key the 300 rows before any POCOM-anchored identity | **tightens** | Keying must be blind and stratified by rule outcome, with no model pre-fill, and the sample must be sized to the claim (§3.11). The filing-role label sample is a post-claim instrument of the same kind (N12). |
| 9 | Optionally key the 8 unkeyed M2a documents as a held-out set | **tightens** | No longer optional in practice. They must also be kept out of any prompt or threshold design. |

### 2.3 The assessment's §6.4 triggers

| trigger (FA §6.4) | effect | why |
|---|---|---|
| Detected layer: a fresh ≥ 100-document sample; agreement-arm lower bound ≥ 0.85 and ≤ 1 false name per 3 documents in every band | **tightens** | The same sample must also confirm any Claude or local verifier arm, so it must be staged and keyed before any model sees it, and it is used once, after the arms are frozen (§5). About 250 documents are needed for a verifier gain to register (DOCUMENTED, P2). The matcher tie-break must be fixed in advance (VAG). The sample must be keyed unseeded, or seeded with planted wrong spans and disclosed: seeding with editor spans is what made markup precision 1.000 by outcome (VSI). |
| Identity: 300 keyed rows, ≥ 0.90 pooled and ≥ 0.80 per band, a synthetic-namespace merge test, a measured Seward-type rate | **tightens** | The thresholds now apply to each identity-bearing rule the reframe adds, the filing-role post claim included. A tier sampled from one stratum licenses only that stratum. The namespace test becomes the isolation test. |
| (a) becomes unacceptable if the clusterer gate breaks editor rollups | **dissolves** | The clusterer cannot reach isolated carriers. |
| The sweep matters for presence only with an inline-linking surface | **relaxes** | "Maximum possible use" proposes exactly such surfaces, and a verification queue also makes the sweep matter, through recall. Its direct-display precision is unchanged. |

### 2.4 New gates

| # | gate | why | owner | what unblocks it |
|---|---|---|---|---|
| N1 | Authorization to send corpus text to a hosted model | Every Claude step sends FRUS text off the machine. No API-use policy exists in `Planning/*.md` (DOCUMENTED, RF [R]). The priced jobs send ±300-character windows merged per document: 310,674,650 characters for the agreement-arm filter (45.7% of 679,401,514) and 346,287,109 for the priced adjudication queue (51.0%), plus 30.8M / 41.9M characters of candidate listings (MEASURED, MCJ `pools.json`; shares INFERRED). RC's narrower design (±200 characters, first occurrence per key) sends 144.4M (21.3%) and 226.8M (33.4%) (MEASURED, RC `disagreement.json`; shares INFERRED). How much text the two jobs together send is not measured. Window design is a lever on both cost and authorization scope. Corpus snippets were also read inside Claude Code sessions during this assessment, which sends them to Anthropic (DOCUMENTED, RC R9). | owner | A written scope: public-domain corpus text only, never user notes or synced content. It names the models, the route (scripted Message Batches) and retention, and it states **whether in-session reads of corpus text in Claude Code are covered**. Until it does, the record states that such reads already occurred. |
| N2 | Spend cap per phase and per treatment, with a hard stop in the batch driver | High scenarios sit far above central. The headline job set (agreement-arm filter, priced adjudication queue, Source Explorer × POCOM adjudication, per-volume guides) costs $284 / $444 / $2,265 on Sonnet 5 batch+cache, low effort, and $1,757 / $3,829 / $22,548 on Opus 5 standard, high effort (INFERRED, MCJ [V]). Thinking tokens are unmeasured. | owner | Caps for the screen, the confirmation run, the pre-1910 pass and any corpus stage, each set from the high scenario of the treatment actually run (§5). |
| N3 | An uncontaminated held-out set | Gate 1 above. | engineer stages, owner keys | A fresh, era-stratified sample of about 250 documents drawn from the corpus length distribution, keyed unseeded or seeded with planted wrong spans and disclosed. It is used once, for confirmation. The 8 unkeyed M2a documents are held out as well. |
| N4 | A blind keying protocol | The M2a seeding precedent cannot size anchoring: no wrong seed was planted, and all 35 "rejected" seeds were boundary edits (MEASURED, MSI [V]). | owner | Covers every instrument: identity tiers, the label sample and the detection sample. Lock the blind column with a sha256 before revealing any machine candidate, and score every arm against the blind column only. If rows are pre-filled for speed, randomise them into halves and plant wrong candidates in one half. With 0 plants accepted of 30, the Wilson upper bound is 11.35% (exact one-sided: 9.5%); with 0 of 50 it is 7.14% (5.8%) (MEASURED arithmetic, MSI / VSI). |
| N5 | Pre-registered thresholds, including the matcher rule | Arms were already chosen after scores existed (FA §0), and the tie-break alone moves agreement-arm P from 0.898 to 0.882 (MEASURED, VAG). | engineer drafts, owner ratifies | Commit the thresholds per band, the matcher tie-break and a rerun-stability check before the first model call. After the gold screen, freeze prompts, windows, thresholds, tie-break and model ids by hash. |
| N6 | A provenance source and wording for hosted-model and rule-derived claims | Gate 12 above. | owner and engineer | Either a ninth `ProvenanceSource` or a disclosure sentence; update the pinned tests. |
| N7 | Per-feature precision floors at the display grain | A per-document list, a cross-document facet, a network edge, a role label, an identity candidate and a written sentence each fail differently. | owner | A floor per feature per band, each measured at its own grain on held-out documents. |
| N8 | An isolation invariant test | Nothing today stops a derived writer from touching the person tables. | engineer, owner ratifies | A test that no derived-data writer touches `persons`, `person_mentions`, `person_rollup_member`, the authority crosswalk or `PersonClusterOverride`. |
| N9 | A grounding rule for written synthesis | Gate 5(c) above. | owner and engineer | Every sentence cites a document id, a POCOM slug or a NAID, checked by a claim-level citation audit on a stratified sample. |
| N10 | Model-output pinning | Hosted outputs are non-deterministic and model ids retire. | engineer | A manifest of model id, prompt hash, parameters and raw responses, plus a rule for what happens when the model is retired. |
| N11 | A terms review for Claude-derived artifacts | A licence gate exists for Gemma-derived vectors; none exists for Claude output. The terms themselves were not assessed (DOCUMENTED, RF [R]). | owner | A compliance note before any model-derived artifact enters the bundle. |
| N12 | A keyed filing-role label sample, keyed as a post claim | No label precision exists on the target population. Labelled rows 1861–1899 (S_after, SE-ROWS) by own role: the Department of State 26,254 of 52,616 (49.9%; 9,540 from + 16,714 to); a single U.S. mission 13,796 (26.2%); two-way "U.S. mission or foreign legation" 8,551 (16.3%); a foreign legation 3,404 (2,535 from + 869 to); a U.S. consulate 542 (MEASURED, MSE `out/merged-rule.json` `label_signatures`; shares INFERRED). The U.S.-mission label is the largest from-side role. Its only positive evidence is 1873 (192 of 193), and it is right on 0 of 33 printed-office sides in 1900–1905 (MEASURED, MSE; 0 of 49 under VSE's parser). The label is shown at the side of a named correspondent, so it reads as that person's post. | engineer stages, owner keys | A blind sample keyed as a post claim ("does the named side write in that filing role?"), stratified by label kind (Department, U.S. mission, two-way, foreign legation, consulate) × chapter kind (country, foreign legation, topical). **Size.** A per-band claim for one label kind needs a 75-row band, per FA §6.4 as §2.3 applies it. Five label kinds × three chapter kinds make 15 cells, and only the cells that will ship need a band of their own (INFERRED). Zero errors give a lower bound of 0.8668 at n = 25 and 0.963 at n = 100 (MEASURED arithmetic, MSI [V]), and 0.9513 at n = 75 (MEASURED arithmetic, MSI). |
| N13 | Source Explorer post evidence ready for a generator | The re-measurement on the merged code is done (MSE). Three things are still open. The classifier lives only in the app, and it covers volumes dated up to 1905 only (ERA-REACH). Bundled POCOM careers cover 6 of the 481 people who held a chief-of-mission or principal post in 1861–1905 (DOCUMENTED, P3). And 148 documents in 1861–1899 scope volumes, plus 9 in 1900–1905, are known to sit under glued chapter titles the merged normaliser still misses (MEASURED, MSE, SE-DOC-VY) — a subset, not a census. | engineer | Shared classifier code, an expanded POCOM artifact, and a census of title forms. |
| N14 | A local-model control arm | Whether Claude beats a free local model is unmeasured (RC). | engineer | A gazetteer-only arm and a local 27–31B arm, screened on the gold and confirmed on the same frozen inputs as any Claude arm. |
| N15 | A decision on 1900–1909 | **By TEI document year:** 12,405 untagged from/to heads in 20 volumes, 68.0% of them honorific-led (MEASURED, VSI), with no silver. **By volume-id year:** TEI-267 holds 15 volumes / 9,912 documents in 1900–1909 (MEASURED, CR `era_reach.json`). Of these, 9 volumes / 6,193 documents are in 1900–1905, which Source Explorer covers. The other 6 / 3,719 are in 1906–1909, which it does not. | owner | Include the decade as its own stratum, or exclude it from identity and post claims. |
| N16 | Gates for offset-bearing surfaces | 6.8% of detected spans sit in footnotes, which have no body offset; 4.3–4.9% are refused by the anchor mapping; highlights go stale when `renderingVersion` changes (MEASURED, VOF, SAMPLE-400; DOCUMENTED, MOF). | engineer and owner | A mention-grain floor, a treatment for footnote names, and a staleness rule. |
| N17 | An aggregation rule for facets and networks | Grouping by name string folds people without ever touching `PersonClusterer`. Per-volume nodes fold the concurrent Sewards (§3.6). | owner | Nodes and buckets labelled as name strings as printed, or split by filing role; volume scoping alone is not enough. A measured Seward-type rate before any node is sized by degree. |
| N18 | The CloudKit gate for synced verdicts | Accept/reject verdicts stored in a `@Model` or a new stored property change the schema (DOCUMENTED, CLAUDE.md). | owner | The R-7 deploy, or verdicts kept device-local. |
| N19 | The v51 reindex before any live-index measurement or person-table feature | Gate 15 above. | owner | The reindex, then a re-measure of the population and orphan figures. |
| N20 | A budget for owner review and keying time | Review queues compete with identity keying for the same sittings. The priced adjudication queue alone (grains key) is 1,051,899 (document, key) pairs, 929,012 of them new at presence grain (MEASURED, VCJ, TEI-267). Keying time is unmeasured except for FA's 300-row estimate (§2.5). | owner | Schedule identity and label keying ahead of any review of machine output, and record sitting durations so later instruments can be priced. |
| N21 | A keyed audit after every corpus pass | Nothing blind-keys the layer that will actually ship. N5's rerun check is pre-run only. Hosted outputs are non-deterministic, so a rerun differs from the confirmation replicates. A filter pass yields Claude verdicts, not a precision (VCJ). | engineer stages, owner keys | A blind-keyed spot sample of the produced layer, stratified by band, scored against the pre-registered floor before the layer ships or the pass extends. |
| N22 | A measured meaning for the Likely/Possible chip | Source Explorer's Likely/Possible chip (`CentralFilesClassifier.swift:14-27`; DOCUMENTED, RA [R]) implies a calibrated confidence scale. Nothing measures what Likely or Possible means in precision terms on any population. | owner and engineer | A measured precision per chip value, from a sample of the claim the chip is attached to (N12 for filing roles; a keyed archival-suggestion sample for series and reels), or a disclosure that the chip states which rule fired, not a precision. |
| N23 | A decision on the shipped summary templates' participant fields | Gate 5(d) above; §3.15. | owner | Explicit acceptance, or template wording "as printed", a disclosure, and exclusion of generated names from name search. |
| N24 | An exclusion list for features driven from the NER stores | `frus1941-43` is inside TEI-267 but already has 81 `persons` rows and 0 `person_mentions` at v50 (MEASURED, VSI [V]; FA §4.0). After v51, `frus1932v04`, `frus1918Supp01v02` and `frus1917Supp02v02` are inside TEI-267 and carry editor identities. A store-driven feature would otherwise put machine names beside an editor list. `frus1873p1v2` is outside TEI-267 (it is in the app view only), so no store-driven feature reaches it (DOCUMENTED, FA §4.0). | engineer | A pinned exclusion or labelling list applied by every store-driven generator, with a test. |

### 2.5 Owner keying time

Owner keying time is the resource that gates identity and post claims. One sitting has a documented estimate. Every other sitting in the program is unpriced.

| instrument | size | time |
|---|---|---|
| 300-row identity evaluation (M1a) | 300 rows | **~2–3 h** (DOCUMENTED estimate, FA §5; it prices marked from/to names only). FA notes that 100 pre-1910 rows "halves it and prices only that slice". |
| R-3 identity verdict sitting | not sized | 2–4 h (INFERRED, FA §4.c) |
| Identity tier A (§3.11) | 100 rows, 25 per decade; about 75 rows per band if a per-band claim is made | not priced |
| Identity tiers B and C (§3.11) | about 380 rows; 450–500 rows | not priced |
| Filing-role label sample (N12) | 75 rows per shipping cell of label kind × chapter kind (N12) | not priced. FA's ~2–3 h per 300 rows is about 0.4–0.6 minutes per row (INFERRED), but it prices marked from/to names only and does not transfer to post-claim or detection keying. |
| Fresh detection sample (N3) | about 250 documents from the corpus length distribution, longer than M2a's 800–8,000-character window | not priced. Editor seeding cut the M2a sitting by about a third (DOCUMENTED, CLAUDE.md), but seeding without planted errors measures agreement with the seeds. |
| The 8 held-out M2a documents | 8 documents | not priced |
| Keyed audits after each pass (N21) | per pass, per band | not priced |

---

## 3. Feature candidates, ranked by value against risk

**Verdict terms.**
- **Buildable now:** no measurement is owed. Owner wording or scope decisions may still be.
- **Conditional:** it can be built once a named measurement or decision exists.
- **Not yet:** it needs an instrument that does not exist.
- **Owner decision owed now:** it already ships, and the owner must accept or change it.

Card numbers from the draft are kept. New cards are 3.15–3.19.

### 3.0 Ranking

| rank | candidate | card | signals | identity asserted | verdict |
|---|---|---|---|---|---|
| 1 | Editor identities in the four #1291 volumes | 3.1 | editor markup, crosswalk, POCOM (shipped) | yes, by the editors | **buildable now** (built; needs the owner's reindex) |
| 2 | Correspondents index from markup | 3.2 | editor markup | no | **buildable now**, after two owner decisions; its isolated data layer is unsized |
| 3 | Per-document names list | 3.3 | editor markup; later detectors; FTS | no | **buildable now** for markup; conditional for detected names |
| 4 | Disclosure on the shipped NLTagger People lens | 3.4 | NLTagger (on device) | no | **buildable now** |
| 5 | Participant fields in the shipped on-device summary templates | 3.15 | on-device FoundationModels | yes, from model memory, already shipped | **owner decision owed now** |
| 6 | Citation note and Chronology rows, correspondents and headings as printed | 3.17 | heading and dateline text | no, if the dateline is attached to the document | **buildable now** in the as-printed form |
| 7 | Trip-packet pull list with correspondents as printed | 3.17 | Source Explorer classifier; heading text | no (an archival pointer) | **conditional** on a keyed sample of archival suggestions (§3.18), or on a disclosure that the pull list comes from an unmeasured classifier |
| 8 | Filing-role label from Source Explorer | 3.5 | Source Explorer, editor markup | no identity; a post claim about the named side | **conditional** on a blind-keyed post-claim sample (N12) |
| 9 | Correspondence network labelled as such | 3.6 | editor markup | no identity, but nodes fold concurrent namesakes | **conditional** on a node-labelling rule (N17) |
| 10 | Detected-names tier at the agreement arm | 3.7 | editor markup, NLTagger, Qwen sweep | no | **conditional** on a floor, a held-out score and a pre-1910-first audit |
| 11 | Search facet by name | 3.8 | any shipped vocabulary; FTS | implicitly, by string folding | **conditional** on an aggregation rule |
| 12 | Posts axis, pre-1906 archival analytics, series dashboard card, semantic-map post lens | 3.18 | Source Explorer classifier, persisted | no (archival pointers at scale) | **conditional** on a keyed sample of archival suggestions, which is not staged |
| 13 | Claude-verified names | 3.9 | detectors, Claude, local model | no | **not yet** (screen conditional on authorization) |
| 14 | Claude-written correspondents guides | 3.10 | markup, POCOM, Source Explorer, Claude or on-device model | not required, but invited | **not yet** |
| 15 | POCOM "possible officeholder" tier with filing context | 3.11 | markup, POCOM, Source Explorer, deterministic checks | yes, hedged | **not yet** |
| 16 | Inline highlighting of unmarked names | 3.12 | detectors, offset mapping | no, but marks text as a person | **not yet** |
| 17 | Claude-adjudicated identities | 3.13 | markup, POCOM, Source Explorer, Claude | yes | **not yet** |
| 18 | Identity tier | 3.14 | all | yes | **not yet** (unchanged) |

Two further tables sit outside the ranking. §3.16 gives a disposition for each surface #234 named and each surface that inherits person rows. §3.19 lists the already-shipped surfaces that reach untagged people.

### 3.1 Editor identities in the four #1291 volumes

| | |
|---|---|
| Signals | Editor markup: `corresp` links into the sibling part's list in the three split sets, and `frus1873p1v2`'s own list. The person-authority crosswalk and the shipped POCOM career section. |
| Grain | The existing `persons` / `person_mentions` / rollup rows |
| Identity asserted | Yes, by the editors. No machine step is involved. |
| Quality | Editor assertions. In the three split parts, 122 of 634 distinct link targets carry a crosswalk id and 52 carry a POCOM slug (MEASURED, MSI [V]). |
| Reach | 5,530 orphan mention rows over 2,089 documents in the split parts, plus 454 rows (37 refs) in `frus1873p1v2` (MEASURED, MSI [V]; FA §4.0). 985 from/to heads carry a POCOM slug (MEASURED, MSI [V]). The app view goes from 267 / 198,936 to 263 / 196,447 (INFERRED, RF [R, file read]). |
| Cost | None further; PR #1291 is merged (DOCUMENTED, RF [R]). |
| Gates | The owner's v51 reindex. After it, N24 applies to any feature driven from the NER stores. Such features must exclude or label `frus1932v04`, `frus1918Supp01v02` and `frus1917Supp02v02`, which are inside TEI-267 and now carry editor identities. The same applies to `frus1941-43`, which is inside TEI-267 and already has 81 `persons` rows and 0 `person_mentions` at v50 (MEASURED, VSI [V]). `frus1873p1v2` is outside TEI-267 (it is in the app view only), so store-driven features never reach it (DOCUMENTED, FA §4.0). |
| Verdict | **Buildable now.** It restores shipped behaviour rather than adding a new feature. |

### 3.2 Correspondents index from markup

| | |
|---|---|
| Signals | Editor markup only (typed `persName` from/to). The label in 3.5 can be added later. |
| Grain | Per document ("who wrote to whom"), and a per-volume list of name strings with no cross-volume merge |
| Identity asserted | No |
| Quality | **On the gold** (GOLD, post hoc): presence P 1.000 (0 false name keys of 79), R 0.274 (MEASURED, FA §2.2). **That precision follows from the seeding outcome.** The marked layer equals the spans seeded into the gold in 64 of 64 documents; the annotator removed none; strict precision equals the share kept exactly, 53 of 88 (MEASURED, VSI). It cannot detect a wrong editor mark. **Display defects.** 83.1% of marked mention rows are a surname alone (MEASURED, FA §2.1). Duplication inside a markup-only list is not measured. Among all gold keys, 46 of 288 are a token-suffix of another key in the same document (MEASURED, FA §2.2). Among detected additions, 8.9% of added pairs share a last token with an editor key, 19.5% in 1861–1899 (census K2; MEASURED, MAG [V]). |
| Reach (TEI-267) | 159,182 documents (80.6%), 97.8% of them header-only; 223,505 (document, census K2) pairs; 11,377 distinct keys; about 30,327 per-volume entries (persons-row key; MEASURED, FA §2.1; pairs reproduced in the MAG controls [V]) |
| Cost | **No model or API cost.** **Size.** A census-format proxy is 2,632,099 bytes, 588,607 with gzip -9 (MEASURED, MAG; it equals FA §2.1's census, 2.63 MB / 589 KB, as a positive control). That format has lower-cased keys with one honorific stripped, and no display string, direction or stable id; the size of an app-shaped correspondents artifact is not measured (VAG). **Engineering.** 2–3 sessions for the two surfaces, a volume-page section and a Research-rail accordion (INFERRED, RA [R]). On top of that comes an isolated data layer — a generator or index table, a re-apply and removal hook, stable ids — which is not sized. RA's closest figures are 2–3 sessions (parse-time route) and 3–4 (artifact route), and both include pieces the isolated route drops (INFERRED, RA [R]). **What staying outside `persons` drops.** FA §4.a's clusterer gate, the synthetic-ref namespace, the `person_mentions` re-apply hook, the source column, the analytics distinct-count fix and the rollup bump. |
| Gates | N8 isolation test; owner wording ("Correspondent from markup") with the `.frusText` chip; the §5(3) exemption; the v51 reindex; stable ids if any user state anchors to entries; the isolated data layer |
| Verdict | **Buildable now**, once the owner decides the wording and the exemption. The data layer is unsized. |

### 3.3 Per-document names list

| | |
|---|---|
| Signals | Editor markup now. Detected names later, from 3.7. FTS for confirming a name at runtime. |
| Grain | (document, name string) |
| Identity asserted | No |
| Quality | **Names.** Markup names as in 3.2; detected names as in 3.7. **Presence needs no offsets.** `document_cache.body_text` equals the HTML-unescaped R-0 text in 400 of 400 documents in each of two independent samples (MEASURED, MOF and VOF, SAMPLE-400). Every sampled detected span therefore has an exact `body_text` offset: 5,188 of 5,188 sweep spans and 2,694 of 2,694 NLTagger spans in the first sample, and 6,447 of 6,447 and 3,249 of 3,249 in the second (MEASURED, VOF). `html.unescape` applies HTML5 entity rules, so a shipped map should decode by XML rules (INFERRED, VOF). **Runtime confirmation.** FTS confirms a known name in its document in 0.10 ms (sweep surfaces) or 0.015 ms (NLTagger surfaces) at the median (MEASURED, MOF [V]; Mac, Python sqlite3 3.51.0, not iOS). It cannot discover names, so a list still needs a shipped name vocabulary. |
| Reach | As 3.2 for markup |
| Cost | Included in 3.2's 2–3 sessions for markup names (INFERRED, RA [R]). Detected names need a bundled per-document artifact and `xcodegen` (RA); not sized. |
| Gates | As 3.2 for markup; as 3.7 for detected names |
| Verdict | **Buildable now** for markup. **Conditional** for detected names. |

### 3.4 Disclosure on the shipped NLTagger People lens

| | |
|---|---|
| Signals | NLTagger, running live on the device |
| Grain | Name-string counts per scope; no document, no offset |
| Identity asserted | No |
| Quality | Not measured. The lens runs Apple's `.personalName` tag over `document_cache.body_text` for any scope, untagged volumes included, keeps Title-cased strings, and applies no frozen filter (DOCUMENTED, RA [R]: `WordCloudTokenizer.swift:157–185`). The filtered NLTagger store's figures (FA §2.1: top strings include 'john', 3,943, and 'chiang kai', 2,454) are a lower bound on its noise, not a description of what it shows. |
| Reach | Any scope a reader selects. It is one of several shipped surfaces that reach untagged people. The others are the Office of the Historian volume people tags on all 267 untagged volumes (647 assignments; MEASURED, RA `manifest_people_tags.json`), full-text search, and the on-device summary templates (§3.15, §3.19). |
| Cost | 0.5–1 session for wording and an export caveat (INFERRED, RA [R]). The program's frozen filter must stay out of the shared stopword payload, whose SHA-256 the keyness baseline pins (DOCUMENTED, CLAUDE.md). |
| Gates | Owner wording saying that a statistical name recogniser did the reading |
| Verdict | **Buildable now** |

### 3.5 Filing-role label from Source Explorer

| | |
|---|---|
| Signals | The Source Explorer classifier (header, dateline, chapter path) applied to editor-marked from/to rows. No POCOM. |
| Grain | (document, side), labelled "the U.S. mission in C", "the Department of State", "the C legation in Washington", or two-way |
| Identity asserted | **No identity, but a post claim about the named side.** Shown beside "Mr. Sanford to Mr. Seward" (`frus1861/d21`), "the U.S. mission in Belgium" reads as Mr. Sanford's post (MSE). |
| Quality | **No keyed sample exists on the target population.** Four proxies, each from a different population, are in the table below the card. |
| Reach (SE-ROWS, post-#1292, as shown) | **1861–1899.** 52,616 of 84,234 rows (62.5%; 86.2% of 61,068 head rows) and 26,498 of 30,864 documents holding rows (85.9%). Before #1292: 47,734 rows and 24,031 documents (MEASURED, MSE; VSE got 52,643 / 26,512 with an independent head-grain method). **1900–1905.** 8,370 of 13,160 rows, unchanged by #1292. **Rows by own role, 1861–1899** (S_after; MEASURED, MSE `label_signatures`; shares INFERRED): the Department of State 26,254 (49.9%); a single U.S. mission 13,796 (26.2%, the largest from-side role); two-way 8,551 (16.3%); a foreign legation 3,404; a U.S. consulate 542. **Refused by design.** Enclosure rows, 23,128 of 84,234. **Era ceiling.** The classifier reads volumes dated up to 1905 only: 38,953 of 197,534 TEI-267 documents (19.7%; MEASURED, CR). |
| Cost | **No API cost.** **Live, no reindex.** A document-level filing role, from header, dateline and chapter path, can be computed live, as Source Explorer does. **Needs the markup data layer.** Attaching the role to editor-marked from/to sides needs that layer: a bundled artifact, or an index table plus a reindex. In the live index the untagged volumes carry no from/to marks outside the four #1291 volumes (DOCUMENTED, RA [R]). **Engineering.** 1–2 sessions for a line in both Source Explorer twin views (INFERRED, RA [R]). Corpus-wide aggregation needs index-time persistence and a reindex (INFERRED, RA [R]). |
| Gates | N12, a blind sample keyed as a post claim. Owner wording that attaches the label to the document rather than the name ("filed as a despatch from the U.S. legation in Belgium"). N22 before reusing the Likely/Possible chip. Refusal rules for enclosures, non-country titles and foreign-government papers. The label's evidence expires with each classifier edit. Twin-view drift. |
| Verdict | **Conditional**, under the rule that a post claim needs a keyed instrument first. No label kind has a keyed sample on the target rows. Out-of-population proxies (MEASURED, MSE): the Department label is right in 409 of 409 rows in 1873 and in 1,002 of 1,047 printed-office sides in 1900–1905; the two-way label in 29 of 29 and 100 of 116; the U.S.-mission label in 192 of 193 in 1873 but 0 of 33 in 1900–1905 (0 of 49 under VSE's parser). The U.S.-mission label, 13,796 rows (26.2%), is the kind whose proxies conflict. |

The four precision proxies for 3.5:

| proxy | population | result | what it can show |
|---|---|---|---|
| 1873 editor lists | `frus1873p1v1`+`v2` head rows, 31 distinct list entries | 649 of 651 right (99.7%). Non-Department evidence: 240 of 242. | Role kind (direction). Country agreement is near-circular, because the list heading and the chapter title share the volume's arrangement (VSE). |
| Printed offices, 1900–1905 | Document sides printing an office; 1,285 of 6,222 documents (SE-DOC-VY) | 1,182 of 1,288 (91.8%): Department 1,002 of 1,047, U.S. mission 0 of 33 | Mostly a Department figure (81% of judged sides) |
| Printed offices, 1861–1899 | 703 of 32,809 documents (2.1%), mostly foreign-government and presidential papers | 66 of 250 (26.4%) | Exposes the failure class; not representative |
| Post-1905 list volumes | 33 volumes, 1914–1952; classifier run outside its era | 2,355 of 2,896 (81.3%) | Outside the classifier's design era |

All MEASURED, MSE. VSE reproduced direction and scale with its own parsers (1873: 645 of 647; U.S. mission 0 of 49).

**Known failure classes** (MEASURED, MSE [V]):
- **Datelined-abroad fallback.** 2,796 of the 27,387 documents shown for 1861–1899 (10.2%) rest on the medium-confidence "datelined abroad" rule. In 592 of them the addressee is not a Secretary or the Department (VSE: 593). An example is a note from Earl Russell to Lord Lyons labelled a U.S. despatch. The heuristic behind that count gives an upper bound.
- **Legation rules not applied.** 2,276 of 4,473 foreign-legation documents are walked up to a parent country title, so the legation rules never run for them (VSE: 2,297 of 4,497 with its own detector).
- **Unshown categories.** The label draws categories from the chosen title's candidates, which include a category Source Explorer does not show in 604 of 27,387 documents (MEASURED, VSE).

**Where identity fails, the label still appears.** For William Hunter's 411 rows in POCOM's 1865–66 gap, the identity rule is corroborated 0 times. The label reads "the Department of State" for 193 of the 197 head-from rows (MEASURED, MSE [V]). That is consistent with 194 head-from datelines reading Department of State (VSE). Correctness is unkeyed.

### 3.6 Correspondence network labelled as such

| | |
|---|---|
| Signals | Editor markup from/to in document heads; optionally 3.5 for node annotations |
| Grain | A directed edge per document (sender to recipient). Nodes are name strings within one volume. |
| Identity asserted | No identity is claimed, but a node is a string clusterer at any scope. A node that spans volumes merges everyone sharing the string (DOCUMENTED, RF [R]). A per-volume node still folds concurrent namesakes within that volume. |
| Quality | Edges are the editors' own typed marks. Direction was not scored on the gold (not measured). Two Sewards were in office concurrently in every year of 1861–69 (W. H. and F. W.) and of 1876–80 (G. F. and F. W.) (DOCUMENTED, FA §2.5 and verdict). A per-volume "Seward" node in any of those volumes already merges two officeholders' correspondence. |
| Reach (TEI-267) | 235,751 from/to rows; distinct from/to keys summed per volume: 28,280 (RC per-volume from/to key; MEASURED, RC [R]) |
| Cost | About 2 sessions for a directed correspondence mode, built as its own view rather than as the co-mention self-join (INFERRED, RA [R]) |
| Gates | The label "correspondence, not co-mention" (FA §4.a). N17: a node must be labelled as a name string as printed, or split by filing role, and a measured Seward-type rate is owed before any node is sized by degree. N8. |
| Verdict | **Conditional** on 3.2 and the N17 node-labelling rule. Cross-volume nodes: **not yet.** |

### 3.7 Detected-names tier at the agreement arm

| | |
|---|---|
| Signals | Editor markup, filtered NLTagger and the filtered Qwen3-14B sweep, combined as editor ∪ (NLTagger ∩ sweep), with sweep-side boundaries |
| Grain | (document, name string) |
| Identity asserted | No |
| Quality (GOLD, post hoc) | **Presence P.** 0.898 [0.852, 0.942]: 245 keys, 25 false (MEASURED, MAG [V]). Under a reversed tie-break, an equally valid maximum matching, P is 0.882 with 29 false; the flips are one real person emitted twice, as full name and nested surname (MEASURED, VAG). **Presence R.** 0.767, 221 of 288 (MEASURED [V]). **Per band.** P 0.980 / 0.973 / 0.745 / 0.842 over 18 / 15 / 15 / 16 documents (MEASURED [V]). **Mention grain.** Strict F1 0.672; relaxed P 0.857 over 350 spans (MEASURED [V]). **No corpus-scale precision exists.** Multiplying the pooled gold P by corpus pairs gives about 78,000 wrong pairs, and weighting by band about 95,000. Both are illustrations across two populations, not estimates (INFERRED, MAG and VAG). |
| Reach (TEI-267) | **Arm.** 768,928 (document, census K2) pairs in 190,658 documents (96.5%), 157,028 keys (MEASURED, MAG [V]); under the grains key the same arm is 758,194 pairs (MCJ [V]). **Beyond the editor layer.** It adds 545,423 census-K2 pairs in 150,674 documents (76.3%). After a within-document last-token collapse — a proxy — that becomes 440,528 pairs in 138,882 documents (70.3%) (MEASURED, VAG). **Where the added pairs sit.** 66.8% have a row inside a paragraph and 2.1% are heading-only (MEASURED, VAG); MAG's 76.1% "body prose" counts lists and tables. **POCOM ceiling for the added pairs.** An officeholder with that surname was in office in 17.4%, exactly one in 15.4% (MEASURED, MAG [V]; ceilings). |
| Cost | **No new model run;** the stores exist. **Size.** The census-format proxy is 2,926,099 bytes with gzip -9, 48 KB larger than editor ∪ filtered NLTagger despite having 11% fewer pairs (MEASURED, MAG [V]). An app-shaped size is not measured (VAG). **Engineering.** 3–4 sessions for generator, artifact and re-apply hook (INFERRED, RA [R]). |
| Gates | An owner floor per band, with the matcher rule fixed (N5); a fresh held-out sample (N3); pre-1910 first: produce the tier over the pinned pre-1910 population, audit it (N21), and only then ship, before extending (FA §5(3), §5 step 12); a keyed audit of each produced layer before it ships (N21); the N24 exclusion list; the OS-build pin and filter promotion; a bundle decision; "Detected name" wording and a provenance label (none of the 8 fits); N8 |
| Verdict | **Conditional** |

### 3.8 Search facet by name

| | |
|---|---|
| Signals | The vocabulary of 3.2 or 3.7; FTS |
| Grain | A name string across documents or volumes |
| Identity asserted | Implicitly: a facet bucket folds everyone who shares the string |
| Quality | **String folding is measured.** 'johnson' (10,761 filtered-sweep mentions, census K2) and 'wilson' (10,010) each fold several people (MEASURED, FA §2.1). **FTS stemming also misleads.** 'Wells' matches 41,794 documents in the TEI-rule volumes, but the case-sensitive word occurs in only 311 of them (0.74%). 'Root' occurs in 936 of 1,784 (MEASURED, MOF [V]; app-view documents in the TEI-rule volumes). These are ceilings on token occurrence. The app's `frus_exact_word` function is the post-filter (DOCUMENTED, MOF). |
| Reach | Whatever vocabulary ships |
| Cost | **Engineering.** About 1 session once the data exists (INFERRED, RA [R]). **Latency** (Mac, Python sqlite3 3.51.0, not iOS). Counts restricted to the 267 TEI-rule volumes through a join, warm: Seward 4.4–4.9 ms, Hull 10.5–12.1 ms, Wells 73–474 ms (MEASURED, MOF and VOF). One volume through a join: 0.24–72 ms across MOF's ten surnames (MEASURED, MOF `fts-timing.json`; MOF's summary prose says 3–72 ms, which omits its Bliss and Blaine rows). One volume by `rowid BETWEEN`: 0.01–0.03 ms (MEASURED, MOF; not reproduced by VOF). One document: ≤ 0.05 ms (MEASURED, MOF). |
| Gates | An owner aggregation rule (N17); the exact-word post-filter; the gates of the vocabulary it reads |
| Verdict | **Conditional** |

### 3.9 Claude-verified names

| | |
|---|---|
| Signals | **Candidates.** The agreement arm and the priced adjudication queue. **Verifier.** Claude (Sonnet 5 or Opus 5) through Message Batches, with ±300-character windows merged per document (MCJ's design) or ±200 characters around each key's first occurrence (RC's design), against whole documents. **Controls.** A local 27–31B model and a gazetteer-only arm. |
| Grain | (document, name string) |
| Identity asserted | No |
| Quality | **Unmeasured.** **Required performance.** On the gold's three-way pool, a verifier must reject at least 89.0% of false keys to reach P 0.898, and at least 92.7% for no more than one false name per 3 documents (INFERRED, RF [R]). On 64 documents, a precision arm registers as better only if it removes at least about 80% of false spans while losing no more than about 2% of true ones (INFERRED, RC [R] from LP `churn.json`). **Queue yield on the gold**, a post-hoc ceiling (GOLD; lenient any-overlap credit, looser than the scorer's one-to-one matching): at most 58 of 330 queue pairs could add a true new name (17.6%); 241 overlap no gold mention (MEASURED, VCJ). A scorer-matched count restricted to the queue was not computed. **Corpus pools.** At least 119,094 of the census net pool's 1,072,769 pairs (census K2; 11.1%) are NLTagger boundary variants of mentions both detectors found (MEASURED, VAG). That share applies to the census pool, not to the priced queue, which already drops every span overlapping an agreement span. The priced queue's own inflation is 122,887 pairs (11.7%) repeating a key the agreement arm already shows in that document (MEASURED, VCJ). |
| Reach | See the jobs table below the card. |
| Cost | **Corpus jobs.** See the jobs table and §3.9.1. **Locally,** Qwen3-14B no-think needs about 183–191 Studio hours for the queue and 171–176 hours for the arm filter; quality is unmeasured (INFERRED, MCJ [V]). **A screen on the 64 gold documents,** 3 replicates, windows: Opus 5 standard high effort $0.8 / $1.6 / $10.2 (queue) and $0.7 / $1.4 / $10.1 (arm filter); Sonnet 5 standard high effort $0.4 / $0.6 / $4.0 and $0.3 / $0.6 / $4.0; Opus 5 batch+cache low effort $0.2 / $0.4 / $2.7 and $0.2 / $0.4 / $2.6 (INFERRED, MCJ). **A whole-document arm on the gold** is not priced as such. The nearest priced shape is LP's whole-pool adjudication, S1-c: 3 replicates, standard pricing, Sonnet $10.21–10.83 and Opus $25.54–27.08 (INFERRED, LP `program-fit/pilot_cost.json`). With a generous thinking allowance, P2 put a pilot at up to about $150 (DOCUMENTED, P2). **A confirmation run** on about 250 fresh documents is priced only for the whole-document arm, in RC R6's S1-c shape (adjudicating a three-way candidate list over whole documents; RC priced it for pre-annotation, which it recommends against for any scoring instrument): Sonnet $14.61–15.83 and Opus $36.53–39.59 per run, standard, at the corpus mean length of 3,439 characters (INFERRED, RC R6 [R]). The windowed verifier on that sample is not priced. |
| Gates | N1–N6, N10, N11, N14, N21; a per-band floor. **Order:** the arm filter before or with any recall job, because only the arm filter moves 1930–1945. **Pre-1910 first:** before any corpus pass (§5). |
| Verdict | **Not yet.** A screen is conditional on authorization, a cap and pre-registered thresholds, and a confirmation on a fresh held-out sample. A corpus filter pass produces Claude verdicts, not a precision estimate; precision comes only from a keyed sample (VCJ). |

The two verification jobs (costs INFERRED, MCJ [V]; VCJ `vcost.json` reproduces all four treatments shown):

| job | population (TEI-267) | perfect-verifier ceiling on the gold (post hoc) | Sonnet 5, batch+cache, low effort | Opus 5, batch+cache, low effort | Sonnet 5, standard, high effort | Opus 5, standard, high effort |
|---|---|---|---|---|---|---|
| Filter the agreement arm (precision) | 1,310,341 spans / 758,194 pairs (grains key; the same arm is 768,928 pairs under census K2) (MEASURED, MCJ [V]) | Editor + perfectly filtered arm: P 0.9955, R 0.767, false keys 25 → 1; per band P 1.000 / 0.973 / 1.000 / 1.000, so 1930–1945 goes from 0.745 to 1.000 (MEASURED, RC [R] `disagreement.json`) | $129 / $209 / $1,113 | $257 / $495 / $2,865 | $371 / $738 / $4,395 | $780 / $1,790 / $11,250 |
| Verify the priced adjudication queue (recall) | 1,526,825 spans / 1,051,899 pairs (grains key), 929,012 of them new at presence grain (MEASURED, MCJ and VCJ) | Editor ∪ arm ∪ a perfectly verified disagreement set: P 0.921, R 0.969; per band P 0.985 / 0.977 / 0.772 / 0.884. 1930–1945 precision is untouched by the recall job (MEASURED, RC [R] `disagreement.json`; RC's disagreement set differs slightly from the priced queue) | $146 / $223 / $1,130 | $292 / $525 / $2,913 | $421 / $785 / $4,310 | $885 / $1,900 / $11,045 |

### 3.9.1 The two cost bases

MCJ and RC price the same two verifier roles about 2× apart. The owner was shown MCJ's dollars and RC's text shares; the table puts each design's own figures together.

| design | window | precision-role population | recall-role population | characters sent (share of 679,401,514) | Sonnet 5 batch+cache central | Opus 5 batch+cache central |
|---|---|---|---|---|---|---|
| MCJ (priced throughout this file) | ±300 characters around every span, merged per document | agreement arm, editor spans included: 1,310,341 spans / 758,194 pairs (grains key) | priced adjudication queue: 1,526,825 spans / 1,051,899 pairs (grains key) | 310,674,650 (45.7%) / 346,287,109 (51.0%), plus 30.8M / 41.9M of candidate listings (MEASURED, MCJ `pools.json`) | $209 / $223 (INFERRED, MCJ [V]) | $495 / $525 (INFERRED, MCJ [V]) |
| RC | ±200 characters around the first occurrence of each key, merged per document | agreement-arm spans the editors did not mark: 1,029,227 spans / 570,129 keys (RC surface key) | disagreement set: 1,529,887 spans / 1,053,359 keys (RC surface key) | 144,448,409 (21.3%) / 226,841,519 (33.4%) (MEASURED, RC `disagreement.json`) | $106 / $155 (INFERRED, RC `pricing.json` [R]) | $251 / $364 (INFERRED, RC `pricing.json` [R]) |

Shares INFERRED.
- **What drives the gap.** Mainly the window design. The populations also differ: RC's precision role excludes editor-marked spans, and RC's disagreement set is not the priced queue (INFERRED, from the two definitions).
- **High scenarios are not comparable.** RC's are priced at high effort with one request per document: $1,135 / $1,328 on Sonnet 5. MCJ's high scenario is at low effort: $1,113 / $1,130.
- **Quality under either design is unmeasured.** Whether first-occurrence windows lose the context a verifier needs is not known. Seven known false-positive rows needed context beyond the sentence (DOCUMENTED, RC from LP `fixability`).
- **Consequences.**
  - Caps in this file use MCJ, the higher base.
  - The window design is a lever on cost and on authorization scope (N1).
  - It belongs in the screen as a tested factor, beside windows against whole documents.

### 3.10 Claude-written correspondents guides

| | |
|---|---|
| Signals | Structured facts from 3.2 (heads, datelines, document ids), POCOM career lines and Source Explorer roll pointers, written up by Claude or by the on-device FoundationModels |
| Grain | Prose per volume or per chapter |
| Identity asserted | Not required, but prose invites it. Any sentence naming a POCOM officeholder inherits 3.11's gates. |
| Quality | No instrument exists. A claim-level citation audit is needed. |
| Reach | 267 volumes. 9,954 structure sections contain at least one marked row (MEASURED, MCJ; live-index section structures over the TEI-267 volume ids). RC counts 12,087 sections in the app view (MEASURED, RC [R]). The 90th-percentile section has 4,232 characters of heads and datelines (MEASURED, RC [R]; app view, RC's section definition). |
| Cost | **Per volume,** about 1,500 words: Sonnet 5 batch+cache low $5.5 / $6.4 / $8.1, and Opus 5 standard high $54 / $70 / $92 (INFERRED, MCJ [V]). MCJ's per-volume key counts used `k2_surface`, not census K2, with negligible cost effect (VCJ). **Per chapter,** about 1,500 words over 9,954 chapters: Sonnet 5 batch+cache low $174 / $200 / $249, and Opus 5 standard high $1,897 / $2,446 / $3,153 (INFERRED, MCJ). **On device,** the model costs nothing per request, and a 90th-percentile section's facts fit its 3,072-token budget. Its output is per device, unscored and cannot be bundled (INFERRED, RC [R]). |
| Gates | 3.2 first; N9 grounding and the citation audit; localization of generated English prose; N10; a bundle decision; provenance |
| Verdict | **Not yet** |

### 3.11 POCOM "possible officeholder" tier with filing context

| | |
|---|---|
| Signals | Editor-marked from/to rows, POCOM surname × year, the Source Explorer chapter post, and deterministic initials and signature checks. No model. |
| Grain | (document, side) mapped to a POCOM slug, held in a table of its own |
| Identity asserted | Yes, hedged as "possible identity, from filing context" |
| Quality | **No precision on the target population:** 0 of 300 evaluation rows are keyed (MEASURED, VCJ). What exists is listed in the bullets below the card. |
| Reach | **Ceiling:** the 45,258 rows where POCOM names exactly one person (MEASURED, MSE, SE-ROWS 1861–1899). **Era ceiling:** the Source Explorer classifier reads volumes dated up to 1905 only, 38,953 of 197,534 TEI-267 documents (MEASURED, CR). |
| Cost | No API cost. 3–4 sessions (INFERRED, P3 and RA [R]), plus a larger POCOM artifact and the owner sitting. |
| Gates | Build and measure the deterministic checks first. Then key a blind sample sized to the claim (INFERRED, MSI; bounds are MEASURED arithmetic [V]). **(A) The two-signal-agreement stratum.** 100 rows from the stratum where the surname rule and the chapter post agree: 37,301 rows as shown, 1861–1899 (MEASURED, MSE; its chief-of-mission part is not independently reproduced, VSE). Draw 25 per decade (1861–69, 1870s, 1880s, 1890s), excluding F. W.-initial, Secretary-convention-narrowed and location-narrowed rows. Zero errors give a lower bound of 0.963; one error gives 0.9455. **Tier A licenses that stratum only** — not the 45,258 single picks, not the 8,642 convention-narrowed rows, not the 2,081 location-narrowed rows. **FA §6.4 still applies:** ≥ 0.90 pooled and ≥ 0.80 in every 75-row band, plus a measured per-volume rate at which one surname denotes more than one officeholder. Tier A's 100 rows fill one such band for 1861–1899 as a whole; a per-decade claim would need about 75 rows per decade, not 25 (INFERRED, FA §6.4). **(B)** About 380 rows for claims about individual rule classes. **(C)** 450–500 rows for coverage beyond that stratum. **Sizing caveat.** The stratum sizes in MSI's sample design predate #1292, which changed the suggestions of 8.9% of 1861–1899 documents (VSI). **Storage and wording.** A separate table: no `authority_id`, no merge overrides, no seal. Owner wording and a provenance sentence; N8; N15. |
| Verdict | **Not yet** |

Evidence available for 3.11 (SE-ROWS 1861–1899, post-#1292, what Source Explorer shows):

- **Chapter rule.** POCOM names one person in 45,258 of 84,234 rows. The chapter post corroborates 37,301 (82.4% of 45,258, INFERRED) and contradicts 2,062. Location narrows several candidates to one in 2,081 rows; the Secretary-over-assistant convention alone narrows 8,642 (MEASURED, MSE). VSE re-derived the Department part row by row (15,692 of 15,696 rows agree); the chief-of-mission part was not independently reproduced. "Corroborated" means two rules applied to the same register agree.
- **F. W. Seward.** 117 head-from rows are first-signed by F. W. Seward. W. H. Seward is assigned to all 113 of them that Source Explorer shows, and the #1292 sender rule decides 0. The initials in the row would catch 108 (MEASURED, MSE [V-part]: VSE reproduced the 117 rows, shown 68 → 113, the sender pattern matching 106 and the rule deciding 0; the W. H. assignment, 113 of 113 shown and 117 under T_after, is MSE only).
- **William Hunter, 1865–66.** 411 rows, 0 corroborated in every arm (MEASURED, MSE [V]).
- **Silver covers post-1910 only.** Where POCOM picks one person on a positive silver head, it agrees 0.9993 / 0.9982 / 0.9624 of the time in 1900–1929 / 1930–1945 / 1946– (MEASURED, MSI [V]). Adding crosswalked people who have no POCOM slug gives 0.972 / 0.939 / 0.863 (INFERRED, MSI).
  - **Not a precision.** That figure is an agreement rate over the heads the OH registry covers.
  - **Concentrated errors.** They come mostly from three namesake pairs: Lyndon B. / U. Alexis Johnson 649, McGeorge / William P. Bundy 619, Woodrow / Charles S. Wilson 88.
  - **Band key.** It is banded by TEI document year; under the assessment's volume-id key, 1930–1945 is 0.930 (MEASURED, VSI).
  - **Exclusions.** It leaves out 539 / 1,490 / 0 picks on linked heads with no crosswalk id, and in 1930–1945 those outnumber the scored picks (MEASURED, VSI).
  - **The "1900–1929" silver band** holds only 1910–1919 documents.
- **Pre-1900 silver is one person.** Hamilton Fish, on 459 heads (MEASURED, MSI [V]).
- **Head format differs.** Untagged 1861–1899 from/to heads, by TEI document year, are 95.7% bare honorifics, and an office word appears in at most 1.3%; silver, outside Fish, is 0% bare honorific (MEASURED, MSI; VSI: 96.4% start with an honorific, an office word appears in at most 1.3%). Silver therefore cannot license pre-1900 identity.
- **Coverage.** 25,687 arm-B rows (1861–1899) have no candidate because the role is outside POCOM (MEASURED, RC [R]). Bundled POCOM careers cover 6 of the 481 people who held a chief-of-mission or principal post in 1861–1905 (DOCUMENTED, P3).

### 3.12 Inline highlighting of unmarked names

| | |
|---|---|
| Signals | Agreement-arm spans (sweep boundaries), R-0 offsets, and a mapping to the reader's render text |
| Grain | A character span in the render flat text (UTF-16 offsets) |
| Identity asserted | No, but it marks a string as a person inside the text itself |
| Quality | **Mapping.** Exact, unique matches on 20- then 10-character context anchors. On SAMPLE-400 that places 88.3% of sweep spans and 88.8% of NLTagger spans correctly and 0 wrongly. It refuses 4.9% / 4.3%, and leaves 6.8% / 6.8% inside footnotes, which have no body offset (MEASURED, VOF; MOF's 5.6% / 4.9% footnote share was undercounted). **Fallbacks that fail.** A surface-only fallback puts footnote spans onto body text (42 of 338 sweep footnote spans) and must not be used (MEASURED, VOF). A converter that wraps every occurrence of a detected surface would wrap 11.9–16.7% of occurrences that no detector tagged (MEASURED, VOF, two samples). **Name quality** is the arm's mention grain: strict F1 0.672, relaxed P 0.857 (MEASURED, MAG [V], GOLD). |
| Mechanism | Highlights are UTF-16 offsets into `buildFlatText`, footnotes excluded, painted by the CSS Custom Highlight API. They go stale when `renderingVersion` changes. The renderer drops `<list><label>` text (DOCUMENTED, MOF [V]). |
| Cost | 3–4 sessions (INFERRED, RA [R]) |
| Gates | A mention-grain floor, stricter than presence; an aligner or a render-time anchored search; a treatment for footnote names; a staleness rule; a tap handler; wording; all of 3.7's gates (N16) |
| Verdict | **Not yet.** The engineering is tractable; mention-grain name precision blocks it. |

### 3.13 Claude-adjudicated identities

| | |
|---|---|
| Signals | Editor-marked from/to rows, POCOM careers, the Source Explorer post, Claude |
| Grain | (document, side) mapped to a slug or to "not in POCOM" |
| Identity asserted | Yes |
| Quality | **No instrument.** A Claude pick scored against its own pre-fill measures nothing. For 18.6% of marked correspondent mentions no local candidate exists, so any answer there would come from model memory (DOCUMENTED, P2). |
| Reach | **Contradicted + location-narrowed + Seward-convention rows, 1861–1905.** 13,907 (B0, the pre-#1292 approximation); 14,495 (B_after, the same approximation layered over the merged output); 13,252 as Source Explorer shows after #1292 (arm A, S_after); 14,485 for the merged classifier's candidates without the roll test (T_after: 2,536 + 2,167 + 9,263 in 1861–1899, plus 509 + 10 in 1900–1905). MEASURED, MCJ and MSE; VCJ reproduced 13,907, 14,495 and 13,252 by re-running the rule script. **Unresolved (volume, surface) marked rows:** 22,688 (DOCUMENTED, LP `cost-scale`; RC [R]). **Era ceiling:** volumes dated up to 1905 only. |
| Cost | **13,907 rows, rows only:** Sonnet 5 batch+cache low $4.0 / $5.7 / $13.1 (INFERRED, MCJ [V]). **With document text:** Sonnet 5 $17 / $20 / $36 and Opus 5 $34 / $46 / $92 (INFERRED, MCJ). The post-#1292 counts move the Sonnet batch cost by under $0.5 (VCJ). **The 22,688 unresolved rows:** Sonnet $10, Opus $24, central, batch+cache, low effort (INFERRED, RC [R]). |
| Gates | Deterministic checks first; the blind-keyed stratified sample of 3.11; N9 grounding; a separate table; never the seal; N1, N2, N10, N11 |
| Verdict | **Not yet.** Cost is trivial; the owner's keying sitting is the gate. |

### 3.14 Identity tier

| | |
|---|---|
| Signals | All of the above |
| Grain | Authority identity |
| Identity asserted | Yes |
| Quality | 0 of 300 keyed. POCOM surname × year is a 55.4% ceiling on the marked layer and 12.7% on the detector layer (MEASURED, FA §2.5). Silver licenses post-1910 regression testing only. |
| Cost | Dominated by owner sittings (§2.5) |
| Gates | FA §6.4's identity trigger, applied to each identity rule; N4 |
| Verdict | **Not yet**, unchanged |

### 3.15 Participant fields in the shipped on-device summary templates

| | |
|---|---|
| Signals | On-device FoundationModels over one document. Three structured templates ask for people: Meeting Record (KeyParticipants), Diplomatic Exchange (Parties) and Individual Role Trace (`SummarizationPromptSeeder.swift:264-283, :334-353, :381-400`; DOCUMENTED, RA [R]). |
| Grain | Per-document generated text; no identity field, no offsets |
| Identity asserted | Yes, implicitly. The model can fill full names from its training data where the document prints only "Mr. Adams". |
| Status | **Already shipped, with no gate.** |
| Quality | **Unmeasured,** and no instrument can score it, because identity rows are unkeyed. 18.6% of marked correspondent mentions have no candidate in any local source (DOCUMENTED, P2), so a full name there can only come from model memory. |
| Reach | **Where it runs.** Any document a reader summarizes, untagged volumes included. **Where the output goes.** It is stored in `GeneratedSummary` (`GeneratedSummary.swift:56`, a CloudKit-synced `@Model`) and indexed into `document_cache.summary_text` (`IndexingPipeline.swift:5852`). A generated name therefore becomes full-text searchable and syncs to every device (DOCUMENTED, RA [R]). **Existing labels.** The `.aiGenerated` authorship chip and `ProvenanceSource.appModel` exist (DOCUMENTED, RA [R]). |
| Cost | **Rewording.** 0.5–1 session to seed a standard template: prompt records of an existing model, with no schema change and no reindex (INFERRED, RA [R]). **Search exclusion.** Excluding generated names from name search is not sized. |
| Gates | N23; N6 wording |
| Verdict | **Owner decision owed now.** It is a live instance of gate 5(c). The options are explicit acceptance, or template wording that keeps names as printed in the heading, a disclosure on the summary, and exclusion of generated names from name search. |

### 3.16 Disposition of the surfaces #234 named, and of the surfaces that inherit person rows

Every shipping person surface except the word-cloud People lens and the summary templates reads `persons` / `person_mentions` / `person_rollup` (DOCUMENTED, RA [R]). **Isolated carriers therefore deliver none of the surfaces below.** Each is delivered only as a new, separate view, or by folding entries into the person tables. Folding in needs RA's shared data layer: 2–3 sessions on the parse-time route, 3–4 on the artifact route, and 0.5–2 sessions per surface on top. It also needs `currentDateIndexVersion` and `currentPersonRollupVersion` bumps (INFERRED, RA [R]). It brings back FA §4.a's clusterer gate and the synthetic-ref namespace. That choice is §6 decision 9.

| surface | named in #234 or inherits | reads | under isolated carriers | nearest separate view | what folding entries in re-imports (DOCUMENTED, RA [R]) |
|---|---|---|---|---|---|
| People browser list and person detail sheet | named | `person_rollup`; seal on authority id | not delivered | 3.2 per-volume correspondents section; 3.11 separate candidate table | clusterer merges (the Seward father and son in one row); list rows deliberately unbadged (`ProvenanceMountTests.swift:255-277`), so a derived row cannot be told apart |
| Person search: autocomplete, person filter, saved searches | named | `persons.name` LIKE; `person_mentions` EXISTS | not delivered | full-text search (§3.19); 3.8 name facet | derived suggestions indistinguishable without a new cue. A filter kind rides the `parametersData` blob; a new stored property on `SavedSearch` would need a CloudKit deploy. |
| Person Analytics | named | per rollup per year | not delivered | none | merged identities inflate one bar; a trend jump where the derived layer begins |
| Co-mention graph | named | self-join on `person_mentions` | not delivered | 3.6 correspondence network, as its own view | heading pairs mixed with body co-mentions; phantom nodes from detector strings; false hubs |
| Related documents: shared-people axis | inherits | `SharedPersonScorer`, Jaccard over rollup ids, weight 0.7 | not delivered | none | a wrong person silently changes relatedness ranking, with no visible cue |
| Collections Persons Index and PDF/DOCX/HTML exports | inherits | rollup × document | not delivered | none | wrong persons in citable exports that travel without the app; `ProvenanceStatement` recites no method for derived names |
| Search results People facet | inherits | `person_rollup_member` | not delivered | 3.8 name facet | merged rollups inflate counts; no per-bucket provenance |
| Custom-scope person facet | inherits | rollup reduced to volume counts | not delivered | none | silent widening or narrowing of a scope; whether a saved scope stores the facet is unverified |
| Front-matter persons list, inline `persName` links, person–subject affinity | inherits | `persons` rows and refs | not delivered | 3.2 volume section; 3.3 rail list; 3.12 | as the People browser; affinity is volume-grain and can read as a per-document link |

### 3.17 Identity-free carriers that read printed text

| carrier | signals and grain | risk (DOCUMENTED, RA [R]) | cost (INFERRED, RA [R]) | gates | verdict |
|---|---|---|---|---|---|
| Citation note: "Correspondents as printed: Mr. Adams to Mr. Seward" in Zotero / RIS / BibTeX exports | heading text; per document | wrong name string in a citation; normalising to POCOM names, or placing names in creator fields, would assert identity | 1 session; no reindex, no schema change | names stay as printed (`ProvenanceMountTests.swift:185` pins that a copied citation carries no provenance sentence); never creator fields | **buildable now** |
| Chronology rows: "Despatch dated London — heading: Mr. Adams to Mr. Seward" | heading rendered as printed, dateline attached to the document; per document | wrong name string; a parsed place or direction read as the named person's post | 1 session, live; a reindex only if correspondents are persisted | `.frusText`; attach the dateline to the document, never to the name, and show no parsed direction; direction accuracy is not measured (§7.1) | **buildable now** in that form; a parsed direction or a post filter is conditional on a keyed direction and placement check |
| Trip-packet pull list with correspondents as printed | the Source Explorer classifier called at packet build time, plus heading text; archival classification per document | a wrong reel on a paid trip; POCOM full names in the citation crib would break its as-printed design | 1–2 sessions; `CentralFilesClassifier` is already compiled into the app; no reindex, no CloudKit deploy | a keyed sample of archival suggestions, as §3.18 requires, or a disclosure that the pull list comes from an unmeasured classifier; Source Explorer's confidence wording; N22; the era ceiling (volumes to 1905) | **conditional** |

### 3.18 Carriers that aggregate the Source Explorer classifier

Each needs the classification persisted: a new index table filled at index time, or a bundled aggregate. Source Explorer's suggestion precision is not measured on any population (DOCUMENTED, RA [R]), so counts built from it would present an unmeasured pointer at scale. All are limited by the era ceiling: volumes dated up to 1905, 38,953 of 197,534 TEI-267 documents (MEASURED, CR).

| carrier | risk (DOCUMENTED, RA [R]) | cost (INFERRED, RA [R]) | verdict |
|---|---|---|---|
| Posts browse axis ("U.S. Legation, London — 1861–1905 — N documents, from datelines and chapters") | wrong archival pointer at scale; a correspondents axis adds wrong name strings | 2 sessions; a new `BrowserLevel`, a new view file (`xcodegen`), persisted or bundled data (reindex) | **conditional** on a keyed sample of archival suggestions, which is not staged |
| Pre-1906 archival analytics aggregation | unmeasured precision presented as counts; inferred filing mixed with editor-cited source notes | 2–3 sessions; reindex | **conditional**, as above, plus a disclosure that the counts are inferred from dateline and chapter |
| Series dashboard card ("where pre-1906 documents were written") | wrong archival pointer; POCOM officeholders presented as FRUS participants | 1–2 sessions; a bundled aggregate, `xcodegen`, a `BundledArtifactProvenance` row | **conditional**, as above |
| Semantic-map post lens | wrong archival pointer; wrong name strings for a correspondent highlight | 1–2 sessions | **conditional**, as above |

### 3.19 Already-shipped surfaces that reach untagged people

| surface | what it shows | identity | disposition |
|---|---|---|---|
| Office of the Historian volume people tags | Presidents and secretaries of state at volume grain. 647 assignments on all 267 untagged volumes, at most 7 per volume, from a taxonomy of 121 people tags (MEASURED, RA `manifest_people_tags.json` [R, file read]). Shown as volume chips (`BrowserViewModel.swift:553-570`) and filters (`SubseriesView.swift:296-305`) (DOCUMENTED, RA [R]). | asserted by the Office of the Historian, at volume grain | Keep. They must not be read as document mentions (RA). No action owed. The document-subject index has no people category among its 13 (MEASURED, RA `oh_people_subjects2.json`). |
| Full-text search | Finds printed names in any document; the in-app empty-state copy points readers to it (`FrontMatterPersonsView.swift:104`; DOCUMENTED, RA [R]) | none | Keep. Porter stemming folds 'Wells' into 'well': 311 of 41,794 matching documents hold the case-sensitive word (MEASURED, MOF [V]). The `frus_exact_word` post-filter exists (DOCUMENTED, MOF). |
| Word-cloud NLTagger People lens | Name-string counts per scope | none | §3.4 |
| On-device summary templates | Generated participants | implicit, from model memory | §3.15 |

---

## 4. Per-assessment deltas

### 4.1 The feasibility assessment (FA, PR #1290)

| statement | where | changes? | what it now reads |
|---|---|---|---|
| "The thing that decides feasibility is not the detector — it is the app's own rollup." | Verdict; §6.1 | **Changes** | For carriers outside the person tables the clusterer never reads the rows. Per-feature floors, blind-keyed identity and post samples, and measured verifiers decide instead (§1). Those carriers also deliver none of the surfaces #234 named (§3.16). |
| "It is a correspondent index, not a people index (97.8% …)." | Verdict; §2.1; §4.a | No | A property of the editors' markup. Any carrier built on it inherits it. |
| "A measured wrong-name rate of zero on the 64-document gold (0 false name keys of 79; 88 of 88 predicted spans overlap a gold mention)." | Verdict | **Changes in status** | FA already named the 88 marked spans as the gold's seeds (FA §2.2, "53 exact + 34 title-extended + 1 split of 88 seeds"), but presented P 1.000 / 0 false keys as measured quality. The annotator, shown those spans, removed none (MEASURED, VSI), so relaxed precision 1.000 follows from that outcome. It cannot detect a wrong editor mark and is not an independent precision. |
| "Read from the shipped `PersonClusterer`'s code, it would merge confidently-wrong persons by default." | Verdict; §3.4 | **Changes** for isolated carriers | The defect class survives wherever a carrier aggregates by name string — per-volume network nodes included — and in any POCOM or Claude identity pick. It is already live in the summary templates (§3.15). |
| "Every shape needs a code gate in `PersonClusterer` before a single derived row exists." | §3.5 | **Changes** | Becomes the isolation invariant (N8). The full gate returns if entries are folded into the People browser. |
| Agreement arm "acceptable … behind an owner precision floor" | Verdict; §4.b2 | No, for direct display | Two additions. The gold P depends on the matcher tie-break: 0.898 or 0.882 (MEASURED, VAG). The corpus census now exists for reach and census-format size, not precision (§2.1, gate 20). |
| "NLTagger alone is borderline." | §4.b1 | No, for display; relaxes as verifier input | As a candidate source, its recall matters more than its display precision. |
| "Any sweep-bearing presence layer is not acceptable (≈3.8 wrong names per document)." | Verdict; §4.b3 | No, for display; relaxes as queue input | The sweep-only increment is 977,228 of the 1,841,697 three-way union pairs (census K2; 53.1%) and adds 4,306 documents (MEASURED, RF [R]). The 1,841,697 equals MAG's 768,928 arm pairs plus the 1,072,769 census net pool pairs [V] (INFERRED arithmetic). |
| "Identity reconciliation … is not shippable on current evidence." | Verdict; §4.c | No | Silver adds post-1910 regression material only (§3.11). |
| "No shipping person surface reads a character offset … the sweep's offsets justify only an inline surface that does not exist." | §3.1; §3.5 | **Changes** | "Maximum use" proposes such surfaces, and the mapping is now measured: 88.3% of sweep spans placed correctly, 0 wrongly (MEASURED, VOF). |
| "Step 0 … the cheapest early-era gain in the whole program." | §4.0; §6.2 | **Changes** | Fixed in code by #1291. The owner's reindex is what remains. |
| "The agreement arm's corpus-scale rows, reach and size — unmeasured." | §4.b2; §5; §7 | **Changes** | Measured: 1,310,341 rows, 768,928 pairs (census K2), 190,658 documents, and 2,926,099 bytes gzipped in the census format (MEASURED, MAG [V]). The by-analogy estimate (8.99 MB / 2.88 MB gz) was close. No app-shaped size and no corpus precision exist (VAG). |
| "What the 11.55-day sweep is for … not evidence for identity, roles or dates." | §4.d | Partly | The review queue and the offset-bearing layer move from contingent uses to central ones. "Not evidence for identity" is unchanged. |
| The first slice: Step 0, then (a) whole-scope, then (b2) after the ingestion path is exercised, then (c) on pre-1910 | §6.2 | **Changes** | Replaced by §5 here. "Pre-1910 first" survives and is extended to the detected tier and every verifier pass. It is strengthened because pre-1900 identity evidence can only come from filing context. |
| POCOM ceilings, 55.4% / 12.7% | §2.5 | No | The loader misses Monroe's one attribute-bearing appointment block, which moves 5 rows (MEASURED, VSE). That is within FA §7's disclosed ≤ 8 rows. |
| Dollar lines rescaled from the Ride-Along's per-candidate pricing | §4.c; §7 | **Superseded for editor-marked correspondents only** | For those rows: MCJ job C, and RC R4 for the 22,688 unresolved rows (Sonnet $10 / Opus $24 central, batch+cache, low effort; INFERRED, RC [R]). Identity adjudication over **detected** surfaces is not priced by MCJ. It remains priced only by FA §4.c's rescale and by RC's 301,979-row detector-union shape: Sonnet $137 / Opus $325 central (INFERRED; DOCUMENTED in LP `cost-scale/costs.json` via RC [R]). |

### 4.2 The Claude-pass answer (P2)

| statement | changes? | what it now reads |
|---|---|---|
| "Probably yes for one job": judging existing candidates, not re-reading for new ones | **Narrows** | Two separable jobs replace one whole-pool judge. **(1) Filter the agreement arm, for precision.** Its post-hoc ceiling is P 0.9955, R 0.767, per band P 1.000 / 0.973 / 1.000 / 1.000. It is the only role that can move the owner's per-band floor, because 24 of the arm's 25 false keys on the gold lie in its intersection spans, outside the disagreement set (MEASURED, RC [R]). **(2) Verify the disagreement set, for recall.** Ceiling P 0.921 / R 0.969, but per band P 0.985 / 0.977 / 0.772 / 0.884. 1930–1945 precision is untouched by the recall job, so the arm filter must come first or with it (MEASURED, RC [R]). |
| A perfect judge of the pool scores 0.988 against 0.828 for the best arm | No | Still an in-sample ceiling on the gold, now split by job as above |
| Cost table: re-read $440–680 / $1,000–1,600; judge $460–700 / $1,100–1,700; identities $160–320 / $410–790 (Sonnet 5 / Opus 5) | **Changes** | **The identities line** priced a 301,979-row detector-union shape; the 29,949 marked correspondent rows cost $13 / $32 (DOCUMENTED, LP `cost-scale/costs.json`; RC [R]). **The reframed jobs,** on Sonnet 5 batch+cache, low effort (INFERRED, MCJ [V]): arm filter $129 / $209 / $1,113; priced adjudication queue $146 / $223 / $1,130; Source Explorer × POCOM adjudication $4.0 / $5.7 / $13.1; per-volume guides $5.5 / $6.4 / $8.1. **All four together:** Sonnet $284 / $444 / $2,265; Opus 5 $568 / $1,048 / $5,833; Opus 5 standard high effort $1,757 / $3,829 / $22,548. RC's narrower windows price the first two at about half (§3.9.1). |
| "Pilot the judging and detection on the 64 keyed documents … plus a free local Qwen run" | **Changes** | **Arms.** Drop the detection arms. **Screen.** Screen the two verifier jobs on the 64 gold documents only: windows (both designs) against whole documents, 3 replicates, beside a gazetteer-only arm and a local 27–31B arm on identical inputs. Iterate only there. **Freeze.** Freeze prompts, windows, thresholds, tie-break and model ids by hash. **Confirm.** Run one confirmation on a fresh sample of about 250 documents. **Screen costs** (INFERRED, MCJ), Opus 5 standard high effort: $1.6 central / $10.2 high (queue) and $1.4 / $10.1 (arm filter). All Opus pilots in MCJ's set — A, B, C with document text, D on 24 volumes — total about $25 central and $51 high. A whole-document arm's nearest priced shape is LP's S1-c, Opus $25.54–27.08 for 3 replicates, standard (INFERRED, LP `program-fit/pilot_cost.json`). P2's thinking-heavy ceiling was up to about $150 (DOCUMENTED, P2). |
| "Test identity only after you key 100 pre-1910 rows, blind" | **Changes** | The principle holds, but the sample is wrong for the reframe. The 100 pre-1910 rows give a zero-error lower bound of 0.963 overall, but hold only 12 several-candidate rows, whose zero-error bound is 0.7575 (MEASURED arithmetic, MSI [V]). They were not drawn on Source Explorer outcomes, and they are unkeyed (VCJ). Build the deterministic initials and signature checks first, then key tiers A / B / C (§3.11). |
| "Running this as subagents inside Claude Code is the wrong route." | No, for production passes | Design-time reading in Claude Code already sends corpus snippets to Anthropic, and did so during this assessment (DOCUMENTED, RC R9). N1 must say whether that is covered. |
| "One untested cheaper option": Gemma-4 31B and Qwen3.6 27B on the Studio | **Changes** | Becomes a required control arm. On Qwen3-14B no-think, all four jobs take 367.7 or 369.4 Studio hours under one consistent time model (INFERRED, VCJ; MCJ's 361–376 h bracket mixed two models). Local verifier quality is unmeasured. |
| "A good result would not change the rollup code gate or your name-string decision." | **Partly changes** | The rollup gate no longer binds isolated carriers. A good arm-filter result can move the per-band floor for the detected tier. It moves nothing about identity. |
| "In 96% of those [pre-1900] documents the head reads only 'Mr. Seward to Mr. Adams', and just 2.2% name a post." | No; corroborated at head grain | Untagged 1861–1899 from/to heads, by TEI document year: 95.7% bare honorific; an office word in at most 1.3% (MEASURED, MSI; [V-part]: VSI found 96.4% honorific-led with a different classifier; head population, not documents) |
| "62–81% of heads name a post and place" after 1900 | **Changes** | That does not hold for 1900–1909: 68.0% of its untagged heads begin with an honorific. From 1910 on, 76.0% use the parenthesised-name form (MEASURED, VSI; by TEI document year). |
| "18.6% of the marked correspondent mentions have no candidate in any local source" | No | It now defines the grounding gate (N9). The same failure is already reachable through the shipped summary templates (§3.15). |
| "Having a model pre-fill them would contaminate the only scoring set." | No; extended | It now covers every instrument, including the label sample and the fresh detection sample (N4). Editor seeding without planted errors is covered too (N3). |

### 4.3 The Source Explorer answer (P3), with the post-#1292 numbers

**Share of documents with an archival suggestion**

| population | before #1292 | after #1292 | source |
|---|---|---|---|
| SE-DOC-AY, 1861–1899 (32,478 documents) | 24,981 (76.9%) | 27,884 (85.9%) | MEASURED, RF `se_denominator.json` [R, file read]. VSI measured 2,904 documents changed (8.9%), almost all additions. |
| Same population: documents with a Notes to / Notes from Foreign Missions suggestion | — | 11,930 any; 3,763 only that | MEASURED, RF `se_shift.json` [R, file read] |
| SE-DOC-VY, 1861–1899 (32,809 documents) | 24,876 (75.8%) | 27,387 (83.5%) | MEASURED, MSE [V] |
| SE-DOC-VY, 1900–1905 (6,222 documents) | 4,957 | 4,957 | MEASURED, MSE [V] |

**The chapter rule on SE-ROWS, 1861–1899** (84,234 rows; POCOM's surname-by-year rule names one person in 45,258)

| arm | corroborated | contradicted | several → one by location | several → one only by the Secretary convention | chapter rule names one |
|---|---|---|---|---|---|
| A0: shown, before #1292 (P3's "as shipped") | 36,269 | 1,921 | 1,982 | 6,805 | 45,056 |
| **S_after: shown, after #1292** | **37,301** | **2,062** | **2,081** | **8,642** | **48,024** |
| B0: Python approximation of the title repairs, before (P3's "repaired" figures) | 40,907 | 2,415 | 2,240 | 8,733 | 51,880 |
| B_after: the same approximation over the merged output | 41,087 | 2,460 | 2,253 | 9,263 | 52,603 |
| T_after: the merged classifier's candidates without the roll test | 41,020 | 2,536 | 2,167 | 9,263 | 52,450 |

- **Provenance.** MEASURED, MSE (`measure_merged.py` → `out/merged-rule.json`). A0 and B0 reproduce CC `coverage/summary.json` in 24 of 24 fields. VCJ reproduced the S_after and B_after totals by re-running the original rule script. VSE independently re-derived the Department part; the chief-of-mission part is not independently reproduced.
- **1900–1905** (13,160 rows; POCOM names one in 9,234). Shown counts are 7,649 / 460 / 7 / 0 both before and after #1292; T_after is 8,466 / 509 / 10 / 0 (MEASURED, MSE).

**Other post-#1292 facts** (MEASURED, MSE unless noted)

| fact | value |
|---|---|
| Rows changing outcome class between B0 and T_after | 2,426: 2,176 legation notes newly classified; 154 under titles only the Python repair read; 68 in legation subchapters nested under a country; 28 legation chapters with foreign datelines, correctly refused |
| Documents still under unread glued titles (a known subset, SE-DOC-VY) | 148 in 1861–1899 scope volumes, plus 9 in 1900–1905 |
| Foreign-legation documents by the title the walk used (S_after) | Legation title 1,969; parent country 2,276 (305 of them a different country); topical 7; none 221; of 4,473. VSE, with its own detector: 1,967 / 2,297 / 7 / 226 of 4,497. |
| Rows under the legation rules (S_after) | 5,015: POCOM names one person in 540; 413 corroborated; 121 contradicted; 1,488 by the Secretary convention; 2,914 roles outside POCOM |
| F. W. Seward class | 117 head-from rows. Shown 68 → 113. The sender pattern matches 106. The sender rule decides 0. W. H. is assigned to 113 of 113 shown. [V-part]: VSE reproduced all but the W. H. assignment. |
| William Hunter, 1865-01-01 to 1866-07-26 | 411 rows. Contradicted 269 → 377; corroborated 0 in every arm [V] |
| Filing-role label reach, rows | 47,734 → 52,616 [V] (VSE: 52,643) |
| Filing-role label rows by own role (S_after) | Department of State 26,254 (9,540 from + 16,714 to); single U.S. mission 13,796; two-way 8,551; foreign legation 3,404; U.S. consulate 542; other 69 (MEASURED, MSE `label_signatures`) |
| POCOM single picks corroborated | Without the roll test, the merged classifier corroborates 41,020 of 45,258 (90.6%, T_after), matching P3's approximation (40,907, 90.4%). What Source Explorer shows, with the roll test, rose from 36,269 (80.1%) to 37,301 (82.4%). The gap is the roll test, not the approximation. Either way, "corroborated" means two rules on the same POCOM register agree. (MEASURED counts, MSE; shares INFERRED) |

**P3's statements**

| statement | changes? | what it now reads |
|---|---|---|
| "It attaches a post to about 9 in 10 of POCOM's single picks." | **Changes in reading** | 9 in 10 holds for the merged classifier's candidates without the roll test (90.6%). What Source Explorer shows, with the roll test, is 82.4% (INFERRED). "Corroborated" means two rules on the same register agree (VSE), which is not identity evidence. |
| "As shipped, without the title repairs, the agreeing count is 36,269." | **Changes** | 37,301 after #1292 |
| The "repaired" counts (40,907 / 2,415 / 2,240 / 8,733) | **Changes in status** | They were a Python approximation. The merged classifier matches it exactly on country chapters (36,792 / 1,893 / 2,079 / 7,062) and differs by 2,426 rows elsewhere. |
| "Seward stays unresolved … at least 117 head rows were signed by F. W. … initials would catch 108." | No | The #1292 sender rule gets direction right but decides none of these rows, because their datelines already say Department of State. |
| "Contradictions cut both ways": topical filing, and POCOM gaps such as William Hunter | No | Hunter contradictions rose from 269 to 377 because more rows are now shown. The label reads "the Department of State" for 193 of 197 head-from rows, consistent with 194 datelines reading Department of State; its correctness is unkeyed. |
| "Consuls, foreign envoys in Washington, chargés and acting officers aren't in POCOM." | No | Legation chapters now receive Notes suggestions (11,930 documents), but 2,914 rows under the legation rules are roles POCOM does not cover. |
| "After 1900 the rule adds almost nothing." | Partly | 1900–1905 is unchanged by #1292. The classifier reads no volume dated after 1905, so Source Explorer and POCOM-chapter features reach 38,953 of 197,534 TEI-267 documents (19.7%; MEASURED, CR). 1906–1909 has neither a Source Explorer classifier nor silver (N15). |
| "Only two pre-1900 volumes carry editor identity links." | No | The crosswalk holds one entry for each, Hamilton Fish (MEASURED, MSI [V]). |
| "The 1873 score is close to circular, 701 of 701." | **Changes in use** | As a filing-role label proxy it scores 649 of 651 on role kind. Place agreement stays near-circular (VSE). |
| "Post-1905 proxy: 98.6% against 93.3%, on about 15% of picks" | **Changes in reading** | The pooled figure is 475 of 482 heads, mostly from 1930–1945 and 1946–. In 1900–1929 it rests on 23 heads where both rules name the same person, and 237 of the 301 such rows in 1930–1945 (79%) rest on POCOM-derived gold (MEASURED, MSI and VSI). |
| "A keyed sample of about 450–500 rows" | Refined | Still the full design. Narrower claims can use tier A (100 rows, licensing its stratum only) or B (about 380) (INFERRED, MSI). |
| "Shared code; more POCOM data (6 of 481); its own table; roughly 3–4 offline sessions" | No | Carried into N13 and §3.11 |
| "Source Explorer shows no suggestion for 23% of 1861–1899 documents." | **Changes** | #1292 reduced it to 14.1% (INFERRED from RF, SE-DOC-AY). Known residual: 148 documents in 1861–1899 scope volumes under glued titles the merged normaliser misses (SE-DOC-VY; a subset, not a census), plus 9 in 1900–1905. |
| (new) | — | The strongest product of the chapter-context work is the filing-role label, not an identity (§3.5). It is a post claim about the named side and needs a keyed sample (N12). |

### 4.4 Errata found while building this delta

1. **FA §6.2 document count.** It says "5,530 orphan mention rows over 2,165 documents". 2,165 is all documents in the three volumes (794 + 912 + 459). The documents holding the orphan rows number 2,089, which is also the sum of FA §4.0's own table (MEASURED, MSI [V]).
2. **FA verdict, markup layer.** FA knew the 88 marked spans were seeds (FA §2.2: "53 exact + 34 title-extended + 1 split of 88 seeds"), but presented presence P 1.000 / 0 false keys as measured quality. Because the annotator, shown those spans, removed none (MEASURED, VSI: 53 kept exactly, 35 boundary-edited, 0 removed), relaxed precision 1.000 follows from that outcome. The figure cannot detect a wrong editor mark and is not an independent precision.
3. **FA §2.2 caveat 3, tie-break.** "No ranking changes" under a different tie-break was tested only on the NLTagger arms. Under a reversed tie-break the agreement arm falls from 0.898 to 0.882 and ranks below the NLTagger-side intersection arm, 0.887 (MEASURED, VAG).
4. **P2's identity price.** The identities line ($160–320 / $410–790) priced a 301,979-row detector union, not the marked correspondent rows (DOCUMENTED, RC [R]).
5. **P3's repaired counts.** P3's "with the chapter-title gaps repaired" counts are a Python approximation, not a classifier run (MEASURED, MSE).
6. **Stale hash record.** `geo-fix/after/source-sha256.txt` records a source hash that matches no commit. The output it describes is byte-identical to a rebuild from HEAD (MEASURED, MSE).
7. **label-validation's 98.6% figure.** Its pooled post-1905 figure is dominated by 1930–1945 and 1946– rows, and most of its 1930–1945 support rests on POCOM-derived gold (MEASURED, VSI).
8. **Scratchpad double count.** Measurement-internal, not in the record: `measure-silver/silver.py` counts each head twice in its concentration tables. Walter Hines Page has 1,678 heads, not 3,356; the 23.6% share is right (MEASURED, VSI).
9. **Scratchpad latency range.** Measurement-internal, not in the record: MOF's summary prose gives per-volume FTS latency through a join as "3–72 ms", but its own `fts-timing.json` records 0.24–0.39 ms for Bliss and 0.25–0.27 ms for Blaine. The range is 0.24–72 ms (MEASURED, MOF `fts-timing.json`).

---

## 5. The recommended first slice under the reframe

**Dependency rule.** A step needs only the steps named in its "needs" column. A step marked independent needs nothing earlier and can start at once. In particular:
- **6(a) depends on steps 2 and 5.** Step 2 fixes the N4 blind protocol, and its strata must exclude the F. W.-initial and convention-narrowed rows that the step 5 checks identify.
- **6(b) depends on steps 2 and 5,** or on a pinned classifier hash, because label evidence expires with each classifier edit and step 5 may change the classifier.
- **6(c) and 6(d) depend on step 2**, which fixes the N4 protocol and the 6(c) seeding choice. After that they can run in parallel with steps 4 and 5.

**Standing rules this slice applies:**
- Screen on the 64 gold documents only, freeze by hash, then run one confirmation on the fresh sample (N3, N5). The fresh sample is never used for iteration.
- Pre-1910 before corpus, with a blind-keyed audit after every pass (FA §5(3), N21).
- A tier licenses only the stratum it was sampled from, and must meet FA §6.4's per-band threshold.
- Spend caps by treatment, set from high scenarios (N2).
- The arm filter comes before or with any recall job, because only the arm filter moves 1930–1945 (§3.9).

| step | what | needs | who and effort | model spend and cap |
|---|---|---|---|---|
| 1 | Reindex to v51 and re-measure population and orphan figures. This delivers 3.1. | independent | owner | None |
| 2 | **Owner decisions.** Wording and provenance for "Correspondent from markup", and for "Filing role" attached to the document. The §5(3) exemption for markup-only carriers. The name-string grain per carrier. The summary-template decision (3.15, N23). The N1 authorization scope, including in-session reads. Spend caps by treatment (N2). Pre-registered thresholds and the matcher tie-break (N5). The N4 blind keying protocol and the 6(c) seeding choice (N3). | independent | owner | None |
| 3 | Write the isolation invariant test (N8) and the store exclusion list (N24) | independent | engineer; not sized | None |
| 4 | **Build.** Correspondents from markup as a per-document list in the Research rail and a per-volume section (3.2, 3.3). The disclosure on the NLTagger People lens (3.4). The citation note and Chronology rows, as printed, with the dateline attached to the document (3.17). | 2, 3 | **Engineer** (INFERRED, RA [R]): 2–3 sessions for the list and section, plus an isolated data layer that is not sized (RA's closest figures are 2–3 sessions parse-time and 3–4 artifact); 0.5–1 for the lens; 1 each for the citation note and Chronology. **Size:** a census-format proxy of 588,607 gzip bytes (MEASURED, MAG); the app-shaped size is not measured. | None |
| 5 | **Deterministic checks.** F. W. initials and signatures; a listing of acting officers and POCOM gaps; a census of chapter-title forms. Share the classifier with a generator (N13). | independent | engineer; part of P3's 3–4 sessions (INFERRED) | None |
| 6(a) | Stage and blind-key identity tier A: 100 rows from the two-signal-agreement stratum, 25 per decade, excluding F. W.-initial, Secretary-convention-narrowed and location-narrowed rows (§3.11) | **2, 5** | engineer stages; owner sitting under N4; time not priced (§2.5) | None |
| 6(b) | Stage and blind-key the filing-role label sample as post claims (N12), stratified by label kind × chapter kind | **2, 5** (or a pinned classifier hash) | as 6(a) | None |
| 6(c) | Stage and key a fresh detection sample of about 250 documents, era-stratified, from the corpus length distribution. Key it unseeded, or seeded with planted wrong spans and disclosed. Lock the key by sha256 before any machine output exists. It is used once, in step 9. | 2 | as 6(a) | None |
| 6(d) | Key the 8 unkeyed M2a documents as a held-out set | 2 | as 6(a) | None |
| 7 | **Screen on the 64 gold documents only.** Run the local controls (a gazetteer-only arm and a local 27–31B verifier). Only with N1 and N2, also run the Claude arm filter and queue verifier: MCJ windows, RC windows and whole documents, 3 replicates. Iterate prompts, windows and thresholds here and nowhere else. | 2 | engineer; Studio time | **Claude, per job, 3 replicates** (INFERRED, MCJ): Opus 5 standard high effort $1.6 central / $10.2 high (queue) and $1.4 / $10.1 (arm filter); Sonnet 5 standard high effort $0.6 / $4.0 for each; Opus 5 batch+cache low effort $0.4 / $2.7 and $0.4 / $2.6. **Whole-document arm:** nearest priced shape S1-c, Sonnet $10.21–10.83 and Opus $25.54–27.08, standard (INFERRED, LP `program-fit/pilot_cost.json`). **With a generous thinking allowance,** up to about $150 (DOCUMENTED, P2). **Cap from the high figures.** |
| 8 | **Freeze by sha256:** prompts, windows, thresholds, matcher tie-break, model ids and local model files, recorded in the N10 manifest | 7 | engineer; owner ratifies | None |
| 9 | **One confirmation run** of the frozen arms, Claude and local, on 6(c), with no further tuning. Score the arm filter per band first, then the recall job. | 6(c), 8 | engineer runs; owner reviews the scores | **Windowed verifier on 250 documents:** not priced. Price it with `cost_model.py`'s two treatments (low / central / high) before the run, and set the cap from the high scenario of the treatment run (N2). **Whole-document arm:** RC R6, S1-c shape (adjudicating a three-way candidate list over whole documents), Sonnet $14.61–15.83 and Opus $36.53–39.59 per run, standard (INFERRED, RC `r6-preannotate.json` [R]). That range is two characters-per-token ends, not a low / central / high triple, and it already includes a 4,000-token-per-request thinking allowance. Replicates multiply it. |
| 10 | Decide the filing-role label (3.5), one label kind at a time, against 6(b), with the chip's meaning settled (N22) | 2, 6(b) | owner floor | None |
| 11 | Decide on the detected-names tier (3.7), with or without a verifier, from 6(c) scores against a per-band floor | 9 with a verifier; 6(c) without | owner | None |
| 12 | **Pre-1910 first.** Pin PRE1910 (85 volumes / 53,894 documents, or 76 / 42,672). Produce the detected tier over that population, running the frozen verifier over it only if step 9 showed a verifier helped. Blind-key a stratified spot sample of the produced layer against the per-band floor (N21). Ship to that population only if the audit passes. Record model id, prompt hash and raw responses (N10). | 11 | owner pins the population and keys the audit; engineer runs | **Verifier pass:** the pre-1910 slice is not priced separately. It is bounded above by the corpus caps in step 13. |
| 13 | **Corpus stages,** only if step 12's audit passes. Extend to the rest of TEI-267 in stages, each followed by an N21 audit. | 12 | owner | Caps by treatment in the table below |
| 14 | **Tier A.** Only if 6(a) passes: ship the "possible officeholder" tier (3.11) for the two-signal-agreement stratum only. Exclude Secretary-convention rows, location-narrowed rows, F. W.-initial rows and all 1861–69 "Seward" rows until tier B passes for those classes. Before shipping, meet FA §6.4: ≥ 0.90 pooled and ≥ 0.80 in every 75-row band. Tier A's 100 rows make one such band for 1861–1899 as a whole; a claim per decade needs about 75 rows per decade rather than 25. A measured Seward-type rate is also required. | 6(a) | owner sittings for further rows and for tiers B and C | None |
| 15 | **Guides prototype** over 10–20 chapters: on-device FoundationModels against Claude, with a claim-level citation audit (3.10) | 4; N1 if Claude is used | engineer; owner reviews the audit | **Not priced** for 10–20 chapters. **Nearest shape:** MCJ's volume guides for the 24 gold volumes at 3 replicates, Opus 5 standard high effort $14.6 / $18.9 / $24.8 (INFERRED, MCJ). |

**Caps for step 13, by treatment** (INFERRED, MCJ [V]; thinking tokens unmeasured). A cap is set from the high scenario of the treatment actually run. RC's narrower windows would roughly halve these, with verifier quality unmeasured (§3.9.1).

| job | Sonnet 5, batch+cache, low effort | Opus 5, batch+cache, low effort | Sonnet 5, standard, high effort | Opus 5, standard, high effort |
|---|---|---|---|---|
| Filter the agreement arm | $129 / $209 / $1,113 | $257 / $495 / $2,865 | $371 / $738 / $4,395 | $780 / $1,790 / $11,250 |
| Verify the priced adjudication queue | $146 / $223 / $1,130 | $292 / $525 / $2,913 | $421 / $785 / $4,310 | $885 / $1,900 / $11,045 |

**Not in the slice:**
- inline highlighting (3.12);
- Claude-adjudicated identities (3.13);
- the carriers that aggregate the Source Explorer classifier (3.18);
- any folding of entries into the person tables (3.16).

---

## 6. Revised owner decisions

1. **Reindex to v51.** This unblocks 3.1 and moves the app view to 263 volumes / 196,447 documents (INFERRED).
2. **Name-string grain, per carrier.** Accept or refuse per-document lists. Cross-document facets and network nodes need a label reading "name string as printed", or a split by filing role (N17). Volume scoping alone still folds the concurrent Sewards.
3. **Wording and provenance.**
   - **Labels to word:** "Correspondent from markup"; "Filing role", attached to the document rather than the name; "Detected name"; "possible identity, from filing context"; "checked by a model"; "model-written summary".
   - **Mechanism:** a ninth `ProvenanceSource`, or disclosure sentences.
   - **Chip:** a measured meaning, or a disclosure, before reusing Likely/Possible (N22).
   - **Seal:** stays tied to an authority id.
4. **The §5(3) exemption.**
   - Grant it for markup-only carriers.
   - Pin PRE1910 for everything else (85 or 76 volumes).
   - Decide whether 1900–1909 is in scope for identity and post claims. By volume-id year that is 15 TEI-267 volumes, 6 of them in 1906–1909 with no Source Explorer classifier (N15).
5. **Hosted-model authorization.** Authorize or refuse sending corpus text: scope, models, route, retention. Say whether in-session reads of corpus text in Claude Code are covered; they already occurred during this assessment. Refusal leaves local models as the only verifier route.
6. **Spend caps** for each phase and treatment, set from high scenarios (N2).
7. **Precision floors** for each feature and band, with the thresholds and the matcher tie-break pre-registered before any model runs (N5, N7).
8. **Keying.**
   - **Order:** identity tier A and the label sample before any review of machine output.
   - **Sizes:** tier A 100 rows (about 75 per band for each per-band claim); tier B about 380; tier C 450–500; the label sample per cell (N12); a 250-document detection sample.
   - **Protocol:** blind (N4), with no model pre-fill of any instrument. The detection sample is keyed unseeded, or seeded with planted errors and disclosed. The 8 unkeyed M2a documents are kept as held-out.
   - **Time:** unmeasured, except FA's ~2–3 h estimate for 300 rows. Record sitting durations (§2.5, N20).
9. **The People browser and the surfaces that inherit person rows.** Decide whether any entry may ever enter the person tables. If yes, FA §4.a's clusterer gate, the synthetic-ref namespace and the rollup bump return. The shared-people axis, the Persons Index exports and the person facets would then change without any new UI (§3.16).
10. **User verdicts.** Keep them device-local, or schedule a CloudKit Production deploy.
11. **Bundle or download tier** for each artifact.
12. **Terms review** before any Claude-derived artifact ships.
13. **Scope of "maximum possible use".** Treat it as a list of separately gated features rather than one program goal.
14. **Summary-template participant fields.** Accept them explicitly, or reword them to names as printed, add a disclosure, and exclude generated names from name search (§3.15, N23).
15. **Window design for any Claude job.** MCJ's ±300-character merged windows, or RC's ±200-character first-occurrence windows. Both are tested in the screen; caps use MCJ's base (§3.9.1).

---

## 7. What stays unsettled, and the risks of "maximum possible use"

### 7.1 Unsettled

| question | status |
|---|---|
| Corpus-scale precision of any detector arm | Unmeasured. Only the 64-document gold exists, with the matcher tie-break affecting it. |
| Filing-role label precision on 1861–1899 no-list rows | Proxies from other populations only, and no keyed sample for any label kind. The U.S.-mission label's proxies conflict: 192 of 193 in 1873 against 0 of 33 printed-office sides in 1900–1905. No proxy is split by chapter kind, so labels inside foreign-legation chapters have no evidence of their own. |
| What the Likely/Possible chip means in precision terms | Unmeasured on any population (N22) |
| Precision of Source Explorer's archival suggestions | Unmeasured (RA) |
| The chief-of-mission part of the chapter-rule counts | Not independently reproduced (VSE) |
| Pre-1900 identity precision | 0 of 300 keyed |
| Verifier specificity; Claude against a local model; either one under MCJ's or RC's windows | Unmeasured |
| How much corpus text the two verifier jobs send together | Not measured |
| Real token counts, thinking tokens, cache hits under batches; the date of the unit prices | Unmeasured; `cost_model.py` records no date |
| Owner keying time | Unmeasured, except FA's ~2–3 h estimate for 300 rows (§2.5) |
| Accuracy of names in the shipped summary templates | Unmeasured; no instrument |
| 1900–1909 | No silver, no Source Explorer after 1905, no proposed stratum |
| Direction accuracy of editor from/to typing | Not measured |
| Duplication inside a markup-only correspondents list | Not measured |
| Figures at index v51 | Not re-run |
| Chapter-title forms the merged normaliser still misses | A known subset only: 148 documents in 1861–1899 scope volumes plus 9 in 1900–1905 |
| How the OH people registry joined FRUS list entries to POCOM | Undocumented, so silver circularity for 1946– is a hypothesis (VSI) |
| App-shaped bundle sizes; iOS FTS latency; render-time anchored-search cost; the `rowid BETWEEN` timing | Unmeasured, or measured once and not reproduced (VOF) |
| Whether a saved custom scope stores the person facet | Not verified (RA) |
| Terms for shipping Claude-derived artifacts; whether the repository is public (bears on leakage) | Not assessed |

### 7.2 Risks of "maximum possible use" as a goal

1. **Corpus before pilot, again, with money.** The sweep already ran all 267 volumes before any precision existed (FA §5). A corpus Claude pass before a held-out confirmation, a pre-1910 pass and its keyed audit would repeat that.
2. **Recall-maximising unions.** The three-way union reaches presence R 0.976 at P 0.491, with 292 false keys over 64 documents (DOCUMENTED, FA §2.2 via RF). Displayed precision would then rest entirely on an unmeasured verifier.
3. **Ceilings stacked into apparent confidence.** POCOM surname × year, the chapter post and the Secretary convention agree mostly because they read the same register. Agreement among them does not separate W. H. from F. W. Seward.
4. **Contaminated instruments.**
   - Pre-filled keys.
   - A detection sample seeded without planted errors.
   - Iterating on the confirmation sample.
   - Scoring on the 64 leaked documents.
   - Rules tuned on published error rows.

   Each turns evaluation into agreement with the machine.
5. **"Machine verified" read as authority.** A chip, "This app's model" wording, or an uncalibrated Likely/Possible chip can present a guess with seal-like confidence.
6. **Model memory as a source.** 18.6% of marked correspondent mentions have no local candidate (DOCUMENTED, P2).
7. **Surface proliferation.** Each new carrier is a new place for wrong names. String-keyed facets and networks fold people without touching `PersonClusterer`, and per-volume nodes fold concurrent namesakes.
8. **Post-hoc overfitting.** Arms, filters, prompts and matcher rules get tuned on 64 documents with 15–18 per band. The tie-break alone moves agreement-arm P by 0.016.
9. **Pressure to fold entries into the People browser.** That re-imports the clusterer gate the isolated carriers avoid. The shared-people axis, the Persons Index exports and the person facets would change silently (§3.16).
10. **Irreproducibility and silent expiry.**
    - NLTagger output is pinned to OS 26.6.2.
    - The sweep is non-deterministic.
    - Claude outputs are non-deterministic and model ids retire.
    - Label evidence expires with classifier edits: #1292 changed the outcome class of 2,426 rows against the approximation (MEASURED, MSE).
11. **Owner-time displacement.** The priced adjudication queue alone is 1,051,899 pairs (grains key), 929,012 of them new at presence grain (MEASURED, VCJ). Reviewing it competes with the keying sittings that gate identity, and keying time is unmeasured.
12. **Cost overrun.** High scenarios run about 5× central on the headline set: $444 against $2,265 on Sonnet 5 batch+cache, and $22,548 at the high scenario on Opus 5 standard high effort (INFERRED, MCJ [V]). Thinking tokens are unmeasured.
13. **Label drift.** A correspondent index called a people index; a filing role read as a named person's post.
14. **Denominator mixing.**
    - **Populations in play:** eleven tags — TEI-267, ERA-REACH, PRE1910, APP-v50, APP-v51, GOLD, SE-ROWS, SE-DOC-VY, SE-DOC-AY, SILVER and SAMPLE-400.
    - **Keys in play:** six — census K2, the grains key, RC's surface key, `k2_surface`, the persons-row key and RC's per-volume from/to key.
    - **A coincidence to avoid:** two unrelated figures both read 85.9% — SE-ROWS documents holding a labelled row (26,498 of 30,864) and the SE-DOC-AY suggestion share (27,884 of 32,478) (VSE).
15. **Silver misread as pre-1900 evidence.** Its 0.96–0.999 agreement rates come from post-1910 heads that name the post, with a single pre-1900 person. The combined 0.972 / 0.939 / 0.863 figure is an agreement rate over registry-covered heads, not a precision. Its errors sit in three namesake pairs, and it is banded by TEI document year: under the volume-id key, 1930–1945 is 0.930 (MEASURED, VSI).
16. **Ungated model memory already ships.** The on-device summary templates can write full names the document does not print, and those names sync and become searchable (§3.15).
17. **Recall work that cannot move the band that matters.** A perfect recall verifier leaves 1930–1945 at P 0.772 on the gold (MEASURED post hoc, RC). Spending on the queue before the arm filter buys recall without reaching the floor.
18. **A confidence chip read as calibrated.** Reusing Source Explorer's Likely/Possible chip for filing roles implies a precision scale nobody has measured (N22).
19. **Archival pointers at scale.** Posts axes, analytics and dashboard cards built from the classifier would present its unmeasured suggestion precision as counts, and the trip packet could send a researcher to the wrong reel (§3.17–3.18).
