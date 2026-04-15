#!/usr/bin/env bash
# AXE voice hook — contextual JARVIS status line via Groq API (Llama 3.1 8B Instant).
# Reads last assistant turn from Claude Code transcript, summarizes via Groq,
# speaks via edge-tts Ryan Neural, plays with afplay. All work async.
# Falls back to cached MP3 if any step fails.
set +e

# --- Config -----------------------------------------------------------------
PYTHON_BIN="/Library/Frameworks/Python.framework/Versions/3.10/bin/python3"
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

# --- Detect project name ----------------------------------------------------
PROJECT=""

# Method 1: cwd from hook input (most reliable if available)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -n "$CWD" ] && [ "$CWD" != "null" ]; then
  PROJECT=$(basename "$CWD")
fi

# Method 2: extract from file paths in recent tool_use entries
if [ -z "$PROJECT" ] || [ "$PROJECT" = "WORK" ]; then
  TOOL_PATH=$(tail -r "$TRANSCRIPT" | head -20 \
    | jq -r '.message.content[]? | select(.type=="tool_use") | .input.file_path // .input.path // .input.command // empty' 2>/dev/null \
    | grep -m1 '/Users/' \
    | sed -E 's|.*/WORK/([^/]+).*|\1|' 2>/dev/null)
  if [ -n "$TOOL_PATH" ] && [ "$TOOL_PATH" != "WORK" ]; then
    PROJECT="$TOOL_PATH"
  fi
fi

# Method 3: extract from transcript path (encodes working dir with dashes)
if [ -z "$PROJECT" ] || [ "$PROJECT" = "WORK" ]; then
  TPATH=$(dirname "$TRANSCRIPT")
  ENCODED=$(echo "$TPATH" | grep -oE 'projects/[^/]+' | head -1 | sed 's|projects/||')
  if [ -n "$ENCODED" ]; then
    # Transcript path encodes cwd as -Users-punith-Downloads-WORK-projectname
    LAST_SEGMENT=$(echo "$ENCODED" | sed 's/.*-WORK-//' | sed 's/-.*//')
    if [ -n "$LAST_SEGMENT" ] && [ "$LAST_SEGMENT" != "$ENCODED" ]; then
      PROJECT="$LAST_SEGMENT"
    fi
  fi
fi

# Clean up project name: capitalize first letter, strip leading dots/dashes
if [ -n "$PROJECT" ] && [ "$PROJECT" != "WORK" ]; then
  PROJECT=$(echo "$PROJECT" | sed 's/^[._-]*//' | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
else
  PROJECT="workspace"
fi

# --- Extract last assistant content (text OR tool actions) ------------------
TEXT=""
TOOL_SUMMARY=""
FOUND_ASSISTANT=0

while IFS= read -r line; do
  [ -z "$line" ] && continue
  ROLE=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
  if [ "$ROLE" = "assistant" ]; then
    FOUND_ASSISTANT=1
    # Try text content first
    CONTENT=$(printf '%s' "$line" | jq -r '[.message.content[]? | select(.type=="text") | .text] | join(" ")' 2>/dev/null)
    if [ -n "$CONTENT" ] && [ "$CONTENT" != "null" ]; then
      TEXT="$CONTENT"
      break
    fi
    # No text — grab tool_use names as fallback
    if [ -z "$TOOL_SUMMARY" ]; then
      TOOLS=$(printf '%s' "$line" | jq -r '[.message.content[]? | select(.type=="tool_use") | .name] | join(", ")' 2>/dev/null)
      if [ -n "$TOOLS" ] && [ "$TOOLS" != "null" ]; then
        TOOL_SUMMARY="Tools used: $TOOLS"
      fi
    fi
  fi
  # Stop after checking last 20 entries to avoid slow scans
  if [ "$FOUND_ASSISTANT" -eq 1 ] && [ -z "$TEXT" ] && [ -n "$TOOL_SUMMARY" ]; then
    TEXT="$TOOL_SUMMARY"
    break
  fi
done < <(tail -r "$TRANSCRIPT" | head -40)

[ -z "$TEXT" ] && exit 0

# Cap input — enough context, not wasteful
SUMMARY_INPUT=$(printf '%s' "$TEXT" | head -c 1800)

# --- Fork everything async --------------------------------------------------
pkill -x afplay 2>/dev/null

(
  # Address preference: "sir" | "ma'am" | "neutral". Defaults to "sir".
  ADDRESS="${AXE_ADDRESS:-sir}"
  case "$ADDRESS" in
    sir|Sir|SIR)
      ADDRESS_INTRO='a JARVIS-style voice module for an engineer (call him "sir")'
      ADDRESS_RULE='- Always address the user as "sir".'
      EX1='"Build successful for Witness, sir."'
      EX2='"Need your attention on Tripwire, sir. Foreign key conflict."'
      EX3='"All 48 tests passing for Prism, sir."'
      EX4='"Permission required for Meeting Mind deploy, sir."'
      EX5='"Agent returned results for Project X, sir."'
      ;;
    "ma'am"|maam|Maam|MAAM|"Ma'am"|"MA'AM"|mam|Mam|MAM)
      # Spelled "mam" (not "ma'am") because en-GB-RyanNeural swallows the
      # apostrophe form. "mam" TTS-renders as a clear British "mam".
      ADDRESS_INTRO='a JARVIS-style voice module for an engineer (address her as "mam")'
      ADDRESS_RULE='- Always address the user as "mam" (spelled exactly m-a-m, NOT "ma'\''am" or "madam"). The TTS voice pronounces "mam" cleanly.'
      EX1='"Build successful for Witness, mam."'
      EX2='"Need your attention on Tripwire, mam. Foreign key conflict."'
      EX3='"All 48 tests passing for Prism, mam."'
      EX4='"Permission required for Meeting Mind deploy, mam."'
      EX5='"Agent returned results for Project X, mam."'
      ;;
    *)
      # neutral: no honorific at all
      ADDRESS_INTRO='a JARVIS-style voice module for an engineer'
      ADDRESS_RULE='- Do NOT use any honorific ("sir", "ma'\''am", "boss", etc.). Keep lines neutral and professional.'
      EX1='"Build successful for Witness."'
      EX2='"Need your attention on Tripwire. Foreign key conflict."'
      EX3='"All 48 tests passing for Prism."'
      EX4='"Permission required for Meeting Mind deploy."'
      EX5='"Agent returned results for Project X."'
      ;;
  esac

  SYSTEM_PROMPT="You are AXE, $ADDRESS_INTRO. Given an assistant message and a project name, output ONE short spoken status line (8-15 words) in calm British butler tone.

RULES:
- Output ONLY the spoken line. No quotes. No preamble. No markdown. No explanation.
$ADDRESS_RULE
- ALWAYS name the project. Examples:
  $EX1
  $EX2
  $EX3
  $EX4
  $EX5
- Be SPECIFIC to the actual content — never generic like \"task complete\" or \"ready\".
- If the message asks a question, phrase as a clarification request naming the subject and project.
- If the message reports completion, state what specifically completed and for which project.
- If the message reports an error or issue, state the specific issue and the project.
- If the message needs permission, say what action needs approval and for which project.
- 8-15 words. Include the project name. Shorter is better after that.
- Say \"AXE\" as one word (rhymes with \"tax\"), never spell letters."

  # Build JSON payload — inject project context into the user message
  USER_MSG="[Project: $PROJECT] $SUMMARY_INPUT"

  PAYLOAD=$(jq -n \
    --arg sys "$SYSTEM_PROMPT" \
    --arg usr "$USER_MSG" \
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
