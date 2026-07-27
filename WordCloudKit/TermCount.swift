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


import Foundation

/// A term and its occurrence count within a scope (year, subseries, etc.).
///
/// Version history:
///   1.0 — Session 98: initial implementation
///   1.1 — S-5b: `Equatable`, so value types carrying term lists (`WordCloudBench`) can be too
///   2.0 — O-1: moved into `WordCloudKit`; the generator emits the same type
public struct TermCount: Sendable, Identifiable, Codable, Equatable {
    public let term: String
    public let count: Int
    public var id: String { term }

    /// Creates a term/count pair.
    public init(term: String, count: Int) {
        self.term = term
        self.count = count
    }
}
