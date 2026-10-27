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

// MARK: - WorkingCorpusResolution

/// What a working corpus amounts to **on this device**.
///
/// The corpus names a fixed set of documents; a device holds whichever of them it has indexed. Both
/// numbers are facts and a researcher needs both: the denominator of any claim is the corpus, while
/// what a query can actually reach is the indexed part.
///
/// This is the pay-off of syncing the key list rather than the query (decision M-1-1). Re-resolving
/// per device would have produced the *indexed* number alone, with nothing to compare it to and no
/// way to know the two devices disagreed.
///
/// Version history:
///   1.0 — M-1: initial implementation
///   1.1 — #1761: the coverage sentence groups both counts, and says "document" when the corpus
///          holds one
///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit from the app's
///          `Models/WorkingCorpusResolver.swift`, public, for the web edition's working corpora
public struct WorkingCorpusResolution: Equatable, Sendable {

    /// Keys this device can actually query — the ones present in the index.
    public let indexedKeys: [String]
    /// Documents the corpus names, indexed or not.
    public let totalCount: Int
    /// Volumes the corpus spans that this device has not indexed.
    public let missingVolumeIds: [String]

    /// Creates a resolution from its three facts, as ``WorkingCorpusResolver/resolve(documentKeys:)``
    /// finds them.
    public init(indexedKeys: [String], totalCount: Int, missingVolumeIds: [String]) {
        self.indexedKeys = indexedKeys
        self.totalCount = totalCount
        self.missingVolumeIds = missingVolumeIds
    }

    /// Documents reachable here.
    public var indexedCount: Int { indexedKeys.count }
    /// Whether the whole corpus is reachable on this device.
    public var isComplete: Bool { indexedCount == totalCount }

    /// The coverage sentence a scope control shows.
    ///
    /// Always states both numbers, even when complete: "267 of 267" tells a reader the corpus is
    /// whole, where a bare "267 documents" leaves them to wonder whether it was clipped.
    ///
    /// Both counts are grouped, as the corpus's own row prints its size: the `%lld` form read
    /// "10914 of 10914" under a cluster whose row read 10,914 (#1761). The noun follows the
    /// corpus's size, so a corpus of one reads "1 of 1 document".
    public var coverageDescription: String {
        CountCopy.phrase(
            totalCount,
            one: String(localized: "workingCorpus.coverage.one %@ %@",
                        defaultValue: "%2$@ of %1$@ document indexed on this device"),
            many: String(localized: "workingCorpus.coverage.many %@ %@",
                         defaultValue: "%2$@ of %1$@ documents indexed on this device"),
            then: [indexedCount.formatted()])
    }
}

// MARK: - WorkingCorpusResolver

/// Resolves a working corpus against the local index.
///
/// Version history:
///   1.0 — M-1: initial implementation
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, resolving a
///          corpus's keys (``resolve(documentKeys:)``); the app's `resolve(_:)`, which takes a
///          `WorkingCorpus`, passes its keys here
public struct WorkingCorpusResolver: Sendable {

    /// The indexed-volume set, used to explain which parts of a corpus are out of reach.
    public let indexedVolumeIds: Set<String>

    /// Creates a resolver for the volumes a device, or a server, has indexed.
    public init(indexedVolumeIds: Set<String>) {
        self.indexedVolumeIds = indexedVolumeIds
    }

    /// Resolves a corpus, by its `"volumeId/documentId"` keys, against the index.
    ///
    /// Membership is decided **by volume**, not by a per-document index probe. A document key whose
    /// volume is indexed is reachable; one whose volume is not, is not. That is exact rather than
    /// approximate — `IndexingPipeline` indexes a volume's documents as a unit — and it costs a set
    /// lookup per key instead of a query per key, which matters at the several-thousand-key scale a
    /// corpus can reach.
    ///
    /// - Parameter documentKeys: The corpus's `documentKeys`, as the record stores them.
    /// - Returns: What the corpus amounts to against this index.
    public func resolve(documentKeys: [String]) -> WorkingCorpusResolution {
        var indexed: [String] = []
        var missing: Set<String> = []
        for key in documentKeys {
            guard let volumeId = key.split(separator: "/").first.map(String.init) else { continue }
            if indexedVolumeIds.contains(volumeId) {
                indexed.append(key)
            } else {
                missing.insert(volumeId)
            }
        }
        return WorkingCorpusResolution(
            indexedKeys: indexed,
            totalCount: documentKeys.count,
            missingVolumeIds: missing.sorted()
        )
    }
}

// MARK: - DocumentScopeGate

/// Composes the document-grain constraints a search may carry at once.
///
/// A working corpus and a project History scope are both sets of documents the user asked to be
/// inside. Living here rather than in the view model because it is a rule about what a scope
/// *means*, not about how a screen holds state — and because a rule this consequential should be
/// testable without standing up a search service.
///
/// Version history:
///   1.0 — M-1: initial implementation
///   1.1 — #1577 lane 4: `combine(corpus:projectGate:pin:)`, a held base's members as a third set
///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, unchanged, for
///          the web edition's working corpora and History scope
public enum DocumentScopeGate {

    /// Intersects the constraints, preserving the empty-set contract.
    ///
    /// **Intersection, not replacement.** Both constraints were asked for, so a History scope inside
    /// a working corpus means the documents in both.
    ///
    /// An empty result stays an empty **array**, never `nil`: `IndexingPipeline` reads an empty
    /// `documentIds` as "match nothing" and `nil` as "no constraint". Collapsing a disjoint
    /// intersection to `nil` would search the entire corpus while two scope labels sit on screen —
    /// the worst available answer, because it looks like a result rather than an error.
    public static func combine(corpus: [String]?, projectGate: [String]?) -> [String]? {
        guard let corpus else { return projectGate }
        guard let projectGate else { return corpus }
        return Set(corpus).intersection(projectGate).sorted()
    }

    /// Intersects the constraints with a held base's members as a third set (#1577 lane 4): a search
    /// inside a held list is also inside the corpus and the History scope the list was found in.
    ///
    /// The same contract as ``combine(corpus:projectGate:)``: `nil` is no constraint, and an empty
    /// result stays an empty array, which matches nothing. A base whose members fall wholly outside a
    /// corpus applied since gives a layer that finds nothing, never one that searches the series.
    ///
    /// - Parameters:
    ///   - corpus: The applied working corpus's keys, or `nil`.
    ///   - projectGate: The project's History scope, or `nil`.
    ///   - pin: The held base's member keys, or `nil` when no base is held.
    /// - Returns: The intersection, or `nil` when no constraint is set.
    public static func combine(corpus: [String]?, projectGate: [String]?, pin: [String]?) -> [String]? {
        let scoped = combine(corpus: corpus, projectGate: projectGate)
        guard let pin else { return scoped }
        guard let scoped else { return pin }
        return Set(scoped).intersection(pin).sorted()
    }
}

// MARK: - SearchParameters + working corpus

extension SearchParameters {

    /// These parameters as a hand-off or a recalled search runs them on a screen whose applied
    /// working corpus is `corpus`: inside that corpus, and under no other document gate (#1646).
    ///
    /// A snapshot's own gates are never inherited. Its `documentIds` and `excludeDocumentIds` carry
    /// the project's History and Focus scopes, which are live, manual choices (#377 Phase 2), or a
    /// corpus as it stood when the search was saved. The applied working corpus is the screen's own
    /// state and stays applied: its banner goes on naming it, so the search runs inside it.
    ///
    /// iPhone and iPad have always run a hand-off this way, because `SearchViewModel` composes the
    /// gate from the corpus it holds each time it builds parameters. The Mac's window holds whole
    /// parameters, and until #1646 it dropped the corpus with the project's gates while its banner
    /// went on saying the search was inside it. `MacSearchViewModel.applyParameters(_:)` asks this.
    ///
    /// Moved here from the app's `Search/SearchModels.swift` in S17b (FRUS Explorer Light), public and
    /// unchanged, beside the gate it composes with, for the web edition's saved searches.
    ///
    /// - Parameter corpus: The applied working corpus's indexed keys, or `nil` when none is applied.
    /// - Returns: These parameters, with that corpus as their only document gate.
    public func runningInside(workingCorpus corpus: [String]?) -> SearchParameters {
        var parameters = self
        parameters.documentIds = DocumentScopeGate.combine(corpus: corpus, projectGate: nil)
        parameters.excludeDocumentIds = nil
        return parameters
    }
}

// MARK: - CorpusCaptureTruncation

/// What is known about whether a working corpus's capture was the whole answer to its query (#607).
///
/// Three states, not two. `unrecorded` is not a synonym for `complete`: it is the honest
/// description of every corpus captured before the fields existed, and a consumer that
/// collapses it into `complete` re-tells the lie the fields were added to stop.
///
/// Version history:
///   1.0 — #607: initial implementation, as `WorkingCorpus.CaptureTruncation`
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with the
///          reading of a corpus's two fields (``init(wasTruncated:totalMatchCount:)``) and the
///          truncation line (``line(documentCount:isMeaningCapture:locale:)``) the corpus lists and the
///          method appendix print, which were `CorporaAxis.truncationLine(_:documentCount:isMeaningCapture:)`;
///          `WorkingCorpus.CaptureTruncation` names it
public enum CorpusCaptureTruncation: Equatable, Sendable {
    /// The fetch stopped short. `total` is the whole-query count where the device had one.
    case truncated(total: Int?)
    /// The capture was every matching document.
    case complete
    /// Captured before the app recorded this. Nothing can be concluded either way.
    case unrecorded

    /// The truncation a corpus's two fields record — the only supported way to read them, which
    /// `WorkingCorpus.truncationAtCapture` reads them by.
    ///
    /// - Parameters:
    ///   - wasTruncated: The corpus's `wasTruncatedAtCapture`: `nil` when not recorded.
    ///   - totalMatchCount: The corpus's `totalMatchCountAtCapture`.
    public init(wasTruncated: Bool?, totalMatchCount: Int?) {
        switch wasTruncated {
        case .some(true): self = .truncated(total: totalMatchCount)
        case .some(false): self = .complete
        case nil: self = .unrecorded
        }
    }

    /// The truncation disclosure line, or `nil` when the capture was complete.
    ///
    /// A Meaning search's capture is recorded as cut short with no total (`ResultSetScope.isCapturePartial`), the
    /// value every reader of the flag treats with care, and until #1688 it read "The capture stopped short of every
    /// match", the words written for a keyword fetch. A ranking has no "every match": the line names what the set
    /// is instead, with the corpus's own count, and is drawn quiet (`CorporaAxis.drawsTruncationLineInAmber`).
    ///
    /// - Parameters:
    ///   - documentCount: The corpus's `documentCount`.
    ///   - isMeaningCapture: The corpus's `isMeaningCapture`.
    ///   - locale: The locale that groups the counts; the user's own unless a host or a test passes one.
    /// - Returns: The amber line for a truncated capture, the quiet line for an
    ///   unrecorded one or a Meaning search's, `nil` for a complete one.
    public func line(documentCount: Int, isMeaningCapture: Bool = false,
                     locale: Locale = .autoupdatingCurrent) -> String? {
        switch self {
        case .truncated where isMeaningCapture:
            return documentCount == 1
                ? String(localized: "browser.corpora.meaning.one",
                         defaultValue: "The closest match of a Meaning search")
                : String(format: String(localized: "browser.corpora.meaning %@",
                                        defaultValue: "The %@ closest matches of a Meaning search"),
                         documentCount.formatted(.number.locale(locale)))
        case .truncated(let total?):
            return String(localized: "browser.corpora.truncated",
                          defaultValue: "Saved \(documentCount) of \(total) matches", locale: locale)
        case .truncated(nil):
            return String(localized: "browser.corpora.truncated.noTotal",
                          defaultValue: "The capture stopped short of every match")
        case .complete:
            return nil
        case .unrecorded:
            return String(localized: "browser.corpora.unrecorded",
                          defaultValue: "Capture completeness not recorded")
        }
    }
}

// MARK: - WorkingCorpusProvenance

/// What a working corpus's stored provenance sentence says about its capture (#1688).
///
/// A corpus records no route, and a field for one would be a CloudKit schema change, so the sentence the capture
/// stored (`WorkingCorpus.sourceDescription`, which the app's `ResultSetScope.captureProvenanceDescription` writes)
/// is what says the set was a Meaning search's. The corpus lists and the method appendix then say "The 100 closest
/// matches of a Meaning search" of it (``CorpusCaptureTruncation/line(documentCount:isMeaningCapture:locale:)``),
/// where a keyword capture cut short is said to have stopped short of every match.
///
/// Version history:
///   1.0 — #1688: initial implementation, as `ResultSetScope.meaningProvenance` and
///          `isMeaningCaptureProvenance(_:)` in the app's `Search/ResultSetScope.swift`
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public and unchanged, for the
///          coverage block of the web edition's method appendix; `ResultSetScope` keeps both names, and the
///          singular sentence it writes for a capture of one
public enum WorkingCorpusProvenance {

    /// A Meaning search's provenance sentence, with `%@` where the count of its closest matches goes.
    public static var meaningSearch: String {
        String(localized: "corpus.save.source.meaning %@",
               defaultValue: "Meaning search — the %@ closest matches")
    }

    /// Whether `description` is the provenance a capture stores for a Meaning search.
    ///
    /// Both of its forms, "Meaning search — the 100 closest matches" and "Meaning search — the closest match",
    /// begin with the words the plural form prints before its count, and no other capture's sentence does: a
    /// keyword list's is "Search results", words found in a Meaning list's "Words found in…", a lasso's and a
    /// cluster's the semantic map's. A corpus saved from a Meaning list before #1598 was recorded as "Search
    /// results" and is not recognised, since nothing on its record tells it from a keyword capture.
    ///
    /// - Parameter description: `WorkingCorpus.sourceDescription`.
    /// - Returns: `true` for a Meaning search's provenance.
    public static func isMeaningCapture(_ description: String?) -> Bool {
        guard let description,
              let stem = meaningSearch.components(separatedBy: "%@").first,
              !stem.isEmpty else { return false }
        return description.hasPrefix(stem)
    }
}
