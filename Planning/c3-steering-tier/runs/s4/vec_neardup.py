from vec import *
import pickle
fam='corrupt OR bribe OR briberi OR kickback OR payoff OR venal OR embezzl OR malfeas OR misappropri OR nepot OR payola'
nex=open("nexus.txt").read().strip()
scope=set((v,d) for v,d in con.execute("SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0",(fam,)))
nxs=set((v,d) for v,d in con.execute("SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0",(nex,)))
allset=scope|nxs
print("scope union size",len(allset),"; in vector index:",sum(1 for k in allset if k in row_of))
print("mean-8sd line %.2f (pairs strictly below it are checked)"%line)
nd=near_duplicates(allset)
print("pairs below line:",len(nd))
pickle.dump(nd,open("work/neardups.pkl","wb"))
for h,a,b in nd: print(h,a,b)
