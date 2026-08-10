#!/usr/bin/env python3
"""Does a trailing EOS change an embedding model's vectors? Two one-minute probes.

Context: during the V-0 spike, LM Studio's console warned on every batch that
"At least one last token in strings embedded is not SEP. 'tokenizer.ggml.add_eos_token'
should be set to 'true' in the GGUF header" — i.e. the GGUF's metadata told llama.cpp
NOT to append an end-of-sequence token, and llama.cpp suspects the model wants one.
Whether that suspicion is correct is a model-card question; whether it MATTERS is
measurable. This script measures it, two ways.

MODE 1 (default): same model, appended-literal A/B. Embeds each sample as
harvest_embeddings.py sends it and again with the literal EOS string appended, and
reports the cosine per pair. The A/B is only *conclusive about the EOS token* if the
server parsed the literal as ONE special token, which the probe tries to confirm from
usage.prompt_tokens — but note the field's real-world behaviour, measured 2026-08-10:
LM Studio reports prompt_tokens: 0 for embeddings requests, so token accounting is
usually UNAVAILABLE and the cosine then bounds the effect without attributing it
(one special token vs a few literal-text tokens — indistinguishable server-side).

MODE 2 (set MODEL_B): same input, two models — the decisive experiment. Load BOTH the
original GGUF and a copy whose add_eos_token flag was flipped (gguf_eos_flag.py), and
embed identical text through each. Same weights, one metadata bit apart:
  cosine ~= 1.000000 (>= 0.99999)  ->  the flag changed nothing; llama.cpp ignored it.
  cosine below that                ->  the flag is live; re-spike the flipped copy into
                                       a FRESH folder and carry both stores to Phase 2,
                                       where the retrieval gates score the two
                                       configurations head-to-head.

Reading Mode 1 (mean pooling over ~40-70 token samples):
  min cosine >= 0.995  ->  a trailing-token perturbation is immaterial; keep the store.
  min cosine <  0.99   ->  load-bearing; do the Mode 2 experiment before trusting it.
  in between           ->  gray zone; do the Mode 2 experiment and ship both arms.

Stdlib only, like the harvester. Run on the machine with LM Studio serving:

    MODEL="<id>" python3 check_eos_effect.py
    MODEL="<original id>" MODEL_B="<flipped-copy id>" python3 check_eos_effect.py

Environment:
  LMSTUDIO_URL  default http://localhost:1234
  MODEL         LM Studio model id (else auto-picked iff exactly one 'embed' id)
  MODEL_B       second model id — presence switches to Mode 2
  PREFIX        default "title: none | text: " (embeddinggemma's document prompt —
                mirror whatever the harvest used; pass PREFIX="" for a bare model)
  EOS           Mode 1 literal, default "<eos>" (Gemma). For a BERT/XLM-R-family
                model try EOS="</s>" or EOS="[SEP]"
"""

import json
import math
import os
import sys
import urllib.request

URL = os.environ.get("LMSTUDIO_URL", "http://localhost:1234").rstrip("/")
PREFIX = os.environ.get("PREFIX", "title: none | text: ")
EOS = os.environ.get("EOS", "<eos>")

SAMPLES = [
    "The Secretary of State presents his compliments to the Minister of Foreign "
    "Affairs and has the honor to acknowledge the receipt of his note of the 12th "
    "instant concerning the claims convention.",
    "Mr. Seward to Mr. Adams. Department of State, Washington, April 1, 1861. Sir: "
    "Your dispatch of March 12 has been received and submitted to the President.",
    "Telegram from the Embassy in France to the Department of State, transmitting "
    "the views of the Foreign Ministry on the proposed naval conference and "
    "requesting instructions before the plenary session.",
    "Memorandum of conversation between the Under Secretary and the Ambassador of "
    "the Soviet Union regarding the exchange of notes on the status of Berlin.",
]


def embed_one(model, text):
    """(vector, usage.prompt_tokens or None) for a single-string embeddings request."""
    payload = {"model": model, "input": text}
    req = urllib.request.Request(URL + "/v1/embeddings", data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        body = json.loads(resp.read())
    return body["data"][0]["embedding"], body.get("usage", {}).get("prompt_tokens")


def pick_model():
    with urllib.request.urlopen(URL + "/v1/models", timeout=30) as resp:
        ids = [m.get("id", "") for m in json.loads(resp.read()).get("data", [])]
    explicit = os.environ.get("MODEL", "")
    if explicit:
        return explicit
    embed_ids = [i for i in ids if "embed" in i.lower()]
    if len(embed_ids) == 1:
        return embed_ids[0]
    sys.exit("Set MODEL explicitly. Models the server reports:\n  "
             + "\n  ".join(ids or ["(none)"]))


def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    return dot / (na * nb)


def two_model_mode(model_a, model_b):
    print("MODE 2 — same input through two models (the same-weights flag A/B)")
    print("A: %s\nB: %s\nprefix: %r" % (model_a, model_b, PREFIX))
    cosines = []
    for index, text in enumerate(SAMPLES):
        vec_a, _ = embed_one(model_a, PREFIX + text)
        vec_b, _ = embed_one(model_b, PREFIX + text)
        if len(vec_a) != len(vec_b):
            sys.exit("dimension mismatch (%d vs %d) — are these really the same weights?"
                     % (len(vec_a), len(vec_b)))
        value = cosine(vec_a, vec_b)
        cosines.append(value)
        print("sample %d: cosine %.6f" % (index + 1, value))
    print("\nmin cosine %.6f | mean %.6f" % (min(cosines), sum(cosines) / len(cosines)))
    if min(cosines) >= 0.99999:
        print("Effectively identical: the flag changed NOTHING (llama.cpp ignored it). "
              "The original store stands alone; report this outcome.")
    else:
        print("The flag is live — the two configurations genuinely embed differently. "
              "Re-spike the flipped copy into a FRESH folder (pin it via MODEL_FILE) and "
              "carry both stores to Phase 2.")


def eos_literal_mode(model):
    print("MODE 1 — one model, EOS literal appended")
    print("model: %s" % model)
    print("prefix: %r   eos literal: %r" % (PREFIX, EOS))
    cosines, deltas = [], []
    for index, text in enumerate(SAMPLES):
        base_vec, base_toks = embed_one(model, PREFIX + text)
        eos_vec, eos_toks = embed_one(model, PREFIX + text + EOS)
        delta = (eos_toks - base_toks) if (base_toks is not None and eos_toks is not None) else None
        value = cosine(base_vec, eos_vec)
        cosines.append(value)
        deltas.append(delta)
        print("sample %d: tokens %s -> %s (delta %s)   cosine %.6f"
              % (index + 1, base_toks, eos_toks, delta, value))

    print()
    print("min cosine %.6f | mean %.6f" % (min(cosines), sum(cosines) / len(cosines)))
    if all(d == 1 for d in deltas):
        print("Delta +1 on every pair: %r was parsed as ONE token — the A/B measured the "
              "EOS token itself. Read: >=0.995 immaterial; <0.99 load-bearing; between, "
              "run Mode 2 and ship both arms." % EOS)
    elif any(d is None for d in deltas) or all(d == 0 for d in deltas):
        print("Token accounting unavailable (the server reported no/zero prompt_tokens — "
              "LM Studio does this for embeddings), so whether %r became one special "
              "token or a few literal-text tokens is UNKNOWN. The cosine bounds a "
              "trailing perturbation either way; for an attributed answer run Mode 2 "
              "(gguf_eos_flag.py + MODEL_B)." % EOS)
    else:
        print("Delta != +1 with real counts: %r tokenized as literal text, so this did "
              "NOT test the EOS token. Run Mode 2 (gguf_eos_flag.py + MODEL_B)." % EOS)


def main():
    model_b = os.environ.get("MODEL_B", "")
    if model_b:
        two_model_mode(pick_model(), model_b)
    else:
        eos_literal_mode(pick_model())


if __name__ == "__main__":
    main()
