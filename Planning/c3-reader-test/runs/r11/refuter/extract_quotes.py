import re,sys
t=open('/Users/jbotts/frus-analysis/c3/runs/r11/overview.md',encoding='utf-8').read()
# straight double quotes only (the overview uses straight quotes for passages; curly ’ appears inside passages)
qs=re.findall(r'"([^"]+)"',t)
print(len(qs),'quote-delimited strings')
for i,q in enumerate(qs,1):
    print(f'[{i}] len={len(q)} :: {q}')
print()
print('block quotes (lines starting with >):', [l for l in t.splitlines() if l.startswith('>')])
print('curly double quotes present:', t.count('“'), t.count('”'))
