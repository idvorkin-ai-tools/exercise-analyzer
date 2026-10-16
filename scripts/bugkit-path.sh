#!/usr/bin/env bash
# Prints the BugKit checkout whose scripts this repo's recipes run (bugs-check, symbolicate, the signing guard):
# the SwiftPM checkout a build leaves under Build/ (the pinned revision), else ~/gits/bug-kit; BUG_KIT overrides
# both. A checkout counts only when it has all four scripts (bugs-monitor.sh and symbolicate.sh arrived in
# 94a5ae3, signing-guard.sh in v0.3.3; bugs-monitor.sh is only that version marker now, scripts/bugs-monitor.sh
# tails the listener's inbox), so one left by an older pin is skipped. Exit 2 with a hint when there is none.
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
KIT=${BUG_KIT:-}
for candidate in "$HERE/Build/SourcePackages/checkouts/bug-kit" "$HOME/gits/bug-kit"; do
  [ -n "$KIT" ] && break
  [ -x "$candidate/scripts/pull-reports.sh" ] && [ -x "$candidate/scripts/bugs-monitor.sh" ] \
    && [ -x "$candidate/scripts/symbolicate.sh" ] && [ -x "$candidate/scripts/signing-guard.sh" ] && KIT=$candidate
done
[ -n "$KIT" ] || { echo "no BugKit checkout at the pinned revision or newer (build once, or git -C ~/gits/bug-kit pull; clone https://github.com/idvorkin/bug-kit there if missing)" >&2; exit 2; }
echo "$KIT"
