# stats6.py: variants missed by 'cuba OR cuban': Havana/Habana/Antilles/Isle of Pines documents that never say Cuba/Cuban (FTS), by band
from h import *
c=con()
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
def cnt(q,lo,hi):
    return c.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
     WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN %s AND dd.date_iso>=? AND dd.date_iso<?"""%ED2,(q,lo,hi)).fetchone()[0]
print("band | 'cuba OR cuban' | 'cuba OR cuban OR havana OR habana' | (havana OR habana) NOT cuba/cuban | (antilles OR \"isle of pines\") NOT cuba/cuban")
for name,lo,hi in [("1870-1899","1870","1900"),("1900-1939","1900","1940"),("1940-1957","1940","1958"),("1958-1989","1958","1990")]:
    a=cnt("cuba OR cuban",lo,hi); b=cnt("cuba OR cuban OR havana OR habana",lo,hi)
    x=cnt("(havana OR habana) NOT (cuba OR cuban)",lo,hi); y=cnt("(antilles OR \"isle of pines\") NOT (cuba OR cuban)",lo,hi)
    print("%s | %d | %d | %d of %d | %d"%(name,a,b,x,b,y))
