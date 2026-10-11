#!/usr/bin/env bash
# Files each shake-to-report bug from a pulled bugs.jsonl as a GitHub issue, once.
# Fallback only (since 2026-10-11): the bug-kit listener files every report itself (docs/DEBUGGING.md); run this next
# to a live listener and the same report is filed twice. Each issue body carries `<!-- bug:<reported_at> -->` and, for BugKit reports, `<!-- bug-id:<id> -->`; a report whose
# marker already exists is skipped. Reads both line formats: BugKit's (id, screen, build, commit, device, context,
# files; https://github.com/idvorkin/bug-kit) and this app's older one (clip, exercise, playhead at the top level).
# The screenshot and the playhead frame are named by their path on the Mac, never uploaded: the repo is public and a
# screenshot can show anything (BugKit principle 13; the gist hosting of #24 is gone).
# Usage: scripts/file-bugs.sh [path/to/bugs.jsonl]   (default: ~/tmp/agent/swing-logs/bugs.jsonl, see `just pull-logs`)
set -euo pipefail
REPO="${REPO:-idvorkin/exercise-analyzer}"
BUGS="${1:-$HOME/tmp/agent/swing-logs/bugs.jsonl}"
[ -f "$BUGS" ] || { echo "no bug file at $BUGS" >&2; exit 1; }
PULLED=$(dirname "$BUGS")

# A failed look at the existing issues must stop the filing, or everything is filed again (CG 6fed157).
existing=$(gh issue list -R "$REPO" --state all --limit 500 --json body --jq '.[].body' | grep -oE 'bug(-id)?:[0-9A-Za-z:.-]*' || true)
[ -n "$existing" ] || { echo "could not read the existing issues' markers; filing nothing" >&2; exit 2; }

while IFS= read -r line; do
  [ -n "$line" ] || continue
  if ! at=$(jq -er '.reported_at' <<<"$line" 2>/dev/null); then echo "skip  (line is not a report: ${line:0:60})"; continue; fi
  id=$(jq -r '.id // empty' <<<"$line")
  if grep -qx "bug:$at" <<<"$existing" || { [ -n "$id" ] && grep -qx "bug-id:$id" <<<"$existing"; }; then
    echo "skip  $at (already filed)"; continue
  fi
  note=$(jq -r '.note' <<<"$line")
  title=$(printf '%s' "$note" | sed -e 's/^[-* ]*//' | grep -m1 . | cut -c1-80)
  body=$(jq -r --arg pulled "$PULLED" '
    def row(name; value): "| " + name + " | " + (value | tostring) + " |\n";
    "**Report from the " + (if (.device // "") | test("iPad") then "iPad" else "phone" end) + "** (shake to report), "
      + .reported_at + "\n\n" +
    "> " + (.note | gsub("\n"; "\n> ")) + "\n\n" +
    "| | |\n|---|---|\n" +
    row("Screen"; .screen // "–") +
    row("Clip"; "`" + (.context.clip // .clip // "–") + "`") +
    row("Exercise"; .context.exercise // .exercise // "–") +
    row("Playhead"; .context.playhead // .playhead // "–") +
    row("Reps"; .context.reps // .reps // "–") +
    row("Build"; (.build // "–") + ", commit " + (.commit // "–") + ", " + (.device // "–")) +
    row("Log"; "`" + (.log // "–") + "` at " + ((.session_t_ms // "–") | tostring) + " ms (pull with `just pull-logs`)") +
    (if .screenshot then row("Screenshot"; "`" + $pulled + "/" + .screenshot + "` (on the Mac, not uploaded)") else "" end) +
    (([(.frame // empty), (.files // [])[] | select(endswith("frame.jpg"))] | first // empty
      | row("Frame at the playhead"; "`" + $pulled + "/" + . + "`")) // "") +
    "\n<!-- bug:" + .reported_at + " -->" +
    (if .id then "\n<!-- bug-id:" + .id + " -->" else "" end)' <<<"$line")
  url=$(gh issue create -R "$REPO" --title "$title" --body "$body" --label bug)
  existing+=$'\n'"bug:$at"
  echo "filed $at → $url"
done <"$BUGS"
