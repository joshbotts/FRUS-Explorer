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

// Reads what the Mac check copy tells accessibility about the elements of one window: the name
// VoiceOver would read, the value, the help, the identifier and whether the element is enabled.
//
//     swiftc -O -o "$MAC_CHECK_SCRATCH/axread" tools/mac-check-copy/axread.swift
//     "$MAC_CHECK_SCRATCH/axread" Search AXCheckBox 5
//
// Arguments: the window's title, the accessibility role to list, and how many to print at most
// (default 10). It reads the copy's bundle id and nothing else, and it changes nothing.
//
// Why it exists (2026-10-10, #1576 lane 4): System Events cannot read a name that is an
// attributed string, and a SwiftUI control inside a window's content gives its name as
// `AXAttributedDescription`. Read through AppleScript, a row's checkbox looked as if it had no
// name; it had one, and a label added on that reading was then read twice.
//
// Version history:
//   1.0 — #1576 lane 4: initial implementation

import AppKit
import ApplicationServices

let bundleId = "bottsywattsy.FRUS-Explorer.maccheck"
let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("usage: axread <window title> <AX role> [max]")
    exit(2)
}
let windowTitle = arguments[1]
let wantedRole = arguments[2]
let maxCount = arguments.count > 3 ? Int(arguments[3]) ?? 10 : 10

guard AXIsProcessTrusted() else {
    print("not trusted for accessibility: run it from a process that is")
    exit(1)
}
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
    print("the check copy is not running")
    exit(1)
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func describe(_ element: AXUIElement) -> String {
    var names: CFArray?
    AXUIElementCopyAttributeNames(element, &names)
    var parts: [String] = []
    for name in (names as? [String]) ?? [] {
        guard let value = attribute(element, name) else { continue }
        if let text = value as? String {
            parts.append("\(name)=\(text)")
        } else if let attributed = value as? NSAttributedString {
            parts.append("\(name)=«\(attributed.string)»")
        } else if let number = value as? NSNumber {
            parts.append("\(name)=\(number)")
        }
    }
    return parts.joined(separator: " | ")
}

var found = 0
func walk(_ element: AXUIElement, depth: Int) {
    guard found < maxCount, depth < 60 else { return }
    if (attribute(element, kAXRoleAttribute) as? String) == wantedRole {
        found += 1
        print(describe(element))
    }
    for child in (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
        walk(child, depth: depth + 1)
    }
}

let application = AXUIElementCreateApplication(app.processIdentifier)
let windows = (attribute(application, kAXWindowsAttribute) as? [AXUIElement]) ?? []
let matching = windows.filter { (attribute($0, kAXTitleAttribute) as? String) == windowTitle }
guard !matching.isEmpty else {
    let titles = windows.compactMap { attribute($0, kAXTitleAttribute) as? String }
    print("no window titled \(windowTitle); open: \(titles)")
    exit(1)
}
for window in matching { walk(window, depth: 0) }
print("\(found) \(wantedRole) printed")
