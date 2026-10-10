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

// MARK: - NewPromptRequestTests

/// The New Prompt sheet is presented from an item that carries its copy (#1590).
///
/// `SummarizationPromptCopyTests` (UI) drives the iPhone and iPad pane: on the code before the
/// fix its first Use as Template opened Choose a Template over a blank editor. The Mac pane is a
/// separate view (`SettingsSummarizationPane`, in `FRUSSettingsView.swift`) that no test target
/// runs, since the unit target is built for iOS, so its half is read from the source here, with
/// the iOS pane's beside it.
///
/// Version history:
///   1.0 — 2026-10-09: #1590 — initial implementation
@Suite("The New Prompt sheet is presented from an item that carries its copy (#1590)")
struct NewPromptRequestTests {

    @Test("A request carries its copy, and two requests are two presentations")
    func requestCarriesItsCopy() {
        let template = PromptTemplate(id: UUID(), name: "Copy of Standard Summary",
                                      promptText: "Summarize the document.", fields: [])
        let first = NewPromptRequest(template: template)
        let second = NewPromptRequest(template: template)
        #expect(first.template?.name == "Copy of Standard Summary")
        #expect(first.template?.promptText == "Summarize the document.")
        // A new identity each time: the same prompt used as a template twice opens the sheet twice.
        #expect(first.id != second.id)
        // New Prompt… asks for no copy, and the editor then opens under Choose a Template.
        #expect(NewPromptRequest(template: nil).template == nil)
    }

    /// Both panes, since they are hand-maintained twins: the three doors (Use as Template,
    /// Duplicate, New Prompt…) each make one request, the sheet is `.sheet(item:)`, and neither
    /// pane keeps the copy in a `@State` of its own beside a Bool.
    @Test("Both Summarization panes present the editor from the request, with no sibling state",
          arguments: ["FRUSExplorer/Settings/SettingsView.swift", "FRUSExplorer/Settings/FRUSSettingsView.swift"])
    func bothPanesPresentFromTheItem(path: String) throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(path), encoding: .utf8)
        func count(_ text: String) -> Int { source.components(separatedBy: text).count - 1 }

        #expect(count("@State private var newPromptRequest: NewPromptRequest? = nil") == 1)
        #expect(count(".sheet(item: $newPromptRequest, onDismiss: refreshTally) { request in") == 1)
        #expect(count("PromptEditorView(initialTemplate: request.template)") == 1)
        // Use as Template and Duplicate each hand the sheet the copy; New Prompt… hands it none.
        #expect(count("newPromptRequest = NewPromptRequest(template: templateFrom(prompt))") == 2)
        #expect(count("newPromptRequest = NewPromptRequest(template: nil)") == 1)
        // The shape that opened the first one blank.
        #expect(count("showNewPromptSheet") == 0, "\(path) presents the New Prompt sheet from a Bool again")
        #expect(count("newPromptInitialTemplate") == 0, "\(path) keeps the copy in a sibling @State again")
    }
}
