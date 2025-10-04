export type EncodeDecision = {
  webcodecs: boolean;
  reason: string;
};

export async function canUseWebCodecs(): Promise<EncodeDecision> {
  const has = 'AudioEncoder' in globalThis && typeof (globalThis as any).AudioEncoder?.isConfigSupported === 'function';
  if (!has) return { webcodecs: false, reason: 'AudioEncoder or isConfigSupported not present' };
  try {
    // @ts-ignore
    const probe = await (globalThis as any).AudioEncoder.isConfigSupported?.({
      codec: 'opus', sampleRate: 48000, numberOfChannels: 2, bitrate: 128_000
    });
    return { webcodecs: !!probe?.supported, reason: probe?.supported ? 'supported' : 'isConfigSupported: false' };
  } catch (e) {
    return { webcodecs: false, reason: `probe failed: ${(e as Error).message}` };
  }
}

export async function encodeWavToOpus(_wav: ArrayBuffer): Promise<ArrayBuffer | null> {
  const { webcodecs, reason } = await canUseWebCodecs();
  console.log('[encode] WebCodecs?', webcodecs, reason);
  return null;
}
