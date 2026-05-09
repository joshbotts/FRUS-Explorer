// SummaryPromptProfile.swift
// Model and persistence for user-customisable summarisation prompt profiles.

import Foundation
import Observation

// MARK: - OutputFormat

/// Controls how the model is asked to structure its output.
public enum SummaryOutputFormat: String, Codable, CaseIterable, Sendable {
    /// Exactly three sentences: type/date/parties · subject/decision · significance.
    /// This is the default and matches the standard FRUS summary convention.
    case threeSentence = "three_sentence"

    /// A free-form analytical paragraph of up to ~120 words, structured around
    /// the user's research focus rather than the standard three-part skeleton.
    case analyticalParagraph = "analytical_paragraph"

    /// A structured set of labelled fields: Who, What, Where/When, Significance,
    /// plus one field whose label is drawn from the profile's focusLabel.
    case structuredFields = "structured_fields"

    var displayName: String {
        switch self {
        case .threeSentence:      return "Three sentences (default)"
        case .analyticalParagraph: return "Analytical paragraph"
        case .structuredFields:   return "Structured fields"
        }
    }

    var description: String {
        switch self {
        case .threeSentence:
            return "A concise three-sentence summary: document type and parties, main subject, historical significance."
        case .analyticalParagraph:
            return "A free-form paragraph up to ~120 words structured around your research focus."
        case .structuredFields:
            return "Labelled fields — Who, What, When/Where, Significance, plus your custom focus field."
        }
    }
}

// MARK: - SummaryPromptProfile

/// A named, user-editable configuration for how the on-device model summarises
/// FRUS documents.  Profiles are stored in Application Support as JSON.
public struct SummaryPromptProfile: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    /// Short display name, e.g. "Institutional History".
    public var name: String
    /// A one-paragraph description of the research goal shown in the UI.
    public var researchDescription: String
    /// The core instruction injected into both system prompt and user prompt.
    /// Written in second-person imperative addressed to the model.
    /// Example: "Emphasise which bureaus, offices, or officials were involved in
    /// reaching or implementing the decision described, and how authority was
    /// exercised or delegated within the bureaucracy."
    public var emphasisInstruction: String
    /// Optional label for the custom field when format == .structuredFields,
    /// e.g. "Bureaucratic actors".
    public var focusLabel: String
    /// Output format preference.
    public var outputFormat: SummaryOutputFormat
    /// Whether this profile was supplied by the app (cannot be deleted).
    public let isBuiltIn: Bool
    public let createdAt: Date
    public var modifiedAt: Date

    nonisolated public init(
        id: UUID = UUID(),
        name: String,
        researchDescription: String,
        emphasisInstruction: String,
        focusLabel: String = "",
        outputFormat: SummaryOutputFormat = .threeSentence,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.researchDescription = researchDescription
        self.emphasisInstruction = emphasisInstruction
        self.focusLabel = focusLabel
        self.outputFormat = outputFormat
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    mutating func touch() { modifiedAt = Date() }
}

// MARK: - Built-in profiles

extension SummaryPromptProfile {
    nonisolated static let builtIns: [SummaryPromptProfile] = [
        defaultProfile,
        institutionalHistory,
        bilateralRelations,
        crisisDecisionMaking,
        economicTrade,
        intelligenceCovert,
    ]

    /// The standard three-sentence summary — used when no custom profile is active.
    nonisolated static let defaultProfile = SummaryPromptProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Default",
        researchDescription: "A general-purpose summary identifying document type, main subject, and historical significance.",
        emphasisInstruction: "Identify the document type, the principal parties or countries involved, the main subject or decision, and its historical significance or outcome.",
        focusLabel: "Significance",
        outputFormat: .threeSentence,
        isBuiltIn: true
    )

    nonisolated static let institutionalHistory = SummaryPromptProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Institutional History",
        researchDescription: "Research on the organisation and management of the Department of State and other foreign-affairs agencies: how policy was coordinated within the bureaucracy, which offices or bureaus were involved, and how authority was exercised or delegated.",
        emphasisInstruction: "Emphasise which bureaus, offices, or named officials were responsible for drafting, coordinating, or implementing the policy described. Note how authority flowed between levels of the hierarchy (desk officer → bureau → under secretary → secretary) and whether inter-agency coordination bodies (NSC, EXCOM, SIG, etc.) were involved. Where relevant, note procedural or institutional constraints that shaped the outcome.",
        focusLabel: "Bureaucratic actors",
        outputFormat: .analyticalParagraph,
        isBuiltIn: true
    )

    nonisolated static let bilateralRelations = SummaryPromptProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Bilateral Relations",
        researchDescription: "Research tracing the arc of U.S. relations with a specific country or region: key negotiating positions, points of agreement or friction, and the evolution of U.S. policy objectives.",
        emphasisInstruction: "Focus on the bilateral relationship between the countries involved: the U.S. negotiating position, the counterpart's stated position, points of agreement or disagreement, and any shift in U.S. policy objectives toward that country. Note the channel through which the exchange took place (embassy cable, NSC meeting, backchannel, etc.).",
        focusLabel: "Relationship dynamic",
        outputFormat: .threeSentence,
        isBuiltIn: true
    )

    nonisolated static let crisisDecisionMaking = SummaryPromptProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Crisis Decision-Making",
        researchDescription: "Research on how U.S. policymakers responded under time pressure: the options considered, who recommended what, the decision actually taken, and the information environment at the time.",
        emphasisInstruction: "Emphasise the decision-making process under pressure: what options were presented, who advocated for each, what information was available or missing, and what decision was ultimately taken and by whom. Note any dissent recorded and the timeline of events.",
        focusLabel: "Decision taken",
        outputFormat: .structuredFields,
        isBuiltIn: true
    )

    nonisolated static let economicTrade = SummaryPromptProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Economic & Trade Policy",
        researchDescription: "Research on U.S. international economic policy: trade negotiations, monetary policy, sanctions, aid, and the intersection of economic interests with diplomatic objectives.",
        emphasisInstruction: "Focus on the economic or commercial dimensions of the document: trade flows, tariff or quota negotiations, monetary or financial arrangements, aid or loan terms, sanctions regimes, or the role of economic leverage in achieving diplomatic objectives. Identify the economic agencies involved (Treasury, Commerce, USTR, ExIm Bank, etc.) alongside State.",
        focusLabel: "Economic mechanism",
        outputFormat: .threeSentence,
        isBuiltIn: true
    )

    nonisolated static let intelligenceCovert = SummaryPromptProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        name: "Intelligence & Covert Action",
        researchDescription: "Research on the intelligence dimension of U.S. foreign policy: assessments, collection activities, covert operations, and the role of the intelligence community in shaping or carrying out policy.",
        emphasisInstruction: "Identify any intelligence assessments, estimates, or collection activities described. Note the role of the CIA, NSA, DIA, or other intelligence community elements. If a covert action is referenced, describe its objective and the level of authorisation recorded. Highlight any tension between intelligence assessments and stated policy.",
        focusLabel: "Intelligence dimension",
        outputFormat: .analyticalParagraph,
        isBuiltIn: true
    )
}

// MARK: - PromptProfileStore

/// Manages the set of `SummaryPromptProfile` values and the active profile selection.
/// When the active profile changes, it posts a notification so `AppStore` can
/// invalidate its summary cache.
@MainActor
@Observable
final class PromptProfileStore {

    private(set) var profiles: [SummaryPromptProfile] = []
    var activeProfileID: UUID = SummaryPromptProfile.defaultProfile.id

    // MARK: Computed

    var activeProfile: SummaryPromptProfile {
        profiles.first(where: { $0.id == activeProfileID })
            ?? SummaryPromptProfile.defaultProfile
    }

    // MARK: Persistence

    private static let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(component: "FRUSExplorer/promptProfiles.json")
    }()

    private static let activeIDKey = "activePromptProfileID"

    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    init() {
        load()
    }

    // MARK: - CRUD

    func create(name: String = "New Profile") -> SummaryPromptProfile {
        let p = SummaryPromptProfile(
            name: name,
            researchDescription: "",
            emphasisInstruction: "",
            isBuiltIn: false
        )
        profiles.append(p)
        save()
        return p
    }

    /// Duplicate an existing profile (built-in profiles can be duplicated but not edited directly).
    func duplicate(_ profile: SummaryPromptProfile) -> SummaryPromptProfile {
        var copy = profile
        copy = SummaryPromptProfile(
            name: profile.name + " (copy)",
            researchDescription: profile.researchDescription,
            emphasisInstruction: profile.emphasisInstruction,
            focusLabel: profile.focusLabel,
            outputFormat: profile.outputFormat,
            isBuiltIn: false
        )
        profiles.append(copy)
        save()
        return copy
    }

    func update(_ profile: SummaryPromptProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var updated = profile
        updated.touch()
        profiles[idx] = updated
        save()
    }

    func delete(_ profile: SummaryPromptProfile) {
        guard !profile.isBuiltIn else { return }
        profiles.removeAll { $0.id == profile.id }
        if activeProfileID == profile.id {
            activeProfileID = SummaryPromptProfile.defaultProfile.id
        }
        save()
    }

    func activate(_ profile: SummaryPromptProfile) {
        guard activeProfileID != profile.id else { return }
        activeProfileID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: Self.activeIDKey)
        // Notify so AppStore can invalidate the summary cache
        NotificationCenter.default.post(name: .summaryProfileDidChange, object: nil)
    }

    // MARK: - Persistence

    func save() {
        do {
            // Only persist user-created profiles; built-ins are always reconstructed at launch.
            let userProfiles = profiles.filter { !$0.isBuiltIn }
            let data = try encoder.encode(userProfiles)
            let url = Self.storageURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[PromptProfileStore] Save failed: \(error)")
        }
    }

    func load() {
        // Always start with built-ins
        var result: [SummaryPromptProfile] = SummaryPromptProfile.builtIns

        // Append persisted user profiles
        let url = Self.storageURL
        if FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let userProfiles = try? decoder.decode([SummaryPromptProfile].self, from: data) {
            result.append(contentsOf: userProfiles)
        }
        profiles = result

        // Restore active selection
        if let savedID = UserDefaults.standard.string(forKey: Self.activeIDKey),
           let uuid = UUID(uuidString: savedID),
           result.contains(where: { $0.id == uuid }) {
            activeProfileID = uuid
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let summaryProfileDidChange = Notification.Name("FRUSExplorer.summaryProfileDidChange")
}
