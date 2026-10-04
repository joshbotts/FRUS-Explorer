// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - Linux logging shim
//
// FTS5Store logs through `os.Logger`, and OSLog exists only on Apple platforms. Where it cannot
// be imported (Linux), this file declares a `Logger` with the same call shape, `privacy:`
// interpolation included, so `FTS5Store.swift` compiles there unchanged. On Apple platforms the
// whole file is compiled out, and `Logger` is the system's.
#if !canImport(OSLog)
import Foundation

/// Stand-in for `OSLogPrivacy`. It is accepted so `\(value, privacy: .public)` compiles, and
/// ignored: standard error has no redaction, so every value prints.
///
/// Version history:
///   1.0 — Session 2026-10-04: initial implementation
enum OSLogPrivacy: Sendable {
    /// The value may appear in logs. FTS5Store marks every value it logs this way.
    case `public`
    /// The value is private to `os.Logger`. Printed here all the same.
    case `private`
    /// `os.Logger`'s default privacy. Printed here all the same.
    case auto
}

/// Stand-in for `OSLogMessage`: a string literal or interpolation, flattened to text.
///
/// Version history:
///   1.0 — Session 2026-10-04: initial implementation
struct OSLogMessage: ExpressibleByStringInterpolation, Sendable {

    /// Builds a message's text from its literal segments and interpolated values.
    struct StringInterpolation: StringInterpolationProtocol {
        /// The text built so far.
        var text = ""

        /// Starts an empty message. The size hints are not used.
        init(literalCapacity: Int, interpolationCount: Int) {}

        /// Appends a literal segment unchanged.
        mutating func appendLiteral(_ literal: String) { text += literal }

        /// Appends a value as `"\(value)"` would, ignoring `privacy`.
        mutating func appendInterpolation<T>(_ value: T, privacy: OSLogPrivacy = .auto) { text += "\(value)" }
    }

    /// The message as it prints.
    let text: String

    /// A message with no interpolation.
    init(stringLiteral value: String) { text = value }

    /// A message built from an interpolation.
    init(stringInterpolation: StringInterpolation) { text = stringInterpolation.text }
}

/// Stand-in for `os.Logger`: each call writes one line, `[level] category: message`, to
/// standard error.
///
/// Version history:
///   1.0 — Session 2026-10-04: initial implementation
struct Logger: Sendable {
    /// The subsystem, kept for parity with `os.Logger`. It is not printed.
    let subsystem: String
    /// The category, printed before each message.
    let category: String

    /// Creates a logger, as `os.Logger(subsystem:category:)` does.
    init(subsystem: String, category: String) { self.subsystem = subsystem; self.category = category }

    private func emit(_ level: String, _ m: OSLogMessage) {
        FileHandle.standardError.write(Data("[\(level)] \(category): \(m.text)\n".utf8))
    }

    /// Writes a message at the debug level.
    func debug(_ m: OSLogMessage) { emit("debug", m) }
    /// Writes a message at the info level.
    func info(_ m: OSLogMessage) { emit("info", m) }
    /// Writes a message at the notice level.
    func notice(_ m: OSLogMessage) { emit("notice", m) }
    /// Writes a message at the warning level.
    func warning(_ m: OSLogMessage) { emit("warning", m) }
    /// Writes a message at the error level.
    func error(_ m: OSLogMessage) { emit("error", m) }
}
#endif
