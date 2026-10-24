// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - ResearchDataFixtures

/// One research data export of each format version, kept so every later decoder is held to them.
///
/// Each holds one record of every type its version carried, in the shape that version's records
/// had (read from `Export/ResearchDataExporter.swift` at the commit that set each version), with
/// sorted keys and ISO-8601 dates as the app's encoder writes them. Version 6's collection also
/// holds the entry with no document that version 6 writes for a heading, a prose block or an
/// apparatus block. The ids are fixed, so a test can name a record across versions.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, versions 1 to 6
enum ResearchDataFixtures {

    /// The fixtures' ids: `id(1)` is the project, 2 the tag, 3 the note, 4 the highlight, 5 the
    /// tag assignment, 6 the collection, 7 its document entry, 8 the version-6 entry with no
    /// document, 9 the prompt, 10 the summary, 11 the visit, 12 the search, 13 the collection
    /// export, 14 the archive visit plan, 15 its document, 16 its target and 17 its tier.
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: "10000000-0000-4000-8000-" + String(format: "%012x", number))!
    }

    /// Every earlier version's file, by version.
    static let earlierVersions: [(version: Int, json: String)] = [
        (1, version1), (2, version2), (3, version3), (4, version4), (5, version5), (6, version6),
    ]

    /// A version-1 file.
    static let version1 = #"""
{
  "collections" : [
    {
      "createdAt" : "2026-06-01T09:15:00Z",
      "entries" : [
        {
          "createdAt" : "2026-06-01T09:20:00Z",
          "documentId" : "d1",
          "id" : "10000000-0000-4000-8000-000000000007",
          "lastModified" : "2026-06-01T09:20:00Z",
          "researchNoteId" : "10000000-0000-4000-8000-000000000003",
          "selectedNoteIds" : [
            "10000000-0000-4000-8000-000000000003"
          ],
          "sortOrder" : 0,
          "volumeId" : "frus1969-76v01"
        }
      ],
      "id" : "10000000-0000-4000-8000-000000000006",
      "lastModified" : "2026-06-01T09:20:00Z",
      "name" : "Vietnam Negotiations",
      "note" : "For chapter 3",
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ]
    }
  ],
  "exportedAt" : "2026-06-10T12:00:00Z",
  "formatVersion" : 1,
  "highlights" : [
    {
      "colorTag" : "yellow",
      "createdAt" : "2026-06-01T09:10:00Z",
      "documentId" : "d1",
      "endOffset" : 42,
      "id" : "10000000-0000-4000-8000-000000000004",
      "noteId" : "10000000-0000-4000-8000-000000000003",
      "renderingVersion" : "0123456789abcdef",
      "selectedText" : "a key turning point",
      "startOffset" : 10,
      "volumeId" : "frus1969-76v01"
    }
  ],
  "notes" : [
    {
      "bodyText" : "Key turning point in the negotiations.",
      "createdAt" : "2026-06-01T09:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-000000000003",
      "lastModified" : "2026-06-02T09:00:00Z",
      "linkedHighlightIds" : [
        "10000000-0000-4000-8000-000000000004"
      ],
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ],
      "selectedSummaryIds" : [
        "10000000-0000-4000-8000-00000000000a"
      ],
      "userTagIds" : [
        "10000000-0000-4000-8000-000000000002"
      ],
      "volumeId" : "frus1969-76v01"
    }
  ],
  "projects" : [
    {
      "createdAt" : "2026-06-01T07:00:00Z",
      "defaultCountryTagIds" : [
        "country-ussr"
      ],
      "defaultDateRangeEnd" : "1974-08-09T04:00:00Z",
      "defaultDateRangeStart" : "1969-01-20T05:00:00Z",
      "defaultSubjectTagIds" : [
        "subject-arms-control"
      ],
      "id" : "10000000-0000-4000-8000-000000000001",
      "lastModified" : "2026-06-01T07:30:00Z",
      "name" : "Cold War Diplomacy",
      "researchQuestion" : "How did détente evolve?"
    }
  ],
  "prompts" : [
    {
      "createdAt" : "2026-06-01T08:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000009",
      "lastModified" : "2026-06-01T08:00:00Z",
      "name" : "People and Positions",
      "promptText" : "List the people in {{DOCUMENT}}.",
      "responseFormat" : {
        "structured" : {
          "schema" : {
            "fields" : [
              {
                "description" : "Who they were",
                "name" : "Background"
              }
            ]
          }
        }
      },
      "schema" : {
        "fields" : [
          {
            "description" : "Who they were",
            "name" : "Background"
          }
        ]
      }
    }
  ],
  "summaries" : [
    {
      "createdAt" : "2026-06-01T10:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000a",
      "lastModified" : "2026-06-01T10:00:00Z",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "promptId" : "10000000-0000-4000-8000-000000000009",
      "responseFormat" : {
        "general" : {}
      },
      "responseText" : "This document discusses...",
      "volumeId" : "frus1969-76v01",
      "wasChunked" : false
    }
  ],
  "tagAssignments" : [
    {
      "createdAt" : "2026-06-01T09:05:00Z",
      "documentId" : "d2",
      "id" : "10000000-0000-4000-8000-000000000005",
      "tagId" : "10000000-0000-4000-8000-000000000002",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "tags" : [
    {
      "createdAt" : "2026-06-01T09:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000002",
      "lastModified" : "2026-06-01T09:00:00Z",
      "name" : "Primary Source"
    }
  ]
}
"""#

    /// A version-2 file.
    static let version2 = #"""
{
  "collections" : [
    {
      "createdAt" : "2026-06-01T09:15:00Z",
      "entries" : [
        {
          "createdAt" : "2026-06-01T09:20:00Z",
          "documentId" : "d1",
          "id" : "10000000-0000-4000-8000-000000000007",
          "lastModified" : "2026-06-01T09:20:00Z",
          "researchNoteId" : "10000000-0000-4000-8000-000000000003",
          "selectedNoteIds" : [
            "10000000-0000-4000-8000-000000000003"
          ],
          "sortOrder" : 0,
          "volumeId" : "frus1969-76v01"
        }
      ],
      "id" : "10000000-0000-4000-8000-000000000006",
      "lastModified" : "2026-06-01T09:20:00Z",
      "name" : "Vietnam Negotiations",
      "note" : "For chapter 3",
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ]
    }
  ],
  "exportedAt" : "2026-07-23T12:00:00Z",
  "exportedForProjectName" : "Cold War Diplomacy",
  "exportedForProjectResearchQuestion" : "How did détente evolve?",
  "formatVersion" : 2,
  "highlights" : [
    {
      "colorTag" : "yellow",
      "createdAt" : "2026-06-01T09:10:00Z",
      "documentId" : "d1",
      "endOffset" : 42,
      "id" : "10000000-0000-4000-8000-000000000004",
      "noteId" : "10000000-0000-4000-8000-000000000003",
      "renderingVersion" : "0123456789abcdef",
      "selectedText" : "a key turning point",
      "startOffset" : 10,
      "volumeId" : "frus1969-76v01"
    }
  ],
  "notes" : [
    {
      "bodyText" : "Key turning point in the negotiations.",
      "createdAt" : "2026-06-01T09:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-000000000003",
      "lastModified" : "2026-06-02T09:00:00Z",
      "linkedHighlightIds" : [
        "10000000-0000-4000-8000-000000000004"
      ],
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ],
      "selectedSummaryIds" : [
        "10000000-0000-4000-8000-00000000000a"
      ],
      "userTagIds" : [
        "10000000-0000-4000-8000-000000000002"
      ],
      "volumeId" : "frus1969-76v01"
    }
  ],
  "projects" : [
    {
      "createdAt" : "2026-06-01T07:00:00Z",
      "defaultCountryTagIds" : [
        "country-ussr"
      ],
      "defaultDateRangeEnd" : "1974-08-09T04:00:00Z",
      "defaultDateRangeStart" : "1969-01-20T05:00:00Z",
      "defaultSubjectTagIds" : [
        "subject-arms-control"
      ],
      "id" : "10000000-0000-4000-8000-000000000001",
      "lastModified" : "2026-06-01T07:30:00Z",
      "name" : "Cold War Diplomacy",
      "researchQuestion" : "How did détente evolve?"
    }
  ],
  "prompts" : [
    {
      "createdAt" : "2026-06-01T08:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000009",
      "lastModified" : "2026-06-01T08:00:00Z",
      "name" : "People and Positions",
      "promptText" : "List the people in {{DOCUMENT}}.",
      "responseFormat" : {
        "structured" : {
          "schema" : {
            "fields" : [
              {
                "description" : "Who they were",
                "name" : "Background"
              }
            ]
          }
        }
      },
      "schema" : {
        "fields" : [
          {
            "description" : "Who they were",
            "name" : "Background"
          }
        ]
      }
    }
  ],
  "summaries" : [
    {
      "createdAt" : "2026-06-01T10:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000a",
      "lastModified" : "2026-06-01T10:00:00Z",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "promptId" : "10000000-0000-4000-8000-000000000009",
      "responseFormat" : {
        "general" : {}
      },
      "responseText" : "This document discusses...",
      "volumeId" : "frus1969-76v01",
      "wasChunked" : false
    }
  ],
  "tagAssignments" : [
    {
      "createdAt" : "2026-06-01T09:05:00Z",
      "documentId" : "d2",
      "id" : "10000000-0000-4000-8000-000000000005",
      "tagId" : "10000000-0000-4000-8000-000000000002",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "tags" : [
    {
      "createdAt" : "2026-06-01T09:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000002",
      "lastModified" : "2026-06-01T09:00:00Z",
      "name" : "Primary Source"
    }
  ]
}
"""#

    /// A version-3 file.
    static let version3 = #"""
{
  "collections" : [
    {
      "createdAt" : "2026-06-01T09:15:00Z",
      "entries" : [
        {
          "createdAt" : "2026-06-01T09:20:00Z",
          "documentId" : "d1",
          "id" : "10000000-0000-4000-8000-000000000007",
          "lastModified" : "2026-06-01T09:20:00Z",
          "researchNoteId" : "10000000-0000-4000-8000-000000000003",
          "selectedNoteIds" : [
            "10000000-0000-4000-8000-000000000003"
          ],
          "sortOrder" : 0,
          "volumeId" : "frus1969-76v01"
        }
      ],
      "id" : "10000000-0000-4000-8000-000000000006",
      "lastModified" : "2026-06-01T09:20:00Z",
      "name" : "Vietnam Negotiations",
      "note" : "For chapter 3",
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ]
    }
  ],
  "exportHistory" : [
    {
      "collectionName" : "Vietnam Negotiations",
      "documentCount" : 3,
      "exportedAt" : "2026-07-25T10:00:00Z",
      "format" : "zotero-api",
      "id" : "10000000-0000-4000-8000-00000000000d",
      "projectId" : "10000000-0000-4000-8000-000000000001"
    }
  ],
  "exportedAt" : "2026-07-26T12:00:00Z",
  "exportedForProjectName" : "Cold War Diplomacy",
  "exportedForProjectResearchQuestion" : "How did détente evolve?",
  "formatVersion" : 3,
  "highlights" : [
    {
      "colorTag" : "yellow",
      "createdAt" : "2026-06-01T09:10:00Z",
      "documentId" : "d1",
      "endOffset" : 42,
      "id" : "10000000-0000-4000-8000-000000000004",
      "noteId" : "10000000-0000-4000-8000-000000000003",
      "renderingVersion" : "0123456789abcdef",
      "selectedText" : "a key turning point",
      "startOffset" : 10,
      "volumeId" : "frus1969-76v01"
    }
  ],
  "notes" : [
    {
      "bodyText" : "Key turning point in the negotiations.",
      "createdAt" : "2026-06-01T09:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-000000000003",
      "lastModified" : "2026-06-02T09:00:00Z",
      "linkedHighlightIds" : [
        "10000000-0000-4000-8000-000000000004"
      ],
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ],
      "selectedSummaryIds" : [
        "10000000-0000-4000-8000-00000000000a"
      ],
      "userTagIds" : [
        "10000000-0000-4000-8000-000000000002"
      ],
      "volumeId" : "frus1969-76v01"
    }
  ],
  "projects" : [
    {
      "createdAt" : "2026-06-01T07:00:00Z",
      "defaultCountryTagIds" : [
        "country-ussr"
      ],
      "defaultDateRangeEnd" : "1974-08-09T04:00:00Z",
      "defaultDateRangeStart" : "1969-01-20T05:00:00Z",
      "defaultSubjectTagIds" : [
        "subject-arms-control"
      ],
      "id" : "10000000-0000-4000-8000-000000000001",
      "lastModified" : "2026-06-01T07:30:00Z",
      "name" : "Cold War Diplomacy",
      "researchQuestion" : "How did détente evolve?"
    }
  ],
  "prompts" : [
    {
      "createdAt" : "2026-06-01T08:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000009",
      "lastModified" : "2026-06-01T08:00:00Z",
      "name" : "People and Positions",
      "promptText" : "List the people in {{DOCUMENT}}.",
      "responseFormat" : {
        "structured" : {
          "schema" : {
            "fields" : [
              {
                "description" : "Who they were",
                "name" : "Background"
              }
            ]
          }
        }
      },
      "schema" : {
        "fields" : [
          {
            "description" : "Who they were",
            "name" : "Background"
          }
        ]
      }
    }
  ],
  "readingHistory" : [
    {
      "accessedAt" : "2026-07-25T09:00:00Z",
      "displayTitle" : "Telegram 1234",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000b",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "searchHistory" : [
    {
      "executedAt" : "2026-07-25T09:30:00Z",
      "id" : "10000000-0000-4000-8000-00000000000c",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "queryText" : "mobilization base",
      "resultCount" : 0
    }
  ],
  "summaries" : [
    {
      "createdAt" : "2026-06-01T10:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000a",
      "lastModified" : "2026-06-01T10:00:00Z",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "promptId" : "10000000-0000-4000-8000-000000000009",
      "responseFormat" : {
        "general" : {}
      },
      "responseText" : "This document discusses...",
      "volumeId" : "frus1969-76v01",
      "wasChunked" : false
    }
  ],
  "tagAssignments" : [
    {
      "createdAt" : "2026-06-01T09:05:00Z",
      "documentId" : "d2",
      "id" : "10000000-0000-4000-8000-000000000005",
      "tagId" : "10000000-0000-4000-8000-000000000002",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "tags" : [
    {
      "createdAt" : "2026-06-01T09:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000002",
      "lastModified" : "2026-06-01T09:00:00Z",
      "name" : "Primary Source"
    }
  ]
}
"""#

    /// A version-4 file.
    static let version4 = #"""
{
  "collections" : [
    {
      "createdAt" : "2026-06-01T09:15:00Z",
      "entries" : [
        {
          "createdAt" : "2026-06-01T09:20:00Z",
          "documentId" : "d1",
          "id" : "10000000-0000-4000-8000-000000000007",
          "lastModified" : "2026-06-01T09:20:00Z",
          "researchNoteId" : "10000000-0000-4000-8000-000000000003",
          "selectedNoteIds" : [
            "10000000-0000-4000-8000-000000000003"
          ],
          "sortOrder" : 0,
          "volumeId" : "frus1969-76v01"
        }
      ],
      "id" : "10000000-0000-4000-8000-000000000006",
      "lastModified" : "2026-06-01T09:20:00Z",
      "name" : "Vietnam Negotiations",
      "note" : "For chapter 3",
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ]
    }
  ],
  "exportHistory" : [
    {
      "collectionName" : "Vietnam Negotiations",
      "documentCount" : 3,
      "exportedAt" : "2026-07-25T10:00:00Z",
      "format" : "zotero-api",
      "id" : "10000000-0000-4000-8000-00000000000d",
      "projectId" : "10000000-0000-4000-8000-000000000001"
    }
  ],
  "exportedAt" : "2026-07-31T12:00:00Z",
  "exportedForProjectName" : "Cold War Diplomacy",
  "exportedForProjectResearchQuestion" : "How did détente evolve?",
  "formatVersion" : 4,
  "highlights" : [
    {
      "colorTag" : "yellow",
      "createdAt" : "2026-06-01T09:10:00Z",
      "documentId" : "d1",
      "endOffset" : 42,
      "id" : "10000000-0000-4000-8000-000000000004",
      "noteId" : "10000000-0000-4000-8000-000000000003",
      "renderingVersion" : "0123456789abcdef",
      "selectedText" : "a key turning point",
      "startOffset" : 10,
      "volumeId" : "frus1969-76v01"
    }
  ],
  "notes" : [
    {
      "bodyText" : "Key turning point in the negotiations.",
      "createdAt" : "2026-06-01T09:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-000000000003",
      "lastModified" : "2026-06-02T09:00:00Z",
      "linkedHighlightIds" : [
        "10000000-0000-4000-8000-000000000004"
      ],
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ],
      "selectedSummaryIds" : [
        "10000000-0000-4000-8000-00000000000a"
      ],
      "userTagIds" : [
        "10000000-0000-4000-8000-000000000002"
      ],
      "volumeId" : "frus1969-76v01"
    }
  ],
  "projects" : [
    {
      "createdAt" : "2026-06-01T07:00:00Z",
      "defaultCountryTagIds" : [
        "country-ussr"
      ],
      "defaultDateRangeEnd" : "1974-08-09T04:00:00Z",
      "defaultDateRangeStart" : "1969-01-20T05:00:00Z",
      "defaultSubjectTagIds" : [
        "subject-arms-control"
      ],
      "id" : "10000000-0000-4000-8000-000000000001",
      "lastModified" : "2026-06-01T07:30:00Z",
      "name" : "Cold War Diplomacy",
      "researchQuestion" : "How did détente evolve?"
    }
  ],
  "prompts" : [
    {
      "createdAt" : "2026-06-01T08:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000009",
      "lastModified" : "2026-06-01T08:00:00Z",
      "name" : "People and Positions",
      "promptText" : "List the people in {{DOCUMENT}}.",
      "responseFormat" : {
        "structured" : {
          "schema" : {
            "fields" : [
              {
                "description" : "Who they were",
                "name" : "Background"
              }
            ]
          }
        }
      },
      "schema" : {
        "fields" : [
          {
            "description" : "Who they were",
            "name" : "Background"
          }
        ]
      }
    }
  ],
  "readingHistory" : [
    {
      "accessedAt" : "2026-07-25T09:00:00Z",
      "displayTitle" : "Telegram 1234",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000b",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "searchHistory" : [
    {
      "executedAt" : "2026-07-25T09:30:00Z",
      "fetchLimit" : 7500,
      "id" : "10000000-0000-4000-8000-00000000000c",
      "indexedVolumeCount" : 553,
      "loadedCount" : 0,
      "matchCount" : 0,
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "queryText" : "mobilization base",
      "renderedExpression" : "{body_text} : (mobilization AND base)",
      "resultCount" : 0,
      "scopeSignature" : "text+summaries+notes"
    }
  ],
  "summaries" : [
    {
      "createdAt" : "2026-06-01T10:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000a",
      "lastModified" : "2026-06-01T10:00:00Z",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "promptId" : "10000000-0000-4000-8000-000000000009",
      "responseFormat" : {
        "general" : {}
      },
      "responseText" : "This document discusses...",
      "volumeId" : "frus1969-76v01",
      "wasChunked" : false
    }
  ],
  "tagAssignments" : [
    {
      "createdAt" : "2026-06-01T09:05:00Z",
      "documentId" : "d2",
      "id" : "10000000-0000-4000-8000-000000000005",
      "tagId" : "10000000-0000-4000-8000-000000000002",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "tags" : [
    {
      "createdAt" : "2026-06-01T09:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000002",
      "lastModified" : "2026-06-01T09:00:00Z",
      "name" : "Primary Source"
    }
  ]
}
"""#

    /// A version-5 file.
    static let version5 = #"""
{
  "collections" : [
    {
      "createdAt" : "2026-06-01T09:15:00Z",
      "entries" : [
        {
          "createdAt" : "2026-06-01T09:20:00Z",
          "documentId" : "d1",
          "id" : "10000000-0000-4000-8000-000000000007",
          "lastModified" : "2026-06-01T09:20:00Z",
          "researchNoteId" : "10000000-0000-4000-8000-000000000003",
          "selectedNoteIds" : [
            "10000000-0000-4000-8000-000000000003"
          ],
          "sortOrder" : 0,
          "volumeId" : "frus1969-76v01"
        }
      ],
      "id" : "10000000-0000-4000-8000-000000000006",
      "lastModified" : "2026-06-01T09:20:00Z",
      "name" : "Vietnam Negotiations",
      "note" : "For chapter 3",
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ]
    }
  ],
  "exportHistory" : [
    {
      "collectionName" : "Vietnam Negotiations",
      "documentCount" : 3,
      "exportedAt" : "2026-07-25T10:00:00Z",
      "format" : "zotero-api",
      "id" : "10000000-0000-4000-8000-00000000000d",
      "projectId" : "10000000-0000-4000-8000-000000000001"
    }
  ],
  "exportedAt" : "2026-08-01T12:00:00Z",
  "exportedForProjectName" : "Cold War Diplomacy",
  "exportedForProjectResearchQuestion" : "How did détente evolve?",
  "formatVersion" : 5,
  "highlights" : [
    {
      "colorTag" : "yellow",
      "createdAt" : "2026-06-01T09:10:00Z",
      "documentId" : "d1",
      "endOffset" : 42,
      "id" : "10000000-0000-4000-8000-000000000004",
      "noteId" : "10000000-0000-4000-8000-000000000003",
      "renderingVersion" : "0123456789abcdef",
      "selectedText" : "a key turning point",
      "startOffset" : 10,
      "volumeId" : "frus1969-76v01"
    }
  ],
  "notes" : [
    {
      "bodyText" : "Key turning point in the negotiations.",
      "createdAt" : "2026-06-01T09:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-000000000003",
      "lastModified" : "2026-06-02T09:00:00Z",
      "linkedHighlightIds" : [
        "10000000-0000-4000-8000-000000000004"
      ],
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ],
      "selectedSummaryIds" : [
        "10000000-0000-4000-8000-00000000000a"
      ],
      "userTagIds" : [
        "10000000-0000-4000-8000-000000000002"
      ],
      "volumeId" : "frus1969-76v01"
    }
  ],
  "projects" : [
    {
      "createdAt" : "2026-06-01T07:00:00Z",
      "defaultCountryTagIds" : [
        "country-ussr"
      ],
      "defaultDateRangeEnd" : "1974-08-09T04:00:00Z",
      "defaultDateRangeStart" : "1969-01-20T05:00:00Z",
      "defaultSubjectTagIds" : [
        "subject-arms-control"
      ],
      "id" : "10000000-0000-4000-8000-000000000001",
      "lastModified" : "2026-06-01T07:30:00Z",
      "name" : "Cold War Diplomacy",
      "researchQuestion" : "How did détente evolve?"
    }
  ],
  "prompts" : [
    {
      "createdAt" : "2026-06-01T08:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000009",
      "lastModified" : "2026-06-01T08:00:00Z",
      "name" : "People and Positions",
      "promptText" : "List the people in {{DOCUMENT}}.",
      "responseFormat" : {
        "structured" : {
          "schema" : {
            "fields" : [
              {
                "description" : "Who they were",
                "name" : "Background"
              }
            ]
          }
        }
      },
      "schema" : {
        "fields" : [
          {
            "description" : "Who they were",
            "name" : "Background"
          }
        ]
      }
    }
  ],
  "readingHistory" : [
    {
      "accessedAt" : "2026-07-25T09:00:00Z",
      "displayTitle" : "Telegram 1234",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000b",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "searchHistory" : [
    {
      "executedAt" : "2026-07-25T09:30:00Z",
      "fetchLimit" : 7500,
      "id" : "10000000-0000-4000-8000-00000000000c",
      "indexedVolumeCount" : 553,
      "loadedCount" : 0,
      "matchCount" : 0,
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "queryText" : "mobilization base",
      "renderedExpression" : "{body_text} : (mobilization AND base)",
      "resultCount" : 0,
      "scopeSignature" : "text+summaries+notes"
    }
  ],
  "summaries" : [
    {
      "authorship" : "aiEdited",
      "createdAt" : "2026-06-01T10:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000a",
      "lastModified" : "2026-06-01T10:00:00Z",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "promptId" : "10000000-0000-4000-8000-000000000009",
      "responseFormat" : {
        "general" : {}
      },
      "responseText" : "This document discusses...",
      "volumeId" : "frus1969-76v01",
      "wasChunked" : false
    }
  ],
  "tagAssignments" : [
    {
      "createdAt" : "2026-06-01T09:05:00Z",
      "documentId" : "d2",
      "id" : "10000000-0000-4000-8000-000000000005",
      "tagId" : "10000000-0000-4000-8000-000000000002",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "tags" : [
    {
      "createdAt" : "2026-06-01T09:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000002",
      "lastModified" : "2026-06-01T09:00:00Z",
      "name" : "Primary Source"
    }
  ]
}
"""#

    /// A version-6 file.
    static let version6 = #"""
{
  "archiveVisits" : [
    {
      "createdAt" : "2026-08-25T08:00:00Z",
      "deliverables" : {
        "includeCitationCrib" : false,
        "includeInquiry" : true,
        "includeLinks" : true,
        "includeTargets" : true
      },
      "documents" : [
        {
          "createdAt" : "2026-08-25T09:00:00Z",
          "documentKey" : "frus1948v02/d3",
          "id" : "10000000-0000-4000-8000-00000000000f",
          "includeExternalRefs" : false,
          "includeSource" : true,
          "lastModified" : "2026-08-25T09:00:00Z"
        }
      ],
      "id" : "10000000-0000-4000-8000-00000000000e",
      "inquiryText" : "What did the Army's files say?",
      "lastModified" : "2026-08-25T09:05:00Z",
      "name" : "Berlin blockade",
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ],
      "targets" : [
        {
          "createdAt" : "2026-08-25T09:05:00Z",
          "id" : "10000000-0000-4000-8000-000000000010",
          "included" : true,
          "lastModified" : "2026-08-25T09:05:00Z",
          "targetKey" : "lot|99Z999",
          "tierId" : "10000000-0000-4000-8000-000000000011",
          "userNote" : "Kept with your tier and notes"
        }
      ],
      "tiers" : [
        {
          "id" : "10000000-0000-4000-8000-000000000011",
          "label" : "First morning",
          "order" : 0
        }
      ]
    }
  ],
  "collections" : [
    {
      "createdAt" : "2026-06-01T09:15:00Z",
      "entries" : [
        {
          "createdAt" : "2026-08-20T09:00:00Z",
          "documentId" : "",
          "id" : "10000000-0000-4000-8000-000000000008",
          "lastModified" : "2026-08-20T09:00:00Z",
          "selectedNoteIds" : [],
          "sortOrder" : 0,
          "volumeId" : ""
        },
        {
          "createdAt" : "2026-06-01T09:20:00Z",
          "documentId" : "d1",
          "id" : "10000000-0000-4000-8000-000000000007",
          "lastModified" : "2026-06-01T09:20:00Z",
          "researchNoteId" : "10000000-0000-4000-8000-000000000003",
          "selectedNoteIds" : [
            "10000000-0000-4000-8000-000000000003"
          ],
          "sortOrder" : 1,
          "volumeId" : "frus1969-76v01"
        }
      ],
      "id" : "10000000-0000-4000-8000-000000000006",
      "lastModified" : "2026-06-01T09:20:00Z",
      "name" : "Vietnam Negotiations",
      "note" : "For chapter 3",
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ]
    }
  ],
  "exportHistory" : [
    {
      "collectionName" : "Vietnam Negotiations",
      "documentCount" : 3,
      "exportedAt" : "2026-07-25T10:00:00Z",
      "format" : "zotero-api",
      "id" : "10000000-0000-4000-8000-00000000000d",
      "projectId" : "10000000-0000-4000-8000-000000000001"
    }
  ],
  "exportedAt" : "2026-08-26T12:00:00Z",
  "exportedForProjectName" : "Cold War Diplomacy",
  "exportedForProjectResearchQuestion" : "How did détente evolve?",
  "formatVersion" : 6,
  "highlights" : [
    {
      "colorTag" : "yellow",
      "createdAt" : "2026-06-01T09:10:00Z",
      "documentId" : "d1",
      "endOffset" : 42,
      "id" : "10000000-0000-4000-8000-000000000004",
      "noteId" : "10000000-0000-4000-8000-000000000003",
      "renderingVersion" : "0123456789abcdef",
      "selectedText" : "a key turning point",
      "startOffset" : 10,
      "volumeId" : "frus1969-76v01"
    }
  ],
  "notes" : [
    {
      "bodyText" : "Key turning point in the negotiations.",
      "createdAt" : "2026-06-01T09:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-000000000003",
      "lastModified" : "2026-06-02T09:00:00Z",
      "linkedHighlightIds" : [
        "10000000-0000-4000-8000-000000000004"
      ],
      "projectIds" : [
        "10000000-0000-4000-8000-000000000001"
      ],
      "selectedSummaryIds" : [
        "10000000-0000-4000-8000-00000000000a"
      ],
      "userTagIds" : [
        "10000000-0000-4000-8000-000000000002"
      ],
      "volumeId" : "frus1969-76v01"
    }
  ],
  "projects" : [
    {
      "createdAt" : "2026-06-01T07:00:00Z",
      "defaultCountryTagIds" : [
        "country-ussr"
      ],
      "defaultDateRangeEnd" : "1974-08-09T04:00:00Z",
      "defaultDateRangeStart" : "1969-01-20T05:00:00Z",
      "defaultSubjectTagIds" : [
        "subject-arms-control"
      ],
      "id" : "10000000-0000-4000-8000-000000000001",
      "lastModified" : "2026-06-01T07:30:00Z",
      "name" : "Cold War Diplomacy",
      "researchQuestion" : "How did détente evolve?"
    }
  ],
  "prompts" : [
    {
      "createdAt" : "2026-06-01T08:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000009",
      "lastModified" : "2026-06-01T08:00:00Z",
      "name" : "People and Positions",
      "promptText" : "List the people in {{DOCUMENT}}.",
      "responseFormat" : {
        "structured" : {
          "schema" : {
            "fields" : [
              {
                "description" : "Who they were",
                "name" : "Background"
              }
            ]
          }
        }
      },
      "schema" : {
        "fields" : [
          {
            "description" : "Who they were",
            "name" : "Background"
          }
        ]
      }
    }
  ],
  "readingHistory" : [
    {
      "accessedAt" : "2026-07-25T09:00:00Z",
      "displayTitle" : "Telegram 1234",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000b",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "searchHistory" : [
    {
      "executedAt" : "2026-07-25T09:30:00Z",
      "fetchLimit" : 7500,
      "id" : "10000000-0000-4000-8000-00000000000c",
      "indexedVolumeCount" : 553,
      "loadedCount" : 0,
      "matchCount" : 0,
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "queryText" : "mobilization base",
      "renderedExpression" : "{body_text} : (mobilization AND base)",
      "resultCount" : 0,
      "scopeSignature" : "text+summaries+notes"
    }
  ],
  "summaries" : [
    {
      "authorship" : "aiEdited",
      "createdAt" : "2026-06-01T10:00:00Z",
      "documentId" : "d1",
      "id" : "10000000-0000-4000-8000-00000000000a",
      "lastModified" : "2026-06-01T10:00:00Z",
      "projectId" : "10000000-0000-4000-8000-000000000001",
      "promptId" : "10000000-0000-4000-8000-000000000009",
      "responseFormat" : {
        "general" : {}
      },
      "responseText" : "This document discusses...",
      "volumeId" : "frus1969-76v01",
      "wasChunked" : false
    }
  ],
  "tagAssignments" : [
    {
      "createdAt" : "2026-06-01T09:05:00Z",
      "documentId" : "d2",
      "id" : "10000000-0000-4000-8000-000000000005",
      "tagId" : "10000000-0000-4000-8000-000000000002",
      "volumeId" : "frus1969-76v01"
    }
  ],
  "tags" : [
    {
      "createdAt" : "2026-06-01T09:00:00Z",
      "id" : "10000000-0000-4000-8000-000000000002",
      "lastModified" : "2026-06-01T09:00:00Z",
      "name" : "Primary Source"
    }
  ]
}
"""#

}
