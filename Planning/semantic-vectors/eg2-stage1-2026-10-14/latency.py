"""V5-Step4-Spike's latency and memory method, repeated: the 25 owner queries under the query
prompt through llama-embedding; per-query cost = (100-query wall - 1-query wall) / 99, best of
three; cold = process + load + 1 query; peak RSS and footprint from /usr/bin/time -l."""
import json, os, re, subprocess, sys, tempfile, time
binary, gguf, queries_path, label = sys.argv[1:5]
queries = []
for line in open(queries_path, encoding="utf-8"):
    line = line.split("#", 1)[0].strip()
    if line:
        queries.append("task: search result | query: " + line)
assert len(queries) == 25, len(queries)

def run(prompts):
    path = os.path.join(tempfile.gettempdir(), "latency-prompts-%s.txt" % label)
    open(path, "w").write("\n".join(prompts))
    t0 = time.perf_counter()
    p = subprocess.run(["/usr/bin/time", "-l", binary, "-m", gguf, "-ngl", "99", "-f", path,
                        "--embd-normalize", "2", "--embd-output-format", "json", "-c", "2048", "-b", "4096", "-ub", "4096"],
                       capture_output=True, text=True)
    wall = time.perf_counter() - t0
    assert p.returncode == 0, p.stderr[-2000:]
    n = len(json.loads(p.stdout)["data"])
    assert n == len(prompts), (n, len(prompts))
    rss = int(re.search(r"(\d+)\s+maximum resident set size", p.stderr).group(1))
    foot = int(re.search(r"(\d+)\s+peak memory footprint", p.stderr).group(1))
    return wall, rss, foot

run(queries[:1])  # first process after a build pays the shader cache once
ones = [run(queries[:1]) for _ in range(3)]
hundreds = [run(queries * 4) for _ in range(3)]
best1 = min(w for w, _, _ in ones)
best100 = min(w for w, _, _ in hundreds)
print(json.dumps({"model": label, "cold_ms_best_of_3": round(best1 * 1000), "per_query_ms": round((best100 - best1) / 99 * 1000, 2),
                  "peak_rss_mb": round(max(r for _, r, _ in ones + hundreds) / 1e6), "peak_footprint_mb": round(max(f for _, _, f in ones + hundreds) / 1e6),
                  "walls_1q_s": [round(w, 3) for w, _, _ in ones], "walls_100q_s": [round(w, 3) for w, _, _ in hundreds]}))
