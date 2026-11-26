---
paths:
  - "WordCloudKit/**"
  - "WordCloudKitTests/**"
  - "CloudVectorsGenerator*/**"
  - "FRUSExplorer/Analytics/WordCloud/**"
  - "FRUSCoreKit/Analytics/WordCloud/**"
---

# WordCloudKit, its taggers, and a launch with no lemmatiser

Claude Code loads this file when a session reads or edits a file its `paths` name. `CLAUDE.md`'s
`WordCloudKit` entry keeps the rules that bind every change; this is the whole entry, moved here
from `CLAUDE.md`'s *SPM package targets* word for word on 2026-11-26, and after it the paragraph on a
launch with no lemmatiser, moved the same day from *Build & Test Commands*.

- `WordCloudKit` — the word-cloud tokenizer stack (`WordCloudTokenizer`,
  `WordCloudMultiLensTokenizer`, `WordCloudLens`, `WordCloudTuning`, `TermCount`,
  `WordCloudLexiconSet`, `WordCloudStopwordSet`). Compiled directly into the app
  targets via `project.yml` (like `FTS5Store`/`SourceNoteKit`) **and** an SPM library
  target, so `CloudVectorsGenerator` tokenises the corpus through the app's own code.
  Lexicon/stopword payloads are **injected**, never read from `Bundle.main` — the app
  supplies them from its bundle (`WordCloudStopwords`/`WordCloudLexicons`), the
  generator from file URLs. `WordCloudMultiLensTokenizer` counts N lenses from one
  `NLTagger` pass; `WordCloudKitTests` pins it against N single-lens runs, and that
  parity suite is what makes the merge safe — do not weaken it. Since #1608 the same pass also
  counts every word as printed (`accumulate(from:into:printedInto:)`), for the keyness reference a
  launch with no lemmatiser compares with; `WordCloudPrintedFormParityTests` holds that tally to a
  `.printed` tokenizer's, and the generator's `VERIFY_PRINTED_WALK=1` run holds it over the corpus.
  Since FRUS Explorer Light's S24d the web edition compiles it on Linux. Since its S29a the two
  tokenizers read a tagger through a protocol, `WordCloudTagger` (`WordCloudTagger.swift`): each word
  of a text in order with its range and, when the walk asks (`WordCloudTagReading`), its lemma and its
  lexical class, and for the entity lenses each name with its type; a tagger comes with its
  `NaturalLanguageHealth` and its `WordCloudTokenizerIdentity`. Both tokenizers' `accumulate(…tagger:)`
  count with any tagger on every platform; their `accumulate` without one counts with NaturalLanguage's
  through the readiness gate (`NaturalLanguageWordCloudTagger`, and `NLTagger` conforms), as before, so
  the two parity suites hold the app's counts. The clouds' provenance and the references' configuration
  name the tokenizer; a file that names none was counted by NaturalLanguage at version 1
  (`WordCloudTokenizerIdentity.legacyNaturalLanguage`), and a stamp of that tokenizer is written without
  the key, so the bundled files stand byte for byte and the generator writes the bytes it wrote; and
  `KeynessBaselineFile.Configuration.mismatches(…tokenizer:)` refuses a scope counted by another
  (`Mismatch.tokenizer`); `CloudVectorsRunner.run(tagger:cloudLenses:environment:)` takes the tagger and
  the lenses the clouds carry from its caller, and `run()` passes NaturalLanguage's. NaturalLanguage and
  `os` are imported behind `canImport(NaturalLanguage)`: the gate's taggers' conformances, the tokenizers'
  counting without a tagger and their scheme lists, and `NaturalLanguageReadiness`'s warm-up, gate and
  engine; where the framework is missing, each declaration that would tag with it is unavailable and
  says why, so nothing there counts without a host's tagger. `NaturalLanguageHealth` stays on every
  platform. CryptoKit is behind
  `canImport` too (`WordCloudPayloadDigest`), and the web edition's package supplies swift-crypto, so
  this package gains no dependency. The kit also holds `Keyness` and `KeynessScore` (`Keyness.swift`,
  from `FRUSExplorer/Analytics/`), `KeynessCloudMeasure`'s two cases (its label stays the app's, in
  `WordCloudLens+UI.swift`), the tuning's reading of the settings (`WordCloudTuning.minimumLength(fromSetting:)`
  and its siblings, which `WordCloudSettings` calls) and `CloudVectorsFile(contentsOf:)` and
  `KeynessBaselineFile(contentsOf:)`; `BundledCloudVectors` and `BundledKeynessBaseline` stay the app's,
  and since FRUS Explorer Light's S29b `KeynessCloud`, the references' lookup, the count, Collocates and the
  shared-word chips are FRUSCoreKit's, which depends on this kit. A WordCloudKitTests suite that tags with NaturalLanguage goes behind
  `canImport(NaturalLanguage)`; one that counts over a stand-in tagger runs everywhere
  (`WordCloudTaggerTests.swift`); and `WordCloudKitTests/KeynessTests.swift` is compiled into the app's
  test target too (`project.yml`).

**To see a launch with no lemmatiser** (#1608), the launch on which Collocates, Distinctive sizing and
Related's shared-word chips compare printed forms: launch a Debug build with
`SIMCTL_CHILD_FRUS_DEBUG_NO_LEMMA_ANSWER=1 xcrun simctl launch <udid> bottsywattsy.FRUS-Explorer`
and wait 30 seconds. The verdict then reads as the owner's iPhone's did, and Settings ▸ Data &
Recovery ▸ Diagnostics ▸ Language Analysis reads *Limited*. A simulator loses its lemmatiser only
by chance (none of fifteen launches of the iPhone 17 on 2026-10-12, one of three of the iPad Pro
13-inch (M5)); `NaturalLanguageReadiness.unansweredLemmaRequestEnvironmentKey` has the detail.
