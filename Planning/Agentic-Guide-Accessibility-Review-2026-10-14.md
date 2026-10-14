# Agentic Analysis Guide — making the outputs readable by a historian with no technical background

**Status:** REVIEW, 2026-10-14. Recommendations only; nothing in the guide is changed by this
document. Written against `Docs/Agentic-Analysis-Guide.md` v1.28 (3,184 lines, `v2` @ `757c6d2`),
read whole, with four recorded outputs as samples: one in the repository
(`Planning/c2-long-session/memos/b1.md`, a scoping memo on fishing rights) and three the owner
supplied on 2026-10-14, the "starter kits" of the 2026-08-31 scoping runs §14 describes (Foreign
Service reform, 447 lines; wartime critical materials, 476; direct talks with Cuba, 317), each
with its archival addendum; the scoring rubric those runs were marked against
(`Planning/c0c-falsifier/RUBRIC.md`), the test that pins §15's example
(`CollectionTests.publishedExampleMatchesTheGuide`), and the previous revision pass
(`Planning/Agentic-Guide-Revisions-2026-09-04.md`), which was about correctness and did not take
up this question.

**The question.** The guide's "outputs" are what an agent hands back: the memo, the overview, the
`.fruscollection`, the query log and the run record (§13, §14.16, §15). Who reads them is the
historian who asked the question, and that person is usually not the one who ran the agents. The
review asks what in the guide shapes those outputs, and what would make them readable by someone
who does not know what a stem, a join or a denominator is, without weakening the audit discipline
the guide exists to enforce.

---

## 0. Verdict

The guide is an excellent operator's manual and its outputs are audit artifacts. It knows this:
§14.16 opens by saying a memo "is the wrong shape for the person who commissioned it" and
prescribes three artifacts, with the overview written to "answer the question". That section is
one of 3,184 lines, it binds reading rounds only, nothing in the §12 house-rules block asks an
agent for it, and the rubric that measures whether agents obey the block (24 items, C1 to P6)
scores none of it. So the historian-facing layer is a recommendation the operator may or may not
pass on, while the audit layer is a rule the agent is scored against. The outputs follow the
incentive.

The fix is not to simplify the audit rules. It is to open every output with a three-part bottom
line in plain language, each part carrying its evidence (R5), and to add a second register with its own rules,
its own place in the block, its own rubric items, and a glossary, so that every number has an audit
form in the memo and a reader's form in the overview, and the two are checked against each other.
Fifteen recommendations follow, in four groups: the reader-facing artifacts (§2), the house-rules
block and rubric (§3), the guide's own front door for a historian reader (§4), and worked examples
(§5). Each carries an effort mark: **S** an hour, **M** a day, **L** more.

---

## 1. What a historian meets today

The sample memo is better than the guide's rules require, and it still shows the five shapes that
lose a non-technical reader. Quoting it:

1. **Database identifiers where a citation belongs.** *"`frus1872p1` "Fisheries in waters adjacent
   to the British North American possessions" · `frus1880` "Alleged Outrage upon American
   Fishermen"…"* A historian cites *Foreign Relations of the United States, 1872, Part 1*; `frus1872p1`
   is the TEI filename. §8 requires the pair on every claim, rightly, but it does not say the pair
   is for the audit trail and the edition's title is for the reader.
2. **Query syntax as prose.** *"I ran a composite phrase query (`fisheries`, `"fishing rights"`,
   `"fishing vessels"`, … `"exclusive economic zone"`) over the full-text index"*. The reader needs
   "I searched for eighteen terms, from *fisheries* to *exclusive economic zone*; the full list is in
   the memo." The backtick list is the audit form, and it is the only form given.
3. **Rates to two decimals in a thirteen-row table, before any sentence says what the table means.**
   The memo's own reading of it, two paragraphs later, is the finding: "Two peaks … with a long
   trough in between … If you work from raw hit counts you will conclude the topic is a modern one;
   it is not." That sentence should come first and the table should follow, and §6.4's rule that
   a rate is "published beside the raw count, never instead of it" needs a reader's clause: in the
   overview, the comparison is written in words and the table is cited.
4. **Internal names.** *"I walked `volume_structures` (the TEI section tree for all 552 volumes)"*.
   The reader's form is "I read the editors' own chapter titles in every volume". The guide's §14.8
   says exactly that in prose; the memo wrote the table name.
5. **Precision the method does not support.** "1.6% of the 316,839 documents", "4.51%". §14.9 says
   a run "that publishes densities to two decimals owes the reader its denominator"; the reader's
   rule is simpler and is missing: round to what the comparison needs, and say the base in words.

Beyond the memo, the guide's own vocabulary is the obstacle. It uses *stem*, *FTS*, *join*,
*denominator*, *grain*, *apparatus*, *counting surface*, *literal share* (strict and tolerant),
*false friend*, *control*, *channel* (came-from and pointed-at), *Ed2 fold*, *rowid*, *NAID*,
*HMS/MLR entry*, *unclustered*, *Hamming distance*, *recall@10*, *provenance digest*, and for the
process *round*, *thread*, *modality*, *refuter*, *critic*, *harness*, *fleet* and *scope memo*,
and defines none of them in one place. Internal references leak into the prose as well: 85
occurrences of an issue number or an experiment code (`#1239`, `C-0c`, `W-19`) and 30 of
*refuter / critic / harness / fleet / modality*. An agent reproduces the register it is given.


### 1a. The three starter kits, read against the same five shapes

The kits are the outputs the guide's §14 was written from, and they are a more demanding test than
the fishing-rights memo because each is two documents at once: a findings report for the historian
and an instrument for the next operator (a "paste-in house rules" block of 70 to 130 lines, a
"loop" of moves, a provenance paragraph with the controls). All five shapes recur in all three.

| Shape | Foreign Service reform | Wartime materials | Cuba talks |
|---|---|---|---|
| Ids for citations | "`frus1977-80v28` is the anchor by a wide margin"; the only document cited anywhere is `frus1977-80v28/d166` | "Single densest file in scope: `frus1944v04`"; "`frus1945-50Intel` will distort any turf measure" | the nine-volume table carries titles (the right form) and the prose then uses ids throughout |
| Query syntax as prose | "`\bFSS\b` misses FSSO (111)"; "a 40-sample (seed 20260831)" | "A naive `digits.digits` regex silently deletes 9,256 notes"; "`type="index"` present in 98 of 99 volumes" | "`normaliz*` 224, `dialogue` 385"; "`back channel` (2) vs `backchannel` (23). Two tokens; porter stemming does not join them" |
| Precision before meaning | "five volumes holding 0.59% of the corpus carry 69.2%, and two volumes holding 0.15% carry 56.7%"; "2.96%, essentially identical to the control's 2.8%" | "0.57% (479 notes) name any non-State origin"; "roughly 55 notes in 84,009 (0.065%)"; "13.6% → 2.2% → 1.9%" | "2,823 (67.0%) resolve to a named archival collection — against a corpus baseline of 28.3%" |
| Internal names | "a div-scoped pass"; "the hit tested against its enclosing `<div type="document">` span" | "`manifest.dateRange.latest` is derived from document dates"; "`frus:doc-dateTime-min` is on every div" | "Your tags land in `document_cache.user_tag_ids`"; "50 nearest neighbors from `semantic-vectors-binary.bin`" |
| Unglossed terms | tag-stripped, word-bounded, HDBSCAN, apparatus, "Restricted-Partly", "UD-UP 61/62/63" | tag-stripped text-layer, letter-tolerant regex, "word qualifier", "entries A1 205A–S" | recall@10 of 0.851, Hamming distance, protecting powers, NAID, "Entry P-14" |

Three things the kits show that the guide alone does not.

**The reader's form already exists inside them, and it is their best writing.** Each kit's most
memorable sentence is in the register the review asks for: *"FRUS shows what State was told about
these agencies, never their records"* (materials, §0); *"The corpus contains departmental
administration in about the way an encyclopaedia contains an article about itself"* (reform, §0);
*"the record shows the option was declined here, on these stated grounds" — never "talks did not
happen because X"* (Cuba, §4); *"an analysis run over the print volumes alone and one run over
print + supplement are different analyses of the same question, 25 years apart"* (Cuba, §5);
*"That is where not to go, and it is as useful as the pull slip"* (reform, addendum). And the
reform kit's addendum does the rewrite itself: it takes the one-sentence verdict and says
**"Rewrite the headline verdict as three sentences, not one"**, giving the three. Those three
sentences are the overview's bottom line in the form R2 asks for. The kit arrived at the reader's
register by audit, at the end, as a correction; the recommendation is to require it at the start.

**The shelf is given in the form a historian can least use.** All three addenda deliver the most
valuable thing in the kit, the archival series that hold what FRUS did not print, as a table of
NAIDs, entry codes and access flags: *"27022977 · UD-UP 61/62/63/66/67/68 · 44 ft, 1955–1973 ·
Restricted-Partly"*. The reform kit's own prose, one paragraph later, says it better: *"Nine RG 59
series, 104.1 linear feet, 1955–1980, every one created by the Office of the (Deputy) Under
Secretary of State for Management. National Archives at College Park."* R5's rule is that
sentence first and the table in the memo; the Cuba addendum's *"one of them titled Backchannel
Messages"* is the kind of detail that belongs in the sentence.

**Two kinds of content the guide's §14.16 does not name, and the overview needs.** The Cuba kit's
§3, *"The definitional call only you can make"*, lists four readings of "direct talks" and says the
answer changes materially with each; its §4 turns an unanswerable negative into three kinds of
document the historian can be shown. Both are addressed to the historian, both are in plain prose,
and neither has a place in the overview template because §14.16 asks for findings, not for the
decisions a round needs back. They are R14 below. And every kit is addressed to two readers at
once: the operator who will paste its house rules and run its loop, and the historian who wants
the answer. The guide names the memo, the overview and the collection and never the kit, so the
kit became the memo and the overview in one file, with the house rules between the findings and
the archival answer. That is R15.

---

## 2. The reader-facing artifacts

### R1 — State the two-register rule once, and make it bind every round (S)

Add to §8, as its first paragraph, and repeat in one line at the head of §14.16:

> **Every number and every quotation exists in two forms.** The audit form (the query, the pair,
> the counting surface, the share with its denominator) lives in the memo and the log and is never
> dropped. The reader's form (a sentence in plain prose, a printed citation with a link, a rounded
> comparison with its base named) lives in the overview and the collection and never carries a
> number the memo does not. A round that produces only the first has not finished.

Today the three-artifact rule "applies to a reading round only" (§14.16). A scoping round should
owe a reader's form too, because a scope memo is the artifact a historian most often receives: the
sample memo *is* one. Say that a scoping round owes the memo and a one-page reader's summary
(R7), and a reading round owes all three artifacts.

### R2 — The overview gets a template, not just a description (M)

§14.16 item 3 describes the overview well (bottom line, body, methodological close) and then
leaves its form to the agent. Give it a fixed skeleton and three prohibitions. Skeleton:

```
# <The question, as asked>
## The bottom line
**1. What FRUS answers directly** — one paragraph: the finding, with the documents it rests on
   cited as the edition, and the size of the set in words.
**2. Where FRUS points for the rest** — one paragraph: the archival series the printed documents
   came from and the ones the editors cited without printing, each named as a series with its
   record group, entry, identifier, dates and access status; and which of the two channels each is.
**3. What this request cannot get from FRUS** — one paragraph: each part of the question the
   corpus does not hold, with what was searched to establish it (the terms, the volumes, the
   controls) and, where one exists, the shelf that holds it anyway.
**Scope** — two sentences: which volumes, how many documents, what was excluded, in words.
## Findings — three to six, each a heading, a paragraph, and one to three quoted documents cited
   as the edition (R3)
## How this was done — one paragraph a methods section would accept (R6)
## Read next — the collection, by name, and what the historian's additions would unlock
```

Prohibitions, stated as rules: **no SQL, no column or table name, no `volume_id/document_id`
string and no file path appears in the overview**; **no table whose header is a column name**;
**no number without its base in words** (R4). The memo keeps all of those. §14.16 already says
the overview "may not carry a number the memo does not"; add the converse check: every number in
the overview is traced to a memo line, and the trace is a table in the memo.

### R3 — Cite as the edition, link as the pair (S)

§8 says "Cite the printed edition, not the database" and, two paragraphs above, "Every claim
carries `(volume_id, document_id)`". Both are right and they are for different readers. Resolve it
in one rule:

> In the memo and the log, the pair. In the overview and the collection, the printed citation
> (*Foreign Relations of the United States, 1958–1960, Volume VII, Part 1, Document 12*) followed
> by the canonical URL, and, for a reader with the app, the `frusexplorer://` link. The manifest
> gives each volume's title (§5 already loads it); the printed document number is
> `document_cache.document_number`. Where the number is `NULL`, cite the document's header and
> date and say the volume prints no number.

Add `title` and `document_number` to §14.16's manifest-companion table, which today is "date, id,
header, URL". The companion is "what a historian actually reads first", the guide says; it should
read as a bibliography.

### R4 — Numbers in the reader's form: "N of M", rounded, with the base in words (S)

§12 already requires "N of M" and §6.4 requires rates beside raw counts. Add the reader's clause to
both and to §14.16:

- A proportion is written as a count of a named set: "about one document in seven among the 43
  volumes indexed", never "14.3%".
- A rate per 1,000 is written as a comparison: "the 1930s is the denser decade: about 9 documents
  in every 1,000 use the phrase, against about 8 in the 1940s, even though the 1940s has far more
  documents". The per-1,000 figures and the denominators go in the memo.
- Round to the precision the comparison needs. Two decimals in prose are a claim of precision the
  method (§14.3's 14% surface spread; §7.1's literal shares) cannot support.
- A floor is said to be one: "at least 1,000 documents", as the app's own method appendix prints a
  capped count (manual §17.6).
- A number that is a bound carries its direction: "a lower bound, because tagging is uneven"
  (§7.5), in those words.

### R5 — The bottom line is three findings, each with its evidence, and it comes first (S)

Every output, a scoping memo as much as an overview, opens with three plain-language paragraphs in
a fixed order, and each paragraph carries the evidence its claims rest on:

1. **What FRUS answers directly.** The finding, in the historian's terms, with the documents it
   rests on cited as the edition (R3) and the set sized in words (R4). A claim here with no cited
   document is not a finding and does not go here.
2. **Where FRUS points for the rest.** The archival series the printed documents came from and
   the series the editors cited without printing, kept as two lists because they answer two
   questions (§8, §14.11), each series named as a researcher would write it to an archive: title,
   record group and entry number, catalog identifier, date span, access status. The Cuba kit's
   addendum is the model for the second list: *676 footnote pointers into 61 archival units, 15 of
   which the source notes never name*, led by the Carter Library's National Security Affairs
   files. The evidence is the count of citing documents or footnotes behind each series, in words.
3. **What this request cannot get from FRUS.** Each part of the question the corpus does not
   hold, stated as a search that was run and found nothing, with the terms, the volumes and the
   controls that make the zero a measurement (§14.2, §14.6), and, where the shelf exists, where
   it is anyway (§14.11's rule that a corpus negative is not a research negative).

§14.16 already puts the negatives in the bottom line; what it lacks is the second paragraph as a
finding in its own right and the evidence rule on all three. The claimant tables, the date-span
screens and the resolution queries stay in the memo. Point the historian to **Research ▸ Archives
Visits** for the advance-inquiry draft rather than reproducing it.

### R6 — The methodological close is a methods paragraph, and the log is the app's own shape (M)

§14.16's "short methodological close" is described as "what kinds of query proved useful". Give
it the form a journal's methods section would accept, in five sentences: what was searched (in
words), over what (volumes and documents, in words, with the exclusions), with what checks (the
positive and negative control, the literal-share reading, the five documents opened in the app), what
was not done, and where the full record is. Then make the full record recognisable: the app exports
a query log as a **method appendix** (manual §17.6: one row per search, its scope, the volumes
indexed at the time, what it returned, with `count_basis` saying whether a count is a floor).
Require the agent's `queries.log` to be summarised into that same table shape for the historian,
with the raw log beside it. A historian who has exported their own appendix will read the agent's
without instruction.

### R7 — The collection is an annotated reading list, not a bare one (M)

§15.1 says that for a candidate list "you want the first two" entry kinds, `document` and
`heading`. The format also carries `prose` (a plain `text` body) and `excerpt` (a frozen passage
with its `volumeId`/`documentId`), and the app renders both in the editor, the preview and every
export (manual §12.3, §12.4). Recommend that a reading round write:

- one `prose` entry under each heading saying, in two or three sentences, why these documents and
  what thread they follow, so the collection carries the overview's argument into the app;
- an `excerpt` entry for each quotation the overview relies on, which is the passage §8's machine
  check already verified, so the reader meets the quotation beside its document rather than in a
  markdown file;
- a closing `prose` entry naming the threads the round could not follow, which §14.16 asks for
  "so an addition has somewhere to attach".

Two cautions. The §15.1 JSON block is pinned byte-for-byte by `CollectionTests`; add the prose and
excerpt guidance as a new §15.1a with its own example rather than editing the block. And an
excerpt makes the file `formatVersion 2` (the format's own history says so), so §15.3's advice to
write `formatVersion: 1` needs a sentence for that case.

### R14 — "Decisions this needs from you" is a required part of the overview (S)

Add to the template in R2, between the bottom line and the findings, a short section the Cuba kit
already models: the definitional choices the question leaves open, each as one sentence with the
consequence of each choice stated ("counting the anti-hijacking talks as direct talks adds a
continuous record from 1969; excluding them leaves three episodes"), and the inclusion rule the
round used meanwhile, in words. A historian reads this before the findings because it tells them
what the findings are findings about. The §12 block's SCOPING section already asks the agent to
write the inclusion rule before the first query; this is the same rule handed back.

### R15 — Name the kit as a genre, and keep it out of the overview (S)

The three starter kits are a fourth artifact: an instrument for the next operator, carrying the
question's house rules, the measured decoys, the volume family and the loop. The guide should say
so in §14.16, with one rule: **a kit is written for the operator and is never the artifact the
historian receives.** Its §0 verdict and its addendum's shelf are lifted into the overview in the
reader's form (R2, R5); its house rules, its false-friend tables with their seeds and samples, and
its loop stay in the kit. The one thing a historian should see of the kit is its "moves" that are
theirs to make in the app (the Cuba kit's "Curate (app). Read 20–40 documents from the four
clusters and tag them"), rewritten without the table names, as a closing "What you can do next in
the app" paragraph of the overview.

---

## 3. The house-rules block and the rubric

### R8 — A READER-FACING OUTPUT section in the §12 block (S), and three rubric items (S)

The block is what agents actually obey (C-0b measured 100% against a 77.6% control, and the
2026-09-04 pass warned that each added line costs attention). Twelve lines, placed after REPORTING:

```text
READER-FACING OUTPUT — the overview and the collection are for a historian, not for me
- Write the overview in plain prose. No SQL, no table or column name, no volume_id/document_id
  string, no file path, no issue number. Those belong in the memo, which keeps every one.
- Cite as the printed edition — "Foreign Relations of the United States, 1958–1960, Volume VII,
  Part 1, Document 12" — then the history.state.gov URL. The id pair is for the memo and the log.
- Give every number as a count of a named set in words ("about one document in seven among the
  43 volumes indexed"), rounded to what the comparison needs; put the exact N of M, the rate and
  the denominator in the memo and say "see the memo" once, not at every number.
- Open with three paragraphs, in this order, before any finding: (1) what FRUS answers directly,
  with the documents cited; (2) where FRUS points for the rest, the series the documents came
  from and the series the footnotes cite unprinted, as two lists, each series by title, record
  group and entry, NARA identifier, dates and access; (3) what this request cannot get from FRUS,
  each as a search you ran, with its terms, volumes and controls, and the shelf if one exists.
- Every quotation in the overview is one the memo verified against its document; every document
  the overview cites is in the collection. Check both before you finish, and say you did.
- Explain a technical term the first time it appears, in the sentence, or do not use it: "the
  index treats 'clearing agreement' and 'clear agreement' as the same words", not "stem".
```

And three rubric items, so the register is scored like the rest:

| id | block | item |
|---|---|---|
| O1 | READER | The overview contains no SQL, column or table name, id pair or file path. |
| O2 | READER | Every number in the overview is a count of a named set in words, and traces to a memo line. |
| O3 | READER | The overview opens with the three-part bottom line: answered directly (documents cited), pointed at (series named, by channel), not answerable (the search that established it). |

Measure the block's length cost the way C-0c did before adopting it: the section above is twelve
lines against a block that stands at 187 today.

---

## 4. The guide's front door for a historian

### R9 — A "two readers" note after the preamble, with a reading path (S)

The guide's preamble names one reader: a researcher who will "point Claude, ChatGPT, Gemini, or a
comparable agentic tool" at the index. A second reader commissions or receives the work and will
never open a terminal. Add, after the preamble:

> **If you will read the results rather than run the agents**, you need six sections and no SQL:
> §1 (what the database is and is not), §10 (what FRUS is, as evidence), §14.16 (what a round owes
> you), the glossary, §9's five checks you can do in the app, and §14.13 (why *only*, *first* and
> *never* need a scope). Skip §2–§7, §12, §13 and the appendix. Hand §12 to whoever runs the agents.

### R10 — A glossary (M)

One table, before the version history, each term in one sentence a historian can use, with the
section that explains it. Draft of the entries the guide most needs; the operator's terms are
included because they appear in the outputs:

| Term | What it means here | See |
|---|---|---|
| index, full-text index | The app's search copy of the documents' text, built on your device; a search index, not the edition. | §1 |
| stem | The index stores each word's root, so *containment*, *contains* and *containing* are one entry, and a search for one finds all three. | §7.1 |
| literal share | Of the documents a phrase search returned, the fraction that actually use the phrase, found by reading a sample; "tolerant" allows inflections, "strict" does not. | §7.1 |
| false friend | A search term that measures the corpus, not the question, because it is common everywhere (*reform*, *Herter*). | §14.5 |
| control | A term searched beside yours to prove the search works: one that must be found (*Department of State*) and one that cannot be. | §14.2 |
| denominator, base | The set a count is a count of: "43 volumes", "dated documents of the 1930s". | §9 |
| grain | What one unit is: an occurrence, a footnote, a document, a volume. | §9 |
| apparatus | The editors' additions: front matter, editorial notes, footnotes, the index. Counted with the documents unless excluded. | §7.2 |
| counting surface | Which text was counted: the raw XML, the text with tags removed, or whole words; the three differ. | §14.3 |
| document date, volume year | When the editors say a document was written, against the years a volume covers; a periodisation must say which. | §14.7 |
| came-from, pointed-at | Where a printed document came from (its source note) against what a footnote cites and did not print; two channels, never summed. | §8, §14.11 |
| second edition, fold | Two volumes exist in two editions; a count drops one of them and says which. | §14.9 |
| volume id, document id | The database's names for a volume and a document (`frus1958-60v07p1`, `d12`); they resolve to a history.state.gov address and are not the citation. | §4.1, §8 |
| record group, entry, lot file, NAID | How the National Archives shelves State Department records: the record group (RG 59 is the Department), the series entry number staff use, the Department's own lot-file number, and the catalog's identifier. | §4.4, §14.11 |
| decimal class, subject-numeric file | The Department's two central filing systems: numbers like 611.41 to January 1963, letters-and-numbers like POL 27 VIET S after. | §4.4 |
| citation form | How a source note is written, which tells you the filing system and not the date. | §7.4 |
| person cluster | The app's grouping of one name across volumes, which prefers to leave two entries apart; a person's count is a floor. | §7.5 |
| subject tag | A label assigned by matching words, useful for finding and unreliable for counting. | §7.7 |
| semantic neighbour, map | Documents placed by the language they share; a lead to read, not evidence of a relation. | Appendix A |
| scoping, scope memo | The pass that decides which volumes and which words a question lives in, before anything is read. | §14 |
| round, thread | One pass of agents over the question; one line of inquiry within it. | §14.12 |
| refuter, critic | A second agent told to find the wrong number; a third told to say whether another round would learn anything. | §14.12, §14.15 |
| reading round | A round whose product is documents read whole and quoted, with the count of each. | §9 item 8 |
| method appendix | The app's export of every search run, with scope, date and result, as a table a paper can cite. | manual §17.6 |

### R11 — Rule first, evidence after, in §14 (L)

§14 is the guide's most valuable part and reads as a run log: a rule, then the measured episode
that produced it, often interleaved. Several subsections already lead with the rule in bold
(§14.6, §14.13, §14.15a). Make that the shape of every §14.x: the rule in one bold sentence at
the top, then a **Measured** paragraph with the episodes, then the recipe. The rules become
quotable into a reader's summary without the episode, and the episodes stay for the operator. This
is the largest edit here and touches no figure.

### R12 — Keep internal references out of the reader's path (S)

Issue numbers, experiment codes and index-version numbers are provenance and belong in the version
history and the memo. In the sections R9 names for the historian (§1, §10, §14.16, §9) move each
such reference into a footnote or the history entry. Elsewhere leave them: the operator needs them.

---

## 5. Worked examples for the guide

Three pairs, each from a number the guide already carries, to go in §14.16 as "the two forms".

**A rate.** Audit form (§6.4): *"commercial policy" runs 1930s 355 / 1940s 582 raw; per 1,000 dated
documents 9.06 / 7.86.* Reader's form: *More documents from the 1940s use the phrase "commercial
policy" than from the 1930s, 582 against 355. But the 1940s volumes hold nearly twice as many
documents. Measured against each decade's size, the 1930s is the denser decade: about 9 documents
in every 1,000, against about 8.*

**A literal share.** Audit form (§7.1): *"clearing agreement" 157 of 229 tolerant.* Reader's form:
*The search for "clearing agreement" returned 229 documents. The index treats "clear agreement" as
the same words, so we read a sample; about seven in ten used the phrase. Take 229 as an upper
bound, and the memo lists the sample.*

**A negative with its shelf.** Audit form (§14.11): *`Wriston` appears in 0 source notes against
38 full-text occurrences … nine RG 59 series, 104.1 linear feet, 1955–1980, three of them
Restricted-Fully.* Reader's form: *FRUS prints almost nothing on the Wriston reforms from the
Department's own files: the name appears in 38 documents and in no source note. The office that
made the reforms left records, though. Nine series of the Under Secretary for Management's papers,
1955 to 1980 and about 104 feet of them, are at the National Archives under Record Group 59; three
are closed. Their entry numbers and catalog identifiers are in the collection's closing note.*

**A superlative.** Audit form (§14.13): *"all 24 dated 1961–63" (nine were 1964–67).* Reader's
form: *Of the 24 documents on this thread, 15 date from 1961 to 1963 and nine from 1964 to 1967.*
The scope word the guide asks for is the sentence's own base.

Two more, from the starter kits, which are the outputs the guide's §14 was built from.

**A verdict.** Audit form (the reform kit, §0): *After correction, the whole reform vocabulary is
~1,740 occurrences across 552 volumes, of which five volumes holding 0.59% of the corpus carry
69.2%, and two volumes holding 0.15% carry 56.7%.* Reader's form: *FRUS prints very little on the
reform of the Foreign Service, and what it prints is in five volumes, all on the organisation and
management of foreign policy from 1961 to 1980, and two of the five hold more than half of it.
The series says almost nothing about the reforms of 1924 and 1931, or the Wriston reforms of the
1950s, in the words of their own time, and the memo shows what was searched to establish that.*

**A loop step for the historian.** Audit form (the Cuba kit, §6): *Curate (app). Read 20–40
documents from the four clusters and tag them with a project tag, e.g. `cuba-talks-seed`. Tag the
disposition documents from §4(a) separately (`cuba-talks-declined`). Two tags, because the agent
will treat them as two different ground truths. Your tags land in `document_cache.user_tag_ids`.*
Reader's form: *In the app, read twenty to forty of the documents the collection groups under the
four episodes and tag the ones that are really about a channel to Havana. Give a second tag to the
documents where an option to talk was put to a decision and declined. Keep the two tags apart: the
next round uses the first to find more like them and the second to answer why talks stopped.*

**A three-part bottom line, drafted from the Foreign Service reform kit.** The kit holds all three
parts, in §0, §7, §3 and its addendum, in that order and in the audit register. Assembled in the
reader's form:

> **What FRUS answers directly.** The series documents the debate over reorganising the Department
> and its personnel system from 1961 to 1980, and four episodes in it can be followed in the
> printed documents: the Herter Committee's implementation, with an itemised action-taken report
> in the 1964–1968 organisation volume; the Macomber programme, *Diplomacy for the 70's*, in the
> 1969–1976 organisation volume; the Murphy Commission, whose documents include a passage ranking
> six studies from Hoover in 1949 to Murphy in 1975; and the drafting of the Foreign Service Act
> of 1980, in the 1977–1980 organisation volume. Almost everything is in five volumes, and two of
> them hold more than half of it. A fifth, separate thread is the loyalty and security episode of
> the early 1950s, densest in the 1952–1954 volume on national security affairs.
>
> **Where FRUS points for the rest.** The documents the editors printed came, in 143 source notes,
> every one in those five volumes, from the records of the Under Secretary for Management. Those
> records survive as nine series at the National Archives at College Park, Record Group 59, 1955 to
> 1980, about 104 feet in all; three are closed and the rest partly restricted. The editors'
> footnotes also cite, without printing, the Executive Secretariat's National Security Council
> policy-paper files (Lot 63 D 351 and Lot 66 D 95, one series, entry A1 1586E), where the
> reorganisation decisions were recorded.
>
> **What this request cannot get from FRUS.** The reforms of 1924 and 1931 and the Wriston reforms
> of the 1950s are not documented here in their own words: searched across all 552 volumes, the
> Rogers Act is named four times, all in a 1976–1980 volume's footnotes and index; the
> Moses-Linthicum Act never; Wristonization never, and the surname only in passing. A search with
> the period's own vocabulary, civil service reform, found an 1871–1897 cluster instead, which is
> real and is not about the Foreign Service. The archives do not rescue the gap: the series above
> begin in 1955, and the bundled catalogue reaches almost nothing before 1940.

Every figure in it is the kit's own, and the memo holds the searches behind each sentence.

---

## 6. What not to change

- The audit rules in §8, §9, §12 and §14. They are the reason the outputs can be trusted, and the
  reader's form is derived from them, never the reverse. Nothing above removes a number from the
  memo or the log.
- §15.1's JSON block (pinned by a test) and the §12 block's existing sections (measured against a
  rubric). R7 and R8 add beside them.
- The guide's length. A historian reader is routed around it (R9), not given a shorter guide that
  would drift from this one.

## 7. Order and cost

1. R1, R3, R4, R5, R9, R12, R14, R15 — one sitting, prose only.
2. R8 — the block section and the three rubric items, then one C-0-style measurement before it is
   called adopted, since the block's length is the known cost.
3. R2, R6, R7, R10 — a day each; R7 needs a new §15.1a example that opens in the app, which is a
   test to add beside `publishedExampleMatchesTheGuide`.
4. R11 — the long one, and the one a historian would notice most after R10.

## 8. Open to the owner

- Whether the overview's citation form should be the app's own `CitationFormatter` output (the
  Department's recommended style, manual §11.1) rather than the longer form R3 drafts. The app's
  form is the one a historian already sees in the Cite sheet.
- Whether a scoping round should owe a collection as well as the one-page summary (R1). §14.16
  says no, because nothing has been read; the sample memo's chapter list argues for a collection
  of headings without documents, which the format allows.
- Whether O1–O3 join the block's measured rubric now or wait for the next field run.
