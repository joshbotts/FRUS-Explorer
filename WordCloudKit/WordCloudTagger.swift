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
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - WordCloudTagger

/// What the word cloud's two tokenizers read of a tagger, so that a host can give them one of its own
/// (FRUS Explorer Light, S29a).
///
/// ## What the tokenizers read
/// `WordCloudTokenizer` and `WordCloudMultiLensTokenizer` read two walks of a text and nothing else:
/// - **the words** (``enumerateWords(in:reading:using:)``): every word of the text in its order, without
///   punctuation, whitespace or other tokens, each with its range in the text and, when the walk asks,
///   its lemma and its lexical class. A word lens counts from this walk.
/// - **the names** (``enumerateNames(in:using:)``): the same text's words with a name of several words
///   given whole ("United States"), each with its name type. The People, Places and Organizations lenses
///   count from this walk.
///
/// Everything else is the tokenizers' own, whatever the tagger: the lemma preferred, the word lowercased
/// and plural-folded where there is none, the lexicons, the markings, the length and stopword tests, and
/// each lens's filter. So two taggers that give the same words, lemmas, classes and names count the same
/// clouds, and a host's tagger counts by the kit's rules, not a copy of them.
///
/// ## What comes with a tagger
/// ``health``: the three flags the kit already reads a lens's support and a count's word form from
/// (`NaturalLanguageHealth.supports(_:)`, `NaturalLanguageHealth.wordForm`), for a host's tagger as for the
/// app's. A host reads it once per count and gives its form to the tokenizer it counts with and to the
/// reference it compares with, as the app does with the readiness gate's verdict. And ``identity``: the
/// tokenizer the counts are made by, which the clouds and the keyness references record, and by which a
/// reference counted by another refuses a scope (`KeynessBaselineFile.Configuration.mismatches`).
///
/// ## NaturalLanguage's
/// On Apple platforms the readiness gate's taggers are one: `NLTagger` conforms, walking itself, and
/// ``NaturalLanguageWordCloudTagger`` asks the gate for a new `NLTagger` for each walk, with the schemes the
/// walk reads, as the tokenizers always have. Each tokenizer's `accumulate` without a tagger counts with
/// it, so the app counts as it did; `WordCloudMultiLensParityTests` and `WordCloudPrintedFormParityTests`
/// hold that. Where NaturalLanguage is missing (Linux) a host gives a tagger of its own, and nothing counts
/// without one.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
public protocol WordCloudTagger {

    /// The tokenizer the counts made with this tagger are counted by: the name the clouds and the
    /// keyness references record, and the one a reference compares with a scope's.
    var identity: WordCloudTokenizerIdentity { get }

    /// What this tagger can do: whether it gives lemmas, lexical classes and names. A host reads it once
    /// per count, as the app reads the readiness gate's verdict, and takes the count's word form from it.
    var health: NaturalLanguageHealth { get }

    /// Calls `body` with each word of `text`, in order, without punctuation, whitespace or other tokens.
    ///
    /// The text is English, as the corpus is. `body` is given the word's range in `text`; its lemma when
    /// `reading` holds ``WordCloudTagReading/lemmas`` and the tagger has one, and `nil` or an empty string
    /// where it has none; and a function that answers the word's lexical class, which the walk calls only
    /// for a word whose class it reads, at most once, and only while `body` runs. A walk whose `reading`
    /// holds ``WordCloudTagReading/lexicalClasses`` may read classes; one that does not reads none.
    /// `body` returns `false` to stop the walk.
    ///
    /// - Parameters:
    ///   - text: The text to walk.
    ///   - reading: What the walk reads of each word besides its range.
    ///   - body: Called with each word's range, its lemma and its lexical class's reader.
    func enumerateWords(in text: String, reading: WordCloudTagReading,
                        using body: (_ range: Range<String.Index>, _ lemma: String?,
                                     _ lexicalClass: () -> WordCloudLexicalClass?) -> Bool)

    /// Calls `body` with each word of `text`, in order, a name of several words given as one, without
    /// punctuation, whitespace or other tokens, with its name type, or `nil` for a word that is no name.
    ///
    /// - Parameters:
    ///   - text: The text to walk.
    ///   - body: Called with each word's or name's range and its name type; returns `false` to stop.
    func enumerateNames(in text: String,
                        using body: (_ range: Range<String.Index>, _ nameType: WordCloudNameType?) -> Bool)
}

// MARK: - What a walk reads

/// What a word walk reads of each word besides its range (S29a).
///
/// A tokenizer asks for no more than it reads: lemmas only when it counts in dictionary forms, so a count
/// of printed forms asks for none (#1608); lexical classes only when a part-of-speech lens is counted, so
/// a walk of the other lenses asks for what a single-lens walk of them asks for (the multi-lens
/// tokenizer's "one asymmetry"). NaturalLanguage's tagger builds its `NLTagger` with exactly these.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
public struct WordCloudTagReading: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    /// Creates a reading from its raw value.
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Each word's lemma, its dictionary form ("negotiated" → "negotiate").
    public static let lemmas = WordCloudTagReading(rawValue: 1 << 0)

    /// Each word's lexical class, for the Topics, Actions and Descriptors lenses.
    public static let lexicalClasses = WordCloudTagReading(rawValue: 1 << 1)
}

/// A word's lexical class, as far as the word lenses read one (S29a): Topics keeps nouns, Actions verbs
/// and Descriptors adjectives.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
public enum WordCloudLexicalClass: Sendable, Hashable, CaseIterable {
    /// A noun, which Topics keeps.
    case noun
    /// A verb, which Actions keeps.
    case verb
    /// An adjective, which Descriptors keeps.
    case adjective
    /// Any other class a tagger gives: an adverb, a pronoun, a determiner, a number. No lens keeps it.
    case other
}

/// A name's type, as the entity lenses read one (S29a).
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
public enum WordCloudNameType: Sendable, Hashable, CaseIterable {
    /// A person's name, which People keeps.
    case person
    /// A place's name, which Places keeps.
    case place
    /// An organization's name, which Organizations keeps.
    case organization
}

// MARK: - WordCloudTokenizerIdentity

/// The tokenizer a count is made by: a name and a version (FRUS Explorer Light, S29a).
///
/// ## Why the files name it
/// A keyness score divides a scope's counts by a reference's, so the two must be one tokenization: a lemma
/// another tagger gives, a word it splits differently, a class it reads otherwise, and the division is
/// between two vocabularies, which no setting of the reader's can mend. The web edition's specification
/// states the rule: a reference counted by another tokenizer is never compared. The clouds
/// (`CloudVectorsFile.Provenance`) and the keyness references (`KeynessBaselineFile.Configuration`) record
/// the identity, and `KeynessBaselineFile.Configuration.mismatches` refuses a scope counted by another.
///
/// ## NaturalLanguage's
/// ``naturalLanguage`` is the app's, on every Apple platform and runtime. NaturalLanguage's lemmas and
/// classes differ a little from one operating system build to another, and the app has always compared a
/// count made on one with a reference made on another, so here they are one tokenizer. A file that names
/// no tokenizer, every file written before S29a and the bundled ones among them, was counted by it and
/// reads as it, so those files stand as they are.
///
/// ## A host's
/// A host's tagger names its own (``WordCloudTagger/identity``), and changes its version whenever its
/// counts would change: a new model, new word lists, a new rule.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
public struct WordCloudTokenizerIdentity: Codable, Sendable, Hashable, CustomStringConvertible {

    /// The tokenizer's name: `NaturalLanguage` for the app's.
    public let name: String

    /// Its version, which changes whenever the counts it makes would.
    public let version: String

    /// Creates an identity.
    /// - Parameters:
    ///   - name: The tokenizer's name.
    ///   - version: Its version.
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }

    /// NaturalLanguage's: the readiness gate's taggers walked by this kit's tokenizers, the app's on every
    /// Apple platform, and the tokenizer of every file that names none.
    public static let naturalLanguage = WordCloudTokenizerIdentity(name: "NaturalLanguage", version: "1")

    /// The name and the version, as a log line or a refusal states them.
    public var description: String { "\(name) \(version)" }
}

#if canImport(NaturalLanguage)

// MARK: - NaturalLanguage's taggers

/// The readiness gate's taggers walk as the tokenizers have always walked them (S29a).
///
/// Every `NLTagger` the app makes comes from `NaturalLanguageReadiness.tagger(tagSchemes:)`, after the
/// warm-up (`NaturalLanguageReadinessScanTests`), so each is NaturalLanguage's, and its health is the gate's
/// verdict. A walk sets the tagger's string and pins English, as the tokenizers did.
extension NLTagger: WordCloudTagger {

    /// NaturalLanguage's.
    public var identity: WordCloudTokenizerIdentity { .naturalLanguage }

    /// The readiness gate's verdict, which a tagger from the gate was built after. It waits for the verdict
    /// as `NaturalLanguageReadiness.health` does, which a tagger from the gate has already waited for.
    public var health: NaturalLanguageHealth { NaturalLanguageReadiness.health }

    /// Walks this tagger by word, as the tokenizers always have: by the scheme
    /// `NaturalLanguageReadiness.wordWalkScheme(of:)` gives, `.lemma` when this tagger has it and
    /// `.tokenType` when the gate left it out (#1539), with punctuation, whitespace and other tokens left
    /// out. A word's lemma is the walk's tag when the walk is by `.lemma` and `reading` asks for lemmas;
    /// its lexical class is this tagger's `.lexicalClass` tag at its first character.
    public func enumerateWords(in text: String, reading: WordCloudTagReading,
                               using body: (_ range: Range<String.Index>, _ lemma: String?,
                                            _ lexicalClass: () -> WordCloudLexicalClass?) -> Bool) {
        let walk = NaturalLanguageReadiness.wordWalkScheme(of: self)
        let readsLemmas = walk == .lemma && reading.contains(.lemmas)
        string = text
        // The FRUS corpus is English; pinning the language improves lemma quality and avoids per-call
        // language detection.
        setLanguage(.english, range: text.startIndex..<text.endIndex)
        enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: walk,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, tokenRange in
            body(tokenRange, readsLemmas ? tag?.rawValue : nil) {
                WordCloudLexicalClass(self.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lexicalClass).0)
            }
        }
    }

    /// Walks this tagger by name type, with `.joinNames`, so that a name of several words is one.
    public func enumerateNames(in text: String,
                               using body: (_ range: Range<String.Index>, _ nameType: WordCloudNameType?) -> Bool) {
        string = text
        setLanguage(.english, range: text.startIndex..<text.endIndex)
        enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]
        ) { tag, tokenRange in
            body(tokenRange, WordCloudNameType(tag))
        }
    }
}

/// NaturalLanguage's tagger, through the readiness gate (S29a): each walk asks
/// `NaturalLanguageReadiness.tagger(tagSchemes:)` for a tagger of its own, with the schemes it reads, and
/// walks it.
///
/// This is how the tokenizers have always tagged, a tagger for each text, and what their `accumulate`
/// without a tagger counts with. The app's cloud-vector generator passes it to its runner, which makes
/// three kinds of walk, each with its own schemes; one `NLTagger` holds the schemes it was built with.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
public struct NaturalLanguageWordCloudTagger: WordCloudTagger, Sendable {

    /// Creates NaturalLanguage's tagger. It holds nothing: the gate holds the warm-up and the verdict.
    public init() {}

    /// NaturalLanguage's.
    public var identity: WordCloudTokenizerIdentity { .naturalLanguage }

    /// The readiness gate's verdict, read now, waiting for it as `NaturalLanguageReadiness.health` does: so
    /// never on the main thread before the verdict has settled. A re-check can replace it, so read it per
    /// count, never keep it.
    public var health: NaturalLanguageHealth { NaturalLanguageReadiness.health }

    /// The schemes a word walk that reads `reading` asks the gate for: `.lemma` for one that reads lemmas,
    /// and `.tokenType` for one that does not, so a count of printed forms asks for no lemma scheme
    /// (#1608); with `.lexicalClass` only for one that reads classes, so a walk of the lexicon lenses asks
    /// for what a single-lens walk of them asks for. The tokenizers' `wordSchemes` and `schemes` are this.
    /// - Parameter reading: What the walk reads of each word.
    /// - Returns: The schemes, the walk's first.
    static func wordSchemes(for reading: WordCloudTagReading) -> [NLTagScheme] {
        let walk: NLTagScheme = reading.contains(.lemmas) ? .lemma : .tokenType
        return reading.contains(.lexicalClasses) ? [walk, .lexicalClass] : [walk]
    }

    /// The schemes a name walk asks the gate for.
    static let nameSchemes: [NLTagScheme] = [.nameType]

    /// Asks the gate for a tagger with the schemes `reading` needs, and walks it.
    public func enumerateWords(in text: String, reading: WordCloudTagReading,
                               using body: (_ range: Range<String.Index>, _ lemma: String?,
                                            _ lexicalClass: () -> WordCloudLexicalClass?) -> Bool) {
        // Through the readiness gate, never `NLTagger(tagSchemes:)` directly: a scheme whose first use in a
        // process fails stays failed for the rest of it (#1373), so the warm-up must come first even when a
        // tokenizer is the first thing to run.
        NaturalLanguageReadiness.tagger(tagSchemes: Self.wordSchemes(for: reading))
            .enumerateWords(in: text, reading: reading, using: body)
    }

    /// Asks the gate for a tagger with the name-type scheme, and walks it.
    public func enumerateNames(in text: String,
                               using body: (_ range: Range<String.Index>, _ nameType: WordCloudNameType?) -> Bool) {
        NaturalLanguageReadiness.tagger(tagSchemes: Self.nameSchemes).enumerateNames(in: text, using: body)
    }
}

extension WordCloudLexicalClass {
    /// The class NaturalLanguage's `.lexicalClass` tag names, or `nil` for no tag.
    init?(_ tag: NLTag?) {
        switch tag {
        case nil: return nil
        case .noun?: self = .noun
        case .verb?: self = .verb
        case .adjective?: self = .adjective
        default: self = .other
        }
    }
}

extension WordCloudNameType {
    /// The type NaturalLanguage's `.nameType` tag names, or `nil` for a word that is no name.
    init?(_ tag: NLTag?) {
        switch tag {
        case .personalName?: self = .person
        case .placeName?: self = .place
        case .organizationName?: self = .organization
        default: return nil
        }
    }
}

#else

// MARK: - Where NaturalLanguage is missing

/// Where `NaturalLanguage` is missing (Linux), the kit has no tagger of its own, and a host gives one
/// (S29a).
@available(*, unavailable, message: "NaturalLanguageWordCloudTagger tags with NaturalLanguage, which this platform does not have: give the tokenizers a WordCloudTagger of your own")
public struct NaturalLanguageWordCloudTagger {}
#endif
