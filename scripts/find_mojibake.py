import os, re, io

ROOT = r"E:\dsh\nacl-ipcc-lite\airbeep"
BAD_MARKERS = ["\u59d8", "\u5b72", "\u95fd"]  # 姘 寲 閽

hits = []
files = []
for base, _, names in os.walk(ROOT):
    for n in names:
        if n.endswith((".swift", ".strings")):
            files.append(os.path.join(base, n))

for p in files:
    raw = open(p, "rb").read()
    try:
        text = raw.decode("utf-8")
        enc = "utf-8"
    except UnicodeDecodeError:
        text = raw.decode("utf-16")
        enc = "utf-16"
    for i, line in enumerate(text.splitlines(), 1):
        if any(m in line for m in BAD_MARKERS):
            hits.append((p.replace(ROOT, ""), i, enc, line.strip()[:110]))

print("files:", len(files), "bad lines:", len(hits))
for h in hits[:40]:
    print(" ", h[0], h[1], h[2], "|", h[3])
