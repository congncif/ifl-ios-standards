#!/usr/bin/env bash
set -euo pipefail

# install-codex.sh — standalone installer for the ifl-ios-standards Codex plugin.
#
# Self-contained: needs NO clone, NO local repo files. Just the `codex` CLI.
# Works like any Codex plugin — add marketplace by repo name, install, done.
#
# Run it any of these ways:
#   curl -fsSL https://raw.githubusercontent.com/congncif/ifl-ios-standards/v1.0.0/ifl-ios-standards/scripts/install-codex.sh | bash -s -- --ref=v1.0.0
#   bash install-codex.sh --ref=v1.0.0
#   bash install-codex.sh --ref=v1.0.0
#
# Flags (all optional):
#   --ref=BRANCH|TAG|SHA   pin an explicitly authorized source (published example: v1.0.0)

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
# plugin's bin/ directory is exported to the user's shell PATH. Create shims that resolve
# the most recently installed available cache entry each time they are invoked.
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$BIN_DIR"
for tool in ifl-init ifl-new-module ifl-new-board; do
  dst="$BIN_DIR/$tool"
  cat > "$dst" <<EOF
#!/usr/bin/env bash
set -euo pipefail

CACHE_ROOT="\${HOME}/.codex/plugins/cache/${MARKETPLACE}/${PLUGIN}"
TOOL="$tool"
SOURCE=""

while IFS= read -r candidate; do
  executable="\$candidate/bin/\$TOOL"
  [ -x "\$executable" ] || continue
  if [ -z "\$SOURCE" ] || [ "\$executable" -nt "\$SOURCE" ]; then
    SOURCE="\$executable"
  fi
done < <(find "\$CACHE_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

if [ -z "\$SOURCE" ]; then
  echo "\$TOOL: no executable cache entry found under \$CACHE_ROOT; reinstall the plugin" >&2
  exit 1
fi

exec "\$SOURCE" "\$@"
EOF
  chmod +x "$dst"
done
echo "Installed dynamic command shims into $BIN_DIR: ifl-init, ifl-new-module, ifl-new-board"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "NOTE: add $BIN_DIR to shell PATH before invoking the scaffolders by name." ;;
esac

echo
echo "Done. In the consuming repo, run: ifl-init --root=."
echo "Then start a new Codex thread so plugin skills are loaded."
echo "Brain Flow uses provider-native generic subagents; no project agent-profile install is required."
