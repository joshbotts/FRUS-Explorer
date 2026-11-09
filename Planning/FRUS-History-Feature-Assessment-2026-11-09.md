# What the history of the series asks of the app — an assessment from *Toward "Thorough, Accurate, and Reliable"* (2026-11-09)

**Source read:** William B. McAllister, Joshua Botts, Peter Cozzens and Aaron W. Marrs, *Toward "Thorough, Accurate, and Reliable": A History of the Foreign Relations of the United States Series* (Office of the Historian, 2015), the EPUB of 24 March 2015: all twelve chapters, the introduction and conclusion, the terms, the stages of a volume's creation, and appendices A to D. About 186,000 words.

**Compared against:** the Research Guide's eleven pages (`Docs/EditableContent/02-Research-Guide.md`), the four About the Series dashboards, the Browse axes (`Docs/iOS-User-Manual.md` §6), the Editors' Annotations design (`Planning/Editors-Annotations-Design-2026-11-06.md`), Source Explorer, the bundled manifest (553 volumes), the live plan of record (`Plan-Of-Record-2026-10-21.md`) and the five open issues (#1854, #1835, #1723, #1696, #234). Two claims below were checked against the TEI itself (`frus1861`, `frus1887`, `frus1932v01` from HistoryAtState/frus, fetched 2026-11-09).

**Question asked:** which features or functionality, beyond what the app has, would let a reader exploit the series fully and responsibly.

**Status:** an assessment for the owner. It proposes; it changes no code. Everything here is a candidate for the plan that follows 1.0, and none of it touches the submission gate.

---

## 0. The answer in one page

The history's thesis is that every volume is a **tree ring**: it records not only the diplomacy it documents but the transparency regime that produced it — who selected, who cleared, under what rules, how long after the events, with what consent from other governments and agencies, and what was left out and whether the omission was marked (Conclusion). The app already reads the series as *documents* very well, and it reads the *editors' layer* (source notes, cross-references, annotations) better than any other tool. What it does not yet read is the **production layer**: the regime under which each volume was made. That is where the gaps are, and almost every gap is a "responsible use" gap, because a reader who does not know a volume's regime over-reads its silences.

Nine recommendations carry most of the value. Four need no new data:

1. **A clearance-regime badge on every volume, keyed to its publication year** (§2.1). Five regimes: Contemporaneous (to 1905), the lag years (1906–1924), the Kellogg Order (1925–1979), the re-review and CDC years (1980–1991), the statute (1992–). The manifest already holds a publication year for all 553 volumes: 71, 13, 205, 69 and 195 volumes fall in the five bands. The badge is the single cheapest thing that changes how a reader weighs a volume.
2. **"Supplemented by / supplements" as a relation in the catalogue** (§2.3), replacing the hard-coded `isRetrospective` id test. Iran 1951–1954 (1989) is answered by the 2017 retrospective; American Republics 1952–1954 (1983) by Guatemala (2003); Congo Crisis 1961–1963 (1994) by Congo 1960–1968 (2013); the Kennedy-era Japan volume (1996) by document 1 of 1964–1968 vol. XXIX pt. 2 (2006). Five digitised microfiche supplements are already in the manifest as volumes but are not tied to the printed volumes they extend.
3. **Count marked omissions in every era, not only after 1991** (§2.4). The TEI carries them: `frus1861` has 212 asterisk-run markers and `frus1887` 254; `frus1932v01` has 112 ". . ." ellipses and 3 `<gap>` elements. The Editors' Annotations axis counts only the post-1991 "not declassified" form.
4. **Correct one shipped claim** (§1). The Research Guide and the Annotations axis say volumes published before the 1925 order did not mark omissions. The history says they did, with asterisks (ch. 2, ch. 4), and the TEI confirms it.

Five need new bundled data, each a small generator in the pattern the repository already uses:

5. **The Supplemental FRUS Submissions index** (§3.1): appendix C's roughly 160 congressional documents of 1869–1914, more than 16,000 pages the annual volumes deliberately did not reprint. Without it, a 19th-century year's annual volume looks like the whole release when it was not.
6. **A per-volume "known gaps" layer with three labelled sources** (§3.2): the volume's own preface sentences, the Historical Advisory Committee's public reports and minutes for the publication year, and a curated, cited set of the withholdings this history documents.
7. **An era-keyed explainer attached to omission markers** (§4.2): why a gap is there depends on when the volume was published, from Randolph's 1794 categories to the Kellogg Order's five, the CIA's "no official acknowledgment" doctrine, and the statute's four exemptions.
8. **A "companion official publications" shelf** (§3.3): the Serial Set, the White Papers, *Peace and War*, *Nazi-Soviet Relations*, *American Foreign Policy: Current Documents*, the CIA's own releases — the channels the government used beside or instead of FRUS.
9. **Two series-analytics charts the history calls for** (§5): the series' *size and selectivity* over time (absolute pages and documents per covered year), and the *genre mix* that shows the turn from documenting diplomacy to documenting policymaking.

Everything else in this document is either a smaller addition (§2.2, §2.5, §3.4, §4), an analytics idea (§5), or something considered and set aside (§6).

---

## 1. A correction before the features

Two shipped texts say the same thing:

- Research Guide, page 3 (*Excisions and Redactions*): "Before Secretary of State Frank Kellogg's 1925 order, FRUS editors did not mark excisions or redactions."
- Editors' Annotations axis, the excisions explainer in `FRUSExplorer/Browser/AnnotationsAxis.swift` (the localized string at line 269): "Volumes published before the 1925 order did not mark omissions at all."

The history says otherwise. On the Civil War volumes: "Printed in an era before federal law or departmental directive indicated how the public should be informed of excisions, the volumes feature lines of asterisks to indicate excised material" (ch. 2, *Excisions, Excisions*). On the Contemporaneous series generally: "When they did excise documents, compilers and reviewers took great care to identify the lacunae with ellipses, asterisks, dashes, or similar markings" (ch. 4, *FRUS at War: The 1898 Volume*). What the 1925 order added was a *formal policy* and a *uniform* mark (the ellipsis), not the first marking.

The TEI agrees. `frus1861.xml` carries 212 runs of asterisks, most as centred paragraphs (`<p rend="center">* * * * * * * * * *</p>`) and some inline at the end of a sentence; `frus1887.xml` carries 254. Neither uses an ellipsis or a `<gap>`. `frus1932v01.xml` (published 1948) carries no asterisk runs, 112 spaced ellipses, 15 ellipsis characters and 3 `<gap>` elements. Three volumes are a sample, not a census; §2.4 proposes the census.

Both texts should be re-worded. The accurate statement is three-part: before 1925 an omission was usually marked with a row of asterisks, under no written rule and without saying whether the cut was the editor's or a reviewer's; from 1925 to 1991 an ellipsis marked an omission of either kind; since 1991 a declassification denial is marked as such and distinguished from the editors' own cuts. Page 3 of the Research Guide is a ranged block in `02-Research-Guide.md`, so `EditableContentKeyTests` governs the edit; the axis string is a plain localized key.

---

## 2. Features that need no new data

### 2.1 A clearance-regime badge, keyed to the publication year

**What it is.** One line on the volume page, the catalogue row and the Series Analytics tooltips: the regime the volume was cleared and published under, derived from `publicationDate`, with a tap-through to a one-screen explainer. The regimes, as the history periodises them:

| Published | Regime | What a reader should know (all from the history) |
|---|---|---|
| 1861–1905 | **Contemporaneous** (chs. 2–4) | Published within about 18 months of the events, often sooner. Selected by Diplomatic Bureau clerks and redacted by the Second Assistant Secretary (Hunter 1866–86, Adee 1886–1924) with no written criteria; ongoing negotiations and despatches marked "personal" or "private" were left out; no foreign government's consent was sought (Frelinghuysen, 1883). Omissions marked with asterisks. The annual volume was never the whole release: Congress received and printed the Supplemental Submissions beside it (§3.1). The 1887 audit found about 11 percent of the year's despatches printed and only 36 omitted that might have merited inclusion (ch. 4). |
| 1906–1924 | **The lag years** (ch. 5) | The same editorial regime, delayed by printing appropriations, a 1910 GPO price rise and the war, not by a policy of secrecy; the 1906 volumes appeared in 1909 and the series never again appeared within a year. Little on the war is in the 1914–1918 annual volumes; it went to the supplements of 1928–1933 and the Lansing Papers (1940). |
| 1925–1979 | **The Kellogg Order** (chs. 6–8) | "Substantially complete as regards the files of the Department"; five grounds for omission (§4.2); foreign-origin documents need that government's consent; an ellipsis marks an omission of either kind. Clearance by the desk officers of the geographic bureaus until 1980; other agencies' equities from the Yalta volume (1955), the CIA's from 1960. Until the 1970s the documentary base is the State central files and lot files; presidential-library research is systematic only from the mid-1970s. Covert action is excluded by policy, not by accident (Franklin to the HAC, 1973). |
| 1980–1991 | **Re-review and the CDC** (chs. 9–10) | The Classification/Declassification Center re-reviewed every cleared compilation in 1980; from 1981 United States documents containing British, Canadian, Australian or New Zealand information were consulted abroad before release; the geographic Assistant Secretary decided appeals; the Office stopped compiling for more than a year and then triaged volumes "with a reasonable assurance of clearance"; from 1986 page limits forced "decompilation" of cleared manuscripts, with the overflow meant for microfiche. The history calls these volumes "translucent". Two of them were later answered by retrospectives (§2.3). |
| 1992– | **The statute** (chs. 11–12) | "Thorough, accurate, and reliable"; the Advisory Committee with access to what was withheld; denials marked as such and whole withheld documents listed; disclaimers in prefaces 1991–1996; the High Level Panel from 1998 for acknowledging covert actions, which acknowledges more than it documents. Volumes compiled before the statute and published after it may carry a preface statement saying so. |

**Why it matters for responsible use.** The regime is the *publication* year's, not the coverage year's. A reader of 1952–1954 Iran has two volumes with the same coverage and opposite regimes, 1989 and 2017; the badge is what tells them apart at a glance. Searching "Guatemala 1954" across the library today returns documents from the 1983 volume and the 2003 retrospective side by side with nothing to say which is which.

**Cost.** Derivation is a pure function of the publication year, already parsed by `FRUSVolumeMetadata.firstYear(in:)`. The explainer is copy (nine strings and a short page), which goes through `Docs/EditableContent/` in the usual way. The existing `AnnotationEra` bands are keyed to the *subseries' first year*, so they describe what the editors annotated by coverage era; the regime badge is a different axis and should not reuse them.

### 2.2 Lag at publication, against the norm of its day, on the volume page

The Production & Timeliness dashboard already draws the lag and a step target (15 years from the 1961 directive, 20 from 1972, 30 from 1985 and the statute). Two small additions:

- Put the figure on the volume page: "Published 1983, 29 years after its latest document. The target in force was 20 years." It is the dashboard's own arithmetic, localised to the volume a reader is holding.
- Extend the target line backward as an *expectation*, drawn differently from the directives: about a year to 1905 (the norm both branches honoured without a rule, ch. 5), then a drifting expectation that the history dates — two years conceded in 1914, three (Hunt, 1922), four (Dennett, 1926), fifteen by the mid-1930s, eighteen to twenty by the 1950s — before Kennedy's 1961 directive. Appendix A charts the same thing; the dashboard's caption could cite it.

### 2.3 "Supplemented by" and "supplements" as a catalogue relation

`VolumeAnnotations.isRetrospective(volumeId:)` is a test on four id fragments (`PubDip`, `Intel`, `Iran`, `Guat`). The history gives the relation that test is standing in for, and the manifest already holds both ends of each pair:

| Original volume | What the history says of it | Answered by |
|---|---|---|
| `frus1952-54v10` Iran, 1951–1954 (1989) | Compiled 1976; the CDC's 1984 review denied 28 documents and excised 83, most on British information; no disclaimer; the Committee's reviewer called it "something like fraud" (ch. 10) | `frus1951-54Iran` (2017) and `frus1951-54IranEd2` (2018) |
| `frus1952-54v04` American Republics (1983) | The CIA's and the Defense Department's role in Guatemala omitted; the expanded introduction's disclaimer that the editors "did not and could not … document systematically" the military and intelligence dimensions (ch. 9) | `frus1952-54Guat` (2003) |
| `frus1961-63v20` Congo Crisis (1994) | Compiled without full access to CIA records; criticised in 1995–1996 as "a misleading account" (ch. 12) | `frus1964-68v23` Congo, 1960–1968 (2013) — a pairing read off the manifest's titles; the history closes in 2002 and does not name it |
| `frus1961-63v22` Northeast Asia (1996) | The Kennedy-era covert operation in Japan, which the interagency panel declined to release in 1995 (ch. 12) | `frus1964-68v29p2` document 1 (2006), where it is acknowledged (ch. 12, n. 4) |
| the 1955–1957, 1958–1960 and 1961–1963 printed volumes with microfiche supplements | Printed selection constrained by the 1986–1988 page limits; the supplements carry the overflow (ch. 10) | the five `…mSupp` volumes already in the manifest (1986, 1991, 1997, 1998, 2021) |
| the 1945–1950 and 1950–1955 subseries | Intelligence documentation excluded by policy at the time (ch. 8) | `frus1945-50Intel` (1996), `frus1950-55Intel` (2007) |

**What the reader sees.** On the original: "Supplemented by *Guatemala* (2003), compiled with CIA records this volume could not use." On the retrospective: "Supplements *The American Republics, Volume IV* (1983)." In search results and facets, a document from the original carries the same one-line pointer. The relation also lets Browse by year and country answer "what covers Guatemala in 1954?" with both volumes and the order to read them in.

**Cost.** A `supplements` field (or a small sidecar JSON with a provenance row in `BundledArtifactProvenance.table`) carrying pairs, a one-line reason and a citation; `ManifestGenerator` has an offline overlay for exactly this kind of curated fact. The owner confirms the pairs; the table above is the history's, not a census of the 553.

### 2.4 Count marked omissions in every era

The Editors' Annotations axis has an `excisions` category that counts documents marking "not declassified", the post-1991 form, and its explainer says the earlier forms "cannot be told from the editors' omissions and are not counted here." That is right about *attribution* and wrong as a reason not to *count*. Three vocabularies, each a count of documents and of marks:

- **1861–1924: asterisk runs.** A paragraph of asterisks (`<p rend="center">* * *…</p>`) or a run at the end of a sentence. 212 in `frus1861`, 254 in `frus1887`.
- **1925–1991: ellipses and gaps.** ". . .", "…" and `<gap>`. 112, 15 and 3 in `frus1932v01`. An ellipsis inside a quoted passage is the author's, not the editor's; the serializer already distinguishes editorial from quoted matter well enough for the count to be labelled "marks that may be omissions", and a per-volume figure is still a floor a reader can use.
- **1992–: declassification marks.** As now, plus whole withheld documents listed in place.

**What it enables.** A "documents with marked omissions" facet and search filter; a per-volume omission density on the volume page beside the regime badge; a Series Analytics chart of marked omissions per thousand documents by publication year, which would be the first measurement of the 1980s "translucency" the history describes and of the statute's effect after it. The label must say what each era's mark can and cannot mean (§1).

**Cost.** A category or three in `AnnotationCategory`, a pass in `VolumeAnnotationsIndexGenerator`, and a regeneration of `volume-annotations-index.json` (it is regenerated with every index bump; the design memo's §4 sets thresholds in the kit, so the figures can ship before the thresholds are settled). `swift test` and the unit target after the JSON refresh, as `CLAUDE.md` requires.

### 2.5 The volume's arrangement scheme as a fact

The *Stages* essay and chapters 3, 4, 6 and 8 give the schemes the series has used: chapters by country (1861–1893), grouping by subject (from 1894), the annual volume to 1951, triennial compilations from 1952–1954 (adopted 1974–1976 over the Committee's objection), subseries by administration from 1961–1963 (formally from the Johnson subseries), special subseries (the war supplements, the Russia volumes, the Lansing Papers, Paris 1919, the wartime conferences), microfiche supplements and the late retrospectives. Browse's hierarchy shows a volume's divisions; it does not say which scheme they follow or why a topic a reader expects in one place sits in another ("Barbary States" rather than "Turkish Empire" in 1874, ch. 4). A scheme label on the volume page, derived from the TEI's chapter structure where it can be and curated where it cannot, closes that.

---

## 3. Features that need new bundled data

### 3.1 The Supplemental FRUS Submissions index (appendix C)

**The fact.** From 1868 to 1914 the Department sent Congress, on request, more than 16,000 pages of diplomatic correspondence that Congress printed as Senate and House Executive Documents — "the equivalent of roughly 20 additional Foreign Relations volumes" (ch. 4). The annual volumes *rarely reprinted* them, so the absence of Samoa from the 1887 volume, or of nearly 200 Cuba documents from the 1870 volume, is not a silence: the documents are in the Serial Set. Appendix C lists each submission with its year, subject, Congress and session, document number, Serial Set number, document count, page count and a one-line summary: about 160 entries, 1869–1914.

**What the app would do with it.** A bundled `supplemental-submissions-index.json` and:

- on every volume page from 1869 to 1914, a section "Also transmitted to Congress for this year, not reprinted here", listing the submissions with their Serial Set numbers;
- in the Browse year and country views for that period, the same rows beside the annual volume, with the tags the taxonomy already uses (Cuba, Samoa, Chile…);
- in Search, when a 19th-century date range or country filter returns little, an empty-state line naming the submissions for that year and subject;
- an outlink per entry to the Serial Set on GovInfo or HathiTrust where a stable address exists, and the citation form otherwise.

**Responsible-use point.** The Research Guide's page 2 says the 19th-century volumes were an instrument of public affairs; this index is what lets a reader *do* something with that: look where the rest of the release went.

**Cost.** Appendix C is a regular list; a Python tool under `tools/` in the stdlib-only pattern parses it once, and the result is small. A row in `BundledArtifactProvenance.table`, a `Generators-Runbook.md` entry, and the public-domain status of the source (an Office of the Historian publication) recorded there.

### 3.2 A per-volume "known gaps" layer, three sources, each labelled

The history's recurring lesson is that the series' reputation suffered "primarily from failures of the series to document significant historical events or acknowledge past actions" (Conclusion), and its recurring remedy, from Kane's 1981 memo to the Committee's 1988 report and the 1990 action plan, is *telling the reader*. The volumes themselves began doing so unevenly: the Guatemala-era disclaimer of 1983, the expanded prefaces of 1990, the Committee's disclaimers of 1991–1996. The app can gather what exists into one place on the volume page, with each statement attributed:

1. **The volume's own words.** The TEI preface and introduction (`<div type="preface">`, already parsed as a structural section) carry the editorial-principles paragraph (the 1932 preface, published 1948, restates the Kellogg principles as Department Regulation 297.1 of 1947), the "necessary security considerations" sentence, the 1983 Guatemala disclaimer, and from the 1990s the declassification paragraph ("…resulted in the decision to withhold N documents in full, excise portions of M…"). A pass that extracts the sentences containing *withheld*, *excised*, *denied*, *declassification review*, *could not* and *security* and shows them verbatim under "The editors say" needs no judgement and no new source. 19th-century volumes have no preface; the badge (§2.1) does their explaining.
2. **The Advisory Committee's public record.** The Committee has reported annually since 1958 and its reports and meeting minutes are public (history.state.gov/about/hac; the history's ch. 12, n. 1 names both). For a volume published in year Y, a link to the Committee's report for Y and Y+1 is the oversight record of the clearance period it came out of. Link, do not bundle; the Office hosts them.
3. **What this history documents.** A curated, cited set of specific withholdings and delays, each with a chapter reference and one sentence of fact, shown under "The Office's history of the series records". Candidates the history names: no Iran documentation in the 1922 volume (ch. 6); the 1941 Far East volume held 1956–1962 over Thai reports (ch. 8); the 1943 China volume held to 1962, 1946 China held at the NSC ahead of Nixon's opening to China, 1949 China delayed 1972–1977 (ch. 8); the 1948 French reservations on West German independence refused in 1970, the British Persian Gulf refusal of 1972, the Italian election operation withheld (ch. 8); the 1951 European Security volume's Greece, Turkey and Yugoslavia material and the 1949–1950 Yugoslavia delay (ch. 9); American Republics 1952–1954 and Iran 1951–1954 (chs. 9–10); Japan 1958–1960's nuclear and status-of-forces material, which the Committee accepted as legitimately withheld, and Italy 1955–1957 and Indonesia 1958–1960, whose excisions it did not (ch. 11); Indonesia 1958–1960 as the first volume to include a covert operation, with its details withheld (ch. 12).

**Where it shows.** The volume page; and, because a reader meets silence in Search before in Browse, a one-line banner on empty or thin results whose filters match a volume with a recorded gap ("No documents on the CIA in Guatemala, 1954: the 1983 volume omitted them; the 2003 retrospective has them.").

**The constraint.** The README says the app's commentary "is about research method and makes no interpretive claims about the history of U.S. foreign policy." Source 3 stays inside that line only if every entry is a statement about *the series* (what a volume contains, when it was cleared, what its editors or the Committee said), attributed to the Office's own history or to the volume, and never a statement about the policy. The labelling is the feature.

### 3.3 A "companion official publications" shelf

The history shows the government publishing foreign-policy documents beside FRUS at every stage, sometimes to say what FRUS could not or would not: *American State Papers* and the Serial Set before 1861 (ch. 1); the Supplemental Submissions (ch. 4); *Peace and War: United States Foreign Policy, 1931–1941* (1943), a wartime compilation "purporting to cover it all" (ch. 6); *Nazi-Soviet Relations, 1939–1941* (1948) and the China White Paper (1949) (ch. 7); the *Department of State Bulletin* and *American Foreign Policy: Current Documents*, revived in 1981 to "compensate" for the lag (ch. 9); the microfiche supplements (ch. 10); the CIA's own releases on Guatemala, the Bay of Pigs and the Cuban Missile Crisis in the 1990s (ch. 12); the Soviet minutes of Tehran, Yalta and Potsdam (ch. 7, n. 20). A short bundled list — title, years covered, publisher, what it is, why it exists, a stable link — surfaced by period from the About the Series pages and from the volume page's regime explainer. Outlinks only; the app bundles none of their text.

### 3.4 Microfiche supplements and the volumes they extend

Five digitised supplements are already catalogue volumes (1955–57 vol. III, 1958–60 vols. III and V, 1961–63 vols. VII–IX and X–XII). The missing piece is the relation of §2.3 and one sentence on each printed volume of the 1955–1960 and 1961–1963 subseries that had a supplement: that its printed selection was made under the 1986–1988 page limits, that a supplement of N documents accompanies it, and whether the Office has digitised it. The history's ch. 10 gives the mechanism ("each additional page above 800 … has a dollar cost"; "decompile").

---

## 4. Guidance and copy

### 4.1 The correction (§1), and two sentences the Research Guide should carry

Page 2 covers the eras well. Three facts from the history would sharpen it without lengthening it much:

- **The tree ring.** "Each volume records the transparency regime that produced it as surely as the diplomacy it documents" is the frame that makes the badge (§2.1) and the gaps layer (§3.2) intelligible, and the history's own (Conclusion).
- **FRUS gated the archives.** From the 1950s to the 1970s the Department opened its records at the National Archives only after the corresponding volume appeared, applied the volume's clearance decisions to the whole file, and let cleared scholars into "restricted" files with their notes reviewed (ch. 8). A reader of mid-century scholarship should know that what the series printed governed what anyone could see.
- **The 19th-century release was larger than the volume.** One sentence pointing at the Supplemental Submissions (§3.1).

### 4.2 An era-keyed explainer attached to omission markers

When a reader taps an asterisk row, an ellipsis or a "not declassified" mark, the reader page can say what that mark could mean in that volume's regime, from the history:

- **1794 onward.** Randolph's three categories — gossip and matter not germane, frank assessments that would expose a minister abroad, and the authors of information who "would be infallibly denounced" (ch. 1); in the Contemporaneous series also ongoing negotiations and "personal" despatches (chs. 3–4).
- **1925–1991.** The Kellogg Order's five grounds: to avoid embarrassing current negotiations; to condense the record; to preserve the confidence reposed by other governments and individuals; to suppress personal opinions (qualified: the choices before a major decision should be shown); to avoid needless offense to other nationalities or individuals — and the rule that a foreign-origin document needed its government's consent (ch. 6). Plus, from 1960, the CIA's doctrines: prior unofficial disclosure is no ground for release; a station or a liaison relationship is never confirmed; official publication is "the most solemn and incontrovertible of evidence" (chs. 8–9).
- **1992–.** The statute's four exemptions for the 30-year release of Department records — weapons systems, intelligence sources, demonstrable harm to current negotiations or activities or to national security, and privacy (ch. 11) — and the High Level Panel's distinction between acknowledging a covert action and releasing its documents (ch. 12).

### 4.3 "Absence is not evidence", and "no record was made"

Two rules the history makes concrete, for the Research Guide and for Search's empty state when the query is intelligence vocabulary and the matching volumes were published before 1992:

- Before the 1990s, covert action and the CIA's presence abroad were kept out of the series by policy (Franklin, 1973; the CIA's 1979–1980 letters; the Office's own 1980–1981 self-censorship), so a search that finds nothing has found the policy, not the past (chs. 8–9).
- Some records were never made: there are no minutes of the political discussions at the First Cairo Conference, and Roosevelt "was not in the habit of making memoranda of his conversation" (ch. 7). A conference volume that prints no memorandum of a conversation may be printing everything there is.

### 4.4 Credit the source

The explainers above quote the Office's own history, a public-domain federal publication the Office hosts chapter by chapter. The Research Guide links it once; the badge and the explainers should link the chapter they draw on, so a reader can check the app against its source.

---

## 5. Series Analytics the history calls for

- **Size and selectivity over time.** The *Terms* define the series' absolute size (pages for a period) and relative size (the share of the record published), and the history gives the only hard relative figure, the 1887 audit's 11 percent (ch. 4). The app can chart documents and printed pages per *covered* year by publication era, and the caption can carry the 1887 figure as the one known reference point. Appendix B's print runs (20,000 copies in 1862, 28,550 for the Lincoln volume, 500–600 for the Department by 1905) belong in that chart's "About these figures", not in a chart of their own.
- **Genre mix.** The history's central editorial shift is from documenting diplomacy (instructions, despatches, notes) to documenting policymaking (memoranda of conversation, NSC papers, telegrams, estimates), with international-law material falling away (ch. 8). Search already facets by document type; a series-wide chart of type shares by coverage decade would show the shift, and the regime badge explains it.
- **19th-century legation density.** The volumes to 1893 are organised by country chapter, and the press of the day read the silences — four short letters from Argentina in 1876, nothing on Chinese immigration in 1880 (ch. 4). A heatmap of documents per country chapter per year for the 52 volumes whose coverage ends by 1893, built from the TEI's chapter divisions, makes those silences visible and sends the reader to §3.1 for the rest of the release.
- **The documentary base, per volume.** The Archival Sourcing dashboard shows provenance categories over time for the series; the history's own figures (State records 64.7 percent of the Kennedy subseries, 53.2 of Johnson, 29.6 of Nixon–Ford; presidential libraries 25.5, 38.5 and 59.1; ch. 12, n. 13) show how much the base moves between neighbouring subseries. One line on the volume page — "Of this volume's documents, N percent come from State's central and lot files, M from the Eisenhower Library…" — localises a chart the app already computes.

---

## 6. Considered and set aside

- **Reception history.** The 19th-century volumes were reviewed and excerpted in newspapers, and the history mines that (chs. 2–4). A link into Chronicling America by publication date would be cheap but speculative, and the app would be curating press, not the series. Not recommended.
- **Production biographies.** The compilers, reviewers and office heads of each volume (appendix D lists the heads 1919–2014). The TEI title pages already give editors from the 1920s on, and the Editors axis indexes them; all 81 editorless volumes were published before 1925 (71 of them before 1906), and the badge covers them with Hunter and Adee by name. A timeline of office heads adds little a reader would use.
- **Anything that judges the policy.** Several of the history's episodes invite a sentence about Guatemala, Iran or Yalta themselves. The app's line, in the README and the About screen, is method only; §3.2's labelling rule keeps it.
- **Bundling the history's text.** It is public domain and would fit, but the Office hosts it; deep links (§4.4) do the work without a second copy to keep current.

---

## 7. Sequencing, and what each touches

Suggested order, by value against cost. None of this is for 1.0; all of it is candidates for the plan that follows.

1. **§1 correction** — two strings; `EditableContentKeyTests` for the Research Guide block. A day.
2. **§2.1 badge and §2.2 lag line** — a derivation in the kit (pure over `publicationDate`), copy for five explainers, volume-page and catalogue UI on both platforms. Mac-compiled, so the kit boundary tests and `swift test` run as usual.
3. **§2.3 and §3.4 relation** — a curated pair table, a manifest overlay or sidecar with its provenance row, the `isRetrospective` call sites moved to the relation. The owner confirms the pairs.
4. **§2.4 omission census** — generator pass, three categories, index JSON regenerated, thresholds in the kit, the axis explainer re-worded with §1.
5. **§3.1 Supplemental Submissions** — one stdlib Python parser of appendix C, one JSON, surfaces in Browse, the volume page and Search's empty state.
6. **§3.2 gaps layer** — preface extraction first (no curation), HAC links second, the cited set third, each shipping on its own.
7. **§4.2–4.3 explainers** — copy, through `Docs/EditableContent/`.
8. **§3.3 shelf and §5 charts** — when the above are in.

The mechanical gates that apply: a new bundled JSON needs its `BundledArtifactProvenance.table` row (`BundledArtifactProvenanceTests.everyArtifactIsTiered`) and a `Generators-Runbook.md` entry; any Research Guide edit re-points its ranged block; a refreshed `volume-annotations-index.json` owes `swift test` and the unit target; no `@Model` changes, so the CloudKit gate is untouched.

---

## Appendix. What each chapter contributed

- **Introduction, Terms, Stages.** "Responsible transparency" as the book's descriptive term; the 1980s as "translucent"; the eight stages of a volume (conceptualisation to publishing); size versus scope; the "principal year" convention for 19th-century titles (a volume for year Y runs from the previous November to about October).
- **Ch. 1 (1790–1860).** Congress's right to ask and the executive's "public interest" reservation; Randolph's 1794 excision categories; the Serial Set (1817–) and *American State Papers* as the pre-1861 record; the universe of records then much smaller — no memoranda of conversation, personal papers kept by officials.
- **Ch. 2 (1861–1868).** The first volume's 425 pages, country by country; excisions marked by rows of asterisks; what was cut from Adams's London despatches (arms procurement, sources, gossip, British opinion, Bull Run, criticism of the United States); print runs; the Lincoln assassination volume; the volumes as public affairs at home and abroad.
- **Ch. 3 (1868–1876).** No 1869 volume and a late 1868 one; Fish's attempt to discontinue the series and Congress's 1,015 pages of requests that revived it; the Marsh affair and Instruction No. 270, publication as a diplomatic act; Fish's 1874–1876 solicitation of ministers' views on what to print.
- **Ch. 4 (1870–1905).** The Supplemental Submissions as half the release (16,000 pages); Hunter and Adee; the 1887 audit (3,308 despatches, 221 and 151 printed, 36 arguably missed); exclusion of ongoing negotiations; the 1883 instruction to mark confidential passages in red; "Confidential" despatches nonetheless printed; informal designators ("Personal and Secret"); the 1894 arrangement by subject; Blaine's 1881 withholding; the 1898 volume's delay and the 1901 release of more; press readings of the volumes' silences.
- **Ch. 5 (1905–1920s).** Printing appropriations, not secrecy, as the first cause of the lag; the norm's drift from one year to two, three, four, fifteen; Tonner's 1915–1916 testimony that delay also served as a filter; the counterfactual that a five-year baseline might have left a 20- or 25-year line today.
- **Ch. 6 (1920–1945).** The Kellogg Order of 26 March 1925 and its five grounds; foreign consent for foreign-origin documents; the war supplements, the Russia volumes, the Lansing Papers, Paris 1919 and the Council of Four minutes vetoed by Roosevelt and Churchill in 1943; *Peace and War* as wartime publicity; no Iran in the 1922 volume; the academic constituency from 1928; the 15-year line accepted by scholars.
- **Ch. 7 (1945–1957).** New equities (Defense, the NSC, the CIA); the Yalta Papers (compiled 1953–1955, leaked and released March 1955, lag ten years) and the State–Defense terms of reference; the First Cairo Conference's missing minutes; the Historical Advisory Committee formed 1957; the series accelerated for Cold War purposes (the Soviet Union 1933–1939 volume beside a planned White Book).
- **Ch. 8 (1958–1979).** The scope decision of 1958 (State files only) and its reversal; the "FRUS filter" growing finer; documenting policymaking rather than diplomacy; the 15-, 20- and 30-year directives; FRUS publication as the gate on the archives; the CIA's doctrines from 1960; the triennial format, microfiche, and the 1978 McGovern amendment; presidential-library research from 1975; the specific delays (the 1941 Far East volume, the China volumes, France 1970, Britain 1972).
- **Ch. 9 (1978–1985).** The CDC and the 1980 re-review; FGI consultations from 1981; self-censorship; the Guatemala chapter of American Republics 1952–1954 and its 1983 disclaimer; the 1984 report to Congress and the 30-year line; Reagan's 1985 directive.
- **Ch. 10 (1986–1990).** Page limits, decompilation and microfiche; the Committee denied access to what was withheld; the Iran volume of June 1989 without a disclaimer; Cohen's resignation and the public "FRUS problem".
- **Ch. 11 (1990–1991).** The Pell Amendment and the statute as enacted (the "thorough, accurate, and reliable" mandate, 30-year line, access at 26 years, the Committee's access to deletions, four exemptions, quarterly meetings); the first HAC review of withheld material (Japan 1958–1960 accepted, Italy and Indonesia not).
- **Ch. 12 (1992–2002).** The CIA MOU of 1992, the High Level Panel of 1998, the Joint Historian of 2002; disclaimers 1991–1996; Indonesia 1958–1960 as the first volume to include a covert operation; the Congo criticism; "core, crisis, context" and the unrealised access guides; the provenance shares by subseries in n. 13; the lag at 32 years (1991–1996) and 35 (2002–2012).
- **Appendices.** A: lag by publication year (the dashboard's chart). B: print runs and lags 1861–1935. C: the roughly 160 Supplemental Submissions, 1869–1914. D: office heads 1919–2014.
