// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CloudKit

// MARK: - ICloudStatusSummary

/// The ONE iCloud status a surface shows, resolved from the four facts `AppState` keeps apart.
///
/// ## Why this exists
/// `AppState` tracks iCloud through four independent properties — whether the container came up
/// with CloudKit at all, the most recent sync *event*, the account status, and whether the private
/// zone was found — and the surfaces that show them (the iOS Settings root's iCloud Sync section,
/// the macOS status bar, and the iOS workspace banner) used to render them on their own. A device
/// that was simply not signed in to iCloud therefore showed three Settings rows, each titled
/// "Status", that contradicted one another: **Sync Error** (the account check wrote its own
/// description into the sync-event channel), **Private Zone Missing** (a private database cannot
/// be listed without an account, and the failed listing read as "missing"), and **Account Issue**.
/// Only the last was the cause — and the banner, reading the event channel raw, called it
/// "iCloud Sync Failed".
///
/// ## Precedence
/// Most fundamental first; each later fact is, in practice, a consequence of an earlier one:
///
/// 1. **Local only** — CloudKit never initialised, so none of the other three means anything.
/// 2. **Account unavailable** — nothing syncs without an account; a failed event or an unlistable
///    zone is the account problem seen from further downstream.
/// 3. **Zone missing** — records cannot move until the zone is recreated. This outranks a
///    succeeded event on purpose: a missing zone is the silent failure the event stream does not
///    report, which is why the zone check exists at all.
/// 4. **Stopped** — an upload failed in an EARLIER launch and none has succeeded since (#1531).
///    The reader has already relaunched, so "relaunch to try again" would be false; and it outranks
///    every event state below, so a successful import or an upload in flight cannot quiet it.
/// 5. **Failed** — the most recent sync event's redacted reason, or an upload that failed earlier
///    in THIS launch and has not succeeded since, whatever events followed it.
/// 6. **Syncing**, 7. **Succeeded**, 8. **Idle** — the event stream, when nothing above applies.
///
/// A surface shows one of these and nothing else. The facts it drops are not lost: every event
/// and health check is recorded by `SyncDiagnosticsLog`, which Data & Recovery ▸ Sync Diagnostics
/// shows in full.
///
/// Version history:
///   1.0 — one status row for a signed-out device, where the iOS Settings root showed three
///   1.1 — `SyncStatusBanner` reads it too, so all three surfaces show the same one status
///   1.2 — #1531: `.stopped`, from an upload failure remembered across launches
///          (``SyncExportFailureMemory``); an unrecovered upload keeps a failure on screen
enum ICloudStatusSummary: Equatable, Sendable {
    /// The container fell back to a local store; `diagnostic` is `AppState.cloudKitInitError`.
    case localOnly(diagnostic: String?)
    /// The iCloud account is not `.available` — not signed in, restricted, and so on.
    case accountUnavailable(CKAccountStatus)
    /// The account is fine but the private sync zone was not found on the server.
    case zoneMissing
    /// An upload failed in an earlier launch and none has succeeded since (#1531).
    case stopped(UnrecoveredExport)
    /// The most recent sync event failed, or an upload failed earlier in this launch and has not
    /// succeeded since; `message` is the observer's redacted reason.
    case failed(message: String)
    /// A sync event is in flight.
    case syncing
    /// The most recent sync event completed at the given date.
    case succeeded(Date)
    /// No sync event has arrived since launch and no check has found a problem.
    case idle

    /// Resolves the single status to show from `AppState`'s four iCloud facts.
    ///
    /// Pure, so the precedence can be tested without a CloudKit container. Every view that shows
    /// iCloud status — the Settings row, the macOS status chip, the iOS workspace banner — reads it
    /// through `AppState.iCloudStatusSummary`, which calls this.
    ///
    /// - Parameters:
    ///   - cloudKitEnabled: `AppState.cloudKitSyncEnabled` — `false` when the container fell back
    ///     to local-only.
    ///   - initError: `AppState.cloudKitInitError`, carried into `.localOnly`.
    ///   - syncState: `AppState.cloudKitSyncState`, the most recent sync event.
    ///   - accountStatus: `AppState.cloudKitAccountStatus`; `nil` until the first check returns.
    ///   - zoneVerified: `AppState.cloudKitZoneVerified`; `nil` until verified or when unknowable.
    ///   - unrecoveredExport: `AppState.unrecoveredExport` — an upload that failed with none
    ///     succeeding since, from ``SyncExportFailureMemory``; `nil` when there is none.
    ///   - launchID: this process's ``SyncExportFailureMemory/currentLaunchID``, which says whether
    ///     that failure began in this launch or an earlier one. A parameter only so tests can say.
    static func resolve(
        cloudKitEnabled: Bool,
        initError: String?,
        syncState: CloudKitSyncState,
        accountStatus: CKAccountStatus?,
        zoneVerified: Bool?,
        unrecoveredExport: UnrecoveredExport? = nil,
        launchID: UUID = SyncExportFailureMemory.currentLaunchID
    ) -> ICloudStatusSummary {
        guard cloudKitEnabled else { return .localOnly(diagnostic: initError) }
        if let accountStatus, accountStatus != .available {
            return .accountUnavailable(accountStatus)
        }
        if zoneVerified == false { return .zoneMissing }
        if let unrecoveredExport {
            // Begun in an earlier launch: the reader relaunched and it failed again, or nothing
            // has uploaded since. Either way the event channel no longer describes it.
            if unrecoveredExport.began(beforeLaunch: launchID) { return .stopped(unrecoveredExport) }
            // Begun in this launch: a failure, and it stays one until an upload succeeds — a later
            // import, or an upload merely in flight, must not quiet it (#1531: "never quiet").
            if case .failed(let message) = syncState { return .failed(message: message) }
            return .failed(message: unrecoveredExport.message
                ?? String(localized: "cloudkit.error.unknown", defaultValue: "Unknown sync error"))
        }
        switch syncState {
        case .failed(let message): return .failed(message: message)
        case .syncing: return .syncing
        case .succeeded(let date): return .succeeded(date)
        case .unknown: return .idle
        }
    }
}

// MARK: - AppState convenience

extension AppState {
    /// The one iCloud status to show right now — see `ICloudStatusSummary` for the precedence.
    ///
    /// Read this rather than the four properties it resolves. Reading them separately is how the
    /// iOS Settings root came to show three contradictory status rows for a signed-out device.
    var iCloudStatusSummary: ICloudStatusSummary {
        ICloudStatusSummary.resolve(
            cloudKitEnabled: cloudKitSyncEnabled,
            initError: cloudKitInitError,
            syncState: cloudKitSyncState,
            accountStatus: cloudKitAccountStatus,
            zoneVerified: cloudKitZoneVerified,
            unrecoveredExport: unrecoveredExport
        )
    }
}

// MARK: - UnrecoveredExport

/// An upload that failed, with no upload succeeding since — the fact #1531 needed the app to keep
/// across launches.
///
/// ## Why the event channel alone could not carry it
/// `AppState.cloudKitSyncState` is the most recent EVENT, and it lives for one process. In #1531 a
/// field missing from the Production schema made every export fail about 1.3 s into every launch,
/// and the status read "idle" on most of them: the failure came before the old observer existed,
/// and after it Core Data refused every request without sending another event. Nothing on screen
/// said that sync had stopped, in both directions, for days. This is the fact that does say so.
///
/// Only ``SyncExportFailureMemory`` writes it, and only a successful upload (or Fix iCloud Sync,
/// which discards what failed to upload) ends it.
///
/// Version history:
///   1.0 — #1531
struct UnrecoveredExport: Codable, Equatable, Sendable {
    /// When the first upload of this unbroken run of failures failed.
    var firstFailedAt: Date
    /// When the most recent one failed.
    var lastFailedAt: Date
    /// The launch that recorded the first failure — its ``SyncExportFailureMemory/currentLaunchID``.
    var firstLaunchID: UUID
    /// The redacted reason of the most recent failure, as `FRUSExplorerApp.cloudKitDiagnostic(_:)`
    /// formatted it. Never free error text.
    var message: String?
    /// The `CD_…` schema identifiers the failures named, from the error itself or from this
    /// process's own system log (``SystemLogSchemaScan``) — allow-listed, sorted.
    var schemaIdentifiers: [String]?

    /// Whether the run began in an earlier launch than `launchID`, i.e. the reader has relaunched
    /// since the first failure and no upload has succeeded.
    func began(beforeLaunch launchID: UUID) -> Bool { firstLaunchID != launchID }
}

// MARK: - SyncStoppedCopy

/// The words for a stopped sync, shared by the iOS Settings row and the macOS status chip, so the
/// two cannot describe one state differently (#1531).
///
/// Version history:
///   1.0 — #1531
enum SyncStoppedCopy {

    /// When the run began, as the reader's locale writes a date and time.
    static func since(_ run: UnrecoveredExport) -> String {
        run.firstFailedAt.formatted(date: .abbreviated, time: .shortened)
    }

    /// The explanation: since when, that the changes are safe here, and what Fix iCloud Sync would
    /// do to them. It promises no retry, because none is coming that the reader can cause.
    static func detail(_ run: UnrecoveredExport) -> String {
        String(format: String(
            localized: "sync.stopped.detail %@",
            defaultValue: "No upload from this device has succeeded since %@. Your changes are kept here, and Fix iCloud Sync would discard them."),
            since(run))
    }

    /// The redacted reason and any schema names, for the reader who reports it — `nil` when the
    /// run carries neither. The schema names are the ones #1531 had to be diagnosed from by hand.
    static func diagnostic(_ run: UnrecoveredExport) -> String? {
        let parts = [run.message, run.schemaIdentifiers.map { $0.joined(separator: ", ") }]
            .compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return String(format: String(localized: "sync.stopped.diagnostic %@",
                                     defaultValue: "Diagnostic: %@"),
                      parts.joined(separator: " · "))
    }

    /// The detail followed by the diagnostic, as the Settings row and the chip's popover show it.
    static func fullDetail(_ run: UnrecoveredExport) -> String {
        guard let diagnostic = diagnostic(run) else { return detail(run) }
        return "\(detail(run))\n\n\(diagnostic)"
    }
}

// MARK: - SyncExportFailureMemory

/// Remembers an unrecovered upload across launches, in this device's own `UserDefaults` (#1531).
///
/// ## Where it lives, and why there
/// `UserDefaults`, never SwiftData: the fact is about this device's store, and a synced record
/// would be both a new CloudKit field (a Production deploy) and absurd — a failure to upload
/// recorded in the very store that cannot upload. One key per build configuration
/// (``FRUSStoreConfiguration``), because a Debug build keeps a store of its own: its failures say
/// nothing about the shipped app's store beside it.
///
/// ## Who writes it
/// ``SyncEventMonitor``, for every ended export event, from the moment the container starts —
/// before `AppState` exists, so the first failure of a launch is never missed. A failed export
/// starts or extends the run; a successful one ends it. ``forget(defaults:configuration:)`` ends it
/// too, when Fix iCloud Sync clears the store the unsent changes were in.
///
/// Version history:
///   1.0 — #1531
enum SyncExportFailureMemory {

    /// This process's launch identity. A run whose ``UnrecoveredExport/firstLaunchID`` differs began
    /// in an earlier launch.
    static let currentLaunchID = UUID()

    /// The `UserDefaults` key for one build configuration's store.
    static func key(for configuration: FRUSStoreConfiguration) -> String {
        "frus.sync.unrecoveredExport.\(configuration.rawValue)"
    }

    /// The remembered run, or `nil` when the last upload succeeded or none has ever failed.
    static func load(defaults: UserDefaults = .standard,
                     configuration: FRUSStoreConfiguration = .current) -> UnrecoveredExport? {
        guard let data = defaults.data(forKey: key(for: configuration)) else { return nil }
        return try? JSONDecoder().decode(UnrecoveredExport.self, from: data)
    }

    /// Records one ended export event and returns the run as it now stands.
    ///
    /// A success ends the run (`nil`). A failure starts one, or extends the run already
    /// remembered: its first failure, its first launch and any identifiers it already named are
    /// kept, so a relaunch that fails again still reads as "stopped since" the first.
    @discardableResult
    static func recordExport(succeeded: Bool,
                             at date: Date,
                             message: String?,
                             schemaIdentifiers: [String]?,
                             launchID: UUID = currentLaunchID,
                             defaults: UserDefaults = .standard,
                             configuration: FRUSStoreConfiguration = .current) -> UnrecoveredExport? {
        guard !succeeded else {
            forget(defaults: defaults, configuration: configuration)
            return nil
        }
        var run = load(defaults: defaults, configuration: configuration)
            ?? UnrecoveredExport(firstFailedAt: date, lastFailedAt: date, firstLaunchID: launchID,
                                 message: nil, schemaIdentifiers: nil)
        run.lastFailedAt = max(run.lastFailedAt, date)
        if let message { run.message = message }
        run.schemaIdentifiers = merged(run.schemaIdentifiers, schemaIdentifiers)
        save(run, defaults: defaults, configuration: configuration)
        return run
    }

    /// Adds identifiers found after the event — the system-log scan finishes seconds later — to the
    /// run still remembered. Does nothing when an upload has succeeded in between.
    @discardableResult
    static func addSchemaIdentifiers(_ identifiers: [String],
                                     defaults: UserDefaults = .standard,
                                     configuration: FRUSStoreConfiguration = .current) -> UnrecoveredExport? {
        guard !identifiers.isEmpty,
              var run = load(defaults: defaults, configuration: configuration) else { return nil }
        run.schemaIdentifiers = merged(run.schemaIdentifiers, identifiers)
        save(run, defaults: defaults, configuration: configuration)
        return run
    }

    /// Ends the run without an upload — for Fix iCloud Sync, which clears the store whose unsent
    /// changes it was about.
    static func forget(defaults: UserDefaults = .standard,
                       configuration: FRUSStoreConfiguration = .current) {
        defaults.removeObject(forKey: key(for: configuration))
    }

    // MARK: Private

    /// The union of two identifier lists, sorted, capped as the inspector caps them; `nil` if empty.
    private static func merged(_ a: [String]?, _ b: [String]?) -> [String]? {
        let union = Set(a ?? []).union(b ?? [])
        guard !union.isEmpty else { return nil }
        return Array(union.sorted().prefix(CloudKitErrorInspector.maxSchemaIdentifiers))
    }

    /// Writes the run. A run that cannot be encoded is not written, which leaves the previous one.
    private static func save(_ run: UnrecoveredExport, defaults: UserDefaults,
                             configuration: FRUSStoreConfiguration) {
        guard let data = try? JSONEncoder().encode(run) else { return }
        defaults.set(data, forKey: key(for: configuration))
    }
}
