// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - Linux Foundation shims
//
// Two things the kit's files call exist only in Apple's Foundation: `String(localized:)` and
// `autoreleasepool`. Where they are missing (Linux), this file declares stand-ins with the same call
// shape, so the files compile there unchanged. On Apple platforms each block is compiled out, and
// the calls reach the system's own: the app's strings still come from its bundle, and the parser
// still drains its pools.

#if !canImport(Darwin)
import Foundation

/// Stand-in for `String.LocalizationValue`: a literal or an interpolation, flattened to text. The
/// app ships English only, and every key the kit uses has its English text as the literal or as
/// `defaultValue`, so that text is what Linux prints.
///
/// An integer is held until the string is made and then written as Foundation writes the `%lld` it
/// stands for: through `String(format:locale:)` in the locale the string is made in, which groups it
/// ("1,204 documents" in English). Every other value is written as `String(describing:)` writes it.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: initial implementation
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): an integer is grouped for the locale, as
///          Apple's `String(localized:)` groups the `%lld` it stands for; it was printed bare, so a count
///          of a thousand or more read differently on Linux, in the method appendix among others
struct LinuxLocalizationValue: ExpressibleByStringInterpolation, Sendable {

    /// One part of the text: a literal segment or a value already written, or an integer that waits
    /// for the locale.
    enum Part: Sendable {
        /// Text as it is.
        case text(String)
        /// A signed integer, written as `%lld` for the locale when the string is made.
        case integer(Int64)
        /// An unsigned integer, written as `%llu` for the locale when the string is made.
        case unsigned(UInt64)
    }

    /// Builds the text from its literal segments and interpolated values.
    struct StringInterpolation: StringInterpolationProtocol {
        /// The parts so far.
        var parts: [Part] = []

        /// Starts an empty interpolation.
        init(literalCapacity: Int, interpolationCount: Int) {}

        /// Appends a literal segment.
        mutating func appendLiteral(_ literal: String) { parts.append(.text(literal)) }

        /// Appends a value as `String(describing:)` writes it.
        mutating func appendInterpolation<T>(_ value: T) { parts.append(.text("\(value)")) }

        /// Appends an integer, which Foundation formats as `%lld` (or `%llu`), in the locale the string
        /// is made in.
        mutating func appendInterpolation<T: BinaryInteger>(_ value: T) {
            if T.isSigned, let signed = Int64(exactly: value) {
                parts.append(.integer(signed))
            } else if let unsigned = UInt64(exactly: value) {
                parts.append(.unsigned(unsigned))
            } else {
                parts.append(.text("\(value)"))
            }
        }

        /// Appends a value through a format style, as `\(value, format: style)` does in Foundation.
        mutating func appendInterpolation<F: FormatStyle>(_ value: F.FormatInput, format: F)
        where F.FormatOutput == String {
            parts.append(.text(format.format(value)))
        }
    }

    /// The parts.
    let parts: [Part]

    /// A plain literal.
    init(stringLiteral value: String) { parts = [.text(value)] }

    /// An interpolated literal.
    init(stringInterpolation: StringInterpolation) { parts = stringInterpolation.parts }

    /// The text, its integers written for `locale`.
    ///
    /// - Parameter locale: The locale the string is made in.
    /// - Returns: The text.
    func text(in locale: Locale) -> String {
        parts.map { part in
            switch part {
            case .text(let text): text
            case .integer(let value): String(format: "%lld", locale: locale, value)
            case .unsigned(let value): String(format: "%llu", locale: locale, value)
            }
        }.joined()
    }
}

extension String {
    /// Stand-in for `String(localized:table:bundle:locale:comment:)`: the literal itself.
    init(localized value: LinuxLocalizationValue, table: String? = nil, bundle: Bundle? = nil,
         locale: Locale = .current, comment: StaticString? = nil) {
        self = value.text(in: locale)
    }

    /// Stand-in for `String(localized:defaultValue:table:bundle:locale:comment:)`: the default value.
    init(localized key: StaticString, defaultValue: LinuxLocalizationValue, table: String? = nil,
         bundle: Bundle? = nil, locale: Locale = .current, comment: StaticString? = nil) {
        self = defaultValue.text(in: locale)
    }
}
#endif

#if !canImport(ObjectiveC)
/// Stand-in for `autoreleasepool(invoking:)`. There is no Objective-C runtime, and so no pool to
/// drain: the body just runs.
@inline(__always)
func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
    try body()
}
#endif
