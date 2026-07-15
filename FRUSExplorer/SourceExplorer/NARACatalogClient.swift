// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - NARACatalogResult

/// A single result from the NARA Catalog API.
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 130: added `recordGroupNumber`, `seriesTitle`, `dateRange`
public struct NARACatalogResult: Sendable {
    /// NARA unique identifier.
    public let naId: String
    /// Title of the record series or description.
    public let title: String
    /// Deep-link URL to the NARA Catalog record.
    public let catalogURL: URL
    /// Short description or scope note if available.
    public let scopeNote: String?
    /// Record group number when the result is RG-specific (e.g. "59").
    public let recordGroupNumber: String?
    /// Series title when available.
    public let seriesTitle: String?
    /// Date range of the records (e.g. "1963–1966").
    public let dateRange: String?
}

// MARK: - NARACatalogError

public enum NARACatalogError: Error, LocalizedError {
    case missingAPIKey
    case networkError(underlying: Error)
    case unexpectedResponse(statusCode: Int)
    case decodingError
    /// HTTP 429 — API rate limit reached.
    case rateLimited
    /// HTTP 403 — API key is present but rejected by NARA.
    case apiKeyRejected

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return String(localized: "nara.error.missingKey",
                          defaultValue: "A NARA Catalog API key is required to search for lot files and Presidential Library records. Add your key in Settings → NARA API.")
        case .networkError:
            return String(localized: "nara.error.network",
                          defaultValue: "Network unavailable. Connect to look up this source in the NARA Catalog.")
        case .rateLimited:
            return String(localized: "nara.error.rateLimited",
                          defaultValue: "NARA Catalog API rate limit reached. Try again later, or use the manual search link below.")
        case .apiKeyRejected:
            return String(localized: "nara.error.keyRejected",
                          defaultValue: "NARA Catalog API key was rejected (HTTP 403). Check the key in Settings → NARA API.")
        case .unexpectedResponse(let code):
            return String(localized: "nara.error.response",
                          defaultValue: "Unexpected response from NARA Catalog (HTTP \(code)).")
        case .decodingError:
            return String(localized: "nara.error.decoding",
                          defaultValue: "Could not interpret the NARA Catalog response.")
        }
    }
}

// MARK: - NARACatalogClient

/// Actor that queries the NARA Catalog API (v2) and constructs static NARA URLs.
///
/// ## Authentication
/// The NARA Catalog API requires an `x-api-key` request header. The key is
/// retrieved from `KeychainStore` on each call, so it is always current.
///
/// ## RG-59 Central Files (no API call)
/// State Dept. central file identifiers are resolved by constructing a static
/// NARA Catalog search URL. No API key is required for this path.
///
/// ## Endpoints used
/// - v2 Search: `GET https://catalog.archives.gov/api/v2/records/search`
///   Structured filter: `description.recordGroupNumber`, free-text `q`
/// - v1 fallback: `GET https://catalog.archives.gov/api/v1/search` (for backward compat)
///
/// ## Query strategy (matched to ParsedSourceNote cases)
/// | Case | Method | NARA query approach |
/// |---|---|---|
/// | `.naraCollection` | `searchByRecordGroup` | RG filter + series/lot keywords |
/// | `.lotFile` | `searchByLotFile` | Free-text lot number search |
/// | `.presidentialLibrary` | `searchByPresidentialMaterials` | Library + collection keywords |
/// | `.centralFiles` | `resolveRG59CentralFiles` | Static URL (no API key) |
///
/// ## Log prefix
/// `[SourceExplorer]`
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 94: recordAPICall() called after each successful NARA API response
///   1.2 — Session 130: v2 API support; structured RG queries; new method overloads
///          matching the expanded ParsedSourceNote cases
///   1.3 — Session 150: `variantControlNumber_is` lot file resolution; static URL helpers
///          for decimal file period routing, presidential library fallbacks, and CIA CREST;
///          specific error cases for rate limiting (429) and key rejection (403)
///   1.4 — Session 151: expanded `decimalFilePeriodURL/Label` to cover 1789–1906, 1906–1910,
///          and 1963–1973 periods; added `filingManualURL(year:)` for per-period PDF filing
///          manuals; added `cfpfFAQURL`, `cfpfAADURL`, `resolveRG84LotFile(lotNumber:)`;
///          added `recordGroup` parameter to `resolveLotFileVariants`
public actor NARACatalogClient {

    // MARK: - Dependencies

    private let keychainStore: KeychainStore
    private let urlSession: URLSession

    // MARK: - Constants

    private static let apiV2Base   = "https://catalog.archives.gov/api/v2"
    private static let apiV1Base   = "https://catalog.archives.gov/api/v1"
    private static let catalogBase = "https://catalog.archives.gov"

    /// naId for the RG-59 Central Foreign Policy Files parent description.
    private static let rg59NaId = "302028"

    // MARK: - Init

    public init(
        keychainStore: KeychainStore = .shared,
        urlSession: URLSession = .shared
    ) {
        self.keychainStore = keychainStore
        self.urlSession    = urlSession
    }

    // MARK: - RG-59 Central Files (static URL — no API call)

    /// Returns the NARA Catalog search URL for the given State Dept. central file identifier.
    ///
    /// No API key is required. The URL opens a pre-filtered search on the
    /// RG-59 Central Foreign Policy Files parent description.
    public nonisolated func resolveRG59CentralFiles(fileIdentifier: String) -> URL {
        var components = URLComponents(string: "\(Self.catalogBase)/search")!
        components.queryItems = [
            URLQueryItem(name: "q",                       value: fileIdentifier),
            URLQueryItem(name: "f.parentDescriptionNaId", value: Self.rg59NaId),
        ]
        return components.url ?? URL(string: "\(Self.catalogBase)/search?q=\(fileIdentifier)")!
    }

    // MARK: - Decimal File Period Routing (static URLs — no API call)

    /// Returns the NARA finding-aid page URL for the State Dept. central file
    /// period that covers the given document year.
    ///
    /// NARA publishes period-specific research pages for the State Dept. central
    /// files spanning 1789–1973. No API key is required.
    ///
    /// ## Period coverage
    /// | Years | Filing system | NARA page |
    /// |---|---|---|
    /// | 1789–1906 | Numerical/register | `rg-59-central-files/1789-1906` |
    /// | 1906–1910 | Numerical (transitional) | `rg-59-central-files/1906-1910` |
    /// | 1910–1963 | Central decimal files | `rg-59-central-files/1910-1963/<period>` |
    /// | 1963–1973 | Subject-numeric files | `rg-59-central-files/1963-1973` |
    ///
    /// - Parameter year: The year the document was created (from the dateline).
    /// - Returns: URL to the appropriate NARA research page.
    public nonisolated func decimalFilePeriodURL(year: Int) -> URL {
        let base = "https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files"
        switch year {
        case ..<1906:
            return URL(string: "\(base)/1789-1906")!
        case 1906...1909:
            return URL(string: "\(base)/1906-1910")!
        case 1910...1962:
            // NARA consolidated all seven decimal-file sub-period pages onto one
            // parent page. The individual sub-period URLs (/1910-1963/1910-1929 etc.)
            // all return HTTP 404 (verified 2026-06-04). Use the parent page.
            return URL(string: "\(base)/1910-1963")!
        default:   // 1963–1973 subject-numeric
            return URL(string: "\(base)/1963-1973")!
        }
    }

    /// Human-readable label for the central-file period covering `year`.
    public nonisolated func decimalFilePeriodLabel(year: Int) -> String {
        switch year {
        case ..<1906:     return "1789–1906"
        case 1906...1909: return "1906–1910"
        case 1910...1929: return "1910–1929"
        case 1930...1939: return "1930–1939"
        case 1940...1944: return "1940–1944"
        case 1945...1949: return "1945–1949"
        case 1950...1954: return "1950–1954"
        case 1955...1959: return "1955–1959"
        case 1960...1962: return "1960–January 1963"
        default:          return "1963–1973"
        }
    }

    /// Returns the NARA filing manual PDF URL for the given document year, or
    /// `nil` when no filing manual applies (e.g. pre-1910 or post-1973).
    ///
    /// NARA publishes scanned filing manuals for each filing system. These
    /// PDFs explain how records are classified and organized within each period.
    ///
    /// - Parameter year: Document year.
    /// - Returns: URL to the filing manual PDF, or `nil`.
    public nonisolated func filingManualURL(year: Int) -> URL? {
        let base = "https://www.archives.gov/files/research/foreign-policy/state-dept/finding-aids"
        switch year {
        case 1910...1949:
            return URL(string: "\(base)/manual-1910-49.pdf")
        case 1950...1954:
            return URL(string: "\(base)/manual-1950-59.pdf")
        case 1955...1959:
            return URL(string: "\(base)/manual-1955.pdf")
        case 1960...1962:
            return URL(string: "\(base)/manual-1960-63.pdf")
        case 1963:
            return URL(string: "\(base)/records-classification-handbook-1963.pdf")
        case 1964...1972:
            return URL(string: "\(base)/dos-records-classification-handbook-1965-1973.pdf")
        default:
            return nil
        }
    }

    // MARK: - Presidential Library Fallback URLs (static — no API call)

    /// Returns the institution-specific finding-aid URL for the given library name.
    ///
    /// Used as a fallback when the NARA Catalog API returns zero results for a
    /// presidential library query. Never returns a generic NARA search link —
    /// each library has its own online finding-aid portal.
    public nonisolated func libraryFallbackURL(libraryName: String) -> URL {
        let lc = libraryName.lowercased()
        switch lc {
        case _ where lc.contains("kennedy") || lc.contains("jfk"):
            return URL(string: "https://www.jfklibrary.org/archives/finding-aids")!
        case _ where lc.contains("johnson") || lc.contains("lbj"):
            return URL(string: "https://www.lbjlibrary.org/research/research-resources")!
        case _ where lc.contains("nixon"):
            return URL(string: "https://www.nixonlibrary.gov/research/finding-aids")!
        case _ where lc.contains("ford"):
            return URL(string: "https://www.fordlibrarymuseum.gov/library/finding-aids.asp")!
        case _ where lc.contains("carter"):
            return URL(string: "https://www.jimmycarterlibrary.gov/research/finding-aids")!
        case _ where lc.contains("reagan"):
            return URL(string: "https://www.reaganlibrary.gov/research")!
        case _ where lc.contains("bush"):
            return URL(string: "https://www.bush41library.tamu.edu/research")!
        case _ where lc.contains("eisenhower") || lc.contains("ddel"):
            return URL(string: "https://www.eisenhowerlibrary.gov/research/finding-aids")!
        case _ where lc.contains("truman") || lc.contains("hstl"):
            return URL(string: "https://www.trumanlibrary.gov/research/finding-aids")!
        case _ where lc.contains("roosevelt") || lc.contains("fdrl"):
            return URL(string: "https://www.fdrlibrary.org/finding-aids")!
        default:
            return URL(string: "https://www.archives.gov/presidential-libraries")!
        }
    }

    // MARK: - CFPF Static URLs (static — no API call)

    /// URL to the NARA CFPF research guide PDF.
    ///
    /// Covers the Central Foreign Policy Files (1973–1979) on P-Reels, D-Reels,
    /// and N-Reels. No API key required.
    public nonisolated var cfpfFAQURL: URL {
        URL(string: "https://www.archives.gov/files/research/foreign-policy/"
            + "state-dept/rg-59-central-files/cfpf-faqs.pdf")!
    }

    /// URL to the NARA Access to Archival Databases (AAD) Electronic Telegrams series list.
    ///
    /// The AAD database contains the electronic telegrams component of the CFPF.
    /// No API key required.
    public nonisolated var cfpfAADURL: URL {
        URL(string: "https://aad.archives.gov/aad/series-list.jsp?cat=WR43")!
    }

    /// Returns a NARA Catalog search URL pre-scoped to RG 84 for a given lot number.
    ///
    /// Used as the fallback URL for F-designator lot files (RG 84 diplomatic
    /// post records) when the `variantControlNumber_is` query returns zero results.
    public nonisolated func resolveRG84LotFile(lotNumber: String) -> URL {
        var components = URLComponents(string: "\(Self.catalogBase)/search")!
        components.queryItems = [
            URLQueryItem(name: "q",                              value: "Lot \(lotNumber)"),
            URLQueryItem(name: "description.recordGroupNumber",  value: "84"),
        ]
        return components.url ?? URL(string: "\(Self.catalogBase)/search")!
    }

    // MARK: - CIA Research URL (static — no API call)

    /// Returns the CIA CREST database URL for the given job number, or the
    /// general CIA reading-room URL when no job number is available.
    ///
    /// CIA records are not indexed in the NARA Catalog. CREST is the
    /// appropriate resource for CIA operational records and historical files.
    public nonisolated func ciaResearchURL(jobNumber: String? = nil) -> URL {
        if let job = jobNumber, !job.isEmpty {
            let encoded = job.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? job
            return URL(string: "https://www.cia.gov/readingroom/search/site/\(encoded)")
                ?? URL(string: "https://www.cia.gov/readingroom/")!
        }
        return URL(string: "https://www.cia.gov/readingroom/")!
    }

    // MARK: - Structured Queries (v2 API)

    /// Searches for a specific National Archives series using a record group number
    /// and optional keywords derived from the series name or lot file number.
    ///
    /// This is the primary query path for `.naraCollection` source notes.
    /// Results are ordered by relevance and filtered to `series` / `recordGroup` level.
    ///
    /// - Parameters:
    ///   - recordGroup: e.g. `"59"`, `"330"`, `"306"`.
    ///   - keywords: e.g. `"Central Files"`, `"Lot 64 D 199"`. Passed as free-text `q`.
    ///   - maxResults: Maximum results to return. Default 3 (series-level queries return few useful hits).
    /// - Returns: Matching catalog descriptions at series level.
    public func searchByRecordGroup(
        _ recordGroup: String,
        keywords: String,
        maxResults: Int = 3
    ) async throws -> [NARACatalogResult] {
        let apiKey = try await fetchAPIKey()
        // v2 supports structured filter by record group number alongside free-text query.
        var components = URLComponents(string: "\(Self.apiV2Base)/records/search")!
        components.queryItems = [
            URLQueryItem(name: "q",                              value: keywords),
            URLQueryItem(name: "description.recordGroupNumber",  value: recordGroup),
            URLQueryItem(name: "resultType",                     value: "description"),
            URLQueryItem(name: "rows",                           value: "\(maxResults)"),
        ]
        guard let url = components.url else { throw NARACatalogError.decodingError }
        return try await executeSearch(url: url, apiKey: apiKey)
    }

    /// Searches for a State Department lot file series by lot number.
    ///
    /// Primary query path for `.lotFile` source notes.
    ///
    /// - Parameters:
    ///   - recordGroup: Typically `"59"` for State Dept. lot files.
    ///   - lotNumber: e.g. `"64 D 199"`, `"72D415"`.
    /// - Returns: The best-matching series description, or `nil` if not found.
    public func searchByLotFile(
        recordGroup: String,
        lotNumber: String
    ) async throws -> NARACatalogResult? {
        // Quote the lot number to encourage phrase matching.
        let keywords = "\"\(lotNumber)\""
        let results = try await searchByRecordGroup(recordGroup, keywords: keywords, maxResults: 1)
        return results.first
    }

    /// Queries the NARA Catalog for a State Dept. lot file series record.
    /// Backward-compatible entry point for existing callers.
    ///
    /// - Parameter lotNumber: e.g. `"61-D 146"`.
    public func resolveLotFile(lotNumber: String) async throws -> NARACatalogResult? {
        try await searchByLotFile(recordGroup: "59", lotNumber: lotNumber)
    }

    /// Resolves a State Dept. lot file using the `variantControlNumber_is` field
    /// query in the NARA Catalog v2 API, which matches against NARA's indexed lot
    /// numbers rather than performing free-text search.
    ///
    /// ## Normalization strategy
    /// FRUS citations use compact form almost exclusively (`63D135`, `72D316`).
    /// NARA may index them with spaces (`63 D 135`) or without. Three variants
    /// are tried in sequence; the first non-empty result wins:
    ///   1. Compact:  `"63D135"`
    ///   2. Spaced:   `"63 D 135"`
    ///   3. Mixed:    `"63 D135"`
    ///
    /// If all three `variantControlNumber_is` queries return zero results, falls
    /// back to the free-text `searchByLotFile` phrase query as a safety net.
    ///
    /// - Parameters:
    ///   - lotNumber: Raw lot number from the source note. May include "Lot " prefix,
    ///     spaces, dashes, or similar noise.
    ///   - recordGroup: NARA record group number. `"59"` for D-designator lot files
    ///     (State Dept. central files); `"84"` for F-designator lot files (post records).
    ///     Defaults to `"59"`.
    /// - Returns: Up to 5 matching series descriptions, newest first.
    public func resolveLotFileVariants(
        lotNumber: String,
        recordGroup: String = "59"
    ) async throws -> [NARACatalogResult] {
        let variants = Self.lotNumberVariants(from: lotNumber)

        for variant in variants {
            let results = try await searchByVariantControlNumber(variant, recordGroup: recordGroup)
            if !results.isEmpty {
                #if DEBUG
                print("[SourceExplorer] Lot file '\(variant)' (RG \(recordGroup)) matched \(results.count) result(s)")
                #endif
                return results
            }
        }

        // All variantControlNumber_is attempts returned zero — fall back to phrase query.
        #if DEBUG
        print("[SourceExplorer] variantControlNumber_is found nothing for '\(lotNumber)' "
              + "(RG \(recordGroup)); falling back to phrase query")
        #endif
        if let fallback = try? await searchByLotFile(recordGroup: recordGroup, lotNumber: lotNumber) {
            return [fallback]
        }
        return []
    }

    /// Generates up to three normalised lot number variants from a raw string.
    ///
    /// Strips "Lot " prefix, dashes, and excess whitespace, then produces:
    /// compact (`63D135`), spaced (`63 D 135`), and mixed (`63 D135`) forms.
    nonisolated static func lotNumberVariants(from raw: String) -> [String] {
        // 1. Strip leading "Lot " prefix (case insensitive), dashes, collapse spaces.
        let stripped = raw
            .replacingOccurrences(of: "Lot ", with: "", options: [.caseInsensitive, .anchored])
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        // 2. Match the canonical NNxNNN pattern (2-3 digits, one letter, 1+ digits).
        let pattern = #"^(\d{2,3})([A-Za-z])(\d+)$"#
        guard let regex  = try? NSRegularExpression(pattern: pattern),
              let match  = regex.firstMatch(in: stripped,
                                            range: NSRange(stripped.startIndex..., in: stripped)),
              let r1     = Range(match.range(at: 1), in: stripped),
              let r2     = Range(match.range(at: 2), in: stripped),
              let r3     = Range(match.range(at: 3), in: stripped)
        else {
            // Unusual format — try the stripped form as-is.
            return [stripped]
        }

        let d1 = String(stripped[r1])
        let lt = String(stripped[r2]).uppercased()
        let d2 = String(stripped[r3])

        return [
            "\(d1)\(lt)\(d2)",      // compact:  63D135
            "\(d1) \(lt) \(d2)",    // spaced:   63 D 135
            "\(d1) \(lt)\(d2)",     // mixed:    63 D135
        ]
    }

    /// Queries the v2 API using `variantControlNumber_is` for an exact lot number match.
    private func searchByVariantControlNumber(
        _ lotNumber: String,
        recordGroup: String
    ) async throws -> [NARACatalogResult] {
        let apiKey = try await fetchAPIKey()
        var components = URLComponents(string: "\(Self.apiV2Base)/records/search")!
        components.queryItems = [
            URLQueryItem(name: "variantControlNumber_is",        value: lotNumber),
            URLQueryItem(name: "description.recordGroupNumber",  value: recordGroup),
            URLQueryItem(name: "resultType",                     value: "description"),
            URLQueryItem(name: "rows",                           value: "5"),
        ]
        guard let url = components.url else { throw NARACatalogError.decodingError }
        return try await executeSearch(url: url, apiKey: apiKey)
    }

    /// Searches for Presidential Library materials using library name and collection keywords.
    ///
    /// Primary query path for `.presidentialLibrary` source notes. Presidential Library
    /// holdings transferred to NARA can appear in the catalog.
    ///
    /// - Parameters:
    ///   - library: e.g. `"Kennedy Library"`, `"Carter Library"`.
    ///   - collection: e.g. `"National Security Files, Vietnam Country Series"`.
    ///   - maxResults: Default 3.
    public func searchByPresidentialMaterials(
        library: String,
        collection: String,
        maxResults: Int = 3
    ) async throws -> [NARACatalogResult] {
        let apiKey = try await fetchAPIKey()
        let q = [library, collection].filter { !$0.isEmpty }.joined(separator: " ")
        var components = URLComponents(string: "\(Self.apiV2Base)/records/search")!
        components.queryItems = [
            URLQueryItem(name: "q",          value: q),
            URLQueryItem(name: "resultType", value: "description"),
            URLQueryItem(name: "rows",       value: "\(maxResults)"),
        ]
        guard let url = components.url else { throw NARACatalogError.decodingError }
        return try await executeSearch(url: url, apiKey: apiKey)
    }

    /// Backward-compatible Presidential Library resolution.
    public func resolvePresidentialLibrary(
        library: String,
        collection: String
    ) async throws -> NARACatalogResult? {
        try await searchByPresidentialMaterials(library: library, collection: collection, maxResults: 1).first
    }

    // MARK: - Generic Search (v1 fallback)

    /// General-purpose free-text search using the v1 API.
    ///
    /// Used when structured parameters are unavailable. Prefer the structured
    /// v2 methods (`searchByRecordGroup`, `searchByLotFile`) when possible.
    func searchCatalog(query: String) async throws -> NARACatalogResult? {
        let apiKey = try await fetchAPIKey()
        var components = URLComponents(string: "\(Self.apiV1Base)/search")!
        components.queryItems = [
            URLQueryItem(name: "q",          value: query),
            URLQueryItem(name: "resultType", value: "description"),
            URLQueryItem(name: "rows",       value: "1"),
        ]
        guard let url = components.url else { throw NARACatalogError.decodingError }
        return try await executeSearch(url: url, apiKey: apiKey).first
    }

    // MARK: - Internal Execution

    private func executeSearch(url: URL, apiKey: String) async throws -> [NARACatalogResult] {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        #if DEBUG
        print("[SourceExplorer] NARA Catalog query: \(url)")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw NARACatalogError.networkError(underlying: error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            switch httpResponse.statusCode {
            case 403: throw NARACatalogError.apiKeyRejected
            case 429: throw NARACatalogError.rateLimited
            default:  throw NARACatalogError.unexpectedResponse(statusCode: httpResponse.statusCode)
            }
        }

        // Record successful API hit for 30-day usage tracking displayed in Settings.
        await MainActor.run { NARAAPIKeyStore.shared.recordAPICall() }

        return decodeResults(from: data)
    }

    // MARK: - JSON Decoding (handles both v1 and v2 response shapes)

    private func decodeResults(from data: Data) -> [NARACatalogResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        // v2 response: {"opaResponse": {"results": {"result": [...]}}}
        // v1 response: {"body": {"hits": {"hits": [...]}}}
        let records: [[String: Any]]

        if let opaResponse = json["opaResponse"] as? [String: Any],
           let results     = opaResponse["results"] as? [String: Any] {
            // v2 format
            if let resultArray = results["result"] as? [[String: Any]] {
                records = resultArray
            } else if let single = results["result"] as? [String: Any] {
                records = [single]
            } else {
                return []
            }
        } else if let body = json["body"] as? [String: Any],
                  let hits = body["hits"] as? [String: Any],
                  let hitArray = hits["hits"] as? [[String: Any]] {
            // v1 format
            records = hitArray.compactMap { $0["_source"] as? [String: Any] }
                              .compactMap { $0["record"] as? [String: Any] }
        } else {
            return []
        }

        return records.compactMap { buildResult(from: $0) }
    }

    private func buildResult(from record: [String: Any]) -> NARACatalogResult? {
        // Field names vary between v1 and v2 responses
        let naId: String
        if let id = record["naId"] as? String, !id.isEmpty {
            naId = id
        } else if let id = record["naId"] as? Int {
            naId = String(id)
        } else if let desc = record["description"] as? [String: Any],
                  let id = desc["naId"] as? String {
            naId = id
        } else {
            return nil
        }

        let title = record["title"] as? String
            ?? (record["description"] as? [String: Any])?["title"] as? String
            ?? ""

        let scopeNote = record["scopeContent"] as? String
            ?? (record["description"] as? [String: Any])?["scopeAndContentNote"] as? String

        let rgNumber = record["recordGroupNumber"].flatMap { "\($0)" }
            ?? (record["description"] as? [String: Any])?["recordGroupNumber"].flatMap { "\($0)" }

        let seriesTitle = record["seriesTitle"] as? String
            ?? (record["description"] as? [String: Any])?["seriesTitle"] as? String

        let dateRange: String?
        if let coverageStartDate = record["coverageStartDate"] as? String,
           let coverageEndDate   = record["coverageEndDate"]   as? String {
            let start = String(coverageStartDate.prefix(4))
            let end   = String(coverageEndDate.prefix(4))
            dateRange = start == end ? start : "\(start)–\(end)"
        } else {
            dateRange = nil
        }

        let catalogURL = URL(string: "\(Self.catalogBase)/id/\(naId)")
            ?? URL(string: Self.catalogBase)!

        return NARACatalogResult(
            naId: naId, title: title, catalogURL: catalogURL,
            scopeNote: scopeNote, recordGroupNumber: rgNumber,
            seriesTitle: seriesTitle, dateRange: dateRange
        )
    }

    // MARK: - API Key

    private func fetchAPIKey() async throws -> String {
        guard let key = try await keychainStore.getNARACatalogAPIKey(), !key.isEmpty else {
            throw NARACatalogError.missingAPIKey
        }
        return key
    }

    /// Returns `true` if an API key is currently stored in the keychain.
    public func hasAPIKey() async -> Bool {
        (try? await keychainStore.getNARACatalogAPIKey() != nil) ?? false
    }
}
