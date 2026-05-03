#!/usr/bin/env bash
# Runs pub get / analyze / test in the project root and writes everything
# (including exit codes) to check_output.txt so it can be shared back.
set +e
cd "$(dirname "$0")"
OUT=check_output.txt
{
  echo "=== flutter --version ==="
  flutter --version
  echo
  echo "=== flutter pub get ==="
  flutter pub get
  echo "(pub get exit: $?)"
  echo
  echo "=== flutter analyze ==="
  flutter analyze
  echo "(analyze exit: $?)"
  echo
  echo "=== flutter test ==="
  flutter test
  echo "(test exit: $?)"
} > "$OUT" 2>&1
echo "Wrote $OUT"
