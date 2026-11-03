// A6 spike (kept in the repository for #1723): the five donation paths, a read-back, and an inspection.
import AppIntents
import CoreSpotlight
import Foundation

@MainActor
enum SpikeDonation {

    /// FRUS Explorer's `makeSearchableItem`, field for field (`IndexingPipeline+App.swift`).
    nonisolated static func makeSearchableItem(_ document: SpikeDocument) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = document.header
        attrs.contentDescription = String(document.body.prefix(300))
        attrs.keywords = [document.group.volumeId, document.documentId]
        attrs.textContent = String(document.body.prefix(3_200))
        return CSSearchableItem(uniqueIdentifier: document.id, domainIdentifier: document.group.volumeId,
                                attributeSet: attrs)
    }

    /// A synchronous helper, so the iOS 18 overload is the one called.
    nonisolated static func associate(_ item: CSSearchableItem, with document: SpikeDocument) {
        item.associateAppEntity(SpikeDocumentEntity(document), priority: 0)
    }

    static func documents(in group: DonationGroup) -> [SpikeDocument] {
        SpikeCorpus.documents.filter { $0.group == group }
    }

    /// Phase 1: every group as designed; `updateLater` goes in plain.
    static func donate() async {
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteAllSearchableItems()
            SpikeLog.write("donate: deleted all items")

            let plain = documents(in: .plain).map(makeSearchableItem)
            try await index.indexSearchableItems(plain)
            SpikeLog.write("donate: plain \(plain.count) items")

            let associated = documents(in: .associated).map { document in
                let item = makeSearchableItem(document)
                associate(item, with: document)
                return item
            }
            try await index.indexSearchableItems(associated)
            SpikeLog.write("donate: associated \(associated.count) items")

            let later = documents(in: .updateLater).map(makeSearchableItem)
            try await index.indexSearchableItems(later)
            SpikeLog.write("donate: updateLater \(later.count) items, plain for now")

            if #available(iOS 27.0, *) {
                let related = documents(in: .relatedIdentifier).map { document in
                    let item = makeSearchableItem(document)
                    item.attributeSet.relatedAppEntityIdentifier =
                        EntityIdentifier(for: SpikeDocumentEntity.self, identifier: document.id)
                    return item
                }
                try await index.indexSearchableItems(related)
                SpikeLog.write("donate: relatedIdentifier \(related.count) items")
            } else {
                SpikeLog.write("donate: relatedIdentifier skipped, iOS < 27")
            }

            let entities = documents(in: .indexedEntity).map(SpikeDocumentEntity.init)
            // `indexAppEntities` is @concurrent on a non-Sendable index: strict concurrency refuses
            // `index` (held on the main actor), so the call takes a fresh index of its own.
            try await CSSearchableIndex.default().indexAppEntities(entities, priority: 0)
            SpikeLog.write("donate: indexAppEntities \(entities.count) entities")
        } catch {
            SpikeLog.write("donate: FAILED \(error)")
        }
    }

    /// Phase 2, in a later launch: associate the already-donated `updateLater` items by update alone.
    static func associateExisting() async {
        let items = documents(in: .updateLater).map { document in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            let item = CSSearchableItem(uniqueIdentifier: document.id, domainIdentifier: document.group.volumeId,
                                        attributeSet: attrs)
            associate(item, with: document)
            item.isUpdate = true
            return item
        }
        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
            SpikeLog.write("associateExisting: \(items.count) isUpdate items carrying only the association")
        } catch {
            SpikeLog.write("associateExisting: FAILED \(error)")
        }
    }

    /// Reads each group back from the app's own index.
    static func query() async {
        for group in DonationGroup.allCases {
            let context = CSSearchQueryContext()
            context.fetchAttributes = ["title", "textContent", "contentDescription", "keywords"]
            let query = CSSearchQuery(
                queryString: "textContent == \"*\(group.marker)*\"cd || title == \"*\(group.marker)*\"cd",
                queryContext: context)
            var rows: [String] = []
            do {
                for try await result in query.results {
                    let item = result.item
                    let attrs = item.attributeSet
                    rows.append("\(item.uniqueIdentifier) domain=\(item.domainIdentifier ?? "nil") "
                        + "title=\(attrs.title.map { String($0.prefix(40)) } ?? "nil") "
                        + "text=\(attrs.textContent?.count ?? -1) desc=\(attrs.contentDescription?.count ?? -1) "
                        + "keywords=\(attrs.keywords ?? [])")
                }
                SpikeLog.write("query \(group.rawValue) [\(group.marker)]: \(rows.count) rows")
                for row in rows { SpikeLog.write("  \(row)") }
            } catch {
                SpikeLog.write("query \(group.rawValue): FAILED \(error)")
            }
        }
    }

    /// Which items carry an association, by querying the attributes the association writes.
    static func associationQuery() async {
        for attribute in ["kMDItemAppEntityTitle", "_kMDItemAppEntityInstanceIdentifier",
                          "_kMDItemAppEntityTypeIdentifier", "kMDItemRelatedUniqueIdentifier"] {
            let query = CSSearchQuery(queryString: "\(attribute) == \"*\"", queryContext: CSSearchQueryContext())
            var ids: [String] = []
            do {
                for try await result in query.results { ids.append(result.item.uniqueIdentifier) }
                SpikeLog.write("assoc-query \(attribute): \(ids.count) items \(ids.sorted())")
            } catch {
                SpikeLog.write("assoc-query \(attribute): FAILED \(error)")
            }
        }
    }

    /// Any query string, logging the identifiers it matches.
    static func rawQuery(_ string: String) async {
        let query = CSSearchQuery(queryString: string, queryContext: CSSearchQueryContext())
        var ids: [String] = []
        do {
            for try await result in query.results { ids.append(result.item.uniqueIdentifier) }
            SpikeLog.write("q \(string): \(ids.count) items \(ids.sorted())")
        } catch {
            SpikeLog.write("q \(string): FAILED \(error)")
        }
    }

    /// Removes two groups by domain, as removing a volume does, and reads everything back.
    static func deleteDomains() async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(
                withDomainIdentifiers: [DonationGroup.associated.volumeId, DonationGroup.indexedEntity.volumeId])
            SpikeLog.write("deleteDomains: spike-associated and spike-indexedEntity")
        } catch {
            SpikeLog.write("deleteDomains: FAILED \(error)")
        }
        await query()
    }

    /// What each path puts on the item, measured on the objects before donation.
    static func inspect() {
        guard let document = documents(in: .associated).first else { return }

        let plain = makeSearchableItem(document)
        let expiry: Date? = plain.expirationDate
        let days = expiry.map { $0.timeIntervalSinceNow / 86_400 } ?? -1
        SpikeLog.write("inspect: default expirationDate \(expiry.map { "\($0)" } ?? "nil") "
            + "(\(String(format: "%.2f", days)) days from now)")
        let plainStrings = archiveStrings(plain.attributeSet)
        SpikeLog.write("inspect: plain attributeSet \(plainStrings.bytes) bytes archived")

        let associated = makeSearchableItem(document)
        associate(associated, with: document)
        let assocStrings = archiveStrings(associated.attributeSet)
        SpikeLog.write("inspect: associated attributeSet \(assocStrings.bytes) bytes archived "
            + "(+\(assocStrings.bytes - plainStrings.bytes))")
        for string in assocStrings.strings.subtracting(plainStrings.strings).sorted() {
            SpikeLog.write("  + \(string.prefix(160))")
        }
        if #available(iOS 27.0, *) {
            SpikeLog.write("inspect: associated item's relatedAppEntityIdentifier = "
                + "\(associated.relatedAppEntityIdentifier.map { "\($0)" } ?? "nil"); attributeSet's = "
                + "\(associated.attributeSet.relatedAppEntityIdentifier.map { "\($0)" } ?? "nil")")

            let related = makeSearchableItem(document)
            related.attributeSet.relatedAppEntityIdentifier =
                EntityIdentifier(for: SpikeDocumentEntity.self, identifier: document.id)
            let relatedStrings = archiveStrings(related.attributeSet)
            SpikeLog.write("inspect: relatedIdentifier attributeSet \(relatedStrings.bytes) bytes archived "
                + "(+\(relatedStrings.bytes - plainStrings.bytes))")
            for string in relatedStrings.strings.subtracting(plainStrings.strings).sorted() {
                SpikeLog.write("  + \(string.prefix(160))")
            }
        }

        let fromEntity = CSSearchableItem(appEntity: SpikeDocumentEntity(document))
        let entityStrings = archiveStrings(fromEntity.attributeSet)
        SpikeLog.write("inspect: CSSearchableItem(appEntity:) uniqueIdentifier=\(fromEntity.uniqueIdentifier) "
            + "domain=\(fromEntity.domainIdentifier ?? "nil") title=\(fromEntity.attributeSet.title ?? "nil") "
            + "text=\(fromEntity.attributeSet.textContent?.count ?? -1) "
            + "expires in \(String(format: "%.2f", ((fromEntity.expirationDate as Date?)?.timeIntervalSinceNow ?? -86_400) / 86_400)) days; "
            + "\(entityStrings.bytes) bytes archived")
        for string in entityStrings.strings.subtracting(plainStrings.strings).sorted() {
            SpikeLog.write("  + \(string.prefix(160))")
        }
    }

    /// The strings inside an attribute set's keyed archive, and its size.
    private static func archiveStrings(_ attrs: CSSearchableItemAttributeSet) -> (bytes: Int, strings: Set<String>) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: attrs, requiringSecureCoding: true),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let objects = plist["$objects"] as? [Any]
        else { return (0, []) }
        var strings = Set<String>()
        func collect(_ value: Any) {
            switch value {
            case let string as String: strings.insert(string)
            case let array as [Any]: array.forEach(collect)
            case let dictionary as [String: Any]:
                for (key, inner) in dictionary {
                    strings.insert(key)
                    collect(inner)
                }
            case let data as Data:
                strings.insert("<data \(data.count) bytes>")
                // The printable runs inside, so the log says what an association stores.
                var run = ""
                for byte in data {
                    if byte >= 0x20 && byte < 0x7f { run.append(Character(UnicodeScalar(byte))) } else {
                        if run.count >= 6 { strings.insert("  run: \(run)") }
                        run = ""
                    }
                }
                if run.count >= 6 { strings.insert("  run: \(run)") }
            default: break
            }
        }
        objects.forEach(collect)
        return (data.count, strings)
    }
}
