# voice-cache — fallback MP3s

The hook calls Groq + edge-tts on every turn. If either fails (network blip, rate limit, missing key), it falls back to a cached MP3 from this directory so there's *some* audio feedback instead of dead silence.

## Regenerate

```bash
python3 -m edge_tts --voice en-GB-RyanNeural --text "Ready, sir."               --write-media ready.mp3
python3 -m edge_tts --voice en-GB-RyanNeural --text "Done, sir."                --write-media done.mp3
python3 -m edge_tts --voice en-GB-RyanNeural --text "Working on it, sir."       --write-media working.mp3
python3 -m edge_tts --voice en-GB-RyanNeural --text "Awaiting clarification, sir." --write-media clarify.mp3
python3 -m edge_tts --voice en-GB-RyanNeural --text "Permission required, sir." --write-media permission.mp3
python3 -m edge_tts --voice en-GB-RyanNeural --text "Encountered an error, sir." --write-media error.mp3
```

Run those from inside this directory. The hook looks for `ready.mp3` by default — the others are there for future routing if you ever want to classify fallback responses.
