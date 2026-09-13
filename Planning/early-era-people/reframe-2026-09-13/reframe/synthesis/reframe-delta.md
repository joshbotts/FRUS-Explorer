# #234 reframed: assessment delta

Date: 2026-09-13.

**The reframe.** #234 was "extend the People browser, person search, person analytics and the co-mention graph to the FRUS volumes whose editors published no persons list". The proposed reframe is "make maximum possible use of the Qwen harvest, NLTagger, POCOM, Source Explorer, and Claude verification/synthesis to develop features for untagged people".

**What this file does.** It states how the reframe changes three assessments:
1. the feasibility assessment merged in PR #1290;
2. the in-session answer on a Sonnet or Opus pass;
3. the in-session answer on Source Explorer chapter context.

No LLM API was called and no corpus text left the machine to produce it.

## 0. Reading rules

**Labels.**
- MEASURED: computed by the script named beside it.
- DOCUMENTED: read in the file named beside it.
- INFERRED: arithmetic or judgement on other figures.

A ceiling is never a precision.

**Verification tags**, appended in square brackets:
- **[V]** An independent verification script reproduced the figure.
- **[V-corr]** The verification disagreed. The corrected figure is used, and the original is named where it matters.
- **[V-part]** Only part was reproduced. The unreproduced part is named.
- **[R]** Reported by one of the three reader agents. The evidence contains no verification block for the readers, so the figure carries only its own label. Where I opened the output file myself, the tag reads [R, file read].

**Populations.** Figures from different rows of this table are never combined into one figure.

| tag | population |
|---|---|
| TEI-267 | TEI-rule store scope: 267 volumes / 197,534 documents (`~/frus-ner-raw/scope.json`) |
| APP-v50 | App view in the live index at version 50: 267 volumes with no `persons` rows / 198,936 documents |
| APP-v51 | App view after the owner's v51 reindex: 263 volumes / 196,447 documents (INFERRED, RF `post1291_population.json` [R, file read]) |
| GOLD | M2a gold: 64 keyed documents / 406 mentions / 288 presence keys. The arms scored on it were chosen after the scores existed. |
| SE-ROWS | Editor-marked from/to rows in no-list volumes, banded by volume-id year. 1861–1899: 61 volumes, 84,234 rows, 30,864 documents holding rows. 1900–1905: 9 volumes, 13,160 rows, 5,314 documents; this band is this program's own cut, not one of the assessment's bands. |
| SE-DOC-VY | Live-index export documents in those 70 volumes, banded by volume-id year: 32,809 (1861–1899) / 6,222 (1900–1905) |
| SE-DOC-AY | The live-index export of 46,837 pre-1906 documents, 1861–1899 by app year: 32,478 documents |
| SILVER | From/to document heads carrying an editor link that reaches a POCOM slug through the person-authority crosswalk. Drawn from the 286 persName-list volumes plus the 3 split-set second parts, banded by TEI document year. Under that key the "1900–1929" silver band holds only documents dated 1910–1919 (MEASURED, VSI). |
| SAMPLE-400 | 400 documents, 100 per band, drawn from TEI-267. Equal allocation, not population-weighted. |

Bands are 1861–1899 / 1900–1929 / 1930–1945 / 1946–. They follow the volume-id year unless a row says otherwise.

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

**Dollar figures.**
- **All are INFERRED.** They are estimated from character counts, so token counts can be off by up to about ±40% (MCJ caveat).
- **Unit prices** come from `llm-pass/cost-scale/cost_model.py`, in $/MTok input/output: Haiku 4.5 1/5, Sonnet 5 2/10, Opus 5 5/25. Batch pricing is ×0.5 and a cache read is ×0.1.
- **Price provenance.** `cost_model.py` records no pricing date and no source. Its prices match the claude-api skill model table cached 2026-06-24 (DOCUMENTED, VCJ).
- **Triples** read low / central / high scenario.
- **Treatments.** "Batch+cache, low effort" and "standard, high effort" are `cost_model.py`'s two treatments. Its thinking tokens and cache hit rates are assumptions, not measurements.

**Code citations** are at the worktree HEAD. Its content is identical to `origin/v2` 6aad5a9f (the reader recorded f63e253e), and it includes #1291 and #1292.

---

## 1. The verdict

The reframe does not change what the evidence shows, but it changes what decides feasibility. In the assessment every shape wrote rows into `persons` / `person_mentions`, so the shipped `PersonClusterer`, whose only row source is `SELECT … FROM persons` (`IndexingPipeline.swift:1175`; DOCUMENTED, RF [R]), decided feasibility. Features kept outside those tables — a per-document list, a Source Explorer line, a correspondence view, a verification queue — never reach it, so the clusterer gate becomes an isolation invariant, and three other things decide instead: a precision floor for each feature at the grain it displays, a blind-keyed identity sample for any claim about who a correspondent was or what post they held, and any verifier measured on documents it has not seen. The assessment's two narrow findings stand. Editor markup yields a correspondent index, not a people index: 97.8% of the 159,182 documents it reaches carry only from/to header names (MEASURED, FA §2.1, TEI-267). Identity is not shippable: 0 of 300 evaluation rows are keyed (MEASURED, VCJ), and post-1910 silver cannot stand in for pre-1900, where the silver set is one person on 459 heads (MEASURED, MSI [V]). One assessment figure changes status: the markup layer's zero wrong names on the gold holds by construction, because the gold was seeded with the same 88 editor spans and the annotator removed none (MEASURED, VSI). The Claude-pass answer changes most. Claude's defensible roles shrink from re-reading or judging the corpus to checking candidates the free layers already produced. Filtering the agreement arm costs $129 / $209 / $1,113 and verifying the disagreement queue $146 / $223 / $1,130 on Sonnet 5 batch+cache, low effort (INFERRED, MCJ [V]). Cost therefore stops binding, and four other things bind instead: authorization to send text off the machine; a held-out instrument, because 63 of the 64 gold documents are named in committed evidence (MEASURED, RF [R, file read]); blind keying; and a local-model control arm. The Source Explorer answer changes in reach and in its best use. After #1292 the share of 1861–1899 documents with an archival suggestion rose from 76.9% to 85.9% (MEASURED, RF [R, file read], SE-DOC-AY). The defensible product is a filing-role label that asserts no identity; it reaches 52,616 of 84,234 correspondent rows (62.5%; MEASURED, MSE [V], SE-ROWS) and has no precision measured on its target population. Source Explorer's identity contribution is unchanged: the new sender rule decides 0 of the 117 head rows first-signed by F. W. Seward; "corroboration" compares POCOM with POCOM; and a pre-1900 identity precision still needs a blind-keyed, stratified sample.

---

## 2. Gates and decisions under the reframe

### 2.1 The assessment's §5 gates

| # | gate (FA §5) | status in FA | effect | why | status 2026-09-13 |
|---|---|---|---|---|---|
| 1 | (1) Evaluation set first | Met for detection; not met for identity | **tightens** | "Met for detection" covers only the existing detectors. 63 of 64 gold documents are named in 15 committed files, and the four error listings hold 1,480 bracketed context snippets (MEASURED, RF `gold_leakage.json` [R, file read]). The M2a audits used LLM adjudicators (DOCUMENTED, FA §1.4). The marked layer equals the seeded spans in 64 of 64 documents, with 0 removed (MEASURED, VSI `v-m2a-seeds.json`). A Claude arm needs a fresh set. | Detection: a screen only. Identity: not met. |
| 2 | (2) Out of interactive scope | Binding | **unchanged** | Claude fits only as a scripted batch job. A Claude Code subagent carries a fixed seat of 44,661–70,602 tokens (INFERRED, LP `cost-scale/side.json`). Design-time reading of error rows is already practised, so it needs a stated exception. | Binding |
| 3 | (3) Pilot before corpus, pre-1910 first | Binding; bypassed once by the sweep | **tightens** | The markup exemption rests on "editor markup asserts no identity", which holds only for carriers that show markup and nothing else. Filing-role labels, POCOM candidates and Claude verdicts each need a held-out pilot of their own. A corpus-scale Claude pass before a pilot would repeat the sweep's bypass, this time with money. The pre-1910 population is still unpinned: 85 volumes / 53,894 documents by manifest earliest year, or 76 / 42,672 by volume-id year (DOCUMENTED, FA §5). | Pin still owed |
| 4 | (4) Synthetic-ref namespace / force-merge-only / index-bump batching | Undefined anywhere | **relaxes** | A namespace collision exists only when derived rows share `persons`' key (volume_id, ref); a separate table removes it. Two things remain: stable deterministic ids, if saved searches or user verdicts anchor to entries, and bump batching for any parse-time change. | Returns in full if any entry is proposed for the People browser |
| 5 | (5) A confidently wrong person is the worst defect | Violated by default under the shipped clusterer | **tightens** | The constraint binds every person claim; only its named mechanism was the clusterer. The reframe adds mechanisms the clusterer gate does not close. (a) POCOM plus filing context: POCOM's chapter rule still assigns W. H. Seward to all 113 of the 113 rows first-signed by F. W. Seward that Source Explorer now shows (MEASURED, MSE [V]). (b) Facets and networks keyed by name string. (c) Model memory: 18.6% of marked correspondent mentions have no candidate in any local source (DOCUMENTED, P2). Each carrier needs its own refusal rule. | Binding |
| 6 | M2a keyed | 64 of 72 keyed; keying the other 8 optional, as a held-out set | **tightens** | The 8 unkeyed documents (3 / 3 / 2 in the three later bands; MEASURED, FA §0) are the only staged documents with no committed residues. They are too few to score a verifier, so they should be spent only as a held-out check. | Protect them from prompt design and pre-fill |
| 7 | N-1 scored | Done | **unchanged** | A record of the detector comparison; it does not depend on the carrier. | Done |
| 8 | N-2 detector choice and build plan | Decision owed | **relaxes** | "Presence, not offsets" was read from the People surfaces' code. It reopens per carrier: presence for lists and facets, offsets for inline highlighting and for context windows sent to a verifier. | Owed, per carrier |
| 9 | N-3 / W-7a more models | Dormant | **tightens** | A Claude judge is a third model, so the gate is active again. It brings authorization, a spend cap, a held-out score, output pinning and a terms review. A local 27–31B arm should run on identical inputs first. That such models are loaded on the Studio is DOCUMENTED in P2 and was not checked from this machine. | Active |
| 10 | 300-row identity evaluation | 0 of 300 keyed | **tightens** | Any claim about who someone was, what post they held, or a career link needs it. It must be keyed blind, because pre-filled rows measure agreement with whatever filled them. It holds only 16 several-candidate rows, 12 of them pre-1910 (DOCUMENTED, LP `identity/gate.json`); with zero errors at n = 12 the lower bound is 0.7575 (MEASURED, MSI [V]). Source Explorer and POCOM claims need a sample stratified by rule outcome (§3.11). 1900–1909 falls into no proposed stratum (MEASURED, VSI). | 0 of 300 keyed (MEASURED, VCJ) |
| 11 | M1b / R-4 derived rows reach the app | Not started | **relaxes** | Its dependence on gates (4) and (5) existed only because derived rows meant `persons` rows. A separate table or bundled artifact needs `xcodegen` for a new resource and its own re-apply hook. "No CloudKit deploy" becomes conditional: synced user accept/reject verdicts trigger the R-7 schema-deploy gate (DOCUMENTED, CLAUDE.md). | Not started |
| 12 | M3 provenance | Not started | **tightens** | `ProvenanceSource` is pinned at 8 labels (`ProvenanceChipTests.swift:51`; DOCUMENTED, RF and RA [R]). None fits a hosted-model verdict or an offline Qwen or NLTagger harvest, and `.appModel` reads "This app's model". None fits a rule-derived identity guess either: `.ohPeopleRegister`'s method sentence describes a join (DOCUMENTED, RA [R]). | Owner wording owed |
| 13 | R-2 mention-context vectors | Not started | **unchanged** | Needed only for identity clustering. A Claude identity judge could substitute, but neither is scored. | Not started |
| 14 | R-3 identity clustering plus adversarial tier | Not started; gated on owner | **tightens** | The adversarial tier is now a concrete hosted model, so it adds authorization, a spend cap, blind keying and a held-out score. "Rules written" becomes a refusal rule for each carrier. | Not started |
| 15 | §4.0 cross-part `corresp` defect | Measured in the live index | **dissolves** | Fixed in code by #1291 (index v51; DOCUMENTED, RF [R]). The live index is still at v50 on all 316,839 revision rows, with 0 `persons` rows in the four affected volumes (MEASURED, RF [R]; VSI). | Owner reindex owed |
| 16 | Precision floor for any detected layer | Unset | **tightens** | One floor becomes one per feature, per band and per verifier output. The gold precision also depends on the matcher: the agreement arm reads 0.898 (25 false keys) under the scorer's tie-break and 0.882 (29 false keys) under an equally valid maximum matching (MEASURED, VAG). The 1930–1945 cell is 15 documents. | Unset |
| 17 | On-screen wording | Unset | **tightens** | New claim types need owner wording: a filing role, a possible officeholder from filing context, a name checked by a model, a model-written guide. The "Reconciled identity" seal stays gated on an authority id (`PersonIndexView.swift:654–664`; DOCUMENTED, RA [R]). | Unset |
| 18 | Bundle-size decision for (b) | Open | **unchanged** | The agreement arm is now measured at 9,346,130 bytes, 2,926,099 with gzip -9, in the census format (MEASURED, MAG [V]). A sweep that only feeds a queue never ships, which removes the ~7.2 MB option. Claude-derived artifacts would add sizes nobody has measured. | Open |
| 19 | OS-build pin and filter promotion | Not started | **unchanged** | Any shipped NLTagger derivative is a property of OS 26.6.2 (25G83) (DOCUMENTED, FA §1.1). A verifier adds its own pin: model id, prompt hash and parameters. | Not started |
| 20 | Corpus-scale census of the agreement arm | Not measured | **unchanged** | Still needed by any carrier that uses the arm; now done. | **Met:** 768,928 (document, K2) pairs, 190,658 documents (96.5%), 157,028 keys, TEI-267 (MEASURED, MAG [V]) |
| 21 | Identity-grain / string-equality re-score | String equality done; last-token proxy grain not scored | **tightens** | In a per-document list the last-token collapse is what the reader actually sees. At corpus scale a within-document last-token collapse removes 19.2% of the arm's added pairs, 32.3% in 1861–1899 (MEASURED, VAG). That collapse is a proxy in both directions: it also merges namesakes. | The gold's last-token P/R is still unscored |
| 22 | On-device rollup consolidation time | Recorded nowhere | **dissolves** | It exists only if derived rows multiply `persons`. Isolated carriers leave the rollup at its editor population: 62,931 `persons` rows at v50 (MEASURED, RF [R]). | Returns if entries are folded into the People browser |
| 23 | Errata in the record | Open | **unchanged** | The record's accuracy does not depend on the carrier. §4.4 adds new errata. | Open |

### 2.2 The assessment's §6.3 owner decisions

| # | decision (FA §6.3) | effect | why |
|---|---|---|---|
| 1 | "Offsets vs presence is settled: presence." The real decision is the name-string grain. | **relaxes, and is re-posed per carrier** | A per-document list asserts nothing beyond its document, so it avoids the "two seward entries" question. A facet or network node that spans documents folds people by string: 'johnson' (10,761 filtered-sweep pairs) and 'wilson' (10,010) each fold several people (MEASURED, FA §2.1). Offsets are no longer settled: inline highlighting needs them, and a mapping has now been measured (§3.12). |
| 2 | Whether "correspondents from FRUS markup" counts as extending the People browser | **dissolves** | The reframe does not need it to count. The part that survives, that it must be labelled a correspondent index, moves into decision 6. |
| 3 | Ratify the derived-entry rollup rule as a code change, plus the synthetic-ref namespace | **relaxes** | For carriers outside `persons`, `person_mentions`, `person_rollup_member`, the authority crosswalk and `PersonClusterOverride`, it becomes an isolation invariant test. It returns in full if any entry is proposed for the People browser. |
| 4 | Grant or refuse the §5(3) exemption for editor markup | **tightens in scope** | The exemption's argument covers carriers that show markup only. Every other feature needs a pinned pre-1910 population and a held-out pilot. |
| 5 | Set the per-band precision floor | **tightens** | It becomes per feature × band × verifier. On the gold's three-way candidate pool, a verifier must reject at least 89.0% of false keys to reach presence P 0.898, or at least 92.7% for at most one false name per 3 documents (INFERRED, RF from FA §2.2). |
| 6 | Approve the wording | **tightens** | It gains new claim types, and needs either a ninth provenance source or a disclosure sentence per claim type. The seal stays tied to an authority id. |
| 7 | The bundle question for (b) | **unchanged** | It still applies to whatever ships. |
| 8 | Key the 300 rows before any POCOM-anchored identity | **tightens** | Keying must be blind and stratified by rule outcome, with no model pre-fill, and the sample must be sized to the claim (§3.11). |
| 9 | Optionally key the 8 unkeyed M2a documents as a held-out set | **tightens** | No longer optional in practice. They must also be kept out of any prompt or threshold design. |

### 2.3 The assessment's §6.4 triggers

| trigger (FA §6.4) | effect | why |
|---|---|---|
| Detected layer: a fresh ≥ 100-document sample; agreement-arm lower bound ≥ 0.85 and ≤ 1 false name per 3 documents in every band | **tightens** | The same sample must also score any Claude arm, so it must be staged and keyed before any model sees it. About 250 documents are needed for a verifier gain to register (DOCUMENTED, P2). The matcher tie-break must be fixed in advance (VAG). |
| Identity: 300 keyed rows, ≥ 0.90 pooled and ≥ 0.80 per band, a synthetic-namespace merge test, a measured Seward-type rate | **tightens** | The thresholds now apply to each identity-bearing rule the reframe adds. The namespace test becomes the isolation test. |
| (a) becomes unacceptable if the clusterer gate breaks editor rollups | **dissolves** | The clusterer cannot reach isolated carriers. |
| The sweep matters for presence only with an inline-linking surface | **relaxes** | "Maximum possible use" proposes exactly such surfaces, and a verification queue also makes the sweep matter, through recall. Its direct-display precision is unchanged. |

### 2.4 New gates

| # | gate | why | owner | what unblocks it |
|---|---|---|---|---|
| N1 | Authorization to send corpus text to a hosted model | Every Claude step sends FRUS text off the machine. No API-use policy exists in `Planning/*.md` (DOCUMENTED, RF [R]). Windowed verification alone sends 21–33% of corpus characters (MEASURED, RC [R], TEI-267). | owner | A written scope: public-domain corpus text only, never user notes or synced content. It names the models, the route (scripted Message Batches) and retention. |
| N2 | Spend cap per phase, with a hard stop in the batch driver | High scenarios sit far above central. The headline job set (agreement-arm filter, queue, identity adjudication, per-volume guides) costs $284 / $444 / $2,265 on Sonnet 5 batch+cache, low effort, and $1,757 / $3,829 / $22,548 on Opus 5 standard, high effort (INFERRED, MCJ [V]). Thinking tokens are unmeasured. | owner | Caps for the pilot, the confirmation run and any corpus pass. |
| N3 | An uncontaminated held-out set | Gate 1 above. | engineer stages, owner keys | A fresh, era-stratified sample of about 250 documents drawn from the corpus length distribution. The 8 unkeyed M2a documents are held out as well. |
| N4 | A blind keying protocol | The M2a seeding precedent cannot size anchoring: no wrong seed was planted, and all 35 "rejected" seeds were boundary edits (MEASURED, MSI [V]). | owner | Lock the blind column with a sha256 before revealing any machine candidate, and score every arm against the blind column only. If rows are pre-filled for speed, randomise them into halves and plant wrong candidates in one half. With 0 plants accepted of 30, the Wilson upper bound is 11.35% (exact one-sided: 9.5%); with 0 of 50 it is 7.14% (5.8%) (MEASURED arithmetic, MSI / VSI). |
| N5 | Pre-registered thresholds, including the matcher rule | Arms were already chosen after scores existed (FA §0), and the tie-break alone moves agreement-arm P from 0.898 to 0.882 (MEASURED, VAG). | engineer drafts, owner ratifies | Commit the thresholds per band, the matcher tie-break and a rerun-stability check before the first model call. |
| N6 | A provenance source and wording for hosted-model and rule-derived claims | Gate 12 above. | owner and engineer | Either a ninth `ProvenanceSource` or a disclosure sentence; update the pinned tests. |
| N7 | Per-feature precision floors at the display grain | A per-document list, a cross-document facet, a network edge, a role label, an identity candidate and a written sentence each fail differently. | owner | A floor per feature per band, each measured at its own grain on held-out documents. |
| N8 | An isolation invariant test | Nothing today stops a derived writer from touching the person tables. | engineer, owner ratifies | A test that no derived-data writer touches `persons`, `person_mentions`, `person_rollup_member`, the authority crosswalk or `PersonClusterOverride`. |
| N9 | A grounding rule for written synthesis | Gate 5(c) above. | owner and engineer | Every sentence cites a document id, a POCOM slug or a NAID, checked by a claim-level citation audit on a stratified sample. |
| N10 | Model-output pinning | Hosted outputs are non-deterministic and model ids retire. | engineer | A manifest of model id, prompt hash, parameters and raw responses, plus a rule for what happens when the model is retired. |
| N11 | A terms review for Claude-derived artifacts | A licence gate exists for Gemma-derived vectors; none exists for Claude output. The terms themselves were not assessed (DOCUMENTED, RF [R]). | owner | A compliance note before any model-derived artifact enters the bundle. |
| N12 | A keyed filing-role label sample | No label precision exists on the target population. The commonest label, the U.S. mission, has positive evidence only from the 1873 volume pair (192 of 193), and it is right on 0 of 33 printed-office sides in 1900–1905 (MEASURED, MSE; 0 of 49 under VSE's parser). | engineer stages, owner keys | A blind sample stratified by label kind and chapter kind (country, foreign legation, topical, U.S. mission). Zero errors at n = 100 gives a lower bound of 0.963 (MEASURED, MSI [V]). |
| N13 | Source Explorer post evidence ready for a generator | The re-measurement on the merged code is done (MSE). Still open: the classifier lives only in the app; bundled POCOM careers cover 6 of the 481 people who held a chief-of-mission or principal post in 1861–1905 (DOCUMENTED, P3); and 148 + 9 documents are known to sit under glued chapter titles the merged normaliser still misses, a subset, not a census (MEASURED, MSE). | engineer | Shared classifier code, an expanded POCOM artifact, and a census of title forms. |
| N14 | A local-model control arm | Whether Claude beats a free local model is unmeasured (RC). | engineer | A gazetteer-only arm and a local 27–31B arm run on identical inputs before any API run. |
| N15 | A decision on 1900–1909 | The decade has no silver and, from 1906, no Source Explorer classifier. It holds 12,405 untagged heads in 20 volumes, 68.0% of them beginning with an honorific (MEASURED, VSI). | owner | Include the decade as its own stratum or exclude it from identity claims. |
| N16 | Gates for offset-bearing surfaces | 6.8% of detected spans sit in footnotes, which have no body offset; 4.3–4.9% are refused by the anchor mapping; highlights go stale when `renderingVersion` changes (MEASURED, VOF, SAMPLE-400; DOCUMENTED, MOF). | engineer and owner | A mention-grain floor, a treatment for footnote names, and a staleness rule. |
| N17 | An aggregation rule for facets and networks | Grouping by name string folds people without ever touching `PersonClusterer`. | owner | Volume-scoped buckets and nodes, or an explicit "name string, not person" disclosure. |
| N18 | The CloudKit gate for synced verdicts | Accept/reject verdicts stored in a `@Model` or a new stored property change the schema (DOCUMENTED, CLAUDE.md). | owner | The R-7 deploy, or verdicts kept device-local. |
| N19 | The v51 reindex before any live-index measurement or person-table feature | Gate 15 above. | owner | The reindex, then a re-measure of the population and orphan figures. |
| N20 | A budget for owner review time | Review queues compete with identity keying for the same sittings. The Claude verification queue alone is 1,051,899 (document, key) pairs, of which 929,012 are new at presence grain (MEASURED, VCJ, TEI-267). | owner | Schedule identity keying ahead of any review of machine output. |

---

## 3. Feature candidates, ranked by value against risk

**Verdict terms.**
- **Buildable now:** no measurement is owed. Owner wording or scope decisions may still be.
- **Conditional:** it can be built once a named measurement or decision exists.
- **Not yet:** it needs an instrument that does not exist.

### 3.0 Ranking

| rank | candidate | signals | identity asserted | verdict |
|---|---|---|---|---|
| 1 | Editor identities in the four #1291 volumes | editor markup, crosswalk, POCOM (shipped) | yes, by the editors | **buildable now** (built; needs the owner's reindex) |
| 2 | Correspondents index from markup | editor markup | no | **buildable now**, after two owner decisions |
| 3 | Per-document names list | editor markup; later detectors; FTS | no | **buildable now** for markup; conditional for detected names |
| 4 | Disclosure on the shipped NLTagger People lens | NLTagger (on device) | no | **buildable now** |
| 5 | Filing-role label from Source Explorer | Source Explorer, editor markup | no (a role, not a person) | **conditional** on a keyed label sample |
| 6 | Correspondence network labelled as such | editor markup | no, if nodes stay per volume | **conditional**; cross-volume nodes not yet |
| 7 | Detected-names tier at the agreement arm | editor markup, NLTagger, Qwen sweep | no | **conditional** on a floor and a held-out score |
| 8 | Search facet by name | any shipped vocabulary; FTS | implicitly, by string folding | **conditional** on an aggregation rule |
| 9 | Claude-verified names | detectors, Claude, local model | no | **not yet** (pilot conditional on authorization) |
| 10 | Claude-written correspondents guides | markup, POCOM, Source Explorer, Claude or on-device model | not required, but invited | **not yet** |
| 11 | POCOM "possible officeholder" tier with filing context | markup, POCOM, Source Explorer, deterministic checks | yes, hedged | **not yet** |
| 12 | Inline highlighting of unmarked names | detectors, offset mapping | no, but marks text as a person | **not yet** |
| 13 | Claude-adjudicated identities | markup, POCOM, Source Explorer, Claude | yes | **not yet** |
| 14 | Identity tier | all | yes | **not yet** (unchanged) |

### 3.1 Editor identities in the four #1291 volumes

| | |
|---|---|
| Signals | Editor markup: `corresp` links into the sibling part's list in the three split sets, and `frus1873p1v2`'s own list. The person-authority crosswalk and the shipped POCOM career section. |
| Grain | The existing `persons` / `person_mentions` / rollup rows |
| Identity asserted | Yes, by the editors. No machine step is involved. |
| Quality | Editor assertions. In the three split parts, 122 of 634 distinct link targets carry a crosswalk id and 52 carry a POCOM slug (MEASURED, MSI [V]). |
| Reach | 5,530 orphan mention rows over 2,089 documents in the split parts, plus 454 rows (37 refs) in `frus1873p1v2` (MEASURED, MSI [V]; FA §4.0). 985 from/to heads carry a POCOM slug (MEASURED, MSI [V]). The app view goes from 267 / 198,936 to 263 / 196,447 (INFERRED, RF [R, file read]). |
| Cost | None further; PR #1291 is merged (DOCUMENTED, RF [R]). |
| Gates | The owner's v51 reindex. After it, any feature driven from the NER stores must exclude or label `frus1932v04`, `frus1918Supp01v02` and `frus1917Supp02v02`: they are inside TEI-267 and now carry editor identities. |
| Verdict | **Buildable now.** It restores shipped behaviour rather than adding a new feature. |

### 3.2 Correspondents index from markup

| | |
|---|---|
| Signals | Editor markup only (typed `persName` from/to). The label in 3.5 can be added later. |
| Grain | Per document ("who wrote to whom"), and a per-volume list of name strings with no cross-volume merge |
| Identity asserted | No |
| Quality | On the gold, presence P is 1.000 (0 false name keys of 79) and R 0.274 (MEASURED, FA §2.2; GOLD, post hoc). **The zero holds by construction:** the marked layer equals the spans seeded into the gold in 64 of 64 documents, none was removed, and strict precision equals the share kept exactly, 53 of 88 (MEASURED, VSI). Two display defects remain. 83.1% of marked mention rows are a surname alone (MEASURED, FA §2.1). 46 of 288 gold keys are a token-suffix of another key in the same document, so an uncollapsed list shows "Seward" beside "William H. Seward" (MEASURED, FA §2.2). |
| Reach (TEI-267) | 159,182 documents (80.6%), 97.8% of them header-only; 223,505 (document, K2) pairs; 11,377 distinct keys; about 30,327 per-volume entries (MEASURED, FA §2.1; pairs reproduced in the MAG controls [V]) |
| Cost | No model or API cost. The artifact is 2,632,099 bytes, 588,607 with gzip -9 (MEASURED, MAG [V]). Engineering, INFERRED from RA [R]: about 1 session for a volume-page section, 1–2 for a Research-rail accordion, 0.5–1 for provenance wiring. Staying outside `persons` drops FA §4.a's clusterer gate, synthetic-ref namespace, `person_mentions` re-apply hook, source column, analytics distinct-count fix and the rollup bump. |
| Gates | N8 isolation test; owner wording ("Correspondent from markup") with the `.frusText` chip; the §5(3) exemption; the v51 reindex; stable ids if any user state anchors to entries |
| Verdict | **Buildable now**, once the owner decides the wording and the exemption |

### 3.3 Per-document names list

| | |
|---|---|
| Signals | Editor markup now. Detected names later, from 3.7. FTS for confirming a name at runtime. |
| Grain | (document, name string) |
| Identity asserted | No |
| Quality | Markup names as in 3.2; detected names as in 3.7. **Presence needs no offsets:** `document_cache.body_text` equals the HTML-unescaped R-0 text in 400 of 400 documents in each of two independent samples (MEASURED, MOF and VOF, SAMPLE-400). Every detected span therefore has an exact `body_text` offset (5,188 of 5,188 sweep spans and 2,694 of 2,694 NLTagger spans in the first sample; MEASURED [V]). FTS confirms a known name in its document in 0.10 ms (sweep surfaces) or 0.015 ms (NLTagger surfaces) at the median (MEASURED, MOF [V]; Mac, Python sqlite3 3.51.0, not iOS). It cannot discover names, so a list still needs a shipped name vocabulary. |
| Reach | As 3.2 for markup |
| Cost | About 1 session on top of 3.2 (INFERRED, RA [R]) |
| Gates | As 3.2 for markup; as 3.7 for detected names |
| Verdict | **Buildable now** for markup. **Conditional** for detected names. |

### 3.4 Disclosure on the shipped NLTagger People lens

| | |
|---|---|
| Signals | NLTagger, running live on the device |
| Grain | Name-string counts per scope; no document, no offset |
| Identity asserted | No |
| Quality | Not measured for this lens. It runs Apple's `.personalName` tag over `document_cache.body_text` for any scope, untagged volumes included, and keeps Title-cased strings (DOCUMENTED, RA [R]: `WordCloudTokenizer.swift:157–185`). The filtered NLTagger store's top corpus strings include 'john' (3,943) and 'chiang kai' (2,454) (MEASURED, FA §2.1). |
| Reach | Any scope a reader selects. This is the one untagged-people surface that already ships. |
| Cost | 0.5–1 session for wording and an export caveat (INFERRED, RA [R]). The program's frozen filter must stay out of the shared stopword payload, whose SHA-256 the keyness baseline pins (DOCUMENTED, CLAUDE.md). |
| Gates | Owner wording saying that a statistical name recogniser did the reading |
| Verdict | **Buildable now** |

### 3.5 Filing-role label from Source Explorer

| | |
|---|---|
| Signals | The Source Explorer classifier (header, dateline, chapter path) applied to editor-marked from/to rows. No POCOM. |
| Grain | (document, side), labelled "the U.S. mission in C", "the Department of State", "the C legation in Washington", or two-way |
| Identity asserted | No. It names a role in the Department's filing system. |
| Quality | **No keyed sample exists on the target population.** Four proxies, each from a different population, are in the table below the card. |
| Reach (SE-ROWS, post-#1292, as shown) | 1861–1899: 52,616 of 84,234 rows (62.5%; 86.2% of 61,068 head rows) and 26,498 of 30,864 documents holding rows (85.9%). Before #1292: 47,734 rows and 24,031 documents (MEASURED, MSE; VSE got 52,643 / 26,512 with an independent head-grain method). 1900–1905: 8,370 of 13,160 rows, unchanged by #1292. The commonest own role is "from a U.S. mission", 13,796 rows (MEASURED, MSE). Enclosure rows (23,128 of 84,234) are refused by design. |
| Cost | No API cost. 1–2 sessions for a line in both Source Explorer twin views, or the label can be computed live in the Research rail with no reindex. Corpus-wide aggregation needs index-time persistence and a reindex (INFERRED, RA [R]). |
| Gates | N12 keyed sample. Owner wording, reusing the existing Likely/Possible chip. Refusal rules for enclosures, non-country titles and foreign-government papers. The label's evidence expires with each classifier edit. Twin-view drift. |
| Verdict | **Conditional.** Proxy evidence is strongest for Department-side labels, and for U.S.-mission labels, the commonest kind, it exists only in 1873 (INFERRED). |

The four precision proxies for 3.5:

| proxy | population | result | what it can show |
|---|---|---|---|
| 1873 editor lists | `frus1873p1v1`+`v2` head rows, 31 distinct list entries | 649 of 651 right (99.7%). Non-Department evidence: 240 of 242. | Role kind (direction). Country agreement is near-circular, because the list heading and the chapter title share the volume's arrangement (VSE). |
| Printed offices, 1900–1905 | Document sides printing an office; 1,285 of 6,222 documents (SE-DOC-VY) | 1,182 of 1,288 (91.8%): Department 1,002 of 1,047, U.S. mission 0 of 33 | Mostly a Department figure (81% of judged sides) |
| Printed offices, 1861–1899 | 703 of 32,809 documents (2.1%), mostly foreign-government and presidential papers | 66 of 250 (26.4%) | Exposes the failure class; not representative |
| Post-1905 list volumes | 33 volumes, 1914–1952; classifier run outside its era | 2,355 of 2,896 (81.3%) | Outside the classifier's design era |

All MEASURED, MSE. VSE reproduced direction and scale with its own parsers (U.S. mission 0 of 49).

**Known failure classes** (MEASURED, MSE [V]):
- **Datelined-abroad fallback.** 2,796 of the 27,387 documents shown for 1861–1899 (10.2%) rest on the medium-confidence "datelined abroad" rule. In 592 of them the addressee is not a Secretary or the Department, for example a note from Earl Russell to Lord Lyons labelled a U.S. despatch; the heuristic behind that count gives an upper bound.
- **Legation rules not applied.** 2,276 of 4,473 foreign-legation documents are walked up to a parent country title, so the legation rules never run for them (VSE: 2,297 of 4,497 with its own detector).
- **Unshown categories.** The label draws categories from the chosen title's candidates, which include a category Source Explorer does not show in 604 of 27,387 documents (MEASURED, VSE).

**Where identity fails, the role still holds.** For William Hunter's 411 rows in POCOM's 1865–66 gap, the identity rule is corroborated 0 times. The label reads "the Department of State" for 193 of the 197 head-from rows (MEASURED, MSE [V]).

### 3.6 Correspondence network labelled as such

| | |
|---|---|
| Signals | Editor markup from/to in document heads; optionally 3.5 for node annotations |
| Grain | A directed edge per document (sender to recipient). Nodes are name strings within one volume. |
| Identity asserted | None while nodes stay per volume. A node that spans volumes is a string clusterer (DOCUMENTED, RF [R]). |
| Quality | Edges are the editors' own typed marks. Direction was not scored on the gold (not measured). "Seward" resolves to two concurrent officeholders in every year of 1861–69 and 1876–80 (DOCUMENTED, FA verdict), so a cross-volume "Seward" node would merge them. |
| Reach (TEI-267) | 235,751 from/to rows; distinct from/to keys summed per volume: 28,280 (MEASURED, RC [R]) |
| Cost | About 2 sessions for a directed correspondence mode, built as its own view rather than as the co-mention self-join (INFERRED, RA [R]) |
| Gates | The label "correspondence, not co-mention" (FA §4.a); an owner rule for node keys (N17); N8 |
| Verdict | **Conditional:** per-volume nodes once 3.2 exists. Cross-volume nodes: **not yet.** |

### 3.7 Detected-names tier at the agreement arm

| | |
|---|---|
| Signals | Editor markup, filtered NLTagger and the filtered Qwen3-14B sweep, combined as editor ∪ (NLTagger ∩ sweep), with sweep-side boundaries |
| Grain | (document, name string) |
| Identity asserted | No |
| Quality (GOLD, post hoc) | Presence P 0.898 [0.852, 0.942]: 245 keys, 25 false (MEASURED, MAG [V]). Under a reversed tie-break, which is an equally valid maximum matching, P is 0.882 with 29 false; the flips are one real person emitted twice, as full name and nested surname (MEASURED, VAG). Presence R 0.767, 221 of 288 (MEASURED [V]). Per-band P: 0.980 / 0.973 / 0.745 / 0.842 over 18 / 15 / 15 / 16 documents (MEASURED [V]). At mention grain: strict F1 0.672, and relaxed P 0.857 over 350 spans (MEASURED [V]). **No corpus-scale precision exists.** Multiplying the pooled gold P by corpus pairs gives about 78,000 wrong pairs, and weighting by band about 95,000. Both are illustrations across two populations, not estimates (INFERRED, MAG and VAG). |
| Reach (TEI-267) | 768,928 pairs in 190,658 documents (96.5%), 157,028 keys (MEASURED, MAG [V]). **Beyond the editor layer** it adds 545,423 pairs in 150,674 documents (76.3%). After a within-document last-token collapse that becomes 440,528 pairs in 138,882 documents (70.3%), a proxy (MEASURED, VAG). 66.8% of the added pairs have a row inside a paragraph and 2.1% are heading-only (MEASURED, VAG; MAG's 76.1% "body prose" counts lists and tables). POCOM ceiling for the added pairs: an officeholder with that surname was in office in 17.4%, exactly one in 15.4% (MEASURED, MAG [V]; ceilings). |
| Cost | No new model run; the stores exist. The artifact is 2,926,099 bytes with gzip -9, 48 KB larger than editor ∪ filtered NLTagger despite having 11% fewer pairs (MEASURED, MAG [V]). Engineering: 3–4 sessions for generator, artifact and re-apply hook (INFERRED, RA [R]). |
| Gates | An owner floor per band, with the matcher rule fixed (N5); a fresh held-out sample (N3); the OS-build pin and filter promotion; a bundle decision; "Detected name" wording and a provenance label (none of the 8 fits); N8 |
| Verdict | **Conditional** |

### 3.8 Search facet by name

| | |
|---|---|
| Signals | The vocabulary of 3.2 or 3.7; FTS |
| Grain | A name string across documents or volumes |
| Identity asserted | Implicitly: a facet bucket folds everyone who shares the string |
| Quality | String folding is measured: 'johnson' (10,761 filtered-sweep pairs) and 'wilson' (10,010) each fold several people (MEASURED, FA §2.1). FTS stemming also misleads. 'Wells' matches 41,794 documents in the TEI-rule volumes, but the case-sensitive word occurs in only 311 of them (0.74%). 'Root' occurs in 936 of 1,784 (MEASURED, MOF [V]; app-view documents in the TEI-rule volumes). These are ceilings on token occurrence. The app's `frus_exact_word` function is the post-filter (DOCUMENTED, MOF). |
| Reach | Whatever vocabulary ships |
| Cost | About 1 session once the data exists (INFERRED, RA [R]). Warm, volume-scoped counts took about 4–12 ms for Seward and Hull and 73–474 ms for Wells across two runs (MEASURED, MOF and VOF; Mac, not iOS). |
| Gates | An owner aggregation rule (N17); the exact-word post-filter; the gates of the vocabulary it reads |
| Verdict | **Conditional** |

### 3.9 Claude-verified names

| | |
|---|---|
| Signals | The agreement arm and the disagreement pools as candidates; Claude (Sonnet 5 or Opus 5) through Message Batches with ±200–300-character windows; a local 27–31B model as the control |
| Grain | (document, name string) |
| Identity asserted | No |
| Quality | **Unmeasured.** Required performance: on the gold's three-way pool a verifier must reject at least 89.0% of false keys to reach P 0.898, and at least 92.7% for no more than one false name per 3 documents (INFERRED, RF [R]). On 64 documents only a precision arm that removes at least about 80% of false spans, while losing no more than about 2% of true ones, registers as better (INFERRED, RC [R] from LP `churn.json`). Queue yield on the gold: 58 of 330 queue pairs can add a true new name under lenient overlap, and 241 touch no gold mention (MEASURED, VCJ; MCJ's "≤ 62 of 330, ≈ 267 false" mixed populations). At corpus scale, at least 119,094 of the census three-way pool's 1,072,769 net pairs (11.1%) are NLTagger boundary variants of mentions both detectors found (MEASURED, VAG). |
| Reach | See the two jobs in the table below the card. |
| Cost | See the table below the card. Locally, Qwen3-14B no-think needs about 183–191 Studio hours for the queue and 171–176 hours for the arm filter, quality unmeasured (INFERRED, MCJ [V]). A pilot of either job on the 64 gold documents, Opus 5, 3 replicates, standard high effort, is $1.6 and $1.4 central (INFERRED, MCJ [V]). A confirmation run over about 250 fresh documents is about $15–16 on Sonnet or $37–40 on Opus per run, standard (INFERRED, RC [R]). |
| Gates | N1–N6, N10, N11, N14; a per-band floor |
| Verdict | **Not yet.** A pilot is conditional on authorization, a fresh held-out sample and pre-registered thresholds. A corpus filter pass produces Claude verdicts, not a precision estimate; precision comes only from the keyed sample (VCJ). |

The two verification jobs:

| job | population (TEI-267) | perfect-verifier ceiling on the gold (post hoc) | Sonnet 5, batch+cache, low effort | Opus 5, batch+cache, low effort |
|---|---|---|---|---|
| Filter the agreement arm (precision) | 1,310,341 spans / 758,194 pairs (MEASURED, MCJ [V]) | Editor + perfectly filtered arm: P 0.9955, R 0.767, false keys 25 → 1; 1930–1945 P 0.745 → 1.000 (MEASURED, RC [R]) | $129 / $209 / $1,113 | $257 / $495 / $2,865 |
| Verify the queue (recall) | 1,526,825 spans / 1,051,899 pairs, 929,012 of them new at presence grain (MEASURED, MCJ and VCJ) | Disagreement set perfectly verified: P 0.921, R 0.969 (MEASURED, RC [R]; RC's pool differs from MCJ's queue) | $146 / $223 / $1,130 | $292 / $525 / $2,913 |

Costs INFERRED, MCJ [V].

### 3.10 Claude-written correspondents guides

| | |
|---|---|
| Signals | Structured facts from 3.2 (heads, datelines, document ids), POCOM career lines and Source Explorer roll pointers, written up by Claude or by the on-device FoundationModels |
| Grain | Prose per volume or per chapter |
| Identity asserted | Not required, but prose invites it. Any sentence naming a POCOM officeholder inherits 3.11's gates. |
| Quality | No instrument exists. A claim-level citation audit is needed. |
| Reach | 267 volumes. 9,954 structure sections contain at least one marked row (MEASURED, MCJ [V]; live-index section structures over the TEI-267 volume ids). The 90th-percentile section has 4,232 characters of heads and datelines (MEASURED, RC [R]; app view, RC's section definition). |
| Cost | About 1,500 words per volume: Sonnet 5 batch+cache low $5.5 / $6.4 / $8.1, Opus 5 standard high $54 / $70 / $92. About 1,500 words per chapter over 9,954 chapters: Sonnet 5 batch+cache low $174 / $200 / $249, Opus 5 standard high $1,897 / $2,446 / $3,153 (INFERRED, MCJ [V]; VCJ found MCJ's per-volume key counts used a different key from the one named, with negligible cost effect). The on-device model costs nothing per request, and a 90th-percentile section's facts fit its 3,072-token budget. Its output is per device, unscored and cannot be bundled (INFERRED, RC [R]). |
| Gates | 3.2 first; N9 grounding and the citation audit; localization of generated English prose; N10; a bundle decision; provenance |
| Verdict | **Not yet** |

### 3.11 POCOM "possible officeholder" tier with filing context

| | |
|---|---|
| Signals | Editor-marked from/to rows, POCOM surname × year, the Source Explorer chapter post, and deterministic initials and signature checks. No model. |
| Grain | (document, side) mapped to a POCOM slug, held in a table of its own |
| Identity asserted | Yes, hedged as "possible identity, from filing context" |
| Quality | **No precision on the target population:** 0 of 300 evaluation rows are keyed (MEASURED, VCJ). What exists is listed in the bullets below the card. |
| Reach | Ceiling: the 45,258 rows where POCOM names exactly one person (MEASURED, MSE, SE-ROWS 1861–1899) |
| Cost | No API cost. 3–4 sessions (INFERRED, P3 and RA [R]), plus a larger POCOM artifact and the owner sitting. |
| Gates | Build and measure the deterministic checks first. Then a blind-keyed sample sized to the claim (INFERRED, MSI; bounds MEASURED [V]): **(A)** 100 rows from the stratum where the surname rule and the chapter post agree, 25 per decade (1861–69, the 1870s, 1880s and 1890s), which gives a lower bound of 0.963 with zero errors and 0.9455 with one; **(B)** about 380 rows for per-class claims; **(C)** 450–500 rows for coverage beyond that stratum. A separate table: no `authority_id`, no merge overrides, no seal. Owner wording and a provenance sentence; N8; N15. |
| Verdict | **Not yet** |

Evidence available for 3.11 (SE-ROWS 1861–1899, post-#1292, what Source Explorer shows):

- **Chapter rule.** POCOM names one person in 45,258 of 84,234 rows. The chapter post corroborates 37,301 (82.4% of 45,258, INFERRED) and contradicts 2,062. Location narrows several candidates to one in 2,081 rows; the Secretary-over-assistant convention alone narrows 8,642 (MEASURED, MSE). VSE re-derived the Department part row by row (15,692 of 15,696 rows agree); the chief-of-mission part was not independently reproduced. "Corroborated" means two rules applied to the same register agree.
- **F. W. Seward.** 117 head-from rows are first-signed by F. W. Seward. W. H. Seward is assigned to all 113 of them that Source Explorer shows, and the #1292 sender rule decides 0. The initials in the row would catch 108 (MEASURED, MSE [V]).
- **William Hunter, 1865–66.** 411 rows, 0 corroborated in every arm (MEASURED, MSE [V]).
- **Silver covers post-1910 only.** Where POCOM picks one person on a positive silver head, it agrees 0.9993 / 0.9982 / 0.9624 of the time in 1900–1929 / 1930–1945 / 1946– (MEASURED, MSI [V]). Adding crosswalked people who have no POCOM slug gives 0.972 / 0.939 / 0.863 (INFERRED, MSI). That figure excludes 539 / 1,490 / 0 picks on linked heads with no crosswalk id, and in 1930–1945 those outnumber the scored picks (MEASURED, VSI). The "1900–1929" silver band holds only 1910–1919 documents. The negative-silver errors come mostly from a few namesake pairs (VSI).
- **Pre-1900 silver is one person.** Hamilton Fish, on 459 heads (MEASURED, MSI [V]).
- **Head format differs.** Untagged 1861–1899 from/to heads are 95.7% bare honorifics, and 1.3% name a post; silver, outside Fish, is 0% bare honorific (MEASURED, MSI; VSI: 96.4% start with an honorific, an office word appears in at most 1.3%). Silver therefore cannot license pre-1900 identity.
- **Coverage.** 25,687 arm-B rows (1861–1899) have no candidate because the role is outside POCOM (MEASURED, RC [R]). Bundled POCOM careers cover 6 of the 481 people who held a chief-of-mission or principal post in 1861–1905 (DOCUMENTED, P3).

### 3.12 Inline highlighting of unmarked names

| | |
|---|---|
| Signals | Agreement-arm spans (sweep boundaries), R-0 offsets, and a mapping to the reader's render text |
| Grain | A character span in the render flat text (UTF-16 offsets) |
| Identity asserted | No, but it marks a string as a person inside the text itself |
| Quality | Mapping: exact, unique matches on 20- then 10-character context anchors. On SAMPLE-400 that places 88.3% of sweep spans and 88.8% of NLTagger spans correctly, places 0 wrongly, refuses 4.9% / 4.3%, and leaves 6.8% / 6.8% inside footnotes, which have no body offset (MEASURED, VOF; MOF's 5.6% / 4.9% footnote share was undercounted). A surface-only fallback puts footnote spans onto body text (42 of 338 sweep footnote spans) and must not be used (MEASURED, VOF). A converter that wraps every occurrence of a detected surface would wrap 11.9–16.7% of occurrences that no detector tagged (MEASURED, VOF, two samples). Name quality is the arm's mention grain: strict F1 0.672, relaxed P 0.857 (MEASURED, MAG [V], GOLD). |
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
| Reach | Contradicted + location-narrowed + Seward-convention rows, 1861–1905, arm B: 13,907 on the pre-#1292 approximation and 14,495 after #1292 (MEASURED, MCJ; VCJ reproduced both by re-running the rule script). Unresolved (volume, surface) marked rows: 22,688 (DOCUMENTED, LP `cost-scale`; RC [R]). |
| Cost | 13,907 rows: Sonnet 5 batch+cache low $4.0 / $5.7 / $13.1; with document text, Sonnet 5 $17 / $20 / $36 and Opus 5 $34 / $46 / $92 (INFERRED, MCJ [V]). The post-#1292 count moves the Sonnet batch cost by under $0.5 (VCJ). The 22,688 unresolved rows: Sonnet $10, Opus $24, central (INFERRED, RC [R]). |
| Gates | Deterministic checks first; the blind-keyed stratified sample of 3.11; N9 grounding; a separate table; never the seal; N1, N2, N10, N11 |
| Verdict | **Not yet.** Cost is trivial; the owner's keying sitting is the gate. |

### 3.14 Identity tier

| | |
|---|---|
| Signals | All of the above |
| Grain | Authority identity |
| Identity asserted | Yes |
| Quality | 0 of 300 keyed. POCOM surname × year is a 55.4% ceiling on the marked layer and 12.7% on the detector layer (MEASURED, FA §2.5). Silver licenses post-1910 regression testing only. |
| Cost | Dominated by owner sittings |
| Gates | FA §6.4's identity trigger, applied to each identity rule; N4 |
| Verdict | **Not yet**, unchanged |

---

## 4. Per-assessment deltas

### 4.1 The feasibility assessment (FA, PR #1290)

| statement | where | changes? | what it now reads |
|---|---|---|---|
| "The thing that decides feasibility is not the detector — it is the app's own rollup." | Verdict; §6.1 | **Changes** | For carriers outside the person tables the clusterer never reads the rows. Per-feature floors, a blind-keyed identity sample and measured verifiers decide instead (§1). |
| "It is a correspondent index, not a people index (97.8% …)." | Verdict; §2.1; §4.a | No | A property of the editors' markup. Any carrier built on it inherits it. |
| "A measured wrong-name rate of zero on the 64-document gold (0 false name keys of 79; 88 of 88 predicted spans overlap a gold mention)." | Verdict | **Changes in status** | The count is right, but it holds by construction: the gold was seeded with those 88 spans and none were removed (MEASURED, VSI). It is not an independent precision. |
| "Read from the shipped `PersonClusterer`'s code, it would merge confidently-wrong persons by default." | Verdict; §3.4 | **Changes** for isolated carriers | The defect class survives wherever a carrier aggregates by name string, and in any POCOM or Claude identity pick. |
| "Every shape needs a code gate in `PersonClusterer` before a single derived row exists." | §3.5 | **Changes** | Becomes the isolation invariant (N8). The full gate returns if entries are folded into the People browser. |
| Agreement arm "acceptable … behind an owner precision floor" | Verdict; §4.b2 | No, for direct display | Two additions. The gold P depends on the matcher tie-break: 0.898 or 0.882 (MEASURED, VAG). The corpus census now exists (§2.1, gate 20). |
| "NLTagger alone is borderline." | §4.b1 | No, for display; relaxes as verifier input | As a candidate source, its recall matters more than its display precision. |
| "Any sweep-bearing presence layer is not acceptable (≈3.8 wrong names per document)." | Verdict; §4.b3 | No, for display; relaxes as queue input | The sweep-only increment is 977,228 of 1,841,697 queue pairs (53.1%) and adds 4,306 documents (MEASURED, RF [R]). The 1,841,697 equals MAG's 768,928 arm pairs + 1,072,769 net pool pairs [V] (INFERRED arithmetic). |
| "Identity reconciliation … is not shippable on current evidence." | Verdict; §4.c | No | Silver adds post-1910 regression material only (§3.11). |
| "No shipping person surface reads a character offset … the sweep's offsets justify only an inline surface that does not exist." | §3.1; §3.5 | **Changes** | "Maximum use" proposes such surfaces, and the mapping is now measured: 88.3% of sweep spans placed correctly, 0 wrongly (MEASURED, VOF). |
| "Step 0 … the cheapest early-era gain in the whole program." | §4.0; §6.2 | **Changes** | Fixed in code by #1291. The owner's reindex is what remains. |
| "The agreement arm's corpus-scale rows, reach and size — unmeasured." | §4.b2; §5; §7 | **Changes** | Measured: 1,310,341 rows, 768,928 pairs, 190,658 documents, 2,926,099 bytes gzipped (MEASURED, MAG [V]). The by-analogy estimate (8.99 MB / 2.88 MB gz) was close. |
| "What the 11.55-day sweep is for … not evidence for identity, roles or dates." | §4.d | Partly | The review queue and the offset-bearing layer move from contingent uses to central ones. "Not evidence for identity" is unchanged. |
| The first slice: Step 0, then (a) whole-scope, then (b2) after the ingestion path is exercised, then (c) on pre-1910 | §6.2 | **Changes** | Replaced by §5 here. "Pre-1910 first for identity" survives and is strengthened, because pre-1900 identity evidence can only come from filing context. |
| POCOM ceilings, 55.4% / 12.7% | §2.5 | No | The loader misses Monroe's one attribute-bearing appointment block, which moves 5 rows (MEASURED, VSE). That is within FA §7's disclosed ≤ 8 rows. |
| Dollar lines rescaled from the Ride-Along's per-candidate pricing | §4.c; §7 | **Superseded** | By the MCJ job prices in §3. |

### 4.2 The Claude-pass answer (P2)

| statement | changes? | what it now reads |
|---|---|---|
| "Probably yes for one job": judging existing candidates, not re-reading for new ones | **Narrows** | Two separable jobs replace one whole-pool judge. **(1)** Filter the agreement arm for precision. Its post hoc ceiling is P 0.9955, R 0.767, and it is the only role that can move the owner's per-band floor, because 24 of the arm's 25 false keys on the gold lie in its intersection spans, outside the disagreement set (MEASURED, RC [R]). **(2)** Verify the disagreement set for recall, ceiling P 0.921 / R 0.969 (MEASURED, RC [R]). |
| A perfect judge of the pool scores 0.988 against 0.828 for the best arm | No | Still an in-sample ceiling on the gold, now split by job as above |
| Cost table: re-read $440–680 / $1,000–1,600; judge $460–700 / $1,100–1,700; identities $160–320 / $410–790 (Sonnet 5 / Opus 5) | **Changes** | The identities line priced a 301,979-row detector-union shape; the 29,949 marked correspondent rows cost $13 / $32 (DOCUMENTED, LP `cost-scale/costs.json`; RC [R]). The reframed jobs, on Sonnet 5 batch+cache, low effort: arm filter $129 / $209 / $1,113; queue verification $146 / $223 / $1,130; Source Explorer × POCOM adjudication $4.0 / $5.7 / $13.1; per-volume guides $5.5 / $6.4 / $8.1. All four together: Sonnet $284 / $444 / $2,265, Opus 5 $568 / $1,048 / $5,833 (INFERRED, MCJ [V]). |
| "Pilot the judging and detection on the 64 keyed documents … plus a free local Qwen run" | **Changes** | Drop the detection arms. Run the two verifier jobs with windows versus whole documents, 3 replicates, with a gazetteer-only arm and a local 27–31B arm on identical inputs. The 64 documents are a screen, not proof; confirmation needs a fresh sample of about 250. All Opus pilots at 3 replicates, standard high effort, total about $25 central and $51 high (INFERRED, MCJ [V]). |
| "Test identity only after you key 100 pre-1910 rows, blind" | **Changes** | The principle holds, but the sample is wrong for the reframe. The 100 pre-1910 rows hold 12 several-candidate rows, a zero-error lower bound of only 0.7575 (MEASURED, MSI [V]), and they were not drawn on Source Explorer outcomes. Build the deterministic initials and signature checks first, then key tiers A / B / C (§3.11). |
| "Running this as subagents inside Claude Code is the wrong route." | No, for production passes | Design-time reading of error rows needs a stated exception, and the authorization should say whether it covers that. |
| "One untested cheaper option": Gemma-4 31B and Qwen3.6 27B on the Studio | **Changes** | Becomes a required control arm. On Qwen3-14B no-think, all four jobs take 367.7 or 369.4 Studio hours under one consistent time model (INFERRED, VCJ; MCJ's 361–376 h bracket mixed two models). Local verifier quality is unmeasured. |
| "A good result would not change the rollup code gate or your name-string decision." | **Partly changes** | The rollup gate no longer binds isolated carriers. A good arm-filter result can move the per-band floor for the detected tier. It moves nothing about identity. |
| "In 96% of those [pre-1900] documents the head reads only 'Mr. Seward to Mr. Adams', and just 2.2% name a post." | No; corroborated at head grain | Untagged 1861–1899 from/to heads: 95.7% bare honorific, 1.3% name a post (MEASURED, MSI [V], head population, not documents) |
| "62–81% of heads name a post and place" after 1900 | **Changes** | That does not hold for 1900–1909: 68.0% of its untagged heads begin with an honorific. From 1910 on, 76.0% use the parenthesised-name form (MEASURED, VSI). |
| "18.6% of the marked correspondent mentions have no candidate in any local source" | No | It now defines the grounding gate (N9). |
| "Having a model pre-fill them would contaminate the only scoring set." | No; extended | It now covers every instrument, including the label sample and the fresh detection sample (N4). |

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
| Documents still under unread glued titles (a known subset) | 148 (1861–1899) + 9 (1900–1905) |
| Foreign-legation documents by the title the walk used (S_after) | Legation title 1,969; parent country 2,276 (305 of them a different country); topical 7; none 221; of 4,473. VSE, with its own detector: 1,967 / 2,297 / 7 / 226 of 4,497. |
| Rows under the legation rules (S_after) | 5,015: POCOM names one person in 540; 413 corroborated; 121 contradicted; 1,488 by the Secretary convention; 2,914 roles outside POCOM |
| F. W. Seward class | 117 head-from rows. Shown 68 → 113. The sender pattern matches 106. The sender rule decides 0. W. H. is assigned to 113 of 113 shown. [V] |
| William Hunter, 1865–01–01 to 1866–07–26 | 411 rows. Contradicted 269 → 377; corroborated 0 in every arm [V] |
| Filing-role label reach, rows | 47,734 → 52,616 [V] |
| POCOM single picks corroborated | 82.4% shown after #1292, against 90.4% for B0 (INFERRED) |

**P3's statements**

| statement | changes? | what it now reads |
|---|---|---|
| "It attaches a post to about 9 in 10 of POCOM's single picks." | **Changes** | 9 in 10 was the Python approximation (90.4%). What Source Explorer shows after #1292 is 82.4% (INFERRED). "Corroborated" means two rules on the same register agree (VSE), which is not identity evidence. |
| "As shipped, without the title repairs, the agreeing count is 36,269." | **Changes** | 37,301 after #1292 |
| The "repaired" counts (40,907 / 2,415 / 2,240 / 8,733) | **Changes in status** | They were a Python approximation. The merged classifier matches it exactly on country chapters (36,792 / 1,893 / 2,079 / 7,062) and differs by 2,426 rows elsewhere. |
| "Seward stays unresolved … at least 117 head rows were signed by F. W. … initials would catch 108." | No | The #1292 sender rule gets direction right but decides none of these rows, because their datelines already say Department of State. |
| "Contradictions cut both ways": topical filing, and POCOM gaps such as William Hunter | No | Hunter contradictions rose from 269 to 377 because more rows are now shown. The filing role is right for 193 of 197 head-from rows. |
| "Consuls, foreign envoys in Washington, chargés and acting officers aren't in POCOM." | No | Legation chapters now receive Notes suggestions (11,930 documents), but 2,914 rows under the legation rules are roles POCOM does not cover. |
| "After 1900 the rule adds almost nothing." | Partly | 1900–1905 is unchanged by #1292. 1906–1909 has neither a Source Explorer classifier nor silver (N15). |
| "Only two pre-1900 volumes carry editor identity links." | No | The crosswalk holds one entry for each, Hamilton Fish (MEASURED, MSI [V]). |
| "The 1873 score is close to circular, 701 of 701." | **Changes in use** | As a filing-role label proxy it scores 649 of 651 on role kind. Place agreement stays near-circular (VSE). |
| "Post-1905 proxy: 98.6% against 93.3%, on about 15% of picks" | **Changes in reading** | The pooled figure is 475 of 482 heads, mostly from 1930–1945 and 1946–. In 1900–1929 it rests on 23 heads where both rules name the same person, and 237 of the 301 such rows in 1930–1945 rest on POCOM-derived gold (MEASURED, MSI and VSI). |
| "A keyed sample of about 450–500 rows" | Refined | Still the full design. Narrower claims can use tier A (100 rows) or B (about 380) (INFERRED, MSI). |
| "Shared code; more POCOM data (6 of 481); its own table; roughly 3–4 offline sessions" | No | Carried into N13 and §3.11 |
| "Source Explorer shows no suggestion for 23% of 1861–1899 documents." | **Changes** | #1292 reduced it to 14.1% (INFERRED from RF, SE-DOC-AY). A residual set of glued titles remains (157 known documents). |
| (new) | — | The strongest product of the chapter-context work is the filing-role label, not an identity (§3.5). |

### 4.4 Errata found while building this delta

1. **FA §6.2 document count.** It says "5,530 orphan mention rows over 2,165 documents". 2,165 is all documents in the three volumes (794 + 912 + 459). The documents holding the orphan rows number 2,089, which is also the sum of FA §4.0's own table (MEASURED, MSI [V]).
2. **FA verdict, markup layer.** "88 of 88 predicted spans overlap a gold mention" and the zero wrong-name rate come from seeding the gold with those spans, not from an independent check (MEASURED, VSI).
3. **FA §2.2 caveat 3, tie-break.** "No ranking changes" under a different tie-break was tested only on the NLTagger arms. Under a reversed tie-break the agreement arm falls from 0.898 to 0.882 and ranks below the NLTagger-side intersection arm, 0.887 (MEASURED, VAG).
4. **P2's identity price.** The identities line ($160–320 / $410–790) priced a 301,979-row detector union, not the marked correspondent rows (DOCUMENTED, RC [R]).
5. **P3's repaired counts.** P3's "with the chapter-title gaps repaired" counts are a Python approximation, not a classifier run (MEASURED, MSE).
6. **Stale hash record.** `geo-fix/after/source-sha256.txt` records a source hash that matches no commit. The output it describes is byte-identical to a rebuild from HEAD (MEASURED, MSE).
7. **label-validation's 98.6% figure.** Its pooled post-1905 figure is dominated by 1930–1945 and 1946– rows, and most of its 1930–1945 support rests on POCOM-derived gold (MEASURED, VSI).
8. **Scratchpad double count.** Measurement-internal, not in the record: `measure-silver/silver.py` counts each head twice in its concentration tables. Walter Hines Page has 1,678 heads, not 3,356; the 23.6% share is right (MEASURED, VSI).

---

## 5. The recommended first slice under the reframe

Each step needs the one before it unless marked independent.

| step | what | needs | model spend |
|---|---|---|---|
| 1 | Reindex to v51 and re-measure population and orphan figures. This delivers 3.1. | Owner; independent of everything else | None |
| 2 | Decide wording and provenance for "Correspondent from markup" and "Filing role", the §5(3) exemption for markup-only carriers, and the name-string grain for each carrier | Owner; independent | None |
| 3 | Write the isolation invariant test (N8) | Engineer; not sized | None |
| 4 | Build correspondents from markup as a per-document list in the Research rail and a per-volume section (3.2, 3.3), and add the disclosure to the NLTagger People lens (3.4) | Engineer: 2–3 sessions for the list and section, 0.5–1 for the lens (INFERRED, RA [R]). A bundled artifact (588,607 bytes gzipped, MEASURED) plus `xcodegen`, or a parse-time table plus a reindex. | None |
| 5 | Build the deterministic checks: F. W. initials and signature, a listing of acting officers and POCOM gaps, and a census of chapter-title forms. Share the classifier with a generator (N13). | Engineer; part of P3's 3–4 sessions (INFERRED) | None |
| 6 | Stage and blind-key the samples, identity first. (a) Identity tier A: 100 rows where the two signals agree. (b) The filing-role label sample (N12). (c) A fresh detection sample of about 250 documents from the corpus length distribution. (d) The 8 unkeyed M2a documents as held-out. Lock each blind column. | Engineer stages; owner sittings under the N4 protocol. Can start in parallel with step 4. | None |
| 7 | Run the local controls on identical inputs: a gazetteer-only arm and a local 27–31B verifier, on the gold and on sample 6(c) | Engineer; Studio time | None |
| 8 | Decide, one label kind at a time, whether to ship the filing-role label (3.5), against sample 6(b) | Owner floor | None |
| 9 | Only with authorization (N1) and a cap (N2): a Claude pilot of the arm filter and the queue verification. Windows versus whole documents, 3 replicates, scored against pre-registered thresholds (N5) on sample 6(c). | Owner authorization, cap and pre-registration | About $1.4–1.6 per job, Opus 5 on the 64 gold documents; about $37–40 Opus per run on 250 fresh documents (INFERRED, MCJ [V], RC [R]) |
| 10 | Decide on the detected-names tier (3.7), with or without a verifier, from step 6(c) scores against a per-band floor | Owner | None |
| 11 | Only if step 10 passes and a verifier helped: one corpus verification pass, capped at the high scenario | Owner | Arm filter up to $1,113 on Sonnet 5 or $2,865 on Opus 5, batch+cache (INFERRED, MCJ [V]) |
| 12 | Only if tier A passes its threshold: the POCOM "possible officeholder" tier (3.11). Tiers B and C for claims about individual classes. | Owner sittings | None |
| 13 | After step 4: a guides prototype over 10–20 chapters, on-device FoundationModels against Claude, with a citation audit (3.10) | Authorization if Claude is used | Small (not priced for 10–20 chapters) |

Inline highlighting (3.12) and Claude-adjudicated identities (3.13) are not in the slice.

---

## 6. Revised owner decisions

1. **Reindex to v51.** This unblocks 3.1 and moves the app view to 263 volumes / 196,447 documents (INFERRED).
2. **Name-string grain, per carrier.** Accept or refuse per-document lists. For cross-document facets and network nodes, choose per-volume scoping or a "name string, not person" disclosure (N17).
3. **Wording and provenance.** Word "Correspondent from markup", "Filing role", "Detected name", "possible identity, from filing context", "checked by a model" and "model-written summary". Choose a ninth `ProvenanceSource` or disclosure sentences. The seal stays tied to an authority id.
4. **The §5(3) exemption.** Grant it for markup-only carriers. Pin the pre-1910 population for everything else (85 or 76 volumes). Decide whether 1900–1909 is in scope for any identity claim (N15).
5. **Hosted-model authorization.** Authorize or refuse sending corpus text: scope, models, route, retention. Refusal leaves local models as the only verifier route.
6. **Spend caps** for each phase.
7. **Precision floors** for each feature and band, with the thresholds and the matcher tie-break pre-registered before any model runs.
8. **Keying.**
   - **Order:** identity tier A and the label sample before any review of machine output.
   - **Sizes:** tier A 100, tier B about 380, tier C 450–500; the label sample; a 250-document detection sample.
   - **Protocol:** blind (N4), with no model pre-fill of any instrument; the 8 unkeyed M2a documents kept as held-out.
9. **The People browser.** Decide whether any verified entry may ever enter it. If yes, FA §4.a's clusterer gate and the rollup bump return.
10. **User verdicts.** Keep them device-local, or schedule a CloudKit Production deploy.
11. **Bundle or download tier** for each artifact.
12. **Terms review** before any Claude-derived artifact ships.
13. **Scope of "maximum possible use".** Treat it as a list of separately gated features rather than one program goal.

---

## 7. What stays unsettled, and the risks of "maximum possible use"

### 7.1 Unsettled

| question | status |
|---|---|
| Corpus-scale precision of any detector arm | Unmeasured. Only the 64-document gold exists, with the matcher tie-break affecting it. |
| Filing-role label precision on 1861–1899 no-list rows | Proxies from other populations only. No independent evidence for U.S.-mission labels outside 1873, or for labels inside foreign-legation chapters. |
| The chief-of-mission part of the chapter-rule counts | Not independently reproduced (VSE) |
| Pre-1900 identity precision | 0 of 300 keyed |
| Verifier specificity; Claude against a local model | Unmeasured |
| Real token counts, thinking tokens, cache hits under batches; the date of the unit prices | Unmeasured; `cost_model.py` records no date |
| 1900–1909 | No silver, no Source Explorer after 1905, no proposed stratum |
| Direction accuracy of editor from/to typing | Not measured |
| Figures at index v51 | Not re-run |
| Chapter-title forms the merged normaliser still misses | A known subset only (157 documents) |
| How the OH people registry joined FRUS list entries to POCOM | Undocumented, so silver circularity for 1946– is a hypothesis (VSI) |
| App-shaped bundle sizes; iOS FTS latency; render-time anchored-search cost | Unmeasured |
| Terms for shipping Claude-derived artifacts; whether the repository is public (bears on leakage) | Not assessed |

### 7.2 Risks of "maximum possible use" as a goal

1. **Corpus before pilot, again, with money.** The sweep already ran all 267 volumes before any precision existed (FA §5). A corpus Claude pass before a held-out pilot repeats that.
2. **Recall-maximising unions.** The three-way union reaches presence R 0.976 at P 0.491, with 292 false keys over 64 documents (DOCUMENTED, FA §2.2 via RF). Displayed precision would then rest entirely on an unmeasured verifier.
3. **Ceilings stacked into apparent confidence.** POCOM surname × year, the chapter post and the Secretary convention agree mostly because they read the same register. Agreement among them does not separate W. H. from F. W. Seward.
4. **Contaminated instruments.** Pre-filled keys, scoring on the 64 leaked documents, or rules tuned on published error rows would turn evaluation into agreement with the machine.
5. **"Machine verified" read as authority.** A chip or "This app's model" wording can present a hosted-model guess with seal-like confidence.
6. **Model memory as a source.** 18.6% of marked correspondent mentions have no local candidate (DOCUMENTED, P2).
7. **Surface proliferation.** Each new carrier is a new place for wrong names, and string-keyed facets and networks fold people without touching `PersonClusterer`.
8. **Post-hoc overfitting.** Arms, filters, prompts and matcher rules get tuned on 64 documents with 15–18 per band. The tie-break alone moves agreement-arm P by 0.016.
9. **Pressure to fold entries into the People browser.** That re-imports the clusterer gate the isolated carriers avoid.
10. **Irreproducibility and silent expiry.**
    - NLTagger output is pinned to OS 26.6.2.
    - The sweep is non-deterministic.
    - Claude outputs are non-deterministic and model ids retire.
    - Label evidence expires with classifier edits: #1292 changed the outcome class of 2,426 rows against the approximation (MEASURED, MSE).
11. **Owner-time displacement.** Review queues of about a million pairs compete with the keying sittings that gate identity.
12. **Cost overrun.** High scenarios run about 5× central on the headline set: $444 against $2,265 on Sonnet 5 batch+cache (INFERRED, MCJ [V]). Thinking tokens are unmeasured.
13. **Label drift.** A correspondent index called a people index.
14. **Denominator mixing.** Seven populations are in play: TEI-267, APP-v50/v51, SE-ROWS, SE-DOC-VY, SE-DOC-AY, SILVER and SAMPLE-400. Two unrelated figures coincide at 85.9%: SE-ROWS documents holding a labelled row (26,498 of 30,864) and the SE-DOC-AY suggestion share (27,884 of 32,478) (VSE).
15. **Silver misread as pre-1900 evidence.** Its 0.96–0.999 agreement rates come from post-1910 heads that name the post, with a single pre-1900 person.
