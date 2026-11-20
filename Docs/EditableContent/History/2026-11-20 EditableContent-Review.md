# EditableContent: what changed since your close-out pass

*Prepared 2026-11-20. It compares `Docs/EditableContent/` at `95bfc706` (2026-10-01, #1544: “The owner’s EditableContent review ships in the app”, your 2026-09-30 review and close-out pass written back) with `v2` at `6f7f2046` (2026-11-20, #1957: 1.0 (1861)).*

**How to use it.** Every block is copied whole from its area file, between its `SOURCE` and `END SOURCE` comments, so you can edit the text here in place and hand this file back: write-back goes by key, as it does in the area files. As there, italic lines, `>` quotations and `<!-- … -->` comments are notes to you and are never written back. Each block’s first line names its key and where it sits in `v2` (file and line).

- **Part 1, text you reviewed that has changed: 71 blocks.** 44 changed under the same key, 22 under a new key, and 5 split into one/many forms (10 blocks now). Under each is the text as it stood at your pass, whole or, for a long block with a small change, just the sentences that changed.
- **Part 2, new since your pass: 577 blocks.** 562 carry keys the app did not have on 2026-10-01; 15 were in the app then but not yet in these files, and say so above their key.
- **Part 3, gone from the app: 10 blocks**, for the record: 5 retired (still in the area files under a RETIRED banner) and 5 removed from the files.

**One open ✎ box is new since your pass:** your 2026-09-30 sentences in About the Series’ “About these figures” footnote, replaced by lane CFPF (#1543, 2026-10-02). It is in Part 1 under 04 Series Analytics.

Left out, besides the 782 blocks whose only change is their `lines:` range or another field of the `SOURCE` comment: one block whose only change is an editor’s note (`corpus.save.truncated.total %@ %@`), and one block added and retired since your pass.

| Area file | Part 1, changed | Part 2, new | Part 3, gone |
|---|---:|---:|---:|
| 01 About & Onboarding | [2](#01-about--onboarding--changed) | [1](#01-about--onboarding--new) | [2](#01-about--onboarding--gone) |
| 02 FRUS Research Guide | [5](#02-frus-research-guide--changed) | — | — |
| 03 Repository README | [1](#03-repository-readme--changed) | — | — |
| 04 Series Analytics | [3](#04-series-analytics--changed) | — | — |
| 05 Analytics | [14](#05-analytics--changed) | [8](#05-analytics--new) | — |
| 06 Archives | [10](#06-archives--changed) | [10](#06-archives--new) | [2](#06-archives--gone) |
| 07 Search & Browse | [22](#07-search--browse--changed) | [319](#07-search--browse--new) | [1](#07-search--browse--gone) |
| 08 Reading, Research & Collections | [7](#08-reading-research--collections--changed) | [84](#08-reading-research--collections--new) | [4](#08-reading-research--collections--gone) |
| 09 Settings & app-wide messages | [7](#09-settings--app-wide-messages--changed) | [155](#09-settings--app-wide-messages--new) | [1](#09-settings--app-wide-messages--gone) |
| **All nine** | **71** | **577** | **10** |

---

## Part 1 — Text you reviewed that has changed (71)

### 01 About & Onboarding — changed

#### 1. About Screen

##### 1.4d Search Model — Storage Section Footer

*`settings.model.footer` · 01-About-and-Onboarding.md:107*

<!-- SOURCE: FRUSExplorer/Settings/SemanticModelSection.swift | property: SemanticModelSection | lines: 73–74 | key: settings.model.footer -->

Lets the app understand searches phrased as questions, using a language model that runs entirely on this device — Google’s EmbeddingGemma 2, an optional 310 MB download. The feature is experimental.

<!-- END SOURCE: settings.model.footer -->

> **At your pass:**
>
> Lets the app understand searches phrased as questions, using a language model that runs entirely on this device — Google’s EmbeddingGemma, an optional 229 MB download. The feature is experimental. The model is provided under the Gemma Terms of Use; see About ▸ Legal for the terms.

---

#### 2. Onboarding Welcome Screen

##### 2.1 Onboarding copy (all three steps)

*`onboarding.*` · 01-About-and-Onboarding.md:163*

<!-- SOURCE: FRUSExplorer/Onboarding/OnboardingView.swift | property: Copy | keys: onboarding.* -->

**Step 1 — Welcome**

- `onboarding.welcome.title` — **Welcome to FRUS Explorer**
- `onboarding.welcome.body` — The official documentary record of U.S. foreign policy since 1861 — searchable and enriched, on your device.

**Step 2 — Add Volumes**

- `onboarding.scope.title` — What would you like to download?
- `onboarding.scope.segment.corpus.long` / `.short` — Entire Corpus · Corpus
- `onboarding.scope.segment.subseries.long` / `.short` — A Subseries · Subseries
- `onboarding.scope.segment.volume.long` / `.short` — A Single Volume · Volume

  *The long labels are macOS; iOS uses the short ones, because three full labels cannot
  share an iPhone’s segment width without truncating.*

- `onboarding.scope.caption.corpus.v2 %lld` — %lld+ volumes · ≈ 3.5 GB to download, about 7 GB once indexed — the entire series, fully offline. Recommended for full functionality. *(the count is the bundled manifest’s — R-3; the size once indexed is measured, two full libraries at index version 74 holding 6.5 to 7.2 GB — L20, #1920)*
- `onboarding.scope.caption.subseries` — A coherent editorial era — recommended if you want to start smaller.
- `onboarding.scope.caption.volume` — One volume to explore — typically a few MB.
- `onboarding.scope.sheet.volumeCount` — *N* volume / volumes

**Step 3 — Ready**

- `onboarding.ready.title` — **You’re all set**
- `onboarding.ready.body` — Your volumes will download and index automatically — search unlocks in minutes. If you have no project yet, one named “My Research” is ready.
- `onboarding.ready.body.empty` — Nothing is downloading yet — browse the corpus and add volumes whenever you like. If you have no project yet, one named “My Research” is ready.
  Shown instead of the line above when the reader reaches Finish with nothing downloading (Skip,
  or a scope that enqueued no volumes), where that line’s two promises would both be false.
  Back from this step stops every download Continue queued (L20, #1920), so a Skip after it reads
  this line when nothing is on the device yet; until then it read the one above, with the whole
  series still downloading behind it.

**Shared** — `onboarding.action.back` (Back), `onboarding.action.skip` (Skip),
`onboarding.offline.banner` (You are offline. Showing bundled catalog only.).
“Get Started” / “Continue” / “Finish” come from `OnboardingStep.continueLabel`.

**Accessibility** — `onboarding.step.position` gives the page dots a spoken position
(“Step 2 of 3: Scope”); `wordcloud.backdrop.chip.era` labels the backdrop’s lens chip when
a volume’s cloud falls back to its era’s vocabulary.

<!-- END SOURCE: onboarding copy -->

> **At your pass**, the sentences that changed:
>
> **Was:** - `onboarding.scope.caption.corpus.v2 %lld` — %lld+ volumes · ≈ 3.5 GB — the entire series, fully offline.
>
> **Now:** - `onboarding.scope.caption.corpus.v2 %lld` — %lld+ volumes · ≈ 3.5 GB to download, about 7 GB once indexed — the entire series, fully offline.
>
> **Was:** *(the count is the bundled manifest’s — R-3)*
>
> **Now:** *(the count is the bundled manifest’s — R-3; the size once indexed is measured, two full libraries at index version 74 holding 6.5 to 7.2 GB — L20, #1920)*
>
> **Was:** *(nothing)*
>
> **Now:** Back from this step stops every download Continue queued (L20, #1920), so a Skip after it reads this line when nothing is on the device yet; until then it read the one above, with the whole series still downloading behind it.

---

### 02 FRUS Research Guide — changed

#### 3. FRUS Research Guide (in-app education pages)

##### 3.2 Page 2 — 165 Years of Documenting U.S. Foreign Policy

*`corpus-evolution` · 02-Research-Guide.md:68*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: corpus-evolution | lines: 743–797 -->

**Title:** 165 Years of Documenting U.S. Foreign Policy

**Subtitle:** How FRUS changed — and why it matters for research

<!-- section-id: origins -->

**Origins: Diplomatic Correspondence (1861–1920s)**

At its birth, FRUS was an instrument of public affairs and congressional relations. The series began during the Civil War as a compilation of official diplomatic correspondence — despatches from diplomatic posts, instructions to U.S. ministers overseas, and notes to and from foreign governments. The volumes documented the operations of the State Department. Coverage was often contemporaneous: volumes sometimes appeared within a year of events, prioritizing currency over comprehensiveness. Because the volumes were produced by the same clerks who administered the Department’s day-to-day business, principles of selection and editing standards reflected operational rather than historical purposes. By the early 20th century, the series had evolved to became a valuable knowledge management tool by providing ready access to key policy and precedent references for officials within the Department and its overseas posts and growing stakeholder constituencies in civil society.

<!-- section-id: professionalization -->

**Professionalization in the Interwar Era (1924-1945)**

In the 1920s, the Department of State began recruiting professionally-trained historians to undertake the increasingly complex editorial work of producing FRUS. Because budget constraints in the early 1900s and operational considerations during World War I delayed publication throughout the previous two decades, those historians had an opportunity to select and edit the historical record of U.S. foreign policy with greater perspective and depth than their predecessors. They established formal editorial principles for FRUS that endured.

<!-- section-id: national-security -->

**The National Security Turn (1945–1970s)**

The Cold War transformed FRUS. As more decision-makers outside the Department of State left their imprint on foreign policy and diplomacy, FRUS historians increasingly needed to complement State Department records with documents drawn from other agencies’ files - especially presidential records. At the same time, the United States expanded and intensified its engagement around the world. The perceived stakes of disclosure in FRUS grew. In 1957, the Department established a Historical Advisory Committee of outside academic experts to provide editorial advice about how to balance timeliness and comprehensiveness and to vouch for the integrity of published volumes. Over the following decades, FRUS historians and advisory committee experts maintained that balance and the series served as the Department of State’s transparency engine. 

<!-- section-id: crisis -->

**Crisis and Reform (1978–1991)**

By the 1980s, the gap between what FRUS had always claimed to be and what it could actually deliver grew painfully apparent. Historians inside the Office of the Historian struggled to achieve direct access to key CIA records. Academic historians appointed to the Department-chartered Historical Advisory Committee faced tightening security restrictions that made it harder to judge whether information withheld during the declassification process was marginal or essential to the historical integrity of publishable volumes. In 1989 and 1990, academic criticism of a volume documenting U.S. policy toward Iran in the early 1950s without any references to widely-known covert action attracted congressional scrutiny of the State Department’s management of the series and its relationship with the advisory committee. In 1991, Congress intervened by establishing statutory mandates for long-standing norms: the mission of the series, the obligations of U.S. Government agencies to provide access to their historical records to the historians producing FRUS, and an advisory committee of academic historians to provide oversight to validate the historical integrity of the series.

<!-- section-id: contemporary -->

**The Contemporary Series (1991–Present)**

Post-1991 volumes reflect the statute’s empowerment of FRUS historians with broader sourcing, fuller coverage of intelligence activities, and more detailed acknowledgment of omissions. Even as some volumes are delayed by interagency declassification disagreements, the 30-year rule creates a rolling horizon; volumes covering the Reagan administration are now publishing, with the Bush 41 and Clinton eras in active production.

<!-- section-id: digital -->

**The Digital Transition**

The Office of the Historian’s shift to XML-encoded TEI files and digital publication in the 21st century has transformed how FRUS can be read and searched. All {{volumes}} volumes are now available as structured digital texts — the foundation for everything this app does. The TEI format preserves document structure (headings, datelines, footnotes, person references) in a form that makes programmatic analysis possible in ways printed volumes never allowed.

<!-- section-id: frus-history -->

To dive deeper into the history of the series, see the Office of the Historian’s [official history](https://history.state.gov/historicaldocuments/frus-history) of FRUS.

<!-- END SOURCE: page corpus-evolution -->

> **At your pass**, the sentences that changed:
>
> **Was:** At the same time, United States expanded and intensified its engagement around the world.
>
> **Now:** At the same time, the United States expanded and intensified its engagement around the world.
>
> **Was:** In the 1957, the Department established a Historical Advisory Committee of outside academic experts to provide editorial advice about how to balance timeliness and comprehensiveness and to vouch for the integrity of published volumes.
>
> **Now:** In 1957, the Department established a Historical Advisory Committee of outside academic experts to provide editorial advice about how to balance timeliness and comprehensiveness and to vouch for the integrity of published volumes.

---

##### 3.3 Page 3 — Understanding What You're Reading

*`understanding-documents` · 02-Research-Guide.md:120*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: understanding-documents | lines: 803–852 -->

**Title:** Understanding What You’re Reading

**Subtitle:** Documents, citations, and the archival record

<!-- section-id: two-registers -->

Every FRUS document is a transcribed and edited representation of an original, archival record. Understanding editorial annotation will help you make full use of FRUS.

<!-- section-id: types -->

**Primary Documents, Editorial Notes, and Front Matter**

FRUS is a documentary history, which means it uses actual historical documents to tell the story of U.S. foreign policy. The historians who compile the volumes carefully select records that best document past decisions, diplomacy, and events. They also provide editorial annotation that adds more context and information from the archives than the documents themselves contain.

Primary documents are the actual historical records that were produced contemporaneously with the events they describe — cables, memoranda, meeting notes, intelligence assessments, letters. These are reproduced in FRUS (sometimes with excisions) from government files. Starting in the early 20th century, each document was published with a source note identifying its provenance, or where the original was found. Many documents also contain footnotes providing information about the historical context around the document or even offering specific archival citations to other documents, meetings, or events that are referenced in the printed document.

Many volumes also contain editorial notes written by Office of the Historian historians. They appear as numbered entries in the document sequence and serve several purposes: summarizing developments the editors judged too voluminous or sensitive to reproduce in full, explaining gaps in the record, providing context for surrounding documents, and noting where fuller documentation exists. An editorial note that says “On [date], the NSC met to discuss…” is telling you something happened that isn’t fully reproduced here. Editorial notes provide additional archival citations to unpublished documents.

Volume front matter has evolved over time. Recent volumes include valuable information about the editor’s research methodology and a listing the archival sources they consulted as they selected documents for inclusion. They also contain annotated lists of people who generated, received, or were mentioned in the documents and terms and abbreviations used in the documents.

<!-- section-id: source-note -->

**Reading a Source Note**

Document source notes identify the archival provenance of the records published in FRUS. A source note for a document in the Reagan subseries might read:

“Source: National Archives, RG 59, Central Foreign Policy File, P840114–1808. Secret; Nodis.”

This tells you: the original record was collected from the National Archives; it’s in Record Group 59 (State Department records); it’s part of the Central Foreign Policy File series; the reel identifier is P840114–1808; and it was classified Secret with a special handling caption.

One way this app helps researchers is by connecting archival citations detected in source notes directly to NARA’s finding aids — so you can navigate from a FRUS document directly to the archive where the original record lives. Source notes are extracted for every era of the series, including the modern volumes whose notes are embedded in the document heading. This makes it easier than ever to follow the archival roadmap FRUS offers for deeper research.

When a source note records classification markings — “Secret; Nodis”, or explicitly “No classification marking” — the app separates them from the archival citation and shows them as a small chip beside the source note in the reading view, in Source Explorer, and on search results. Most volumes covering 1946 to 1954, and the wartime conference volumes before them, print the marking above the dateline instead (“Secret”, or “Top Secret” over “Priority”): the reading view shows it there, as the volume prints it, and Source Explorer and search results show it in the same chip. The markings describe how the original record was handled at the time; the published text has been declassified.

The app also ships a corpus-wide authority of the archival collections FRUS cites: from Source Explorer you can open any matched collection to see its variant citation forms, its National Archives catalog record, every volume across the series that cites it, and how many documents in your own indexed volumes came from it.

<!-- section-id: classifications -->

**Excisions and Redactions**

Most FRUS documents are published in full, but there are many that were published with excisions. Some of these excisions were editorial - the historians who compiled the volume judged that the excised material wasn’t significant enough to warrant inclusion. Others were redactions were made for policy reasons during a clearance or declassification process - government officials judged that information could not be released without unacceptable risks to U.S. interests or security.

Before Secretary of State Frank Kellogg’s 1925 order, FRUS editors marked an excision with a row of asterisks, under no written policy and without any signal about whether material was cut for editorial or policy reasons. Beginning with that order, FRUS historians marked omissions uniformly with ellipses (...), but still did not characterize the general nature or describe the extent of the information that was withheld, or explain whether an omission was an editorial excision or a redaction made after an unfavorable declassification decision. The 1991 statutory mandate required more detailed editorial accounting for omitted material: volumes produced since then mark each redaction explicitly, apart from the editors’ own excisions, giving researchers a greater sense of how what is published compares to what had to be withheld.

<!-- section-id: omissions -->

**What FRUS Leaves Out**

FRUS publishes thousands of documents for every administration’s foreign policy, but it is just the tip of the iceberg for the entire historical record. Early volumes documented the implementation of foreign policy in the diplomacy conducted by the Department of State, but not the deliberative processes that set the course for U.S. foreign policy in Washington. Later volumes focused more and more on filling this gap by editorial prioritization of the decision-making process and inclusion of more and more records from beyond the State Department. This reversal of editorial focus means that the vast majority of diplomatic records that illustrate how foreign policy was implemented at U.S. embassies throughout the world are underrepresented in recent volumes compared to earlier ones.

<!-- END SOURCE: page understanding-documents -->

> **At your pass**, the sentences that changed:
>
> **Was:** *(nothing)*
>
> **Now:** Most volumes covering 1946 to 1954, and the wartime conference volumes before them, print the marking above the dateline instead (“Secret”, or “Top Secret” over “Priority”): the reading view shows it there, as the volume prints it, and Source Explorer and search results show it in the same chip.
>
> **Was:** **Excisions**
>
> **Now:** **Excisions and Redactions**
>
> **Was:** Other excisions were made for policy considerations - government officials judged that information could not be released without unacceptable risks to U.S. interests or security.
>
> **Now:** Others were redactions made in the declassification process - government officials judged that information could not be released without unacceptable risks to U.S. interests or security.
>
> **Was:** Before the 1920s, FRUS editors did not annotate excisions. Beginning in the 1920s, FRUS historians added ellipses (...) to indicate that material was omitted, but did not describe how much information was withheld or explain whether an excision was editorial in nature or an unfavorable declassification decision. The 1991 statutory mandate required more detailed editorial accounting for excised material, giving researchers a greater sense of how what is published compares to what had to be withheld.
>
> **Now:** Before Secretary of State Frank Kellogg’s 1925 order, FRUS editors marked an excision with a row of asterisks, under no written policy and without saying whether the cut was theirs or a reviewer’s. Beginning with that order, FRUS historians marked omissions uniformly with ellipses (...), but still did not describe how much information was withheld or explain whether an omission was an editorial excision or a redaction made after an unfavorable declassification decision. The 1991 statutory mandate required more detailed editorial accounting for omitted material: volumes produced since then mark each redaction explicitly, apart from the editors’ own excisions, giving researchers a greater sense of how what is published compares to what had to be withheld.

---

##### 3.5 Page 5 — Finding What You Need in FRUS Explorer

*`finding-documents` · 02-Research-Guide.md:228*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: finding-documents | lines: 920–962 -->

**Title:** Finding What You Need in FRUS Explorer

**Subtitle:** What you can start from, and what you can narrow to

<!-- section-id: starting-points -->

**Start From Whatever You Have**

FRUS Explorer is designed to help you find what you need in the series, regardless of whether you start from a natural language question, a quoted passage, a citation, a date, a broad subject, or one good document. Each of those leads somewhere in this app. The full text of every volume you’ve downloaded and indexed is searchable at once. Citations lead to the documents they identify. People tagged by FRUS editors can be followed everywhere else they’ve been tagged. Documents that fell within any span of days can be laid out in order and visualized, allowing you to ignore volume boundaries to watch how events unfolded. The Subject index points toward subjects spread too thinly to find easily any other way. And one document you trust can lead you to the documents most connected to it — by shared archival file, citation, date, the editors’ own arrangement, shared people and subjects, or, if you choose to turn it on, an AI model’s reading of the entire series for natural-language meaning.

<!-- section-id: narrowing -->

**Narrow Without Losing Count**

Whatever a search returns, you can use facets to break down the results: how the matches spread across years, volumes, people, document types, archival provenance and subjects. Most of those become a filter with one click or tap; archival provenance is the exception — it is descriptive only. When a set of volumes is the thing you keep coming back to — a crisis, a region, an administration — you can name it once and reuse it everywhere the app lets you choose scopes. When the thing you care about is covered in a particular set of documents, you can freeze them into a working corpus and run every later search inside it. You can also stack the different search modes on top of each other: search for words among your query's closest natural-language matches, or narrow keyword results with a natural-language query. You can even swap the order of the search modes, since each order yields a different list. The app keeps track of these scopes so you can replicate and document your research method.

<!-- section-id: honest-arithmetic -->

**Search That Shows Its Arithmetic**

The app assumes that some users will treat counts against the series as a whole as evidence for factual and interpretive claims, so it has been built to honestly report results against that standard. The Query Inspector shows how the app translated what you typed into the keyword search box into the query that actually ran under the hood. This can be especially important when your results are surprising. For example, an unexpectedly large count may be related to how the app sweeps variants of your terms into searches by default. When results exceed caps set for performance reasons, they are reported as floors, never as totals, and the app offers tools to visualize matches it cannot list in detail. And wherever a figure could describe either the whole series or only your indexed volumes, the app says which one it is counting.

<!-- section-id: whole-series -->

**The Whole Series, Not Just Your Library**

Finding does not wait for downloading. Semantic similarity, subjects, series-wide figures, and every volume’s place in the corpus are all visible before you add any volume to your device. Bundled data about the series as a whole allows discovery to run ahead of your library and tell you which volumes are worth adding to it. Features and functionality that need the text itself — full-text search, reading documents, analysis of the words — work over only what you have indexed.

<!-- section-id: manual -->

**Where the Controls Are**

To delve into the details about search screens, filters, and syntax, visit the User Manual — linked from the About screen. It will walk you through how the app delivers these capabilities.

<!-- END SOURCE: page finding-documents -->

> **At your pass**, the sentences that changed:
>
> **Was:** The topic index points toward subjects spread too thinly to find easily any other way. And one document you trust can lead you to the documents most connected to it — by shared archival file, citation, date, the editors’ own arrangement, shared people and topics, or, if you choose to turn it on, an AI model’s reading of the entire series for natural-language meaning.
>
> **Now:** The Subject index points toward subjects spread too thinly to find easily any other way. And one document you trust can lead you to the documents most connected to it — by shared archival file, citation, date, the editors’ own arrangement, shared people and subjects, or, if you choose to turn it on, an AI model’s reading of the entire series for natural-language meaning.
>
> **Was:** *(nothing)*
>
> **Now:** Any list of results can also be searched within, for as long as you are working with it, by the other kind of search: words found among a question’s closest matches, or keyword results ranked by a question, and the two swapped, since each order gives a different list.

---

##### 3.6 Page 6 — Seeing the Bigger Picture in FRUS Explorer

*`corpus-analysis` · 02-Research-Guide.md:270*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: corpus-analysis | lines: 966–1015 -->

**Title:** Seeing the Bigger Picture in FRUS Explorer

**Subtitle:** Questions you can put to the series as a whole

<!-- section-id: over-time -->

**Change Over Time**

Using Corpus Analytics, you can explore how the topics and language you are following move across the volumes you’ve downloaded. Any term or phrase can be charted across the series’ thirteen decades to see when it starts to appear in your volumes, when it surges, and which of your volumes carry it — as raw counts, or as a share of each period’s documents so a term does not look like it is surging just because the series grew. Any stretch of days can be reconstructed in sequence. And any set of documents you assemble — a search’s results, a collection — can be read as a timeline, so its gaps and concentrations show at a glance.

<!-- section-id: language -->

**The Language Itself**

In Search, you can go beyond finding documents and use your query to learn more about how that language was used in your volumes. Alongside the standard results list, you can see what other terms occur frequently with your own search term (its collocates) or view occurrences of your search term lined up as a concordance, so a page of hits can be sorted by the term’s immediate context and not just skimmed as a list. You can generate word clouds from a wide range of scopes keyed to either frequency or distinctiveness. The bundled semantic map places every document in the series on one screen beside others that an AI model assessed as similar, whether or not they share a volume, a date, or a citation.

<!-- section-id: people -->

**The People**

You can ask who the published record foregrounds: the most-mentioned figures of an era, one person’s presence traced year by year, two careers compared, pairs tracked together, and the network of who is named alongside whom. These features read only the people FRUS editors tagged during production, which links each mention in a document to the volume’s list of persons, and they reach only the volumes you have downloaded.

Editors tagged people in about half the series’ volumes, which hold just over a third of its documents. Tagging became the practice in volumes published from the early 1980s, so expect the people you study to be tagged in volumes covering 1955 onward, and in most of those covering 1951–1954. Before 1951 it is the exception, found among others in two volumes for 1873, the World War I supplements, the Russia volumes for 1918–1919, the five volumes for 1932, the wartime summit conferences, and a handful of postwar volumes on the United Nations, Germany and Austria. Where a volume is tagged, nearly every document names someone on its list, but only the people the editors listed are tagged. For anyone else, and in every untagged volume, you have to use search to look up people by their name as it appeared in the records. For any volume, you can easily see whether its editors tagged its people, and the app also lists the volumes that do, era by era.

<!-- section-id: citation-web -->

**The Web the Editors Drew**

FRUS editors stitched the series together with cross-references between printed documents and out to archival records. In FRUS Explorer, you can read that stitching at both scales: one document’s neighborhood as a graph — what other records informed it, what records it fed into, including archival material cited in its footnotes but not printed in the series — and the whole citation web as an aggregated network, with its most-cited landmarks and the volumes that lean on each other most. These are measures of how the editors linked documents, not a ranking of historical importance.

<!-- section-id: archival-signal -->

**Where the Documents Came From**

The app attempts to name the source archival file for every FRUS document’s original manuscript copy. Once analyzed at scale, FRUS source notes and footnotes offer powerful insights into the archival records each era’s editors actually worked in. Archival analytics offers source rankings, co-citation networks, and flows between archival units, era by era. Use this feature to see how FRUS highlights connections between discrete archival collections and repositories or use FRUS to scout out specific collections or central file classifications of interest.

<!-- section-id: finding-aid -->

**Honest Evidence**

FRUS is a selective, evolving proxy for the archival record. To learn more about the app’s analytics features, see the User Manual — linked from the About screen — for the full tour.

<!-- END SOURCE: page corpus-analysis -->

> **At your pass**, the sentences that changed:
>
> **Was:** These features only reach more recent downloaded volumes whose editors tagged people during production.
>
> **Now:** These features read only the people FRUS editors tagged during production, which links each mention in a document to the volume’s list of persons, and they reach only the volumes you have downloaded. Editors tagged people in about half the series’ volumes, which hold just over a third of its documents. Tagging became the practice in volumes published from the early 1980s, so expect the people you study to be tagged in volumes covering 1955 onward, and in most of those covering 1951–1954. Before 1951 it is the exception, found among others in two volumes for 1873, the World War I supplements, the Russia volumes for 1918–1919, the five volumes for 1932, the wartime summit conferences, and a handful of postwar volumes on the United Nations, Germany and Austria. Where a volume is tagged, nearly every document names someone on its list, but only the people the editors listed are tagged. For anyone else, and in every untagged volume, search for the name. For any volume you can see whether its editors tagged its people, and list the volumes that do, era by era.

---

##### 3.10 Page 10 — Archival Sourcing *(live dashboard — no editable page prose)*

*`series-sourcing` · 02-Research-Guide.md:404*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-sourcing | lines: 1122–1131 | note: dashboard page, sections: [] -->

This page renders the live **Archival Sourcing** dashboard (`EducationDashboard.seriesSourcing`) instead of prose, so it has no editable page-level sections. Its page **title** (“Archival Sourcing”) and **subtitle** (“Where the series drew its documents from, over time”) are localized in code at the lines above (`education.series.sourcing.page.title` / `.subtitle`).

The dashboard’s own on-screen copy lives in **`FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.provenance.intro`
- Chart titles/captions: `series.provenance.composition.title` / `.caption`, `series.provenance.trend.title` / `.caption`, `series.provenance.density.title` / `.caption`; axis labels `series.provenance.*.x` / `.y`; category legend `series.provenance.category.legend`
- Caveats block: `series.provenance.caveats.title` / `series.provenance.caveats.body.v3 %lld %lld`
- Shared “View as table” control: `series.inspector.viewTable`
- Empty state: `series.provenance.empty.title` / `series.provenance.empty.message`

<!-- END SOURCE: page series-sourcing -->

> **At your pass**, the sentences that changed:
>
> **Was:** - Caveats block: `series.provenance.caveats.title` / `series.provenance.caveats.body.v2 %lld %lld`
>
> **Now:** - Caveats block: `series.provenance.caveats.title` / `series.provenance.caveats.body.v3 %lld %lld`

---

### 03 Repository README — changed

#### 8. Repository README

*`repo.readme` · 03-Repository-README.md:25*

<!-- SOURCE: README.md | key: repo.readme | whole-file -->

# FRUS Explorer

A macOS, iPadOS, and iOS application providing tools to help researchers use the
[Foreign Relations of the United States (FRUS)](https://history.state.gov/historicaldocuments)
series more effectively.

FRUS is the official documentary record of U.S. foreign policy, published since 1861 and edited
today by the historians of the Office of the Historian, who publish it as open TEI data. The app's
bundled manifest covers 553 volumes, from the Lincoln through the George H.W. Bush administrations;
a full local index holds roughly 317,000 documents. FRUS Explorer downloads those TEI editions,
indexes them on your device, and adds reading, searching, sourcing and analysis tools built on the
Office's editorial work — all of it working offline once volumes are downloaded.

It is an independent, private-capacity project, developed with [Claude Code](https://claude.ai/code),
and is **not** an official product of the Office of the Historian or the U.S. Department of State.
Its commentary is about research method and makes no interpretive claims about the history of U.S.
foreign policy. Current build: **1861** (version 1.0).

## Screenshots

| Search (macOS) | Source Explorer (iPad) | Semantic map (iPad) |
|---|---|---|
| ![Search results with facets and filters](Docs/screenshots/macos/search.png) | ![A source note resolved to its National Archives catalog record](Docs/screenshots/ipad/source-explorer.png) | ![Semantic map](Docs/screenshots/ipad/semantic-map.png) |

More in [`Docs/screenshots/`](Docs/screenshots).

## What it does

- **Read** — TEI documents rendered with footnotes, page breaks, and live cross-references, plus
  highlights, notes, and a per-document Research rail.
- **Search** — full-text keyword FTS5/BM25 search with stemming, phrases, `NEAR(...)` proximity, `=exact` word matching, saved scopes, and working corpora captured from a result set. Semantic search relies on an optional query encoder download to execute natural language queries against vector embeddings.
- **Read a result set four ways** — ranked list, timeline, concordance (every hit lined up on the
  search term), and collocates (the words that keep company with it).
- **Inspect the query** — the Query Inspector shows the FTS5 expression your search actually became,
  each term's index form, and its corpus-wide versus in-scope counts.
- **Facet** — break a result set down by year, volume, person, document type, archival
  provenance, and subject; sort, page, and filter each breakdown; tap a row to narrow.
- **Analyze** — corpus, series, person, and cross-reference dashboards; a chronology view; and a
  word cloud with keyness and collocation.
- **Trace sources** — Source Explorer resolves FRUS source notes to NARA record groups, lot files,
  and collections, with archival neighbors and cross-volume provenance, from bundled indexes.
  Where the records are **not** at the National Archives it names the institution that holds them
  — including two that have been renamed since FRUS printed them — rather than returning
  catalog rows that cannot be right.
- **Organize** — projects, collections, exports (PDF, HTML, Word, BibTeX, RIS), Zotero, a research
  trail, and iCloud sync of your own work.
- **Summarize** — on-device Apple Intelligence summaries, one document at a time or as unattended
  bulk runs, with authorship recorded on every summary.

For anything beyond this list, read the user manuals — they are the feature documentation.

## Requirements

**To run**

- iPhone or iPad on iOS/iPadOS 26, or a Mac on macOS 26.
- An iCloud account is optional; with one, your notes, tags, collections, and projects sync via
  CloudKit and the iCloud key-value store.
- On-device summarization requires an Apple Intelligence–capable device.
- A NARA Catalog API key is optional. The bundled archival indexes resolve with no network and no
  key; a key adds live catalog lookups.

**To build**

- Xcode 26 or later, Swift 6.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — `project.yml` is the source of truth for the Xcode project.
- An Apple Developer account for signing, with iCloud/CloudKit, Keychain Sharing, and Background
  Modes capabilities.

## Getting the app

Test builds are distributed through TestFlight:

- [TestFlight instructions — iPhone and iPad](Docs/TestFlight-Instructions-ios.md)
- [TestFlight instructions — Mac](Docs/TestFlight-Instructions-mac.md)

## Documentation

- [iOS / iPadOS Quick Start](Docs/iOS-Quick-Start.md) and [macOS Quick Start](Docs/macOS-Quick-Start.md) — a first session on each platform, from the download to a cited document, with screenshots.
- [iOS / iPadOS User Manual](Docs/iOS-User-Manual.md) — the full feature documentation.
- [macOS User Manual](Docs/macOS-User-Manual.md) — the same, for the Mac app.
- [Agentic Analysis with the FRUS Explorer Database](Docs/Agentic-Analysis-Guide.md) — for researchers pointing an AI agent at the local SQLite index: schema reference, working query patterns, the ways the data will quietly mislead you, and how to keep provenance intact.
- [`Planning/FRUS-Explorer-Specification.md`](Planning/FRUS-Explorer-Specification.md) — the original design specification.
- [`CLAUDE.md`](CLAUDE.md) — build, test, and data-generator commands; coding standards; release gates. This is the maintainer's reference and the canonical copy of every command.

## How it works

Volumes are TEI XML files published by the Office of the Historian. The app downloads them per
volume, parses each into an abstract syntax tree, and serializes that to HTML rendered in a web
view — so footnotes, page breaks, and internal references keep their editorial structure rather
than being flattened into plain text.

Search is SQLite FTS5 with BM25 ranking and English stemming, built on device as volumes finish
downloading. Semantic features rely on vector embeddings generated ahead of time with Google's
EmbeddingGemma 2 model; searching by meaning runs the same model on your device. Everything you
write — notes, tags, highlights, collections, projects, prompts — lives
in SwiftData and syncs through CloudKit; nothing you write leaves your devices for a server we run.
Summarization uses Apple's on-device `FoundationModels` framework, so document text is never sent
off the device.

The archival layer is bundled and offline. Indexes built ahead of time from the NARA Catalog and
from the volumes' own front-matter source sections — central files, lot files, collection authority,
per-volume provenance — ship inside the app and resolve without a network call or an API key. The
tools that generate them live in `Package.swift` as SPM targets; their invocations and environment
variables are documented in `CLAUDE.md`.

## Building

`project.yml` is the source of truth for the Xcode project; regenerate with XcodeGen after changing
it. **`xcodegen generate` deletes `FRUSExplorer.xcodeproj/xcshareddata/xcschemes/` and regenerates
the schemes with incorrect values — always restore them afterwards with
`git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.** Build and version bumps must not go through XcodeGen at all; see `CLAUDE.md` for that procedure.

Two shared schemes: `FRUSExplorer` (iOS/iPadOS) and `FRUSExplorerMac`. Test, generator, and release
commands all live in [`CLAUDE.md`](CLAUDE.md) — they are not repeated here so there is only one copy
to keep correct.

Every archive needs the query encoder's debug symbols cached locally first: run [`Scripts/fetch-llama-dsyms.sh`](Scripts/fetch-llama-dsyms.sh) once after cloning (and after any rebuild of `Vendor/llama.xcframework`). The dSYMs are too large for the repository, so an archive-only build phase copies them from that cache and refuses to archive without them; the `CLAUDE.md` entry explains why.

## Data and credits

- The **FRUS series** is published by the [Office of the Historian](https://history.state.gov), U.S. Department of State, and is in the public domain. TEI editions come from the [HistoryAtState](https://github.com/HistoryAtState) repositories.
- The bundled person-authority crosswalk derives from the Office of the Historian's public-domain
  (CC0) `HistoryAtState/people` registry; volume subject profiles derive from its public-domain
  `frus-subjects` document–subject mappings.
- Archival records come from the [National Archives Catalog](https://www.archives.gov/research/catalog/help/api). FRUS Explorer is not affiliated with, endorsed by, or sponsored by NARA, and catalog data is subject to NARA's terms of use.
- TEI rendering approaches were informed by the [TEI Publisher](https://teipublisher.com) project (Apache 2.0).

Commentary, advice, and guidance about the FRUS series contained in the application reflect personal
views and not necessarily those of the Department of State or the U.S. Government.

## License

Apache 2.0. See [LICENSE](LICENSE) for the full license text.

All source files carry the Apache 2.0 license header.

The optional natural-language search feature downloads Google's [EmbeddingGemma 2](https://huggingface.co/google/embeddinggemma-2) model at the user's request and runs it on-device. The model weights are never part of this repository; Google licenses the model under the Apache License, Version 2.0. The app downloads it unmodified (the ggml-org Q8_0 GGUF build, SHA-256-pinned in the semantic artifacts) and embeds [llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT) to run it. See [NOTICE](NOTICE). Builds 42 to 50 used EmbeddingGemma 300m, under the Gemma Terms of Use, and asked the reader to accept those terms before the download.

## Contributing

Read [`CLAUDE.md`](CLAUDE.md) for the architecture, build commands, and coding standards, and [`Planning/DEVELOPMENT-PLAN.md`](Planning/DEVELOPMENT-PLAN.md) for the session sequence. Both app targets must build and the full test suite must pass before a change lands. Update `FRUS-API.openapi.yaml` when you touch a stored or queryable data surface. The test suite checks that file's structure (OpenAPI 3.1.0, its required paths and schemas, no `nullable: true`), not that it describes your change, so keeping it current is yours to do.

<!-- END SOURCE: repo.readme -->

> **At your pass:**
>
> # FRUS Explorer
>
> A macOS, iPadOS, and iOS application providing tools to help researchers use the
> [Foreign Relations of the United States (FRUS)](https://history.state.gov/historicaldocuments)
> series more effectively.
>
> FRUS is the official documentary record of U.S. foreign policy since 1861. The app's bundled
> manifest covers 553 volumes; a full local index holds roughly 317,000 documents. FRUS Explorer
> downloads the Office of the Historian's TEI editions, indexes them on your device, and adds the
> reading, searching, sourcing and analysis tools a corpus that size needs — all of it working
> offline once volumes are downloaded.
>
> It is an independent project, developed with [Claude Code](https://claude.ai/code), and is **not**
> an official product of the Office of the Historian or the U.S. Department of State. Current build:
> **48** (version 0.2).
>
> ## Screenshots
>
> | Search (macOS) | Cross-reference graph (macOS) | Semantic map (iPad) |
> |---|---|---|
> | ![Search results with facets and filters](Docs/screenshots/macos/search.png) | ![Cross-reference graph](Docs/screenshots/macos/cross-reference-graph.png) | ![Semantic map](Docs/screenshots/ipad/semantic-map.png) |
>
> More in [`Docs/screenshots/`](Docs/screenshots).
>
> ## What it does
>
> - **Read** — TEI documents rendered with footnotes, page breaks, and live cross-references, plus
>   highlights, notes, and a per-document Research rail.
> - **Search** — full-text keyword FTS5/BM25 search with stemming, phrases, `NEAR(...)` proximity, `=exact` word matching, saved scopes, and working corpora captured from a result set. Semantic search relies on an optional query encoder download to execute natural language queries against vector embeddings.
> - **Read a result set four ways** — ranked list, timeline, concordance (every hit lined up on the
>   search term), and collocates (the words that keep company with it).
> - **Inspect the query** — the Query Inspector shows the FTS5 expression your search actually became,
>   each term's index form, and its corpus-wide versus in-scope counts.
> - **Facet** — break a result set down by year, volume, person, document type, and archival
>   provenance; sort, page, and filter each breakdown; tap a row to narrow.
> - **Analyze** — corpus, series, person, and cross-reference dashboards; a chronology view; and a
>   word cloud with keyness and collocation.
> - **Trace sources** — Source Explorer resolves FRUS source notes to NARA record groups, lot files,
>   and collections, with archival neighbors and cross-volume provenance, from bundled indexes.
>   Where the records are **not** at the National Archives it names the institution that holds them
>   — including two that have been renamed since FRUS printed them — rather than returning
>   catalog rows that cannot be right.
> - **Organize** — projects, collections, exports (PDF, HTML, Word, BibTeX, RIS), Zotero, a research
>   trail, and iCloud sync of your own work.
> - **Summarize** — on-device Apple Intelligence summaries, one document at a time or as unattended
>   bulk runs, with authorship recorded on every summary.
>
> For anything beyond this list, read the user manuals — they are the feature documentation.
>
> ## Requirements
>
> **To run**
>
> - iPhone or iPad on iOS/iPadOS 26, or a Mac on macOS 26.
> - An iCloud account is optional; with one, your notes, tags, collections, and projects sync via
>   CloudKit and the iCloud key-value store.
> - On-device summarization requires an Apple Intelligence–capable device.
> - A NARA Catalog API key is optional. The bundled archival indexes resolve with no network and no
>   key; a key adds live catalog lookups.
>
> **To build**
>
> - Xcode 26 or later, Swift 6.
> - [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — `project.yml` is the source of truth for the Xcode project.
> - An Apple Developer account for signing, with iCloud/CloudKit, Keychain Sharing, and Background
>   Modes capabilities.
>
> ## Getting the app
>
> Test builds are distributed through TestFlight:
>
> - [TestFlight instructions — iPhone and iPad](Docs/TestFlight-Instructions-ios.md)
> - [TestFlight instructions — Mac](Docs/TestFlight-Instructions-mac.md)
>
> ## Documentation
>
> - [iOS / iPadOS User Manual](Docs/iOS-User-Manual.md) — the full feature documentation.
> - [macOS User Manual](Docs/macOS-User-Manual.md) — the same, for the Mac app.
> - [Agentic Analysis with the FRUS Explorer Database](Docs/Agentic-Analysis-Guide.md) — for researchers pointing an AI agent at the local SQLite index: schema reference, working query patterns, the ways the data will quietly mislead you, and how to keep provenance intact.
> - [`Planning/FRUS-Explorer-Specification.md`](Planning/FRUS-Explorer-Specification.md) — the original design specification.
> - [`CLAUDE.md`](CLAUDE.md) — build, test, and data-generator commands; coding standards; release gates. This is the maintainer's reference and the canonical copy of every command.
>
> ## How it works
>
> Volumes are TEI XML files published by the Office of the Historian. The app downloads them per
> volume, parses each into an abstract syntax tree, and serializes that to HTML rendered in a web
> view — so footnotes, page breaks, and internal references keep their editorial structure rather
> than being flattened into plain text.
>
> Search is SQLite FTS5 with BM25 ranking and English stemming, built on device as volumes finish
> downloading. Semantic features rely on vector embeddings generated ahead of time with Google's
> EmbeddingGemma model; searching by meaning runs the same model on your device. Everything you
> write — notes, tags, highlights, collections, projects, prompts — lives
> in SwiftData and syncs through CloudKit; nothing you write leaves your devices for a server we run.
> Summarization uses Apple's on-device `FoundationModels` framework, so document text is never sent
> off the device.
>
> The archival layer is bundled and offline. Indexes built ahead of time from the NARA Catalog and
> from the volumes' own front-matter source sections — central files, lot files, collection authority,
> per-volume provenance — ship inside the app and resolve without a network call or an API key. The
> tools that generate them live in `Package.swift` as SPM targets; their invocations and environment
> variables are documented in `CLAUDE.md`.
>
> ## Building
>
> `project.yml` is the source of truth for the Xcode project; regenerate with XcodeGen after changing
> it. **`xcodegen generate` deletes `FRUSExplorer.xcodeproj/xcshareddata/xcschemes/` and regenerates
> the schemes with incorrect values — always restore them afterwards with
> `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.** Build and version bumps must not go through XcodeGen at all; see `CLAUDE.md` for that procedure.
>
> Two shared schemes: `FRUSExplorer` (iOS/iPadOS) and `FRUSExplorerMac`. Test, generator, and release
> commands all live in [`CLAUDE.md`](CLAUDE.md) — they are not repeated here so there is only one copy
> to keep correct.
>
> Every archive needs the query encoder's debug symbols cached locally first: run [`Scripts/fetch-llama-dsyms.sh`](Scripts/fetch-llama-dsyms.sh) once after cloning (and after any rebuild of `Vendor/llama.xcframework`). The dSYMs are too large for the repository, so an archive-only build phase copies them from that cache and refuses to archive without them; the `CLAUDE.md` entry explains why.
>
> ## Data and credits
>
> - The **FRUS series** is published by the [Office of the Historian](https://history.state.gov), U.S. Department of State, and is in the public domain. TEI editions come from the [HistoryAtState](https://github.com/HistoryAtState) repositories.
> - The bundled person-authority crosswalk derives from the Office of the Historian's public-domain
>   (CC0) `HistoryAtState/people` registry; volume subject profiles derive from its public-domain
>   `frus-subjects` document–subject mappings.
> - Archival records come from the [National Archives Catalog](https://www.archives.gov/research/catalog/help/api). FRUS Explorer is not affiliated with, endorsed by, or sponsored by NARA, and catalog data is subject to NARA's terms of use.
> - TEI rendering approaches were informed by the [TEI Publisher](https://teipublisher.com) project (Apache 2.0).
>
> Commentary, advice, and guidance about the FRUS series contained in the application reflect personal
> views and not necessarily those of the Department of State or the U.S. Government.
>
> ## License
>
> Apache 2.0. See [LICENSE](LICENSE) for the full license text.
>
> All source files carry the Apache 2.0 license header.
>
> The optional natural-language search feature downloads Google's EmbeddingGemma model at the user's request and runs it on-device. The model weights are never part of this repository and are not covered by the Apache License: Gemma is provided under and subject to the [Gemma Terms of Use](https://ai.google.dev/gemma/terms), including its [Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy). The app ships the model unmodified (the Q4_0 QAT GGUF build, SHA-256-pinned in the semantic artifacts) and embeds [llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT) to run it. See [NOTICE](NOTICE) and `Planning/semantic-vectors/Gemma-Compliance-Runbook.md`.
>
> ## Contributing
>
> Read [`CLAUDE.md`](CLAUDE.md) for the architecture, build commands, and coding standards, and [`Planning/DEVELOPMENT-PLAN.md`](Planning/DEVELOPMENT-PLAN.md) for the session sequence. Both app targets must build and the full test suite must pass before a change lands. Update `FRUS-API.openapi.yaml` when you touch a stored or queryable data surface — that one is mechanically enforced.

---

### 04 Series Analytics — changed

#### 4. Series Analytics — Dashboard Prose

##### Source Provenance dashboard (Series Analytics SA-3b) › Page intro

*`series.provenance.intro` · 04-Series-Analytics.md:19*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | intro (SourceProvenanceDashboard) | lines: 248–249 | key: series.provenance.intro -->

Where did the editors of Foreign Relations of the United States find the documents they published? Since the early 20th century, nearly every document carries a source note naming the archival file it came from. These charts read those notes across the whole series to trace how its archival provenance changed. The State Department’s central files predominated until bureau lot files and presidential libraries appeared after World War II. Modern volumes draw on a much wider range of sources.

<!-- END SOURCE: series.provenance.intro -->

> **At your pass:**
>
> Where did the editors of Foreign Relations of the United States find the documents they published? Since the early 20th century, every document carries a source note naming the archival file it came from. These charts read those notes across the whole series to trace how its archival provenance changed. The State Department’s central files predominated until bureau lot files and presidential libraries appeared after World War II. Modern volumes draw on a much wider range of sources.

---

##### Source Provenance dashboard (Series Analytics SA-3b) › "About these figures" methodology footnote

*`series.provenance.caveats.body.v3 %lld %lld` · 04-Series-Analytics.md:59*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats body | lines: 661–662 | key: series.provenance.caveats.body.v3 %lld %lld -->

These figures come from parsing each document’s source note, the citation naming where its archival original was found. They are not drawn from a catalog of the archives. “Other / Unclassified” means a citation the parser could not classify, not a missing source note. Coverage spans %1$lld of the %2$lld cataloged volumes. Pre-1900 volumes are largely published diplomatic correspondence with no archival source notes, so the trend begins around 1900. The categories follow State Department filing practice. Between 1906-1910, the Department used a case-based Numerical File. After 1910, it adopted a classification-based Central Decimal File that persisted (with incremental revisions) until January 1963. The Subject-Numeric File replaced the decimal file in February 1963 and ran through 1973, and the Central Foreign Policy File followed from July 1973. A citation to the central files is placed by what it gives: a decimal file number, a Subject-Numeric file designation or its block of years, or the Central Foreign Policy File’s name or a film number. Lot files were kept by individual bureaus, offices, and posts. Presidential libraries hold the White House records that dominate modern volumes. Remember that these counts show where FRUS editors found the documents they selected for publication. That is an editorial and archival signal, not a full census of the underlying archives.

<!-- END SOURCE: series.provenance.caveats.body.v3 %lld %lld -->

> **✎ Your sentences of 2026-09-30, replaced by lane CFPF (#1543, 2026-10-02).** You wrote: “The Central Decimal File is the pre-1963 central filing system. For now, the Central Foreign Policy File category covers both its 1963–1973 Subject-Numeric successor and the post-1973 file.” The app now ships the three sentences above in their place, under a new key (`.v3`). Why: the category never held the 1963–1973 file. Measured over the 264,552 document source notes, 22 of the 9,443 Subject-Numeric citations sat in the Central Foreign Policy File category; 3,844 were counted under the Central Decimal File and 5,577 under Other NARA Collections, by how each note was worded. #1543 gives the Subject-Numeric File a category of its own, which is what your “For now” was waiting on, so the footnote says what the three central categories are and how a citation is placed among them. It also names the Numerical File of 1906–1910, whose 2,447 citations the Central Decimal File category has always held. Edit the block above to reword it; this box is never written back.

> **At your pass, under `series.provenance.caveats.body.v2 %lld %lld`**, the sentences that changed:
>
> **Was:** The Central Decimal File is the pre-1963 central filing system. For now, the Central Foreign Policy File category covers both its 1963–1973 Subject-Numeric successor and the post-1973 file.
>
> **Now:** The Central Decimal File category is the central filing system through January 1963: the decimal file from 1910 and, before it, the Numerical File of 1906–1910. The Subject-Numeric File replaced the decimal file in February 1963 and ran through 1973, and the Central Foreign Policy File followed from July 1973. A citation to the central files is placed by what it gives: a decimal file number, a Subject-Numeric file designation or its block of years, or the Central Foreign Policy File’s name or a film number.

---

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.4 About the Series dashboards › This dashboard groups source notes into eleven broad…

*`series.provenance.archivalLink.detail.v2` · 04-Series-Analytics.md:241*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | SourceProvenanceDashboard.archivalAnalyticsLink | lines: 609–610 | key: series.provenance.archivalLink.detail.v2 -->

This dashboard groups source notes into eleven broad categories. Archival Analytics names the individual collections inside them, ranks them era by era, and shows which ones the same volumes drew on together.

<!-- END SOURCE: series.provenance.archivalLink.detail.v2 -->

> **At your pass, under `series.provenance.archivalLink.detail`:**
>
> This dashboard groups source notes into ten broad categories. Archival Analytics names the individual collections inside them, ranks them era by era, and shows which ones the same volumes drew on together.

---

### 05 Analytics — changed

#### 5. Analytics — Explanatory Captions & Info Popovers

##### About the Graph popover › Timeline and Network layouts

*`graph.info.timeline.body` · 05-Analytics.md:53*

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1581–1582 | key: graph.info.timeline.body -->

Timeline mode places each document at its date along a horizontal time axis. Outgoing references usually sit to the left, since they are earlier. Incoming references usually sit to the right, since they are later. A cited page number sits at the dates of the documents printed on it. The app places and labels a document or page in a volume you have not downloaded at the dates it can access from its existing data, often only its enclosing volume’s span. Documents with no recorded date go in the Undated column. Network mode arranges nodes by their connections alone.

<!-- END SOURCE: graph.info.timeline.body -->

> **At your pass:**
>
> Timeline mode places each document at its date along a horizontal time axis. Outgoing references usually sit to the left, since they are earlier. Incoming references usually sit to the right, since they are later. Documents with no recorded date go in the Undated column. Network mode arranges nodes by their connections alone.

---

##### Cross-Reference Analytics — Captions › Excluded unresolvable references — one (shown only when the count is non-zero)

*The count is grouped and the sentence agrees with it, as the export's caveat below does (#1761, where one reference over 1961–1963 read “1 unresolvable references are excluded”).*

*`crossRefAnalytics.excludedBrokenCaption.one` · 05-Analytics.md:628*

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 867–868 | key: crossRefAnalytics.excludedBrokenCaption.one | shared: iOS+macOS (single edit point) -->

%@ unresolvable reference is excluded from this analysis — a cross-reference in the printed volumes that points to a document, page, or volume not present in the corpus.

<!-- END SOURCE: crossRefAnalytics.excludedBrokenCaption.one -->

*`crossRefAnalytics.excludedBrokenCaption.many` · 05-Analytics.md:636*

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 869–870 | key: crossRefAnalytics.excludedBrokenCaption.many | shared: iOS+macOS (single edit point) -->

%@ unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus.

<!-- END SOURCE: crossRefAnalytics.excludedBrokenCaption.many -->

> **At your pass, one block for every count, `crossRefAnalytics.excludedBrokenCaption`:**
>
> \(excludedBrokenCount) unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus.

---

##### Analytics Export — Word Cloud caveats › Counted as printed

*Changed by #1608 (2026-10-12). The caveat's example was “negotiation” and “negotiations”, which is false while* Merge plural and singular forms *is on (the default): a printed count still folds a regular plural by rule, and counts those two as one word. It is now a verb, which no rule folds. The last two blocks are new: since #1608 such a cloud has a Distinctive ranking, against a corpus reference counted as printed, and its CSV and its image say so.*

*Changed for decision 38 of the 2026-10-14 plan of record (2026-10-16). The image's two caption segments and the collection plate's line said only that the words were counted, or counted and compared, as printed, where the screen and the CSV also say that another device can count differently. They now carry your sentence, “Counted as printed on this device; another device may count differently.”: the plate as you wrote it, and the image's caption as a segment of its line, in the counted form under Frequency and the counted-and-compared form under Distinctive. Each replaces “not in dictionary forms” (the caption) or “the device that made this cloud was not reducing words to their dictionary forms” (the plate). A collection's cloud is sized by frequency, so its plate has no counted-and-compared form.*

*`wordcloud.export.caveat.countedAsPrinted` · 05-Analytics.md:945*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.countedAsPrintedCaveat | lines: 185–186 | key: wordcloud.export.caveat.countedAsPrinted | shared: iOS+macOS (single edit point) -->

Counting: these words were counted as printed. When this cloud was made, the device’s language analysis was not reducing words to their dictionary forms, so “negotiate” and “negotiated” are two words here where a device whose language analysis works counts one. These counts and shares cannot be compared with a cloud counted in dictionary forms.

<!-- END SOURCE: wordcloud.export.caveat.countedAsPrinted -->

> **At your pass:**
>
> Counting: these words were counted as printed. When this cloud was made, the device’s language analysis was not reducing words to their dictionary forms, so “negotiation” and “negotiations” are two words here where a device whose language analysis works counts one. These counts and shares cannot be compared with a cloud counted in dictionary forms.

---

*`wordcloud.export.caption.countedAsPrinted` · 05-Analytics.md:951*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.countedAsPrintedCaptionSegment | lines: 266–267 | key: wordcloud.export.caption.countedAsPrinted | shared: iOS+macOS (single edit point) -->

counted as printed on this device; another device may count differently

<!-- END SOURCE: wordcloud.export.caption.countedAsPrinted -->

> **At your pass:**
>
> counted as printed, not in dictionary forms

---

*`wordcloud.export.collection.countedAsPrinted` · 05-Analytics.md:957*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.countedAsPrintedPlateLine | lines: 276–277 | key: wordcloud.export.collection.countedAsPrinted | shared: iOS+macOS (single edit point) -->

Counted as printed on this device; another device may count differently.

<!-- END SOURCE: wordcloud.export.collection.countedAsPrinted -->

> **At your pass:**
>
> Counted as printed: the device that made this cloud was not reducing words to their dictionary forms.

---

#### 12. Word Cloud — Keyness and its Reference

##### 12.2 When keyness is unavailable, and why › This device counted the words as printed

*Added by #1373. Shown under Distinctive when the scope's words were counted without the device's lemmatiser. Reworded by #1539: the app checks again each time it becomes active, and the cloud is counted again when a check finds the lemmatiser working.*

*Since #1608 (2026-10-12) a reader should not meet it. A cloud counted as printed is now ranked against a second corpus reference that was counted as printed, and says so (§12.4,* Counted and compared as printed*). This sentence is left for a launch on which that second reference could not be loaded. Its text is unchanged.*

*`wordcloud.keyness.unavailable.languageAnalysis` · 05-Analytics.md:1093*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1110–1111 | key: wordcloud.keyness.unavailable.languageAnalysis -->

These words were counted as printed, because this device’s language analysis wasn’t reducing them to their dictionary forms. The corpus reference was counted in dictionary forms, so the two can’t be compared. Size words by frequency instead. FRUS Explorer checks again each time you come back to it, and the cloud is counted again if it recovers; if it doesn’t, quitting and reopening FRUS Explorer may restore it.

<!-- END SOURCE: wordcloud.keyness.unavailable.languageAnalysis -->

> **At your pass:**
>
> These words were counted as printed, because this device’s language analysis wasn’t reducing them to their dictionary forms. The corpus reference was counted in dictionary forms, so the two can’t be compared. Size words by frequency instead, or quit and reopen FRUS Explorer and try again.

---

##### 12.4 Empty states › A name lens this device cannot draw

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

*Added by #1373; re-keyed in its review round 3. Shown for People, Places or Organizations when the device's name recognizer failed its check. Interpolated with the lens name (`%1$@`) and with the lenses that still work (`%2$@`), which the app reads from the same check and joins as a list: with only names failing, All terms, Topics (nouns), Actions (verbs), Descriptors (adjectives), Concepts, and Sentiment; with the word classes failing too, All terms, Concepts, and Sentiment. Reworded by #1539: the app checks again each time it becomes active, and the cloud reloads when a check finds names working.*

*`wordcloud.lens.unavailable.names %@ %@` · 05-Analytics.md:1207*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 472–473 | key: wordcloud.lens.unavailable.names %@ %@ -->

This device’s language analysis isn’t recognizing names right now, so the “%1$@” lens can’t be drawn. %2$@ still work. FRUS Explorer checks again each time you come back to it, and the cloud updates if it recovers; if it doesn’t, quitting and reopening FRUS Explorer may restore it.

<!-- END SOURCE: wordcloud.lens.unavailable.names %@ %@ -->

> **At your pass:**
>
> This device’s language analysis isn’t recognizing names right now, so the “%1$@” lens can’t be drawn. %2$@ still work. Quitting and reopening FRUS Explorer may restore it.

---

##### 12.4 Empty states › A part-of-speech lens this device cannot draw

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

*Added by #1373; re-keyed in its review round 3. Shown for Topics, Actions or Descriptors when the device's word classes failed their check. Interpolated with the lens name (`%1$@`) and with the lenses that still work (`%2$@`), which the app reads from the same check and joins as a list: with only the word classes failing, All terms, People, Places, Organizations, Concepts, and Sentiment; with names failing too, All terms, Concepts, and Sentiment. Reworded by #1539: the app checks again each time it becomes active, and the cloud reloads when a check finds the word classes working.*

*`wordcloud.lens.unavailable.classes %@ %@` · 05-Analytics.md:1221*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 476–477 | key: wordcloud.lens.unavailable.classes %@ %@ -->

This device’s language analysis isn’t telling nouns, verbs and adjectives apart right now, so the “%1$@” lens can’t be drawn. %2$@ still work. FRUS Explorer checks again each time you come back to it, and the cloud updates if it recovers; if it doesn’t, quitting and reopening FRUS Explorer may restore it.

<!-- END SOURCE: wordcloud.lens.unavailable.classes %@ %@ -->

> **At your pass:**
>
> This device’s language analysis isn’t telling nouns, verbs and adjectives apart right now, so the “%1$@” lens can’t be drawn. %2$@ still work. Quitting and reopening FRUS Explorer may restore it.

---

##### 12.4 Empty states › Counted as printed

*Added by #1373. A caption under the cloud's title when its words were counted without the device's lemmatiser — and, since review round 1, under a comparison column's count too. The exported forms of the same fact are §5's* Counted as printed *blocks.*

*Changed by #1608 (2026-10-12): the second sentence is new. The owner's condition for the printed-form fallback (2026-09-29, restated 2026-10-12) is that every surface that falls back says that it did, says why, and says that results can differ from a device whose language analysis reduces words to their dictionary forms; the decision of 2026-09-29 names the clouds' counts among those surfaces, and this line said only the first two. It is no longer held to two lines: it is shown whole, and scrolls in a short strip where the screen has no room for it.*

*`wordcloud.countedAsPrinted` · 05-Analytics.md:1351*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 175–176 | key: wordcloud.countedAsPrinted -->

Counted as printed: this device isn’t reducing words to their dictionary forms right now. Counts can differ on a device that does: a Mac, or another iPhone or iPad.

<!-- END SOURCE: wordcloud.countedAsPrinted -->

> **At your pass:**
>
> Counted as printed: this device isn’t reducing words to their dictionary forms right now.

---

#### 13. Semantic Analytics — the map, its regions, its slices, and its vectors

##### 13.8 Settings ▸ Data & Recovery ▸ Semantic Match Feedback › The privacy footer

*Re-keyed from `settings.semanticFeedback.privacy` for #1545 (2026-10-18): it names where the file goes. `\(SemanticFeedbackMail.address)` is feedback@frusexplorer.app, the one constant the draft is addressed from.*

*`settings.semanticFeedback.privacy.v2` · 05-Analytics.md:1785*

<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 113–121 | key: settings.semanticFeedback.privacy.v2 -->

Stored on-device and not synced to iCloud. Each verdict records the two documents, your judgement, the match score, which release of the vectors it applies to, and when you made it. The app shares none of this on its own: to contribute your verdicts, choose Prepare Feedback File, then send the file to \(SemanticFeedbackMail.address). Where this device can send mail, Email Feedback File drafts that message with the file attached; Share Feedback File generates the file so you can share it another way.

<!-- END SOURCE: settings.semanticFeedback.privacy.v2 -->

> **At your pass, under `settings.semanticFeedback.privacy`:**
>
> Stored on-device and not synced to iCloud. Each verdict records the two documents, your judgement, the match score, which release of the vectors it applies to, and when you gave it. The app sends none of it: to share your verdicts, choose Prepare Feedback File, then Share Feedback File.

---

#### 14. Short strings bumped since the build-42 pass — the parts about this area

##### Word cloud › Reading every indexed document. On a full library this ta…

*`wordcloud.loading.corpus.v2` · 05-Analytics.md:1827*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1600–1601 | key: wordcloud.loading.corpus.v2 -->

Processing every indexed document. On a full library this takes about twenty minutes, and longer on an older device; the finished cloud is kept, but closing this screen before then stops it.

<!-- END SOURCE: wordcloud.loading.corpus.v2 -->

> **At your pass:**
>
> Reading every indexed document. On a full library this takes several minutes — you can leave this screen and come back.

---

##### Semantic map lenses › Each volume takes the category its source notes name most…

*`semanticMap.lens.provenance.caption.v3` · 05-Analytics.md:1843*

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapLens.swift | lines: 106–107 | key: semanticMap.lens.provenance.caption.v3 -->

Each volume takes the category its source notes name most often — a plurality, not a majority, for 86 of the 499 volumes it colors. Volumes with fewer than ten notes are left uncolored.

<!-- END SOURCE: semanticMap.lens.provenance.caption.v3 -->

> **At your pass, under `semanticMap.lens.provenance.caption.v2`:**
>
> Each volume takes the category its source notes name most often — a plurality, not a majority, for 73 of the 499 volumes it colors. Volumes with fewer than ten notes are left uncolored.

---

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.2 Corpus, Person and Cross-Reference Analytics › Tooltip — Switch to Search with this term — and, if you narrowed the…

*`analytics.handoff.help.v3` · 05-Analytics.md:1913*

<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.searchHandoffBar | lines: 1365–1366 | key: analytics.handoff.help.v3 -->

Switch to Search with this term — and, if you narrowed the years of a date-based view, those years — to see the matching documents. The count is Search’s: it takes in a document whose dates overlap the years, even one the chart places before them, and leaves out an undated one, which the chart places in its volume’s first year. Search opens over document text only, with your own notes and summaries left out.

<!-- END SOURCE: analytics.handoff.help.v3 -->

> **At your pass, under `analytics.handoff.help.v2`:**
>
> Switch to Search pre-filled with this term — and this year range, if a date-based view is active — to see the matching documents. Search opens over document text only, the way the chart counts, with your own notes and summaries left out.

---

##### 18.2 Corpus, Person and Cross-Reference Analytics › Showing the top \(…) co-mentioned people (of \(…)+) by…

*`personCoMention.cap.disclosed` · 05-Analytics.md:2043*

<!-- SOURCE: FRUSCoreKit/Analytics/PersonCoMentionNetwork.swift | PersonCoMentionNetwork.capDisclosure | lines: 166–167 | key: personCoMention.cap.disclosed -->

*Shown only when the cap bites, so it always reads "Showing the top 24 co-mentioned people (of 25+) …". The "25+" is all the app knows: it asks for one partner more than the 24 it draws, so it can say there are more but not how many.*

Showing the top \(partnerCount) co-mentioned people (of \(totalPartnerCount)+) by shared-document count.

<!-- END SOURCE: personCoMention.cap.disclosed -->

> **At your pass:**
>
> Showing the top \(partners.count) co-mentioned people (of \(totalPartnerCount)+) by shared-document count.

---

### 06 Archives — changed

#### 9. Archival Analytics — Dashboard Prose

##### 9.3 Network — one collection and everything cited beside it › The info dock — what a link means

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

*`archival.network.dock.grain.one` · 06-Archives.md:247*

<!-- SOURCE: FRUSCoreKit/Analytics/Archival/ArchivalCounts.swift | ArchivalCounts.networkPartners | lines: 150–151 | key: archival.network.dock.grain.one | shared: iOS+macOS (single edit point) -->

%@ collection shares two or more volumes with this one. Links are volume-grain — the same volumes drew on both — which is not document-level affinity.

<!-- END SOURCE: archival.network.dock.grain.one -->

*`archival.network.dock.grain.many` · 06-Archives.md:253*

<!-- SOURCE: FRUSCoreKit/Analytics/Archival/ArchivalCounts.swift | ArchivalCounts.networkPartners | lines: 152–153 | key: archival.network.dock.grain.many | shared: iOS+macOS (single edit point) -->

%@ collections share two or more volumes with this one. Links are volume-grain — the same volumes drew on both — which is not document-level affinity.

<!-- END SOURCE: archival.network.dock.grain.many -->

> **At your pass, one block for every count, `archival.network.dock.grain %lld`:**
>
> %lld collections share two or more volumes with this one. Links are volume-grain — the same volumes drew on both — which is not document-level affinity.

---

##### 9.3 Network — one collection and everything cited beside it › The info dock — the six-per-custodian cap

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

*`archival.network.dock.capped.one` · 06-Archives.md:265*

<!-- SOURCE: FRUSCoreKit/Analytics/Archival/ArchivalCounts.swift | ArchivalCounts.networkHeldBack | lines: 170–171 | key: archival.network.dock.capped.one | shared: iOS+macOS (single edit point) -->

%@ more is held back so each custodian’s quadrant stays readable; every quadrant keeps its strongest members. Raising the threshold narrows the neighborhood rather than seeing more of it.

<!-- END SOURCE: archival.network.dock.capped.one -->

*`archival.network.dock.capped.many` · 06-Archives.md:271*

<!-- SOURCE: FRUSCoreKit/Analytics/Archival/ArchivalCounts.swift | ArchivalCounts.networkHeldBack | lines: 172–173 | key: archival.network.dock.capped.many | shared: iOS+macOS (single edit point) -->

%@ more are held back so each custodian’s quadrant stays readable; every quadrant keeps its strongest members. Raising the threshold narrows the neighborhood rather than seeing more of it.

<!-- END SOURCE: archival.network.dock.capped.many -->

> **At your pass, one block for every count, `archival.network.dock.capped.v2 %lld`:**
>
> %lld more are held back so each custodian’s quadrant stays readable; every quadrant keeps its strongest members. Raising the threshold narrows the neighborhood rather than seeing more of it.

---

##### 9.3 Network — one collection and everything cited beside it › The info dock — the class sub-arc

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

*`archival.network.dock.classes.one` · 06-Archives.md:283*

<!-- SOURCE: FRUSCoreKit/Analytics/Archival/ArchivalCounts.swift | ArchivalCounts.networkClassSquares | lines: 191–192 | key: archival.network.dock.classes.one | shared: iOS+macOS (single edit point) -->

The %@ square is a central-file class drawn from inside the Central Files record, which is hidden while it is shown.

<!-- END SOURCE: archival.network.dock.classes.one -->

*`archival.network.dock.classes.many` · 06-Archives.md:289*

<!-- SOURCE: FRUSCoreKit/Analytics/Archival/ArchivalCounts.swift | ArchivalCounts.networkClassSquares | lines: 193–194 | key: archival.network.dock.classes.many | shared: iOS+macOS (single edit point) -->

The %@ squares are central-file classes drawn from inside the Central Files record, which is hidden while they are shown.

<!-- END SOURCE: archival.network.dock.classes.many -->

> **At your pass, one block for every count, `archival.network.dock.classes %lld`:**
>
> The %lld squares are central-file classes drawn from inside the Central Files record, which is hidden while they are shown.

---

##### 9.3 Network — one collection and everything cited beside it › A selected class node's card

*`archival.network.class.caption.v2` · 06-Archives.md:329*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 838–839 | key: archival.network.class.caption.v2 -->

Central-file class — a subject heading inside one of the State Department’s central filing systems, not a collection

<!-- END SOURCE: archival.network.class.caption.v2 -->

> **At your pass, under `archival.network.class.caption`:**
>
> Central-file class — a subject heading inside the State Department’s filing system, not a collection

---

##### 9.5 Your Library — the same questions asked of your own index › Your collections card — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

*`archival.library.collections.caption.v2 %lld %lld` · 06-Archives.md:779*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1565–1566 | key: archival.library.collections.caption.v2 %lld %lld -->

Matched from your own source notes against the archival authority list in the app. %1$lld notes cite the central files, which are filing systems rather than collections. Another %2$lld name something the list does not recognize. Neither group is listed here.

<!-- END SOURCE: archival.library.collections.caption.v2 %lld %lld -->

> **At your pass, under `archival.library.collections.caption %lld %lld`:**
>
> Matched from your own source notes against the archival authority list in the app. %1$lld notes cite the central files, which are a filing system rather than a collection. Another %2$lld name something the list does not recognize. Neither group is listed here.

---

##### 9.6 The info popover ("About Archival Analytics") › The three counts — detail

*`archival.info.weights.detail.v2` · 06-Archives.md:891*

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 345–346 | key: archival.info.weights.detail.v2 -->

Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. Unprinted pointers counts something else entirely: footnotes pointing at archival material that FRUS did not print. The first two measure where documents were drawn from; the third measures where FRUS historian sent readers to learn more. Because they reflect different editorial goals, they are never added together. Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no editorial footnotes pointing to unpublished documents, and about a hundred and ninety collections appear only under such footnotes, having supplied no printed document. A collection named only in a volume’s front matter has volumes but no documents.

<!-- END SOURCE: archival.info.weights.detail.v2 -->

> Same string also in §14 (Archival analytics — the three weights) — edit one copy only.

> **At your pass**, the sentences that changed:
>
> **Was:** Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and a hundred and eighty-one collections appear only under pointers, having supplied no printed document.
>
> **Now:** Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and about a hundred and ninety collections appear only under pointers, having supplied no printed document.

---

##### 9.6 The info popover ("About Archival Analytics") › Why Central Files is hidden — detail

*`archival.info.umbrella.detail.v3` · 06-Archives.md:913*

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 349–350 | key: archival.info.umbrella.detail.v3 -->

The State Department’s Central Files are cited by 158 volumes and supply more than eighteen thousand documents. That is over twice the next-largest collection, and its bar would flatten every other one. So it is hidden by default, and the chart states what it withheld. Turn the chip off to see it. The era-specific Central Files records are never hidden. Those records — Central Files 1964–66, 1967–69 and 1970–73 — are the Subject-Numeric File’s blocks of years, as the editors of later volumes cited them at the National Archives. Your Library counts the same citations under the Subject-Numeric File instead of listing them as collections.

<!-- END SOURCE: archival.info.umbrella.detail.v3 -->

> **At your pass, under `archival.info.umbrella.detail`:**
>
> The State Department’s Central Files are cited by 157 volumes and supply more than seventeen thousand documents. That is over twice the next-largest collection, and its bar would flatten every other one. So it is hidden by default, and the chart states what it withheld. Turn the chip off to see it. The era-specific Central Files records are never hidden.

---

##### 9.6 The info popover ("About Archival Analytics") › Your Library's rule — detail

*`archival.info.library.detail.v2` · 06-Archives.md:956*

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.library.detail.v2 -->

Only documents whose editors recorded where the original was found as a source note appear in this mode of browsing Your Library. Its total may be smaller than your indexed document count because volumes with no source notes add nothing. The collections list matches each citation to a named body of records; notes citing the central files — the decimal file, the Subject-Numeric File and the Central Foreign Policy File — cite a filing system rather than a collection and are counted in the composition instead. Your Library counts only what you have indexed, while Collections reflects bundled data and does not change with your downloads.

<!-- END SOURCE: archival.info.library.detail.v2 -->

> **At your pass, under `archival.info.library.detail`:**
>
> Only documents whose editors recorded where the original was found appear in Your Library. So its total is smaller than your indexed document count, and volumes with no source notes add nothing. The collections list matches each citation to a named body of records; notes citing the central files are a filing system rather than a collection and are counted in the composition instead. Your Library counts only what you have indexed — Collections does not, and does not change with your downloads.

---

##### 9.6 The info popover ("About Archival Analytics") › Collections and classes — detail

*`archival.info.units.detail.v3` · 06-Archives.md:976*

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 395–396 | key: archival.info.units.detail.v3 -->

A named collection is a body of records with a custodian. A central-file class is a subject heading inside one of the State Department’s central filing systems — 763.72 in the decimal file for the European War, POL 27 VIET S in the Subject-Numeric File for the war in South Vietnam. The two are never mixed in one ranking. Classes are ranked at one depth: a decimal file number stands for itself, while subject-numeric designators are grouped to their category and number, or to their category alone when they have no number, and a grouped row opens to the exact designators underneath it. Before 1948 the series cites classes far more than collections. After 1976 it barely cites classes at all.

<!-- END SOURCE: archival.info.units.detail.v3 -->

> **At your pass, under `archival.info.units.detail`:**
>
> A named collection is a body of records with a custodian. A central-file class is a subject heading inside one filing system — 763.72 for the European War, POL 27 VIET S for the war in South Vietnam. The two are never mixed in one ranking. Classes are ranked at one depth: a decimal file number stands for itself, while subject-numeric designators are grouped to their category and number, and a grouped row opens to the exact designators underneath it. Before 1948 the series cites classes far more than collections. After 1976 it barely cites classes at all.

---

#### 14. Short strings bumped since the build-42 pass — the parts about this area

##### Archival analytics — the three weights › Documents counts how many published documents came out of…

*`archival.info.weights.detail.v2` · 06-Archives.md:1830*

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 345–346 | key: archival.info.weights.detail.v2 -->

Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. Unprinted pointers counts something else entirely: editorial footnotes pointing at material there that FRUS did not print. The first two measure where FRUS historians found the documents they printed; the third measures where they sent readers to learn more. They are never added together because they measure different things. Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no editorial footnotes pointing to unpublished documents, and about a hundred and ninety collections appear only under such footnotes, having supplied no printed document. A collection named only in a volume’s front matter has volumes but no documents.

<!-- END SOURCE: archival.info.weights.detail.v2 -->

> Same string also in §9.6 — edit one copy only.

> **At your pass**, the sentences that changed:
>
> **Was:** Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and a hundred and eighty-one collections appear only under pointers, having supplied no printed document.
>
> **Now:** Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and about a hundred and ninety collections appear only under pointers, having supplied no printed document.

---

### 07 Search & Browse — changed

#### 7. Search & Result-Set Copy

##### 7.1 The Query Inspector

*`search.inspector.denominator %@` · 07-Search-and-Browse.md:35*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.denominator %@ -->

*Interpolated with the indexed-volume count, written by `CountCopy` (“1 volume”, “552 volumes”). Keep the placeholder.*

Counts are over the %@ indexed on this device — not the whole published series.

<!-- END SOURCE: search.inspector.denominator %@ -->

> **At your pass, under `search.inspector.denominator`:**
>
> Counts are over the %lld volumes indexed on this device — not the whole published series.

---

*`search.empty.denominator %@` · 07-Search-and-Browse.md:105*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.empty.denominator %@ -->

*Interpolated with the indexed-volume count, written by `CountCopy` (“1 volume”, “552 volumes”). Keep the placeholder.*

0 here means 0 in what you have indexed — %@ on this device.

<!-- END SOURCE: search.empty.denominator %@ -->

> **At your pass, under `search.empty.denominator`:**
>
> 0 here means 0 in what you have indexed — %lld volumes on this device.

---

##### 7.3 Facets › Subject facet — footer

*`search.subject.facet.footer` · 07-Search-and-Browse.md:504*

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 964–965 | key: search.subject.facet.footer -->

Choose a sub-category: categories themselves are headings, because each one reaches most of the series. The volume count beside each row says how many it selects, and the volume picker then fills with the matches you have indexed.

<!-- END SOURCE: search.subject.facet.footer -->

> **At your pass:**
>
> Experimental. These topics are experimental enrichment data, not editorial subject headings reviewed as part of the FRUS publication process, so some are wrong. Choose a sub-category: categories themselves are headings, because each one reaches most of the series. The volume count beside each row says how many it selects, and the volume picker then fills with the matches you have indexed.

---

##### 7.3 Facets › Subject facet — picker footer

*`search.subject.facet.picker.footer` · 07-Search-and-Browse.md:515*

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 1492–1493 | key: search.subject.facet.picker.footer -->

A volume appears when any document in it carries the subject — mentioned is enough. Categories are headings, not filters — every one of them reaches most of the series — so open a category and choose a sub-category, and check the volume count beside each. For finer subjects, browse the Subject index.

<!-- END SOURCE: search.subject.facet.picker.footer -->

> **At your pass:**
>
> Detected topics (experimental). These are inferred from the text, not editorial subject headings, so some are wrong. A volume appears when any document in it carries the topic — mentioned is enough. Categories are headings, not filters — every one of them reaches most of the series — so open a category and choose a sub-category, and check the volume count beside each. For finer topics, browse the Topic index.

---

##### 7.5 Collocation — the words near your term

*`search.collocation.unavailable.languageAnalysis` · 07-Search-and-Browse.md:569*

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.languageAnalysis -->

*Added by #1373. Shown when this device's lemmatiser failed its check. Reworded by #1539: the app now checks again each time it becomes active, and the panel rebuilds when a check finds the lemmatiser working.*

*Since #1608 (2026-10-12) a reader should not meet it. With no lemmatiser the panel now counts the neighbors as printed and ranks them against a second corpus reference that was counted as printed, under the note in the next block. This sentence is left for a launch on which that second reference could not be loaded. Its text is unchanged.*

This device’s language analysis isn’t reducing words to their dictionary forms right now, so the words near your matches can’t be compared with the bundled corpus reference. FRUS Explorer checks again each time you come back to it, and this panel updates if it recovers; if it doesn’t, quitting and reopening FRUS Explorer may restore it.

<!-- END SOURCE: search.collocation.unavailable.languageAnalysis -->

> **At your pass:**
>
> This device’s language analysis isn’t reducing words to their dictionary forms right now, so the words near your matches can’t be compared with the corpus reference, which was counted that way. Quitting and reopening FRUS Explorer may restore it.

---

*`search.collocation.caveat.bounded.v3 %@ %@` · 07-Search-and-Browse.md:607*

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | CollocationCaveatCopy.bounded | key: search.collocation.caveat.bounded.v3 %@ %@ -->

*Interpolated with the scanned and total counts, grouped since #1683 (`.v2` printed them through `%lld`, as "1204"). A scan that stopped short of its results had at least two, so “results” has no form for one.*

The scan stopped at %1$@ of your %2$@ results, so this ranking covers part of them, not all.

<!-- END SOURCE: search.collocation.caveat.bounded.v3 %@ %@ -->

> **At your pass, under `search.collocation.caveat.bounded.v2 %lld %lld`:**
>
> The scan stopped at %lld of your %lld results, so this ranking covers part of them, not all.

---

##### 7.11 Compacting the search index

*`related.why.cohort %@ %@` · 07-Search-and-Browse.md:1241*

<!-- SOURCE: FRUSCoreKit/RelatedDocuments/SimilarityModel.swift | RelatedDocumentsCounts.cohort | lines: 383–384 | key: related.why.cohort %@ %@ -->

*The archival “why related” chip (#644). Interpolated with the container name and its size, which is
grouped since #1586 (“1 of 1,063”).
Replaces a bare “same provenance”, which read identically for a lot file holding two documents and
for Nixon’s NSC Files holding 7,056 — and that difference is what tells a researcher whether sharing
the container is a finding or a filing-cabinet coincidence.*

%1$@ · 1 of %2$@

<!-- END SOURCE: related.why.cohort %@ %@ -->

> **At your pass, under `related.why.cohort %@ %lld`:**
>
> *The archival “why related” chip (#644). Interpolated with the container name and its size.
> Replaces a bare “same provenance”, which read identically for a lot file holding two documents and
> for Nixon’s NSC Files holding 7,056 — and that difference is what tells a researcher whether sharing
> the container is a finding or a filing-cabinet coincidence.*
>
> %@ · 1 of %lld

---

##### 7.12 Semantic search fallback (V-5 s3)

*The card's Download Search Model button starts the download (B4, 2026-10-15); through build 50 it opened the consent sheet, §1.4c, now retired with the Gemma Terms.*

*`search.semantic.offer.body` · 07-Search-and-Browse.md:1259*

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchSharedViews.swift | property: SemanticModelOfferCard | lines: 148–149 | key: search.semantic.offer.body -->

Keyword search found nothing, but the app can also search by what an AI model detects your question to mean — including questions whose words never appear in the documents. This needs a one-time 310 MB model download that runs entirely on this device.

<!-- END SOURCE: search.semantic.offer.body -->

> **At your pass:**
>
> Keyword search found nothing, but the app can also search by what an AI model detects your question to mean — including questions whose words never appear in the documents. This needs a one-time 229 MB model download that runs entirely on this device.

---

##### 7.13 Search Tips › Where the tips open › More menu hint (iOS)

*`search.moreActions.help.v4` · 07-Search-and-Browse.md:1825*

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | SearchView.moreMenu .controlHelp detail | lines: 1665–1666 | key: search.moreActions.help.v4 -->

*The VoiceOver hint and Large Content Viewer detail for the More menu. It lists the menu's contents, so it is re-keyed whenever an item joins: `.v2` named the abbreviation lookup and the tips, `.v3` added Select Results (#1576), and `.v4` adds Search Within These Results (#1577 lane 4).*

Save this search or its results, select results to act on several at once, search within these results, revisit saved searches, find a document by citation, look up an abbreviation, or read the search tips

<!-- END SOURCE: search.moreActions.help.v4 -->

> **At your pass, under `search.moreActions.help.v2`:**
>
> Save this search or its results, revisit saved searches, find a document by citation, look up an abbreviation, or read the search tips

---

#### 16. Browse — the axis captions

##### 16.3 Administrations › The drill-in caption

*`browser.administrations.drill.caption.v2 %@ %@ %@` · 07-Search-and-Browse.md:2624*

<!-- SOURCE: FRUSExplorer/Browser/AdministrationIndexView.swift | lines: 140–141 | key: browser.administrations.drill.caption.v2 %@ %@ %@ -->

%1$@ with documents covering the %2$@ administration (%3$@), most documents first. Membership: any dated document. A volume spanning two administrations appears under both.

<!-- END SOURCE: browser.administrations.drill.caption.v2 %@ %@ %@ -->

> **At your pass, under `browser.administrations.drill.caption`:**
>
> \(profile.volumes.count) volumes with documents covering the \(profile.president) administration (\(termText(start: profile.start, end: profile.end))), largest share first. Membership: any dated document. A volume spanning two administrations appears under both.

---

##### 16.4 Subjects › The coverage statement

*`subjects.index.coverage.v2 %lld %lld` · 07-Search-and-Browse.md:2651*

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | lines: 489–490 | key: subjects.index.coverage.v2 %lld %lld -->

%1$lld subjects across the whole series. Counts describe all %2$lld cataloged volumes, not the volumes you have indexed — a search reaches only what is on this device.

<!-- END SOURCE: subjects.index.coverage.v2 %lld %lld -->

> **At your pass:**
>
> %1$lld assigned topics across the whole series. Counts describe all %2$lld cataloged volumes, not the volumes you have indexed — a search reaches only what is on this device. Topics are drawn from experimental enrichment data, not editorial subject headings, so some are wrong.

---

##### 16.4 Subjects › The subject-area chip (#1365)

*`subjects.index.groupFilter.all.one %@` · 07-Search-and-Browse.md:2665*

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexGrouping.groupFilterCaption | lines: 318–319 | key: subjects.index.groupFilter.all.one %@ -->

Subject area: %@ — 1 subject

<!-- END SOURCE: subjects.index.groupFilter.all.one %@ -->

> **At your pass:**
>
> Topic area: %@ — 1 topic

---

*`subjects.index.groupFilter.all.many %@ %@` · 07-Search-and-Browse.md:2671*

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexGrouping.groupFilterCaption | lines: 321–322 | key: subjects.index.groupFilter.all.many %@ %@ -->

Subject area: %1$@ — %2$@ subjects

<!-- END SOURCE: subjects.index.groupFilter.all.many %@ %@ -->

> **At your pass:**
>
> Topic area: %1$@ — %2$@ topics

---

*`subjects.index.groupFilter.some.one %@ %@` · 07-Search-and-Browse.md:2677*

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexGrouping.groupFilterCaption | lines: 326–327 | key: subjects.index.groupFilter.some.one %@ %@ -->

Subject area: %1$@ — %2$@ of 1 subject

<!-- END SOURCE: subjects.index.groupFilter.some.one %@ %@ -->

> **At your pass:**
>
> Topic area: %1$@ — %2$@ of 1 topic

---

*`subjects.index.groupFilter.some.many %@ %@ %@` · 07-Search-and-Browse.md:2683*

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexGrouping.groupFilterCaption | lines: 329–330 | key: subjects.index.groupFilter.some.many %@ %@ %@ -->

Subject area: %1$@ — %2$@ of %3$@ subjects

<!-- END SOURCE: subjects.index.groupFilter.some.many %@ %@ %@ -->

> **At your pass:**
>
> Topic area: %1$@ — %2$@ of %3$@ topics

---

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.1 Search — scope footers, prompts, Meaning mode, facets and collocations › Subject data covers \(…) of \(…) matches.

*`facets.subjects.coverage` · 07-Search-and-Browse.md:2771*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.subjectsCaveat | lines: 1218–1219 | key: facets.subjects.coverage -->

Subject data covers \(facets.subjectCoverage.formatted()) of \(facets.matchCount.formatted()) matches.

<!-- END SOURCE: facets.subjects.coverage -->

> **At your pass:**
>
> Subjects detected for \(facets.subjectCoverage.formatted()) of \(facets.matchCount.formatted()) matches.

---

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › Tooltip — Browse an index of the subjects across the whole series…

*`browser.corpus.subjects.help` · 07-Search-and-Browse.md:3048*

<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | CorpusView.crossVolumeIndicesSection | lines: 358–359 | key: browser.corpus.subjects.help -->

Browse an index of the subjects across the whole series — including volumes you have not downloaded. Tap one to see its reach and find documents on it

<!-- END SOURCE: browser.corpus.subjects.help -->

> **At your pass:**
>
> Browse an index of the topics detected across the whole series — including volumes you have not downloaded. Tap one to see its reach and find documents on it

---

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › Empty state — The subject index did not load, so subjects cannot be…

*`subjects.index.unavailable.message` · 07-Search-and-Browse.md:3097*

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectIndexView.unavailableSection | lines: 523–524 | key: subjects.index.unavailable.message -->

The subject index did not load, so subjects cannot be browsed. Everything else in the app is unaffected.

<!-- END SOURCE: subjects.index.unavailable.message -->

> **At your pass:**
>
> The detected-topic index did not load, so topics cannot be browsed. Everything else in the app is unaffected.

---

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › Footer — The first three figures describe the whole series…

*`subjects.detail.footer` · 07-Search-and-Browse.md:3105*

<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | SubjectDetailSheet.body | lines: 622–623 | key: subjects.detail.footer -->

The first three figures describe the whole series, including volumes you have not downloaded. Only the last one is what a search here can return.

<!-- END SOURCE: subjects.detail.footer -->

> **At your pass:**
>
> The first three figures describe the whole series, including volumes you have not downloaded. Only the last one is what a search here can return. Topics are detected automatically from the text, not editorial subject headings.

---

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › No subjects for this volume yet. The Office of the Historian’s…

*`browser.volume.subjects.none` · 07-Search-and-Browse.md:3140*

<!-- SOURCE: FRUSExplorer/Browser/VolumeSubjectsView.swift | VolumeSubjectsChips.body | lines: 81–82 | key: browser.volume.subjects.none -->

No subjects for this volume yet. The Office of the Historian’s experimental subject data, not published on history.state.gov, does not cover it.

<!-- END SOURCE: browser.volume.subjects.none -->

> **At your pass:**
>
> No subjects detected for this volume yet. The topic data is the Office of the Historian's own subject export, and it does not cover this volume.

---

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › Ranks the collections and file series the %lld volumes…

*`browser.volume.subjectVolumes.archival.footer %lld` · 07-Search-and-Browse.md:3148*

<!-- SOURCE: FRUSExplorer/Browser/VolumeSubjectsView.swift | VolumeSubjectVolumesSheet.archivalProfileSection | lines: 357–358 | key: browser.volume.subjectVolumes.archival.footer %lld -->

Ranks the collections and file series the %lld volumes covering this subject draw on. The scope is whole volumes, not the documents about this subject inside them.

<!-- END SOURCE: browser.volume.subjectVolumes.archival.footer %lld -->

> **At your pass:**
>
> Ranks the collections and file series the %lld volumes covering this subject draw on. The scope is whole volumes, not the documents about this subject inside them — and the subjects themselves are detected automatically, not editorial headings.

---

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › Footer — Shows this subject’s reach across the whole series, and finds…

*`browser.volume.subjectVolumes.explore.footer` · 07-Search-and-Browse.md:3155*

<!-- SOURCE: FRUSExplorer/Browser/VolumeSubjectsView.swift | VolumeSubjectVolumesSheet.subjectExplorerSection | lines: 381–382 | key: browser.volume.subjectVolumes.explore.footer -->

Shows this subject’s reach across the whole series, and finds the documents on it that you have indexed.

<!-- END SOURCE: browser.volume.subjectVolumes.explore.footer -->

> **At your pass:**
>
> Shows this topic’s reach across the whole series, and finds the documents on it that you have indexed.

---

### 08 Reading, Research & Collections — changed

#### 10. Export Method Statements

##### 10.1 Archival Analytics › The class lens's grain sentence

*`archival.export.caveat.grain.v2` · 08-Reading-Research-Collections.md:1192*

<!-- SOURCE: FRUSCoreKit/Analytics/Export/ArchivalAnalyticsExport.swift | grainCaveat | lines: 77–78 | key: archival.export.caveat.grain.v2 -->

Grain: central-file rows are one unit deep. A decimal file number (763.72) stands for itself; subject-numeric designators are grouped to their category and number (POL 27 VIET S and POL 27 ARAB-ISR both count under POL 27), or to their category alone when they have no number (POL US-USSR counts under POL). A grouped row’s own leaves, with their counts, are listed under the chart in the app. A volume citing two designators in one group counts once for the group.

<!-- END SOURCE: archival.export.caveat.grain.v2 -->

> **At your pass, under `archival.export.caveat.grain`:**
>
> Grain: central-file rows are one unit deep. A decimal file number (763.72) stands for itself; subject-numeric designators are grouped to their category and number (POL 27 VIET S and POL 27 ARAB-ISR both count under POL 27), because at full length half of them carry a single document. A grouped row’s own leaves, with their counts, are listed under the chart in the app. A volume citing two designators in one group counts once for the group.

---

#### 14. Short strings bumped since the build-42 pass — the parts about this area

##### Where an export says what it drew on › provenance.source.ohPeople

*`provenance.source.ohPeople` · 08-Reading-Research-Collections.md:1604*

<!-- SOURCE: FRUSCoreKit/Provenance/ProvenanceSource.swift | lines: 115–116 | key: provenance.source.ohPeople | shared: iOS+macOS (single edit point) -->

FRUS + OH people data

<!-- END SOURCE: provenance.source.ohPeople -->

> **At your pass:**
>
> FRUS + OH people register

---

##### Where an export says what it drew on › provenance.partner.ohPeople

*`provenance.partner.ohPeople` · 08-Reading-Research-Collections.md:1681*

<!-- SOURCE: FRUSCoreKit/Provenance/ProvenanceSource.swift | lines: 163–164 | key: provenance.partner.ohPeople | shared: iOS+macOS (single edit point) -->

the Office of the Historian's working data for people (its HistoryAtState/people repository) and its Principal Officers and Chiefs of Mission

<!-- END SOURCE: provenance.partner.ohPeople -->

> **At your pass:**
>
> the Office of the Historian's people register

---

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › Most distinctive first. (after the subject data's caption)

*`panel.subjects.caveat` · 08-Reading-Research-Collections.md:2417*

<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | ResearchRailView.subjectsAccordion | lines: 420–421 | key: panel.subjects.caveat -->

Most distinctive first.

<!-- END SOURCE: panel.subjects.caveat -->

> **At your pass:**
>
> Detected automatically from the text, not editorial subject headings — so some are wrong. Most distinctive first.

---

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › Ranked from the first %1$@ of %2$@ documents that share…

*`related.poolCut %@ %@` · 08-Reading-Research-Collections.md:2453*

<!-- SOURCE: FRUSCoreKit/RelatedDocuments/SimilarityModel.swift | RelatedDocumentsCounts.poolCut | lines: 400–401 | key: related.poolCut %@ %@ -->

Ranked from the first %1$@ of %2$@ documents that share this anchor’s archival container. The rest were not scored. Narrow the scope to reach them.

<!-- END SOURCE: related.poolCut %@ %@ -->

> **At your pass, under `related.poolCut %lld %lld`:**
>
> Ranked from the first %1$lld of %2$lld documents that share this anchor’s archival container. The rest were not scored. Narrow the scope to reach them.

---

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › At least %1$@ documents in %2$@ you have not downloaded…

*`related.offIndex.caption.capped %@ %@` · 08-Reading-Research-Collections.md:2476*

<!-- SOURCE: FRUSCoreKit/RelatedDocuments/SimilarityModel.swift | RelatedDocumentsCounts.offIndexCaption | lines: 425–426 | key: related.offIndex.caption.capped %@ %@ -->

*The opening sentence of Related Documents' Beyond your library section when the scan stopped at its cap of 4,096 documents, so the count is a floor: "At least 4,096 documents in 12 volumes you have not downloaded read as close…". `%1$@` is the number of documents and `%2$@` the volumes with their noun, "1 volume" or "12 volumes". Until #1618 the two numbers were not grouped and this read "At least 4096 documents".*

At least %1$@ documents in %2$@ you have not downloaded read as close to this one as the matches ranked above.

<!-- END SOURCE: related.offIndex.caption.capped %@ %@ -->

> **At your pass, under `related.offIndex.caption.capped %lld %lld`:**
>
> At least %1$lld documents in %2$lld volumes you have not downloaded read as close to this one as the matches ranked above.

---

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › %1$@ document in %2$@ you have not downloaded reads as…

*`related.offIndex.caption.one %@ %@` · 08-Reading-Research-Collections.md:2485*

<!-- SOURCE: FRUSCoreKit/RelatedDocuments/SimilarityModel.swift | RelatedDocumentsCounts.offIndexCaption | lines: 431–432 | key: related.offIndex.caption.one %@ %@ -->

*The same sentence for exactly one document: "1 document in 1 volume you have not downloaded reads as close…". Until #1618 there was one form for every count, and it read "1 documents in 1 volumes … read as close".*

%1$@ document in %2$@ you have not downloaded reads as close to this one as the matches ranked above.

<!-- END SOURCE: related.offIndex.caption.one %@ %@ -->

*`related.offIndex.caption.many %@ %@` · 08-Reading-Research-Collections.md:2494*

<!-- SOURCE: FRUSCoreKit/RelatedDocuments/SimilarityModel.swift | RelatedDocumentsCounts.offIndexCaption | lines: 433–434 | key: related.offIndex.caption.many %@ %@ -->

*The same sentence for any other count: "94 documents in 19 volumes you have not downloaded read as close…". `%2$@` is the volumes with their noun, so many documents in one volume read "1,204 documents in 1 volume".*

%1$@ documents in %2$@ you have not downloaded read as close to this one as the matches ranked above.

<!-- END SOURCE: related.offIndex.caption.many %@ %@ -->

> **At your pass, one block for every count, `related.offIndex.caption %lld %lld`:**
>
> %1$lld documents in %2$lld volumes you have not downloaded read as close to this one as the matches ranked above.

---

### 09 Settings & app-wide messages — changed

#### 6. Settings, Tips & Collections

##### Volumes & Storage (Library) › Storage & Index footer

*`settings.hub.storageIndex.footer` · 09-Settings-and-App.md:269*

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | storageAndIndexSection footer | lines: 584–585 | key: settings.hub.storageIndex.footer | shared: iOS (macOS carries the same text separately) -->

Notes, highlights, and tags are never affected. For reference: the full FRUS corpus is roughly 3.3 GB of XML plus 3 to 3.5 GB of search index.

<!-- END SOURCE: settings.hub.storageIndex.footer -->

> **At your pass:**
>
> Notes, highlights, and tags are never affected. For reference: the full FRUS corpus is roughly 3.4 GB of XML plus 9–10 GB of search index.

---

##### Volumes & Storage (Library) › Free Up Space — size-estimate note

*`settings.hub.freeUp.estimateNote` · 09-Settings-and-App.md:315*

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | FreeUpSpaceSheet | lines: 1736–1737 | key: settings.hub.freeUp.estimateNote | shared: iOS (macOS carries the same text separately) -->

Each size is the XML file plus an estimate of its share of the search index, 0.86 times the XML. That ratio comes from the full corpus: about 2.9 GB of index for about 3.3 GB of XML. Per volume it runs from roughly 0.7 to 1 times, so treat these sizes as approximate.

<!-- END SOURCE: settings.hub.freeUp.estimateNote -->

> **At your pass:**
>
> Each size is the XML file plus an estimated 2.8× for its share of the search index. That ratio comes from the full corpus: about 9–10 GB of index for about 3.4 GB of XML. Per volume the overhead runs from roughly 2.5× to 3×, so treat these sizes as approximate.

---

##### Data & Recovery (System) › Research-data export — JSON footer

*`settings.export.json.footer.searches` · 09-Settings-and-App.md:546*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections JSON section footer | key: settings.export.json.footer.searches | shared: iOS+macOS (single edit point — hosted by Data & Recovery on both) -->

One JSON file with your notes, tags, highlights, collections, custom prompts, projects, archive visit plans, saved searches, working corpora, volume scopes, corrections, reviewed changes, Suggested Next leads, and synced settings. It also holds your research trail: every document you opened, every search you ran and how many results it returned, and every collection you exported.

<!-- END SOURCE: settings.export.json.footer.searches -->

> **At your pass, under `settings.export.json.footer.visits`:**
>
> One JSON file with your notes, tags, highlights, collections, custom prompts, projects, and archive visit plans. It also holds your research trail: every document you opened, every search you ran and how many results it returned, and every collection you exported.

---

##### Discovery Tips (TipKit) › Tip — Facet Rows Are Filters

*`tip.facetNarrow.message` · 09-Settings-and-App.md:1470*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | FacetNarrowTip.message | key: tip.facetNarrow.message | shared: iOS+macOS (single edit point) -->

Select a person, a document type or a subject to narrow your search to it. In Years and Volumes, select rows and then Apply. Each narrowing becomes a chip you can clear; the counts always describe the whole match, before any narrowing.

<!-- END SOURCE: tip.facetNarrow.message -->

> **At your pass:**
>
> Select any year, volume or person to narrow your search to it — it becomes a chip you can clear. The counts themselves always describe the whole match, before any narrowing.

---

#### 14. Short strings bumped since the build-42 pass — the parts about this area

##### Menus, tooltips, and short labels › Colors group collections by who holds the records — four…

*`series.provenance.topCollections.method.v4 %lld %lld` · 09-Settings-and-App.md:1679*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | lines: 307–308 | key: series.provenance.topCollections.method.v4 %lld %lld -->

Colors group collections by who holds the records — four custodians, not the eleven categories above, which classify the citation rather than its holder. Eras here are coarser than the decades above, so a year range ending mid-era still covers the whole era. Document counts come from an index covering all %1$lld cataloged volumes with no 1900 floor, so a row here can rest on volumes the charts above leave out; the collection names come from a cross-volume authority that reaches %2$lld of them. The Categories filter above does not apply to this ranking.

<!-- END SOURCE: series.provenance.topCollections.method.v4 %lld %lld -->

> **At your pass, under `series.provenance.topCollections.method.v3 %lld %lld`:**
>
> Colors group collections by who holds the records — four custodians, not the ten categories above, which classify the citation rather than its holder. Eras here are coarser than the decades above, so a year range ending mid-era still covers the whole era. Document counts come from an index covering all %1$lld cataloged volumes with no 1900 floor, so a row here can rest on volumes the charts above leave out; the collection names come from a cross-volume authority that reaches %2$lld of them. The Categories filter above does not apply to this ranking.

---

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.13 Settings › \(…) · \(…) of XML, plus about as much again in search index.…

*`settings.hub.browse.corpus.detail` · 09-Settings-and-App.md:2107*

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | MacDownloadVolumesSheet.corpusDetail | lines: 1620–1621 | key: settings.hub.browse.corpus.detail | shared: iOS+macOS (one text on both hubs since #1483; VolumesStorageHubView.swift declares it too, in DownloadVolumesBrowseView.scopeFooter) | same text also in: FRUSExplorer/Settings/VolumesStorageHubView.swift -->

\(HubCopy.volumes(allVolumes.count)) · \(xml) of XML, plus about as much again in search index. Downloads run in the background and resume across launches.

<!-- END SOURCE: settings.hub.browse.corpus.detail -->

> **At your pass:**
>
> \(HubCopy.volumes(allVolumes.count)) · \(xml) of XML, plus roughly 2.8× that in search index. Downloads run in the background and resume across launches.

---

##### 18.13 Settings › Footer — How many colors the Chronology and Corpus Analytics charts…

*`settings.display.chartColors.footer.v2` · 09-Settings-and-App.md:2175*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView.body | lines: 1719–1720 | key: settings.display.chartColors.footer.v2 -->

How many colors the Chronology and Corpus Analytics charts use for their volumes. When more volumes contribute than there are colors, the last color is a gray “Other volumes” holding the rest, so a chart names one volume fewer than its colors. Each chart can override this per view.

<!-- END SOURCE: settings.display.chartColors.footer.v2 -->

> **At your pass, under `settings.display.chartColors.footer`:**
>
> How many volumes appear as distinct colors in the Chronology and Corpus Analytics charts before the rest fold into a single “Other” series. Each chart can override this per view.

---

## Part 2 — New since your pass (577)

### 01 About & Onboarding — new

#### 1. About Screen

##### 1.4e Open Source — EmbeddingGemma 2 Notice

*The last row of the Open Source section, under the bold "EmbeddingGemma 2" label; the row links to the model's page on Hugging Face. It replaced §1.4b on 2026-10-15 (B4): EmbeddingGemma 2 is licensed under Apache 2.0, so the model is named and its licence stated, as llama.cpp's is.*

*`about.openSource.embeddingGemma.body` · 01-About-and-Onboarding.md:119*

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: openSourceSection | lines: 637–638 | key: about.openSource.embeddingGemma.body -->

Natural-language search runs Google’s EmbeddingGemma 2 model on this device, an optional download used unmodified. Licensed under the Apache License, Version 2.0.

<!-- END SOURCE: about.openSource.embeddingGemma.body -->

### 05 Analytics — new

#### 5. Analytics — Explanatory Captions & Info Popovers

##### About the Graph popover › The node menu’s open item — Mac, and iPhone and iPad

*`graph.contextMenu.openDocument` · 05-Analytics.md:125*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.openDocumentActionName | lines: 1533–1533 | key: graph.contextMenu.openDocument | shared: macOS -->

Open in Main Window

<!-- END SOURCE: graph.contextMenu.openDocument -->

*`graph.contextMenu.openDocument.ios` · 05-Analytics.md:131*

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.openDocumentActionName | lines: 1535–1535 | key: graph.contextMenu.openDocument.ios | shared: iOS -->

View Document

<!-- END SOURCE: graph.contextMenu.openDocument.ios -->

##### Analytics Export — Word Cloud caveats › Counted as printed

*`wordcloud.export.caveat.keyness.comparedAsPrinted` · 05-Analytics.md:963*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.comparedAsPrintedCaveat | lines: 228–229 | key: wordcloud.export.caveat.keyness.comparedAsPrinted | shared: iOS+macOS (single edit point) -->

Keyness reference: because these words were counted as printed, each was scored against a reference for the whole FRUS corpus that was counted as printed too. A device whose language analysis reduces words to their dictionary forms (a Mac, or another iPhone or iPad) scores dictionary forms against a reference counted in dictionary forms, so its keyness table for this scope can differ from this one.

<!-- END SOURCE: wordcloud.export.caveat.keyness.comparedAsPrinted -->

*`wordcloud.export.caption.comparedAsPrinted` · 05-Analytics.md:969*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.printedFormsCaptionSegment | lines: 258–259 | key: wordcloud.export.caption.comparedAsPrinted | shared: iOS+macOS (single edit point) -->

counted and compared as printed on this device; another device may count and compare differently

<!-- END SOURCE: wordcloud.export.caption.comparedAsPrinted -->

#### 12. Word Cloud — Keyness and its Reference

##### 12.3 The keyness export › Axis label

*Added by #1608. The axis label of a Distinctive export whose words were counted as printed and scored against the reference counted as printed.*

*`wordcloud.export.axis.keyness.printed` · 05-Analytics.md:1125*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.keynessAxisLabel | lines: 236–237 | key: wordcloud.export.axis.keyness.printed -->

Ranked by keyness (log-likelihood) against the bundled FRUS corpus reference, both counted as printed

<!-- END SOURCE: wordcloud.export.axis.keyness.printed -->

##### 12.4 Empty states › Counted and compared as printed

*Added by #1608 (2026-10-12). The same caption's place under the cloud's title, when the cloud is sized by Distinctive and its words were counted without the device's lemmatiser: they are then compared with a corpus reference counted as printed, where Distinctive used to be withheld. It says the three things the owner's condition asks: that the cloud fell back, why, and that the ranking can differ on another device. The example is a verb because a printed count still folds a regular plural by rule while* Merge plural and singular forms *is on.*

*`wordcloud.keyness.comparedAsPrinted` · 05-Analytics.md:1361*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.comparedAsPrintedNote | lines: 207–208 | key: wordcloud.keyness.comparedAsPrinted -->

Counted and compared as printed: this device isn’t reducing words to their dictionary forms right now, so “negotiate” and “negotiated” are two words, here and in the corpus reference. A device that does reduce them (a Mac, or another iPhone or iPad) can rank these words differently.

<!-- END SOURCE: wordcloud.keyness.comparedAsPrinted -->

#### 13. Semantic Analytics — the map, its regions, its slices, and its vectors

##### 13.8 Settings ▸ Data & Recovery ▸ Semantic Match Feedback › The mail draft's subject

*Added for #1545 (2026-10-18). Email Feedback File opens Mail with this subject, the file attached and feedback@frusexplorer.app filled in; the reader sends it, changes it or throws it away.*

*`settings.semanticFeedback.mail.subject` · 05-Analytics.md:1794*

<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 264–265 | key: settings.semanticFeedback.mail.subject -->

FRUS Explorer Semantic Match Feedback

<!-- END SOURCE: settings.semanticFeedback.mail.subject -->

##### 13.8 Settings ▸ Data & Recovery ▸ Semantic Match Feedback › The mail draft's body

*Added for #1545 (2026-10-18). `\(version)` is the app's version and build, as About writes them: 1.0 (1861).*

*`settings.semanticFeedback.mail.body` · 05-Analytics.md:1803*

<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 266–267 | key: settings.semanticFeedback.mail.body -->

My Semantic Match Feedback verdicts from FRUS Explorer \(version) are attached.

<!-- END SOURCE: settings.semanticFeedback.mail.body -->

### 06 Archives — new

#### 11. Source Explorer — Panel Prose

##### 11.2 Central files — decimal and subject-numeric › Requesting a Subject-Numeric File record from NARA

*#1543: a Subject-Numeric citation (February 1963–1973) has its own panel in every wording, through the Department or through the National Archives. Its rows are short labels with no block: “State Dept. Subject-Numeric File (February 1963–1973)”, “File Designation”, “File Years” and, for the Filing Period row, “February 1963–1973 (Subject-Numeric File)”.*

*`source.explorer.subjectNumeric.cite.note` · 06-Archives.md:1234*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 680–681 | key: source.explorer.subjectNumeric.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

To request the original record from NARA, you will need the file designation above and the block of years it was filed in (1963, 1964–66, 1967–69 or 1970–73). Add any telegram or airgram number, the from/to information, and the document’s date from the source note. NARA asks that a central-file citation name the file designation, not a folder or a box.

<!-- END SOURCE: source.explorer.subjectNumeric.cite.note -->

##### 11.2 Central files — decimal and subject-numeric › Where the Subject-Numeric File's handbooks and box lists are

*The second sentence is yours, from the decimal-file hint above.*

*`source.explorer.subjectNumeric.hint` · 06-Archives.md:1246*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 731–732 | key: source.explorer.subjectNumeric.hint | shared: iOS+macOS (the same key in both views — edit both) -->

The filing handbooks are on the linked NARA page: the 1963 handbook for 1963 and the 1965 handbook for 1964–1973. Box lists are available on-site at the National Archives at College Park.

<!-- END SOURCE: source.explorer.subjectNumeric.hint -->

##### 11.4 Presidential libraries and other repositories › A named file series the citation places with an agency

*Mac. New in build 49 (#1514): a Department of State series that is not the central files (the INR/IL, INR–NIE, Bundy and USUN files) and another agency's own series (`National Security Council, Carter Intelligence Files`) name their holder, so "does not state the holding repository" was false for them. Interpolated with the agency — the Department of State, the National Security Council, the Department of Defense. Keep the `\(holder)` placeholder; the sentence supplies "the" before it. Beside this note the provenance column no longer offers the link "Department of State records at the National Archives" (review round 1): the citation places the Department's own series it names with the Department and does not say whether any was accessioned since, and another agency's are not State records.*

*`source.explorer.namedSeries.note.held` · 06-Archives.md:1532*

<!-- SOURCE: FRUSCoreKit/SourceExplorer/NamedFileSeriesRouting.swift | lines: 326–327 | key: source.explorer.namedSeries.note.held -->

A file series the citation attributes generally to the \(holder), cited without a lot number, so no automated NARA Catalog query is available.

<!-- END SOURCE: source.explorer.namedSeries.note.held -->

##### 11.4 Presidential libraries and other repositories › What a named file series is, when the citation names its agency

*iPhone and iPad. New in build 49 (#1514), the twin of the Mac block above. Keep the `\(holder)` placeholder. Under it the panel no longer offers the link "Department of State records at the National Archives" (review round 1), as on the Mac.*

*`source.explorer.namedSeries.explainer.held` · 06-Archives.md:1556*

<!-- SOURCE: FRUSCoreKit/SourceExplorer/NamedFileSeriesRouting.swift | lines: 316–317 | key: source.explorer.namedSeries.explainer.held -->

A file series the citation attributes generally to the \(holder), cited without a lot number.

<!-- END SOURCE: source.explorer.namedSeries.explainer.held -->

##### 11.8 Related collections › A Subject-Numeric citation, and no other document matched to its file

*Shown under the Subject-Numeric File panel when the Archival Neighbors list is empty and the citation's file (`POL 27 VIET S`) was searched for: a note worded through the Department whose designation the app stored, or one worded through the National Archives whose designation the app reads as a class.*

*`source.explorer.related.empty.subjectNumeric` · 06-Archives.md:1792*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2553–2554 | key: source.explorer.related.empty.subjectNumeric | shared: iOS+macOS (the same key in both views — edit both) -->

This source note cites the Subject-Numeric File. No other indexed document was matched to the same file. Index more volumes to surface related documents.

<!-- END SOURCE: source.explorer.related.empty.subjectNumeric -->

##### 11.8 Related collections › A Subject-Numeric citation the app cannot match on

*Shown under the same panel when there was nothing to search for: a designation the app does not read as a class (`POL FR-US`, `ORG 4–COMM`, `AID (US) S VIET`), a citation that gives only its block of years, or a note whose first sentence the app reads another way. Indexing more volumes does not change it.*

*`source.explorer.related.empty.subjectNumeric.unkeyed` · 06-Archives.md:1804*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2556–2557 | key: source.explorer.related.empty.subjectNumeric.unkeyed | shared: iOS+macOS (the same key in both views — edit both) -->

This source note cites the Subject-Numeric File, but not in a form the app can match on, so documents from the same file can’t be matched.

<!-- END SOURCE: source.explorer.related.empty.subjectNumeric.unkeyed -->

#### 15. Archives Visits — the research-trip planner

##### 15.4 Targets — tiers, orphans, substitution › A stored target now part of another

*`archiveVisit.superseded.caption %@` · 06-Archives.md:2120*

<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1224–1225 | key: archiveVisit.superseded.caption %@ -->

Stored target — now part of “%@”, which shows another stored row’s tier, note and exclusion. Kept with your tier and notes; it never deletes itself.

<!-- END SOURCE: archiveVisit.superseded.caption %@ -->

##### 15.4 Targets — tiers, orphans, substitution › …when it had excluded its own target

*`archiveVisit.superseded.excluded` · 06-Archives.md:2129*

<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1229–1230 | key: archiveVisit.superseded.excluded -->

Excluded from the packet when it was a target of its own.

<!-- END SOURCE: archiveVisit.superseded.excluded -->

##### 15.4 Targets — tiers, orphans, substitution › A lot stated apart inside a target

*`archiveVisit.target.lot %@ %@` · 06-Archives.md:2156*

<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 993–994 | key: archiveVisit.target.lot %@ %@ -->

Lot %1$@ — %2$@

<!-- END SOURCE: archiveVisit.target.lot %@ %@ -->

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.3 Archival Analytics › Files with no subject number

*The reading beside a family that is a category alone, such as `POL` or `AID (US)`, in the Central-file classes ranking and in the Network's subject-numeric families (index version 69). Its files are the ones cited with a category and a country and no subject number between them, `POL US-USSR`; each is listed under the family with its country.*

*`archival.classLabel.noSubjectNumber` · 06-Archives.md:2318*

<!-- SOURCE: FRUSCoreKit/Analytics/SubjectNumericLabelTable.swift | SubjectNumericLabelTable.gloss | lines: 235–236 | key: archival.classLabel.noSubjectNumber -->

Files with no subject number

<!-- END SOURCE: archival.classLabel.noSubjectNumber -->

### 07 Search & Browse — new

#### 7. Search & Result-Set Copy

##### 7.1 The Query Inspector › The empty library (#1918, HCD-4)

*Shown in place of the zero-result state when no volume is indexed, on iPhone, iPad and the Mac, and in place of a blank Subseries list when the downloaded-only filter leaves it empty. Its button, **Download Volumes…**, opens the download browser on iPhone and iPad and Settings ▸ Library ▸ Volumes & Storage on the Mac; **Show All Volumes** takes the filter off.*

*`library.empty.title` · 07-Search-and-Browse.md:118*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | EmptyLibraryNotice.title(for:) | lines: 500–501 | key: library.empty.title | shared: iOS only -->

No volumes on this device yet

<!-- END SOURCE: library.empty.title -->

*`library.empty.title.mac` · 07-Search-and-Browse.md:124*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | EmptyLibraryNotice.title(for:) | lines: 498–499 | key: library.empty.title.mac | shared: macOS only -->

No volumes on this Mac yet

<!-- END SOURCE: library.empty.title.mac -->

*`library.preparing.title` · 07-Search-and-Browse.md:130*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | EmptyLibraryNotice.title(for:) | lines: 503–504 | key: library.preparing.title | shared: iOS+macOS (single edit point) -->

*Shown while volumes are downloading or being indexed and none is ready.*

No volumes ready yet

<!-- END SOURCE: library.preparing.title -->

*`library.empty.search` · 07-Search-and-Browse.md:138*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | EmptyLibraryNotice.detail(for:in:) | lines: 515–516 | key: library.empty.search | shared: iOS only -->

Search reads only the volumes downloaded to this device, so it cannot find anything yet. Download some, and search them here.

<!-- END SOURCE: library.empty.search -->

*`library.empty.search.mac` · 07-Search-and-Browse.md:144*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | EmptyLibraryNotice.detail(for:in:) | lines: 512–513 | key: library.empty.search.mac | shared: macOS only -->

Search reads only the volumes downloaded to this Mac, so it cannot find anything yet. Download some, and search them here.

<!-- END SOURCE: library.empty.search.mac -->

*`library.empty.browse` · 07-Search-and-Browse.md:150*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | EmptyLibraryNotice.detail(for:in:) | lines: 519–520 | key: library.empty.browse | shared: iOS+macOS (single edit point) -->

This list shows downloaded volumes only, and none is downloaded yet. Download some, or show every volume in the series.

<!-- END SOURCE: library.empty.browse -->

*`library.preparing.search` · 07-Search-and-Browse.md:156*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | EmptyLibraryNotice.detail(for:in:) | lines: 522–523 | key: library.preparing.search | shared: iOS+macOS (single edit point) -->

Search finds the volumes you are downloading once each one is indexed.

<!-- END SOURCE: library.preparing.search -->

*`library.preparing.browse` · 07-Search-and-Browse.md:162*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | EmptyLibraryNotice.detail(for:in:) | lines: 525–526 | key: library.preparing.browse | shared: iOS+macOS (single edit point) -->

The volumes you are downloading appear here as each one arrives.

<!-- END SOURCE: library.preparing.browse -->

##### 7.3 Facets

*`facets.preamble.one` · 07-Search-and-Browse.md:240*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.preambleHeadline | key: facets.preamble.one -->

*The keyword preamble when the match is one document (#1683): it read "Describing all 1 matches". The plural is not in this file.*

Describing the 1 match

<!-- END SOURCE: facets.preamble.one -->

*`facets.preamble.meaning.one` · 07-Search-and-Browse.md:248*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.preambleHeadline | key: facets.preamble.meaning.one -->

*The Meaning preamble when the list is one document (#1683): it read "Describing the 1 closest matches".*

Describing the closest match

<!-- END SOURCE: facets.preamble.meaning.one -->

*`facets.preamble.wordsInMatches %@` · 07-Search-and-Browse.md:256*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.preambleHeadline | key: facets.preamble.wordsInMatches %@ -->

*The facet panel's heading over words found inside a held Meaning list (#1577 lane 4). It is counted over the list, as a Meaning list's facets are, and the line under it is the Meaning one, "Counted over the results themselves…".*

Describing the %@ closest matches that contain your words

<!-- END SOURCE: facets.preamble.wordsInMatches %@ -->

*`facets.preamble.wordsInMatches.one` · 07-Search-and-Browse.md:264*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.preambleHeadline | key: facets.preamble.wordsInMatches.one -->

*The same for one document.*

Describing the closest match that contains your words

<!-- END SOURCE: facets.preamble.wordsInMatches.one -->

*`facets.preamble.wordsInMatches.unknown` · 07-Search-and-Browse.md:272*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.preambleHeadline | key: facets.preamble.wordsInMatches.unknown -->

*The same before the count is known.*

Describing the closest matches that contain your words

<!-- END SOURCE: facets.preamble.wordsInMatches.unknown -->

*`facets.preamble.rankedByMeaning %@` · 07-Search-and-Browse.md:280*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.preambleHeadline | key: facets.preamble.rankedByMeaning %@ -->

*The facet panel's heading over a held list ranked by a question (#1577 lane 4). On iPhone and iPad Facets is shut over a ranking, as over a Meaning list; the Mac's window offers Facets either way, and shows this heading over a ranking since lane 5.*

Describing these %@ results, ranked by your question

<!-- END SOURCE: facets.preamble.rankedByMeaning %@ -->

*`facets.preamble.rankedByMeaning.one` · 07-Search-and-Browse.md:288*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.preambleHeadline | key: facets.preamble.rankedByMeaning.one -->

*The same for one result.*

Describing this result, ranked by your question

<!-- END SOURCE: facets.preamble.rankedByMeaning.one -->

*`facets.preamble.rankedByMeaning.unknown` · 07-Search-and-Browse.md:296*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | FacetPanelView.preambleHeadline | key: facets.preamble.rankedByMeaning.unknown -->

*The same before the count is known.*

Describing these results, ranked by your question

<!-- END SOURCE: facets.preamble.rankedByMeaning.unknown -->

*`search.count.closest.one` · 07-Search-and-Browse.md:315*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.closest.one -->

*The same header when a Meaning search shows exactly one result, as it can when filters leave one row of its list or it ran inside a set of one document. Until #1577 lane 2 it read "1 closest matches".*

1 closest match

<!-- END SOURCE: search.count.closest.one -->

*`search.semantic.row.score.a11y %lld` · 07-Search-and-Browse.md:323*

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchSharedViews.swift | key: search.semantic.row.score.a11y %lld -->

*What VoiceOver reads after a result's label when a Meaning search ranked it, on iPhone and iPad: the figure the row's "Semantic match · N%" chip shows, in words. The row is one accessibility element whose label replaces what it draws, so until #1577 lane 3 the chip was not read at all; its label is §7.16's since #1684.*

Semantic match %lld percent

<!-- END SOURCE: search.semantic.row.score.a11y %lld -->

*`search.count.one` · 07-Search-and-Browse.md:331*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.one -->

*The results header on iPhone and iPad when a search finds exactly one document. Until #1577 lane 2 the header had one string for every count and read "1 results". The Mac's count label has always had a singular of its own.*

1 result

<!-- END SOURCE: search.count.one -->

*`search.count.wordsInMatches %@ %@` · 07-Search-and-Browse.md:339*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.wordsInMatches %@ %@ -->

*The results header for words found inside a held Meaning list: how many of that list's rows contain the words, and the list's size. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

%1$@ of your %2$@ closest matches contain these words

<!-- END SOURCE: search.count.wordsInMatches %@ %@ -->

*`search.count.wordsInMatches.one %@` · 07-Search-and-Browse.md:347*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.wordsInMatches.one %@ -->

*The same header when exactly one row of the held Meaning list contains the words. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

1 of your %@ closest matches contains these words

<!-- END SOURCE: search.count.wordsInMatches.one %@ -->

*`search.count.wordsInMatches.none %@` · 07-Search-and-Browse.md:355*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.wordsInMatches.none %@ -->

*The same header when no row of the held Meaning list contains the words. It names what was searched, where "No results" would not. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

None of your %@ closest matches contains these words

<!-- END SOURCE: search.count.wordsInMatches.none %@ -->

*`search.count.wordsInMatches.single` · 07-Search-and-Browse.md:363*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.wordsInMatches.single -->

*The same header when the held Meaning list is one document, and it contains the words. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

Your closest match contains these words

<!-- END SOURCE: search.count.wordsInMatches.single -->

*`search.count.wordsInMatches.single.none` · 07-Search-and-Browse.md:371*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.wordsInMatches.single.none -->

*The same header when the held Meaning list is one document, and it does not contain the words. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

Your closest match does not contain these words

<!-- END SOURCE: search.count.wordsInMatches.single.none -->

*`search.count.rankedByMeaning %@` · 07-Search-and-Browse.md:379*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.rankedByMeaning %@ -->

*The results header for a keyword list reordered by a question, when every row could be ranked. The placeholder is the count as the keyword header says it, "212 results" or "1 result". Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

%@, closest first

<!-- END SOURCE: search.count.rankedByMeaning %@ -->

*`search.count.rankedByMeaning.partial %@ %@ %@` · 07-Search-and-Browse.md:387*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.count.rankedByMeaning.partial %@ %@ %@ -->

*The same header when some rows could not be ranked: the count, how many were ranked, and how many were not. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

%1$@ · %2$@ ranked · %3$@ not ranked

<!-- END SOURCE: search.count.rankedByMeaning.partial %@ %@ %@ -->

*`search.count.rankedWholeMatch %@ %@` · 07-Search-and-Browse.md:395*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wholeMatchClause | key: search.count.rankedWholeMatch %@ %@ -->

*The results header for a keyword list or a browse held at its ceiling and ranked by a question, which since #1577 lane 6 ranks the list's whole match and lists the closest of it up to the ceiling (1,000 on iPhone and iPad, 7,500 on the Mac): how many of the closest are listed, and of how many documents. A claim about a set, so a date sort keeps it. The part below follows it after a “·” where it applies. A ranking that could list the whole set reads as the two blocks above.*

Closest %1$@ of %2$@ results

<!-- END SOURCE: search.count.rankedWholeMatch %@ %@ -->

*`search.count.rankedWholeMatch.filtered %@ %@` · 07-Search-and-Browse.md:403*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wholeMatchClause | key: search.count.rankedWholeMatch.filtered %@ %@ -->

*The same header when filters chosen since the list was held left some of its match out: they narrow the match before the ranking, so the closest are the closest of the documents that pass them, and the second figure counts those. The row above names the whole match, so the header says which documents it means.*

Closest %1$@ of the %2$@ results that pass your filters

<!-- END SOURCE: search.count.rankedWholeMatch.filtered %@ %@ -->

*`search.count.rankedWholeMatch.noneRanked %@` · 07-Search-and-Browse.md:411*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wholeMatchClause | key: search.count.rankedWholeMatch.noneRanked %@ -->

*The header for such a ranking when none of the documents could be ranked (none has a vector, or their volumes' match files are not on the device). The rows listed are the held list's own, under the unranked rows' line (§7.15).*

None of the %@ results could be ranked

<!-- END SOURCE: search.count.rankedWholeMatch.noneRanked %@ -->

*`search.count.rankedWholeMatch.noneRanked.filtered %@` · 07-Search-and-Browse.md:419*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wholeMatchClause | key: search.count.rankedWholeMatch.noneRanked.filtered %@ -->

*The same when filters chosen since left some of the match out.*

None of the %@ results that pass your filters could be ranked

<!-- END SOURCE: search.count.rankedWholeMatch.noneRanked.filtered %@ -->

*`search.count.rankedWholeMatch.notRanked %@` · 07-Search-and-Browse.md:427*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wholeMatchClause | key: search.count.rankedWholeMatch.notRanked %@ -->

*After the first two headers above when some of the documents ranked inside could not be ranked: with no vector (front matter, chapter headings), or in a volume whose match file is not on the device. They are counted here; those the list has room for follow the closest under the unranked rows' line (§7.15).*

%@ not ranked

<!-- END SOURCE: search.count.rankedWholeMatch.notRanked %@ -->

*`search.count.wordsInMatches.filtered %@ %@` · 07-Search-and-Browse.md:435*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wordsInMatchesClauseWithFilters | key: search.count.wordsInMatches.filtered %@ %@ -->

*The results header for words found inside a held Meaning list when filters chosen since the list was held narrow the layer as well (#1577 lane 4). "Contain these words" alone would put what the filters removed down to the words.*

%1$@ of your %2$@ closest matches contain these words and pass your filters

<!-- END SOURCE: search.count.wordsInMatches.filtered %@ %@ -->

*`search.count.wordsInMatches.one.filtered %@` · 07-Search-and-Browse.md:443*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wordsInMatchesClauseWithFilters | key: search.count.wordsInMatches.one.filtered %@ -->

*The same when one row is left.*

1 of your %@ closest matches contains these words and passes your filters

<!-- END SOURCE: search.count.wordsInMatches.one.filtered %@ -->

*`search.count.wordsInMatches.none.filtered %@` · 07-Search-and-Browse.md:451*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wordsInMatchesClauseWithFilters | key: search.count.wordsInMatches.none.filtered %@ -->

*The same when none is left: either the words are in none of the list, or the filters removed every row that holds them, and the header cannot say which.*

None of your %@ closest matches both contains these words and passes your filters

<!-- END SOURCE: search.count.wordsInMatches.none.filtered %@ -->

*`search.count.wordsInMatches.single.filtered` · 07-Search-and-Browse.md:459*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wordsInMatchesClauseWithFilters | key: search.count.wordsInMatches.single.filtered -->

*The same when the held list is one document, and it is left.*

Your closest match contains these words and passes your filters

<!-- END SOURCE: search.count.wordsInMatches.single.filtered -->

*`search.count.wordsInMatches.single.none.filtered` · 07-Search-and-Browse.md:467*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.wordsInMatchesClauseWithFilters | key: search.count.wordsInMatches.single.none.filtered -->

*The same when the held list is one document, and it is not left.*

Your closest match does not both contain these words and pass your filters

<!-- END SOURCE: search.count.wordsInMatches.single.none.filtered -->

##### 7.5 Collocation — the words near your term

*`search.collocation.printedForms.note` · 07-Search-and-Browse.md:579*

<!-- SOURCE: FRUSExplorer/Search/Collocation.swift | CollocationAnalysis.printedFormsNote(for:) | lines: 238–239 | key: search.collocation.printedForms.note -->

*Added by #1608 (2026-10-12). The first row of the collocates list on a launch whose language analysis has no lemmatiser: the panel ranks where it used to refuse, and says that it compared printed forms, why, and that the ranking can differ on another device, as the owner's condition for the fallback asks. The same row stands above the panel's message when such a count ranked nothing (*No word appears at least 3 times…* and *Nothing near your matches is used more here…*, both further down): each is a result of counting printed forms, and a device that reduces words can rank where this one found nothing. The example is a verb because a printed count still folds a regular plural by rule while* Merge plural and singular forms *is on. It does not say that the app checks again: with that sentence the note was seven lines on an iPhone 17 and left two rows of the ranking on screen. The panel is still ranked again when a check finds the lemmatiser working, and the note then goes.*

Compared as printed: this device’s language analysis isn’t reducing words to their dictionary forms right now, so “negotiate” and “negotiated” count as two words, here and in the corpus reference. A device that does reduce them (a Mac, or another iPhone or iPad) can rank these neighbors differently.

<!-- END SOURCE: search.collocation.printedForms.note -->

*`search.collocation.caveat.scope.v3 %@ %@` · 07-Search-and-Browse.md:615*

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | CollocationCaveatCopy.scanned | key: search.collocation.caveat.scope.v3 %@ %@ -->

*Collocates' line of what the scan read, after the sentence naming the set it read (#1683). %1$@ is the matches with their noun and %2$@ the documents with theirs, from the forms below and “1 document” / “12 documents”: “6,387 matches, in 1,512 documents that had indexed text.” Its `.v2` printed both counts through `%lld`, as "6387 matches, in 1512 documents", and had no block here.*

%1$@, in %2$@ that had indexed text.

<!-- END SOURCE: search.collocation.caveat.scope.v3 %@ %@ -->

*`search.collocation.caveat.matches.one` · 07-Search-and-Browse.md:623*

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | CollocationCaveatCopy.scanned | key: search.collocation.caveat.matches.one -->

*The line's count of matches, for one (#1683).*

%@ match

<!-- END SOURCE: search.collocation.caveat.matches.one -->

*`search.collocation.caveat.matches.many` · 07-Search-and-Browse.md:631*

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | CollocationCaveatCopy.scanned | key: search.collocation.caveat.matches.many -->

*The same, for any other number.*

%@ matches

<!-- END SOURCE: search.collocation.caveat.matches.many -->

##### 7.6 What a reading actually covers

*`search.collocation.caveat.scope.loaded.wordsInMatches` · 07-Search-and-Browse.md:673*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.collocation.caveat.scope.loaded.wordsInMatches -->

*The Collocates reading's scope line over words found inside a held Meaning list. The line above it says "the highest-scoring matches", which those rows are not: they were chosen by a question and kept for their words. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

Measured over every result this search loaded, not the page on screen — those are the closest matches that contain your words, not every document that contains them.

<!-- END SOURCE: search.collocation.caveat.scope.loaded.wordsInMatches -->

*`search.collocation.caveat.scope.checklist %@` · 07-Search-and-Browse.md:681*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.collocationScopeDescription | key: search.collocation.caveat.scope.checklist %@ -->

*Added after the Collocates scope line while Checklist Mode hides rows. Its leading space joins it to the sentence before.*

 %@ reviewed documents are excluded.

<!-- END SOURCE: search.collocation.caveat.scope.checklist %@ -->

*`search.collocation.caveat.scope.checklist.one` · 07-Search-and-Browse.md:689*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.collocationScopeDescription | key: search.collocation.caveat.scope.checklist.one -->

*The same for one hidden document (#1683): it read "1 reviewed documents are excluded."*

 %@ reviewed document is excluded.

<!-- END SOURCE: search.collocation.caveat.scope.checklist.one -->

*`search.timeline.bias.wordsInMatches` · 07-Search-and-Browse.md:703*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.timeline.bias.wordsInMatches -->

*The Timeline reading's caption over words found inside a held Meaning list, for the same reason. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

These are the closest matches that contain your words, not a sample across time — this shape is theirs, not the whole match’s.

<!-- END SOURCE: search.timeline.bias.wordsInMatches -->

##### 7.7 Working corpora

*`corpus.save.rankedWholeMatch %@ %@` · 07-Search-and-Browse.md:751*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureTruncationWarning | key: corpus.save.rankedWholeMatch %@ %@ -->

*Save as Working Corpus's warning over a ranking of a whole match that listed the closest of it (#1577 lane 6), in place of the highest-scoring sentence above: these rows were chosen by a question, not by the keyword score. Interpolated with the closest count and the documents ranked inside, which are those that pass the filters chosen since.*

These %1$@ documents are the closest to your question of %2$@ matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.rankedWholeMatch %@ %@ -->

*`corpus.save.rankedWholeMatch.one %@` · 07-Search-and-Browse.md:759*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureTruncationWarning | key: corpus.save.rankedWholeMatch.one %@ -->

*The same when only one document is captured.*

This document is the closest to your question of %@ matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.rankedWholeMatch.one %@ -->

*`corpus.save.rankedWholeMatch.unranked %@ %@ %@ %@` · 07-Search-and-Browse.md:767*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureTruncationWarning | key: corpus.save.rankedWholeMatch.unranked %@ %@ %@ %@ -->

*The same when rows the ranking could not rank were listed after the closest: the captured count, how many of them are the closest, the documents ranked inside, and how many it could not rank. The unranked rows are not the closest of anything, so the closest are counted apart.*

These %1$@ documents are the %2$@ closest to your question of %3$@ matching documents, and %4$@ that it could not rank. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.rankedWholeMatch.unranked %@ %@ %@ %@ -->

*`corpus.save.checklistHiding.one` · 07-Search-and-Browse.md:783*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureChecklistWarning | key: corpus.save.checklistHiding.one -->

*The capture sheet's checklist line for one hidden document (#1683): it read "hiding 1 reviewed documents. They will not be…".*

Checklist mode is hiding %@ reviewed document. It will not be in this corpus.

<!-- END SOURCE: corpus.save.checklistHiding.one -->

*`corpus.save.meaning` · 07-Search-and-Browse.md:791*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 691–692 | key: corpus.save.meaning -->

*The Save Working Corpus sheet's warning for a list saved from a Meaning search (#1598).*

These documents are the closest matches a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.

<!-- END SOURCE: corpus.save.meaning -->

*`corpus.save.meaning.one` · 07-Search-and-Browse.md:799*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureTruncationWarning | key: corpus.save.meaning.one -->

*The Meaning caution for a capture of one document (#1683): it read "These documents are…" whatever the count.*

This document is the closest match a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.

<!-- END SOURCE: corpus.save.meaning.one -->

*`corpus.save.source.meaning %@` · 07-Search-and-Browse.md:807*

<!-- SOURCE: FRUSCoreKit/Models/WorkingCorpusResolver.swift | lines: 300–301 | key: corpus.save.source.meaning %@ -->

*Stored on a working corpus saved from a Meaning search, and shown wherever the corpus is listed. Interpolated with the number of rows the search returned.*

Meaning search — the %@ closest matches

<!-- END SOURCE: corpus.save.source.meaning %@ -->

*`corpus.save.source.meaning.one` · 07-Search-and-Browse.md:815*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 787–788 | key: corpus.save.source.meaning.one -->

*The same, when the search returned one row.*

Meaning search — the closest match

<!-- END SOURCE: corpus.save.source.meaning.one -->

*`corpus.save.wordsInMatches` · 07-Search-and-Browse.md:823*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: corpus.save.wordsInMatches -->

*The caution in the Save Working Corpus sheet when the list is words found inside a Meaning list. Like the Meaning list's own caution it carries no number, since the sheet's Documents row is one line above it. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

These documents are the ones among a Meaning search’s closest matches that contain your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.

<!-- END SOURCE: corpus.save.wordsInMatches -->

*`corpus.save.wordsInMatches.one` · 07-Search-and-Browse.md:831*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: corpus.save.wordsInMatches.one -->

*The same caution when the capture is one document. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

This document is the one among a Meaning search’s closest matches that contains your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.

<!-- END SOURCE: corpus.save.wordsInMatches.one -->

*`corpus.save.source.wordsInMatches %@ %@` · 07-Search-and-Browse.md:839*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: corpus.save.source.wordsInMatches %@ %@ -->

*What a working corpus saved from such a list records as its source: how many documents were found, of how many closest matches. Shown on iPhone and iPad since #1577 lane 4 and in the Mac's Search window since lane 5, over a list held with Search Within These Results (§7.15); written in lane 2.*

Words found in a Meaning search’s closest matches — %1$@ of %2$@

<!-- END SOURCE: corpus.save.source.wordsInMatches %@ %@ -->

*`corpus.save.source.wordsInMatches.within %@ %@ %@` · 07-Search-and-Browse.md:847*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureProvenanceDescription | key: corpus.save.source.wordsInMatches.within %@ %@ %@ -->

*What a working corpus saved from words found in a held Meaning list records as its source, when the list's question is known, which since #1577 lane 4 it always is: the record names both layers, the question here and the words in the corpus's own query field. %3$@ is the question in quotation marks; %1$@ of %2$@ are the rows found and the list's size.*

Words found in a Meaning search’s closest matches to %3$@ — %1$@ of %2$@

<!-- END SOURCE: corpus.save.source.wordsInMatches.within %@ %@ %@ -->

*`corpus.save.source.rankedByMeaning %@` · 07-Search-and-Browse.md:855*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureProvenanceDescription | key: corpus.save.source.rankedByMeaning %@ -->

*What a working corpus saved from a held keyword list ranked by a question records as its source (#1577 lane 4): the list it ranked, by its words in quotation marks or a browse's name. The question is in the corpus's own query field. Where the list was cut at its fetch ceiling, the truncation clause follows as for any search.*

Search results for %@, ranked by a question

<!-- END SOURCE: corpus.save.source.rankedByMeaning %@ -->

*`corpus.save.source.rankedByMeaning.unlabelled` · 07-Search-and-Browse.md:863*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureProvenanceDescription | key: corpus.save.source.rankedByMeaning.unlabelled -->

*The same when the list has no name to give.*

Search results, ranked by a question

<!-- END SOURCE: corpus.save.source.rankedByMeaning.unlabelled -->

*`corpus.save.source.rankedWholeMatch %@ %@` · 07-Search-and-Browse.md:871*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureProvenanceDescription | key: corpus.save.source.rankedWholeMatch %@ %@ -->

*What follows a ranking's provenance line above when it ranked the list's whole match and listed the closest of it (#1577 lane 6), in place of the truncation clause “ — the highest-scoring … of … matches”: the closest count and the documents ranked inside. A ranking that could rank none of them records the truncation clause, since its rows are the held list's own.*

 — the closest %1$@ of %2$@ matches

<!-- END SOURCE: corpus.save.source.rankedWholeMatch %@ %@ -->

*`corpus.save.source.rankedWholeMatch.unranked %@ %@ %@` · 07-Search-and-Browse.md:879*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureProvenanceDescription | key: corpus.save.source.rankedWholeMatch.unranked %@ %@ %@ -->

*The same when rows the ranking could not rank were listed after the closest: %3$@ is how many.*

 — the closest %1$@ of %2$@ matches, and %3$@ not ranked

<!-- END SOURCE: corpus.save.source.rankedWholeMatch.unranked %@ %@ %@ -->

*`corpus.save.source.checklist.one` · 07-Search-and-Browse.md:887*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureProvenanceDescription | key: corpus.save.source.checklist.one -->

*Added to a corpus's source when Checklist Mode hid one document from the capture (#1683): it read "; 1 reviewed documents excluded". The plural is not in this file.*

; %@ reviewed document excluded

<!-- END SOURCE: corpus.save.source.checklist.one -->

*`corpus.save.source.narrowed %@ %@` · 07-Search-and-Browse.md:895*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.captureProvenanceDescription | key: corpus.save.source.narrowed %@ %@ -->

*What a working corpus records when its search was narrowed beyond its words (#1758): %1$@ is the source above ("Search results", or a Meaning search's closest matches), %2$@ what narrowed it, its phrases joined by semicolons, as "years 1945". The truncation and checklist clauses follow it. The corpus records its words apart, in its own query field.*

%1$@ (%2$@)

<!-- END SOURCE: corpus.save.source.narrowed %@ %@ -->

*`corpus.save.narrowedBy` · 07-Search-and-Browse.md:903*

<!-- SOURCE: FRUSExplorer/Search/SaveWorkingCorpusSheet.swift | SaveWorkingCorpusSheet.body | key: corpus.save.narrowedBy -->

*The Save Working Corpus sheet's row under From when the search was narrowed beyond its words (#1758): its value is the phrases above, as "years 1945". The phrases are the method appendix's own words for a search's scope (`SearchScopeSignature.describe`), with the two below, each with its singular.*

Narrowed by

<!-- END SOURCE: corpus.save.narrowedBy -->

*`corpus.save.narrowing.volumes %@` · 07-Search-and-Browse.md:911*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.narrowing(ofRowsSignedBy:) | key: corpus.save.narrowing.volumes %@ -->

*A narrowing phrase for a search limited to a set of volumes (#1758), where the appendix says "12 volumes", which after "Search results" would read as a count of the corpus. Interpolated with the number of volumes.*

within %@ volumes

<!-- END SOURCE: corpus.save.narrowing.volumes %@ -->

*`corpus.save.narrowing.volumes.one` · 07-Search-and-Browse.md:919*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.narrowing(ofRowsSignedBy:) | key: corpus.save.narrowing.volumes.one -->

*The same for one volume.*

within %@ volume

<!-- END SOURCE: corpus.save.narrowing.volumes.one -->

*`corpus.save.narrowing.documents %@` · 07-Search-and-Browse.md:927*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.narrowing(ofRowsSignedBy:) | key: corpus.save.narrowing.documents %@ -->

*A narrowing phrase for a search run inside a set of documents (#1758): an applied working corpus, a project's History, or both. Interpolated with the number of documents.*

within a set of %@ documents

<!-- END SOURCE: corpus.save.narrowing.documents %@ -->

*`corpus.save.narrowing.documents.one` · 07-Search-and-Browse.md:935*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | ResultSetScope.narrowing(ofRowsSignedBy:) | key: corpus.save.narrowing.documents.one -->

*The same for a set of one document.*

within a set of %@ document

<!-- END SOURCE: corpus.save.narrowing.documents.one -->

*`search.checklist.loggingOff` · 07-Search-and-Browse.md:943*

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | lines: 70–71 | key: search.checklist.loggingOff -->

*Shown under the results count on iPhone, iPad and Mac while Checklist Mode is on and Settings ▸ Research ▸ Research Sessions ▸ Log Research Sessions is off (#1592).*

Opening a result does not hide it while Log Research Sessions is off in Settings. Mark Reviewed still hides a result.

<!-- END SOURCE: search.checklist.loggingOff -->

*`search.checklist.hiddenBanner.v2 %@` · 07-Search-and-Browse.md:951*

<!-- SOURCE: FRUSExplorer/Search/ChecklistStrip.swift | ChecklistCopy.hidden | key: search.checklist.hiddenBanner.v2 %@ -->

*The checklist strip's count of what Checklist Mode is hiding, on iPhone, iPad and Mac, beside “Nothing hidden”. Grouped since #1683: its `%lld` key read "1852 reviewed hidden" beside the selection's "1,852 results marked reviewed".*

%@ reviewed hidden

<!-- END SOURCE: search.checklist.hiddenBanner.v2 %@ -->

##### 7.12 Semantic search fallback (V-5 s3)

*`search.semantic.offer.body.meaning` · 07-Search-and-Browse.md:1265*

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchSharedViews.swift | property: SemanticModelOfferCard | lines: 151–152 | key: search.semantic.offer.body.meaning -->

*The same card in Meaning mode, where no keyword search ran: shown when a Meaning search is submitted and the model is not on the device.*

A Meaning search ranks documents by what an AI model detects your question to mean, including questions whose words never appear in the documents. This needs a one-time 310 MB model download that runs entirely on this device.

<!-- END SOURCE: search.semantic.offer.body.meaning -->

*`search.semantic.empty.set.none` · 07-Search-and-Browse.md:1305*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 463–464 | key: search.semantic.empty.set.none -->

The set you are searching within holds no documents on this device, so there is nothing to rank.

<!-- END SOURCE: search.semantic.empty.set.none -->

*`search.semantic.empty.set.filtered` · 07-Search-and-Browse.md:1311*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 468–469 | key: search.semantic.empty.set.filtered -->

None of the closest matches inside the documents you are searching within passes your other filters.

<!-- END SOURCE: search.semantic.empty.set.filtered -->

*`search.semantic.empty.set.notIndexed` · 07-Search-and-Browse.md:1317*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 470–471 | key: search.semantic.empty.set.notIndexed -->

None of the closest matches inside the documents you are searching within is indexed on this device.

<!-- END SOURCE: search.semantic.empty.set.notIndexed -->

*`search.semantic.empty.set.noVectors` · 07-Search-and-Browse.md:1323*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 474–475 | key: search.semantic.empty.set.noVectors -->

None of the documents you are searching within can be ranked by meaning: the app has no match data for them. Front matter and chapter headings never have any.

<!-- END SOURCE: search.semantic.empty.set.noVectors -->

*`search.semantic.empty.set.warming %@` · 07-Search-and-Browse.md:1329*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 479–480 | key: search.semantic.empty.set.warming %@ -->

Match files for %@ are still downloading in the background. Searching again in a moment may rank the documents you are searching within.

<!-- END SOURCE: search.semantic.empty.set.warming %@ -->

*`search.semantic.empty.set.notFetching %@` · 07-Search-and-Browse.md:1335*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.emptyInsideSet | lines: 484–485 | key: search.semantic.empty.set.notFetching %@ -->

The documents you are searching within could not be ranked: match files for %@ are not on this device. Download Missing Vectors in Settings fetches the files for volumes you have downloaded.

<!-- END SOURCE: search.semantic.empty.set.notFetching %@ -->

*`search.meaning.strip.base.within %@` · 07-Search-and-Browse.md:1353*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticModeStrip.opening | lines: 243–244 | key: search.meaning.strip.base.within %@ -->

Meaning search (experimental): ranked by what your question means, inside the %@ you are searching within — your exact words may not appear. Front matter and chapter headings are not reachable this way. *(%@ is the set's size with its noun, “1 document” or “212 documents”.)*

<!-- END SOURCE: search.meaning.strip.base.within %@ -->

*`search.meaning.strip.base.emptySet` · 07-Search-and-Browse.md:1361*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticModeStrip.opening | lines: 239–240 | key: search.meaning.strip.base.emptySet -->

Meaning search (experimental): the set you are searching within holds no documents on this device, so there is nothing to rank.

<!-- END SOURCE: search.meaning.strip.base.emptySet -->

*`search.meaning.strip.notIndexed.one` · 07-Search-and-Browse.md:1374*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.notIndexedHere | lines: 415–416 | key: search.meaning.strip.notIndexed.one -->

%@ close match is not listed: this device's index does not hold that document.

<!-- END SOURCE: search.meaning.strip.notIndexed.one -->

*`search.meaning.strip.notIndexed.many` · 07-Search-and-Browse.md:1380*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.notIndexedHere | lines: 417–418 | key: search.meaning.strip.notIndexed.many -->

%@ close matches are not listed: this device's index does not hold those documents.

<!-- END SOURCE: search.meaning.strip.notIndexed.many -->

*`search.meaning.strip.withoutVector.one` · 07-Search-and-Browse.md:1390*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.withoutVector | lines: 435–436 | key: search.meaning.strip.withoutVector.one -->

%@ document in the set has no match data and cannot be ranked.

<!-- END SOURCE: search.meaning.strip.withoutVector.one -->

*`search.meaning.strip.withoutVector.many` · 07-Search-and-Browse.md:1396*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.withoutVector | lines: 437–438 | key: search.meaning.strip.withoutVector.many -->

%@ documents in the set have no match data and cannot be ranked.

<!-- END SOURCE: search.meaning.strip.withoutVector.many -->

*`search.meaning.strip.unranked.downloading %@ %@` · 07-Search-and-Browse.md:1408*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.unranked | lines: 392–393 | key: search.meaning.strip.unranked.downloading %@ %@ -->

%1$@ in %2$@ could not be ranked yet; their match files are downloading.

<!-- END SOURCE: search.meaning.strip.unranked.downloading %@ %@ -->

*`search.meaning.strip.unranked.notFetching %@ %@` · 07-Search-and-Browse.md:1414*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | SemanticUnscoredCopy.unranked | lines: 397–398 | key: search.meaning.strip.unranked.notFetching %@ %@ -->

%1$@ in %2$@ could not be ranked: their match files are not on this device. Download Missing Vectors in Settings fetches the files for volumes you have downloaded.

<!-- END SOURCE: search.meaning.strip.unranked.notFetching %@ %@ -->

*`search.meaning.strip.row` · 07-Search-and-Browse.md:1436*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | property: SemanticModeStrip.rowTitle | lines: 142–142 | key: search.meaning.strip.row -->

Meaning search (experimental)

<!-- END SOURCE: search.meaning.strip.row -->

*`search.meaning.strip.more.a11y` · 07-Search-and-Browse.md:1443*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | property: SemanticModeStrip.wholeCaptionLabel | lines: 147–147 | key: search.meaning.strip.more.a11y -->

About Meaning search

<!-- END SOURCE: search.meaning.strip.more.a11y -->

*`search.meaning.strip.more.help` · 07-Search-and-Browse.md:1450*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | property: SemanticModeStrip.wholeCaptionHelp | lines: 152–153 | key: search.meaning.strip.more.help -->

Shows the strip's whole text at your text size

<!-- END SOURCE: search.meaning.strip.more.help -->

*`search.meaning.strip.sheet.title` · 07-Search-and-Browse.md:1457*

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | property: SemanticModeStrip.sheetTitle | lines: 158–158 | key: search.meaning.strip.sheet.title -->

Meaning Search

<!-- END SOURCE: search.meaning.strip.sheet.title -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › Added %1$@ to “%2$@”.

*`search.selection.outcome.added %@ %@` · 07-Search-and-Browse.md:1838*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.added(_:alreadyPresent:to:locale:) | lines: 688–689 | key: search.selection.outcome.added %@ %@ -->

*The line after Add to Collection added documents: "Added 31 documents to “Chile”." `%1$@` is the number added, with its noun, and `%2$@` the collection's name. When some were already in the collection, one of the two sentences below follows it.*

Added %1$@ to “%2$@”.

<!-- END SOURCE: search.selection.outcome.added %@ %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › %@ was already in it.

*`search.selection.outcome.already.one %@` · 07-Search-and-Browse.md:1847*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.added(_:alreadyPresent:to:locale:) | lines: 694–695 | key: search.selection.outcome.already.one %@ -->

*Follows the line above when one of the documents was already in the collection: "1 was already in it." `%@` is the number.*

%@ was already in it.

<!-- END SOURCE: search.selection.outcome.already.one %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › %@ were already in it.

*`search.selection.outcome.already.many %@` · 07-Search-and-Browse.md:1856*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.added(_:alreadyPresent:to:locale:) | lines: 696–697 | key: search.selection.outcome.already.many %@ -->

*The same for more than one: "6 were already in it."*

%@ were already in it.

<!-- END SOURCE: search.selection.outcome.already.many %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › Nothing added: %1$@ was already in “%2$@”.

*`search.selection.outcome.noneAdded.one %@ %@` · 07-Search-and-Browse.md:1865*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.added(_:alreadyPresent:to:locale:) | lines: 682–683 | key: search.selection.outcome.noneAdded.one %@ %@ -->

*The line when every picked document was already in the collection, for one document. `%1$@` is the number and `%2$@` the collection's name. No Undo is offered beside it.*

Nothing added: %1$@ was already in “%2$@”.

<!-- END SOURCE: search.selection.outcome.noneAdded.one %@ %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › Nothing added: %1$@ were already in “%2$@”.

*`search.selection.outcome.noneAdded.many %@ %@` · 07-Search-and-Browse.md:1874*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.added(_:alreadyPresent:to:locale:) | lines: 684–685 | key: search.selection.outcome.noneAdded.many %@ %@ -->

*The same for more than one: "Nothing added: 6 were already in “Chile”."*

Nothing added: %1$@ were already in “%2$@”.

<!-- END SOURCE: search.selection.outcome.noneAdded.many %@ %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › Removed %1$@ from “%2$@”.

*`search.selection.outcome.removed %@ %@` · 07-Search-and-Browse.md:1883*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.removed(_:from:locale:) | lines: 709–710 | key: search.selection.outcome.removed %@ %@ -->

*The line after Undo took an add back: "Removed 31 documents from “Chile”." `%1$@` is the number removed, with its noun, and `%2$@` the collection's name.*

Removed %1$@ from “%2$@”.

<!-- END SOURCE: search.selection.outcome.removed %@ %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › %@ selected result is not in this list now.

*`search.selection.outcome.dropped.one %@` · 07-Search-and-Browse.md:1892*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.dropped(_:locale:) | lines: 722–723 | key: search.selection.outcome.dropped.one %@ -->

*The line when the same search was run again, under a changed filter, and one picked result is no longer in the list. `%@` is the number.*

%@ selected result is not in this list now.

<!-- END SOURCE: search.selection.outcome.dropped.one %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › %@ selected results are not in this list now.

*`search.selection.outcome.dropped.many %@` · 07-Search-and-Browse.md:1901*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.dropped(_:locale:) | lines: 724–725 | key: search.selection.outcome.dropped.many %@ -->

*The same for more than one: "12 selected results are not in this list now."*

%@ selected results are not in this list now.

<!-- END SOURCE: search.selection.outcome.dropped.many %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › Select %@ or fewer

*`search.selection.overLimit.v3 %@` · 07-Search-and-Browse.md:1910*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.overLimit(_:locale:) | lines: 596–597 | key: search.selection.overLimit.v3 %@ -->

*Why Add to Collection and Add Tags are dimmed, when more results are picked than one of them takes: "Select 1,000 documents or fewer". `%@` is the limit, with its noun. It is said beside each of the two, under its name: in the Actions menu on iPhone and iPad, under the two buttons of the Mac's selection strip, and in a checked result's menu on the Mac. Mark Reviewed stays live. Re-keyed for #1683 (decision 69): it was a line above the results, "Select %@ or fewer to add them to a collection or to tag them.", and beside the commands it no longer says what they are for. Re-keyed in #1576 lane 5 too, when the line came to speak for Add Tags as well.*

Select %@ or fewer

<!-- END SOURCE: search.selection.overLimit.v3 %@ -->

##### 7.13 Search Tips › Selecting results: what a command did (iOS) › Undo did not finish: %@

*`search.selection.outcome.undoFailed %@` · 07-Search-and-Browse.md:1919*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.undoFailed(_:) | lines: 735–736 | key: search.selection.outcome.undoFailed %@ -->

*The line when the Undo of an add threw. `%@` is the system's own description of the failure. No Undo is offered beside it. It does not say that nothing changed: a removal whose save failed has already taken the documents out of the collection in memory.*

Undo did not finish: %@

<!-- END SOURCE: search.selection.outcome.undoFailed %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › Added “%1$@” to %2$@.

*`search.selection.outcome.tagged %@ %@` · 07-Search-and-Browse.md:1932*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.tagged(_:alreadyTagged:tagNames:locale:) | lines: 632–633 | key: search.selection.outcome.tagged %@ %@ -->

*One tag was added: "Added “Chile” to 31 documents." `%1$@` is the tag's name and `%2$@` the documents that gained it, with their noun.*

Added “%1$@” to %2$@.

<!-- END SOURCE: search.selection.outcome.tagged %@ %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › Added %1$@ tags to %2$@.

*`search.selection.outcome.tagged.tags %@ %@` · 07-Search-and-Browse.md:1941*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.tagged(_:alreadyTagged:tagNames:locale:) | lines: 636–637 | key: search.selection.outcome.tagged.tags %@ %@ -->

*More than one tag was added: "Added 3 tags to 31 documents." `%1$@` is the number of tags and `%2$@` the documents that gained at least one, with their noun.*

Added %1$@ tags to %2$@.

<!-- END SOURCE: search.selection.outcome.tagged.tags %@ %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › %@ already had it.

*`search.selection.outcome.alreadyTagged %@` · 07-Search-and-Browse.md:1950*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.tagged(_:alreadyTagged:tagNames:locale:) | lines: 644–645 | key: search.selection.outcome.alreadyTagged %@ -->

*Follows the line for one tag when some of the documents carried it already: "6 already had it." `%@` is how many. One form serves one and many.*

%@ already had it.

<!-- END SOURCE: search.selection.outcome.alreadyTagged %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › %@ already had them.

*`search.selection.outcome.alreadyTagged.tags %@` · 07-Search-and-Browse.md:1959*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.tagged(_:alreadyTagged:tagNames:locale:) | lines: 645–646 | key: search.selection.outcome.alreadyTagged.tags %@ -->

*Follows the line for several tags when some of the documents carried every one of them already: "6 already had them."*

%@ already had them.

<!-- END SOURCE: search.selection.outcome.alreadyTagged.tags %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › Nothing added: %1$@ document already had “%2$@”.

*`search.selection.outcome.noneTagged.one %@ %@` · 07-Search-and-Browse.md:1968*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.tagged(_:alreadyTagged:tagNames:locale:) | lines: 616–617 | key: search.selection.outcome.noneTagged.one %@ %@ -->

*The one document carried the one tag already. No Undo is offered. `%1$@` is the number and `%2$@` the tag's name.*

Nothing added: %1$@ document already had “%2$@”.

<!-- END SOURCE: search.selection.outcome.noneTagged.one %@ %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › Nothing added: %1$@ documents already had “%2$@”.

*`search.selection.outcome.noneTagged.many %@ %@` · 07-Search-and-Browse.md:1977*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.tagged(_:alreadyTagged:tagNames:locale:) | lines: 618–619 | key: search.selection.outcome.noneTagged.many %@ %@ -->

*Every document carried the one tag already: "Nothing added: 37 documents already had “Chile”."*

Nothing added: %1$@ documents already had “%2$@”.

<!-- END SOURCE: search.selection.outcome.noneTagged.many %@ %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › Nothing added: %@ document already had those tags.

*`search.selection.outcome.noneTagged.tags.one %@` · 07-Search-and-Browse.md:1986*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.tagged(_:alreadyTagged:tagNames:locale:) | lines: 624–625 | key: search.selection.outcome.noneTagged.tags.one %@ -->

*The one document carried every one of several tags already.*

Nothing added: %@ document already had those tags.

<!-- END SOURCE: search.selection.outcome.noneTagged.tags.one %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › Nothing added: %@ documents already had those tags.

*`search.selection.outcome.noneTagged.tags.many %@` · 07-Search-and-Browse.md:1995*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.tagged(_:alreadyTagged:tagNames:locale:) | lines: 626–627 | key: search.selection.outcome.noneTagged.tags.many %@ -->

*Every document carried every one of several tags already.*

Nothing added: %@ documents already had those tags.

<!-- END SOURCE: search.selection.outcome.noneTagged.tags.many %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › Removed “%1$@” from %2$@.

*`search.selection.outcome.untagged %@ %@` · 07-Search-and-Browse.md:2004*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.untagged(_:tagNames:locale:) | lines: 660–661 | key: search.selection.outcome.untagged %@ %@ -->

*After Undo of an Add Tags that gave one tag: "Removed “Chile” from 31 documents." Only the tags the command added are taken off. `%2$@` can be fewer than were tagged, when some of those tags were removed another way first.*

Removed “%1$@” from %2$@.

<!-- END SOURCE: search.selection.outcome.untagged %@ %@ -->

##### 7.13 Search Tips › Selecting results: what an Add Tags did (iOS and macOS) › Removed %1$@ tags from %2$@.

*`search.selection.outcome.untagged.tags %@ %@` · 07-Search-and-Browse.md:2013*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.untagged(_:tagNames:locale:) | lines: 664–665 | key: search.selection.outcome.untagged.tags %@ %@ -->

*After Undo of an Add Tags that gave several tags: "Removed 3 tags from 31 documents."*

Removed %1$@ tags from %2$@.

<!-- END SOURCE: search.selection.outcome.untagged.tags %@ %@ -->

##### 7.13 Search Tips › Selecting results: the Select button's help (macOS) › Select results, to add several to a collection or mark them reviewed at once

*`search.selection.toggle.on.help` · 07-Search-and-Browse.md:2026*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.selectToggleOnHelp | lines: 464–465 | key: search.selection.toggle.on.help -->

*While selection is off.*

Select results, to add several to a collection or mark them reviewed at once

<!-- END SOURCE: search.selection.toggle.on.help -->

##### 7.13 Search Tips › Selecting results: the Select button's help (macOS) › Leave selection and clear the checkboxes

*`search.selection.toggle.off.help` · 07-Search-and-Browse.md:2035*

<!-- SOURCE: FRUSExplorer/Search/ResultSelection.swift | ResultSelectionCopy.selectToggleOffHelp | lines: 470–471 | key: search.selection.toggle.off.help -->

*While selection is on.*

Leave selection and clear the checkboxes

<!-- END SOURCE: search.selection.toggle.off.help -->

##### 7.15 Search within these results (#1577 lanes 4 to 7) › The ways in (iOS)

*`search.layer.start.wordsInMatches` · 07-Search-and-Browse.md:2115*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | SearchLayerDirection.startTitle | key: search.layer.start.wordsInMatches -->

*The More menu's item over a Meaning list, after Save as Working Corpus…. It holds the list on screen as a base and turns the field to Keywords, so that the words typed next are found inside it.*

Find Words in These Matches

<!-- END SOURCE: search.layer.start.wordsInMatches -->

*`search.layer.start.rankByMeaning` · 07-Search-and-Browse.md:2123*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | SearchLayerDirection.startTitle | key: search.layer.start.rankByMeaning -->

*The same item over a keyword list or a browse: the field turns to Meaning, and the question typed next reorders the list, closest first.*

Rank These Results by a Question

<!-- END SOURCE: search.layer.start.rankByMeaning -->

*`search.layer.sort.closestToQuestion` · 07-Search-and-Browse.md:2131*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.closestToAQuestion | key: search.layer.sort.closestToQuestion -->

*The Sort menu's second way into a ranking, below the three orders, on a keyword list only.*

Closest to a Question…

<!-- END SOURCE: search.layer.sort.closestToQuestion -->

*`search.saveSearch.layered` · 07-Search-and-Browse.md:2139*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.saveSearchUnavailable | key: search.saveSearch.layered -->

*Save this search's second line in the More menu while a base is held, when the item is off: a layered search is not saved (the owner's decision 4), and the durable form is the result set. On the Mac it is the bookmark button's help while the button is off (`SearchSheet.swift`).*

Not while searching within results. Save as Working Corpus keeps these results.

<!-- END SOURCE: search.saveSearch.layered -->

##### 7.15 Search within these results (#1577 lanes 4 to 7) › The way in (Mac)

*`search.layer.toolbar` · 07-Search-and-Browse.md:2149*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.searchWithinResults | key: search.layer.toolbar -->

*The Mac Search window's toolbar button, after Save as Working Corpus…. It holds the list on screen and turns the field to the other engine. Its title stays the same whichever way the layer will run; its help, below, says which.*

Search Within Results

<!-- END SOURCE: search.layer.toolbar -->

*`search.layer.toolbar.help.wordsInMatches` · 07-Search-and-Browse.md:2157*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.searchWithinResultsHelp | key: search.layer.toolbar.help.wordsInMatches -->

*The button's help over a Meaning list.*

Find words in these closest matches. They keep their order, and only those that contain your words stay listed.

<!-- END SOURCE: search.layer.toolbar.help.wordsInMatches -->

*`search.layer.toolbar.help.rankByMeaning` · 07-Search-and-Browse.md:2165*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.searchWithinResultsHelp | key: search.layer.toolbar.help.rankByMeaning -->

*The button's help over a keyword list or a browse.*

Rank these results by a question. Every result stays listed, the closest first.

<!-- END SOURCE: search.layer.toolbar.help.rankByMeaning -->

*`search.layer.toolbar.help.rankWholeMatch %@` · 07-Search-and-Browse.md:2173*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.searchWithinResultsHelp | key: search.layer.toolbar.help.rankWholeMatch %@ -->

*The button's help over a keyword list or a browse cut at its ceiling (#1577 lane 6), in place of the sentence above, which would be untrue there: a question then ranks every result of the search and lists the closest up to the ceiling. %@ is the ceiling, 7,500.*

Rank every result of this search by a question, not only those loaded. The closest %@ are listed.

<!-- END SOURCE: search.layer.toolbar.help.rankWholeMatch %@ -->

*`search.layer.toolbar.help.unavailable` · 07-Search-and-Browse.md:2181*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.searchWithinResultsHelp | key: search.layer.toolbar.help.unavailable -->

*The button's help while it is dimmed with no list it can hold: no results, a search under way or failed, a list that is a layer's own, or a keyword list with no Meaning model to rank it.*

Hold the list on screen and search inside it with the other engine: words in a Meaning search’s matches, or a question over keyword results.

<!-- END SOURCE: search.layer.toolbar.help.unavailable -->

*`search.layer.toolbar.help.held` · 07-Search-and-Browse.md:2189*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.searchWithinResultsHelp | key: search.layer.toolbar.help.held -->

*The button's help while a list is held, when it is dimmed: a layer is never held again.*

You are searching within results already. Stop searching within them to hold another list.

<!-- END SOURCE: search.layer.toolbar.help.held -->

*`search.layer.engine.help %@` · 07-Search-and-Browse.md:2197*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.heldEngineHelp | key: search.layer.engine.help %@ -->

*The help of the plain label that takes the Keywords | Meaning control's place on the Mac while a list is held. %@ is the engine, "Keywords" or "Meaning". VoiceOver reads the label as the control it stands for, "Search by" (`search.mode.title`), with the engine as its value.*

While you search within results, the field searches by %@. Stop searching within them to choose the engine again.

<!-- END SOURCE: search.layer.engine.help %@ -->

##### 7.15 Search within these results (#1577 lanes 4 to 7) › The field (iOS and Mac)

*`search.layer.prompt.wordsInMatches` · 07-Search-and-Browse.md:2207*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | SearchLayerDirection.fieldPrompt | key: search.layer.prompt.wordsInMatches -->

*The search field's prompt while a Meaning list is held.*

Words to find in these matches…

<!-- END SOURCE: search.layer.prompt.wordsInMatches -->

*`search.layer.prompt.rankByMeaning` · 07-Search-and-Browse.md:2215*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | SearchLayerDirection.fieldPrompt | key: search.layer.prompt.rankByMeaning -->

*The search field's prompt while a keyword list or a browse is held.*

A question to rank these results by…

<!-- END SOURCE: search.layer.prompt.rankByMeaning -->

##### 7.15 Search within these results (#1577 lanes 4 to 7) › The row that names the base (iOS and Mac)

*`search.layer.base.within %@` · 07-Search-and-Browse.md:2225*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.rowDescription | key: search.layer.base.within %@ -->

*The row that takes the Keywords | Meaning control's place while a base is held; on the Mac, the row under the working corpus banner, beside which a label names the field's engine. %@ is one of the descriptions below.*

*In each description the words or the question are quoted once: a search typed as one phrase in quotation marks, `"offset agreement"`, fills the placeholder without its own marks, so the description's “…” are the only pair and the row reads "Within 212 results for “offset agreement”". Any other search fills it as typed (plan of record §6g, 2026-10-19).*

Within %@

<!-- END SOURCE: search.layer.base.within %@ -->

*`search.layer.base.a11y %@` · 07-Search-and-Browse.md:2235*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.accessibilityLabel | key: search.layer.base.a11y %@ -->

*What VoiceOver reads for the row, and announces when the base is held.*

Searching within %@

<!-- END SOURCE: search.layer.base.a11y %@ -->

*`search.layer.set.meaning %@ %@` · 07-Search-and-Browse.md:2243*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.meaning %@ %@ -->

*A Meaning list: its size, then its question in quotation marks.*

%1$@ closest matches to “%2$@”

<!-- END SOURCE: search.layer.set.meaning %@ %@ -->

*`search.layer.set.meaning.one %@` · 07-Search-and-Browse.md:2251*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.meaning.one %@ -->

*A Meaning list of one document.*

the closest match to “%@”

<!-- END SOURCE: search.layer.set.meaning.one %@ -->

*`search.layer.set.keywords %@ %@` · 07-Search-and-Browse.md:2259*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.keywords %@ %@ -->

*A keyword list that loaded every match: "212 results" or "1 result", then the words.*

%1$@ for “%2$@”

<!-- END SOURCE: search.layer.set.keywords %@ %@ -->

*`search.layer.set.keywords.cut %@ %@ %@` · 07-Search-and-Browse.md:2267*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.keywords.cut %@ %@ %@ -->

*A keyword list cut at its fetch ceiling, whose total is known: the rows loaded, the total, the words. A ranking of it is a ranking of that slice, which this says. Since #1577 lane 6 a question ranks the whole match of such a list, and the row reads “all … results” (below); this shows only for a list whose search the app does not know, which no screen holds today.*

the first %1$@ of %2$@ results for “%3$@”

<!-- END SOURCE: search.layer.set.keywords.cut %@ %@ %@ -->

*`search.layer.set.keywords.cutUnknown %@ %@` · 07-Search-and-Browse.md:2275*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.keywords.cutUnknown %@ %@ -->

*The same when the total could not be counted. Since #1577 lane 6, as the block above says, shown only for a list whose search is not known.*

the first %1$@ results for “%2$@”

<!-- END SOURCE: search.layer.set.keywords.cutUnknown %@ %@ -->

*`search.layer.set.browse %@ %@` · 07-Search-and-Browse.md:2283*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.browse %@ %@ -->

*A browse with no words, named by its filter: a person, a topic or a subject area.*

%1$@ for %2$@

<!-- END SOURCE: search.layer.set.browse %@ %@ -->

*`search.layer.set.browse.cut %@ %@ %@` · 07-Search-and-Browse.md:2291*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.browse.cut %@ %@ %@ -->

*A browse cut at its fetch ceiling, whose total is known. Since #1577 lane 6 such a browse held for a question reads “all … results” (below); this shows only for a browse whose search is not known.*

the first %1$@ of %2$@ results for %3$@

<!-- END SOURCE: search.layer.set.browse.cut %@ %@ %@ -->

*`search.layer.set.browse.cutUnknown %@ %@` · 07-Search-and-Browse.md:2299*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.browse.cutUnknown %@ %@ -->

*The same when the total could not be counted. Since #1577 lane 6, as the block above says, shown only for a browse whose search is not known.*

the first %1$@ results for %2$@

<!-- END SOURCE: search.layer.set.browse.cutUnknown %@ %@ -->

*`search.layer.set.keywords.whole %@ %@` · 07-Search-and-Browse.md:2307*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.keywords.whole %@ %@ -->

*A keyword list cut at its ceiling and held for a question, since #1577 lane 6: the question ranks the whole match, so the row names it whole, by the search's count, then the words.*

all %1$@ results for “%2$@”

<!-- END SOURCE: search.layer.set.keywords.whole %@ %@ -->

*`search.layer.set.keywords.wholeUnknown %@` · 07-Search-and-Browse.md:2315*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.keywords.wholeUnknown %@ -->

*The same when the search's count failed, until a question has ranked the match and counted it.*

every result for “%@”

<!-- END SOURCE: search.layer.set.keywords.wholeUnknown %@ -->

*`search.layer.set.browse.whole %@ %@` · 07-Search-and-Browse.md:2323*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.browse.whole %@ %@ -->

*A browse cut at its ceiling of 7,500 and held for a question (#1577 lane 6), named by its filter.*

all %1$@ results for %2$@

<!-- END SOURCE: search.layer.set.browse.whole %@ %@ -->

*`search.layer.set.browse.wholeUnknown %@` · 07-Search-and-Browse.md:2331*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.browse.wholeUnknown %@ -->

*The same when the browse's count failed.*

every result for %@

<!-- END SOURCE: search.layer.set.browse.wholeUnknown %@ -->

*`search.layer.set.browse.unnamed.whole %@` · 07-Search-and-Browse.md:2339*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.browse.unnamed.whole %@ -->

*A browse cut at its ceiling whose filter has no name to give (#1577 lane 6).*

all %@ results of your browse

<!-- END SOURCE: search.layer.set.browse.unnamed.whole %@ -->

*`search.layer.set.browse.unnamed.wholeUnknown` · 07-Search-and-Browse.md:2347*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.browse.unnamed.wholeUnknown -->

*The same when its count failed.*

every result of your browse

<!-- END SOURCE: search.layer.set.browse.unnamed.wholeUnknown -->

*`search.layer.set.browse.unnamed %@` · 07-Search-and-Browse.md:2355*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.setDescription | key: search.layer.set.browse.unnamed %@ -->

*A browse whose filter has no name to give.*

%@ of your browse

<!-- END SOURCE: search.layer.set.browse.unnamed %@ -->

*`search.layer.leftOut.reviewed.one` · 07-Search-and-Browse.md:2363*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.leftOutDescription | key: search.layer.leftOut.reviewed.one -->

*The row's second line when Checklist Mode was hiding one of the list's rows as it was held: the layer runs inside the list as it was shown.*

%@ result hidden as reviewed is not included.

<!-- END SOURCE: search.layer.leftOut.reviewed.one -->

*`search.layer.leftOut.reviewed.many` · 07-Search-and-Browse.md:2371*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.leftOutDescription | key: search.layer.leftOut.reviewed.many -->

*The same for several.*

%@ results hidden as reviewed are not included.

<!-- END SOURCE: search.layer.leftOut.reviewed.many -->

*`search.layer.leftOut.notDownloaded.one` · 07-Search-and-Browse.md:2379*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.leftOutDescription | key: search.layer.leftOut.notDownloaded.one -->

*The row's second line when the Meaning list had a close match in a volume not downloaded, which has no row to search.*

%@ match in a volume you have not downloaded is not included.

<!-- END SOURCE: search.layer.leftOut.notDownloaded.one -->

*`search.layer.leftOut.notDownloaded.many` · 07-Search-and-Browse.md:2387*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.leftOutDescription | key: search.layer.leftOut.notDownloaded.many -->

*The same for several.*

%@ matches in volumes you have not downloaded are not included.

<!-- END SOURCE: search.layer.leftOut.notDownloaded.many -->

*`search.layer.leave.a11y` · 07-Search-and-Browse.md:2395*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerBaseRow | key: search.layer.leave.a11y -->

*The row's close button, for VoiceOver and the Large Content Viewer. It puts the list back as it was, with no search; on the Mac, unless a filter changed while the list was held, when the list's search runs again under the filters in force. The Mac's row declares it too (`SearchSheet.swift`).*

Stop searching within these results

<!-- END SOURCE: search.layer.leave.a11y -->

*`search.layer.leave.help` · 07-Search-and-Browse.md:2403*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerBaseRow | key: search.layer.leave.help -->

*The close button's pointer help on iPad and the Mac, and its Large Content Viewer detail. The Mac's row declares it too (`SearchSheet.swift`).*

Show the list you were searching within again, as it was

<!-- END SOURCE: search.layer.leave.help -->

*`search.layer.announce.leave` · 07-Search-and-Browse.md:2411*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.leftAnnouncement | key: search.layer.announce.leave -->

*What VoiceOver announces when the reader leaves a base.*

Stopped searching within these results

<!-- END SOURCE: search.layer.announce.leave -->

##### 7.15 Search within these results (#1577 lanes 4 to 7) › A layer that found nothing (iOS and Mac)

*`search.layer.empty.searchLibrary` · 07-Search-and-Browse.md:2421*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerEmptyState.searchLibraryTitle | key: search.layer.empty.searchLibrary -->

*Under "None of your 100 closest matches contains these words": leaves the base and searches the words as keywords across the whole library.*

Search the Whole Library for These Words

<!-- END SOURCE: search.layer.empty.searchLibrary -->

*`search.layer.empty.ranked` · 07-Search-and-Browse.md:2429*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerEmptyState.rankedStatement | key: search.layer.empty.ranked -->

*What an empty ranking says. A ranking returns its whole list, so it is empty only when the filters, or a working corpus applied since, removed every member. Since #1577 lane 6 a ranking of a whole match whose set held documents that pass the filters says instead what a Meaning search inside a set says when it lists nothing (the documents could not be ranked, and why), since the filters narrowed its set before it was ranked and every document of it passes them.*

None of the results you are searching within passes your filters.

<!-- END SOURCE: search.layer.empty.ranked -->

*`search.layer.back.matches %@` · 07-Search-and-Browse.md:2437*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.backTitle | key: search.layer.back.matches %@ -->

*Back to a Meaning list of several.*

Back to the %@ Matches

<!-- END SOURCE: search.layer.back.matches %@ -->

*`search.layer.back.match` · 07-Search-and-Browse.md:2445*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.backTitle | key: search.layer.back.match -->

*Back to a Meaning list of one.*

Back to the Closest Match

<!-- END SOURCE: search.layer.back.match -->

*`search.layer.back.results %@` · 07-Search-and-Browse.md:2453*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.backTitle | key: search.layer.back.results %@ -->

*Back to a keyword list or a browse of several.*

Back to the %@ Results

<!-- END SOURCE: search.layer.back.results %@ -->

*`search.layer.back.result` · 07-Search-and-Browse.md:2461*

<!-- SOURCE: FRUSExplorer/Search/SearchLayering.swift | PinnedResultBase.backTitle | key: search.layer.back.result -->

*Back to a keyword list of one.*

Back to the Result

<!-- END SOURCE: search.layer.back.result -->

##### 7.15 Search within these results (#1577 lanes 4 to 7) › A ranking's unranked rows (iOS and Mac)

*`search.layer.unranked.many` · 07-Search-and-Browse.md:2471*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.unrankedHeader | key: search.layer.unranked.many -->

*The line over the rows a ranking could not rank, which follow the ranked ones in the list's own order: front matter and headings have no match data, and a volume's match file may not be on the device. The Meaning strip above says which. Shown under the relevance order only.*

%@ results not ranked by meaning

<!-- END SOURCE: search.layer.unranked.many -->

*`search.layer.unranked.one` · 07-Search-and-Browse.md:2479*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.unrankedHeader | key: search.layer.unranked.one -->

*The same for one row.*

%@ result not ranked by meaning

<!-- END SOURCE: search.layer.unranked.one -->

##### 7.15 Search within these results (#1577 lanes 4 to 7) › Swap (iOS and Mac, #1577 lane 7)

*`search.layer.swap` · 07-Search-and-Browse.md:2489*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.swapTitle | key: search.layer.swap -->

*The button on the row that names a held list, before its ✕, once a search has run inside the list: the two searches change places. The words or question searched inside the list run as a search of their own, under the working corpus and the filters in force, and the list's own words or question then run inside its results, so "7 of your 100 closest matches contain these words" becomes every result for the words, closest to the question first, and the reverse. Not offered for a browse with no words. A titled button with two passing arrows, on iPhone, iPad and the Mac; the Mac's row declares it too (`SearchSheet.swift`).*

Swap

<!-- END SOURCE: search.layer.swap -->

*`search.layer.swap.a11y` · 07-Search-and-Browse.md:2497*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.swapLabel | key: search.layer.swap.a11y -->

*Swap's name for VoiceOver, and the Large Content Viewer's title on iPhone and iPad.*

Swap the two searches

<!-- END SOURCE: search.layer.swap.a11y -->

*`search.layer.swap.help.rankByMeaning %@ %@` · 07-Search-and-Browse.md:2505*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.swapHelp | key: search.layer.swap.help.rankByMeaning %@ %@ -->

*Swap's help over words found in a Meaning list: its VoiceOver hint, its pointer help on iPad, its tooltip on the Mac, and what VoiceOver hears as the swap starts. The first `%@` is the words, the second the list's question. Each is quoted once, as the row quotes the held list: a search typed as one phrase in quotation marks fills its placeholder without its own marks.*

Search for “%1$@” first, then rank what it finds by “%2$@”

<!-- END SOURCE: search.layer.swap.help.rankByMeaning %@ %@ -->

*`search.layer.swap.help.wordsInMatches %@ %@` · 07-Search-and-Browse.md:2513*

<!-- SOURCE: FRUSExplorer/Search/SearchLayerViews.swift | SearchLayerCopy.swapHelp | key: search.layer.swap.help.wordsInMatches %@ %@ -->

*The same over a ranking of a keyword list. The first `%@` is the question, the second the list's words.*

Ask “%1$@” first, then find “%2$@” among its closest matches

<!-- END SOURCE: search.layer.swap.help.wordsInMatches %@ %@ -->

##### 7.16 A search result, as VoiceOver reads it (#1684)

*On iPhone and iPad a search result is one button, so VoiceOver reads it as one element, and its label replaces everything the row draws. Until #1684 the label was the heading alone. Since then it is the heading and then the row as it is drawn, joined by commas: the number where the row draws one, the heading, the dateline, the volume id as printed, the classification chip's own words (“Classification markings: %@”, the chip's label), the Editorial Note and Front Matter badges, and the tags (plan of record decision 73, the owner's choice of 2026-10-19). A Meaning search's score follows as the row's value (“Semantic match %lld percent”, above). The snippet is not read with the row: VoiceOver's More Content offers it. Each tag is an action as well. The Mac's rows are not one element, and none of this is the Mac's: VoiceOver reads each part a Mac row draws.*

*`search.result.a11y.numbered %@ %@` · 07-Search-and-Browse.md:2525*

<!-- SOURCE: FRUSExplorer/Search/SearchResultAccessibility.swift | SearchResultAccessibility.heading(for:) | key: search.result.a11y.numbered %@ %@ -->

*How a result's label begins when the row draws the document's number beside its heading: the number, then the heading (“7. Memorandum From…”). A heading that already opens with its number is read as it is printed, so neither form says the number twice.*

%1$@. %2$@

<!-- END SOURCE: search.result.a11y.numbered %@ %@ -->

*`search.result.a11y.tags %@` · 07-Search-and-Browse.md:2533*

<!-- SOURCE: FRUSExplorer/Search/SearchResultAccessibility.swift | SearchResultAccessibility.tagList(_:) | key: search.result.a11y.tags %@ -->

*The label's last part when the document carries tags: their names, in the order the row draws their chips, joined by commas.*

Tags: %@

<!-- END SOURCE: search.result.a11y.tags %@ -->

*`search.tagchip.a11y` · 07-Search-and-Browse.md:2541*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/Search/SearchResultAccessibility.swift | SearchResultAccessibility.filterAction(tagName:) | key: search.tagchip.a11y -->

*Interpolated with the tag's name — keep `\(tagName)` intact. The name of the result's VoiceOver action for each of its tags, and the chip's own name: it filters the search by the tag, as a tap on the chip does. Not offered while results are being selected, where a tap on a chip picks its row. The chips are buttons inside the row's button, which VoiceOver cannot reach, so until #1684 a VoiceOver reader could not filter by a tag from a result.*

Filter by \(tagName)

<!-- END SOURCE: search.tagchip.a11y -->

*`search.result.a11y.matchedText` · 07-Search-and-Browse.md:2549*

<!-- SOURCE: FRUSExplorer/Search/SearchResultAccessibility.swift | SearchResultAccessibility.moreContent(for:) | key: search.result.a11y.matchedText -->

*What VoiceOver's More Content calls a keyword search result's snippet: the words from just before the word the search matched, about 300 characters, cut at a space. It is not read when a reader lands on the row: the stored snippet runs to about 2,000 characters, where the row draws two lines of it. Since A10b the snippet starts about 30 characters before the word, so More Content takes those and the rest after it. Since #1760 the word is the rarest of the search's words that the text holds, across the reader's index, with words such as “the”, “of” and “why” set aside while the search has others, so a question typed as keywords no longer starts at “the”.*

Matched text

<!-- END SOURCE: search.result.a11y.matchedText -->

*`search.result.a11y.openingText` · 07-Search-and-Browse.md:2557*

<!-- SOURCE: FRUSExplorer/Search/SearchResultAccessibility.swift | SearchResultAccessibility.moreContent(for:) | key: search.result.a11y.openingText -->

*The same for a Meaning search result, whose snippet marks no word: it is the document's opening prose after its heading, source note and dateline. Since A10b a keyword result whose words are only in its heading, source note or dateline shows that opening prose too, and offers it under this name. A keyword result whose snippet is only its heading and dateline again offers nothing, ranked by a question or not, since the label has read both.*

Opening text

<!-- END SOURCE: search.result.a11y.openingText -->

#### 16. Browse — the axis captions

##### 16.4 Subjects › The subject data's caption, on every subject surface (#1905)

*`subjects.caption` · 07-Search-and-Browse.md:2642*

<!-- SOURCE: FRUSExplorer/Browser/VolumeSubjectProfilesStore.swift | SubjectDataCaption.text | lines: 78–79 | key: subjects.caption -->

Experimental subject data from the Office of the Historian, not published on history.state.gov. Subjects are matched to documents by name in the text; they are not editorial headings from the FRUS publication process, so some are wrong.

<!-- END SOURCE: subjects.caption -->

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.1 Search — scope footers, prompts, Meaning mode, facets and collocations › Ask a question to rank the %@ you are searching within by meaning.

*`search.prompt.meaning.withinSet %@` · 07-Search-and-Browse.md:2870*

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchMode.documentSetPrompt | lines: 185–186 | key: search.prompt.meaning.withinSet %@ -->

Ask a question to rank the %@ you are searching within by meaning. *(%@ is the set's size with its noun, “1 document” or “212 documents”.)*

<!-- END SOURCE: search.prompt.meaning.withinSet %@ -->

##### 18.1 Search — scope footers, prompts, Meaning mode, facets and collocations › Enter keywords to search the %@ you are searching within.

*`search.prompt.withinSet %@` · 07-Search-and-Browse.md:2880*

<!-- SOURCE: FRUSExplorer/Search/SearchModels.swift | SearchMode.documentSetPrompt | key: search.prompt.withinSet %@ -->

Enter keywords to search the %@ you are searching within. *(%@ is the set's size with its noun, “1 document” or “212 documents”.)*

<!-- END SOURCE: search.prompt.withinSet %@ -->

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › A volume’s count and share in a drill list (#1643)

*Added by #1643. Beside each volume in the list a provenance type or a central-file class opens: the volume’s documents from that door, and their share of its own sourced documents — “12 docs · 40%”. It read “1 docs · 3%” for a volume with one. `%1$@` is the count with its noun, “1 doc” or “1,204 docs”, the app’s shared short count; `%2$@` is the share. A volume with no sourced-document count shows the count alone. Keep `%%`, which prints one percent sign.*

*`browser.archives.accessory.share %@ %@` · 07-Search-and-Browse.md:2965*

<!-- SOURCE: FRUSExplorer/Browser/ArchivesBrowseView.swift | ArchivesAxis.volumeAccessory | lines: 123–124 | key: browser.archives.accessory.share %@ %@ | shared: iOS+macOS (single edit point) -->

%1$@ · %2$@%%

<!-- END SOURCE: browser.archives.accessory.share %@ %@ -->

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › Corpus row — The %@ closest matches of a Meaning search

*`browser.corpora.meaning %@` · 07-Search-and-Browse.md:3025*

<!-- SOURCE: FRUSCoreKit/Models/WorkingCorpusResolver.swift | CorpusCaptureTruncation.line | key: browser.corpora.meaning %@ -->

The %@ closest matches of a Meaning search *(%@ is the corpus's own document count.)*

<!-- END SOURCE: browser.corpora.meaning %@ -->

##### 18.7 Browse — axes, All Volumes, scopes, corpora, clusters and subjects › Corpus row — The closest match of a Meaning search

*`browser.corpora.meaning.one` · 07-Search-and-Browse.md:3032*

<!-- SOURCE: FRUSCoreKit/Models/WorkingCorpusResolver.swift | CorpusCaptureTruncation.line | key: browser.corpora.meaning.one -->

*The same, for a corpus of one document.*

The closest match of a Meaning search

<!-- END SOURCE: browser.corpora.meaning.one -->

#### 19. Browse — a volume page's Editors’ Annotations (the editors' annotations design, 2026-11-06)

##### 19.1 The section, its groups, and what a missing layer says

*`browser.volume.annotations.row.spoken` · 07-Search-and-Browse.md:3270*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.row.spoken -->

%1$@: %2$@.

<!-- END SOURCE: browser.volume.annotations.row.spoken -->

*`browser.volume.annotations.absent.spoken` · 07-Search-and-Browse.md:3276*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.absent.spoken -->

Not in this volume: %@.

<!-- END SOURCE: browser.volume.annotations.absent.spoken -->

*`browser.volume.annotations.header` · 07-Search-and-Browse.md:3282*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.header -->

Editors’ Annotations

<!-- END SOURCE: browser.volume.annotations.header -->

*`browser.volume.annotations.absent.header` · 07-Search-and-Browse.md:3288*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.absent.header -->

Not in this volume (%@)

<!-- END SOURCE: browser.volume.annotations.absent.header -->

*`browser.volume.annotations.absent.people.hint` · 07-Search-and-Browse.md:3294*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.absent.people.hint -->

Search the names instead.

<!-- END SOURCE: browser.volume.annotations.absent.people.hint -->

*`browser.volume.annotations.absent.onset` · 07-Search-and-Browse.md:3300*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.absent.onset -->

Standard in the volumes covering %@ on.

<!-- END SOURCE: browser.volume.annotations.absent.onset -->

*`browser.volume.annotations.group.named` · 07-Search-and-Browse.md:3306*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.group.named -->

Who is named

<!-- END SOURCE: browser.volume.annotations.group.named -->

*`browser.volume.annotations.group.provenance` · 07-Search-and-Browse.md:3312*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.group.provenance -->

Where it came from

<!-- END SOURCE: browser.volume.annotations.group.provenance -->

*`browser.volume.annotations.group.connects` · 07-Search-and-Browse.md:3318*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.group.connects -->

How it connects

<!-- END SOURCE: browser.volume.annotations.group.connects -->

##### 19.2 The layers' names

*`browser.volume.annotations.people` · 07-Search-and-Browse.md:3326*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.people -->

People tagged

<!-- END SOURCE: browser.volume.annotations.people -->

*`browser.volume.annotations.abbreviations` · 07-Search-and-Browse.md:3332*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.abbreviations -->

Abbreviations explained

<!-- END SOURCE: browser.volume.annotations.abbreviations -->

*`browser.volume.annotations.correspondents` · 07-Search-and-Browse.md:3338*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.correspondents -->

Senders and recipients

<!-- END SOURCE: browser.volume.annotations.correspondents -->

*`browser.volume.annotations.subjects` · 07-Search-and-Browse.md:3344*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.subjects -->

Subject lines

<!-- END SOURCE: browser.volume.annotations.subjects -->

*`browser.volume.annotations.participants` · 07-Search-and-Browse.md:3350*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.participants -->

Meeting participants

<!-- END SOURCE: browser.volume.annotations.participants -->

*`browser.volume.annotations.sourceNotes` · 07-Search-and-Browse.md:3356*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.sourceNotes -->

Source notes

<!-- END SOURCE: browser.volume.annotations.sourceNotes -->

*`browser.volume.annotations.classification` · 07-Search-and-Browse.md:3362*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.classification -->

Classification markings

<!-- END SOURCE: browser.volume.annotations.classification -->

*`browser.volume.annotations.excisions` · 07-Search-and-Browse.md:3368*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.excisions -->

Redactions marked as not declassified

<!-- END SOURCE: browser.volume.annotations.excisions -->

*`browser.volume.annotations.editorialOmissions` · 07-Search-and-Browse.md:3374*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.editorialOmissions -->

Marked editorial omissions

<!-- END SOURCE: browser.volume.annotations.editorialOmissions -->

*`browser.volume.annotations.despatch` · 07-Search-and-Browse.md:3380*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.despatch -->

Despatch numbers

<!-- END SOURCE: browser.volume.annotations.despatch -->

*`browser.volume.annotations.numbered` · 07-Search-and-Browse.md:3386*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.numbered -->

Numbered documents

<!-- END SOURCE: browser.volume.annotations.numbered -->

*`browser.volume.annotations.crossReferences` · 07-Search-and-Browse.md:3392*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.crossReferences -->

Cross-references

<!-- END SOURCE: browser.volume.annotations.crossReferences -->

*`browser.volume.annotations.referencesToDocuments` · 07-Search-and-Browse.md:3398*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.referencesToDocuments -->

References to documents

<!-- END SOURCE: browser.volume.annotations.referencesToDocuments -->

*`browser.volume.annotations.editorialNotes` · 07-Search-and-Browse.md:3404*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.editorialNotes -->

Editorial notes

<!-- END SOURCE: browser.volume.annotations.editorialNotes -->

*`browser.volume.annotations.footnotes` · 07-Search-and-Browse.md:3410*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.footnotes -->

Footnotes

<!-- END SOURCE: browser.volume.annotations.footnotes -->

*`browser.volume.annotations.marginalNotes` · 07-Search-and-Browse.md:3416*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.marginalNotes -->

Marginal notes

<!-- END SOURCE: browser.volume.annotations.marginalNotes -->

*`browser.volume.annotations.printedAids` · 07-Search-and-Browse.md:3422*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.printedAids -->

Front and back matter

<!-- END SOURCE: browser.volume.annotations.printedAids -->

*`browser.volume.annotations.noteOnSources` · 07-Search-and-Browse.md:3428*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.noteOnSources -->

Note on Sources

<!-- END SOURCE: browser.volume.annotations.noteOnSources -->

##### 19.3 The counts

*`browser.volume.annotations.ofDocuments.one` · 07-Search-and-Browse.md:3436*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.ofDocuments.one -->

%2$@ of %1$@ document

<!-- END SOURCE: browser.volume.annotations.ofDocuments.one -->

*`browser.volume.annotations.ofDocuments.many` · 07-Search-and-Browse.md:3442*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.ofDocuments.many -->

%2$@ of %1$@ documents

<!-- END SOURCE: browser.volume.annotations.ofDocuments.many -->

*`browser.volume.annotations.people.listed.one` · 07-Search-and-Browse.md:3448*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.people.listed.one -->

%@ person listed

<!-- END SOURCE: browser.volume.annotations.people.listed.one -->

*`browser.volume.annotations.people.listed.many` · 07-Search-and-Browse.md:3454*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.people.listed.many -->

%@ people listed

<!-- END SOURCE: browser.volume.annotations.people.listed.many -->

*`browser.volume.annotations.terms.listed.one` · 07-Search-and-Browse.md:3460*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.terms.listed.one -->

%@ term listed

<!-- END SOURCE: browser.volume.annotations.terms.listed.one -->

*`browser.volume.annotations.terms.listed.many` · 07-Search-and-Browse.md:3466*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.terms.listed.many -->

%@ terms listed

<!-- END SOURCE: browser.volume.annotations.terms.listed.many -->

*`browser.volume.annotations.sourceNotes.citations` · 07-Search-and-Browse.md:3472*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.sourceNotes.citations -->

archival citations (“Source: …”)

<!-- END SOURCE: browser.volume.annotations.sourceNotes.citations -->

*`browser.volume.annotations.sourceNotes.fileNumbers` · 07-Search-and-Browse.md:3478*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.sourceNotes.fileNumbers -->

file numbers above the heading

<!-- END SOURCE: browser.volume.annotations.sourceNotes.fileNumbers -->

*`browser.volume.annotations.sourceNotes.both` · 07-Search-and-Browse.md:3484*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.sourceNotes.both -->

archival citations and file numbers

<!-- END SOURCE: browser.volume.annotations.sourceNotes.both -->

*`browser.volume.annotations.excisions.one` · 07-Search-and-Browse.md:3490*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.excisions.one -->

%@ document with a redaction marked

<!-- END SOURCE: browser.volume.annotations.excisions.one -->

*`browser.volume.annotations.excisions.many` · 07-Search-and-Browse.md:3496*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.excisions.many -->

%@ documents with redactions marked

<!-- END SOURCE: browser.volume.annotations.excisions.many -->

*`browser.volume.annotations.editorialOmissions.one` · 07-Search-and-Browse.md:3502*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.editorialOmissions.one -->

%@ document with an editorial omission marked

<!-- END SOURCE: browser.volume.annotations.editorialOmissions.one -->

*`browser.volume.annotations.editorialOmissions.many` · 07-Search-and-Browse.md:3508*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.editorialOmissions.many -->

%@ documents with editorial omissions marked

<!-- END SOURCE: browser.volume.annotations.editorialOmissions.many -->

*`browser.volume.annotations.editorialNotes.one` · 07-Search-and-Browse.md:3514*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.editorialNotes.one -->

%@ editorial note

<!-- END SOURCE: browser.volume.annotations.editorialNotes.one -->

*`browser.volume.annotations.editorialNotes.many` · 07-Search-and-Browse.md:3520*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.editorialNotes.many -->

%@ editorial notes

<!-- END SOURCE: browser.volume.annotations.editorialNotes.many -->

*`browser.volume.annotations.xrefs.documents.one` · 07-Search-and-Browse.md:3526*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.xrefs.documents.one -->

%@ document cites another in this volume

<!-- END SOURCE: browser.volume.annotations.xrefs.documents.one -->

*`browser.volume.annotations.xrefs.documents.many` · 07-Search-and-Browse.md:3532*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.xrefs.documents.many -->

%@ documents cite others in this volume

<!-- END SOURCE: browser.volume.annotations.xrefs.documents.many -->

*`browser.volume.annotations.xrefs.volumes.one` · 07-Search-and-Browse.md:3538*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.xrefs.volumes.one -->

%@ document cites other volumes

<!-- END SOURCE: browser.volume.annotations.xrefs.volumes.one -->

*`browser.volume.annotations.xrefs.volumes.many` · 07-Search-and-Browse.md:3544*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.xrefs.volumes.many -->

%@ documents cite other volumes

<!-- END SOURCE: browser.volume.annotations.xrefs.volumes.many -->

*`browser.volume.annotations.xrefs.pages.one` · 07-Search-and-Browse.md:3550*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.xrefs.pages.one -->

%@ document cites printed pages

<!-- END SOURCE: browser.volume.annotations.xrefs.pages.one -->

*`browser.volume.annotations.xrefs.pages.many` · 07-Search-and-Browse.md:3556*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.xrefs.pages.many -->

%@ documents cite printed pages

<!-- END SOURCE: browser.volume.annotations.xrefs.pages.many -->

##### 19.4 The names of the front and back matter

*`browser.volume.annotations.aid.preface` · 07-Search-and-Browse.md:3564*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.preface -->

Preface

<!-- END SOURCE: browser.volume.annotations.aid.preface -->

*`browser.volume.annotations.aid.foreword` · 07-Search-and-Browse.md:3570*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.foreword -->

Foreword

<!-- END SOURCE: browser.volume.annotations.aid.foreword -->

*`browser.volume.annotations.aid.introduction` · 07-Search-and-Browse.md:3576*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.introduction -->

Introduction

<!-- END SOURCE: browser.volume.annotations.aid.introduction -->

*`browser.volume.annotations.aid.sources` · 07-Search-and-Browse.md:3582*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.sources -->

Sources

<!-- END SOURCE: browser.volume.annotations.aid.sources -->

*`browser.volume.annotations.aid.terms` · 07-Search-and-Browse.md:3588*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.terms -->

Abbreviations

<!-- END SOURCE: browser.volume.annotations.aid.terms -->

*`browser.volume.annotations.aid.persons` · 07-Search-and-Browse.md:3594*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.persons -->

Persons

<!-- END SOURCE: browser.volume.annotations.aid.persons -->

*`browser.volume.annotations.aid.listOfPapers` · 07-Search-and-Browse.md:3600*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.listOfPapers -->

List of Papers

<!-- END SOURCE: browser.volume.annotations.aid.listOfPapers -->

*`browser.volume.annotations.aid.covertActions` · 07-Search-and-Browse.md:3606*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.covertActions -->

Note on U.S. Covert Actions

<!-- END SOURCE: browser.volume.annotations.aid.covertActions -->

*`browser.volume.annotations.aid.pressRelease` · 07-Search-and-Browse.md:3612*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.pressRelease -->

Press Release

<!-- END SOURCE: browser.volume.annotations.aid.pressRelease -->

*`browser.volume.annotations.aid.volumeSummary` · 07-Search-and-Browse.md:3618*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.volumeSummary -->

Volume Summary

<!-- END SOURCE: browser.volume.annotations.aid.volumeSummary -->

*`browser.volume.annotations.aid.index` · 07-Search-and-Browse.md:3624*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.index -->

Index

<!-- END SOURCE: browser.volume.annotations.aid.index -->

*`browser.volume.annotations.aid.errata` · 07-Search-and-Browse.md:3630*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsPresentation.swift | key: browser.volume.annotations.aid.errata -->

Errata

<!-- END SOURCE: browser.volume.annotations.aid.errata -->

#### 20. Browse — the Editors’ Annotations axis (the editors' annotations design, lane C, 2026-11-06)

##### 20.1 The door, the axis and its rows

*`browser.corpus.tile.annotations` · 07-Search-and-Browse.md:3642*

<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | key: browser.corpus.tile.annotations -->

*The door's title: a tile in the Browse by grid on iPhone and iPad, after Editors and before Archives. A grid tile holds one line, so the axis's own name, Editors’ Annotations, is shortened here. VoiceOver reads the tile by the label two blocks down.*

Annotations

<!-- END SOURCE: browser.corpus.tile.annotations -->

*`browser.corpus.tile.annotations.a11y` · 07-Search-and-Browse.md:3660*

<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | key: browser.corpus.tile.annotations.a11y -->

Browse by editors' annotations

<!-- END SOURCE: browser.corpus.tile.annotations.a11y -->

*`browser.corpus.tile.annotations.help` · 07-Search-and-Browse.md:3666*

<!-- SOURCE: FRUSExplorer/Browser/CorpusView.swift | key: browser.corpus.tile.annotations.help -->

Volumes categorized by what their editors annotated — people tagged, source notes, classification and more — and the era each practice became standard

<!-- END SOURCE: browser.corpus.tile.annotations.help -->

*`browser.annotations.index.caption` · 07-Search-and-Browse.md:3672*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.index.caption -->

What the editors of %@ annotated, layer by layer. A layer that runs through a volume, such as people tagged, counts when it reaches at least half the volume's documents. Annotation types found here and there, such as an editorial note, when one document carries it. Each strip shades the eras, earliest first and the late retrospectives last, by the share of their volumes that carry the layer.

<!-- END SOURCE: browser.annotations.index.caption -->

*`browser.annotations.ofVolumes.one` · 07-Search-and-Browse.md:3678*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.ofVolumes.one -->

%2$@ of %1$@ volume

<!-- END SOURCE: browser.annotations.ofVolumes.one -->

*`browser.annotations.ofVolumes.many` · 07-Search-and-Browse.md:3684*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.ofVolumes.many -->

%2$@ of %1$@ volumes

<!-- END SOURCE: browser.annotations.ofVolumes.many -->

*`browser.annotations.row.spoken` · 07-Search-and-Browse.md:3690*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.row.spoken -->

%1$@: %2$@.

<!-- END SOURCE: browser.annotations.row.spoken -->

*`browser.annotations.row.help` · 07-Search-and-Browse.md:3696*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: browser.annotations.row.help -->

What the editors did, when it became standard, and the volumes that carry it

<!-- END SOURCE: browser.annotations.row.help -->

*`browser.annotations.standard.none` · 07-Search-and-Browse.md:3702*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.standard.none -->

No era made it standard. It is most common in the volumes covering %@.

<!-- END SOURCE: browser.annotations.standard.none -->

*`browser.annotations.standard.none.retrospective` · 07-Search-and-Browse.md:3708*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.standard.none.retrospective -->

No era made it standard. It is most common in the late retrospective volumes.

<!-- END SOURCE: browser.annotations.standard.none.retrospective -->

*`browser.annotations.standard.redactions` · 07-Search-and-Browse.md:3714*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.standard.redactions -->

Volumes produced after the passage of the 1991 statute include explicit editorial annotation of redactions made during the declassification process.

<!-- END SOURCE: browser.annotations.standard.redactions -->

*`browser.annotations.era.span` · 07-Search-and-Browse.md:3720*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.era.span -->

%1$@–%2$@

<!-- END SOURCE: browser.annotations.era.span -->

*`browser.annotations.era.from` · 07-Search-and-Browse.md:3726*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.era.from -->

%@ on

<!-- END SOURCE: browser.annotations.era.from -->

*`browser.annotations.era.retrospective` · 07-Search-and-Browse.md:3732*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.era.retrospective -->

the late retrospectives

<!-- END SOURCE: browser.annotations.era.retrospective -->

*`browser.annotations.era.retrospective.title` · 07-Search-and-Browse.md:3738*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.era.retrospective.title -->

Late retrospectives

<!-- END SOURCE: browser.annotations.era.retrospective.title -->

*`browser.annotations.era.retrospective.short` · 07-Search-and-Browse.md:3744*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.era.retrospective.short -->

Retro.

<!-- END SOURCE: browser.annotations.era.retrospective.short -->

*`browser.annotations.band.spoken` · 07-Search-and-Browse.md:3750*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.band.spoken -->

%1$@: %2$@

<!-- END SOURCE: browser.annotations.band.spoken -->

*`browser.annotations.unavailable.title` · 07-Search-and-Browse.md:3756*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: browser.annotations.unavailable.title -->

Editors’ Annotations Unavailable

<!-- END SOURCE: browser.annotations.unavailable.title -->

*`browser.annotations.unavailable.detail` · 07-Search-and-Browse.md:3762*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: browser.annotations.unavailable.detail -->

The bundled annotation data could not be loaded. Reinstalling the app restores it.

<!-- END SOURCE: browser.annotations.unavailable.detail -->

##### 20.2 A layer's page

*`browser.annotations.category.practice` · 07-Search-and-Browse.md:3770*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: browser.annotations.category.practice -->

What the editors did

<!-- END SOURCE: browser.annotations.category.practice -->

*`browser.annotations.category.eras` · 07-Search-and-Browse.md:3776*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: browser.annotations.category.eras -->

Era by era

<!-- END SOURCE: browser.annotations.category.eras -->

*`browser.annotations.category.app` · 07-Search-and-Browse.md:3782*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: browser.annotations.category.app -->

In the app

<!-- END SOURCE: browser.annotations.category.app -->

*`browser.annotations.category.volumes` · 07-Search-and-Browse.md:3788*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: browser.annotations.category.volumes -->

Volumes

<!-- END SOURCE: browser.annotations.category.volumes -->

*`browser.annotations.link.people` · 07-Search-and-Browse.md:3794*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.link.people -->

Open People

<!-- END SOURCE: browser.annotations.link.people -->

*`browser.annotations.link.archives` · 07-Search-and-Browse.md:3800*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.link.archives -->

Open Archives

<!-- END SOURCE: browser.annotations.link.archives -->

*`browser.annotations.drill.with` · 07-Search-and-Browse.md:3806*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.drill.with -->

Volumes with it

<!-- END SOURCE: browser.annotations.drill.with -->

*`browser.annotations.drill.without` · 07-Search-and-Browse.md:3812*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.drill.without -->

Volumes without it

<!-- END SOURCE: browser.annotations.drill.without -->

*`browser.annotations.drill.sourceCitation` · 07-Search-and-Browse.md:3818*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.drill.sourceCitation -->

Archival citations (“Source: …”)

<!-- END SOURCE: browser.annotations.drill.sourceCitation -->

*`browser.annotations.drill.sourceFileNumber` · 07-Search-and-Browse.md:3824*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.drill.sourceFileNumber -->

File numbers above the heading

<!-- END SOURCE: browser.annotations.drill.sourceFileNumber -->

*`browser.annotations.drill.spoken` · 07-Search-and-Browse.md:3830*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: browser.annotations.drill.spoken -->

%1$@: %2$@

<!-- END SOURCE: browser.annotations.drill.spoken -->

##### 20.3 Each layer: what the editors did, when a volume counts, and what the app does with it

*`browser.annotations.practice.people` · 07-Search-and-Browse.md:3838*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.people -->

The editors identified the key people in the volume and included a List of Persons with short summary descriptions of their official roles. These people are tagged as they appear in each document in the volume.

<!-- END SOURCE: browser.annotations.practice.people -->

*`browser.annotations.rule.people` · 07-Search-and-Browse.md:3844*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.people -->

A volume counts when at least half its documents link a name to its List of Persons.

<!-- END SOURCE: browser.annotations.rule.people -->

*`browser.annotations.app.people` · 07-Search-and-Browse.md:3850*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.people -->

The People browser and Person analytics read these links. Where a volume does not link its names, rely on keyword search instead.

<!-- END SOURCE: browser.annotations.app.people -->

*`browser.annotations.practice.abbreviations` · 07-Search-and-Browse.md:3856*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.abbreviations -->

The editors identified common abbreviations in the volume and included a List of Abbreviations that explains what they mean.

<!-- END SOURCE: browser.annotations.practice.abbreviations -->

*`browser.annotations.rule.abbreviations` · 07-Search-and-Browse.md:3862*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.abbreviations -->

A volume counts when at least half its documents link a term to its List of Abbreviations.

<!-- END SOURCE: browser.annotations.rule.abbreviations -->

*`browser.annotations.app.abbreviations` · 07-Search-and-Browse.md:3868*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.abbreviations -->

The reader opens a linked abbreviation's meaning.

<!-- END SOURCE: browser.annotations.app.abbreviations -->

*`browser.annotations.practice.correspondents` · 07-Search-and-Browse.md:3874*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.correspondents -->

The editors marked who sent each document, and to whom, in its heading.

<!-- END SOURCE: browser.annotations.practice.correspondents -->

*`browser.annotations.rule.correspondents` · 07-Search-and-Browse.md:3880*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.correspondents -->

A volume counts when at least half its documents mark a sender or a recipient in the heading.

<!-- END SOURCE: browser.annotations.rule.correspondents -->

*`browser.annotations.practice.subjects` · 07-Search-and-Browse.md:3886*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.subjects -->

Where a memorandum carried a Subject line, the editors printed it with the memorandum.

<!-- END SOURCE: browser.annotations.practice.subjects -->

*`browser.annotations.rule.subjects` · 07-Search-and-Browse.md:3892*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.subjects -->

A volume counts when one of its documents prints a Subject line.

<!-- END SOURCE: browser.annotations.rule.subjects -->

*`browser.annotations.practice.participants` · 07-Search-and-Browse.md:3898*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.participants -->

Where a memorandum of conversation lists who took part, the editors marked the list.

<!-- END SOURCE: browser.annotations.practice.participants -->

*`browser.annotations.rule.participants` · 07-Search-and-Browse.md:3904*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.participants -->

A volume counts when one of its documents lists who attended a meeting.

<!-- END SOURCE: browser.annotations.rule.participants -->

*`browser.annotations.practice.sourceNotes` · 07-Search-and-Browse.md:3910*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.sourceNotes -->

A source note says where the editors found a document. It was printed first as a file number above the heading, and later as a note that begins “Source:” with the full archival citation. The earliest volumes print none: a despatch there carries its assigned serial number instead.

<!-- END SOURCE: browser.annotations.practice.sourceNotes -->

*`browser.annotations.rule.sourceNotes` · 07-Search-and-Browse.md:3916*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.sourceNotes -->

A volume counts when at least half its documents carry a source note, of either form.

<!-- END SOURCE: browser.annotations.rule.sourceNotes -->

*`browser.annotations.app.sourceNotes` · 07-Search-and-Browse.md:3922*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.sourceNotes -->

Source Explorer and the Archives axis read them, and a chapter's list of documents shows the first line of each note.

<!-- END SOURCE: browser.annotations.app.sourceNotes -->

*`browser.annotations.practice.classification` · 07-Search-and-Browse.md:3928*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.classification -->

The editors printed each document's security classification, first above the dateline and later in the source note.

<!-- END SOURCE: browser.annotations.practice.classification -->

*`browser.annotations.rule.classification` · 07-Search-and-Browse.md:3934*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.classification -->

A volume counts when at least half its documents carry a classification marking, as the app reads them.

<!-- END SOURCE: browser.annotations.rule.classification -->

*`browser.annotations.app.classification` · 07-Search-and-Browse.md:3940*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.classification -->

Search's results and Source Explorer show a document's marking.

<!-- END SOURCE: browser.annotations.app.classification -->

*`browser.annotations.practice.excisions` · 07-Search-and-Browse.md:3946*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.excisions -->

The editors mark what declassification review redacted: a gap in the printed text, “[… not declassified]”, or a whole document withheld, listed in its place with its heading, its source note and the number of pages not declassified. From Secretary Kellogg’s 1925 order until the 1991 statute, volumes marked an omission with an ellipsis, whether the editors left the text out or it was not cleared for publication, so declassification redactions cannot be distinguished from editorial omissions. They are not counted here. Volumes published before the 1925 order marked an omission with a row of asterisks, under no written rule and without saying whose cut it was; those are not counted here either.

<!-- END SOURCE: browser.annotations.practice.excisions -->

*`browser.annotations.rule.excisions` · 07-Search-and-Browse.md:3952*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.excisions -->

A volume counts when one of its documents marks a redaction as not declassified: text in it, or the whole document.

<!-- END SOURCE: browser.annotations.rule.excisions -->

*`browser.annotations.practice.editorialOmissions` · 07-Search-and-Browse.md:3958*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.editorialOmissions -->

Since Secretary Kellogg’s 1925 order, where the editors left out part of a document as not relevant to the volume, they could say so in brackets and describe what was omitted. Until the 1991 statute an ellipsis could also mark an omission, the editors’ or a redaction, and those are not counted here. Volumes published before the order marked an omission with a row of asterisks, not a bracketed note, and are not counted here.

<!-- END SOURCE: browser.annotations.practice.editorialOmissions -->

*`browser.annotations.rule.editorialOmissions` · 07-Search-and-Browse.md:3964*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.editorialOmissions -->

A volume published from 1925 counts when one of its documents says, in brackets, what the editors left out: “[Here follows …]” or “[Omitted here is …]”.

<!-- END SOURCE: browser.annotations.rule.editorialOmissions -->

*`browser.annotations.practice.despatch` · 07-Search-and-Browse.md:3970*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.despatch -->

Older volumes print the number a diplomatic post gave each despatch it sent, “No. 74.”, by which the despatch is found in the archives.

<!-- END SOURCE: browser.annotations.practice.despatch -->

*`browser.annotations.rule.despatch` · 07-Search-and-Browse.md:3976*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.despatch -->

A volume counts when at least a tenth of its documents carry a despatch number.

<!-- END SOURCE: browser.annotations.rule.despatch -->

*`browser.annotations.app.despatch` · 07-Search-and-Browse.md:3982*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.despatch -->

Source Explorer shows a document's despatch number with its archival series.

<!-- END SOURCE: browser.annotations.app.despatch -->

*`browser.annotations.practice.numbered` · 07-Search-and-Browse.md:3988*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.numbered -->

The editors numbered the documents in print, so that each heading opens with its number: “12. Telegram From …”.

<!-- END SOURCE: browser.annotations.practice.numbered -->

*`browser.annotations.rule.numbered` · 07-Search-and-Browse.md:3994*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.numbered -->

A volume counts when at least half its documents print a document number.

<!-- END SOURCE: browser.annotations.rule.numbered -->

*`browser.annotations.app.numbered` · 07-Search-and-Browse.md:4000*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.numbered -->

Document titles and citations give the number the volume prints.

<!-- END SOURCE: browser.annotations.app.numbered -->

*`browser.annotations.practice.crossReferences` · 07-Search-and-Browse.md:4006*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.crossReferences -->

The editors' notes point to other documents in the volume, to other volumes and to printed pages: “See Document 12”, “see p. 123”.

<!-- END SOURCE: browser.annotations.practice.crossReferences -->

*`browser.annotations.rule.crossReferences` · 07-Search-and-Browse.md:4012*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.crossReferences -->

A volume counts when one of its documents cites another of its documents, another volume or a printed page.

<!-- END SOURCE: browser.annotations.rule.crossReferences -->

*`browser.annotations.app.crossReferences` · 07-Search-and-Browse.md:4018*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.crossReferences -->

The reader follows each one, and the Cross-Reference graph and Cross-Volume Connections draw them.

<!-- END SOURCE: browser.annotations.app.crossReferences -->

*`browser.annotations.practice.editorialNotes` · 07-Search-and-Browse.md:4024*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.editorialNotes -->

Where no single document tells the story, the editors wrote a note of their own, set between the documents.

<!-- END SOURCE: browser.annotations.practice.editorialNotes -->

*`browser.annotations.rule.editorialNotes` · 07-Search-and-Browse.md:4030*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.editorialNotes -->

A volume counts when it prints an editorial note.

<!-- END SOURCE: browser.annotations.rule.editorialNotes -->

*`browser.annotations.app.editorialNotes` · 07-Search-and-Browse.md:4036*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.editorialNotes -->

Search can limit its results to editorial notes.

<!-- END SOURCE: browser.annotations.app.editorialNotes -->

*`browser.annotations.practice.footnotes` · 07-Search-and-Browse.md:4042*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.footnotes -->

The editors' footnotes usually explain context or reference other documents.

<!-- END SOURCE: browser.annotations.practice.footnotes -->

*`browser.annotations.rule.footnotes` · 07-Search-and-Browse.md:4048*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.footnotes -->

A volume counts when at least half its documents carry a footnote.

<!-- END SOURCE: browser.annotations.rule.footnotes -->

*`browser.annotations.app.footnotes` · 07-Search-and-Browse.md:4054*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.footnotes -->

The reader shows each footnote with its document.

<!-- END SOURCE: browser.annotations.app.footnotes -->

*`browser.annotations.practice.marginalNotes` · 07-Search-and-Browse.md:4060*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.marginalNotes -->

A few volumes print notes written in a document's margin, set off from its text.

<!-- END SOURCE: browser.annotations.practice.marginalNotes -->

*`browser.annotations.rule.marginalNotes` · 07-Search-and-Browse.md:4066*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.marginalNotes -->

A volume counts when one of its documents prints a marginal note.

<!-- END SOURCE: browser.annotations.rule.marginalNotes -->

*`browser.annotations.practice.printedAids` · 07-Search-and-Browse.md:4072*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.practice.printedAids -->

Besides its documents, a volume prints front and back matter to help readers use it: a preface, lists of sources, abbreviations and persons, an index.

<!-- END SOURCE: browser.annotations.practice.printedAids -->

*`browser.annotations.rule.printedAids` · 07-Search-and-Browse.md:4078*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.printedAids -->

A volume counts when it prints one of the sections listed below.

<!-- END SOURCE: browser.annotations.rule.printedAids -->

*`browser.annotations.app.printedAids` · 07-Search-and-Browse.md:4084*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.printedAids -->

A volume's page lists them under Front Matter and Back Matter, and the reader opens each one.

<!-- END SOURCE: browser.annotations.app.printedAids -->

*`browser.annotations.app.none` · 07-Search-and-Browse.md:4090*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.app.none -->

The reader shows these as printed. Nothing else in the app reads them yet.

<!-- END SOURCE: browser.annotations.app.none -->

##### 20.4 A drill's list

*`browser.annotations.drill.with.title` · 07-Search-and-Browse.md:4098*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.drill.with.title -->

With: %@

<!-- END SOURCE: browser.annotations.drill.with.title -->

*`browser.annotations.drill.without.title` · 07-Search-and-Browse.md:4104*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.drill.without.title -->

Without: %@

<!-- END SOURCE: browser.annotations.drill.without.title -->

*`browser.annotations.drill.caption` · 07-Search-and-Browse.md:4110*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.drill.caption -->

%1$@. %2$@

<!-- END SOURCE: browser.annotations.drill.caption -->

*`browser.annotations.rule.sourceForm` · 07-Search-and-Browse.md:4116*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.sourceForm -->

A volume counts when at least half its documents carry a source note of this form.

<!-- END SOURCE: browser.annotations.rule.sourceForm -->

*`browser.annotations.rule.aid` · 07-Search-and-Browse.md:4122*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.rule.aid -->

A volume counts when it prints this section.

<!-- END SOURCE: browser.annotations.rule.aid -->

*`browser.annotations.accessory.notes.one` · 07-Search-and-Browse.md:4128*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.accessory.notes.one -->

%@ note

<!-- END SOURCE: browser.annotations.accessory.notes.one -->

*`browser.annotations.accessory.notes.many` · 07-Search-and-Browse.md:4134*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.accessory.notes.many -->

%@ notes

<!-- END SOURCE: browser.annotations.accessory.notes.many -->

*`browser.annotations.note.from` · 07-Search-and-Browse.md:4140*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.note.from -->

You came here from this volume.

<!-- END SOURCE: browser.annotations.note.from -->

*`browser.annotations.note.people.unlinked` · 07-Search-and-Browse.md:4146*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.note.people.unlinked -->

Prints a List of Persons, but none of its documents links a name to it.

<!-- END SOURCE: browser.annotations.note.people.unlinked -->

*`browser.annotations.note.abbreviations.unlinked` · 07-Search-and-Browse.md:4152*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.note.abbreviations.unlinked -->

Prints a List of Abbreviations, but none of its documents links a term to it.

<!-- END SOURCE: browser.annotations.note.abbreviations.unlinked -->

*`browser.annotations.note.editorialOmissions.before1925` · 07-Search-and-Browse.md:4158*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.note.editorialOmissions.before1925 -->

Published before the 1925 order, when the editors marked an omission with a row of asterisks, not a bracketed note.

<!-- END SOURCE: browser.annotations.note.editorialOmissions.before1925 -->

##### 20.5 A volume page's rows

*`browser.volume.annotations.row.hint` · 07-Search-and-Browse.md:4166*

<!-- SOURCE: FRUSExplorer/Browser/VolumeAnnotationsSection.swift | key: browser.volume.annotations.row.hint -->

Opens what the editors did, and the volumes that carry it.

<!-- END SOURCE: browser.volume.annotations.row.hint -->

##### 20.6 The matrix, and the line the People browser and Person analytics carry

*`browser.annotations.era.drill.title` · 07-Search-and-Browse.md:4176*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.era.drill.title -->

%1$@, %2$@

<!-- END SOURCE: browser.annotations.era.drill.title -->

*`browser.annotations.cell.spoken` · 07-Search-and-Browse.md:4182*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxis.swift | key: browser.annotations.cell.spoken -->

%1$@, %2$@

<!-- END SOURCE: browser.annotations.cell.spoken -->

*`people.tagging.caption` · 07-Search-and-Browse.md:4188*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: people.tagging.caption -->

People are tagged in %@, and only those volumes' people appear here. In the others, search for the names.

<!-- END SOURCE: people.tagging.caption -->

*`people.tagging.link` · 07-Search-and-Browse.md:4194*

<!-- SOURCE: FRUSExplorer/Browser/AnnotationsAxisViews.swift | key: people.tagging.link -->

Volumes that tag people

<!-- END SOURCE: people.tagging.link -->

### 08 Reading, Research & Collections — new

#### 6. Settings, Tips & Collections (continued)

##### Reading — the actions on a selection (#1540) › A highlight colour — what VoiceOver reads

*`selectionBar.highlightColor.a11y` · 08-Reading-Research-Collections.md:558*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/DocumentView/FloatingSelectionBar.swift | SelectionVerb.title | lines: 32–33 | key: selectionBar.highlightColor.a11y | shared: iOS+macOS (single edit point) -->

Highlight \(color.displayName)

<!-- END SOURCE: selectionBar.highlightColor.a11y -->

##### Reading — the actions on a selection (#1540) › Excerpt

*`selectionBar.excerpt` · 08-Reading-Research-Collections.md:565*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/DocumentView/FloatingSelectionBar.swift | SelectionVerb.title | lines: 35–35 | key: selectionBar.excerpt | shared: iOS+macOS (single edit point) -->

Excerpt

<!-- END SOURCE: selectionBar.excerpt -->

##### Reading — the actions on a selection (#1540) › Look Up in NARA

*`selectionBar.lookUpInNARA` · 08-Reading-Research-Collections.md:572*

<!-- SOURCE: FRUSExplorer/DocumentView/FloatingSelectionBar.swift | SelectionVerb.title | lines: 37–37 | key: selectionBar.lookUpInNARA | shared: iOS+macOS (single edit point) -->

Look Up in NARA

<!-- END SOURCE: selectionBar.lookUpInNARA -->

##### Reading — the actions on a selection (#1540) › Note

*`selectionBar.note` · 08-Reading-Research-Collections.md:581*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/DocumentView/FloatingSelectionBar.swift | SelectionVerb.title | lines: 39–39 | key: selectionBar.note | shared: iOS+macOS (single edit point) -->

Note

<!-- END SOURCE: selectionBar.note -->

##### Collections Export › Export format grid — Web page

*`export.grid.html.caption.v2` · 08-Reading-Research-Collections.md:908*

<!-- SOURCE: FRUSExplorer/Collections/CollectionExporter+App.swift | ExportFormat.gridCaption | key: export.grid.html.caption.v2 -->

Web page

<!-- END SOURCE: export.grid.html.caption.v2 -->

##### Collections — the six templates (L25, decision 139) › Full text as printed

*`collection.preset.fullTextAsPrinted` · 08-Reading-Research-Collections.md:919*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.displayName | lines: 95–96 | key: collection.preset.fullTextAsPrinted | shared: iOS+macOS (single edit point) -->

*The card's name, template 1 of 6.*

Full text as printed

<!-- END SOURCE: collection.preset.fullTextAsPrinted -->

##### Collections — the six templates (L25, decision 139) › Footnotes · source notes · bibliography · archives

*`collection.preset.fullTextAsPrinted.subtitle` · 08-Reading-Research-Collections.md:928*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.subtitle | lines: 119–120 | key: collection.preset.fullTextAsPrinted.subtitle | shared: iOS+macOS (single edit point) -->

*The line under the card's name, template 1 of 6.*

Footnotes · source notes · bibliography · archives

<!-- END SOURCE: collection.preset.fullTextAsPrinted.subtitle -->

##### Collections — the six templates (L25, decision 139) › Printed

*`collection.preset.fullTextAsPrinted.short` · 08-Reading-Research-Collections.md:937*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortName | lines: 157–157 | key: collection.preset.fullTextAsPrinted.short | shared: iOS+macOS (single edit point) -->

*The chip's name on iPhone, template 1 of 6.*

Printed

<!-- END SOURCE: collection.preset.fullTextAsPrinted.short -->

##### Collections — the six templates (L25, decision 139) › full text

*`collection.preset.fullTextAsPrinted.tag` · 08-Reading-Research-Collections.md:946*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortTag | lines: 176–176 | key: collection.preset.fullTextAsPrinted.tag | shared: iOS+macOS (single edit point) -->

*The word under the chip, template 1 of 6.*

full text

<!-- END SOURCE: collection.preset.fullTextAsPrinted.tag -->

##### Collections — the six templates (L25, decision 139) › Full text with your annotations

*`collection.preset.fullTextWithAnnotations` · 08-Reading-Research-Collections.md:955*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.displayName | lines: 98–99 | key: collection.preset.fullTextWithAnnotations | shared: iOS+macOS (single edit point) -->

*The card's name, template 2 of 6.*

Full text with your annotations

<!-- END SOURCE: collection.preset.fullTextWithAnnotations -->

##### Collections — the six templates (L25, decision 139) › Notes · highlights · headnotes · chronology · persons

*`collection.preset.fullTextWithAnnotations.subtitle` · 08-Reading-Research-Collections.md:964*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.subtitle | lines: 122–123 | key: collection.preset.fullTextWithAnnotations.subtitle | shared: iOS+macOS (single edit point) -->

*The line under the card's name, template 2 of 6.*

Notes · highlights · headnotes · chronology · persons

<!-- END SOURCE: collection.preset.fullTextWithAnnotations.subtitle -->

##### Collections — the six templates (L25, decision 139) › Annotated

*`collection.preset.fullTextWithAnnotations.short` · 08-Reading-Research-Collections.md:973*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortName | lines: 159–159 | key: collection.preset.fullTextWithAnnotations.short | shared: iOS+macOS (single edit point) -->

*The chip's name on iPhone, template 2 of 6.*

Annotated

<!-- END SOURCE: collection.preset.fullTextWithAnnotations.short -->

##### Collections — the six templates (L25, decision 139) › full text

*`collection.preset.fullTextWithAnnotations.tag` · 08-Reading-Research-Collections.md:982*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortTag | lines: 178–178 | key: collection.preset.fullTextWithAnnotations.tag | shared: iOS+macOS (single edit point) -->

*The word under the chip, template 2 of 6.*

full text

<!-- END SOURCE: collection.preset.fullTextWithAnnotations.tag -->

##### Collections — the six templates (L25, decision 139) › Summaries with overview

*`collection.preset.summariesWithOverview` · 08-Reading-Research-Collections.md:991*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.displayName | lines: 101–102 | key: collection.preset.summariesWithOverview | shared: iOS+macOS (single edit point) -->

*The card's name, template 3 of 6.*

Summaries with overview

<!-- END SOURCE: collection.preset.summariesWithOverview -->

##### Collections — the six templates (L25, decision 139) › AI summaries · notes · word cloud · chronology · themes

*`collection.preset.summariesWithOverview.subtitle` · 08-Reading-Research-Collections.md:1000*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.subtitle | lines: 125–126 | key: collection.preset.summariesWithOverview.subtitle | shared: iOS+macOS (single edit point) -->

*The line under the card's name, template 3 of 6.*

AI summaries · notes · word cloud · chronology · themes

<!-- END SOURCE: collection.preset.summariesWithOverview.subtitle -->

##### Collections — the six templates (L25, decision 139) › Summaries

*`collection.preset.summariesWithOverview.short` · 08-Reading-Research-Collections.md:1009*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortName | lines: 161–161 | key: collection.preset.summariesWithOverview.short | shared: iOS+macOS (single edit point) -->

*The chip's name on iPhone, template 3 of 6.*

Summaries

<!-- END SOURCE: collection.preset.summariesWithOverview.short -->

##### Collections — the six templates (L25, decision 139) › AI

*`collection.preset.summariesWithOverview.tag` · 08-Reading-Research-Collections.md:1018*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortTag | lines: 180–180 | key: collection.preset.summariesWithOverview.tag | shared: iOS+macOS (single edit point) -->

*The word under the chip, template 3 of 6.*

AI

<!-- END SOURCE: collection.preset.summariesWithOverview.tag -->

##### Collections — the six templates (L25, decision 139) › Citations with your notes

*`collection.preset.citationsWithNotes` · 08-Reading-Research-Collections.md:1027*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.displayName | lines: 104–105 | key: collection.preset.citationsWithNotes | shared: iOS+macOS (single edit point) -->

*The card's name, template 4 of 6.*

Citations with your notes

<!-- END SOURCE: collection.preset.citationsWithNotes -->

##### Collections — the six templates (L25, decision 139) › Citation list · notes · bibliography · themes

*`collection.preset.citationsWithNotes.subtitle` · 08-Reading-Research-Collections.md:1036*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.subtitle | lines: 128–129 | key: collection.preset.citationsWithNotes.subtitle | shared: iOS+macOS (single edit point) -->

*The line under the card's name, template 4 of 6.*

Citation list · notes · bibliography · themes

<!-- END SOURCE: collection.preset.citationsWithNotes.subtitle -->

##### Collections — the six templates (L25, decision 139) › Noted

*`collection.preset.citationsWithNotes.short` · 08-Reading-Research-Collections.md:1045*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortName | lines: 163–163 | key: collection.preset.citationsWithNotes.short | shared: iOS+macOS (single edit point) -->

*The chip's name on iPhone, template 4 of 6.*

Noted

<!-- END SOURCE: collection.preset.citationsWithNotes.short -->

##### Collections — the six templates (L25, decision 139) › citations

*`collection.preset.citationsWithNotes.tag` · 08-Reading-Research-Collections.md:1054*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortTag | lines: 182–182 | key: collection.preset.citationsWithNotes.tag | shared: iOS+macOS (single edit point) -->

*The word under the chip, template 4 of 6.*

citations

<!-- END SOURCE: collection.preset.citationsWithNotes.tag -->

##### Collections — the six templates (L25, decision 139) › Citations with archival sources

*`collection.preset.citationsWithArchivalSources` · 08-Reading-Research-Collections.md:1063*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.displayName | lines: 107–108 | key: collection.preset.citationsWithArchivalSources | shared: iOS+macOS (single edit point) -->

*The card's name, template 5 of 6.*

Citations with archival sources

<!-- END SOURCE: collection.preset.citationsWithArchivalSources -->

##### Collections — the six templates (L25, decision 139) › Citation list · source notes · archives · persons

*`collection.preset.citationsWithArchivalSources.subtitle` · 08-Reading-Research-Collections.md:1072*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.subtitle | lines: 131–132 | key: collection.preset.citationsWithArchivalSources.subtitle | shared: iOS+macOS (single edit point) -->

*The line under the card's name, template 5 of 6.*

Citation list · source notes · archives · persons

<!-- END SOURCE: collection.preset.citationsWithArchivalSources.subtitle -->

##### Collections — the six templates (L25, decision 139) › Archival

*`collection.preset.citationsWithArchivalSources.short` · 08-Reading-Research-Collections.md:1081*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortName | lines: 165–165 | key: collection.preset.citationsWithArchivalSources.short | shared: iOS+macOS (single edit point) -->

*The chip's name on iPhone, template 5 of 6.*

Archival

<!-- END SOURCE: collection.preset.citationsWithArchivalSources.short -->

##### Collections — the six templates (L25, decision 139) › citations

*`collection.preset.citationsWithArchivalSources.tag` · 08-Reading-Research-Collections.md:1090*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortTag | lines: 184–184 | key: collection.preset.citationsWithArchivalSources.tag | shared: iOS+macOS (single edit point) -->

*The word under the chip, template 5 of 6.*

citations

<!-- END SOURCE: collection.preset.citationsWithArchivalSources.tag -->

##### Collections — the six templates (L25, decision 139) › Everything included

*`collection.preset.everythingIncluded` · 08-Reading-Research-Collections.md:1099*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.displayName | lines: 110–111 | key: collection.preset.everythingIncluded | shared: iOS+macOS (single edit point) -->

*The card's name, template 6 of 6.*

Everything included

<!-- END SOURCE: collection.preset.everythingIncluded -->

##### Collections — the six templates (L25, decision 139) › Full text · all options · all five sections

*`collection.preset.everythingIncluded.subtitle` · 08-Reading-Research-Collections.md:1108*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.subtitle | lines: 134–135 | key: collection.preset.everythingIncluded.subtitle | shared: iOS+macOS (single edit point) -->

*The line under the card's name, template 6 of 6.*

Full text · all options · all five sections

<!-- END SOURCE: collection.preset.everythingIncluded.subtitle -->

##### Collections — the six templates (L25, decision 139) › Everything

*`collection.preset.everythingIncluded.short` · 08-Reading-Research-Collections.md:1117*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortName | lines: 167–167 | key: collection.preset.everythingIncluded.short | shared: iOS+macOS (single edit point) -->

*The chip's name on iPhone, template 6 of 6.*

Everything

<!-- END SOURCE: collection.preset.everythingIncluded.short -->

##### Collections — the six templates (L25, decision 139) › all on

*`collection.preset.everythingIncluded.tag` · 08-Reading-Research-Collections.md:1126*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionPreset.shortTag | lines: 186–186 | key: collection.preset.everythingIncluded.tag | shared: iOS+macOS (single edit point) -->

*The word under the chip, template 6 of 6.*

all on

<!-- END SOURCE: collection.preset.everythingIncluded.tag -->

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.5 Export method statements › ranked inside a set of %@, not across the whole series

*`appendix.scope.semantic.within %@` · 08-Reading-Research-Collections.md:1839*

<!-- SOURCE: FRUSCoreKit/Search/SearchScopeSignature.swift | SearchScopeSignature.rankedInsidePhrase | lines: 446–447 | key: appendix.scope.semantic.within %@ -->

ranked inside a set of %@, not across the whole series

<!-- END SOURCE: appendix.scope.semantic.within %@ -->

*`appendix.scope.semantic.within.empty` · 08-Reading-Research-Collections.md:1845*

<!-- SOURCE: FRUSCoreKit/Search/SearchScopeSignature.swift | SearchScopeSignature.describe | lines: 276–277 | key: appendix.scope.semantic.within.empty -->

ranked inside a set that held no documents

<!-- END SOURCE: appendix.scope.semantic.within.empty -->

##### 18.5 Export method statements › inside the closest matches of a Meaning search for…

*`appendix.scope.base.meaning %@ %@` · 08-Reading-Research-Collections.md:1853*

<!-- SOURCE: FRUSCoreKit/Search/SearchScopeSignature.swift | SearchScopeSignature.basePhrase | key: appendix.scope.base.meaning %@ %@ -->

*The method appendix's phrase for a search run inside a held Meaning list (#1577 lane 4), from the trail row's `base=` part: %2$@ is the list's question and %1$@ its size with its noun ("100 documents"). %2$@ is quoted as the row quoted it, so a question or words typed as one phrase in quotation marks fill it without their own marks; the trail still records them as typed (plan of record §6g, 2026-10-19). The same holds for the keyword list's phrase below.*

inside the closest matches of a Meaning search for “%2$@” (%1$@)

<!-- END SOURCE: appendix.scope.base.meaning %@ %@ -->

*`appendix.scope.base.keywords %@ %@` · 08-Reading-Research-Collections.md:1861*

<!-- SOURCE: FRUSCoreKit/Search/SearchScopeSignature.swift | SearchScopeSignature.basePhrase | key: appendix.scope.base.keywords %@ %@ -->

*The same for a ranking of a held keyword list.*

inside the results of a keyword search for “%2$@” (%1$@)

<!-- END SOURCE: appendix.scope.base.keywords %@ %@ -->

*`appendix.scope.base.browse %@ %@` · 08-Reading-Research-Collections.md:1869*

<!-- SOURCE: FRUSCoreKit/Search/SearchScopeSignature.swift | SearchScopeSignature.basePhrase | key: appendix.scope.base.browse %@ %@ -->

*The same for a ranking of a held browse, by its filter's name. A browse writes no trail row of its own, so this phrase is the only record of it.*

inside the results of a browse of %2$@ (%1$@)

<!-- END SOURCE: appendix.scope.base.browse %@ %@ -->

*`appendix.scope.base.browse.unnamed %@` · 08-Reading-Research-Collections.md:1877*

<!-- SOURCE: FRUSCoreKit/Search/SearchScopeSignature.swift | SearchScopeSignature.basePhrase | key: appendix.scope.base.browse.unnamed %@ -->

*The same for a browse with no name to give.*

inside the results of a browse (%@)

<!-- END SOURCE: appendix.scope.base.browse.unnamed %@ -->

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › Summaries created on your other devices still appear here…

*`summary.unavailable.explanation.otherDevices` · 08-Reading-Research-Collections.md:2006*

<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | SummaryBlockView.body | lines: 291–292 | key: summary.unavailable.explanation.otherDevices | shared: macOS only -->

Summaries created on your other devices still appear here via iCloud.

<!-- END SOURCE: summary.unavailable.explanation.otherDevices -->

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › Browse — You followed a link to page %lld of this volume, which isn’t downloaded.

*`browser.volume.followedPage %lld` · 08-Reading-Research-Collections.md:2393*

<!-- SOURCE: FRUSExplorer/TEI/FRUSURLSchemeHandler.swift | FollowedPageLink.notice | lines: 410–411 | key: browser.volume.followedPage %lld | shared: iOS and macOS (one text, under the not-downloaded heading of a volume's page in Browse on iPhone and iPad and in the Corpus Browser on the Mac) -->

You followed a link to page %lld of this volume, which isn’t downloaded.

<!-- END SOURCE: browser.volume.followedPage %lld -->

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › Summaries from your other devices still appear here…

*`panel.summary.unavailable.otherDevices` · 08-Reading-Research-Collections.md:2433*

<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | ResearchRailView.summaryAccordion | lines: 564–565 | key: panel.summary.unavailable.otherDevices | shared: iOS only -->

Summaries from your other devices still appear here via iCloud.

<!-- END SOURCE: panel.summary.unavailable.otherDevices -->

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › Apple Intelligence — why it cannot summarize

*`ai.availability.notEnabled.mac, ai.availability.notEnabled, ai.availability.modelNotReady` · 08-Reading-Research-Collections.md:2440*

<!-- SOURCE: FRUSExplorer/Summarization/AppleIntelligenceProvider.swift | AppleIntelligenceAvailability | lines: 387–397 | keys: ai.availability.notEnabled.mac, ai.availability.notEnabled, ai.availability.modelNotReady | shared: iOS+macOS (single edit point; the Mac's own sentence for switched off) -->

**Switched off, on the Mac:** Apple Intelligence is turned off on this Mac. Turn it on in System Settings ▸ Apple Intelligence & Siri to generate summaries here.

**Switched off, on iPhone and iPad:** Apple Intelligence is turned off on this device. Turn it on in Settings ▸ Apple Intelligence & Siri to generate summaries here.

**Its model not ready yet:** Apple Intelligence is not ready on this device yet: its model may still be downloading. Try again later.

<!-- END SOURCE: ai.availability -->

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › Shared words compared as printed: this device’s language…

*`related.sharedTerms.printedForms.note` · 08-Reading-Research-Collections.md:2467*

<!-- SOURCE: FRUSExplorer/RelatedDocuments/SemanticSharedTerms.swift | SemanticSharedTerms.Evidence.printedFormsNote | lines: 98–99 | key: related.sharedTerms.printedForms.note -->

*Added by #1608 (2026-10-12). A line above Related Documents' rows on a launch whose language analysis has no lemmatiser, whenever the rows' shared words were compared (one of the two experimental wording signals is raised). The* shares: *chips used to be left out on such a launch; they now compare the two documents' words as printed, and this says that they did, why, and that another device can name different words, as the owner's condition for the fallback asks. It is shown whether or not a row has a chip: with none, every row shows a percentage where a device that reduces words can name the words, and this line is what says why.*

Shared words compared as printed: this device’s language analysis isn’t reducing words to their dictionary forms right now, so two documents share a word only where both print the same form (“negotiate” in one and “negotiated” in the other is not a match). A device that does reduce them (a Mac, or another iPhone or iPad) can name different shared words.

<!-- END SOURCE: related.sharedTerms.printedForms.note -->

##### 18.11 Research, projects and history › A collection with no name — Project Home, its Manage sheet, and every other list row

*`collection.untitled.name` · 08-Reading-Research-Collections.md:2577*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionEditorNaming.swift | CollectionEditorNaming.navigationTitle | lines: 60–60 | key: collection.untitled.name | same text also in: FRUSExplorer/Collections/MacCollectionManagerView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Untitled Collection

<!-- END SOURCE: collection.untitled.name -->

##### 18.11 Research, projects and history › Discard Changes?

*`note.editor.discard.title` · 08-Reading-Research-Collections.md:2643*

<!-- SOURCE: FRUSExplorer/ResearchNoteEditor/ResearchNoteEditorView.swift | NoteEditorDialogCopy.discardTitle | lines: 494–494 | key: note.editor.discard.title -->

*The title of the dialog the note editor shows before it closes a note that holds something unsaved — its text, its formatting, its tags, its projects or its summaries (L19, #1919): from the editor's Discard, and on iPhone and iPad from a swipe down on the editor (a tap beside an iPad's editor leaves it open); on the Mac from Discard, Esc and closing the note's window. Its buttons are Keep Editing and Discard Changes, and one of the two messages below follows the title.*

Discard Changes?

<!-- END SOURCE: note.editor.discard.title -->

##### 18.11 Research, projects and history › This note has not been saved.

*`note.editor.discard.message.new` · 08-Reading-Research-Collections.md:2652*

<!-- SOURCE: FRUSExplorer/ResearchNoteEditor/ResearchNoteEditorView.swift | NoteEditorDialogCopy.discardMessage(isNewNote:) | lines: 509–510 | key: note.editor.discard.message.new -->

*The dialog's message for a note being written, which has never been saved.*

This note has not been saved.

<!-- END SOURCE: note.editor.discard.message.new -->

##### 18.11 Research, projects and history › Your changes to this note have not been saved.

*`note.editor.discard.message.edit` · 08-Reading-Research-Collections.md:2661*

<!-- SOURCE: FRUSExplorer/ResearchNoteEditor/ResearchNoteEditorView.swift | NoteEditorDialogCopy.discardMessage(isNewNote:) | lines: 511–512 | key: note.editor.discard.message.edit -->

*The dialog's message for a note saved before and changed since.*

Your changes to this note have not been saved.

<!-- END SOURCE: note.editor.discard.message.edit -->

##### 18.12 Collections, Zotero and the trip packet › Smart collection. Its documents come from its saved search.

*`collection.picker.smart` · 08-Reading-Research-Collections.md:2721*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | SmartCollectionRule.sentence | lines: 1070–1071 | key: collection.picker.smart -->

*The line under a smart collection's name in Add to Collection and Add Excerpt to Collection, on iPhone, iPad and Mac, where an ordinary collection's row prints its document count; the row is listed and does not take a tap (#1593). Since #1619 it is also the first row of a smart collection's Contents, in the iPhone and iPad editor and in the Mac's Collections window, whose Add menus then take no hand-added document, section heading, note block or passage.*

Smart collection. Its documents come from its saved search.

<!-- END SOURCE: collection.picker.smart -->

##### 18.12 Collections, Zotero and the trip packet › Smart collection

*`collection.smart.listLabel` · 08-Reading-Research-Collections.md:2730*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | SmartCollectionRule.listLabel | lines: 1078–1078 | key: collection.smart.listLabel -->

*What a smart collection's row prints where an ordinary collection's prints its document count (#1619): in the Collections list on iPhone and iPad, in the Mac Collections window's collection picker and its Manage Collections sheet, and since #1687 in Project Home's Collections sheet (**Manage**), on every platform. On the Mac's toolbar the picker shows a bolt in its place, which VoiceOver reads as these words.*

Smart collection

<!-- END SOURCE: collection.smart.listLabel -->

##### 18.12 Collections, Zotero and the trip packet › Not part of the smart collection: added before it was…

*`collection.smart.earlier.heading` · 08-Reading-Research-Collections.md:2739*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | SmartCollectionRule.entriesFromBeforeLinkHeading | lines: 1033–1034 | key: collection.smart.earlier.heading -->

*The dimmed heading over a smart collection's entries from before its link (#1619; decision 22 of the 2026-10-14 plan of record), in a section of its own under the collection's Contents: in the iPhone and iPad editor, which is also the Mac's New Collection sheet, and in the Mac's Collections window. A smart collection takes no hand-added document, section heading, note block or passage, so an entry of those kinds is one it held before it was linked, and every export, the preview and the Archives Visit list leave it out. The section shows only while there is such an entry; each is listed dimmed, by its title or its words.*

Not part of the smart collection: added before it was linked to its saved search.

<!-- END SOURCE: collection.smart.earlier.heading -->

##### 18.12 Collections, Zotero and the trip packet › Remove These Entries

*`collection.smart.earlier.remove` · 08-Reading-Research-Collections.md:2748*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | SmartCollectionRule.removeEntriesFromBeforeLink | lines: 1039–1039 | key: collection.smart.earlier.remove -->

*The button under those entries, on iPhone, iPad and Mac, and the destructive button of the dialog it opens. It removes nothing itself: the dialog asks first, and only its button removes them. Nothing else removes them; unlinked, the collection counts them again.*

Remove These Entries

<!-- END SOURCE: collection.smart.earlier.remove -->

##### 18.12 Collections, Zotero and the trip packet › Remove These Entries?

*`collection.smart.earlier.remove.confirm.title` · 08-Reading-Research-Collections.md:2757*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | SmartCollectionRule.removeEntriesFromBeforeLinkTitle | lines: 1044–1044 | key: collection.smart.earlier.remove.confirm.title -->

*The title of the dialog that asks before the entries from before the link are removed. Its message is the next block, or the one after it for more than one entry.*

Remove These Entries?

<!-- END SOURCE: collection.smart.earlier.remove.confirm.title -->

##### 18.12 Collections, Zotero and the trip packet › Removes the entry added before this collection was linked…

*`collection.smart.earlier.remove.confirm.message.one` · 08-Reading-Research-Collections.md:2766*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | SmartCollectionRule.removeEntriesFromBeforeLinkMessage(count:locale:) | lines: 1055–1056 | key: collection.smart.earlier.remove.confirm.message.one -->

*The dialog's message when one entry would go.*

Removes the entry added before this collection was linked to its saved search.

<!-- END SOURCE: collection.smart.earlier.remove.confirm.message.one -->

##### 18.12 Collections, Zotero and the trip packet › Removes the %@ entries added before this collection was…

*`collection.smart.earlier.remove.confirm.message.many` · 08-Reading-Research-Collections.md:2775*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | SmartCollectionRule.removeEntriesFromBeforeLinkMessage(count:locale:) | lines: 1057–1058 | key: collection.smart.earlier.remove.confirm.message.many -->

*The dialog's message when more than one entry would go. `%@` is the count, grouped: "Removes the 1,204 entries added before…".*

Removes the %@ entries added before this collection was linked to its saved search.

<!-- END SOURCE: collection.smart.earlier.remove.confirm.message.many -->

##### 18.12 Collections, Zotero and the trip packet › Empty note block

*`collection.smart.earlier.emptyNote` · 08-Reading-Research-Collections.md:2784*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | SmartCollectionRule.emptyNoteBlock | lines: 1064–1064 | key: collection.smart.earlier.emptyNote -->

*What a row in that section prints for a note block that holds no text. A section heading with none reads "Untitled section", as it does in the entry inspector.*

Empty note block

<!-- END SOURCE: collection.smart.earlier.emptyNote -->

##### 18.12 Collections, Zotero and the trip packet › Saved search not found

*`collection.editor.smart.missing` · 08-Reading-Research-Collections.md:2793*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | SmartCollectionLinkRows.body | lines: 2440–2440 | key: collection.editor.smart.missing -->

*Where a smart collection's Smart Collection section names its saved search, when no saved search has the linked one's id any more (#1619 review): in Collection settings on iPhone and iPad, and in the Mac Collections window's ⚙ Collection popover. Unlink sits beside it either way.*

Saved search not found

<!-- END SOURCE: collection.editor.smart.missing -->

##### 18.12 Collections, Zotero and the trip packet › The linked saved search could not be found. It may have…

*`collection.editor.smart.missing.explanation` · 08-Reading-Research-Collections.md:2802*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | SmartCollectionLinkRows.body | lines: 2451–2452 | key: collection.editor.smart.missing.explanation -->

*The line under it, in place of the line that says what the link does. A smart collection takes nothing by hand, so the line says how to take it back (#1619 review).*

The linked saved search could not be found. It may have been deleted. Unlink it to add to this collection by hand.

<!-- END SOURCE: collection.editor.smart.missing.explanation -->

##### 18.12 Collections, Zotero and the trip packet › Link to Saved Search…

*`collection.editor.smart.link` · 08-Reading-Research-Collections.md:2811*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | SmartCollectionLinkButton.body | lines: 2482–2483 | key: collection.editor.smart.link -->

*A Smart Collection section's button for a collection that is not linked: in Collection settings on iPhone and iPad, which on the Mac is also the New Collection sheet's, and since #1687 in the Mac Collections window's ⚙ Collection popover, which until then could unlink a collection and not link one. It opens the list of saved searches, newest first; in the Collections window it first closes the popover, and the list opens over the window. It is dimmed until a search is saved, over the next block's line (on the Mac, the one after it).*

Link to Saved Search…

<!-- END SOURCE: collection.editor.smart.link -->

##### 18.12 Collections, Zotero and the trip packet › Save a search from the Search tab to enable smart collections.

*`collection.editor.smart.noSearches` · 08-Reading-Research-Collections.md:2820*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | SmartCollectionLinkButton.body | lines: 2496–2497 | key: collection.editor.smart.noSearches -->

*Under the dimmed Link to Saved Search… on iPhone and iPad, while no search is saved.*

Save a search from the Search tab to enable smart collections.

<!-- END SOURCE: collection.editor.smart.noSearches -->

##### 18.12 Collections, Zotero and the trip packet › Save a search from the Search window to enable smart collections.

*`collection.editor.smart.noSearches.mac` · 08-Reading-Research-Collections.md:2829*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | SmartCollectionLinkButton.body | lines: 2491–2492 | key: collection.editor.smart.noSearches.mac -->

*The same line on the Mac (#1687): in the Collections window's ⚙ Collection popover, and in the New Collection sheet, where it had named the Search tab, which the Mac does not have.*

Save a search from the Search window to enable smart collections.

<!-- END SOURCE: collection.editor.smart.noSearches.mac -->

##### 18.12 Collections, Zotero and the trip packet › Couldn’t Add to Archives Visit

*`archiveVisit.collection.error.title` · 08-Reading-Research-Collections.md:2838*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEditorView.swift | CollectionEditorView.body | lines: 369–369 | key: archiveVisit.collection.error.title | same text also in: FRUSExplorer/Collections/MacCollectionManagerView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

*The title of the alert Add to Archives Visit… shows when a smart collection's search cannot run (#1619), on iPhone, iPad and Mac. Its message is the export's own: "Search is not ready yet. Try again in a moment." before the index has opened, or "The linked saved search could not be found. It may have been deleted."*

Couldn’t Add to Archives Visit

<!-- END SOURCE: archiveVisit.collection.error.title -->

##### 18.12 Collections, Zotero and the trip packet › Add %@ Documents to Collection

*`collection.picker.title.documents.many` · 08-Reading-Research-Collections.md:2848*

<!-- SOURCE: FRUSExplorer/Collections/CollectionPickerSheet.swift | CollectionPickerCopy.documentsTitle(count:locale:) | lines: 574–575 | key: collection.picker.title.documents.many -->

*The Add to Collection sheet's title when a command on search results carries more than one document (#1576), on iPhone, iPad and Mac: "Add 37 Documents to Collection". `%@` is the count. For one document the sheet keeps its plain title, "Add to Collection".*

Add %@ Documents to Collection

<!-- END SOURCE: collection.picker.title.documents.many -->

##### 18.12 Collections, Zotero and the trip packet › Not Added

*`collection.picker.addFailed.title` · 08-Reading-Research-Collections.md:2857*

<!-- SOURCE: FRUSExplorer/Collections/CollectionPickerSheet.swift | CollectionPickerCopy.addFailedTitle | lines: 606–606 | key: collection.picker.addFailed.title -->

*The title of the alert the Add to Collection sheet shows when documents from search results could not be added (#1576). One of the three messages below follows it, and the sheet stays open.*

Not Added

<!-- END SOURCE: collection.picker.addFailed.title -->

##### 18.12 Collections, Zotero and the trip packet › This is a smart collection. Its documents come from its saved search, so nothing…

*`collection.picker.addFailed.smart` · 08-Reading-Research-Collections.md:2866*

<!-- SOURCE: FRUSExplorer/Collections/CollectionPickerSheet.swift | CollectionPickerCopy.addFailure(_:locale:) | lines: 618–619 | key: collection.picker.addFailed.smart -->

*The alert's message when the collection is a smart one. A smart collection's row takes no tap, so the sheet does not reach this today; it is what the add itself answers with if anything else asks.*

This is a smart collection. Its documents come from its saved search, so nothing can be added to it by hand.

<!-- END SOURCE: collection.picker.addFailed.smart -->

##### 18.12 Collections, Zotero and the trip packet › A collection takes up to %2$@ at a time, and %1$@ were chosen.

*`collection.picker.addFailed.overLimit %@ %@` · 08-Reading-Research-Collections.md:2875*

<!-- SOURCE: FRUSExplorer/Collections/CollectionPickerSheet.swift | CollectionPickerCopy.addFailure(_:locale:) | lines: 622–623 | key: collection.picker.addFailed.overLimit %@ %@ -->

*The alert's message when more documents were chosen than one add takes: "A collection takes up to 1,000 documents at a time, and 1,200 documents were chosen." `%1$@` is the number chosen and `%2$@` the limit, each with its noun. Keep both tokens and their numbers.*

A collection takes up to %2$@ at a time, and %1$@ were chosen.

<!-- END SOURCE: collection.picker.addFailed.overLimit %@ %@ -->

##### 18.12 Collections, Zotero and the trip packet › The collection could not be saved, so nothing was added. %@

*`collection.picker.addFailed.save %@` · 08-Reading-Research-Collections.md:2884*

<!-- SOURCE: FRUSExplorer/Collections/CollectionPickerSheet.swift | CollectionPickerCopy.addFailure(_:locale:) | lines: 628–629 | key: collection.picker.addFailed.save %@ -->

*The alert's message when saving failed. The documents are taken back out of the collection, so the sentence is true as it stands. `%@` is the system's own description of the failure.*

The collection could not be saved, so nothing was added. %@

<!-- END SOURCE: collection.picker.addFailed.save %@ -->

##### 18.12 Collections, Zotero and the trip packet › Added to “\(…)”

*`collection.picker.announce.added` · 08-Reading-Research-Collections.md:2893*

<!-- SOURCE: FRUSExplorer/Collections/CollectionPickerSheet.swift | CollectionPickerCopy.announcement(_:collectionName:) | lines: 588–588 | key: collection.picker.announce.added -->

*What VoiceOver says when Add to Collection has put the document, or a passage of it, into the collection the reader chose (L19, #1919), as the collection's row shows its green check and the sheet closes. `\(collectionName)` is the collection's name as its row shows it. Search's results say what an add did themselves, with its Undo, so the picker says nothing there.*

Added to “\(collectionName)”

<!-- END SOURCE: collection.picker.announce.added -->

##### 18.12 Collections, Zotero and the trip packet › Already in “\(…)”

*`collection.picker.announce.alreadyIn` · 08-Reading-Research-Collections.md:2902*

<!-- SOURCE: FRUSExplorer/Collections/CollectionPickerSheet.swift | CollectionPickerCopy.announcement(_:collectionName:) | lines: 590–590 | key: collection.picker.announce.alreadyIn -->

*What VoiceOver says when the collection held the document already, so nothing was added. The row shows "Already here" beside a hollow check, where an add shows the green one.*

Already in “\(collectionName)”

<!-- END SOURCE: collection.picker.announce.alreadyIn -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Tags are added. A document keeps the tags it already has.

*`tags.picker.adding.footer` · 08-Reading-Research-Collections.md:2915*

<!-- SOURCE: FRUSExplorer/DocumentView/UserTagPickerSheet.swift | UserTagPickerCopy.addingFooter | lines: 544–545 | key: tags.picker.adding.footer -->

*The line under the list of tags in the adding mode. It is what tells a reader that switching a tag on here cannot take another tag off.*

Tags are added. A document keeps the tags it already has.

<!-- END SOURCE: tags.picker.adding.footer -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Up to %2$@ can be tagged at a time, and %1$@ were chosen.

*`tags.picker.addFailed.overLimit %@ %@` · 08-Reading-Research-Collections.md:2924*

<!-- SOURCE: FRUSExplorer/DocumentView/UserTagPickerSheet.swift | UserTagPickerCopy.addFailure(_:locale:) | lines: 609–610 | key: tags.picker.addFailed.overLimit %@ %@ -->

*The message of the "Not Tagged" alert when more documents were chosen than one Add Tags takes. `%1$@` is the number chosen and `%2$@` the limit, each with its noun. The command is dimmed over the limit, so a reader should not reach this.*

Up to %2$@ can be tagged at a time, and %1$@ were chosen.

<!-- END SOURCE: tags.picker.addFailed.overLimit %@ %@ -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › The tags could not be read or saved, so no document was tagged. %@

*`tags.picker.addFailed.save %@` · 08-Reading-Research-Collections.md:2933*

<!-- SOURCE: FRUSExplorer/DocumentView/UserTagPickerSheet.swift | UserTagPickerCopy.addFailure(_:locale:) | lines: 615–616 | key: tags.picker.addFailed.save %@ -->

*The alert's message when the tags could not be read or saved. Nothing is written then, so the sentence is true as it stands. `%@` is the system's own description of the failure.*

The tags could not be read or saved, so no document was tagged. %@

<!-- END SOURCE: tags.picker.addFailed.save %@ -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Send to Zotero Library — the Zotero collection made for a collection with no name

*`export.zotero.collection.untitled %@` · 08-Reading-Research-Collections.md:3028*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionExporter.swift | CollectionExportNaming.zoteroCollectionName | lines: 1605–1606 | key: export.zotero.collection.untitled %@ -->

FRUS Explorer Collection - %@

*(Interpolated with the day of the send, written yyyy-mm-dd in the reader's own time zone.)*

<!-- END SOURCE: export.zotero.collection.untitled %@ -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Collection preview and entry inspector — a Section heading with no text

*`collection.inspector.section.untitled` · 08-Reading-Research-Collections.md:3041*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSCoreKit/Collections/CollectionEditorNaming.swift | CollectionEditorNaming.untitledSection | lines: 98–98 | key: collection.inspector.section.untitled -->

Untitled section

<!-- END SOURCE: collection.inspector.section.untitled -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Rename Collection

*`collection.rename.title` · 08-Reading-Research-Collections.md:3079*

<!-- SOURCE: FRUSExplorer/Collections/CollectionListView.swift | CollectionRenameAlert.body | lines: 684–684 | key: collection.rename.title -->

*The title of the alert that asks for a collection's new name (#1823): from a row's menu in the Collections list on iPhone and iPad, and from Collection ▸ Rename Collection… on the Mac. Leaving the name empty keeps the old one.*

Rename Collection

<!-- END SOURCE: collection.rename.title -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Delete “\(…)”?

*`collection.delete.confirm.title.named` · 08-Reading-Research-Collections.md:3088*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | CollectionDeletion.title(for:locale:) | lines: 919–920 | key: collection.delete.confirm.title.named -->

*The title of the dialog that asks before one collection is deleted (#1823), naming it. It asks wherever a collection is deleted: a row's swipe, its menu or Edit's Delete in the Collections list on iPhone and iPad, and Manage Collections and Collection ▸ Delete Collection… on the Mac. Its message follows the title blocks below.*

Delete “\(name)”?

<!-- END SOURCE: collection.delete.confirm.title.named -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Delete %@ collection?

*`collection.delete.confirm.title.one` · 08-Reading-Research-Collections.md:3097*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | CollectionDeletion.title(for:locale:) | lines: 924–924 | key: collection.delete.confirm.title.one -->

*The count form of the title for one collection. The dialog names a single collection instead (the block above), so this form is the grammar's and is not drawn today.*

Delete %@ collection?

<!-- END SOURCE: collection.delete.confirm.title.one -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Delete %@ collections?

*`collection.delete.confirm.title.many` · 08-Reading-Research-Collections.md:3106*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | CollectionDeletion.title(for:locale:) | lines: 925–925 | key: collection.delete.confirm.title.many -->

*The title when Edit's Delete in the Collections list on iPhone and iPad deletes several collections at once; `%@` is the count, grouped for the reader's locale.*

Delete %@ collections?

<!-- END SOURCE: collection.delete.confirm.title.many -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Delete Collection?

*`collection.delete.confirm.title.none` · 08-Reading-Research-Collections.md:3115*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | CollectionDeletion.title(for:locale:) | lines: 915–915 | key: collection.delete.confirm.title.none -->

*What the title reads for the moment the dialog takes to close after its Delete, once there is nothing left for it to name.*

Delete Collection?

<!-- END SOURCE: collection.delete.confirm.title.none -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Its section headings, note blocks and headnotes go with it…

*`collection.delete.confirm.message.one` · 08-Reading-Research-Collections.md:3124*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | CollectionDeletion.message(count:) | lines: 934–935 | key: collection.delete.confirm.message.one -->

*The dialog's message when one collection would go. A collection's headings, note blocks and headnotes are the reader's own writing, and the delete reaches every device, which is why the dialog asks at all.*

Its section headings, note blocks and headnotes go with it, on your other devices too once they sync. The documents in it, and your notes and highlights on them, stay.

<!-- END SOURCE: collection.delete.confirm.message.one -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Their section headings, note blocks and headnotes go with them…

*`collection.delete.confirm.message.many` · 08-Reading-Research-Collections.md:3133*

<!-- SOURCE: FRUSExplorer/Models/Collection.swift | CollectionDeletion.message(count:) | lines: 936–937 | key: collection.delete.confirm.message.many -->

*The dialog's message when several collections would go.*

Their section headings, note blocks and headnotes go with them, on your other devices too once they sync. The documents in them, and your notes and highlights on them, stay.

<!-- END SOURCE: collection.delete.confirm.message.many -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Delete Note Block?

*`collection.entry.delete.confirm.title.prose` · 08-Reading-Research-Collections.md:3142*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryRows.swift | CollectionEntryDeletion.title(for:) | lines: 381–381 | key: collection.entry.delete.confirm.title.prose -->

*The title of the dialog that asks before a note block with text is deleted from a collection's outline (L19, #1919), in the form of the collection's own delete dialog above: by a swipe or Edit's delete on iPhone and iPad, and by its trash on the Mac. A row that holds nothing of the reader's — an empty note block, a heading with no section defaults, a document at its defaults, a passage, an apparatus block — goes at once. Its button is Delete Note Block, and the first message below follows the title.*

Delete Note Block?

<!-- END SOURCE: collection.entry.delete.confirm.title.prose -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Delete Heading?

*`collection.entry.delete.confirm.title.heading` · 08-Reading-Research-Collections.md:3151*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryRows.swift | CollectionEntryDeletion.title(for:) | lines: 383–383 | key: collection.entry.delete.confirm.title.heading -->

*The title when the row is a heading that sets defaults for its section's documents, deleted alone: by a swipe or Edit's delete, Delete Heading Only, or the Mac's trash. Its button is Delete Heading.*

Delete Heading?

<!-- END SOURCE: collection.entry.delete.confirm.title.heading -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Remove Document?

*`collection.entry.delete.confirm.title.document` · 08-Reading-Research-Collections.md:3160*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryRows.swift | CollectionEntryDeletion.title(for:) | lines: 385–385 | key: collection.entry.delete.confirm.title.document -->

*The title when the row is a document with a headnote, or with settings of its own in the collection: a title, a body depth, an override, a headnote setting, or a choice of its notes or highlights. Its button is Remove Document.*

Remove Document?

<!-- END SOURCE: collection.entry.delete.confirm.title.document -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Its text goes with it, on your other devices too…

*`collection.entry.delete.confirm.message.prose` · 08-Reading-Research-Collections.md:3169*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryRows.swift | CollectionEntryDeletion.message(for:) | lines: 405–406 | key: collection.entry.delete.confirm.message.prose -->

*The message under Delete Note Block?. Nothing undoes a collection row's deletion, and it reaches the reader's other devices, which is why the dialog asks.*

Its text goes with it, on your other devices too once they sync.

<!-- END SOURCE: collection.entry.delete.confirm.message.prose -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Its section defaults go with it, on your other devices…

*`collection.entry.delete.confirm.message.heading` · 08-Reading-Research-Collections.md:3178*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryRows.swift | CollectionEntryDeletion.message(for:) | lines: 408–409 | key: collection.entry.delete.confirm.message.heading -->

*The message under Delete Heading?.*

Its section defaults go with it, on your other devices too once they sync. The entries under it stay.

<!-- END SOURCE: collection.entry.delete.confirm.message.heading -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Its headnote and its settings in this collection go with it…

*`collection.entry.delete.confirm.message.headnote` · 08-Reading-Research-Collections.md:3187*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryRows.swift | CollectionEntryDeletion.message(for:) | lines: 411–412 | key: collection.entry.delete.confirm.message.headnote -->

*The message under Remove Document? when the document has a headnote, which goes with its row.*

Its headnote and its settings in this collection go with it, on your other devices too once they sync. The document, and your notes and highlights on it, stay.

<!-- END SOURCE: collection.entry.delete.confirm.message.headnote -->

##### Adding tags to search results: the tag picker's adding mode (iOS and macOS) › Its settings in this collection go with it, on your other…

*`collection.entry.delete.confirm.message.settings` · 08-Reading-Research-Collections.md:3196*

<!-- SOURCE: FRUSExplorer/Collections/CollectionEntryRows.swift | CollectionEntryDeletion.message(for:) | lines: 414–415 | key: collection.entry.delete.confirm.message.settings -->

*The message under Remove Document? when the document has settings of its own and no headnote.*

Its settings in this collection go with it, on your other devices too once they sync. The document, and your notes and highlights on it, stay.

<!-- END SOURCE: collection.entry.delete.confirm.message.settings -->

### 09 Settings & app-wide messages — new

#### 6. Settings, Tips & Collections

##### Volumes & Storage (Library) › Keeping Current — an update's progress, and why a check could not run (#1660)

*Since build 51 (#1660, the owner's answers of 2026-10-16) a listed volume's row stays after Update or Update All and shows where its update stands; a failed update offers Retry with its reason; a side-loaded copy's row says Update replaces it; and when the published list cannot be read, a row under the two buttons says why. One shared view on every platform, so each block below is a single edit point.*

*`settings.hub.corrections.status.queued, settings.hub.corrections.status.downloading, settings.hub.corrections.status.alreadyDownloading, settings.hub.corrections.status.indexing, settings.hub.corrections.status.updated, settings.hub.corrections.retry` · 09-Settings-and-App.md:199*

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentModel.swift | KeepingCurrentCopy | lines: 359–375 | keys: settings.hub.corrections.status.queued, settings.hub.corrections.status.downloading, settings.hub.corrections.status.alreadyDownloading, settings.hub.corrections.status.indexing, settings.hub.corrections.status.updated, settings.hub.corrections.retry | shared: iOS+macOS (single edit point) -->

**Waiting in the queue:** Queued

**Downloading:** Downloading…

**A download of the volume was already under way:** Already downloading…

**Re-indexing:** Indexing…

**Done:** Updated

**A failed row's button:** Retry

<!-- END SOURCE: settings.hub.corrections.status -->

*`settings.hub.corrections.sideloaded` · 09-Settings-and-App.md:215*

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentModel.swift | KeepingCurrentCopy.sideloaded | lines: 378–379 | key: settings.hub.corrections.sideloaded | shared: iOS+macOS (single edit point) -->

Your side-loaded copy. Update replaces it with the published volume.

<!-- END SOURCE: settings.hub.corrections.sideloaded -->

*`settings.hub.corrections.failed.offline, settings.hub.corrections.failed.timedOut, settings.hub.corrections.failed.server, settings.hub.corrections.failed.other, settings.hub.corrections.failed.indexing, settings.hub.corrections.failed.noURL` · 09-Settings-and-App.md:221*

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentModel.swift | KeepingCurrentCopy.failure(_:) | lines: 387–404 | keys: settings.hub.corrections.failed.offline, settings.hub.corrections.failed.timedOut, settings.hub.corrections.failed.server, settings.hub.corrections.failed.other, settings.hub.corrections.failed.indexing, settings.hub.corrections.failed.noURL | shared: iOS+macOS (single edit point) -->

**No connection:** The download failed: no connection.

**Timed out:** The download failed: it timed out.

**GitHub sent no volume:** The download failed: GitHub did not send the volume.

**Any other cause:** The download failed: \(download.description)

**The re-index failed:** The volume downloaded, and indexing it failed: \(description)

**No catalogue address (not expected, since every listed volume has one):** This volume has no published copy to download.

*(Interpolated with the system's description of the error.)*

<!-- END SOURCE: settings.hub.corrections.failed -->

*L20 (#1920, HCD-3): a volume's own page shows the download lines above, with **Retry** (`settings.hub.corrections.retry`) in Download Volume's place, when its download fails with its retries spent, on iPhone and iPad and in the Mac's Corpus Browser, and VoiceOver hears the line as it arrives. Until L20 such a download vanished, and the Mac's page stayed on Downloading….*

*`settings.hub.corrections.listProblem, settings.hub.corrections.listProblem.offline, settings.hub.corrections.listProblem.rateLimited, settings.hub.corrections.listProblem.rateLimited.noTime, settings.hub.corrections.listProblem.server, settings.hub.corrections.listProblem.unreadable` · 09-Settings-and-App.md:241*

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentModel.swift | KeepingCurrentCopy.listProblem(_:) | lines: 409–435 | keys: settings.hub.corrections.listProblem, settings.hub.corrections.listProblem.offline, settings.hub.corrections.listProblem.rateLimited, settings.hub.corrections.listProblem.rateLimited.noTime, settings.hub.corrections.listProblem.server, settings.hub.corrections.listProblem.unreadable | shared: iOS+macOS (single edit point) -->

**The row's label:** Couldn’t read the published list

**Offline:** This device is offline. Checking compares your volumes with the list on GitHub.

**GitHub's request limit, when it says when it lifts:** GitHub limits how often it answers one network, and this network has reached the limit. Try again after \(time).

**GitHub's request limit, when it does not:** GitHub limits how often it answers one network, and this network has reached the limit. Try again later.

**GitHub answered with an error:** GitHub answered with error \(status). Try again later.

**No reason was recorded:** The list on GitHub could not be read.

*(Any other failure shows the system's own description of it.)*

<!-- END SOURCE: settings.hub.corrections.listProblem -->

*`settings.hub.corrections.update.a11y, settings.hub.corrections.retry.a11y` · 09-Settings-and-App.md:259*

<!-- SOURCE: FRUSExplorer/Settings/KeepingCurrentSection.swift | KeepingCurrentRow.control | lines: 266–271 | keys: settings.hub.corrections.update.a11y, settings.hub.corrections.retry.a11y | shared: iOS+macOS (single edit point) -->

**VoiceOver, a row's Update:** Update \(volumeId)

**VoiceOver, a row's Retry:** Retry the update of \(volumeId)

<!-- END SOURCE: settings.hub.corrections.rowButtons -->

##### Volumes & Storage (Library) › Cancel All — the button, the question it asks first, and the Mac's queue line

*`settings.hub.active.cancelAll, settings.hub.active.queueLine, settings.hub.active.cancelAll.title, settings.hub.active.cancelAll.message, settings.hub.active.cancelAll.confirm, settings.hub.active.cancelAll.keep` · 09-Settings-and-App.md:279*

<!-- SOURCE: FRUSExplorer/Settings/StorageHubModel.swift | HubCopy (Cancel All) | lines: 49–73 | keys: settings.hub.active.cancelAll, settings.hub.active.queueLine, settings.hub.active.cancelAll.title, settings.hub.active.cancelAll.message, settings.hub.active.cancelAll.confirm, settings.hub.active.cancelAll.keep | shared: iOS+macOS (single edit point) -->

**The button:** Cancel All

**The Mac hub's queue line, while anything is queued:** \(volumes(count)) in the download queue

**The question it asks first:** Stop downloading \(volumes(count))?

**Its message:** Volumes already on this device stay. To download the others later, use “Download from GitHub…”.

**Its buttons:** Cancel All Downloads · Keep Downloading

<!-- END SOURCE: settings.hub.active.cancelAll -->

##### Volumes & Storage (Library) › Hero summary line, and the Measuring… placeholder (#1476)

*`settings.hub.summary.removing.one` · 09-Settings-and-App.md:359*

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | LibraryStatusSummary.text | lines: 143–144 | key: settings.hub.summary.removing.one | shared: iOS+macOS (single edit point) -->

1 being removed

<!-- END SOURCE: settings.hub.summary.removing.one -->

*`settings.hub.summary.removing %lld` · 09-Settings-and-App.md:365*

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | LibraryStatusSummary.text | lines: 146–147 | key: settings.hub.summary.removing %lld | shared: iOS+macOS (single edit point) -->

%lld being removed

<!-- END SOURCE: settings.hub.summary.removing %lld -->

*`settings.hub.hero.unmeasured` · 09-Settings-and-App.md:377*

<!-- SOURCE: FRUSExplorer/Settings/StorageHubModel.swift | StorageHeroContent.unmeasuredValue | lines: 273–273 | key: settings.hub.hero.unmeasured | shared: iOS+macOS (single edit point) — the hero's size before a measurement, or after one fails with no earlier one -->

—

<!-- END SOURCE: settings.hub.hero.unmeasured -->

*`settings.hub.measureFailed` · 09-Settings-and-App.md:383*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/Settings/StorageHubModel.swift | DownloadedVolumesListModel.heroContent | lines: 478–479 | key: settings.hub.measureFailed | the hero's sentence after a measurement fails with no earlier one, and what VoiceOver reads for its dash then | same text also in: FRUSExplorer/Settings/VolumesStorageHubView.swift, FRUSExplorer/Settings/MacVolumesStorageHub.swift (the failure row's label) -->

Could not measure storage

<!-- END SOURCE: settings.hub.measureFailed -->

##### Volumes & Storage (Library) › Side-loaded — Not in the bundled catalogue

*`settings.hub.sideload.notCatalogued.detail` · 09-Settings-and-App.md:438*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SideloadCatalogueNotice.detail | lines: 401–402 | key: settings.hub.sideload.notCatalogued.detail | shared: iOS+macOS (single edit point) -->

Volumes added from your own files cannot be used with some features that rely on the app’s bundled publication data. Citation Lookup and Add Documents do not resolve a citation or history.state.gov link to them; open them from Browse or find them with Search.

<!-- END SOURCE: settings.hub.sideload.notCatalogued.detail -->

##### Data & Recovery (System) › Recovery ladder footer — while an upload is unrecovered (#1531)

*Added by lane SYNC (#1531). Shown in place of the footer above while an upload from this device has failed and none has succeeded since: then Fix iCloud Sync, the first rung, would discard the changes that never reached iCloud, so “the one that deletes nothing” would be untrue. Reset This Device does not touch them.*

*`settings.dataRecovery.recovery.footer.unrecovered` · 09-Settings-and-App.md:488*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | DataRecoveryView.recoveryFooter | lines: 339–340 | key: settings.dataRecovery.recovery.footer.unrecovered | shared: iOS+macOS (single edit point) -->

In order of how much they take away. While this device holds changes that have not reached iCloud, Fix iCloud Sync would discard them too.

<!-- END SOURCE: settings.dataRecovery.recovery.footer.unrecovered -->

##### Data & Recovery (System) › Fix iCloud Sync — the warning while an upload is unrecovered (#1531)

*Added by lane SYNC (#1531). While an upload from this device has failed and none has succeeded since, the confirmation opens with this paragraph and then shows the message above, unchanged. %@ is the date and time of the first failed upload, as the device writes dates. It shows whether the failure began in this session or an earlier one.*

*`settings.dataRecovery.fixSync.warning %@` · 09-Settings-and-App.md:506*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | DataRecoveryView.fixSyncMessage | lines: 315–316 | key: settings.dataRecovery.fixSync.warning %@ | shared: iOS+macOS (single edit point) -->

Warning: no upload from this device has succeeded since %@, so it holds changes that are not in iCloud yet. Fix iCloud Sync would discard them.

<!-- END SOURCE: settings.dataRecovery.fixSync.warning %@ -->

##### Data & Recovery (System) › Fix iCloud Sync — the row’s line while an upload is unrecovered (#1531)

*Added by lane SYNC (#1531). Replaces “Re-download from iCloud at next launch” under the Fix iCloud Sync row in the same state, so the cost shows before the row is tapped.*

*`settings.dataRecovery.fixSync.detail.unrecovered` · 09-Settings-and-App.md:516*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | DataRecoveryView.fixSyncRowDetail | lines: 328–329 | key: settings.dataRecovery.fixSync.detail.unrecovered | shared: iOS+macOS (single edit point) -->

Would discard changes not yet in iCloud

<!-- END SOURCE: settings.dataRecovery.fixSync.detail.unrecovered -->

##### Data & Recovery (System) › Import from JSON — Import from JSON…

*`settings.import.json.action` · 09-Settings-and-App.md:555*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.rowAction | lines: 417–417 | key: settings.import.json.action | shared: iOS+macOS (single edit point) -->

Import from JSON…

<!-- END SOURCE: settings.import.json.action -->

##### Data & Recovery (System) › Import from JSON — Brings back a file from Export as JSON, written by this app…

*`settings.import.json.footer` · 09-Settings-and-App.md:562*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.rowFooter | lines: 422–423 | key: settings.import.json.footer | shared: iOS+macOS (single edit point) -->

Brings back a file from Export as JSON, written by this app on any device or by FRUS Explorer Light. Before anything is written, you see what importing it will add and replace.

<!-- END SOURCE: settings.import.json.footer -->

##### Data & Recovery (System) › Import from JSON — Import from JSON

*`settings.import.title` · 09-Settings-and-App.md:569*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.title | lines: 430–430 | key: settings.import.title | shared: iOS+macOS (single edit point) -->

Import from JSON

<!-- END SOURCE: settings.import.title -->

##### Data & Recovery (System) › Import from JSON — Reading the file…

*`settings.import.reading` · 09-Settings-and-App.md:576*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.reading | lines: 435–435 | key: settings.import.reading | shared: iOS+macOS (single edit point) -->

Reading the file…

<!-- END SOURCE: settings.import.reading -->

##### Data & Recovery (System) › Import from JSON — Import

*`settings.import.action.import` · 09-Settings-and-App.md:583*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.importAction | lines: 439–439 | key: settings.import.action.import | shared: iOS+macOS (single edit point) -->

Import

<!-- END SOURCE: settings.import.action.import -->

##### Data & Recovery (System) › Import from JSON — Cancel

*`settings.import.action.cancel` · 09-Settings-and-App.md:590*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.cancel | lines: 443–443 | key: settings.import.action.cancel | shared: iOS+macOS (single edit point) -->

Cancel

<!-- END SOURCE: settings.import.action.cancel -->

##### Data & Recovery (System) › Import from JSON — Done

*`settings.import.action.done` · 09-Settings-and-App.md:597*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.done | lines: 447–447 | key: settings.import.action.done | shared: iOS+macOS (single edit point) -->

Done

<!-- END SOURCE: settings.import.action.done -->

##### Data & Recovery (System) › Import from JSON — File

*`settings.import.file.header` · 09-Settings-and-App.md:604*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fileHeader | lines: 453–453 | key: settings.import.file.header | shared: iOS+macOS (single edit point) -->

File

<!-- END SOURCE: settings.import.file.header -->

##### Data & Recovery (System) › Import from JSON — Name

*`settings.import.file.name` · 09-Settings-and-App.md:611*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fileNameLabel | lines: 457–457 | key: settings.import.file.name | shared: iOS+macOS (single edit point) -->

Name

<!-- END SOURCE: settings.import.file.name -->

##### Data & Recovery (System) › Import from JSON — Exported

*`settings.import.file.exported` · 09-Settings-and-App.md:618*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.exportedLabel | lines: 461–461 | key: settings.import.file.exported | shared: iOS+macOS (single edit point) -->

Exported

<!-- END SOURCE: settings.import.file.exported -->

##### Data & Recovery (System) › Import from JSON — Format version

*`settings.import.file.version` · 09-Settings-and-App.md:625*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.versionLabel | lines: 465–465 | key: settings.import.file.version | shared: iOS+macOS (single edit point) -->

Format version

<!-- END SOURCE: settings.import.file.version -->

##### Data & Recovery (System) › Import from JSON — Exported under the project

*`settings.import.file.project` · 09-Settings-and-App.md:632*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.projectLabel | lines: 469–469 | key: settings.import.file.project | shared: iOS+macOS (single edit point) -->

Exported under the project

<!-- END SOURCE: settings.import.file.project -->

##### Data & Recovery (System) › Import from JSON — This file is from an earlier version of the export, which…

*`settings.import.fieldsNotCarried` · 09-Settings-and-App.md:639*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.olderFileFooter | lines: 479–480 | key: settings.import.fieldsNotCarried | shared: iOS+macOS (single edit point) -->

This file is from an earlier version of the export, which cannot carry \(list). A record the import replaces keeps them as they are here, and a new record takes the app’s defaults.

<!-- END SOURCE: settings.import.fieldsNotCarried -->

##### Data & Recovery (System) › Import from JSON — An export of this version cannot hold \(…), so the file…

*`settings.import.typesNotCarried` · 09-Settings-and-App.md:646*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.olderFileFooter | lines: 485–486 | key: settings.import.typesNotCarried | shared: iOS+macOS (single edit point) -->

An export of this version cannot hold \(list), so the file brings none.

<!-- END SOURCE: settings.import.typesNotCarried -->

##### Data & Recovery (System) › Import from JSON — a note’s formatting

*`settings.import.field.noteFormatting` · 09-Settings-and-App.md:653*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 495–496 | key: settings.import.field.noteFormatting | shared: iOS+macOS (single edit point) -->

a note’s formatting

<!-- END SOURCE: settings.import.field.noteFormatting -->

##### Data & Recovery (System) › Import from JSON — a collection’s front matter and export settings

*`settings.import.field.collectionSettings` · 09-Settings-and-App.md:660*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 498–499 | key: settings.import.field.collectionSettings | shared: iOS+macOS (single edit point) -->

a collection’s front matter and export settings

<!-- END SOURCE: settings.import.field.collectionSettings -->

##### Data & Recovery (System) › Import from JSON — a collection entry’s kind, text and own settings

*`settings.import.field.collectionEntryContent` · 09-Settings-and-App.md:667*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 501–502 | key: settings.import.field.collectionEntryContent | shared: iOS+macOS (single edit point) -->

a collection entry’s kind, text and own settings

<!-- END SOURCE: settings.import.field.collectionEntryContent -->

##### Data & Recovery (System) › Import from JSON — a project’s focus tags and Suggested Next weights

*`settings.import.field.projectFocus` · 09-Settings-and-App.md:674*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 504–505 | key: settings.import.field.projectFocus | shared: iOS+macOS (single edit point) -->

a project’s focus tags and Suggested Next weights

<!-- END SOURCE: settings.import.field.projectFocus -->

##### Data & Recovery (System) › Import from JSON — a recorded search’s scope and counts

*`settings.import.field.searchCaptureProvenance` · 09-Settings-and-App.md:681*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 507–508 | key: settings.import.field.searchCaptureProvenance | shared: iOS+macOS (single edit point) -->

a recorded search’s scope and counts

<!-- END SOURCE: settings.import.field.searchCaptureProvenance -->

##### Data & Recovery (System) › Import from JSON — who wrote a summary

*`settings.import.field.summaryAuthorship` · 09-Settings-and-App.md:688*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.fieldsName | lines: 510–511 | key: settings.import.field.summaryAuthorship | shared: iOS+macOS (single edit point) -->

who wrote a summary

<!-- END SOURCE: settings.import.field.summaryAuthorship -->

##### Data & Recovery (System) › Import from JSON — Made by FRUS Explorer Light

*`settings.import.web.header` · 09-Settings-and-App.md:695*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webHeader | lines: 518–518 | key: settings.import.web.header | shared: iOS+macOS (single edit point) -->

Made by FRUS Explorer Light

<!-- END SOURCE: settings.import.web.header -->

##### Data & Recovery (System) › Import from JSON — Summaries

*`settings.import.web.summaries` · 09-Settings-and-App.md:702*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webSummariesLabel | lines: 522–522 | key: settings.import.web.summaries | shared: iOS+macOS (single edit point) -->

Summaries

<!-- END SOURCE: settings.import.web.summaries -->

##### Data & Recovery (System) › Import from JSON — Corrections

*`settings.import.web.corrections` · 09-Settings-and-App.md:709*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webCorrectionsLabel | lines: 526–526 | key: settings.import.web.corrections | shared: iOS+macOS (single edit point) -->

Corrections

<!-- END SOURCE: settings.import.web.corrections -->

##### Data & Recovery (System) › Import from JSON — Included

*`settings.import.web.included` · 09-Settings-and-App.md:716*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webValue | lines: 533–533 | key: settings.import.web.included | shared: iOS+macOS (single edit point) -->

Included

<!-- END SOURCE: settings.import.web.included -->

##### Data & Recovery (System) › Import from JSON — Left out

*`settings.import.web.leftOut` · 09-Settings-and-App.md:723*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webValue | lines: 535–535 | key: settings.import.web.leftOut | shared: iOS+macOS (single edit point) -->

Left out

<!-- END SOURCE: settings.import.web.leftOut -->

##### Data & Recovery (System) › Import from JSON — Not said

*`settings.import.web.unsaid` · 09-Settings-and-App.md:730*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webValue | lines: 537–537 | key: settings.import.web.unsaid | shared: iOS+macOS (single edit point) -->

Not said

<!-- END SOURCE: settings.import.web.unsaid -->

##### Data & Recovery (System) › Import from JSON — FRUS Explorer Light says what its export leaves out by…

*`settings.import.web.footer` · 09-Settings-and-App.md:737*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.webFooter | lines: 542–543 | key: settings.import.web.footer | shared: iOS+macOS (single edit point) -->

FRUS Explorer Light says what its export leaves out by choice. Its corrections come only in a curator’s export.

<!-- END SOURCE: settings.import.web.footer -->

##### Data & Recovery (System) › Import from JSON — What the Import Does

*`settings.import.records.header` · 09-Settings-and-App.md:744*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.recordsHeader | lines: 549–549 | key: settings.import.records.header | shared: iOS+macOS (single edit point) -->

What the Import Does

<!-- END SOURCE: settings.import.records.header -->

##### Data & Recovery (System) › Import from JSON — In all

*`settings.import.total` · 09-Settings-and-App.md:751*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.totalLabel | lines: 553–553 | key: settings.import.total | shared: iOS+macOS (single edit point) -->

In all

<!-- END SOURCE: settings.import.total -->

##### Data & Recovery (System) › Import from JSON — This library already holds every record in the file, as new…

*`settings.import.nothingToDo` · 09-Settings-and-App.md:758*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.nothingToDo | lines: 557–558 | key: settings.import.nothingToDo | shared: iOS+macOS (single edit point) -->

This library already holds every record in the file, as new or newer, so importing it would change nothing.

<!-- END SOURCE: settings.import.nothingToDo -->

##### Data & Recovery (System) › Import from JSON — A record already here is replaced only by a newer copy, and…

*`settings.import.records.footer` · 09-Settings-and-App.md:765*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.recordsFooter | lines: 564–565 | key: settings.import.records.footer | shared: iOS+macOS (single edit point) -->

A record already here is replaced only by a newer copy, and only in what this file’s version can carry. Nothing here is deleted, so a record you have deleted since this file was made comes back.

<!-- END SOURCE: settings.import.records.footer -->

##### Data & Recovery (System) › Import from JSON — This device takes the file’s synced settings as they are…

*`settings.import.settings.applied` · 09-Settings-and-App.md:772*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.settingsApplied | lines: 572–573 | key: settings.import.settings.applied | shared: iOS+macOS (single edit point) -->

This device takes the file’s synced settings as they are imported, since Sync Settings Across Devices is on.

<!-- END SOURCE: settings.import.settings.applied -->

##### Data & Recovery (System) › Import from JSON — The file’s synced settings are kept with your library. This…

*`settings.import.settings.kept` · 09-Settings-and-App.md:779*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.settingsKept | lines: 578–579 | key: settings.import.settings.kept | shared: iOS+macOS (single edit point) -->

The file’s synced settings are kept with your library. This device takes them when Sync Settings Across Devices is turned on.

<!-- END SOURCE: settings.import.settings.kept -->

##### Data & Recovery (System) › Import from JSON — \(…) set aside

*`settings.import.count.setAside` · 09-Settings-and-App.md:786*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.counts | lines: 589–590 | key: settings.import.count.setAside | shared: iOS+macOS (single edit point) -->

\(count.setAside) set aside

<!-- END SOURCE: settings.import.count.setAside -->

##### Data & Recovery (System) › Import from JSON — \(…) repeated

*`settings.import.count.repeated` · 09-Settings-and-App.md:793*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.counts | lines: 593–594 | key: settings.import.count.repeated | shared: iOS+macOS (single edit point) -->

\(count.repeated) repeated

<!-- END SOURCE: settings.import.count.repeated -->

##### Data & Recovery (System) › Import from JSON — \(…) to add

*`settings.import.count.add` · 09-Settings-and-App.md:800*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.added | lines: 605–605 | key: settings.import.count.add | shared: iOS+macOS (single edit point) -->

\(count) to add

<!-- END SOURCE: settings.import.count.add -->

##### Data & Recovery (System) › Import from JSON — \(…) to replace

*`settings.import.count.replace` · 09-Settings-and-App.md:807*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.replaced | lines: 609–609 | key: settings.import.count.replace | shared: iOS+macOS (single edit point) -->

\(count) to replace

<!-- END SOURCE: settings.import.count.replace -->

##### Data & Recovery (System) › Import from JSON — \(…) already here

*`settings.import.count.keep` · 09-Settings-and-App.md:814*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.kept | lines: 613–613 | key: settings.import.count.keep | shared: iOS+macOS (single edit point) -->

\(count) already here

<!-- END SOURCE: settings.import.count.keep -->

##### Data & Recovery (System) › Import from JSON — Research Notes

*`settings.import.type.researchNote` · 09-Settings-and-App.md:821*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 621–621 | key: settings.import.type.researchNote | shared: iOS+macOS (single edit point) -->

Research Notes

<!-- END SOURCE: settings.import.type.researchNote -->

##### Data & Recovery (System) › Import from JSON — Tags

*`settings.import.type.userTag` · 09-Settings-and-App.md:828*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 623–623 | key: settings.import.type.userTag | shared: iOS+macOS (single edit point) -->

Tags

<!-- END SOURCE: settings.import.type.userTag -->

##### Data & Recovery (System) › Import from JSON — Tag Assignments

*`settings.import.type.documentTagAssignment` · 09-Settings-and-App.md:835*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 625–625 | key: settings.import.type.documentTagAssignment | shared: iOS+macOS (single edit point) -->

Tag Assignments

<!-- END SOURCE: settings.import.type.documentTagAssignment -->

##### Data & Recovery (System) › Import from JSON — Highlights

*`settings.import.type.documentHighlight` · 09-Settings-and-App.md:842*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 627–627 | key: settings.import.type.documentHighlight | shared: iOS+macOS (single edit point) -->

Highlights

<!-- END SOURCE: settings.import.type.documentHighlight -->

##### Data & Recovery (System) › Import from JSON — Collections

*`settings.import.type.collection` · 09-Settings-and-App.md:849*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 629–629 | key: settings.import.type.collection | shared: iOS+macOS (single edit point) -->

Collections

<!-- END SOURCE: settings.import.type.collection -->

##### Data & Recovery (System) › Import from JSON — Collection Entries

*`settings.import.type.collectionEntry` · 09-Settings-and-App.md:856*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 631–631 | key: settings.import.type.collectionEntry | shared: iOS+macOS (single edit point) -->

Collection Entries

<!-- END SOURCE: settings.import.type.collectionEntry -->

##### Data & Recovery (System) › Import from JSON — Custom Prompts

*`settings.import.type.summarizationPrompt` · 09-Settings-and-App.md:863*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 633–633 | key: settings.import.type.summarizationPrompt | shared: iOS+macOS (single edit point) -->

Custom Prompts

<!-- END SOURCE: settings.import.type.summarizationPrompt -->

##### Data & Recovery (System) › Import from JSON — Projects

*`settings.import.type.project` · 09-Settings-and-App.md:870*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 635–635 | key: settings.import.type.project | shared: iOS+macOS (single edit point) -->

Projects

<!-- END SOURCE: settings.import.type.project -->

##### Data & Recovery (System) › Import from JSON — Summaries

*`settings.import.type.generatedSummary` · 09-Settings-and-App.md:877*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 637–637 | key: settings.import.type.generatedSummary | shared: iOS+macOS (single edit point) -->

Summaries

<!-- END SOURCE: settings.import.type.generatedSummary -->

##### Data & Recovery (System) › Import from JSON — Documents Visited

*`settings.import.type.readingHistoryEntry` · 09-Settings-and-App.md:884*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 639–639 | key: settings.import.type.readingHistoryEntry | shared: iOS+macOS (single edit point) -->

Documents Visited

<!-- END SOURCE: settings.import.type.readingHistoryEntry -->

##### Data & Recovery (System) › Import from JSON — Searches Executed

*`settings.import.type.searchHistoryEntry` · 09-Settings-and-App.md:891*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 641–641 | key: settings.import.type.searchHistoryEntry | shared: iOS+macOS (single edit point) -->

Searches Executed

<!-- END SOURCE: settings.import.type.searchHistoryEntry -->

##### Data & Recovery (System) › Import from JSON — Collections Exported

*`settings.import.type.exportHistoryEntry` · 09-Settings-and-App.md:898*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 643–643 | key: settings.import.type.exportHistoryEntry | shared: iOS+macOS (single edit point) -->

Collections Exported

<!-- END SOURCE: settings.import.type.exportHistoryEntry -->

##### Data & Recovery (System) › Import from JSON — Archives Visits

*`settings.import.type.archiveVisitPlan` · 09-Settings-and-App.md:905*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 645–645 | key: settings.import.type.archiveVisitPlan | shared: iOS+macOS (single edit point) -->

Archives Visits

<!-- END SOURCE: settings.import.type.archiveVisitPlan -->

##### Data & Recovery (System) › Import from JSON — Archives Visit Documents

*`settings.import.type.archiveVisitDocument` · 09-Settings-and-App.md:912*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 647–647 | key: settings.import.type.archiveVisitDocument | shared: iOS+macOS (single edit point) -->

Archives Visit Documents

<!-- END SOURCE: settings.import.type.archiveVisitDocument -->

##### Data & Recovery (System) › Import from JSON — Archives Visit Targets

*`settings.import.type.archiveVisitTarget` · 09-Settings-and-App.md:919*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 649–649 | key: settings.import.type.archiveVisitTarget | shared: iOS+macOS (single edit point) -->

Archives Visit Targets

<!-- END SOURCE: settings.import.type.archiveVisitTarget -->

##### Data & Recovery (System) › Import from JSON — Saved Searches

*`settings.import.type.savedSearch` · 09-Settings-and-App.md:926*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 651–651 | key: settings.import.type.savedSearch | shared: iOS+macOS (single edit point) -->

Saved Searches

<!-- END SOURCE: settings.import.type.savedSearch -->

##### Data & Recovery (System) › Import from JSON — Working Corpora

*`settings.import.type.workingCorpus` · 09-Settings-and-App.md:933*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 653–653 | key: settings.import.type.workingCorpus | shared: iOS+macOS (single edit point) -->

Working Corpora

<!-- END SOURCE: settings.import.type.workingCorpus -->

##### Data & Recovery (System) › Import from JSON — Volume Scopes

*`settings.import.type.customVolumeScope` · 09-Settings-and-App.md:940*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 655–655 | key: settings.import.type.customVolumeScope | shared: iOS+macOS (single edit point) -->

Volume Scopes

<!-- END SOURCE: settings.import.type.customVolumeScope -->

##### Data & Recovery (System) › Import from JSON — Classification Corrections

*`settings.import.type.documentClassificationOverride` · 09-Settings-and-App.md:947*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 657–657 | key: settings.import.type.documentClassificationOverride | shared: iOS+macOS (single edit point) -->

Classification Corrections

<!-- END SOURCE: settings.import.type.documentClassificationOverride -->

##### Data & Recovery (System) › Import from JSON — Person Corrections

*`settings.import.type.personClusterOverride` · 09-Settings-and-App.md:954*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 659–659 | key: settings.import.type.personClusterOverride | shared: iOS+macOS (single edit point) -->

Person Corrections

<!-- END SOURCE: settings.import.type.personClusterOverride -->

##### Data & Recovery (System) › Import from JSON — Reviewed Changes

*`settings.import.type.annotationReview` · 09-Settings-and-App.md:961*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 661–661 | key: settings.import.type.annotationReview | shared: iOS+macOS (single edit point) -->

Reviewed Changes

<!-- END SOURCE: settings.import.type.annotationReview -->

##### Data & Recovery (System) › Import from JSON — Suggested Next Leads

*`settings.import.type.projectLeadEntry` · 09-Settings-and-App.md:968*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 663–663 | key: settings.import.type.projectLeadEntry | shared: iOS+macOS (single edit point) -->

Suggested Next Leads

<!-- END SOURCE: settings.import.type.projectLeadEntry -->

##### Data & Recovery (System) › Import from JSON — Synced Settings

*`settings.import.type.syncedPreferences` · 09-Settings-and-App.md:975*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.typeName | lines: 665–665 | key: settings.import.type.syncedPreferences | shared: iOS+macOS (single edit point) -->

Synced Settings

<!-- END SOURCE: settings.import.type.syncedPreferences -->

##### Data & Recovery (System) › Import from JSON — From an Earlier Export

*`settings.import.readings.header` · 09-Settings-and-App.md:982*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsHeader | lines: 672–672 | key: settings.import.readings.header | shared: iOS+macOS (single edit point) -->

From an Earlier Export

<!-- END SOURCE: settings.import.readings.header -->

##### Data & Recovery (System) › Import from JSON — Collection entries with no document

*`settings.import.inert` · 09-Settings-and-App.md:989*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.inertLabel | lines: 676–676 | key: settings.import.inert | shared: iOS+macOS (single edit point) -->

Collection entries with no document

<!-- END SOURCE: settings.import.inert -->

##### Data & Recovery (System) › Import from JSON — Summaries that name no author

*`settings.import.noAuthorship` · 09-Settings-and-App.md:996*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.noAuthorshipLabel | lines: 680–680 | key: settings.import.noAuthorship | shared: iOS+macOS (single edit point) -->

Summaries that name no author

<!-- END SOURCE: settings.import.noAuthorship -->

##### Data & Recovery (System) › Import from JSON — Headnote drafts

*`settings.import.headnotes` · 09-Settings-and-App.md:1003*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.headnotesLabel | lines: 684–684 | key: settings.import.headnotes | shared: iOS+macOS (single edit point) -->

Headnote drafts

<!-- END SOURCE: settings.import.headnotes -->

##### Data & Recovery (System) › Import from JSON — Collections whose saved search is not here

*`settings.import.unlinked` · 09-Settings-and-App.md:1010*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.unlinkedLabel | lines: 688–688 | key: settings.import.unlinked | shared: iOS+macOS (single edit point) -->

Collections whose saved search is not here

<!-- END SOURCE: settings.import.unlinked -->

##### Data & Recovery (System) › Import from JSON — An earlier export wrote a heading, a prose block and a…

*`settings.import.inert.detail` · 09-Settings-and-App.md:1017*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsFooter | lines: 695–696 | key: settings.import.inert.detail | shared: iOS+macOS (single edit point) -->

An earlier export wrote a heading, a prose block and a section block alike, without saying which, so these come in as entries the collection editor leaves untouched and no export prints.

<!-- END SOURCE: settings.import.inert.detail -->

##### Data & Recovery (System) › Import from JSON — A summary that names no author comes in as AI-generated, as…

*`settings.import.noAuthorship.detail` · 09-Settings-and-App.md:1024*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsFooter | lines: 699–700 | key: settings.import.noAuthorship.detail | shared: iOS+macOS (single edit point) -->

A summary that names no author comes in as AI-generated, as the app reads any such summary.

<!-- END SOURCE: settings.import.noAuthorship.detail -->

##### Data & Recovery (System) › Import from JSON — A headnote draft is a summary a collection keeps for a…

*`settings.import.headnotes.detail` · 09-Settings-and-App.md:1031*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsFooter | lines: 703–704 | key: settings.import.headnotes.detail | shared: iOS+macOS (single edit point) -->

A headnote draft is a summary a collection keeps for a headnote, which no list or search shows; an earlier export marks it by its prompt.

<!-- END SOURCE: settings.import.headnotes.detail -->

##### Data & Recovery (System) › Import from JSON — A collection keeps its link to a saved search this library…

*`settings.import.unlinked.detail` · 09-Settings-and-App.md:1038*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.readingsFooter | lines: 707–708 | key: settings.import.unlinked.detail | shared: iOS+macOS (single edit point) -->

A collection keeps its link to a saved search this library does not hold, and shows it as it shows a link to a deleted search.

<!-- END SOURCE: settings.import.unlinked.detail -->

##### Data & Recovery (System) › Import from JSON — Importing %2$@ of %1$@ record…

*`settings.import.progress.one %@ %@` · 09-Settings-and-App.md:1045*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.progress | lines: 719–720 | key: settings.import.progress.one %@ %@ | shared: iOS+macOS (single edit point) -->

Importing %2$@ of %1$@ record…

<!-- END SOURCE: settings.import.progress.one %@ %@ -->

##### Data & Recovery (System) › Import from JSON — Importing %2$@ of %1$@ records…

*`settings.import.progress.many %@ %@` · 09-Settings-and-App.md:1052*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.progress | lines: 721–722 | key: settings.import.progress.many %@ %@ | shared: iOS+macOS (single edit point) -->

Importing %2$@ of %1$@ records…

<!-- END SOURCE: settings.import.progress.many %@ %@ -->

##### Data & Recovery (System) › Import from JSON — Imported

*`settings.import.done.header` · 09-Settings-and-App.md:1059*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.doneHeader | lines: 727–727 | key: settings.import.done.header | shared: iOS+macOS (single edit point) -->

Imported

<!-- END SOURCE: settings.import.done.header -->

##### Data & Recovery (System) › Import from JSON — Added

*`settings.import.done.added` · 09-Settings-and-App.md:1066*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.addedLabel | lines: 731–731 | key: settings.import.done.added | shared: iOS+macOS (single edit point) -->

Added

<!-- END SOURCE: settings.import.done.added -->

##### Data & Recovery (System) › Import from JSON — Replaced

*`settings.import.done.replaced` · 09-Settings-and-App.md:1073*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.replacedLabel | lines: 735–735 | key: settings.import.done.replaced | shared: iOS+macOS (single edit point) -->

Replaced

<!-- END SOURCE: settings.import.done.replaced -->

##### Data & Recovery (System) › Import from JSON — Already here

*`settings.import.done.kept` · 09-Settings-and-App.md:1080*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.keptLabel | lines: 739–739 | key: settings.import.done.kept | shared: iOS+macOS (single edit point) -->

Already here

<!-- END SOURCE: settings.import.done.kept -->

##### Data & Recovery (System) › Import from JSON — Notes now in plain text

*`settings.import.done.plainNotes` · 09-Settings-and-App.md:1087*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.plainNotesLabel | lines: 743–743 | key: settings.import.done.plainNotes | shared: iOS+macOS (single edit point) -->

Notes now in plain text

<!-- END SOURCE: settings.import.done.plainNotes -->

##### Data & Recovery (System) › Import from JSON — Summaries now AI-generated

*`settings.import.done.aiSummaries` · 09-Settings-and-App.md:1094*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.aiSummariesLabel | lines: 747–747 | key: settings.import.done.aiSummaries | shared: iOS+macOS (single edit point) -->

Summaries now AI-generated

<!-- END SOURCE: settings.import.done.aiSummaries -->

##### Data & Recovery (System) › Import from JSON — An earlier export cannot carry a note’s formatting or say…

*`settings.import.done.textChanged` · 09-Settings-and-App.md:1101*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.doneFooter | lines: 754–755 | key: settings.import.done.textChanged | shared: iOS+macOS (single edit point) -->

An earlier export cannot carry a note’s formatting or say who wrote a summary, so a note or summary whose text it replaced reads as plain text or as AI-generated.

<!-- END SOURCE: settings.import.done.textChanged -->

##### Data & Recovery (System) › Import from JSON — The imported records reach your other devices through…

*`settings.import.done.sync` · 09-Settings-and-App.md:1108*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.doneFooter | lines: 758–759 | key: settings.import.done.sync | shared: iOS+macOS (single edit point) -->

The imported records reach your other devices through iCloud, as your own changes do.

<!-- END SOURCE: settings.import.done.sync -->

##### Data & Recovery (System) › Import from JSON — Can’t Import This File

*`settings.import.failed.header` · 09-Settings-and-App.md:1115*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.failedHeader | lines: 767–767 | key: settings.import.failed.header | shared: iOS+macOS (single edit point) -->

Can’t Import This File

<!-- END SOURCE: settings.import.failed.header -->

##### Data & Recovery (System) › Import from JSON — Import Stopped

*`settings.import.stopped.header` · 09-Settings-and-App.md:1122*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.stoppedHeader | lines: 771–771 | key: settings.import.stopped.header | shared: iOS+macOS (single edit point) -->

Import Stopped

<!-- END SOURCE: settings.import.stopped.header -->

##### Data & Recovery (System) › Import from JSON — This file was exported by a newer version of FRUS Explorer,…

*`settings.import.error.newer` · 09-Settings-and-App.md:1129*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.problem | lines: 778–779 | key: settings.import.error.newer | shared: iOS+macOS (single edit point) -->

This file was exported by a newer version of FRUS Explorer, at format version \(version). Update the app to import it.

<!-- END SOURCE: settings.import.error.newer -->

##### Data & Recovery (System) › Import from JSON — This file names format version \(…), which no version…

*`settings.import.error.unknownVersion` · 09-Settings-and-App.md:1136*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.problem | lines: 781–782 | key: settings.import.error.unknownVersion | shared: iOS+macOS (single edit point) -->

This file names format version \(version), which no version of FRUS Explorer has written.

<!-- END SOURCE: settings.import.error.unknownVersion -->

##### Data & Recovery (System) › Import from JSON — This file is not a research export from Export as JSON, or…

*`settings.import.error.notAnExport` · 09-Settings-and-App.md:1143*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.problem | lines: 786–787 | key: settings.import.error.notAnExport | shared: iOS+macOS (single edit point) -->

This file is not a research export from Export as JSON, or it is damaged.

<!-- END SOURCE: settings.import.error.notAnExport -->

##### Data & Recovery (System) › Import from JSON — The file could not be read: \(…)

*`settings.import.error.unreadable` · 09-Settings-and-App.md:1150*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.unreadable | lines: 795–795 | key: settings.import.error.unreadable | shared: iOS+macOS (single edit point) -->

The file could not be read: \(detail)

<!-- END SOURCE: settings.import.error.unreadable -->

##### Data & Recovery (System) › Import from JSON — The import stopped: \(…) What it saved before it…

*`settings.import.error.stopped` · 09-Settings-and-App.md:1157*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataImportView.swift | ResearchImportCopy.stopped | lines: 800–801 | key: settings.import.error.stopped | shared: iOS+macOS (single edit point) -->

The import stopped: \(detail) What it saved before it stopped is kept, and importing the file again adds the rest.

<!-- END SOURCE: settings.import.error.stopped -->

##### Data & Recovery (System) › Language Analysis — the Diagnostics row (#1539)

*Added by #1539. A read-only row in Data & Recovery's Diagnostics section, on iPhone, iPad and Mac (one shared view), saying what this device's language analysis can do in this session. The row's title, then its trailing value and detail line for each state: while the app is still checking, when all three parts work, and when one or more does not.*

*`settings.dataRecovery.languageAnalysis` · 09-Settings-and-App.md:1229*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisRow.body | lines: 745–746 | key: settings.dataRecovery.languageAnalysis | shared: iOS+macOS (single edit point) -->

Language Analysis

<!-- END SOURCE: settings.dataRecovery.languageAnalysis -->

*`settings.dataRecovery.languageAnalysis.value.checking` · 09-Settings-and-App.md:1235*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 902–903 | key: settings.dataRecovery.languageAnalysis.value.checking | shared: iOS+macOS (single edit point) -->

Checking

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.value.checking -->

*`settings.dataRecovery.languageAnalysis.detail.checking` · 09-Settings-and-App.md:1241*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 904–905 | key: settings.dataRecovery.languageAnalysis.detail.checking | shared: iOS+macOS (single edit point) -->

Finding out what this device’s language analysis can do.

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.detail.checking -->

*`settings.dataRecovery.languageAnalysis.value.working` · 09-Settings-and-App.md:1247*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 909–910 | key: settings.dataRecovery.languageAnalysis.value.working | shared: iOS+macOS (single edit point) -->

Working

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.value.working -->

*`settings.dataRecovery.languageAnalysis.detail.working` · 09-Settings-and-App.md:1253*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 911–912 | key: settings.dataRecovery.languageAnalysis.detail.working | shared: iOS+macOS (single edit point) -->

Dictionary forms, parts of speech and names all work on this device.

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.detail.working -->

*`settings.dataRecovery.languageAnalysis.value.limited` · 09-Settings-and-App.md:1259*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 914–915 | key: settings.dataRecovery.languageAnalysis.value.limited | shared: iOS+macOS (single edit point) -->

Limited

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.value.limited -->

*Interpolated with the parts that are not working, joined as a list from the three names below — for example “dictionary forms” or “dictionary forms and names”.*

*`settings.dataRecovery.languageAnalysis.detail.limited %@` · 09-Settings-and-App.md:1267*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.init | lines: 917–918 | key: settings.dataRecovery.languageAnalysis.detail.limited %@ | shared: iOS+macOS (single edit point) -->

Not working right now: %@. FRUS Explorer checks again each time you come back to it.

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.detail.limited %@ -->

*`settings.dataRecovery.languageAnalysis.capability.lemmas` · 09-Settings-and-App.md:1273*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.missingCapabilities | lines: 930–931 | key: settings.dataRecovery.languageAnalysis.capability.lemmas | shared: iOS+macOS (single edit point) -->

dictionary forms

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.capability.lemmas -->

*`settings.dataRecovery.languageAnalysis.capability.classes` · 09-Settings-and-App.md:1279*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.missingCapabilities | lines: 934–935 | key: settings.dataRecovery.languageAnalysis.capability.classes | shared: iOS+macOS (single edit point) -->

parts of speech

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.capability.classes -->

*`settings.dataRecovery.languageAnalysis.capability.names` · 09-Settings-and-App.md:1285*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisSummary.missingCapabilities | lines: 938–939 | key: settings.dataRecovery.languageAnalysis.capability.names | shared: iOS+macOS (single edit point) -->

names

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.capability.names -->

##### Data & Recovery (System) › Language Analysis — Copy Language Analysis Record (#1608)

*Added by #1608. The row under Language Analysis, on iPhone, iPad and Mac (one shared view). It copies what the language check has logged since the app opened, so a tester can paste it into a report: an iPhone’s own log held those lines for about nine hours when it was read on 2026-10-11, and reading that log takes a Mac. Three strings: the button’s title; its title for two seconds after it is pressed, which is also what VoiceOver is told; and its explanation, which is the pointer’s tooltip on the Mac and VoiceOver’s hint on iPhone and iPad. The copied text is not in these files. It is the log’s own lines, each with its time, under the app’s version and build, the system’s version and the device’s model, and it is not translated.*

*`settings.dataRecovery.languageAnalysis.copy` · 09-Settings-and-App.md:1295*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisRow.copyLabel | lines: 764–765 | key: settings.dataRecovery.languageAnalysis.copy | shared: iOS+macOS (single edit point) -->

Copy Language Analysis Record

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.copy -->

*`settings.dataRecovery.languageAnalysis.copied` · 09-Settings-and-App.md:1301*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisRow.copiedLabel | lines: 770–770 | key: settings.dataRecovery.languageAnalysis.copied | shared: iOS+macOS (single edit point) -->

Copied

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.copied -->

*`settings.dataRecovery.languageAnalysis.copy.help` · 09-Settings-and-App.md:1307*

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | LanguageAnalysisRow.body | lines: 757–758 | key: settings.dataRecovery.languageAnalysis.copy.help | shared: iOS+macOS (single edit point) -->

Copies what the language check has found since the app opened, with the app’s and the system’s versions. Paste it into a bug report.

<!-- END SOURCE: settings.dataRecovery.languageAnalysis.copy.help -->

##### Display & Reading › Reading Width (#1665)

*Settings ▸ Display's Reading Width, beside Document Text Size (#1665, the owner's decisions 20 and 50 of 2026-10-15 and 2026-10-16). Three steps on two ladders: on iPhone 60, 70 and 87ch, on iPad and the Mac 70, 87 and 120ch, so each footer below states its device's figures — the mean characters a line at Medium text, measured on the Long Telegram (`ReadingWidth`). A footer's figures change only with a rung, and `ReadingWidthTests` measures them again.*

*`settings.display.readingWidth.label, settings.display.readingWidth.a11y` · 09-Settings-and-App.md:1336*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | lines: 1686–1696 | keys: settings.display.readingWidth.label, settings.display.readingWidth.a11y | shared: iOS+macOS (single edit point) -->

**The control's name:** Reading Width

**VoiceOver:** Document reading width

<!-- END SOURCE: settings.display.readingWidth.control -->

*`settings.display.readingWidth.header` · 09-Settings-and-App.md:1344*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | lines: 1700–1701 | key: settings.display.readingWidth.header | shared: iOS+macOS (single edit point) -->

Reading Width

<!-- END SOURCE: settings.display.readingWidth.header -->

*`settings.display.readingWidth.narrow, settings.display.readingWidth.standard, settings.display.readingWidth.wide` · 09-Settings-and-App.md:1350*

<!-- SOURCE: FRUSExplorer/TEI/ReadingWidth.swift | ReadingWidth.label | lines: 52–55 | keys: settings.display.readingWidth.narrow, settings.display.readingWidth.standard, settings.display.readingWidth.wide | shared: iOS+macOS (single edit point) -->

**The three steps:** Narrow · Standard · Wide

<!-- END SOURCE: settings.display.readingWidth.steps -->

*`settings.display.readingWidth.footer.phone` · 09-Settings-and-App.md:1356*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView.readingWidthFooter | lines: 1655–1656 | key: settings.display.readingWidth.footer.phone | shared: iPhone only -->

How long a document’s lines may grow: about 63 characters at Narrow, 77 at Standard and 100 at Wide, at Medium text. In portrait the screen is narrower than all three.

<!-- END SOURCE: settings.display.readingWidth.footer.phone -->

*`settings.display.readingWidth.footer.wide` · 09-Settings-and-App.md:1362*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView.readingWidthFooter | lines: 1658–1659 | key: settings.display.readingWidth.footer.wide | shared: iPad and macOS -->

How long a document’s lines may grow: about 77 characters at Narrow, 100 at Standard and 145 at Wide, at Medium text. A narrower window, or the Research panel beside the document, makes them shorter.

<!-- END SOURCE: settings.display.readingWidth.footer.wide -->

#### 14. Short strings bumped since the build-42 pass — the parts about this area

##### Storage hub — the reindex and maintenance controls › Only volumes not yet fully indexed.

*`settings.hub.indexRemaining.detail.v2` · 09-Settings-and-App.md:1562*

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | lines: 549–550 | key: settings.hub.indexRemaining.detail.v2 -->

*The line under **Index Remaining** in Volumes & Storage ▸ Storage & Index on iPhone and iPad. The button indexes each downloaded volume the index holds no document of, and since #1689 each one whose indexing stopped before the app finished writing it to the index, which can hold some of its documents and not the rest. Until then it passed the second kind over, and the line read "Only volumes not yet indexed." (`settings.hub.indexRemaining.detail`).*

Only volumes not yet fully indexed.

<!-- END SOURCE: settings.hub.indexRemaining.detail.v2 -->

##### Storage hub — the reindex and maintenance controls › Index volumes not yet fully indexed

*`settings.hub.indexRemaining.a11y.v2` · 09-Settings-and-App.md:1571*

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 544–545 | key: settings.hub.indexRemaining.a11y.v2 -->

*What VoiceOver calls the Mac's **Index Remaining** button; its tooltip is the next block. Since #1689 the button also takes a volume whose indexing stopped before the app finished writing it to the index, so its name no longer reads "Index volumes that have not been indexed yet" (`settings.hub.indexRemaining.a11y`).*

Index volumes not yet fully indexed

<!-- END SOURCE: settings.hub.indexRemaining.a11y.v2 -->

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.13 Settings › The copy will carry index version \(…).

*`settings.export.database.indexVersion` · 09-Settings-and-App.md:1732*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 678–679 | key: settings.export.database.indexVersion | shared: macOS only -->

The copy will carry index version \(installed).

<!-- END SOURCE: settings.export.database.indexVersion -->

##### 18.13 Settings › The copy will carry index version \(…), not this build’s \(…).

*`settings.export.database.indexVersion.older` · 09-Settings-and-App.md:1739*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 675–676 | key: settings.export.database.indexVersion.older | shared: macOS only -->

The copy will carry index version \(installed), not this build’s \(current).

<!-- END SOURCE: settings.export.database.indexVersion.older -->

##### 18.13 Settings › The index is being updated to version \(…). You can export it…

*`settings.export.database.indexVersion.updatingTo` · 09-Settings-and-App.md:1746*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 664–665 | key: settings.export.database.indexVersion.updatingTo | shared: macOS only -->

The index is being updated to version \(current). You can export it when the update is done.

<!-- END SOURCE: settings.export.database.indexVersion.updatingTo -->

##### 18.13 Settings › The index is being updated. You can export it when the update is done.

*`settings.export.database.indexVersion.updating` · 09-Settings-and-App.md:1753*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 667–668 | key: settings.export.database.indexVersion.updating | shared: macOS only -->

The index is being updated. You can export it when the update is done.

<!-- END SOURCE: settings.export.database.indexVersion.updating -->

##### 18.13 Settings › The index has no version recorded yet.

*`settings.export.database.indexVersion.none` · 09-Settings-and-App.md:1760*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.line | lines: 671–672 | key: settings.export.database.indexVersion.none | shared: macOS only -->

The index has no version recorded yet.

<!-- END SOURCE: settings.export.database.indexVersion.none -->

##### 18.13 Settings › Exported \(…), index version \(…).

*`settings.export.database.done.withVersion` · 09-Settings-and-App.md:1767*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DatabaseExportIndexVersion.doneLine | lines: 688–689 | key: settings.export.database.done.withVersion | shared: macOS only -->

Exported \(size), index version \(version).

<!-- END SOURCE: settings.export.database.done.withVersion -->

##### 18.13 Settings › Export as JSON…

*`settings.export.json.action.mac` · 09-Settings-and-App.md:1776*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.jsonExportRow | lines: 427–427 | key: settings.export.json.action.mac | shared: macOS only -->

Export as JSON…

<!-- END SOURCE: settings.export.json.action.mac -->

##### 18.13 Settings › Share…

*`settings.export.share` · 09-Settings-and-App.md:1783*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.shareTitle | lines: 413–413 | key: settings.export.share | shared: macOS only -->

Share…

<!-- END SOURCE: settings.export.share -->

##### 18.13 Settings › Export Notes as Markdown (\(…))…

*`settings.export.markdown.action.mac` · 09-Settings-and-App.md:1790*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.markdownExportRow | lines: 479–480 | key: settings.export.markdown.action.mac | shared: macOS only -->

Export Notes as Markdown (\(markdownExportURLs.count))…

<!-- END SOURCE: settings.export.markdown.action.mac -->

##### 18.13 Settings › FRUS Research Notes

*`settings.export.markdown.folderName` · 09-Settings-and-App.md:1797*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.markdownExportRow | lines: 472–473 | key: settings.export.markdown.folderName | shared: macOS only -->

FRUS Research Notes

<!-- END SOURCE: settings.export.markdown.folderName -->

##### 18.13 Settings › Choose a folder. Your notes are saved in a new folder inside…

*`settings.export.markdown.panelMessage` · 09-Settings-and-App.md:1804*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.markdownExportRow | lines: 474–475 | key: settings.export.markdown.panelMessage | shared: macOS only -->

Choose a folder. Your notes are saved in a new folder inside it, “FRUS Research Notes”, one Markdown file per note.

<!-- END SOURCE: settings.export.markdown.panelMessage -->

##### 18.13 Settings › Export Query Log as a Method Appendix…

*`settings.export.appendix.action.mac` · 09-Settings-and-App.md:1811*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.appendixExportRow | lines: 525–526 | key: settings.export.appendix.action.mac | shared: macOS only -->

Export Query Log as a Method Appendix…

<!-- END SOURCE: settings.export.appendix.action.mac -->

##### 18.13 Settings › FRUS Query Log

*`settings.export.appendix.folderName` · 09-Settings-and-App.md:1818*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.appendixExportRow | lines: 518–519 | key: settings.export.appendix.folderName | shared: macOS only -->

FRUS Query Log

<!-- END SOURCE: settings.export.appendix.folderName -->

##### 18.13 Settings › Choose a folder. The query log is saved in a new folder inside…

*`settings.export.appendix.panelMessage` · 09-Settings-and-App.md:1825*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.appendixExportRow | lines: 520–521 | key: settings.export.appendix.panelMessage | shared: macOS only -->

Choose a folder. The query log is saved in a new folder inside it, “FRUS Query Log”, as a Markdown table and a CSV.

<!-- END SOURCE: settings.export.appendix.panelMessage -->

##### 18.13 Settings › Export Here

*`settings.export.folder.prompt` · 09-Settings-and-App.md:1832*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections.saveFolderExport | lines: 389–389 | key: settings.export.folder.prompt | shared: macOS only -->

Export Here

<!-- END SOURCE: settings.export.folder.prompt -->

##### 18.13 Settings › Saved “\(…)” in \(…).

*`settings.export.saved.file` · 09-Settings-and-App.md:1839*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | ExportDestinationWriter.savedFileLine | lines: 778–779 | key: settings.export.saved.file | shared: macOS only -->

Saved “\(name)” in \(folder).

<!-- END SOURCE: settings.export.saved.file -->

##### 18.13 Settings › Saved %1$@ file in a new folder, “%2$@”, in %3$@.

*`settings.export.saved.folder.one %@` · 09-Settings-and-App.md:1846*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | ExportDestinationWriter.savedFolderLine | lines: 789–790 | key: settings.export.saved.folder.one %@ | shared: macOS only -->

Saved %1$@ file in a new folder, “%2$@”, in %3$@.

<!-- END SOURCE: settings.export.saved.folder.one %@ -->

##### 18.13 Settings › Saved %1$@ files in a new folder, “%2$@”, in %3$@.

*`settings.export.saved.folder.many %@` · 09-Settings-and-App.md:1853*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | ExportDestinationWriter.savedFolderLine | lines: 791–792 | key: settings.export.saved.folder.many %@ | shared: macOS only -->

Saved %1$@ files in a new folder, “%2$@”, in %3$@.

<!-- END SOURCE: settings.export.saved.folder.many %@ -->

##### 18.13 Settings › Couldn’t save the export: \(…)

*`settings.export.saveFailed` · 09-Settings-and-App.md:1860*

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | ExportDestinationWriter.failedLine | lines: 798–799 | key: settings.export.saveFailed | shared: macOS only -->

Couldn’t save the export: \(error.localizedDescription)

<!-- END SOURCE: settings.export.saveFailed -->

##### 18.13 Settings › Prompts still edit and sync to your other devices…

*`settings.summarization.availability.unavailable.prompts` · 09-Settings-and-App.md:2034*

<!-- SOURCE: FRUSExplorer/Settings/FRUSSettingsView.swift | SettingsSummarizationPane.body | lines: 782–783 | key: settings.summarization.availability.unavailable.prompts | same text also in: FRUSExplorer/Settings/SettingsView.swift -->
<!-- The same key and wording are declared in each file named above; an edit here is applied to all of them. -->

Prompts still edit and sync to your other devices, where they are used for generation.

<!-- END SOURCE: settings.summarization.availability.unavailable.prompts -->

##### 18.14 App-wide status, sync and schema messages › Sync banner — a stopped sync, remembered across launches (#1531)

*Added by lane SYNC (#1531): the wording for a failure the app remembers across launches. It shows when an upload from this device failed in an EARLIER session and none has succeeded since — so the reader has already relaunched, and the banner neither tells them to relaunch nor promises a retry. A successful download does not hide it; only a successful upload ends it. The one-session failure keeps its own line above. VoiceOver reads the title and the line. Details opens the Settings iCloud Sync row, which says since when (next blocks).*

*`sync.banner.stopped.title` · 09-Settings-and-App.md:2367*

<!-- SOURCE: FRUSExplorer/App/SyncStatusBanner.swift | key: sync.banner.stopped.title | SyncStatusBanner.content -->

iCloud Sync Stopped

<!-- END SOURCE: sync.banner.stopped.title -->

*`sync.banner.stopped.detail` · 09-Settings-and-App.md:2373*

<!-- SOURCE: FRUSExplorer/App/SyncStatusBanner.swift | key: sync.banner.stopped.detail | SyncStatusBanner.content -->

Sync stopped on this device; your changes are kept here.

<!-- END SOURCE: sync.banner.stopped.detail -->

##### 18.14 App-wide status, sync and schema messages › A stopped sync — the Settings row and the Mac status bar (#1531)

*Added by lane SYNC (#1531). The iPhone and iPad Settings iCloud Sync row reads **Sync Stopped**, and the Mac status bar's chip reads **Sync Stopped** and opens a popover titled **iCloud Sync Stopped**. Both show the explanation below, with %@ the date and time of the first failed upload, then “Diagnostic:” and the redacted error and any record-type and field names it carried, for a bug report. The Mac chip's tooltip is the explanation alone.*

*`settings.icloud.stopped` · 09-Settings-and-App.md:2383*

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 286–286 | key: settings.icloud.stopped -->

Sync Stopped

<!-- END SOURCE: settings.icloud.stopped -->

*`statusBar.sync.stopped` · 09-Settings-and-App.md:2389*

<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | StatusBarView.cloudKitStatusChip | lines: 705–705 | key: statusBar.sync.stopped | shared: macOS only -->

Sync Stopped

<!-- END SOURCE: statusBar.sync.stopped -->

*`statusBar.sync.stopped.title` · 09-Settings-and-App.md:2395*

<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | StatusBarView.cloudKitStatusChip | lines: 715–716 | key: statusBar.sync.stopped.title | shared: macOS only -->

iCloud Sync Stopped

<!-- END SOURCE: statusBar.sync.stopped.title -->

*`sync.stopped.detail %@` · 09-Settings-and-App.md:2401*

<!-- SOURCE: FRUSExplorer/App/ICloudStatusSummary.swift | SyncStoppedCopy.detail | lines: 195–196 | key: sync.stopped.detail %@ | shared: iOS+macOS (single edit point) -->

No upload from this device has succeeded since %@. Your changes are kept here, and Fix iCloud Sync would discard them.

<!-- END SOURCE: sync.stopped.detail %@ -->

*`sync.stopped.diagnostic %@` · 09-Settings-and-App.md:2407*

<!-- SOURCE: FRUSExplorer/App/ICloudStatusSummary.swift | SyncStoppedCopy.diagnostic | lines: 206–207 | key: sync.stopped.diagnostic %@ | shared: iOS+macOS (single edit point) -->

Diagnostic: %@

<!-- END SOURCE: sync.stopped.diagnostic %@ -->

##### 18.14 App-wide status, sync and schema messages › The Live Activity, once the app has stopped updating it (#1642)

*Added 2026-10-12 (#1642). What the Lock Screen and the Dynamic Island say under the activity’s title when the app has stopped updating it: iOS suspended the app after you left it, or the app was closed. The system marks the activity two minutes after the app’s last update, and until then it shows the progress as it stood. One sentence for an index run and two for a summarization run. The widget cannot tell a suspended app from a closed one, so each sentence has to be true of both: opening the app carries a suspended run on, and after the app was closed the launch removes the activity. A summarization run started with Continue in the background switched on, which the app will take up again by itself between your visits, reads the third sentence (#1695, plan of record decision 64, 2026-10-19); with it off, or switched on only after the run began, the second. Since #1695 the three are in `FRUSExplorer/Models/IndexingActivityAttributes.swift`, the file the app and the widget both compile, where they were in the widget’s own file, so a test reads what the widget prints. The indexing sentence fits one line on an iPhone 17’s Lock Screen and the summarization sentence wraps to two; the second was seen only on a build that labelled an index run as a summarization run, since no summarization runs on a simulator.*

*`liveactivity.stopped.indexing` · 09-Settings-and-App.md:2457*

<!-- SOURCE: FRUSExplorer/Models/IndexingActivityAttributes.swift | ContentState.stoppedLabel | lines: 128–129 | key: liveactivity.stopped.indexing -->

Indexing has stopped. Open FRUS Explorer to continue.

<!-- END SOURCE: liveactivity.stopped.indexing -->

*`liveactivity.stopped.summarizing` · 09-Settings-and-App.md:2463*

<!-- SOURCE: FRUSExplorer/Models/IndexingActivityAttributes.swift | ContentState.stoppedLabel | lines: 135–136 | key: liveactivity.stopped.summarizing -->

Summarizing has stopped. Open FRUS Explorer to continue.

<!-- END SOURCE: liveactivity.stopped.summarizing -->

*`liveactivity.stopped.summarizing.background` · 09-Settings-and-App.md:2469*

<!-- SOURCE: FRUSExplorer/Models/IndexingActivityAttributes.swift | ContentState.stoppedLabel | lines: 132–133 | key: liveactivity.stopped.summarizing.background -->

Summarizing will continue in the background. Open FRUS Explorer to continue now.

<!-- END SOURCE: liveactivity.stopped.summarizing.background -->

##### 18.14 App-wide status, sync and schema messages › The Live Activity while the app is updating it (#1695)

*Added 2026-10-20 (#1695). The activity’s other words, which had no block: what it says under the title before a volume’s documents are counted, and before a summarization run knows how many documents it has; the title of the merge that ends a whole-library index pass, which had been empty; and the title of a summarization run. Since #1695 one activity follows a whole indexing queue, titled by each volume in turn (plan of record decision 63), and the finishing merge’s words are its title, where they had been a line under an empty one. The count under the bar (“312/740 docs”) and the seconds left (“~12s”, none under five since #1695) are not keyed strings, and have no block.*

*`liveactivity.parsing` · 09-Settings-and-App.md:2479*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorerWidgets/IndexingLiveActivity.swift | ContentState.indeterminateLabel | lines: 48–48 | key: liveactivity.parsing -->

Parsing…

<!-- END SOURCE: liveactivity.parsing -->

*`liveactivity.summarizing.preparing` · 09-Settings-and-App.md:2485*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorerWidgets/IndexingLiveActivity.swift | ContentState.indeterminateLabel | lines: 52–53 | key: liveactivity.summarizing.preparing -->

Preparing to summarize…

<!-- END SOURCE: liveactivity.summarizing.preparing -->

*`liveactivity.optimizing` · 09-Settings-and-App.md:2491*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/App/AppState.swift | LiveActivityLifecycle.indexingState | lines: 4669–4669 | key: liveactivity.optimizing -->

Finalizing index…

<!-- END SOURCE: liveactivity.optimizing -->

*`liveactivity.summarizing.title` · 09-Settings-and-App.md:2497*

*Already in the app at your pass; this file did not carry it then.*

<!-- SOURCE: FRUSExplorer/App/AppState.swift | LiveActivityLifecycle.summarizationState | lines: 4711–4712 | key: liveactivity.summarizing.title -->

Summarizing FRUS documents

<!-- END SOURCE: liveactivity.summarizing.title -->

---

## Part 3 — Gone from the app (10)

*For the record only: none of these strings is in the app, so editing them here has no effect.*

### 01 About & Onboarding — gone

#### 1. About Screen

##### 1.4b On-Device Model — EmbeddingGemma Notice

*`about.modelLicense.gemma.body` · retired; still in 01-About-and-Onboarding.md:83 under this banner:*

> ⚠️ **RETIRED — editing this block has no effect.** The section went with EmbeddingGemma 300m
> (B4, 2026-10-15): its successor, an Open Source row under Apache 2.0, is §1.4e. Kept so the
> Gemma notice's wording is not lost; delete it when you next revise this section.

> When you enable natural-language search, the app downloads Google’s EmbeddingGemma model (229 MB) and runs it on this device to convert your search queries into vectors. The model is used unmodified. Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms, including its Prohibited Use Policy.

##### 1.4c Search Model — Consent Sheet

*`settings.model.consent.body` · retired; still in 01-About-and-Onboarding.md:97 under this banner:*

> ⚠️ **RETIRED — editing this block has no effect.** The sheet went with EmbeddingGemma 300m
> (B4, 2026-10-15): under Apache 2.0 there is no flow-down, so Download Search Model downloads.
> Kept so the wording is not lost; delete it when you next revise this section.

> This optional 229 MB download is Google’s EmbeddingGemma model, provided under and subject to the Gemma Terms of Use, including its Prohibited Use Policy. By downloading it you agree to use it consistently with those terms.

### 06 Archives — gone

#### 15. Archives Visits — the research-trip planner

##### 15.6 The trip-packet sheet › Empty — a smart collection's search cannot run

*`packet.empty.smart.title` · removed from 06-Archives.md. The Amendment-Log entry that names it (line 175) begins: “amended for lane HYG of the 2026-09-28 plan of record (2026-10-01, the build-49 wave), #1412, #1439, #1423, #1450, #1484”.*

> This collection’s search can’t run yet

*`packet.empty.smart.message` · removed from 06-Archives.md. The Amendment-Log entry that names it (line 175) begins: “amended for lane HYG of the 2026-09-28 plan of record (2026-10-01, the build-49 wave), #1412, #1439, #1423, #1450, #1484”.*

> This collection’s documents come from its saved search, and search isn’t available yet. Finish indexing and try again.

### 07 Search & Browse — gone

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.1 Search — scope footers, prompts, Meaning mode, facets and collocations › Detected topics from the Office of the Historian, matched…

*`facets.subjects.provenance` · retired; still in 07-Search-and-Browse.md:2783 under this banner:*

> ⚠️ **RETIRED — editing this block has no effect.** No line holds it: #1905 put the subject data's one
> caption, `subjects.caption` (§16.4), where this account stood in the facet panel's Subjects section.
> Kept so the wording is not lost; delete it when you next revise this section.

> Detected topics from the Office of the Historian, matched by name — not the volumes’ own markup.

### 08 Reading, Research & Collections — gone

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.10 Reading — the document, its rail, Related, Chronology, cross-references and citations › Document \(…) was not found in this volume (last document…

*`citation.match.fuzzyNote` · removed from 08-Reading-Research-Collections.md. The Amendment-Log entry that names it (line 98) begins: “amended for #1474, which changes no existing `defaultValue”.*

> Document \(requested) was not found in this volume (last document is \(max)); the nearest available document is \(nearest).

##### 18.11 Research, projects and history › Project Home ▸ Collections — a collection with no name

*`project.home.collections.untitled` · removed from 08-Reading-Research-Collections.md. The Amendment-Log entry that names it (line 160) begins: “amended for lane EXPORT of the 2026-09-28 plan of record (2026-10-01, the build-49 wave), #1465, #1496, #1497, #1498, #1464”.*

> Untitled Collection

##### 18.11 Research, projects and history › Project Home ▸ Manage — a collection with no name

*`project.collections.manage.untitled` · removed from 08-Reading-Research-Collections.md. The Amendment-Log entry that names it (line 160) begins: “amended for lane EXPORT of the 2026-09-28 plan of record (2026-10-01, the build-49 wave), #1465, #1496, #1497, #1498, #1464”.*

> Untitled Collection

##### 18.12 Collections, Zotero and the trip packet › This is a smart collection. Its documents are resolved from…

*`collection.editor.docs.smartEmpty` · retired; still in 08-Reading-Research-Collections.md:2714 under this banner:*

> ⚠️ **RETIRED — editing this block has no effect.** #1619 replaced it with the next block, the picker's
> sentence, which a smart collection's Contents now opens with whether or not it holds entries. Kept so
> the wording is not lost; delete it when you next revise this section.

> This is a smart collection. Its documents are resolved from the linked saved search when you export — use Export in Actions below.

### 09 Settings & app-wide messages — gone

#### 18. Prose this file had never carried (build-48 sweep) — the parts about this area

##### 18.13 Settings › The included copy of the terms could not be loaded. The…

*`about.gemmaTerms.missing` · retired; still in 09-Settings-and-App.md:1872 under this banner:*

> ⚠️ **RETIRED — editing this block has no effect.** The bundled Gemma Terms screen went with
> EmbeddingGemma 300m (B4, 2026-10-15). Kept so the wording is not lost; delete it when you
> next revise this section.

> The included copy of the terms could not be loaded. The authoritative text is at the link below.
