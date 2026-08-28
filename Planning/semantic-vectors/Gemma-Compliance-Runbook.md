# Gemma compliance runbook — every obligation, its surface, and its deadline

**Date:** 2026-08-28 · **Status:** ACCEPTED by the owner 2026-08-28 ("i accept all of
these. proceed."), resolving the licence gate the step-4 assessment (§7.2) and spike both
named. **Authority for the clause readings:** `Planning/semantic-spike/Gemma-License-V5-Implications.md`
(the 2026-08-10 clause map). This runbook is the *implementation* side: which text goes on
which surface, in what order, and what recurs. Engineering-side document, not legal advice.

## 0. The escape-hatch check, run before anything was written

The clause map's §5 required one re-check before committing to the Gemma Terms: has
EmbeddingGemma been relicensed, or has an Apache-2.0 Gemma-family embedder appeared?
**Checked 2026-08-28: no, on both.** `google/embeddinggemma-300m` still declares
`license: gemma` (HF API, lastModified 2025-09-25 — untouched since release); Gemma 4
(released 2026-04-02, Apache-2.0) has no embedding sibling in Google's HF organization.
The Gemma Terms path therefore stands. **Re-run this check at every §5 recurrence below** —
if an Apache-2.0 embedder of comparable quality appears, every obligation in this document
dissolves for the cost recorded in §6.

## 1. The four §3.1 conditions, mapped to surfaces

| # | Condition (clause map §2) | Surface | Status |
|---|---|---|---|
| 4 | NOTICE file carrying the exact sentence | `NOTICE` at the repo root | **DONE (this PR)** |
| 3 | Prominent modification notices | "distributed unmodified" statement + SHA in `NOTICE`, the artifact-repo README (§3), and the About entry (§4) | NOTICE done; others land with their surfaces |
| 2 | A copy of the Terms to every recipient | Gemma Terms text bundled in the app's Full Notices screen, plus live links | **s2** (see §4) |
| 1 | Use-restriction flow-down as an enforceable provision, plus notice to users | (a) custom EULA in App Store Connect — **owner-only**, §5; (b) the download-consent sentence — **s2**, §4; (c) the About notice — **s2**, §4 | open |

The exact sentence, verbatim (already in `NOTICE`): *"Gemma is provided under and subject
to the Gemma Terms of Use found at ai.google.dev/gemma/terms"*. Both URLs verified live
2026-08-28 (`/gemma/terms`, `/gemma/prohibited_use_policy`).

## 2. Ordering rules — what must precede what

1. **Artifact-repo notices go live BEFORE the GGUF is uploaded anywhere.** Uploading the
   file to `frus-semantic-vectors` is itself "Distribution" under §1.1(b), regardless of
   whether any app ever fetches it. §3's text must be in that repo first.
2. **The in-app surfaces (§4) ship in the SAME build as the fetch path.** The About entry
   and consent sheet describe a real feature or none; they must not ship ahead of it, and
   the feature must not ship ahead of them.
3. **The custom EULA (§5) must be in App Store Connect before that build is submitted for
   review.** It is metadata, not binary — it can be staged any time before submission.
4. This PR's `NOTICE` and README paragraph run ahead of all of it deliberately: notices
   in place before distribution begins is the required order, and early is harmless.

## 3. The artifact-repo text — ready to paste into `frus-semantic-vectors`

Two files. First, append to that repo's `README.md`:

> ## Model weights
>
> Beside the per-volume vector shards, this repository's **Releases** host the query
> encoder the FRUS Explorer app can optionally download: Google's EmbeddingGemma model,
> as the unmodified lmstudio-community Q4_0 QAT GGUF build
> (`embeddinggemma-300m-qat-Q4_0.gguf`, 229,093,184 bytes, SHA-256
> `5a9e0645541b06367dec3fd14d0019015b872cfe36d35dfb2a9d752dade09020`).
>
> The model weights are **not** covered by this repository's license. Gemma is provided
> under and subject to the [Gemma Terms of Use](https://ai.google.dev/gemma/terms),
> including the [Gemma Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy).
> By downloading or using the model file you agree to those terms, including their use
> restrictions. The vector artifacts in this repository are model *outputs* and carry no
> model-license conditions.

Second, a `NOTICE` file in that repo carrying the same EmbeddingGemma section as this
repo's `NOTICE` (the exact sentence, the unmodified statement, the SHA).

**Hosting decision, recorded:** the GGUF goes up as a **GitHub Release asset** on
`frus-semantic-vectors`, not a git blob (the file exceeds GitHub's 100 MB hard limit) and
not LFS (bandwidth quotas on a 229 MB public download; `raw.githubusercontent.com` serves
LFS pointers, not content). A release asset has a stable direct URL
(`github.com/joshbotts/frus-semantic-vectors/releases/download/<tag>/<file>`), a 2 GB cap,
and no quota. The app verifies the download against the artifact's `modelFileSHA256`
before adopting it — the `SemanticShardFetcher` validate-before-keep pattern.

## 4. The in-app surfaces — s2 implements these

**Full Notices screen (About ▸ Legal), two additions:**

- A new section after Open Source — suggested header key `about.modelLicense.header` =
  "On-Device Model" — with one entry:
  - Title (`about.modelLicense.gemma.title`): **EmbeddingGemma (Google)**
  - Body (`about.modelLicense.gemma.body`): *"When you enable natural-language search,
    the app downloads Google's EmbeddingGemma model (229 MB) and runs it on this device
    to convert your search queries into vectors. The model is used unmodified. Gemma is
    provided under and subject to the Gemma Terms of Use found at
    ai.google.dev/gemma/terms, including its Prohibited Use Policy."*
  - Links to both URLs (in-app browser, like the existing rows), plus a row pushing the
    bundled Terms text (condition 2): capture the Terms page's text verbatim into a
    bundled resource (record the page's "last modified" date beside it — 2026-04-01 as of
    the clause map) and render it in a scrollable text screen.
- In the existing Open Source section, a **llama.cpp** entry (MIT), same shape as the
  TEI Publisher row: *"The natural-language search feature embeds llama.cpp
  (github.com/ggml-org/llama.cpp), © 2023–2026 The ggml authors, MIT License."*

**The download-consent sheet** (the #926 pattern — pressing the button is the consent):

> *"This optional 229 MB download is Google's EmbeddingGemma model, provided under and
> subject to the Gemma Terms of Use, including its Prohibited Use Policy. By downloading
> it you agree to use it consistently with those terms."* — with a "View the Terms" link.

This sentence plus §5's EULA clause is condition 1's "enforceable provision in the
agreement governing use, plus notice to users."

## 5. The App Store Connect custom EULA — owner-only checklist

Apple's **standard** EULA does not carry the Gemma use restrictions, so the flow-down
needs a custom one. One-time metadata change, no binary involved:

1. App Store Connect → the app → **App Information** → **License Agreement** → Edit →
   replace the standard agreement with custom text.
2. Base text: Apple's own "Licensed Application End User License Agreement" template
   (Apple requires its minimum terms to survive in any custom EULA — start from their
   template, do not draft from scratch).
3. Append one clause:

   > *"Optional on-device model. The App can, at your request, download Google's
   > EmbeddingGemma model for on-device search. The model is provided under and subject
   > to the Gemma Terms of Use (ai.google.dev/gemma/terms), including the Gemma
   > Prohibited Use Policy (ai.google.dev/gemma/prohibited_use_policy), which are
   > incorporated into this Agreement with respect to your use of the model. You may use
   > the model only in compliance with those terms, and your rights to use the model
   > terminate automatically on breach of them."*

4. Save; the custom EULA then shows on the App Store product page. Do this before the
   build carrying the fetch path is submitted (§2.3).
5. For the Mac **DirectDistribution** channel there is no ASC EULA: the in-app consent
   sentence (§4) plus the bundled Terms are the flow-down for that channel — already
   covered by the same build.

## 6. Recurring obligations and the standing exits

- **PUP re-check at release cadence.** The Prohibited Use Policy is incorporated by live
  URL and updatable. At each release that includes the encoder: re-read the PUP's
  last-modified date; if changed, re-read the policy (embeddings-only search sits far
  from every current category). Fold the §0 escape-hatch check into the same ritual.
- **Termination containment (clause map §3):** on any termination, pull the encoder —
  typed semantic search dies, and *nothing else*: all V-1–V-4 artifacts are Outputs and
  §3.3 survives termination. The prospective loss is re-embedding rights: a future corpus
  change would need a different model — one overnight re-embed (~6.1 h measured), a
  repack, artifact redistribution, and a re-run of the 25-query instrument (the judged
  verdict is Gemma-space).
- **Trademark:** describe, never brand — "uses Google's EmbeddingGemma model" is fine;
  nothing implying Google endorsement.
- **What never carries obligations:** every shipped vector artifact (bundled tiers,
  shards, map, centroids), the harvest itself (local use, not Distribution), and all
  Apache-2.0 code in this repo, llama.cpp integration included.
