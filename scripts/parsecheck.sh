#!/usr/bin/env bash
# Syntax-only parse check for the SwiftUI sources (no macOS SDK needed).
set -uo pipefail
cd /mnt/e/dsh/nacl-ipcc-lite || exit 1
files=(
  airbeep/NaClRootView.swift
  airbeep/NaClAboutView.swift
  airbeep/IPCC/IPCCView.swift
  airbeep/AirliftSetupViews.swift
  airbeep/AirBeepAirliftSetupView.swift
  airbeep/AirBeepAdvancedSettingsView.swift
  airbeep/ContentView.swift
)
rc=0
for f in "${files[@]}"; do
  out=$(swiftc -parse "$f" 2>&1)
  if [[ -n "$out" ]]; then
    echo "=== $f ==="
    echo "$out"
    rc=1
  fi
done
if [[ $rc -eq 0 ]]; then
  echo "PARSE_OK all files"
fi
exit $rc
