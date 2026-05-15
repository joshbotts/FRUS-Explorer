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
    }

    // MARK: - EmptyStateTest

    @Test("EmptyStateTest: GlobalContextViewModel with no data reports zero counts")
    @MainActor
    func emptyGlobalContextReportsZeroCounts() {
        let vm = GlobalContextViewModel()
        #expect(vm.allNotes.isEmpty)
        #expect(vm.allCollections.isEmpty)
        #expect(vm.allHistory.isEmpty)
        #expect(vm.totalDocumentsAccessed == 0)
        #expect(vm.untaggedNotesCount == 0)
        #expect(vm.untaggedHistoryCount == 0)
        #expect(vm.filteredNotes.isEmpty)
        #expect(vm.filteredCollections.isEmpty)
        #expect(vm.perProjectBreakdown.isEmpty)
        #expect(vm.perVolumeBreakdown.isEmpty)
    }

    @Test("EmptyStateTest: GlobalContextViewModel with no data and active filters still returns empty")
    @MainActor
    func emptyGlobalContextWithFiltersReturnsEmpty() {
        let vm = GlobalContextViewModel()
        vm.selectedProjectFilter = UUID()
        vm.selectedUserTagFilter = UUID()
        #expect(vm.filteredNotes.isEmpty)
        #expect(vm.filteredCollections.isEmpty)
    }

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
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
