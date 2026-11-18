#!/usr/bin/env python3
"""用 Python 复现 App 里 stage() 的每一步，检查最终要写入设备的 bundle 是否正确。"""
import plistlib
import shutil
import zipfile
from pathlib import Path

SRC = Path(r"E:\dsh\nacl-ipcc-lite\airbeep\IPCCData")
OUT = Path(r"E:\dsh\nacl-ipcc\dist\stage-check")
TEMPLATE = SRC / "O2_Germany.ipcc"

CARRIERS = {
    "46000": ("CMCC_cn.bundle", "com.apple.Carrier_CMCC_cn", "CMCC_cn"),
    "46001": ("Unicom_cn.bundle", "com.apple.Carrier_Unicom_cn", "Unicom_cn"),
    "46011": ("Telecom_cn.bundle", "com.apple.Carrier_Telecom_cn", "Telecom_cn"),
}

if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir(parents=True)

# 1. 解包模板
with zipfile.ZipFile(TEMPLATE) as z:
    names = z.namelist()
    print("模板内条目：")
    for n in names:
        print("   ", n)
    z.extractall(OUT)

payload = OUT / "Payload"
template_dirs = [p for p in payload.iterdir() if p.is_dir()]
print("\n模板 bundle 目录:", [p.name for p in template_dirs])
bundle = template_dirs[0]

# 2. 整份替换 carrier.plist
plist_src = SRC / "46000.plist"
shutil.copyfile(plist_src, bundle / "carrier.plist")

# 3. 改写身份
info_path = bundle / "Info.plist"
info = plistlib.loads(info_path.read_bytes())
bundle_name, bundle_id, short = CARRIERS["46000"]
info["CFBundleIdentifier"] = bundle_id
info["CFBundleName"] = short
info["CFBundleExecutable"] = short
info["CFBundleVersion"] = "9999"
info["CFBundleShortVersionString"] = "9999.0"
info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))

version_path = bundle / "version.plist"
if version_path.exists():
    ver = plistlib.loads(version_path.read_bytes())
    ver["CFBundleVersion"] = "9999"
    ver["CFBundleShortVersionString"] = "9999.0"
    ver["BuildVersion"] = "9999"
    version_path.write_bytes(plistlib.dumps(ver, fmt=plistlib.FMT_BINARY))

# 4. 重命名成目标 bundle
staged = OUT / bundle_name
bundle.rename(staged)

print(f"\n=== 最终要写入 /var/mobile/Library/Carrier Bundles/iPhone/{staged.name} ===")
for p in sorted(staged.rglob("*")):
    rel = p.relative_to(staged)
    kind = "DIR " if p.is_dir() else "FILE"
    size = "" if p.is_dir() else f"{p.stat().st_size:>8d} B"
    print(f"  {kind} {str(rel):48s} {size}")

print("\n=== Info.plist ===")
info2 = plistlib.loads((staged / "Info.plist").read_bytes())
for k in ["CFBundleIdentifier", "CFBundleName", "CFBundleExecutable",
          "CFBundleVersion", "CFBundleShortVersionString"]:
    print(f"  {k} = {info2.get(k)}")

print("\n=== version.plist ===")
if (staged / "version.plist").exists():
    ver2 = plistlib.loads((staged / "version.plist").read_bytes())
    for k in ["CFBundleVersion", "CFBundleShortVersionString", "BuildVersion"]:
        print(f"  {k} = {ver2.get(k)}")

print("\n=== carrier.plist（替换进来的 46000）===")
cp = plistlib.loads((staged / "carrier.plist").read_bytes())
print("  keys:", ", ".join(sorted(cp.keys())[:12]), "...")
for k in ["SupportedSIMs", "SupportedSIMsByFirmware", "CarrierName"]:
    if k in cp:
        v = cp[k]
        if isinstance(v, list) and len(v) > 8:
            v = v[:8] + ["..."]
        if isinstance(v, dict):
            v = list(v)[:6]
        print(f"  {k} = {v}")

print("\n=== 签名相关文件（必须原样保留）===")
sig = sorted((staged / "signatures").rglob("*")) if (staged / "signatures").exists() else []
print("  signatures/ 条目:", [str(p.relative_to(staged / 'signatures')) for p in sig])
print("  *.der.pri:", [p.name for p in staged.glob("*.der.pri")])
