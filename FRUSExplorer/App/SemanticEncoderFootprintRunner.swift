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
import llama

#if DEBUG

/// Measures the query encoder's in-app memory footprint at the four points the CPU shape was
/// measured at (plan-of-record A-2, the kept half of B-4).
///
/// ## Why this rides the app rather than a CLI
/// The number wanted is the *in-app* footprint under **Metal**, and neither of the cheaper routes
/// can produce it. The **simulator cannot**: `SemanticQueryEncoder.load` forces `n_gpu_layers = 0`
/// under `targetEnvironment(simulator)`, because the paravirtual GPU runs the Metal kernels
/// *wrong* rather than slowly — measured at cosine ≈ −0.12 against the CLI reference, with no error
/// raised. So a simulator run measures the CPU shape, which is already known
/// (141 → 349 → 393 → 140 MB). And the **CLI shape is a ceiling, not a prediction**: 861 MB peak
/// RSS / 639 MB footprint, taken before the app's mmap pin, its absence of a JSON dump, and its
/// encode-then-release lifecycle.
///
/// The macOS app is the one place all three hold at once: full Metal offload, the shipped load
/// path, and a process whose footprint can be sampled from inside.
///
/// **Metal really is in effect here, and it is not taken on trust.** `llama_model_default_params()`
/// in the vendored xcframework returns `n_gpu_layers = -1`, which `llama.h` documents as *"a
/// negative value means all layers"* — measured by linking the macOS slice directly rather than by
/// reading the comment beside the call. The runner reports the value it observed so a future
/// upstream bump that changes the default shows up in the output rather than silently turning this
/// into a second CPU measurement.
///
/// ## What it does NOT measure
/// `phys_footprint` is the whole process, so every number here includes the app around the encoder.
/// That is deliberate and is why the four points are reported rather than one: the *differences*
/// are the encoder's cost, and the fourth point is what says whether it comes back.
///
/// ## What it measured (A-2, 2026-09-07, macOS 26.6.2)
/// Footprint MB, mean of four homogeneous runs: before 147.8 → after load 263.0 → after 25 encodes
/// **301.6** → after unload **141.4**. So the encoder costs ~160 MB while loaded and releases
/// completely, ending below its own baseline. Against the CPU shape's 141 → 349 → 393 → 140, Metal
/// peaks **~91 MB lower** rather than higher: the GGUF is mmapped and its clean pages are resident
/// without being charged to `phys_footprint` — the resident column peaks ~645 MB against a 229 MB
/// model file. Full record in `Planning/semantic-vectors/encoder-footprint-metal.json`.
///
/// ## How to run it — and do NOT launch it from a shell
/// Launch with `open -n --env FRUS_ENCODER_FOOTPRINT=1 -a "<...>/FRUS Explorer.app"`. Running the
/// binary directly from a shell leaves the app permanently non-frontmost, App Nap throttles the
/// `.utility` detached task below, and the run either takes ~116 s or never happens at all — three
/// attempts produced no output inside a 150 s window, at 0 % CPU with RSS flat, having finished
/// booting. Through `open` the same run completes in ~10 s, every time.
///
/// Two things that make a failed run readable. The JSON is written on **every** path, including
/// both guards, so *no file at all* means this runner never ran — not that the model was missing.
/// And `print()` to a redirected stdout is block-buffered, so an empty log is not evidence of an
/// empty run; the file is the only reliable channel.
///
/// ## Env
///   FRUS_ENCODER_FOOTPRINT      arms the seam (any value)
///   FRUS_ENCODER_FOOTPRINT_OUT  output JSON (default: Documents/encoder-footprint.json —
///                               inside the container, because the Mac app is sandboxed and
///                               cannot write an arbitrary path)
///   FRUS_ENCODER_FOOTPRINT_N    encodes to run (default 25, the count the CPU shape used)
enum SemanticEncoderFootprintRunner {

    /// One sample: what had happened, and the process footprint when it had.
    private struct Sample: Codable {
        let stage: String
        let footprintMB: Double
        let residentMB: Double
    }

    /// The process's physical footprint in bytes — the figure Xcode's memory gauge reports, and
    /// the one the CPU shape was recorded in, so the two are comparable.
    ///
    /// - Returns: `(footprint, resident)` in bytes, or `nil` if the kernel refuses the query.
    static func memory() -> (footprint: UInt64, resident: UInt64)? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return (UInt64(info.phys_footprint), UInt64(info.resident_size))
    }

    /// Twenty-five queries in the register the encoder actually serves — natural-language research
    /// questions, not keywords. Held here rather than read from a file so the run needs no staged
    /// input: the Mac app is sandboxed and cannot read an arbitrary path (the sibling
    /// `CSUserQueryEvalRunner` documents that failure).
    private static let queries: [String] = (1...25).map { i in
        [
            "How did the United States respond to the seizure of American vessels?",
            "What did the ambassador report about the negotiations?",
            "How was economic assistance coordinated with allied governments?",
            "What position did the Department take on recognition?",
            "How were refugees and displaced persons handled after the war?",
        ][(i - 1) % 5] + " (probe \(i))"
    }

    /// Runs when armed. Detached, so an unarmed launch pays nothing and an armed one does not
    /// block startup.
    /// - Parameter store: The verified-model door. Passed in rather than reached for, because it
    ///   is created during boot and this runner has no business knowing where it lives.
    static func runIfRequested(store: SemanticModelStore?) {
        let env = ProcessInfo.processInfo.environment
        guard env["FRUS_ENCODER_FOOTPRINT"] != nil else { return }
        let out = env["FRUS_ENCODER_FOOTPRINT_OUT"]
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("encoder-footprint.json").path
        let encodes = env["FRUS_ENCODER_FOOTPRINT_N"].flatMap(Int.init) ?? 25

        Task.detached(priority: .utility) {
            await run(store: store, outPath: out, encodes: encodes)
        }
    }

    private static func sample(_ stage: String) -> Sample {
        let m = memory()
        return Sample(stage: stage,
                      footprintMB: Double(m?.footprint ?? 0) / 1_048_576,
                      residentMB: Double(m?.resident ?? 0) / 1_048_576)
    }

    private static func run(store: SemanticModelStore?, outPath: String, encodes: Int) async {
        var samples: [Sample] = [sample("before")]
        var note = ""

        guard let store else {
            write(samples: samples, encodes: 0,
                  note: "no semantic model store — the semantic stack did not boot", outPath: outPath)
            return
        }
        guard let modelURL = await store.verifiedModelURL() else {
            write(samples: samples, encodes: 0,
                  note: "the model is not present or failed its pin; download it in Settings first",
                  outPath: outPath)
            return
        }

        let encoder = SemanticQueryEncoder()
        do {
            try await encoder.load(modelPath: modelURL.path)
            samples.append(sample("after load"))
            for q in queries.prefix(encodes) { _ = try await encoder.encodeQuery(q) }
            samples.append(sample("after \(min(encodes, queries.count)) encodes"))
            await encoder.unload()
            // The footprint after a free is not instantaneous; give the allocator a moment so the
            // fourth point measures release rather than timing.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            samples.append(sample("after unload"))
        } catch {
            note = "encoder error: \(error)"
            samples.append(sample("after failure"))
        }
        write(samples: samples, encodes: min(encodes, queries.count), note: note, outPath: outPath)
    }

    private static func write(samples: [Sample], encodes: Int, note: String, outPath: String) {
        struct Report: Codable {
            let measured: String
            let platform: String
            let nGpuLayersDefault: Int32
            let backend: String
            let activeProcessorCount: Int
            let encodes: Int
            let samples: [Sample]
            let note: String
        }
        #if targetEnvironment(simulator)
        let backend = "CPU (simulator: n_gpu_layers forced to 0 — the paravirtual GPU is wrong, not slow)"
        #elseif os(macOS)
        let backend = "Metal (macOS keeps the library default)"
        #else
        let backend = "Metal (device keeps the library default)"
        #endif
        let report = Report(
            measured: ISO8601DateFormatter().string(from: Date()),
            platform: ProcessInfo.processInfo.operatingSystemVersionString,
            nGpuLayersDefault: llama_model_default_params().n_gpu_layers,
            backend: backend,
            activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
            encodes: encodes, samples: samples, note: note)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(report) {
            try? data.write(to: URL(fileURLWithPath: outPath))
        }
        for s in samples {
            print(String(format: "[EncoderFootprint] %-22s footprint %7.1f MB  resident %7.1f MB",
                         (s.stage as NSString).utf8String!, s.footprintMB, s.residentMB))
        }
        print("[EncoderFootprint] backend=\(backend) n_gpu_layers_default=\(report.nGpuLayersDefault) -> \(outPath)")
    }
}

#endif
