// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import PersonAuthorityIndexGeneratorCore

/// The `persons-complete.xml` overlay: identifier enrichment and the #260 crosswalk expansion
/// (#736).
///
/// Every fixture below is shaped like the real drop, because three of the rules this suite pins
/// exist only because the real drop broke a plausible implementation:
///
/// - anchors ride on `<idno type="frus-ref">`, **not** `<source-url>` as both the issue and the
///   plan state — a `source-url` parser returns 0 pairs from 30,776 well-formed entries and
///   reports success;
/// - an entry can carry several `people-id`s, and 46 ids the app uses appear only as an entry's
///   *secondary* one;
/// - the audit CSV keys on `FRUS-NNNNN` xml:ids, the identifier the joining rules forbid relying
///   on, so the guard has to resolve them inside the same file version.
@Suite("persons-complete overlay")
struct PersonsCompleteOverlayTests {

    // MARK: - Anchors

    @Test("Anchors are read from frus-ref idnos, the form the file actually uses")
    func parsesFRUSRefAnchors() throws {
        let chunk = """
            <person xml:id="FRUS-00199">
              <persName type="main">Adams, Ruth</persName>
              <idno type="frus-ref">frus1917-72PubDipv07/persons#p_AR_1</idno>
              <note type="sources">frus-volumes</note>
            </person>
            """
        let entry = PersonsCompleteOverlay.parseEntry(chunk)
        #expect(entry.anchors.count == 1)
        #expect(entry.anchors.first?.volumeId == "frus1917-72PubDipv07")
        #expect(entry.anchors.first?.ref == "p_AR_1")
    }

    @Test("A frus-ref without the /persons segment is not an anchor")
    func rejectsNonPersonsRef() {
        #expect(PersonsCompleteOverlay.parseFRUSRef("frus1958-60v03/documents#d12") == nil)
        #expect(PersonsCompleteOverlay.parseFRUSRef("frus1958-60v03/persons#") == nil)
        #expect(PersonsCompleteOverlay.parseFRUSRef("notavolume/persons#p_A1") == nil)
        #expect(PersonsCompleteOverlay.parseFRUSRef("no-hash-at-all") == nil)
    }

    // MARK: - People-ids

    @Test("Every people-id on an entry is captured, not only the first")
    func capturesAllPeopleIds() {
        // 64 auto-merged entries carry several ids, and 46 the app uses exist ONLY as a secondary
        // one — a first-id-wins parse silently orphans them.
        let chunk = """
            <person xml:id="FRUS-01234">
              <persName type="main">Merged, Person</persName>
              <idno type="people-id">100104</idno>
              <idno type="people-id">100105</idno>
              <idno type="frus-ref">frus1952-54v01/persons#p_MP1</idno>
            </person>
            """
        let entry = PersonsCompleteOverlay.parseEntry(chunk)
        #expect(entry.peopleIds == ["100104", "100105"], "document order, both kept")
    }

    @Test("An entry with no people-id still parses, and carries none")
    func entryWithoutPeopleId() {
        let chunk = """
            <person xml:id="FRUS-00199"><persName type="main">Adams, Ruth</persName>
            <idno type="frus-ref">frus1917-72PubDipv07/persons#p_AR_1</idno></person>
            """
        let entry = PersonsCompleteOverlay.parseEntry(chunk)
        #expect(entry.peopleIds.isEmpty)
        #expect(entry.anchors.count == 1, "the anchor is real even though it cannot be joined")
    }

    // MARK: - Enrichment fields

    @Test("Wikidata, VIAF and role text are read where present")
    func readsEnrichmentFields() {
        // The drop spells these `Wikidata` and `VIAF`, NOT `wikidata`/`viaf`. A case-sensitive
        // match on the lower-case form finds zero of 7,500 Wikidata and 6,442 VIAF ids and
        // reports a clean build — which is exactly what the first run of this generator did.
        let chunk = """
            <person xml:id="FRUS-02000">
              <persName type="main">Saunders, Harold H.</persName>
              <occupation>Assistant Secretary of State for Near Eastern Affairs</occupation>
              <idno type="people-id">109500</idno>
              <idno type="Wikidata">Q5660906</idno>
              <idno type="Wikidata-URL">https://www.wikidata.org/wiki/Q5660906</idno>
              <idno type="VIAF">69005565</idno>
              <idno type="VIAF-URL">https://viaf.org/viaf/69005565</idno>
            </person>
            """
        let entry = PersonsCompleteOverlay.parseEntry(chunk)
        #expect(entry.wikidata == "Q5660906", "the bare id, not the -URL sibling")
        #expect(entry.viaf == "69005565")
        #expect(entry.role == "Assistant Secretary of State for Near Eastern Affairs")
    }

    @Test("Identifier lookup is case-insensitive and never returns the -URL variant")
    func identifierMatchingIsCaseInsensitiveAndPrefersBareId() {
        // Both spellings must work: the drop uses `Wikidata`/`VIAF` today and nothing guarantees
        // the next one does. And a prefix match would store the URL for whichever came first.
        for spelling in ["Wikidata", "wikidata", "WIKIDATA"] {
            let chunk = "<person xml:id=\"X\"><idno type=\"\(spelling)\">Q1</idno>"
                + "<idno type=\"\(spelling)-URL\">https://example.org/Q1</idno></person>"
            #expect(PersonsCompleteOverlay.parseEntry(chunk).wikidata == "Q1", "\(spelling)")
        }
        // A `-URL`-only entry yields nothing rather than a URL where an id belongs.
        let urlOnly = #"<person xml:id="X"><idno type="Wikidata-URL">https://x/Q9</idno></person>"#
        #expect(PersonsCompleteOverlay.parseEntry(urlOnly).wikidata == nil)
    }

    @Test("Role text falls back to the bio note and collapses the source's hard wrapping")
    func roleFallsBackAndCollapses() {
        // The source hard-wraps inside the element; without collapsing, newlines reach the UI
        // mid-sentence.
        let chunk = """
            <person xml:id="FRUS-00200">
              <persName type="main">Adams, Samuel Clifford, Jr.</persName>
              <note type="bio">Non-career appointee. Ambassador Extraordinary and Plenipotentiary
                  (Niger).</note>
              <idno type="people-id">100104</idno>
            </person>
            """
        let entry = PersonsCompleteOverlay.parseEntry(chunk)
        #expect(entry.role == "Non-career appointee. Ambassador Extraordinary and Plenipotentiary (Niger).")
    }

    @Test("Occupation wins over the bio note, because upstream duplicates them")
    func occupationWinsOverBio() {
        let chunk = """
            <person xml:id="FRUS-1"><occupation>Chief, ECA Mission</occupation>
            <note type="bio">Chief, ECA Mission</note><idno type="people-id">1</idno></person>
            """
        #expect(PersonsCompleteOverlay.parseEntry(chunk).role == "Chief, ECA Mission")
    }

    // MARK: - The audit guard

    let auditCSV = """
        pid_a,name_a,years_a,pid_b,name_b,years_b,auto_merge_reason,year_overlap,name_signal,occ_token_jaccard,verdict,review_type,rationale
        FRUS-00609,"al-Khalifa, Shaikh Hamad ibn Isa",,FRUS-00611,"al-Khalifa, Shaikh Mohammad",,name,,,,unmerge,model,"Different people, one is the Amir"
        FRUS-01480,"Austin, Robert D.",,FRUS-01481,"Austin, Robert J.",,name,,,,uncertain,model,"Middle initial differs"
        FRUS-03000,"Keeper, A.",,FRUS-03001,"Keeper, A.",,name,,,,keep,model,"Same person"
        """

    @Test("The guard resolves the CSV's xml:ids to people-ids inside the same file")
    func auditGuardResolvesThroughEntries() {
        // The CSV keys on FRUS-NNNNN, which the joining rules forbid relying on across file
        // versions. Resolving them through THIS file's entries is the only correspondence that
        // exists, which is why the runner pins the result in provenance.
        let entries = [
            PersonsCompleteOverlay.parseEntry(
                #"<person xml:id="FRUS-00609"><idno type="people-id">100609</idno></person>"#),
            PersonsCompleteOverlay.parseEntry(
                #"<person xml:id="FRUS-00611"><idno type="people-id">100611</idno></person>"#),
            PersonsCompleteOverlay.parseEntry(
                #"<person xml:id="FRUS-01480"><idno type="people-id">101480</idno></person>"#),
            PersonsCompleteOverlay.parseEntry(
                #"<person xml:id="FRUS-03000"><idno type="people-id">103000</idno></person>"#)
        ]
        let flagged = PersonsCompleteOverlay.flaggedPeopleIds(auditCSV: auditCSV, entries: entries)
        #expect(flagged == ["100609", "100611", "101480"])
        #expect(!flagged.contains("103000"), "a `keep` verdict is not a flag")
    }

    @Test("A CSV whose xml:ids match nothing yields an empty guard, not a silent pass")
    func auditGuardEmptyWhenIdsDoNotMatch() {
        // This is what a post-re-mint CSV looks like. The runner treats an empty result as fatal
        // rather than proceeding with an inert guard.
        let entries = [PersonsCompleteOverlay.parseEntry(
            #"<person xml:id="FRUS-99999"><idno type="people-id">1</idno></person>"#)]
        #expect(PersonsCompleteOverlay.flaggedPeopleIds(auditCSV: auditCSV, entries: entries).isEmpty)
    }

    @Test("A CSV with bare carriage-return line endings still parses")
    func auditGuardHandlesCRLineEndings() {
        // The shipped file uses classic-Mac `\r` endings. Splitting on `\n` makes the whole file
        // one row, so no verdict is ever matched and the guard passes zero ids — measured, it
        // reported `csvRows=1` over 1,662 real rows.
        let crOnly = auditCSV.replacingOccurrences(of: "\n", with: "\r")
        let entries = [
            PersonsCompleteOverlay.parseEntry(
                #"<person xml:id="FRUS-00609"><idno type="people-id">100609</idno></person>"#),
            PersonsCompleteOverlay.parseEntry(
                #"<person xml:id="FRUS-01480"><idno type="people-id">101480</idno></person>"#)
        ]
        let flagged = PersonsCompleteOverlay.flaggedPeopleIds(auditCSV: crOnly, entries: entries)
        #expect(flagged == ["100609", "101480"])

        // And CRLF, which the same split would leave a stray `\r` on.
        let crlf = auditCSV.replacingOccurrences(of: "\n", with: "\r\n")
        #expect(PersonsCompleteOverlay.flaggedPeopleIds(auditCSV: crlf, entries: entries)
                == ["100609", "101480"])
    }

    @Test("Quoted commas in the rationale column do not shift the verdict column")
    func csvHonoursQuotedFields() {
        // "Different people, one is the Amir" contains a comma; a naive split puts `model` where
        // the parser looks for the verdict and every flag is missed.
        let fields = PersonsCompleteOverlay.splitCSVRow(
            #"FRUS-1,"Doe, John",,FRUS-2,"Doe, J.",,name,,,,unmerge,model,"a, b, c""#)
        #expect(fields.count == 13)
        #expect(fields[10] == "unmerge")
    }

    // MARK: - Whole-file parse

    @Test("Parsing splits on person elements and keeps each entry's own idnos")
    func parsesWholeFile() {
        let xml = """
            <listPerson>
              <person xml:id="FRUS-1"><idno type="people-id">1</idno>
                <idno type="frus-ref">frus1861/persons#p_A1</idno></person>
              <person xml:id="FRUS-2"><idno type="people-id">2</idno>
                <idno type="frus-ref">frus1862/persons#p_B1</idno></person>
            </listPerson>
            """
        let entries = PersonsCompleteOverlay.parse(xml: xml)
        #expect(entries.count == 2)
        #expect(entries[0].peopleIds == ["1"])
        #expect(entries[1].anchors.first?.volumeId == "frus1862",
                "entry 2's anchor must not leak into entry 1")
    }
}
