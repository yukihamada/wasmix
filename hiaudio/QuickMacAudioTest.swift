#!/usr/bin/env swift

// 🎤 Quick Mac Audio Test - 音を鳴らすだけ
import AVFoundation
import Foundation

print("🎤 Quick Mac Audio Test - 音を鳴らします")

// シンプルに音を生成して再生
let audioEngine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()
let mixer = audioEngine.mainMixerNode

// オーディオエンジンに接続
audioEngine.attach(playerNode)
audioEngine.connect(playerNode, to: mixer, format: mixer.outputFormat(forBus: 0))

// テスト音生成 (1000Hz サイン波)
func generateTestSound(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
    let sampleRate = 44100.0
    let frameCount = AVAudioFrameCount(duration * sampleRate)
    
    guard let buffer = AVAudioPCMBuffer(
        pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!,
        frameCapacity: frameCount
    ) else { return nil }
    
    buffer.frameLength = frameCount
    
    let channelCount = Int(buffer.format.channelCount)
    for channel in 0..<channelCount {
        let samples = buffer.floatChannelData![channel]
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let sample = Float(sin(2.0 * .pi * frequency * time) * 0.3)  // 30% volume
            samples[frame] = sample
        }
    }
    
    return buffer
}

do {
    // エンジン開始
    try audioEngine.start()
    print("✅ Audio engine started")
    
    // テスト音生成
    if let testBuffer = generateTestSound(frequency: 1000.0, duration: 2.0) {
        print("🎵 Playing 1000Hz test tone for 2 seconds...")
        
        playerNode.scheduleBuffer(testBuffer, at: nil) {
            print("🎵 Test sound finished!")
        }
        
        playerNode.play()
        
        // 再生完了まで待機
        Thread.sleep(forTimeInterval: 3.0)
        
        print("✅ Test completed successfully!")
    } else {
        print("❌ Failed to generate test sound")
    }
    
    audioEngine.stop()
    
} catch {
    print("❌ Audio engine error: \(error.localizedDescription)")
}

print("🎉 Mac audio test finished")