import { initAudio, startRecording, stopRecording, exportWav, getState } from './modules/recorder';
import { saveFile, listFiles, loadLatest } from './modules/opfs';
import { initNotes } from './modules/crdt';
import { setupMIDI } from './modules/midi';
import { mountHUD } from './modules/hud';
import { AudioVisualizer } from './modules/visualizer';

// HUD first
mountHUD();

// Initialize visualizer
let visualizer: AudioVisualizer | null = null;

// Register Service Worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js');
}

// Offline badge
const offlineIndicator = document.getElementById('indicator-offline')!;
function updateOnline() { 
  offlineIndicator.style.display = navigator.onLine ? 'none' : 'flex';
  if (!navigator.onLine) {
    offlineIndicator.classList.add('error');
  } else {
    offlineIndicator.classList.remove('error');
  }
}
addEventListener('online', updateOnline);
addEventListener('offline', updateOnline);
updateOnline();

const el = {
  start: document.getElementById('btn-start') as HTMLButtonElement,
  record: document.getElementById('btn-record') as HTMLButtonElement,
  stop: document.getElementById('btn-stop') as HTMLButtonElement,
  exportBtn: document.getElementById('btn-export') as HTMLButtonElement,
  save: document.getElementById('btn-save') as HTMLButtonElement,
  list: document.getElementById('btn-list') as HTMLButtonElement,
  load: document.getElementById('btn-load') as HTMLButtonElement,
  device: document.getElementById('device')!,
  sr: document.getElementById('samplerate')!,
  base: document.getElementById('baselatency')!,
  log: document.getElementById('log')!,
  files: document.getElementById('files')!,
  notes: document.getElementById('notes') as HTMLTextAreaElement,
  docid: document.getElementById('docid')!,
  midiBtn: document.getElementById('btn-midi') as HTMLButtonElement,
  midiList: document.getElementById('midi')!
};

el.start.addEventListener('click', async () => {
  el.start.disabled = true;
  try {
    const info = await initAudio();
    
    // Update device info in the top bar
    const deviceInfo = document.getElementById('device-info')!;
    deviceInfo.innerHTML = `
      <span>${info.deviceLabel ?? 'Unknown Device'}</span>
      <span>${info.sampleRate}Hz</span>
    `;
    
    // Update latency info
    el.base.textContent = info.baseLatency ? `${(info.baseLatency * 1000).toFixed(1)}ms` : '--ms';
    
    // Initialize visualizer
    const visualizerContainer = document.getElementById('visualizer')!;
    visualizer = new AudioVisualizer(visualizerContainer);
    const state = getState();
    if (state.ctx && state.processor) {
      visualizer.connect(state.ctx, state.processor);
    }
    
    el.record.disabled = false;
    el.exportBtn.disabled = false;
    el.save.disabled = false;
    log('Audio initialized successfully');
    
    // Update button state
    el.start.textContent = 'Audio Active';
    el.start.classList.remove('btn-primary');
    el.start.classList.add('active');
  } catch (e) {
    el.start.disabled = false;
    log('Audio start failed: ' + (e as Error).message);
  }
});

el.record.addEventListener('click', async () => {
  el.record.disabled = true;
  el.stop.disabled = false;
  await startRecording();
  log('Recording started...');
  
  // Add recording animation
  el.record.classList.add('recording');
  document.body.classList.add('recording-active');
});

el.stop.addEventListener('click', async () => {
  await stopRecording();
  el.stop.disabled = true;
  el.record.disabled = false;
  log('Recording stopped');
  
  // Remove recording animation
  el.record.classList.remove('recording');
  document.body.classList.remove('recording-active');
});

el.exportBtn.addEventListener('click', async () => {
  const wav = await exportWav();
  if (!wav) { log('Nothing to export'); return; }
  const blob = new Blob([wav], { type: 'audio/wav' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'wasmix-recording.wav';
  a.click();
  URL.revokeObjectURL(url);
  log('Exported WAV');
});

el.save.addEventListener('click', async () => {
  const state = getState();
  if (!state.lastWav) { log('Export WAV first'); return; }
  await saveFile('renders/mixdown.wav', state.lastWav);
  // journal (best-effort)
  try {
    const { append } = await import('./modules/journal');
    await append('default', { ts: Date.now(), kind: 'save-render', payload: { path: 'renders/mixdown.wav', bytes: state.lastWav.byteLength } });
  } catch {}
  log('Saved to OPFS: renders/mixdown.wav');
  await refreshList();
});

async function refreshList() {
  const arr = await listFiles('renders');
  el.files.innerHTML = '';
  
  if (arr.length === 0) {
    el.files.innerHTML = '<div style="text-align: center; color: var(--text-dim); padding: var(--space-lg);">No files yet. Record something first!</div>';
  } else {
    for (const f of arr) {
      const fileItem = document.createElement('div');
      fileItem.className = 'file-item';
      fileItem.textContent = f;
      fileItem.addEventListener('click', () => {
        // Highlight selected file
        document.querySelectorAll('.file-item').forEach(item => item.classList.remove('selected'));
        fileItem.classList.add('selected');
      });
      el.files.appendChild(fileItem);
    }
  }
  el.load.disabled = arr.length === 0;
}
el.list.addEventListener('click', refreshList);

el.load.addEventListener('click', async () => {
  const buf = await loadLatest('renders');
  if (!buf) { log('No file'); return; }
  const ctx = getState().ctx;
  if (!ctx) return;
  const audioBuf = await ctx.decodeAudioData(buf.slice(0));
  const src = new AudioBufferSourceNode(ctx, { buffer: audioBuf });
  src.connect(ctx.destination);
  src.start();
  log('Playing latest OPFS render');
});

function log(s: string) {
  el.log.textContent = `[${new Date().toLocaleTimeString()}] ${s}\n` + el.log.textContent;
}

// CRDT notes
initNotes(el.notes, el.docid);

// MIDI
el.midiBtn.addEventListener('click', () => setupMIDI(el.midiList));
