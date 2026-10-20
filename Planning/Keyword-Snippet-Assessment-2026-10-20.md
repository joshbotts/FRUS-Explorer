# Keyword search snippets: an assessment, 2026-10-20

**What this is.** The plan of record's §6g finding from A10 (#1684): a keyword result's snippet repeats the document's own heading, source note and dateline, and the row's two default lines rarely reach the word that matched. Measured on `v2` at `8927db62` (A10 merged). Nothing is built. The options go to the owner (§4), and the owner's choice is recorded in §5.

**How it was measured.**
- **The index.** A full library at the current index version, 69: 553 volumes and 318,104 documents. It came from the "iPhone 17e A8 timing" simulator (`89404205`, indexed 2026-10-18), cloned (APFS) into a scratch folder and opened read-only and immutable. The simulator was not booted or touched.
- **The searches.** A throwaway package test, deleted afterwards, ran the shipped `SearchService.search` for twelve queries and kept each one's top 1,000 rows, the iOS fetch ceiling.
  - The queries: Berlin, Vietnam, Cuba, Kissinger, Khrushchev, oil, nuclear, embargo, refugees, coup, human rights and disarmament. Each matches 3,507 to 16,239 documents.
  - Figures are given for the top 20 (iOS's first page), the top 100 (the Add Documents sheet's fetch) and the top 1,000.
  - Each row's snippet was rebuilt with the shipped `makeContextSnippet`, and 12,000 of 12,000 equalled the service's own.
- **The drawing.** Each snippet, today's and each option's, was laid out with Core Text:
  - in the 12-point system font that both platforms use: `.caption` on iOS, `.callout` on the Mac;
  - with the matched word in medium weight;
  - and with SwiftUI's tail truncation: whole lines wrap at word breaks, and the last line is cut by character before "…".

  The widths and the font were checked against three drawn rows we already have:
  - the iPhone screenshot `Planning/Cross-Platform-UI-Adversarial-Review/assets/ios-search-results.png`: three lines, reproduced exactly at 370 points;
  - `Docs/screenshots/macos/search.png`: two lines, reproduced exactly at 990 points in 12-point (13-point breaks differently);
  - A10's fixture on iPhone 17: two lines, within one character of the "Spoken-row fixture, xy…" that A10 saw.
- **The boilerplate.** A document's heading, source note and dateline. Its end is where the corrected strip of §3 stops.

## 1. In brief

- **The match is rarely near the start.**
  - In the top 100 rows, the first matched word lies past `body_text`'s 150th character in 65.3% of rows: 60.0% of the top 20, 73.6% of the top 1,000.
  - It lies inside the heading, source note or dateline in 46.1%. The query names the heading's country or person ("Telegram From the Embassy in Cuba"), or the source note's file ("POL CUBA–US").
- **The opening of `body_text` is the row again.** Across all 308,609 documents (not counting editorial notes and front matter):
  - the heading, source note and dateline fill a median of 150 characters of the opening, 349 at the 90th percentile;
  - they make up 88.6% of the first 150 characters;
  - from 1961 the median is 329 to 372 characters, more than two iPhone lines.
- **So the default two lines mostly redraw the row.** In the top 100:

  | Where | Bold word drawn | Drawn text that is the row's own heading, source note and dateline |
  |---|---|---|
  | iPhone 17 | 28.7% | 90.5% |
  | The Mac's default Search window | 53.2% | 77.6% |
  | iPad Pro 13-inch, landscape | 78.8% | 57.9% |

  The owner's own screenshots show it: in `Docs/screenshots/macos/search.png` ("Berlin blockade"), one of the first six rows draws a bold word.
- **The three options, at two lines on iPhone 17 (top 100):**

  | Option | Bold word drawn | Drawn text that repeats the row |
  |---|---|---|
  | **A**, strip the boilerplate | 56.8% | 11.9% |
  | **B**, start a little before the match | 100% | 44.5% |
  | **C**, both | 100% | 4.9% |
  | **C with the corrected strip** | 100% | none |

  Under B, the bold word is often the heading's own.
- **The recommendation is C with the corrected strip** (§3): the window starts 30 characters before the prose's first match and keeps 2,000 after it.
- **No index version, and no CloudKit change.** The snippet is cut when a search runs. It is kit code (`FRUSCoreKit/Search/SearchService.swift`), so `swift build --target FRUSCoreKit`, `swift test`, the unit target and the Mac build are owed. The web edition's keyword rows change with it.
- **Found on the way:** `ProseSnippet`, the strip Meaning rows use today, stops short in 17.9% of documents (§3).

## 2. Measurements

### 2.1 Characters a line holds

Measured over ordinary FRUS prose at 12-point. The two-line column is the mean drawn over the top 1,000 rows' snippets.

| Where | Snippet width | Characters a line | Two lines (the default) |
|---|---:|---:|---:|
| iPhone SE (3rd generation) | 343 pt | 57 | 112 |
| iPhone 17 | 370 pt | 60 | 122 |
| iPad mini, portrait | 704 pt | 118 | 238 |
| iPad Pro 13-inch, portrait | 992 pt | 171 | 338 |
| iPad Pro 13-inch, landscape | 1,336 pt | 229 | 458 |
| Mac, the Search window at its default 820 pt | 770 pt | 133 | 261 |
| Mac, the same window with Facets open | 470 pt | 79 | 156 |

- **Widths.** iOS rows inset 16 points on an iPhone and 20 on an iPad. The Mac's text starts 25 points in from the list's edge, and its width is the list's less 50 (the screenshot's 990 in a 1,040-point list).
- **The Add Documents sheet's snippet is narrower.** On an iPhone 17 it is about 340 points, after the sheet's checkmark column, so it draws like the iPhone SE row. In the Mac's 560-point sheet it is about 480, so it draws like the Mac with Facets open.

### 2.2 Where the first match lies

The shipped scan: the first word whose Porter stem matches.

| Rows | Past character 150 | Past 1,000 (the window opens "…") | Inside the heading, source note or dateline |
|---|---:|---:|---:|
| Top 20 | 60.0% | 5.0% | 51.7% |
| Top 100 | 65.3% | 3.9% | 46.1% |
| Top 1,000 | 73.6% | 14.4% | 34.8% |

By query (top 100; the last two columns are iPhone 17 at two lines):

| Query | Matches | Past 150 | Inside the boilerplate | Bold word drawn today | With C |
|---|---:|---:|---:|---:|---:|
| Berlin | 16,239 | 48% | 72% | 48% | 100% |
| Vietnam | 13,011 | 75% | 51% | 15% | 100% |
| Cuba | 11,225 | 49% | 66% | 33% | 100% |
| Kissinger | 13,394 | 2% | 95% | 94% | 100% |
| Khrushchev | 3,507 | 80% | 15% | 17% | 100% |
| oil | 14,494 | 87% | 30% | 7% | 100% |
| nuclear | 10,498 | 79% | 36% | 18% | 100% |
| embargo | 4,520 | 98% | 2% | 1% | 100% |
| refugees | 7,749 | 49% | 60% | 46% | 100% |
| coup | 4,123 | 95% | 13% | 2% | 100% |
| human rights | 7,102 | 69% | 65% | 26% | 100% |
| disarmament | 7,353 | 53% | 48% | 37% | 100% |

"Kissinger" draws its bold word today because the word is in the heading the row draws again: "228. Telephone Conversation Between President Nixon and his / Special Assistant for National Security Affairs (**Kissinger**) Sourc…".

### 2.3 How much of the opening is boilerplate

All 318,104 documents.

| Documents | Count | Median, characters | 90th percentile | 150 or more | Share of the first 150 characters |
|---|---:|---:|---:|---:|---:|
| 1861–1905 | 39,793 | 94 | 128 | 1.9% | 64.9% |
| 1906–1945 | 141,299 | 142 | 179 | 37.4% | 88.8% |
| 1946–1960 | 74,128 | 173 | 314 | 67.8% | 94.1% |
| 1961–1976 | 40,979 | 329 | 631 | 94.1% | 97.3% |
| 1977 on | 12,410 | 372 | 661 | 99.6% | 99.9% |
| All documents | 308,609 | 150 | 349 | 50.1% | 88.6% |
| Editorial notes | 8,467 | 19 | 20 | 0% | 12.2% |
| Front matter | 1,028 | 14 | 34 | 0.9% | 12.4% |

Each era opens differently:
- **1861–1905:** the heading and the dateline: "Mr. Jones to Mr. Hay. Legation of the United States, Buenos Ayres, February 3, 1900. No. 769.]".
- **1906–1960:** the file number first: "841D.01/215: Telegram The Minister in Ireland (Gray) to the Secretary of State Dublin, November 1, 1943—7 p.m. [Received 8:48 p.m.] 136.".
- **From 1961:** the numbered heading, then a long "Source:" note.

### 2.4 What each option draws

Top 100, 1,200 rows. Each cell gives the share of rows whose bold word is drawn whole, then the share of the drawn text that is the row's own heading, source note and dateline.

**Two lines, the default:**

| Where | Today | A | B | C | C, corrected strip |
|---|---|---|---|---|---|
| iPhone SE | 21.8% · 90.8% | 54.9% · 12.4% | 100% · 45.3% | 100% · 5.1% | 100% · 0 |
| iPhone 17 | 28.7% · 90.5% | 56.8% · 11.9% | 100% · 44.5% | 100% · 4.9% | 100% · 0 |
| iPad mini, portrait | 48.1% · 80.1% | 76.4% · 7.4% | 100% · 36.5% | 100% · 3.1% | 100% · 0 |
| iPad Pro 13-inch, portrait | 65.5% · 69.2% | 83.4% · 5.3% | 100% · 31.0% | 100% · 2.3% | 100% · 0 |
| iPad Pro 13-inch, landscape | 78.8% · 57.9% | 88.6% · 3.9% | 100% · 25.7% | 100% · 1.7% | 100% · 0 |
| Mac, default window | 53.2% · 77.6% | 78.8% · 6.8% | 100% · 35.1% | 100% · 2.9% | 100% · 0 |
| Mac, Facets open | 34.8% · 88.0% | 63.2% · 10.3% | 100% · 42.2% | 100% · 4.2% | 100% · 0 |

**Rows drawing any of it at two lines:** today 98.2%, A 18.6%, B 55.7%, C 8.2%, C with the corrected strip none.

**One line**, bold word drawn:

| Where | Today | A | B | C | C, corrected strip |
|---|---|---|---|---|---|
| iPhone SE | 8.8% | 31.9% | 99.9% | 99.8% | 99.8% |
| iPhone 17 | 10.0% | 34.8% | 100% | 100% | 100% |
| Mac, default window | 30.8% | 57.8% | 100% | 100% | 100% |

**Ten lines**, bold word drawn:

| Where | Today | A | B | C | C, corrected strip |
|---|---|---|---|---|---|
| iPhone 17 | 86.5% | 93.2% | 100% | 100% | 100% |
| iPad and Mac | 92.3% to 100% | 96.4% to 100% | 100% | 100% | 100% |

**The other slices, two lines on iPhone 17:**

| Rows | Today | A | B | C | C, corrected strip |
|---|---|---|---|---|---|
| Top 20 | 33.3% · 91.4% | 65.4% · 13.9% | 100% · 51.2% | 100% · 7.2% | 100% · 0 |
| Top 1,000 | 21.2% · 81.8% | 36.9% · 9.5% | 100% · 33.4% | 98.9% · 2.9% | 98.9% · 0 |

In the top 1,000, 1.1% of rows match only inside the heading, source note or dateline. A and C then draw the document's opening prose with no bold word (§3). None of the top 100 does.

**"0" for the corrected strip holds by construction.** The repeated text is counted up to where that strip stops, so the zero says only that it reaches its own measure. Read row by row, its samples draw no repeated field. What it still misses, the 3.5% of documents whose dateline lies further on, is described under the corrected strip in §3.

## 3. The options and their costs

**The window today.**
- `results(from:parameters:)` calls `makeContextSnippet(body:stemmedTerms:contextRadius: 1000)`. That bolds the first word whose stem matches and keeps 1,000 characters on each side, snapped to word breaks. So a match in the first 1,000 characters is drawn after the whole of `body_text`'s opening.
- The rows draw the window's first N lines: 2 by default (`SearchDefaults`), 1 to 10 by #189-C.
  - On iOS and in Add Documents: `SearchSnippetView`.
  - On the Mac: `SnippetView` in `SearchSheet.swift`.
- VoiceOver's More Content (A10, decision 73) reads up to 150 characters on each side of the bold word (`SearchResultAccessibility.matchedText`).

**A. Strip the heading, source note and dateline, as `ProseSnippet` does.** The window starts no earlier than the prose, and the bold word is the prose's first match. It still starts up to 1,000 characters before that match.
- **Effect (top 100, two lines):**

  | Where | Bold word drawn | Drawn text that repeats the row |
  |---|---|---|
  | iPhone 17 | 57% | 12% |
  | Mac | 79% | 7% |
  | iPad Pro 13-inch, landscape | 89% | 4% |

  The repeated text is what `ProseSnippet`'s strip leaves (below), in 19% of rows.
- **A row whose only match is in the boilerplate** (1.1% of the top 1,000, none of the top 100) draws its opening prose with no bold word, as a Meaning row does. Its heading, drawn above, holds the word.
- **The 1 to 10 line setting:** the window keeps its size, so ten lines fill as today.
- **Add Documents:** the sheet already draws the source note under the snippet, so today a modern document's row draws its source note twice. Under A it draws it once.
- **VoiceOver:** unchanged.
- **Cost:** the strip is `ProseSnippet`'s, in SemanticVectorsKit, which FRUSCoreKit cannot import. `FRUSCoreKitBoundaryTests` allows only Foundation and the guarded modules `CLAUDE.md` names. Within the web edition's rules, the strip moves into FRUSCoreKit, and Meaning rows call it there. `ProseSnippet` itself can stay in SemanticVectorsKit for the retrieval evaluation harness (`RetrievalEvalHarnessCore`), or that harness can take the kit's; that is the lane's to settle.

**B. Start the window a little before the match**, 30 characters (about five words), without the strip.
- **Effect:** the bold word is drawn at two lines on every platform, and at one line in 99.9% of rows on an iPhone SE. But the first match lies inside the boilerplate in 46% of top-100 rows. There B bolds the heading's or source note's own word and draws the source note after it: 45% of what is drawn on iPhone 17 and 35% on the Mac, in 56% of rows. For example, "Cuba" in `frus1969-76ve10` d213:
  > … 9, Central Files 1970–73, POL **CUBA**–US. Secret. It was drafted / by Crimmins, Hurwitch, and Funseth; cleared by Meyer, Bowden…
- **The 1 to 10 line setting:** with 1,000 characters kept after the match, ten lines no longer fill on an iPad or the Mac. On an iPad Pro, landscape, ten lines draw 1,007 characters on average, against 1,391 today. So the far side goes to 2,000.
- **VoiceOver:** More Content reads about 30 characters before the word and 150 after, some 180 in all. Decision 73 and the iOS manual §7.1 say "about 300 characters". That stays true if `SearchResultAccessibility` takes the rest after the word, one constant in app code.
- **Cost:** the smallest change: one more argument to `makeContextSnippet` (characters before, characters after).

**C. Both:** strip, then start 30 characters before the prose's first match, keeping 2,000 after it.
- **Effect:**
  - At two lines, the bold word is drawn in every row of the top 100 on every platform.
  - At one line it is drawn in 99.8% on an iPhone SE.
  - With `ProseSnippet`'s strip as it is, the row's own text is 4.9% of what is drawn on iPhone 17, in 8.2% of rows. With the corrected strip it is none.

  Two examples, iPhone 17, two lines. "Cuba", `frus1969-76ve10` d213:
  > Today: 213. Telegram 23858 From the Department of State to All ARA / Diplomatic Posts Source: National Archives, RG 59, Central File…
  >
  > C: … the possibility of reintegrating **Cuba** into the Organization of / American States and the hemispheric community, the Departm…

  "coup", `frus1951v06p2` d94:
  > Today: 792.00/11–3051: Telegram The Chargé in Thailand (Turner) to the / Secretary of State confidential Bangkok, November 30, 1951—3…
  >
  > C: … yet offer firm analysis Nov 29 **coup**. Fol based solely on / preliminary observations. 1. Causes. Coup apparently motivated…
- **The 1 to 10 line setting:** ten lines fill at least as fully as today: 1,798 characters on an iPad Pro, landscape, and 1,235 on the Mac, against 1,391 and 1,212. On an iPhone, ten lines hold about 600 characters either way.
- **A row whose only match is in the boilerplate:** as A.
- **Add Documents:** as A. The sheet's narrow column, like the iPhone SE row, now draws the match: today it does in 21.8% of its rows at two lines.
- **VoiceOver:** as B.
- **Cost:** A's and B's together.

**The corrected strip.** `ProseSnippet`'s strip, which Meaning rows use today, stops short in two ways.
1. **Its despatch-serial rule runs before the heading is tried again.** A heading that opens "No. 567" loses only its number, and the rest of the heading stays. This happens in 6,923 documents in 26 volumes, the 1952–54 volumes and the 1945 Berlin conference's among them.
2. **It stops at text that no stored field carries.** In 1946–60 telegrams, a classification marking ("confidential", "top secret us urgent niact") or a distribution note ("Repeated to Amman, Baghdad, …") sits before the dateline. The corrected strip goes on through the document's own dateline where the dateline starts within 200 characters. It still leaves the dateline in place in 3.5% of documents, where a long distribution note puts it further on.

   For example, `ProseSnippet`'s strip draws "coup" (`frus1951v06p2` d94) under A as:
   > confidential Bangkok, November 30, 1951—3 p. m. 1233. / Insufficient info yet offer firm analysis Nov 29 coup. Fol based s…

**The two corrections together take the strip further than `ProseSnippet`'s** in 17.9% of documents, and in 54.3% of those from 1946–60.

**If the corrected strip moves into FRUSCoreKit and Meaning rows call it**, Meaning rows lose the same leftovers. That is a change to Meaning rows too, and is part of what is chosen.

**Common to every option:**
- **No index version.** The snippet is cut when a search runs, from `body_text` as stored. No CloudKit change.
- **Kit code.** `swift build --target FRUSCoreKit`, `swift test`, the unit target and the Mac build.
- **The web edition.** All of it is within `CLAUDE.md`'s four rules: Foundation only, and no new import. FRUS Explorer Light's keyword rows change in the same way, since it calls `SearchService.search`.
- **Tests:**
  - `SearchSnippetCostTests` keeps a reference copy of the window and follows it.
  - New tests would cover the strip (a "No. 567" heading, a classification line) and the window (its lead, its far side, a row with no match in the prose).
  - The window's start should snap back to a space, not only across letters. A 30-character lead otherwise opens on "… s 3463", from "Bonn’s".
  - `UITestSpokenVolumeSeederTests` reads the service's heading-and-dateline fallback, which no option changes.
- **The manuals.** Their words hold: "a snippet with your terms highlighted", "1–10 lines of context". Their two search screenshots (`Docs/screenshots/ipad/search-results.png` and `Docs/screenshots/macos/search.png`) show today's snippets and would join the owner's capture list.
- **Where it goes.** It changes the kit's search service and A10's More Content constant (A10 is merged), and a comment in the Mac's `SearchSheet.swift`. Of the lanes still to land, only A13 also works in the Search views. It could be a lane of its own anywhere before A19's checklist in build 51, or wait for a later build.

## 4. For the owner

1. **C with the corrected strip (recommended).** One strip in FRUSCoreKit, which keyword and Meaning rows share. A lead of 30 characters, 2,000 after the match, and More Content kept at about 300 characters.
2. **C with `ProseSnippet`'s strip as it is.** Meaning rows are unchanged.
3. **A**, the strip alone.
4. **B**, the lead alone, with the far side raised to 2,000.
5. **None for now.** The finding stays in §6g.

The second question is where it goes: build 51, as a lane before A19, or a later build.

## 5. The owner's choice

Not yet given.
