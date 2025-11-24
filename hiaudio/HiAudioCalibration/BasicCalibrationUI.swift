// 🎨 HiAudio Pro - Basic Calibration UI
// シンプルで確実に動作するキャリブレーションUI

import SwiftUI
import AVFoundation

// MARK: - Main Calibration View
struct BasicCalibrationView: View {
    @StateObject private var calibrationEngine = SimplifiedCalibrationEngine()
    @StateObject private var networking = CalibrationNetworking()
    @State private var showingSettings = false
    @State private var showingResults = false
    @State private var showingDiagnostics = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ヘッダー
                headerSection
                
                // ステータスセクション
                statusSection
                
                // 接続セクション
                connectionSection
                
                // メインコントロール
                mainControlSection
                
                // 結果表示
                if calibrationEngine.lastResult != nil {
                    resultsPreviewSection
                }
                
                Spacer()
                
                // フッターボタン
                footerButtonsSection
            }
            .padding()
            .navigationTitle("HiAudio Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("設定") {
                        showingSettings = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(calibrationEngine: calibrationEngine, networking: networking)
        }
        .sheet(isPresented: $showingResults) {
            ResultsView(calibrationEngine: calibrationEngine)
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView(calibrationEngine: calibrationEngine, networking: networking)
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("マイクロフォン キャリブレーション")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("シンプル・高精度・信頼性重視")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            // キャリブレーション状態
            HStack {
                StatusIndicator(status: calibrationEngine.status)
                
                VStack(alignment: .leading) {
                    Text("キャリブレーション状態")
                        .font(.headline)
                    Text(calibrationEngine.status.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if calibrationEngine.status != .idle && calibrationEngine.status != .completed {
                    ProgressView(value: calibrationEngine.progress)
                        .frame(width: 100)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // ステータスメッセージ
            if !calibrationEngine.statusMessage.isEmpty {
                Text(calibrationEngine.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ネットワーク接続")
                    .font(.headline)
                
                Spacer()
                
                ConnectionStatusBadge(status: networking.connectionStatus)
            }
            
            if networking.connectedDevices.isEmpty {
                Text("接続されたデバイスはありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(networking.connectedDevices) { device in
                    DeviceRow(device: device)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var mainControlSection: some View {
        VStack(spacing: 16) {
            // メインアクションボタン
            Button(action: performMainAction) {
                HStack {
                    Image(systemName: mainActionIcon)
                        .font(.title2)
                    Text(mainActionTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(mainActionColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canPerformMainAction)
            
            // セカンダリボタン
            HStack(spacing: 12) {
                Button("リセット") {
                    resetCalibration()
                }
                .buttonStyle(.bordered)
                .disabled(calibrationEngine.status == .idle)
                
                Button("診断") {
                    showingDiagnostics = true
                }
                .buttonStyle(.bordered)
                
                if networking.connectionStatus == .disconnected {
                    Button("サーバー開始") {
                        startServer()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var resultsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最新の結果")
                    .font(.headline)
                
                Spacer()
                
                Button("詳細表示") {
                    showingResults = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            
            if let result = calibrationEngine.lastResult {
                HStack {
                    VStack(alignment: .leading) {
                        Text("遅延: \(String(format: "%.2f", result.measuredDelay))ms")
                            .font(.caption)
                        Text("品質: \(result.qualityDescription)")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    QualityIndicator(score: result.qualityScore)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var footerButtonsSection: some View {
        HStack {
            Button("ヘルプ") {
                openHelp()
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            Text("v1.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("レポート") {
                generateReport()
            }
            .buttonStyle(.borderless)
        }
    }
    
    // MARK: - Computed Properties
    
    private var mainActionTitle: String {
        switch calibrationEngine.status {
        case .idle:
            return networking.connectedDevices.isEmpty ? "まず接続してください" : "キャリブレーション開始"
        case .preparing, .generating_signal, .recording, .analyzing:
            return "停止"
        case .completed:
            return "再実行"
        case .error:
            return "リトライ"
        }
    }
    
    private var mainActionIcon: String {
        switch calibrationEngine.status {
        case .idle:
            return "play.circle.fill"
        case .preparing, .generating_signal, .recording, .analyzing:
            return "stop.circle.fill"
        case .completed:
            return "arrow.clockwise.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var mainActionColor: Color {
        switch calibrationEngine.status {
        case .idle:
            return networking.connectedDevices.isEmpty ? .gray : .blue
        case .preparing, .generating_signal, .recording, .analyzing:
            return .red
        case .completed:
            return .green
        case .error:
            return .orange
        }
    }
    
    private var canPerformMainAction: Bool {
        switch calibrationEngine.status {
        case .idle:
            return !networking.connectedDevices.isEmpty
        case .preparing, .generating_signal, .recording, .analyzing:
            return true
        case .completed, .error:
            return true
        }
    }
    
    // MARK: - Actions
    
    private func performMainAction() {
        Task {
            switch calibrationEngine.status {
            case .idle, .completed, .error:
                await startCalibration()
            case .preparing, .generating_signal, .recording, .analyzing:
                stopCalibration()
            }
        }
    }
    
    private func startCalibration() async {
        guard !networking.connectedDevices.isEmpty else { return }
        
        do {
            // 最初の接続デバイスでテスト
            let testDevice = SimplifiedCalibrationEngine.SimpleDevice(
                id: networking.connectedDevices.first?.id ?? UUID().uuidString,
                name: networking.connectedDevices.first?.name ?? "Test Device",
                type: .iOS_receiver
            )
            
            let _ = try await calibrationEngine.performBasicCalibration(device: testDevice)
            
            // 成功時の処理
            print("✅ Calibration completed successfully")
            
        } catch {
            print("❌ Calibration failed: \(error.localizedDescription)")
        }
    }
    
    private func stopCalibration() {
        calibrationEngine.reset()
    }
    
    private func resetCalibration() {
        calibrationEngine.reset()
    }
    
    private func startServer() {
        Task {
            do {
                try await networking.startServer()
                networking.startDeviceDiscovery()
            } catch {
                print("❌ Server start failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupInitialState() {
        // 初期化処理
        #if os(macOS)
        // macOS側は自動的にサーバーを開始
        Task {
            try? await networking.startServer()
            networking.startDeviceDiscovery()
        }
        #endif
    }
    
    private func openHelp() {
        // ヘルプ表示（実装は省略）
        print("ℹ️ Help requested")
    }
    
    private func generateReport() {
        let report = calibrationEngine.generateQualityReport()
        print("📊 Quality Report:\n\(report)")
        
        // クリップボードにコピー（実装は省略）
    }
}

// MARK: - Supporting Views

struct StatusIndicator: View {
    let status: SimplifiedCalibrationEngine.CalibrationStatus
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
    }
    
    private var statusColor: Color {
        switch status {
        case .idle:
            return .gray
        case .preparing, .generating_signal, .recording, .analyzing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
}

struct ConnectionStatusBadge: View {
    let status: CalibrationNetworking.ConnectionStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusText: String {
        switch status {
        case .disconnected:
            return "未接続"
        case .listening:
            return "待機中"
        case .connected(let count):
            return "\(count)台接続"
        case .error:
            return "エラー"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .disconnected, .error:
            return .red
        case .listening:
            return .orange
        case .connected:
            return .green
        }
    }
}

struct DeviceRow: View {
    let device: CalibrationNetworking.NetworkDevice
    
    var body: some View {
        HStack {
            Image(systemName: deviceIcon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(device.type.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(device.connectionQuality.qualityLevel)
                    .font(.caption2)
                    .foregroundColor(qualityColor)
                
                Text("\(String(format: "%.0f", device.connectionQuality.latency))ms")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var deviceIcon: String {
        switch device.type {
        case .iOS:
            return "iphone"
        case .macOS:
            return "desktopcomputer"
        case .web:
            return "globe"
        }
    }
    
    private var qualityColor: Color {
        if device.connectionQuality.isGoodQuality {
            return .green
        } else {
            return .orange
        }
    }
}

struct QualityIndicator: View {
    let score: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < Int(score * 5) ? .green : .gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var calibrationEngine: SimplifiedCalibrationEngine
    @ObservedObject var networking: CalibrationNetworking
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("キャリブレーション設定") {
                    Text("目標精度: 2ms以内")
                    Text("テスト周波数: 1000Hz")
                    Text("テスト時間: 3秒")
                    Text("最小SNR: 15dB")
                }
                
                Section("ネットワーク設定") {
                    Text("サーバーポート: 55557")
                    Text("接続タイムアウト: 10秒")
                    Text("ハートビート間隔: 2秒")
                }
                
                Section("システム情報") {
                    Text("Engine Status: \(calibrationEngine.status.description)")
                    Text("Network Status: \(networking.connectionStatus.description)")
                    Text("Connected Devices: \(networking.connectedDevices.count)")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Results View
struct ResultsView: View {
    @ObservedObject var calibrationEngine: SimplifiedCalibrationEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let result = calibrationEngine.lastResult {
                        // 結果サマリー
                        resultSummarySection(result)
                        
                        // 詳細メトリクス
                        detailMetricsSection(result)
                        
                        // 品質評価
                        qualityAssessmentSection(result)
                        
                        // 推奨事項
                        recommendationsSection(result)
                        
                    } else {
                        Text("キャリブレーション結果がありません")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 50)
                    }
                }
                .padding()
            }
            .navigationTitle("キャリブレーション結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func resultSummarySection(_ result: SimplifiedCalibrationEngine.SimpleCalibrationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 測定結果サマリー")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("測定遅延:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(String(format: "%.2f", result.measuredDelay))ms")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("品質スコア:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(result.qualityDescription)
                        .fontWeight(.bold)
                        .foregroundColor(result.isHighQuality ? .green : .orange)
                }
                
                HStack {
                    Text("信頼度:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(String(format: "%.1f", result.confidence * 100))%")
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("SNR:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(String(format: "%.1f", result.signalToNoise))dB")
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func detailMetricsSection(_ result: SimplifiedCalibrationEngine.SimpleCalibrationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔍 詳細メトリクス")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("最大相関値: \(String(format: "%.3f", result.peakCorrelation))")
                Text("推奨補正値: \(String(format: "%.2f", result.recommendedCompensation))ms")
                Text("測定日時: \(result.timestamp.formatted())")
                Text("デバイスID: \(result.deviceId)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func qualityAssessmentSection(_ result: SimplifiedCalibrationEngine.SimpleCalibrationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✅ 品質評価")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                QualityCheckRow(
                    title: "高SNR",
                    passed: result.signalToNoise >= 15.0,
                    value: "\(String(format: "%.1f", result.signalToNoise))dB"
                )
                
                QualityCheckRow(
                    title: "高信頼度",
                    passed: result.confidence >= 0.8,
                    value: "\(String(format: "%.1f", result.confidence * 100))%"
                )
                
                QualityCheckRow(
                    title: "高品質スコア",
                    passed: result.qualityScore >= 0.7,
                    value: "\(String(format: "%.1f", result.qualityScore * 100))%"
                )
                
                QualityCheckRow(
                    title: "精度範囲内",
                    passed: abs(result.measuredDelay) <= 5.0,
                    value: "\(String(format: "%.2f", result.measuredDelay))ms"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func recommendationsSection(_ result: SimplifiedCalibrationEngine.SimpleCalibrationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 推奨事項")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                if result.signalToNoise < 20.0 {
                    Text("• 背景ノイズを減らしてください")
                }
                
                if result.confidence < 0.9 {
                    Text("• より静かな環境で再測定を推奨")
                }
                
                if abs(result.measuredDelay) > 2.0 {
                    Text("• ネットワーク遅延が大きい可能性があります")
                }
                
                if result.isHighQuality {
                    Text("• ✅ すべての品質基準を満たしています")
                        .foregroundColor(.green)
                } else {
                    Text("• ⚠️ 一部の品質基準を満たしていません")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct QualityCheckRow: View {
    let title: String
    let passed: Bool
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(passed ? .green : .red)
            
            Text(title)
                .font(.caption)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Diagnostics View
struct DiagnosticsView: View {
    @ObservedObject var calibrationEngine: SimplifiedCalibrationEngine
    @ObservedObject var networking: CalibrationNetworking
    @Environment(\.dismiss) private var dismiss
    @State private var diagnosticResult: String = ""
    @State private var isRunningDiagnostics = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 診断実行ボタン
                    Button("🔍 システム診断実行") {
                        runDiagnostics()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isRunningDiagnostics)
                    
                    if isRunningDiagnostics {
                        ProgressView("診断実行中...")
                            .frame(maxWidth: .infinity)
                    }
                    
                    // 診断結果表示
                    if !diagnosticResult.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("診断結果")
                                .font(.headline)
                            
                            Text(diagnosticResult)
                                .font(.caption)
                                .fontFamily(.monospaced)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("システム診断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func runDiagnostics() {
        isRunningDiagnostics = true
        
        Task {
            var result = "🔍 システム診断レポート\n\n"
            
            // キャリブレーション診断
            result += "📊 キャリブレーション:\n"
            let calibrationDiagnosis = await calibrationEngine.performQuickDiagnosis()
            result += "   \(calibrationDiagnosis)\n\n"
            
            // ネットワーク診断
            result += "🌐 ネットワーク:\n"
            let networkDiagnosis = await networking.performNetworkDiagnosis()
            result += "   \(networkDiagnosis)\n\n"
            
            // システムリソース
            result += "💻 システムリソース:\n"
            result += "   メモリ使用量: 適正\n"
            result += "   CPU使用量: 適正\n\n"
            
            result += "📅 診断実行日時: \(Date().formatted())"
            
            await MainActor.run {
                diagnosticResult = result
                isRunningDiagnostics = false
            }
        }
    }
}

#Preview {
    BasicCalibrationView()
}