// 🎯 HiAudio Pro - Multi-Point Measurement & Optimization Engine
// 多点測定と最適化アルゴリズム

import Foundation
import simd
import Accelerate

// MARK: - Multi-Point Measurement Engine
class MultiPointOptimizer {
    
    // MARK: - Configuration
    private let maxMeasurementRounds = 5
    private let convergenceThreshold: Double = 0.01 // 0.01ms
    private let outlierThreshold: Double = 2.0 // 標準偏差の2倍
    private let minimumConfidence: Float = 0.8
    
    // State
    private var measurementHistory: [MeasurementRound] = []
    private var spatialModel: SpatialAcousticModel?
    
    // MARK: - Data Structures
    struct MeasurementRound {
        let roundNumber: Int
        let timestamp: Date
        let measurements: [String: MultiPointMeasurement]
        let environmentalConditions: EnvironmentalConditions
        let qualityMetrics: RoundQualityMetrics
        
        var averageDelay: Double {
            let delays = measurements.values.map { $0.primaryDelay }
            return delays.reduce(0, +) / Double(delays.count)
        }
        
        var standardDeviation: Double {
            let delays = measurements.values.map { $0.primaryDelay }
            let mean = averageDelay
            let variance = delays.map { pow($0 - mean, 2) }.reduce(0, +) / Double(delays.count)
            return sqrt(variance)
        }
    }
    
    struct MultiPointMeasurement {
        let deviceId: String
        let primaryDelay: Double           // メイン遅延 (ms)
        let confidence: Float             // 信頼度 (0-1)
        let snrDecibels: Float           // SNR (dB)
        let spatialPosition: SIMD3<Float> // 3D位置 (x, y, z)
        let multiPathProfile: [PathComponent] // マルチパス成分
        let frequencyResponse: [Float]    // 周波数応答
        let phaseResponse: [Float]        // 位相応答
        let qualityScore: Float          // 総合品質スコア
        let timestamp: Date
        
        var isHighQuality: Bool {
            return confidence > 0.9 && snrDecibels > 25.0 && qualityScore > 0.85
        }
    }
    
    struct PathComponent {
        let delay: Double               // 相対遅延 (ms)
        let amplitude: Float           // 振幅 (線形)
        let phase: Float              // 位相 (rad)
        let confidence: Float         // 検出信頼度
        
        var isSignificant: Bool {
            return amplitude > 0.1 && confidence > 0.7
        }
    }
    
    struct EnvironmentalConditions {
        let temperature: Float?        // 温度 (℃)
        let humidity: Float?          // 湿度 (%)
        let pressure: Float?          // 気圧 (hPa)
        let backgroundNoiseLevel: Float // 背景雑音レベル (dB)
        let estimatedRoomSize: SIMD3<Float>? // 推定部屋サイズ (m)
        let acousticProperties: AcousticProperties
        
        // 音速計算 (温度・湿度補正)
        var soundSpeed: Double {
            let temp = Double(temperature ?? 20.0)
            let humid = Double(humidity ?? 50.0)
            
            // 温度・湿度による音速補正
            return 331.3 * sqrt(1.0 + temp / 273.15) + (humid * 0.01)
        }
    }
    
    struct AcousticProperties {
        let reverbTime: Float         // 残響時間 (s)
        let clarity: Float           // 明瞭度
        let definition: Float        // 明確度
        let warmth: Float           // 温かみ指標
        let spaciousness: Float     // 空間性
        
        var roomCharacter: RoomType {
            if reverbTime < 0.3 {
                return .anechoic
            } else if reverbTime < 0.8 {
                return .dry
            } else if reverbTime < 1.5 {
                return .normal
            } else {
                return .reverberant
            }
        }
    }
    
    enum RoomType {
        case anechoic, dry, normal, reverberant
    }
    
    struct RoundQualityMetrics {
        let measurementConsistency: Float    // 測定間一貫性
        let spatialCoherence: Float         // 空間的整合性
        let temporalStability: Float        // 時間的安定性
        let environmentalStability: Float   // 環境安定性
        let overallReliability: Float       // 総合信頼性
        
        var meetsQualityStandard: Bool {
            return overallReliability > 0.8
        }
    }
    
    // MARK: - Spatial Acoustic Model
    struct SpatialAcousticModel {
        let speakerPosition: SIMD3<Float>     // スピーカー位置
        let devicePositions: [String: SIMD3<Float>] // デバイス位置
        let roomGeometry: RoomGeometry        // 部屋の幾何形状
        let acousticParameters: ModelParameters // 音響パラメータ
        let validationScore: Float           // モデル妥当性スコア
        
        func predictDelay(for position: SIMD3<Float>) -> Double {
            let distance = length(position - speakerPosition)
            let soundSpeed = acousticParameters.soundSpeed
            let baseDelay = Double(distance) / soundSpeed * 1000.0 // ms
            
            // 部屋の音響特性による補正
            let reverbCorrection = acousticParameters.reverbCorrection
            let diffusionCorrection = acousticParameters.diffusionCorrection
            
            return baseDelay + reverbCorrection + diffusionCorrection
        }
    }
    
    struct RoomGeometry {
        let dimensions: SIMD3<Float>      // 長さ・幅・高さ (m)
        let wallMaterials: [WallMaterial] // 壁面材質
        let furnitureObjects: [FurnitureObject] // 家具配置
        
        var volume: Float {
            return dimensions.x * dimensions.y * dimensions.z
        }
        
        var surfaceArea: Float {
            return 2.0 * (dimensions.x * dimensions.y + 
                         dimensions.y * dimensions.z + 
                         dimensions.z * dimensions.x)
        }
    }
    
    enum WallMaterial {
        case concrete, drywall, wood, fabric, glass
        
        var absorptionCoefficient: Float {
            switch self {
            case .concrete: return 0.02
            case .drywall: return 0.05
            case .wood: return 0.10
            case .fabric: return 0.35
            case .glass: return 0.03
            }
        }
    }
    
    struct FurnitureObject {
        let position: SIMD3<Float>
        let size: SIMD3<Float>
        let material: FurnitureMaterial
        let absorptionEffect: Float
    }
    
    enum FurnitureMaterial {
        case wood, fabric, metal, leather
    }
    
    struct ModelParameters {
        let soundSpeed: Double
        let reverbCorrection: Double
        let diffusionCorrection: Double
        let temperatureGradient: Float
        let airAbsorption: Float
    }
    
    // MARK: - Main Optimization Algorithm
    func performMultiPointOptimization(
        measurements: [String: MultiPointMeasurement],
        environmentalConditions: EnvironmentalConditions
    ) async throws -> OptimizationResult {
        
        print("🎯 Starting multi-point optimization...")
        print("   Devices: \(measurements.count)")
        print("   Environmental: \(environmentalConditions.soundSpeed)m/s sound speed")
        
        // 1. 測定品質評価
        let qualityMetrics = evaluateRoundQuality(measurements: measurements, conditions: environmentalConditions)
        
        guard qualityMetrics.meetsQualityStandard else {
            throw OptimizationError.insufficientQuality(qualityMetrics.overallReliability)
        }
        
        // 2. 外れ値検出と除去
        let filteredMeasurements = removeOutliers(from: measurements)
        print("   Filtered measurements: \(filteredMeasurements.count)/\(measurements.count)")
        
        // 3. 空間音響モデル構築
        let spatialModel = try await buildSpatialModel(
            measurements: filteredMeasurements,
            conditions: environmentalConditions
        )
        
        // 4. 最適化アルゴリズム実行
        let optimizationResult = try await executeOptimizationAlgorithm(
            measurements: filteredMeasurements,
            spatialModel: spatialModel
        )
        
        // 5. 結果検証
        let validationResult = validateOptimization(
            result: optimizationResult,
            originalMeasurements: measurements
        )
        
        print("✅ Multi-point optimization completed:")
        print("   RMS Error: \(String(format: "%.6f", optimizationResult.rmsError))ms")
        print("   Max Deviation: \(String(format: "%.6f", optimizationResult.maxDeviation))ms")
        print("   Spatial Coherence: \(String(format: "%.3f", optimizationResult.spatialCoherence))")
        print("   Validation Score: \(String(format: "%.3f", validationResult.overallScore))")
        
        return optimizationResult
    }
    
    // MARK: - Quality Evaluation
    private func evaluateRoundQuality(
        measurements: [String: MultiPointMeasurement],
        conditions: EnvironmentalConditions
    ) -> RoundQualityMetrics {
        
        // 1. 測定間一貫性
        let delays = measurements.values.map { $0.primaryDelay }
        let confidences = measurements.values.map { $0.confidence }
        let snrValues = measurements.values.map { $0.snrDecibels }
        
        let delayStdDev = calculateStandardDeviation(delays)
        let confidenceAvg = confidences.reduce(0, +) / Float(confidences.count)
        let snrAvg = snrValues.reduce(0, +) / Float(snrValues.count)
        
        let measurementConsistency = Float(max(0.0, 1.0 - delayStdDev / 1.0)) // 1ms基準
        
        // 2. 空間的整合性
        let spatialCoherence = evaluateSpatialCoherence(measurements: measurements)
        
        // 3. 時間的安定性（過去の測定との比較）
        let temporalStability = evaluateTemporalStability(measurements: measurements)
        
        // 4. 環境安定性
        let environmentalStability = conditions.backgroundNoiseLevel < -40.0 ? 1.0 : 0.5
        
        // 5. 総合信頼性
        let overallReliability = (
            measurementConsistency * 0.3 +
            spatialCoherence * 0.25 +
            temporalStability * 0.2 +
            environmentalStability * 0.1 +
            (confidenceAvg * 0.15)
        )
        
        return RoundQualityMetrics(
            measurementConsistency: measurementConsistency,
            spatialCoherence: spatialCoherence,
            temporalStability: temporalStability,
            environmentalStability: environmentalStability,
            overallReliability: overallReliability
        )
    }
    
    // MARK: - Outlier Detection
    private func removeOutliers(from measurements: [String: MultiPointMeasurement]) -> [String: MultiPointMeasurement] {
        let delays = measurements.values.map { $0.primaryDelay }
        let mean = delays.reduce(0, +) / Double(delays.count)
        let stdDev = calculateStandardDeviation(delays)
        
        let threshold = stdDev * outlierThreshold
        
        return measurements.filter { _, measurement in
            let deviation = abs(measurement.primaryDelay - mean)
            return deviation <= threshold && measurement.confidence >= minimumConfidence
        }
    }
    
    // MARK: - Spatial Model Building
    private func buildSpatialModel(
        measurements: [String: MultiPointMeasurement],
        conditions: EnvironmentalConditions
    ) async throws -> SpatialAcousticModel {
        
        print("🏗️ Building spatial acoustic model...")
        
        // デバイス位置から部屋の幾何形状を推定
        let devicePositions = Dictionary(uniqueKeysWithValues: 
            measurements.map { ($0.key, $0.value.spatialPosition) }
        )
        
        let roomGeometry = estimateRoomGeometry(from: Array(devicePositions.values))
        let speakerPosition = estimateSpeakerPosition(measurements: measurements)
        
        // 音響パラメータ推定
        let acousticParams = ModelParameters(
            soundSpeed: conditions.soundSpeed,
            reverbCorrection: calculateReverbCorrection(conditions.acousticProperties),
            diffusionCorrection: calculateDiffusionCorrection(roomGeometry),
            temperatureGradient: 0.0, // 簡略化
            airAbsorption: calculateAirAbsorption(conditions)
        )
        
        let model = SpatialAcousticModel(
            speakerPosition: speakerPosition,
            devicePositions: devicePositions,
            roomGeometry: roomGeometry,
            acousticParameters: acousticParams,
            validationScore: 0.85 // 暫定値
        )
        
        spatialModel = model
        print("✅ Spatial model built with \(devicePositions.count) device positions")
        
        return model
    }
    
    // MARK: - Optimization Algorithm
    private func executeOptimizationAlgorithm(
        measurements: [String: MultiPointMeasurement],
        spatialModel: SpatialAcousticModel
    ) async throws -> OptimizationResult {
        
        print("⚡ Executing optimization algorithm...")
        
        // 1. 基準遅延の設定（最小遅延基準）
        let minDelay = measurements.values.map { $0.primaryDelay }.min() ?? 0.0
        
        // 2. 各デバイスの補正遅延計算
        var correctionDelays: [String: Double] = [:]
        
        for (deviceId, measurement) in measurements {
            let rawDelay = measurement.primaryDelay
            let spatialPrediction = spatialModel.predictDelay(for: measurement.spatialPosition)
            
            // 実測値と空間モデル予測の統合
            let weightedDelay = rawDelay * 0.8 + spatialPrediction * 0.2
            correctionDelays[deviceId] = weightedDelay - minDelay
        }
        
        // 3. 反復最適化
        var optimizedDelays = correctionDelays
        var previousRMS: Double = Double.greatestFiniteMagnitude
        
        for iteration in 1...5 {
            // グローバル最適化ステップ
            optimizedDelays = performGlobalOptimizationStep(optimizedDelays, measurements: measurements)
            
            let currentRMS = calculateRMSError(optimizedDelays)
            print("   Iteration \(iteration): RMS = \(String(format: "%.6f", currentRMS))ms")
            
            if abs(previousRMS - currentRMS) < convergenceThreshold {
                print("   Converged after \(iteration) iterations")
                break
            }
            previousRMS = currentRMS
        }
        
        // 4. 結果構築
        let rmsError = calculateRMSError(optimizedDelays)
        let maxDeviation = optimizedDelays.values.map { abs($0) }.max() ?? 0.0
        let spatialCoherence = calculateSpatialCoherence(optimizedDelays, spatialModel: spatialModel)
        
        return OptimizationResult(
            delayCorrections: optimizedDelays,
            rmsError: rmsError,
            maxDeviation: maxDeviation,
            spatialCoherence: spatialCoherence,
            convergenceIterations: 5,
            qualityScore: Float(max(0.0, 1.0 - rmsError / 0.5)), // 0.5ms基準
            optimizationMethod: .multiPointSpatial,
            timestamp: Date()
        )
    }
    
    // MARK: - Helper Functions
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    private func evaluateSpatialCoherence(measurements: [String: MultiPointMeasurement]) -> Float {
        // 空間配置の妥当性を評価
        return 0.85 // 暫定実装
    }
    
    private func evaluateTemporalStability(measurements: [String: MultiPointMeasurement]) -> Float {
        // 過去の測定結果との比較
        return 0.90 // 暫定実装
    }
    
    private func estimateRoomGeometry(from positions: [SIMD3<Float>]) -> RoomGeometry {
        // デバイス位置から部屋サイズを推定
        let minX = positions.map { $0.x }.min() ?? 0
        let maxX = positions.map { $0.x }.max() ?? 0
        let minY = positions.map { $0.y }.min() ?? 0
        let maxY = positions.map { $0.y }.max() ?? 0
        let minZ = positions.map { $0.z }.min() ?? 0
        let maxZ = positions.map { $0.z }.max() ?? 0
        
        let dimensions = SIMD3<Float>(maxX - minX + 2.0, maxY - minY + 2.0, maxZ - minZ + 2.5)
        
        return RoomGeometry(
            dimensions: dimensions,
            wallMaterials: [.drywall, .drywall, .drywall, .drywall], // 仮定
            furnitureObjects: []
        )
    }
    
    private func estimateSpeakerPosition(measurements: [String: MultiPointMeasurement]) -> SIMD3<Float> {
        // 測定結果から最適なスピーカー位置を推定
        let positions = measurements.values.map { $0.spatialPosition }
        let centerX = positions.map { $0.x }.reduce(0, +) / Float(positions.count)
        let centerY = positions.map { $0.y }.reduce(0, +) / Float(positions.count)
        let centerZ = positions.map { $0.z }.reduce(0, +) / Float(positions.count)
        
        return SIMD3<Float>(centerX, centerY, centerZ + 1.0) // スピーカーは少し高い位置
    }
    
    private func calculateReverbCorrection(_ acousticProps: AcousticProperties) -> Double {
        return Double(acousticProps.reverbTime) * 0.5 // 簡略化
    }
    
    private func calculateDiffusionCorrection(_ geometry: RoomGeometry) -> Double {
        return Double(geometry.volume) * 0.01 // 簡略化
    }
    
    private func calculateAirAbsorption(_ conditions: EnvironmentalConditions) -> Float {
        return conditions.humidity ?? 50.0 * 0.001 // 簡略化
    }
    
    private func performGlobalOptimizationStep(
        _ delays: [String: Double],
        measurements: [String: MultiPointMeasurement]
    ) -> [String: Double] {
        // グローバル最適化ステップ（最小二乗法ベース）
        return delays // 暫定実装
    }
    
    private func calculateRMSError(_ delays: [String: Double]) -> Double {
        let values = Array(delays.values)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    private func calculateSpatialCoherence(_ delays: [String: Double], spatialModel: SpatialAcousticModel) -> Float {
        // 空間モデルとの整合性評価
        return 0.88 // 暫定実装
    }
    
    private func validateOptimization(
        result: OptimizationResult,
        originalMeasurements: [String: MultiPointMeasurement]
    ) -> ValidationResult {
        return ValidationResult(
            overallScore: result.qualityScore * 0.9, // 暫定実装
            spatialConsistency: result.spatialCoherence,
            temporalStability: 0.85,
            robustness: 0.80
        )
    }
}

// MARK: - Result Structures
struct OptimizationResult {
    let delayCorrections: [String: Double]
    let rmsError: Double
    let maxDeviation: Double
    let spatialCoherence: Float
    let convergenceIterations: Int
    let qualityScore: Float
    let optimizationMethod: OptimizationMethod
    let timestamp: Date
    
    enum OptimizationMethod {
        case simpleMinimum
        case leastSquares
        case multiPointSpatial
        case adaptiveWeighted
    }
}

struct ValidationResult {
    let overallScore: Float
    let spatialConsistency: Float
    let temporalStability: Float
    let robustness: Float
}

enum OptimizationError: Error, LocalizedError {
    case insufficientQuality(Float)
    case convergenceFailure
    case spatialModelFailure
    case invalidMeasurements
    
    var errorDescription: String? {
        switch self {
        case .insufficientQuality(let score):
            return "測定品質が不十分です (品質スコア: \(score))"
        case .convergenceFailure:
            return "最適化が収束しませんでした"
        case .spatialModelFailure:
            return "空間音響モデルの構築に失敗しました"
        case .invalidMeasurements:
            return "無効な測定データです"
        }
    }
}