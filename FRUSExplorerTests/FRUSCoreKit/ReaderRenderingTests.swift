// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - ReaderRenderingTests

/// The reader's lookups and converter (`ReaderRendering.swift`), which `DocumentViewModel.load`
/// and FRUS Explorer Light both render through. The page they produce is pinned by the web
/// edition's golden HTML; these pin the rules the lookups carry.
@Suite("Reader rendering — the lookups the reader resolves a document's links against")
struct ReaderRenderingTests {

    private let persons = [
        PersonEntry(ref: "p_AD1", name: "Acheson, Dean"),
        PersonEntry(ref: "p_KGF1", name: "Kennan, George F."),
        PersonEntry(ref: "p_AD1", name: "Acheson, Dean G."),
    ]

    private let terms = [
        GlossEntry(ref: "t_NSC1", term: "NSC", definition: "National Security Council"),
        GlossEntry(ref: "t_JCS1", term: "JCS", definition: "Joint Chiefs of Staff"),
        GlossEntry(ref: "t_NSC2", term: "nsc", definition: "the Council"),
    ]

    @Test("Persons and terms are keyed by ref, and terms by lowercased text; a repeated key keeps its last entry")
    func lookupsKeyTheEntries() {
        let lookups = ReaderLookups(persons: persons, terms: terms)
        #expect(lookups.personsByRef.count == 2)
        #expect(lookups.personsByRef["p_AD1"]?.name == "Acheson, Dean G.")
        #expect(lookups.termsByRef.count == 3)
        #expect(lookups.termsByRef["t_NSC1"]?.definition == "National Security Council")
        #expect(lookups.termsByText.count == 2)
        #expect(lookups.termsByText["nsc"]?.ref == "t_NSC2")
        #expect(lookups.termsByText["NSC"] == nil)
    }

    @Test("The reader's converter resolves persons and terms by ref, and an <abbr> by its text in any case")
    func converterResolvesThroughTheLookups() {
        let converter = ASTToRenderNodeConverter(
            readerOf: "frus1961-63v06", lookups: ReaderLookups(persons: persons, terms: terms), brokenRefs: nil)
        #expect(converter.volumeId == "frus1961-63v06")
        #expect(converter.personLookup?("p_KGF1")?.name == "Kennan, George F.")
        #expect(converter.personLookup?("p_none") == nil)
        #expect(converter.glossLookup?("t_JCS1")?.term == "JCS")
        #expect(converter.abbrLookup?("JcS")?.ref == "t_JCS1")
        #expect(converter.abbrLookup?("NSC")?.ref == "t_NSC2")
        // No index: nothing is degraded.
        #expect(converter.brokenRefLookup?("#dX") == nil)
    }

    @Test("A broken reference is degraded by the index for the converter's volume only")
    func brokenReferencesAreVolumeScoped() throws {
        let json = """
        {"schemaVersion":1,"generated":"2026-10-04","corpusVolumeCount":1,"seriesVolumeCount":1,\
        "totalBroken":1,"fullDetail":true,"records":[\
        {"sv":"frus1901","sd":"d1","t":"#dX","r":"unknownAnchor","rv":"frus1901","ra":"dX"}]}
        """
        let index = try JSONDecoder().decode(BrokenRefsIndex.self, from: Data(json.utf8))
        let lookups = ReaderLookups(persons: [], terms: [])
        let inVolume = ASTToRenderNodeConverter(readerOf: "frus1901", lookups: lookups, brokenRefs: index)
        #expect(inVolume.brokenRefLookup?("#dX")?.reason == "unknownAnchor")
        #expect(inVolume.brokenRefLookup?("#d1") == nil)
        let elsewhere = ASTToRenderNodeConverter(readerOf: "frus1902", lookups: lookups, brokenRefs: index)
        #expect(elsewhere.brokenRefLookup?("#dX") == nil)
    }
}

// MARK: - A document that names its people and terms on @ana (#1599)

/// 1981–88 vol. XVI names the people and terms each document mentions on the document div's
/// `ana` attribute and marks none of them in the text. These tests follow one such document from
/// the file to the three places it has to arrive: the parse, the index's person mentions, and the
/// two lists the reader writes below it.
///
/// The fixture's first document names two people and three terms that the volume's lists hold,
/// and, each once: a person twice, an id no list holds, and a person in another file's list.
@Suite("A document names its people and terms on @ana (#1599)")
struct NamedReferencesTests {

    private static let volumeId = "frus1981-88v16"

    /// What `d1`'s `ana` holds, in the order written.
    private static let pointers = [
        "#p_ARVD_1", "#p_BF_1", "#t_EXDIS_1", "#t_OAS_1", "#t_RD_1",
        "#p_ARVD_1", "#x_NOLIST_1", "frus1981-88v11#p_HAMJ_1",
    ]

    private static func volumeXML(d1Ana: String?) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt></fileDesc></teiHeader>
          <text>
            <front>
              <div type="section" xml:id="persons"><head>Persons</head>
                <list>
                  <item><hi rend="strong"><persName xml:id="p_ARVD_1">Allen, Richard V. “Dick”</persName></hi>, Assistant to the President</item>
                  <item><hi rend="strong"><persName xml:id="p_BF_1">Belaúnde Terry, Fernando</persName></hi>, President of Peru</item>
                  <item><hi rend="strong"><persName xml:id="p_HAMJ_1">Haig, Alexander Meigs, Jr.</persName></hi>, Secretary of State</item>
                </list>
              </div>
              <div type="section" xml:id="terms"><head>Abbreviations and Terms</head>
                <list>
                  <item><term xml:id="t_EXDIS_1">Exdis</term>, exclusive distribution</item>
                  <item><term xml:id="t_OAS_1">OAS</term>, Organization of American States</item>
                  <item><term xml:id="t_RD_1">R&amp;D</term>, research and development</item>
                </list>
              </div>
            </front>
            <body>
              <div type="chapter" xml:id="ch7"><head>Ecuador</head>
                <div type="document" xml:id="d1" n="1"\(d1Ana.map { " ana=\"\($0)\"" } ?? "")>
                  <head>1. Telegram From the Department of State</head>
                  <p>The Secretary met the President.<note n="1" xml:id="d1fn1" type="source">Source: Department of State.</note></p>
                </div>
                <div type="document" xml:id="d2" n="2">
                  <head>2. Memorandum</head>
                  <p>A call on <persName corresp="#p_BF_1">Belaúnde</persName>.</p>
                </div>
                <div type="document" xml:id="d3" n="3" ana="#p_BF_1 #p_HAMJ_1">
                  <head>3. Telegram</head>
                  <p><persName corresp="#p_BF_1">Belaúnde</persName> replied.</p>
                </div>
                <div type="document" xml:id="d4" n="4" ana="#t_OAS_1">
                  <head>4. Note</head>
                  <p>Text.</p>
                </div>
              </div>
            </body>
          </text>
        </TEI>
        """
    }

    /// A folder holding the fixture as the volume's file.
    private func makeVolume(d1Ana: String? = NamedReferencesTests.pointers.joined(separator: " ")) throws
        -> (dir: URL, url: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSNamedRefs-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let url = volumes.appendingPathComponent("\(Self.volumeId).xml")
        try Self.volumeXML(d1Ana: d1Ana).write(to: url, atomically: true, encoding: .utf8)
        return (dir, url)
    }

    /// The model the reader's converter makes of `documentId`, through the volume's own lists.
    private func readerModel(of documentId: String, in url: URL) async throws -> FRUSDocumentRenderModel {
        let parser = FRUSDocumentParser()
        let full = try await parser.parseVolumeFull(volumeURL: url)
        // The reader parses the one document it opens.
        let document = try #require(try await parser.parseDocument(documentId: documentId, volumeURL: url))
        var converter = ASTToRenderNodeConverter(
            readerOf: Self.volumeId,
            lookups: ReaderLookups(persons: full.persons, terms: full.terms), brokenRefs: nil)
        return converter.convert(document)
    }

    // MARK: The parse

    @Test("The parse carries the pointers as written, and none for a document without the attribute")
    func theParseCarriesThePointers() async throws {
        let (dir, url) = try makeVolume()
        defer { try? FileManager.default.removeItem(at: dir) }
        let documents = try await FRUSDocumentParser().parse(volumeURL: url)
        let byId = Dictionary(uniqueKeysWithValues: documents.map { ($0.documentId, $0) })
        #expect(byId["d1"]?.annotatedReferences == Self.pointers)
        #expect(byId["d2"]?.annotatedReferences == [])
        #expect(byId["d3"]?.annotatedReferences == ["#p_BF_1", "#p_HAMJ_1"])
        // The reader's parse of one document carries them too.
        let one = try #require(try await FRUSDocumentParser().parseDocument(documentId: "d1", volumeURL: url))
        #expect(one.annotatedReferences == Self.pointers)
    }

    @Test("A copy of the document keeps its pointers")
    func copiesKeepThePointers() {
        let document = FRUSDocumentAST(documentId: "d1", nodes: [.paragraph(children: [.text("Text.")])],
                                       annotatedReferences: ["#p_BF_1"])
        #expect(document.carrying([]).annotatedReferences == ["#p_BF_1"])
        #expect(document.applyingClassificationOverride(isEditorialNote: true).annotatedReferences
                == ["#p_BF_1"])
    }

    @Test("A pointer names an id of its own volume, and nothing in another file")
    func whatAPointerNames() {
        #expect(FRUSDocumentAST.annotatedId("#p_BF_1") == "p_BF_1")
        #expect(FRUSDocumentAST.annotatedId("p_BF_1") == "p_BF_1")
        #expect(FRUSDocumentAST.annotatedId("frus1981-88v11#p_BF_1") == nil)
        #expect(FRUSDocumentAST.annotatedId("#") == nil)
        #expect(FRUSDocumentAST.annotatedId("") == nil)
        #expect(FRUSDocumentAST.annotatedPointers(" #p_BF_1\n   #t_OAS_1 ") == ["#p_BF_1", "#t_OAS_1"])
        #expect(FRUSDocumentAST.annotatedPointers(nil) == [])
    }

    // MARK: The index

    @Test("A person mention is a pointer the volume's persons list holds")
    func whichPointersArePersons() {
        let listed: Set<String> = ["p_ARVD_1", "p_BF_1", "p_HAMJ_1"]
        // One pointer for each way of not being one: a term, an id no list holds, and a person of
        // this list named through another file.
        #expect(IndexingPipeline.annotatedPersonRefs(["#p_BF_1"], persons: listed) == ["p_BF_1"])
        #expect(IndexingPipeline.annotatedPersonRefs(["#t_OAS_1"], persons: listed) == [])
        #expect(IndexingPipeline.annotatedPersonRefs(["#p_NOLIST_1"], persons: listed) == [])
        #expect(IndexingPipeline.annotatedPersonRefs(["frus1981-88v11#p_HAMJ_1"], persons: listed) == [])
        #expect(IndexingPipeline.annotatedPersonRefs(Self.pointers, persons: listed) == ["p_ARVD_1", "p_BF_1"])
    }

    @Test("Indexing stores the mentions, beside the ones the text marks")
    func indexingStoresTheMentions() async throws {
        let (dir, _) = try makeVolume()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        try await pipeline.indexVolume(Self.volumeId)
        let mentions = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
        func persons(_ documentId: String) async throws -> [String] {
            try await mentions.personRefs(forDocumentId: documentId, volumeId: Self.volumeId)
        }
        // Named on `@ana` alone: the two its list holds, the repeated one once.
        #expect(try await persons("d1") == ["p_ARVD_1", "p_BF_1"])
        // Marked in the text alone, as before.
        #expect(try await persons("d2") == ["p_BF_1"])
        // Both ways: the person named twice is one mention.
        #expect(try await persons("d3") == ["p_BF_1", "p_HAMJ_1"])
        // Terms alone: no person.
        #expect(try await persons("d4") == [])
    }

    // MARK: The reader

    @Test("The reader lists the persons and the terms below the document, each as its link")
    func theReaderListsThem() async throws {
        let (dir, url) = try makeVolume()
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = try await readerModel(of: "d1", in: url)
        // Each pointer once, in the document's order, as the entry of the volume's own list.
        #expect(model.listedReferences.persons.map(\.ref) == ["p_ARVD_1", "p_BF_1"])
        #expect(model.listedReferences.persons.map(\.name)
                == ["Allen, Richard V. “Dick”", "Belaúnde Terry, Fernando"])
        #expect(model.listedReferences.persons.first?.description?.contains("Assistant to the President") == true)
        #expect(model.listedReferences.terms.map(\.ref) == ["t_EXDIS_1", "t_OAS_1", "t_RD_1"])
        #expect(model.listedReferences.terms.map(\.term) == ["Exdis", "OAS", "R&D"])
        #expect(model.listedReferences.terms.first?.definition == "exclusive distribution")

        let page = FRUSRenderNodeHTMLSerializer.reader.serialize(model)
        let section = """
            <section class="named-references"><hr class="fn-rule">\
            <h2 class="fn-section-heading">Persons</h2><ul class="named-list">\
            <li><a class="pers-name" href="frusexplorer://person/p_ARVD_1">Allen, Richard V. “Dick”</a></li>\
            <li><a class="pers-name" href="frusexplorer://person/p_BF_1">Belaúnde Terry, Fernando</a></li></ul>\
            <h2 class="fn-section-heading">Abbreviations &amp; Terms</h2><ul class="named-list">\
            <li><a class="gloss" href="frusexplorer://gloss/t_EXDIS_1">Exdis</a></li>\
            <li><a class="gloss" href="frusexplorer://gloss/t_OAS_1">OAS</a></li>\
            <li><a class="gloss" href="frusexplorer://gloss/t_RD_1">R&amp;D</a></li></ul></section>
            """
        // After everything the document prints, its footnotes section included.
        #expect(page.hasSuffix("</ol></section>" + section))
        #expect(page.components(separatedBy: "named-references").count == 2)
        // The reader's other serializer, a host's own, writes the same lists.
        let hosted = FRUSRenderNodeHTMLSerializer.reader(figureURL: { _ in nil }).serialize(model)
        #expect(hosted.hasSuffix(section))
    }

    @Test("Each link is one the reader answers")
    func theLinksAreReaderLinks() throws {
        #expect(FRUSURLScheme.readerLink(from: try #require(URL(string: "frusexplorer://person/p_ARVD_1")))
                == .person(ref: "p_ARVD_1"))
        #expect(FRUSURLScheme.readerLink(from: try #require(URL(string: "frusexplorer://gloss/t_EXDIS_1")))
                == .gloss(ref: "t_EXDIS_1"))
    }

    #if !SWIFT_PACKAGE // FRUSURLSchemeHandler is the app's
    /// The app answers a tap from the model it registered, which until this held only the links
    /// in the body and the footnotes: on an iPhone the first build of the lists opened "Person
    /// Information Unavailable" for every name. This drives the handler the web view calls.
    @Test("A tap on a listed person or term gives the app the volume's own entry")
    @MainActor
    func theAppAnswersATapOnAListedEntry() async throws {
        let (dir, url) = try makeVolume()
        defer { try? FileManager.default.removeItem(at: dir) }
        let handler = FRUSURLSchemeHandler()
        handler.register(model: try await readerModel(of: "d1", in: url))

        var person: PersonEntry?, term: GlossEntry?
        var personCalls = 0, termCalls = 0
        handler.onPersonTap = { person = $0; personCalls += 1 }
        handler.onGlossTap = { term = $0; termCalls += 1 }

        handler.dispatch(url: try #require(URL(string: "frusexplorer://person/p_BF_1")))
        #expect(personCalls == 1)
        #expect(person?.name == "Belaúnde Terry, Fernando")
        #expect(person?.description?.contains("President of Peru") == true)

        handler.dispatch(url: try #require(URL(string: "frusexplorer://gloss/t_OAS_1")))
        #expect(termCalls == 1)
        #expect(term?.term == "OAS")
        #expect(term?.definition == "Organization of American States")

        // A person the document does not name is still not one of its page's.
        handler.dispatch(url: try #require(URL(string: "frusexplorer://person/p_HAMJ_1")))
        #expect(personCalls == 2 && person == nil)
    }
    #endif

    @Test("A document that names only terms has no Persons heading, and one that names nothing has no lists")
    func onlyWhatIsNamed() async throws {
        let (dir, url) = try makeVolume()
        defer { try? FileManager.default.removeItem(at: dir) }
        let termsOnly = FRUSRenderNodeHTMLSerializer.reader.serialize(try await readerModel(of: "d4", in: url))
        #expect(termsOnly.hasSuffix("""
            <section class="named-references"><hr class="fn-rule">\
            <h2 class="fn-section-heading">Abbreviations &amp; Terms</h2><ul class="named-list">\
            <li><a class="gloss" href="frusexplorer://gloss/t_OAS_1">OAS</a></li></ul></section>
            """))
        #expect(!termsOnly.contains(">Persons<"))

        let unnamed = try await readerModel(of: "d2", in: url)
        #expect(unnamed.listedReferences.isEmpty)
        #expect(!FRUSRenderNodeHTMLSerializer.reader.serialize(unnamed).contains("named-references"))
    }

    @Test("An export writes no lists, and a converter with no lookups resolves none")
    func exportsAreUnchanged() async throws {
        let (dir, url) = try makeVolume()
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = try await readerModel(of: "d1", in: url)
        #expect(!model.listedReferences.isEmpty)
        #expect(!FRUSRenderNodeHTMLSerializer().serialize(model).contains("named-references"))

        let document = try #require(try await FRUSDocumentParser().parseDocument(documentId: "d1", volumeURL: url))
        var bare = ASTToRenderNodeConverter(volumeId: Self.volumeId)
        #expect(bare.convert(document).listedReferences.isEmpty)
    }

    @Test("The lists are no part of the document's text: its rendering version does not move")
    func theFlatTextIsUnchanged() async throws {
        let (dir, url) = try makeVolume()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (plainDir, plainURL) = try makeVolume(d1Ana: nil)
        defer { try? FileManager.default.removeItem(at: plainDir) }
        let named = try await readerModel(of: "d1", in: url)
        let plain = try await readerModel(of: "d1", in: plainURL)
        #expect(!named.listedReferences.isEmpty && plain.listedReferences.isEmpty)
        #expect(ASTToRenderNodeConverter.renderingVersion(for: named)
                == ASTToRenderNodeConverter.renderingVersion(for: plain))
        // And the body the offset engine walks is byte for byte the same.
        let namedPage = FRUSRenderNodeHTMLSerializer.reader.serialize(named)
        let plainPage = FRUSRenderNodeHTMLSerializer.reader.serialize(plain)
        #expect(namedPage.hasPrefix(plainPage))
    }
}
