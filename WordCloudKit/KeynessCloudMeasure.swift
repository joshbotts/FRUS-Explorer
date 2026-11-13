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

// MARK: - KeynessCloudMeasure

/// Which question the word cloud is answering.
///
/// Persisted rather than held as view state: the macOS host applies `.id(scope.signature)` to
/// `WordCloudView`, which destroys every `@State` when the window is retargeted. A `@State` measure
/// would silently revert to frequency on the Mac while surviving the same action on iOS.
///
/// The raw values are what the app stores under `frus.wordcloud.measure`. The control's label,
/// `pickerLabel`, is the app's (`KeynessCloud.swift`), as ``WordCloudLens``'s labels are: the words
/// are localised there, and this kit reads no bundle.
///
/// Version history:
///   1.0 — S-1: initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24d): moved out of the app's `KeynessCloud.swift` into
///          `WordCloudKit`, public; its label stays the app's
public enum KeynessCloudMeasure: String, CaseIterable, Sendable {
    /// Words sized by how often they occur in the scope. The historical behaviour.
    case frequency
    /// Words sized by how much more often they occur here than across the corpus.
    case keyness
}
