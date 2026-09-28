# FRUS Explorer — Editable Static Content

> ⚠️ **SUPERSEDED SNAPSHOT — do not edit, and do not port anything from here.**
> This is the state of the editable mirror on **2026-08-02**, kept as the record of the owner
> editorial pass merged in #655. The live mirror is **`Docs/EditableContent.md`**, which has since
> been rewritten repeatedly — most consequentially by #1078, which recast the Research Guide's
> pages 5–7 as task contracts and ran an en-US spelling sweep. The British spellings still in this
> file are therefore *correct as history* and are deliberately left alone. Editing this file has no
> effect on the app: revisions are mapped back to source by key from the live mirror only.

This file contains the user-facing editorial prose across FRUS Explorer: the About screen,
the onboarding welcome, the in-app FRUS Research Guide, the Series-analytics dashboards, the
analytics info popovers and captions, and the explanatory footers in Settings. Edit the text
directly. When you are done, hand the file back and the changes will be written to the source code.

**Regenerated from source: 2026-07-26 (build 36).** Blocks in §1–§6 reflect the code as of that
date unless a later amendment is noted below.

**Amended 2026-08-01 (#597 PR 2):** seven new Research Guide sections covering the Query &
Corpus Analysis wave were added by hand to §3 — `query-inspector`, `result-facets`,
`working-corpora` (page 5), `reading-results`, `keyness` (page 7) and `method-appendix` (page 7).

**Amended 2026-08-02 (build 37 docs pass):** three additions and three corrections.
 - **New §7** carries the search and result-set copy from the Query & Corpus Analysis wave — the
   query inspector, facets, concordance, collocation, working corpora, the ceiling notices and the
   method appendix. That material is not "analytics captions" and not "settings", which is why it
   has its own section rather than being folded into §5 or §6.
 - **§6's Discovery Tips block is rewritten.** It carried one tip that no longer exists and was
   missing four that do. All six tips now appear with **both** their title and their message.
 - **New §8** carries the repository README, which is public-facing prose and was not previously
   round-trippable here.
 - Three stale blocks corrected: the Research Guide's `related-documents` text (the fourth signal
   is now *corpus proximity*, and chips no longer show a percentage for two of the five), the
   `citations` text (**Settings → Connections**, not the retired Settings → Connections), and the `ai`
   text (bulk summarization now states its real duration and reports parts).

**A note on the `lines:` field.** It is advisory and it rots — a third of the annotations had
drifted within five weeks of the last regeneration, some by several hundred lines. **`key:` is the
real address.** If a `lines:` range and a `key:` disagree, the key wins; do not use the line numbers
to navigate.

**How annotations work:** Each editable block is preceded by an HTML comment that
identifies the exact source location. Do not remove or alter the annotation comments —
they are how your revisions get mapped back to code. You can edit anything between
the comments freely, including adding or removing paragraphs, restructuring bullet
lists, and changing headings.

---

## 1. About Screen

*Displayed in the About screen — reached from Settings on iOS/iPadOS, and from the app menu ("About FRUS Explorer", a dedicated window) on macOS.*

---

### 1.1 FRUS Series Description

*This is Markdown source — the series name renders bold. Keep the `**text**` emphasis intact.*

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: frusDescriptionRaw | lines: 243–257 | key: about.frus.description -->

The **Foreign Relations of the United States** (FRUS) series is the official documentary record of U.S. foreign policy. The Department of State has published FRUS continuously since 1861. The series now comprises more than 550 volumes covering U.S. foreign policy from 1861 through the early 1990s.

While the content of the series has shifted over time, recent FRUS volumes cover U.S. bilateral and regional relations across the globe; U.S. policymakers' responses to unfolding crises; engagement with global issues like human rights, terrorism, narcotics, health, and the environment; and thematic topics including national security policy, foreign economic policy, and foreign affairs organization and management. It is an invaluable resource for scholars, policymakers, and citizens seeking to understand the origins of contemporary challenges and the United States's role in the world.

<!-- END SOURCE: about.frus.description -->

---

### 1.2 Attribution

*The three text fragments below are assembled into a single sentence in code.*

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: attributionText | lines: 437–438 | keys: about.attribution.prefix, about.attribution.claude, about.attribution.suffix -->

**Prefix:** The code for FRUS Explorer was generated by

**Linked word:** Claude *(links to claude.ai — do not change this word)*

**Suffix:** , an AI assistant made by Anthropic, at the direction of Joshua Botts. Josh thanks his colleagues for the inspiration, feature ideas, feedback, and enthusiasm they contributed to the app.

<!-- END SOURCE: about.attribution -->

---

### 1.3 Open Source — FRUS Explorer License Notice

*Shown first in the Open Source section, under the bold "FRUS Explorer" label; the row links to the GitHub repository.*

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: openSourceSection | lines: 507–508 | key: about.openSource.appLicense.body -->

Licensed under the Apache License, Version 2.0. View source and contribute on GitHub.

<!-- END SOURCE: about.openSource.appLicense.body -->

---

### 1.4 Open Source — TEI Publisher Notice

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: openSourceSection | lines: 533–534 | key: about.openSource.teiPublisher.body -->

TEI rendering approaches informed by the TEI Publisher project (teipublisher.com). Licensed under the Apache License, Version 2.0.

<!-- END SOURCE: about.openSource.teiPublisher.body -->

---

### 1.5 NARA Disclaimer

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: naraDisclaimerSection | lines: 556–557 | key: about.nara.disclaimer -->

FRUS Explorer is not affiliated with, endorsed by, or sponsored by the National Archives and Records Administration (NARA). NARA Catalog data accessed through this app is provided by the National Archives and is subject to their terms of use.

<!-- END SOURCE: about.nara.disclaimer -->

---

### 1.6 DOS Disclaimer

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: dosDisclaimerSection | lines: 593–594 | key: about.dos.disclaimer -->

FRUS Explorer is an independently-developed research tool and is not an official product of the Office of the Historian or the U.S. Department of State. Commentary, advice, and guidance about the FRUS series contained in the application reflect personal views and not necessarily those of the Department of State or the U.S. Government. The FRUS series itself is a public domain resource.

<!-- END SOURCE: about.dos.disclaimer -->

---

## 2. Onboarding Welcome Screen

*Displayed on first launch — the Welcome step before the user chooses what to download.*

---

### 2.1 Onboarding copy (all three steps)

> **Rewritten 2026-07-27 (Workstream O, O-4).** The flow now floats in one docked glass
> panel over an animated word cloud, and every string below is a real
> `String(localized:)` key — before O-4 this view carried 14 raw `Text("…")` literals and
> not one localised string. The keys are listed so a translator or an editor can find them.
>
> The section previously documented `OnboardingIntroView.swift`, which never rendered; see
> §2.2 for what became of its body text.

<!-- SOURCE: FRUSExplorer/Onboarding/OnboardingView.swift | property: Copy | keys: onboarding.* -->

**Step 1 — Welcome**

- `onboarding.welcome.title` — **Welcome to FRUS Explorer**
- `onboarding.welcome.body` — The official documentary record of U.S. foreign policy since 1861 — searchable, cross-referenced, on your device.

**Step 2 — Add Volumes**

- `onboarding.scope.title` — What would you like to download?
- `onboarding.scope.segment.corpus.long` / `.short` — Entire Corpus · Corpus
- `onboarding.scope.segment.subseries.long` / `.short` — A Subseries · Subseries
- `onboarding.scope.segment.volume.long` / `.short` — A Single Volume · Volume

  *The long labels are macOS; iOS uses the short ones, because three full labels cannot
  share an iPhone's segment width without truncating.*

- `onboarding.scope.caption.corpus` — 552+ volumes · ≈ 3.3 GB — the entire series, fully offline.
- `onboarding.scope.caption.subseries` — A decade or diplomatic era — the recommended starting point.
- `onboarding.scope.caption.volume` — One volume to explore — typically a few MB.
- `onboarding.scope.sheet.volumeCount` — *N* volume / volumes

**Step 3 — Ready**

- `onboarding.ready.title` — **You're all set**
- `onboarding.ready.body` — Volumes download and index automatically — search unlocks in minutes. Your project “My Research” is ready.

**Shared** — `onboarding.action.back` (Back), `onboarding.action.skip` (Skip),
`onboarding.offline.banner` (You are offline. Showing bundled catalog only.).
"Get Started" / "Continue" / "Finish" come from `OnboardingStep.continueLabel`.

**Accessibility** — `onboarding.step.position` gives the page dots a spoken position
("Step 2 of 3: Scope"); `wordcloud.backdrop.chip.era` labels the backdrop's lens chip when
a volume's cloud falls back to its era's vocabulary.

<!-- END SOURCE: onboarding copy -->

---

### 2.2 Intro Body Text — *not currently displayed*

> **Also corrected 2026-07-26 (O-0).** `OnboardingIntroView` was the only view that ever
> rendered this text. With it deleted, `OnboardingViewModel.bundledIntroText` has no
> reader: the property is still compiled and still covered by `EmbeddedMarkdownLinkTests`
> (which checks its Markdown links parse), but **nothing in the app puts it on screen**.
> It is kept here rather than dropped because it is good, accurate prose about the series
> that a later session may want to rehome — the FRUS Research Guide (§3) is the obvious
> candidate. Editing it today has no visible effect.

*A single Markdown block stored in `OnboardingViewModel.bundledIntroText`; keep the `[text](url)` link syntax intact.*

<!-- SOURCE: FRUSExplorer/Onboarding/OnboardingViewModel.swift | property: bundledIntroText | lines: 239–249 -->

The Foreign Relations of the United States (FRUS) series is the official documentary record of U.S. foreign policy. The Department of State has published FRUS continuously since 1861. The series now comprises more than 550 volumes covering U.S. foreign policy from 1861 through the early 1990s.

Today, the Office of the Historian at the Department of State produces the series under a [1991 federal statute](https://uscode.house.gov/view.xhtml?req=%22foreign+relations+of+the+United+States%22+series&f=treesort&fq=true&num=2&hl=true&edition=prelim&granuleId=USC-prelim-title22-section4351) that requires the series to provide a "thorough, accurate, and reliable documentary record of major United States foreign policy decisions and significant United States diplomatic activity." To fulfill this mandate, the historians who produce FRUS consult records from the White House, National Security Council, Departments of State and Defense, the CIA, other U.S. Government agencies, and sometimes even the private papers of key policymakers to identify the most critical documentation for editorial annotation, declassification, and publication.

The statute requires that this work be guided by historical objectivity: records may not be altered without acknowledgment, no fact of major importance in reaching a decision should be omitted, and information should not be withheld to conceal a defect in policy. Volumes should be published within 30 years of the events they document.

While the content of the series has shifted over time, recent FRUS volumes cover U.S. bilateral and regional relations across the globe; U.S. policymakers' responses to unfolding crises; engagement with global issues like human rights, terrorism, narcotics, health, and the environment; and thematic topics including national security policy, foreign economic policy, and foreign affairs organization and management. It is an invaluable resource for scholars, policymakers, and citizens seeking to understand the origins of contemporary challenges and the United States's role in the world.

FRUS Explorer provides a variety of research tools for using the series, which is freely available at [history.state.gov](https://history.state.gov/historicaldocuments/about-frus) and the [HistoryAtState](https://github.com/HistoryAtState/frus) GitHub repository.

<!-- END SOURCE: bundledIntroText -->

---

## 3. FRUS Research Guide (in-app education pages)

*`IndexingEducationView` — the in-app FRUS Research Guide. It has **eleven pages**: **seven prose pages** (pages 1–7) whose text is editable below, followed by **four live "About the Series" dashboard pages** that render interactive charts instead of prose. The guide is shown while the first index builds and is also reachable any time from the app (iOS Settings → FRUS Research Guide; macOS `frus.researchGuide` window).*

*The content model is a series of `EducationPage` and `EducationSection` structs. Structure per prose page: **Title**, optional **Subtitle**, then one or more **Sections**. Each section has an optional **Heading**, one or more **Paragraphs**, and an optional **Bullet list**.*

*The `id` values in the annotations (`page-id` / `section-id`) are the Swift `id` strings on the structs — they are used as update keys and must not be changed. Prose here uses raw Swift string literals in code (not localized), so edits map back verbatim.*

*The four dashboard pages (§3.8–§3.11) have **no editable page prose** (`sections: []`). Their on-screen copy — intro paragraph, per-chart captions, and caveats — lives in the dashboard view files as localized strings; those blocks list where to edit it. Do not add prose here for those pages.*

---

### 3.1 Page 1 — The Official Record of American Foreign Policy

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: what-frus-is | lines: 613–665 -->

**Title:** The Official Record of American Foreign Policy

**Subtitle:** Foreign Relations of the United States

<!-- section-id: intro -->

Foreign Relations of the United States — FRUS — is the official documentary history of major U.S. foreign policy decisions and significant diplomatic activity, published continuously by the Department of State since 1861. It is one of the longest-running publication programs of the U.S. government and an indispensable source for the history of American diplomacy.

<!-- section-id: mandate -->

**Congressionally-Mandated Historical Transparency**

Since 1991, FRUS is required by federal statute (Public Law 102-138, codified at [22 U.S.C. § 4351 et seq.](https://uscode.house.gov/view.xhtml?req=%22foreign+relations+of+the+United+States%22+series&f=treesort&fq=true&num=2&hl=true&edition=prelim&granuleId=USC-prelim-title22-section4351), amended 2021). The law establishes four binding commitments:

- The series must constitute "a thorough, accurate, and reliable documentary record of major United States foreign policy decisions and significant United States diplomatic activity. Volumes of this publication shall include all records needed to provide a comprehensive documentation of the major foreign policy decisions and actions of the United States Government, including the facts which contributed to the formulation of policies and records providing supporting and alternative views to the policy position ultimately adopted"
- Volumes must be published within 30 years of the events they document
- Government departments must grant historians full access to pertinent records at 20 years
- An Advisory Committee on Historical Diplomatic Documentation comprised of representatives of major scholarly organizations and experts chosen by the Department of State must oversee the production and declassification process to validate the historical objectivity of the series

<!-- section-id: ooh -->

**Prepared by the Department of State's Office of the Historian**

FRUS volumes are compiled and edited by professional historians in the Office of the Historian at the Department of State. Historians in the compilation and review team identify the most important documents, provide context through editorial notes and annotations, and review draft volume manuscripts to ensure they provide "thorough, accurate, and reliable" coverage of the assigned topic(s). Historians in the declassification, publishing, and digital initiatives team coordinate the complex and thorough interagency declassification review required before release and then the detailed preparation of the manuscript required for publication.

<!-- section-id: sources -->

**Breadth of Sources**

FRUS historians draw on still-classified records from the White House and National Security Council at Presidential Libraries as well as records from the Departments of State and Defense, the CIA, and other agencies, both at the National Archives and directly at those agencies. When needed, they also seek access to the private papers of key policymakers.

<!-- section-id: scope -->

**Scope**

FRUS volumes produced today cover U.S. bilateral and regional relations across the globe, including U.S. policymakers' responses to unfolding crises; their engagement with global issues like human rights, terrorism, narcotics, health, and the environment; and thematic topics including national security policy, foreign economic policy, and foreign affairs organization and management. The series currently spans from 1861 through the early 1990s, with volumes covering the Clinton administration still in production.

<!-- END SOURCE: page what-frus-is -->

---

### 3.2 Page 2 — 163 Years in Progress

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: corpus-evolution | lines: 666–726 -->

**Title:** 163 Years in Progress

**Subtitle:** How FRUS changed — and why it matters for research

<!-- section-id: origins -->

**Origins: Diplomatic Correspondence (1861–1920s)**

At its birth, FRUS was an instrument of public affairs and congressional relations. The series began during the Civil War as a compilation of official diplomatic correspondence — despatches from diplomatic posts, instructions to U.S. ministers overseas, and notes to and from foreign governments. The volumes documented the operations of the State Department. Coverage was often contemporaneous: volumes sometimes appeared within a year of events, prioritizing currency over comprehensiveness. Because the volumes were produced by the same clerks who administered the Department's day-to-day business, principles of selection and editing standards reflected operational rather than historical purposes. By the early 20th century, the series had evolved to became a valuable knowledge management tool by providing ready access to key policy and precedent references for officials within the Department and its overseas posts and growing stakeholder constituencies in civil society.

<!-- section-id: professionalization -->

**Professionalization in the Interwar Era (1924-1945)**

In the 1920s, the Department of State began recruiting professionally-trained historians to undertake the increasingly complex editorial work of producing FRUS. Because budget constraints in the early 1900s and operational considerations during World War I delayed publication throughout the previous two decades, those historians had an opportunity to select and edit the historical record of U.S. foreign policy with greater perspective and depth than their predecessors. They established formal editorial principles for FRUS that endured.

<!-- section-id: national-security -->

**The National Security Turn (1945–1970s)**

The Cold War transformed FRUS. As more decision-makers outside the Department of State left their imprint on foreign policy and diplomacy, FRUS historians increasingly needed to complement State Department records with documents drawn from other agencies' files - especially presidential records. At the same time, United States expanded and intensified its engagement around the world. The perceived stakes of disclosure in FRUS grew. In the 1957, the Department established a Historical Advisory Committee of outside academic experts to provide editorial advice about how to balance timeliness and comprehensiveness and to vouch for the integrity of published volumes. Over the following decades, FRUS historians and advisory committee experts maintained that balance and the series served as the Department of State's transparency engine. 

<!-- section-id: crisis -->

**Crisis and Reform (1978–1991)**

By the 1980s, the gap between what FRUS had always claimed to be and what it could actually deliver grew painfully apparent. Historians inside the Office of the Historian struggled to achieve direct access to key CIA records. Academic historians appointed to the Department-chartered Historical Advisory Committee faced tightening security restrictions that made it harder to judge whether information withheld during the declassification process was marginal or essential to the historical integrity of publishable volumes. In 1989 and 1990, academic criticism of a volume documenting U.S. policy toward Iran in the early 1950s without any references to widely-known covert action attracted congressional scrutiny of the State Department's management of the series and its relationship with the advisory committee. In 1991, Congress intervened by establishing statutory mandates for long-standing norms: the mission of the series, the obligations of U.S. Government agencies to provide access to their historical records to the historians producing FRUS, and an advisory committee of academic historians to provide oversight to validate the historical integrity of the series.

<!-- section-id: contemporary -->

**The Contemporary Series (1991–Present)**

Post-1991 volumes reflect the statute's empowerment of FRUS historians with broader sourcing, fuller coverage of intelligence activities, and more detailed acknowledgment of omissions. Even as some volumes are delayed by interagency declassification disagreements, the 30-year rule creates a rolling horizon; volumes covering the Reagan administration are now publishing, with the Bush 41 and Clinton eras in active production.

<!-- section-id: digital -->

**The Digital Transition**

The Office of the Historian's shift to XML-encoded TEI files and digital publication in the 21st century has transformed how FRUS can be read and searched. All 552 volumes are now available as structured digital texts — the foundation for everything this app does. The TEI format preserves document structure (headings, datelines, footnotes, person references) in a form that makes programmatic analysis possible in ways printed volumes never allowed.

<!-- section-id: frus-history -->

To dive deeper into the history of the series, see the Office of the Historian's [official history](https://history.state.gov/historicaldocuments/frus-history) of FRUS.

<!-- END SOURCE: page corpus-evolution -->

---

### 3.3 Page 3 — Understanding What You're Reading

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: understanding-documents | lines: 727–789 -->

**Title:** Understanding What You're Reading

**Subtitle:** Documents, citations, and the archival record

<!-- section-id: two-registers -->

Every FRUS document is a transcribed and edited representation of an original, archival record. Understanding editorial annotation will help you make full use of FRUS.

<!-- section-id: types -->

**Primary Documents, Editorial Notes, and Front Matter**

FRUS is a documentary history, which means it uses actual historical documents to tell the story of U.S. foreign policy. The historians who compile the volumes carefully select records that best document past decisions, diplomacy, and events. They also provide editorial annotation that adds more context and information from the archives than the documents themselves contain.

Primary documents are the actual historical records that were produced contemporaneously with the events they describe — cables, memoranda, meeting notes, intelligence assessments, letters. These are reproduced in FRUS (sometimes with excisions) from government files. Starting in the early 20th century, each document was published with a source note identifying its provenance, or where the original was found. Many documents also contain footnotes providing information about the historical context around the document or even offering specific archival citations to other documents, meetings, or events that are referenced in the printed document.

Many volumes also contain editorial notes written by Office of the Historian historians. They appear as numbered entries in the document sequence and serve several purposes: summarizing developments the editors judged too voluminous or sensitive to reproduce in full, explaining gaps in the record, providing context for surrounding documents, and noting where fuller documentation exists. An editorial note that says "On [date], the NSC met to discuss…" is telling you something happened that isn't fully reproduced here. Editorial notes provide additional archival citations to unpublished documents.

Volume front matter has evolved over time. Recent volumes include valuable information about the editor's research methodology and a listing the archival sources they consulted as they selected documents for inclusion. They also contain annotated lists of people who generated, received, or were mentioned in the documents and terms and abbreviations used in the documents.

<!-- section-id: source-note -->

**Reading a Source Note**

Document source notes identify the archival provenance of the records published in FRUS. A source note for a document in the Reagan subseries might read:

"Source: National Archives, RG 59, Central Foreign Policy File, P840114–1808. Secret; Nodis."

This tells you: the original record was collected from the National Archives; it's in Record Group 59 (State Department records); it's part of the Central Foreign Policy File series; the reel identifier is P840114–1808; and it was classified Secret with a special handling caption.

One way this app helps researchers is by connecting archival citations detected in source notes directly to NARA's finding aids — so you can navigate from a FRUS document directly to the archive where the original record lives. Source notes are extracted for every era of the series, including the modern volumes whose notes are embedded in the document heading. This makes it easier than ever to follow the archival roadmap FRUS offers for deeper research.

When a source note records classification markings — "Secret; Nodis", or explicitly "No classification marking" — the app separates them from the archival citation and shows them as a small chip beside the source note in the reading view, in Source Explorer, and on search results. The markings describe how the original record was handled at the time; the published text has been declassified.

The app also ships a corpus-wide authority of the archival collections FRUS cites: from Source Explorer you can open any matched collection to see its variant citation forms, its National Archives catalog record, every volume across the series that cites it, and how many documents in your own indexed volumes came from it.

<!-- section-id: broken-references -->

**When a Cross-Reference Leads Nowhere**

The printed volumes cite each other constantly — "see page 700," "see Document 42." Because pre-digital volumes were retyped from the printed books and their cross-references retroactively tagged, a small number cite a page, document, or volume that does not exist in the digital corpus. The app ships a corpus-wide validation of every cross-reference (about 2.7 million checked), so it knows exactly which ones cannot be followed.

A confirmed-unresolvable reference appears in muted grey with a dotted underline and a small dagger instead of looking like a working link; tapping it explains why it can't be followed and what it apparently meant to point at. These references are also excluded from the cross-reference graph and analytics (the analytics caption discloses how many).

<!-- section-id: classifications -->

**Excisions**

Most FRUS documents are published in full, but there are many that were published with excisions. Some of these excisions were editorial - the historians who compiled the volume judged that the excised material wasn't significant enough to warrant inclusion. Other excisions were made for policy considerations - government officials judged that information could not be released without unacceptable risks to U.S. interests or security.

Before the 1920s, FRUS editors did not annotate excisions. Beginning in the 1920s, FRUS historians added ellipses (...) to indicate that material was omitted, but did not describe how much information was withheld or explain whether an excision was editorial in nature or an unfavorable declassification decision. The 1991 statutory mandate required more detailed editorial accounting for excised material, giving researchers a greater sense of how what is published compares to what had to be withheld.

<!-- section-id: omissions -->

**What FRUS Leaves Out**

FRUS publishes thousands of documents for every administration's foreign policy, but it is just the tip of the iceberg for the entire historical record. Early volumes documented the implementation of foreign policy in the diplomacy conducted by the Department of State, but not the deliberative processes that set the course for U.S. foreign policy in Washington. Later volumes focused more and more on filling this gap by editorial prioritization of the decision-making process and inclusion of more and more records from beyond the State Department. This reversal of editorial focus means that the vast majority of diplomatic records that illustrate how foreign policy was implemented at U.S. embassies throughout the world are underrepresented in recent volumes compared to earlier ones.

<!-- END SOURCE: page understanding-documents -->

---

### 3.4 Page 4 — Using FRUS for Research

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: research-practices | lines: 790–851 -->

**Title:** Using FRUS for Research

**Subtitle:** Strategies for getting the most from the archive

<!-- section-id: intro -->

FRUS rewards researchers who read across documents, not just within them, and who squeeze valuable information about both historical and archival context from the editorial annotation added to documents. Here are strategies that experienced historians have used with printed and online volumes (later pages will address how this app builds on these tried-and-true methods).

<!-- section-id: introduction -->

**Read the Front Matter**

Every FRUS volume opens with a substantial editorial introduction that explains the volume's scope, the sources available (and unavailable), major gaps in the record, and key themes. Reading this Front Matter takes minutes but saves hours of confusion.

<!-- section-id: person -->

**Follow the Person, Not Just the Topic**

Some of the richest insights come from tracking individual policymakers across documents. Secretary Kissinger's position in one cable often illuminates a memo written three weeks earlier. The person index in this app aggregates mentions across a volume; use it to trace who was driving decisions, not just what decisions were made.

<!-- section-id: dates -->

**Use Date Ranges Pragmatically**

If your research topic is topical or thematic, you may find that queries across the entire FRUS corpus yield an unmanageably large number of search results. It can seem impossible to wade through page after page of hits. Date filtering lets you focus on reasonable slices of time. You can zero in on a particularly relevant time period or define more manageable chunks for a comprehensive review of results.

<!-- section-id: editorial -->

**Editorial Notes as a Finding Aid**

When an editorial note summarizes a meeting or document rather than reproducing it, that's a research signal, not a dead end. The note includes archival citations to the underlying documentation. You can use the document-level Source Explorer or the free-text NARA Lookup tool to find the relevant finding aids and track down the relevant original records at NARA.

<!-- section-id: cross-volume -->

**Cross Volume Boundaries**

The focus and scope of individual FRUS volumes embody decisions about how to slice a complex record. A decision made in a document on one page of a Latin America volume might have been shaped by simultaneous conversations documented in a Foreign Economic Policy volume. Searching, following cross-references, and building collections across subseries and time periods often reveals policy coherence (or contradiction) that single-volume reading misses.

<!-- section-id: omissions -->

**Don't Forget What You're Not Reading**

FRUS tells the U.S. side of the history of foreign relations. The counterpart cable from a foreign ministry, the intelligence report shaping the other side's expectations and strategies, the domestic political pressures driving a foreign leader — these are absent. FRUS is indispensable for illuminating the thinking and actions of U.S. policymakers. As valuable as that often is, international history is an interactive story that requires understanding events from multiple perspectives to truly master. For many types of questions, researchers should treat FRUS as an entry point to a historical or policy question, not its answer.

<!-- END SOURCE: page research-practices -->

---

### 3.5 Page 5 — Finding What You Need

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: finding-documents | lines: 852–939 -->

**Title:** Finding What You Need

**Subtitle:** Ways to locate documents across the corpus

<!-- section-id: search -->

**Full-Text Search**

Search the full text of every downloaded and indexed volume at once. Results are ranked by relevance with English stemming, so searching "negotiation" also returns "negotiate," "negotiated," and "negotiations." The search box understands Google-style syntax: wrap words in quotes for an exact phrase ("missile crisis"), use OR for either term, a leading minus to exclude a word (-Cuba), and a trailing asterisk for prefix matching (negoti*).

Open the advanced filters to narrow by date range, document type, a person mentioned, and the search scope (document text, summaries, notes). You can also limit a search to specific volumes or whole subseries, apply one of your named volume scopes (My Volume Scopes), or filter by a detected topic — either fills the volume picker with the matching indexed volumes, and warns you when a scope has none indexed yet. Search only covers indexed volumes — download and index more to widen the corpus.

Find it on the Search tab (iOS) or the search window, ⌘F (Mac).

<!-- section-id: query-inspector -->

**What Your Query Actually Searched For**

Search rewrites what you type before it runs — stemming, implicit AND between words, the operators above. The Query Inspector shows the expression it compiled, so a search that returns something surprising can be read rather than guessed at.

It also warns where stemming widens a search past what you meant: type “containment” and the panel tells you it was searched as “contain,” which also matches “contains” and “container.” Prefix the word with = to search it literally. This matters most when you are about to report a count: an unexpectedly large number is usually a stem, not a finding.
<!-- section-id: result-facets -->

**The Shape of a Result Set**

Facets break a result set down by year, volume, person, document type and archival provenance, so you can see at a glance whether a term clusters in one administration, one country file, or one editor’s volumes.

Read the denominator carefully, because it is deliberately not the list you are looking at: facets describe the whole match, before any narrowing you apply below them. That is what makes them comparable to each other — a breakdown that shifted every time you filtered would tell you about your filtering rather than about the corpus.

Facet rows are also controls. Tapping one narrows the search to that year, volume, or person, and the narrowing appears as a chip you can clear.
<!-- section-id: working-corpora -->

**Working Corpora**

A working corpus is a fixed set of documents — the results of one search, frozen. Save one with “Save as Working Corpus…” and apply it from the advanced filters under My Working Corpora; every later search then runs only inside it.

This is different from a volume scope. A scope narrows to whole volumes; a corpus narrows to the particular documents you captured, which is what you want when the set you care about is “the 240 documents that matched, minus the eleven I decided were irrelevant.”

Each corpus records how it was made, and the app repeats it back where you apply one. If the search that produced it was capped, the corpus says so — “the highest-scoring 7,500 of 67,034 matches” — because a set that was truncated at capture is not the same evidence as a set that was complete, and you should not have to remember which was which.
<!-- section-id: volume-scopes -->

**Custom Volume Scopes**

A volume scope is a named, reusable set of volumes — every volume covering a crisis, a region, or an administration. Build one in Settings → Volume Scopes: the editor lists the whole series with a title filter, and Add Volumes By… gathers matches by detected subject, person, manifest tag, or coverage years and editor. Scopes sync to your other devices via iCloud, and volumes you haven't downloaded stay in a scope and take effect once indexed.

Apply a scope anywhere the corpus can be sliced: the search filters, the Corpus, Person, and Cross-Reference Analytics scope menus, the Word Cloud, and the About the Series dashboards. Each entry shows how many of the scope's volumes are indexed, and a scope with none indexed is called out honestly rather than silently searching nothing.

<!-- section-id: browser -->

**Corpus Browser**

Browse the series the way it is published: corpus → subseries → volume → compilation → document, with a breadcrumb trail so you always know where you are. From here you also download and queue volumes for indexing.

Find it on the Browse tab (iOS) or the Corpus Browser window, ⇧⌘B (Mac).

<!-- section-id: volume-subjects -->

**Top Subjects on Volumes**

Every volume shows a Top Subjects section — the subjects most characteristic of that volume, drawn from experimental subject data and grouped by category.

Tap a subject to see the other FRUS volumes covering it across the entire series — including volumes you haven't downloaded — and jump straight to one. It works before downloading, so it doubles as a way to decide which volumes are worth adding to your library.

These are automatically detected topics, not editorial subject headings, so treat them as experimental — a few may be mistagged. The same topics also work as filters: Filter by detected topic… in the search filters, and the By Detected Topic scope menus in Analytics, the Word Cloud, and the About the Series dashboards, all narrow to the volumes where a topic is most characteristic. The same chips also appear on each volume's page, in its Top Subjects section.

<!-- section-id: chronology -->

**Chronology**

Pick a date range and browse every indexed document from that period, grouped by date — ideal for reconstructing how a crisis or summit unfolded day by day. A distribution chart shows where documents cluster across the range and which volumes they come from, and dense dates collapse so a busy day stays readable. Tap a chart bar to jump to that date; tap a volume in the legend to filter. Documents that span a wide range of dates (chiefly editorial notes) are listed separately rather than pinned to a single day. A Word Cloud for this range button turns whatever span you are viewing into a word cloud.

Find it from the Browse tab’s Analysis Tools menu (iOS) or the Chronology window (Mac).

<!-- section-id: person-index -->

**Person Index**

An alphabetical directory of everyone named across your indexed volumes. Select a person to see every document that mentions them — a fast way to follow an individual policymaker, diplomat, or foreign leader through the record.

The app groups a person's appearances across volumes automatically, but it is deliberately cautious — it won't merge two entries unless it is confident they are the same person, so some people appear more than once. You can finish the job by hand: merge two entries from a person's detail (or a row's context menu), and undo any merge or separation later from the Corrections list. Your corrections sync across your devices.

A person's detail also lists Subjects — detected topics characteristic of the volumes where they are mentioned (volume-level, not per-document tags). Tap one to see every volume covering it.

Find it in the Corpus Browser's People section.

<!-- section-id: citation-lookup -->

**Find by Citation**

Have a FRUS citation from a footnote, a syllabus, or another book? Paste it into Find by Citation and the app helps you look for the right document — no manual hunting through volumes and document numbers.

Find it in the Search screen's overflow (More) menu (iOS) or under Find ▸ Citation Lookup, ⇧⌘F (Mac).

<!-- section-id: related-documents -->

**Related Documents**

From any document, Related Documents ranks the indexed documents most connected to the one you are reading, blending five signals: archival provenance (drawn from the same file or collection), cross-references (cites or is cited by), closeness in date, corpus proximity, and shared people. Small icon chips on each result show why it matched, and each chip says only what its signal can support: a count of citations, or simply "same provenance", where a percentage would mean nothing.

Corpus proximity reads the FRUS editors' own arrangement. Two documents printed side by side, or gathered into the same short chapter, score highest; the signal eases off as the container they share widens to a whole compilation and then the whole volume, and lower again for a different volume in the same subseries. It is a way of asking what the editors thought belonged together.

A scope control limits the list to This volume, This subseries, or All volumes, and Adjust weights opens a slider per signal so you can tune the blend — favor provenance for archival work, dates for reconstructing a week — and your tuning is remembered. A sixth signal, shared topics, is visible but stays disabled until experimental detected-topic document data is ready to include in the app.

Find it in the Research rail's Related tile. On the Mac — and on iPad with Stage Manager — it opens as its own window that stays open while you jump between results.

<!-- END SOURCE: page finding-documents -->

---

### 3.6 Page 6 — Seeing the Bigger Picture

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: corpus-analysis | lines: 940–1028 -->

**Title:** Seeing the Bigger Picture

**Subtitle:** Tools for analysis across documents and volumes

<!-- section-id: analytics -->

**Corpus Analytics**

Chart how often a term or phrase appears across the indexed corpus, broken down by decade, year, month, day, subseries, or individual volume. Use it to see when a topic first enters FRUS, how coverage of a country or issue shifts over time, and which volumes are richest for a keyword. The By-Subseries and By-Volume views are interactive: tap a bar to open those exact documents in Search, with the counts shown so you know what to expect.

A caution: FRUS volumes are selective and evolving proxies for the underlying archival record — treat term-frequency trends as a finding aid, not as direct evidence of what policymakers were discussing. The “% of documents” toggle on the By-Year and By-Decade charts reads a term as a share of the corpus rather than a raw count — the percentage of that period’s documents that contain it — so a term doesn’t look like it is surging simply because the series published more in later decades.

An Export menu saves a chart as a figure (PNG or PDF) or as the data behind it (CSV) — the time-based charts offer all three; on By Subseries and By Volume the figure items are dimmed and only the CSV is available.

Analytics runs entirely on your local index; no network connection is required.

Find it from the Browse tab’s Analysis Tools menu (iOS) or the Corpus Analytics window (Mac).

<!-- section-id: reading-results -->

**Four Ways to Read a Search Result Set**

Above your search results, four readings of the same search are available. Timeline places the matches by date. Concordance lines every occurrence up on your search term, so a page of hits can be read as usage rather than as a list. Collocates ranks the words that keep company with your term. Facets breaks the match down by year, volume, person and provenance.

They do not all count the same thing, and each panel names the set it used. The concordance shows the page you are on; facets read the whole match; the timeline and collocates cover the results retained for this search. Use Collocates for ideas for follow-on searches: the words your query travels with can help you reconstruct period-specific vocabulary you did not know to look for.
<!-- section-id: keyness -->

**Distinctive Words, Not Just Frequent Ones**

The Word Cloud can size words two ways. By frequency, the biggest words in almost any FRUS scope are the ones that are big everywhere — government, department, president. Switch “Size words by” to distinctiveness and the cloud instead ranks words by how much more they appear here than in the corpus as a whole, which is what makes one volume, decade or working corpus look different from every other.

The comparison is made against a reference built from the whole series and shipped with the app, so it works with no volumes downloaded. It is also honest about when it cannot run: change the tokenizing settings in a way the reference was not built for, or ask for a scope with too little text, and the app says the ranking is unavailable rather than showing you a number it cannot stand behind.
<!-- section-id: person-analytics -->

**Person Analytics**

Where the Person Index is an alphabetical directory for looking someone up, Person Analytics charts how people that were tagged by Office of the Historian editors during production appear across the record over time. Trends mode ranks the most-mentioned people for a chosen era, lets you add up to five people and compare how often each is mentioned year by year (as raw counts or as a share of that period’s dated documents), and — when exactly two people are selected — draws a relationship chart of how often the pair is mentioned together over time. Network mode centres a co-mention graph on one focus person, radiating out to the people most often named alongside them.

Mentions come only from more recent volumes produced when person tagging was part of the editorial workflow and then only for documents the app can place on a date. On top of that, remember that FRUS itself is a selective record — read these as who the published documents foreground, not a full census of who mattered.

Find it from the Browse tab’s Analysis Tools menu (iOS) or the Person Analytics window (Mac).

<!-- section-id: word-cloud -->

**Word Cloud**

See the most frequent terms across any slice of the corpus — a single document, a volume or subseries, a collection, a tag, a saved search, a custom volume scope, a detected topic, a date range, or the whole corpus — with each word sized by how often it appears. Semantic lenses narrow the cloud to people, places, organizations, topics, actions, descriptors, concepts, or sentiment, all recognised on-device.

Tap any word to chart its frequency across the whole series in Corpus Analytics, hide words you don’t want to see, or compare two scopes side by side; from the Options menu, export the cloud as a PNG, PDF, or CSV, where the CSV ranks every visible term with its count and its share of the words counted and records your settings — including how many words you hid by hand. A date-range cloud and the Chronology browser hand off to each other — build a cloud from the dates you are viewing in Chronology, or jump from a date-range cloud back into Chronology for the same span. Tune the cloud’s typeface and density in Settings.

Like Analytics, a word cloud reflects what FRUS editors chose to publish, not the full archival record — read it as a finding aid, not as direct evidence.

Find it from the Browse tab’s Analysis Tools menu (iOS) or the Word Cloud window (Mac), plus the word-cloud buttons on documents, volumes, subseries, collections, tags, saved searches, and your custom volume scopes (Settings → Volume Scopes).

<!-- section-id: cross-reference-graph -->

**Cross-Reference Graph**

Visualise the web of footnote cross-references the editors drew between documents and volumes. Choose how far to expand the graph — direct connections only, or one or two degrees of neighbors — to trace how a decision was informed by, or fed into, the surrounding record.

Pinch to zoom and drag to pan — on the Mac the scroll wheel zooms too — and right-click (or long-press) a node to recenter the graph on that document or open it.

Find it from the Research rail's Graph tile (it opens in its own window on Mac and on iPad with Stage Manager).

<!-- section-id: cross-reference-analytics -->

**Cross-Reference Analytics**

Where the graph traces one document’s neighborhood, Cross-Reference Analytics steps back and treats the whole citation web as a statistical object. It surfaces the most-referenced documents (those the editors cite most often, by inbound-citation count), a degree-distribution histogram that shows the network’s shape — a few heavily-cited landmarks and a long tail — a volume-to-volume heat matrix of which volumes cite which among the most-connected volumes, and a list of “landmark” documents ranked by an offline PageRank influence score. Every row is tappable to open the document or volume.

These are structural measures of how the editors linked documents, not a claim about historical importance. Note also that FRUS editorial practice toward cross-references has changed over time. In more recent volumes, editors were not required to exhaustively annotate previously cross-referenced documents within a volume. Analytics trends over time may reflect evolving editorial practices alongside changes in the archival record. Comparisons within subseries scopes are more likely to carry a historical signal than those that cross editorial eras.

Find it from the Browse tab’s Analysis Tools menu (iOS) or the Cross-Reference Analytics window (Mac).

<!-- section-id: source-explorer -->

**Source Explorer & NARA Catalog**

Open the Source Explorer from any document to read its source note broken into structured archival fields detected during indexing, and to follow citations into NARA's finding aids — the correct period-specific research page, relevant record groups, and related collections.

You can also select any text — a lot file number, a decimal file identifier, a collection name — and run a NARA Catalog Lookup directly: lot-file search, keyword search within a record group, or central-files period routing. Period routing needs no key; the other strategies rely on a free NARA Catalog API key you can request from the National Archives and then add in Settings.

From those same source notes, Archival Neighbors gathers other indexed documents drawn from the same detected archival source — the same lot file, central decimal file, record-group series, or presidential-library collection — so pieces of one file scattered across volumes come back together. Reach it from the Source Explorer, a document’s row in a volume’s sources list, a search result, or a node in the cross-reference graph; on the Mac each archival source opens its own Archival Neighbors window, so several can sit side by side. An empty list is an honest answer: no document in your indexed volumes cites that source — indexing more volumes may surface some.

More recent volumes contain a front matter section on sources that provides an annotated list of archival collections its editors drew on. If a volume has a Sources section, it has been enriched so that each collection that resolves — a record group or a lot file — links straight to its record in the National Archives Catalog, each recognized entry shows how many of your indexed documents cite it (a count, or an honest zero), and a collection the app’s cross-volume authority tracks opens its full Collection view — aliases, catalog record, and every citing volume — so you can follow a body of records across the series. Resolved collections also show the archival file series name and the HMS/MLR entry number — the identifier NARA staff use to locate a series, and the value you will need when you request the original records.

<!-- section-id: timeline -->

**Document Timeline**

Turn any set of results into a timeline. From a search result list or a collection, the timeline view charts those documents by year (and lists them chronologically) so you can see their distribution over time at a glance and spot gaps or concentrations.

<!-- END SOURCE: page corpus-analysis -->

---

### 3.7 Page 7 — Working With Documents

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: working-with-documents | lines: 1029–1115 -->

**Title:** Working With Documents

**Subtitle:** Reading, annotating, organizing, and exporting

<!-- section-id: document -->

**The Document Reader**

Every document is rendered from its original TEI-encoded XML, preserving the published structure: headings, datelines, footnote markers, tables, and emphasis. Footnote markers open inline; person names link to the volume's biographical glossary. Read mode keeps the focus on the published text, while Research mode opens the Research rail — your notes, tags, collections, and AI summaries — alongside it.

<!-- section-id: annotations -->

**Highlights, Notes & Tags**

Create color-coded text highlights that persist across sessions, attach free-text research notes to a passage or a whole document, and apply your own tags to group documents by theme, actor, or analytical category. All of it is yours and travels with your account.

<!-- section-id: projects -->

**Research Projects**

A project is an activity lens on your work. Every note, highlight, summary, and collection you create is tagged with the active project, so you can keep separate research threads distinct and switch between them instantly — or work in the global context with no project selected. Switch or create projects from the project picker.

A default project is created for you; you never have to set one up before exploring.

<!-- section-id: collections -->

**Collections & Export**

Collections are curated sets you assemble for a purpose — a teaching reader, a briefing packet, a source dossier. The manager is where you shape the content: add documents from any volume, interleave your own section headings and rich-text prose (bold, italic, underline, colour), attach notes to a document, and inspect a document's notes, highlights, tags, summary, and archival source in place. Add Documents gathers documents without leaving the editor — search the index, browse a volume, paste citations or history.state.gov links (each line resolves to its document), or pull in everything carrying one of your tags. The composition lives on the collection itself — default body depth (full text, an AI summary, or a compact index), footnotes, table-of-contents style, and whether to include highlights, notes, or a word cloud — and any single document or whole section can override the body depth. Four one-tap presets — teaching reader, briefing packet, source dossier, scholarly edition — set the whole composition at once as a starting point, adding any apparatus they call for without disturbing what you have already placed. Sections nest up to three levels — indent or outdent a heading from its context menu, drag a heading to move its whole section as a block, and give the collection a subtitle, author line, rich-text introduction, and colophon for a true title page. Excerpt quotations freeze a highlighted or selected passage into the collection as a styled block quote with its citation, and each document's inspector is a per-document control surface — an editable “key takeaway” headnote above the body (seeded by on-device AI, or written in your own words, with a small chip noting which), per-document overrides for highlights, notes, source note, footnotes, and summary prompt, and a “See also” line citing cross-referenced documents inside the collection. Generated apparatus blocks — a bibliography, a chronology, a sources-and-archives list, a persons index, and a thematic index — are computed from the collection’s documents at every export and in the preview, placeable anywhere like any other row. Sort by Date puts the documents in chronological order either across the whole collection in one sweep, or within each section only — so documents stay under their own heading rather than crossing into a neighboring section. A live preview shows the collection exactly as its HTML export while you compose — side-by-side on iPad and Mac, a Preview toggle on iPhone.

Export is simply how you share it. Render the collection — section headings and prose included — as a PDF, HTML file, or Word document; produce a BibTeX or RIS file for a reference manager; or save a native “.fruscollection” file: an editable copy a colleague opens right back into their own FRUS Explorer, where the documents travel as references they can download. Import one with Import Collection or by opening the file. A smart collection driven by a saved search can be frozen into an editable copy with Create Static Snapshot.

Find it on the Collections tab (iOS) or the Collections window, ⇧⌘K (Mac).

<!-- section-id: quotation-check -->

**Checking Your Quotations**

An excerpt in a collection is a frozen quotation, captured whenever you captured it. Volumes get reindexed, removed and re-downloaded, so before a collection exports, the app checks every stored excerpt against the text of the document it cites.

The check is a deterministic comparison, not a judgement. It forgives everything about presentation — line breaks, curly versus straight quotes, soft hyphens, capitalisation, and elisions marked with an ellipsis, whose fragments must still appear in order — and forgives nothing about wording. A paraphrase does not pass.

It warns; it never blocks. A quotation from a volume you have since removed cannot be checked at all, and the app says that rather than calling it wrong — being unable to verify something is not the same as finding it false.
<!-- section-id: method-appendix -->

**The Query Log as a Method Appendix**

The app records the searches you run, and exports them as a methods statement: every query with the scope it ran under, how many volumes were indexed at the time, and what it returned. Find it in Settings → Data & Recovery, as a Markdown table and a CSV.

The reason to keep it is the zeros. “I searched for this and found nothing” is an assertion; the same sentence with a date, a scope and a denominator is evidence, and it is the only form of it a reader can check.

A count that hit the app’s row ceiling is written as “at least 7,500,” never as 7,500 — it is a floor, and the CSV carries a column saying so, because a spreadsheet will otherwise happily sum a column of floors into a total that was never measured. Searches recorded before the app kept this detail are printed and marked, not quietly dropped.

A collection can carry the same appendix, narrowed to the project it was exported under. That is off by default: it contains the text of every search you ran, which is exactly the thing not to attach to a shared PDF by accident.
<!-- section-id: citations -->

**Citations & Bibliographic Export**

Every document carries a correctly formatted citation in the history.state.gov style, ready to copy. You can also export citations — individually or for a whole collection — as BibTeX or RIS for your reference manager (RIS imports into Zotero on the desktop via File → Import).

Sending to Zotero is one action: connect a Zotero account (Settings → Connections) and Send to Zotero Library pushes a document — or an entire collection — straight into your library over the web, carrying your tags and research notes; without an account it falls back to an RIS file for desktop import.

<!-- section-id: ai -->

**AI Summaries**

Where Apple Intelligence is available, generate on-device summaries of individual documents using prompt templates — standard ones for different research purposes (analytical, chronological, actor-focused) or your own. Summaries are stored locally and can be used as first drafts of research notes that you revise or exported alongside documents in collections; every summary in an exported collection is labeled as AI-generated content attributed to Apple Intelligence. Treat them as orientation only: always read the primary document yourself for your actual research.

To summarize a large body of material at once, the background summarizer works through an entire subseries, volume, tag, saved search, date range, or one of your saved volume scopes unattended, reporting progress as it goes — so a stack of summaries is ready when you return.

<!-- section-id: sync -->

**Syncing Across Devices**

Your notes, highlights, tags, collections, and projects sync automatically through iCloud, so your research follows you between iPhone, iPad, and Mac. Downloaded volumes and the search index are stored per-device and are not synced.

<!-- section-id: privacy -->

**Your Data Stays Private**

The app does not share any usage or research data with anyone. You can export and share anonymized diagnostic data with the developer for troubleshooting if and when you choose. You can also export all your research data.

<!-- END SOURCE: page working-with-documents -->

---

### 3.8 Page 8 — Production & Timeliness *(live dashboard — no editable page prose)*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-production | lines: 1116–1136 | note: dashboard page, sections: [] -->

This page renders the live **Production & Timeliness** dashboard (`EducationDashboard.seriesProduction`) instead of prose, so it has no editable page-level sections. Its page **title** ("Production & Timeliness") and **subtitle** ("How long the official record takes to reach print") are localized in code at the lines above (`education.series.production.page.title` / `.subtitle`).

The dashboard's own on-screen copy — the intro paragraph, per-chart captions, and the "About these figures" caveats — lives in **`FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.production.intro`
- Chart titles/captions: `series.chart.lag.title` / `.caption`, `series.chart.lag.target.series`, `series.chart.peryear.title` / `.caption`, `series.chart.cumulative.title` / `.caption`; axis labels `series.chart.*.x` / `.y`; era legend `series.chart.era.legend`
- Caveats block: `series.caveats.title` / `series.caveats.body`
- Shared "View as table" control: `series.inspector.viewTable`
- Empty state: `series.empty.title` / `series.empty.message`

<!-- END SOURCE: page series-production -->

---

### 3.9 Page 9 — Geographic Emphasis *(live dashboard — no editable page prose)*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-geography | lines: 1137–1157 | note: dashboard page, sections: [] -->

This page renders the live **Geographic Emphasis** dashboard (`EducationDashboard.seriesGeography`) instead of prose, so it has no editable page-level sections. Its page **title** ("Geographic Emphasis") and **subtitle** ("Which regions and countries the series covers most") are localized in code at the lines above (`education.series.geography.page.title` / `.subtitle`).

The dashboard's own on-screen copy lives in **`FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.geography.intro`
- Chart titles/captions: `series.geography.trend.title` / `.caption`, `series.geography.totals.title` / `.caption`, `series.geography.countries.title` / `.caption`; axis labels `series.geography.*.x` / `.y`; region legend `series.geography.region.legend`
- Caveats block: `series.geography.caveats.title` / `series.geography.caveats.body`
- Shared "View as table" control: `series.inspector.viewTable`
- Empty state: `series.geography.empty.title` / `series.geography.empty.message`

<!-- END SOURCE: page series-geography -->

---

### 3.10 Page 10 — Archival Sourcing *(live dashboard — no editable page prose)*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-sourcing | lines: 1158–1178 | note: dashboard page, sections: [] -->

This page renders the live **Archival Sourcing** dashboard (`EducationDashboard.seriesSourcing`) instead of prose, so it has no editable page-level sections. Its page **title** ("Archival Sourcing") and **subtitle** ("Where the series drew its documents from, over time") are localized in code at the lines above (`education.series.sourcing.page.title` / `.subtitle`).

The dashboard's own on-screen copy lives in **`FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.provenance.intro`
- Chart titles/captions: `series.provenance.composition.title` / `.caption`, `series.provenance.trend.title` / `.caption`, `series.provenance.density.title` / `.caption`; axis labels `series.provenance.*.x` / `.y`; category legend `series.provenance.category.legend`
- Caveats block: `series.provenance.caveats.title` / `series.provenance.caveats.body`
- Shared "View as table" control: `series.inspector.viewTable`
- Empty state: `series.provenance.empty.title` / `series.provenance.empty.message`

<!-- END SOURCE: page series-sourcing -->

---

### 3.11 Page 11 — Administration Profiles *(live dashboard — no editable page prose)*

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: series-administrations | lines: 1179–1190 | note: dashboard page, sections: [] -->

This page renders the live **Administration Profiles** dashboard (`EducationDashboard.administrationProfiles`) instead of prose, so it has no editable page-level sections. Its page **title** ("Administration Profiles") and **subtitle** ("How the series' coverage is distributed across presidencies") are localized in code at the lines above (`education.series.administrations.page.title` / `.subtitle`).

The dashboard's own on-screen copy lives in **`FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift`** as localized strings. To edit it, change these keys there:

- Intro: `series.admin.intro`
- Chart titles/captions: `series.admin.docs.title` / `.caption`, `series.admin.perYear.title` / `.caption`, `series.admin.volumes.header` / `series.admin.volumes.caption`; axis labels `series.admin.*.x` / `.y`; party legend `series.admin.party.legend`; per-administration detail `series.admin.detail.title` / `series.admin.detail.picker`
- Editorial-note (range-document) toggle: `series.admin.toggle.title` / `series.admin.toggle.subtitle`
- Caveats block: `series.admin.caveats.title` / `series.admin.caveats.body`
- Shared "View as table" control: `series.inspector.viewTable`
- Empty state: `series.admin.empty.title` / `series.admin.empty.message`

<!-- END SOURCE: page series-administrations -->

---

## 4. Series Analytics — Dashboard Prose

*The four Series-analytics dashboards (reached from the Research Guide's live dashboard pages and from Corpus Analytics). Each has an intro paragraph, per-chart subtitles, and an "About these figures" methodology footnote. These are shared SwiftUI views — one edit point changes both iOS and macOS.*

---

### Source Provenance dashboard (Series Analytics SA-3b)

#### Page intro

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | intro (SourceProvenanceDashboard) | lines: 119–120 | key: series.provenance.intro -->

Where did the editors of Foreign Relations of the United States find the documents they published? Since the early 20th century, every document carries a source note naming the archival file it was drawn from. These charts parse those notes across the whole series to trace how its archival base evolved — from the near-total dominance of the State Department's central files until the postwar appearance of bureau lot files and presidential libraries, to the diversified sourcing of the modern volumes.

<!-- END SOURCE: series.provenance.intro -->

#### Chart 1 subtitle — Archival provenance over time

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | mixOverTimeChart caption | lines: 247–248 | key: series.provenance.trend.caption -->

Each decade's source notes divided among the archival collections they cite, so every decade sums to 100%. Decades are set by each volume's coverage midpoint; the trend begins in 1900 because earlier volumes carry no archival source notes.

<!-- END SOURCE: series.provenance.trend.caption -->

#### Chart 2 subtitle — Overall provenance composition

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | compositionChart caption | lines: 302–303 | key: series.provenance.composition.caption -->

How many source notes across the whole series (from 1900) cite each kind of archival collection. The Central Decimal File dwarfs the rest — most published FRUS documents came from the State Department's own central filing.

<!-- END SOURCE: series.provenance.composition.caption -->

#### Chart 3 subtitle — The documentary base by decade

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | densityChart caption | lines: 350–351 | key: series.provenance.density.caption -->

How many source notes each decade contributes — the density behind the shares above. The 1940s carry the deepest base. Note that volumes covering the 1970s, 1980s, and 1990s are currently in production. Those decades will look different as new volumes are released.

<!-- END SOURCE: series.provenance.density.caption -->

#### Category-filter caveat — shown while categories are hidden

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats filtered line | lines: 399–400 | key: series.provenance.caveats.filtered.v2 -->

Some categories are hidden — the shares shown are re-based to the shown categories, not the full mix. A decade with no notes in any shown category collapses to zero rather than being skipped. Use the Categories menu above to show all.

<!-- END SOURCE: series.provenance.caveats.filtered.v2 -->

#### "About these figures" methodology footnote

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats body | lines: 405–406 | key: series.provenance.caveats.body -->

These figures are derived by parsing each document's source note — the citation naming where its archival original was found — not from a catalog of the archives. "Other / Unclassified" is a citation form the parser could not classify, not the absence of a source note. Coverage spans 522 of the 552 catalogued volumes. Pre-1900 volumes are largely published diplomatic correspondence carrying no archival source notes, so the trend begins around 1900; those early retrospective compilations are excluded from the charts. The categories map to State Department filing practice: the Central Decimal File is the pre-1963 central filing system; the Central Foreign Policy File its post-1963 successor; lot files were maintained by individual bureaus, offices, and posts; and presidential libraries hold the White House records that dominate modern volumes. Remember that these counts reflect where FRUS editors drew documents — an editorial and archival signal — rather than a full census of the underlying archives.

<!-- END SOURCE: series.provenance.caveats.body -->

---

The `AdministrationProfilesDashboard` is a single shared SwiftUI view (used via `EducationDashboardView`), so its `String(localized:)` keys are single edit points shared across iOS and macOS.

### Administration Profiles Dashboard

#### Dashboard intro
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.intro | lines: 236–237 | key: series.admin.intro | shared: iOS+macOS (single edit point) -->

Whose foreign policy does Foreign Relations of the United States document? Every dated document is attributed to the presidential administration in office when the events it records took place. These charts trace how the series' coverage is distributed across administrations — how many documents each one draws, and how densely the series covers each term — and let you drill into any single administration to see which volumes carry its record.

<!-- END SOURCE: series.admin.intro -->
Note: `AdministrationProfilesDashboard` is one shared SwiftUI view rendered on both iOS and macOS; editing this key changes both platforms.

#### Narrowed-empty state — shown when scope and year range match no administration
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.narrowedEmptyState | lines: 202–203 | key: series.admin.narrowedEmpty.message | shared: iOS+macOS (single edit point) -->

No presidential administration matches the current scope and year range — the selected subseries' volumes may carry no attributed documents, or the years may fall outside every term. Reset the scope or year range above for the whole series.

<!-- END SOURCE: series.admin.narrowedEmpty.message -->

#### Editorial-notes toggle explainer
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.editorialNotesToggle | lines: 253–254 | key: series.admin.toggle.subtitle | shared: iOS+macOS (single edit point) -->

Editorial-note documents carry a span of dates rather than a single date; including them adds them to every count and proportion.

<!-- END SOURCE: series.admin.toggle.subtitle -->

#### Chart 1 subtitle — Documents per administration
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.documentsChart | lines: 275–276 | key: series.admin.docs.caption | shared: iOS+macOS (single edit point) -->

How many published documents concern each administration's foreign policy, in chronological order. Attribution is by any overlap, so a volume spanning two terms counts in both.

Note that volumes covering the 1970s, 1980s, and 1990s are currently in production. The Carter, Reagan, H.W. Bush, and Clinton administrations will look different as new volumes are released.

<!-- END SOURCE: series.admin.docs.caption -->

#### Chart 2 subtitle — Volumes per administration-year
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.volumesPerYearChart | lines: 327–328 | key: series.admin.perYear.caption | shared: iOS+macOS (single edit point) -->

How many volumes cover each administration, divided by the length of its term in years — a measure of how densely the series covers each presidency. The sitting administration (no end date) is omitted.

Note that volumes covering the 1970s, 1980s, and 1990s are currently in production. The Carter, Reagan, H.W. Bush, and Clinton administrations will look different as new volumes are released.

<!-- END SOURCE: series.admin.perYear.caption -->

#### Volume-list subtitle — per-administration shares
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.volumeList | lines: 456–457 | key: series.admin.volumes.caption | shared: iOS+macOS (single edit point) -->

Each volume's share is the fraction of that volume's documents that fall in this administration — so shares can sum past 100% across administrations under any-overlap attribution.

<!-- END SOURCE: series.admin.volumes.caption -->

#### Subseries-scope caveat — shown while a subseries scope is active
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.caveats | lines: 532–533 | key: series.admin.caveats.scope %@ | shared: iOS+macOS (single edit point) -->

Scoped to the %@ subseries — counts and proportions are recomputed from that subseries' volumes only, and the per-administration coverage span (which the source data pre-aggregates for the whole series) is hidden. Reset the scope above for the whole series.

<!-- END SOURCE: series.admin.caveats.scope %@ -->
Note: `%@` is filled with the active subseries label at runtime — keep the placeholder verbatim.

#### Any-overlap attribution footnote — "About these figures"
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.caveats | lines: 539–540 | key: series.admin.caveats.body | shared: iOS+macOS (single edit point) -->

Documents are attributed to an administration by any overlap between the document's date and the president's term, so a volume spanning two administrations is counted in both — which is why the summed volume counts exceed the 552-volume corpus and a volume's proportions can sum to over 100% across administrations. These counts measure which administration's foreign policy the documents cover, not when the volumes were published. Editorial-note documents carry a range of dates rather than a single date; their inclusion is controlled by the toggle above (off by default). Pre-1861 retrospective compilations concern no single administration and are omitted. Administrations are counted per president — Nixon and Ford are separate, as are Grover Cleveland's two non-consecutive terms — and administrations for which the series is not yet published do not appear.

<!-- END SOURCE: series.admin.caveats.body -->

---

### Geographic Emphasis dashboard

#### Intro paragraph
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.intro | lines: 142–143 | key: series.geography.intro -->

Where in the world does Foreign Relations of the United States look? Every volume carries editorial place tags, which resolve approximately to the State Department's six regional bureaus. These charts trace how the series' geographic emphasis shifted over time — from an early concentration on Europe and the Western Hemisphere toward the postwar diversification into Asia, the Near East, and Africa — and which regions and countries the corpus covers most.

<!-- END SOURCE: series.geography.intro -->

#### Chart 1 caption — Regional emphasis over time
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.regionTrendChart | lines: 179–180 | key: series.geography.trend.caption -->

Each decade's volumes divided among the regions they cover — a volume spanning several regions splits evenly among them, so every decade sums to 100%. Decades are set by each volume's coverage midpoint.

<!-- END SOURCE: series.geography.trend.caption -->

#### Chart 2 caption — Overall regional emphasis
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.regionTotalsChart | lines: 233–234 | key: series.geography.totals.caption -->

How many volumes touch each region across the whole series. A volume that covers several regions counts once in each, so these totals overlap.

<!-- END SOURCE: series.geography.totals.caption -->

#### Chart 3 caption — Most-covered countries
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.topCountriesChart | lines: 278–279 | key: series.geography.countries.caption -->

The individual place tags carried by the most volumes — the concrete detail behind the regional picture.

<!-- END SOURCE: series.geography.countries.caption -->

#### Regional-bureau mapping footnote
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.caveats | lines: 328–329 | key: series.geography.caveats.body -->

Place tags are volume-level editorial tags: a volume "touches" a region if it carries a place tag mapped to that region — this is not a document count, and a volume commonly spans several regions. The stacked view uses per-volume fractional attribution, so a volume covering three regions contributes a third to each and every decade sums to 100%; the overall bars, by contrast, count a multi-region volume once in each region. Regions roughly follow the State Department's six current regional bureaus, with dependencies and territories folded into "Other." 551 of the 552 catalogued volumes carry at least one place tag. These figures reflect the volumes the app currently catalogs — the newest volumes may not yet appear.

<!-- END SOURCE: series.geography.caveats.body -->
Note: while a subseries scope is active, this dashboard's caveats block also shows the shared scope line `series.caveats.scope %@` (`SeriesGeographyDashboard.swift` lines 321–322). Its canonical block lives in the Production & Timeliness subsection below; the same key and defaultValue appear in both files, so edit both occurrences together.

---

### Production & Timeliness dashboard (`SeriesProductionDashboard.swift`)

Shared iOS+macOS surface — a single SwiftUI view rendered in both the onboarding sheet and the Research Guide. Every string below is keyed via `String(localized:)`, so editing the `defaultValue` is a single edit point for both platforms.

#### Intro paragraph

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var intro | lines: 125–126 | key: series.production.intro | shared: iOS+macOS (single edit point) -->

How long does the official record take to reach print? These charts trace the timeliness of Foreign Relations of the United States across its whole span — the lag between the events a volume documents and its publication (against the evolving publication-timeliness target), the pace of publication over time, and the steady growth of the digitized corpus.

<!-- END SOURCE: series.production.intro -->

#### Chart 1 caption — Publication lag over time

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var lagChart (caption) | lines: 167–168 | key: series.chart.lag.caption | shared: iOS+macOS (single edit point) -->

Each point is a volume: its publication year (horizontal) against how many years earlier its latest document was written — the lag (vertical). The dashed step line is the timeliness target in force at publication — 15 years from the 1961 directive, 20 from 1972, and 30 from 1985 (codified by the 1991 statute).

<!-- END SOURCE: series.chart.lag.caption -->

#### Chart 2 caption — Volumes published per year

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var perYearChart (caption) | lines: 246–247 | key: series.chart.peryear.caption | shared: iOS+macOS (single edit point) -->

How many volumes reached print in each year, coloured by era. Output has never been steady — it reflects staffing, declassification throughput, and the shift to digital publication.

<!-- END SOURCE: series.chart.peryear.caption -->

#### Chart 3 caption — Cumulative volumes published

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var cumulativeChart (caption) | lines: 295–296 | key: series.chart.cumulative.caption | shared: iOS+macOS (single edit point) -->

The digitized corpus has grown to the 552 volumes this app catalogs — steeply in some decades, slowly in others.

<!-- END SOURCE: series.chart.cumulative.caption -->

#### Subseries-scope caveat — shown while a subseries scope is active (shared with Geographic Emphasis)

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var caveats (scope line) | lines: 350–351 | key: series.caveats.scope %@ | shared: iOS+macOS (single edit point) -->

Scoped to the %@ subseries — reset the scope above for the whole series.

<!-- END SOURCE: series.caveats.scope %@ -->
Note: `SeriesGeographyDashboard.swift` repeats the same key and defaultValue in its own caveats block (lines 321–322) — edit both occurrences together so the two files stay consistent. `%@` is filled with the active subseries label at runtime; keep the placeholder verbatim.

#### Publication-timeliness footnote ("About these figures")

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var caveats (body) | lines: 357–358 | key: series.caveats.body | shared: iOS+macOS (single edit point) -->

Production figures reflect only published, digitized volumes. Publication year is the volume's TEI print year and coverage is the span of its document dates; lag is print year minus coverage-end year, and can be near-zero or negative for the near-contemporaneous early volumes. The publication-timeliness target evolved over time — no formal target before 1961, then 15 years (1961 directive), 20 years (1972 directive), and 30 years (1985 directive, codified by the 1991 statute); the step line is drawn against each volume's publication year, so it shows exactly the target in force when the volume was published. These charts reflect the 552 volumes the app currently catalogs — the newest volumes may not yet appear.

<!-- END SOURCE: series.caveats.body -->

---

## 5. Analytics — Explanatory Captions & Info Popovers

*The "About …" info popovers and figure captions across the analytics features, plus the methods statement that travels inside an exported chart's CSV. Multi-sentence explanatory copy that teaches how to read each visualization.*

---

### About the Graph popover

#### What the graph shows
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1358–1359 | key: graph.info.what.body -->

Each node is a FRUS document. Blue nodes cite the central document; orange nodes are cited by it. Grey nodes are 2nd- or 3rd-degree neighbours. Larger nodes have more connections across the corpus, and each arrow points at the document being cited.

<!-- END SOURCE: graph.info.what.body -->

#### Edge context
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1364–1365 | key: graph.info.edges.body -->

Many edges carry the original footnote or editorial-note text where the reference appeared — hover over (or tap) the middle of a line to read it. Thicker lines mean the pair is linked by several separate references.

<!-- END SOURCE: graph.info.edges.body -->

#### Timeline and Network layouts
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1370–1371 | key: graph.info.timeline.body -->

Timeline places each document at its date along a time axis — documents this one cites usually sit to the left (earlier), documents citing it to the right (later). Documents without a recorded date park in the Undated column. Network uses a spring layout based purely on connections.

<!-- END SOURCE: graph.info.timeline.body -->

#### Neighbourhood degree
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1376–1377 | key: graph.info.degree.body -->

1° shows only direct neighbours of the central document. 2° adds neighbours of those neighbours. 3° extends one further hop. Resize the window to see denser graphs more clearly.

<!-- END SOURCE: graph.info.degree.body -->

#### Navigating the graph
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1382–1383 | key: graph.info.interact.body -->

Click a node to see its details. Right-click (or long-press) to recenter the graph on that document or open it in the main window. Use pinch-to-zoom and drag to pan.

<!-- END SOURCE: graph.info.interact.body -->

#### Undownloaded volumes
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1388–1389 | key: graph.info.undownloaded.body -->

References pointing to documents in volumes you haven't downloaded are still shown — the connection was recorded when the source volume was indexed. Those nodes appear with a dashed border and a struck-through cloud icon; select one to download its volume directly from the info panel.

References from volumes you haven't indexed yet are not shown at all, because those volumes have never been parsed. An orange banner at the top of the graph appears when your inbound connections may be incomplete for this reason. Download and index additional volumes to fill in the missing edges.

<!-- END SOURCE: graph.info.undownloaded.body -->

---

### Word Cloud — Info Popover ("About the Word Cloud")
<!-- Toolbar info popover; iOS+macOS use the same WordCloudView.swift toolbar (one file, shared across platforms). -->

#### Word Cloud info — What you're seeing

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 693–694 | key: wordcloud.info.shows.detail -->

The most frequent meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, custom volume scope, or the whole corpus — each sized by how often it appears.

<!-- END SOURCE: wordcloud.info.shows.detail -->

#### Word Cloud info — Lenses

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 697–698 | key: wordcloud.info.lenses.detail -->

The lens chips narrow the cloud to a kind of term — People, Places, Organizations, Topics, Actions, Descriptors, Concepts, or Sentiment — using on-device language analysis.

<!-- END SOURCE: wordcloud.info.lenses.detail -->

#### Word Cloud info — What's filtered out

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 701–702 | key: wordcloud.info.filters.detail -->

Common stopwords are always removed. A word's menu can hide it just from this cloud (temporary — it comes back next time), or add it to your hidden-word lists (globally or per lens) that you manage in Settings → Word Cloud. You can also hide diplomatic boilerplate. Use “Show hidden words” in the Options menu to bring hidden words back.

<!-- END SOURCE: wordcloud.info.filters.detail -->

#### Word Cloud info — Tapping a word

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 705–706 | key: wordcloud.info.tap.detail -->

Charts how often that term appears across the whole corpus in Corpus Analytics; the word's menu also offers a scoped chart and a direct Search.

<!-- END SOURCE: wordcloud.info.tap.detail -->

### Word Cloud Settings — section footers

<!-- Shared surface note: WordCloudSettingsView is a single shared SwiftUI view used on both iOS and macOS (differs only by a #if os(macOS) .formStyle); each footer key below is a single edit point across both platforms. -->

#### Filtering footer — classification markings

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | filteringSection footer | lines: 182–183 | key: settings.wordcloud.markings.footer | shared: iOS+macOS (single edit point) -->

Classification markings include terms like “Top Secret”, “Confidential”, precedence words (“Priority”, “Immediate”), and month names — document chrome that otherwise leaks into clouds, especially named-entity lenses.

<!-- END SOURCE: settings.wordcloud.markings.footer -->

#### Thresholds footer

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | thresholdsSection footer | lines: 212–213 | key: settings.wordcloud.thresholds.footer | shared: iOS+macOS (single edit point) -->

Drop terms shorter than the minimum length or appearing fewer than the minimum number of times. Raising either makes a sparser, higher-signal cloud. Occurrences are counted across the whole scope before its top terms are chosen, so raising that one may not change the sample above — it thins the long tail you never see.

<!-- END SOURCE: settings.wordcloud.thresholds.footer -->

#### Appearance footer

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | appearanceSection footer | lines: 238–239 | key: settings.wordcloud.appearance.footer | shared: iOS+macOS (single edit point) -->

Choose the typeface the cloud is drawn in and how tightly its words pack together. Compact fits more terms; airy spaces them out for legibility. These settings apply on this device only.

<!-- END SOURCE: settings.wordcloud.appearance.footer -->

#### Hidden-words footer — "Every cloud" scope

<!-- S-5b merged the two hidden-words sections into one editor with an "Applies to" scope picker; these two footers are now the two branches of `StopListScope.footer`, not two separate sections. -->

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | StopListScope.footer (.allLenses) | lines: 369–370 | key: settings.wordcloud.global.footer | shared: iOS+macOS (single edit point) -->

Words listed here are removed from every word cloud, on top of the built-in stop lists.

<!-- END SOURCE: settings.wordcloud.global.footer -->

#### Hidden-words footer — single-lens scope

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | StopListScope.footer (.lens) | lines: 372–373 | key: settings.wordcloud.lens.footer | shared: iOS+macOS (single edit point) -->

Words hidden only when the selected lens is active — useful for trimming a recurring false positive (for example, a place the recogniser keeps mistaking) without affecting other lenses.

<!-- END SOURCE: settings.wordcloud.lens.footer -->

#### Performance footer — background precompute

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | performanceSection footer | lines: 161–162 | key: settings.wordcloud.precompute.footer | shared: iOS+macOS (single edit point) -->

When enabled, the most demanding clouds — the whole corpus, a subseries — are computed in the background after indexing, so they open instantly. Runs only while the device is idle.

<!-- END SOURCE: settings.wordcloud.precompute.footer -->

#### Sample footer — where the preview's terms come from

<!-- S-5b. Two branches of `WordCloudBench.provenance`, chosen by whether a cached cloud was found. -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudBench.swift | WordCloudBench.provenance | lines: 190–191 | key: settings.wordcloud.bench.source.cached | shared: iOS+macOS (single edit point) -->

Sampled from your most recent word cloud.

<!-- END SOURCE: settings.wordcloud.bench.source.cached -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudBench.swift | WordCloudBench.provenance | lines: 192–193 | key: settings.wordcloud.bench.source.canned | shared: iOS+macOS (single edit point) -->

A stand-in sample — open a corpus or subseries cloud and this becomes your own terms.

<!-- END SOURCE: settings.wordcloud.bench.source.canned -->

#### Sample empty state — the settings keep nothing

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | sampleSection | lines: 125–126 | key: settings.wordcloud.sample.none | shared: iOS+macOS (single edit point) -->

These settings keep nothing from the sample. Lower a threshold or turn a filter off.

<!-- END SOURCE: settings.wordcloud.sample.none -->

---

### Chronology
<!-- Toolbar info popover; iOS+macOS use the same ChronologyView.swift toolbar (one file, shared across platforms). -->

#### What you're seeing
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1078–1079 | key: chronology.info.shows.detail -->

Every indexed document whose date falls within the range you pick, grouped into date sections that coarsen (days → months → years) as the range widens.

<!-- END SOURCE: chronology.info.shows.detail -->

#### How dates work
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1082–1083 | key: chronology.info.dates.detail -->

Each document sits at its TEI date, and is shown no more precisely than its source supports — with the precision (day/month/year) and certainty (exact vs. approximate) preserved.

<!-- END SOURCE: chronology.info.dates.detail -->

#### The distribution chart
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1086–1087 | key: chronology.info.chart.detail -->

The stacked chart colour-codes documents by source volume (the top volumes, then a grey “Other”). Use the chart-colours menu to choose how many volumes get a distinct colour.

<!-- END SOURCE: chronology.info.chart.detail -->

#### Wide ranges
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1090–1091 | key: chronology.info.cap.detail -->

The document list is capped at 5,000, but the chart still reflects the whole range; the summary line reports the true total so you can narrow the range.

<!-- END SOURCE: chronology.info.cap.detail -->

### Source Explorer
<!-- Shared static FeatureInfoButton.sourceExplorer in FRUSTheme; consumed by both SourceExplorerView (iOS) and MacSourceExplorerView (macOS). Edit once in FRUSTheme.swift to change both. -->

#### What you're seeing
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.sourceExplorer FeatureInfoItem | lines: 157–158 | key: source.explorer.info.shows.detail | shared: iOS+macOS (single edit point) -->

A structured breakdown of one document's source note — the State Department editors' record of where the document came from (archive, file, lot, telegram or despatch number) and how it was handled.

<!-- END SOURCE: source.explorer.info.shows.detail -->

#### Why it matters
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.sourceExplorer FeatureInfoItem | lines: 161–162 | key: source.explorer.info.why.detail | shared: iOS+macOS (single edit point) -->

Source notes are your trail back to the original record. The parsed fields let you cite the document precisely and judge its provenance at a glance.

<!-- END SOURCE: source.explorer.info.why.detail -->

#### Links to the National Archives
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.sourceExplorer FeatureInfoItem | lines: 165–166 | key: source.explorer.info.catalog.detail | shared: iOS+macOS (single edit point) -->

Where a note resolves to a NARA series or file unit, the explorer links straight to the National Archives Catalog so you can locate the original record.

<!-- END SOURCE: source.explorer.info.catalog.detail -->

---

### Corpus Analytics — Info Popover ("About these results")
<!-- Shared static FeatureInfoButton.corpusAnalytics in FRUSTheme (moved out of AnalyticsView in Wave C, Win 7); the `analytics.info.*` keys and copy are unchanged. Edit once in FRUSTheme.swift to change both platforms. -->

#### What the numbers mean
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 183–184 | key: analytics.info.metric.body | shared: iOS+macOS (single edit point) -->

Each bar shows the number of indexed FRUS documents that contain your search term in that period. A document that mentions the term ten times is counted once.

<!-- END SOURCE: analytics.info.metric.body -->

#### Multiple words
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 187–188 | key: analytics.info.multiword.body | shared: iOS+macOS (single edit point) -->

Words separated by spaces are combined with AND: national security matches documents containing both words. OR (either term) and NOT / leading - (exclude a term) work too, exactly as in the Search box.

<!-- END SOURCE: analytics.info.multiword.body -->

#### Phrases
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 191–192 | key: analytics.info.phrase.body | shared: iOS+macOS (single edit point) -->

Wrap words in quotes for an ordered phrase: "missile crisis" matches only documents where those words appear together, in that order. Analytics and Search interpret the same query identically, so the counts here match what Search returns.

<!-- END SOURCE: analytics.info.phrase.body -->

#### Stemming
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 195–196 | key: analytics.info.stemming.body | shared: iOS+macOS (single edit point) -->

English stemming is applied: searching for "negotiate" also matches "negotiating", "negotiated", and "negotiations".

<!-- END SOURCE: analytics.info.stemming.body -->

#### How dates are determined
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 199–200 | key: analytics.info.dating.body | shared: iOS+macOS (single edit point) -->

Each document is placed at its TEI <date> attribute — the date of authorship, not the volume's publication date. A document with no stored date falls back to the start year of its volume, in both the counts and the % denominator. Documents lacking month or day precision are excluded from the By Month and By Day charts.

<!-- END SOURCE: analytics.info.dating.body -->

### Corpus Analytics — Normalization Caption

#### Share-of-corpus caveat (% of documents mode)
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.normalizationCaption | lines: 1599–1600 | key: analytics.normalize.caption | shared: iOS+macOS (single edit point) -->

Share of indexed documents per period. Only downloaded, indexed volumes are counted, so this is a share of your local corpus, not the entire FRUS series.

<!-- END SOURCE: analytics.normalize.caption -->

### Person Analytics — Info Popover ("About Person Analytics")
<!-- Shared static FeatureInfoButton.personAnalytics in FRUSTheme (added in Wave C, Win 7). Source doc comment notes this copy was drafted in Wave C and is pending owner review. Edit once in FRUSTheme.swift to change both platforms. -->

#### What you're seeing
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 213–214 | key: personAnalytics.info.shows.detail | shared: iOS+macOS (single edit point) -->

Trends ranks the people most mentioned in an era, as tagged by FRUS editors, and charts how often a person is mentioned across FRUS documents over time. Network maps who is co-mentioned with whom — people named together in the same documents. Volumes covering the period before World War II do not include editorial tagging of people, so they are out of scope for these tools.

<!-- END SOURCE: personAnalytics.info.shows.detail -->

#### How people are counted
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 217–218 | key: personAnalytics.info.counting.detail | shared: iOS+macOS (single edit point) -->

Counts are mentions of a person across indexed documents, grouped by the app's person authority so spelling variants, honorifics, and name forms for the same individual merge into one identity rather than splitting into several.

<!-- END SOURCE: personAnalytics.info.counting.detail -->

#### Comparing people
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 221–222 | key: personAnalytics.info.compare.detail | shared: iOS+macOS (single edit point) -->

Tap a ranking bar, or use "Add a person to compare", to plot several people's mention trajectories on one chart — each colored line is one person. Remove a person with the ✕ on its chip.

<!-- END SOURCE: personAnalytics.info.compare.detail -->

### Cross-Reference Analytics — Info Popover ("About Cross-Reference Analytics")
<!-- Shared static FeatureInfoButton.crossReferenceAnalytics in FRUSTheme (added in Wave C, Win 7). Source doc comment notes this copy was drafted in Wave C and is pending owner review. Edit once in FRUSTheme.swift to change both platforms. -->

#### What you're seeing
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 235–236 | key: crossRefAnalytics.info.shows.detail | shared: iOS+macOS (single edit point) -->

How FRUS documents cite one another. The ranking lists the most-referenced documents; the heat matrix shows citation flow between whole volumes; landmarks are the documents a citation-following reader keeps returning to. Remember that FRUS editorial practices around cross-referencing have evolved over time. Subseries or administration-level scoping will carry a more consistent signal than broader scopes that reflect more diverse editorial practices.

<!-- END SOURCE: crossRefAnalytics.info.shows.detail -->

#### Reading the heat matrix
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 239–240 | key: crossRefAnalytics.info.matrix.detail | shared: iOS+macOS (single edit point) -->

Rows cite columns — a darker cell means the row's volume cites the column's volume more often. Column labels are a short code of the volume's years and number (e.g. '55–57 II); hover, or use VoiceOver, for the full title on either axis.

<!-- END SOURCE: crossRefAnalytics.info.matrix.detail -->

#### About the influence score
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 243–244 | key: crossRefAnalytics.info.influence.detail | shared: iOS+macOS (single edit point) -->

Landmark documents are ranked by an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is not a claim of historical importance.

<!-- END SOURCE: crossRefAnalytics.info.influence.detail -->

### Cross-Reference Analytics — Captions

#### Scope-of-figures caveat
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 646–647 | key: crossRefAnalytics.resolvedCaption | shared: iOS+macOS (single edit point) -->

The most-referenced, degree, and PageRank figures attribute same-volume references (including resolved page references) to their own volume; when a year range or scope is set they count citations made by documents in that era/scope. The volume heat matrix counts connections between different volumes, so it excludes same-volume citations.

<!-- END SOURCE: crossRefAnalytics.resolvedCaption -->

#### Excluded unresolvable references (shown only when the count is non-zero)

<!-- Placeholder note: the leading count is a Swift string interpolation, not a %lld token — keep `\(excludedBrokenCount)` intact exactly as written. -->

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 651–652 | key: crossRefAnalytics.excludedBrokenCaption | shared: iOS+macOS (single edit point) -->

\(excludedBrokenCount) unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus.

<!-- END SOURCE: crossRefAnalytics.excludedBrokenCaption -->

#### Landmark Documents (Influence) — PageRank hedge subtitle
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.landmarkSection | lines: 1050–1051 | key: crossRefAnalytics.landmarks.subtitle | shared: iOS+macOS (single edit point) -->

Ranked by an offline PageRank influence score over the resolved citation graph — documents a citation-following reader keeps returning to. This is a structural influence measure, not a claim of historical importance. Tap to open.

<!-- END SOURCE: crossRefAnalytics.landmarks.subtitle -->

---

### Analytics Export — Methods Statement (D3)

*The prose that leaves the app inside an exported chart. Every CSV carries a `#`-commented preamble — the figure, terms, grouping, scope, year range, values, app version and export date, then the method and caveats below, then the corpus attribution. An exported PNG or PDF carries only a two-line caption plus the pointer to the CSV, so these sentences are where a reader finds the method. Menu labels, the CSV preamble's field labels ("Figure", "Scope", "Method and caveats", …), CSV column headings, and export-failure messages are functional strings and are intentionally excluded.*

<!-- Placeholder note: `%lld` (a number) and `%@` (a word or phrase) are filled in at export time. Keep them intact and in order — removing one will break the string. -->

#### Corpus attribution — closes every export

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.corpusAttribution | lines: 88–89 | key: analytics.export.attribution | shared: iOS+macOS (single edit point) -->

Foreign Relations of the United States corpus published by the Office of the Historian, U.S. Department of State (history.state.gov). The corpus is in the public domain.

<!-- END SOURCE: analytics.export.attribution -->

#### Dating rule

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.datingCaveat | lines: 114–115 | key: analytics.export.caveat.dating | shared: iOS+macOS (single edit point) -->

Dating: each document is placed at its TEI <date> (the date of authorship). A document with no stored date falls back to the start year of its volume, in both the counts and the % denominator. Documents lacking month or day precision are excluded from the By Month and By Day charts.

<!-- END SOURCE: analytics.export.caveat.dating -->

#### Corpus-coverage caveat

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.corpusCaveat | lines: 120–121 | key: analytics.export.caveat.corpus %lld | shared: iOS+macOS (single edit point) -->

Corpus: counts cover only the %lld volume(s) indexed on this device, not the entire FRUS series.

<!-- END SOURCE: analytics.export.caveat.corpus -->

#### Value-mode caveat

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.valueModeCaveat | lines: 128–129 | key: analytics.export.caveat.values %@ | shared: iOS+macOS (single edit point) -->

Values: %@. A share is that period's matching documents divided by all indexed documents in the same period, so a growing corpus does not read as a rising term.

<!-- END SOURCE: analytics.export.caveat.values -->

#### Year range — when the chart ignores it

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.yearRangeDescription | lines: 103–104 | key: analytics.export.range.notApplied | shared: iOS+macOS (single edit point) -->

Not applied — this breakdown covers the whole corpus span

<!-- END SOURCE: analytics.export.range.notApplied -->

#### Figure caption — pointer to the CSV

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsFigureExport.swift | AnalyticsFigureCanvas.body | lines: 79–80 | key: analytics.export.figure.seeData | shared: iOS+macOS (single edit point) -->

Full method, caveats, and the underlying numbers accompany this figure in its CSV export.

<!-- END SOURCE: analytics.export.figure.seeData -->

### Analytics Export — Person Analytics caveats

#### Dated-documents population

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.personProvenance | lines: 451–452 | key: personAnalytics.export.caveat.dated | shared: iOS+macOS (single edit point) -->

Population: person mentions are counted over DATED documents only — unlike the Corpus Analytics charts, no volume-start-year fallback is applied, so absolute counts are not directly comparable between the two views.

<!-- END SOURCE: personAnalytics.export.caveat.dated -->

#### Identity grouping

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.personProvenance | lines: 453–454 | key: personAnalytics.export.caveat.identity | shared: iOS+macOS (single edit point) -->

Identity: mentions are grouped by the app's person authority, so spelling variants and name forms for one individual merge into a single identity. The person id column is that grouped identity.

<!-- END SOURCE: personAnalytics.export.caveat.identity -->

#### Decade shares (By Decade in % mode only)

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.decadeShareCaveat | lines: 470–471 | key: personAnalytics.export.caveat.decadeShare | shared: iOS+macOS (single edit point) -->

Decade shares: a decade's plotted share is the MEAN of the yearly shares for the years in which this person was mentioned. Years with no mentions are omitted from that average rather than counted as zero, while the "Dated documents in period" column sums every year of the decade. Dividing this file's columns therefore gives the decade's own share, which can be far LOWER than the plotted value — a person mentioned in only one year of a decade plots that year's share for the whole decade. Use the columns for the decade's share and the plotted value for the mentioned years' average; they answer different questions.

<!-- END SOURCE: personAnalytics.export.caveat.decadeShare -->

### Analytics Export — Cross-Reference Analytics caveats

#### Unresolvable references

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 425–426 | key: crossRefAnalytics.export.caveat.excluded %lld | shared: iOS+macOS (single edit point) -->

Unresolvable references: %lld cross-reference(s) are excluded from this analysis — references in the printed volumes that point to a document, page, or volume not present in this corpus.

<!-- END SOURCE: crossRefAnalytics.export.caveat.excluded -->

#### Same-volume attribution

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 429–430 | key: crossRefAnalytics.export.caveat.sameVolume | shared: iOS+macOS (single edit point) -->

Attribution: the document-level figures attribute same-volume references (including resolved page references) to the document's own volume. The volume heat matrix is inherently cross-volume and excludes same-volume citations.

<!-- END SOURCE: crossRefAnalytics.export.caveat.sameVolume -->

#### Heat matrix — which volumes it covers

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixCaveats | lines: 563–564 | key: crossRefAnalytics.export.caveat.matrixLimit %lld | shared: iOS+macOS (single edit point) -->

Selection: the matrix covers the %lld most-connected volumes by total inbound + outbound references. The CSV lists only pairs that have references between them; the figure draws the whole grid and leaves those pairs blank.

<!-- END SOURCE: crossRefAnalytics.export.caveat.matrixLimit -->

#### Heat matrix — axes and labels

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixCaveats | lines: 566–567 | key: crossRefAnalytics.export.caveat.matrixAxes | shared: iOS+macOS (single edit point) -->

Axes: rows cite columns. In the figure the column headings are abbreviated volume codes and the row labels are shortened descriptive labels; both volumes' full titles appear in this CSV.

<!-- END SOURCE: crossRefAnalytics.export.caveat.matrixAxes -->

#### Landmark Documents — what the score is

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.exportLandmarkCSV | lines: 619–620 | key: crossRefAnalytics.export.caveat.pageRank | shared: iOS+macOS (single edit point) -->

Score: an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is not a claim of historical importance.

<!-- END SOURCE: crossRefAnalytics.export.caveat.pageRank -->

### Analytics Export — Word Cloud caveats

<!-- A cloud never reads a document date, so its export deliberately carries no dating rule and no year-range line. The exported plate's figure title, axis line, and caption facts (wordcloud.export.figureTitle / .axis / .caption.*) are functional identifiers and are intentionally excluded here. -->

#### Population

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 346–347 | key: wordcloud.export.caveat.population %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Population: counts cover the %lld document(s) this scope resolved to. The share column's denominator is %lld — every word counted under the "%@" lens after all of the filters below. It is not the scope's total word count, and shares from two different lenses are not comparable.

<!-- END SOURCE: wordcloud.export.caveat.population -->

#### Stopwords

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 349–350 | key: wordcloud.export.caveat.stopwords %@ %@ | shared: iOS+macOS (single edit point) -->

Stopwords: common English words are always removed. FRUS boilerplate (telegram, department, embassy…) is %@; classification markings, months, and weekdays (secret, confidential, january…) are %@.

<!-- END SOURCE: wordcloud.export.caveat.stopwords -->

#### Stopwords caveat — the two fill-in phrases

*Each `%@` slot above (first the boilerplate filter, then the markings filter) is filled with one of these two fragments, depending on whether that filter is on.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 352–352 | keys: wordcloud.export.caveat.stopwords.excluded, wordcloud.export.caveat.stopwords.kept | shared: iOS+macOS (single edit point) -->

**Filter on:** also removed

**Filter off:** kept

<!-- END SOURCE: wordcloud.export.caveat.stopwords.excluded/.kept -->

#### Tuning thresholds

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 357–358 | key: wordcloud.export.caveat.tuning %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Tuning: words shorter than %lld character(s) and words occurring fewer than %lld time(s) are excluded; plural folding is %@.

<!-- END SOURCE: wordcloud.export.caveat.tuning -->

<!-- The tuning %@ slot is filled with the generic common.on / common.off strings ("on" / "off"), which are shared app-wide and not editable here. -->

#### Words hidden by hand

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 372–373 | key: wordcloud.export.caveat.hidden %lld | shared: iOS+macOS (single edit point) -->

Hidden words: %lld word(s) were hidden by hand in this cloud and are absent from this export. They were counted before being hidden, so they remain in the denominator above.

<!-- END SOURCE: wordcloud.export.caveat.hidden -->

#### Personal stop lists

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 377–378 | key: wordcloud.export.caveat.stopLists %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Your stop lists: %lld word(s) on your global hidden-word list and %lld on your list for the "%@" lens were removed before counting, so they appear neither in this table nor in its denominator. Both lists are editable in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.export.caveat.stopLists -->

#### Active lens

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 382–383 | key: wordcloud.export.caveat.lens %@ | shared: iOS+macOS (single edit point) -->

Lens: the cloud is filtered to the "%@" word list, so this is a subset of the scope's vocabulary, not its whole frequency ranking.

<!-- END SOURCE: wordcloud.export.caveat.lens -->

---

## 6. Settings, Tips & Collections

*Explanatory footers in Settings — the ones that tell a reader what a control costs or protects, across the four groups (Library · Research · Reading & Search · System). Functional and error strings are intentionally excluded. Also the discovery tips and the Collections native-export explanation. Strings shared across platforms via one localization key are marked; where the two platforms genuinely say different things (the Volumes & Storage hub is still two views, and search logging differs by platform) each is a separate edit point and says so.*

---

### iCloud Sync, Settings Sync & Privacy

#### Settings-sync toggle detail
<!-- S-5b made the "single edit point" claim on the three keys below actually true: the macOS Sync pane used to hardcode its own near-identical copy (and had drifted — "shares those settings" vs "shares the settings above"). Both platforms now render `SyncSettingsSection`. -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.rows | lines: 1427–1428 | key: settings.sync.toggle.detail | shared: iOS+macOS (single edit point) -->

Word-cloud filters & stop lists, citation style, default document mode, and research logging.

<!-- END SOURCE: settings.sync.toggle.detail -->

#### Settings-sync unavailable notice
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.rows | lines: 1439–1440 | key: settings.sync.unavailable | shared: iOS+macOS (single edit point) -->

Settings sync needs iCloud. Sign in to iCloud and enable it for FRUS Explorer to turn this on.

<!-- END SOURCE: settings.sync.unavailable -->

#### iCloud Sync section footer
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.footerText | lines: 1449–1450 | key: settings.sync.footer | shared: iOS+macOS (single edit point) -->

When on, this device shares the settings above with your other devices that also have this enabled. Turning it on adopts your existing iCloud settings; leave it off to keep this device's settings separate.

<!-- END SOURCE: settings.sync.footer -->

### Research Sessions

<!-- Settings ▸ Research ▸ Research Sessions. One view on both platforms. The recording footer still has TWO keys, but no longer for the original reason: the platforms once recorded into DIFFERENT stores (iOS wrote `.searchSubmit` session events, macOS wrote `SearchHistoryEntry`), and since Wave R-2a there is exactly one writer of each kind on both. What still differs is only what the surfaces are CALLED — macOS has the History window and Recents, iOS has the History screen plus Project Home's cards and tiles — so the two texts differ in their nouns and not in their substance.

This whole block was refreshed in Wave R-5. Every key below changed in R-2a, and this file had been left describing the R-1 wording, some of which had become false — see the per-entry notes. -->

#### Research-session recording footer (iOS)

<!-- Rewritten TWICE, each time under a NEW key, because no String Catalog ships and reusing a key with different text is a silent collision. R-1 replaced `settings.sessions.logging.footer` (which described a switch that governed the session log alone) with `…footer.trail`; R-4 replaced that with `…trail.v2` when iOS gained a `SearchHistoryEntry` writer; R-2a replaced THAT with `…trail.v3`, because sessions became derived rather than stored and exports joined the trail. The label stays "Log Research Sessions" (owner decision, R-0 Q3), so this footer carries the whole explanatory burden, including the behaviour change: History and Recents drain when the switch is off. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordingSection footer | lines: 189–190 | key: settings.sessions.logging.footer.trail.v3 | shared: iOS only (see the note above) -->

Despite the name, this switch covers everything the app remembers about your work — the documents you open, the text of the searches you run, and the collections you export. There is one record of each, shared by the History screen, a project's Recently Read and Recent Searches cards and its Documents Visited and Searches Run counts, and the Session Log, which groups them into sessions that end after 30 minutes of inactivity. All of it is kept on this device and, if iCloud sync is on, in your private iCloud database. Turning it off stops every part of that recording, so those will thin out and eventually be empty: that is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it.

<!-- END SOURCE: settings.sessions.logging.footer.trail.v3 -->

#### Research-session recording footer (macOS)

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordingSection footer | lines: 186–187 | key: settings.sessions.logging.footer.trail.mac.v2 | shared: macOS only (see the note above) -->

Despite the name, this switch covers everything the app remembers about your work — the documents you open, the text of the searches you run, and the collections you export. There is one record of each, shared by the History window, a project's Recents, and the Session Log, which groups them into sessions that end after 30 minutes of inactivity. All of it is kept on this device and, if iCloud sync is on, in your private iCloud database. Turning it off stops every part of that recording, so History and Recents will thin out and eventually be empty: that is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it.

<!-- END SOURCE: settings.sessions.logging.footer.trail.mac.v2 -->

#### Recorded-activity footer (empty)

<!-- One key on both platforms since Wave R-2a. A macOS variant used to exist because the session log read `SessionEvent`, which macOS never wrote for a search — so "run a search" would have been a promise the Mac did not keep. The log is derived from `SearchHistoryEntry` now, of which macOS has always been a producer, so the fence is gone. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordedActivitySection footer | lines: 228–229 | key: settings.sessions.activity.footer.empty | shared: iOS+macOS (single edit point) -->

Nothing has been recorded yet. Open a document or run a search and it will appear here.

<!-- END SOURCE: settings.sessions.activity.footer.empty -->

#### Recorded-activity footer (non-empty)

<!-- Wave R-2a, NEW key. The R-1 text under `settings.sessions.activity.footer` said "No other part of the app reads this log — it is groundwork for a research-trail view." That was true of the `SessionEvent` store and became false the moment the log was derived from the same reading, search and export history the History surface and Project Home are built from. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordedActivitySection footer | lines: 235–236 | key: settings.sessions.activity.footer.derived | shared: iOS+macOS (single edit point) -->

Sessions are not stored — they are worked out from the times you opened documents, ran searches and exported collections, with a gap of 30 minutes starting a new one. The same records fill the History screen and a project's Recents.

<!-- END SOURCE: settings.sessions.activity.footer.derived -->

#### Delete-sessions footer

<!-- Wave R-2a, NEW key. The R-1 text under `settings.sessions.manage.footer.trail` ended "…and so does the reading and search history the switch above also governs — this button does not reach that." That gap is closed: sessions are derived from that history, so deleting sessions IS deleting it, and the button now calls `HistoryTrailAdmin.deleteAll`. Leaving the old sentence in place would have under-warned about an irreversible, CloudKit-propagating delete. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.manageSection footer | lines: 263–264 | key: settings.sessions.manage.footer.whole | shared: iOS+macOS (single edit point) -->

Deletes the whole record of your work: every document you opened, every search you ran, and every collection you exported, on this device and — if iCloud sync is on — in your iCloud database. Your notes, highlights, tags and collections are not touched. You can also delete single entries from the History screen.

<!-- END SOURCE: settings.sessions.manage.footer.whole -->

#### iCloud unavailable (Local Only) detail
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 228–229 | key: settings.icloud.localOnly.detail | shared: iOS only (the macOS status lives in the main window's status bar) -->

iCloud sync is unavailable. Notes, tags, and collections won't sync across devices. Check that you are signed in to iCloud in Settings and that FRUS Explorer has iCloud access.

<!-- END SOURCE: settings.icloud.localOnly.detail -->

#### iCloud zone-missing detail
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 304–305 | key: settings.icloud.zoneMissing.detail | shared: iOS only (the macOS status lives in the main window's status bar) -->

The iCloud sync zone is missing. Data cannot upload or download until it is recreated. Force-quit and relaunch the app, or use Settings → Data & Recovery → Fix iCloud Sync.

<!-- END SOURCE: settings.icloud.zoneMissing.detail -->

---

### Volumes & Storage (Library)

<!-- The merged Library destination. Replaces the retired Volume Updates and Storage & Backup subsections, whose keys (`settings.volumes.updates.footer`, `settings.storage.aggregate.footer`, `settings.storage.backup.note`) went with the panes S-2b/S-2c deleted. The hub is still TWO views — VolumesStorageHubView.swift for iOS, MacVolumesStorageHub.swift for macOS — so each footer below is a separate edit point unless noted. -->

#### Keeping Current footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | keepingCurrentSection footer | lines: 519–520 | key: settings.hub.keepingCurrent.footer | shared: iOS (macOS carries the same text separately in MacVolumesStorageHub.swift) -->

Updating re-downloads and re-indexes a volume. Your notes, highlights, tags, and summaries are preserved.

<!-- END SOURCE: settings.hub.keepingCurrent.footer -->

#### Storage & Index footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | storageAndIndexSection footer | lines: 589–590 | key: settings.hub.storageIndex.footer | shared: iOS (macOS carries the same text separately) -->

Notes, highlights, and tags are never affected. For reference: the full FRUS corpus is roughly 3.4 GB of XML plus 9–10 GB of search index.

<!-- END SOURCE: settings.hub.storageIndex.footer -->

#### Rebuild From Scratch — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | rebuild confirmation | lines: 189–190 | key: settings.hub.rebuild.message | shared: iOS (macOS carries the same text separately) -->

This deletes the entire search index — full-text rows, cross-references, page ranges, document dates, person mentions, and the document cache — then rebuilds it by re-parsing all \(volumes) you have downloaded.

Your research notes, highlights, summaries, collections, and tags are stored separately and are not affected.

<!-- END SOURCE: settings.hub.rebuild.message -->

#### Free Up Space — removal confirmation

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | MacManageStorageSheet / FreeUpSpaceSheet confirmation | lines: 1656–1657 | key: settings.hub.freeUp.confirm.message | shared: iOS+macOS (single edit point — the Mac adopted these keys when its missing confirmation was added) -->

The XML files and their search-index rows are deleted from this device. Every one of these volumes can be downloaded again.

<!-- END SOURCE: settings.hub.freeUp.confirm.message -->

#### Free Up Space — size-estimate note

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | FreeUpSpaceSheet | lines: 1605–1606 | key: settings.hub.freeUp.estimateNote | shared: iOS (macOS carries the same text separately) -->

Sizes are the XML file plus an estimated 2.8× search-index contribution (measured across the full corpus: ~9–10 GB of index for ~3.4 GB of XML). Per-volume overhead ranges from roughly 2.5× to 3×, so treat these as approximate.

<!-- END SOURCE: settings.hub.freeUp.estimateNote -->

#### Needs Attention footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | needsAttentionSection footer | lines: 427–428 | key: settings.hub.interrupted.footer | shared: iOS (macOS carries the same text separately) -->

These volumes were being indexed when the app last quit. Shown only when something needs you.

<!-- END SOURCE: settings.hub.interrupted.footer -->

#### Download options footer (iOS only)

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | optionsSection footer | lines: 699–700 | key: settings.hub.options.footer | shared: iOS only — absorbed the retired iCloud-Backup exclusion note -->

Volume files are large; Wi-Fi is recommended. Downloaded XML is excluded from iCloud Backup — it can be re-downloaded at any time.

<!-- END SOURCE: settings.hub.options.footer -->

### Connections (System)

<!-- The merged outside-services destination (S-4a). One shared view, so these are single edit points. -->

#### Connections footer

<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | ConnectionsView services section footer | lines: 51–52 | key: settings.connections.footer | shared: iOS+macOS (single edit point) -->

Both keys are held in your keychain and travel with iCloud Keychain to your other devices. Neither service is required — the app works without them.

<!-- END SOURCE: settings.connections.footer -->

#### NARA Catalog — about

<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | NARACatalogConnectionView About section | lines: 252–253 | key: settings.connections.nara.about | shared: iOS+macOS (single edit point) -->

A free key from the National Archives Catalog. Source Explorer needs it to search lot files and Presidential Library records; everything else in the app works without it.

<!-- END SOURCE: settings.connections.nara.about -->

#### Zotero — about

<!-- SOURCE: FRUSExplorer/Settings/ConnectionsView.swift | ZoteroConnectionView About section | lines: 488–489 | key: settings.zotero.about.body | shared: iOS+macOS (single edit point) -->

Send FRUS documents — with your tags and research notes — straight into your Zotero library, where they sync to all your devices including the Zotero iOS app. This is the only way to get FRUS annotations into Zotero on iPhone and iPad.

<!-- END SOURCE: settings.zotero.about.body -->

### Data & Recovery (System)

<!-- The merged export/diagnostics/recovery destination (S-4b). Replaces the retired Reset & Data Safety subsection: the recovery ladder renamed its rungs, so all seven `settings.reset.*` keys are gone. -->

#### Recovery ladder footer

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | recoverySection footer | lines: 186–187 | key: settings.dataRecovery.recovery.footer | shared: iOS+macOS (single edit point) -->

In order of how much they take away. Try the first one first — it is the one that deletes nothing.

<!-- END SOURCE: settings.dataRecovery.recovery.footer -->

#### Fix iCloud Sync — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | fixSync confirmation | lines: 119–120 | key: settings.dataRecovery.fixSync.message | shared: iOS+macOS (single edit point) -->

The local copy of your synced data is cleared and pulled down again. Nothing in iCloud is deleted, so nothing is lost — the app returns to onboarding while it restores.

<!-- END SOURCE: settings.dataRecovery.fixSync.message -->

#### Reset This Device — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | resetDevice confirmation | lines: 135–136 | key: settings.dataRecovery.resetDevice.message | shared: iOS+macOS (single edit point) -->

Downloaded volumes and the search index go; your notes, highlights, tags, collections and projects stay in iCloud and come back on the next launch. You will need to download volumes again.

<!-- END SOURCE: settings.dataRecovery.resetDevice.message -->

#### Broken Cross-References report footer

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | reports section footer | lines: 305–306 | key: settings.export.brokenRefs.footer | shared: iOS+macOS (single edit point) -->

The corpus-wide list of cross-references in the printed FRUS volumes that point to a document, page, or volume not present in the corpus. The CSV lists distinct broken targets; the fuller per-occurrence spreadsheet with source line numbers is generated offline.

<!-- END SOURCE: settings.export.brokenRefs.footer -->

#### Research-data export — JSON footer

<!-- Wave R-5, NEW key (`settings.export.json.footer` listed six things; the file now carries seven). The research trail is named explicitly rather than folded into "your research data" because it is the part a reader would not assume was in there — and the part they may want to check before sharing the file, since it includes the text of every search they ran. -->

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections JSON section footer | key: settings.export.json.footer.trail | shared: iOS+macOS (single edit point — hosted by Data & Recovery on both) -->

A single JSON file containing your notes, tags, highlights, collections, custom prompts and projects, plus your research trail — every document you opened, every search you ran with the number of results it returned, and every collection you exported.

<!-- END SOURCE: settings.export.json.footer.trail -->

#### Erase Everything — warning

<!-- Wave R-5, NEW key. Wave R-2a extended `EraseEverythingView.performReset` to delete the whole research trail but left this list — the screen's entire account of what is about to go — unchanged, so the warning under-stated its own reach. -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | key: settings.erase.warning.trail | shared: iOS+macOS (single edit point — reached from the macOS Data & Recovery sheet) -->

This deletes every downloaded volume, the search index, and all of your research notes, projects, tags, collections, highlights, and AI-generated summaries — along with your whole research trail: every document you opened, every search you ran, and every collection you exported. Because your research data syncs, it goes from your other devices too. This cannot be undone.

<!-- END SOURCE: settings.erase.warning.trail -->

#### Erase Everything — first confirmation

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | lines: 1309–1310 | key: settings.erase.confirm1.message | shared: iOS+macOS (single edit point) -->

Everything listed above will be deleted from this device and from iCloud.

<!-- END SOURCE: settings.erase.confirm1.message -->

#### Erase Everything — final confirmation

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | lines: 1325–1326 | key: settings.erase.confirm2.message | shared: iOS+macOS (single edit point) -->

Export your research data first if you might want it back.

<!-- END SOURCE: settings.erase.confirm2.message -->

### Background Summarization

#### Continue-in-background footer
<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | BackgroundSummarizationSettingsView.backgroundContinuationSection footer | lines: 97–98 | key: bg.summarizer.continue.hint | shared: iOS+macOS (single edit point) -->

When on, summarization resumes opportunistically while the device is idle, a few documents at a time, even after you close the app. Uses the on-device model and some battery.

<!-- END SOURCE: bg.summarizer.continue.hint -->

---

### Discovery Tips (TipKit)

*Small popovers that appear beside easy-to-miss controls the first few times you reach them. Each
retires once the control is used. Every tip has a **title** and a **message**; both are editable.
The set is re-armable from Settings ▸ Display ▸ **Show Tips Again**.*

#### Tip — Your Research Tools Live Here
*iPhone / iPad only. Appears on the Research-rail toggle in the document toolbar.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ResearchRailTip.title | key: tip.researchRail.title | shared: iOS only -->

Your Research Tools Live Here

<!-- END SOURCE: tip.researchRail.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ResearchRailTip.message | key: tip.researchRail.message | shared: iOS only -->

Citations, the word cloud, archival sources, the cross-reference graph, related documents, and your notes, tags and collections for this document.

<!-- END SOURCE: tip.researchRail.message -->

#### Tip — Tap the Edges to Turn the Page
*iOS only. Appears over the document reading area.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | EdgeTapNavigationTip.title | key: tip.edgeTap.title | shared: iOS only -->

Tap the Edges to Turn the Page

<!-- END SOURCE: tip.edgeTap.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | EdgeTapNavigationTip.message | key: tip.edgeTap.message | shared: iOS only -->

In Read mode, tapping the left or right edge moves to the previous or next document in this volume — the order the editors arranged them in.

<!-- END SOURCE: tip.edgeTap.message -->

#### Tip — Four Ways to Read These Results
*iOS only. Appears on the binoculars menu above search results.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ExamineResultsTip.title | key: tip.examineResults.title | shared: iOS only -->

Four Ways to Read These Results

<!-- END SOURCE: tip.examineResults.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ExamineResultsTip.message | key: tip.examineResults.message | shared: iOS only -->

Place them on a timeline, line every occurrence up on your search term, rank the words that keep company with it, or break the whole match down by year, volume, person and provenance.

<!-- END SOURCE: tip.examineResults.message -->

#### Tip — Facet Rows Are Filters
*iPhone, iPad and macOS — the one tip with a shared anchor. Appears on the facet panel.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | FacetNarrowTip.title | key: tip.facetNarrow.title | shared: iOS+macOS (single edit point) -->

Facet Rows Are Filters

<!-- END SOURCE: tip.facetNarrow.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | FacetNarrowTip.message | key: tip.facetNarrow.message | shared: iOS+macOS (single edit point) -->

Tap any year, volume or person to narrow your search to it — it becomes a chip you can clear. The counts themselves always describe the whole match, before any narrowing.

<!-- END SOURCE: tip.facetNarrow.message -->

#### Tip — Browse References as a List
*iOS and macOS. Appears on the reference-list toggle in the cross-reference graph.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | GraphReferenceListTip.title | key: tip.graphList.title | shared: iOS+macOS (single edit point) -->

Browse References as a List

<!-- END SOURCE: tip.graphList.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | GraphReferenceListTip.message | key: tip.graphList.message | shared: iOS+macOS (single edit point) -->

Open a side panel listing every reference with its date, volume, and the footnote that linked it.

<!-- END SOURCE: tip.graphList.message -->

#### Tip — Timeline or Network
*iOS and macOS. Appears on the layout picker in the cross-reference graph.*

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | TimelineLayoutTip.title | key: tip.timeline.title | shared: iOS+macOS (single edit point) -->

Timeline or Network

<!-- END SOURCE: tip.timeline.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | TimelineLayoutTip.message | key: tip.timeline.message | shared: iOS+macOS (single edit point) -->

Timeline places each document at its date — earlier sources left, later responses right. Network shows the citation web instead.

<!-- END SOURCE: tip.timeline.message -->

#### The tip-recall control (Settings ▸ Display)

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | key: settings.display.tips.header | shared: iOS+macOS (single edit point) -->

Discovery Tips

<!-- END SOURCE: settings.display.tips.header -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | key: settings.display.tips.reset | shared: iOS+macOS (single edit point) -->

Show Tips Again

<!-- END SOURCE: settings.display.tips.reset -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | key: settings.display.tips.reset.done | shared: iOS+macOS (single edit point) -->

Tips will appear again as you reach the controls they point at.

<!-- END SOURCE: settings.display.tips.reset.done -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | DisplaySettingsView | key: settings.display.tips.footer | shared: iOS+macOS (single edit point) -->

Tips point out controls that are easy to miss — the Research button, the page-turn edges, the ways to read a result set. Each retires once you use the control it describes. This brings them all back.

<!-- END SOURCE: settings.display.tips.footer -->

---

### Collections Export

#### Native-format export explanation
<!-- SOURCE: FRUSExplorer/Collections/CollectionExportSheet.swift | CollectionExportSheet.nativeShareOptions | lines: 460–461 | key: export.native.hint | shared: iOS+macOS (single edit point) -->

Shares an editable copy of this collection — its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don’t have. Your research notes stay private unless you include them above.

<!-- END SOURCE: export.native.hint -->

Note: the apostrophe in "don’t" is a curly quote (U+2019), copied verbatim from source.

---

*End of editable content. Source locations span the About screen (§1), Onboarding (§2),
the 11-page Research Guide (§3), the four Series-analytics dashboards (§4), the analytics
captions & info popovers (§5), and the Settings / tips / Collections prose (§6). Annotations
were re-pinned to current source lines in the 2026-07 source→doc refresh; §1 gained the
FRUS Explorer license notice (§1.3) and §6 the word-cloud precompute footer — strings added
to the app after the previous revision. Blocks marked `shared: iOS+macOS` are a single edit
point (one localization key, or the shared FRUSTheme static) — there is no separate platform
duplicate to hunt for.*

*Reconciliation to do during revision: the Corpus Analytics search-syntax/dating popover (§5)
and the Word Cloud popover (§5) overlap the Research Guide's search and word-cloud pages
(§3.5–§3.6) — align wording, and add the Guide's "finding aid, not evidence" caveat to the
Word Cloud popover so the two surfaces don't drift.*

---

## 7. Search & Result-Set Copy
*The Query & Corpus Analysis wave (#602–#623) and the eight-issue wave (#629–#641). This material
is neither an analytics caption nor a settings footer — it is the prose that tells a researcher
what a number covers — so it has its own section. Almost all of it exists because a count that does
not say what it counted is worse than no count.*

---

### 7.1 The Query Inspector

*Source: `FRUSExplorer/Search/QueryInspectorView.swift`*

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.expressionsDiffer -->

Documents and your own summaries/notes are searched with different expressions, because only some of them are in scope.

<!-- END SOURCE: search.inspector.expressionsDiffer -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.stemWarning -->

*Interpolated: `\(term) is searched as \(stem) — other words with that root match too`. Keep both placeholders.*

%@ is searched as %@ — other words with that root match too

<!-- END SOURCE: search.inspector.stemWarning -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.inspector.denominator -->

*Interpolated with the indexed-volume count.*

Counts are over the %lld volumes indexed on this device — not the whole published series.

<!-- END SOURCE: search.inspector.denominator -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.empty.combination -->

Each of your terms matches something on its own — it is the combination that appears in no single document.

<!-- END SOURCE: search.empty.combination -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.empty.oneEmpty -->

*Interpolated with the term that matched nothing.*

%@ matches no document in your current scope. The rest of your query is not the problem.

<!-- END SOURCE: search.empty.oneEmpty -->

<!-- SOURCE: FRUSExplorer/Search/QueryInspectorView.swift | key: search.empty.denominator -->

*Interpolated with the indexed-volume count.*

0 here means 0 in what you have indexed — %lld volumes on this device.

<!-- END SOURCE: search.empty.denominator -->

---

### 7.2 Reading a Result Set — the four modes

*Source: `FRUSExplorer/Search/SearchView.swift, SearchSheet.swift`*

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | key: search.mode.help -->

Read the results you have as a timeline, as your search term in context, or as the words that occur near it — or break the whole match down by year, volume, person, type and provenance.

<!-- END SOURCE: search.mode.help -->

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | key: search.facets.on.help.v2 -->

Break the whole match down by year, volume, person, type and provenance — before any narrowing you apply

<!-- END SOURCE: search.facets.on.help.v2 -->

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | key: search.kwic.show.help.v2 -->

Show every occurrence of your term on its own line, aligned — for the documents on this page

<!-- END SOURCE: search.kwic.show.help.v2 -->

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | key: search.cap.tooltip -->

*Interpolated with the loaded and total counts.*

Showing %lld of %lld matches. Narrow your search with a date range, volume filter, or more specific terms to see every result.

<!-- END SOURCE: search.cap.tooltip -->

<!-- SOURCE: FRUSExplorer/Search/SearchView.swift | key: search.cap.tooltip.unknownTotal -->

*Interpolated with the loaded count.*

Showing the first %lld matches. The total could not be counted, so there may be many more — narrow your search with a date range, volume filter, or more specific terms.

<!-- END SOURCE: search.cap.tooltip.unknownTotal -->

---

### 7.3 Facets

*Source: `FRUSExplorer/Search/FacetPanelView.swift`*

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.preamble.detail -->

Facets read the whole match, before any narrowing you apply below.

<!-- END SOURCE: facets.preamble.detail -->

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.checklistNote -->

*Interpolated with the shown count.*

Checklist mode is hiding reviewed results. These facets still describe the whole match, not the %lld shown.

<!-- END SOURCE: facets.checklistNote -->

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.undated -->

*Interpolated with the undated count.*

%lld matched documents carry no date and appear in no year above.

<!-- END SOURCE: facets.undated -->

<!-- SOURCE: FRUSExplorer/Search/FacetPanelView.swift | key: facets.provenance.coverage -->

*Interpolated with three counts. This is the two-denominator caveat — parsed at all vs. named a record group — and both numbers matter.*

Source notes parsed for %lld of %lld matches; %lld name a record group.

<!-- END SOURCE: facets.provenance.coverage -->

---

### 7.4 Concordance (keyword in context)

*Source: `FRUSExplorer/Search/ConcordanceView.swift`*

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.empty.detail -->

These results matched, but none of their text could be aligned on your search term. Phrase, wildcard and proximity searches match in ways a concordance cannot centre on a single word.

<!-- END SOURCE: search.kwic.empty.detail -->

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.omitted -->

*Interpolated with the omitted count and the per-document line cap.*

%lld further occurrences aren't shown — each document contributes at most %lld lines.

<!-- END SOURCE: search.kwic.omitted -->

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.unaligned -->

*Interpolated with a document count.*

%lld matching documents contributed no line — their match isn't a whole word this view can centre on.

<!-- END SOURCE: search.kwic.unaligned -->

---

### 7.5 Collocation — the words near your term

*Source: `FRUSExplorer/Search/CollocationView.swift`*

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.noArtifact -->

The bundled corpus reference could not be loaded, so there is nothing to measure these neighbourhoods against.

<!-- END SOURCE: search.collocation.unavailable.noArtifact -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.mismatch -->

*Interpolated with the setting that differs.*

Your Word Cloud settings count words differently from the bundled corpus reference, so the two can't be compared: %@. Restore that setting to rank these neighbours.

<!-- END SOURCE: search.collocation.unavailable.mismatch -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.noMatches -->

None of these results contains a whole word this measure can centre on. Phrase, wildcard and proximity searches match in ways a word window cannot anchor to.

<!-- END SOURCE: search.collocation.unavailable.noMatches -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.floor -->

*Interpolated with the minimum-count floor.*

No word appears at least %lld times near your matches. A word occurring once or twice can top a ranking without saying anything about the documents, so nothing is ranked. Widening the window, or a broader search, will give it more to work with.

<!-- END SOURCE: search.collocation.unavailable.floor -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.nothingDistinctive -->

Nothing near your matches is used more here than across the corpus. That is a real result, not an error: this query sits in ordinary FRUS prose.

<!-- END SOURCE: search.collocation.unavailable.nothingDistinctive -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.caveat.bounded.v2 -->

*Interpolated with the scanned and total counts.*

The scan stopped at %lld of your %lld results, so this ranking covers part of them, not all.

<!-- END SOURCE: search.collocation.caveat.bounded.v2 -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.caveat.unpriced -->

*Interpolated with the reference cutoff.*

Words occurring fewer than %lld times corpus-wide are unpriced and score as if new.

<!-- END SOURCE: search.collocation.caveat.unpriced -->

---

### 7.6 What a reading actually covers

*Source: `FRUSExplorer/Search/ResultSetScope.swift`*

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.collocation.caveat.scope.loaded.capped -->

Measured over every result this search loaded, not the page on screen — those are the highest-scoring matches, not a sample of all of them.

<!-- END SOURCE: search.collocation.caveat.scope.loaded.capped -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.collocation.caveat.scope.loaded.complete -->

Measured over every result this search loaded, which is every matching document.

<!-- END SOURCE: search.collocation.caveat.scope.loaded.complete -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | key: search.timeline.bias -->

These are the highest-scoring matches, not a sample across time — this shape is theirs, not the whole match's.

<!-- END SOURCE: search.timeline.bias -->

---

### 7.7 Working corpora

*Source: `FRUSExplorer/Settings/WorkingCorporaView.swift, SaveWorkingCorpusSheet.swift, SearchFilterView.swift`*

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpora.footer -->

A working corpus is a fixed set of documents, captured once. It syncs to your other devices whole, so a count taken inside it means the same thing everywhere — even where fewer of its volumes are indexed.

<!-- END SOURCE: corpora.footer -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpora.empty.detail -->

Run a search, then choose "Save as Working Corpus" to fix those results as a named set you can search inside later.

<!-- END SOURCE: corpora.empty.detail -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpus.save.footer -->

The set is fixed at capture. Re-running the query later may find different documents; this corpus will not change, which is what makes counts taken inside it reproducible.

<!-- END SOURCE: corpus.save.footer -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpus.save.truncated.total -->

*Interpolated with the captured and total counts.*

These %1$@ documents are the highest-scoring of %2$@ matching documents. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.truncated.total -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpus.save.truncated.unknown -->

*Interpolated with the captured count.*

These %@ documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.truncated.unknown -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpus.save.checklistHiding -->

*Interpolated with the hidden count.*

Checklist mode is hiding %@ reviewed documents. They will not be in this corpus.

<!-- END SOURCE: corpus.save.checklistHiding -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: search.corpus.footer -->

A working corpus is a fixed set of documents. Applying one searches only inside it. Manage them in Settings.

<!-- END SOURCE: search.corpus.footer -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: search.corpus.noneIndexed -->

*Interpolated with the corpus name.*

None of "%@" is indexed on this device yet — download and index its volumes first.

<!-- END SOURCE: search.corpus.noneIndexed -->

---

### 7.8 The method appendix

*Source: `FRUSExplorer/Export/QueryMethodAppendix.swift, ResearchDataExportView.swift`*

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.snapshot -->

Each count is what the search returned when it ran, over the volumes downloaded to that device at that moment. It is not re-run, and it will not match a search run today against a larger index.

<!-- END SOURCE: appendix.caveat.snapshot -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.zero.one -->

One of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.

<!-- END SOURCE: appendix.caveat.zero.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.zero.many -->

*Interpolated with a count. Kept separate from the singular above because there is no String Catalog to inflect it.*

%lld of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.

<!-- END SOURCE: appendix.caveat.zero.many -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.floor.one -->

One search hit the app's row ceiling. Its count is shown as "at least N" and is a floor, not a total — do not sum it with the others.

<!-- END SOURCE: appendix.caveat.floor.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.floor.many -->

*Interpolated with a count.*

%lld searches hit the app's row ceiling. Those counts are shown as "at least N" and are floors, not totals — do not sum them.

<!-- END SOURCE: appendix.caveat.floor.many -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.unrecorded.one -->

One search predates this app version and recorded only a result count, with no record of the scope, the ceiling, or how many volumes were indexed. It is marked "as reported" and cannot be checked against the others.

<!-- END SOURCE: appendix.caveat.unrecorded.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.unrecorded.many -->

*Interpolated with a count.*

%lld searches predate this app version and recorded only a result count, with no record of the scope, the ceiling, or how many volumes were indexed. They are marked "as reported" and cannot be checked against the others.

<!-- END SOURCE: appendix.caveat.unrecorded.many -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.attribution -->

Text from Foreign Relations of the United States, Office of the Historian, U.S. Department of State (public domain).

<!-- END SOURCE: appendix.attribution -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: settings.export.appendix.footer -->

Every search you ran, with the scope it ran under and how many volumes were indexed at the time — as a Markdown table and a CSV. Counts that hit the app's row ceiling are shown as "at least N", so a partial result is never presented as a total.

<!-- END SOURCE: settings.export.appendix.footer -->

---

### 7.9 Occurrence counts — when they are refused, and why

*Source: `FRUSExplorer/Analytics/OccurrenceAvailability.swift, AnalyticsView.swift`*

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.measure.help -->

Count matching documents, or every occurrence of the word. A term mentioned fifty times in one document is one document and fifty occurrences — the two can move in opposite directions.

<!-- END SOURCE: analytics.measure.help -->

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.occurrences.unavailable.exact -->

Occurrence counts aren't available for exact-word searches: the index stores word stems, so it cannot tell one exact spelling's occurrences from another's.

<!-- END SOURCE: analytics.occurrences.unavailable.exact -->

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.occurrences.unavailable.multiTerm -->

Occurrence counts aren't available for phrases, wildcards or proximity searches — those match several index terms, which have no single occurrence count.

<!-- END SOURCE: analytics.occurrences.unavailable.multiTerm -->

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.occurrences.unavailable.composite -->

Occurrence counts aren't available for queries with more than one term: adding up occurrences of each would count two different things as one.

<!-- END SOURCE: analytics.occurrences.unavailable.composite -->

<!-- SOURCE: FRUSExplorer/Analytics/OccurrenceAvailability.swift | key: analytics.occurrences.unavailable.notSingleToken -->

This term indexes as several separate words, so it has no single occurrence count.

<!-- END SOURCE: analytics.occurrences.unavailable.notSingleToken -->

---

### 7.10 Bulk summarization

*Source: `FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift, BackgroundSummarizationService.swift`*

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.concurrency.hint.v2 -->

Apple Intelligence generates one summary at a time, so a higher number does not speed up the model itself. It helps when your Mac is busy with other work, and it makes the first summary take longer to appear.

<!-- END SOURCE: bg.summarizer.concurrency.hint.v2 -->

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.concurrency.hint.background -->

*iOS only.*

Once a run continues in the background, iOS processes documents one at a time regardless of this setting.

<!-- END SOURCE: bg.summarizer.concurrency.hint.background -->

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.start.duration -->

Summarizing a large scope can take several hours. You can keep working while it runs.

<!-- END SOURCE: bg.summarizer.start.duration -->

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.start.quitting -->

*macOS only.*

Quitting FRUS Explorer stops the run. Summaries already written are kept.

<!-- END SOURCE: bg.summarizer.start.quitting -->

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | key: bg.summarizer.failed.unavailable -->

*Interpolated with the succeeded and attemptable counts.*

Apple Intelligence became unavailable. Stopped after %lld of %lld documents.

<!-- END SOURCE: bg.summarizer.failed.unavailable -->


---

## 8. Repository README

*The public-facing description of the project at `README.md` — the first thing anyone sees on the
repository. It is prose you may want to rewrite, so it round-trips here like everything else.*

*Unlike every other block in this file, this one is the **whole file**, not a string inside Swift
source. Edit it freely; the whole thing is written back to `README.md`.*

*Condensed 2026-08-02 (build 37) from 385 lines to 162. The review that drove it found eleven false
or stale claims — a search cap that had doubled, a ⌘F shortcut that had moved to ⌘S, a window-scene
table missing eleven scenes and naming one that no longer exists, a "600+ tests" count that
understated by four times, and a pbxproj UUID convention that does not exist. The rule that keeps it
short: **build, test and generator commands live in `CLAUDE.md`, and features live in the user
manuals.** The README points at both rather than restating either, so there is only one copy of each
to keep correct.*

<!-- SOURCE: README.md | key: repo.readme | whole-file -->

# FRUS Explorer

A macOS, iPadOS, and iOS application providing tools to help researchers use the
[Foreign Relations of the United States (FRUS)](https://history.state.gov/historicaldocuments)
series more effectively.

FRUS is the official documentary record of U.S. foreign policy since 1861. The app's bundled
manifest covers 552 volumes; a full local index holds roughly 317,000 documents. FRUS Explorer
downloads the Office of the Historian's TEI editions, indexes them on your device, and adds the
reading, searching, sourcing and analysis tools a corpus that size needs — all of it working
offline once volumes are downloaded.

It is an independent project, developed with [Claude Code](https://claude.ai/code), and is **not**
an official product of the Office of the Historian or the U.S. Department of State. Current build:
**37** (version 0.2).

## Screenshots

| Search (macOS) | Cross-reference graph (macOS) | Reading (iPhone) |
|---|---|---|
| ![Search results with facets and filters](Docs/screenshots/macos/search.png) | ![Cross-reference graph](Docs/screenshots/macos/cross-reference-graph.png) | ![Document view](Docs/screenshots/ios/document-view.png) |

More in [`Docs/screenshots/`](Docs/screenshots).

## What it does

- **Read** — TEI documents rendered with footnotes, page breaks, and live cross-references, plus
  highlights, notes, and a per-document Research rail.
- **Search** — full-text FTS5/BM25 search with stemming, phrases, `NEAR(...)` proximity,
  `=exact` word matching, saved scopes, and working corpora captured from a result set.
- **Read a result set four ways** — ranked list, timeline, concordance (every hit lined up on the
  search term), and collocates (the words that keep company with it).
- **Inspect the query** — the Query Inspector shows the FTS5 expression your search actually became,
  each term's index form, and its corpus-wide versus in-scope counts.
- **Facet** — break a result set down by year, volume, person, document type, and archival
  provenance; tap a row to narrow.
- **Analyse** — corpus, series, person, and cross-reference dashboards; a chronology view; and a
  word cloud with keyness and collocation.
- **Trace sources** — Source Explorer resolves FRUS source notes to NARA record groups, lot files,
  and collections, with archival neighbours and cross-volume provenance, from bundled indexes.
- **Organise** — projects, collections, exports (PDF, HTML, Word, BibTeX, RIS), Zotero, a research
  trail, and iCloud sync of your own work.
- **Summarize** — on-device Apple Intelligence summaries, one document at a time or as unattended
  bulk runs, with authorship recorded on every summary.

For anything beyond this list, read the user manuals — they are the feature documentation.

## Stated coverage, stated limits

The app is built on the premise that a research tool must not round its own uncertainty away.

Cross-references validated as dead render as muted, explained text rather than posing as working
links. Source Explorer distinguishes "no documents in your indexed volumes cite this" — an explicit
zero — from a note it could not parse. Analytics surfaces state their indexed coverage
("142 of 267") rather than silently resolving to a smaller set. The word cloud's keyness measure
refuses to compare at all when live tokenisation settings diverge from its bundled reference. The
four result readings each say which set they counted, because when you are about to quote a number
that distinction *is* the number. "Why related" chips report only what their signal can support —
a count of citations, or simply *same provenance*, where a percentage would be meaningless. The
JSON research export records whether each summary was written by the model, edited by you, or
written by you.

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
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — `project.yml` is the
  source of truth for the Xcode project.
- An Apple Developer account for signing, with iCloud/CloudKit, Keychain Sharing, and Background
  Modes capabilities.

## Getting the app

Test builds are distributed through TestFlight:

- [TestFlight instructions — iPhone and iPad](Docs/TestFlight-Instructions-ios.md)
- [TestFlight instructions — Mac](Docs/TestFlight-Instructions-mac.md)

## Documentation

- [iOS / iPadOS User Manual](Docs/iOS-User-Manual.md) — the full feature documentation.
- [macOS User Manual](Docs/macOS-User-Manual.md) — the same, for the Mac app.
- [`Planning/FRUS-Explorer-Specification.md`](Planning/FRUS-Explorer-Specification.md) — the design
  specification.
- [`CLAUDE.md`](CLAUDE.md) — build, test, and data-generator commands; coding standards; release
  gates. This is the maintainer's reference and the canonical copy of every command.

## How it works

Volumes are TEI XML files published by the Office of the Historian. The app downloads them per
volume, parses each into an abstract syntax tree, and serializes that to HTML rendered in a web
view — so footnotes, page breaks, and internal references keep their editorial structure rather
than being flattened into plain text.

Search is SQLite FTS5 with BM25 ranking and English stemming, built on device as volumes finish
downloading. Everything you write — notes, tags, highlights, collections, projects, prompts — lives
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
`git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.** Build and version bumps must not
go through XcodeGen at all; see `CLAUDE.md` for that procedure.

Two shared schemes: `FRUSExplorer` (iOS/iPadOS) and `FRUSExplorerMac`. Test, generator, and release
commands all live in [`CLAUDE.md`](CLAUDE.md) — they are not repeated here so there is only one copy
to keep correct.

macOS Direct Distribution builds are archived, notarized, stapled, and packaged as a DMG by
[`Scripts/notarize.sh`](Scripts/notarize.sh). Run it with `--dry-run` first; the script's header
documents its prerequisites and options.

## Data and credits

- The **FRUS series** is published by the [Office of the Historian](https://history.state.gov),
  U.S. Department of State, and is in the public domain. TEI editions come from the
  [HistoryAtState](https://github.com/HistoryAtState) repositories.
- The bundled person-authority crosswalk derives from the Office of the Historian's public-domain
  (CC0) `HistoryAtState/people` registry; volume subject profiles derive from its public-domain
  `frus-subjects` document–subject mappings.
- Archival records come from the
  [National Archives Catalog](https://www.archives.gov/research/catalog/help/api). FRUS Explorer is
  not affiliated with, endorsed by, or sponsored by NARA, and catalog data is subject to NARA's
  terms of use.
- TEI rendering approaches were informed by the [TEI Publisher](https://teipublisher.com) project
  (Apache 2.0).

Commentary, advice, and guidance about the FRUS series contained in the application reflect personal
views and not necessarily those of the Department of State or the U.S. Government.

## License

Apache 2.0. See [LICENSE](LICENSE) for the full license text.

All source files carry the Apache 2.0 license header.

## Contributing

Read [`CLAUDE.md`](CLAUDE.md) for the architecture, build commands, and coding standards, and
[`Planning/DEVELOPMENT-PLAN.md`](Planning/DEVELOPMENT-PLAN.md) for the session sequence. Both app
targets must build and the full test suite must pass before a change lands. Update
`FRUS-API.openapi.yaml` when you touch a stored or queryable data surface — that one is
mechanically enforced.
<!-- END SOURCE: repo.readme -->
