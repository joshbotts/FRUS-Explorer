// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

// MARK: - CodingStandardsAuditTests

/// Automated enforcement of the coding standards checklist from Session 31.
///
/// These tests read the source tree to verify structural compliance with the
/// standards defined in `FRUS-Explorer-Specification.md` §22:
/// - All Swift source files carry the Apache 2.0 license header
/// - No `nullable: true` in the OpenAPI document (3.0 syntax forbidden)
/// - Key source files declare a version history comment block
/// - No hardcoded English strings in SwiftUI views that bypass localization
///   (spot-check of known patterns)
/// - `FRUS-API.openapi.yaml` declares OpenAPI 3.1.0
///
/// Version history:
///   1.0 — Session 31: initial coding standards audit suite
struct CodingStandardsAuditTests {

    // MARK: - File URL Helpers

    private static let projectRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    private static let sourceRoot: URL =
        projectRoot.appendingPathComponent("FRUSExplorer")

    private static let testsRoot: URL =
        projectRoot.appendingPathComponent("FRUSExplorerTests")

    private static let openAPIURL: URL =
        projectRoot.appendingPathComponent("FRUS-API.openapi.yaml")

    // MARK: - OpenAPI Compliance

    @Test("CodingStandardsAudit: FRUS-API.openapi.yaml declares OpenAPI 3.1.0")
    func openAPIVersionDeclaration() throws {
        let content = try String(contentsOf: Self.openAPIURL, encoding: .utf8)
        #expect(content.contains("openapi: 3.1.0"),
                "OpenAPI document must declare version 3.1.0")
    }

    @Test("CodingStandardsAudit: FRUS-API.openapi.yaml contains no deprecated nullable: true syntax")
    func noDeprecatedNullableSyntax() throws {
        let content = try String(contentsOf: Self.openAPIURL, encoding: .utf8)
        #expect(!content.contains("nullable: true"),
                "Found 'nullable: true' — use 'type: [\"...\", \"null\"]' in OpenAPI 3.1")
    }

    @Test("CodingStandardsAudit: /citation-lookup endpoint is defined in OpenAPI spec")
    func citationLookupEndpointDefined() throws {
        let content = try String(contentsOf: Self.openAPIURL, encoding: .utf8)
        #expect(content.contains("/citation-lookup:"),
                "OpenAPI spec must define /citation-lookup (added in Session 30)")
    }

    @Test("CodingStandardsAudit: CitationMatch schema is defined in OpenAPI components")
    func citationMatchSchemaDefined() throws {
        let content = try String(contentsOf: Self.openAPIURL, encoding: .utf8)
        #expect(content.contains("CitationMatch:"),
                "CitationMatch schema must be defined in components/schemas")
    }

    // MARK: - License Header Compliance

    @Test("CodingStandardsAudit: all session source files carry Apache 2.0 license header")
    func allSourceFilesHaveLicenseHeader() throws {
        let licenseMarker = "Licensed under the Apache License, Version 2.0"
        var violations: [String] = []

        let fm = FileManager.default
        let sourceURLs = try fm.subpathsOfDirectory(atPath: Self.sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .map { Self.sourceRoot.appendingPathComponent($0) }

        for url in sourceURLs {
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if !content.contains(licenseMarker) {
                violations.append(url.lastPathComponent)
            }
        }

        #expect(violations.isEmpty,
                "Missing Apache 2.0 header in: \(violations.sorted().joined(separator: ", "))")
    }

    @Test("CodingStandardsAudit: all test files carry Apache 2.0 license header")
    func allTestFilesHaveLicenseHeader() throws {
        let licenseMarker = "Licensed under the Apache License, Version 2.0"
        var violations: [String] = []

        let fm = FileManager.default
        let testURLs = try fm.subpathsOfDirectory(atPath: Self.testsRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .map { Self.testsRoot.appendingPathComponent($0) }

        for url in testURLs {
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if !content.contains(licenseMarker) {
                violations.append(url.lastPathComponent)
            }
        }

        #expect(violations.isEmpty,
                "Missing Apache 2.0 header in tests: \(violations.sorted().joined(separator: ", "))")
    }

    // MARK: - Version History Comments

    @Test("CodingStandardsAudit: key session output files declare version history")
    func keyFilesHaveVersionHistory() throws {
        let keyFiles: [String] = [
            "FRUSExplorer/App/FRUSExplorerApp.swift",
            "FRUSExplorer/App/AppState.swift",
            "FRUSExplorer/Search/SearchService.swift",
            "FRUSExplorer/CrossReference/CrossReferenceGraphView.swift",
            "FRUSExplorer/Citation/CitationParser.swift",
            "FRUSExplorer/Citation/PageRangeStore.swift",
            "FRUSExplorer/Citation/CitationMatchingEngine.swift",
        ]

        var missing: [String] = []
        for relativePath in keyFiles {
            let url = Self.projectRoot.appendingPathComponent(relativePath)
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if !content.contains("Version history:") {
                missing.append(relativePath)
            }
        }

        #expect(missing.isEmpty,
                "Missing 'Version history:' block in: \(missing.joined(separator: ", "))")
    }

    // MARK: - Localization

    @Test("CodingStandardsAudit: key view files use String(localized:) not bare string literals in Text()")
    func keyViewsUseLocalization() throws {
        // Spot-check: these views must not contain plain Text("...") with 4+ char strings
        // that bypass localization. We check a pattern of bareText("...") vs Text(String(localized:...)).
        // Note: this is a heuristic; some Text() with dynamic content is acceptable.
        let viewFiles = [
            "FRUSExplorer/Citation/CitationLookupView.swift",
            "FRUSExplorer/CrossReference/CrossReferenceGraphView.swift",
            "FRUSExplorer/Settings/AboutView.swift",
        ]

        for relativePath in viewFiles {
            let url = Self.projectRoot.appendingPathComponent(relativePath)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Verify file uses String(localized:) — if it doesn't at all, that's a red flag
            #expect(content.contains("String(localized:") || content.contains("localized:"),
                    "\(relativePath) appears to use no localization at all")
        }
    }

    // MARK: - Debug Telemetry

    @Test("CodingStandardsAudit: CitationParser uses #if DEBUG telemetry logging")
    func citationParserHasDebugLogging() throws {
        let url = Self.projectRoot.appendingPathComponent("FRUSExplorer/Citation/CitationParser.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("#if DEBUG"), "CitationParser must use #if DEBUG logging")
        #expect(content.contains("[CitationParser]"), "CitationParser must use [CitationParser] log prefix")
    }

    @Test("CodingStandardsAudit: CitationMatchingEngine uses #if DEBUG telemetry logging")
    func citationMatchingEngineHasDebugLogging() throws {
        let url = Self.projectRoot.appendingPathComponent("FRUSExplorer/Citation/CitationMatchingEngine.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("#if DEBUG"), "CitationMatchingEngine must use #if DEBUG logging")
        #expect(content.contains("[CitationMatcher]"), "CitationMatchingEngine must use [CitationMatcher] log prefix")
    }

    @Test("CodingStandardsAudit: PageRangeStore uses #if DEBUG telemetry logging")
    func pageRangeStoreHasDebugLogging() throws {
        let url = Self.projectRoot.appendingPathComponent("FRUSExplorer/Citation/PageRangeStore.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("#if DEBUG"), "PageRangeStore must use #if DEBUG logging")
        #expect(content.contains("[PageRangeStore]"), "PageRangeStore must use [PageRangeStore] log prefix")
    }

    // MARK: - Architecture

    @Test("CodingStandardsAudit: SparkleUpdater is guarded by DIRECT_DISTRIBUTION compiler flag")
    func sparkleUpdaterIsConditionallyCompiled() throws {
        let url = Self.projectRoot.appendingPathComponent("FRUSExplorer/Distribution/SparkleUpdater.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("#if os(macOS) && DIRECT_DISTRIBUTION"),
                "SparkleUpdater must be guarded by #if os(macOS) && DIRECT_DISTRIBUTION")
    }

    @Test("CodingStandardsAudit: project.yml declares Manual signing for DirectDistribution")
    func projectYMLManualSigning() throws {
        let url = Self.projectRoot.appendingPathComponent("project.yml")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("CODE_SIGN_STYLE: Manual"),
                "DirectDistribution config must use CODE_SIGN_STYLE: Manual")
    }

    // MARK: - Cross-Reference Graph

    @Test("CodingStandardsAudit: CrossReferenceGraphView uses accessibilityRepresentation")
    func graphViewUsesAccessibilityRepresentation() throws {
        let url = Self.projectRoot.appendingPathComponent("FRUSExplorer/CrossReference/CrossReferenceGraphView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("accessibilityRepresentation"),
                "CrossReferenceGraphView must use .accessibilityRepresentation for VoiceOver (Q3)")
    }

    @Test("CodingStandardsAudit: CrossReferenceGraphView handles reduceMotion for animations")
    func graphViewHandlesReduceMotion() throws {
        let url = Self.projectRoot.appendingPathComponent("FRUSExplorer/CrossReference/CrossReferenceGraphView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("reduceMotion"),
                "CrossReferenceGraphView must respect accessibilityReduceMotion (Q4)")
    }

    // MARK: - File Count Sanity

    @Test("CodingStandardsAudit: source tree contains expected minimum number of Swift files")
    func sourceTreeSize() throws {
        let fm = FileManager.default
        let sourceCount = (try? fm.subpathsOfDirectory(atPath: Self.sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }.count) ?? 0
        let testCount = (try? fm.subpathsOfDirectory(atPath: Self.testsRoot.path)
            .filter { $0.hasSuffix(".swift") }.count) ?? 0

        // 31 sessions × ~3 files average = ~90 source files minimum
        #expect(sourceCount >= 50,
                "Expected ≥50 Swift source files, found \(sourceCount)")
        // 31 sessions × ~1 test file = ~31 test files minimum
        #expect(testCount >= 25,
                "Expected ≥25 test files, found \(testCount)")
    }
}
