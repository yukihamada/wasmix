# Sprint 1 — One-week plan (M1 kick-off)

**Goal:** WebCodecs detection + fallback path foundation, and durability skeleton.

## Backlog → Selected
- [ ] WebCodecs detect & stub encoder API (`src/modules/encode.ts`)
- [ ] Worker wiring for future `ffmpeg.wasm` fallback (no binary yet)
- [ ] OPFS journal API (append, snapshot, replay stubs) (`src/modules/journal.ts`)
- [ ] CI: typecheck + build + Pages artifact
- [ ] Issue templates & PR template (this PR)

## Acceptance criteria
- `encode.canUseWebCodecs()` returns true/false and logs decision.
- MVP still runs; WAV export unchanged.
- Unit-free smoke tests run on CI (build succeeds).

## Tasks
1. `src/modules/encode.ts` — feature detect `AudioEncoder.isConfigSupported`
2. `src/modules/journal.ts` — define API surface: `append(op)`, `snapshot()`, `replay()`
3. Replace console logs with a minimal status HUD component (done)
4. GitHub Actions: ensure Pages deploy job not broken
