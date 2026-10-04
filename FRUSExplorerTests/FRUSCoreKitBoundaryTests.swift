// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

// MARK: - FRUSCoreKitBoundaryTests

/// FRUSCoreKit compiles with Foundation alone, on Apple platforms and on Linux, and names nothing
/// that lives only in the app.
///
/// ## Why a source scan
/// Both app targets compile `FRUSCoreKit/` into the app's own module, so the app's build cannot tell
/// a kit file that calls the app from one that does not: it builds either way. Only the package
/// fails — `swift build --target FRUSCoreKit`, which compiles the kit alone — and nothing runs that
/// on every change here. FRUS Explorer Light compiles the same files on Linux from a pinned commit,
/// so a kit file that imported SwiftUI or named `IndexingPipeline` would break the web edition
/// unseen until its pin next moved. These scans read the source, so the app's own test run fails:
/// - every import but Foundation is a module the kit may use, inside the `#if canImport` that
///   selects it (``importRuleViolations(in:)``);
/// - no kit file reads `Bundle.main` or `UserDefaults`: the app reads them and passes the kit what
///   it read (the broken-refs index, the citation style);
/// - no kit file names a type, function, constant or variable the app declares at the top level of
///   a file under `FRUSExplorer/`, outside comments and string literals (``topLevelTypes(in:)``,
///   ``topLevelFunctionsAndGlobals(in:)``, ``appNames(in:among:)``);
/// - every line of code under `FRUSCoreKit/Linux/` is inside a `#if !canImport(…)`, so an Apple
///   platform compiles nothing from it;
/// - every suite under `FRUSExplorerTests/FRUSCoreKit/` opens with the header that imports the kit
///   in the package and the app in Xcode, and imports the app's modules only in Xcode;
/// - no suite there names, outside Xcode's branches (``linesByCompiler(_:)``), what the package
///   lacks: the app's top-level declarations, or those of the test target's other files, which
///   Xcode compiles beside the suites. Xcode builds and passes such a suite; `swift test` does not;
/// - `project.yml` compiles the kit in both app targets, and `Package.swift` declares it and its
///   suites as targets.
///
/// What it cannot see: a member the app adds to a type it does not declare (an extension of a kit
/// type, or of a Foundation one such as `String`), an app type nested in another, and a declaration
/// whose keyword does not start its line. The package build catches those.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: initial implementation
@Suite("FRUSCoreKit — Foundation only, and nothing that lives in the app")
struct FRUSCoreKitBoundaryTests {

    /// The repository root, from this file's location.
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Each `.swift` file under `directory` (relative to the repository root), by its path from the
    /// root, with its text.
    static func sources(under directory: String) throws -> [(path: String, text: String)] {
        let root = repoRoot.appendingPathComponent(directory)
        return try FileManager.default.subpathsOfDirectory(atPath: root.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { ("\(directory)/\($0)", try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8)) }
    }

    /// `source` with every comment and string literal blanked, as lines.
    static func codeLines(_ source: String) -> [String] {
        String(decoding: CodingStandardsAuditTests.maskedCode(source), as: UTF8.self)
            .components(separatedBy: "\n")
    }

    // MARK: Imports

    /// The modules a kit file may import besides Foundation, each with the condition whose branch
    /// it must sit in: swift-crypto's `Crypto` stands in for CryptoKit, so it is the `#else`.
    static let permittedImports: [String: (condition: String, inElse: Bool)] = [
        "FoundationXML": ("canImport(FoundationXML)", false),
        "CryptoKit": ("canImport(CryptoKit)", false),
        "Crypto": ("canImport(CryptoKit)", true),
        "SourceNoteKit": ("canImport(SourceNoteKit)", false),
    ]

    /// Each import in `source` that breaks the kit's rule, as `line: import`: Foundation anywhere;
    /// a permitted module only directly inside the branch of its own condition; nothing else.
    static func importRuleViolations(in source: String) -> [String] {
        var branches: [(condition: String, inElse: Bool)] = []
        var violations: [String] = []
        for (index, line) in codeLines(source).enumerated() {
            let code = line.trimmingCharacters(in: .whitespaces)
            if code.hasPrefix("#if ") {
                branches.append((String(code.dropFirst(4)).trimmingCharacters(in: .whitespaces), false))
            } else if code.hasPrefix("#elseif") || code.hasPrefix("#else"), !branches.isEmpty {
                branches[branches.count - 1].inElse = true
            } else if code.hasPrefix("#endif"), !branches.isEmpty {
                branches.removeLast()
            } else if code.hasPrefix("import ") || code.contains(" import ") && code.hasPrefix("@") {
                let module = code.components(separatedBy: " ").last ?? ""
                if module == "Foundation" { continue }
                guard let rule = permittedImports[module], let branch = branches.last,
                      branch.condition == rule.condition, branch.inElse == rule.inElse else {
                    violations.append("\(index + 1): \(code)")
                    continue
                }
            }
        }
        return violations
    }

    @Test("Every kit file imports Foundation, and any other module only behind the canImport that selects it")
    func kitImportsOnlyWhatLinuxHas() throws {
        let kit = try Self.sources(under: "FRUSCoreKit")
        #expect(kit.count >= 15, "read only \(kit.count) kit files: the walk is broken, not the kit clean")
        let violations = kit.flatMap { file in Self.importRuleViolations(in: file.text).map { "\(file.path):\($0)" } }
        #expect(violations.isEmpty, """
            A kit file imports a module Linux does not have, or outside its guard. The kit compiles \
            with Foundation alone; an Apple-only declaration it needs moves into the kit, and an \
            Apple-only half of a kit type moves into the app (CLAUDE.md, FRUSCoreKit):
            \(violations.joined(separator: "\n"))
            """)
    }

    @Test("The import rule: Foundation anywhere, a permitted module only in its own branch")
    func importRule() {
        #expect(Self.importRuleViolations(in: "import Foundation\n").isEmpty)
        #expect(Self.importRuleViolations(in: "#if canImport(FoundationXML)\nimport FoundationXML\n#endif\n").isEmpty)
        #expect(Self.importRuleViolations(in: "#if canImport(CryptoKit)\nimport CryptoKit\n#else\nimport Crypto\n#endif\n").isEmpty)
        // Apple-only, guarded or not.
        #expect(Self.importRuleViolations(in: "import SwiftUI\n") == ["1: import SwiftUI"])
        #expect(Self.importRuleViolations(in: "#if canImport(SwiftUI)\nimport SwiftUI\n#endif\n") == ["2: import SwiftUI"])
        // A permitted module unguarded, in the wrong branch, or under another module's guard.
        #expect(Self.importRuleViolations(in: "import CryptoKit\n") == ["1: import CryptoKit"])
        #expect(Self.importRuleViolations(in: "#if canImport(CryptoKit)\nimport Crypto\n#endif\n") == ["2: import Crypto"])
        #expect(Self.importRuleViolations(in: "#if canImport(Darwin)\nimport SourceNoteKit\n#endif\n")
                == ["2: import SourceNoteKit"])
        // An attributed import is an import, and an import in a comment or a string is not.
        #expect(Self.importRuleViolations(in: "@preconcurrency import WebKit\n") == ["1: @preconcurrency import WebKit"])
        #expect(Self.importRuleViolations(in: "// import SwiftUI\nlet s = \"import UIKit\"\n").isEmpty)
    }

    // MARK: The app's settings and bundle

    @Test("No kit file reads Bundle.main or UserDefaults")
    func kitReadsNoBundleOrDefaults() throws {
        var sites: [String] = []
        for file in try Self.sources(under: "FRUSCoreKit") {
            for (index, line) in Self.codeLines(file.text).enumerated()
            where line.contains("Bundle.main") || line.contains("UserDefaults") {
                sites.append("\(file.path):\(index + 1)")
            }
        }
        #expect(sites.isEmpty, """
            A kit file reads the app's bundle or settings. The kit is given what the app read — \
            `BrokenRefsIndexStore` and `CitationStyle.current` stay in the app for this reason:
            \(sites.joined(separator: "\n"))
            """)
    }

    // MARK: The app's types

    /// The types `source` declares at the top level of its file and could be named from another
    /// file: every `struct`, `class`, `enum`, `actor`, `protocol` or `typealias` at the start of a
    /// line, after its attributes and modifiers, unless it is `private` or `fileprivate`.
    static func topLevelTypes(in source: String) -> Set<String> {
        let declaration = /^(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|internal|open|final|nonisolated|indirect)\s+)*(?:struct|class|enum|actor|protocol|typealias)\s+([A-Z]\w*)/
        var names: Set<String> = []
        for line in codeLines(source) {
            if let match = line.firstMatch(of: declaration) { names.insert(String(match.1)) }
        }
        return names
    }

    /// The functions, constants and variables `source` declares at the top level of its file and
    /// could be named from another file: every `func`, `let` or `var` at the start of a line, after
    /// its attributes and modifiers, unless it is `private` or `fileprivate`. An operator has no name
    /// to find, so it is left out.
    static func topLevelFunctionsAndGlobals(in source: String) -> Set<String> {
        let declaration = /^(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|internal|nonisolated(?:\(unsafe\))?)\s+)*(?:func|let|var)\s+([A-Za-z_]\w*)/
        var names: Set<String> = []
        for line in codeLines(source) {
            if let match = line.firstMatch(of: declaration) { names.insert(String(match.1)) }
        }
        return names
    }

    /// Everything the files under `directory` declare at the top level that another file could name:
    /// types (``topLevelTypes(in:)``), and functions, constants and variables
    /// (``topLevelFunctionsAndGlobals(in:)``).
    static func topLevelDeclarations(under directory: String) throws -> Set<String> {
        try sources(under: directory).reduce(into: Set<String>()) {
            $0.formUnion(topLevelTypes(in: $1.text))
            $0.formUnion(topLevelFunctionsAndGlobals(in: $1.text))
        }
    }

    /// The identifiers on one line of code that are in `names`, in order.
    static func identifiers(on line: String, among names: Set<String>) -> [String] {
        line.matches(of: /[A-Za-z_][A-Za-z0-9_]*/).map { String($0.output) }.filter { names.contains($0) }
    }

    /// The identifiers in `source`'s code that are in `names`, each with its 1-based line.
    static func appNames(in source: String, among names: Set<String>) -> [String] {
        codeLines(source).enumerated().flatMap { index, line in
            identifiers(on: line, among: names).map { "\(index + 1): \($0)" }
        }
    }

    @Test("No kit file names a type, function, constant or variable the app declares")
    func kitNamesNoAppType() throws {
        let declared = try Self.topLevelDeclarations(under: "FRUSExplorer")
        // The walk is real: the app's model, view model and pipeline are among them, and two of its
        // free functions.
        #expect(declared.isSuperset(of: ["IndexingPipeline", "DocumentViewModel", "AppState", "DocumentHighlight",
                                         "frusSubseries", "formattedBytes"]),
                "the app's declarations were not read: \(declared.count) found")
        var sites: [String] = []
        for file in try Self.sources(under: "FRUSCoreKit") {
            sites += Self.appNames(in: file.text, among: declared).map { "\(file.path):\($0)" }
        }
        #expect(sites.isEmpty, """
            A kit file names a declaration that lives in the app. The app builds — it compiles both \
            into one module — but `swift build --target FRUSCoreKit` and FRUS Explorer Light do not. \
            Move the declaration into the kit, with a forwarder or typealias in the app under the old \
            name:
            \(sites.joined(separator: "\n"))
            """)
    }

    @Test("The app-type rule reads top-level declarations, and code only")
    func appTypeRule() {
        let app = """
            @Observable @MainActor
            public final class Viewer {}
            struct Store { enum Nested {} }
            private struct Hidden {}
            extension Formatter {}
            typealias Alias = Int
            """
        // An attribute on a line of its own leaves the keyword's line to be read; a nested type, a
        // private one and an extension are not names another file can call.
        #expect(Self.topLevelTypes(in: app) == ["Viewer", "Store", "Alias"])
        #expect(Self.topLevelTypes(in: "@MainActor final class Viewer {}\n") == ["Viewer"])
        let kit = """
            // Viewer calls this.
            let s = "Store"
            let x = Store.shared
            """
        #expect(Self.appNames(in: kit, among: ["Store", "Viewer"]) == ["3: Store"])
        // Free functions and globals, read the same way; a member, an operator and a private one are
        // not names another file can call.
        let globals = """
            func frusSubseries(from id: String) -> String? { nil }
            @MainActor public func bringToFront() {}
            nonisolated(unsafe) var cache = 0
            let log = 1
            private func helper() {}
            fileprivate let hidden = 2
            func == (a: Store, b: Store) -> Bool { true }
            struct Store { func member() {}; static let shared = Store() }
                let indented = 3
            """
        #expect(Self.topLevelFunctionsAndGlobals(in: globals) == ["frusSubseries", "bringToFront", "cache", "log"])
    }

    // MARK: Linux-only files

    @Test("Every line of code under FRUSCoreKit/Linux/ is compiled out wherever Darwin exists")
    func linuxShimsCompileToNothingOnApplePlatforms() throws {
        let shims = try Self.sources(under: "FRUSCoreKit/Linux")
        #expect(!shims.isEmpty, "FRUSCoreKit/Linux/ holds no Swift file")
        var unguarded: [String] = []
        for file in shims {
            var conditions: [String] = []
            for (index, line) in Self.codeLines(file.text).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("#if ") { conditions.append(String(code.dropFirst(4))); continue }
                if code.hasPrefix("#endif") { _ = conditions.popLast(); continue }
                if code.hasPrefix("#else") || code.hasPrefix("#elseif") {
                    // An #else would compile on the platforms the #if left out: the Apple ones.
                    unguarded.append("\(file.path):\(index + 1): \(code)")
                    continue
                }
                guard !code.isEmpty else { continue }
                if !conditions.contains(where: { $0.hasPrefix("!canImport(") }) {
                    unguarded.append("\(file.path):\(index + 1): \(code)")
                }
            }
        }
        #expect(unguarded.isEmpty, """
            Code under FRUSCoreKit/Linux/ that an Apple platform compiles. Those files are stand-ins \
            for what only Apple's Foundation has, and the app must reach the system's own:
            \(unguarded.joined(separator: "\n"))
            """)
    }

    // MARK: The kit's suites

    /// Each line of `source`'s code, with whether only Xcode compiles it: inside `#if !SWIFT_PACKAGE`,
    /// or in the `#else` of `#if SWIFT_PACKAGE`. A directive's own line counts as Xcode's, since it
    /// names nothing either compiler builds.
    static func linesByCompiler(_ source: String) -> [(code: String, xcodeOnly: Bool)] {
        var branches: [(condition: String, inElse: Bool)] = []
        var lines: [(code: String, xcodeOnly: Bool)] = []
        for line in codeLines(source) {
            let code = line.trimmingCharacters(in: .whitespaces)
            if code.hasPrefix("#if ") {
                branches.append((String(code.dropFirst(4)), false))
            } else if code.hasPrefix("#else"), !branches.isEmpty {
                branches[branches.count - 1].inElse = true
            } else if code.hasPrefix("#endif"), !branches.isEmpty {
                branches.removeLast()
            } else {
                let xcodeOnly = branches.contains { $0.condition == "SWIFT_PACKAGE" && $0.inElse }
                    || branches.contains { $0.condition == "!SWIFT_PACKAGE" && !$0.inElse }
                lines.append((line, xcodeOnly))
                continue
            }
            lines.append((line, true))
        }
        return lines
    }

    @Test("Every suite under FRUSExplorerTests/FRUSCoreKit/ imports the kit in the package and the app only in Xcode")
    func kitSuitesCompileAgainstTheKitAlone() throws {
        let suites = try Self.sources(under: "FRUSExplorerTests/FRUSCoreKit")
        #expect(suites.count >= 11, "read only \(suites.count) suites under FRUSExplorerTests/FRUSCoreKit/")
        let header = "#if SWIFT_PACKAGE\n@testable import FRUSCoreKit\n#else\n"
        var problems: [String] = []
        for file in suites {
            if !file.text.contains(header) { problems.append("\(file.path): no `#if SWIFT_PACKAGE` header") }
            for (index, line) in Self.linesByCompiler(file.text).enumerated() where !line.xcodeOnly {
                let code = line.code.trimmingCharacters(in: .whitespaces)
                guard code.hasPrefix("import ") || code.hasPrefix("@testable import ") else { continue }
                let module = code.components(separatedBy: " ").last ?? ""
                guard !["Foundation", "Testing", "FRUSCoreKit"].contains(module) else { continue }
                problems.append("\(file.path):\(index + 1): \(code) outside the Xcode branch")
            }
        }
        #expect(problems.isEmpty, """
            A suite the package compiles against FRUSCoreKit alone imports the app, or lacks the header \
            that chooses the module. `swift test --filter FRUSCoreKitTests` would not build:
            \(problems.joined(separator: "\n"))
            """)
    }

    @Test("No suite under FRUSExplorerTests/FRUSCoreKit/ names what the package lacks outside Xcode's branches")
    func kitSuitesNameOnlyWhatThePackageHas() throws {
        // What the package lacks: the app's top-level declarations, and those of the test target's
        // other files, which Xcode compiles beside the suites and the package does not.
        var absent = try Self.topLevelDeclarations(under: "FRUSExplorer")
        for file in try Self.sources(under: "FRUSExplorerTests") where !file.path.hasPrefix("FRUSExplorerTests/FRUSCoreKit/") {
            absent.formUnion(Self.topLevelTypes(in: file.text))
            absent.formUnion(Self.topLevelFunctionsAndGlobals(in: file.text))
        }
        // The walk is real: the app's pipeline and scheme handler, and a helper of the test target's.
        #expect(absent.isSuperset(of: ["IndexingPipeline", "FRUSURLSchemeHandler", "makeTestPipeline"]),
                "the declarations the package lacks were not read: \(absent.count) found")
        var sites: [String] = []
        for file in try Self.sources(under: "FRUSExplorerTests/FRUSCoreKit") {
            for (index, line) in Self.linesByCompiler(file.text).enumerated() where !line.xcodeOnly {
                sites += Self.identifiers(on: line.code, among: absent).map { "\(file.path):\(index + 1): \($0)" }
            }
        }
        #expect(sites.isEmpty, """
            A suite the package compiles against FRUSCoreKit alone names a declaration of the app's or \
            of the test target's other files. Xcode builds and passes it; `swift test --filter \
            FRUSCoreKitTests` and FRUS Explorer Light do not. Call the kit's name, or put the line \
            inside `#if !SWIFT_PACKAGE` with the reason on the guard:
            \(sites.joined(separator: "\n"))
            """)
    }

    @Test("The compiler rule: Xcode's lines are inside #if !SWIFT_PACKAGE or the #else of #if SWIFT_PACKAGE")
    func compilerRule() {
        let suite = """
            #if SWIFT_PACKAGE
            @testable import FRUSCoreKit
            #else
            @testable import FRUSExplorer
            #endif
            let kit = FRUSURLScheme.self
            #if !SWIFT_PACKAGE // the app's
            let app = IndexingPipeline.self
            #else
            let packageOnly = 1
            #endif
            """
        let lines = Self.linesByCompiler(suite)
        #expect(lines.count == 11)
        let both = lines.enumerated().filter { !$0.element.xcodeOnly }.map { $0.offset + 1 }
        // The kit's import, the line both compile and the package's own branch; never the app's.
        #expect(both == [2, 6, 10])
    }

    // MARK: Who compiles the kit

    @Test("Both app targets compile FRUSCoreKit/, and the package builds it and its suites as targets of their own")
    func theKitIsCompiledByBothTargetsAndThePackage() throws {
        let project = try String(contentsOf: Self.repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)
        let sourcePaths = project.components(separatedBy: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces) == "- path: FRUSCoreKit"
        }
        #expect(sourcePaths.count == 2, "project.yml names FRUSCoreKit as a source path \(sourcePaths.count) time(s), not once per app target")
        let manifest = try String(contentsOf: Self.repoRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
        let paths = CodingStandardsAuditTests.packageTargetPaths(in: manifest)
        #expect(paths.contains("FRUSCoreKit"), "Package.swift declares no target at FRUSCoreKit")
        #expect(paths.contains("FRUSExplorerTests/FRUSCoreKit"), "Package.swift declares no test target at FRUSExplorerTests/FRUSCoreKit")
    }
}
