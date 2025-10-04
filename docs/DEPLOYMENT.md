# Deployment

## GitHub Pages (static)
- ✅ Works for MVP features (WAV export, OPFS, PWA).
- ⛔ Custom headers (COOP/COEP) are **not** supported. Features requiring SharedArrayBuffer/Threads must use alternative hosts.

## Vercel
- Include `vercel.json` (already in repo) to set:
  - `Cross-Origin-Opener-Policy: same-origin`
  - `Cross-Origin-Embedder-Policy: require-corp`

## Netlify
- Use `public/_headers` (already in repo).

## Local dev
- `vite.config.ts` is configured to serve COOP/COEP headers during `npm run dev`.
