#!/usr/bin/env bash
# Syntax-only parse check for every Swift source (no macOS SDK needed).
set -uo pipefail
cd /mnt/e/dsh/nacl-ipcc-lite || exit 1
rc=0
count=0
while IFS= read -r f; do
  count=$((count + 1))
  out=$(swiftc -parse "$f" 2>&1)
  if [[ -n "$out" ]]; then
    echo "=== $f ==="
    echo "$out"
    rc=1
  fi
done < <(find airbeep -name '*.swift' | sort)
if [[ $rc -eq 0 ]]; then
  echo "PARSE_OK $count files"
fi
exit $rc
