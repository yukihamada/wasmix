#!/usr/bin/env swift
import Foundation
import Network

print("🔍 Testing connection to physical iPhone at 172.20.10.1:55555...")

// UDPでテストパケットを送信
let connection = NWConnection(
    host: "172.20.10.1",
    port: 55555,
    using: .udp
)

connection.stateUpdateHandler = { state in
    print("📡 Connection state: \(state)")
    
    switch state {
    case .ready:
        print("✅ Connected to iPhone!")
        
        // テストデータ送信
        let testData = "HELLO_FROM_MAC".data(using: .utf8)!
        connection.send(content: testData, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Send error: \(error)")
            } else {
                print("✅ Test packet sent successfully!")
            }
            connection.cancel()
            exit(0)
        })
        
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

connection.start(queue: .global())

// タイムアウト
DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
    print("⏰ Timeout - cancelling connection")
    connection.cancel()
    exit(1)
}

// メインループを維持
RunLoop.main.run()