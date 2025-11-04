#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: createProject <swift|dotnet|go|py|ts> <ProjectName>"
  exit 1
fi

LANG="$1"
NAME="$2"
BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-"$HOME/dev-bootstrap"}"

if [[ ! -f "$BOOTSTRAP_HOME/Makefile" ]]; then
  echo "Bootstrap Makefile not found at $BOOTSTRAP_HOME. Set BOOTSTRAP_HOME env var."
  exit 2
fi

make -C "$BOOTSTRAP_HOME" "new:${LANG}" NAME="$NAME"
