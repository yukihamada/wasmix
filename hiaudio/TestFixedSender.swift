#!/usr/bin/env swift

// 🧪 Test Fixed HiAudio Sender - Verify UDP packet transmission works
// Simple UDP receiver to test if the fixed buffer sizes work

import Foundation
import Network

print("🧪 Testing Fixed HiAudio Sender - UDP Packet Reception Test")
print("=" * 60)

class UDPPacketReceiver {
    private var listener: NWListener?
    private var receivedPackets = 0
    private var lastPacketTime: Date?
    private var totalBytesReceived: Int = 0
    private var packetSizes: [Int] = []
    
    func startListening() {
        print("🎧 Starting UDP receiver on port 55555...")
        
        do {
            let params = NWParameters.udp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: 55555)!)
            
            listener?.newConnectionHandler = { connection in
                self.handleConnection(connection)
            }
            
            listener?.start(queue: DispatchQueue.global())
            print("✅ UDP receiver listening on port 55555")
            
        } catch {
            print("❌ Failed to start UDP listener: \(error)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        print("📡 New connection from: \(connection.endpoint)")
        connection.start(queue: DispatchQueue.global())
        
        func receiveNext() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, isComplete, error in
                if let data = data, !data.isEmpty {
                    self.processReceivedPacket(data)
                }
                
                if let error = error {
                    print("📡 Receive error: \(error)")
                }
                
                if !isComplete {
                    receiveNext()
                }
            }
        }
        
        receiveNext()
    }
    
    private func processReceivedPacket(_ data: Data) {
        receivedPackets += 1
        totalBytesReceived += data.count
        packetSizes.append(data.count)
        
        let currentTime = Date()
        if let lastTime = lastPacketTime {
            let interval = currentTime.timeIntervalSince(lastTime) * 1000 // ms
            
            // Show packet info every 50 packets to avoid spam
            if receivedPackets % 50 == 0 {
                let avgSize = packetSizes.reduce(0, +) / packetSizes.count
                let minSize = packetSizes.min() ?? 0
                let maxSize = packetSizes.max() ?? 0
                let packetsPerSec = 1000.0 / interval * 50.0 // Approximate rate
                
                print("📦 Packet #\(receivedPackets): \(data.count) bytes")
                print("   📊 Stats: Avg \(avgSize), Min \(minSize), Max \(maxSize) bytes")
                print("   📈 Rate: ~\(String(format: "%.0f", packetsPerSec)) packets/sec")
                print("   📐 Total: \(totalBytesReceived) bytes received")
                
                // Check if packet sizes are within UDP MTU limits
                if maxSize > 1472 {
                    print("   ⚠️ WARNING: Packets exceeding MTU limit detected!")
                } else {
                    print("   ✅ All packets within MTU limit")
                }
                print()
            }
        }
        
        lastPacketTime = currentTime
        
        // Show first few packets for debugging
        if receivedPackets <= 5 {
            print("📦 Packet #\(receivedPackets): \(data.count) bytes")
            
            // Try to parse as HiAudio AudioPacket
            if data.count >= 16 {
                let id = data[0..<8].withUnsafeBytes { $0.load(as: UInt64.self) }
                let timestamp = data[8..<16].withUnsafeBytes { $0.load(as: Double.self) }
                let audioDataSize = data.count - 16
                print("   Packet ID: \(id)")
                print("   Timestamp: \(timestamp)")
                print("   Audio data: \(audioDataSize) bytes")
                
                // Calculate audio parameters from payload size
                let frames = audioDataSize / 8 // 2 channels * 4 bytes per sample
                print("   Audio frames: \(frames)")
                
                if frames == 128 {
                    print("   ✅ Correct buffer size (128 frames)")
                } else if frames == 512 {
                    print("   ⚠️ Old buffer size detected (512 frames)")
                } else {
                    print("   ❓ Unexpected buffer size (\(frames) frames)")
                }
            }
            print()
        }
    }
    
    func printSummary() {
        print("\n📊 Test Summary:")
        print("   Total packets received: \(receivedPackets)")
        print("   Total bytes received: \(totalBytesReceived)")
        
        if !packetSizes.isEmpty {
            let avgSize = packetSizes.reduce(0, +) / packetSizes.count
            let minSize = packetSizes.min()!
            let maxSize = packetSizes.max()!
            
            print("   Packet sizes: Min \(minSize), Avg \(avgSize), Max \(maxSize) bytes")
            
            if maxSize <= 1472 {
                print("   ✅ All packets within UDP MTU limit (1472 bytes)")
            } else {
                print("   ❌ Some packets exceed UDP MTU limit")
            }
        }
    }
}

let receiver = UDPPacketReceiver()

// Signal handler for clean shutdown
signal(SIGINT) { _ in
    print("\n\n🛑 Stopping packet reception test...")
    receiver.printSummary()
    exit(0)
}

receiver.startListening()

print("🎵 Waiting for packets from HiAudio Sender...")
print("💡 Make sure HiAudio Sender is running and started streaming")
print("⏹️ Press Ctrl+C to stop and see results")

RunLoop.current.run()

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}