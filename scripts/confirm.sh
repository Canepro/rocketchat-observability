#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-This is a destructive action. Type YES to continue.}"
echo "$MSG"
read -r -p "Confirm by typing YES: " ANSWER
if [[ "$ANSWER" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi