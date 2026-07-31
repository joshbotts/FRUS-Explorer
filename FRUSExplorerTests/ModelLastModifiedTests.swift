// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwiftData
import Testing

@testable import FRUSExplorer

// MARK: - ModelLastModifiedTests

/// Whether a `didSet` observer on a `@Model` property fires. It does not.
///
/// `lastModified` is what CloudKit's last-writer-wins resolves on. If it never advances past `init`,
/// a device holding an old copy wins every merge — restoring entries the researcher deleted and
/// reverting edits — and nothing on screen says so.
///
/// Four models kept it current with `didSet` observers — 73 of them — and **none has ever fired**.
/// The `@Model` macro rewrites a stored property into a computed pair backed by the managed store,
/// and a computed property cannot carry a property observer, so the bodies are discarded silently.
///
/// This suite pins that fact rather than lamenting it. If a future SwiftData release begins
/// honouring the observers, these cases fail — which is the signal that `ModelModificationStamper`
/// could be retired and the observers trusted. Until then it is the evidence for why a save-time
/// stamp exists at all.
///
/// Version history:
///   1.0 — M-1 follow-up: initial implementation
@Suite("Model didSet observers do not fire")
@MainActor
struct ModelLastModifiedTests {

    private static let backdated = Date(timeIntervalSince1970: 0)

    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: Project.self, Collection.self, ResearchNote.self, GeneratedSummary.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    /// Whether `lastModified` moved off the epoch after `mutate` ran.
    ///
    /// No stamper is installed in this suite: these cases measure the OBSERVERS alone.
    private func observerFired(_ read: () -> Date?, _ set: (Date?) -> Void, _ mutate: () -> Void) -> Bool {
        set(Self.backdated)
        mutate()
        guard let now = read() else { return false }
        return now > Self.backdated
    }

    @Test("Project: neither a scalar nor an array edit fires its observer")
    func projectObserversAreInert() throws {
        let container = try container()
        let project = Project(name: "Berlin")
        container.mainContext.insert(project)

        let scalar = observerFired({ project.lastModified }, { project.lastModified = $0 },
                                   { project.name = "Berlin 1948" })
        let reassigned = observerFired({ project.lastModified }, { project.lastModified = $0 },
                                       { project.defaultUserTagIds = [UUID()] })
        let appended = observerFired({ project.lastModified }, { project.lastModified = $0 },
                                     { project.defaultUserTagIds.append(UUID()) })
        #expect(!scalar && !reassigned && !appended, """
        A didSet observer on a @Model property fired (scalar: \(scalar), reassign: \(reassigned), \
        append: \(appended)). SwiftData's behaviour has changed — ModelModificationStamper may now \
        be redundant, and Project.swift's original doc comment was right after all.
        """)
        _ = container
    }

    @Test("Collection, ResearchNote and GeneratedSummary behave identically")
    func theOtherThreeAreInertToo() throws {
        let container = try container()
        let collection = Collection(name: "Potsdam")
        let note = ResearchNote(documentId: "d1", volumeId: "v1", bodyText: "first")
        let summary = GeneratedSummary(documentId: "d1", volumeId: "v1",
                                       promptId: UUID(), responseText: "first")
        for model in [collection as any PersistentModel, note, summary] {
            container.mainContext.insert(model)
        }
        let fired = [
            observerFired({ collection.lastModified }, { collection.lastModified = $0 },
                          { collection.name = "Potsdam II" }),
            observerFired({ note.lastModified }, { note.lastModified = $0 },
                          { note.bodyText = "edited" }),
            observerFired({ note.lastModified }, { note.lastModified = $0 },
                          { note.projectIds = [UUID()] }),
            observerFired({ summary.lastModified }, { summary.lastModified = $0 },
                          { summary.responseText = "edited" }),
        ]
        #expect(!fired.contains(true),
                "an observer fired somewhere (\(fired)) — SwiftData's behaviour has changed")
        _ = container
    }

    @Test("Control: the harness CAN see a stamp, so the results above are real")
    func harnessIsSound() throws {
        let container = try container()
        let project = Project(name: "x")
        container.mainContext.insert(project)
        // Stamping by hand — the pattern CustomVolumeScope and WorkingCorpus use. If this fails the
        // suite is measuring its own plumbing and every result above is void.
        let fired = observerFired({ project.lastModified }, { project.lastModified = $0 },
                                  { project.lastModified = Date() })
        #expect(fired, "the harness cannot detect a stamp at all — every other result here is meaningless")
        _ = container
    }
}

// MARK: - ModelModificationStamperTests

/// The save-time stamp that replaces 73 observers which never fired.
///
/// Every case asks whether the stamp reaches the **persisted** row, not merely the in-memory
/// object: a stamp applied during `willSave` but excluded from that save would lag by one write,
/// which is exactly the kind of near-miss that reads as working.
@Suite("Model modification stamper")
@MainActor
struct ModelModificationStamperTests {

    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: Project.self, Collection.self, ResearchNote.self, WorkingCorpus.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @Test("An edit followed by a save advances lastModified in the SAVED row")
    func stampsOnSave() throws {
        let container = try container()
        let context = container.mainContext
        let stamper = ModelModificationStamper()
        stamper.start(observing: context)
        defer { stamper.stop() }

        let project = Project(name: "Berlin")
        context.insert(project)
        try context.save()
        project.lastModified = Date(timeIntervalSince1970: 0)
        try context.save()

        project.name = "Berlin 1948"
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Project>()).first)
        let stamp = try #require(fetched.lastModified)
        #expect(stamp.timeIntervalSince1970 > 0, "the edit did not stamp at all")
        #expect(stamp.timeIntervalSinceNow > -5,
                "the stamp is not current — it lagged the save it should have been part of")
    }

    @Test("It reaches every model that carries the field, not just the one it was written for")
    func stampsEveryStampingModel() throws {
        let container = try container()
        let context = container.mainContext
        let stamper = ModelModificationStamper()
        stamper.start(observing: context)
        defer { stamper.stop() }
        let epoch = Date(timeIntervalSince1970: 0)

        let note = ResearchNote(documentId: "d1", volumeId: "v1", bodyText: "first")
        let collection = Collection(name: "Potsdam")
        context.insert(note)
        context.insert(collection)
        try context.save()
        note.lastModified = epoch
        collection.lastModified = epoch
        try context.save()

        note.bodyText = "edited"
        collection.name = "Potsdam II"
        try context.save()

        #expect(try #require(note.lastModified) > epoch)
        #expect(try #require(collection.lastModified) > epoch)
    }

    @Test("An array edit stamps too — the case the old doc comment got wrong in both directions")
    func stampsArrayEdits() throws {
        let container = try container()
        let context = container.mainContext
        let stamper = ModelModificationStamper()
        stamper.start(observing: context)
        defer { stamper.stop() }

        let note = ResearchNote(documentId: "d1", volumeId: "v1")
        context.insert(note)
        try context.save()
        let epoch = Date(timeIntervalSince1970: 0)

        note.lastModified = epoch
        note.projectIds = [UUID()]
        try context.save()
        #expect(try #require(note.lastModified) > epoch, "whole reassignment did not stamp")

        note.lastModified = epoch
        note.projectIds.append(UUID())
        try context.save()
        #expect(try #require(note.lastModified) > epoch,
                "an in-place append did not stamp — the save hook must cover the case observers never could")
    }

    @Test("An INSERT is not stamped, so a deliberate creation timestamp survives its first save")
    func insertsAreNotStamped() throws {
        let container = try container()
        let context = container.mainContext
        let stamper = ModelModificationStamper()
        stamper.start(observing: context)
        defer { stamper.stop() }

        // A corpus captured with an explicit provenance timestamp. Stamping inserts as well as
        // changes would overwrite it on the very first save — silently rewriting the record of when
        // the evidence was gathered.
        let corpus = WorkingCorpus(name: "OSP", documentKeys: ["v1/d1"])
        corpus.lastModified = Date(timeIntervalSince1970: 0)
        context.insert(corpus)
        try context.save()

        #expect(corpus.lastModified == Date(timeIntervalSince1970: 0),
                "the insert was stamped — a value set deliberately before the first save must survive it")
    }

    @Test("Saving with nothing changed neither stamps nor loops")
    func idleSaveIsInert() throws {
        let container = try container()
        let context = container.mainContext
        let stamper = ModelModificationStamper()
        stamper.start(observing: context)
        defer { stamper.stop() }

        let project = Project(name: "x")
        context.insert(project)
        try context.save()
        let epoch = Date(timeIntervalSince1970: 0)
        project.lastModified = epoch
        try context.save()          // the stamp for THAT change
        let afterFirst = try #require(project.lastModified)

        try context.save()          // nothing changed
        try context.save()
        #expect(project.lastModified == afterFirst,
                "an idle save moved the stamp, so every save rewrites every record and CloudKit churns")
    }

    @Test("Stopping the stamper stops the stamping — the control for every case above")
    func stopIsHonoured() throws {
        let container = try container()
        let context = container.mainContext
        let stamper = ModelModificationStamper()
        stamper.start(observing: context)

        let project = Project(name: "x")
        context.insert(project)
        try context.save()
        stamper.stop()

        let epoch = Date(timeIntervalSince1970: 0)
        project.lastModified = epoch
        project.name = "renamed"
        try context.save()
        // If this ALSO stamped, something other than the stamper is doing it and every result in
        // this suite is attributing the behaviour to the wrong mechanism.
        #expect(project.lastModified == epoch,
                "the stamp survived stop() — the suite is measuring something else")
    }
}
