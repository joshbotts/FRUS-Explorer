# FRUSKit

A Swift library for parsing *Foreign Relations of the United States* (FRUS) TEI XML volumes published by the [Office of the Historian](https://history.state.gov/) and made available as open data at [HistoryAtState/frus](https://github.com/HistoryAtState/frus).

## Schema

FRUS volumes are encoded according to the [Text Encoding Initiative P5 Guidelines](https://tei-c.org/guidelines/p5/) with a custom project profile defined in `schema/frus.odd` (compiled from TEI ODD to RelaxNG). FRUSKit models the key structural elements defined in that schema.

## Installation

Add FRUSKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourorg/FRUSKit.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["FRUSKit"]),
]
```

## Quick Start

```swift
import FRUSKit

let parser = FRUSParser()

// Parse from a local file (download from https://github.com/HistoryAtState/frus/tree/master/volumes)
let url = URL(fileURLWithPath: "frus1969-76v24.xml")
let volume = try parser.parse(url: url)

// Volume identity
print(volume.id)            // "frus1969-76v24"
print(volume.volumeTitle!)  // "1969–1976, Volume XXIV"
print(volume.seriesTitle!)  // "Foreign Relations of the United States"

// Iterate all diplomatic documents in the volume
for doc in volume.documents {
    print("Document \(doc.number ?? "?"):", doc.title ?? "(untitled)")
    if let date = doc.date {
        print("  Date:", date.when ?? date.text)
    }
    print("  Paragraphs:", doc.paragraphs.count)
}

// Access chapters and compilations
for compilation in volume.compilations {
    print("Compilation:", compilation.title ?? "")
    for chapter in compilation.children.filter({ $0.type == .chapter }) {
        print("  Chapter:", chapter.title ?? "")
    }
}

// Front / back matter
if let preface = volume.frontMatterSection[.preface] {
    print("Preface body text:", preface.bodyText)
}
```

## Document Structure

FRUS TEI XML is organised as follows (matching the FRUS schema):

```
TEI (@xml:id = volume identifier)
├── teiHeader
│   ├── fileDesc
│   │   ├── titleStmt   → titles[], editors[], principals[]
│   │   └── publicationStmt → publisher, pubDate, idnos[]
│   ├── encodingDesc
│   ├── profileDesc     → langUsage[], particDesc (persons[])
│   └── revisionDesc    → changes[]
└── text
    ├── front           → [Division] (preface, sources, persons, terms)
    ├── body            → [Division] (compilations → chapters → documents)
    └── back            → [Division] (appendices, index)
```

Each `Division` (mapped from `<div>`) has:

| Property | Source | Notes |
|---|---|---|
| `id` | `@xml:id` | Canonical identifier, e.g. `"d176"` |
| `type` | `@type` | `.compilation`, `.chapter`, `.document`, `.section`, … |
| `number` | `@n` | Document number |
| `headings` | `<head>` | One or more headings |
| `dateline` | `<dateline>` | Date + place of creation |
| `opener` | `<opener>` | Salutation / addressee |
| `closer` | `<closer>` | Valediction / signature |
| `paragraphs` | `<p>` | Body paragraphs |
| `notes` | `<note>` | Footnotes and editorial notes |
| `children` | nested `<div>` | Nested sub-divisions |

### Inline Content

`Paragraph.content` (and `Heading.content`, `Dateline.content`, etc.) is an array of `InlineContent`, an enum covering:

- `.text(String)` — plain text
- `.persName(PersonName)` — `<persName>` with optional `ref` to `<particDesc>`
- `.placeName(PlaceName)` — `<placeName>`
- `.orgName(OrgName)` — `<orgName>`
- `.date(DateElement)` — `<date>` with ISO 8601 `when`/`from`/`to`
- `.ref(Reference)` — `<ref>` / `<xRef>` cross-references
- `.hi(HighlightedText)` — `<hi rend="italic|bold|…">`
- `.term(Term)` — `<term>` abbreviation
- `.note(Note)` — inline footnote
- `.pageBreak(PageBreak)` — `<pb n="551">`
- `.lineBreak` — `<lb/>`
- `.list(XMLList)` — `<list>`
- `.table(Table)` — `<table>`
- `.unknown(elementName:rawContent:)` — forward-compatibility catch-all

## API Reference

### `FRUSParser`

| Method | Description |
|---|---|
| `parse(url:) throws -> FRUSVolume` | Parse from a file URL |
| `parse(data:) throws -> FRUSVolume` | Parse from raw `Data` |

### `FRUSVolume` (convenience)

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Volume identifier |
| `volumeTitle` | `String?` | Main title |
| `seriesTitle` | `String?` | "Foreign Relations of the United States" |
| `documents` | `[Division]` | All `<div type="document">` in the body |
| `chapters` | `[Division]` | All `<div type="chapter">` in the body |
| `compilations` | `[Division]` | Top-level compilations |
| `frontMatterSection` | `[DivisionType: Division]` | Front matter by type |

### `Division` (convenience)

| Property | Type | Description |
|---|---|---|
| `title` | `String?` | Plain text of first heading |
| `documentNumber` | `Int?` | `@n` as integer |
| `date` | `DateElement?` | First date in dateline |
| `footnotes` | `[Note]` | Notes with `type="footnote"` |
| `bodyText` | `String` | All paragraph text joined |
| `allDocuments` | `[Division]` | Recursive descendant documents |
| `allChapters` | `[Division]` | Recursive descendant chapters |

### `DateElement` (convenience)

| Property | Type | Description |
|---|---|---|
| `date` | `Date?` | Parsed from `@when` (ISO 8601) |

## Requirements

- Swift 5.9+
- macOS 13+ / iOS 16+
- No external dependencies (uses `Foundation.XMLParser`)

## License

The FRUS source files are in the public domain per the U.S. State Department. This library is released under the MIT License.
