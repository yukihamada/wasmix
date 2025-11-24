// 🎯 HiAudio Pro - Automatic Calibration Coordinator
// macOSとiPhone間の自動キャリブレーション統合システム

import Foundation
import Network
import AVFoundation

// MARK: - Automatic Calibration Coordinator
@MainActor
class AutoCalibrationCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var calibrationPhase: CalibrationPhase = .idle
    @Published var connectedDevices: [CalibrationDevice] = []
    @Published var overallProgress: Float = 0.0
    @Published var statusMessage: String = "準備完了"
    @Published var calibrationResults: [String: CalibrationResult] = [:]
    
    // MARK: - Core Components
    private let calibrationEngine = CalibrationEngine()
    private let networkManager = CalibrationNetworkManager()
    private let audioSystem = CalibrationAudioSystem()
    
    // Configuration
    private let maxSimultaneousDevices = 10
    private let calibrationTimeout: TimeInterval = 30.0
    private let retryAttempts = 3
    
    // State Management
    private var currentSession: CalibrationSession?
    private var deviceRegistrations: [String: DeviceRegistration] = [:]
    private var completedMeasurements: [String: DelayMeasurement] = [:]
    
    enum CalibrationPhase {
        case idle
        case discovering
        case preparing
        case measuring
        case analyzing
        case optimizing
        case applying
        case completed
        case failed(Error)
        
        var description: String {
            switch self {
            case .idle: return "待機中"
            case .discovering: return "デバイス検索中"
            case .preparing: return "キャリブレーション準備中"
            case .measuring: return "音響測定実行中"
            case .analyzing: return "測定結果を解析中"
            case .optimizing: return "遅延設定を最適化中"
            case .applying: return "キャリブレーション設定を適用中"
            case .completed: return "キャリブレーション完了"
            case .failed(let error): return "失敗: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        setupNetworkManager()
        setupAudioSystem()
    }
    
    private func setupNetworkManager() {
        networkManager.delegate = self
        networkManager.startListening()
    }
    
    private func setupAudioSystem() {
        audioSystem.delegate = self
    }
    
    // MARK: - Main Calibration Flow
    func startAutomaticCalibration() async throws {
        print("🎯 Starting automatic calibration flow...")
        
        guard !connectedDevices.isEmpty else {
            throw CalibrationError.noDevicesFound
        }
        
        // セッション開始
        currentSession = CalibrationSession(
            id: UUID().uuidString,
            devices: connectedDevices,
            startTime: Date()
        )
        
        do {
            // 1. デバイス検出・準備
            calibrationPhase = .discovering
            try await discoverAndPrepareDevices()
            
            // 2. 音響測定
            calibrationPhase = .measuring
            try await performAcousticMeasurements()
            
            // 3. 結果解析
            calibrationPhase = .analyzing
            let analysisResults = try await analyzeCalibrationResults()
            
            // 4. 設定最適化
            calibrationPhase = .optimizing
            let optimizedSettings = try await optimizeDelaySettings(analysisResults)
            
            // 5. 設定適用
            calibrationPhase = .applying
            try await applyCalibrationSettings(optimizedSettings)
            
            calibrationPhase = .completed
            statusMessage = "キャリブレーション完了"
            overallProgress = 1.0
            
            print("✅ Automatic calibration completed successfully")
            
        } catch {
            calibrationPhase = .failed(error)
            statusMessage = "キャリブレーションエラー: \(error.localizedDescription)"
            print("❌ Calibration failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Device Discovery & Preparation
    private func discoverAndPrepareDevices() async throws {
        statusMessage = "接続済みデバイスを確認中..."
        overallProgress = 0.1
        
        // 接続済みデバイスの準備状態確認
        for device in connectedDevices {
            try await prepareDevice(device)
            await updateProgress(0.1 + 0.2 * Float(connectedDevices.firstIndex(where: { $0.id == device.id }) ?? 0) / Float(connectedDevices.count))
        }
        
        // 最小デバイス数チェック
        let readyDevices = connectedDevices.filter { $0.status == .ready }
        guard readyDevices.count >= 1 else {
            throw CalibrationError.insufficientDevices
        }
        
        statusMessage = "\(readyDevices.count)台のデバイスが準備完了"
        overallProgress = 0.3
    }
    
    private func prepareDevice(_ device: CalibrationDevice) async throws {
        print("📱 Preparing device: \(device.name)")
        
        // デバイス固有の準備処理
        let preparationMessage = CalibrationMessage.prepare(
            deviceId: device.id,
            sessionId: currentSession?.id ?? "",
            audioSettings: getOptimalAudioSettings(for: device)
        )
        
        try await networkManager.sendMessage(preparationMessage, to: device)
        
        // 準備完了の応答を待機
        try await waitForDevicePreparation(device, timeout: 10.0)
    }
    
    private func getOptimalAudioSettings(for device: CalibrationDevice) -> AudioSettings {
        return AudioSettings(
            sampleRate: device.capabilities.maxSampleRate,
            bufferSize: 512, // 低遅延設定
            channelCount: min(device.capabilities.channelCount, 2),
            bitDepth: 32
        )
    }
    
    // MARK: - Acoustic Measurements
    private func performAcousticMeasurements() async throws {
        statusMessage = "音響測定を開始中..."
        overallProgress = 0.4
        
        guard let session = currentSession else {
            throw CalibrationError.invalidSession
        }
        
        // キャリブレーション信号を生成
        let calibrationSignal = generateCalibrationSweep()
        print("🎵 Generated calibration signal: \(calibrationSignal.count) samples")
        
        // 全デバイスに測定開始通知
        for device in connectedDevices.filter({ $0.status == .ready }) {
            let startMessage = CalibrationMessage.startMeasurement(
                deviceId: device.id,
                sessionId: session.id,
                signalDuration: 5.0
            )
            
            try await networkManager.sendMessage(startMessage, to: device)
        }
        
        // 音響信号の再生
        try await audioSystem.playCalibrationSignal(calibrationSignal)
        
        // 各デバイスからの録音データを収集
        try await collectRecordingData()
        
        statusMessage = "音響測定完了"
        overallProgress = 0.7
    }
    
    private func generateCalibrationSweep() -> [Float] {
        // CalibrationEngineのスイープ生成を使用
        let sweepDuration: Double = 5.0
        let sampleRate: Double = 48000.0
        let startFreq: Double = 20.0
        let endFreq: Double = 20000.0
        
        let frameCount = Int(sweepDuration * sampleRate)
        var sweep = [Float](repeating: 0.0, count: frameCount)
        
        let logStart = log(startFreq)
        let logEnd = log(endFreq)
        let logRange = logEnd - logStart
        
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let normalizedTime = t / sweepDuration
            
            let instantFreq = exp(logStart + logRange * normalizedTime)
            let phase = 2.0 * .pi * instantFreq * t / logRange
            
            let window = 0.5 - 0.5 * cos(2.0 * .pi * normalizedTime)
            sweep[i] = Float(sin(phase) * window * 0.8)
        }
        
        return sweep
    }
    
    private func collectRecordingData() async throws {
        let timeout = Date().addingTimeInterval(calibrationTimeout)
        var receivedData: Set<String> = []
        
        while receivedData.count < connectedDevices.count && Date() < timeout {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // 録音データの受信状況をチェック
            for device in connectedDevices {
                if !receivedData.contains(device.id) && hasRecordingData(for: device.id) {
                    receivedData.insert(device.id)
                    print("📡 Received recording data from \(device.name)")
                }
            }
            
            // 進捗更新
            let progress = 0.4 + 0.3 * Float(receivedData.count) / Float(connectedDevices.count)
            await updateProgress(progress)
        }
        
        guard receivedData.count >= 1 else {
            throw CalibrationError.noRecordingDataReceived
        }
        
        print("✅ Recording data collection completed: \(receivedData.count)/\(connectedDevices.count) devices")
    }
    
    // MARK: - Analysis & Optimization
    private func analyzeCalibrationResults() async throws -> [String: DelayMeasurement] {
        statusMessage = "測定結果を解析中..."
        
        var measurements: [String: DelayMeasurement] = [:]
        let referenceSignal = generateCalibrationSweep()
        
        for device in connectedDevices {
            guard let recordingData = getRecordingData(for: device.id) else { continue }
            
            // 高精度遅延測定
            let result = await Task.detached {
                return self.calibrationEngine.measureDelayWithHighPrecision(
                    reference: referenceSignal,
                    recorded: recordingData
                )
            }.value
            
            let measurement = DelayMeasurement(
                deviceId: device.id,
                delayMs: result.delay,
                confidence: result.confidence,
                signalToNoise: result.snr,
                timestamp: Date()
            )
            
            measurements[device.id] = measurement
            print("📊 \(device.name): \(String(format: "%.3f", result.delay))ms delay, \(String(format: "%.1f", result.snr))dB SNR")
        }
        
        completedMeasurements = measurements
        return measurements
    }
    
    private func optimizeDelaySettings(_ measurements: [String: DelayMeasurement]) async throws -> OptimizedSettings {
        statusMessage = "遅延設定を最適化中..."
        
        let reliableMeasurements = measurements.values.filter { $0.isReliable }
        guard !reliableMeasurements.isEmpty else {
            throw CalibrationError.noReliableMeasurements
        }
        
        // 最小遅延を基準として設定
        let minDelay = reliableMeasurements.map { $0.delayMs }.min() ?? 0
        
        var optimizedDelays: [String: Double] = [:]
        for measurement in reliableMeasurements {
            optimizedDelays[measurement.deviceId] = measurement.delayMs - minDelay
        }
        
        // 最適化品質評価
        let rmsError = calculateRMSError(optimizedDelays)
        let maxDeviation = optimizedDelays.values.map { abs($0) }.max() ?? 0
        
        let optimizedSettings = OptimizedSettings(
            delayMap: optimizedDelays,
            rmsError: rmsError,
            maxDeviation: maxDeviation,
            qualityScore: calculateQualityScore(rmsError: rmsError, maxDeviation: maxDeviation),
            timestamp: Date()
        )
        
        print("⚡ Optimization completed:")
        print("   RMS Error: \(String(format: "%.3f", rmsError))ms")
        print("   Max Deviation: \(String(format: "%.3f", maxDeviation))ms")
        print("   Quality Score: \(String(format: "%.3f", optimizedSettings.qualityScore))")
        
        return optimizedSettings
    }
    
    private func applyCalibrationSettings(_ settings: OptimizedSettings) async throws {
        statusMessage = "キャリブレーション設定を適用中..."
        
        for (deviceId, delay) in settings.delayMap {
            guard let device = connectedDevices.first(where: { $0.id == deviceId }) else { continue }
            
            let applyMessage = CalibrationMessage.applySettings(
                deviceId: deviceId,
                delayCompensation: delay,
                timestamp: Date().timeIntervalSince1970
            )
            
            try await networkManager.sendMessage(applyMessage, to: device)
            print("📡 Applied \(String(format: "%.3f", delay))ms delay to \(device.name)")
        }
        
        // 設定適用の完了を待機
        try await waitForSettingsApplication(timeout: 10.0)
        
        statusMessage = "全デバイスにキャリブレーション設定を適用完了"
    }
    
    // MARK: - Helper Functions
    private func updateProgress(_ progress: Float) async {
        overallProgress = progress
    }
    
    private func hasRecordingData(for deviceId: String) -> Bool {
        return deviceRegistrations[deviceId]?.hasRecordingData == true
    }
    
    private func getRecordingData(for deviceId: String) -> [Float]? {
        return deviceRegistrations[deviceId]?.recordingData
    }
    
    private func waitForDevicePreparation(_ device: CalibrationDevice, timeout: TimeInterval) async throws {
        // デバイス準備完了を待機
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline && device.status != .ready {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        if device.status != .ready {
            throw CalibrationError.devicePreparationTimeout
        }
    }
    
    private func waitForSettingsApplication(timeout: TimeInterval) async throws {
        // 設定適用完了を待機
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
    
    private func calculateRMSError(_ delays: [String: Double]) -> Double {
        let values = Array(delays.values)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    private func calculateQualityScore(rmsError: Double, maxDeviation: Double) -> Float {
        let rmsScore = max(0.0, 1.0 - rmsError / 1.0) // 1ms基準
        let deviationScore = max(0.0, 1.0 - maxDeviation / 2.0) // 2ms基準
        return Float((rmsScore + deviationScore) / 2.0)
    }
}

// MARK: - Supporting Data Structures
struct CalibrationSession {
    let id: String
    let devices: [CalibrationDevice]
    let startTime: Date
    var endTime: Date?
    
    var duration: TimeInterval {
        return (endTime ?? Date()).timeIntervalSince(startTime)
    }
}

struct CalibrationDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let model: String
    let capabilities: DeviceCapabilities
    var status: DeviceStatus = .disconnected
    var lastSeen: Date = Date()
    
    enum DeviceStatus {
        case disconnected
        case connected
        case preparing
        case ready
        case measuring
        case error(String)
    }
    
    static func == (lhs: CalibrationDevice, rhs: CalibrationDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

struct DeviceRegistration {
    let device: CalibrationDevice
    let registrationTime: Date
    var hasRecordingData: Bool = false
    var recordingData: [Float]?
    var lastActivity: Date = Date()
}

struct AudioSettings {
    let sampleRate: Double
    let bufferSize: Int
    let channelCount: Int
    let bitDepth: Int
}

struct OptimizedSettings {
    let delayMap: [String: Double]
    let rmsError: Double
    let maxDeviation: Double
    let qualityScore: Float
    let timestamp: Date
}

// MARK: - Extended Calibration Messages
enum CalibrationMessage: Codable {
    case deviceRegistration(DeviceInfo)
    case prepare(deviceId: String, sessionId: String, audioSettings: AudioSettings)
    case preparationComplete(deviceId: String)
    case startMeasurement(deviceId: String, sessionId: String, signalDuration: Double)
    case recordingData(deviceId: String, data: [Float], timestamp: TimeInterval)
    case applySettings(deviceId: String, delayCompensation: Double, timestamp: TimeInterval)
    case settingsApplied(deviceId: String, success: Bool)
    case error(deviceId: String, message: String)
    case calibrationReady(deviceId: String, timestamp: TimeInterval)
    case audioData(deviceId: String, sampleRate: Double, data: [Float], timestamp: TimeInterval)
    case calibrationResult(CalibrationResult)
    case calibrationError(String)
}

// MARK: - Error Types
enum CalibrationError: Error, LocalizedError {
    case noDevicesFound
    case insufficientDevices
    case invalidSession
    case noRecordingDataReceived
    case noReliableMeasurements
    case devicePreparationTimeout
    case measurementTimeout
    case networkError(String)
    case audioSystemError(String)
    
    var errorDescription: String? {
        switch self {
        case .noDevicesFound:
            return "接続されたデバイスが見つかりません"
        case .insufficientDevices:
            return "キャリブレーションに十分なデバイスがありません"
        case .invalidSession:
            return "無効なキャリブレーションセッション"
        case .noRecordingDataReceived:
            return "録音データを受信できませんでした"
        case .noReliableMeasurements:
            return "信頼できる測定結果がありません"
        case .devicePreparationTimeout:
            return "デバイス準備がタイムアウトしました"
        case .measurementTimeout:
            return "音響測定がタイムアウトしました"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .audioSystemError(let message):
            return "音声システムエラー: \(message)"
        }
    }
}

// MARK: - Network & Audio System Delegates
extension AutoCalibrationCoordinator: CalibrationNetworkManagerDelegate {
    func didReceiveDeviceRegistration(_ device: CalibrationDevice) {
        if !connectedDevices.contains(device) {
            connectedDevices.append(device)
            print("📱 Device registered: \(device.name)")
        }
    }
    
    func didReceiveMessage(_ message: CalibrationMessage, from device: CalibrationDevice) {
        Task {
            await handleReceivedMessage(message, from: device)
        }
    }
    
    private func handleReceivedMessage(_ message: CalibrationMessage, from device: CalibrationDevice) async {
        switch message {
        case .preparationComplete(let deviceId):
            if let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) {
                connectedDevices[index].status = .ready
            }
            
        case .recordingData(let deviceId, let data, _):
            deviceRegistrations[deviceId]?.recordingData = data
            deviceRegistrations[deviceId]?.hasRecordingData = true
            
        case .settingsApplied(let deviceId, let success):
            print(success ? "✅" : "❌", "Settings applied for device: \(deviceId)")
            
        default:
            break
        }
    }
}

extension AutoCalibrationCoordinator: CalibrationAudioSystemDelegate {
    func didCompleteAudioPlayback() {
        print("🎵 Calibration signal playback completed")
    }
    
    func didEncounterAudioError(_ error: Error) {
        Task {
            await MainActor.run {
                calibrationPhase = .failed(error)
                statusMessage = "音声システムエラー: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Placeholder Protocols for Network and Audio Systems
protocol CalibrationNetworkManagerDelegate: AnyObject {
    func didReceiveDeviceRegistration(_ device: CalibrationDevice)
    func didReceiveMessage(_ message: CalibrationMessage, from device: CalibrationDevice)
}

protocol CalibrationAudioSystemDelegate: AnyObject {
    func didCompleteAudioPlayback()
    func didEncounterAudioError(_ error: Error)
}

// MARK: - Placeholder Classes (to be implemented separately)
class CalibrationNetworkManager {
    weak var delegate: CalibrationNetworkManagerDelegate?
    
    func startListening() {
        // Network listening implementation
    }
    
    func sendMessage(_ message: CalibrationMessage, to device: CalibrationDevice) async throws {
        // Message sending implementation
    }
}

class CalibrationAudioSystem {
    weak var delegate: CalibrationAudioSystemDelegate?
    
    func playCalibrationSignal(_ signal: [Float]) async throws {
        // Audio playback implementation
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        delegate?.didCompleteAudioPlayback()
    }
}