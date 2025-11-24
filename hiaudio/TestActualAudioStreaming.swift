#!/usr/bin/env swift
import Foundation
import Network
import AVFoundation

print("🎵 Testing actual audio streaming to physical iPhone...")

// 実際のAudioPacket形式でテストデータを作成
struct AudioPacket {
    let id: UInt64
    let payload: Data
    let timestamp: CFAbsoluteTime
    
    func serialize() -> Data {
        var data = Data()
        var i = id
        var t = timestamp
        data.append(Data(bytes: &i, count: 8))
        data.append(Data(bytes: &t, count: 8))
        data.append(payload)
        return data
    }
}

// 48kHz stereo で128フレーム (1,024 bytes) のテスト音声データ作成
func createTestAudioData() -> Data {
    let frameCount = 128
    let frequency: Float = 440.0 // A音
    let sampleRate: Float = 48000
    var audioData = Data()
    
    for frame in 0..<frameCount {
        let time = Float(frame) / sampleRate
        let sample = sin(2.0 * Float.pi * frequency * time) * 0.3 // 音量30%
        
        // ステレオ (L, R, L, R...)
        for _ in 0..<2 {
            let sampleBytes = withUnsafeBytes(of: sample) { $0 }
            audioData.append(contentsOf: sampleBytes)
        }
    }
    
    return audioData
}

let connection = NWConnection(host: "172.20.10.1", port: 55555, using: .udp)
var packetsToSend = 100 // 約1.3秒分
var packetsSent = 0

connection.stateUpdateHandler = { state in
    print("📡 Connection: \(state)")
    
    switch state {
    case .ready:
        print("✅ Ready to stream!")
        startAudioStreaming()
        
    case .failed(let error):
        print("❌ Failed: \(error)")
        exit(1)
        
    default:
        break
    }
}

func startAudioStreaming() {
    let audioData = createTestAudioData()
    print("🔊 Created test audio: \(audioData.count) bytes")
    
    // 75fps送信 (Mac HiAudioSender相当)
    Timer.scheduledTimer(withTimeInterval: 1.0/75.0, repeats: true) { timer in
        packetsSent += 1
        let timestamp = CFAbsoluteTimeGetCurrent()
        let packet = AudioPacket(id: UInt64(packetsSent), payload: audioData, timestamp: timestamp)
        let serializedPacket = packet.serialize()
        
        connection.send(content: serializedPacket, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Packet \(packetsSent) failed: \(error)")
            } else if packetsSent <= 10 || packetsSent % 25 == 0 {
                print("✅ Audio packet \(packetsSent)/\(packetsToSend) sent (\(serializedPacket.count) bytes)")
            }
        })
        
        if packetsSent >= packetsToSend {
            timer.invalidate()
            print("🏁 Audio streaming test complete!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                connection.cancel()
                exit(0)
            }
        }
    }
}

connection.start(queue: .global())

// タイムアウト
DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
    print("⏰ Timeout")
    connection.cancel()
    exit(1)
}

RunLoop.main.run()