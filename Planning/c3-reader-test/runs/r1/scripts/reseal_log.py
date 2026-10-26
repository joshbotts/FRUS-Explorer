# Keep the ELIDED: line last in queries.log: remove it wherever it stands and append it again (the text is kept in work/elided_line.txt).
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
lines = open(RUN + "/queries.log").read().split("\n")
elided = open(RUN + "/work/elided_line.txt").read().strip("\n")
lines = [l for l in lines if not l.startswith("ELIDED:")]
while lines and lines[-1] == "": lines.pop()
lines.append(elided)
open(RUN + "/queries.log", "w").write("\n".join(lines) + "\n")
print("resealed;", len(lines), "lines; last line starts:", lines[-1][:40])
