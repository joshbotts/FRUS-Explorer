// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The FRUS era buckets used by the parser eval report.
///
/// Mirrors the buckets of the Source Explorer audit's coverage table
/// (`Planning/Completed/Source-Explorer-Audit-2026-07-03.md` §2.1) so eval numbers line up
/// directly with the audit's per-era analysis and the Phase 2 verification targets
/// (unrecognized <10% for 1906–1963, <15% overall).
///
/// A volume is bucketed by the first year of its coverage span, taken from the
/// leading four digits of its volume id (`frus1952-54v01p2` → 1952 → `.era1952to1954`).
/// Every id in the corpus matches `frus\d{4}…`.
///
/// Version history:
///   1.0 — Source Explorer Phase 2 (Session 2026-07-03): initial implementation
public enum EraBucket: Int, CaseIterable, Sendable {
    /// Volumes beginning before 1906 (pre-Numerical File despatch era).
    case pre1906
    /// 1906–1939 (Numerical File, then the central decimal file).
    case era1906to1939
    /// 1940–1951 (decimal file, wartime agencies).
    case era1940to1951
    /// The 1952–54 subseries (last top-level-note encoding; lot files emerge).
    case era1952to1954
    /// 1955–57 (first head-nested source-note encoding).
    case era1955to1957
    /// 1958–60.
    case era1958to1960
    /// 1961–63 (Kennedy; presidential-library citations dominate).
    case era1961to1963
    /// 1964–1976 (subject-numeric central files, Johnson/Nixon/Ford libraries).
    case era1964to1976
    /// 1977 and later (CFPF reels, AAD, Carter/Reagan/Bush libraries).
    case era1977plus

    /// Buckets `volumeId` by its leading four-digit year, or `nil` when the id
    /// carries no `frus\d{4}` prefix.
    ///
    /// - Parameter volumeId: A FRUS volume id such as `frus1969-76v08`.
    public init?(volumeId: String) {
        guard volumeId.hasPrefix("frus") else { return nil }
        let digits = volumeId.dropFirst("frus".count).prefix(4)
        guard digits.count == 4, let year = Int(digits) else { return nil }
        self.init(year: year)
    }

    /// Buckets a coverage start year.
    ///
    /// - Parameter year: The first year of the volume's coverage span.
    public init(year: Int) {
        switch year {
        case ..<1906:      self = .pre1906
        case 1906...1939:  self = .era1906to1939
        case 1940...1951:  self = .era1940to1951
        case 1952...1954:  self = .era1952to1954
        case 1955...1957:  self = .era1955to1957
        case 1958...1960:  self = .era1958to1960
        case 1961...1963:  self = .era1961to1963
        case 1964...1976:  self = .era1964to1976
        default:           self = .era1977plus
        }
    }

    /// Report label, matching the audit table's row names.
    public var label: String {
        switch self {
        case .pre1906:        return "pre-1906"
        case .era1906to1939:  return "1906-1939"
        case .era1940to1951:  return "1940-1951"
        case .era1952to1954:  return "1952-1954"
        case .era1955to1957:  return "1955-1957"
        case .era1958to1960:  return "1958-1960"
        case .era1961to1963:  return "1961-1963"
        case .era1964to1976:  return "1964-1976"
        case .era1977plus:    return "1977+"
        }
    }
}
