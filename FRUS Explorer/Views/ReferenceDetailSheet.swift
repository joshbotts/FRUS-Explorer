// Views/ReferenceDetailSheet.swift
// Bottom sheets shown when the user taps a footnote superscript, a persName, or a term.

import SwiftUI

// MARK: - FootnoteDetailSheet

struct FootnoteDetailSheet: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let n = note.n {
                        Text("Note \(n)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(FRUSRenderer.attributedString(noteContent))
                        .font(.system(size: 14, design: .serif))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(note.type == "source" ? "Source" : "Footnote")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
    }

    private var noteContent: [InlineContent] {
        if !note.paragraphs.isEmpty {
            return note.paragraphs.enumerated().flatMap { idx, para -> [InlineContent] in
                idx == 0 ? para.content : [.text(" ")] + para.content
            }
        }
        return note.content
    }
}

// MARK: - PersonDetailSheet

struct PersonDetailSheet: View {
    let ref: String
    let volume: FRUSVolume
    @Environment(\.dismiss) private var dismiss

    private var person: PersonRecord? {
        volume.header.profileDescription?.particDesc?.persons
            .first(where: { $0.id == ref })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let p = person {
                        personCard(p)
                    } else {
                        Text("Person record not found.")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Person")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
    }

    @ViewBuilder
    private func personCard(_ p: PersonRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Primary name
            if let primary = p.names.first {
                Label(primary, systemImage: "person.fill")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
            }
            // Additional names
            if p.names.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Also known as")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(p.names.dropFirst().enumerated()), id: \.offset) { _, name in
                        Text(name).font(.system(size: 13, design: .serif))
                    }
                }
            }
            // Biographical notes
            if !p.notes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(p.notes.enumerated()), id: \.offset) { _, note in
                        Text(note)
                            .font(.system(size: 13, design: .serif))
                            .lineSpacing(3)
                    }
                }
            }
        }
    }
}

// MARK: - TermDetailSheet

struct TermDetailSheet: View {
    let ref: String
    let volume: FRUSVolume
    @Environment(\.dismiss) private var dismiss

    private struct TermMatch {
        let abbrev: String
        let definition: String
    }

    private var term: TermMatch? {
        let allDivs = (volume.text.front?.divisions ?? [])
            + volume.text.body.divisions
            + (volume.text.back?.divisions ?? [])
        return findTerm(ref: ref, in: allDivs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let t = term {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(t.abbrev)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.purple)
                            Text(t.definition)
                                .font(.system(size: 14, design: .serif))
                                .lineSpacing(4)
                        }
                    } else {
                        Text("Term definition not found.")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Term")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
#endif
    }

    private func findTerm(ref: String, in divs: [Division]) -> TermMatch? {
        for div in divs {
            for para in div.paragraphs {
                if let match = scanContent(ref: ref, content: para.content) { return match }
            }
            if let match = findTerm(ref: ref, in: div.children) { return match }
        }
        return nil
    }

    private func scanContent(ref: String, content: [InlineContent]) -> TermMatch? {
        for item in content {
            if case .list(let list) = item, list.type == "gloss" {
                for listItem in list.items {
                    if listItem.labelID == ref {
                        return TermMatch(
                            abbrev: listItem.label ?? ref,
                            definition: FRUSRenderer.plainText(listItem.content)
                        )
                    }
                }
            }
        }
        return nil
    }
}
