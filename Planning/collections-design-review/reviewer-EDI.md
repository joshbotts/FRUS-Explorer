ID: EDI-1
Severity: S1
Claim: Square brackets cannot mark a heading or dateline as the compiler's, because the volumes print headings and datelines of their own in the same brackets, so the Note's rule that bracketed ones "are the compiler's" is false of what the volume prints.
What a person meets: A reader of any export (PDF, Word or web page, made on any platform) under the recommended mark. Kennan's telegram is dated "[Moscow, 22 February 1946]"; a memorandum from the 1950 volume VI in the same collection is dated "[Washington, April 3, 1950.]". The first bracket is the compiler's, set over a telegram that prints its own place, day and hour. The second is the volume's own, printed so by its editors. The page draws them alike, and the Note at the back calls both the compiler's. A reader who knows the series takes a bracketed date line to be one the editors supplied, and so reads the first as saying the telegram bore none. A compiler's "[The Long Telegram]" and a volume's "[Editorial Note]" collide the same way, and the record has no rule for a compiler who types the volume's own form, "[Washington,] March 28, 1950".
Evidence:
- Record §5: "Brackets are FRUS's own sign for words an editor supplied, and the reader of a collection drawn from FRUS already reads them so. They need no key".
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:40 "Headings and datelines in square brackets are the compiler's."; :26 prints the volume's "[Received 4:58 p.m.]" one row above :27's "[The Long Telegram] — [Moscow, 22 February 1946]"; :53, under "a line beneath", the contents row "4. The Long Telegram — Moscow, 22 February 1946" has no mark at all; :85-98 use a dagger.
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionB.dc.html:72, :92, :96: one page carries the compiler's bracketed heading, the volume's "[Received February 5—4:56 p.m.]" and the volume's "120[187]".
- /home/user/FRUS-Explorer/Planning/c3-reader-facing-tier/runs/f7/work/docmeta.json:18 `"dateline": "[Washington, April 3, 1950.]"` (frus1950v06/d32); :11 "[Washington,] March 28, 1950.".
- Public TEI fetched today (https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/frus1950v06.xml and frus1946v06.xml), counted by regular expression: frus1950v06 has 24 wholly bracketed datelines of 852, "[Washington, undated.]" among them; frus1946v06 has "[Received …]" in 395 datelines and another bracketed part in 68, the supplied signatures "[Byrnes]" and "[Kennan]", and no `<supplied>` element, so the brackets are the printed text itself.
- /home/user/FRUS-Explorer/FRUSCoreKit/DocumentView/DocumentDisplayTitle.swift:36-37 lists heads the volumes print as "*[Editorial Note]*, *[Untitled]*"; /home/user/FRUS-Explorer/FRUSCoreKit/Citation/CitationFormatter.swift:188-189: "a bracketed `@n`, which is the editors' description".
- Where the TEI does tag supplied words, all three exporters draw the same plain brackets: /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:843-844 (and :240: the dagger is a footnote sign the volumes print, "`†` (944)"); /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:1350-1357; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:1563-1568.
- /home/user/FRUS-Explorer/Docs/iOS-User-Manual.md:483 teaches the reading: "editorial omissions marked in brackets".
- From memory, not fetched: that a bracketed place or date in the series means "supplied by the editors, not on the document".
Refutation: A rule in the record that draws the compiler's brackets differently from the volume's, or a showing that no volume prints a wholly bracketed heading or dateline. Checked: §5 and the mockups give no such rule, and the counts above show the contrary.
Direction: Use a mark the volumes do not print in that place, and word the Note so that it is true of every bracket on the page.

ID: EDI-2
Severity: S1
Claim: A title of the compiler's keeps printing with no mark, and with neither the volume's heading nor the citation beside it, at Summary or None depth and in every contents row, so §5's "Neither … where both are on the page" and §3.4's "nothing there needs a mark" are false of those places.
What a person meets: The owner's existing collections on any platform, which "export as they do now". A document titled "The Long Telegram" at Summary or None depth exports headed by those words alone: the title took the citation's place, and the volume's heading prints only inside a full text. In the contents list of any such collection the row is the compiler's title among rows of volume headings or citations, with nothing to tell them apart. A device still on build 1861, or a reader of a .fruscollection file made under the new design, prints a new "Your own" heading the same way.
Evidence:
- Record §5: "Neither: … a title that prints above the volume's heading, as today's override does, where both are on the page"; §3.3: "A collection that exists today keeps *The citation, then the volume's heading* and exports as it does now"; §3.4: "Nothing the volume printed is hidden on an old build, so nothing there needs a mark."
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:747-750: the override replaces the citation as the heading; :755-756: it is the contents row under both styles.
- The volume's heading is drawn only under `case .full`: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:325-375 (:373-374 `case .index: break  // no body content`); /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:685-699, :707-749; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:688-694, :705-760.
- /home/user/FRUS-Explorer/Docs/iOS-User-Manual.md:1093: "replaces the derived title in the table of contents and the export heading".
Refutation: A line of the record that marks an existing override, or code that prints the volume's heading or the citation beside an override at Summary or None depth. Checked: neither exists in §3 to §5 or in the three exporters.
Direction: Mark the compiler's title wherever the volume's heading is not beside it, the contents row and Summary and None depth included, in collections that exist today as in new ones.

ID: EDI-3
Severity: S1
Claim: A collection that hides parts and replaces nothing prints no Note on the Text by default, so what §5 says is "stated in the Note" (a hidden dateline, footnotes, a hidden reference) is neither marked nor stated.
What a person meets: Any platform. The owner picks "Full text with your annotations" in the export sheet, whose recipe turns footnotes off, and exports: the text keeps its superscript calls and prints no notes, and since no heading or dateline was replaced no Note is added. Or he hides one telegram's dateline: it prints with its classification and no place or day, and no page says so. Or he hides the reference of a document headed in his own words: the Note's entry reads "Document 475 of the 1946 volume VI", and nothing on that document's page says it is that document.
Evidence:
- Record §5: "It prints at the end, before the colophon, whenever the collection replaces a heading or a dateline, and the author may place it anywhere as a block, or add it to a collection that replaces nothing", against "Stated in the Note on the Text, and not marked on the page: a part that is hidden" and "It makes every other customization in this design a stated one."
- Hidden is offered for the dateline (§3.1 table) and the reference (§3.4: "its reference hidden"); footnotes are "Unchanged" (§3.1).
- Calls stay when notes go: /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:339-366; /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:717-718 ("`false` omits the footnotes section, markers stay"); /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:715-716.
- A shipped template does it: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:231 (`fullTextWithAnnotations`: `footnotes: false`).
- The Note keys an entry by the volume's number alone: /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:40.
Refutation: A rule that the Note prints when any part is hidden, or an exporter that drops the calls with the notes. Checked: §5 reads as quoted, and all three exporters keep the calls.
Direction: Print the Note whenever a part the volume prints is hidden, and have each entry name the document as its page names it.

ID: EDI-4
Severity: S2
Claim: A dateline is the document's own text with the editors' additions in brackets, not "the volume's editors' words", so a dateline of the compiler's replaces primary-source text that §3.6 says the design leaves alone, and replaces all of it.
What a person meets: On the Mac or iPad preview, or in the inspector on any platform, the owner types "Moscow, 22 February 1946" for document 475. The export prints "[Moscow, 22 February 1946]" where the telegram reads "Moscow, February 22, 1946—9 p.m." and the editors add "[Received February 22—3:52 p.m.]": the hour of dispatch and the time of receipt leave the page. The popover that takes the typed line also offers "Apply to: This section · All documents". A letter dated at its foot, and an enclosure with a dateline of its own, are not provided for. The Chronology block goes on printing the stored date whatever he typed.
Evidence:
- Record §3.1: "The text is never among the choices. The heading and the dateline are the volume's editors' words about a document. They are not the document's words"; §3.6 item 2: "Kept"; /home/user/FRUS-Explorer/Planning/Completed/Collections-Authoring-Scope.md:155: "The product's scholarly credibility rests on untouched TEI".
- Public TEI fetched today, frus1946v06.xml, d475, inside the document's div: `<opener><seg rendition="#left">…secret…</seg><dateline rendition="#right">…Moscow…, <date … when="1946-02-22T21:00:00+03:00">February 22, 1946—9 p.m.</date><lb/>[Received February 22—3:52 p.m.]</dateline></opener>`.
- The app reads the dateline as the document's: record §3.5 ("part of a document's flat text"); /home/user/FRUS-Explorer/FRUSCoreKit/Search/IndexingPipeline.swift:7415-7424 ("derived from its own dateline … the dateline decides the series and the geography"), :7446-7449 (19,243 attachments print a dateline that differs from their parent's).
- Whole replacement and scope: /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:34 against :40; /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionC.dc.html:119 against :122, :206-219 ("Your dateline", then "Apply to"), :305. Record §3.4: "On a heading: the same keys, as the section's." Record §3.1 limits "Your own" to "one document" for the heading and not for the dateline.
- Datelines elsewhere than the head: /home/user/FRUS-Explorer/FRUSExplorerTests/CollectionTests.swift:9612-9616 (of the datelines it measured, "43 are a document's own child …, 13,692 sit in an opener, 742 in a closer and 9 in an attachment").
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionGeneratedBlocks.swift:348-371: the Chronology reads the index's date.
Refutation: TEI or code showing the dateline is the editors' composition, or a rule in the record that keeps the printed line on the page and limits a typed one to one document. Checked: none found.
Direction: Treat the dateline as text: print the compiler's date beside the printed line, for one document at a time, and never in its place.

ID: EDI-5
Severity: S2
Claim: With the colophon on, the export's own "Where this came from" block will say that documents headed and dated in the compiler's words were "Read from the text and editorial apparatus of the FRUS volumes, and from no other source", because the record gives those words no source and never mentions the block.
What a person meets: A reader of a PDF, Word or web export with the colophon on. The Note on the Text says the bracketed heads are the compiler's; the footer under it says the documents came from the volumes and nowhere else. Where the collection also holds a prose block the footer adds "The app never mixes them into the published text", while a dateline of the compiler's stands inside the document's opener.
Evidence:
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:1297-1298 ("Derived from the items rather than declared by the caller, so an export cannot claim a source it did not use or omit one it did"), :1317-1319 (a document adds `.frusText`, and `.appModel` only for a summary), :1324-1325 (a heading adds nothing).
- The sentences: /home/user/FRUS-Explorer/FRUSCoreKit/Provenance/ProvenanceSource.swift:142, :152.
- All three formats print the block: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:655-662; /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:513-514; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:666-669.
- The compiler's dateline drawn in the document's opener: /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:32-35. The record names the colophon only as a control and as the Note's neighbour (§2.4, §4.3, §5).
Refutation: A line of the record, or code, that gives a compiler's heading or dateline a source in `provenanceSources`. Checked: none.
Direction: Derive a source for the compiler's words from the plan, as the set is derived from the items now, and reword the two sentences so they stay true.

ID: EDI-6
Severity: S2
Claim: The collection's assembly does not hold what the volume prints for a head or a dateline (no dateline that sits in an opener, no head of an editorial note, a head's footnote call written "[1]", nothing for a volume not on the device), so the Note cannot quote it as §5 says and §2.2's "differs only in its dates" is contradicted by a pinned test.
What a person meets: Any platform. Today the record's eight Kennan telegrams list under Header & Dateline as eight identical rows with no date. Under the design, the Note on document 475 has no printed dateline to quote; a 1977–1980 head is quoted as "1. Letter From President Carter to Soviet General Secretary Brezhnev[1]", a bracket of the app's making beside the compiler's; and for a document whose volume is not on the device (the preview, where the author checks the Note, or an export after the wait gives up) there is no printed head at all.
Evidence:
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:1468-1482 reads top-level nodes only; :1518-1522 writes a numbered call as "[n]"; :193-196 (a preview never downloads).
- The converter nests them: /home/user/FRUS-Explorer/FRUSCoreKit/TEI/ASTToRenderNodeConverter.swift:392-393 (opener), :572-575 (editorial note).
- Pinned: /home/user/FRUS-Explorer/FRUSExplorerTests/FRUSCoreKit/CollectionResolutionTests.swift:450-452 ("the dateline, inside an opener, prints with the body rather than in the header", `d7.dateline == nil`).
- Public TEI fetched today, counted by regular expression: documents 470, 473, 474, 475, 476, 477, 480 and 486 of frus1946v06 each have their dateline inside `<opener>`, as do 651 of that volume's 692 documents and every dateline counted in frus1964-68v14 (318) and frus1977-80v06 (321); a numbered source note sits on the head in 311 of 335 and 308 of 315 documents of those two, and a numbered note on 79 of 692 heads of frus1946v06.
- Record §2.2: "Under *Header & Dateline* a contents list of them differs only in its dates"; /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:26, :52, :84 draw contents rows with datelines.
- /home/user/FRUS-Explorer/FRUSCoreKit/DocumentView/DocumentDisplayTitle.swift:32-33 ("seven headerless documents"); /home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionContentResolver.swift:685-691, :720-722 (no download address, or 300 seconds).
- NEEDS A RUN to see the rows: a Header & Dateline contents list of the eight telegrams, and of a 1977–1980 document.
Refutation: A second reading of head and dateline in the assembly, or a test that pins an opener's dateline into the collection document. Checked: the index has one (/home/user/FRUS-Explorer/FRUSCoreKit/Search/IndexingPipeline.swift:7347-7359) that the assembly does not call, and the test pins nil.
Direction: Give lane 3 one reading of the printed head and dateline (opener, closer, note wrapper, footnote calls, absent volume) before anything quotes them, and count it in the lane's size.

ID: EDI-7
Severity: S2
Claim: Two of the ten parts are not separable as drawn: a heading carries footnote calls, so a replaced or hidden heading leaves notes that nothing calls, and the source note is itself one of the footnotes, so the Source-note switch does not decide whether it prints.
What a person meets: Any platform. The owner gives a 1977–1980 document a heading of his own: the volume's heading, which carried call 1, is no longer drawn, footnote 1 (the source note) still opens the notes, and the text's calls begin at 2. He turns Source note off with Footnotes on: the control shows it off and the page prints it among the notes, so a Note that says source notes are left out is false. Under "Full text as printed", with both on, it prints in both places.
Evidence:
- Record §3.5: "a heading that is replaced or hidden is still walked by each exporter's offset counter and is not drawn". The call is the heading's child: /home/user/FRUS-Explorer/FRUSCoreKit/TEI/ASTToRenderNodeConverter.swift:386-387, :436-437; /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:740-741.
- Public TEI fetched today: the head carries a numbered source note in 308 of 315 documents of frus1977-80v06 (d1: `<note n="1" type="source" …>Source: Carter Library, …`) and 311 of 335 of frus1964-68v14; 79 of 692 heads of frus1946v06 carry a numbered note (d13, note 41).
- Every footnote prints when footnotes are on, the source note among them: /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:364-366, :700-719; /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:1034-1053; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:1080-1103. It prints again from the index: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:379-382. Both are on by recipe: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:227.
- The mockups assume two disjoint parts for document 470, whose TEI has five notes: /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/PartsPhone.dc.html:87-88, :93-94 ("Footnotes · 4 notes", "Source note · Shown"); /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionB.dc.html:102-105, :109.
- NEEDS A RUN to see the page: export frus1946v06 d470 with Footnotes and Source note both on and count the source note.
Refutation: An exporter that leaves the source note out of the footnotes when its switch is off, or a rule in the record for a call on a heading that is not drawn. Checked: no exporter tests a note's type before printing it, and §3.5 and §5 give no rule.
Direction: Decide what becomes of a call on an undrawn heading, and make Source note and Footnotes disjoint in the plan before a switch or a Note describes either.

ID: EDI-8
Severity: S2
Claim: The short form as shown (year, volume, document) names more than one volume for 133 of the 553 bundled volumes, 48 of them even with a part added, and is one form under all three styles, so it cannot be "held to the parser by a round trip" and the style chosen does not show in the contents list the owner asked about.
What a person meets: A reader of any export whose contents list or See also line cites "*FRUS*, 1919, vol. I, doc. 12": the Paris Peace Conference volume I and the 1919 annual volume I both answer. For a 1946 telegram "doc. 475" is a number the volume's heading does not carry. For a Potsdam document the volume prints without a number the row names no document, and with the address "behind" the reference a PDF, which carries no links, has no locator for it. The owner changes History at State to Chicago and the contents list does not move.
Evidence:
- Record §6: "each style gains a short form, and the contents list and the *See also* line use it"; one row, "Short (proposed) | *FRUS*, 1946, vol. VI, doc. 475."; "held to the parser by a round trip". /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Citations.dc.html:56-66 draws one short form.
- /home/user/FRUS-Explorer/FRUSExplorer/Resources/manifest.json, counted today by `subseries` and each title's "Volume N" and "Part N": 61 year-and-volume keys are shared by 133 volumes; with the part, 22 keys by 48 (1945 I and II: frus1945Berlinv01/02 and frus1945v01/02; 1919 I and II; 1943: three volumes; 1894: four); 99 titles have no "Volume N".
- The app has met this before: /home/user/FRUS-Explorer/FRUSCoreKit/Chronology/VolumeLabels.swift:60-66 ("Until #1388 this was asserted and false: 11 tags were shared by 29 volumes"). The full forms' round trip already excuses two volumes by name: /home/user/FRUS-Explorer/FRUSExplorerTests/FRUSCoreKit/CitationMatchingEngineTests.swift:521-534.
- /home/user/FRUS-Explorer/FRUSCoreKit/Citation/CitationParser.swift:38-46: the short forms it reads carry a part ("pt. 1") and, for "pre-1955–57 references", a page.
- /home/user/FRUS-Explorer/FRUSCoreKit/Citation/CitationFormatter.swift:469-470 ("pre-1955 volumes whose headers carry no numeric prefix"), :177-179, :188-195 (217 documents cited with no number). Public TEI fetched today: none of frus1946v06's 723 heads opens with a number, and d475 runs from page 696 to 709.
- Record §3.1 ("with the address behind it") against /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:1202-1205 ("CoreText frame drawing has no link annotations") and /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:694-699, which prints the address today.
Refutation: A short form in the record that carries a part, a named volume or a supplement, or one per style. Checked: §6 and the mockup show one form with none of these.
Direction: Specify the short form over the whole manifest and for each style before promising the round trip, and keep a printed locator for a document the volume does not number.

ID: EDI-9
Severity: S2
Claim: The ask for "other labels derived from the source TEI … marked appropriately" is met for headings and datelines only: "Source:", the one label of the volume's that the design lets the compiler replace, is classed with the app's own words and replaced with no mark.
What a person meets: Any platform, in the Wording group. The owner sets the source note's word to "Archive". A 1977–1980 document, whose own first note is printed "Source: Carter Library, …", exports "Archive: Carter Library, …" with nothing to say the volume's word was changed. A 1946 telegram, whose volume prints a bare file number above the heading, exports that number after the text under his word. No other label the TEI prints (an enclosure's head, a list's "SUBJECT", "Editorial Note") has a control.
Evidence:
- The ask (the record's opening quotation): "overriding headings, datelines, and other labels derived from the source TEI with my own headings and labels, marked appropriately".
- Record §3.1: "Source note … On or off, under the collection's word for it"; §5: "Neither: the app's own words (*Contents*, *Research Note*, an apparatus block's title)"; §7 item 2 lists *Source* among "the collection's own words".
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:1508-1514: "Post-1969 volumes' stored notes ALREADY lead with `Source:` — the TEI carries the label — while every renderer prepends its own".
- Public TEI fetched today: frus1977-80v06 d1 `<note n="1" type="source" …>Source: Carter Library, …`; frus1946v06 d475 `<note rend="inline" type="source">861.00/2–2246: Telegram</note>`. /home/user/FRUS-Explorer/Docs/iOS-User-Manual.md:483: "file numbers printed above the heading".
Refutation: A mark for a replaced label in §5, or the owner saying he meant only the app's labels. Checked the first: none. The second is his to say.
Direction: List which printed labels may be replaced, and give each the mark a heading gets.

ID: EDI-10
Severity: S3
Claim: One formatter for "every place a citation prints" puts each added style in the wrong shape somewhere, since the app's Chicago is a note's punctuation and its Turabian a bibliography entry's, a collection has both places, and neither form names the document cited.
What a person meets: Any platform. A collection set to Turabian prints its reference lines and excerpt source lines as three sentences; one set to Chicago prints its Bibliography block in note form. A reader who knows either manual meets notes that never name the telegram or its date. Under any style the indexes go on citing "Document 12 (frus1969-76v01)".
Evidence:
- /home/user/FRUS-Explorer/FRUSCoreKit/Citation/CitationFormatter.swift:519-525 ("per the Chicago Manual of Style (notes-bibliography)", `*Full volume title*, edited by Name (City: Publisher, Year), Document N.`), :560-566 ("per Turabian (student edition of Chicago)", `*Full volume title*. Edited by Name. City: Publisher, Year. Document N.`).
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:1226-1229: the formatter "reads only volume metadata and the document number"; :995-996 and :1242-1244: the `volumeId/documentId` fallback, which no style governs.
- Record §6: "It governs every place a citation prints: the reference under a heading or the heading itself, a contents row in *Citation* style, an excerpt's source line, the *See also* line, and the Bibliography's and the Chronology's rows."
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionGeneratedBlocks.swift:709-710, :722-723: the blocks' own document tokens.
- From memory, not fetched (this container's proxy refused history.state.gov's page on citing the series, and neither manual could be read): that Chicago and Turabian are one system with a note form and a bibliography form, and that a note for a document in a published collection names the document and its date.
Refutation: The manuals showing each shape as that style's single form for a document in this series. Not checked: they could not be fetched.
Direction: Give a style a form for each place (reference, list, bibliography), or name the three by what they print.

Attacked and held:
- A compiler's title in a citation record: none. The BibTeX, RIS and Zotero item is built from the volume's head (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:1120-1132; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/BibTeXCollectionExporter.swift:30-33), the record changes nothing there, and the formats with no place for a Note carry nothing that needs one. §5's "survive … a `.bib` file" has nothing to survive.
- AI text keeps its label: the attribution is drawn apart from the *Summary* and *Headnote* labels and is none of the ten parts (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:363-365, :458-462; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:1127-1137), so no switch or wording removes it.
- "A style changes no order" (§6) is true: the Bibliography sorts by volume id and printed number and the Chronology by stored date (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionGeneratedBlocks.swift:313-327, :361-363).
- Two citation styles inside one export: not possible. One formatter per batch serves the heading, the excerpt line, See also and the blocks' rows (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:797, :917, :1236-1245, :1262-1268), and nothing there reads the app-wide preference; the two can differ only between collections.
- A compiler's dateline on an older build: it cannot appear unmarked, since today's entry has no field that holds one (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:649-696) and a build without the new keys prints the volume's own.

Not read:
- The mockups OptionA, PartsPhone and Main beyond their visible text; OptionB and OptionC beyond the page and the popover.
- The Word exporter beyond its document section, run walkers and footnote registration; the PDF exporter beyond the lines cited; the editor and preview views on either platform.
- Both manuals beyond the two lines cited; the two earlier designs beyond the lines cited.
- history.state.gov's page on citing the series (refused by the proxy) and the Chicago and Turabian manuals.
- The corpus beyond four volumes fetched from the public repository (frus1946v06, frus1950v06, frus1964-68v14, frus1977-80v06); the counts in them are by regular expression over the TEI, not by the app's parser.
- Nothing was built or run.