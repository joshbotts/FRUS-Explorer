// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - SearchRefusalMessageTests

/// What a keyword search shows when its query holds nothing it can search for (#1299).
///
/// `SearchService` throws `FTS5Error.emptyQuery` for a query the parser refuses — `-korea`, `NOT korea`, a group
/// nested past `FTS5InlineQueryParser.maximumGroupDepth` — and until #1299 neither host mapped it. `FTS5Error` has no
/// `LocalizedError` conformance, so iOS's Search Error screen read "The operation couldn’t be completed.
/// (FRUSExplorer.FTS5Error error 5.)", and the macOS view model stored the raw error.
///
/// The iOS half is driven at runtime, through a real `SearchViewModel` over a real (empty) index, because the whole
/// path — the view model's guard, the service's throw, the catch — is what decides the string. The macOS view model
/// is compiled only into the macOS app and this bundle builds for iOS, so its half is a source pin scoped to the one
/// method that assigns the error, never a window of the file.
///
/// Version history:
///   1.0 — #1299: initial implementation
@Suite("A refused keyword query reads as a message, not an error code")
@MainActor
struct SearchRefusalMessageTests {

    // MARK: - Fixture

    /// A view model over an index with nothing in it, and the directory to remove afterwards.
    ///
    /// Nothing needs indexing: a refused query throws before any statement runs, and the positive control below
    /// shows the same fixture runs an ordinary query without an error.
    private func makeViewModel() throws -> (dir: URL, vm: SearchViewModel) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSRefusal-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("refusal.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        return (dir, SearchViewModel(searchService: SearchService(fts5Store: store, pipeline: pipeline)))
    }

    /// Queries the parser refuses, each for a different reason.
    private static let refusedQueries: [String] = [
        "-korea",
        "NOT korea",
        "-(korea OR vietnam)",
        String(repeating: "(", count: 33) + "cold" + String(repeating: ")", count: 33),
    ]

    // MARK: - iOS, at runtime

    @Test("iOS: a refused query shows a readable message that points at Search Tips")
    func iOSRefusedQueryShowsTheMessage() async throws {
        let (dir, vm) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Positive control: the fixture runs an ordinary query, so an error below is the refusal and not a broken index.
        vm.keywords = "cold"
        await vm.search()
        #expect(vm.hasSearched && vm.searchError == nil, "precondition: an ordinary query runs without an error")

        var refused = 0
        for query in Self.refusedQueries {
            vm.keywords = query
            await vm.search()
            let message = try #require(vm.searchError, "\(query.prefix(40)) should not run")
            refused += 1
            #expect(!message.contains("FTS5Error"), "\(query.prefix(40)) shows an error code: \(message)")
            #expect(!message.contains("couldn’t be completed"), "\(query.prefix(40)) shows the system message")
            #expect(message.contains("Search Tips"), "\(query.prefix(40)) does not point at Search Tips: \(message)")
            #expect(vm.results.isEmpty)
        }
        #expect(refused == Self.refusedQueries.count)
    }

    /// `FTS5Error.emptyQuery` has a second cause the refusal message would describe falsely: text that parses, with
    /// every content scope off, which iOS's Filters sheet allows. The mapping reads the parse, so that case is not
    /// called a query that only excludes words.
    @Test("iOS: a query that parses but has every scope off is not called a refusal")
    func iOSScopeOffIsNotCalledARefusal() async throws {
        let (dir, vm) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        vm.keywords = "cold"
        await vm.search()
        #expect(vm.searchError == nil, "precondition: with a scope on, the query runs")

        vm.includeDocumentText = false
        vm.includeSummaries = false
        vm.includeNotes = false
        await vm.search()
        let message = try #require(vm.searchError, "precondition: with every scope off the service throws")
        #expect(!message.contains("Search Tips"), "a scope error was explained as a refused query: \(message)")
    }

    // MARK: - macOS, by source

    /// The body of a declaration, from its opening brace to the brace that matches it.
    private static func declaration(_ signature: String, in source: String) throws -> String {
        let start = try #require(source.range(of: signature), "no declaration: \(signature)")
        var depth = 0
        var opened = false
        var index = start.lowerBound
        while index < source.endIndex {
            let character = source[index]
            if character == "{" { depth += 1; opened = true }
            if character == "}" {
                depth -= 1
                if opened, depth == 0 { return String(source[start.lowerBound...index]) }
            }
            index = source.index(after: index)
        }
        Issue.record("unbalanced braces after \(signature)")
        return ""
    }

    /// `MacSearchViewModel.swift`, read from the repository.
    private static func macViewModelSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: "FRUSExplorer/App/MacSearchViewModel.swift"), encoding: .utf8)
    }

    @Test("macOS: the keyword search's catch stores the mapped error, not the raw one")
    func macCatchStoresTheMappedError() throws {
        let body = try Self.declaration("func performSearch(service: SearchService?) async {",
                                        in: Self.macViewModelSource())
        // The slice is bounded and real, or every absence below is vacuous.
        #expect(body.contains("} catch {"))
        #expect(!body.contains("func performMeaningSearch"))

        let catchBody = try #require(body.range(of: "} catch {").map { String(body[$0.upperBound...]) })
        #expect(catchBody.contains("searchError = SearchQueryRefusal.readable(error, for: frozenParams)"),
                "the Mac search must map a refused query as iOS does")
        let rawAssignments = catchBody.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0 == "searchError = error" }
        #expect(rawAssignments.isEmpty, "the raw FTS5Error still reaches searchError")
    }
}
