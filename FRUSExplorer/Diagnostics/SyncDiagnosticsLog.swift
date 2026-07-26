// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

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
/// `(codeName, code) → count` histogram of a `partialFailure`'s sub-errors, and coarse
/// environment (app version/build, OS, device-model class). **Never** recorded: record
/// names/IDs, zone/owner identifiers, emails, field values, `localizedDescription`, or any
/// free text that could embed an identifier.
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
    /// App marketing version (`CFBundleShortVersionString`).
    let appVersion: String
    /// App build number (`CFBundleVersion`).
    let appBuild: String
    /// Coarse OS version string.
    let osVersion: String
    /// Device model *class* (e.g. `iPhone16,2`) — not a serial or per-device identifier.
    let deviceModel: String
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

    /// Maximum rows retained; older rows are dropped (ring buffer).
    private let maxEntries = 200

    /// In-memory copy of the persisted rows, loaded lazily on first access.
    private var cache: [SyncDiagnosticsEntry]?

    // MARK: Persistence location

    /// The durable log file in Application Support (never Caches — the OS may purge Caches).
    /// `nil` only if the directory can't be resolved/created, in which case the log is a no-op.
    private static let fileURL: URL? = {
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
        subErrorHistogram: [SubErrorBucket]? = nil
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
            var parts = ["[\(stamp.string(from: e.timestamp))]",
                         e.phase,
                         e.succeeded ? "ok" : "FAILED"]
            if let d = e.durationSeconds { parts.append(String(format: "%.1fs", d)) }
            if let dom = e.errorDomain, let code = e.errorCode {
                parts.append("\(dom) \(e.errorCodeName ?? "code \(code)") (\(code))")
            }
            if let n = e.partialItemCount { parts.append("partial=\(n)") }
            var line = parts.joined(separator: "  ")
            if let hist = e.subErrorHistogram, !hist.isEmpty {
                let breakdown = hist.map { "\($0.count)× \($0.key)" }.joined(separator: ", ")
                line += "\n    └ \(breakdown)"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
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
        if let url = Self.fileURL { try? FileManager.default.removeItem(at: url) }
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
            + "\(Self.osVersion) · \(Self.deviceModel)"
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
        if let url = Self.fileURL, let data = try? Data(contentsOf: url),
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
        guard let url = Self.fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(rows) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
