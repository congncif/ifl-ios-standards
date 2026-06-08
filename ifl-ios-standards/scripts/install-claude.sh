#!/usr/bin/env bash
set -euo pipefail

# install-claude.sh — install + auto-enable the ifl-ios-standards Claude Code plugin.
#
# Usage:
#   scripts/install-claude.sh [--scope=user|project|local] [--project=PATH]
#
# Scope (default: user = global, every project sees the plugin):
#   --scope=user     install globally; merge auto-enable into ~/.claude/settings.json
#   --scope=project  install for one repo; merge into PATH/.claude/settings.local.json
#                    (PATH from --project=, else $PWD)
#   --scope=local    install for this checkout only; CLI state only, no settings file written
#
# Steps: validate plugin + marketplace → marketplace add → install → (scope-dependent) settings merge.
# The settings merge uses jq (deep-merge, never clobbers existing keys); if jq is absent it prints
# the exact block + target path for manual paste.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKETPLACE_ROOT="$(cd "$PLUGIN_DIR/.." && pwd)"

MARKETPLACE_NAME="ifl-ios-standards"
PLUGIN_NAME="ifl-ios-standards"
PLUGIN_REF="$PLUGIN_NAME@$MARKETPLACE_NAME"

SCOPE="user"
PROJ="$PWD"

for a in "$@"; do
  case "$a" in
    --scope=user|--scope=project|--scope=local) SCOPE="${a#--scope=}" ;;
    --project=*) PROJ="${a#--project=}" ;;
    -h|--help) sed -n '4,21p' "$0"; exit 0 ;;
    *) echo "install-claude.sh: unknown arg '$a'" >&2; exit 64 ;;
  esac
done

# ── Preflight ────────────────────────────────────────────────────────────────

command -v claude >/dev/null 2>&1 || { echo "ERROR: 'claude' CLI not on PATH" >&2; exit 1; }
[ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]        || { echo "ERROR: plugin manifest missing at $PLUGIN_DIR/.claude-plugin/plugin.json" >&2; exit 1; }
[ -f "$MARKETPLACE_ROOT/.claude-plugin/marketplace.json" ] || { echo "ERROR: marketplace manifest missing at $MARKETPLACE_ROOT/.claude-plugin/marketplace.json" >&2; exit 1; }
[ -f "$PLUGIN_DIR/skills/boardy-vip/SKILL.md" ]        || { echo "ERROR: router skill missing at $PLUGIN_DIR/skills/boardy-vip/SKILL.md" >&2; exit 1; }

echo "ifl-ios-standards install"
echo "  plugin:      $PLUGIN_DIR"
echo "  marketplace: $MARKETPLACE_ROOT"
echo "  scope:       $SCOPE"
[ "$SCOPE" = project ] && echo "  project:     $PROJ"
echo

# ── Validate (offline) ───────────────────────────────────────────────────────

claude plugin validate "$PLUGIN_DIR"
claude plugin validate "$MARKETPLACE_ROOT"

# ── Install ──────────────────────────────────────────────────────────────────

claude plugin marketplace add  --scope "$SCOPE" "$MARKETPLACE_ROOT"
claude plugin install          --scope "$SCOPE" "$PLUGIN_REF"

# ── Auto-enable settings merge (scope-dependent) ─────────────────────────────

merge_block() {
  # $1 = target settings.json path
  local target="$1"
  local dir; dir="$(dirname "$target")"
  mkdir -p "$dir"
  [ -f "$target" ] || echo '{}' > "$target"

  if command -v jq >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp)"
    jq \
      --arg mp "$MARKETPLACE_NAME" \
      --arg path "$MARKETPLACE_ROOT" \
      --arg ref "$PLUGIN_REF" \
      '
      .extraKnownMarketplaces = (.extraKnownMarketplaces // {}) |
      .extraKnownMarketplaces[$mp] = { "source": { "source": "directory", "path": $path } } |
      .enabledPlugins = (.enabledPlugins // {}) |
      .enabledPlugins[$ref] = true
      ' "$target" > "$tmp"
    mv "$tmp" "$target"
    echo "  merged auto-enable into $target"
  else
    cat >&2 <<EOF
  jq not found — add this to $target manually:
  {
    "extraKnownMarketplaces": { "$MARKETPLACE_NAME": { "source": { "source": "directory", "path": "$MARKETPLACE_ROOT" } } },
    "enabledPlugins": { "$PLUGIN_REF": true }
  }
EOF
  fi
}

case "$SCOPE" in
  user)    merge_block "$HOME/.claude/settings.json" ;;
  project) merge_block "$PROJ/.claude/settings.local.json" ;;
  local)   echo "  scope=local — CLI state only, no settings file written" ;;
esac

echo
echo "Done. Restart Claude Code (or run /reload-plugins) if discovery does not refresh."
echo "Then: /ifl-ios-standards:boardy-vip   (router)   or just describe an iOS Boardy task."
