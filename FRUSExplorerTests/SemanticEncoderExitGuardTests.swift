// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

/// The exit guard's bookkeeping (the Mac quit-crash fix): every registered free action runs
/// EXACTLY once, whichever of `unregister` (a deliberate unload) or `drain` (the exit handler)
/// reaches it first. The at-exit ORDERING itself — handler before ggml's static destructor —
/// cannot be tested in-process; it was proven by the standalone probe the type's doc comment
/// records, and this suite pins the half that can regress silently in Swift.
@Suite("Semantic encoder exit guard")
struct SemanticEncoderExitGuardTests {

    @Test("Unregister reclaims the free action exactly once")
    func unregisterReclaimsOnce() {
        let guardian = SemanticEncoderExitGuard()
        nonisolated(unsafe) var freed = 0
        let token = guardian.register { freed += 1 }

        let first = guardian.unregister(token)
        #expect(first != nil)
        first?()
        #expect(freed == 1)
        #expect(guardian.unregister(token) == nil,
                "a reclaimed action must not be reclaimable again — double-free is the bug class")
        guardian.drain()
        #expect(freed == 1, "drain must not re-run a reclaimed action")
    }

    @Test("Drain frees everything still registered, once, and is idempotent")
    func drainFreesOnce() {
        let guardian = SemanticEncoderExitGuard()
        nonisolated(unsafe) var freed: [Int] = []
        _ = guardian.register { freed.append(1) }
        let second = guardian.register { freed.append(2) }

        guardian.drain()
        #expect(freed.sorted() == [1, 2])
        guardian.drain()
        #expect(freed.count == 2, "a second drain must be a no-op")
        #expect(guardian.unregister(second) == nil,
                "drained actions are gone; a later unload must find nothing to free")
    }

    @Test("The encoder frees through the guard — one definition of freeing")
    func encoderRoutesThroughGuard() throws {
        // Source pin: `unload()` must reclaim via `unregister` and run the closure, never call
        // llama_free/llama_model_free directly — a direct call beside the registered closure
        // would double-free when drain races an unload at exit.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("FRUSExplorer/Semantic/SemanticQueryEncoder.swift"),
            encoding: .utf8)
        let unloadBody = try #require(source.range(of: "func unload()").map {
            String(source[$0.lowerBound...].prefix(400))
        })
        #expect(unloadBody.contains("unregister"))
        #expect(!unloadBody.contains("llama_free(context)"),
                "unload must free through the reclaimed closure, not a second direct call")
    }
}
