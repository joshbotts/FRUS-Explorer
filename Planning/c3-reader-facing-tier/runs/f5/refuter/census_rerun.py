# census_rerun.py: independent re-derivation of the core census (USIA|USIS|VOA) by decade over the 77 volumes,
# using the memo's stated regexes and surface (header+dateline+body_text, whitespace-collapsed, non-apparatus).
import sqlite3, re, collections
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
RUN = "/Users/jbotts/frus-analysis/c3f/runs/f5/"
c = sqlite3.connect(DB, uri=True)
SCOPE = open(RUN + "h.py").read().split('SCOPE = """')[1].split('"""')[0].split()
USIA = re.compile(r"\b(USIA|U\.S\.I\.A\.|United States Information Agency|U\.S\. Information Agency)\b")
USIS = re.compile(r"\b(USIS|United States Information Service|U\.S\. Information Service)\b")
VOA = re.compile(r"\b(Voice of America|VOA)\b")
PD = re.compile(r"\bpublic diplomacy\b", re.I); SP = re.compile(r"\bsoft[- ]power\b", re.I); HM = re.compile(r"\bhearts and minds\b", re.I)
POS = re.compile(r"\bDepartment of State\b")
den = collections.Counter(); num = collections.Counter(); top = collections.defaultdict(collections.Counter)
fam = collections.Counter(); posvol = collections.Counter(); n = 0
for v in SCOPE:
    for h, dl, b, dt in c.execute("SELECT d.header,d.dateline,d.body_text,dd.date_iso FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0", [v]):
        n += 1
        t = re.sub(r'\s+', ' ', (h or '') + ' ' + (dl or '') + ' ' + (b or ''))
        a, s, o = bool(USIA.search(t)), bool(USIS.search(t)), bool(VOA.search(t))
        fam['USIA'] += a; fam['USIS'] += s; fam['VOA'] += o; fam['PD'] += bool(PD.search(t)); fam['SP'] += bool(SP.search(t)); fam['HM'] += bool(HM.search(t))
        if POS.search(t): posvol[v] += 1
        dec = (dt[:3] + '0s') if dt else 'undated'
        den[dec] += 1
        if a or s or o:
            num[dec] += 1; top[dec][v] += 1
print("documents:", n, "(38,059 claimed)")
print("families:", dict(fam), "(claimed USIA 375, USIS 402, VOA 179, public diplomacy 2, soft power 0, hearts and minds 15)")
print("CORE:", sum(num.values()), "(864 claimed)")
print("positive control volumes with >=1 'Department of State' doc:", len(posvol), "of 77; docs:", sum(posvol.values()), "(14,998 claimed)")
for d in sorted(den):
    tv = top[d].most_common(1)[0] if top[d] else None
    rate = f"1 in {den[d]/num[d]:.1f}" if num[d] else "-"
    print(f"  {d}: {num[d]} of {den[d]} = {rate}; top volume {tv}")
print("(claimed: 1940s 196 of 13,688; 1950s 293 of 12,972; 1960s 330 of 7,884; 1970s 45 of 3,370; 1980s 0 of 106)")
