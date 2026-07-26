// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CloudKit
import Foundation

// MARK: - CloudKitErrorInspection

/// Everything a CloudKit `NSError` was willing to say, reduced to allow-listed scalars
/// (Wave R-6).
///
/// Nothing here is free text. The only strings that survive are CloudKit **code names** the app
/// itself supplies and **schema identifiers** the app itself defines — see
/// ``CloudKitErrorInspector/schemaIdentifiers(in:)`` for the exact grammar and
/// `SyncDiagnosticsEntry` for the redaction contract this upholds (#188-C.1).
struct CloudKitErrorInspection: Sendable, Equatable {

    /// Whether a `CKPartialErrorsByItemIDKey` dictionary was found **anywhere** in the walked
    /// chain.
    ///
    /// This is the field #488 wanted and did not have. `false` means *the app looked and there
    /// was none*; the absence of the field on a stored row means *this row predates the walk*.
    /// Those two are different facts and the old code could not tell them apart.
    var hadPartialDictionary: Bool = false

    /// How deep the per-item dictionary sat: `0` on the error itself, `1` one
    /// `NSUnderlyingErrorKey` hop down, and so on. `nil` when none was found.
    var partialDictionaryDepth: Int?

    /// How many items the per-item dictionary held (a scalar count, never identifiers).
    /// `0` is meaningful and distinct from `nil`: a dictionary that was present but empty.
    var partialItemCount: Int?

    /// The per-item sub-errors bucketed by CloudKit code, most frequent first, ties broken by
    /// ascending code so two runs over the same failure produce the same dump.
    var subErrorHistogram: [SubErrorBucket]?

    /// Schema identifiers recovered from the error's text, sorted and de-duplicated.
    ///
    /// These are the `CD_RecordType` / `CD_field` / `_pcs_data` tokens the CloudKit server names
    /// when it rejects a record — the single most useful thing in a `partialFailure`, and the
    /// thing #488 had to be reconstructed from the CloudKit Console to learn.
    var schemaIdentifiers: [String] = []

    /// The server's requested back-off in seconds (`CKErrorRetryAfterKey`), when it sent one.
    var retryAfterSeconds: Double?

    /// How many distinct errors the walk actually visited.
    var errorsVisited: Int = 0

    /// Whether the walk stopped at a bound (depth or breadth) rather than exhausting the chain.
    ///
    /// Load-bearing for honesty: a truncated walk that found no dictionary must not be reported
    /// as "there was none", so the dump says which of the two happened.
    var chainTruncated: Bool = false
}

// MARK: - CloudKitErrorInspector

/// Pulls the diagnosable facts out of a CloudKit `NSError` — including the ones that are not at
/// the top level (Wave R-6, issue #488).
///
/// ## The defect this replaces
/// The old `cloudKitDiagnostic(_:)` looked for `CKPartialErrorsByItemIDKey` at exactly one level
/// and, on a miss, fell through to domain + code. A `grep` over the app returned **zero** readers
/// of `NSUnderlyingErrorKey`, `NSMultipleUnderlyingErrorsKey`, `CKErrorRetryAfterKey`, or the
/// server's error text. So when `NSPersistentCloudKitContainer` re-vended #488's failure with the
/// sub-errors one hop down, every channel that could have named the rejected record type was
/// discarded and the log line read `CKErrorDomain partialFailure (2)` and nothing else.
///
/// ## What it does
/// A breadth-first walk of the error graph — `NSUnderlyingErrorKey` and
/// `NSMultipleUnderlyingErrorsKey` — bounded three ways so a malformed or self-referential chain
/// can never hang: ``maxDepth``, ``maxErrorsVisited``, and an identity set that makes a cycle
/// terminate on the second visit. At each node it collects the per-item dictionary (first one
/// wins), the retry-after hint, and schema identifiers.
///
/// ## What it will not do
/// It never returns free text from an `NSError`. `localizedDescription`, failure reasons and
/// `userInfo` strings are **scanned**, never **stored**: only substrings matching the narrow
/// grammar in ``schemaIdentifiers(in:)`` escape. Record names, zone owner ids, e-mail addresses
/// and field values all live in exactly those strings, which is why #188-C.1 forbids passing them
/// through — and why `CloudKitErrorInspectorTests` pins the redaction with an error whose
/// description is nothing but identifiers.
///
/// Deliberately a pure `enum` over `NSError`: no CloudKit account, no container and no network is
/// needed to exercise any of it, so the shapes #488 produced are constructible in a unit test.
enum CloudKitErrorInspector {

    // MARK: Bounds

    /// How many `NSUnderlyingErrorKey` hops the walk will take. Real
    /// `NSPersistentCloudKitContainer` chains are one to three deep; this is slack, not a target.
    static let maxDepth = 6

    /// Hard ceiling on distinct errors visited, so `NSMultipleUnderlyingErrorsKey` fan-out
    /// cannot make the walk quadratic on a batch failure.
    static let maxErrorsVisited = 64

    /// How many of a per-item dictionary's sub-errors are scanned for schema identifiers. Every
    /// sub-error is still **counted** for the histogram; only the text scan is sampled.
    static let maxSubErrorsScanned = 200

    /// Ceiling on reported identifiers. #488 had four; a run of hundreds means something other
    /// than a schema mismatch and the dump should stay readable.
    static let maxSchemaIdentifiers = 12

    // MARK: Inspection

    /// Walks `error` and its underlying-error chain and returns the allow-listed facts.
    ///
    /// - Parameter error: The top-level error, exactly as CloudKit or SwiftData handed it over.
    /// - Returns: An inspection whose ``CloudKitErrorInspection/hadPartialDictionary`` is a real
    ///   answer either way — `false` means the walk completed and found none.
    static func inspect(_ error: NSError) -> CloudKitErrorInspection {
        var result = CloudKitErrorInspection()
        var identifiers: Set<String> = []
        // Identity, not equality: two NSErrors can compare equal without being the same node,
        // and it is *the same node reached twice* that would loop.
        var visited: Set<ObjectIdentifier> = []
        var queue: [(error: NSError, depth: Int)] = [(error, 0)]
        var cursor = 0

        while cursor < queue.count {
            if visited.count >= maxErrorsVisited {
                result.chainTruncated = true
                break
            }
            let (node, depth) = queue[cursor]
            cursor += 1
            guard visited.insert(ObjectIdentifier(node)).inserted else { continue }

            collectSchemaIdentifiers(from: node, into: &identifiers)

            if result.retryAfterSeconds == nil,
               let retry = node.userInfo[CKErrorRetryAfterKey] as? NSNumber {
                result.retryAfterSeconds = retry.doubleValue
            }

            // The keys of this dictionary are `CKRecord.ID`s and are deliberately NEVER read:
            // a record name is a leaky token and the record *type* is not recoverable from it
            // anyway. Only the values (the sub-errors) are inspected.
            if !result.hadPartialDictionary,
               let partial = node.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                result.hadPartialDictionary = true
                result.partialDictionaryDepth = depth
                result.partialItemCount = partial.count
                result.subErrorHistogram = histogram(of: partial, collecting: &identifiers)
            }

            guard depth < maxDepth else {
                result.chainTruncated = true
                continue
            }
            if let under = node.userInfo[NSUnderlyingErrorKey] as? NSError {
                queue.append((under, depth + 1))
            }
            if let multiple = node.userInfo[NSMultipleUnderlyingErrorsKey] as? [Error] {
                if multiple.count > maxErrorsVisited { result.chainTruncated = true }
                for sub in multiple.prefix(maxErrorsVisited) {
                    queue.append((sub as NSError, depth + 1))
                }
            }
        }

        result.errorsVisited = visited.count
        result.schemaIdentifiers = Array(identifiers.sorted().prefix(maxSchemaIdentifiers))
        return result
    }

    // MARK: CloudKit code names

    /// The human name for a CloudKit error code, or `nil` if this app has no name for it.
    ///
    /// Only meaningful for `CKErrorDomain`. Callers must check the domain first: applying this
    /// table to, say, an `NSCocoaErrorDomain` code produces a confident wrong answer, which is
    /// worse than "code 4".
    static func codeName(for code: Int) -> String? { codeNames[code] }

    /// Human-readable labels for the CloudKit error codes most likely to appear in a
    /// SwiftData + CloudKit app during normal operation and schema migration.
    private static let codeNames: [Int: String] = [
        1:  "internalError",
        2:  "partialFailure",
        3:  "networkUnavailable",
        4:  "networkFailure",
        5:  "badContainer",
        6:  "serviceUnavailable",
        7:  "requestRateLimited",
        8:  "missingEntitlement",
        9:  "notAuthenticated",
        10: "permissionFailure",
        11: "unknownItem",
        12: "invalidArguments",
        14: "serverRecordChanged",
        15: "serverRejectedRequest",
        18: "incompatibleVersion",
        19: "constraintViolation",
        20: "operationCancelled",
        21: "changeTokenExpired",
        22: "batchRequestFailed",
        23: "zoneBusy",
        24: "badDatabase",
        25: "quotaExceeded",
        26: "zoneNotFound",
        28: "userDeletedZone",
    ]

    // MARK: Schema identifiers

    /// Extracts CloudKit **schema identifiers** — and nothing else — from arbitrary error text.
    ///
    /// ## The grammar, in full
    /// The text is split into maximal runs of `[A-Za-z0-9_]`. A run is emitted when it either
    /// begins with `CD_` and has something after the underscore, or is exactly `_pcs_data`.
    /// Everything else is dropped on the floor.
    ///
    /// That is deliberately narrower than it looks. `CD_` is the prefix
    /// `NSPersistentCloudKitContainer` puts on every record type and field it mirrors, and
    /// `_pcs_data` is CloudKit's own encrypted-values system field — both are names *this app's
    /// own schema* defines, so publishing them tells an attacker nothing they could not read off
    /// the CloudKit Console. Record names, zone names, owner ids and e-mail addresses cannot
    /// match: a UUID has no underscore, so `CD_` can never begin inside one, and the maximal-run
    /// rule means `someCD_thing` is one run that fails the prefix test rather than two.
    ///
    /// Hand-written rather than a regular expression on purpose: a reviewer checking the
    /// redaction contract can read exactly what escapes, and there is no pattern to "simplify"
    /// into `.*`.
    ///
    /// - Parameter text: Any error text. It is read and discarded; nothing but matches escape.
    /// - Returns: The distinct identifiers found, unordered.
    static func schemaIdentifiers(in text: String) -> Set<String> {
        var found: Set<String> = []
        var run = ""
        run.reserveCapacity(32)

        func flush() {
            defer { run.removeAll(keepingCapacity: true) }
            guard !run.isEmpty else { return }
            if run == "_pcs_data" {
                found.insert(run)
            } else if run.count > 3, run.hasPrefix("CD_") {
                found.insert(run)
            }
        }

        for scalar in text.unicodeScalars {
            if isIdentifierScalar(scalar) {
                run.unicodeScalars.append(scalar)
            } else {
                flush()
            }
        }
        flush()
        return found
    }

    /// Whether a scalar can appear inside a CloudKit schema identifier: ASCII letters, digits,
    /// and the underscore. Anything else terminates the run.
    private static func isIdentifierScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar {
        case "a"..."z", "A"..."Z", "0"..."9", "_": return true
        default: return false
        }
    }

    // MARK: Private

    /// Scans one error's own text for schema identifiers, stopping once the report is full.
    ///
    /// Both `localizedDescription` and the `String`-valued `userInfo` entries are scanned, because
    /// CloudKit puts the server's explanation in different places depending on how the error was
    /// re-vended. Keys are visited in sorted order so a bounded scan is deterministic.
    private static func collectSchemaIdentifiers(from error: NSError, into set: inout Set<String>) {
        guard set.count < maxSchemaIdentifiers else { return }
        set.formUnion(schemaIdentifiers(in: error.localizedDescription))
        let info = error.userInfo
        for key in info.keys.sorted() {
            guard set.count < maxSchemaIdentifiers else { return }
            guard let text = info[key] as? String else { continue }
            set.formUnion(schemaIdentifiers(in: text))
        }
    }

    /// Buckets a per-item dictionary's sub-errors by code, and samples their text for identifiers.
    ///
    /// Every sub-error is counted; only the first ``maxSubErrorsScanned`` are read for text, so a
    /// ten-thousand-record batch failure costs a dictionary walk rather than ten thousand
    /// localisations.
    ///
    /// Buckets are named from the CloudKit table without a domain check, unlike the top-level
    /// error: the values of `CKPartialErrorsByItemIDKey` are `CKError`s by contract, and keying
    /// the bucket on `(domain, code)` instead would change a persisted type for a case that does
    /// not arise.
    private static func histogram(of partial: [AnyHashable: Error],
                                  collecting identifiers: inout Set<String>) -> [SubErrorBucket] {
        var byCode: [Int: Int] = [:]
        var scanned = 0
        for (_, subError) in partial {
            let ns = subError as NSError
            byCode[ns.code, default: 0] += 1
            if scanned < maxSubErrorsScanned, identifiers.count < maxSchemaIdentifiers {
                collectSchemaIdentifiers(from: ns, into: &identifiers)
                scanned += 1
            }
        }
        return byCode
            .map { code, count in
                SubErrorBucket(key: codeName(for: code) ?? "code \(code)", code: code, count: count)
            }
            // Count descending, then code ascending. The old code sorted on count alone, so two
            // buckets of equal size came out in dictionary order — a dump that differed between
            // runs of the same failure.
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.code < $1.code }
    }
}
