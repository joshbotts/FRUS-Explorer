# Launch marketing kit — the first public release

**Status:** DRAFT, 2026-10-13. Written against `v2` @ `0fe15702` (build 50 tagged). Nothing here is
published. It is the drafting pass for `Visual-Marketing-Plan.md` §7's open steps 10 (the capture
sessions, store frames as a separate pass), 12 (the App Preview) and 15 (composed hero and captioned
frames), and it rides on `Store-Listing-Draft.md`, which stays the copy of record for the App Store
Connect fields. Where the two differ on a field, the store draft wins until the owner reconciles them.

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
   map, 172 regions, about 317,000 documents in a full index (316,814 by the parser's replica; a device
   count is owed to the release census). "Every document" is never said.
2. **Caveats travel in the pixels.** A frame that shows the map shows the app's own caveat line; one
   that names a region keeps *Experimental* in view; one that shows NARA data carries the NARA
   sentence; the first frame of every set carries the not-an-official-product sentence.
3. **Describe, never brand.** The optional meaning search is "an optional language model that runs
   on your device"; in the description, "Google's EmbeddingGemma model" is the one permitted form.
   Nothing says "AI-powered".

---

## 1. Positioning

**One line.** *The U.S. diplomatic record, on your device, with the tools a 553-volume corpus needs.*

**The pitch (boilerplate, 98 words).**

> FRUS Explorer is a research tool for the *Foreign Relations of the United States* series, the
> State Department's official documentary record of American foreign policy, published since 1861.
> It downloads the Office of the Historian's own TEI editions, indexes them on your iPhone, iPad or
> Mac, and works offline from then on: full-text search, a reader that keeps the editors' apparatus,
> source notes resolved to the shelf, collections and course readers, and analytics across the whole
> series. It is an independent project, not an official product of the Office of the Historian or
> the U.S. Department of State.

**Three proof points, each with its screen.**

| Claim | The screen that proves it | Why it is the claim |
|---|---|---|
| **Offline, whole-series search with facets.** 553 volumes; phrases, proximity and exact words; facets by year, volume, person, document type, provenance and subject. | Search with the Facets inspector open (`macos/search.png`) | history.state.gov searches one volume at a time and shows no facets. This is the daily-use difference. |
| **The editors' apparatus, kept.** Footnotes, cross-references, person links and source notes live; a source note resolved to record group, entry, lot and repository. | The reader with the Research rail; Source Explorer (`ipad/source-explorer.png`) | Nothing else turns a FRUS footnote into a pull slip. |
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
`researchers-04`, `researchers-05`, `teachers-08`, `teachers-09`, `analysts-11`, `analysts-12` and
`teachers-10`. The other four (`researchers-06`, `researchers-07`, `analysts-13`, `analysts-14`) are
for the landing page and the audience posts, where a set can be shown whole.

The spec is `tools/marketing/shots.json`; `tools/marketing/compose.py` renders it (its README has the
commands); the drafts are in `Planning/marketing-drafts/`, with one contact sheet per audience.

| # | Headline | Subline (as drafted) | iPad capture | Mac capture | iPhone |
|---|---|---|---|---|---|
| 01 | Search 553 volumes of the U.S. diplomatic record. Offline. | Full-text search with phrases, proximity and exact words, faceted by year, volume, person, document type and subject. | `ipad/search-results` (build 47, owner's device: re-shoot with the demo status bar) | `macos/search` | **none** |
| 02 | Read it as printed. Keep what you find. | Documents rendered from the original TEI with footnotes and cross-references live, and a research rail beside the text… | `ipad/research-rail` (build 47) | `macos/research-strip` | **none** |
| 03 | See the whole series at once. | 314,616 documents placed by the language they share… Experimental. | `ipad/semantic-map` | `macos/semantic-map` | **none** |
| 04 | From footnote to shelf. | Every source note resolved as far as the bundled reference data reaches… No network, no API key. | `ipad/source-explorer` | `macos/source-explorer` | — |
| 05 | Plan the trip before you book it. | An Archives Visit turns your documents into research targets… | `ipad/trip-packet` (packet lines changed, #1514/#1515) | `macos/trip-packet` (**stale**, #1444) | — |
| 06 | Follow what the editors cited. | The cross-reference graph around any document… | `ipad/cross-reference-graph` (**stale**, #1438/#1481) | `macos/cross-reference-graph` (**stale**, #1438) | — |
| 07 | Cite as you write. | The Department's recommended citation, BibTeX, RIS, or straight into your own Zotero library… | **none** | **none** | — |
| 08 | Build a course reader in an afternoon. | Section the collection by week, excerpt the passages… apply the Teaching reader preset, export PDF or Word. | `ipad/collections-editor` | `macos/collections` (**stale**, #1446) | — |
| 09 | Lecture material before a single download. | How late the official record runs against the law that governs it, and three more dashboards… | `ipad/series-production` | `macos/series-production` | — |
| 10 | Why raw counts mislead, shown live. | Chart a term by year, switch to share of documents, and tap into the documents behind the spike… | `ipad/analytics` (build 47) | `macos/analytics` | — |
| 11 | A crisis, day by day, across every volume. | Chronology lays out every dated document in a window you set… | `ipad/chronology` (build 47) | `macos/chronology` (**stale**, #1387/#1400) | — |
| 12 | Ask a question, not a keyword. | Search by meaning ranks the whole series by what you asked, with an optional language model that runs on your device… Experimental. | `ipad/semantic-search` (build 47) | **none** | — |
| 13 | Who the record orbits. | Person Analytics around any name… | **none** | `macos/person-analytics-network` (**stale**, #1370/#1441) | — |
| 14 | How the archive itself changed. | Which collections each era's editors drew on… | `ipad/archival-analytics` (counts predate #1514) | `macos/archival-analytics` (same) | — |

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
drafts render them as placeholders carrying the route to capture.

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

### 5.1 Announcement post (for the README, a blog, or a newsletter; 346 words)

> **FRUS Explorer, first public release**
>
> *Foreign Relations of the United States* is the State Department's official documentary record of
> American foreign policy: 553 volumes published since 1861, declassified cables, memoranda, minutes
> and intelligence estimates, every one of them in the public domain. FRUS Explorer is a free,
> independent research tool that puts that series on your iPhone, iPad or Mac and builds a workbench
> around it. It is not an official product of the Office of the Historian or the U.S. Department of
> State.
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

### 5.2 Listserv note (H-Diplo, SHAFR members, a departmental list; 142 words)

> Colleagues: I have released FRUS Explorer, a free iPhone, iPad and Mac app for working with the
> *Foreign Relations of the United States* series offline. It downloads the Office of the Historian's
> TEI editions, indexes them on the device, and adds full-text search with facets, a reader that keeps
> the editorial apparatus, source notes resolved to record group and lot file, an archives-visit
> packet, collections that export as course readers or Zotero records, and series-wide analytics,
> including a map of 314,616 documents by the language they share. It is an independent project, not
> an official product of the Office of the Historian or the Department of State; the series itself is
> public domain and the code is open source. Manuals and the download are at [link]. I would be
> grateful for bug reports and, especially, for the questions it cannot yet answer.

### 5.3 Social posts (each under 300 characters)

1. *FRUS Explorer is out: 553 volumes of the U.S. diplomatic record on your iPhone, iPad or Mac,
   searchable offline, with the editors' footnotes and source notes kept. Independent, free, open
   source. Not an official product of the Office of the Historian. [link]*
2. *Every FRUS source note, resolved: record group, entry, lot file, repository. Then an Archives
   Visit packet with the lines reading-room staff ask you to quote. [frame 04 or 05]*
3. *A map of 314,616 FRUS documents placed by the language they share, named by the words that set
   each region apart. Experimental, and the layout's own caveat is on the screen. [frame 03]*

### 5.4 One-line press description (under 200 characters)

> FRUS Explorer: an independent, offline research app for the *Foreign Relations of the United
> States* series, on iPhone, iPad and Mac. Free; the series is public domain.

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
| the provenance lens | the plurality caption, which is owed a correction (75 of 499) before any asset quotes it | no frame uses the provenance lens, deliberately |

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
number of the capture run in `Docs/screenshots/README.md`'s ledger, as the X-8 rule asks.

---

## 8. Decisions for the owner

1. **The ten.** Keep the listing's ten as §3 names them, or trade `teachers-10` for `researchers-06`?
   Recommendation: keep; the analytics frame reads on a phone-sized thumbnail and the graph does not.
2. **Landscape iPad frames.** Every iPad capture is landscape and the app's two-pane layouts are its
   iPad story; if App Store Connect's 13-inch slot takes landscape, keep it. Otherwise the iPad set
   is re-shot portrait, and frames 02 and 08 lose their second pane.
3. **Price and territories.** The copy says "free" and "English only"; both are owner facts to confirm
   before any of §5 ships.
4. **The README hero row.** Three slots today: `macos/search`, `macos/cross-reference-graph`,
   `ipad/semantic-map`. Swap the graph (stale, and the least legible of the three at README width) for
   `ipad/source-explorer`, which carries the claim no competitor can make.
5. **Whether to add this file to the plan of record.** `Plan-Of-Record-2026-10-11.md` §3 lists the
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
| Regions | 172 | same, `semantic-map-index.json` |
| Documents in a full index | about 317,000 (316,814 by replica) | same; the device count is owed to the release census |
| Corpus size | ≈ 3.3 GB of volumes; index ≈ 2.8× | the onboarding sheet (`ipad/onboarding-volumes.png`) and the iOS manual §2.3 |
| Latest coverage | 1981–1988 vol. XVI | the build-50 TestFlight notes |
| Provenance lens plurality | 75 of 499 | the visual-marketing plan §5, recomputed 2026-10-01; the shipped caption still says 73 |
