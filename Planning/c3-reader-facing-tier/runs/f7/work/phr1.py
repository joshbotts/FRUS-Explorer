import sqlite3
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open("work/ea_vols_list.txt")]+['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08']
ph=",".join("?"*len(vols))
phr=["ZZZ_IMPOSSIBLE_ZZZ","department of state","soft power","prestige of the united states","image of the united states","american image","u.s. image","hearts and minds","asian mind","oriental mind","psychology of asians","asian psychology","face saving","loss of face","neutralism","anti-american","united states information service","information agency","voice of america","cultural exchange","educational exchange","leader grant","american cultural center","binational center","book translation","motion pictures","public opinion poll","opinion survey","propaganda","psychological warfare","psychological operations","psychological strategy","effectiveness of our information","effectiveness of the information","racial","colored peoples","anti-white","asians","orientals","free world","peaceful coexistence","nation building","political warfare"]
for p in phr:
    q='"%s"'%p
    sql=f"""SELECT COUNT(*),COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
    WHERE frus_documents MATCH ? AND d.volume_id IN ({ph}) AND d.is_front_matter=0 AND d.is_editorial_note=0"""
    print(p, db.execute(sql,[q]+vols).fetchone(),flush=True)
