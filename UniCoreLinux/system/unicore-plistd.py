#!/usr/bin/env python3
import plistlib, json, sys
from pathlib import Path

PREF_DIR = Path('/System/Library/Preferences')
PREF_DIR.mkdir(parents=True, exist_ok=True)

def read(name):
    p = PREF_DIR / f"{name}.plist"
    if not p.exists():
        print('{}')
        return
    with p.open('rb') as f:
        data = plistlib.load(f)
        print(json.dumps(data))

def write(name, data):
    p = PREF_DIR / f"{name}.plist"
    with p.open('wb') as f:
        plistlib.dump(data, f)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("usage: unicore-plistd.py read|write name [jsondata]")
        sys.exit(1)
    cmd = sys.argv[1]
    name = sys.argv[2]
    if cmd == 'read':
        read(name)
    elif cmd == 'write':
        import json
        data = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        write(name, data)
    else:
        print("unknown command")
