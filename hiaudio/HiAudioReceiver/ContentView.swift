import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var receiver = BestReceiver()
    @State private var localIP = "Getting IP..."
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.2), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            mainContent
        }
        .preferredColorScheme(.dark)
        .onAppear {
            getLocalIPAddress()
            if !receiver.isReceiving {
                receiver.start()
                print("📱 Auto-started HiAudio Receiver")
            }
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 25) {
                headerView
                mainControlView
                audioWaveformView
                statsGridView
                if receiver.isReceiving {
                    quickSettingsView
                    proControlsView
                    aiMetricsView
                }
                Spacer(minLength: 30)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan, radius: 5)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("HiAudio")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Audio Receiver")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Circle()
                        .fill(receiver.isReceiving ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                        .scaleEffect(receiver.isReceiving ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(), value: receiver.isReceiving)
                    
                    Text(receiver.isReceiving ? "LIVE" : "OFF")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(receiver.isReceiving ? .green : .red)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var mainControlView: some View {
        Button(action: {
            if receiver.isReceiving {
                receiver.stop()
            } else {
                receiver.start()
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: receiver.isReceiving ? 
                                [Color.red.opacity(0.8), Color.red] :
                                [Color.green.opacity(0.8), Color.green],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                HStack(spacing: 12) {
                    Image(systemName: receiver.isReceiving ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(receiver.isReceiving ? "STOP RECEIVER" : "START RECEIVER")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(receiver.isReceiving ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: receiver.isReceiving)
        .padding(.horizontal)
    }
    
    private var audioWaveformView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("AUDIO SIGNAL")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(String(format: "%.1f", receiver.outputLevel))dB")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(receiver.isClipping ? .red : .cyan)
            }
            
            AudioWaveformView(isReceiving: receiver.isReceiving, audioLevel: receiver.outputLevel, isClipping: receiver.isClipping)
                .frame(height: 60)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.4))
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private var statsGridView: some View {
        VStack(spacing: 15) {
            HStack {
                Text("LIVE DATA")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                StatCardView(
                    title: "PACKETS",
                    value: "\(receiver.packetsReceived)",
                    unit: "",
                    color: .cyan,
                    isActive: receiver.isReceiving
                )
                
                StatCardView(
                    title: "LATENCY",
                    value: String(format: "%.1f", receiver.targetLatencyMs),
                    unit: "ms",
                    color: .green,
                    isActive: receiver.isReceiving
                )
                
                StatCardView(
                    title: "VOLUME",
                    value: String(format: "%.0f", receiver.outputVolume * 100),
                    unit: "%",
                    color: .orange,
                    isActive: receiver.isReceiving
                )
                
                StatCardView(
                    title: "IP",
                    value: localIP,
                    unit: ":55555",
                    color: .purple,
                    isActive: receiver.isReceiving
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.4))
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private var quickSettingsView: some View {
        VStack(spacing: 15) {
            HStack {
                Text("QUICK SETTINGS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("VOLUME")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 80, alignment: .leading)
                    
                    Slider(value: $receiver.outputVolume, in: 0...1, step: 0.1)
                    .accentColor(.orange)
                    
                    Text("\(Int(receiver.outputVolume * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .frame(width: 40, alignment: .trailing)
                }
                
                HStack {
                    Text("LATENCY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 80, alignment: .leading)
                    
                    Slider(value: Binding(
                        get: { receiver.targetLatencyMs },
                        set: { receiver.setTargetLatency($0) }
                    ), in: 10...200, step: 5)
                    .accentColor(.green)
                    
                    Text("\(Int(receiver.targetLatencyMs))ms")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.4))
        .cornerRadius(15)
        .padding(.horizontal)
        .transition(.opacity.combined(with: .scale))
    }
    
    private func getLocalIPAddress() {
        DispatchQueue.global().async {
            var address: String = "Unknown"
            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            
            if getifaddrs(&ifaddr) == 0 {
                var ptr = ifaddr
                while ptr != nil {
                    defer { ptr = ptr?.pointee.ifa_next }
                    
                    let interface = ptr?.pointee
                    let addrFamily = interface?.ifa_addr.pointee.sa_family
                    
                    if addrFamily == UInt8(AF_INET) {
                        let name = String(cString: (interface?.ifa_name)!)
                        if name == "en0" || name == "en1" { // WiFi or Ethernet
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                       &hostname, socklen_t(hostname.count),
                                       nil, socklen_t(0), NI_NUMERICHOST)
                            address = String(cString: hostname)
                            break
                        }
                    }
                }
                freeifaddrs(ifaddr)
            }
            
            DispatchQueue.main.async {
                self.localIP = address
            }
        }
    }
}

// MARK: - Receiver Control View
struct ReceiverControlView: View {
    @ObservedObject var receiver: BestReceiver
    @Binding var localIP: String
    @State private var cableConnected: Bool = false
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.2), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header with speaker icon
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .shadow(color: .cyan, radius: 10)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("HiAudio")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Professional Audio Receiver")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Connection status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(receiver.isReceiving ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                            .scaleEffect(receiver.isReceiving ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(), value: receiver.isReceiving)
                        
                        Text(receiver.isReceiving ? "CONNECTED" : "DISCONNECTED")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(receiver.isReceiving ? .green : .red)
                    }
                }
                .padding(.top)
                
                Spacer()
                
                // 🔌 Cable Connection Visualization
                CableConnectionView(isConnected: receiver.isReceiving, onToggle: {
                    if receiver.isReceiving {
                        receiver.stop()
                    } else {
                        receiver.start()
                    }
                })
                
                Spacer()
                
                // Audio Status Panel
                VStack(spacing: 20) {
                    // Status Display
                    VStack(spacing: 10) {
                        HStack {
                            Text("STATUS:")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(receiver.isReceiving ? "RECEIVING AUDIO" : "WAITING FOR CONNECTION")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(receiver.isReceiving ? .green : .orange)
                        }
                        
                        if receiver.isReceiving {
                            HStack {
                                Text("PACKETS:")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(receiver.packetsReceived)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    
                    // 🌊 **リアルタイム音声波形アニメーション**
                    VStack(spacing: 8) {
                        Text("AUDIO LEVEL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        AudioWaveformView(isReceiving: receiver.isReceiving, audioLevel: receiver.outputLevel, isClipping: receiver.isClipping)
                            .frame(height: 50)
                            .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Device Information (Compact)
                CompactDeviceInfoView(receiver: receiver, localIP: localIP)
                    .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
            .padding()
        }
    }
}

// MARK: - Stat Card View
struct StatCardView: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(isActive ? color : .gray)
                    .animation(.easeInOut(duration: 0.3), value: value)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.bottom, 1)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? color.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isActive ? 1.0 : 0.98)
        .animation(.spring(response: 0.3), value: isActive)
    }
}

// MARK: - Device Info View
struct DeviceInfoView: View {
    @ObservedObject var receiver: BestReceiver
    let localIP: String
    
    var body: some View {
        VStack(spacing: 15) {
            Text("DEVICE INFORMATION")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                InfoRowView(label: "NAME", value: receiver.deviceName)
                InfoRowView(label: "IP", value: localIP)
                InfoRowView(label: "PORT", value: "\(HiAudioService.udpPort)")
                InfoRowView(label: "STATUS", value: receiver.isReceiving ? "DISCOVERABLE" : "OFFLINE")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Info Row View
struct InfoRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.cyan)
        }
    }
}

// MARK: - Receiver Audio View
struct ReceiverAudioView: View {
    @ObservedObject var receiver: BestReceiver
    
    var body: some View {
        VStack(spacing: 30) {
            Text("AUDIO MONITORING")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top)
            
            // Audio Level Meter
            HStack {
                Spacer()
                VStack {
                    Text("OUTPUT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    ReceiverAudioMeterView(
                        level: receiver.outputLevel,
                        isClipping: receiver.isClipping
                    )
                    
                    Text("\(Int(receiver.outputLevel))dB")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(receiver.isClipping ? .red : .white)
                }
                Spacer()
            }
            
            // Audio Statistics
            VStack(spacing: 15) {
                HStack {
                    AudioStatView(title: "LATENCY", value: "\(String(format: "%.1f", receiver.currentLatency))ms", color: latencyColor(receiver.currentLatency))
                    Spacer()
                    AudioStatView(title: "AVG LATENCY", value: "\(String(format: "%.1f", receiver.averageLatency))ms", color: .cyan)
                }
                
                HStack {
                    AudioStatView(title: "PACKETS/SEC", value: "\(receiver.packetsPerSecond)", color: .blue)
                    Spacer()
                    AudioStatView(title: "QUALITY", value: receiver.connectionQuality, color: qualityColor(receiver.connectionQuality))
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(.darkGray)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func latencyColor(_ latency: Double) -> Color {
        if latency < 5 { return .green }
        if latency < 20 { return .yellow }
        return .red
    }
    
    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "EXCELLENT": return .green
        case "GOOD": return .cyan
        case "FAIR": return .yellow
        case "POOR": return .red
        default: return .gray
        }
    }
}

// MARK: - Receiver Audio Meter View
struct ReceiverAudioMeterView: View {
    let level: Float      // -60 to 0 dB
    let isClipping: Bool
    
    private var normalizedLevel: Double {
        Double(max(0, (level + 60) / 60)) // -60dB〜0dBを0〜1に正規化
    }
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                // 背景
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 30, height: 200)
                    .border(Color.gray, width: 1)
                
                // レベルバー
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .green, location: 0.0),
                            .init(color: .yellow, location: 0.7),
                            .init(color: .red, location: 0.9)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 28, height: max(2, normalizedLevel * 198))
                    .animation(.easeInOut(duration: 0.1), value: normalizedLevel)
                
                // クリッピング警告
                if isClipping {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 30, height: 8)
                        .offset(y: -205)
                        .animation(.easeInOut(duration: 0.3).repeatForever(), value: isClipping)
                }
            }
        }
    }
}

// MARK: - Audio Stat View
struct AudioStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Receiver Network View
struct ReceiverNetworkView: View {
    @ObservedObject var receiver: BestReceiver
    
    var body: some View {
        VStack(spacing: 30) {
            Text("NETWORK STATUS")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top)
            
            // Connection Status
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: receiver.isReceiving ? "wifi" : "wifi.slash")
                        .font(.system(size: 50))
                        .foregroundColor(receiver.isReceiving ? .green : .gray)
                    
                    VStack(alignment: .leading) {
                        Text(receiver.isReceiving ? "ONLINE" : "OFFLINE")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(receiver.isReceiving ? .green : .gray)
                        
                        Text(receiver.isReceiving ? "Ready for connections" : "Start receiving to go online")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                
                // Network Metrics
                if receiver.isReceiving {
                    VStack(spacing: 15) {
                        HStack {
                            NetworkMetricView(title: "CURRENT LATENCY", value: "\(String(format: "%.1f", receiver.currentLatency))ms", color: .cyan)
                            Spacer()
                            NetworkMetricView(title: "AVG LATENCY", value: "\(String(format: "%.1f", receiver.averageLatency))ms", color: .blue)
                        }
                        
                        HStack {
                            NetworkMetricView(title: "PACKETS", value: "\(receiver.packetsReceived)", color: .green)
                            Spacer()
                            NetworkMetricView(title: "QUALITY", value: receiver.connectionQuality, color: qualityColor(receiver.connectionQuality))
                        }
                        
                        HStack {
                            NetworkMetricView(title: "RATE", value: "\(receiver.packetsPerSecond)/s", color: .orange)
                            Spacer()
                            NetworkMetricView(title: "BUFFER", value: "STABLE", color: .purple)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(.darkGray)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "EXCELLENT": return .green
        case "GOOD": return .cyan
        case "FAIR": return .yellow
        case "POOR": return .red
        default: return .gray
        }
    }
}

// MARK: - Network Metric View
struct NetworkMetricView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Receiver Spectrum View
struct ReceiverSpectrumView: View {
    @ObservedObject var receiver: BestReceiver
    @State private var spectrumData: [Float] = Array(repeating: 0.0, count: 64)
    @State private var waveformData: [Float] = Array(repeating: 0.0, count: 128)
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SPECTRUM ANALYZER")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding()
            
            // Compact Spectrum Analyzer
            VStack {
                Text("FREQUENCY SPECTRUM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .border(Color.gray, width: 1)
                        .frame(height: 120)
                    
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<spectrumData.count, id: \.self) { index in
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [.green, .yellow, .red],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ))
                                .frame(height: max(1, CGFloat(spectrumData[index]) * 110))
                                .animation(.easeInOut(duration: 0.1), value: spectrumData[index])
                        }
                    }
                    .padding(5)
                }
                .padding(.horizontal)
            }
            
            // Compact Waveform
            VStack {
                Text("WAVEFORM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .border(Color.gray, width: 1)
                        .frame(height: 80)
                    
                    Path { path in
                        guard !waveformData.isEmpty else { return }
                        let stepWidth = UIScreen.main.bounds.width * 0.8 / Double(waveformData.count - 1)
                        
                        path.move(to: CGPoint(x: 0, y: 40 + Double(waveformData[0]) * 35))
                        for i in 1..<waveformData.count {
                            let x = Double(i) * stepWidth
                            let y = 40 + Double(waveformData[i]) * 35
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(Color.green, lineWidth: 1)
                    
                    // Center line
                    Rectangle()
                        .fill(Color.yellow.opacity(0.5))
                        .frame(height: 1)
                        .position(x: UIScreen.main.bounds.width * 0.4, y: 40)
                }
                .padding(.horizontal)
            }
            
            // Real-time Analysis Stats
            VStack(spacing: 15) {
                HStack {
                    MobileAnalysisStatView(title: "PEAK FREQ", value: "\(Int(findPeakFrequency()))Hz", color: .cyan)
                    Spacer()
                    MobileAnalysisStatView(title: "RMS POWER", value: "\(String(format: "%.1f", receiver.outputLevel))dB", color: .green)
                }
                
                HStack {
                    MobileAnalysisStatView(title: "DYNAMIC", value: "\(String(format: "%.1f", calculateDynamicRange()))dB", color: .orange)
                    Spacer()
                    MobileAnalysisStatView(title: "QUALITY", value: receiver.connectionQuality, color: qualityColor(receiver.connectionQuality))
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(.darkGray)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) {_ in
            updateSpectrumData()
            updateWaveformData()
        }
    }
    
    private func updateSpectrumData() {
        for i in 0..<spectrumData.count {
            let frequency = Float(i) / Float(spectrumData.count)
            let baseLevel = Float(receiver.outputLevel + 60) / 60.0
            let freqResponse = 1.0 - abs(frequency - 0.4) * 1.5
            spectrumData[i] = max(0, min(1, baseLevel * freqResponse * Float.random(in: 0.7...1.3)))
        }
    }
    
    private func updateWaveformData() {
        let amplitude = (receiver.outputLevel + 60) / 60.0
        for i in 0..<waveformData.count {
            let phase = Float(i) * 0.2
            let baseWave = sin(phase) * amplitude
            let noise = Float.random(in: -0.15...0.15) * amplitude
            waveformData[i] = max(-1, min(1, baseWave + noise))
        }
    }
    
    private func findPeakFrequency() -> Float {
        guard let maxIndex = spectrumData.enumerated().max(by: { $0.1 < $1.1 })?.0 else { return 0 }
        return Float(maxIndex) * (24000.0 / Float(spectrumData.count))
    }
    
    private func calculateDynamicRange() -> Float {
        let maxLevel = spectrumData.max() ?? 0
        let minLevel = spectrumData.min() ?? 0
        return (maxLevel - minLevel) * 60
    }
    
    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "EXCELLENT": return .green
        case "GOOD": return .cyan
        case "FAIR": return .yellow
        case "POOR": return .red
        default: return .gray
        }
    }
}

// MARK: - Mobile Analysis Stat View
struct MobileAnalysisStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
        }
    }
}

// MARK: - Receiver Features View (Pro Settings)
struct ReceiverFeaturesView: View {
    @ObservedObject var receiver: BestReceiver
    @State private var selectedAudioFormat = "WAV 48kHz"
    @State private var bufferSize: Float = 3.0
    @State private var noiseGate: Float = -40.0
    @State private var showExportSheet = false
    
    var body: some View {
        VStack(spacing: 25) {
            Text("PRO FEATURES")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding()
            
            // Recording Section
            VStack(spacing: 15) {
                Text("SESSION RECORDING")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                HStack(spacing: 20) {
                    Button(action: {
                        toggleRecording()
                    }) {
                        HStack {
                            Image(systemName: receiver.isRecording ? "stop.circle.fill" : "record.circle")
                            Text(receiver.isRecording ? "STOP" : "RECORD")
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(receiver.isRecording ? Color.red : Color.green)
                        .cornerRadius(8)
                    }
                    
                    if receiver.isRecording {
                        VStack {
                            Text("DURATION")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(formatDuration(receiver.recordingDuration))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Export Controls
                HStack(spacing: 15) {
                    Button("EXPORT") {
                        showExportSheet = true
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(6)
                    
                    Button("SHARE") {
                        // Share functionality
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.8))
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Audio Quality Control
            VStack(spacing: 15) {
                Text("AUDIO QUALITY CONTROL")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                // Quality Adaptation
                VStack(spacing: 12) {
                    HStack {
                        Text("ADAPTIVE QUALITY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Toggle("", isOn: $receiver.adaptiveQualityEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    }
                    
                    // Buffer Management
                    HStack {
                        Text("BUFFER SIZE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(String(format: "%.1f", bufferSize))ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Slider(value: $bufferSize, in: 1...10, step: 0.5)
                        .accentColor(.green)
                    
                    // Jitter Buffer Control
                    HStack {
                        Text("JITTER BUFFER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(receiver.jitterBufferSize) packets")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    
                    // 🎯 Target Latency Control
                    HStack {
                        Text("TARGET LATENCY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(String(format: "%.0f", receiver.targetLatencyMs))ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    
                    Slider(value: Binding(
                        get: { receiver.targetLatencyMs },
                        set: { newValue in
                            receiver.setTargetLatency(newValue)
                        }
                    ), in: 10...200, step: 5)
                        .accentColor(.orange)
                    
                    HStack {
                        Text("10ms")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Ultra-low")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.orange)
                        Spacer()
                        Text("200ms")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    // Connection Quality Display
                    HStack {
                        Text("QUALITY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(receiver.connectionQuality)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(qualityColor(receiver.connectionQuality))
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Audio Processing Settings
            VStack(spacing: 15) {
                Text("AUDIO PROCESSING")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                VStack(spacing: 12) {
                    // Volume Control
                    HStack {
                        Text("VOLUME")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(String(format: "%.0f", receiver.outputVolume * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Slider(value: $receiver.outputVolume, in: 0...1, step: 0.05)
                        .accentColor(.blue)
                    
                    // Format Selector
                    HStack {
                        Text("EXPECTED FORMAT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Picker("Format", selection: $selectedAudioFormat) {
                            Text("96kHz Stereo").tag("96kHz Stereo")
                            Text("48kHz Stereo").tag("48kHz Stereo") 
                            Text("48kHz Mono").tag("48kHz Mono")
                            Text("44.1kHz Mono").tag("44.1kHz Mono")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .foregroundColor(.white)
                    }
                    
                    // Auto-Reconnection
                    HStack {
                        Text("AUTO RECONNECT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Toggle("", isOn: $receiver.autoReconnectEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // System Information
            VStack(spacing: 10) {
                Text("SYSTEM INFO")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                VStack(spacing: 8) {
                    InfoRowView(label: "SAMPLE RATE", value: "96000 Hz")
                    InfoRowView(label: "BIT DEPTH", value: "32-bit Float")
                    InfoRowView(label: "CHANNELS", value: "Stereo (2.0)")
                    InfoRowView(label: "CODEC", value: "PCM Uncompressed")
                    InfoRowView(label: "PROTOCOL", value: "UDP + 2x Redundancy")
                    InfoRowView(label: "PROCESSING", value: "Multiband + Limiter")
                    InfoRowView(label: "VERSION", value: "HiAudio Pro v2.1 Ultra")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(.darkGray)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showExportSheet) {
            ExportOptionsView(recordedFiles: receiver.recordedFiles, onExport: { recording in
                // Handle export functionality
                print("Exporting: \(recording.name)")
            }, onDelete: { recording in
                receiver.deleteRecording(recording)
            })
        }
    }
    
    private func toggleRecording() {
        if receiver.isRecording {
            receiver.stopRecording()
        } else {
            receiver.startRecording()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func qualityColor(_ quality: String) -> Color {
        switch quality {
        case "EXCELLENT": return .green
        case "GOOD": return .cyan
        case "FAIR": return .yellow
        case "POOR": return .red
        default: return .gray
        }
    }
}

// MARK: - Export Options View
struct ExportOptionsView: View {
    @Environment(\.dismiss) var dismiss
    let recordedFiles: [RecordingFile]
    let onExport: (RecordingFile) -> Void
    let onDelete: (RecordingFile) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("RECORDED FILES")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                
                if recordedFiles.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No recordings yet")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("Start recording to see files here")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(recordedFiles) { recording in
                                RecordedFileRow(
                                    recording: recording,
                                    onExport: { onExport(recording) },
                                    onDelete: { onDelete(recording) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Recordings (\(recordedFiles.count))")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Recordings View
struct RecordingsView: View {
    @ObservedObject var receiver: BestReceiver
    @State private var showShareSheet = false
    @State private var selectedRecording: RecordingFile?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AUDIO RECORDINGS")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top)
            
            // Recording Control Section
            VStack(spacing: 15) {
                Text("SESSION RECORDING")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                HStack(spacing: 20) {
                    Button(action: {
                        if receiver.isRecording {
                            receiver.stopRecording()
                        } else {
                            receiver.startRecording()
                        }
                    }) {
                        HStack {
                            Image(systemName: receiver.isRecording ? "stop.circle.fill" : "record.circle")
                            Text(receiver.isRecording ? "STOP" : "RECORD")
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 15)
                        .background(receiver.isRecording ? Color.red : Color.green)
                        .cornerRadius(8)
                    }
                    
                    if receiver.isRecording {
                        VStack {
                            Text("RECORDING")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                            Text(formatDuration(receiver.recordingDuration))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Recordings List
            VStack(spacing: 15) {
                HStack {
                    Text("SAVED RECORDINGS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    Spacer()
                    
                    Text("(\(receiver.recordedFiles.count))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                if receiver.recordedFiles.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No recordings yet")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("Start recording to capture audio")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 30)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(receiver.recordedFiles) { recording in
                                RecordingItemView(
                                    recording: recording,
                                    onShare: {
                                        selectedRecording = recording
                                        showShareSheet = true
                                    },
                                    onDelete: {
                                        receiver.deleteRecording(recording)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(.darkGray)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showShareSheet) {
            if let recording = selectedRecording {
                ShareSheet(recording: recording)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Item View
struct RecordingItemView: View {
    let recording: RecordingFile
    let onShare: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                            .foregroundColor(.cyan)
                        Text(recording.formattedDuration)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    
                    HStack {
                        Image(systemName: "doc")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Text(recording.formattedFileSize)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                
                Text(recording.formattedDate)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(6)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.red.opacity(0.8))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Share Sheet
struct ShareSheet: View {
    let recording: RecordingFile
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("SHARE RECORDING")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                
                VStack(spacing: 15) {
                    Text(recording.name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    HStack {
                        Text(recording.formattedDuration)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                        Text("•")
                            .foregroundColor(.gray)
                        Text(recording.formattedFileSize)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                VStack(spacing: 15) {
                    ShareOption(title: "AirDrop", icon: "airplayaudio")
                    ShareOption(title: "Files App", icon: "folder")
                    ShareOption(title: "Email", icon: "envelope")
                    ShareOption(title: "Messages", icon: "message")
                    ShareOption(title: "More Options", icon: "ellipsis.circle")
                }
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Share Option
struct ShareOption: View {
    let title: String
    let icon: String
    
    var body: some View {
        Button(action: {
            // Share action implementation
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.cyan)
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Recorded File Row
struct RecordedFileRow: View {
    let recording: RecordingFile
    let onExport: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack {
                        Text(recording.formattedDuration)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        Text(recording.formattedFileSize)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    Text(recording.formattedDate)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("SHARE") {
                        onExport()
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(4)
                    
                    Button("DELETE") {
                        onDelete()
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(4)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 🔌 Cable Connection View
struct CableConnectionView: View {
    let isConnected: Bool
    let onToggle: () -> Void
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 30) {
            // Speaker with input jack
            ZStack {
                // Speaker body
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.9), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                    )
                
                // Speaker grille
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 8) {
                            ForEach(0..<6, id: \.self) { _ in
                                Circle()
                                    .fill(Color.gray.opacity(0.6))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                
                // Input jack
                HStack {
                    Spacer()
                    VStack {
                        Circle()
                            .fill(isConnected ? Color.green : Color.gray.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .overlay(
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 8, height: 8)
                            )
                        Spacer()
                    }
                }
                .padding(.trailing, -12)
            }
            .shadow(color: isConnected ? .green.opacity(0.5) : .clear, radius: 10)
            
            // Cable
            HStack(spacing: 0) {
                Spacer()
                
                // Cable body
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.8), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 80, height: 6)
                    .offset(x: isConnected ? 12 : -20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isConnected)
                
                // Cable connector
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray, Color.black],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 30, height: 12)
                    .overlay(
                        Capsule()
                            .stroke(Color.gray.opacity(0.7), lineWidth: 1)
                    )
                    .offset(x: isConnected ? 12 : -20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isConnected)
            }
            .padding(.horizontal, 40)
            
            // Connection button
            Button(action: onToggle) {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(
                                LinearGradient(
                                    colors: isConnected ? 
                                        [Color.red.opacity(0.8), Color.red] :
                                        [Color.green.opacity(0.8), Color.green],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 160, height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        HStack(spacing: 8) {
                            Image(systemName: isConnected ? "cable.connector.slash" : "cable.connector")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(isConnected ? "DISCONNECT" : "CONNECT")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isConnected ? 1.05 : 1.0)
            .animation(.spring(response: 0.4), value: isConnected)
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if isConnected {
                withAnimation(.easeInOut(duration: 2)) {
                    animationOffset += 1
                }
            }
        }
    }
}

// MARK: - Compact Device Info View
struct CompactDeviceInfoView: View {
    @ObservedObject var receiver: BestReceiver
    let localIP: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("DEVICE INFO")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("IP:")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(localIP)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                
                HStack {
                    Text("PORT:")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("55555")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                
                if receiver.isReceiving {
                    HStack {
                        Text("LATENCY:")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(String(format: "%.1f", receiver.targetLatencyMs))ms")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - 🌊 Real-time Audio Waveform Animation
struct AudioWaveformView: View {
    let isReceiving: Bool
    let audioLevel: Float  // -60dB to 0dB
    let isClipping: Bool
    
    @State private var waveformBars: [Float] = Array(repeating: 0.0, count: 20)
    @State private var animationPhase: Double = 0
    @State private var lastAudioLevel: Float = -60.0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: getBarColors(for: index),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: CGFloat(waveformBars[index] * 40))
                    .animation(.easeOut(duration: 0.1), value: waveformBars[index])
            }
        }
        .onReceive(Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()) { _ in
            updateAudioWaveform()
        }
        .onChange(of: audioLevel) { newLevel in
            if isReceiving && newLevel > lastAudioLevel {
                addAudioPulse(strength: audioLevelToStrength(newLevel))
                lastAudioLevel = newLevel
            }
        }
    }
    
    private func getBarColors(for index: Int) -> [Color] {
        if !isReceiving {
            return [Color.gray.opacity(0.3), Color.gray.opacity(0.1)]
        }
        
        let barLevel = waveformBars[index]
        
        if isClipping && barLevel > 0.7 {
            // 🔴 クリッピング時: 赤色警告
            return [Color.red, Color.orange]
        } else if barLevel > 0.5 {
            // 🟢 高音量: 緑→青グラデーション
            return [Color.green, Color.cyan, Color.blue]
        } else if barLevel > 0.2 {
            // 🔵 中音量: 青→紫グラデーション  
            return [Color.cyan, Color.blue, Color.purple]
        } else {
            // 🟣 低音量: 紫→グレーグラデーション
            return [Color.purple.opacity(0.7), Color.gray.opacity(0.4)]
        }
    }
    
    private func audioLevelToStrength(_ level: Float) -> Float {
        // -60dB to 0dB を 0.0 to 1.0 に正規化
        return max(0.0, min(1.0, (level + 60.0) / 60.0))
    }
    
    private func updateAudioWaveform() {
        if isReceiving {
            // 🎵 **音声レベルベースの波形生成**
            animationPhase += 0.2
            let currentStrength = audioLevelToStrength(audioLevel)
            
            for i in 0..<waveformBars.count {
                // 音声レベルに基づく基本波形 + 動的波
                let baseLevel = currentStrength * 0.6 // 音声レベルをベースに
                let waveComponent = Float(sin(animationPhase + Double(i) * 0.8)) * currentStrength * 0.4
                let targetLevel = baseLevel + waveComponent
                
                // スムーズな減衰
                let decayRate: Float = 0.85
                waveformBars[i] = waveformBars[i] * decayRate + targetLevel * (1.0 - decayRate)
            }
        } else {
            // 📴 **停止中**: 波形が静止
            for i in 0..<waveformBars.count {
                waveformBars[i] *= 0.9
            }
        }
    }
    
    private func addAudioPulse(strength: Float) {
        // 🎤 **音声レベルに応じたパルス**: 強い音ほど広範囲に影響
        let pulseWidth = Int(strength * 5) + 1 // 1-6本のバー
        let centerIndex = Int.random(in: pulseWidth...(waveformBars.count - pulseWidth))
        
        for offset in -pulseWidth...pulseWidth {
            let index = centerIndex + offset
            if index >= 0 && index < waveformBars.count {
                let distance = Float(abs(offset))
                let falloff = max(0.1, 1.0 - distance / Float(pulseWidth))
                waveformBars[index] = min(1.0, waveformBars[index] + strength * falloff)
            }
        }
    }
}

// MARK: - Pro Controls Extension
extension ContentView {
    
    // 🔥 **PRO CONTROLS VIEW** - Professional audio controls
    private var proControlsView: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.cyan)
                
                Text("PRO CONTROLS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Audio Quality Preset
            VStack(spacing: 8) {
                HStack {
                    Text("QUALITY PRESET")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("ULTRA (96kHz)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                
                // Quality indicator bars
                HStack(spacing: 3) {
                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(index < 7 ? Color.green : Color.green.opacity(0.3))
                            .frame(height: 4)
                    }
                }
            }
            .padding(.horizontal)
            
            // Ultra-low Latency Control
            VStack(spacing: 8) {
                HStack {
                    Text("TARGET LATENCY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", receiver.targetLatencyMs))ms")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                
                Slider(value: Binding(
                    get: { receiver.targetLatencyMs },
                    set: { receiver.setTargetLatency($0) }
                ), in: 5.0...50.0, step: 1.0)
                .accentColor(.orange)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    // 🧠 **AI METRICS VIEW** - AI calibration status
    private var aiMetricsView: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("AI PRECISION SYNC")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Circle()
                    .fill(receiver.aiTuningActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(receiver.aiTuningActive ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: receiver.aiTuningActive)
            }
            .padding(.horizontal)
            
            // AI Metrics Grid
            HStack(spacing: 15) {
                VStack(spacing: 4) {
                    Text("ACCURACY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(String(format: "%.2f", receiver.aiSyncAccuracy))ms")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 4) {
                    Text("OPTIMIZATION")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(String(format: "%.0f", receiver.hardwareOptimization))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 4) {
                    Text("PREDICTION")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(receiver.predictiveCorrection ? "ON" : "OFF")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(receiver.predictiveCorrection ? .green : .gray)
                }
                
                VStack(spacing: 4) {
                    Text("ADAPTIVE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(receiver.adaptiveBuffering ? "ON" : "OFF")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(receiver.adaptiveBuffering ? .green : .gray)
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}

// MARK: - Testing Extension
extension BestReceiver {
    func addSampleRecording() {
        let sampleRecording = RecordingFile(
            url: URL(string: "file:///sample.m4a")!,
            name: "Sample_Recording.m4a",
            duration: 125.5,
            dateCreated: Date(),
            fileSize: 1024000
        )
        recordedFiles.append(sampleRecording)
    }
}