// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CatalogJSONValue

/// A fully general, `Sendable` JSON tree — the harvester's canonical in-memory form for a
/// NARA Catalog description record.
///
/// ## Why an untyped tree rather than a `Decodable` struct
///
/// The existing `CentralFilesIndexGeneratorCore.NARACatalogHarvestClient` decodes NARA records
/// into a narrow `Decodable` mirror that names five fields. Everything else in the response —
/// including `creators`, every date, every restriction, and every physical-holdings detail —
/// is silently discarded at the decode boundary, which is precisely why the HMS/MLR entry
/// numbers could not be recovered offline in #315 and a full re-query was required.
///
/// This harvester's remit is "all available data", so it decodes into a tree that cannot drop a
/// field it was not told about. A typed projection (`SeriesRecord`) is derived *from* the tree
/// for the fields we understand; the tree itself is what the field census walks and what a
/// corrected projection can be re-applied to with no re-download.
///
/// `[String: Any]` would have been the obvious shape and is unusable here: it is not `Sendable`,
/// so it cannot cross an actor boundary under Swift 6 strict concurrency.
///
/// ## Value-encoding quirks this type absorbs
///
/// NARA's export is not consistently typed, and every accessor below coerces rather than
/// failing. All three quirks are measured, not anticipated:
///
/// - `naId` arrives as a JSON **number** in the bulk export and as either a number or a string
///   from the API (the reason `CentralFilesIndexGeneratorCore.CatalogScalar` exists).
/// - `audiovisual` is a **quoted string**, and its capitalisation varies: `"false"` in RG 486,
///   `"True"` in the official API example published on archives.gov. `boolValue` therefore
///   compares case-insensitively rather than against a literal.
/// - `holdingsMeasurements[].count` is a **floating-point** number (`1.0`, `13.0`) even when it
///   counts discrete boxes, so `intValue` accepts an integral `Double`.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public enum CatalogJSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([CatalogJSONValue])
    case object([String: CatalogJSONValue])
}

// MARK: - Decodable

extension CatalogJSONValue: Decodable {

    /// Decodes any JSON value.
    ///
    /// Integers are probed before doubles so a whole number re-encodes without a spurious `.0`. That
    /// ordering is what keeps `naId` usable: probing `Double` first would turn `1933760` into
    /// `1933760.0` and every identifier comparison would have to defend against it.
    ///
    /// The cost, stated plainly because the raw store is described as lossless: a JSON float that
    /// happens to be whole — `"count": 1.0`, which is how NARA writes holdings measurements — is
    /// normalised to the integer `1`. The stored NDJSON therefore preserves every JSON *value*, and
    /// is not byte-identical to NARA's original line for such fields. Nothing downstream depends on
    /// the distinction (`doubleValue` reads either form), but the field census will report the type
    /// as `int` for those paths, which is a fact about this decoder rather than about the export.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([CatalogJSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: CatalogJSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrepresentable JSON value")
        }
    }
}

// MARK: - Encodable

extension CatalogJSONValue: Encodable {

    /// Re-encodes the tree. Used to persist matched raw records as NDJSON so a corrected
    /// projection can be re-applied offline (`PROJECT_ONLY`) without re-streaming the export.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:            try container.encodeNil()
        case .bool(let b):     try container.encode(b)
        case .int(let i):      try container.encode(i)
        case .double(let d):   try container.encode(d)
        case .string(let s):   try container.encode(s)
        case .array(let a):    try container.encode(a)
        case .object(let o):   try container.encode(o)
        }
    }
}

// MARK: - Accessors

extension CatalogJSONValue {

    /// The value's `[String: CatalogJSONValue]` payload, or `nil` if it is not an object.
    public var objectValue: [String: CatalogJSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// The value's element list, or `nil` if it is not an array.
    public var arrayValue: [CatalogJSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    /// The value as an array **regardless of arity**: a lone object or scalar becomes a
    /// one-element array, `.null` becomes empty.
    ///
    /// NARA's schemas declare several fields as arrays that the export sometimes emits as a bare
    /// object (`accessRestriction` is an object; `physicalOccurrences` is an array). Rather than
    /// hard-code which is which — and be wrong for a field the census has not yet seen — every
    /// list-shaped read goes through this, so an arity change upstream widens the projection
    /// instead of emptying it.
    public var asArray: [CatalogJSONValue] {
        switch self {
        case .null:         return []
        case .array(let a): return a
        default:            return [self]
        }
    }

    /// The value as a `String`, coercing numbers and booleans.
    ///
    /// Integral doubles stringify without the fractional part so an `naId` that arrived as
    /// `1.933760e6` cannot become `"1933760.0"` and fail to match its integer spelling.
    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i):    return String(i)
        case .double(let d): return d == d.rounded() ? String(Int(d)) : String(d)
        case .bool(let b):   return b ? "true" : "false"
        case .null, .array, .object: return nil
        }
    }

    /// A trimmed, non-empty `String`, or `nil`. The common case for every text field: NARA emits
    /// both absent keys and present-but-blank values, and neither should reach the artifact.
    public var nonEmptyString: String? {
        guard let s = stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }

    /// The value as an `Int`, accepting an integral `Double` and a numeric `String`.
    public var intValue: Int? {
        switch self {
        case .int(let i):    return i
        case .double(let d): return d == d.rounded() ? Int(d) : nil
        case .string(let s): return Int(s.trimmingCharacters(in: .whitespaces))
        default:             return nil
        }
    }

    /// The value as a `Double`, accepting an `Int` and a numeric `String`.
    public var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i):    return Double(i)
        case .string(let s): return Double(s.trimmingCharacters(in: .whitespaces))
        default:             return nil
        }
    }

    /// The value as a `Bool`, accepting the **quoted, arbitrarily-capitalised** strings NARA
    /// actually ships (`"true"`, `"True"`, `"false"`, `"False"`) as well as a real JSON boolean.
    ///
    /// The case-insensitive compare is the load-bearing part: `audiovisual` is `"false"` in
    /// RG 486 and `"True"` in NARA's own published example, so a literal `== "true"` test would
    /// read one of the two as `nil` and silently mis-report a whole record group.
    public var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .int(let i):  return i == 0 ? false : (i == 1 ? true : nil)
        case .string(let s):
            switch s.trimmingCharacters(in: .whitespaces).lowercased() {
            case "true", "yes", "y", "1":  return true
            case "false", "no", "n", "0": return false
            default: return nil
            }
        default: return nil
        }
    }

    /// Member lookup on an object. Returns `.null`-equivalent `nil` for a non-object.
    public subscript(key: String) -> CatalogJSONValue? {
        guard case .object(let o) = self else { return nil }
        let value = o[key]
        // Collapse an explicit JSON null to "absent" for read purposes. The distinction is
        // preserved for the census (which walks the raw tree), but a projection asking for a
        // field should treat `null` and missing identically.
        if case .some(.null) = value { return nil }
        return value
    }

    /// Whether the key is present at all, **including** an explicit `null`.
    ///
    /// The census needs this distinction that `subscript` deliberately erases: a field that is
    /// always present-and-null is a different upstream fact from a field that is never emitted,
    /// and conflating them is how "we captured nothing" gets misread as "there is nothing".
    public func hasKey(_ key: String) -> Bool {
        guard case .object(let o) = self else { return false }
        return o.keys.contains(key)
    }
}

// MARK: - NDJSON parsing

extension CatalogJSONValue {

    /// Decodes one NDJSON line into a record tree, unwrapping NARA's `{"record": {…}}` envelope.
    ///
    /// Every line of the S3 bulk export is wrapped; the live API delivers the same object at
    /// `_source.record`. Both are accepted, as is a bare record object, so one parser serves the
    /// bulk source, the API source, and the re-projection path over persisted NDJSON.
    ///
    /// - Returns: the unwrapped record, or `nil` for a blank line or a line that is not an object.
    public static func decodeRecordLine(_ line: Data) throws -> CatalogJSONValue? {
        guard !line.isEmpty else { return nil }
        let value = try JSONDecoder().decode(CatalogJSONValue.self, from: line)
        guard value.objectValue != nil else { return nil }
        if let wrapped = value["record"], wrapped.objectValue != nil { return wrapped }
        if let source = value["_source"]?["record"], source.objectValue != nil { return source }
        return value
    }
}
