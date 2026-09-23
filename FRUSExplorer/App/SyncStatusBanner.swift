// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SyncStatusBanner

/// The workspace-level iCloud indicator on iOS (#665).
///
/// ## Why iOS needed one
/// `AppState`'s iCloud state has driven the macOS status bar since #188 — **Local Only** in
/// orange with the init diagnostic in its tooltip, **iCloud Sync**, **Syncing…** with a spinner,
/// and the failure message. On iOS the same state reached only `SettingsView`, three taps from
/// the workspace, so a user whose sync was off or broken had no way to notice while they worked.
/// The whole point of the state is that data is silently not moving; putting it where nobody
/// looks defeats it.
///
/// ## What it shows, and what it stays quiet about
/// Only the states a researcher needs to act on, read from `ICloudStatusSummary` — the same one
/// status the Settings root and the macOS status bar show, so the three never disagree:
///
/// - **Local Only** — sync is disabled or the container failed to initialise. Notes, tags and
///   collections made now stay on this device. This is the one that matters, and it persists
///   until it is no longer true.
/// - **iCloud Account Issue** — not signed in, restricted, or undetermined, with the account's own
///   explanation. This used to arrive titled **iCloud Sync Failed**, because the health check wrote
///   the account's description into the sync-event state and the banner read that state raw: a
///   researcher who had simply never signed in was told a sync had failed.
/// - **iCloud Sync Zone Missing** — the private zone is gone, so nothing uploads or downloads.
///   Added with the summary: it is the silent failure the zone check exists for, and it lived only
///   in Settings, three taps away — the problem #665 solved for failures. It is safe to announce
///   only because a FAILED zone listing now records "unknown" rather than "missing", and a
///   successful setup re-checks, so neither a network blip nor a first launch reads as a deletion.
/// - **iCloud Sync Failed** — with the redacted reason the observer already computed.
///
/// It says **nothing** while sync is healthy, and nothing while a sync is merely in flight. A
/// spinner that appears on every import would be its own kind of churn — the same reasoning that
/// keeps the indexing banner off screen between volumes — and "iCloud is working" is not news.
/// `.syncing`, `.succeeded` and `.idle` render nothing at all.
///
/// ## Why a banner rather than a chip
/// It rides the same `.safeAreaInset(edge: .bottom)` as `IndexingBannerView`, which is what the
/// issue asked for: the app already has one place where it tells you something about the state
/// of your data, and this belongs beside it rather than inventing a second vocabulary. When both
/// want the space the indexing banner wins — that one is transient and finishes; this one waits.
///
/// Version history:
///   1.0 — Session 2026-08-07: #665
///   1.1 — accessibility identifier, so the #1070 keyboard gate can be asserted end-to-end
///   1.2 — reads `ICloudStatusSummary` instead of the raw event state: an account problem is titled
///          as one, and a missing sync zone is announced
struct SyncStatusBanner: View {

    /// The one iCloud status to show — `AppState.iCloudStatusSummary`.
    let summary: ICloudStatusSummary
    /// Opens the place with the detail — the Settings root, whose iCloud Sync row explains it.
    let onOpenSettings: () -> Void

    /// What the banner says for one status.
    struct Content: Equatable {
        /// The bold first line.
        let title: String
        /// The explanation beneath it, at most two lines.
        let detail: String
        /// The leading SF Symbol.
        let systemImage: String
        /// The symbol's colour.
        let tint: Color
    }

    /// What the banner says for `summary`, or `nil` when there is nothing worth interrupting the
    /// workspace for. The whole visibility and wording rule, in one pure function the tests call.
    static func content(for summary: ICloudStatusSummary) -> Content? {
        switch summary {
        case .localOnly:
            return Content(
                title: String(localized: "sync.banner.localOnly.title", defaultValue: "Local Only"),
                detail: String(localized: "sync.banner.localOnly.detail",
                               defaultValue: "Notes, tags, and collections you make now stay on this device."),
                systemImage: "icloud.slash",
                tint: .orange)
        case .accountUnavailable(let status):
            // One title for every unavailable status — the explanation beneath names which, in
            // the same words the Settings row uses — so no restricted or undetermined account is
            // told it is "not signed in".
            return Content(
                title: String(localized: "sync.banner.account.title",
                              defaultValue: "iCloud Account Issue"),
                detail: AppState.accountStatusDescription(status),
                systemImage: "person.crop.circle.badge.exclamationmark",
                tint: .orange)
        case .zoneMissing:
            return Content(
                title: String(localized: "sync.banner.zoneMissing.title",
                              defaultValue: "iCloud Sync Zone Missing"),
                detail: String(localized: "sync.banner.zoneMissing.detail",
                               defaultValue: "Nothing syncs until it’s recreated. Relaunch, or use Fix iCloud Sync."),
                systemImage: "exclamationmark.icloud.fill",
                tint: .red)
        case .failed(let message):
            // The observer's already-redacted message — the same text the macOS status bar shows —
            // never a raw `NSError`.
            return Content(
                title: String(localized: "sync.banner.failed.title", defaultValue: "iCloud Sync Failed"),
                detail: message,
                systemImage: "exclamationmark.icloud",
                tint: .red)
        case .syncing, .succeeded, .idle:
            return nil
        }
    }

    /// Whether there is anything worth interrupting the workspace for.
    ///
    /// Static so the host can ask before reserving layout space, without building the view.
    static func isWorthShowing(_ summary: ICloudStatusSummary) -> Bool {
        content(for: summary) != nil
    }

    var body: some View {
        if let content = Self.content(for: summary) {
            HStack(spacing: 10) {
                Image(systemName: content.systemImage)
                    .foregroundStyle(content.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(content.title)
                        .font(.subheadline.weight(.medium))
                    Text(content.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Button(String(localized: "sync.banner.details", defaultValue: "Details")) {
                    onOpenSettings()
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(content.title). \(content.detail)")
            // #1070's contract is observable only if the occluder can be named. This banner is
            // the inset's commonest occupant — for a local-only user it is up permanently — so
            // `KeyboardDismissBarReachTests` asserts through this identifier that the inset has
            // yielded while the keyboard is raised. An identifier rather than the label, which is
            // localized and composed from two more localized strings.
            .accessibilityIdentifier("tabShell.syncBanner")
        }
    }
}
