#!/usr/bin/env swift

// 🔍 HiAudio Sender Test - Verify Audio Capture and Network Sending
// Test the actual HiAudio sender functionality

import Foundation
import AVFoundation
import Network

print("🔍 HiAudio Sender Audio Capture and Network Test")
print("=" * 60)

// Minimal implementation of OrpheusProtocol for testing
struct AudioPacket {
    let id: UInt64
    let payload: Data
    let timestamp: Double
    
    func serialize() -> Data {
        var data = Data()
        withUnsafeBytes(of: id.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: payload.count.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: timestamp.bitPattern.bigEndian) { data.append(contentsOf: $0) }
        data.append(payload)
        return data
    }
}

class HiAudioSenderTest {
    private var audioEngine = AVAudioEngine()
    private var isRunning = false
    private var packetID: UInt64 = 0
    private var connection: NWConnection?
    
    // Test configuration
    private let testHost = "::1" // IPv6 localhost
    private let testPort: UInt16 = 12345
    private let bufferSize: UInt32 = 512
    
    func runTest() {
        print("🎤 Testing HiAudio Sender Audio Capture and Network Transmission...")
        
        checkAudioPermissions()
        setupTestReceiver()
        setupAudioCapture()
        startTest()
    }
    
    private func checkAudioPermissions() {
        print("\n📋 Checking Audio Permissions:")
        
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            print("✅ Microphone permission granted")
        case .denied:
            print("❌ Microphone permission denied")
            return
        case .undetermined:
            print("❓ Requesting microphone permission...")
            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    print("✅ Permission granted")
                } else {
                    print("❌ Permission denied")
                }
            }
            return
        @unknown default:
            print("⚠️ Unknown permission status")
        }
    }
    
    private func setupTestReceiver() {
        print("\n🌐 Setting up test UDP receiver...")
        
        // Create UDP listener to verify packets are being sent
        let params = NWParameters.udp
        let listener = try! NWListener(using: params, on: NWEndpoint.Port(rawValue: testPort)!)
        
        listener.newConnectionHandler = { (connection: NWConnection) in
            print("📡 Test receiver: New connection from \(connection.endpoint)")
            self.handleTestConnection(connection)
        }
        
        listener.start(queue: DispatchQueue.global())
        print("✅ Test UDP receiver listening on port \(testPort)")
    }
    
    private func handleTestConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue.global())
        
        func receiveNext() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let data = data, !data.isEmpty {
                    print("📦 Received packet: \(data.count) bytes")
                    
                    // Parse packet
                    if data.count >= 24 { // Minimum packet size
                        let id = data[0..<8].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
                        let payloadSize = data[8..<16].withUnsafeBytes { $0.load(as: Int.self).bigEndian }
                        let timestamp = data[16..<24].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
                        print("   Packet ID: \(id), Payload size: \(payloadSize), Timestamp: \(timestamp)")
                    }
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
    
    private func setupAudioCapture() {
        print("\n🎵 Setting up audio capture...")
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        print("🎤 Input format: \(inputFormat.channelCount)ch @ \(Int(inputFormat.sampleRate))Hz")
        
        // Create audio format for processing
        let format = AVAudioFormat(standardFormatWithSampleRate: inputFormat.sampleRate, channels: min(inputFormat.channelCount, 2))!
        
        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer)
        }
        
        print("✅ Audio capture setup complete")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Analyze audio levels
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        var peak: Float = 0.0
        var rms: Float = 0.0
        
        for i in 0..<frameCount {
            let sample = abs(channelData[i])
            peak = max(peak, sample)
            rms += sample * sample
        }
        
        rms = sqrt(rms / Float(frameCount))
        
        let peakDB = peak > 0 ? 20 * log10(peak) : -80.0
        let rmsDB = rms > 0 ? 20 * log10(rms) : -80.0
        
        // Create audio packet (similar to BestSender)
        let audioData = createAudioPacketData(from: buffer)
        packetID += 1
        
        let packet = AudioPacket(
            id: packetID,
            payload: audioData,
            timestamp: CFAbsoluteTimeGetCurrent()
        )
        
        // Send packet
        sendAudioPacket(packet)
        
        // Log audio levels and packet info every second (approximately)
        if packetID % 90 == 0 { // Roughly every second at 48kHz/512 buffer
            print("🎵 Audio: Peak \(String(format: "%.1f", peakDB))dB, RMS \(String(format: "%.1f", rmsDB))dB | Packet #\(packetID) (\(audioData.count) bytes)")
        }
    }
    
    private func createAudioPacketData(from buffer: AVAudioPCMBuffer) -> Data {
        let channels = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        var audioData = Data()
        
        if channels == 2 {
            // Stereo interleaved
            guard let leftChannel = buffer.floatChannelData?[0],
                  let rightChannel = buffer.floatChannelData?[1] else { return Data() }
            
            for frame in 0..<frameCount {
                withUnsafeBytes(of: leftChannel[frame]) { bytes in
                    audioData.append(contentsOf: bytes)
                }
                withUnsafeBytes(of: rightChannel[frame]) { bytes in
                    audioData.append(contentsOf: bytes)
                }
            }
        } else {
            // Mono
            guard let channelData = buffer.floatChannelData?[0] else { return Data() }
            audioData = Data(bytes: channelData, count: frameCount * 4)
        }
        
        return audioData
    }
    
    private func sendAudioPacket(_ packet: AudioPacket) {
        if connection == nil {
            setupNetworkConnection()
        }
        
        guard let conn = connection, conn.state == .ready else {
            if packetID % 90 == 0 {
                print("⚠️ Network connection not ready, skipping packet")
            }
            return
        }
        
        let serializedPacket = packet.serialize()
        
        conn.send(content: serializedPacket, completion: .contentProcessed { error in
            if let error = error {
                print("📡 Send error: \(error)")
            }
        })
    }
    
    private func setupNetworkConnection() {
        print("\n🌐 Setting up network connection to test receiver...")
        
        let host = NWEndpoint.Host(testHost)
        let port = NWEndpoint.Port(rawValue: testPort)!
        let params = NWParameters.udp
        params.serviceClass = .interactiveVoice
        
        connection = NWConnection(host: host, port: port, using: params)
        
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Network connection ready")
            case .failed(let error):
                print("❌ Network connection failed: \(error)")
            case .cancelled:
                print("🚫 Network connection cancelled")
            default:
                print("🔄 Network connection state: \(state)")
            }
        }
        
        connection?.start(queue: DispatchQueue.global())
    }
    
    private func startTest() {
        print("\n🚀 Starting HiAudio sender test...")
        
        do {
            try audioEngine.start()
            isRunning = true
            print("✅ Audio engine started successfully!")
            print("🎤 Speak into your microphone to generate audio packets")
            print("📡 Packets will be sent to \(testHost):\(testPort)")
            print("⏹️ Press Ctrl+C to stop")
            
            RunLoop.current.run()
            
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        connection?.cancel()
        isRunning = false
        print("\n🛑 HiAudio sender test stopped")
        print("📊 Total packets sent: \(packetID)")
    }
}

// Signal handler for clean shutdown
let test = HiAudioSenderTest()

signal(SIGINT) { _ in
    print("\n\n🛑 Stopping test...")
    test.stop()
    exit(0)
}

test.runTest()

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}