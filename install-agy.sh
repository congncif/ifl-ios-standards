#!/usr/bin/env bash
set -euo pipefail

# install-agy.sh — standalone installer for the ifl-ios-standards Google Antigravity plugin.
#
# Works by copying the source repo contents into the Antigravity plugin directory.
#
# Run it any of these ways:
#   curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/v1.0.0/install-agy.sh | bash -s -- --ref=v1.0.0
#   bash install-agy.sh --ref=v1.0.0
#   bash install-agy.sh --ref=v1.0.0 --scope=project
#
# Flags (all optional):
#   --ref=BRANCH|TAG|SHA   pin an explicitly authorized source (published example: v1.0.0)
#   --scope=global|project default global

REPO="congncif/ifl-ios-standards"
PLUGIN="ifl-ios-standards"
REF=""
SCOPE="global"

for a in "$@"; do
  case "$a" in
    --ref=*)   REF="${a#--ref=}" ;;
    --scope=global|--scope=project) SCOPE="${a#--scope=}" ;;
    -h|--help) sed -n '4,20p' "$0" 2>/dev/null || grep '^#' <<<""; exit 0 ;;
    *) echo "install-agy.sh: unknown arg '$a'" >&2; exit 64 ;;
  esac
done

# Determine the destination path based on scope
if [ "$SCOPE" = "global" ]; then
  DEST_DIR="$HOME/.gemini/config/plugins/$PLUGIN"
else
  # Using the .agents directory for project-local Antigravity plugins
  DEST_DIR="$PWD/.agents/plugins/$PLUGIN"
fi

# Ensure the destination directory exists
mkdir -p "$DEST_DIR"

if [ -d "./$PLUGIN" ] && [ -f "./$PLUGIN/plugin.json" ] && [ -z "$REF" ]; then
  echo "Installing $PLUGIN from local directory (scope: $SCOPE) to $DEST_DIR"
  cp -R "./$PLUGIN/"* "$DEST_DIR/"
  cp -R "./$PLUGIN/".* "$DEST_DIR/" 2>/dev/null || true
else
  echo "Installing $PLUGIN from $REPO${REF:+ @ $REF} (scope: $SCOPE) to $DEST_DIR"
  
  # Create a temporary directory to clone the repository
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  SRC_URL="https://github.com/$REPO.git"

  if [ -n "$REF" ]; then
    echo "Cloning ref $REF..."
    git clone --depth 1 --branch "$REF" "$SRC_URL" "$TMP_DIR/repo" >/dev/null 2>&1
  else
    echo "Cloning latest..."
    git clone --depth 1 "$SRC_URL" "$TMP_DIR/repo" >/dev/null 2>&1
  fi

  # Copy the plugin contents to the destination
  # The Antigravity plugin is located in the ifl-ios-standards subdirectory
  cp -R "$TMP_DIR/repo/$PLUGIN/"* "$DEST_DIR/"
  cp -R "$TMP_DIR/repo/$PLUGIN/".* "$DEST_DIR/" 2>/dev/null || true
fi

echo
echo "Done. The Antigravity plugin has been installed successfully."
echo "You can now use the plugin and its agents in your Antigravity environment!"
