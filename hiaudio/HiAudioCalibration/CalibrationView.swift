// 📱 HiAudio Pro - iPhone Calibration UI
// キャリブレーション用ユーザーインターフェース

import SwiftUI
import AVFoundation

struct CalibrationView: View {
    @StateObject private var calibrationClient = iOSCalibrationClient()
    @State private var showingConnectionSheet = false
    @State private var showingInstructions = false
    @State private var macOSHost = ""
    @State private var autoDetectedHosts: [String] = []
    
    // アニメーション用
    @State private var pulseAnimation = false
    @State private var waveAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // バックグラウンドグラデーション
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        
                        // ヘッダー
                        VStack(spacing: 10) {
                            Image(systemName: "waveform.badge.mic")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    .linearGradient(colors: [.blue, .purple], 
                                                   startPoint: .topLeading, 
                                                   endPoint: .bottomTrailing)
                                )
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(), 
                                         value: pulseAnimation)
                            
                            Text("HiAudio Pro")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("マイクロフォン キャリブレーション")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .onAppear {
                            pulseAnimation = true
                        }
                        
                        // 接続状態カード
                        ConnectionStatusCard(
                            status: calibrationClient.connectionStatus,
                            onConnectTapped: {
                                showingConnectionSheet = true
                            }
                        )
                        
                        // キャリブレーション状態カード
                        CalibrationStatusCard(
                            state: calibrationClient.calibrationState,
                            progress: calibrationClient.currentProgress,
                            message: calibrationClient.statusMessage,
                            waveAnimation: $waveAnimation
                        )
                        
                        // アクションボタン
                        ActionButtonsView(
                            calibrationClient: calibrationClient,
                            showingInstructions: $showingInstructions
                        )
                        
                        // デバイス情報
                        DeviceInfoCard()
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingConnectionSheet) {
            ConnectionSetupView(
                calibrationClient: calibrationClient,
                macOSHost: $macOSHost,
                autoDetectedHosts: $autoDetectedHosts
            )
        }
        .sheet(isPresented: $showingInstructions) {
            CalibrationInstructionsView()
        }
        .onAppear {
            startNetworkDiscovery()
        }
    }
    
    private func startNetworkDiscovery() {
        // 簡単なネットワーク探索（実装は省略）
        autoDetectedHosts = ["192.168.1.100", "192.168.1.101"]
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    let status: iOSCalibrationClient.ConnectionStatus
    let onConnectTapped: () -> Void
    
    var body: some View {
        Card {
            HStack(spacing: 15) {
                // ステータスアイコン
                statusIcon
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("接続状態")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(status.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if case .disconnected = status {
                    Button("接続", action: onConnectTapped)
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .connected:
            Image(systemName: "wifi")
                .foregroundColor(.green)
        case .connecting:
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
        case .disconnected:
            Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.gray)
        case .error:
            Image(systemName: "wifi.slash")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Calibration Status Card
struct CalibrationStatusCard: View {
    let state: iOSCalibrationClient.CalibrationState
    let progress: Float
    let message: String
    @Binding var waveAnimation: Bool
    
    var body: some View {
        Card {
            VStack(spacing: 20) {
                // ステータスヘッダー
                HStack {
                    stateIcon
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("キャリブレーション状態")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(state.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // 進捗バー
                if case .listening = state {
                    VStack(spacing: 10) {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(
                                LinearProgressViewStyle(tint: .blue)
                            )
                            .scaleEffect(y: 2.0)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 波形アニメーション
                if case .listening = state {
                    WaveformAnimationView(isAnimating: $waveAnimation)
                        .frame(height: 60)
                        .onAppear {
                            waveAnimation = true
                        }
                        .onDisappear {
                            waveAnimation = false
                        }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "mic")
                .foregroundColor(.gray)
        case .preparing:
            Image(systemName: "gear")
                .foregroundColor(.orange)
        case .listening:
            Image(systemName: "mic.fill")
                .foregroundColor(.red)
        case .analyzing:
            Image(systemName: "chart.bar.xaxis")
                .foregroundColor(.blue)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Action Buttons
struct ActionButtonsView: View {
    @ObservedObject var calibrationClient: iOSCalibrationClient
    @Binding var showingInstructions: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            // メインアクションボタン
            Button(action: mainAction) {
                HStack {
                    Image(systemName: mainActionIcon)
                        .font(.title3)
                    Text(mainActionTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(mainActionColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canPerformMainAction)
            
            // サブボタン
            HStack(spacing: 15) {
                Button("使い方") {
                    showingInstructions = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("リセット") {
                    calibrationClient.resetCalibration()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(calibrationClient.calibrationState == .idle)
            }
        }
    }
    
    private var mainActionTitle: String {
        switch calibrationClient.calibrationState {
        case .idle:
            return calibrationClient.connectionStatus == .connected ? 
                   "キャリブレーション開始" : "まず接続してください"
        case .preparing, .listening, .analyzing:
            return "実行中..."
        case .completed:
            return "完了"
        case .failed:
            return "再試行"
        }
    }
    
    private var mainActionIcon: String {
        switch calibrationClient.calibrationState {
        case .idle:
            return "play.circle.fill"
        case .preparing, .listening, .analyzing:
            return "stop.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "arrow.clockwise.circle"
        }
    }
    
    private var mainActionColor: Color {
        switch calibrationClient.calibrationState {
        case .idle:
            return calibrationClient.connectionStatus == .connected ? .blue : .gray
        case .preparing, .listening, .analyzing:
            return .red
        case .completed:
            return .green
        case .failed:
            return .orange
        }
    }
    
    private var canPerformMainAction: Bool {
        switch calibrationClient.calibrationState {
        case .idle:
            return calibrationClient.connectionStatus == .connected
        case .preparing, .listening, .analyzing:
            return true
        case .completed:
            return false
        case .failed:
            return true
        }
    }
    
    private func mainAction() {
        Task {
            switch calibrationClient.calibrationState {
            case .idle, .failed:
                do {
                    try await calibrationClient.startCalibration()
                } catch {
                    print("❌ Calibration failed: \(error)")
                }
            case .preparing, .listening, .analyzing:
                calibrationClient.resetCalibration()
            case .completed:
                break
            }
        }
    }
}

// MARK: - Device Info Card
struct DeviceInfoCard: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "iphone")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("デバイス情報")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(title: "機種", value: UIDevice.current.model)
                    InfoRow(title: "名前", value: UIDevice.current.name)
                    InfoRow(title: "iOS", value: UIDevice.current.systemVersion)
                    InfoRow(title: "マイク", value: "内蔵マイクロフォン")
                }
            }
            .padding()
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Waveform Animation
struct WaveformAnimationView: View {
    @Binding var isAnimating: Bool
    @State private var amplitude: [Double] = Array(repeating: 0.1, count: 20)
    
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<amplitude.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue)
                    .frame(width: 4)
                    .frame(height: CGFloat(amplitude[index]) * 40 + 4)
                    .animation(
                        .easeInOut(duration: 0.5 + Double(index) * 0.05)
                        .repeatForever(autoreverses: true),
                        value: amplitude[index]
                    )
            }
        }
        .onChange(of: isAnimating) { animating in
            if animating {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        for i in 0..<amplitude.count {
            withAnimation(
                .easeInOut(duration: 0.5 + Double(i) * 0.05)
                .repeatForever(autoreverses: true)
            ) {
                amplitude[i] = Double.random(in: 0.3...1.0)
            }
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            amplitude = Array(repeating: 0.1, count: amplitude.count)
        }
    }
}

// MARK: - Connection Setup View
struct ConnectionSetupView: View {
    @ObservedObject var calibrationClient: iOSCalibrationClient
    @Binding var macOSHost: String
    @Binding var autoDetectedHosts: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("自動検出されたデバイス") {
                    if autoDetectedHosts.isEmpty {
                        Text("デバイスが見つかりません")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(autoDetectedHosts, id: \.self) { host in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(host)
                                        .font(.headline)
                                    Text("HiAudio Pro Server")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("接続") {
                                    connectToHost(host)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                
                Section("手動設定") {
                    TextField("IPアドレス", text: $macOSHost)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("接続") {
                        connectToHost(macOSHost)
                    }
                    .disabled(macOSHost.isEmpty)
                }
                
                Section("接続について") {
                    Text("macOSアプリと同じWi-Fiネットワークに接続してください。")
                    Text("自動検出されない場合は、macOSアプリに表示されるIPアドレスを手動で入力してください。")
                }
            }
            .navigationTitle("macOS接続")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func connectToHost(_ host: String) {
        calibrationClient.connectToMacOS(host: host)
        dismiss()
    }
}

// MARK: - Instructions View
struct CalibrationInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ヘッダー
                    VStack(alignment: .leading, spacing: 10) {
                        Text("キャリブレーション手順")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("正確な音響測定のための準備と実行方法")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 準備
                    InstructionSection(
                        title: "1. 事前準備",
                        icon: "checkmark.circle",
                        steps: [
                            "macOSアプリでHiAudioを起動",
                            "同じWi-Fiネットワークに接続",
                            "静かな環境を確保",
                            "iPhoneの充電を確認"
                        ]
                    )
                    
                    // 配置
                    InstructionSection(
                        title: "2. 機器の配置",
                        icon: "location",
                        steps: [
                            "iPhoneを測定したい位置に配置",
                            "スピーカーから30cm〜1m離す",
                            "iPhoneの画面を上向きに",
                            "安定した場所に設置"
                        ]
                    )
                    
                    // 実行
                    InstructionSection(
                        title: "3. キャリブレーション実行",
                        icon: "play.circle",
                        steps: [
                            "「接続」ボタンでmacOSと接続",
                            "「キャリブレーション開始」をタップ",
                            "測定信号の再生・録音を待つ",
                            "完了まで動かさない"
                        ]
                    )
                    
                    // 注意事項
                    InstructionSection(
                        title: "⚠️ 重要な注意事項",
                        icon: "exclamationmark.triangle",
                        steps: [
                            "測定中は絶対に動かさない",
                            "話しかけたり音を立てない",
                            "他のアプリを使用しない",
                            "バックグラウンド更新を無効に"
                        ]
                    )
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("使い方")
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
}

struct InstructionSection: View {
    let title: String
    let icon: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Text(step)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 10)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Card View Component
struct Card<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    CalibrationView()
}