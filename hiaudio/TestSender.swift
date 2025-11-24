#!/usr/bin/env swift

import Foundation
import AVFoundation
import Network

print("🎵 HiAudio Mac Sender テスト - 起動中...")

// Basic audio engine test
let engine = AVAudioEngine()
let inputNode = engine.inputNode

print("✅ オーディオエンジン初期化完了")

// Test UDP connection to iPhone
print("📱 iPhone接続テスト中...")

func testConnection() {
    let params = NWParameters.udp
    let host = NWEndpoint.Host("Yuki's iPhone.local")
    let port = NWEndpoint.Port(integerLiteral: 55555)
    
    let connection = NWConnection(host: host, port: port, using: params)
    
    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            print("✅ iPhone接続成功！")
            connection.cancel()
        case .failed(let error):
            print("❌ iPhone接続失敗: \(error)")
            connection.cancel()
        default:
            print("🔄 接続状態: \(state)")
        }
    }
    
    connection.start(queue: DispatchQueue.global())
}

testConnection()

// Keep running for a few seconds
RunLoop.main.run(until: Date().addingTimeInterval(5))

print("🎵 テスト完了")