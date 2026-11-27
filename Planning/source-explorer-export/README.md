# `source-explorer-export/` — the export of 2026-11-26, at row L31

`source-explorer-export-summary.json` and `source-explorer-export-sample.json` are the committed part of a
`SourceExplorerExportGenerator` run (#335), made for row L31 of the plan of record from 2026-11-25 (#1975,
#1976, #1974) with the stamp `GENERATED_DATE=2026-11-26`. They replace the snapshot of 2026-07-29, which
nothing had kept current and which recorded nothing of the indexes it read.

**What it read.** The corpus at `~/Development/frus` `216cdb764` (its `volumes/` is `6170e4b32`'s); the 553
volumes of `FRUSExplorer/Resources/manifest.json` (191 files of the corpus are outside it and skipped); and
the bundled `central-files-index.json`, `volume-sources-index.json` and `collection-authority.json` as L26's
merge left them (`bbe6686c`, index version 76), which L31 does not change. 264,736 records, one for each
source note.

**A record's year, since L31,** is the one Source Explorer gives the document (#1976, decision 175): its
dateline's, by the one rule the app reads a dateline by (#1975), else the document's own date as the index
stores it. The generator parses each volume with FRUSCoreKit, as the index does, and asks the kit for the
year (`SourceExplorerDocumentContext.year(of:)`); until L31 it read the first four digits of
`frus:doc-dateTime-min`. The year opens the 1906–1910 Numerical File's window and files the record under its
decade. **The Numerical File's case number, since L31,** is read by the kit's rule (SourceNoteKit's
`NumericalFileCitation`, #1974), so a citation in the decimal file's form names no case and lists no roll.

**What moved, and why.** A control of the unchanged generator at `bbe6686c`, over the same inputs with the
same stamp, came first, so that each issue's count is its own and not #1854's (L26 gave the export 138 more
notes, and four months of the corpus and the indexes moved the rest):
- the control against the July snapshot: 264,736 records where it had 264,464, and 553 volumes where it had
  552; `resolvedVolumeSources` 198,886 → 199,700, `resolvedLotBundle` 8,974 → 9,057, `liveRouteOnly`
  41,071 → 40,611, `noResolution` 12,750 → 12,585, `resolvedNumericalFile` 2,783 both;
- #1975 alone moves no record: the export read no dateline before #1976;
- #1976: 141 records change year, 23 of them decade: 127 to the year their dateline prints, 11 to the editors' bracketed year, and 3 to the index's own day where `frus:doc-dateTime-min`'s first four digits are the year before (#1326's instant). Two of them cross the 1906–1910 window: `frus1910` d91 leaves it for its dateline's 1914 and loses its roll, and `frus1914` d602 enters it at its dateline's 1907, where its decimal citation `711.654` read as case 711;
- #1974: 335 records lose a wrong case's rolls for the coverage gap and resolve through the volume-sources index instead: the 334 decimal-form citations in the window at the control's years, and `frus1914` d602, which #1976 brought into it.

At L31 every record's year is the year Source Explorer hydrates for its document from a full v76 index of the
same corpus: 264,736 of 264,736, where at the control 157 differed and 8,033 had none in Source Explorer.

**What is here, and what is not.** `source-explorer-export.json`, the full export (about 180 MB), is
gitignored and exists only on the machine that last ran the generator. Re-run the generator rather than build
anything from a kept copy: it is offline and deterministic, and the authority's ids do not survive between
its runs (the rule in the runbook's `CollectionUsageIndexGenerator` entry). The run's inputs, environment and
measured figures are in `Planning/Generators-Runbook.md`, under `SourceExplorerExportGenerator`.

**The two ranked lists are not the generator's.** `missed-lots-ranked.tsv` (2026-07-29, #563) and
`library-collections-ranked.tsv` (2026-08-05, #691) are curation worklists that sessions built from the
export of their day, the first by the `jq` recipe in `Planning/Completed/352-lot-resolution-runbook.md`; no
recipe for the second was recorded. They rank lot files and library collections, which no change of L31
reaches, and they were not rebuilt, so they describe the export of their own dates.
