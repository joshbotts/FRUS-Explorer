// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - SaveSearchRequestTests

/// The Save Search sheet is presented from an item that carries its name, and keeps the name as its own state.
///
/// `SaveSearchSheetTests` (UI, in `SearchWithinResultsTests.swift`) drives iPhone and iPad's sheet: on the code before
/// the fix it failed at "Save is off", on an iPhone 17 and an iPad Pro 13-inch (M5). The Mac's Search window
/// (`MacSearchWindowView`, in `App/SearchSheet.swift`) is a view no test target runs, since the unit target is built
/// for iOS, and the sheet's Mac body is compiled out of it, so those halves are read from the source here.
///
/// Version history:
///   1.0 — 2026-10-18: initial implementation
@Suite("The Save Search sheet is presented from an item that carries its name")
struct SaveSearchRequestTests {

    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repositoryRoot.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("A request offers its words, trimmed, as the name, and two requests are two presentations")
    func requestOffersItsWords() {
        var parameters = SearchParameters()
        parameters.keywords = "berlin crisis"
        let first = SaveSearchRequest(words: " berlin crisis  ", parameters: parameters)
        let second = SaveSearchRequest(words: " berlin crisis  ", parameters: parameters)
        #expect(first.offeredName == "berlin crisis")
        // The sheet shows the words as the field held them, under the name.
        #expect(first.words == " berlin crisis  ")
        #expect(first.parameters.keywords == "berlin crisis")
        // A new identity each time: Save this search chosen twice for one search opens the sheet twice.
        #expect(first.id != second.id)
    }

    @Test("A name is saved trimmed, and a name of spaces or none is not saved")
    func savedName() {
        #expect(SaveSearchRequest.savedName(from: " Berlin, 1961 ") == "Berlin, 1961")
        #expect(SaveSearchRequest.savedName(from: "Berlin") == "Berlin")
        #expect(SaveSearchRequest.savedName(from: "   ") == nil)
        #expect(SaveSearchRequest.savedName(from: "") == nil)
    }

    /// Both Search screens, since each kept its own sheet until this fix: the command makes the request, the sheet is
    /// `.sheet(item:)`, and neither screen keeps the name in a `@State` of its own beside a Bool.
    @Test("Both Search screens present the sheet from the request, with no sibling state",
          arguments: ["FRUSExplorer/Search/SearchView.swift", "FRUSExplorer/App/SearchSheet.swift"])
    func bothScreensPresentFromTheItem(path: String) throws {
        let source = try Self.source(path)
        func count(_ text: String) -> Int { source.components(separatedBy: text).count - 1 }

        #expect(count("@State private var saveSearchRequest: SaveSearchRequest? = nil") == 1)
        #expect(count("saveSearchRequest = SaveSearchRequest(words: ") == 1)
        #expect(count(".sheet(item: $saveSearchRequest) { request in") == 1)
        #expect(count("SaveSearchSheet(request: request) { name in") == 1)
        #expect(count("modelContext.insert(SavedSearch(name: name, parameters: request.parameters))") == 1)
        // The shape that opened the sheet with Save off.
        #expect(count("showSaveSearchSheet") == 0, "\(path) presents the Save Search sheet from a Bool again")
        #expect(count("saveSearchName") == 0, "\(path) keeps the sheet's name in a sibling @State again")
    }

    /// Both of the sheet's bodies work Save out from the name the sheet holds, and the Mac's Return saves as Save does.
    @Test("The sheet holds its own name, and both bodies' Save reads it")
    func theSheetHoldsItsOwnName() throws {
        let source = try Self.source("FRUSExplorer/Search/SaveSearchSheet.swift")
        func count(_ text: String) -> Int { source.components(separatedBy: text).count - 1 }

        #expect(count("@State private var name: String") == 1)
        #expect(count("_name = State(initialValue: request.offeredName)") == 1)
        #expect(count("text: $name") == 2, "each body's name field edits the sheet's own name")
        #expect(count(".disabled(SaveSearchRequest.savedName(from: name) == nil)") == 2,
                "each body's Save is off by the sheet's own name")
        #expect(count(".onSubmit { save() }") == 1, "Return in the Mac's name field saves")
    }
}
