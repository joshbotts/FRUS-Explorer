import Foundation

// Harness around the app's REAL CentralFilesClassifier / GeoKeyNormalizer / CentralFilesIndex /
// VolumeStructure sources. Two modes:
//   harness selftest
//   harness run <export.jsonl> <docs-out.jsonl> <volumes-out.jsonl>
//
// `resolveAsSourceExplorer` mirrors SourceExplorerView.resolveCountrySeries (lines 979-1019) and
// its twin MacSourceExplorerView.resolveCountrySeries (lines 1479-1523) statement for statement,
// minus the async pipeline fetch (the structure comes from the same volume_structures row the
// pipeline's cachedVolumeStructure decodes with JSONDecoder) and minus the enclosure pass.

// MARK: - The document-level resolution, as Source Explorer runs it

struct Resolution {
    let classification: CentralFilesClassification
    let rolls: [CountryRoll]
}

struct Outcome {
    var gate: String            // "ok" or the early-exit reason
    var year: Int?
    var dateISO: String?
    var path: [String] = []
    var chosenTitleIndex: Int?  // index into path of the title whose iteration first produced rolls
    var resolutions: [Resolution] = []
}

func resolveAsSourceExplorer(header: String?, dateline: String?, structure: VolumeStructure?,
                             documentId: String, index: CentralFilesIndex?) -> Outcome {
    // documentYear = DocumentView.extractYear(from: entry.dateline)
    let year = AppYearGate.extractYear(from: dateline)
    var o = Outcome(gate: "ok", year: year, dateISO: nil)
    guard let dateline else { o.gate = "noDateline"; return o }
    guard let year else { o.gate = "noYear"; return o }
    guard year < 1906 else { o.gate = "year>=1906"; return o }
    guard let index else { o.gate = "noIndex"; return o }
    var path: [String] = []
    if let structure {
        path = CentralFilesClassifier.documentSectionPath(in: structure, documentId: documentId)
    }
    o.path = path
    guard !path.isEmpty else { o.gate = "noSectionPath"; return o }

    let dateISO = CentralFilesClassifier.datelineDateISO(from: dateline)
    o.dateISO = dateISO
    var resolutions: [Resolution] = []
    for (i, title) in path.enumerated() where resolutions.isEmpty {
        let classifications = CentralFilesClassifier.classify(
            header: header ?? "", dateline: dateline, chapterCountry: title)
        for classification in classifications {
            guard let series = index.series(category: classification.category) else { continue }
            let rolls: [CountryRoll]
            if classification.category.isChronologicalRun {
                guard let dateISO else { continue }
                rolls = series.rolls(containingDate: dateISO)
            } else {
                guard let geoKey = classification.geoKeys.first else { continue }
                rolls = series.rolls(geoKey: geoKey, dateISO: dateISO)
            }
            if !rolls.isEmpty {
                resolutions.append(Resolution(classification: classification, rolls: rolls))
            }
        }
        if !resolutions.isEmpty && o.chosenTitleIndex == nil { o.chosenTitleIndex = i }
    }
    o.resolutions = resolutions
    return o
}

// MARK: - Helpers

func classJSON(_ c: CentralFilesClassification, rolls: [CountryRoll]? = nil) -> [String: Any] {
    var d: [String: Any] = [
        "category": c.category.rawValue,
        "chronologicalRun": c.category.isChronologicalRun,
        "geoKeys": c.geoKeys,
        "confidence": c.confidence == .high ? "high" : "medium",
    ]
    if c.category == .consularDespatches { d["consularPostKey"] = c.geoKeys.first ?? NSNull() }
    if let rolls {
        d["rollCount"] = rolls.count
        d["rollNaIds"] = Array(rolls.prefix(5).map(\.naId))
    }
    return d
}

func jsonLine(_ obj: [String: Any]) -> Data {
    var data = try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes])
    data.append(0x0A)
    return data
}

let diplomaticGeoCategories: [CentralFilesSeriesCategory] = [.despatches, .instructions, .notesFrom, .notesTo]

func geoVocabulary(_ index: CentralFilesIndex, _ cats: [CentralFilesSeriesCategory]) -> Set<String> {
    var s = Set<String>()
    for c in cats { for r in index.series(category: c)?.rolls ?? [] { s.formUnion(r.geoKeys) } }
    return s
}

// MARK: - Self-test (positive controls from the unit tests)

var failures = 0
var checks = 0
@MainActor func check(_ ok: Bool, _ label: String) {
    checks += 1
    if ok { print("PASS  \(label)") } else { failures += 1; print("FAIL  \(label)") }
}

@MainActor func selftest() {
    typealias C = CentralFilesClassifier
    let index = CentralFilesIndexStore.shared
    check(index != nil, "CentralFilesIndexStore.shared loaded via Bundle.main")

    // CentralFilesClassifierTests.classifiesDespatch
    let d4 = C.classify(header: "Minister Griscom to the Secretary of State.",
                        dateline: "American Legation, Tokyo, March 14, 1905.", chapterCountry: "Japan")
    check(d4.count == 1 && d4.first?.category == .despatches && d4.first?.geoKeys == ["japan"]
          && d4.first?.confidence == .high, "classifiesDespatch d4 -> despatches/japan/high")
    let d5 = C.classify(header: "No. 302. Mr. Rublee to Mr. Fish.",
                        dateline: "Legation of the United States, Berne, September 28, 1875.",
                        chapterCountry: "Switzerland")
    check(d5.first?.category == .despatches && d5.first?.geoKeys == ["switzerland"], "classifiesDespatch d5 -> despatches/switzerland")
    // classifiesNoteFrom
    let d2 = C.classify(header: "Dr. Lobo to Mr. Gresham.",
                        dateline: "Legation of Venezuela, Washington, October 26, 1893.", chapterCountry: "Venezuela")
    check(d2.count == 1 && d2.first?.category == .notesFrom && d2.first?.geoKeys == ["venezuela"]
          && d2.first?.confidence == .high, "classifiesNoteFrom d2 -> notesFrom/venezuela/high")
    // classifiesDeptOutbound
    let d1 = C.classify(header: "Mr. Seward to Mr. Adams.",
                        dateline: "Department of State, Washington, July 6, 1863.", chapterCountry: "Great Britain")
    check(d1.map(\.category) == [.instructions, .notesTo] && d1.allSatisfy { $0.geoKeys == ["great britain"] }
          && d1.allSatisfy { $0.confidence == .medium }, "classifiesDeptOutbound d1 -> [instructions, notesTo]/great britain/medium")
    let d3 = C.classify(header: "No. 407. Mr. Evarts to Dr. Aceval.",
                        dateline: "Department of State, Washington, November 13, 1878.", chapterCountry: "Paraguay")
    check(d3.map(\.category) == [.instructions, .notesTo] && d3.first?.geoKeys == ["paraguay"], "classifiesDeptOutbound d3 -> paraguay")
    // classifiesConsular
    let cons = C.classify(header: "Mr. Springer to Mr. Uhl.",
                          dateline: "Consulate-General, of the United States, Havana, June 19, 1895.", chapterCountry: "Spain")
    check(cons.count == 1 && cons.first?.category == .consularDespatches && cons.first?.geoKeys == ["havana"]
          && cons.first?.confidence == .high, "classifiesConsular -> consularDespatches/havana/high")
    // consularPostKeyExtraction
    check(C.consularPostKey(fromDateline: "Consulate-General, of the United States, Havana, June 19, 1895.") == "havana", "consularPostKey havana")
    check(C.consularPostKey(fromDateline: "American Consulate, Amoy, March 2, 1899.") == "amoy", "consularPostKey amoy")
    check(C.consularPostKey(fromDateline: "Consulate of the United States at Canton, July 4, 1860.") == "canton", "consularPostKey canton (at-form)")
    check(C.consularPostKey(fromDateline: "no consulate city here") == nil, "consularPostKey nil")
    // noCountryNoClassification
    check(C.classify(header: "Mr. X to Mr. Y.", dateline: "American Legation, Tokyo, March 14, 1905.", chapterCountry: nil).isEmpty,
          "noCountryNoClassification")
    // classifiesBareCityDespatch
    let d6 = C.classify(header: "Mr. Dayton to Mr. Seward.", dateline: "Paris, December 11, 1863.", chapterCountry: "France")
    check(d6.count == 1 && d6.first?.category == .despatches && d6.first?.geoKeys == ["france"] && d6.first?.confidence == .medium,
          "classifiesBareCityDespatch -> despatches/france/medium")
    check(C.classify(header: "Mr. Seward to Mr. Dayton.", dateline: "Department of State, Washington, December 11, 1863.",
                     chapterCountry: "France").map(\.category) == [.instructions, .notesTo], "bare-city control: outbound not swept")
    // parsesDatelineDate
    check(C.datelineDateISO(from: "Legation of the United States, Buenos Ayres, February 3, 1900.") == "1900-02-03", "datelineDateISO 1900-02-03")
    check(C.datelineDateISO(from: "Legation of the United States, Berne, September 28, 1875. (Received October 14.)") == "1875-09-28", "datelineDateISO ignores Received")
    check(C.datelineDateISO(from: "no date here") == nil, "datelineDateISO nil")
    // resolvesSectionPath
    let sub = VolumeSection(sectionId: "sc1", divType: "subchapter", title: "Correspondence respecting the capture of the Saxon.",
                            documentIds: ["d229"], subsections: [])
    let ctry = VolumeSection(sectionId: "ch1", divType: "chapter", title: "Great Britain.", documentIds: [], subsections: [sub])
    let comp = VolumeSection(sectionId: "comp1", divType: "compilation", title: "Correspondence.", documentIds: [], subsections: [ctry])
    let st = VolumeStructure(volumeId: "frus1864p1", sections: [comp])
    check(C.documentSectionPath(in: st, documentId: "d229") == ["Correspondence.", "Great Britain.", "Correspondence respecting the capture of the Saxon."],
          "documentSectionPath nested chain")
    check(C.documentSectionPath(in: st, documentId: "d999").isEmpty, "documentSectionPath miss -> []")
    // End to end against the bundled index
    if let index {
        let r5 = index.series(category: .despatches)?.rolls(geoKey: "switzerland", dateISO: "1875-09-28") ?? []
        check(r5.contains { $0.naId == "189376306" }, "end-to-end d5 roll 189376306")
        let ri = index.series(category: .instructions)?.rolls(geoKey: "great britain", dateISO: "1863-07-06") ?? []
        check(ri.contains { $0.naId == "149311973" }, "end-to-end d1 instruction roll 149311973")
        let rn = index.series(category: .notesFrom)?.rolls(geoKey: "venezuela", dateISO: "1893-10-26") ?? []
        check(rn.contains { $0.naId == "188287901" }, "end-to-end d2 notesFrom roll 188287901")
        let rp = index.series(category: .despatches)?.rolls(geoKey: "france", dateISO: "1863-12-11") ?? []
        check(rp.contains { $0.naId == "188687259" }, "end-to-end Paris despatch roll 188687259")
        // Same Paris doc through the full Source Explorer mirror with a two-level structure.
        let parisSec = VolumeSection(sectionId: "c", divType: "chapter", title: "France.", documentIds: ["d6"], subsections: [])
        let parisComp = VolumeSection(sectionId: "k", divType: "compilation", title: "Correspondence.", documentIds: [], subsections: [parisSec])
        let o = resolveAsSourceExplorer(header: "Mr. Dayton to Mr. Seward.", dateline: "Paris, December 11, 1863.",
                                        structure: VolumeStructure(volumeId: "frus1864p3", sections: [parisComp]),
                                        documentId: "d6", index: index)
        check(o.gate == "ok" && o.chosenTitleIndex == 1 && o.resolutions.first?.rolls.contains { $0.naId == "188687259" } == true,
              "mirror: Correspondence. falls through, France. chosen, roll 188687259")
    }
    // ConsularTailClassifierTests
    for dl in ["Consulate-General of Spain, New York, June 5, 1895.", "Spanish Consulate-General, Washington, June 5, 1895.",
               "British Consulate, New York, March 2, 1880."] {
        let c = C.classify(header: "The Spanish consul to Mr. Olney.", dateline: dl, chapterCountry: "Spain")
        check(c.map(\.category) == [.notesFromForeignConsuls] && c.first?.geoKeys.isEmpty == true && c.first?.confidence == .high,
              "foreign consulate -> notesFromForeignConsuls: \(dl)")
    }
    for dl in ["Consulate-General, of the United States, Havana, June 19, 1895.", "United States Consulate, Amoy, March 2, 1899.",
               "American Consulate, Amoy, March 2, 1899.", "Consulate of the United States at Canton, July 4, 1860."] {
        check(!C.isForeignConsulateDateline(dl.lowercased()), "US consulate not foreign: \(dl)")
    }
    check(!C.isForeignConsulateDateline("consulate-general, havana, june 19, 1895."), "bare consulate not foreign")
    let pair = C.classify(header: "Mr. Fish to the consul at Havana.", dateline: "Department of State, Washington, July 6, 1873.", chapterCountry: "Spain")
    check(pair.map(\.category) == [.instructions, .notesTo, .consularInstructions, .notesToForeignConsuls], "dept outbound + consul header -> 4 candidates")
    check(C.classify(header: "Mr. Fish to the consul at Havana.", dateline: "Department of State, Washington, July 6, 1873.",
                     chapterCountry: nil).map(\.category) == [.consularInstructions, .notesToForeignConsuls], "consul pair without country")
    // DomesticAndSpecialAgentClassifierTests
    for dl in ["War Department, Washington, March 3, 1898.", "Treasury Department, Washington, July 1, 1885.", "Navy Department, Washington, May 2, 1861."] {
        let c = C.classify(header: "The Secretary of War to Mr. Sherman.", dateline: dl, chapterCountry: "Spain")
        check(c.map(\.category) == [.lettersReceived] && c.first?.confidence == .high, "letters received: \(dl)")
    }
    let dom = C.classify(header: "Mr. Sherman to the Secretary of War.", dateline: "Department of State, Washington, March 5, 1898.", chapterCountry: "Spain")
    check(dom.map(\.category).contains(.domesticLetters) && Array(dom.map(\.category).prefix(2)) == [.instructions, .notesTo], "domestic letter candidate")
    check(!C.domesticAddressee(inHeader: "the secretary of war to mr. sherman.") && C.domesticAddressee(inHeader: "mr. sherman to the secretary of war."),
          "domestic addressee direction")
    check(C.classify(header: "Mr. Webster to Mr. Cushing, Special Commissioner.", dateline: "Department of State, Washington, May 8, 1843.",
                     chapterCountry: "China").map(\.category) == [.specialAgentsInstructions], "special agent instruction")
    let sa = C.classify(header: "Mr. Blount, Special Commissioner, to Mr. Gresham.", dateline: "Honolulu, April 26, 1893.", chapterCountry: "Hawaii")
    check(sa.map(\.category) == [.specialAgentsDespatches] && sa.first?.geoKeys.isEmpty == true, "special agent despatch")
    // EnclosureDualHomeTests.enclosureHomesRefuseAParentDerivedCountry
    let homes = C.enclosureHomes(openers: [
        IndexingPipeline.EnclosureOpener(label: "1", header: "Mr. Springer to Mr. Uhl", dateline: "Consulate-General, of the United States, Havana, June 19, 1895."),
        IndexingPipeline.EnclosureOpener(label: "2", header: "Mr. Smith to Mr. Jones", dateline: "Paris, December 11, 1863."),
    ])
    check(homes.contains { $0.part == .enclosure(label: "1") && !$0.classification.geoKeys.isEmpty }
          && !homes.contains { $0.part == .enclosure(label: "2") && !$0.classification.geoKeys.isEmpty }, "enclosureHomes narrowing")
    // CentralFilesClassifierTests.extractYearCoversPre1906Datelines (through the extracted DocumentView.extractYear)
    let years: [(String?, Int?)] = [
        ("Department of State, Washington, November 30, 1862.", 1862), ("Department of State, Washington, July 6, 1863.", 1863),
        ("Legation of the United States, Berne, September 28, 1875.", 1875), ("American Legation, Tokyo, March 14, 1905.", 1905),
        ("Washington, January 1, 1899.", 1899), ("Washington, January 1, 1900.", 1900), ("Washington, January 1, 1906.", 1906),
        ("Washington, January 1, 1910.", 1910), ("Washington, January 1, 2029.", 2029), ("Meeting held in room 2030.", nil),
        ("An antique note dated 1799.", nil), ("Department of State, Washington.", nil), ("Ref. telegram No. 1805. Tokyo, March 14, 1905.", 1905),
    ]
    for (dl, y) in years { check(AppYearGate.extractYear(from: dl) == y, "extractYear \(dl ?? "nil") -> \(y.map(String.init) ?? "nil")") }
    print("selftest: \(checks - failures)/\(checks) passed")
    exit(failures == 0 ? 0 : 1)
}

// MARK: - Corpus run

@MainActor func run(exportPath: String, docsOut: String, volsOut: String) {
    guard let index = CentralFilesIndexStore.shared else { fatalError("central-files-index.json did not load") }
    let diploVocab = geoVocabulary(index, diplomaticGeoCategories)
    let consularVocab = geoVocabulary(index, [.consularDespatches])
    FileManager.default.createFile(atPath: docsOut, contents: nil)
    FileManager.default.createFile(atPath: volsOut, contents: nil)
    let docsFH = FileHandle(forWritingAtPath: docsOut)!
    let volsFH = FileHandle(forWritingAtPath: volsOut)!
    let text = try! String(contentsOfFile: exportPath, encoding: .utf8)
    var nDocs = 0
    for line in text.split(separator: "\n") {
        let v = try! JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
        let volume = v["volume"] as! String
        var structure: VolumeStructure? = nil
        var structureDecode = "absent"
        if let sj = v["structure_json"] as? String {
            // IndexingPipeline.cachedVolumeStructure: try? JSONDecoder().decode(VolumeStructure.self, ...)
            structure = try? JSONDecoder().decode(VolumeStructure.self, from: Data(sj.utf8))
            structureDecode = structure == nil ? "failed" : "ok"
        }
        // Volume-level arrangement: every section title (any depth) whose normalized keys hit a
        // geo key served by a diplomatic-series roll.
        var countryTitles: [String: [String]] = [:]
        var unmatchedTopTitles: [String] = []
        var docsUnderCountry = Set<String>()
        var docsInStructure = Set<String>()
        func walk(_ sections: [VolumeSection], depth: Int, underCountry: Bool) {
            for s in sections {
                // The app looks rolls up with geoKeys.first only (SourceExplorerView ~line 1011).
                let first = GeoKeyNormalizer.keys(from: s.title).first
                let isCountry = first.map { diploVocab.contains($0) } ?? false
                if isCountry { countryTitles[s.title] = [first!] }
                else if depth <= 1 && !s.isFrontMatterKind && s.divType != "back" && unmatchedTopTitles.count < 40 { unmatchedTopTitles.append("\(s.divType):\(s.title)") }
                for d in s.documentIds {
                    docsInStructure.insert(d)
                    if isCountry || underCountry { docsUnderCountry.insert(d) }
                }
                walk(s.subsections, depth: depth + 1, underCountry: underCountry || isCountry)
            }
        }
        if let structure { walk(structure.sections, depth: 0, underCountry: false) }

        let docs = v["docs"] as! [[String: Any]]
        for doc in docs {
            let d = doc["d"] as! String
            let header = doc["header"] as? String
            let dateline = doc["dateline"] as? String
            let o = resolveAsSourceExplorer(header: header, dateline: dateline, structure: structure, documentId: d, index: index)
            var byTitle: [[String: Any]] = []
            let path = o.path.isEmpty ? (structure.map { CentralFilesClassifier.documentSectionPath(in: $0, documentId: d) } ?? []) : o.path
            if let dateline {
                for title in path {
                    let cs = CentralFilesClassifier.classify(header: header ?? "", dateline: dateline, chapterCountry: title)
                    byTitle.append([
                        "title": title,
                        "titleGeoKeys": GeoKeyNormalizer.keys(from: title),
                        "titleKeyServedByDiplomaticRoll": GeoKeyNormalizer.keys(from: title).first.map { diploVocab.contains($0) } ?? false,
                        "titleAnyKeyServedByDiplomaticRoll": GeoKeyNormalizer.keys(from: title).contains { diploVocab.contains($0) },
                        "classifications": cs.map { c -> [String: Any] in
                            var rolls: [CountryRoll] = []
                            if let s = index.series(category: c.category) {
                                if c.category.isChronologicalRun { if let iso = o.dateISO ?? CentralFilesClassifier.datelineDateISO(from: dateline) { rolls = s.rolls(containingDate: iso) } }
                                else if let g = c.geoKeys.first { rolls = s.rolls(geoKey: g, dateISO: o.dateISO ?? CentralFilesClassifier.datelineDateISO(from: dateline)) }
                            }
                            return classJSON(c, rolls: rolls)
                        },
                    ])
                }
            }
            let noChapter: [[String: Any]] = dateline.map { dl in
                CentralFilesClassifier.classify(header: header ?? "", dateline: dl, chapterCountry: nil).map { classJSON($0) }
            } ?? []
            var chosenTitle: Any = NSNull()
            if let i = o.chosenTitleIndex { chosenTitle = o.path[i] }
            let consPost = o.resolutions.first { $0.classification.category == .consularDespatches }?.classification.geoKeys.first
            let obj: [String: Any] = [
                "volume": volume,
                "d": d,
                "header": header ?? NSNull(),
                "dateline": dateline ?? NSNull(),
                "front": doc["front"] ?? NSNull(),
                "editorial": doc["editorial"] ?? NSNull(),
                "dateIsoIndex": doc["date_iso"] ?? NSNull(),
                "appYear": o.year ?? NSNull(),
                "datelineDateISO": dateline.flatMap { CentralFilesClassifier.datelineDateISO(from: $0) } ?? NSNull(),
                "gate": o.gate,
                "sectionPath": path,
                "chosenTitleIndex": o.chosenTitleIndex ?? NSNull(),
                "chosenTitle": chosenTitle,
                "shown": o.resolutions.map { classJSON($0.classification, rolls: $0.rolls) },
                "consularPostKeyShown": consPost ?? NSNull(),
                "consularPostKeyInIndexVocab": consPost.map { consularVocab.contains($0) } ?? NSNull(),
                "classifierByTitle": byTitle,
                "classifierNoChapter": noChapter,
            ]
            docsFH.write(jsonLine(obj))
            nDocs += 1
        }
        volsFH.write(jsonLine([
            "volume": volume,
            "earliest": v["earliest"] ?? NSNull(),
            "structureDecode": structureDecode,
            "docsInCache": docs.count,
            "docsInStructure": docsInStructure.count,
            "docsUnderCountryTitle": docsUnderCountry.count,
            "countryTitles": countryTitles,
            "unmatchedTopLevelTitles": unmatchedTopTitles,
        ]))
    }
    try? docsFH.close(); try? volsFH.close()
    print("run: \(nDocs) documents written; diplomatic geo vocabulary \(diploVocab.count) keys; consular \(consularVocab.count) keys")
}

let args = CommandLine.arguments
if args.count >= 2 && args[1] == "selftest" {
    MainActor.assumeIsolated { selftest() }
} else if args.count >= 5 && args[1] == "run" {
    MainActor.assumeIsolated { run(exportPath: args[2], docsOut: args[3], volsOut: args[4]) }
} else {
    print("usage: harness selftest | harness run <export.jsonl> <docs.jsonl> <volumes.jsonl>")
    exit(2)
}
