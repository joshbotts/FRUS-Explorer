// Views/SubjectChipView.swift
// Reusable subject-taxonomy pill chip and wrapping row used in OutlineView and DetailView.

import SwiftUI

// MARK: - Single chip

/// A compact pill that labels one subject from the FRUS subject taxonomy.
/// Color reflects the subject's `kind`:
///   - "compound-subject" → frusRuby (red-brown — a paired person+topic or place+topic tag)
///   - "topic"            → blue
///   - everything else    → secondary
struct SubjectChip: View {
    let subject: TaxonomySubject

    var body: some View {
        Text(subject.name)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(chipColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(chipColor.opacity(0.10), in: Capsule())
            .overlay(Capsule().strokeBorder(chipColor.opacity(0.25), lineWidth: 0.5))
    }

    private var chipColor: Color {
        switch subject.kind {
        case "compound-subject": return Color.frusRuby
        case "topic":            return .blue
        default:                 return .secondary
        }
    }
}

// MARK: - Wrapping row

/// Lays out an array of `SubjectChip` views, wrapping across multiple lines
/// when the available width is exceeded.  Uses a `LazyVGrid` with adaptive
/// columns so it responds correctly to narrow outline rows and wide detail panels.
struct SubjectChipsRow: View {
    let subjects: [TaxonomySubject]

    private let columns = [GridItem(.adaptive(minimum: 60, maximum: 180), spacing: 4)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(subjects) { subject in
                SubjectChip(subject: subject)
            }
        }
    }
}
