// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

// MARK: - AppSourceTree

/// The two directories of the app's own Swift that the source scans read: `FRUSExplorer/`, and
/// `FRUSCoreKit/`, which both app targets compile too.
///
/// FRUSCoreKit, part 1 moved the TEI pipeline and the citation code from `FRUSExplorer/` to
/// `FRUSCoreKit/`, so a scan of `FRUSExplorer/` alone stopped reading them. A scan whose rule can
/// be broken there reads both through this type: a rule about string literals, localization keys,
/// doc comments, declarations or the kit's own API. A scan for the app's views, scenes, windows,
/// models or services reads `FRUSExplorer/` alone, because the kit cannot name any of them
/// (`FRUSCoreKitBoundaryTests`).
///
/// ## Read on 2026-10-09 (#1604)
/// Every test file that walks a source folder without this type was read, 34 of them. Four had a
/// rule a kit file could break, and read the kit now: the word-cloud precompute removal scan (a
/// banned name, read in all of ``compiledDirectories``), the Corpus Analytics unit-noun scan (a
/// string, in the two `Analytics/` folders), the citation-engine construction scan (the kit's own
/// initialiser) and the SF Symbol literal scan (a string). ``AppSourceTreeTests`` holds the rest
/// to a list: a test file that walks the app's folder without this type is named there with the
/// reason a kit file cannot break its rule, and one that is not named fails.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: initial implementation
///   1.1 — #1604: ``compiledDirectories``, and `AppSourceTreeTests`
enum AppSourceTree {

    /// The directories, relative to the repository root.
    static let directories = ["FRUSExplorer", "FRUSCoreKit"]

    /// Every directory both app targets compile, in `project.yml`'s order: the two above and the
    /// five older kits. A scan for something that must be nowhere in the app reads these.
    /// `AppSourceTreeTests` holds the list to `project.yml`.
    static let compiledDirectories = ["FRUSExplorer", "FTS5Store", "WordCloudKit", "SemanticVectorsKit",
                                      "SourceNoteKit", "TEIHeaderKit", "FRUSCoreKit"]

    /// Every `.swift` file under the two directories, at any depth, sorted by path.
    ///
    /// - Parameter repoRoot: The repository root.
    /// - Returns: The files.
    static func swiftFiles(in repoRoot: URL) -> [URL] {
        swiftFiles(in: repoRoot, directories: directories)
    }

    /// Every `.swift` file under `directories`, at any depth, sorted by path.
    ///
    /// - Parameters:
    ///   - repoRoot: The repository root.
    ///   - directories: The directories to read, relative to the repository root.
    /// - Returns: The files.
    static func swiftFiles(in repoRoot: URL, directories: [String]) -> [URL] {
        directories.flatMap { directory -> [URL] in
            let walker = FileManager.default.enumerator(at: repoRoot.appendingPathComponent(directory),
                                                        includingPropertiesForKeys: nil)
            return (walker?.compactMap { $0 as? URL } ?? []).filter { $0.pathExtension == "swift" }
        }
        .sorted { $0.path < $1.path }
    }
}

// MARK: - AppSourceTreeTests

/// What the source scans read is what the app compiles, and a scan that reads less says why
/// (#1604).
///
/// #1604 was found by reading: a scan for four banned names walked `FRUSExplorer/` and passed,
/// after the file likeliest to bring them back had moved to `FRUSCoreKit/`. Reading the other
/// scans found three more. These two tests are that reading, kept: the first fails when the app
/// compiles a directory the scans' list lacks, the second when a test file walks the app's folder
/// alone and is not on the list of those that may.
///
/// Version history:
///   1.0 — #1604: initial implementation
@Suite("Source scans read what the app compiles (#1604)")
struct AppSourceTreeTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    /// The folders `target` compiles, read from `project.yml`: each `- path:` of the target's
    /// `sources:` that names a folder (no `/`, no extension), in the file's order.
    static func sourceFolders(of target: String, in projectYML: String) -> [String] {
        var inTarget = false
        var inSources = false
        var folders: [String] = []
        for line in projectYML.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let indent = line.prefix { $0 == " " }.count
            if indent <= 2 {
                inTarget = line == "  \(target):"
                inSources = false
                continue
            }
            guard inTarget else { continue }
            if indent == 4 {
                inSources = trimmed == "sources:"
                continue
            }
            guard inSources, indent == 6, trimmed.hasPrefix("- path: ") else { continue }
            let path = String(trimmed.dropFirst("- path: ".count))
            if !path.contains("/") && !path.contains(".") { folders.append(path) }
        }
        return folders
    }

    @Test("The directories the scans call compiled are the ones project.yml gives both app targets")
    func compiledDirectoriesAreTheProjects() throws {
        let project = try String(contentsOf: Self.repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)
        for target in ["FRUSExplorer", "FRUSExplorerMac"] {
            #expect(Self.sourceFolders(of: target, in: project) == AppSourceTree.compiledDirectories, """
                project.yml gives \(target) other source folders than AppSourceTree.compiledDirectories. \
                A folder the app compiles and the scans do not read is #1604 again: add it to the list.
                """)
        }
        #expect(Set(AppSourceTree.directories).isSubset(of: AppSourceTree.compiledDirectories))
        // The reader against a fixture: comments and nested keys between entries, a file entry,
        // and a second target whose entries are not the first's.
        let fixture = """
            targets:
              One:
                type: application
                sources:
                  - path: Alpha
                    # a comment under an entry
                    excludes:
                      - "Info.plist"
                  # a comment between entries
                  - path: Beta
                  - path: Alpha/Models/Shared.swift
                info:
                  path: Alpha/Info.plist
              Two:
                sources:
                  - path: Gamma
            """
        #expect(Self.sourceFolders(of: "One", in: fixture) == ["Alpha", "Beta"])
        #expect(Self.sourceFolders(of: "Two", in: fixture) == ["Gamma"])
        #expect(Self.sourceFolders(of: "Three", in: fixture).isEmpty)
    }

    /// Test files that walk `FRUSExplorer/`, or a folder under it, without `AppSourceTree`, each
    /// with the reason: what its rule is about that a kit file cannot name, or how it reads the
    /// kit itself. An exact list, not permission: a scan added here is one somebody has read.
    static let walksTheAppFolderAlone: [String: String] = [
        "AnalyticsValueUnitTests.swift": "reads the kit's Analytics folder beside the app's, by two paths of its own",
        "BrowseScopeTests.swift": "call sites of ScopeIndexView, a SwiftUI view",
        "BrowseTwoPaneMetricsTests.swift": "root selections on the browser's view model, an app type",
        "BundledArtifactProvenanceTests.swift": "lists FRUSExplorer/Resources, bundled data and not source",
        "CloudKitSchemaInventoryTests.swift": "writers of AnnotationReview, a SwiftData model",
        "CodingStandardsAuditTests+CopyScans.swift": "reads FRUSCoreKit/ too, by a list of its own",
        "CodingStandardsAuditTests.swift": "the licence scan reads every directory a target names; its other walk only counts files",
        "DetachedHostingEnvironmentTests.swift": "SwiftUI modifiers whose content is hosted outside the view",
        "DiscoveryTipWiringAuditTests.swift": "TipKit tips and the views that anchor them",
        "EducationDashboardTests.swift": "the Research Guide's entry points, SwiftUI views",
        "FRUSCoreKitBoundaryTests.swift": "reads the app's declarations in order to hold the kit to them",
        "HandoffVisibilityTests.swift": "AppState's hand-offs",
        "MacDocumentOpenRoutingTests.swift": "AppState's document-open channel",
        "MacWindowFrontingTests.swift": "calls of SwiftUI's openWindow",
        "MacWindowRoutingTests.swift": "SwiftUI window scenes",
        "ProvenanceStatementTests.swift": "calls of AnalyticsProvenance, an app type",
        "ResearchDocumentAggregationTests.swift": "SwiftUI row backgrounds and the selected trait",
        "SceneAddressingTests.swift": "scene identities, SwiftUI's and AppState's",
        "SceneEnvironmentAuditTests.swift": "SwiftUI scenes and what each injects",
        "SemanticStorageReportTests.swift": "AppState's shard-fetch scope",
        "SheetExitTests.swift": "SwiftUI sheets and the views they present",
        "SourceProvenanceDataTests.swift": "Swift Charts marks and their colour scale",
        "ToolbarAccessibilityAuditTests.swift": "SwiftUI toolbars, pickers, sheets, List footers and views",
        "TripPacketEntryPointParityTests.swift": "ArchiveVisitPlan, a SwiftData model, and TripPacketSheet, a view",
        "WindowTargetingTests.swift": "UIKit scene activation and SwiftUI windows",
    ]

    /// Whether `source` enumerates a folder and names the app's folder, or one under it, as a
    /// string of its own: the two things a walk of `FRUSExplorer/` needs. A path that ends in a
    /// file's name is a read of that file and is not counted.
    static func walksTheAppFolder(_ source: String) -> Bool {
        let walks = ["enumerator(at", "enumerator(atPath", "subpathsOfDirectory(", "contentsOfDirectory("]
            .contains { source.contains($0) }
        return walks && source.range(of: #""FRUSExplorer(/[A-Za-z0-9_/]+)?""#, options: .regularExpression) != nil
    }

    @Test("A test that walks the app's folder without AppSourceTree is on the list of those that may")
    func everyWalkOfTheAppFolderAloneIsListed() throws {
        let testsRoot = Self.repoRoot.appendingPathComponent("FRUSExplorerTests")
        let files = try FileManager.default.subpathsOfDirectory(atPath: testsRoot.path)
            .filter { $0.hasSuffix(".swift") }
        // 352 on 2026-10-09. A walk that reads nothing finds no walker.
        try #require(files.count > 250, "read only \(files.count) test files")
        var found: Set<String> = []
        for path in files {
            let source = try String(contentsOf: testsRoot.appendingPathComponent(path), encoding: .utf8)
            if Self.walksTheAppFolder(source) && !source.contains("AppSourceTree") { found.insert(path) }
        }
        let listed = Set(Self.walksTheAppFolderAlone.keys)
        #expect(found.subtracting(listed).isEmpty, """
            These test files walk FRUSExplorer/ and not FRUSCoreKit/: \(found.subtracting(listed).sorted()). \
            If a kit file could break the rule (a string, a key, a banned name, a declaration, the \
            kit's own API), read both trees through AppSourceTree. If none could, add the file to \
            walksTheAppFolderAlone with the reason.
            """)
        #expect(listed.subtracting(found).isEmpty, """
            These are listed and no longer walk the app's folder alone: \
            \(listed.subtracting(found).sorted()). Drop them from walksTheAppFolderAlone.
            """)
        // The reader: a walk of the folder, a walk of a folder under it, a read of one file, and
        // a walk of somewhere else.
        #expect(Self.walksTheAppFolder(#"let f = fm.enumerator(at: root.appending(path: "FRUSExplorer"))"#))
        #expect(Self.walksTheAppFolder(#"try fm.subpathsOfDirectory(atPath: "FRUSExplorer/Analytics")"#))
        #expect(!Self.walksTheAppFolder(#"try fm.contentsOfDirectory(atPath: tmp); read("FRUSExplorer/App/AppState.swift")"#))
        #expect(!Self.walksTheAppFolder(#"let text = read("FRUSExplorer")"#))
    }
}
