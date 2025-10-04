export async function setupMIDI(target: HTMLElement) {
  if (!('requestMIDIAccess' in navigator)) {
    target.textContent = 'Web MIDI not supported on this browser.';
    return;
  }
  try {
    // @ts-ignore
    const access: WebMidi.MIDIAccess = await navigator.requestMIDIAccess();
    target.innerHTML = '';
    target.appendChild(line('Inputs:'));
    access.inputs.forEach((input) => {
      target.appendChild(line(`- ${input.name}`));
      input.onmidimessage = (e) => {
        target.appendChild(line(`  msg [${Array.from(e.data).join(', ')}]`));
      };
    });
    access.outputs.forEach((out) => {
      target.appendChild(line(`Output: ${out.name}`));
    });
  } catch (e) {
    target.textContent = 'MIDI permission denied or unavailable.';
  }
}

function line(s: string) {
  const p = document.createElement('div');
  p.textContent = s;
  return p;
}
