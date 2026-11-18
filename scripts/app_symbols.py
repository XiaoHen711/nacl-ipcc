#!/usr/bin/env python3
"""List defined vs undefined `al_*` / `nacl_*` symbols in the built app binary."""
import struct
import sys
import zipfile

IPA = sys.argv[1] if len(sys.argv) > 1 else r"E:\dsh\nacl-ipcc\dist\NaCl-IPCC-0.4.1-unsigned.ipa"
PREFIXES = ("_al_", "_nacl_")

data = zipfile.ZipFile(IPA).read("Payload/airbeep.app/airbeep")
magic = struct.unpack_from("<I", data, 0)[0]
assert magic == 0xFEEDFACF, hex(magic)
ncmds = struct.unpack_from("<I", data, 16)[0]
off = 32
syms = []
for _ in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", data, off)
    if cmd == 0x2:  # LC_SYMTAB
        symoff, nsyms, stroff, strsize = struct.unpack_from("<IIII", data, off + 8)
        for i in range(nsyms):
            n_strx, n_type, n_sect, n_desc, n_value = struct.unpack_from("<IBBHQ", data, symoff + i * 16)
            end = data.find(b"\x00", stroff + n_strx)
            name = data[stroff + n_strx:end].decode("ascii", "replace")
            syms.append((name, n_type, n_sect, n_desc, n_value))
    off += cmdsize

print(f"total symbols: {len(syms)}")
def show(pred_label, filt):
    rows = [s for s in syms if filt(s[0])]
    print(f"--- {pred_label} ({len(rows)}) ---")
    for name, n_type, n_sect, n_desc, n_value in rows:
        ntype = n_type & 0x0E
        kind = {0x0: "UNDF", 0xE: "SECT"}.get(ntype, hex(ntype))
        weak = " (weak_def)" if n_desc & 0x80 else (" (weak_ref)" if n_desc & 0x40 else "")
        print(f"  {name:34s} {kind:5s} sect={n_sect:3d} value=0x{n_value:x}{weak}")

show("al_/nacl_ symbols", lambda n: n.startswith(PREFIXES))
