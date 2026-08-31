# Assessment: a local read-only tool surface for outside agents (W-19 row L-8)

**Status:** ASSESSED, 2026-08-31. Row L-8 of `Agentic-Loop-Development-Plan.md`, which enters as an
assessment ending in a build/no-build recommendation.

**Method.** A five-voice panel — a baseline auditor, an advocate for, an advocate against, a
technical scoping pass, and an MCP reality check — followed by an adversarial judge instructed that
a verdict of "it depends" fails the row. Every claim was required to carry `file:line` evidence or
be marked UNVERIFIED. The judge's job included finding where both advocates overreached, and it
found eight places; the corrections are folded in below rather than appended.

---

## The verdict

> **Build a narrower thing: a read-only command-line executable. Do not build an MCP server.**

Record L-8 as **ASSESSED — NO-BUILD (MCP)**, superseded by a CLI row.

---

## 1. The bar the row set for itself

L-8 was gated on L-1..L-4 for a stated reason: *"they are the cheap four-fifths of the value: if the
loop works well through files and affordances, the server must justify itself against that baseline,
not against today's folklore."*

**L-0 through L-7 have all shipped.** So the proposal may claim credit for none of: getting the
database out (L-2's backup + strip + rank-1 verify), handing candidates back (L-1's fixture-pinned
write-minimum), making a citation checkable (L-5's URL scheme), making a run citable (L-7's
research-state record), or reaching the embedder and full-precision vectors (L-4, L-6).

Six of the loop's seven steps are supported. **Three things remain**, and they are the whole of what
a tool layer could add:

1. **The resolution layer is committed and pathed, but never joined for the agent.** The database
   stores codes — `lot_file_norm`, `decimal_class`. Every resolution of a code into a shelf lives in
   bundled JSON the agent must locate, load and join by hand.
2. **The archival half of the method is measured at zero.** §14.11 of the guide records that three
   scoping runs — careful, adversarially re-checked, written up — resolved *zero* record groups,
   *zero* NAIDs, *zero* series titles, and opened one of fifteen archival artifacts, as a glossary.
   This is the panel's heaviest evidence because it is the one place the project has **measured**
   what its documentation achieves against careful agents, rather than inferring it.
3. **Of §12's ~40 house rules, exactly one is enforced by a mechanism** — L-2's privacy strip, which
   the server would not add.

### Does the build case clear it?

**The case for a constrained tool surface clears it. The case for MCP does not.**

Counting the enforceable fraction honestly: IDENTITY 3/3 and EXCLUSIONS 3/3 become structural (a
typed `(volumeId, documentId)` on the wire; no rowid; no column through which `summary_text` or
`note_text` can reach a model). Roughly 5 of 11 KNOWN TRAPS become structural by surface shaping
(`bm25` ASC, `citation_era` never exposed as a date, `reference_type` never exposed as a
body/footnote split, stems returned beside surface forms). ARCHIVAL gains 3–4 from a required
channel enum with no union value. SCOPING gains ~7 **only if the tool scans the TEI corpus** — see
§4.

**Call it 12–16 of 40, up to ~20 with a corpus scanner, against 1 today.** That is a real delta and
it clears the bar.

But every one of those guarantees is a property of **a fixed-subcommand binary**, not of a protocol.

---

## 2. Why the boundary falls where it does

**Every shipped row in this wave is protocol-agnostic** — a JSON file, a URL scheme, a SQL table, a
clipboard paste, an exported database, a model path. An MCP server would be the first artifact in
the wave that works only for users of MCP-capable clients. The gate asked the server to justify
itself against the files-and-affordances baseline; measured against a baseline that reaches *every*
agent, it would **narrow the audience** while adding this package's first external dependency across
94 targets (`Package.swift` declares zero) and walking into the entitlement corner Sparkle already
cost this project once.

MCP's distinguishing features — capability negotiation, a discoverable catalogue, a client-mediated
approval boundary — are for an agent talking to a service it does not own. Here there is one user,
one machine, and a snapshot that user personally exported to a path of their choosing.

**And the CLI loses nothing**, because an MCP stdio server *is* a subprocess speaking JSON-RPC on
stdin. The binary is the business logic; the protocol is a transport bolted on later if the
falsifier fires. Building the CLI first is not a compromise — it is the correct build order.

### The one point kept on MCP's side

A tool catalogue is re-presented every turn, where a 90-line pasted block can be forgotten or
truncated. That speaks directly to §14.11's *"the omission was invisible from inside the work."* The
mechanism is UNVERIFIED from this tree and external to it, so the verdict **discounts it rather than
dismissing it** — and it is precisely what the first falsifier below is designed to measure.

---

## 3. The four questions the row named

### Q1 — Process model: a separate executable, and in-app is *blocked*, not merely worse

Neither entitlements file grants `com.apple.security.network.server`, and `DistributionTests`'
sandbox-parity test forbids adding a capability to one configuration alone. So any listener means
shipping a listening-socket entitlement in an App Store submission — and a GUI app has no stdio for
a client to attach to.

Better than the panel first said: **the executable is not new work.** `RetrievalEvalHarnessCore`
already declares the exact dependency set, and `Package.swift` already carries 28 executables on a
uniform Core/executable/Tests shape.

### Q2 — Read-only: the exported copy, path required, no container default

Against the live store **both options fail silently**. `immutable=1` — what the existing harness
uses — does not read the WAL and returns stale-but-plausible numbers; plain `?mode=ro` needs the
`-shm` and can fail or depend on the app's state.

L-2's export is the only place the privacy decision has actually *executed*: a page copy through a
READONLY source connection so the WAL is included, then null → `DELETE FROM user_tags` → `VACUUM` →
rebuild both FTS tables in that order, then `quick_check` and rank-1 integrity. Require the path;
never default to the container.

### Q3 — Which tools first: six, with one correction and one promotion

Keep `coverage`, `search_documents`, `document`, `neighbors`, `archival_units`.

- **Correct `term_frequency`:** it must scan the TEI corpus, not `FTS5Vocabulary`. Porter stemming
  folds the guide's own worked split — `chiefs of mission` 1,687 / `chiefs of missions` 170 — into
  one stem, so a tool that *stated* the variant rule while running on stems would violate that rule
  in its own implementation.
- **Promote `archival_units` to first.** It is the only tool answering a **measured** failure rather
  than an inferred one, it is the only one the shipped baseline does not half-deliver, and it needs
  neither FTS nor vectors — just the committed artifacts, a required channel enum, and the envelope.

### Q4 — House rules as tool descriptions: the row's framing is wrong

**A tool description is prose with exactly the authority of §12's prose.** Only implementations
bind. Restated correctly, three mechanisms do real work:

- **The response envelope** — every result carries L-7's record fields plus volumes-indexed against
  552, the open mode, and the counting surface. **This is the one thing prose structurally cannot
  do:** §12 can *ask* for a denominator; it cannot *attach* one.
- **Absent capability** — no subcommand's `SELECT` names `summary_text` or `note_text`, so the
  researcher's own writing is unreachable rather than merely forbidden.
- **Required parameters** — an archival channel enum with no union value makes §14.11's
  never-sum rule structural instead of hoped-for.

---

## 4. Two things the row got wrong, recorded so the next reader is not misled

**Its scope cannot execute the rules the Plan of Record cites as its strongest argument.** The Plan
of Record names four (controls, counting surface, variant expansion, both archival channels). Three
run over the **TEI corpus**, not the index — §14.2's controls and §14.3's three counting surfaces
are file measurements, and §7.2 says outright *"If the distinction is load-bearing, parse the TEI."*
The fourth is **inexpressible on a porter-stemmed index**. The row's stated scope — `FTS5Store` +
`SemanticVectorsKit` — cannot do any of them. Any build must include the corpus scanner
(`GeneratorKit.VolumeCorpusEnumerator` already exists) or drop those rules from its claims.

**"House rules built into the tool descriptions" overstates what descriptions do.** See Q4.

### And one claim of the assessment's own that did not survive

The baseline auditor's headline — that the resolution layer is *unreachable* because the 34 bundled
artifacts live only inside the installed app bundle — is **refuted**. They are committed to a public
repository, and the guide states the installed path twice. The survivable claim is narrower and is
what this document adopts: the artifacts are reachable but **un-pathed where they are named**, and
§14.11's table lists fifteen files with no path at all.

---

## 5. What would change this verdict

**Flips to BUILD THE MCP SERVER:** evidence that the *delivery channel*, not the tool surface,
changes agent behaviour. Re-run §14's scoping protocol three times on one question with (a) the §12
block pasted and a shell, (b) the CLI plus a one-line pointer, (c) the same CLI wrapped in MCP — and
find (c) beats (b) on rule compliance by a margin surviving the run-to-run variance §14 already
documents. That is the only thing MCP is claimed to add over a binary, and nobody has measured it.

**Flips to BUILD NOTHING:** re-run §14's protocol with the §12 block pasted and find the archival and
scoping rules are *obeyed*. §14.11's zero was recorded **before** §12 carried an ARCHIVAL SCOPE block
at all. If the block alone fixes the failure it was written to fix, the honest answer is a docs pass
plus SQL views, not a binary.

**What does not flip it:** that MCP is convenient, that an SDK is official, or that a bundle installs
in one click. Installation convenience is downstream of whether the protocol adds a guarantee.

---

## 6. What to do, in order

1. **Run the falsifier before any code.** Re-run §14's scoping protocol on a fresh question with the
   §12 block pasted, and count which rules are violated anyway, by block. This repo settles hard
   calls by measurement — the `Ibid.` gap, 512-vs-256 dims, the NLTagger control. Do it here. **The
   rules that survive a paste need no tool; the rules that do not are the specification for the
   subcommands.** Watch the archival block especially: §14.11's zero predates it.
2. **Then build the CLI, `archival_units` first.** If the build stops after one subcommand, that is
   the one that justifies the row.
3. **Fix the two documentation defects this assessment exposed** (doc cost): put the artifact path
   in §14.11 and note the files are committed in the public repo; and add a **surface-routing table**
   to §12 saying which rules the database can answer and which need the TEI or the bundled JSON.
4. **Ship the cheap enforcement that needs no binary:** SQL views on the L-2 export pre-applying the
   EXCLUSIONS block and the Ed2 twin fold. It reaches `sqlite3`, Python, *and* the generic SQLite MCP
   server the guide already recommends — about 4 of 40 rules for statements in a tested function.
5. **Stamp the export.** It carries no provenance of its own, so an agent cannot tell a stripped copy
   from an unstripped one, and pairing L-7's clipboard record with the right file is the
   researcher's discipline. Write those fields into a table inside the copy, in the same act. XS,
   and it removes the exact failure §13 exists to prevent.
6. **Fix `README.md`'s build number** — seven builds stale on the public front door, on the page
   carrying the only link to the guide this whole wave serves.
7. **Do not let this displace Tier A §2a.** The store listing is the App Store critical path and two
   build-44 tester verdicts are outstanding. The CLI is small enough to interleave with Tier B; the
   MCP server was not, and that asymmetry is part of why it is refused.
