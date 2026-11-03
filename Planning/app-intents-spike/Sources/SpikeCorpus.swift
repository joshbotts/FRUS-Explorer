// A6 spike (kept in the repository for #1723): fictional FRUS-shaped documents in five donation groups.
import Foundation

/// How a group's documents reach Spotlight.
enum DonationGroup: String, CaseIterable, Sendable {
    /// Exactly as FRUS Explorer's `makeSearchableItem` donates today: no entity.
    case plain
    /// The same item, with `associateAppEntity(_:priority:)` (iOS 18) called before donation.
    case associated
    /// Donated plain first; a later `isUpdate` item carries only the association.
    case updateLater
    /// The same item, with 27.0's `relatedAppEntityIdentifier` set on its attribute set.
    case relatedIdentifier
    /// No `CSSearchableItem` of the app's own: `CSSearchableIndex.indexAppEntities(_:)`.
    case indexedEntity

    /// The volume id, which is also the item's domain.
    var volumeId: String { "spike-\(rawValue)" }

    /// The one word only this group's documents contain.
    var marker: String {
        switch self {
        case .plain: "Quillmere"
        case .associated: "Varrowind"
        case .updateLater: "Tessaloon"
        case .relatedIdentifier: "Ombrevale"
        case .indexedEntity: "Corvantis"
        }
    }

    /// The group's topic, for a question that does not name the marker.
    var topic: String {
        switch self {
        case .plain: "a harbor dispute over fishing rights"
        case .associated: "emergency grain shipments for famine relief"
        case .updateLater: "base rights for a military airfield"
        case .relatedIdentifier: "the resettlement of refugees after a border war"
        case .indexedEntity: "monitoring stations for a nuclear test ban"
        }
    }
}

/// One fictional document.
struct SpikeDocument: Sendable, Hashable {
    let group: DonationGroup
    let documentId: String
    let header: String
    let body: String

    /// The FRUS Explorer identifier shape: `"\(volumeId)/\(documentId)"`.
    var id: String { "\(group.volumeId)/\(documentId)" }
}

enum SpikeCorpus {
    static let documents: [SpikeDocument] = DonationGroup.allCases.flatMap { group in
        [
            SpikeDocument(
                group: group, documentId: "d1",
                header: "Telegram From the Embassy in \(group.marker) to the Department of State",
                body: """
                \(group.marker), March 3, 1957, 4 p.m. 412. Ambassador met this morning with the Foreign \
                Minister of \(group.marker) on \(group.topic). The Minister said his government could not \
                accept the present arrangement and asked that the United States use its good offices. I told \
                him the Department was studying the question and would reply within the week. He then raised \
                \(group.topic) a second time, saying that public opinion in \(group.marker) would not wait. \
                Recommend the Department authorize me to say that the United States favors direct talks \
                between the parties, without prejudice to either position. (This document is fictional: it \
                was written for a FRUS Explorer spike and does not appear in the Foreign Relations series.)
                """),
            SpikeDocument(
                group: group, documentId: "d2",
                header: "Memorandum of Conversation: \(group.marker) and \(group.topic.capitalized)",
                body: """
                Washington, March 9, 1957. SUBJECT: \(group.topic.capitalized). PARTICIPANTS: The Secretary \
                of State; the Ambassador of \(group.marker). The Ambassador presented his government's views \
                on \(group.topic) and left an aide-mémoire. The Secretary said the United States hoped for a \
                settlement acceptable to both sides and would consider any proposal \(group.marker) put \
                forward. (Fictional, for a FRUS Explorer spike.)
                """),
        ]
    }

    static func document(id: String) -> SpikeDocument? { documents.first { $0.id == id } }
}
