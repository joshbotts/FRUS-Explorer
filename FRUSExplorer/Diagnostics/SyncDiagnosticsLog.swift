// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreData       // NSPersistentCloudKitContainer's sync events (SyncEventMonitor, #1531)
import Foundation

// MARK: - SubErrorBucket

/// One bucket of a CloudKit `partialFailure`'s per-item sub-errors, aggregated by error kind
/// (#188-C.1). The key is the sub-error's CloudKit **code name** — never a record identifier —
/// so the histogram diagnoses *which kind of failure and how many* without leaking any identity.
struct SubErrorBucket: Codable, Sendable, Hashable {
    /// The CloudKit sub-error code name (e.g. `"serverRecordChanged"`), or `"code N"` if unknown.
    let key: String
    /// The numeric CloudKit sub-error code.
    let code: Int
    /// How many failed items reported this code.
    let count: Int
}

// MARK: - SyncDiagnosticsEntry

/// A single **redacted** CloudKit sync-telemetry row (#188-C.1). Built field-by-field from an
/// explicit allow-list — never by serializing a raw `NSError`/`userInfo`/`CKRecord` — so it can
/// never carry user-identifying data or synced content.
///
/// Recorded (safe): event phase, timing, success, error domain/code/code-name, a
/// `(codeName, code) → count` histogram of a `partialFailure`'s sub-errors, the app's own
/// CloudKit schema identifiers recovered from the server text, and coarse environment (app
/// version/build, OS, device-model class). **Never** recorded: record names/IDs, zone/owner
/// identifiers, emails, field values, `localizedDescription`, or any free text that could embed
/// an identifier.
///
/// ## Adding a field
/// Every property added after 1.0 **must** be optional. `SyncDiagnosticsLog.loaded()` swallows a
/// decode failure with `try?` and falls back to `[]`, so a non-optional addition would silently
/// erase the entire on-disk history the first time an old file was read — the very history the
/// owner pastes into an issue. Optional properties decode with `decodeIfPresent`, so a file
/// written by an older build still round-trips; `SyncDiagnosticsEntryTests` pins that.
///
/// Version history:
///   1.0 — #188-C.1: initial implementation
///   1.1 — Wave R-6: `hadPartialDictionary`, `partialDictionaryDepth`, `schemaIdentifiers`,
///          `retryAfterSeconds`, `chainTruncated` — the channels #488 discarded
///   1.2 — #1531: `buildConfiguration` (a Debug build's rows describe CloudKit Development), and
///          `systemLogScanned` / `systemLogSchemaIdentifiers` — what this process's own system log
///          named after a failed event, which the error itself did not carry
struct SyncDiagnosticsEntry: Codable, Sendable, Identifiable {
    /// A freshly generated local row id — NOT the CloudKit event's identifier.
    let id: UUID
    /// When this row was recorded.
    let timestamp: Date
    /// The event phase: `"setup"`/`"import"`/`"export"` (container events) or
    /// `"account"`/`"zone"`/`"init"` (health checks).
    let phase: String
    /// The container event's start time (nil for health checks).
    let startDate: Date?
    /// The container event's end time (nil for in-progress or health checks).
    let endDate: Date?
    /// `endDate − startDate` when both are present.
    let durationSeconds: Double?
    /// Whether the event/check succeeded.
    let succeeded: Bool
    /// The top-level error's domain (e.g. `CKErrorDomain`), when there was an error.
    let errorDomain: String?
    /// The top-level error's numeric code.
    let errorCode: Int?
    /// The top-level error's human code name, when known.
    let errorCodeName: String?
    /// For a `partialFailure`: how many items failed (a scalar count, not identifiers).
    let partialItemCount: Int?
    /// For a `partialFailure`: the per-item sub-errors bucketed by code name.
    let subErrorHistogram: [SubErrorBucket]?
    /// Whether a `CKPartialErrorsByItemIDKey` dictionary was found anywhere in the error chain
    /// (Wave R-6). `false` means *looked, found none*; `nil` means the row predates the walk.
    var hadPartialDictionary: Bool? = nil
    /// How many `NSUnderlyingErrorKey` hops down that dictionary sat — `0` for the top-level
    /// error. `nil` when none was found or the row predates the walk.
    var partialDictionaryDepth: Int? = nil
    /// The `CD_…` / `_pcs_data` schema identifiers named in the server's error text. These are
    /// names this app's own schema defines — never record names or field values.
    var schemaIdentifiers: [String]? = nil
    /// The server's requested back-off in seconds (`CKErrorRetryAfterKey`), when it sent one.
    var retryAfterSeconds: Double? = nil
    /// Whether the error-chain walk stopped at a bound instead of exhausting the chain, so a
    /// bounded walk that found nothing is not mistaken for an absence.
    var chainTruncated: Bool? = nil
    /// The build configuration that recorded the row — `"Debug"` or `"Release"`
    /// (``FRUSStoreConfiguration/logLabel``). A Debug build talks to CloudKit's Development
    /// environment, so its rows say nothing about Production (#1531). `nil` on rows from before 1.2.
    var buildConfiguration: String? = nil
    /// Whether this process's system log was read after the event (#1531): `true` read, `false`
    /// tried and could not be opened, `nil` not tried (a success, a rate-limited repeat, or a row
    /// from before 1.2).
    var systemLogScanned: Bool? = nil
    /// The `CD_…` schema identifiers that log named around the event, through the same allow-list
    /// as ``schemaIdentifiers`` (``SystemLogSchemaScan``); `nil` when it named none or was not read.
    var systemLogSchemaIdentifiers: [String]? = nil
    /// App marketing version (`CFBundleShortVersionString`).
    let appVersion: String
    /// App build number (`CFBundleVersion`).
    let appBuild: String
    /// Coarse OS version string.
    let osVersion: String
    /// Device model *class* (e.g. `iPhone16,2`) — not a serial or per-device identifier.
    let deviceModel: String
}

extension SyncDiagnosticsEntry {

    /// Whether this row records a failure the app could not describe beyond a domain and a code
    /// (Wave R-6).
    ///
    /// This is #488's log line exactly: `CKErrorDomain partialFailure (2)` with no sub-errors and
    /// no schema identifiers — a row that *looks* like every other failed row in the Data &
    /// Recovery summary but tells the reader nothing. Rows written before R-6 are undiagnosed by
    /// definition, and this correctly says so.
    ///
    /// The `errorCode` guard is deliberately the same test the Data & Recovery summary uses for
    /// "this row is an error", so the undescribed count can never exceed the error count. The
    /// health-check rows that carry only an `errorCodeName` (`accountStatus(3)`) are not errors by
    /// that definition and are not counted here either.
    var isUndiagnosedFailure: Bool {
        guard errorCode != nil else { return false }
        return (subErrorHistogram ?? []).isEmpty && (schemaIdentifiers ?? []).isEmpty
            && (systemLogSchemaIdentifiers ?? []).isEmpty
    }
}

// MARK: - SyncDiagnosticsLog

/// A local-only, bounded ring buffer of redacted CloudKit sync-telemetry rows (#188-C.1), so a
/// tester can export their device's sync history (via Settings → Sync Diagnostics) to complement
/// the server-side CloudKit Console logs.
///
/// Persisted to a JSON file in **Application Support**, entirely outside the SwiftData /
/// `NSPersistentCloudKitContainer` store — so it is local-only by construction and never syncs.
/// An `actor` so recording, ring-trimming, and disk I/O stay off the main thread and serialized.
///
/// Every stored field is on the `SyncDiagnosticsEntry` allow-list; this type has no path to
/// record identifiers, zone/owner names, or synced content.
actor SyncDiagnosticsLog {

    /// The shared app-wide log.
    static let shared = SyncDiagnosticsLog()

    /// Where this log persists — ``defaultFileURL`` for the shared log, a scratch file for a test.
    private let fileURL: URL?

    /// A log persisted at `fileURL`. The app uses ``shared``; a test passes a file of its own so
    /// nothing it records reaches the durable log.
    init(fileURL: URL? = SyncDiagnosticsLog.defaultFileURL) {
        self.fileURL = fileURL
    }

    /// Maximum rows retained; older rows are dropped (ring buffer).
    private let maxEntries = 200

    /// In-memory copy of the persisted rows, loaded lazily on first access.
    private var cache: [SyncDiagnosticsEntry]?

    // MARK: Persistence location

    /// The durable log file in Application Support (never Caches — the OS may purge Caches).
    /// `nil` only if the directory can't be resolved/created, in which case the log is a no-op.
    static let defaultFileURL: URL? = {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("FRUSExplorer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sync-diagnostics.json")
    }()

    // MARK: Coarse environment (constant per run; captured once)

    /// App marketing version.
    private static let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    /// App build number.
    private static let appBuild =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    /// Coarse OS version.
    private static let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    /// Device model class (e.g. `iPhone16,2` / `Mac15,3`) — a hardware class, not a serial.
    private static let deviceModel: String = {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            let ptr = raw.bindMemory(to: CChar.self).baseAddress!
            return String(cString: ptr)
        }
    }()

    // MARK: Recording

    /// Records one redacted telemetry row from already-extracted, allow-listed scalars. Callers
    /// (which run on `@MainActor` near the CloudKit event) decompose the event/error into these
    /// Sendable values first, so no `NSError`/`Event` ever crosses into the actor.
    func record(
        phase: String,
        startDate: Date?,
        endDate: Date?,
        succeeded: Bool,
        errorDomain: String? = nil,
        errorCode: Int? = nil,
        errorCodeName: String? = nil,
        partialItemCount: Int? = nil,
        subErrorHistogram: [SubErrorBucket]? = nil,
        hadPartialDictionary: Bool? = nil,
        partialDictionaryDepth: Int? = nil,
        schemaIdentifiers: [String]? = nil,
        retryAfterSeconds: Double? = nil,
        chainTruncated: Bool? = nil,
        systemLogScanned: Bool? = nil,
        systemLogSchemaIdentifiers: [String]? = nil
    ) {
        let duration: Double? = (startDate != nil && endDate != nil)
            ? endDate!.timeIntervalSince(startDate!) : nil
        let entry = SyncDiagnosticsEntry(
            id: UUID(),
            timestamp: Date(),
            phase: phase,
            startDate: startDate,
            endDate: endDate,
            durationSeconds: duration,
            succeeded: succeeded,
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
            buildConfiguration: FRUSStoreConfiguration.current.logLabel,
            systemLogScanned: systemLogScanned,
            systemLogSchemaIdentifiers: systemLogSchemaIdentifiers,
            appVersion: Self.appVersion,
            appBuild: Self.appBuild,
            osVersion: Self.osVersion,
            deviceModel: Self.deviceModel
        )
        var all = loaded()
        all.append(entry)
        if all.count > maxEntries { all = Array(all.suffix(maxEntries)) }
        cache = all
        persist(all)
    }

    // MARK: Reading / export

    /// All retained rows, oldest first.
    func entries() -> [SyncDiagnosticsEntry] { loaded() }

    /// A human-readable, allow-list-only plain-text dump for on-screen display and clipboard.
    func formattedText() -> String {
        let rows = loaded()
        guard !rows.isEmpty else {
            return "No CloudKit sync events recorded yet.\n\(envHeader())"
        }
        var lines: [String] = [envHeader(), ""]
        let stamp = ISO8601DateFormatter()
        for e in rows.reversed() {  // newest first for reading
            lines.append(Self.line(for: e, stamp: stamp))
        }
        return lines.joined(separator: "\n")
    }

    /// Renders one row of the readable dump.
    ///
    /// Split out of ``formattedText()`` and `nonisolated` so the wording can be tested against a
    /// constructed entry, without the actor, the durable file, or an Application Support
    /// directory. Before Wave R-6 nothing in either test target touched this type at all.
    ///
    /// The Wave R-6 fields are rendered so that the three states an owner must tell apart are
    /// visibly different in the text they paste into an issue:
    /// - `partial=N@depth D` — the per-item dictionary was found, and where.
    /// - `no per-item errors in chain` — the walk completed and there were none.
    /// - neither — the row predates the walk, so the app genuinely does not know.
    nonisolated static func line(for e: SyncDiagnosticsEntry,
                                 stamp: ISO8601DateFormatter) -> String {
        var parts = ["[\(stamp.string(from: e.timestamp))]",
                     e.phase,
                     e.succeeded ? "ok" : "FAILED"]
        // #1531: a Debug build's rows describe CloudKit Development, never Production — the one
        // fact that would have told the owner the 02:20 "export ok" rows were not the shipped app's.
        if let configuration = e.buildConfiguration { parts.append(configuration) }
        if let d = e.durationSeconds { parts.append(String(format: "%.1fs", d)) }
        if let dom = e.errorDomain, let code = e.errorCode {
            parts.append("\(dom) \(e.errorCodeName ?? "code \(code)") (\(code))")
        }
        if let n = e.partialItemCount {
            parts.append(e.partialDictionaryDepth.map { "partial=\(n)@depth \($0)" }
                         ?? "partial=\(n)")
        } else if e.hadPartialDictionary == false {
            parts.append(e.chainTruncated == true
                         ? "no per-item errors found (chain truncated)"
                         : "no per-item errors in chain")
        }
        if let retry = e.retryAfterSeconds {
            parts.append(String(format: "retry-after=%.0fs", retry))
        }
        var line = parts.joined(separator: "  ")
        if let hist = e.subErrorHistogram, !hist.isEmpty {
            let breakdown = hist.map { "\($0.count)× \($0.key)" }.joined(separator: ", ")
            line += "\n    └ \(breakdown)"
        }
        if let ids = e.schemaIdentifiers, !ids.isEmpty {
            line += "\n    └ schema: \(ids.joined(separator: ", "))"
        }
        // #1531: what this process's own log named, kept apart from what the error named so the
        // reader can tell the two sources apart.
        switch e.systemLogScanned {
        case true?:
            let ids = e.systemLogSchemaIdentifiers ?? []
            line += ids.isEmpty
                ? "\n    └ system log: no schema names"
                : "\n    └ system log: \(ids.joined(separator: ", "))"
        case false?:
            line += "\n    └ system log: could not be read"
        case nil:
            break
        }
        return line
    }

    /// The pretty-printed JSON bytes of all rows, for file export.
    func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(loaded())
    }

    /// Writes the human-readable dump to a temp file and returns its URL for `ShareLink` /
    /// `NSSavePanel`. Distinct from the durable Application-Support log.
    func exportURL() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-sync-diagnostics.txt")
        guard let data = formattedText().data(using: .utf8) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Clears the log (in memory and on disk).
    func clear() {
        cache = []
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: Private

    /// Environment header for the readable dump: build/OS/device, then the CloudKit schema-deploy
    /// state (Wave R-7).
    ///
    /// The schema line is here rather than in a log row because #488 was reported by pasting
    /// exactly this dump into an issue — a sync failure caused by an undeployed schema was
    /// therefore described by an export that could not mention the schema. It costs nothing at
    /// launch (the header is built only when someone reads or exports the log) and adds no rows,
    /// so the 200-entry ring still holds 200 sync events.
    ///
    /// Only type and field *names this app defines* appear, so the redaction allow-list is intact.
    private func envHeader() -> String {
        let head = "FRUS Explorer \(Self.appVersion) (\(Self.appBuild)) · "
            + "\(Self.osVersion) · \(Self.deviceModel) · "
            + "\(FRUSStoreConfiguration.current.logLabel) build"
        guard !CloudKitSchemaInventory.isProductionSchemaCurrent else {
            return head + "\n"
                + "CloudKit schema: deployed through build "
                + "\(CloudKitSchemaInventory.deployedThroughBuild) "
                + "(\(CloudKitSchemaInventory.deployedOn)) — current for this build"
        }
        return head + "\n"
            + "CloudKit schema: ⚠️ NEWER THAN DEPLOYED — last deploy build "
            + "\(CloudKitSchemaInventory.deployedThroughBuild) "
            + "(\(CloudKitSchemaInventory.deployedOn))\n"
            + "  awaiting deploy: "
            + CloudKitSchemaInventory.identifiersAwaitingDeploy.joined(separator: ", ")
    }

    /// Loads the persisted rows on first access, caching them in memory thereafter.
    private func loaded() -> [SyncDiagnosticsEntry] {
        if let cache { return cache }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows: [SyncDiagnosticsEntry]
        if let url = fileURL, let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([SyncDiagnosticsEntry].self, from: data) {
            rows = decoded
        } else {
            rows = []
        }
        cache = rows
        return rows
    }

    /// Persists the rows to the durable Application-Support file.
    private func persist(_ rows: [SyncDiagnosticsEntry]) {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(rows) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - SyncEventSnapshot

/// One CloudKit sync event, reduced to allow-listed `Sendable` values the moment it is posted.
///
/// The `NSPersistentCloudKitContainer.Event` itself never leaves the notification callback
/// (#188-C.1): it is not `Sendable`, and its error carries text that may name records.
struct SyncEventSnapshot: Sendable {
    /// `"setup"`, `"import"`, `"export"`, or `"unknown"` for a type this build does not know.
    let phase: String
    /// Whether the event has finished. A started event has no end date and no outcome yet.
    let hasEnded: Bool
    /// Whether a finished event succeeded; meaningless while `hasEnded` is false.
    let succeeded: Bool
    /// When the event started.
    let startDate: Date
    /// When it ended — or, for an event still in flight, when the snapshot was taken.
    let endDate: Date
    /// The redacted diagnosis of the event's error, if it carried one.
    let diagnostic: FRUSExplorerApp.CloudKitDiagnosticResult?

    /// A snapshot from its parts — what a test builds, since an `Event` has no public initializer.
    init(phase: String, hasEnded: Bool, succeeded: Bool, startDate: Date, endDate: Date,
         diagnostic: FRUSExplorerApp.CloudKitDiagnosticResult? = nil) {
        self.phase = phase
        self.hasEnded = hasEnded
        self.succeeded = succeeded
        self.startDate = startDate
        self.endDate = endDate
        self.diagnostic = diagnostic
    }

    /// Decomposes a posted event into allow-listed values.
    init(_ event: NSPersistentCloudKitContainer.Event) {
        switch event.type {
        case .setup: phase = "setup"
        case .import: phase = "import"
        case .export: phase = "export"
        @unknown default: phase = "unknown"
        }
        hasEnded = event.endDate != nil
        succeeded = event.succeeded
        startDate = event.startDate
        endDate = event.endDate ?? Date.now
        diagnostic = (event.error as? NSError).map { FRUSExplorerApp.cloudKitDiagnostic($0) }
    }
}

// MARK: - SyncEventMonitor

/// Listens for CloudKit sync events from BEFORE the container starts, and keeps them until the
/// app can act on them (#1531).
///
/// ## The defect this replaces
/// The app's only observer of `NSPersistentCloudKitContainer.eventChangedNotification` was
/// installed inside `bootDownloadManager`, after the container had started. The container's
/// mirroring delegate begins work the moment it exists, and in #1531 Production rejected an export
/// about 1.3 s into every launch — before that observer existed. Core Data then refused every
/// later request without sending another event. So most of those launches recorded nothing: the
/// iPhone's Sync Log held a sync event on 0 of its 17 launches after 2026-09-27 11:54Z, against 31
/// of 39 before, and the status stayed "idle", which shows no banner, while sync was stopped in
/// both directions.
///
/// ## What it does
/// `ModelContainer.makeFRUSContainer()` calls ``install()`` immediately before it builds the
/// CloudKit container. From then on, for every event, in order:
/// 1. an ended export updates ``SyncExportFailureMemory`` — a failure starts or extends the run, a
///    success ends it — which needs nothing but `UserDefaults`, so the next launch knows even if
///    this one never gets further;
/// 2. an ended event gets its Sync Log row, and a failed one first has this process's own system
///    log read for the schema names its error did not carry (``SystemLogSchemaScan``);
/// 3. the event goes to the app — or, until `FRUSExplorerApp` calls
///    ``attach(memory:events:)``, waits in ``pending``. `AppState` does not exist when the first
///    events arrive, and must not be touched before it does.
///
/// Rows are written one at a time in arrival order, even though a failed event's row waits a moment
/// for the system log: an exported Sync Log reads newest-first, and a failure filed after the
/// success that followed it would read as the latest news.
///
/// Version history:
///   1.0 — #1531
@MainActor
final class SyncEventMonitor {

    /// The app's monitor, installed by `makeFRUSContainer()` on the CloudKit path.
    static let shared = SyncEventMonitor()

    /// How many events are held before ``attach(memory:events:)``. A launch delivers a handful
    /// before the app attaches; past this the oldest go, counted in ``droppedBeforeAttach``.
    static let pendingLimit = 500

    /// The shortest gap between two system-log reads. In #1531 a failure came with each launch,
    /// not in bursts, but a burst of failed events must not cost a burst of log walks.
    static let scanInterval: TimeInterval = 30

    private let center: NotificationCenter
    private let defaults: UserDefaults
    private let configuration: FRUSStoreConfiguration
    private let log: SyncDiagnosticsLog?
    private let scansSystemLog: Bool
    private let scanDelay: Duration

    private var observer: (any NSObjectProtocol)?
    private var consumer: ((SyncEventSnapshot) -> Void)?
    private var memoryObserver: ((UnrecoveredExport?) -> Void)?
    private var lastScanAt: Date?
    private var recordingTail: Task<Void, Never>?

    /// Events received before the app attached, oldest first.
    private(set) var pending: [SyncEventSnapshot] = []
    /// Events dropped from ``pending`` because it was full.
    private(set) var droppedBeforeAttach = 0

    /// A monitor reading `center`, remembering failures in `defaults` under `configuration`'s key,
    /// and writing rows to `log` (`nil` writes none).
    ///
    /// - Parameters:
    ///   - scansSystemLog: whether a failed event has this process's system log read.
    ///   - scanDelay: how long the read waits first, so the lines Core Data logged around the
    ///     failure have reached the log store.
    init(center: NotificationCenter = .default,
         defaults: UserDefaults = .standard,
         configuration: FRUSStoreConfiguration = .current,
         log: SyncDiagnosticsLog? = .shared,
         scansSystemLog: Bool = true,
         scanDelay: Duration = .seconds(2)) {
        self.center = center
        self.defaults = defaults
        self.configuration = configuration
        self.log = log
        self.scansSystemLog = scansSystemLog
        self.scanDelay = scanDelay
    }

    /// Whether ``install()`` has run.
    var isInstalled: Bool { observer != nil }

    /// Starts listening. Idempotent. Call before the CloudKit container is built.
    func install() {
        guard observer == nil else { return }
        let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        observer = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [self] notification in
            // Decomposed here, on the posting callback: the Event never crosses an isolation
            // boundary (#188-C.1). `queue: .main` makes this the main thread, so the hop below is
            // synchronous and events reach `receive` in the order they were posted.
            guard let event = notification.userInfo?[key]
                    as? NSPersistentCloudKitContainer.Event else { return }
            let snapshot = SyncEventSnapshot(event)
            MainActor.assumeIsolated { self.receive(snapshot) }
        }
    }

    /// Stops listening — for a test's own monitor; the app's listens for the life of the process.
    func uninstall() {
        if let observer { center.removeObserver(observer) }
        observer = nil
    }

    /// Hands the app every event from here on, after the ones held so far, in order.
    ///
    /// - Parameters:
    ///   - memory: called at once with the remembered run (or `nil`), and again whenever an
    ///     export or a system-log read changes it — `AppState.unrecoveredExport`'s writer.
    ///   - events: called for each event: the held ones now, oldest first, then each as it comes.
    func attach(memory: @escaping (UnrecoveredExport?) -> Void,
                events: @escaping (SyncEventSnapshot) -> Void) {
        memoryObserver = memory
        consumer = events
        memory(SyncExportFailureMemory.load(defaults: defaults, configuration: configuration))
        let held = pending
        pending = []
        for snapshot in held { events(snapshot) }
    }

    /// Takes one event: remembers an export's outcome, files its row, and delivers or holds it.
    func receive(_ snapshot: SyncEventSnapshot) {
        if snapshot.hasEnded, snapshot.phase == "export" {
            let run = SyncExportFailureMemory.recordExport(
                succeeded: snapshot.succeeded,
                at: snapshot.endDate,
                message: snapshot.diagnostic?.message,
                schemaIdentifiers: snapshot.diagnostic?.inspection.schemaIdentifiers,
                defaults: defaults,
                configuration: configuration)
            memoryObserver?(run)
        }
        if snapshot.hasEnded { fileRow(for: snapshot) }
        if let consumer {
            consumer(snapshot)
        } else {
            if pending.count >= Self.pendingLimit {
                pending.removeFirst()
                droppedBeforeAttach += 1
            }
            pending.append(snapshot)
        }
    }

    /// Waits until every row filed so far is written — for tests.
    func waitForRows() async {
        await recordingTail?.value
    }

    // MARK: Private

    /// Files the Sync Log row for an ended event, after every row filed before it.
    private func fileRow(for snapshot: SyncEventSnapshot) {
        guard let log else { return }
        let scan = !snapshot.succeeded && scansSystemLog && claimScan(at: snapshot.endDate)
        let delay = scanDelay
        let previous = recordingTail
        recordingTail = Task.detached(priority: .utility) { [self] in
            await previous?.value
            var scanned: Bool? = nil
            var found: [String]? = nil
            if scan {
                try? await Task.sleep(for: delay)
                let result = SystemLogSchemaScan.scanCurrentProcess(from: snapshot.startDate,
                                                                    to: snapshot.endDate)
                scanned = result != nil
                found = result.flatMap { $0.isEmpty ? nil : $0 }
            }
            let diag = snapshot.diagnostic
            await log.record(
                phase: snapshot.phase,
                startDate: snapshot.startDate,
                endDate: snapshot.endDate,
                succeeded: snapshot.succeeded,
                errorDomain: diag?.domain,
                errorCode: diag?.code,
                errorCodeName: diag?.codeName,
                partialItemCount: diag?.partialCount,
                subErrorHistogram: diag?.histogram,
                // Wave R-6. Recorded for every ended event that carried an error, so "the app
                // looked and there was no per-item detail" is a fact in the row rather than an
                // absence the reader has to guess at.
                hadPartialDictionary: diag?.inspection.hadPartialDictionary,
                partialDictionaryDepth: diag?.inspection.partialDictionaryDepth,
                schemaIdentifiers: (diag?.inspection.schemaIdentifiers).flatMap {
                    $0.isEmpty ? nil : $0
                },
                retryAfterSeconds: diag?.inspection.retryAfterSeconds,
                chainTruncated: diag?.inspection.chainTruncated,
                systemLogScanned: scanned,
                systemLogSchemaIdentifiers: found)
            if let found, snapshot.phase == "export" {
                await self.absorbSystemLogIdentifiers(found)
            }
        }
    }

    /// Whether a failed event ending at `date` may read the system log, claiming the slot if so.
    private func claimScan(at date: Date) -> Bool {
        if let lastScanAt, abs(date.timeIntervalSince(lastScanAt)) < Self.scanInterval { return false }
        lastScanAt = date
        return true
    }

    /// Adds what the system log named to the remembered run, and tells the app.
    private func absorbSystemLogIdentifiers(_ identifiers: [String]) {
        guard let run = SyncExportFailureMemory.addSchemaIdentifiers(
            identifiers, defaults: defaults, configuration: configuration) else { return }
        memoryObserver?(run)
    }
}
