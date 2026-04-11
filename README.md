# claude-sonar

### [Solved] The observability gap in parallel AI agent workflows — hear what every Claude Code session just did, without looking.

A Stop-hook kit that gives every Claude Code session a voice. Parallel AI workflows used to be invisible — now they're audible.

![Ad hero](./screenshots/ad-hero.svg)

---

## Why this exists

In 2026, most engineers aren't running one AI assistant — they're running **four at once**. One migrating a database. One building a bundle. One running tests. One deploying a preview.

**The problem:** visual attention is a single-threaded resource. You cannot watch four terminals simultaneously. So you miss when things finish. You miss when things break. You context-switch constantly just to check status. The productivity you *should* be getting from parallel AI delegation gets eaten by the overhead of monitoring it.

This is an **observability problem**, not a UI problem. And observability problems don't get solved by adding more panels — they get solved by adding the right channel.

## The fix: voice as an ambient channel

Human auditory processing runs in parallel to vision. You can hear a timer while reading a book. You can pick up your name in a crowded room while focused on a conversation. Sound is **omnidirectional** and **pre-attentive** — you don't need to look at it to receive it.

`claude-sonar` wires a Stop hook into every Claude Code session. After each turn, it:

1. Grabs the last assistant message from the transcript
2. Sends it to Groq `llama-3.1-8b-instant` with a JARVIS-style system prompt (~300ms)
3. Speaks the 10-word response via `edge-tts` in a British butler voice
4. Returns in under 10ms so Claude never blocks

Real lines pulled straight from today's `voice.log`:

![Voice log](./screenshots/voice-log.svg)

None are scripted. Every line is generated fresh from the message that just landed. The voice *understands* what happened — so it can say it back to you specifically.

Now you run four Claude sessions and you hear:

> *"Migration applied successfully, sir."* — session 1
>
> *"147 tests passing, sir."* — session 3
>
> *"Preview deployment live on Vercel, sir."* — session 4

Without looking. Without alt-tabbing. Without losing focus on whichever session you're actively coding in.

This is what ambient computing looks like for AI developer tools.

---

## Key features

- 🎯 **Context-aware voice** — every line is LLM-generated from what Claude actually just said. No canned phrases. No "task complete" noise.
- ⚡ **Sub-10ms hook** — fully async. Claude never blocks waiting on voice.
- 🧠 **Groq `llama-3.1-8b-instant`** — ~300ms round-trip on the free tier (30 req/min). Plenty for heavy solo work.
- 🇬🇧 **British butler voice** — `edge-tts` with `en-GB-RyanNeural`. A/B tested against 4 alternatives.
- 🛟 **Graceful degradation** — cached MP3 fallbacks if the LLM call fails. Never silent, never broken.
- 💸 **Free to run** — no paid APIs, no local models, no build step.
- 🔧 **Swap anything** — voice, model, callsign, persona. All one-line edits.

## Requirements

- macOS (uses `afplay`)
- Python 3.10+
- `jq`, `curl` → `brew install jq curl`
- A free Groq API key → [console.groq.com/keys](https://console.groq.com/keys)

## Install

```bash
git clone https://github.com/filmy-munky/claude-sonar.git
cd claude-sonar
./install.sh
```

The installer copies the hook to `~/.claude/hooks/`, installs `edge-tts`, and creates a `.env` template. Then:

1. Paste your Groq key into `~/.claude/hooks/.env`
2. Merge the `Stop` hook block from `settings.json.example` into `~/.claude/settings.json`
3. Open a new Claude Code session — the first reply will chime and speak

**Setup time: under 3 minutes.**

## Configure

Edit `~/.claude/hooks/axe-voice.sh`:

| Variable | Default | Swap to |
|----------|---------|---------|
| `EDGE_VOICE` | `en-GB-RyanNeural` | `python3 -m edge_tts --list-voices` for alternatives |
| `GROQ_MODEL` | `llama-3.1-8b-instant` | `llama-3.3-70b-versatile` for smarter, slower lines |

Drop `CLAUDE.md.example` into `~/.claude/CLAUDE.md` to make Claude's *written* tone match the voice.

## Files

| Path | Purpose |
|------|---------|
| `hooks/axe-voice.sh` | The Stop hook — tails transcript, calls Groq, speaks via edge-tts |
| `hooks/.env.example` | Template for `GROQ_API_KEY` |
| `hooks/voice-cache/` | Fallback MP3s if the LLM call fails |
| `settings.json.example` | Stop hook wiring for `~/.claude/settings.json` |
| `CLAUDE.md.example` | JARVIS persona prompt for the text layer |
| `install.sh` | One-shot installer |
| `assets/ad.html` | Self-contained Apple-ad animation (22s loop, screen-record ready) |
| `screenshots/` | Visual assets for this README |

## Troubleshooting

Tail `~/.claude/hooks/voice.log` — every invocation logs there.

- **Silent** → missing `GROQ_API_KEY`, `jq`, `edge-tts`, or wrong `PYTHON_BIN` in the hook
- **Voice spells "A dot X dot E dot"** → your persona file has the name as `A.X.E.`; write callsigns as single words
- **Generic lines only** → Groq call is failing; check `voice.log` for HTTP errors

## The name

*Sonar* — because you're scanning multiple targets you can't see, and they ping you back when they have something to report. That is literally what this does.

---

Built by [Punith Gowda](https://github.com/filmy-munky)
