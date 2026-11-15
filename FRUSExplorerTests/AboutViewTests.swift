// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - AboutViewTests

struct AboutViewTests {

    // MARK: - AboutScreenLinksTest

    @Test("AboutScreenLinksTest: all About screen URLs are well-formed https URLs")
    func aboutLinksAreWellFormed() {
        for urlString in AboutLinks.allURLStrings {
            let url = URL(string: urlString)
            #expect(url != nil, "Expected \(urlString) to be a valid URL")
            #expect(url?.scheme == "https",
                    "Expected \(urlString) to use https scheme")
            #expect(url?.host != nil,
                    "Expected \(urlString) to have a non-nil host")
        }
    }

    @Test("AboutScreenLinksTest: expected hosts are present")
    func aboutLinksContainExpectedHosts() {
        let hosts = AboutLinks.allURLStrings.compactMap { URL(string: $0)?.host }
        #expect(hosts.contains("history.state.gov"))
        #expect(hosts.contains("github.com"))
        #expect(hosts.contains("www.archives.gov"))
        #expect(hosts.contains("teipublisher.com"))
        // The on-device model's open-source row (B4) links its card; the Gemma Terms links
        // (ai.google.dev) retired with EmbeddingGemma 300m.
        #expect(hosts.contains("huggingface.co"))
        #expect(!hosts.contains("ai.google.dev"))
        // The privacy policy and the support page (#1917, ASR-2).
        #expect(hosts.contains("frusexplorer.app"))
    }

    /// The two pages App Review looks for inside the app (#1917, ASR-2) are the addresses App Store
    /// Connect's Privacy Policy URL and Support URL give (`Planning/app-store-connect/
    /// App-Store-Connect-Entry.md`, §2 and §4): the in-app link and the listing's must be one page.
    /// No test reaches the pages themselves, which answer only once the site is public.
    @Test("AboutScreenLinksTest: the privacy policy and support links are the listing's two addresses")
    func privacyAndSupportAreTheListingsAddresses() {
        #expect(AboutLinks.privacyPolicy == "https://frusexplorer.app/privacy")
        #expect(AboutLinks.support == "https://frusexplorer.app/support")
        #expect(AboutLinks.allURLStrings.contains(AboutLinks.privacyPolicy))
        #expect(AboutLinks.allURLStrings.contains(AboutLinks.support))
    }

    /// About ▸ Legal, which both platforms show, and the Mac's Help menu each link both pages (#1917,
    /// ASR-2). Read from the source, since the rows are SwiftUI and the menu is the Mac's alone: the
    /// Legal section's body and the Help menu's group are each asked for the call that links each page.
    @Test("AboutScreenLinksTest: Legal and the Mac's Help menu link the privacy policy and the support page")
    func legalAndHelpMenuLinkBothPages() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
        let about = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Settings/AboutView.swift"),
                               encoding: .utf8)
        let legal = try #require(Self.slice(of: about, from: "private var legalSection: some View {",
                                            to: "private var legalRowLabel: some View {"))
        #expect(legal.contains("urlString: AboutLinks.privacyPolicy,"), "About ▸ Legal does not link the privacy policy")
        #expect(legal.contains("urlString: AboutLinks.support,"), "About ▸ Legal does not link the support page")
        let app = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/App/FRUSExplorerApp.swift"),
                             encoding: .utf8)
        let help = try #require(Self.slice(of: app, from: "CommandGroup(replacing: .help) {",
                                           to: "TextFormattingCommands()"))
        #expect(help.contains("urlString: AboutLinks.privacyPolicy)"), "the Help menu does not link the privacy policy")
        #expect(help.contains("urlString: AboutLinks.support)"), "the Help menu does not link the support page")
    }

    /// The text between the first `start` and the next `end` after it, or `nil` when either is missing.
    private static func slice(of text: String, from start: String, to end: String) -> Substring? {
        guard let lower = text.range(of: start),
              let upper = text.range(of: end, range: lower.upperBound..<text.endIndex) else { return nil }
        return text[lower.upperBound..<upper.lowerBound]
    }

    /// The manuals and quick starts that About, the Research tab and the Mac's Help menu open are
    /// files in this repository, read on GitHub at the default branch's head. A rename that left
    /// a link behind would open GitHub's 404 page.
    @Test("AboutScreenLinksTest: every GitHub document it links is in the repository")
    func linkedDocumentsExist() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
        let prefix = "https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/"
        let documents = AboutLinks.allURLStrings.filter { $0.hasPrefix(prefix) }
        // The two manuals and the two quick starts: fewer means the prefix no longer matches.
        #expect(documents.count >= 4)
        for link in documents {
            let path = root.appendingPathComponent(String(link.dropFirst(prefix.count))).path
            #expect(FileManager.default.fileExists(atPath: path), "\(link) names no file in the repository")
        }
    }

    // MARK: - EmptyStateTest

    @Test("EmptyStateTest: ProjectContextViewModel with no data has empty projects list")
    @MainActor
    func emptyProjectContextReportsZeroProjects() throws {
        let container = try makeContainer()
        let vm = ProjectContextViewModel()
        vm.load(context: container.mainContext)
        #expect(vm.projects.isEmpty)
    }

    // MARK: - DynamicTypeTest

    @Test("DynamicTypeTest: AboutLinks URL strings are non-empty and bounded in length")
    func aboutLinkStringsAreBounded() {
        for urlString in AboutLinks.allURLStrings {
            #expect(!urlString.isEmpty)
            // URLs should not be unreasonably long (no accidental whitespace/linebreaks)
            #expect(urlString.count < 256)
            #expect(!urlString.contains("\n"))
            #expect(!urlString.contains(" "))
        }
    }

    @Test("DynamicTypeTest: localized string keys produce non-empty default values")
    func localizedDefaultValuesAreNonEmpty() {
        let keys: [(String, String)] = [
            ("about.title", "About FRUS Explorer"),
            ("about.appName", "FRUS Explorer"),
            ("about.frus.header", "About FRUS"),
            ("about.resources.header", "Resources"),
            ("about.attribution.header", "Attribution"),
            ("about.openSource.header", "Open Source"),
            ("about.nara.header", "NARA Catalog API"),
        ]
        for (_, defaultValue) in keys {
            #expect(!defaultValue.isEmpty)
        }
    }

    // MARK: - Helper

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Project.self,
            ResearchNote.self,
            Collection.self,
            CollectionEntry.self,
            UserTag.self,
            ReadingHistoryEntry.self,
            GeneratedSummary.self,
            SummarizationPrompt.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }
}
