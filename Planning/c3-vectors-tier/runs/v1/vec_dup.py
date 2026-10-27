from vec import *
S=signs()
pairs=[(("frus1881","d405"),("frus1894app2","d394")),(("frus1961-63v11","d18"),("frus1961-63v11","d21")),(("frus1961-63v06","d74"),("frus1961-63v11","d155"))]
for a,b in pairs:
    print(a,b,"hamming",hamming(S[row_of[a]],S[row_of[b]]))
# any near-duplicate (<=20 bits) of the selected documents anywhere in the corpus
sel=[("frus1874","d552"),("frus1898","d498"),("frus1902","d273"),("frus1941v07","d134"),("frus1948v09","d420"),("frus1950v02","d440"),("frus1958-60v06","d535"),("frus1958-60v06","d532"),("frus1961-63v11","d21"),("frus1969-76ve10","d205"),("frus1977-80v23","d18"),("frus1977-80v01","d129"),("frus1981-88v03","d10")]
for a in sel:
    nb=neighbours(row_of[a],1)[0]
    print(a,"nearest",nb[0],doc_of[nb[1]])
