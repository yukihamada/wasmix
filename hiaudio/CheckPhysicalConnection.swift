#!/usr/bin/env swift
import Foundation
import Network

print("🔍 Testing final connection to physical iPhone...")

// 物理iPhone に直接接続テスト
let connection = NWConnection(
    host: "172.20.10.1", 
    port: 55555,
    using: .udp
)

var testPacketsSent = 0

connection.stateUpdateHandler = { state in
    print("📡 Connection state: \(state)")
    
    switch state {
    case .ready:
        print("✅ Connected to physical iPhone!")
        sendTestPackets()
        
    case .failed(let error):
        print("❌ Connection failed: \(error)")
        exit(1)
        
    case .cancelled:
        print("🚫 Connection cancelled")
        exit(0)
        
    default:
        break
    }
}

func sendTestPackets() {
    // 数個のテストパケットを送信
    for i in 1...5 {
        let testMessage = "TEST_PACKET_\(i)_FROM_MAC"
        guard let testData = testMessage.data(using: .utf8) else { continue }
        
        connection.send(content: testData, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Packet \(i) failed: \(error)")
            } else {
                print("✅ Packet \(i) sent successfully!")
            }
            
            testPacketsSent += 1
            if testPacketsSent >= 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🏁 Test complete!")
                    connection.cancel()
                    exit(0)
                }
            }
        })
        
        Thread.sleep(forTimeInterval: 0.2) // 200ms間隔
    }
}

connection.start(queue: .global())

// タイムアウト
DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
    print("⏰ Timeout - test failed")
    connection.cancel()
    exit(1)
}

RunLoop.main.run()