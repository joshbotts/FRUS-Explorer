#!/usr/bin/env python3
"""Read — or flip to true — `tokenizer.ggml.add_eos_token` in a GGUF header. Stdlib-only.

Why this exists: the embeddinggemma QAT GGUF harvested with llama.cpp warning that
'tokenizer.ggml.add_eos_token' should be true, i.e. every chunk was embedded without a
trailing EOS. The decisive experiment is a same-weights A/B: copy the GGUF, flip the
flag on the COPY, and embed identical text through both (check_eos_effect.py's MODEL_B
mode) — same weights, one metadata bit apart. This tool is the flip.

    python3 gguf_eos_flag.py show /path/to/model.gguf
    python3 gguf_eos_flag.py set-true /path/to/COPY-of-model.gguf
    python3 gguf_eos_flag.py set-false /path/to/COPY-of-model.gguf

`show` prints the flag's presence/value plus neighbouring context (architecture, name,
add_bos_token, bos/eos/sep token ids). `set-true`/`set-false` rewrite the flag's single
value byte in place — run them ONLY on a copy, never the original: the point is two
artifacts, one per configuration, each pinnable by SHA (printed after the flip for
MODEL_FILE provenance). `set-false` exists for the CONSUMPTION check: when the shipped
header is already correct (the 2026-08-10 finding — the QAT gemma ships add_eos_token
= true while the SEP warning fires anyway, because Gemma's vocab has no SEP for the
check to find), flipping a copy DOWN and comparing identical inputs through both
models proves whether the engine consumes the flag at embedding time at all.

Refusals are part of the contract: not GGUF / GGUF v1 / key ABSENT / key present but
not BOOL all exit non-zero without writing a byte. "Absent" matters — a missing key
cannot be patched in place (inserting one shifts every offset in the file and needs a
full rewrite with the gguf library); report that outcome instead of improvising.
"""

import hashlib
import struct
import sys

# GGUF metadata value types (spec v2/v3).
FIXED_SIZES = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8}
T_BOOL, T_STRING, T_ARRAY = 7, 8, 9

INTEREST = (
    "general.architecture", "general.name",
    "tokenizer.ggml.add_bos_token", "tokenizer.ggml.add_eos_token",
    "tokenizer.ggml.bos_token_id", "tokenizer.ggml.eos_token_id",
    "tokenizer.ggml.seperator_token_id", "tokenizer.ggml.separator_token_id",
)

SCALAR_FMT = {0: "<B", 1: "<b", 2: "<H", 3: "<h", 4: "<I", 5: "<i",
              6: "<f", 7: "<B", 10: "<Q", 11: "<q", 12: "<d"}


def u32(f):
    return struct.unpack("<I", f.read(4))[0]


def u64(f):
    return struct.unpack("<Q", f.read(8))[0]


def gguf_string(f):
    return f.read(u64(f)).decode("utf-8", "replace")


def skip_value(f, vtype):
    if vtype in FIXED_SIZES:
        f.seek(FIXED_SIZES[vtype], 1)
    elif vtype == T_STRING:
        f.seek(u64(f), 1)
    elif vtype == T_ARRAY:
        elem_type = u32(f)
        count = u64(f)
        if elem_type in FIXED_SIZES:
            f.seek(FIXED_SIZES[elem_type] * count, 1)
        else:
            for _ in range(count):
                skip_value(f, elem_type)
    else:
        sys.exit("unknown GGUF value type %d — refusing to guess at the layout" % vtype)


def read_scalar(f, vtype):
    raw = f.read(FIXED_SIZES[vtype])
    value = struct.unpack(SCALAR_FMT[vtype], raw)[0]
    return bool(value) if vtype == T_BOOL else value


def scan(path):
    """{key: (vtype, value_or_None, value_offset)} for the keys of interest."""
    found = {}
    with open(path, "rb") as f:
        if f.read(4) != b"GGUF":
            sys.exit("%s is not a GGUF file (bad magic)" % path)
        version = u32(f)
        if version < 2:
            sys.exit("GGUF v%d uses 32-bit lengths this parser does not speak" % version)
        u64(f)  # tensor count — unused
        kv_count = u64(f)
        for _ in range(kv_count):
            key = gguf_string(f)
            vtype = u32(f)
            offset = f.tell()
            if key in INTEREST and vtype != T_ARRAY:
                if vtype == T_STRING:
                    found[key] = (vtype, gguf_string(f), offset)
                else:
                    found[key] = (vtype, read_scalar(f, vtype), offset)
            else:
                skip_value(f, vtype)
    return found


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("show", "set-true", "set-false"):
        sys.exit(__doc__.strip().split("\n\n")[1])
    command, path = sys.argv[1], sys.argv[2]
    found = scan(path)

    for key in INTEREST:
        if key in found:
            vtype, value, _ = found[key]
            print("%-38s = %r%s" % (key, value, "" if vtype != T_BOOL else "  (bool)"))
    flag = found.get("tokenizer.ggml.add_eos_token")
    if flag is None:
        sys.exit("\ntokenizer.ggml.add_eos_token is ABSENT from this header. An in-place "
                 "flip is impossible (adding a key needs a full rewrite) — report this "
                 "outcome rather than patching by other means.")
    vtype, value, offset = flag
    if vtype != T_BOOL:
        sys.exit("\ntokenizer.ggml.add_eos_token has type %d, not BOOL — refusing." % vtype)

    if command == "show":
        print("\nadd_eos_token is %s. set-true / set-false on a COPY will flip it." % value)
        return

    target = command == "set-true"
    if value == target:
        print("\nalready %s — no write performed." % value)
        return
    with open(path, "r+b") as f:
        f.seek(offset)
        f.write(b"\x01" if target else b"\x00")
    check = scan(path)["tokenizer.ggml.add_eos_token"][1]
    if check is not target:
        sys.exit("post-write verification failed — the flag does not read back %s" % target)
    print("\nFlipped add_eos_token %s -> %s in place and verified by re-read." % (value, target))
    print("Patched file SHA-256 (pin this via MODEL_FILE when harvesting with it):")
    print("  %s" % sha256(path))


if __name__ == "__main__":
    main()
