# The agentic loop — closing the two hand-offs between the app and an outside agent

**Status:** proposed, 2026-08-30. Written against the tree at `9760d2b` (build 44 on TestFlight,
index format version 47). This is **wave W-19**; its Plan-of-Record placement is **Tier A §2b of
`Plan-Of-Record-2026-08-28.md`** — *promoted 2026-08-31 from Tier D, which that document then
vacated, when #234's scoring lane was deferred.* Every code claim below was verified against the
tree at the stated anchors, not taken from a doc comment.

**One row has moved since writing.** L-0 called `Docs/Agentic-Analysis-Guide.md` v1.1; the guide
is now **v1.2** (PR #1137, 2026-08-31), which added §14 — the scoping method drawn from three
measured runs — and §14.11, the archival half, after an audit found all three runs had resolved
zero record groups and zero NAIDs. A.7's staleness is unaffected and still owed. But **§14.11
strengthens the case for L-8**: the rules a local read-only MCP server would enforce are now
written down and measured (controls on every scan, a declared counting surface, variant
expansion, both archival channels resolved and never summed), so that assessment now has a
concrete tool surface to weigh rather than a sketch.

**Why this document exists.** `Docs/Agentic-Analysis-Guide.md` (v1.1, with its Appendix A on the
semantic artifacts) documents how an outside AI agent reads `frus.db` and the vector layer. What
it documents is folklore: the researcher must know the sandbox path, know `.backup` over `cp`,
know the `rank`-1 integrity form, strip their own notes by hand, and bridge opaque tag ids by
memory. And the return trip barely exists — an agent's findings come back as text the researcher
re-navigates by hand. The working rhythm the guide enables — **curate in the app → compute over
the curation → adjudicate in the app → claim** — runs today on discipline instead of affordances.
This plan collects the app-side work that changes that, as one wave rather than scattered issues,
so the sequencing argument is made once.

**The two hand-offs, named.** Everything below serves one of them:

- **Outbound (app → agent):** getting the database, the researcher's curation, and the
  reproducibility facts out of the app safely and consentfully. Rows L-2, L-3, L-7.
- **Inbound (agent → app):** getting an agent's candidate lists and citations back into the app
  as first-class objects the researcher can adjudicate. Rows L-1, L-5.
- **Both directions ride the semantic layer:** L-4, L-6. L-0 is the correction that keeps the
  published guide true; L-8 is the strategic assessment.

**What this wave deliberately is not.** No CloudKit schema change anywhere in it — every row was
checked against the #488 gate and none adds or alters a `@Model` or a stored property (L-3 writes
a plain SQLite table on the indexing side). No new bundled resource except where a row says so.
No network service: the app stays local-first; even L-8 is an assessment of a *local* server.

---

## The rows

| # | Session | Hand-off | Size | Gate |
|---|---|---|---|---|
| ~~L-0~~ | ~~Guide correction: A.7 is stale since build 44~~ — **SHIPPED**, two sites not one | — | XS | — |
| ~~L-1~~ | ~~The `.fruscollection` write-minimum~~ — **SHIPPED** #1144; the guide's example is a test fixture | inbound | S | — |
| ~~L-2~~ | ~~Export Research Database…~~ — **SHIPPED** #1145; the strip needed a `VACUUM`, it was not an erase | outbound | S | — |
| ~~L-3~~ | ~~Mirror tag *names* beside the tag ids~~ — **SHIPPED** #1143; no index-version bump, and why | outbound | S | — |
| ~~L-4~~ | ~~Surface the embedder the app now ships~~ — **SHIPPED** #1146; digest unchanged, binary byte-identical | both | S | — |
| ~~L-5~~ | ~~`frusexplorer://` deep links~~ — **SHIPPED** #1149; the scheme was already live in-app | inbound | M | — |
| ~~L-6~~ | ~~Corpus-wide shard fetch (explicit opt-in)~~ — **SHIPPED** #1147; #926's refusal intact | both | S | — |
| ~~L-7~~ | ~~Copy research-state record~~ — **SHIPPED** #1148; answers §13's table, not the row's list | outbound | XS | — |
| ~~L-8~~ | ~~Local read-only MCP server — ASSESSMENT~~ — **ASSESSED 2026-08-31: NO-BUILD (MCP)**; superseded by C-0/C-1 below | both | M | — |

### L-0 — Guide correction: Appendix A.7 is stale since build 44

`Docs/Agentic-Analysis-Guide.md:1029` still says the app "never embeds queries, so there is no
in-repo reference for the query-side prompt." That was verified true against the pre-build-44
tree it was written on, and build 44's Search by Meaning (manual §7.11) falsified it: the app now
downloads the pinned EmbeddingGemma GGUF and embeds queries on-device through
`SemanticQueryEncoder.encodeQuery` (`FRUSExplorer/Semantic/SemanticQueryEncoder.swift:225`),
under the pinned prompt `SemanticQueryPrompt.queryPrefix = "task: search result | query: "`
(`SemanticVectorsKit/SemanticQueryPrompt.swift:30`). Rewrite A.7's caveat: the query-side prompt
is now in-repo and public; the remaining caveat (recall measured document-to-document, never for
text queries) stands. While in the file, note that the guide was documented against index format
version 46 and the tree is now at 47 — the guide's own §13 already tells readers to record the
installed version, so a one-line "written against v46" in the version history suffices; do not
chase the number.

### L-1 — The `.fruscollection` write-minimum: spec + conformance fixture

**The keystone, and mostly documentation.** `NativeCollectionFormat.swift` already defines a
versioned, tolerant-reader, plain-`Codable` format whose documents are portable
`volumeId`/`documentId` pairs, explicitly built to reconstruct on another device with missing
volumes offered on open (its own header, and the format's version history 1.0 → 2.3). An agent
that can *write* a minimal valid file turns its candidate list into an editable collection the
researcher double-clicks — the inbound hand-off closed with near-zero app code. The same file
exported *out* of the app is a curated set the agent can read, so one spec serves both
directions.

Deliverables: (a) a **write-minimum spec** — the exact keys a v1-floor file needs
(`formatVersion`, entries of kind document with `volumeId`/`documentId`, optional headings and
prose for grouping), published as a short section in `Docs/Agentic-Analysis-Guide.md` so it lives
where its audience already is; (b) a **conformance fixture test** in `FRUSExplorerTests` that
decodes a hand-written minimal file byte-for-byte matching the spec's example, so the promise
cannot silently break when the format bumps — the tolerant reader's floor (`minimumReaderVersion`
defaulted 1) is the compatibility contract, and the test pins it from the outside; (c) one
optional format addition, **only if free under the floor**: an informational `generator` string
("who wrote this file"), an optional key a v1 reader ignores, so agent-authored collections are
distinguishable in provenance without a version bump.

### L-2 — Export Research Database…

A Settings action (Data & Recovery or Volumes & Storage) that does what the guide's §2 teaches by
hand: run SQLite's backup into a user-chosen destination (`NSSavePanel` / `fileExporter`), WAL
checkpointed, then verify with `quick_check` plus the `rank`-1 FTS5 `integrity-check` the app
already runs (`IndexingPipeline.swift:1771` — the form measured to actually detect content
drift). One checkbox: **"Include my notes, summaries, and tags"** — default OFF, and when off the
export runs the guide's §11 strip (`summary_text`/`note_text`/`user_tag_ids` nulled, `user_content`
rebuilt) on the copy, never the live store. The consent decision the guide argues for becomes UI
instead of SQL the user must remember. The source URL is `makeDatabaseURL()`
(`FRUSExplorerApp.swift:2629`); the app owns the connection, the busy-timeout discipline, and the
integrity code already, so this is assembly, not invention. Disable the action while indexing is
active, the same interlock `IndexHealthView` applies to its integrity button.

### L-3 — Mirror tag names beside the tag ids

`document_cache.user_tag_ids` holds opaque SwiftData identifiers; the names live only in
CloudKit-synced models, invisible to any agent. The sync that writes the assignments already
exists — `FRUSExplorerApp.swift:2769`'s `DocumentTagAssignment` → `user_tag_ids` pass — so the
change is one more table written in the same pass: `user_tags(tag_id TEXT PRIMARY KEY, name
TEXT)`, replaced wholesale on each sync. Suddenly "documents I tagged *escalation-rhetoric*" is a
self-describing join instead of a bridge the researcher keeps in their head, and the guide's
supervised-corpus-building pattern loses its one rough edge. SQLite-side only: **no `@Model`
change, no CloudKit deploy** — the names are already synced by CloudKit in their own model; this
mirrors them into the index the way the assignments already are. Add the table to the guide's
schema reference in the same session.

### L-4 — Surface the embedder the app now ships

Build 44 put the exact pinned GGUF on the user's disk (`SemanticModelStore`, integrity-checked by
length + SHA-256 at adoption) and the query prompt in public code. Two small affordances make
that reusable by an agent instead of re-downloaded and guessed at:

- **a.** In Settings → Volumes & Storage → Natural-Language Search: a "reveal model in Finder" /
  copy-path affordance (macOS; iOS shows the path read-only). An agent then loads the same
  weights the app validated, instead of fetching 229 MB and trusting a URL.
- **b.** Publish `queryPrefix` in `semantic-vectors-index.json`'s provenance block as an
  **informational field beside `harvestGenerated`** — deliberately NOT in the digest's canonical
  string (`SemanticVectorsArtifacts.Provenance.digest` concatenates model → quantization; adding
  a published-but-undigested field changes no artifact's identity, the same treatment
  `harvestScriptSHA256` already gets). The parity fixture generator
  (`tools/semantic-harvest/make_query_parity_fixture.py:34`) already emits the prefix; this makes
  the artifact self-describing without invalidating any shipped generation. Requires re-emitting
  the index JSON via SemanticVectorsGenerator with `DIMS=512` — the CLAUDE.md warning about the
  256 default applies in full.

### L-5 — `frusexplorer://` deep links

There is no custom URL scheme today (`project.yml` declares no `CFBundleURLTypes`; the only
`onOpenURL` route is `.fruscollection`). Add `frusexplorer://document/<volumeId>/<documentId>`
routed through the existing document-window plumbing on both platforms, so every line of an agent
dossier is one click from the app's rendered document — the audit surface the whole loop argument
rests on. Malformed or unknown ids degrade to a clear "not in your library" state offering the
volume download, mirroring Meaning search's beyond-library rows. **This row touches
`project.yml`** and therefore pays the house ritual: `xcodegen generate` followed by
`git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`. Scope the scheme to the
document route only; a grab-bag of routes can come later if anything needs them.

### L-6 — Corpus-wide shard fetch, as an explicit opt-in

Tier-2 shards exist only for downloaded volumes, so an agent gets exact int8 rerank only where
the library reaches; everywhere else it is Tier-1 Hamming only. #926 deliberately refused a
corpus-wide *missing count* ("published − onDisk would tell a 12-volume library it was missing
544") — and this row does not relitigate that refusal: the automatic paths and the default count
stay exactly as shipped. What it adds is one **explicit button** in `SemanticStorageSection`
("Download all vectors — 552 volumes, ~162 MB"), stating its size up front, driving the existing
`SemanticShardFetcher`/`adoptShard(from:for:)` path volume by volume with the same
validate-before-keep rule. Pressing a button that names its cost is the consent #926's design
already treats as sufficient for the manual path. Report a count on completion, the shipped
pattern ("512 of 552"), and surface failures through the same `SemanticStorageReport` wording
rules — it may say what it noticed, never that nothing is wrong.

### L-7 — Copy research-state record

The guide's §13 reproducibility record currently requires SQL. `IndexHealthView` already reads
the installed index format version; add a **Copy research-state record** action beside the
integrity button that puts a small JSON on the clipboard: app build + version, installed and
current `currentDateIndexVersion` (`IndexingPipeline.swift:778`, 47 today), the indexed volume-id
list, the subject vocabulary digest (`document_subject_volumes`), and the semantic provenance
digest. One paste makes a machine-assisted run citable — the "Later" roadmap item of the guide's
companion proposals, delivered at XS cost because every ingredient is already in memory somewhere
in the app.

### L-8 — Local read-only MCP server — ASSESSMENT

The strategic item, and per this repo's convention it enters as an **assessment ending in a
build/no-build recommendation**, not a build: a local, read-only MCP server (macOS first)
exposing safe query / neighbor / dossier tools with the guide's house rules built in, so the
method survives contact with any agent rather than only a careful one. The assessment must
answer: process model (in-app server vs. a separate SPM executable reusing `FTS5Store` and
`SemanticVectorsKit` — the second keeps the sandbox story clean and the app untouched); the
read-only enforcement story (`mode=ro` URI on the exported copy vs. the live store — the copy is
the safe default); which tools are worth exposing first (the guide's §6 patterns are the
candidate list); and what the house rules look like as tool descriptions rather than prose.
Gated on L-1..L-4 because they are the cheap four-fifths of the value: if the loop works well
through files and affordances, the server must justify itself against that baseline, not against
today's folklore.

---

## Sequencing

L-0 ships immediately (it is a correctness fix to a published document). L-1, L-2, L-3 are the
wave's core and can ship as one session or three, in any order — together they take the loop from
"possible with folklore" to "supported." L-4 and L-7 ride along wherever convenient (L-4b shares
a session with any vectors-index re-emit). L-5 stands alone because of the xcodegen ritual. L-6
is independent. L-8 waits for the rest by design.

*(Sequencing note corrected 2026-08-31: this paragraph used to say "nothing here jumps the Plan of
Record's queue: Tier A (#234)…". The wave **is** Tier A now — §2b — after #234's scoring lane was
deferred when the NER harvest did not finish its week. The standing gates are still untouched and
every L-row is still sized to interleave with Tier B.)* The wave's one external dependency is the
guide itself, which this repo owns.

**L-0 SHIPPED 2026-08-31.** `Docs/Agentic-Analysis-Guide.md` is at v1.3. The correction was
**two sites, not the one this plan named**: §A.7's caveat, and Appendix A's opening frame, which
stated the same claim in stronger form ("the app itself never embeds free text") and which an agent
reading top-down would have hit first. Both now name
`SemanticQueryPrompt.queryPrefix = "task: search result | query: "` and keep the
document-to-document recall caveat explicitly unrepaired. The index-format note landed in the
version history as this row prescribed: written against 46, tree now at 47, record your own.


---

## The wave is complete — and what replaced its last row

**L-0 through L-7 shipped** (PRs #1142–#1149). The loop the guide describes now runs on affordances
rather than folklore: an agent can write a collection the researcher opens, read tag names instead
of UUIDs, be handed a verified and consentfully-stripped database in one action, reuse the model
weights the app validated under the prompt the artifact publishes, rerank the whole series, cite a
run reproducibly, and emit a link that opens the rendered document.

**L-8 was assessed and refused.** `MCP-Server-Assessment-2026-08-31.md` carries the reasoning; the
short form is that the gate did its job. Measured against the baseline the other seven rows built —
rather than against the folklore L-8 was scoped in — an MCP server would have been **the first
artifact in this wave that works only for users of MCP-capable clients**, narrowing the audience
while adding the package's first external dependency across 94 targets. Everything MCP would have
carried, a fixed-subcommand binary carries too; an MCP stdio server *is* a subprocess speaking
JSON-RPC on stdin.

Two of the row's own premises did not survive: its stated scope (`FTS5Store` + `SemanticVectorsKit`)
cannot execute three of the four rules the Plan of Record cites as its strongest argument — those run
over the TEI corpus — and the fourth is inexpressible on a porter-stemmed index. And "house rules
built into the tool descriptions" overstates what descriptions do: a description is prose with
exactly the authority of §12's prose. Only implementations bind.

### C-1 — the read-only CLI, gated on a measurement

| # | Session | Size | Gate |
|---|---|---|---|
| C-0 | **Run the falsifier**: re-run §14's scoping protocol with the §12 block pasted and count which rules are violated anyway, by block | S | none |
| C-1 | The read-only CLI, `archival_units` subcommand first — the only tool answering a *measured* failure | M | C-0 |

**C-0 is not ceremony and must not be skipped.** §14.11's zero — three careful runs resolving no
record groups and no NAIDs — was recorded *before* §12 carried an ARCHIVAL SCOPE block at all. If the
block alone fixes the failure it was written to fix, the honest answer is a docs pass and SQL views,
not a binary. The rules that survive a paste need no tool; the rules that do not **are** the
subcommand specification.

### Residue this assessment exposed, none of it gated on C-1

- §14.11's artifact table names fifteen files with **no path**; the bundle path is stated only in §5
  and §A.1. Put it in §14.11 and note the files are committed in the public repo. *(Doc, XS.)*
- Add a **surface-routing table** to §12: which rules the database can answer, and which need the TEI
  or the bundled JSON. *(Doc, S.)*
- **SQL views on the L-2 export** pre-applying the EXCLUSIONS block and the Ed2 twin fold — ~4 of 40
  rules, reaching `sqlite3`, Python and the generic SQLite MCP server the guide already recommends.
  *(S.)*
- **Stamp the export.** It carries no provenance of its own, so a stripped copy is indistinguishable
  from an unstripped one. *(XS, and it removes the failure §13 exists to prevent.)*
- `README.md` states build 37 against `project.yml`'s 44 — seven builds stale on the public front
  door, on the page carrying the only link to the guide this wave serves. *(XS.)*
