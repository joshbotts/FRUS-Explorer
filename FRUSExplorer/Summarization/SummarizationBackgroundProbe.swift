// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS) && DEBUG
import BackgroundTasks
import Darwin
import Foundation
import FoundationModels
import SwiftUI
import UIKit

/// A DEBUG-only diagnostic harness that measures whether — and how well — Apple's
/// on-device `FoundationModels` summarization runs under `BGProcessingTask`
/// constraints, to de-risk background bulk summarization before committing to it.
///
/// Each run summarises one real indexed document with `LanguageModelSession` and
/// appends a structured JSONL line (timestamp, availability, application state,
/// inference latency, memory footprint before/after, success/error, sequence
/// index) to a log file the developer can inspect or share from Settings →
/// Diagnostics.
///
/// Two entry points:
/// - `runSingle` — one summary; used for the foreground baseline button.
/// - `runUntilExpiration` — summarises successive documents until the background
///   task is cancelled, so a single wake reveals throughput-per-wake and any
///   intra-wake latency creep (thermal throttling).
///
/// Trigger the background variant on demand from Xcode's debugger:
/// `e -l objc -- (void)[[BGTaskScheduler sharedScheduler]
///   _simulateLaunchForTaskWithIdentifier:@"bottsywattsy.FRUS-Explorer.summarizationProbe"]`
///
/// Version history:
///   1.0 — Summarization background-feasibility harness
enum SummarizationBackgroundProbe {

    /// One measured summarization attempt.
    struct Sample: Codable {
        let date: String
        let trigger: String           // "foreground" | "background"
        let sequence: Int             // 0-based index within a wake
        let applicationState: String  // "active" | "inactive" | "background"
        let availability: String      // String(describing: SystemLanguageModel availability)
        let documentId: String?
        let inputChars: Int
        let success: Bool
        let outputChars: Int
        let inferenceMs: Int
        let footprintBeforeMB: Double
        let footprintAfterMB: Double
        let cancelled: Bool
        let error: String?
    }

    /// UserDefaults key marking that the next indexing background wake should run
    /// the probe instead of indexing.
    private static let armedKey = "frus.debug.summarizationProbe.armed"

    /// Whether the probe is armed for the next background wake.
    static var isArmed: Bool { UserDefaults.standard.bool(forKey: armedKey) }

    /// Arms the probe so the next indexing background wake runs it.
    static func arm() { UserDefaults.standard.set(true, forKey: armedKey) }

    /// Clears the armed flag (called as the background run begins).
    static func disarm() { UserDefaults.standard.set(false, forKey: armedKey) }

    /// JSONL log file in the app's Documents directory.
    static let logURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("summarization-probe.jsonl")
    }()

    /// Runs a single summary (foreground baseline).
    @MainActor
    static func runSingle(trigger: String, appState: AppState) async -> Sample {
        let doc = await firstDocument(appState: appState, skipping: 0)
        return await summarizeOne(trigger: trigger, sequence: 0, document: doc)
    }

    /// Summarises successive documents until the surrounding `Task` is cancelled
    /// (background-task budget exhausted) or documents run out. One sample is
    /// logged per attempt, so the wake's throughput and latency trend are captured.
    @MainActor
    static func runUntilExpiration(appState: AppState) async {
        var index = 0
        while !Task.isCancelled {
            guard let doc = await firstDocument(appState: appState, skipping: index) else { break }
            let sample = await summarizeOne(trigger: "background", sequence: index, document: doc)
            index += 1
            // Stop early if the model is unavailable or we were cancelled mid-run.
            if sample.cancelled || (!sample.success && sample.error?.contains("unavailable") == true) { break }
        }
    }

    // MARK: - Core

    /// Performs and measures one summarization, appends a `Sample`, and returns it.
    @MainActor
    private static func summarizeOne(
        trigger: String,
        sequence: Int,
        document: (volumeId: String, documentId: String, text: String)?
    ) async -> Sample {
        let appStateName = stateString(UIApplication.shared.applicationState)
        let availability = String(describing: SystemLanguageModel.default.availability)
        let before = footprintMB()

        let input = String((document?.text ?? "").prefix(6_000))
        var success = false
        var output = ""
        var cancelled = false
        var errorText: String?

        let start = Date()
        if document == nil {
            errorText = "no indexed document"
        } else if !SystemLanguageModel.default.isAvailable {
            errorText = "model unavailable"
        } else if input.isEmpty {
            errorText = "empty document body"
        } else {
            do {
                let session = LanguageModelSession()
                let prompt = """
                Summarize the following Foreign Relations of the United States document \
                in three sentences:

                \(input)
                """
                output = try await session.respond(to: prompt).content
                success = true
            } catch is CancellationError {
                cancelled = true
                errorText = "cancelled"
            } catch {
                errorText = String(describing: error)
            }
        }
        let inferenceMs = Int(Date().timeIntervalSince(start) * 1_000)
        let after = footprintMB()

        let sample = Sample(
            date: ISO8601DateFormatter().string(from: Date()),
            trigger: trigger,
            sequence: sequence,
            applicationState: appStateName,
            availability: availability,
            documentId: document?.documentId,
            inputChars: input.count,
            success: success,
            outputChars: output.count,
            inferenceMs: inferenceMs,
            footprintBeforeMB: before,
            footprintAfterMB: after,
            cancelled: cancelled,
            error: errorText
        )
        append(sample)
        return sample
    }

    /// Returns the `index`-th indexed document (volume, id, body text), or `nil`.
    @MainActor
    private static func firstDocument(
        appState: AppState, skipping index: Int
    ) async -> (volumeId: String, documentId: String, text: String)? {
        guard let pipeline = appState.indexingPipeline,
              let keys = try? await pipeline.allDocumentKeys(),
              index < keys.count else { return nil }
        let key = keys[index]
        let text = (try? await pipeline.fetchDocumentBodyText(
            volumeId: key.volumeId, documentId: key.documentId)) ?? ""
        return (key.volumeId, key.documentId, text)
    }

    // MARK: - Log file

    /// Appends a sample as one JSON line.
    static func append(_ sample: Sample) {
        guard let data = try? JSONEncoder().encode(sample) else { return }
        var line = data
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: logURL, options: .atomic)
        }
    }

    /// The current log contents (newest entries last).
    static func readLog() -> String {
        (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
    }

    /// Deletes the log file.
    static func clear() {
        try? FileManager.default.removeItem(at: logURL)
    }

    // MARK: - Measurement helpers

    private static func stateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    /// Current resident memory footprint in megabytes (`phys_footprint`), or `-1`.
    /// Exposed so the real background-summarization batch can sample it too.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }

    // MARK: - Real background-run instrumentation

    /// Appends a sample from the *real* background-summarization batch (not the
    /// probe), so an unplugged soak self-records throughput/latency/memory to the
    /// same log — readable from this screen without a debugger.
    ///
    /// `sequence` is the document's index within the current wake's batch, so the
    /// max sequence per timestamp cluster is that wake's throughput, and the
    /// `inferenceMs` trend across a cluster reveals thermal creep.
    static func recordBackgroundRun(
        documentId: String,
        sequence: Int,
        inputChars: Int,
        inferenceMs: Int,
        footprintBeforeMB: Double,
        footprintAfterMB: Double,
        success: Bool,
        error: String?
    ) {
        let sample = Sample(
            date: ISO8601DateFormatter().string(from: Date()),
            trigger: "bg-real",
            sequence: sequence,
            applicationState: "background",
            availability: String(describing: SystemLanguageModel.default.availability),
            documentId: documentId,
            inputChars: inputChars,
            success: success,
            outputChars: 0,
            inferenceMs: inferenceMs,
            footprintBeforeMB: footprintBeforeMB,
            footprintAfterMB: footprintAfterMB,
            cancelled: false,
            error: error
        )
        append(sample)
    }
}

/// DEBUG-only Settings screen driving `SummarizationBackgroundProbe`: run a
/// foreground baseline, schedule the background variant, and view/share/clear the
/// diagnostic log.
struct SummarizationProbeView: View {

    @Environment(AppState.self) private var appState
    @State private var log: String = ""
    @State private var running = false
    @State private var scheduled = false

    /// The LLDB command that triggers the (armed) probe via the indexing task.
    private var simulateCommand: String {
        "e -l objc -- (void)[[BGTaskScheduler sharedScheduler] "
        + "_simulateLaunchForTaskWithIdentifier:@\"\(FRUSExplorerApp.debugIndexingBGTaskID)\"]"
    }

    var body: some View {
        List {
            Section {
                Button {
                    runForeground()
                } label: {
                    Label("Run one summary (foreground)", systemImage: "play.circle")
                }
                .disabled(running)

                Button {
                    scheduleBackground()
                } label: {
                    Label(scheduled ? "Background probe scheduled" : "Schedule background probe",
                          systemImage: "clock.arrow.circlepath")
                }
            } footer: {
                Text("""
                Run on a real device, unplugged, across several wakes for thermal/throughput data. \
                After scheduling, trigger the background run from the Xcode debugger (pause, then in \
                the console):

                \(simulateCommand)

                Then Refresh to see the per-inference samples.
                """)
                .font(.caption)
                .textSelection(.enabled)
            }

            Section("Log (JSONL, newest last)") {
                if running {
                    HStack { ProgressView(); Text("Summarizing…").foregroundStyle(.secondary) }
                }
                ScrollView {
                    Text(log.isEmpty ? "No samples yet." : log)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 360)
            }

            Section {
                Button("Refresh") { log = SummarizationBackgroundProbe.readLog() }
                ShareLink(item: SummarizationBackgroundProbe.logURL) {
                    Label("Share log", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    SummarizationBackgroundProbe.clear()
                    log = ""
                } label: {
                    Label("Clear log", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Summarization Probe")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { log = SummarizationBackgroundProbe.readLog() }
    }

    /// Runs a single foreground summary, then refreshes the log.
    private func runForeground() {
        running = true
        Task { @MainActor in
            _ = await SummarizationBackgroundProbe.runSingle(trigger: "foreground", appState: appState)
            log = SummarizationBackgroundProbe.readLog()
            running = false
        }
    }

    /// Arms the probe and submits an indexing background-task request; the next
    /// indexing wake runs the probe instead of indexing.
    private func scheduleBackground() {
        SummarizationBackgroundProbe.arm()
        let request = BGProcessingTaskRequest(identifier: FRUSExplorerApp.debugIndexingBGTaskID)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(request)
        scheduled = true
    }
}
#endif
