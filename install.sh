#!/usr/bin/env bash
set -euo pipefail

# install.sh — standalone installer for the ifl-ios-standards Claude Code plugin.
#
# Self-contained: needs NO clone, NO local repo files, NO jq. Just the `claude` CLI.
# Works like any public plugin — add marketplace by repo name, install, done.
#
# Run it any of these ways:
#   curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/main/install.sh | bash
#   bash install.sh
#   bash install.sh --ref=v0.15.0 --scope=project
#
# Flags (all optional):
#   --ref=BRANCH|TAG|SHA   pin a version (e.g. v0.15.0); omit = default branch
#   --scope=user|project|local   default user (global, all projects)

REPO="congncif/ifl-ios-standards"
MARKETPLACE="ifl-ios-standards"      # the "name" field inside marketplace.json
PLUGIN="ifl-ios-standards"
REF=""
SCOPE="user"

for a in "$@"; do
  case "$a" in
    --ref=*)   REF="${a#--ref=}" ;;
    --scope=user|--scope=project|--scope=local) SCOPE="${a#--scope=}" ;;
    -h|--help) sed -n '4,20p' "$0" 2>/dev/null || grep '^#' <<<""; exit 0 ;;
    *) echo "install.sh: unknown arg '$a'" >&2; exit 64 ;;
  esac
done

command -v claude >/dev/null 2>&1 || { echo "ERROR: 'claude' CLI not found on PATH." >&2; exit 1; }

SRC="$REPO"
[ -n "$REF" ] && SRC="$REPO#$REF"

echo "Installing $PLUGIN from $REPO${REF:+ @ $REF}  (scope: $SCOPE)"

# 1. add marketplace by repo name (CLI fetches .claude-plugin/marketplace.json from the repo)
claude plugin marketplace add --scope "$SCOPE" "$SRC"

# 2. install the plugin (install implies enable)
claude plugin install --scope "$SCOPE" "$PLUGIN@$MARKETPLACE"

echo
echo "Done. Run /reload-plugins (or restart Claude Code), then: /ifl-ios-standards:boardy-vip"
