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

// Puts the Mac check copy's preferences back from a saved export: sets each key through
// CFPreferences, one at a time, removes the keys the export lacks, then reads the domain back
// through `defaults export`, in another process, and names any key that differs.
//
//     defaults export bottsywattsy.FRUS-Explorer.maccheck "$MAC_CHECK_SCRATCH/prefs-before.plist"
//     swiftc -O -o "$MAC_CHECK_SCRATCH/prefs-restore" tools/mac-check-copy/prefs-restore.swift
//     "$MAC_CHECK_SCRATCH/prefs-restore" "$MAC_CHECK_SCRATCH/prefs-before.plist"
//
// Arguments: the saved export, and the domain (default the copy's bundle id). Run it with the copy
// quit. It exits 0 when the domain reads back identical to the export, and 1 otherwise.
//
// Why it exists (2026-10-21, the build-51 sitting S4, #1763): `defaults import` of the copy's
// 96-key domain exited 0 and changed nothing, twice, in a sitting whose 15-key import at the start
// had taken. Setting the keys one by one through CFPreferences put all 96 back, identical to the
// export.
//
// Version history:
//   1.0 — #1763: S4's sitting helper, with the read-back

import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 || arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: prefs-restore <export.plist> [domain]\n".utf8))
    exit(64)
}
let domain = arguments.count == 3 ? arguments[2] : "bottsywattsy.FRUS-Explorer.maccheck"
let app = domain as CFString

/// Reads a dictionary property list, or nil.
func dictionary(from data: Data) -> [String: Any]? {
    (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
}

guard let exportData = FileManager.default.contents(atPath: arguments[1]),
      let saved = dictionary(from: exportData) else {
    FileHandle.standardError.write(Data("\(arguments[1]) is not a dictionary property list\n".utf8))
    exit(66)
}

// The keys the export lacks go first, then every key it holds, synchronized one at a time.
let current = (CFPreferencesCopyKeyList(app, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]) ?? []
for key in current where saved[key] == nil {
    CFPreferencesSetValue(key as CFString, nil, app, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
}
_ = CFPreferencesAppSynchronize(app)
var unsynchronized: [String] = []
for (key, value) in saved {
    CFPreferencesSetValue(key as CFString, value as CFPropertyList, app, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    if !CFPreferencesAppSynchronize(app) { unsynchronized.append(key) }
}

// Read back the way `defaults import` was found out: by another process asking cfprefsd. Into a
// file, which `defaults export` writes as a binary property list: to standard output it writes XML,
// which keeps a date only to the second, so a date saved with a fraction would read as differing.
let readBack = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("prefs-restore-\(ProcessInfo.processInfo.processIdentifier).plist")
let reader = Process()
reader.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
reader.arguments = ["export", domain, readBack.path]
do {
    try reader.run()
} catch {
    FileHandle.standardError.write(Data("could not run defaults export: \(error)\n".utf8))
    exit(1)
}
reader.waitUntilExit()
let now = FileManager.default.contents(atPath: readBack.path).flatMap(dictionary(from:)) ?? [:]
try? FileManager.default.removeItem(at: readBack)
let differing = Set(saved.keys).union(now.keys).filter { key in
    guard let want = saved[key], let have = now[key] else { return true }
    return !(want as AnyObject).isEqual(have)
}.sorted()

print("set \(saved.count) keys of \(domain); synchronize failed for \(unsynchronized.count); "
      + "read back \(now.count) keys, \(differing.count) differing"
      + (differing.isEmpty ? "" : ": " + differing.map { String($0.prefix(60)) }.joined(separator: ", ")))
exit(differing.isEmpty && unsynchronized.isEmpty ? 0 : 1)
