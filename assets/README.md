# assets/

## `ad.html` — the Apple-ad-style animation

Self-contained HTML. No build step. No external deps. Open in Safari, full-screen, screen-record with QuickTime → you have a 22-second ad loop for LinkedIn / Twitter / whatever.

### Record it

```bash
open -a Safari /Users/YOU/claude-sonar/assets/ad.html
```

1. Press `Cmd + Ctrl + F` — full screen.
2. Open **QuickTime Player** → `File → New Screen Recording`.
3. Record the **whole screen** for ~25 seconds (full 22s loop + 3s lead-in for the black fade).
4. Stop. Trim to 22s. Export at 1080p.

### What the ad shows

| Time | Scene | Content |
|------|-------|---------|
| 00:00 – 02:5 | Brand | `claude-sonar` hero type |
| 02:5 – 06:5 | Problem | *"Four terminals. One pair of eyes."* |
| 06:5 – 11:0 | Stack | Stop hook → Groq 300ms → edge-tts |
| 11:0 – 15:5 | Voice | Real AXE line + animated waveform |
| 15:5 – 19:0 | Multi-terminal | 4-panel grid, one terminal highlighted |
| 19:0 – 22:0 | Tagline | *"Built for the hands-off engineer."* |

### Aesthetic notes

- Pitch black (`#000`) — Apple ad default.
- `-apple-system` / SF Pro font stack — zero webfonts, looks native on macOS.
- Single accent: `#0a84ff` (Apple system blue).
- Slow 4-second scene holds — resist the urge to speed up; Apple ads *breathe*.
- Waveform pulse fakes the voice playing. For the final cut, dub over with the real AXE voice using `edge-tts --voice en-GB-RyanNeural --text "All three hero demos have passed validation, sir." --write-media hero.mp3`.

### Customizing

- Change `--accent` in `:root` for a different color direction. `#ff375f` (Apple red) and `#30d158` (Apple green) both look great.
- Edit the hero line in scene 4 to any line from your own `voice.log`.
- The `.grid` terminals in scene 5 are just styled divs — edit the text to whatever workflow you actually run.
