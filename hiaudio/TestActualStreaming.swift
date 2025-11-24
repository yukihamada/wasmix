#!/usr/bin/env swift
import Foundation
import Network

print("🎵 Testing actual audio streaming to physical iPhone...")

// 実際のオーディオパケットサイズをシミュレート (128フレーム = 1,040 bytes)
let audioData = Data(repeating: 0x42, count: 1040)
var packetsSent = 0

let connection = NWConnection(
    host: "172.20.10.1",
    port: 55555,
    using: .udp
)

connection.stateUpdateHandler = { state in
    print("📡 Connection: \(state)")
    
    switch state {
    case .ready:
        print("✅ Ready to stream to iPhone!")
        sendAudioPackets()
        
    case .failed(let error):
        print("❌ Failed: \(error)")
        exit(1)
        
    default:
        break
    }
}

func sendAudioPackets() {
    Timer.scheduledTimer(withTimeInterval: 0.0133, repeats: true) { timer in // ~75fps for low latency
        packetsSent += 1
        
        connection.send(content: audioData, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Packet \(packetsSent) failed: \(error)")
            } else if packetsSent <= 5 || packetsSent % 75 == 0 {
                print("✅ Packet \(packetsSent) sent (\(audioData.count) bytes)")
            }
        })
        
        // 5秒後に終了
        if packetsSent >= 375 { // 5 seconds @ 75 fps
            timer.invalidate()
            print("🏁 Streaming test complete - sent \(packetsSent) packets")
            connection.cancel()
            exit(0)
        }
    }
}

connection.start(queue: .global())

// メインループ
RunLoop.main.run()