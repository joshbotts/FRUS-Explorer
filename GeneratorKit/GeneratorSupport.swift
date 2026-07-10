// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - GeneratorError

/// Fatal conditions shared across the corpus-scanning generators, surfaced with a readable
/// message when a tool exits non-zero.
public enum GeneratorError: Error, CustomStringConvertible {
    /// No `*.xml` volumes were found in the corpus directory.
    case noVolumes(String)
    /// A required input file could not be read.
    case missingFile(String)

    public var description: String {
        switch self {
        case .noVolumes(let dir): return "No .xml volumes found in \(dir)"
        case .missingFile(let path): return "Required file not found: \(path)"
        }
    }
}

// MARK: - Logging

/// Writes a progress line to standard error, keeping standard output free for machine-readable
/// generator output. Matches the `FileHandle.standardError` logging every generator uses.
///
/// - Parameter message: The line to log (a trailing newline is appended).
public func generatorLog(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

// MARK: - Date stamp

/// The `generated` date stamp for a bundled artifact: `yyyy-MM-dd` in `en_US_POSIX`/UTC so the
/// value is locale- and timezone-independent (and therefore reproducible in CI).
///
/// - Parameter override: A `GENERATED_DATE` override for reproducible builds; when non-nil it is
///   returned verbatim.
/// - Returns: The date stamp.
public func generatorDateStamp(override: String? = nil) -> String {
    if let override, !override.isEmpty { return override }
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    return f.string(from: Date())
}
