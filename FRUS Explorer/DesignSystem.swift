// DesignSystem.swift
// Visual identity for FRUSExplorer.
//
// Aesthetic direction: archival-academic — ink on aged paper,
// diplomatic sans paired with a classical serif. Muted ochre/slate
// palette that nods to physical State Department documents without
// becoming a costume.

import SwiftUI

// MARK: - Color palette

extension ShapeStyle where Self == Color {
    // Nothing exported here; colours are all via asset catalog / semantic.
}

extension Color {
    nonisolated static let frusAccent   = Color("FRUSAccent",   bundle: nil)   // deep slate-blue
    nonisolated static let frusOchre    = Color(red: 0.73, green: 0.60, blue: 0.35)
    nonisolated static let frusInk      = Color(red: 0.13, green: 0.14, blue: 0.17)
    nonisolated static let frusPaper    = Color(red: 0.97, green: 0.95, blue: 0.90)
    nonisolated static let frusRuling   = Color(red: 0.85, green: 0.81, blue: 0.72)
    // Authentic FRUS cover ruby red — used for "downloaded / ready / online" states.
    nonisolated static let frusRuby     = Color(red: 147/255, green: 49/255, blue: 22/255)
    // Deep amber — used for error / failure states (distinct from the ruby-red success color).
    nonisolated static let frusAmber    = Color(red: 180/255, green: 83/255, blue: 9/255)
}

// MARK: - Typography scale

struct FRUSTextStyle {
    // Display — volume/chapter titles
    static let displaySerif = Font.custom("Georgia", size: 26).weight(.bold)
    // Heading — section names
    static let headingSerif = Font.custom("Georgia", size: 17).weight(.semibold)
    // Body — document text
    static let bodySerif    = Font.custom("Georgia", size: 14)
    // Caption
    static let captionSerif = Font.custom("Georgia", size: 11).italic()
    // Monospace label
    static let mono         = Font.system(size: 11, design: .monospaced)
}

// MARK: - Document paper background modifier

struct PaperBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.frusPaper)
    }
}

extension View {
    func paperBackground() -> some View {
        modifier(PaperBackground())
    }
}

// MARK: - Ruling-line divider

struct RulingLine: View {
    var color: Color = .frusRuling
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

// MARK: - Redacted placeholder

struct RedactedPlaceholder: View {
    let lines: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<lines, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.frusRuling)
                    .frame(height: 11)
                    .frame(maxWidth: i % 3 == 2 ? .infinity * 0.6 : .infinity)
            }
        }
        .redacted(reason: .placeholder)
    }
}
