#!/usr/bin/env bash
# Quick check for unfiled bug reports (issue #26), through BugKit's pull-reports.sh --check: every paired iPhone and
# iPad, bugs.jsonl only, one stable line per report that has no issue yet:
#   new exercise-analyzer <device> <reported_at> <note>
# Exit 1 when there are new reports, 0 when clean, 2 when the issue lookup failed (so nothing is called new by
# mistake). An unreachable device is named, not a failure. Config: ~/.config/bug-kit/apps.json (the listener's).
# BugKit is found in the SwiftPM checkout a build leaves under Build/, else in ~/gits/bug-kit (BUG_KIT overrides).
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
KIT=${BUG_KIT:-}
for candidate in "$HERE/Build/SourcePackages/checkouts/bug-kit" "$HOME/gits/bug-kit"; do
  [ -n "$KIT" ] && break
  [ -x "$candidate/scripts/pull-reports.sh" ] && KIT=$candidate
done
[ -n "$KIT" ] || { echo "no BugKit checkout (build once, or clone https://github.com/idvorkin/bug-kit to ~/gits/bug-kit)" >&2; exit 2; }
exec "$KIT/scripts/pull-reports.sh" --check exercise-analyzer
