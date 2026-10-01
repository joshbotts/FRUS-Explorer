// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CloudKit
import Foundation
import OSLog
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

// MARK: - #1531: what a row records about where it came from

/// The two facts #1531 needed a Sync Log row to carry: which build configuration wrote it (a Debug
/// build's rows describe CloudKit Development), and what this process's own system log named after
/// a failure the error itself could not describe.
@Suite("Sync Log row sources (#1531)")
struct SyncDiagnosticsRowSourceTests {

    private let stamp = ISO8601DateFormatter()

    private func entry(configuration: String? = nil, scanned: Bool? = nil,
                       logIdentifiers: [String]? = nil) -> SyncDiagnosticsEntry {
        SyncDiagnosticsEntry(
            id: UUID(), timestamp: Date(timeIntervalSince1970: 1_790_000_000), phase: "export",
            startDate: nil, endDate: nil, durationSeconds: nil, succeeded: false,
            errorDomain: "CKErrorDomain", errorCode: 2, errorCodeName: "partialFailure",
            partialItemCount: nil, subErrorHistogram: nil, hadPartialDictionary: false,
            buildConfiguration: configuration, systemLogScanned: scanned,
            systemLogSchemaIdentifiers: logIdentifiers,
            appVersion: "2.0", appBuild: "49", osVersion: "Version 26.5", deviceModel: "iPhone18,1")
    }

    @Test("A row says which build configuration wrote it")
    func rowNamesItsConfiguration() {
        let line = SyncDiagnosticsLog.line(for: entry(configuration: "Debug"), stamp: stamp)
        #expect(line.contains("FAILED  Debug"), Comment(rawValue: line))
        #expect(!SyncDiagnosticsLog.line(for: entry(), stamp: stamp).contains("Debug"))
    }

    /// Read and found, read and found nothing, could not read, never tried: four states a reader
    /// must tell apart, the last being every row from before #1531.
    @Test("The system log's four states read differently")
    func systemLogStatesRenderApart() {
        let found = SyncDiagnosticsLog.line(
            for: entry(scanned: true, logIdentifiers: ["CD_GeneratedSummary", "CD_sourceContentHash"]),
            stamp: stamp)
        #expect(found.contains("└ system log: CD_GeneratedSummary, CD_sourceContentHash"))
        let none = SyncDiagnosticsLog.line(for: entry(scanned: true), stamp: stamp)
        #expect(none.contains("└ system log: no schema names"))
        let unreadable = SyncDiagnosticsLog.line(for: entry(scanned: false), stamp: stamp)
        #expect(unreadable.contains("└ system log: could not be read"))
        let untried = SyncDiagnosticsLog.line(for: entry(), stamp: stamp)
        #expect(!untried.contains("system log"))
    }

    /// A failure the system log named is diagnosed, though its error carried nothing — #1531's
    /// exact row, `partialDict=none`, once the log is read.
    @Test("A failure the system log named is not undescribed")
    func systemLogNamesCountAsADiagnosis() {
        #expect(entry(scanned: true).isUndiagnosedFailure)
        #expect(!entry(scanned: true, logIdentifiers: ["CD_sourceContentHash"]).isUndiagnosedFailure)
    }

    /// Through the log's own `record` and its file, read back by a second log on the same file —
    /// the path a row takes from a failed event to the Sync Log a reader exports after relaunching.
    @Test("A recorded row keeps its #1531 fields through the log's file")
    func recordedFieldsSurviveTheFile() async throws {
        let directory = URL.temporaryDirectory.appending(path: "frus-log-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "sync-diagnostics.json")
        await SyncDiagnosticsLog(fileURL: file).record(
            phase: "export", startDate: nil, endDate: .now, succeeded: false,
            errorDomain: "CKErrorDomain", errorCode: 2, errorCodeName: "partialFailure",
            systemLogScanned: true, systemLogSchemaIdentifiers: ["CD_sourceContentHash"])
        let row = try #require(await SyncDiagnosticsLog(fileURL: file).entries().first,
                               "the row did not reach the file")
        #expect(row.buildConfiguration == "Debug", "this Debug test build's row lost its configuration")
        #expect(row.systemLogScanned == true)
        #expect(row.systemLogSchemaIdentifiers == ["CD_sourceContentHash"])
    }
}

// MARK: - SyncEventMonitor (#1531)

/// The observer that now exists from before the container starts.
///
/// ## The defect it replaces
/// The old observer was installed in `bootDownloadManager`, seconds after the container had
/// started, and #1531's export failed 1.3 s into every launch: most launches recorded nothing, and
/// the status stayed idle while sync was stopped. The monitor takes events from the start, keeps
/// what matters without `AppState`, and hands the app everything it held once it attaches.
///
/// `NSPersistentCloudKitContainer.Event` has no public initializer, so these drive `receive(_:)`
/// with snapshots; that the monitor is installed before the container is pinned by
/// `DebugStoreSeparationTests.containerFactoryWiring`. Each test's monitor has its own
/// `UserDefaults` suite and log file, so nothing reaches the device's real memory or Sync Log.
/// Idiom-agnostic.
@Suite("Sync event monitor (#1531)")
@MainActor
struct SyncEventMonitorTests {

    private struct Fixture {
        let monitor: SyncEventMonitor
        let defaults: UserDefaults
        let suite: String
        let log: SyncDiagnosticsLog
        let directory: URL

        /// Removes the log's directory and the `UserDefaults` suite, so no test leaves a
        /// `frus.test.<uuid>` preferences file behind in the test host.
        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
    }

    private func makeFixture(scans: Bool = false, delay: Duration = .zero) throws -> Fixture {
        let suite = "frus.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let directory = URL.temporaryDirectory.appending(path: "frus-monitor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let log = SyncDiagnosticsLog(fileURL: directory.appending(path: "sync-diagnostics.json"))
        let monitor = SyncEventMonitor(center: NotificationCenter(), defaults: defaults,
                                       configuration: .debug, log: log,
                                       scansSystemLog: scans, scanDelay: delay)
        return Fixture(monitor: monitor, defaults: defaults, suite: suite, log: log,
                       directory: directory)
    }

    /// A failed export or import ending `seconds` after `base` — real dates, so a system-log read
    /// starts near the present instead of walking this process's whole log.
    private func failure(_ phase: String, at base: Date, plus seconds: TimeInterval = 0)
        -> SyncEventSnapshot {
        SyncEventSnapshot(phase: phase, hasEnded: true, succeeded: false,
                          startDate: base.addingTimeInterval(seconds),
                          endDate: base.addingTimeInterval(seconds),
                          diagnostic: FRUSExplorerApp.cloudKitDiagnostic(partialFailure))
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func event(_ phase: String, ended: Bool = true, succeeded: Bool = true,
                       at offset: TimeInterval = 0, error: NSError? = nil) -> SyncEventSnapshot {
        SyncEventSnapshot(phase: phase, hasEnded: ended, succeeded: succeeded,
                          startDate: start.addingTimeInterval(offset),
                          endDate: start.addingTimeInterval(offset + 1),
                          diagnostic: error.map { FRUSExplorerApp.cloudKitDiagnostic($0) })
    }

    private var partialFailure: NSError { NSError(domain: CKErrorDomain, code: 2) }

    /// #1531's launch: setup, then the export that fails, then an import — all before `AppState`
    /// exists. The app must receive every one, in order, when it attaches, and then each new one.
    @Test("Events before attach are held and replayed in order; later ones go straight through")
    func heldEventsReplayInOrder() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let monitor = fixture.monitor
        monitor.receive(event("setup"))
        monitor.receive(event("export", succeeded: false, at: 1, error: partialFailure))
        monitor.receive(event("import", at: 2))
        #expect(monitor.pending.map(\.phase) == ["setup", "export", "import"])

        var delivered: [String] = []
        monitor.attach(memory: { _ in }, events: { delivered.append($0.phase) })
        #expect(delivered == ["setup", "export", "import"],
                "the app missed or reordered what happened before it attached")
        #expect(monitor.pending.isEmpty)
        monitor.receive(event("export", at: 3))
        #expect(delivered == ["setup", "export", "import", "export"])
    }

    /// The first failure of a launch is remembered with no `AppState` at all — the fact the next
    /// launch's "Sync Stopped" stands on — and only a successful EXPORT ends it.
    @Test("A failed export is remembered before the app attaches; only a successful one ends it")
    func failureIsRememberedWithoutTheApp() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        fixture.monitor.receive(event("export", succeeded: false, error: partialFailure))
        let run = try #require(SyncExportFailureMemory.load(defaults: fixture.defaults,
                                                            configuration: .debug),
                               "a failure before the app attached was not remembered")
        #expect(run.firstLaunchID == SyncExportFailureMemory.currentLaunchID)
        #expect(run.message == "CKErrorDomain partialFailure")
        #expect(SyncExportFailureMemory.load(defaults: fixture.defaults, configuration: .release) == nil)

        fixture.monitor.receive(event("import", at: 5))
        #expect(SyncExportFailureMemory.load(defaults: fixture.defaults, configuration: .debug) != nil,
                "a successful IMPORT ended an upload failure")
        fixture.monitor.receive(event("export", ended: false, at: 6))
        #expect(SyncExportFailureMemory.load(defaults: fixture.defaults, configuration: .debug) != nil,
                "an upload merely STARTING ended the failure")
        fixture.monitor.receive(event("export", at: 7))
        #expect(SyncExportFailureMemory.load(defaults: fixture.defaults, configuration: .debug) == nil)
    }

    /// Attaching hands the app the remembered run at once — a run from an EARLIER launch, before
    /// any event of this one, is what shows "Sync Stopped" as soon as the app attaches.
    @Test("Attaching hands the app the remembered run at once, and every change after")
    func attachDeliversTheMemory() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let earlier = UUID()
        SyncExportFailureMemory.recordExport(succeeded: false, at: start, message: "m",
                                             schemaIdentifiers: nil, launchID: earlier,
                                             defaults: fixture.defaults, configuration: .debug)
        var seen: [UnrecoveredExport?] = []
        fixture.monitor.attach(memory: { seen.append($0) }, events: { _ in })
        #expect(seen.count == 1)
        #expect(seen.first??.firstLaunchID == earlier)
        fixture.monitor.receive(event("export"))
        #expect(seen.count == 2)
        #expect(seen.last.map { $0 == nil } == true, "the app was not told the upload recovered")
    }

    /// The app's side: `bootDownloadManager` attaches to the monitor and no longer installs a late
    /// observer of its own — the one that missed #1531's failure. Read with comments and strings
    /// masked, so the doc comments that tell the story cannot satisfy or trip it.
    @Test("The app attaches to the monitor and keeps no late observer of its own")
    func appAttachesInsteadOfObserving() throws {
        let code = String(decoding: CodingStandardsAuditTests.maskedCode(
            try DebugStoreSeparationTests.appSource("FRUSExplorer/App/FRUSExplorerApp.swift")),
            as: UTF8.self)
        #expect(code.contains("SyncEventMonitor.shared.attach("),
                "the app never attaches, so events after boot reach no AppState")
        #expect(!code.contains("eventChangedNotification"),
                "FRUSExplorerApp observes sync events itself again, after the container has started")
        #expect(code.filter { !$0.isWhitespace }.contains("memory:{[appState]runinappState.unrecoveredExport=run}"),
                "the remembered run no longer reaches AppState")
    }

    /// The else branch of attaching: a container that fell back to local-only sends no events, but
    /// an earlier launch's unsent changes are still in the mirrored store, which Fix iCloud Sync
    /// clears — so a REAL fallback reads the remembered run for the warning. A test or preview
    /// launch, which skips CloudKit with no error, must not.
    @Test("A real container fallback reads the remembered run; a skipped one does not")
    func fallbackReadsTheRun() throws {
        let source = try DebugStoreSeparationTests.appSource("FRUSExplorer/App/FRUSExplorerApp.swift")
        let fallback = try #require(DebugStoreSeparationTests.functionBody(
            "if let initError = _containerSetup.initError", in: source),
            "the container-fallback branch is not where this test looks")
        #expect(fallback.filter { !$0.isWhitespace }
                    .contains("appState.unrecoveredExport=SyncExportFailureMemory.load()"),
                "a real fallback no longer reads the remembered run, so Fix iCloud Sync would not warn")
        let code = String(decoding: CodingStandardsAuditTests.maskedCode(source), as: UTF8.self)
        #expect(code.components(separatedBy: "SyncExportFailureMemory.load()").count - 1 == 1,
                "the remembered run is read somewhere else too — a test launch could pick it up")
    }

    @Test("Past the pending limit the oldest held events go, and are counted")
    func pendingIsBounded() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        for index in 0..<(SyncEventMonitor.pendingLimit + 3) {
            fixture.monitor.receive(event("import", ended: false, at: TimeInterval(index)))
        }
        #expect(fixture.monitor.pending.count == SyncEventMonitor.pendingLimit)
        #expect(fixture.monitor.droppedBeforeAttach == 3)
        #expect(fixture.monitor.pending.first?.startDate == start.addingTimeInterval(3))
    }

    /// Every ended event gets a row, in arrival order, marked with the build configuration; a
    /// started event gets none, as before #1531.
    @Test("Ended events are logged in order with their configuration; started ones are not")
    func rowsAreFiledInOrder() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        fixture.monitor.receive(event("setup", ended: false))
        fixture.monitor.receive(event("export", succeeded: false, at: 1, error: partialFailure))
        fixture.monitor.receive(event("export", at: 2))
        await fixture.monitor.waitForRows()
        let rows = await fixture.log.entries()
        #expect(rows.map(\.phase) == ["export", "export"])
        #expect(rows.map(\.succeeded) == [false, true])
        #expect(rows.allSatisfy { $0.buildConfiguration == "Debug" })
        #expect(rows.first?.errorCodeName == "partialFailure")
        #expect(rows.allSatisfy { $0.systemLogScanned == nil },
                "a monitor told not to read the system log read it")
    }

    /// The end-to-end channel #1531 lacked: a Core Data error line naming a field, in THIS
    /// process's own log, reaches the failed row and the remembered run. The line is written with
    /// a test subsystem under `com.apple.coredata` at error level, the shape Core Data's own fatal
    /// export errors take; the scan is read until the line has reached the log store, so the
    /// monitor's own read cannot race it.
    @Test("A failure's row and remembered run carry what this process's system log named")
    func systemLogReachesTheRowAndTheRun() async throws {
        let fixture = try makeFixture(scans: true, delay: .milliseconds(50))
        defer { fixture.cleanUp() }
        let failedAt = Date.now
        Logger(subsystem: "com.apple.coredata.frus-test", category: "cloudkit").error(
            "Export failed: Cannot create or modify field 'CD_frusTestField' in record 'CD_FRUSTestRecord' in production schema")
        var found: [String]? = nil
        for _ in 0..<40 {
            found = SystemLogSchemaScan.scanCurrentProcess(from: failedAt, to: Date.now)
            if found?.contains("CD_frusTestField") == true { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        #expect(found?.contains("CD_frusTestField") == true,
                "this process's own log never showed the line — OSLogStore is unreadable here")

        var memory: UnrecoveredExport?
        fixture.monitor.attach(memory: { memory = $0 }, events: { _ in })
        fixture.monitor.receive(SyncEventSnapshot(
            phase: "export", hasEnded: true, succeeded: false, startDate: failedAt,
            endDate: Date.now, diagnostic: FRUSExplorerApp.cloudKitDiagnostic(partialFailure)))
        await fixture.monitor.waitForRows()
        let row = try #require(await fixture.log.entries().last)
        #expect(row.systemLogScanned == true)
        #expect(row.systemLogSchemaIdentifiers?.contains("CD_FRUSTestRecord") == true)
        #expect(row.systemLogSchemaIdentifiers?.contains("CD_frusTestField") == true)
        #expect(row.isUndiagnosedFailure == false)
        #expect(memory?.schemaIdentifiers?.contains("CD_frusTestField") == true,
                "the remembered run did not take up what the log named")
    }

    /// The order promise, with the wait it is about. A failed row waits for the system log (2 s
    /// and a log walk in the app) and a success right after it does not, so without the chain the
    /// success would be filed first — and an exported Sync Log, read newest-first, would show the
    /// failure as the latest news. `rowsAreFiledInOrder` cannot see this: its monitor reads no log,
    /// so no row ever waits.
    @Test("A failed row waiting on the system log is still filed before the success after it")
    func aWaitingFailedRowKeepsItsPlace() async throws {
        let fixture = try makeFixture(scans: true, delay: .milliseconds(500))
        defer { fixture.cleanUp() }
        let now = Date.now
        fixture.monitor.receive(failure("export", at: now))
        fixture.monitor.receive(SyncEventSnapshot(phase: "export", hasEnded: true, succeeded: true,
                                                  startDate: now.addingTimeInterval(0.1),
                                                  endDate: now.addingTimeInterval(0.2),
                                                  diagnostic: nil))
        await fixture.monitor.waitForRows()
        let rows = await fixture.log.entries()
        #expect(rows.map(\.succeeded) == [false, true],
                "the success was filed before the failure that preceded it")
        #expect(rows.first?.systemLogScanned != nil,
                "fixture guard: the failed row read no system log, so it never waited")
    }

    /// One read per `scanInterval`: a burst of failures must not cost a burst of log walks. The
    /// second failure, 10 s after the first, is filed without a read; the third, 31 s after the
    /// first, reads again. The interval runs from the last READ, by the events' own end dates.
    @Test("A failure within 30 s of the last system-log read does not read it again")
    func systemLogReadsAreSpaced() async throws {
        #expect(SyncEventMonitor.scanInterval == 30, "fixture guard: the dates below assume 30 s")
        let fixture = try makeFixture(scans: true)
        defer { fixture.cleanUp() }
        let now = Date.now
        fixture.monitor.receive(failure("export", at: now))
        fixture.monitor.receive(failure("import", at: now, plus: 10))
        fixture.monitor.receive(failure("export", at: now, plus: 31))
        await fixture.monitor.waitForRows()
        let rows = await fixture.log.entries()
        #expect(rows.map { $0.systemLogScanned != nil } == [true, false, true],
                "the system log was read for the wrong failures: \(rows.map(\.systemLogScanned))")
    }

    /// What the system log names after a failed IMPORT is filed on that import's row, but it does
    /// not join the remembered upload failure: the run is about changes that never left this
    /// device, and a download's failure says nothing about which of them iCloud refused.
    @Test("A failed import's system-log names stay on its row and out of the upload failure")
    func importScanDoesNotJoinTheRun() async throws {
        let fixture = try makeFixture(scans: true, delay: .milliseconds(50))
        defer { fixture.cleanUp() }
        SyncExportFailureMemory.recordExport(succeeded: false, at: .now, message: "m",
                                             schemaIdentifiers: nil, defaults: fixture.defaults,
                                             configuration: .debug)
        let failedAt = Date.now
        Logger(subsystem: "com.apple.coredata.frus-test", category: "cloudkit").error(
            "Import failed: Cannot create or modify field 'CD_frusImportField' in record 'CD_FRUSImportRecord' in production schema")
        var found: [String]? = nil
        for _ in 0..<40 {
            found = SystemLogSchemaScan.scanCurrentProcess(from: failedAt, to: Date.now)
            if found?.contains("CD_frusImportField") == true { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        #expect(found?.contains("CD_frusImportField") == true,
                "fixture guard: this process's own log never showed the line")

        fixture.monitor.receive(SyncEventSnapshot(
            phase: "import", hasEnded: true, succeeded: false, startDate: failedAt,
            endDate: Date.now, diagnostic: FRUSExplorerApp.cloudKitDiagnostic(partialFailure)))
        await fixture.monitor.waitForRows()
        let row = try #require(await fixture.log.entries().last)
        #expect(row.systemLogSchemaIdentifiers?.contains("CD_frusImportField") == true,
                "fixture guard: the import's own row did not get what the log named")
        let run = try #require(SyncExportFailureMemory.load(defaults: fixture.defaults,
                                                            configuration: .debug))
        #expect(run.schemaIdentifiers == nil,
                "a failed import's system-log names joined the remembered upload failure")
    }
}
