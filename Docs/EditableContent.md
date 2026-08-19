# FRUS Explorer — Editable Static Content

This file contains the user-facing editorial prose across FRUS Explorer: the About screen, the
onboarding welcome, the in-app FRUS Research Guide, the Series and Archival analytics dashboards,
the analytics info popovers and captions, the Source Explorer panels, the methods statements
stamped on every export, and the explanatory footers in Settings. Edit the text directly. When you
are done, hand the file back and the changes will be written to the source code.

**Regenerated from source: 2026-08-09 (build 38). Amended 2026-08-16 for build 42.**

The build-42 amendment adds **§13**, which covers the semantic map and the Settings section that
governs its files — a surface this file had never carried, and which grew a great deal in this
release. It also refreshes four blocks in §6 and §7 whose text *and* localization key changed in the
build-42 plain-language pass, so the prose here matches what ships. Every string in §13 was read
out of the source rather than transcribed.

Those short strings now have blocks: **§14** carries the storage hubs' reindex controls, the
document reader's person and term popovers, the Collections search-unavailable notice, the Zotero
rate-limit error, and every other key the build-42 and build-43 sessions bumped without a block —
31 in all, each read out of the source.

**The plain-language pass (2026-08-09).** 126 of the app's longest strings were rewritten to read
more plainly, and 122 of them changed. The rule was that plainer must not mean vaguer: every
number, every stated limitation, and every refusal to claim more than the data supports survives,
usually promoted out of a trailing clause into a sentence of its own. If a revision below reads as
having *lost* a caveat rather than unpacked one, that is a defect — say so and it goes back.

Five rewrites were rejected during review because the plainer wording claimed more than the
original: "most heavily used" for a ranking that measures how many volumes cite a collection;
"covers the whole series" for what was only an independence claim; "exact phrase" for an index
that is stemmed and has a separate exact-word mode; "the collections cited alongside it" for a
graph that also draws class nodes; and "arrangement" for the app's own named Composition setting.
They are recorded here because they are the failure mode to watch for in your own edits.

**What is new in this regeneration**
 - **§9 Archival Analytics** — the four modes (Collections, Network, Flows, Your Library), their
   captions, caveat blocks, empty states and info popover. None of it was in this file before.
 - **§10 Export method statements** — the prose stamped above the numbers in an exported CSV or
   figure, for the archival surfaces and for the four About-the-Series dashboards. This is what a
   reader sees when the file has travelled without the app, so it has to stand alone. (§5 already
   carried the corpus, Person, Cross-Reference and Word Cloud statements.)
 - **§11 Source Explorer** — the panel prose: what a citation resolved to, what it did not, and
   what to do about it. Note that nearly every key here exists twice, once per platform.
 - **§12 Word Cloud keyness** — the two measures, and every state in which the app refuses to
   score rather than show a number it cannot stand behind.
 - Smaller additions inside existing sections: a **Display & Reading** subsection in §6, the
   heat-matrix subtitle in §5, the detected-topic facet footers in §7, and the Data & Recovery
   strings for schema-pending and store-mismatch.
 - **§7.11 has been moved** back inside §7, where it belongs; it had been sitting after the README.

**Earlier amendments**, kept for the record: 2026-08-01 (#597 PR 2) added seven Research Guide
sections for the Query & Corpus Analysis wave to §3; 2026-08-02 (build 37) added §7 and §8,
rewrote §6's Discovery Tips block, and corrected three stale Research Guide blocks.

**A note on the `lines:` field.** It is advisory and it rots — a third of the annotations had
drifted within five weeks of the previous regeneration, some by several hundred lines. **`key:` is
the real address.** If a `lines:` range and a `key:` disagree, the key wins; do not use the line
numbers to navigate.

**Three blocks name a key the code no longer has** — `settings.erase.warning.trail` and the two
`tip.examineResults.*` keys. Their text is left in place rather than deleted, because deciding
whether the copy went away with the feature or was merely renamed is an editorial call, not a
mechanical one.

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

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: frusDescriptionRaw | lines: 243–255 | key: about.frus.description -->

The **Foreign Relations of the United States** (FRUS) series is the official documentary record of U.S. foreign policy. The Department of State has published it continuously since 1861. The series now runs to more than 550 volumes, covering 1861 through the early 1990s.

What the series covers has changed over time. Recent volumes document U.S. bilateral and regional relations around the world, and how U.S. policymakers responded to unfolding crises. They cover global issues such as human rights, terrorism, narcotics, health, and the environment. They also cover thematic topics such as national security policy, foreign economic policy, and foreign affairs organization and management. Scholars, policymakers, and citizens use FRUS to trace the origins of today's challenges and the United States's role in the world.

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

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: openSourceSection | lines: 505–506 | key: about.openSource.appLicense.body -->

Licensed under the Apache License, Version 2.0. View source and contribute on GitHub.

<!-- END SOURCE: about.openSource.appLicense.body -->

---

### 1.4 Open Source — TEI Publisher Notice

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: openSourceSection | lines: 531–532 | key: about.openSource.teiPublisher.body -->

TEI rendering approaches informed by the TEI Publisher project (teipublisher.com). Licensed under the Apache License, Version 2.0.

<!-- END SOURCE: about.openSource.teiPublisher.body -->

---

### 1.5 NARA Disclaimer

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: naraDisclaimerSection | lines: 554–560 | key: about.nara.disclaimer -->

FRUS Explorer is not affiliated with, endorsed by, or sponsored by the National Archives and Records Administration (NARA). NARA Catalog data accessed through this app is provided by the National Archives and is subject to their terms of use.

<!-- END SOURCE: about.nara.disclaimer -->

---

### 1.6 DOS Disclaimer

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: dosDisclaimerSection | lines: 591–597 | key: about.dos.disclaimer -->

FRUS Explorer is an independent research tool. It is not an official product of the Office of the Historian or the U.S. Department of State. Any commentary, advice, or guidance about the FRUS series in this app reflects personal views. Those views are not necessarily those of the Department of State or the U.S. Government. The FRUS series itself is in the public domain.

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
- `onboarding.ready.body.empty` — Nothing is downloading yet — browse the corpus and add volumes whenever you like. Your project “My Research” is ready.
  Shown instead of the line above when the reader reaches Finish with nothing downloading (Skip,
  or a scope that enqueued no volumes), where that line's two promises would both be false.

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

They do not all count the same thing, and each panel names the set it used. The concordance shows the page you are on; facets read the whole match; the timeline and collocates cover the results retained for this search.

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

<!-- section-id: archival-analytics -->

**Archival Analytics**

Every published FRUS document carries a source note naming the archival file its original was found in. Read one at a time they are citations; clustered across the whole series they answer a question no volume states outright — which bodies of records each era's editors actually worked in. Archival Analytics is where that clustering is shown: era-by-era rankings of the collections and filing-system classes the volumes drew on, a co-citation network of which collections were used together, the editors' cross-reference flows between archival units, and an archival profile of your own indexed volumes.

Scope it to a subseries, a saved volume scope, a detected topic, or one president's volumes — and note that it scopes over the whole series rather than over your library, so the same scope gives the same figures on any device, with nothing downloaded. Counts can be read as documents or as volumes; those are different questions and give different answers.

These figures show where the editors drew their documents, which is an editorial and archival signal rather than a census of the archives themselves. The rankings say what was cited, not what exists.

Find it from the Browse tab's Analysis Tools menu (iOS) or the Archival Analytics window (Mac), and from the "Open Archival Analytics" link on the Archival Sourcing page of this guide.

<!-- section-id: semantic-analytics -->

**Semantic Analytics**

Every other analytics surface measures something the corpus states — who is named, what cites what, where a document came from. Semantic Analytics measures how the language sits. Every document in the series is placed on one map by the shape of its wording, so documents that read alike land near each other whether or not they share a volume, a date, or a citation. Regions are named by the vocabulary that distinguishes them from the rest of the corpus.

You can colour the map four ways — by region, by coverage era, by what is downloaded on this device, or by provenance: the archival category most of each volume's source notes name, which shows the State Department's central files giving way to the presidential libraries across the plane. A key under the map names the colours, except on Regions, where colour separates neighbouring regions and the names are drawn on the map itself. Tap a point to see which document it is and open it. Draw a lasso around an area to keep everything inside it as a working corpus, which you can then use to scope a search. Or tap two documents as poles and lay the whole series along the axis between them: the axis runs between the two documents' volumes, so two documents from the same volume give no axis, and a slice replaces the vertical axis with each volume's coverage year.

You can also **scope** the map with the same control the other analytics surfaces use — a subseries, one of your own volume scopes, a detected topic, or a president's volumes. Scoping does not shrink the map: the rest of the corpus stays on screen in grey, and the documents in scope keep their colour, so you can see where an editorial or political segment actually falls in the corpus's language. Region names re-rank to the regions the scope fills, and taps and lassos apply only to it. Note the grain: every scope here is a set of whole volumes, so a detected-topic scope lights every document in the volumes carrying that tag rather than only the documents on that subject.

This is a model's reading of the language, not an editorial fact, and it is experimental. Two cautions in particular. The map's plane preserves local similarity: neighbours are meaningfully near each other, but the distance between two far-apart regions means nothing. And the model was not measured on nineteenth-century prose, so placements in the earliest volumes are a declared unknown rather than a checked result.

Find it from the Browse tab's Analysis Tools menu (iOS) or the Semantic Analytics window (Mac).

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

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | intro (SourceProvenanceDashboard) | lines: 146–147 | key: series.provenance.intro -->

Where did the editors of Foreign Relations of the United States find the documents they published? Since the early 20th century, every document carries a source note naming the archival file it came from. These charts read those notes across the whole series to trace how its archival base changed. The State Department's central files dominated almost completely until bureau lot files and presidential libraries appeared after the war. Modern volumes draw on a much wider range of sources.

<!-- END SOURCE: series.provenance.intro -->

#### Chart 1 subtitle — Archival provenance over time

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | mixOverTimeChart caption | lines: 293–294 | key: series.provenance.trend.caption -->

Each decade's source notes divided among the archival collections they cite, so every decade totals 100%. A volume's decade is set by the midpoint of its coverage. The trend begins in 1900 because earlier volumes carry no archival source notes.

<!-- END SOURCE: series.provenance.trend.caption -->

#### Chart 2 subtitle — Overall provenance composition

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | compositionChart caption | lines: 355–356 | key: series.provenance.composition.caption -->

How many source notes across the whole series, from 1900 on, cite each kind of archival collection. The Central Decimal File dwarfs the rest. Most published FRUS documents came from the State Department's own central filing.

<!-- END SOURCE: series.provenance.composition.caption -->

#### Chart 3 subtitle — The documentary base by decade

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | densityChart caption | lines: 410–411 | key: series.provenance.density.caption -->

How many source notes each decade contributes. These are the counts behind the shares above. The 1940s carry the deepest base. Volumes covering the 1970s, 1980s, and 1990s are still in production, so those decades will look different as new volumes are released.

<!-- END SOURCE: series.provenance.density.caption -->

#### Category-filter caveat — shown while categories are hidden

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats filtered line | lines: 466–467 | key: series.provenance.caveats.filtered.v2 -->

Some categories are hidden. Each share below is a share of the categories still shown, not of all source notes. A decade with no notes in any shown category reads as zero rather than being skipped. Use the Categories menu above to show them all.

<!-- END SOURCE: series.provenance.caveats.filtered.v2 -->

#### "About these figures" methodology footnote

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats body | lines: 472–473 | key: series.provenance.caveats.body -->

These figures come from parsing each document's source note, the citation naming where its archival original was found. They are not drawn from a catalog of the archives. "Other / Unclassified" means a citation the parser could not classify, not a missing source note. Coverage spans 522 of the 552 catalogued volumes. Pre-1900 volumes are largely published diplomatic correspondence with no archival source notes, so the trend begins around 1900. Those early retrospective compilations are left out of the charts. The categories follow State Department filing practice. The Central Decimal File is the pre-1963 central filing system, and the Central Foreign Policy File is its post-1963 successor. Lot files were kept by individual bureaus, offices, and posts. Presidential libraries hold the White House records that dominate modern volumes. Remember that these counts show where FRUS editors drew their documents. That is an editorial and archival signal, not a full census of the underlying archives.

<!-- END SOURCE: series.provenance.caveats.body -->

---

The `AdministrationProfilesDashboard` is a single shared SwiftUI view (used via `EducationDashboardView`), so its `String(localized:)` keys are single edit points shared across iOS and macOS.

### Administration Profiles Dashboard

#### Dashboard intro
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.intro | lines: 240–241 | key: series.admin.intro | shared: iOS+macOS (single edit point) -->

Whose foreign policy does Foreign Relations of the United States document? Every dated document is assigned to the presidential administration in office when the events it records took place. These charts show how many documents each administration draws, and how densely the series covers each term. Select any administration to see which volumes carry its record.

<!-- END SOURCE: series.admin.intro -->
Note: `AdministrationProfilesDashboard` is one shared SwiftUI view rendered on both iOS and macOS; editing this key changes both platforms.

#### Narrowed-empty state — shown when scope and year range match no administration
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.narrowedEmptyState | lines: 206–207 | key: series.admin.narrowedEmpty.message | shared: iOS+macOS (single edit point) -->

No administration matches your current scope and year range. The subseries you selected may carry no attributed documents, or your years may fall outside every presidential term. Reset the scope or year range above to see the whole series.

<!-- END SOURCE: series.admin.narrowedEmpty.message -->

#### Editorial-notes toggle explainer
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.editorialNotesToggle | lines: 257–258 | key: series.admin.toggle.subtitle | shared: iOS+macOS (single edit point) -->

Editorial-note documents carry a span of dates rather than a single date; including them adds them to every count and proportion.

<!-- END SOURCE: series.admin.toggle.subtitle -->

#### Chart 1 subtitle — Documents per administration
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.documentsChart | lines: 279–280 | key: series.admin.docs.caption | shared: iOS+macOS (single edit point) -->

How many published documents concern each administration's foreign policy, in chronological order. Any date overlap counts, so a volume spanning two terms counts in both.

Volumes covering the 1970s, 1980s, and 1990s are still in production. The Carter, Reagan, H.W. Bush, and Clinton administrations will look different as new volumes are released.

<!-- END SOURCE: series.admin.docs.caption -->

#### Chart 2 subtitle — Volumes per administration-year
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.volumesPerYearChart | lines: 340–341 | key: series.admin.perYear.caption | shared: iOS+macOS (single edit point) -->

How many volumes cover each administration, divided by the length of its term in years. This measures how densely the series covers each presidency. The sitting administration has no end date, so it is left out.

Volumes covering the 1970s, 1980s, and 1990s are still in production. The Carter, Reagan, H.W. Bush, and Clinton administrations will look different as new volumes are released.

<!-- END SOURCE: series.admin.perYear.caption -->

#### Volume-list subtitle — per-administration shares
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.volumeList | lines: 478–479 | key: series.admin.volumes.caption | shared: iOS+macOS (single edit point) -->

Each volume's share is the fraction of that volume's documents that fall in this administration — so shares can sum past 100% across administrations under any-overlap attribution.

<!-- END SOURCE: series.admin.volumes.caption -->

#### Subseries-scope caveat — shown while a subseries scope is active
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.caveats | lines: 554–555 | key: series.admin.caveats.scope %@ | shared: iOS+macOS (single edit point) -->

Scoped to the %@ subseries. Counts and proportions come from that subseries' volumes alone. The coverage span for each administration is hidden here, because the source data pre-aggregates it for the whole series. Reset the scope above to see the whole series.

<!-- END SOURCE: series.admin.caveats.scope %@ -->
Note: `%@` is filled with the active subseries label at runtime — keep the placeholder verbatim.

#### Any-overlap attribution footnote — "About these figures"
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.caveats | lines: 561–562 | key: series.admin.caveats.body | shared: iOS+macOS (single edit point) -->

A document counts toward an administration if its dates overlap that president's term at all. A volume spanning two administrations therefore counts in both. That is why the volume counts add up to more than the series' 552 volumes. It is also why one volume's proportions can total over 100% across administrations. These counts measure whose foreign policy the documents cover, not when the volumes were published. Editorial notes carry a range of dates rather than a single date. The toggle above decides whether they are counted, and it is off by default. Retrospective compilations covering years before 1861 concern no single administration and are left out. Each president is counted separately: Nixon and Ford are distinct, as are Grover Cleveland's two non-consecutive terms. Administrations the series has not yet published do not appear.

<!-- END SOURCE: series.admin.caveats.body -->

---

### Geographic Emphasis dashboard

#### Intro paragraph
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.intro | lines: 146–147 | key: series.geography.intro -->

Where in the world does Foreign Relations of the United States look? Every volume carries editorial place tags, which map roughly to the State Department's six regional bureaus. These charts show how the series' geographic emphasis shifted over time. Early volumes concentrate on Europe and the Western Hemisphere. Postwar volumes widen into Asia, the Near East, and Africa. The charts also show which regions and countries the series covers most.

<!-- END SOURCE: series.geography.intro -->

#### Chart 1 caption — Regional emphasis over time
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.regionTrendChart | lines: 183–184 | key: series.geography.trend.caption -->

Each decade's volumes divided among the regions they cover. A volume spanning several regions splits evenly between them, so every decade totals 100%. A volume's decade is set by the midpoint of its coverage.

<!-- END SOURCE: series.geography.trend.caption -->

#### Chart 2 caption — Overall regional emphasis
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.regionTotalsChart | lines: 245–246 | key: series.geography.totals.caption -->

How many volumes touch each region across the whole series. A volume that covers several regions counts once in each, so these totals overlap.

<!-- END SOURCE: series.geography.totals.caption -->

#### Chart 3 caption — Most-covered countries
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.topCountriesChart | lines: 297–298 | key: series.geography.countries.caption -->

The individual place tags carried by the most volumes — the concrete detail behind the regional picture.

<!-- END SOURCE: series.geography.countries.caption -->

#### Regional-bureau mapping footnote
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.caveats | lines: 354–355 | key: series.geography.caveats.body -->

Place tags are editorial tags on the volume, not on the document. A volume touches a region if it carries a place tag that maps to that region. These are volume counts, not document counts, and a volume commonly spans several regions. The stacked chart splits each volume across its regions. A volume covering three regions contributes a third to each, so every decade totals 100%. The overall bars work differently: they count a multi-region volume once in every region it touches. Regions roughly follow the State Department's six current regional bureaus, with dependencies and territories folded into "Other." 551 of the 552 catalogued volumes carry at least one place tag. These figures cover the volumes the app currently catalogs, so the newest volumes may not appear yet.

<!-- END SOURCE: series.geography.caveats.body -->
Note: while a subseries scope is active, this dashboard's caveats block also shows the shared scope line `series.caveats.scope %@` (`SeriesGeographyDashboard.swift` lines 321–322). Its canonical block lives in the Production & Timeliness subsection below; the same key and defaultValue appear in both files, so edit both occurrences together.

---

### Production & Timeliness dashboard (`SeriesProductionDashboard.swift`)

Shared iOS+macOS surface — a single SwiftUI view rendered in both the onboarding sheet and the Research Guide. Every string below is keyed via `String(localized:)`, so editing the `defaultValue` is a single edit point for both platforms.

#### Intro paragraph

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var intro | lines: 129–130 | key: series.production.intro | shared: iOS+macOS (single edit point) -->

How long does the official record take to reach print? These charts trace the timeliness of Foreign Relations of the United States across its whole span. They show the lag between the events a volume documents and its publication. That lag is measured against the publication-timeliness target in force at the time. They also show the pace of publication over time and the steady growth of the digitized series.

<!-- END SOURCE: series.production.intro -->

#### Chart 1 caption — Publication lag over time

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var lagChart (caption) | lines: 171–172 | key: series.chart.lag.caption | shared: iOS+macOS (single edit point) -->

Each point is a volume. The horizontal axis is its publication year. The vertical axis is the lag: how many years earlier its latest document was written. The dashed step line is the timeliness target in force when the volume appeared. That target was 15 years from the 1961 directive, 20 years from 1972, and 30 years from 1985, codified by the 1991 statute.

<!-- END SOURCE: series.chart.lag.caption -->

#### Chart 2 caption — Volumes published per year

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var perYearChart (caption) | lines: 258–259 | key: series.chart.peryear.caption | shared: iOS+macOS (single edit point) -->

How many volumes reached print in each year, coloured by era. Output has never been steady — it reflects staffing, declassification throughput, and the shift to digital publication.

<!-- END SOURCE: series.chart.peryear.caption -->

#### Chart 3 caption — Cumulative volumes published

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var cumulativeChart (caption) | lines: 315–316 | key: series.chart.cumulative.caption | shared: iOS+macOS (single edit point) -->

The digitized corpus has grown to the 552 volumes this app catalogs — steeply in some decades, slowly in others.

<!-- END SOURCE: series.chart.cumulative.caption -->

#### Subseries-scope caveat — shown while a subseries scope is active (shared with Geographic Emphasis)

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var caveats (scope line) | lines: 378–379 | key: series.caveats.scope %@ | shared: iOS+macOS (single edit point) -->

Scoped to the %@ subseries — reset the scope above for the whole series.

<!-- END SOURCE: series.caveats.scope %@ -->
Note: `SeriesGeographyDashboard.swift` repeats the same key and defaultValue in its own caveats block (lines 321–322) — edit both occurrences together so the two files stay consistent. `%@` is filled with the active subseries label at runtime; keep the placeholder verbatim.

#### Publication-timeliness footnote ("About these figures")

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var caveats (body) | lines: 385–386 | key: series.caveats.body | shared: iOS+macOS (single edit point) -->

These figures cover only published, digitized volumes. A volume's publication year is the print year in its TEI header, and its coverage is the span of its document dates. Lag is print year minus coverage-end year. For the near-contemporaneous early volumes that lag can be close to zero or negative. The timeliness target changed over time. There was no formal target before 1961. It was then 15 years under the 1961 directive, 20 under the 1972 directive, and 30 under the 1985 directive, codified by the 1991 statute. The step line is drawn against each volume's publication year, so it shows exactly the target in force when that volume was published. These charts cover the 552 volumes the app currently catalogs, so the newest volumes may not appear yet.

<!-- END SOURCE: series.caveats.body -->

---

## 5. Analytics — Explanatory Captions & Info Popovers

*The "About …" info popovers and figure captions across the analytics features, plus the methods statement that travels inside an exported chart's CSV. Multi-sentence explanatory copy that teaches how to read each visualization.*

---

### About the Graph popover

#### What the graph shows
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1398–1399 | key: graph.info.what.body -->

Each node is a FRUS document. Blue nodes cite the central document. Orange nodes are cited by it. Grey nodes are 2nd- or 3rd-degree neighbours. Larger nodes have more connections across the corpus. Each arrow points at the document being cited.

<!-- END SOURCE: graph.info.what.body -->

#### Edge context
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1404–1405 | key: graph.info.edges.body -->

Many lines carry the original footnote or editorial-note text where the reference appeared. Hover over or tap the middle of a line to read it. A thicker line means the two documents are linked by several separate references.

<!-- END SOURCE: graph.info.edges.body -->

#### Timeline and Network layouts
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1410–1411 | key: graph.info.timeline.body -->

Timeline places each document at its date along a time axis. Documents this one cites usually sit to the left, since they are earlier. Documents citing it sit to the right, since they are later. Documents with no recorded date go in the Undated column. Network uses a spring layout, which arranges nodes by their connections alone.

<!-- END SOURCE: graph.info.timeline.body -->

#### Neighbourhood degree
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1416–1417 | key: graph.info.degree.body -->

1° shows only direct neighbours of the central document. 2° adds neighbours of those neighbours. 3° extends one further hop. Resize the window to see denser graphs more clearly.

<!-- END SOURCE: graph.info.degree.body -->

#### Navigating the graph
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1422–1423 | key: graph.info.interact.body -->

Click a node to see its details. Right-click (or long-press) to recenter the graph on that document or open it in the main window. Use pinch-to-zoom and drag to pan.

<!-- END SOURCE: graph.info.interact.body -->

#### Undownloaded volumes
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1428–1429 | key: graph.info.undownloaded.body -->

A reference can point to a document in a volume you have not downloaded. The graph still shows it, because the connection was recorded when the citing volume was indexed. Those nodes have a dashed border and a struck-through cloud icon. Select one to download its volume from the info panel.

References from volumes you have not indexed are not shown at all. Those volumes have never been parsed, so the app has never seen their references. An orange banner appears at the top of the graph when your inbound connections may be incomplete for this reason. Download and index more volumes to fill in the missing links.

<!-- END SOURCE: graph.info.undownloaded.body -->

---

### Word Cloud — Info Popover ("About the Word Cloud")
<!-- Toolbar info popover; iOS+macOS use the same WordCloudView.swift toolbar (one file, shared across platforms). -->

#### Word Cloud info — What you're seeing

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1078–1079 | key: wordcloud.info.shows.detail -->

The meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, custom volume scope, or the whole corpus. “Size words by” chooses what the sizes mean.

<!-- END SOURCE: wordcloud.info.shows.detail -->

#### Word Cloud info — Lenses

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1091–1092 | key: wordcloud.info.lenses.detail -->

The lens chips narrow the cloud to a kind of term — People, Places, Organizations, Topics, Actions, Descriptors, Concepts, or Sentiment — using on-device language analysis.

<!-- END SOURCE: wordcloud.info.lenses.detail -->

#### Word Cloud info — What's filtered out

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1095–1096 | key: wordcloud.info.filters.detail -->

Common stopwords are always removed. A word's own menu can hide it from this cloud only, which lasts until you next open it. The same menu can add it to a hidden-word list, either global or for one lens. You manage those lists in Settings → Word Cloud. You can also hide diplomatic boilerplate. Use “Show hidden words” in the Options menu to bring hidden words back.

<!-- END SOURCE: wordcloud.info.filters.detail -->

#### Word Cloud info — Tapping a word

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1099–1100 | key: wordcloud.info.tap.detail -->

Charts how often that term appears across the whole corpus in Corpus Analytics; the word's menu also offers a scoped chart and a direct Search.

<!-- END SOURCE: wordcloud.info.tap.detail -->

### Word Cloud Settings — section footers

<!-- Shared surface note: WordCloudSettingsView is a single shared SwiftUI view used on both iOS and macOS (differs only by a #if os(macOS) .formStyle); each footer key below is a single edit point across both platforms. -->

#### Filtering footer — classification markings

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | filteringSection footer | lines: 182–183 | key: settings.wordcloud.markings.footer | shared: iOS+macOS (single edit point) -->

Classification markings include terms like "Top Secret" and "Confidential", precedence words like "Priority" and "Immediate", and month names. These words describe the form of a document, not its content. Left in, they crowd the cloud, especially the named-entity lenses.

<!-- END SOURCE: settings.wordcloud.markings.footer -->

#### Thresholds footer

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | thresholdsSection footer | lines: 212–213 | key: settings.wordcloud.thresholds.footer | shared: iOS+macOS (single edit point) -->

Drops terms shorter than the minimum length, and terms appearing fewer than the minimum number of times. Raising either gives a sparser cloud of stronger terms. Occurrences are counted across the whole scope before the top terms are picked. So raising the minimum count may not change the sample above. It thins the long tail you never see.

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
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1086–1087 | key: chronology.info.shows.detail -->

Every indexed document whose date falls within the range you pick, grouped into date sections that coarsen (days → months → years) as the range widens.

<!-- END SOURCE: chronology.info.shows.detail -->

#### How dates work
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1090–1091 | key: chronology.info.dates.detail -->

Each document sits at its TEI date, and is shown no more precisely than its source supports — with the precision (day/month/year) and certainty (exact vs. approximate) preserved.

<!-- END SOURCE: chronology.info.dates.detail -->

#### The distribution chart
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1094–1095 | key: chronology.info.chart.detail -->

The stacked chart colour-codes documents by source volume (the top volumes, then a grey “Other”). Use the chart-colours menu to choose how many volumes get a distinct colour.

<!-- END SOURCE: chronology.info.chart.detail -->

#### Wide ranges
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1098–1099 | key: chronology.info.cap.detail -->

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

Words separated by spaces are combined with AND. So national security matches documents containing both words. OR finds either term. NOT, or a leading -, excludes a term. All of this works exactly as it does in the Search box.

<!-- END SOURCE: analytics.info.multiword.body -->

#### Phrases
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 191–192 | key: analytics.info.phrase.body | shared: iOS+macOS (single edit point) -->

Wrap words in quotes for an ordered phrase. "missile crisis" matches only documents where those two words appear together, in that order. Analytics and Search read a query the same way, so the counts here match what Search returns.

<!-- END SOURCE: analytics.info.phrase.body -->

#### Stemming
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 195–196 | key: analytics.info.stemming.body | shared: iOS+macOS (single edit point) -->

English stemming is applied: searching for "negotiate" also matches "negotiating", "negotiated", and "negotiations".

<!-- END SOURCE: analytics.info.stemming.body -->

#### How dates are determined
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 199–200 | key: analytics.info.dating.body | shared: iOS+macOS (single edit point) -->

Each document sits at its TEI <date> attribute, the date it was written, not the volume's publication date. A document with no stored date falls back to the start year of its volume, in both the counts and the % denominator. A document with no month is left out of the By Month chart. One with no day is left out of By Day.

<!-- END SOURCE: analytics.info.dating.body -->

### Corpus Analytics — Normalization Caption

#### Share-of-corpus caveat (% of documents mode)
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.normalizationCaption | lines: 1818–1819 | key: analytics.normalize.caption | shared: iOS+macOS (single edit point) -->

Share of indexed documents per period. Only downloaded, indexed volumes are counted, so this is a share of your local corpus, not the entire FRUS series.

<!-- END SOURCE: analytics.normalize.caption -->

### Person Analytics — Info Popover ("About Person Analytics")
<!-- Shared static FeatureInfoButton.personAnalytics in FRUSTheme (added in Wave C, Win 7). Source doc comment notes this copy was drafted in Wave C and is pending owner review. Edit once in FRUSTheme.swift to change both platforms. -->

#### What you're seeing
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 213–214 | key: personAnalytics.info.shows.detail | shared: iOS+macOS (single edit point) -->

Trends ranks the people most mentioned in an era, as tagged by FRUS editors. It also charts how often one person is mentioned across FRUS documents over time. Network maps who is named alongside whom in the same documents. Volumes covering the years before World War II carry no editorial tagging of people, so they fall outside both tools.

<!-- END SOURCE: personAnalytics.info.shows.detail -->

#### How people are counted
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 217–218 | key: personAnalytics.info.counting.detail | shared: iOS+macOS (single edit point) -->

Counts are mentions of a person across the documents you have indexed. The app's person authority groups them, so spelling variants, honorifics, and different name forms for one individual merge into a single identity instead of splitting into several.

<!-- END SOURCE: personAnalytics.info.counting.detail -->

#### Comparing people
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 221–222 | key: personAnalytics.info.compare.detail | shared: iOS+macOS (single edit point) -->

Tap a ranking bar, or use "Add a person to compare", to plot several people's mention trajectories on one chart — each colored line is one person. Remove a person with the ✕ on its chip.

<!-- END SOURCE: personAnalytics.info.compare.detail -->

### Cross-Reference Analytics — Info Popover ("About Cross-Reference Analytics")
<!-- Shared static FeatureInfoButton.crossReferenceAnalytics in FRUSTheme (added in Wave C, Win 7). Source doc comment notes this copy was drafted in Wave C and is pending owner review. Edit once in FRUSTheme.swift to change both platforms. -->

#### What you're seeing
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 265–266 | key: crossRefAnalytics.info.shows.detail | shared: iOS+macOS (single edit point) -->

How FRUS documents cite one another. The ranking lists the most-referenced documents. The heat matrix shows citation flow between whole volumes. Landmarks are the documents a reader following citations keeps returning to. FRUS cross-referencing practice has changed over the life of the series. A subseries or a single administration therefore gives a more consistent signal than a broad scope, which mixes several editorial practices.

<!-- END SOURCE: crossRefAnalytics.info.shows.detail -->

#### Reading the heat matrix
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 269–270 | key: crossRefAnalytics.info.matrix.detail | shared: iOS+macOS (single edit point) -->

Rows cite columns. A darker cell means the row's volume cites the column's volume more often. Column labels are a short code of the volume's years and number, such as '55–57 II. Hover over a label, or use VoiceOver, for the full title on either axis.

<!-- END SOURCE: crossRefAnalytics.info.matrix.detail -->

#### About the influence score
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 273–274 | key: crossRefAnalytics.info.influence.detail | shared: iOS+macOS (single edit point) -->

Landmark documents are ranked by PageRank, computed on this device over the citations the app resolved. It measures how often a document is cited by other much-cited documents. It is not a claim of historical importance.

<!-- END SOURCE: crossRefAnalytics.info.influence.detail -->

### Cross-Reference Analytics — Captions

#### Scope-of-figures caveat
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 653–654 | key: crossRefAnalytics.resolvedCaption | shared: iOS+macOS (single edit point) -->

The most-referenced, degree, and PageRank charts count same-volume references, including resolved page references, toward the document's own volume. Set a year range or scope and they count citations made by documents in that era or scope. The heat matrix counts only connections between different volumes, so it leaves same-volume citations out.

<!-- END SOURCE: crossRefAnalytics.resolvedCaption -->

#### Excluded unresolvable references (shown only when the count is non-zero)

<!-- Placeholder note: the leading count is a Swift string interpolation, not a %lld token — keep `\(excludedBrokenCount)` intact exactly as written. -->

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 658–659 | key: crossRefAnalytics.excludedBrokenCaption | shared: iOS+macOS (single edit point) -->

\(excludedBrokenCount) unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus.

<!-- END SOURCE: crossRefAnalytics.excludedBrokenCaption -->

#### Landmark Documents (Influence) — PageRank hedge subtitle
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.landmarkSection | lines: 1057–1058 | key: crossRefAnalytics.landmarks.subtitle | shared: iOS+macOS (single edit point) -->

Ranked by a PageRank score computed on this device over the citations the app resolved. These are the documents a reader following citations keeps returning to. The score measures position in the citation network, not historical importance. Tap to open.

<!-- END SOURCE: crossRefAnalytics.landmarks.subtitle -->

---

#### Heat matrix — subtitle

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | lines: 850–851 | key: crossRefAnalytics.matrix.subtitle -->

Citations between the \(Self.matrixVolumeLimit) volumes with the most references in and out. Rows cite columns. Darker cells mean more references. Tap a volume label to open it.

<!-- END SOURCE: crossRefAnalytics.matrix.subtitle -->

---

### Analytics Export — Methods Statement (D3)

*The prose that leaves the app inside an exported chart. Every CSV carries a `#`-commented preamble — the figure, terms, grouping, scope, year range, values, app version and export date, then the method and caveats below, then the corpus attribution. An exported PNG or PDF carries only a two-line caption plus the pointer to the CSV, so these sentences are where a reader finds the method. Menu labels, the CSV preamble's field labels ("Figure", "Scope", "Method and caveats", …), CSV column headings, and export-failure messages are functional strings and are intentionally excluded.*

<!-- Placeholder note: `%lld` (a number) and `%@` (a word or phrase) are filled in at export time. Keep them intact and in order — removing one will break the string. -->

#### Corpus attribution — closes every export

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.corpusAttribution | lines: 110–111 | key: analytics.export.attribution | shared: iOS+macOS (single edit point) -->

Foreign Relations of the United States corpus published by the Office of the Historian, U.S. Department of State (history.state.gov). The corpus is in the public domain.

<!-- END SOURCE: analytics.export.attribution -->

#### Dating rule

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.datingCaveat | lines: 137–138 | key: analytics.export.caveat.dating | shared: iOS+macOS (single edit point) -->

Dating: each document sits at its TEI <date>, the date it was written. A document with no stored date falls back to the start year of its volume, in both the counts and the % denominator. A document with no month is left out of the By Month chart. One with no day is left out of By Day.

<!-- END SOURCE: analytics.export.caveat.dating -->

#### Corpus-coverage caveat

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.corpusCaveat | lines: 145–146 | key: analytics.export.caveat.corpus %lld | shared: iOS+macOS (single edit point) -->

Corpus: counts cover only the %lld volume(s) indexed on this device, not the entire FRUS series.

<!-- END SOURCE: analytics.export.caveat.corpus -->

#### Value-mode caveat

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.valueModeCaveat | lines: 153–154 | key: analytics.export.caveat.values %@ | shared: iOS+macOS (single edit point) -->

Values: %@. A share is that period's matching documents divided by all indexed documents in the same period, so a growing corpus does not read as a rising term.

<!-- END SOURCE: analytics.export.caveat.values -->

#### Year range — when the chart ignores it

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.yearRangeDescription | lines: 125–126 | key: analytics.export.range.notApplied | shared: iOS+macOS (single edit point) -->

Not applied — this breakdown covers the whole corpus span

<!-- END SOURCE: analytics.export.range.notApplied -->

#### Figure caption — pointer to the CSV

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsFigureExport.swift | AnalyticsFigureCanvas.body | lines: 79–80 | key: analytics.export.figure.seeData | shared: iOS+macOS (single edit point) -->

Full method, caveats, and the underlying numbers accompany this figure in its CSV export.

<!-- END SOURCE: analytics.export.figure.seeData -->

### Analytics Export — Person Analytics caveats

#### Dated-documents population

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.personProvenance | lines: 457–458 | key: personAnalytics.export.caveat.dated | shared: iOS+macOS (single edit point) -->

Population: person mentions are counted in dated documents only. The Corpus Analytics charts fall back to the volume's start year for undated documents; these charts do not. Counts from the two views are therefore not directly comparable.

<!-- END SOURCE: personAnalytics.export.caveat.dated -->

#### Identity grouping

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.personProvenance | lines: 459–460 | key: personAnalytics.export.caveat.identity | shared: iOS+macOS (single edit point) -->

Identity: mentions are grouped by the app's person authority, so spelling variants and name forms for one individual merge into a single identity. The person id column is that grouped identity.

<!-- END SOURCE: personAnalytics.export.caveat.identity -->

#### Decade shares (By Decade in % mode only)

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.decadeShareCaveat | lines: 476–477 | key: personAnalytics.export.caveat.decadeShare | shared: iOS+macOS (single edit point) -->

Decade shares: the share plotted for a decade is the average of the yearly shares for the years this person was mentioned. Years with no mentions are dropped from that average rather than counted as zero. The "Dated documents in period" column, by contrast, sums every year of the decade. So dividing this file's columns gives the decade's own share, which can be far lower than the plotted value. Someone mentioned in one year of a decade plots that single year's share for the whole decade. Use the columns for the decade's share and the plotted value for the average across the mentioned years. They answer different questions.

<!-- END SOURCE: personAnalytics.export.caveat.decadeShare -->

### Analytics Export — Cross-Reference Analytics caveats

#### Unresolvable references

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 428–429 | key: crossRefAnalytics.export.caveat.excluded %lld | shared: iOS+macOS (single edit point) -->

Unresolvable references: %lld cross-reference(s) are excluded from this analysis — references in the printed volumes that point to a document, page, or volume not present in this corpus.

<!-- END SOURCE: crossRefAnalytics.export.caveat.excluded -->

#### Same-volume attribution

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 431–433 | key: crossRefAnalytics.export.caveat.sameVolume | shared: iOS+macOS (single edit point) -->

Attribution: the document-level figures count same-volume references, including resolved page references, toward the document's own volume. The volume heat matrix counts only citations between different volumes, so it leaves same-volume references out.

<!-- END SOURCE: crossRefAnalytics.export.caveat.sameVolume -->

#### Heat matrix — which volumes it covers

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixCaveats | lines: 570–571 | key: crossRefAnalytics.export.caveat.matrixLimit %lld | shared: iOS+macOS (single edit point) -->

Selection: the matrix covers the %lld volumes with the most references in and out. The CSV lists only pairs with at least one reference between them. The figure draws the whole grid and leaves the rest of the cells blank.

<!-- END SOURCE: crossRefAnalytics.export.caveat.matrixLimit -->

#### Heat matrix — axes and labels

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixCaveats | lines: 573–574 | key: crossRefAnalytics.export.caveat.matrixAxes | shared: iOS+macOS (single edit point) -->

Axes: rows cite columns. In the figure the column headings are abbreviated volume codes and the row labels are shortened descriptive labels; both volumes' full titles appear in this CSV.

<!-- END SOURCE: crossRefAnalytics.export.caveat.matrixAxes -->

#### Landmark Documents — what the score is

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.exportLandmarkCSV | lines: 626–627 | key: crossRefAnalytics.export.caveat.pageRank | shared: iOS+macOS (single edit point) -->

Score: an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is not a claim of historical importance.

<!-- END SOURCE: crossRefAnalytics.export.caveat.pageRank -->

### Analytics Export — Word Cloud caveats

<!-- A cloud never reads a document date, so its export deliberately carries no dating rule and no year-range line. The exported plate's figure title, axis line, and caption facts (wordcloud.export.figureTitle / .axis / .caption.*) are functional identifiers and are intentionally excluded here. -->

#### Population

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 667–668 | key: wordcloud.export.caveat.population %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Population: these counts cover the %lld document(s) in this scope. The share column divides by %lld, which is every word counted under the "%@" lens after the filters below. That is not the scope's total word count. Shares from two different lenses cannot be compared.

<!-- END SOURCE: wordcloud.export.caveat.population -->

#### Stopwords

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 670–671 | key: wordcloud.export.caveat.stopwords %@ %@ | shared: iOS+macOS (single edit point) -->

Stopwords: common English words are always removed. FRUS boilerplate (telegram, department, embassy…) is %@; classification markings, months, and weekdays (secret, confidential, january…) are %@.

<!-- END SOURCE: wordcloud.export.caveat.stopwords -->

#### Stopwords caveat — the two fill-in phrases

*Each `%@` slot above (first the boilerplate filter, then the markings filter) is filled with one of these two fragments, depending on whether that filter is on.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 352–352 | keys: wordcloud.export.caveat.stopwords.excluded, wordcloud.export.caveat.stopwords.kept | shared: iOS+macOS (single edit point) -->

**Filter on:** also removed

**Filter off:** kept

<!-- END SOURCE: wordcloud.export.caveat.stopwords.excluded/.kept -->

#### Tuning thresholds

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 678–679 | key: wordcloud.export.caveat.tuning %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Tuning: words shorter than %lld character(s) and words occurring fewer than %lld time(s) are excluded; plural folding is %@.

<!-- END SOURCE: wordcloud.export.caveat.tuning -->

<!-- The tuning %@ slot is filled with the generic common.on / common.off strings ("on" / "off"), which are shared app-wide and not editable here. -->

#### Words hidden by hand

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 693–694 | key: wordcloud.export.caveat.hidden %lld | shared: iOS+macOS (single edit point) -->

Hidden words: %lld word(s) were hidden by hand in this cloud and are absent from this export. They were counted before being hidden, so they remain in the denominator above.

<!-- END SOURCE: wordcloud.export.caveat.hidden -->

#### Personal stop lists

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 698–699 | key: wordcloud.export.caveat.stopLists %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Your stop lists: %lld word(s) from your global hidden-word list and %lld from your list for the "%@" lens were removed before counting. They are in neither this table nor its denominator. You can edit both lists in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.export.caveat.stopLists -->

#### Active lens

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 725–726 | key: wordcloud.export.caveat.lens %@ | shared: iOS+macOS (single edit point) -->

Lens: the cloud is filtered to the "%@" word list, so this is a subset of the scope's vocabulary, not its whole frequency ranking.

<!-- END SOURCE: wordcloud.export.caveat.lens -->

---

## 6. Settings, Tips & Collections

*Explanatory footers in Settings — the ones that tell a reader what a control costs or protects, across the four groups (Library · Research · Reading & Search · System). Functional and error strings are intentionally excluded. Also the discovery tips and the Collections native-export explanation. Strings shared across platforms via one localization key are marked; where the two platforms genuinely say different things (the Volumes & Storage hub is still two views, and search logging differs by platform) each is a separate edit point and says so.*

---

### iCloud Sync, Settings Sync & Privacy

#### Settings-sync toggle detail
<!-- S-5b made the "single edit point" claim on the three keys below actually true: the macOS Sync pane used to hardcode its own near-identical copy (and had drifted — "shares those settings" vs "shares the settings above"). Both platforms now render `SyncSettingsSection`. -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.rows | lines: 1470–1471 | key: settings.sync.toggle.detail | shared: iOS+macOS (single edit point) -->

Word-cloud filters & stop lists, citation style, default document mode, and research logging.

<!-- END SOURCE: settings.sync.toggle.detail -->

#### Settings-sync unavailable notice
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.rows | lines: 1482–1483 | key: settings.sync.unavailable | shared: iOS+macOS (single edit point) -->

Settings sync needs iCloud. Sign in to iCloud and enable it for FRUS Explorer to turn this on.

<!-- END SOURCE: settings.sync.unavailable -->

#### iCloud Sync section footer
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.footerText | lines: 1492–1493 | key: settings.sync.footer | shared: iOS+macOS (single edit point) -->

When this is on, the device shares the settings above with your other devices that also have it on. Turning it on adopts the settings already in iCloud. Leave it off to keep this device's settings separate.

<!-- END SOURCE: settings.sync.footer -->

### Research Sessions

<!-- Settings ▸ Research ▸ Research Sessions. One view on both platforms. The recording footer still has TWO keys, but no longer for the original reason: the platforms once recorded into DIFFERENT stores (iOS wrote `.searchSubmit` session events, macOS wrote `SearchHistoryEntry`), and since Wave R-2a there is exactly one writer of each kind on both. What still differs is only what the surfaces are CALLED — macOS has the History window and Recents, iOS has the History screen plus Project Home's cards and tiles — so the two texts differ in their nouns and not in their substance.

This whole block was refreshed in Wave R-5. Every key below changed in R-2a, and this file had been left describing the R-1 wording, some of which had become false — see the per-entry notes. -->

#### Research-session recording footer (iOS)

<!-- Rewritten TWICE, each time under a NEW key, because no String Catalog ships and reusing a key with different text is a silent collision. R-1 replaced `settings.sessions.logging.footer` (which described a switch that governed the session log alone) with `…footer.trail`; R-4 replaced that with `…trail.v2` when iOS gained a `SearchHistoryEntry` writer; R-2a replaced THAT with `…trail.v3`, because sessions became derived rather than stored and exports joined the trail. The label stays "Log Research Sessions" (owner decision, R-0 Q3), so this footer carries the whole explanatory burden, including the behaviour change: History and Recents drain when the switch is off. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordingSection footer | lines: 189–190 | key: settings.sessions.logging.footer.trail.v3 | shared: iOS only (see the note above) -->

Despite the name, this switch covers everything the app remembers about your work. That means the documents you open, the text of the searches you run, and the collections you export. The app keeps one record of each. The History screen, a project's Recently Read and Recent Searches cards, its Documents Visited and Searches Run counts, and the Session Log all read those same records. The Session Log groups them into sessions, and a session ends after 30 minutes of inactivity. The records stay on this device, and in your private iCloud database if iCloud sync is on. Turn the switch off and all of that recording stops. Those surfaces will thin out and eventually be empty. That is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it.

<!-- END SOURCE: settings.sessions.logging.footer.trail.v3 -->

#### Research-session recording footer (macOS)

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordingSection footer | lines: 186–187 | key: settings.sessions.logging.footer.trail.mac.v2 | shared: macOS only (see the note above) -->

Despite the name, this switch covers everything the app remembers about your work. That means the documents you open, the text of the searches you run, and the collections you export. The app keeps one record of each. The History window, a project's Recents, and the Session Log all read those same records. The Session Log groups them into sessions, and a session ends after 30 minutes of inactivity. The records stay on this device, and in your private iCloud database if iCloud sync is on. Turn the switch off and all of that recording stops. History and Recents will thin out and eventually be empty. That is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it.

<!-- END SOURCE: settings.sessions.logging.footer.trail.mac.v2 -->

#### Recorded-activity footer (empty)

<!-- One key on both platforms since Wave R-2a. A macOS variant used to exist because the session log read `SessionEvent`, which macOS never wrote for a search — so "run a search" would have been a promise the Mac did not keep. The log is derived from `SearchHistoryEntry` now, of which macOS has always been a producer, so the fence is gone. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordedActivitySection footer | lines: 228–229 | key: settings.sessions.activity.footer.empty | shared: iOS+macOS (single edit point) -->

Nothing has been recorded yet. Open a document or run a search and it will appear here.

<!-- END SOURCE: settings.sessions.activity.footer.empty -->

#### Recorded-activity footer (non-empty)

<!-- Wave R-2a, NEW key. The R-1 text under `settings.sessions.activity.footer` said "No other part of the app reads this log — it is groundwork for a research-trail view." That was true of the `SessionEvent` store and became false the moment the log was derived from the same reading, search and export history the History surface and Project Home are built from. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.recordedActivitySection footer | lines: 235–236 | key: settings.sessions.activity.footer.derived | shared: iOS+macOS (single edit point) -->

The app does not store sessions. It works them out from the times you opened documents, ran searches, and exported collections. A gap of 30 minutes starts a new session. The same records fill the History screen and a project's Recents.

<!-- END SOURCE: settings.sessions.activity.footer.derived -->

#### Delete-sessions footer

<!-- Wave R-2a, NEW key. The R-1 text under `settings.sessions.manage.footer.trail` ended "…and so does the reading and search history the switch above also governs — this button does not reach that." That gap is closed: sessions are derived from that history, so deleting sessions IS deleting it, and the button now calls `HistoryTrailAdmin.deleteAll`. Leaving the old sentence in place would have under-warned about an irreversible, CloudKit-propagating delete. -->

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | ResearchSessionsView.manageSection footer | lines: 263–264 | key: settings.sessions.manage.footer.whole | shared: iOS+macOS (single edit point) -->

This deletes the whole record of your work: every document you opened, every search you ran, and every collection you exported. It goes from this device, and from your iCloud database if iCloud sync is on. Your notes, highlights, tags, and collections are not touched. To delete single entries instead, use the History screen.

<!-- END SOURCE: settings.sessions.manage.footer.whole -->

#### iCloud unavailable (Local Only) detail
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 237–238 | key: settings.icloud.localOnly.detail | shared: iOS only (the macOS status lives in the main window's status bar) -->

iCloud sync is unavailable. Notes, tags, and collections won't sync across devices. Check that you are signed in to iCloud in Settings and that FRUS Explorer has iCloud access.

<!-- END SOURCE: settings.icloud.localOnly.detail -->

#### iCloud zone-missing detail
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 313–314 | key: settings.icloud.zoneMissing.detail | shared: iOS only (the macOS status lives in the main window's status bar) -->

The iCloud sync zone is missing. Data cannot upload or download until it is recreated. Force-quit and relaunch the app, or use Settings → Data & Recovery → Fix iCloud Sync.

<!-- END SOURCE: settings.icloud.zoneMissing.detail -->

---

#### Deleting one session — confirmation

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | lines: 150–151 | key: settings.sessions.delete.message.trail.v2 %@ -->

%@ will be permanently deleted from this device. If iCloud sync is on, the same records go from iCloud too. A session is made of every document you opened, every search you ran, and every collection you exported. Your notes, highlights, tags, and collections are not affected.

<!-- END SOURCE: settings.sessions.delete.message.trail.v2 %@ -->

---

### Volumes & Storage (Library)

<!-- The merged Library destination. Replaces the retired Volume Updates and Storage & Backup subsections, whose keys (`settings.volumes.updates.footer`, `settings.storage.aggregate.footer`, `settings.storage.backup.note`) went with the panes S-2b/S-2c deleted. The hub is still TWO views — VolumesStorageHubView.swift for iOS, MacVolumesStorageHub.swift for macOS — so each footer below is a separate edit point unless noted. -->

#### Keeping Current footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | keepingCurrentSection footer | lines: 529–530 | key: settings.hub.keepingCurrent.footer | shared: iOS (macOS carries the same text separately in MacVolumesStorageHub.swift) -->

Updating re-downloads and re-indexes a volume. Your notes, highlights, tags, and summaries are preserved.

<!-- END SOURCE: settings.hub.keepingCurrent.footer -->

#### Storage & Index footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | storageAndIndexSection footer | lines: 600–601 | key: settings.hub.storageIndex.footer | shared: iOS (macOS carries the same text separately) -->

Notes, highlights, and tags are never affected. For reference: the full FRUS corpus is roughly 3.4 GB of XML plus 9–10 GB of search index.

<!-- END SOURCE: settings.hub.storageIndex.footer -->

#### Rebuild From Scratch — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | rebuild confirmation | lines: 198–199 | key: settings.hub.rebuild.message.v2 | shared: iOS (macOS carries the same text separately) -->

This deletes everything the app has built for searching — document text, cross-references, page numbers, dates and the people named in each document — and builds it again by re-reading all (volumes) you have downloaded.\n\nYour research notes, highlights, summaries, collections, and tags are stored separately. They are not affected.

<!-- END SOURCE: settings.hub.rebuild.message.v2 -->

#### Free Up Space — removal confirmation

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | MacManageStorageSheet / FreeUpSpaceSheet confirmation | lines: 1768–1769 | key: settings.hub.freeUp.confirm.message | shared: iOS+macOS (single edit point — the Mac adopted these keys when its missing confirmation was added) -->

The XML files and their search-index rows are deleted from this device. Every one of these volumes can be downloaded again.

<!-- END SOURCE: settings.hub.freeUp.confirm.message -->

#### Free Up Space — size-estimate note

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | FreeUpSpaceSheet | lines: 1717–1718 | key: settings.hub.freeUp.estimateNote | shared: iOS (macOS carries the same text separately) -->

Each size is the XML file plus an estimated 2.8× for its share of the search index. That ratio comes from the full corpus: about 9–10 GB of index for about 3.4 GB of XML. Per volume the overhead runs from roughly 2.5× to 3×, so treat these sizes as approximate.

<!-- END SOURCE: settings.hub.freeUp.estimateNote -->

#### Needs Attention footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | needsAttentionSection footer | lines: 437–438 | key: settings.hub.interrupted.footer.v2 | shared: iOS (macOS carries the same text separately) -->

These volumes were still being indexed when the app last closed. This section appears only when something needs your attention.

<!-- END SOURCE: settings.hub.interrupted.footer.v2 -->

#### Download options footer (iOS only)

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | optionsSection footer | lines: 710–711 | key: settings.hub.options.footer | shared: iOS only — absorbed the retired iCloud-Backup exclusion note -->

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

Send FRUS documents to your Zotero library with your tags and research notes attached. Zotero syncs them to all your devices, including the Zotero iOS app. This is the only way to get FRUS annotations into Zotero on iPhone and iPad.

<!-- END SOURCE: settings.zotero.about.body -->

### Data & Recovery (System)

<!-- The merged export/diagnostics/recovery destination (S-4b). Replaces the retired Reset & Data Safety subsection: the recovery ladder renamed its rungs, so all seven `settings.reset.*` keys are gone. -->

#### Recovery ladder footer

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | recoverySection footer | lines: 259–260 | key: settings.dataRecovery.recovery.footer | shared: iOS+macOS (single edit point) -->

In order of how much they take away. Try the first one first — it is the one that deletes nothing.

<!-- END SOURCE: settings.dataRecovery.recovery.footer -->

#### Fix iCloud Sync — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | fixSync confirmation | lines: 134–135 | key: settings.dataRecovery.fixSync.message | shared: iOS+macOS (single edit point) -->

This clears the local copy of your synced data and downloads it again. Nothing in iCloud is deleted, so nothing is lost. The app returns to onboarding while it restores. The clearing happens the next time the app starts, so quit and reopen it.

<!-- END SOURCE: settings.dataRecovery.fixSync.message -->

#### Reset This Device — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | resetDevice confirmation | lines: 161–162 | key: settings.dataRecovery.resetDevice.message | shared: iOS+macOS (single edit point) -->

Downloaded volumes and the search index go; your notes, highlights, tags, collections and projects stay in iCloud and come back on the next launch. You will need to download volumes again.

<!-- END SOURCE: settings.dataRecovery.resetDevice.message -->

#### Broken Cross-References report footer

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | reports section footer | lines: 533–534 | key: settings.export.brokenRefs.footer | shared: iOS+macOS (single edit point) -->

Every cross-reference in the printed FRUS volumes that points to a document, page, or volume the corpus does not contain. The list covers the whole corpus. The CSV names each broken target once, not once for every occurrence. A fuller spreadsheet, with one row per occurrence and its source line number, is produced by a separate tool rather than in the app.

<!-- END SOURCE: settings.export.brokenRefs.footer -->

#### Research-data export — JSON footer

<!-- Wave R-5, NEW key (`settings.export.json.footer` listed six things; the file now carries seven). The research trail is named explicitly rather than folded into "your research data" because it is the part a reader would not assume was in there — and the part they may want to check before sharing the file, since it includes the text of every search they ran. -->

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections JSON section footer | key: settings.export.json.footer.trail | shared: iOS+macOS (single edit point — hosted by Data & Recovery on both) -->

One JSON file with your notes, tags, highlights, collections, custom prompts, and projects. It also holds your research trail: every document you opened, every search you ran and how many results it returned, and every collection you exported.

<!-- END SOURCE: settings.export.json.footer.trail -->

#### Erase Everything — warning

<!-- Wave R-5, NEW key. Wave R-2a extended `EraseEverythingView.performReset` to delete the whole research trail but left this list — the screen's entire account of what is about to go — unchanged, so the warning under-stated its own reach. -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | key: settings.erase.warning.trail | shared: iOS+macOS (single edit point — reached from the macOS Data & Recovery sheet) -->

This deletes every downloaded volume, the search index, and all of your research notes, projects, tags, collections, highlights, and AI-generated summaries — along with your whole research trail: every document you opened, every search you ran, and every collection you exported. Because your research data syncs, it goes from your other devices too. This cannot be undone.

<!-- END SOURCE: settings.erase.warning.trail -->

#### Erase Everything — first confirmation

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | lines: 1359–1360 | key: settings.erase.confirm1.message | shared: iOS+macOS (single edit point) -->

Everything listed above will be deleted from this device and from iCloud.

<!-- END SOURCE: settings.erase.confirm1.message -->

#### Erase Everything — final confirmation

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | lines: 1375–1376 | key: settings.erase.confirm2.message | shared: iOS+macOS (single edit point) -->

Export your research data first if you might want it back.

<!-- END SOURCE: settings.erase.confirm2.message -->

#### Erase All Data — what exactly goes

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | lines: 1300–1301 | key: settings.erase.warning.inventory -->

This deletes every downloaded volume and the search index. It deletes all of your research notes, projects, tags, collections, highlights, and AI-generated summaries. It also deletes your saved searches, working corpora, custom volume scopes, project leads, and any person-identity corrections you have made. It deletes your whole research trail as well: every document you opened, every search you ran, and every collection you exported. Because your research data syncs, it goes from your other devices too. Your app preferences are kept. This cannot be undone.

<!-- END SOURCE: settings.erase.warning.inventory -->

---

#### When iCloud has not been told about a record type yet

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | lines: 476–477 | key: settings.dataRecovery.schema.about.pending -->

iCloud has to be told about each kind of record the app saves before it will accept one. Some additions in this version have not been published yet. Records that use them will not upload until they are. Everything else keeps syncing. This is a problem with the app, not with your account. There is nothing you can do here except report it.

<!-- END SOURCE: settings.dataRecovery.schema.about.pending -->

---

#### When the stored data does not match the running build

<!-- SOURCE: FRUSExplorer/Models/StoreSchemaDiagnostic.swift | lines: 117–119 | key: storeSchema.summary.consequence -->

This usually happens when your stored data does not match the build you are running. The data is safe, and iCloud still has its copy. This build cannot open it, so it is using a separate local store. Nothing you do here will sync.

<!-- END SOURCE: storeSchema.summary.consequence -->

---

### Background Summarization

#### Continue-in-background footer
<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift | BackgroundSummarizationSettingsView.backgroundContinuationSection footer | lines: 99–100 | key: bg.summarizer.continue.hint.v2 | shared: iOS+macOS (single edit point) -->

When on, the app keeps summarizing a few documents at a time while you are not using the device, even after you close the app. Uses the on-device model and some battery.

<!-- END SOURCE: bg.summarizer.continue.hint.v2 -->

---

### Display & Reading

*The reading-mode footers in Settings ▸ Display, and the Browse error a broken index produces. New in this regeneration.*

---

#### Reading mode — footer (iPad and Mac)

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | lines: 1671–1672 | key: settings.display.reading.footer -->

"Remember Last" reopens documents in the mode you used last, Read or Research. Research mode shows the Research rail in a side panel beside the document. Read mode hides the rail so you can just read. The rail toggle inside a document always wins for that document.

<!-- END SOURCE: settings.display.reading.footer -->

---

#### Reading mode — footer (iPhone)

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | lines: 1668–1669 | key: settings.display.reading.footer.iphone -->

The Research rail opens as a bottom sheet from the toolbar's Research button. It never opens on its own, so it cannot cover a document you only meant to read. Edge-Tap Page Turn moves you between documents while the rail is closed.

<!-- END SOURCE: settings.display.reading.footer.iphone -->

---

#### Custom volume scopes — the coverage-years facet

<!-- SOURCE: FRUSExplorer/Settings/CustomScopesView.swift | lines: 879–880 | key: settings.scopes.facet.coverage.footer -->

Adds volumes whose coverage overlaps the years you set. You can also narrow by editor. Leave both years blank to add by editor name alone. Volumes with no coverage dates in the manifest never match a year range.

<!-- END SOURCE: settings.scopes.facet.coverage.footer -->

---

#### Browse — the search index could not be opened

<!-- SOURCE: FRUSExplorer/Browser/BrowserViewModel.swift | lines: 493–495 | key: browser.indexing.pipelineUnavailable -->

FRUS Explorer could not open its search index. This volume cannot be indexed or checked until you restart. Relaunch the app. If the message comes back, the index database is damaged and only reinstalling will rebuild it.

<!-- END SOURCE: browser.indexing.pipelineUnavailable -->

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
<!-- SOURCE: FRUSExplorer/Collections/CollectionExportSheet.swift | CollectionExportSheet.nativeShareOptions | lines: 566–567 | key: export.native.hint | shared: iOS+macOS (single edit point) -->

Shares an editable copy of this collection: its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don't have. Your research notes stay private unless you include them above.

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

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1051–1052 | key: search.facets.on.help.v2 -->

Break the whole match down by year, volume, person, type and provenance — before any narrowing you apply

<!-- END SOURCE: search.facets.on.help.v2 -->

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1126–1127 | key: search.kwic.show.help.v2 -->

Show every occurrence of your term on its own line, aligned — for the documents on this page

<!-- END SOURCE: search.kwic.show.help.v2 -->

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1281–1284 | key: search.cap.tooltip -->

*Interpolated with the loaded and total counts.*

Showing %lld of %lld matches. Narrow your search with a date range, volume filter, or more specific terms to see every result.

<!-- END SOURCE: search.cap.tooltip -->

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1286–1289 | key: search.cap.tooltip.unknownTotal -->

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

#### Detected-topic facet — footer

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 918–919 | key: search.subject.facet.footer -->

Experimental. These topics are detected automatically from the text, not editorial subject headings, so some are wrong. Choosing a category finds volumes where that topic is one of their most distinctive. The volume picker then fills with the matches you have indexed.

<!-- END SOURCE: search.subject.facet.footer -->

---

#### Detected-topic facet — picker footer

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 1428–1429 | key: search.subject.facet.picker.footer -->

Detected topics (experimental). These are inferred from the text, not editorial subject headings, so some are wrong. A volume appears when a topic is among its most distinctive, not merely mentioned. Categories are broad. Open a sub-category to narrow the list.

<!-- END SOURCE: search.subject.facet.picker.footer -->

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

Your Word Cloud settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to rank these neighbours.

<!-- END SOURCE: search.collocation.unavailable.mismatch -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.noMatches -->

None of these results contains a whole word this measure can centre on. Phrase, wildcard and proximity searches match in ways a word window cannot anchor to.

<!-- END SOURCE: search.collocation.unavailable.noMatches -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.floor -->

*Interpolated with the minimum-count floor.*

No word appears at least %lld times near your matches. A word used once or twice can top a ranking while telling you nothing about the documents, so nothing is ranked. Widen the window or run a broader search to give this more text to read.

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

These are the highest-scoring matches, not a sample across time — this shape is theirs, not the whole match’s.

<!-- END SOURCE: search.timeline.bias -->

---

### 7.7 Working corpora

*Source: `FRUSExplorer/Settings/WorkingCorporaView.swift, SaveWorkingCorpusSheet.swift, SearchFilterView.swift`*

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpora.footer -->

A working corpus is a fixed set of documents, captured once. The whole set syncs to your other devices. A count taken inside it therefore means the same thing on every device, even where fewer of its volumes are indexed.

<!-- END SOURCE: corpora.footer -->

<!-- SOURCE: FRUSExplorer/Settings/WorkingCorporaView.swift | key: corpora.empty.detail -->

Run a search, then choose “Save as Working Corpus” to fix those results as a named set you can search inside later.

<!-- END SOURCE: corpora.empty.detail -->

<!-- SOURCE: FRUSExplorer/Search/SaveWorkingCorpusSheet.swift | lines: 129–130 | key: corpus.save.footer -->

The set is fixed at capture. Re-running the query later may find different documents; this corpus will not change, which is what makes counts taken inside it reproducible.

<!-- END SOURCE: corpus.save.footer -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 240–242 | key: corpus.save.truncated.total -->

*Interpolated with the captured and total counts.*

These %1$@ documents are the highest-scoring of %2$@ matching documents. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.truncated.total -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 245–247 | key: corpus.save.truncated.unknown -->

*Interpolated with the captured count.*

These %@ documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.truncated.unknown -->

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 258–260 | key: corpus.save.checklistHiding -->

*Interpolated with the hidden count.*

Checklist mode is hiding %@ reviewed documents. They will not be in this corpus.

<!-- END SOURCE: corpus.save.checklistHiding -->

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 758–759 | key: search.corpus.footer -->

A working corpus is a fixed set of documents. Applying one searches only inside it. Manage them in Settings.

<!-- END SOURCE: search.corpus.footer -->

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 827–829 | key: search.corpus.noneIndexed -->

*Interpolated with the corpus name.*

None of “%@” is indexed on this device yet — download and index its volumes first.

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

One search predates this app version. It saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. It is marked "as reported" and cannot be checked against the others.

<!-- END SOURCE: appendix.caveat.unrecorded.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.unrecorded.many -->

*Interpolated with a count.*

%lld searches predate this app version. They saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. They are marked "as reported" and cannot be checked against the others.

<!-- END SOURCE: appendix.caveat.unrecorded.many -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.attribution -->

Text from Foreign Relations of the United States, Office of the Historian, U.S. Department of State (public domain).

<!-- END SOURCE: appendix.attribution -->

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | lines: 139–141 | key: settings.export.appendix.footer -->

Every search you ran, in a Markdown table and a CSV. Each row gives the scope the search ran under and how many volumes were indexed at the time. Counts that hit the app's row ceiling appear as "at least N", so a partial result is never printed as a total.

<!-- END SOURCE: settings.export.appendix.footer -->

---

### 7.9 Occurrence counts — when they are refused, and why

*Source: `FRUSExplorer/Analytics/OccurrenceAvailability.swift, AnalyticsView.swift`*

<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | lines: 2790–2792 | key: analytics.measure.help -->

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

Apple Intelligence generates one summary at a time, so a higher number does not make the model faster. It helps when your Mac is busy with other work. It also makes the first summary take longer to appear.

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

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationService.swift | lines: 617–619 | key: bg.summarizer.failed.unavailable -->

*Interpolated with the succeeded and attemptable counts.*

Apple Intelligence became unavailable. Stopped after %lld of %lld documents.

<!-- END SOURCE: bg.summarizer.failed.unavailable -->


### 7.11 Compacting the search index

*Source: `FRUSExplorer/Settings/SettingsComponents.swift` (the shared `IndexCompaction` rule),
rendered identically by both storage hubs.*

*SQLite never returns deleted pages to the filesystem — they go on a freelist and wait to be reused —
so the index file can be much larger than the data in it. Reindexing is the main producer. Measured
on the author's 552-volume store: 6.29 GiB on disk, 2.75 GiB live, 3.53 GiB reclaimable.*

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.storage.compact.available -->

*Interpolated with the reclaimable size and its percentage of the file.*

%@ of this is free space left by reindexing — %lld%% of the file.

<!-- END SOURCE: settings.storage.compact.available -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.storage.compact.blocked -->

*Shown when there is something worth reclaiming but not enough free disk to do it safely. Stated
rather than hidden: this is the case where the number explains the most.*

%@ could be reclaimed, but compacting needs about %@ of free space first.

<!-- END SOURCE: settings.storage.compact.blocked -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 863–864 | key: settings.storage.compact.action | shared: iOS+macOS (single edit point) -->

Compact Database

<!-- END SOURCE: settings.storage.compact.action -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 873–874 | key: settings.storage.compact.caveat | shared: iOS+macOS (single edit point) -->

Rewrites the index to give the free space back. Searching is unavailable while it runs — usually a few seconds, longer on a large library. Nothing you have written is affected.

<!-- END SOURCE: settings.storage.compact.caveat -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 873–874 | key: settings.storage.compact.done -->

*Interpolated with the reclaimed size.*

Reclaimed %@.

<!-- END SOURCE: settings.storage.compact.done -->

<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | key: related.why.cohort -->

*The archival "why related" chip (#644). Interpolated with the container name and its size.
Replaces a bare "same provenance", which read identically for a lot file holding two documents and
for Nixon's NSC Files holding 7,056 — and that difference is what tells a researcher whether sharing
the container is a finding or a filing-cabinet coincidence.*

%@ · 1 of %lld

<!-- END SOURCE: related.why.cohort -->

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

---

## 9. Archival Analytics — Dashboard Prose

*The Archival Analytics family (`FRUSExplorer/Analytics/`): four modes — Collections, Network, Flows and Your Library — behind one mode picker, on iOS/iPadOS and in the macOS Archival Analytics window. Three of the four read bundled data and render with nothing downloaded; Your Library reads your own index. This section is new in this regeneration.*

---

### 9.1 The mode picker, and what it says when data is missing

#### Mode picker — help text

*Shown under the Mode control on both platforms.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 265–266 | key: archival.mode.help.v2 -->

Switch between the era rankings, the co-citation network, the reference hand-off diagram, and the archival profile of your own indexed volumes.

<!-- END SOURCE: archival.mode.help.v2 -->

---

#### Network mode is unavailable

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 293–294 | key: archival.network.unavailable -->

The bundled collection authority is unavailable in this build, so the network cannot be drawn.

<!-- END SOURCE: archival.network.unavailable -->

---

#### Flows mode is unavailable

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 313–314 | key: archival.flows.unavailable -->

The bundled reference-flow index is unavailable in this build, so hand-offs cannot be shown. This is not the same as the series having none.

<!-- END SOURCE: archival.flows.unavailable -->

---

#### Document counts are unavailable, so only the volume weight is offered

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 884–885 | key: archival.caveats.noUsageIndex -->

Document counts are unavailable in this build — the bundled usage index did not load — so only the volume weight is offered.

<!-- END SOURCE: archival.caveats.noUsageIndex -->

---

### 9.2 Collections — the ranking

#### While the archival authority loads

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 347–348 | key: archival.collections.loading -->

Reading the archival authority…

<!-- END SOURCE: archival.collections.loading -->

---

#### Ranking caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 799–800 | key: archival.ranking.caption %@ %lld %@ %lld -->

Volumes covering %1$@ — %2$lld of them — draw on %3$lld %4$@. Bars are coloured by who holds the records.

<!-- END SOURCE: archival.ranking.caption %@ %lld %@ %lld -->

---

#### Nothing to rank in this era

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 704–705 | key: archival.ranking.empty -->

No archival units resolved in this era under the current unit and weight.

<!-- END SOURCE: archival.ranking.empty -->

---

#### The caveat block — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1155 | key: archival.caveats.title | shared: iOS+macOS (the same key in both views — edit both) -->

About these figures

<!-- END SOURCE: archival.caveats.title -->

---

#### The method statement, in the info popover

*Moved off the page into **About These Figures** by #838, and unchanged in substance: it is what stops the two counts, the era asymmetry and the name-clustering from being read as defects. The disclosures that change with the controls — what the Central Files filter withheld, and a failed artifact load — stayed on the page and have their own blocks above.*

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 240–241 | key: archival.info.method.detail -->

They are parsed from the source note on each published document, not read from an archive's catalog. So they say where the editors drew documents from — an editorial and archival signal, not a census of what the archives hold. Coverage is uneven by era, and switching what the chart shows is the way through it: named collections are scarce before 1948, where central-file numbers carry almost the whole record, and those numbers all but disappear after 1976, where the presidential libraries carry it. Collections are grouped across volumes by name, so when two spellings of one name fail to merge, the same body of records can appear twice under nearby names.

<!-- END SOURCE: archival.info.method.detail -->

---

#### The caveat block — what the umbrella filter withheld

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 876–877 | key: archival.caveats.umbrella %lld %@ %@ -->

The Central Files umbrella record is hidden here. On its own it accounts for %1$lld %2$@ in the %3$@ volumes, and its bar would flatten the scale. The era-specific Central Files records are still shown.

<!-- END SOURCE: archival.caveats.umbrella %lld %@ %@ -->

---

### 9.3 Network — one collection and everything cited beside it

#### Before a collection is chosen — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 627–628 | key: archival.network.empty.title -->

Choose a Collection

<!-- END SOURCE: archival.network.empty.title -->

---

#### Before a collection is chosen — detail

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 630–631 | key: archival.network.empty.detail -->

Pick a collection to see which other bodies of records the same volumes drew on.

<!-- END SOURCE: archival.network.empty.detail -->

---

#### Nothing co-cited — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 635–636 | key: archival.network.none.title -->

No Co-Cited Collections

<!-- END SOURCE: archival.network.none.title -->

---

#### Nothing co-cited — detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 638–640 | key: archival.network.none.detail.v2 %@ %@ -->

No other collection shares two or more volumes with %1$@ above the current threshold. %2$@

<!-- END SOURCE: archival.network.none.detail.v2 %@ %@ -->

---

#### Nothing co-cited — what to try

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 645–646 | key: archival.network.none.floor -->

The threshold is already at its lowest, so this collection simply shares no volumes with another — choose a more widely cited one.

<!-- END SOURCE: archival.network.none.floor -->

---

#### The info dock, before a node is selected

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 557–558 | key: archival.network.dock.title -->

Select a node to see the link

<!-- END SOURCE: archival.network.dock.title -->

---

#### The info dock — what the rings mean

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 597–599 | key: archival.network.dock.summary.v2 %lld %lld %@ -->

%1$lld of the %2$lld nodes above the current threshold are drawn. Distance from the centre shows link strength. The dashed rings mark three quarters, one half, and one quarter of the strongest link here (%3$@).

<!-- END SOURCE: archival.network.dock.summary.v2 %lld %lld %@ -->

---

#### The info dock — what a link means

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 601–603 | key: archival.network.dock.grain %lld -->

%lld collections share two or more volumes with this one. Links are volume-grain — the same volumes drew on both — which is not document-level affinity.

<!-- END SOURCE: archival.network.dock.grain %lld -->

---

#### The info dock — the six-per-custodian cap

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 606–608 | key: archival.network.dock.capped.v2 %lld -->

%lld more are held back so each custodian's quadrant stays readable; every quadrant keeps its strongest. Raise the threshold to narrow the neighbourhood rather than to see more of it.

<!-- END SOURCE: archival.network.dock.capped.v2 %lld -->

---

#### The info dock — the class sub-arc

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 612–614 | key: archival.network.dock.classes %lld -->

The %lld squares are central-file classes drawn from inside the Central Files record, which is hidden while they are shown.

<!-- END SOURCE: archival.network.dock.classes %lld -->

---

#### A selected node's card

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 543–544 | key: archival.network.card.detail %lld %lld %@ -->

%1$lld volumes cite both this and %3$@; together they supplied %2$lld documents to those volumes.

<!-- END SOURCE: archival.network.card.detail %lld %lld %@ -->

---

#### A selected class node's card

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 539–540 | key: archival.network.class.caption -->

Central-file class — a subject heading inside the State Department's filing system, not a collection

<!-- END SOURCE: archival.network.class.caption -->

---

#### Node accessibility hint

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 463–464 | key: archival.network.node.hint -->

Select to see this link's detail; long-press for actions

<!-- END SOURCE: archival.network.node.hint -->

---

#### Threshold slider — accessibility label

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 235–236 | key: archival.network.threshold.a11y -->

Minimum link strength, as a share of the strongest link

<!-- END SOURCE: archival.network.threshold.a11y -->

---

### 9.4 Flows — where an editor's cross-reference led

#### What this mode is for

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 140–141 | key: archival.flows.intro -->

When a FRUS editor annotated one published document by pointing to another, the two documents usually came from different archives. Added up across the series, those pointers map the paths the editors walked between bodies of records.

<!-- END SOURCE: archival.flows.intro -->

---

#### The unfocused view — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 263–264 | key: archival.flows.top.title | shared: iOS+macOS (the same key in both views — edit both) -->

The heaviest hand-offs in the series

<!-- END SOURCE: archival.flows.top.title -->

---

#### The unfocused view — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 296–297 | key: archival.flows.top.caption -->

Choose a focus collection above to see everywhere its documents point.

<!-- END SOURCE: archival.flows.top.caption -->

---

#### Focused, outgoing — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 356–357 | key: archival.flows.title.outgoing -->

Where these documents point

<!-- END SOURCE: archival.flows.title.outgoing -->

---

#### Focused, incoming — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 358–359 | key: archival.flows.title.incoming -->

What points at these documents

<!-- END SOURCE: archival.flows.title.incoming -->

---

#### Focused, outgoing — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 372–373 | key: archival.flows.caption.outgoing %lld %lld -->

%1$lld references run from this collection to others. A further %2$lld stay inside the collection itself and are excluded — a hand-off to yourself is not a hand-off.

<!-- END SOURCE: archival.flows.caption.outgoing %lld %lld -->

---

#### Focused, incoming — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 374–375 | key: archival.flows.caption.incoming %lld %lld -->

%1$lld references run from other collections to this one. A further %2$lld stay inside the collection itself and are excluded — a hand-off to yourself is not a hand-off.

<!-- END SOURCE: archival.flows.caption.incoming %lld %lld -->

---

#### A selected hand-off — outgoing detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 542–543 | key: archival.flows.card.detail.outgoing %lld %lld -->

%1$lld references, %2$lld%% of everything this collection hands off.

<!-- END SOURCE: archival.flows.card.detail.outgoing %lld %lld -->

---

#### A selected hand-off — incoming detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 544–545 | key: archival.flows.card.detail.incoming %lld %lld -->

%1$lld references, %2$lld%% of everything handed off to this collection.

<!-- END SOURCE: archival.flows.card.detail.incoming %lld %lld -->

---

#### No hand-offs — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 573–573 | key: archival.flows.none.title -->

No Hand-Offs Recorded

<!-- END SOURCE: archival.flows.none.title -->

---

#### No hand-offs — detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 575–577 | key: archival.flows.none.detail %@ %lld %lld -->

No cross-reference runs between %1$@ and another collection in this direction. The cross-reference style these come from postdates 1945. Only %2$lld of the %3$lld volumes in the series carry any of these references.

<!-- END SOURCE: archival.flows.none.detail %@ %lld %lld -->

---

#### The caveat block — the footnote share, stated first

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 646–648 | key: archival.flows.caveats.footnotes %@ -->

%@ of these references are footnotes. A ribbon therefore describes how the editors annotated. While annotating material from one collection, they pointed the reader to material from another. It is not a relationship between the archives themselves.

<!-- END SOURCE: archival.flows.caveats.footnotes %@ -->

---

#### The caveat block — coverage, dates, and the excluded class axis

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 653–655 | key: archival.flows.caveats.body.v2 %lld %lld %lld %lld -->

Coverage is uneven, and the gap is itself a finding. Only %1$lld of the %2$lld volumes in the series contribute a single reference. The cross-reference style these come from postdates 1945. The figures cover the whole series whatever you have downloaded, but they carry no dates. The stored data is a pair of archival units and a count, with no volume or year attached. So you cannot narrow this mode to a period. Central-file classes are left out on purpose. Across the whole series they carry %3$lld references over %4$lld pairs, which is under two per pair. That is too thin to rank, and there are no labels to rank it with.

<!-- END SOURCE: archival.flows.caveats.body.v2 %lld %lld %lld %lld -->

---

#### The caveat block — why you cannot browse the citations

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 661–662 | key: archival.flows.caveats.browse -->

You cannot browse the individual citations here. The app can list the references inside the volumes you have indexed. It cannot tell which of those are the footnotes this measure is built on. A list would therefore disagree with the diagram above it, and nothing on screen would explain why.

<!-- END SOURCE: archival.flows.caveats.browse -->

---

#### The References picker — first option

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsData.swift | lines: 59–60 | key: archival.flows.layer.printed -->

Between printed documents

<!-- END SOURCE: archival.flows.layer.printed -->

---

#### The References picker — second option

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsData.swift | lines: 62–63 | key: archival.flows.layer.unprinted -->

To unprinted material

<!-- END SOURCE: archival.flows.layer.unprinted -->

---

#### The References picker — its label

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 158–158 | key: archival.flows.layer -->

References

<!-- END SOURCE: archival.flows.layer -->

---

#### Unprinted material — what this layer is for

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 138–139 | key: archival.flows.intro.unprinted -->

FRUS editors often name a document they did not print, and say where it is filed. Added up across the series, those pointers show where the editors sent readers for the record they left out.

<!-- END SOURCE: archival.flows.intro.unprinted -->

---

#### Unprinted material — unfocused title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 261–262 | key: archival.flows.top.title.unprinted -->

The heaviest pointers to unprinted material

<!-- END SOURCE: archival.flows.top.title.unprinted -->

---

#### Unprinted material — unfocused caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 294–295 | key: archival.flows.top.caption.unprinted -->

Choose a focus collection above to see everywhere its footnotes send you.

<!-- END SOURCE: archival.flows.top.caption.unprinted -->

---

#### Unprinted material — focused, outgoing title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 350–351 | key: archival.flows.title.unprinted.outgoing -->

Where the footnotes send you

<!-- END SOURCE: archival.flows.title.unprinted.outgoing -->

---

#### Unprinted material — focused, incoming title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 352–353 | key: archival.flows.title.unprinted.incoming -->

Which collections' footnotes send you here

<!-- END SOURCE: archival.flows.title.unprinted.incoming -->

---

#### Unprinted material — focused, outgoing caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 365–366 | key: archival.flows.caption.unprinted.outgoing %lld %lld -->

%1$lld footnotes on documents from this collection name unprinted material in other collections. A further %2$lld name unprinted material in this collection itself, and are left out — the diagram shows where the editors sent you *away* to.

<!-- END SOURCE: archival.flows.caption.unprinted.outgoing %lld %lld -->

---

#### Unprinted material — focused, incoming caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 367–368 | key: archival.flows.caption.unprinted.incoming %lld %lld -->

%1$lld footnotes on documents from other collections name unprinted material in this one. A further %2$lld come from documents already in this collection, and are left out.

<!-- END SOURCE: archival.flows.caption.unprinted.incoming %lld %lld -->

---

#### Unprinted material — the scope caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 608–610 | key: archival.flows.caveats.unprinted.scope %lld %lld %lld %lld -->

This layer reads two kinds of citation only: State Department lot files, and collections in the presidential libraries. Both are ways of filing that came in after 1945, so the earlier volumes are almost absent here even though their footnotes are full of archival citations. Those earlier citations give a file number in the central files, which this measure does not yet read. %1$lld citations were found and %2$lld of them matched a known collection, across %3$lld of the %4$lld volumes in the series.

<!-- END SOURCE: archival.flows.caveats.unprinted.scope %lld %lld %lld %lld -->

---

#### Unprinted material — the coverage-span caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 617–619 | key: archival.flows.caveats.unprinted.era %lld %lld -->

The volumes contributing here cover %1$lld to %2$lld.

<!-- END SOURCE: archival.flows.caveats.unprinted.era %lld %lld -->

---

#### Unprinted material — the “Ibid.” caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 625–627 | key: archival.flows.caveats.unprinted.ibid %@ -->

%@ of these citations come from an “Ibid.” — the editor wrote the archive out once and then referred back to it. The app follows that back the way a reader would, but it is a reading, not a quotation.

<!-- END SOURCE: archival.flows.caveats.unprinted.ibid %@ -->

---

#### Unprinted material — what a ribbon claims

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 632–633 | key: archival.flows.caveats.unprinted.claim -->

A ribbon says the editors, working on material from one collection, told the reader that something they did not print is in another. It does not say the two archives refer to each other, and it is not a count of documents held anywhere.

<!-- END SOURCE: archival.flows.caveats.unprinted.claim -->

---

#### Unprinted material — export axis, outgoing

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 240–241 | key: archival.export.axis.flows.unprinted.outgoing -->

Unprinted material this collection's footnotes name

<!-- END SOURCE: archival.export.axis.flows.unprinted.outgoing -->

---

#### Unprinted material — export axis, incoming

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 242–243 | key: archival.export.axis.flows.unprinted.incoming -->

Footnotes naming unprinted material in this collection

<!-- END SOURCE: archival.export.axis.flows.unprinted.incoming -->

---

### 9.5 Your Library — the same questions asked of your own index

#### What this mode is for

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 926–927 | key: archival.library.intro %lld %lld -->

The archival profile of **your** library — computed from the %1$lld source notes across the %2$lld indexed volumes that carry them, not from the bundled corpus-wide aggregates.

<!-- END SOURCE: archival.library.intro %lld %lld -->

---

#### While your source notes are counted

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 919–920 | key: archival.library.loading -->

Counting your indexed source notes…

<!-- END SOURCE: archival.library.loading -->

---

#### Composition card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 936–937 | key: archival.library.composition.title | shared: iOS+macOS (the same key in both views — edit both) -->

Where your documents come from

<!-- END SOURCE: archival.library.composition.title -->

---

#### Composition card — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 945–946 | key: archival.library.composition.caption -->

Every source note in your index, divided among the kinds of archival collection they cite.

<!-- END SOURCE: archival.library.composition.caption -->

---

#### Citation-forms card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 981–982 | key: archival.library.bands.title | shared: iOS+macOS (the same key in both views — edit both) -->

Citation forms across your volumes

<!-- END SOURCE: archival.library.bands.title -->

---

#### Citation-forms card — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 990–991 | key: archival.library.bands.caption -->

The same composition, split by the era your volumes cover. Read left to right it is the shift from the State Department's decimal file, through the postwar bureau lot files, to the presidential libraries.

<!-- END SOURCE: archival.library.bands.caption -->

---

#### Your collections card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1070–1071 | key: archival.library.collections.title | shared: iOS+macOS (the same key in both views — edit both) -->

Your most-cited collections

<!-- END SOURCE: archival.library.collections.title -->

---

#### Your collections card — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1080–1081 | key: archival.library.collections.caption %lld %lld -->

Matched from your own source notes against the archival authority list in the app. %1$lld notes cite the central files, which are a filing system rather than a collection. Another %2$lld name something the list does not recognise. Neither group is listed here.

<!-- END SOURCE: archival.library.collections.caption %lld %lld -->

---

#### Your collections card — nothing resolved

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1091–1092 | key: archival.library.collections.empty -->

None of your volumes' source notes name a collection the bundled authority recognises.

<!-- END SOURCE: archival.library.collections.empty -->

---

#### Your collections card — row hint

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1124–1125 | key: archival.library.collections.hint -->

Shows the documents in your index drawn from this collection

<!-- END SOURCE: archival.library.collections.hint -->

---

#### Footer — what these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1159–1160 | key: archival.library.footer %lld %lld -->

Counted from the %1$lld volumes you have indexed. %2$lld more exist in the series. Index more and these charts change with you. The Collections mode is different: it does not depend on what you have downloaded.

<!-- END SOURCE: archival.library.footer %lld %lld -->

---

#### Footer — why the total is smaller than your document count

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1166–1167 | key: archival.library.footer.detail %lld %lld -->

A source note is not a document. Only documents whose editors recorded where the original was found appear here. So this total is smaller than your indexed document count, and volumes with no source notes add nothing. The collections list matches each citation to a named body of records. %1$lld notes cite the central files, which are a filing system rather than a collection; those notes are counted in the composition above. Another %2$lld name something the app's authority list does not recognise.

<!-- END SOURCE: archival.library.footer.detail %lld %lld -->

---

#### Nothing indexed yet — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1179 | key: archival.library.empty.title -->

No Source Notes Yet

<!-- END SOURCE: archival.library.empty.title -->

---

#### Nothing indexed yet — detail

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1181–1182 | key: archival.library.empty.detail -->

Download and index a volume and this page will show where its documents came from. The Collections mode works without any downloads.

<!-- END SOURCE: archival.library.empty.detail -->

---

### 9.6 The info popover ("About Archival Analytics")

*Shared: `FeatureInfoButton.archivalAnalytics` in `FRUSTheme.swift` feeds both platforms. Edit once.*

#### What you're seeing — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 234 | key: archival.info.shows.title -->

What you're seeing

<!-- END SOURCE: archival.info.shows.title -->

---

#### What you're seeing — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 235–236 | key: archival.info.shows.detail.v2 -->

Where the editors of Foreign Relations of the United States found the documents they published. Collections ranks the archival collections and central-file classes each era's volumes drew on. Network puts one collection at the centre and groups everything cited alongside it by custodian. Flows maps where an editor's cross-reference led when it pointed from one document to another. Your Library counts the same things in the volumes you have indexed.

<!-- END SOURCE: archival.info.shows.detail.v2 -->

---

#### Documents and volumes — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 243 | key: archival.info.weights.title -->

Documents and volumes count different things

<!-- END SOURCE: archival.info.weights.title -->

---

#### Documents and volumes — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 244–245 | key: archival.info.weights.detail -->

Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. A collection can supply a thousand documents to five volumes, or six hundred to ninety-eight. Both lists are correct. Switching the weight changes the order, and sometimes which collections appear at all. A collection named only in a volume's front matter has volumes but no documents.

<!-- END SOURCE: archival.info.weights.detail -->

---

#### Why Central Files is hidden — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 247 | key: archival.info.umbrella.title -->

Why Central Files is hidden

<!-- END SOURCE: archival.info.umbrella.title -->

---

#### Why Central Files is hidden — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 248–249 | key: archival.info.umbrella.detail -->

The State Department's Central Files are cited by 157 volumes and supply more than seventeen thousand documents. That is over twice the next-largest collection, and its bar would flatten every other one. So it is hidden by default, and the chart states what it withheld. Turn the chip off to see it. The era-specific Central Files records are never hidden.

<!-- END SOURCE: archival.info.umbrella.detail -->

---

#### A flow is an editor's footnote — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 251 | key: archival.info.flows.title -->

A flow is an editor's footnote, not an archive's

<!-- END SOURCE: archival.info.flows.title -->

---

#### A flow is an editor's footnote — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 252–253 | key: archival.info.flows.detail -->

About 95% of the references behind Flows are footnotes. A ribbon means the editors annotated material from one collection and sent you to material from another. It does not mean the two archives cite each other. Coverage is uneven, and that is itself a finding. Only 254 of the 552 volumes carry any of these references, because the cross-reference style they come from postdates 1945.

<!-- END SOURCE: archival.info.flows.detail -->

---

#### Collections and classes — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 255 | key: archival.info.units.title -->

Collections and classes are different things

<!-- END SOURCE: archival.info.units.title -->

---

#### Collections and classes — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 256–257 | key: archival.info.units.detail -->

A named collection is a body of records with a custodian. A central-file class is a subject heading inside one filing system — 763.72 for the European War, POL 27 VIET S for the war in South Vietnam. The two are never mixed in one ranking. Before 1948 the series cites classes far more than collections. After 1976 it barely cites classes at all.

<!-- END SOURCE: archival.info.units.detail -->

---

---

## 10. Export Method Statements

*Every analytics figure and table that leaves the app carries a methods statement above its numbers — a `#`-commented preamble on a CSV, a printed block on a figure plate. This is the prose a reader sees when the file has travelled without the app, so it has to stand alone. §5 already carries the corpus, Person, Cross-Reference and Word Cloud statements; the Archival and About-the-Series ones are new here.*

---

### 10.1 Archival Analytics

#### The sentence every archival export carries

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 54–55 | key: archival.export.caveat.base -->

Method: these figures come from the source note on each published FRUS document. That note is the citation naming where the editors found the archival original. So they record where the editors drew documents from, not what the archives themselves hold. Collections are grouped across volumes by name. When two spellings of one name fail to merge, a single body of records appears twice under nearby names.

<!-- END SOURCE: archival.export.caveat.base -->

---

#### Why the three weights disagree

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 290–291 | key: archival.export.caveat.weight -->

The three weights count different things. A document counts only when its own source note names the collection. A volume counts when either its front matter or any document source note names the collection. So a collection named only in front matter has volumes but no documents. Unprinted pointers counts neither: it counts footnotes naming material FRUS did not print, and is never added to the other two. Switching the weight changes which collections appear in the ranking, not just their order.

<!-- END SOURCE: archival.export.caveat.weight -->

---

#### Why an era can look empty

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 296–297 | key: archival.export.caveat.coverage -->

Coverage is uneven by era. Named collections are scarce before 1948, where central-file classes carry almost the whole record. Classes all but disappear after 1976, where the presidential libraries carry it. A thin ranking usually means you have the wrong unit selected, not a thin era.

<!-- END SOURCE: archival.export.caveat.coverage -->

---

#### Collections ranking — what the era covers

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 92–93 | key: archival.export.caveat.scope %lld %lld -->

Scope: %1$lld volumes cover this era, and %2$lld archival units in them carry at least one document under the current unit and weight.

<!-- END SOURCE: archival.export.caveat.scope %lld %lld -->

---

#### Collections ranking — what the umbrella filter withheld

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 87–88 | key: archival.export.caveat.umbrella %lld %@ -->

Withheld: this ranking leaves out the Central Files umbrella record. On its own it accounts for %1$lld %2$@ in this era, and its bar would flatten the scale. The era-specific Central Files records are still included.

<!-- END SOURCE: archival.export.caveat.umbrella %lld %@ -->

---

#### Cited Over Time export — what the bars count

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 153–154 | key: archival.export.caveat.timeline %lld -->

Scope: the whole published series, not this device's library. Each bar counts the volumes in one coverage era whose front matter or document source notes name this collection — volumes, not documents, so a volume citing it once counts the same as a volume built on it. The %lld eras run contiguously from the first era that cites it to the last, so an interior gap is a real gap. The buckets are FRUS's own subseries rather than decades, because a decade axis splits a published subseries across two bars.

<!-- END SOURCE: archival.export.caveat.timeline %lld -->

---

#### Network — what a link means

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 209–210 | key: archival.export.caveat.network.grain -->

What a link means: two collections are linked because the same volumes drew on both. Each document carries exactly one source note, so no document can cite two collections. The shared-documents measure counts how much material the two collections supplied together to the volumes they share. It does not count documents citing both.

<!-- END SOURCE: archival.export.caveat.network.grain -->

---

#### Network — what the table lists

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 212–213 | key: archival.export.caveat.network.scope %lld %lld %lld -->

Scope: this table lists %1$lld of the %2$lld units above the current threshold. In all, %3$lld collections share two or more volumes with the focus. The graph draws at most six per custodian so each quadrant stays readable. This table lists exactly what the graph drew.

<!-- END SOURCE: archival.export.caveat.network.scope %lld %lld %lld -->

---

#### Flows — the footnote share, stated first

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 250–251 | key: archival.export.caveat.flows.footnotes %@ -->

Read this first: %@ of these references are footnotes. A row describes how the editors annotated. While annotating material from one collection, they pointed the reader to material from another. It is not a relationship between the archives themselves.

<!-- END SOURCE: archival.export.caveat.flows.footnotes %@ -->

---

#### Flows — coverage and the absence of dates

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 254–255 | key: archival.export.caveat.flows.coverage %lld %lld -->

Coverage: only %1$lld of the %2$lld volumes in the series contribute any of these references. The cross-reference style they come from postdates 1945. The figures carry no dates: the stored data is a pair of archival units and a count. You cannot narrow this view to a period.

<!-- END SOURCE: archival.export.caveat.flows.coverage %lld %lld -->

---

#### Flows — why the class axis is excluded

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 258–259 | key: archival.export.caveat.flows.classes %lld %lld -->

Excluded: central-file classes. Between them the whole series carries %1$lld references over %2$lld pairs — under two per pair — which is too thin to rank, and there are no labels to rank it with.

<!-- END SOURCE: archival.export.caveat.flows.classes %lld %lld -->

---

#### Flows — same-unit references

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 265–266 | key: archival.export.caveat.flows.sameUnit %lld -->

Excluded: %lld references from this collection to itself. A hand-off to yourself is not a hand-off, but the figure is stated so the exclusion is visible.

<!-- END SOURCE: archival.export.caveat.flows.sameUnit %lld -->

---

#### Flows, unprinted material — what a row claims

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 229–230 | key: archival.export.caveat.flows.unprinted.claim %lld %lld -->

Read this first: every row is an editorial footnote naming archival material FRUS did not print. A row says the editors, working on material from one collection, told the reader that something unprinted is in another. It is not a relationship between the archives and not a count of documents held anywhere. %1$lld citations were found; %2$lld matched a known collection.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.claim %lld %lld -->

---

#### Flows, unprinted material — scope

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 233–234 | key: archival.export.caveat.flows.unprinted.scope %lld %lld -->

Scope: State Department lot files and presidential-library collections only. Both are post-1945 ways of filing, so pre-war volumes are nearly absent even though their footnotes cite archives heavily — those citations give a central-file number, which this measure does not yet read. %1$lld of the %2$lld volumes in the series contribute a row.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.scope %lld %lld -->

---

#### Flows, unprinted material — method

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 237–238 | key: archival.export.caveat.flows.unprinted.ibid %@ -->

Method: %@ of these citations come from an “Ibid.” — the archive is named once and referred back to. The app follows that back the way a reader would; it is a reading, not a quotation.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.ibid %@ -->

---

#### Flows, unprinted material — coverage span

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 243–244 | key: archival.export.caveat.flows.unprinted.era %lld %lld -->

Coverage span: the contributing volumes cover %1$lld to %2$lld.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.era %lld %lld -->

---

---

#### Your Library — what these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 183–184 | key: archival.export.caveat.library %lld %lld %lld -->

Scope: counted from what you have indexed on this device. That is %1$lld source notes across the %2$lld indexed volumes that carry them, out of %3$lld volumes in the series. These figures change as you index more volumes. Do not compare them with the figures for the whole series.

<!-- END SOURCE: archival.export.caveat.library %lld %lld %lld -->

---

#### Your Library — what a source note is

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 187–188 | key: archival.export.caveat.notes -->

Unit: a source note is not a document. Only documents whose editors recorded where the original was found are counted, so this total is smaller than the indexed document count.

<!-- END SOURCE: archival.export.caveat.notes -->

---

### 10.2 The four About-the-Series dashboards

*One builder per dashboard in `SeriesAnalyticsExport.swift`. Three of the four never read a document's date, so each states its own dating rule rather than inheriting the corpus one — that is what these `dating` blocks are.*

#### What corpus these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 41–43 | key: series.export.caveat.corpus %lld -->

Corpus: these figures come from a data file that ships with the app and covers all %lld catalogued volumes of the series. They do not depend on which volumes you have indexed on this device. Every device shows the same numbers, and they are available before you download anything.

<!-- END SOURCE: series.export.caveat.corpus %lld -->

---

#### When a subseries scope is active

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 51–53 | key: series.export.caveat.scope %@ -->

Scoped to %@ — every figure below is recomputed from that subset's volumes alone and is not comparable with a whole-series export.

<!-- END SOURCE: series.export.caveat.scope %@ -->

---

#### Production & timeliness — dating rule

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 75–76 | key: series.export.dating.production -->

Dating: no document date is read. A volume sits at its print year, taken from the publication-date in its TEI header. Its publication lag is that print year minus the last year of the coverage range in the same header. Neither figure is derived from the dates of the volume's own documents.

<!-- END SOURCE: series.export.dating.production -->

---

#### Geographic emphasis — dating rule

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 96–97 | key: series.export.dating.geography -->

Dating: no document date is read. A volume is placed by the coverage range declared in its TEI header. Its regions come from the volume's own subject tags. So these figures count volumes concerned with a region, not documents about it.

<!-- END SOURCE: series.export.dating.geography -->

---

#### Archival sourcing — dating rule

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 133–134 | key: series.export.dating.provenance -->

Dating: no document date is read. Each source note sits in the coverage decade of the volume that printed it, taken from that volume's declared date range. The trend starts around 1900. Earlier volumes are published correspondence and carry no archival source notes.

<!-- END SOURCE: series.export.dating.provenance -->

---

#### Archival sourcing — what a source note is

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 119–121 | key: series.export.caveat.provenanceNotes %lld -->

Unit: %lld parsed source notes. A source note is the citation naming where a document's archival original was found. "Other / Unclassified" means a citation the parser could not classify, not a missing note.

<!-- END SOURCE: series.export.caveat.provenanceNotes %lld -->

---

#### Archival sourcing — when categories are hidden

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 114–116 | key: series.export.caveat.hiddenCategories %@ -->

Re-based: %@ are hidden, and every share in this table is a share of the categories shown rather than of all source notes. A decade with nothing in any shown category is zero here, not absent.

<!-- END SOURCE: series.export.caveat.hiddenCategories %@ -->

---

#### Administration profiles — dating rule

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 192–193 | key: series.export.dating.administration -->

Dating: each document is placed by its own editorial date bounds, the frus:doc-dateTime-min and -max attributes on the document element. A TEI <date> is not used, and there is no fallback to the volume's start year. An undated document is attributed to no administration and drops out.

<!-- END SOURCE: series.export.dating.administration -->

---

#### Administration profiles — what the year range does

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 148–149 | key: series.export.caveat.adminYears -->

Year range: this selects which administrations appear, by whether the president's term overlaps the range. It does not re-count documents. An administration shown here carries its full count even when only part of its term falls inside the range.

<!-- END SOURCE: series.export.caveat.adminYears -->

---

#### Administration profiles — why the counts overlap

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 155–156 | key: series.export.caveat.adminOverlap -->

Attribution: a document counts toward every administration its date range overlaps. The counts therefore overlap each other and add up to more than the whole series. A term ends on the day the next president takes office. A document dated on a succession day therefore belongs to the incoming president. These counts measure whose foreign policy the documents cover, not when the volumes were published.

<!-- END SOURCE: series.export.caveat.adminOverlap -->

---

#### Administration profiles — the editorial-notes toggle

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 174–176 | key: series.export.caveat.adminNotes.v2 %@ -->

Editorial notes: %@. Editorial-note documents carry a span of dates rather than a single date; excluding them also withholds a volume whose only tie to an administration is such a note.

<!-- END SOURCE: series.export.caveat.adminNotes.v2 %@ -->

---

---

## 11. Source Explorer — Panel Prose

*The explanatory notes inside Source Explorer: what a citation resolved to, what it did not, and what a researcher should do about it. §5 already carries the Source Explorer info popover; this section carries the panels themselves. Almost every key here exists twice — once in `SourceExplorerView.swift` (iOS) and once in `MacSourceExplorerView.swift` — so a revision has to be applied to both. This section is new in this regeneration.*

---

### 11.1 When there is no source note, or no key to look one up by

#### No source note on this document

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 237–238 | key: source.explorer.noNote.body -->

This document has no archival source note. Its likely filing is predicted from its dateline and FRUS chapter — see the resolution on the right.

<!-- END SOURCE: source.explorer.noNote.body -->

---

#### No source note — what you can still do

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1312–1313 | key: source.explorer.noNote.detail | shared: iOS+macOS (the same key in both views — edit both) -->

This document carries no archival source note, and its exact filing couldn't be predicted from its dateline and FRUS chapter.

<!-- END SOURCE: source.explorer.noNote.detail -->

---

#### No source note — the diplomatic series

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1332–1333 | key: source.explorer.noNote.series.diplomatic | shared: iOS+macOS (the same key in both views — edit both) -->

Documents of this era are held in the country-arranged diplomatic series (Despatches and Instructions) at the National Archives, Record Group 59.

<!-- END SOURCE: source.explorer.noNote.series.diplomatic -->

---

#### No source note — the numerical file

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1335–1336 | key: source.explorer.noNote.series.numerical | shared: iOS+macOS (the same key in both views — edit both) -->

Documents of this era are filed in the 1906–1910 Numerical File at the National Archives, Record Group 59, arranged by case number rather than by country or date.

<!-- END SOURCE: source.explorer.noNote.series.numerical -->

---

#### The note parsed, but carries no lookup key

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1178–1179 | key: source.explorer.noKey.explanation | shared: iOS+macOS (the same key in both views — edit both) -->

A free NARA Catalog API key is needed to search for lot file and Presidential Library records. Add your key in Settings.

<!-- END SOURCE: source.explorer.noKey.explanation -->

---

#### The citation form was not recognised

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 838–839 | key: source.explorer.unrecognized.explanation | shared: iOS+macOS (the same key in both views — edit both) -->

The source note format was not recognized. The raw text is shown to the left. Automated NARA Catalog resolution is unavailable for this entry.

<!-- END SOURCE: source.explorer.unrecognized.explanation -->

---

#### The macOS window with no document selected

<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 1967–1968 | key: source.explorer.window.empty.detail -->

Open a document with a source note, then tap Sources in the toolbar. Or switch to Collections to browse the archival collections FRUS cites.

<!-- END SOURCE: source.explorer.window.empty.detail -->

---

### 11.2 Central files — decimal and subject-numeric

#### Requesting a decimal-file record from NARA

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 426–427 | key: source.explorer.centralFiles.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

To request the original record from NARA, give them the decimal file number above. Add any telegram serial number, the from/to information, and the document's date from the source note. Archivists use these details to find the record within the file.

<!-- END SOURCE: source.explorer.centralFiles.cite.note -->

---

#### Which filing period a decimal number belongs to

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1635–1636 | key: source.explorer.decimalPeriod.hint | shared: iOS+macOS (the same key in both views — edit both) -->

Box lists, purport indexes, and the filing manual for this period are available on the linked NARA page.

<!-- END SOURCE: source.explorer.decimalPeriod.hint -->

---

#### The Central Foreign Policy File

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 812–813 | key: source.explorer.cfpf.note | shared: iOS+macOS (the same key in both views — edit both) -->

CFPF records are available on microfilm (P-Reels, D-Reels, N-Reels) at NARA and as electronic telegrams in the AAD database. No API key is required for either resource.

<!-- END SOURCE: source.explorer.cfpf.note -->

---

#### Requesting a CFPF record from NARA

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 580–581 | key: source.explorer.cfpf.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

To request the original record from NARA, give them the file identifier above. Add any telegram channel and serial numbers, the from/to information, and the document's date from the source note.

<!-- END SOURCE: source.explorer.cfpf.cite.note -->

---

#### The 1906–1910 Numerical File — roll found

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1573–1574 | key: source.explorer.numericalFile.found | shared: iOS+macOS (the same key in both views — edit both) -->

These digitized rolls hold File No. \(fileIdentifier). Open one and review the images page by page — documents are filed in numeric order by case.

<!-- END SOURCE: source.explorer.numericalFile.found -->

---

#### The 1906–1910 Numerical File — no roll covers it

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1552–1553 | key: source.explorer.numericalFile.gap | shared: iOS+macOS (the same key in both views — edit both) -->

No digitized roll directly covers this file number. Use the Card Index to confirm the case number, then browse the Numerical File series.

<!-- END SOURCE: source.explorer.numericalFile.gap -->

---

### 11.3 Lot files

#### Requesting a lot file from NARA

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 984–985 | key: source.explorer.lotFile.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

When requesting the original records from NARA, cite the HMS/MLR entry number together with the lot number — it is the identifier archives staff use to locate the series.

<!-- END SOURCE: source.explorer.lotFile.cite.note -->

---

#### Resolved from the bundled lot index

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 989–990 | key: source.explorer.lotFile.bundled.note | shared: iOS+macOS (the same key in both views — edit both) -->

Resolved from the bundled index — no API key required. Records may be described at the series level rather than digitized page-by-page.

<!-- END SOURCE: source.explorer.lotFile.bundled.note -->

---

#### HMS / MLR entry numbers

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 970–971 | key: source.explorer.lotFile.hmsMlr.series.note | shared: iOS+macOS (the same key in both views — edit both) -->

These entry numbers identify the enclosing file series, not this specific file unit.

<!-- END SOURCE: source.explorer.lotFile.hmsMlr.series.note -->

---

#### A possible match, not a confirmed one

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1059–1060 | key: source.explorer.curatedLot.possible.note | shared: iOS+macOS (the same key in both views — edit both) -->

This match was made by collection name, not by a catalog control number. Confirm the lot number against the series before citing it.

<!-- END SOURCE: source.explorer.curatedLot.possible.note -->

---

#### Several candidate lots

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1111–1112 | key: source.explorer.curatedLot.candidates.note | shared: iOS+macOS (the same key in both views — edit both) -->

NARA did not accession this lot as a single series, so no one record is the answer. Review the candidates against the document's date and type.

<!-- END SOURCE: source.explorer.curatedLot.candidates.note -->

---

#### A lot file NARA divided across several series

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/LotClaimantsIndex.swift | lines: 143–144 | key: source.explorer.dividedLot.rationale %lld -->

NARA divided this lot file across %lld series. Each series lists the lot among its own control numbers, so each holds part of the records this citation names. The citation alone does not say which one.

<!-- END SOURCE: source.explorer.dividedLot.rationale %lld -->

---

### 11.4 Presidential libraries and other repositories

#### Presidential library — provenance

<!-- SOURCE: FRUSExplorer/SourceExplorer/PresidentialLibraryOutcome.swift | lines: 213–217 | key: source.explorer.presLib.offline.provenance -->

Matched against the National Archives' own description of this library, from the bundled catalog — no API key or network required.

<!-- END SOURCE: source.explorer.presLib.offline.provenance -->

---

#### Presidential library — collection only

<!-- SOURCE: FRUSExplorer/SourceExplorer/PresidentialLibraryOutcome.swift | lines: 183–188 | key: source.explorer.presLib.offline.collectionOnly -->

The collection is identified, but the citation does not name one of its \(c.series.count) series unambiguously. Open the collection record to find the series cited.

<!-- END SOURCE: source.explorer.presLib.offline.collectionOnly -->

---

#### Presidential library — several candidate series

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/PresidentialLibraryOutcome.swift | lines: 191–197 | key: source.explorer.presLib.offline.candidates -->

The collection is identified. The series named in the citation matches \(candidates.count) of its records, and \(shown) of those are listed below. No single record is the answer on its own, so check the titles and dates before citing.

<!-- END SOURCE: source.explorer.presLib.offline.candidates -->

---

#### A repository outside NARA's custody

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 524–531 | key: source.explorer.nara.outsideCustody | shared: iOS+macOS (the same key in both views — edit both) -->

\(library) is not a National Archives repository, so the NARA Catalog has no record of this collection. A search on the collection name alone returns results that look authoritative but are not. None are shown here.

<!-- END SOURCE: source.explorer.nara.outsideCustody -->

---

#### A foreign archive

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 779–780 | key: source.explorer.foreignArchive.note | shared: iOS+macOS (the same key in both views — edit both) -->

Foreign government archives are not indexed in the NARA Catalog. Consult the archive directly for access.

<!-- END SOURCE: source.explorer.foreignArchive.note -->

---

#### Previously published material

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 788–789 | key: source.explorer.published.note | shared: iOS+macOS (the same key in both views — edit both) -->

This document was previously published. Consult the cited publication for the original source.

<!-- END SOURCE: source.explorer.published.note -->

---

#### Intelligence records

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 439–440 | key: source.explorer.cia.note -->

CIA records are not in the NARA Catalog. The CREST database (cia.gov/readingroom) holds declassified CIA documents including operational files and historical collections.

<!-- END SOURCE: source.explorer.cia.note -->

---

#### A named file series

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 828–829 | key: source.explorer.namedSeries.note -->

A named file series cited without a lot number. The citation does not state the holding repository, so no automated NARA Catalog query is available.

<!-- END SOURCE: source.explorer.namedSeries.note -->

---

#### What a named file series is

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 340–341 | key: source.explorer.namedSeries.explainer -->

A named file series cited without a lot number. The repository is not stated in the citation.

<!-- END SOURCE: source.explorer.namedSeries.explainer -->

---

#### A country series

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1276–1277 | key: source.explorer.countrySeries.intro | shared: iOS+macOS (the same key in both views — edit both) -->

This document predates the 1906 Numerical File. Based on its dateline and FRUS chapter, it was likely filed in the digitized series below — open a roll and review the images for the document's date.

<!-- END SOURCE: source.explorer.countrySeries.intro -->

---

### 11.5 The Paris Peace Conference records (RG 256)

#### Why these are not RG 59

<!-- SOURCE: FRUSExplorer/SourceExplorer/ParisPeaceRecords.swift | lines: 170–175 | key: source.explorer.parisPeace.provenance -->

The American Commission to Negotiate Peace kept its own decimal file, separate from the State Department's. These records are Record Group 256, so the RG 59 central-file finding aids and filing manual do not describe them.

<!-- END SOURCE: source.explorer.parisPeace.provenance -->

---

#### Why the panel will not name a roll

<!-- SOURCE: FRUSExplorer/SourceExplorer/ParisPeaceRecords.swift | lines: 185–191 | key: source.explorer.parisPeace.rolls -->

Microfilm publication M820 reproduces the series. Most of its 538 file units are digitised, each covering a range of decimal numbers. This panel does not say which one holds this document. The ranges overlap and are not always continuous, so use the index below to find it.

<!-- END SOURCE: source.explorer.parisPeace.rolls -->

---

### 11.6 Digitised scans

#### Only the class is known — iOS

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 609–614 | key: source.explorer.scans.classOnly -->

NARA has scanned \(count) file ranges in decimal class \(cls), but none of them covers \(fileIdentifier). The scans for this file are partial.

<!-- END SOURCE: source.explorer.scans.classOnly -->

---

#### Only the class is known — macOS

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1781–1786 | key: source.explorer.scans.classOnlyMac -->

NARA has scanned \(count) file ranges in this decimal class, but none of them covers \(fileIdentifier). The scans for this file are partial.

<!-- END SOURCE: source.explorer.scans.classOnlyMac -->

---

#### Several ranges contain this file

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1769–1775 | key: source.explorer.scans.multiple | shared: iOS+macOS (the same key in both views — edit both) -->

\(ranges.count) scanned file ranges contain \(fileIdentifier). They are listed narrowest first. NARA digitised this file in overlapping sets, so the widest range is not wrong. The narrowest is simply the most specific.

<!-- END SOURCE: source.explorer.scans.multiple -->

---

#### What a scan range does and does not tell you

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 626–631 | key: source.explorer.scans.caveat -->

This is the scan of the file range the citation falls in, not of this document. The document is somewhere inside it.

<!-- END SOURCE: source.explorer.scans.caveat -->

---

### 11.7 Catalog evidence and manual searches

#### Matched on the record group alone

<!-- SOURCE: FRUSExplorer/SourceExplorer/CatalogQueryEvidence.swift | lines: 130–135 | key: source.explorer.nara.candidates.recordGroupOnly -->

Matched by keyword within record group \(recordGroup). The record group is the one cited; nothing here ties these records to the series cited. Check the series title and dates before citing.

<!-- END SOURCE: source.explorer.nara.candidates.recordGroupOnly -->

---

#### Matched on the collection name alone

<!-- SOURCE: FRUSExplorer/SourceExplorer/CatalogQueryEvidence.swift | lines: 137–142 | key: source.explorer.nara.candidates.collectionNameOnly -->

Searched on the repository and collection names only — no catalog identifier constrains these results to the collection cited. Treat them as leads, and prefer the finding aid above.

<!-- END SOURCE: source.explorer.nara.candidates.collectionNameOnly -->

---

#### An unverified manual search

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 922–923 | key: source.explorer.manualSearch.unverified.detail -->

From a manual search. Not checked against the cited lot number or record group.

<!-- END SOURCE: source.explorer.manualSearch.unverified.detail -->

---

#### What an export says about a manual search

<!-- SOURCE: FRUSExplorer/SourceExplorer/CatalogQueryEvidence.swift | lines: 103–107 | key: source.explorer.manualSearch.exportCaveat -->

NOTE: Result of a manual free-text search. It has not been checked against the cited lot number or record group.

<!-- END SOURCE: source.explorer.manualSearch.exportCaveat -->

---

### 11.8 Related collections

#### Why these collections are listed together

<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionDetailView.swift | lines: 359–360 | key: collection.detail.related.footer -->

These collections appear alongside this one in the same volumes' source lists. Ranking uses the overlap coefficient, so a broad umbrella record does not dominate. The link is at volume level: both collections fed the same compilation. It does not mean the same documents cite both.

<!-- END SOURCE: collection.detail.related.footer -->

---

#### No related collections

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2020–2021 | key: source.explorer.related.empty.noNeighbors | shared: iOS+macOS (the same key in both views — edit both) -->

No other indexed documents cite this archival source. Index more volumes to surface related documents.

<!-- END SOURCE: source.explorer.related.empty.noNeighbors -->

---

#### This citation matched no collection

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2023–2024 | key: source.explorer.related.empty.unmatched | shared: iOS+macOS (the same key in both views — edit both) -->

This source note doesn't cite a recognized lot file, central file, or presidential library, so related documents can't be matched.

<!-- END SOURCE: source.explorer.related.empty.unmatched -->

---

---

## 12. Word Cloud — Keyness and its Reference

*The keyness measure and the bundled corpus reference it is scored against, plus every state in which the app refuses to score rather than showing a number it cannot stand behind. §5 already carries the word cloud's info popover and settings footers; these are the keyness strings added since. This section is new in this regeneration.*

---

### 12.1 What the two measures are

#### Frequency and Distinctive

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1082–1083 | key: wordcloud.info.measure.detail -->

Frequency sizes each word by how often it appears here. That tends to surface the vocabulary every FRUS volume shares. Distinctive compares this scope with a built-in reference for the whole corpus. It sizes each word by how much more it is used here than across the series. The measure is log-likelihood keyness, the corpus-linguistics standard. Distinctive lists only words used more here than in the corpus. A word this scope conspicuously avoids is a real finding, and it will not appear. Words occurring fewer than three times here are never ranked. One or two mentions can top a keyness list without telling you anything about the documents.

<!-- END SOURCE: wordcloud.info.measure.detail -->

---

#### The two numbers on each row

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1087–1088 | key: wordcloud.info.keyness.numbers.detail -->

Each row carries two numbers, and they answer different questions. The score on the right is log-likelihood (G²). It measures how strong the evidence is that the difference is real, and the list is ranked on it. “38× more often here” is the effect size: how much more often the word is used here than across the corpus, per word of text. G² grows with the amount of text, so a long volume scores higher than a short collection for the same effect. When you compare two scopes, compare the multiples. A word marked “unpriced” occurs too rarely across the corpus to be counted in the reference, so its multiple is an upper bound.

<!-- END SOURCE: wordcloud.info.keyness.numbers.detail -->

---

#### The reference, named on screen

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 401–403 | key: wordcloud.keyness.caveat.reference %lld -->

Words occurring fewer than %lld times corpus-wide are unpriced and score as if new.

<!-- END SOURCE: wordcloud.keyness.caveat.reference %lld -->

---

### 12.2 When keyness is unavailable, and why

#### No reference shipped

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 546–547 | key: wordcloud.keyness.unavailable.noArtifact -->

The bundled corpus reference could not be loaded, so there is nothing to measure this scope against.

<!-- END SOURCE: wordcloud.keyness.unavailable.noArtifact -->

---

#### This lens has no reference

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 549–551 | key: wordcloud.keyness.unavailable.lens %@ -->

The “%@” lens has no corpus reference. Names of people, places, and organizations are not counted across the whole corpus, so there is nothing to compare this scope against. Switch to another lens, or size words by frequency.

<!-- END SOURCE: wordcloud.keyness.unavailable.lens %@ -->

---

#### Your settings do not match the reference

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 554–556 | key: wordcloud.keyness.unavailable.mismatch %@ -->

Your settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to compare this scope with the corpus.

<!-- END SOURCE: wordcloud.keyness.unavailable.mismatch %@ -->

---

#### Nothing in this scope clears the floor

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 559–561 | key: wordcloud.keyness.unavailable.floor %lld -->

No word occurs at least %lld times in this scope. A word appearing once or twice can top a keyness ranking without saying anything about the documents, so nothing is ranked.

<!-- END SOURCE: wordcloud.keyness.unavailable.floor %lld -->

---

#### Nothing here is used more than corpus-wide

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 564–565 | key: wordcloud.keyness.unavailable.nothingDistinctive -->

Nothing here is used more than it is across the corpus. That is a real result, not an error: this scope’s vocabulary is typical of the series.

<!-- END SOURCE: wordcloud.keyness.unavailable.nothingDistinctive -->

---

#### This lens found too little to draw

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 629–630 | key: wordcloud.lens.insufficient.detail %@ -->

There aren't enough %@ in this scope to fill a cloud. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.insufficient.detail %@ -->

---

### 12.3 The keyness export

#### Axis label

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 738–739 | key: wordcloud.export.axis.keyness -->

Ranked by keyness (log-likelihood) against the bundled FRUS corpus reference

<!-- END SOURCE: wordcloud.export.axis.keyness -->

---

#### What the reference is

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 703–705 | key: wordcloud.export.caveat.keyness %lld %lld %@ -->

Keyness: each word is scored against a built-in reference for the whole FRUS corpus. That reference covers %lld of the corpus's %lld distinct words for this lens, and was generated %@. Only words used more here than in the corpus are listed. A word this scope conspicuously avoids is a real finding, and this table does not carry it.

<!-- END SOURCE: wordcloud.export.caveat.keyness %lld %lld %@ -->

---

#### When the reference covers everything

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 713–715 | key: wordcloud.export.caveat.keyness.complete %lld -->

Keyness candidates: every word occurring at least %lld times in this scope was scored.

<!-- END SOURCE: wordcloud.export.caveat.keyness.complete %lld -->

---

#### When the reference is truncated

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 709–711 | key: wordcloud.export.caveat.keyness.truncated %lld -->

Keyness candidates: only this scope's %lld most frequent words were scored, so a word that is rare here but unique to it is outside this ranking.

<!-- END SOURCE: wordcloud.export.caveat.keyness.truncated %lld -->

---

#### What "unpriced" means

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 718–720 | key: wordcloud.export.caveat.keyness.cutoff %lld -->

Reference coverage: the reference counts only words occurring at least %lld times across the corpus. A rarer word is marked unpriced rather than absent. It is scored as though the corpus never used it. Treat a high score on a rare word with care.

<!-- END SOURCE: wordcloud.export.caveat.keyness.cutoff %lld -->

---

### 12.4 Empty states

#### Nothing to draw

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1027–1029 | key: wordcloud.empty.detail -->

There's no indexed text in this scope yet. Download and index the relevant volumes, then try again.

<!-- END SOURCE: wordcloud.empty.detail -->

---

#### The macOS window with no scope

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1699–1701 | key: wordcloud.window.empty.detail -->

Pick a scope above, or open a word cloud from a document, volume, collection, tag, saved search, volume scope, or the corpus.

<!-- END SOURCE: wordcloud.window.empty.detail -->

---

---

## 13. Semantic Analytics — the map, its regions, its slices, and its vectors

*The map surface and everything that explains it, plus the Settings section that governs the files
it needs. Gathered here rather than split across §5 and §6 because an editor working on this feature
is working on one idea, and the prose has to hold together: a **region** is a grouping the corpus
produced on its own, a **slice** is a contrast the reader proposed, and the difference between those
two sentences is the feature. Nearly all of it is new in build 42.*

**The standing rule for this section: plainer must not become more confident.** The semantic axis
ships at weight 0, its quality before 1900 is a declared unknown rather than a measured pass, and
the neighbour list is drawn only from volumes on the device even though the map draws all 552. Every
one of those limits is stated somewhere below. If an edit reads as having removed one rather than
unpacked it, that is a defect — say so and it goes back.

---

### 13.1 What the window says about itself


#### Panel heading
<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 137 | key: semanticAnalytics.about.title | shared: iOS+macOS (single edit point) -->

How the corpus's language sits

<!-- END SOURCE: semanticAnalytics.about.title -->

#### What the map is
<!-- The four verbs a reader can act on — tap, lasso, two poles, and (build 42) arriving from a document. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 158 | key: semanticAnalytics.about.body.v2 | shared: iOS+macOS (single edit point) -->



<!-- END SOURCE: semanticAnalytics.about.body.v2 -->

#### Experimental standing
<!-- Not hedging. The blind panel that would have graded early-era quality was retired as a gate, so pre-1900 IS unmeasured, and this is the sentence that says so. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 170 | key: semanticAnalytics.about.experimental | shared: iOS+macOS (single edit point) -->



<!-- END SOURCE: semanticAnalytics.about.experimental -->

#### Layout caveat, under the map
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1289 | key: semanticMap.caveat.map | shared: iOS+macOS (single edit point) -->



<!-- END SOURCE: semanticMap.caveat.map -->


### 13.2 Regions — a grouping the corpus produced


#### What a region is
<!-- New in build 42. The second sentence is load-bearing: the names are the most distinctive words in a SAMPLE (c-TF-IDF over up to 300 documents), not subject headings, and a reader who takes them for topic labels over-reads every region. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1920 | key: semanticMap.region.whatItIs | shared: iOS+macOS (single edit point) -->

A region is a group the corpus fell into on its own — documents whose language reads alike, found by clustering rather than chosen by an editor. Its name is the most distinctive words in a sample of those documents, not a subject heading, so read it as a hint at what the group is about rather than a claim about every document in it.

<!-- END SOURCE: semanticMap.region.whatItIs -->

#### Save the region as a working corpus
<!-- New in build 42. The lasso could carry a set off the map and a region could not. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1951 | key: semanticMap.region.save | shared: iOS+macOS (single edit point) -->

Save as Working Corpus

<!-- END SOURCE: semanticMap.region.save -->

#### Confirmation after saving
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1944 | key: semanticMap.region.saved | shared: iOS+macOS (single edit point) -->

Saved as “%@”. Find it under Working Corpora, where it can scope a search.

<!-- END SOURCE: semanticMap.region.saved -->


### 13.3 Slices — a contrast the reader proposed


#### What a slice adds, on the selection card
<!-- New in build 42, and the complement of §13.2. The last sentence is the one that keeps it honest: ANY two differing volumes produce a spread, so a tidy picture is not evidence. Removing it would leave the text selling the feature. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2163 | key: semanticMap.axis.whatItAdds | shared: iOS+macOS (single edit point) -->

On the map no direction has a meaning. A slice gives one that does: left to right becomes how far each document leans between two volumes you pick, with time running up the side. Any two volumes will produce a spread, so read it as a contrast you proposed — not one the corpus found.

<!-- END SOURCE: semanticMap.axis.whatItAdds -->

#### After one pole is set
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1842 | key: semanticMap.axis.needsSecondPole.v2 | shared: iOS+macOS (single edit point) -->

Tap a document in a different volume and choose “…to here”. The map will then lay every document out by how far it leans between the two.

<!-- END SOURCE: semanticMap.axis.needsSecondPole.v2 -->

#### Refused: both documents in one volume
<!-- An axis runs between two volume summaries, not the two documents tapped. Before build 42 this refusal was silent and read as a dead control. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 649 | key: semanticMap.axis.sameVolume | shared: iOS+macOS (single edit point) -->

An axis runs between two volumes, and both of these documents are in the same one. Pick a document from a different volume as the second end.

<!-- END SOURCE: semanticMap.axis.sameVolume -->

#### Refused: the two volumes are too alike
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 671 | key: semanticMap.axis.tooAlike | shared: iOS+macOS (single edit point) -->

These two volumes read so alike that there is no direction between them to lay the corpus along. Try two volumes you expect to differ.

<!-- END SOURCE: semanticMap.axis.tooAlike -->

#### Refused: no summary for a volume
<!-- Split from the message above in build 42. A missing summary is a property of the build, not of the volumes, and saying 'too alike' there sent the reader to change the wrong thing. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 662 | key: semanticMap.axis.noSummary | shared: iOS+macOS (single edit point) -->

This version of the app has no language summary for one of these volumes, so it cannot place an axis between them. Try a different volume as that end.

<!-- END SOURCE: semanticMap.axis.noSummary -->

#### Reading a slice's position
<!-- The bit width is READ FROM THE ARTIFACT, not typed — it said '256-bit' for a whole generation after the corpus moved to 512. Keep the placeholder. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1321 | key: semanticMap.caveat.slice.position.v2 | shared: iOS+macOS (single edit point) -->

Left to right is how far each document leans from %1$@ toward %2$@. The reading is approximate — it comes from a compact %3$lld-bit summary of each document — so treat a clear side as meaningful and a small gap as noise.

<!-- END SOURCE: semanticMap.caveat.slice.position.v2 -->

#### Reading a slice's vertical axis
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1333 | key: semanticMap.caveat.slice.vertical.v2 | shared: iOS+macOS (single edit point) -->

Up and down is the volume's coverage midpoint, not each document's own date.

<!-- END SOURCE: semanticMap.caveat.slice.vertical.v2 -->


### 13.4 Arriving from a document, and leaving by its neighbours


#### Research-rail tile
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 784 | key: researchRail.tile.semanticMap | shared: iOS+macOS (single edit point) -->

On the Map

<!-- END SOURCE: researchRail.tile.semanticMap -->

#### Research-rail tile help
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 785 | key: researchRail.tile.semanticMap.help | shared: iOS+macOS (single edit point) -->

Show where this document sits on the semantic map, among the documents whose language is most like it

<!-- END SOURCE: researchRail.tile.semanticMap.help -->

#### Nearest-documents heading
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2039 | key: semanticMap.nearest.header | shared: iOS+macOS (single edit point) -->

Nearest in language

<!-- END SOURCE: semanticMap.nearest.header -->

#### What the nearest list is drawn from
<!-- The map draws all 552 volumes; this list can only score documents whose vectors are on the device. Saying so is not optional — without it the ten rows read as the ten nearest in the corpus. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2063 | key: semanticMap.nearest.fence | shared: iOS+macOS (single edit point) -->

Drawn only from volumes downloaded on this device — the map shows the whole series, so there may be nearer documents it cannot score yet.

<!-- END SOURCE: semanticMap.nearest.fence -->

#### When the anchor's own volume is absent
<!-- The anchor's own vectors ARE the query, so this is a harder limit than the one above: no vectors for this volume means no comparison at all. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2074 | key: semanticMap.nearest.needsVolume | shared: iOS+macOS (single edit point) -->

Finding nearest documents needs this volume on the device. Download it to compare this document with others.

<!-- END SOURCE: semanticMap.nearest.needsVolume -->

#### A document with no place on the map
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1693 | key: semanticMap.reveal.notOnMap | shared: iOS+macOS (single edit point) -->

This document has no place on the map

<!-- END SOURCE: semanticMap.reveal.notOnMap -->

#### …and why
<!-- About 2,356 display rows — chapter openers, front matter, appendix structure — were never embedded. Ordinary, not a fault, and the wording carries that. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1697 | key: semanticMap.reveal.notOnMap.detail | shared: iOS+macOS (single edit point) -->

Chapter openers, front matter and appendix material were not included when the map was built, so %@ has no point to show. The rest of the series is here.

<!-- END SOURCE: semanticMap.reveal.notOnMap.detail -->


### 13.5 Related Documents — the semantic axis


#### Axis caption when the weight is 0
<!-- The axis ships OFF. Until build 42 the only prose describing it lived in a feedback screen in Settings ▸ Data & Recovery, so the app's most usable semantic feature was its least discoverable. -->

<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | lines: 415 | key: related.weights.semantic.off | shared: iOS+macOS (single edit point) -->

Off. Raise it to also match documents whose wording reads alike, even when they share no words, citations or archive. Experimental, and untested on nineteenth-century prose.

<!-- END SOURCE: related.weights.semantic.off -->

#### Axis caption when the weight is raised
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | lines: 417 | key: related.weights.semantic.on | shared: iOS+macOS (single edit point) -->

Matches carry a “Semantic match” score. Press and hold one — or right-click on a Mac — to say whether it helped. Those verdicts are how this axis gets judged.

<!-- END SOURCE: related.weights.semantic.on -->


### 13.6 Settings ▸ Volumes & Storage ▸ Semantic Vectors

*One view mounted by both storage hubs, so every string here is a single edit point.*


#### Section header
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 64 | key: settings.vectors.header | shared: iOS+macOS (single edit point) -->

Semantic Vectors

<!-- END SOURCE: settings.vectors.header -->

#### Section footer
<!-- Rewritten in build 42: the previous version opened 'Vectors let the app…', which asks the reader to know what a vector is before the sentence will parse. -->

<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 77 | key: settings.vectors.footer.v3 | shared: iOS+macOS (single edit point) -->

The app can find documents on the same subject even when they use none of the same words. Matches appear in the Related Documents panel, in a section of their own. Each volume needs a small extra file for this, which downloads with the volume and is removed with it. The feature is experimental, and how well it works on nineteenth-century material is not yet established.

<!-- END SOURCE: settings.vectors.footer.v3 -->

#### Download-with-volumes toggle
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 129 | key: settings.vectors.auto.label | shared: iOS+macOS (single edit point) -->

Download With Volumes

<!-- END SOURCE: settings.vectors.auto.label -->

#### …its detail
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 137 | key: settings.vectors.auto.detail.v3 | shared: iOS+macOS (single edit point) -->

Helps Related Documents find documents on the same subject even when they use none of the same words. About %@ per volume.

<!-- END SOURCE: settings.vectors.auto.detail.v3 -->

#### …its accessibility hint
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 148 | key: settings.vectors.auto.a11y.v2 | shared: iOS+macOS (single edit point) -->

When this is off, the extra file is not downloaded alongside a volume. You can still download them all from the button above, and if you open Related Documents for a volume, the app fetches that volume's file then.

<!-- END SOURCE: settings.vectors.auto.a11y.v2 -->

#### Manual download button
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 161 | key: settings.vectors.download.label | shared: iOS+macOS (single edit point) -->

Download Missing Vectors

<!-- END SOURCE: settings.vectors.download.label -->

#### …its detail
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 165 | key: settings.vectors.download.detail.v3 | shared: iOS+macOS (single edit point) -->

%lld volumes on this device are missing this file. About %@ to download, and Related Documents gets better for those volumes.

<!-- END SOURCE: settings.vectors.download.detail.v3 -->

#### Remove downloaded vectors
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 263 | key: settings.vectors.remove.detail.v2 | shared: iOS+macOS (single edit point) -->

Frees %@. Your volumes, notes and search stay exactly as they are. Related Documents keeps working, but its matches are less precise until these files download again.

<!-- END SOURCE: settings.vectors.remove.detail.v2 -->

#### Retry failed downloads
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 236 | key: settings.vectors.retry.detail.v2 | shared: iOS+macOS (single edit point) -->

Lets the app try the downloads that failed earlier. Worth using if you were offline before.

<!-- END SOURCE: settings.vectors.retry.detail.v2 -->

#### When the build carries no vectors
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 283 | key: settings.vectors.unavailable.detail.v2 | shared: iOS+macOS (single edit point) -->

This version of the app cannot match documents by subject, so that part of Related Documents is unavailable. Nothing is wrong with your library.

<!-- END SOURCE: settings.vectors.unavailable.detail.v2 -->

#### Problems — nothing noticed
<!-- This deliberately REFUSES to give a clean bill of health: the app only notices a problem when it downloads or searches a volume, so 'no problems' would claim more than it knows. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 118 | key: settings.vectors.problems.none.v2 | shared: iOS+macOS (single edit point) -->

Nothing has gone wrong since the app opened. The app only notices a problem when it downloads or searches a volume, so this does not mean every file is good.

<!-- END SOURCE: settings.vectors.problems.none.v2 -->

#### A file that did not arrive intact
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 150 | key: settings.vectors.error.integrity.v2 | shared: iOS+macOS (single edit point) -->

The file did not arrive intact, so the app discarded it. Downloading again usually fixes this.

<!-- END SOURCE: settings.vectors.error.integrity.v2 -->

---

## 14. Short strings bumped since the build-42 pass

*The strings the §13 header promised blocks for — the storage hubs' reindex controls, the
reader's person and term popovers, the Collections search-unavailable notice, the Zotero
rate-limit error — plus every other short string whose localization key was bumped by the
build-42 and build-43 sessions without gaining a block here. Grouped by surface rather than
by section, because each is one or two sentences and an editor working on one is working on
its screen, not on a theme. Every string below was read out of the source, key and line
included, like everything else in this file. A few strings carry Swift interpolations —
`\(HubCopy.volumes(failures))` and the like; keep them intact exactly as written, as the
placeholder notes elsewhere in this file already require. The §13 standing rule applies
unchanged: plainer must not become more confident.*

### Storage hub — the reindex and maintenance controls

#### No volumes on this device yet. Download them from GitHub,…
<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | lines: 352 | key: settings.hub.downloaded.empty.iOS.v2 -->

No volumes on this device yet. Download them from GitHub, or add an XML file you already have.

<!-- END SOURCE: settings.hub.downloaded.empty.iOS.v2 -->

#### No volumes on this Mac yet. Download them from GitHub, or…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 323 | key: settings.hub.downloaded.empty.v2 -->

No volumes on this Mac yet. Download them from GitHub, or add an XML file you already have.

<!-- END SOURCE: settings.hub.downloaded.empty.v2 -->

#### \(HubCopy.volumes(failures)) could not be indexed
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 575 | key: settings.hub.indexFailures.v2 -->

\(HubCopy.volumes(failures)) could not be indexed

<!-- END SOURCE: settings.hub.indexFailures.v2 -->

#### Indexes only the volumes that still need it, and leaves t…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 550 | key: settings.hub.indexRemaining.help.v2 -->

Indexes only the volumes that still need it, and leaves the rest untouched

<!-- END SOURCE: settings.hub.indexRemaining.help.v2 -->

#### Deletes what the app has built for searching and builds i…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 567 | key: settings.hub.rebuild.help.v2 -->

Deletes what the app has built for searching and builds it again from every downloaded volume. Use this if search results look wrong, or if leftovers remain from volumes you deleted.

<!-- END SOURCE: settings.hub.rebuild.help.v2 -->

#### Rebuilds what Spotlight knows about your documents. Quick…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 623 | key: settings.hub.spotlight.help.v2 -->

Rebuilds what Spotlight knows about your documents. Quicker than a full reindex, because it reuses text the app has already read.

<!-- END SOURCE: settings.hub.spotlight.help.v2 -->

### Storage hub — index health

#### The app updates the index by itself when a new version im…
<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | lines: 631 | key: settings.storage.indexHealth.footer.v2 -->

The app updates the index by itself when a new version improves how indexing works. Check Integrity runs a full check whenever you ask for one.

<!-- END SOURCE: settings.storage.indexHealth.footer.v2 -->

### Semantic vectors — fetch failures and refusals

#### There is no file available for this volume.
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 143 | key: settings.vectors.error.notPublished.v2 -->

There is no file available for this volume.

<!-- END SOURCE: settings.vectors.error.notPublished.v2 -->

#### The file downloaded correctly, but it was made for a diff…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 156 | key: settings.vectors.error.rejected.v2 -->

The file downloaded correctly, but it was made for a different version of the app, so it was not kept. A future update will publish a matching one.

<!-- END SOURCE: settings.vectors.error.rejected.v2 -->

#### The download did not finish. The app tries again when you…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 153 | key: settings.vectors.error.transport.v2 -->

The download did not finish. The app tries again when your connection changes.

<!-- END SOURCE: settings.vectors.error.transport.v2 -->

#### The file is no longer on this device.
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 179 | key: settings.vectors.refused.missing.v2 -->

The file is no longer on this device.

<!-- END SOURCE: settings.vectors.refused.missing.v2 -->

#### This file was made for a different version of the app, so…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 176 | key: settings.vectors.refused.provenance.v2 -->

This file was made for a different version of the app, so it cannot be used with this one. Remove it and download again.

<!-- END SOURCE: settings.vectors.refused.provenance.v2 -->

### The document reader's person and term popovers

#### This volume was indexed before the app recorded definitio…
<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | lines: 288 | key: glossNotFound.detail.v2 -->

This volume was indexed before the app recorded definitions. To add them, re-index the volume in Settings → Volumes & Storage.

<!-- END SOURCE: glossNotFound.detail.v2 -->

#### This volume was indexed before the app recorded details a…
<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | lines: 278 | key: personNotFound.detail.v2 -->

This volume was indexed before the app recorded details about people. To add them, re-index the volume in Settings → Volumes & Storage.

<!-- END SOURCE: personNotFound.detail.v2 -->

### Collections and Zotero

#### Search is not ready yet. Try again in a moment.
<!-- SOURCE: FRUSExplorer/Collections/CollectionContentResolver.swift | lines: 34 | key: export.smart.noSearchService.v2 -->

Search is not ready yet. Try again in a moment.

<!-- END SOURCE: export.smart.noSearchService.v2 -->

#### Zotero is receiving too many requests right now. Try agai…
<!-- SOURCE: FRUSExplorer/Zotero/ZoteroAPIModels.swift | lines: 206 | key: zotero.error.rateLimited.v2 -->

Zotero is receiving too many requests right now. Try again in a moment.

<!-- END SOURCE: zotero.error.rateLimited.v2 -->

### Word cloud

#### The meaningful terms in the chosen scope — a document, vo…
<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1101 | key: wordcloud.info.shows.detail.v2 -->

The meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, custom volume scope, or the whole corpus. “Size words by” chooses what the sizes mean.

<!-- END SOURCE: wordcloud.info.shows.detail.v2 -->

#### Reading every indexed document. On a full library this ta…
<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1006 | key: wordcloud.loading.corpus.v2 -->

Reading every indexed document. On a full library this takes several minutes — you can leave this screen and come back.

<!-- END SOURCE: wordcloud.loading.corpus.v2 -->

### Semantic map lenses

#### Too few source notes
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapLens.swift | lines: 139 | key: semanticMap.legend.noProvenance.v2 -->

Too few source notes

<!-- END SOURCE: semanticMap.legend.noProvenance.v2 -->

#### Each volume takes the category its source notes name most…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapLens.swift | lines: 99 | key: semanticMap.lens.provenance.caption.v2 -->

Each volume takes the category its source notes name most often — a plurality, not a majority, for 73 of 522 volumes. Volumes with ten notes or fewer are left uncoloured.

<!-- END SOURCE: semanticMap.lens.provenance.caption.v2 -->

### Archival analytics — the three weights

#### The three weights count different things. A document coun…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 315 | key: archival.export.caveat.weight.v2 -->

The three weights count different things. A document counts only when its own source note names the collection. A volume counts when either its front matter or any document source note names the collection. So a collection named only in front matter has volumes but no documents. Unprinted pointers counts neither: it counts footnotes naming material FRUS did not print, and is never added to the other two. Switching the weight changes which collections appear in the ranking, not just their order.

<!-- END SOURCE: archival.export.caveat.weight.v2 -->

#### Documents counts how many published documents came out of…
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 244 | key: archival.info.weights.detail.v2 -->

Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. Unprinted pointers counts something else entirely: footnotes pointing at material there that FRUS did not print. The first two measure where documents were drawn from; the third measures where readers were sent. They are never added together. Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and a hundred and eighty-one collections appear only under pointers, having supplied no printed document. A collection named only in a volume's front matter has volumes but no documents.

<!-- END SOURCE: archival.info.weights.detail.v2 -->

#### The three counts measure different things
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 243 | key: archival.info.weights.title.v2 -->

The three counts measure different things

<!-- END SOURCE: archival.info.weights.title.v2 -->

### Chronology summary line

#### \(editorialNotes) editorial note\(editorialNotes == 1 ?
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | lines: 1319 | key: chronology.agg.editorial.v2 -->

\(editorialNotes) editorial note\(editorialNotes == 1 ? 

<!-- END SOURCE: chronology.agg.editorial.v2 -->

#### \(volumes) volume\(volumes == 1 ?
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | lines: 1314 | key: chronology.agg.volumes.v2 -->

\(volumes) volume\(volumes == 1 ? 

<!-- END SOURCE: chronology.agg.volumes.v2 -->

### Menus, tooltips, and short labels

#### Chronology, Corpus Analytics, Person Analytics, Cross-Ref…
<!-- SOURCE: FRUSExplorer/Browser/BrowserView.swift | lines: 438 | key: browse.analysisTools.help.v3 -->

Chronology, Corpus Analytics, Person Analytics, Cross-Reference Analytics, Archival Analytics, Semantic Analytics, and the corpus Word Cloud

<!-- END SOURCE: browse.analysisTools.help.v3 -->

#### Corpus, Person, Cross-Reference, Archival, and Semantic a…
<!-- SOURCE: FRUSExplorer/App/MainWindowView.swift | lines: 376 | key: mainwindow.tools.analytics.menu.help.v3 -->

Corpus, Person, Cross-Reference, Archival, and Semantic analytics, Chronology, and Word Cloud

<!-- END SOURCE: mainwindow.tools.analytics.menu.help.v3 -->

#### Research window (⌘⌥R), Collections (⇧⌘K), and Complete Hi…
<!-- SOURCE: FRUSExplorer/App/MainWindowView.swift | lines: 426 | key: mainwindow.tools.myResearch.help.v2 -->

Research window (⌘⌥R), Collections (⇧⌘K), and Complete History

<!-- END SOURCE: mainwindow.tools.myResearch.help.v2 -->

#### Open Document
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | lines: 809 | key: research.action.openDocument.v2 -->

Open Document

<!-- END SOURCE: research.action.openDocument.v2 -->

#### Colours group collections by who holds the records — four…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | lines: 304 | key: series.provenance.topCollections.method.v2 -->

Colours group collections by who holds the records — four custodians, not the ten categories above, which classify the citation rather than its holder. Eras here are coarser than the decades above, so a year range ending mid-era still covers the whole era. Document counts come from an index covering all 552 catalogued volumes with no 1900 floor, so a row here can rest on volumes the charts above leave out; the collection names come from a cross-volume authority that reaches 356 of them. The Categories filter above does not apply to this ranking.

<!-- END SOURCE: series.provenance.topCollections.method.v2 -->

#### Digitized Scans
<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1822 | key: source.explorer.scans.header.v2 -->

Digitized Scans

<!-- END SOURCE: source.explorer.scans.header.v2 -->


### Archival Flows — the crossing-citations caveat

#### Some footnotes cross between the two filing systems
<!-- Added by #831's measurement. The numbers are literal because the artifact does not carry this
     axis: the measurement found it too concentrated to draw. If it is ever regenerated with a
     mixed axis, these figures must be re-measured or removed — they are not read from data. -->
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | key: archival.flows.caveats.mixed -->

Some footnotes cross between the two filing systems — a document filed in a lot file or a presidential library pointing to a central-file number, or the reverse. There are about 1,900 of these across the series, and they are not spread evenly: a third of them come from two situations, the 1945 Potsdam volumes moving between Truman's presidential file and the wartime file, and one 1952–54 conference volume moving between its lot file and its conference file. They are counted in neither diagram above.

<!-- END SOURCE: archival.flows.caveats.mixed -->
