# claude-sonar

### [Solved] The observability gap in parallel AI agent workflows — hear what every Claude Code session just did, without looking.

I run 12+ projects and 4 Claude Code terminals at the same time. My AI assistant **AXE — Automated X-platform Engine** — speaks a contextual status line after every turn, so I know which workflow just finished without alt-tabbing.

![VSCode with 4 Claude terminals](./screenshots/vscode-multi-terminal.svg)

---

## Why this exists

Visual attention is single-threaded. You can't watch four terminals at once. But sound is omnidirectional — you hear it while your eyes are on something else. That's the gap.

`claude-sonar` wires a Stop hook into Claude Code. After every turn:

1. Grabs the last assistant message from the transcript
2. Sends it to Groq `llama-3.1-8b-instant` (~300ms, free tier)
3. AXE summarizes it into a 10-word spoken line with a JARVIS-style system prompt
4. `edge-tts` speaks it via `en-GB-RyanNeural` (British butler voice)
5. Hook returns in <10ms — Claude never blocks

![Voice log](./screenshots/voice-log.svg)

Every line above is real, pulled straight from `voice.log`. None are scripted — each is generated fresh from what Claude actually just said.

---

## Key features

- 🎯 **Context-aware voice** — every line is LLM-generated from the actual assistant message. No "task complete" noise.
- ⚡ **Sub-10ms hook** — fully async. Claude never waits on voice.
- 🧠 **Groq `llama-3.1-8b-instant`** — ~300ms round-trip, free tier (30 req/min).
- 🇬🇧 **British butler voice** — `en-GB-RyanNeural`, A/B tested against 4 alternatives.
- 🛟 **Graceful degradation** — cached MP3 fallbacks if the LLM call fails.
- 💸 **Free to run** — no paid APIs, no local models, no build step.
- 🔧 **Swap anything** — voice, model, callsign, persona — all one-line edits.

## Requirements

- macOS (uses `afplay`)
- Python 3.10+
- `jq`, `curl` → `brew install jq curl`
- Free Groq API key → [console.groq.com/keys](https://console.groq.com/keys)

## Install

```bash
git clone https://github.com/filmy-munky/claude-sonar.git
cd claude-sonar
./install.sh
```

Then:

1. Paste your Groq key into `~/.claude/hooks/.env`
2. Merge the `Stop` hook block from `settings.json.example` into `~/.claude/settings.json`
3. Open a new Claude Code session — first reply will chime and speak

**Setup time: under 3 minutes.**

## Configure

Edit `~/.claude/hooks/axe-voice.sh`:

| Variable | Default | Swap to |
|----------|---------|---------|
| `EDGE_VOICE` | `en-GB-RyanNeural` | `python3 -m edge_tts --list-voices` for options |
| `GROQ_MODEL` | `llama-3.1-8b-instant` | `llama-3.3-70b-versatile` for smarter (slower) lines |

Drop `CLAUDE.md.example` into `~/.claude/CLAUDE.md` to make the written tone match the voice.

## Files

| Path | Purpose |
|------|---------|
| `hooks/axe-voice.sh` | The Stop hook — tails transcript, calls Groq, speaks via edge-tts |
| `hooks/.env.example` | Template for `GROQ_API_KEY` |
| `hooks/voice-cache/` | Fallback MP3s if the LLM call fails |
| `settings.json.example` | Stop hook wiring for `~/.claude/settings.json` |
| `CLAUDE.md.example` | AXE persona prompt for the text layer |
| `install.sh` | One-shot installer |
| `assets/ad.html` | Apple-ad animation (22s loop, screen-record ready) |
| `screenshots/` | Visual assets for this README |

## Troubleshooting

Tail `~/.claude/hooks/voice.log` — every invocation logs there.

- **Silent** → missing `GROQ_API_KEY`, `jq`, `edge-tts`, or wrong `PYTHON_BIN`
- **Voice spells letters** → write callsigns as single words (`AXE` not `A.X.E.`)
- **Generic lines only** → Groq call failing; check `voice.log` for HTTP errors

## The name

*Sonar* — scanning multiple targets you can't see. They ping you back when they have something to report.

*AXE — Automated X-platform Engine.* The assistant callsign. Pronounced like the tool — one word, never spelled out.

---

Built by [Punith Gowda](https://github.com/filmy-munky)
