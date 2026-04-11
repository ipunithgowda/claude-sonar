#!/usr/bin/env bash
# AXE voice hook — contextual JARVIS status line via Groq API (Llama 3.1 8B Instant).
# Reads last assistant turn from Claude Code transcript, summarizes via Groq,
# speaks via edge-tts Ryan Neural, plays with afplay. All work async.
# Falls back to cached MP3 if any step fails.
set +e

# --- Config -----------------------------------------------------------------
PYTHON_BIN="$(command -v python3)"
EDGE_VOICE="en-GB-RyanNeural"
GROQ_MODEL="llama-3.1-8b-instant"
GROQ_URL="https://api.groq.com/openai/v1/chat/completions"
OUT_FILE="/tmp/axe-voice.mp3"
CACHE_DIR="$HOME/.claude/hooks/voice-cache"
LOG_FILE="$HOME/.claude/hooks/voice.log"
ENV_FILE="$HOME/.claude/hooks/.env"
FALLBACK_MP3="$CACHE_DIR/ready.mp3"

# --- Load secrets -----------------------------------------------------------
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
if [ -z "$GROQ_API_KEY" ]; then
  # No key — silently exit. Voice simply won't speak until key is provided.
  exit 0
fi

# --- Read hook input --------------------------------------------------------
INPUT=$(cat)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# --- Extract last assistant text content ------------------------------------
TEXT=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  ROLE=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
  if [ "$ROLE" = "assistant" ]; then
    CONTENT=$(printf '%s' "$line" | jq -r '[.message.content[]? | select(.type=="text") | .text] | join(" ")' 2>/dev/null)
    if [ -n "$CONTENT" ] && [ "$CONTENT" != "null" ]; then
      TEXT="$CONTENT"
      break
    fi
  fi
done < <(tail -r "$TRANSCRIPT")

[ -z "$TEXT" ] && exit 0

# Cap input — enough context, not wasteful
SUMMARY_INPUT=$(printf '%s' "$TEXT" | head -c 1800)

# --- Fork everything async --------------------------------------------------
pkill -x afplay 2>/dev/null

(
  SYSTEM_PROMPT='You are AXE, a JARVIS-style voice module for an engineer (call him "sir"). Given an assistant message, output ONE short spoken status line (5-12 words) in calm British butler tone.

RULES:
- Output ONLY the spoken line. No quotes. No preamble. No markdown. No explanation.
- Always address the user as "sir".
- Be SPECIFIC to the actual content — never generic like "task complete" or "ready".
- If the message asks a question, phrase as a clarification request naming the subject.
- If the message reports completion, state what specifically completed.
- If the message reports an issue, state the specific issue.
- Under 12 words. Shorter is better.
- Say "AXE" as one word (rhymes with "tax"), never spell letters.'

  # Build JSON payload with jq (safely handles special chars)
  PAYLOAD=$(jq -n \
    --arg sys "$SYSTEM_PROMPT" \
    --arg usr "$SUMMARY_INPUT" \
    --arg model "$GROQ_MODEL" \
    '{
      model: $model,
      messages: [
        {role: "system", content: $sys},
        {role: "user", content: $usr}
      ],
      max_tokens: 40,
      temperature: 0.7
    }')

  # Call Groq with 5-sec timeout
  RESPONSE=$(curl -s -m 5 "$GROQ_URL" \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>>"$LOG_FILE")

  LINE=$(printf '%s' "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)

  # Normalize: strip quotes, collapse whitespace, AXE-safe
  LINE=$(printf '%s' "$LINE" \
    | tr '\n' ' ' \
    | sed -E 's/^[[:space:]]*["'"'"'`]+//' \
    | sed -E 's/["'"'"'`]+[[:space:]]*$//' \
    | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | sed -E 's/AXE/Axe/g')

  echo "[$(date '+%H:%M:%S')] $LINE" >> "$LOG_FILE"

  # Fallback if empty
  if [ -z "$LINE" ]; then
    [ -f "$FALLBACK_MP3" ] && afplay "$FALLBACK_MP3" >/dev/null 2>&1
    exit 0
  fi

  # Synthesize and play
  "$PYTHON_BIN" -m edge_tts --voice "$EDGE_VOICE" --text "$LINE" --write-media "$OUT_FILE" >/dev/null 2>&1
  if [ -f "$OUT_FILE" ]; then
    afplay "$OUT_FILE" >/dev/null 2>&1
  else
    [ -f "$FALLBACK_MP3" ] && afplay "$FALLBACK_MP3" >/dev/null 2>&1
  fi
) >/dev/null 2>&1 &
disown

exit 0
