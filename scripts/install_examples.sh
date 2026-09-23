#!/bin/bash
# install_examples.sh — build every icon described in examples/*.json.
#
# Each JSON file is a single object:
#   { "name": "Developer", "target": "/Volumes/External/Developer",
#     "suffix": "developer", "symbol": "chevron.left.forwardslash.chevron.right" }
#
# Optional keys: "symbolmode" ("1" native symbol, "0" app icon),
#                "systemIcns" (CoreTypes .icns used when symbolmode is 0).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

shopt -s nullglob
files=("$ROOT"/examples/*.json)
if [ ${#files[@]} -eq 0 ]; then
  echo "no files in examples/" >&2
  exit 1
fi

for f in "${files[@]}"; do
  echo "== $(basename "$f")"
  # One shell-quoted field per line, in a fixed order, so the JSON never has to
  # be parsed by hand inside bash.
  mapfile -t fields < <(python3 - "$f" <<'PY'
import json, shlex, sys
d = json.load(open(sys.argv[1]))
for key in ("name", "target", "suffix", "symbol", "systemIcns"):
    v = d.get(key, "")
    print(shlex.quote(str(v)) if v else "''")
print(shlex.quote(str(d.get("symbolmode", ""))))
PY
)
  eval "NAME=${fields[0]}; TARGET=${fields[1]}; SUFFIX=${fields[2]}; SYMBOL=${fields[3]}; SYSICNS=${fields[4]}; SYMBOLMODE=${fields[5]}"
  TARGET="${TARGET/#\~/$HOME}"
  SYSICNS="${SYSICNS/#\~/$HOME}"
  if [ ! -d "$TARGET" ]; then
    echo "   skipped: $TARGET does not exist on this Mac"
    continue
  fi
  SYMBOLMODE="$SYMBOLMODE" "$HERE/build_icon_app.sh" "$NAME" "$TARGET" "$SUFFIX" "$SYMBOL" "$SYSICNS"
done