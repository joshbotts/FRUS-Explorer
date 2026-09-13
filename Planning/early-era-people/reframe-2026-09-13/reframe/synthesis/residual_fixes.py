import sys
P='/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/reframe/synthesis/reframe-delta-v2.md'
s=open(P,encoding='utf-8').read()
n_ok=0
def once(old,new):
    global s,n_ok
    c=s.count(old)
    assert c==1,(c,old[:90])
    s=s.replace(old,new); n_ok+=1
# U1 step 9 spend
once("""**Windowed verifier on 250 documents:** not priced. **Nearest estimate:** RC's whole-document, detection-shaped estimate is Sonnet $14.61–15.83 and Opus $36.53–39.59 per run, standard (INFERRED, RC R6 [R]); replicates multiply it. **Cap** per run from that estimate plus the thinking allowance. |""",
"""**Windowed verifier on 250 documents:** not priced. Price it with `cost_model.py`'s two treatments (low / central / high) before the run, and set the cap from the high scenario of the treatment run (N2). **Whole-document arm:** RC R6, S1-c shape (adjudicating a three-way candidate list over whole documents), Sonnet $14.61–15.83 and Opus $36.53–39.59 per run, standard (INFERRED, RC `r6-preannotate.json` [R]). That range is two characters-per-token ends, not a low / central / high triple, and it already includes a 4,000-token-per-request thinking allowance. Replicates multiply it. |""")
# E2 detection-shaped in 3.9 cost
once("""**A confirmation run** on about 250 fresh documents is priced only in a whole-document, detection-shaped form:""",
"""**A confirmation run** on about 250 fresh documents is priced only for the whole-document arm, in RC R6's S1-c shape (adjudicating a three-way candidate list over whole documents; RC priced it for pre-annotation, which it recommends against for any scoring instrument):""")
# U2 step 12 and 3.7 gates
once("""Ship the detected tier there first. If a verifier helped, run the frozen verifier over that population only. Then blind-key a stratified spot sample of the produced layer against the per-band floor (N21), and record model id, prompt hash and raw responses (N10).""",
"""Produce the detected tier over that population, running the frozen verifier over it only if step 9 showed a verifier helped. Blind-key a stratified spot sample of the produced layer against the per-band floor (N21). Ship to that population only if the audit passes. Record model id, prompt hash and raw responses (N10).""")
once("""pre-1910 first: ship and audit the pinned pre-1910 population before extending (FA §5(3), §5 step 12); a keyed audit of the shipped layer (N21)""",
"""pre-1910 first: produce the tier over the pinned pre-1910 population, audit it (N21), and only then ship, before extending (FA §5(3), §5 step 12); a keyed audit of each produced layer before it ships (N21)""")
# U3 N12 size + E3 0.9513
once("""The size per cell is unset. Zero errors give a lower bound of 0.8668 at n = 25, 0.9513 at n = 75 and 0.963 at n = 100 (MEASURED arithmetic, MSI [V]). |""",
"""**Size.** A per-band claim for one label kind needs a 75-row band, per FA §6.4 as §2.3 applies it. Five label kinds × three chapter kinds make 15 cells, and only the cells that will ship need a band of their own (INFERRED). Zero errors give a lower bound of 0.8668 at n = 25 and 0.963 at n = 100 (MEASURED arithmetic, MSI [V]), and 0.9513 at n = 75 (MEASURED arithmetic, MSI). |""")
once("""| Filing-role label sample (N12) | unset per cell, label kind × chapter kind | not priced |""",
"""| Filing-role label sample (N12) | 75 rows per shipping cell of label kind × chapter kind (N12) | not priced. FA's ~2–3 h per 300 rows is about 0.4–0.6 minutes per row (INFERRED), but it prices marked from/to names only and does not transfer to post-claim or detection keying. |""")
# U4 keys
once("""| k2_surface | `measure_pocom.k2_surface`, per-volume distinct keys | sum 30,011 (MCJ job D); census K2 gives 30,107 (VCJ) |""",
"""| k2_surface | `measure_pocom.k2_surface`, per-volume distinct keys | sum 30,011 (MCJ job D); census K2 gives 30,107 (VCJ) |
| persons-row key | lower-cased surface, distinct per volume, all marked rows | marked layer: about 30,327 per-volume entries (FA §2.1; VAG) |
| RC per-volume from/to key | RC `synthesis-size.json`: distinct from/to keys summed per volume, from/to rows only | 28,280 (RC) |""")
once("""about 30,327 per-volume entries (MEASURED, FA §2.1;""", """about 30,327 per-volume entries (persons-row key; MEASURED, FA §2.1;""")
once("""distinct from/to keys summed per volume: 28,280 (MEASURED, RC [R])""", """distinct from/to keys summed per volume: 28,280 (RC per-volume from/to key; MEASURED, RC [R])""")
once("""**Pair keys in play:** four — census K2, the grains key, RC's surface key and `k2_surface`.""",
"""**Keys in play:** six — census K2, the grains key, RC's surface key, `k2_surface`, the persons-row key and RC's per-volume from/to key.""")
# E3 other [V] tags
once("""A census-format proxy is 2,632,099 bytes, 588,607 with gzip -9 (MEASURED, MAG [V]).""",
"""A census-format proxy is 2,632,099 bytes, 588,607 with gzip -9 (MEASURED, MAG; it equals FA §2.1's census, 2.63 MB / 589 KB, as a positive control).""")
once("""a census-format proxy of 588,607 gzip bytes (MEASURED, MAG [V])""", """a census-format proxy of 588,607 gzip bytes (MEASURED, MAG)""")
once("""Untagged 1861–1899 from/to heads: 95.7% bare honorific, 1.3% name a post (MEASURED, MSI [V], head population, not documents)""",
"""Untagged 1861–1899 from/to heads, by TEI document year: 95.7% bare honorific; an office word in at most 1.3% (MEASURED, MSI; [V-part]: VSI found 96.4% honorific-led with a different classifier; head population, not documents)""")
# E5 dependencies
once("""Pre-registered thresholds and the matcher tie-break (N5). | independent | owner | None |""",
"""Pre-registered thresholds and the matcher tie-break (N5). The N4 blind keying protocol and the 6(c) seeding choice (N3). | independent | owner | None |""")
once("""excluding F. W.-initial, Secretary-convention-narrowed and location-narrowed rows (§3.11) | **5** |""",
"""excluding F. W.-initial, Secretary-convention-narrowed and location-narrowed rows (§3.11) | **2, 5** |""")
once("""stratified by label kind × chapter kind | independent | as 6(a) | None |""",
"""stratified by label kind × chapter kind | **2, 5** (or a pinned classifier hash) | as 6(a) | None |""")
once("""It is used once, in step 9. | independent | as 6(a) | None |""", """It is used once, in step 9. | 2 | as 6(a) | None |""")
once("""| 6(d) | Key the 8 unkeyed M2a documents as a held-out set | independent | as 6(a) | None |""",
"""| 6(d) | Key the 8 unkeyed M2a documents as a held-out set | 2 | as 6(a) | None |""")
once("""- **6(a) depends on step 5,** because its strata must exclude the F. W.-initial and convention-narrowed rows that the deterministic checks identify.
- **6(b), 6(c) and 6(d) are independent** and can start at once, in parallel with steps 4 and 5.""",
"""- **6(a) depends on steps 2 and 5.** Step 2 fixes the N4 blind protocol, and its strata must exclude the F. W.-initial and convention-narrowed rows that the step 5 checks identify.
- **6(b) depends on steps 2 and 5,** or on a pinned classifier hash, because label evidence expires with each classifier edit and step 5 may change the classifier.
- **6(c) and 6(d) depend on step 2**, which fixes the N4 protocol and the 6(c) seeding choice. After that they can run in parallel with steps 4 and 5.""")
# E6 trip packet
once("""| **conditional** on N22 and the classifier's confidence wording |""",
"""| **conditional** on a keyed sample of archival suggestions (§3.18), or on a disclosure that the pull list comes from an unmeasured classifier |""")
once("""| carry Source Explorer's confidence wording; N22; the era ceiling (volumes to 1905) | **conditional** |""",
"""| a keyed sample of archival suggestions, as §3.18 requires, or a disclosure that the pull list comes from an unmeasured classifier; Source Explorer's confidence wording; N22; the era ceiling (volumes to 1905) | **conditional** |""")
once("""| A measured precision per chip value from the N12 sample, or a disclosure that the chip states which rule fired, not a precision. |""",
"""| A measured precision per chip value, from a sample of the claim the chip is attached to (N12 for filing roles; a keyed archival-suggestion sample for series and reels), or a disclosure that the chip states which rule fired, not a precision. |""")
# E7 chronology
once("""| Chronology rows: "From Mr. Adams (London) to Mr. Seward" | heading and dateline, parsed live; per document | wrong name string; wrong post or direction from parsing |""",
"""| Chronology rows: "Despatch dated London — heading: Mr. Adams to Mr. Seward" | heading rendered as printed, dateline attached to the document; per document | wrong name string; a parsed place or direction read as the named person's post |""")
once("""| `.frusText`; direction accuracy is not measured (§7.1) | **buildable now** |""",
"""| `.frusText`; attach the dateline to the document, never to the name, and show no parsed direction; direction accuracy is not measured (§7.1) | **buildable now** in that form; a parsed direction or a post filter is conditional on a keyed direction and placement check |""")
once("""| 6 | Citation note and Chronology rows, correspondents as printed | 3.17 | heading and dateline text | no | **buildable now** |""",
"""| 6 | Citation note and Chronology rows, correspondents and headings as printed | 3.17 | heading and dateline text | no, if the dateline is attached to the document | **buildable now** in the as-printed form |""")
once("""The citation note and Chronology rows (3.17).""", """The citation note and Chronology rows, as printed, with the dateline attached to the document (3.17).""")
# E8 band keys
once("""From 1910 on, 76.0% use the parenthesised-name form (MEASURED, VSI).""", """From 1910 on, 76.0% use the parenthesised-name form (MEASURED, VSI; by TEI document year).""")
once("""Untagged 1861–1899 from/to heads are 95.7% bare honorifics, and 1.3% name a post;""",
"""Untagged 1861–1899 from/to heads, by TEI document year, are 95.7% bare honorifics, and an office word appears in at most 1.3%;""")
# E9 labels
once("""(Sonnet $10 / Opus $24 central, INFERRED, RC [R])""", """(Sonnet $10 / Opus $24 central, batch+cache, low effort; INFERRED, RC [R])""")
once("""Sonnet $137 / Opus $325 central (INFERRED, LP `cost-scale/costs.json` via RC [R])""", """Sonnet $137 / Opus $325 central (INFERRED; DOCUMENTED in LP `cost-scale/costs.json` via RC [R])""")
once("""**The 22,688 unresolved rows:** Sonnet $10, Opus $24, central (INFERRED, RC [R]).""", """**The 22,688 unresolved rows:** Sonnet $10, Opus $24, central, batch+cache, low effort (INFERRED, RC [R]).""")
# E10 3.3 cost
once("""| Cost | About 1 session on top of 3.2 (INFERRED, RA [R]) |""",
"""| Cost | Included in 3.2's 2–3 sessions for markup names (INFERRED, RA [R]). Detected names need a bundled per-document artifact and `xcodegen` (RA); not sized. |""")
open(P,'w',encoding='utf-8').write(s)
print('applied', n_ok)
