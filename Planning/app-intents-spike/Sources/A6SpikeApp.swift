// A6 spike (kept in the repository for #1723): the app shell, its log, and the landing paths.
import AppIntents
import CoreSpotlight
import OSLog
import SwiftUI
import UIKit

@main
struct A6SpikeApp: App {
    @State private var model = SpikeModel.shared

    init() {
        SpikeShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                    SpikeLog.write("landed: CSSearchableItemActionType id=\(identifier ?? "nil") "
                        + "userInfo keys=\(activity.userInfo.map { $0.keys.map { "\($0)" }.sorted() } ?? [])")
                    if let identifier { model.open(identifier, via: "CSSearchableItemActionType") }
                }
                .onContinueUserActivity(SpikeModel.documentActivityType) { activity in
                    SpikeLog.write("landed: document activity \(activity.userInfo ?? [:])")
                }
                .task { await model.runLaunchActions() }
        }
    }
}

/// The spike's one model: what is open, what was searched, and the launch's scripted actions.
@MainActor
@Observable
final class SpikeModel {
    static let shared = SpikeModel()
    static let documentActivityType = "bottsywattsy.A6Spike.document"

    var openedId: String?
    var searchTerm = ""
    var lastLanding = "none"
    var logTail: [String] = []

    func open(_ id: String, via path: String) {
        openedId = id
        lastLanding = "\(path) → \(id)"
    }

    func search(_ term: String, via path: String) {
        openedId = nil
        searchTerm = term
        lastLanding = "\(path) → search \"\(term)\""
    }

    /// `--spike=inspect,donate,query` runs those steps in order at launch.
    func runLaunchActions() async {
        let device = UIDevice.current
        SpikeLog.write("launch: \(device.model) \(device.systemName) \(device.systemVersion), "
            + "indexing available=\(CSSearchableIndex.isIndexingAvailable())")
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--spike=") })
        else { return }
        for step in argument.dropFirst("--spike=".count).split(separator: ",") {
            await run(String(step))
        }
    }

    func run(_ step: String) async {
        SpikeLog.write("step: \(step)")
        switch step {
        case "inspect": SpikeDonation.inspect()
        case "donate": await SpikeDonation.donate()
        case "associate-existing": await SpikeDonation.associateExisting()
        case "query": await SpikeDonation.query()
        case "delete-domains": await SpikeDonation.deleteDomains()
        case "assoc-query": await SpikeDonation.associationQuery()
        case "expiry-donate":
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = "Expiry probe Zanthorel"
            attrs.textContent = "Zanthorel expiry probe"
            let item = CSSearchableItem(uniqueIdentifier: "spike-expiry/d1", domainIdentifier: "spike-expiry", attributeSet: attrs)
            item.expirationDate = Date().addingTimeInterval(60)
            do {
                try await CSSearchableIndex.default().indexSearchableItems([item])
                SpikeLog.write("expiry-donate: one item expiring \(item.expirationDate.map { "\($0)" } ?? "nil")")
            } catch { SpikeLog.write("expiry-donate: FAILED \(error)") }
            await SpikeDonation.rawQuery("title == \"*Zanthorel*\"cd")
        case "expiry-query":
            await SpikeDonation.rawQuery("title == \"*Zanthorel*\"cd")
        case "delete-entities":
            do {
                try await CSSearchableIndex.default().deleteAppEntities(ofType: SpikeDocumentEntity.self)
                SpikeLog.write("deleteAppEntities(ofType:) done")
            } catch { SpikeLog.write("deleteAppEntities(ofType:) FAILED \(error)") }
            await SpikeDonation.query()
        default:
            if step.hasPrefix("q:") { await SpikeDonation.rawQuery(String(step.dropFirst(2))) }
            else { SpikeLog.write("step: unknown \(step)") }
        }
    }
}

/// Every line goes to the unified log and to `Documents/spike-log.txt`.
@MainActor
enum SpikeLog {
    static let logger = Logger(subsystem: "bottsywattsy.A6Spike", category: "Spike")
    static let url = URL.documentsDirectory.appending(path: "spike-log.txt")

    static func write(_ line: String) {
        let stamped = "\(Date().formatted(.iso8601)) \(line)"
        logger.notice("\(stamped, privacy: .public)")
        SpikeModel.shared.logTail.append(stamped)
        if SpikeModel.shared.logTail.count > 200 { SpikeModel.shared.logTail.removeFirst() }
        let data = Data((stamped + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}

struct ContentView: View {
    @Bindable var model: SpikeModel

    var body: some View {
        NavigationStack {
            List {
                Section("Landing") {
                    Text(model.lastLanding).font(.footnote.monospaced())
                }
                if let id = model.openedId, let document = SpikeCorpus.document(id: id) {
                    Section("Open document") {
                        DocumentPane(document: document)
                    }
                }
                Section("Search") {
                    TextField("Search", text: $model.searchTerm)
                    ForEach(SpikeCorpus.documents.filter { matches($0) }, id: \.self) { document in
                        Button(document.header) { model.open(document.id, via: "list") }
                    }
                }
                Section("Steps") {
                    ForEach(["inspect", "donate", "associate-existing", "query", "assoc-query", "expiry-donate", "expiry-query", "delete-domains"], id: \.self) { step in
                        Button(step) { Task { await model.run(step) } }
                    }
                }
                Section("Log") {
                    ForEach(Array(model.logTail.suffix(40).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption2.monospaced())
                    }
                }
            }
            .navigationTitle("Spike Reader")
        }
    }

    private func matches(_ document: SpikeDocument) -> Bool {
        let term = model.searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        return term.isEmpty || document.header.lowercased().contains(term) || document.body.lowercased().contains(term)
    }
}

/// The open document, which publishes the activity Siri reads for "this document" (iOS 18.2+).
struct DocumentPane: View {
    let document: SpikeDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.header).font(.headline)
            Text(document.id).font(.caption.monospaced())
            Text(document.body).font(.body)
        }
        .userActivity(SpikeModel.documentActivityType, element: document) { document, activity in
            activity.title = document.header
            activity.userInfo = ["id": document.id]
            activity.appEntityIdentifier = EntityIdentifier(for: SpikeDocumentEntity.self, identifier: document.id)
        }
    }
}
