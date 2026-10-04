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
/// Version history:
///   1.0 — FRUSCoreKit, part 1: initial implementation
struct LinuxLocalizationValue: ExpressibleByStringInterpolation, Sendable {

    /// Builds the text from its literal segments and interpolated values.
    struct StringInterpolation: StringInterpolationProtocol {
        /// The text built so far.
        var text = ""

        /// Starts an empty interpolation.
        init(literalCapacity: Int, interpolationCount: Int) {}

        /// Appends a literal segment.
        mutating func appendLiteral(_ literal: String) { text += literal }

        /// Appends a value as `String(describing:)` writes it.
        mutating func appendInterpolation<T>(_ value: T) { text += "\(value)" }

        /// Appends a value through a format style, as `\(value, format: style)` does in Foundation.
        mutating func appendInterpolation<F: FormatStyle>(_ value: F.FormatInput, format: F)
        where F.FormatOutput == String {
            text += format.format(value)
        }
    }

    /// The flattened text.
    let text: String

    /// A plain literal.
    init(stringLiteral value: String) { text = value }

    /// An interpolated literal.
    init(stringInterpolation: StringInterpolation) { text = stringInterpolation.text }
}

extension String {
    /// Stand-in for `String(localized:table:bundle:locale:comment:)`: the literal itself.
    init(localized value: LinuxLocalizationValue, table: String? = nil, bundle: Bundle? = nil,
         locale: Locale = .current, comment: StaticString? = nil) {
        self = value.text
    }

    /// Stand-in for `String(localized:defaultValue:table:bundle:locale:comment:)`: the default value.
    init(localized key: StaticString, defaultValue: LinuxLocalizationValue, table: String? = nil,
         bundle: Bundle? = nil, locale: Locale = .current, comment: StaticString? = nil) {
        self = defaultValue.text
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
