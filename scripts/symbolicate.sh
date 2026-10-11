#!/usr/bin/env bash
# Symbolicates a MetricKit crash or hang JSON (Documents/crashes/*.json, pulled by `just pull-logs`) against the
# binaries of the last `just build-device`. Prints each attributed thread's frames as "binary  symbol (file:line)"
# where a binary with the frame's UUID is found here, "+offset (system)" for Apple's, and says so when the app's
# frames come from another build (the UUID does not match: rebuild that commit, `BugKitCommit` on the report).
#
# Two things the first version got wrong (bug-kit PR #10 found the first with a test):
# - `atos -l 0x0 <offset>` prints the address back unresolved when the binary's __TEXT does not start at 0 (an
#   executable's starts at 0x100000000). The offset in the payload counts from __TEXT, so give atos that start as
#   -l and start + offset as the address. The start is read with `otool -l`.
# - A Debug build's code is not in the app's main binary: Xcode links it as ExerciseAnalyzer.debug.dylib inside
#   the .app (the main binary is a stub), and the payload names that dylib. Matching the frame's UUID against the
#   stub's dSYM never found the app's frames. Every Mach-O under the .app (and any dSYM beside it) is a candidate,
#   picked by UUID.
# Usage: scripts/symbolicate.sh ~/tmp/agent/swing-logs/crashes/<stamp>.json
set -euo pipefail
FILE=${1:?usage: symbolicate.sh <crash.json>}
PRODUCTS=${PRODUCTS:-Build/Build/Products/Debug-iphoneos}
APP="$PRODUCTS/ExerciseAnalyzer.app"
[ -d "$APP" ] || { echo "no app under $PRODUCTS: run just build-device" >&2; exit 1; }

# uuid (upper case) → Mach-O path, for every binary of ours in the build: the app's stub, its debug dylib, embedded
# frameworks and extensions, the watch app, and dSYM DWARF files when the build made them (file:line then).
declare -A binaries
while IFS= read -r bin; do
  while IFS= read -r uuid; do binaries[$uuid]=$bin; done < <(dwarfdump --uuid "$bin" 2>/dev/null | awk '{print toupper($2)}')
done < <(find "$APP" "$PRODUCTS" -maxdepth 6 \( -type f -perm -u+x -o -path "*/DWARF/*" \) -print 2>/dev/null |
  while IFS= read -r f; do file -b "$f" | grep -q "Mach-O" && echo "$f"; done)
echo "binaries here: ${#binaries[@]} ($(for u in "${!binaries[@]}"; do basename "${binaries[$u]}"; done | sort -u | tr '\n' ' '))"

text_start() {  # the binary's __TEXT vmaddr: 0x100000000 for an executable, 0 for a dylib
  otool -l "$1" | awk '/segname __TEXT$/ {getline; print $2; exit}'
}

jq -r '
  .crashDiagnostics[]?, .hangDiagnostics[]? |
  "crash: exceptionType \(.diagnosticMetaData.exceptionType // "-") signal \(.diagnosticMetaData.signal // "-") reason \(.diagnosticMetaData.terminationReason // "-" | gsub("\n"; " "))",
  (.callStackTree.callStacks[] | select(.threadAttributed == true) | .. | objects | select(has("address")) |
    "frame \(.binaryName // "?") \(.binaryUUID // "?" | ascii_upcase) \(.offsetIntoBinaryTextSegment // 0)")' "$FILE" |
while IFS= read -r line; do
  case "$line" in
    crash:*) echo "$line" ;;
    frame\ *)
      set -- $line
      name=$2; uuid=$3; off=$4
      bin=${binaries[$uuid]:-}
      if [ -n "$bin" ]; then
        text=$(text_start "$bin")
        addr=$(printf '0x%x' $((text + off)))
        sym=$(atos -o "$bin" -arch arm64 -l "$text" "$addr" 2>/dev/null || true)
        echo "  $name  ${sym:-+$off}"
      elif [[ "$name" == ExerciseAnalyzer* ]]; then
        echo "  $name  +$off (this build's $name has another UUID: the crash is from a different build)"
      else
        echo "  $name  +$off (system)"
      fi
      ;;
  esac
done
