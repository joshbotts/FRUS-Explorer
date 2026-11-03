// A6 spike (kept in the repository for #1723): drives Spotlight, Shortcuts and Siri on the simulator and keeps
// a screenshot and the element tree of each step in SPIKE_OUT.
import XCTest

@MainActor
final class SpikeSurfaceTests: XCTestCase {

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let spotlight = XCUIApplication(bundleIdentifier: "com.apple.Spotlight")
    private let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SPIKE_OUT"] ?? NSTemporaryDirectory())

    override func setUp() async throws {
        continueAfterFailure = true
    }

    private func keep(_ name: String, _ app: XCUIApplication? = nil) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: out.appending(path: "\(name).png"))
        let tree = (app ?? springboard).debugDescription
        try? tree.write(to: out.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func note(_ line: String) {
        let url = out.appending(path: "notes.txt")
        let data = Data((Date().formatted(.iso8601) + " " + line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    private func pause(_ seconds: Double) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    /// Home screen, a swipe down the middle, and Spotlight's own field.
    private func search(_ text: String) -> Bool {
        XCUIDevice.shared.press(.home)
        pause(1.5)
        // A snippet an earlier intent showed (Summarize's dialog) outlives the home button.
        for host in ["com.apple.springboard", "com.apple.siri", "com.apple.ShortcutsUI", "com.apple.shortcuts"] {
            let done = XCUIApplication(bundleIdentifier: host).buttons["Done"]
            if done.exists { done.tap(); pause(1) }
        }
        let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        start.press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        var field: XCUIElement?
        for _ in 0..<20 where field == nil {
            if spotlight.searchFields.firstMatch.exists { field = spotlight.searchFields.firstMatch }
            else if spotlight.textFields.firstMatch.exists { field = spotlight.textFields.firstMatch }
            else { pause(0.5) }
        }
        guard let field else {
            keep("nofield-\(text)", spotlight)
            return false
        }
        field.typeText(text)
        pause(5)
        return true
    }

    /// Every section header and app result cell Spotlight renders, scrolling to load them all.
    private func collectSections(_ name: String) -> XCUIElement? {
        pause(2)
        var seen = Set<String>()
        var firstApp: XCUIElement?
        for page in 0..<6 {
            for element in spotlight.descendants(matching: .any).allElementsBoundByIndex {
                let id = element.identifier
                guard id.hasPrefix("Identifier:SectionHeader") || id.hasPrefix("Identifier:AppViewResultCell")
                    || id.hasPrefix("Identifier:ResultCell") else { continue }
                let line = "\(id) | \(element.label)"
                if seen.insert(line).inserted { note("\(name) p\(page): \(line)") }
                if firstApp == nil, id.hasPrefix("Identifier:AppViewResultCell") { firstApp = element }
            }
            keep("\(name)-p\(page)", spotlight)
            if firstApp != nil { break }
            let top = spotlight.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            top.press(forDuration: 0.05, thenDragTo: spotlight.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
            pause(2)
        }
        return firstApp
    }

    func test1SpotlightResults() {
        for marker in ["Quillmere", "Varrowind", "Tessaloon", "Ombrevale", "Corvantis"] {
            guard search("Telegram From the Embassy in \(marker)") else { XCTFail("no Spotlight field for \(marker)"); continue }
            pause(4)
            let name = "spotlight-\(marker)"
            if let cell = collectSections(name) {
                note("\(name): tapping \(cell.identifier) '\(cell.label)'")
                cell.tap()
                pause(4)
                keep("\(name)-landed", XCUIApplication(bundleIdentifier: "bottsywattsy.A6Spike"))
            } else {
                note("\(name): no app result cell")
            }
        }
        XCUIDevice.shared.press(.home)
    }

    func test3Shortcuts() {
        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        shortcuts.launch()
        pause(4)
        let back = shortcuts.navigationBars.buttons.firstMatch
        if back.exists { back.tap(); pause(2) }
        keep("shortcuts-home", shortcuts)
        let spike = shortcuts.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Spike Reader'")).firstMatch
        if spike.waitForExistence(timeout: 5) {
            spike.tap()
            pause(3)
            keep("shortcuts-spike", shortcuts)
            let summarize = shortcuts.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Summarize'")).firstMatch
            if summarize.exists {
                summarize.tap()
                pause(4)
                keep("shortcuts-summarize-1", shortcuts)
                let doc = shortcuts.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Varrowind'")).firstMatch
                if doc.waitForExistence(timeout: 8) {
                    doc.tap()
                    pause(15)
                    keep("shortcuts-summarize-2", shortcuts)
                }
            }
        } else {
            note("shortcuts: no Spike Reader element")
        }
    }
}
