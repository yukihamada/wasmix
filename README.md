# WASMIX (MVP)

**Local‑first, conflict‑free Web DAW.**  
AudioWorklet + PWA + OPFS で「録る・聴く・残す」を最短で。

> このMVPは **録音/モニタ/エクスポート(WAV)** と **OPFS保存**, **PWAオフライン**, **簡易CRDTメモ**, **MIDI列挙** を実装した最小構成です。

---

## デモの狙い
- **低遅延モニタ**: `AudioWorklet`（モノラル）でモニタしながら録音
- **WAVエクスポート**: ブラウザ内で16-bit PCM WAVを生成
- **ローカル保存**: **OPFS** に保存/再生
- **PWA**: Service Worker同梱でオフラインでも起動
- **CRDT**: Automergeでローカルメモ（同期は別実装）
- **MIDI**: 入力列挙とメッセージの監視

> 次段：WebCodecs → FFmpeg.wasm フォールバックでエクスポート加速。

---

## ローカル実行
```bash
npm i
npm run dev
# http://localhost:5173 を開く
```

devサーバは `COOP/COEP` を返すよう設定済み（SAB/Threadsを将来使うための布石）。

---

## GitHub Codespaces で開く
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/<YOUR_ORG>/<YOUR_REPO>?quickstart=1)

---

## デプロイ先の選択
- **GitHub Pages**：MVPはOK。ただし **COOP/COEPが出せない**ため、SAB/Threadsを使う将来機能は不可。  
- **Vercel/Netlify**：このリポの `vercel.json` / `public/_headers` でCOOP/COEPを付与できます。  
くわしくは `docs/DEPLOYMENT.md` を参照。

---

## 構成
```
/src
  /modules
    recorder.ts       # 録音＆WAVエンコード
    opfs.ts           # OPFS: 保存/一覧/読込
    crdt.ts           # Automergeメモ
    midi.ts           # Web MIDI 列挙
    encode.ts         # WebCodecs検出（将来のエンコード窓口）
    journal.ts        # OPFSジャーナル骨格
    env.ts, hud.ts    # 環境検出とHUD
  /worklets
    monitor-processor.js
/public
  sw.js, manifest.webmanifest, icon.svg, _headers
vercel.json, vite.config.ts
```

---

## スプリント運用
- `docs/ROADMAP.md` / `docs/SPRINT-1.md` を参照
- `scripts/seed-issues.sh owner/repo` で Issue を流し込み
- 小さめPR（≤300行）で進める

---

## ライセンス
MIT
