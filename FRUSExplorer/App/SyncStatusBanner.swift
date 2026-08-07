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
/// `AppState.cloudKitSyncState` has driven the macOS status bar since #188 — **Local Only** in
/// orange with the init diagnostic in its tooltip, **iCloud Sync**, **Syncing…** with a spinner,
/// and the failure message. On iOS the same state reached only `SettingsView`, three taps from
/// the workspace, so a user whose sync was off or broken had no way to notice while they worked.
/// The whole point of the state is that data is silently not moving; putting it where nobody
/// looks defeats it.
///
/// ## What it shows, and what it stays quiet about
/// Only the two states a researcher needs to act on:
///
/// - **Local Only** — sync is disabled or the container failed to initialise. Notes, tags and
///   collections made now stay on this device. This is the one that matters, and it persists
///   until it is no longer true.
/// - **Sync failed** — with the redacted reason the observer already computed.
///
/// It says **nothing** while sync is healthy, and nothing while a sync is merely in flight. A
/// spinner that appears on every import would be its own kind of churn — the same reasoning that
/// keeps the indexing banner off screen between volumes — and "iCloud is working" is not news.
/// `.succeeded` and `.unknown` render nothing at all.
///
/// ## Why a banner rather than a chip
/// It rides the same `.safeAreaInset(edge: .bottom)` as `IndexingBannerView`, which is what the
/// issue asked for: the app already has one place where it tells you something about the state
/// of your data, and this belongs beside it rather than inventing a second vocabulary. When both
/// want the space the indexing banner wins — that one is transient and finishes; this one waits.
///
/// Version history:
///   1.0 — Session 2026-08-07: #665
struct SyncStatusBanner: View {

    /// The live sync state.
    let state: CloudKitSyncState
    /// Whether CloudKit initialised at all. `false` means local-only regardless of `state`.
    let cloudKitEnabled: Bool
    /// Opens the place with the detail — Settings ▸ Data & Recovery on iOS.
    let onOpenSettings: () -> Void

    /// Whether there is anything worth interrupting the workspace for.
    ///
    /// Static so the host can ask before reserving layout space, without building the view.
    static func isWorthShowing(state: CloudKitSyncState, cloudKitEnabled: Bool) -> Bool {
        if !cloudKitEnabled { return true }
        if case .failed = state { return true }
        return false
    }

    var body: some View {
        if Self.isWorthShowing(state: state, cloudKitEnabled: cloudKitEnabled) {
            HStack(spacing: 10) {
                Image(systemName: cloudKitEnabled ? "exclamationmark.icloud" : "icloud.slash")
                    .foregroundStyle(cloudKitEnabled ? .red : .orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(detail)
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
            .accessibilityLabel("\(title). \(detail)")
        }
    }

    private var title: String {
        cloudKitEnabled
            ? String(localized: "sync.banner.failed.title", defaultValue: "iCloud Sync Failed")
            : String(localized: "sync.banner.localOnly.title", defaultValue: "Local Only")
    }

    /// The detail line. For a failure this is the observer's already-redacted message — the same
    /// text the macOS status bar shows — never a raw `NSError`.
    private var detail: String {
        guard cloudKitEnabled else {
            return String(localized: "sync.banner.localOnly.detail",
                          defaultValue: "Notes, tags, and collections you make now stay on this device.")
        }
        if case .failed(let message) = state { return message }
        return ""
    }
}
