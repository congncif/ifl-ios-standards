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

# 3. Codex currently loads plugin skills/MCP metadata, but does not guarantee that a
# plugin's bin/ directory is exported to the user's shell PATH. Publish stable shims
# for the scaffolders into ~/.local/bin, which is already on PATH for most Codex setups.
BIN_DIR="${HOME}/.local/bin"
CACHE_ROOT="${HOME}/.codex/plugins/cache/${MARKETPLACE}/${PLUGIN}"
PLUGIN_DIR=""

if [ -d "$CACHE_ROOT" ]; then
  PLUGIN_DIR="$(find "$CACHE_ROOT" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
fi

if [ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR/bin" ]; then
  mkdir -p "$BIN_DIR"
  for tool in ifl-init ifl-new-module ifl-new-board; do
    src="$PLUGIN_DIR/bin/$tool"
    dst="$BIN_DIR/$tool"
    if [ -x "$src" ]; then
      cat > "$dst" <<EOF
#!/usr/bin/env bash
exec "$src" "\$@"
EOF
      chmod +x "$dst"
    fi
  done
  echo "Installed command shims into $BIN_DIR: ifl-init, ifl-new-module, ifl-new-board"
else
  echo "WARNING: installed plugin, but could not find cached bin/ under $CACHE_ROOT" >&2
  echo "         Re-run this installer after starting a new Codex thread, or call tools via the cache path." >&2
fi

echo
echo "Done. Start a new Codex thread, then describe a Boardy+VIP iOS task"
echo "(e.g. \"add a new Boardy VIP module\") — the router skill fires by context."
