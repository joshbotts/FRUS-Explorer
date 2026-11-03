// A6 spike (kept in the repository for #1723): the document entity, its query, four intents and the phrases.
import AppIntents
import CoreSpotlight
import Foundation
import FoundationModels

/// `FRUSDocumentEntity` as A7 would sketch it: keyed by the existing `"\(volumeId)/\(documentId)"`.
struct SpikeDocumentEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "FRUS Document"
    static let defaultQuery = SpikeDocumentQuery()

    let id: String

    @Property(title: "Title", indexingKey: \.title)
    var title: String

    @Property(title: "Volume")
    var volume: String

    /// Not a property: the text the attribute set carries, as the app's donation does.
    let body: String

    init(_ document: SpikeDocument) {
        id = document.id
        body = document.body
        title = document.header
        volume = document.group.volumeId
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(volume)")
    }

    /// The app's own fields, as `makeSearchableItem` sets them.
    var attributeSet: CSSearchableItemAttributeSet {
        let attrs = defaultAttributeSet
        attrs.contentDescription = String(body.prefix(300))
        attrs.textContent = String(body.prefix(3_200))
        attrs.keywords = [volume, id]
        return attrs
    }
}

/// Resolves documents from the app's own store, as A7's would from `document_cache`.
struct SpikeDocumentQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpikeDocumentEntity] {
        await SpikeLog.write("query: entities(for: \(identifiers))")
        return identifiers.compactMap { SpikeCorpus.document(id: $0) }.map(SpikeDocumentEntity.init)
    }

    func entities(matching string: String) async throws -> [SpikeDocumentEntity] {
        await SpikeLog.write("query: entities(matching: \"\(string)\")")
        let needle = string.lowercased()
        return SpikeCorpus.documents
            .filter { $0.header.lowercased().contains(needle) || $0.body.lowercased().contains(needle) }
            .map(SpikeDocumentEntity.init)
    }

    func suggestedEntities() async throws -> [SpikeDocumentEntity] {
        await SpikeLog.write("query: suggestedEntities()")
        return SpikeCorpus.documents.map(SpikeDocumentEntity.init)
    }
}

/// 27.0's reindex hooks, gated so the deployment target stays 26.0.
@available(iOS 27.0, *)
extension SpikeDocumentQuery: IndexedEntityQuery {
    func reindexEntities(for identifiers: [String], indexDescription: CSSearchableIndexDescription) async throws {
        await SpikeLog.write("IndexedEntityQuery.reindexEntities(for: \(identifiers.count) ids)")
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        await SpikeLog.write("IndexedEntityQuery.reindexAllEntities")
    }
}

// MARK: - Intents

/// Candidate 1: open a document.
struct OpenSpikeDocumentIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open FRUS Document"

    @Parameter(title: "Document")
    var target: SpikeDocumentEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        SpikeLog.write("OpenSpikeDocumentIntent.perform: \(target.id)")
        SpikeModel.shared.open(target.id, via: "OpenIntent")
        return .result()
    }
}

/// Candidate 2: search the corpus, landing on the app's search screen.
struct SearchSpikeCorpusIntent: ShowInAppSearchResultsIntent {
    static let title: LocalizedStringResource = "Search FRUS"
    static let searchScopes: [StringSearchScope] = [.general]

    @Parameter(title: "Search Terms")
    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some IntentResult {
        SpikeLog.write("SearchSpikeCorpusIntent.perform: \"\(criteria.term)\"")
        SpikeModel.shared.search(criteria.term, via: "ShowInAppSearchResultsIntent")
        return .result()
    }
}

/// Candidate 3: summarize a document, in the background, with the on-device model.
struct SummarizeSpikeDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize FRUS Document"
    static let openAppWhenRun = false

    @Parameter(title: "Document")
    var document: SpikeDocumentEntity

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        await SpikeLog.write("SummarizeSpikeDocumentIntent.perform: \(document.id)")
        let text: String
        switch SystemLanguageModel.default.availability {
        case .available:
            let session = LanguageModelSession(instructions: "Summarize the document in two sentences.")
            text = try await session.respond(to: document.body).content
        case .unavailable(let reason):
            text = "The on-device model is unavailable: \(reason)"
        }
        await SpikeLog.write("SummarizeSpikeDocumentIntent result: \(text.prefix(200))")
        return .result(value: text, dialog: "\(text)")
    }
}

/// Candidate 4 stands in for Add to Collection: a write to the app's own store, without UI.
struct ReadLaterSpikeDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Add FRUS Document to Read Later"
    static let openAppWhenRun = false

    @Parameter(title: "Document")
    var document: SpikeDocumentEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        SpikeLog.write("ReadLaterSpikeDocumentIntent.perform: \(document.id)")
        var list = UserDefaults.standard.stringArray(forKey: "readLater") ?? []
        list.append(document.id)
        UserDefaults.standard.set(list, forKey: "readLater")
        return .result(dialog: "Added \(document.title).")
    }
}

/// 27.0's schema intents, gated: does the macro compile under a 26.0 target? The metadata processor
/// refuses this one beside `OpenSpikeDocumentIntent` ("OpenIntent targets should be unique"), so it is
/// built only in the variant that drops the classic one.
#if SPIKE_SCHEMA_OPEN
@available(iOS 27.0, *)
@AppIntent(schema: .system.open)
struct OpenSpikeDocumentSchemaIntent: OpenIntent {
    var target: SpikeDocumentEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        SpikeLog.write("OpenSpikeDocumentSchemaIntent.perform: \(target.id)")
        SpikeModel.shared.open(target.id, via: ".system.open")
        return .result()
    }
}
#endif

@available(iOS 27.0, *)
@AppIntent(schema: .system.searchInApp)
struct SearchSpikeSchemaIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]
    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some IntentResult {
        SpikeLog.write("SearchSpikeSchemaIntent.perform: \"\(criteria.term)\"")
        SpikeModel.shared.search(criteria.term, via: ".system.searchInApp")
        return .result()
    }
}

// MARK: - Phrases

struct SpikeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        #if SPIKE_NO_PARAM_SHORTCUTS
        AppShortcut(
            intent: OpenSpikeDocumentIntent(),
            phrases: ["Open a document in \(.applicationName)"],
            shortTitle: "Open Document", systemImageName: "doc.text")
        #else
        AppShortcut(
            intent: OpenSpikeDocumentIntent(),
            phrases: ["Open \(\.$target) in \(.applicationName)", "Open a document in \(.applicationName)"],
            shortTitle: "Open Document", systemImageName: "doc.text")
        #endif
        AppShortcut(
            intent: SearchSpikeCorpusIntent(),
            phrases: ["Search \(.applicationName)", "Search in \(.applicationName)"],
            shortTitle: "Search", systemImageName: "magnifyingglass")
        #if SPIKE_NO_PARAM_SHORTCUTS
        AppShortcut(
            intent: SummarizeSpikeDocumentIntent(),
            phrases: ["Summarize a document in \(.applicationName)"],
            shortTitle: "Summarize", systemImageName: "text.quote")
        #else
        AppShortcut(
            intent: SummarizeSpikeDocumentIntent(),
            phrases: ["Summarize \(\.$document) in \(.applicationName)", "Summarize a document in \(.applicationName)"],
            shortTitle: "Summarize", systemImageName: "text.quote")
        #endif
        AppShortcut(
            intent: ReadLaterSpikeDocumentIntent(),
            phrases: ["Add a document to Read Later in \(.applicationName)"],
            shortTitle: "Read Later", systemImageName: "bookmark")
    }
}
