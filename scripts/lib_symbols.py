#!/usr/bin/env python3
"""列出 libairlift_ffi.a 里每个成员定义的 al_* 全局符号（Mach-O 符号表解析）。"""
import struct
import sys
from pathlib import Path

LIB = Path(r"E:\dsh\nacl-ipcc-lite\Vendor\AirCard\AirliftFFI.xcframework\ios-arm64\libairlift_ffi.a")


def iter_ar_members(data: bytes):
    assert data[:8] == b"!<arch>\n", "not an ar archive"
    off = 8
    while off + 60 <= len(data):
        header = data[off:off + 60]
        name = header[0:16].decode("ascii", "replace").strip()
        size_field = header[48:58].decode("ascii", "replace").strip()
        try:
            size = int(size_field)
        except ValueError:
            break
        body_off = off + 60
        body = data[body_off:body_off + size]
        # BSD long names: "#1/<len>" then the name lives inside the body
        if name.startswith("#1/"):
            nlen = int(name[3:])
            real = body[:nlen].rstrip(b"\x00").decode("ascii", "replace")
            body = body[nlen:]
            name = real
        yield name, body
        off = body_off + size + (size % 2)


def macho_symbols(body: bytes):
    if len(body) < 32:
        return []
    magic = struct.unpack_from(">I", body, 0)[0]
    if magic not in (0xFEEDFACF, 0xFEEDFACE, 0xCEFAEDFE, 0xCFFAEDFE):
        return []
    if magic == 0xFEEDFACF:  # 64-bit, big-endian fields
        ncmds = struct.unpack_from(">I", body, 16)[0]
        off = 32
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from(">II", body, off)
            if cmd == 0x2:  # LC_SYMTAB
                symoff, nsyms, stroff, strsize = struct.unpack_from(">IIII", body, off + 8)
                out = []
                for i in range(nsyms):
                    n_strx, n_type, n_sect, n_desc, n_value = struct.unpack_from(
                        ">IBBHQ", body, symoff + i * 16
                    )
                    if n_type & 0x0E != 0x0E:  # skip stab
                        continue
                    end = body.find(b"\x00", stroff + n_strx)
                    s = body[stroff + n_strx:end].decode("ascii", "replace")
                    out.append((s, n_type, n_sect, n_value != 0))
                return out
            off += cmdsize
    return []


data = LIB.read_bytes()
wanted = {}
total_members = 0
for name, body in iter_ar_members(data):
    total_members += 1
    for sym, n_type, n_sect, has_value in macho_symbols(body):
        if sym.startswith("_al_"):
            bare = sym[1:]
            wanted.setdefault(bare, []).append((name, n_sect != 0 or has_value))

print(f"archive members: {total_members}, al_* symbols found: {len(wanted)}")
for sym in sorted(wanted):
    defs = [m for m, defined in wanted[sym] if defined]
    kind = "DEFINED" if defs else "undefined"
    print(f"  {sym:32s} {kind:10s} members={len(wanted[sym])}")
