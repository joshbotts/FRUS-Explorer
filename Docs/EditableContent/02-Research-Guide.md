# EditableContent — FRUS Research Guide

Part of the owner’s editing surface, `Docs/EditableContent/` (read `README.md` there first). Covers §3. Every block’s text is what the app shows at `v2` 07b9b65c (build 48). Section numbers are the ones the single file used, so references like “§18’s rule” still point somewhere.

**In this file:** 11 blocks · 5 ✎ unlanded 2026-09-21 edits · no ⚑ wording issues

✎ under: 3.2 Page 2 — 163 Years in Progress; 3.4 Page 4 — Using FRUS for Research; 3.5 Page 5 — Finding What You Need in FRUS Explorer; 3.6 Page 6 — Seeing the Bigger Picture in FRUS Explorer; 3.7 Page 7 — Working With Documents in FRUS Explorer

---

## 3. FRUS Research Guide (in-app education pages)

*`IndexingEducationView` — the in-app FRUS Research Guide. It has **eleven pages**: **seven prose pages** (pages 1–7) whose text is editable below, followed by **four live "About the Series" dashboard pages** that render interactive charts instead of prose. The guide is shown while the first index builds and is also reachable any time from the app (iOS Settings → FRUS Research Guide; macOS `frus.researchGuide` window).*

*The content model is a series of `EducationPage` and `EducationSection` structs. Structure per prose page: **Title**, optional **Subtitle**, then one or more **Sections**. Each section has an optional **Heading**, one or more **Paragraphs**, and an optional **Bullet list**.*

*The `id` values in the annotations (`page-id` / `section-id`) are the Swift `id` strings on the structs — they are used as update keys and must not be changed. Prose here uses raw Swift string literals in code (not localized), so edits map back verbatim.*

*The four dashboard pages (§3.8–§3.11) have **no editable page prose** (`sections: []`). Their on-screen copy — intro paragraph, per-chart captions, and caveats — lives in the dashboard view files as localized strings; those blocks list where to edit it. Do not add prose here for those pages.*

---

### 3.1 Page 1 — The Official Record of American Foreign Policy

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: what-frus-is | lines: 688–734 -->

**Title:** The Official Record of American Foreign Policy

**Subtitle:** Foreign Relations of the United States

<!-- section-id: intro -->

Foreign Relations of the United States — FRUS — is the official documentary history of major U.S. foreign policy decisions and significant diplomatic activity, published continuously by the Department of State since 1861. It is one of the longest-running publication programs of the U.S. government and an indispensable source for the history of American diplomacy.

<!-- section-id: mandate -->

**Congressionally-Mandated Historical Transparency**

Since 1991, FRUS is required by federal statute (Public Law 102-138, codified at [22 U.S.C. § 4351 et seq.](https://uscode.house.gov/view.xhtml?req=%22foreign+relations+of+the+United+States%22+series&f=treesort&fq=true&num=2&hl=true&edition=prelim&granuleId=USC-prelim-title22-section4351), amended 2021). The law establishes four binding commitments:

- The series must constitute “a thorough, accurate, and reliable documentary record of major United States foreign policy decisions and significant United States diplomatic activity. Volumes of this publication shall include all records needed to provide a comprehensive documentation of the major foreign policy decisions and actions of the United States Government, including the facts which contributed to the formulation of policies and records providing supporting and alternative views to the policy position ultimately adopted”
- Volumes must be published within 30 years of the events they document
- Government departments must grant historians full access to pertinent records at 20 years
- An Advisory Committee on Historical Diplomatic Documentation comprised of representatives of major scholarly organizations and experts chosen by the Department of State must oversee the production and declassification process to validate the historical objectivity of the series

<!-- section-id: ooh -->

**Prepared by the Department of State’s Office of the Historian**

FRUS volumes are compiled and edited by professional historians in the Office of the Historian at the Department of State. Historians in the compilation and review team identify the most important documents, provide context through editorial notes and annotations, and review draft volume manuscripts to ensure they provide “thorough, accurate, and reliable” coverage of the assigned topic(s). Historians in the declassification, publishing, and digital initiatives team coordinate the complex and thorough interagency declassification review required before release and then the detailed preparation of the manuscript required for publication.

<!-- section-id: sources -->

**Breadth of Sources**

FRUS historians draw on still-classified records from the White House and National Security Council at Presidential Libraries as well as records from the Departments of State and Defense, the CIA, and other agencies, both at the National Archives and directly at those agencies. When needed, they also seek access to the private papers of key policymakers.

<!-- section-id: scope -->

**Scope**

FRUS volumes produced today cover U.S. bilateral and regional relations across the globe, including U.S. policymakers’ responses to unfolding crises; their engagement with global issues like human rights, terrorism, narcotics, health, and the environment; and thematic topics including national security policy, foreign economic policy, and foreign affairs organization and management. The series currently spans from 1861 through the early 1990s, with volumes covering the Clinton administration still in production.

<!-- END SOURCE: page what-frus-is -->

---

### 3.2 Page 2 — 163 Years in Progress

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: corpus-evolution | lines: 740–794 -->

**Title:** 163 Years in Progress

**Subtitle:** How FRUS changed — and why it matters for research

<!-- section-id: origins -->

**Origins: Diplomatic Correspondence (1861–1920s)**

At its birth, FRUS was an instrument of public affairs and congressional relations. The series began during the Civil War as a compilation of official diplomatic correspondence — despatches from diplomatic posts, instructions to U.S. ministers overseas, and notes to and from foreign governments. The volumes documented the operations of the State Department. Coverage was often contemporaneous: volumes sometimes appeared within a year of events, prioritizing currency over comprehensiveness. Because the volumes were produced by the same clerks who administered the Department’s day-to-day business, principles of selection and editing standards reflected operational rather than historical purposes. By the early 20th century, the series had evolved to became a valuable knowledge management tool by providing ready access to key policy and precedent references for officials within the Department and its overseas posts and growing stakeholder constituencies in civil society.

<!-- section-id: professionalization -->

**Professionalization in the Interwar Era (1924-1945)**

In the 1920s, the Department of State began recruiting professionally-trained historians to undertake the increasingly complex editorial work of producing FRUS. Because budget constraints in the early 1900s and operational considerations during World War I delayed publication throughout the previous two decades, those historians had an opportunity to select and edit the historical record of U.S. foreign policy with greater perspective and depth than their predecessors. They established formal editorial principles for FRUS that endured.

<!-- section-id: national-security -->

**The National Security Turn (1945–1970s)**

The Cold War transformed FRUS. As more decision-makers outside the Department of State left their imprint on foreign policy and diplomacy, FRUS historians increasingly needed to complement State Department records with documents drawn from other agencies’ files - especially presidential records. At the same time, United States expanded and intensified its engagement around the world. The perceived stakes of disclosure in FRUS grew. In the 1957, the Department established a Historical Advisory Committee of outside academic experts to provide editorial advice about how to balance timeliness and comprehensiveness and to vouch for the integrity of published volumes. Over the following decades, FRUS historians and advisory committee experts maintained that balance and the series served as the Department of State’s transparency engine. 

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

> ✎ **Your 2026-09-21 edits to this page — not yet in the app.** The page above shows what the app displays. To adopt an edit, paste it over the paragraph of the same section above.

**✎ Page title**

```text
165 Years of Documenting U.S. Foreign Policy
```

---

### 3.3 Page 3 — Understanding What You're Reading

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: understanding-documents | lines: 800–849 -->

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

When a source note records classification markings — “Secret; Nodis”, or explicitly “No classification marking” — the app separates them from the archival citation and shows them as a small chip beside the source note in the reading view, in Source Explorer, and on search results. The markings describe how the original record was handled at the time; the published text has been declassified.

The app also ships a corpus-wide authority of the archival collections FRUS cites: from Source Explorer you can open any matched collection to see its variant citation forms, its National Archives catalog record, every volume across the series that cites it, and how many documents in your own indexed volumes came from it.

<!-- section-id: classifications -->

**Excisions**

Most FRUS documents are published in full, but there are many that were published with excisions. Some of these excisions were editorial - the historians who compiled the volume judged that the excised material wasn’t significant enough to warrant inclusion. Other excisions were made for policy considerations - government officials judged that information could not be released without unacceptable risks to U.S. interests or security.

Before the 1920s, FRUS editors did not annotate excisions. Beginning in the 1920s, FRUS historians added ellipses (...) to indicate that material was omitted, but did not describe how much information was withheld or explain whether an excision was editorial in nature or an unfavorable declassification decision. The 1991 statutory mandate required more detailed editorial accounting for excised material, giving researchers a greater sense of how what is published compares to what had to be withheld.

<!-- section-id: omissions -->

**What FRUS Leaves Out**

FRUS publishes thousands of documents for every administration’s foreign policy, but it is just the tip of the iceberg for the entire historical record. Early volumes documented the implementation of foreign policy in the diplomacy conducted by the Department of State, but not the deliberative processes that set the course for U.S. foreign policy in Washington. Later volumes focused more and more on filling this gap by editorial prioritization of the decision-making process and inclusion of more and more records from beyond the State Department. This reversal of editorial focus means that the vast majority of diplomatic records that illustrate how foreign policy was implemented at U.S. embassies throughout the world are underrepresented in recent volumes compared to earlier ones.

<!-- END SOURCE: page understanding-documents -->

---

### 3.4 Page 4 — Using FRUS for Research

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: research-practices | lines: 855–909 -->

**Title:** Using FRUS for Research

**Subtitle:** Strategies for getting the most from the volumes

<!-- section-id: intro -->

FRUS rewards researchers who read across documents, not just within them, and who squeeze valuable information about both historical and archival context from the editorial annotation added to documents. Here are strategies that experienced historians have used with printed and online volumes (later pages will address how this app builds on these tried-and-true methods).

<!-- section-id: introduction -->

**Read the Front Matter**

Every FRUS volume opens with a substantial editorial introduction that explains the volume’s scope, the sources available (and unavailable), major gaps in the record, and key themes. Reading this Front Matter takes minutes but saves hours of confusion.

<!-- section-id: dates -->

**Use Date Ranges Pragmatically**

If your research topic is topical or thematic, you may find that queries across the entire FRUS corpus yield an unmanageably large number of search results. It can seem impossible to wade through page after page of hits. Date filtering lets you focus on reasonable slices of time. You can zero in on a particularly relevant time period or define more manageable chunks for a comprehensive review of results.

<!-- section-id: editorial -->

**Editorial Notes as a Finding Aid**

When an editorial note summarizes a meeting or document rather than reproducing it, that’s a research signal, not a dead end. The note includes archival citations to the underlying documentation. You can use the document-level Source Explorer or the free-text NARA Lookup tool to find the relevant finding aids and track down the relevant original records at NARA.

<!-- section-id: cross-volume -->

**Cross Volume Boundaries**

The focus and scope of individual FRUS volumes embody decisions about how to slice a complex record. A decision made in a document on one page of a Latin America volume might have been shaped by simultaneous conversations documented in a Foreign Economic Policy volume. Searching, following cross-references, and building collections across subseries and time periods often reveals policy coherence (or contradiction) that single-volume reading misses.

<!-- section-id: archival-road-map -->

**Think of FRUS as a Map of the Archives**

Recent FRUS volumes can serve as a map of U.S. government agency archives in three ways. First, it publishes transcriptions of the most critical historical records that document the foreign policy decision-making process and key diplomatic meetings, making them directly available to researchers. Second, the source notes for the documents selected for publication tell researchers the archival collections they came from, pointing them toward other useful files. Third, the note on sources in volume front matter identifies the broad range of archival repositories and collections that FRUS historians consulted to identify candidate documents for selection and publication. The most sophisticated users of FRUS rely on the series not only for the records it delivers directly, but also for the documentary trail it offers to a wider and richer range of U.S. Government sources.

<!-- section-id: omissions -->

**Don’t Forget What You’re Not Reading**

FRUS tells the U.S. side of the history of foreign relations. The counterpart cable from a foreign ministry, the intelligence report shaping the other side’s expectations and strategies, the domestic political pressures driving a foreign leader — these are absent. FRUS is indispensable for illuminating the thinking and actions of U.S. policymakers. As valuable as that often is, international history is an interactive story that requires understanding events from multiple perspectives to truly master. For many types of questions, researchers should treat FRUS as an entry point to a historical or policy question, not its answer.

<!-- END SOURCE: page research-practices -->

> ✎ **Your 2026-09-21 edits to this page — not yet in the app.** The page above shows what the app displays. To adopt an edit, paste it over the paragraph of the same section above.

**✎ Section `archival-road-map` — Think of FRUS as a Map of the Archives**

```text
Recent FRUS volumes can serve as a map of U.S. government agency archives in three ways. First, it publishes transcriptions of the most critical historical records that document the foreign policy decision-making process and key diplomatic meetings, making them directly available to researchers. Second, the source notes for the documents selected for publication tell researchers the archival collections they came from, pointing them toward other useful files. Third, the note on sources in volume front matter identifies the broad range of archival repositories and collections that FRUS historians consulted to identify candidate documents for selection and publication. Experienced users of FRUS rely on the series not only for the records it delivers directly, but also for the documentary trail it offers to a wider and richer range of U.S. Government sources.
```

### 3.5 Page 5 — Finding What You Need in FRUS Explorer

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: finding-documents | lines: 917–959 -->

**Title:** Finding What You Need in FRUS Explorer

**Subtitle:** What you can start from, and what you can narrow to

<!-- section-id: starting-points -->

**Start From Whatever You Have**

FRUS Explorer is designed to help you find what you need in the series, regardless of whether your starting point is a natural language question, a phrase you half-remember, a citation that caught your eye in someone’s footnote, a name that keeps appearing, a fateful date, a broad subject, or one good document. Each of those leads somewhere in this app. The full text of every volume you have downloaded and indexed is searchable at once. A citation resolves to the document it names. Many people can be followed through everything that mentions them. Any span of days can be laid out in order, as they unfolded. The topic index reaches subjects spread too thinly to find easily any other way. And one document you trust can lead you to the documents most connected to it — by shared archival file, citation, date, the editors’ own arrangement, shared people and topics, or, if you choose to turn it on, an AI model’s reading of the entire series for meaning.

<!-- section-id: narrowing -->

**Narrow Without Losing Count**

Whatever a search returns, you can see its shape before you read a page of it: how the matches spread across years, volumes, people, document types, archival provenance and subjects. Most of those become a filter with one click or tap, and the subjects facet narrows a result set to a single topic area; archival provenance is the exception — it is descriptive only, because the search has no provenance filter to narrow to, and the panel says so where it is shown. When a set of volumes is the thing you keep coming back to — a crisis, a region, an administration — you can name it once and reuse it everywhere the series can be sliced. When the thing you care about is covered in a particular set of documents, you can freeze them into a working corpus and run every later search inside it. The app keeps track of these scopes so you can replicate and document your research method.

<!-- section-id: honest-arithmetic -->

**Search That Shows Its Arithmetic**

The app treats counts against the series as a whole as evidence, and holds itself to that standard. The Query Inspector shows how the app translated what you typed into the keyword search box into the query that actually ran under the hood. This can be especially important when your results are surprising. For example, an unexpectedly large count may be related to how the app sweeps variants of your terms into searches by default. Capped results are reported as floors, never as totals, and the app offers tools to visualize matches it cannot list. And wherever a figure could describe either the whole series or only your indexed volumes, the app says which one it is counting.

<!-- section-id: whole-series -->

**The Whole Series, Not Just Your Library**

Finding does not wait for downloading. Semantic similarity, subjects, people, series-wide figures, and every volume’s place in the corpus are all visible before you add any volume to your device. Discovery can run ahead of your library and tell you which volumes are worth adding to it. What needs the text itself — full-text search, reading documents, analysis of the words — works over what you have indexed, and the app is plain about that boundary rather than letting a small library masquerade as the series.

<!-- section-id: manual -->

**Where the Controls Are**

To delve into the details about search screens, filters, and syntax, visit the User Manual — linked from the About screen. It will walk you through how the app delivers these capabilities.

<!-- END SOURCE: page finding-documents -->

> ✎ **Your 2026-09-21 edits to this page — not yet in the app.** The page above shows what the app displays. To adopt an edit, paste it over the paragraph of the same section above.

**✎ Section `starting-points` — Start From Whatever You Have**

```text
FRUS Explorer is designed to help you find what you need in the series, regardless of whether you start from a natural language question, a quoted passage, a citation, a date, a broad subject, or one good document. Each of those leads somewhere in this app. The full text of every volume you’ve downloaded and indexed is searchable at once. Citations lead to the documents they identify. People tagged by FRUS editors can be followed everywhere else they’ve been tagged. Documents that fell within any span of days can be laid out in order and visualized, allowing you to ignore volume boundaries to watch how events unfolded. The topic index points toward subjects spread too thinly to find easily any other way. And one document you trust can lead you to the documents most connected to it — by shared archival file, citation, date, the editors’ own arrangement, shared people and topics, or, if you choose to turn it on, an AI model’s reading of the entire series for natural-language meaning.
```

**✎ Section `narrowing` — Narrow Without Losing Count**

```text
Whatever a search returns, you can use facets to break down the results: how the matches spread across years, volumes, people, document types, archival provenance and subjects. Most of those become a filter with one click or tap, and the subjects facet narrows a result set to a single topic area. When a set of volumes is the thing you keep coming back to — a crisis, a region, an administration — you can name it once and reuse it everywhere the app lets users choose scopes. When the thing you care about is covered in a particular set of documents, you can freeze them into a working corpus and run every later search inside it. The app keeps track of these scopes so you can replicate and document your research method.
```

*The text above is your rewrite plus the clause #1418 restored — “and the subjects facet narrows a result set to a single topic area”. `ResearchGuideCoverageTests` requires “subjects facet” or “topic area” in the guide, so keep one of them (and `CorrectedClaimsTests` line 150 requires that whole clause word for word). As written it fails `CorrectedClaimsTests.educationDoesNotClaimProvenanceNarrows` at line 147: it drops the phrase “archival provenance is the exception — it is descriptive only”, leaving “Most of those become a filter with one click or tap” unqualified over a list that includes archival provenance, which has no filter. The clause #1418 kept is still open for you to confirm or reverse.*

**✎ Section `honest-arithmetic` — Search That Shows Its Arithmetic**

```text
The app treats counts against the series as a whole as evidence for factual and interpretive claims, and holds itself to that standard. The Query Inspector shows how the app translated what you typed into the keyword search box into the query that actually ran under the hood. This can be especially important when your results are surprising. For example, an unexpectedly large count may be related to how the app sweeps variants of your terms into stemmed searches by default. Capped results are reported as floors, never as totals, and the app offers tools to visualize matches it cannot list. Wherever a figure could describe either the whole series or only your indexed subset of volumes, the app says which one it is counting.
```

**✎ Section `whole-series` — The Whole Series, Not Just Your Library**

```text
Finding does not wait for downloading. Semantic similarity, subjects, series-wide figures, and every volume’s place in the corpus are all visible before you add any volume to your device. These bundled data sources allow discovery to run ahead of your library and offer insight into which volumes are worth adding to it. Features and functionality that need the text itself — full-text search, reading documents, analysis of the words — work over only what you have indexed.
```

---

### 3.6 Page 6 — Seeing the Bigger Picture in FRUS Explorer

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: corpus-analysis | lines: 963–1012 -->

**Title:** Seeing the Bigger Picture in FRUS Explorer

**Subtitle:** Questions you can put to the series as a whole

<!-- section-id: over-time -->

**Change Over Time**

You can watch the record move. Any term or phrase can be charted across the series’ thirteen decades to see when it enters the record, when it surges, and which volumes carry it — as raw counts, or as a share of each period’s documents so a term does not look like it is surging just because the series grew. Any stretch of days can be reconstructed in sequence. And any set of documents you assemble — a search’s results, a collection — can be read as a timeline, so its gaps and concentrations show at a glance.

<!-- section-id: language -->

**The Language Itself**

You can ask what any slice of the corpus sounds like — a document, a volume, a decade, a working corpus — and get more than a list of frequent words: the words most distinctive of that slice compared with the whole series, what other terms occur frequently with your own search term (its collocates), and every occurrence of a term lined up as a concordance, so a page of hits can be sorted by the term’s immediate context and not just skimmed as a list. A semantic map places every document in the series on one screen beside others that an AI model assessed as similar, whether or not they share a volume, a date, or a citation.

<!-- section-id: people -->

**The People**

You can ask who the published record foregrounds: the most-mentioned figures of an era, one person’s presence traced year by year, two careers compared, pairs tracked together, and the network of who is named alongside whom. These readings reach the volumes whose editors tagged people during production — the more recent ones — and the app tells you so rather than letting an editorial gap read as a historical absence.

<!-- section-id: citation-web -->

**The Web the Editors Drew**

FRUS editors stitched the series together with cross-references between printed documents and out to archival records. In FRUS Explorer, you can read that stitching at both scales: one document’s neighborhood as a graph — what informed it, what it fed into, including the archival material its footnotes cite but the series never printed — and the whole citation web as an aggregated network, with its most-cited landmarks and the volumes that lean on each other. These are measures of how the editors linked documents, not a ranking of historical importance.

<!-- section-id: archival-signal -->

**Where the Documents Came From**

Every published document names the archival file its original was found in, and clustered across the series those source notes answer a question no volume states outright: which bodies of records each era’s editors actually worked in. Archival analytics offers source rankings, co-citation networks, and flows between archival units, era by era. Use this feature to see how FRUS highlights connections between discrete archival collections and repositories or scout out specific collections or central file classifications of interest from what FRUS prints from and about them.

<!-- section-id: finding-aid -->

**Honest Evidence**

FRUS is a selective, evolving proxy for the archival record. To learn more about the app’s analytics features, see the User Manual — linked from the About screen — for the full tour.

<!-- END SOURCE: page corpus-analysis -->

> ✎ **Your 2026-09-21 edits to this page — not yet in the app.** The page above shows what the app displays. To adopt an edit, paste it over the paragraph of the same section above.

**✎ Section `over-time` — Change Over Time**

```text
You can watch the record move. Any term or phrase can be charted across the series’ thirteen decades to see when it enters FRUS’s record, when usage explodes in FRUS documents, and which volumes carry it — as raw counts, or as a share of each period’s documents so a term does not look like it is surging just because the series grew. Any stretch of days can be reconstructed in sequence. And any set of documents you assemble — a search’s results, a collection — can be read as a timeline, so its gaps and concentrations show at a glance.
```

**✎ Section `language` — The Language Itself**

```text
You can ask what words any slice of the corpus uses — a document, a volume, a decade, a working corpus — and get more than a list of frequent terms: the words most distinctive of that slice compared with the whole series, what other terms occur frequently with your own search term (its collocates), and every occurrence of a term lined up as a concordance, so a page of hits can be sorted by the term’s immediate context and not just skimmed as a list. A semantic map places every document in the series on one screen beside others that an AI model assessed as similar, whether or not they share a volume, a date, or a citation.
```

**✎ Section `people` — The People**

```text
You can ask who the published record foregrounds: the most-mentioned figures of an era, one person’s presence traced year by year, two careers compared, pairs tracked together, and the network of who is named alongside whom. These features only reach more recent volumes whose editors tagged people during production.
```

**✎ Section `citation-web` — The Web the Editors Drew**

```text
FRUS editors stitched the series together with cross-references between printed documents and out to archival records. In FRUS Explorer, you can read that stitching at both scales: one document’s neighborhood as a graph — what other records informed it, what records it fed into, including archival material cited in its footnotes but not printed in the series — and the whole citation web as an aggregated network, with its most-cited landmarks and the volumes that lean on each other most. These are measures of how the editors linked documents, not a ranking of historical importance.
```

**✎ Section `archival-signal` — Where the Documents Came From**

```text
The app attempts to name the archival file every FRUS document’s original manuscript copy was found in. Once analyzed at scale, FRUS source notes and footnotes offer powerful insights into the archival records each era’s editors actually worked in. Archival analytics offers source rankings, co-citation networks, and flows between archival units, era by era. Use this feature to see how FRUS highlights connections between discrete archival collections and repositories or use FRUS to scout out specific collections or central file classifications of interest.
```

---

### 3.7 Page 7 — Working With Documents in FRUS Explorer

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: working-with-documents | lines: 1016–1065 -->

**Title:** Working With Documents in FRUS Explorer

**Subtitle:** Reading, annotating, organizing, and exporting

<!-- section-id: reading -->

**The Text, As Published**

The document you read is the document the volume printed: its structure, its datelines, its style, its footnotes in place, with the people it names linked to the volume’s own glossary. Reading stays clean until you ask for more — your notes, tags, and summaries sit in a rail you open when you want them and close when you don’t.

<!-- section-id: your-apparatus -->

**Your Own Layer on the Record**

Everything you add — highlights, notes, tags, the projects that keep separate research threads distinct — is maintained as a distinct, private layer, kept apart from the published text and never blended into it. It follows you across your devices, and it stays private: the app shares nothing about your research with anyone, and everything you make can be exported so you can use it elsewhere.

<!-- section-id: outputs -->

**From Reading List to Finished Output**

A set of documents can become a shaped thing: a teaching reader, a briefing packet, a source dossier — ordered, sectioned, curated in your own words, annotated, and exported in forms other people can actually use, from print-ready files to a working set that a colleague opens in their own FRUS Explorer. Every document carries a citation in the series’ own style, ready for your footnotes or your reference manager. And where on-device AI is available it can draft summaries for you that are always labeled as generated, never passed off as part of the record or as your own reading.

<!-- section-id: integrity -->

**Claims That Survive Checking**

The app is built so that what you publish from it as a collection can be checked. Every quotation you freeze into a collection is re-verified against the text of the document it cites before export — presentation is forgiven, wording is not, and a paraphrase does not pass. Your searches can be exported as a method appendix: the query log records each query with its scope, its date, and how many volumes were indexed at the time. History isn’t science, but searches against a shared, trusted source like FRUS can and should provide reproducible results.

<!-- section-id: beyond -->

**When the Trail Leaves the Series**

When you are ready to follow source notes or footnotes past the published series to the shelves at College Park or a presidential library, FRUS Explorer can help you plan research visits. By selecting documents, you can seed and triage a research plan and prepare for a visit. The app’s research trip packet resolves selected documents’ source notes and/or outward-pointing footnotes against National Archives data to flag access-restriction warnings for still-classified collections, help you draft advance inquiries to an archivist, and gather the collection-level information about records that NARA asks you to provide when you’re ready to request them.

<!-- section-id: manual -->

**Where the Controls Are**

To learn more about what FRUS Explorer lets you do with documents, see the User Manual — linked from the About screen.

<!-- END SOURCE: page working-with-documents -->

> ✎ **Your 2026-09-21 edits to this page — not yet in the app.** The page above shows what the app displays. To adopt an edit, paste it over the paragraph of the same section above.

**✎ Section `reading` — The Text, As Published**

```text
Reading stays clean, with documents presented as described by their editorial annotation and TEI tagging, until you ask for more. Your notes, tags, and summaries sit in a Research rail you open when you want and close when you don’t.
```

**✎ Section `your-apparatus` — Your Own Layer on the Record**

```text
Everything you add — highlights, notes, tags, the projects that keep separate research threads distinct — is maintained as a private layer, distinct from the published text. Your research and annotation data follows you across your devices, and it stays private: the app shares nothing about your research with anyone, and everything you make can be exported so you can use it elsewhere.
```

**✎ Section `outputs` — From Reading List to Finished Output**

```text
You can turn a set of documents you select into a curated collection: a teaching reader, a briefing packet, a source dossier — ordered, sectioned, annotated, and exported in forms other people can actually use, from print-ready files to a handoff that a colleague can open in their own copy of FRUS Explorer. Every document carries a citation in the series’ own style, ready for your footnotes or your reference manager. And, if on-device AI is available, the app can produce draft summaries for you that are always labeled as generated, never passed off as part of the record or as your interpretation.
```

**✎ Section `integrity` — Claims That Survive Checking**

```text
The app provides verifiable outputs. Every quotation you freeze into a collection is re-verified against the text of the document it cites before export. The searches you used to locate the documents you selected can be exported as a method appendix: the query log records each query with its scope, its date, and how many volumes were indexed at the time. History isn’t science, but searches against a shared, trusted source like FRUS can and should provide reproducible results.
```

**✎ Section `beyond` — When the Trail Leaves the Series**

```text
When you are ready to follow source notes or footnotes to repositories like the National Archives at College Park or a presidential library, FRUS Explorer can help you plan research visits. By selecting documents, you can seed and triage a research plan and prepare for a visit. The app builds research trip packets by resolving selected documents’ source notes and/or outward-pointing footnotes against National Archives data to flag access-restriction warnings for still-classified collections, help you draft essential advance inquiries to an archivist, and gather the collection-level information about records that you’ll need to fill out pull slips once you arrive for research.
```

---

### 3.8 Page 8 — Production & Timeliness *(live dashboard — no editable page prose)*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-production | lines: 1077–1086 | note: dashboard page, sections: [] -->

This page renders the live **Production & Timeliness** dashboard (`EducationDashboard.seriesProduction`) instead of prose, so it has no editable page-level sections. Its page **title** (“Production & Timeliness”) and **subtitle** (“How long the official record takes to reach print”) are localized in code at the lines above (`education.series.production.page.title` / `.subtitle`).

The dashboard’s own on-screen copy — the intro paragraph, per-chart captions, and the “About these figures” caveats — lives in **`FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.production.intro`
- Chart titles/captions: `series.chart.lag.title` / `.caption`, `series.chart.lag.target.series`, `series.chart.peryear.title` / `.caption`, `series.chart.cumulative.title` / `.caption`; axis labels `series.chart.*.x` / `.y`; era legend `series.chart.era.legend`
- Caveats block: `series.caveats.title` / `series.caveats.body.v2 %lld`
- Shared “View as table” control: `series.inspector.viewTable`
- Empty state: `series.empty.title` / `series.empty.message`

<!-- END SOURCE: page series-production -->

---

### 3.9 Page 9 — Geographic Emphasis *(live dashboard — no editable page prose)*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-geography | lines: 1098–1107 | note: dashboard page, sections: [] -->

This page renders the live **Geographic Emphasis** dashboard (`EducationDashboard.seriesGeography`) instead of prose, so it has no editable page-level sections. Its page **title** (“Geographic Emphasis”) and **subtitle** (“Which regions and countries the series covers most”) are localized in code at the lines above (`education.series.geography.page.title` / `.subtitle`).

The dashboard’s own on-screen copy lives in **`FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.geography.intro`
- Chart titles/captions: `series.geography.trend.title` / `.caption`, `series.geography.totals.title` / `.caption`, `series.geography.countries.title` / `.caption`; axis labels `series.geography.*.x` / `.y`; region legend `series.geography.region.legend`
- Caveats block: `series.geography.caveats.title` / `series.geography.caveats.body.v2 %lld %lld`
- Shared “View as table” control: `series.inspector.viewTable`
- Empty state: `series.geography.empty.title` / `series.geography.empty.message`

<!-- END SOURCE: page series-geography -->

---

### 3.10 Page 10 — Archival Sourcing *(live dashboard — no editable page prose)*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-sourcing | lines: 1119–1128 | note: dashboard page, sections: [] -->

This page renders the live **Archival Sourcing** dashboard (`EducationDashboard.seriesSourcing`) instead of prose, so it has no editable page-level sections. Its page **title** (“Archival Sourcing”) and **subtitle** (“Where the series drew its documents from, over time”) are localized in code at the lines above (`education.series.sourcing.page.title` / `.subtitle`).

The dashboard’s own on-screen copy lives in **`FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.provenance.intro`
- Chart titles/captions: `series.provenance.composition.title` / `.caption`, `series.provenance.trend.title` / `.caption`, `series.provenance.density.title` / `.caption`; axis labels `series.provenance.*.x` / `.y`; category legend `series.provenance.category.legend`
- Caveats block: `series.provenance.caveats.title` / `series.provenance.caveats.body.v2 %lld %lld`
- Shared “View as table” control: `series.inspector.viewTable`
- Empty state: `series.provenance.empty.title` / `series.provenance.empty.message`

<!-- END SOURCE: page series-sourcing -->

---

### 3.11 Page 11 — Administration Profiles *(live dashboard — no editable page prose)*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-administrations | lines: 1140–1149 | note: dashboard page, sections: [] -->

This page renders the live **Administration Profiles** dashboard (`EducationDashboard.administrationProfiles`) instead of prose, so it has no editable page-level sections. Its page **title** (“Administration Profiles”) and **subtitle** (“How the series’ coverage is distributed across presidencies”) are localized in code at the lines above (`education.series.administrations.page.title` / `.subtitle`).

The dashboard’s own on-screen copy lives in **`FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.admin.intro`
- Chart titles/captions: `series.admin.docs.title` / `.caption`, `series.admin.perYear.title` / `.caption`, `series.admin.volumes.header` / `series.admin.volumes.caption`; axis labels `series.admin.*.x` / `.y`; party legend `series.admin.party.legend`; per-administration detail `series.admin.detail.title` / `series.admin.detail.picker`
- Editorial-note (range-document) toggle: `series.admin.toggle.title` / `series.admin.toggle.subtitle`
- Caveats block: `series.admin.caveats.title` / `series.admin.caveats.body.v2 %lld`
- Shared “View as table” control: `series.inspector.viewTable`
- Empty state: `series.admin.empty.title` / `series.admin.empty.message`

<!-- END SOURCE: page series-administrations -->

---
