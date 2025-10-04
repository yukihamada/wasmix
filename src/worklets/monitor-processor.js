class MonitorProcessor extends AudioWorkletProcessor {
  constructor(options) {
    super(options);
    this._record = false;
    this._sum = 0;
    this._count = 0;
    this.port.onmessage = (ev) => {
      if (ev.data?.type === 'record') this._record = !!ev.data.on;
    };
  }
  process(inputs, outputs, parameters) {
    const input = inputs[0];
    const output = outputs[0];
    if (input && input[0] && output && output[0]) {
      output[0].set(input[0]);
      if (this._record) {
        const left = new Float32Array(input[0].length);
        left.set(input[0]);
        this.port.postMessage({ type: 'frames', left }, [left.buffer]);
      }
      let sum = 0;
      const ch = input[0];
      for (let i = 0; i < ch.length; i++) { const s = ch[i]; sum += s * s; }
      this._sum += sum / ch.length;
      this._count++;
      if (this._count % 30 === 0) {
        const rms = Math.sqrt(this._sum / this._count);
        this.port.postMessage({ type: 'rms', rms });
        this._sum = 0; this._count = 0;
      }
    }
    return true;
  }
}
registerProcessor('monitor-processor', MonitorProcessor);
