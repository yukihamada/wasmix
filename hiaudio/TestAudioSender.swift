#!/usr/bin/env swift

// 🎵 Simple UDP Audio Sender - Send test audio to web client
import Foundation
import Network

print("🎵 Test Audio Sender - Sending 1000Hz tone via UDP")

class TestAudioSender {
    private let connection: NWConnection
    private var isRunning = false
    
    init() {
        let host = NWEndpoint.Host("localhost")
        let port = NWEndpoint.Port(rawValue: 55556)!
        
        connection = NWConnection(host: host, port: port, using: .udp)
        
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("✅ UDP connection ready")
                self.startSendingAudio()
            case .failed(let error):
                print("❌ UDP connection failed: \(error)")
            default:
                break
            }
        }
    }
    
    func start() {
        print("🚀 Starting UDP audio sender...")
        connection.start(queue: .main)
        
        // Keep running
        RunLoop.main.run()
    }
    
    private func startSendingAudio() {
        isRunning = true
        sendAudioPackets()
    }
    
    private func sendAudioPackets() {
        guard isRunning else { return }
        
        // Generate 1000Hz sine wave (128 frames, stereo)
        let frameCount = 128
        let frequency = 1000.0
        let sampleRate = 48000.0
        var audioData: [Float32] = []
        
        let startTime = Date().timeIntervalSince1970
        
        for frame in 0..<frameCount {
            let time = (Double(frame) / sampleRate) + (startTime * frequency / sampleRate)
            let sample = Float32(sin(2.0 * .pi * frequency * time) * 0.3)
            
            // Stereo: L, R, L, R...
            audioData.append(sample)
            audioData.append(sample)
        }
        
        // Create UDP packet with header
        let header = "HIAUDIO_DATA"
        let headerData = header.data(using: .utf8)!
        let audioBytes = audioData.withUnsafeBytes { Data($0) }
        
        var packet = Data()
        packet.append(headerData)
        packet.append(audioBytes)
        
        // Send packet
        connection.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Send error: \(error)")
            }
        })
        
        // Schedule next packet (128 frames @ 48kHz = ~2.67ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
            self.sendAudioPackets()
        }
    }
    
    func stop() {
        isRunning = false
        connection.cancel()
        print("🛑 Audio sender stopped")
    }
}

// Signal handler for clean shutdown
signal(SIGINT) { _ in
    print("\n🛑 Stopping audio sender...")
    exit(0)
}

// Run the sender
let sender = TestAudioSender()
sender.start()