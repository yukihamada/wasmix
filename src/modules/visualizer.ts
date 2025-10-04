// Audio Visualizer Module

export class AudioVisualizer {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private animationId: number | null = null;
  private analyser: AnalyserNode | null = null;
  private dataArray: Uint8Array | null = null;

  constructor(container: HTMLElement) {
    this.canvas = document.createElement('canvas');
    this.canvas.style.width = '100%';
    this.canvas.style.height = '100%';
    container.appendChild(this.canvas);
    
    const ctx = this.canvas.getContext('2d');
    if (!ctx) throw new Error('Canvas 2D context not available');
    this.ctx = ctx;
    
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  private resize() {
    const rect = this.canvas.parentElement?.getBoundingClientRect();
    if (rect) {
      this.canvas.width = rect.width * window.devicePixelRatio;
      this.canvas.height = rect.height * window.devicePixelRatio;
      this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
    }
  }

  connect(audioContext: AudioContext, source: AudioNode) {
    this.analyser = audioContext.createAnalyser();
    this.analyser.fftSize = 2048;
    this.analyser.smoothingTimeConstant = 0.8;
    
    source.connect(this.analyser);
    
    const bufferLength = this.analyser.frequencyBinCount;
    this.dataArray = new Uint8Array(bufferLength);
    
    this.start();
  }

  private start() {
    const draw = () => {
      this.animationId = requestAnimationFrame(draw);
      
      if (!this.analyser || !this.dataArray) return;
      
      this.analyser.getByteTimeDomainData(this.dataArray);
      
      const width = this.canvas.width / window.devicePixelRatio;
      const height = this.canvas.height / window.devicePixelRatio;
      
      // Clear canvas
      this.ctx.fillStyle = '#0a0a0f';
      this.ctx.fillRect(0, 0, width, height);
      
      // Draw waveform
      this.ctx.lineWidth = 2;
      this.ctx.strokeStyle = '#00d4aa';
      this.ctx.beginPath();
      
      const sliceWidth = width / this.dataArray.length;
      let x = 0;
      
      for (let i = 0; i < this.dataArray.length; i++) {
        const v = this.dataArray[i] / 128.0;
        const y = v * height / 2;
        
        if (i === 0) {
          this.ctx.moveTo(x, y);
        } else {
          this.ctx.lineTo(x, y);
        }
        
        x += sliceWidth;
      }
      
      this.ctx.lineTo(width, height / 2);
      this.ctx.stroke();
      
      // Add glow effect
      this.ctx.shadowBlur = 10;
      this.ctx.shadowColor = '#00d4aa';
      this.ctx.stroke();
      this.ctx.shadowBlur = 0;
    };
    
    draw();
  }

  stop() {
    if (this.animationId !== null) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
    
    // Clear the canvas
    const width = this.canvas.width / window.devicePixelRatio;
    const height = this.canvas.height / window.devicePixelRatio;
    this.ctx.fillStyle = '#0a0a0f';
    this.ctx.fillRect(0, 0, width, height);
  }

  disconnect() {
    this.stop();
    this.analyser = null;
    this.dataArray = null;
  }
}