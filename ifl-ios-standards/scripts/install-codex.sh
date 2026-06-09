#!/usr/bin/env bash
set -euo pipefail

# install-codex.sh — standalone installer for the ifl-ios-standards Codex plugin.
#
# Self-contained: needs NO clone, NO local repo files. Just the `codex` CLI.
# Works like any Codex plugin — add marketplace by repo name, install, done.
#
# Run it any of these ways:
#   curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/main/ifl-ios-standards/scripts/install-codex.sh | bash
#   bash install-codex.sh
#   bash install-codex.sh --ref=v0.15.0
#
# Flags (all optional):
#   --ref=BRANCH|TAG|SHA   pin a version (e.g. v0.15.0); omit = default branch (main)

REPO="congncif/ifl-ios-standards"
MARKETPLACE="ifl-ios-standards"      # the "name" field inside .codex-plugin/marketplace.json
PLUGIN="ifl-ios-standards"
REF=""

for a in "$@"; do
  case "$a" in
    --ref=*)   REF="${a#--ref=}" ;;
    -h|--help) sed -n '4,16p' "$0" 2>/dev/null; exit 0 ;;
    *) echo "install-codex.sh: unknown arg '$a'" >&2; exit 64 ;;
  esac
done

command -v codex >/dev/null 2>&1 || { echo "ERROR: 'codex' CLI not found on PATH." >&2; exit 1; }

echo "Installing $PLUGIN from $REPO${REF:+ @ $REF} (Codex)"

# 1. add marketplace by repo name (Codex fetches .codex-plugin/marketplace.json from the repo)
if [ -n "$REF" ]; then
  codex plugin marketplace add "$REPO" --ref "$REF"
else
  codex plugin marketplace add "$REPO"
fi

# 2. install the plugin (records into ~/.codex/config.toml)
codex plugin add "$PLUGIN@$MARKETPLACE"

echo
echo "Done. Start a new Codex thread, then describe a Boardy+VIP iOS task"
echo "(e.g. \"add a new Boardy VIP module\") — the router skill fires by context."
