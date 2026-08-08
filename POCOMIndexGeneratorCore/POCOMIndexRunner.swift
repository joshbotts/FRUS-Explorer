// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - POCOMIndexRunner

/// Orchestrates a POCOM career-index build (#736).
///
/// ## Run this **after** the authority index, not before
/// The slug set that decides what is worth bundling lives in `person-authority-index.json`, and
/// only schema v2 carries it. So the order is: regenerate the authority index (which mints the
/// slugs), then run this against it. Without `AUTHORITY_INDEX` the whole register is emitted,
/// which is a useful survey and a wasteful bundle.
///
/// Environment variables:
/// - `POCOM_DIR` (required): a `HistoryAtState/pocom` checkout.
/// - `AUTHORITY_INDEX` (optional): `person-authority-index.json`; restricts output to slugs the
///   app can actually reach, and reports the reach.
/// - `OUTPUT_PATH` (optional): default `FRUSExplorer/Resources/pocom-index.json`.
/// - `GENERATED_DATE` (optional): pins the `generated` stamp for a reproducible build.
public enum POCOMIndexRunner {

    /// Current schema version of the generated index.
    public static let indexVersion = 1

    public static func run(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let dirPath = environment["POCOM_DIR"], !dirPath.isEmpty else {
            FileHandle.standardError.write(Data("""
                error: set POCOM_DIR to a HistoryAtState/pocom checkout.
                e.g. POCOM_DIR=/path/to/pocom swift run POCOMIndexGenerator

                """.utf8))
            exit(2)
        }
        let checkout = URL(fileURLWithPath: dirPath, isDirectory: true)
        let outputURL = URL(fileURLWithPath:
            environment["OUTPUT_PATH"] ?? "FRUSExplorer/Resources/pocom-index.json")
        let generated = environment["GENERATED_DATE"] ?? isoDate()

        // The slugs the app can reach, from the authority index's v2 `s` field.
        var keepSlug: Set<String>?
        var authoritySlugCount = 0
        if let path = environment["AUTHORITY_INDEX"], !path.isEmpty {
            let slugs = (try? loadAuthoritySlugs(URL(fileURLWithPath: path))) ?? []
            authoritySlugCount = slugs.count
            if slugs.isEmpty {
                print("""
                    warning: \(path) carries no POCOM slugs. Either it is still schema v1, or the \
                    authority build has not been re-run. Emitting the whole register.
                    """)
            } else {
                keepSlug = slugs
                print("Restricting to \(slugs.count) slugs reachable from the authority index.")
            }
        }

        let head = gitHead(checkout) ?? "unknown"
        let source = "HistoryAtState/pocom (CC0 / public domain), checkout \(head)"

        do {
            print("Building POCOM career index from \(checkout.path) …")
            let (index, stats) = try POCOMIndexBuilder.build(
                checkout: checkout, version: indexVersion, generated: generated,
                source: source, keepSlug: keepSlug)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(index)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: outputURL)

            print("""

                Wrote \(outputURL.path)  \
                (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))
                  person files read:        \(stats.personFiles)
                  country-mission chiefs:   \(stats.countryChiefs)
                  organization chiefs:      \(stats.orgChiefs)
                  principal positions:      \(stats.principals)
                  careers emitted:          \(stats.careersEmitted)
                  assignments emitted:      \(stats.assignmentsEmitted)
                """)
            if stats.appointmentsWithNoPerson > 0 {
                print("  appointments naming a person the register has no file for: "
                    + "\(stats.appointmentsWithNoPerson)")
            }
            if !stats.unknownRoleIds.isEmpty {
                // Reported rather than swallowed: an unresolved role id is a title the code tables
                // do not carry, and the label falls back to a humanised slug.
                print("  role ids absent from the role tables (\(stats.unknownRoleIds.count)): "
                    + stats.unknownRoleIds.sorted().prefix(8).joined(separator: ", "))
            }
            if authoritySlugCount > 0 {
                print("  reach: \(stats.careersEmitted) of \(authoritySlugCount) "
                    + "app-reachable slugs have at least one appointment")
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    // MARK: - Helpers

    /// Every POCOM slug named by an authority index's entries. Empty for a v1 file, which is the
    /// signal the caller warns about rather than treating as "no one is reachable".
    static func loadAuthoritySlugs(_ url: URL) throws -> Set<String> {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let authority = json["authority"] as? [String: Any] else { return [] }
        var slugs = Set<String>()
        for value in authority.values {
            if let entry = value as? [String: Any], let slug = entry["s"] as? String, !slug.isEmpty {
                slugs.insert(slug)
            }
        }
        return slugs
    }

    /// The checkout's HEAD, for provenance. `nil` when the directory is not a git checkout — the
    /// build still runs and records "unknown" rather than refusing.
    static func gitHead(_ checkout: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", checkout.path, "rev-parse", "--short", "HEAD"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let head = String(decoding: out, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return head.isEmpty ? nil : head
    }

    static func isoDate() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }
}
