#!/usr/bin/env python3
"""Does the missing trailing EOS change embeddinggemma's vectors? A one-minute A/B.

Context: during the V-0 spike, LM Studio's console warned on every batch that
"At least one last token in strings embedded is not SEP. 'tokenizer.ggml.add_eos_token'
should be set to 'true' in the GGUF header" — i.e. the GGUF's metadata told llama.cpp
NOT to append an end-of-sequence token, and llama.cpp suspects the model wants one.
Whether that suspicion is correct for a Gemma-architecture embedding model is a
model-card question; whether it MATTERS is measurable right here. This probe embeds a
few FRUS-flavored samples twice — exactly as harvest_embeddings.py sends them, and with
the literal EOS token appended — and reports the cosine between each pair.

The A/B is only valid if the server parsed the appended "<eos>" as ONE special token,
so the probe checks usage.prompt_tokens: a delta of exactly +1 per pair validates the
comparison; any other delta means the literal tokenized as plain text and the probe
says so instead of reporting a meaningless cosine. Watch the LM Studio console while
it runs: the +eos requests should NOT trigger the warning if the delta is +1.

Reading the result (mean pooling over ~40-60 token samples):
  min cosine >= 0.995  ->  the missing EOS is immaterial; keep the spike store and
                           record the warning in the hand-off.
  min cosine <  0.99   ->  the header is load-bearing; resolve add_eos_token (model
                           card / HF discussions / re-download or header edit) and
                           re-spike this model into a FRESH folder, keeping both.
  in between           ->  bring both a fixed-header store and the original to
                           Phase 2 and let the retrieval gates decide.

Stdlib only, like the harvester. Run on the machine with LM Studio serving the model:

    MODEL="<id from /v1/models>" python3 check_eos_effect.py

Environment:
  LMSTUDIO_URL  default http://localhost:1234
  MODEL         LM Studio model id (else auto-picked iff exactly one 'embed' id)
  PREFIX        default "title: none | text: " (embeddinggemma's document prompt —
                mirror whatever the harvest used; pass PREFIX="" for a bare model)
  EOS           default "<eos>" (the literal appended in the B arm; Gemma's EOS.
                For a BERT/XLM-R-family model try EOS="</s>" or EOS="[SEP]")
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


def main():
    model = pick_model()
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
    if any(d is None for d in deltas):
        print("The server did not report usage.prompt_tokens, so the probe cannot confirm "
              "%r was parsed as one special token. Treat the cosines as suggestive only." % EOS)
    elif all(d == 1 for d in deltas):
        print("Delta +1 on every pair: %r was parsed as ONE token — the A/B is valid." % EOS)
        print("min cosine %.6f | mean %.6f" % (min(cosines), sum(cosines) / len(cosines)))
        print("Reading: >=0.995 immaterial, keep the store; <0.99 the header is load-bearing; "
              "between, bring both configurations to Phase 2.")
    else:
        print("Delta != +1, so %r tokenized as literal text and this run did NOT test the EOS "
              "token. The header question stays open — report this outcome." % EOS)


if __name__ == "__main__":
    main()
