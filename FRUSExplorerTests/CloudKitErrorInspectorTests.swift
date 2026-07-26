// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CloudKit
import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - Fixtures

/// Builds the CloudKit error shapes #488 produced, offline.
///
/// Every one of them is an `NSError` with a hand-built `userInfo`, so no iCloud account, no
/// container and no network is involved. That was the argument for doing this at all: the shapes
/// are constructible, so "we cannot test CloudKit failures" was never true.
private enum ErrorFixtures {

    /// A `CKError` sub-error as it appears inside a per-item dictionary.
    static func subError(code: Int, description: String? = nil) -> NSError {
        var info: [String: Any] = [:]
        if let description { info[NSLocalizedDescriptionKey] = description }
        return NSError(domain: CKErrorDomain, code: code, userInfo: info)
    }

    /// A `partialFailure` carrying `count` sub-errors of `code`, keyed by distinct record ids.
    ///
    /// The keys are `CKRecord.ID`s exactly as CloudKit sends them — and exactly what the
    /// inspector must never read.
    static func partialFailure(subErrors: [(code: Int, count: Int, description: String?)],
                               extra: [String: Any] = [:]) -> NSError {
        var partial: [AnyHashable: Error] = [:]
        for group in subErrors {
            for _ in 0..<group.count {
                let id = CKRecord.ID(recordName: UUID().uuidString)
                partial[id] = subError(code: group.code, description: group.description)
            }
        }
        var info: [String: Any] = [CKPartialErrorsByItemIDKey: partial]
        info.merge(extra) { _, new in new }
        return NSError(domain: CKErrorDomain,
                       code: CKError.partialFailure.rawValue,
                       userInfo: info)
    }

    /// Wraps `error` in an outer error one hop up, the way `NSPersistentCloudKitContainer`
    /// re-vends a CloudKit failure.
    static func wrapped(_ error: NSError,
                        domain: String = "NSCocoaErrorDomain",
                        code: Int = 134_400) -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSUnderlyingErrorKey: error])
    }

    /// Wraps several errors under `NSMultipleUnderlyingErrorsKey`.
    static func wrappedMultiple(_ errors: [NSError],
                                domain: String = "NSCocoaErrorDomain",
                                code: Int = 134_400) -> NSError {
        NSError(domain: domain, code: code,
                userInfo: [NSMultipleUnderlyingErrorsKey: errors])
    }
}

/// An error whose underlying error is itself — the shape a bounded walk has to survive.
///
/// `NSError.userInfo` is immutable at init, so a cycle cannot be built by construction; overriding
/// the getter is the only way to produce one. That makes this a genuine test of the identity set
/// rather than of the depth bound (which the `deepChain` test covers separately).
private final class SelfReferencingError: NSError, @unchecked Sendable {
    override var userInfo: [String: Any] { [NSUnderlyingErrorKey: self] }
}

// MARK: - CloudKitErrorInspectorTests

/// Tests the Wave R-6 CloudKit error walk (issue #488).
///
/// Before this suite existed, `grep` for `cloudKitDiagnostic` or `SyncDiagnosticsEntry` across
/// both test targets returned nothing at all — the diagnostic path that was supposed to explain a
/// sync failure had never been executed by a test.
struct CloudKitErrorInspectorTests {

    // MARK: Finding the per-item dictionary

    @Test("A top-level partialFailure is found at depth 0")
    func topLevelPartialFailure() {
        let error = ErrorFixtures.partialFailure(subErrors: [
            (code: 21, count: 10, description: nil),
            (code: 14, count: 2, description: nil),
        ])
        let result = CloudKitErrorInspector.inspect(error)

        #expect(result.hadPartialDictionary)
        #expect(result.partialDictionaryDepth == 0)
        #expect(result.partialItemCount == 12)
        #expect(result.subErrorHistogram?.map(\.key) == ["changeTokenExpired", "serverRecordChanged"])
        #expect(result.subErrorHistogram?.map(\.count) == [10, 2])
        #expect(!result.chainTruncated)
    }

    /// The #488 shape: the container re-vends the failure, so the dictionary is one hop down and
    /// the one-level lookup that shipped saw nothing.
    @Test("A partialFailure nested under NSUnderlyingErrorKey is found at depth 1")
    func nestedPartialFailure() {
        let inner = ErrorFixtures.partialFailure(subErrors: [(code: 12, count: 4, description: nil)])
        let result = CloudKitErrorInspector.inspect(ErrorFixtures.wrapped(inner))

        #expect(result.hadPartialDictionary)
        #expect(result.partialDictionaryDepth == 1)
        #expect(result.partialItemCount == 4)
        #expect(result.subErrorHistogram?.first?.key == "invalidArguments")
    }

    @Test("A partialFailure reached through NSMultipleUnderlyingErrorsKey is found")
    func partialFailureUnderMultipleErrors() {
        let noise = NSError(domain: CKErrorDomain, code: 3, userInfo: [:])
        let inner = ErrorFixtures.partialFailure(subErrors: [(code: 15, count: 2, description: nil)])
        let result = CloudKitErrorInspector.inspect(
            ErrorFixtures.wrappedMultiple([noise, inner]))

        #expect(result.hadPartialDictionary)
        #expect(result.partialDictionaryDepth == 1)
        #expect(result.partialItemCount == 2)
    }

    @Test("Two hops down is still found")
    func doublyNestedPartialFailure() {
        let inner = ErrorFixtures.partialFailure(subErrors: [(code: 11, count: 1, description: nil)])
        let result = CloudKitErrorInspector.inspect(
            ErrorFixtures.wrapped(ErrorFixtures.wrapped(inner)))

        #expect(result.partialDictionaryDepth == 2)
        #expect(result.partialItemCount == 1)
    }

    /// The distinction that cost #488 the most time. "We looked and there was none" has to be a
    /// recorded fact, not the same silence as "we never looked".
    @Test("An error with no per-item dictionary reports that it looked and found none")
    func noPartialDictionary() {
        let result = CloudKitErrorInspector.inspect(
            NSError(domain: CKErrorDomain, code: 9, userInfo: [:]))

        #expect(!result.hadPartialDictionary)
        #expect(result.partialDictionaryDepth == nil)
        #expect(result.partialItemCount == nil)
        #expect(!result.chainTruncated, "a short chain is exhausted, not truncated")
    }

    /// A dictionary that exists but is empty is not the same as no dictionary at all, and the
    /// scalar count has to preserve the difference.
    @Test("An empty per-item dictionary is found, with a count of zero")
    func emptyPartialDictionary() {
        let error = NSError(domain: CKErrorDomain,
                            code: CKError.partialFailure.rawValue,
                            userInfo: [CKPartialErrorsByItemIDKey: [AnyHashable: Error]()])
        let result = CloudKitErrorInspector.inspect(error)

        #expect(result.hadPartialDictionary)
        #expect(result.partialItemCount == 0)
        #expect(result.subErrorHistogram?.isEmpty == true)
    }

    // MARK: Termination

    @Test("A self-referential error chain terminates instead of hanging")
    func cyclicChainTerminates() {
        let cyclic = SelfReferencingError(domain: CKErrorDomain, code: 1, userInfo: [:])
        let result = CloudKitErrorInspector.inspect(cyclic)

        #expect(result.errorsVisited == 1, "the same node reached twice must not be walked twice")
        #expect(!result.hadPartialDictionary)
    }

    /// The depth bound is the other half of termination — and a bounded walk that found nothing
    /// must say it was bounded, or `hadPartialDictionary == false` would be a lie.
    @Test("A chain deeper than the bound stops, and admits it was truncated")
    func deepChainIsTruncatedNotSilent() {
        var error = ErrorFixtures.partialFailure(subErrors: [(code: 12, count: 1, description: nil)])
        for _ in 0..<(CloudKitErrorInspector.maxDepth + 3) {
            error = ErrorFixtures.wrapped(error)
        }
        let result = CloudKitErrorInspector.inspect(error)

        #expect(!result.hadPartialDictionary)
        #expect(result.chainTruncated, "a bounded walk that found nothing must not read as an absence")
        #expect(result.errorsVisited <= CloudKitErrorInspector.maxDepth + 1)
    }

    @Test("A wide fan-out is capped at the visit ceiling")
    func wideFanOutIsCapped() {
        let siblings = (0..<(CloudKitErrorInspector.maxErrorsVisited * 2)).map { i in
            NSError(domain: CKErrorDomain, code: i % 5, userInfo: [:])
        }
        let result = CloudKitErrorInspector.inspect(ErrorFixtures.wrappedMultiple(siblings))

        #expect(result.errorsVisited <= CloudKitErrorInspector.maxErrorsVisited)
        #expect(result.chainTruncated)
    }

    // MARK: Determinism

    /// Two buckets of equal size used to come out in dictionary order, so the same failure
    /// produced a different dump on each run and two pasted logs could not be compared.
    @Test("Equal-sized buckets are ordered by code, so repeated runs agree")
    func histogramIsDeterministic() {
        let dumps: Set<[String]> = Set((0..<8).map { _ in
            let error = ErrorFixtures.partialFailure(subErrors: [
                (code: 26, count: 3, description: nil),
                (code: 14, count: 3, description: nil),
                (code: 11, count: 3, description: nil),
            ])
            return CloudKitErrorInspector.inspect(error).subErrorHistogram?.map(\.key) ?? []
        })
        #expect(dumps.count == 1, "the same failure must render the same breakdown every time")
        #expect(dumps.first == ["unknownItem", "serverRecordChanged", "zoneNotFound"])
    }

    // MARK: Schema identifiers

    /// #488's four identifiers, in the sentence CloudKit actually writes.
    @Test("Schema identifiers are recovered from a sub-error's server text")
    func schemaIdentifiersFromSubErrors() {
        let error = ErrorFixtures.partialFailure(subErrors: [
            (code: 12, count: 2,
             description: "Invalid arguments: Unknown field 'CD_leadAxisWeights' in record type 'CD_Project'"),
            (code: 12, count: 1,
             description: "Invalid arguments: Unknown record type 'CD_ProjectLeadEntry'"),
        ])
        let result = CloudKitErrorInspector.inspect(error)

        #expect(result.schemaIdentifiers.contains("CD_leadAxisWeights"))
        #expect(result.schemaIdentifiers.contains("CD_Project"))
        #expect(result.schemaIdentifiers.contains("CD_ProjectLeadEntry"))
        #expect(result.schemaIdentifiers == result.schemaIdentifiers.sorted())
    }

    @Test("The _pcs_data system field is recognised")
    func pcsDataIsRecognised() {
        let error = NSError(domain: CKErrorDomain, code: 15, userInfo: [
            NSLocalizedDescriptionKey: "Field '_pcs_data' is not marked queryable",
        ])
        #expect(CloudKitErrorInspector.inspect(error).schemaIdentifiers == ["_pcs_data"])
    }

    @Test("Identifiers in a nested error's text are recovered too")
    func schemaIdentifiersFromNestedError() {
        let inner = NSError(domain: CKErrorDomain, code: 15, userInfo: [
            NSLocalizedDescriptionKey: "record type 'CD_Collection' field 'CD_includeProjectProvenance' not found",
        ])
        let result = CloudKitErrorInspector.inspect(ErrorFixtures.wrapped(inner))
        #expect(result.schemaIdentifiers == ["CD_Collection", "CD_includeProjectProvenance"])
    }

    @Test("The reported identifier list is capped")
    func identifiersAreCapped() {
        let text = (0..<50).map { "CD_Type\($0)" }.joined(separator: " ")
        let error = NSError(domain: CKErrorDomain, code: 15,
                            userInfo: [NSLocalizedDescriptionKey: text])
        #expect(CloudKitErrorInspector.inspect(error).schemaIdentifiers.count
                <= CloudKitErrorInspector.maxSchemaIdentifiers)
    }

    // MARK: Redaction — the contract with no mechanical gate but this one

    /// #188-C.1 forbids any free text from an `NSError` reaching the log, because record names,
    /// zone owner ids and field *values* all ride in `localizedDescription`. The contract has no
    /// other enforcement, so this test is the gate: if a later change starts logging the
    /// description, or widens the grammar, this goes red.
    @Test("A description full of identifiers yields no tokens at all")
    func personalDataNeverEscapes() {
        let recordName = "3F2504E0-4F89-11D3-9A0C-0305E82C3301"
        let description = """
            Record \(recordName) in zone com.apple.coredata.cloudkit.zone owned by \
            _9a3f21c8b7 for user researcher@example.edu failed: value "Kissinger memo, \
            Cairo 1974" conflicts with the server record
            """
        let error = NSError(domain: CKErrorDomain, code: 14, userInfo: [
            NSLocalizedDescriptionKey: description,
            NSLocalizedFailureReasonErrorKey: description,
            NSDebugDescriptionErrorKey: description,
        ])

        let result = CloudKitErrorInspector.inspect(error)

        #expect(result.schemaIdentifiers.isEmpty,
                "nothing in a record name, zone name, owner id, e-mail or field value is a schema identifier")
        #expect(CloudKitErrorInspector.schemaIdentifiers(in: description).isEmpty)

        // Belt and braces: no fragment of the description may survive anywhere in the result.
        let rendered = String(describing: result)
        for secret in [recordName, "researcher@example.edu", "Kissinger", "_9a3f21c8b7"] {
            #expect(!rendered.contains(secret), "\(secret) escaped into the inspection")
        }
    }

    /// The same description, but with one legitimate identifier buried in it. The identifier must
    /// come out and nothing around it may.
    @Test("Only the identifier escapes a description that also carries private data")
    func onlyIdentifierEscapes() {
        let description = "Record 3F2504E0-4F89-11D3 of type 'CD_ResearchNote' owned by _abc99 rejected"
        let error = NSError(domain: CKErrorDomain, code: 15,
                            userInfo: [NSLocalizedDescriptionKey: description])
        let result = CloudKitErrorInspector.inspect(error)

        #expect(result.schemaIdentifiers == ["CD_ResearchNote"])
        #expect(!String(describing: result).contains("_abc99"))
    }

    @Test("A run that merely contains CD_ is not an identifier")
    func prefixMustStartTheRun() {
        #expect(CloudKitErrorInspector.schemaIdentifiers(in: "someCD_thing xCD_y").isEmpty,
                "the prefix must begin a maximal identifier run, not appear inside one")
        #expect(CloudKitErrorInspector.schemaIdentifiers(in: "CD_").isEmpty,
                "a bare prefix names nothing")
        #expect(CloudKitErrorInspector.schemaIdentifiers(in: "pcs_data _pcs_datax").isEmpty)
        #expect(CloudKitErrorInspector.schemaIdentifiers(in: "(CD_Project.CD_name)")
                == Set(["CD_Project", "CD_name"]))
    }

    // MARK: Retry-after

    @Test("The server's retry-after hint is carried through")
    func retryAfterIsRecovered() {
        let error = NSError(domain: CKErrorDomain, code: 7,
                            userInfo: [CKErrorRetryAfterKey: NSNumber(value: 30.0)])
        #expect(CloudKitErrorInspector.inspect(error).retryAfterSeconds == 30.0)
    }

    @Test("A retry-after hint on a nested error is still found")
    func nestedRetryAfter() {
        let inner = NSError(domain: CKErrorDomain, code: 7,
                            userInfo: [CKErrorRetryAfterKey: NSNumber(value: 12.5)])
        #expect(CloudKitErrorInspector.inspect(ErrorFixtures.wrapped(inner)).retryAfterSeconds == 12.5)
    }

    // MARK: Code names

    @Test("CloudKit code names cover the codes the diagnostics text documents")
    func codeNames() {
        #expect(CloudKitErrorInspector.codeName(for: 2) == "partialFailure")
        #expect(CloudKitErrorInspector.codeName(for: 21) == "changeTokenExpired")
        #expect(CloudKitErrorInspector.codeName(for: 15) == "serverRejectedRequest")
        #expect(CloudKitErrorInspector.codeName(for: 9_999) == nil)
    }
}

// MARK: - CloudKitDiagnosticTests

/// Tests the caller that turns an inspection into the row the log stores and the string the sync
/// status shows.
struct CloudKitDiagnosticTests {

    @Test("A nested partialFailure now produces the breakdown, not a bare cocoa code")
    func nestedFailureIsDescribed() {
        let inner = ErrorFixtures.partialFailure(subErrors: [
            (code: 12, count: 3,
             description: "Unknown field 'CD_defaultUserTagIds' in record type 'CD_Project'"),
        ])
        let diag = FRUSExplorerApp.cloudKitDiagnostic(ErrorFixtures.wrapped(inner))

        #expect(diag.partialCount == 3)
        #expect(diag.message.contains("3× invalidArguments"))
        #expect(diag.inspection.partialDictionaryDepth == 1)
        #expect(diag.inspection.schemaIdentifiers.contains("CD_defaultUserTagIds"))
        // The top-level identity is still reported as the top-level identity.
        #expect(diag.domain == "NSCocoaErrorDomain")
        #expect(diag.code == 134_400)
    }

    /// The CloudKit code table used to be applied to every domain, so an `NSCocoaErrorDomain`
    /// code 4 was confidently reported as `networkFailure`.
    @Test("CloudKit code names are not applied to other domains")
    func codeNamesAreDomainScoped() {
        let ck = FRUSExplorerApp.cloudKitDiagnostic(
            NSError(domain: CKErrorDomain, code: 4, userInfo: [:]))
        let cocoa = FRUSExplorerApp.cloudKitDiagnostic(
            NSError(domain: "NSCocoaErrorDomain", code: 4, userInfo: [:]))

        #expect(ck.codeName == "networkFailure")
        #expect(cocoa.codeName == "code 4")
        #expect(cocoa.message == "NSCocoaErrorDomain code 4")
    }

    @Test("A plain failure records that the app looked for per-item detail")
    func plainFailureRecordsThatItLooked() {
        let diag = FRUSExplorerApp.cloudKitDiagnostic(
            NSError(domain: CKErrorDomain, code: 9, userInfo: [:]))

        #expect(diag.partialCount == nil)
        #expect(diag.histogram == nil)
        #expect(diag.inspection.hadPartialDictionary == false)
        #expect(diag.message == "CKErrorDomain notAuthenticated")
    }

    @Test("The user-facing message carries no schema identifiers or free text")
    func messageStaysClean() {
        let inner = ErrorFixtures.partialFailure(subErrors: [
            (code: 15, count: 1,
             description: "Record 3F2504E0-4F89-11D3 of type 'CD_ResearchNote' rejected"),
        ])
        let diag = FRUSExplorerApp.cloudKitDiagnostic(ErrorFixtures.wrapped(inner))

        #expect(!diag.message.contains("CD_ResearchNote"),
                "the status string a researcher sees stays a plain-language count")
        #expect(!diag.message.contains("3F2504E0"))
    }
}
