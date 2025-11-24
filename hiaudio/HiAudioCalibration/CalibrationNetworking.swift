// 🌐 HiAudio Pro - Reliable Calibration Networking
// macOS-iOS間の確実な通信システム

import Foundation
import Network
import os.log

// MARK: - Reliable Calibration Networking
@MainActor
class CalibrationNetworking: ObservableObject {
    
    // MARK: - Published Properties
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var connectedDevices: [NetworkDevice] = []
    @Published var networkQuality: NetworkQuality = NetworkQuality()
    @Published var lastError: NetworkError?
    
    // MARK: - Core Components
    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]
    private var messageHandler: CalibrationMessageHandler?
    
    // Configuration
    private let serverPort: UInt16 = 55557  // キャリブレーション専用ポート
    private let connectionTimeout: TimeInterval = 10.0
    private let heartbeatInterval: TimeInterval = 2.0
    private let maxRetries = 3
    
    // State Management
    private var heartbeatTimer: Timer?
    private var discoveryTimer: Timer?
    private var messageQueue: [QueuedMessage] = []
    private var isProcessingQueue = false
    
    // Logging
    private let logger = OSLog(subsystem: "com.hiaudio.calibration", category: "networking")
    
    // MARK: - Data Structures
    enum ConnectionStatus {
        case disconnected
        case listening
        case connected(Int) // デバイス数
        case error(NetworkError)
        
        var description: String {
            switch self {
            case .disconnected: return "未接続"
            case .listening: return "待機中"
            case .connected(let count): return "接続済み (\(count)台)"
            case .error(let error): return "エラー: \(error.localizedDescription)"
            }
        }
    }
    
    enum NetworkError: Error, LocalizedError {
        case listenerStartFailed(Error)
        case connectionFailed(String)
        case messageEncodingFailed(Error)
        case messageDecodingFailed(Error)
        case sendTimeout
        case deviceNotFound(String)
        case networkUnavailable
        
        var errorDescription: String? {
            switch self {
            case .listenerStartFailed(let error):
                return "サーバー開始失敗: \(error.localizedDescription)"
            case .connectionFailed(let deviceId):
                return "デバイス接続失敗: \(deviceId)"
            case .messageEncodingFailed(let error):
                return "メッセージ送信エラー: \(error.localizedDescription)"
            case .messageDecodingFailed(let error):
                return "メッセージ受信エラー: \(error.localizedDescription)"
            case .sendTimeout:
                return "送信タイムアウト"
            case .deviceNotFound(let id):
                return "デバイスが見つかりません: \(id)"
            case .networkUnavailable:
                return "ネットワークが利用できません"
            }
        }
    }
    
    struct NetworkDevice: Identifiable, Equatable {
        let id: String
        let name: String
        let type: DeviceType
        let ipAddress: String
        let capabilities: DeviceCapabilities
        var connectionQuality: ConnectionQuality
        var lastSeen: Date
        
        enum DeviceType: String, Codable {
            case iOS = "iOS"
            case macOS = "macOS"
            case web = "Web"
        }
        
        struct DeviceCapabilities: Codable {
            let sampleRates: [Double]
            let channelCount: Int
            let hasHardwareTimer: Bool
            let supportsLowLatency: Bool
        }
        
        struct ConnectionQuality {
            var latency: Double = 0.0      // ms
            var jitter: Double = 0.0       // ms
            var packetLoss: Float = 0.0    // %
            var signalStrength: Float = 1.0 // 0-1
            
            var isGoodQuality: Bool {
                return latency < 50.0 && jitter < 10.0 && packetLoss < 1.0
            }
            
            var qualityLevel: String {
                if latency < 20.0 && jitter < 5.0 && packetLoss < 0.5 {
                    return "優秀"
                } else if latency < 50.0 && jitter < 10.0 && packetLoss < 1.0 {
                    return "良好"
                } else if latency < 100.0 && jitter < 20.0 && packetLoss < 5.0 {
                    return "可"
                } else {
                    return "不良"
                }
            }
        }
        
        static func == (lhs: NetworkDevice, rhs: NetworkDevice) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct NetworkQuality {
        var overallLatency: Double = 0.0
        var averageJitter: Double = 0.0
        var worstPacketLoss: Float = 0.0
        var activeConnections: Int = 0
        
        var overallScore: Float {
            let latencyScore = Float(max(0.0, 1.0 - overallLatency / 100.0))
            let jitterScore = Float(max(0.0, 1.0 - averageJitter / 20.0))
            let lossScore = max(0.0, 1.0 - worstPacketLoss / 5.0)
            
            return (latencyScore + jitterScore + lossScore) / 3.0
        }
    }
    
    struct QueuedMessage {
        let id: String
        let targetDevice: String
        let message: CalibrationMessage
        let timestamp: Date
        var retryCount: Int = 0
        
        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > 30.0 // 30秒タイムアウト
        }
    }
    
    // MARK: - Calibration Messages
    enum CalibrationMessage: Codable {
        // デバイス登録・発見
        case deviceRegistration(DeviceRegistrationInfo)
        case deviceDiscovery
        case deviceList([NetworkDevice])
        
        // キャリブレーション制御
        case startCalibration(CalibrationConfig)
        case stopCalibration
        case calibrationReady(deviceId: String)
        
        // 音声データ交換
        case audioTestSignal(AudioData)
        case audioRecording(AudioData)
        case audioConfirmation(received: Bool)
        
        // 結果・ステータス
        case calibrationResult(CalibrationResultData)
        case statusUpdate(DeviceStatus)
        case error(String)
        
        // ネットワーク管理
        case heartbeat(timestamp: TimeInterval)
        case heartbeatResponse(timestamp: TimeInterval)
        case goodbye
        
        struct DeviceRegistrationInfo: Codable {
            let deviceId: String
            let deviceName: String
            let deviceType: NetworkDevice.DeviceType
            let capabilities: NetworkDevice.DeviceCapabilities
            let timestamp: TimeInterval
        }
        
        struct CalibrationConfig: Codable {
            let sessionId: String
            let sampleRate: Double
            let signalDuration: Double
            let testFrequency: Double
            let expectedDevices: [String]
        }
        
        struct AudioData: Codable {
            let sessionId: String
            let deviceId: String
            let sampleRate: Double
            let channelCount: Int
            let samples: [Float]
            let timestamp: TimeInterval
        }
        
        struct CalibrationResultData: Codable {
            let deviceId: String
            let sessionId: String
            let measuredDelay: Double
            let confidence: Float
            let signalToNoise: Float
            let qualityScore: Float
            let timestamp: TimeInterval
        }
        
        struct DeviceStatus: Codable {
            let deviceId: String
            let status: String
            let progress: Float
            let message: String
            let timestamp: TimeInterval
        }
    }
    
    // MARK: - Server Methods (macOS側)
    func startServer() async throws {
        guard connectionStatus != .listening else {
            os_log("Server already running", log: logger, type: .info)
            return
        }
        
        os_log("🚀 Starting calibration server on port %d", log: logger, type: .info, serverPort)
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.allowFastOpen = true
        
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: serverPort))
        } catch {
            lastError = .listenerStartFailed(error)
            connectionStatus = .error(.listenerStartFailed(error))
            throw error
        }
        
        guard let listener = listener else {
            throw NetworkError.listenerStartFailed(NSError(domain: "CalibrationNetworking", code: -1))
        }
        
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                await self?.handleListenerStateChange(state)
            }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleNewConnection(connection)
            }
        }
        
        listener.start(queue: .main)
        connectionStatus = .listening
        
        // ハートビート開始
        startHeartbeat()
        
        os_log("✅ Calibration server started successfully", log: logger, type: .info)
    }
    
    func stopServer() {
        os_log("🛑 Stopping calibration server", log: logger, type: .info)
        
        // すべての接続を閉じる
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
        
        // リスナー停止
        listener?.cancel()
        listener = nil
        
        // タイマー停止
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        
        // 状態リセット
        connectionStatus = .disconnected
        connectedDevices.removeAll()
        messageQueue.removeAll()
        
        os_log("✅ Calibration server stopped", log: logger, type: .info)
    }
    
    // MARK: - Client Methods (iOS側)
    func connectToServer(host: String, port: UInt16? = nil) async throws {
        let targetPort = port ?? serverPort
        os_log("🔌 Connecting to server %@ on port %d", log: logger, type: .info, host, targetPort)
        
        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: targetPort)
        let endpoint = NWEndpoint.hostPort(host: hostEndpoint, port: portEndpoint)
        
        let parameters = NWParameters.tcp
        parameters.allowFastOpen = true
        
        let connection = NWConnection(to: endpoint, using: parameters)
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            connection.stateUpdateHandler = { state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        if !hasResumed {
                            hasResumed = true
                            
                            // 接続を登録
                            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                            self.connections[deviceId] = connection
                            
                            // デバイス登録メッセージ送信
                            Task {
                                try? await self.sendDeviceRegistration(connection: connection)
                            }
                            
                            // 受信開始
                            self.startReceiving(connection: connection, deviceId: deviceId)
                            
                            continuation.resume()
                        }
                        
                    case .failed(let error):
                        if !hasResumed {
                            hasResumed = true
                            self.lastError = .connectionFailed(host)
                            continuation.resume(throwing: NetworkError.connectionFailed(host))
                        }
                        
                    case .cancelled:
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(throwing: NetworkError.connectionFailed("Connection cancelled"))
                        }
                        
                    default:
                        break
                    }
                }
            }
            
            connection.start(queue: .main)
            
            // タイムアウト処理
            DispatchQueue.main.asyncAfter(deadline: .now() + connectionTimeout) {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(throwing: NetworkError.sendTimeout)
                }
            }
        }
    }
    
    // MARK: - Message Handling
    func sendMessage(_ message: CalibrationMessage, to deviceId: String) async throws {
        guard let connection = connections[deviceId] else {
            throw NetworkError.deviceNotFound(deviceId)
        }
        
        try await sendMessage(message, connection: connection)
    }
    
    private func sendMessage(_ message: CalibrationMessage, connection: NWConnection) async throws {
        do {
            let data = try JSONEncoder().encode(message)
            let lengthData = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }
            
            // 長さ情報 + メッセージデータ
            var fullData = lengthData
            fullData.append(data)
            
            return try await withCheckedThrowingContinuation { continuation in
                var hasResumed = false
                
                connection.send(content: fullData, completion: .contentProcessed({ error in
                    if !hasResumed {
                        hasResumed = true
                        if let error = error {
                            continuation.resume(throwing: NetworkError.messageEncodingFailed(error))
                        } else {
                            continuation.resume()
                        }
                    }
                }))
                
                // タイムアウト
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: NetworkError.sendTimeout)
                    }
                }
            }
            
        } catch is EncodingError {
            throw NetworkError.messageEncodingFailed(error)
        }
    }
    
    private func startReceiving(connection: NWConnection, deviceId: String) {
        // メッセージ長を受信
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            if let error = error {
                os_log("❌ Receive error: %@", log: self?.logger ?? OSLog.default, type: .error, error.localizedDescription)
                return
            }
            
            guard let data = data, data.count == 4 else {
                self?.startReceiving(connection: connection, deviceId: deviceId) // 再開
                return
            }
            
            let messageLength = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            // メッセージ本体を受信
            connection.receive(minimumIncompleteLength: Int(messageLength), maximumLength: Int(messageLength)) { messageData, _, _, error in
                if let error = error {
                    os_log("❌ Message receive error: %@", log: self?.logger ?? OSLog.default, type: .error, error.localizedDescription)
                    return
                }
                
                if let messageData = messageData {
                    Task {
                        await self?.handleReceivedMessage(messageData, from: deviceId)
                    }
                }
                
                // 次のメッセージを待機
                self?.startReceiving(connection: connection, deviceId: deviceId)
            }
        }
    }
    
    private func handleReceivedMessage(_ data: Data, from deviceId: String) async {
        do {
            let message = try JSONDecoder().decode(CalibrationMessage.self, from: data)
            await processMessage(message, from: deviceId)
        } catch {
            os_log("❌ Message decode error: %@", log: logger, type: .error, error.localizedDescription)
            lastError = .messageDecodingFailed(error)
        }
    }
    
    private func processMessage(_ message: CalibrationMessage, from deviceId: String) async {
        switch message {
        case .deviceRegistration(let info):
            await handleDeviceRegistration(info, deviceId: deviceId)
            
        case .heartbeat(let timestamp):
            // ハートビート応答
            let response = CalibrationMessage.heartbeatResponse(timestamp: Date().timeIntervalSince1970)
            try? await sendMessage(response, to: deviceId)
            
        case .heartbeatResponse(let timestamp):
            await updateConnectionQuality(deviceId: deviceId, requestTime: timestamp)
            
        case .calibrationReady:
            os_log("📱 Device %@ is ready for calibration", log: logger, type: .info, deviceId)
            
        case .audioRecording(let audioData):
            await handleAudioRecording(audioData, from: deviceId)
            
        case .calibrationResult(let result):
            await handleCalibrationResult(result, from: deviceId)
            
        case .statusUpdate(let status):
            await handleStatusUpdate(status, from: deviceId)
            
        case .error(let errorMessage):
            os_log("❌ Device %@ reported error: %@", log: logger, type: .error, deviceId, errorMessage)
            
        case .goodbye:
            await handleDeviceDisconnection(deviceId)
            
        default:
            os_log("📨 Received unhandled message from %@", log: logger, type: .debug, deviceId)
        }
    }
    
    // MARK: - Event Handlers
    private func handleListenerStateChange(_ state: NWListener.State) async {
        switch state {
        case .ready:
            connectionStatus = .listening
            os_log("✅ Listener ready", log: logger, type: .info)
            
        case .failed(let error):
            lastError = .listenerStartFailed(error)
            connectionStatus = .error(.listenerStartFailed(error))
            os_log("❌ Listener failed: %@", log: logger, type: .error, error.localizedDescription)
            
        case .cancelled:
            connectionStatus = .disconnected
            os_log("🛑 Listener cancelled", log: logger, type: .info)
            
        default:
            break
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) async {
        let deviceId = UUID().uuidString // 一時的なID
        connections[deviceId] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleConnectionStateChange(state, deviceId: deviceId)
            }
        }
        
        connection.start(queue: .main)
        startReceiving(connection: connection, deviceId: deviceId)
        
        os_log("🔌 New connection from device: %@", log: logger, type: .info, deviceId)
    }
    
    private func handleConnectionStateChange(_ state: NWConnection.State, deviceId: String) async {
        switch state {
        case .ready:
            os_log("✅ Connection ready: %@", log: logger, type: .debug, deviceId)
            
        case .failed(let error):
            os_log("❌ Connection failed: %@ - %@", log: logger, type: .error, deviceId, error.localizedDescription)
            await handleDeviceDisconnection(deviceId)
            
        case .cancelled:
            os_log("🛑 Connection cancelled: %@", log: logger, type: .debug, deviceId)
            await handleDeviceDisconnection(deviceId)
            
        default:
            break
        }
    }
    
    private func handleDeviceRegistration(_ info: CalibrationMessage.DeviceRegistrationInfo, deviceId: String) async {
        let device = NetworkDevice(
            id: info.deviceId,
            name: info.deviceName,
            type: info.deviceType,
            ipAddress: "unknown", // TODO: 実際のIPアドレス取得
            capabilities: info.capabilities,
            connectionQuality: NetworkDevice.ConnectionQuality(),
            lastSeen: Date()
        )
        
        // デバイスリスト更新
        if let index = connectedDevices.firstIndex(where: { $0.id == device.id }) {
            connectedDevices[index] = device
        } else {
            connectedDevices.append(device)
        }
        
        // 接続状態更新
        connectionStatus = .connected(connectedDevices.count)
        
        os_log("📱 Device registered: %@ (%@)", log: logger, type: .info, device.name, device.type.rawValue)
    }
    
    private func handleDeviceDisconnection(_ deviceId: String) async {
        connections.removeValue(forKey: deviceId)
        connectedDevices.removeAll { $0.id == deviceId }
        
        let remainingCount = connectedDevices.count
        connectionStatus = remainingCount > 0 ? .connected(remainingCount) : .listening
        
        os_log("👋 Device disconnected: %@", log: logger, type: .info, deviceId)
    }
    
    private func updateConnectionQuality(deviceId: String, requestTime: TimeInterval) async {
        let responseTime = Date().timeIntervalSince1970
        let latency = (responseTime - requestTime) * 1000.0 // ms
        
        if let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) {
            connectedDevices[index].connectionQuality.latency = latency
            connectedDevices[index].lastSeen = Date()
        }
    }
    
    private func handleAudioRecording(_ audioData: CalibrationMessage.AudioData, from deviceId: String) async {
        os_log("🎵 Received audio recording from %@: %d samples", log: logger, type: .debug, deviceId, audioData.samples.count)
        // CalibrationEngineに転送
        NotificationCenter.default.post(name: .audioRecordingReceived, object: audioData)
    }
    
    private func handleCalibrationResult(_ result: CalibrationMessage.CalibrationResultData, from deviceId: String) async {
        os_log("📊 Received calibration result from %@: %.3fms delay", log: logger, type: .info, deviceId, result.measuredDelay)
        // 結果処理
        NotificationCenter.default.post(name: .calibrationResultReceived, object: result)
    }
    
    private func handleStatusUpdate(_ status: CalibrationMessage.DeviceStatus, from deviceId: String) async {
        os_log("📱 Status update from %@: %@ (%.1f%%)", log: logger, type: .debug, deviceId, status.status, status.progress * 100)
        // ステータス更新処理
    }
    
    // MARK: - Utility Methods
    private func sendDeviceRegistration(connection: NWConnection) async throws {
        #if os(iOS)
        let deviceType = NetworkDevice.DeviceType.iOS
        let deviceName = UIDevice.current.name
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #elseif os(macOS)
        let deviceType = NetworkDevice.DeviceType.macOS
        let deviceName = Host.current().localizedName ?? "macOS Device"
        let deviceId = UUID().uuidString
        #endif
        
        let capabilities = NetworkDevice.DeviceCapabilities(
            sampleRates: [44100.0, 48000.0],
            channelCount: 2,
            hasHardwareTimer: true,
            supportsLowLatency: true
        )
        
        let registrationInfo = CalibrationMessage.DeviceRegistrationInfo(
            deviceId: deviceId,
            deviceName: deviceName,
            deviceType: deviceType,
            capabilities: capabilities,
            timestamp: Date().timeIntervalSince1970
        )
        
        let message = CalibrationMessage.deviceRegistration(registrationInfo)
        try await sendMessage(message, connection: connection)
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.sendHeartbeats()
            }
        }
    }
    
    private func sendHeartbeats() async {
        let timestamp = Date().timeIntervalSince1970
        let heartbeat = CalibrationMessage.heartbeat(timestamp: timestamp)
        
        for deviceId in connections.keys {
            try? await sendMessage(heartbeat, to: deviceId)
        }
        
        // ネットワーク品質更新
        await updateNetworkQuality()
    }
    
    private func updateNetworkQuality() async {
        let latencies = connectedDevices.map { $0.connectionQuality.latency }
        let jitters = connectedDevices.map { $0.connectionQuality.jitter }
        let packetLosses = connectedDevices.map { $0.connectionQuality.packetLoss }
        
        networkQuality.overallLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        networkQuality.averageJitter = jitters.isEmpty ? 0 : jitters.reduce(0, +) / Double(jitters.count)
        networkQuality.worstPacketLoss = packetLosses.max() ?? 0
        networkQuality.activeConnections = connectedDevices.count
    }
    
    // MARK: - Device Discovery
    func startDeviceDiscovery() {
        os_log("🔍 Starting device discovery", log: logger, type: .info)
        
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.broadcastDiscovery()
            }
        }
    }
    
    func stopDeviceDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        os_log("🛑 Stopped device discovery", log: logger, type: .info)
    }
    
    private func broadcastDiscovery() async {
        let discovery = CalibrationMessage.deviceDiscovery
        
        for deviceId in connections.keys {
            try? await sendMessage(discovery, to: deviceId)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let audioRecordingReceived = Notification.Name("audioRecordingReceived")
    static let calibrationResultReceived = Notification.Name("calibrationResultReceived")
    static let deviceConnected = Notification.Name("deviceConnected")
    static let deviceDisconnected = Notification.Name("deviceDisconnected")
}

// MARK: - Utility Extensions
extension CalibrationNetworking {
    
    /// 接続品質レポート生成
    func generateConnectionReport() -> String {
        let totalDevices = connectedDevices.count
        let goodQualityDevices = connectedDevices.filter { $0.connectionQuality.isGoodQuality }.count
        
        var report = """
        🌐 ネットワーク接続レポート
        
        📊 接続統計:
           総デバイス数: \(totalDevices)
           良好品質デバイス: \(goodQualityDevices)/\(totalDevices)
           平均遅延: \(String(format: "%.1f", networkQuality.overallLatency))ms
           平均ジッター: \(String(format: "%.1f", networkQuality.averageJitter))ms
           最大パケット損失: \(String(format: "%.1f", networkQuality.worstPacketLoss))%
           総合品質: \(String(format: "%.1f", networkQuality.overallScore * 100))%
        
        📱 接続デバイス:
        """
        
        for device in connectedDevices {
            report += "\n   • \(device.name) (\(device.type.rawValue))"
            report += "\n     遅延: \(String(format: "%.1f", device.connectionQuality.latency))ms"
            report += " | 品質: \(device.connectionQuality.qualityLevel)"
        }
        
        return report
    }
    
    /// ネットワーク診断
    func performNetworkDiagnosis() async -> String {
        os_log("🔍 Performing network diagnosis", log: logger, type: .info)
        
        var diagnosis = "🔍 ネットワーク診断結果:\n\n"
        
        // 基本接続テスト
        if connections.isEmpty {
            diagnosis += "❌ アクティブな接続がありません\n"
        } else {
            diagnosis += "✅ \(connections.count)個のアクティブ接続\n"
        }
        
        // 品質テスト
        if networkQuality.overallScore > 0.8 {
            diagnosis += "✅ ネットワーク品質良好\n"
        } else if networkQuality.overallScore > 0.6 {
            diagnosis += "⚠️ ネットワーク品質注意\n"
        } else {
            diagnosis += "❌ ネットワーク品質不良\n"
        }
        
        // 推奨事項
        diagnosis += "\n📋 推奨事項:\n"
        if networkQuality.overallLatency > 50.0 {
            diagnosis += "• 有線LAN接続を検討\n"
        }
        if networkQuality.worstPacketLoss > 1.0 {
            diagnosis += "• Wi-Fi信号強度を確認\n"
        }
        if connectedDevices.count > 5 {
            diagnosis += "• デバイス数が多すぎる可能性\n"
        }
        
        return diagnosis
    }
}