import sqlite3, re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def text(v,d):
    r=db.execute("SELECT header, COALESCE(dateline,''), COALESCE(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    return " ".join(" ".join(r).split())
checks=[
 ("frus1964-68v32","d8",[r'Bonilla',r'Mann',r'Reid',r'aid program|assistance program|AID program']),
 ("frus1947v07","d553",[r'Wedemeyer',r'State Council',r'supervision']),
 ("frus1948v07","d440",[r'propaganda',r'legislat|Legislative Yuan']),
 ("frus1950v03","d728",[r'Marshall',r'personal',r'Chiang|Generalissimo']),
 ("frus1958-60v01","d135",[r'Thuan',r'desk']),
 ("frus1958-60v01","d156",[r'proud']),
 ("frus1958-60v01","d160",[r'Can Lao',r'stop corruption|stamp out|combat corruption|fight corruption']),
 ("frus1961-63v01","d298",[r'Ellender']),
 ("frus1961-63v22","d252",[r'Harriman',r'purge|questionable']),
 ("frus1950v05","d289",[r'Reuter']),
 ("frus1977-80v03","d248",[r'President Carter|to the President|Mr\. President']),
 ("frus1949v08","d576",[r'\bLi\b|Li Tsung|Acting President',r'\bPai\b']),
 ("frus1922v01","d842",[r'remedy|beyond']),
 ("frus1950v06","d802",[r'Quirino',r'graft']),
 ("frus1893","d628",[r'Mosul',r'Amadia']),
 ("frus1964-68v05","d301",[r'self-respect|self respect',r'leverage']),
 ("frus1969-76v08","d191",[r'Sullivan',r'Senate Foreign Relations|SFRC|Moose|Lowenstein']),
 ("frus1961-63v20","d422",[r'Rusk|The Secretary',r'Spaak']),
 ("frus1981-88v01","d247",[r'Secretary|Shultz',r'Policy Planning']),
 ("frus1977-80v03","d35",[r'London',r'May 8|May 7']),
 ("frus1977-80v24","d337",[r'Venezuela|Perez|Pérez']),
 ("frus1969-76ve09p2","d155",[r'Kissinger|The Secretary',r'Northrop|Lockheed']),
 ("frus1944v06","d269",[r'Gauss']),
 ("frus1947v05","d23",[r'Acheson',r'experts']),
 ("frus1912","d1502",[r'Senate',r'Nicaragua']),
 ("frus1921v01","d275",[r'extraterritorial']),
]
for v,d,pats in checks:
    t=text(v,d); print(f"\n== {v}/{d} ==")
    for p in pats:
        ms=list(re.finditer(p,t))
        if not ms: print(f"  [{p}] NOT FOUND"); continue
        m=ms[0]; print(f"  [{p}] x{len(ms)} ... {t[max(0,m.start()-110):m.end()+110]} ...")
