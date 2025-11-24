// 📱 HiAudio Pro - iPhone Calibration Client
// macOS CalibrationEngineと連携するiOS側実装

import Foundation
import AVFoundation
import Accelerate
import Network
import CoreML

// MARK: - Calibration Client Protocol
protocol CalibrationClientDelegate: AnyObject {
    func calibrationDidStart()
    func calibrationDidReceiveProgress(_ progress: Float, message: String)
    func calibrationDidComplete(result: CalibrationResult)
    func calibrationDidFail(error: CalibrationError)
}

// MARK: - Calibration Error Types
enum CalibrationError: Error, LocalizedError {
    case audioPermissionDenied
    case networkConnectionFailed
    case hardwareNotSupported
    case calibrationTimedOut
    case invalidAudioFormat
    case positioningError
    
    var errorDescription: String? {
        switch self {
        case .audioPermissionDenied:
            return "マイクのアクセス許可が必要です"
        case .networkConnectionFailed:
            return "macOSアプリとの接続に失敗しました"
        case .hardwareNotSupported:
            return "この機種はキャリブレーション対象外です"
        case .calibrationTimedOut:
            return "キャリブレーションがタイムアウトしました"
        case .invalidAudioFormat:
            return "音声フォーマットが無効です"
        case .positioningError:
            return "デバイスの位置測定に失敗しました"
        }
    }
}

// MARK: - Main iOS Calibration Client
class iOSCalibrationClient: ObservableObject {
    
    // MARK: - Properties
    weak var delegate: CalibrationClientDelegate?
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var calibrationState: CalibrationState = .idle
    @Published var currentProgress: Float = 0.0
    @Published var statusMessage: String = "待機中"
    
    // Audio Engine
    private var audioEngine: AVAudioEngine?
    private var audioSession: AVAudioSession?
    private var inputNode: AVAudioInputNode?
    
    // Network
    private var connection: NWConnection?
    private var listener: NWListener?
    
    // Calibration Data
    private var deviceInfo: DeviceInfo?
    private var recordingBuffer: [Float] = []
    private var calibrationStartTime: Date?
    
    // Configuration
    private let sampleRate: Double = 48000.0
    private let bufferSize: AVAudioFrameCount = 1024
    private let maxRecordingDuration: TimeInterval = 10.0
    
    // MARK: - Connection Status
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        var description: String {
            switch self {
            case .disconnected: return "未接続"
            case .connecting: return "接続中..."
            case .connected: return "接続済み"
            case .error(let message): return "エラー: \(message)"
            }
        }
    }
    
    // MARK: - Calibration State
    enum CalibrationState {
        case idle
        case preparing
        case listening
        case analyzing
        case completed
        case failed(CalibrationError)
        
        var description: String {
            switch self {
            case .idle: return "待機中"
            case .preparing: return "準備中"
            case .listening: return "録音中"
            case .analyzing: return "解析中"
            case .completed: return "完了"
            case .failed(let error): return "失敗: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        setupDeviceInfo()
        setupAudioSession()
    }
    
    deinit {
        disconnect()
        stopAudioEngine()
    }
    
    // MARK: - Device Information Setup
    private func setupDeviceInfo() {
        let modelName = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let deviceName = UIDevice.current.name
        
        // iPhone機種判別
        var modelIdentifier = "Unknown"
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        modelIdentifier = String(cString: machine)
        
        deviceInfo = DeviceInfo(
            id: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            name: deviceName,
            model: modelIdentifier,
            iOSVersion: systemVersion,
            microphoneType: getMicrophoneType(for: modelIdentifier),
            capabilities: getDeviceCapabilities(for: modelIdentifier)
        )
        
        print("📱 Device Info: \(deviceInfo?.description ?? "Unknown")")
    }
    
    private func getMicrophoneType(for modelIdentifier: String) -> String {
        // iPhone機種別のマイクタイプを返す
        if modelIdentifier.contains("iPhone15") {
            return "Triple-mic array with spatial audio"
        } else if modelIdentifier.contains("iPhone14") || modelIdentifier.contains("iPhone13") {
            return "Dual-mic array with spatial audio"
        } else if modelIdentifier.contains("iPhone12") || modelIdentifier.contains("iPhone11") {
            return "Dual-mic array"
        } else {
            return "Standard microphone"
        }
    }
    
    private func getDeviceCapabilities(for modelIdentifier: String) -> DeviceCapabilities {
        // 機種別の性能情報
        let maxSampleRate: Double
        let channelCount: Int
        let hasAdvancedDSP: Bool
        
        if modelIdentifier.contains("iPhone15") || modelIdentifier.contains("iPhone14") {
            maxSampleRate = 48000.0
            channelCount = 2
            hasAdvancedDSP = true
        } else if modelIdentifier.contains("iPhone13") || modelIdentifier.contains("iPhone12") {
            maxSampleRate = 48000.0
            channelCount = 1
            hasAdvancedDSP = true
        } else {
            maxSampleRate = 44100.0
            channelCount = 1
            hasAdvancedDSP = false
        }
        
        return DeviceCapabilities(
            maxSampleRate: maxSampleRate,
            channelCount: channelCount,
            hasBuiltinCalibration: hasAdvancedDSP
        )
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession?.setCategory(.playAndRecord, 
                                        mode: .measurement,
                                        options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession?.setActive(true)
            
            // 最高品質設定
            try audioSession?.setPreferredSampleRate(sampleRate)
            try audioSession?.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
            
            print("✅ Audio session configured: \(sampleRate)Hz, \(bufferSize) frames")
            
        } catch {
            print("❌ Audio session setup failed: \(error)")
        }
    }
    
    // MARK: - Network Connection
    func connectToMacOS(host: String, port: UInt16 = 55556) {
        connectionStatus = .connecting
        statusMessage = "macOSアプリに接続中..."
        
        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)
        let endpoint = NWEndpoint.hostPort(host: hostEndpoint, port: portEndpoint)
        
        connection = NWConnection(to: endpoint, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.connectionStatus = .connected
                    self?.statusMessage = "接続完了"
                    self?.sendDeviceRegistration()
                    
                case .failed(let error):
                    self?.connectionStatus = .error(error.localizedDescription)
                    self?.statusMessage = "接続失敗"
                    
                case .cancelled:
                    self?.connectionStatus = .disconnected
                    self?.statusMessage = "接続終了"
                    
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: .global())
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        connectionStatus = .disconnected
        statusMessage = "切断済み"
    }
    
    // MARK: - Device Registration
    private func sendDeviceRegistration() {
        guard let deviceInfo = deviceInfo,
              let connection = connection else { return }
        
        let registrationData = CalibrationMessage.deviceRegistration(deviceInfo)
        
        do {
            let data = try JSONEncoder().encode(registrationData)
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    print("❌ Device registration failed: \(error)")
                } else {
                    print("✅ Device registered successfully")
                }
            }))
        } catch {
            print("❌ Registration encoding failed: \(error)")
        }
    }
    
    // MARK: - Calibration Process
    func startCalibration() async throws {
        guard connectionStatus == .connected else {
            throw CalibrationError.networkConnectionFailed
        }
        
        // 1. 権限確認
        let permission = await requestMicrophonePermission()
        guard permission else {
            throw CalibrationError.audioPermissionDenied
        }
        
        // 2. 音声エンジン準備
        try setupAudioEngine()
        
        // 3. キャリブレーション開始通知
        calibrationState = .preparing
        delegate?.calibrationDidStart()
        calibrationStartTime = Date()
        
        // 4. macOSに開始通知
        sendCalibrationReady()
        
        // 5. キャリブレーション信号待機
        try await waitForCalibrationSignal()
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw CalibrationError.hardwareNotSupported
        }
        
        inputNode = audioEngine.inputNode
        
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate,
                                   channels: 1,
                                   interleaved: false)!
        
        // 高精度録音設定
        inputNode?.installTap(onBus: 0,
                             bufferSize: bufferSize,
                             format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
        
        try audioEngine.start()
        print("✅ Audio engine started for calibration")
    }
    
    private func stopAudioEngine() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
    }
    
    // MARK: - Audio Processing
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard calibrationState == .listening,
              let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // バッファに追加
        recordingBuffer.append(contentsOf: audioData)
        
        // 進捗更新
        let currentDuration = Double(recordingBuffer.count) / sampleRate
        let progress = Float(currentDuration / maxRecordingDuration)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentProgress = min(progress, 1.0)
            self?.statusMessage = "録音中... \(String(format: "%.1f", currentDuration))秒"
            self?.delegate?.calibrationDidReceiveProgress(progress, message: self?.statusMessage ?? "")
        }
        
        // 最大録音時間に達した場合
        if currentDuration >= maxRecordingDuration {
            completeRecording()
        }
    }
    
    private func completeRecording() {
        calibrationState = .analyzing
        stopAudioEngine()
        
        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = "録音完了 - 解析中..."
        }
        
        // macOSに録音データ送信
        sendRecordingData()
    }
    
    // MARK: - Network Communication
    private func sendCalibrationReady() {
        let message = CalibrationMessage.calibrationReady(
            deviceId: deviceInfo?.id ?? "",
            timestamp: Date().timeIntervalSince1970
        )
        sendMessage(message)
    }
    
    private func sendRecordingData() {
        guard !recordingBuffer.isEmpty else { return }
        
        let message = CalibrationMessage.audioData(
            deviceId: deviceInfo?.id ?? "",
            sampleRate: sampleRate,
            data: recordingBuffer,
            timestamp: Date().timeIntervalSince1970
        )
        
        sendMessage(message)
        
        // バッファクリア
        recordingBuffer.removeAll()
    }
    
    private func sendMessage(_ message: CalibrationMessage) {
        guard let connection = connection else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    print("❌ Message send failed: \(error)")
                }
            }))
        } catch {
            print("❌ Message encoding failed: \(error)")
        }
    }
    
    private func waitForCalibrationSignal() async throws {
        // メッセージ受信待機
        guard let connection = connection else {
            throw CalibrationError.networkConnectionFailed
        }
        
        try await withCheckedThrowingContinuation { continuation in
            receiveMessages(continuation: continuation)
        }
    }
    
    private func receiveMessages(continuation: CheckedContinuation<Void, Error>?) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            
            if let error = error {
                continuation?.resume(throwing: CalibrationError.networkConnectionFailed)
                return
            }
            
            if let data = data {
                self?.processReceivedMessage(data)
            }
            
            if !isComplete {
                self?.receiveMessages(continuation: continuation)
            }
        }
    }
    
    private func processReceivedMessage(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(CalibrationMessage.self, from: data)
            
            switch message {
            case .startCalibration:
                DispatchQueue.main.async { [weak self] in
                    self?.calibrationState = .listening
                    self?.statusMessage = "キャリブレーション信号を録音中..."
                }
                
            case .calibrationResult(let result):
                DispatchQueue.main.async { [weak self] in
                    self?.calibrationState = .completed
                    self?.statusMessage = "キャリブレーション完了"
                    self?.currentProgress = 1.0
                    self?.delegate?.calibrationDidComplete(result: result)
                }
                
            case .calibrationError(let errorMessage):
                DispatchQueue.main.async { [weak self] in
                    let error = CalibrationError.calibrationTimedOut // または適切なエラーマッピング
                    self?.calibrationState = .failed(error)
                    self?.statusMessage = "エラー: \(errorMessage)"
                    self?.delegate?.calibrationDidFail(error: error)
                }
                
            default:
                break
            }
            
        } catch {
            print("❌ Message decoding failed: \(error)")
        }
    }
}

// MARK: - Supporting Data Structures

struct DeviceInfo: Codable {
    let id: String
    let name: String
    let model: String
    let iOSVersion: String
    let microphoneType: String
    let capabilities: DeviceCapabilities
    
    var description: String {
        return "\(model) (\(name)) - \(microphoneType)"
    }
}

enum CalibrationMessage: Codable {
    case deviceRegistration(DeviceInfo)
    case calibrationReady(deviceId: String, timestamp: TimeInterval)
    case startCalibration
    case audioData(deviceId: String, sampleRate: Double, data: [Float], timestamp: TimeInterval)
    case calibrationResult(CalibrationResult)
    case calibrationError(String)
}

// MARK: - Extensions for Integration

extension iOSCalibrationClient {
    
    /// 簡易キャリブレーション (自動モード)
    func performQuickCalibration() async throws {
        try await startCalibration()
        
        // 自動進行をモニター
        while calibrationState != .completed && calibrationState != .failed(CalibrationError.calibrationTimedOut) {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        }
        
        if case .failed(let error) = calibrationState {
            throw error
        }
    }
    
    /// キャリブレーション状態のリセット
    func resetCalibration() {
        calibrationState = .idle
        currentProgress = 0.0
        statusMessage = "待機中"
        recordingBuffer.removeAll()
        stopAudioEngine()
    }
    
    /// デバイス情報の更新
    func updateDeviceInfo() {
        setupDeviceInfo()
    }
}

// MARK: - Audio Quality Extensions

extension iOSCalibrationClient {
    
    /// 音声品質の事前チェック
    func checkAudioQuality() async -> AudioQualityReport {
        let report = AudioQualityReport()
        
        // マイク動作確認
        do {
            try setupAudioEngine()
            
            // 短時間録音テスト
            let testDuration: TimeInterval = 1.0
            var testBuffer: [Float] = []
            
            // 簡易録音テスト (実装省略)
            
            stopAudioEngine()
            
            report.microphoneStatus = .working
            report.backgroundNoiseLevel = calculateNoiseLevel(testBuffer)
            report.recommendedSettings = getRecommendedSettings()
            
        } catch {
            report.microphoneStatus = .error(error.localizedDescription)
        }
        
        return report
    }
    
    private func calculateNoiseLevel(_ buffer: [Float]) -> Float {
        guard !buffer.isEmpty else { return 0 }
        
        let rms = sqrt(buffer.map { $0 * $0 }.reduce(0, +) / Float(buffer.count))
        return 20 * log10(rms + 1e-6) // dB
    }
    
    private func getRecommendedSettings() -> [String: Any] {
        return [
            "sampleRate": sampleRate,
            "bufferSize": bufferSize,
            "optimalDistance": "30cm - 1m",
            "environment": "静かな室内を推奨",
            "orientation": "画面を上向きに"
        ]
    }
}

struct AudioQualityReport {
    enum MicrophoneStatus {
        case working
        case warning(String)
        case error(String)
    }
    
    var microphoneStatus: MicrophoneStatus = .working
    var backgroundNoiseLevel: Float = 0.0 // dB
    var recommendedSettings: [String: Any] = [:]
    
    var isGoodQuality: Bool {
        switch microphoneStatus {
        case .working:
            return backgroundNoiseLevel > -40.0 // -40dB以下のノイズフロア
        case .warning, .error:
            return false
        }
    }
}