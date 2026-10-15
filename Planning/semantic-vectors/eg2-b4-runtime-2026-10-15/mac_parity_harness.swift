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

// QueryEncoderParityTests' procedure on the Mac, through the macOS slice of a llama.xcframework
// (plan of record B4, 2026-10-15). `run_mac_harness.sh` compiles this beside the app's own
// `FRUSExplorer/Semantic/SemanticQueryEncoder.swift` and `SemanticVectorsKit/SemanticQueryPrompt.swift`,
// so the wrapper measured is the shipped source, linked against the slice the Mac app embeds.
//
// Why a command-line harness and not the unit target: the unit target is iOS-only, and the one way
// to run it on this Mac, "My Mac (Designed for iPad)", launches the iOS app under the Mac app's
// bundle id and so inside the owner's real Mac container. This process has no container, no store
// and no CloudKit. The simulator rule does not apply here, so the encoder keeps the library's
// default offload, all layers on Metal.
//
// Usage: mac-parity-harness <gguf> <fixture.json>
// Prints one JSON object: the parity (min cosine against the fixture, as the test computes it),
// the four footprint points of `memoryShape()`, the load and encode times, and the default
// `n_gpu_layers` the slice reports.

import CryptoKit
import Darwin
import Foundation
import llama

struct FixtureQuery: Decodable {
    let text: String
    let vector: [Double]
}

struct Fixture: Decodable {
    let queryPrefix: String
    let ggufSHA256: String
    let referenceEngine: String
    let queries: [FixtureQuery]
}

/// SHA-256 of a file in 4 MB slices, each read inside its own autorelease pool: top-level code
/// never drains the main thread's pool, and without one a 229 MB hash stayed in the "before"
/// footprint (224 MB in the first run).
func sha256Hex(of url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while true {
        let chunk = try autoreleasepool { try handle.read(upToCount: 4 << 20) }
        guard let chunk, !chunk.isEmpty else { break }
        hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

func cosine(_ a: [Double], _ b: [Double]) -> Double {
    var dot = 0.0, na = 0.0, nb = 0.0
    for index in 0..<min(a.count, b.count) {
        dot += a[index] * b[index]
        na += a[index] * a[index]
        nb += b[index] * b[index]
    }
    return dot / (na.squareRoot() * nb.squareRoot())
}

/// `phys_footprint` and resident size in MB, as `QueryEncoderParityTests.physFootprint()` and
/// `SemanticEncoderFootprintRunner.memory()` read them.
func memoryMB() -> (footprint: Double, resident: Double) {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return (-1, -1) }
    return (Double(info.phys_footprint) / 1_048_576, Double(info.resident_size) / 1_048_576)
}

func milliseconds(_ value: Duration) -> Double {
    Double(value.components.seconds) * 1_000 + Double(value.components.attoseconds) / 1e15
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: mac-parity-harness <gguf> <fixture.json>\n".utf8))
    exit(2)
}
let modelPath = arguments[1]
let fixture = try JSONDecoder().decode(
    Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[2])))
guard fixture.queryPrefix == SemanticQueryPrompt.queryPrefix else {
    FileHandle.standardError.write(Data("the fixture's prompt is not the app's\n".utf8))
    exit(1)
}
guard try sha256Hex(of: URL(fileURLWithPath: modelPath)) == fixture.ggufSHA256 else {
    FileHandle.standardError.write(Data("the model is not the GGUF the fixture was made from\n".utf8))
    exit(1)
}

let clock = ContinuousClock()
let before = memoryMB()
let encoder = SemanticQueryEncoder()
let loadStart = clock.now
try await encoder.load(modelPath: modelPath)
let loadTime = clock.now - loadStart
let afterLoad = memoryMB()

var worst = 1.0
var worstQuery = ""
var encodeTimes: [Double] = []
var afterFirst = (footprint: 0.0, resident: 0.0)
for (offset, row) in fixture.queries.enumerated() {
    let start = clock.now
    let vector = try await encoder.encodeQuery(row.text)
    encodeTimes.append(milliseconds(clock.now - start))
    if offset == 0 { afterFirst = memoryMB() }
    guard vector.count == row.vector.count else {
        FileHandle.standardError.write(Data("width \(vector.count), fixture \(row.vector.count)\n".utf8))
        exit(1)
    }
    let agreement = cosine(vector, row.vector)
    if agreement < worst {
        worst = agreement
        worstQuery = row.text
    }
}
let afterAll = memoryMB()
await encoder.unload()
// As the footprint runner does: the footprint after a free is not instantaneous.
try await Task.sleep(nanoseconds: 2_000_000_000)
let afterUnload = memoryMB()

let warm = encodeTimes.dropFirst().sorted()
let report: [String: Any] = [
    "model": URL(fileURLWithPath: modelPath).lastPathComponent,
    "fixtureEngine": fixture.referenceEngine,
    "queries": fixture.queries.count,
    "minCosine": worst,
    "worstQuery": worstQuery,
    "nGpuLayersDefault": Int(llama_model_default_params().n_gpu_layers),
    "footprintMB": [
        "before": before.footprint, "afterLoad": afterLoad.footprint,
        "afterFirstEncode": afterFirst.footprint, "after25Encodes": afterAll.footprint,
        "afterUnload": afterUnload.footprint,
    ],
    "residentMB": [
        "before": before.resident, "afterLoad": afterLoad.resident,
        "afterFirstEncode": afterFirst.resident, "after25Encodes": afterAll.resident,
        "afterUnload": afterUnload.resident,
    ],
    "loadMs": milliseconds(loadTime),
    "firstEncodeMs": encodeTimes[0],
    "warmEncodeMedianMs": warm[warm.count / 2],
    "warmEncodeMinMs": warm[0],
    "warmEncodeMaxMs": warm[warm.count - 1],
]
let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
