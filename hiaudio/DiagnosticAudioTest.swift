#!/usr/bin/env swift

// 🔍 HiAudio Diagnostic Test - Audio Input Verification
// Check if audio input is working and what levels we're getting

import Foundation
import AVFoundation

print("🔍 HiAudio Diagnostic Test - Audio Input Verification")
print("=" * 60)

class AudioInputDiagnostic {
    private var audioEngine = AVAudioEngine()
    private var isRunning = false
    private var sampleCount = 0
    private var peakLevel: Float = 0.0
    private var rmsLevel: Float = 0.0
    
    func runDiagnostic() {
        print("🎤 Checking audio input capabilities...")
        checkAudioPermissions()
        checkAudioDevices()
        setupAudioDiagnostic()
    }
    
    private func checkAudioPermissions() {
        print("\n📋 Audio Permission Status:")
        
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            print("❓ Status: UNDETERMINED - requesting permission...")
            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    print("✅ Permission GRANTED")
                    self.continueSetup()
                } else {
                    print("❌ Permission DENIED")
                }
            }
            return
            
        case .denied:
            print("❌ Status: DENIED - Please enable microphone access in System Settings")
            print("   Go to: System Settings > Privacy & Security > Microphone")
            return
            
        case .granted:
            print("✅ Status: GRANTED")
            
        @unknown default:
            print("⚠️ Status: UNKNOWN")
        }
        
        continueSetup()
    }
    
    private func checkAudioDevices() {
        print("\n🎙️ Available Audio Input Devices:")
        
        // Get default input device
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        print("   Default Input Device:")
        print("     Sample Rate: \(Int(inputFormat.sampleRate))Hz")
        print("     Channels: \(inputFormat.channelCount)")
        print("     Format: \(inputFormat.commonFormat)")
        print("     Interleaved: \(inputFormat.isInterleaved)")
        
        // Check if we have any input
        if inputFormat.channelCount == 0 {
            print("❌ ERROR: No audio input channels available!")
            return
        }
        
        if inputFormat.sampleRate == 0 {
            print("❌ ERROR: Invalid sample rate!")
            return
        }
        
        print("✅ Audio input device looks good")
    }
    
    private func continueSetup() {
        setupAudioDiagnostic()
    }
    
    private func setupAudioDiagnostic() {
        print("\n🔧 Setting up audio input monitoring...")
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // Create a tap to monitor audio levels
        let bufferSize: UInt32 = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] (buffer, time) in
            self?.analyzeAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            isRunning = true
            print("✅ Audio engine started - monitoring input levels...")
            print("\n🎵 Audio Level Monitor:")
            print("   Speak into your microphone to see levels")
            print("   Press Ctrl+C to stop")
            
            // Start monitoring loop
            startMonitoring()
            
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    private func analyzeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        var peak: Float = 0.0
        var sum: Float = 0.0
        
        for i in 0..<frameCount {
            let sample = abs(channelData[i])
            peak = max(peak, sample)
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameCount))
        
        // Update levels
        peakLevel = peak
        rmsLevel = rms
        sampleCount += frameCount
    }
    
    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            
            let peakDB = self.peakLevel > 0 ? 20 * log10(self.peakLevel) : -80.0
            let rmsDB = self.rmsLevel > 0 ? 20 * log10(self.rmsLevel) : -80.0
            
            // Visual level meter
            let meterLength = 40
            let peakMeter = Int(max(0, (peakDB + 60) / 60 * Float(meterLength)))
            let rmsMeter = Int(max(0, (rmsDB + 60) / 60 * Float(meterLength)))
            
            let peakBar = String(repeating: "█", count: min(peakMeter, meterLength))
            let rmsBar = String(repeating: "▓", count: min(rmsMeter, meterLength))
            
            print("\r🎤 Peak: \(String(format: "%5.1f", peakDB))dB [\(peakBar.padding(toLength: meterLength, withPad: " ", startingAt: 0))]", terminator: "")
            print("  RMS: \(String(format: "%5.1f", rmsDB))dB [\(rmsBar.padding(toLength: meterLength, withPad: " ", startingAt: 0))]", terminator: "")
            
            // Status indicators
            if peakDB > -40 {
                print(" 🔊", terminator: "")
            } else if peakDB > -60 {
                print(" 🔉", terminator: "")
            } else {
                print(" 🔇", terminator: "")
            }
            
            fflush(stdout)
        }
        
        RunLoop.current.run()
    }
    
    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRunning = false
        print("\n\n🛑 Audio diagnostic stopped")
        print("📊 Final Stats:")
        print("   Total samples processed: \(sampleCount)")
        print("   Final peak level: \(String(format: "%.1f", peakLevel > 0 ? 20 * log10(peakLevel) : -80.0))dB")
        print("   Final RMS level: \(String(format: "%.1f", rmsLevel > 0 ? 20 * log10(rmsLevel) : -80.0))dB")
    }
}

// Signal handler for clean shutdown
let diagnostic = AudioInputDiagnostic()

signal(SIGINT) { _ in
    print("\n\n🛑 Stopping diagnostic...")
    diagnostic.stop()
    exit(0)
}

diagnostic.runDiagnostic()

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}