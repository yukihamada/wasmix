// 🌍 HiAudio Pro - Universal Calibration UI
// 「誰もがいい音をみんなで」を実現するユニバーサルUI

import SwiftUI

// MARK: - Universal Calibration Main View
struct UniversalCalibrationView: View {
    @StateObject private var universalSystem = UniversalCalibrationSystem()
    @State private var showingDeviceDetails = false
    @State private var selectedDevice: UniversalCalibrationSystem.UniversalAudioDevice?
    @State private var showingSetupGuide = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー - ビジョン表示
                    universalHeaderSection
                    
                    // システム状態
                    systemStatusSection
                    
                    // デバイス発見・接続
                    deviceDiscoverySection
                    
                    // 発見されたデバイス一覧
                    if !universalSystem.discoveredDevices.isEmpty {
                        discoveredDevicesSection
                    }
                    
                    // キャリブレーション制御
                    calibrationControlSection
                    
                    // 結果表示
                    if !universalSystem.multiDeviceResults.isEmpty {
                        resultsOverviewSection
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Universal Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("セットアップガイド") {
                        showingSetupGuide = true
                    }
                    .font(.caption)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("再検索") {
                        Task {
                            await universalSystem.startUniversalDiscovery()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDeviceDetails) {
            if let device = selectedDevice {
                DeviceDetailView(device: device, universalSystem: universalSystem)
            }
        }
        .sheet(isPresented: $showingSetupGuide) {
            UniversalSetupGuide()
        }
        .onAppear {
            Task {
                await universalSystem.startUniversalDiscovery()
            }
        }
    }
    
    // MARK: - View Sections
    
    private var universalHeaderSection: some View {
        VStack(spacing: 16) {
            // アイコン群 - 対応デバイス表示
            HStack(spacing: 12) {
                ForEach(UniversalCalibrationSystem.UniversalAudioDevice.UniversalDeviceType.allCases.prefix(6), id: \.self) { deviceType in
                    Image(systemName: deviceType.icon)
                        .font(.title2)
                        .foregroundColor(Color(deviceType.color))
                        .frame(width: 40, height: 40)
                        .background(Color(deviceType.color).opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            VStack(spacing: 8) {
                Text("🌍 Universal Audio Calibration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("誰もがいい音をみんなで")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("iPhone・Echo・Google Home・あらゆるデバイスを\n自動で発見して最適化")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemStatusIcon)
                    .foregroundColor(systemStatusColor)
                    .font(.title3)
                
                Text("システム状態")
                    .font(.headline)
                
                Spacer()
                
                Text(universalSystem.systemStatus.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 進行状況バー
            if case .calibrating = universalSystem.systemStatus {
                ProgressView("マルチデバイス キャリブレーション実行中...")
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var deviceDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📡 デバイス自動検索")
                    .font(.headline)
                
                Spacer()
                
                Text("\(universalSystem.discoveredDevices.count)台発見")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            // 検索対象プロトコル表示
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ProtocolBadge(name: "iPhone/Mac", icon: "wifi", status: .active)
                ProtocolBadge(name: "Alexa", icon: "homepod", status: .active)
                ProtocolBadge(name: "Google Cast", icon: "homepod.fill", status: .active)
                ProtocolBadge(name: "UPnP/DLNA", icon: "network", status: .active)
                ProtocolBadge(name: "WebSocket", icon: "globe", status: .active)
                ProtocolBadge(name: "AirPlay", icon: "airplayaudio", status: .active)
            }
            
            if case .discovering = universalSystem.systemStatus {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("全プロトコルでデバイス検索中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var discoveredDevicesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎵 発見されたオーディオデバイス")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(universalSystem.discoveredDevices) { device in
                    UniversalDeviceCard(
                        device: device,
                        calibrationResult: universalSystem.multiDeviceResults[device.id]
                    ) {
                        selectedDevice = device
                        showingDeviceDetails = true
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var calibrationControlSection: some View {
        VStack(spacing: 16) {
            // メインキャリブレーションボタン
            Button(action: {
                Task {
                    try? await universalSystem.startMultiDeviceCalibration()
                }
            }) {
                HStack {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.title2)
                    Text(calibrationButtonTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(calibrationButtonColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canStartCalibration)
            
            // 詳細オプション
            HStack(spacing: 12) {
                Button("音声ガイド") {
                    startVoiceGuidedSetup()
                }
                .buttonStyle(.bordered)
                
                Button("QRコード生成") {
                    generateUniversalQRCode()
                }
                .buttonStyle(.bordered)
                
                Button("一括設定") {
                    applyUniversalSettings()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var resultsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 キャリブレーション結果")
                .font(.headline)
            
            // 統計サマリー
            HStack(spacing: 20) {
                StatCard(
                    title: "平均遅延",
                    value: String(format: "%.1fms", averageDelay),
                    color: averageDelay < 5.0 ? .green : .orange
                )
                
                StatCard(
                    title: "最高品質",
                    value: "\(highQualityDeviceCount)/\(universalSystem.multiDeviceResults.count)",
                    color: highQualityRatio > 0.8 ? .green : .orange
                )
                
                StatCard(
                    title: "同期精度",
                    value: String(format: "±%.1fms", synchronizationAccuracy),
                    color: synchronizationAccuracy < 2.0 ? .green : .orange
                )
            }
            
            // デバイス別結果
            ForEach(Array(universalSystem.multiDeviceResults.values), id: \.deviceId) { result in
                CalibrationResultRow(result: result)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var systemStatusIcon: String {
        switch universalSystem.systemStatus {
        case .idle: return "circle"
        case .discovering: return "magnifyingglass"
        case .calibrating: return "waveform"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private var systemStatusColor: Color {
        switch universalSystem.systemStatus {
        case .idle: return .gray
        case .discovering: return .blue
        case .calibrating: return .orange
        case .completed: return .green
        case .error: return .red
        }
    }
    
    private var calibrationButtonTitle: String {
        switch universalSystem.systemStatus {
        case .idle:
            return universalSystem.discoveredDevices.isEmpty ? "まずデバイス検索を実行" : "全デバイス同時キャリブレーション"
        case .discovering:
            return "検索中..."
        case .calibrating:
            return "キャリブレーション実行中"
        case .completed:
            return "再キャリブレーション"
        case .error:
            return "リトライ"
        }
    }
    
    private var calibrationButtonColor: Color {
        switch universalSystem.systemStatus {
        case .idle:
            return universalSystem.discoveredDevices.isEmpty ? .gray : .blue
        case .discovering:
            return .gray
        case .calibrating:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    private var canStartCalibration: Bool {
        switch universalSystem.systemStatus {
        case .idle:
            return !universalSystem.discoveredDevices.isEmpty
        case .completed, .error:
            return true
        case .discovering, .calibrating:
            return false
        }
    }
    
    private var averageDelay: Double {
        let delays = universalSystem.multiDeviceResults.values.map { $0.measuredDelay }
        return delays.isEmpty ? 0.0 : delays.reduce(0, +) / Double(delays.count)
    }
    
    private var highQualityDeviceCount: Int {
        return universalSystem.multiDeviceResults.values.filter { $0.qualityLevel == "優秀" }.count
    }
    
    private var highQualityRatio: Double {
        let total = universalSystem.multiDeviceResults.count
        return total == 0 ? 0.0 : Double(highQualityDeviceCount) / Double(total)
    }
    
    private var synchronizationAccuracy: Double {
        let delays = universalSystem.multiDeviceResults.values.map { $0.measuredDelay }
        guard delays.count > 1 else { return 0.0 }
        
        let maxDelay = delays.max() ?? 0.0
        let minDelay = delays.min() ?? 0.0
        return maxDelay - minDelay
    }
    
    // MARK: - Action Methods
    
    private func startVoiceGuidedSetup() {
        // 音声ガイド付きセットアップ開始
        print("🎤 音声ガイドセットアップ開始")
    }
    
    private func generateUniversalQRCode() {
        // デバイス接続用QRコード生成
        print("📱 ユニバーサルQRコード生成")
    }
    
    private func applyUniversalSettings() {
        // 全デバイスに最適設定を一括適用
        Task {
            try? await universalSystem.applyRecommendedSettingsToDevices()
            print("⚙️ 全デバイス設定適用完了")
        }
    }
}

// MARK: - Supporting Views

struct ProtocolBadge: View {
    let name: String
    let icon: String
    let status: Status
    
    enum Status {
        case active, inactive, searching
        
        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .gray
            case .searching: return .blue
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(status.color)
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct UniversalDeviceCard: View {
    let device: UniversalCalibrationSystem.UniversalAudioDevice
    let calibrationResult: UniversalCalibrationSystem.UniversalCalibrationResult?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // デバイスアイコンとタイプ
                VStack(spacing: 4) {
                    Image(systemName: device.type.icon)
                        .font(.title2)
                        .foregroundColor(Color(device.type.color))
                    
                    Text(device.type.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // デバイス名
                Text(device.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // 状態・結果表示
                if let result = calibrationResult {
                    VStack(spacing: 4) {
                        Text("\(String(format: "%.1f", result.measuredDelay))ms")
                            .font(.caption2)
                            .fontWeight(.bold)
                        
                        Text(result.qualityLevel)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor(result.qualityLevel).opacity(0.2))
                            .foregroundColor(qualityColor(result.qualityLevel))
                            .cornerRadius(4)
                    }
                } else {
                    Text(device.calibrationState.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(height: 120)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func qualityColor(_ level: String) -> Color {
        switch level {
        case "優秀": return .green
        case "良好": return .blue
        case "要改善": return .orange
        default: return .gray
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CalibrationResultRow: View {
    let result: UniversalCalibrationSystem.UniversalCalibrationResult
    
    var body: some View {
        HStack {
            // デバイス情報
            HStack(spacing: 8) {
                Image(systemName: result.deviceType.icon)
                    .foregroundColor(Color(result.deviceType.color))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.deviceName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(result.deviceType.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 結果データ
            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.1f", result.measuredDelay))ms")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("遅延")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.1f", result.confidence * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("信頼度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(result.qualityLevel)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(qualityColor.opacity(0.2))
                    .foregroundColor(qualityColor)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var qualityColor: Color {
        switch result.qualityLevel {
        case "優秀": return .green
        case "良好": return .blue
        case "要改善": return .orange
        default: return .gray
        }
    }
}

// MARK: - Device Detail View

struct DeviceDetailView: View {
    let device: UniversalCalibrationSystem.UniversalAudioDevice
    let universalSystem: UniversalCalibrationSystem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // デバイス基本情報
                    deviceInfoSection
                    
                    // 接続情報
                    connectionInfoSection
                    
                    // 能力・対応機能
                    capabilitiesSection
                    
                    // キャリブレーション結果（あれば）
                    if let result = universalSystem.multiDeviceResults[device.id] {
                        calibrationResultSection(result)
                    }
                    
                    // アクションボタン
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle(device.name)
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
    
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: device.type.icon)
                    .font(.largeTitle)
                    .foregroundColor(Color(device.type.color))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(device.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("ID: \(device.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontFamily(.monospaced)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var connectionInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("接続情報")
                .font(.headline)
            
            if let ipAddress = device.connectionInfo.ipAddress {
                InfoRow(label: "IPアドレス", value: ipAddress)
            }
            
            if let port = device.connectionInfo.port {
                InfoRow(label: "ポート", value: "\(port)")
            }
            
            if let phrase = device.connectionInfo.voiceActivationPhrase {
                InfoRow(label: "音声起動", value: phrase)
            }
            
            InfoRow(label: "通信方式", value: device.capabilities.communicationMethod.rawValue)
            InfoRow(label: "接続品質", value: String(format: "%.1f%%", device.connectionInfo.connectionQuality * 100))
            InfoRow(label: "最終確認", value: device.connectionInfo.lastSeen.formatted(date: .omitted, time: .shortened))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("デバイス機能")
                .font(.headline)
            
            CapabilityRow(
                icon: "speaker.wave.2",
                title: "音声再生",
                isSupported: device.capabilities.supportsAudioPlayback
            )
            
            CapabilityRow(
                icon: "mic",
                title: "音声録音",
                isSupported: device.capabilities.supportsAudioRecording
            )
            
            CapabilityRow(
                icon: "mic.circle",
                title: "内蔵マイク",
                isSupported: device.capabilities.hasBuiltinMicrophone
            )
            
            CapabilityRow(
                icon: "waveform.badge.mic",
                title: "音声起動",
                isSupported: device.capabilities.supportsVoiceActivation
            )
            
            InfoRow(label: "最大サンプルレート", value: "\(Int(device.capabilities.maxSampleRate))Hz")
            InfoRow(label: "チャンネル数", value: "\(device.capabilities.channelCount)ch")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func calibrationResultSection(_ result: UniversalCalibrationSystem.UniversalCalibrationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("キャリブレーション結果")
                .font(.headline)
            
            InfoRow(label: "測定遅延", value: "\(String(format: "%.2f", result.measuredDelay))ms")
            InfoRow(label: "信頼度", value: "\(String(format: "%.1f", result.confidence * 100))%")
            InfoRow(label: "信号品質", value: "\(String(format: "%.1f", result.signalQuality * 100))%")
            InfoRow(label: "品質レベル", value: result.qualityLevel)
            InfoRow(label: "推奨補正", value: "\(String(format: "%.2f", result.recommendedSettings.delayCompensation))ms")
            InfoRow(label: "音量調整", value: "\(String(format: "%.1f", result.recommendedSettings.volumeAdjustment * 100))%")
            InfoRow(label: "測定日時", value: result.timestamp.formatted())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button("個別キャリブレーション実行") {
                // このデバイスのみでキャリブレーション
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button("テスト信号再生") {
                    // テスト信号再生
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("接続テスト") {
                    // 接続品質テスト
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Supporting Detail Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

struct CapabilityRow: View {
    let icon: String
    let title: String
    let isSupported: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isSupported ? .green : .gray)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(isSupported ? .primary : .secondary)
            
            Spacer()
            
            Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSupported ? .green : .gray)
        }
        .font(.caption)
    }
}

// MARK: - Setup Guide

struct UniversalSetupGuide: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStep = 0
    
    private let setupSteps = [
        SetupStep(
            title: "Amazon Echo セットアップ",
            description: "1. Alexaアプリで「HiAudio」スキルを有効化\n2. 「Alexa, start HiAudio calibration」と話しかける",
            icon: "homepod"
        ),
        SetupStep(
            title: "Google Home セットアップ",
            description: "1. Google Homeアプリで「HiAudio」アクションを追加\n2. 「Hey Google, start HiAudio calibration」と話しかける",
            icon: "homepod.fill"
        ),
        SetupStep(
            title: "ブラウザセットアップ",
            description: "1. https://hiaudio.pro/calibrate にアクセス\n2. マイク・スピーカーアクセスを許可\n3. 自動的にiPhoneアプリと接続",
            icon: "globe"
        ),
        SetupStep(
            title: "その他デバイス",
            description: "UPnP/DLNA対応スピーカー、Apple TV、Android TVも自動検出されます",
            icon: "speaker.wave.3"
        )
    ]
    
    struct SetupStep {
        let title: String
        let description: String
        let icon: String
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🌍 ユニバーサル セットアップガイド")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                TabView(selection: $selectedStep) {
                    ForEach(setupSteps.indices, id: \.self) { index in
                        SetupStepView(step: setupSteps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                
                HStack {
                    if selectedStep > 0 {
                        Button("戻る") {
                            selectedStep -= 1
                        }
                    }
                    
                    Spacer()
                    
                    if selectedStep < setupSteps.count - 1 {
                        Button("次へ") {
                            selectedStep += 1
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("開始") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("セットアップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("スキップ") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SetupStepView: View {
    let step: UniversalSetupGuide.SetupStep
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: step.icon)
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text(step.title)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(step.description)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    UniversalCalibrationView()
}