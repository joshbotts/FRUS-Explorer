# The Gemma licence, mapped onto V-5 — what shipping the query encoder signs the app up for

**Status:** research memo, 2026-08-10, supporting the owner's licence read (the second of the
two acts that close V-0). Sources fetched today: the Gemma Terms of Use at
ai.google.dev/gemma/terms (page last modified 2026-04-01; EmbeddingGemma is in its Appendix),
the Gemma Prohibited Use Policy (last modified 2024-02-21), both Hugging Face repos, Google's
own MediaPipe/AI-Edge shipping guidance, and the commentary record. Quotes are verbatim from
the live pages. **This is an engineering-side clause map, not legal advice**; the Google staff
answer on the topic (huggingface.co/google/gemma-7b/discussions/122) itself declines to bless
any implementation and points at counsel.

## 1. The boundary that matters most: Outputs are free, weights are not

The Terms define Model Derivatives to cover "(i) modifications to Gemma, (ii) works based on
Gemma" — a Q4_0 GGUF or a Core ML conversion is squarely one — but state: *"For clarity,
Outputs are not deemed Model Derivatives"* (§1.1(e)), and *"Google claims no rights in Outputs
you generate using Gemma"* (§3.3).

Consequence for this workstream: **every artifact V-1 through V-4 ships is an Output.** The
raw store's chunk vectors, the pooled document vectors, Tier 0's map coordinates and
centroids, Tier 1's binary sketches, Tier 2's int8 shards — all licence-free, no flow-down,
no notices, regardless of model choice. The Gemma question **binds exactly one thing: V-5's
bundled query encoder.** Phase 3 (the harvest itself) is local use, not Distribution, and is
unconditionally fine.

## 2. If V-5 ships EmbeddingGemma weights: four cumulative §3.1 conditions

Delivery mechanism is irrelevant — "Distribution" is "any transmission, publication, or other
sharing … to a third party" (§1.1(b)), so a Background Assets pack, an app-owned CDN, or the
binary itself are the same act. The conditions:

1. **Flow-down as an enforceable term:** the §3.2 use restrictions (which incorporate the
   Prohibited Use Policy by reference) must appear "as an enforceable provision in any
   agreement (e.g., license agreement, terms of use, etc.) governing the use and/or
   distribution," plus notice to users. Apple's **standard** App Store EULA does not carry
   them ⇒ a **custom EULA in App Store Connect** plus an in-app notice is the workable shape.
2. **A copy of the Gemma Terms to every recipient** ⇒ bundle the terms text in the app's
   licences screen.
3. **Prominent modification notices** on modified files ⇒ the Core ML/quantized conversion
   must be labelled as modified from the released checkpoint.
4. **A NOTICE file** with the exact sentence: "Gemma is provided under and subject to the
   Gemma Terms of Use found at ai.google.dev/gemma/terms".

All four are paperwork, not engineering. The real costs are §3 below.

## 3. The ongoing-exposure clauses (the actual price)

- **The restricted-use list can change under a shipped app.** The Terms incorporate the PUP
  by live URL; the PUP's own first line reserves the right to update it "from time to time."
  (The incorporation sentence does *not* say "as may be updated" — an ambiguity the
  commentary glosses over — but the practical posture is: the list is Google's to edit.)
- **Termination on breach of any term, with a delete-and-cease duty** (§4.5). Note the
  self-referential trap the commentary flags: failing the §2 flow-down is itself a breach and
  therefore a termination trigger. Containment if it ever fired: the app pulls the encoder
  (typed-query semantic search dies), **but every V-1–V-4 feature survives** — vectors are
  Outputs and §3.3 survives termination. What is lost prospectively is regeneration: no
  future re-embed on Gemma, so the vector artifacts freeze until re-harvested on another
  model (~one overnight, per the spike's measured clocks).
- **The remote-restriction reservation** (§3.2 final paragraph): Google "reserves the right
  to restrict (remotely or otherwise) usage … Google reasonably believes are in violation."
  No technical channel reaches an offline Core ML file, and no exercise of the right was
  found in the record — read it as a legal lever, not a kill switch, but it is in the
  contract.
- **An embeddings-only research app sits far from every PUP category.** The prohibitions are
  generation-framed (rights-violating content, dangerous activity, misinformation, sexual
  content); an embedder generates no content, has no safety filter to circumvent, and app
  users cannot prompt the model — they type search queries whose vectors are compared
  against precomputed Outputs. The exposure is the update clause, not today's list.

## 4. Precedent (what shippers actually do)

- **Google's own surfaces never show an in-app Gemma licence flow.** The MediaPipe iOS guide
  has the developer accept at Kaggle/HF, then bundle the file into the Xcode project —
  silent on the developer's own §3.1 duties. The AI Edge Gallery app instead makes the *end
  user* log into Hugging Face and accept the gate at download time (delegated acceptance).
- Third-party App Store apps ship quantized Gemma builds (Private LLM et al.) with no
  visible compliance flow; **no App Store rejection tied to a model licence was found**
  (absence of evidence, noted as such). App Review does not appear to audit model licences.
- The one on-record Google answer confirms the obligation categories and declines to
  validate implementations.
- The HF repo detail worth knowing: `google/embeddinggemma-300m` is gated behind accepting
  the terms; the `lmstudio-community` QAT GGUF is **ungated** but tagged `license: gemma` —
  the terms govern it regardless, and LM Studio's disclaimer pushes compliance onto the
  downloader.

## 5. The 2026 wrinkle, and what it does to sequencing

**Gemma 4 (April 2026) is Apache-2.0** — Google's first OSI-licensed Gemmaverse release —
but it is *not retroactive*: EmbeddingGemma remains under the custom Terms today. Two live
escape hatches at V-5 time: a Gemma-4-family embedding model (or a relicensed
EmbeddingGemma), which would dissolve this memo entirely — **re-check before deciding V-5**
— or arctic-embed l-v2.0, Apache-2.0 now, measured second on every gate at 2.2× the harvest
clock.

The sequencing point the design already implies (§3.1/§6.4: corpus and query vectors must
come from one artifact): **a V-5 model swap is a full re-embed.** The spike priced that at
one overnight run (~6.1 h gemma, ~13.5 h arctic) plus a re-pack — real but contained. So
choosing gemma for Phase 3 does **not** irrevocably marry V-5 to these terms; it caps the
cost of changing course at one more Studio night. Conversely, if the owner already knows
they will never ship under a flow-down EULA, arctic-at-Phase-3 buys that certainty for
second-place gate numbers and a longer harvest.

---

Version history:
  1.0 — 2026-08-10: initial clause map from the live Terms/PUP/repos/precedent record,
        scoped to the V-5 weight-bundling decision.
