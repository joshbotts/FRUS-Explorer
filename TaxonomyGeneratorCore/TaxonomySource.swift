// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - TaxonomySource

/// Where a run reads the tag taxonomy from (#1622).
///
/// The tool had one source, the page, and a parse that turns on the page's markup. The site is
/// being rebuilt, and since #1600 a page with other markup stops the run where it used to empty
/// the bundled file. The second source is the file the page is drawn from, which the Office of
/// the Historian keeps in a public repository and releases into the public domain.
///
/// ## The order
/// A run that names no source reads ``automaticOrder``: the repository's file, and the page when
/// the file gives nothing to write. The file is first because it is the data and not a drawing
/// of it, and because `manifest.json`, whose volumes carry these tags by slug, is read from the
/// Office's repositories too. On 2026-10-11 the two sources wrote the same bytes.
///
/// Version history:
///   1.0 — #1622: initial implementation
public enum TaxonomySource: String, Sendable, Equatable, CaseIterable {

    /// `taxonomy/taxonomy.xml` in the public HistoryAtState/tags repository, at the head of its
    /// default branch.
    case repository

    /// The page `history.state.gov/tags/all`.
    case page

    /// The sources a run tries when none is named, in order.
    public static let automaticOrder: [TaxonomySource] = [.repository, .page]

    /// The sources a run tries for `TAXONOMY_SOURCE`'s value: ``automaticOrder`` for no value or
    /// an empty one, the one source for `repository` or `page`, and `nil` for anything else, which
    /// the run refuses: a misspelt source must not be read as "either".
    ///
    /// - Parameter value: The environment variable's value, if it is set.
    /// - Returns: The sources to try, or `nil` when `value` names none.
    public static func order(named value: String?) -> [TaxonomySource]? {
        guard let value, !value.isEmpty else { return automaticOrder }
        return TaxonomySource(rawValue: value).map { [$0] }
    }

    /// The address a run fetches.
    public var url: String {
        switch self {
        case .repository:
            return "https://raw.githubusercontent.com/HistoryAtState/tags/HEAD/taxonomy/taxonomy.xml"
        case .page:
            return "https://history.state.gov/tags/all"
        }
    }

    /// How a run's output names the source, mid-sentence.
    public var name: String {
        switch self {
        case .repository: return "the repository's file"
        case .page: return "the page"
        }
    }
}
