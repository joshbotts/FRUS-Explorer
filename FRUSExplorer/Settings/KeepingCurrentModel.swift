// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

// MARK: - KeepingCurrentModel

/// Keeping Current's list (#1660): the downloaded volumes the last check found changed upstream,
/// and where each one's update stands.
///
/// ## What it replaces
/// Each storage hub kept its own list and dropped a volume's row the moment Update was pressed,
/// before anything had downloaded, and whether or not the download manager had taken the request:
/// it declined a volume already downloading and said nothing. The Mac's pane showed no transfer at
/// all, so an Update All that downloaded 29 volumes on the owner's Mac (2026-10-12) read as a
/// button that did nothing. The owner's answers of 2026-10-16 set what replaces it: a row stays
/// and shows its update's progress — Queued, Downloading, Indexing, then Updated — a failed
/// download is retried as a first download's is and then reads Failed with Retry, a volume already
/// downloading says so and follows that download, Check for Corrections reads the published list
/// itself when it has none and says why when it cannot, and a side-loaded copy's row says Update
/// replaces it.
///
/// ## Why it lives on `AppState`
/// For the reason `DownloadedVolumesListModel` does: a hub does not outlive the reader leaving it,
/// and an update keeps running after its hub is gone. Both hubs mount `KeepingCurrentSection`,
/// which reads this one model, so the rows and their states survive leaving Settings and coming
/// back, for the rest of the launch.
///
/// ## Where the states come from
/// `FRUSExplorerApp` feeds it three things: the download queue (`downloadStateDidChange(_:)`),
/// how each transfer ended (`transferDidFinish(_:outcome:)`, from `DownloadManager`'s
/// `onTransferFinished`), and when a downloaded volume's re-index ends
/// (`indexingDidFinish(_:failure:)`, from the post-download hook). A state only moves forward
/// along Queued, Downloading, Indexing and Updated, whatever order those reports arrive in; Retry
/// and a cancel are the only ways back.
///
/// Version history:
///   1.0 — #1660: initial implementation
@MainActor
@Observable
final class KeepingCurrentModel {

    // MARK: - Types

    /// Where one volume's update stands.
    enum Status: Equatable, Sendable {
        /// Listed by the check and not yet asked for: the row offers Update.
        case available
        /// Update was pressed, and the download waits its turn in the queue.
        case queued
        /// The download is under way.
        case downloading
        /// A download of the volume was already under way or waiting when the check listed it or
        /// Update was pressed. It fetches the same published file, so the row follows it.
        case alreadyDownloading
        /// The download finished and the volume is being indexed.
        case indexing
        /// Downloaded and indexed.
        case updated
        /// The update failed; the row offers Retry.
        case failed(Failure)

        /// Whether the row offers Update or Retry, and so whether Update All takes it.
        var offersUpdate: Bool {
            switch self {
            case .available, .failed: return true
            default: return false
            }
        }

        /// Whether an update of the volume is under way.
        var isUnderWay: Bool {
            switch self {
            case .queued, .downloading, .alreadyDownloading, .indexing: return true
            default: return false
            }
        }

        /// Whether the update failed.
        var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    /// Why an update failed.
    enum Failure: Equatable, Sendable {
        /// The download failed with its automatic retries spent.
        case download(DownloadFailure)
        /// The volume downloaded, and indexing it failed, with the error's description.
        case indexing(String)
        /// The download manager declined it for having no catalogue address. A listed volume is
        /// always a catalogue volume, so this is not expected; it is kept so a decline is never
        /// silent again.
        case noCatalogueURL
    }

    /// One listed volume.
    struct Row: Identifiable, Equatable {
        /// The volume's catalogue entry.
        let entry: VolumeManifestEntry
        /// Whether the file on this device is one the reader side-loaded, which Update replaces.
        let isSideloaded: Bool
        /// Where its update stands.
        var status: Status

        /// The volume's id.
        var id: String { entry.volumeId }
    }

    /// Why the published list could not be read when the reader asked for it.
    enum ListProblem: Equatable, Sendable {
        /// The device is offline.
        case offline
        /// GitHub's request limit, and when it lifts if GitHub said.
        case rateLimited(until: Date?)
        /// GitHub answered with a status that is not a success.
        case server(status: Int)
        /// Any other failure, with its description.
        case other(String)
    }

    // MARK: - State

    /// The listed volumes, in the catalogue's order.
    private(set) var rows: [Row] = []
    /// `true` while a check runs, the list's own fetch included.
    private(set) var isChecking = false
    /// `true` once a check in this launch has listed what it found.
    private(set) var hasChecked = false
    /// `true` while Refresh Available List runs.
    private(set) var isRefreshingList = false
    /// Why the last check or refresh the reader asked for could not read the published list.
    private(set) var listProblem: ListProblem? = nil

    /// Whether a finished download is indexed. `false` only when the search index could not
    /// open, so no re-index follows a download: a finished download then reads Updated at once.
    var indexesDownloads = true

    /// The volumes in the download queue, transferring or waiting, as last reported.
    private var queuedVolumeIds: Set<String> = []
    /// The volumes whose transfer is under way, as last reported.
    private var activeVolumeIds: Set<String> = []

    /// Whether Update All has a row to take.
    var offersUpdateAll: Bool { rows.contains { $0.status.offersUpdate } }

    // MARK: - Checking

    /// Lists the downloaded volumes whose published copy differs from this device's.
    ///
    /// Reads the published list first when this launch has none (the owner's answer of
    /// 2026-10-16), and sets `listProblem` when it cannot.
    ///
    /// - Parameters:
    ///   - manifest: The catalogue and its live listing.
    ///   - downloads: The download manager, which hashes the local files.
    ///   - isOnline: Whether the device is online.
    ///   - session: The session the published list is read through. Default `.shared`; a test
    ///     answers it from fixtures.
    func check(manifest: ManifestStore, downloads: DownloadManager?, isOnline: Bool,
               session: URLSession = .shared) async {
        guard !isChecking, let downloads else { return }
        isChecking = true
        defer { isChecking = false }
        listProblem = nil
        if manifest.diffResult == nil {
            guard isOnline else {
                listProblem = .offline
                return
            }
            await manifest.refresh(session: session)
        }
        guard let diff = manifest.diffResult else {
            listProblem = Self.problem(for: manifest.liveFetchError, isOnline: isOnline)
            return
        }
        let found = await VolumeUpdateChecker.updatableVolumes(
            known: diff.known,
            liveInfoByVolumeId: diff.liveInfoByVolumeId,
            downloadManager: downloads
        )
        listed(found)
    }

    /// Re-reads the published list (Refresh Available List), and sets `listProblem` when it cannot.
    ///
    /// - Parameters:
    ///   - manifest: The catalogue and its live listing.
    ///   - isOnline: Whether the device is online.
    ///   - session: The session the list is read through. Default `.shared`.
    func refreshList(manifest: ManifestStore, isOnline: Bool, session: URLSession = .shared) async {
        guard !isRefreshingList else { return }
        isRefreshingList = true
        defer { isRefreshingList = false }
        listProblem = nil
        guard isOnline else {
            listProblem = .offline
            return
        }
        await manifest.refresh(session: session)
        if let error = manifest.liveFetchError {
            listProblem = Self.problem(for: error, isOnline: isOnline)
        }
    }

    /// Replaces the list with what a check found.
    ///
    /// A volume whose update is under way, or failed, keeps its row and its state; one in the
    /// download queue already is listed as already downloading; the rest offer Update. A row
    /// whose update is under way and which the check no longer finds — it is being indexed, so
    /// its new file matches — stays until its update ends. An updated row the check no longer
    /// finds is current, and goes.
    func listed(_ found: [UpdatableVolume]) {
        let previous = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let foundIds = Set(found.map(\.id))
        var next: [Row] = found.map { volume in
            if let row = previous[volume.id], row.status.isUnderWay || row.status.isFailed {
                return row
            }
            let status: Status = queuedVolumeIds.contains(volume.id) ? .alreadyDownloading : .available
            return Row(entry: volume.entry, isSideloaded: volume.isSideloaded, status: status)
        }
        next += rows.filter { $0.status.isUnderWay && !foundIds.contains($0.id) }
        rows = next
        hasChecked = true
    }

    // MARK: - Updating

    /// Queues `volumeId`'s update, from its row's Update or Retry.
    func update(_ volumeId: String, downloads: DownloadManager?) async {
        guard let downloads, let index = index(of: volumeId), rows[index].status.offersUpdate else { return }
        let entry = rows[index].entry
        // Before the queue answers, so a second press cannot ask twice.
        rows[index].status = .queued
        let outcome = await downloads.enqueueDownload(entry, force: true)
        enqueued(volumeId, outcome: outcome)
    }

    /// Queues every row that offers Update or Retry.
    func updateAll(downloads: DownloadManager?) async {
        for id in rows.filter({ $0.status.offersUpdate }).map(\.id) {
            await update(id, downloads: downloads)
        }
    }

    /// Records what the download manager did with an update's request.
    ///
    /// The queue's own reports may already have moved the row on — a download the queue started
    /// at once, or even finished — so a queued request changes nothing here.
    func enqueued(_ volumeId: String, outcome: DownloadEnqueueOutcome) {
        guard let index = index(of: volumeId) else { return }
        switch outcome {
        case .queued:
            break
        case .alreadyQueued:
            if rows[index].status == .queued || rows[index].status == .downloading {
                rows[index].status = .alreadyDownloading
            }
        case .alreadyDownloaded:
            // A forced request is never declined for this; were it, nothing was queued.
            if rows[index].status == .queued { rows[index].status = .available }
        case .noCatalogueURL:
            rows[index].status = .failed(.noCatalogueURL)
        }
    }

    // MARK: - Reports

    /// The download queue changed.
    func downloadStateDidChange(_ state: DownloadManagerState) {
        activeVolumeIds = Set(state.activeVolumeIds)
        queuedVolumeIds = activeVolumeIds.union(state.pendingVolumeIds)
        // Only forward. A row that has started stays Downloading through a failed attempt's wait
        // for its retry, and a row that has left the queue keeps its state until the transfer's
        // own report says how it ended.
        for index in rows.indices where rows[index].status == .queued && activeVolumeIds.contains(rows[index].id) {
            rows[index].status = .downloading
        }
    }

    /// A transfer ended.
    func transferDidFinish(_ volumeId: String, outcome: DownloadTransferOutcome) {
        guard let index = index(of: volumeId) else { return }
        switch outcome {
        case .succeeded:
            // Whatever asked for it, the volume is now the published copy.
            switch rows[index].status {
            case .indexing, .updated: break
            default: rows[index].status = indexesDownloads ? .indexing : .updated
            }
        case .failed(let failure):
            if rows[index].status.isUnderWay && rows[index].status != .indexing {
                rows[index].status = .failed(.download(failure))
            }
        case .cancelled:
            if rows[index].status.isUnderWay && rows[index].status != .indexing {
                rows[index].status = .available
            }
        }
    }

    /// A downloaded volume's re-index ended.
    ///
    /// - Parameters:
    ///   - volumeId: The volume.
    ///   - failure: The index error's description, or `nil` when it succeeded.
    func indexingDidFinish(_ volumeId: String, failure: String?) {
        guard let index = index(of: volumeId), rows[index].status.isUnderWay else { return }
        rows[index].status = failure.map { .failed(.indexing($0)) } ?? .updated
    }

    // MARK: - Helpers

    private func index(of volumeId: String) -> Int? {
        rows.firstIndex { $0.id == volumeId }
    }

    /// What kept the published list from being read.
    ///
    /// - Parameters:
    ///   - error: The fetch's error (`ManifestStore.liveFetchError`).
    ///   - isOnline: Whether the device is online.
    static func problem(for error: (any Error)?, isOnline: Bool) -> ListProblem {
        guard isOnline else { return .offline }
        if let listing = error as? LiveListingError {
            return listing.isRateLimited ? .rateLimited(until: listing.retryAfter)
                                         : .server(status: listing.statusCode)
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                return .offline
            default:
                return .other(urlError.localizedDescription)
            }
        }
        if let error { return .other(error.localizedDescription) }
        return .other(KeepingCurrentCopy.listUnreadable)
    }
}

// MARK: - KeepingCurrentCopy

/// What Keeping Current says about an update and about the published list (#1660).
///
/// Version history:
///   1.0 — #1660: initial implementation
enum KeepingCurrentCopy {

    /// A queued update's status.
    static let queued = String(localized: "settings.hub.corrections.status.queued",
                               defaultValue: "Queued")
    /// A downloading update's status.
    static let downloading = String(localized: "settings.hub.corrections.status.downloading",
                                    defaultValue: "Downloading…")
    /// The status of a row whose volume was already downloading.
    static let alreadyDownloading = String(localized: "settings.hub.corrections.status.alreadyDownloading",
                                           defaultValue: "Already downloading…")
    /// A re-indexing update's status.
    static let indexing = String(localized: "settings.hub.corrections.status.indexing",
                                 defaultValue: "Indexing…")
    /// A finished update's status.
    static let updated = String(localized: "settings.hub.corrections.status.updated",
                                defaultValue: "Updated")
    /// The button a failed row offers.
    static let retry = String(localized: "settings.hub.corrections.retry",
                              defaultValue: "Retry")

    /// The line under a side-loaded copy's title.
    static let sideloaded = String(localized: "settings.hub.corrections.sideloaded",
                                   defaultValue: "Your side-loaded copy. Update replaces it with the published volume.")

    /// The line under a failed row's title.
    static func failure(_ failure: KeepingCurrentModel.Failure) -> String {
        switch failure {
        case .download(let download):
            switch download.urlErrorCode {
            case .notConnectedToInternet?, .networkConnectionLost?, .dataNotAllowed?, .internationalRoamingOff?:
                return String(localized: "settings.hub.corrections.failed.offline",
                              defaultValue: "The download failed: no connection.")
            case .timedOut?:
                return String(localized: "settings.hub.corrections.failed.timedOut",
                              defaultValue: "The download failed: it timed out.")
            case .badServerResponse?:
                return String(localized: "settings.hub.corrections.failed.server",
                              defaultValue: "The download failed: GitHub did not send the volume.")
            default:
                return String(localized: "settings.hub.corrections.failed.other",
                              defaultValue: "The download failed: \(download.description)")
            }
        case .indexing(let description):
            return String(localized: "settings.hub.corrections.failed.indexing",
                          defaultValue: "The volume downloaded, and indexing it failed: \(description)")
        case .noCatalogueURL:
            return String(localized: "settings.hub.corrections.failed.noURL",
                          defaultValue: "This volume has no published copy to download.")
        }
    }

    /// The label of the row that says the published list could not be read.
    static let listProblemLabel = String(localized: "settings.hub.corrections.listProblem",
                                         defaultValue: "Couldn’t read the published list")

    /// The sentence under it: why.
    static func listProblem(_ problem: KeepingCurrentModel.ListProblem) -> String {
        switch problem {
        case .offline:
            return String(localized: "settings.hub.corrections.listProblem.offline",
                          defaultValue: "This device is offline. Checking compares your volumes with the list on GitHub.")
        case .rateLimited(let until?):
            let time = until.formatted(date: .omitted, time: .shortened)
            return String(localized: "settings.hub.corrections.listProblem.rateLimited",
                          defaultValue: "GitHub limits how often it answers one network, and this network has reached the limit. Try again after \(time).")
        case .rateLimited(nil):
            return String(localized: "settings.hub.corrections.listProblem.rateLimited.noTime",
                          defaultValue: "GitHub limits how often it answers one network, and this network has reached the limit. Try again later.")
        case .server(let status):
            return String(localized: "settings.hub.corrections.listProblem.server",
                          defaultValue: "GitHub answered with error \(status). Try again later.")
        case .other(let description):
            return description
        }
    }

    /// The description used when no error was recorded.
    static let listUnreadable = String(localized: "settings.hub.corrections.listProblem.unreadable",
                                       defaultValue: "The list on GitHub could not be read.")
}
