#!/usr/bin/env bash
# Event stream for an agent Monitor: BugKit's bugs-monitor.sh for this app (bug-kit PR #10, from this script's
# first version). It runs `pull-reports.sh --check exercise-analyzer` every minute and prints one line per report
# that is not yet an issue, each once (`new exercise-analyzer <device> <reported_at> <note>`), plus
# `check_failed <reason>` once when the check itself breaks (devicectl, the issue lookup) and `check_ok` when it
# recovers, so a broken check is not silence. Silent otherwise, so the agent is woken only to file.
# Usage: scripts/bugs-monitor.sh [--every seconds]   (default 60)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
KIT=$("$HERE/bugkit-path.sh") || exit 2
exec "$KIT/scripts/bugs-monitor.sh" exercise-analyzer "$@"
