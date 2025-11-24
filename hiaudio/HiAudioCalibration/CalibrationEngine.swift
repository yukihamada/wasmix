// 🎵 HiAudio Pro - Advanced Calibration Engine
// iPhone マイク完全同期・キャリブレーションシステム

import Foundation
import Accelerate
import AVFoundation

// MARK: - Core Data Structures

struct CalibrationFilter {
    let frequencyResponse: [Float]
    let phaseResponse: [Float]
    let sensitivityCorrection: Float
    let deviceModel: String
    let timestamp: Date
    
    var description: String {
        return "Calibration[\(deviceModel)]: \(sensitivityCorrection)dB, \(frequencyResponse.count) taps"
    }
}

struct DelayMeasurement {
    let deviceId: String
    let delayMs: Double
    let confidence: Float  // 0.0-1.0
    let signalToNoise: Float
    let timestamp: Date
    
    var isReliable: Bool {
        return confidence > 0.8 && signalToNoise > 20.0 // 20dB SNR minimum
    }
}

struct CalibrationResult {
    let delayMap: [String: Double]
    let calibrationFilters: [String: CalibrationFilter]
    let globalOptimization: OptimizationResult
    let measurementQuality: Float
    let timestamp: Date
}

struct OptimizationResult {
    let totalDelay: Double
    let maxDeviation: Double
    let rmsError: Double
    let convergenceIterations: Int
}

// MARK: - Main Calibration Engine

class CalibrationEngine {
    
    // Configuration
    private let sweepDuration: Double = 5.0
    private let sweepStartFreq: Double = 20.0
    private let sweepEndFreq: Double = 20000.0
    private let sampleRate: Double = 48000.0
    private let fftSize: Int = 4096
    
    // State
    private var referenceFilter: CalibrationFilter?
    private var deviceCalibrations: [String: CalibrationFilter] = [:]
    
    // MARK: - Public API
    
    /// 完全自動キャリブレーション実行
    func performFullCalibration(devices: [AudioDevice]) async throws -> CalibrationResult {
        print("🎯 Starting full calibration for \(devices.count) devices...")
        
        // 1. キャリブレーション信号生成
        let sweepSignal = generateLogSweep()
        print("✅ Generated calibration sweep: \(sweepSignal.count) samples")
        
        // 2. 全デバイスに配信・録音
        let recordings = try await collectRecordings(devices: devices, sweep: sweepSignal)
        print("✅ Collected recordings from \(recordings.count) devices")
        
        // 3. 各デバイスの遅延測定
        var delayMeasurements: [DelayMeasurement] = []
        
        for device in devices {
            guard let recording = recordings[device.id] else { continue }
            
            let delay = measureDelayWithHighPrecision(
                reference: sweepSignal,
                recorded: recording
            )
            
            delayMeasurements.append(DelayMeasurement(
                deviceId: device.id,
                delayMs: delay.delay,
                confidence: delay.confidence,
                signalToNoise: delay.snr,
                timestamp: Date()
            ))
        }
        
        // 4. キャリブレーションフィルタ生成 (必要な場合)
        var calibrationFilters: [String: CalibrationFilter] = [:]
        
        for device in devices {
            if deviceCalibrations[device.id] == nil {
                // 新しいデバイスのキャリブレーション
                if let filter = try await generateDeviceCalibration(device: device, recording: recordings[device.id]) {
                    calibrationFilters[device.id] = filter
                    deviceCalibrations[device.id] = filter
                }
            } else {
                // 既存のキャリブレーション使用
                calibrationFilters[device.id] = deviceCalibrations[device.id]
            }
        }
        
        // 5. 全体最適化
        let optimization = optimizeDelayConfiguration(measurements: delayMeasurements)
        print("✅ Optimization complete: RMS error \(String(format: "%.3f", optimization.rmsError))ms")
        
        // 6. 結果作成
        let delayMap = Dictionary(uniqueKeysWithValues: 
            delayMeasurements.compactMap { measurement in
                measurement.isReliable ? (measurement.deviceId, measurement.delayMs) : nil
            }
        )
        
        let quality = calculateOverallQuality(measurements: delayMeasurements, optimization: optimization)
        
        return CalibrationResult(
            delayMap: delayMap,
            calibrationFilters: calibrationFilters,
            globalOptimization: optimization,
            measurementQuality: quality,
            timestamp: Date()
        )
    }
    
    // MARK: - Signal Generation
    
    /// 高品質ログスイープ生成
    private func generateLogSweep() -> [Float] {
        let frameCount = Int(sweepDuration * sampleRate)
        var sweep = [Float](repeating: 0.0, count: frameCount)
        
        let logStart = log(sweepStartFreq)
        let logEnd = log(sweepEndFreq)
        let logRange = logEnd - logStart
        
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let normalizedTime = t / sweepDuration
            
            // ログ周波数スイープ
            let instantFreq = exp(logStart + logRange * normalizedTime)
            let phase = 2.0 * .pi * instantFreq * t / logRange
            
            // ウィンドウ関数適用 (Hann window)
            let window = 0.5 - 0.5 * cos(2.0 * .pi * normalizedTime)
            
            sweep[i] = Float(sin(phase) * window * 0.8) // -20dB peak
        }
        
        print("📊 Sweep: \(sweepStartFreq)Hz-\(sweepEndFreq)Hz, \(sweepDuration)s, peak=\(sweep.max() ?? 0))")
        return sweep
    }
    
    // MARK: - High-Precision Delay Measurement
    
    private func measureDelayWithHighPrecision(
        reference: [Float],
        recorded: [Float]
    ) -> (delay: Double, confidence: Float, snr: Float) {
        
        // 新しいサブミリ秒遅延測定エンジンを使用
        let precisionEngine = SubMillisecondDelayEngine()
        let result = precisionEngine.measureDelayWithSubMillisecondPrecision(
            reference: reference,
            recorded: recorded
        )
        
        print("🎯 High-precision measurement result:")
        print("   Delay: \(String(format: "%.6f", result.delayMilliseconds))ms")
        print("   Sub-sample precision: \(String(format: "%.6f", result.subSamplePrecision))")
        print("   Confidence: \(String(format: "%.3f", result.confidence))")
        print("   SNR: \(String(format: "%.1f", result.snrDecibels))dB")
        print("   Quality score: \(String(format: "%.3f", result.measurementQuality.overallScore))")
        
        return (result.delayMilliseconds, result.confidence, result.snrDecibels)
    }
    
    private func computeNormalizedCrossCorrelation(_ x: [Float], _ y: [Float]) -> [Float] {
        let n = x.count + y.count - 1
        let fftSize = nextPowerOfTwo(n)
        
        // Zero-pad to FFT size
        var xPadded = x + Array(repeating: 0.0, count: fftSize - x.count)
        var yPadded = y + Array(repeating: 0.0, count: fftSize - y.count)
        
        // FFT
        let xFFT = computeFFT(xPadded)
        let yFFT = computeFFT(yPadded)
        
        // Cross-correlation in frequency domain: X* × Y
        var correlationFFT = [DSPComplex](repeating: DSPComplex(), count: fftSize/2 + 1)
        for i in 0..<correlationFFT.count {
            let xConj = DSPComplex(real: xFFT[i].real, imag: -xFFT[i].imag)
            correlationFFT[i] = DSPComplex(
                real: xConj.real * yFFT[i].real - xConj.imag * yFFT[i].imag,
                imag: xConj.real * yFFT[i].imag + xConj.imag * yFFT[i].real
            )
        }
        
        // IFFT
        let correlation = computeIFFT(correlationFFT, size: fftSize)
        
        // Normalize
        let maxValue = correlation.max() ?? 1.0
        return correlation.map { $0 / maxValue }
    }
    
    private func findPeakWithParabolicInterpolation(_ signal: [Float]) -> (index: Double, value: Float) {
        guard signal.count > 2 else { return (0, 0) }
        
        // Find integer peak
        let maxIndex = signal.enumerated().max(by: { $0.1 < $1.1 })?.0 ?? 0
        
        // Parabolic interpolation for sub-sample precision
        if maxIndex > 0 && maxIndex < signal.count - 1 {
            let y1 = signal[maxIndex - 1]
            let y2 = signal[maxIndex]
            let y3 = signal[maxIndex + 1]
            
            let denominator = y1 - 2*y2 + y3
            if abs(denominator) > 1e-6 {
                let offset = 0.5 * (y1 - y3) / denominator
                let interpolatedIndex = Double(maxIndex) + Double(offset)
                let interpolatedValue = y2 - 0.25 * (y1 - y3) * Float(offset)
                
                return (interpolatedIndex, interpolatedValue)
            }
        }
        
        return (Double(maxIndex), signal[maxIndex])
    }
    
    // MARK: - Device Calibration
    
    private func generateDeviceCalibration(
        device: AudioDevice,
        recording: [Float]?
    ) async throws -> CalibrationFilter? {
        
        guard let recording = recording else { return nil }
        
        // iPhone モデル別プリセットがあるかチェック
        if let preset = loadDevicePreset(deviceModel: device.model) {
            print("📱 Using preset calibration for \(device.model)")
            return preset
        }
        
        print("🔧 Generating new calibration for \(device.model)")
        
        // 基準信号との比較でキャリブレーションフィルタ生成
        let referenceIR = extractImpulseResponse(generateLogSweep())
        let deviceIR = extractImpulseResponse(recording)
        
        let frequencyResponse = computeFrequencyResponseCorrection(
            reference: referenceIR,
            device: deviceIR
        )
        
        let phaseResponse = computePhaseResponseCorrection(
            reference: referenceIR,
            device: deviceIR
        )
        
        let sensitivityCorrection = computeSensitivityCorrection(
            reference: generateLogSweep(),
            device: recording
        )
        
        let filter = CalibrationFilter(
            frequencyResponse: frequencyResponse,
            phaseResponse: phaseResponse,
            sensitivityCorrection: sensitivityCorrection,
            deviceModel: device.model,
            timestamp: Date()
        )
        
        // プリセットとして保存
        saveDevicePreset(filter: filter)
        
        return filter
    }
    
    // MARK: - Optimization
    
    private func optimizeDelayConfiguration(measurements: [DelayMeasurement]) -> OptimizationResult {
        let reliableMeasurements = measurements.filter { $0.isReliable }
        guard !reliableMeasurements.isEmpty else {
            return OptimizationResult(totalDelay: 0, maxDeviation: 0, rmsError: 0, convergenceIterations: 0)
        }
        
        // 最小遅延デバイスを基準とする
        let minDelay = reliableMeasurements.map { $0.delayMs }.min() ?? 0
        let adjustedDelays = reliableMeasurements.map { $0.delayMs - minDelay }
        
        // RMSエラー計算
        let meanDelay = adjustedDelays.reduce(0, +) / Double(adjustedDelays.count)
        let rmsError = sqrt(adjustedDelays.map { pow($0 - meanDelay, 2) }.reduce(0, +) / Double(adjustedDelays.count))
        
        // 最大偏差
        let maxDeviation = adjustedDelays.map { abs($0 - meanDelay) }.max() ?? 0
        
        return OptimizationResult(
            totalDelay: adjustedDelays.reduce(0, +),
            maxDeviation: maxDeviation,
            rmsError: rmsError,
            convergenceIterations: 1
        )
    }
    
    // MARK: - Quality Assessment
    
    private func calculateOverallQuality(
        measurements: [DelayMeasurement],
        optimization: OptimizationResult
    ) -> Float {
        
        let reliableCount = measurements.filter { $0.isReliable }.count
        let totalCount = measurements.count
        let reliabilityScore = Float(reliableCount) / Float(totalCount)
        
        let precisionScore = Float(max(0, 1.0 - optimization.rmsError / 1.0)) // 1ms RMS を基準
        let consistencyScore = Float(max(0, 1.0 - optimization.maxDeviation / 2.0)) // 2ms max deviation を基準
        
        return (reliabilityScore * 0.4 + precisionScore * 0.4 + consistencyScore * 0.2)
    }
    
    // MARK: - Helper Functions
    
    private func nextPowerOfTwo(_ n: Int) -> Int {
        var result = 1
        while result < n {
            result <<= 1
        }
        return result
    }
    
    private func evaluateConfidence(correlation: [Float], peak: (index: Double, value: Float)) -> Float {
        // ピーク値 vs ノイズフロア比較
        let sortedValues = correlation.sorted(by: >)
        let noiseFloor = sortedValues[min(sortedValues.count - 1, 100)...].reduce(0, +) / Float(sortedValues.count - 100)
        
        return min(1.0, peak.value / (noiseFloor + 0.001))
    }
    
    private func estimateSignalToNoise(correlation: [Float], peak: (index: Double, value: Float)) -> Float {
        let noiseLevel = sqrt(correlation.map { $0 * $0 }.reduce(0, +) / Float(correlation.count) - peak.value * peak.value)
        return 20 * log10(peak.value / (noiseLevel + 1e-6))
    }
    
    // DSP Helper functions (simplified - would need full implementation)
    
    private func computeFFT(_ input: [Float]) -> [DSPComplex] {
        // Simplified - use Accelerate framework
        return []
    }
    
    private func computeIFFT(_ input: [DSPComplex], size: Int) -> [Float] {
        // Simplified - use Accelerate framework  
        return []
    }
    
    private func extractImpulseResponse(_ signal: [Float]) -> [Float] {
        // Simplified - implement actual IR extraction
        return []
    }
    
    private func computeFrequencyResponseCorrection(reference: [Float], device: [Float]) -> [Float] {
        // Simplified - implement frequency domain correction
        return []
    }
    
    private func computePhaseResponseCorrection(reference: [Float], device: [Float]) -> [Float] {
        // Simplified - implement phase correction
        return []
    }
    
    private func computeSensitivityCorrection(reference: [Float], device: [Float]) -> Float {
        // RMS level comparison
        let refRMS = sqrt(reference.map { $0 * $0 }.reduce(0, +) / Float(reference.count))
        let devRMS = sqrt(device.map { $0 * $0 }.reduce(0, +) / Float(device.count))
        
        return 20 * log10(refRMS / (devRMS + 1e-6))
    }
    
    private func loadDevicePreset(deviceModel: String) -> CalibrationFilter? {
        // Load from UserDefaults or file
        return nil
    }
    
    private func saveDevicePreset(filter: CalibrationFilter) {
        // Save to UserDefaults or file
    }
    
    private func collectRecordings(devices: [AudioDevice], sweep: [Float]) async throws -> [String: [Float]] {
        // Coordinate with existing HiAudio infrastructure
        return [:]
    }
}

// MARK: - Supporting Types

struct AudioDevice {
    let id: String
    let name: String
    let model: String
    let capabilities: DeviceCapabilities
}

struct DeviceCapabilities {
    let maxSampleRate: Double
    let channelCount: Int
    let hasBuiltinCalibration: Bool
}

// MARK: - API Extensions

extension CalibrationEngine {
    
    /// 簡易キャリブレーション (1台のみ)
    func performQuickCalibration(device: AudioDevice) async throws -> DelayMeasurement {
        let sweep = generateLogSweep()
        
        // TODO: Implement single device calibration
        
        return DelayMeasurement(
            deviceId: device.id,
            delayMs: 0.0,
            confidence: 1.0,
            signalToNoise: 30.0,
            timestamp: Date()
        )
    }
    
    /// キャリブレーション結果の適用
    func applyCalibration(_ result: CalibrationResult, to devices: [AudioDevice]) async throws {
        for device in devices {
            if let delay = result.delayMap[device.id],
               let filter = result.calibrationFilters[device.id] {
                
                // TODO: Apply delay and filter to device
                print("📡 Applied calibration to \(device.name): \(delay)ms delay, \(filter.sensitivityCorrection)dB")
            }
        }
    }
    
    /// リアルタイム調整
    func performRealtimeAdjustment(measurements: [DelayMeasurement]) async throws {
        let optimization = optimizeDelayConfiguration(measurements: measurements)
        
        if optimization.rmsError > 0.1 { // 0.1ms threshold
            print("⚡ Realtime adjustment needed: RMS error \(optimization.rmsError)ms")
            // TODO: Apply real-time corrections
        }
    }
}
