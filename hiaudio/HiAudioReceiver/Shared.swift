import Foundation

// Bonjour service configuration for automatic discovery
struct HiAudioService {
    static let serviceType = "_hiaudio._udp."
    static let serviceName = "HiAudio Receiver"
    static let udpPort: UInt16 = 55555
}

struct AudioPacket {
    let id: UInt64
    let payload: Data // PCM Float32
    let timestamp: CFAbsoluteTime // 送信時刻
    
    func serialize() -> Data {
        var data = Data()
        var i = id
        var t = timestamp
        data.append(Data(bytes: &i, count: 8))
        data.append(Data(bytes: &t, count: 8))
        data.append(payload)
        return data
    }
    
    static func deserialize(_ data: Data) -> AudioPacket? {
        guard data.count > 16 else { return nil }
        let id = data.subdata(in: 0..<8).withUnsafeBytes { $0.load(as: UInt64.self) }
        let timestamp = data.subdata(in: 8..<16).withUnsafeBytes { $0.load(as: CFAbsoluteTime.self) }
        let payload = data.subdata(in: 16..<data.count)
        return AudioPacket(id: id, payload: payload, timestamp: timestamp)
    }
}