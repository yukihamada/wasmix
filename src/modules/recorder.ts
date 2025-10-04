let ctx: AudioContext | null = null;
let processor: AudioWorkletNode | null = null;
let recording = false;
let recorded: Float32Array[] = [];
let sampleRate = 48000;
let lastWav: ArrayBuffer | null = null;
let deviceLabel: string | undefined;

export async function initAudio() {
  const stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: false, noiseSuppression: false } });
  deviceLabel = stream.getAudioTracks()[0]?.label;
  ctx = new AudioContext({ latencyHint: 'interactive' });
  sampleRate = ctx.sampleRate;
  await ctx.audioWorklet.addModule(new URL('../worklets/monitor-processor.js', import.meta.url));
  const src = new MediaStreamAudioSourceNode(ctx, { mediaStream: stream });
  processor = new AudioWorkletNode(ctx, 'monitor-processor');
  processor.port.onmessage = (ev) => {
    if (ev.data?.type === 'frames' && recording) {
      recorded.push(new Float32Array(ev.data.left));
    }
  };
  src.connect(processor).connect(ctx.destination);
  return { sampleRate, baseLatency: ctx.baseLatency, deviceLabel };
}

export async function startRecording() {
  recorded = [];
  recording = true;
  processor?.port.postMessage({ type: 'record', on: true });
}

export async function stopRecording() {
  recording = false;
  processor?.port.postMessage({ type: 'record', on: false });
}

export function getState() {
  return { ctx, sampleRate, lastWav, deviceLabel };
}

export async function exportWav(): Promise<ArrayBuffer | null> {
  if (!recorded.length || !ctx) return null;
  const length = recorded.reduce((a, b) => a + b.length, 0);
  const pcm = new Float32Array(length);
  let o = 0;
  for (const chunk of recorded) { pcm.set(chunk, o); o += chunk.length; }
  lastWav = encodeWAV(pcm, ctx.sampleRate);
  return lastWav;
}

// 16-bit PCM WAV encoder
function encodeWAV(samples: Float32Array, sampleRate: number): ArrayBuffer {
  const numChannels = 1;
  const bytesPerSample = 2;
  const blockAlign = numChannels * bytesPerSample;
  const byteRate = sampleRate * blockAlign;
  const dataSize = samples.length * bytesPerSample;
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);

  // RIFF header
  writeString(view, 0, 'RIFF');
  view.setUint32(4, 36 + dataSize, true);
  writeString(view, 8, 'WAVE');

  // fmt chunk
  writeString(view, 12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, 16, true);

  // data chunk
  writeString(view, 36, 'data');
  view.setUint32(40, dataSize, true);

  let offset = 44;
  for (let i = 0; i < samples.length; i++, offset += 2) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
  }
  return buffer;
}

function writeString(view: DataView, offset: number, str: string) {
  for (let i = 0; i < str.length; i++) view.setUint8(offset + i, str.charCodeAt(i));
}
