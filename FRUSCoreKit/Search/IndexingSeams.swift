// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(SourceNoteKit)
import SourceNoteKit
#endif

// MARK: - IndexingStampStore

/// Where `IndexingPipeline` and `IndexingStateTracker` keep what they read back on a later run: the
/// date-index, FTS-schema and person-rollup stamps, the broken-references artifact last applied, and
/// the interrupted-indexing sentinel.
///
/// The requirements are `UserDefaults`' own methods, spelled as it spells them, so the app's
/// conformance is empty (`IndexingPipeline+App.swift`) and its stamps stay under the keys and in the
/// domain they always used. The kit never names `UserDefaults` itself (FRUSCoreKitBoundaryTests): a
/// host without one, such as FRUS Explorer Light's server or a package test, passes an
/// ``InMemoryIndexingStampStore``.
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): initial implementation
public protocol IndexingStampStore: AnyObject, Sendable {
    /// The integer stored under `defaultName`, or 0 when there is none.
    func integer(forKey defaultName: String) -> Int
    /// The string stored under `defaultName`, or `nil` when there is none.
    func string(forKey defaultName: String) -> String?
    /// The data stored under `defaultName`, or `nil` when there is none.
    func data(forKey defaultName: String) -> Data?
    /// Stores `value` under `defaultName`; `nil` removes it.
    func set(_ value: Any?, forKey defaultName: String)
    /// Removes whatever is stored under `defaultName`.
    func removeObject(forKey defaultName: String)
}

// MARK: - InMemoryIndexingStampStore

/// An ``IndexingStampStore`` that lives as long as the process: for a host that keeps no stamps
/// between runs, and for tests that must not touch the app's own.
///
/// It answers as `UserDefaults` does for the values the pipeline stores: an `Int` reads back through
/// ``integer(forKey:)`` and ``string(forKey:)``, a `String` through ``string(forKey:)`` and, when it
/// holds a number, ``integer(forKey:)``, and `Data` through ``data(forKey:)``.
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): initial implementation
public final class InMemoryIndexingStampStore: IndexingStampStore, @unchecked Sendable {

    /// Guards `values`; the pipeline reads some stamps off its actor (`needsFTSRebuildReindex`).
    private let lock = NSLock()
    /// The stored values, by key.
    private var values: [String: Any] = [:]

    /// An empty store.
    public init() {}

    /// The integer under `defaultName`: an `Int` as stored, a `String` holding one parsed, else 0.
    public func integer(forKey defaultName: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        switch values[defaultName] {
        case let value as Int: return value
        case let value as String: return Int(value) ?? 0
        default: return 0
        }
    }

    /// The string under `defaultName`: a `String` as stored, an `Int` written out, else `nil`.
    public func string(forKey defaultName: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        switch values[defaultName] {
        case let value as String: return value
        case let value as Int: return String(value)
        default: return nil
        }
    }

    /// The data under `defaultName`, or `nil`.
    public func data(forKey defaultName: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[defaultName] as? Data
    }

    /// Stores `value` under `defaultName`; `nil` removes it.
    public func set(_ value: Any?, forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        values[defaultName] = value
    }

    /// Removes whatever is stored under `defaultName`.
    public func removeObject(forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        values[defaultName] = nil
    }
}

// MARK: - IndexingResources

/// The bundled data files the indexer and search read, handed to `IndexingPipeline` by its host.
///
/// Four of them change what an index holds: the person-authority crosswalk (the person rollup's
/// canonical ids), the document-subject index (`document_subjects` and its facet), the decimal-class
/// label table (which body-footnote class citations `external_citations` keeps) and the
/// broken-references index (`cross_references.is_broken`). The fifth provider answers the
/// related-documents alias fallback from the collection authority, which only the app holds today.
///
/// Each provider is asked on first use and may load then, so a host decides when the decode is
/// paid: the app's ``bundled`` wraps its existing lazy stores (`IndexingPipeline+App.swift`), whose
/// 6 MB and 2.4 MB decodes keep their first-use timing (#736); ``loading(fromDirectory:)`` decodes
/// each file once, on first use, from a folder of the app's resources. The kit itself never reads a
/// bundle (FRUSCoreKitBoundaryTests).
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): initial implementation
public struct IndexingResources: Sendable {

    /// The person-authority crosswalk, or `nil` when the host has none.
    let personAuthority: @Sendable () -> PersonAuthorityIndex?
    /// The document-grain subject index, or `nil`.
    let documentSubjects: @Sendable () -> DocumentSubjectIndex?
    /// The decimal-class label table, or `nil`.
    let decimalClassLabels: @Sendable () -> DecimalClassLabelTable?
    /// The broken-references index, or `nil`.
    let brokenRefs: @Sendable () -> BrokenRefsIndex?
    /// The collection-authority alias fallback for a source note (parsed, raw), or `nil`.
    let collectionAliasFallback: @Sendable (ParsedSourceNote, String) -> IndexingPipeline.CollectionAliasFallback?

    /// A set of providers. Internal, so the resource types can stay internal to the kit; a host
    /// outside the module uses ``none`` or ``loading(fromDirectory:)``.
    init(personAuthority: @escaping @Sendable () -> PersonAuthorityIndex?,
         documentSubjects: @escaping @Sendable () -> DocumentSubjectIndex?,
         decimalClassLabels: @escaping @Sendable () -> DecimalClassLabelTable?,
         brokenRefs: @escaping @Sendable () -> BrokenRefsIndex?,
         collectionAliasFallback: @escaping @Sendable (ParsedSourceNote, String)
            -> IndexingPipeline.CollectionAliasFallback? = { _, _ in nil }) {
        self.personAuthority = personAuthority
        self.documentSubjects = documentSubjects
        self.decimalClassLabels = decimalClassLabels
        self.brokenRefs = brokenRefs
        self.collectionAliasFallback = collectionAliasFallback
    }

    /// No resources: every provider answers `nil`, as the app's stores do when a file is missing.
    /// An index built this way lacks subjects, class citations, broken-reference flags and
    /// authority ids, so it is for tests that need none of them.
    public static let none = IndexingResources(
        personAuthority: { nil }, documentSubjects: { nil },
        decimalClassLabels: { nil }, brokenRefs: { nil })

    /// The four files that change what an index holds, by resource name.
    public static let indexResourceNames = [
        "person-authority-index", "document-subject-index", "decimal-class-labels", "broken-refs-index",
    ]

    /// Why ``loading(fromDirectory:)`` refused a folder.
    public enum LoadError: Error, Equatable, CustomStringConvertible {
        /// These `.json` files are not in the folder.
        case missing(directory: String, names: [String])

        /// The refusal, as a sentence.
        public var description: String {
            switch self {
            case .missing(let directory, let names):
                return "\(directory) lacks \(names.map { "\($0).json" }.joined(separator: ", ")); "
                    + "an index built without them differs from the app's"
            }
        }
    }

    /// Providers that decode each file in `directory` once, on first use: the app's
    /// `FRUSExplorer/Resources`, or a copy of it. Throws ``LoadError/missing(directory:names:)``
    /// when any of ``indexResourceNames`` is absent, since an index built without one differs from
    /// the app's while every step reports success. A file that is present but will not decode
    /// answers `nil`, as the app's stores do. The alias fallback answers `nil`.
    public static func loading(fromDirectory directory: URL) throws -> IndexingResources {
        let missing = indexResourceNames.filter {
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent("\($0).json").path)
        }
        guard missing.isEmpty else { throw LoadError.missing(directory: directory.path, names: missing) }
        let authority = LazyResource<PersonAuthorityIndex>(directory, "person-authority-index")
        let subjects = LazyResource<DocumentSubjectIndex>(directory, "document-subject-index")
        let labels = LazyResource<DecimalClassLabelTable>(directory, "decimal-class-labels")
        let broken = LazyResource<BrokenRefsIndex>(directory, "broken-refs-index")
        return IndexingResources(
            personAuthority: { authority.value() }, documentSubjects: { subjects.value() },
            decimalClassLabels: { labels.value() }, brokenRefs: { broken.value() })
    }
}

/// One JSON resource, decoded the first time it is asked for and kept.
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): initial implementation
final class LazyResource<Value: Decodable & Sendable>: @unchecked Sendable {

    /// Guards `loaded`.
    private let lock = NSLock()
    /// `nil` until loaded; then the decoded value, or `.some(nil)` when it would not decode.
    private var loaded: Value??
    /// The file to decode.
    private let url: URL

    /// The resource `name`.json in `directory`.
    init(_ directory: URL, _ name: String) {
        url = directory.appendingPathComponent("\(name).json")
    }

    /// The decoded value, decoding it on the first call; `nil` when the file will not decode.
    func value() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        if let loaded { return loaded }
        let value: Value?
        do {
            value = try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[IndexingResources] \(url.lastPathComponent) failed to decode: \(error)")
            #endif
            value = nil
        }
        loaded = .some(value)
        return value
    }
}

// MARK: - IndexedDocumentDonor

/// One indexed document as the indexer hands it to a donor: the cached fields a system search index
/// shows.
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): initial implementation
public struct DonatedDocument: Sendable, Equatable {
    /// The document's volume.
    public let volumeId: String
    /// The document's id within the volume.
    public let documentId: String
    /// The cached header; may be empty.
    public let header: String
    /// The cached body text.
    public let bodyText: String
    /// The printed document number, if any.
    public let documentNumber: String?
    /// Whether the document is an editorial note.
    public let isEditorialNote: Bool

    /// Memberwise, spelled out because `public` suppresses the synthesized one.
    public init(volumeId: String, documentId: String, header: String, bodyText: String,
                documentNumber: String?, isEditorialNote: Bool) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.header = header
        self.bodyText = bodyText
        self.documentNumber = documentNumber
        self.isEditorialNote = isEditorialNote
    }
}

/// What the indexer tells a system search index: the app's Spotlight donor
/// (`IndexingPipeline+App.swift`). A host without one passes none.
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): initial implementation
public protocol IndexedDocumentDonor: Sendable {
    /// A volume was indexed: offer its documents. Best-effort, and called on the pipeline's actor
    /// in the place `indexVolume` donated before, so it must not block.
    func donate(volumeId: String, documents: [DonatedDocument])
    /// A volume left the index: withdraw what was offered for it.
    func withdraw(volumeId: String) async
}

// MARK: - IndexingPipeline + post-index passes

extension IndexingPipeline {

    /// Runs the passes that follow indexing, in the order the app's launch runs them: the person
    /// rollup, then the broken-reference flags, then the document subjects. Each is gated and
    /// idempotent, and a failure in one does not stop the next, as at the app's call sites.
    ///
    /// The app's three launch branches call this, and FRUS Explorer Light's indexer is to call it
    /// too, so the two build their indexes through the same steps.
    ///
    /// `nonisolated`, so each pass is a call of its own into the actor, as the launch's three calls
    /// were: other work queued on the pipeline, a search among it, runs between passes rather than
    /// waiting for all three.
    ///
    /// - Parameters:
    ///   - overrides: The user's person-cluster corrections, applied by the rollup.
    ///   - afterRollupRebuild: Called when the rollup was rebuilt, before the next pass starts, so a
    ///     host can publish the renumbered ids as soon as they exist (#747).
    /// - Returns: Whether the rollup was rebuilt.
    @discardableResult
    public nonisolated func runPostIndexPasses(overrides: [PersonClusterOverrideData] = [],
                                               afterRollupRebuild: (@Sendable () async -> Void)? = nil) async -> Bool {
        let rebuilt = (try? await consolidatePersonRollupIfNeeded(overrides: overrides)) == true
        if rebuilt, let afterRollupRebuild { await afterRollupRebuild() }
        try? await applyBrokenRefsIndexIfNeeded()
        try? await applyDocumentSubjectsIfNeeded()
        return rebuilt
    }
}
