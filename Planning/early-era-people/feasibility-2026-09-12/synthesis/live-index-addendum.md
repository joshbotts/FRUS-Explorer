**Verified against the live index, 2026-09-12 (MEASURED, read-only `mode=ro` over
`~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db`,
552 volumes / 316,839 documents, every `document_revisions` row at index version 50).** The orphan rows
exist at runtime, and their count is the per-(document, ref) dedupe of the store's per-mention count:

| volume | documents | `persons` rows | `person_mentions` rows (distinct refs / documents) | rows joining to no `persons` row |
|---|---|---|---|---|
| `frus1932v04` | 794 | **0** | 2,552 (434 / 783) | **2,552** |
| `frus1918Supp01v02` | 912 | **0** | 2,114 (108 / 884) | **2,114** |
| `frus1917Supp02v02` | 459 | **0** | 864 (92 / 422) | **864** |
| sibling `frus1932v03` | 799 | 597 | 2,257 (308 / 781) | 0 |
| sibling `frus1918Supp01v01` | 927 | 267 | 2,477 (227 / 907) | 0 |
| sibling `frus1917Supp02v01` | 725 | 212 | 1,771 (172 / 705) | 0 |

So 98.6% of `frus1932v04`'s documents already carry an editor-asserted, identity-bearing person ref
that no surface can show, because the ref's `persons` row lives in the sibling part. Corpus-wide the
index holds **6,288** `person_mentions` rows joining to no `persons` row; **four** volumes carry
mentions and zero `persons` rows — the three above plus **`frus1873p1v2` (454 rows, 37 refs)**, whose
own 57-entry list sits under `xml:id="correspondence"`, a spelling #740's `personsSectionIds`
allow-list (`FRUSDocumentParser.swift:1477-1486`) does not carry, although its doc comment says both
1873 parts use `correspondents` (`frus1873p1v1` does and has its 57 rows). The remaining orphans
(`frus1969-76v14` 129, `frus1964-68v23` 53, …) are a different, smaller class not examined here.

**The app view today is therefore 267 volumes with zero `persons` rows, holding 198,936 documents**
— not the Program doc's 268 / 199,246 of 2026-08-07: `frus1873p1v1` has since gained its list (#740)
and nothing else moved. It is the same *count* as the TEI-rule 267 but a different *set*
(`frus1873p1v2` is in the app view and out of the TEI rule; `frus1941-43` the reverse).
