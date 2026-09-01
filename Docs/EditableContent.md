# FRUS Explorer — Editable Static Content

This file contains the user-facing editorial prose across FRUS Explorer: the About screen, the
onboarding welcome, the in-app FRUS Research Guide, the Series and Archival analytics dashboards,
the analytics info popovers and captions, the Source Explorer panels, the methods statements
stamped on every export, the Archive Visit planner and its trip packet, the Browse-axis coverage
captions, and the explanatory footers in Settings. Edit the text directly. When you
are done, hand the file back and the changes will be written to the source code.

**Regenerated from source: 2026-08-09 (build 38). Amended 2026-08-16 for build 42; amended 2026-08-23 for the post-42 changes; amended 2026-08-29 for build 44.**

**The 2026-08-29 amendment** re-ran the mechanical sweep over all 466 blocks after build 44 was
tagged. The verification half came back clean: every block's key is live, and the only source
strings whose wording moved since the last amendment are one interpolation-variable rename with
identical visible text (`appendix.caveat.zero.many`) and one capitalization fix on a window title
this file does not carry (`packet.title`). The build-43/44 feature PRs that added long strings
mostly added their blocks as they went (§1.4a–d, §7.12, §13.5's lexical twin), which is why the
sweep found no rot — the additions below are the surfaces that DIDN'T bring their blocks:

 - **§15 Archive Visits** — the build-44 flagship (#1086–#1097) shipped ~120 new strings and none
   had a block: the plan list and Mac manager, the editor's coverage/derivation states, the
   research-targets info popover (the two-claims definition and both sparsity disclosures), the
   tier/orphan/substitution prose, and the rescoped packet sheet's empty states and topic captions.
 - **§16 Browse — the axis captions** — a standing gap, not a new one: the coverage statements on
   the Clusters, Archives, Administrations and Subjects browse axes were never carried. Each is a
   numbers-bearing method sentence, exactly this file's material.
 - New blocks inside existing sections: the Meaning-search caveats the method appendix gained at
   #1127 (§7.8), the Meaning strip's filters caveat (§7.12), the archival export's grain and
   pointed-at method sentences (§10.1 — pre-baseline gaps), the map's figure-export caveats from
   W-3/W-2a (§13.7), the Semantic Match Feedback screen (§13.8 — shipped earlier, never carried),
   the Flows ⓘ's `Ibid.` disclosure beside its mixed-systems sibling (§14), the classification
   override's rail warning and Settings corrections list from W-4/#1097 (§14), the exact-word
   charting refusal (§5), and the storage hubs' remove-volume confirmations with their side-loaded
   variants (§6).

**The 2026-08-23 amendment** verified every block's prose against the source string it names —
mechanically, block by block — and repaired the twenty that had drifted since build 42. Most of the
drift came from four passes that edited strings without touching this mirror: the #838 archival
copy pass (footers shortened, prose moved into ⓘ items), the #834 central-file channel (the Flows
scope ⓘ and the graph's help now describe three citation kinds, not two), the #1052 subject-facet
rewrite (categories are headings, not scopes), and the American-spelling copy guard
(coloured/centre/recognise → colored/center/recognize). It also **filled three §13 blocks that had
been empty since they were written** (the map's About body, the experimental-standing line, and the
layout caveat), repointed a §13 block that carried the slice's *horizontal* caption under the
*vertical* caption's key, replaced the retired graph help block with the live
`graph.info.interact.body.v2`, and added the blocks the post-42 features grew:
`archival.info.library.*` (#838's moved Your-Library rule) and `graph.context.centralFile` (#834's
class nodes).

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
   reader sees when the file has traveled without the app, so it has to stand alone. (§5 already
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

**Blocks whose key the code no longer has are now marked in place.** A sweep on 2026-08-19 checked
every one of the 443 blocks against the source and found **31** naming a key that is absent from the
file they point at — the three this note used to list, plus 28 nobody had noticed. Editing such a
block has no effect: the revision is mapped back by `key:`, and there is nothing to map it to.

Nineteen were repointed mechanically, because the key had only gained its format placeholders
(`related.why.cohort` → `related.why.cohort %@ %lld`) or a version suffix (`archival.info.weights.*`
→ `.v2`). Three more were repointed after reading the source and confirming the string had simply
been renamed with its wording intact — including the two `tip.examineResults.*` keys this note used
to defer as an editorial call; they are `tip.examine.*` now, and the prose matches.

The remaining **eleven** carry a ⚠️ RETIRED banner naming what happened to the string. Their text is
left in place rather than deleted, because deciding whether copy went away with its feature or is
worth re-attaching somewhere is an editorial call, not a mechanical one.

`FRUSExplorerTests/EditableContentKeyTests` now fails the suite when a block names a key the source
does not have, so this cannot silently accumulate again.

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

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: frusDescriptionRaw | lines: 260–268 | key: about.frus.description -->

The **Foreign Relations of the United States** (FRUS) series is the official documentary record of U.S. foreign policy, published continually by the Department of State since 1861. The series now runs to more than 550 volumes, covering 1861 through the early 1990s. Recent volumes document U.S. bilateral and regional relations around the world, and how U.S. policymakers responded to unfolding crises. They cover global issues such as human rights, terrorism, narcotics, health, and the environment. They also follow thematic topics such as national security policy, foreign economic policy, and foreign affairs organization and management. Scholars, policymakers, and citizens use FRUS to trace the origins of today's challenges and the United States's role in the world.

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

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: openSourceSection | lines: 522–523 | key: about.openSource.appLicense.body -->

Licensed under the Apache License, Version 2.0. View source and contribute on GitHub.

<!-- END SOURCE: about.openSource.appLicense.body -->

---

### 1.4 Open Source — TEI Publisher Notice

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: openSourceSection | lines: 548–549 | key: about.openSource.teiPublisher.body -->

TEI rendering approaches informed by the TEI Publisher project (teipublisher.com). Licensed under the Apache License, Version 2.0.

<!-- END SOURCE: about.openSource.teiPublisher.body -->

---

### 1.4a Open Source — llama.cpp Notice

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: openSourceSection | lines: 582–583 | key: about.openSource.llamaCpp.body -->

The natural-language search feature runs its on-device model through llama.cpp (github.com/ggml-org/llama.cpp), © 2023–2026 The ggml authors, licensed under the MIT License.

<!-- END SOURCE: about.openSource.llamaCpp.body -->

---

### 1.4b On-Device Model — EmbeddingGemma Notice

> **Compliance note:** this paragraph and the consent sheet below are licence surfaces (the Gemma
> Terms use-restriction flow-down — `Planning/semantic-vectors/Gemma-Compliance-Runbook.md` §4).
> An edit here is a compliance change, not a copy edit: the notice sentence
> ("Gemma is provided under and subject to…") is required verbatim.

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: onDeviceModelSection | lines: 613–614 | key: about.modelLicense.gemma.body -->

When you enable natural-language search, the app downloads Google's EmbeddingGemma model (229 MB) and runs it on this device to convert your search queries into vectors. The model is used unmodified. Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms, including its Prohibited Use Policy.

<!-- END SOURCE: about.modelLicense.gemma.body -->

---

### 1.4c Search Model — Consent Sheet

<!-- SOURCE: FRUSExplorer/Settings/SemanticModelSection.swift | property: SemanticModelConsentSheet | lines: 216–217 | key: settings.model.consent.body -->

This optional 229 MB download is Google's EmbeddingGemma model, provided under and subject to the Gemma Terms of Use, including its Prohibited Use Policy. By downloading it you agree to use it consistently with those terms.

<!-- END SOURCE: settings.model.consent.body -->

---

### 1.4d Search Model — Storage Section Footer

<!-- SOURCE: FRUSExplorer/Settings/SemanticModelSection.swift | property: SemanticModelSection | lines: 67–68 | key: settings.model.footer -->

Lets the app understand searches phrased as questions, using a language model that runs entirely on this device — Google's EmbeddingGemma, an optional 229 MB download. The feature is experimental. The model is provided under the Gemma Terms of Use; see About ▸ Legal for the terms.

<!-- END SOURCE: settings.model.footer -->

---

### 1.5 NARA Disclaimer

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: naraDisclaimerSection | lines: 571–577 | key: about.nara.disclaimer -->

FRUS Explorer is not affiliated with, endorsed by, or sponsored by the National Archives and Records Administration (NARA). NARA Catalog data accessed through this app is provided by the National Archives and is subject to their terms of use.

<!-- END SOURCE: about.nara.disclaimer -->

---

### 1.6 DOS Disclaimer

<!-- SOURCE: FRUSExplorer/Settings/AboutView.swift | property: dosDisclaimerSection | lines: 608–614 | key: about.dos.disclaimer -->

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

**Subtitle:** Strategies for getting the most from the volumes

<!-- section-id: intro -->

FRUS rewards researchers who read across documents, not just within them, and who squeeze valuable information about both historical and archival context from the editorial annotation added to documents. Here are strategies that experienced historians have used with printed and online volumes (later pages will address how this app builds on these tried-and-true methods).

<!-- section-id: introduction -->

**Read the Front Matter**

Every FRUS volume opens with a substantial editorial introduction that explains the volume's scope, the sources available (and unavailable), major gaps in the record, and key themes. Reading this Front Matter takes minutes but saves hours of confusion.

<!-- section-id: dates -->

**Use Date Ranges Pragmatically**

If your research topic is topical or thematic, you may find that queries across the entire FRUS corpus yield an unmanageably large number of search results. It can seem impossible to wade through page after page of hits. Date filtering lets you focus on reasonable slices of time. You can zero in on a particularly relevant time period or define more manageable chunks for a comprehensive review of results.

<!-- section-id: editorial -->

**Editorial Notes as a Finding Aid**

When an editorial note summarizes a meeting or document rather than reproducing it, that's a research signal, not a dead end. The note includes archival citations to the underlying documentation. You can use the document-level Source Explorer or the free-text NARA Lookup tool to find the relevant finding aids and track down the relevant original records at NARA.

<!-- section-id: cross-volume -->

**Cross Volume Boundaries**

The focus and scope of individual FRUS volumes embody decisions about how to slice a complex record. A decision made in a document on one page of a Latin America volume might have been shaped by simultaneous conversations documented in a Foreign Economic Policy volume. Searching, following cross-references, and building collections across subseries and time periods often reveals policy coherence (or contradiction) that single-volume reading misses.

<!-- section-id: archival-road-map -->

**Think of FRUS as a Map of the Archives**

Recent FRUS volumes can serve as a map of U.S. government agency archives in three ways. First, it publishes transcriptions of the most critical historical records that document the foreign policy decision-making process and key diplomatic meetings, making them directly available to researchers. Second, the source notes for the documents selected for publication tell researchers the archival collections they came from, pointing them toward other useful files. Third, the note on sources in volume front matter identifies the broad range of archival repositories and collections that FRUS historians consulted to identify candidate documents for selection and publication. The most sophisticated users of FRUS rely on the series not only for the records it delivers directly, but also for the documentary trail it offers to a wider and richer range of U.S. Government sources.

<!-- section-id: omissions -->

**Don't Forget What You're Not Reading**

FRUS tells the U.S. side of the history of foreign relations. The counterpart cable from a foreign ministry, the intelligence report shaping the other side's expectations and strategies, the domestic political pressures driving a foreign leader — these are absent. FRUS is indispensable for illuminating the thinking and actions of U.S. policymakers. As valuable as that often is, international history is an interactive story that requires understanding events from multiple perspectives to truly master. For many types of questions, researchers should treat FRUS as an entry point to a historical or policy question, not its answer.

<!-- END SOURCE: page research-practices -->

### 3.5 Page 5 — Finding What You Need in FRUS Explorer

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: finding-documents | lines: 852–939 -->

**Title:** Finding What You Need in FRUS Explorer

**Subtitle:** What you can start from, and what you can narrow to

<!-- section-id: starting-points -->

**Start From Whatever You Have**

Historical research can start from a question you are trying to answer or a source you are trying to understand. FRUS Explorer is designed to help, regardless of whether your starting point is a phrase you half-remember, a citation that caught your eye in someone's footnote, a name that keeps appearing, a fateful date, a subject, or one good document. Each of those leads somewhere in this app. The full text of every volume you have downloaded and indexed is searchable at once. A citation resolves to the document it names. Many people can be followed through everything that mentions them. Any span of days can be laid out in order, as they unfolded. The topic index reaches subjects spread too thinly to find easily any other way. And one document you trust can lead you to the documents most connected to it — by shared archival file, citation, date, the editors' own arrangement, shared people and topics, or, if you choose to turn it on, the resemblance of their language.

<!-- section-id: narrowing -->

**Narrow Without Losing Count**

Whatever a search returns, you can see its shape before you read a page of it: how the matches spread across years, volumes, people, document types, and archival provenance. Any of those facets becomes a filter with one tap, and the subjects facet narrows a result set to a single topic area. When a set of volumes is the thing you keep coming back to — a crisis, a region, an administration — you can name it once and reuse it everywhere the series can be sliced. When the thing you care about is covered in a particular set of documents, you can freeze them into a working corpus and run every later search inside it. The app keeps track of these scopes so you can replicate and document your research method.

<!-- section-id: honest-arithmetic -->

**Search That Shows Its Arithmetic**

The app treats your counts as evidence, and holds itself to that standard. The Query Inspector shows how the app translated what you typed into the search box into the query that actually ran under the hood. This can be especially important when your results are surprising. For example, an unexpectedly large count is usually related to how the app applies "stemming" to sweep variants of your terms into searches. Capped results are reported as floors, never as totals, and the app offers tools to visualize matches it cannot list. And wherever a figure could describe either the whole series or only your indexed volumes, the app says which one it is counting.

<!-- section-id: whole-series -->

**The Whole Series, Not Just Your Library**

Finding does not wait for downloading. Subjects, people, series-wide figures, and every volume's place in the corpus are all visible before a volume is on your device — so discovery can run ahead of your library and tell you which volumes are worth adding to it. What needs the text itself — full-text search, reading documents, analysis of the words — works over what you have indexed, and the app is plain about that boundary rather than letting a small library masquerade as the series.

<!-- section-id: manual -->

**Where the Controls Are**

To delve into the details about search screens, filters, and syntax, visit the User Manual — linked from the About screen. It will walk you through how the app delivers these capabilities.

<!-- END SOURCE: page finding-documents -->

---

### 3.6 Page 6 — Seeing the Bigger Picture in FRUS Explorer

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: corpus-analysis | lines: 940–1028 -->

**Title:** Seeing the Bigger Picture in FRUS Explorer

**Subtitle:** Questions you can put to the series as a whole

<!-- section-id: over-time -->

**Change Over Time**

You can watch the record move. Any term or phrase can be charted across the series' thirteen decades to see when it enters the record, when it surges, and which volumes carry it — as raw counts, or as a share of each period's documents so a term does not look like it is surging just because the series grew. Any stretch of days can be reconstructed in sequence. And any set of documents you assemble — a search's results, a collection — can be read as a timeline, so its gaps and concentrations show at a glance.

<!-- section-id: language -->

**The Language Itself**

You can ask what any slice of the corpus sounds like — a document, a volume, a decade, a working corpus — and get more than a list of frequent words: the words most distinctive of that slice compared with the whole series, the company a term keeps (its collocates), and every occurrence of a term lined up as a concordance, so a page of hits can be read as usage rather than skimmed as a list. An experimental semantic analytics feature places every document in the series on one map by the shape of its wording, so documents that read alike sit near each other whether or not they share a volume, a date, or a citation.

<!-- section-id: people -->

**The People**

You can ask who the published record foregrounds: the most-mentioned figures of an era, one person's presence traced year by year, two careers compared, pairs tracked together, and the network of who is named alongside whom. These readings reach the volumes whose editors tagged people during production — the more recent ones — and the app tells you so rather than letting an editorial gap read as a historical absence.

<!-- section-id: citation-web -->

**The Web the Editors Drew**

FRUS editors stitched the series together with cross-references between printed documents and out to archival records. In FRUS Explorer, you can read that stitching at both scales: one document's neighborhood as a graph — what informed it, what it fed into, including the archival material its footnotes cite but the series never printed — and the whole citation web as a statistical object, with its most-cited landmarks and the volumes that lean on each other. These are measures of how the editors linked documents, not a ranking of historical importance.

<!-- section-id: archival-signal -->

**Where the Documents Came From**

Every published document names the archival file its original was found in, and clustered across the series those source notes answer a question no volume states outright: which bodies of records each era's editors actually worked in. Archival analytics offers source rankings, co-citation networks, and flows between archival units, era by era — and the same signal works at reading distance: from any document you can gather the other indexed documents drawn from the same file or collection, so pieces of one archival file scattered across volumes come back together.

<!-- section-id: finding-aid -->

**Honest Evidence**

FRUS is a selective, evolving proxy for the archival record. The app keeps that honest for you — denominators are named where available, experimental signals are marked as experimental, and where a measure cannot stand behind a number it says the measure is unavailable rather than showing one. To learn more about the app's analytics features, see the User Manual — linked from the About screen — for the full tour.

<!-- END SOURCE: page corpus-analysis -->

---

### 3.7 Page 7 — Working With Documents in FRUS Explorer

<!-- SOURCE: FRUSExplorer/Onboarding/IndexingEducationView.swift | page-id: working-with-documents | lines: 1029–1115 -->

**Title:** Working With Documents in FRUS Explorer

**Subtitle:** Reading, annotating, organizing, and exporting

<!-- section-id: reading -->

**The Text, As Published**

The document you read is the document the volume printed: its structure, its datelines, its style, its footnotes in place, with the people it names linked to the volume's own glossary. Reading stays clean until you ask for more — your notes, tags, and summaries sit in a rail you open when you want them and close when you don't.

<!-- section-id: your-apparatus -->

**Your Own Layer on the Record**

Everything you add — highlights, notes, tags, the projects that keep separate research threads distinct — is your layer, kept apart from the published text and never blended into it. It follows you across your devices, and it stays private: the app shares nothing about your research with anyone, and everything you make can be exported so you can use it elsewhere.

<!-- section-id: outputs -->

**From Reading List to Finished Output**

A set of documents can become a shaped thing: a teaching reader, a briefing packet, a source dossier — ordered, sectioned, curated in your own words, annotated, and exported in forms other people can actually use, from print-ready files to a working set that a colleague opens in their own FRUS Explorer. Every document carries a citation in the series' own style, ready for your footnotes or your reference manager. And where on-device AI is available it can draft summaries for you that are always labeled as generated, never passed off as the record or as you.

<!-- section-id: integrity -->

**Claims That Survive Checking**

The app is built so that what you publish from it can be checked. Every quotation you freeze into a collection is re-verified against the text of the document it cites before export — presentation is forgiven, wording is not, and a paraphrase does not pass. Your searches can be exported as a method appendix: the query log records each query with its scope, its date, and how many volumes were indexed at the time, which is what turns "I searched and found nothing" from an assertion into evidence a reader can check.

<!-- section-id: beyond -->

**When the Trail Leaves the Series**

When you are ready to follow source notes or footnotes past the published series to the shelves at College Park or a presidential library, FRUS Explorer can help you plan research visits. Documents you select seed a visit and research plan. The app's research trip packet resolves each document's source note and outward-pointing footnotes against National Archives data to flag access-restriction warnings for still-classified collections, draft advance inquiries to an archivist, and identify each record the way NARA asks you to request it.

<!-- section-id: manual -->

**Where the Controls Are**

To learn more about what FRUS Explorer lets you do with documents, see the User Manual — linked from the About screen.

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

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | intro (SourceProvenanceDashboard) | lines: 234–235 | key: series.provenance.intro -->

Where did the editors of Foreign Relations of the United States find the documents they published? Since the early 20th century, every document carries a source note naming the archival file it came from. These charts read those notes across the whole series to trace how its archival base changed. The State Department's central files dominated almost completely until bureau lot files and presidential libraries appeared after the war. Modern volumes draw on a much wider range of sources.

<!-- END SOURCE: series.provenance.intro -->

#### Chart 1 subtitle — Archival provenance over time

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | mixOverTimeChart caption | lines: 381–382 | key: series.provenance.trend.caption -->

Each decade's source notes divided among the archival collections they cite, so every decade totals 100%. A volume's decade is set by the midpoint of its coverage. The trend begins in 1900 because earlier volumes carry no archival source notes.

<!-- END SOURCE: series.provenance.trend.caption -->

#### Chart 2 subtitle — Overall provenance composition

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | compositionChart caption | lines: 443–444 | key: series.provenance.composition.caption -->

How many source notes across the whole series, from 1900 on, cite each kind of archival collection. The Central Decimal File dwarfs the rest. Most published FRUS documents came from the State Department's own central filing.

<!-- END SOURCE: series.provenance.composition.caption -->

#### Chart 3 subtitle — The documentary base by decade

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | densityChart caption | lines: 498–499 | key: series.provenance.density.caption -->

How many source notes each decade contributes. These are the counts behind the shares above. The 1940s carry the deepest base. Volumes covering the 1970s, 1980s, and 1990s are still in production, so those decades will look different as new volumes are released.

<!-- END SOURCE: series.provenance.density.caption -->

#### Category-filter caveat — shown while categories are hidden

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats filtered line | lines: 613–614 | key: series.provenance.caveats.filtered.v2 -->

Some categories are hidden. Each share below is a share of the categories still shown, not of all source notes. A decade with no notes in any shown category reads as zero rather than being skipped. Use the Categories menu above to show them all.

<!-- END SOURCE: series.provenance.caveats.filtered.v2 -->

#### "About these figures" methodology footnote

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats body | lines: 619–620 | key: series.provenance.caveats.body -->

These figures come from parsing each document's source note, the citation naming where its archival original was found. They are not drawn from a catalog of the archives. "Other / Unclassified" means a citation the parser could not classify, not a missing source note. Coverage spans 522 of the 552 cataloged volumes. Pre-1900 volumes are largely published diplomatic correspondence with no archival source notes, so the trend begins around 1900. Those early retrospective compilations are left out of the charts. The categories follow State Department filing practice. The Central Decimal File is the pre-1963 central filing system, and the Central Foreign Policy File is its post-1963 successor. Lot files were kept by individual bureaus, offices, and posts. Presidential libraries hold the White House records that dominate modern volumes. Remember that these counts show where FRUS editors drew their documents. That is an editorial and archival signal, not a full census of the underlying archives.

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
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.caveats | lines: 554–556 | key: series.admin.caveats.scope %@ | shared: iOS+macOS (single edit point) -->

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

Place tags are editorial tags on the volume, not on the document. A volume touches a region if it carries a place tag that maps to that region. These are volume counts, not document counts, and a volume commonly spans several regions. The stacked chart splits each volume across its regions. A volume covering three regions contributes a third to each, so every decade totals 100%. The overall bars work differently: they count a multi-region volume once in every region it touches. Regions roughly follow the State Department's six current regional bureaus, with dependencies and territories folded into "Other." 551 of the 552 cataloged volumes carry at least one place tag. These figures cover the volumes the app currently catalogs, so the newest volumes may not appear yet.

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

How many volumes reached print in each year, colored by era. Output has never been steady — it reflects staffing, declassification throughput, and the shift to digital publication.

<!-- END SOURCE: series.chart.peryear.caption -->

#### Chart 3 caption — Cumulative volumes published

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var cumulativeChart (caption) | lines: 315–316 | key: series.chart.cumulative.caption | shared: iOS+macOS (single edit point) -->

The digitized corpus has grown to the 552 volumes this app catalogs — steeply in some decades, slowly in others.

<!-- END SOURCE: series.chart.cumulative.caption -->

#### Subseries-scope caveat — shown while a subseries scope is active (shared with Geographic Emphasis)

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var caveats (scope line) | lines: 378–380 | key: series.caveats.scope %@ | shared: iOS+macOS (single edit point) -->

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
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1469–1470 | key: graph.info.what.body -->

Each node is a FRUS document. Blue nodes cite the central document. Orange nodes are cited by it. Gray nodes are 2nd- or 3rd-degree neighbors. Larger nodes have more connections across the corpus. Each arrow points at the document being cited.

<!-- END SOURCE: graph.info.what.body -->

#### Edge context
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1475–1476 | key: graph.info.edges.body -->

Many lines carry the original footnote or editorial-note text where the reference appeared. Hover over or tap the middle of a line to read it. A thicker line means the two documents are linked by several separate references.

<!-- END SOURCE: graph.info.edges.body -->

#### Timeline and Network layouts
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1481–1482 | key: graph.info.timeline.body -->

Timeline places each document at its date along a time axis. Documents this one cites usually sit to the left, since they are earlier. Documents citing it sit to the right, since they are later. Documents with no recorded date go in the Undated column. Network uses a spring layout, which arranges nodes by their connections alone.

<!-- END SOURCE: graph.info.timeline.body -->

#### Neighborhood degree
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1487–1488 | key: graph.info.degree.body -->

1° shows only direct neighbors of the central document. 2° adds neighbors of those neighbors. 3° extends one further hop. Resize the window to see denser graphs more clearly.

<!-- END SOURCE: graph.info.degree.body -->

#### Navigating the graph
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1504–1505 | key: graph.info.interact.body.v2 -->
<!-- Repointed from graph.info.interact.body after the 2026-08-23 docs pass bumped the key to
     .v2 (the teal-node and three-citation-kinds paragraphs) but left this in-place block on the
     dead key. The §14 copy carries the change rationale; this is the section's editing surface,
     the same in-place + §14 pairing the archival.info.weights.* keys use. -->

Click a node to see its details. Right-click (or long-press) to recenter the graph on that document or open it in the main window. Use pinch-to-zoom and drag to pan.

Teal nodes are archival material the editors pointed to in a footnote but did not print. There is no document behind one, so the walk ends there.

This graph draws three kinds of archival citation: State Department lot files, collections in the presidential libraries, and the central files cited by decimal number, such as 681.8229/8–2950 — the usual practice in the earlier volumes, and still most archival footnotes in the volumes covering the 1950s. Opening a lot-file or library node shows the collection's record. A central-file node is labeled by the number alone, with no subject beside it: the filing schedule was renumbered in 1950, and a guessed subject could not be told from a right one. A citation that was read but could not be matched is left off rather than drawn as a guess.

<!-- END SOURCE: graph.info.interact.body.v2 -->

#### Undownloaded volumes
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1499–1500 | key: graph.info.undownloaded.body -->

A reference can point to a document in a volume you have not downloaded. The graph still shows it, because the connection was recorded when the citing volume was indexed. Those nodes have a dashed border and a struck-through cloud icon. Select one to download its volume from the info panel.

References from volumes you have not indexed are not shown at all. Those volumes have never been parsed, so the app has never seen their references. An orange banner appears at the top of the graph when your inbound connections may be incomplete for this reason. Download and index more volumes to fill in the missing links.

<!-- END SOURCE: graph.info.undownloaded.body -->

---

### Word Cloud — Info Popover ("About the Word Cloud")
<!-- Toolbar info popover; iOS+macOS use the same WordCloudView.swift toolbar (one file, shared across platforms). -->

#### Word Cloud info — What you're seeing

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1101–1102 | key: wordcloud.info.shows.detail.v2 -->

The meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, custom volume scope, or the whole corpus. “Size words by” chooses what the sizes mean.

<!-- END SOURCE: wordcloud.info.shows.detail.v2 -->

#### Word Cloud info — Lenses

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1114–1115 | key: wordcloud.info.lenses.detail -->

The lens chips narrow the cloud to a kind of term — People, Places, Organizations, Topics, Actions, Descriptors, Concepts, or Sentiment — using on-device language analysis.

<!-- END SOURCE: wordcloud.info.lenses.detail -->

#### Word Cloud info — What's filtered out

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1118–1119 | key: wordcloud.info.filters.detail -->

Common stopwords are always removed. A word's own menu can hide it from this cloud only, which lasts until you next open it. The same menu can add it to a hidden-word list, either global or for one lens. You manage those lists in Settings → Word Cloud. You can also hide diplomatic boilerplate. Use “Show hidden words” in the Options menu to bring hidden words back.

<!-- END SOURCE: wordcloud.info.filters.detail -->

#### Word Cloud info — Tapping a word

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1122–1123 | key: wordcloud.info.tap.detail -->

Charts how often that term appears across the whole corpus in Corpus Analytics; the word's menu also offers a scoped chart and a direct Search.

<!-- END SOURCE: wordcloud.info.tap.detail -->

### Word Cloud Settings — section footers

<!-- Shared surface note: WordCloudSettingsView is a single shared SwiftUI view used on both iOS and macOS (differs only by a #if os(macOS) .formStyle); each footer key below is a single edit point across both platforms. -->

#### Filtering footer — classification markings

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | filteringSection footer | lines: 163–164 | key: settings.wordcloud.markings.footer | shared: iOS+macOS (single edit point) -->

Classification markings include terms like "Top Secret" and "Confidential", precedence words like "Priority" and "Immediate", and month names. These words describe the form of a document, not its content. Left in, they crowd the cloud, especially the named-entity lenses.

<!-- END SOURCE: settings.wordcloud.markings.footer -->

#### Thresholds footer

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | thresholdsSection footer | lines: 193–194 | key: settings.wordcloud.thresholds.footer | shared: iOS+macOS (single edit point) -->

Drops terms shorter than the minimum length, and terms appearing fewer than the minimum number of times. Raising either gives a sparser cloud of stronger terms. Occurrences are counted across the whole scope before the top terms are picked. So raising the minimum count may not change the sample above. It thins the long tail you never see.

<!-- END SOURCE: settings.wordcloud.thresholds.footer -->

#### Appearance footer

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | appearanceSection footer | lines: 219–220 | key: settings.wordcloud.appearance.footer | shared: iOS+macOS (single edit point) -->

Choose the typeface the cloud is drawn in and how tightly its words pack together. Compact fits more terms; airy spaces them out for legibility. These settings apply on this device only.

<!-- END SOURCE: settings.wordcloud.appearance.footer -->

#### Hidden-words footer — "Every cloud" scope

<!-- S-5b merged the two hidden-words sections into one editor with an "Applies to" scope picker; these two footers are now the two branches of `StopListScope.footer`, not two separate sections. -->

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | StopListScope.footer (.allLenses) | lines: 350–351 | key: settings.wordcloud.global.footer | shared: iOS+macOS (single edit point) -->

Words listed here are removed from every word cloud, on top of the built-in stop lists.

<!-- END SOURCE: settings.wordcloud.global.footer -->

#### Hidden-words footer — single-lens scope

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | StopListScope.footer (.lens) | lines: 353–354 | key: settings.wordcloud.lens.footer | shared: iOS+macOS (single edit point) -->

Words hidden only when the selected lens is active — useful for trimming a recurring false positive (for example, a place the recognizer keeps mistaking) without affecting other lenses.

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

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | sampleSection | lines: 123–124 | key: settings.wordcloud.sample.none | shared: iOS+macOS (single edit point) -->

These settings keep nothing from the sample. Lower a threshold or turn a filter off.

<!-- END SOURCE: settings.wordcloud.sample.none -->

---

### Chronology
<!-- Toolbar info popover; iOS+macOS use the same ChronologyView.swift toolbar (one file, shared across platforms). -->

#### What you're seeing
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1109–1110 | key: chronology.info.shows.detail -->

Every indexed document whose date falls within the range you pick, grouped into date sections that coarsen (days → months → years) as the range widens.

<!-- END SOURCE: chronology.info.shows.detail -->

#### How dates work
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1113–1114 | key: chronology.info.dates.detail -->

Each document sits at its TEI date, and is shown no more precisely than its source supports — with the precision (day/month/year) and certainty (exact vs. approximate) preserved.

<!-- END SOURCE: chronology.info.dates.detail -->

#### The distribution chart
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1117–1118 | key: chronology.info.chart.detail -->

The stacked chart color-codes documents by source volume (the top volumes, then a gray “Other”). Use the chart-colors menu to choose how many volumes get a distinct color.

<!-- END SOURCE: chronology.info.chart.detail -->

#### Wide ranges
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1121–1122 | key: chronology.info.cap.detail -->

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
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.normalizationCaption | lines: 1864–1865 | key: analytics.normalize.caption | shared: iOS+macOS (single edit point) -->

Share of indexed documents per period. Only downloaded, indexed volumes are counted, so this is a share of your local corpus, not the entire FRUS series.

<!-- END SOURCE: analytics.normalize.caption -->

### Corpus Analytics — Exact-word terms

*The refusal state shown when every entered term is an `=exact` term. It sits ahead of the
No-Results branch on purpose: this state HAS matches, and a bare "No Results" would read as "this
word never appears" — the opposite of the truth. The distinction it teaches (Analytics counts by
stem, Search filters to the exact word) must survive editing.*

#### Title
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | lines: 1591–1592 | key: analytics.exactUnsupported.title | shared: iOS+macOS (single edit point) -->

Exact-Word Charting Isn’t Available

<!-- END SOURCE: analytics.exactUnsupported.title -->

#### Detail
<!-- Placeholder note: the leading interpolation renders the refused terms as a list ("=containment
     and =détente"). Keep `\(unsupportedExactTerms.map { "=\($0)" }.formatted(.list(type: .and)))`
     intact exactly as written. -->
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | lines: 1595–1596 | key: analytics.exactUnsupported.detail | shared: iOS+macOS (single edit point) -->

\(unsupportedExactTerms.map { "=\($0)" }.formatted(.list(type: .and))) can’t be charted: Analytics counts by word stem, so it cannot tell "containment" from "container". Remove the = to chart the stem, or use Search, which does filter to the exact word.

<!-- END SOURCE: analytics.exactUnsupported.detail -->

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
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 270–271 | key: crossRefAnalytics.info.shows.detail | shared: iOS+macOS (single edit point) -->

How FRUS documents cite one another. The ranking lists the most-referenced documents. The heat matrix shows citation flow between whole volumes. Landmarks are the documents a reader following citations keeps returning to. FRUS cross-referencing practice has changed over the life of the series. A subseries or a single administration therefore gives a more consistent signal than a broader scope that mixes several editorial practices.

<!-- END SOURCE: crossRefAnalytics.info.shows.detail -->

#### Reading the heat matrix
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 274–275 | key: crossRefAnalytics.info.matrix.detail | shared: iOS+macOS (single edit point) -->

Rows cite columns. A darker cell means the row's volume cites the column's volume more often. Column labels are a short code of the volume's years and number, such as '55–57 II. Hover over a label, or use VoiceOver, for the full title on either axis.

<!-- END SOURCE: crossRefAnalytics.info.matrix.detail -->

#### About the influence score
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 278–279 | key: crossRefAnalytics.info.influence.detail | shared: iOS+macOS (single edit point) -->

Landmark documents are ranked by PageRank, computed on this device over the citations the app resolved. It measures how often a document is cited by other much-cited documents. It is not a claim of historical importance.

<!-- END SOURCE: crossRefAnalytics.info.influence.detail -->

### Cross-Reference Analytics — Captions

#### Scope-of-figures caveat
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 770–771 | key: crossRefAnalytics.resolvedCaption | shared: iOS+macOS (single edit point) -->

The most-referenced, degree, and PageRank charts count same-volume references, including resolved page references, toward the document's own volume. Set a year range or scope and they count citations made by documents in that era or scope. The heat matrix counts only connections between different volumes, so it leaves same-volume citations out.

<!-- END SOURCE: crossRefAnalytics.resolvedCaption -->

#### Excluded unresolvable references (shown only when the count is non-zero)

<!-- Placeholder note: the leading count is a Swift string interpolation, not a %lld token — keep `\(excludedBrokenCount)` intact exactly as written. -->

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 775–776 | key: crossRefAnalytics.excludedBrokenCaption | shared: iOS+macOS (single edit point) -->

\(excludedBrokenCount) unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus.

<!-- END SOURCE: crossRefAnalytics.excludedBrokenCaption -->

#### Landmark Documents (Influence) — PageRank hedge subtitle
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.landmarkSection | lines: 1187–1188 | key: crossRefAnalytics.landmarks.subtitle | shared: iOS+macOS (single edit point) -->

Ranked by a PageRank score computed on this device over the citations the app resolved. These are the documents a reader following citations keeps returning to. The score measures position in the citation network, not historical importance. Tap to open.

<!-- END SOURCE: crossRefAnalytics.landmarks.subtitle -->

---

#### Heat matrix — subtitle

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | lines: 980–981 | key: crossRefAnalytics.matrix.subtitle -->

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

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.corpusCaveat | lines: 145–147 | key: analytics.export.caveat.corpus %lld | shared: iOS+macOS (single edit point) -->

Corpus: counts cover only the %lld volume(s) indexed on this device, not the entire FRUS series.

<!-- END SOURCE: analytics.export.caveat.corpus -->

#### Value-mode caveat

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.valueModeCaveat | lines: 153–155 | key: analytics.export.caveat.values %@ | shared: iOS+macOS (single edit point) -->

Values: %@. A share is that period's matching documents divided by all indexed documents in the same period, so a growing corpus does not read as a rising term.

<!-- END SOURCE: analytics.export.caveat.values -->

#### Year range — when the chart ignores it

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.yearRangeDescription | lines: 125–126 | key: analytics.export.range.notApplied | shared: iOS+macOS (single edit point) -->

Not applied — this breakdown covers the whole corpus span

<!-- END SOURCE: analytics.export.range.notApplied -->

#### Figure caption — pointer to the CSV

Printed on every exported figure. It used to read "Full method, caveats, and the underlying numbers
**accompany this figure** in its CSV export" — which a PNG published on its own made false: it did
not merely omit the caveats, it asserted they had travelled with the image. It now says where the
numbers can be got, which is true however the figure is published.

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.plateDataPointer | lines: 140–141 | key: analytics.export.figure.seeData | shared: iOS+macOS (single edit point) -->

The underlying numbers are available as a CSV export from FRUS Explorer, with the full method statement.

<!-- END SOURCE: analytics.export.figure.seeData -->

#### Figure plate — publisher credit

The credit an exported figure carries **on the image**. Before this existed a plate printed
`FRUS Explorer <version>` and nothing else, so a figure published in an article credited a reading
application for the U.S. government's documentary edition. This is the one-line form; the full
sentence in the CSV preamble is `analytics.export.attribution`, and the two should agree.

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.plateAttribution | lines: 129–130 | key: analytics.export.plateAttribution | shared: iOS+macOS (single edit point) -->

Foreign Relations of the United States, published by the Office of the Historian, U.S. Department of State. Public domain.

<!-- END SOURCE: analytics.export.plateAttribution -->

### Analytics Export — Person Analytics caveats

#### Dated-documents population

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.personProvenance | lines: 514–515 | key: personAnalytics.export.caveat.dated | shared: iOS+macOS (single edit point) -->

Population: person mentions are counted in dated documents only. The Corpus Analytics charts fall back to the volume's start year for undated documents; these charts do not. Counts from the two views are therefore not directly comparable.

<!-- END SOURCE: personAnalytics.export.caveat.dated -->

#### Identity grouping

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.personProvenance | lines: 516–517 | key: personAnalytics.export.caveat.identity | shared: iOS+macOS (single edit point) -->

Identity: mentions are grouped by the app's person authority, so spelling variants and name forms for one individual merge into a single identity. The person id column is that grouped identity.

<!-- END SOURCE: personAnalytics.export.caveat.identity -->

#### Decade shares (By Decade in % mode only)

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.decadeShareCaveat | lines: 533–534 | key: personAnalytics.export.caveat.decadeShare | shared: iOS+macOS (single edit point) -->

Decade shares: the share plotted for a decade is the average of the yearly shares for the years this person was mentioned. Years with no mentions are dropped from that average rather than counted as zero. The "Dated documents in period" column, by contrast, sums every year of the decade. So dividing this file's columns gives the decade's own share, which can be far lower than the plotted value. Someone mentioned in one year of a decade plots that single year's share for the whole decade. Use the columns for the decade's share and the plotted value for the average across the mentioned years. They answer different questions.

<!-- END SOURCE: personAnalytics.export.caveat.decadeShare -->

### Analytics Export — Cross-Reference Analytics caveats

#### Unresolvable references

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 513–514 | key: crossRefAnalytics.export.caveat.excluded %lld | shared: iOS+macOS (single edit point) -->

Unresolvable references: %lld cross-reference(s) are excluded from this analysis — references in the printed volumes that point to a document, page, or volume not present in this corpus.

<!-- END SOURCE: crossRefAnalytics.export.caveat.excluded -->

#### Same-volume attribution

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 517 | key: crossRefAnalytics.export.caveat.sameVolume | shared: iOS+macOS (single edit point) -->

Attribution: the document-level figures count same-volume references, including resolved page references, toward the document's own volume. The volume heat matrix counts only citations between different volumes, so it leaves same-volume references out.

<!-- END SOURCE: crossRefAnalytics.export.caveat.sameVolume -->

#### Heat matrix — which volumes it covers

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixCaveats | lines: 687–689 | key: crossRefAnalytics.export.caveat.matrixLimit %lld | shared: iOS+macOS (single edit point) -->

Selection: the matrix covers the %lld volumes with the most references in and out. The CSV lists only pairs with at least one reference between them. The figure draws the whole grid and leaves the rest of the cells blank.

<!-- END SOURCE: crossRefAnalytics.export.caveat.matrixLimit -->

#### Heat matrix — axes and labels

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixCaveats | lines: 690–691 | key: crossRefAnalytics.export.caveat.matrixAxes | shared: iOS+macOS (single edit point) -->

Axes: rows cite columns. In the figure the column headings are abbreviated volume codes and the row labels are shortened descriptive labels; both volumes' full titles appear in this CSV.

<!-- END SOURCE: crossRefAnalytics.export.caveat.matrixAxes -->

#### Landmark Documents — what the score is

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.exportLandmarkCSV | lines: 743–744 | key: crossRefAnalytics.export.caveat.pageRank | shared: iOS+macOS (single edit point) -->

Score: an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is not a claim of historical importance.

<!-- END SOURCE: crossRefAnalytics.export.caveat.pageRank -->

### Analytics Export — Word Cloud caveats

<!-- A cloud never reads a document date, so its export deliberately carries no dating rule and no year-range line. The exported plate's figure title, axis line, and caption facts (wordcloud.export.figureTitle / .axis / .caption.*) are functional identifiers and are intentionally excluded here. -->

#### Population

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 667–669 | key: wordcloud.export.caveat.population %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Population: these counts cover the %lld document(s) in this scope. The share column divides by %lld, which is every word counted under the "%@" lens after the filters below. That is not the scope's total word count. Shares from two different lenses cannot be compared.

<!-- END SOURCE: wordcloud.export.caveat.population -->

#### Stopwords

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 670–677 | key: wordcloud.export.caveat.stopwords %@ %@ | shared: iOS+macOS (single edit point) -->

Stopwords: common English words are always removed. FRUS boilerplate (telegram, department, embassy…) is %@; classification markings, months, and weekdays (secret, confidential, january…) are %@.

<!-- END SOURCE: wordcloud.export.caveat.stopwords -->

#### Stopwords caveat — the two fill-in phrases

*Each `%@` slot above (first the boilerplate filter, then the markings filter) is filled with one of these two fragments, depending on whether that filter is on.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 352–352 | keys: wordcloud.export.caveat.stopwords.excluded, wordcloud.export.caveat.stopwords.kept | shared: iOS+macOS (single edit point) -->

**Filter on:** also removed

**Filter off:** kept

<!-- END SOURCE: wordcloud.export.caveat.stopwords.excluded/.kept -->

#### Tuning thresholds

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 678–683 | key: wordcloud.export.caveat.tuning %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Tuning: words shorter than %lld character(s) and words occurring fewer than %lld time(s) are excluded; plural folding is %@.

<!-- END SOURCE: wordcloud.export.caveat.tuning -->

<!-- The tuning %@ slot is filled with the generic common.on / common.off strings ("on" / "off"), which are shared app-wide and not editable here. -->

#### Words hidden by hand

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 693–695 | key: wordcloud.export.caveat.hidden %lld | shared: iOS+macOS (single edit point) -->

Hidden words: %lld word(s) were hidden by hand in this cloud and are absent from this export. They were counted before being hidden, so they remain in the denominator above.

<!-- END SOURCE: wordcloud.export.caveat.hidden -->

#### Personal stop lists

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 698–700 | key: wordcloud.export.caveat.stopLists %lld %lld %@ | shared: iOS+macOS (single edit point) -->

Your stop lists: %lld word(s) from your global hidden-word list and %lld from your list for the "%@" lens were removed before counting. They are in neither this table nor its denominator. You can edit both lists in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.export.caveat.stopLists -->

#### Active lens

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 725–727 | key: wordcloud.export.caveat.lens %@ | shared: iOS+macOS (single edit point) -->

Lens: the cloud is filtered to the "%@" word list, so this is a subset of the scope's vocabulary, not its whole frequency ranking.

<!-- END SOURCE: wordcloud.export.caveat.lens -->

---

## 6. Settings, Tips & Collections

*Explanatory footers in Settings — the ones that tell a reader what a control costs or protects, across the four groups (Library · Research · Reading & Search · System). Functional and error strings are intentionally excluded. Also the discovery tips and the Collections native-export explanation. Strings shared across platforms via one localization key are marked; where the two platforms genuinely say different things (the Volumes & Storage hub is still two views, and search logging differs by platform) each is a separate edit point and says so.*

---

### iCloud Sync, Settings Sync & Privacy

#### Settings-sync toggle detail
<!-- S-5b made the "single edit point" claim on the three keys below actually true: the macOS Sync pane used to hardcode its own near-identical copy (and had drifted — "shares those settings" vs "shares the settings above"). Both platforms now render `SyncSettingsSection`. -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.rows | lines: 1466–1467 | key: settings.sync.toggle.detail | shared: iOS+macOS (single edit point) -->

Word-cloud filters & stop lists, citation style, default document mode, and research logging.

<!-- END SOURCE: settings.sync.toggle.detail -->

#### Settings-sync unavailable notice
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.rows | lines: 1478–1479 | key: settings.sync.unavailable | shared: iOS+macOS (single edit point) -->

Settings sync needs iCloud. Sign in to iCloud and enable it for FRUS Explorer to turn this on.

<!-- END SOURCE: settings.sync.unavailable -->

#### iCloud Sync section footer
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SyncSettingsSection.footerText | lines: 1488–1489 | key: settings.sync.footer | shared: iOS+macOS (single edit point) -->

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
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 232–233 | key: settings.icloud.localOnly.detail | shared: iOS only (the macOS status lives in the main window's status bar) -->

iCloud sync is unavailable. Notes, tags, and collections won't sync across devices. Check that you are signed in to iCloud in Settings and that FRUS Explorer has iCloud access.

<!-- END SOURCE: settings.icloud.localOnly.detail -->

#### iCloud zone-missing detail
<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | SettingsView.iCloudSyncStatusRow | lines: 308–309 | key: settings.icloud.zoneMissing.detail | shared: iOS only (the macOS status lives in the main window's status bar) -->

The iCloud sync zone is missing. Data cannot upload or download until it is recreated. Force-quit and relaunch the app, or use Settings → Data & Recovery → Fix iCloud Sync.

<!-- END SOURCE: settings.icloud.zoneMissing.detail -->

---

#### Deleting one session — confirmation

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Settings/ResearchSessionsView.swift | lines: 150–152 | key: settings.sessions.delete.message.trail.v2 %@ -->

%@ will be permanently deleted from this device. If iCloud sync is on, the same records go from iCloud too. A session is made of every document you opened, every search you ran, and every collection you exported. Your notes, highlights, tags, and collections are not affected.

<!-- END SOURCE: settings.sessions.delete.message.trail.v2 %@ -->

---

### Volumes & Storage (Library)

<!-- The merged Library destination. Replaces the retired Volume Updates and Storage & Backup subsections, whose keys (`settings.volumes.updates.footer`, `settings.storage.aggregate.footer`, `settings.storage.backup.note`) went with the panes S-2b/S-2c deleted. The hub is still TWO views — VolumesStorageHubView.swift for iOS, MacVolumesStorageHub.swift for macOS — so each footer below is a separate edit point unless noted. -->

#### Keeping Current footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | keepingCurrentSection footer | lines: 533–534 | key: settings.hub.keepingCurrent.footer | shared: iOS (macOS carries the same text separately in MacVolumesStorageHub.swift) -->

Updating re-downloads and re-indexes a volume. Your notes, highlights, tags, and summaries are preserved.

<!-- END SOURCE: settings.hub.keepingCurrent.footer -->

#### Storage & Index footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | storageAndIndexSection footer | lines: 604–605 | key: settings.hub.storageIndex.footer | shared: iOS (macOS carries the same text separately) -->

Notes, highlights, and tags are never affected. For reference: the full FRUS corpus is roughly 3.4 GB of XML plus 9–10 GB of search index.

<!-- END SOURCE: settings.hub.storageIndex.footer -->

#### Rebuild From Scratch — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | rebuild confirmation | lines: 201–202 | key: settings.hub.rebuild.message.v2 | shared: iOS (macOS carries the same text separately) -->

This deletes everything the app has built for searching — document text, cross-references, page numbers, dates and the people named in each document — and builds it again by re-reading all (volumes) you have downloaded.\n\nYour research notes, highlights, summaries, collections, and tags are stored separately. They are not affected.

<!-- END SOURCE: settings.hub.rebuild.message.v2 -->

#### Free Up Space — removal confirmation

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | MacManageStorageSheet / FreeUpSpaceSheet confirmation | lines: 1791–1792 | key: settings.hub.freeUp.confirm.message | shared: iOS+macOS (single edit point — the Mac adopted these keys when its missing confirmation was added) -->

The XML files and their search-index rows are deleted from this device. Every one of these volumes can be downloaded again.

<!-- END SOURCE: settings.hub.freeUp.confirm.message -->

#### Free Up Space — size-estimate note

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | FreeUpSpaceSheet | lines: 1740–1741 | key: settings.hub.freeUp.estimateNote | shared: iOS (macOS carries the same text separately) -->

Each size is the XML file plus an estimated 2.8× for its share of the search index. That ratio comes from the full corpus: about 9–10 GB of index for about 3.4 GB of XML. Per volume the overhead runs from roughly 2.5× to 3×, so treat these sizes as approximate.

<!-- END SOURCE: settings.hub.freeUp.estimateNote -->

#### Needs Attention footer

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | needsAttentionSection footer | lines: 441–442 | key: settings.hub.interrupted.footer.v2 | shared: iOS (macOS carries the same text separately) -->

These volumes were still being indexed when the app last closed. This section appears only when something needs your attention.

<!-- END SOURCE: settings.hub.interrupted.footer.v2 -->

#### Download options footer (iOS only)

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | optionsSection footer | lines: 714–715 | key: settings.hub.options.footer | shared: iOS only — absorbed the retired iCloud-Backup exclusion note -->

Volume files are large; Wi-Fi is recommended. Downloaded XML is excluded from iCloud Backup — it can be re-downloaded at any time.

<!-- END SOURCE: settings.hub.options.footer -->

#### Remove-volume confirmation

*Four variants of one message: each platform names itself ("this device" / "this Mac"), and each
has a side-loaded form whose bold warning is the load-bearing sentence — a side-loaded volume has
no download to fall back on, so removal can be final. Keep the `**…**` emphasis intact.*

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | remove confirmation | lines: 1371–1372 | key: settings.hub.remove.message.iOS -->

The XML file and its search-index rows are deleted from this device. Your notes, highlights, tags, and summaries for it are kept, and the volume can be downloaded again.

<!-- END SOURCE: settings.hub.remove.message.iOS -->

<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | remove confirmation, side-loaded | lines: 1368–1369 | key: settings.hub.remove.message.iOS.sideloaded -->

The XML file and its search-index rows are deleted from this device. Your notes, highlights, tags, and summaries for it are kept. **This volume was side-loaded, so the app cannot download it again** — if you no longer have the file, this cannot be undone.

<!-- END SOURCE: settings.hub.remove.message.iOS.sideloaded -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | remove confirmation | lines: 1346–1347 | key: settings.hub.remove.message -->

The XML file and its search-index rows are deleted from this Mac. Your notes, highlights, tags, and summaries for it are kept, and the volume can be downloaded again.

<!-- END SOURCE: settings.hub.remove.message -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | remove confirmation, side-loaded | lines: 1343–1344 | key: settings.hub.remove.message.sideloaded -->

The XML file and its search-index rows are deleted from this Mac. Your notes, highlights, tags, and summaries for it are kept. **This volume was side-loaded, so the app cannot download it again** — if you no longer have the file, this cannot be undone.

<!-- END SOURCE: settings.hub.remove.message.sideloaded -->

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

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | recoverySection footer | lines: 267–268 | key: settings.dataRecovery.recovery.footer | shared: iOS+macOS (single edit point) -->

In order of how much they take away. Try the first one first — it is the one that deletes nothing.

<!-- END SOURCE: settings.dataRecovery.recovery.footer -->

#### Fix iCloud Sync — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | fixSync confirmation | lines: 142–143 | key: settings.dataRecovery.fixSync.message | shared: iOS+macOS (single edit point) -->

This clears the local copy of your synced data and downloads it again. Nothing in iCloud is deleted, so nothing is lost. The app returns to onboarding while it restores. The clearing happens the next time the app starts, so quit and reopen it.

<!-- END SOURCE: settings.dataRecovery.fixSync.message -->

#### Reset This Device — confirmation message

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | resetDevice confirmation | lines: 169–170 | key: settings.dataRecovery.resetDevice.message | shared: iOS+macOS (single edit point) -->

Downloaded volumes and the search index go; your notes, highlights, tags, collections and projects stay in iCloud and come back on the next launch. You will need to download volumes again.

<!-- END SOURCE: settings.dataRecovery.resetDevice.message -->

#### Broken Cross-References report footer

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | reports section footer | lines: 543–544 | key: settings.export.brokenRefs.footer | shared: iOS+macOS (single edit point) -->

Every cross-reference in the printed FRUS volumes that points to a document, page, or volume the corpus does not contain. The list covers the whole corpus. The CSV names each broken target once, not once for every occurrence. A fuller spreadsheet, with one row per occurrence and its source line number, is produced by a separate tool rather than in the app.

<!-- END SOURCE: settings.export.brokenRefs.footer -->

#### Research-data export — JSON footer

<!-- Wave R-5, NEW key (`settings.export.json.footer` listed six things; the file now carries seven). The research trail is named explicitly rather than folded into "your research data" because it is the part a reader would not assume was in there — and the part they may want to check before sharing the file, since it includes the text of every search they ran. -->

<!-- Archive Visits Phase 2, NEW key (`…json.footer.trail` listed seven things; the file now also carries archive visit plans). -->

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | DataExportSections JSON section footer | key: settings.export.json.footer.visits | shared: iOS+macOS (single edit point — hosted by Data & Recovery on both) -->

One JSON file with your notes, tags, highlights, collections, custom prompts, projects, and archive visit plans. It also holds your research trail: every document you opened, every search you ran and how many results it returned, and every collection you exported.

<!-- END SOURCE: settings.export.json.footer.visits -->

#### Erase Everything — warning

<!-- Wave R-5, NEW key. Wave R-2a extended `EraseEverythingView.performReset` to delete the whole research trail but left this list — the screen's entire account of what is about to go — unchanged, so the warning under-stated its own reach. -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: the Research Trail erase warning; the trail schema was retired (R-2b). Kept so the
> wording is not lost; delete it, or point it at a live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | key: settings.erase.warning.trail | shared: iOS+macOS (single edit point — reached from the macOS Data & Recovery sheet) -->

This deletes every downloaded volume, the search index, and all of your research notes, projects, tags, collections, highlights, and AI-generated summaries — along with your whole research trail: every document you opened, every search you ran, and every collection you exported. Because your research data syncs, it goes from your other devices too. This cannot be undone.

<!-- END SOURCE: settings.erase.warning.trail -->

#### Erase Everything — first confirmation

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | lines: 1354–1355 | key: settings.erase.confirm1.message | shared: iOS+macOS (single edit point) -->

Everything listed above will be deleted from this device and from iCloud.

<!-- END SOURCE: settings.erase.confirm1.message -->

#### Erase Everything — final confirmation

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | EraseEverythingView | lines: 1370–1371 | key: settings.erase.confirm2.message | shared: iOS+macOS (single edit point) -->

Export your research data first if you might want it back.

<!-- END SOURCE: settings.erase.confirm2.message -->

#### Erase All Data — what exactly goes

<!-- W-4 (#279), NEW key (`…inventory.visits` under-stated the reach once the reset began deleting document-classification corrections — the same fault each predecessor key was minted to fix). -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | key: settings.erase.warning.inventory.corrections -->

This deletes every downloaded volume and the search index. It deletes all of your research notes, projects, tags, collections, highlights, and AI-generated summaries. It also deletes your saved searches, working corpora, custom volume scopes, archive visit plans, project leads, and any person-identity or document-classification corrections you have made. It deletes your whole research trail as well: every document you opened, every search you ran, and every collection you exported. Because your research data syncs, it goes from your other devices too. Your app preferences are kept. This cannot be undone.

<!-- END SOURCE: settings.erase.warning.inventory.corrections -->

---

#### When iCloud has not been told about a record type yet

<!-- SOURCE: FRUSExplorer/Settings/DataRecoveryView.swift | lines: 486–487 | key: settings.dataRecovery.schema.about.pending -->

iCloud has to be told about each kind of record the app saves before it will accept one. Some additions in this version have not been published yet. Records that use them will not upload until they are. Everything else keeps syncing. This is a problem with the app, not with your account. There is nothing you can do here except report it.

<!-- END SOURCE: settings.dataRecovery.schema.about.pending -->

---

#### When the stored data does not match the running build

<!-- SOURCE: FRUSExplorer/Models/StoreSchemaDiagnostic.swift | lines: 118 | key: storeSchema.summary.consequence -->

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

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | lines: 1672–1673 | key: settings.display.reading.footer -->

"Remember Last" reopens documents in the mode you used last, Read or Research. Research mode shows the Research rail in a side panel beside the document. Read mode hides the rail so you can just read. The rail toggle inside a document always wins for that document.

<!-- END SOURCE: settings.display.reading.footer -->

---

#### Reading mode — footer (iPhone)

<!-- SOURCE: FRUSExplorer/Settings/SettingsView.swift | lines: 1669–1670 | key: settings.display.reading.footer.iphone -->

The Research rail opens as a bottom sheet from the toolbar's Research button. It never opens on its own, so it cannot cover a document you only meant to read. Edge-Tap Page Turn moves you between documents while the rail is closed.

<!-- END SOURCE: settings.display.reading.footer.iphone -->

---

#### Custom volume scopes — the coverage-years facet

<!-- SOURCE: FRUSExplorer/Settings/CustomScopesView.swift | lines: 948–949 | key: settings.scopes.facet.coverage.footer -->

Adds volumes whose coverage overlaps the years you set. You can also narrow by editor. Leave both years blank to add by editor name alone. Volumes with no coverage dates in the manifest never match a year range.

<!-- END SOURCE: settings.scopes.facet.coverage.footer -->

---

#### Browse — the search index could not be opened

<!-- SOURCE: FRUSExplorer/Browser/BrowserViewModel.swift | lines: 518 | key: browser.indexing.pipelineUnavailable -->

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

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ExamineResultsTip.title | key: tip.examine.title | shared: iOS only -->

Four Ways to Read These Results

<!-- END SOURCE: tip.examine.title -->

<!-- SOURCE: FRUSExplorer/App/DiscoveryTips.swift | ExamineResultsTip.message | key: tip.examine.message | shared: iOS only -->

Place them on a timeline, line every occurrence up on your search term, rank the words that keep company with it, or break the whole match down by year, volume, person and provenance.

<!-- END SOURCE: tip.examine.message -->

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
<!-- SOURCE: FRUSExplorer/Collections/CollectionExportSheet.swift | CollectionExportSheet.nativeShareOptions | lines: 597–598 | key: export.native.hint | shared: iOS+macOS (single edit point) -->

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

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 935–936 | key: search.facets.on.help.v2 -->

Break the whole match down by year, volume, person, type and provenance — before any narrowing you apply

<!-- END SOURCE: search.facets.on.help.v2 -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: no kwic string remains in SearchSheet. Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1126–1127 | key: search.kwic.show.help.v2 -->

Show every occurrence of your term on its own line, aligned — for the documents on this page

<!-- END SOURCE: search.kwic.show.help.v2 -->

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1524 | key: search.cap.tooltip -->

*Interpolated with the loaded and total counts.*

Showing %lld of %lld matches. Narrow your search with a date range, volume filter, or more specific terms to see every result.

<!-- END SOURCE: search.cap.tooltip -->

<!-- SOURCE: FRUSExplorer/App/SearchSheet.swift | lines: 1529 | key: search.cap.tooltip.unknownTotal -->

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

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 925–926 | key: search.subject.facet.footer -->

Experimental. These topics are detected automatically from the text, not editorial subject headings, so some are wrong. Choose a sub-category: categories themselves are headings, because each one reaches most of the series. The volume count beside each row says how many it selects, and the volume picker then fills with the matches you have indexed.

<!-- END SOURCE: search.subject.facet.footer -->

---

#### Detected-topic facet — picker footer

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 1441–1442 | key: search.subject.facet.picker.footer -->

Detected topics (experimental). These are inferred from the text, not editorial subject headings, so some are wrong. A volume appears when any document in it carries the topic — mentioned is enough. Categories are headings, not filters — every one of them reaches most of the series — so open a category and choose a sub-category, and check the volume count beside each. For finer topics, browse the Topic index.

<!-- END SOURCE: search.subject.facet.picker.footer -->

---

### 7.4 Concordance (keyword in context)

*Source: `FRUSExplorer/Search/ConcordanceView.swift`*

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.empty.detail -->

These results matched, but none of their text could be aligned on your search term. Phrase, wildcard and proximity searches match in ways a concordance cannot center on a single word.

<!-- END SOURCE: search.kwic.empty.detail -->

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.omitted -->

*Interpolated with the omitted count and the per-document line cap.*

%lld further occurrences aren't shown — each document contributes at most %lld lines.

<!-- END SOURCE: search.kwic.omitted -->

<!-- SOURCE: FRUSExplorer/Search/ConcordanceView.swift | key: search.kwic.unaligned -->

*Interpolated with a document count.*

%lld matching documents contributed no line — their match isn't a whole word this view can center on.

<!-- END SOURCE: search.kwic.unaligned -->

---

### 7.5 Collocation — the words near your term

*Source: `FRUSExplorer/Search/CollocationView.swift`*

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.noArtifact -->

The bundled corpus reference could not be loaded, so there is nothing to measure these neighborhoods against.

<!-- END SOURCE: search.collocation.unavailable.noArtifact -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: replaced by the specific reasons (.noArtifact/.noMatches/.nothingDistinctive/.pending/.scanFailed). Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.mismatch -->

*Interpolated with the setting that differs.*

Your Word Cloud settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to rank these neighbors.

<!-- END SOURCE: search.collocation.unavailable.mismatch -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.noMatches -->

None of these results contains a whole word this measure can center on. Phrase, wildcard and proximity searches match in ways a word window cannot anchor to.

<!-- END SOURCE: search.collocation.unavailable.noMatches -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: replaced by the specific reasons (see .mismatch above). Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.floor -->

*Interpolated with the minimum-count floor.*

No word appears at least %lld times near your matches. A word used once or twice can top a ranking while telling you nothing about the documents, so nothing is ranked. Widen the window or run a broader search to give this more text to read.

<!-- END SOURCE: search.collocation.unavailable.floor -->

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.unavailable.nothingDistinctive -->

Nothing near your matches is used more here than across the corpus. That is a real result, not an error: this query sits in ordinary FRUS prose.

<!-- END SOURCE: search.collocation.unavailable.nothingDistinctive -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: consolidated into search.collocation.caveat.scope.v2. Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/Search/CollocationView.swift | key: search.collocation.caveat.bounded.v2 -->

*Interpolated with the scanned and total counts.*

The scan stopped at %lld of your %lld results, so this ranking covers part of them, not all.

<!-- END SOURCE: search.collocation.caveat.bounded.v2 -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: consolidated into search.collocation.caveat.scope.v2. Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

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

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: only corpus.save.source.search remains in ResultSetScope. Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 240–242 | key: corpus.save.truncated.total -->

*Interpolated with the captured and total counts.*

These %1$@ documents are the highest-scoring of %2$@ matching documents. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.truncated.total -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: only corpus.save.source.search remains in ResultSetScope. Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 245–247 | key: corpus.save.truncated.unknown -->

*Interpolated with the captured count.*

These %@ documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset.

<!-- END SOURCE: corpus.save.truncated.unknown -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: only corpus.save.source.search remains in ResultSetScope. Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

<!-- SOURCE: FRUSExplorer/Search/ResultSetScope.swift | lines: 258–260 | key: corpus.save.checklistHiding -->

*Interpolated with the hidden count.*

Checklist mode is hiding %@ reviewed documents. They will not be in this corpus.

<!-- END SOURCE: corpus.save.checklistHiding -->

<!-- SOURCE: FRUSExplorer/Search/SearchFilterView.swift | lines: 765–766 | key: search.corpus.footer -->

A working corpus is a fixed set of documents. Applying one searches only inside it. Manage them in Settings.

<!-- END SOURCE: search.corpus.footer -->

> ⚠️ **RETIRED — editing this block has no effect.** The app no longer ships this
> string: no longer in SearchFilterView. Kept so the wording is not lost; delete it, or point it at a
> live key, when you next revise this section.

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

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.zero.many %lld -->

*Interpolated with a count. Kept separate from the singular above because there is no String Catalog to inflect it.*

%lld of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.

<!-- END SOURCE: appendix.caveat.zero.many %lld -->

<!-- The Meaning route's own caveat (#1127): its counts are a ranked top-K, not a match total, and
     its zeros are not term absence — different claims than the keyword rows make. Both sentences
     are the caveat; neither may be dropped for brevity. -->
<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | lines: 348–349 | key: appendix.caveat.semantic.one -->

One search ran by meaning (on-device model) rather than by keywords. Its count is the size of a ranked list, not a match total, and a zero there does not mean any term is absent.

<!-- END SOURCE: appendix.caveat.semantic.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | lines: 350–351 | key: appendix.caveat.semantic.many %lld -->

*Interpolated with a count — keep `\(semanticRowCount)` intact.*

\(semanticRowCount) searches ran by meaning (on-device model) rather than by keywords. Their counts are sizes of ranked lists, not match totals, and zeros there do not mean any term is absent.

<!-- END SOURCE: appendix.caveat.semantic.many %lld -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.floor.one -->

One search hit the app's row ceiling. Its count is shown as "at least N" and is a floor, not a total — do not sum it with the others.

<!-- END SOURCE: appendix.caveat.floor.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.floor.many %lld -->

*Interpolated with a count.*

%lld searches hit the app's row ceiling. Those counts are shown as "at least N" and are floors, not totals — do not sum them.

<!-- END SOURCE: appendix.caveat.floor.many %lld -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.unrecorded.one -->

One search predates this app version. It saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. It is marked "as reported" and cannot be checked against the others.

<!-- END SOURCE: appendix.caveat.unrecorded.one -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.caveat.unrecorded.many %lld -->

*Interpolated with a count.*

%lld searches predate this app version. They saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. They are marked "as reported" and cannot be checked against the others.

<!-- END SOURCE: appendix.caveat.unrecorded.many %lld -->

<!-- SOURCE: FRUSExplorer/Export/QueryMethodAppendix.swift | key: appendix.attribution -->

Text from Foreign Relations of the United States, Office of the Historian, U.S. Department of State (public domain).

<!-- END SOURCE: appendix.attribution -->

<!-- SOURCE: FRUSExplorer/Export/ResearchDataExportView.swift | lines: 140 | key: settings.export.appendix.footer -->

Every search you ran, in a Markdown table and a CSV. Each row gives the scope the search ran under and how many volumes were indexed at the time. Counts that hit the app's row ceiling appear as "at least N", so a partial result is never printed as a total.

<!-- END SOURCE: settings.export.appendix.footer -->

---

### 7.9 Occurrence counts — when they are refused, and why

*Source: `FRUSExplorer/Analytics/OccurrenceAvailability.swift, AnalyticsView.swift`*

<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | lines: 2890 | key: analytics.measure.help -->

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

<!-- SOURCE: FRUSExplorer/Summarization/BackgroundSummarizationService.swift | lines: 618 | key: bg.summarizer.failed.unavailable -->

*Interpolated with the succeeded and attemptable counts.*

Apple Intelligence became unavailable. Stopped after %lld of %lld documents.

<!-- END SOURCE: bg.summarizer.failed.unavailable -->


### 7.11 Compacting the search index

*Source: `FRUSExplorer/Settings/SettingsComponents.swift` (the shared `IndexCompaction` rule),
rendered identically by both storage hubs.*

*SQLite never returns deleted pages to the filesystem — they go on a freelist and wait to be reused —
so the index file can be much larger than the data in it. Reindexing is the main producer. Measured
on the author's 552-volume store: 6.29 GiB on disk, 2.75 GiB live, 3.53 GiB reclaimable.*

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.storage.compact.available %@ %lld -->

*Interpolated with the reclaimable size and its percentage of the file.*

%@ of this is free space left by reindexing — %lld%% of the file.

<!-- END SOURCE: settings.storage.compact.available %@ %lld -->

<!-- SOURCE: FRUSExplorer/Settings/SettingsComponents.swift | key: settings.storage.compact.blocked %@ %@ -->

*Shown when there is something worth reclaiming but not enough free disk to do it safely. Stated
rather than hidden: this is the case where the number explains the most.*

%@ could be reclaimed, but compacting needs about %@ of free space first.

<!-- END SOURCE: settings.storage.compact.blocked %@ %@ -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 867–869 | key: settings.storage.compact.action | shared: iOS+macOS (single edit point) -->

Compact Database

<!-- END SOURCE: settings.storage.compact.action -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 877–878 | key: settings.storage.compact.caveat | shared: iOS+macOS (single edit point) -->

Rewrites the index to give the free space back. Searching is unavailable while it runs — usually a few seconds, longer on a large library. Nothing you have written is affected.

<!-- END SOURCE: settings.storage.compact.caveat -->

<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 886–888 | key: settings.storage.compact.done %@ -->

*Interpolated with the reclaimed size.*

Reclaimed %@.

<!-- END SOURCE: settings.storage.compact.done %@ -->

<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | key: related.why.cohort %@ %lld -->

*The archival "why related" chip (#644). Interpolated with the container name and its size.
Replaces a bare "same provenance", which read identically for a lot file holding two documents and
for Nixon's NSC Files holding 7,056 — and that difference is what tells a researcher whether sharing
the container is a finding or a filing-cabinet coincidence.*

%@ · 1 of %lld

<!-- END SOURCE: related.why.cohort %@ %lld -->

---

### 7.12 Semantic search fallback (V-5 s3)

> **Compliance note:** the offer card leads to the consent sheet (§1.4c), whose sentence is the
> Gemma flow-down. The offer copy itself is editable; the consent sheet's is not a copy edit.

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchSharedViews.swift | property: SemanticModelOfferCard | lines: 112-114 | key: search.semantic.offer.body -->

Keyword search found nothing, but the app can also search by what a question means — including questions whose words never appear in the documents. This needs a one-time 229 MB model download that runs entirely on this device.

<!-- END SOURCE: search.semantic.offer.body -->

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchFallbackView.swift | property: disclosureCaption | lines: 329-331 | key: search.semantic.results.caption -->

Ranked by meaning, not keywords, across the whole series — your exact words may not appear.

<!-- END SOURCE: search.semantic.results.caption -->

<!-- SOURCE: FRUSExplorer/Search/SemanticSearchFallbackView.swift | property: emptyCard | lines: 282-284 | key: search.semantic.empty.warming %lld -->

Match files for %lld volumes are still downloading in the background. Searching again in a moment may find more.

<!-- END SOURCE: search.semantic.empty.warming %lld -->

---

<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | property: SemanticModeStrip.caption | lines: 41-43 | key: search.meaning.strip.base -->

Meaning search (experimental): ranked by what your question means, across the whole series — your exact words may not appear. Front matter and chapter headings are not reachable this way.

<!-- END SOURCE: search.meaning.strip.base -->

<!-- Appended to the strip when matches land in undownloaded volumes while non-volume filters are
     active (#1127). The claim is precise: the volume scope IS checked for those matches, the other
     filters are NOT — a rewrite that says "filters are ignored" would claim too much, one that
     stays silent would claim too little. -->
<!-- SOURCE: FRUSExplorer/Search/SemanticMeaningModeViews.swift | property: SemanticModeStrip.caption | lines: 52-54 | key: search.meaning.strip.beyondUnchecked -->

Matches in volumes you have not downloaded are checked against your volume scope only, not your other filters.

<!-- END SOURCE: search.meaning.strip.beyondUnchecked -->

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
- **Analyze** — corpus, series, person, and cross-reference dashboards; a chronology view; and a
  word cloud with keyness and collocation.
- **Trace sources** — Source Explorer resolves FRUS source notes to NARA record groups, lot files,
  and collections, with archival neighbors and cross-volume provenance, from bundled indexes.
- **Organize** — projects, collections, exports (PDF, HTML, Word, BibTeX, RIS), Zotero, a research
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

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 378–379 | key: archival.mode.help.v2 -->

Switch between the era rankings, the co-citation network, the reference hand-off diagram, and the archival profile of your own indexed volumes.

<!-- END SOURCE: archival.mode.help.v2 -->

---

#### Network mode is unavailable

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 444–445 | key: archival.network.unavailable -->

The bundled collection authority is unavailable in this build, so the network cannot be drawn.

<!-- END SOURCE: archival.network.unavailable -->

---

#### Flows mode is unavailable

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 464–465 | key: archival.flows.unavailable -->

The bundled reference-flow index is unavailable in this build, so hand-offs cannot be shown. This is not the same as the series having none.

<!-- END SOURCE: archival.flows.unavailable -->

---

#### Document counts are unavailable, so only the volume weight is offered

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1201–1202 | key: archival.caveats.noUsageIndex -->

Document counts are unavailable in this build — the bundled usage index did not load — so only the volume weight is offered.

<!-- END SOURCE: archival.caveats.noUsageIndex -->

---

#### Unprinted pointers on the classes lens — the self-citation disclosure
<!-- #834: the class lens gained its own pointer vocabulary, so Unprinted pointers is no longer
     withheld there — but most central-file citations name the citing document's own file, so
     without this footnote a reader comparing the two lenses compares two different things. The
     shares are measured (three in five overall, three in four before 1946); do not round them
     away. -->

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | key: archival.caveats.classPointersSelfCitation -->

Most central-file citations name the file the citing document itself came from — about three in five, and closer to three in four before 1946. They are counted here, because the file was still cited, but they are not movement between archives.

<!-- END SOURCE: archival.caveats.classPointersSelfCitation -->

---

### 9.2 Collections — the ranking

#### While the archival authority loads

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 498–499 | key: archival.collections.loading -->

Reading the archival authority…

<!-- END SOURCE: archival.collections.loading -->

---

#### Ranking caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1116 | key: archival.ranking.caption %@ %lld %@ %lld -->

Volumes covering %1$@ — %2$lld of them — draw on %3$lld %4$@. Bars are colored by who holds the records.

<!-- END SOURCE: archival.ranking.caption %@ %lld %@ %lld -->

---

#### Nothing to rank in this era

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1008–1009 | key: archival.ranking.empty -->

No archival units resolved in this era under the current unit and weight.

<!-- END SOURCE: archival.ranking.empty -->

---

#### The caveat block — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1486 | key: archival.caveats.measured -->

Measured here

<!-- END SOURCE: archival.caveats.measured -->

---

#### The method statement, in the info popover

*Moved off the page into **About These Figures** by #838, and unchanged in substance: it is what stops the two counts, the era asymmetry and the name-clustering from being read as defects. The disclosures that change with the controls — what the Central Files filter withheld, and a failed artifact load — stayed on the page and have their own blocks above.*

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 240–241 | key: archival.info.method.detail -->

They are parsed from the source note on each published document, not read from an archive's catalog. So they say where the editors drew documents from — an editorial and archival signal, not a census of what the archives hold. Coverage is uneven by era, and switching what the chart shows is the way through it: named collections are scarce before 1948, where central-file numbers carry almost the whole record, and those numbers all but disappear after 1976, where the presidential libraries carry it. Collections are grouped across volumes by name, so when two spellings of one name fail to merge, the same body of records can appear twice under nearby names.

<!-- END SOURCE: archival.info.method.detail -->

---

#### The caveat block — what the umbrella filter withheld

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1193 | key: archival.caveats.umbrella %lld %@ %@ -->

The Central Files umbrella record is hidden here. On its own it accounts for %1$lld %2$@ in the %3$@ volumes, and its bar would flatten the scale. The era-specific Central Files records are still shown.

<!-- END SOURCE: archival.caveats.umbrella %lld %@ %@ -->

---

### 9.3 Network — one collection and everything cited beside it

#### Before a collection is chosen — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 866–867 | key: archival.network.empty.title -->

Choose a Collection

<!-- END SOURCE: archival.network.empty.title -->

---

#### Before a collection is chosen — detail

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 869–870 | key: archival.network.empty.detail -->

Pick a collection to see which other bodies of records the same volumes drew on.

<!-- END SOURCE: archival.network.empty.detail -->

---

#### Nothing co-cited — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 874–875 | key: archival.network.none.title -->

No Co-Cited Collections

<!-- END SOURCE: archival.network.none.title -->

---

#### Nothing co-cited — detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 878 | key: archival.network.none.detail.v2 %@ %@ -->

No other collection shares two or more volumes with %1$@ above the current threshold. %2$@

<!-- END SOURCE: archival.network.none.detail.v2 %@ %@ -->

---

#### Nothing co-cited — what to try

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 884–885 | key: archival.network.none.floor -->

The threshold is already at its lowest, so this collection simply shares no volumes with another — choose a more widely cited one.

<!-- END SOURCE: archival.network.none.floor -->

---

#### The info dock, before a node is selected

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 796–797 | key: archival.network.dock.title -->

Select a node to see the link

<!-- END SOURCE: archival.network.dock.title -->

---

#### The info dock — what the rings mean

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 837 | key: archival.network.dock.summary.v2 %lld %lld %@ -->

%1$lld of the %2$lld nodes above the current threshold are drawn. Distance from the center shows link strength. The dashed rings mark three quarters, one half, and one quarter of the strongest link here (%3$@).

<!-- END SOURCE: archival.network.dock.summary.v2 %lld %lld %@ -->

---

#### The info dock — what a link means

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 841 | key: archival.network.dock.grain %lld -->

%lld collections share two or more volumes with this one. Links are volume-grain — the same volumes drew on both — which is not document-level affinity.

<!-- END SOURCE: archival.network.dock.grain %lld -->

---

#### The info dock — the six-per-custodian cap

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 846 | key: archival.network.dock.capped.v2 %lld -->

%lld more are held back so each custodian's quadrant stays readable; every quadrant keeps its strongest. Raise the threshold to narrow the neighborhood rather than to see more of it.

<!-- END SOURCE: archival.network.dock.capped.v2 %lld -->

---

#### The info dock — the class sub-arc

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 852 | key: archival.network.dock.classes %lld -->

The %lld squares are central-file classes drawn from inside the Central Files record, which is hidden while they are shown.

<!-- END SOURCE: archival.network.dock.classes %lld -->

---

#### A selected node's card

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 782–785 | key: archival.network.card.detail %lld %lld %@ -->

%1$lld volumes cite both this and %3$@; together they supplied %2$lld documents to those volumes.

<!-- END SOURCE: archival.network.card.detail %lld %lld %@ -->

---

#### A selected class node's card

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 778–779 | key: archival.network.class.caption -->

Central-file class — a subject heading inside the State Department's filing system, not a collection

<!-- END SOURCE: archival.network.class.caption -->

---

#### Node accessibility hint

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 631–632 | key: archival.network.node.hint -->

Select to see this link's detail; long-press for actions

<!-- END SOURCE: archival.network.node.hint -->

---

#### Threshold slider — accessibility label

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 284–285 | key: archival.network.threshold.a11y -->

Minimum link strength, as a share of the strongest link

<!-- END SOURCE: archival.network.threshold.a11y -->

---

### 9.4 Flows — where an editor's cross-reference led

#### What this mode is for

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 142–143 | key: archival.flows.intro -->

When a FRUS editor annotated one published document by pointing to another, the two documents usually came from different archives. Added up across the series, those pointers map the paths the editors walked between bodies of records.

<!-- END SOURCE: archival.flows.intro -->

---

#### The unfocused view — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 265–266 | key: archival.flows.top.title | shared: iOS+macOS (the same key in both views — edit both) -->

The heaviest hand-offs in the series

<!-- END SOURCE: archival.flows.top.title -->

---

#### The unfocused view — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 298–299 | key: archival.flows.top.caption -->

Choose a focus collection above to see everywhere its documents point.

<!-- END SOURCE: archival.flows.top.caption -->

---

#### Focused, outgoing — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 358–359 | key: archival.flows.title.outgoing -->

Where these documents point

<!-- END SOURCE: archival.flows.title.outgoing -->

---

#### Focused, incoming — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 360–361 | key: archival.flows.title.incoming -->

What points at these documents

<!-- END SOURCE: archival.flows.title.incoming -->

---

#### Focused, outgoing — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 374–375 | key: archival.flows.caption.outgoing %lld %lld -->

%1$lld references run from this collection to others. A further %2$lld stay inside the collection itself and are excluded — a hand-off to yourself is not a hand-off.

<!-- END SOURCE: archival.flows.caption.outgoing %lld %lld -->

---

#### Focused, incoming — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 376–377 | key: archival.flows.caption.incoming %lld %lld -->

%1$lld references run from other collections to this one. A further %2$lld stay inside the collection itself and are excluded — a hand-off to yourself is not a hand-off.

<!-- END SOURCE: archival.flows.caption.incoming %lld %lld -->

---

#### A selected hand-off — outgoing detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 544–545 | key: archival.flows.card.detail.outgoing %lld %lld -->

%1$lld references, %2$lld%% of everything this collection hands off.

<!-- END SOURCE: archival.flows.card.detail.outgoing %lld %lld -->

---

#### A selected hand-off — incoming detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 546–547 | key: archival.flows.card.detail.incoming %lld %lld -->

%1$lld references, %2$lld%% of everything handed off to this collection.

<!-- END SOURCE: archival.flows.card.detail.incoming %lld %lld -->

---

#### No hand-offs — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 584 | key: archival.flows.none.title -->

No Hand-Offs Recorded

<!-- END SOURCE: archival.flows.none.title -->

---

#### No hand-offs — detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 587 | key: archival.flows.none.detail %@ %lld %lld -->

No cross-reference runs between %1$@ and another collection in this direction. The cross-reference style these come from postdates 1945. Only %2$lld of the %3$lld volumes in the series carry any of these references.

<!-- END SOURCE: archival.flows.none.detail %@ %lld %lld -->

---

#### The caveat block — the footnote share, stated first

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 658 | key: archival.flows.caveats.footnotes %@ -->

%@ of these references are footnotes. A ribbon therefore describes how the editors annotated. While annotating material from one collection, they pointed the reader to material from another. It is not a relationship between the archives themselves.

<!-- END SOURCE: archival.flows.caveats.footnotes %@ -->

---

#### The caveat block — coverage, dates, and the excluded class axis

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 665 | key: archival.flows.caveats.body.v3 %lld %lld %lld %lld -->

Only %1$lld of the %2$lld volumes in the series contribute a single reference — the gap is itself a finding. The central-file classes left out of the diagrams carry %3$lld references over %4$lld pairs. These figures cover the whole series whatever you have downloaded, and carry no dates, so this mode cannot be narrowed to a period.

<!-- END SOURCE: archival.flows.caveats.body.v3 %lld %lld %lld %lld -->

---

#### The caveat block — why you cannot browse the citations

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.browse.detail -->

The app can list the references inside the volumes you have indexed. It cannot tell which of those are the footnotes this measure is built on. A list would therefore disagree with the diagram above it, and nothing on screen would explain why.

<!-- END SOURCE: archival.info.flows.browse.detail -->

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

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 160–161 | key: archival.flows.layer -->

References

<!-- END SOURCE: archival.flows.layer -->

---

#### Unprinted material — what this layer is for

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 140–141 | key: archival.flows.intro.unprinted -->

FRUS editors often name a document they did not print, and say where it is filed. Added up across the series, those pointers show where the editors sent readers for the record they left out.

<!-- END SOURCE: archival.flows.intro.unprinted -->

---

#### Unprinted material — unfocused title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 263–264 | key: archival.flows.top.title.unprinted -->

The heaviest pointers to unprinted material

<!-- END SOURCE: archival.flows.top.title.unprinted -->

---

#### Unprinted material — unfocused caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 296–297 | key: archival.flows.top.caption.unprinted -->

Choose a focus collection above to see everywhere its footnotes send you.

<!-- END SOURCE: archival.flows.top.caption.unprinted -->

---

#### Unprinted material — focused, outgoing title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 352–353 | key: archival.flows.title.unprinted.outgoing -->

Where the footnotes send you

<!-- END SOURCE: archival.flows.title.unprinted.outgoing -->

---

#### Unprinted material — focused, incoming title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 354–355 | key: archival.flows.title.unprinted.incoming -->

Which collections' footnotes send you here

<!-- END SOURCE: archival.flows.title.unprinted.incoming -->

---

#### Unprinted material — focused, outgoing caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 367–368 | key: archival.flows.caption.unprinted.outgoing %lld %lld -->

%1$lld footnotes on documents from this collection name unprinted material in other collections. A further %2$lld name unprinted material in this collection itself, and are left out — the diagram shows where the editors sent you *away* to.

<!-- END SOURCE: archival.flows.caption.unprinted.outgoing %lld %lld -->

---

#### Unprinted material — focused, incoming caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 369–370 | key: archival.flows.caption.unprinted.incoming %lld %lld -->

%1$lld footnotes on documents from other collections name unprinted material in this one. A further %2$lld come from documents already in this collection, and are left out.

<!-- END SOURCE: archival.flows.caption.unprinted.incoming %lld %lld -->

---

#### Unprinted material — the scope caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 644 | key: archival.flows.caveats.unprinted.scope.v2 %lld %lld %lld %lld -->

%1$lld citations were found and %2$lld of them matched a known collection, across %3$lld of the %4$lld volumes in the series. What this layer reads, and why the earlier volumes are nearly absent, is in the ⓘ.

<!-- END SOURCE: archival.flows.caveats.unprinted.scope.v2 %lld %lld %lld %lld -->

---

#### Unprinted material — the coverage-span caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 629 | key: archival.flows.caveats.unprinted.era %lld %lld -->

The volumes contributing here cover %1$lld to %2$lld.

<!-- END SOURCE: archival.flows.caveats.unprinted.era %lld %lld -->

---

#### Unprinted material — the “Ibid.” caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 637 | key: archival.flows.caveats.unprinted.ibid.v2 %@ -->

%@ of these citations come from an “Ibid.”, which the app follows back — a reading rather than a quotation, explained in the ⓘ.

<!-- END SOURCE: archival.flows.caveats.unprinted.ibid.v2 %@ -->

---

#### Unprinted material — what Flows reads, and what it does not

<!-- #834/#1012: this ⓘ item was rewritten when the central-file channel shipped. The old text
     ("what a ribbon claims") lives on in archival.info.flows.detail; this one now carries the
     scope — three citation kinds — and the self-file share, which is why a citation count reads
     roughly three times the number of pointers that lead somewhere new. -->
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.scope.detail -->

This layer reads three kinds of citation: State Department lot files, collections in the presidential libraries, and central-file numbers such as 763.72/10417. The first two are ways of filing that came in after 1945; the third is how the earlier volumes cite, which is why they were nearly absent here until it was added.

Most central-file citations point at the citing document's own file rather than somewhere else — about three in five, and closer to three in four before 1946. Those are counted where a class is ranked, because the class was still cited, but they are not drawn as movement between archives. A count of central-file citations is therefore roughly three times the number of pointers that actually lead somewhere new.

<!-- END SOURCE: archival.info.flows.scope.detail -->

---

#### Unprinted material — export axis, outgoing

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 242–243 | key: archival.export.axis.flows.unprinted.outgoing -->

Unprinted material this collection's footnotes name

<!-- END SOURCE: archival.export.axis.flows.unprinted.outgoing -->

---

#### Unprinted material — export axis, incoming

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 244–245 | key: archival.export.axis.flows.unprinted.incoming -->

Footnotes naming unprinted material in this collection

<!-- END SOURCE: archival.export.axis.flows.unprinted.incoming -->

---

### 9.5 Your Library — the same questions asked of your own index

#### What this mode is for

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1256 | key: archival.library.intro %lld %lld -->

The archival profile of **your** library — computed from the %1$lld source notes across the %2$lld indexed volumes that carry them, not from the bundled corpus-wide aggregates.

<!-- END SOURCE: archival.library.intro %lld %lld -->

---

#### While your source notes are counted

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1249–1250 | key: archival.library.loading -->

Counting your indexed source notes…

<!-- END SOURCE: archival.library.loading -->

---

#### Composition card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1266–1267 | key: archival.library.composition.title | shared: iOS+macOS (the same key in both views — edit both) -->

Where your documents come from

<!-- END SOURCE: archival.library.composition.title -->

---

#### Composition card — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1275–1276 | key: archival.library.composition.caption -->

Every source note in your index, divided among the kinds of archival collection they cite.

<!-- END SOURCE: archival.library.composition.caption -->

---

#### Citation-forms card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1311–1312 | key: archival.library.bands.title | shared: iOS+macOS (the same key in both views — edit both) -->

Citation forms across your volumes

<!-- END SOURCE: archival.library.bands.title -->

---

#### Citation-forms card — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1320–1321 | key: archival.library.bands.caption -->

The same composition, split by the era your volumes cover. Read left to right it is the shift from the State Department's decimal file, through the postwar bureau lot files, to the presidential libraries.

<!-- END SOURCE: archival.library.bands.caption -->

---

#### Your collections card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1401–1402 | key: archival.library.collections.title | shared: iOS+macOS (the same key in both views — edit both) -->

Your most-cited collections

<!-- END SOURCE: archival.library.collections.title -->

---

#### Your collections card — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1411 | key: archival.library.collections.caption %lld %lld -->

Matched from your own source notes against the archival authority list in the app. %1$lld notes cite the central files, which are a filing system rather than a collection. Another %2$lld name something the list does not recognize. Neither group is listed here.

<!-- END SOURCE: archival.library.collections.caption %lld %lld -->

---

#### Your collections card — nothing resolved

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1422–1423 | key: archival.library.collections.empty -->

None of your volumes' source notes name a collection the bundled authority recognizes.

<!-- END SOURCE: archival.library.collections.empty -->

---

#### Your collections card — row hint

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1455–1456 | key: archival.library.collections.hint -->

Shows the documents in your index drawn from this collection

<!-- END SOURCE: archival.library.collections.hint -->

---

#### Footer — what these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1490 | key: archival.library.footer %lld %lld -->

Counted from the %1$lld volumes you have indexed. %2$lld more exist in the series.

<!-- END SOURCE: archival.library.footer %lld %lld -->

---

#### Footer — the two counts the collections list leaves out

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- #838(2) moved the "a source note is not a document" explanation off the page into the ⓘ
     (archival.info.library.detail); the footer keeps only the two measured counts. -->
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1497 | key: archival.library.footer.detail %lld %lld -->

%1$lld notes cite the central files, counted in the composition above. Another %2$lld name something the app's authority list does not recognize.

<!-- END SOURCE: archival.library.footer.detail %lld %lld -->

---

#### Nothing indexed yet — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1510 | key: archival.library.empty.title -->

No Source Notes Yet

<!-- END SOURCE: archival.library.empty.title -->

---

#### Nothing indexed yet — detail

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1512–1513 | key: archival.library.empty.detail -->

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

Where the editors of Foreign Relations of the United States found the documents they published. Collections ranks the archival collections and central-file numbers each era's volumes drew on. Network puts one collection at the center and groups everything cited alongside it by custodian. Flows maps where an editor's cross-reference led when it pointed from one document to another. Your Library counts the same things in the volumes you have indexed.

<!-- END SOURCE: archival.info.shows.detail.v2 -->

---

#### The three counts — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 243 | key: archival.info.weights.title.v2 -->

The three counts measure different things

<!-- END SOURCE: archival.info.weights.title.v2 -->

---

#### The three counts — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 244–245 | key: archival.info.weights.detail.v2 -->

Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. Unprinted pointers counts something else entirely: footnotes pointing at material there that FRUS did not print. The first two measure where documents were drawn from; the third measures where readers were sent. They are never added together. Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and a hundred and eighty-one collections appear only under pointers, having supplied no printed document. A collection named only in a volume's front matter has volumes but no documents.

<!-- END SOURCE: archival.info.weights.detail.v2 -->

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

#### Your Library's rule — title
<!-- #838(2): Your Library's rule, moved off the page into this ⓘ item. The two counts it used to
     carry stay on the chart footer (archival.library.footer.detail) — they are measurements of
     the reader's own library; this is the rule they obey. -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.library.title -->

A source note is not a document

<!-- END SOURCE: archival.info.library.title -->

---

#### Your Library's rule — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.library.detail -->

Only documents whose editors recorded where the original was found appear in Your Library. So its total is smaller than your indexed document count, and volumes with no source notes add nothing. The collections list matches each citation to a named body of records; notes citing the central files are a filing system rather than a collection and are counted in the composition instead. Your Library counts only what you have indexed — Collections does not, and does not change with your downloads.

<!-- END SOURCE: archival.info.library.detail -->

---

#### Collections and classes — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 255 | key: archival.info.units.title -->

Collections and classes are different things

<!-- END SOURCE: archival.info.units.title -->

---

#### Collections and classes — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 256–257 | key: archival.info.units.detail -->

A named collection is a body of records with a custodian. A central-file class is a subject heading inside one filing system — 763.72 for the European War, POL 27 VIET S for the war in South Vietnam. The two are never mixed in one ranking. Classes are ranked at one depth: a decimal file number stands for itself, while subject-numeric designators are grouped to their category and number, and a grouped row opens to the exact designators underneath it. Before 1948 the series cites classes far more than collections. After 1976 it barely cites classes at all.

<!-- END SOURCE: archival.info.units.detail -->

---

---

## 10. Export Method Statements

*Every analytics figure and table that leaves the app carries a methods statement above its numbers — a `#`-commented preamble on a CSV, a printed block on a figure plate. This is the prose a reader sees when the file has traveled without the app, so it has to stand alone. §5 already carries the corpus, Person, Cross-Reference and Word Cloud statements; the Archival and About-the-Series ones are new here.*

---

### 10.1 Archival Analytics

#### The sentence every archival export carries

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 56–57 | key: archival.export.caveat.base -->

Method: these figures come from the source note on each published FRUS document. That note is the citation naming where the editors found the archival original. So they record where the editors drew documents from, not what the archives themselves hold. Collections are grouped across volumes by name. When two spellings of one name fail to merge, a single body of records appears twice under nearby names.

<!-- END SOURCE: archival.export.caveat.base -->

---

#### The pointers exports' own base sentence

*A separate base, not an appended correction: `archival.export.caveat.base` above describes work a
pointers (unprinted-references) export did not do — those figures are parsed from editorial
footnotes, not source notes. Two contradictory methods statements in one file would leave the
reader trusting the first, so the pointers exports swap the base out entirely.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | pointerBaseCaveat | lines: 328–330 | key: archival.export.caveat.base.pointers -->

These figures are parsed from the editorial footnotes of published FRUS documents, not from the source notes that record where those documents came from, and not from an archive's catalog. They count references pointing at material the editors did not print. A reference is an annotation practice, so the figures describe how FRUS annotated its volumes rather than a relation between archives.

<!-- END SOURCE: archival.export.caveat.base.pointers -->

---

#### The class lens's grain sentence

*Stamped when the export ranks central-file classes (#826, owner decision D-3): decimal rows stand
for themselves, subject-numeric rows are folded to category+number. The sentence exists because the
fold hides the designator a reader writes on a pull slip — it says the fold happened and points at
the app's leaf listing. The POL 27 example is the explanation; keep a concrete pair.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | grainCaveat | lines: 69–71 | key: archival.export.caveat.grain -->

Grain: central-file rows are one unit deep. A decimal file number (763.72) stands for itself; subject-numeric designators are grouped to their category and number (POL 27 VIET S and POL 27 ARAB-ISR both count under POL 27), because at full length half of them carry a single document. A grouped row's own leaves, with their counts, are listed under the chart in the app. A volume citing two designators in one group counts once for the group.

<!-- END SOURCE: archival.export.caveat.grain -->

---

#### Why the three weights disagree

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 315–316 | key: archival.export.caveat.weight.v2 -->

The three weights count different things. A document counts only when its own source note names the collection. A volume counts when either its front matter or any document source note names the collection. So a collection named only in front matter has volumes but no documents. Unprinted pointers counts neither: it counts footnotes naming material FRUS did not print, and is never added to the other two. Switching the weight changes which collections appear in the ranking, not just their order.

<!-- END SOURCE: archival.export.caveat.weight.v2 -->

---

#### Why an era can look empty

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 333–334 | key: archival.export.caveat.coverage -->

Coverage is uneven by era. Named collections are scarce before 1948, where central-file classes carry almost the whole record. Classes all but disappear after 1976, where the presidential libraries carry it. A thin ranking usually means you have the wrong unit selected, not a thin era.

<!-- END SOURCE: archival.export.caveat.coverage -->

---

#### Collections ranking — what the era covers

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 96 | key: archival.export.caveat.scope %lld %lld -->

Scope: %1$lld volumes cover this era, and %2$lld archival units in them carry at least one document under the current unit and weight.

<!-- END SOURCE: archival.export.caveat.scope %lld %lld -->

---

#### Collections ranking — what the umbrella filter withheld

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 91 | key: archival.export.caveat.umbrella %lld %@ -->

Withheld: this ranking leaves out the Central Files umbrella record. On its own it accounts for %1$lld %2$@ in this era, and its bar would flatten the scale. The era-specific Central Files records are still included.

<!-- END SOURCE: archival.export.caveat.umbrella %lld %@ -->

---

#### Cited Over Time export — what the bars count

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 178 | key: archival.export.caveat.timeline %lld -->

Scope: the whole published series, not this device's library. Each bar counts the volumes in one coverage era whose front matter or document source notes name this collection — volumes, not documents, so a volume citing it once counts the same as a volume built on it. The %lld eras run contiguously from the first era that cites it to the last, so an interior gap is a real gap. The buckets are FRUS's own subseries rather than decades, because a decade axis splits a published subseries across two bars.

<!-- END SOURCE: archival.export.caveat.timeline %lld -->

---

#### Network — what a link means

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 234–235 | key: archival.export.caveat.network.grain -->

What a link means: two collections are linked because the same volumes drew on both. Each document carries exactly one source note, so no document can cite two collections. The shared-documents measure counts how much material the two collections supplied together to the volumes they share. It does not count documents citing both.

<!-- END SOURCE: archival.export.caveat.network.grain -->

---

#### Network — what the table lists

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 237 | key: archival.export.caveat.network.scope %lld %lld %lld -->

Scope: this table lists %1$lld of the %2$lld units above the current threshold. In all, %3$lld collections share two or more volumes with the focus. The graph draws at most six per custodian so each quadrant stays readable. This table lists exactly what the graph drew.

<!-- END SOURCE: archival.export.caveat.network.scope %lld %lld %lld -->

---

#### Flows — the footnote share, stated first

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 275 | key: archival.export.caveat.flows.footnotes %@ -->

Read this first: %@ of these references are footnotes. A row describes how the editors annotated. While annotating material from one collection, they pointed the reader to material from another. It is not a relationship between the archives themselves.

<!-- END SOURCE: archival.export.caveat.flows.footnotes %@ -->

---

#### Flows — coverage and the absence of dates

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 279 | key: archival.export.caveat.flows.coverage %lld %lld -->

Coverage: only %1$lld of the %2$lld volumes in the series contribute any of these references. The cross-reference style they come from postdates 1945. The figures carry no dates: the stored data is a pair of archival units and a count. You cannot narrow this view to a period.

<!-- END SOURCE: archival.export.caveat.flows.coverage %lld %lld -->

---

#### Flows — why the class axis is excluded

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 283 | key: archival.export.caveat.flows.classes %lld %lld -->

Excluded: central-file classes. Between them the whole series carries %1$lld references over %2$lld pairs — under two per pair — which is too thin to rank, and there are no labels to rank it with.

<!-- END SOURCE: archival.export.caveat.flows.classes %lld %lld -->

---

#### Flows — same-unit references

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 290 | key: archival.export.caveat.flows.sameUnit %lld -->

Excluded: %lld references from this collection to itself. A hand-off to yourself is not a hand-off, but the figure is stated so the exclusion is visible.

<!-- END SOURCE: archival.export.caveat.flows.sameUnit %lld -->

---

#### Flows, unprinted material — what a row claims

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 254 | key: archival.export.caveat.flows.unprinted.claim %lld %lld -->

Read this first: every row is an editorial footnote naming archival material FRUS did not print. A row says the editors, working on material from one collection, told the reader that something unprinted is in another. It is not a relationship between the archives and not a count of documents held anywhere. %1$lld citations were found; %2$lld matched a known collection.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.claim %lld %lld -->

---

#### Flows, unprinted material — scope

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 261 | key: archival.export.caveat.flows.unprinted.scope %lld %lld -->

Scope: State Department lot files, presidential-library collections, and central-file numbers. The first two are post-1945 ways of filing; the third is how the earlier volumes cite, which is why they were nearly absent from this measure until it was added. Most central-file citations name the citing document’s own file rather than another — about three in five — so they are counted but are not movement between archives. %1$lld of the %2$lld volumes in the series contribute a row.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.scope %lld %lld -->

---

#### Flows, unprinted material — method

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 262 | key: archival.export.caveat.flows.unprinted.ibid %@ -->

Method: %@ of these citations come from an “Ibid.” — the archive is named once and referred back to. The app follows that back the way a reader would; it is a reading, not a quotation.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.ibid %@ -->

---

#### Flows, unprinted material — coverage span

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 268 | key: archival.export.caveat.flows.unprinted.era %lld %lld -->

Coverage span: the contributing volumes cover %1$lld to %2$lld.

<!-- END SOURCE: archival.export.caveat.flows.unprinted.era %lld %lld -->

---

---

#### Your Library — what these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 208 | key: archival.export.caveat.library %lld %lld %lld -->

Scope: counted from what you have indexed on this device. That is %1$lld source notes across the %2$lld indexed volumes that carry them, out of %3$lld volumes in the series. These figures change as you index more volumes. Do not compare them with the figures for the whole series.

<!-- END SOURCE: archival.export.caveat.library %lld %lld %lld -->

---

#### Your Library — what a source note is

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 212–213 | key: archival.export.caveat.notes -->

Unit: a source note is not a document. Only documents whose editors recorded where the original was found are counted, so this total is smaller than the indexed document count.

<!-- END SOURCE: archival.export.caveat.notes -->

---

### 10.2 The four About-the-Series dashboards

*One builder per dashboard in `SeriesAnalyticsExport.swift`. Three of the four never read a document's date, so each states its own dating rule rather than inheriting the corpus one — that is what these `dating` blocks are.*

#### What corpus these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 42 | key: series.export.caveat.corpus %lld -->

Corpus: these figures come from a data file that ships with the app and covers all %lld cataloged volumes of the series. They do not depend on which volumes you have indexed on this device. Every device shows the same numbers, and they are available before you download anything.

<!-- END SOURCE: series.export.caveat.corpus %lld -->

---

#### When a subseries scope is active

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 52 | key: series.export.caveat.scope %@ -->

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

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 120 | key: series.export.caveat.provenanceNotes %lld -->

Unit: %lld parsed source notes. A source note is the citation naming where a document's archival original was found. "Other / Unclassified" means a citation the parser could not classify, not a missing note.

<!-- END SOURCE: series.export.caveat.provenanceNotes %lld -->

---

#### Archival sourcing — when categories are hidden

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 115 | key: series.export.caveat.hiddenCategories %@ -->

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

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift | lines: 175 | key: series.export.caveat.adminNotes.v2 %@ -->

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

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1376–1377 | key: source.explorer.noNote.detail | shared: iOS+macOS (the same key in both views — edit both) -->

This document carries no archival source note, and its exact filing couldn't be predicted from its dateline and FRUS chapter.

<!-- END SOURCE: source.explorer.noNote.detail -->

---

#### No source note — the diplomatic series

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1396–1397 | key: source.explorer.noNote.series.diplomatic | shared: iOS+macOS (the same key in both views — edit both) -->

Documents of this era are held in the country-arranged diplomatic series (Despatches and Instructions) at the National Archives, Record Group 59.

<!-- END SOURCE: source.explorer.noNote.series.diplomatic -->

---

#### No source note — the numerical file

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1399–1400 | key: source.explorer.noNote.series.numerical | shared: iOS+macOS (the same key in both views — edit both) -->

Documents of this era are filed in the 1906–1910 Numerical File at the National Archives, Record Group 59, arranged by case number rather than by country or date.

<!-- END SOURCE: source.explorer.noNote.series.numerical -->

---

#### The note parsed, but carries no lookup key

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1242–1243 | key: source.explorer.noKey.explanation | shared: iOS+macOS (the same key in both views — edit both) -->

A free NARA Catalog API key is needed to search for lot file and Presidential Library records. Add your key in Settings.

<!-- END SOURCE: source.explorer.noKey.explanation -->

---

#### The citation form was not recognized

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 838–839 | key: source.explorer.unrecognized.explanation | shared: iOS+macOS (the same key in both views — edit both) -->

The source note format was not recognized. The raw text is shown to the left. Automated NARA Catalog resolution is unavailable for this entry.

<!-- END SOURCE: source.explorer.unrecognized.explanation -->

---

#### The macOS window with no document selected

<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 2004–2005 | key: source.explorer.window.empty.detail -->

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

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1699–1700 | key: source.explorer.decimalPeriod.hint | shared: iOS+macOS (the same key in both views — edit both) -->

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

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1637–1638 | key: source.explorer.numericalFile.found | shared: iOS+macOS (the same key in both views — edit both) -->

These digitized rolls hold File No. \(fileIdentifier). Open one and review the images page by page — documents are filed in numeric order by case.

<!-- END SOURCE: source.explorer.numericalFile.found -->

---

#### The 1906–1910 Numerical File — no roll covers it

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1616–1617 | key: source.explorer.numericalFile.gap | shared: iOS+macOS (the same key in both views — edit both) -->

No digitized roll directly covers this file number. Use the Card Index to confirm the case number, then browse the Numerical File series.

<!-- END SOURCE: source.explorer.numericalFile.gap -->

---

### 11.3 Lot files

#### Requesting a lot file from NARA

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1048–1049 | key: source.explorer.lotFile.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

When requesting the original records from NARA, cite the HMS/MLR entry number together with the lot number — it is the identifier archives staff use to locate the series.

<!-- END SOURCE: source.explorer.lotFile.cite.note -->

---

#### Resolved from the bundled lot index

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1053–1054 | key: source.explorer.lotFile.bundled.note | shared: iOS+macOS (the same key in both views — edit both) -->

Resolved from the bundled index — no API key required. Records may be described at the series level rather than digitized page-by-page.

<!-- END SOURCE: source.explorer.lotFile.bundled.note -->

---

#### HMS / MLR entry numbers

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1034–1035 | key: source.explorer.lotFile.hmsMlr.series.note | shared: iOS+macOS (the same key in both views — edit both) -->

These entry numbers identify the enclosing file series, not this specific file unit.

<!-- END SOURCE: source.explorer.lotFile.hmsMlr.series.note -->

---

#### A possible match, not a confirmed one

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1123–1124 | key: source.explorer.curatedLot.possible.note | shared: iOS+macOS (the same key in both views — edit both) -->

This match was made by collection name, not by a catalog control number. Confirm the lot number against the series before citing it.

<!-- END SOURCE: source.explorer.curatedLot.possible.note -->

---

#### Several candidate lots

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1175–1176 | key: source.explorer.curatedLot.candidates.note | shared: iOS+macOS (the same key in both views — edit both) -->

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

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.note | shared: one definition since W-11 — PublishedSourceGuidanceView renders this for BOTH platforms when the citation grammar declines the note -->

This document was previously published. Consult the cited publication for the original source.

<!-- END SOURCE: source.explorer.published.note -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.lookFor -->

*Interpolated with the extracted designation — a series number, an issue date and page, or a president–year–page. Keep the `\(designation)` placeholder.*

Look for \(designation) in this publication.

<!-- END SOURCE: source.explorer.published.lookFor -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.linkStale -->

*Shown under the link button only when the table's verification stamp is older than the freshness window. Interpolated with the stamp date — keep the `\(…)` placeholder.*

Link last verified \(checked.formatted(date: .abbreviated, time: .omitted)).

<!-- END SOURCE: source.explorer.published.linkStale -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.link.treaties -->

Open the U.S. treaties research guide (Library of Congress)

<!-- END SOURCE: source.explorer.published.link.treaties -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.link.bulletin -->

Browse the Bulletin on the Internet Archive

<!-- END SOURCE: source.explorer.published.link.bulletin -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.link.publicPapers -->

Browse the Public Papers on GovInfo

<!-- END SOURCE: source.explorer.published.link.publicPapers -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.family.treatySeries -->

Treaty Series (Department of State)

<!-- END SOURCE: source.explorer.published.family.treatySeries -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.family.eas -->

Executive Agreement Series (Department of State)

<!-- END SOURCE: source.explorer.published.family.eas -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.family.bulletin -->

Department of State Bulletin

<!-- END SOURCE: source.explorer.published.family.bulletin -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.family.publicPapers -->

Public Papers of the Presidents

<!-- END SOURCE: source.explorer.published.family.publicPapers -->

---

#### Intelligence records

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 548–549 | key: source.explorer.cia.note -->

CIA records are not in the NARA Catalog. The CREST database (cia.gov/readingroom) holds declassified CIA documents including operational files and historical collections.

<!-- END SOURCE: source.explorer.cia.note -->

---

#### A named file series

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 828–829 | key: source.explorer.namedSeries.note -->

A named file series cited without a lot number. The citation does not state the holding repository, so no automated NARA Catalog query is available.

<!-- END SOURCE: source.explorer.namedSeries.note -->

---

#### What a named file series is

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 449–450 | key: source.explorer.namedSeries.explainer -->

A named file series cited without a lot number. The repository is not stated in the citation.

<!-- END SOURCE: source.explorer.namedSeries.explainer -->

---

#### A country series

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1340–1341 | key: source.explorer.countrySeries.intro | shared: iOS+macOS (the same key in both views — edit both) -->

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

Microfilm publication M820 reproduces the series. Most of its 538 file units are digitized, each covering a range of decimal numbers. This panel does not say which one holds this document. The ranges overlap and are not always continuous, so use the index below to find it.

<!-- END SOURCE: source.explorer.parisPeace.rolls -->

---

### 11.6 Digitized scans

#### Only the class is known — iOS

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 718–723 | key: source.explorer.scans.classOnly -->

NARA has scanned \(count) file ranges in decimal class \(cls), but none of them covers \(fileIdentifier). The scans for this file are partial.

<!-- END SOURCE: source.explorer.scans.classOnly -->

---

#### Only the class is known — macOS

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1845–1850 | key: source.explorer.scans.classOnlyMac -->

NARA has scanned \(count) file ranges in this decimal class, but none of them covers \(fileIdentifier). The scans for this file are partial.

<!-- END SOURCE: source.explorer.scans.classOnlyMac -->

---

#### Several ranges contain this file

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1833–1839 | key: source.explorer.scans.multiple | shared: iOS+macOS (the same key in both views — edit both) -->

\(ranges.count) scanned file ranges contain \(fileIdentifier). They are listed narrowest first. NARA digitized this file in overlapping sets, so the widest range is not wrong. The narrowest is simply the most specific.

<!-- END SOURCE: source.explorer.scans.multiple -->

---

#### What a scan range does and does not tell you

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 736 | key: source.explorer.scans.caveat -->

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

<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionDetailView.swift | lines: 372–373 | key: collection.detail.related.footer -->

These collections appear alongside this one in the same volumes' source lists. Ranking uses the overlap coefficient, so a broad umbrella record does not dominate. The link is at volume level: both collections fed the same compilation. It does not mean the same documents cite both.

<!-- END SOURCE: collection.detail.related.footer -->

---

#### No related collections

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2084–2085 | key: source.explorer.related.empty.noNeighbors | shared: iOS+macOS (the same key in both views — edit both) -->

No other indexed documents cite this archival source. Index more volumes to surface related documents.

<!-- END SOURCE: source.explorer.related.empty.noNeighbors -->

---

#### This citation matched no collection

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2087–2088 | key: source.explorer.related.empty.unmatched | shared: iOS+macOS (the same key in both views — edit both) -->

This source note doesn't cite a recognized lot file, central file, or presidential library, so related documents can't be matched.

<!-- END SOURCE: source.explorer.related.empty.unmatched -->

---

---

## 12. Word Cloud — Keyness and its Reference

*The keyness measure and the bundled corpus reference it is scored against, plus every state in which the app refuses to score rather than showing a number it cannot stand behind. §5 already carries the word cloud's info popover and settings footers; these are the keyness strings added since. This section is new in this regeneration.*

---

### 12.1 What the two measures are

#### Frequency and Distinctive

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1105–1106 | key: wordcloud.info.measure.detail -->

Frequency sizes each word by how often it appears here. That tends to surface the vocabulary every FRUS volume shares. Distinctive compares this scope with a built-in reference for the whole corpus. It sizes each word by how much more it is used here than across the series. The measure is log-likelihood keyness, the corpus-linguistics standard. Distinctive lists only words used more here than in the corpus. A word this scope conspicuously avoids is a real finding, and it will not appear. Words occurring fewer than three times here are never ranked. One or two mentions can top a keyness list without telling you anything about the documents.

<!-- END SOURCE: wordcloud.info.measure.detail -->

---

#### The two numbers on each row

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1110–1111 | key: wordcloud.info.keyness.numbers.detail -->

Each row carries two numbers, and they answer different questions. The score on the right is log-likelihood (G²). It measures how strong the evidence is that the difference is real, and the list is ranked on it. “38× more often here” is the effect size: how much more often the word is used here than across the corpus, per word of text. G² grows with the amount of text, so a long volume scores higher than a short collection for the same effect. When you compare two scopes, compare the multiples. A word marked “unpriced” occurs too rarely across the corpus to be counted in the reference, so its multiple is an upper bound.

<!-- END SOURCE: wordcloud.info.keyness.numbers.detail -->

---

#### The reference, named on screen

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 402 | key: wordcloud.keyness.caveat.reference %lld -->

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

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 550 | key: wordcloud.keyness.unavailable.lens %@ -->

The “%@” lens has no corpus reference. Names of people, places, and organizations are not counted across the whole corpus, so there is nothing to compare this scope against. Switch to another lens, or size words by frequency.

<!-- END SOURCE: wordcloud.keyness.unavailable.lens %@ -->

---

#### Your settings do not match the reference

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 555 | key: wordcloud.keyness.unavailable.mismatch %@ -->

Your settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to compare this scope with the corpus.

<!-- END SOURCE: wordcloud.keyness.unavailable.mismatch %@ -->

---

#### Nothing in this scope clears the floor

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 560 | key: wordcloud.keyness.unavailable.floor %lld -->

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

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 704 | key: wordcloud.export.caveat.keyness %lld %lld %@ -->

Keyness: each word is scored against a built-in reference for the whole FRUS corpus. That reference covers %lld of the corpus's %lld distinct words for this lens, and was generated %@. Only words used more here than in the corpus are listed. A word this scope conspicuously avoids is a real finding, and this table does not carry it.

<!-- END SOURCE: wordcloud.export.caveat.keyness %lld %lld %@ -->

---

#### When the reference covers everything

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 714 | key: wordcloud.export.caveat.keyness.complete %lld -->

Keyness candidates: every word occurring at least %lld times in this scope was scored.

<!-- END SOURCE: wordcloud.export.caveat.keyness.complete %lld -->

---

#### When the reference is truncated

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 710 | key: wordcloud.export.caveat.keyness.truncated %lld -->

Keyness candidates: only this scope's %lld most frequent words were scored, so a word that is rare here but unique to it is outside this ranking.

<!-- END SOURCE: wordcloud.export.caveat.keyness.truncated %lld -->

---

#### What "unpriced" means

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 719 | key: wordcloud.export.caveat.keyness.cutoff %lld -->

Reference coverage: the reference counts only words occurring at least %lld times across the corpus. A rarer word is marked unpriced rather than absent. It is scored as though the corpus never used it. Treat a high score on a rare word with care.

<!-- END SOURCE: wordcloud.export.caveat.keyness.cutoff %lld -->

---

### 12.4 Empty states

#### Nothing to draw

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1051 | key: wordcloud.empty.detail -->

There's no indexed text in this scope yet. Download and index the relevant volumes, then try again.

<!-- END SOURCE: wordcloud.empty.detail -->

---

#### The macOS window with no scope

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1723 | key: wordcloud.window.empty.detail -->

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
the neighbor list is drawn only from volumes on the device even though the map draws all 552. Every
one of those limits is stated somewhere below. If an edit reads as having removed one rather than
unpacked it, that is a defect — say so and it goes back.

---

### 13.1 What the window says about itself


#### Panel heading
<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 137–138 | key: semanticAnalytics.about.title | shared: iOS+macOS (single edit point) -->

How the corpus's language sits

<!-- END SOURCE: semanticAnalytics.about.title -->

#### What the map is
<!-- The four verbs a reader can act on — tap, lasso, two poles, and (build 42) arriving from a document. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 158 | key: semanticAnalytics.about.body.v2 | shared: iOS+macOS (single edit point) -->

Every document in the corpus placed by the shape of its language, not by citations or archival provenance. Regions are named by the vocabulary that distinguishes them. Tap a document to open it, draw a lasso to keep a set, or pick two poles to lay the corpus along an axis you can state — which replaces the vertical axis with each volume's coverage year.

<!-- END SOURCE: semanticAnalytics.about.body.v2 -->

#### Experimental standing
<!-- Not hedging. The blind panel that would have graded early-era quality was retired as a gate, so pre-1900 IS unmeasured, and this is the sentence that says so. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 170 | key: semanticAnalytics.about.experimental | shared: iOS+macOS (single edit point) -->

Experimental. This is a model's reading of the language, not an editorial fact, and its quality before 1900 has not been measured.

<!-- END SOURCE: semanticAnalytics.about.experimental -->

#### Layout caveat, under the map
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1289 | key: semanticMap.caveat.map | shared: iOS+macOS (single edit point) -->

Layout preserves local similarity; distances between far regions are not meaningful.

<!-- END SOURCE: semanticMap.caveat.map -->


### 13.2 Regions — a grouping the corpus produced


#### What a region is
<!-- New in build 42. The second sentence is load-bearing: the names are the most distinctive words in a SAMPLE (c-TF-IDF over up to 300 documents), not subject headings, and a reader who takes them for topic labels over-reads every region. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1920 | key: semanticMap.region.whatItIs | shared: iOS+macOS (single edit point) -->

A region is a group the corpus fell into on its own — documents whose language reads alike, found by clustering rather than chosen by an editor. Its name is the most distinctive words in a sample of those documents, not a subject heading, so read it as a hint at what the group is about rather than a claim about every document in it.

<!-- END SOURCE: semanticMap.region.whatItIs -->

#### Save the region as a working corpus
<!-- New in build 42. The lasso could carry a set off the map and a region could not. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1951–1952 | key: semanticMap.region.save | shared: iOS+macOS (single edit point) -->

Save as Working Corpus

<!-- END SOURCE: semanticMap.region.save -->

#### Confirmation after saving
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1944–1945 | key: semanticMap.region.saved %@ | shared: iOS+macOS (single edit point) -->

Saved as “%@”. Find it under Working Corpora, where it can scope a search.

<!-- END SOURCE: semanticMap.region.saved %@ -->


### 13.3 Slices — a contrast the reader proposed


#### What a slice adds, on the selection card
<!-- New in build 42, and the complement of §13.2. The last sentence is the one that keeps it honest: ANY two differing volumes produce a spread, so a tidy picture is not evidence. Removing it would leave the text selling the feature. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2163 | key: semanticMap.axis.whatItAdds | shared: iOS+macOS (single edit point) -->

On the map no direction has a meaning. A slice gives one that does: left to right becomes how far each document leans between two volumes you pick, with time running up the side. Any two volumes will produce a spread, so read it as a contrast you proposed — not one the corpus found.

<!-- END SOURCE: semanticMap.axis.whatItAdds -->

#### After one pole is set
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1842–1843 | key: semanticMap.axis.needsSecondPole.v2 | shared: iOS+macOS (single edit point) -->

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

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1408–1414 | key: semanticMap.caveat.slice.position.v2 %@ %@ %lld | shared: iOS+macOS (single edit point) -->

Left to right is how far each document leans from %1$@ toward %2$@. The reading is approximate — it comes from a compact %3$lld-bit summary of each document — so treat a clear side as meaningful and a small gap as noise.

<!-- END SOURCE: semanticMap.caveat.slice.position.v2 -->

#### Reading a slice's vertical axis
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1333–1334 | key: semanticMap.caveat.slice.vertical.v2 | shared: iOS+macOS (single edit point) -->

Up and down is the volume's coverage midpoint, not each document's own date.

<!-- END SOURCE: semanticMap.caveat.slice.vertical.v2 -->


### 13.4 Arriving from a document, and leaving by its neighbors


#### Research-rail tile
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 784–786 | key: researchRail.tile.semanticMap | shared: iOS+macOS (single edit point) -->

On the Map

<!-- END SOURCE: researchRail.tile.semanticMap -->

#### Research-rail tile help
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 785–786 | key: researchRail.tile.semanticMap.help | shared: iOS+macOS (single edit point) -->

Show where this document sits on the semantic map, among the documents whose language is most like it

<!-- END SOURCE: researchRail.tile.semanticMap.help -->

#### Nearest-documents heading
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2039–2040 | key: semanticMap.nearest.header | shared: iOS+macOS (single edit point) -->

Nearest in language

<!-- END SOURCE: semanticMap.nearest.header -->

#### What the nearest list is drawn from
<!-- The map draws all 552 volumes; this list can only score documents whose vectors are on the device. Saying so is not optional — without it the ten rows read as the ten nearest in the corpus. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2063–2064 | key: semanticMap.nearest.fence | shared: iOS+macOS (single edit point) -->

Drawn only from volumes downloaded on this device — the map shows the whole series, so there may be nearer documents it cannot score yet.

<!-- END SOURCE: semanticMap.nearest.fence -->

#### When the anchor's own volume is absent
<!-- The anchor's own vectors ARE the query, so this is a harder limit than the one above: no vectors for this volume means no comparison at all. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2074–2075 | key: semanticMap.nearest.needsVolume | shared: iOS+macOS (single edit point) -->

Finding nearest documents needs this volume on the device. Download it to compare this document with others.

<!-- END SOURCE: semanticMap.nearest.needsVolume -->

#### A document with no place on the map
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1693–1694 | key: semanticMap.reveal.notOnMap | shared: iOS+macOS (single edit point) -->

This document has no place on the map

<!-- END SOURCE: semanticMap.reveal.notOnMap -->

#### …and why
<!-- About 2,356 display rows — chapter openers, front matter, appendix structure — were never embedded. Ordinary, not a fault, and the wording carries that. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1697–1698 | key: semanticMap.reveal.notOnMap.detail %@ | shared: iOS+macOS (single edit point) -->

Chapter openers, front matter and appendix material were not included when the map was built, so %@ has no point to show. The rest of the series is here.

<!-- END SOURCE: semanticMap.reveal.notOnMap.detail %@ -->


### 13.5 Related Documents — the semantic axis


#### Axis caption when the weight is 0
<!-- The axis ships OFF. Until build 42 the only prose describing it lived in a feedback screen in Settings ▸ Data & Recovery, so the app's most usable semantic feature was its least discoverable. -->

<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | lines: 415–416 | key: related.weights.semantic.off | shared: iOS+macOS (single edit point) -->

Off. Raise it to also match documents whose wording reads alike, even when they share no words, citations or archive. Experimental, and untested on nineteenth-century prose.

<!-- END SOURCE: related.weights.semantic.off -->

#### Axis caption when the weight is raised
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | lines: 417–418 | key: related.weights.semantic.on | shared: iOS+macOS (single edit point) -->

Matches carry a “Semantic match” score. Press and hold one — or right-click on a Mac — to say whether it helped. Those verdicts are how this axis gets judged.

<!-- END SOURCE: related.weights.semantic.on -->

#### Similar-wording axis name (W-17)
<!-- SOURCE: FRUSExplorer/RelatedDocuments/SimilarityModel.swift | key: related.axis.lexical | shared: iOS+macOS (single edit point) -->

Similar wording (experimental)

<!-- END SOURCE: related.axis.lexical -->

#### Similar-wording axis caption while off
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | key: related.weights.lexical.off | shared: iOS+macOS (single edit point) -->

Off. Raise it to also match documents that reuse this one's distinctive wording. Experimental; searches only the volumes indexed on this device, so results vary with your library.

<!-- END SOURCE: related.weights.lexical.off -->

#### Similar-wording axis caption when the weight is raised
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | key: related.weights.lexical.on | shared: iOS+macOS (single edit point) -->

Matches share this document's distinctive wording. Searches only the volumes indexed on this device, so results vary with your library.

<!-- END SOURCE: related.weights.lexical.on -->


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
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 129–130 | key: settings.vectors.auto.label | shared: iOS+macOS (single edit point) -->

Download With Volumes

<!-- END SOURCE: settings.vectors.auto.label -->

#### …its detail
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 137–138 | key: settings.vectors.auto.detail.v3 %@ | shared: iOS+macOS (single edit point) -->

Helps Related Documents find documents on the same subject even when they use none of the same words. About %@ per volume.

<!-- END SOURCE: settings.vectors.auto.detail.v3 %@ -->

#### …its accessibility hint
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 148 | key: settings.vectors.auto.a11y.v2 | shared: iOS+macOS (single edit point) -->

When this is off, the extra file is not downloaded alongside a volume. You can still download them all from the button above, and if you open Related Documents for a volume, the app fetches that volume's file then.

<!-- END SOURCE: settings.vectors.auto.a11y.v2 -->

#### Manual download button
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 161–162 | key: settings.vectors.download.label | shared: iOS+macOS (single edit point) -->

Download Missing Vectors

<!-- END SOURCE: settings.vectors.download.label -->

#### …its detail
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 165–166 | key: settings.vectors.download.detail.v3 %lld %@ | shared: iOS+macOS (single edit point) -->

%lld volumes on this device are missing this file. About %@ to download, and Related Documents gets better for those volumes.

<!-- END SOURCE: settings.vectors.download.detail.v3 %lld %@ -->

#### Remove downloaded vectors
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 263–264 | key: settings.vectors.remove.detail.v2 %@ | shared: iOS+macOS (single edit point) -->

Frees %@. Your volumes, notes and search stay exactly as they are. Related Documents keeps working, but its matches are less precise until these files download again.

<!-- END SOURCE: settings.vectors.remove.detail.v2 %@ -->

#### Retry failed downloads
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 236–237 | key: settings.vectors.retry.detail.v2 | shared: iOS+macOS (single edit point) -->

Lets the app try the downloads that failed earlier. Worth using if you were offline before.

<!-- END SOURCE: settings.vectors.retry.detail.v2 -->

#### When the build carries no vectors
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 283–284 | key: settings.vectors.unavailable.detail.v2 | shared: iOS+macOS (single edit point) -->

This version of the app cannot match documents by subject, so that part of Related Documents is unavailable. Nothing is wrong with your library.

<!-- END SOURCE: settings.vectors.unavailable.detail.v2 -->

#### Problems — nothing noticed
<!-- This deliberately REFUSES to give a clean bill of health: the app only notices a problem when it downloads or searches a volume, so 'no problems' would claim more than it knows. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 118 | key: settings.vectors.problems.none.v2 | shared: iOS+macOS (single edit point) -->

Nothing has gone wrong since the app opened. The app only notices a problem when it downloads or searches a volume, so this does not mean every file is good.

<!-- END SOURCE: settings.vectors.problems.none.v2 -->

#### A file that did not arrive intact
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 150–151 | key: settings.vectors.error.integrity.v2 | shared: iOS+macOS (single edit point) -->

The file did not arrive intact, so the app discarded it. Downloading again usually fixes this.

<!-- END SOURCE: settings.vectors.error.integrity.v2 -->

---

### 13.7 The map as an exported figure — frames and slices

*W-3 (#1100–#1101) and W-2a gave the map an offscreen figure-export path. These are the method
sentences stamped on what leaves the app; like §10, they must stand alone once the file has
traveled.*

#### The frame sequence's grain sentence
<!-- The publication animation's per-frame claim. The refusal in the second clause is the point:
     a frame lights the documents of the volumes published so far — a scope is a SET OF VOLUMES —
     and a reader will want it to mean "the documents about my subject", which it never does. -->
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapFrameSequence.swift | lines: 84–86 | key: semanticMap.frames.grain -->

Each frame lights every document in the volumes published so far — a scope is a set of volumes, so a frame shows where those volumes' documents sit, never the documents about any particular subject.

<!-- END SOURCE: semanticMap.frames.grain -->

#### The slice figure's caveat
<!-- Placeholder note: `%1$@` and `%2$@` are the slice's two pole labels. Keep them, positional
     numbers included. The capitalized SLICE is deliberate emphasis in a plain-text stamp. -->
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2785–2786 | key: semanticMap.export.caveat.slice %@ %@ -->

This figure shows a SLICE (%1$@ → %2$@), not the map plane: the horizontal axis is the slice projection and the vertical axis is time. Region labels are omitted — a region's center belongs to the map plane, and in the slice its documents sit somewhere else entirely.

<!-- END SOURCE: semanticMap.export.caveat.slice %@ %@ -->

---

### 13.8 Settings ▸ Data & Recovery ▸ Semantic Match Feedback

*The feedback screen for the "Semantically similar (experimental)" Related Documents axis. Shipped
before build 44 but never carried here. The `unknown` block is the honest center of the screen —
the axis is unmeasured exactly where it is meant to help most — and any edit that softens that
admission is a defect. Short chrome not carried: `settings.semanticFeedback.about.header`,
`.how.header`, `.recorded.header`, `.total`, `.helpful`, `.share`, `.export`, `.clear`,
`.clear.confirm`, `.clear.confirmAction`, `.era.unknown`.*

#### Window title
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 135–136 | key: settings.semanticFeedback.title -->

Semantic Match Feedback

<!-- END SOURCE: settings.semanticFeedback.title -->

#### What the axis is
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 40–47 | key: settings.semanticFeedback.what -->

The “Semantically similar (experimental)” axis in Related Documents finds documents by the shape of their language rather than by citations or archival provenance. It is off by default — raise its weight in any Related Documents view to try it.

<!-- END SOURCE: settings.semanticFeedback.what -->

#### What is not known
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 48–56 | key: settings.semanticFeedback.unknown -->

What we do not know is how good it is before 1900. The automatic check we can run relies on the editors’ cross-references, and that citation style only becomes common after 1945 — so it reaches barely 500 early documents out of the whole corpus. Nineteenth-century volumes are exactly where this axis is meant to help most, and exactly where nothing has measured it.

<!-- END SOURCE: settings.semanticFeedback.unknown -->

#### How to give feedback
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 64–70 | key: settings.semanticFeedback.how -->

Long-press (or right-click) any related document that shows the magnifier icon, then choose whether the match was helpful. Nineteenth-century verdicts are worth the most.

<!-- END SOURCE: settings.semanticFeedback.how -->

#### The privacy footer
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 98–104 | key: settings.semanticFeedback.privacy -->

Stored only on this device and never synced to iCloud. Each verdict records the two documents, your judgement, the match score, and which release of the vectors it applies to.

<!-- END SOURCE: settings.semanticFeedback.privacy -->

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
<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | lines: 352–353 | key: settings.hub.downloaded.empty.iOS.v2 -->

No volumes on this device yet. Download them from GitHub, or add an XML file you already have.

<!-- END SOURCE: settings.hub.downloaded.empty.iOS.v2 -->

#### No volumes on this Mac yet. Download them from GitHub, or…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 323–324 | key: settings.hub.downloaded.empty.v2 -->

No volumes on this Mac yet. Download them from GitHub, or add an XML file you already have.

<!-- END SOURCE: settings.hub.downloaded.empty.v2 -->

#### \(HubCopy.volumes(failures)) could not be indexed
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 575–576 | key: settings.hub.indexFailures.v2 -->

\(HubCopy.volumes(failures)) could not be indexed

<!-- END SOURCE: settings.hub.indexFailures.v2 -->

#### Indexes only the volumes that still need it, and leaves t…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 550–551 | key: settings.hub.indexRemaining.help.v2 -->

Indexes only the volumes that still need it, and leaves the rest untouched

<!-- END SOURCE: settings.hub.indexRemaining.help.v2 -->

#### Deletes what the app has built for searching and builds i…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 567–568 | key: settings.hub.rebuild.help.v2 -->

Deletes what the app has built for searching and builds it again from every downloaded volume. Use this if search results look wrong, or if leftovers remain from volumes you deleted.

<!-- END SOURCE: settings.hub.rebuild.help.v2 -->

#### Rebuilds what Spotlight knows about your documents. Quick…
<!-- SOURCE: FRUSExplorer/Settings/MacVolumesStorageHub.swift | lines: 623–624 | key: settings.hub.spotlight.help.v2 -->

Rebuilds what Spotlight knows about your documents. Quicker than a full reindex, because it reuses text the app has already read.

<!-- END SOURCE: settings.hub.spotlight.help.v2 -->

### Storage hub — index health

#### The app updates the index by itself when a new version im…
<!-- SOURCE: FRUSExplorer/Settings/VolumesStorageHubView.swift | lines: 631–632 | key: settings.storage.indexHealth.footer.v2 -->

The app updates the index by itself when a new version improves how indexing works. Check Integrity runs a full check whenever you ask for one.

<!-- END SOURCE: settings.storage.indexHealth.footer.v2 -->

### Semantic vectors — fetch failures and refusals

#### There is no file available for this volume.
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 143–144 | key: settings.vectors.error.notPublished.v2 -->

There is no file available for this volume.

<!-- END SOURCE: settings.vectors.error.notPublished.v2 -->

#### The file downloaded correctly, but it was made for a diff…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 156–157 | key: settings.vectors.error.rejected.v2 -->

The file downloaded correctly, but it was made for a different version of the app, so it was not kept. A future update will publish a matching one.

<!-- END SOURCE: settings.vectors.error.rejected.v2 -->

#### The download did not finish. The app tries again when you…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 153–154 | key: settings.vectors.error.transport.v2 -->

The download did not finish. The app tries again when your connection changes.

<!-- END SOURCE: settings.vectors.error.transport.v2 -->

#### The file is no longer on this device.
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 179–180 | key: settings.vectors.refused.missing.v2 -->

The file is no longer on this device.

<!-- END SOURCE: settings.vectors.refused.missing.v2 -->

#### This file was made for a different version of the app, so…
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 176–177 | key: settings.vectors.refused.provenance.v2 -->

This file was made for a different version of the app, so it cannot be used with this one. Remove it and download again.

<!-- END SOURCE: settings.vectors.refused.provenance.v2 -->

### The document reader's person and term popovers

#### This volume was indexed before the app recorded definitio…
<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | lines: 295–296 | key: glossNotFound.detail.v2 -->

This volume was indexed before the app recorded definitions. To add them, re-index the volume in Settings → Volumes & Storage.

<!-- END SOURCE: glossNotFound.detail.v2 -->

#### This volume was indexed before the app recorded details a…
<!-- SOURCE: FRUSExplorer/App/MacDocumentView.swift | lines: 285–286 | key: personNotFound.detail.v2 -->

This volume was indexed before the app recorded details about people. To add them, re-index the volume in Settings → Volumes & Storage.

<!-- END SOURCE: personNotFound.detail.v2 -->

### Collections and Zotero

#### Search is not ready yet. Try again in a moment.
<!-- SOURCE: FRUSExplorer/Collections/CollectionContentResolver.swift | lines: 34–35 | key: export.smart.noSearchService.v2 -->

Search is not ready yet. Try again in a moment.

<!-- END SOURCE: export.smart.noSearchService.v2 -->

#### Zotero is receiving too many requests right now. Try agai…
<!-- SOURCE: FRUSExplorer/Zotero/ZoteroAPIModels.swift | lines: 206–207 | key: zotero.error.rateLimited.v2 -->

Zotero is receiving too many requests right now. Try again in a moment.

<!-- END SOURCE: zotero.error.rateLimited.v2 -->

### Word cloud

#### The meaningful terms in the chosen scope — a document, vo…
<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1101–1102 | key: wordcloud.info.shows.detail.v2 -->

The meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, custom volume scope, or the whole corpus. “Size words by” chooses what the sizes mean.

<!-- END SOURCE: wordcloud.info.shows.detail.v2 -->

#### Reading every indexed document. On a full library this ta…
<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1006–1007 | key: wordcloud.loading.corpus.v2 -->

Reading every indexed document. On a full library this takes several minutes — you can leave this screen and come back.

<!-- END SOURCE: wordcloud.loading.corpus.v2 -->

### Semantic map lenses

#### Too few source notes
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapLens.swift | lines: 139–140 | key: semanticMap.legend.noProvenance.v2 -->

Too few source notes

<!-- END SOURCE: semanticMap.legend.noProvenance.v2 -->

#### Each volume takes the category its source notes name most…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapLens.swift | lines: 99–100 | key: semanticMap.lens.provenance.caption.v2 -->

Each volume takes the category its source notes name most often — a plurality, not a majority, for 73 of the 498 volumes it colors. Volumes with fewer than ten notes are left uncolored.

<!-- END SOURCE: semanticMap.lens.provenance.caption.v2 -->

### Archival analytics — the three weights

#### The three weights count different things. A document coun…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 315–316 | key: archival.export.caveat.weight.v2 -->

The three weights count different things. A document counts only when its own source note names the collection. A volume counts when either its front matter or any document source note names the collection. So a collection named only in front matter has volumes but no documents. Unprinted pointers counts neither: it counts footnotes naming material FRUS did not print, and is never added to the other two. Switching the weight changes which collections appear in the ranking, not just their order.

<!-- END SOURCE: archival.export.caveat.weight.v2 -->

#### Documents counts how many published documents came out of…
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 244–245 | key: archival.info.weights.detail.v2 -->

Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. Unprinted pointers counts something else entirely: footnotes pointing at material there that FRUS did not print. The first two measure where documents were drawn from; the third measures where readers were sent. They are never added together. Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and a hundred and eighty-one collections appear only under pointers, having supplied no printed document. A collection named only in a volume's front matter has volumes but no documents.

<!-- END SOURCE: archival.info.weights.detail.v2 -->

#### The three counts measure different things
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 243 | key: archival.info.weights.title.v2 -->

The three counts measure different things

<!-- END SOURCE: archival.info.weights.title.v2 -->

### Chronology summary line

#### \(editorialNotes) editorial note\(editorialNotes == 1 ?
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | lines: 1319–1320 | key: chronology.agg.editorial.v2 -->

\(editorialNotes) editorial note\(editorialNotes == 1 ? 

<!-- END SOURCE: chronology.agg.editorial.v2 -->

#### \(volumes) volume\(volumes == 1 ?
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | lines: 1314–1315 | key: chronology.agg.volumes.v2 -->

\(volumes) volume\(volumes == 1 ? 

<!-- END SOURCE: chronology.agg.volumes.v2 -->

### Menus, tooltips, and short labels

#### Chronology, Corpus Analytics, Person Analytics, Cross-Ref…
<!-- SOURCE: FRUSExplorer/Browser/BrowserView.swift | lines: 438–439 | key: browse.analysisTools.help.v3 -->

Chronology, Corpus Analytics, Person Analytics, Cross-Reference Analytics, Archival Analytics, Semantic Analytics, and the corpus Word Cloud

<!-- END SOURCE: browse.analysisTools.help.v3 -->

#### Corpus, Person, Cross-Reference, Archival, and Semantic a…
<!-- SOURCE: FRUSExplorer/App/MainWindowView.swift | lines: 376–377 | key: mainwindow.tools.analytics.menu.help.v3 -->

Corpus, Person, Cross-Reference, Archival, and Semantic analytics, Chronology, and Word Cloud

<!-- END SOURCE: mainwindow.tools.analytics.menu.help.v3 -->

#### Research window (⌘⌥R), Collections (⇧⌘K), Archive Visits…
<!-- Archive Visits Phase 3, NEW key (`…help.v2` named three windows; the menu carries four now — the same re-mint `.v2` itself was). -->

<!-- SOURCE: FRUSExplorer/App/MainWindowView.swift | key: mainwindow.tools.myResearch.help.v3 -->

Research window (⌘⌥R), Collections (⇧⌘K), Archive Visits, and Complete History

<!-- END SOURCE: mainwindow.tools.myResearch.help.v3 -->

#### Open Document
<!-- SOURCE: FRUSExplorer/Research/ResearchView.swift | lines: 809–810 | key: research.action.openDocument.v2 -->

Open Document

<!-- END SOURCE: research.action.openDocument.v2 -->

#### Colors group collections by who holds the records — four…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | lines: 304–305 | key: series.provenance.topCollections.method.v2 -->

Colors group collections by who holds the records — four custodians, not the ten categories above, which classify the citation rather than its holder. Eras here are coarser than the decades above, so a year range ending mid-era still covers the whole era. Document counts come from an index covering all 552 cataloged volumes with no 1900 floor, so a row here can rest on volumes the charts above leave out; the collection names come from a cross-volume authority that reaches 356 of them. The Categories filter above does not apply to this ranking.

<!-- END SOURCE: series.provenance.topCollections.method.v2 -->

#### Digitized Scans
<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1822–1823 | key: source.explorer.scans.header.v2 -->

Digitized Scans

<!-- END SOURCE: source.explorer.scans.header.v2 -->


### Archival Flows — the crossing-citations caveat

#### Some footnotes cross between the two filing systems
<!-- Added by #831's measurement. The numbers are literal because the artifact does not carry this
     axis: the measurement found it too concentrated to draw. If it is ever regenerated with a
     mixed axis, these figures must be re-measured or removed — they are not read from data. -->
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.mixed.detail -->

Some footnotes cross between the two filing systems — a document filed in a lot file or a presidential library pointing to a central-file number, or the reverse. There are about 1,900 of these across the series, and they are not spread evenly: a third of them come from two situations, the 1945 Potsdam volumes moving between Truman's presidential file and the wartime file, and one 1952–54 conference volume moving between its lot file and its conference file. They are counted in neither diagram.

<!-- END SOURCE: archival.info.flows.mixed.detail -->

#### Some citations are read through an “Ibid.”
<!-- The mixed-systems item's sibling in the same Flows ⓘ, never carried here before. The middle
     sentence is the honest claim — the app follows the editor's back-reference "the way a reader
     would, but it is a reading, not a quotation" — and the last sentence delegates the size of
     the effect to the chart rather than fixing a number in prose. Both must survive editing. -->
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 294–295 | key: archival.info.flows.ibid.detail -->

Some of these citations come from an “Ibid.” — the editor wrote the archive out once and then referred back to it. The app follows that back the way a reader would, but it is a reading, not a quotation. The share it accounts for is stated on the chart.

<!-- END SOURCE: archival.info.flows.ibid.detail -->


### Cross-Reference Graph — unprinted archival material (#837, #834)

#### Navigating the graph, and what a teal node is
<!-- The graph's ⓘ "Navigating the graph" item — the retired graph.help.body's successor, repointed
     2026-08-23. Keeps the shipped shape vocabulary: unit and class nodes are CIRCLES like every
     other node (owner's decision 2026-08-19) — the design handoff drew rounded squares, which
     would have inverted the archival Network view's circle=collection / square=class reading.
     #834's last commit put central-file class nodes on this canvas; the body names all three
     citation kinds and says a class node carries its number with NO subject gloss, because the
     filing schedule was renumbered in 1950 and only the earlier schedule ships (#828's standard:
     where the table cannot place something, say nothing). The last sentence is a refusal and must
     survive editing: an unmatched citation is left off rather than guessed. -->
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.info.interact.body.v2 -->

Click a node to see its details. Right-click (or long-press) to recenter the graph on that document or open it in the main window. Use pinch-to-zoom and drag to pan.

Teal nodes are archival material the editors pointed to in a footnote but did not print. There is no document behind one, so the walk ends there.

This graph draws three kinds of archival citation: State Department lot files, collections in the presidential libraries, and the central files cited by decimal number, such as 681.8229/8–2950 — the usual practice in the earlier volumes, and still most archival footnotes in the volumes covering the 1950s. Opening a lot-file or library node shows the collection's record. A central-file node is labeled by the number alone, with no subject beside it: the filing schedule was renumbered in 1950, and a guessed subject could not be told from a right one. A citation that was read but could not be matched is left off rather than drawn as a guess.

<!-- END SOURCE: graph.info.interact.body.v2 -->

#### The legend key
<!-- Shown only when the canvas actually carries a unit node — a permanent key for something
     usually absent teaches a vocabulary the reader will not see. -->
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.legend.unit -->

Not printed — opens the collection

<!-- END SOURCE: graph.legend.unit -->

#### A class node's context-menu heading
<!-- #834: the central-file counterpart of graph.context.unprinted. "Central file" and not the
     class number, because the menu heading names the KIND — the number is on the node. -->
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.context.centralFile -->

Central file, not printed

<!-- END SOURCE: graph.context.centralFile -->


### The classification override — the rail warning and the Settings corrections list (W-4, #1097)

*W-4 let a reader reclassify a document the corpus filed oddly; #1097 moved the control into the
Research rail's classification ⓘ popover by owner decision. The warning is the anomaly disclosure
#279 requires — what follows the override (body styling, badges, filters, counts, exports, across
devices) and what cannot (the bundled series-analytics dashboards, computed from the published
corpus). Softening the "cannot see this change" sentence would turn a disclosed limit into a
silent inconsistency.*

#### The override confirmation warning
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | reclassify confirmation | lines: 1126–1127 | key: classification.override.warning.v2 -->

The document's body styling, badges, search filters, counts, and exports will follow the new classification on all your devices. Bundled series-analytics dashboards are computed from the published corpus and cannot see this change, and other open windows reflect it when reopened. You can restore FRUS's own classification at any time from here or from Settings ▸ Search.

<!-- END SOURCE: classification.override.warning.v2 -->

#### The corrections list — empty state
<!-- SOURCE: FRUSExplorer/Settings/ClassificationCorrectionsView.swift | lines: 106–107 | key: classification.corrections.empty.detail -->

Documents you reclassify from the Research panel appear here, where you can restore FRUS's own classification.

<!-- END SOURCE: classification.corrections.empty.detail -->

#### The corrections list — footer
<!-- SOURCE: FRUSExplorer/Settings/ClassificationCorrectionsView.swift | lines: 136–137 | key: classification.corrections.footer -->

Undoing a correction restores FRUS's own classification and syncs across your devices. A correction for a volume not indexed on this device takes effect when the volume is indexed.

<!-- END SOURCE: classification.corrections.footer -->

---

## 15. Archive Visits — the research-trip planner

*Build 44's flagship (#1086–#1097): an Archive Visit turns documents' source notes and their
footnotes' citations to unprinted material into a prioritized plan for a research trip. The prose
below is the feature's entire editorial voice — the two-claims vocabulary (**drawn from** = the
document's own source note; **pointed at** = a footnote citing something unprinted) and the rule
that the two counts are NEVER added are stated in the info popover and echoed by every footer.
Edits must keep that vocabulary consistent across all the blocks in this section, and must keep
the sparsity disclosure honest: pointed-at references exist on only ~4% of documents corpus-wide,
so a thin list is expected — sparse data, not a failed scan. The trip-packet sheet (15.6) predates
the feature but was rescoped by Phase 0 (#1088) and its empty states rewritten.*

### 15.1 The plan list, and the Mac manager window

#### Empty state — title
<!-- Shared: the same key is used by ArchiveVisitListView (iOS) and MacArchiveVisitManagerView. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitListView.swift | lines: 58 | key: archiveVisit.empty.title -->

No Archive Visits

<!-- END SOURCE: archiveVisit.empty.title -->

#### Empty state — detail
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitListView.swift | lines: 61–62 | key: archiveVisit.empty.detail -->

An Archive Visit turns documents' source notes into a research-trip plan. Seed one from Source Explorer, Archival Neighbors, a collection, or a project — or start empty below.

<!-- END SOURCE: archiveVisit.empty.detail -->

#### List footer — what a plan is
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitListView.swift | lines: 69–70 | key: archiveVisit.list.footer -->

An Archive Visit is your plan for consulting the records behind these documents — what to see, in what order, at which repository. The whole plan syncs to your other devices.

<!-- END SOURCE: archiveVisit.list.footer -->

#### Per-plan coverage line
<!-- Placeholder note: keep `\(indexed.formatted())` and `\(seeds.count.formatted())` intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitListView.swift | lines: 148–149 | key: archiveVisit.coverage.v2 -->

\(indexed.formatted()) of \(seeds.count.formatted()) documents indexed on this device

<!-- END SOURCE: archiveVisit.coverage.v2 -->

#### Mac manager — no selection
<!-- SOURCE: FRUSExplorer/TripPacket/MacArchiveVisitManagerView.swift | lines: 60 | key: archiveVisit.mac.noSelection.title -->

No Archive Visit Selected

<!-- END SOURCE: archiveVisit.mac.noSelection.title -->

<!-- SOURCE: FRUSExplorer/TripPacket/MacArchiveVisitManagerView.swift | lines: 64–65 | key: archiveVisit.mac.noSelection.detail -->

Choose a plan from the picker in the toolbar, or create a new one. Plans can also be seeded from Source Explorer, Archival Neighbors, a collection, or a project.

<!-- END SOURCE: archiveVisit.mac.noSelection.detail -->

#### Deleting a plan
<!-- Shared: the same key is used from the editor, the list, and the Mac manager (three call
     sites, one string each — a change to the defaultValue must be made in all three). The message
     draws the sync boundary: the plan's own data goes, from every device; documents and volumes
     are untouched. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 213–214 | key: archiveVisit.delete.message -->

This deletes the plan, its priority tiers, and its per-target notes — from your other devices too, after sync. Documents and volumes are untouched.

<!-- END SOURCE: archiveVisit.delete.message -->

### 15.2 The editor — coverage and derivation states

#### The summary line
<!-- Placeholder note: keep `\(targets.formatted())` and `\(repositories.formatted())` intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 582–583 | key: archiveVisit.editor.summary.v2 -->

\(targets.formatted()) targets across \(repositories.formatted()) repositories.

<!-- END SOURCE: archiveVisit.editor.summary.v2 -->

#### The coverage caveat
<!-- Phase 4's honesty line: targets derive from the search index, so unindexed seeding documents
     can silently contribute nothing. Placeholder note: keep both `\(…formatted())` interpolations
     intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 587–588 | key: archiveVisit.editor.coverage.v2 -->

\(derived.indexedDocumentCount.formatted()) of \(derived.seededDocumentCount.formatted()) seeding documents indexed on this device — targets from unindexed documents may be missing below.

<!-- END SOURCE: archiveVisit.editor.coverage.v2 -->

#### Deriving
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 269 | key: archiveVisit.editor.deriving -->

Deriving research targets from the plan's documents…

<!-- END SOURCE: archiveVisit.editor.deriving -->

#### No documents seeded
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 555 | key: archiveVisit.editor.noSeeds.title -->

No documents seeded

<!-- END SOURCE: archiveVisit.editor.noSeeds.title -->

<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 558–559 | key: archiveVisit.editor.noSeeds.detail -->

Seed this plan from Source Explorer, Archival Neighbors, a collection, or a project — each surface offers Add to Archive Visit.

<!-- END SOURCE: archiveVisit.editor.noSeeds.detail -->

#### Documents seeded, no targets derived
<!-- Two different empty states, and the difference is the diagnosis: `noTargets` means derivation
     ran and found nothing placeable; `allOff` means the reader switched every contribution off.
     Neither may be blurred into a generic "nothing here". -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1059–1060 | key: archiveVisit.editor.noTargets -->

No targets derive from these documents on this device — their volumes may not be indexed yet, or their source notes name nothing the app can place.

<!-- END SOURCE: archiveVisit.editor.noTargets -->

<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1056–1057 | key: archiveVisit.editor.allOff -->

Every document's contributions are switched off — turn a document's archival source or unprinted references back on under Documents.

<!-- END SOURCE: archiveVisit.editor.allOff -->

### 15.3 The info popover ("About research targets")

#### Title
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 485–486 | key: archiveVisit.info.title -->

About research targets

<!-- END SOURCE: archiveVisit.info.title -->

#### Body — the two claims, and the never-summed rule
<!-- The feature's defining paragraph. "The two counts are never added because they answer
     different questions" is owner decision 1b's rule stated to the reader; the last sentence
     explains why a plan stays correct as volumes index (stored rows are only the reader's own
     tiers/notes/exclusions — everything else re-derives). Both must survive editing. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 488–489 | key: archiveVisit.info.body -->

A target is one archival unit under one claim. Drawn from: the document was published from this file — its own source note. Pointed at: the document's footnotes cite this, unprinted. One document can seed several targets, each prioritized on its own; the two counts are never added because they answer different questions. A row is stored only once you give it a tier, a note, or an exclusion — the rest derives from the seeds each time, so it stays right as volumes index.

<!-- END SOURCE: archiveVisit.info.body -->

#### The corpus sparsity disclosure
<!-- The corpus-wide number is literal in the string (13,750 of 316,839, measured over the full
     index) — if the index is ever rebuilt over a different corpus it must be re-measured, not
     assumed. "Sparse data, not a failed scan" is the sentence doing the work. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 491–492 | key: archiveVisit.info.sparsity -->

Footnote references to unprinted material exist on only about 4% of documents corpus-wide (measured over the full index: 13,750 of 316,839), so a thin pointed-at list is expected — sparse data, not a failed scan.

<!-- END SOURCE: archiveVisit.info.sparsity -->

#### The measured local line
<!-- Phase 4's device-local companion: beside the corpus claim, never replacing it — the two
     describe different populations. Placeholder note: keep both `\(sparsity.…formatted())`
     interpolations intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1103–1104 | key: archiveVisit.info.sparsity.measured.v2 -->

On this device: \(sparsity.withReferences.formatted()) of \(sparsity.indexed.formatted()) indexed documents carry such references.

<!-- END SOURCE: archiveVisit.info.sparsity.measured.v2 -->

### 15.4 Targets — tiers, orphans, substitution

#### Tiers footer
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1482–1483 | key: archiveVisit.tiers.footer -->

Targets without a tier stay in Unprioritized, always listed last. An unlabeled tier reads “Priority 1”.

<!-- END SOURCE: archiveVisit.tiers.footer -->

#### An orphaned stored target
<!-- A stored row whose target no longer derives from the current seeds. "It never deletes itself"
     is the promise: the reader's tier and note survive reseeding until they remove them. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1028–1029 | key: archiveVisit.orphan.caption -->

Stored target — no longer derives from this plan's current seeds. Kept with your tier and notes; it never deletes itself.

<!-- END SOURCE: archiveVisit.orphan.caption -->

#### Removing an orphan
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 180–181 | key: archiveVisit.orphan.remove.message -->

Its tier and note are deleted — from your other devices too, after sync. Nothing else in the plan changes.

<!-- END SOURCE: archiveVisit.orphan.remove.message -->

#### The digitized-substitute hint
<!-- Shown when part of the target's record group is digitized or microfilmed: read it that way
     instead of pulling boxes. Keep the leading ⇄ glyph — it is the row's badge. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 801–802 | key: archiveVisit.target.substitute -->

⇄ Part of this record is digitized or filmed — read it that way instead of pulling.

<!-- END SOURCE: archiveVisit.target.substitute -->

#### An inherited (Ibid.) seeding
<!-- The W-1b rule surfacing in the seeding detail: the citation was inherited from the preceding
     footnote's citation, and the row says so rather than presenting the reading as a quotation. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 881–882 | key: archiveVisit.seeding.inherited -->

Cited as “Ibid.” — inherited from the preceding footnote's citation.

<!-- END SOURCE: archiveVisit.seeding.inherited -->

### 15.5 The Documents tab

#### Footer — the two switches
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1081–1082 | key: archiveVisit.documents.footer -->

Each document contributes through two switches: its own source note (drawn from) and its footnotes' citations to unprinted material (pointed at). References beyond FRUS exist on only about 4% of documents — where a half is absent, the control is a caption, never a dead switch.

<!-- END SOURCE: archiveVisit.documents.footer -->

### 15.6 The trip-packet sheet

*Phase 0 (#1088) rescoped the packet to the documents the reader has actually engaged with, and
rewrote its empty states so each names its real cause. The three causes are distinct diagnoses —
no engaged documents, no search index yet, a smart collection whose saved search cannot run yet —
and an edit must not collapse them into one generic message.*

#### Empty — no documents to plan over
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 208–209 | key: packet.empty.noDocuments.message -->

There are no documents here to plan over. Add documents to a collection, write a note on one, or apply a focus tag — the packet is built from the documents you have engaged with.

<!-- END SOURCE: packet.empty.noDocuments.message -->

#### Empty — the index is not ready
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 190 | key: packet.empty.noIndex.title -->

The search index isn't ready

<!-- END SOURCE: packet.empty.noIndex.title -->

<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 193–194 | key: packet.empty.noIndex.message -->

The packet reads source notes from the search index, which isn't available yet. Finish indexing and try again.

<!-- END SOURCE: packet.empty.noIndex.message -->

#### Empty — a smart collection's search cannot run
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 198 | key: packet.empty.smart.title -->

This collection's search can't run yet

<!-- END SOURCE: packet.empty.smart.title -->

<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 201–202 | key: packet.empty.smart.message -->

This collection's documents come from its saved search, and search isn't available yet. Finish indexing and try again.

<!-- END SOURCE: packet.empty.smart.message -->

#### The research-topic field captions
<!-- Two states of one caption. The seeded form's second sentence is a privacy boundary — the
     drafts send what the reader writes HERE, never the stored project note — and must survive. -->
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 354–355 | key: packet.topic.caption.seeded -->

Seeded from your project's research question — edit freely. The drafts send what you write here, never the stored note.

<!-- END SOURCE: packet.topic.caption.seeded -->

<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 356–357 | key: packet.topic.caption.unseeded -->

The inquiry drafts send what you write here.

<!-- END SOURCE: packet.topic.caption.unseeded -->

---

## 16. Browse — the axis captions

*The coverage statements on the Browse axes: what each axis was computed from, what its counts
denominate, and what cannot be reached through it. These predate build 44 and were a standing gap
in this file. Each is a method sentence with numbers or a refusal in it — the same material as
§10's export statements — so the same editing rule applies: plainer must not mean vaguer, and
every denominator and every "cannot appear here" must survive.*

### 16.1 Clusters

#### The index caption
<!-- Placeholder note: keep `\(clusterCount)`, `\(unclusteredCount)` and `\(percentText)` intact.
     The unclustered disclosure is the load-bearing clause — those documents cannot be reached
     from this list at all, and hiding that would present the axis as exhaustive. -->
<!-- SOURCE: FRUSExplorer/Browser/ClustersBrowseView.swift | lines: 137–142 | key: browser.clusters.caption -->

\(clusterCount) clusters computed from document text. Labels are the most distinctive sampled terms, not subject headings. \(unclusteredCount) documents (\(percentText)%) belong to no cluster and cannot be reached from this list. Era bars reflect each volume's coverage era, not document dates.

<!-- END SOURCE: browser.clusters.caption -->

#### The drill-in footer
<!-- SOURCE: FRUSExplorer/Browser/ClustersBrowseView.swift | lines: 503–506 | key: browser.clusters.drill.footer -->

A cluster is a group the corpus fell into on its own — documents whose language reads alike, found by clustering rather than chosen by an editor. Its label is the most distinctive words in a sample of those documents, not a subject heading. Era counts reflect each volume's coverage era, not each document's own date.

<!-- END SOURCE: browser.clusters.drill.footer -->

### 16.2 Archives

#### The coverage statement
<!-- Placeholder note: keep `\(coverage.noteCount)`, `\(coverage.volumesWithNotes)`,
     `\(coverage.volumesScanned)`, `\(percent)` and `\(noteless)` intact. The last sentence is the
     refusal — the noteless volumes, mostly the pre-1906 annuals, cannot appear on this axis. -->
<!-- SOURCE: FRUSExplorer/Browser/ArchivesBrowseView.swift | lines: 84–89 | key: browser.archives.coverage -->

FRUS's editors printed a source note under \(coverage.noteCount) documents across \(coverage.volumesWithNotes) of \(coverage.volumesScanned) volumes — the archival record this axis browses. About \(percent)% of those notes name an archival collection; most of the rest cite a State Department central-file number. \(noteless) volumes, mostly the pre-1906 annuals, print no notes and cannot appear here.

<!-- END SOURCE: browser.archives.coverage -->

### 16.3 Administrations

#### The index caption
<!-- Placeholder note: keep `\(membershipSum)` and `\(index.volumeTotals.count)` intact. "Dated to
     each term, never by where a volume was published" is the coverage-not-production rule the
     administration profiles are built on; the double-counting disclosure explains why memberships
     sum past the volume count. -->
<!-- SOURCE: FRUSExplorer/Browser/AdministrationIndexView.swift | lines: 179–182 | key: browser.administrations.coverage -->

Volumes filed by the administration their documents cover — dated to each term, never by where a volume was published. A volume spanning two administrations appears under both: memberships sum to \(membershipSum) across \(index.volumeTotals.count) volumes.

<!-- END SOURCE: browser.administrations.coverage -->

#### The drill-in caption
<!-- Placeholder note: keep `\(profile.volumes.count)`, `\(profile.president)` and
     `\(termText(start: profile.start, end: profile.end))` intact. -->
<!-- SOURCE: FRUSExplorer/Browser/AdministrationIndexView.swift | lines: 105–108 | key: browser.administrations.drill.caption -->

\(profile.volumes.count) volumes with documents covering the \(profile.president) administration (\(termText(start: profile.start, end: profile.end))), largest share first. Membership: any dated document. A volume spanning two administrations appears under both.

<!-- END SOURCE: browser.administrations.drill.caption -->

### 16.4 Subjects

#### The coverage statement
<!-- The two disclosures are the caption: counts describe all 552 volumes while search reaches
     only this device's index, and topics are DETECTED, not editorial — "so some are wrong" is a
     sentence the feature owes the reader and must survive editing. -->
<!-- SOURCE: FRUSExplorer/Browser/SubjectIndexView.swift | lines: 260–261 | key: subjects.index.coverage %lld -->

%lld detected topics across the whole series. Counts describe all 552 volumes, not the volumes you have indexed — a search reaches only what is on this device. Topics are detected automatically from the text, not editorial subject headings, so some are wrong.

<!-- END SOURCE: subjects.index.coverage %lld -->
