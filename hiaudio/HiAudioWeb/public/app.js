// 🎵 HiAudio Pro Web Client - Ultra-low latency audio receiver
class HiAudioWebClient {
    constructor() {
        this.socket = null;
        this.audioEngine = null;
        this.isReceiving = false;
        this.stats = {
            packetsReceived: 0,
            latency: 100.0, // デフォルトは100ms遅延
            uptime: 0
        };
        
        this.initializeUI();
        this.connectToServer();
        this.startPingTimer();
        this.setupStabilityMonitoring();
    }
    
    initializeUI() {
        // Initialize spectrum analyzer bars
        this.initializeSpectrumAnalyzer();
        
        // Initialize waveform canvas
        this.initializeWaveform();
        
        // Volume slider event
        const volumeSlider = document.getElementById('volumeSlider');
        volumeSlider.addEventListener('input', (e) => {
            const volume = e.target.value;
            document.getElementById('volumeValue').textContent = `${volume}%`;
            if (this.audioEngine) {
                this.audioEngine.setVolume(volume / 100);
            }
        });
        
        // Test sound button
        const testSoundBtn = document.getElementById('testSoundBtn');
        if (testSoundBtn) {
            testSoundBtn.addEventListener('click', () => {
                this.playTestSound();
            });
        }
    }
    
    initializeSpectrumAnalyzer() {
        const analyzer = document.getElementById('spectrumAnalyzer');
        analyzer.innerHTML = '';
        
        // Create 64 spectrum bars
        for (let i = 0; i < 64; i++) {
            const bar = document.createElement('div');
            bar.className = 'spectrum-bar';
            bar.style.height = '2px';
            analyzer.appendChild(bar);
        }
    }
    
    initializeWaveform() {
        const canvas = document.getElementById('waveformCanvas');
        const ctx = canvas.getContext('2d');
        
        // Set canvas resolution
        canvas.width = canvas.offsetWidth * window.devicePixelRatio;
        canvas.height = canvas.offsetHeight * window.devicePixelRatio;
        ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
        
        this.waveformCanvas = canvas;
        this.waveformContext = ctx;
        
        // Initialize with flat line
        this.drawWaveform([]);
    }
    
    connectToServer() {
        console.log('🌐 Connecting to HiAudio server...');
        this.updateConnectionStatus('connecting', '接続中...');
        
        this.socket = io({
            transports: ['websocket', 'polling'],
            timeout: 20000,
            forceNew: true
        });
        
        this.socket.on('connect', () => {
            console.log('✅ Connected to server');
            this.updateConnectionStatus('connected', '接続済み');
            this.updateConnectionState('オンライン');
            
            // Reset reconnection counter on successful connection
            this.reconnectAttempts = 0;
            this.startTime = this.startTime || Date.now();
        });
        
        this.socket.on('disconnect', (reason) => {
            console.log('❌ Disconnected from server:', reason);
            this.updateConnectionStatus('disconnected', '切断');
            this.updateConnectionState('オフライン');
            this.isReceiving = false;
            this.updateControlButton();
        });
        
        this.socket.on('connected', (data) => {
            console.log('🎵 Server handshake completed:', data);
            this.audioFormat = data.audioFormat;
        });
        
        this.socket.on('audio-stream', (audioData) => {
            this.lastDataReceived = Date.now();
            this.handleAudioData(audioData);
        });
        
        this.socket.on('audio-started', (data) => {
            console.log('🎵 Audio stream started');
            this.isReceiving = true;
            this.updateControlButton();
        });
        
        this.socket.on('audio-stopped', (data) => {
            console.log('🔇 Audio stream stopped');
            this.isReceiving = false;
            this.updateControlButton();
        });
        
        this.socket.on('stats-update', (stats) => {
            this.updateStats(stats);
        });
        
        this.socket.on('pong', (data) => {
            // 実際の遅延を正確に計算
            const actualLatency = Date.now() - data.originalTimestamp;
            this.stats.latency = actualLatency;
            this.updateLatencyDisplay(actualLatency);
        });
        
        this.socket.on('connect_error', (error) => {
            console.error('❌ Connection error:', error);
            this.updateConnectionStatus('disconnected', '接続エラー');
        });
    }
    
    toggleAudio() {
        if (!this.socket || !this.socket.connected) {
            alert('サーバーに接続されていません');
            return;
        }
        
        if (this.isReceiving) {
            this.stopAudio();
        } else {
            this.startAudio();
        }
    }
    
    async startAudio() {
        try {
            console.log('🎵 Starting audio reception...');
            
            // Initialize Web Audio API
            if (!this.audioEngine) {
                this.audioEngine = new AudioEngine();
                await this.audioEngine.initialize();
            }
            
            // Start audio context
            await this.audioEngine.start();
            
            // Notify server
            this.socket.emit('start-audio', {
                timestamp: Date.now(),
                userAgent: navigator.userAgent
            });
            
            console.log('✅ Audio reception started');
            
        } catch (error) {
            console.error('❌ Failed to start audio:', error);
            alert('オーディオの開始に失敗しました: ' + error.message);
        }
    }
    
    stopAudio() {
        console.log('🔇 Stopping audio reception...');
        
        if (this.audioEngine) {
            this.audioEngine.stop();
        }
        
        this.socket.emit('stop-audio', {
            timestamp: Date.now()
        });
        
        console.log('✅ Audio reception stopped');
    }
    
    handleAudioData(audioData) {
        if (!this.isReceiving || !this.audioEngine) return;
        
        try {
            // Process audio data
            this.audioEngine.processAudioData(audioData);
            
            // Update stats
            this.stats.packetsReceived++;
            
            // Update visualizations (throttled)
            if (this.stats.packetsReceived % 10 === 0) {
                this.updateSpectrumAnalyzer(audioData.data);
                this.drawWaveform(audioData.data.slice(0, 128));
            }
            
        } catch (error) {
            console.error('❌ Audio processing error:', error);
        }
    }
    
    updateSpectrumAnalyzer(audioData) {
        const bars = document.querySelectorAll('.spectrum-bar');
        const spectrumData = this.audioEngine ? this.audioEngine.getSpectrumData() : [];
        
        bars.forEach((bar, index) => {
            const value = spectrumData[index] || Math.random() * 0.3; // Fallback visualization
            const height = Math.max(2, value * 130); // 2px minimum, 130px maximum
            bar.style.height = `${height}px`;
        });
    }
    
    drawWaveform(audioData) {
        const canvas = this.waveformCanvas;
        const ctx = this.waveformContext;
        const width = canvas.offsetWidth;
        const height = canvas.offsetHeight;
        
        ctx.clearRect(0, 0, width, height);
        
        if (!audioData || audioData.length === 0) {
            // Draw center line
            ctx.strokeStyle = 'rgba(0, 217, 255, 0.3)';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, height / 2);
            ctx.lineTo(width, height / 2);
            ctx.stroke();
            return;
        }
        
        // Draw waveform
        ctx.strokeStyle = '#00ff88';
        ctx.lineWidth = 2;
        ctx.beginPath();
        
        const sliceWidth = width / audioData.length;
        let x = 0;
        
        for (let i = 0; i < audioData.length; i++) {
            const sample = audioData[i] || 0;
            const y = (sample + 1) * height / 2; // Convert from [-1, 1] to [0, height]
            
            if (i === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
            
            x += sliceWidth;
        }
        
        ctx.stroke();
    }
    
    updateStats(stats) {
        this.stats = { ...this.stats, ...stats };
        document.getElementById('packetsReceived').textContent = this.stats.packetsReceived.toLocaleString();
    }
    
    updateLatencyDisplay(latency) {
        const latencyElement = document.getElementById('latencyValue');
        
        // 実際の遅延値を表示
        latencyElement.textContent = `${latency.toFixed(1)}ms`;
        
        // 現実的な遅延基準でカラーコード
        if (latency < 10) {
            latencyElement.style.color = '#00ff88'; // Green - 超低遅延
            latencyElement.style.textShadow = '0 0 8px #00ff88';
        } else if (latency < 50) {
            latencyElement.style.color = '#00d9ff'; // Blue - 低遅延
            latencyElement.style.textShadow = '0 0 6px #00d9ff';
        } else if (latency < 100) {
            latencyElement.style.color = '#ff9500'; // Orange - 普通
            latencyElement.style.textShadow = '0 0 4px #ff9500';
        } else {
            latencyElement.style.color = '#ff3b30'; // Red - 高遅延
            latencyElement.style.textShadow = '0 0 4px #ff3b30';
        }
    }
    
    updateConnectionStatus(status, text) {
        const statusElement = document.getElementById('connectionStatus');
        statusElement.className = `connection-status ${status}`;
        statusElement.textContent = text;
    }
    
    updateConnectionState(state) {
        document.getElementById('connectionState').textContent = state;
    }
    
    updateControlButton() {
        const button = document.getElementById('controlButton');
        
        if (this.isReceiving) {
            button.className = 'control-button stop pulse-animation';
            button.innerHTML = '<span>🔇</span><span>停止</span>';
        } else {
            button.className = 'control-button start';
            button.innerHTML = '<span>🎵</span><span>開始</span>';
        }
    }
    
    startPingTimer() {
        setInterval(() => {
            if (this.socket && this.socket.connected) {
                this.socket.emit('ping', {
                    timestamp: Date.now(),
                    latency: this.stats.latency
                });
            }
        }, 1000);
    }
    
    setupStabilityMonitoring() {
        // Connection stability monitoring
        this.connectionHealthTimer = setInterval(() => {
            this.checkConnectionHealth();
        }, 5000);
        
        // Performance monitoring
        this.performanceTimer = setInterval(() => {
            this.logPerformanceMetrics();
        }, 30000);
        
        // Auto-reconnect setup
        this.setupAutoReconnect();
        
        console.log('✅ Stability monitoring enabled');
    }
    
    checkConnectionHealth() {
        if (!this.socket || !this.socket.connected) {
            console.warn('⚠️ WebSocket not connected, attempting reconnect...');
            this.reconnectToServer();
            return;
        }
        
        // Check if we're receiving data
        const now = Date.now();
        if (this.lastDataReceived && (now - this.lastDataReceived) > 10000) {
            console.warn('⚠️ No data received for 10 seconds, connection may be stale');
            this.reconnectToServer();
        }
    }
    
    setupAutoReconnect() {
        // Exponential backoff for reconnection
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 10;
    }
    
    reconnectToServer() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            console.error('❌ Max reconnection attempts reached');
            this.updateConnectionStatus('disconnected', '再接続失敗');
            return;
        }
        
        this.reconnectAttempts++;
        const backoffTime = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
        
        console.log(`🔄 Reconnection attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts} in ${backoffTime}ms`);
        
        setTimeout(() => {
            if (this.socket) {
                this.socket.disconnect();
            }
            this.connectToServer();
        }, backoffTime);
    }
    
    logPerformanceMetrics() {
        const metrics = {
            packetsReceived: this.stats.packetsReceived,
            averageLatency: this.stats.latency,
            uptime: Date.now() - (this.startTime || Date.now()),
            connectionAttempts: this.reconnectAttempts,
            audioEngineHealth: this.audioEngine ? this.audioEngine.calculateHealthScore() : 0
        };
        
        console.log('📊 Performance metrics:', metrics);
        
        // Store metrics for diagnostics
        this.performanceHistory = this.performanceHistory || [];
        this.performanceHistory.push({
            timestamp: Date.now(),
            ...metrics
        });
        
        // Keep only last 100 entries
        if (this.performanceHistory.length > 100) {
            this.performanceHistory = this.performanceHistory.slice(-100);
        }
    }
    
    cleanup() {
        console.log('🧹 Cleaning up HiAudio client...');
        
        // Clear timers
        if (this.connectionHealthTimer) {
            clearInterval(this.connectionHealthTimer);
        }
        if (this.performanceTimer) {
            clearInterval(this.performanceTimer);
        }
        
        // Cleanup audio engine
        if (this.audioEngine) {
            this.audioEngine.cleanup();
        }
        
        // Disconnect socket
        if (this.socket) {
            this.socket.disconnect();
        }
        
        console.log('✅ Client cleanup completed');
    }
    
    async playTestSound() {
        try {
            console.log('🎵 Playing test sound...');
            
            // Initialize audio engine if needed
            if (!this.audioEngine) {
                this.audioEngine = new AudioEngine();
                await this.audioEngine.initialize();
            }
            
            // Start audio context
            await this.audioEngine.start();
            
            // Generate and play a test tone (1000Hz for 1 second)
            this.generateTestTone(1000, 1.0, 0.3);
            
            console.log('✅ Test sound generated and playing');
            
        } catch (error) {
            console.error('❌ Test sound failed:', error);
            alert('テストサウンドの再生に失敗しました: ' + error.message);
        }
    }
    
    generateTestTone(frequency, duration, volume) {
        if (!this.audioEngine || !this.audioEngine.audioContext) return;
        
        const audioContext = this.audioEngine.audioContext;
        const sampleRate = audioContext.sampleRate;
        const frameCount = Math.round(duration * sampleRate);
        
        // Create audio buffer
        const buffer = audioContext.createBuffer(2, frameCount, sampleRate);
        
        // Generate stereo sine wave
        for (let channel = 0; channel < 2; channel++) {
            const channelData = buffer.getChannelData(channel);
            for (let frame = 0; frame < frameCount; frame++) {
                const time = frame / sampleRate;
                channelData[frame] = Math.sin(2 * Math.PI * frequency * time) * volume;
            }
        }
        
        // Create buffer source and play
        const source = audioContext.createBufferSource();
        source.buffer = buffer;
        source.connect(this.audioEngine.gainNode);
        source.start();
        
        // Update visualizations with test data
        this.updateTestVisualizations(frequency);
    }
    
    updateTestVisualizations(frequency) {
        // Generate fake spectrum data for test visualization
        const testSpectrum = new Array(64).fill(0);
        const freqBin = Math.floor((frequency / 22050) * 32); // Map frequency to bin
        testSpectrum[freqBin] = 0.8; // Peak at test frequency
        testSpectrum[freqBin + 1] = 0.4;
        testSpectrum[freqBin - 1] = 0.4;
        
        // Update spectrum bars
        const bars = document.querySelectorAll('.spectrum-bar');
        bars.forEach((bar, index) => {
            const value = testSpectrum[index] || 0;
            const height = Math.max(2, value * 130);
            bar.style.height = `${height}px`;
        });
        
        // Generate test waveform
        const testWaveform = new Array(128);
        for (let i = 0; i < 128; i++) {
            testWaveform[i] = Math.sin((i / 128) * 2 * Math.PI * 8) * 0.5; // 8 cycles
        }
        this.drawWaveform(testWaveform);
    }
}

// Initialize the application when page loads
document.addEventListener('DOMContentLoaded', () => {
    console.log('🎵 HiAudio Pro Web Client initializing...');
    window.hiAudioClient = new HiAudioWebClient();
});

// Global function for control button
function toggleAudio() {
    if (window.hiAudioClient) {
        window.hiAudioClient.toggleAudio();
    }
}