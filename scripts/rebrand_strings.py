#!/usr/bin/env python3
"""按需替换若干本地化/品牌字符串（UTF-8 安全）。"""
import io
import sys
from pathlib import Path

ROOT = Path(r"E:\dsh\nacl-ipcc-lite\airbeep")

EDITS = {
    "AirBeepAirliftSetupView.swift": [
        (
            'Text("Pairing and LocalDevVPN are ready. Return to 氯化钠 to read or change the recording tones.")',
            'Text("Pairing and LocalDevVPN are ready. Return to NaCl IPCC to run the carrier lock.")',
        ),
        (
            '.navigationTitle("Airlift Setup")',
            '.navigationTitle("Airlift Setup")',
        ),
    ],
    "AirliftSetupViews.swift": [
        (
            "Connect this iPhone to a Wi-Fi network to continue. 氯化钠 will continue automatically once Wi-Fi is available.",
            "Connect this iPhone to a Wi-Fi network to continue. NaCl IPCC will continue automatically once Wi-Fi is available.",
        ),
        (
            "Start pairing, then open Settings › Privacy & Security › Developer Mode › Pair with 氯化钠.",
            "Start pairing, then open Settings › Privacy & Security › Developer Mode › Pair with NaCl IPCC.",
        ),
        (
            "Open LocalDevVPN, tap Connect, then return to 氯化钠.",
            "Open LocalDevVPN, tap Connect, then return to NaCl IPCC.",
        ),
    ],
    "Airlift/PairingController.swift": [
        ('private let hostName = "氯化钠"', 'private let hostName = "NaCl IPCC"'),
        (
            "Enable it in Settings › 氯化钠 › Local Network.",
            "Enable it in Settings › NaCl IPCC › Local Network.",
        ),
        (
            "Enter PIN \\(pin) in Settings › Privacy & Security › Developer Mode › Pair with 氯化钠",
            "Enter PIN \\(pin) in Settings › Privacy & Security › Developer Mode › Pair with NaCl IPCC",
        ),
    ],
    "zh-Hans.lproj/Localizable.strings": [
        (
            '"Pairing and LocalDevVPN are ready. Return to 氯化钠 to read or change the recording tones." = "配对和 LocalDevVPN 已就绪，请返回 氯化钠 读取或修改录音提示音。";',
            '"Pairing and LocalDevVPN are ready. Return to NaCl IPCC to run the carrier lock." = "配对记录与 LocalDevVPN 已就绪，返回 NaCl IPCC 执行锁定。";',
        ),
        (
            '"Start pairing, then open Settings › Privacy & Security › Developer Mode › Pair with 氯化钠." = "开始配对后，前往“设置 › 隐私与安全性 › 开发者模式 › 与 氯化钠 配对”。";',
            '"Start pairing, then open Settings › Privacy & Security › Developer Mode › Pair with NaCl IPCC." = "开始配对后，前往“设置 › 隐私与安全性 › 开发者模式 › 与 NaCl IPCC 配对”。";',
        ),
        (
            '"Open LocalDevVPN, tap Connect, then return to 氯化钠." = "打开 LocalDevVPN，点击“连接”，连接成功后返回 氯化钠。";',
            '"Open LocalDevVPN, tap Connect, then return to NaCl IPCC." = "打开 LocalDevVPN，点击“连接”，连接成功后返回 NaCl IPCC。";',
        ),
        (
            '"Connect this iPhone to a Wi-Fi network to continue. 氯化钠 will continue automatically once Wi-Fi is available." = "请将这台 iPhone 连接到 Wi-Fi 后继续。Wi-Fi 可用时 氯化钠 会自动继续。";',
            '"Connect this iPhone to a Wi-Fi network to continue. NaCl IPCC will continue automatically once Wi-Fi is available." = "请将这台 iPhone 连接到 Wi-Fi 后继续。Wi-Fi 可用时 NaCl IPCC 会自动继续。";',
        ),
    ],
    "en.lproj/Localizable.strings": [
        (
            '"Pairing and LocalDevVPN are ready. Return to 氯化钠 to read or change the recording tones." = "Pairing and LocalDevVPN are ready. Return to 氯化钠 to read or change the recording tones.";',
            '"Pairing and LocalDevVPN are ready. Return to NaCl IPCC to run the carrier lock." = "Pairing and LocalDevVPN are ready. Return to NaCl IPCC to run the carrier lock.";',
        ),
        (
            '"Start pairing, then open Settings › Privacy & Security › Developer Mode › Pair with 氯化钠." = "Start pairing, then open Settings › Privacy & Security › Developer Mode › Pair with 氯化钠.";',
            '"Start pairing, then open Settings › Privacy & Security › Developer Mode › Pair with NaCl IPCC." = "Start pairing, then open Settings › Privacy & Security › Developer Mode › Pair with NaCl IPCC.";',
        ),
        (
            '"Open LocalDevVPN, tap Connect, then return to 氯化钠." = "Open LocalDevVPN, tap Connect, then return to 氯化钠.";',
            '"Open LocalDevVPN, tap Connect, then return to NaCl IPCC." = "Open LocalDevVPN, tap Connect, then return to NaCl IPCC.";',
        ),
        (
            '"Connect this iPhone to a Wi-Fi network to continue. 氯化钠 will continue automatically once Wi-Fi is available." = "Connect this iPhone to a Wi-Fi network to continue. 氯化钠 will continue automatically once Wi-Fi is available.";',
            '"Connect this iPhone to a Wi-Fi network to continue. NaCl IPCC will continue automatically once Wi-Fi is available." = "Connect this iPhone to a Wi-Fi network to continue. NaCl IPCC will continue automatically once Wi-Fi is available.";',
        ),
    ],
}

changed = 0
for rel, pairs in EDITS.items():
    path = ROOT / rel
    if not path.exists():
        print(f"MISSING {rel}")
        continue
    text = path.read_text(encoding="utf-8")
    original = text
    for old, new in pairs:
        if old == new:
            continue
        if old not in text:
            print(f"  ! not found in {rel}: {old[:60]!r}")
            continue
        text = text.replace(old, new)
        changed += 1
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"updated {rel}")

print(f"replacements: {changed}")
