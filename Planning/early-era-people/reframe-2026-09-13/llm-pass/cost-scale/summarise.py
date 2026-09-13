#!/usr/bin/env python3
"""Compact tables from costs.json + the INFERRED side arithmetic (electricity, subagent route)."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
C = json.load(open(os.path.join(HERE, "costs.json")))
def get(m, sh, eff, b, c):
    return [x for x in C["rows"] if x["model"] == m and x["shape"] == sh and x["effort"] == eff and x["batch"] == b and x["cached"] == c][0]
f = lambda d: " / ".join("{:,}".format(v) for v in d)
out = []
for sh in ("A", "B", "C_marked_all", "C_union_all", "C_marked_live", "C_union_live"):
    out.append("\n### %s  ($ low / central / high)\n| model | std, no cache, low eff | std, no cache, high eff | batch, no cache, low | batch, cached, low | batch, cached, high | tokens central: in / out / think(low) / think(high) MTok |\n|---|---|---|---|---|---|---|" % sh)
    for m in ("haiku-4.5", "sonnet-5", "opus-5"):
        a = get(m, sh, "low", False, False); b = get(m, sh, "high", False, False); c = get(m, sh, "low", True, False)
        d = get(m, sh, "low", True, True); e = get(m, sh, "high", True, True)
        out.append("| %s | %s | %s | %s | %s%s | %s%s | %s / %s / %s / %s |" % (m, f(a["dollars"]), f(b["dollars"]), f(c["dollars"]), f(d["dollars"]),
                   "" if all(d["cache_eligible"]) else " (cache only at high prefix)", f(e["dollars"]), "" if all(e["cache_eligible"]) else " (")[:0] if False else
                   "| %s | %s | %s | %s | %s | %s | %s / %s / %s / %s |" % (m, f(a["dollars"]), f(b["dollars"]), f(c["dollars"]), f(d["dollars"]), f(e["dollars"]),
                   a["input_tok_M"][1], a["output_tok_M"][1], a["thinking_tok_M"][1], b["thinking_tok_M"][1]))
    out.append("batches needed (low/central/high scenario, by 100k-request and 256 MB caps): " + ", ".join("%s %s" % (m, [v["batches"] for v in C["volumes"][m][sh]]) for m in C["volumes"]))
    out.append("requests: " + str([v["requests"] for v in C["volumes"]["sonnet-5"][sh]]) + " ; body MB (sonnet-5): " + str([v["body_MB"] for v in C["volumes"]["sonnet-5"][sh]]))
side = {}
hrs = 997807.6 / 3600
side["sweep_hours"] = round(hrs, 1)
side["sweep_kWh_range_at_90_120W"] = [round(hrs * 0.09, 1), round(hrs * 0.12, 1)]
side["sweep_electricity_usd_at_0.15_0.25"] = [round(hrs * 0.09 * 0.15, 2), round(hrs * 0.12 * 0.25, 2)]
side["nltagger_electricity_usd_upper"] = round(475.8 / 3600 * 0.12 * 0.25, 4)
# subagent route (INFERRED): per-agent seat = CLAUDE.md 140,378 + MEMORY.md 20,588 chars (MEASURED) at 3.18-4.64 chars/token + 15k tool/system (INFERRED)
seat = [round((140378 + 20588) / 4.644 + 10000), round((140378 + 20588) / 3.181 + 20000)]
side["subagent_seat_tokens_range"] = seat
docs_per_agent = 197534 / 1000; text_tok_per_agent = [679401514 / 1000 / 4.644, 679401514 / 1000 / 2.849]
side["subagent_docs_per_agent_at_1000"] = round(docs_per_agent); side["subagent_text_tokens_per_agent"] = [round(x) for x in text_tok_per_agent]
# a Read-tool loop of ~6k-token reads with context accumulating: turns = text/6k; billed input per agent = sum over turns of (seat + accumulated)
def agent_input(seat_t, text_t, read=6000):
    turns = int(text_t // read) + 1; tot = 0
    for k in range(turns): tot += seat_t + k * read
    return turns, tot
lo = agent_input(seat[0], text_tok_per_agent[0]); hi = agent_input(seat[1], text_tok_per_agent[1])
side["subagent_turns_per_agent"] = [lo[0], hi[0]]; side["subagent_billed_input_tokens_all_agents_B"] = [round(lo[1] * 1000 / 1e9, 1), round(hi[1] * 1000 / 1e9, 1)]
# with 90% of that as cache reads at 0.1x: effective full-price tokens
eff = [lo[1] * 1000 * (0.1 * 0.9 + 0.1), hi[1] * 1000 * (0.1 * 0.9 + 0.1)]
side["subagent_sonnet5_standard_input_usd_if_90pct_cache_read"] = [round(e / 1e6 * 2) for e in eff]
side["subagent_opus5_standard_input_usd_if_90pct_cache_read"] = [round(e / 1e6 * 5) for e in eff]
json.dump(side, open(os.path.join(HERE, "side.json"), "w"), indent=1)
open(os.path.join(HERE, "summary.md"), "w").write("\n".join(out))
print("\n".join(out)); print(json.dumps(side, indent=1))
