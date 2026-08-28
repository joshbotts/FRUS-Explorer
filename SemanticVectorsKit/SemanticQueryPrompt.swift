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

/// The QUERY-side prompt template — the one judged fact the artifact's provenance does not carry.
///
/// `SemanticVectorsArtifacts.Provenance.prefix` pins the DOCUMENT prompt (`title: none | text: `),
/// because that is what the corpus was embedded under. The query side was an open question until
/// the 2026-08-27 evaluation ran all 25 owner queries under three templates and the owner judged
/// the results: the model's retrieval template won (P 0.65 / MRR 0.77), and the alternatives
/// materially diverge from it (document 63%, bare 54% top-10 agreement) — so the prompt is a
/// measured decision, not a convention (`Planning/semantic-vectors/eval-2026-08-27/VERDICT.md`).
///
/// One definition here, used by the in-app encoder and the evaluation harness both, so the string
/// a shipped query is embedded under is the string the verdict judged — a one-character drift
/// would silently move every query in the space.
public enum SemanticQueryPrompt {

    /// The template, trailing space included; the query text is appended verbatim.
    public static let queryPrefix = "task: search result | query: "
}
