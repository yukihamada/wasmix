#!/usr/bin/env swift

// 🎤 Simple Mac Microphone Audio Test
// Macのマイクだけで音を鳴らすシンプルテスト

import Foundation
import AVFoundation
import CoreAudio

print("🎤 Simple Mac Microphone Audio Test")
print("=" * 40)

class SimpleMacAudioTest {
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputNode: AVAudioOutputNode?
    private var isRunning = false
    
    func startSimpleAudioTest() {
        print("🚀 Starting simple Mac microphone test...")
        
        // Setup audio engine
        setupAudioEngine()
        
        // Start audio processing
        startAudioProcessing()
        
        print("🎵 Audio test running... Speak into microphone!")
        print("💡 You should hear your voice with a slight delay")
        print("⏹️ Press Ctrl+C to stop")
        
        // Keep running
        RunLoop.current.run()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        inputNode = engine.inputNode
        outputNode = engine.outputNode
        
        guard let input = inputNode, let output = outputNode else {
            print("❌ Failed to get audio nodes")
            return
        }
        
        // Get input format
        let inputFormat = input.outputFormat(forBus: 0)
        print("🎤 Input: \(inputFormat.channelCount)ch @ \(Int(inputFormat.sampleRate))Hz")
        
        // Create output format matching input
        guard let outputFormat = AVAudioFormat(
            commonFormat: inputFormat.commonFormat,
            sampleRate: inputFormat.sampleRate,
            channels: min(inputFormat.channelCount, 2),
            interleaved: inputFormat.isInterleaved
        ) else {
            print("❌ Failed to create output format")
            return
        }
        
        print("🔊 Output: \(outputFormat.channelCount)ch @ \(Int(outputFormat.sampleRate))Hz")
        
        // Connect input directly to output (with volume control)
        let mixer = engine.mainMixerNode
        engine.connect(input, to: mixer, format: inputFormat)
        
        // Add volume control to prevent feedback
        mixer.outputVolume = 0.3  // Reduce volume to 30%
        
        print("✅ Audio engine configured")
    }
    
    private func startAudioProcessing() {
        guard let engine = audioEngine else { return }
        
        do {
            // Request microphone permission
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined:
                print("🔐 Requesting microphone permission...")
                AVAudioApplication.requestRecordPermission { granted in
                    if granted {
                        print("✅ Microphone permission granted")
                        self.actuallyStartEngine()
                    } else {
                        print("❌ Microphone permission denied")
                    }
                }
                return
                
            case .denied:
                print("❌ Microphone permission denied. Please enable in System Settings.")
                return
                
            case .granted:
                print("✅ Microphone permission already granted")
                break
                
            @unknown default:
                print("⚠️ Unknown permission status")
                break
            }
            
            actuallyStartEngine()
            
        } catch {
            print("❌ Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func actuallyStartEngine() {
        guard let engine = audioEngine else { return }
        
        do {
            try engine.start()
            isRunning = true
            print("🎵 Audio engine started successfully!")
            print("🎤 Speak into your microphone - you should hear yourself!")
            
        } catch {
            print("❌ Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        audioEngine?.stop()
        isRunning = false
        print("🛑 Audio engine stopped")
    }
}

// Signal handler for clean shutdown
signal(SIGINT) { _ in
    print("\n🛑 Stopping audio test...")
    exit(0)
}

// Run the test
let audioTest = SimpleMacAudioTest()
audioTest.startSimpleAudioTest()

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}