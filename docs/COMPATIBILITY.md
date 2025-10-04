# Browser compatibility (high level)

- **AudioWorklet**: modern Chromium/Firefox/Safari.
- **OPFS**: modern browsers; Sync Access Handle in Workers only.
- **WebCodecs (audio)**: limited availability; the app detects and falls back (future).
- **Web MIDI**: Chromium & Firefox; Safari often lacks support.
- **SAB/Threads**: require `crossOriginIsolated` (COOP/COEP headers).

For up-to-date status, test the HUD in the header and check console logs.
