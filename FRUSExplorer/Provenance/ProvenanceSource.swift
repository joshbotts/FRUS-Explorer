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

/// How far a displayed value sits from the FRUS volumes, and what it was joined to.
///
/// **This is a citation feature, not a visual one.** The question a reader is asking is not what
/// colour a chip is but *may I write "FRUS shows X", or must I write something weaker* — so the
/// tier answers how far from FRUS, and ``ProvenanceSource`` names the partner, because that is the
/// first half of the sentence they are about to write. See
/// `Planning/Provenance-Tiers-Development-Plan.md` (wave PV).
///
/// Version history:
///   1.0 — PV-0: initial implementation
enum ProvenanceTier: Int, Comparable, CaseIterable, Sendable {

    /// Derived from the FRUS volumes and nothing else.
    ///
    /// **Licenses "this came from FRUS and nowhere else". It never licenses "this is what FRUS
    /// says"** — a machine did the reading, and every Tier-1 sentence about a parse names the app
    /// as the reader.
    case frusOnly = 1

    /// Produced by joining the FRUS volumes to another body of data.
    case joined = 2

    /// Produced by this app rather than read from a source — a model or a scoring rule stands
    /// between the volumes and the value.
    case computed = 3

    static func < (a: ProvenanceTier, b: ProvenanceTier) -> Bool { a.rawValue < b.rawValue }
}

/// The eight things a value's provenance can be, and the words for each.
///
/// **Eight labels rather than three tiers, by owner decision.** "Tier 2" forces a reader to look
/// something up; "FRUS + NARA catalog" *is* the answer to what they must cite. The cost is a
/// vocabulary to learn, and it is paid once.
///
/// **Three collapses are deliberate.** POCOM folds into the people register, `volume-tag-taxonomy`
/// folds into subjects, and the owner's curated archival resolutions fold into the NARA catalogue
/// — the last is *disclosed by name* where it applies rather than taking a ninth label, which is
/// the Q-3 decision.
///
/// Version history:
///   1.0 — PV-0: initial implementation
enum ProvenanceSource: String, CaseIterable, Sendable {

    /// The volumes themselves: their text, their apparatus, and anything read from them alone.
    case frusText

    /// NARA's catalogue — central files, series facts, presidential libraries, digitised ranges.
    case naraCatalog

    /// The Office of the Historian's CC0 people register, and POCOM's career records with it.
    case ohPeopleRegister

    /// The Office of the Historian's subject taxonomy and the document-level subject drop.
    case ohSubjects

    /// The State Department's own decimal classification schedule, as published in NARA's manuals.
    case stateDeptSchedule

    /// This app's word lists — the lexicons and stopwords behind the clouds and keyness.
    case appWordLists

    /// This app's neural model — semantic vectors, the map, and on-device summaries.
    case appModel

    /// The reader's own work. **Deliberately outside the provenance family**: nobody mis-cites
    /// their own highlight as FRUS, and the storage layer already separates it (`user_content` is
    /// a different FTS5 table from the corpus index, so the corpus stays immutable outside volume
    /// indexing). It appears only where the reader's own act becomes a denominator.
    case yourReading

    /// How far from the volumes this source sits.
    var tier: ProvenanceTier {
        switch self {
        case .frusText:                                   return .frusOnly
        case .naraCatalog, .ohPeopleRegister,
             .ohSubjects, .stateDeptSchedule:             return .joined
        case .appWordLists, .appModel:                    return .computed
        // Not a provenance claim at all — see the case's own note.
        case .yourReading:                                return .computed
        }
    }

    /// What a chip says. Short, because it sits inline beside a value.
    var label: String {
        switch self {
        case .frusText:
            return String(localized: "provenance.source.frusText", defaultValue: "FRUS text")
        case .naraCatalog:
            return String(localized: "provenance.source.nara", defaultValue: "FRUS + NARA catalog")
        case .ohPeopleRegister:
            return String(localized: "provenance.source.ohPeople",
                          defaultValue: "FRUS + OH people register")
        case .ohSubjects:
            return String(localized: "provenance.source.ohSubjects",
                          defaultValue: "FRUS + OH subjects")
        case .stateDeptSchedule:
            return String(localized: "provenance.source.stateSchedule",
                          defaultValue: "FRUS + State Dept. schedule")
        case .appWordLists:
            return String(localized: "provenance.source.wordLists",
                          defaultValue: "FRUS + this app's word lists")
        case .appModel:
            return String(localized: "provenance.source.model", defaultValue: "This app's model")
        case .yourReading:
            return String(localized: "provenance.source.yourReading", defaultValue: "Your reading")
        }
    }

    /// The sentence an export carries — what a reader may and may not claim from this value.
    ///
    /// **These reach a footnote, which is the whole point of the wave**, so they say what the
    /// label cannot: that the app did the reading, that an unmatched record is absent rather than
    /// wrong, and that a computed figure is the app's output rather than the record's.
    var methodSentence: String {
        switch self {
        case .frusText:
            return String(localized: "provenance.method.frusText",
                          defaultValue: "Read from the text and editorial apparatus of the FRUS volumes, and from no other source. Where a value was parsed out of printed prose, this app did the reading.")
        case .naraCatalog, .ohPeopleRegister, .ohSubjects, .stateDeptSchedule:
            return String(format: String(localized: "provenance.method.joined %@",
                                         defaultValue: "Produced by joining the FRUS volumes to %@. The join is this app's; a record it could not match is absent rather than wrong."),
                          partnerName)
        case .appWordLists, .appModel:
            return String(localized: "provenance.method.computed",
                          defaultValue: "Computed by this app rather than read from a source — a model or a scoring rule stands between the volumes and this figure. Cite it as the app's output, not the record's.")
        case .yourReading:
            return String(localized: "provenance.method.yourReading",
                          defaultValue: "Your own notes, tags and highlights. The app never mixes them into the published text.")
        }
    }

    /// The partner named inside a joined method sentence.
    var partnerName: String {
        switch self {
        case .naraCatalog:
            return String(localized: "provenance.partner.nara",
                          defaultValue: "the National Archives catalog")
        case .ohPeopleRegister:
            return String(localized: "provenance.partner.ohPeople",
                          defaultValue: "the Office of the Historian's people register")
        case .ohSubjects:
            return String(localized: "provenance.partner.ohSubjects",
                          defaultValue: "the Office of the Historian's subject taxonomy")
        case .stateDeptSchedule:
            return String(localized: "provenance.partner.stateSchedule",
                          defaultValue: "the State Department's decimal classification schedule")
        default:
            return label
        }
    }

    /// The extra sentence a value owes when the owner's own archival judgement stands behind it.
    ///
    /// **Q-3: curated resolutions are disclosed by name.** Twenty lot files and 185 finding-aid
    /// entries resolve on the owner's judgement rather than on anything NARA published, and
    /// `curated-lot-resolutions.json` says so about itself while nothing on screen does. They fold
    /// into ``naraCatalog`` for the label — an eight-word vocabulary should not grow a ninth entry
    /// for twenty rows — and surface here instead.
    static let curatedDisclosure = String(
        localized: "provenance.curated.disclosure",
        defaultValue: "Some archival identifiers in this material were matched by hand rather than found in the catalog, because NARA publishes no control number for them.")
}
