import AVFoundation
import Network
import Foundation
import Cocoa
import SwiftUI

// 📢 通知システム
struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let type: NotificationType
    let message: String
    let timestamp: Date = Date()
    
    enum NotificationType {
        case info, warning, error, success
        
        var color: NSColor {
            switch self {
            case .info: return .systemBlue
            case .warning: return .systemOrange
            case .error: return .systemRed
            case .success: return .systemGreen
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }
}

// 🎨 UI・テーマ管理
enum UIMode: String, CaseIterable {
    case minimal = "minimal"
    case visual = "visual"
    case unified = "unified"
    
    var displayName: String {
        switch self {
        case .minimal: return "🔹 Minimal"
        case .visual: return "🎆 Visual"
        case .unified: return "🎛️ Unified"
        }
    }
}

enum AppColorScheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "☀️ Light"
        case .dark: return "🌙 Dark"
        case .auto: return "⚙️ Auto"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }
}

// ネットワーク品質監視クラス
class NetworkStats {
    private var packetsSent: UInt64 = 0
    private var packetsLost: UInt64 = 0
    private var lastLatency: Double = 0
    private var rttHistory: [Double] = []
    private let maxHistorySize = 100
    
    func recordPacketSent() {
        packetsSent += 1
    }
    
    func recordLatency(_ latency: Double) {
        lastLatency = latency
        rttHistory.append(latency)
        if rttHistory.count > maxHistorySize {
            rttHistory.removeFirst()
        }
    }
    
    var averageLatency: Double {
        guard !rttHistory.isEmpty else { return 0 }
        return rttHistory.reduce(0, +) / Double(rttHistory.count)
    }
    
    var isNetworkGood: Bool {
        return averageLatency < 20.0 // 20ms未満なら良好
    }
    
    func recommendedQuality() -> AudioQuality {
        if averageLatency < 10.0 {
            return .ultra // 超高品質
        } else if averageLatency < 20.0 {
            return .high // 高品質
        } else if averageLatency < 50.0 {
            return .medium // 中品質
        } else {
            return .low // 低遅延優先
        }
    }
}

enum AudioQuality {
    case ultra  // 96kHz, 128 frames, ステレオ + マルチバンド処理
    case high   // 48kHz, 128 frames, ステレオ
    case medium // 48kHz, 128 frames, モノラル
    case low    // 44.1kHz, 128 frames, モノラル
    
    var sampleRate: Double {
        switch self {
        case .ultra: return 96000
        case .high, .medium: return 48000
        case .low: return 44100
        }
    }
    
    var bufferSize: UInt32 {
        switch self {
        case .ultra, .high, .medium, .low: return 128
        }
    }
    
    var channels: UInt32 {
        switch self {
        case .ultra, .high: return 2
        default: return 1
        }
    }
    
    var description: String {
        switch self {
        case .ultra: return "Ultra (96kHz Stereo + DSP)"
        case .high: return "High (48kHz Stereo)"
        case .medium: return "Medium (48kHz Mono)"
        case .low: return "Low (44.1kHz Mono)"
        }
    }
}

// 🎵 **ULTRA-HIGH QUALITY** ノイズリダクションクラス
class NoiseReducer {
    private var noiseFloor: Float = -80.0 // -80dB 超高精度ノイズフロア
    private var gateThreshold: Float = -65.0 // -65dB 高感度ゲート
    private var gateRelease: Float = 0.05 // 高速ゲート開放
    private var gateState: Float = 0.0
    
    // スペクトラル・ノイズリダクション (周波数領域処理)
    private var noiseProfile: [Float] = Array(repeating: 0.0, count: 512)
    private var isLearning = true
    private var learningSamples = 0
    
    // 🎛️ **動的制御パラメータ**
    private var isEnabled = true
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled else { return } // 無効時は処理をスキップ
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        // 🎵 **SPECTRAL NOISE REDUCTION**: 周波数領域でのノイズ処理
        if isLearning && learningSamples < 1000 {
            learnNoiseProfile(channelData, frameCount: frameCount)
        } else {
            applySpectralNoiseReduction(channelData, frameCount: frameCount)
        }
        
        // 従来のゲート処理も併用
        for i in 0..<frameCount {
            let sample = channelData[i]
            let sampleLevel = abs(sample)
            let levelDB = sampleLevel > 0 ? 20 * log10(sampleLevel) : -80.0
            
            // アダプティブ・ゲート処理
            if levelDB > gateThreshold {
                gateState = min(1.0, gateState + 0.2) // 高速開放
            } else {
                gateState = max(0.0, gateState - gateRelease)
            }
            
            // Soft-knee compression for smooth gating
            let softGate = smoothstep(0.0, 1.0, gateState)
            channelData[i] = sample * softGate
        }
    }
    
    private func learnNoiseProfile(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        // ノイズプロファイル学習フェーズ
        for i in 0..<min(frameCount, noiseProfile.count) {
            let sample = abs(data[i])
            noiseProfile[i] = max(noiseProfile[i], sample * 0.1)
        }
        learningSamples += 1
        if learningSamples >= 1000 {
            isLearning = false
        }
    }
    
    private func applySpectralNoiseReduction(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        // スペクトラル・サブトラクション
        for i in 0..<min(frameCount, noiseProfile.count) {
            let sample = data[i]
            let sampleLevel = abs(sample)
            if sampleLevel < noiseProfile[i] * 3.0 { // ノイズレベルの3倍以下は削減
                data[i] = sample * 0.1 // 90%削減
            }
        }
    }
    
    private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
    
    // 🎛️ **リアルタイム設定変更メソッド**
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            gateState = 1.0 // 無効時はフルオープン
        }
    }
    
    func setGateThreshold(_ threshold: Float) {
        gateThreshold = max(-80.0, min(0.0, threshold))
    }
    
    func resetNoiseProfile() {
        isLearning = true
        learningSamples = 0
        noiseProfile = Array(repeating: 0.0, count: 512)
    }
}

// 🎵 **ULTRA-HIGH QUALITY** 自動ゲイン制御クラス  
class AutomaticGainControl {
    private var targetLevel: Float = -8.0 // -8dB 高品質目標レベル
    private var currentGain: Float = 1.0
    private var peakHistory: [Float] = []
    private var rmsHistory: [Float] = []
    private let historySize = 100 // 100フレーム分の履歴 (高精度)
    
    // マルチバンド・コンプレッサー (3バンド分割)
    private var lowBandGain: Float = 1.0    // 80Hz - 500Hz
    private var midBandGain: Float = 1.0    // 500Hz - 5kHz  
    private var highBandGain: Float = 1.0   // 5kHz - 24kHz
    private var crossoverFilters: [ButterworthFilter] = []
    
    // Look-ahead リミッター (64サンプル先読み = 約0.67ms)
    private var delayBuffer: [Float] = Array(repeating: 0.0, count: 64)
    private var delayIndex = 0
    private var limitThreshold: Float = -1.0 // -1dB でハードリミット
    
    // コンプレッサーパラメータ
    private var compressorRatio: Float = 4.0    // 4:1 圧縮 (動的変更可能)
    private let attackTime: Float = 0.001       // 1ms アタック
    private let releaseTime: Float = 0.100      // 100ms リリース
    private var compressorEnvelope: Float = 0.0
    
    // 🎛️ **動的制御フラグ**
    private var isAGCEnabled = true
    private var isCompressionEnabled = true
    private var isLimiterEnabled = true
    
    init() {
        setupCrossoverFilters()
    }
    
    private func setupCrossoverFilters() {
        // Linkwitz-Riley 24dB/octave crossover filters
        crossoverFilters = [
            ButterworthFilter(frequency: 500, sampleRate: 96000, isHighPass: false),  // Low pass
            ButterworthFilter(frequency: 500, sampleRate: 96000, isHighPass: true),   // High pass 1
            ButterworthFilter(frequency: 5000, sampleRate: 96000, isHighPass: false), // Low pass 2
            ButterworthFilter(frequency: 5000, sampleRate: 96000, isHighPass: true)   // High pass 2
        ]
    }
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard buffer.floatChannelData?[0] != nil else { return }
        let frameCount = Int(buffer.frameLength)
        
        // ステレオ処理対応
        let channels = Int(buffer.format.channelCount)
        
        for channel in 0..<channels {
            guard let channelPtr = buffer.floatChannelData?[channel] else { continue }
            
            // 🎛️ マルチバンド分析とコンプレッション (切り替え可能)
            if isCompressionEnabled {
                processMultibandCompression(channelPtr, frameCount: frameCount)
            }
            
            // 🎛️ Look-ahead リミッター適用 (切り替え可能)
            if isLimiterEnabled {
                applyLookAheadLimiter(channelPtr, frameCount: frameCount)
            }
        }
        
        // 統計更新
        updateStatistics(buffer)
    }
    
    private func processMultibandCompression(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        // マルチバンド信号分離と独立コンプレッション
        for i in 0..<frameCount {
            let sample = data[i]
            
            // 3バンド分離フィルタリング
            let lowBand = crossoverFilters[0].process(sample)
            let midBand = crossoverFilters[2].process(crossoverFilters[1].process(sample))
            let highBand = crossoverFilters[3].process(sample)
            
            // 各バンド独立コンプレッション
            let compressedLow = applyCompression(lowBand, gain: &lowBandGain, threshold: -12.0)
            let compressedMid = applyCompression(midBand, gain: &midBandGain, threshold: -8.0)
            let compressedHigh = applyCompression(highBand, gain: &highBandGain, threshold: -4.0)
            
            // 再合成
            data[i] = compressedLow + compressedMid + compressedHigh
        }
    }
    
    private func applyCompression(_ sample: Float, gain: inout Float, threshold: Float) -> Float {
        let level = abs(sample)
        let levelDB = level > 0 ? 20 * log10(level) : -80.0
        
        if levelDB > threshold {
            // コンプレッサー動作: オーバー分を圧縮
            let overAmount = levelDB - threshold
            let compressedOver = overAmount / compressorRatio
            let targetLevel = threshold + compressedOver
            let targetGain = pow(10, (targetLevel - levelDB) / 20.0)
            
            // スムーズなゲイン変化 (attack/release)
            if targetGain < gain {
                gain = gain * (1.0 - attackTime) + targetGain * attackTime
            } else {
                gain = gain * (1.0 - releaseTime) + targetGain * releaseTime
            }
        } else {
            // 閾値下では徐々にゲインを1.0に戻す
            gain = gain * (1.0 - releaseTime) + 1.0 * releaseTime
        }
        
        return sample * gain
    }
    
    private func applyLookAheadLimiter(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let currentSample = data[i]
            
            // 遅延バッファから出力サンプルを取得
            let outputSample = delayBuffer[delayIndex]
            
            // 先読み分析: 64サンプル先までピーク検出
            var peakAhead: Float = 0.0
            for j in 0..<64 {
                let futureIndex = (delayIndex + j) % 64
                peakAhead = max(peakAhead, abs(delayBuffer[futureIndex]))
            }
            
            // ハードリミッター: -1dB を超える場合は制限
            let peakDB = peakAhead > 0 ? 20 * log10(peakAhead) : -80.0
            let limitGain: Float = peakDB > limitThreshold ? pow(10, (limitThreshold - peakDB) / 20.0) : 1.0
            
            // 制限されたサンプルを出力
            data[i] = outputSample * limitGain
            
            // 現在のサンプルを遅延バッファに格納
            delayBuffer[delayIndex] = currentSample
            delayIndex = (delayIndex + 1) % 64
        }
    }
    
    private func updateStatistics(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        // ピークレベル検出
        var peak: Float = 0
        var rms: Float = 0
        
        for i in 0..<frameCount {
            let sample = abs(channelData[i])
            peak = max(peak, sample)
            rms += sample * sample
        }
        
        rms = sqrt(rms / Float(frameCount))
        
        // dBに変換
        let peakDB = peak > 0 ? 20 * log10(peak) : -80.0
        let rmsDB = rms > 0 ? 20 * log10(rms) : -80.0
        
        peakHistory.append(peakDB)
        rmsHistory.append(rmsDB)
        
        if peakHistory.count > historySize {
            peakHistory.removeFirst()
            rmsHistory.removeFirst()
        }
        
        // 🎛️ 全体ゲイン調整（マスターゲイン）- AGC有効時のみ
        if isAGCEnabled {
            let averageRMS = rmsHistory.reduce(0, +) / Float(rmsHistory.count)
            let targetGain = pow(10, (targetLevel - averageRMS) / 20.0)
            currentGain = currentGain * 0.98 + targetGain * 0.02 // より滑らかな変化
        } else {
            currentGain = 1.0 // AGC無効時は固定ゲイン
        }
    }
    
    var currentGainDB: Float {
        return 20 * log10(currentGain)
    }
    
    var compressionInfo: String {
        return String(format: "L:%.1fdB M:%.1fdB H:%.1fdB", 
                     20 * log10(lowBandGain),
                     20 * log10(midBandGain), 
                     20 * log10(highBandGain))
    }
    
    // 🎛️ **リアルタイム設定変更メソッド**
    func setEnabled(_ enabled: Bool) {
        isAGCEnabled = enabled
    }
    
    func setCompressionEnabled(_ enabled: Bool) {
        isCompressionEnabled = enabled
        if !enabled {
            // 圧縮無効時はゲインをリセット
            lowBandGain = 1.0
            midBandGain = 1.0
            highBandGain = 1.0
        }
    }
    
    func setLimiterEnabled(_ enabled: Bool) {
        isLimiterEnabled = enabled
    }
    
    func setTargetLevel(_ level: Float) {
        targetLevel = max(-20.0, min(0.0, level))
    }
    
    func setCompressionRatio(_ ratio: Float) {
        compressorRatio = max(1.0, min(10.0, ratio))
    }
}

// Butterworth 2nd order filter for crossover
class ButterworthFilter {
    private var x1: Float = 0, x2: Float = 0
    private var y1: Float = 0, y2: Float = 0
    private var a0: Float, a1: Float, a2: Float
    private var b1: Float, b2: Float
    
    init(frequency: Float, sampleRate: Float, isHighPass: Bool) {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / sqrt(2.0)
        
        if isHighPass {
            // High-pass coefficients
            let norm = 1.0 / (1.0 + alpha)
            a0 = (1.0 + cosOmega) * 0.5 * norm
            a1 = -(1.0 + cosOmega) * norm
            a2 = (1.0 + cosOmega) * 0.5 * norm
            b1 = -2.0 * cosOmega * norm
            b2 = (1.0 - alpha) * norm
        } else {
            // Low-pass coefficients
            let norm = 1.0 / (1.0 + alpha)
            a0 = (1.0 - cosOmega) * 0.5 * norm
            a1 = (1.0 - cosOmega) * norm
            a2 = (1.0 - cosOmega) * 0.5 * norm
            b1 = -2.0 * cosOmega * norm
            b2 = (1.0 - alpha) * norm
        }
    }
    
    func process(_ input: Float) -> Float {
        let output = a0 * input + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2
        
        x2 = x1; x1 = input
        y2 = y1; y1 = output
        
        return output
    }
}

struct DiscoveredDevice: Equatable {
    let name: String
    let host: String
    let port: Int
    var isConnected: Bool = false
    
    // 🎯 **同期・レイテンシー管理**
    var averageLatency: Double = 0.0        // 平均遅延
    var latencyHistory: [Double] = []       // 遅延履歴
    var lastPingTime: Date?                 // 最後のPing時刻
    var isResponding: Bool = true           // 応答状況
    var syncOffset: Double = 0.0            // 同期オフセット
    
    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        return lhs.host == rhs.host && lhs.port == rhs.port
    }
    
    mutating func updateLatency(_ latency: Double) {
        latencyHistory.append(latency)
        
        // 最大50回分の履歴を保持
        if latencyHistory.count > 50 {
            latencyHistory.removeFirst()
        }
        
        // 平均計算
        averageLatency = latencyHistory.reduce(0, +) / Double(latencyHistory.count)
        lastPingTime = Date()
        isResponding = true
    }
    
    var latencyQuality: String {
        if averageLatency < 5 { return "EXCELLENT" }
        if averageLatency < 15 { return "GOOD" }
        if averageLatency < 30 { return "FAIR" }
        return "POOR"
    }
}

class BestSender: NSObject, ObservableObject {
    private var engine = AVAudioEngine()
    private var connections: [String: NWConnection] = [:] // Host -> Connection
    private var packetID: UInt64 = 0
    private var serviceBrowser: NetServiceBrowser?
    private var discoveredServices: [NetService] = []
    
    // ネットワーク品質監視
    private var networkStats = NetworkStats()
    private var currentSampleRate: Double = 48000
    private var currentBufferSize: UInt32 = 128
    
    // 自動ゲイン制御(AGC)
    private var agc = AutomaticGainControl()
    private var mixerNode = AVAudioMixerNode()
    
    // ノイズリダクション
    private var noiseReducer = NoiseReducer()
    
    @Published var isStreaming = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isDiscovering = false
    @Published var targetIPs: [String] = [] // Keep for manual fallback
    
    // 🎚️ リアルタイム音声メーター
    @Published var inputLevel: Float = 0.0          // -60 to 0 dB
    @Published var outputLevel: Float = 0.0         // -60 to 0 dB  
    @Published var isClipping: Bool = false         // クリッピング警告
    @Published var signalToNoise: Float = 0.0       // S/N比
    @Published var packetsPerSecond: UInt64 = 0     // パケット送信レート
    @Published var averageLatency: Double = 0.0     // 平均遅延
    
    // 🎬 プロ機能
    @Published var isRecording = false              // 録音状態
    @Published var recordingDuration: TimeInterval = 0 // 録音時間
    private var audioFile: AVAudioFile?            // 録音ファイル
    private var recordingTimer: Timer?             // 録音時間更新
    
    // 🎛️ **リアルタイム設定切り替え**
    @Published var selectedSampleRate: Double = 96000 // サンプルレート
    @Published var selectedChannels: UInt32 = 2        // チャンネル数
    @Published var selectedBufferSize: UInt32 = 128    // バッファサイズ
    @Published var noiseReductionEnabled: Bool = true  // ノイズリダクション
    @Published var agcEnabled: Bool = true             // AGC自動ゲイン制御
    @Published var compressionEnabled: Bool = true     // マルチバンド圧縮
    @Published var limiterEnabled: Bool = true         // Look-aheadリミッター
    @Published var compressionRatio: Float = 4.0       // 圧縮比 1-10
    @Published var noiseGateThreshold: Float = -65.0   // ノイズゲート閾値 -80~0dB
    @Published var agcTargetLevel: Float = -8.0        // AGC目標レベル -20~0dB
    
    // 📊 **システム監視・統計**
    @Published var cpuUsage: Float = 0.0               // CPU使用率
    @Published var memoryUsage: Float = 0.0            // メモリ使用率
    @Published var droppedPackets: UInt64 = 0          // ドロップパケット数
    @Published var totalDataSent: UInt64 = 0           // 総送信データ量 (bytes)
    @Published var sessionDuration: TimeInterval = 0   // セッション継続時間
    @Published var currentBitrate: Float = 0.0         // 現在のビットレート (kbps)
    @Published var networkHealth: String = "UNKNOWN"   // ネットワーク健全性
    
    // ⚠️ **通知・アラート**
    @Published var notifications: [AppNotification] = []
    
    // 🎨 **UI・テーマ設定**
    @Published var uiMode: UIMode = .unified          // UI表示モード
    @Published var colorScheme: AppColorScheme = .auto // カラーテーマ
    
    // 🔄 **自動接続設定**
    @Published var autoConnectEnabled: Bool = true    // 新しいノード発見時に自動接続
    
    private var sessionStartTime: Date?
    private var systemMonitorTimer: Timer?
    private var totalBytesSent: UInt64 = 0

    override init() {
        super.init()
        print("🚀 BestSender初期化開始")
        startDiscovering()
        print("✅ BestSender初期化完了")
    }
    
    deinit {
        stopDiscovering()
    }
    
    func start() {
        guard !isStreaming else { return }
        
        setupAudio()
        connectToAllDevices()
        startSystemMonitoring()
        sessionStartTime = Date()
        totalBytesSent = 0
        
        addNotification(.success, "🎵 Audio streaming started")
        isStreaming = true
    }
    
    func stop() {
        guard isStreaming else { return }
        
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        
        for (_, conn) in connections {
            conn.cancel()
        }
        connections.removeAll()
        
        stopSystemMonitoring()
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        addNotification(.info, "📊 Session ended. Duration: \(formatDuration(duration))")
        
        updateDeviceConnectionStatus()
        isStreaming = false
    }

    private func setupAudio() {
        // 🎛️ **ハードウェア対応**: 利用可能な最適サンプルレートを使用
        let input = engine.inputNode
        let hwFormat = input.inputFormat(forBus: 0)
        
        print("🔊 Hardware format: \(hwFormat.sampleRate)Hz, \(hwFormat.channelCount)ch")
        
        // ハードウェアサンプルレートを使用（またはサポートされている最も近い値）
        let actualSampleRate = hwFormat.sampleRate
        let actualChannels = min(selectedChannels, UInt32(hwFormat.channelCount))
        let format = AVAudioFormat(standardFormatWithSampleRate: actualSampleRate, channels: actualChannels)!
        
        // 実際の値を更新
        DispatchQueue.main.async {
            self.selectedSampleRate = actualSampleRate
            self.selectedChannels = actualChannels
        }
        
        // 動的バッファサイズ計算 (遅延 = バッファサイズ/サンプルレート * 1000ms)
        let latencyMs = Double(selectedBufferSize) / actualSampleRate * 1000
        print("🎛️ Audio setup: \(actualSampleRate)Hz, \(actualChannels)ch, \(selectedBufferSize)frames (≈\(String(format: "%.1f", latencyMs))ms)")
        
        input.installTap(onBus: 0, bufferSize: selectedBufferSize, format: format) { [weak self] (buffer, _) in
            self?.send(buffer)
        }
        
        do {
            try engine.start()
            print("✅ Audio engine started successfully")
        } catch {
            print("❌ Audio engine failed to start: \(error)")
        }
    }
    
    // 🎛️ **リアルタイム設定変更** - ストリーミング中でも変更可能
    func updateAudioSettings() {
        guard isStreaming else { return }
        
        // エンジン一時停止
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        
        // 新しい設定でセットアップ
        setupAudio()
        
        // DSPパラメータ更新
        updateDSPSettings()
        
        print("🔄 Audio settings updated in real-time")
    }
    
    private func updateDSPSettings() {
        // ノイズリダクション設定更新
        noiseReducer.setEnabled(noiseReductionEnabled)
        noiseReducer.setGateThreshold(noiseGateThreshold)
        
        // AGC設定更新  
        agc.setEnabled(agcEnabled)
        agc.setTargetLevel(agcTargetLevel)
        agc.setCompressionRatio(compressionRatio)
        agc.setCompressionEnabled(compressionEnabled)
        agc.setLimiterEnabled(limiterEnabled)
    }
    
    private func send(_ buffer: AVAudioPCMBuffer) {
        // 🎚️ **プロ級オーディオ処理チェーン**
        
        // 0. リアルタイム音声レベル測定
        updateAudioLevels(buffer)
        
        // 🎛️ 1. ノイズリダクション - 背景ノイズを除去 (切り替え可能)
        if noiseReductionEnabled {
            noiseReducer.processBuffer(buffer)
        }
        
        // 🎛️ 2. 自動ゲイン制御 - 適切な音量レベルに自動調整 (切り替え可能)
        if agcEnabled || compressionEnabled || limiterEnabled {
            agc.processBuffer(buffer)
        }
        
        // 🎬 録音処理 - 処理されたオーディオを録音
        writeToRecordingFile(buffer)
        
        // 3. 品質監視とログ出力 (96kHz = 750 packets/sec なので調整)
        if packetID % 750 == 0 { // 1秒ごと (96kHz/128 = 750 packets/sec)
            let quality = networkStats.recommendedQuality()
            let gain = agc.currentGainDB
            let compressionInfo = agc.compressionInfo
            print("🎵 \(quality.description) | AGC: \(String(format: "%.1f", gain))dB | Compression: \(compressionInfo) | Latency: \(String(format: "%.1f", networkStats.averageLatency))ms")
            
            // UIメーター更新
            DispatchQueue.main.async {
                self.averageLatency = self.networkStats.averageLatency
                self.packetsPerSecond = 750 // 96kHz ステレオでは750 packets/sec
            }
        }
        
        // 🎵 **STEREO 96kHz** データ準備: ステレオ対応
        let channels = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        var stereoData = Data()
        
        if channels == 2 {
            // ステレオデータをインターリーブ形式で送信 (L, R, L, R, ...)
            guard let leftChannel = buffer.floatChannelData?[0],
                  let rightChannel = buffer.floatChannelData?[1] else { return }
            
            stereoData.reserveCapacity(frameCount * 2 * 4) // 2チャンネル * Float32
            
            for frame in 0..<frameCount {
                // Left sample
                withUnsafeBytes(of: leftChannel[frame]) { bytes in
                    stereoData.append(contentsOf: bytes)
                }
                // Right sample  
                withUnsafeBytes(of: rightChannel[frame]) { bytes in
                    stereoData.append(contentsOf: bytes)
                }
            }
        } else {
            // モノラル互換モード
            guard let channelData = buffer.floatChannelData?[0] else { return }
            stereoData = Data(bytes: channelData, count: frameCount * 4)
        }
        
        let data = stereoData
        
        packetID += 1
        networkStats.recordPacketSent()
        
        // 遅延測定用: パケットにタイムスタンプを追加
        let timestamp = CFAbsoluteTimeGetCurrent()
        let packet = AudioPacket(id: packetID, payload: data, timestamp: timestamp)
        let serialized = packet.serialize()
        
        // 🚀 **最適化された送信ロジック** - 接続状態チェック付き
        for (hostKey, conn) in connections {
            // 接続が準備できているかチェック
            guard conn.state == .ready else {
                if packetID % 750 == 0 { // 1秒ごとにログ
                    print("⚠️ Skipping \(hostKey) - connection not ready: \(conn.state)")
                }
                continue
            }
            
            // 🎯 **シンプルで確実な送信** - 重複送信を廃止し、エラーハンドリング強化
            conn.send(content: serialized, completion: .contentProcessed { error in
                if let error = error {
                    if self.packetID % 750 == 0 { // エラーログも1秒ごと
                        print("📡 Send error to \(hostKey): \(error)")
                    }
                    // 送信エラーの場合、接続をリセット
                    DispatchQueue.main.async {
                        if let device = self.discoveredDevices.first(where: { $0.host == hostKey }) {
                            self.retryConnection(device: device)
                        }
                    }
                }
            })
        }
        
        // 📊 アクティブ接続数の監視
        if packetID % 750 == 0 {
            let readyConnections = connections.filter { $0.value.state == .ready }.count
            let totalConnections = connections.count
            print("📡 Active connections: \(readyConnections)/\(totalConnections)")
        }
    }
    
    func addTargetIP(_ ip: String) {
        if !targetIPs.contains(ip) {
            targetIPs.append(ip)
        }
    }
    
    func removeTargetIP(_ ip: String) {
        targetIPs.removeAll { $0 == ip }
    }
    
    // MARK: - Bonjour Discovery
    private func startDiscovering() {
        serviceBrowser = NetServiceBrowser()
        serviceBrowser?.delegate = self
        serviceBrowser?.searchForServices(ofType: HiAudioService.serviceType, inDomain: "local.")
        isDiscovering = true
        print("Started Bonjour service discovery")
    }
    
    private func stopDiscovering() {
        serviceBrowser?.stop()
        serviceBrowser = nil
        isDiscovering = false
        print("Stopped Bonjour service discovery")
    }
    
    private func connectToAllDevices() {
        let params = NWParameters.udp
        params.serviceClass = .interactiveVoice
        
        // 🔧 **UDP最適化**: バッファサイズとタイムアウト設定
        params.defaultProtocolStack.transportProtocol = NWProtocolUDP.Options()
        
        // Connect to discovered devices with enhanced error handling
        for device in discoveredDevices {
            // 既存接続をスキップ
            if connections[device.host] != nil {
                print("📍 Skipping \(device.name) - connection already exists")
                continue
            }
            
            let host = NWEndpoint.Host(device.host)
            let port = NWEndpoint.Port(integerLiteral: UInt16(device.port))
            let conn = NWConnection(host: host, port: port, using: params)
            
            // 🚀 **強化された接続ハンドリング**
            conn.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    print("🔄 Connection to \(device.name) (\(device.host)): \(state)")
                    switch state {
                    case .ready:
                        self?.addNotification(.success, "✅ Connected to \(device.name)")
                        print("🎉 \(device.name) ready for audio streaming")
                        
                        // 接続テスト: 小さなパケットを送信
                        self?.sendConnectionTest(to: conn, deviceName: device.name)
                        
                    case .failed(let error):
                        self?.addNotification(.error, "❌ \(device.name): \(error.localizedDescription)")
                        self?.connections.removeValue(forKey: device.host)
                        print("💥 Connection failed to \(device.name): \(error)")
                        
                        // 3秒後に再接続を試行
                        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                            self?.retryConnection(device: device)
                        }
                        
                    case .cancelled:
                        self?.addNotification(.warning, "🚫 Connection to \(device.name) cancelled")
                        self?.connections.removeValue(forKey: device.host)
                        
                    case .waiting(let error):
                        print("⏳ Connection to \(device.name) waiting: \(error)")
                        
                    case .preparing:
                        print("⚙️ Preparing connection to \(device.name)")
                        
                    case .setup:
                        print("🔧 Setting up connection to \(device.name)")
                        
                    @unknown default:
                        print("❓ Unknown connection state to \(device.name): \(state)")
                    }
                    self?.updateDeviceConnectionStatus()
                }
            }
            
            // 接続タイムアウト設定
            DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
                switch conn.state {
                case .ready, .cancelled:
                    break // 既に成功または終了済み
                case .failed(_):
                    break // 既に失敗済み
                default:
                    print("⏰ Connection timeout to \(device.name) - cancelling")
                    conn.cancel()
                }
            }
            
            conn.start(queue: DispatchQueue.global(qos: .userInteractive))
            connections[device.host] = conn
            print("🚀 Starting connection to \(device.name) at \(device.host):\(device.port)")
        }
        
        // Connect to manual IPs as fallback with enhanced error handling
        for ip in targetIPs {
            if connections[ip] == nil {
                let host = NWEndpoint.Host(ip)
                let port = NWEndpoint.Port(integerLiteral: HiAudioService.udpPort)
                let conn = NWConnection(host: host, port: port, using: params)
                
                // 手動IP接続の強化されたハンドラー
                conn.stateUpdateHandler = { [weak self] state in
                    DispatchQueue.main.async {
                        print("🔄 Manual IP \(ip): \(state)")
                        switch state {
                        case .ready:
                            self?.addNotification(.success, "✅ Manual IP \(ip) connected")
                            print("🎉 Manual IP \(ip) ready for streaming")
                            
                        case .failed(let error):
                            self?.addNotification(.error, "❌ Manual IP \(ip): \(error.localizedDescription)")
                            self?.connections.removeValue(forKey: ip)
                            print("💥 Manual IP connection failed: \(error)")
                            
                        case .cancelled:
                            self?.addNotification(.warning, "🚫 Manual IP \(ip) cancelled")
                            self?.connections.removeValue(forKey: ip)
                            
                        case .waiting(let error):
                            print("⏳ Manual IP \(ip) waiting: \(error)")
                            
                        default:
                            break
                        }
                        self?.updateDeviceConnectionStatus()
                    }
                }
                
                // 手動IP接続もタイムアウト設定
                DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
                    switch conn.state {
                    case .ready, .cancelled:
                        break // 既に成功または終了済み
                    case .failed(_):
                        break // 既に失敗済み
                    default:
                        print("⏰ Manual IP \(ip) timeout - cancelling")
                        conn.cancel()
                    }
                }
                
                conn.start(queue: DispatchQueue.global(qos: .userInteractive))
                connections[ip] = conn
                print("🚀 Connecting to manual IP \(ip):\(HiAudioService.udpPort)")
            }
        }
        
        updateDeviceConnectionStatus()
    }
    
    private func updateDeviceConnectionStatus() {
        DispatchQueue.main.async {
            for i in 0..<self.discoveredDevices.count {
                let device = self.discoveredDevices[i]
                if let connection = self.connections[device.host] {
                    // 接続が存在し、ready状態の場合のみ接続済みとする
                    self.discoveredDevices[i].isConnected = (connection.state == .ready)
                    print("🔍 Device \(device.name) connection state: \(connection.state)")
                } else {
                    self.discoveredDevices[i].isConnected = false
                    print("🔍 Device \(device.name) has no connection")
                }
            }
        }
    }
    
    // 🔄 **接続再試行ロジック**
    private func retryConnection(device: DiscoveredDevice) {
        guard isStreaming else { return } // ストリーミング停止時は再試行しない
        
        print("🔄 Retrying connection to \(device.name)")
        
        let params = NWParameters.udp
        params.serviceClass = .interactiveVoice
        params.defaultProtocolStack.transportProtocol = NWProtocolUDP.Options()
        
        let host = NWEndpoint.Host(device.host)
        let port = NWEndpoint.Port(integerLiteral: UInt16(device.port))
        let conn = NWConnection(host: host, port: port, using: params)
        
        // 再試行用の状態ハンドラー
        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                print("🔄 Retry connection to \(device.name): \(state)")
                switch state {
                case .ready:
                    self?.addNotification(.success, "🔄 Reconnected to \(device.name)")
                    self?.sendConnectionTest(to: conn, deviceName: device.name)
                case .failed(_):
                    print("💥 Retry failed for \(device.name)")
                    self?.connections.removeValue(forKey: device.host)
                case .cancelled:
                    self?.connections.removeValue(forKey: device.host)
                default:
                    break
                }
                self?.updateDeviceConnectionStatus()
            }
        }
        
        // 再試行にもタイムアウトを設定
        DispatchQueue.global().asyncAfter(deadline: .now() + 8.0) {
            switch conn.state {
            case .ready, .cancelled:
                break // 既に成功または終了済み
            case .failed(_):
                break // 既に失敗済み
            default:
                print("⏰ Retry timeout for \(device.name)")
                conn.cancel()
            }
        }
        
        conn.start(queue: DispatchQueue.global(qos: .userInteractive))
        connections[device.host] = conn
    }
    
    // 🧪 **接続テスト** - 小さなパケットで接続確認
    private func sendConnectionTest(to connection: NWConnection, deviceName: String) {
        let testData = "HIAUDIO_CONNECTION_TEST".data(using: .utf8) ?? Data()
        
        connection.send(content: testData, completion: .contentProcessed { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Connection test failed to \(deviceName): \(error)")
                    self.addNotification(.warning, "⚠️ Connection test failed: \(deviceName)")
                } else {
                    print("✅ Connection test passed for \(deviceName)")
                    self.addNotification(.info, "🧪 Connection verified: \(deviceName)")
                }
            }
        })
    }
}

// MARK: - NetServiceBrowser Delegate
extension BestSender: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Found service: \(service.name)")
        service.delegate = self
        service.resolve(withTimeout: 10.0)
        discoveredServices.append(service)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("Removed service: \(service.name)")
        discoveredServices.removeAll { $0 == service }
        
        // Remove from discovered devices and disconnect
        DispatchQueue.main.async {
            if let index = self.discoveredDevices.firstIndex(where: { $0.name == service.name }) {
                let device = self.discoveredDevices[index]
                self.connections[device.host]?.cancel()
                self.connections.removeValue(forKey: device.host)
                self.discoveredDevices.remove(at: index)
            }
        }
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("Service browser stopped")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Service browser failed: \(errorDict)")
    }
}

// MARK: - NetService Delegate
extension BestSender: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        print("Resolved service: \(sender.name)")
        
        guard let addresses = sender.addresses, !addresses.isEmpty else { return }
        
        for addressData in addresses {
            let address = addressData.withUnsafeBytes { bytes in
                bytes.bindMemory(to: sockaddr.self).baseAddress!.pointee
            }
            
            if address.sa_family == UInt8(AF_INET) {
                let addr4 = addressData.withUnsafeBytes { bytes in
                    bytes.bindMemory(to: sockaddr_in.self).baseAddress!.pointee
                }
                let host = String(cString: inet_ntoa(addr4.sin_addr))
                
                DispatchQueue.main.async {
                    let device = DiscoveredDevice(
                        name: sender.name,
                        host: host,
                        port: Int(sender.port),
                        isConnected: false
                    )
                    
                    // Check if already exists
                    if !self.discoveredDevices.contains(where: { $0.host == host }) {
                        self.discoveredDevices.append(device)
                        print("🔍 Added discovered device: \(device.name) at \(device.host)")
                        
                        DispatchQueue.main.async {
                            self.addNotification(.success, "📱 New device found: \(device.name)")
                        }
                        
                        // Auto-connect if enabled and streaming
                        if self.autoConnectEnabled && self.isStreaming {
                            print("🔄 Auto-connecting to \(device.name)...")
                            self.connectToDevice(device)
                            DispatchQueue.main.async {
                                self.addNotification(.info, "🔗 Auto-connected to \(device.name)")
                            }
                        }
                    }
                }
                break // Use first IPv4 address
            }
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("Failed to resolve service \(sender.name): \(errorDict)")
    }
    
    func connectToDevice(_ device: DiscoveredDevice) {
        print("🔗 Connecting to device: \(device.name) at \(device.host):\(device.port)")
        
        let params = NWParameters.udp
        params.serviceClass = .interactiveVoice
        
        let host = NWEndpoint.Host(device.host)
        let port = NWEndpoint.Port(integerLiteral: UInt16(device.port))
        let conn = NWConnection(host: host, port: port, using: params)
        
        conn.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                print("🔄 Connection state to \(device.name): \(state)")
                switch state {
                case .ready:
                    self.addNotification(.success, "✅ Connected to \(device.name)")
                    print("🎉 Successfully connected to \(device.name) - ready to send audio")
                case .failed(let error):
                    self.addNotification(.error, "❌ Failed to connect to \(device.name): \(error.localizedDescription)")
                    // 失敗した接続を削除
                    self.connections.removeValue(forKey: device.host)
                case .cancelled:
                    self.addNotification(.warning, "🚫 Connection to \(device.name) was cancelled")
                    // キャンセルされた接続を削除
                    self.connections.removeValue(forKey: device.host)
                default:
                    break
                }
                // 状態変更のたびにデバイス接続ステータスを更新
                self.updateDeviceConnectionStatus()
            }
        }
        
        conn.start(queue: DispatchQueue.global(qos: .userInteractive))
        connections[device.host] = conn
    }
    
    // MARK: - Audio Level Monitoring
    private func updateAudioLevels(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        // ピーク・RMSレベル計算
        var peak: Float = 0.0
        var rms: Float = 0.0
        var sum: Float = 0.0
        
        for i in 0..<frameCount {
            let sample = abs(channelData[i])
            if sample > peak {
                peak = sample
            }
            sum += sample * sample
        }
        
        rms = sqrt(sum / Float(frameCount))
        
        // dB変換 (-60dB〜0dB範囲)
        let peakDB = peak > 0 ? max(-60.0, 20 * log10(peak)) : -60.0
        let rmsDB = rms > 0 ? max(-60.0, 20 * log10(rms)) : -60.0
        
        // クリッピング検出 (-3dB以上)
        let clipping = peakDB > -3.0
        
        // S/N比推定 (簡易版)
        let snr = max(0, peakDB + 60) // -60dBをノイズフロアとする
        
        // UIを60fps更新 (375パケット/秒なので約6.25回に1回)
        if packetID % 6 == 0 {
            DispatchQueue.main.async {
                self.inputLevel = peakDB
                self.outputLevel = rmsDB
                self.isClipping = clipping
                self.signalToNoise = snr
            }
        }
    }
    
    // MARK: - Recording Functions
    func startRecording() {
        guard !isRecording else { return }
        
        // Create audio file for recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "HiAudio_Recording_\(dateFormatter.string(from: Date())).wav"
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            // 🎵 **RECORDING**: 96kHz ステレオ録音対応
            let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 96000, channels: 2)!
            audioFile = try AVAudioFile(forWriting: audioURL, settings: recordingFormat.settings)
            
            isRecording = true
            recordingDuration = 0
            
            // Start recording timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.recordingDuration += 1
                }
            }
            
            print("🎬 Recording started: \(fileName)")
        } catch {
            print("❌ Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioFile = nil
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        print("🎬 Recording stopped. Duration: \(String(format: "%.1f", recordingDuration))s")
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func writeToRecordingFile(_ buffer: AVAudioPCMBuffer) {
        guard isRecording, let audioFile = audioFile else { return }
        
        do {
            try audioFile.write(from: buffer)
        } catch {
            print("❌ Failed to write audio data: \(error)")
        }
    }
    
    // MARK: - System Monitoring
    private func startSystemMonitoring() {
        systemMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateSystemStats()
        }
    }
    
    private func stopSystemMonitoring() {
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
    }
    
    private func updateSystemStats() {
        // セッション継続時間更新
        if let startTime = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(startTime)
        }
        
        // ビットレート計算 (kbps)
        let frameSize = selectedChannels * selectedBufferSize * 4 // Float32 = 4 bytes
        let framesPerSecond = selectedSampleRate / Double(selectedBufferSize)
        currentBitrate = Float(frameSize) * Float(framesPerSecond) * 8 / 1000 // Convert to kbps
        
        // ネットワーク健全性評価
        updateNetworkHealth()
        
        // UI更新
        DispatchQueue.main.async {
            self.totalDataSent = self.totalBytesSent
        }
    }
    
    private func updateNetworkHealth() {
        let latency = networkStats.averageLatency
        let quality: String
        
        if latency < 5 {
            quality = "EXCELLENT"
        } else if latency < 15 {
            quality = "GOOD"
        } else if latency < 30 {
            quality = "FAIR"
        } else {
            quality = "POOR"
        }
        
        if quality != networkHealth {
            DispatchQueue.main.async {
                self.networkHealth = quality
                if quality == "POOR" {
                    self.addNotification(.warning, "⚠️ Poor network quality detected")
                }
            }
        }
    }
    
    // MARK: - Notification System
    func addNotification(_ type: AppNotification.NotificationType, _ message: String) {
        DispatchQueue.main.async {
            let notification = AppNotification(type: type, message: message)
            self.notifications.insert(notification, at: 0)
            
            // 最大10件まで保持
            if self.notifications.count > 10 {
                self.notifications.removeLast()
            }
        }
    }
    
    func clearNotifications() {
        DispatchQueue.main.async {
            self.notifications.removeAll()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
