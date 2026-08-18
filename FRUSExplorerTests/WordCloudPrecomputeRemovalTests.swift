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
import Testing
@testable import FRUSExplorer

/// The background word-cloud precompute is gone, its stored defaults are cleaned up, and the cost
/// it was meant to hide is now stated instead.
///
/// ## Why it was removed rather than throttled or left off
/// Measured on an owner iPad, build 42 (`cpu_resource_fatal`): the corpus job ran NLTagger at 97%
/// CPU for 50 seconds and iOS terminated the app. Turning it off (PR #954) stopped the harm, but a
/// switch nobody should ever turn on is not a setting — it is a trap with a label. And it could not
/// have paid for itself even had it completed: the disk key carries `fp=documentCacheCount` and the
/// enqueue site was *the end of indexing a volume*, so any entry it wrote was invalidated by the
/// next volume indexed.
///
/// What replaces it is honesty about the cost. A corpus cloud reads every indexed document; the
/// loading copy now says minutes and says the screen can be left, rather than "a moment".
///
/// Version history:
///   1.0 — removal of the precompute
@Suite("The word-cloud precompute is removed")
struct WordCloudPrecomputeRemovalTests {

    private static var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer")
    }

    private static func sources() throws -> [(String, String)] {
        let urls = (FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? [])
            .sorted { $0.path < $1.path }
        return try urls.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    /// Nothing may reference the machinery — a leftover call site is how a removed feature comes
    /// back as a build error at the worst moment, or worse, half-returns.
    @Test("No code references the retired precompute machinery")
    func machineryIsGone() throws {
        var offenders: [String] = []
        for (name, text) in try Self.sources() {
            // The cleanup function names the retired keys on purpose; it is the one exception.
            if name == "WordCloudSettings.swift" { continue }
            for symbol in ["WordCloudPrecomputeQueue", "drainWordCloudPrecompute",
                           "WordCloudLoader.precompute", "backgroundPrecompute"] where text.contains(symbol) {
                offenders.append("\(name): \(symbol)")
            }
        }
        #expect(offenders.isEmpty, """
            The precompute machinery is still referenced: \(offenders.joined(separator: ", ")).
            It was removed because it got the app killed by iOS and could not have paid for itself
            even when it finished.
            """)
    }

    /// The stored defaults are cleared, and the queue is the one that matters — it is state, not a
    /// preference, and could still name a scope enqueued by a build that had the feature.
    @Test("Launch clears the defaults the feature left behind")
    func retiredDefaultsAreCleared() {
        let defaults = UserDefaults.standard
        let keys = ["frus.wordcloud.backgroundPrecompute",
                    "frus.wordcloud.backgroundPrecompute.defaultOffMigrated",
                    "frus.wordcloud.precomputeQueue"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) where value != nil { defaults.set(value, forKey: key) } }

        defaults.set(true, forKey: keys[0])
        defaults.set(true, forKey: keys[1])
        defaults.set(["corpus"], forKey: keys[2])
        WordCloudSettings.removeRetiredPrecomputeDefaults()
        for key in keys {
            #expect(defaults.object(forKey: key) == nil, """
                `\(key)` survived the cleanup. The queue especially: it is state rather than a
                setting, so a stale entry outlives the feature and looks meaningful later.
                """)
        }
        // Idempotent — it runs on every launch.
        WordCloudSettings.removeRetiredPrecomputeDefaults()
    }

    /// The cleanup has to actually run, or it is a function nobody calls — a shape this codebase
    /// has now shipped four times.
    @Test("The cleanup is called at launch")
    func cleanupIsWired() throws {
        let app = try String(contentsOf: Self.appRoot.appending(path: "App/FRUSExplorerApp.swift"),
                             encoding: .utf8)
        let code = app.components(separatedBy: .newlines)
            .map { line -> String in
                guard let slashes = line.range(of: "//") else { return line }
                return String(line[..<slashes.lowerBound])
            }.joined(separator: "\n")
        #expect(code.contains("WordCloudSettings.removeRetiredPrecomputeDefaults()"),
                "the defaults cleanup is declared but never called")
    }

    /// The cost is stated where the reader waits for it.
    @Test("A corpus cloud says what it costs, in minutes")
    func corpusLoadingStatesTheCost() throws {
        let view = try String(contentsOf: Self.appRoot.appending(path: "Analytics/WordCloud/WordCloudView.swift"),
                              encoding: .utf8)
        #expect(view.contains("wordcloud.loading.corpus.v2"), """
            The corpus loading message is still the old key. It said "this can take a moment" for a
            job that reads every indexed document, and the precompute that was supposed to make that
            true no longer exists.
            """)
        #expect(view.contains("several minutes"),
                "the corpus message does not say how long it actually takes")
        #expect(!view.contains("this can take a moment"),
                "the understated copy is still present")
    }
}
