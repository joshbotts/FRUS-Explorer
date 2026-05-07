// SummaryStore.swift
// Persistent store for AI-generated document summaries.
//
// Each SummaryRecord captures the full identity of a generated summary:
// which document (volumeID + divisionID) and which summariser configuration
// (profileID + cached profileName) produced it, plus the generated text and timestamp.
//
// The store is keyed on (volumeID, divisionID, profileID) so that:
//   • Multiple profiles can each have their own summary for the same document.
//   • Summaries can be purged by profile without affecting other profiles.
//   • allSummaryTexts provides a search-ready [nodeID: String] dict covering
//     every stored summary across all profiles and volumes.

import Foundation
import Observation

// MARK: - SummaryRecord

struct SummaryRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let volumeID: String
    let divisionID: String
    let profileID: UUID
    /// Profile name captured at generation time; accurate for display even if
    /// the profile is later renamed or deleted.
    let profileName: String
    let text: String
    let generatedAt: Date

    /// Matches `SearchRecord.id` and `OutlineNode.id` format: "\(volumeID)__\(divisionID)".
    var nodeID: String { "\(volumeID)__\(divisionID)" }
}

// MARK: - SummaryStore

@MainActor
@Observable
final class SummaryStore {

    private(set) var records: [SummaryRecord] = []

    // MARK: - Persistence

    private static let fileName = "summaries.json"

    private static var storageURL: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return support.appending(component: "FRUSExplorer/\(fileName)")
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() { load() }

    // MARK: - Write

    /// Persist a newly generated summary, replacing any existing record for the
    /// same (volumeID, divisionID, profileID) triple.
    func store(
        volumeID: String,
        divisionID: String,
        profileID: UUID,
        profileName: String,
        text: String
    ) {
        records.removeAll {
            $0.volumeID == volumeID &&
            $0.divisionID == divisionID &&
            $0.profileID == profileID
        }
        records.append(SummaryRecord(
            id: UUID(),
            volumeID: volumeID,
            divisionID: divisionID,
            profileID: profileID,
            profileName: profileName,
            text: text,
            generatedAt: Date()
        ))
        save()
    }

    // MARK: - Read

    func lookup(volumeID: String, divisionID: String, profileID: UUID) -> String? {
        records.first {
            $0.volumeID == volumeID &&
            $0.divisionID == divisionID &&
            $0.profileID == profileID
        }?.text
    }

    // MARK: - Purge

    /// Remove all summaries produced by a specific summariser profile.
    func purge(profileID: UUID) {
        records.removeAll { $0.profileID == profileID }
        save()
    }

    /// Remove the single stored summary for one document / profile combination,
    /// used when regenerating a summary.
    func purge(volumeID: String, divisionID: String, profileID: UUID) {
        records.removeAll {
            $0.volumeID == volumeID &&
            $0.divisionID == divisionID &&
            $0.profileID == profileID
        }
        save()
    }

    /// Remove all summaries for a volume (called when the volume file is deleted).
    func purgeVolume(_ volumeID: String) {
        records.removeAll { $0.volumeID == volumeID }
        save()
    }

    // MARK: - Search support

    /// All stored summary texts keyed by `"\(volumeID)__\(divisionID)"`.
    /// When multiple profiles have summaries for the same document, their texts
    /// are concatenated so every profile's content is reachable in a single search pass.
    var allSummaryTexts: [String: String] {
        var result: [String: String] = [:]
        for record in records {
            if let existing = result[record.nodeID] {
                result[record.nodeID] = existing + " " + record.text
            } else {
                result[record.nodeID] = record.text
            }
        }
        return result
    }

    // MARK: - Profile statistics (for purge UI)

    struct ProfileStat: Identifiable {
        let profileID: UUID
        let profileName: String
        let count: Int
        var id: UUID { profileID }
    }

    /// Summary counts grouped by profile, sorted by profile name.
    var profileStats: [ProfileStat] {
        var seen: [UUID: (name: String, count: Int)] = [:]
        for r in records {
            if let existing = seen[r.profileID] {
                seen[r.profileID] = (existing.name, existing.count + 1)
            } else {
                seen[r.profileID] = (r.profileName, 1)
            }
        }
        return seen
            .map { ProfileStat(profileID: $0.key, profileName: $0.value.name, count: $0.value.count) }
            .sorted { $0.profileName < $1.profileName }
    }

    // MARK: - Persistence helpers

    func save() {
        do {
            let data = try encoder.encode(records)
            let url = Self.storageURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            print("[SummaryStore] Save failed: \(error)")
        }
    }

    func load() {
        let url = Self.storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            records = try decoder.decode([SummaryRecord].self, from: data)
        } catch {
            print("[SummaryStore] Load failed: \(error)")
        }
    }
}
