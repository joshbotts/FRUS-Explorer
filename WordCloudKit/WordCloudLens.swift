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

/// The semantic filter applied when text is reduced to word-cloud terms.
///
/// Pure data: no SwiftUI, no bundle access, so the app and the offline
/// `CloudVectorsGenerator` classify tokens through the same type rather than two
/// copies that can drift. The user-facing `label` and `systemImage` live in the app's
/// `WordCloudLens+UI` extension, which is where localisation belongs.
///
/// Version history:
///   1.0 — Word Cloud v2: sentiment & concept lenses
///   2.0 — O-1: moved into `WordCloudKit`; UI members split into the app extension
public enum WordCloudLens: String, CaseIterable, Sendable, Codable, Identifiable {
    /// All frequent content words (the original behaviour).
    case allTerms
    /// Named people.
    case people
    /// Named places.
    case places
    /// Named organizations.
    case organizations
    /// Common nouns — the subjects/topics of the text.
    case topics
    /// Verbs — the actions.
    case actions
    /// Adjectives — descriptive language.
    case descriptors
    /// Abstract IR/diplomacy concepts (sovereignty, legitimacy, deterrence…).
    case concepts
    /// Sentiment-bearing words, coloured by polarity.
    case sentiment

    public var id: String { rawValue }

    /// `true` for the named-entity lenses (people / places / organizations).
    ///
    /// These take a different path through the tokenizer — `NLTagger`'s `.nameType`
    /// scheme with `.joinNames` — and are **excluded from the bundled cloud vectors**
    /// pending curation, so `WordCloudMultiLensTokenizer` refuses them.
    public var isEntity: Bool {
        switch self {
        case .people, .places, .organizations: return true
        default: return false
        }
    }

    /// Lenses whose output depends on how much matching signal a scope contains —
    /// a tiny document may have few or no entities, concepts, or sentiment words, so
    /// the UI shows an "insufficient signal" state rather than a near-empty cloud.
    public var isSignalDependent: Bool {
        switch self {
        case .allTerms, .topics, .actions, .descriptors: return false
        case .people, .places, .organizations, .concepts, .sentiment: return true
        }
    }

    /// The minimum number of terms below which this lens is treated as having
    /// insufficient signal to display for a scope.
    public var minimumSignalTerms: Int { isSignalDependent ? 4 : 0 }

    /// `true` when the cloud should colour words by sentiment polarity instead of
    /// the rank palette.
    public var colorsBySentiment: Bool { self == .sentiment }

    /// The four lenses the bundled cloud vectors carry.
    ///
    /// Entity lenses are excluded by the design hand-off pending curation, and
    /// `.allTerms` / `.descriptors` are not part of the onboarding cloud's cycle.
    public static let bundledCloudLenses: [WordCloudLens] = [.concepts, .topics, .actions, .sentiment]
}
