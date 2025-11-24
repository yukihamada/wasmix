#!/usr/bin/env swift
import Foundation
import Network

print("🎵 Sending actual HiAudio packets to physical iPhone...")

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

// 正しい音声データを生成 (48kHz stereo, 128 frames = 1024 bytes)
func createRealAudioData() -> Data {
    let frameCount = 128
    let frequency: Float = 440.0 // A音 (440Hz)
    let sampleRate: Float = 48000.0
    var audioData = Data()
    
    for frame in 0..<frameCount {
        let time = Float(frame) / sampleRate
        let leftSample = sin(2.0 * Float.pi * frequency * time) * 0.5 // 50%音量
        let rightSample = sin(2.0 * Float.pi * frequency * time * 1.2) * 0.5 // 少し高い音
        
        // ステレオインターリーブ (L, R, L, R...)
        withUnsafeBytes(of: leftSample) { bytes in
            audioData.append(contentsOf: bytes)
        }
        withUnsafeBytes(of: rightSample) { bytes in
            audioData.append(contentsOf: bytes)
        }
    }
    
    return audioData
}

let connection = NWConnection(host: "172.20.10.1", port: 55555, using: .udp)
var packetsToSend = 75 * 5 // 5秒分 (75fps)
var packetsSent = 0

connection.stateUpdateHandler = { state in
    print("📡 Connection: \(state)")
    
    switch state {
    case .ready:
        print("✅ Ready to send audio packets!")
        startSending()
        
    case .failed(let error):
        print("❌ Failed: \(error)")
        exit(1)
        
    default:
        break
    }
}

func startSending() {
    let audioData = createRealAudioData()
    print("🔊 Created audio data: \(audioData.count) bytes (should be 1024)")
    
    // 75fps送信 (13.33ms間隔)
    Timer.scheduledTimer(withTimeInterval: 1.0/75.0, repeats: true) { timer in
        packetsSent += 1
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        let packet = AudioPacket(
            id: UInt64(packetsSent), 
            payload: audioData, 
            timestamp: timestamp
        )
        
        let serialized = packet.serialize()
        
        connection.send(content: serialized, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Packet \(packetsSent) failed: \(error)")
            } else if packetsSent <= 10 || packetsSent % 37 == 0 {
                print("✅ Audio packet \(packetsSent)/\(packetsToSend) sent (\(serialized.count) bytes total, \(audioData.count) audio)")
            }
        })
        
        if packetsSent >= packetsToSend {
            timer.invalidate()
            print("🏁 Audio streaming test complete! Sent \(packetsSent) packets")
            print("📱 Check iPhone app logs for 'play() called' messages")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                connection.cancel()
                exit(0)
            }
        }
    }
}

connection.start(queue: .global())

DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
    print("⏰ Test timeout")
    connection.cancel()
    exit(1)
}

RunLoop.main.run()