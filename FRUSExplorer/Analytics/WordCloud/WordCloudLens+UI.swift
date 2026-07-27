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

import SwiftUI

/// The user-facing half of `WordCloudLens`.
///
/// The lens itself is pure data in `WordCloudKit` so the offline generator can classify
/// tokens through the same type. Localised labels and SF Symbols cannot go there — the
/// generator has no bundle and no String Catalog — so they live here.
///
/// Version history:
///   1.0 — O-1: split out when `WordCloudLens` moved to `WordCloudKit`
extension WordCloudLens {

    /// Localised menu label.
    var label: String {
        switch self {
        case .allTerms:      return String(localized: "wordcloud.lens.all", defaultValue: "All terms")
        case .people:        return String(localized: "wordcloud.lens.people", defaultValue: "People")
        case .places:        return String(localized: "wordcloud.lens.places", defaultValue: "Places")
        case .organizations: return String(localized: "wordcloud.lens.orgs", defaultValue: "Organizations")
        case .topics:        return String(localized: "wordcloud.lens.topics", defaultValue: "Topics (nouns)")
        case .actions:       return String(localized: "wordcloud.lens.actions", defaultValue: "Actions (verbs)")
        case .descriptors:   return String(localized: "wordcloud.lens.descriptors", defaultValue: "Descriptors (adjectives)")
        case .concepts:      return String(localized: "wordcloud.lens.concepts", defaultValue: "Concepts")
        case .sentiment:     return String(localized: "wordcloud.lens.sentiment", defaultValue: "Sentiment")
        }
    }

    /// The bare lens name, for the onboarding backdrop's chip.
    ///
    /// Distinct from ``label``, which is the Analytics *menu* label and carries a
    /// disambiguating parenthetical — "Topics (nouns)", "Actions (verbs)". That reads as
    /// documentation in a menu and as noise on a decorative chip, where the hand-off
    /// specifies just the lens name.
    var shortLabel: String {
        switch self {
        case .allTerms:      return String(localized: "wordcloud.lens.short.all", defaultValue: "All terms")
        case .people:        return String(localized: "wordcloud.lens.short.people", defaultValue: "People")
        case .places:        return String(localized: "wordcloud.lens.short.places", defaultValue: "Places")
        case .organizations: return String(localized: "wordcloud.lens.short.orgs", defaultValue: "Organizations")
        case .topics:        return String(localized: "wordcloud.lens.short.topics", defaultValue: "Topics")
        case .actions:       return String(localized: "wordcloud.lens.short.actions", defaultValue: "Actions")
        case .descriptors:   return String(localized: "wordcloud.lens.short.descriptors", defaultValue: "Descriptors")
        case .concepts:      return String(localized: "wordcloud.lens.short.concepts", defaultValue: "Concepts")
        case .sentiment:     return String(localized: "wordcloud.lens.short.sentiment", defaultValue: "Sentiment")
        }
    }

    /// SF Symbol for the lens menu.
    var systemImage: String {
        switch self {
        case .allTerms:      return "text.word.spacing"
        case .people:        return "person.2"
        case .places:        return "mappin.and.ellipse"
        case .organizations: return "building.2"
        case .topics:        return "tag"
        case .actions:       return "bolt"
        case .descriptors:   return "paintpalette"
        case .concepts:      return "lightbulb"
        case .sentiment:     return "face.smiling"
        }
    }
}
