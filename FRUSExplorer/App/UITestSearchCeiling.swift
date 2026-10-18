// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if DEBUG
import Foundation

// MARK: - UITestSearchCeiling

/// A keyword ceiling a UI test can lower (#1577 lane 6), so that a fixture of six documents can be a list cut at its
/// ceiling.
///
/// ## Why
/// A question ranks a held list's whole match only when the list was cut at its ceiling, which on iPhone and iPad is
/// 1,000 rows for a search with text in it (`SearchViewModel.searchHardLimit`). No fixture a UI test seeds holds more
/// than thirty documents that one search matches, so no UI test reached that ranking or the header it gives the list.
/// A launch that sets ``environmentKey`` to a number, beside `FRUS_UI_TEST_MODE`, fetches such a search at that many
/// rows instead (`SearchViewModel.keywordFetchCeiling`). Nothing else is replaced: the count, the whole match, the
/// ranking and the rows fetched again are the app's own, so the list is cut as a list of 1,000 rows of 35,275 is.
///
/// ## Contract
/// `#if DEBUG`, and inert unless `FRUS_UI_TEST_MODE` is `1` and the value is a whole number above zero. A browse with
/// no words keeps its own ceiling of 7,500.
///
/// Version history:
///   1.0 — #1577 lane 6: initial implementation
enum UITestSearchCeiling {

    /// The launch-environment key a UI test sets to the ceiling it wants, such as `4`.
    static let environmentKey = "FRUS_UI_TEST_SEARCH_CEILING"

    /// The ceiling this launch's UI test asks for, or `nil` when it asks for none.
    static var requested: Int? { requested(in: ProcessInfo.processInfo.environment) }

    /// ``requested`` with the environment lifted out, so a test can drive every arm.
    ///
    /// - Parameter environment: A process environment.
    /// - Returns: The ceiling, or `nil` outside a UI test, with no value, or with one that is not a whole number above zero.
    static func requested(in environment: [String: String]) -> Int? {
        guard environment["FRUS_UI_TEST_MODE"] == "1",
              let value = environment[environmentKey].flatMap({ Int($0) }), value > 0 else { return nil }
        return value
    }
}
#endif
