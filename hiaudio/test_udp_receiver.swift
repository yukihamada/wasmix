#!/usr/bin/env swift
import Foundation
import Network

print("🔍 Testing UDP receiver on port 55555...")

let listener = try! NWListener(using: .udp, on: 55555)

listener.stateUpdateHandler = { state in
    print("📡 Listener state: \(state)")
}

listener.newConnectionHandler = { connection in
    print("📦 New connection: \(connection)")
    
    connection.start(queue: .global())
    
    func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data {
                print("📥 Received \(data.count) bytes: \(String(data: data, encoding: .utf8) ?? "binary data")")
            }
            if let error = error {
                print("❌ Receive error: \(error)")
            }
            if !isComplete {
                receive()
            }
        }
    }
    receive()
}

listener.start(queue: .global())
print("✅ UDP listener started on port 55555")

// Keep running
RunLoop.main.run()