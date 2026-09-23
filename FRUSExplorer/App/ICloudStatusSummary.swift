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
/// zone was found — and both surfaces that show them (the iOS Settings root's iCloud Sync section
/// and the macOS status bar) used to render each one on its own. A device that was simply not
/// signed in to iCloud therefore showed three rows, each titled "Status", that contradicted one
/// another: **Sync Error** (the account check writes its own description into the sync-event
/// channel), **Private Zone Missing** (a private database cannot be listed without an account, and
/// the failed listing read as "missing"), and **Account Issue**. Only the last was the cause.
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
/// 4. **Failed** — the most recent sync event's redacted reason.
/// 5. **Syncing**, 6. **Succeeded**, 7. **Idle** — the event stream, when nothing above applies.
///
/// A surface shows one of these and nothing else. The facts it drops are not lost: every event
/// and health check is recorded by `SyncDiagnosticsLog`, which Data & Recovery ▸ Sync Diagnostics
/// shows in full.
///
/// Version history:
///   1.0 — one status row for a signed-out device, where the iOS Settings root showed three
enum ICloudStatusSummary: Equatable, Sendable {
    /// The container fell back to a local store; `diagnostic` is `AppState.cloudKitInitError`.
    case localOnly(diagnostic: String?)
    /// The iCloud account is not `.available` — not signed in, restricted, and so on.
    case accountUnavailable(CKAccountStatus)
    /// The account is fine but the private sync zone was not found on the server.
    case zoneMissing
    /// The most recent sync event failed; `message` is the observer's redacted reason.
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
    /// iCloud status reads it through `AppState.iCloudStatusSummary`, which calls this.
    ///
    /// - Parameters:
    ///   - cloudKitEnabled: `AppState.cloudKitSyncEnabled` — `false` when the container fell back
    ///     to local-only.
    ///   - initError: `AppState.cloudKitInitError`, carried into `.localOnly`.
    ///   - syncState: `AppState.cloudKitSyncState`, the most recent sync event.
    ///   - accountStatus: `AppState.cloudKitAccountStatus`; `nil` until the first check returns.
    ///   - zoneVerified: `AppState.cloudKitZoneVerified`; `nil` until verified or when unknowable.
    static func resolve(
        cloudKitEnabled: Bool,
        initError: String?,
        syncState: CloudKitSyncState,
        accountStatus: CKAccountStatus?,
        zoneVerified: Bool?
    ) -> ICloudStatusSummary {
        guard cloudKitEnabled else { return .localOnly(diagnostic: initError) }
        if let accountStatus, accountStatus != .available {
            return .accountUnavailable(accountStatus)
        }
        if zoneVerified == false { return .zoneMissing }
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
            zoneVerified: cloudKitZoneVerified
        )
    }
}
