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

/// The form a word lens counts a word in (#1608).
///
/// ## Why it is a value and not a property of the tagger
/// Until #1608 the form was whatever the tagger happened to return: a lemma where the lemmatiser
/// gave one, and otherwise the printed word. That is a true count, but the app could not compare
/// it with anything, because the bundled corpus reference was counted in dictionary forms. On the
/// owner's iPhone under iOS 27.0.1, on build 49 and in the foreground, iOS never answered the
/// request for the English lemma data, so Collocates refused, and the word cloud's Distinctive
/// sizing and Related Documents' shared-word chips were withheld.
///
/// The fallback compares printed forms with a second reference counted as printed. It is exact only
/// if a scope and that reference are counted the same way, so the form is decided once, from the
/// verdict a surface read (``NaturalLanguageHealth/wordForm``), and handed to the tokenizer and to
/// the reference lookup alike. A tokenizer told ``printed`` asks for no lemma scheme at all, so a
/// lemmatiser that starts answering part way through a count cannot mix the two forms in it.
///
/// ## What "printed" is
/// The word as the volume prints it, lowercased, and then exactly what the tokenizers have always
/// done with a word the lemmatiser has no entry for: when the tuning folds plurals,
/// `WordCloudTokenizer.singularize` reduces a regular plural by rule. So `missiles` joins `missile`
/// and `treaties` joins `treaty`, while `negotiate`, `negotiated` and `negotiating` are three words
/// and `men` is not `man`. The rule knows no names: `Dulles` is counted as `dulle`. It is the count
/// a launch with no lemmatiser has made since #1373, unchanged; #1608 adds a reference counted the
/// same way.
///
/// Version history:
///   1.0 — #1608: initial implementation
public enum WordCloudWordForm: String, Sendable, Codable, CaseIterable {
    /// The lemmatiser's dictionary form where it has one ("negotiations" and "negotiated" under
    /// "negotiation" and "negotiate"), and the printed form where it has none.
    case dictionary
    /// The printed form of every word: no lemma is read, whatever the tagger could give.
    case printed
}
