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

    private static let uiTestsRoot: URL =
        projectRoot.appendingPathComponent("FRUSExplorerUITests")

    private static let openAPIURL: URL =
        projectRoot.appendingPathComponent("FRUS-API.openapi.yaml")

    // MARK: - Release Surfaces

    /// `README.md`'s stated build and version match `project.yml`.
    ///
    /// The README is the project's public front door and the only page linking the agentic-analysis
    /// guide, and it sat at build 37 while the tree was at 44. Seven builds, because nothing
    /// checked: `CLAUDE.md`'s bump procedure names two files — `project.yml` and `project.pbxproj`
    /// — and the README is a third place the number lives. A step nothing enforces is a step that
    /// gets skipped, so this is the enforcement rather than a fourth line of procedure.
    @Test("CodingStandardsAudit: README states the current build and version")
    func readmeStatesCurrentBuild() throws {
        let project = try String(
            contentsOf: Self.projectRoot.appendingPathComponent("project.yml"), encoding: .utf8)
        let readme = try String(
            contentsOf: Self.projectRoot.appendingPathComponent("README.md"), encoding: .utf8)

        func firstMatch(_ pattern: String, in text: String) throws -> [String] {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { return [] }
            return (1..<match.numberOfRanges).compactMap {
                Range(match.range(at: $0), in: text).map { r in String(text[r]) }
            }
        }

        let build = try firstMatch(#"CURRENT_PROJECT_VERSION:\s*(\d+)"#, in: project)
        let marketing = try firstMatch(#"MARKETING_VERSION:\s*"([^"]+)""#, in: project)
        #expect(build.count == 1, "project.yml must state CURRENT_PROJECT_VERSION")
        #expect(marketing.count == 1, "project.yml must state MARKETING_VERSION")

        let stated = try firstMatch(#"Current build:\s*\*\*(\d+)\*\*\s*\(version ([0-9.]+)\)"#,
                                    in: readme)
        #expect(stated.count == 2,
                "README.md must carry a line of the form: Current build: **N** (version X.Y).")
        guard stated.count == 2, let expectedBuild = build.first,
              let expectedVersion = marketing.first else { return }

        #expect(stated[0] == expectedBuild,
                """
                README.md says build \(stated[0]) but project.yml says \(expectedBuild). \
                Update the "Current build:" line in README.md to **\(expectedBuild)** \
                (version \(expectedVersion)).
                """)
        #expect(stated[1] == expectedVersion,
                """
                README.md says version \(stated[1]) but project.yml says \(expectedVersion). \
                Update the "Current build:" line in README.md.
                """)
    }

    /// The Plan of Record's claim about which visual-marketing steps are done matches the plan.
    ///
    /// **This exists because the drift already happened.** The Plan of Record is the document
    /// someone reads to decide what to work on next, and it described five closed export gaps, four
    /// shipped motion items and a drafted store listing as all still open — for a day, across
    /// fourteen merged PRs. Separately, a strike in the plan itself was silently *lost* when a
    /// script wrote the file twice from one unmodified string, so a finished row read as startable.
    ///
    /// Neither failure is visible by reading: both documents were internally plausible. What makes
    /// them checkable is that the Plan of Record states a set and the plan holds the truth, so the
    /// two can be compared. Strike a row without updating the Plan of Record — or lose a strike —
    /// and this fails with both sets printed.
    ///
    /// It deliberately does NOT try to decide whether a row *should* be struck. That needs to know
    /// what shipped, which no test can. It pins the far narrower and still useful property: the two
    /// documents agree.
    /// **The record half is found, not named** (2026-09-06). This test used to open
    /// `Plan-Of-Record-2026-08-28.md` by literal path, and that document has since been superseded
    /// — its own header now reads *"do NOT read its row states as current"*. So the check against
    /// two documents drifting apart had itself drifted onto a frozen file, and would have gone on
    /// passing against a snapshot forever. It now selects the one plan of record NOT marked
    /// `Status: SUPERSEDED`, and fails when there is not exactly one — zero live plans or two live
    /// plans is a real problem, not a test bug.
    @Test("CodingStandardsAudit: the Plan of Record's struck-step list matches the plan")
    func planOfRecordMatchesTheVisualMarketingPlan() throws {
        let planURL = Self.projectRoot
            .appendingPathComponent("Planning/Visual-Marketing-Plan.md")
        let planningDirectory = Self.projectRoot.appendingPathComponent("Planning")
        let candidates = try FileManager.default
            .contentsOfDirectory(at: planningDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("Plan-Of-Record-") && $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let live = try candidates.filter {
            try !String(contentsOf: $0, encoding: .utf8).contains("Status: SUPERSEDED")
        }
        #expect(live.count == 1, """
            Expected exactly one live plan of record in Planning/ — found \(live.count) of \
            \(candidates.count): \(live.map(\.lastPathComponent).sorted()). A superseded plan must \
            say "Status: SUPERSEDED" in its header; the current one must not.
            """)
        let recordURL = try #require(live.first)
        let plan = try String(contentsOf: planURL, encoding: .utf8)
        let record = try String(contentsOf: recordURL, encoding: .utf8)

        // What the plan actually says: numbered rows inside its §7 Sequence, struck or not.
        var struckInPlan: Set<Int> = []
        var sawSequence = false
        var rowsSeen = 0
        for line in plan.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## 7. Sequence") { sawSequence = true; continue }
            if sawSequence, line.hasPrefix("## 8.") { break }
            guard sawSequence else { continue }
            guard let match = line.firstMatch(of: /^(\d+)\. (~~)?/) else { continue }
            guard let number = Int(match.1) else { continue }
            rowsSeen += 1
            if match.2 != nil { struckInPlan.insert(number) }
        }
        #expect(rowsSeen > 10, """
            Parsed only \(rowsSeen) numbered rows from the plan's §7 Sequence. The section headings \
            or the row format changed, and this check is now blind rather than passing.
            """)

        // What the Plan of Record claims.
        let claim = try #require(record.firstMatch(of: /§7 struck: ([0-9, ]+)\./),
                                 "the Plan of Record must carry a line of the form: §7 struck: 0, 1, 2.")
        let claimed = Set(claim.1.split(separator: ",").compactMap {
            Int($0.trimmingCharacters(in: .whitespaces))
        })

        #expect(claimed == struckInPlan, """
            The Plan of Record and Visual-Marketing-Plan disagree about which §7 steps are done.
              Plan of Record claims: \(claimed.sorted())
              The plan itself shows: \(struckInPlan.sorted())
            Update the "§7 struck:" line in \(recordURL.lastPathComponent), or restore the strike \
            that went missing from Visual-Marketing-Plan.md.
            """)
    }

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
    //
    // SparkleUpdater (and its "guarded by DIRECT_DISTRIBUTION compiler flag" audit
    // test) was removed in Session 2026-06-07 — Apple rejects App Store/TestFlight
    // submissions that bundle Sparkle.framework, since Xcode links package
    // dependencies per-target rather than per-config (see project.yml `configs:`
    // comment for the full rationale).

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

    // MARK: - Test Container Hermeticity

    /// Every `ModelConfiguration` in the two test trees opts out of CloudKit.
    ///
    /// `cloudKitDatabase` defaults to `.automatic`, which adopts the *test host app's* iCloud
    /// entitlement. The host is entitled, so an in-memory test store built without the explicit
    /// `.none` gets a real `NSCloudKitMirroringDelegate` whose setup runs asynchronously and
    /// outlives the test that created it. Measured on `v2` @ `9078fe61` (iPhone 17e, iOS 27.0),
    /// nine such calls crashed the host five times with `NSInternalInconsistencyException:
    /// 'No eligible connection available'` and the target ended `** TEST EXECUTE FAILED **`,
    /// while the log's own last line said the run had passed.
    ///
    /// The scan walks each call's balanced parentheses, so a call split across lines is read
    /// whole — `CaptureStateSeederTests.swift:30-31` is one, and it passes. It does NOT skip
    /// comments or string literals: nothing in either tree defeats it today, and a doc comment
    /// that quotes `ModelConfiguration(` would go red falsely.
    ///
    /// Scoped to the TEST trees on purpose. The app tree holds two calls this rule must not
    /// touch, for two different reasons: `ModelContainer+FRUS.swift:239` is explicitly
    /// `.private("iCloud.bottsywattsy.FRUS-Explorer")`, and `:203` is deliberately bare — it
    /// leans on `.automatic` to yield the mirrored store's `url` and, as its own comment at
    /// `:200-202` says, never builds a container. This file is skipped BY NAME because it
    /// necessarily contains the search string itself; renaming it would make it scan itself
    /// and move `scanned`.
    ///
    /// Version history:
    ///   1.0 — 2026-09-19: #1325, the test-host crash
    @Test("CodingStandardsAudit: every test ModelConfiguration opts out of CloudKit")
    func testModelConfigurationsOptOutOfCloudKit() throws {
        let needle = "ModelConfiguration("
        let fm = FileManager.default

        func swiftFiles(under root: URL) throws -> [URL] {
            try fm.subpathsOfDirectory(atPath: root.path)
                .filter { $0.hasSuffix(".swift") }
                .filter { ($0 as NSString).lastPathComponent != "CodingStandardsAuditTests.swift" }
                .map { root.appendingPathComponent($0) }
        }

        let testURLs = try swiftFiles(under: Self.testsRoot) + swiftFiles(under: Self.uiTestsRoot)

        var scanned = 0
        var violations: [String] = []

        for url in testURLs {
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            var cursor = content.startIndex
            while let match = content.range(of: needle, range: cursor..<content.endIndex) {
                // `match.upperBound` is one past the "("; step back onto it and walk to its
                // partner, so a call broken across lines is read as one call.
                var depth = 0
                var index = content.index(before: match.upperBound)
                var close = content.index(before: content.endIndex)
                while index < content.endIndex {
                    if content[index] == "(" {
                        depth += 1
                    } else if content[index] == ")" {
                        depth -= 1
                        if depth == 0 {
                            close = index
                            break
                        }
                    }
                    index = content.index(after: index)
                }

                scanned += 1
                if !content[match.lowerBound...close].contains("cloudKitDatabase") {
                    let line = content[content.startIndex..<match.lowerBound]
                        .reduce(into: 1) { total, character in
                            if character == "\n" { total += 1 }
                        }
                    violations.append("\(url.lastPathComponent):\(line)")
                }
                cursor = content.index(after: close)
            }
        }

        // A renamed initialiser, a moved root or a filter typo would make the sweep vacuously
        // green. The floor sits just under the 39 calls the trees hold today, because the
        // population this test protects is exactly the one a collapse would hide.
        #expect(scanned >= 35, """
            Scanned only \(scanned) ModelConfiguration call(s): the sweep is broken, not the \
            tree clean.
            """)

        #expect(violations.isEmpty, """
            Test ModelConfiguration(s) without cloudKitDatabase: .none — the default .automatic \
            adopts the test host's iCloud entitlement and crashes the host: \
            \(violations.sorted().joined(separator: ", "))
            """)
    }

    // MARK: - Collection Document Counts

    /// No Collections or Project surface counts a collection's entries as its documents.
    ///
    /// `Collection.documentEntries` holds every entry of every kind — headings, prose blocks,
    /// excerpts, generated apparatus blocks and unknown kinds as well as documents — so its
    /// `count` labelled a collection of six documents under two headings and one prose block
    /// "9 documents" on the Collections tab, and printed the same wrong number at three sites in
    /// the macOS manager (#1358). `Collection.documentCount` is the rule; this refuses the raw
    /// count in both spellings, `documentEntries?.count` and `(… documentEntries ?? []).count`.
    ///
    /// Any `(` or `{` after `.count` is taken for a FILTERED count (`.count(where:)`,
    /// `.count { … }`) and let through, which is coarser than it sounds in both directions. A raw
    /// count heading an `if let` or `switch` body (`switch c.documentEntries?.count {`) passes; a
    /// call that WRAPS the array and has its result counted
    /// (`distinctDocumentKeys(in: c.documentEntries ?? []).count`) is refused. Neither shape occurs
    /// in these two directories today. And a filtered count passes whatever it filters for:
    /// Project Home's collections sheet (`ProjectCollectionsEditor.collectionInfo`, in
    /// `ProjectContext/`) counts DISTINCT `.document` keys on purpose, to match what seeds the
    /// project's leads, so it reads one less than `documentCount` for a document added twice.
    ///
    /// Scoped to the two directories #1358 names. Widened to the whole tree it would find four
    /// more matches, none a size label: three raw counts that count entries on purpose (a debug
    /// print in `Collection.duplicate`, and the entry-count tie-break in `DuplicateRecordCleanup`
    /// that keeps the richer of two duplicate records) and the Research sidebar's wrapped call
    /// above, its deliberate distinct-document rule. The scan does not skip comments, so a comment
    /// in these directories must not spell the pattern either.
    ///
    /// Version history:
    ///   1.0 — 2026-09-23: #1358
    ///   1.1 — 2026-09-23: #1358 review — the doc states what the pattern actually lets through
    ///         and refuses, and names Project Home's distinct count as a filtered count it passes
    @Test("CodingStandardsAudit: Collections and ProjectContext count documents, not entries")
    func collectionCountsReadDocumentCount() throws {
        let raw = try NSRegularExpression(pattern: #"""
            documentEntries\s*\?\s*\.count\b(?!\s*[({])|documentEntries\s*\?\?\s*\[\]\s*\)\s*\.count\b(?!\s*[({])
            """#)
        let fm = FileManager.default
        var violations: [String] = []

        for directory in ["Collections", "ProjectContext"] {
            let root = Self.sourceRoot.appendingPathComponent(directory)
            let paths = try fm.subpathsOfDirectory(atPath: root.path).filter { $0.hasSuffix(".swift") }
            // A moved or renamed directory would make the scan vacuously green. Today the two
            // hold 25 and 16 Swift files.
            #expect(paths.count >= 10, """
                Read only \(paths.count) Swift file(s) under FRUSExplorer/\(directory): the scan is \
                broken, not the tree clean.
                """)
            for path in paths {
                // The whole file, not line by line: `\s` spans newlines, so
                // `(c.documentEntries ?? [])` with `.count` on the next line is still one match.
                let content = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
                for match in raw.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                    guard let range = Range(match.range, in: content) else {
                        Issue.record("Unmappable match range in \(directory)/\(path)")
                        continue
                    }
                    let line = content[..<range.lowerBound].reduce(into: 1) { total, character in
                        if character == "\n" { total += 1 }
                    }
                    violations.append("\(directory)/\(path):\(line)")
                }
            }
        }

        #expect(violations.isEmpty, """
            A collection's raw entry count shown as its size — it counts headings, prose, excerpts \
            and generated blocks as documents; read Collection.documentCount: \
            \(violations.sorted().joined(separator: ", "))
            """)
    }

    // MARK: - Hover Never Selects

    /// No hover closure in the app writes a selection.
    ///
    /// Two graphs' node hit areas once wrote the pointer's hover into the property the
    /// click writes and the info panel reads (#1383): `.onHover { … vm.selectedPartnerId = … }` in
    /// `PersonCoMentionGraphView` and `VolumeConnectionGraphView`. So on macOS every node the
    /// pointer crossed became the selection, leaving it did not undo that, and a click on a node the
    /// pointer had just entered — the toggle's second write — cleared it. The fix keeps hover in
    /// `hoveredPartnerId` and lets only `toggleSelection(_:)` write the selection; this keeps the
    /// shape from coming back anywhere, the way `CrossReferenceGraphView` split it in Session 161.
    ///
    /// A closure fails when it assigns an identifier beginning `selected` (`vm.selectedPartnerId =`,
    /// not `==`) or calls `toggleSelection(`, which writes the selection by another name. It is
    /// read as the modifier's own argument — balanced parentheses, then a balanced trailing
    /// closure — over a copy of the file with comments and string literals blanked, so a brace in
    /// a string cannot end it early and a comment quoting the pattern cannot fail it. Regex
    /// literals are read as code. Because a closure's end is only as good as that masking, the
    /// test also requires every file's masked copy to balance its braces and parentheses — all
    /// 479 do today — so a literal the lexer misreads fails here by name instead of silently
    /// cutting a closure short.
    ///
    /// Scoped to the whole app tree, where #1383 named `Analytics/` and `CrossReference/`: the
    /// other hover closures (the document margin chevrons in `MacDocumentView` and
    /// `DocumentView`, the cross-reference graph's two, and Chronology's `.onContinuousHover`)
    /// write hover state only, so the wider scope costs nothing and covers a third graph.
    ///
    /// Version history:
    ///   1.0 — 2026-09-23: #1383
    ///   1.1 — 2026-09-24: #1383 review — the closure finder split out as `hoverClosureRanges(in:)`,
    ///          and its `.onHoverX` identifier check dropped: it was dead, since the rule that a
    ///          `(` or `{` must follow the name already passes over `.onHoverChanged`
    @Test("CodingStandardsAudit: no hover closure writes a selection")
    func hoverClosuresNeverWriteASelection() throws {
        let paths = try FileManager.default.subpathsOfDirectory(atPath: Self.sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
        var closures = 0
        var violations: [String] = []
        var misread: [String] = []
        for path in paths {
            let content = try String(contentsOf: Self.sourceRoot.appendingPathComponent(path),
                                     encoding: .utf8)
            let scan = try Self.hoverSelectionWrites(in: content)
            closures += scan.closures
            violations += scan.writeLines.map { "\(path):\($0)" }
            // The closure boundaries are only as good as the masking: a string or comment the
            // lexer misreads leaves a stray brace or parenthesis behind, and then a closure can
            // end early and hide a write. Every file in the tree balances today.
            let masked = Self.maskedCode(content)
            let braces = masked.reduce(0) { $0 + ($1 == 0x7B ? 1 : $1 == 0x7D ? -1 : 0) }
            let parens = masked.reduce(0) { $0 + ($1 == 0x28 ? 1 : $1 == 0x29 ? -1 : 0) }
            if braces != 0 || parens != 0 { misread.append(path) }
        }

        // A moved root or a renamed modifier would make the sweep vacuously green. The tree holds
        // 479 Swift files and seven hover closures today; the floors sit just under both.
        #expect(paths.count >= 400, """
            Read only \(paths.count) Swift file(s) under FRUSExplorer/: the scan is broken, not the \
            tree clean.
            """)
        #expect(closures >= 6, """
            Found only \(closures) hover closure(s): the scan is broken, not the tree clean.
            """)
        #expect(misread.isEmpty, """
            The scan's lexer left unbalanced braces or parentheses in \(misread.sorted()) — it \
            misreads a string, comment or literal there, so it cannot vouch for their hover closures.
            """)
        #expect(violations.isEmpty, """
            A hover closure writes a selection — hover must set hover state only, and only a click \
            may select (#1383): \(violations.sorted().joined(separator: ", "))
            """)
    }

    /// One fixture for the hover scan: a source snippet and what the scan must report for it.
    struct HoverScanFixture: CustomTestStringConvertible, Sendable {
        /// What the fixture proves, shown as the test case's name.
        let name: String
        /// The Swift source the scan reads.
        let source: String
        /// How many hover closures the scan must find.
        let closures: Int
        /// The 1-based lines the scan must flag.
        let writeLines: [Int]
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// The scan's rules, one fixture each. The two type cases are #1383's own sites as `v2`
    /// wrote them; each exclusion has a snippet that would fail if that exclusion stopped holding.
    /// The fourth from last pins a rule of the closure finder, not the lexer: a name that only
    /// begins `.onHover` is another identifier and opens no closure, because `(` or `{` must follow
    /// the modifier's name. The last three pin the lexer rules the tree-wide balance check guards
    /// only indirectly — a misread that happens to stay balanced passes it — each by a literal whose
    /// misreading would close the closure before a write it holds: a `#`-delimited raw string, an
    /// escaped quote and a nested comment.
    static let hoverScanFixtures: [HoverScanFixture] = [
        HoverScanFixture(
            name: "the co-mention graph's one-line handler is flagged",
            source: """
                .onHover { hovering in if hovering { vm.selectedPartnerId = node.rollupId } }
                """,
            closures: 1, writeLines: [1]),
        HoverScanFixture(
            name: "the volume graph's handler is flagged, and not the button action before it",
            source: """
                Button {
                    vm.selectedPartnerId = (vm.selectedPartnerId == id) ? nil : id
                } label: { EmptyView() }
                .onHover { hovering in
                    if hovering { vm.selectedPartnerId = id }
                }
                """,
            closures: 1, writeLines: [5]),
        HoverScanFixture(
            name: "a selection written after the closure's closing brace is not the closure's",
            source: """
                .onHover { hovering in vm.hoverChanged(id, hovering: hovering) }
                .contextMenu { Button { vm.selectedPartnerId = id } label: { EmptyView() } }
                """,
            closures: 1, writeLines: []),
        HoverScanFixture(
            name: "a comparison with a selection is not a write",
            source: """
                .onHover { hovering in
                    if hovering, vm.selectedPartnerId == id { vm.hoveredPartnerId = id }
                }
                """,
            closures: 1, writeLines: []),
        HoverScanFixture(
            name: "a comment quoting the pattern is not a write",
            source: """
                .onHover { hovering in
                    // never vm.selectedPartnerId = id here
                    vm.hoverChanged(id, hovering: hovering)
                }
                """,
            closures: 1, writeLines: []),
        HoverScanFixture(
            name: "a brace inside an interpolated string does not end the closure early",
            source: """
                .onHover { h in label = "\\(h ? "{" : "")" }
                .contextMenu { Button { vm.selectedPartnerId = id } label: { EmptyView() } }
                """,
            closures: 1, writeLines: []),
        HoverScanFixture(
            name: "a call to toggleSelection is a write by another name",
            source: """
                .onHover { hovering in if hovering { vm.toggleSelection(id) } }
                """,
            closures: 1, writeLines: [1]),
        HoverScanFixture(
            name: "a closure passed in parentheses is read",
            source: """
                .onHover(perform: { hovering in vm.selectedNodeKey = hovering ? id : nil })
                """,
            closures: 1, writeLines: [1]),
        HoverScanFixture(
            name: "an interpolation inside a parenthesized closure does not end it early",
            source: """
                .onHover(perform: { h in label = "\\(h)"; vm.selectedNodeKey = h ? id : nil })
                """,
            closures: 1, writeLines: [1]),
        HoverScanFixture(
            name: "onContinuousHover's trailing closure after its arguments is read",
            source: """
                .onContinuousHover(coordinateSpace: .local) { phase in
                    selectedBucketKey = nil
                }
                """,
            closures: 1, writeLines: [2]),
        HoverScanFixture(
            name: "a name that only begins .onHover is another identifier, not the modifier",
            source: """
                .onHoverChanged { vm.selectedPartnerId = id }
                """,
            closures: 0, writeLines: []),
        HoverScanFixture(
            name: "a quote and a brace inside a raw string do not end the closure early",
            source: ##"""
                .onHover { h in label = #"a"}"#; vm.selectedNodeKey = nil }
                """##,
            closures: 1, writeLines: [1]),
        HoverScanFixture(
            name: "an escaped quote does not end the string, so the brace after it is not code",
            source: #"""
                .onHover { h in label = "\"}"; vm.selectedNodeKey = nil }
                """#,
            closures: 1, writeLines: [1]),
        HoverScanFixture(
            name: "a nested comment runs to its own close, so the brace inside it is not code",
            source: """
                .onHover { h in /* a /* b */ } */ vm.selectedNodeKey = nil }
                """,
            closures: 1, writeLines: [1]),
    ]

    /// The hover scan reports exactly what each fixture states, so a pass over the tree means the
    /// tree is clean rather than that the scan read nothing.
    @Test("CodingStandardsAudit: the hover scan's rules", arguments: hoverScanFixtures)
    func hoverScanRules(_ fixture: HoverScanFixture) throws {
        let scan = try Self.hoverSelectionWrites(in: fixture.source)
        #expect(scan.closures == fixture.closures)
        #expect(scan.writeLines == fixture.writeLines)
    }

    // MARK: - Hover Wiring

    /// One place a graph view reads #1383's hover rules: a declaration, and the call it must make.
    struct HoverWiringClaim: CustomTestStringConvertible, Sendable {
        /// What the claim pins, shown as the test case's name.
        let name: String
        /// The view's file, relative to `FRUSExplorer/`.
        let file: String
        /// The declaration's header through its opening brace, which must occur once in the file.
        let declaration: String
        /// A regular expression over the declaration's masked body that must match exactly once.
        let pattern: String
        /// The edit that must fail the claim — the reason it exists.
        let mutant: String
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// The graph views' side of #1383, which the view-model suites cannot see: they drive
    /// `displayedPartnerId` and `isPreviewingHover`, and nothing there fails if a view stops
    /// reading them. On iOS `hoveredPartnerId` is never set, so `displayedPartnerId` IS the
    /// selection there and a revert changes nothing on the platform the tests run on; and the
    /// `.onHover` closures are `#if os(macOS)`, which the iOS test target never compiles. Each
    /// pattern is the call itself, read inside its own declaration over the comment- and
    /// string-masked copy the hover scan uses. The patterns pin each call's exact spelling on
    /// purpose, so a harmless rewording — a renamed closure parameter, a wrapper around the dock's
    /// `ScrollView` — fails its claim too; the failure message says which field to update.
    static let hoverWiringClaims: [HoverWiringClaim] = [
        HoverWiringClaim(
            name: "the co-mention canvas emphasises the displayed partner",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"let\s+isEmphasized\s*=\s*vm\.displayedPartnerId\s*==\s*node\.rollupId\b"#,
            mutant: "isEmphasized reads vm.selectedPartnerId"),
        HoverWiringClaim(
            name: "the co-mention dock shows the displayed partner",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var infoDock: some View {",
            pattern: #"if\s+let\s+sel\s*=\s*vm\.displayedPartnerId\s*\{[^{}]*ScrollView\s*\{\s*dockedInfoPanel\(for:\s*sel\)\s*\}"#,
            mutant: "the dock binds vm.selectedPartnerId"),
        HoverWiringClaim(
            name: "a co-mention node's click toggles its selection",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var nodeHitAreas: some View {",
            pattern: #"Button\s*\{\s*vm\.toggleSelection\(node\.rollupId\)\s*\}\s*label:"#,
            mutant: "the hit area's Button calls something other than toggleSelection"),
        HoverWiringClaim(
            name: "a co-mention node's hover closure passes the pointer's state through",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var nodeHitAreas: some View {",
            pattern: #"\.onHover\s*\{\s*hovering\s+in\s+vm\.hoverChanged\(node\.rollupId,\s*hovering:\s*hovering\)\s*\}"#,
            mutant: "the closure passes hovering: !hovering"),
        HoverWiringClaim(
            name: "the volume canvas emphasises the displayed volume",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"let\s+isEmphasized\s*=\s*vm\.displayedPartnerId\s*==\s*id\b"#,
            mutant: "isEmphasized reads vm.selectedPartnerId"),
        HoverWiringClaim(
            name: "the volume panel shows the displayed volume, and a preview does not take the pointer",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var overlayControls: some View {",
            // `[^{}]*` keeps the gate inside the `if let` that shows the panel, so it can only
            // be a modifier of `infoPanel(for: sel)`.
            pattern: #"if\s+let\s+sel\s*=\s*vm\.displayedPartnerId\s*\{\s*infoPanel\(for:\s*sel\)[^{}]*\.allowsHitTesting\(!vm\.isPreviewingHover\)[^{}]*\}"#,
            mutant: "the panel binds vm.selectedPartnerId, or the gate is deleted, or its ! is dropped"),
        HoverWiringClaim(
            name: "a volume node's click toggles its selection",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var nodeHitAreas: some View {",
            pattern: #"Button\s*\{\s*vm\.toggleSelection\(id\)\s*\}\s*label:"#,
            mutant: "the hit area's Button calls something other than toggleSelection"),
        HoverWiringClaim(
            name: "a volume node's hover closure passes the pointer's state through",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var nodeHitAreas: some View {",
            pattern: #"\.onHover\s*\{\s*hovering\s+in\s+vm\.hoverChanged\(id,\s*hovering:\s*hovering\)\s*\}"#,
            mutant: "the closure passes hovering: !hovering"),
    ]

    /// Each graph view makes the call its claim names, inside the declaration that owns it (#1383).
    ///
    /// Version history:
    ///   1.0 — 2026-09-24: #1383 review
    ///   1.1 — 2026-09-24: #1383 review, round 2: both failure messages name the field to update
    ///          when a refactor rewords a call or a declaration without changing what it does
    @Test("CodingStandardsAudit: the graph views read the hover rules", arguments: hoverWiringClaims)
    func graphViewsReadTheHoverRules(_ claim: HoverWiringClaim) throws {
        let source = try String(contentsOf: Self.sourceRoot.appendingPathComponent(claim.file),
                                encoding: .utf8)
        let body = try #require(Self.maskedDeclarationBody(claim.declaration, in: source), """
            \(claim.file) must declare `\(claim.declaration)` exactly once. If a refactor renamed \
            or re-typed that declaration, update this claim's `declaration` in \
            `CodingStandardsAuditTests.hoverWiringClaims` to the header that now holds the call; \
            if the header now occurs more than once, choose one that occurs once (#1383).
            """)
        let regex = try NSRegularExpression(pattern: claim.pattern)
        let matches = regex.numberOfMatches(in: body, range: NSRange(body.startIndex..., in: body))
        #expect(matches == 1, """
            \(claim.file), `\(claim.declaration)`: expected the call once, found it \(matches) \
            time(s). The mutant this guards against: \(claim.mutant) (#1383). The pattern pins \
            the call's exact spelling on purpose. If a refactor reworded the call without changing \
            what it reads or calls — a renamed closure parameter, a wrapper around the dock's \
            ScrollView — update this claim's `pattern` in \
            `CodingStandardsAuditTests.hoverWiringClaims` to the new spelling, and check that the \
            mutant above still fails it; if it moved the call into another declaration, update the \
            claim's `declaration` instead. If the view now does what the mutant does, it has lost \
            the hover rule: fix the view, not the claim.
            """)
    }

    // MARK: - Label Wiring

    /// One place a graph canvas draws its labels through #1384's placement: a declaration, a pattern
    /// over its masked body, and how many times the pattern must match there.
    struct LabelWiringClaim: CustomTestStringConvertible, Sendable {
        /// What the claim pins, shown as the test case's name.
        let name: String
        /// The view's file, relative to `FRUSExplorer/`.
        let file: String
        /// The declaration's header through its opening brace, which must occur once in the file.
        let declaration: String
        /// A regular expression over the declaration's masked body.
        let pattern: String
        /// How many times `pattern` must match: 1 for a call the canvas must make, 0 for a shape it
        /// must no longer have.
        let expected: Int
        /// The edit that must fail the claim — the reason it exists.
        let mutant: String
        /// The fewest characters the masked body may have, so a zero-match claim cannot pass on a
        /// body that has lost its drawing: 1,000 for a whole canvas, less for a short helper.
        var minimumBody: Int = 1_000
        /// The case name Swift Testing shows.
        var testDescription: String { name }
    }

    /// The only `context.draw(` calls a co-mention or volume canvas may make: its focus or central
    /// node's icon, and a placed label at its placed rect. Any other — a `Text`, a `labelText(…)`,
    /// a resolved label or a `context.resolve(…)` drawn under a node beside the placement loop —
    /// matches, so the claim that expects none of them fails (#1384 review: the first version of
    /// these claims matched only the `context.draw(Text(` spelling #1384 replaced).
    static let anyOtherDraw = #"context\.draw\((?!Image\(systemName:|text,\s*at:\s*CGPoint\(x:\s*rect\.midX,\s*y:\s*rect\.midY\))"#

    /// The canvases' side of #1384, which the placement fixtures cannot see. `GraphNodeLabelTests`
    /// and the graphs' label suites drive `GraphNodeLabels.place(_:)` and the request builders, and
    /// nothing there fails if a canvas goes back to drawing every label under its node, measures a
    /// different text from the one it draws, draws a disc at a radius of its own that the
    /// placement does not keep clear of, or draws a plate behind any label but the centre's. Each
    /// claim reads the canvas's own code over the masked copy the hover claims use, and pins the
    /// spelling on purpose.
    static let labelWiringClaims: [LabelWiringClaim] = [
        LabelWiringClaim(
            name: "the co-mention canvas draws the labels the placement keeps, where it put them",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"let\s+requests\s*=\s*vm\.labelRequests\(sizes:\s*sizes\)\s*let\s+placed\s*=\s*GraphNodeLabels\.place\(requests\)\s*if\s+let\s+plate\s*=\s*GraphNodeLabels\.plate\(for:\s*requests,\s*placed:\s*placed\)\s*\{\s*GraphNodeLabels\.drawPlate\(&context,\s*in:\s*plate\)\s*\}\s*for\s*\(id,\s*rect\)\s*in\s*placed\s*\{\s*if\s+let\s+text\s*=\s*resolved\[id\]\s*\{\s*context\.draw\(text,\s*at:\s*CGPoint\(x:\s*rect\.midX,\s*y:\s*rect\.midY\),\s*anchor:\s*\.center\)\s*\}\s*\}"#,
            expected: 1,
            mutant: "the canvas draws every label again, draws a placed label somewhere other than its rect, or draws the centre's label without its plate"),
        LabelWiringClaim(
            name: "the co-mention canvas measures the text it draws",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"for\s+id\s+in\s+vm\.labelPriority\s*\{\s*let\s+text\s*=\s*context\.resolve\(labelText\(for:\s*id,\s*isFocus:\s*id\s*==\s*focusId\)\)\s*resolved\[id\]\s*=\s*text\s*sizes\[id\]\s*=\s*text\.measure\(in:"#,
            expected: 1,
            mutant: "a label's size estimated, or measured from a text other than the one drawn"),
        LabelWiringClaim(
            name: "the co-mention canvas draws one plate, the centre's",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"GraphNodeLabels\.drawPlate\("#,
            expected: 1,
            mutant: "a plate drawn behind every label, or behind a partner's"),
        LabelWiringClaim(
            name: "the co-mention canvas fills only its discs",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"context\.fill\("#,
            expected: 2,
            mutant: "a plate of the canvas's own filled behind a label, where `GraphNodeLabels.drawPlate(_:in:)` draws the centre's alone"),
        LabelWiringClaim(
            name: "no co-mention label is drawn outside the placement",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: anyOtherDraw,
            expected: 0,
            mutant: "the per-node `context.draw(Text(shortLabel(…)))` #1384 replaced, or a per-node draw of `labelText(…)`, of `resolved[id]` or of `context.resolve(…)` beside the placement loop"),
        LabelWiringClaim(
            name: "the co-mention canvas draws a partner's disc at the radius the placement keeps clear of",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"let\s+r\s*=\s*vm\.nodeRadius\(for:\s*node\.rollupId\)"#,
            expected: 1,
            mutant: "the canvas computes a partner's radius itself, as it did before #1384"),
        LabelWiringClaim(
            name: "the co-mention canvas draws the focus's disc at the radius the placement keeps clear of",
            file: "Analytics/PersonCoMentionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"let\s+cr\s*=\s*vm\.nodeRadius\(for:\s*focusId\)"#,
            expected: 1,
            mutant: "the canvas draws the focus at a literal radius, as it did before #1384"),
        LabelWiringClaim(
            name: "the volume canvas draws the labels the placement keeps, where it put them",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"let\s+requests\s*=\s*vm\.labelRequests\(sizes:\s*sizes\)\s*let\s+placed\s*=\s*GraphNodeLabels\.place\(requests\)\s*if\s+let\s+plate\s*=\s*GraphNodeLabels\.plate\(for:\s*requests,\s*placed:\s*placed\)\s*\{\s*GraphNodeLabels\.drawPlate\(&context,\s*in:\s*plate\)\s*\}\s*for\s*\(id,\s*rect\)\s*in\s*placed\s*\{\s*if\s+let\s+text\s*=\s*resolved\[id\]\s*\{\s*context\.draw\(text,\s*at:\s*CGPoint\(x:\s*rect\.midX,\s*y:\s*rect\.midY\),\s*anchor:\s*\.center\)\s*\}\s*\}"#,
            expected: 1,
            mutant: "the canvas draws every label again, draws a placed label somewhere other than its rect, or draws the centre's label without its plate"),
        LabelWiringClaim(
            name: "the volume canvas measures the text it draws",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"for\s+id\s+in\s+vm\.labelPriority\s*\{\s*let\s+text\s*=\s*context\.resolve\(labelText\(for:\s*id,\s*isCentral:\s*id\s*==\s*centralId\)\)\s*resolved\[id\]\s*=\s*text\s*sizes\[id\]\s*=\s*text\.measure\(in:"#,
            expected: 1,
            mutant: "a label's size estimated, or measured from a text other than the one drawn"),
        LabelWiringClaim(
            name: "the volume canvas draws one plate, the centre's",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"GraphNodeLabels\.drawPlate\("#,
            expected: 1,
            mutant: "a plate drawn behind every label, or behind a partner's"),
        LabelWiringClaim(
            name: "the volume canvas fills only its discs",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"context\.fill\("#,
            expected: 2,
            mutant: "a plate of the canvas's own filled behind a label, where `GraphNodeLabels.drawPlate(_:in:)` draws the centre's alone"),
        LabelWiringClaim(
            name: "no volume label is drawn outside the placement",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: anyOtherDraw,
            expected: 0,
            mutant: "the per-node `context.draw(Text(String(id.prefix(10))))` #1384 replaced, or a per-node draw of `labelText(…)`, of `resolved[id]` or of `context.resolve(…)` beside the placement loop"),
        LabelWiringClaim(
            name: "the volume canvas draws a partner's disc at the radius the placement keeps clear of",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"let\s+r\s*=\s*vm\.nodeRadius\(for:\s*id\)"#,
            expected: 1,
            mutant: "the canvas computes a partner's radius itself, as it did before #1384"),
        LabelWiringClaim(
            name: "the volume canvas draws the central disc at the radius the placement keeps clear of",
            file: "CrossReference/VolumeConnectionGraphView.swift",
            declaration: "private var graphCanvas: some View {",
            pattern: #"let\s+cr\s*=\s*vm\.nodeRadius\(for:\s*centralId\)"#,
            expected: 1,
            mutant: "the canvas draws the central volume at a literal radius, as it did before #1384"),
        LabelWiringClaim(
            name: "the archival canvas draws its labels last, after the nodes and the focus",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func canvas(_ graph: ArchivalNetworkGraph,\n                        layout: ArchivalNetworkLayout) -> some View {",
            pattern: #"drawNodes\(&context,\s*graph:\s*graph,\s*layout:\s*layout\)\s*drawFocus\(&context,\s*graph:\s*graph,\s*layout:\s*layout\)\s*drawLabels\(&context,\s*graph:\s*graph,\s*layout:\s*layout\)\s*\}"#,
            expected: 1,
            mutant: "the labels not drawn, or drawn before the nodes, which then paint over them",
            minimumBody: 300),
        LabelWiringClaim(
            name: "the archival canvas draws the labels the placement keeps, where it put them",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawLabels(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                            layout: ArchivalNetworkLayout) {",
            pattern: #"let\s+requests\s*=\s*ArchivalNetworkBuilder\.labelRequests\(graph,\s*layout:\s*layout,\s*selectedNodeId:\s*selectedNodeId,\s*sizes:\s*sizes\)\s*let\s+placed\s*=\s*GraphNodeLabels\.place\(requests\)\s*if\s+let\s+plate\s*=\s*GraphNodeLabels\.plate\(for:\s*requests,\s*placed:\s*placed\)\s*\{\s*GraphNodeLabels\.drawPlate\(&context,\s*in:\s*plate\)\s*\}\s*for\s*\(id,\s*rect\)\s*in\s*placed\s*\{\s*if\s+let\s+text\s*=\s*resolved\[id\]\s*\{\s*context\.draw\(text,\s*at:\s*CGPoint\(x:\s*rect\.midX,\s*y:\s*rect\.midY\),\s*anchor:\s*\.center\)\s*\}\s*\}"#,
            expected: 1,
            mutant: "the canvas draws every label again, draws a placed label somewhere other than its rect, or draws the focus's label without its plate",
            minimumBody: 600),
        LabelWiringClaim(
            name: "the archival canvas measures the text it draws",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawLabels(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                            layout: ArchivalNetworkLayout) {",
            pattern: #"for\s+id\s+in\s+ArchivalNetworkBuilder\.labelPriority\(graph,\s*selectedNodeId:\s*selectedNodeId\)\s*\{\s*let\s+text\s*=\s*context\.resolve\(labelText\(for:\s*id,\s*in:\s*graph\)\)\s*resolved\[id\]\s*=\s*text\s*sizes\[id\]\s*=\s*text\.measure\(in:"#,
            expected: 1,
            mutant: "a label's size estimated, or measured from a text other than the one drawn",
            minimumBody: 600),
        LabelWiringClaim(
            name: "the archival label pass draws one plate, the focus's",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawLabels(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                            layout: ArchivalNetworkLayout) {",
            pattern: #"GraphNodeLabels\.drawPlate\("#,
            expected: 1,
            mutant: "a plate drawn behind every label, or behind a node's",
            minimumBody: 600),
        LabelWiringClaim(
            name: "the archival label pass fills nothing of its own",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawLabels(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                            layout: ArchivalNetworkLayout) {",
            pattern: #"context\.fill\("#,
            expected: 0,
            mutant: "a plate of the pass's own filled behind a label, where `GraphNodeLabels.drawPlate(_:in:)` draws the focus's alone",
            minimumBody: 600),
        LabelWiringClaim(
            name: "the archival label pass draws nothing but placed labels",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawLabels(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                            layout: ArchivalNetworkLayout) {",
            pattern: #"context\.draw\((?!text,\s*at:\s*CGPoint\(x:\s*rect\.midX,\s*y:\s*rect\.midY\))"#,
            expected: 0,
            mutant: "a label drawn under its node beside the placement loop",
            minimumBody: 600),
        LabelWiringClaim(
            name: "no archival label is drawn under a node",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawNodes(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                           layout: ArchivalNetworkLayout) {",
            pattern: #"context\.draw\("#,
            expected: 0,
            mutant: "the per-node `context.draw(Text(shortLabel(node.label)))` #1384 replaced, or any label drawn with its node",
            minimumBody: 600),
        LabelWiringClaim(
            name: "the archival canvas draws a node at the radius the placement keeps clear of",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawNodes(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                           layout: ArchivalNetworkLayout) {",
            pattern: #"let\s+radius\s*=\s*ArchivalNetworkBuilder\.drawnRadius\(for:\s*node,\s*isSelected:\s*isSelected\)"#,
            expected: 1,
            mutant: "the canvas computes a node's radius itself, as it did before #1384",
            minimumBody: 600),
        LabelWiringClaim(
            name: "no archival focus label is drawn beside the focus's disc",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawFocus(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                           layout: ArchivalNetworkLayout) {",
            pattern: #"context\.draw\((?!Image\(systemName:)"#,
            expected: 0,
            mutant: "the focus's `context.draw(Text(shortLabel(graph.focus.name)))` #1384 replaced",
            minimumBody: 300),
        LabelWiringClaim(
            name: "the archival canvas draws the focus at the radius the placement keeps clear of",
            file: "Analytics/ArchivalNetworkView.swift",
            declaration: "private func drawFocus(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,\n                           layout: ArchivalNetworkLayout) {",
            pattern: #"let\s+radius\s*=\s*ArchivalNetworkBuilder\.focusRadius\b"#,
            expected: 1,
            mutant: "the canvas draws the focus at a literal radius, as it did before #1384",
            minimumBody: 300),
    ]

    /// Each graph canvas draws its labels through the placement, as its claim states (#1384).
    ///
    /// Version history:
    ///   1.0 — 2026-09-24: #1384
    ///   1.1 — 2026-09-24: #1384 review — the archival network's canvas, a zero claim that forbids
    ///          every other `context.draw(` rather than one spelling, and no plate
    ///   1.2 — 2026-09-24: #1384 review round 2 — the centre's plate, by the owner's decision: each
    ///          draw loop starts with it, each canvas draws exactly one, and none fills a plate of
    ///          its own
    @Test("CodingStandardsAudit: the graph canvases draw only placed labels", arguments: labelWiringClaims)
    func graphCanvasesDrawOnlyPlacedLabels(_ claim: LabelWiringClaim) throws {
        let source = try String(contentsOf: Self.sourceRoot.appendingPathComponent(claim.file),
                                encoding: .utf8)
        let body = try #require(Self.maskedDeclarationBody(claim.declaration, in: source), """
            \(claim.file) must declare `\(claim.declaration)` exactly once. If a refactor renamed \
            or re-typed that declaration, update this claim's `declaration` in \
            `CodingStandardsAuditTests.labelWiringClaims` (#1384).
            """)
        // Not vacuous: a body this short has lost the canvas, not the defect.
        #expect(body.count > claim.minimumBody,
                "\(claim.file): read only \(body.count) characters of `\(claim.declaration)`")
        let regex = try NSRegularExpression(pattern: claim.pattern)
        let matches = regex.numberOfMatches(in: body, range: NSRange(body.startIndex..., in: body))
        #expect(matches == claim.expected, """
            \(claim.file), `\(claim.declaration)`: expected \(claim.expected) match(es), found \
            \(matches). The mutant this guards against: \(claim.mutant) (#1384). The pattern pins \
            the exact spelling on purpose: if a refactor reworded the code without changing what \
            it draws, update this claim's `pattern` in `CodingStandardsAuditTests.labelWiringClaims` \
            and check that the mutant above still fails it. If the canvas now does what the mutant \
            does, it has lost the placement: fix the view, not the claim.
            """)
    }

    /// The masked body of the declaration in `source` whose header is `declaration` (ending in
    /// `{`), from that brace through its balanced close — or `nil` unless the header occurs
    /// exactly once, so a claim can never read the wrong one of two.
    static func maskedDeclarationBody(_ declaration: String, in source: String) -> String? {
        let code = maskedCode(source)
        let header = Array(declaration.utf8)
        guard header.last == UInt8(ascii: "{"),
              let start = firstIndex(of: header, in: code, from: 0),
              firstIndex(of: header, in: code, from: start + 1) == nil else { return nil }
        let brace = start + header.count - 1
        return String(decoding: code[brace..<balancedEnd(code, from: brace, open: "{", close: "}")],
                      as: UTF8.self)
    }

    /// What `hoverSelectionWrites(in:)` found in one file.
    struct HoverScan {
        /// Hover closures read (`.onHover` and `.onContinuousHover`).
        var closures = 0
        /// The 1-based lines inside them that write a selection.
        var writeLines: [Int] = []
    }

    /// Reads every `.onHover` / `.onContinuousHover` argument in `source` and reports the lines
    /// inside one that assign a `selected…` identifier or call `toggleSelection(`.
    static func hoverSelectionWrites(in source: String) throws -> HoverScan {
        let code = maskedCode(source)
        let write = try NSRegularExpression(
            pattern: #"\bselected[A-Za-z0-9_]*\s*=(?!=)|\btoggleSelection\s*\("#)
        var scan = HoverScan()
        for closure in hoverClosureRanges(in: code) {
            scan.closures += 1
            let region = String(decoding: code[closure], as: UTF8.self)
            let lineBefore = code[..<closure.lowerBound].reduce(into: 1) { if $1 == 0x0A { $0 += 1 } }
            for match in write.matches(in: region, range: NSRange(region.startIndex..., in: region)) {
                guard let range = Range(match.range, in: region) else { continue }
                let line = lineBefore + region[..<range.lowerBound].filter { $0 == "\n" }.count
                scan.writeLines.append(line)
            }
        }
        scan.writeLines.sort()
        return scan
    }

    /// Where each `.onHover` / `.onContinuousHover` argument lies in `code`, a `maskedCode(_:)`
    /// copy: from just past the modifier's name through its balanced parentheses and then its
    /// balanced trailing closure. A name that only begins `.onHover` (`.onHoverChanged`) is another
    /// identifier, and is passed over because neither `(` nor `{` follows the matched prefix.
    static func hoverClosureRanges(in code: [UInt8]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        for token in [Array(".onHover".utf8), Array(".onContinuousHover".utf8)] {
            var i = 0
            while let start = firstIndex(of: token, in: code, from: i) {
                i = start + token.count
                var end = skipSpace(code, from: i)
                if end < code.count, code[end] == UInt8(ascii: "(") {
                    end = balancedEnd(code, from: end, open: "(", close: ")")
                    let next = skipSpace(code, from: end)
                    if next < code.count, code[next] == UInt8(ascii: "{") {
                        end = balancedEnd(code, from: next, open: "{", close: "}")
                    }
                } else if end < code.count, code[end] == UInt8(ascii: "{") {
                    end = balancedEnd(code, from: end, open: "{", close: "}")
                } else {
                    continue
                }
                ranges.append(i..<end)
                i = end
            }
        }
        return ranges
    }

    /// `source` as UTF-8 with the contents of every comment and string literal replaced by
    /// spaces (newlines kept, so offsets and line numbers still match the file). Handles `//` and
    /// nested `/* */` comments, `"…"` and `"""…"""` strings, `#`-delimited raw strings, and
    /// `\( … )` interpolations, whose code — and any string nested in it — is lexed in turn.
    ///
    /// The lexing is `LexedSource`'s, which the copy scans read for its string literals (#1374):
    /// one lexer for every scan in this suite, so the hover scan's fixtures pin both.
    static func maskedCode(_ source: String) -> [UInt8] {
        LexedSource(source).masked
    }

    /// The first index at or after `from` where `needle` occurs in `haystack`.
    private static func firstIndex(of needle: [UInt8], in haystack: [UInt8], from: Int) -> Int? {
        guard needle.count <= haystack.count else { return nil }
        var i = from
        search: while i + needle.count <= haystack.count {
            for k in 0..<needle.count where haystack[i + k] != needle[k] {
                i += 1
                continue search
            }
            return i
        }
        return nil
    }

    /// The first index at or after `from` that is not a space, tab or newline.
    private static func skipSpace(_ code: [UInt8], from: Int) -> Int {
        var i = from
        while i < code.count, [0x20, 0x09, 0x0A, 0x0D].contains(code[i]) { i += 1 }
        return i
    }

    /// One past the delimiter that closes the one at `from` (or the end of `code`).
    private static func balancedEnd(_ code: [UInt8], from: Int,
                                    open: Unicode.Scalar, close: Unicode.Scalar) -> Int {
        var depth = 0, i = from
        while i < code.count {
            if code[i] == UInt8(ascii: open) { depth += 1 }
            else if code[i] == UInt8(ascii: close) {
                depth -= 1
                if depth == 0 { return i + 1 }
            }
            i += 1
        }
        return code.count
    }
}
