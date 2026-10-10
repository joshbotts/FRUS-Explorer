// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

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
/// rule a kit file could break, and read both trees now: the word-cloud precompute removal scan
/// (a banned name), the Corpus Analytics unit-noun scan (a string, in the two `Analytics/`
/// folders), the citation-engine construction scan (the kit's own initialiser) and the SF Symbol
/// literal scan (a string). Of the other thirty, four already read the kit by a list of their
/// own, six list data folders or the tests themselves, and twenty hold a rule about the app's
/// views, scenes, windows, charts, tips or SwiftData models, or about `AppState` or another type
/// the app declares, none of which a kit file can name.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: initial implementation
///   1.1 — #1604: the survey above; no change to what this type reads
enum AppSourceTree {

    /// The directories, relative to the repository root.
    static let directories = ["FRUSExplorer", "FRUSCoreKit"]

    /// Every `.swift` file under the two directories, at any depth, sorted by path.
    ///
    /// - Parameter repoRoot: The repository root.
    /// - Returns: The files.
    static func swiftFiles(in repoRoot: URL) -> [URL] {
        directories.flatMap { directory -> [URL] in
            let walker = FileManager.default.enumerator(at: repoRoot.appendingPathComponent(directory),
                                                        includingPropertiesForKeys: nil)
            return (walker?.compactMap { $0 as? URL } ?? []).filter { $0.pathExtension == "swift" }
        }
        .sorted { $0.path < $1.path }
    }
}
