

===== USER (line 837) =====
Could a systematic Sonnet or Opus pass through all 267 volumes do a better job evaluating and applying NLT/Gemma/POCOM data to deliver better results?


===== USER (line 915) =====
Can source explorer help add location context for the pre-1900 candidates using the same strategies the app already uses to suggest central file candidates from the enclosing chapters for documents?


===== USER (line 1694) =====
1292 merged. If 234 were reframed from “extend people browser” to “make maximum possible use of qwen harvest, NLTTagger, POCOM, source Explorer, and Claude verification/synthesis to develop features for untagged people,” how would that affect the latest assessments?


===== ASSISTANT FINAL (line 911, 4001 chars) =====
**Probably yes for one job, not for the others.** Nothing can show "better" until a small test runs, and that test needs your approval to send corpus text to the Anthropic API and spend money. I sent nothing and spent nothing.

First, a correction to the premise: Gemma never detected people in this project. The 11.55-day sweep ran Qwen3-14B. EmbeddingGemma only produces the semantic-search vectors, and the plan to reuse it for identity was never built.

**Where Sonnet or Opus could plausibly beat what exists**
- **Judging the existing candidates, not re-reading for new ones.** Between the editors' marks, NLTagger and the sweep, some arm already proposes 398 of the 406 gold mentions. A perfect judge of that pool would score 0.988 on names per document, against 0.828 for the best current arm. A full re-read could add at most 8 mentions.
- **Following instructions.** 273 of the sweep's 358 surviving false positives are places, institutions and bare titles its own prompt told it to exclude. A stronger model plausibly does better there, but that is unmeasured.

**Where it would add least, or add risk**
- **Identity before 1900.** In 96% of those documents the head reads only "Mr. Seward to Mr. Adams", and just 2.2% name a post. A model would be choosing by convention exactly where nothing can check it.
- **Identity after 1900 needs less help than it seems.** 62–81% of heads name a post and place, and a simple rule with no model already picks one officeholder in about 70% of POCOM's "several" cases.
- **Names from memory.** 18.6% of the marked correspondent mentions have no candidate in any local source, including POCOM and the People register, so any answer there comes from the model's memory.
- **No way to score identity.** None of the 300 identity rows are keyed. Having a model pre-fill them would contaminate the only scoring set.

**What it would cost**

Estimates for a scripted Message Batches job, with token counts about ±25% and thinking tokens unmeasured:

| Job over all 267 volumes | Sonnet 5 | Opus 5 |
|---|---|---|
| Re-read every document and list names | $440–680 | $1,000–1,600 |
| Judge existing candidates per document | $460–700 | $1,100–1,700 |
| Choose identities for unresolved correspondent mentions | $160–320 | $410–790 |

For comparison, the Qwen sweep used about $4–8 of electricity. Running this as subagents inside Claude Code is the wrong route: input alone would cost more than the batch job, and the batch discount would be lost.

**What I'd do instead of a full pass**
1. **Pilot the judging and detection on the 64 keyed documents.** Run both models three times each, plus a free local Qwen run on whole documents. That control shows whether any gain comes from the model or just from seeing whole documents instead of 800-token chunks. Pass thresholds are written down before anything runs.
2. **Test identity only after you key 100 pre-1910 rows**, blind.

The pilot costs about $10–22 without thinking tokens and up to about $150 with a generous thinking allowance.

**Two limits on what the pilot can show:**
- **Gain needed.** On 64 documents only a gain of about 0.05 F1 or more registers as real.
- **Leakage.** Those documents' errors are already published in the repo, so a win is a screen, not proof. Confirming it needs a fresh sample of about 250 documents, including long ones.

**What a good result would not change.** It would not remove the rollup code gate or your name-string decision from the assessment. At most it replaces the sweep's vote in the detection layer, or it adds a machine-proposed identity tier that never earns the "Reconciled identity" seal.

**One untested cheaper option.** The Studio already has Gemma-4 31B and Qwen3.6 27B loaded. None of the analysis priced a local judging pass with those.

The measurements are in the session scratchpad under `llm-pass/`; tell me if you want them saved to the repo. To run the pilot, I need your go-ahead to send those 64 documents to the API and a spending cap.


===== ASSISTANT FINAL (line 980, 4184 chars) =====
**Yes, as a check on POCOM's surname guesses. It can't yet show that pre-1900 identities are right, and it needs new plumbing to reach the app.** I compiled Source Explorer's actual classifier and ran it over every pre-1906 document, then matched its post hypotheses against POCOM. Nothing was sent anywhere.

**What it adds for pre-1900 correspondents**

The strategy turns "Mr. Adams to Mr. Seward", datelined at the London legation in the Great Britain chapter, into a post: the US minister to Great Britain writing to the Department. Over the 84,234 correspondent rows in 1861–1899 volumes:

| Outcome, with the chapter-title gaps repaired | Rows |
|---|---|
| POCOM's surname-by-year rule names one person | 45,258 |
| The chapter's post agrees with that person | 40,907 |
| The chapter's post contradicts that person | 2,415 |
| Several same-surname officeholders narrowed to one by location | 2,240 |
| Narrowed to one only by assuming "Mr. Seward" means the Secretary | 8,733 |

As shipped, without the title repairs, the agreeing count is 36,269.

- **Mostly corroboration.** It attaches a post to about 9 in 10 of POCOM's single picks, which is the evidence pre-1900 heads never print.
- **Some real namesake fixes.** The two Osborns in Chile and Argentina separate, and so does George F. Seward in China.
- **Seward stays unresolved.** F. W. Seward was Assistant Secretary for all of 1861–69, so location can't separate father from son. At least 117 head rows were signed by F. W. A check on the initials already in the head would catch 108 of them.
- **Contradictions cut both ways.** Some are documents filed under a topical chapter, like Bigelow's Paris despatches in the Mexico chapter. Others expose a legation secretary POCOM confused with a later chief, or a POCOM gap, like William Hunter acting as Secretary in 1865–66.
- **Out of reach.** Consuls, foreign envoys in Washington, chargés and acting officers aren't in POCOM. After 1900 the rule adds almost nothing, because heads already name the post.

**Whether it is right is unmeasured**

- **Only two pre-1900 volumes carry editor identity links,** frus1873p1v1 and v2. As shipped, the classifier reads none of their chapters, because every title starts with a Roman numeral.
- **The 1873 score is close to circular.** With the numerals stripped, chapter plus surname matched the editors' person in 701 of 701 mentions. But except for Hamilton Fish, tying a list entry to a POCOM person itself used POCOM. That score covers about 23 people and no case with several candidates.
- **A post-1905 proxy suggests it filters well.** Over 15 later volumes, where both rules name the same person they are right 98.6% of the time, against 93.3% for surname alone. That combined answer covers only about 15% of the surname rule's picks.

A real pre-1900 precision figure needs a keyed sample of about 450–500 rows. It should include the several-candidate class, the 1860s Sewards, legation chapters and enclosures.

**What reaching the app would take**

- **Shared code.** The classifier and title normaliser live only in the app. No generator extracts headers, datelines or chapter paths.
- **More POCOM data.** The bundled POCOM careers cover 6 of the 481 people who held a chief-of-mission or principal post in 1861–1905.
- **Its own table.** A candidate can't use the authority id, a merge override or the existing merge suggestions, because each would merge people or light the "Reconciled identity" seal. It would be worded as a possible identity from filing context.
- **Cost.** Roughly 3–4 offline sessions, on top of the correspondent layer it builds on.

It doesn't change the assessment's verdict that identity isn't shippable. It adds a concrete clause to the rollup-rule decision and a new wording decision.

**A defect found on the way.** Source Explorer shows no archival suggestion for 23% of 1861–1899 documents. Much of that is chapter titles the normaliser misses: Roman numerals, "British legation.", "Chili" and "(Continued.)". I left a task chip to fix it; the fix helps Source Explorer now, independent of #234.

The harness and measurements are in the session scratchpad under `chapter-context/`.
