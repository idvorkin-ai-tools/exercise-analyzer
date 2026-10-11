#!/usr/bin/env bash
# Prints the BugKit checkout whose scripts this repo's recipes run (bugs-check, bugs-monitor, symbolicate): the
# SwiftPM checkout a build leaves under Build/ (the pinned revision), else ~/gits/bug-kit; BUG_KIT overrides both.
# Exit 2 with a hint when there is none.
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
KIT=${BUG_KIT:-}
for candidate in "$HERE/Build/SourcePackages/checkouts/bug-kit" "$HOME/gits/bug-kit"; do
  [ -n "$KIT" ] && break
  [ -x "$candidate/scripts/pull-reports.sh" ] && KIT=$candidate
done
[ -n "$KIT" ] || { echo "no BugKit checkout (build once, or clone https://github.com/idvorkin/bug-kit to ~/gits/bug-kit)" >&2; exit 2; }
echo "$KIT"
