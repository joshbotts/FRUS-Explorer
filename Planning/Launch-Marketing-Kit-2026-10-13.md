# Launch marketing kit — the first public release

**Status:** DRAFT, 2026-10-13. Written against `v2` @ `0fe15702` (build 50 tagged). Nothing here is
published. It is the drafting pass for `Visual-Marketing-Plan.md` §7's open steps 10 (the capture
sessions, store frames as a separate pass), 12 (the App Preview) and 15 (composed hero and captioned
frames), and it rides on `Store-Listing-Draft.md`, which stays the copy of record for the App Store
Connect fields. Where the two differ on a field, the store draft wins until the owner reconciles them.

**Revised 2026-10-17: a second theme, "built on the editors' work" (§1a).** It credits the editorial
curation and annotation the Office of the Historian's historians put into the series, sets the edited
series apart from a bulk release of documents, and ties every feature that reads the editors'
apparatus back to the part it reads. Its copy is in §1, §3 and §5 and its rules in §6. The same pass
brought three stale figures up to the shipped artifacts: the map's regions in rule 1 and §9, and the
provenance lens's plurality in §6 and §9.

**What this session could and could not do.** This was written on a Linux container with no simulator
and no Mac, so **no capture was taken**. Every composed frame in `Planning/marketing-drafts/` stands
on a capture already in `Docs/screenshots/` (builds 47 and 48, 2026-09-13 to 2026-09-23), and
`Docs/screenshots/README.md`'s *Stale after build 48* and *Not re-checked after the build-49 wave*
lists apply to them in full. **There is no iPhone capture in the repository at all** beyond
`ios/indexing-banner.png`, and the App Store needs an iPhone set (§3). Treat the drafts as the
layout, the copy and the argument, not as the pixels: the pixels come from §8's sittings on build 50.

**Three rules bind every sentence below**, carried from the visual-marketing plan §5:

1. **No number that was not measured from a shipped artifact.** The only figures used here are the
   store draft's §5 table: 553 volumes, published since 1861, 107 subseries, 314,616 documents on the
   map, 140 regions (172 under the earlier model's layout), about 317,000 documents in a full index (316,814 by the parser's replica; a device
   count is owed to the release census). "Every document" is never said.
2. **Caveats travel in the pixels.** A frame that shows the map shows the app's own caveat line; one
   that names a region keeps *Experimental* in view; one that shows NARA data carries the NARA
   sentence; the first frame of every set carries the not-an-official-product sentence.
3. **Describe, never brand.** The optional meaning search is "an optional language model that runs
   on your device"; in the description, "Google's EmbeddingGemma model" is the one permitted form.
   Nothing says "AI-powered".

---

## 1. Positioning

**One line.** *The edited record of U.S. diplomacy, on your device, with tools built on its editors'
work.* (Until 2026-10-17: *The U.S. diplomatic record, on your device, with the tools a 553-volume
corpus needs.*)

**The pitch (boilerplate, 105 words).**

> FRUS Explorer is a research tool for the *Foreign Relations of the United States* series, the
> State Department's documentary record of American foreign policy, published since 1861 and edited
> today by historians in the Office of the Historian. It downloads the Office's TEI editions, indexes
> them on your iPhone, iPad or Mac, and works offline. Its tools are built on the editors' apparatus:
> source notes resolved to the shelf, cross-references drawn as a graph, and the people and dates the
> editors identified made searchable. It is an independent project, not an official product of the
> Office of the Historian or the U.S. Department of State.

**Three proof points, each with its screen.**

| Claim | The screen that proves it | Why it is the claim |
|---|---|---|
| **Offline, whole-series search with facets.** 553 volumes; phrases, proximity and exact words; facets by year, volume, person, document type, provenance and subject. | Search with the Facets inspector open (`macos/search.png`) | history.state.gov searches one volume at a time and shows no facets. This is the daily-use difference. |
| **The editors' apparatus, put to work.** Headings, source notes, cross-references and the people the editors tagged, read from the volumes and made live: a source note resolves to record group, entry and lot; a cross-reference becomes an edge in a graph; a name becomes a person you can follow across the series. | The reader with the Research rail; Source Explorer (`ipad/source-explorer.png`) | A bulk release of documents has none of this. Nothing else turns a FRUS footnote into a pull slip. |
| **The series as a whole.** A map of 314,616 documents by the language they share; term frequency, person networks, chronology, archival sourcing, all exportable with their method. | The semantic map (`ipad/semantic-map.png`); Corpus Analytics (`macos/analytics.png`) | The first time anyone has been able to look at the published record from above. |

**What it is not, said first by us.** Not official. Not every document (two honest counts, neither
"every"). Not a chatbot: the on-device model turns a question into a vector, and summaries are
Apple's on-device framework, one document at a time, with authorship recorded. **English only**: no
`.xcstrings` ships, so the launch is scoped to English-language territories or the listing says so.

**Voice.** Plain, concrete, in the second person, with the research vocabulary the audience already
has (source note, lot file, RG, entry, finding aid, course reader, method appendix). No exclamation
marks. A headline is a verb phrase or a claim, five to eight words. A subline says what the frame
shows and one honest limit.

---

## 1a. Theme: built on the editors' work

**Why it leads.** FRUS is an edited series, and its value is the editing. By statute it must be "a
thorough, accurate, and reliable record of major United States foreign policy decisions and
significant United States diplomatic activity", and any deletion must be marked where it occurs. The
app's own Research Guide says what that takes: "Historians in the compilation and review team
identify the most important documents, provide context through editorial notes and annotations, and
review draft volume manuscripts to ensure they provide 'thorough, accurate, and reliable' coverage."
A bulk release of documents vouches only for the fact of its release. The app's best tools are
readings of what the editors wrote, so the copy says so.

**The edited series against a bulk release.** The middle column quotes the preface's "Editorial
Methodology" in *Foreign Relations of the United States, 1969–1976*, Volume E–9, Part 1 (2014), which
is public domain. Describe a bulk release in general terms only; never name another archive,
collection or project.

| What a researcher needs | The edited series | What the app does with it |
|---|---|---|
| Selection | "all records needed to provide comprehensive documentation of major foreign policy decisions", chosen from the files of the Department and the other agencies involved | Searches the record the editors assembled; its counts are counts of what they chose to print |
| Order | "The documents are presented chronologically according to Washington time." | Chronology, Administrations and date order use the dates the editors assigned |
| A name for each item | "A heading has been supplied by the editors for each document included in the volume." | Results, Browse, citations and collections list documents under those headings |
| Where the original is | "The first footnote to each document indicates the document's source, original classification, distribution, and drafting information." | Source Explorer, the Archives Visit packet, the provenance facet and Archival Analytics |
| How documents connect | annotation that will "provide references to important related documents printed in other volumes" | Live links, the Cross-Reference Graph and Cross-Reference Analytics |
| What isn't there | editorial notes "summarize pertinent material not printed"; withheld text is marked with "the number of lines or pages of text that were omitted" | Editorial notes are searchable; the packet lists files the editors cited but didn't print |
| Who is speaking | lists of persons and of abbreviations and terms in the front matter | Person cards, the People browser, the person facet and Person Analytics |

**Rules.**

1. **Name the element, then the feature.** "Source Explorer starts from the editors' source note" says
   who did the work and what the app adds.
2. **Credit the note to the editors and the reading to the app.** `ProvenanceSource` licenses "this
   came from FRUS and nowhere else" and never "this is what FRUS says": where a value was parsed out
   of printed prose, "this app did the reading".
3. **Keep the layers apart, in the app's own terms.** *FRUS text* is read from the volumes alone.
   *Joined* values combine them with the National Archives catalog, the Office's people register or
   subject taxonomy, or the Department's decimal schedule. *Computed* values come from the app's model
   or word lists and are cited "as the app's output, not the record's". The reader's own notes are a
   fourth thing: "The app never mixes them into the published text."
4. **Speak about the series' method, never for the Office.** Quote the prefaces and the statute.
   Nothing may suggest the Office reviewed, endorsed or uses the app, and copy that names the Office
   carries the not-an-official-product sentence (§6).
5. **Mind the eras.** The prefaces describe modern practice. Of the 553 volumes, 51 carry no source
   note paired with a document, all but one of them published before 1910, and 81 early volumes name
   no editors. Say "most documents" and "modern volumes" where it matters.
6. **Don't give the app the editors' credit.** Never "curated", "annotated" or "organized by FRUS
   Explorer": the app indexes, links, resolves and computes.

**One line per feature**, for the store, the frames, the site and the posts:

| Feature | What it reads | Layer | Line |
|---|---|---|---|
| Search facets | the editors' person tags and editorial-note tagging, each document's source note; the Office's subject mappings for the subject facet | FRUS text, joined | Facets sort every match by what the editors recorded: the people they tagged, whether it is a document or an editorial note, and where the original is filed. |
| The reader | headings, datelines, footnotes, cross-references, person tags, each volume's terms | FRUS text | Documents keep the editors' headings, footnotes and cross-references, live. |
| Chronology, Administrations | the dates the editors assigned, at the precision they gave | FRUS text | Chronology places each document on the date the editors assigned it. |
| People, Person Analytics | the editors' person tags and lists of persons; the Office's people register for identity, life years and careers | FRUS text, joined | The people the editors tagged, tied to one identity across the series by the Office's people register. |
| Source Explorer | the source note and the volumes' Sources sections; the NARA catalog | FRUS text, joined | Source Explorer starts from the editors' source note and resolves it as far as the bundled reference data reaches. |
| Archives Visit | source notes, and footnotes citing files the editors didn't print | FRUS text, joined | The packet keeps the files the editors printed from apart from the files they only cited. |
| Cross-Reference Graph and Analytics | the editors' cross-references and archival citations; rankings computed over them | FRUS text, computed | Every edge is one of the editors' footnotes. The rankings measure how the editors linked documents, not historical importance. |
| Related Documents | five editorial signals (source files, cross-references, dates, placement, people), the Office's subjects, two experimental signals | FRUS text, joined, computed | Ranked mostly by what the editors' apparatus shows two documents share, with two experimental signals the app computes. |
| Collections and readers | headings, source notes; the Persons Index from person tags; Sources & Archives from source notes | FRUS text | A reader keeps the editors' source notes, and its Sources & Archives block lists the collections they name. |
| Citations | the volume's title and editors, the document's number, its history.state.gov page | FRUS text | Every citation credits the volume's editors by name. |
| Topic Index, subject facet | the Office's document–subject mappings, matched by name | joined | Topics come from the Office's subject mappings; they aren't the editors' headings, and the app says so. |
| Meaning search, the map, clusters | the app's model | computed | The app's model reading the language: experimental, and not an editorial fact. |

**Figures this theme may quote**, each measured from a shipped artifact on 2026-10-17: 264,598 source
notes paired with a document, in 502 of the 553 volumes (`collection-usage-index.json`, `coverage`);
8,637 cross-volume citations into 5,747 documents from 185 volumes (`resolved-edge-index.json`:
77,866 document edges less 69,229 within one volume); 81 volumes, all published between 1861 and 1922, whose
header names no editor (`manifest.json`). Figures recorded only in planning documents (body footnotes, editorial notes,
lists of persons, glossaries) need a census first.

---

## 2. The three audiences

Each audience gets a lead frame, a 60–90 s recording, two headline alternates and the objection it
will raise. The demo data on the capture devices (`Docs/screenshots/README.md`, *Simulator, build 48*)
already fits all three: the project **Early Cold War** with its research question, the scopes
*Berlin Crises 1958-1963*, *Cuba 1958-1963* and *Soviet Union 1945-1950*, working corpora for
"Berlin airlift" and `"long telegram"`, the collection **The Long Telegram and Its Readers**, and an
Archives Visit seeded from it plus frus1952-54v02p1/d41 and frus1955-57v19/d81. Reuse it; it was
built so that `trip-packet` has both claim lists, and no new data set is needed.

### 2.1 Researchers — historians and graduate students

**Who.** Diplomatic and international historians, graduate students writing a seminar paper or a
dissertation chapter, archivists and reference librarians who field FRUS questions. They already use
history.state.gov and the printed volumes; they keep Zotero; they will go to College Park.

**The job they arrive with.** Find everything on a question across the series, read it with the
apparatus intact, keep the receipts, cite it, and know where the originals are before the trip.

**The three features that matter.**
1. Search with facets, working corpora and the Query Inspector (manual §7): a result set they can
   defend, frozen as a denominator.
2. Source Explorer and the Archives Visit packet (§14): the source note resolved, the RG/entry/NAID
   lines, the advance-inquiry draft, the restricted-series flags.
3. Cite, Zotero and the method appendix (§11, §17.6): the citation in the Department's style, the
   search log a committee can read.

**Lead frame.** *From footnote to shelf.* (`researchers-04`), then *Plan the trip before you book it.*
(`researchers-05`).

**Headline alternates.** *Every source note, resolved.* · *The archive, before you get there.* ·
*Search the whole series. Keep the receipts.*

**The objection, and the answer.** *"I can search history.state.gov for free."* One volume at a time,
no facets, no proximity, no working corpus, no source-note resolution, and nothing travels to your
Zotero library. The app is free too (owner to confirm the price before this line ships); the
difference is the workbench.

**Recording R (75 s), on the full-corpus iPad or Mac, Early Cold War active.**

| s | On screen | Caption |
|---|---|---|
| 0–8 | Search tab, Keywords, type `"long telegram"`, results land, the match count shows | Search 553 volumes, offline. |
| 8–18 | Open Facets; tap **Years**, then a year; the list narrows; tap **People** | Facets read the whole match before you narrow it. |
| 18–26 | **•••** ▸ Save as Working Corpus… ▸ name it | Freeze the result set as a denominator you can cite. |
| 26–40 | Open frus1946v06/d475; the Research rail; tap **Sources** ▸ Source Explorer resolves the note | Every source note resolved as far as the bundled data reaches. |
| 40–55 | **Add to Archives Visit** ▸ open the packet; scroll past the RG, entry and NAID lines and the Access line | The lines reading-room staff ask you to quote. |
| 55–66 | Back to the document; **Cite** tile ▸ the citation; **Send to Zotero** | Cite as you write. |
| 66–75 | Settings ▸ Data & Recovery ▸ the method appendix export (or Project Home's Searches Run count) | Your searches, logged for the methods section. |

Shoot the Cite sheet step on the iPad in landscape with the rail open: it is the one frame in the
set with no capture at all (§8).

### 2.2 Teachers — course readers, lecture material, classroom analytics

**Who.** Faculty teaching U.S. foreign relations, Cold War, or methods seminars; advanced high-school
and community-college instructors with a document-based course; librarians running instruction
sessions. They want a packet students can open, and a chart that works on a projector.

**The job they arrive with.** Assemble a reader for next week, with framing and questions; put a
document in front of thirty students without thirty logins; show, live, why the record looks the
way it does.

**The three features that matter.**
1. Collections with the **Teaching reader** preset, nested sections, excerpts, headnotes and front
   matter, exported to PDF or Word (manual §12): the course reader.
2. **.fruscollection** sharing and **Share Citation…** (§12.10, §11.2): the same document set to every
   student, each annotating independently; a citation and a history.state.gov link to anyone.
3. The About the Series dashboards and classroom analytics (§16.1, §18.6): publication lag against the
   statute, geographic emphasis over time, a term by year with *% of documents*, all offline, and
   four of them before anything is downloaded.

**Lead frame.** *Build a course reader in an afternoon.* (`teachers-08`), then *Lecture material before
a single download.* (`teachers-09`).

**Headline alternates.** *A reader for next week.* · *The same packet for every student.* · *Show the
record, not a slide about it.*

**The objection, and the answer.** *"My students will not install an app."* They need not: the PDF
and Word exports stand alone, and Share Citation sends a plain link. The app is for the teacher;
the `.fruscollection` route is for the class that does install it. Also, the series dashboards and the
Research Guide are the methods reading; the manual says so (§16).

**Recording T (80 s), on the full-corpus iPad, landscape.**

| s | On screen | Caption |
|---|---|---|
| 0–10 | Collections ▸ **The Long Telegram and Its Readers**; the sidebar with sections and prose; the live preview | A sectioned reader with your own framing. |
| 10–22 | Add Documents ▸ **Citations** tab; paste two citations from a syllabus; they resolve | Paste the syllabus; the citations resolve. |
| 22–34 | A document's **Configure** ▸ Headnote ▸ **Generate**, then **Edit**; the *AI · edited* chip | A one-line headnote, yours, with authorship recorded. |
| 34–46 | Collection settings ▸ **Teaching reader** preset; the Persons Index and Chronology appear in the preview | The Teaching reader preset: full text, source notes, index and chronology. |
| 46–58 | **Export** ▸ PDF; the first page with the title and introduction | Export PDF or Word. |
| 58–70 | Settings ▸ About ▸ Research Guide ▸ **Production & Timeliness**; drag the year range | Lecture material that ships inside the app. |
| 70–80 | Corpus Analytics, term *Berlin*, toggle **% of documents**; tap a bar ▸ the documents behind it | Why raw counts mislead, shown live. |

### 2.3 Policy analysts — crisis chronologies, meaning search, who the record orbits

**Who.** Think-tank and government analysts, Foreign Service officers and staff historians,
journalists on a precedent story, lawyers and students of statecraft. They do not know the series'
volume structure and do not want to; they know the question and the dates.

**The job they arrive with.** What did Washington know and argue in the month of a crisis, across
every file that printed it? Who was in the room? What did the record say about a problem the last
time it came up, whatever words it used then?

**The three features that matter.**
1. **Chronology** (manual §15.7): a date window, every dated document in it from every volume on the
   device, with the volumes carrying the weight named.
2. **Search by meaning** (§7.12): a question, ranked by what it means, on the device; and
   **Person Analytics** Network and Trends (§15.3) for who the record orbits.
3. Corpus Analytics with *% of documents* and **Visualize in Corpus Analytics** from a search (§15.1,
   §7.11); the **Briefing packet** preset (§12.7) for a skimmable read with on-device summaries.

**Lead frame.** *A crisis, day by day, across every volume.* (`analysts-11`), then *Ask a question, not
a keyword.* (`analysts-12`).

**Headline alternates.** *What Washington knew, by the day.* · *The precedent, whatever words it used.*
· *The record of a crisis, in one window.*

**The objection, and the answer.** *"The series stops decades ago; I work on now."* The series runs to
the early 1990s and the newest volumes to 1988 (vol. XVI of 1981–1988 is the latest in the bundle);
the value is precedent, and the dashboards say exactly how far the record reaches. Never claim
currency.

**Recording A (70 s), on the Mac, the Chronology and Search windows side by side.**

| s | On screen | Caption |
|---|---|---|
| 0–14 | Chronology, range 10/14/1962 to 11/20/1962, **Show**; the stacked bars by volume; scroll the day list | Every dated document in the window, whichever volume printed it. |
| 14–24 | Tap **Search in this range**; type `quarantine`; results | Search inside the window. |
| 24–40 | Search window ▸ **Meaning**; type *How did Washington come to see the Soviet Union as its principal adversary?*; the Semantic match percentages | Ask a question, not a keyword. Experimental, on your device. |
| 40–54 | Person Analytics ▸ Network, focus *Kennan, George Frost*; click *Acheson*; **Explore connections** | Who the record orbits. |
| 54–64 | Corpus Analytics with two terms, **% of documents** | Share of the record, not a raw count. |
| 64–70 | A collection with the **Briefing packet** preset, the Key takeaway cards in the preview | A briefing you can skim, with authorship on every summary. |

The Meaning step needs the query encoder downloaded on the capture device (Settings ▸ Volumes &
Storage ▸ the search model) and the "Experimental" banner in frame. The Mac has no capture of this
state (§8).

---

## 3. The store screenshot set

**One set, fourteen frames, three audiences in order.** App Store Connect shows up to ten per device
class, and the first three are what a search result shows, so the three universal frames lead and
the audience frames follow. The listing takes **ten**: the three universal, then
`researchers-04`, `researchers-05`, `researchers-06`, `teachers-08`, `teachers-09`, `analysts-11` and
`analysts-12`. The other four (`teachers-10`, `researchers-07`, `analysts-13`, `analysts-14`) are
for the landing page and the audience posts, where a set can be shown whole. (The owner traded
`teachers-10` for `researchers-06` on 2026-10-15, §8's decision 1.)

The spec is `tools/marketing/shots.json`; `tools/marketing/compose.py` renders it (its README has the
commands); the drafts are in `Planning/marketing-drafts/`, with one contact sheet per audience.

| # | Headline | Subline (as drafted) | iPad capture | Mac capture | iPhone |
|---|---|---|---|---|---|
| 01 | Search 553 volumes of the U.S. diplomatic record. Offline. | Full-text search with phrases, proximity and exact words, faceted by year, volume, person, document type and subject. | `ipad/search-results` (build 47, owner's device: re-shoot with the demo status bar) | `macos/search` | **none** |
| 02 | Read it as printed. Keep what you find. | The editors' headings, footnotes and cross-references, live, with a research rail beside the text… | `ipad/research-rail` (build 47) | `macos/research-strip` | **none** |
| 03 | See the whole series at once. | 314,616 documents placed by the language they share… Experimental. | `ipad/semantic-map` | `macos/semantic-map` | **none** |
| 04 | From footnote to shelf. | The editors' source note, resolved as far as the bundled reference data reaches… No network, no API key. | `ipad/source-explorer` | `macos/source-explorer` | — |
| 05 | Plan the trip before you book it. | An Archives Visit turns your documents into research targets… | `ipad/trip-packet` (packet lines changed, #1514/#1515) | `macos/trip-packet` (**stale**, #1444) | — |
| 06 | Follow what the editors cited. | The editors' own cross-references around any document… | `ipad/cross-reference-graph` (**stale**, #1438/#1481) | `macos/cross-reference-graph` (**stale**, #1438) | — |
| 07 | Cite as you write. | The Department's recommended citation, BibTeX, RIS, or straight into your own Zotero library… | **none** | **none** | — |
| 08 | Build a course reader in an afternoon. | Section the collection by week, excerpt the passages… apply the Teaching reader preset, export PDF or Word. | `ipad/collections-editor` | `macos/collections` (**stale**, #1446) | — |
| 09 | Lecture material before a single download. | How late the official record runs against the law that governs it, and three more dashboards… | `ipad/series-production` | `macos/series-production` | — |
| 10 | Why raw counts mislead, shown live. | Chart a term by year, switch to share of documents, and tap into the documents behind the spike… | `ipad/analytics` (build 47) | `macos/analytics` | — |
| 11 | A crisis, day by day, across every volume. | Chronology lays out every dated document in a window you set… | `ipad/chronology` (build 47) | `macos/chronology` (**stale**, #1387/#1400) | — |
| 12 | Ask a question, not a keyword. | Search by meaning ranks the whole series by what you asked, with an optional language model that runs on your device… Experimental. | `ipad/semantic-search` (build 47) | **none** | — |
| 13 | Who the record orbits. | Person Analytics around any name… | **none** | `macos/person-analytics-network` (**stale**, #1370/#1441) | — |
| 14 | How the archive itself changed. | Which collections each era's editors drew on… | `ipad/archival-analytics` (counts predate #1514) | `macos/archival-analytics` (same) | — |

**The captures as of 2026-10-21 (the plan of record's §6a, sitting S5).** The table's capture notes
are the state of 2026-10-13. Every frame now stands on a capture of build 1861, taken in the
build-51 sweep's sittings S1 to S4 (`Docs/screenshots/README.md`, *The sittings' ledger*), and
`shots.json` names each file. The frames the table marks **none** have one: 07 is `ipad/cite-sheet`
and `macos/cite-popover`, 12 on the Mac is `macos/search-meaning`, and 13 on the iPad is
`ipad/person-analytics-network`. The iPhone has six: `ios/search-results` (01, with
`ios/search-facets`, the facet sheet open, as its second take), `ios/document` (02, the Long
Telegram, which is `frus1946v06/d475`), `ios/semantic-map` (03), `ios/source-explorer` (04) and
`ios/chronology` (11), the last two for a longer iPhone set if the owner wants one. S5 ran the
composer: the drafts are in `Planning/marketing-drafts/`, and the store sizes were written to
`~/Desktop/store`, outside the repository.

**Frame design, as drafted.** The launch screen's palette (`LaunchBackground` #F2F2F4, title black at
0.9) with the icon's red (`FRUSTheme.provenanceFRUS`, #A61C2A) as the eyebrow, Inter Display here and
SF Pro on the Mac; a dark variant (#0F1217, the map film's ground) for the map. Eyebrow, headline,
subline; the capture whole and bleeding at the foot, except the map, which is fitted so its caveat
line stays in the frame; the disclosure line in its own row. No device bezel: a store frame with a
drawn device is a fashion, and a bezel hides the status bar the capture conventions already set.

**Sizes.** The presets render iPad 13-inch at 2752×2064 (landscape, which every iPad capture is),
Mac at 2880×1800 and iPhone 6.9-inch at 1320×2868. **These are external facts from third-party
guides, not from Apple's own table**, and the plan's §6 rule stands: verify in App Store Connect
before export, including whether a landscape iPad set is accepted for the 13-inch slot and whether
a 6.5-inch iPhone set is still accepted. Sources read on 2026-10-13: the Adalo and AppDrift guides to
2026 sizes, the Splitmetrics landscape note, and the App Screenshot Studio note on 12.9 versus 13
inch (links in the session's reply; none is Apple).

**The iPhone gap is the blocking one.** Every iPad and Mac frame has at least a stand-in; the three
universal iPhone frames have none, and the listing cannot be submitted without an iPhone set. The
drafts render them as placeholders carrying the route to capture. *Closed on 2026-10-21: S3 took
the iPhone frames on an iPhone 17 Pro Max under iOS 27.0, and S5 wired them into `shots.json`.*

---

## 4. The App Preview (25 to 30 seconds)

Two passes on one simulator at one resolution, per the plan §2(a): the splash and onboarding exist
only on an erased device, and one queued download replaces them for good.

| s | Pass | Beat | Rule |
|---|---|---|---|
| 0–4 | A (erased) | Launch: the seeded splash cloud resolves to the wordmark | M-5 seeded the lens, so the beat reproduces. The XCUI harness cannot see it; this is a manual recording. |
| 4–10 | A | Onboarding ▸ *What would you like to download?* ▸ switch Corpus → Subseries → Volume; the cloud tracks the scope | **Hold for the LensChip before recording** (the `prepareVolumes` trap): an early frame shows the era's vocabulary and looks right. |
| 10–15 | B (full corpus) | Search `Berlin blockade`; results; Facets open | The match count is in frame and says what it is. |
| 15–20 | B | Open a document; the Research rail; a highlight | |
| 20–25 | B | The map: whole corpus, Regions; one camera transit into a region (M-1) | Reduce Motion off for the transit; the caveat line in frame. |
| 25–29 | B | Source Explorer resolving a note; the Archives Visit packet | NARA sentence is on the packet header itself. |
| 29–30 | — | Wordmark and the one-line disclaimer | *Not an official product of the Office of the Historian or the U.S. Department of State.* |

Cut at the device's native size for each class; no voice-over (English only, and the caption track
says it). The recording is `xcrun simctl io <udid> recordVideo` on the iPad; on the Mac, QuickTime's
screen recording of the isolated check copy (the README's launch-argument patches keep the sync chip
healthy). A 30 s cap is Apple's; keep 2 s of slack.

---

## 5. Launch copy

Everything below reuses the store draft's measured figures and its disclaimer placement. The owner's
three *Open before paste* sentences in the store draft (the "nothing is sent anywhere" claim, "every
chart exports", "every document carries a note") are **not** repeated here: this copy says "notes and
collections sync through your own iCloud account", "most charts export", and "where the editors gave
one".

### 5.1 Announcement post (for the README, a blog, or a newsletter; 447 words)

> **FRUS Explorer, first public release**
>
> *Foreign Relations of the United States* is the State Department's official documentary record of
> American foreign policy: 553 volumes published since 1861, declassified cables, memoranda, minutes
> and intelligence estimates, every one of them in the public domain. FRUS Explorer is a free,
> independent research tool that puts that series on your iPhone, iPad or Mac and builds a workbench
> around it. It is not an official product of the Office of the Historian or the U.S. Department of
> State.
>
> The series is worth building on because of how it is made. Its editors, today the historians of
> the Office of the Historian, choose the documents that record major decisions from the files of
> the Department and the other agencies involved. They print them in date order, write each one's
> heading, note where the original is kept, point to related documents, summarize what they could
> not print, and mark what remains classified. FRUS Explorer is built on that apparatus. Where a
> feature reads it, the app says so, and where the app computes something of its own, it says that
> too.
>
> Download a volume, a subseries or the whole corpus, and the app indexes it on the device. From then
> on, search works offline across everything you hold: phrases, proximity, exact words, and facets by
> year, volume, person, document type, archival provenance and subject. Documents render from the
> Office's own TEI with footnotes, cross-references and person links live. Highlight, annotate and tag;
> file it all under a project; cite in the Department's style, in BibTeX or RIS, or straight into
> Zotero.
>
> Where the editors gave a document a source note, the app resolves it as far as its bundled
> reference data reaches: record group, entry, lot file, series, the repository that holds it. An
> Archives Visit turns the documents you have gathered into a packet of research targets, with the
> lines reading-room staff ask you to quote and a draft of the advance inquiry.
>
> For teaching, collections become course readers: sectioned, excerpted, with headnotes and front
> matter, exported to PDF or Word, or shared with students as an editable file. For the series as a
> whole, there is a map of 314,616 documents placed by the language they share, term frequency over
> time, person networks, a day-by-day chronology, and dashboards on how the series itself is made,
> four of which work before you download anything.
>
> Searching by meaning is optional and experimental: an on-device language model turns your question
> into a vector, and nothing you type leaves the device. Notes and collections sync through your own
> iCloud account.
>
> The series is in the public domain; the app's code is Apache 2.0 on GitHub.

### 5.2 Listserv note (H-Diplo, SHAFR members, a departmental list; 163 words)

> Colleagues: I have released FRUS Explorer, a free iPhone, iPad and Mac app for working with the
> *Foreign Relations of the United States* series offline. It is built on the editors' apparatus. It
> resolves source notes to record group and lot file, draws the editors' cross-references as a graph,
> makes the people they identified and the dates they assigned searchable, and plans an archives
> visit that includes files the editors cited but did not print. It also adds full-text search with
> facets, collections that export as course readers or Zotero records, and series-wide analytics,
> and it keeps what it read from the volumes apart from what it computed itself. It is an independent
> project, not an official product of the Office of the Historian or the Department of State; the
> series is public domain and the code is open source. Manuals and the download are at [link]. I
> would be grateful for bug reports and, especially, for the questions it cannot yet answer.

### 5.3 Social posts (each under 300 characters)

1. *FRUS Explorer is out: 553 volumes of the U.S. diplomatic record on your iPhone, iPad or Mac,
   searchable offline, with the editors' footnotes and source notes kept. Independent, free, open
   source. Not an official product of the Office of the Historian. [link]*
2. *Most FRUS documents carry the editors' note on where the original is kept. FRUS Explorer
   resolves it to record group, lot file and entry, then plans the archives trip, including files
   the editors cited but didn't print. [frame 04 or 05]*
3. *A map of 314,616 FRUS documents placed by the language they share, named by the words that set
   each region apart. Experimental, and the layout's own caveat is on the screen. [frame 03]*
4. *FRUS isn't a document dump. Its editors chose every document, wrote every heading and noted
   where the originals are filed. FRUS Explorer builds on that work: source notes become archive
   leads, cross-references a graph. Not an official product of the Office of the Historian. [link]*
5. *The 1991 statute asks FRUS to be a thorough, accurate and reliable record. That standard is what
   makes the series worth building tools on. FRUS Explorer reads the editors' apparatus and keeps it
   in view. Not an official product of the Office of the Historian. [link]*

### 5.4 One-line press description (under 200 characters)

> FRUS Explorer: an independent, offline research app for the *Foreign Relations of the United
> States* series, built on its editors' annotation. iPhone, iPad and Mac. Free.

(Until 2026-10-17: *…the Foreign Relations of the United States series, on iPhone, iPad and Mac.
Free; the series is public domain.*)

### 5.5 FAQ (for the landing page and the listing's reviewer notes)

- **Is this official?** No. It is an independent tool. The series is published by the Office of the
  Historian and is in the public domain; the app's commentary reflects personal views.
- **Does it need the network?** To download volumes, the optional search model, and figure images;
  and when you ask it to look something up in the NARA Catalog or send to Zotero. Reading, search,
  annotation and most archival resolution run on the device.
- **Is it AI?** Two optional on-device features use a model: summaries (Apple's on-device framework,
  one document at a time, authorship recorded on every summary) and search by meaning (an on-device
  language model, flagged experimental). Nothing you type leaves the device.
- **How much space?** The whole series is about 3.3 GB of volumes; the app's own estimate is about
  2.8 times that again for the index. A subseries is a manageable fraction, and volumes can be
  removed later.
- **Which languages?** English only, in this release.
- **Where do my notes live?** On your device and, if you sign in, in your own iCloud account.
- **What does the editing add?** Selection, order and annotation. The editors choose the documents
  that record major decisions, print them in date order, write a heading for each, note where the
  original is filed, point to related documents, summarize what they could not print, and mark what
  is still classified. Most of FRUS Explorer's research tools read that apparatus.
- **Which parts come from the editors, and which from the app?** The app labels them. Values read
  from the volumes alone are marked *FRUS text*. Values joined to other records, such as the National
  Archives catalog or the Office's people register, name the record. Values the app computes, such
  as the semantic map, are marked as the app's own and experimental.

---

## 6. Disclosure checklist, per asset

| Asset shows | It must carry | Where it is, as drafted |
|---|---|---|
| anything | *not an official product of the Office of the Historian or the U.S. Department of State* | frame 01's foot on every device; the preview's last card; every piece of copy |
| the map | *Layout preserves local similarity; distances between far regions are not meaningful.* and *Experimental* | the capture's own lines, kept whole by `keepFoot` |
| a region name | *This surface is experimental.* | the capture's orange line; the subline says Experimental |
| NARA data | *not affiliated with, endorsed by, or sponsored by the National Archives…* | frames 04 and 05's foot; the FAQ |
| meaning search | describe, never brand; *experimental* | frame 12's subline; §5.1's last paragraph |
| a count | only a §5-table figure | 553; 314,616; "about 317,000" with "about"; never "every" |
| the provenance lens | the plurality caption as the app prints it: 86 of 499, which `SemanticMapSurfaceTests.provenanceCaptionFiguresAreMeasured` recomputes from the bundled index | no frame uses the provenance lens, deliberately |
| the Office of the Historian, by name | the not-an-official-product sentence, in the same asset | §1a rule 4; every §5 piece that names the Office |
| a feature built on the editors' apparatus | the part it reads (source note, cross-reference, the people they tagged) and its layer: FRUS text, joined or computed | §1a's feature lines; frames 02, 04 and 06 |

---

## 7. Capture plan on build 50, in sittings

The conventions are `Docs/screenshots/README.md`'s (the demo status bar, the two local-only patches
for the sync banner and CloudKit, the isolated Mac copy, windows captured one at a time) and the
sitting shape is `Planning/Capture-Runbook.md`'s. This list is only what the frames need beyond the
manuals' sweep.

**Sitting 1 — iPhone 17 Pro Max simulator, iOS 27, portrait, full corpus (new).** Frames 01, 02, 03,
and the iPhone preview pass B. Also take 04 (Source Explorer) and 11 (Chronology) in case the owner
wants a longer iPhone set. The iPhone's Search shows the facet sheet modally; capture the results
list with the sheet closed and a second frame with it open.

**Sitting 2 — iPad Pro 13-inch (M5) simulator, iOS 27, landscape, full corpus.** Re-shoot 01, 02, 10,
11 and 12 with the demo status bar (the build-47 ones carry the owner's); re-shoot 05, 06 and 14
(stale); and take the two frames with no capture, **07 (the Cite sheet)** and **13 (Person Analytics
Network)**. Then the iPad preview pass B, and recordings R and T.

**Sitting 3 — erased iPad simulator.** The preview's pass A (splash, onboarding), holding for the
LensChip. Confirm the splash renders on this build before recording (the plan §2(a2) history).

**Sitting 4 — the Mac, isolated copy.** Re-shoot 05, 06, 08, 11 and 13 (stale); take **07 (the Cite
popover)** and **12 (the Search window in Meaning mode)**, which need the encoder downloaded in the
copy; then recording A, and the Mac preview.

**After the sittings.** Run `SCALE=1 OUT_DIR=~/Desktop/store python3 tools/marketing/compose.py`
for the store-size frames, re-run the drafts into `Planning/marketing-drafts/`, and record the build
number of the capture run in `Docs/screenshots/README.md`'s ledger, as the X-8 rule asks. *Run on
2026-10-21 in S5, the plan of record's embed pass: 34 frames at the presets' sizes, 14 iPad, 14 Mac
and 6 iPhone, each stamped with build 1861; the ledger's S5 entry has the run.*

---

## 8. Decisions for the owner

1. **The ten.** Keep the listing's ten as §3 names them, or trade `teachers-10` for `researchers-06`?
   Recommendation: keep; the analytics frame reads on a phone-sized thumbnail and the graph does not.
   *Answered 2026-10-15: trade. `researchers-06`, the cross-reference graph, takes the tenth slot and
   `teachers-10` goes to the landing page (§3 is updated; `Plan-Of-Record-2026-10-14.md` decision 32).*
2. **Landscape iPad frames.** Every iPad capture is landscape and the app's two-pane layouts are its
   iPad story; if App Store Connect's 13-inch slot takes landscape, keep it. Otherwise the iPad set
   is re-shot portrait, and frames 02 and 08 lose their second pane.
   *Answered 2026-10-15: landscape, once the upload page confirms the slot takes 2752 × 2064 (decision 33).*
3. **Price and territories.** The copy says "free" and "English only"; both are owner facts to confirm
   before any of §5 ships.
   *Answered 2026-10-15: free, in every storefront, English only (decision 31).*
4. **The README hero row.** Three slots today: `macos/search`, `macos/cross-reference-graph`,
   `ipad/semantic-map`. Swap the graph (stale, and the least legible of the three at README width) for
   `ipad/source-explorer`, which carries the claim no competitor can make.
   *Answered 2026-10-15: swap, in the plan's §6a S5 (decision 34).*
5. **Whether to add this file to the plan of record.** *Answered 2026-10-14: `Plan-Of-Record-2026-10-14.md` §2 names this file and folds its four sittings into the manuals' capture sessions on build 51 (its §6a and §6c).* `Plan-Of-Record-2026-10-11.md` (now in `Completed/`) §3 listed the
   marketing items under *App Store Connect and marketing*; one bullet pointing here keeps the two in
   step. Not done in this pass, because that file's §7 line is checked against
   `Visual-Marketing-Plan.md` by `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan`
   and the edit is better made in the pass that strikes a step.

---

## 9. Where every number here comes from

| Figure | Value | Source |
|---|---|---|
| Volumes | 553 | `Store-Listing-Draft.md` §5, `manifest.json` entry count |
| Published since | 1861 | same, earliest `publicationDate` |
| Documents on the map | 314,616 | same, `semantic-vectors-index.json` |
| Regions | 140 | same, `semantic-map-index.json`, re-read 2026-10-15 after B4 (172 under the earlier layout) |
| Documents in a full index | about 317,000 (316,814 by replica) | same; the device count is owed to the release census |
| Corpus size | ≈ 3.3 GB of volumes; index ≈ 2.8× | the onboarding sheet (`ipad/onboarding-volumes.png`) and the iOS manual §2.3 |
| Latest coverage | 1981–1988 vol. XVI | the build-50 TestFlight notes |
| Provenance lens plurality | 86 of 499 | the shipped caption (`SemanticMapLens.swift`), recomputed from `source-provenance-index.json` by `SemanticMapSurfaceTests.provenanceCaptionFiguresAreMeasured`; it was 75 before #1543 added the Subject-Numeric category |
| Source notes paired with a document | 264,598, in 502 of 553 volumes | `collection-usage-index.json`, `coverage` |
| Cross-volume citations | 8,637, into 5,747 documents from 185 volumes | `resolved-edge-index.json`, `coverage`: 77,866 document edges less 69,229 within a volume |
| Volumes naming no editor | 81, all published 1861–1922 | `manifest.json`, an empty `editors` list |
