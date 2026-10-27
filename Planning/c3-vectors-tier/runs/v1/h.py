import sqlite3, re, sys, json
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
def con():
    c=sqlite3.connect(DB,uri=True); return c
