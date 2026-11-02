#!/bin/sh
# One command that says whether Panes is healthy: build, tests, lint.
# Exit 0 = all green. Any failure exits 1 and names the step.
set -u
cd "$(dirname "$0")/.." || exit 1

fail=0
step() {
  name=$1; shift
  printf '== %s\n' "$name"
  if "$@"; then printf '   ok\n'; else printf '   FAILED: %s\n' "$name"; fail=1; fi
}

step build swift build
step tests swift test
step lint  swift format lint --strict -r Sources Tests

if [ "$fail" = 0 ]; then echo "GREEN - build, tests and lint passed."; exit 0; fi
echo "RED - fix the failed step above before committing."; exit 1
