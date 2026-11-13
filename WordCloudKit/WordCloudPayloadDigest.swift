// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// SHA-256 is CryptoKit's on Apple platforms and swift-crypto's `Crypto` where CryptoKit is missing
// (Linux), whose package supplies it; the two give the same digest of the same bytes.
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation

// MARK: - WordCloudPayloadDigest

/// Identifies the lexicon and stopword payloads a tokenisation was performed under.
///
/// The keyness baseline is a ~50-minute offline run; `word-cloud-lexicons.json` and
/// `word-cloud-stopwords.json` are small bundled resources that any session might reasonably edit.
/// Add a concept to the lexicon without rerunning the generator and the scope side starts counting
/// a term the reference has never heard of — reference zero, top of the keyness list, in every
/// scope, in every build, with nothing anywhere to say so. `VolumeSubjectProfilesGenerator` already
/// pins its upstream drop by md5 for exactly this reason; this is the same interlock.
///
/// Both sides compute the digest **here**, over the raw file bytes, so the generator and the app
/// cannot disagree about how it is derived.
///
/// Version history:
///   1.0 — S-1: initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24d): swift-crypto's SHA-256 where CryptoKit is missing
public enum WordCloudPayloadDigest {

    /// Hex SHA-256 of the given bytes.
    ///
    /// Raw bytes, not a parsed-and-re-encoded form: re-encoding would silently forgive a
    /// reordering or a formatting change, and the point is to notice that the file was touched.
    public static func digest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Hex SHA-256 of the file at `url`, or `nil` when it cannot be read.
    ///
    /// A `nil` never matches a recorded digest, so an unreadable payload reads as a mismatch —
    /// which is the safe direction: it withholds keyness rather than computing it against
    /// something unverified.
    public static func digest(ofFileAt url: URL) -> String? {
        (try? Data(contentsOf: url)).map(digest(of:))
    }
}
