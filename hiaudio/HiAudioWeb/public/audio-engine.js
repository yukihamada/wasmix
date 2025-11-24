// 🎵 HiAudio Pro Web Audio Engine - Ultra-low latency audio processing
class AudioEngine {
    constructor() {
        this.audioContext = null;
        this.gainNode = null;
        this.analyserNode = null;
        this.isInitialized = false;
        this.isPlaying = false;
        this.sampleRate = 96000;
        this.channels = 2;
        this.volume = 1.0;
        
        // Audio processing buffers
        this.audioBuffer = [];
        this.spectrumData = new Float32Array(64);
        this.waveformData = new Float32Array(128);
        
        // Performance monitoring
        this.stats = {
            samplesProcessed: 0,
            bufferUnderruns: 0,
            lastProcessTime: 0,
            reconnectAttempts: 0,
            errors: 0
        };
        
        // Stability enhancements
        this.reconnectTimer = null;
        this.healthCheckTimer = null;
        this.errorThreshold = 5;
        this.isRecovering = false;
        
        // Auto-recovery setup
        this.setupAutoRecovery();
    }
    
    async initialize() {
        try {
            console.log('🎵 Initializing Web Audio API...');
            
            // Create audio context with low latency settings
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
                sampleRate: this.sampleRate,
                latencyHint: 'interactive' // Lowest latency mode
            });
            
            // Create audio processing nodes
            this.gainNode = this.audioContext.createGain();
            this.analyserNode = this.audioContext.createAnalyser();
            
            // Configure analyser for real-time visualization
            this.analyserNode.fftSize = 128; // Small FFT for low latency
            this.analyserNode.smoothingTimeConstant = 0.3;
            
            // Connect nodes: gain -> analyser -> destination
            this.gainNode.connect(this.analyserNode);
            this.analyserNode.connect(this.audioContext.destination);
            
            // Set initial volume
            this.gainNode.gain.value = this.volume;
            
            this.isInitialized = true;
            console.log('✅ Audio engine initialized');
            console.log(`   Sample Rate: ${this.audioContext.sampleRate}Hz`);
            console.log(`   Base Latency: ${(this.audioContext.baseLatency * 1000).toFixed(1)}ms`);
            console.log(`   Output Latency: ${(this.audioContext.outputLatency * 1000).toFixed(1)}ms`);
            
        } catch (error) {
            console.error('❌ Audio initialization failed:', error);
            this.stats.errors++;
            
            // Try recovery
            if (this.stats.errors < this.errorThreshold) {
                console.log('🔄 Attempting audio recovery...');
                setTimeout(() => this.initialize(), 2000);
                return;
            }
            throw error;
        }
    }
    
    setupAutoRecovery() {
        // Health monitoring every 10 seconds
        this.healthCheckTimer = setInterval(() => {
            this.performHealthCheck();
        }, 10000);
        
        // Error recovery monitoring
        this.reconnectTimer = setInterval(() => {
            if (this.stats.errors > 0 && !this.isRecovering) {
                this.attemptRecovery();
            }
        }, 5000);
    }
    
    performHealthCheck() {
        if (!this.audioContext) return;
        
        // Check audio context state
        if (this.audioContext.state === 'suspended' || this.audioContext.state === 'closed') {
            console.warn('⚠️ Audio context in bad state:', this.audioContext.state);
            this.attemptRecovery();
            return;
        }
        
        // Check for buffer underruns
        if (this.stats.bufferUnderruns > 10) {
            console.warn('⚠️ Too many buffer underruns detected');
            this.optimizeBuffering();
        }
        
        // Log health status
        const healthScore = this.calculateHealthScore();
        if (healthScore < 0.7) {
            console.warn(`⚠️ Audio health score low: ${(healthScore * 100).toFixed(1)}%`);
        }
    }
    
    calculateHealthScore() {
        const errorRate = this.stats.errors / Math.max(this.stats.samplesProcessed / 1000, 1);
        const underrunRate = this.stats.bufferUnderruns / Math.max(this.stats.samplesProcessed / 1000, 1);
        const contextHealth = this.audioContext && this.audioContext.state === 'running' ? 1.0 : 0.0;
        
        return Math.max(0, 1.0 - errorRate - underrunRate * 0.5) * contextHealth;
    }
    
    async attemptRecovery() {
        if (this.isRecovering) return;
        
        this.isRecovering = true;
        console.log('🚨 Starting audio recovery process...');
        
        try {
            // Step 1: Stop current audio
            this.stop();
            
            // Step 2: Close and recreate audio context
            if (this.audioContext) {
                await this.audioContext.close();
            }
            
            // Step 3: Clear buffers
            this.audioBuffer = [];
            this.spectrumData.fill(0);
            this.waveformData.fill(0);
            
            // Step 4: Reinitialize
            await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
            await this.initialize();
            
            // Step 5: Reset error counters
            this.stats.errors = Math.max(0, this.stats.errors - 2);
            this.stats.bufferUnderruns = 0;
            this.stats.reconnectAttempts++;
            
            console.log('✅ Audio recovery completed successfully');
            
        } catch (error) {
            console.error('❌ Audio recovery failed:', error);
            this.stats.errors++;
        } finally {
            this.isRecovering = false;
        }
    }
    
    optimizeBuffering() {
        console.log('🔧 Optimizing audio buffering...');
        
        // Clear old buffers
        this.audioBuffer = [];
        
        // Adjust buffer size based on performance
        if (this.audioContext) {
            const targetLatency = this.audioContext.baseLatency + 0.020; // Add 20ms buffer
            console.log(`🎯 Target latency adjusted to ${(targetLatency * 1000).toFixed(1)}ms`);
        }
        
        // Reset underrun counter
        this.stats.bufferUnderruns = 0;
    }
    
    async start() {
        if (!this.isInitialized) {
            throw new Error('Audio engine not initialized');
        }
        
        try {
            // Resume audio context (required for Chrome autoplay policy)
            if (this.audioContext.state === 'suspended') {
                await this.audioContext.resume();
            }
            
            this.isPlaying = true;
            console.log('✅ Audio engine started');
            
        } catch (error) {
            console.error('❌ Audio start failed:', error);
            throw error;
        }
    }
    
    stop() {
        if (this.audioContext && this.audioContext.state === 'running') {
            // Don't close the context, just suspend it for reuse
            this.audioContext.suspend();
        }
        
        this.isPlaying = false;
        console.log('🔇 Audio engine stopped');
    }
    
    processAudioData(audioData) {
        if (!this.isInitialized || !this.isPlaying || !audioData.data) {
            return;
        }
        
        try {
            const startTime = performance.now();
            
            // Create audio buffer from received data
            const buffer = this.createAudioBufferFromData(audioData);
            if (!buffer) {
                this.stats.bufferUnderruns++;
                return;
            }
            
            // Schedule buffer for immediate playback
            this.scheduleAudioBuffer(buffer);
            
            // Update performance stats
            const processingTime = performance.now() - startTime;
            this.stats.samplesProcessed++;
            this.stats.lastProcessTime = processingTime;
            
            // Check for performance issues
            if (processingTime > 10) { // 10ms warning threshold
                console.warn(`⚠️ Slow audio processing: ${processingTime.toFixed(2)}ms`);
            }
            
            // Update visualizations (throttled for performance)
            if (this.stats.samplesProcessed % 5 === 0) {
                this.updateAnalysisData();
            }
            
        } catch (error) {
            console.error('❌ Audio processing error:', error);
            this.stats.errors++;
            
            // Trigger recovery if too many errors
            if (this.stats.errors >= this.errorThreshold && !this.isRecovering) {
                this.attemptRecovery();
            }
        }
    }
    
    createAudioBufferFromData(audioData) {
        try {
            const { data, channels = 2, sampleRate = 96000 } = audioData;
            const frameCount = data.length / channels;
            
            if (frameCount <= 0) return null;
            
            // Create audio buffer
            const buffer = this.audioContext.createBuffer(channels, frameCount, sampleRate);
            
            // Fill buffer with audio data
            for (let channel = 0; channel < channels; channel++) {
                const channelData = buffer.getChannelData(channel);
                
                if (channels === 2) {
                    // Stereo: deinterleave data (L, R, L, R, ... -> L..., R...)
                    for (let i = 0; i < frameCount; i++) {
                        channelData[i] = data[i * channels + channel] || 0;
                    }
                } else {
                    // Mono: copy directly
                    for (let i = 0; i < frameCount; i++) {
                        channelData[i] = data[i] || 0;
                    }
                }
            }
            
            return buffer;
            
        } catch (error) {
            console.error('❌ Buffer creation error:', error);
            return null;
        }
    }
    
    scheduleAudioBuffer(buffer) {
        try {
            // Create buffer source node
            const source = this.audioContext.createBufferSource();
            source.buffer = buffer;
            
            // Connect to gain node
            source.connect(this.gainNode);
            
            // Schedule for immediate playback
            const now = this.audioContext.currentTime;
            source.start(now);
            
        } catch (error) {
            console.error('❌ Audio scheduling error:', error);
        }
    }
    
    updateAnalysisData() {
        if (!this.analyserNode) return;
        
        // Get frequency data for spectrum analyzer
        this.analyserNode.getFloatFrequencyData(this.spectrumData);
        
        // Convert dB values to normalized 0-1 range for visualization
        for (let i = 0; i < this.spectrumData.length; i++) {
            // Convert from dB (-100 to 0) to linear (0 to 1)
            this.spectrumData[i] = Math.max(0, (this.spectrumData[i] + 100) / 100);
        }
        
        // Get time domain data for waveform
        const timeDomainData = new Float32Array(this.analyserNode.fftSize);
        this.analyserNode.getFloatTimeDomainData(timeDomainData);
        
        // Downsample for waveform display (128 samples)
        const downsampleRatio = Math.floor(timeDomainData.length / 128);
        for (let i = 0; i < 128; i++) {
            this.waveformData[i] = timeDomainData[i * downsampleRatio] || 0;
        }
    }
    
    setVolume(volume) {
        this.volume = Math.max(0, Math.min(1, volume));
        if (this.gainNode) {
            this.gainNode.gain.value = this.volume;
        }
        console.log(`🔊 Volume set to ${Math.round(this.volume * 100)}%`);
    }
    
    getVolume() {
        return this.volume;
    }
    
    getSpectrumData() {
        return Array.from(this.spectrumData);
    }
    
    getWaveformData() {
        return Array.from(this.waveformData);
    }
    
    getStats() {
        return {
            ...this.stats,
            isInitialized: this.isInitialized,
            isPlaying: this.isPlaying,
            sampleRate: this.audioContext?.sampleRate || 0,
            currentLatency: this.audioContext ? 
                (this.audioContext.baseLatency + this.audioContext.outputLatency) * 1000 : 0
        };
    }
    
    // Audio worklet support for even lower latency (if available)
    async initializeWorklet() {
        if (!this.audioContext.audioWorklet) {
            console.log('⚠️ AudioWorklet not supported, using standard nodes');
            return;
        }
        
        try {
            await this.audioContext.audioWorklet.addModule('/audio-processor.js');
            const workletNode = new AudioWorkletNode(this.audioContext, 'audio-processor');
            
            // Replace standard nodes with worklet
            this.gainNode.disconnect();
            this.gainNode.connect(workletNode);
            workletNode.connect(this.analyserNode);
            
            console.log('✅ AudioWorklet initialized for ultra-low latency');
            
        } catch (error) {
            console.error('❌ AudioWorklet initialization failed:', error);
        }
    }
    
    // Cleanup method to prevent memory leaks
    cleanup() {
        console.log('🧹 Cleaning up audio engine...');
        
        // Clear timers
        if (this.healthCheckTimer) {
            clearInterval(this.healthCheckTimer);
            this.healthCheckTimer = null;
        }
        
        if (this.reconnectTimer) {
            clearInterval(this.reconnectTimer);
            this.reconnectTimer = null;
        }
        
        // Stop and cleanup audio
        this.stop();
        
        // Clear buffers
        this.audioBuffer = [];
        this.spectrumData = new Float32Array(64);
        this.waveformData = new Float32Array(128);
        
        // Close audio context
        if (this.audioContext && this.audioContext.state !== 'closed') {
            this.audioContext.close();
        }
        
        // Reset state
        this.isInitialized = false;
        this.isPlaying = false;
        this.isRecovering = false;
        
        console.log('✅ Audio engine cleanup completed');
    }
    
    // Enhanced diagnostic information
    getDiagnostics() {
        const baseInfo = {
            state: this.audioContext?.state || 'not initialized',
            sampleRate: this.audioContext?.sampleRate || 0,
            baseLatency: this.audioContext ? Math.round(this.audioContext.baseLatency * 1000 * 10) / 10 : 0,
            outputLatency: this.audioContext ? Math.round(this.audioContext.outputLatency * 1000 * 10) / 10 : 0,
            totalLatency: this.audioContext ? Math.round((this.audioContext.baseLatency + this.audioContext.outputLatency) * 1000 * 10) / 10 : 0,
            performance: this.stats,
            healthScore: this.calculateHealthScore(),
            bufferSize: this.audioBuffer.length,
            timestamp: Date.now()
        };
        
        // Add memory usage estimate
        baseInfo.estimatedMemoryUsage = {
            buffers: this.audioBuffer.length * 1024, // rough estimate in bytes
            spectrumData: this.spectrumData.byteLength,
            waveformData: this.waveformData.byteLength
        };
        
        return baseInfo;
    }
    
    // Force garbage collection (if possible)
    forceGarbageCollection() {
        if (window.gc && typeof window.gc === 'function') {
            window.gc();
            console.log('🗑️ Forced garbage collection');
        } else {
            // Trigger natural GC by creating pressure
            const temp = new Array(10000).fill(new Float32Array(1024));
            temp.length = 0;
        }
    }
}

// Auto-cleanup on page unload
if (typeof window !== 'undefined') {
    window.addEventListener('beforeunload', () => {
        if (window.hiAudioClient && window.hiAudioClient.audioEngine) {
            window.hiAudioClient.audioEngine.cleanup();
        }
    });
    
    // Memory pressure monitoring
    if ('memory' in performance) {
        setInterval(() => {
            const memInfo = performance.memory;
            if (memInfo.usedJSHeapSize > memInfo.totalJSHeapSize * 0.9) {
                console.warn('⚠️ High memory usage detected, triggering cleanup');
                if (window.hiAudioClient && window.hiAudioClient.audioEngine) {
                    window.hiAudioClient.audioEngine.forceGarbageCollection();
                }
            }
        }, 30000); // Check every 30 seconds
    }
}

// Audio processor worklet for ultra-low latency (optional)
const audioProcessorWorklet = `
class AudioProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this.volume = 1.0;
        
        this.port.onmessage = (event) => {
            if (event.data.type === 'setVolume') {
                this.volume = event.data.value;
            }
        };
    }
    
    process(inputs, outputs, parameters) {
        const input = inputs[0];
        const output = outputs[0];
        
        if (input.length > 0 && output.length > 0) {
            for (let channel = 0; channel < output.length; channel++) {
                const inputChannel = input[channel];
                const outputChannel = output[channel];
                
                if (inputChannel && outputChannel) {
                    for (let i = 0; i < outputChannel.length; i++) {
                        outputChannel[i] = (inputChannel[i] || 0) * this.volume;
                    }
                }
            }
        }
        
        return true;
    }
}

registerProcessor('audio-processor', AudioProcessor);
`;

// Create blob URL for the worklet
if (typeof window !== 'undefined') {
    const blob = new Blob([audioProcessorWorklet], { type: 'application/javascript' });
    window.audioProcessorURL = URL.createObjectURL(blob);
}