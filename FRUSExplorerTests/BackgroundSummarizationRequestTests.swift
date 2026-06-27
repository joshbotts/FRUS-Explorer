// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - SummarizationScope Codable

struct SummarizationScopeCodableTests {

    private func roundTrip(_ scope: SummarizationScope) throws -> SummarizationScope {
        let data = try JSONEncoder().encode(scope)
        return try JSONDecoder().decode(SummarizationScope.self, from: data)
    }

    @Test("SummarizationScope round-trips through Codable for every case")
    func allCasesRoundTrip() throws {
        let cases: [SummarizationScope] = [
            .volume(volumeId: "frus1969-76v01"),
            .subseries(subseries: "1969-76"),
            .userTag(documentKeys: ["frus1969-76v01/d1", "frus1969-76v01/d2"]),
            .savedSearch(documentKeys: ["frus1952-54v02/d9"]),
            .dateRange(earliest: "1961-01-01", latest: "1963-12-31")
        ]
        for scope in cases {
            #expect(try roundTrip(scope) == scope)
        }
    }
}

// MARK: - Request store

struct BackgroundSummarizationRequestStoreTests {

    private let promptId = UUID()

    private func cleanUp() {
        BackgroundSummarizationRequestStore.setEnabled(false) // also clears the request
    }

    @Test("Store: save/load/clear round-trip when enabled")
    func saveLoadClear() {
        cleanUp()
        BackgroundSummarizationRequestStore.setEnabled(true)
        defer { cleanUp() }

        let request = BackgroundSummarizationRequest(
            scope: .volume(volumeId: "frus1969-76v01"), promptId: promptId)
        BackgroundSummarizationRequestStore.save(request)

        let loaded = BackgroundSummarizationRequestStore.load()
        #expect(loaded == request)
        #expect(BackgroundSummarizationRequestStore.hasPending)

        BackgroundSummarizationRequestStore.clear()
        #expect(BackgroundSummarizationRequestStore.load() == nil)
        #expect(!BackgroundSummarizationRequestStore.hasPending)
    }

    @Test("Store: save is a no-op while background continuation is disabled")
    func saveNoOpWhenDisabled() {
        cleanUp()
        defer { cleanUp() }

        #expect(!BackgroundSummarizationRequestStore.isEnabled)
        BackgroundSummarizationRequestStore.save(
            BackgroundSummarizationRequest(scope: .subseries(subseries: "1969-76"), promptId: promptId))
        #expect(BackgroundSummarizationRequestStore.load() == nil)
        #expect(!BackgroundSummarizationRequestStore.hasPending)
    }

    @Test("Store: disabling clears a pending request")
    func disablingClears() {
        cleanUp()
        BackgroundSummarizationRequestStore.setEnabled(true)
        BackgroundSummarizationRequestStore.save(
            BackgroundSummarizationRequest(scope: .volume(volumeId: "v1"), promptId: promptId))
        #expect(BackgroundSummarizationRequestStore.load() != nil)

        BackgroundSummarizationRequestStore.setEnabled(false)
        #expect(BackgroundSummarizationRequestStore.load() == nil)
    }
}
