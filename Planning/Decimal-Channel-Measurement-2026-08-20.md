# #834 decimal channel — the measurement gate

Measured 2026-08-20 over all 552 shippable volumes by `DecimalChannelMeasurement`
(`MEASURE_DECIMAL=1 swift run -c release ExternalCitationIndexGenerator`). Artifacts:
`decimal-channel-measurement.json` (the report) and `decimal-channel-measurement-sample.json`
(820 reviewable candidates). **Nothing here changes a bundled artifact, an app struct, or the
database schema.** This is commit 1 of #834's four, and it exists because the issue makes two
measurements binding before any harvest.

---

## 1. The headline: the mandated rule cannot reach the era the issue is for

#834 requires *"anchor-first grammar only; never route through `decimalClassLocation`"*, where an
anchor is a self-identifying **repository phrase**. `CollectionKeying.centralFilesAnchorSegment`
implements that, matching `central files` and `central foreign policy`.

| band | volumes | `namesRepository` candidates |
|---|---|---|
| before 1910 | 81 | **0** |
| **1910–1945** | **159** | **0** |
| 1946 and later | 312 | 10,885 |

**Zero.** Those phrases are post-war naming; the pre-war footnotes the issue exists to reach are
spelled `File No. 763.72/10417` or bare `793.94/9732`. The mandated rule is not merely weak
pre-war — it returns nothing at all, in 159 volumes over 159,371 footnotes. #834 cannot be
delivered under its own stated constraint, and no amount of grammar work changes that.

## 2. A rule the issue never named does reach it

Reading the shape-only rule's samples (which is how both `Ibid.` defects in the lot/library channel
were found) showed the discriminator: FRUS writes a complete central-file citation as
**class + document serial** — `793.94/9732`, `185.1521/69`. The class names the file, the serial
names the paper in it. That is self-identifying without any label, and it is what separates a real
citation from a number in prose: shape-only reads `771` out of *"total, 771,967"* and `500` out of
*"quota of 2,500,000"*, and neither carries a serial.

### 1910–1945 (159 volumes, 159,371 footnotes)

| rule | candidates | own-class | **external** | citer unclassed | keys |
|---|---|---|---|---|---|
| `namesRepository` — **the mandated rule** | 0 | — | **0** | 0 | 0 |
| `namesFileNumber` — the `File No.` label | 672 | 76.0% | 152 | 38 | 310 |
| `carriesSerial` | 4,718 | 74.5% | 1,059 | 566 | 1,543 |
| `carriesSerialComposing` — **recommended** | 4,276 | 75.8% | **941** | 393 | 1,359 |
| `anySelfIdentifying` | 4,828 | 74.2% | 1,096 | 573 | 1,588 |
| `shapeOnly` — contaminated, never a proposal | 10,293 | 52.3% | 4,186 | 1,526 | 2,563 |

`carriesSerial` at 4,718 is close to the issue's claimed 4,877 pre-war footnotes, which suggests
that figure came from a proxy regex of roughly this shape. **It is a candidate count, not a yield.**

## 3. Three quarters of the channel is documents citing their own file

`FootnoteCitationGrammar`'s doc comment records **56%** of decimal footnote hits as the citing
document's own class. That figure has no reproducible basis in the tree — no data file, no test,
and the rule that produced it is unrecorded — so it was treated here as unmeasured. Measured now,
through `ExportClassification.derivedKeys`, the identical call `ProvenanceFlowIndexRunner` uses:

| rule | own-class share (corpus) |
|---|---|
| `namesRepository` | 64.7% |
| `namesFileNumber` | 75.1% |
| `carriesSerial` | 68.8% |
| `shapeOnly` | 60.2% |

**The 56% understates it.** Pre-war it is 74–76%. A same-class reference is the document restating
its own provenance, not pointing outside itself — so on the recommended rule the pre-war channel is
4,276 candidates yielding **941 genuinely external references**.

`citerUnclassed` is counted separately throughout and is *not* folded into "external": the citing
document having no class of its own is not evidence either way, and merging it would inflate the
channel's apparent worth by 393 pre-war references.

## 4. The denominator question is settled

A #834 comment reported its own scan counting 579,563 footnotes against
`DocumentFootnoteExtractor`'s 470,827 over the same 552 volumes, called the 23% gap unexplained,
and instructed that no figure reach shipped copy until re-derived through the real extractor.

This pass runs through `DocumentFootnoteExtractor` and counts **470,827** — the extractor's own
number, exactly. The 579,563 figure does not reproduce here and needs no reconciliation: it appears
to be a property of that scan, not of the extractor.

## 5. Two rejected discriminators, priced rather than abandoned

- **Require a dot.** A first pass read the serial rule's dotless hits as false positives. **That was
  wrong, and the owner corrected it**: dotless decimal file numbers are real, the parser admits them
  deliberately, and `222` composes as *Extradition / Ecuador*. Measured, the dot discards 326 of
  4,718 pre-war candidates and only 28 external ones — it buys almost nothing and costs real keys.
- **Shape alone.** 10,293 pre-war candidates, but 52.3% own-class and visibly contaminated by prose
  numbers. `decimalClassLocation`'s own contract says callers must gate by classification first;
  this is what skipping that gate costs.

## 6. Composition, and what it cannot claim

`carriesSerialComposing` tests each key against the State Department's own 1910–1949 schedule as
parsed by #828 into `decimal-class-labels.json` — class digit + country number, the filing system's
own grammar. It drops 442 of 4,718 pre-war candidates (9.4%) and 118 external ones.

**Two limits bound what that number means.** The shipped country table is known incomplete — #828's
analysis measured ~290 distinct 1910–49 codes against the 198 that shipped — so a key that fails to
compose is **not** thereby proven false, and some of those 118 are false negatives. And **no
schedule ships for 1950 onward** (parsed, measured, deliberately skipped because the classification
was renumbered in 1950), so the post-war `carriesSerialComposing` row tests keys against a schedule
that does not govern them and is **uninterpretable**. Read composition for the pre-war band only.

## 7. What this settles, and what still needs an owner decision

**Settled:**

- #834's premise **holds** — the pre-war band is reachable — but at roughly **941 external
  references**, not 4,877. Against ~99 pre-war references in the shipped artifact today, that is a
  ~10× gain in the era the layer currently cannot see.
- The mandated anchor rule **must be relaxed** to a serial-carrying rule, or the issue delivers
  nothing. This is a change to #834's own constraint and needs recording as such.
- The denominator is `DocumentFootnoteExtractor`'s 470,827.

**Open — recommendations, not decisions:**

1. **Exclude same-class or flag it?** Own-class is 68–76%, well above the 34% same-unit share the
   shipped layer already tolerates. Recommend **flag**, following `ProvenanceFlowIndex`: same-unit
   flows are stored and excluded at display, *because an artifact that had already dropped them
   could not disclose what the exclusion removed*. Excluding at harvest makes the 75% invisible.
2. **Which rule ships** — `carriesSerialComposing` (941 pre-war external, best evidence) or
   `anySelfIdentifying` (1,096, includes non-composing keys the incomplete country table may be
   wrongly rejecting). The gap is 155 references.
3. **Subject-numeric** (`POL 27 VIET S`) stays out per #834; measured here at 395 of 34,893
   serial-carrying candidates corpus-wide, ~1 pre-war. Confirm it stays out.
4. Whether ~941 pre-war references justify commits 2–4 — a grammar change, an artifact schema bump,
   a class-keyed target axis, an `external_citations` column, and an **index-version bump 45 → 46
   with an owner-approved full reindex**. That cost is unchanged by this measurement; only the
   benefit is now known.
