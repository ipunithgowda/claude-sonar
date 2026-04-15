#!/usr/bin/env bash
# claude-sonar — one-shot installer.
# Installs the AXE voice hook into ~/.claude/hooks, checks deps, and prints
# next steps. Does NOT touch settings.json — you merge that yourself to avoid
# clobbering existing hooks.
set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"

echo "==> claude-sonar installer"
echo ""

# --- Check deps -------------------------------------------------------------
missing=()
command -v jq >/dev/null 2>&1 || missing+=("jq")
command -v python3 >/dev/null 2>&1 || missing+=("python3")
command -v afplay >/dev/null 2>&1 || missing+=("afplay (macOS only)")
command -v curl >/dev/null 2>&1 || missing+=("curl")

if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing dependencies: ${missing[*]}"
  echo "Install with: brew install jq python3 curl"
  exit 1
fi

if ! python3 -c "import edge_tts" 2>/dev/null; then
  echo "==> Installing edge-tts..."
  python3 -m pip install --user edge-tts
fi

# --- Install hook -----------------------------------------------------------
mkdir -p "$HOOKS_DIR/voice-cache"
cp "$REPO_ROOT/hooks/axe-voice.sh" "$HOOKS_DIR/axe-voice.sh"
chmod +x "$HOOKS_DIR/axe-voice.sh"
echo "==> Installed $HOOKS_DIR/axe-voice.sh"

# --- Address preference -----------------------------------------------------
# Ask how AXE should address the user. Default to "sir" if input isn't a TTY
# (e.g. piped install) or user just hits enter.
echo ""
echo "How should AXE address you?"
echo "  1) Sir      — \"Build successful for Project X, sir.\""
echo "  2) Mam      — \"Build successful for Project X, mam.\" (British short form)"
echo "  3) Neutral  — \"Build successful for Project X.\" (no honorific)"
echo ""
ADDRESS_CHOICE=""
if [ -t 0 ]; then
  read -r -p "Choose [1/2/3, default 1]: " ADDRESS_CHOICE
fi
case "$ADDRESS_CHOICE" in
  2) AXE_ADDRESS="mam" ;;
  3) AXE_ADDRESS="neutral" ;;
  *) AXE_ADDRESS="sir" ;;
esac
echo "==> AXE will address you as: $AXE_ADDRESS"

# --- Install .env if missing ------------------------------------------------
if [ ! -f "$HOOKS_DIR/.env" ]; then
  cp "$REPO_ROOT/hooks/.env.example" "$HOOKS_DIR/.env"
  chmod 600 "$HOOKS_DIR/.env"
  echo "==> Created $HOOKS_DIR/.env — add your GROQ_API_KEY"
else
  echo "==> $HOOKS_DIR/.env already exists — keeping your GROQ_API_KEY"
fi

# Patch AXE_ADDRESS in the env file (replace if present, append if not).
if grep -q '^AXE_ADDRESS=' "$HOOKS_DIR/.env"; then
  # In-place replace, portable across macOS/Linux sed
  tmp="$HOOKS_DIR/.env.tmp"
  awk -v val="AXE_ADDRESS=$AXE_ADDRESS" \
    '/^AXE_ADDRESS=/ {print val; next} {print}' \
    "$HOOKS_DIR/.env" > "$tmp" && mv "$tmp" "$HOOKS_DIR/.env"
else
  printf '\nAXE_ADDRESS=%s\n' "$AXE_ADDRESS" >> "$HOOKS_DIR/.env"
fi
chmod 600 "$HOOKS_DIR/.env"

# --- Next steps -------------------------------------------------------------
cat <<EOF

==> Done. Next steps:

  1. Edit $HOOKS_DIR/.env and paste your Groq key
     (free: https://console.groq.com/keys)

  2. Merge settings.json.example into ~/.claude/settings.json
     (add the Stop hook block, don't replace the whole file)

  3. Open a new Claude Code session — after the first reply
     you should hear a chime + a spoken one-liner.

  Logs: tail -f $HOOKS_DIR/voice.log

EOF
