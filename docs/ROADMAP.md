# WASMIX – Roadmap

## Status
- ✅ MVP: AudioWorklet-based monitor/record, WAV export, OPFS save/load, PWA offline, CRDT notes, MIDI enumerate.
- 🔜 Next increments focus on **export**, **durability**, **collab**.

## Milestones
### M1 — Export acceleration (WebCodecs / FFmpeg.wasm)
- Detect `AudioEncoder.isConfigSupported()` and prefer WebCodecs when available.
- Fallback to `ffmpeg.wasm` in a Worker for AAC/Opus/MP3 and stems.
- **DoD:** 60s stereo @48k/128kbps encodes under 2× realtime on M3-level laptop; functional fallback on non-supporting browsers.

### M2 — Zero‑loss persistence (OPFS snapshot + journal)
- Append-only journal per project; periodic snapshot; crash-safe replay on boot.
- **DoD:** Forced crash test recovers to <5s with no data loss across 100 edits.

### M3 — Realtime/async collaboration (CRDT sync)
- WebSocket relay or WebRTC mesh for Automerge/Yjs docs.
- **DoD:** Two peers edit tracks & notes conflict-free with sub-second remote echo (LAN).

### M4 — Performance guardrails
- SAB ring buffer and back-pressure; XRuns detector adapting 128→256f blocks; RUM telemetry for `baseLatency` and p95 UI lag.
- **DoD:** p95 UI response <50ms on 100-track synthetic session; XRuns/min == 0 for 10min.

### M5 — MIDI Learn & mapping presets
- Map CC/Note to parameters; persist maps in OPFS.
- **DoD:** Learn flow (<10s) and recall across sessions.

### M6 — Hosting & CI
- Pages (static) for MVP; Netlify/Vercel for COOP/COEP headers when SAB/Threads are required.
- **DoD:** One-click deploys; CI build & preview per PR.
