#!/usr/bin/env bash
# Quick check for unfiled bug reports (issue #26), through BugKit's pull-reports.sh --check: every paired iPhone and
# iPad, bugs.jsonl only, one stable line per report that has no issue yet:
#   new exercise-analyzer <device> <reported_at> <note>
# Exit 1 when there are new reports, 0 when clean, 2 when the issue lookup failed (so nothing is called new by
# mistake). An unreachable device is named, not a failure. Config: ~/.config/bug-kit/apps.json (the listener's).
# The BugKit checkout comes from scripts/bugkit-path.sh.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
KIT=$("$HERE/bugkit-path.sh") || exit 2
exec "$KIT/scripts/pull-reports.sh" --check exercise-analyzer
