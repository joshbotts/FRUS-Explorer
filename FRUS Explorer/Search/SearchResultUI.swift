// Search/SearchResultUI.swift
// SwiftUI display helpers for SearchResult.MatchField.
//
// Kept separate from SearchResult.swift (Foundation-only) so that importing SwiftUI
// here cannot taint the SearchResult.MatchField.Hashable conformance with @MainActor
// inference under -strict-concurrency=complete.

import SwiftUI

// MARK: - MatchField display

extension SearchResult.MatchField {
    var icon: String {
        switch self {
        case .title:      return "textformat"
        case .body:       return "text.alignleft"
        case .person:     return "person"
        case .place:      return "mappin"
        case .org:        return "building.2"
        case .term:       return "ellipsis.curlybraces"
        case .summary:    return "sparkles"
        case .annotation: return "pencil.line"
        case .date:       return "calendar"
        case .subject:    return "tag"
        }
    }

    var label: String {
        switch self {
        case .title:      return "Title"
        case .body:       return "Text"
        case .person:     return "Person"
        case .place:      return "Place"
        case .org:        return "Org"
        case .term:       return "Term"
        case .summary:    return "Summary"
        case .annotation: return "Note"
        case .date:       return "Date"
        case .subject:    return "Subject"
        }
    }

    var tint: Color {
        switch self {
        case .title:      return .primary
        case .body:       return .blue
        case .person:     return .purple
        case .place:      return .green
        case .org:        return .orange
        case .term:       return .teal
        case .summary:    return .indigo
        case .annotation: return .brown
        case .date:       return .red
        case .subject:    return Color.frusRuby
        }
    }

    var sortOrder: Int {
        switch self {
        case .title: return 0; case .body: return 1; case .person: return 2
        case .place: return 3; case .org:  return 4; case .term:   return 5
        case .summary: return 6; case .annotation: return 7; case .date: return 8
        case .subject: return 9
        }
    }
}
