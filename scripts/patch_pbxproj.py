p = r"E:\dsh\nacl-ipcc-lite\airbeep.xcodeproj\project.pbxproj"
t = open(p, encoding="utf-8").read()
t = t.replace('INFOPLIST_KEY_CFBundleDisplayName = "氯化钠";', 'INFOPLIST_KEY_CFBundleDisplayName = "NaCl IPCC";')
t = t.replace("MARKETING_VERSION = 0.2.0;", "MARKETING_VERSION = 0.3.0;")
t = t.replace("ASSETCATALOG_COMPILER_APPICON_NAME = Appicon;", "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
lines = [
    l for l in t.splitlines(True)
    if "Appicon.icon in Resources */ = {isa = PBXBuildFile" not in l
    and "D1664C2C303161240037E861 /* Appicon.icon */," not in l
    and "D1664C2D303161240037E861 /* Appicon.icon in Resources */," not in l
]
open(p, "w", encoding="utf-8", newline="").write("".join(lines))
print("patched lux lines:", len(t.splitlines()), "->", len(lines))
