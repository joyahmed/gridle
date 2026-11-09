#!/bin/sh
# The path the machine-wide pre-push hook looks for. Gridle keeps its real gate in
# scripts/verify.sh (build, tests, lint); this only hands over to it.
exec sh "$(dirname "$0")/../../scripts/verify.sh" "$@"
