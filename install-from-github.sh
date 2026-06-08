#!/usr/bin/env bash
set -euo pipefail

# install-from-github.sh — add the ifl-ios-standards marketplace from GitHub and enable the plugin.
#
# For teammates / CI / fresh machines: no drive, no local clone needed — pulls from GitHub.
#
# Usage:
#   install-from-github.sh [--repo=OWNER/NAME] [--ref=BRANCH_OR_TAG] [--scope=user|project|local] [--project=PATH]
#
# Defaults:
#   --repo=congncif/ifl-ios-standards     GitHub repo hosting .claude-plugin/marketplace.json at its root
#   --ref=<none>                          pin a branch/tag/SHA (e.g. --ref=v0.14.0); omit = default branch
#   --scope=user                          global; merge auto-enable into ~/.claude/settings.json
#   --scope=project --project=PATH        repo-local; merge into PATH/.claude/settings.local.json
#   --scope=local                         CLI state only, no settings file written
#
# The marketplace declared name is "ifl-ios-standards-local" (same marketplace, GitHub transport).
# If that name is already registered (e.g. from the local drive), this script removes it first so
# the GitHub source takes over — you run one transport at a time.

REPO="congncif/ifl-ios-standards"
REF=""
SCOPE="user"
PROJ="$PWD"

MARKETPLACE_NAME="ifl-ios-standards-local"
PLUGIN_NAME="ifl-ios-standards"
PLUGIN_REF="$PLUGIN_NAME@$MARKETPLACE_NAME"

for a in "$@"; do
  case "$a" in
    --repo=*)    REPO="${a#--repo=}" ;;
    --ref=*)     REF="${a#--ref=}" ;;
    --scope=user|--scope=project|--scope=local) SCOPE="${a#--scope=}" ;;
    --project=*) PROJ="${a#--project=}" ;;
    -h|--help)   sed -n '4,26p' "$0"; exit 0 ;;
    *) echo "install-from-github.sh: unknown arg '$a'" >&2; exit 64 ;;
  esac
done

command -v claude >/dev/null 2>&1 || { echo "ERROR: 'claude' CLI not on PATH" >&2; exit 1; }

# marketplace add source: github shorthand, optionally pinned to a ref
SRC="$REPO"
[ -n "$REF" ] && SRC="$REPO#$REF"

echo "ifl-ios-standards install (GitHub)"
echo "  repo:   $REPO${REF:+  (ref: $REF)}"
echo "  scope:  $SCOPE"
[ "$SCOPE" = project ] && echo "  project: $PROJ"
echo

# ── Swap transport: drop any existing same-name marketplace, then add GitHub ─

if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE_NAME"; then
  echo "  removing existing '$MARKETPLACE_NAME' marketplace (switching transport)…"
  claude plugin marketplace remove "$MARKETPLACE_NAME" 2>/dev/null || true
fi

claude plugin marketplace add  --scope "$SCOPE" "$SRC"
claude plugin install          --scope "$SCOPE" "$PLUGIN_REF"

# ── Scope-aware auto-enable settings merge (GitHub source shape) ─────────────

merge_block() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  [ -f "$target" ] || echo '{}' > "$target"

  if command -v jq >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp)"
    jq \
      --arg mp "$MARKETPLACE_NAME" \
      --arg repo "$REPO" \
      --arg ref "$REF" \
      --arg pref "$PLUGIN_REF" \
      '
      .extraKnownMarketplaces = (.extraKnownMarketplaces // {}) |
      .extraKnownMarketplaces[$mp] = (
        { "source": { "source": "github", "repo": $repo }, "autoUpdate": true }
        + (if $ref == "" then {} else { "source": { "source": "github", "repo": $repo, "ref": $ref }, "autoUpdate": true } end)
      ) |
      .enabledPlugins = (.enabledPlugins // {}) |
      .enabledPlugins[$pref] = true
      ' "$target" > "$tmp"
    mv "$tmp" "$target"
    echo "  merged auto-enable into $target"
  else
    cat >&2 <<EOF
  jq not found — add this to $target manually:
  {
    "extraKnownMarketplaces": { "$MARKETPLACE_NAME": { "source": { "source": "github", "repo": "$REPO"${REF:+, \"ref\": \"$REF\"} }, "autoUpdate": true } },
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
