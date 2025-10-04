export function envInfo() {
  const coi = (globalThis as any).crossOriginIsolated === true;
  const sab = typeof SharedArrayBuffer !== 'undefined';
  const sw = 'serviceWorker' in navigator;
  return { coi, sab, sw };
}
