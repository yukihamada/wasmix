import { envInfo } from './env';
import { canUseWebCodecs } from './encode';

export async function mountHUD() {
  const hud = {
    webcodecs: document.getElementById('hud-webcodecs')!,
    coi: document.getElementById('hud-coi')!,
    sab: document.getElementById('hud-sab')!,
    sw: document.getElementById('hud-sw')!,
  };
  const { coi, sab, sw } = envInfo();
  hud.coi.textContent = String(coi);
  hud.sab.textContent = String(sab);
  hud.sw.textContent = String(sw);

  try {
    const dec = await canUseWebCodecs();
    hud.webcodecs.textContent = dec.webcodecs ? 'available' : `no (${dec.reason})`;
  } catch (e) {
    hud.webcodecs.textContent = 'error';
  }
}
