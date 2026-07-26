// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - SyncDiagnosticsEntryTests

/// Tests the stored sync-telemetry row and the readable dump built from it (Wave R-6).
///
/// Two things are pinned here that nothing else can catch:
/// 1. **Backward-compatible decoding.** `SyncDiagnosticsLog.loaded()` swallows a decode failure
///    with `try?` and returns `[]`. A non-optional field added to `SyncDiagnosticsEntry` would
///    therefore not fail loudly — it would silently erase every row already on disk, which is the
///    history an owner pastes into an issue.
/// 2. **The three states of "did we look?"** rendered distinguishably in the dump.
struct SyncDiagnosticsEntryTests {

    private let stamp = ISO8601DateFormatter()

    /// Builds a row with the R-6 fields left at their defaults unless named.
    private func entry(errorDomain: String? = "CKErrorDomain",
                       errorCode: Int? = 2,
                       errorCodeName: String? = "partialFailure",
                       partialItemCount: Int? = nil,
                       subErrorHistogram: [SubErrorBucket]? = nil,
                       hadPartialDictionary: Bool? = nil,
                       partialDictionaryDepth: Int? = nil,
                       schemaIdentifiers: [String]? = nil,
                       retryAfterSeconds: Double? = nil,
                       chainTruncated: Bool? = nil) -> SyncDiagnosticsEntry {
        SyncDiagnosticsEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            phase: "export",
            startDate: nil,
            endDate: nil,
            durationSeconds: nil,
            succeeded: false,
            errorDomain: errorDomain,
            errorCode: errorCode,
            errorCodeName: errorCodeName,
            partialItemCount: partialItemCount,
            subErrorHistogram: subErrorHistogram,
            hadPartialDictionary: hadPartialDictionary,
            partialDictionaryDepth: partialDictionaryDepth,
            schemaIdentifiers: schemaIdentifiers,
            retryAfterSeconds: retryAfterSeconds,
            chainTruncated: chainTruncated,
            appVersion: "2.0",
            appBuild: "36",
            osVersion: "Version 26.0",
            deviceModel: "iPhone17,1")
    }

    // MARK: Decoding

    /// A file written by a build that predates the R-6 fields. If this ever throws, the whole log
    /// disappears the next time anyone opens Sync Diagnostics.
    @Test("A row written before the R-6 fields existed still decodes")
    func legacyRowDecodes() throws {
        let legacy = """
            [{
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "timestamp": "2026-07-20T12:00:00Z",
              "phase": "export",
              "succeeded": false,
              "errorDomain": "CKErrorDomain",
              "errorCode": 2,
              "errorCodeName": "partialFailure",
              "appVersion": "2.0",
              "appBuild": "35",
              "osVersion": "Version 26.0",
              "deviceModel": "iPhone17,1"
            }]
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([SyncDiagnosticsEntry].self,
                                      from: Data(legacy.utf8))

        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.errorCodeName == "partialFailure")
        #expect(row.hadPartialDictionary == nil, "an old row must not claim the app looked")
        #expect(row.schemaIdentifiers == nil)
        #expect(row.retryAfterSeconds == nil)
        #expect(row.chainTruncated == nil)
    }

    @Test("A row with the R-6 fields round-trips")
    func roundTrip() throws {
        let original = entry(partialItemCount: 4,
                             subErrorHistogram: [SubErrorBucket(key: "invalidArguments",
                                                                code: 12, count: 4)],
                             hadPartialDictionary: true,
                             partialDictionaryDepth: 1,
                             schemaIdentifiers: ["CD_Project", "CD_ProjectLeadEntry"],
                             retryAfterSeconds: 30)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SyncDiagnosticsEntry.self,
                                        from: encoder.encode(original))

        #expect(decoded.hadPartialDictionary == true)
        #expect(decoded.partialDictionaryDepth == 1)
        #expect(decoded.schemaIdentifiers == ["CD_Project", "CD_ProjectLeadEntry"])
        #expect(decoded.retryAfterSeconds == 30)
    }

    // MARK: The undescribed-failure test

    /// #488's row exactly: a failure with a domain, a code, and nothing else.
    @Test("A failure with no sub-errors and no identifiers counts as undescribed")
    func undiagnosedFailure() {
        #expect(entry(hadPartialDictionary: false).isUndiagnosedFailure)
        #expect(entry(partialItemCount: 0,
                      subErrorHistogram: [],
                      hadPartialDictionary: true).isUndiagnosedFailure,
                "a dictionary that was present but empty describes nothing either")
    }

    @Test("A failure that names sub-errors or a record type is described")
    func diagnosedFailure() {
        #expect(!entry(partialItemCount: 4,
                       subErrorHistogram: [SubErrorBucket(key: "invalidArguments", code: 12, count: 4)],
                       hadPartialDictionary: true).isUndiagnosedFailure)
        #expect(!entry(hadPartialDictionary: false,
                       schemaIdentifiers: ["CD_ProjectLeadEntry"]).isUndiagnosedFailure)
    }

    @Test("A successful row is not an undescribed failure")
    func successIsNotUndiagnosed() {
        #expect(!entry(errorDomain: nil, errorCode: nil, errorCodeName: nil).isUndiagnosedFailure)
    }

    /// The health checks record a code *name* without a code. The summary does not count those as
    /// errors, so this must not count them as undescribed ones — or the "with no detail" count
    /// could exceed the error count it qualifies.
    @Test("A health-check row with no error code is not counted")
    func healthCheckRowIsNotUndiagnosed() {
        #expect(!entry(errorDomain: nil, errorCode: nil,
                       errorCodeName: "accountStatus(3)").isUndiagnosedFailure)
    }

    // MARK: The dump

    @Test("A found dictionary reports its depth")
    func dumpShowsDepth() {
        let line = SyncDiagnosticsLog.line(
            for: entry(partialItemCount: 4, hadPartialDictionary: true, partialDictionaryDepth: 1),
            stamp: stamp)
        #expect(line.contains("partial=4@depth 1"))
    }

    /// The distinction the whole item exists for.
    @Test("Looked-and-found-none, truncated, and never-looked all read differently")
    func dumpDistinguishesTheThreeStates() {
        let looked = SyncDiagnosticsLog.line(for: entry(hadPartialDictionary: false), stamp: stamp)
        let truncated = SyncDiagnosticsLog.line(
            for: entry(hadPartialDictionary: false, chainTruncated: true), stamp: stamp)
        let legacy = SyncDiagnosticsLog.line(for: entry(), stamp: stamp)

        #expect(looked.contains("no per-item errors in chain"))
        #expect(truncated.contains("chain truncated"))
        #expect(!legacy.contains("no per-item errors"),
                "a row written before the walk existed must not claim the app looked")
        #expect(looked != truncated)
        #expect(looked != legacy)
    }

    @Test("Schema identifiers and the retry hint appear in the dump")
    func dumpShowsIdentifiersAndRetry() {
        let line = SyncDiagnosticsLog.line(
            for: entry(partialItemCount: 3,
                       subErrorHistogram: [SubErrorBucket(key: "invalidArguments", code: 12, count: 3)],
                       hadPartialDictionary: true,
                       partialDictionaryDepth: 0,
                       schemaIdentifiers: ["CD_Project", "CD_leadAxisWeights"],
                       retryAfterSeconds: 30),
            stamp: stamp)

        #expect(line.contains("3× invalidArguments"))
        #expect(line.contains("schema: CD_Project, CD_leadAxisWeights"))
        #expect(line.contains("retry-after=30s"))
    }

    @Test("A row with no R-6 fields renders as it always did")
    func legacyRowRendersUnchanged() {
        let line = SyncDiagnosticsLog.line(for: entry(), stamp: stamp)
        #expect(line.contains("export"))
        #expect(line.contains("FAILED"))
        #expect(line.contains("CKErrorDomain partialFailure (2)"))
        #expect(!line.contains("schema:"))
        #expect(!line.contains("retry-after"))
    }
}
